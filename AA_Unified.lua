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
local PathfindingService = game:GetService("PathfindingService")
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

    -- UNIVERSAL PARTY JOIN & LOBBY NAVIGATION
    PartyJoinEnabled = false,
    AutoCreatePartyFallback = true, -- If no matching party exists after timeout, queue solo pod
    PartySearchTimeout = 8,         -- Seconds to scan PartyFinder before solo pod fallback
    TargetPartyName = "",           -- Leave blank to auto-match current Mode (e.g., "Summer", "Misty", "Namek")
    LobbyMoveMethod = "Hybrid",     -- Options: "Hybrid" (Walk + Teleport fallback), "Teleport", "Walk"

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
            if obj and (obj:IsA("IntValue") or obj:IsA("NumberValue")) then
                return obj.Value
            end
        end
        return 0
    end

    result.Gems = GetStatVal({"gems", "Gems"})
    result.SummerPearls = GetStatVal({"summer_pearls", "SummerPearls", "pearls", "Pearls"})
    result.DawnCoins = GetStatVal({"dawn_coins", "DawnCoins"})
    result.Gold = GetStatVal({"gold", "Gold"})
    return result
end

local function ReadPlayerItemCounts()
    local stats = LocalPlayer:FindFirstChild("_stats") or LocalPlayer:FindFirstChild("Stats")
    local counts = {}
    if not stats then return counts end

    local folders = {
        stats:FindFirstChild("items"),
        stats:FindFirstChild("portals"),
        stats:FindFirstChild("inventory")
    }

    for _, folder in ipairs(folders) do
        if folder then
            for _, item in ipairs(folder:GetChildren()) do
                local itemName = tostring(item:GetAttribute("ItemId") or item.Name)
                local qty = (item:IsA("IntValue") or item:IsA("NumberValue")) and item.Value
                    or tonumber(item:GetAttribute("Amount") or item:GetAttribute("Count") or 1) or 1
                counts[itemName] = (counts[itemName] or 0) + qty
            end
        end
    end
    return counts
end

local function CapturePreMatchSnapshot()
    if MatchTracker.SnapshotTaken then return end
    MatchTracker.SnapshotTaken = true
    MatchTracker.WebhookSentThisMatch = false
    MatchTracker.StartTime = os.clock()
    MatchTracker.StartCurrencies = ReadPlayerCurrencies()
    MatchTracker.StartItems = ReadPlayerItemCounts()
end

local function ResetMatchSnapshot()
    MatchTracker.SnapshotTaken = false
    MatchTracker.WebhookSentThisMatch = false
end

local function GetMatchRewardsReport()
    local endCurrencies = ReadPlayerCurrencies()
    local endItems = ReadPlayerItemCounts()
    local durationStr = FormatTimer(os.clock() - (MatchTracker.StartTime > 0 and MatchTracker.StartTime or os.clock()))

    local earnedLines = {}
    local currencyOrder = {
        { key = "SummerPearls", label = "SummerPearls" },
        { key = "DawnCoins", label = "Dawn Coins" },
        { key = "Gems", label = "Gems" },
        { key = "Gold", label = "Gold" }
    }

    for _, c in ipairs(currencyOrder) do
        local diff = (endCurrencies[c.key] or 0) - (MatchTracker.StartCurrencies[c.key] or 0)
        if diff > 0 then
            table.insert(earnedLines, string.format("• **+%d %s** (Total: %d)", diff, c.label, endCurrencies[c.key]))
        end
    end

    local dropLines = {}
    local hasPortalDrop = false

    for itemName, newQty in pairs(endItems) do
        local oldQty = MatchTracker.StartItems[itemName] or 0
        local gained = newQty - oldQty
        if gained > 0 then
            local isPortal = itemName:lower():find("portal") ~= nil
            if isPortal then hasPortalDrop = true end
            local prefix = isPortal and "🌀 **[PORTAL DROP]** " or "• "
            table.insert(dropLines, string.format("%s**+%dx %s**", prefix, gained, itemName))
        end
    end

    local resultsGui = PlayerGui and (PlayerGui:FindFirstChild("ResultsUI") or PlayerGui:FindFirstChild("EndScreen"))
    local waveText = "Completed"
    if resultsGui then
        for _, lbl in ipairs(resultsGui:GetDescendants()) do
            if lbl:IsA("TextLabel") and lbl.Visible and lbl.Text ~= "" then
                local txt = lbl.Text
                local lower = txt:lower()
                if lower:find("wave") then
                    waveText = txt
                elseif lower:find("portal") then
                    hasPortalDrop = true
                    table.insert(dropLines, "🌀 **[PORTAL DROP]** **" .. txt .. "**")
                elseif txt:match("^%+%d+") then
                    table.insert(earnedLines, "• **" .. txt .. "**")
                end
            end
        end
    end

    local earnedStr = #earnedLines > 0 and table.concat(earnedLines, "\n") or "• _No currency delta detected_"
    local dropsStr = #dropLines > 0 and table.concat(dropLines, "\n") or "• _No item or portal drops this run_"

    MatchTracker.LastSummaryText = string.format("Last Run (%s | %s):\n%s\n%s", waveText, durationStr, earnedStr:gsub("%*", ""), dropsStr:gsub("%*", ""))

    return {
        wave = waveText,
        duration = durationStr,
        earnedText = earnedStr,
        dropsText = dropsStr,
        hasPortal = hasPortalDrop
    }
end

local function SendMatchEndWebhook(forceTest)
    local cfg = getgenv().AAConfig
    if not cfg.WebhookEnabled or not cfg.SendMatchWebhookOnEnd then return false end
    if cfg.WebhookUrl == "" then return false end
    if not forceTest and MatchTracker.WebhookSentThisMatch then return false end

    local httpReq = request or http_request or (syn and syn.request) or (fluxus and fluxus.request)
    if not httpReq then return false end

    local report = GetMatchRewardsReport()
    MatchTracker.WebhookSentThisMatch = true

    local shouldPing = (cfg.DiscordUserId ~= "") and (not cfg.PingOnlyOnPortalDrop or report.hasPortal)
    local pingContent = shouldPing and string.format("<@%s>", tostring(cfg.DiscordUserId):gsub("%D", "")) or ""

    local modeDisplay = cfg.Mode .. (cfg.PartyJoinEnabled and " (PartyJoin)" or "")
    local titleText = report.hasPortal
        and "🌀 PORTAL DROP! Match Completed (" .. modeDisplay .. ")"
        or "🏆 Match Completed — " .. modeDisplay

    local payload = {
        content = pingContent,
        username = "AA Match Tracker",
        embeds = {{
            title = titleText,
            color = report.hasPortal and 10181046 or 3066993,
            fields = {
                { name = "Stage / Wave", value = report.wave, inline = true },
                { name = "Clear Time", value = report.duration, inline = true },
                { name = "Currency Earned", value = report.earnedText, inline = false },
                { name = "Items & Portals Dropped", value = report.dropsText, inline = false }
            },
            footer = { text = "Anime Adventures Auto-Tracker • " .. os.date("%X") }
        }}
    }

    pcall(function()
        httpReq({
            Url = cfg.WebhookUrl,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(payload)
        })
    end)

    return true
end

-- 9. MODULE: LIVE BANNER SCANNER & BANNER WEBHOOK
local function GetCurrentBannerUnits()
    local foundUnits = {}
    local seen = {}

    local function AddUnitEntry(unitName, rarityText)
        unitName = tostring(unitName or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if unitName == "" or #unitName < 2 then return end
        local key = unitName:lower()
        if not seen[key] then
            seen[key] = true
            table.insert(foundUnits, {
                name = unitName,
                rarity = tostring(rarityText or "Featured")
            })
        end
    end

    local bannerData = ReplicatedStorage:FindFirstChild("banner_data") or ReplicatedStorage:FindFirstChild("Banners")
    if bannerData then
        for _, obj in ipairs(bannerData:GetDescendants()) do
            if obj:IsA("StringValue") and obj.Value ~= "" then
                local rar = obj.Parent and obj.Parent:FindFirstChild("Rarity")
                AddUnitEntry(obj.Value, rar and rar.Value or "Featured")
            elseif obj:GetAttribute("UnitId") then
                AddUnitEntry(obj:GetAttribute("UnitId"), obj:GetAttribute("Rarity") or "Featured")
            end
        end
    end

    local summonGui = PlayerGui and (PlayerGui:FindFirstChild("SummonUI", true) or PlayerGui:FindFirstChild("BannerGui", true))
    if summonGui then
        for _, frame in ipairs(summonGui:GetDescendants()) do
            if frame:IsA("Frame") or frame:IsA("ImageLabel") then
                local nameLbl = frame:FindFirstChild("UnitName", true) or frame:FindFirstChild("Title", true)
                local rarLbl = frame:FindFirstChild("Rarity", true)
                if nameLbl and nameLbl:IsA("TextLabel") and nameLbl.Text ~= "" then
                    AddUnitEntry(nameLbl.Text, rarLbl and rarLbl:IsA("TextLabel") and rarLbl.Text or "Featured")
                end
            end
        end
    end

    return foundUnits
end

local function HasTargetUnitInInventory(targetName, targetRarity)
    local stats = LocalPlayer:FindFirstChild("_stats") or LocalPlayer:FindFirstChild("Stats")
    local ownedUnits = stats and (stats:FindFirstChild("units") or stats:FindFirstChild("inventory"))
    if not ownedUnits then return false end

    local needle = targetName:lower()
    local reqRarity = (targetRarity or "Any"):lower()

    for _, item in ipairs(ownedUnits:GetChildren()) do
        local unitId = tostring(item:GetAttribute("UnitId") or item.Name or item.Value):lower()
        local rarity = tostring(item:GetAttribute("Rarity") or (item:FindFirstChild("Rarity") and item.Rarity.Value) or ""):lower()

        if unitId:find(needle, 1, true) then
            if reqRarity == "any" or rarity:find(reqRarity, 1, true) then
                return true
            end
        end
    end
    return false
end

local function IsTargetUnitOnBanner()
    local cfg = getgenv().AAConfig
    if not cfg.BannerCheckEnabled or cfg.BannerTargetAcquired then return false end
    if cfg.TargetBannerUnit == "" then return false end

    if HasTargetUnitInInventory(cfg.TargetBannerUnit, cfg.TargetBannerRarity) then
        cfg.BannerTargetAcquired = true
        SaveConfig(cfg)
        return false
    end

    local needle = cfg.TargetBannerUnit:lower()
    local reqRarity = (cfg.TargetBannerRarity or "Any"):lower()
    local units = GetCurrentBannerUnits()

    for _, u in ipairs(units) do
        if u.name:lower():find(needle, 1, true) then
            if reqRarity == "any" or u.rarity:lower() == "featured" or u.rarity:lower():find(reqRarity, 1, true) then
                return true
            end
        end
    end

    return false
end

local function SendBannerWebhook(forceTest)
    local cfg = getgenv().AAConfig
    if not cfg.WebhookEnabled or cfg.WebhookUrl == "" then return false end

    local httpReq = request or http_request or (syn and syn.request) or (fluxus and fluxus.request)
    if not httpReq then return false end

    local units = GetCurrentBannerUnits()
    local targetFound = IsTargetUnitOnBanner()

    local lines = {}
    local hashParts = {}
    for _, u in ipairs(units) do
        table.insert(lines, string.format("• **%s** (%s)", u.name, u.rarity))
        table.insert(hashParts, u.name .. ":" .. u.rarity)
    end

    local bannerHash = table.concat(hashParts, "|")
    if not forceTest then
        if bannerHash == "" or bannerHash == cfg.LastNotifiedBannerHash then
            return false
        end
        if cfg.NotifyOnlyOnTarget and not targetFound then
            return false
        end
    end

    cfg.LastNotifiedBannerHash = bannerHash
    SaveConfig(cfg)

    local pingContent = (targetFound and cfg.DiscordUserId ~= "")
        and string.format("<@%s>", tostring(cfg.DiscordUserId):gsub("%D", ""))
        or ""

    local unitListText = #lines > 0 and table.concat(lines, "\n") or "_No banner data cached yet (open Summon UI once in lobby)._"
    local titleText = targetFound
        and string.format("🚨 TARGET UNIT ON BANNER: %s (%s)!", cfg.TargetBannerUnit, cfg.TargetBannerRarity)
        or "📢 Anime Adventures — Current Banner Rotation"

    local payload = {
        content = pingContent,
        username = "AA Banner Watcher",
        embeds = {{
            title = titleText,
            description = unitListText,
            color = targetFound and 16729344 or 3447003,
            fields = {
                { name = "Target Unit", value = string.format("%s (%s)", cfg.TargetBannerUnit, cfg.TargetBannerRarity), inline = true },
                { name = "Location", value = IsInLobby() and "Lobby" or "In Match", inline = true }
            },
            footer = { text = "Anime Adventures Auto-Checker • " .. os.date("%X") }
        }}
    }

    pcall(function()
        httpReq({
            Url = cfg.WebhookUrl,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(payload)
        })
    end)

    return true
end

-- 10. MODULE: MODERN STYLED UI (CYAN / VIOLET / EMERALD DARK THEME)
local ActivityLabelRef = nil
local UnitCountLabelRef = nil
local MacroStatusLabelRef = nil

local function CreateStyledControlGui()
    local existing = CoreGui:FindFirstChild("AAModernHubUI") or (PlayerGui and PlayerGui:FindFirstChild("AAModernHubUI"))
    if existing then existing:Destroy() end

    local cfg = getgenv().AAConfig

    local COL_BG_DARK   = Color3.fromRGB(16, 18, 24)
    local COL_CARD      = Color3.fromRGB(23, 26, 35)
    local COL_INPUT     = Color3.fromRGB(15, 17, 23)
    local COL_CYAN      = Color3.fromRGB(45, 226, 230)
    local COL_VIOLET    = Color3.fromRGB(138, 92, 246)
    local COL_EMERALD   = Color3.fromRGB(16, 185, 129)
    local COL_RED       = Color3.fromRGB(239, 68, 68)
    local COL_AMBER     = Color3.fromRGB(245, 158, 11)
    local COL_TEXT_MAIN = Color3.fromRGB(240, 244, 250)
    local COL_TEXT_DIM  = Color3.fromRGB(150, 160, 180)

    local gui = Instance.new("ScreenGui")
    gui.Name = "AAModernHubUI"
    gui.ResetOnSpawn = false
    pcall(function() gui.Parent = CoreGui end)
    if not gui.Parent and PlayerGui then gui.Parent = PlayerGui end

    local main = Instance.new("Frame")
    main.Name = "MainWindow"
    main.Size = UDim2.new(0, 500, 0, 325)
    main.Position = UDim2.new(0.5, -250, 0.22, 0)
    main.BackgroundColor3 = COL_BG_DARK
    main.BorderSizePixel = 0
    main.Active = true
    main.Draggable = true
    main.Parent = gui
    Instance.new("UICorner", main).CornerRadius = UDim.new(0, 12)

    local mainStroke = Instance.new("UIStroke", main)
    mainStroke.Thickness = 1.6
    mainStroke.Color = Color3.new(1, 1, 1)

    local borderGrad = Instance.new("UIGradient", mainStroke)
    borderGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.0, COL_CYAN),
        ColorSequenceKeypoint.new(0.5, COL_VIOLET),
        ColorSequenceKeypoint.new(1.0, COL_EMERALD)
    })

    local topBar = Instance.new("Frame")
    topBar.Size = UDim2.new(1, 0, 0, 38)
    topBar.BackgroundTransparency = 1
    topBar.Parent = main

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -80, 1, 0)
    titleLbl.Position = UDim2.new(0, 16, 0, 0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextSize = 14
    titleLbl.TextColor3 = COL_TEXT_MAIN
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Text = "Anime Adventures — Unified Control Panel (Upd 21.5)"
    titleLbl.Parent = topBar

    local minBtn = Instance.new("TextButton")
    minBtn.Size = UDim2.new(0, 26, 0, 26)
    minBtn.Position = UDim2.new(1, -64, 0, 6)
    minBtn.BackgroundColor3 = COL_CARD
    minBtn.Font = Enum.Font.GothamBold
    minBtn.TextSize = 14
    minBtn.TextColor3 = COL_TEXT_DIM
    minBtn.Text = "—"
    minBtn.Parent = topBar
    Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 6)

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 26, 0, 26)
    closeBtn.Position = UDim2.new(1, -34, 0, 6)
    closeBtn.BackgroundColor3 = COL_CARD
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 13
    closeBtn.TextColor3 = COL_TEXT_DIM
    closeBtn.Text = "X"
    closeBtn.Parent = topBar
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

    local divider = Instance.new("Frame")
    divider.Size = UDim2.new(1, -24, 0, 1)
    divider.Position = UDim2.new(0, 12, 0, 38)
    divider.BackgroundColor3 = Color3.fromRGB(38, 44, 58)
    divider.BorderSizePixel = 0
    divider.Parent = main

    local sidebar = Instance.new("Frame")
    sidebar.Size = UDim2.new(0, 130, 1, -50)
    sidebar.Position = UDim2.new(0, 12, 0, 46)
    sidebar.BackgroundTransparency = 1
    sidebar.Parent = main

    local sideLayout = Instance.new("UIListLayout", sidebar)
    sideLayout.Padding = UDim.new(0, 8)

    local contentArea = Instance.new("Frame")
    contentArea.Size = UDim2.new(1, -162, 1, -86)
    contentArea.Position = UDim2.new(0, 150, 0, 46)
    contentArea.BackgroundTransparency = 1
    contentArea.Parent = main

    local footerBar = Instance.new("Frame")
    footerBar.Size = UDim2.new(1, -162, 0, 30)
    footerBar.Position = UDim2.new(0, 150, 1, -38)
    footerBar.BackgroundColor3 = COL_CARD
    footerBar.Parent = main
    Instance.new("UICorner", footerBar).CornerRadius = UDim.new(0, 8)
    local footerStroke = Instance.new("UIStroke", footerBar)
    footerStroke.Color = Color3.fromRGB(42, 52, 68)
    footerStroke.Thickness = 1

    local activityLbl = Instance.new("TextLabel")
    activityLbl.Size = UDim2.new(0.68, 0, 1, 0)
    activityLbl.Position = UDim2.new(0, 10, 0, 0)
    activityLbl.BackgroundTransparency = 1
    activityLbl.Font = Enum.Font.GothamSemibold
    activityLbl.TextSize = 11
    activityLbl.TextColor3 = COL_EMERALD
    activityLbl.TextXAlignment = Enum.TextXAlignment.Left
    activityLbl.Text = "● Script Activity: Running"
    activityLbl.Parent = footerBar
    ActivityLabelRef = activityLbl

    local unitCountLbl = Instance.new("TextLabel")
    unitCountLbl.Size = UDim2.new(0.30, -10, 1, 0)
    unitCountLbl.Position = UDim2.new(0.70, 0, 0, 0)
    unitCountLbl.BackgroundTransparency = 1
    unitCountLbl.Font = Enum.Font.GothamSemibold
    unitCountLbl.TextSize = 11
    unitCountLbl.TextColor3 = COL_CYAN
    unitCountLbl.TextXAlignment = Enum.TextXAlignment.Right
    unitCountLbl.Text = "Units: 0"
    unitCountLbl.Parent = footerBar
    UnitCountLabelRef = unitCountLbl

    local minimized = false
    minBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        sidebar.Visible = not minimized
        contentArea.Visible = not minimized
        footerBar.Visible = not minimized
        divider.Visible = not minimized
        main.Size = minimized and UDim2.new(0, 500, 0, 38) or UDim2.new(0, 500, 0, 325)
        minBtn.Text = minimized and "+" or "—"
    end)

    closeBtn.MouseButton1Click:Connect(function()
        gui.Enabled = false
    end)

    local pages = {}
    local tabButtons = {}

    local function CreateTab(labelText)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 36)
        btn.BackgroundColor3 = COL_CARD
        btn.Font = Enum.Font.GothamSemibold
        btn.TextSize = 12
        btn.TextColor3 = COL_TEXT_DIM
        btn.Text = labelText
        btn.Parent = sidebar
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

        local stroke = Instance.new("UIStroke", btn)
        stroke.Thickness = 1.2
        stroke.Color = COL_VIOLET
        stroke.Transparency = 0.45

        local page = Instance.new("ScrollingFrame")
        page.Size = UDim2.new(1, 0, 1, 0)
        page.BackgroundTransparency = 1
        page.BorderSizePixel = 0
        page.ScrollBarThickness = 3
        page.ScrollBarImageColor3 = COL_CYAN
        page.AutomaticCanvasSize = Enum.AutomaticSize.Y
        page.CanvasSize = UDim2.new(0, 0, 0, 0)
        page.Visible = false
        page.Parent = contentArea

        local layout = Instance.new("UIListLayout", page)
        layout.Padding = UDim.new(0, 7)

        btn.MouseButton1Click:Connect(function()
            for _, p in pairs(pages) do p.Visible = false end
            for _, item in pairs(tabButtons) do
                item.btn.TextColor3 = COL_TEXT_DIM
                item.stroke.Color = COL_VIOLET
                item.stroke.Thickness = 1.2
                item.stroke.Transparency = 0.45
            end
            page.Visible = true
            btn.TextColor3 = COL_CYAN
            stroke.Color = COL_CYAN
            stroke.Thickness = 1.8
            stroke.Transparency = 0
        end)

        table.insert(pages, page)
        table.insert(tabButtons, { btn = btn, stroke = stroke })
        return page
    end

    local function AddPillToggle(parent, labelText, configKey)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -4, 0, 34)
        row.BackgroundColor3 = COL_CARD
        row.Parent = parent
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)
        local rowStroke = Instance.new("UIStroke", row)
        rowStroke.Thickness = 1

        local dot = Instance.new("Frame")
        dot.Size = UDim2.new(0, 8, 0, 8)
        dot.Position = UDim2.new(0, 12, 0.5, -4)
        dot.Parent = row
        Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -95, 1, 0)
        lbl.Position = UDim2.new(0, 28, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.GothamSemibold
        lbl.TextSize = 12
        lbl.TextColor3 = COL_TEXT_MAIN
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Text = labelText
        lbl.Parent = row

        local pill = Instance.new("TextButton")
        pill.Size = UDim2.new(0, 54, 0, 22)
        pill.Position = UDim2.new(1, -64, 0.5, -11)
        pill.Font = Enum.Font.GothamBold
        pill.TextSize = 10
        pill.TextColor3 = Color3.new(1, 1, 1)
        pill.Parent = row
        Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)

        local function Refresh()
            local state = cfg[configKey]
            pill.Text = state and "ON" or "OFF"
            pill.BackgroundColor3 = state and COL_EMERALD or Color3.fromRGB(55, 62, 78)
            dot.BackgroundColor3 = state and COL_EMERALD or Color3.fromRGB(90, 98, 115)
            rowStroke.Color = state and Color3.fromRGB(28, 95, 78) or Color3.fromRGB(40, 46, 60)
        end

        Refresh()
        pill.MouseButton1Click:Connect(function()
            cfg[configKey] = not cfg[configKey]
            SaveConfig(cfg)
            Refresh()
        end)
    end

    local function AddDropdownCycle(parent, labelText, configKey, options, onChanged)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -4, 0, 34)
        row.BackgroundColor3 = COL_CARD
        row.Parent = parent
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)
        local s = Instance.new("UIStroke", row)
        s.Color = Color3.fromRGB(42, 50, 66)
        s.Thickness = 1

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.45, 0, 1, 0)
        lbl.Position = UDim2.new(0, 12, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 12
        lbl.TextColor3 = COL_TEXT_DIM
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Text = labelText
        lbl.Parent = row

        local valBtn = Instance.new("TextButton")
        valBtn.Size = UDim2.new(0.50, -10, 0, 24)
        valBtn.Position = UDim2.new(0.50, 0, 0.5, -12)
        valBtn.BackgroundColor3 = COL_INPUT
        valBtn.Font = Enum.Font.GothamSemibold
        valBtn.TextSize = 11
        valBtn.TextColor3 = COL_CYAN
        valBtn.Parent = row
        Instance.new("UICorner", valBtn).CornerRadius = UDim.new(0, 6)
        local vs = Instance.new("UIStroke", valBtn)
        vs.Color = Color3.fromRGB(48, 65, 88)
        vs.Thickness = 1

        local function Refresh()
            valBtn.Text = tostring(cfg[configKey]) .. "  ▾"
        end

        Refresh()
        valBtn.MouseButton1Click:Connect(function()
            local idx = 1
            for i, opt in ipairs(options) do
                if opt == cfg[configKey] then idx = i break end
            end
            cfg[configKey] = options[(idx % #options) + 1]
            SaveConfig(cfg)
            Refresh()
            if onChanged then onChanged(cfg[configKey]) end
        end)

        return Refresh
    end

    local function AddStyledInput(parent, labelText, configKey, isNumber, placeholder)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -4, 0, 34)
        row.BackgroundColor3 = COL_CARD
        row.Parent = parent
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)
        local s = Instance.new("UIStroke", row)
        s.Color = Color3.fromRGB(42, 50, 66)
        s.Thickness = 1

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.45, 0, 1, 0)
        lbl.Position = UDim2.new(0, 12, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 12
        lbl.TextColor3 = COL_TEXT_DIM
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Text = labelText
        lbl.Parent = row

        local box = Instance.new("TextBox")
        box.Size = UDim2.new(0.50, -10, 0, 24)
        box.Position = UDim2.new(0.50, 0, 0.5, -12)
        box.BackgroundColor3 = COL_INPUT
        box.Font = Enum.Font.GothamSemibold
        box.TextSize = 11
        box.TextColor3 = COL_TEXT_MAIN
        box.PlaceholderText = placeholder or ""
        box.ClearTextOnFocus = false
        box.Text = tostring(cfg[configKey])
        box.Parent = row
        Instance.new("UICorner", box).CornerRadius = UDim.new(0, 6)
        local bs = Instance.new("UIStroke", box)
        bs.Color = Color3.fromRGB(48, 65, 88)
        bs.Thickness = 1

        box.FocusLost:Connect(function()
            if isNumber then
                local num = tonumber(box.Text)
                if num then cfg[configKey] = num end
            else
                cfg[configKey] = box.Text
            end
            box.Text = tostring(cfg[configKey])
            SaveConfig(cfg)
        end)
    end

    -- TAB 1: MAIN FARM
    local tabMain = CreateTab("Main Farm")
    AddPillToggle(tabMain, "Master Auto-Farm", "Enabled")
    AddDropdownCycle(tabMain, "Farm Mode:", "Mode", {"SummerEvent", "MistyVillage", "Story", "InfinityCastle"})
    AddDropdownCycle(tabMain, "Lobby Move:", "LobbyMoveMethod", {"Hybrid", "Teleport", "Walk"})
    AddPillToggle(tabMain, "Party Join (All Modes)", "PartyJoinEnabled")
    AddPillToggle(tabMain, "Auto-Start & Skip Waves", "AutoStart")
    AddPillToggle(tabMain, "Auto-Replay Match", "AutoReplay")
    AddPillToggle(tabMain, "Captcha Auto-Solver", "CaptchaBypass")
    AddPillToggle(tabMain, "Summer: Vote Tsunami (2x)", "SummerVoteTsunami")
    AddPillToggle(tabMain, "Summer: +30% Pearl Cards", "AutoPickModifierCard")

    -- TAB 2: PLACEMENT & CONSOLIDATED MACRO STUDIO
    local tabPlace = CreateTab("Placement")
    local refreshPlacementMode = AddDropdownCycle(tabPlace, "Placement Mode:", "PlacementMode", {"Percentage", "Macro"})

    local macroCard = Instance.new("Frame")
    macroCard.Name = "MacroStudioCard"
    macroCard.Size = UDim2.new(1, -4, 0, 134)
    macroCard.BackgroundColor3 = COL_CARD
    macroCard.Parent = tabPlace
    Instance.new("UICorner", macroCard).CornerRadius = UDim.new(0, 10)
    local macroCardStroke = Instance.new("UIStroke", macroCard)
    macroCardStroke.Color = COL_VIOLET
    macroCardStroke.Thickness = 1.2
    macroCardStroke.Transparency = 0.25

    local macroHeader = Instance.new("TextLabel")
    macroHeader.Size = UDim2.new(0.52, 0, 0, 24)
    macroHeader.Position = UDim2.new(0, 12, 0, 6)
    macroHeader.BackgroundTransparency = 1
    macroHeader.Font = Enum.Font.GothamBold
    macroHeader.TextSize = 12
    macroHeader.TextColor3 = COL_CYAN
    macroHeader.TextXAlignment = Enum.TextXAlignment.Left
    macroHeader.Text = "MACRO STUDIO"
    macroHeader.Parent = macroCard

    local macroNameBox = Instance.new("TextBox")
    macroNameBox.Size = UDim2.new(0.44, -12, 0, 22)
    macroNameBox.Position = UDim2.new(0.56, 0, 0, 7)
    macroNameBox.BackgroundColor3 = COL_INPUT
    macroNameBox.Font = Enum.Font.GothamSemibold
    macroNameBox.TextSize = 11
    macroNameBox.TextColor3 = COL_TEXT_MAIN
    macroNameBox.PlaceholderText = "Macro Name..."
    macroNameBox.ClearTextOnFocus = false
    macroNameBox.Text = tostring(cfg.ActiveMacroName)
    macroNameBox.Parent = macroCard
    Instance.new("UICorner", macroNameBox).CornerRadius = UDim.new(0, 6)
    local mnStroke = Instance.new("UIStroke", macroNameBox)
    mnStroke.Color = Color3.fromRGB(48, 65, 88)
    mnStroke.Thickness = 1

    local macroStatusBox = Instance.new("TextLabel")
    macroStatusBox.Size = UDim2.new(1, -20, 0, 26)
    macroStatusBox.Position = UDim2.new(0, 10, 0, 34)
    macroStatusBox.BackgroundColor3 = COL_INPUT
    macroStatusBox.Font = Enum.Font.GothamSemibold
    macroStatusBox.TextSize = 11
    macroStatusBox.TextColor3 = COL_TEXT_DIM
    macroStatusBox.Parent = macroCard
    Instance.new("UICorner", macroStatusBox).CornerRadius = UDim.new(0, 6)
    local mStroke = Instance.new("UIStroke", macroStatusBox)
    mStroke.Color = Color3.fromRGB(42, 50, 66)
    mStroke.Thickness = 1
    MacroStatusLabelRef = macroStatusBox

    local function UpdateIdleMacroStatus()
        local steps, dur = LoadMacroFile(cfg.ActiveMacroName)
        if #steps > 0 then
            macroStatusBox.TextColor3 = COL_CYAN
            macroStatusBox.Text = string.format("Ready: '%s' (%d actions | %s)", cfg.ActiveMacroName, #steps, FormatTimer(dur))
        else
            macroStatusBox.TextColor3 = COL_TEXT_DIM
            macroStatusBox.Text = string.format("Empty: '%s' — Press Record to capture", cfg.ActiveMacroName)
        end
    end
    UpdateIdleMacroStatus()

    macroNameBox.FocusLost:Connect(function()
        local clean = macroNameBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
        if clean == "" then clean = "Default" end
        cfg.ActiveMacroName = clean
        macroNameBox.Text = clean
        SaveConfig(cfg)
        UpdateIdleMacroStatus()
    end)

    local gridContainer = Instance.new("Frame")
    gridContainer.Size = UDim2.new(1, -20, 0, 62)
    gridContainer.Position = UDim2.new(0, 10, 0, 65)
    gridContainer.BackgroundTransparency = 1
    gridContainer.Parent = macroCard

    local function MakeMacroBtn(text, bgColor, posX, posY, sizeX, sizeY)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(sizeX, -3, 0, sizeY)
        b.Position = UDim2.new(posX, posX > 0 and 3 or 0, 0, posY)
        b.BackgroundColor3 = bgColor
        b.Font = Enum.Font.GothamBold
        b.TextSize = 11
        b.TextColor3 = Color3.new(1, 1, 1)
        b.Text = text
        b.Parent = gridContainer
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
        return b
    end

    local btnStartUse = MakeMacroBtn("▶ Start / Use Macro", COL_CYAN,    0.00, 0,  0.50, 28)
    btnStartUse.TextColor3 = Color3.fromRGB(12, 16, 22)
    local btnRecord   = MakeMacroBtn("● Record",          COL_RED,     0.50, 0,  0.50, 28)
    local btnSave     = MakeMacroBtn("✔ Save Macro",      COL_EMERALD, 0.00, 33, 0.50, 28)
    local btnClear    = MakeMacroBtn("🗑 Clear Macro",     COL_VIOLET,  0.50, 33, 0.50, 28)

    btnStartUse.MouseButton1Click:Connect(function()
        local started, count = StartMacroPlaybackNow()
        refreshPlacementMode()
        if started then
            macroStatusBox.TextColor3 = COL_CYAN
            macroStatusBox.Text = string.format("▶ Playing '%s' (%d actions)...", cfg.ActiveMacroName, count)
        else
            macroStatusBox.TextColor3 = COL_AMBER
            macroStatusBox.Text = string.format("Mode set to Macro, but '%s' has 0 actions!", cfg.ActiveMacroName)
        end
    end)

    btnRecord.MouseButton1Click:Connect(function()
        StartMacroRecording()
        macroStatusBox.TextColor3 = COL_RED
        macroStatusBox.Text = "● RECORDING [00:00.0] — Place/Upgrade units now!"
    end)

    btnSave.MouseButton1Click:Connect(function()
        local count = MacroState.IsRecording and #MacroState.RecordedSteps or #LoadMacroFile(cfg.ActiveMacroName)
        local dur = MacroState.IsRecording and (os.clock() - MacroState.RecordStartTime) or 0
        if MacroState.IsRecording then
            StopMacroRecording()
        else
            SaveMacroFile(cfg.ActiveMacroName, LoadMacroFile(cfg.ActiveMacroName))
        end
        macroStatusBox.TextColor3 = COL_EMERALD
        macroStatusBox.Text = string.format("✔ Saved '%s' (%d actions | %s)", cfg.ActiveMacroName, count, FormatTimer(dur))
    end)

    btnClear.MouseButton1Click:Connect(function()
        MacroState.IsRecording = false
        MacroState.RecordedSteps = {}
        ResetMacroPlayback()
        SaveMacroFile(cfg.ActiveMacroName, {})
        macroStatusBox.TextColor3 = COL_TEXT_DIM
        macroStatusBox.Text = "🗑 Cleared macro: " .. cfg.ActiveMacroName
    end)

    AddPillToggle(tabPlace, "Auto-Place (Ground & Hill)", "AutoPlace")
    AddPillToggle(tabPlace, "Upd 21.5 Native Auto-Upgrade", "UseNativeAutoUpgrade")
    AddStyledInput(tabPlace, "Lane % (0.00 - 1.00):", "LanePercent", true)
    AddStyledInput(tabPlace, "Slot Spread %:", "SlotPercentSpread", true)
    AddStyledInput(tabPlace, "Road Side Offset:", "RoadSideOffset", true)

    -- TAB 3: BANNER, REWARDS & WEBHOOK
    local tabBanner = CreateTab("Banner / Hook")
    AddPillToggle(tabBanner, "Auto-Check & Summon", "BannerCheckEnabled")
    AddStyledInput(tabBanner, "Target Unit Name:", "TargetBannerUnit", false)
    AddDropdownCycle(tabBanner, "Rarity Filter:", "TargetBannerRarity", {"Any", "Legendary", "Mythic", "Secret"})
    AddDropdownCycle(tabBanner, "Banner Type:", "TargetBannerType", {"Standard", "MistyVillage", "Summer"})
    AddPillToggle(tabBanner, "10x Multi Summon", "SummonMulti")
    AddPillToggle(tabBanner, "Reset Acquired Flag", "BannerTargetAcquired")
    AddPillToggle(tabBanner, "Webhook on Match End", "SendMatchWebhookOnEnd")
    AddPillToggle(tabBanner, "Ping Only on Portal Drop", "PingOnlyOnPortalDrop")
    AddStyledInput(tabBanner, "Discord User ID (Ping):", "DiscordUserId", false)
    AddStyledInput(tabBanner, "Discord Webhook URL:", "WebhookUrl", false)

    local statusBox = Instance.new("TextLabel")
    statusBox.Size = UDim2.new(1, -4, 0, 56)
    statusBox.BackgroundColor3 = COL_INPUT
    statusBox.Font = Enum.Font.Gotham
    statusBox.TextSize = 11
    statusBox.TextColor3 = COL_CYAN
    statusBox.TextWrapped = true
    statusBox.Text = "Click 'Check Banner', 'Last Earnings', or 'Test Webhook'."
    statusBox.Parent = tabBanner
    Instance.new("UICorner", statusBox).CornerRadius = UDim.new(0, 6)

    local btnRow = Instance.new("Frame")
    btnRow.Size = UDim2.new(1, -4, 0, 28)
    btnRow.BackgroundTransparency = 1
    btnRow.Parent = tabBanner

    local checkBtn = Instance.new("TextButton")
    checkBtn.Size = UDim2.new(0.32, 0, 1, 0)
    checkBtn.BackgroundColor3 = COL_VIOLET
    checkBtn.Font = Enum.Font.GothamBold
    checkBtn.TextSize = 10
    checkBtn.TextColor3 = Color3.new(1, 1, 1)
    checkBtn.Text = "Check Banner"
    checkBtn.Parent = btnRow
    Instance.new("UICorner", checkBtn).CornerRadius = UDim.new(0, 6)

    local earnBtn = Instance.new("TextButton")
    earnBtn.Size = UDim2.new(0.32, 0, 1, 0)
    earnBtn.Position = UDim2.new(0.34, 0, 0, 0)
    earnBtn.BackgroundColor3 = Color3.fromRGB(14, 165, 233)
    earnBtn.Font = Enum.Font.GothamBold
    earnBtn.TextSize = 10
    earnBtn.TextColor3 = Color3.new(1, 1, 1)
    earnBtn.Text = "Last Earnings"
    earnBtn.Parent = btnRow
    Instance.new("UICorner", earnBtn).CornerRadius = UDim.new(0, 6)

    local hookBtn = Instance.new("TextButton")
    hookBtn.Size = UDim2.new(0.32, 0, 1, 0)
    hookBtn.Position = UDim2.new(0.68, 0, 0, 0)
    hookBtn.BackgroundColor3 = COL_EMERALD
    hookBtn.Font = Enum.Font.GothamBold
    hookBtn.TextSize = 10
    hookBtn.TextColor3 = Color3.new(1, 1, 1)
    hookBtn.Text = "Test Webhook"
    hookBtn.Parent = btnRow
    Instance.new("UICorner", hookBtn).CornerRadius = UDim.new(0, 6)

    checkBtn.MouseButton1Click:Connect(function()
        local units = GetCurrentBannerUnits()
        if #units == 0 then
            statusBox.Text = "No banner data cached yet (open Summon UI once in lobby)."
        else
            local names = {}
            for _, u in ipairs(units) do table.insert(names, u.name .. " [" .. u.rarity .. "]") end
            statusBox.Text = "Live: " .. table.concat(names, ", ")
        end
    end)

    earnBtn.MouseButton1Click:Connect(function()
        statusBox.Text = MatchTracker.LastSummaryText
    end)

    hookBtn.MouseButton1Click:Connect(function()
        local okMatch = SendMatchEndWebhook(true)
        local okBanner = SendBannerWebhook(true)
        statusBox.Text = (okMatch or okBanner) and "Test webhooks sent to Discord!" or "Failed: paste WebhookUrl above first."
    end)

    -- TAB 4: STORY / PARTY
    local tabStory = CreateTab("Story / Party")
    AddPillToggle(tabStory, "Party Join (Works All Modes)", "PartyJoinEnabled")
    AddPillToggle(tabStory, "Fallback to Solo Pod on Timeout", "AutoCreatePartyFallback")
    AddStyledInput(tabStory, "Party Search Timeout (s):", "PartySearchTimeout", true)
    AddStyledInput(tabStory, "Party Filter (Blank=Auto):", "TargetPartyName", false, "Auto-matches Mode")
    AddStyledInput(tabStory, "Story World ID:", "StoryWorld", false)
    AddStyledInput(tabStory, "Story Act (1-6 / inf):", "StoryAct", false)
    AddDropdownCycle(tabStory, "Difficulty:", "StoryDifficulty", {"Normal", "Hard"})
    AddStyledInput(tabStory, "Story Lobby Pod:", "StoryPod", false)

    pages[1].Visible = true
    tabButtons[1].btn.TextColor3 = COL_CYAN
    tabButtons[1].stroke.Color = COL_CYAN
    tabButtons[1].stroke.Thickness = 1.8
    tabButtons[1].stroke.Transparency = 0
end

CreateStyledControlGui()

-- 11. MODULE: CAPTCHA SOLVER (DEEP MODAL SCAN, ZINDEX SPLIT-CHAR, MATH, IMAGE ASSET & MULTI-REMOTE)
local LastCaptchaAttempt = 0
local CaptchaAttemptCount = 0

local function StripRichText(str)
    return tostring(str or ""):gsub("<[^>]+>", ""):gsub("&nbsp;", " "):gsub("^%s+", ""):gsub("%s+$", "")
end

local function IsGuiVisibleInTree(inst)
    local curr = inst
    while curr and curr ~= game do
        if curr:IsA("ScreenGui") and not curr.Enabled then return false end
        if curr:IsA("SurfaceGui") and not curr.Enabled then return false end
        if curr:IsA("BillboardGui") and not curr.Enabled then return false end
        if curr:IsA("GuiObject") and not curr.Visible then return false end
        curr = curr.Parent
    end
    return true
end

local CAPTCHA_KEYWORDS = {
    "captcha", "verify", "verification", "security", "human",
    "bot", "antibot", "anti_bot", "afk", "check", "robot", "prove",
    "challenge", "answer", "code"
}

local function ContainsCaptchaKeyword(str)
    local lower = tostring(str or ""):lower()
    for _, kw in ipairs(CAPTCHA_KEYWORDS) do
        if lower:find(kw, 1, true) then
            return true
        end
    end
    return false
end

local function FindActiveCaptchaContainer()
    local roots = { PlayerGui, CoreGui }
    local bestContainer = nil
    local bestScore = 0

    for _, root in ipairs(roots) do
        if root then
            for _, gui in ipairs(root:GetChildren()) do
                if gui:IsA("ScreenGui") and gui.Enabled and gui.Name ~= "AAModernHubUI" then
                    local score = 0
                    if ContainsCaptchaKeyword(gui.Name) then
                        score = score + 50
                    end

                    local hasVisibleBox = false
                    local hasCaptchaText = false
                    local hasConfirm = false
                    local candidateSubFrame = nil

                    for _, desc in ipairs(gui:GetDescendants()) do
                        if IsGuiVisibleInTree(desc) then
                            if desc:IsA("TextBox") then
                                hasVisibleBox = true
                                score = score + 25
                                if not candidateSubFrame then
                                    candidateSubFrame = desc.Parent
                                end
                            elseif desc:IsA("TextLabel") or desc:IsA("TextButton") then
                                local txt = StripRichText(desc.Text)
                                local combined = (desc.Name .. " " .. txt):lower()
                                if combined:find("captcha") or combined:find("anti%-bot") or combined:find("antibot") or combined:find("are you a robot") or combined:find("human verification") or combined:find("afk check") then
                                    hasCaptchaText = true
                                    score = score + 60
                                    if desc.Parent and desc.Parent:IsA("GuiObject") then
                                        candidateSubFrame = desc.Parent
                                    end
                                elseif ContainsCaptchaKeyword(desc.Name) or ContainsCaptchaKeyword(txt) then
                                    hasCaptchaText = true
                                    score = score + 20
                                end

                                if desc:IsA("GuiButton") then
                                    if combined:find("submit") or combined:find("verify") or combined:find("confirm") or combined:find("enter") or combined:find("ok") or combined:find("done") then
                                        hasConfirm = true
                                        score = score + 20
                                    end
                                end
                            end
                        end
                    end

                    if score >= 50 or (hasVisibleBox and (hasConfirm or hasCaptchaText)) or (hasCaptchaText and hasConfirm) then
                        if score > bestScore then
                            bestScore = score
                            if candidateSubFrame and candidateSubFrame.Parent and candidateSubFrame.Parent:IsA("Frame") then
                                bestContainer = candidateSubFrame.Parent
                            else
                                bestContainer = gui
                            end
                        end
                    end
                end
            end
        end
    end

    return bestContainer
end

local function EvaluateSimpleMath(text)
    local norm = text:gsub("×", "*"):gsub("÷", "/"):gsub("−", "-")
    local a, op, b = norm:match("(%d+)%s*([%+%-xX%*/])%s*(%d+)")
    if not a or not b then return nil end
    local n1, n2 = tonumber(a), tonumber(b)
    if not n1 or not n2 then return nil end

    if op == "+" then return tostring(n1 + n2)
    elseif op == "-" then return tostring(n1 - n2)
    elseif op == "*" or op == "x" or op == "X" then return tostring(n1 * n2)
    elseif op == "/" and n2 ~= 0 then return tostring(math.floor(n1 / n2))
    end
    return nil
end

local function ExtractSplitCharacterCode(container)
    local charLabels = {}
    for _, obj in ipairs(container:GetDescendants()) do
        if obj:IsA("TextLabel") and IsGuiVisibleInTree(obj) then
            local clean = StripRichText(obj.Text):gsub("%s+", "")
            if #clean == 1 and clean:match("^[A-Za-z0-9]$")
               and obj.AbsoluteSize.X >= 8 and obj.AbsoluteSize.Y >= 8
               and obj.TextTransparency < 0.85 then
                table.insert(charLabels, {
                    char = clean,
                    x = obj.AbsolutePosition.X,
                    y = obj.AbsolutePosition.Y,
                    z = obj.ZIndex
                })
            end
        end
    end

    if #charLabels < 3 or #charLabels > 10 then return nil end

    table.sort(charLabels, function(a, b)
        if math.abs(a.x - b.x) <= 4 and math.abs(a.y - b.y) <= 4 then
            return a.z > b.z
        end
        if math.abs(a.y - b.y) > 22 then
            return a.y < b.y
        end
        return a.x < b.x
    end)

    local deduped = {}
    for _, item in ipairs(charLabels) do
        local prev = deduped[#deduped]
        if not prev or math.abs(item.x - prev.x) > 5 or math.abs(item.y - prev.y) > 5 then
            table.insert(deduped, item)
        end
    end

    if #deduped < 3 or #deduped > 8 then return nil end

    local built = {}
    for _, item in ipairs(deduped) do
        table.insert(built, item.char)
    end
    return table.concat(built)
end

local function FireAllCaptchaRemotes(answer)
    local patterns = {
        "submit_captcha", "verify_captcha", "captcha",
        "afk_verify", "anti_afk", "verification", "verify", "challenge"
    }
    local remotes = FindAllMatchingRemotes(patterns)
    local numAns = tonumber(answer)

    for _, remote in ipairs(remotes) do
        pcall(function()
            if remote:IsA("RemoteEvent") then
                remote:FireServer(answer)
                if numAns then remote:FireServer(numAns) end
            elseif remote:IsA("RemoteFunction") then
                remote:InvokeServer(answer)
            end
        end)
    end
end

local function SubmitTextBoxEntry(inputBox, answerStr, submitBtn)
    if not inputBox then return end
    pcall(function()
        inputBox:CaptureFocus()
        task.wait(0.06)
        inputBox.Text = answerStr
        if firesignal then
            pcall(function() firesignal(inputBox:GetPropertyChangedSignal("Text")) end)
        end
        task.wait(0.08)
        inputBox:ReleaseFocus(true)
    end)

    if VirtualInputManager then
        pcall(function()
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
            task.wait(0.03)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
        end)
    end

    task.wait(0.12)
    if submitBtn then
        ClickGuiButton(submitBtn)
    end
end

local function SolveCaptcha()
    if not getgenv().AAConfig.CaptchaBypass then return false end
    if (os.clock() - LastCaptchaAttempt) < 1.0 then return false end

    local captchaContainer = FindActiveCaptchaContainer()
    if not captchaContainer then
        CaptchaAttemptCount = 0
        return false
    end

    LastCaptchaAttempt = os.clock()
    CaptchaAttemptCount = CaptchaAttemptCount + 1

    local codeText = nil
    local mathAnswer = nil
    local inputBox = nil
    local submitBtn = nil
    local promptText = ""
    local clickableChoices = {}

    for _, obj in ipairs(captchaContainer:GetDescendants()) do
        if IsGuiVisibleInTree(obj) then
            if obj:IsA("TextLabel") and obj.TextTransparency < 0.85 then
                local raw = StripRichText(obj.Text)
                local lower = raw:lower()
                local compact = raw:gsub("%s+", "")

                if lower:find("select") or lower:find("click") or lower:find("choose") or lower:find("pick") or lower:find("tap") or lower:find("find") or lower:find("press") then
                    promptText = lower
                end

                local mAns = EvaluateSimpleMath(raw)
                if mAns then
                    mathAnswer = mAns
                end

                local extractedCode = raw:match("[Cc]ode%s*[:%-=]%s*([A-Za-z0-9]+)")
                    or raw:match("[Tt]ype%s+['\"]?([A-Za-z0-9]+)['\"]?")
                    or raw:match("[Ee]nter%s+['\"]?([A-Za-z0-9]+)['\"]?")
                    or raw:match("[Ii]nput%s+['\"]?([A-Za-z0-9]+)['\"]?")
                if extractedCode and #extractedCode >= 3 then
                    codeText = extractedCode
                elseif compact:match("^%d%d%d%d+$") then
                    codeText = compact
                elseif not codeText and #compact >= 4 and #compact <= 8 and compact:match("^[A-Za-z0-9]+$") then
                    if not ContainsCaptchaKeyword(lower) and lower ~= "submit" and lower ~= "confirm" and lower ~= "enter" and lower ~= "verify" then
                        codeText = compact
                    end
                end

            elseif obj:IsA("TextBox") then
                inputBox = obj

            elseif obj:IsA("GuiButton") then
                local btnTxt = obj:IsA("TextButton") and StripRichText(obj.Text) or ""
                local combined = (obj.Name .. " " .. btnTxt):lower()
                if combined:find("submit") or combined:find("verify") or combined:find("confirm") or combined:find("done") or combined:find("check") or combined:find("ok") then
                    submitBtn = obj
                else
                    table.insert(clickableChoices, obj)
                end
            end
        end
    end

    if not codeText and not mathAnswer then
        codeText = ExtractSplitCharacterCode(captchaContainer)
    end

    local finalAnswer = mathAnswer or codeText

    if finalAnswer and inputBox then
        SubmitTextBoxEntry(inputBox, tostring(finalAnswer), submitBtn)
        FireAllCaptchaRemotes(finalAnswer)
        return true
    end

    if finalAnswer and #clickableChoices > 0 then
        local targetLower = tostring(finalAnswer):lower()
        for _, btn in ipairs(clickableChoices) do
            local btnTxt = btn:IsA("TextButton") and StripRichText(btn.Text):lower() or ""
            local childLbl = btn:FindFirstChildWhichIsA("TextLabel", true)
            local childTxt = childLbl and StripRichText(childLbl.Text):lower() or ""
            if btnTxt == targetLower or childTxt == targetLower or btn.Name:lower() == targetLower then
                ClickGuiButton(btn)
                task.wait(0.15)
                if submitBtn then ClickGuiButton(submitBtn) end
                FireAllCaptchaRemotes(finalAnswer)
                return true
            end
        end
    end

    if promptText ~= "" and #clickableChoices > 0 then
        local clickedAny = false
        for _, btn in ipairs(clickableChoices) do
            local childImg = btn:IsA("ImageButton") and btn.Image or ""
            if childImg == "" then
                local subImg = btn:FindFirstChildWhichIsA("ImageLabel", true)
                if subImg then childImg = subImg.Image end
            end

            local childLbl = btn:FindFirstChildWhichIsA("TextLabel", true)
            local childTxt = childLbl and StripRichText(childLbl.Text) or ""

            local meta = table.concat({
                tostring(btn:GetAttribute("Category") or ""),
                tostring(btn:GetAttribute("Type") or ""),
                tostring(btn:GetAttribute("Item") or ""),
                tostring(btn:GetAttribute("Id") or ""),
                tostring(btn:GetAttribute("Answer") or ""),
                btn.Name,
                btn:IsA("TextButton") and StripRichText(btn.Text) or "",
                childTxt,
                tostring(childImg)
            }, " "):lower()

            for word in promptText:gmatch("%a+") do
                if #word >= 3 and word ~= "select" and word ~= "click" and word ~= "all" and word ~= "the" and word ~= "with" and word ~= "images" and word ~= "that" and word ~= "are" then
                    if meta:find(word, 1, true) then
                        ClickGuiButton(btn)
                        clickedAny = true
                        task.wait(0.18)
                        break
                    end
                end
            end
        end

        if clickedAny then
            if submitBtn then
                task.wait(0.2)
                ClickGuiButton(submitBtn)
            end
            return true
        end
    end

    if CaptchaAttemptCount >= 3 and #clickableChoices > 0 then
        local pick = clickableChoices[((CaptchaAttemptCount - 1) % #clickableChoices) + 1]
        ClickGuiButton(pick)
        if submitBtn then
            task.wait(0.15)
            ClickGuiButton(submitBtn)
        end
        return true
    end

    return false
end

-- 12. MODULE: AUTO-SUMMON & CURRENCY CHECK
local function HasEnoughCurrencyForRoll()
    local cfg = getgenv().AAConfig
    local stats = LocalPlayer:FindFirstChild("_stats") or LocalPlayer:FindFirstChild("Stats")
    if not stats then return false end

    if cfg.TargetBannerType == "MistyVillage" then
        local dawnCoins = stats:FindFirstChild("dawn_coins") or stats:FindFirstChild("DawnCoins")
        local cost = cfg.SummonMulti and 500 or 50
        return dawnCoins and dawnCoins.Value >= cost
    else
        local gems = stats:FindFirstChild("gems") or stats:FindFirstChild("Gems")
        local cost = cfg.SummonMulti and 1500 or 150
        return gems and gems.Value >= cost
    end
end

local function RunBannerRoutine()
    local cfg = getgenv().AAConfig
    SendBannerWebhook(false)

    if not IsTargetUnitOnBanner() then return false end
    if not HasEnoughCurrencyForRoll() then return false end

    local lobbyFolder = workspace:FindFirstChild("_lobby") or workspace:FindFirstChild("Lobby")
    local summonZone = lobbyFolder and lobbyFolder:FindFirstChild("summon", true)
    if summonZone and summonZone:IsA("BasePart") and LocalPlayer.Character and LocalPlayer.Character.PrimaryPart then
        local dist = (LocalPlayer.Character.PrimaryPart.Position - summonZone.Position).Magnitude
        if dist > 15 then
            LocalPlayer.Character:PivotTo(summonZone.CFrame + Vector3.new(0, 3, 0))
            task.wait(0.5)
        end
    end

    local rollType = cfg.SummonMulti and "multi" or "single"
    FireEndpoint({"request_summon", "summon"}, cfg.TargetBannerType, rollType)
    task.wait(1.5)

    if HasTargetUnitInInventory(cfg.TargetBannerUnit, cfg.TargetBannerRarity) then
        cfg.BannerTargetAcquired = true
        SaveConfig(cfg)
        return false
    end

    return true
end

-- 13. MODULE: LOBBY & MATCHMAKING (FULL WORKSPACE POD DISCOVERY + PATHFIND/TOUCH + QUEUE)
local LobbySearchStartTime = 0
local LastPodMoveTime = 0
local IsWalkingToPod = false

local function GetPartFromInstance(inst)
    if not inst then return nil end
    if inst:IsA("BasePart") then return inst end
    if inst:IsA("Model") then
        return inst.PrimaryPart
            or inst:FindFirstChild("Door")
            or inst:FindFirstChild("Pad")
            or inst:FindFirstChild("Trigger")
            or inst:FindFirstChild("TouchPart")
            or inst:FindFirstChildWhichIsA("BasePart", true)
    end
    return nil
end

local function FindBestLobbyPod(keywords, preferredPodName)
    local searchRoots = {}
    local lobbyFolder = workspace:FindFirstChild("_lobby") or workspace:FindFirstChild("Lobby")
    if lobbyFolder then table.insert(searchRoots, lobbyFolder) end
    table.insert(searchRoots, workspace)

    local kwList = type(keywords) == "table" and keywords or { tostring(keywords) }
    local lowerKws = {}
    for _, k in ipairs(kwList) do
        local clean = tostring(k):lower()
        if clean ~= "" then table.insert(lowerKws, clean) end
    end

    -- 1. Exact pod name match first (e.g., Story_Pod_1, SummerEvent_Pod_1)
    if preferredPodName and preferredPodName ~= "" then
        local exactNeedle = preferredPodName:lower()
        for _, root in ipairs(searchRoots) do
            for _, obj in ipairs(root:GetDescendants()) do
                if obj.Name:lower() == exactNeedle or obj.Name:lower():find(exactNeedle, 1, true) then
                    local part = GetPartFromInstance(obj)
                    if part and part.Position.Y > -200 then
                        return part, obj
                    end
                end
            end
        end
    end

    -- 2. Score-based scan across pod models, pads, doors, and BillboardGui/SurfaceGui labels
    local bestPart = nil
    local bestOwner = nil
    local bestScore = -1

    local function ScoreCandidate(part, ownerObj, textBlob)
        local lower = textBlob:lower()
        local matchedKw = false
        local score = 0

        for _, kw in ipairs(lowerKws) do
            if lower:find(kw, 1, true) then
                matchedKw = true
                score = score + 50
            end
        end
        if not matchedKw then return end

        if lower:find("pod") or lower:find("pad") or lower:find("portal") or lower:find("door") or lower:find("elevator") or lower:find("teleporter") or lower:find("zone") or lower:find("queue") then
            score = score + 30
        end
        if ownerObj:FindFirstChildWhichIsA("TouchTransmitter", true) or part:FindFirstChildWhichIsA("TouchTransmitter", true) then
            score = score + 40
        end
        if lower:find("inprogress") or lower:find("full") or lower:find("locked") then
            score = score - 40
        end
        -- Prefer empty/open pods (often numbered _1 or without active player occupant)
        if lower:find("_1") or lower:find("pod1") then
            score = score + 10
        end

        if score > bestScore then
            bestScore = score
            bestPart = part
            bestOwner = ownerObj
        end
    end

    for _, root in ipairs(searchRoots) do
        for _, obj in ipairs(root:GetDescendants()) do
            if obj:IsA("Model") or obj:IsA("BasePart") then
                local part = GetPartFromInstance(obj)
                if part and part.Position.Y > -200 then
                    local blob = obj.Name .. " " .. (obj.Parent and obj.Parent.Name or "")
                    ScoreCandidate(part, obj, blob)
                end
            elseif obj:IsA("TextLabel") and obj.Text ~= "" then
                local guiParent = obj:FindFirstAncestorWhichIsA("BillboardGui") or obj:FindFirstAncestorWhichIsA("SurfaceGui")
                local adornee = guiParent and (guiParent.Adornee or guiParent.Parent)
                local part = GetPartFromInstance(adornee)
                if part and part.Position.Y > -200 then
                    ScoreCandidate(part, adornee, StripRichText(obj.Text) .. " " .. adornee.Name)
                end
            end
        end
        if bestPart then break end
    end

    return bestPart, bestOwner
end

local function TriggerPodTouch(targetPart, targetOwner)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp or not targetPart then return end

    if firetouchinterest then
        local touchParts = { targetPart }
        if targetOwner then
            for _, d in ipairs(targetOwner:GetDescendants()) do
                if d:IsA("BasePart") and d ~= targetPart then
                    table.insert(touchParts, d)
                end
            end
        end
        for _, p in ipairs(touchParts) do
            pcall(function()
                firetouchinterest(hrp, p, 0)
                task.wait(0.05)
                firetouchinterest(hrp, p, 1)
            end)
        end
    end
end

local function WalkToPosition(targetPos)
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return false end

    IsWalkingToPod = true
    local path = PathfindingService:CreatePath({
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = true,
        WaypointSpacing = 4
    })

    local ok = pcall(function()
        path:ComputeAsync(hrp.Position, targetPos)
    end)

    if ok and path.Status == Enum.PathStatus.Success then
        for _, wp in ipairs(path:GetWaypoints()) do
            if not IsInLobby() or not getgenv().AAConfig.Enabled then break end
            if wp.Action == Enum.PathWaypointAction.Jump then
                hum.Jump = true
            end
            hum:MoveTo(wp.Position)
            local reached = hum.MoveToFinished:Wait()
            if not reached then break end
        end
    else
        hum:MoveTo(targetPos)
        hum.MoveToFinished:Wait()
    end

    IsWalkingToPod = false
    return (hrp.Position - targetPos).Magnitude <= 10
end

local function MoveToLobbyPod(keywords, preferredPodName)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    local targetPart, targetOwner = FindBestLobbyPod(keywords, preferredPodName)
    if not targetPart then return false end

    local dist = (hrp.Position - targetPart.Position).Magnitude
    if dist <= 6 then
        TriggerPodTouch(targetPart, targetOwner)
        return true
    end

    if (os.clock() - LastPodMoveTime) < 1.2 or IsWalkingToPod then
        return false
    end
    LastPodMoveTime = os.clock()

    local method = getgenv().AAConfig.LobbyMoveMethod or "Hybrid"
    local destPos = targetPart.Position + Vector3.new(0, 3, 0)

    if method == "Teleport" then
        char:PivotTo(CFrame.new(destPos))
        task.wait(0.15)
        TriggerPodTouch(targetPart, targetOwner)
        return true
    elseif method == "Walk" then
        task.spawn(function()
            if WalkToPosition(destPos) then
                TriggerPodTouch(targetPart, targetOwner)
            end
        end)
        return true
    else
        -- Hybrid: pathfind/walk if close (< 45 studs), otherwise pivot + fire touch
        if dist < 45 then
            task.spawn(function()
                if WalkToPosition(destPos) then
                    TriggerPodTouch(targetPart, targetOwner)
                else
                    char:PivotTo(CFrame.new(destPos))
                    TriggerPodTouch(targetPart, targetOwner)
                end
            end)
        else
            char:PivotTo(CFrame.new(destPos))
            task.wait(0.15)
            TriggerPodTouch(targetPart, targetOwner)
        end
        return true
    end
end

local function GetModeKeywordsForParty()
    local cfg = getgenv().AAConfig
    local custom = tostring(cfg.TargetPartyName or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if custom ~= "" then
        return { custom:lower() }
    end

    local mode = cfg.Mode
    if mode == "SummerEvent" then
        return { "summer", "pearl", "event" }
    elseif mode == "MistyVillage" then
        return { "misty", "village", "dawn" }
    elseif mode == "Story" then
        return { tostring(cfg.StoryWorld or "story"):lower(), "story" }
    elseif mode == "InfinityCastle" then
        return { "infinity", "castle", "inf" }
    end
    return { mode:lower() }
end

local function FindPartyFinderGui()
    if not PlayerGui then return nil end
    local names = { "PartyFinder", "PartyUI", "Parties", "LobbyParty", "PartyList" }
    for _, n in ipairs(names) do
        local found = PlayerGui:FindFirstChild(n, true)
        if found then return found end
    end
    return nil
end

local function TryJoinModeParty()
    local cfg = getgenv().AAConfig
    if not cfg.PartyJoinEnabled then return false end

    local partyGui = FindPartyFinderGui()
    if not partyGui then
        local openBtn = PlayerGui and (PlayerGui:FindFirstChild("PartyButton", true) or PlayerGui:FindFirstChild("PartiesButton", true))
        if openBtn and openBtn:IsA("GuiButton") then
            ClickGuiButton(openBtn)
        end
        FireEndpoint({"request_parties", "get_parties", "open_party_finder"})
        return false
    end

    if partyGui:IsA("ScreenGui") and not partyGui.Enabled then
        partyGui.Enabled = true
    elseif partyGui:IsA("GuiObject") and not partyGui.Visible then
        partyGui.Visible = true
    end

    local keywords = GetModeKeywordsForParty()

    for _, desc in ipairs(partyGui:GetDescendants()) do
        if desc:IsA("TextLabel") and desc.Visible and desc.Text ~= "" then
            local rowText = StripRichText(desc.Text):lower()
            local matched = false
            for _, kw in ipairs(keywords) do
                if rowText:find(kw, 1, true) then
                    matched = true
                    break
                end
            end

            if matched then
                local container = desc.Parent
                for _ = 1, 3 do
                    if not container then break end
                    local joinBtn = container:FindFirstChild("JoinButton", true) or container:FindFirstChild("Join", true)
                    if not joinBtn then
                        for _, child in ipairs(container:GetDescendants()) do
                            if child:IsA("GuiButton") and child.Visible then
                                local bTxt = (child.Name .. " " .. (child:IsA("TextButton") and StripRichText(child.Text) or "")):lower()
                                if bTxt:find("join") or bTxt:find("enter") then
                                    joinBtn = child
                                    break
                                end
                            end
                        end
                    end

                    if joinBtn and joinBtn:IsA("GuiButton") then
                        ClickGuiButton(joinBtn)
                        local partyId = container:GetAttribute("PartyId") or container:GetAttribute("Id") or container.Name
                        FireEndpoint({"join_party", "request_join_party"}, partyId)
                        return true
                    end
                    container = container.Parent
                end
            end
        end
    end

    return false
end

local function ConfirmLobbySelectionGui(keywords)
    if not PlayerGui then return end
    local kwList = type(keywords) == "table" and keywords or { tostring(keywords) }

    for _, gui in ipairs(PlayerGui:GetChildren()) do
        if gui:IsA("ScreenGui") and gui.Enabled and gui.Name ~= "AAModernHubUI" then
            for _, desc in ipairs(gui:GetDescendants()) do
                if desc:IsA("GuiButton") and IsGuiVisibleInTree(desc) then
                    local txt = (desc.Name .. " " .. (desc:IsA("TextButton") and StripRichText(desc.Text) or "")):lower()
                    for _, kw in ipairs(kwList) do
                        if kw ~= "" and txt:find(kw:lower(), 1, true) then
                            ClickGuiButton(desc)
                            task.wait(0.1)
                            break
                        end
                    end
                    if txt == "start" or txt == "confirm" or txt == "create" or txt == "enter" or txt == "play" or txt == "select" then
                        ClickGuiButton(desc)
                    end
                end
            end
        end
    end
end

local function QueueSoloModePod()
    local cfg = getgenv().AAConfig
    local mode = cfg.Mode

    if mode == "Story" then
        local levelId = string.format("%s_level_%s", cfg.StoryWorld, cfg.StoryAct)
        local _, podObj = FindBestLobbyPod({"story", tostring(cfg.StoryWorld)}, cfg.StoryPod)
        local podName = podObj and podObj.Name or cfg.StoryPod

        MoveToLobbyPod({"story", tostring(cfg.StoryWorld)}, podName)
        task.wait(0.35)
        FireEndpoint({"request_join_lobby", "join_lobby"}, podName)
        task.wait(0.35)
        ConfirmLobbySelectionGui({cfg.StoryWorld, "act " .. tostring(cfg.StoryAct), cfg.StoryDifficulty})
        FireEndpoint({"request_match_making", "match_making"}, podName, levelId, true, cfg.StoryDifficulty)
        task.wait(0.35)
        FireEndpoint({"request_start_game", "start_game"}, podName)

    elseif mode == "SummerEvent" then
        local _, podObj = FindBestLobbyPod({"summer", "event", "pearl"}, "SummerEvent_Pod_1")
        local podName = podObj and podObj.Name or "SummerEvent_Pod_1"

        MoveToLobbyPod({"summer", "event", "pearl"}, podName)
        task.wait(0.35)
        FireEndpoint({"request_join_lobby", "join_lobby"}, podName)
        task.wait(0.35)
        ConfirmLobbySelectionGui({"summer", "event"})
        FireEndpoint({"request_start_game", "start_game"}, podName)

    elseif mode == "MistyVillage" then
        local _, podObj = FindBestLobbyPod({"misty", "village", "dawn"}, "MistyVillage_Pod_1")
        local podName = podObj and podObj.Name or "MistyVillage_Pod_1"

        MoveToLobbyPod({"misty", "village", "dawn"}, podName)
        task.wait(0.35)
        FireEndpoint({"request_join_lobby", "join_lobby"}, podName)
        task.wait(0.35)
        ConfirmLobbySelectionGui({"misty", "village"})
        FireEndpoint({"request_start_game", "start_game"}, podName)

    elseif mode == "InfinityCastle" then
        local _, podObj = FindBestLobbyPod({"infinity", "castle"}, "InfinityCastle_Pod_1")
        local podName = podObj and podObj.Name or "InfinityCastle_Pod_1"

        MoveToLobbyPod({"infinity", "castle"}, podName)
        task.wait(0.35)
        ConfirmLobbySelectionGui({"infinity", "castle"})
        FireEndpoint({"request_start_infinity_castle", "infinity_castle"}, podName)
    end
end

local function RunLobbyRoutine()
    if SolveCaptcha() then return end
    if RunBannerRoutine() then return end

    local cfg = getgenv().AAConfig

    if cfg.PartyJoinEnabled then
        if LobbySearchStartTime == 0 then
            LobbySearchStartTime = os.clock()
        end

        if TryJoinModeParty() then
            return
        end

        if cfg.AutoCreatePartyFallback and (os.clock() - LobbySearchStartTime) >= (cfg.PartySearchTimeout or 8) then
            QueueSoloModePod()
        end
    else
        LobbySearchStartTime = 0
        QueueSoloModePod()
    end
end

-- 14. MODULE: DYNAMIC PERCENTAGE PATH CALCULATOR (0% TO 100%)
local function GetOrderedWaypoints()
    local map = workspace:FindFirstChild("_map") or workspace:FindFirstChild("Map")
    local wpFolder = map and (map:FindFirstChild("waypoints") or map:FindFirstChild("Waypoints") or map:FindFirstChild("Path"))
    if not wpFolder then return {} end

    local ordered = {}
    local idx = 1
    while true do
        local node = wpFolder:FindFirstChild(tostring(idx))
        if node and node:IsA("BasePart") then
            table.insert(ordered, node.Position)
            idx = idx + 1
        else
            break
        end
    end

    if #ordered == 0 then
        local children = wpFolder:GetChildren()
        table.sort(children, function(a, b)
            local na, nb = tonumber(a.Name), tonumber(b.Name)
            if na and nb then return na < nb end
            return a.Name < b.Name
        end)
        for _, child in ipairs(children) do
            if child:IsA("BasePart") then
                table.insert(ordered, child.Position)
            end
        end
    end

    return ordered
end

local function GetPointAtLanePercentage(percent)
    local points = GetOrderedWaypoints()
    if #points == 0 then
        return Vector3.new(0, 5, 0), Vector3.new(1, 0, 0)
    elseif #points == 1 then
        return points[1], Vector3.new(1, 0, 0)
    end

    percent = math.clamp(percent, 0, 1)

    local segments = {}
    local totalLength = 0
    for i = 1, #points - 1 do
        local segVec = points[i + 1] - points[i]
        local segLen = segVec.Magnitude
        table.insert(segments, {
            startPos = points[i],
            endPos = points[i + 1],
            length = segLen,
            dir = segLen > 0 and segVec.Unit or Vector3.new(1, 0, 0)
        })
        totalLength = totalLength + segLen
    end

    local targetDist = totalLength * percent
    local walked = 0

    for _, seg in ipairs(segments) do
        if walked + seg.length >= targetDist or seg == segments[#segments] then
            local remainder = math.max(0, targetDist - walked)
            local alpha = seg.length > 0 and (remainder / seg.length) or 0
            local exactPos = seg.startPos:Lerp(seg.endPos, alpha)
            return exactPos, seg.dir
        end
        walked = walked + seg.length
    end

    return points[#points], Vector3.new(1, 0, 0)
end

local function GetSortedHillsNear(targetPos)
    local map = workspace:FindFirstChild("_map") or workspace:FindFirstChild("Map")
    local hills = {}
    if not map then return hills end

    for _, part in ipairs(map:GetDescendants()) do
        if part:IsA("BasePart") and (part.Name:lower():find("hill") or part.Name:lower():find("cliff")) then
            table.insert(hills, part.Position + getgenv().AAConfig.HillOffset)
        end
    end

    table.sort(hills, function(a, b)
        return (a - targetPos).Magnitude < (b - targetPos).Magnitude
    end)

    return hills
end

-- 15. MODULE: EQUIPPED UNITS RESOLVER (STATS OR HOTBAR GUI FALLBACK)
local function GetEquippedUnitSlots()
    local slots = {}
    local stats = LocalPlayer:FindFirstChild("_stats") or LocalPlayer:FindFirstChild("Stats")
    local equipped = stats and (stats:FindFirstChild("equipped_units") or stats:FindFirstChild("EquippedUnits"))

    if equipped and #equipped:GetChildren() > 0 then
        for _, unitVal in ipairs(equipped:GetChildren()) do
            local uid = (unitVal:IsA("StringValue") or unitVal:IsA("IntValue")) and unitVal.Value
                or unitVal:GetAttribute("UnitId") or unitVal:GetAttribute("Id") or unitVal.Name
            local pType = tostring(unitVal:GetAttribute("PlacementType") or "Ground"):lower()
            if uid and tostring(uid) ~= "" then
                table.insert(slots, { id = uid, placementType = pType })
            end
        end
    end

    if #slots == 0 and PlayerGui then
        local hotbar = PlayerGui:FindFirstChild("SpawnUnitUI", true) or PlayerGui:FindFirstChild("Hotbar", true)
        if hotbar then
            for _, btn in ipairs(hotbar:GetDescendants()) do
                if btn:IsA("GuiButton") and btn.Visible then
                    local uid = btn:GetAttribute("UnitId") or btn:GetAttribute("Unit")
                    if uid and tostring(uid) ~= "" then
                        table.insert(slots, {
                            id = uid,
                            placementType = tostring(btn:GetAttribute("PlacementType") or "Ground"):lower()
                        })
                    end
                end
            end
        end
    end

    return slots
end

-- 16. MODULE: UNIT PLACEMENT (MACRO OR PERCENTAGE) & UPDATE 21.5 AUTO-UPGRADE
local nativeUpgradeEnabled = false

local function RunUnitRoutine()
    local cfg = getgenv().AAConfig

    if cfg.PlacementMode == "Macro" then
        StepMacroPlayback()
        return
    end

    if cfg.AutoPlace and not MacroState.IsRecording then
        local slots = GetEquippedUnitSlots()
        if #slots > 0 then
            local anchorCenter, _ = GetPointAtLanePercentage(cfg.LanePercent)
            local nearbyHills = GetSortedHillsNear(anchorCenter)

            for i, slot in ipairs(slots) do
                local slotOffsetPct = ((i - 1) - (#slots - 1) / 2) * cfg.SlotPercentSpread
                local slotPct = math.clamp(cfg.LanePercent + slotOffsetPct, 0.02, 0.98)
                local lanePos, laneDir = GetPointAtLanePercentage(slotPct)

                local finalPos
                if (slot.placementType == "hill" or slot.placementType == "hybrid") and #nearbyHills > 0 then
                    finalPos = nearbyHills[((i - 1) % #nearbyHills) + 1]
                else
                    local sideSign = (i % 2 == 0) and 1 or -1
                    local perpDir = Vector3.new(-laneDir.Z, 0, laneDir.X)
                    finalPos = lanePos + (perpDir * cfg.RoadSideOffset * sideSign)
                end

                FireEndpoint({"spawn_unit", "place_unit"}, slot.id, CFrame.new(finalPos))
                task.wait(0.2)
            end
        end
    end

    if cfg.UseNativeAutoUpgrade and not nativeUpgradeEnabled then
        local autoUpgradeBtn = PlayerGui and PlayerGui:FindFirstChild("AutoUpgrade", true)
        if autoUpgradeBtn and autoUpgradeBtn:IsA("GuiButton") then
            ClickGuiButton(autoUpgradeBtn)
            nativeUpgradeEnabled = true
        else
            FireEndpoint({"toggle_auto_upgrade", "auto_upgrade"}, true)
            nativeUpgradeEnabled = true
        end
    end

    if cfg.FallbackManualUpgrade and not cfg.UseNativeAutoUpgrade then
        for _, unit in ipairs(GetOwnedUnitsList()) do
            FireEndpoint({"upgrade_unit_ingame", "upgrade_unit"}, unit)
            task.wait(0.15)
        end
    end
end

-- 17. MODULE: MATCH FLOW, SUMMER WEATHER, MODIFIER CARDS & END-OF-MATCH WEBHOOK
local function RunMatchFlow()
    if SolveCaptcha() then return end

    CapturePreMatchSnapshot()

    local cfg = getgenv().AAConfig
    SendBannerWebhook(false)

    if cfg.AutoStart then
        FireEndpoint({"vote_start", "start_vote"})
    end

    if cfg.AutoSkipWaves then
        FireEndpoint({"vote_wave_skip", "wave_skip"})
    end

    if (cfg.SummerVoteTsunami or cfg.AutoPickModifierCard) and PlayerGui then
        local cardGui = PlayerGui:FindFirstChild("ModifierCards", true) or PlayerGui:FindFirstChild("WeatherVote", true)
        if cardGui and IsGuiVisibleInTree(cardGui) then
            for _, btn in ipairs(cardGui:GetDescendants()) do
                if btn:IsA("GuiButton") and IsGuiVisibleInTree(btn) then
                    local text = StripRichText(btn.Text):lower()
                    if (cfg.SummerVoteTsunami and text:find("tsunami")) or
                       (cfg.AutoPickModifierCard and (text:find("pearl") or text:find("30%"))) then
                        ClickGuiButton(btn)
                        break
                    end
                end
            end
        end
    end

    local resultsGui = PlayerGui and (PlayerGui:FindFirstChild("ResultsUI") or PlayerGui:FindFirstChild("EndScreen"))
    if resultsGui and resultsGui.Enabled then
        nativeUpgradeEnabled = false
        ResetMacroPlayback()
        if MacroState.IsRecording then StopMacroRecording() end

        task.wait(1.5)
        SendMatchEndWebhook(false)

        task.wait(1.0)
        ResetMatchSnapshot()

        if IsTargetUnitOnBanner() and HasEnoughCurrencyForRoll() then
            FireEndpoint({"request_return_lobby", "return_lobby"})
        elseif cfg.AutoReplay then
            FireEndpoint({"request_replay", "replay"})
        end
    end
end

-- 18. FAST UI TIMER LOOP
task.spawn(function()
    while true do
        if MacroState.IsRecording then
            local elapsed = os.clock() - MacroState.RecordStartTime
            local timerText = string.format("● REC [%s] — %d Actions", FormatTimer(elapsed), #MacroState.RecordedSteps)
            if MacroStatusLabelRef then
                MacroStatusLabelRef.TextColor3 = Color3.fromRGB(239, 68, 68)
                MacroStatusLabelRef.Text = timerText
            end
            if ActivityLabelRef then
                ActivityLabelRef.TextColor3 = Color3.fromRGB(239, 68, 68)
                ActivityLabelRef.Text = timerText
            end
        elseif MacroState.IsPlaying then
            local steps, totalDur = LoadMacroFile(getgenv().AAConfig.ActiveMacroName)
            local elapsed = os.clock() - MacroState.PlaybackStartTime
            local stepDone = math.min(MacroState.CurrentStepIndex - 1, #steps)
            local playText = string.format("▶ MACRO [%s / %s] (%d/%d)", FormatTimer(elapsed), FormatTimer(totalDur), stepDone, #steps)
            if MacroStatusLabelRef then
                MacroStatusLabelRef.TextColor3 = Color3.fromRGB(45, 226, 230)
                MacroStatusLabelRef.Text = playText
            end
            if ActivityLabelRef then
                ActivityLabelRef.TextColor3 = Color3.fromRGB(45, 226, 230)
                ActivityLabelRef.Text = playText
            end
        end
        task.wait(0.1)
    end
end)

-- 19. MAIN EXECUTION LOOP
task.spawn(function()
    while true do
        local cfg = getgenv().AAConfig
        local isEnabled = cfg.Enabled
        local inLobby = IsInLobby()

        if not MacroState.IsRecording and not MacroState.IsPlaying and ActivityLabelRef then
            local statusMode = cfg.PartyJoinEnabled and (cfg.Mode .. " + Party") or cfg.Mode
            ActivityLabelRef.Text = isEnabled
                and ("● " .. (inLobby and ("Queue: " .. statusMode) or ("Match: " .. statusMode)))
                or "● Script Activity: Paused"
            ActivityLabelRef.TextColor3 = isEnabled and Color3.fromRGB(16, 185, 129) or Color3.fromRGB(239, 68, 68)
        end

        if UnitCountLabelRef then
            UnitCountLabelRef.Text = "Units: " .. tostring(#GetOwnedUnitsList())
        end

        if isEnabled then
            pcall(function()
                if inLobby then
                    nativeUpgradeEnabled = false
                    ResetMacroPlayback()
                    ResetMatchSnapshot()
                    RunLobbyRoutine()
                else
                    LobbySearchStartTime = 0
                    RunUnitRoutine()
                    RunMatchFlow()
                end
            end)
        end
        task.wait(0.25)
    end
end)
