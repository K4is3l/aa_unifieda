-- ============================================================================
-- ANIME ADVENTURES - HARDENED AUTO MODE / PLAY HERE vs FIND MATCH + UNIT MACRO
-- ============================================================================

print("[AA_Auto_Macro] Initializing...")

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
    task.wait(0.1)
    LocalPlayer = Players.LocalPlayer
end

local PlayerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 15)
local IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- Safe file helpers
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

-- Anti-AFK
LocalPlayer.Idled:Connect(function()
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end)

-- ============================================================================
-- CONFIGURATION
-- ============================================================================
local CONFIG_FILE = "AA_Auto_Macro_Config.json"
local Config = {
    AutoEnabled = false,
    StageMode = "Summer Event",   -- "Summer Event", "Misty Village", "Regular Stages"
    QueueType = "Find Match",     -- "Play Here" or "Find Match"
    MacroName = "default_unit_macro",
    AutoPlayMacro = true,
    StepDelay = 0.25
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
                    Config[k] = data[k]
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
-- GUI CONTAINER RESOLVER (gethui -> CoreGui -> PlayerGui)
-- ============================================================================
local function GetSafeGuiParent()
    if type(gethui) == "function" then
        local ok, hui = pcall(gethui)
        if ok and typeof(hui) == "Instance" then
            return hui
        end
    end
    local okCore = pcall(function()
        local _ = CoreGui.Name
    end)
    if okCore and CoreGui then
        return CoreGui
    end
    return PlayerGui or LocalPlayer:WaitForChild("PlayerGui", 10)
end

-- ============================================================================
-- SAFE GUI CLICKER & BUTTON FINDER
-- ============================================================================
local StatusText = "Idle (Auto Match OFF)"

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
                local absPos = btn.AbsolutePosition
                local absSize = btn.AbsoluteSize
                if absSize.X > 0 and absSize.Y > 0 then
                    local x = absPos.X + absSize.X * 0.5
                    local y = absPos.Y + absSize.Y * 0.5 + inset.Y
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
        if cur:IsA("ScreenGui") and not cur.Enabled then
            return false
        end
        if cur:IsA("GuiObject") and not cur.Visible then
            return false
        end
        cur = cur.Parent
    end
    return true
end

local function GetButtonTextBlob(btn)
    local parts = { tostring(btn.Name or "") }
    if btn:IsA("TextButton") and type(btn.Text) == "string" then
        table.insert(parts, btn.Text)
    end
    for _, d in ipairs(btn:GetDescendants()) do
        if d:IsA("TextLabel") or d:IsA("TextButton") then
            if type(d.Text) == "string" and d.Text ~= "" then
                table.insert(parts, d.Text)
            end
        end
    end
    return table.concat(parts, " "):lower()
end

local function FindButtonContaining(phrase, ignoreRoot)
    if not PlayerGui then
        PlayerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    end
    if not PlayerGui then return nil end

    local target = phrase:lower()
    for _, d in ipairs(PlayerGui:GetDescendants()) do
        if (not ignoreRoot or not d:IsDescendantOf(ignoreRoot))
            and (d:IsA("TextButton") or d:IsA("ImageButton"))
            and IsReallyVisible(d)
        then
            local blob = GetButtonTextBlob(d)
            if blob:find(target, 1, true) then
                return d
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

-- ============================================================================
-- AUTO MODE ("Where do you want to Play?") + "Play Here" / "Find Match"
-- ============================================================================
local QueueState = {
    Busy = false,
    LastRun = 0,
    Cooldown = 2.5
}

local PanelGuiRef = nil

local function StepAutoMatchmaking()
    if not Config.AutoEnabled or not IsInLobby() or QueueState.Busy then
        return
    end
    if (os.clock() - QueueState.LastRun) < QueueState.Cooldown then
        return
    end

    QueueState.Busy = true
    QueueState.LastRun = os.clock()

    pcall(function()
        local desiredPhrase = (Config.QueueType == "Play Here") and "play here" or "find match"
        local fallbackPhrase = (Config.QueueType == "Play Here") and "find match" or "play here"

        -- 1. Click "Play Here" or "Find Match" if visible
        local queueBtn = FindButtonContaining(desiredPhrase, PanelGuiRef) or FindButtonContaining(fallbackPhrase, PanelGuiRef)
        if queueBtn then
            StatusText = "Clicking: " .. Config.QueueType
            SafeClick(queueBtn)
            return
        end

        -- 2. Click Stage Mode ("Summer Event", "Misty Village", "Regular Stages") if visible
        local modeBtn = FindButtonContaining(Config.StageMode, PanelGuiRef)
        if modeBtn then
            StatusText = "Selecting: " .. Config.StageMode
            SafeClick(modeBtn)
            task.wait(0.35)
            queueBtn = FindButtonContaining(desiredPhrase, PanelGuiRef) or FindButtonContaining(fallbackPhrase, PanelGuiRef)
            if queueBtn then
                StatusText = "Clicking: " .. Config.QueueType
                SafeClick(queueBtn)
            end
            return
        end

        -- 3. Otherwise try opening the Play menu once per cooldown
        for _, kw in ipairs({ "play", "areas", "summer", "event" }) do
            local openBtn = FindButtonContaining(kw, PanelGuiRef)
            if openBtn then
                StatusText = "Opening Play menu (" .. kw .. ")"
                SafeClick(openBtn)
                return
            end
        end

        StatusText = "Lobby: waiting for Play prompt..."
    end)

    QueueState.Busy = false
end

-- ============================================================================
-- UNIT MACRO RECORDER & PLAYER
-- ============================================================================
local Macro = {
    Recording = false,
    Playing = false,
    StartClock = 0,
    Steps = {},
    PlayStartClock = 0,
    PlayIndex = 1,
    Hooked = false
}

local function GetMacroPath(name)
    local safe = tostring(name or "default_unit_macro"):gsub("[^%w_%-]", "_")
    if safe == "" then safe = "default_unit_macro" end
    return "AAMacro_" .. safe .. ".json"
end

local function SaveMacroSteps()
    SaveConfig()
    SafeWriteFile(GetMacroPath(Config.MacroName), HttpService:JSONEncode({
        name = Config.MacroName,
        steps = Macro.Steps
    }))
end

local function LoadMacroSteps()
    local raw = SafeReadFile(GetMacroPath(Config.MacroName))
    if not raw then return {} end
    local ok, decoded = pcall(function()
        return HttpService:JSONDecode(raw)
    end)
    if ok and type(decoded) == "table" and type(decoded.steps) == "table" then
        return decoded.steps
    end
    return {}
end

local function GetOwnedUnits()
    local owned = {}
    local container = workspace:FindFirstChild("_units") or workspace:FindFirstChild("Units")
    if not container then return owned end
    for _, u in ipairs(container:GetChildren()) do
        local stats = u:FindFirstChild("_stats") or u:FindFirstChild("Stats")
        local ownerVal = stats and (stats:FindFirstChild("player") or stats:FindFirstChild("Owner"))
        local ownerAttr = u:GetAttribute("Owner") or u:GetAttribute("Player")
        if (ownerVal and ownerVal.Value == LocalPlayer) or (ownerAttr and tostring(ownerAttr) == LocalPlayer.Name) then
            table.insert(owned, u)
        end
    end
    return owned
end

local function GetOwnedUnitSlot(unitInstance)
    for idx, u in ipairs(GetOwnedUnits()) do
        if u == unitInstance then return idx end
    end
    return 1
end

local function GetOwnedUnitAtSlot(slot)
    return GetOwnedUnits()[slot]
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

local function InstallUnitMacroHook()
    if Macro.Hooked then return end
    if type(hookmetamethod) ~= "function" or type(getnamecallmethod) ~= "function" or type(checkcaller) ~= "function" then
        return
    end

    local ok = pcall(function()
        local prevNamecall
        prevNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            local args = { ... }

            if Macro.Recording and not checkcaller() and (method == "FireServer" or method == "InvokeServer") then
                if typeof(self) == "Instance" and self:IsDescendantOf(ReplicatedStorage) then
                    local rName = self.Name:lower()
                    local t = os.clock() - Macro.StartClock

                    if (rName:find("spawn") or rName:find("place")) and typeof(args[2]) == "CFrame" then
                        local cf = args[2]
                        table.insert(Macro.Steps, {
                            t = t,
                            kind = "place",
                            unitId = tostring(args[1]),
                            pos = { cf.X, cf.Y, cf.Z }
                        })
                    elseif rName:find("upgrade") and typeof(args[1]) == "Instance" then
                        table.insert(Macro.Steps, {
                            t = t,
                            kind = "upgrade",
                            slot = GetOwnedUnitSlot(args[1])
                        })
                    elseif rName:find("sell") and typeof(args[1]) == "Instance" then
                        table.insert(Macro.Steps, {
                            t = t,
                            kind = "sell",
                            slot = GetOwnedUnitSlot(args[1])
                        })
                    end
                end
            end

            return prevNamecall(self, ...)
        end)
    end)

    if ok then Macro.Hooked = true end
end

local function StartRecordingMacro()
    InstallUnitMacroHook()
    Macro.Playing = false
    Macro.Steps = {}
    Macro.StartClock = os.clock()
    Macro.Recording = true
    StatusText = "Recording unit actions..."
end

local function StopRecordingMacro()
    if not Macro.Recording then return end
    Macro.Recording = false
    SaveMacroSteps()
    StatusText = "Saved " .. tostring(#Macro.Steps) .. " macro steps"
end

local function StartPlayingMacro()
    if Macro.Recording then StopRecordingMacro() end
    local loaded = LoadMacroSteps()
    Macro.Steps = loaded
    Macro.PlayIndex = 1
    Macro.PlayStartClock = os.clock()
    Macro.Playing = (#loaded > 0)
    StatusText = Macro.Playing and ("Playing macro (" .. #loaded .. " steps)") or "No macro steps saved"
    return Macro.Playing, #loaded
end

local function StepMacroPlayback()
    if Macro.Recording or not Config.AutoPlayMacro or IsInLobby() then
        return
    end

    if not Macro.Playing then
        local loaded = LoadMacroSteps()
        if #loaded == 0 then return end
        Macro.Steps = loaded
        Macro.PlayIndex = 1
        Macro.PlayStartClock = os.clock()
        Macro.Playing = true
    end

    local elapsed = os.clock() - Macro.PlayStartClock
    while Macro.PlayIndex <= #Macro.Steps do
        local step = Macro.Steps[Macro.PlayIndex]
        if elapsed >= (step.t or 0) then
            StatusText = "Macro step " .. Macro.PlayIndex .. "/" .. #Macro.Steps
            if step.kind == "place" and type(step.pos) == "table" then
                CallRemoteFuzzy({ "spawn_unit", "place_unit" }, step.unitId, CFrame.new(step.pos[1], step.pos[2], step.pos[3]))
            elseif step.kind == "upgrade" then
                local unitInst = GetOwnedUnitAtSlot(step.slot or 1)
                if unitInst then CallRemoteFuzzy({ "upgrade_unit_ingame", "upgrade_unit" }, unitInst) end
            elseif step.kind == "sell" then
                local unitInst = GetOwnedUnitAtSlot(step.slot or 1)
                if unitInst then CallRemoteFuzzy({ "sell_unit", "sell" }, unitInst) end
            end
            Macro.PlayIndex = Macro.PlayIndex + 1
            task.wait(0.15)
        else
            break
        end
    end
end

-- ============================================================================
-- UI BUILDER (HIGH DISPLAYORDER + TOGGLE BUTTON)
-- ============================================================================
local StatusLabelRef = nil

local function BuildPanel()
    local guiParent = GetSafeGuiParent()
    if not guiParent then
        warn("[AA_Auto_Macro] Could not find GUI container!")
        return
    end

    for _, container in ipairs({ guiParent, PlayerGui, CoreGui }) do
        if container then
            local old = container:FindFirstChild("AA_AutoMacro_UI")
            if old then pcall(function() old:Destroy() end) end
        end
    end

    local sg = Instance.new("ScreenGui")
    sg.Name = "AA_AutoMacro_UI"
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true
    sg.DisplayOrder = 999999
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent = guiParent
    PanelGuiRef = sg

    -- Small toggle pill so you can always show/hide the panel
    local pill = Instance.new("TextButton")
    pill.Name = "TogglePill"
    pill.Size = UDim2.new(0, 56, 0, 32)
    pill.Position = UDim2.new(0, 12, 0.22, 0)
    pill.BackgroundColor3 = Color3.fromRGB(30, 110, 220)
    pill.TextColor3 = Color3.fromRGB(255, 255, 255)
    pill.Font = Enum.Font.GothamBold
    pill.TextSize = 13
    pill.Text = "AA UI"
    pill.Active = true
    pill.Draggable = true
    pill.Parent = sg
    Instance.new("UICorner", pill).CornerRadius = UDim.new(0, 8)

    local frame = Instance.new("Frame")
    frame.Name = "MainFrame"
    frame.Size = UDim2.new(0, 255, 0, 260)
    frame.Position = UDim2.new(0.5, -127, 0.5, -130)
    frame.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Draggable = true
    frame.Visible = true
    frame.Parent = sg
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(60, 130, 240)
    stroke.Thickness = 1.5
    stroke.Parent = frame

    pill.MouseButton1Click:Connect(function()
        frame.Visible = not frame.Visible
    end)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -12, 0, 26)
    title.Position = UDim2.new(0, 6, 0, 4)
    title.BackgroundTransparency = 1
    title.Text = "AA Auto + Unit Macro"
    title.TextColor3 = Color3.fromRGB(240, 245, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.Parent = frame

    local function MakeBtn(label, yPos, bgColor)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, -16, 0, 30)
        b.Position = UDim2.new(0, 8, 0, yPos)
        b.BackgroundColor3 = bgColor
        b.TextColor3 = Color3.fromRGB(255, 255, 255)
        b.Font = Enum.Font.GothamBold
        b.TextSize = 12
        b.Text = label
        b.Parent = frame
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
        return b
    end

    local modes = { "Summer Event", "Misty Village", "Regular Stages" }
    local modeIdx = 1
    for i, m in ipairs(modes) do
        if m == Config.StageMode then modeIdx = i end
    end

    local autoBtn = MakeBtn("Auto Match: " .. (Config.AutoEnabled and "ON" or "OFF"), 34,
        Config.AutoEnabled and Color3.fromRGB(35, 140, 80) or Color3.fromRGB(140, 45, 45))
    local modeBtn = MakeBtn("Mode: " .. Config.StageMode, 70, Color3.fromRGB(45, 70, 120))
    local queueBtn = MakeBtn("Join Type: " .. Config.QueueType, 106, Color3.fromRGB(45, 105, 125))
    local recBtn = MakeBtn("Record Macro: START", 142, Color3.fromRGB(150, 85, 30))
    local playMacroBtn = MakeBtn("Play Macro (Now)", 178, Color3.fromRGB(70, 55, 130))

    local statusLbl = Instance.new("TextLabel")
    statusLbl.Size = UDim2.new(1, -16, 0, 36)
    statusLbl.Position = UDim2.new(0, 8, 0, 214)
    statusLbl.BackgroundTransparency = 1
    statusLbl.Text = "Status: " .. StatusText
    statusLbl.TextColor3 = Color3.fromRGB(180, 210, 255)
    statusLbl.Font = Enum.Font.Gotham
    statusLbl.TextSize = 11
    statusLbl.TextWrapped = true
    statusLbl.Parent = frame
    StatusLabelRef = statusLbl

    autoBtn.MouseButton1Click:Connect(function()
        Config.AutoEnabled = not Config.AutoEnabled
        SaveConfig()
        autoBtn.Text = "Auto Match: " .. (Config.AutoEnabled and "ON" or "OFF")
        autoBtn.BackgroundColor3 = Config.AutoEnabled and Color3.fromRGB(35, 140, 80) or Color3.fromRGB(140, 45, 45)
        StatusText = Config.AutoEnabled and "Auto Match enabled" or "Idle (Auto Match OFF)"
    end)

    modeBtn.MouseButton1Click:Connect(function()
        modeIdx = (modeIdx % #modes) + 1
        Config.StageMode = modes[modeIdx]
        SaveConfig()
        modeBtn.Text = "Mode: " .. Config.StageMode
    end)

    queueBtn.MouseButton1Click:Connect(function()
        Config.QueueType = (Config.QueueType == "Find Match") and "Play Here" or "Find Match"
        SaveConfig()
        queueBtn.Text = "Join Type: " .. Config.QueueType
    end)

    recBtn.MouseButton1Click:Connect(function()
        if not Macro.Recording then
            StartRecordingMacro()
            recBtn.Text = "Record Macro: STOP & SAVE"
            recBtn.BackgroundColor3 = Color3.fromRGB(175, 35, 35)
        else
            StopRecordingMacro()
            recBtn.Text = "Record Macro: START (" .. tostring(#Macro.Steps) .. ")"
            recBtn.BackgroundColor3 = Color3.fromRGB(150, 85, 30)
        end
    end)

    playMacroBtn.MouseButton1Click:Connect(function()
        local ok, count = StartPlayingMacro()
        playMacroBtn.Text = ok and ("Playing Macro (" .. tostring(count) .. " steps)") or "No Saved Macro Steps"
    end)

    print("[AA_Auto_Macro] UI Loaded into: " .. guiParent.Name)
end

BuildPanel()

LocalPlayer.OnTeleport:Connect(function()
    Macro.Playing = false
    Macro.PlayIndex = 1
end)

task.spawn(function()
    while task.wait(0.35) do
        if StatusLabelRef then
            StatusLabelRef.Text = "Status: " .. StatusText
        end
        if Config.AutoEnabled and IsInLobby() then
            StepAutoMatchmaking()
        elseif not IsInLobby() then
            StepMacroPlayback()
        end
    end
end)
