--[[
Copyright (C) GtX (Andy), 2019

Author: GtX | Andy
Date: 07.04.2019
Revision: FS22-03

Contact:
https://forum.giants-software.com
https://github.com/GtX-Andy

Important:
Not to be added to any mods / maps or modified from its current release form.
No modifications may be made to this script, including conversion to other game versions without written permission from GtX | Andy

Darf nicht zu Mods / Maps hinzugefügt oder von der aktuellen Release-Form geändert werden.
Ohne schriftliche Genehmigung von GtX | Andy dürfen keine Änderungen an diesem Skript vorgenommen werden, einschließlich der Konvertierung in andere Spielversionen
]]

EasyDevControlsGeneralFrame = {}

local EasyDevControlsGeneralFrame_mt = Class(EasyDevControlsGeneralFrame, EasyDevControlsBaseFrame)
local EMPTY_TABLE = {}

EasyDevControlsGeneralFrame.NUM_QUALITY_OPTIONS = 5

EasyDevControlsGeneralFrame.L10N_SYMBOL = {}

EasyDevControlsGeneralFrame.CONTROLS = {
    "textInputAddMoney",
    "textInputRemoveMoney",
    "textInputSetMoney",
    "checkedTimeScale",
    "buttonStopTime",
    "checkedFlightModeToggle",
    "checkedFlightModeState",
    "checkedHudVisibility",
    "checkedToggleHudInput",
    "checkedDeleteObjectsKey",
    "titleTeleport",
    "multiTeleport",
    "textInputTeleportXZ",
    "buttonTeleportConfirm",
    "buttonFlipVehicles",
    "textInputSetFOVAngle",
    "buttonResetFOVAngle",
    "multiSetQuality",
    "multiShowCollectables",
    "buttonClearI3DCache"
}

function EasyDevControlsGeneralFrame.new(ui, easyDevControls, accessLevel)
    local self = EasyDevControlsBaseFrame.new(EasyDevControlsGeneralFrame_mt, ui, easyDevControls, accessLevel)

    self:registerControls(EasyDevControlsGeneralFrame.CONTROLS)

    return self
end

function EasyDevControlsGeneralFrame:initialize()
    local fieldNumberText = g_i18n:getText("fieldJob_number")
    local teleportFieldTexts = {}

    for i = 1, #g_fieldManager:getFields() do
        teleportFieldTexts[i] = string.format(fieldNumberText, i)
    end

    self.numTeleportFields = #teleportFieldTexts
    self.mapSelectTeleportIndex = self.numTeleportFields + 1
    self.locationTeleportIndex = self.mapSelectTeleportIndex + 1

    teleportFieldTexts[self.mapSelectTeleportIndex] = EasyDevUtils.getText("easyDevControls_teleportMapSelect")
    teleportFieldTexts[self.locationTeleportIndex] = "X / Z"

    self.multiTeleport:setTexts(teleportFieldTexts)

    self.buttonResetFOVAngle:setImageFilename(nil, self.ui.iconsUIFilename)

    self.qualityValues = {
        EasyDevUtils.getText("easyDevControls_userSetting")
    }

    self.qualitySettings = {
        [SettingsModel.SETTING.OBJECT_DRAW_DISTANCE] = {
            defualtValue = 0,
            setFunc = function(coeff) setViewDistanceCoeff(coeff) end,
            getFunc = function() return getViewDistanceCoeff() end
        },
        [SettingsModel.SETTING.LOD_DISTANCE] = {
            defualtValue = 0,
            setFunc = function(coeff) setLODDistanceCoeff(coeff) end,
            getFunc = function() return getLODDistanceCoeff() end
        },
        [SettingsModel.SETTING.TERRAIN_LOD_DISTANCE] = {
            defualtValue = 0,
            setFunc = function(coeff) setTerrainLODDistanceCoeff(coeff) end,
            getFunc = function() return getTerrainLODDistanceCoeff() end
        },
        [SettingsModel.SETTING.FOLIAGE_DRAW_DISTANCE] = {
            defualtValue = 0,
            setFunc = function(coeff) setFoliageViewDistanceCoeff(coeff) end,
            getFunc = function() return getFoliageViewDistanceCoeff() end
        },
        [SettingsModel.SETTING.VOLUME_MESH_TESSELLATION] = {
            defualtValue = 0,
            setFunc = function(coeff) SettingsModel.setVolumeMeshTessellationCoeff(coeff) end,
            getFunc = function() return SettingsModel.getVolumeMeshTessellationCoeff() end
        }
    }

    if g_settingsScreen ~= nil and g_settingsScreen.settingsModel then
        local settingsModel = g_settingsScreen.settingsModel
        local percentValues = settingsModel.percentValues or EMPTY_TABLE

        self.qualityValues = {
            0.1,
            0.25,
            5,
            10
        }

        for key, setting in pairs(settingsModel.settings) do
            local qualitySetting = self.qualitySettings[key]

            if qualitySetting ~= nil and qualitySetting.getFunc ~= nil and qualitySetting.setFunc ~= nil then
                local defualtValue = percentValues[setting.saved] or qualitySetting.getFunc()

                qualitySetting.defualtValue = defualtValue

                if key == SettingsModel.SETTING.OBJECT_DRAW_DISTANCE then
                    table.insert(self.qualityValues, 3, defualtValue)
                end
            end
        end
    end

    self.multiSetQuality:setTexts({
        g_i18n:getText("setting_low"),
        g_i18n:getText("setting_medium"),
        EasyDevUtils.getText("easyDevControls_userSetting"), -- @Giants 'MultiTextOptionElement does not support adding mod texts still
        g_i18n:getText("setting_high"),
        g_i18n:getText("setting_veryHigh")
    })

    self.collectiblesThreshold = {}

    self.collectiblesDisabled = true
    self.collectiblesCompleted = false

    local thresholdTexts
    local collectiblesSystem = g_currentMission.collectiblesSystem

    if collectiblesSystem ~= nil and not self.ui.isMultiplayer then
        local numCollectibles = #collectiblesSystem.collectibleIndexToName

        if numCollectibles > 0 then
            local hotspotThreshold = collectiblesSystem.hotspotThreshold
            local foundText = EasyDevUtils.getText("easyDevControls_found")

            if hotspotThreshold == nil or hotspotThreshold <= 0 then
                hotspotThreshold = numCollectibles / 4
                collectiblesSystem.hotspotThreshold = hotspotThreshold
            end

            thresholdTexts = {
                g_i18n:getText("configuration_valueDefault")
            }

            self.collectiblesThreshold[1] = hotspotThreshold

            for i = 10, 0, -1 do
                if i < 10 or numCollectibles ~= hotspotThreshold then
                    table.insert(thresholdTexts, string.format("%d %% %s", i * 10, foundText))
                    table.insert(self.collectiblesThreshold, numCollectibles * (i * 0.1))
                end
            end

            self.collectiblesDisabled = false
        end
    end

    if self.collectiblesDisabled then
        thresholdTexts = {
            g_i18n:getText("easyDevControls_unsupported"),
        }
    end

    self.multiShowCollectables:setTexts(thresholdTexts)
end

function EasyDevControlsGeneralFrame:subscribeToMessages(messageCenter)
    messageCenter:subscribe(MessageType.TIMESCALE_CHANGED, self.onTimeScaleChanged, self)
    messageCenter:subscribe(EasyDevUtils.MESSAGE_TYPE_SETTINGS_CHANGED, self.onSettingChanged, self)
end

function EasyDevControlsGeneralFrame:updateAvailableProperties()
    local mission = g_currentMission

    -- Cheat Money (Add | Remove | Set)
    local cheatMoneyDisabled = self:getIsPropertyDisabled("cheatMoney")

    self.textInputAddMoney.lastValidText = ""
    self.textInputAddMoney:setText("")
    self.textInputAddMoney:setDisabled(cheatMoneyDisabled)

    self.textInputRemoveMoney.lastValidText = ""
    self.textInputRemoveMoney:setText("")
    self.textInputRemoveMoney:setDisabled(cheatMoneyDisabled)

    self.textInputSetMoney.lastValidText = ""
    self.textInputSetMoney:setText("")
    self.textInputSetMoney:setDisabled(cheatMoneyDisabled)

    -- Custom Time Scales
    self.checkedTimeScale:setIsChecked(self.easyDevControls:getCustomTimeScaleState())
    self.checkedTimeScale:setDisabled(not self.hasMasterRights)

    -- Stop Time
    self.buttonStopTime:setDisabled(not self.hasMasterRights or mission.missionInfo.timeScale <= 0)

    -- Flight Mode
    local flightModeEnabled = g_flightModeEnabled

    self.checkedFlightModeToggle:setIsChecked(flightModeEnabled)
    self.checkedFlightModeState:setIsChecked(mission.player.debugFlightMode)
    self.checkedFlightModeState:setDisabled(not flightModeEnabled)

    -- Hud Visibility
    self.noHudModeEnabled = g_noHudModeEnabled

    self.checkedHudVisibility:setIsChecked(not self.noHudModeEnabled)
    self.checkedToggleHudInput:setIsChecked(self.easyDevControls.toggleHudInputEnabled)

    -- Delete Objects
    self.checkedDeleteObjectsKey:setDisabled(not self.hasMasterRights)

    -- Teleport
    local vehicle, isEntered = self.easyDevControls:getVehicle()

    self.teleportDisabled = self:getIsPropertyDisabled("teleport")
    self.teleportIndex = self.mapSelectTeleportIndex

    if vehicle ~= nil then
        local singleVehicle = false

        if not isEntered then
            singleVehicle = vehicle.getAttachedImplements == nil or #vehicle:getAttachedImplements() == 0

            if singleVehicle and vehicle.getAttacherVehicle ~= nil then
                local attacherVehicle = vehicle:getAttacherVehicle()

                singleVehicle = attacherVehicle == nil or attacherVehicle == self
            end
        end

        if singleVehicle then
            self.titleTeleport:setText(EasyDevUtils.formatText("easyDevControls_teleportFormatedTitle", vehicle:getName()))
        else
            self.titleTeleport:setText(EasyDevUtils.formatText("easyDevControls_teleportFormatedTitle", g_i18n:getText("ui_vehicles")))
        end
    else
        self.titleTeleport:setText(EasyDevUtils.formatText("easyDevControls_teleportFormatedTitle", g_i18n:getText("ui_playerCharacter")))
    end

    self.multiTeleport:setState(self.teleportIndex)
    self.multiTeleport:setDisabled(self.teleportDisabled)

    self.textInputTeleportXZ.lastValidText = ""
    self.textInputTeleportXZ:setText("")
    self.textInputTeleportXZ:setDisabled(self.teleportDisabled or self.teleportIndex ~= self.locationTeleportIndex)

    self.buttonTeleportConfirm:setDisabled(self.teleportDisabled)

    -- Flip Vehicles
    self.flipVehiclesDisabled = true

    if vehicle ~= nil then
        self.flipVehiclesDisabled = self:getIsPropertyDisabled("flipVehicles")
    end

    self.buttonFlipVehicles:setDisabled(self.flipVehiclesDisabled)

    -- Set FOV Angle
    self.textInputSetFOVAngle.lastValidText = ""
    self.textInputSetFOVAngle:setText("")
    self.buttonResetFOVAngle:setDisabled(false)

    -- Set Quality
    self.multiSetQuality:setState(Utils.getValueIndex(getViewDistanceCoeff(), self.qualityValues))
    self.multiSetQuality:setDisabled(#self.qualityValues ~= EasyDevControlsGeneralFrame.NUM_QUALITY_OPTIONS)

    -- Collectables (SP ONLY)
    local collectiblesState = 1
    local collectiblesDisabled = true

    if not self.collectiblesDisabled and not self.collectiblesCompleted then
        collectiblesDisabled = mission.collectiblesSystem:isCompleted()

        if not collectiblesDisabled then
            local hotspotThreshold = mission.collectiblesSystem.hotspotThreshold

            for i = 1, #self.collectiblesThreshold do
                if hotspotThreshold >= self.collectiblesThreshold[i] then
                    collectiblesState = i

                    break
                end
            end
        else
            self.collectiblesCompleted = true
        end
    end

    self.multiShowCollectables:setState(collectiblesState)
    self.multiShowCollectables:setDisabled(collectiblesDisabled)

    -- Clear I3D Cache
    self.buttonClearI3DCache:setDisabled(getNumOfSharedI3DFiles() == 0)

    EasyDevControlsGeneralFrame:superClass().updateAvailableProperties(self)
end

-- Cheat Money (Add | Remove | Set)
function EasyDevControlsGeneralFrame:onCheatMoneyEnterPressed(element)
    local name = element.name or "addMoney"

    if element.text ~= "" then
        local typeId = EasyDevControlsMoneyEvent.TYPES[name:upper()] or 1

        self:setInfoText(self.easyDevControls:changeMoney(element.text, typeId, g_currentMission:getFarmId()))
        element:setText("")
    end

    element.lastValidText = ""
end

function EasyDevControlsGeneralFrame:onCheatMoneyTextChanged(element, text)
    if text ~= "" then
        if (element.name == "setMoney" and text == "-") or tonumber(text) ~= nil then
            element.lastValidText = text
        else
            element:setText(element.lastValidText)
        end
    else
        element.lastValidText = ""
    end
end

-- Custom Time Scale
function EasyDevControlsGeneralFrame:onClickSetTimeScale(index, element)
    if self.hasMasterRights then
        if index == 2 then
            g_gui:showYesNoDialog({
                text = EasyDevUtils.getText("easyDevControls_extraTimescalesWarning"),
                yesText = g_i18n:getText("button_confirm"),
                noText = g_i18n:getText("button_cancel"),
                dialogType = DialogElement.TYPE_WARNING,
                callback = function (confirm)
                    if confirm then
                        self:setExtraTimeScaleState(true, element.texts[index])
                    else
                        element:setIsChecked(false)

                        self:setInfoText(EasyDevUtils.getText("easyDevControls_requestCancelledMessage"))
                    end
                end
            })
        else
            self:setExtraTimeScaleState(false, element.texts[index])
        end
    end
end

function EasyDevControlsGeneralFrame:setExtraTimeScaleState(state, stateText)
    if g_server ~= nil then
        self.easyDevControls:setCustomTimeScaleState(state)
        self:setInfoText(EasyDevUtils.formatText("easyDevControls_extraTimescalesInfo", stateText or tostring(state)))
    else
        self:setInfoText(self.easyDevControls:clientSendEvent(EasyDevControlsTimeScaleEvent.new(state)))
    end
end

-- Stop Time
function EasyDevControlsGeneralFrame:onClickStopTime(element)
    if self.hasMasterRights then
        g_currentMission:setTimeScale(0) -- Event handled by the 'setTimeScale' function
        self:setInfoText(EasyDevUtils.getText("easyDevControls_stopTimeInfo"))
    else
        element:setDisabled(true)
        self:setInfoText(EasyDevUtils.getText("easyDevControls_requestFailedMessage"))
    end
end

-- Flight Mode / State
function EasyDevControlsGeneralFrame:onClickFlightMode(index, element)
    local player = g_currentMission.player

    if player ~= nil then
        local isChecked = element:getIsChecked()

        if element.id == "checkedFlightModeToggle" then
            if (not isChecked and g_flightModeEnabled) or (isChecked and not g_flightModeEnabled) then
                player:consoleCommandToggleFlightMode()

                local setDisabled = not g_flightModeEnabled

                self.checkedFlightModeState:setIsChecked(player.debugFlightMode)
                self.checkedFlightModeState:setDisabled(setDisabled)

                self:setInfoText(EasyDevUtils.formatText("easyDevControls_flightModeToggleInfo", element.texts[index]))
            end
        elseif element.id == "checkedFlightModeState" then
            if g_flightModeEnabled then
                player.debugFlightMode = isChecked

                local text = player.debugFlightMode and "easyDevControls_flightModeStateOnInfo" or "easyDevControls_flightModeStateOffInfo"
                self:setInfoText(EasyDevUtils.formatText(text, element.texts[index]))
            else
                element:setIsChecked(false)
                element:setDisabled(true)
            end
        end
    end
end

-- Hud Visibility / Key
function EasyDevControlsGeneralFrame:onClickHudVisibility(index, element)
    if g_currentMission.hud ~= nil then
        if element.id == "checkedHudVisibility" then
            local isChecked = element:getIsChecked()

            if (not isChecked and not g_noHudModeEnabled) or (isChecked and g_noHudModeEnabled) then
                g_currentMission.hud:consoleCommandToggleVisibility()
                self.noHudModeEnabled = g_noHudModeEnabled

                self:setInfoText(EasyDevUtils.formatText("easyDevControls_hudVisibilityInfo", element.texts[index]))
            end
        elseif element.id == "checkedToggleHudInput" then
            if self.easyDevControls:setToggleHudInputEnabled(index == CheckedOptionElement.STATE_CHECKED) then
                self:setInfoText(EasyDevUtils.formatText("easyDevControls_hudInputOnInfo", EasyDevUtils.getText("input_EDC_TOGGLE_HUD")))
            else
                self:setInfoText(EasyDevUtils.getText("easyDevControls_hudInputOffInfo"))
            end
        end
    end
end

-- Teleport Player or Vehicle
function EasyDevControlsGeneralFrame:onClickTeleport(index, element)
    self.teleportIndex = index

    self.textInputTeleportXZ:setDisabled(self.teleportDisabled or index ~= self.locationTeleportIndex)

    if self.textInputTeleportXZ.text ~= "" then
        self:onTextInputEscPressed(self.textInputTeleportXZ)
    end
end

function EasyDevControlsGeneralFrame:onTeleportEnterPressed(element)
    self:onClickTeleportConfirm(self.buttonTeleportConfirm)
end

function EasyDevControlsGeneralFrame:onTeleportTextChanged(element, text)
    if text ~= "" then
        local lastChar = text:sub(-1)
        local newText, numSpaces = text:gsub(" +"," ")

        if (lastChar == " " and numSpaces <= 1 and (element.lastValidText == nil or element.lastValidText ~= "")) or tonumber(lastChar) then
            element.lastValidText = newText

            if newText ~= text then
                element:setText(newText)
            end
        else
            element:setText(element.lastValidText)
        end
    else
        element.lastValidText = ""
    end
end

function EasyDevControlsGeneralFrame:onClickTeleportConfirm(element)
    local teleportIndex = self.teleportIndex
    local numFieldsEntries = self.numFieldsEntries
    local vehicle, isEntered = self.easyDevControls:getVehicle(true)

    if vehicle ~= nil and not isEntered then
        if vehicle:getOwnerFarmId() ~= g_currentMission:getFarmId() then
            self:setInfoText(EasyDevUtils.getText("easyDevControls_invalidFarmVehicleWarning"))

            return
        end
    end

    local object = vehicle or g_currentMission.player

    if teleportIndex <= self.numTeleportFields then
        self:onSelectTeleportLocation(object, teleportIndex, nil, nil)
    elseif teleportIndex == self.mapSelectTeleportIndex then
        g_gui:changeScreen(nil, EasyDevControlsTeleportScreen)

        self.ui.mapTeleportScreen:setReturnScreen("EasyDevControlsTabbedMenu")
        self.ui.mapTeleportScreen:setCallback(self.onSelectTeleportLocation, self, object)
    elseif teleportIndex == self.locationTeleportIndex then
        local infoText

        if self.textInputTeleportXZ.text ~= "" then
            local mapPosition = self.textInputTeleportXZ.text:split(" ")
            local x = tonumber(mapPosition[1] or "-1")
            local z = tonumber(mapPosition[2] or "-1")

            if x > -1 and z > -1 then
                infoText = self.easyDevControls:teleport(object, x, z, nil)
                self:onTextInputEscPressed(self.textInputTeleportXZ)
            else
                infoText = EasyDevUtils.getText("easyDevControls_invalidTeleportWarning")
            end
        else
            infoText = EasyDevUtils.getText("easyDevControls_emptyTeleportWarning")
        end

        self:setInfoText(infoText)
    end
end

function EasyDevControlsGeneralFrame:onSelectTeleportLocation(object, posX, posZ, yRot)
    if self.isOpen then
        self:setInfoText(self.easyDevControls:teleport(object, posX, posZ, yRot))
    else
        self.onOpenInfoText = self.easyDevControls:teleport(object, posX, posZ, yRot)
    end
end

-- Flip Vehicles
function EasyDevControlsGeneralFrame:onClickFlipVehicles(element)
    if not self.flipVehiclesDisabled then
        local vehicle, isEntered = self.easyDevControls:getVehicle(true, true)

        if (vehicle ~= nil and vehicle.rootNode ~= nil) and g_currentMission.hud ~= nil then
            local ingameMap = g_currentMission.hud:getIngameMap()

            if ingameMap ~= nil then
                if not isEntered and vehicle:getOwnerFarmId() ~= g_currentMission:getFarmId() then
                    self:setInfoText(EasyDevUtils.getText("easyDevControls_invalidFarmVehicleWarning"))

                    return
                end

                local x, _, z = getTranslation(vehicle.rootNode)
                local dx, _, dz = localDirectionToWorld(vehicle.rootNode, 0, 0, 1)
                local yRot = MathUtil.getYRotationFromDirection(dx, dz)

                local normalizedPosX = EasyDevUtils.getNoNilClamp((x + ingameMap.worldCenterOffsetX) / ingameMap.worldSizeX, 0, 1, x)
                local normalizedPosZ = EasyDevUtils.getNoNilClamp((z + ingameMap.worldCenterOffsetZ) / ingameMap.worldSizeZ, 0, 1, z)

                self.easyDevControls:teleport(vehicle, normalizedPosX * ingameMap.worldSizeX, normalizedPosZ * ingameMap.worldSizeZ, yRot)
                self:setInfoText(EasyDevUtils.getText("easyDevControls_flipVehiclesInfo"))

                return
            end
        end
    else
        element:setDisabled(true)
    end

    self:setInfoText(EasyDevUtils.getText("easyDevControls_requestFailedMessage"))
end

-- Delete Objects Key
function EasyDevControlsGeneralFrame:onClickDeleteObjectsKey(index, element)
    local state = self.easyDevControls:setDeleteObjectsInputEnabled(self:getIsCheckedIndex(index))
    self:setInfoText(EasyDevUtils.formatText("easyDevControls_deleteObjectsKeyInfo", EasyDevUtils.getText("input_EDC_OBJECT_DELETE"), self:getStateText(state, false)))
end

-- Set FOV Angle
function EasyDevControlsGeneralFrame:onSetFOVAngleEnterPressed(element)
    if element.text ~= "" then
        local fovY = tonumber(element.text)

        if fovY ~= nil then
            if fovY >= 0 then
                g_currentMission:consoleCommandSetFOV(element.text)

                self.buttonResetFOVAngle:setDisabled(false)

                self:setInfoText(EasyDevUtils.formatText("easyDevControls_setFovAngleInfo", fovY))
            else
                self:onClickResetFOVAngle(self.buttonResetFOVAngle)
            end
        else
            self:setInfoText(EasyDevUtils.formatText("easyDevControls_setFOVAngleWarning", element.text))
        end

        element:setText("")
    end

    element.lastValidText = ""
end

function EasyDevControlsGeneralFrame:onClickResetFOVAngle(element)
    local mission = g_currentMission
    local object = mission.player

    if mission.controlledVehicle ~= nil then
        object = mission.controlledVehicle:getActiveCamera()
    end

    local cameraNode = object ~= nil and object.cameraNode or getCamera(0)
    local fovY = 0

    mission:consoleCommandSetFOV("-1")

    if cameraNode ~= nil then
        fovY = math.deg(getFovY(cameraNode))
    end

    element:setDisabled(true)

    self:setInfoText(EasyDevUtils.formatText("easyDevControls_resetFovAngleInfo", fovY))
end

function EasyDevControlsGeneralFrame:onSetFOVAngleTextChanged(element, text)
    if text ~= "" then
        local num = tonumber(text)

        if text == "-" or (num ~= nil and num >= -1) then
            element.lastValidText = text
        else
            element:setText(element.lastValidText)
        end
    else
        element.lastValidText = ""
    end
end

-- Set Quality
function EasyDevControlsGeneralFrame:onClickSetQuality(index)
    local qualityValue = self.qualityValues[index]

    if qualityValue ~= nil and self.qualitySettings ~= nil then
        for key, setting in pairs (self.qualitySettings) do
            local setFunc = setting.setFunc

            if setFunc ~= nil then
                if index == 3 and setting.defualtValue ~= 0 then
                    setFunc(setting.defualtValue)
                else
                    setFunc(qualityValue)
                end
            end
        end

        self:setInfoText(EasyDevUtils.formatText("easyDevControls_setQualityInfo", self.multiSetQuality.texts[index] or EasyDevUtils.getText("easyDevControls_userSetting")))
    end
end

-- Show Collectables (SP ONLY)
function EasyDevControlsGeneralFrame:onClickShowCollectables(index, element)
    if not self.collectiblesDisabled then
        local collectiblesSystem = g_currentMission.collectiblesSystem

        collectiblesSystem.hotspotThreshold = self.collectiblesThreshold[index]
        collectiblesSystem:updateHotspotState()
    end
end

-- Clear I3D Cache
function EasyDevControlsGeneralFrame:onClickClearI3DCache(element)
    local verbose = g_showDevelopmentWarnings

    if not verbose then
        verbose = self.easyDevControls.godMode ~= nil
    end

    g_i3DManager:clearEntireSharedI3DFileCache(verbose)
    element:setDisabled(true)

    self:setInfoText(EasyDevUtils.getText("easyDevControls_clearI3DCacheInfo"))
end

-- Listeners
function EasyDevControlsGeneralFrame:onTimeScaleChanged()
    self.buttonStopTime:setDisabled(not self.hasMasterRights or g_currentMission.missionInfo.timeScale <= 0)
end

function EasyDevControlsGeneralFrame:onSettingChanged(id, value)
    if id == EasyDevUtils.SETTING_TOGGLE_HUD_INPUT then
        self.checkedToggleHudInput:setIsChecked(Utils.getNoNil(value, self.easyDevControls.toggleHudInputEnabled))
    elseif id == EasyDevUtils.SETTING_TIMESCALE then
        self.checkedTimeScale:setIsChecked(self.easyDevControls:getCustomTimeScaleState())
        self.checkedTimeScale:setDisabled(not self.hasMasterRights)
    end
end

-- Extras
function EasyDevControlsGeneralFrame:getResetValues()
    local unchecked = CheckedOptionElement.STATE_UNCHECKED

    return {
        checkedTimeScale = {
            value = unchecked,
            permissionKey = "timeScale"
        },
        checkedFlightModeToggle = {
            value = unchecked
        },
        checkedHudVisibility = {
            value = unchecked
        },
        checkedToggleHudInput = {
            value = unchecked
        },
        multiTeleport = {
            value = self.mapSelectTeleportIndex,
            permissionKey = "teleport"
        },
        multiSetQuality = {
            value = 3
        },
        multiShowCollectables = {
            value = 1
        },
    }
end
