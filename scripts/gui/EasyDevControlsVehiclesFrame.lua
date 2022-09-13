--[[
Copyright (C) GtX (Andy), 2019

Author: GtX | Andy
Date: 07.04.2019
Revision: FS22-04

Contact:
https://forum.giants-software.com
https://github.com/GtX-Andy

Important:
Not to be added to any mods / maps or modified from its current release form.
No modifications may be made to this script, including conversion to other game versions without written permission from GtX | Andy

Darf nicht zu Mods / Maps hinzugefügt oder von der aktuellen Release-Form geändert werden.
Ohne schriftliche Genehmigung von GtX | Andy dürfen keine Änderungen an diesem Skript vorgenommen werden, einschließlich der Konvertierung in andere Spielversionen
]]

EasyDevControlsVehiclesFrame = {}

local EasyDevControlsVehiclesFrame_mt = Class(EasyDevControlsVehiclesFrame, EasyDevControlsBaseFrame)
local EMPTY_TABLE = {}

EasyDevControlsVehiclesFrame.L10N_SYMBOL = {}

EasyDevControlsVehiclesFrame.CONTROLS = {
    "multiResetState",
    "buttonConfirmReload",
    "buttonConfirmAnalyseVehicle",
    "multiFillUnit",
    "fillUnitFillLevelTitle",
    "multiFillType",
    "multiFillChange",
    "textInputFillAmount",
    "buttonConfirmFillLevel",
    "buttonToggleCover",
    "multiConditionType",
    "multiConditionSetAddRemove",
    "multiConditionStep",
    "buttonConfirmCondition",
    "multiFuelChange",
    "textInputFuel",
    "buttonConfirmFuel",
    "buttonSetPowerConsumer",
    "textInputMotorTemp",
    "textInputOperatingTime",
    "buttonConfirmRemoveAllVehicles",
    "multiGlobalWiperState",
    "checkedShowVehicleDistance",
    "multiVehicleDebug",
    "checkedTensionBeltsDebug"
}

EasyDevControlsVehiclesFrame.CONDITION_STEP_VALUES =  {0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1}
EasyDevControlsVehiclesFrame.FUEL_TYPE_INDEXS =  {}
EasyDevControlsVehiclesFrame.MAX_WIPER_STATES = 10

function EasyDevControlsVehiclesFrame.new(ui, easyDevControls, accessLevel)
    local self = EasyDevControlsBaseFrame.new(EasyDevControlsVehiclesFrame_mt, ui, easyDevControls, accessLevel)

    self.lastSelectedFillUnit = 1
    self.lastSelectedFillTypeId = 1
    self.lastFillTypeVehicle = nil

    self.updatingDebugState = false
    self:registerControls(EasyDevControlsVehiclesFrame.CONTROLS)

    return self
end

function EasyDevControlsVehiclesFrame:initialize()
    local fillEmptySetTexts = {
        EasyDevUtils.getText("easyDevControls_fill"),
        EasyDevUtils.getText("easyDevControls_empty"),
        EasyDevUtils.getText("easyDevControls_set")
    }

    self.isServer = self.ui.isServer
    self.isMultiplayer = self.ui.isMultiplayer

    self.unknownText = EasyDevUtils.getText("easyDevControls_unknown")
    EasyDevControlsVehiclesFrame.createFuelTypeIndexs()

    self.multiFillChange:setTexts(fillEmptySetTexts)
    self.multiFuelChange:setTexts(fillEmptySetTexts)

    self.multiResetState:setTexts({
        EasyDevUtils.getText("easyDevControls_reload"),
        EasyDevUtils.getText("easyDevControls_reloadReset")
    })

    self.multiConditionType:setTexts({
        EasyDevUtils.getText("easyDevControls_vehicleDirt"),
        EasyDevUtils.getText("easyDevControls_vehicleWear"),
        EasyDevUtils.getText("easyDevControls_vehicleDamage"),
        EasyDevUtils.getText("easyDevControls_all")
    })

    self.multiConditionSetAddRemove:setTexts({
        EasyDevUtils.getText("easyDevControls_set"),
        EasyDevUtils.getText("easyDevControls_add"),
        EasyDevUtils.getText("easyDevControls_remove")
    })
end

function EasyDevControlsVehiclesFrame:subscribeToMessages(messageCenter)
    -- messageCenter:subscribe(EasyDevUtils.MESSAGE_TYPE_SETTINGS_CHANGED, self.onSettingChanged, self)
end

function EasyDevControlsVehiclesFrame:updateAvailableProperties()
    local vehicle, isEntered = self.easyDevControls:getVehicle()
    local noControlledVehicle = g_currentMission.controlledVehicle == nil
    local noVehicle = vehicle == nil

    self.updatingDebugState = true

    -- Reload Vehicle
    local reloadVehicleDisabled = true

    if not noVehicle and self.isServer and not self.isMultiplayer then
        reloadVehicleDisabled = false -- No need for this in MP as all mods are zipped anyway
    end

    self.multiResetState:setDisabled(reloadVehicleDisabled)
    self.buttonConfirmReload:setDisabled(reloadVehicleDisabled)

    -- Analyse Vehicle
    self.buttonConfirmAnalyseVehicle:setDisabled(reloadVehicleDisabled or noControlledVehicle)

    -- Set Fill Level
    local fillUnitTexts = EMPTY_TABLE
    local numFillUnitTexts = 0

    local lastSelectedFillUnit = self.lastSelectedFillUnit or 1
    local lastSelectedFillTypeId = self.lastSelectedFillTypeId or 1

    selectedVehicle = self.easyDevControls:getSelectedVehicle("spec_fillUnit", false)
    self.setFillUnitDisabled = selectedVehicle == nil or self:getIsPropertyDisabled("vehicleFillLevel")

    if not self.setFillUnitDisabled and selectedVehicle.getFillUnits ~= nil then
        self.fillUnitTexts = {}
        self.fillUnitFillTypesTexts = {}
        self.fillUnitSupportedFillTypes = {}

        if selectedVehicle ~= self.lastFillTypeVehicle then
            lastSelectedFillUnit = 1
            lastSelectedFillTypeId = 1
        end

        self.lastFillTypeVehicle = selectedVehicle -- [22/05/2022] Thanks @Alien Jim for mentioning this was not remembered when not exiting vehicle :-)

        for fillUnitIndex, fillUnit in ipairs(selectedVehicle:getFillUnits()) do
            self.fillUnitTexts[fillUnitIndex] = EasyDevUtils.formatText("easyDevControls_fillUnitIndex", tostring(fillUnitIndex))

            self.fillUnitFillTypesTexts[fillUnitIndex] = {}
            self.fillUnitSupportedFillTypes[fillUnitIndex] = {}

            for supportedFillType, _ in pairs(fillUnit.supportedFillTypes) do
                local fillType = g_fillTypeManager:getFillTypeByIndex(supportedFillType)
                local title = fillType ~= nil and fillType.title or self.unknownText

                table.insert(self.fillUnitFillTypesTexts[fillUnitIndex], title)
                table.insert(self.fillUnitSupportedFillTypes[fillUnitIndex], supportedFillType)
            end
        end

        -- Fix for vehicles that include the 'FillUnit Spec' but do not use it for some reason :-/
        numFillUnitTexts = #self.fillUnitFillTypesTexts

        if numFillUnitTexts > 0 and numFillUnitTexts < lastSelectedFillUnit then
            lastSelectedFillUnit = 1
            lastSelectedFillTypeId = 1

            self.lastFillTypeVehicle = nil
        end
    end

    if numFillUnitTexts <= 0 then
        self.fillUnitTexts = {
            "1"
        }

        self.fillUnitFillTypesTexts = {
            {self.unknownText}
        }

        self.fillUnitSupportedFillTypes = {
            {FillType.UNKNOWN}
        }

        lastSelectedFillUnit = 1
        lastSelectedFillTypeId = 1

        self.lastFillTypeVehicle = nil
        self.setFillUnitDisabled = true
    end

    self.lastSelectedFillUnit = lastSelectedFillUnit
    self.lastSelectedFillTypeId = lastSelectedFillTypeId

    fillUnitTexts = self.fillUnitTexts

    self.multiFillUnit:setTexts(fillUnitTexts)
    self.multiFillUnit:setState(lastSelectedFillUnit)
    self.multiFillUnit:setDisabled(self.setFillUnitDisabled or #fillUnitTexts <= 1)

    fillUnitTexts = self.fillUnitFillTypesTexts[lastSelectedFillUnit]

    self.multiFillType:setTexts(fillUnitTexts)
    self.multiFillType:setState(lastSelectedFillTypeId)
    self.multiFillType:setDisabled(self.setFillUnitDisabled or #fillUnitTexts <= 1)

    self.multiFillChange:setState(self.multiFillChange:getState(), true) -- Handles 'textInputFillAmount'
    self.multiFillChange:setDisabled(self.setFillUnitDisabled)

    self.buttonConfirmFillLevel:setDisabled(self.setFillUnitDisabled)

    -- Toggle Cover
    self.buttonToggleCover:setDisabled(self.easyDevControls:getSelectedVehicle("spec_cover", false) == nil)

    -- Set Condition
    local setConditionDisabled = self:getIsPropertyDisabled("vehicleCondition")

    self.multiConditionType:setDisabled(noVehicle or setConditionDisabled)
    self.multiConditionSetAddRemove:setDisabled(noVehicle or setConditionDisabled)
    self.multiConditionStep:setDisabled(noVehicle or setConditionDisabled)
    self.buttonConfirmCondition:setDisabled(noVehicle or setConditionDisabled)

    -- Set Fuel
    local fuelDisabled = true

    if not self:getIsPropertyDisabled("vehicleFuel") and vehicle ~= nil and vehicle.getConsumerFillUnitIndex ~= nil then
        EasyDevControlsVehiclesFrame.createFuelTypeIndexs()

        for _, fillTypeIndex in pairs (EasyDevControlsVehiclesFrame.FUEL_TYPE_INDEXS) do
            if vehicle:getConsumerFillUnitIndex(fillTypeIndex) ~= nil then
                fuelDisabled = false

                break
            end
        end
    end

    self.setFuelDisabled = fuelDisabled
    self.multiFuelChange:setState(self.multiFuelChange:getState(), true) -- Handles 'textInputFuel'

    self.multiFuelChange:setDisabled(fuelDisabled)
    self.buttonConfirmFuel:setDisabled(fuelDisabled)

    -- Set Power Consumer
    self.buttonSetPowerConsumer:setDisabled(reloadVehicleDisabled or noControlledVehicle)

    -- Set Motor Temp
    local setMotorTempDisabled = self:getIsPropertyDisabled("vehicleMotorTemp")
    local tempDisabled = noVehicle or setMotorTempDisabled or vehicle.spec_motorized == nil

    self.textInputMotorTemp.lastValidText = ""
    self.textInputMotorTemp:setDisabled(tempDisabled)

    -- Set Operating Time
    self.setOperatingTimeDisabled = self:getIsPropertyDisabled("vehicleOperatingTime")
    local operatingTimeDisabled = noVehicle or self.setOperatingTimeDisabled or vehicle.setOperatingTime == nil

    self.textInputOperatingTime.lastValidText = ""
    self.textInputOperatingTime:setDisabled(operatingTimeDisabled)

    -- Remove / Delete All Vehicles
    self.buttonConfirmRemoveAllVehicles:setDisabled(not self.hasMasterRights)

    -- Wipers
    if self.wiperTexts == nil then
        self.wiperTexts = {
            EasyDevUtils.getText("easyDevControls_wiperStateRainSensor"),
            g_i18n:getText("ui_off")
        }

        for i = 1, EasyDevControlsVehiclesFrame.MAX_WIPER_STATES do
            table.insert(self.wiperTexts, EasyDevUtils.formatText("easyDevControls_state", tostring(i)))
        end
    end

    self.wipersForcedState = Wipers.forcedState
    self.multiGlobalWiperState:setTexts(self.wiperTexts)
    self.multiGlobalWiperState:setState(self.wipersForcedState + 2)

    -- Vehicle Distance
    self.showVehicleDistance = g_showVehicleDistance
    self.checkedShowVehicleDistance:setIsChecked(self.showVehicleDistance)

    -- Vehicle Debug (Excludes state '10' as 'reverbSettings.xml' is not included so this can be activated by CC if required with custom files.)
    self.vehicleDebugState = VehicleDebug.state
    self.multiVehicleDebug:setState(self.vehicleDebugState + 1)

    -- Tension Belts Debug
    self.tensionBeltDebugRendering = TensionBelts.debugRendering
    self.checkedTensionBeltsDebug:setIsChecked(self.tensionBeltDebugRendering)

    self.updatingDebugState = false

    EasyDevControlsVehiclesFrame:superClass().updateAvailableProperties(self)
end

function EasyDevControlsVehiclesFrame:update(dt)
    if not self.updatingDebugState then
        if Wipers.forcedState ~= self.wipersForcedState then
            self.wipersForcedState = Wipers.forcedState
            self.multiVehicleDebug:setState(self.wipersForcedState + 2)
        end

        if VehicleDebug.state ~= self.vehicleDebugState then
            self.vehicleDebugState = VehicleDebug.state
            self.multiVehicleDebug:setState(self.vehicleDebugState + 1)
        end

        if TensionBelts.debugRendering ~= self.tensionBeltDebugRendering then
            self.tensionBeltDebugRendering = TensionBelts.debugRendering
            self.checkedTensionBeltsDebug:setIsChecked(TensionBelts.debugRendering)
        end

        if g_showVehicleDistance ~= self.showVehicleDistance then
            self.showVehicleDistance = g_showVehicleDistance
            self.checkedShowVehicleDistance:setIsChecked(g_showVehicleDistance)
        end
    end

    EasyDevControlsVehiclesFrame:superClass().update(self, dt)
end

-- Reload Vehicle
function EasyDevControlsVehiclesFrame:onClickConfirmReload(element)
    local resetVehicle = self.multiResetState:getState() == CheckedOptionElement.STATE_CHECKED
    local vehicle, isEntered = self.easyDevControls:getVehicle()
    local radius = 0

    if vehicle ~= nil then
        if not isEntered and g_currentMission.player ~= nil then
            local px, py, pz = getWorldTranslation(g_currentMission.player.rootNode)
            local vx, vy, vz = getWorldTranslation(vehicle.rootNode)

            -- Allows resting of the vehicle your looking at.
            radius = MathUtil.vector3Length(vx - px, vy - py, vz - pz) + 0.2
        end

        -- No need for my own function as editing and XML or I3D in MP is not possible.
        local message = g_currentMission:consoleCommandReloadVehicle(tostring(resetVehicle), radius)

        if message == nil or not message:sub(1, 7) == "Warning" then
            self:setInfoText(EasyDevUtils.formatText("easyDevControls_reloadVehicleInfo", vehicle:getFullName()))

            return
        end
    end

    self:setInfoText(EasyDevUtils.getText("easyDevControls_noValidVehicleWarning"))
end

-- Analyse Vehicle
function EasyDevControlsVehiclesFrame:onClickConfirmAnalyseVehicle(element)
    local vehicle = g_currentMission.controlledVehicle

    if vehicle == nil then
        self:setInfoText(EasyDevUtils.getText("easyDevControls_noValidVehicleWarning"))

        return
    end

    local selectedVehicle = vehicle:getSelectedVehicle()

    if selectedVehicle ~= nil then
        vehicle = selectedVehicle
    end

    local name = vehicle:getFullName()

    local function analyseVehicle(yes)
        if yes then
            if VehicleDebug.consoleCommandAnalyze(nil) == "Analyzed vehicle" then
                self:setInfoText(EasyDevUtils.formatText("easyDevControls_vehicleAnalyseInfo", name))
            else
                self:setInfoText(EasyDevUtils.getText("easyDevControls_vehicleAnalyseFailedWarning"))
            end
        else
            self:setInfoText(EasyDevUtils.getText("easyDevControls_requestCancelledMessage"))
        end
    end

    g_gui:showYesNoDialog({
        text = EasyDevUtils.formatText("easyDevControls_vehicleAnalyseWarning", name),
        dialogType = DialogElement.TYPE_INFO,
        yesText = g_i18n:getText("button_continue"),
        noText = g_i18n:getText("button_cancel"),
        callback = analyseVehicle
    })
end

-- Fill Unit
function EasyDevControlsVehiclesFrame:onClickFillUnit(index, element)
    local fillUnitTexts = self.fillUnitFillTypesTexts[index]

    self.lastSelectedFillUnit = index

    self.multiFillType:setTexts(fillUnitTexts)
    self.multiFillType:setDisabled(self.setFillUnitDisabled or #fillUnitTexts <= 1)

    self.multiFillChange:setState(self.multiFillChange:getState(), true)
end

function EasyDevControlsVehiclesFrame:onClickFillType(index, element)
    self.lastSelectedFillTypeId = index
end

function EasyDevControlsVehiclesFrame:onClickFillState(index, element)
    self.textInputFillAmount:setDisabled(self.setFillUnitDisabled or index < 3)

    if index == 1 then
        local selectedVehicle = self.easyDevControls:getSelectedVehicle("spec_fillUnit", false)

        if selectedVehicle ~= nil and selectedVehicle.getFillUnitCapacity ~= nil then
            local capacity = selectedVehicle:getFillUnitCapacity(self.lastSelectedFillUnit)

            if capacity ~= nil then
                if math.abs(capacity) == math.huge then
                    capacity = 100
                end

                self.textInputFillAmount.lastValidText = g_i18n:formatFluid(capacity)
                self.textInputFillAmount:setText(self.textInputFillAmount.lastValidText)
            else
                self:onTextInputEscPressed(self.textInputFillAmount)
            end
        else
            self:onTextInputEscPressed(self.textInputFillAmount)
        end
    elseif index == 2 then
        self.textInputFillAmount.lastValidText = "0 l"
        self.textInputFillAmount:setText("0 l")
    else
        self:onTextInputEscPressed(self.textInputFillAmount)
    end
end

function EasyDevControlsVehiclesFrame:onFillAmountEnterPressed(element)
    if element.text ~= "" then
        self:setFillUnitFillLevel(tonumber(element.text), element.text)

        element:setText("")
    else
        self:setInfoText(EasyDevUtils.getText("easyDevControls_invalidValueWarning"))
    end

    element.lastValidText = ""
end

function EasyDevControlsVehiclesFrame:onClickConfirmFillLevel(element)
    local index = self.multiFillChange:getState()

    if index < 3 then
        self:setFillUnitFillLevel(index == 1 and 1e+7 or 0)
    else
        self:onFillAmountEnterPressed(self.textInputFillAmount)
    end
end

function EasyDevControlsVehiclesFrame:setFillUnitFillLevel(amount)
    if amount ~= nil then
        local vehicle = self.easyDevControls:getSelectedVehicle("spec_fillUnit", false)

        if vehicle ~= nil then
            local fillUnitIndex = self.lastSelectedFillUnit

            local supportedFillTypes = self.fillUnitSupportedFillTypes[fillUnitIndex]
            local fillTypeIndex = supportedFillTypes ~= nil and supportedFillTypes[self.lastSelectedFillTypeId] or nil

            if amount == 0 and vehicle.spec_fillUnit.removeVehicleIfEmpty then
                local function ignoreRemoveIfEmptyCallback(ignoreRemoveIfEmpty)
                    self:setInfoText(self.easyDevControls:setFillUnitFillLevel(vehicle, fillUnitIndex, fillTypeIndex, amount, ignoreRemoveIfEmpty))
                end

                g_gui:showYesNoDialog({
                    text = EasyDevUtils.formatText("easyDevControls_ignoreRemoveIfEmptyMessage", vehicle:getFullName()),
                    callback = ignoreRemoveIfEmptyCallback
                })
            else
                if vehicle:getFillUnitCapacity(fillUnitIndex) == math.huge then
                    amount = math.min(amount, 100)
                end

                self:setInfoText(self.easyDevControls:setFillUnitFillLevel(vehicle, fillUnitIndex, fillTypeIndex, amount, false))
            end
        else
            self:setInfoText(EasyDevUtils.getText("easyDevControls_noValidVehicleWarning"))
        end
    else
        self:setInfoText(EasyDevUtils.getText("easyDevControls_invalidValueWarning"))
    end
end

-- Toggle Cover
function EasyDevControlsVehiclesFrame:onClickToggleCover(element)
    local selectedVehicle = self.easyDevControls:getSelectedVehicle("spec_cover", false)

    if selectedVehicle ~= nil then
        local spec = selectedVehicle.spec_cover
        local newState = spec.state + 1

        if newState > #spec.covers then
            newState = 0
        end

        if selectedVehicle:getIsNextCoverStateAllowed(newState) then
            selectedVehicle:setCoverState(newState)

            spec.isStateSetAutomatically = false

            local l10n = "easyDevControls_open"

            if newState == 0 then
                l10n = "easyDevControls_closed"
            end

            self:setInfoText(EasyDevUtils.formatText("easyDevControls_toggleCoverInfo", selectedVehicle:getFullName(), EasyDevUtils.getText(l10n):lower(), tostring(newState)))
        end
    else
        self:setInfoText(EasyDevUtils.getText("easyDevControls_noValidVehicleWarning"))
    end
end

-- Set Condition
function EasyDevControlsVehiclesFrame:onClickConditionSetAddRemove(index, element)
    if index > 1 and self.multiConditionStep:getState() == 1 then
        self.multiConditionStep:setState(2)
    end
end

function EasyDevControlsVehiclesFrame:onClickConditionStep(index, element, leftClick)
    if index == 1 and self.multiConditionSetAddRemove:getState() > 1 then
        element:setState(leftClick and #element.texts or 2)
    end
end

function EasyDevControlsVehiclesFrame:onClickConfirmCondition(element)
    local vehicle, isEntered = self.easyDevControls:getVehicle()
    local typeIndex = self.multiConditionType:getState() - 1
    local applyType = self.multiConditionSetAddRemove:getState()
    local amount = EasyDevControlsVehiclesFrame.CONDITION_STEP_VALUES[self.multiConditionStep:getState()]

    self:setInfoText(self.easyDevControls:setVehicleCondition(vehicle, isEntered, typeIndex, applyType == 1, applyType < 3 and amount or -amount))
end

-- Set Fuel
function EasyDevControlsVehiclesFrame:onClickFuelChangeType(index, element)
    self.textInputFuel:setDisabled(self.setFuelDisabled or index < 3)

    if index == 1 then
        local vehicle, _ = self.easyDevControls:getVehicle()

        if vehicle ~= nil and vehicle.spec_motorized ~= nil and vehicle.getConsumerFillUnitIndex ~= nil then
            local _, capacity = SpeedMeterDisplay.getVehicleFuelLevelAndCapacity(vehicle)

            if capacity ~= nil then
                self.textInputFuel.lastValidText = g_i18n:formatFluid(capacity)
                self.textInputFuel:setText(self.textInputFuel.lastValidText)
            else
                self:onTextInputEscPressed(self.textInputFuel)
            end
        else
            self:onTextInputEscPressed(self.textInputFuel)
        end
    elseif index == 2 then
        self.textInputFuel.lastValidText = "0 l"
        self.textInputFuel:setText("0 l")
    else
        self:onTextInputEscPressed(self.textInputFuel)
    end
end

function EasyDevControlsVehiclesFrame:onFuelEnterPressed(element)
    if element.text ~= "" then
        self:setVehicleFuel(tonumber(element.text))

        element:setText("")
    else
        self:setInfoText(EasyDevUtils.getText("easyDevControls_invalidValueWarning"))
    end

    element.lastValidText = ""
end

function EasyDevControlsVehiclesFrame:onClickConfirmFuel(element)
    local index = self.multiFuelChange:getState()

    if index < 3 then
        self:setVehicleFuel(index == 1 and 1e+7 or 0)
    else
        self:onFuelEnterPressed(self.textInputFuel)
    end
end

function EasyDevControlsVehiclesFrame:setVehicleFuel(amount)
    if amount ~= nil then
        local vehicle, _ = self.easyDevControls:getVehicle()

        if vehicle ~= nil and vehicle.spec_motorized ~= nil and vehicle.getConsumerFillUnitIndex ~= nil then
            local _, capacity = SpeedMeterDisplay.getVehicleFuelLevelAndCapacity(vehicle)

            if capacity ~= nil and math.abs(capacity) ~= math.huge then
                self:setInfoText(self.easyDevControls:setVehicleFuel(vehicle, amount))
            end
        else
            self:setInfoText(EasyDevUtils.getText("easyDevControls_noValidVehicleWarning"))
        end
    else
        self:setInfoText(EasyDevUtils.getText("easyDevControls_invalidValueWarning"))
    end
end

-- Set Power Consumer
function EasyDevControlsVehiclesFrame:onClickSetPowerConsumer(element)
    if g_currentMission ~= nil and g_currentMission.controlledVehicle ~= nil then
        local isPowerConsumer, selectedImplement = self.easyDevControls:getSelectedImplementIsPowerConsumer(g_currentMission.controlledVehicle)

        if isPowerConsumer then
            local spec = selectedImplement.spec_powerConsumer
            local properties = EasyDevControlsVehiclesFrame.getPowerConsumerProperties(spec)

            local function setPowerConsumer(yes, callbackValues)
                if not yes then
                    self:setInfoText(EasyDevUtils.getText("easyDevControls_requestCancelledMessage"))

                    return
                end

                if callbackValues == nil then
                    self:setInfoText(EasyDevUtils.getText("easyDevControls_requestFailedMessage"))

                    return
                end

                if Utils.getNoNil(callbackValues["resetToDefault"], false) then
                    if spec.edcOriginalValues ~= nil then
                        for name, value in pairs (spec.edcOriginalValues) do
                            if name == "forceDir" then
                                callbackValues[name] = value < 0 and 1 or 2
                            else
                                callbackValues[name] = value
                            end
                        end
                    else
                        self:setInfoText(EasyDevUtils.getText("easyDevControls_defaultResetFailedMessage"))

                        return
                    end
                end

                local neededMinPtoPower = Utils.getNoNil(callbackValues["neededMinPtoPower"], spec.neededMinPtoPower)
                local neededMaxPtoPower = Utils.getNoNil(callbackValues["neededMaxPtoPower"], spec.neededMaxPtoPower)
                local forceFactor = Utils.getNoNil(callbackValues["forceFactor"], spec.forceFactor)
                local maxForce = Utils.getNoNil(callbackValues["maxForce"], spec.maxForce)

                local forceDir = callbackValues["forceDir"]

                if forceDir ~= nil then
                    forceDir = forceDir == 2 and 1 or -1
                else
                    forceDir = spec.forceDir
                end

                local ptoRpm = Utils.getNoNil(callbackValues["ptoRpm"], spec.ptoRpm)
                local syncVehicles = Utils.getNoNil(callbackValues["syncVehicles"], 1) == CheckedOptionElement.STATE_CHECKED

                self:setInfoText(self.easyDevControls:setPowerConsumer(selectedImplement, neededMinPtoPower, neededMaxPtoPower, forceFactor, maxForce, forceDir, ptoRpm, syncVehicles))
            end

            self.ui:showDynamicSelectionDialog({
                headerText = selectedImplement:getName(),
                callback = setPowerConsumer,
                properties = properties,
                numHorizontal = 2,
                numVertical = 4
            })
        else
            self:setInfoText(EasyDevUtils.getText("easyDevControls_setPowerConsumerWarning"))
        end
    end
end

function EasyDevControlsVehiclesFrame.getPowerConsumerProperties(spec)
    local powerConsumerProperties = {
        {
            name = "neededMinPtoPower",
            title = EasyDevUtils.getText("easyDevControls_neededMinPtoPowerTitle"),
            typeId = DynamicSelectionDialog.TYPE_TEXT_INPUT,
            ignoreEsc = true
        },
        {
            name = "neededMaxPtoPower",
            title = EasyDevUtils.getText("easyDevControls_neededMaxPtoPowerTitle"),
            typeId = DynamicSelectionDialog.TYPE_TEXT_INPUT,
            ignoreEsc = true
        },
        {
            name = "forceFactor",
            title = EasyDevUtils.getText("easyDevControls_forceFactorTitle"),
            typeId = DynamicSelectionDialog.TYPE_TEXT_INPUT,
            ignoreEsc = true
        },
        {
            name = "maxForce",
            title = EasyDevUtils.getText("easyDevControls_maxForceTitle"),
            typeId = DynamicSelectionDialog.TYPE_TEXT_INPUT,
            ignoreEsc = true
        },
        {
            name = "forceDir",
            title = EasyDevUtils.getText("easyDevControls_forceDir"),
            typeId = DynamicSelectionDialog.TYPE_MULTI_TEXT_OPTION,
            texts = {"-1", "1"},
        },
        {
            name = "ptoRpm",
            title = EasyDevUtils.getText("easyDevControls_ptoRpm"),
            typeId = DynamicSelectionDialog.TYPE_TEXT_INPUT,
            ignoreEsc = true
        },
        {
            name = "syncVehicles",
            title = EasyDevUtils.getText("easyDevControls_syncVehicles"),
            typeId = DynamicSelectionDialog.TYPE_CHECKED_OPTION,
            defaultValue = CheckedOptionElement.STATE_CHECKED
        },
        {
            name = "resetToDefault",
            title = EasyDevUtils.getText("easyDevControls_resetToDefault"),
            typeId = DynamicSelectionDialog.TYPE_BUTTON,
            defaultValue = false
        }
    }

    for i, property in ipairs (powerConsumerProperties) do
        if spec ~= nil then
            local value = spec[property.name]

            if value ~= nil then
                if property.name == "forceDir" then
                    property.defaultValue = value < 0 and 1 or 2
                else
                    property.defaultValue = value
                end
            end
        end
    end

    return powerConsumerProperties
end

-- Set Motor Temp
function EasyDevControlsVehiclesFrame:onMotorTempEnterPressed(element)
    if element.text ~= "" then
        local temperature = tonumber(element.text)

        if temperature ~= nil then
            local vehicle, _ = self.easyDevControls:getVehicle()

            self:setInfoText(self.easyDevControls:setVehicleMotorTemperature(vehicle, temperature))
        else

        end

        element:setText("")
    end

    element.lastValidText = ""
end

-- Set Operating Time
function EasyDevControlsVehiclesFrame:onOperatingTimeEnterPressed(element)
    if element.text ~= "" then
        local operatingTime = tonumber(element.text)

        if operatingTime ~= nil then
            local vehicle, _ = self.easyDevControls:getVehicle()

            self:setInfoText(self.easyDevControls:setVehicleOperatingTime(vehicle, operatingTime))
        else

        end

        element:setText("")
    end

    element.lastValidText = ""
end

-- Remove All Vehicles
function EasyDevControlsVehiclesFrame:onClickConfirmRemoveAllVehicles(element)
    local function removeAllVehicles(yes)
        if yes then
            self.buttonConfirmRemoveAllVehicles:setDisabled(true)
            self:setInfoText(self.easyDevControls:removeAllObjects(EasyDevControlsRemoveAllObjectsEvent.VEHICLES))
        end
    end

    g_gui:showYesNoDialog({
        text = EasyDevUtils.formatText("easyDevControls_removeAllObjectsWarning", EasyDevUtils.getText("easyDevControls_typeVehicles")),
        yesText = g_i18n:getText("button_continue"),
        noText = g_i18n:getText("button_cancel"),
        callback = removeAllVehicles
    })
end

-- Wipers
function EasyDevControlsVehiclesFrame:onClickGlobalWiperState(index, element)
    self.updatingDebugState = true

    self.wipersForcedState = index - 2
    Wipers.forcedState = EasyDevUtils.getNoNilClamp(self.wipersForcedState, -1, 999, -1)

    self.updatingDebugState = false
end

-- Show Vehicle Distance
function EasyDevControlsVehiclesFrame:onClickShowVehicleDistance(index, element)
    self.updatingDebugState = true

    self.showVehicleDistance = self:getIsCheckedIndex(index)
    g_currentMission:consoleCommandShowVehicleDistance(self.showVehicleDistance)

    self:setInfoText(EasyDevUtils.formatText("easyDevControls_vehicleDistanceInfo", self.stateTexts[index]))

    self.updatingDebugState = false
end

-- Vehicle Debug
function EasyDevControlsVehiclesFrame:onClickVehicleDebug(index, element)
    self.updatingDebugState = true

    self.vehicleDebugState = index - 1
    VehicleDebug.setState(self.vehicleDebugState)
    self:setInfoText(EasyDevUtils.formatText("easyDevControls_debugStateInfo", element.texts[index]))

    self.updatingDebugState = false
end

-- Tension Belts Debug
function EasyDevControlsVehiclesFrame:onClickTensionBeltsDebug(index, element)
    self.updatingDebugState = true

    self.tensionBeltDebugRendering = self:getIsCheckedIndex(index)
    TensionBelts.debugRendering = self.tensionBeltDebugRendering
    self:setInfoText(EasyDevUtils.formatText("easyDevControls_tensionBeltsDebugInfo", self.stateTexts[index]))

    self.updatingDebugState = false
end

-- Listeners
function EasyDevControlsVehiclesFrame:onSettingChanged(id, value)
end

-- Extras
function EasyDevControlsVehiclesFrame.createFuelTypeIndexs()
    if EasyDevControlsVehiclesFrame.FUEL_TYPE_INDEXS == nil then
        EasyDevControlsVehiclesFrame.FUEL_TYPE_INDEXS = {}
    end

    if #EasyDevControlsVehiclesFrame.FUEL_TYPE_INDEXS < 3 then
        EasyDevControlsVehiclesFrame.FUEL_TYPE_INDEXS[1] = FillType.DIESEL
        EasyDevControlsVehiclesFrame.FUEL_TYPE_INDEXS[2] = FillType.ELECTRICCHARGE
        EasyDevControlsVehiclesFrame.FUEL_TYPE_INDEXS[3] = FillType.METHANE
    end
end

-- Extras
function EasyDevControlsVehiclesFrame:getResetValues()
    return {
        multiGlobalWiperState = {
            value = -1
        },
        checkedShowVehicleDistance = {
            value = CheckedOptionElement.STATE_UNCHECKED
        },
        multiVehicleDebug = {
            value = 1
        },
        checkedTensionBeltsDebug = {
            value = CheckedOptionElement.STATE_UNCHECKED
        }
    }
end
