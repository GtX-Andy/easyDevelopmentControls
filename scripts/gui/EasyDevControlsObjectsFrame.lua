--[[
Copyright (C) GtX (Andy), 2019

Author: GtX | Andy
Date: 07.04.2019
Revision: FS22-02

Contact:
https://forum.giants-software.com
https://github.com/GtX-Andy

Important:
Not to be added to any mods / maps or modified from its current release form.
No modifications may be made to this script, including conversion to other game versions without written permission from GtX | Andy

Darf nicht zu Mods / Maps hinzugefügt oder von der aktuellen Release-Form geändert werden.
Ohne schriftliche Genehmigung von GtX | Andy dürfen keine Änderungen an diesem Skript vorgenommen werden, einschließlich der Konvertierung in andere Spielversionen
]]

EasyDevControlsObjectsFrame = {}

local EasyDevControlsObjectsFrame_mt = Class(EasyDevControlsObjectsFrame, EasyDevControlsBaseFrame)
local EMPTY_TABLE = {}

local function getRangeTable(maxValue)
    local rangeTable = {}

    for i = 1, (maxValue or 25) do
        rangeTable[i] = i
    end

    return rangeTable
end

EasyDevControlsObjectsFrame.BALE_TYPE_SQUARE = 1
EasyDevControlsObjectsFrame.BALE_TYPE_ROUND = 2

EasyDevControlsObjectsFrame.BALE_UNWRAPPED = 1
EasyDevControlsObjectsFrame.BALE_WRAPPED = 2

EasyDevControlsObjectsFrame.PALLETS_FARM = 1
EasyDevControlsObjectsFrame.PALLETS_GENERAL = 2
EasyDevControlsObjectsFrame.PALLETS_CROPS = 3
EasyDevControlsObjectsFrame.PALLETS_ALL = 4

EasyDevControlsObjectsFrame.REMOVE_ALL_TYPES = {
    BALES = {
        id = EasyDevControlsRemoveAllObjectsEvent.BALES,
        nameI18N = "easyDevControls_typeBales"
    },
    PALLETS = {
        id = EasyDevControlsRemoveAllObjectsEvent.PALLETS,
        nameI18N = "easyDevControls_typePallets"
    },
    LOGS = {
        id = EasyDevControlsRemoveAllObjectsEvent.LOGS,
        nameI18N = "easyDevControls_typeLogs"
    },
    STUMPS = {
        id = EasyDevControlsRemoveAllObjectsEvent.STUMPS,
        nameI18N = "easyDevControls_typeStumps"
    }
}

EasyDevControlsObjectsFrame.TIP_LENGTHS = getRangeTable(100)
EasyDevControlsObjectsFrame.CLEAR_RADIUS = getRangeTable(100)

EasyDevControlsObjectsFrame.L10N_SYMBOL = {}

EasyDevControlsObjectsFrame.CONTROLS = {
    "multiBaleType",
    "multiBaleSize",
    "multiBaleFillType",
    "multiBaleWrapState",
    "buttonConfirmBale",
    "buttonBaleList",
    "buttonBalesFermenting",
    "checkedShowBaleLocations",
    "checkedShowPalletLocations",
    "multiPalletCategory",
    "multiPalletFillType",
    "buttonConfirmPallet",
    "multiLogType",
    "multiLogLength",
    "buttonConfirmLog",
    "multiOptionTipToTriggerFillType",
    "multiTipToTriggerState",
    "textInputTipToTriggerAmount",
    "buttonConfirmTipToTrigger",
    "multiTipAnywhereFillType",
    "multiTipAnywhereLength",
    "textInputTipAnywhereAmount",
    "buttonConfirmTipAnywhere",
    "multiClearTipAnywhereFillType",
    "multiClearTipAnywhereState",
    "multiClearTipAnywhereArea",
    "buttonConfirmClearTipAnywhere",
    "checkedShowTipCollisions",
    "buttonConfirmRemoveAllBales",
    "buttonConfirmRemoveAllPallets",
    "buttonConfirmRemoveAllLogs",
    "buttonConfirmRemoveAllStumps"
}

function EasyDevControlsObjectsFrame.new(ui, easyDevControls, accessLevel)
    local self = EasyDevControlsBaseFrame.new(EasyDevControlsObjectsFrame_mt, ui, easyDevControls, accessLevel)

    self:registerControls(EasyDevControlsObjectsFrame.CONTROLS)

    return self
end

function EasyDevControlsObjectsFrame:initialize()
    self.multiBaleType:setTexts({
        EasyDevUtils.getText("easyDevControls_square"),
        EasyDevUtils.getText("easyDevControls_round")
    })

    self.multiBaleWrapState:setTexts({
        EasyDevUtils.getText("easyDevControls_unwrapped"),
        EasyDevUtils.getText("easyDevControls_wrapped")
    })

    self.multiTipToTriggerState:setTexts({
        EasyDevUtils.getText("easyDevControls_fill"),
        EasyDevUtils.getText("easyDevControls_empty"),
        EasyDevUtils.getText("easyDevControls_set")
    })

    self:collectBaleTypeData(true)
    self:collectPalletTypeData(true)
    self:collectTreeTypeData(true)

    local fieldNumberText = g_i18n:getText("fieldJob_number")
    local allText = EasyDevUtils.getText("easyDevControls_all")
    local radiusText = EasyDevUtils.getText("easyDevControls_radius")

    local tipAnywhereFillTypeTexts = {}

    local clearTipAnywhereFillTypeTexts = {
        allText
    }

    local clearTipAnywhereStateTexts = {
        radiusText
    }

    local tipAnywhereLengthTexts = {}
    local clearTipAnywhereFieldTexts = {}
    local clearTipAnywhereRadiusTexts = {}

    self.tipAnywhereFillTypes = {}

    self.clearTipAnywhereFillTypes = {
        FillType.UNKNOWN
    }

    for _, heightType in ipairs (g_densityMapHeightManager:getDensityMapHeightTypes()) do
        if heightType.fillTypeIndex ~= FillType.TARP then
            local fillTypeTitle = EasyDevUtils.getFillTypeTitle(heightType.fillTypeIndex)

            table.insert(tipAnywhereFillTypeTexts, fillTypeTitle)
            table.insert(self.tipAnywhereFillTypes, heightType.fillTypeIndex)

            table.insert(clearTipAnywhereFillTypeTexts, fillTypeTitle)
            table.insert(self.clearTipAnywhereFillTypes, heightType.fillTypeIndex)
        end
    end

    for i = 1, #EasyDevControlsObjectsFrame.TIP_LENGTHS do
        table.insert(tipAnywhereLengthTexts, string.format("%i m", EasyDevControlsObjectsFrame.TIP_LENGTHS[i]))
    end

    self.multiTipAnywhereFillType:setTexts(tipAnywhereFillTypeTexts)
    self.multiTipAnywhereLength:setTexts(tipAnywhereLengthTexts)

    for i, _ in ipairs (g_fieldManager:getFields()) do
        clearTipAnywhereFieldTexts[i] = string.format(fieldNumberText, i)
    end

    local numFieldTexts = #clearTipAnywhereFieldTexts + 1

    clearTipAnywhereFieldTexts[numFieldTexts] = allText

    for i = 1, #EasyDevControlsObjectsFrame.CLEAR_RADIUS do
        table.insert(clearTipAnywhereRadiusTexts, string.format("%i m", EasyDevControlsObjectsFrame.CLEAR_RADIUS[i]))
    end

    self.clearTipAnywhereStates = {
        {
            texts = clearTipAnywhereRadiusTexts,
            maxIndex = #clearTipAnywhereRadiusTexts,
            lastIndex = 1,
            disabled = false
        },
        {
            texts = clearTipAnywhereFieldTexts,
            maxIndex = numFieldTexts,
            lastIndex = numFieldTexts,
            disabled = numFieldTexts == 1
        },
        {
            texts = {g_i18n:getText("ui_map")},
            maxIndex = 1,
            lastIndex = 1,
            disabled = true
        }
    }

    self.multiClearTipAnywhereFillType:setTexts(clearTipAnywhereFillTypeTexts)

    self.multiClearTipAnywhereState:setTexts({
        radiusText,
        g_i18n:getText("ui_fields"),
        g_i18n:getText("ui_map")
    })

    self.multiClearTipAnywhereArea:setTexts(clearTipAnywhereRadiusTexts)
end

function EasyDevControlsObjectsFrame:subscribeToMessages(messageCenter)
    messageCenter:subscribe(EasyDevUtils.MESSAGE_TYPE_SETTINGS_CHANGED, self.onSettingChanged, self)
end

function EasyDevControlsObjectsFrame:updateAvailableProperties()
    local x, y, z, dirX, dirZ, player, controlledVehicle = EasyDevUtils.getPlayerWorldLocation()
    local isServer = g_server ~= nil

    -- Add Bale
    local addBaleDisabled = self:getIsPropertyDisabled("addBale")
    local baleTypeIndex = self.baleTypeIndex or 1
    local baleSizeIndex = self.baleSizeIndex or 1
    local baleFillTypeIndex = self.baleFillTypeIndex or 1

    self:collectBaleTypeData()

    self.addBaleDisabled = addBaleDisabled
    self.baleWrapStateIndex = self.multiBaleWrapState:getState()

    self.multiBaleType:setState(baleTypeIndex)
    self.multiBaleType:setDisabled(addBaleDisabled)

    self.multiBaleSize:setTexts(self.baleSizeTexts[baleTypeIndex])
    self.multiBaleSize:setState(baleSizeIndex)
    self.multiBaleSize:setDisabled(addBaleDisabled)

    self.multiBaleFillType:setTexts(self.baleFillTypesTexts[baleTypeIndex][baleSizeIndex])
    self.multiBaleFillType:setState(baleFillTypeIndex, true)
    self.multiBaleFillType:setDisabled(addBaleDisabled)

    self.buttonConfirmBale:setDisabled(addBaleDisabled)

    -- Show Locations
    if g_easyDevHotspotsManager ~= nil then
        self.checkedShowBaleLocations:setIsChecked(g_easyDevHotspotsManager.updateBales)
        self.checkedShowPalletLocations:setIsChecked(g_easyDevHotspotsManager.updatePallets)
    end

    -- Add Pallet
    local addPalletDisabled = self:getIsPropertyDisabled("addPallet")

    self:collectPalletTypeData()

    self.multiPalletCategory:setTexts(self.palletCategoryTexts)
    self.multiPalletCategory:setState(self.palletCategoryIndex or 1, true)

    self.multiPalletCategory:setDisabled(addPalletDisabled)
    self.multiPalletFillType:setDisabled(addPalletDisabled)
    self.buttonConfirmPallet:setDisabled(addPalletDisabled)

    -- Add Log
    local addPalletDisabled = self:getIsPropertyDisabled("addLog")

    self:collectTreeTypeData()

    self.multiLogType:setTexts(self.logTypeTexts)
    self.multiLogType:setState(self.logTypeIndex or 1, true)

    self.multiLogType:setDisabled(addPalletDisabled)
    self.multiLogLength:setDisabled(addPalletDisabled)
    self.buttonConfirmLog:setDisabled(addPalletDisabled)

    -- Tip To Trigger
    self.maximumText = EasyDevUtils.getText("easyDevControls_maximum")
    self.emptyText = g_i18n:formatFluid(0)

    self.tipToTriggerDisabled = true
    self.triggerObjectData = nil

    self.tipToTriggerOptions = {
        {
            title = EasyDevUtils.getText("easyDevControls_all"),
            fillTypeIndex = FillType.UNKNOWN,
            capacity = 0,
            amounts = {
                1e+7,
                0
            },
            texts = {
                self.maximumText,
                self.emptyText,
                ""
            }
        }
    }

    if player ~= nil and g_currentMission.controlPlayer then
        self.tipToTriggerDisabled = self:getIsPropertyDisabled("tipToTrigger")

        if not self.tipToTriggerDisabled then
            raycastAll(x, y + 4, z, 0, -1, 0, "tipToTriggerRaycastCallback", 10, self, nil, false, false)

            self.tipToTriggerDisabled = self.triggerObjectData == nil
        end
    end

    self.multiOptionTipToTriggerFillType:setOptions(self.tipToTriggerOptions)
    self.multiOptionTipToTriggerFillType:setState(self.multiOptionTipToTriggerFillType.state, true)

    self.multiOptionTipToTriggerFillType:setDisabled(self.tipToTriggerDisabled)
    self.multiTipToTriggerState:setDisabled(self.tipToTriggerDisabled)
    self.buttonConfirmTipToTrigger:setDisabled(self.tipToTriggerDisabled)

    -- Tip Anywhere
    local tipAnywhereDisabled = self:getIsPropertyDisabled("tipAnywhere")

    if not tipAnywhereDisabled then
        -- See if it would be possible to tip where player is standing
        tipAnywhereDisabled = not EasyDevUtils.getCanTipToGround(nil, nil, x, y, z, dirX, dirZ, 1, controlledVehicle, g_currentMission:getFarmId())
    end

    self.multiTipAnywhereFillType:setDisabled(tipAnywhereDisabled)
    self.multiTipAnywhereLength:setDisabled(tipAnywhereDisabled)
    self.textInputTipAnywhereAmount:setDisabled(tipAnywhereDisabled)
    self.buttonConfirmTipAnywhere:setDisabled(tipAnywhereDisabled)

    self.tipAnywhereAmount = 0
    self.tipAnywhereDisabled = tipAnywhereDisabled


    -- Clear Tip Anywhere
    local disableClearTipAnywhere = self:getIsPropertyDisabled("clearTipAnywhere")
    self.clearTipAnywhereMapWide = not self:getIsPropertyDisabled("clearTipAnywhereMapWide")

    self.multiClearTipAnywhereState:setState(self.multiClearTipAnywhereState.state, true)

    self.multiClearTipAnywhereFillType:setDisabled(disableClearTipAnywhere)
    self.multiClearTipAnywhereState:setDisabled(disableClearTipAnywhere)
    self.multiClearTipAnywhereArea:setDisabled(disableClearTipAnywhere)
    self.buttonConfirmClearTipAnywhere:setDisabled(disableClearTipAnywhere)

    -- Show Tip Collisions
    self.checkedShowTipCollisions:setDisabled(not isServer)

    -- Remove All
    local disableRemoveAll = not self.hasMasterRights

    self.buttonConfirmRemoveAllBales:setDisabled(disableRemoveAll)
    self.buttonConfirmRemoveAllPallets:setDisabled(disableRemoveAll)
    self.buttonConfirmRemoveAllLogs:setDisabled(disableRemoveAll)
    self.buttonConfirmRemoveAllStumps:setDisabled(disableRemoveAll)

    EasyDevControlsObjectsFrame:superClass().updateAvailableProperties(self)
end

function EasyDevControlsObjectsFrame:delete()
    if g_easyDevDebugTipCollisions ~= nil then
        g_easyDevDebugTipCollisions:setActive(false)
    end

    EasyDevControlsObjectsFrame:superClass().delete(self)
end

-- Add Bale
function EasyDevControlsObjectsFrame:onClickBaleType(index, element)
    self.baleTypeIndex = index

    self.multiBaleSize:setTexts(self.baleSizeTexts[index])
    self.multiBaleSize:setState(1, true)
end

function EasyDevControlsObjectsFrame:onClickBaleSize(index, element)
    local baleFillTypesTexts = self.baleFillTypesTexts[self.baleTypeIndex]

    self.baleSizeIndex = index

    if baleFillTypesTexts ~= nil and baleFillTypesTexts[index] ~= nil then
        self.multiBaleFillType:setTexts(baleFillTypesTexts[index])
        self.multiBaleFillType:setState(1, true)
        self.multiBaleFillType:setDisabled(self.addBaleDisabled or #baleFillTypesTexts[index] < 2)
    end
end

function EasyDevControlsObjectsFrame:onClickBaleFillType(index, element)
    local baleSizeIndex = self.baleSizeIndex
    local baleTypeIndex = self.baleTypeIndex

    local typeSizeData = self.baleSizes[baleTypeIndex]
    local wrapStateDisabled = true

    self.baleFillTypeIndex = index

    if typeSizeData ~= nil and typeSizeData[baleSizeIndex] ~= nil then
        local sizeData = typeSizeData[baleSizeIndex]

        if sizeData.supportsWrapping and self.baleFillTypes[baleTypeIndex] then
            local fillTypesByType = self.baleFillTypes[baleTypeIndex]

            if fillTypesByType[baleSizeIndex] ~= nil and fillTypesByType[baleSizeIndex][index] then
                local fillTypeIndex = fillTypesByType[baleSizeIndex][index]

                if fillTypeIndex == FillType.GRASS_WINDROW or fillTypeIndex == FillType.SILAGE then
                    wrapStateDisabled = false -- Need to allow for custom bale types
                end
            end
        end
    end

    if wrapStateDisabled and self.multiBaleWrapState:getState() == EasyDevControlsObjectsFrame.BALE_WRAPPED then
        self.multiBaleWrapState:setState(EasyDevControlsObjectsFrame.BALE_UNWRAPPED, true)
    end

    self.multiBaleWrapState:setDisabled(self.addBaleDisabled or wrapStateDisabled)
end

function EasyDevControlsObjectsFrame:onClickBaleWrapState(index, element)
    self.baleWrapStateIndex = index
end

function EasyDevControlsObjectsFrame:onClickConfirmBale(element)
    local x, y, z, _, _, _, ry = self.easyDevControls:getObjectSpawnLocation(5.5)

    local fillTypeIndex = self.baleFillTypes[self.baleTypeIndex][self.baleSizeIndex][self.baleFillTypeIndex]
    local isRoundbale = self.baleTypeIndex == EasyDevControlsObjectsFrame.BALE_TYPE_ROUND
    local baleSizes = self.baleSizes[self.baleTypeIndex][self.baleSizeIndex]
    local width, height, length, diameter = baleSizes.width, baleSizes.height, baleSizes.length, baleSizes.diameter
    local wrapState = self.baleWrapStateIndex - 1


    local baleXMLFilename, baleIndex = g_baleManager:getBaleXMLFilename(fillTypeIndex, isRoundbale, width, height, length, diameter, "")

    -- Not finished !!!!
    -- Maybe store the index's instead like the pallets???

    if baleIndex ~= nil then
        self:setInfoText(self.easyDevControls:spawnBale(baleIndex, fillTypeIndex, wrapState, g_currentMission:getFarmId(), x, y, z, ry))
    end
end

-- Bale List
function EasyDevControlsObjectsFrame:onClickShowBaleList(element)
    local list = {}

    local sizeData = {
        {
            "width",
            EasyDevUtils.getText("easyDevControls_width")
        },
        {
            "height",
            EasyDevUtils.getText("easyDevControls_height")
        },
        {
            "length",
            EasyDevUtils.getText("easyDevControls_length")
        },
        {
            "diameter",
            EasyDevUtils.getText("easyDevControls_diameter")
        }
    }

    local sizeText = EasyDevUtils.getText("easyDevControls_size") .. ":"
    local fillTypesText = "\n\n  " .. EasyDevUtils.getText("easyDevControls_fillTypes") .. ":"

    for _, bale in ipairs(g_baleManager.bales) do
        local text = sizeText

        for _, data in ipairs(sizeData) do
            local sizeKey = data[1]

            if bale[sizeKey] ~= nil and bale[sizeKey] ~= 0 then
                text = string.format("%s\n    %s: %s", text, data[2], bale[sizeKey])
            end
        end

        text = text .. fillTypesText

        for _, fillTypeData in ipairs(bale.fillTypes) do
            local fillTypeDesc = g_fillTypeManager:getFillTypeByIndex(fillTypeData.fillTypeIndex)

            text = string.format("%s\n    %s | %s", text, fillTypeDesc.name, fillTypeDesc.title)
        end

        table.insert(list, {
            overlayColour = EasyDevUtils.OVERLAY_COLOUR_PRODUCTION_POINT,
            title = bale.xmlFilename,
            text = text
        })
    end

    self.ui:showDynamicListDialog({
        headerText = EasyDevUtils.getText("easyDevControls_availableBaleTypesTitle"),
        callback = nil,
        target = nil,
        list = list
    })
end

-- Bales Fermenting
function EasyDevControlsObjectsFrame:onClickShowBalesFermenting(element)
    local list = {}

    local baleText = g_i18n:getText("infohud_bale")
    local fermentingText = g_i18n:getText("info_fermenting")
    local sizeText = EasyDevUtils.getText("easyDevControls_size")
    local locationText = EasyDevUtils.getText("easyDevControls_location")

    local farmId = g_currentMission:getFarmId()
    local baleNumber = 1

    for _, item in pairs (g_currentMission.itemSystem.itemsToSave) do
        local object = item.item

        if object.isa ~= nil and object:isa(Bale) and g_currentMission.accessHandler:canFarmAccessOtherId(farmId, object:getOwnerFarmId()) then
            if object.getIsFermenting ~= nil and object:getIsFermenting() then
                local percentage = object.fermentingPercentage or 0
                local location = EasyDevUtils.getObjectLocationString(object.nodeId)

                local baleSizeText = ""
                local fillLevel = object:getFillLevel()
                local fillTypeTitle = EasyDevUtils.getFillTypeTitle(object:getFillType())

                if object.isRoundbale then
                    baleSizeText = string.format("%s: %s", sizeText, EasyDevUtils.formatLength(object.diameter, true))
                else
                    baleSizeText = string.format("%s: %s", sizeText, EasyDevUtils.formatLength(object.length, true))
                end

                table.insert(list, {
                    overlayColour = EasyDevUtils.OVERLAY_COLOUR_PRODUCTION_POINT,
                    title = string.format("%s %i", baleText, baleNumber),
                    text = string.format("  %s: %d%%\n  %s: %s\n  %s\n  %s: %s", fermentingText, percentage * 100, fillTypeTitle, g_i18n:formatVolume(fillLevel, 0), baleSizeText, locationText, location)
                })

                baleNumber = baleNumber + 1
            end
        end
    end

    self.ui:showDynamicListDialog({
        headerText = EasyDevUtils.getText("easyDevControls_fermentingBalesTitle"),
        callback = nil,
        target = nil,
        list = list
    })
end

-- Show Bales / Pallets Locations
function EasyDevControlsObjectsFrame:onClickShowLocations(index, element)
    self:setInfoText(self.easyDevControls:showObjectLocations(EasyDevHotspotsManager[element.name], self:getIsCheckedIndex(index)))
end

-- Add Pallet
function EasyDevControlsObjectsFrame:onClickPalletCategory(index, element)
    local category = self.palletCategories[index]

    if category ~= nil then
        self.multiPalletFillType:setTexts(category.fillTypeTexts)
        self.multiPalletFillType:setState(category.lastIndex)

        self.palletCategoryIndex = index
    else
        element:setState(1)
        self.palletCategoryIndex = 1
    end
end

function EasyDevControlsObjectsFrame:onClickPalletFillType(index, element)
    local category = self.palletCategories[self.palletCategoryIndex]

    if category ~= nil then
        category.lastIndex = index
    else
        self.multiPalletCategory:setState(1, true)
    end
end

function EasyDevControlsObjectsFrame:onClickConfirmPallet(element)
    local category = self.palletCategories[self.palletCategoryIndex]

    if category ~= nil then
        local x, y, z, _, _, _, _ = self.easyDevControls:getObjectSpawnLocation(1.6)
        local lastIndex = category.lastIndex

        self:setInfoText(self.easyDevControls:spawnPallet(category.fillTypes[lastIndex], category.xmlFilenames[lastIndex], g_currentMission:getFarmId(), x, y, z))
    else
        self:setInfoText(EasyDevUtils.getText("easyDevControls_requestFailedMessage"))
    end
end

-- Add Log
function EasyDevControlsObjectsFrame:onClickLogType(index, element)
    local treeTypesInfo = self.treeTypesInfo[index]

    if treeTypesInfo ~= nil then
        self.multiLogLength:setTexts(treeTypesInfo.lengthTexts)
        self.multiLogLength:setState(treeTypesInfo.lastLengthIndex)

        self.logTypeIndex = index
    else
        element:setState(1)
        self.logTypeIndex = 1
    end
end

function EasyDevControlsObjectsFrame:onClickLogLength(index, element)
    local treeTypesInfo = self.treeTypesInfo[self.logTypeIndex]

    if treeTypesInfo ~= nil then
        treeTypesInfo.lastLengthIndex = index
    else
        self.multiLogType:setState(1, true)
    end
end

function EasyDevControlsObjectsFrame:onClickConfirmLog(element)
    local treeTypesInfo = self.treeTypesInfo[self.logTypeIndex]

    if treeTypesInfo ~= nil then
        local x, y, z, dirX, dirY, dirZ, _ = self.easyDevControls:getObjectSpawnLocation(1.1)

        self:setInfoText(self.easyDevControls:spawnLog(treeTypesInfo.index, treeTypesInfo.lastLengthIndex, treeTypesInfo.growthState, x, y, z, dirX, dirY, dirZ))
    else
        self:setInfoText(EasyDevUtils.getText("easyDevControls_requestFailedMessage"))
    end
end

-- Tip To Trigger
function EasyDevControlsObjectsFrame:tipToTriggerRaycastCallback(hitActorId, x, y, z, distance, nx, ny, nz, subShapeIndex, hitShapeId)
    local object = g_currentMission:getNodeObject(hitActorId)

    if object ~= nil and object ~= self and object.getFillUnitIndexFromNode ~= nil and object.target ~= nil and object.target.getFillLevel ~= nil then
        local target = object.target

        if target.skipSell ~= nil and not target.skipSell then
            local name = target.owningPlaceable ~= nil and target.owningPlaceable:getName() or "Unknown Name"

            EasyDevUtils.devInfo("Target '%s' skipSell flag is false, disabling Tip To Trigger functions.", name)

            return true
        end

        if target.setFillLevel == nil and (target.targetStorages ~= nil and table.size(target.targetStorages) == 0) then
            local name = target.owningPlaceable ~= nil and target.owningPlaceable:getName() or "Unknown Name"

            EasyDevUtils.devInfo("Target '%s' does not support 'setFillLevel' and has no 'targetStorages'!", name)

            return true
        end

        local farmId = g_currentMission.player.farmId

        if object.getIsFillAllowedFromFarm == nil or not object:getIsFillAllowedFromFarm(farmId) then
            local name = target.owningPlaceable ~= nil and target.owningPlaceable:getName() or "Unknown Name"

            EasyDevUtils.devInfo("Target '%s' does not accept fill types from farm id %d", name, farmId or 0)

            return true
        end

        local fillTypes = object.fillTypes

        if fillTypes == nil then
            fillTypes = target.supportedFillTypes

            if fillTypes == nil then
                local name = target.owningPlaceable ~= nil and target.owningPlaceable:getName() or "Unknown Name"

                EasyDevUtils.devInfo("Target '%s' does not have any valid fill types!", name)

                return true
            end
        end

        for fillTypeIndex, _ in pairs (fillTypes) do
            local capacityText = self.maximumText
            local capacity = 0

            if target.getCapacity ~= nil then
                capacity = target:getCapacity(fillTypeIndex, farmId) or 0
            end

            if capacity == 0 then
                local fillLevel = object.target:getFillLevel(fillTypeIndex, farmId) or 0
                local freeCapacity = object.target:getFreeCapacity(fillTypeIndex, farmId) or 0

                capacity = freeCapacity + fillLevel
            end

            if capacity > 0 then
                capacityText = g_i18n:formatFluid(capacity)
            end

            table.insert(self.tipToTriggerOptions, {
                title = EasyDevUtils.getFillTypeTitle(fillTypeIndex),
                fillTypeIndex = fillTypeIndex,
                amounts = {
                    1e+7,
                    0
                },
                texts = {
                    capacityText,
                    self.emptyText,
                    ""
                }
            })
        end

        if #self.tipToTriggerOptions > 1 then
            self.triggerObjectData = {
                object = object,
                fillTypes = fillTypes,
                hitActorId = hitActorId
            }

            return false -- Stop the searching
        end
    end

    return true
end

function EasyDevControlsObjectsFrame:onClickTipToTriggerFillType(option, index, element)
    self:updateTipToTriggerInfo(option, self.multiTipToTriggerState.state)
end

function EasyDevControlsObjectsFrame:updateTipToTriggerInfo(option, state)
    local textInputElement = self.textInputTipToTriggerAmount
    local textInputElementDisabled = self.tipToTriggerDisabled or state < 3
    local text = option.texts[state] or ""

    textInputElement.lastValidText = text
    textInputElement:setText(text)

    textInputElement:setDisabled(textInputElementDisabled)
end

function EasyDevControlsObjectsFrame:onClickTipToTriggerState(index, element)
    self:updateTipToTriggerInfo(self.tipToTriggerOptions[self.multiOptionTipToTriggerFillType.state], index)
end

function EasyDevControlsObjectsFrame:onTipToTriggerAmountEnterPressed(element)
    local option = self.tipToTriggerOptions[self.multiOptionTipToTriggerFillType.state]
    local amount = element.text ~= "" and tonumber(element.text) or nil

    if amount == nil then
        element.lastValidText = ""
        element:setText("")
    end

    option.texts[3] = element.lastValidText
    option.amounts[3] = amount
end

function EasyDevControlsObjectsFrame:onClickConfirmTipToTrigger(element)
    local option = self.tipToTriggerOptions[self.multiOptionTipToTriggerFillType.state]
    local triggerObjectData = self.triggerObjectData

    local triggerObject = triggerObjectData ~= nil and triggerObjectData.object or nil
    local nodeObject = g_currentMission:getNodeObject(triggerObjectData.hitActorId)

    if (triggerObject ~= nil and nodeObject ~= nil and triggerObject == nodeObject) and option ~= nil then
        local state = self.multiTipToTriggerState.state

        if state == 3 then
            self:onTipToTriggerAmountEnterPressed(self.textInputTipToTriggerAmount) -- Make sure value is correct
        end

        local deltaFillLevel = option.amounts[state]

        if deltaFillLevel ~= nil then
            local fillTypes = triggerObjectData.fillTypes
            local farmId = g_currentMission.player.farmId

            if option.fillTypeIndex ~= FillType.UNKNOWN then
                fillTypes = {
                    [option.fillTypeIndex] = true
                }
            end

            for fillTypeIndex, _ in pairs (fillTypes) do
                local fillType = fillTypeIndex

                if triggerObject.fillTypeConversions ~= nil and triggerObject.fillTypeConversions[fillTypeIndex] ~= nil then
                    fillType = triggerObject.fillTypeConversions[fillTypeIndex].outgoingFillType or fillTypeIndex
                end

                self.easyDevControls:setTargetFillLevel(triggerObject.target, fillType, deltaFillLevel, farmId)
            end

            self:setInfoText("Updating target storage's.")
        else
            self:setInfoText(EasyDevUtils.getText("easyDevControls_invalidValueWarning"))
        end
    else
        self:setInfoText(EasyDevUtils.getText("easyDevControls_requestFailedMessage"))
    end
end

-- Tip Anywhere
function EasyDevControlsObjectsFrame:onTipAnywhereAmountEnterPressed(element)
    local amount = element.text ~= "" and tonumber(element.text) or nil

    if amount == nil then
        element.lastValidText = ""
        element:setText("")
    end

    self.tipAnywhereAmount = amount or 0
end

function EasyDevControlsObjectsFrame:onClickConfirmTipAnywhere(element)
    local x, y, z, dirX, dirZ, player, controlledVehicle = EasyDevUtils.getPlayerWorldLocation()

    if player ~= nil and EasyDevUtils.getIsFarmlandAccessible(x, z, player.farmId) then
        self:onTipAnywhereAmountEnterPressed(self.textInputTipAnywhereAmount)

        if self.tipAnywhereAmount > 0 then
            local fillTypeIndex = self.tipAnywhereFillTypes[self.multiTipAnywhereFillType:getState()]
            local length = EasyDevControlsObjectsFrame.TIP_LENGTHS[self.multiTipAnywhereLength:getState()]

            self:setInfoText(self.easyDevControls:tipHeightType(self.tipAnywhereAmount, fillTypeIndex, x, y, z, dirX, dirZ, length, controlledVehicle, player))
            self:onTextInputEscPressed(self.textInputTipAnywhereAmount)
        else
            self:setInfoText(EasyDevUtils.getText("easyDevControls_invalidValueWarning"))
        end
    else
        element:setDisabled(true)

        self:setInfoText(EasyDevUtils.getText("easyDevControls_requestFailedMessage"))
    end
end

-- Clear Tip Anywhere
function EasyDevControlsObjectsFrame:onClickClearTipAnywhereState(index, element)
    if not self.clearTipAnywhereMapWide then
        index = 1
        element:setState(index)
    end

    local stateData = self.clearTipAnywhereStates[index]
    local areaElement = self.multiClearTipAnywhereArea

    if stateData ~= nil then
        areaElement:setTexts(stateData.texts)
        areaElement:setState(stateData.lastIndex or 1)
        areaElement:setDisabled(stateData.disabled)
    end
end

function EasyDevControlsObjectsFrame:onClickClearTipAnywhereArea(index, element)
    self.clearTipAnywhereStates[self.multiClearTipAnywhereState.state].lastIndex = index
end

function EasyDevControlsObjectsFrame:onClickConfirmClearTipAnywhere(element)
    local fillTypeIndex = self.clearTipAnywhereFillTypes[self.multiClearTipAnywhereFillType.state]

    local stateIndex = self.multiClearTipAnywhereState:getState()
    local stateData = self.clearTipAnywhereStates[stateIndex]

    if fillTypeIndex ~= nil and stateData ~= nil then
        local x, _, z, radius, valid = 0, nil, 0, 1, false
        local farmId = g_currentMission:getFarmId()

        if stateIndex == EasyDevControlsClearHeightTypeEvent.TYPE_AREA then
            radius = EasyDevControlsObjectsFrame.CLEAR_RADIUS[stateData.lastIndex]
            x, _, z, _, _, player = EasyDevUtils.getPlayerWorldLocation(true)

            valid = EasyDevUtils.getIsFarmlandAccessible(x, z, farmId, radius)
        elseif stateIndex == EasyDevControlsClearHeightTypeEvent.TYPE_FIELD then
            if stateData.lastIndex == stateData.maxIndex then
                stateIndex = EasyDevControlsClearHeightTypeEvent.TYPE_FIELDS
                valid = #g_fieldManager:getFields() > 0
            else
                local field = g_fieldManager:getFieldByIndex(stateData.lastIndex)

                if field ~= nil then
                    valid = field.farmland == nil or g_farmlandManager:getFarmlandOwner(field.farmland.id) == farmId
                    x = field.fieldId
                end
            end
        elseif stateIndex == EasyDevControlsClearHeightTypeEvent.TYPE_MAP then
            valid = true
            -- To Do: Popup message
        end

        if valid then
            self:setInfoText(self.easyDevControls:clearHeightType(stateIndex, fillTypeIndex, x, z, radius, farmId))
        else
            element:setDisabled(true)
            self:setInfoText(EasyDevUtils.getText("easyDevControls_requestFailedMessage"))
        end
    end
end

-- Show Tip Collisions
function EasyDevControlsObjectsFrame:onClickShowTipCollisions(index, element)
    if g_easyDevDebugTipCollisions ~= nil then
        local active = self:getIsCheckedIndex(index)
        local isActive = g_easyDevDebugTipCollisions:setActive(active)

        if active ~= isActive then
            element:setState(isActive)
        end

        -- Need texts??
    end
end

-- Remove All
function EasyDevControlsObjectsFrame:onClickConfirmRemoveAll(element)
    local typeData = EasyDevControlsObjectsFrame.REMOVE_ALL_TYPES[element.name]

    if typeData ~= nil then
        local function removeAllObjects(yes)
            if yes then
                element:setDisabled(true)
                self:setInfoText(self.easyDevControls:removeAllObjects(typeData.id))
            end
        end

        g_gui:showYesNoDialog({
            text = EasyDevUtils.formatText("easyDevControls_removeAllObjectsWarning", EasyDevUtils.getText(typeData.nameI18N)),
            yesText = g_i18n:getText("button_continue"),
            noText = g_i18n:getText("button_cancel"),
            callback = removeAllObjects
        })
    else
        self:setInfoText(EasyDevUtils.getText("easyDevControls_requestFailedMessage"))
    end
end



function EasyDevControlsObjectsFrame:collectBaleTypeData(force)
    if not force and self.baleSizes ~= nil and self.baleSizeTexts ~= nil and self.baleFillTypes ~= nil and self.baleFillTypesTexts ~= nil then
        return
    end

    local numSquareBaleSizes = 0
    local numRoundBaleSizes = 0

    local squareBaleSizes = {}
    local roundBaleSizes = {}

    local squareBales = {}
    local roundBales = {}

    self.baleSizes = {{}, {}}
    self.baleSizeTexts = {{}, {}}

    self.baleFillTypes = {{}, {}}
    self.baleFillTypesTexts = {{}, {}}

    self.baleTypeIndex = 1
    self.baleSizeIndex = 1
    self.baleFillTypeIndex = 1
    self.baleWrapStateIndex = 1

    for _, bale in ipairs(g_baleManager.bales) do
        if bale.isAvailable and (bale.customEnvironment == nil or bale.customEnvironment == "") then
            if bale.isRoundbale then
                if roundBaleSizes[bale.diameter] == nil then
                    roundBaleSizes[bale.diameter] = {}

                    numRoundBaleSizes = numRoundBaleSizes + 1
                end

                table.insert(roundBaleSizes[bale.diameter], bale)
            else
                if squareBaleSizes[bale.length] == nil then
                    squareBaleSizes[bale.length] = {}

                    numSquareBaleSizes = numSquareBaleSizes + 1
                end

                table.insert(squareBaleSizes[bale.length], bale)
            end
        end
    end

    if numSquareBaleSizes > 0 then
        for _, bales in pairs(squareBaleSizes) do
            table.insert(squareBales, bales)
        end

        table.sort(squareBales, function (k1, k2)
            return k1[1].length < k2[1].length
        end)
    end

    if numRoundBaleSizes > 0 then
        for _, bales in pairs(roundBaleSizes) do
            table.insert(roundBales, bales)
        end

        table.sort(roundBales, function (k1, k2)
            return k1[1].diameter < k2[1].diameter
        end)
    end

    for typeIndex, baleTypes in ipairs({squareBales, roundBales}) do
        for i, bales in ipairs (baleTypes) do
            local refBale = bales[1]

            local baleSize = {}
            local baleSizeText = nil

            local baleFillTypes = {}
            local baleFillTypesTexts = {}

            local fillTypesAdded = {}

            for _, bale in pairs(bales) do
                for _, fillTypeData in ipairs(bale.fillTypes) do
                    if not fillTypesAdded[fillTypeData.fillTypeIndex] then
                        local fillType = g_fillTypeManager:getFillTypeByIndex(fillTypeData.fillTypeIndex)

                        table.insert(baleFillTypes, fillType.index)
                        table.insert(baleFillTypesTexts, fillType.title)

                        fillTypesAdded[fillTypeData.fillTypeIndex] = true
                    end
                end
            end

            if typeIndex == EasyDevControlsObjectsFrame.BALE_TYPE_ROUND then
                baleSize.width = refBale.width
                baleSize.diameter = refBale.diameter

                baleSizeText = EasyDevUtils.formatLength(refBale.diameter, true)
            else
                baleSize.width = refBale.width
                baleSize.height = refBale.height
                baleSize.length = refBale.length

                baleSizeText = EasyDevUtils.formatLength(refBale.length, true)
            end

            baleSize.supportsWrapping = fillTypesAdded[FillType.SILAGE]

            self.baleSizes[typeIndex][i] = baleSize
            self.baleSizeTexts[typeIndex][i] = baleSizeText

            self.baleFillTypes[typeIndex][i] = baleFillTypes
            self.baleFillTypesTexts[typeIndex][i] = baleFillTypesTexts
        end
    end
end

function EasyDevControlsObjectsFrame:collectPalletTypeData(force)
    if not force and self.palletCategoryTexts ~= nil and (self.palletCategories ~= nil and #self.palletCategories == 4) then
        return
    end

    local pallets = {}

    local customPallets = {
        [FillType.SUGARBEET] = "data/objects/pallets/fillablePallet/fillablePallet.xml",
        [FillType.SUGARBEET_CUT] = "data/objects/pallets/fillablePallet/fillablePallet.xml",
        [FillType.FORAGE] = "data/objects/pallets/fillablePallet/fillablePallet.xml",
        [FillType.CHAFF] = "data/objects/pallets/fillablePallet/fillablePallet.xml",
        [FillType.TREESAPLINGS] = "data/objects/pallets/treeSaplingPallet/treeSaplingPallet.xml",
        [FillType.WOODCHIPS] = "data/objects/pallets/fillablePallet/fillablePallet.xml",
        [FillType.SILAGE] = "data/objects/pallets/fillablePallet/fillablePallet.xml",
        [FillType.POPLAR] = "data/objects/pallets/palletPoplar/palletPoplar.xml",
        [FillType.SNOW] = "data/objects/pallets/fillablePallet/fillablePallet.xml",
        [FillType.ROADSALT] = "data/objects/pallets/fillablePallet/fillablePallet.xml",
        [FillType.MANURE] = "data/objects/pallets/fillablePallet/fillablePallet.xml",
        [FillType.PIGFOOD] = "data/objects/bigBagPallet/pigFood/bigBagPallet_pigFood.xml",
        [FillType.STONE] = "data/objects/pallets/fillablePallet/fillablePallet.xml"
    }

    local farmFillTypes = {
        [FillType.SEEDS] = 1,
        [FillType.FERTILIZER] = 2,
        [FillType.LIME] = 3,
        [FillType.LIQUIDFERTILIZER] = 4,
        [FillType.HERBICIDE] = 5,
        [FillType.MANURE] = 6,
        [FillType.MINERAL_FEED] = 7,
        [FillType.SILAGE_ADDITIVE] = 8,
        [FillType.TREESAPLINGS] = 9,
        [FillType.SUGARCANE] = 10,
        [FillType.POPLAR] = 11,
        [FillType.POTATO] = 12,
        [FillType.PIGFOOD] = 13,
        [FillType.FORAGE] = 14
    }

    for _, fillType in pairs(g_fillTypeManager:getFillTypes()) do
        if fillType.palletFilename ~= nil then
            pallets[fillType.index] = fillType.palletFilename
        elseif customPallets[fillType.index] ~= nil then
            pallets[fillType.index] = customPallets[fillType.index]
        end
    end

    pallets[FillType.OILSEEDRADISH] = nil
    pallets[FillType.COTTON] = nil -- No Fill Plane in base game

    self.palletCategoryIndex = 1

    self.palletCategories = {
        {
            title = EasyDevUtils.getText("easyDevControls_farmProducts"),
            lastIndex = 1,
            fillTypes = {},
            fillTypeTexts = {},
            xmlFilenames = {}
        },
        {
            title = EasyDevUtils.getText("easyDevControls_generalHeader"),
            lastIndex = 1,
            fillTypes = {},
            fillTypeTexts = {},
            xmlFilenames = {}
        },
        {
            title = g_i18n:getText("ui_map_crops"),
            lastIndex = 1,
            fillTypes = {},
            fillTypeTexts = {},
            xmlFilenames = {}
        },
        {
            title = EasyDevUtils.getText("easyDevControls_all"),
            lastIndex = 1,
            fillTypes = {},
            fillTypeTexts = {},
            xmlFilenames = {}
        }
    }

    self.palletCategoryTexts = {}

    for i = 1, #self.palletCategories do
        self.palletCategoryTexts[i] = self.palletCategories[i].title
    end

    for fillTypeIndex, _ in pairs (pallets) do
        local index = farmFillTypes[fillTypeIndex]

        if index ~= nil then
            self.palletCategories[EasyDevControlsObjectsFrame.PALLETS_FARM].fillTypes[index] = fillTypeIndex
        elseif g_fruitTypeManager.fillTypeIndexToFruitTypeIndex[fillTypeIndex] ~= nil or
            g_fruitTypeManager.windrowFillTypes[fillTypeIndex] == true or
            fillTypeIndex == FillType.SUGARBEET_CUT then

            table.insert(self.palletCategories[EasyDevControlsObjectsFrame.PALLETS_CROPS].fillTypes, fillTypeIndex)
        else
            table.insert(self.palletCategories[EasyDevControlsObjectsFrame.PALLETS_GENERAL].fillTypes, fillTypeIndex)
        end

        table.insert(self.palletCategories[EasyDevControlsObjectsFrame.PALLETS_ALL].fillTypes, fillTypeIndex)
    end

    for i = 1, #self.palletCategories do
        local category = self.palletCategories[i]

        if i > 1 then
            table.sort(category.fillTypes, function(k1, k2)
                local fillType1 = g_fillTypeManager.fillTypes[k1]
                local fillType2 = g_fillTypeManager.fillTypes[k2]

                if fillType1 ~= nil and fillType2 ~= nil then
                    return fillType1.title < fillType2.title
                end

                return false
            end)
        end

        for index, fillTypeIndex in ipairs (category.fillTypes) do
            category.xmlFilenames[index] = pallets[fillTypeIndex]
            category.fillTypeTexts[index] = EasyDevUtils.getFillTypeTitle(fillTypeIndex)
        end
    end
end

function EasyDevControlsObjectsFrame:collectTreeTypeData(force)
    if force or (self.treeTypesInfo == nil or #self.treeTypesInfo == 0) or self.logTypeTexts == nil then
        self.treeTypesInfo = {}
        self.logTypeTexts = {}

        self.logTypeIndex = 1

        local treeNameToMaxLength = {
            pine = 8,
            stonePine = 8,
            spruce1 = 6,
            birch = 5,
            americanElm = 5,
            shagbarkHickory = 4,
            oak = 3,
            maple = 2
        }

        for name, maxLength in pairs (treeNameToMaxLength) do
            local treeType = g_treePlantManager:getTreeTypeDescFromName(name)

            if treeType ~= nil then
                local treeTypeInfo = {
                    title = g_i18n:getText(treeType.nameI18N, g_currentMission.baseDirectory),
                    growthState = #treeType.treeFilenames,
                    index = treeType.index,
                    maxLength = maxLength,
                    lastLengthIndex = 1
                }

                if treeType.name == "PINE" then
                    treeTypeInfo.growthState = math.min(6, treeTypeInfo.growthState) -- Mesh error when using Stage 7
                end

                table.insert(self.treeTypesInfo, treeTypeInfo)
            end
        end

        table.sort(self.treeTypesInfo, function (k1, k2)
            return k1.maxLength > k2.maxLength
        end)

        for i = 1, #self.treeTypesInfo do
            self.logTypeTexts[i] = self.treeTypesInfo[i].title
        end
    end

    -- Use feet for the US users
    for i = 1, #self.treeTypesInfo do
        local treeTypeInfo = self.treeTypesInfo[i]
        local useFahrenheit = g_i18n.useFahrenheit

        treeTypeInfo.lengthTexts = {}

        for i = 1, treeTypeInfo.maxLength do
            if not useFahrenheit then
                treeTypeInfo.lengthTexts[i] = string.format("%d %s", i, i == 1 and "meter" or "meters")
            else
                treeTypeInfo.lengthTexts[i] = string.format("%.2f feet", i * 3.281)
            end
        end
    end
end

-- Listeners
function EasyDevControlsObjectsFrame:onSettingChanged(id, value)
    if id == EasyDevUtils.SETTING_HOTSPOTS then
        if g_easyDevHotspotsManager ~= nil then
            self.checkedShowBaleLocations:setIsChecked(g_easyDevHotspotsManager.updateBales)
            self.checkedShowPalletLocations:setIsChecked(g_easyDevHotspotsManager.updatePallets)
        end
    end
end

-- Extras
function EasyDevControlsObjectsFrame:getResetValues()
    local unchecked = CheckedOptionElement.STATE_UNCHECKED

    return {
        checkedShowBaleLocations = {
            value = unchecked
        },
        checkedShowPalletLocations = {
            value = unchecked
        },
        checkedShowTipCollisions = {
            value = unchecked
        }
    }
end
