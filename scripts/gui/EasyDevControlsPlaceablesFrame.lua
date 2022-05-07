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

EasyDevControlsPlaceablesFrame = {}

local EasyDevControlsPlaceablesFrame_mt = Class(EasyDevControlsPlaceablesFrame, EasyDevControlsBaseFrame)
local EMPTY_TABLE = {}

EasyDevControlsPlaceablesFrame.L10N_SYMBOL = {}

EasyDevControlsPlaceablesFrame.CONTROLS = {
    "multiSetProductionPoint",
    "buttonSetProductionPointOwner",
    "buttonSetProductionPointState",
    "buttonSetProductionPointOutput",
    "buttonSetProductionPointFillLevel",
    "buttonProductionPointsList",
    "buttonAutoDeliverMapping",
    "checkedProductionPointsDebug",
    "checkedShowPlaceableTestAreas",
    "checkedShowPlacementCollisions",
    "buttonConfirmReloadPlaceable",
    "buttonConfirmReloadPlaceableText",
    "buttonConfirmReloadAllPlaceables",
    "buttonConfirmRemoveAllPlaceables",
    "buttonConfirmRemoveAllMapPlaceables"
}

EasyDevControlsPlaceablesFrame.PRODUCTION_POINT_ALL_NPC = 1
EasyDevControlsPlaceablesFrame.PRODUCTION_POINT_ALL_FARM = 2
EasyDevControlsPlaceablesFrame.PRODUCTION_POINT_TRIGGER = 3

function EasyDevControlsPlaceablesFrame.new(ui, easyDevControls, accessLevel)
    local self = EasyDevControlsBaseFrame.new(EasyDevControlsPlaceablesFrame_mt, ui, easyDevControls, accessLevel)

    self.farmIDs = {}
    self.farmTexts = {}

    self.productionPointData = {}
    self.productionPointIndexTexts = {}
    self.productionPointTexts = {}
    self.productionPoints = {}

    self.availableProductionPoints = 0
    self.productionPointIndex = EasyDevControlsPlaceablesFrame.PRODUCTION_POINT_ALL_NPC

    self:registerControls(EasyDevControlsPlaceablesFrame.CONTROLS)

    return self
end

function EasyDevControlsPlaceablesFrame:initialize()
    self.noneText = g_i18n:getText("character_option_none")

    self.isServer = g_server ~= nil
    self.isSinglePlayer = self.isServer and not self.ui.isMultiplayer

    self:initProductionPointData()
end

function EasyDevControlsPlaceablesFrame:subscribeToMessages(messageCenter)
    -- messageCenter:subscribe(EasyDevUtils.MESSAGE_TYPE_SETTINGS_CHANGED, self.onSettingChanged, self)
    messageCenter:subscribe(EasyDevUtils.MESSAGE_TYPE_PRODUCTIONS_CHANGED, self.onProductionsChanged, self)
    messageCenter:subscribe(MessageType.FARM_CREATED, self.onFarmCreated, self)
    messageCenter:subscribe(MessageType.FARM_DELETED, self.onFarmDeleted, self)
end

function EasyDevControlsPlaceablesFrame:updateAvailableProperties()
    self:collectFarmsInfo()

    -- Production Point
    local productionPointsDisabled = self:getIsPropertyDisabled("productionPoints")

    self.multiSetProductionPoint:setDisabled(productionPointsDisabled)
    self.buttonSetProductionPointOwner:setDisabled(productionPointsDisabled)
    self.buttonSetProductionPointState:setDisabled(productionPointsDisabled)
    self.buttonSetProductionPointOutput:setDisabled(productionPointsDisabled)
    self.buttonSetProductionPointFillLevel:setDisabled(productionPointsDisabled)

    self.productionPointsDisabled = productionPointsDisabled
    self:initProductionPointsInfo() -- ToDO: Need to update this when any production changes owner??

    -- Reload All Placeables
    local closestPlaceable
    local placeableName = ""
    local reloadPlaceableDisabled = true
    local reloadAllPlaceablesDisabled = true

    if self.isSinglePlayer then
        local lastDistance  = math.huge
        local placeableSystem = g_currentMission.placeableSystem
        local playerNode = g_currentMission.player ~= nil and g_currentMission.player.rootNode

        if playerNode == nil then
            playerNode = g_currentMission.controlledVehicle ~= nil and g_currentMission.controlledVehicle.rootNode
        end

        if playerNode ~= nil and placeableSystem ~= nil then
            for _, placeable in ipairs(placeableSystem.placeables) do
                if placeable.spec_trainSystem == nil and placeable.rootNode ~= nil then
                    local distance = calcDistanceFrom(placeable.rootNode, playerNode)

                    if distance < 30 and distance < lastDistance then
                        lastDistance = distance
                        closestPlaceable = placeable
                    end
                end
            end

            if closestPlaceable ~= nil then
                reloadPlaceableDisabled = false
                placeableName = closestPlaceable:getName()
            end
        end

        reloadAllPlaceablesDisabled = false
    end

    placeableName = EasyDevUtils.formatText("easyDevControls_reloadPlaceableTitle", EasyDevUtils.getNoNilOrEmpty(placeableName, self.noneText))
    self.closestPlaceable = closestPlaceable

    self.buttonConfirmReloadPlaceableText:setText(placeableName)
    self.buttonConfirmReloadPlaceable:setDisabled(reloadPlaceableDisabled)
    self.buttonConfirmReloadAllPlaceables:setDisabled(reloadAllPlaceablesDisabled)

    -- Placement Collisions
    self.checkedShowPlacementCollisions:setDisabled(not self.isServer)

    -- Remove All Placeables / Map Placeables
    self.buttonConfirmRemoveAllPlaceables:setDisabled(not self.isSinglePlayer)
    self.buttonConfirmRemoveAllMapPlaceables:setDisabled(not self.isSinglePlayer)

    EasyDevControlsPlaceablesFrame:superClass().updateAvailableProperties(self)
end

function EasyDevControlsPlaceablesFrame:delete()
    if g_easyDevDebugProduction ~= nil then
        g_easyDevDebugProduction:setActive(false)
    end

    if g_easyDevDebugPlacementCollisions ~= nil then
        g_easyDevDebugPlacementCollisions:setActive(false)
    end

    EasyDevControlsPlaceablesFrame:superClass().delete(self)
end

-- Production Point
function EasyDevControlsPlaceablesFrame:onClickSetProductionPoint(index, element)
    local productionPoints = self.productionPoints[index] or EMPTY_TABLE
    local disabled = self.productionPointsDisabled or #productionPoints == 0

    self.currentProductionPoints = productionPoints
    self.productionPointIndex = index

    self.buttonSetProductionPointOwner:setDisabled(disabled)
    self.buttonSetProductionPointState:setDisabled(disabled)
    self.buttonSetProductionPointOutput:setDisabled(disabled)
    self.buttonSetProductionPointFillLevel:setDisabled(disabled)
end

function EasyDevControlsPlaceablesFrame:onClickSetProductionPointData(element)
    if element.name ~= nil then
        local dialogData = self:updateProductionPointsData(element.name)

        if dialogData ~= nil then
            local dialogTarget = self.ui:showDynamicSelectionDialog({
                headerText = dialogData.headerText,
                confirmButtonDisabled = dialogData.confirmButtonDisabled,
                callback = dialogData.callback,
                target = dialogData.target,
                properties = dialogData.properties,
                numHorizontal = dialogData.numHorizontal,
                numVertical = dialogData.numVertical,
                numVerticalClosePerRow = dialogData.numVerticalClosePerRow,
                flowVertical = dialogData.flowVertical
            })

            if dialogTarget ~= nil then
                dialogTarget:setNotifyOnClose(self)
                self.productionPointDialog = dialogTarget
            end
        end
    else
        self:setInfoText(EasyDevUtils.getText("easyDevControls_requestFailedMessage"))
    end
end

function EasyDevControlsPlaceablesFrame:initProductionPointsInfo(setProductionPoint)
    local activatableObjectsSystem = g_currentMission.activatableObjectsSystem

    local productionChainManager = g_currentMission.productionChainManager
    local numberOfProductionPoints = productionChainManager:getNumOfProductionPoints()

    local playerFarmId = g_currentMission:getFarmId()
    local availableProductionPoints = 0

    self.productionPointIndexTexts = {}
    self.productionPointTexts = {}
    self.productionPoints = {}

    -- ToDo: Add support for farmland productions (ID 15 / buyWithFarmland)
    if playerFarmId ~= FarmManager.SPECTATOR_FARM_ID and numberOfProductionPoints > 0 then --[[and not self.productionPointsDisabled then]]
        self.productionPoints[1] = {}
        self.productionPoints[2] = {}
        self.productionPoints[3] = EMPTY_TABLE

        self.productionPointTexts[1] = EasyDevUtils.getText("easyDevControls_npcOwned")
        self.productionPointTexts[2] = EasyDevUtils.getText("easyDevControls_farmOwned")
        self.productionPointTexts[3] = EasyDevUtils.getText("easyDevControls_currentTrigger")

        for i = 1, numberOfProductionPoints do
            local productionPoint = productionChainManager.productionPoints[i]

            if productionPoint ~= nil then
                local farmId = productionPoint:getOwnerFarmId()

                local npcOwned = farmId == FarmManager.SPECTATOR_FARM_ID
                local playerOwned = farmId == playerFarmId
                local indexText = string.format("PP %i", i)

                if npcOwned or playerOwned then
                    if npcOwned then
                        table.insert(self.productionPoints[1], productionPoint)
                    end

                    if playerOwned then
                        table.insert(self.productionPoints[2], productionPoint)
                    end

                    if activatableObjectsSystem.currentActivatableObject == productionPoint.activatable then
                        self.productionPoints[3] = {productionPoint}
                    end

                    table.insert(self.productionPoints, {productionPoint})
                    table.insert(self.productionPointTexts, indexText)

                    if productionPoint == setProductionPoint then
                        self.productionPointIndex = #self.productionPoints
                    end

                    availableProductionPoints = availableProductionPoints + 1
                end

                self.productionPointIndexTexts[productionPoint] = indexText
            end
        end
    end

    if availableProductionPoints == 0 then
        self.productionPointTexts[1] = self.noneText
    end

    self.multiSetProductionPoint:setTexts(self.productionPointTexts)

    if availableProductionPoints ~= self.availableProductionPoints then
        self.productionPointIndex = 1
    end

    self.multiSetProductionPoint:setState(self.productionPointIndex, true)
    self.availableProductionPoints = availableProductionPoints
end

function EasyDevControlsPlaceablesFrame:initProductionPointData()
    self.productionPointData.productionPointOwner = {
        headerText = "",
        numHorizontal = 1,
        numVertical = 1,
        flowVertical = false,
        properties = {
            {
                title = EasyDevUtils.getText("easyDevControls_setOwnerTitle"),
                typeId = DynamicSelectionDialog.TYPE_MULTI_TEXT_OPTION,
                name = "productionPointOwner",
                dynamicId = "multiOwnerElement",
                texts = self.farmTexts
            }
        },
        callback = function(confirm, callbackValues)
            if confirm and callbackValues ~= nil then
                local farmName = "NPC"
                local numUpdated = 0
                local setProductionPoint = nil

                local pushLastChange = self.productionPointIndex > EasyDevControlsPlaceablesFrame.PRODUCTION_POINT_TRIGGER
                local farmId = self.farmIDs[callbackValues["productionPointOwner"]]

                if farmId ~= nil then
                    local farm = g_farmManager.farmIdToFarm[farmId]

                    if farm ~= nil then
                        for _, productionPoint in ipairs(self.currentProductionPoints) do
                            if productionPoint.owningPlaceable ~= nil then
                                if self.isServer then
                                    productionPoint.owningPlaceable:setOwnerFarmId(farmId)
                                else
                                    productionPoint.owningPlaceable:setOwnerFarmId(farmId, true)
                                    g_client:getServerConnection():sendEvent(EasyDevControlsObjectFarmChangeEvent.new(productionPoint.owningPlaceable, farmId))
                                end

                                if pushLastChange then
                                    setProductionPoint = productionPoint
                                end

                                if productionPoint.activatable ~= nil and productionPoint.activatable.updateText ~= nil then
                                    productionPoint.activatable:updateText() -- update buy / manage text
                                end

                                numUpdated = numUpdated + 1
                            end
                        end

                        if farmId ~= FarmManager.SPECTATOR_FARM_ID then
                            farmName = farm.name
                        end
                    end
                end

                if numUpdated > 0 then
                    local typeText = EasyDevUtils.getTypeText("PRODUCTION_POINT", numUpdated)

                    self:initProductionPointsInfo(setProductionPoint)
                    self:setInfoText(EasyDevUtils.formatText("easyDevControls_productionPointOwnerInfo", numUpdated, typeText, farmName, farmId))
                else
                    self:setInfoText(EasyDevUtils.getText("easyDevControls_requestFailedMessage"))
                end
            end
        end
    }

    self.productionPointData.productionPointState = {
        headerText = "",
        numHorizontal = 1,
        numVertical = 3,
        numVerticalClosePerRow = 2,
        flowVertical = false,
        confirmButtonDisabled = true,
        variableIDs = {},
        lastSetIndexs = {},
        disabledIndexs = {},
        properties = {
            {
                title = EasyDevUtils.getText("easyDevControls_setStateTitle"),
                typeId = DynamicSelectionDialog.TYPE_MULTI_TEXT_OPTION,
                name = "productionPointMultiInputType",
                dynamicId = "multiInputTypeElement",
                disabled = false,
                forceState = true,
                lastIndex = 1,
                onClickCallback = function(dialog, index, element, isLeft, property)
                    local data = self.productionPointData.productionPointState
                    local indexToSet = data.lastSetIndexs[index] or 1

                    dialog.multiStateElement:setState(indexToSet, true)
                end
            },
            {
                typeId = DynamicSelectionDialog.TYPE_CHECKED_OPTION,
                profile = "dynamicSelectionMultiTextOptionClose",
                name = "productionPointMultiState",
                dynamicId = "multiStateElement",
                disabled = false,
                lastIndex = 1,
                onClickCallback = function(dialog, index, element, isLeft, property)
                    local data = self.productionPointData.productionPointState
                    local multiTypeLastIndex = dialog.multiInputTypeElement.lastIndex
                    local disabledIndex = data.disabledIndexs[multiTypeLastIndex] or 0

                    data.lastSetIndexs[multiTypeLastIndex] = index
                    dialog.buttonConfirmStateElement:setDisabled(disabledIndex == index)
                end
            },
            {
                typeId = DynamicSelectionDialog.TYPE_BUTTON,
                profile = "dynamicSelectionConfirmClose",
                name = "productionPointButtonConfirmState",
                dynamicId = "buttonConfirmStateElement",
                disabled = false,
                onClickCallback = function(dialog, element, property)
                    local numUpdated = 0

                    local multiTypeIndex = dialog.multiInputTypeElement:getState()
                    local multiStateIndex = dialog.multiStateElement:getState()

                    local data = self.productionPointData.productionPointState
                    local state = multiStateIndex == CheckedOptionElement.STATE_CHECKED

                    if multiTypeIndex > 1 then
                        local productionId = data.variableIDs[multiTypeIndex]

                        if productionId ~= nil then
                            for _, productionPoint in pairs(self.currentProductionPoints) do
                                productionPoint:setProductionState(productionId, state, false)
                            end

                            numUpdated = numUpdated + 1
                        end
                    else
                        for _, productionPoint in ipairs(self.currentProductionPoints) do
                            for _, production in pairs(productionPoint.productions) do
                                productionPoint:setProductionState(production.id, state, false)

                                numUpdated = numUpdated + 1
                            end
                        end
                    end

                    if numUpdated > 0 then
                        local stateText = self.stateTexts[multiStateIndex] or ""
                        local typeText = EasyDevUtils.getTypeText("PRODUCTION", numUpdated)

                        if multiTypeIndex > 1 then
                            local synced = true

                            data.disabledIndexs[multiTypeIndex] = multiStateIndex

                            for index, stateIndex in pairs (data.disabledIndexs) do
                                if index > 1 and stateIndex ~= multiStateIndex then
                                    data.disabledIndexs[1] = 0
                                    synced = false

                                    break
                                end
                            end

                            if synced then
                                data.disabledIndexs[1] = multiStateIndex
                            end
                        else
                            for index, _ in pairs (data.disabledIndexs) do
                                data.disabledIndexs[index] = multiStateIndex
                            end
                        end

                        element:setDisabled(true)

                        self:setInfoText(EasyDevUtils.formatText("easyDevControls_productionPointStateInfo", numUpdated, typeText, stateText:upper()))
                    else
                        self:setInfoText(EasyDevUtils.getText("easyDevControls_requestFailedMessage"))
                    end
                end
            }
        }
    }

    self.productionPointData.productionPointOutputMode = {
        headerText = "",
        numHorizontal = 1,
        numVertical = 3,
        numVerticalClosePerRow = 2,
        flowVertical = false,
        confirmButtonDisabled = true,
        variableIDs = {},
        lastSetIndexs = {},
        disabledIndexs = {},
        properties = {
            {
                title = EasyDevUtils.getText("easyDevControls_outputModeTitle"),
                typeId = DynamicSelectionDialog.TYPE_MULTI_TEXT_OPTION,
                name = "productionPointMultiOutputType",
                dynamicId = "multiOutputTypeElement",
                disabled = false,
                forceState = true,
                lastIndex = 1,
                onClickCallback = function(dialog, index, element, isLeft, property)
                    local data = self.productionPointData.productionPointOutputMode
                    local indexToSet = data.lastSetIndexs[index] or 1

                    dialog.multiOutputModeElement:setState(indexToSet, true)
                end
            },
            {
                typeId = DynamicSelectionDialog.TYPE_MULTI_TEXT_OPTION,
                texts = {
                    g_i18n:getText("ui_production_output_storing"),
                    g_i18n:getText("ui_production_output_selling"),
                    g_i18n:getText("ui_production_output_distributing")
                },
                profile = "dynamicSelectionMultiTextOptionClose",
                name = "productionPointMultiOutputMode",
                dynamicId = "multiOutputModeElement",
                lastIndex = 1,
                onClickCallback = function(dialog, index, element, isLeft, property)
                    local data = self.productionPointData.productionPointOutputMode
                    local multiTypeLastIndex = dialog.multiOutputTypeElement.lastIndex
                    local disabledIndex = data.disabledIndexs[multiTypeLastIndex] or 0

                    data.lastSetIndexs[multiTypeLastIndex] = index
                    dialog.buttonConfirmOutputElement:setDisabled(disabledIndex == index)
                end
            },
            {
                typeId = DynamicSelectionDialog.TYPE_BUTTON,
                profile = "dynamicSelectionConfirmClose",
                name = "productionPointButtonConfirmOutput",
                dynamicId = "buttonConfirmOutputElement",
                disabled = false,
                onClickCallback = function(dialog, element, property)
                    local numUpdated = 0

                    local multiTypeIndex = dialog.multiOutputTypeElement:getState()
                    local multiModeIndex = dialog.multiOutputModeElement:getState()

                    local data = self.productionPointData.productionPointOutputMode
                    local distributionMode = multiModeIndex - 1

                    if multiTypeIndex > 1 then
                        local outputFillTypeId = data.variableIDs[multiTypeIndex]

                        if outputFillTypeId ~= nil then
                            for _, productionPoint in pairs(self.currentProductionPoints) do
                                if productionPoint.outputFillTypeIds[outputFillTypeId] ~= nil then
                                    productionPoint:setOutputDistributionMode(outputFillTypeId, distributionMode)

                                    numUpdated = numUpdated + 1
                                end
                            end
                        end
                    else
                        for _, productionPoint in ipairs(self.currentProductionPoints) do
                            for outputFillTypeId in pairs(productionPoint.outputFillTypeIds) do
                                productionPoint:setOutputDistributionMode(outputFillTypeId, distributionMode)

                                numUpdated = numUpdated + 1
                            end
                        end
                    end

                    if numUpdated > 0 then
                        local typeText = EasyDevUtils.getTypeText("PRODUCTION", numUpdated)
                        local l10n = "ui_production_output_storing"

                        if distributionMode == ProductionPoint.OUTPUT_MODE.DIRECT_SELL then
                            l10n = "ui_production_output_selling"
                        elseif distributionMode == ProductionPoint.OUTPUT_MODE.AUTO_DELIVER then
                            l10n = "ui_production_output_distributing"
                        end

                        if multiTypeIndex > 1 then
                            local synced = true

                            data.disabledIndexs[multiTypeIndex] = multiModeIndex

                            for index, stateIndex in pairs (data.disabledIndexs) do
                                if index > 1 and stateIndex ~= multiModeIndex then
                                    data.disabledIndexs[1] = 0
                                    synced = false

                                    break
                                end
                            end

                            if synced then
                                data.disabledIndexs[1] = multiModeIndex
                            end
                        else
                            for index, _ in pairs (data.disabledIndexs) do
                                data.disabledIndexs[index] = multiModeIndex
                            end
                        end

                        element:setDisabled(true)

                        self:setInfoText(EasyDevUtils.formatText("easyDevControls_productionPointDistributionInfo", numUpdated, typeText, g_i18n:getText(l10n)))
                    else
                        self:setInfoText(EasyDevUtils.getText("easyDevControls_requestFailedMessage"))
                    end
                end
            }
        }
    }

    self.productionPointData.productionPointFillLevel = {
        headerText = "",
        confirmButtonDisabled = true,
        flowVertical = false,
        numHorizontal = 1,
        numVertical = 6,
        numVerticalClosePerRow = 5,
        types = {
            "inputFillTypeIds",
            "outputFillTypeIds"
        },
        fillTypes = {},
        fillTypeTexts = {},
        lastSetIndexs = {},
        inputTypeIndex = 1,
        maxFillLevels = {},
        maxFillLevelTexts = {},
        properties = {
            {
                typeId = DynamicSelectionDialog.TYPE_MULTI_TEXT_OPTION,
                title = EasyDevUtils.getText("easyDevControls_fillLevelTitle"),
                name = "productionPointMultiFillLevelMode",
                dynamicId = "multiFillLevelModeElement",
                forceState = true,
                texts = {
                    EasyDevUtils.getText("easyDevControls_input"),
                    EasyDevUtils.getText("easyDevControls_output")
                },
                onClickCallback = function(dialog, index, element, isLeft, property)
                    local data = self.productionPointData.productionPointFillLevel
                    local indexToSet = data.lastSetIndexs[index] or 1

                    dialog.multiFillLevelFillTypeElement:setTexts(data.fillTypeTexts[index])
                    dialog.multiFillLevelFillTypeElement:setState(1)

                    dialog.multiFillLevelStateElement:setState(indexToSet, true)
                end
            },
            {
                typeId = DynamicSelectionDialog.TYPE_MULTI_TEXT_OPTION,
                profile = "dynamicSelectionMultiTextOptionClose",
                name = "productionPointMultiFillLevelFillType",
                dynamicId = "multiFillLevelFillTypeElement",
                disabled = false,
                onClickCallback = function(dialog, index, element, isLeft, property)
                    dialog.multiFillLevelStateElement:setState(dialog.multiFillLevelStateElement:getState(), true)
                end
            },
            {
                typeId = DynamicSelectionDialog.TYPE_MULTI_TEXT_OPTION,
                profile = "dynamicSelectionMultiTextOptionClose",
                name = "productionPointMultiFillLevelState",
                dynamicId = "multiFillLevelStateElement",
                texts = {
                    EasyDevUtils.getText("easyDevControls_fill"),
                    EasyDevUtils.getText("easyDevControls_empty"),
                    EasyDevUtils.getText("easyDevControls_set"),

                },
                onClickCallback = function(dialog, index, element, isLeft, property)
                    local data = self.productionPointData.productionPointFillLevel
                    local textInputElement = dialog.textInputAmountElement

                    if index == 1 then
                        local text = "100 %"

                        if data.inputTypeIndex == 1 then
                            local modeState = dialog.multiFillLevelModeElement:getState()
                            local fillTypeState = dialog.multiFillLevelFillTypeElement:getState()

                            text = data.maxFillLevelTexts[modeState][fillTypeState]

                            if text == nil then
                                text = "Maximum"
                            end

                            text = tostring(text)
                        end

                        textInputElement.maxCharacters = 10
                        textInputElement.lastValidText = text
                        textInputElement:setText(text)
                    elseif index == 2 then
                        local text = data.inputTypeIndex == 1 and "0" or "0 %"

                        textInputElement.maxCharacters = 10
                        textInputElement.lastValidText = text
                        textInputElement:setText(text)
                    else
                        if dialog.multiFillLevelFillTypeElement:getState() > 1 then
                            if data.inputTypeIndex == 1 then
                                textInputElement.maxCharacters = 10
                            else
                                textInputElement.maxCharacters = 3
                            end

                            textInputElement.lastValidText = ""
                            textInputElement:setText("")
                        else
                            element:setState(isLeft and 2 or 1, true)

                            return
                        end
                    end

                    textInputElement:setDisabled(index < 3)
                end
            },
            {
                typeId = DynamicSelectionDialog.TYPE_MULTI_TEXT_OPTION,
                profile = "dynamicSelectionMultiTextOptionClose",
                name = "productionPointMultiInputType",
                dynamicId = "multiFillInputTypeElement",
                texts = {
                    EasyDevUtils.getText("easyDevControls_unitLitres"),
                    EasyDevUtils.getText("easyDevControls_unitPercent")
                },
                onClickCallback = function(dialog, index, element, isLeft, property)
                    self.productionPointData.productionPointFillLevel.inputTypeIndex = index
                    dialog.multiFillLevelStateElement:setState(dialog.multiFillLevelStateElement:getState(), true)
                end
            },
            {
                typeId = DynamicSelectionDialog.TYPE_TEXT_INPUT,
                profile = "dynamicSelectionTextInputClose",
                name = "productionPointTextInputAmount",
                dynamicId = "textInputAmountElement",
                maxCharacters = 10
            },
            {
                typeId = DynamicSelectionDialog.TYPE_BUTTON,
                profile = "dynamicSelectionConfirmClose",
                name = "productionPointButtonConfirmFillLevel",
                dynamicId = "buttonConfirmFillLevelElement",
                onClickCallback = function(dialog, element, property)
                    local stateIndex = dialog.multiFillLevelStateElement:getState()
                    local modeIndex = dialog.multiFillLevelModeElement:getState()
                    local isOutput = modeIndex == 2
                    local fillLevel

                    if stateIndex == 1 then
                        fillLevel = 1e+7
                    elseif stateIndex == 2 then
                        fillLevel = 0
                    else
                        fillLevel = tonumber(dialog.textInputAmountElement.text or "")

                        if fillLevel == nil then
                            self:setInfoText(EasyDevUtils.getText("easyDevControls_invalidValueWarning"))
                        end

                        dialog.textInputAmountElement:setText("")
                        dialog.textInputAmountElement.lastValidText = ""
                    end

                    if fillLevel ~= nil then
                        local fillTypeStateIndex = dialog.multiFillLevelFillTypeElement:getState()
                        local data = self.productionPointData.productionPointFillLevel
                        local variableName = data.types[modeIndex]

                        if fillTypeStateIndex > 1 then
                            local productionPoint = self.currentProductionPoints[1]
                            local fillTypeIndex = data.fillTypes[modeIndex][fillTypeStateIndex]

                            if productionPoint ~= nil and (productionPoint[variableName] ~= nil and productionPoint[variableName][fillTypeIndex] ~= nil) then
                                local capacity = productionPoint:getCapacity(fillTypeIndex)

                                if data.inputTypeIndex == 1 then
                                    fillLevel = math.max(math.min(fillLevel, capacity), 0)
                                else
                                    fillLevel = capacity * (fillLevel / 100)
                                end

                                if fillLevel == capacity then
                                    fillLevel = fillLevel + 1
                                end

                                self:setInfoText(self.easyDevControls:setProductionPointFillLevels(productionPoint, fillLevel, fillTypeIndex, isOutput, false))
                            else
                                self:setInfoText(EasyDevUtils.getText("easyDevControls_requestFailedMessage"))
                            end
                        else
                            local numUpdated = 0

                            for _, productionPoint in ipairs(self.currentProductionPoints) do
                                if self.easyDevControls:setProductionPointFillLevels(productionPoint, fillLevel, nil, isOutput, true) then
                                    numUpdated = numUpdated + 1
                                end
                            end

                            if self.isServer then
                                local modeL10N = isOutput and "easyDevControls_output" or "easyDevControls_input"
                                local typeText = EasyDevUtils.getTypeText("PRODUCTION_POINT", numUpdated)

                                self:setInfoText(EasyDevUtils.formatText("easyDevControls_productionPointFillLevelAllInfo", EasyDevUtils.getText(modeL10N):lower(), numUpdated, typeText))
                            else
                                self:setInfoText(EasyDevUtils.getText("easyDevControls_serverRequestMessage"))
                            end
                        end
                    end
                end
            }
        }
    }
end

function EasyDevControlsPlaceablesFrame:updateProductionPointsData(dataName)
    local ppData = self.productionPointData

    if ppData.productionPointOwner == nil or ppData.productionPointState == nil or ppData.productionPointOutputMode == nil or ppData.productionPointFillLevel == nil then
        self:initProductionPointData()
    end

    if dataName ~= nil then
        local data = self.productionPointData[dataName]

        if data ~= nil and self.currentProductionPoints ~= nil then
            local headerText = ""
            local productionPoint
            local currentIndex = self.productionPointIndex

            if currentIndex == EasyDevControlsPlaceablesFrame.PRODUCTION_POINT_ALL_NPC then
                headerText = string.format("%s %s", EasyDevUtils.getText("easyDevControls_all"), EasyDevUtils.getText("easyDevControls_npcOwned"))
            elseif currentIndex == EasyDevControlsPlaceablesFrame.PRODUCTION_POINT_ALL_FARM then
                headerText = string.format("%s %s", EasyDevUtils.getText("easyDevControls_all"), EasyDevUtils.getText("easyDevControls_farmOwned"))
            else
                productionPoint = self.currentProductionPoints[1]

                if productionPoint == nil then
                    return nil
                end

                headerText = productionPoint:getName() or g_fillTypeManager:getFillTypeTitleByIndex(productionPoint.primaryProductFillType)
            end

            data.headerText = headerText

            if dataName == "productionPointOwner" then
                local numFarms = #g_farmManager.farms
                local lastIndex = 1

                if #self.farmIDs ~= numFarms or #self.farmTexts ~= numFarms then
                    self:collectFarmsInfo()
                end

                if currentIndex > EasyDevControlsPlaceablesFrame.PRODUCTION_POINT_ALL_NPC then
                    local farmId = FarmManager.SPECTATOR_FARM_ID

                    if currentIndex == EasyDevControlsPlaceablesFrame.PRODUCTION_POINT_ALL_FARM then
                        farmId = g_currentMission:getFarmId() or farmId
                    else
                        farmId = productionPoint:getOwnerFarmId() or farmId
                    end

                    for index, id in ipairs (self.farmIDs) do
                        if id == farmId then
                            lastIndex = index

                            break
                        end
                    end
                end

                data.properties[1].texts = self.farmTexts
                data.properties[1].lastIndex = lastIndex
            elseif (dataName == "productionPointState") or (dataName == "productionPointOutputMode") then
                local isOuputMode = dataName == "productionPointOutputMode"

                local firstIndex
                local synced = true

                local variableIDs = {
                    EMPTY_TABLE
                }

                local texts = {
                    EasyDevUtils.getText("easyDevControls_all")
                }

                local lastSetIndexs = {
                    0
                }

                local disabledIndexs = {
                    0
                }

                for _, pp in ipairs(self.currentProductionPoints) do
                    if isOuputMode then
                        for outputFillTypeIndex in pairs(pp.outputFillTypeIds) do
                            local distributionMode = pp:getOutputDistributionMode(outputFillTypeIndex) + 1

                            if firstIndex == nil then
                                firstIndex = distributionMode
                            else
                                if firstIndex ~= distributionMode then
                                    synced = false
                                end
                            end

                            if currentIndex > EasyDevControlsPlaceablesFrame.PRODUCTION_POINT_ALL_FARM then
                                local fillType = g_fillTypeManager:getFillTypeByIndex(outputFillTypeIndex)

                                table.insert(variableIDs, outputFillTypeIndex)
                                table.insert(texts, fillType.title)

                                table.insert(lastSetIndexs, distributionMode)
                                table.insert(disabledIndexs, distributionMode)
                            end
                        end
                    else
                        for _, production in pairs(pp.productions) do
                            local statusIndex = pp:getIsProductionEnabled(production.id) and 2 or 1

                            if firstIndex == nil then
                                firstIndex = statusIndex
                            else
                                if firstIndex ~= statusIndex then
                                    synced = false
                                end
                            end

                            if currentIndex > EasyDevControlsPlaceablesFrame.PRODUCTION_POINT_ALL_FARM then
                                table.insert(variableIDs, production.id)
                                table.insert(texts, production.name)

                                table.insert(lastSetIndexs, statusIndex)
                                table.insert(disabledIndexs, statusIndex)
                            end
                        end
                    end
                end

                if synced and firstIndex ~= nil then
                    lastSetIndexs[1] = firstIndex
                    disabledIndexs[1] = firstIndex
                end

                data.properties[1].texts = texts
                data.properties[1].disabled = currentIndex < EasyDevControlsPlaceablesFrame.PRODUCTION_POINT_TRIGGER

                data.variableIDs = variableIDs
                data.lastSetIndexs = lastSetIndexs
                data.disabledIndexs = disabledIndexs
            elseif dataName == "productionPointFillLevel" then
                local allText = EasyDevUtils.getText("easyDevControls_all")
                local maximumText = EasyDevUtils.getText("easyDevControls_maximum")
                local disabled = true

                local fillTypes = {
                    {
                        EMPTY_TABLE
                    },
                    {
                        EMPTY_TABLE
                    }
                }

                local fillTypeTexts = {
                    {
                        allText
                    },
                    {
                        allText
                    }
                }

                local maxFillLevels = {
                    {
                        1e+7
                    },
                    {
                        1e+7
                    }
                }

                local maxFillLevelTexts = {
                    {
                        maximumText
                    },
                    {
                        maximumText
                    }
                }

                if currentIndex > EasyDevControlsPlaceablesFrame.PRODUCTION_POINT_ALL_FARM then
                    for _, pp in ipairs(self.currentProductionPoints) do
                        for i, typeName in ipairs (data.types) do
                            local variable = pp[typeName]

                            if variable ~= nil then
                                for fillTypeIndex in pairs(variable) do
                                    local fillType = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)
                                    local capacity, capacityText = 0, ""

                                    if i == 1 then
                                        for _, targetStorage in pairs(pp.unloadingStation.targetStorages) do
                                            if targetStorage:getIsFillTypeSupported(fillTypeIndex) then
                                                local storageCapacity = targetStorage:getCapacity(fillTypeIndex)

                                                if storageCapacity ~= nil then
                                                    capacity = capacity + storageCapacity
                                                end
                                            end
                                        end
                                    else
                                        capacity = pp.storage:getCapacity(fillTypeIndex) or 0
                                    end

                                    if capacity == 0 then
                                        capacity = 1e+7
                                        capacityText = maximumText
                                    else
                                        capacityText = g_i18n:formatFluid(capacity)
                                    end

                                    table.insert(fillTypes[i], fillTypeIndex)
                                    table.insert(fillTypeTexts[i], fillType.title)

                                    table.insert(maxFillLevels[i], capacity)
                                    table.insert(maxFillLevelTexts[i], capacityText)

                                    disabled = false
                                end
                            end
                        end
                    end
                end

                data.properties[2].disabled = disabled

                for i = 1, #data.properties do
                    data.properties[i].lastIndex = 1
                end

                data.fillTypes = fillTypes
                data.fillTypeTexts = fillTypeTexts

                data.lastSetIndexs = {}
                data.inputTypeIndex = 1

                data.maxFillLevels = maxFillLevels
                data.maxFillLevelTexts = maxFillLevelTexts
            end

            return data
        end
    end

    return nil
end

-- Production Points List
function EasyDevControlsPlaceablesFrame:onClickProductionPointsList(element)
    local headerText = EasyDevUtils.getText("easyDevControls_productionPointListTitle")
    local list = {}

    if #self.productionPoints > 3 then
        local infoText = "  - %s:  %i / %i\n  - %s:  %s (%i)\n  - %s:  %s\n  - %s:  %s\n  - %s:  %s"

        local activeText = EasyDevUtils.getText("easyDevControls_activeProductions")
        local ownerText = EasyDevUtils.getText("easyDevControls_owner")
        local priceText = EasyDevUtils.getText("easyDevControls_price")
        local locationText = EasyDevUtils.getText("easyDevControls_location")
        local tableIdText = EasyDevUtils.getText("easyDevControls_tableId")

        local farm = g_farmManager.farmIdToFarm[g_currentMission:getFarmId()]

        for i = 4, #self.productionPoints do
            local pp = self.productionPoints[i][1]

            if pp ~= nil then
                local owningPlaceable = pp.owningPlaceable
                local location = EasyDevUtils.getObjectLocationString(owningPlaceable.rootNode, owningPlaceable)
                local idString = self.productionPointIndexTexts[pp] or "PP xx"
                local ownerName = "NPC"
                local price = 0

                if pp.ownerFarmId ~= FarmManager.SPECTATOR_FARM_ID then
                    ownerName = farm ~= nil and farm.name or "N/A"

                    price = owningPlaceable:getSellPrice()
                else
                    local storeItem = g_storeManager:getItemByXMLFilename(owningPlaceable.configFileName)

                    price = g_currentMission.economyManager:getBuyPrice(storeItem) or owningPlaceable:getPrice()

                    if owningPlaceable.buysFarmland and owningPlaceable.farmlandId ~= nil then
                        local farmland = g_farmlandManager:getFarmlandById(owningPlaceable.farmlandId)

                        if farmland ~= nil and g_farmlandManager:getFarmlandOwner(owningPlaceable.farmlandId) ~= g_currentMission:getFarmId() then
                            price = price + farmland.price
                        end
                    end
                end

                price = g_i18n:formatMoney(price, 0, true, true)

                table.insert(list, {
                    overlayColour = EasyDevUtils.OVERLAY_COLOUR_PRODUCTION_POINT,
                    title = string.format("%s  | %s", idString, pp:getName()),
                    text = string.format(infoText, activeText, #pp.activeProductions, #pp.productions, ownerText, ownerName, pp.ownerFarmId, priceText, price, locationText, location, tableIdText, pp:tableId())
                })
            end
        end
    end

    self.ui:showDynamicListDialog({
        headerText = headerText,
        callback = nil,
        target = nil,
        list = list
    })
end

-- Delivery Mapping
function EasyDevControlsPlaceablesFrame:onClickAutoDeliverMapping(element)
    local headerText = EasyDevUtils.getText("easyDevControls_deliveryMappingTitle")
    local list = {}

    local farmId = g_currentMission:getFarmId()
    local farmProductionChains = g_currentMission.productionChainManager.farmIds[farmId]

    if farmProductionChains ~= nil and farmProductionChains.inputTypeToProductionPoints ~= nil then
        local transferCostText = EasyDevUtils.getText("easyDevControls_transferCost")
        local tableIdText = EasyDevUtils.getText("easyDevControls_tableId")
        local receivingText = "%s\n        - %s  |  %s\n            - %s / 1000 l:  %s\n            - %s:  %s"

        for i = 4, #self.productionPoints do
            local productionPoint = self.productionPoints[i][1]

            if productionPoint and productionPoint.ownerFarmId == farmId then
                local text = ""

                for fillTypeIndex in pairs (productionPoint.outputFillTypeIds) do
                    if productionPoint:getOutputDistributionMode(fillTypeIndex) == ProductionPoint.OUTPUT_MODE.AUTO_DELIVER then
                        local receivingProductionPoints = farmProductionChains.inputTypeToProductionPoints[fillTypeIndex]
                        local fillType = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)

                        if text == "" then
                            text = "    "
                        else
                            text = text .. "\n\n    "
                        end

                        text = text .. EasyDevUtils.formatText("easyDevControls_productionPointDistributingInfo", fillType.title)

                        if receivingProductionPoints ~= nil then
                            for _, receivingProductionPoint in pairs(receivingProductionPoints) do
                                local index = self:getProductionPointIndex(receivingProductionPoint)

                                if index > 0 then
                                    local idString = self.productionPointIndexTexts[receivingProductionPoint] or "PP xx"
                                    local distance = calcDistanceFrom(productionPoint.owningPlaceable.rootNode, receivingProductionPoint.owningPlaceable.rootNode)
                                    local transferCost = g_i18n:formatMoney(1000 * distance * ProductionPoint.DIRECT_DELIVERY_PRICE, 2, true, true)

                                    text = string.format(receivingText, text, idString, receivingProductionPoint:getName(), transferCostText, transferCost, tableIdText, receivingProductionPoint:tableId())
                                end
                            end
                        else
                            text = string.format("%s\n        - %s", text, self.noneText)
                        end
                    end
                end

                if text ~= "" then
                    local idString = self.productionPointIndexTexts[productionPoint] or "PP xx"

                    table.insert(list, {
                        overlayColour = EasyDevUtils.OVERLAY_COLOUR_PRODUCTION_POINT,
                        title = string.format("%s  | %s", idString, productionPoint:getName()),
                        text = text
                    })
                end
            end
        end
    end

    self.ui:showDynamicListDialog({
        headerText = headerText,
        callback = nil,
        target = nil,
        list = list
    })
end

-- Production Points Debug
function EasyDevControlsPlaceablesFrame:onClickProductionPointsDebug(index, element)
    if g_easyDevDebugProduction ~= nil then
        local active = self:getIsCheckedIndex(index)
        local isActive = g_easyDevDebugProduction:setActive(active)

        if active ~= isActive then
            element:setState(isActive)
        end
    end
end

-- Show Placeable Test Areas
function EasyDevControlsPlaceablesFrame:onClickShowPlaceableTestAreas(index, element)
    local placeableSystem = g_currentMission.placeableSystem
    local renderingActive = self:getIsCheckedIndex(index)

    if placeableSystem ~= nil then
        if (renderingActive and not placeableSystem.isTestAreaRenderingActive) or (not renderingActive and placeableSystem.isTestAreaRenderingActive) then
            placeableSystem:consoleCommandPlaceableTestAreas()
        end
    end
end

-- Show Placement Collisions
function EasyDevControlsPlaceablesFrame:onClickShowPlacementCollisions(index, element)
    if g_easyDevDebugPlacementCollisions ~= nil then
        local active = self:getIsCheckedIndex(index)
        local isActive = g_easyDevDebugPlacementCollisions:setActive(active)

        if active ~= isActive then
            element:setState(isActive)
        end
    end
end

-- Reload All Placeables
function EasyDevControlsPlaceablesFrame:onClickReloadPlaceables(element)
    local closestPlaceable = nil

    if element.name == "reloadPlaceable" then
        closestPlaceable = self.closestPlaceable
    end

    local resultFunction = function(numReloaded, failedToReload)
        self:setInfoText(EasyDevUtils.formatText("easyDevControls_reloadPlaceablesInfo", numReloaded, EasyDevUtils.getTypeText("PLACEABLE", numReloaded)))

        element:setDisabled(true)

        if closestPlaceable == nil then
            self.buttonConfirmReloadPlaceable:setDisabled(true)
        end

        if failedToReload ~= nil and #failedToReload > 0 then
            local headerText = EasyDevUtils.getText("easyDevControls_requestFailedMessage")
            local list = {
                {title = EasyDevUtils.formatText("easyDevControls_reloadFailedMessage", EasyDevUtils.getText("easyDevControls_typePlaceables"))}
            }

            for i = 1, #failedToReload do
                table.insert(list, {text = string.format("%i:  %s", i, failedToReload[i])})
            end

            self.ui:showDynamicListDialog({
                headerText = headerText,
                list = list
            })
        end
    end

    self:setInfoText(self.easyDevControls:reloadPlaceables(closestPlaceable, resultFunction))
end

-- Remove All Placeables / Map Placeables
function EasyDevControlsPlaceablesFrame:onClickConfirmRemoveAllPlaceables(element)
    local typeIndex = EasyDevControlsRemoveAllObjectsEvent[element.name]

    if typeIndex ~= nil then
        local text = "easyDevControls_typePlaceables"

        if typeIndex == EasyDevControlsRemoveAllObjectsEvent.MAP_PLACEABLES then
            text = "easyDevControls_typePrePlacedPlaceables"
        end

        local function removeAllPlaceables(yes)
            if yes then
                element:setDisabled(true)
                self:setInfoText(self.easyDevControls:removeAllObjects(typeIndex))
            end
        end

        g_gui:showYesNoDialog({
            text = EasyDevUtils.formatText("easyDevControls_removeAllObjectsWarning", EasyDevUtils.getText(text)),
            yesText = g_i18n:getText("button_continue"),
            noText = g_i18n:getText("button_cancel"),
            callback = removeAllPlaceables
        })
    end
end

function EasyDevControlsPlaceablesFrame:collectFarmsInfo()
    local farmIDs = {
        FarmManager.SPECTATOR_FARM_ID
    }

    local farmTexts = {
        "NPC"
    }

    for _, farm in ipairs(g_farmManager.farms) do
        if not farm.isSpectator then
            table.insert(farmIDs, farm.farmId)
            table.insert(farmTexts, farm.name)
        end
    end

    self.farmIDs = farmIDs
    self.farmTexts = farmTexts
end

function EasyDevControlsPlaceablesFrame:getProductionPointIndex(productionPoint)
    if productionPoint ~= nil then
        for i = 4, #self.productionPoints do
            if self.productionPoints[i][1] == productionPoint then
                return i - 3
            end
        end
    end

    return 0
end

-- Listeners
function EasyDevControlsPlaceablesFrame:onSettingChanged(id, value)
end

function EasyDevControlsPlaceablesFrame:onProductionsChanged(reloaded)
    self:initProductionPointsInfo()
end

function EasyDevControlsPlaceablesFrame:onDynamicSelectionDialogClosed(args)
    self.productionPointDialog = nil
end

function EasyDevControlsPlaceablesFrame:onFarmCreated(farmId)
    if self.productionPointDialog ~= nil then
        self.productionPointDialog:close()

        self:collectFarmsInfo()
        self:initProductionPointsInfo()

        self:setInfoText(string.format("Info: ID - 1 (%s)", g_i18n:getText("button_mp_createFarm")))
    end
end

function EasyDevControlsPlaceablesFrame:onFarmDeleted(farmId)
    if self.productionPointDialog ~= nil then
        self.productionPointDialog:close()

        self:collectFarmsInfo()
        self:initProductionPointsInfo()

        self:setInfoText(string.format("Info: ID - 2 (%s)", g_i18n:getText("button_mp_deleteFarm")))
    end
end

-- Extras
function EasyDevControlsPlaceablesFrame:getResetValues()
    return {
        checkedProductionPointsDebug = {
            value = CheckedOptionElement.STATE_UNCHECKED
        },
        checkedShowPlaceableTestAreas = {
            value = CheckedOptionElement.STATE_UNCHECKED
        },
        checkedShowPlacementCollisions = {
            value = CheckedOptionElement.STATE_UNCHECKED
        }
    }
end
