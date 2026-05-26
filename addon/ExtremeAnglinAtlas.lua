local _, ExtremeAnglinAtlas = ...

local DATA = ExtremeAnglinAtlasData or { zones = {} }
local FISH_PAGE_SIZE = 16
local fishPage = 1
local selectedCategory
local selectedZoneIndex = 1
local frame

local DEFAULT_ITEM_ICON = "Interface\\Icons\\INV_Misc_Fish_14"
local ZONE_CATEGORY_ORDER = {
    "Eastern Kingdoms",
    "Kalimdor",
    "Outland",
    "Other",
}

local function countRows(rows)
    return rows and #rows or 0
end

local function getZone(index)
    return DATA.zones and DATA.zones[index] or nil
end

local function getSelectedZone()
    return getZone(selectedZoneIndex)
end

local function zoneCategory(zone)
    return zone and zone.category or "Other"
end

local function categoryHasZones(category)
    for _, zone in ipairs(DATA.zones or {}) do
        if zoneCategory(zone) == category then
            return true
        end
    end

    return false
end

local function selectedZoneMatchesCategory()
    local zone = getSelectedZone()
    return zone and zoneCategory(zone) == selectedCategory
end

local function firstZoneIndexForCategory(category)
    for index, zone in ipairs(DATA.zones or {}) do
        if zoneCategory(zone) == category then
            return index
        end
    end

    return nil
end

local function firstCategory()
    for _, category in ipairs(ZONE_CATEGORY_ORDER) do
        if categoryHasZones(category) then
            return category
        end
    end

    local firstZone = getZone(1)
    return zoneCategory(firstZone)
end

local function ensureSelectedZoneForCategory()
    if not selectedZoneMatchesCategory() then
        selectedZoneIndex = firstZoneIndexForCategory(selectedCategory) or selectedZoneIndex
    end
end

local function itemQualityColor(quality)
    local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality or 1] or nil

    if color and color.hex then
        return color.hex
    end

    if color and color.r and color.g and color.b then
        return string.format(
            "|cff%02x%02x%02x",
            math.floor((color.r * 255) + 0.5),
            math.floor((color.g * 255) + 0.5),
            math.floor((color.b * 255) + 0.5)
        )
    end

    return "|cffffffff"
end

local function itemDisplayInfo(itemId, itemName)
    local name, _, quality, _, _, _, _, _, _, texture = GetItemInfo(itemId)

    return {
        name = name or itemName or ("Item " .. tostring(itemId)),
        color = itemQualityColor(quality),
        texture = texture or DEFAULT_ITEM_ICON,
    }
end

local function skillText(fish)
    if fish.minSkill and fish.maxSkill then
        return fish.minSkill .. " - " .. fish.maxSkill
    end

    if fish.minSkill then
        return tostring(fish.minSkill)
    end

    return "-"
end

local function updatePagerText()
    local selectedZone = getSelectedZone()
    local fishTotal = selectedZone and countRows(selectedZone.fish) or 0
    local fishPages = math.max(1, math.ceil(fishTotal / FISH_PAGE_SIZE))

    frame.fishPager:SetText(fishPage .. " / " .. fishPages)
end

local function updateFishList()
    local selectedZone = getSelectedZone()
    local fishList = selectedZone and selectedZone.fish or {}
    local startIndex = ((fishPage - 1) * FISH_PAGE_SIZE) + 1

    frame.zoneTitle:SetText(selectedZone and selectedZone.name or "No zone selected")

    for rowIndex = 1, FISH_PAGE_SIZE do
        local row = frame.rows[rowIndex]
        local fish = fishList[startIndex + rowIndex - 1]

        if fish then
            local display = itemDisplayInfo(fish.itemId, fish.itemName)
            row.itemId = fish.itemId
            row.itemName = fish.itemName
            row.name:SetText(display.color .. display.name .. "|r")
            row.icon:SetTexture(display.texture)
            row.skill:SetText(skillText(fish))
            row:Show()
        else
            row.itemId = nil
            row.itemName = nil
            row:Hide()
        end
    end

    updatePagerText()
end

local function setZone(index)
    selectedZoneIndex = index
    fishPage = 1
    local zone = getSelectedZone()
    selectedCategory = zoneCategory(zone)

    if frame and frame.regionDropdown then
        UIDropDownMenu_SetText(frame.regionDropdown, selectedCategory or "Select region")
    end

    if frame and frame.zoneDropdown then
        UIDropDownMenu_SetText(frame.zoneDropdown, zone and zone.name or "Select zone")
    end

    updateFishList()
end

local function setCategory(category)
    selectedCategory = category
    ensureSelectedZoneForCategory()
    setZone(selectedZoneIndex)
end

local function changeFishPage(delta)
    local selectedZone = getSelectedZone()
    local fishTotal = selectedZone and countRows(selectedZone.fish) or 0
    local fishPages = math.max(1, math.ceil(fishTotal / FISH_PAGE_SIZE))
    fishPage = math.min(fishPages, math.max(1, fishPage + delta))
    updateFishList()
end

local function createText(parent, layer, template, text, point, relativeTo, relativePoint, x, y)
    local fontString = parent:CreateFontString(nil, layer, template)
    fontString:SetPoint(point, relativeTo, relativePoint, x, y)
    fontString:SetText(text)
    return fontString
end

local function createButton(parent, text, width, height, point, relativeTo, relativePoint, x, y)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetWidth(width)
    button:SetHeight(height)
    button:SetPoint(point, relativeTo, relativePoint, x, y)
    button:SetText(text)
    return button
end

local function initializeRegionDropdown()
    for _, category in ipairs(ZONE_CATEGORY_ORDER) do
        if categoryHasZones(category) then
            local info = UIDropDownMenu_CreateInfo()
            info.text = category
            info.value = category
            info.func = function(self)
                setCategory(self.value)
            end
            info.checked = category == selectedCategory
            UIDropDownMenu_AddButton(info)
        end
    end
end

local function initializeZoneDropdown()
    for index, zone in ipairs(DATA.zones or {}) do
        if zoneCategory(zone) == selectedCategory then
            local info = UIDropDownMenu_CreateInfo()
            info.text = zone.name
            info.value = index
            info.func = function(self)
                setZone(self.value)
            end
            info.checked = index == selectedZoneIndex
            UIDropDownMenu_AddButton(info)
        end
    end
end

local function createFishRow(parent, index)
    local row = CreateFrame("Button", nil, parent)
    row:SetWidth(560)
    row:SetHeight(22)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 28, -152 - ((index - 1) * 22))
    row:EnableMouse(true)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetWidth(18)
    row.icon:SetHeight(18)
    row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.name = createText(row, "ARTWORK", "GameFontHighlightSmall", "", "LEFT", row.icon, "RIGHT", 8, 0)
    row.skill = createText(row, "ARTWORK", "GameFontHighlightSmall", "", "RIGHT", row, "RIGHT", 0, 0)

    row:SetScript("OnEnter", function(self)
        if not self.itemId then
            return
        end

        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink("item:" .. self.itemId .. ":0:0:0:0:0:0:0")
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    return row
end

local function createFrame()
    -- BackdropTemplate is required for SetBackdrop on Classic clients.
    frame = CreateFrame("Frame", "ExtremeAnglinAtlasFrame", UIParent, "BackdropTemplate")
    frame:SetWidth(620)
    frame:SetHeight(540)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()
    frame.rows = {}

    createText(frame, "ARTWORK", "GameFontNormalLarge", "Extreme Anglin' Atlas", "TOPLEFT", frame, "TOPLEFT", 24, -22)
    createText(frame, "ARTWORK", "GameFontNormal", "Region", "TOPLEFT", frame, "TOPLEFT", 28, -58)
    createText(frame, "ARTWORK", "GameFontNormal", "Zone", "TOPLEFT", frame, "TOPLEFT", 310, -58)

    local close = createButton(frame, "Close", 72, 22, "TOPRIGHT", frame, "TOPRIGHT", -22, -20)
    close:SetScript("OnClick", function()
        frame:Hide()
    end)

    frame.regionDropdown = CreateFrame("Frame", "ExtremeAnglinAtlasRegionDropDown", frame, "UIDropDownMenuTemplate")
    frame.regionDropdown:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -84)
    UIDropDownMenu_SetWidth(frame.regionDropdown, 230)
    UIDropDownMenu_Initialize(frame.regionDropdown, initializeRegionDropdown)

    frame.zoneDropdown = CreateFrame("Frame", "ExtremeAnglinAtlasZoneDropDown", frame, "UIDropDownMenuTemplate")
    frame.zoneDropdown:SetPoint("TOPLEFT", frame, "TOPLEFT", 294, -84)
    UIDropDownMenu_SetWidth(frame.zoneDropdown, 230)
    UIDropDownMenu_Initialize(frame.zoneDropdown, initializeZoneDropdown)

    frame.zoneTitle = createText(frame, "ARTWORK", "GameFontNormalLarge", "", "TOPLEFT", frame, "TOPLEFT", 28, -126)
    createText(frame, "ARTWORK", "GameFontNormalSmall", "Skill", "TOPRIGHT", frame, "TOPRIGHT", -36, -126)

    for index = 1, FISH_PAGE_SIZE do
        frame.rows[index] = createFishRow(frame, index)
    end

    frame.fishPager = createText(frame, "ARTWORK", "GameFontHighlightSmall", "", "BOTTOMRIGHT", frame, "BOTTOMRIGHT", -116, 28)
    local fishPrev = createButton(frame, "<", 34, 22, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", -166, 22)
    local fishNext = createButton(frame, ">", 34, 22, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", -36, 22)
    fishPrev:SetScript("OnClick", function() changeFishPage(-1) end)
    fishNext:SetScript("OnClick", function() changeFishPage(1) end)
end

function ExtremeAnglinAtlas.Toggle()
    if not frame then
        createFrame()
    end

    if frame:IsShown() then
        frame:Hide()
    else
        selectedCategory = selectedCategory or firstCategory()
        ensureSelectedZoneForCategory()
        setZone(selectedZoneIndex)
        frame:Show()
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
eventFrame:SetScript("OnEvent", function(_, event)
    -- Item names, icons, and quality colors can arrive after the first paint.
    if event == "GET_ITEM_INFO_RECEIVED" and frame and frame:IsShown() then
        updateFishList()
    end
end)

SLASH_EXTREMEANGLINATLAS1 = "/extremeanglinatlas"
SLASH_EXTREMEANGLINATLAS2 = "/eaa"
SlashCmdList.EXTREMEANGLINATLAS = function()
    ExtremeAnglinAtlas.Toggle()
end
