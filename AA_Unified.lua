table.insert(dropLines, string.format("%s**+%dx %s**", prefix, gained, itemName))
        end
    end

    local currencyText = (#earnedLines > 0) and table.concat(earnedLines, "\n") or "• No currency gained"
    local dropsText = (#dropLines > 0) and table.concat(dropLines, "\n") or "• No item/portal drops"

    local summary = string.format(
        "**Match Duration:** %s\n**Currencies:**\n%s\n**Drops:**\n%s",
        durationStr,
        currencyText,
        dropsText
    )

    MatchTracker.LastSummaryText = summary
    return summary, hasPortalDrop
end

-- ============================================================================
-- 9. LOBBY POD RESOLVER & "FIND MATCH" QUEUE CONTROLLER
-- ============================================================================
local QueueGuard = {
    Busy = false,
    LastAttempt = 0,
    Cooldown = 3.0
}

local function GetLobbySearchRoots()
    local roots = {}
    local candidates = {
        workspace:FindFirstChild("_LOBBIES"),
        workspace:FindFirstChild("_PORTALS"),
        workspace:FindFirstChild("_lobby"),
        workspace:FindFirstChild("Lobby"),
        workspace
    }

    local seen = {}
    for _, item in ipairs(candidates) do
        if item and not seen[item] then
            seen[item] = true
            table.insert(roots, item)
        end
    end
    return roots
end

local function GetPodPivotOrPart(podObj)
    if not podObj then return nil, nil end
    if podObj:IsA("BasePart") then
        return podObj.CFrame, podObj
    end
    if podObj:IsA("Model") then
        local primary = podObj.PrimaryPart or podObj:FindFirstChildWhichIsA("BasePart", true)
        return podObj:GetPivot(), primary
    end
    return nil, nil
end

local function FindBestLobbyPod(keyword)
    local needle = tostring(keyword or ""):lower()
    local fallbackPod = nil

    for _, root in ipairs(GetLobbySearchRoots()) do
        for _, desc in ipairs(root:GetDescendants()) do
            if desc:IsA("Model") or desc:IsA("BasePart") then
                local fullPath = desc:GetFullName():lower()
                local nameMatch = needle ~= "" and (desc.Name:lower():find(needle, 1, true) or fullPath:find(needle, 1, true))

                local labelMatch = false
                if needle ~= "" then
                    for _, guiText in ipairs(desc:GetDescendants()) do
                        if guiText:IsA("TextLabel") and type(guiText.Text) == "string" then
                            if guiText.Text:lower():find(needle, 1, true) then
                                labelMatch = true
                                break
                            end
                        end
                    end
                end

                if nameMatch or labelMatch then
                    local cf, part = GetPodPivotOrPart(desc)
                    if cf then
                        return desc, cf, part
                    end
                elseif not fallbackPod and (desc.Name:lower():find("lobbytemplate", 1, true) or desc.Name:lower():find("pod", 1, true)) then
                    local cf, part = GetPodPivotOrPart(desc)
                    if cf then
                        fallbackPod = { inst = desc, cf = cf, part = part }
                    end
                end
            end
        end
    end

    if fallbackPod then
        return fallbackPod.inst, fallbackPod.cf, fallbackPod.part
    end
    return nil, nil, nil
end

local function MoveToLobbyPod(podKeyword)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local _, cf, part = FindBestLobbyPod(podKeyword)
    if not cf then return nil end

    if hrp and (hrp.Position - cf.Position).Magnitude > 8 then
        if char.PrimaryPart then
            char:PivotTo(cf + Vector3.new(0, 3, 0))
        else
            hrp.CFrame = cf + Vector3.new(0, 3, 0)
        end
    end

    if firetouchinterest and hrp and part and part:IsA("BasePart") then
        pcall(function()
            firetouchinterest(hrp, part, 0)
            task.wait(0.05)
            firetouchinterest(hrp, part, 1)
        end)
    end

    return cf
end

local function IsVisibleTree(obj)
    local cur = obj
    while cur and cur ~= PlayerGui do
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

local function FindVisibleMatchButton()
    if not PlayerGui then return nil end

    for _, desc in ipairs(PlayerGui:GetDescendants()) do
        if (desc:IsA("TextButton") or desc:IsA("ImageButton")) and IsVisibleTree(desc) then
            local candidates = {}
            if desc:IsA("TextButton") and type(desc.Text) == "string" then
                table.insert(candidates, desc.Text:lower())
            end
            table.insert(candidates, desc.Name:lower())

            for _, child in ipairs(desc:GetDescendants()) do
                if child:IsA("TextLabel") and type(child.Text) == "string" then
                    table.insert(candidates, child.Text:lower())
                end
            end

            for _, label in ipairs(candidates) do
                if label:find("find match", 1, true) or label:find("play here", 1, true) then
                    return desc
                end
            end
        end
    end

    return nil
end

local function StepSummerOrModeQueue()
    local cfg = getgenv().AAConfig
    if not cfg or not cfg.Enabled or not IsInLobby() or QueueGuard.Busy then
        return
    end

    local now = os.clock()
    if (now - QueueGuard.LastAttempt) < QueueGuard.Cooldown then
        return
    end

    QueueGuard.Busy = true
    QueueGuard.LastAttempt = now

    pcall(function()
        local matchBtn = FindVisibleMatchButton()
        if matchBtn then
            ClickGuiButton(matchBtn)
            return
        end

        local mode = cfg.Mode or "SummerEvent"
        FireEndpoint({
            "SelectMode", "SetMode", "ChooseMode",
            "JoinMatchmaking", "StartMatchmaking", "FindMatch",
            "Queue", "EnterQueue", "JoinQueue"
        }, mode)

        if cfg.PartyJoinEnabled then
            FireEndpoint({ "JoinParty", "SearchParty", "FindParty" }, cfg.TargetPartyName)
            if cfg.AutoCreatePartyFallback then
                FireEndpoint({ "CreateParty", "MakeParty", "HostParty" }, mode)
            end
        end

        task.wait(0.35)
        matchBtn = FindVisibleMatchButton()
        if matchBtn then
            ClickGuiButton(matchBtn)
        end
    end)

    QueueGuard.Busy = false
end

local function QueueSoloModePod()
    local cfg = getgenv().AAConfig
    if not cfg then return end
    local mode = cfg.Mode

    local matchBtn = FindVisibleMatchButton()
    if matchBtn then
        ClickGuiButton(matchBtn)
        return
    end

    StepSummerOrModeQueue()

    task.wait(0.35)
    matchBtn = FindVisibleMatchButton()
    if matchBtn then
        ClickGuiButton(matchBtn)
        return
    end

    if mode == "Story" then
        local levelId = string.format("%s_level_%s", cfg.StoryWorld, cfg.StoryAct)
        MoveToLobbyPod(cfg.StoryPod)
        FireEndpoint({"request_join_lobby", "join_lobby"}, cfg.StoryPod)
        task.wait(0.5)
        FireEndpoint({"request_match_making", "match_making"}, cfg.StoryPod, levelId, true, cfg.StoryDifficulty)
        task.wait(0.5)
        FireEndpoint({"request_start_game", "start_game"}, cfg.StoryPod)

    elseif mode == "SummerEvent" then
        MoveToLobbyPod("Summer")
        FireEndpoint({"request_join_lobby", "join_lobby"}, "SummerEvent_Pod_1")
        task.wait(0.6)
        matchBtn = FindVisibleMatchButton()
        if matchBtn then
            ClickGuiButton(matchBtn)
        else
            FireEndpoint({"request_start_game", "start_game"}, "SummerEvent_Pod_1")
        end

    elseif mode == "MistyVillage" then
        MoveToLobbyPod("Misty")
        FireEndpoint({"request_join_lobby", "join_lobby"}, "MistyVillage_Pod_1")
        task.wait(0.6)
        matchBtn = FindVisibleMatchButton()
        if matchBtn then
            ClickGuiButton(matchBtn)
        else
            FireEndpoint({"request_start_game", "start_game"}, "MistyVillage_Pod_1")
        end

    elseif mode == "InfinityCastle" then
        MoveToLobbyPod("Infinity")
        FireEndpoint({"request_start_infinity_castle", "infinity_castle"})
    end
end

local LobbySearchStartTime = 0

local function RunLobbyRoutine()
    if type(SolveCaptcha) == "function" and SolveCaptcha() then return end
    if type(RunBannerRoutine) == "function" and RunBannerRoutine() then return end

    local cfg = getgenv().AAConfig
    if not cfg then return end

    local matchBtn = FindVisibleMatchButton()
    if matchBtn then
        ClickGuiButton(matchBtn)
        return
    end

    if cfg.PartyJoinEnabled then
        if LobbySearchStartTime == 0 then
            LobbySearchStartTime = os.clock()
        end

        if type(TryJoinModeParty) == "function" and TryJoinModeParty() then
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
