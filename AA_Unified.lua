-- ============================================================================
-- ANIME ADVENTURES - UNIFIED HUB (DARK / ORANGE TABBED UI + SLIDERS + MACRO)
-- Save as 'AA_Unified_Hub.lua' in your executor's 'workspace' and 'autoexec'.
-- ============================================================================

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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
    if #names == 0 then
        table.insert(names, "Default")
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
    "Ant Kingdom"
}

local Config = {
    Runs = 0,
    CurrentWave = 0,

    -- Macro (Record / Play & Macro Maps)
    SelectedMacro = "Default",
    RecordMacro = false,
    PlayMacro = false,
    EquipMacroUnits = false,
    PlayBy = "Money",               -- "Money" or "Time"
    UseMacroMaps = false,
    MapMacros = {
        ["Planet Greenie"] = "None",
        ["Walled City"] = "None",
        ["Snowy Town"] = "None",
        ["Sand Village"] = "None",
        ["Navy Bay"] = "None",
        ["Fiend City"] = "None",
        ["Spirit World"] = "None",
        ["Ant Kingdom"] = "None"
    },

    -- Auto Play (All Modes & Event)
    AutoPlay = false,
    PathPosition = 1,               -- 1..100 (%)
    Spacing = 1,                    -- 1..20 (studs)
    CoverAllLanes = true,
    PlaceNearBuffers = false,
    WeatherAware = true,
    ShowPlacementGrid = false,
    FarmUnitsFirst = true,
    AutoUpgrade = true,
    UpgradeWhileSaving = true,
    GriffinForm = "Off",
    WalkLikePlayer = false,

    -- Event Auto Play (Summer Hunt)
    UseEventInSummer = false,
    EventPathPosition = 50,
    EventSpacing = 1,

    -- Specific Unit Settings (Slots 1-6)
    SelectedUnitSlot = 1,
    UnitSlots = {
        [1] = { Name = "Slot 1", Priority = 1, MaxPlace = 1, MaxUpgrade = 15, PlaceWave = 1, UpgradeWave = 1, OnHill = false },
        [2] = { Name = "Slot 2", Priority = 2, MaxPlace = 3, MaxUpgrade = 15, PlaceWave = 1, UpgradeWave = 1, OnHill = false },
        [3] = { Name = "Slot 3", Priority = 3, MaxPlace = 3, MaxUpgrade = 15, PlaceWave = 1, UpgradeWave = 1, OnHill = false },
        [4] = { Name = "Slot 4", Priority = 4, MaxPlace = 3, MaxUpgrade = 15, PlaceWave = 1, UpgradeWave = 1, OnHill = false },
        [5] = { Name = "Slot 5", Priority = 5, MaxPlace = 3, MaxUpgrade = 15, PlaceWave = 1, UpgradeWave = 1, OnHill = false },
        [6] = { Name = "Slot 6", Priority = 6, MaxPlace = 3, MaxUpgrade = 15, PlaceWave = 1, UpgradeWave = 1, OnHill = false }
    },

    -- Join: Castle / Events / Portals / Swordsmith & Misty Tower
    AutoInfinityCastle = false,
    CastleMatchmaking = true,
    CastleFloorMode = "Next Floor",
    CastleFixedFloor = 1,
    CastleDifficulty = "Hard",

    AutoEventChallenge = false,
    EventMatchmaking = true,        -- true = "Find Match", false = "Play Here"
    HuntBingoMaps = false,
    HuntUnwonWeathers = false,

    AutoPortal = false,
    AutoStartPortal = true,
    AutoNextPortal = true,
    MostUsesLeftFirst = true,
    PortalMatchmaking = true,

    AutoSwordsmith = false,
    SwordsmithMatchmaking = true,
    SwordsmithStage = "Best Available",
    BloodMoonWhenUp = true,
    SkipStageAfterLosses = 0,
    AutoMistyTower = false,
    MistyMatchmaking = true,
    RestAfterLosses = 3,

    -- Match / Game Automation
    AutoStartMatch = true,
    AutoSkipWaves = true,
    AutoReplay = true,
    ClaimClearRewards = true
}

local function LoadConfig()
    local raw = SafeReadFile(CONFIG_FILE)
    if raw then
        local ok, data = pcall(function()
            return HttpService:JSONDecode(raw)
        end)
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
-- 3. GUI CONTAINER, CLICKER & FUZZY REMOTE HELPERS
-- ============================================================================
local function GetSafeGuiParent()
    if type(gethui) == "function" then
        local ok, hui = pcall(gethui)
        if ok and typeof(hui) == "Instance" then
            return hui
        end
    end
    local okCore = pcall(function() local _ = CoreGui.Name end)
    if okCore and CoreGui then return CoreGui end
    return PlayerGui or LocalPlayer:WaitForChild("PlayerGui", 10)
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
    if not PlayerGui then
        PlayerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    end
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
    if w and (w:IsA("IntValue") or w:IsA("NumberValue")) then
        return w.Value
    end
    local valObj = w and (w:FindFirstChild("Value") or w:FindFirstChild("Wave"))
    if valObj and (valObj:IsA("IntValue") or valObj:IsA("NumberValue")) then
        return valObj.Value
    end
    return 0
end

-- ============================================================================
-- 4. MACRO ENGINE (RECORD / PLAY BY MONEY OR TIME + STEP LIST + IMPORT/EXPORT)
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
    if clean == "" then clean = "Default" end
    return "AAMacro_" .. clean .. ".json"
end

local function SaveMacroFile(name, steps)
    SafeWriteFile(GetMacroFilename(name), HttpService:JSONEncode({
        name = name,
        steps = steps
    }))
end

local function LoadMacroFile(name)
    local raw = SafeReadFile(GetMacroFilename(name))
    if not raw then return {} end
    local ok, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if ok and type(data) == "table" and type(data.steps) == "table" then
        return data.steps
    end
    return {}
end

local function ExportMacroJson(name, steps)
    return HttpService:JSONEncode({
        name = name,
        steps = steps
    })
end

local function ImportMacroJson(rawJson, targetName)
    if type(rawJson) ~= "string" or rawJson == "" then return false, 0 end
    local ok, decoded = pcall(function() return HttpService:JSONDecode(rawJson) end)
    if not ok or type(decoded) ~= "table" then return false, 0 end
    local list = type(decoded.steps) == "table" and decoded.steps or (decoded[1] and decoded or nil)
    if not list then return false, 0 end
    local name = (targetName and targetName ~= "") and targetName or (decoded.name or Config.SelectedMacro)
    Config.SelectedMacro = name
    MacroEngine.Steps = list
    MacroEngine.PlayIndex = 1
    SaveMacroFile(name, list)
    SaveConfig()
    NotifyStepsChanged()
    return true, #list
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
    if Config.RecordMacro or not Config.PlayMacro or IsInLobby() then
        MacroEngine.Status = Config.RecordMacro and "recording" or "idle"
        return
    end

    if #MacroEngine.Steps == 0 then
        MacroEngine.Steps = LoadMacroFile(Config.SelectedMacro)
        MacroEngine.PlayIndex = 1
        MacroEngine.PlayStartClock = os.clock()
        NotifyStepsChanged()
    end

    if #MacroEngine.Steps == 0 then
        MacroEngine.Status = "no steps"
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
-- 5. AUTO JOIN ("Where do you want to Play?" -> "Play Here" / "Find Match")
-- ============================================================================
local JoinGuard = { Busy = false, LastRun = 0, Cooldown = 2.5 }

local function StepLobbyJoinAndMatchmaking(rootGui)
    if not IsInLobby() or JoinGuard.Busy then return end

    local activeMode = nil
    local useMatchmaking = true

    if Config.AutoEventChallenge then
        activeMode = "Summer Event"
        useMatchmaking = Config.EventMatchmaking
    elseif Config.AutoSwordsmith then
        activeMode = "Misty Village"
        useMatchmaking = Config.SwordsmithMatchmaking
    elseif Config.AutoMistyTower then
        activeMode = "Misty Village"
        useMatchmaking = Config.MistyMatchmaking
    elseif Config.AutoInfinityCastle then
        activeMode = "Regular Stages"
        useMatchmaking = Config.CastleMatchmaking
    elseif Config.AutoPortal then
        activeMode = "Regular Stages"
        useMatchmaking = Config.PortalMatchmaking
    end

    if not activeMode then return end
    if (os.clock() - JoinGuard.LastRun) < JoinGuard.Cooldown then return end

    JoinGuard.Busy = true
    JoinGuard.LastRun = os.clock()

    pcall(function()
        local desired = useMatchmaking and "find match" or "play here"
        local fallback = useMatchmaking and "play here" or "find match"

        local confirmBtn = FindButtonByPhrase(desired, rootGui) or FindButtonByPhrase(fallback, rootGui)
        if confirmBtn then
            SafeClick(confirmBtn)
            return
        end

        local modeBtn = FindButtonByPhrase(activeMode, rootGui)
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

-- ============================================================================
-- 6. FULL DARK + ORANGE TABBED UI (SLIDERS, STEPS TABLE, MAP SELECTORS)
-- ============================================================================
local SessionStart = os.clock()

local function CountActiveFeatures()
    local c = 0
    for _, v in pairs(Config) do
        if v == true then c = c + 1 end
    end
    return c
end

local function BuildTabbedHub()
    local guiParent = GetSafeGuiParent()
    if not guiParent then return nil end

    for _, container in ipairs({ guiParent, PlayerGui, CoreGui }) do
        if container then
            local old = container:FindFirstChild("AA_BigFrootStyle_Hub")
            if old then pcall(function() old:Destroy() end) end
        end
    end

    local C_BG       = Color3.fromRGB(16, 15, 14)
    local C_SIDEBAR  = Color3.fromRGB(22, 20, 19)
    local C_CARD     = Color3.fromRGB(26, 23, 21)
    local C_CTRL     = Color3.fromRGB(36, 31, 28)
    local C_ACCENT   = Color3.fromRGB(235, 105, 30)
    local C_TEXT     = Color3.fromRGB(242, 238, 234)
    local C_MUTED    = Color3.fromRGB(155, 145, 138)

    local sg = Instance.new("ScreenGui")
    sg.Name = "AA_BigFrootStyle_Hub"
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true
    sg.DisplayOrder = 999999
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent = guiParent

    -- Top Floating Watermark Pill (Tap to toggle UI)
    local topPill = Instance.new("TextButton")
    topPill.Name = "TopPill"
    topPill.Size = UDim2.new(0, 240, 0, 28)
    topPill.Position = UDim2.new(0.5, -120, 0, 8)
    topPill.BackgroundColor3 = C_SIDEBAR
    topPill.TextColor3 = C_TEXT
    topPill.Font = Enum.Font.GothamSemibold
    topPill.TextSize = 12
    topPill.Text = "AA Unified  •  Tap to open/close"
    topPill.Active = true
    topPill.Draggable = true
    topPill.Parent = sg
    Instance.new("UICorner", topPill).CornerRadius = UDim.new(1, 0)
    local pillStroke = Instance.new("UIStroke", topPill)
    pillStroke.Color = C_ACCENT
    pillStroke.Thickness = 1

    -- Main Window
    local winW = IsMobile and 560 or 680
    local winH = IsMobile and 345 or 425
    local main = Instance.new("Frame")
    main.Name = "MainWindow"
    main.Size = UDim2.new(0, winW, 0, winH)
    main.Position = UDim2.new(0.5, -winW / 2, 0.5, -winH / 2)
    main.BackgroundColor3 = C_BG
    main.BorderSizePixel = 0
    main.Active = true
    main.Draggable = true
    main.Parent = sg
    Instance.new("UICorner", main).CornerRadius = UDim.new(0, 12)
    local mainStroke = Instance.new("UIStroke", main)
    mainStroke.Color = Color3.fromRGB(48, 42, 38)
    mainStroke.Thickness = 1

    topPill.MouseButton1Click:Connect(function()
        main.Visible = not main.Visible
    end)

    -- Sidebar
    local sidebar = Instance.new("Frame")
    sidebar.Size = UDim2.new(0, 152, 1, 0)
    sidebar.BackgroundColor3 = C_SIDEBAR
    sidebar.BorderSizePixel = 0
    sidebar.Parent = main
    Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0, 12)

    local brand = Instance.new("TextLabel")
    brand.Size = UDim2.new(1, -16, 0, 38)
    brand.Position = UDim2.new(0, 12, 0, 8)
    brand.BackgroundTransparency = 1
    brand.Text = "AA Unified\nv2.1.0"
    brand.TextXAlignment = Enum.TextXAlignment.Left
    brand.TextColor3 = C_TEXT
    brand.Font = Enum.Font.GothamBold
    brand.TextSize = 13
    brand.Parent = sidebar

    local navScroll = Instance.new("ScrollingFrame")
    navScroll.Size = UDim2.new(1, -12, 1, -56)
    navScroll.Position = UDim2.new(0, 6, 0, 50)
    navScroll.BackgroundTransparency = 1
    navScroll.ScrollBarThickness = 2
    navScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    navScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    navScroll.Parent = sidebar
    local navList = Instance.new("UIListLayout", navScroll)
    navList.Padding = UDim.new(0, 4)

    -- Right Header & Page Container
    local header = Instance.new("TextLabel")
    header.Size = UDim2.new(1, -172, 0, 34)
    header.Position = UDim2.new(0, 164, 0, 8)
    header.BackgroundTransparency = 1
    header.Text = "Home"
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.TextColor3 = C_TEXT
    header.Font = Enum.Font.GothamBold
    header.TextSize = 16
    header.Parent = main

    local pageHolder = Instance.new("Frame")
    pageHolder.Size = UDim2.new(1, -168, 1, -48)
    pageHolder.Position = UDim2.new(0, 160, 0, 42)
    pageHolder.BackgroundTransparency = 1
    pageHolder.Parent = main

    local Pages = {}
    local NavButtons = {}

    local function CreatePage(pageName)
        local sf = Instance.new("ScrollingFrame")
        sf.Name = pageName
        sf.Size = UDim2.new(1, 0, 1, 0)
        sf.BackgroundTransparency = 1
        sf.ScrollBarThickness = 3
        sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
        sf.CanvasSize = UDim2.new(0, 0, 0, 0)
        sf.Visible = false
        sf.Parent = pageHolder

        local layout = Instance.new("UIListLayout", sf)
        layout.Padding = UDim.new(0, 8)
        Pages[pageName] = sf
        return sf
    end

    local function SelectTab(pageName)
        header.Text = pageName
        for name, pg in pairs(Pages) do
            pg.Visible = (name == pageName)
        end
        for name, btn in pairs(NavButtons) do
            local active = (name == pageName)
            btn.BackgroundColor3 = active and Color3.fromRGB(45, 32, 24) or C_SIDEBAR
            btn.TextColor3 = active and C_ACCENT or C_MUTED
        end
    end

    local function AddNavTab(label)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 30)
        btn.BackgroundColor3 = C_SIDEBAR
        btn.Text = "  " .. label
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.TextColor3 = C_MUTED
        btn.Font = Enum.Font.GothamSemibold
        btn.TextSize = 12
        btn.Parent = navScroll
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
        NavButtons[label] = btn
        btn.MouseButton1Click:Connect(function()
            SelectTab(label)
        end)
        return CreatePage(label)
    end

    -- UI Builders
    local function CreateCard(parent, titleText)
        local card = Instance.new("Frame")
        card.Size = UDim2.new(1, -6, 0, 0)
        card.AutomaticSize = Enum.AutomaticSize.Y
        card.BackgroundColor3 = C_CARD
        card.BorderSizePixel = 0
        card.Parent = parent
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

        local pad = Instance.new("UIPadding", card)
        pad.PaddingTop = UDim.new(0, 10)
        pad.PaddingBottom = UDim.new(0, 10)
        pad.PaddingLeft = UDim.new(0, 10)
        pad.PaddingRight = UDim.new(0, 10)

        local list = Instance.new("UIListLayout", card)
        list.Padding = UDim.new(0, 7)

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 0, 20)
        lbl.BackgroundTransparency = 1
        lbl.Text = titleText
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextColor3 = C_ACCENT
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 13
        lbl.Parent = card

        return card
    end

    local function AddToggle(card, labelText, initialState, onChanged)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 26)
        row.BackgroundTransparency = 1
        row.Parent = card

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -54, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = labelText
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextColor3 = C_TEXT
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 12
        lbl.Parent = row

        local pillBtn = Instance.new("TextButton")
        pillBtn.Size = UDim2.new(0, 44, 0, 22)
        pillBtn.Position = UDim2.new(1, -44, 0.5, -11)
        pillBtn.Text = ""
        pillBtn.BackgroundColor3 = initialState and C_ACCENT or C_CTRL
        pillBtn.Parent = row
        Instance.new("UICorner", pillBtn).CornerRadius = UDim.new(1, 0)

        local knob = Instance.new("Frame")
        knob.Size = UDim2.new(0, 16, 0, 16)
        knob.Position = initialState and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
        knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        knob.Parent = pillBtn
        Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

        local state = initialState
        pillBtn.MouseButton1Click:Connect(function()
            state = not state
            pillBtn.BackgroundColor3 = state and C_ACCENT or C_CTRL
            knob.Position = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
            onChanged(state)
            SaveConfig()
        end)

        return {
            Set = function(newState)
                state = newState
                pillBtn.BackgroundColor3 = state and C_ACCENT or C_CTRL
                knob.Position = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
            end
        }
    end

    local function AddSlider(card, labelText, minVal, maxVal, currentVal, suffix, onChanged)
        local container = Instance.new("Frame")
        container.Size = UDim2.new(1, 0, 0, 38)
        container.BackgroundTransparency = 1
        container.Parent = card

        local topRow = Instance.new("Frame")
        topRow.Size = UDim2.new(1, 0, 0, 18)
        topRow.BackgroundTransparency = 1
        topRow.Parent = container

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.7, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = labelText
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextColor3 = C_TEXT
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 12
        lbl.Parent = topRow

        local valBox = Instance.new("TextLabel")
        valBox.Size = UDim2.new(0.3, 0, 1, 0)
        valBox.Position = UDim2.new(0.7, 0, 0, 0)
        valBox.BackgroundColor3 = C_CTRL
        valBox.Text = tostring(currentVal) .. (suffix or "")
        valBox.TextColor3 = C_TEXT
        valBox.Font = Enum.Font.GothamBold
        valBox.TextSize = 11
        valBox.Parent = topRow
        Instance.new("UICorner", valBox).CornerRadius = UDim.new(0, 4)

        local track = Instance.new("Frame")
        track.Size = UDim2.new(1, 0, 0, 8)
        track.Position = UDim2.new(0, 0, 0, 24)
        track.BackgroundColor3 = C_CTRL
        track.BorderSizePixel = 0
        track.Parent = container
        Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

        local fill = Instance.new("Frame")
        fill.Size = UDim2.new(0, 0, 1, 0)
        fill.BackgroundColor3 = C_ACCENT
        fill.BorderSizePixel = 0
        fill.Parent = track
        Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

        local thumb = Instance.new("Frame")
        thumb.Size = UDim2.new(0, 14, 0, 14)
        thumb.Position = UDim2.new(0, -7, 0.5, -7)
        thumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        thumb.Parent = fill
        Instance.new("UICorner", thumb).CornerRadius = UDim.new(1, 0)

        local dragging = false
        local value = math.clamp(currentVal or minVal, minVal, maxVal)

        local function ApplyValue(v, saveIt)
            value = math.clamp(math.floor(v + 0.5), minVal, maxVal)
            local alpha = (maxVal > minVal) and ((value - minVal) / (maxVal - minVal)) or 0
            fill.Size = UDim2.new(alpha, 0, 1, 0)
            valBox.Text = tostring(value) .. (suffix or "")
            onChanged(value)
            if saveIt then SaveConfig() end
        end

        ApplyValue(value, false)

        local function UpdateFromInput(input)
            local absPos = track.AbsolutePosition.X
            local absSize = track.AbsoluteSize.X
            if absSize <= 0 then return end
            local rel = math.clamp((input.Position.X - absPos) / absSize, 0, 1)
            ApplyValue(minVal + rel * (maxVal - minVal), false)
        end

        track.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                UpdateFromInput(input)
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                UpdateFromInput(input)
            end
        end)

        UserInputService.InputEnded:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
                dragging = false
                SaveConfig()
            end
        end)

        return {
            SetValue = function(v)
                ApplyValue(v, false)
            end
        }
    end

    local function AddCycleSelector(card, labelText, getOptionsFn, currentVal, onChanged)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 28)
        row.BackgroundTransparency = 1
        row.Parent = card

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.46, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = labelText
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextColor3 = C_TEXT
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 12
        lbl.Parent = row

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.54, 0, 1, 0)
        btn.Position = UDim2.new(0.46, 0, 0, 0)
        btn.BackgroundColor3 = C_CTRL
        btn.TextColor3 = C_TEXT
        btn.Font = Enum.Font.GothamSemibold
        btn.TextSize = 11
        btn.Text = tostring(currentVal or "--") .. "  ▾"
        btn.Parent = row
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

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
            btn.Text = tostring(selected) .. "  ▾"
            onChanged(selected)
            SaveConfig()
        end)

        return {
            Set = function(v)
                selected = v
                btn.Text = tostring(v) .. "  ▾"
            end
        }
    end

    local function AddButtonRow(card, text, colorOverride, callback)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 28)
        btn.BackgroundColor3 = colorOverride or C_CTRL
        btn.TextColor3 = C_TEXT
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 12
        btn.Text = text
        btn.Parent = card
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
        btn.MouseButton1Click:Connect(callback)
        return btn
    end

    -- ========================================================================
    -- TAB 1: HOME
    -- ========================================================================
    local homePage = AddNavTab("Home")
    local statusCard = CreateCard(homePage, "Status & Session")
    local statusLbl = Instance.new("TextLabel")
    statusLbl.Size = UDim2.new(1, 0, 0, 42)
    statusLbl.BackgroundTransparency = 1
    statusLbl.TextXAlignment = Enum.TextXAlignment.Left
    statusLbl.TextColor3 = C_TEXT
    statusLbl.Font = Enum.Font.GothamSemibold
    statusLbl.TextSize = 12
    statusLbl.Text = "Session: 0m 0s  |  Features On: 0\nFPS: 60  |  Ping: 0 ms  |  Runs: 0  |  Wave: 0"
    statusLbl.Parent = statusCard

    local quickCard = CreateCard(homePage, "Quick Actions")
    AddButtonRow(quickCard, "Copy Discord Invite", C_CTRL, function()
        SafeSetClipboard("https://discord.gg/")
    end)
    AddButtonRow(quickCard, "Load Last Config", C_CTRL, function()
        LoadConfig()
    end)
    AddButtonRow(quickCard, "Toggle Watermark Pill", C_CTRL, function()
        topPill.Visible = not topPill.Visible
    end)

    -- ========================================================================
    -- TAB 2: MACRO (Record / Play + Steps Table + Macro Maps)
    -- ========================================================================
    local macroPage = AddNavTab("Macro")
    local macroCard = CreateCard(macroPage, "Macro > Record / Play")

    local macroSelector = AddCycleSelector(macroCard, "Macro", function()
        return ListSavedMacros()
    end, Config.SelectedMacro, function(chosen)
        Config.SelectedMacro = chosen
        MacroEngine.Steps = LoadMacroFile(chosen)
        MacroEngine.PlayIndex = 1
        NotifyStepsChanged()
    end)

    local nameInput = Instance.new("TextBox")
    nameInput.Size = UDim2.new(1, 0, 0, 28)
    nameInput.BackgroundColor3 = C_CTRL
    nameInput.TextColor3 = C_TEXT
    nameInput.PlaceholderText = "new macro name"
    nameInput.Text = ""
    nameInput.Font = Enum.Font.Gotham
    nameInput.TextSize = 12
    nameInput.ClearTextOnFocus = false
    nameInput.Parent = macroCard
    Instance.new("UICorner", nameInput).CornerRadius = UDim.new(0, 6)

    AddButtonRow(macroCard, "Create", Color3.fromRGB(60, 120, 65), function()
        local newName = nameInput.Text:gsub("^%s+", ""):gsub("%s+$", "")
        if newName == "" then return end
        Config.SelectedMacro = newName
        MacroEngine.Steps = {}
        MacroEngine.PlayIndex = 1
        SaveMacroFile(newName, {})
        SaveConfig()
        macroSelector.Set(newName)
        NotifyStepsChanged()
    end)

    AddButtonRow(macroCard, "Delete", Color3.fromRGB(135, 42, 42), function()
        SafeDeleteFile(GetMacroFilename(Config.SelectedMacro))
        local list = ListSavedMacros()
        Config.SelectedMacro = list[1] or "Default"
        MacroEngine.Steps = LoadMacroFile(Config.SelectedMacro)
        MacroEngine.PlayIndex = 1
        SaveConfig()
        macroSelector.Set(Config.SelectedMacro)
        NotifyStepsChanged()
    end)

    AddButtonRow(macroCard, "Refresh List", C_CTRL, function()
        macroSelector.Set(Config.SelectedMacro)
        MacroEngine.Steps = LoadMacroFile(Config.SelectedMacro)
        NotifyStepsChanged()
    end)

    local recToggleObj, playToggleObj
    recToggleObj = AddToggle(macroCard, "Record Macro", Config.RecordMacro, function(val)
        Config.RecordMacro = val
        if val then
            Config.PlayMacro = false
            if playToggleObj then playToggleObj.Set(false) end
            InstallMacroHook()
            MacroEngine.Steps = {}
            MacroEngine.StartClock = os.clock()
            NotifyStepsChanged()
        else
            SaveMacroFile(Config.SelectedMacro, MacroEngine.Steps)
            NotifyStepsChanged()
        end
    end)

    playToggleObj = AddToggle(macroCard, "Play Macro", Config.PlayMacro, function(val)
        Config.PlayMacro = val
        if val then
            Config.RecordMacro = false
            if recToggleObj then recToggleObj.Set(false) end
            MacroEngine.Steps = LoadMacroFile(Config.SelectedMacro)
            MacroEngine.PlayIndex = 1
            MacroEngine.PlayStartClock = os.clock()
            NotifyStepsChanged()
        end
    end)

    AddToggle(macroCard, "Equip Macro Units", Config.EquipMacroUnits, function(val)
        Config.EquipMacroUnits = val
    end)

    AddCycleSelector(macroCard, "Play By", { "Money", "Time" }, Config.PlayBy, function(val)
        Config.PlayBy = val
    end)

    -- Steps Table Card (# | Action | Unit | W... | Yen)
    local stepsCard = CreateCard(macroPage, "Steps (Picked Macro)")
    local headerRow = Instance.new("TextLabel")
    headerRow.Size = UDim2.new(1, 0, 0, 18)
    headerRow.BackgroundTransparency = 1
    headerRow.Text = "#     Action        Unit                     W     Yen"
    headerRow.TextXAlignment = Enum.TextXAlignment.Left
    headerRow.TextColor3 = C_MUTED
    headerRow.Font = Enum.Font.Code
    headerRow.TextSize = 11
    headerRow.Parent = stepsCard

    local stepsListHolder = Instance.new("Frame")
    stepsListHolder.Size = UDim2.new(1, 0, 0, 110)
    stepsListHolder.BackgroundColor3 = C_CTRL
    stepsListHolder.BorderSizePixel = 0
    stepsListHolder.Parent = stepsCard
    Instance.new("UICorner", stepsListHolder).CornerRadius = UDim.new(0, 6)

    local stepsScroll = Instance.new("ScrollingFrame")
    stepsScroll.Size = UDim2.new(1, -6, 1, -6)
    stepsScroll.Position = UDim2.new(0, 3, 0, 3)
    stepsScroll.BackgroundTransparency = 1
    stepsScroll.ScrollBarThickness = 2
    stepsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    stepsScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    stepsScroll.Parent = stepsListHolder
    local stepsLayout = Instance.new("UIListLayout", stepsScroll)
    stepsLayout.Padding = UDim.new(0, 2)

    local rowsCountLbl = Instance.new("TextLabel")
    rowsCountLbl.Size = UDim2.new(1, 0, 0, 16)
    rowsCountLbl.BackgroundTransparency = 1
    rowsCountLbl.Text = "0 rows"
    rowsCountLbl.TextXAlignment = Enum.TextXAlignment.Right
    rowsCountLbl.TextColor3 = C_MUTED
    rowsCountLbl.Font = Enum.Font.Gotham
    rowsCountLbl.TextSize = 11
    rowsCountLbl.Parent = stepsCard

    local function RebuildStepsTable(steps)
        for _, child in ipairs(stepsScroll:GetChildren()) do
            if child:IsA("TextLabel") then child:Destroy() end
        end
        if not steps or #steps == 0 then
            local emptyLbl = Instance.new("TextLabel")
            emptyLbl.Size = UDim2.new(1, 0, 0, 22)
            emptyLbl.BackgroundTransparency = 1
            emptyLbl.Text = "  no steps"
            emptyLbl.TextXAlignment = Enum.TextXAlignment.Left
            emptyLbl.TextColor3 = C_MUTED
            emptyLbl.Font = Enum.Font.Gotham
            emptyLbl.TextSize = 11
            emptyLbl.Parent = stepsScroll
            rowsCountLbl.Text = "0 rows"
            return
        end

        for i, st in ipairs(steps) do
            local line = Instance.new("TextLabel")
            line.Size = UDim2.new(1, 0, 0, 18)
            line.BackgroundTransparency = 1
            line.TextXAlignment = Enum.TextXAlignment.Left
            line.TextColor3 = C_TEXT
            line.Font = Enum.Font.Code
            line.TextSize = 11
            line.Text = string.format("%-4d  %-10s  %-22s  %-4d  %d",
                i,
                tostring(st.action or "Act"),
                tostring(st.unit or "Unit"),
                tonumber(st.wave) or 0,
                tonumber(st.yen) or 0
            )
            line.Parent = stepsScroll
        end
        rowsCountLbl.Text = tostring(#steps) .. " rows"
    end

    MacroEngine.OnStepsChanged = RebuildStepsTable
    MacroEngine.Steps = LoadMacroFile(Config.SelectedMacro)
    RebuildStepsTable(MacroEngine.Steps)

    -- Share / Import / Copy Card
    local shareCard = CreateCard(macroPage, "Share")
    local importBox = Instance.new("TextBox")
    importBox.Size = UDim2.new(1, 0, 0, 28)
    importBox.BackgroundColor3 = C_CTRL
    importBox.TextColor3 = C_TEXT
    importBox.PlaceholderText = "macro JSON"
    importBox.Text = ""
    importBox.Font = Enum.Font.Gotham
    importBox.TextSize = 12
    importBox.ClearTextOnFocus = false
    importBox.Parent = shareCard
    Instance.new("UICorner", importBox).CornerRadius = UDim.new(0, 6)

    AddButtonRow(shareCard, "Import (saves under Name)", C_CTRL, function()
        local target = nameInput.Text ~= "" and nameInput.Text or Config.SelectedMacro
        ImportMacroJson(importBox.Text, target)
        macroSelector.Set(Config.SelectedMacro)
    end)

    AddButtonRow(shareCard, "Copy Picked Macro", C_CTRL, function()
        SafeSetClipboard(ExportMacroJson(Config.SelectedMacro, MacroEngine.Steps))
    end)

    -- Macro Maps Card (Story Maps selectors)
    local mapsCard = CreateCard(macroPage, "Macro Maps")
    AddToggle(mapsCard, "Use Macro Maps", Config.UseMacroMaps, function(val)
        Config.UseMacroMaps = val
    end)

    for _, mapName in ipairs(STORY_MAPS) do
        AddCycleSelector(mapsCard, mapName, function()
            local list = { "None" }
            for _, m in ipairs(ListSavedMacros()) do
                table.insert(list, m)
            end
            return list
        end, Config.MapMacros[mapName] or "None", function(chosen)
            Config.MapMacros[mapName] = chosen
        end)
    end

    -- ========================================================================
    -- TAB 3: AUTO PLAY (All Modes, Event, Specific Unit Settings)
    -- ========================================================================
    local autoPlayPage = AddNavTab("Auto Play")
    local apCard = CreateCard(autoPlayPage, "Auto Play > All Modes")

    AddToggle(apCard, "Auto Play", Config.AutoPlay, function(v) Config.AutoPlay = v end)
    AddSlider(apCard, "Path Position", 1, 100, Config.PathPosition, "%", function(v) Config.PathPosition = v end)
    AddSlider(apCard, "Spacing", 1, 20, Config.Spacing, " studs", function(v) Config.Spacing = v end)
    AddToggle(apCard, "Cover All Lanes", Config.CoverAllLanes, function(v) Config.CoverAllLanes = v end)
    AddToggle(apCard, "Place Near Others' Buffers", Config.PlaceNearBuffers, function(v) Config.PlaceNearBuffers = v end)
    AddToggle(apCard, "Weather-Aware", Config.WeatherAware, function(v) Config.WeatherAware = v end)
    AddToggle(apCard, "Show Placement Grid", Config.ShowPlacementGrid, function(v) Config.ShowPlacementGrid = v end)
    AddToggle(apCard, "Farm Units First", Config.FarmUnitsFirst, function(v) Config.FarmUnitsFirst = v end)
    AddToggle(apCard, "Auto Upgrade", Config.AutoUpgrade, function(v) Config.AutoUpgrade = v end)
    AddToggle(apCard, "Upgrade While Saving", Config.UpgradeWhileSaving, function(v) Config.UpgradeWhileSaving = v end)
    AddCycleSelector(apCard, "Griffin Form", { "Off", "Auto", "Always" }, Config.GriffinForm, function(v) Config.GriffinForm = v end)
    AddToggle(apCard, "Walk Like A Player", Config.WalkLikePlayer, function(v) Config.WalkLikePlayer = v end)

    local eventApCard = CreateCard(autoPlayPage, "Auto Play > Event (Summer Hunt)")
    AddToggle(eventApCard, "Use This Page In Summer Hunt", Config.UseEventInSummer, function(v) Config.UseEventInSummer = v end)
    AddSlider(eventApCard, "Event Path Position", 1, 100, Config.EventPathPosition, "%", function(v) Config.EventPathPosition = v end)

    local unitCard = CreateCard(autoPlayPage, "Specific Unit Settings (Slots 1-6)")
    local prioSlider, maxPlaceSlider, maxUpgSlider, placeWaveSlider, upgWaveSlider, hillToggle

    local function RefreshSlotControls(slotIdx)
        local cfgSlot = Config.UnitSlots[slotIdx]
        if not cfgSlot then return end
        if prioSlider then prioSlider.SetValue(cfgSlot.Priority) end
        if maxPlaceSlider then maxPlaceSlider.SetValue(cfgSlot.MaxPlace) end
        if maxUpgSlider then maxUpgSlider.SetValue(cfgSlot.MaxUpgrade) end
        if placeWaveSlider then placeWaveSlider.SetValue(cfgSlot.PlaceWave) end
        if upgWaveSlider then upgWaveSlider.SetValue(cfgSlot.UpgradeWave) end
        if hillToggle then hillToggle.Set(cfgSlot.OnHill) end
    end

    AddCycleSelector(unitCard, "Unit Slot", { "1", "2", "3", "4", "5", "6" }, tostring(Config.SelectedUnitSlot), function(val)
        local idx = tonumber(val) or 1
        Config.SelectedUnitSlot = idx
        RefreshSlotControls(idx)
    end)

    prioSlider = AddSlider(unitCard, "Place Priority", 1, 6, Config.UnitSlots[Config.SelectedUnitSlot].Priority, "", function(v)
        Config.UnitSlots[Config.SelectedUnitSlot].Priority = v
    end)
    maxPlaceSlider = AddSlider(unitCard, "Max Place", 0, 20, Config.UnitSlots[Config.SelectedUnitSlot].MaxPlace, "", function(v)
        Config.UnitSlots[Config.SelectedUnitSlot].MaxPlace = v
    end)
    maxUpgSlider = AddSlider(unitCard, "Max Upgrade", 0, 25, Config.UnitSlots[Config.SelectedUnitSlot].MaxUpgrade, "", function(v)
        Config.UnitSlots[Config.SelectedUnitSlot].MaxUpgrade = v
    end)
    placeWaveSlider = AddSlider(unitCard, "Place From Wave", 1, 100, Config.UnitSlots[Config.SelectedUnitSlot].PlaceWave, "", function(v)
        Config.UnitSlots[Config.SelectedUnitSlot].PlaceWave = v
    end)
    upgWaveSlider = AddSlider(unitCard, "Upgrade From Wave", 1, 100, Config.UnitSlots[Config.SelectedUnitSlot].UpgradeWave, "", function(v)
        Config.UnitSlots[Config.SelectedUnitSlot].UpgradeWave = v
    end)
    hillToggle = AddToggle(unitCard, "Place On Hill", Config.UnitSlots[Config.SelectedUnitSlot].OnHill, function(v)
        Config.UnitSlots[Config.SelectedUnitSlot].OnHill = v
    end)

    -- ========================================================================
    -- TAB 4: JOIN (Castle / Events / Portals / Swordsmith & Misty Tower)
    -- ========================================================================
    local joinPage = AddNavTab("Join")

    local castleCard = CreateCard(joinPage, "Infinity Castle")
    AddToggle(castleCard, "Auto Infinity Castle", Config.AutoInfinityCastle, function(v) Config.AutoInfinityCastle = v end)
    AddToggle(castleCard, "Matchmaking (OFF = Play Here)", Config.CastleMatchmaking, function(v) Config.CastleMatchmaking = v end)
    AddCycleSelector(castleCard, "Floor", { "Next Floor", "Fixed Floor" }, Config.CastleFloorMode, function(v) Config.CastleFloorMode = v end)
    AddSlider(castleCard, "Fixed Floor", 1, 100, Config.CastleFixedFloor, "", function(v) Config.CastleFixedFloor = v end)
    AddCycleSelector(castleCard, "Difficulty", { "Normal", "Hard", "Nightmare" }, Config.CastleDifficulty, function(v) Config.CastleDifficulty = v end)

    local eventJoinCard = CreateCard(joinPage, "Event Challenge")
    AddToggle(eventJoinCard, "Auto Join Event Challenge", Config.AutoEventChallenge, function(v) Config.AutoEventChallenge = v end)
    AddToggle(eventJoinCard, "Matchmaking (OFF = Play Here)", Config.EventMatchmaking, function(v) Config.EventMatchmaking = v end)
    AddToggle(eventJoinCard, "Hunt Bingo Maps", Config.HuntBingoMaps, function(v) Config.HuntBingoMaps = v end)
    AddToggle(eventJoinCard, "Hunt Unwon Weathers", Config.HuntUnwonWeathers, function(v) Config.HuntUnwonWeathers = v end)

    local portalCard = CreateCard(joinPage, "Portals")
    AddToggle(portalCard, "Auto Portal", Config.AutoPortal, function(v) Config.AutoPortal = v end)
    AddToggle(portalCard, "Auto Start Portal", Config.AutoStartPortal, function(v) Config.AutoStartPortal = v end)
    AddToggle(portalCard, "Auto Next Portal", Config.AutoNextPortal, function(v) Config.AutoNextPortal = v end)
    AddToggle(portalCard, "Most Uses Left First", Config.MostUsesLeftFirst, function(v) Config.MostUsesLeftFirst = v end)
    AddToggle(portalCard, "Matchmaking (OFF = Play Here)", Config.PortalMatchmaking, function(v) Config.PortalMatchmaking = v end)

    local swordCard = CreateCard(joinPage, "Swordsmith Village & Misty Tower")
    AddToggle(swordCard, "Auto Swordsmith Village", Config.AutoSwordsmith, function(v) Config.AutoSwordsmith = v end)
    AddToggle(swordCard, "Matchmaking (OFF = Play Here)", Config.SwordsmithMatchmaking, function(v) Config.SwordsmithMatchmaking = v end)
    AddCycleSelector(swordCard, "Stage", { "Best Available", "Day Stage", "Night Stage" }, Config.SwordsmithStage, function(v) Config.SwordsmithStage = v end)
    AddToggle(swordCard, "Blood Moon When Up", Config.BloodMoonWhenUp, function(v) Config.BloodMoonWhenUp = v end)
    AddSlider(swordCard, "Skip A Stage After Losses", 0, 10, Config.SkipStageAfterLosses, "", function(v) Config.SkipStageAfterLosses = v end)
    AddToggle(swordCard, "Auto Misty Tower", Config.AutoMistyTower, function(v) Config.AutoMistyTower = v end)
    AddToggle(swordCard, "Misty Matchmaking (OFF = Play Here)", Config.MistyMatchmaking, function(v) Config.MistyMatchmaking = v end)
    AddSlider(swordCard, "Rest After Losses", 0, 10, Config.RestAfterLosses, "", function(v) Config.RestAfterLosses = v end)

    -- ========================================================================
    -- TAB 5: GAME
    -- ========================================================================
    local gamePage = AddNavTab("Game")
    local gameCard = CreateCard(gamePage, "Match Flow")
    AddToggle(gameCard, "Auto Start", Config.AutoStartMatch, function(v) Config.AutoStartMatch = v end)
    AddToggle(gameCard, "Auto Skip Waves", Config.AutoSkipWaves, function(v) Config.AutoSkipWaves = v end)
    AddToggle(gameCard, "Auto Replay", Config.AutoReplay, function(v) Config.AutoReplay = v end)
    AddToggle(gameCard, "Claim Clear Rewards", Config.ClaimClearRewards, function(v) Config.ClaimClearRewards = v end)

    SelectTab("Home")

    -- Live Status & Heartbeat Loop
    local frames = 0
    local currentFps = 60
    RunService.RenderStepped:Connect(function()
        frames = frames + 1
    end)

    task.spawn(function()
        while sg.Parent do
            task.wait(1)
            currentFps = frames
            frames = 0

            local elapsed = math.floor(os.clock() - SessionStart)
            local mins = math.floor(elapsed / 60)
            local secs = elapsed % 60
            local pingMs = 0
            pcall(function()
                pingMs = math.floor(StatsService.Network.ServerStatsItem["Data Ping"]:GetValue())
            end)

            local waveNow = GetCurrentWave()
            Config.CurrentWave = waveNow

            statusLbl.Text = string.format(
                "Session: %dm %ds  |  Features On: %d\nFPS: %d  |  Ping: %d ms  |  Runs: %d  |  Wave: %d",
                mins, secs, CountActiveFeatures(), currentFps, pingMs, Config.Runs, waveNow
            )
            topPill.Text = string.format("AA Unified  •  %d fps  •  Tap to toggle", currentFps)
        end
    end)

    return sg
end

local HubGui = BuildTabbedHub()

-- ============================================================================
-- 7. MAIN RUNTIME LOOP
-- ============================================================================
task.spawn(function()
    while task.wait(0.35) do
        if IsInLobby() then
            StepLobbyJoinAndMatchmaking(HubGui)
        else
            if Config.AutoStartMatch then
                CallRemoteFuzzy({ "vote_start", "start_game", "ready" })
            end
            if Config.AutoSkipWaves then
                CallRemoteFuzzy({ "vote_wave_skip", "skip_wave" })
            end
            StepMacroRuntime()
        end
    end
end)
