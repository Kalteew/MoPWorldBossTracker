
local ADDON_NAME = ...

local BOSS_QUEST_IDS = {
    32099, -- Sha of Anger
    32098, -- Galleon
    32518, -- Nalak
    32519, -- Oondasta
    33117, -- Xuen
    33118, -- Chi-Ji
    33119, -- Yu'lon
    33120, -- Niuzao
    33121, -- Ordos
}

local function IsQuestCompleted(id)
    if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
        return C_QuestLog.IsQuestFlaggedCompleted(id)
    elseif _G.IsQuestFlaggedCompleted then
        return _G.IsQuestFlaggedCompleted(id)
    end
    return false
end

local function HasKilledAnyBoss()
    for _, id in ipairs(BOSS_QUEST_IDS) do
        if IsQuestCompleted(id) then
            return true
        end
    end
    return false
end

local function GetCharKey()
    local name, realm = UnitName("player")
    realm = GetRealmName() or realm or "?"
    return realm .. " - " .. name
end

local function ColorizeName(name, class)
    local c = RAID_CLASS_COLORS[class]
    if c and c.colorStr then
        return "|c" .. c.colorStr .. name .. "|r"
    end
    return name
end

local DB

local function EnsureDefaults()
    DB = MoPWorldBossTrackerDB or {}
    MoPWorldBossTrackerDB = DB
    DB.chars = DB.chars or {}
    DB.minimap = DB.minimap or { hide = false }
    DB.framePos = DB.framePos or {}
    DB.lastResetAt = DB.lastResetAt or 0
    DB.showAll = DB.showAll or false
end

local function UpdateCharacter()
    local level = UnitLevel("player")
    if level < 90 then return end
    local key = GetCharKey()
    local _, classFile = UnitClass("player")
    local char = DB.chars[key] or {}
    char.level = level
    char.class = classFile
    char.lastSeen = time()
    char.killed = HasKilledAnyBoss()
    DB.chars[key] = char
end

local function GetNextWeeklyReset()
    local now = time()
    if C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset then
        return now + C_DateAndTime.GetSecondsUntilWeeklyReset()
    else
        return now + 7 * 24 * 60 * 60
    end
end

local function CheckReset()
    local now = time()
    if not DB.lastResetAt or now >= DB.lastResetAt then
        DB.lastResetAt = GetNextWeeklyReset()
        for _, char in pairs(DB.chars) do
            char.killed = nil
        end
        return true
    end
    return false
end

local mainFrame

local function RefreshUI()
    if not mainFrame or not mainFrame:IsShown() then return end
    UpdateCharacter()

    for _, line in ipairs(mainFrame.lines) do
        line:Hide()
    end
    wipe(mainFrame.lines)

    local index = 0
    for name, info in pairs(DB.chars) do
        if info.level and info.level >= 90 and (DB.showAll or not info.killed) then
            index = index + 1
            local line = mainFrame.lines[index]
            if not line then
                line = mainFrame.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                mainFrame.lines[index] = line
                line:SetPoint("TOPLEFT", 0, -(index - 1) * 20)
                line:SetPoint("RIGHT")
            end
            local text = ColorizeName(name, info.class)
            if info.killed then
                text = text .. " - done"
            end
            line:SetText(text)
            line:Show()
        end
    end

    if DB.showAll then
        mainFrame.message:Hide()
    else
        if index == 0 then
            mainFrame.message:Show()
        else
            mainFrame.message:Hide()
        end
    end
    mainFrame.content:SetHeight(index * 20)
end

local function ToggleFrame()
    if mainFrame:IsShown() then
        mainFrame:Hide()
    else
        mainFrame:Show()
        RefreshUI()
    end
end

local function ShowFrame()
    if not mainFrame:IsShown() then
        mainFrame:Show()
    end
    RefreshUI()
end

local function HideFrame()
    mainFrame:Hide()
end

local function UpdateMinimapButton()
    if DB.minimap.hide then
        MoPWorldBossTrackerMinimapButton:Hide()
    else
        MoPWorldBossTrackerMinimapButton:Show()
    end
end

local function ToggleMinimapButton()
    DB.minimap.hide = not DB.minimap.hide
    UpdateMinimapButton()
end

local function CreateMinimapButton()
    local button = CreateFrame("Button", "MoPWorldBossTrackerMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:SetPoint("TOPLEFT", Minimap, "TOPLEFT")

    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture("Interface\\Icons\\inv_misc_map_01")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")

    button:SetScript("OnClick", ToggleFrame)

    UpdateMinimapButton()
end

local function LoadPosition()
    local pos = DB.framePos
    if pos.point then
        mainFrame:ClearAllPoints()
        mainFrame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
    else
        mainFrame:SetPoint("CENTER")
    end
end

local function SavePosition()
    local point, _, relativePoint, x, y = mainFrame:GetPoint()
    DB.framePos.point = point
    DB.framePos.relativePoint = relativePoint
    DB.framePos.x = x
    DB.framePos.y = y
end

local function CreateMainFrame()
    mainFrame = CreateFrame("Frame", "MoPWorldBossTrackerFrame", UIParent, "BackdropTemplate")
    mainFrame:SetSize(300, 200)
    mainFrame:SetClampedToScreen(true)
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
    mainFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); SavePosition() end)
    mainFrame:SetScript("OnShow", RefreshUI)
    mainFrame:Hide()

    mainFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })

    local title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", 0, -10)
    title:SetText("MoP World Boss Tracker")
    mainFrame.title = title

    local close = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -5, -5)
    close:SetScript("OnClick", HideFrame)

    local scrollFrame = CreateFrame("ScrollFrame", nil, mainFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 16, -32)
    scrollFrame:SetPoint("BOTTOMRIGHT", -32, 16)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(1, 1)
    scrollFrame:SetScrollChild(content)
    mainFrame.content = content

    mainFrame.lines = {}
    mainFrame.message = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mainFrame.message:SetPoint("TOP", 0, -10)
    mainFrame.message:SetText("All set for this week!")
    mainFrame.message:Hide()

    LoadPosition()
end

SLASH_MOPWB1 = "/mopwb"
SlashCmdList["MOPWB"] = function(msg)
    msg = msg and msg:lower() or ""
    if msg == "show" then
        ShowFrame()
    elseif msg == "hide" then
        HideFrame()
    elseif msg == "minimap" then
        ToggleMinimapButton()
    elseif msg == "all" then
        DB.showAll = true
        RefreshUI()
    elseif msg == "todo" then
        DB.showAll = false
        RefreshUI()
    else
        ToggleFrame()
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

eventFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        EnsureDefaults()
        CreateMainFrame()
        CreateMinimapButton()
        CheckReset()
        UpdateCharacter()
    elseif event == "PLAYER_ENTERING_WORLD" then
        CheckReset()
        UpdateCharacter()
        RefreshUI()
    end
end)

local elapsed = 0
eventFrame:SetScript("OnUpdate", function(self, e)
    elapsed = elapsed + e
    if elapsed > 60 then
        elapsed = 0
        if CheckReset() then
            RefreshUI()
        end
    end
end)
