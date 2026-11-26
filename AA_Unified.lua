-- ============================================================================
-- ANIME ADVENTURES (UPD 21.5+) - FULL COMPILED AUTO-FARM & MACRO PANEL
-- Save as 'AA_Unified.lua' in your executor's 'autoexec' and 'workspace' folders.
-- ============================================================================

repeat task.wait() until game:IsLoaded()

if getgenv().AA_Loaded then
    warn("[AA_Unified] Re-executing UI & updating loops...")
end
getgenv().AA_Loaded = true

-- 1. SELF-PERSISTENCE ACROSS TELEPORTS (Lobby <-> Match)
local SCRIPT_FILENAME = "AA_Unified.lua"
local queueTeleport = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)

if queueTeleport and isfile and readfile and isfile(SCRIPT_FILENAME) then
    pcall(function()
        queueTeleport(readfile(SCRIPT_FILENAME))
    end)
end

-- 2. SERVICES & REFERENCES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 15)

-- 3. PERSISTENT CONFIGURATION
local CONFIG_FILENAME = "AA_Config.json"
local DefaultConfig = {
    Enabled = true,
    Mode = "SummerEvent",          -- Options: "SummerEvent", "MistyVillage", "Story", "InfinityCastle"

    -- UNIVERSAL PARTY JOIN (Applies across ALL Farm Modes)
    PartyJoinEnabled = false,
    AutoCreatePartyFallback = true, -- If no matching party exists after timeout, queue solo pod
    PartySearchTimeout = 8,         -- Seconds to scan PartyFinder before solo pod fallback
    TargetPartyName = "",           -- Leave blank to auto-match current Mode (e.g., "Summer", "Misty", "Namek")

    -- PLACEMENT & MACRO SETTINGS
    PlacementMode = "Percentage",  -- Options: "Percentage", "Macro"
    ActiveMacroName = "Default",
    AutoPlace = true,
    LanePercent = 0.50,
    SlotPercentSpread = 0.04,
    RoadSideOffset = 6.5,
    HillOffset = Vector3.new(0, 1, 0),

    -- DISCORD WEBHOOK & MATCH REWARDS SETTINGS
    WebhookEnabled = true,
    WebhookUrl = "",
    DiscordUserId = "",
    SendMatchWebhookOnEnd = true,
    PingOnlyOnPortalDrop = false,
    NotifyEveryRotation = true,
    NotifyOnlyOnTarget = false,
    LastNotifiedBannerHash = "",

    -- BANNER CHECKER, RARITY FILTER & AUTO-SUMMON
    BannerCheckEnabled = true,
    TargetBannerUnit = "Vego",
    TargetBannerRarity = "Mythic", -- Options: "Any", "Legendary", "Mythic", "Secret"
    TargetBannerType = "Standard", -- Options: "Standard", "MistyVillage", "Summer"
    SummonMulti = true,
    BannerTargetAcquired = false,

    -- STORY SETTINGS
    StoryPod = "Story_Pod_1",
    StoryWorld = "namek",
    StoryAct = "1",
    StoryDifficulty = "Normal",

    -- MATCH & UPDATE 21.5 SETTINGS
    AutoStart = true,
    AutoSkipWaves = true,
    AutoReplay = true,
    UseNativeAutoUpgrade = true,
    FallbackManualUpgrade = true,
    SummerVoteTsunami = true,
    AutoPickModifierCard = true,
    CaptchaBypass = true
}

local function LoadConfig()
    if isfile and readfile and isfile(CONFIG_FILENAME) then
        local ok, decoded = pcall(function()
            return HttpService:JSONDecode(readfile(CONFIG_FILENAME))
        end)
        if ok and type(decoded) == "table" then
            -- Migrate legacy Mode == "PartyJoin" cleanly
            if decoded.Mode == "PartyJoin" then
                decoded.Mode = "SummerEvent"
                decoded.PartyJoinEnabled = true
            end
            for k, v in pairs(DefaultConfig) do
                if decoded[k] == nil then decoded[k] = v end
            end
            return decoded
        end
    end
    return DefaultConfig
end

local function SaveConfig(cfg)
    if writefile then
        pcall(function()
            writefile(CONFIG_FILENAME, HttpService:JSONEncode(cfg))
        end)
    end
end

getgenv().AAConfig = LoadConfig()
SaveConfig(getgenv().AAConfig)

-- 4. SAFE GUI CLICKER (FIRESIGNAL + VIRTUALINPUTMANAGER FALLBACK)
local function ClickGuiButton(btn)
    if not btn or not btn:IsA("GuiButton") then return false end

    local clicked = false
    if firesignal then
        pcall(function()
            firesignal(btn.MouseButton1Click)
            clicked = true
        end)
        pcall(function()
            firesignal(btn.Activated)
            clicked = true
        end)
        pcall(function()
            firesignal(btn.MouseButton1Down)
            firesignal(btn.MouseButton1Up)
        end)
    end

    if VirtualInputManager then
        pcall(function()
            local inset = GuiService:GetGuiInset()
            local pos = btn.AbsolutePosition
            local size = btn.AbsoluteSize
            if size.X > 0 and size.Y > 0 then
                local cx = pos.X + (size.X / 2)
                local cy = pos.Y + (size.Y / 2) + inset.Y
                VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, true, game, 1)
                task.wait(0.03)
                VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, false, game, 1)
                clicked = true
            end
        end)
    end

    return clicked
end

-- 5. ANTI-AFK & FUZZY REMOTE DISPATCHER
LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

local RemoteCache = {}
local DiscoveredRemotes = {}

local function IndexAllRemotes()
    table.clear(DiscoveredRemotes)
    for _, desc in ipairs(ReplicatedStorage:GetDescendants()) do
        if desc:IsA("RemoteEvent") or desc:IsA("RemoteFunction") then
            table.insert(DiscoveredRemotes, desc)
        end
    end
end
IndexAllRemotes()

ReplicatedStorage.DescendantAdded:Connect(function(desc)
    if desc:IsA("RemoteEvent") or desc:IsA("RemoteFunction") then
        table.insert(DiscoveredRemotes, desc)
    end
end)

local function FindRemote(remoteNameOrPatterns)
    local patterns = type(remoteNameOrPatterns) == "table" and remoteNameOrPatterns or { remoteNameOrPatterns }
    local cacheKey = patterns[1]

    if RemoteCache[cacheKey] and RemoteCache[cacheKey].Parent then
        return RemoteCache[cacheKey]
    end

    for _, pat in ipairs(patterns) do
        local lowerPat = pat:lower()
        for _, r in ipairs(DiscoveredRemotes) do
            if r.Parent and r.Name:lower() == lowerPat then
                RemoteCache[cacheKey] = r
                return r
            end
        end
    end

    for _, pat in ipairs(patterns) do
        local lowerPat = pat:lower()
        for _, r in ipairs(DiscoveredRemotes) do
            if r.Parent and r.Name:lower():find(lowerPat, 1, true) then
                RemoteCache[cacheKey] = r
                return r
            end
        end
    end

    return nil
end

local function FindAllMatchingRemotes(patterns)
    local matches = {}
    local seen = {}
    for _, pat in ipairs(patterns) do
        local lowerPat = pat:lower()
        for _, r in ipairs(DiscoveredRemotes) do
            if r.Parent and not seen[r] and r.Name:lower():find(lowerPat, 1, true) then
                seen[r] = true
                table.insert(matches, r)
            end
        end
    end
    return matches
end

local function FireEndpoint(remoteNameOrPatterns, ...)
    local remote = FindRemote(remoteNameOrPatterns)
    if not remote then return nil end
    local args = {...}
    local ok, res = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(unpack(args))
        elseif remote:IsA("RemoteFunction") then
            return remote:InvokeServer(unpack(args))
        end
    end)
    return ok and res or nil
end

-- 6. STATE DETECTION (LOBBY VS MATCH)
local function IsInLobby()
    if workspace:FindFirstChild("_lobby") or workspace:FindFirstChild("Lobby") then
        return true
    end
    local wavesObj = workspace:FindFirstChild("_waves") or workspace:FindFirstChild("_wave")
    if wavesObj then
        return false
    end
    if PlayerGui and (PlayerGui:FindFirstChild("SpawnUnitUI", true) or PlayerGui:FindFirstChild("WaveUI", true)) then
        return false
    end
    return true
end

-- 7. MODULE: MACRO RECORDER, STORAGE & PLAYBACK ENGINE
local MacroState = {
    IsRecording = false,
    RecordStartTime = 0,
    RecordedSteps = {},
    IsPlaying = false,
    PlaybackStartTime = 0,
    CurrentStepIndex = 1,
    HookInstalled = false,
    HookSupported = (hookmetamethod ~= nil and getnamecallmethod ~= nil and checkcaller ~= nil)
}

local function FormatTimer(seconds)
    seconds = math.max(0, seconds or 0)
    local mins = math.floor(seconds / 60)
    local secs = seconds % 60
    return string.format("%02d:%04.1f", mins, secs)
end

local function GetMacroFilename(name)
    local clean = tostring(name or "Default"):gsub("[^%w_%-]", "")
    if clean == "" then clean = "Default" end
    return "AA_Macro_" .. clean .. ".json"
end

local function SaveMacroFile(name, steps)
    if not writefile then return end
    local payload = {
        macroName = name,
        totalDuration = (#steps > 0) and steps[#steps].time or 0,
        steps = steps
    }
    pcall(function()
        writefile(GetMacroFilename(name), HttpService:JSONEncode(payload))
    end)
end

local function LoadMacroFile(name)
    local fname = GetMacroFilename(name)
    if isfile and readfile and isfile(fname) then
        local ok, decoded = pcall(function()
            return HttpService:JSONDecode(readfile(fname))
        end)
        if ok and type(decoded) == "table" and type(decoded.steps) == "table" then
            return decoded.steps, decoded.totalDuration or 0
        end
    end
    return {}, 0
end

local function GetOwnedUnitsList()
    local list = {}
    local activeUnits = workspace:FindFirstChild("_units") or workspace:FindFirstChild("Units")
    if not activeUnits then return list end

    for _, u in ipairs(activeUnits:GetChildren()) do
        local uStats = u:FindFirstChild("_stats") or u:FindFirstChild("Stats")
        local owner = uStats and (uStats:FindFirstChild("player") or uStats:FindFirstChild("Owner"))
        local ownerAttr = u:GetAttribute("Owner") or u:GetAttribute("Player")
        if (owner and owner.Value == LocalPlayer) or (ownerAttr and tostring(ownerAttr) == LocalPlayer.Name) then
            table.insert(list, u)
        end
    end
    return list
end

local function GetOwnedUnitIndex(unitObj)
    for i, u in ipairs(GetOwnedUnitsList()) do
        if u == unitObj then return i end
    end
    return 1
end

local function GetOwnedUnitByIndex(targetIdx)
    return GetOwnedUnitsList()[targetIdx]
end

local function InstallMacroHook()
    if MacroState.HookInstalled or not MacroState.HookSupported then return end

    local ok = pcall(function()
        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            local args = {...}

            if MacroState.IsRecording and not checkcaller() and (method == "FireServer" or method == "InvokeServer") then
                if typeof(self) == "Instance" and self:IsDescendantOf(ReplicatedStorage) then
                    local rName = self.Name:lower()
                    local elapsed = os.clock() - MacroState.RecordStartTime

                    if (rName:find("spawn") or rName:find("place")) and typeof(args[2]) == "CFrame" then
                        local cf = args[2]
                        table.insert(MacroState.RecordedSteps, {
                            time = elapsed,
                            action = "spawn_unit",
                            unitId = tostring(args[1]),
                            pos = { cf.X, cf.Y, cf.Z }
                        })
                    elseif rName:find("upgrade") and typeof(args[1]) == "Instance" then
                        table.insert(MacroState.RecordedSteps, {
                            time = elapsed,
                            action = "upgrade_unit_ingame",
                            unitIndex = GetOwnedUnitIndex(args[1])
                        })
                    elseif rName:find("sell") and typeof(args[1]) == "Instance" then
                        table.insert(MacroState.RecordedSteps, {
                            time = elapsed,
                            action = "sell_unit",
                            unitIndex = GetOwnedUnitIndex(args[1])
                        })
                    end
                end
            end

            return oldNamecall(self, ...)
        end)
    end)

    if ok then
        MacroState.HookInstalled = true
    else
        MacroState.HookSupported = false
    end
end

local function AttachWorkspaceFallbackRecorder()
    local activeUnits = workspace:FindFirstChild("_units") or workspace:FindFirstChild("Units")
    if not activeUnits then return end

    activeUnits.ChildAdded:Connect(function(unit)
        if not MacroState.IsRecording or MacroState.HookInstalled then return end
        task.wait(0.15)
        local uStats = unit:FindFirstChild("_stats") or unit:FindFirstChild("Stats")
        local owner = uStats and uStats:FindFirstChild("player")
        if owner and owner.Value == LocalPlayer then
            local pos = unit:GetPivot().Position
            local unitId = tostring(unit:GetAttribute("UnitId") or (uStats:FindFirstChild("id") and uStats.id.Value) or unit.Name)
            table.insert(MacroState.RecordedSteps, {
                time = os.clock() - MacroState.RecordStartTime,
                action = "spawn_unit",
                unitId = unitId,
                pos = { pos.X, pos.Y, pos.Z }
            })
        end
    end)
end
AttachWorkspaceFallbackRecorder()

local function StartMacroRecording()
    InstallMacroHook()
    MacroState.IsPlaying = false
    MacroState.RecordedSteps = {}
    MacroState.RecordStartTime = os.clock()
    MacroState.IsRecording = true
end

local function StopMacroRecording()
    if not MacroState.IsRecording then return end
    MacroState.IsRecording = false
    SaveMacroFile(getgenv().AAConfig.ActiveMacroName, MacroState.RecordedSteps)
end

local function ResetMacroPlayback()
    MacroState.IsPlaying = false
    MacroState.PlaybackStartTime = 0
    MacroState.CurrentStepIndex = 1
end

local function StartMacroPlaybackNow()
    local cfg = getgenv().AAConfig
    if MacroState.IsRecording then
        StopMacroRecording()
    end
    cfg.PlacementMode = "Macro"
    SaveConfig(cfg)
    ResetMacroPlayback()
    local steps = LoadMacroFile(cfg.ActiveMacroName)
    if #steps > 0 then
        MacroState.IsPlaying = true
        MacroState.PlaybackStartTime = os.clock()
        MacroState.CurrentStepIndex = 1
        return true, #steps
    end
    return false, 0
end

local function StepMacroPlayback()
    if MacroState.IsRecording then return end

    local steps = LoadMacroFile(getgenv().AAConfig.ActiveMacroName)
    if #steps == 0 then return end

    if not MacroState.IsPlaying then
        MacroState.IsPlaying = true
        MacroState.PlaybackStartTime = os.clock()
        MacroState.CurrentStepIndex = 1
    end

    local elapsed = os.clock() - MacroState.PlaybackStartTime
    while MacroState.CurrentStepIndex <= #steps do
        local step = steps[MacroState.CurrentStepIndex]
        if elapsed >= (step.time or 0) then
            if step.action == "spawn_unit" and step.pos then
                local cf = CFrame.new(step.pos[1], step.pos[2], step.pos[3])
                FireEndpoint({"spawn_unit", "place_unit"}, step.unitId, cf)
            elseif step.action == "upgrade_unit_ingame" then
                local unitObj = GetOwnedUnitByIndex(step.unitIndex or 1)
                if unitObj then FireEndpoint({"upgrade_unit_ingame", "upgrade_unit"}, unitObj) end
            elseif step.action == "sell_unit" then
                local unitObj = GetOwnedUnitByIndex(step.unitIndex or 1)
                if unitObj then FireEndpoint({"sell_unit", "sell"}, unitObj) end
            end
            MacroState.CurrentStepIndex = MacroState.CurrentStepIndex + 1
        else
            break
        end
    end
end

-- 8. MODULE: MATCH REWARDS TRACKER, PORTAL DETECTOR & DISCORD WEBHOOKS
local MatchTracker = {
    SnapshotTaken = false,
    WebhookSentThisMatch = false,
    StartTime = 0,
    StartCurrencies = {},
    StartItems = {},
    LastSummaryText = "No completed match recorded yet."
}

local function ReadPlayerCurrencies()
    local stats = LocalPlayer:FindFirstChild("_stats") or LocalPlayer:FindFirstChild("Stats")
    local result = { Gems = 0, SummerPearls = 0, DawnCoins = 0, Gold = 0 }
    if not stats then return result end

    local function GetStatVal(names)
        for _, n in ipairs(names) do
            local obj = stats:FindFirstChild(n)
            if obj and (obj:IsA("IntValue") or obj:IsA
