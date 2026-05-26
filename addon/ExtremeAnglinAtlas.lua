local _, ExtremeAnglinAtlas = ...

local DATA = ExtremeAnglinAtlasData or { zones = {} }
local FISH_PAGE_SIZE = 16
local fishPage = 1
local searchMode = "region"
local searchText = ""
local selectedFishKey
local selectedCategory
local selectedZoneIndex = 1
local fishIndex
local fishByKey
local frame
local updateModeControls

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

local function lowerText(value)
    return string.lower(value or "")
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

local function zoneCategoryOrder(category)
    for index, orderedCategory in ipairs(ZONE_CATEGORY_ORDER) do
        if orderedCategory == category then
            return index
        end
    end

    return #ZONE_CATEGORY_ORDER + 1
end

local function fishKey(fish)
    if fish.itemId then
        return "item:" .. fish.itemId
    end

    return "name:" .. lowerText(fish.itemName)
end

local function buildFishIndex()
    if fishIndex then
        return
    end

    fishIndex = {}
    fishByKey = {}

    for zoneIndex, zone in ipairs(DATA.zones or {}) do
        local seenInZone = {}

        for _, fish in ipairs(zone.fish or {}) do
            local key = fishKey(fish)

            if not seenInZone[key] then
                local entry = fishByKey[key]

                if not entry then
                    entry = {
                        key = key,
                        itemId = fish.itemId,
                        itemName = fish.itemName,
                        zones = {},
                    }
                    fishByKey[key] = entry
                    table.insert(fishIndex, entry)
                end

                table.insert(entry.zones, {
                    zoneIndex = zoneIndex,
                    zoneName = zone.name,
                    category = zoneCategory(zone),
                    minSkill = fish.minSkill,
                    maxSkill = fish.maxSkill,
                })
                seenInZone[key] = true
            end
        end
    end

    for _, entry in ipairs(fishIndex) do
        table.sort(entry.zones, function(left, right)
            local leftOrder = zoneCategoryOrder(left.category)
            local rightOrder = zoneCategoryOrder(right.category)

            if leftOrder ~= rightOrder then
                return leftOrder < rightOrder
            end

            return left.zoneName < right.zoneName
        end)
    end

    table.sort(fishIndex, function(left, right)
        return left.itemName < right.itemName
    end)
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
    local name, quality, texture

    if itemId then
        name, _, quality, _, _, _, _, _, _, texture = GetItemInfo(itemId)
    end

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

local function updatePagerText(rowTotal)
    local fishPages = math.max(1, math.ceil(rowTotal / FISH_PAGE_SIZE))

    frame.fishPager:SetText(fishPage .. " / " .. fishPages)
end

local function fishSearchRows()
    local rows = {}
    local query = lowerText(searchText)

    buildFishIndex()

    if query == "" then
        return rows
    end

    for _, entry in ipairs(fishIndex) do
        if lowerText(entry.itemName):find(query, 1, true) then
            table.insert(rows, {
                kind = "fishResult",
                fishKey = entry.key,
                itemId = entry.itemId,
                itemName = entry.itemName,
                zoneCount = countRows(entry.zones),
            })
        end
    end

    return rows
end

local function selectedFishZoneRows()
    local rows = {}

    buildFishIndex()

    local entry = fishByKey and fishByKey[selectedFishKey] or nil
    if not entry then
        return rows
    end

    for _, zone in ipairs(entry.zones) do
        table.insert(rows, {
            kind = "fishZone",
            zoneIndex = zone.zoneIndex,
            zoneName = zone.zoneName,
            category = zone.category,
            itemId = entry.itemId,
            itemName = entry.itemName,
            minSkill = zone.minSkill,
            maxSkill = zone.maxSkill,
        })
    end

    return rows
end

local function currentZoneRows()
    local rows = {}
    local selectedZone = getSelectedZone()

    for _, fish in ipairs((selectedZone and selectedZone.fish) or {}) do
        table.insert(rows, {
            kind = "zoneFish",
            fishKey = fishKey(fish),
            itemId = fish.itemId,
            itemName = fish.itemName,
            minSkill = fish.minSkill,
            maxSkill = fish.maxSkill,
        })
    end

    return rows
end

local function activeRows()
    if selectedFishKey then
        return selectedFishZoneRows()
    end

    if searchMode == "fish" then
        return fishSearchRows()
    end

    return currentZoneRows()
end

local function updateFishList()
    local selectedZone = getSelectedZone()
    local rows = activeRows()
    local rowTotal = countRows(rows)
    local startIndex = ((fishPage - 1) * FISH_PAGE_SIZE) + 1

    if selectedFishKey then
        local entry = fishByKey and fishByKey[selectedFishKey] or nil
        frame.zoneTitle:SetFontObject(frame.zoneTitleLargeFont)
        frame.zoneTitle:SetText(entry and entry.itemName or "Fish not found")
        frame.rightHeader:SetText("Skill")
        frame.backButton:Show()
    elseif searchMode == "fish" then
        frame.zoneTitle:SetFontObject(frame.zoneTitleSmallFont)
        frame.zoneTitle:SetText("Search Results")
        frame.rightHeader:SetText("Zones")
        frame.backButton:Hide()
    else
        frame.zoneTitle:SetFontObject(frame.zoneTitleLargeFont)
        frame.zoneTitle:SetText(selectedZone and selectedZone.name or "No zone selected")
        frame.rightHeader:SetText("Skill")
        frame.backButton:Hide()
    end

    for rowIndex = 1, FISH_PAGE_SIZE do
        local row = frame.rows[rowIndex]
        local data = rows[startIndex + rowIndex - 1]

        if data then
            local display = itemDisplayInfo(data.itemId, data.itemName)
            row.kind = data.kind
            row.fishKey = data.fishKey
            row.zoneIndex = data.zoneIndex
            row.itemId = data.itemId
            row.itemName = data.itemName
            row.icon:SetTexture(display.texture)

            if data.kind == "fishResult" then
                row.name:SetText(display.color .. display.name .. "|r")
                row.skill:SetText(tostring(data.zoneCount))
            elseif data.kind == "fishZone" then
                row.name:SetText(data.zoneName)
                row.skill:SetText(skillText(data))
            else
                row.name:SetText(display.color .. display.name .. "|r")
                row.skill:SetText(skillText(data))
            end

            row:Show()
        else
            row.kind = nil
            row.fishKey = nil
            row.zoneIndex = nil
            row.itemId = nil
            row.itemName = nil
            row:Hide()
        end
    end

    if rowTotal == 0 then
        if selectedFishKey then
            frame.emptyText:SetText("No zones found")
        elseif searchMode == "fish" and searchText == "" then
            frame.emptyText:SetText("Type a fish name")
        elseif searchMode == "fish" then
            frame.emptyText:SetText("No fish found")
        else
            frame.emptyText:SetText("No fish listed")
        end
        frame.emptyText:Show()
    else
        frame.emptyText:Hide()
    end

    updatePagerText(rowTotal)
end

local function setZone(index)
    selectedZoneIndex = index
    fishPage = 1
    selectedFishKey = nil

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

local function setSearchMode(mode)
    searchMode = mode
    selectedFishKey = nil
    fishPage = 1

    if frame and frame.searchBox then
        frame.searchBox:ClearFocus()
    end

    if updateModeControls then
        updateModeControls()
    end

    updateFishList()
end

local function setCategory(category)
    selectedCategory = category
    ensureSelectedZoneForCategory()
    setZone(selectedZoneIndex)
end

local function changeFishPage(delta)
    local fishPages = math.max(1, math.ceil(countRows(activeRows()) / FISH_PAGE_SIZE))
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

local function setVisible(element, visible)
    if visible then
        element:Show()
    else
        element:Hide()
    end
end

updateModeControls = function()
    if not frame then
        return
    end

    local fishMode = searchMode == "fish"

    setVisible(frame.searchLabel, fishMode)
    setVisible(frame.searchBox, fishMode)
    setVisible(frame.regionLabel, not fishMode)
    setVisible(frame.zoneLabel, not fishMode)
    setVisible(frame.regionDropdown, not fishMode)
    setVisible(frame.zoneDropdown, not fishMode)

    if fishMode then
        frame.regionModeButton:UnlockHighlight()
        frame.fishModeButton:LockHighlight()
    else
        frame.regionModeButton:LockHighlight()
        frame.fishModeButton:UnlockHighlight()
    end
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
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 28, -202 - ((index - 1) * 22))
    row:EnableMouse(true)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetWidth(18)
    row.icon:SetHeight(18)
    row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.name = createText(row, "ARTWORK", "GameFontHighlightSmall", "", "LEFT", row.icon, "RIGHT", 8, 0)
    row.name:SetWidth(430)
    row.name:SetJustifyH("LEFT")
    row.skill = createText(row, "ARTWORK", "GameFontHighlightSmall", "", "RIGHT", row, "RIGHT", 0, 0)

    row:SetScript("OnClick", function(self)
        if (self.kind == "fishResult" or self.kind == "zoneFish") and self.fishKey then
            selectedFishKey = self.fishKey
            fishPage = 1
            updateFishList()
        elseif self.kind == "fishZone" and self.zoneIndex then
            searchMode = "region"
            setZone(self.zoneIndex)
            updateModeControls()
        end
    end)
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
    frame:SetHeight(610)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
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
    frame:SetScript("OnHide", function()
        if frame.searchBox then
            frame.searchBox:ClearFocus()
        end
    end)
    frame:Hide()
    frame.rows = {}
    table.insert(UISpecialFrames, "ExtremeAnglinAtlasFrame")

    createText(frame, "ARTWORK", "GameFontNormalLarge", "Extreme Anglin' Atlas", "TOPLEFT", frame, "TOPLEFT", 24, -22)

    local close = createButton(frame, "Close", 72, 22, "TOPRIGHT", frame, "TOPRIGHT", -22, -20)
    close:SetScript("OnClick", function()
        frame:Hide()
    end)

    frame.regionModeButton = createButton(frame, "By Region", 96, 22, "TOPLEFT", frame, "TOPLEFT", 28, -58)
    frame.regionModeButton:SetScript("OnClick", function()
        setSearchMode("region")
    end)
    frame.fishModeButton = createButton(frame, "By Fish", 96, 22, "TOPLEFT", frame, "TOPLEFT", 132, -58)
    frame.fishModeButton:SetScript("OnClick", function()
        setSearchMode("fish")
    end)

    frame.searchLabel = createText(frame, "ARTWORK", "GameFontNormalLarge", "Fish Search", "TOPLEFT", frame, "TOPLEFT", 28, -96)
    frame.searchBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    frame.searchBox:SetWidth(488)
    frame.searchBox:SetHeight(20)
    frame.searchBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 36, -118)
    frame.searchBox:SetAutoFocus(false)
    frame.searchBox:SetScript("OnTextChanged", function(self)
        searchText = self:GetText() or ""
        selectedFishKey = nil
        fishPage = 1
        updateFishList()
    end)
    frame.searchBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)
    frame.searchBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        frame:Hide()
    end)

    frame.regionLabel = createText(frame, "ARTWORK", "GameFontNormal", "Region", "TOPLEFT", frame, "TOPLEFT", 28, -96)
    frame.zoneLabel = createText(frame, "ARTWORK", "GameFontNormal", "Zone", "TOPLEFT", frame, "TOPLEFT", 310, -96)

    frame.regionDropdown = CreateFrame("Frame", "ExtremeAnglinAtlasRegionDropDown", frame, "UIDropDownMenuTemplate")
    frame.regionDropdown:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -122)
    UIDropDownMenu_SetWidth(frame.regionDropdown, 230)
    UIDropDownMenu_Initialize(frame.regionDropdown, initializeRegionDropdown)

    frame.zoneDropdown = CreateFrame("Frame", "ExtremeAnglinAtlasZoneDropDown", frame, "UIDropDownMenuTemplate")
    frame.zoneDropdown:SetPoint("TOPLEFT", frame, "TOPLEFT", 294, -122)
    UIDropDownMenu_SetWidth(frame.zoneDropdown, 230)
    UIDropDownMenu_Initialize(frame.zoneDropdown, initializeZoneDropdown)

    frame.zoneTitle = createText(frame, "ARTWORK", "GameFontNormalLarge", "", "TOPLEFT", frame, "TOPLEFT", 28, -176)
    frame.zoneTitleLargeFont = _G.GameFontNormalLarge
    frame.zoneTitleSmallFont = _G.GameFontNormal
    frame.rightHeader = createText(frame, "ARTWORK", "GameFontNormalSmall", "Skill", "TOPRIGHT", frame, "TOPRIGHT", -36, -176)
    frame.backButton = createButton(frame, "Back", 60, 22, "TOPRIGHT", frame, "TOPRIGHT", -116, -170)
    frame.backButton:SetScript("OnClick", function()
        selectedFishKey = nil
        fishPage = 1
        updateFishList()
    end)
    frame.backButton:Hide()
    frame.emptyText = createText(frame, "ARTWORK", "GameFontDisable", "", "TOPLEFT", frame, "TOPLEFT", 28, -206)
    frame.emptyText:Hide()
    updateModeControls()

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
