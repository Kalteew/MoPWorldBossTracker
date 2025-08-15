
local ADDON_NAME = ...
local ADDON_VERSION = GetAddOnMetadata(ADDON_NAME, "Version") or "dev"

local BOSSES = {
    { questId = 32099, npcId = 60491, name = "Sha of Anger" },
    { questId = 32098, npcId = 62346, name = "Galleon" },
    { questId = 32518, npcId = 69099, name = "Nalak" },
    { questId = 32519, npcId = 69161, name = "Oondasta" },
    { questId = 33117, npcId = 71954, name = "Xuen" },
    { questId = 33118, npcId = 71953, name = "Chi-Ji" },
    { questId = 33119, npcId = 71955, name = "Yu'lon" },
    { questId = 33120, npcId = 71952, name = "Niuzao" },
    { questId = 33121, npcId = 72057, name = "Ordos" },
}

local ACTIVE_QUEST_IDS = {
    [32099] = true, -- Sha of Anger
    [32098] = true, -- Galleon
}

local function GetBossName(boss)
    if not boss.name and C_QuestLog and C_QuestLog.GetTitleForQuestID then
        boss.name = C_QuestLog.GetTitleForQuestID(boss.questId)
    end
    if not boss.name then
        boss.name = "Unknown"
    end
    return boss.name
end

local function GetActiveBossNames()
    local names = {}
    for _, boss in ipairs(BOSSES) do
        if ACTIVE_QUEST_IDS[boss.questId] then
            table.insert(names, GetBossName(boss))
        end
    end
    return names
end

local function IsQuestCompleted(id)
    if GetQuestsCompleted then
        local completed = GetQuestsCompleted()
        return completed and completed[id] or false
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

function AddTextToFrame(theFrame, text, firstPosition, x, y)
    local font = theFrame:CreateFontString(nil, "OVERLAY")
    font:SetFontObject("GameFontHighlight")
    font:SetPoint(firstPosition, x, y)
    font:SetText(text)
    font:SetFont("Fonts\\FRIZQT__.ttf", pcdSettings.entrySize, "OUTLINE")
    return font
end

local DB

local LOG_LEVEL = { ERROR = 1, INFO = 2, DEBUG = 3 }

local function Log(level, msg, ...)
    if DB and DB.logLevel and level <= DB.logLevel then
        print("|cff33ff99" .. ADDON_NAME .. "|r:", string.format(msg, ...))
    end
end

local function LogError(msg, ...)
    Log(LOG_LEVEL.ERROR, msg, ...)
end

local function LogInfo(msg, ...)
    Log(LOG_LEVEL.INFO, msg, ...)
end

local function LogDebug(msg, ...)
    Log(LOG_LEVEL.DEBUG, msg, ...)
end

local function EnsureDefaults()
    DB = MoPWorldBossTrackerDB or {}
    MoPWorldBossTrackerDB = DB
    DB.chars = DB.chars or {}
    DB.minimap = DB.minimap or { hide = false }
    DB.framePos = DB.framePos or {}
    DB.framePos.width = DB.framePos.width or 300
    DB.framePos.height = DB.framePos.height or 200
    DB.lastResetAt = DB.lastResetAt or 0
    DB.showAll = DB.showAll or false
    DB.frameShown = DB.frameShown or false
    DB.trackBosses = DB.trackBosses or {}
    DB.logLevel = DB.logLevel or LOG_LEVEL.INFO

    if DB.version ~= ADDON_VERSION then
        for _, boss in ipairs(BOSSES) do
            DB.trackBosses[boss.questId] = ACTIVE_QUEST_IDS[boss.questId] or false
        end
        DB.version = ADDON_VERSION
    else
        for _, boss in ipairs(BOSSES) do
            if DB.trackBosses[boss.questId] == nil then
                DB.trackBosses[boss.questId] = ACTIVE_QUEST_IDS[boss.questId] or false
            end
        end
    end
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
    char.killed = type(char.killed) == "table" and char.killed or {}
    for _, boss in ipairs(BOSSES) do
        if DB.trackBosses[boss.questId] ~= false then
            if IsQuestCompleted(boss.questId) then
                char.killed[boss.questId] = true
            else
                char.killed[boss.questId] = nil
            end
        end
    end
    DB.chars[key] = char
    LogDebug("Updated data for %s", key)
end

local function GetMissingBosses(info)
    local killed = type(info.killed) == "table" and info.killed or {}
    local missing = {}
    for _, boss in ipairs(BOSSES) do
        if DB.trackBosses[boss.questId] ~= false and not killed[boss.questId] then
            table.insert(missing, GetBossName(boss))
        end
    end
    return missing
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
            char.killed = {}
        end
        LogInfo("Weekly reset detected, clearing kills")
        return true
    end
    LogDebug("No reset needed; next reset at %s", DB.lastResetAt and date("%c", DB.lastResetAt) or "unknown")
    return false
end

local mainFrame
local HideFrame

local function RefreshUI()
    if not mainFrame then
        LogDebug("RefreshUI called before main frame exists")
        return
    end
    if not mainFrame:IsShown() then
        LogDebug("RefreshUI skipped; frame hidden")
        return
    end
    LogDebug("Refreshing UI")
    UpdateCharacter()

    for _, line in ipairs(mainFrame.lines) do
        line:Hide()
    end
    wipe(mainFrame.lines)

    local index = 0
    for name, info in pairs(DB.chars) do
        if info.level and info.level >= 90 then
            local missing = GetMissingBosses(info)
            if DB.showAll or #missing > 0 then
                if #missing == 0 then
                    index = index + 1
                    local line = mainFrame.lines[index]
                    if not line then
                        line = AddTextToFrame(mainFrame.content, "", "TOPLEFT", 0, -(index - 1) * 20)
                        mainFrame.lines[index] = line
                    end
                    line:SetText(ColorizeName(name, info.class) .. " - done")
                else
                    for _, bossName in ipairs(missing) do
                        index = index + 1
                        local line = mainFrame.lines[index]
                        if not line then
                            line = AddTextToFrame(mainFrame.content, "", "TOPLEFT", 0, -(index - 1) * 20)
                            mainFrame.lines[index] = line
                        end
                        line:SetText(ColorizeName(name, info.class) .. " - " .. bossName)
                    end
                end
            end
        end
    end

    if DB.showAll then
        mainFrame.message:Hide()
    else
        if index == 0 then
            HideFrame()
            return
        else
            mainFrame.message:Hide()
        end
    end
    mainFrame.content:SetHeight(index * 20)

    local range = mainFrame.scrollFrame:GetVerticalScrollRange()
    if range == 0 then
        mainFrame.scrollFrame:SetVerticalScroll(0)
        mainFrame.scrollFrame.ScrollBar:Hide()
    else
        mainFrame.scrollFrame.ScrollBar:Show()
    end
    LogDebug("UI refresh complete (%d lines)", index)
end

local function ToggleFrame()
    if mainFrame:IsShown() then
        mainFrame:Hide()
        DB.frameShown = false
        LogInfo("Main frame hidden")
    else
        mainFrame:Show()
        DB.frameShown = true
        RefreshUI()
        LogInfo("Main frame shown")
    end
end

local function ShowFrame()
    if not mainFrame:IsShown() then
        mainFrame:Show()
        LogInfo("Main frame shown")
    end
    DB.frameShown = true
    RefreshUI()
end

function HideFrame()
    mainFrame:Hide()
    DB.frameShown = false
    LogInfo("Main frame hidden")
end

local function UpdateMinimapButton()
    if DB.minimap.hide then
        MoPWorldBossTrackerMinimapButton:Hide()
    else
        MoPWorldBossTrackerMinimapButton:Show()
    end
    LogDebug("Minimap button %s", DB.minimap.hide and "hidden" or "shown")
end

local function ToggleMinimapButton()
    DB.minimap.hide = not DB.minimap.hide
    UpdateMinimapButton()
    LogInfo("Minimap button %s", DB.minimap.hide and "hidden" or "shown")
end

local doUpdateTooltip

local function AddCharactersToTooltip(tooltip)
    local any
    for name, info in pairs(DB.chars) do
        if info.level and info.level >= 90 then
            local missing = GetMissingBosses(info)
            if DB.showAll or #missing > 0 then
                if #missing == 0 then
                    tooltip:AddLine(ColorizeName(name, info.class) .. " - done")
                else
                    for _, bossName in ipairs(missing) do
                        tooltip:AddLine(ColorizeName(name, info.class) .. " - " .. bossName)
                    end
                end
                any = true
            end
        end
    end
    if not any then
        tooltip:AddLine("All set for this week!")
    end
end

local function UpdateTooltip(tooltip, usingPanel)
    local _, relativeTo = tooltip:GetPoint()
    if doUpdateTooltip and (
        usingPanel or (relativeTo and relativeTo:GetName() == "MoPWorldBossTrackerMinimapButton")
    ) then
        tooltip:ClearLines()
        tooltip:AddLine("MoP World Boss Tracker")
        tooltip:AddLine(" ")
        AddCharactersToTooltip(tooltip)
        tooltip:AddLine(" ")
        tooltip:AddLine("|cFF9CD6DELeft-Click|r Toggle Frame")
        C_Timer.After(1, function() UpdateTooltip(tooltip, usingPanel) end)
    end
end

local function CreateMinimapButton()
    local button = CreateFrame("Button", "MoPWorldBossTrackerMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:SetPoint("TOPLEFT", Minimap, "TOPLEFT")

    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture("Interface\\AddOns\\MoPWorldBossTracker\\MopWorldBossTracker_icon.tga")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")

    button:SetScript("OnClick", function()
        ToggleFrame()
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_NONE")
        GameTooltip:SetPoint("TOPLEFT", self, "BOTTOMLEFT")
        doUpdateTooltip = true
        UpdateTooltip(GameTooltip, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        doUpdateTooltip = nil
        GameTooltip:Hide()
    end)

    UpdateMinimapButton()
end

local function LoadPosition()
    local pos = DB.framePos
    mainFrame:SetSize(pos.width or 300, pos.height or 200)
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
    DB.framePos.width = mainFrame:GetWidth()
    DB.framePos.height = mainFrame:GetHeight()
end

local function CreateMainFrame()
    mainFrame = CreateFrame("Frame", "MoPWorldBossTrackerFrame", UIParent, "BackdropTemplate")
    mainFrame:SetSize(300, 200)
    mainFrame:SetClampedToScreen(true)
    mainFrame:SetMovable(true)
    mainFrame:SetResizable(true)
    if mainFrame.SetResizeBounds then
        mainFrame:SetResizeBounds(200, 150)
    else
        mainFrame:SetMinResize(200, 150)
    end
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
    mainFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); SavePosition(); RefreshUI() end)
    mainFrame:SetScript("OnShow", RefreshUI)
    mainFrame:Hide()

    local title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", 0, -10)
    title:SetText("MoP World Boss Tracker")
    mainFrame.title = title

    local close = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -5, -5)
    close:SetScript("OnClick", HideFrame)

    local scrollFrame = CreateFrame("ScrollFrame", nil, mainFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 16, -32)
    scrollFrame:SetPoint("BOTTOMRIGHT", -16, 16)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(1, 1)
    scrollFrame:SetScrollChild(content)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local new = current - delta * 20
        if new < 0 then new = 0 end
        local range = self:GetVerticalScrollRange()
        if new > range then new = range end
        self:SetVerticalScroll(new)
    end)
    scrollFrame.ScrollBar:Hide()
    mainFrame.scrollFrame = scrollFrame
    mainFrame.content = content

    local resize = CreateFrame("Button", nil, mainFrame)
    resize:SetPoint("BOTTOMRIGHT")
    resize:SetSize(16, 16)
    resize:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resize:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resize:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resize:SetScript("OnMouseDown", function(self) self:GetParent():StartSizing("BOTTOMRIGHT") end)
    resize:SetScript("OnMouseUp", function(self) self:GetParent():StopMovingOrSizing(); SavePosition(); RefreshUI() end)

    mainFrame.lines = {}
    mainFrame.message = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mainFrame.message:SetPoint("TOP", 0, -10)
    mainFrame.message:SetText("All set for this week!")
    mainFrame.message:Hide()

    LoadPosition()
    if DB.frameShown then
        mainFrame:Show()
    end
end

local optionsPanel

local function CreateOptionsPanel()
    optionsPanel = CreateFrame("Frame", "MoPWBOptions")
    optionsPanel.name = "MoP World Boss Tracker"

    local general = CreateFrame("Frame", nil, optionsPanel)
    general:SetAllPoints()

    local bosses = CreateFrame("Frame", nil, optionsPanel)
    bosses:SetAllPoints()
    bosses:Hide()

    local tab1 = CreateFrame("Button", "$parentTab1", optionsPanel, "PanelTopTabButtonTemplate")
    tab1:SetText("General")
    tab1:SetID(1)
    tab1:SetPoint("BOTTOMLEFT", optionsPanel, "TOPLEFT", 0, 0)

    local tab2 = CreateFrame("Button", "$parentTab2", optionsPanel, "PanelTopTabButtonTemplate")
    tab2:SetText("Bosses")
    tab2:SetID(2)
    tab2:SetPoint("LEFT", tab1, "RIGHT", 10, 0)

    PanelTemplates_SetNumTabs(optionsPanel, 2)
    local function ShowTab(id)
        PanelTemplates_SetTab(optionsPanel, id)
        general:SetShown(id == 1)
        bosses:SetShown(id == 2)
    end
    tab1:SetScript("OnClick", function(self) ShowTab(self:GetID()) end)
    tab2:SetScript("OnClick", function(self) ShowTab(self:GetID()) end)
    ShowTab(1)

    local ltitle = general:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    ltitle:SetPoint("TOPLEFT", 16, -16)
    ltitle:SetText("Logging Level")

    local levels = {
        { text = "Errors", value = LOG_LEVEL.ERROR },
        { text = "Info", value = LOG_LEVEL.INFO },
        { text = "Debug", value = LOG_LEVEL.DEBUG },
    }

    local dropdown = CreateFrame("Frame", "MoPWBLogLevelDropdown", general, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", ltitle, "BOTTOMLEFT", -16, -8)

    UIDropDownMenu_Initialize(dropdown, function(self, level, menuList)
        local info
        for _, lvl in ipairs(levels) do
            info = UIDropDownMenu_CreateInfo()
            info.text = lvl.text
            info.value = lvl.value
            info.func = function(btn)
                DB.logLevel = btn.value
                UIDropDownMenu_SetSelectedValue(dropdown, btn.value)
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    UIDropDownMenu_SetSelectedValue(dropdown, DB.logLevel)
    for _, lvl in ipairs(levels) do
        if lvl.value == DB.logLevel then
            UIDropDownMenu_SetText(dropdown, lvl.text)
            break
        end
    end

    local title = bosses:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Track Bosses")

    local last = title
    for _, boss in ipairs(BOSSES) do
        local cb = CreateFrame("CheckButton", nil, bosses, "InterfaceOptionsCheckButtonTemplate")
        cb.Text = cb.Text or cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        cb.Text:SetPoint("LEFT", cb, "RIGHT", 0, 1)
        cb.Text:SetText(GetBossName(boss))
        cb:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -4)
        cb:SetChecked(DB.trackBosses[boss.questId] ~= false)
        cb:SetScript("OnClick", function(self)
            DB.trackBosses[boss.questId] = self:GetChecked() or false
            UpdateCharacter()
            RefreshUI()
        end)
        last = cb
    end

    if InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(optionsPanel)
    elseif Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(optionsPanel, optionsPanel.name)
        Settings.RegisterAddOnCategory(category)
    end
end

SLASH_MOPWB1 = "/mopwb"
SlashCmdList["MOPWB"] = function(msg)
    msg = msg and msg:lower() or ""
    LogDebug("Slash command: %s", msg)
    if msg == "show" then
        ShowFrame()
    elseif msg == "hide" then
        HideFrame()
    elseif msg == "minimap" then
        ToggleMinimapButton()
    elseif msg == "all" then
        DB.showAll = true
        LogInfo("Showing all characters")
        RefreshUI()
    elseif msg == "todo" then
        DB.showAll = false
        LogInfo("Showing incomplete characters")
        RefreshUI()
    elseif msg == "version" then
        local active = table.concat(GetActiveBossNames(), ", ")
        print(string.format("%s v%s - active bosses: %s", ADDON_NAME, ADDON_VERSION, active))
    elseif msg == "" then
        ToggleFrame()
    else
        LogError("Unknown command: %s", msg)
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ZONE_CHANGED")
eventFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")

local MAP_ID_PANDARIA = 424
local questEventRegistered

local function IsInPandaria()
    if not C_Map or not C_Map.GetBestMapForUnit then return false end
    local mapID = C_Map.GetBestMapForUnit("player")
    while mapID do
        local info = C_Map.GetMapInfo(mapID)
        if not info then break end
        if info.mapType == Enum.UIMapType.Continent then
            return info.mapID == MAP_ID_PANDARIA
        end
        mapID = info.parentMapID
    end
    return false
end

local function UpdateQuestListener()
    if IsInPandaria() then
        if not questEventRegistered then
            eventFrame:RegisterEvent("QUEST_TURNED_IN")
            questEventRegistered = true
        end
    elseif questEventRegistered then
        eventFrame:UnregisterEvent("QUEST_TURNED_IN")
        questEventRegistered = false
    end
end

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        EnsureDefaults()
        CreateMainFrame()
        CreateMinimapButton()
        CreateOptionsPanel()
        CheckReset()
        UpdateCharacter()
        UpdateQuestListener()
        LogInfo("%s v%s loaded", ADDON_NAME, ADDON_VERSION)
    elseif event == "PLAYER_ENTERING_WORLD" then
        CheckReset()
        UpdateCharacter()
        UpdateQuestListener()
        if DB.frameShown then
            ShowFrame()
        else
            RefreshUI()
        end
    elseif event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" or event == "ZONE_CHANGED_NEW_AREA" then
        UpdateQuestListener()
    elseif event == "QUEST_TURNED_IN" then
        local questID = ...
        if DB.trackBosses[questID] ~= false then
            UpdateCharacter()
            RefreshUI()
        end
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
