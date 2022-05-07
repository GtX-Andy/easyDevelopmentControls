--[[
Copyright (C) GtX (Andy), 2019

Author: GtX | Andy
Date: 07.04.2019
Revision: FS22-01

Contact:
https://forum.giants-software.com
https://github.com/GtX-Andy

Important:
Not to be added to any mods / maps or modified from its current release form.
No modifications may be made to this script, including conversion to other game versions without written permission from GtX | Andy

Darf nicht zu Mods / Maps hinzugefügt oder von der aktuellen Release-Form geändert werden.
Ohne schriftliche Genehmigung von GtX | Andy dürfen keine Änderungen an diesem Skript vorgenommen werden, einschließlich der Konvertierung in andere Spielversionen
]]

EasyDevControlsFieldsFrame = {}

local EasyDevControlsFieldsFrame_mt = Class(EasyDevControlsFieldsFrame, EasyDevControlsBaseFrame)
local EMPTY_TABLE = {}

EasyDevControlsFieldsFrame.L10N_SYMBOL = {}

EasyDevControlsFieldsFrame.CONTROLS = {
    "buttonFieldSetFruit",
    "buttonFieldSetGround",
    "checkedVineSetStateFruitType",
    "checkedVineSetStateGrowthState",
    "buttonConfirmVineSetState",
    "textDisplayWeeds",
    "buttonRemoveWeeds",
    "buttonAddWeeds",
    "textDisplayStones",
    "buttonRemoveStones",
    "buttonAddStones",
    "buttonConfirmAdvanceGrowth",
    "multiGrowthPeriod",
    "buttonConfirmGrowthPeriod",
    "multiSetFarmlandOwnerSortBy",
    "multiSetFarmlandFarmId",
    "multiSetFarmlandOwnerIndex",
    "buttonConfirmSetFarmlandOwner",
    "textRefreshFieldOverlay",
    "buttonRefreshFieldOverlay",
    "multiDebugFieldStatusRange",
    "checkedDebugFieldStatus",
    "checkedDebugVineSystem",
    "checkedDebugStoneSystem"
}

function EasyDevControlsFieldsFrame.new(ui, easyDevControls, accessLevel)
    local self = EasyDevControlsBaseFrame.new(EasyDevControlsFieldsFrame_mt, ui, easyDevControls, accessLevel)

    self:registerControls(EasyDevControlsFieldsFrame.CONTROLS)

    self.fieldRefreshingTimer = -1
    self.setFarmlandOwner = {}

    return self
end

function EasyDevControlsFieldsFrame:initialize()
    self.lastGrowthStates = {}

    self:initializeSetFieldDialogData()
    self:createSetFieldDialogData()

    self.vineFruitTypeData = {}
    self.vineNone = {
        g_i18n:getText("ui_none")
    }

    self.vineFruitTypeTexts = {}
    self.vineFruitTypes = {}

    self.vineGrowthStateTexts = {}
    self.vineGrowthStates = {}

    self.multiDebugFieldStatusRange:setTexts(EasyDevUtils.getFormatedRangeTexts())

    self.formattedSecondsText = EasyDevUtils.getText("easyDevControls_formattedSeconds")
    self.buttonRefreshFieldOverlay:setImageFilename(nil, self.ui.iconsUIFilename)

    self.multiSetFarmlandOwnerSortBy:setTexts({
        EasyDevUtils.getText("easyDevControls_farmlandTitle"),
        EasyDevUtils.getText("easyDevControls_fieldIndexTitle")
    })
end

function EasyDevControlsFieldsFrame:subscribeToMessages(messageCenter)
    -- messageCenter:subscribe(EasyDevUtils.MESSAGE_TYPE_SETTINGS_CHANGED, self.onSettingChanged, self)
end

function EasyDevControlsFieldsFrame:updateAvailableProperties()
    local mission = g_currentMission
    local missionInfo = mission.missionInfo

    local startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, posX, posZ = EasyDevUtils.getProjectedArea(5, 5, 2, false)
    local _, fieldArea, _ = FSDensityMapUtil.getFieldDensity(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ)

    local currentFieldIndex = 0
    local currentFieldText = ""

    local disabledText = EasyDevUtils.getText("easyDevControls_disabled")

    if fieldArea ~= 0 then
        local farmland = g_farmlandManager:getFarmlandAtWorldPosition(posX, posZ)

        if farmland ~= nil then
            local lastDistance = math.huge

            for _, field in ipairs (g_fieldManager.farmlandIdFieldMapping[farmland.id] or EMPTY_TABLE) do
                local distance = MathUtil.vector2Length(posX - field.posX, posZ - field.posZ)

                if distance < lastDistance then
                    lastDistance = distance
                    currentFieldIndex = field.fieldId
                end
            end
        end
    end

    self.farmId = mission:getFarmId()
    self.playerOnField = currentFieldIndex ~= 0
    self.currentFieldIndex = currentFieldIndex

    if self.playerOnField then
        currentFieldText = string.format("%s %d", EasyDevUtils.getText("easyDevControls_fieldIndexTitle"), self.currentFieldIndex)
    else
        currentFieldText = EasyDevUtils.getText("easyDevControls_noField")
    end

    if mission.hud ~= nil then
        self.ingameMap = mission.hud:getIngameMap()
    end

    if self.ingameMap == nil then
        self.textRefreshFieldOverlay:setText("...")
    end

    self.weedsEnabled = missionInfo.weedsEnabled and mission.weedSystem:getMapHasWeed()
    self.stonesEnabled = missionInfo.stonesEnabled and mission.stoneSystem:getMapHasStones()

    -- Set Field Fruit
    self.fieldSetFruitDisabled = self:getIsPropertyDisabled("fieldSetFruit")
    self.buttonFieldSetFruit:setDisabled(self.fieldSetFruitDisabled)

    -- Set Field Ground
    self.fieldSetGroundDisabled = self:getIsPropertyDisabled("fieldSetGround")
    self.buttonFieldSetGround:setDisabled(self.fieldSetGroundDisabled)

    -- Vine System Set State
    local vineSetStateDisabled = true
    local numFarmVines = 0

    local fruitTypeTexts = self.vineNone
    local grothStateTexts = self.vineNone

    local accessHandler = g_currentMission.accessHandler

    for placeable, _ in pairs(EasyDevUtils.getVinePlaceables()) do
        if accessHandler:canFarmAccessOtherId(self.farmId, placeable:getOwnerFarmId()) then
            self:updateVineGrowthAndFruitData(placeable:getVineFruitType())

            numFarmVines = numFarmVines + 1
        end
    end

    if next(self.vineFruitTypeData) ~= nil then
        if numFarmVines > 0 then
            vineSetStateDisabled = self:getIsPropertyDisabled("vineSetState")

            fruitTypeTexts = self.vineFruitTypeTexts
            grothStateTexts = self.vineGrowthStateTexts[1]
        else
            self.vineFruitTypeData = {}
        end
    end

    self.checkedVineSetStateFruitType:setTexts(fruitTypeTexts)
    self.checkedVineSetStateFruitType:setState(1)

    self.checkedVineSetStateGrowthState:setTexts(grothStateTexts)
    self.checkedVineSetStateGrowthState:setState(1)

    self.checkedVineSetStateFruitType:setDisabled(vineSetStateDisabled)
    self.checkedVineSetStateGrowthState:setDisabled(vineSetStateDisabled)
    self.buttonConfirmVineSetState:setDisabled(vineSetStateDisabled)

    self.vineSetStateDisabled = vineSetStateDisabled

    -- Add / Remove Weeds | Stones
    local addRemoveDisabled = self:getIsPropertyDisabled("addRemoveWeedsStones")

    local weedsDisplayText = disabledText
    local weedsDisabled = true

    local stonesDisplayText = disabledText
    local stonesDisabled = true

    if not addRemoveDisabled then
        if self.weedsEnabled then
            weedsDisplayText = currentFieldText
            weedsDisabled = not self.playerOnField
        end

        if self.stonesEnabled then
            stonesDisplayText = currentFieldText
            stonesDisabled = not self.playerOnField
        end
    end

    self.textDisplayWeeds:setText(weedsDisplayText)
    self.textDisplayStones:setText(stonesDisplayText)

    self.buttonRemoveWeeds:setDisabled(addRemoveDisabled or weedsDisabled)
    self.buttonAddWeeds:setDisabled(addRemoveDisabled or weedsDisabled)

    self.buttonRemoveStones:setDisabled(addRemoveDisabled or stonesDisabled)
    self.buttonAddStones:setDisabled(addRemoveDisabled or stonesDisabled)

    -- Advance Growth
    self.updateGrowthSystemDisabled = self:getIsPropertyDisabled("updateGrowthSystem")
    self.buttonConfirmAdvanceGrowth:setDisabled(self.updateGrowthSystemDisabled)

    -- Set Seasonal Growth Period
    self.multiGrowthPeriod:setState(EasyDevUtils.getMonthFromPeriod())

    self.multiGrowthPeriod:setDisabled(self.updateGrowthSystemDisabled)
    self.buttonConfirmGrowthPeriod:setDisabled(self.updateGrowthSystemDisabled)

    -- Set Farmland Owner
    local setFarmlandOwnerDisabled = self:getIsPropertyDisabled("setFarmlandOwner")

    local farmTexts = {
        "NPC"
    }

    self.setFarmlandOwner.farmIds = {
        FarmlandManager.NO_OWNER_FARM_ID
    }

    local farm = g_farmManager:getFarmById(self.farmId)

    if farm ~= nil and farm.farmId ~= FarmManager.SPECTATOR_FARM_ID then
        farmTexts[2] = farm.name
        self.setFarmlandOwner.farmIds[2] = farm.farmId
    end

    -- for _, farm in ipairs(g_farmManager:getFarms()) do
        -- if farm.isSpectator then
            -- table.insert(farmTexts, "NPC")
            -- table.insert(self.setFarmlandOwner.farmIds, FarmlandManager.NO_OWNER_FARM_ID)
        -- else
            -- table.insert(farmTexts, farm.name)
            -- table.insert(self.setFarmlandOwner.farmIds, farm.farmId)
        -- end
    -- end

    self.multiSetFarmlandFarmId:setTexts(farmTexts)

    if self.setFarmlandOwner.farmlandTexts == nil or self.setFarmlandOwner.farmlandIds == nil then
        local fieldText = EasyDevUtils.getText("easyDevControls_fieldIndexTitle")
        local farmlandText = EasyDevUtils.getText("easyDevControls_farmlandTitle")
        local allText = EasyDevUtils.getText("easyDevControls_all")

        self.setFarmlandOwner.farmlandTexts = {
            {allText},
            {allText}
        }

        self.setFarmlandOwner.farmlandIds = {
            {0},
            {0}
        }

        self.setFarmlandOwner.lastIndexs = {
            1,
            1
        }

        for _, farmland in pairs (g_farmlandManager:getFarmlands()) do
            table.insert(self.setFarmlandOwner.farmlandIds[1], farmland.id)
        end

        table.sort(self.setFarmlandOwner.farmlandIds[1])

        for i = 2, #self.setFarmlandOwner.farmlandIds[1] do
            table.insert(self.setFarmlandOwner.farmlandTexts[1], string.format("%s %d", farmlandText, self.setFarmlandOwner.farmlandIds[1][i]))
        end

        for _, field in ipairs(g_fieldManager:getFields()) do
            table.insert(self.setFarmlandOwner.farmlandTexts[2], string.format("%s %d", fieldText, field.fieldId))
            table.insert(self.setFarmlandOwner.farmlandIds[2], field.farmland.id)
        end

        self.setFarmlandOwner.sortBy = 1
        self.setFarmlandOwner.farmId = FarmlandManager.NO_OWNER_FARM_ID
        -- self.setFarmlandOwner.farmlandId = self.setFarmlandOwner.farmlandIds[1][1]

        self.multiSetFarmlandOwnerIndex:setTexts(self.setFarmlandOwner.farmlandTexts[1])
        self.multiSetFarmlandOwnerIndex:setState(self.setFarmlandOwner.lastIndexs[1])
    end

    self.multiSetFarmlandOwnerSortBy:setDisabled(setFarmlandOwnerDisabled)
    self.multiSetFarmlandFarmId:setDisabled(setFarmlandOwnerDisabled)
    self.multiSetFarmlandOwnerIndex:setDisabled(setFarmlandOwnerDisabled)
    self.buttonConfirmSetFarmlandOwner:setDisabled(setFarmlandOwnerDisabled)

    self.setFarmlandOwnerDisabled = setFarmlandOwnerDisabled
    self.multiSetFarmlandOwnerSortBy:setState(self.setFarmlandOwner.sortBy, true)

    -- Field Status Debug
    self.multiDebugFieldStatusRange:setState(EasyDevUtils.getDefaultRangeValue(FieldManager.DEBUG_SHOW_FIELDSTATUS_SIZE, true))
    self.checkedDebugFieldStatus:setIsChecked(FieldManager.DEBUG_SHOW_FIELDSTATUS)

    -- Vine System Debug
    self.checkedDebugVineSystem:setIsChecked(mission.vineSystem.isDebugAreaActive)

    -- Stone System Debug
    self.checkedDebugStoneSystem:setIsChecked((self.stonesEnabled and mission.stoneSystem.isDebugAreaActive) or false)
    self.checkedDebugStoneSystem:setDisabled(not self.stonesEnabled)

    EasyDevControlsFieldsFrame:superClass().updateAvailableProperties(self)
end

function EasyDevControlsFieldsFrame:update(dt)
    EasyDevControlsFieldsFrame:superClass().update(self, dt)

    if self.ingameMap ~= nil and self.ingameMap.fieldRefreshTimer ~= nil then
        if self.fieldRefreshingTimer < 0 then
            self.textRefreshFieldOverlay:setText(self.formattedSecondsText:format(math.floor((IngameMap.FIELD_REFRESH_INTERVAL - self.ingameMap.fieldRefreshTimer) / 1000) + 0.5))
        else
            self.fieldRefreshingTimer = self.fieldRefreshingTimer - dt
        end
    end
end

-- Field Set Fruit / Ground
function EasyDevControlsFieldsFrame:initializeSetFieldDialogData()
    local fieldTexts, fieldIndexs = self:getFieldTexts()
    local growthStateTexts, fruitTypeTexts, fruitTypes = self:getGrowthAndFruitData()
    local groundLayerTexts, groundLayers = self:getGroundLayerData()
    local weedStateTexts, weedStates = self:getWeedData()
    local angleTexts, angles = self:getAngleData()
    local groundTypeTexts, groundTypes = self:getGroundTypeData()
    local stoneStateTexts, stoneStates = self:getStoneData()

    local tripleStates = {
        0,
        1,
        2
    }

    local tripleStateTexts = {
        "0 %",
        "50 %",
        "100 %"
    }

    local onOffStates = {
        0,
        1
    }

    self.setFieldIndexs = fieldIndexs
    self.setFieldFruitTypes = fruitTypes
    self.setFieldGroundLayers = groundLayers
    self.setFieldFertilizerStates = tripleStates
    self.setFieldPlowingStates = onOffStates
    self.setFieldWeedStates = weedStates
    self.setFieldLimeStates = onOffStates
    self.setFieldStubbleStates = onOffStates
    self.setFieldHerbicideStates = onOffStates
    self.setFieldRollerStates = onOffStates
    self.setFieldStonesStates = stoneStates
    self.setFieldAngles = angles
    self.setGroundTypes = groundTypes

    self.setFieldTexts = {
        setFruit = {
            fieldIndex = fieldTexts,
            fruitIndex = fruitTypeTexts,
            growthState = growthStateTexts,
            groundLayer = groundLayerTexts,
            fertilizerState = tripleStateTexts,
            weedState = weedStateTexts,
            stonesState = stoneStateTexts
        },
        setGround = {
            fieldIndex = fieldTexts,
            groundType = groundTypeTexts,
            angle = angleTexts,
            groundLayer = groundLayerTexts,
            fertilizerState = tripleStateTexts,
            weedState = weedStateTexts,
            stonesState = stoneStateTexts
        }
    }

    self.setFieldData = {
        setFruit = {
            fieldIndex = self.allFieldsIndex,
            fruitIndex = 1,
            growthState = 1,
            groundLayer = 1,
            fertilizerState = 1,
            plowingState = 1,
            weedState = 1,
            limeState = 1,
            herbicideState = 1,
            rollerState = 1,
            stonesState = 1,
            stubbleState = 1,
            buyFarmland = false
        },
        setGround = {
            fieldIndex = self.allFieldsIndex,
            groundType = 1,
            angle = 1,
            groundLayer = 1,
            fertilizerState = 1,
            plowingState = 1,
            weedState = 1,
            limeState = 1,
            herbicideState = 1,
            rollerState = 1,
            stonesState = 1,
            stubbleState = 1,
            removeFoliage = true,
            buyFarmland = false
        }
    }
end

function EasyDevControlsFieldsFrame:createSetFieldDialogData()
    local setFruitTexts = self.setFieldTexts.setFruit

    local function updateButtonOnConfirm(dialog)
        -- Allow the confirm buttons again after any change

        if dialog.buttonOnConfirmElement:getIsDisabled() then
            dialog.buttonOnConfirmElement:setDisabled(false)
        end

        if dialog.confirmButton:getIsDisabled() then
            dialog.confirmButton:setDisabled(false)
        end
    end

    local function sharedFieldFruitCallback(dialog, index, element)
        self.setFieldData.setFruit[element.name] = index

        updateButtonOnConfirm(dialog)
    end

    local setGroundTexts = self.setFieldTexts.setGround

    local function sharedFieldGroundCallback(dialog, index, element)
        self.setFieldData.setGround[element.name] = index

        updateButtonOnConfirm(dialog)
    end

    local setFruitProperties = {
        {
            typeId = DynamicSelectionDialog.TYPE_MULTI_TEXT_OPTION,
            title = EasyDevUtils.getText("easyDevControls_fieldIndexTitle"),
            name = "fieldIndex",
            texts = setFruitTexts.fieldIndex,
            onClickCallback = sharedFieldFruitCallback
        },
        {
            typeId = DynamicSelectionDialog.TYPE_MULTI_TEXT_OPTION,
            title = EasyDevUtils.getText("easyDevControls_fruitTypeTitle"),
            dynamicId = "multiFruitIndexElement",
            name = "fruitIndex",
            forceState = true,
            texts = setFruitTexts.fruitIndex,
            onClickCallback = function(dialog, index, element)
                local lastGrowthIndex = self.lastGrowthStates[index] or 1

                dialog.multiGrowthStateElement:setTexts(self.setFieldTexts.setFruit.growthState[index])
                dialog.multiGrowthStateElement:setState(lastGrowthIndex)

                self.setFieldData.setFruit.growthState = lastGrowthIndex
                self.setFieldData.setFruit[element.name] = index

                updateButtonOnConfirm(dialog)
            end
        },
        {
            typeId = DynamicSelectionDialog.TYPE_MULTI_TEXT_OPTION,
            title = EasyDevUtils.getText("easyDevControls_growthStateTitle"),
            dynamicId = "multiGrowthStateElement",
            name = "growthState",
            onClickCallback = function(dialog, index, element)
                self.setFieldData.setFruit[element.name] = index
                self.lastGrowthStates[dialog.multiFruitIndexElement.state] = index

                updateButtonOnConfirm(dialog)
            end
        },
        {
            typeId = DynamicSelectionDialog.TYPE_MULTI_TEXT_OPTION,
            title = EasyDevUtils.getText("easyDevControls_groundLayerTitle"),
            name = "groundLayer", -- sprayState
            texts = setFruitTexts.groundLayer,
            onClickCallback = sharedFieldFruitCallback
        },
        {
            typeId = DynamicSelectionDialog.TYPE_MULTI_TEXT_OPTION,
            title = EasyDevUtils.getText("easyDevControls_fertilizerStateTitle"),
            name = "fertilizerState",
            texts = setFruitTexts.fertilizerState,
            onClickCallback = sharedFieldFruitCallback
        },
        {
            typeId = DynamicSelectionDialog.TYPE_CHECKED_OPTION,
            title = EasyDevUtils.getText("easyDevControls_plowingStateTitle"),
            name = "plowingState",
            useYesNoTexts = true,
            onClickCallback = sharedFieldFruitCallback
        },
        {
            typeId = DynamicSelectionDialog.TYPE_MULTI_TEXT_OPTION,
            title = EasyDevUtils.getText("easyDevControls_weedStateTitle"),
            name = "weedState",
            disabled = not g_currentMission.missionInfo.weedsEnabled,
            texts = setFruitTexts.weedState,
            onClickCallback = sharedFieldFruitCallback
        },
        {
            typeId = DynamicSelectionDialog.TYPE_CHECKED_OPTION,
            title = EasyDevUtils.getText("easyDevControls_limeStateTitle"),
            name = "limeState",
            useYesNoTexts = true,
            onClickCallback = sharedFieldFruitCallback
        },
        {
            typeId = DynamicSelectionDialog.TYPE_CHECKED_OPTION,
            title = EasyDevUtils.getText("easyDevControls_herbicideStateTitle"),
            name = "herbicideState",
            useYesNoTexts = true,
            onClickCallback = sharedFieldFruitCallback
        },
        {
            typeId = DynamicSelectionDialog.TYPE_CHECKED_OPTION,
            title = EasyDevUtils.getText("easyDevControls_rollerStateTitle"),
            name = "rollerState",
            useYesNoTexts = true,
            onClickCallback = sharedFieldFruitCallback
        },
        {
            typeId = DynamicSelectionDialog.TYPE_MULTI_TEXT_OPTION,
            title = EasyDevUtils.getText("easyDevControls_stonesStateTitle"),
            name = "stonesState",
            texts = setFruitTexts.stonesState,
            onClickCallback = sharedFieldFruitCallback
        },
        {
            typeId = DynamicSelectionDialog.TYPE_CHECKED_OPTION,
            title = EasyDevUtils.getText("easyDevControls_stubbleStateTitle"),
            name = "stubbleState",
            useYesNoTexts = true,
            onClickCallback = sharedFieldFruitCallback
        },
        {
            typeId = DynamicSelectionDialog.TYPE_CHECKED_OPTION,
            title = EasyDevUtils.getText("easyDevControls_buyFarmlandTitle"),
            name = "buyFarmland",
            useYesNoTexts = true,
            onClickCallback = function(dialog, index, element)
                self.setFieldData.setFruit[element.name] = self:getIsCheckedIndex(index)

                updateButtonOnConfirm(dialog)
            end
        },
        {
            -- Fake, just moves the confirm button over.
            typeId = DynamicSelectionDialog.TYPE_SPACER,
            name = "buttonSpacer"
        },
        {
            typeId = DynamicSelectionDialog.TYPE_BUTTON,
            title = g_i18n:getText("button_confirm"),
            name = "buttonOnConfirm",
            dynamicId = "buttonOnConfirmElement",
            onClickCallback = function(dialog, element)
                self:onClickFieldSetFruit(true)

                element:setDisabled(true)
                dialog.confirmButton:setDisabled(true)
            end
        }
    }

    local setGroundProperties = {
        {
            typeId = DynamicSelectionDialog.TYPE_MULTI_TEXT_OPTION,
            title = EasyDevUtils.getText("easyDevControls_fieldIndexTitle"),
            name = "fieldIndex",
            texts = setGroundTexts.fieldIndex,
            onClickCallback = sharedFieldGroundCallback
        },
        {
            typeId = DynamicSelectionDialog.TYPE_MULTI_TEXT_OPTION,
            title = EasyDevUtils.getText("easyDevControls_groundTypeTitle"),
            name = "groundType",
            texts = setGroundTexts.groundType,
            onClickCallback = sharedFieldGroundCallback
        },
        {
            typeId = DynamicSelectionDialog.TYPE_MULTI_TEXT_OPTION,
            title = EasyDevUtils.getText("easyDevControls_angleTitle"),
            name = "angle",
            texts = setGroundTexts.angle,
            onClickCallback = sharedFieldGroundCallback
        },
        {
            typeId = DynamicSelectionDialog.TYPE_MULTI_TEXT_OPTION,
            title = EasyDevUtils.getText("easyDevControls_groundLayerTitle"),
            name = "groundLayer",
            texts = setGroundTexts.groundLayer,
            onClickCallback = sharedFieldGroundCallback
        },
        {
            typeId = DynamicSelectionDialog.TYPE_MULTI_TEXT_OPTION,
            title = EasyDevUtils.getText("easyDevControls_fertilizerStateTitle"),
            name = "fertilizerState",
            texts = setGroundTexts.fertilizerState,
            onClickCallback = sharedFieldGroundCallback
        },
        {
            typeId = DynamicSelectionDialog.TYPE_CHECKED_OPTION,
            title = EasyDevUtils.getText("easyDevControls_plowingStateTitle"),
            name = "plowingState",
            useYesNoTexts = true,
            onClickCallback = sharedFieldGroundCallback
        },
        {
            typeId = DynamicSelectionDialog.TYPE_CHECKED_OPTION,
            title = EasyDevUtils.getText("easyDevControls_limeStateTitle"),
            name = "limeState",
            useYesNoTexts = true,
            onClickCallback = sharedFieldGroundCallback
        },
        {
            typeId = DynamicSelectionDialog.TYPE_MULTI_TEXT_OPTION,
            title = EasyDevUtils.getText("easyDevControls_weedStateTitle"),
            name = "weedState",
            texts = setGroundTexts.weedState,
            onClickCallback = sharedFieldGroundCallback
        },
        {
            typeId = DynamicSelectionDialog.TYPE_CHECKED_OPTION,
            title = EasyDevUtils.getText("easyDevControls_herbicideStateTitle"),
            name = "herbicideState",
            useYesNoTexts = true,
            onClickCallback = sharedFieldGroundCallback
        },
        {
            typeId = DynamicSelectionDialog.TYPE_CHECKED_OPTION,
            title = EasyDevUtils.getText("easyDevControls_rollerStateTitle"),
            name = "rollerState",
            useYesNoTexts = true,
            onClickCallback = sharedFieldGroundCallback
        },
        {
            typeId = DynamicSelectionDialog.TYPE_MULTI_TEXT_OPTION,
            title = EasyDevUtils.getText("easyDevControls_stonesStateTitle"),
            name = "stonesState",
            texts = setGroundTexts.stonesState,
            onClickCallback = sharedFieldGroundCallback
        },
        {
            typeId = DynamicSelectionDialog.TYPE_CHECKED_OPTION,
            title = EasyDevUtils.getText("easyDevControls_stubbleStateTitle"),
            name = "stubbleState",
            useYesNoTexts = true,
            onClickCallback = sharedFieldGroundCallback
        },
        {
            typeId = DynamicSelectionDialog.TYPE_CHECKED_OPTION,
            title = EasyDevUtils.getText("easyDevControls_removeFoliageTitle"),
            name = "removeFoliage",
            useYesNoTexts = true,
            onClickCallback = function(dialog, index, element)
                self.setFieldData.setGround[element.name] = self:getIsCheckedIndex(index)
                updateButtonOnConfirm(dialog)
            end
        },
        {
            typeId = DynamicSelectionDialog.TYPE_CHECKED_OPTION,
            title = EasyDevUtils.getText("easyDevControls_buyFarmlandTitle"),
            name = "buyFarmland",
            useYesNoTexts = true,
            onClickCallback = function(dialog, index, element)
                self.setFieldData.setGround[element.name] = self:getIsCheckedIndex(index)
                updateButtonOnConfirm(dialog)
            end
        },
        {
            typeId = DynamicSelectionDialog.TYPE_BUTTON,
            title = g_i18n:getText("button_confirm"),
            name = "buttonOnConfirm",
            dynamicId = "buttonOnConfirmElement",
            onClickCallback = function(dialog, element)
                self:onClickFieldSetGround(true)

                element:setDisabled(true)
                dialog.confirmButton:setDisabled(true)
            end
        }
    }

    local confirmText = EasyDevUtils.getText("easyDevControls_buttonConfirmAndClose")

    self.setFieldDialogData = {
        setFruit = {
            headerText = EasyDevUtils.getText("easyDevControls_fieldSetFruitTitle"),
            properties = setFruitProperties,
            numHorizontal = 3,
            numVertical = 5,
            confirmText = confirmText,
            callback = self.onClickFieldSetFruit
        },
        setGround = {
            headerText = EasyDevUtils.getText("easyDevControls_fieldSetGroundTitle"),
            properties = setGroundProperties,
            numHorizontal = 3,
            numVertical = 5,
            confirmText = confirmText,
            callback = self.onClickFieldSetGround
        }
    }
end

function EasyDevControlsFieldsFrame:getFieldTexts()
    local fieldTexts = {}
    local fieldIndexs = {}

    for fieldIndex, _ in ipairs (g_fieldManager:getFields()) do
        table.insert(fieldTexts, tostring(fieldIndex))
        table.insert(fieldIndexs, fieldIndex)
    end

    table.insert(fieldTexts, EasyDevUtils.getText("easyDevControls_all"))
    table.insert(fieldIndexs, 0)

    return fieldTexts, fieldIndexs
end

function EasyDevControlsFieldsFrame:getGrowthAndFruitData()
    local prepareText = g_i18n:getText("ui_growthMapReadyToPrepareForHarvest")
    local harvestText = g_i18n:getText("ui_growthMapReadyToHarvest")
    local witheredText = g_i18n:getText("ui_growthMapWithered")
    local growingText = g_i18n:getText("ui_growthMapGrowing")
    local cutText = g_i18n:getText("ui_growthMapCut")
    local sownText = g_i18n:getText("ui_growthMapSown")

    local growthStateTexts = {}

    local fruitTypeTexts = {}
    local fruitTypes = {}

    for index, fruitType in pairs (g_fruitTypeManager.indexToFruitType) do
        if fruitType.isGrowing and fruitType.cutState > 0 and fruitType.numGrowthStates > 0 and fruitType.allowsSeeding then
            local fillType = g_fruitTypeManager:getFillTypeByFruitTypeIndex(index)
            local numFruitTypes = #fruitTypes + 1
            local texts = {}

            local harvestingState = 1
            local preparingState = 1
            local growingState = 0

            local maxGrowingState = fruitType.minHarvestingGrowthState - 1

            local minPreparingState = fruitType.minPreparingGrowthState
            local maxPreparingState = fruitType.maxPreparingGrowthState

            local maxHarvestingState = fruitType.maxHarvestingGrowthState
            local witheredState = fruitType.witheredState or maxHarvestingState + 1

            if minPreparingState >= 0 then
                maxGrowingState = math.min(maxGrowingState, minPreparingState - 1)
            end

            if maxPreparingState >= 0 then
                witheredState = maxPreparingState + 1
            end

            -- if fruitType.preparedGrowthState >= 0 then
                -- maxGrowingState = maxHarvestingState
            -- end

            local numPreparingStates = 0

            if minPreparingState >= 0 and maxPreparingState >= 0 then
                numPreparingStates = 1 + (maxPreparingState - minPreparingState)
            end

            local numHarvestingStates = 1 + (maxHarvestingState - fruitType.minHarvestingGrowthState)

            for growthState = 1, (2 ^ fruitType.numStateChannels - 1) do
                if growthState == witheredState and witheredState ~= maxHarvestingState then
                    table.insert(texts, witheredText)
                elseif growthState == fruitType.cutState then
                    table.insert(texts, cutText)
                elseif growthState <= maxGrowingState then
                    if maxGrowingState > 1 and growingState > 0 then
                        if maxGrowingState > 2 then
                            table.insert(texts, string.format("%s %d", growingText, growingState))
                        else
                            table.insert(texts, growingText)
                        end
                    else
                        table.insert(texts, sownText)
                    end

                    growingState = growingState + 1
                elseif numPreparingStates > 0 and growthState >= minPreparingState and growthState <= maxPreparingState then
                    if numPreparingStates > 1 then
                        table.insert(texts, string.format("%s %d", prepareText, preparingState))

                        preparingState = preparingState + 1
                    else
                        table.insert(texts, prepareText)
                    end
                elseif growthState <= maxHarvestingState then
                    if numHarvestingStates > 1 then
                        table.insert(texts, string.format("%s %d", harvestText, harvestingState))

                        harvestingState = harvestingState + 1
                    else
                        table.insert(texts, harvestText)
                    end
                end
            end

            self.lastGrowthStates[numFruitTypes] = 1
            growthStateTexts[numFruitTypes] = texts

            fruitTypeTexts[numFruitTypes] = fillType.title
            fruitTypes[numFruitTypes] = index
        end
    end

    return growthStateTexts, fruitTypeTexts, fruitTypes
end

function EasyDevControlsFieldsFrame:getGroundLayerData()
    local unknownTexts = EasyDevUtils.getText("easyDevControls_unknown")

    local fieldGroundSystem = g_currentMission.fieldGroundSystem
    local sprayTypeMaxValue = fieldGroundSystem:getMaxValue(FieldDensityMap.SPRAY_TYPE)

    local chopperStraw = fieldGroundSystem:getChopperTypeValue(FieldChopperType.CHOPPER_STRAW)
    local chopperMaize = fieldGroundSystem:getChopperTypeValue(FieldChopperType.CHOPPER_MAIZE)

    local groundLayerTexts = {
        EasyDevUtils.getFieldSprayTypeTitle("NONE", "None")
    }

    local groundLayers = {
        0
    }

    for i = 1, sprayTypeMaxValue do
        local sprayType = nil
        local name = unknownTexts

        for identifier, layerId in pairs(fieldGroundSystem.fieldSprayTypeValue) do
            if layerId == i then
                sprayType = identifier

                break
            end
        end

        if sprayType ~= nil then
            name = FieldSprayType.getName(sprayType)
            name = EasyDevUtils.getFieldSprayTypeTitle(name, name)
        elseif i == chopperStraw then
            name = EasyDevUtils.getFieldSprayTypeTitle("STRAW", "Straw")
        elseif i == chopperMaize then
            name = EasyDevUtils.getFieldSprayTypeTitle("MAIZE", "Maize")
        elseif i == sprayTypeMaxValue then
            name = EasyDevUtils.getFieldSprayTypeTitle("MASK", "Mask")
        end

        table.insert(groundLayerTexts, name)
        table.insert(groundLayers, i)
    end

    return groundLayerTexts, groundLayers
end

function EasyDevControlsFieldsFrame:getWeedData()
    -- Future: Use 'getFieldInfoStates' and '<herbicide><replacements>' from the maps_weed.xml to make this dynamic

    local smallText = EasyDevUtils.getText("easyDevControls_small")
    local mediumText = EasyDevUtils.getText("easyDevControls_medium")
    local largeText = EasyDevUtils.getText("easyDevControls_large")
    local growingText = EasyDevUtils.getText("easyDevControls_growing")
    local witheredText = EasyDevUtils.getText("easyDevControls_withered")

    local weedStateTexts = {
        g_i18n:getText("ui_none"),
        string.format("%s (%s)", smallText, growingText),
        string.format("%s (%s)", mediumText, growingText),
        smallText,
        mediumText,
        largeText,
        EasyDevUtils.getText("easyDevControls_partial"),
        string.format("%s (%s)", smallText, witheredText),
        string.format("%s (%s)", mediumText, witheredText),
        string.format("%s (%s)", largeText, witheredText)
    }

    local weedStates = {}

    for i = 0, #weedStateTexts - 1 do
        table.insert(weedStates, i)
    end

    return weedStateTexts, weedStates
end

function EasyDevControlsFieldsFrame:getAngleData()
    local angleMaxValue = g_currentMission.fieldGroundSystem:getGroundAngleMaxValue()

    if angleMaxValue == nil then
        return {"0°"}, {0}
    end

    local angles = {}
    local angleTexts = {}
    local increment = 180 / (angleMaxValue + 1)

    for i = 0, angleMaxValue do
        table.insert(angleTexts, string.format("%d°", increment * i))
        table.insert(angles, i)
    end

    -- Same values but allows a user to see 360° worth of available angles
    for i = 0, angleMaxValue do
        table.insert(angleTexts, string.format("%d°", 180 + increment * i))
        table.insert(angles, i)
    end

    return angleTexts, angles
end

function EasyDevControlsFieldsFrame:getGroundTypeData()
    local groundTypeTexts = {}
    local groundTypes = {}

    for i, groundType in ipairs (FieldGroundType.getAllOrdered()) do
        table.insert(groundTypes, groundType)
    end

    table.sort(groundTypes)

    for i, groundType in ipairs (groundTypes) do
        local name = FieldGroundType.getName(groundType) or "INVALID"

        groundTypeTexts[i] = EasyDevUtils.getFieldGroundTypeTitle(name, name)
    end

    return groundTypeTexts, groundTypes
end

function EasyDevControlsFieldsFrame:getStoneData()
    local stoneStateTexts = {}
    local stoneStates = {}

    local stoneSystem = g_currentMission.stoneSystem

    if stoneSystem ~= nil then
        local stateText = EasyDevUtils.getText("easyDevControls_state")

        local maskValue = stoneSystem:getMaskValue()
        local pickedValue = stoneSystem:getPickedValue()
        local minValue, maxValue = g_currentMission.stoneSystem:getMinMaxValues()

        table.insert(stoneStateTexts, string.format(stateText, maskValue))
        table.insert(stoneStates, maskValue)

        for value = minValue, maxValue do
            if value ~= maskValue and value ~= pickedValue then
                table.insert(stoneStateTexts, string.format(stateText, value))
                table.insert(stoneStates, value)
            end
        end

        table.insert(stoneStateTexts, EasyDevUtils.getText("easyDevControls_picked"))
        table.insert(stoneStates, pickedValue)
    else
        stoneStateTexts[1] = g_i18n:getText("ui_none")
        stoneStates[1] = 0
    end

    return stoneStateTexts, stoneStates
end

function EasyDevControlsFieldsFrame:onClickFieldSet(element)
    if self.setFieldDialogData == nil then
        self:initializeSetFieldDialogData()
        self:createSetFieldDialogData ()
    end

    local data = self.setFieldDialogData[element.name]

    if data ~= nil then
        local setFieldData = self.setFieldData[element.name]

        if setFieldData ~= nil then
            setFieldData.fieldIndex = self.currentFieldIndex > 0 and self.currentFieldIndex or #self.setFieldIndexs

            for _, property in ipairs (data.properties) do
                local name = property.name

                if name == "buyFarmland" then
                    property.lastIndex = 1
                elseif name == "removeFoliage" then
                    property.lastIndex = setFieldData[name] and 2 or 1
                elseif name == "growthState" and setFieldData.fruitIndex ~= nil then
                    property.lastIndex = self.lastGrowthStates[setFieldData.fruitIndex]
                elseif name == "weedState" or name == "herbicideState" then
                    property.disabled = not self.weedsEnabled
                    property.lastIndex = property.disabled and 1 or property.lastIndex
                elseif name == "stonesState" then
                    property.disabled = not self.stonesEnabled
                    property.lastIndex = property.disabled and 1 or property.lastIndex
                else
                    property.lastIndex = setFieldData[name] or 1
                end
            end
        end

        self.ui:showDynamicSelectionDialog({
            headerText = data.headerText,
            properties = data.properties,
            hideBackground = not self:getPerformBackgroundBlur(),
            callback = data.callback,
            target = self,
            numHorizontal = data.numHorizontal,
            numVertical = data.numVertical,
            confirmText = data.confirmText,
			confirmButtonAction = InputAction.MENU_ACTIVATE,
            onCloseTarget = self
        })

        self:setContainerVisibility(false) -- Hide the containers so when background is hidden there is more visibility
    else
        self:setInfoText(EasyDevUtils.getText("easyDevControls_requestFailedMessage"))
    end
end

function EasyDevControlsFieldsFrame:onClickFieldSetFruit(confirmed)
    if confirmed then
        local data = self.setFieldData.setFruit

        local fieldIndex = self.setFieldIndexs[data.fieldIndex]
        local fruitIndex = self.setFieldFruitTypes[data.fruitIndex]
        local groundLayer = self.setFieldGroundLayers[data.groundLayer]
        local fertilizerState = self.setFieldFertilizerStates[data.fertilizerState]
        local plowingState = self.setFieldPlowingStates[data.plowingState]
        local limeState = self.setFieldLimeStates[data.limeState]
        local stubbleState = self.setFieldStubbleStates[data.stubbleState]
        local weedState = self.setFieldWeedStates[data.weedState]
        local herbicideState = self.setFieldHerbicideStates[data.herbicideState]
        local rollerState = self.setFieldRollerStates[data.rollerState]
        local stonesState = self.setFieldStonesStates[data.stonesState]

        self:setInfoText(self.easyDevControls:setFieldFruit(fieldIndex, fruitIndex, data.growthState, groundLayer, fertilizerState, plowingState, limeState, stubbleState, weedState, herbicideState, rollerState, stonesState, data.buyFarmland, self.farmId))
    end
end

function EasyDevControlsFieldsFrame:onClickFieldSetGround(confirmed)
    if confirmed then
        local data = self.setFieldData.setGround

        local fieldIndex = self.setFieldIndexs[data.fieldIndex]
        local groundTypeValue = self.setGroundTypes[data.groundType]
        local angleValue = self.setFieldAngles[data.angle]
        local groundLayer = self.setFieldGroundLayers[data.groundLayer]
        local fertilizerState = self.setFieldFertilizerStates[data.fertilizerState]
        local plowingState = self.setFieldPlowingStates[data.plowingState]
        local limeState = self.setFieldLimeStates[data.limeState]
        local stubbleState = self.setFieldStubbleStates[data.stubbleState]
        local weedState = self.setFieldWeedStates[data.weedState]
        local herbicideState = self.setFieldHerbicideStates[data.herbicideState]
        local rollerState = self.setFieldRollerStates[data.rollerState]
        local stonesState = self.setFieldStonesStates[data.stonesState]

        self:setInfoText(self.easyDevControls:setFieldGround(fieldIndex, groundTypeValue, angleValue, data.removeFoliage, groundLayer, fertilizerState, plowingState, limeState, stubbleState, weedState, herbicideState, rollerState, stonesState, data.buyFarmland, self.farmId))
    end
end

-- Vine System Set State
function EasyDevControlsFieldsFrame:updateVineGrowthAndFruitData(fruitTypeIndex)
    if fruitTypeIndex == nil or self.vineFruitTypeData[fruitTypeIndex] ~= nil then
        return false
    end

    local fruitType = g_fruitTypeManager:getFruitTypeByIndex(fruitTypeIndex)

    if fruitType ~= nil and fruitType.isGrowing and fruitType.cutState == 0 and fruitType.numGrowthStates > 0 then
        local growingText = g_i18n:getText("ui_growthMapGrowing")
        local harvestText = g_i18n:getText("ui_growthMapReadyToHarvest")

        local growthStateTexts = {}

        local growingState = 1
        local harvestingState = 1

        local maxGrowingState = fruitType.minHarvestingGrowthState - 1
        local maxHarvestingState = fruitType.maxHarvestingGrowthState
        local witheredState = fruitType.witheredState or (maxHarvestingState + 1)

        local numHarvestingStates = 1 + (maxHarvestingState - fruitType.minHarvestingGrowthState)

        for growthState = 1, (2 ^ fruitType.numStateChannels - 1) do
            if growthState == witheredState and witheredState ~= maxHarvestingState then
                table.insert(growthStateTexts, g_i18n:getText("ui_growthMapWithered"))
            elseif growthState == fruitType.cutState then
                table.insert(growthStateTexts, g_i18n:getText("ui_growthMapCut"))
            elseif growthState <= maxGrowingState then
                if maxGrowingState > 1 then
                    table.insert(growthStateTexts, string.format("%s %d", growingText, growingState))
                else
                    table.insert(growthStateTexts, growingText)
                end

                growingState = growingState + 1
            elseif growthState <= maxHarvestingState then
                if numHarvestingStates > 1 then
                    table.insert(growthStateTexts, string.format("%s %d", harvestText, harvestingState))

                    harvestingState = harvestingState + 1
                else
                    table.insert(growthStateTexts, harvestText)
                end
            end
        end

        if #growthStateTexts > 0 then
            local fillType = g_fruitTypeManager:getFillTypeByFruitTypeIndex(fruitTypeIndex)

            self.vineFruitTypeData[fruitTypeIndex] = {
                growthStateTexts = growthStateTexts,
                fruitTypeIndex = fruitTypeIndex,
                title = fillType.title
            }

            EasyDevUtils.clearTable(self.vineFruitTypeTexts)
            EasyDevUtils.clearTable(self.vineFruitTypes)

            EasyDevUtils.clearTable(self.vineGrowthStateTexts)
            EasyDevUtils.clearTable(self.vineGrowthStates)

            for _, data in pairs (self.vineFruitTypeData) do
                table.insert(self.vineFruitTypeTexts, data.title)
                table.insert(self.vineFruitTypes, data.fruitTypeIndex)

                table.insert(self.vineGrowthStateTexts, data.growthStateTexts)
                table.insert(self.vineGrowthStates, 1)
            end

            return true
        end
    end

    return false
end

function EasyDevControlsFieldsFrame:onClickVineSetStateFruitType(index, element)
    self.checkedVineSetStateGrowthState:setTexts(self.vineGrowthStateTexts[index] or EMPTY_TABLE)
    self.checkedVineSetStateGrowthState:setState(self.vineGrowthStates[index] or 1)
end

function EasyDevControlsFieldsFrame:onClickVineSetStateGrowthState(index, element)
    self.vineGrowthStates[self.checkedVineSetStateFruitType.state] = index
end

function EasyDevControlsFieldsFrame:onClickConfirmVineSetState(element)
    local fruitTypeState = self.checkedVineSetStateFruitType:getState()
    local placeableVine = nil -- Future, targeted vine updating

    self:setInfoText(self.easyDevControls:vineSystemSetState(placeableVine, self.vineFruitTypes[fruitTypeState], self.vineGrowthStates[fruitTypeState], self.farmId))
end

-- Vine System Update Visuals
function EasyDevControlsFieldsFrame:onClickVineUpdateVisuals(element)
    g_currentMission.vineSystem:consoleCommandUpdateVisuals()

    self:setInfoText(EasyDevUtils.getText("easyDevControls_vineUpdateVisualsInfo"))
end

-- Add / Remove Stones & Weeds
function EasyDevControlsFieldsFrame:onClickRemove(element)
    if self.playerOnField then
        if element.name == "removeWeeds" then
            self:setInfoText(self.easyDevControls:addRemoveWeedsDelta(self.currentFieldIndex, -1))
        elseif element.name == "removeStones" then
            self:setInfoText(self.easyDevControls:addRemoveStonesDelta(self.currentFieldIndex, -1))
        end
    end
end

function EasyDevControlsFieldsFrame:onClickAdd(element)
    if self.playerOnField then
        if element.name == "addWeeds" then
            self:setInfoText(self.easyDevControls:addRemoveWeedsDelta(self.currentFieldIndex, 1))
        elseif element.name == "addStones" then
            self:setInfoText(self.easyDevControls:addRemoveStonesDelta(self.currentFieldIndex, 1))
        end
    end
end

-- Advance Growth
function EasyDevControlsFieldsFrame:onClickConfirmAdvanceGrowth(element)
    if not self.updateGrowthSystemDisabled then
        local growthMode = g_currentMission.growthSystem:getGrowthMode()
        local args = {
            updateGrowthMode = growthMode ~= GrowthSystem.MODE.DAILY,
            successText = EasyDevUtils.getText("easyDevControls_advanceGrowthInfo"),
            setGrowth = false
        }

        if growthMode == GrowthSystem.MODE.DAILY then
            self:setGrowthPeriod(true, args)
        else
            local currentSetting = growthMode == GrowthSystem.MODE.SEASONAL and "ui_gameMode_seasonal" or "ui_paused"

            g_gui:showYesNoDialog({
                text = EasyDevUtils.formatText("easyDevControls_advanceGrowthWarning", g_i18n:getText("setting_seasonalGrowth"), g_i18n:getText(currentSetting)),
                callback = self.setGrowthPeriod,
                target = self,
                args = args
            })
        end
    else
        element:setDisabled(true)

        self:setInfoText(EasyDevUtils.getText("easyDevControls_requestFailedMessage"))
    end
end

-- Set Seasonal Growth Period
function EasyDevControlsFieldsFrame:onClickConfirmGrowthPeriod(element)
    if not self.updateGrowthSystemDisabled then
        local period = EasyDevUtils.getPeriodFromMonth(self.multiGrowthPeriod:getState())
        local growthMode = g_currentMission.growthSystem:getGrowthMode()
        local args = {
            updateGrowthMode = growthMode == GrowthSystem.MODE.DISABLED,
            successText = EasyDevUtils.formatText("easyDevControls_setGrowthPeriodInfo", g_i18n:formatPeriod(period, false), period),
            setGrowth = true,
            period = period
        }

        if growthMode ~= GrowthSystem.MODE.DISABLED then
            self:setGrowthPeriod(true, args)
        else
            g_gui:showYesNoDialog({
                text = EasyDevUtils.formatText("easyDevControls_setGrowthPeriodWarning", g_i18n:getText("setting_seasonalGrowth"), g_i18n:getText("ui_paused")),
                callback = self.setGrowthPeriod,
                target = self,
                args = args
            })
        end
    else
        element:setDisabled(true)
        self.multiGrowthPeriod:setDisabled(true)

        self:setInfoText("easyDevControls_requestFailedMessage")
    end
end

function EasyDevControlsFieldsFrame:setGrowthPeriod(yes, args)
    if yes then
        if args.updateGrowthMode then
            g_currentMission.growthSystem:setGrowthMode(GrowthSystem.MODE.DAILY, false)
        end

        if self.parent.target ~= nil and self.parent.target.onSendServerRequest ~= nil then
            self.parent.target:onSendServerRequest(5000 / 6, EasyDevUtils.getText("easyDevControls_updatingAllFieldsMessage"), args.successText)
        end

        self:setInfoText(self.easyDevControls:setGrowthPeriod(args.setGrowth, args.period))
    else
        self:setInfoText(EasyDevUtils.getText("easyDevControls_requestCancelledMessage"))
    end
end

-- Set Farmland Owner
function EasyDevControlsFieldsFrame:updateFarmlandOwnerElements()
    local isButtonDisabled = self.setFarmlandOwnerDisabled

    if not isButtonDisabled then
        local setFarmlandOwner = self.setFarmlandOwner

        local index = setFarmlandOwner.lastIndexs[setFarmlandOwner.sortBy]
        local farmlandId = setFarmlandOwner.farmlandIds[setFarmlandOwner.sortBy][index]

        if farmlandId > 0 then
            local farmlandOwner = g_farmlandManager:getFarmlandOwner(farmlandId)

            if farmlandOwner == self.farmId then
                isButtonDisabled = setFarmlandOwner.farmId == self.farmId
            elseif farmlandOwner == FarmlandManager.NO_OWNER_FARM_ID then
                isButtonDisabled = setFarmlandOwner.farmId == FarmlandManager.NO_OWNER_FARM_ID
            end
        end
    end

    self.buttonConfirmSetFarmlandOwner:setDisabled(isButtonDisabled)
end

function EasyDevControlsFieldsFrame:onClickSetFarmlandOwnerSortBy(index, element)
    self.setFarmlandOwner.sortBy = index

    self.multiSetFarmlandOwnerIndex:setTexts(self.setFarmlandOwner.farmlandTexts[index])
    self.multiSetFarmlandOwnerIndex:setState(self.setFarmlandOwner.lastIndexs[index])

    self:updateFarmlandOwnerElements()
end

function EasyDevControlsFieldsFrame:onClickSetFarmlandFarmId(index, element)
    self.setFarmlandOwner.farmId = self.setFarmlandOwner.farmIds[index]

    self:updateFarmlandOwnerElements()
end

function EasyDevControlsFieldsFrame:onClickSetFarmlandOwnerIndex(index, element)
    self.setFarmlandOwner.lastIndexs[self.setFarmlandOwner.sortBy] = index

    self:updateFarmlandOwnerElements()
end

function EasyDevControlsFieldsFrame:onClickConfrimSetFarmlandOwner(element)
    local setFarmlandOwner = self.setFarmlandOwner
    local sortBy = setFarmlandOwner.sortBy

    local index = setFarmlandOwner.lastIndexs[sortBy]
    local farmlandId = setFarmlandOwner.farmlandIds[sortBy][index]

    local farmId = setFarmlandOwner.farmId
    local farmName = "NPC"

    if farmId ~= FarmManager.SPECTATOR_FARM_ID then
        local farm = g_farmManager:getFarmById(self.farmId)

        if farm ~= nil then
            farmName = farm.name
        else
            self:setInfoText(EasyDevUtils.getText("easyDevControls_requestFailedMessage"))
            element:setDisabled(true)

            return
        end
    end

    if farmlandId == 0 then
        local numUpdated = 0

        for _, farmland in pairs(g_farmlandManager:getFarmlands()) do
            local currentOwner = g_farmlandManager:getFarmlandOwner(farmland.id)

            if currentOwner == self.farmId or currentOwner == FarmlandManager.NO_OWNER_FARM_ID then
                g_client:getServerConnection():sendEvent(FarmlandStateEvent.new(farmland.id, farmId, 0))

                numUpdated = numUpdated + 1
            end
        end

        self:setInfoText(EasyDevUtils.formatText("easyDevControls_setFarmlandOwnerAllInfo", numUpdated, farmName))
    else
        local currentOwner = g_farmlandManager:getFarmlandOwner(farmlandId)

        if currentOwner == self.farmId or currentOwner == FarmlandManager.NO_OWNER_FARM_ID then
            g_client:getServerConnection():sendEvent(FarmlandStateEvent.new(farmlandId, farmId, 0))

            self:setInfoText(EasyDevUtils.formatText("easyDevControls_setFarmlandOwnerInfo", farmlandId, farmName))
        else
            self:setInfoText(EasyDevUtils.getText("easyDevControls_requestFailedMessage"))
        end

        self:updateFarmlandOwnerElements()
    end
end

-- Refresh Field Overlay
function EasyDevControlsFieldsFrame:onClickRefreshFieldOverlay(element)
    self.fieldRefreshingTimer = 1000
    self.ingameMap.fieldRefreshTimer = IngameMap.FIELD_REFRESH_INTERVAL - 1000

    self.textRefreshFieldOverlay:setText(EasyDevUtils.getText("easyDevControls_refreshing"))
    self:setInfoText(EasyDevUtils.getText("easyDevControls_refreshFieldOverlayInfo"))
end

-- Field Status Debug
function EasyDevControlsFieldsFrame:onClickDebugFieldStatusRange(index, element)
    if FieldManager.DEBUG_SHOW_FIELDSTATUS then
        FieldManager.DEBUG_SHOW_FIELDSTATUS_SIZE = EasyDevUtils.getDefaultRangeValue(index) or FieldManager.DEBUG_SHOW_FIELDSTATUS_SIZE
    end
end

function EasyDevControlsFieldsFrame:onClickDebugFieldStatus(index, element)
    local active = self:getIsCheckedIndex(index)

    if active and not FieldManager.DEBUG_SHOW_FIELDSTATUS then
        local rangeState = self.multiDebugFieldStatusRange:getState()
        local size = EasyDevUtils.getDefaultRangeValue(rangeState) or FieldManager.DEBUG_SHOW_FIELDSTATUS_SIZE

        g_fieldManager:consoleCommandToggleDebugFieldStatus(size)
    elseif not active and FieldManager.DEBUG_SHOW_FIELDSTATUS then
        g_fieldManager:consoleCommandToggleDebugFieldStatus("10")
    end

    self:setInfoText(EasyDevUtils.formatText("easyDevControls_debugFieldStatusInfo", self:getStateText(FieldManager.DEBUG_SHOW_FIELDSTATUS, true)))
end

-- Vine System Debug
function EasyDevControlsFieldsFrame:onClickDebugVineSystem(index, element)
    local isDebugAreaActive = self:getIsCheckedIndex(index)
    local vineSystem = g_currentMission.vineSystem

    if isDebugAreaActive and not vineSystem.isDebugAreaActive or not isDebugAreaActive and vineSystem.isDebugAreaActive then
        vineSystem:consoleCommandToggleDebug()
    else
        element:setIsChecked(vineSystem.isDebugAreaActive)
    end

    self:setInfoText(EasyDevUtils.formatText("easyDevControls_vineSystemDebugInfo", self:getStateText(vineSystem.isDebugAreaActive, true)))
end

-- Stone System Debug
function EasyDevControlsFieldsFrame:onClickDebugStoneSystem(index, element)
    local isDebugAreaActive = self:getIsCheckedIndex(index)
    local stoneSystem = g_currentMission.stoneSystem

    if isDebugAreaActive and not stoneSystem.isDebugAreaActive or not isDebugAreaActive and stoneSystem.isDebugAreaActive then
        stoneSystem:consoleCommandToggleDebug()
    else
        element:setIsChecked(stoneSystem.isDebugAreaActive)
    end

    self:setInfoText(EasyDevUtils.formatText("easyDevControls_stoneSystemDebugInfo", self:getStateText(stoneSystem.isDebugAreaActive, true)))
end

-- Listeners
function EasyDevControlsFieldsFrame:onSettingChanged(id, value)
end

function EasyDevControlsFieldsFrame:onDynamicSelectionDialogClosed()
    self:setContainerVisibility(true)
end

function EasyDevControlsFieldsFrame:getPerformBackgroundBlur()
    if self.parent.target ~= nil then
        return self.parent.target.performBackgroundBlur
    end

    return true
end

-- Extras
function EasyDevControlsFieldsFrame:getResetValues()
    return {
        multiDebugFieldStatusRange = {
            value = 5
        },
        checkedDebugFieldStatus = {
            value = CheckedOptionElement.STATE_UNCHECKED
        },
        checkedDebugVineSystem = {
            value = CheckedOptionElement.STATE_UNCHECKED
        },
        checkedDebugStoneSystem = {
            value = CheckedOptionElement.STATE_UNCHECKED
        }
    }
end
