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

EasyDevControlsPlayerFrame = {}

local EasyDevControlsPlayerFrame_mt = Class(EasyDevControlsPlayerFrame, EasyDevControlsBaseFrame)

local EMPTY_TABLE = {}

local function NO_CALLBACK()
end

local JUMP_MULTIPLIER_STATES = {
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10
}

EasyDevControlsPlayerFrame.L10N_SYMBOL = {}

EasyDevControlsPlayerFrame.CONTROLS = {
    "checkedSuperStrength",
    "multiJumpMultiplier",
    "checkedThirdPersonView",
    "checkedWoodCuttingMarker",
    "checkedAimOverlay",
    "multiRunSpeed",
    "checkedRunSpeedState",
    "checkedRunSpeedKey",
    "multiSetFarmObject",
    "multiSetFarm",
    "buttonConfirmSetFarm",
    "checkedPlayerDebug",
    "checkedPlayerFsmDebug",
    "checkedPlayerFsmStateJumpDebug"
}

function EasyDevControlsPlayerFrame.new(ui, easyDevControls, accessLevel)
    local self = EasyDevControlsBaseFrame.new(EasyDevControlsPlayerFrame_mt, ui, easyDevControls, accessLevel)

    self.player = nil

    self.superStrengthAvailable = true
    self.thirdPersonAvailable = true

    self:registerControls(EasyDevControlsPlayerFrame.CONTROLS)

    return self
end

function EasyDevControlsPlayerFrame:initialize()
    self.superStrengthAvailable = self.easyDevControls.superStrengthAvailable

    if not self.superStrengthAvailable then
        self.checkedSuperStrength:setTexts({EasyDevUtils.getText("easyDevControls_disabled")})
        self.checkedSuperStrength:setState(1)
        self.checkedSuperStrength:setDisabled(true)
    end

    self.thirdPersonAvailable = self.easyDevControls.thirdPersonAvailable

    if not self.thirdPersonAvailable then
        self.checkedThirdPersonView:setTexts({EasyDevUtils.getText("easyDevControls_disabled")})
        self.checkedThirdPersonView:setState(1)
        self.checkedThirdPersonView:setDisabled(true)
    end
end

function EasyDevControlsPlayerFrame:subscribeToMessages(messageCenter)
    messageCenter:subscribe(EasyDevUtils.MESSAGE_TYPE_SETTINGS_CHANGED, self.onSettingChanged, self)
end

function EasyDevControlsPlayerFrame:updateAvailableProperties()
    self.player = g_currentMission.player

    local player = self.player
    local playerStateMachine = player.playerStateMachine

    -- Super Strength
    self.updatingSuperStrength = false
    self.superStrengthState = player.superStrengthEnabled

    if self.superStrengthAvailable then
        local superStrengthDisabled = self:getIsPropertyDisabled("superStrength")

        self.checkedSuperStrength:setIsChecked(self.superStrengthState)
        self.checkedSuperStrength:setDisabled(superStrengthDisabled)
    end

    -- Jump Multiplier
    local jumpHeightDisabled = self:getIsPropertyDisabled("jumpHeight", EasyDevControlsUI.ACCESS_NONE)

    self.jumpHeight = player.motionInformation.jumpHeight or 1

    if jumpHeightDisabled and self.jumpHeight ~= 1 then
        self.jumpHeight = self.easyDevControls:setPlayerJumpHeight(1)
    end

    self.multiJumpMultiplier:setState(Utils.getValueIndex(self.jumpHeight, JUMP_MULTIPLIER_STATES))
    self.multiJumpMultiplier:setDisabled(jumpHeightDisabled)

    -- Third Person View
    if self.thirdPersonAvailable then
        self.checkedThirdPersonView:setIsChecked(player.thirdPersonViewActive)
    end

    -- Wood Cutting Marker
    self.checkedWoodCuttingMarker:setIsChecked(g_woodCuttingMarkerEnabled)

    -- Wood Cutting Marker
    self.checkedAimOverlay:setIsChecked(player.aimOverlay.visible)

    -- Running Speed
    local runningSpeedInfo = self.easyDevControls:getRunningSpeedUiInfo()
    local runningSpeedDisabled = self:getIsPropertyDisabled("runningSpeed", EasyDevControlsUI.ACCESS_NONE)

    self.runningSpeedDisabled = runningSpeedDisabled

    self.multiRunSpeed:setState(runningSpeedInfo[1])
    self.multiRunSpeed:setDisabled(runningSpeedDisabled)

    self.checkedRunSpeedState:setIsChecked(runningSpeedInfo[2])
    self.checkedRunSpeedState:setDisabled(runningSpeedDisabled)

    self.checkedRunSpeedKey:setIsChecked(runningSpeedInfo[3])
    self.checkedRunSpeedKey:setDisabled(runningSpeedDisabled)

    -- Set Farm (TO DO)
    self.setFarmDisabled = true
    self.setFarmIndexToFarmId = {
        AccessHandler.EVERYONE
    }

    if false and self.ui.isMultiplayer then
        self.setFarmDisabled = self:getIsPropertyDisabled("setFarm")

        local setFarmObjectTexts = {
            g_i18n:getText("ui_playerCharacter")
        }

        local controlledVehicle = g_currentMission.controlledVehicle

        if controlledVehicle then
            setFarmObjectTexts[2] = controlledVehicle:getName()

            if controlledVehicle.getAttachedImplements ~= nil then
                local attachedImplements = controlledVehicle:getAttachedImplements()

                for i = 1, #attachedImplements do
                    local object = attachedImplements[i].object

                    if object ~= nil and object.setOwnerFarmId ~= nil then
                        table.insert(setFarmObjectTexts, object:getName())
                    end
                end
            end
        end

        self.multiSetFarmObject:setTexts(setFarmObjectTexts)

        local setFarmTexts = {
            g_i18n:getText("ui_none")
        }

        for _, farm in ipairs(g_farmManager:getFarms()) do
            if farm.farmId ~= FarmManager.SPECTATOR_FARM_ID then
                table.insert(setFarmTexts, farm.name)
                table.insert(self.setFarmIndexToFarmId, farm.farmId)
            end
        end

        self.multiSetFarm:setTexts(setFarmTexts)
    end

    self.multiSetFarmObject:setDisabled(self.setFarmDisabled)
    self.multiSetFarm:setDisabled(self.setFarmDisabled) -- Need listener
    self.buttonConfirmSetFarm:setDisabled(self.setFarmDisabled)

    -- Player Debug
    self.checkedPlayerDebug:setIsChecked(player.baseInformation.isInDebug)

    -- Player Fsm Debug
    self.checkedPlayerFsmDebug:setIsChecked(playerStateMachine.debugMode)

    -- Player Fsm Debug
    self.checkedPlayerFsmStateJumpDebug:setIsChecked(playerStateMachine.playerStateJump.isInDebugMode)

    EasyDevControlsPlayerFrame:superClass().updateAvailableProperties(self)
end

function EasyDevControlsPlayerFrame:update(dt)
    if self.superStrengthAvailable and not self.updatingSuperStrength then
        local player = g_currentMission.player

        if player ~= nil and player.superStrengthEnabled ~= self.superStrengthState then
            self:onSettingChanged(EasyDevUtils.SETTING_SUPER_STRENGTH, player.superStrengthEnabled)
        end
    end

    EasyDevControlsPlayerFrame:superClass().update(self, dt)
end

-- Super Strength
function EasyDevControlsPlayerFrame:onClickSuperStrength(index, element)
    self.updatingSuperStrength = true
    self.superStrengthState = self:getIsCheckedIndex(index)
    self:setInfoText(self.easyDevControls:setSuperStrengthState(self.superStrengthState))
    self.updatingSuperStrength = false
end

-- Jump Multiplier
function EasyDevControlsPlayerFrame:onClickJumpMultiplier(index, element)
    self.jumpHeight = self.easyDevControls:setPlayerJumpHeight(index)
    self:setInfoText(EasyDevUtils.formatText("easyDevControls_jumpMultiplierInfo", element.texts[index]))
end

-- Third Person View
function EasyDevControlsPlayerFrame:onClickThirdPersonView(index, element)
    local player = g_currentMission.player

    player:setThirdPersonViewActive(self:getIsCheckedIndex(index))
    self.easyDevControls:updateThirdPersonCameraModelTarget(player.thirdPersonViewActive and player or nil)

    self:setInfoText(EasyDevUtils.formatText("easyDevControls_thirdPersonViewInfo", self.stateTexts[index]))
end

-- Wood Cutting Marker
function EasyDevControlsPlayerFrame:onClickWoodCuttingMarker(index, element)
    if g_woodCuttingMarkerEnabled ~= self:getIsCheckedIndex(index) then
        Player.consoleCommandToggleWoodCuttingMaker()
    end

    self:setInfoText(EasyDevUtils.formatText("easyDevControls_woodCuttingMarkerInfo", self.stateTexts[index]))
end

-- Aim Overlay / Marker
function EasyDevControlsPlayerFrame:onClickAimOverlay(index, element)
    local player = g_currentMission.player

    if player ~= nil and player.aimOverlay ~= nil then
        player.aimOverlay.visible = self:getIsCheckedIndex(index)
    end

    self:setInfoText(EasyDevUtils.formatText("easyDevControls_aimOverlayInfo", self.stateTexts[index]))
end

-- Running Speed
function EasyDevControlsPlayerFrame:onClickRunSpeed(index, element)
    self.easyDevControls:setRunningSpeedMultiplier(index + 1)
    self:setInfoText(EasyDevUtils.formatText("easyDevControls_runSpeedInfo", self.multiRunSpeed.texts[index]))  --  This needs to be the text not on / off
end

function EasyDevControlsPlayerFrame:onClickRunSpeedState(index, element)
    self.easyDevControls:setRunningSpeedActive(self:getIsCheckedIndex(index))
    self:setInfoText(EasyDevUtils.formatText("easyDevControls_runSpeedStateInfo", self.stateTexts[index]))
end

function EasyDevControlsPlayerFrame:onClickRunSpeedKey(index, element)
    self.easyDevControls:setRunningSpeedKeyActive(self:getIsCheckedIndex(index))
    self:setInfoText(EasyDevUtils.formatText("easyDevControls_runSpeedKeyInfo", EasyDevUtils.getText("input_EDC_PLAYER_RUN_SPEED"), self.stateTexts[index]))
end

-- Set Farm
function EasyDevControlsPlayerFrame:onClickConfirmSetFarm(element)
    local setFarmObjectIndex = self.multiSetFarmObject:getState()
    local setFarmIndex = self.multiSetFarm:getState()

    local farmId = self.setFarmIndexToFarmId[setFarmIndex]
    local farm = g_farmManager:getFarmById(farmId)

    if farm ~= nil then
        if setFarmObjectIndex == 1 then
            if g_currentMission.player ~= nil then
                g_client:getServerConnection():sendEvent(PlayerSetFarmEvent.new(g_currentMission.player, farmId))

                self:setInfoText("Player farm changed to " .. tostring(farm.name).. " (" .. tostring(farm.farmId) .. ")")
            end
        elseif g_currentMission.controlledVehicle ~= nil then
            local controlledVehicle = g_currentMission.controlledVehicle

            if setFarmObjectIndex == 2 then
                controlledVehicle:setOwnerFarmId(farmId) -- Need edc function and event

                self:setInfoText("Vehicle " .. controlledVehicle:getFullName() .. " farm changed to " .. tostring(farm.name).. " (" .. tostring(farm.farmId) .. ")")
            else
                if controlledVehicle.getAttachedImplements ~= nil then
                    local attachedImplements = controlledVehicle:getAttachedImplements()
                    local object = attachedImplements[setFarmObjectIndex - 2].object

                    if object ~= nil and object.setOwnerFarmId ~= nil then
                        object:setOwnerFarmId(farmId) -- Need edc function and event
                        self:setInfoText("Vehicle " .. object:getFullName() .. " farm changed to " .. tostring(farm.name).. " (" .. tostring(farm.farmId) .. ")")
                    end
                end
            end


        end
    else
        self:setInfoText("Failed to set farm!")
    end
end

-- Player Debug
function EasyDevControlsPlayerFrame:onClickPlayerDebug(index, element)
    g_currentMission.player.baseInformation.isInDebug = self:getIsCheckedIndex(index)
    self:setInfoText(EasyDevUtils.formatText("easyDevControls_playerDebugInfo", self.stateTexts[index]))
end

-- Player FSM Debug
function EasyDevControlsPlayerFrame:onClickPlayerFsmDebug(index, element)
    local playerStateMachine = g_currentMission.player.playerStateMachine

    if playerStateMachine ~= nil then
        playerStateMachine.debugMode = self:getIsCheckedIndex(index)
    end

    self:setInfoText(EasyDevUtils.formatText("easyDevControls_playerFsmDebugInfo", self.stateTexts[index]))
end

-- Player FSM State Jump Debug
function EasyDevControlsPlayerFrame:onClickPlayerFsmStateJumpDebug(index, element)
    local playerStateMachine = g_currentMission.player.playerStateMachine

    if playerStateMachine ~= nil then
        playerStateMachine.playerStateJump.isInDebugMode = self:getIsCheckedIndex(index)

        if playerStateMachine.playerStateJump:inDebugMode() then
            playerStateMachine.playerStateJump.playerPos = {}
        end
    end

    self:setInfoText(EasyDevUtils.formatText("easyDevControls_playerFsmStateJumpDebugInfo", self.stateTexts[index]))
end

-- Listeners
function EasyDevControlsPlayerFrame:onSettingChanged(id, value)
    if id == EasyDevUtils.SETTING_SUPER_STRENGTH then
        local player = g_currentMission.player

        self.updatingSuperStrength = false
        self.superStrengthState = player ~= nil and player.superStrengthEnabled or false

        if self.superStrengthAvailable then
            self.checkedSuperStrength:setIsChecked(self.superStrengthState)
            self.checkedSuperStrength:setDisabled(self:getIsPropertyDisabled("superStrength"))
        end
    elseif id == EasyDevUtils.SETTING_JUMP_MULTIPLIER then
        if g_currentMission.player ~= nil then
            local jumpHeightDisabled = self:getIsPropertyDisabled("jumpHeight", EasyDevControlsUI.ACCESS_NONE)

            self.jumpHeight = g_currentMission.player.motionInformation.jumpHeight or 1

            if jumpHeightDisabled and self.jumpHeight ~= 1 then
                self.jumpHeight = self.easyDevControls:setPlayerJumpHeight(1)
            end

            self.multiJumpMultiplier:setState(Utils.getValueIndex(self.jumpHeight, JUMP_MULTIPLIER_STATES))
            self.multiJumpMultiplier:setDisabled(jumpHeightDisabled)
        end
    elseif id == EasyDevUtils.SETTING_RUNNING_SPEED then
        local runningSpeedInfo = self.easyDevControls:getRunningSpeedUiInfo()
        local runningSpeedDisabled = self:getIsPropertyDisabled("runningSpeed", EasyDevControlsUI.ACCESS_NONE)

        self.runningSpeedDisabled = runningSpeedDisabled

        self.multiRunSpeed:setState(runningSpeedInfo[1])
        self.multiRunSpeed:setDisabled(runningSpeedDisabled)

        self.checkedRunSpeedState:setIsChecked(runningSpeedInfo[2])
        self.checkedRunSpeedState:setDisabled(runningSpeedDisabled)

        self.checkedRunSpeedKey:setIsChecked(runningSpeedInfo[3])
        self.checkedRunSpeedKey:setDisabled(runningSpeedDisabled)
    end
end

-- Extras
function EasyDevControlsPlayerFrame:getResetValues()
    local unchecked = CheckedOptionElement.STATE_UNCHECKED

    return {
        checkedSuperStrength = {
            value = unchecked,
            permissionKey = "superStrength"
        },
        multiJumpMultiplier = {
            value = 1,
            permissionKey = "jumpHeight"
        },
        checkedThirdPersonView = {
            value = unchecked
        },
        checkedWoodCuttingMarker = {
            value = unchecked
        },
        multiRunSpeed = {
            value = 3
        },
        checkedRunSpeedState = {
            value = unchecked,
            permissionKey = "runningSpeed"
        },
        checkedRunSpeedKey = {
            value = unchecked
        },
        multiSetFarmObject = {
            value = 1,
            force = false
        },
        multiSetFarm = {
            value = 1,
            force = false
        },
        checkedPlayerDebug = {
            value = unchecked
        },
        checkedPlayerFsmDebug = {
            value = unchecked
        },
        checkedPlayerFsmStateJumpDebug = {
            value = unchecked
        }
    }
end
