
local ADDON_NAME = ...

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

local function GetBossName(boss)
    if not boss.name and C_QuestLog and C_QuestLog.GetTitleForQuestID then
        boss.name = C_QuestLog.GetTitleForQuestID(boss.questId)
    end
    if not boss.name then
        boss.name = "Unknown"
    end
    return boss.name
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

local DB

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
    for _, boss in ipairs(BOSSES) do
        if DB.trackBosses[boss.questId] == nil then
            DB.trackBosses[boss.questId] = true
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
        if info.level and info.level >= 90 then
            local missing = GetMissingBosses(info)
            if DB.showAll or #missing > 0 then
                if #missing == 0 then
                    index = index + 1
                    local line = mainFrame.lines[index]
                    if not line then
                        line = mainFrame.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                        mainFrame.lines[index] = line
                        line:SetPoint("TOPLEFT", 0, -(index - 1) * 20)
                        line:SetPoint("RIGHT")
                    end
                    line:SetText(ColorizeName(name, info.class) .. " - done")
                    line:Show()
                else
                    for _, bossName in ipairs(missing) do
                        index = index + 1
                        local line = mainFrame.lines[index]
                        if not line then
                            line = mainFrame.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                            mainFrame.lines[index] = line
                            line:SetPoint("TOPLEFT", 0, -(index - 1) * 20)
                            line:SetPoint("RIGHT")
                        end
                        line:SetText(ColorizeName(name, info.class) .. " - " .. bossName)
                        line:Show()
                    end
                end
            end
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

    local range = mainFrame.scrollFrame:GetVerticalScrollRange()
    if range == 0 then
        mainFrame.scrollFrame:SetVerticalScroll(0)
        mainFrame.scrollFrame.ScrollBar:Hide()
    else
        mainFrame.scrollFrame.ScrollBar:Show()
    end
end

local function ToggleFrame()
    if mainFrame:IsShown() then
        mainFrame:Hide()
        DB.frameShown = false
    else
        mainFrame:Show()
        DB.frameShown = true
        RefreshUI()
    end
end

local function ShowFrame()
    if not mainFrame:IsShown() then
        mainFrame:Show()
    end
    DB.frameShown = true
    RefreshUI()
end

local function HideFrame()
    mainFrame:Hide()
    DB.frameShown = false
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
    optionsPanel = CreateFrame("Frame")
    optionsPanel.name = "MoP World Boss Tracker"

    local title = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("MoP World Boss Tracker")

    local subtitle = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetText("Select bosses to track:")

    local last = subtitle
    for _, boss in ipairs(BOSSES) do
        local cb = CreateFrame("CheckButton", nil, optionsPanel, "InterfaceOptionsCheckButtonTemplate")
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
        CreateOptionsPanel()
        CheckReset()
        UpdateCharacter()
    elseif event == "PLAYER_ENTERING_WORLD" then
        CheckReset()
        UpdateCharacter()
        if DB.frameShown then
            ShowFrame()
        else
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
