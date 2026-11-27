-- ============================================================================
-- ANIME ADVENTURES - UNIFIED HUB (DARK / ORANGE TABBED UI + MACRO + AUTO PLAY)
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
-- 1. SAFE EXECUTOR FILE & TELEPORT WRAPPERS
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

local function SafeListFiles()
    local names = {}
    if type(listfiles) == "function" then
        local ok, files = pcall(listfiles, "")
        if ok and type(files) == "table" then
            for _, f in ipairs(files) do
                local m = tostring(f):match("AAMacro_([%w_%-]+)%.json$")
                if m then table.insert(names, m) end
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
local Config = {
    -- Home / Session Stats
    Runs = 0,
    CurrentWave = 0,

    -- Macro (Record / Play & Macro Maps)
    SelectedMacro = "Default",
    NewMacroName = "",
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
    PathPosition = 1,               -- 1% to 100%
    Spacing = 1,                    -- studs
    CoverAllLanes = true,
    PlaceNearBuffers = false,
    WeatherAware = true,
    FarmUnitsFirst = true,
    AutoUpgrade = true,
    UpgradeWhileSaving = true,
    WalkLikePlayer = false,

    -- Event Auto Play (Summer Hunt)
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
    PortalMatchmaking = true,

    AutoSwordsmith = false,
    SwordsmithMatchmaking = true,
    BloodMoonWhenUp = true,
    AutoMistyTower = false,
    MistyMatchmaking = true,

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
                                v[subK] = data[k][subK]
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
-- 3. FUZZY REMOTES, GUI CLICKER & STATE HELPERS
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
-- 4. MACRO ENGINE (RECORD / PLAY BY MONEY OR TIME + STEP LIST)
-- ============================================================================
local MacroEngine = {
    StartClock = 0,
    Steps = {},
    PlayIndex = 1,
    PlayStartClock = 0,
    Status = "idle",
    Hooked = false
}

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
                    local wave = GetCurrentWave()
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
                    elseif rName:find("upgrade") and typeof(args[1]) == "Instance" then
                        table.insert(MacroEngine.Steps, {
                            action = "Upgrade",
                            unit = args[1].Name,
                            slot = GetUnitSlotIndex(args[1]),
                            wave = wave,
                            yen = yen,
                            t = t
                        })
                    elseif rName:find("sell") and typeof(args[1]) == "Instance" then
                        table.insert(MacroEngine.Steps, {
                            action = "Sell",
                            unit = args[1].Name,
                            slot = GetUnitSlotIndex(args[1]),
                            wave = wave,
                            yen = yen,
                            t = t
                        })
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

        -- 1. Click "Find Match" or "Play Here" if "Join Matchmaking?" popup is open
        local confirmBtn = FindButtonByPhrase(desired, rootGui) or FindButtonByPhrase(fallback, rootGui)
        if confirmBtn then
            SafeClick(confirmBtn)
            return
        end

        -- 2. Click mode card if "Where do you want to Play?" popup is open
        local modeBtn = FindButtonByPhrase(activeMode, rootGui)
        if modeBtn then
            SafeClick(modeBtn)
            task.wait(0.35)
            confirmBtn = FindButtonByPhrase(desired, rootGui) or FindButtonByPhrase(fallback, rootGui)
            if confirmBtn then SafeClick(confirmBtn) end
            return
        end

        -- 3. Open Play prompt once per cooldown
        local playBtn = FindButtonByPhrase("play", rootGui)
        if playBtn then
            SafeClick(playBtn)
        end
    end)

    JoinGuard.Busy = false
end

-- ============================================================================
-- 6. BIGFROOT-STYLE DARK + ORANGE TABBED UI
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
    if not guiParent then return end

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

    -- Top Floating Watermark Pill (Tap to open/close)
    local topPill = Instance.new("TextButton")
    topPill.Name = "TopPill"
    topPill.Size = UDim2.new(0, 230, 0, 28)
    topPill.Position = UDim2.new(0.5, -115, 0, 8)
    topPill.BackgroundColor3 = C_SIDEBAR
    topPill.TextColor3 = C_TEXT
    topPill.Font = Enum.Font.GothamSemibold
    topPill.TextSize = 12
    topPill.Text = "AA Hub  •  Tap to toggle UI"
    topPill.Active = true
    topPill.Draggable = true
    topPill.Parent = sg
    Instance.new("UICorner", topPill).CornerRadius = UDim.new(1, 0)
    local pillStroke = Instance.new("UIStroke", topPill)
    pillStroke.Color = C_ACCENT
    pillStroke.Thickness = 1

    -- Main Window
    local winW = IsMobile and 540 or 640
    local winH = IsMobile and 340 or 410
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

    -- Left Sidebar
    local sidebar = Instance.new("Frame")
    sidebar.Size = UDim2.new(0, 145, 1, 0)
    sidebar.BackgroundColor3 = C_SIDEBAR
    sidebar.BorderSizePixel = 0
    sidebar.Parent = main
    Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0, 12)

    local brand = Instance.new("TextLabel")
    brand.Size = UDim2.new(1, -16, 0, 38)
    brand.Position = UDim2.new(0, 12, 0, 8)
    brand.BackgroundTransparency = 1
    brand.Text = "AA Unified\nv2.0.0"
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

    -- Right Content Area
    local header = Instance.new("TextLabel")
    header.Size = UDim2.new(1, -165, 0, 34)
    header.Position = UDim2.new(0, 158, 0, 8)
    header.BackgroundTransparency = 1
    header.Text = "Home"
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.TextColor3 = C_TEXT
    header.Font = Enum.Font.GothamBold
    header.TextSize = 16
    header.Parent = main

    local pageHolder = Instance.new("Frame")
    pageHolder.Size = UDim2.new(1, -162, 1, -48)
    pageHolder.Position = UDim2.new(0, 154, 0, 42)
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
            btn.BackgroundColor3 = active and Color3.fromRGB(45, 32, 24) or Color3.fromRGB(22, 20, 19)
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

    -- UI Component Builders
    local function CreateSectionCard(parent, titleText)
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
    end

    local function AddCycleDropdown(card, labelText, options, currentVal, onChanged)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 28)
        row.BackgroundTransparency = 1
        row.Parent = card

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.48, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = labelText
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextColor3 = C_TEXT
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 12
        lbl.Parent = row

        local idx = 1
        for i, opt in ipairs(options) do
            if opt == currentVal then idx = i end
        end

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.52, 0, 1, 0)
        btn.Position = UDim2.new(0.48, 0, 0, 0)
        btn.BackgroundColor3 = C_CTRL
        btn.TextColor3 = C_TEXT
        btn.Font = Enum.Font.GothamSemibold
        btn.TextSize = 11
        btn.Text = tostring(options[idx]) .. "  ▾"
        btn.Parent = row
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

        btn.MouseButton1Click:Connect(function()
            idx = (idx % #options) + 1
            local chosen = options[idx]
            btn.Text = tostring(chosen) .. "  ▾"
            onChanged(chosen)
            SaveConfig()
        end)
    end

    local function AddButton(card, text, colorOverride, callback)
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
    -- TAB 1: HOME (Status, Stats, Quick Actions)
    -- ========================================================================
    local homePage = AddNavTab("Home")
    local statusCard = CreateSectionCard(homePage, "Status & Session")
    local statusReadout = Instance.new("TextLabel")
    statusReadout.Size = UDim2.new(1, 0, 0, 42)
    statusReadout.BackgroundTransparency = 1
    statusReadout.TextXAlignment = Enum.TextXAlignment.Left
    statusReadout.TextColor3 = C_TEXT
    statusReadout.Font = Enum.Font.GothamSemibold
    statusReadout.TextSize = 12
    statusReadout.Text = "Session: 0m 0s  |  Features On: 0\nFPS: 60  |  Ping: 0 ms  |  Runs: 0  |  Macro Steps: 0"
    statusReadout.Parent = statusCard

    local quickCard = CreateSectionCard(homePage, "Quick Actions")
    AddButton(quickCard, "Load Last Config", C_CTRL, function()
        LoadConfig()
    end)
    AddButton(quickCard, "Toggle Watermark Pill", C_CTRL, function()
        topPill.Visible = not topPill.Visible
    end)

    -- ========================================================================
    -- TAB 2: MACRO (Record / Play + Macro Maps)
    -- ========================================================================
    local macroPage = AddNavTab("Macro")
    local macroCtrlCard = CreateSectionCard(macroPage, "Macro > Record / Play")

    local macroBox = Instance.new("TextBox")
    macroBox.Size = UDim2.new(1, 0, 0, 28)
    macroBox.BackgroundColor3 = C_CTRL
    macroBox.TextColor3 = C_TEXT
    macroBox.PlaceholderText = "new macro name (e.g. SummerFarm)"
    macroBox.Text = Config.SelectedMacro
    macroBox.Font = Enum.Font.Gotham
    macroBox.TextSize = 12
    macroBox.ClearTextOnFocus = false
    macroBox.Parent = macroCtrlCard
    Instance.new("UICorner", macroBox).CornerRadius = UDim.new(0, 6)

    AddButton(macroCtrlCard, "Create / Load Macro Name", C_CTRL, function()
        local name = macroBox.Text ~= "" and macroBox.Text or "Default"
        Config.SelectedMacro = name
        MacroEngine.Steps = LoadMacroFile(name)
        MacroEngine.PlayIndex = 1
        SaveConfig()
    end)

    AddToggle(macroCtrlCard, "Record Macro", Config.RecordMacro, function(val)
        Config.RecordMacro = val
        if val then
            Config.PlayMacro = false
            InstallMacroHook()
            MacroEngine.Steps = {}
            MacroEngine.StartClock = os.clock()
        else
            SaveMacroFile(Config.SelectedMacro, MacroEngine.Steps)
        end
    end)

    AddToggle(macroCtrlCard, "Play Macro", Config.PlayMacro, function(val)
        Config.PlayMacro = val
        if val then
            Config.RecordMacro = false
            MacroEngine.Steps = LoadMacroFile(Config.SelectedMacro)
            MacroEngine.PlayIndex = 1
            MacroEngine.PlayStartClock = os.clock()
        end
    end)

    AddToggle(macroCtrlCard, "Equip Macro Units", Config.EquipMacroUnits, function(val)
        Config.EquipMacroUnits = val
    end)

    AddCycleDropdown(macroCtrlCard, "Play By", { "Money", "Time" }, Config.PlayBy, function(v)
        Config.PlayBy = v
    end)

    local stepsCard = CreateSectionCard(macroPage, "Steps & Macro Maps")
    local stepsInfo = Instance.new("TextLabel")
    stepsInfo.Size = UDim2.new(1, 0, 0, 32)
    stepsInfo.BackgroundTransparency = 1
    stepsInfo.TextXAlignment = Enum.TextXAlignment.Left
    stepsInfo.TextColor3 = C_MUTED
    stepsInfo.Font = Enum.Font.Gotham
    stepsInfo.TextSize = 11
    stepsInfo.Text = "Macro: idle  |  Step 0 / 0"
    stepsInfo.Parent = stepsCard

    AddToggle(stepsCard, "Use Macro Maps", Config.UseMacroMaps, function(val)
        Config.UseMacroMaps = val
    end)

    -- ========================================================================
    -- TAB 3: AUTO PLAY (All Modes, Event, Specific Unit Settings)
    -- ========================================================================
    local autoPlayPage = AddNavTab("Auto Play")
    local apCard = CreateSectionCard(autoPlayPage, "Auto Play > All Modes & Event")

    AddToggle(apCard, "Auto Play", Config.AutoPlay, function(v) Config.AutoPlay = v end)
    AddToggle(apCard, "Use Event Page In Summer Hunt", Config.UseEventInSummer, function(v) Config.UseEventInSummer = v end)
    AddCycleDropdown(apCard, "Path Position", { "1%", "25%", "50%", "75%", "100%" }, tostring(Config.PathPosition) .. "%", function(v)
        Config.PathPosition = tonumber(v:match("%d+")) or 50
    end)
    AddToggle(apCard, "Cover All Lanes", Config.CoverAllLanes, function(v) Config.CoverAllLanes = v end)
    AddToggle(apCard, "Place Near Others' Buffers", Config.PlaceNearBuffers, function(v) Config.PlaceNearBuffers = v end)
    AddToggle(apCard, "Weather-Aware", Config.WeatherAware, function(v) Config.WeatherAware = v end)
    AddToggle(apCard, "Farm Units First", Config.FarmUnitsFirst, function(v) Config.FarmUnitsFirst = v end)
    AddToggle(apCard, "Auto Upgrade", Config.AutoUpgrade, function(v) Config.AutoUpgrade = v end)
    AddToggle(apCard, "Upgrade While Saving", Config.UpgradeWhileSaving, function(v) Config.UpgradeWhileSaving = v end)
    AddToggle(apCard, "Walk Like A Player", Config.WalkLikePlayer, function(v) Config.WalkLikePlayer = v end)

    local unitCard = CreateSectionCard(autoPlayPage, "Specific Unit Settings (Slots 1-6)")
    AddCycleDropdown(unitCard, "Active Slot", { "Slot 1", "Slot 2", "Slot 3", "Slot 4", "Slot 5", "Slot 6" }, "Slot " .. Config.SelectedUnitSlot, function(v)
        Config.SelectedUnitSlot = tonumber(v:match("%d+")) or 1
    end)
    AddToggle(unitCard, "Place Selected Slot On Hill", Config.UnitSlots[Config.SelectedUnitSlot].OnHill, function(v)
        Config.UnitSlots[Config.SelectedUnitSlot].OnHill = v
    end)

    -- ========================================================================
    -- TAB 4: JOIN (Castle / Events / Portals / Swordsmith & Misty Tower)
    -- ========================================================================
    local joinPage = AddNavTab("Join")
    local eventCard = CreateSectionCard(joinPage, "Castle / Events (Summer Hunt)")
    AddToggle(eventCard, "Auto Join Event Challenge", Config.AutoEventChallenge, function(v) Config.AutoEventChallenge = v end)
    AddToggle(eventCard, "Event Matchmaking (OFF = Play Here)", Config.EventMatchmaking, function(v) Config.EventMatchmaking = v end)
    AddToggle(eventCard, "Hunt Bingo Maps", Config.HuntBingoMaps, function(v) Config.HuntBingoMaps = v end)
    AddToggle(eventCard, "Hunt Unwon Weathers", Config.HuntUnwonWeathers, function(v) Config.HuntUnwonWeathers = v end)

    local castleCard = CreateSectionCard(joinPage, "Infinity Castle & Portals")
    AddToggle(castleCard, "Auto Infinity Castle", Config.AutoInfinityCastle, function(v) Config.AutoInfinityCastle = v end)
    AddToggle(castleCard, "Castle Matchmaking (OFF = Play Here)", Config.CastleMatchmaking, function(v) Config.CastleMatchmaking = v end)
    AddToggle(castleCard, "Auto Portal", Config.AutoPortal, function(v) Config.AutoPortal = v end)
    AddToggle(castleCard, "Portal Matchmaking (OFF = Play Here)", Config.PortalMatchmaking, function(v) Config.PortalMatchmaking = v end)

    local villageCard = CreateSectionCard(joinPage, "Swordsmith / Misty Village & Tower")
    AddToggle(villageCard, "Auto Swordsmith / Misty Village", Config.AutoSwordsmith, function(v) Config.AutoSwordsmith = v end)
    AddToggle(villageCard, "Village Matchmaking (OFF = Play Here)", Config.SwordsmithMatchmaking, function(v) Config.SwordsmithMatchmaking = v end)
    AddToggle(villageCard, "Blood Moon When Up", Config.BloodMoonWhenUp, function(v) Config.BloodMoonWhenUp = v end)
    AddToggle(villageCard, "Auto Misty Tower", Config.AutoMistyTower, function(v) Config.AutoMistyTower = v end)

    -- ========================================================================
    -- TAB 5: GAME & LOBBY (Match Flow)
    -- ========================================================================
    local gamePage = AddNavTab("Game")
    local gameCard = CreateSectionCard(gamePage, "Match Automation")
    AddToggle(gameCard, "Auto Start Match", Config.AutoStartMatch, function(v) Config.AutoStartMatch = v end)
    AddToggle(gameCard, "Auto Skip Waves", Config.AutoSkipWaves, function(v) Config.AutoSkipWaves = v end)
    AddToggle(gameCard, "Auto Replay", Config.AutoReplay, function(v) Config.AutoReplay = v end)
    AddToggle(gameCard, "Claim Clear Rewards", Config.ClaimClearRewards, function(v) Config.ClaimClearRewards = v end)

    SelectTab("Home")

    -- Live Status & Heartbeat Updater
    local frameCounter = 0
    local fps = 60
    RunService.RenderStepped:Connect(function()
        frameCounter = frameCounter + 1
    end)

    task.spawn(function()
        while sg.Parent do
            task.wait(1)
            fps = frameCounter
            frameCounter = 0

            local elapsed = math.floor(os.clock() - SessionStart)
            local mins = math.floor(elapsed / 60)
            local secs = elapsed % 60
            local pingMs = 0
            pcall(function()
                pingMs = math.floor(StatsService.Network.ServerStatsItem["Data Ping"]:GetValue())
            end)

            statusReadout.Text = string.format(
                "Session: %dm %ds  |  Features On: %d\nFPS: %d  |  Ping: %d ms  |  Runs: %d  |  Macro Steps: %d",
                mins, secs, CountActiveFeatures(), fps, pingMs, Config.Runs, #MacroEngine.Steps
            )
            topPill.Text = string.format("AA Hub  •  %d fps  •  Tap to toggle", fps)
            stepsInfo.Text = string.format(
                "Macro: %s  |  Step %d / %d",
                MacroEngine.Status,
                math.min(MacroEngine.PlayIndex, math.max(1, #MacroEngine.Steps)),
                #MacroEngine.Steps
            )
        end
    end)

    return sg
end

local HubScreenGui = BuildTabbedHub()

-- ============================================================================
-- 7. MAIN RUNTIME LOOP
-- ============================================================================
task.spawn(function()
    while task.wait(0.35) do
        if IsInLobby() then
            StepLobbyJoinAndMatchmaking(HubScreenGui)
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
