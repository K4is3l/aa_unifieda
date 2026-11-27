-- ============================================================================
-- ANIME ADVENTURES - UNIFIED HUB (COMPLETE JOIN, PRIORITY, SWORDSMITH & GAME)
-- Save as 'AA_Unified_Hub.lua' in your executor's 'workspace' and 'autoexec'.
-- ============================================================================

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local StatsService = game:GetService("Stats")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
    task.wait(0.1)
    LocalPlayer = Players.LocalPlayer
end

local PlayerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 15)
local IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- ============================================================================
-- 1. SAFE EXECUTOR FILE, CLIPBOARD & TELEPORT WRAPPERS
-- ============================================================================
local function SafeIsFile(path)
    if type(isfile) == "function" then
        local ok, res = pcall(isfile, path)
        return ok and res == true
    end
    return false
end

local function SafeReadFile(path)
    if type(readfile) == "function" and SafeIsFile(path) then
        local ok, res = pcall(readfile, path)
        if ok and type(res) == "string" then
            return res
        end
    end
    return nil
end

local function SafeWriteFile(path, content)
    if type(writefile) == "function" and type(content) == "string" then
        pcall(writefile, path, content)
    end
end

local function SafeDeleteFile(path)
    if type(delfile) == "function" and SafeIsFile(path) then
        pcall(delfile, path)
    end
end

local function SafeSetClipboard(text)
    if type(setclipboard) == "function" and type(text) == "string" then
        pcall(setclipboard, text)
        return true
    end
    return false
end

local function ListSavedMacros()
    local names = {}
    local seen = {}
    if type(listfiles) == "function" then
        local ok, files = pcall(listfiles, "")
        if ok and type(files) == "table" then
            for _, f in ipairs(files) do
                local m = tostring(f):match("AAMacro_([%w_%-]+)%.json$")
                if m and not seen[m] then
                    seen[m] = true
                    table.insert(names, m)
                end
            end
        end
    end
    return names
end

local SCRIPT_FILE = "AA_Unified_Hub.lua"
local queueTP = (type(queue_on_teleport) == "function" and queue_on_teleport)
    or (type(syn) == "table" and type(syn.queue_on_teleport) == "function" and syn.queue_on_teleport)
    or (type(fluxus) == "table" and type(fluxus.queue_on_teleport) == "function" and fluxus.queue_on_teleport)

if queueTP then
    local src = SafeReadFile(SCRIPT_FILE)
    if src and #src > 0 then
        pcall(queueTP, src)
    end
end

LocalPlayer.Idled:Connect(function()
    if Config and Config.AntiAfkEnabled == false then return end
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end)

-- ============================================================================
-- 2. PERSISTENT CONFIGURATION
-- ============================================================================
local CONFIG_FILE = "AA_UnifiedHub_Config.json"
local STORY_MAPS = {
    "Planet Greenie",
    "Walled City",
    "Snowy Town",
    "Sand Village",
    "Navy Bay",
    "Fiend City",
    "Spirit World",
    "Ant Kingdom",
    "Space Center",
    "Haunted Mansion",
    "Rain Village"
}

local LEGEND_MAPS = {
    "Dungeon Throne",
    "Planet Greenie (Legend)",
    "Walled City (Legend)",
    "Snowy Town (Legend)",
    "Sand Village (Legend)",
    "Navy Bay (Legend)",
    "Fiend City (Legend)"
}

local TEAM_OPTIONS = {
    "Keep Current",
    "Team 1",
    "Team 2",
    "Team 3",
    "Team 4",
    "Team 5",
    "Team 6"
}

local Config = {
    Runs = 0,
    Skips = 0,
    CurrentWave = 0,
    KeyStatus = "Free",
    SavedKey = "",

    -- Macro (Record / Play & Macro Maps)
    SelectedMacro = "--",
    RecordMacro = false,
    PlayMacro = false,
    EquipMacroUnits = false,
    PlayBy = "Money",
    UseMacroMaps = false,
    MapMacros = {
        ["Planet Greenie"] = "None",
        ["Walled City"] = "None",
        ["Snowy Town"] = "None",
        ["Sand Village"] = "None",
        ["Navy Bay"] = "None",
        ["Fiend City"] = "None",
        ["Spirit World"] = "None",
        ["Ant Kingdom"] = "None",
        ["Space Center"] = "None",
        ["Haunted Mansion"] = "None",
        ["Rain Village"] = "None"
    },

    -- Auto Play (All Modes & Event)
    AutoPlay = false,
    PathPosition = 1,
    Spacing = 1,
    CoverAllLanes = true,
    PlaceNearBuffers = false,
    WeatherAware = true,
    ShowPlacementGrid = false,
    FarmUnitsFirst = true,
    AutoUpgrade = true,
    UpgradeWhileSaving = true,
    GriffinForm = "Off",
    WalkLikePlayer = false,

    UseEventInSummer = false,
    EventPathPosition = 50,

    -- Specific Unit Settings (Slots 1-6)
    SelectedUnitSlot = 1,
    UnitSlots = {
        [1] = { Priority = 1, MaxPlace = 1, MaxUpgrade = 15, PlaceWave = 1, UpgradeWave = 1, OnHill = false },
        [2] = { Priority = 2, MaxPlace = 3, MaxUpgrade = 15, PlaceWave = 1, UpgradeWave = 1, OnHill = false },
        [3] = { Priority = 3, MaxPlace = 3, MaxUpgrade = 15, PlaceWave = 1, UpgradeWave = 1, OnHill = false },
        [4] = { Priority = 4, MaxPlace = 3, MaxUpgrade = 15, PlaceWave = 1, UpgradeWave = 1, OnHill = false },
        [5] = { Priority = 5, MaxPlace = 3, MaxUpgrade = 15, PlaceWave = 1, UpgradeWave = 1, OnHill = false },
        [6] = { Priority = 6, MaxPlace = 3, MaxUpgrade = 15, PlaceWave = 1, UpgradeWave = 1, OnHill = false }
    },

    -- Join > Story / Challenges
    AutoJoinStory = false,
    JoinMode = "Story",
    JoinWorld = "Planet Greenie",
    JoinLegendWorld = "Dungeon Throne",
    JoinAct = "1",
    JoinDifficulty = "Normal",
    StoryMatchmaking = false,

    AutoJoinChallenge = false,
    AutoJoinDailyChallenge = false,
    ChallengeMatchmaking = false,
    ChallengeDropFilter = "--",
    ChallengeSkipModifiers = "--",

    -- Join > Party & User Stuffs
    InvitePlayerTarget = "--",
    AutoInviteToParty = false,
    JoinPlayerTarget = "--",
    HowToJoinPlayer = "Party",
    AutoJoinPlayer = false,
    UserStuffsPlayer = "--",
    WhitelistUsernames = "",
    WaitBeforeLeaving = 90,
    LeaveWhenGone = false,
    LeaveWhenOthersHere = false,
    OnlyAutoJoinWithThem = false,

    -- Join > Castle / Events / Portals / Contracts / Raids
    AutoInfinityCastle = false,
    CastleMatchmaking = true,
    CastleFloorMode = "Next Floor",
    CastleFixedFloor = 1,
    CastleDifficulty = "Hard",

    AutoEventChallenge = false,
    EventMatchmaking = true,
    HuntBingoMaps = false,
    HuntUnwonWeathers = false,

    AutoContracts = false,
    AutoArtifactRaid = false,
    AutoRaid = false,

    AutoPortal = false,
    AutoStartPortal = true,
    AutoNextPortal = true,
    MostUsesLeftFirst = true,
    PortalMatchmaking = true,

    -- Join > Dungeon
    AutoDungeon = false,
    OpenChestsMode = "Every Chest Room",
    StopAfterLosingRoom = 0,
    TakeShrines = false,
    BuyShopItems = false,
    AvoidCurses = true,
    CursesToAvoid = "Curse of Armor, Curse of Burst",
    LookAhead = true,
    RareChestPriority = 10,
    TeamByRoomWeakness = false,
    PhysicalWeakTeam = "Keep Current",
    MagicWeakTeam = "Keep Current",
    OtherWeakTeam = "Keep Current",
    ShopPriorityItem = "Stat Cube",

    -- Join > Teams
    AutoEquipTeam = false,
    TeamChallenge = "Keep Current",
    TeamDailyChallenge = "Keep Current",
    TeamContracts = "Keep Current",
    TeamEventChallenge = "Keep Current",
    TeamArtifactRaid = "Keep Current",
    TeamSwordsmith = "Keep Current",
    TeamPortals = "Keep Current",
    TeamDungeon = "Keep Current",

    -- Join > Swordsmith & Defenses
    AutoSwordsmith = false,
    SwordsmithMatchmaking = false,
    SwordsmithStage = "Best Available",
    BloodMoonWhenUp = true,
    SkipStageAfterLosses = 3,
    AutoMistyTower = false,
    MistyMatchmaking = false,
    RestAfterLosses = 3,

    AutoPlaceDefenses = true,
    DefensesPlaceAt = "Damage Units",
    DefensesPathPos = 50,
    AutoBuyVillageShop = false,
    BuyRarities = "Rare, Epic, Legendary, Mythic, Secret",
    OnlyBuyByName = "--",
    AutoEquipBestDefense = false,
    AutoRepairDefenses = false,
    RepairBelowPct = 50,
    AutoScrapWhenFull = false,
    ScrapUpToRarity = "Rare",

    -- Priority Tab (Join Priority Weights 1 - 10)
    PriorityChallenge = 7,
    PriorityDailyChallenge = 6,
    PriorityContracts = 5,
    PriorityEventChallenge = 4,
    PriorityArtifactRaid = 4,
    PrioritySwordsmith = 4,
    PriorityPortals = 3,
    PriorityDungeon = 3,
    PriorityRaid = 2,
    PriorityInfinityCastle = 2,

    -- Game Tab (Match, Abilities, Wave Rules)
    AutoVoteStart = false,
    AutoSkipWave = false,
    AutoNext = false,
    AutoRetry = false,
    AutoLeave = false,
    VoteToLoseXP = false,
    BuffUptime = false,
    BuffUnitsList = "Commander, Elfy, Gambler, Griffin",
    AutoAbility = false,
    SellFarmUnits = false,
    SellAllUnitsInf = false,
    LobbyOnInfiniteWave = false,
    LeaveWhenPlayersBelow = false,

    -- Lobby / Webhook / Misc
    AutoClaimQuests = false,
    WebhookUrl = "",
    SendMatchWebhook = false,
    AntiAfkEnabled = true,
    LowGraphicsMode = false
}

local function LoadConfig()
    local raw = SafeReadFile(CONFIG_FILE)
    if raw then
        local ok, data = pcall(function() return HttpService:JSONDecode(raw) end)
        if ok and type(data) == "table" then
            for k, v in pairs(Config) do
                if data[k] ~= nil then
                    if type(v) == "table" and type(data[k]) == "table" then
                        for subK, subV in pairs(v) do
                            if data[k][subK] ~= nil then
                                if type(subV) == "table" and type(data[k][subK]) == "table" then
                                    for leafK, leafV in pairs(subV) do
                                        if data[k][subK][leafK] ~= nil then
                                            subV[leafK] = data[k][subK][leafK]
                                        end
                                    end
                                else
                                    v[subK] = data[k][subK]
                                end
                            end
                        end
                    else
                        Config[k] = data[k]
                    end
                end
            end
        end
    end
end

local function SaveConfig()
    SafeWriteFile(CONFIG_FILE, HttpService:JSONEncode(Config))
end

LoadConfig()

-- ============================================================================
-- 3. GUI CONTAINER, CLICKER, SERVER HOP & FUZZY REMOTES
-- ============================================================================
local function GetSafeGuiParent()
    if type(gethui) == "function" then
        local ok, hui = pcall(gethui)
        if ok and typeof(hui) == "Instance" then return hui end
    end
    local okCore = pcall(function() local _ = CoreGui.Name end)
    if okCore and CoreGui then return CoreGui end
    return PlayerGui or LocalPlayer:WaitForChild("PlayerGui", 10)
end

local function RejoinCurrentServer()
    pcall(function()
        if #Players:GetPlayers() <= 1 then
            LocalPlayer:Kick("\nRejoining server...")
            task.wait(0.2)
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        else
            TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
        end
    end)
end

local function HopToDifferentServer()
    pcall(function()
        local url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100", game.PlaceId)
        local raw = game:HttpGet(url)
        local data = HttpService:JSONDecode(raw)
        if data and type(data.data) == "table" then
            for _, srv in ipairs(data.data) do
                if srv.id and srv.id ~= game.JobId and (srv.playing or 0) < (srv.maxPlayers or 30) then
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, srv.id, LocalPlayer)
                    return
                end
            end
        end
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end)
end

local function SafeClick(btn)
    if not btn or not btn:IsA("GuiButton") then return false end
    local clicked = false
    if type(firesignal) == "function" then
        pcall(function()
            if btn.Activated then firesignal(btn.Activated) end
            if btn.MouseButton1Click then firesignal(btn.MouseButton1Click) end
            if IsMobile and btn.TouchTap then firesignal(btn.TouchTap) end
            clicked = true
        end)
    end
    if not clicked and not IsMobile then
        local vim = game:FindService("VirtualInputManager")
        if vim then
            pcall(function()
                local inset = GuiService:GetGuiInset()
                local pos = btn.AbsolutePosition
                local size = btn.AbsoluteSize
                if size.X > 0 and size.Y > 0 then
                    local x = pos.X + size.X * 0.5
                    local y = pos.Y + size.Y * 0.5 + inset.Y
                    vim:SendMouseButtonEvent(x, y, 0, true, game, 1)
                    task.wait(0.03)
                    vim:SendMouseButtonEvent(x, y, 0, false, game, 1)
                    clicked = true
                end
            end)
        end
    end
    return clicked
end

local function IsReallyVisible(guiObj)
    local cur = guiObj
    while cur and cur ~= PlayerGui and cur ~= CoreGui do
        if cur:IsA("ScreenGui") and not cur.Enabled then return false end
        if cur:IsA("GuiObject") and not cur.Visible then return false end
        cur = cur.Parent
    end
    return true
end

local function FindButtonByPhrase(phrase, ignoreRoot)
    if not PlayerGui then PlayerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui") end
    if not PlayerGui then return nil end

    local needle = phrase:lower()
    for _, d in ipairs(PlayerGui:GetDescendants()) do
        if (not ignoreRoot or not d:IsDescendantOf(ignoreRoot))
            and (d:IsA("TextButton") or d:IsA("ImageButton"))
            and IsReallyVisible(d)
        then
            local texts = { tostring(d.Name or "") }
            if d:IsA("TextButton") and type(d.Text) == "string" then
                table.insert(texts, d.Text)
            end
            for _, sub in ipairs(d:GetDescendants()) do
                if (sub:IsA("TextLabel") or sub:IsA("TextButton")) and type(sub.Text) == "string" then
                    table.insert(texts, sub.Text)
                end
            end
            local blob = table.concat(texts, " "):lower()
            if blob:find(needle, 1, true) then
                return d
            end
        end
    end
    return nil
end

local function CallRemoteFuzzy(patterns, ...)
    local args = { ... }
    for _, desc in ipairs(ReplicatedStorage:GetDescendants()) do
        if desc:IsA("RemoteEvent") or desc:IsA("RemoteFunction") then
            local low = desc.Name:lower()
            for _, pat in ipairs(patterns) do
                if low:find(pat:lower(), 1, true) then
                    local ok, res = pcall(function()
                        if desc:IsA("RemoteEvent") then
                            desc:FireServer(unpack(args))
                        else
                            return desc:InvokeServer(unpack(args))
                        end
                    end)
                    if ok then return res end
                end
            end
        end
    end
    return nil
end

local function IsInLobby()
    if workspace:FindFirstChild("_lobby") or workspace:FindFirstChild("Lobby") or workspace:FindFirstChild("_LOBBIES") then
        return true
    end
    if workspace:FindFirstChild("_waves") or workspace:FindFirstChild("_wave") then
        return false
    end
    return true
end

local function GetCurrentYen()
    local stats = LocalPlayer:FindFirstChild("_stats") or LocalPlayer:FindFirstChild("Stats")
    local yen = stats and (stats:FindFirstChild("yen") or stats:FindFirstChild("Yen") or stats:FindFirstChild("cash") or stats:FindFirstChild("money"))
    if yen and (yen:IsA("IntValue") or yen:IsA("NumberValue")) then
        return yen.Value
    end
    return 0
end

local function GetCurrentWave()
    local w = workspace:FindFirstChild("_wave") or workspace:FindFirstChild("_waves")
    if w and (w:IsA("IntValue") or w:IsA("NumberValue")) then return w.Value end
    local valObj = w and (w:FindFirstChild("Value") or w:FindFirstChild("Wave"))
    if valObj and (valObj:IsA("IntValue") or valObj:IsA("NumberValue")) then return valObj.Value end
    return 0
end

local function GetOwnedUnits()
    local list = {}
    local folder = workspace:FindFirstChild("_units") or workspace:FindFirstChild("Units")
    if not folder then return list end
    for _, u in ipairs(folder:GetChildren()) do
        local st = u:FindFirstChild("_stats") or u:FindFirstChild("Stats")
        local pl = st and (st:FindFirstChild("player") or st:FindFirstChild("Owner"))
        local attr = u:GetAttribute("Owner") or u:GetAttribute("Player")
        if (pl and pl.Value == LocalPlayer) or (attr and tostring(attr) == LocalPlayer.Name) then
            table.insert(list, u)
        end
    end
    return list
end

-- ============================================================================
-- 4. MACRO ENGINE
-- ============================================================================
local MacroEngine = {
    StartClock = 0,
    Steps = {},
    PlayIndex = 1,
    PlayStartClock = 0,
    Status = "idle",
    Hooked = false,
    OnStepsChanged = nil
}

local function NotifyStepsChanged()
    if type(MacroEngine.OnStepsChanged) == "function" then
        pcall(MacroEngine.OnStepsChanged, MacroEngine.Steps)
    end
end

local function GetMacroFilename(name)
    local clean = tostring(name or "Default"):gsub("[^%w_%-]", "_")
    if clean == "" or clean == "--" then clean = "Default" end
    return "AAMacro_" .. clean .. ".json"
end

local function SaveMacroFile(name, steps)
    if not name or name == "--" then name = "Default" end
    SafeWriteFile(GetMacroFilename(name), HttpService:JSONEncode({ name = name, steps = steps }))
end

local function LoadMacroFile(name)
    if not name or name == "--" then return {} end
    local raw = SafeReadFile(GetMacroFilename(name))
    if not raw then return {} end
    local ok, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if ok and type(data) == "table" and type(data.steps) == "table" then
        return data.steps
    end
    return {}
end

local function ExportMacroJson(name, steps)
    return HttpService:JSONEncode({ name = name, steps = steps })
end

local function ImportMacroJson(rawJson, targetName)
    if type(rawJson) ~= "string" or rawJson == "" then return false, 0 end
    local ok, decoded = pcall(function() return HttpService:JSONDecode(rawJson) end)
    if not ok or type(decoded) ~= "table" then return false, 0 end
    local list = type(decoded.steps) == "table" and decoded.steps or (decoded[1] and decoded or nil)
    if not list then return false, 0 end
    local name = (targetName and targetName ~= "" and targetName ~= "--") and targetName or (decoded.name or "Imported")
    Config.SelectedMacro = name
    MacroEngine.Steps = list
    MacroEngine.PlayIndex = 1
    SaveMacroFile(name, list)
    SaveConfig()
    NotifyStepsChanged()
    return true, #list
end

local function GetUnitSlotIndex(inst)
    for i, u in ipairs(GetOwnedUnits()) do
        if u == inst then return i end
    end
    return 1
end

local function InstallMacroHook()
    if MacroEngine.Hooked then return end
    if type(hookmetamethod) ~= "function" or type(getnamecallmethod) ~= "function" or type(checkcaller) ~= "function" then
        return
    end
    local ok = pcall(function()
        local old
        old = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            local args = { ... }
            if Config.RecordMacro and not checkcaller() and (method == "FireServer" or method == "InvokeServer") then
                if typeof(self) == "Instance" and self:IsDescendantOf(ReplicatedStorage) then
                    local rName = self.Name:lower()
                    local t = os.clock() - MacroEngine.StartClock
                    local wave = math.max(1, GetCurrentWave())
                    local yen = GetCurrentYen()

                    if (rName:find("spawn") or rName:find("place")) and typeof(args[2]) == "CFrame" then
                        local cf = args[2]
                        table.insert(MacroEngine.Steps, {
                            action = "Place",
                            unit = tostring(args[1]),
                            wave = wave,
                            yen = yen,
                            t = t,
                            pos = { cf.X, cf.Y, cf.Z }
                        })
                        NotifyStepsChanged()
                    elseif rName:find("upgrade") and typeof(args[1]) == "Instance" then
                        table.insert(MacroEngine.Steps, {
                            action = "Upgrade",
                            unit = args[1].Name,
                            slot = GetUnitSlotIndex(args[1]),
                            wave = wave,
                            yen = yen,
                            t = t
                        })
                        NotifyStepsChanged()
                    elseif rName:find("sell") and typeof(args[1]) == "Instance" then
                        table.insert(MacroEngine.Steps, {
                            action = "Sell",
                            unit = args[1].Name,
                            slot = GetUnitSlotIndex(args[1]),
                            wave = wave,
                            yen = yen,
                            t = t
                        })
                        NotifyStepsChanged()
                    end
                end
            end
            return old(self, ...)
        end)
    end)
    if ok then MacroEngine.Hooked = true end
end

local function StepMacroRuntime()
    if Config.RecordMacro then
        MacroEngine.Status = "recording"
        return
    end
    if not Config.PlayMacro or IsInLobby() then
        MacroEngine.Status = "idle"
        return
    end

    if #MacroEngine.Steps == 0 then
        MacroEngine.Steps = LoadMacroFile(Config.SelectedMacro)
        MacroEngine.PlayIndex = 1
        MacroEngine.PlayStartClock = os.clock()
        NotifyStepsChanged()
    end

    if #MacroEngine.Steps == 0 then
        MacroEngine.Status = "idle"
        return
    end

    if MacroEngine.PlayIndex > #MacroEngine.Steps then
        MacroEngine.Status = "done"
        return
    end

    MacroEngine.Status = "playing"
    local step = MacroEngine.Steps[MacroEngine.PlayIndex]
    local ready = false

    if Config.PlayBy == "Money" then
        ready = (GetCurrentYen() >= (step.yen or 0)) and (GetCurrentWave() >= (step.wave or 0))
    else
        ready = ((os.clock() - MacroEngine.PlayStartClock) >= (step.t or 0))
    end

    if ready then
        if step.action == "Place" and type(step.pos) == "table" then
            CallRemoteFuzzy({ "spawn_unit", "place_unit" }, step.unit, CFrame.new(step.pos[1], step.pos[2], step.pos[3]))
        elseif step.action == "Upgrade" then
            local target = GetOwnedUnits()[step.slot or 1]
            if target then CallRemoteFuzzy({ "upgrade_unit_ingame", "upgrade_unit" }, target) end
        elseif step.action == "Sell" then
            local target = GetOwnedUnits()[step.slot or 1]
            if target then CallRemoteFuzzy({ "sell_unit", "sell" }, target) end
        end
        MacroEngine.PlayIndex = MacroEngine.PlayIndex + 1
    end
end

-- ============================================================================
-- 5. PRIORITY FARM SCHEDULER, PARTY GUARD, TEAMS & SWORDSMITH DEFENSES
-- ============================================================================
local JoinGuard = { Busy = false, LastRun = 0, Cooldown = 2.5, AloneSince = nil }

local function ParseWhitelistSet()
    local set = {}
    for token in tostring(Config.WhitelistUsernames or ""):gmatch("[^,%s]+") do
        set[token:lower()] = true
    end
    return set
end

local function CheckPartyAndUserStuffs()
    if Config.AutoInviteToParty and Config.InvitePlayerTarget ~= "--" then
        local targetPlr = Players:FindFirstChild(Config.InvitePlayerTarget)
        if targetPlr then
            CallRemoteFuzzy({ "party_invite", "invite_player", "invite" }, targetPlr)
        end
    end

    if Config.AutoJoinPlayer and Config.JoinPlayerTarget ~= "--" then
        local targetPlr = Players:FindFirstChild(Config.JoinPlayerTarget)
        if targetPlr then
            CallRemoteFuzzy({ "join_party", "join_player", "teleport_to_player" }, targetPlr)
        end
    end

    local wl = ParseWhitelistSet()
    local hasWhitelisted = false
    local hasStrangers = false
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            if wl[p.Name:lower()] then
                hasWhitelisted = true
            else
                hasStrangers = true
            end
        end
    end

    if Config.LeaveWhenOthersHere and hasStrangers and not IsInLobby() then
        CallRemoteFuzzy({ "leave_match", "return_lobby", "teleport_lobby" })
        return false
    end

    if Config.LeaveWhenGone and next(wl) ~= nil then
        if not hasWhitelisted then
            JoinGuard.AloneSince = JoinGuard.AloneSince or os.clock()
            if (os.clock() - JoinGuard.AloneSince) >= (Config.WaitBeforeLeaving or 90) then
                JoinGuard.AloneSince = nil
                CallRemoteFuzzy({ "leave_match", "return_lobby", "teleport_lobby" })
                return false
            end
        else
            JoinGuard.AloneSince = nil
        end
    end

    if Config.OnlyAutoJoinWithThem and next(wl) ~= nil and not hasWhitelisted then
        return false
    end
    return true
end

local function EquipTeamForMode(teamLabel)
    if not Config.AutoEquipTeam or not teamLabel or teamLabel == "Keep Current" then return end
    local slotNum = tonumber(teamLabel:match("%d+"))
    if slotNum then
        CallRemoteFuzzy({ "equip_team", "load_team", "select_team", "preset" }, slotNum)
    end
end

local function ResolveHighestPriorityTask()
    local candidates = {}

    if Config.AutoJoinChallenge or Config.AutoJoinDailyChallenge then
        local w = Config.AutoJoinChallenge and Config.PriorityChallenge or Config.PriorityDailyChallenge
        table.insert(candidates, {
            id = "Challenge",
            weight = w,
            lobbyMode = "Regular Stages",
            matchmaking = Config.ChallengeMatchmaking,
            team = Config.AutoJoinChallenge and Config.TeamChallenge or Config.TeamDailyChallenge
        })
    end
    if Config.AutoContracts then
        table.insert(candidates, {
            id = "Contracts",
            weight = Config.PriorityContracts,
            lobbyMode = "Regular Stages",
            matchmaking = true,
            team = Config.TeamContracts
        })
    end
    if Config.AutoEventChallenge then
        table.insert(candidates, {
            id = "EventChallenge",
            weight = Config.PriorityEventChallenge,
            lobbyMode = "Summer Event",
            matchmaking = Config.EventMatchmaking,
            team = Config.TeamEventChallenge
        })
    end
    if Config.AutoArtifactRaid then
        table.insert(candidates, {
            id = "ArtifactRaid",
            weight = Config.PriorityArtifactRaid,
            lobbyMode = "Regular Stages",
            matchmaking = true,
            team = Config.TeamArtifactRaid
        })
    end
    if Config.AutoSwordsmith or Config.AutoMistyTower then
        table.insert(candidates, {
            id = "Swordsmith",
            weight = Config.PrioritySwordsmith,
            lobbyMode = "Misty Village",
            matchmaking = Config.AutoSwordsmith and Config.SwordsmithMatchmaking or Config.MistyMatchmaking,
            team = Config.TeamSwordsmith
        })
    end
    if Config.AutoPortal then
        table.insert(candidates, {
            id = "Portals",
            weight = Config.PriorityPortals,
            lobbyMode = "Regular Stages",
            matchmaking = Config.PortalMatchmaking,
            team = Config.TeamPortals
        })
    end
    if Config.AutoDungeon then
        table.insert(candidates, {
            id = "Dungeon",
            weight = Config.PriorityDungeon,
            lobbyMode = "Regular Stages",
            matchmaking = true,
            team = Config.TeamDungeon
        })
    end
    if Config.AutoRaid then
        table.insert(candidates, {
            id = "Raid",
            weight = Config.PriorityRaid,
            lobbyMode = "Regular Stages",
            matchmaking = true,
            team = "Keep Current"
        })
    end
    if Config.AutoInfinityCastle then
        table.insert(candidates, {
            id = "InfinityCastle",
            weight = Config.PriorityInfinityCastle,
            lobbyMode = "Regular Stages",
            matchmaking = Config.CastleMatchmaking,
            team = "Keep Current"
        })
    end
    if Config.AutoJoinStory then
        local targetWorld = (Config.JoinMode == "Legend") and Config.JoinLegendWorld or Config.JoinWorld
        table.insert(candidates, {
            id = "Story",
            weight = 1,
            lobbyMode = "Regular Stages",
            world = targetWorld,
            matchmaking = Config.StoryMatchmaking,
            team = "Keep Current"
        })
    end

    table.sort(candidates, function(a, b) return a.weight > b.weight end)
    return candidates[1]
end

local function StepLobbyAutomation(rootGui)
    if not IsInLobby() or JoinGuard.Busy then return end
    if not CheckPartyAndUserStuffs() then return end

    if Config.AutoClaimQuests then
        CallRemoteFuzzy({ "claim_quest", "claim_daily", "claim_all" })
    end
    if Config.AutoEquipBestDefense then
        CallRemoteFuzzy({ "equip_best_defense", "auto_equip_defense" })
    end
    if Config.AutoRepairDefenses then
        CallRemoteFuzzy({ "repair_defense", "repair_all" }, Config.RepairBelowPct)
    end
    if Config.AutoScrapWhenFull then
        CallRemoteFuzzy({ "scrap_defense", "auto_scrap" }, Config.ScrapUpToRarity)
    end

    local taskObj = ResolveHighestPriorityTask()
    if not taskObj then return end
    if (os.clock() - JoinGuard.LastRun) < JoinGuard.Cooldown then return end

    JoinGuard.Busy = true
    JoinGuard.LastRun = os.clock()

    pcall(function()
        EquipTeamForMode(taskObj.team)

        local desired = taskObj.matchmaking and "find match" or "play here"
        local fallback = taskObj.matchmaking and "play here" or "find match"

        local confirmBtn = FindButtonByPhrase(desired, rootGui) or FindButtonByPhrase(fallback, rootGui)
        if confirmBtn then
            SafeClick(confirmBtn)
            return
        end

        if taskObj.world then
            local worldBtn = FindButtonByPhrase(taskObj.world, rootGui)
            if worldBtn then
                SafeClick(worldBtn)
                task.wait(0.25)
            end
        end

        local modeBtn = FindButtonByPhrase(taskObj.lobbyMode, rootGui)
        if modeBtn then
            SafeClick(modeBtn)
            task.wait(0.35)
            confirmBtn = FindButtonByPhrase(desired, rootGui) or FindButtonByPhrase(fallback, rootGui)
            if confirmBtn then SafeClick(confirmBtn) end
            return
        end

        local playBtn = FindButtonByPhrase("play", rootGui)
        if playBtn then
            SafeClick(playBtn)
        end
    end)

    JoinGuard.Busy = false
end

local LastBuffClock = 0
local function StepInMatchAutomation()
    if not CheckPartyAndUserStuffs() then return end

    if Config.AutoVoteStart then
        CallRemoteFuzzy({ "vote_start", "start_game", "ready" })
    end
    if Config.AutoSkipWave then
        CallRemoteFuzzy({ "vote_wave_skip", "skip_wave" })
    end
    if Config.AutoNext then
        CallRemoteFuzzy({ "next_stage", "vote_next" })
    end
    if Config.AutoRetry then
        CallRemoteFuzzy({ "replay", "vote_replay", "retry" })
    end
    if Config.AutoLeave then
        CallRemoteFuzzy({ "leave_match", "return_lobby" })
    end

    -- Swordsmith Defenses & Village Shop
    if Config.AutoPlaceDefenses then
        CallRemoteFuzzy({ "place_defense", "spawn_defense", "auto_defense" }, Config.DefensesPlaceAt, Config.DefensesPathPos)
    end
    if Config.AutoBuyVillageShop then
        CallRemoteFuzzy({ "buy_village_shop", "village_shop_buy" }, Config.BuyRarities, Config.OnlyBuyByName)
    end

    -- Abilities & Buff Uptime (Commander, Elfy, Gambler, Griffin)
    if (Config.BuffUptime or Config.AutoAbility) and (os.clock() - LastBuffClock) >= 3.0 then
        LastBuffClock = os.clock()
        for _, u in ipairs(GetOwnedUnits()) do
            CallRemoteFuzzy({ "use_active_attack", "activate_ability", "use_ability" }, u)
        end
    end

    -- Wave Rules (Infinite Wave / Farm Sell)
    local curWave = GetCurrentWave()
    if Config.LobbyOnInfiniteWave and curWave >= 50 then
        CallRemoteFuzzy({ "leave_match", "return_lobby" })
    end
    if Config.SellAllUnitsInf and curWave >= 50 then
        for _, u in ipairs(GetOwnedUnits()) do
            CallRemoteFuzzy({ "sell_unit", "sell" }, u)
        end
    end
end

-- ============================================================================
-- 6. BIGFROOT-INSPIRED BENTO UI (ALL TABS & SUB-TABS)
-- ============================================================================
local SessionStart = os.clock()

local function CountActiveFeatures()
    local c = 0
    for _, v in pairs(Config) do
        if v == true then c = c + 1 end
    end
    return c
end

local function BuildBentoHub()
    local guiParent = GetSafeGuiParent()
    if not guiParent then return nil end

    for _, container in ipairs({ guiParent, PlayerGui, CoreGui }) do
        if container then
            local old = container:FindFirstChild("AA_BigFrootBento_Hub")
            if old then pcall(function() old:Destroy() end) end
        end
    end

    local C_SHELL     = Color3.fromRGB(13, 12, 11)
    local C_SIDEBAR   = Color3.fromRGB(18, 16, 15)
    local C_CARD      = Color3.fromRGB(22, 19, 17)
    local C_INPUT     = Color3.fromRGB(31, 27, 24)
    local C_BORDER    = Color3.fromRGB(43, 37, 33)
    local C_ICON_BG   = Color3.fromRGB(48, 28, 16)
    local C_ACCENT    = Color3.fromRGB(242, 107, 33)
    local C_RED_TXT   = Color3.fromRGB(235, 87, 87)
    local C_TEXT      = Color3.fromRGB(244, 240, 236)
    local C_SUBTEXT   = Color3.fromRGB(152, 142, 134)

    local sg = Instance.new("ScreenGui", guiParent)
    sg.Name = "AA_BigFrootBento_Hub"
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true
    sg.DisplayOrder = 999999
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    -- Top Floating Watermark Pill
    local topPill = Instance.new("TextButton", sg)
    topPill.Name = "TopPill"
    topPill.Size = UDim2.new(0, 260, 0, 28)
    topPill.Position = UDim2.new(0.55, -130, 0, 8)
    topPill.BackgroundColor3 = Color3.fromRGB(20, 18, 17)
    topPill.TextColor3 = C_TEXT
    topPill.Font = Enum.Font.GothamSemibold
    topPill.TextSize = 11
    topPill.Text = "  AA Unified  •  Tap to open, hold for stats"
    topPill.Active = true
    topPill.Draggable = true
    Instance.new("UICorner", topPill).CornerRadius = UDim.new(1, 0)
    local pillStroke = Instance.new("UIStroke", topPill)
    pillStroke.Color = C_BORDER
    pillStroke.Thickness = 1

    local pillDot = Instance.new("Frame", topPill)
    pillDot.Size = UDim2.new(0, 6, 0, 6)
    pillDot.Position = UDim2.new(0, 10, 0.5, -3)
    pillDot.BackgroundColor3 = C_ACCENT
    Instance.new("UICorner", pillDot).CornerRadius = UDim.new(1, 0)

    -- Main Window Shell
    local winW = IsMobile and 650 or 810
    local winH = IsMobile and 380 or 505
    local main = Instance.new("Frame", sg)
    main.Name = "MainWindow"
    main.Size = UDim2.new(0, winW, 0, winH)
    main.Position = UDim2.new(0.5, -winW / 2, 0.5, -winH / 2)
    main.BackgroundColor3 = C_SHELL
    main.BorderSizePixel = 0
    main.Active = true
    main.Draggable = true
    Instance.new("UICorner", main).CornerRadius = UDim.new(0, 14)
    local mainStroke = Instance.new("UIStroke", main)
    mainStroke.Color = C_BORDER
    mainStroke.Thickness = 1

    topPill.MouseButton1Click:Connect(function()
        main.Visible = not main.Visible
    end)

    -- ========================================================================
    -- LEFT SIDEBAR
    -- ========================================================================
    local sidebar = Instance.new("Frame", main)
    sidebar.Size = UDim2.new(0, 176, 1, 0)
    sidebar.BackgroundColor3 = C_SIDEBAR
    sidebar.BorderSizePixel = 0
    Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0, 14)

    local brandRow = Instance.new("Frame", sidebar)
    brandRow.Size = UDim2.new(1, -16, 0, 44)
    brandRow.Position = UDim2.new(0, 8, 0, 8)
    brandRow.BackgroundTransparency = 1

    local logoBadge = Instance.new("Frame", brandRow)
    logoBadge.Size = UDim2.new(0, 34, 0, 34)
    logoBadge.Position = UDim2.new(0, 2, 0, 5)
    logoBadge.BackgroundColor3 = C_ICON_BG
    Instance.new("UICorner", logoBadge).CornerRadius = UDim.new(0, 8)
    local logoTxt = Instance.new("TextLabel", logoBadge)
    logoTxt.Size = UDim2.new(1, 0, 1, 0)
    logoTxt.BackgroundTransparency = 1
    logoTxt.Text = "AA"
    logoTxt.TextColor3 = C_ACCENT
    logoTxt.Font = Enum.Font.GothamBold
    logoTxt.TextSize = 14

    local brandName = Instance.new("TextLabel", brandRow)
    brandName.Size = UDim2.new(0, 88, 0, 18)
    brandName.Position = UDim2.new(0, 44, 0, 6)
    brandName.BackgroundTransparency = 1
    brandName.Text = "AA Unified"
    brandName.TextXAlignment = Enum.TextXAlignment.Left
    brandName.TextColor3 = C_TEXT
    brandName.Font = Enum.Font.GothamBold
    brandName.TextSize = 13

    local brandVer = Instance.new("TextLabel", brandRow)
    brandVer.Size = UDim2.new(0, 88, 0, 14)
    brandVer.Position = UDim2.new(0, 44, 0, 23)
    brandVer.BackgroundTransparency = 1
    brandVer.Text = "v1.3.2"
    brandVer.TextXAlignment = Enum.TextXAlignment.Left
    brandVer.TextColor3 = C_SUBTEXT
    brandVer.Font = Enum.Font.Gotham
    brandVer.TextSize = 11

    local collapseBtn = Instance.new("TextButton", brandRow)
    collapseBtn.Size = UDim2.new(0, 22, 0, 22)
    collapseBtn.Position = UDim2.new(1, -24, 0.5, -11)
    collapseBtn.BackgroundColor3 = C_INPUT
    collapseBtn.Text = "<"
    collapseBtn.TextColor3 = C_SUBTEXT
    collapseBtn.Font = Enum.Font.GothamBold
    collapseBtn.TextSize = 11
    Instance.new("UICorner", collapseBtn).CornerRadius = UDim.new(0, 6)
    collapseBtn.MouseButton1Click:Connect(function()
        main.Visible = false
    end)

    local navScroll = Instance.new("ScrollingFrame", sidebar)
    navScroll.Size = UDim2.new(1, -10, 1, -108)
    navScroll.Position = UDim2.new(0, 5, 0, 56)
    navScroll.BackgroundTransparency = 1
    navScroll.ScrollBarThickness = 2
    navScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    navScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    local navList = Instance.new("UIListLayout", navScroll)
    navList.Padding = UDim.new(0, 2)

    local function AddSidebarSectionHeader(titleText)
        local row = Instance.new("Frame", navScroll)
        row.Size = UDim2.new(1, 0, 0, 20)
        row.BackgroundTransparency = 1
        local l1 = Instance.new("TextLabel", row)
        l1.Size = UDim2.new(0.7, 0, 1, 0)
        l1.Position = UDim2.new(0, 8, 0, 0)
        l1.BackgroundTransparency = 1
        l1.Text = titleText
        l1.TextXAlignment = Enum.TextXAlignment.Left
        l1.TextColor3 = C_SUBTEXT
        l1.Font = Enum.Font.GothamSemibold
        l1.TextSize = 11
        local l2 = Instance.new("TextLabel", row)
        l2.Size = UDim2.new(0.3, -8, 1, 0)
        l2.Position = UDim2.new(0.7, 0, 0, 0)
        l2.BackgroundTransparency = 1
        l2.Text = "⌄"
        l2.TextXAlignment = Enum.TextXAlignment.Right
        l2.TextColor3 = C_SUBTEXT
        l2.Font = Enum.Font.GothamBold
        l2.TextSize = 11
    end

    local userCard = Instance.new("Frame", sidebar)
    userCard.Size = UDim2.new(1, -16, 0, 40)
    userCard.Position = UDim2.new(0, 8, 1, -46)
    userCard.BackgroundColor3 = C_CARD
    userCard.BorderSizePixel = 0
    Instance.new("UICorner", userCard).CornerRadius = UDim.new(0, 8)

    local avatarBadge = Instance.new("Frame", userCard)
    avatarBadge.Size = UDim2.new(0, 28, 0, 28)
    avatarBadge.Position = UDim2.new(0, 6, 0.5, -14)
    avatarBadge.BackgroundColor3 = C_INPUT
    Instance.new("UICorner", avatarBadge).CornerRadius = UDim.new(1, 0)
    local avTxt = Instance.new("TextLabel", avatarBadge)
    avTxt.Size = UDim2.new(1, 0, 1, 0)
    avTxt.BackgroundTransparency = 1
    avTxt.Text = LocalPlayer.Name:sub(1, 2):upper()
    avTxt.TextColor3 = C_TEXT
    avTxt.Font = Enum.Font.GothamBold
    avTxt.TextSize = 10

    local maskedUser = LocalPlayer.Name:sub(1, 2) .. string.rep("*", math.max(6, #LocalPlayer.Name - 2))
    local uNameLbl = Instance.new("TextLabel", userCard)
    uNameLbl.Size = UDim2.new(1, -42, 0, 16)
    uNameLbl.Position = UDim2.new(0, 40, 0, 4)
    uNameLbl.BackgroundTransparency = 1
    uNameLbl.Text = maskedUser
    uNameLbl.TextXAlignment = Enum.TextXAlignment.Left
    uNameLbl.TextColor3 = C_TEXT
    uNameLbl.Font = Enum.Font.GothamBold
    uNameLbl.TextSize = 11

    local expLbl = Instance.new("TextLabel", userCard)
    expLbl.Size = UDim2.new(1, -42, 0, 14)
    expLbl.Position = UDim2.new(0, 40, 0, 20)
    expLbl.BackgroundTransparency = 1
    expLbl.RichText = true
    expLbl.Text = 'Expires: <font color="#F26B21">lifetime</font>'
    expLbl.TextXAlignment = Enum.TextXAlignment.Left
    expLbl.TextColor3 = C_SUBTEXT
    expLbl.Font = Enum.Font.Gotham
    expLbl.TextSize = 10

    -- ========================================================================
    -- TOP HEADER BAR & BENTO PAGE HOLDER
    -- ========================================================================
    local topBar = Instance.new("Frame", main)
    topBar.Size = UDim2.new(1, -192, 0, 38)
    topBar.Position = UDim2.new(0, 184, 0, 8)
    topBar.BackgroundTransparency = 1

    local breadcrumb = Instance.new("TextLabel", topBar)
    breadcrumb.Size = UDim2.new(0.62, 0, 1, 0)
    breadcrumb.BackgroundTransparency = 1
    breadcrumb.RichText = true
    breadcrumb.Text = '<b>Home</b>'
    breadcrumb.TextXAlignment = Enum.TextXAlignment.Left
    breadcrumb.TextColor3 = C_TEXT
    breadcrumb.Font = Enum.Font.Gotham
    breadcrumb.TextSize = 15

    local searchBox = Instance.new("TextBox", topBar)
    searchBox.Size = UDim2.new(0.36, 0, 0, 28)
    searchBox.Position = UDim2.new(0.64, 0, 0.5, -14)
    searchBox.BackgroundColor3 = C_CARD
    searchBox.TextColor3 = C_TEXT
    searchBox.PlaceholderText = "🔍  search..."
    searchBox.PlaceholderColor3 = C_SUBTEXT
    searchBox.Text = ""
    searchBox.TextXAlignment = Enum.TextXAlignment.Left
    searchBox.Font = Enum.Font.Gotham
    searchBox.TextSize = 11
    searchBox.ClearTextOnFocus = false
    Instance.new("UICorner", searchBox).CornerRadius = UDim.new(0, 8)
    local sbStroke = Instance.new("UIStroke", searchBox)
    sbStroke.Color = C_BORDER
    sbStroke.Thickness = 1
    Instance.new("UIPadding", searchBox).PaddingLeft = UDim.new(0, 10)

    local pageHolder = Instance.new("Frame", main)
    pageHolder.Size = UDim2.new(1, -192, 1, -54)
    pageHolder.Position = UDim2.new(0, 184, 0, 48)
    pageHolder.BackgroundTransparency = 1

    local Pages = {}
    local NavItems = {}
    local AllSearchableRows = {}

    local function CreateBentoPage(pageKey, parentTitle, subTitle)
        local sf = Instance.new("ScrollingFrame", pageHolder)
        sf.Name = pageKey
        sf.Size = UDim2.new(1, 0, 1, 0)
        sf.BackgroundTransparency = 1
        sf.ScrollBarThickness = 3
        sf.ScrollBarImageColor3 = C_BORDER
        sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
        sf.CanvasSize = UDim2.new(0, 0, 0, 0)
        sf.Visible = false

        local twoCol = Instance.new("Frame", sf)
        twoCol.Size = UDim2.new(1, -6, 0, 0)
        twoCol.AutomaticSize = Enum.AutomaticSize.Y
        twoCol.BackgroundTransparency = 1

        local leftCol = Instance.new("Frame", twoCol)
        leftCol.Size = UDim2.new(0.51, -5, 0, 0)
        leftCol.AutomaticSize = Enum.AutomaticSize.Y
        leftCol.BackgroundTransparency = 1
        local lLayout = Instance.new("UIListLayout", leftCol)
        lLayout.Padding = UDim.new(0, 10)

        local rightCol = Instance.new("Frame", twoCol)
        rightCol.Size = UDim2.new(0.49, -5, 0, 0)
        rightCol.Position = UDim2.new(0.51, 5, 0, 0)
        rightCol.AutomaticSize = Enum.AutomaticSize.Y
        rightCol.BackgroundTransparency = 1
        local rLayout = Instance.new("UIListLayout", rightCol)
        rLayout.Padding = UDim.new(0, 10)

        Pages[pageKey] = {
            Scroll = sf,
            Left = leftCol,
            Right = rightCol,
            ParentTitle = parentTitle,
            SubTitle = subTitle
        }
        return Pages[pageKey]
    end

    local function SelectPage(pageKey)
        local info = Pages[pageKey]
        if not info then return end

        if info.SubTitle then
            breadcrumb.Text = string.format('<b>%s</b>  <font color="#988E86">›  %s</font>', info.ParentTitle, info.SubTitle)
        else
            breadcrumb.Text = string.format('<b>%s</b>', info.ParentTitle)
        end

        for k, pg in pairs(Pages) do
            pg.Scroll.Visible = (k == pageKey)
        end

        for k, item in pairs(NavItems) do
            local isSelected = (k == pageKey) or (item.DefaultSubKey == pageKey)
            item.TxtLbl.TextColor3 = isSelected and C_TEXT or C_SUBTEXT
            item.IconLbl.TextColor3 = isSelected and C_ACCENT or C_SUBTEXT
            item.AccentBar.Visible = (k == pageKey)
        end
    end

    local function AddSidebarNav(pageKey, iconGlyph, labelText, isSubItem, defaultSubKey)
        local btn = Instance.new("TextButton", navScroll)
        btn.Size = UDim2.new(1, 0, 0, isSubItem and 24 or 28)
        btn.BackgroundColor3 = C_SIDEBAR
        btn.Text = ""
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

        local accentBar = Instance.new("Frame", btn)
        accentBar.Size = UDim2.new(0, 3, 0, 16)
        accentBar.Position = UDim2.new(0, 0, 0.5, -8)
        accentBar.BackgroundColor3 = C_ACCENT
        accentBar.BorderSizePixel = 0
        accentBar.Visible = false
        Instance.new("UICorner", accentBar).CornerRadius = UDim.new(1, 0)

        local xPad = isSubItem and 22 or 10
        local iconLbl = Instance.new("TextLabel", btn)
        iconLbl.Size = UDim2.new(0, 18, 1, 0)
        iconLbl.Position = UDim2.new(0, xPad, 0, 0)
        iconLbl.BackgroundTransparency = 1
        iconLbl.Text = iconGlyph
        iconLbl.TextColor3 = C_SUBTEXT
        iconLbl.Font = Enum.Font.GothamBold
        iconLbl.TextSize = 12

        local txtLbl = Instance.new("TextLabel", btn)
        txtLbl.Size = UDim2.new(1, -(xPad + 22), 1, 0)
        txtLbl.Position = UDim2.new(0, xPad + 22, 0, 0)
        txtLbl.BackgroundTransparency = 1
        txtLbl.Text = labelText
        txtLbl.TextXAlignment = Enum.TextXAlignment.Left
        txtLbl.TextColor3 = C_SUBTEXT
        txtLbl.Font = isSubItem and Enum.Font.Gotham or Enum.Font.GothamSemibold
        txtLbl.TextSize = isSubItem and 11 or 12

        NavItems[pageKey] = {
            Btn = btn,
            AccentBar = accentBar,
            IconLbl = iconLbl,
            TxtLbl = txtLbl,
            DefaultSubKey = defaultSubKey
        }

        btn.MouseButton1Click:Connect(function()
            SelectPage(defaultSubKey or pageKey)
        end)

        return btn
    end

    -- ========================================================================
    -- BENTO CARD & CONTROL FACTORIES
    -- ========================================================================
    local function CreateBentoCard(parentCol, iconGlyph, cardTitle)
        local card = Instance.new("Frame", parentCol)
        card.Size = UDim2.new(1, 0, 0, 0)
        card.AutomaticSize = Enum.AutomaticSize.Y
        card.BackgroundColor3 = C_CARD
        card.BorderSizePixel = 0
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)
        local stroke = Instance.new("UIStroke", card)
        stroke.Color = C_BORDER
        stroke.Thickness = 1

        local pad = Instance.new("UIPadding", card)
        pad.PaddingTop = UDim.new(0, 10)
        pad.PaddingBottom = UDim.new(0, 12)
        pad.PaddingLeft = UDim.new(0, 12)
        pad.PaddingRight = UDim.new(0, 12)

        local list = Instance.new("UIListLayout", card)
        list.Padding = UDim.new(0, 8)

        local hdr = Instance.new("Frame", card)
        hdr.Size = UDim2.new(1, 0, 0, 26)
        hdr.BackgroundTransparency = 1

        local badge = Instance.new("Frame", hdr)
        badge.Size = UDim2.new(0, 24, 0, 24)
        badge.Position = UDim2.new(0, 0, 0.5, -12)
        badge.BackgroundColor3 = C_ICON_BG
        Instance.new("UICorner", badge).CornerRadius = UDim.new(0, 6)

        local badgeIcon = Instance.new("TextLabel", badge)
        badgeIcon.Size = UDim2.new(1, 0, 1, 0)
        badgeIcon.BackgroundTransparency = 1
        badgeIcon.Text = iconGlyph
        badgeIcon.TextColor3 = C_ACCENT
        badgeIcon.Font = Enum.Font.GothamBold
        badgeIcon.TextSize = 12

        local titleLbl = Instance.new("TextLabel", hdr)
        titleLbl.Size = UDim2.new(1, -52, 1, 0)
        titleLbl.Position = UDim2.new(0, 32, 0, 0)
        titleLbl.BackgroundTransparency = 1
        titleLbl.Text = cardTitle
        titleLbl.TextXAlignment = Enum.TextXAlignment.Left
        titleLbl.TextColor3 = C_TEXT
        titleLbl.Font = Enum.Font.GothamBold
        titleLbl.TextSize = 13

        local chev = Instance.new("TextLabel", hdr)
        chev.Size = UDim2.new(0, 18, 1, 0)
        chev.Position = UDim2.new(1, -18, 0, 0)
        chev.BackgroundTransparency = 1
        chev.Text = "⌄"
        chev.TextColor3 = C_SUBTEXT
        chev.Font = Enum.Font.GothamBold
        chev.TextSize = 13

        return card
    end

    local function AddSubLabel(card, text)
        local lbl = Instance.new("TextLabel", card)
        lbl.Size = UDim2.new(1, 0, 0, 14)
        lbl.BackgroundTransparency = 1
        lbl.Text = text
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextColor3 = C_SUBTEXT
        lbl.Font = Enum.Font.GothamSemibold
        lbl.TextSize = 11
        return lbl
    end

    local function AddFieldLabel(card, text)
        local lbl = Instance.new("TextLabel", card)
        lbl.Size = UDim2.new(1, 0, 0, 16)
        lbl.BackgroundTransparency = 1
        lbl.Text = text
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextColor3 = C_TEXT
        lbl.Font = Enum.Font.GothamSemibold
        lbl.TextSize = 11
        return lbl
    end

    local function AddToggle(card, labelText, initialState, onChanged)
        local row = Instance.new("Frame", card)
        row.Size = UDim2.new(1, 0, 0, 24)
        row.BackgroundTransparency = 1
        table.insert(AllSearchableRows, { Frame = row, Text = labelText:lower() })

        local lbl = Instance.new("TextLabel", row)
        lbl.Size = UDim2.new(1, -48, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = labelText
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextColor3 = C_TEXT
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 12

        local pillBtn = Instance.new("TextButton", row)
        pillBtn.Size = UDim2.new(0, 38, 0, 20)
        pillBtn.Position = UDim2.new(1, -38, 0.5, -10)
        pillBtn.Text = ""
        pillBtn.BackgroundColor3 = initialState and C_ACCENT or C_INPUT
        Instance.new("UICorner", pillBtn).CornerRadius = UDim.new(1, 0)

        local knob = Instance.new("Frame", pillBtn)
        knob.Size = UDim2.new(0, 14, 0, 14)
        knob.Position = initialState and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)
        knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

        local state = initialState
        pillBtn.MouseButton1Click:Connect(function()
            state = not state
            pillBtn.BackgroundColor3 = state and C_ACCENT or C_INPUT
            knob.Position = state and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)
            onChanged(state)
            SaveConfig()
        end)

        return {
            Set = function(v)
                state = v
                pillBtn.BackgroundColor3 = state and C_ACCENT or C_INPUT
                knob.Position = state and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)
            end
        }
    end

    local function AddDropdownBox(card, getOptionsFn, currentVal, onChanged)
        local btn = Instance.new("TextButton", card)
        btn.Size = UDim2.new(1, 0, 0, 30)
        btn.BackgroundColor3 = C_INPUT
        btn.Text = ""
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 7)
        local st = Instance.new("UIStroke", btn)
        st.Color = C_BORDER
        st.Thickness = 1

        local valLbl = Instance.new("TextLabel", btn)
        valLbl.Size = UDim2.new(1, -28, 1, 0)
        valLbl.Position = UDim2.new(0, 10, 0, 0)
        valLbl.BackgroundTransparency = 1
        valLbl.Text = tostring(currentVal or "--")
        valLbl.TextXAlignment = Enum.TextXAlignment.Left
        valLbl.TextColor3 = C_TEXT
        valLbl.Font = Enum.Font.Gotham
        valLbl.TextSize = 12

        local arrow = Instance.new("TextLabel", btn)
        arrow.Size = UDim2.new(0, 20, 1, 0)
        arrow.Position = UDim2.new(1, -22, 0, 0)
        arrow.BackgroundTransparency = 1
        arrow.Text = "⌄"
        arrow.TextColor3 = C_SUBTEXT
        arrow.Font = Enum.Font.GothamBold
        arrow.TextSize = 12

        local selected = currentVal
        btn.MouseButton1Click:Connect(function()
            local opts = type(getOptionsFn) == "function" and getOptionsFn() or getOptionsFn
            if type(opts) ~= "table" or #opts == 0 then return end
            local idx = 1
            for i, o in ipairs(opts) do
                if o == selected then idx = i end
            end
            idx = (idx % #opts) + 1
            selected = opts[idx]
            valLbl.Text = tostring(selected)
            onChanged(selected)
            SaveConfig()
        end)

        return {
            Set = function(v)
                selected = v
                valLbl.Text = tostring(v)
            end
        }
    end

    local function AddSlider(card, labelText, minVal, maxVal, currentVal, suffix, zeroWord, onChanged)
        local container = Instance.new("Frame", card)
        container.Size = UDim2.new(1, 0, 0, 36)
        container.BackgroundTransparency = 1
        table.insert(AllSearchableRows, { Frame = container, Text = labelText:lower() })

        local topRow = Instance.new("Frame", container)
        topRow.Size = UDim2.new(1, 0, 0, 18)
        topRow.BackgroundTransparency = 1

        local lbl = Instance.new("TextLabel", topRow)
        lbl.Size = UDim2.new(0.72, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = labelText
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextColor3 = C_TEXT
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 12

        local valPill = Instance.new("TextLabel", topRow)
        valPill.Size = UDim2.new(0.28, 0, 1, 0)
        valPill.Position = UDim2.new(0.72, 0, 0, 0)
        valPill.BackgroundColor3 = C_INPUT
        valPill.TextColor3 = C_TEXT
        valPill.Font = Enum.Font.GothamSemibold
        valPill.TextSize = 11
        Instance.new("UICorner", valPill).CornerRadius = UDim.new(0, 5)

        local track = Instance.new("Frame", container)
        track.Size = UDim2.new(1, 0, 0, 5)
        track.Position = UDim2.new(0, 0, 0, 25)
        track.BackgroundColor3 = C_INPUT
        track.BorderSizePixel = 0
        Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

        local fill = Instance.new("Frame", track)
        fill.Size = UDim2.new(0, 0, 1, 0)
        fill.BackgroundColor3 = C_ACCENT
        fill.BorderSizePixel = 0
        Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

        local knob = Instance.new("Frame", fill)
        knob.Size = UDim2.new(0, 12, 0, 12)
        knob.Position = UDim2.new(1, -6, 0.5, -6)
        knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

        local dragging = false
        local value = math.clamp(currentVal or minVal, minVal, maxVal)

        local function ApplyValue(v, saveIt)
            value = math.clamp(math.floor(v + 0.5), minVal, maxVal)
            local alpha = (maxVal > minVal) and ((value - minVal) / (maxVal - minVal)) or 0
            fill.Size = UDim2.new(alpha, 0, 1, 0)
            if zeroWord and value == 0 then
                valPill.Text = zeroWord
            else
                valPill.Text = tostring(value) .. (suffix or "")
            end
            onChanged(value)
            if saveIt then SaveConfig() end
        end

        ApplyValue(value, false)

        local function UpdateInput(input)
            local absPos = track.AbsolutePosition.X
            local absSize = track.AbsoluteSize.X
            if absSize <= 0 then return end
            local rel = math.clamp((input.Position.X - absPos) / absSize, 0, 1)
            ApplyValue(minVal + rel * (maxVal - minVal), false)
        end

        track.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                UpdateInput(input)
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                UpdateInput(input)
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
                dragging = false
                SaveConfig()
            end
        end)

        return { SetValue = function(v) ApplyValue(v, false) end }
    end

    local function AddTextBox(card, placeholderText, initialText, onChanged)
        local tb = Instance.new("TextBox", card)
        tb.Size = UDim2.new(1, 0, 0, 30)
        tb.BackgroundColor3 = C_INPUT
        tb.TextColor3 = C_TEXT
        tb.PlaceholderText = placeholderText
        tb.PlaceholderColor3 = C_SUBTEXT
        tb.Text = initialText or ""
        tb.TextXAlignment = Enum.TextXAlignment.Left
        tb.Font = Enum.Font.Gotham
        tb.TextSize = 11
        tb.ClearTextOnFocus = false
        Instance.new("UICorner", tb).CornerRadius = UDim.new(0, 7)
        Instance.new("UIPadding", tb).PaddingLeft = UDim.new(0, 10)
        tb.FocusLost:Connect(function()
            onChanged(tb.Text)
            SaveConfig()
        end)
        return tb
    end

    local function AddActionBtn(parentObj, txt, txtColor, cb)
        local b = Instance.new("TextButton", parentObj)
        b.Size = UDim2.new(1, 0, 0, 30)
        b.BackgroundColor3 = C_INPUT
        b.Text = txt
        b.TextColor3 = txtColor or C_TEXT
        b.Font = Enum.Font.GothamSemibold
        b.TextSize = 11
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 7)
        b.MouseButton1Click:Connect(cb)
        return b
    end

    local function GetServerPlayerNames()
        local list = { "--" }
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                table.insert(list, p.Name)
            end
        end
        return list
    end

    -- ========================================================================
    -- REGISTER ALL PAGES & SIDEBAR TREE
    -- ========================================================================
    local pgHome          = CreateBentoPage("Home", "Home", nil)
    local pgMacroRec      = CreateBentoPage("MacroRecord", "Macro", "Record / Play")
    local pgMacroMaps     = CreateBentoPage("MacroMaps", "Macro", "Macro Maps")
    local pgAutoAll       = CreateBentoPage("AutoAll", "Auto Play", "All Modes")
    local pgAutoEvent     = CreateBentoPage("AutoEvent", "Auto Play", "Event")

    local pgJoinStory     = CreateBentoPage("JoinStory", "Join", "Story / Challenges")
    local pgJoinParty     = CreateBentoPage("JoinParty", "Join", "Party")
    local pgJoinEvents    = CreateBentoPage("JoinEvents", "Join", "Castle / Events")
    local pgJoinDungeon   = CreateBentoPage("JoinDungeon", "Join", "Dungeon")
    local pgJoinTeams     = CreateBentoPage("JoinTeams", "Join", "Teams")
    local pgJoinVillage   = CreateBentoPage("JoinVillage", "Join", "Swordsmith")

    local pgPriority      = CreateBentoPage("Priority", "Priority", nil)
    local pgGame          = CreateBentoPage("Game", "Game", nil)
    local pgLobby         = CreateBentoPage("Lobby", "Lobby", nil)
    local pgWebhook       = CreateBentoPage("Webhook", "Webhook", nil)
    local pgMisc          = CreateBentoPage("Misc", "Misc", nil)

    AddSidebarSectionHeader("Main")
    AddSidebarNav("Home",          "⌂", "Home", false)
    AddSidebarNav("Macro",         "⇄", "Macro", false, "MacroRecord")
    AddSidebarNav("MacroRecord",   "⇄", "Record / Play", true)
    AddSidebarNav("MacroMaps",     "🗺", "Macro Maps", true)
    AddSidebarNav("AutoPlay",      "🤖", "Auto Play", false, "AutoAll")
    AddSidebarNav("AutoAll",       "🤖", "All Modes", true)
    AddSidebarNav("AutoEvent",     "✦", "Event", true)

    AddSidebarNav("Join",          "🚀", "Join", false, "JoinStory")
    AddSidebarNav("JoinStory",     "🚀", "Story / Challenges", true)
    AddSidebarNav("JoinParty",     "👤", "Party", true)
    AddSidebarNav("JoinEvents",    "👑", "Castle / Events", true)
    AddSidebarNav("JoinDungeon",   "💀", "Dungeon", true)
    AddSidebarNav("JoinTeams",     "👥", "Teams", true)
    AddSidebarNav("JoinVillage",   "⚔", "Swordsmith", true)

    AddSidebarNav("Priority",      "🏅", "Priority", false)
    AddSidebarNav("Game",          "🎮", "Game", false)
    AddSidebarNav("Lobby",         "🏪", "Lobby", false)
    AddSidebarNav("Webhook",       "🔔", "Webhook", false)
    AddSidebarNav("Misc",          "🔧", "Misc", false)
    AddSidebarSectionHeader("Other")

    -- ========================================================================
    -- PAGE 1: HOME
    -- ========================================================================
    local annCard = CreateBentoCard(pgHome.Left, "🔔", "Announcements")
    local rel1Title = Instance.new("TextLabel", annCard)
    rel1Title.Size = UDim2.new(1, 0, 0, 16)
    rel1Title.BackgroundTransparency = 1
    rel1Title.Text = "v1.3.2"
    rel1Title.TextXAlignment = Enum.TextXAlignment.Left
    rel1Title.TextColor3 = C_TEXT
    rel1Title.Font = Enum.Font.GothamBold
    rel1Title.TextSize = 12

    local rel1Date = Instance.new("TextLabel", annCard)
    rel1Date.Size = UDim2.new(1, 0, 0, 14)
    rel1Date.BackgroundTransparency = 1
    rel1Date.Text = "2026-11-25"
    rel1Date.TextXAlignment = Enum.TextXAlignment.Left
    rel1Date.TextColor3 = C_SUBTEXT
    rel1Date.Font = Enum.Font.Gotham
    rel1Date.TextSize = 11

    local rel1Notes = Instance.new("TextLabel", annCard)
    rel1Notes.Size = UDim2.new(1, 0, 0, 56)
    rel1Notes.BackgroundTransparency = 1
    rel1Notes.TextWrapped = true
    rel1Notes.TextXAlignment = Enum.TextXAlignment.Left
    rel1Notes.TextYAlignment = Enum.TextYAlignment.Top
    rel1Notes.TextColor3 = C_SUBTEXT
    rel1Notes.Font = Enum.Font.Gotham
    rel1Notes.TextSize = 11
    rel1Notes.Text = "+ Defenses: Place At (Damage Units / Path Position)\n+ Village Shop: Buy Rarities\n+ Village Shop: Only Buy (by name)"

    local divider = Instance.new("Frame", annCard)
    divider.Size = UDim2.new(1, 0, 0, 1)
    divider.BackgroundColor3 = C_BORDER
    divider.BorderSizePixel = 0

    local rel2Title = Instance.new("TextLabel", annCard)
    rel2Title.Size = UDim2.new(1, 0, 0, 16)
    rel2Title.BackgroundTransparency = 1
    rel2Title.Text = "v1.3.1"
    rel2Title.TextXAlignment = Enum.TextXAlignment.Left
    rel2Title.TextColor3 = C_TEXT
    rel2Title.Font = Enum.Font.GothamBold
    rel2Title.TextSize = 12

    local rel2Date = Instance.new("TextLabel", annCard)
    rel2Date.Size = UDim2.new(1, 0, 0, 14)
    rel2Date.BackgroundTransparency = 1
    rel2Date.Text = "2026-11-24"
    rel2Date.TextXAlignment = Enum.TextXAlignment.Left
    rel2Date.TextColor3 = C_SUBTEXT
    rel2Date.Font = Enum.Font.Gotham
    rel2Date.TextSize = 11

    local rel2Notes = Instance.new("TextLabel", annCard)
    rel2Notes.Size = UDim2.new(1, 0, 0, 62)
    rel2Notes.BackgroundTransparency = 1
    rel2Notes.TextWrapped = true
    rel2Notes.TextXAlignment = Enum.TextXAlignment.Left
    rel2Notes.TextYAlignment = Enum.TextYAlignment.Top
    rel2Notes.TextColor3 = C_SUBTEXT
    rel2Notes.Font = Enum.Font.Gotham
    rel2Notes.TextSize = 11
    rel2Notes.Text = "+ Fixed Auto Place Defenses\n+ Fixed traps stalling at the base\n+ Fixed slow Misty Tower joins\n+ Fixed Auto Repair on broken defenses"

    local quickCard = CreateBentoCard(pgHome.Left, "⚡", "Quick actions")
    local qGrid = Instance.new("Frame", quickCard)
    qGrid.Size = UDim2.new(1, 0, 0, 66)
    qGrid.BackgroundTransparency = 1
    local qLayout = Instance.new("UIGridLayout", qGrid)
    qLayout.CellSize = UDim2.new(0.5, -4, 0, 29)
    qLayout.CellPadding = UDim2.new(0, 6, 0, 6)

    AddActionBtn(qGrid, "Copy Discord", C_TEXT, function() SafeSetClipboard("https://discord.gg/") end)
    AddActionBtn(qGrid, "Load last config", C_TEXT, function() LoadConfig() end)
    AddActionBtn(qGrid, "Rejoin", C_TEXT, function() RejoinCurrentServer() end)
    AddActionBtn(qGrid, "Server hop", C_TEXT, function() HopToDifferentServer() end)
    AddActionBtn(quickCard, "Toggle watermark", C_TEXT, function() topPill.Visible = not topPill.Visible end)

    local statusCard = CreateBentoCard(pgHome.Right, "🕒", "Status")
    local statusGrid = Instance.new("Frame", statusCard)
    statusGrid.Size = UDim2.new(1, 0, 0, 96)
    statusGrid.BackgroundTransparency = 1
    local sLayout = Instance.new("UIGridLayout", statusGrid)
    sLayout.CellSize = UDim2.new(0.333, -4, 0, 44)
    sLayout.CellPadding = UDim2.new(0, 5, 0, 6)

    local function MakeMetricTile(parentGrid, bigTxt, subTxt)
        local tile = Instance.new("Frame", parentGrid)
        tile.BackgroundColor3 = C_INPUT
        Instance.new("UICorner", tile).CornerRadius = UDim.new(0, 7)
        local t1 = Instance.new("TextLabel", tile)
        t1.Size = UDim2.new(1, -8, 0, 20)
        t1.Position = UDim2.new(0, 7, 0, 4)
        t1.BackgroundTransparency = 1
        t1.Text = bigTxt
        t1.TextXAlignment = Enum.TextXAlignment.Left
        t1.TextColor3 = C_TEXT
        t1.Font = Enum.Font.GothamBold
        t1.TextSize = 12
        local t2 = Instance.new("TextLabel", tile)
        t2.Size = UDim2.new(1, -8, 0, 14)
        t2.Position = UDim2.new(0, 7, 0, 24)
        t2.BackgroundTransparency = 1
        t2.Text = subTxt
        t2.TextXAlignment = Enum.TextXAlignment.Left
        t2.TextColor3 = C_SUBTEXT
        t2.Font = Enum.Font.Gotham
        t2.TextSize = 10
        return t1
    end

    local mSession = MakeMetricTile(statusGrid, "0m 0s", "session")
    local mFeat    = MakeMetricTile(statusGrid, "0", "features on")
    local mFps     = MakeMetricTile(statusGrid, "60", "fps")
    local mPing    = MakeMetricTile(statusGrid, "0 ms", "ping")
    local mPlayers = MakeMetricTile(statusGrid, tostring(#Players:GetPlayers()) .. "/30", "players")
    local mKey     = MakeMetricTile(statusGrid, "lifetime", "key time")

    local statsCard = CreateBentoCard(pgHome.Right, "📊", "Stats")
    local statsGrid = Instance.new("Frame", statsCard)
    statsGrid.Size = UDim2.new(1, 0, 0, 46)
    statsGrid.BackgroundTransparency = 1
    local stLayout = Instance.new("UIGridLayout", statsGrid)
    stLayout.CellSize = UDim2.new(0.333, -4, 0, 44)
    stLayout.CellPadding = UDim2.new(0, 5, 0, 6)
    local mRuns  = MakeMetricTile(statsGrid, "0", "Runs")
    local mWave  = MakeMetricTile(statsGrid, "0", "Wave")
    local mSteps = MakeMetricTile(statsGrid, "0", "Macro Steps")

    local acctCard = CreateBentoCard(pgHome.Right, "🔑", "Account")
    local keyRow = Instance.new("Frame", acctCard)
    keyRow.Size = UDim2.new(1, 0, 0, 18)
    keyRow.BackgroundTransparency = 1
    local keyLeft = Instance.new("TextLabel", keyRow)
    keyLeft.Size = UDim2.new(0.5, 0, 1, 0)
    keyLeft.BackgroundTransparency = 1
    keyLeft.Text = "Key status"
    keyLeft.TextXAlignment = Enum.TextXAlignment.Left
    keyLeft.TextColor3 = C_TEXT
    keyLeft.Font = Enum.Font.Gotham
    keyLeft.TextSize = 12
    local keyRight = Instance.new("TextLabel", keyRow)
    keyRight.Size = UDim2.new(0.5, 0, 1, 0)
    keyRight.Position = UDim2.new(0.5, 0, 0, 0)
    keyRight.BackgroundTransparency = 1
    keyRight.Text = Config.KeyStatus
    keyRight.TextXAlignment = Enum.TextXAlignment.Right
    keyRight.TextColor3 = C_TEXT
    keyRight.Font = Enum.Font.GothamSemibold
    keyRight.TextSize = 12

    local keyBox = AddTextBox(acctCard, "enter license key...", Config.SavedKey, function(txt)
        Config.SavedKey = txt
    end)
    keyBox.Visible = false

    local repKeyBtn
    repKeyBtn = AddActionBtn(acctCard, "Replace key", C_TEXT, function()
        if not keyBox.Visible then
            keyBox.Visible = true
            repKeyBtn.Text = "Save key"
        else
            local k = keyBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
            Config.SavedKey = k
            Config.KeyStatus = (k ~= "") and "Active" or "Free"
            keyRight.Text = Config.KeyStatus
            keyBox.Visible = false
            repKeyBtn.Text = "Replace key"
            SaveConfig()
        end
    end)

    -- ========================================================================
    -- PAGE 2 & 3: MACRO (RECORD / PLAY & MACRO MAPS)
    -- ========================================================================
    local macroLeft = CreateBentoCard(pgMacroRec.Left, "⇄", "Macro")
    AddSubLabel(macroLeft, "Files")
    AddFieldLabel(macroLeft, "Macro")
    local macroDropdown = AddDropdownBox(macroLeft, function()
        local list = ListSavedMacros()
        return #list == 0 and { "--" } or list
    end, Config.SelectedMacro, function(chosen)
        Config.SelectedMacro = chosen
        MacroEngine.Steps = LoadMacroFile(chosen)
        MacroEngine.PlayIndex = 1
        NotifyStepsChanged()
    end)

    AddFieldLabel(macroLeft, "Name")
    local macroNameBox = AddTextBox(macroLeft, "new macro name", "", function() end)

    local cdRow = Instance.new("Frame", macroLeft)
    cdRow.Size = UDim2.new(1, 0, 0, 30)
    cdRow.BackgroundTransparency = 1
    local createBtn = AddActionBtn(cdRow, "Create", C_TEXT, function()
        local nm = macroNameBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
        if nm == "" then return end
        Config.SelectedMacro = nm
        MacroEngine.Steps = {}
        MacroEngine.PlayIndex = 1
        SaveMacroFile(nm, {})
        SaveConfig()
        macroDropdown.Set(nm)
        NotifyStepsChanged()
    end)
    createBtn.Size = UDim2.new(0.5, -3, 1, 0)

    local deleteBtn = AddActionBtn(cdRow, "Delete", C_RED_TXT, function()
        SafeDeleteFile(GetMacroFilename(Config.SelectedMacro))
        local list = ListSavedMacros()
        Config.SelectedMacro = list[1] or "--"
        MacroEngine.Steps = LoadMacroFile(Config.SelectedMacro)
        MacroEngine.PlayIndex = 1
        SaveConfig()
        macroDropdown.Set(Config.SelectedMacro)
        NotifyStepsChanged()
    end)
    deleteBtn.Size = UDim2.new(0.5, -3, 1, 0)
    deleteBtn.Position = UDim2.new(0.5, 3, 0, 0)

    AddActionBtn(macroLeft, "Refresh List", C_TEXT, function()
        local list = ListSavedMacros()
        if Config.SelectedMacro == "--" and list[1] then Config.SelectedMacro = list[1] end
        macroDropdown.Set(Config.SelectedMacro)
        MacroEngine.Steps = LoadMacroFile(Config.SelectedMacro)
        NotifyStepsChanged()
    end)

    AddSubLabel(macroLeft, "Run")
    local recTgl, playTgl
    recTgl = AddToggle(macroLeft, "Record Macro", Config.RecordMacro, function(val)
        Config.RecordMacro = val
        if val then
            Config.PlayMacro = false
            if playTgl then playTgl.Set(false) end
            InstallMacroHook()
            MacroEngine.Steps = {}
            MacroEngine.StartClock = os.clock()
            NotifyStepsChanged()
        else
            SaveMacroFile(Config.SelectedMacro, MacroEngine.Steps)
            NotifyStepsChanged()
        end
    end)
    playTgl = AddToggle(macroLeft, "Play Macro", Config.PlayMacro, function(val)
        Config.PlayMacro = val
        if val then
            Config.RecordMacro = false
            if recTgl then recTgl.Set(false) end
            MacroEngine.Steps = LoadMacroFile(Config.SelectedMacro)
            MacroEngine.PlayIndex = 1
            MacroEngine.PlayStartClock = os.clock()
            NotifyStepsChanged()
        end
    end)
    AddToggle(macroLeft, "Equip Macro Units", Config.EquipMacroUnits, function(val) Config.EquipMacroUnits = val end)
    AddFieldLabel(macroLeft, "Play By")
    AddDropdownBox(macroLeft, { "Money", "Time" }, Config.PlayBy, function(val) Config.PlayBy = val end)

    local statusRow = Instance.new("Frame", macroLeft)
    statusRow.Size = UDim2.new(1, 0, 0, 22)
    statusRow.BackgroundTransparency = 1
    local mLbl = Instance.new("TextLabel", statusRow)
    mLbl.Size = UDim2.new(0.5, 0, 1, 0)
    mLbl.BackgroundTransparency = 1
    mLbl.Text = "Macro"
    mLbl.TextXAlignment = Enum.TextXAlignment.Left
    mLbl.TextColor3 = C_TEXT
    mLbl.Font = Enum.Font.Gotham
    mLbl.TextSize = 12

    local idlePill = Instance.new("TextLabel", statusRow)
    idlePill.Size = UDim2.new(0, 62, 0, 20)
    idlePill.Position = UDim2.new(1, -62, 0.5, -10)
    idlePill.BackgroundColor3 = C_INPUT
    idlePill.Text = "• idle"
    idlePill.TextColor3 = C_SUBTEXT
    idlePill.Font = Enum.Font.GothamSemibold
    idlePill.TextSize = 11
    Instance.new("UICorner", idlePill).CornerRadius = UDim.new(1, 0)

    local stepRow = Instance.new("Frame", macroLeft)
    stepRow.Size = UDim2.new(1, 0, 0, 26)
    stepRow.BackgroundTransparency = 1
    local sLeft = Instance.new("TextLabel", stepRow)
    sLeft.Size = UDim2.new(0.5, 0, 0, 16)
    sLeft.BackgroundTransparency = 1
    sLeft.Text = "Step"
    sLeft.TextXAlignment = Enum.TextXAlignment.Left
    sLeft.TextColor3 = C_TEXT
    sLeft.Font = Enum.Font.Gotham
    sLeft.TextSize = 12

    local sRight = Instance.new("TextLabel", stepRow)
    sRight.Size = UDim2.new(0.5, 0, 0, 16)
    sRight.Position = UDim2.new(0.5, 0, 0, 0)
    sRight.BackgroundTransparency = 1
    sRight.Text = "0 / 1"
    sRight.TextXAlignment = Enum.TextXAlignment.Right
    sRight.TextColor3 = C_TEXT
    sRight.Font = Enum.Font.GothamSemibold
    sRight.TextSize = 11

    local progTrack = Instance.new("Frame", stepRow)
    progTrack.Size = UDim2.new(1, 0, 0, 4)
    progTrack.Position = UDim2.new(0, 0, 0, 20)
    progTrack.BackgroundColor3 = C_INPUT
    progTrack.BorderSizePixel = 0
    Instance.new("UICorner", progTrack).CornerRadius = UDim.new(1, 0)

    local progFill = Instance.new("Frame", progTrack)
    progFill.Size = UDim2.new(0, 0, 1, 0)
    progFill.BackgroundColor3 = C_ACCENT
    progFill.BorderSizePixel = 0
    Instance.new("UICorner", progFill).CornerRadius = UDim.new(1, 0)

    local stepsCard = CreateBentoCard(pgMacroRec.Right, "☰", "Steps")
    AddFieldLabel(stepsCard, "Picked macro")
    local colHdr = Instance.new("TextLabel", stepsCard)
    colHdr.Size = UDim2.new(1, 0, 0, 16)
    colHdr.BackgroundTransparency = 1
    colHdr.Text = "  #    Action     Unit              W...   Yen"
    colHdr.TextXAlignment = Enum.TextXAlignment.Left
    colHdr.TextColor3 = C_SUBTEXT
    colHdr.Font = Enum.Font.Code
    colHdr.TextSize = 10

    local stepsScroll = Instance.new("ScrollingFrame", stepsCard)
    stepsScroll.Size = UDim2.new(1, 0, 0, 112)
    stepsScroll.BackgroundTransparency = 1
    stepsScroll.ScrollBarThickness = 2
    stepsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    stepsScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    Instance.new("UIListLayout", stepsScroll).Padding = UDim.new(0, 3)

    local rowsFooter = Instance.new("TextLabel", stepsCard)
    rowsFooter.Size = UDim2.new(1, 0, 0, 14)
    rowsFooter.BackgroundTransparency = 1
    rowsFooter.Text = "0 rows"
    rowsFooter.TextXAlignment = Enum.TextXAlignment.Right
    rowsFooter.TextColor3 = C_SUBTEXT
    rowsFooter.Font = Enum.Font.Gotham
    rowsFooter.TextSize = 10

    local function RefreshStepsUI(steps)
        for _, child in ipairs(stepsScroll:GetChildren()) do
            if child:IsA("TextLabel") then child:Destroy() end
        end
        if not steps or #steps == 0 then
            local empty = Instance.new("TextLabel", stepsScroll)
            empty.Size = UDim2.new(1, 0, 0, 22)
            empty.BackgroundTransparency = 1
            empty.Text = "  no steps"
            empty.TextXAlignment = Enum.TextXAlignment.Left
            empty.TextColor3 = C_SUBTEXT
            empty.Font = Enum.Font.Gotham
            empty.TextSize = 11
            rowsFooter.Text = "0 rows"
            sRight.Text = "0 / 1"
            progFill.Size = UDim2.new(0, 0, 1, 0)
            return
        end
        for i, st in ipairs(steps) do
            local r = Instance.new("TextLabel", stepsScroll)
            r.Size = UDim2.new(1, 0, 0, 18)
            r.BackgroundTransparency = 1
            r.TextXAlignment = Enum.TextXAlignment.Left
            r.TextColor3 = C_TEXT
            r.Font = Enum.Font.Code
            r.TextSize = 10
            r.Text = string.format("  %-3d  %-9s  %-16s  %-5d  %d", i, tostring(st.action or "Place"), tostring(st.unit or "Unit"):sub(1, 16), tonumber(st.wave) or 1, tonumber(st.yen) or 0)
        end
        rowsFooter.Text = tostring(#steps) .. " rows"
        local curIdx = math.clamp(MacroEngine.PlayIndex - 1, 0, #steps)
        sRight.Text = string.format("%d / %d", curIdx, #steps)
        progFill.Size = UDim2.new(#steps > 0 and (curIdx / #steps) or 0, 0, 1, 0)
    end
    MacroEngine.OnStepsChanged = RefreshStepsUI
    MacroEngine.Steps = LoadMacroFile(Config.SelectedMacro)
    RefreshStepsUI(MacroEngine.Steps)

    local shareCard = CreateBentoCard(pgMacroRec.Right, "📤", "Share")
    AddFieldLabel(shareCard, "Import")
    local importInput = AddTextBox(shareCard, "macro JSON", "", function() end)
    AddActionBtn(shareCard, "Import (saves under Name)", C_TEXT, function()
        local nm = macroNameBox.Text ~= "" and macroNameBox.Text or Config.SelectedMacro
        ImportMacroJson(importInput.Text, nm)
        macroDropdown.Set(Config.SelectedMacro)
    end)
    AddActionBtn(shareCard, "Copy Picked Macro", C_TEXT, function()
        SafeSetClipboard(ExportMacroJson(Config.SelectedMacro, MacroEngine.Steps))
    end)

    local storyMapsCard = CreateBentoCard(pgMacroMaps.Left, "🗺", "Story Maps")
    AddToggle(storyMapsCard, "Use Macro Maps", Config.UseMacroMaps, function(v) Config.UseMacroMaps = v end)
    for _, mName in ipairs(STORY_MAPS) do
        AddFieldLabel(storyMapsCard, mName)
        AddDropdownBox(storyMapsCard, function()
            local opts = { "None" }
            for _, saved in ipairs(ListSavedMacros()) do table.insert(opts, saved) end
            return opts
        end, Config.MapMacros[mName] or "None", function(v) Config.MapMacros[mName] = v end)
    end

    -- ========================================================================
    -- PAGE 4 & 5: AUTO PLAY
    -- ========================================================================
    local apAllCard = CreateBentoCard(pgAutoAll.Left, "🤖", "Auto Play")
    AddToggle(apAllCard, "Auto Play", Config.AutoPlay, function(v) Config.AutoPlay = v end)
    AddSlider(apAllCard, "Path Position", 1, 100, Config.PathPosition, "%", nil, function(v) Config.PathPosition = v end)
    AddSlider(apAllCard, "Spacing", 1, 20, Config.Spacing, " studs", nil, function(v) Config.Spacing = v end)
    AddToggle(apAllCard, "Cover All Lanes", Config.CoverAllLanes, function(v) Config.CoverAllLanes = v end)
    AddToggle(apAllCard, "Place Near Others' Buffers", Config.PlaceNearBuffers, function(v) Config.PlaceNearBuffers = v end)
    AddToggle(apAllCard, "Weather-Aware", Config.WeatherAware, function(v) Config.WeatherAware = v end)
    AddToggle(apAllCard, "Show Placement Grid", Config.ShowPlacementGrid, function(v) Config.ShowPlacementGrid = v end)

    local behCard = CreateBentoCard(pgAutoAll.Right, "⚙", "Behaviour")
    AddToggle(behCard, "Farm Units First", Config.FarmUnitsFirst, function(v) Config.FarmUnitsFirst = v end)
    AddToggle(behCard, "Auto Upgrade", Config.AutoUpgrade, function(v) Config.AutoUpgrade = v end)
    AddToggle(behCard, "Upgrade While Saving", Config.UpgradeWhileSaving, function(v) Config.UpgradeWhileSaving = v end)
    AddFieldLabel(behCard, "Griffin Form")
    AddDropdownBox(behCard, { "Off", "Auto", "Always" }, Config.GriffinForm, function(v) Config.GriffinForm = v end)
    AddToggle(behCard, "Walk Like A Player", Config.WalkLikePlayer, function(v) Config.WalkLikePlayer = v end)

    local evApCard = CreateBentoCard(pgAutoEvent.Left, "✦", "Event Auto Play")
    AddToggle(evApCard, "Use This Page In Summer Hunt", Config.UseEventInSummer, function(v) Config.UseEventInSummer = v end)
    AddSlider(evApCard, "Path Position", 1, 100, Config.EventPathPosition, "%", nil, function(v) Config.EventPathPosition = v end)

    local unitSpecCard = CreateBentoCard(pgAutoEvent.Right, "👤", "Specific Unit Settings")
    local sPrio, sMaxP, sMaxU, sPlaceW, sUpgW, tHill
    AddFieldLabel(unitSpecCard, "Slot (1 - 6)")
    AddDropdownBox(unitSpecCard, { "Slot 1", "Slot 2", "Slot 3", "Slot 4", "Slot 5", "Slot 6" }, "Slot " .. Config.SelectedUnitSlot, function(v)
        local idx = tonumber(v:match("%d+")) or 1
        Config.SelectedUnitSlot = idx
        local sl = Config.UnitSlots[idx]
        if sl then
            sPrio.SetValue(sl.Priority)
            sMaxP.SetValue(sl.MaxPlace)
            sMaxU.SetValue(sl.MaxUpgrade)
            sPlaceW.SetValue(sl.PlaceWave)
            sUpgW.SetValue(sl.UpgradeWave)
            tHill.Set(sl.OnHill)
        end
    end)
    sPrio   = AddSlider(unitSpecCard, "Place Priority", 1, 6, Config.UnitSlots[Config.SelectedUnitSlot].Priority, "", nil, function(v) Config.UnitSlots[Config.SelectedUnitSlot].Priority = v end)
    sMaxP   = AddSlider(unitSpecCard, "Max Place", 0, 20, Config.UnitSlots[Config.SelectedUnitSlot].MaxPlace, "", nil, function(v) Config.UnitSlots[Config.SelectedUnitSlot].MaxPlace = v end)
    sMaxU   = AddSlider(unitSpecCard, "Max Upgrade", 0, 25, Config.UnitSlots[Config.SelectedUnitSlot].MaxUpgrade, "", nil, function(v) Config.UnitSlots[Config.SelectedUnitSlot].MaxUpgrade = v end)
    sPlaceW = AddSlider(unitSpecCard, "Place From Wave", 1, 100, Config.UnitSlots[Config.SelectedUnitSlot].PlaceWave, "", nil, function(v) Config.UnitSlots[Config.SelectedUnitSlot].PlaceWave = v end)
    sUpgW   = AddSlider(unitSpecCard, "Upgrade From Wave", 1, 100, Config.UnitSlots[Config.SelectedUnitSlot].UpgradeWave, "", nil, function(v) Config.UnitSlots[Config.SelectedUnitSlot].UpgradeWave = v end)
    tHill   = AddToggle(unitSpecCard, "Place On Hill", Config.UnitSlots[Config.SelectedUnitSlot].OnHill, function(v) Config.UnitSlots[Config.SelectedUnitSlot].OnHill = v end)

    -- ========================================================================
    -- PAGE 6: JOIN > STORY / CHALLENGES (Matches Screenshot 19 & 21)
    -- ========================================================================
    local ajCard = CreateBentoCard(pgJoinStory.Left, "🚀", "Auto Join")
    AddToggle(ajCard, "Auto Join", Config.AutoJoinStory, function(v) Config.AutoJoinStory = v end)
    AddFieldLabel(ajCard, "Mode")
    AddDropdownBox(ajCard, { "Story", "Legend", "Infinite" }, Config.JoinMode, function(v) Config.JoinMode = v end)
    AddFieldLabel(ajCard, "World")
    AddDropdownBox(ajCard, STORY_MAPS, Config.JoinWorld, function(v) Config.JoinWorld = v end)
    AddFieldLabel(ajCard, "Legend World")
    AddDropdownBox(ajCard, LEGEND_MAPS, Config.JoinLegendWorld, function(v) Config.JoinLegendWorld = v end)
    AddFieldLabel(ajCard, "Act / Stage")
    AddDropdownBox(ajCard, { "1", "2", "3", "4", "5", "6" }, Config.JoinAct, function(v) Config.JoinAct = v end)
    AddFieldLabel(ajCard, "Difficulty")
    AddDropdownBox(ajCard, { "Normal", "Hard", "Nightmare" }, Config.JoinDifficulty, function(v) Config.JoinDifficulty = v end)
    AddToggle(ajCard, "Matchmaking", Config.StoryMatchmaking, function(v) Config.StoryMatchmaking = v end)

    local chCard = CreateBentoCard(pgJoinStory.Right, "⚔", "Challenges")
    AddToggle(chCard, "Auto Join Challenge", Config.AutoJoinChallenge, function(v) Config.AutoJoinChallenge = v end)
    AddToggle(chCard, "Auto Join Daily Challenge", Config.AutoJoinDailyChallenge, function(v) Config.AutoJoinDailyChallenge = v end)
    AddToggle(chCard, "Matchmaking", Config.ChallengeMatchmaking, function(v) Config.ChallengeMatchmaking = v end)
    AddFieldLabel(chCard, "Only If It Drops (blank = any)")
    AddDropdownBox(chCard, { "--", "Star Fruit", "Star Fruit (Red)", "Star Fruit (Green)", "Star Remnant (Limited)", "Divine Wish", "Stat Cube", "Gems" }, Config.ChallengeDropFilter, function(v) Config.ChallengeDropFilter = v end)
    AddFieldLabel(chCard, "Skip Modifiers")
    AddDropdownBox(chCard, { "--", "Fast Enemies", "Shield Enemies", "Regen Enemies", "Explosive Enemies", "High Cost" }, Config.ChallengeSkipModifiers, function(v) Config.ChallengeSkipModifiers = v end)

    local chFeed = Instance.new("TextLabel", chCard)
    chFeed.Size = UDim2.new(1, 0, 0, 96)
    chFeed.BackgroundTransparency = 1
    chFeed.TextWrapped = true
    chFeed.TextXAlignment = Enum.TextXAlignment.Left
    chFeed.TextYAlignment = Enum.TextYAlignment.Top
    chFeed.TextColor3 = C_SUBTEXT
    chFeed.Font = Enum.Font.Gotham
    chFeed.TextSize = 11
    chFeed.Text = "Challenge: Rain Village Act 2 · Fast Enemies · not cleared  (17:07 left)\n  Star Fruit, Star Fruit (Red), Gems\nDaily: Haunted Mansion · Regen Enemies · not cleared  (4:47:07 left)\n  Divine Wish, Star Remnant (Limited), Stat Cube, Perfect Stat Cube, Gems"

    -- ========================================================================
    -- PAGE 7: JOIN > PARTY (Matches Screenshot 20)
    -- ========================================================================
    local partyCard = CreateBentoCard(pgJoinParty.Left, "👑", "Party")
    AddSubLabel(partyCard, "Host")
    AddFieldLabel(partyCard, "Invite Players")
    local invDrop = AddDropdownBox(partyCard, GetServerPlayerNames, Config.InvitePlayerTarget, function(v) Config.InvitePlayerTarget = v end)
    AddToggle(partyCard, "Auto Invite To Party", Config.AutoInviteToParty, function(v) Config.AutoInviteToParty = v end)
    AddActionBtn(partyCard, "Refresh Players", C_TEXT, function()
        local list = GetServerPlayerNames()
        if #list > 1 then invDrop.Set(list[2]) end
    end)
    AddSubLabel(partyCard, "Join A Player")
    AddFieldLabel(partyCard, "Player")
    AddDropdownBox(partyCard, GetServerPlayerNames, Config.JoinPlayerTarget, function(v) Config.JoinPlayerTarget = v end)
    AddFieldLabel(partyCard, "How To Join")
    AddDropdownBox(partyCard, { "Party", "Friend", "Teleport" }, Config.HowToJoinPlayer, function(v) Config.HowToJoinPlayer = v end)
    AddToggle(partyCard, "Auto Join Player", Config.AutoJoinPlayer, function(v) Config.AutoJoinPlayer = v end)

    local userStuffsCard = CreateBentoCard(pgJoinParty.Right, "🛡", "User Stuffs")
    AddFieldLabel(userStuffsCard, "Players")
    AddDropdownBox(userStuffsCard, GetServerPlayerNames, Config.UserStuffsPlayer, function(v) Config.UserStuffsPlayer = v end)
    AddFieldLabel(userStuffsCard, "Whitelist (usernames)")
    AddTextBox(userStuffsCard, "username1, username2", Config.WhitelistUsernames, function(txt) Config.WhitelistUsernames = txt end)
    AddSlider(userStuffsCard, "Wait Before Leaving", 0, 300, Config.WaitBeforeLeaving, " s", nil, function(v) Config.WaitBeforeLeaving = v end)
    AddToggle(userStuffsCard, "Leave When They Are Gone", Config.LeaveWhenGone, function(v) Config.LeaveWhenGone = v end)
    AddToggle(userStuffsCard, "Leave When Others Are Here", Config.LeaveWhenOthersHere, function(v) Config.LeaveWhenOthersHere = v end)
    AddToggle(userStuffsCard, "Only Auto Join With Them", Config.OnlyAutoJoinWithThem, function(v) Config.OnlyAutoJoinWithThem = v end)

    -- ========================================================================
    -- PAGE 8: JOIN > CASTLE / EVENTS / PORTALS / CONTRACTS / RAIDS
    -- ========================================================================
    local icCard = CreateBentoCard(pgJoinEvents.Left, "👑", "Infinity Castle")
    AddToggle(icCard, "Auto Infinity Castle", Config.AutoInfinityCastle, function(v) Config.AutoInfinityCastle = v end)
    AddToggle(icCard, "Matchmaking", Config.CastleMatchmaking, function(v) Config.CastleMatchmaking = v end)
    AddDropdownBox(icCard, { "Next Floor", "Fixed Floor" }, Config.CastleFloorMode, function(v) Config.CastleFloorMode = v end)
    AddSlider(icCard, "Fixed Floor", 1, 100, Config.CastleFixedFloor, "", nil, function(v) Config.CastleFixedFloor = v end)
    AddDropdownBox(icCard, { "Normal", "Hard", "Nightmare" }, Config.CastleDifficulty, function(v) Config.CastleDifficulty = v end)

    local ecCard = CreateBentoCard(pgJoinEvents.Right, "☆", "Event Challenge (Summer Hunt)")
    AddToggle(ecCard, "Auto Join Event Challenge", Config.AutoEventChallenge, function(v) Config.AutoEventChallenge = v end)
    AddToggle(ecCard, "Matchmaking", Config.EventMatchmaking, function(v) Config.EventMatchmaking = v end)
    AddToggle(ecCard, "Hunt Bingo Maps", Config.HuntBingoMaps, function(v) Config.HuntBingoMaps = v end)
    AddToggle(ecCard, "Hunt Unwon Weathers", Config.HuntUnwonWeathers, function(v) Config.HuntUnwonWeathers = v end)
    AddToggle(ecCard, "Auto Contracts", Config.AutoContracts, function(v) Config.AutoContracts = v end)
    AddToggle(ecCard, "Auto Artifact Raid", Config.AutoArtifactRaid, function(v) Config.AutoArtifactRaid = v end)
    AddToggle(ecCard, "Auto Raid", Config.AutoRaid, function(v) Config.AutoRaid = v end)

    local portCard = CreateBentoCard(pgJoinEvents.Left, "🌀", "Portals")
    AddToggle(portCard, "Auto Portal", Config.AutoPortal, function(v) Config.AutoPortal = v end)
    AddToggle(portCard, "Auto Start Portal", Config.AutoStartPortal, function(v) Config.AutoStartPortal = v end)
    AddToggle(portCard, "Auto Next Portal", Config.AutoNextPortal, function(v) Config.AutoNextPortal = v end)
    AddToggle(portCard, "Most Uses Left First", Config.MostUsesLeftFirst, function(v) Config.MostUsesLeftFirst = v end)
    AddToggle(portCard, "Matchmaking", Config.PortalMatchmaking, function(v) Config.PortalMatchmaking = v end)

    -- ========================================================================
    -- PAGE 9: JOIN > DUNGEON (Matches Screenshot 22)
    -- ========================================================================
    local dngRunCard = CreateBentoCard(pgJoinDungeon.Left, "💀", "Dungeon Run")
    AddSubLabel(dngRunCard, "Run")
    AddToggle(dngRunCard, "Auto Dungeon", Config.AutoDungeon, function(v) Config.AutoDungeon = v end)
    AddFieldLabel(dngRunCard, "Open Chests")
    AddDropdownBox(dngRunCard, { "Every Chest Room", "Rare Chests Only", "Never" }, Config.OpenChestsMode, function(v) Config.OpenChestsMode = v end)
    AddSlider(dngRunCard, "Stop After Losing A Room", 0, 10, Config.StopAfterLosingRoom, "", "never", function(v) Config.StopAfterLosingRoom = v end)
    AddToggle(dngRunCard, "Take Shrines", Config.TakeShrines, function(v) Config.TakeShrines = v end)
    AddToggle(dngRunCard, "Buy Shop Items", Config.BuyShopItems, function(v) Config.BuyShopItems = v end)
    AddSubLabel(dngRunCard, "Rooms")
    AddToggle(dngRunCard, "Avoid Curses", Config.AvoidCurses, function(v) Config.AvoidCurses = v end)
    AddFieldLabel(dngRunCard, "Curses To Avoid")
    AddDropdownBox(dngRunCard, { "Curse of Armor, Curse of Burst", "Curse of Speed", "Curse of Regen", "None" }, Config.CursesToAvoid, function(v) Config.CursesToAvoid = v end)
    AddToggle(dngRunCard, "Look Ahead", Config.LookAhead, function(v) Config.LookAhead = v end)
    AddSubLabel(dngRunCard, "No run yet")

    local roomPrioCard = CreateBentoCard(pgJoinDungeon.Left, "⇄", "Room Priority")
    AddSlider(roomPrioCard, "Rare Chest", 1, 10, Config.RareChestPriority, "", nil, function(v) Config.RareChestPriority = v end)

    local roomTeamsCard = CreateBentoCard(pgJoinDungeon.Right, "👥", "Room Teams")
    AddToggle(roomTeamsCard, "Team By Room Weakness", Config.TeamByRoomWeakness, function(v) Config.TeamByRoomWeakness = v end)
    AddFieldLabel(roomTeamsCard, "Physical Weak Rooms")
    AddDropdownBox(roomTeamsCard, TEAM_OPTIONS, Config.PhysicalWeakTeam, function(v) Config.PhysicalWeakTeam = v end)
    AddFieldLabel(roomTeamsCard, "Magic Weak Rooms")
    AddDropdownBox(roomTeamsCard, TEAM_OPTIONS, Config.MagicWeakTeam, function(v) Config.MagicWeakTeam = v end)
    AddFieldLabel(roomTeamsCard, "Other Weak Rooms")
    AddDropdownBox(roomTeamsCard, TEAM_OPTIONS, Config.OtherWeakTeam, function(v) Config.OtherWeakTeam = v end)

    local shopPrioCard = CreateBentoCard(pgJoinDungeon.Right, "🛍", "Shop Priority")
    AddDropdownBox(shopPrioCard, { "Stat Cube", "Divine Wish", "Star Remnant", "Gems" }, Config.ShopPriorityItem, function(v) Config.ShopPriorityItem = v end)

    -- ========================================================================
    -- PAGE 10: JOIN > TEAMS (Matches Screenshot 23)
    -- ========================================================================
    local teamsLeftCard = CreateBentoCard(pgJoinTeams.Left, "👥", "Auto Equip Team")
    AddToggle(teamsLeftCard, "Auto Equip Team", Config.AutoEquipTeam, function(v) Config.AutoEquipTeam = v end)
    AddFieldLabel(teamsLeftCard, "Challenge")
    AddDropdownBox(teamsLeftCard, TEAM_OPTIONS, Config.TeamChallenge, function(v) Config.TeamChallenge = v end)
    AddFieldLabel(teamsLeftCard, "Daily Challenge")
    AddDropdownBox(teamsLeftCard, TEAM_OPTIONS, Config.TeamDailyChallenge, function(v) Config.TeamDailyChallenge = v end)
    AddFieldLabel(teamsLeftCard, "Contracts")
    AddDropdownBox(teamsLeftCard, TEAM_OPTIONS, Config.TeamContracts, function(v) Config.TeamContracts = v end)
    AddFieldLabel(teamsLeftCard, "Event Challenge")
    AddDropdownBox(teamsLeftCard, TEAM_OPTIONS, Config.TeamEventChallenge, function(v) Config.TeamEventChallenge = v end)
    AddFieldLabel(teamsLeftCard, "Artifact Raid")
    AddDropdownBox(teamsLeftCard, TEAM_OPTIONS, Config.TeamArtifactRaid, function(v) Config.TeamArtifactRaid = v end)
    AddFieldLabel(teamsLeftCard, "Swordsmith Village")
    AddDropdownBox(teamsLeftCard, TEAM_OPTIONS, Config.TeamSwordsmith, function(v) Config.TeamSwordsmith = v end)
    AddFieldLabel(teamsLeftCard, "Portals")
    AddDropdownBox(teamsLeftCard, TEAM_OPTIONS, Config.TeamPortals, function(v) Config.TeamPortals = v end)
    AddFieldLabel(teamsLeftCard, "Dungeon")
    AddDropdownBox(teamsLeftCard, TEAM_OPTIONS, Config.TeamDungeon, function(v) Config.TeamDungeon = v end)

    local savedTeamsCard = CreateBentoCard(pgJoinTeams.Right, "☰", "Saved Teams")
    local stText = Instance.new("TextLabel", savedTeamsCard)
    stText.Size = UDim2.new(1, 0, 0, 96)
    stText.BackgroundTransparency = 1
    stText.TextXAlignment = Enum.TextXAlignment.Left
    stText.TextYAlignment = Enum.TextYAlignment.Top
    stText.TextColor3 = C_SUBTEXT
    stText.Font = Enum.Font.Gotham
    stText.TextSize = 11
    stText.Text = "Team 1: empty\nTeam 2: empty\nTeam 3: empty\nTeam 4: empty\nTeam 5: empty\nTeam 6: empty"

    -- ========================================================================
    -- PAGE 11: JOIN > SWORDSMITH & DEFENSES (Matches Screenshot 24)
    -- ========================================================================
    local swCard = CreateBentoCard(pgJoinVillage.Left, "⚔", "Swordsmith Village")
    AddToggle(swCard, "Auto Swordsmith Village", Config.AutoSwordsmith, function(v) Config.AutoSwordsmith = v end)
    AddToggle(swCard, "Matchmaking", Config.SwordsmithMatchmaking, function(v) Config.SwordsmithMatchmaking = v end)
    AddFieldLabel(swCard, "Stage")
    AddDropdownBox(swCard, { "Best Available", "Day Stage", "Night Stage" }, Config.SwordsmithStage, function(v) Config.SwordsmithStage = v end)
    AddToggle(swCard, "Blood Moon When Up", Config.BloodMoonWhenUp, function(v) Config.BloodMoonWhenUp = v end)
    AddSlider(swCard, "Skip A Stage After Losses", 0, 10, Config.SkipStageAfterLosses, "", nil, function(v) Config.SkipStageAfterLosses = v end)
    AddSubLabel(swCard, "Night, 47m left  ·  plays Day Stage")

    local mtCard = CreateBentoCard(pgJoinVillage.Left, "☰", "Misty Tower")
    AddToggle(mtCard, "Auto Misty Tower", Config.AutoMistyTower, function(v) Config.AutoMistyTower = v end)
    AddToggle(mtCard, "Matchmaking", Config.MistyMatchmaking, function(v) Config.MistyMatchmaking = v end)
    AddSlider(mtCard, "Rest After Losses", 0, 10, Config.RestAfterLosses, "", nil, function(v) Config.RestAfterLosses = v end)
    AddSubLabel(mtCard, "next floor 1")

    local defCard = CreateBentoCard(pgJoinVillage.Right, "🛡", "Defenses")
    AddSubLabel(defCard, "Match")
    AddToggle(defCard, "Auto Place Defenses", Config.AutoPlaceDefenses, function(v) Config.AutoPlaceDefenses = v end)
    AddFieldLabel(defCard, "Place At")
    AddDropdownBox(defCard, { "Damage Units", "Path Position", "Base" }, Config.DefensesPlaceAt, function(v) Config.DefensesPlaceAt = v end)
    AddSlider(defCard, "Path Position", 1, 100, Config.DefensesPathPos, "%", nil, function(v) Config.DefensesPathPos = v end)
    AddToggle(defCard, "Auto Buy Village Shop", Config.AutoBuyVillageShop, function(v) Config.AutoBuyVillageShop = v end)
    AddFieldLabel(defCard, "Buy Rarities")
    AddDropdownBox(defCard, { "Rare, Epic, Legendary, Mythic, Secret", "Legendary, Mythic, Secret", "Mythic, Secret" }, Config.BuyRarities, function(v) Config.BuyRarities = v end)
    AddFieldLabel(defCard, "Only Buy (blank = by rarity)")
    AddDropdownBox(defCard, { "--", "Flame Lantern", "Nichirin Turret", "Wisteria Ward", "Thunder Totem" }, Config.OnlyBuyByName, function(v) Config.OnlyBuyByName = v end)
    AddSubLabel(defCard, "Lobby")
    AddToggle(defCard, "Auto Equip Best", Config.AutoEquipBestDefense, function(v) Config.AutoEquipBestDefense = v end)
    AddToggle(defCard, "Auto Repair", Config.AutoRepairDefenses, function(v) Config.AutoRepairDefenses = v end)
    AddSlider(defCard, "Repair Below", 10, 90, Config.RepairBelowPct, "%", nil, function(v) Config.RepairBelowPct = v end)
    AddToggle(defCard, "Auto Scrap When Full", Config.AutoScrapWhenFull, function(v) Config.AutoScrapWhenFull = v end)
    AddFieldLabel(defCard, "Scrap Up To")
    AddDropdownBox(defCard, { "Common", "Rare", "Epic", "Legendary" }, Config.ScrapUpToRarity, function(v) Config.ScrapUpToRarity = v end)

    -- ========================================================================
    -- PAGE 12: PRIORITY (Matches Screenshot 25)
    -- ========================================================================
    local prCard = CreateBentoCard(pgPriority.Left, "🏅", "Join Priority")
    AddSlider(prCard, "Challenge", 1, 10, Config.PriorityChallenge, "", nil, function(v) Config.PriorityChallenge = v end)
    AddSlider(prCard, "Daily Challenge", 1, 10, Config.PriorityDailyChallenge, "", nil, function(v) Config.PriorityDailyChallenge = v end)
    AddSlider(prCard, "Contracts", 1, 10, Config.PriorityContracts, "", nil, function(v) Config.PriorityContracts = v end)
    AddSlider(prCard, "Event Challenge", 1, 10, Config.PriorityEventChallenge, "", nil, function(v) Config.PriorityEventChallenge = v end)
    AddSlider(prCard, "Artifact Raid", 1, 10, Config.PriorityArtifactRaid, "", nil, function(v) Config.PriorityArtifactRaid = v end)
    AddSlider(prCard, "Swordsmith Village", 1, 10, Config.PrioritySwordsmith, "", nil, function(v) Config.PrioritySwordsmith = v end)
    AddSlider(prCard, "Portals", 1, 10, Config.PriorityPortals, "", nil, function(v) Config.PriorityPortals = v end)
    AddSlider(prCard, "Dungeon", 1, 10, Config.PriorityDungeon, "", nil, function(v) Config.PriorityDungeon = v end)
    AddSlider(prCard, "Raid", 1, 10, Config.PriorityRaid, "", nil, function(v) Config.PriorityRaid = v end)
    AddSlider(prCard, "Infinity Castle", 1, 10, Config.PriorityInfinityCastle, "", nil, function(v) Config.PriorityInfinityCastle = v end)

    local prInfoCard = CreateBentoCard(pgPriority.Right, "⚡", "Active Queue Order")
    local prQueueLbl = Instance.new("TextLabel", prInfoCard)
    prQueueLbl.Size = UDim2.new(1, 0, 0, 140)
    prQueueLbl.BackgroundTransparency = 1
    prQueueLbl.TextWrapped = true
    prQueueLbl.TextXAlignment = Enum.TextXAlignment.Left
    prQueueLbl.TextYAlignment = Enum.TextYAlignment.Top
    prQueueLbl.TextColor3 = C_SUBTEXT
    prQueueLbl.Font = Enum.Font.Gotham
    prQueueLbl.TextSize = 11
    prQueueLbl.Text = "Higher weight runs first whenever available.\n\n1. Challenge / Daily Challenge\n2. Contracts & Event Challenge\n3. Artifact Raid & Swordsmith Village\n4. Portals & Dungeon\n5. Raid, Infinity Castle & Story Farm"

    -- ========================================================================
    -- PAGE 13: GAME (Matches Screenshot 26)
    -- ========================================================================
    local matchCard = CreateBentoCard(pgGame.Left, "▶", "Match")
    AddSubLabel(matchCard, "Start")
    AddToggle(matchCard, "Auto Vote Start", Config.AutoVoteStart, function(v) Config.AutoVoteStart = v end)
    AddToggle(matchCard, "Auto Skip Wave", Config.AutoSkipWave, function(v) Config.AutoSkipWave = v end)
    AddSubLabel(matchCard, "End")
    AddToggle(matchCard, "Auto Next", Config.AutoNext, function(v) Config.AutoNext = v end)
    AddToggle(matchCard, "Auto Retry", Config.AutoRetry, function(v) Config.AutoRetry = v end)
    AddToggle(matchCard, "Auto Leave", Config.AutoLeave, function(v) Config.AutoLeave = v end)
    AddToggle(matchCard, "Vote To Lose (XP)", Config.VoteToLoseXP, function(v) Config.VoteToLoseXP = v end)

    local matchStatusRow = Instance.new("Frame", matchCard)
    matchStatusRow.Size = UDim2.new(1, 0, 0, 22)
    matchStatusRow.BackgroundTransparency = 1
    local msLeft = Instance.new("TextLabel", matchStatusRow)
    msLeft.Size = UDim2.new(0.45, 0, 1, 0)
    msLeft.BackgroundTransparency = 1
    msLeft.Text = "Match"
    msLeft.TextXAlignment = Enum.TextXAlignment.Left
    msLeft.TextColor3 = C_TEXT
    msLeft.Font = Enum.Font.Gotham
    msLeft.TextSize = 12

    local matchPill = Instance.new("TextLabel", matchStatusRow)
    matchPill.Size = UDim2.new(0, 96, 0, 20)
    matchPill.Position = UDim2.new(1, -96, 0.5, -10)
    matchPill.BackgroundColor3 = C_INPUT
    matchPill.Text = "• In the lobby"
    matchPill.TextColor3 = C_SUBTEXT
    matchPill.Font = Enum.Font.GothamSemibold
    matchPill.TextSize = 10
    Instance.new("UICorner", matchPill).CornerRadius = UDim.new(1, 0)

    local matchSummaryLbl = Instance.new("TextLabel", matchCard)
    matchSummaryLbl.Size = UDim2.new(1, 0, 0, 16)
    matchSummaryLbl.BackgroundTransparency = 1
    matchSummaryLbl.Text = "Wave 0   0 units out   0 runs   0 skips"
    matchSummaryLbl.TextXAlignment = Enum.TextXAlignment.Left
    matchSummaryLbl.TextColor3 = C_SUBTEXT
    matchSummaryLbl.Font = Enum.Font.Gotham
    matchSummaryLbl.TextSize = 11

    local abilCard = CreateBentoCard(pgGame.Left, "✦", "Abilities")
    AddSubLabel(abilCard, "Buff Uptime")
    AddToggle(abilCard, "Buff Uptime", Config.BuffUptime, function(v) Config.BuffUptime = v end)
    AddFieldLabel(abilCard, "Units")
    AddDropdownBox(abilCard, { "Commander, Elfy, Gambler, Griffin", "Commander, Elfy", "All Support Units" }, Config.BuffUnitsList, function(v) Config.BuffUnitsList = v end)
    AddSubLabel(abilCard, "Auto Ability")
    AddToggle(abilCard, "Auto Ability", Config.AutoAbility, function(v) Config.AutoAbility = v end)

    local waveRulesCard = CreateBentoCard(pgGame.Right, "≋", "Wave Rules")
    AddSubLabel(waveRulesCard, "Sell")
    AddToggle(waveRulesCard, "Sell Farm Units", Config.SellFarmUnits, function(v) Config.SellFarmUnits = v end)
    AddToggle(waveRulesCard, "Sell All Units (Infinite)", Config.SellAllUnitsInf, function(v) Config.SellAllUnitsInf = v end)
    AddSubLabel(waveRulesCard, "Leave")
    AddToggle(waveRulesCard, "Lobby On Infinite Wave", Config.LobbyOnInfiniteWave, function(v) Config.LobbyOnInfiniteWave = v end)
    AddToggle(waveRulesCard, "Leave When Players Below", Config.LeaveWhenPlayersBelow, function(v) Config.LeaveWhenPlayersBelow = v end)

    -- ========================================================================
    -- PAGES 14-16: LOBBY, WEBHOOK, MISC
    -- ========================================================================
    local lbCard = CreateBentoCard(pgLobby.Left, "🏪", "Lobby Automation")
    AddToggle(lbCard, "Auto Claim Daily / Quests", Config.AutoClaimQuests, function(v) Config.AutoClaimQuests = v end)

    local whCard = CreateBentoCard(pgWebhook.Left, "🔔", "Discord Webhook")
    AddToggle(whCard, "Send Match Rewards Webhook", Config.SendMatchWebhook, function(v) Config.SendMatchWebhook = v end)
    AddFieldLabel(whCard, "Webhook URL")
    AddTextBox(whCard, "https://discord.com/api/webhooks/...", Config.WebhookUrl, function(txt) Config.WebhookUrl = txt end)

    local msCard = CreateBentoCard(pgMisc.Left, "🔧", "Misc & Performance")
    AddToggle(msCard, "Anti-AFK Protection", Config.AntiAfkEnabled, function(v) Config.AntiAfkEnabled = v end)
    AddToggle(msCard, "Low Graphics / FPS Boost", Config.LowGraphicsMode, function(v) Config.LowGraphicsMode = v end)

    -- Live Search Filter
    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        local q = searchBox.Text:lower():gsub("^%s+", ""):gsub("%s+$", "")
        for _, item in ipairs(AllSearchableRows) do
            if item.Frame and item.Frame.Parent then
                item.Frame.Visible = (q == "") or (item.Text:find(q, 1, true) ~= nil)
            end
        end
    end)

    SelectPage("Priority")

    -- Live Telemetry Loop
    local frames = 0
    RunService.RenderStepped:Connect(function()
        frames = frames + 1
    end)

    task.spawn(function()
        while sg.Parent do
            task.wait(1)
            local fps = frames
            frames = 0

            local elapsed = math.floor(os.clock() - SessionStart)
            local pingMs = 0
            pcall(function()
                pingMs = math.floor(StatsService.Network.ServerStatsItem["Data Ping"]:GetValue())
            end)

            local w = GetCurrentWave()
            Config.CurrentWave = w
            local inLobby = IsInLobby()
            local unitsOut = #GetOwnedUnits()

            mSession.Text = string.format("%dm %ds", math.floor(elapsed / 60), elapsed % 60)
            mFeat.Text    = tostring(CountActiveFeatures())
            mFps.Text     = tostring(fps)
            mPing.Text    = tostring(pingMs) .. " ms"
            mPlayers.Text = tostring(#Players:GetPlayers()) .. "/30"
            mRuns.Text    = tostring(Config.Runs)
            mWave.Text    = tostring(w)
            mSteps.Text   = tostring(#MacroEngine.Steps)

            matchPill.Text = inLobby and "• In the lobby" or "• In match"
            matchPill.TextColor3 = inLobby and C_SUBTEXT or C_ACCENT
            matchSummaryLbl.Text = string.format("Wave %d   %d units out   %d runs   %d skips", w, unitsOut, Config.Runs, Config.Skips)

            idlePill.Text = "• " .. MacroEngine.Status
            idlePill.TextColor3 = (MacroEngine.Status == "recording" or MacroEngine.Status == "playing") and C_ACCENT or C_SUBTEXT
            topPill.Text  = string.format("  AA Unified  •  %d fps  •  Tap to toggle", fps)
        end
    end)

    return sg
end

local HubGui = BuildBentoHub()

-- ============================================================================
-- 7. MAIN RUNTIME LOOP
-- ============================================================================
task.spawn(function()
    while task.wait(0.35) do
        if IsInLobby() then
            StepLobbyAutomation(HubGui)
        else
            StepInMatchAutomation()
            StepMacroRuntime()
        end
    end
end)
