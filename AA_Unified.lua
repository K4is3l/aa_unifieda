-- ============================================================================
-- ANIME ADVENTURES (UPD 21.5+) - UNIFIED AUTO-FARM, MACRO RECORDER & MODERN UI
-- Save as 'AA_Unified.lua' in your executor's 'autoexec' and 'workspace' folders.
-- ============================================================================

repeat task.wait() until game:IsLoaded()

if getgenv().AA_Loaded then
    warn("[AA_Unified] Already loaded! Re-executing UI...")
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
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 15)

-- 3. PERSISTENT CONFIGURATION
local CONFIG_FILENAME = "AA_Config.json"
local DefaultConfig = {
    Enabled = true,
    Mode = "SummerEvent",          -- Options: "SummerEvent", "MistyVillage", "Story", "InfinityCastle", "PartyJoin"

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

    -- STORY & PARTY SETTINGS
    StoryPod = "Story_Pod_1",
    StoryWorld = "namek",
    StoryAct = "1",
    StoryDifficulty = "Normal",
    TargetPartyName = "Summer",

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

-- 4. ANTI-AFK & NON-BLOCKING REMOTE DISPATCHER
LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

local RemoteCache = {}
local function GetRemotesFolder()
    local endpoints = ReplicatedStorage:FindFirstChild("endpoints")
    if endpoints then
        return endpoints:FindFirstChild("client_to_server") or endpoints
    end
    return ReplicatedStorage
end

local function FindRemote(remoteName)
    if RemoteCache[remoteName] and RemoteCache[remoteName].Parent then
        return RemoteCache[remoteName]
    end
    local folder = GetRemotesFolder()
    local remote = folder:FindFirstChild(remoteName, true) or ReplicatedStorage:FindFirstChild(remoteName, true)
    if remote and (remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction")) then
        RemoteCache[remoteName] = remote
        return remote
    end
    return nil
end

local function FireEndpoint(remoteName, ...)
    local remote = FindRemote(remoteName)
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

-- 5. MODULE: MACRO RECORDER, STORAGE & PLAYBACK ENGINE
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

local function GetOwnedUnitIndex(unitObj)
    local activeUnits = workspace:FindFirstChild("_units")
    if not activeUnits then return 1 end
    local idx = 0
    for _, u in ipairs(activeUnits:GetChildren()) do
        local owner = u:FindFirstChild("_stats") and u._stats:FindFirstChild("player")
        if owner and owner.Value == LocalPlayer then
            idx = idx + 1
            if u == unitObj then return idx end
        end
    end
    return 1
end

local function GetOwnedUnitByIndex(targetIdx)
    local activeUnits = workspace:FindFirstChild("_units")
    if not activeUnits then return nil end
    local idx = 0
    for _, u in ipairs(activeUnits:GetChildren()) do
        local owner = u:FindFirstChild("_stats") and u._stats:FindFirstChild("player")
        if owner and owner.Value == LocalPlayer then
            idx = idx + 1
            if idx == targetIdx then return u end
        end
    end
    return nil
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
                    local rName = self.Name
                    local elapsed = os.clock() - MacroState.RecordStartTime

                    if rName == "spawn_unit" and typeof(args[2]) == "CFrame" then
                        local cf = args[2]
                        table.insert(MacroState.RecordedSteps, {
                            time = elapsed,
                            action = "spawn_unit",
                            unitId = tostring(args[1]),
                            pos = { cf.X, cf.Y, cf.Z }
                        })
                    elseif rName == "upgrade_unit_ingame" and typeof(args[1]) == "Instance" then
                        table.insert(MacroState.RecordedSteps, {
                            time = elapsed,
                            action = "upgrade_unit_ingame",
                            unitIndex = GetOwnedUnitIndex(args[1])
                        })
                    elseif rName == "sell_unit" and typeof(args[1]) == "Instance" then
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

-- Fallback workspace unit listener if executor blocks hookmetamethod
local function AttachWorkspaceFallbackRecorder()
    local activeUnits = workspace:FindFirstChild("_units")
    if not activeUnits then return end

    activeUnits.ChildAdded:Connect(function(unit)
        if not MacroState.IsRecording or MacroState.HookInstalled then return end
        task.wait(0.15)
        local uStats = unit:FindFirstChild("_stats")
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
                FireEndpoint("spawn_unit", step.unitId, cf)
            elseif step.action == "upgrade_unit_ingame" then
                local unitObj = GetOwnedUnitByIndex(step.unitIndex or 1)
                if unitObj then FireEndpoint("upgrade_unit_ingame", unitObj) end
            elseif step.action == "sell_unit" then
                local unitObj = GetOwnedUnitByIndex(step.unitIndex or 1)
                if unitObj then FireEndpoint("sell_unit", unitObj) end
            end
            MacroState.CurrentStepIndex = MacroState.CurrentStepIndex + 1
        else
            break
        end
    end
end

-- 6. MODULE: MATCH REWARDS TRACKER, PORTAL DETECTOR & DISCORD WEBHOOKS
local MatchTracker = {
    SnapshotTaken = false,
    WebhookSentThisMatch = false,
    StartTime = 0,
    StartCurrencies = {},
    StartItems = {},
    LastSummaryText = "No completed match recorded yet."
}

local function ReadPlayerCurrencies()
    local stats = LocalPlayer:FindFirstChild("_stats")
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
    local stats = LocalPlayer:FindFirstChild("_stats")
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

    local resultsGui = PlayerGui and PlayerGui:FindFirstChild("ResultsUI")
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

    local titleText = report.hasPortal
        and "🌀 PORTAL DROP! Match Completed (" .. cfg.Mode .. ")"
        or "🏆 Match Completed — " .. cfg.Mode

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

-- 7. MODULE: LIVE BANNER SCANNER & BANNER WEBHOOK
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
    local stats = LocalPlayer:FindFirstChild("_stats")
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
                { name = "Location", value = workspace:FindFirstChild("_lobby") and "Lobby" or "In Match", inline = true }
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

-- 8. MODULE: MODERN STYLED UI (CYAN / VIOLET / EMERALD DARK THEME)
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

    local function AddDropdownCycle(parent, labelText, configKey, options)
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
        end)
    end

    local function AddStyledInput(parent, labelText, configKey, isNumber)
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
    AddDropdownCycle(tabMain, "Farm Mode:", "Mode", {"SummerEvent", "MistyVillage", "Story", "InfinityCastle", "PartyJoin"})
    AddPillToggle(tabMain, "Auto-Start & Skip Waves", "AutoStart")
    AddPillToggle(tabMain, "Auto-Replay Match", "AutoReplay")
    AddPillToggle(tabMain, "Captcha Auto-Solver", "CaptchaBypass")
    AddPillToggle(tabMain, "Summer: Vote Tsunami (2x)", "SummerVoteTsunami")
    AddPillToggle(tabMain, "Summer: +30% Pearl Cards", "AutoPickModifierCard")

    -- TAB 2: PLACEMENT & MACRO RECORDER
    local tabPlace = CreateTab("Placement")
    AddDropdownCycle(tabPlace, "Placement Mode:", "PlacementMode", {"Percentage", "Macro"})
    AddStyledInput(tabPlace, "Macro File Name:", "ActiveMacroName", false)

    local macroStatusBox = Instance.new("TextLabel")
    macroStatusBox.Size = UDim2.new(1, -4, 0, 34)
    macroStatusBox.BackgroundColor3 = COL_INPUT
    macroStatusBox.Font = Enum.Font.GothamBold
    macroStatusBox.TextSize = 11
    macroStatusBox.TextColor3 = COL_CYAN
    macroStatusBox.Text = "⏹ Macro Idle — Ready to Record or Play"
    macroStatusBox.Parent = tabPlace
    Instance.new("UICorner", macroStatusBox).CornerRadius = UDim.new(0, 8)
    local mStroke = Instance.new("UIStroke", macroStatusBox)
    mStroke.Color = Color3.fromRGB(48, 65, 88)
    mStroke.Thickness = 1
    MacroStatusLabelRef = macroStatusBox

    local recRow = Instance.new("Frame")
    recRow.Size = UDim2.new(1, -4, 0, 30)
    recRow.BackgroundTransparency = 1
    recRow.Parent = tabPlace

    local startRecBtn = Instance.new("TextButton")
    startRecBtn.Size = UDim2.new(0.32, 0, 1, 0)
    startRecBtn.BackgroundColor3 = COL_RED
    startRecBtn.Font = Enum.Font.GothamBold
    startRecBtn.TextSize = 11
    startRecBtn.TextColor3 = Color3.new(1, 1, 1)
    startRecBtn.Text = "● Start Rec"
    startRecBtn.Parent = recRow
    Instance.new("UICorner", startRecBtn).CornerRadius = UDim.new(0, 6)

    local stopRecBtn = Instance.new("TextButton")
    stopRecBtn.Size = UDim2.new(0.32, 0, 1, 0)
    stopRecBtn.Position = UDim2.new(0.34, 0, 0, 0)
    stopRecBtn.BackgroundColor3 = COL_EMERALD
    stopRecBtn.Font = Enum.Font.GothamBold
    stopRecBtn.TextSize = 11
    stopRecBtn.TextColor3 = Color3.new(1, 1, 1)
    stopRecBtn.Text = "■ Stop & Save"
    stopRecBtn.Parent = recRow
    Instance.new("UICorner", stopRecBtn).CornerRadius = UDim.new(0, 6)

    local clearRecBtn = Instance.new("TextButton")
    clearRecBtn.Size = UDim2.new(0.32, 0, 1, 0)
    clearRecBtn.Position = UDim2.new(0.68, 0, 0, 0)
    clearRecBtn.BackgroundColor3 = COL_VIOLET
    clearRecBtn.Font = Enum.Font.GothamBold
    clearRecBtn.TextSize = 11
    clearRecBtn.TextColor3 = Color3.new(1, 1, 1)
    clearRecBtn.Text = "Clear Macro"
    clearRecBtn.Parent = recRow
    Instance.new("UICorner", clearRecBtn).CornerRadius = UDim.new(0, 6)

    startRecBtn.MouseButton1Click:Connect(function()
        StartMacroRecording()
        macroStatusBox.TextColor3 = COL_RED
        macroStatusBox.Text = "● RECORDING [00:00.0] — Place/Upgrade units now!"
    end)

    stopRecBtn.MouseButton1Click:Connect(function()
        local count = #MacroState.RecordedSteps
        local dur = FormatTimer(os.clock() - MacroState.RecordStartTime)
        StopMacroRecording()
        macroStatusBox.TextColor3 = COL_EMERALD
        macroStatusBox.Text = string.format("✔ Saved %d actions (%s) to %s", count, dur, cfg.ActiveMacroName)
    end)

    clearRecBtn.MouseButton1Click:Connect(function()
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
    AddStyledInput(tabStory, "Story World ID:", "StoryWorld", false)
    AddStyledInput(tabStory, "Story Act (1-6 / inf):", "StoryAct", false)
    AddDropdownCycle(tabStory, "Difficulty:", "StoryDifficulty", {"Normal", "Hard"})
    AddStyledInput(tabStory, "Story Lobby Pod:", "StoryPod", false)
    AddStyledInput(tabStory, "Party Name Filter:", "TargetPartyName", false)

    pages[1].Visible = true
    tabButtons[1].btn.TextColor3 = COL_CYAN
    tabButtons[1].stroke.Color = COL_CYAN
    tabButtons[1].stroke.Thickness = 1.8
    tabButtons[1].stroke.Transparency = 0
end

CreateStyledControlGui()

-- 9. MODULE: CAPTCHA SOLVER (UPD 21.5 NUMERIC CODE + LEGACY IMAGE GRID)
local function SolveCaptcha()
    if not getgenv().AAConfig.CaptchaBypass or not PlayerGui then return false end

    local captchaGui = PlayerGui:FindFirstChild("CaptchaGui") or PlayerGui:FindFirstChild("Verification")
    if not captchaGui then
        for _, gui in ipairs(PlayerGui:GetChildren()) do
            if gui:IsA("ScreenGui") and gui.Enabled and gui:FindFirstChild("Submit", true) then
                captchaGui = gui
                break
            end
        end
    end
    if not (captchaGui and captchaGui.Enabled) then return false end

    local codeText = nil
    local inputBox = nil
    local submitBtn = nil

    for _, obj in ipairs(captchaGui:GetDescendants()) do
        if obj:IsA("TextLabel") and obj.Visible then
            local digits = obj.Text:gsub("%s+", "")
            if digits:match("^%d%d%d%d+$") then
                codeText = digits
            end
        elseif obj:IsA("TextBox") and obj.Visible then
            inputBox = obj
        elseif obj:IsA("GuiButton") and obj.Visible then
            local n = (obj.Name .. " " .. (obj:IsA("TextButton") and obj.Text or "")):lower()
            if n:find("submit") then
                submitBtn = obj
            end
        end
    end

    if codeText and inputBox then
        inputBox.Text = codeText
        task.wait(0.25)
        if submitBtn and firesignal then
            pcall(function() firesignal(submitBtn.MouseButton1Click) end)
            pcall(function() firesignal(submitBtn.Activated) end)
        end
        task.wait(0.5)
        return true
    end

    local promptLabel = captchaGui:FindFirstChild("Prompt", true)
    local targetKeyword = promptLabel and promptLabel.Text:lower() or ""

    for _, obj in ipairs(captchaGui:GetDescendants()) do
        if obj:IsA("ImageButton") and obj.Visible then
            local tag = tostring(obj:GetAttribute("Category") or obj.Name):lower()
            if targetKeyword ~= "" and targetKeyword:find(tag, 1, true) then
                if firesignal then pcall(function() firesignal(obj.MouseButton1Click) end) end
                task.wait(0.25)
            end
        end
    end

    if submitBtn and firesignal then
        task.wait(0.3)
        pcall(function() firesignal(submitBtn.MouseButton1Click) end)
    end

    return true
end

-- 10. MODULE: AUTO-SUMMON & CURRENCY CHECK
local function HasEnoughCurrencyForRoll()
    local cfg = getgenv().AAConfig
    local stats = LocalPlayer:FindFirstChild("_stats")
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

    local summonZone = workspace:FindFirstChild("_lobby") and workspace._lobby:FindFirstChild("summon", true)
    if summonZone and summonZone:IsA("BasePart") and LocalPlayer.Character and LocalPlayer.Character.PrimaryPart then
        local dist = (LocalPlayer.Character.PrimaryPart.Position - summonZone.Position).Magnitude
        if dist > 15 then
            LocalPlayer.Character:SetPrimaryPartCFrame(summonZone.CFrame + Vector3.new(0, 3, 0))
            task.wait(0.5)
        end
    end

    local rollType = cfg.SummonMulti and "multi" or "single"
    FireEndpoint("request_summon", cfg.TargetBannerType, rollType)
    task.wait(1.5)

    if HasTargetUnitInInventory(cfg.TargetBannerUnit, cfg.TargetBannerRarity) then
        cfg.BannerTargetAcquired = true
        SaveConfig(cfg)
        return false
    end

    return true
end

-- 11. MODULE: LOBBY & MATCHMAKING (STORY / SUMMER / MISTY / PARTY)
local function RunLobbyRoutine()
    if SolveCaptcha() then return end
    if RunBannerRoutine() then return end

    local cfg = getgenv().AAConfig
    local mode = cfg.Mode

    if mode == "Story" then
        local levelId = string.format("%s_level_%s", cfg.StoryWorld, cfg.StoryAct)
        FireEndpoint("request_join_lobby", cfg.StoryPod)
        task.wait(0.6)
        FireEndpoint("request_match_making", cfg.StoryPod, levelId, true, cfg.StoryDifficulty)
        task.wait(0.6)
        FireEndpoint("request_start_game", cfg.StoryPod)

    elseif mode == "SummerEvent" then
        FireEndpoint("request_join_lobby", "SummerEvent_Pod_1")
        task.wait(1)
        FireEndpoint("request_start_game", "SummerEvent_Pod_1")

    elseif mode == "MistyVillage" then
        FireEndpoint("request_join_lobby", "MistyVillage_Pod_1")
        task.wait(1)
        FireEndpoint("request_start_game", "MistyVillage_Pod_1")

    elseif mode == "InfinityCastle" then
        FireEndpoint("request_start_infinity_castle")

    elseif mode == "PartyJoin" then
        local partyGui = PlayerGui and PlayerGui:FindFirstChild("PartyFinder", true)
        if not partyGui then return end

        for _, label in ipairs(partyGui:GetDescendants()) do
            if label:IsA("TextLabel") and label.Text:find(cfg.TargetPartyName, 1, true) then
                local joinBtn = label.Parent and label.Parent:FindFirstChild("JoinButton")
                if joinBtn and joinBtn:IsA("GuiButton") and firesignal then
                    pcall(function() firesignal(joinBtn.MouseButton1Click) end)
                    break
                end
            end
        end
    end
end

-- 12. MODULE: DYNAMIC PERCENTAGE PATH CALCULATOR (0% TO 100%)
local function GetOrderedWaypoints()
    local map = workspace:FindFirstChild("_map")
    local wpFolder = map and map:FindFirstChild("waypoints")
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
        table.sort(children, function(a, b) return a.Name < b.Name end)
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
    local map = workspace:FindFirstChild("_map")
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

-- 13. MODULE: UNIT PLACEMENT (MACRO OR PERCENTAGE) & UPDATE 21.5 AUTO-UPGRADE
local nativeUpgradeEnabled = false

local function RunUnitRoutine()
    local cfg = getgenv().AAConfig

    if cfg.PlacementMode == "Macro" then
        StepMacroPlayback()
        return
    end

    if cfg.AutoPlace and not MacroState.IsRecording then
        local stats = LocalPlayer:FindFirstChild("_stats")
        local equipped = stats and stats:FindFirstChild("equipped_units")
        if equipped then
            local units = equipped:GetChildren()
            local anchorCenter, _ = GetPointAtLanePercentage(cfg.LanePercent)
            local nearbyHills = GetSortedHillsNear(anchorCenter)

            for i, unitVal in ipairs(units) do
                local slotOffsetPct = ((i - 1) - (#units - 1) / 2) * cfg.SlotPercentSpread
                local slotPct = math.clamp(cfg.LanePercent + slotOffsetPct, 0.02, 0.98)
                local lanePos, laneDir = GetPointAtLanePercentage(slotPct)

                local placementType = tostring(unitVal:GetAttribute("PlacementType") or "Ground"):lower()
                local finalPos

                if (placementType == "hill" or placementType == "hybrid") and #nearbyHills > 0 then
                    finalPos = nearbyHills[((i - 1) % #nearbyHills) + 1]
                else
                    local sideSign = (i % 2 == 0) and 1 or -1
                    local perpDir = Vector3.new(-laneDir.Z, 0, laneDir.X)
                    finalPos = lanePos + (perpDir * cfg.RoadSideOffset * sideSign)
                end

                FireEndpoint("spawn_unit", unitVal.Value, CFrame.new(finalPos))
                task.wait(0.2)
            end
        end
    end

    if cfg.UseNativeAutoUpgrade and not nativeUpgradeEnabled then
        local autoUpgradeBtn = PlayerGui and PlayerGui:FindFirstChild("AutoUpgrade", true)
        if autoUpgradeBtn and autoUpgradeBtn:IsA("GuiButton") and firesignal then
            pcall(function() firesignal(autoUpgradeBtn.MouseButton1Click) end)
            nativeUpgradeEnabled = true
        else
            FireEndpoint("toggle_auto_upgrade", true)
            nativeUpgradeEnabled = true
        end
    end

    if cfg.FallbackManualUpgrade and not cfg.UseNativeAutoUpgrade then
        local activeUnits = workspace:FindFirstChild("_units")
        if activeUnits then
            for _, unit in ipairs(activeUnits:GetChildren()) do
                local uStats = unit:FindFirstChild("_stats")
                local owner = uStats and uStats:FindFirstChild("player")
                if owner and owner.Value == LocalPlayer then
                    FireEndpoint("upgrade_unit_ingame", unit)
                    task.wait(0.15)
                end
            end
        end
    end
end

-- 14. MODULE: MATCH FLOW, SUMMER WEATHER, MODIFIER CARDS & END-OF-MATCH WEBHOOK
local function RunMatchFlow()
    if SolveCaptcha() then return end

    CapturePreMatchSnapshot()

    local cfg = getgenv().AAConfig
    SendBannerWebhook(false)

    if cfg.AutoStart then
        FireEndpoint("vote_start")
    end

    if cfg.AutoSkipWaves then
        FireEndpoint("vote_wave_skip")
    end

    if (cfg.SummerVoteTsunami or cfg.AutoPickModifierCard) and PlayerGui then
        local cardGui = PlayerGui:FindFirstChild("ModifierCards", true) or PlayerGui:FindFirstChild("WeatherVote", true)
        if cardGui and cardGui.Visible then
            for _, btn in ipairs(cardGui:GetDescendants()) do
                if btn:IsA("GuiButton") then
                    local text = (btn.Text or ""):lower()
                    if (cfg.SummerVoteTsunami and text:find("tsunami")) or
                       (cfg.AutoPickModifierCard and (text:find("pearl") or text:find("30%"))) then
                        if firesignal then pcall(function() firesignal(btn.MouseButton1Click) end) end
                        break
                    end
                end
            end
        end
    end

    local resultsGui = PlayerGui and PlayerGui:FindFirstChild("ResultsUI")
    if resultsGui and resultsGui.Enabled then
        nativeUpgradeEnabled = false
        ResetMacroPlayback()
        if MacroState.IsRecording then StopMacroRecording() end

        task.wait(1.5)
        SendMatchEndWebhook(false)

        task.wait(1.0)
        ResetMatchSnapshot()

        if IsTargetUnitOnBanner() and HasEnoughCurrencyForRoll() then
            FireEndpoint("request_return_lobby")
        elseif cfg.AutoReplay then
            FireEndpoint("request_replay")
        end
    end
end

-- 15. FAST UI TIMER LOOP
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

-- 16. MAIN EXECUTION LOOP
task.spawn(function()
    while true do
        local isEnabled = getgenv().AAConfig.Enabled
        local inLobby = workspace:FindFirstChild("_lobby") ~= nil

        if not MacroState.IsRecording and not MacroState.IsPlaying and ActivityLabelRef then
            ActivityLabelRef.Text = isEnabled
                and ("● Script Activity: " .. (inLobby and "Lobby Queue" or "In Match"))
                or "● Script Activity: Paused"
            ActivityLabelRef.TextColor3 = isEnabled and Color3.fromRGB(16, 185, 129) or Color3.fromRGB(239, 68, 68)
        end

        if UnitCountLabelRef then
            local activeUnits = workspace:FindFirstChild("_units")
            local count = 0
            if activeUnits then
                for _, u in ipairs(activeUnits:GetChildren()) do
                    local owner = u:FindFirstChild("_stats") and u._stats:FindFirstChild("player")
                    if owner and owner.Value == LocalPlayer then
                        count = count + 1
                    end
                end
            end
            UnitCountLabelRef.Text = "Units: " .. tostring(count)
        end

        if isEnabled then
            pcall(function()
                if inLobby then
                    nativeUpgradeEnabled = false
                    ResetMacroPlayback()
                    ResetMatchSnapshot()
                    RunLobbyRoutine()
                else
                    RunUnitRoutine()
                    RunMatchFlow()
                end
            end)
        end
        task.wait(0.25)
    end
end)
