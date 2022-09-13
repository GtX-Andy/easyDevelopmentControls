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

EasyDevControls = {}

local EasyDevControls_mt = Class(EasyDevControls)

local edc_timeScaleCustomSettingsActive = false
local edc_timeScaleCustomSettings = {0.5, 1, 2, 3, 4, 5, 6, 10, 15, 30, 60, 120, 240, 360, 500, 2000, 5000, 10000, 20000, 40000, 60000}

local edc_maxRunningSpeedActive = false
local edc_maxRunningSpeedInputActive = false

local edc_maxRunningSpeedMultiplier = 4
local edc_maxRunningSpeed = 9 * edc_maxRunningSpeedMultiplier

function EasyDevControls.new(isServer, isClient, buildId, versionString, releaseType, loadConsoleCommands)
    local self = setmetatable({}, EasyDevControls_mt)

    self.isServer = isServer
    self.isClient = isClient

    self.buildId = buildId
    self.versionString = versionString
    self.releaseType = releaseType

    self.toggleHudInputEnabled = false
    self.deleteObjectsInputEnabled = false

    self.jumpHeight = 1
    self.thirdPersonAvailable = true
    self.superStrengthAvailable = true

    self.formatedDeleteText = EasyDevUtils.getText("easyDevControls_deleteObject")
    self.requestFailedText = EasyDevUtils.getText("easyDevControls_requestFailedMessage")
    self.serverRequestText = EasyDevUtils.getText("easyDevControls_serverRequestMessage")

    -- Standard
    addConsoleCommand("leaveCurrentGame", "Exit to the main menu quickly without saving. [keepLogFile]", "consoleCommandLeave", self)

    -- Only with -consoleCommandsGtX start parameter
    if loadConsoleCommands then
        local warning = " IMPORTANT: This function will continue to be used until complete application exit!"

        addConsoleCommand("gtxRestartGameWithParamater", "Restart the game and apply given parameter, parameter must start with hyphen [parameter][clearLogFile]" .. warning, "consoleCommandRestartWithParamater", self)
        addConsoleCommand("gtxRestartCurrentSaveGame", "Restarts the game and reloads the current savegame [clearLogFile]" .. warning, "consoleCommandRestartCurrentSaveGame", self)

        addConsoleCommand("gtxResetEDC", "Resets selected settings to GtX's standard setup.", "consoleCommandResetEDC", self)
        addConsoleCommand("gtxPrint", "Prints the given path information [clearLog][path][function parameters (Use 'self' if required) or table depth | maxDepth]", "consoleCommandPrintEnvironment", self)
        addConsoleCommand("gtxPrintScenegraph", "Prints the map scenegraph to the log [nodeName][visibleOnly][clearLog].", "consoleCommandPrintScenegraph", self)
    end

    self.isEnabled = false

    return self
end

function EasyDevControls:load(mission)
    if g_easyDevHotspotsManager ~= nil then
        g_easyDevHotspotsManager:setCurrentMission(mission)
    end

    self.isMultiplayer = mission.missionDynamicInfo.isMultiplayer
    self.ui = EasyDevControlsUI.new(self.isServer, self.isClient, self, self.isMultiplayer, mission)
end

function EasyDevControls:onLoadMapFinished()
    EasyDevUtils.INVALID_FILLTYPE = 2 ^ FillTypeManager.SEND_NUM_BITS

    g_asyncTaskManager:addTask(function ()
        self.ui:checkModConflicts()
        self.ui:load(false)

        Utils.getNumTimeScales = Utils.overwrittenFunction(Utils.getNumTimeScales, self.inj_utils_getNumTimeScales)
        Utils.getTimeScaleString = Utils.overwrittenFunction(Utils.getTimeScaleString, self.inj_utils_getTimeScaleString)
        Utils.getTimeScaleIndex = Utils.overwrittenFunction(Utils.getTimeScaleIndex, self.inj_utils_getTimeScaleIndex)
        Utils.getTimeScaleFromIndex = Utils.overwrittenFunction(Utils.getTimeScaleFromIndex, self.inj_utils_getTimeScaleFromIndex)

        Player.getDesiredSpeed = Utils.overwrittenFunction(Player.getDesiredSpeed, self.inj_player_getDesiredSpeed)
    end)
end

function EasyDevControls:onMissionStarted()
    self.ui:onMissionStarted()
    self.isEnabled = true

    g_asyncTaskManager:addTask(function ()
        self:onSetCustomTimeScaleState()

        if self.jumpHeight > 1 then
            self:setPlayerJumpHeight(self.jumpHeight)
        end
    end)
end

function EasyDevControls:delete(mission)
    if self.ui ~= nil then
        self.ui:delete()
        self.ui = nil
    end

    removeConsoleCommand("leaveCurrentGame")

    removeConsoleCommand("gtxRestartGameWithParamater")
    removeConsoleCommand("gtxRestartCurrentSaveGame")

    removeConsoleCommand("gtxResetEDC")
    removeConsoleCommand("gtxPrint")
    removeConsoleCommand("gtxPrintScenegraph")
end

function EasyDevControls:saveSettingsToXMLFile(xmlFile, key, xmlFilename, missionInfo, mission)
    setXMLBool(xmlFile, key .. ".general.toggleHudInputEnabled", self.toggleHudInputEnabled)
    setXMLBool(xmlFile, key .. ".general.timeScaleCustomSettingsActive", edc_timeScaleCustomSettingsActive)

    setXMLBool(xmlFile, key .. ".player.maxRunningSpeedInputActive", edc_maxRunningSpeedInputActive)
    setXMLInt(xmlFile, key .. ".player.maxRunningSpeedMultiplier", edc_maxRunningSpeedMultiplier)

    setXMLInt(xmlFile, key .. ".player.jumpHeight", self.jumpHeight)
end

function EasyDevControls:loadSettingsFromXMLFile(xmlFile, key, xmlFilename, missionInfo, mission)
    self:setToggleHudInputEnabled(getXMLBool(xmlFile, key .. ".general.toggleHudInputEnabled"))
    self:setCustomTimeScaleState(getXMLBool(xmlFile, key .. ".general.timeScaleCustomSettingsActive"))

    self:setRunningSpeedKeyActive(getXMLBool(xmlFile, key .. ".player.maxRunningSpeedInputActive"))
    self:setRunningSpeedMultiplier(EasyDevUtils.getNoNilClamp(getXMLInt(xmlFile, key .. ".player.maxRunningSpeedMultiplier"), 2, 14, 4))

    self.jumpHeight = EasyDevUtils.getNoNilClamp(getXMLInt(xmlFile, key .. ".player.jumpHeight"), 1, 10, 1)
end

function EasyDevControls:update(dt)
    if self.isServer and self.treesToCut ~= nil then
        local numTrees = #self.treesToCut

        if g_treePlantManager.loadTreeTrunkData == nil then
            for _, treeToCut in pairs (self.treesToCut) do
                if treeToCut.dataAdded then
                    numTrees = numTrees - 1
                else
                    g_treePlantManager.loadTreeTrunkData = treeToCut
                    treeToCut.dataAdded = true
                end
            end
        end

        if numTrees <= 0 and not self.addingTreeToCut then
            self.treesToCut = nil
        end
    end

    if self.deleteObjectsInputEnabled and (self.isServer or g_currentMission.isMasterUser) then
        local eventIdActive, eventText = false, ""

        if self.controlledPlayer ~= nil and not self.controlledPlayer.isCarryingObject then
            local hudUpdater = self.controlledPlayer.hudUpdater -- No need to waste resources with another 'raycast' function when Giants have one

            if hudUpdater.object ~= nil then
                if hudUpdater.isVehicle then
                    if hudUpdater.object.trainSystem == nil then
                        eventIdActive = true
                        eventText = EasyDevUtils.formatText("easyDevControls_deleteObject", hudUpdater.object:getName())
                    end
                elseif hudUpdater.isBale then
                    eventIdActive = true
                    eventText = EasyDevUtils.formatText("easyDevControls_deleteObject", EasyDevUtils.getText("easyDevControls_typeBale"))
                elseif hudUpdater.isPallet then
                    eventIdActive = true
                    eventText = EasyDevUtils.formatText("easyDevControls_deleteObject", EasyDevUtils.getText("easyDevControls_typePallet"))
                elseif hudUpdater.isSplitShape then
                    eventIdActive = true
                    eventText = EasyDevUtils.formatText("easyDevControls_deleteObject", EasyDevUtils.getText("easyDevControls_typeLog"))
                end
            else
                local x, y, z = localToWorld(self.controlledPlayer.cameraNode, 0, 0, 1)
                local dx, dy, dz = localDirectionToWorld(self.controlledPlayer.cameraNode, 0, 0, -1)

                self.lastHitObject = nil
                self.lastHitObjectTypeId = nil

                raycastAll(x, y, z, dx, dy, dz, "treeRaycastCallback", Player.MAX_PICKABLE_OBJECT_DISTANCE, self)

                if self.lastHitObject ~= nil and entityExists(self.lastHitObject) then
                    local splitTypeId = getSplitType(self.lastHitObject)

                    if splitTypeId ~= 0 then
                        local splitType = g_splitTypeManager:getSplitTypeByIndex(splitTypeId)
                        local splitTypeName = splitType and splitType.title

                        local farmName = ""
                        local farmland = g_farmlandManager:getFarmlandAtWorldPosition(x, z)

                        local box = hudUpdater.objectBox

                        box:clear()

                        if getName(self.lastHitObject) == "splitGeom" and getHasClassId(self.lastHitObject, ClassIds.SHAPE) then
                            eventText = EasyDevUtils.getText("easyDevControls_infohud_stump")
                            self.lastHitObjectTypeId = EasyDevControlsDeleteObjectEvent.TYPE_STUMP
                        else
                            eventText = EasyDevUtils.getText("easyDevControls_infohud_tree")
                            self.lastHitObjectTypeId = EasyDevControlsDeleteObjectEvent.TYPE_TREE
                        end

                        box:setTitle(eventText)

                        if farmland ~= nil then
                            local ownerFarmId = g_farmlandManager:getFarmlandOwner(farmland.id)

                            if ownerFarmId == g_currentMission:getFarmId() and ownerFarmId ~= FarmManager.SPECTATOR_FARM_ID then
                                farmName = g_i18n:getText("fieldInfo_ownerYou")
                            elseif ownerFarmId == AccessHandler.EVERYONE or ownerFarmId == AccessHandler.NOBODY then
                                local npc = farmland:getNPC()

                                farmName = npc.title
                            else
                                local farm = g_farmManager:getFarmById(ownerFarmId)

                                if farm ~= nil then
                                    farmName = farm.name
                                else
                                    farmName = g_i18n:getText("fieldInfo_ownerNobody")
                                end
                            end
                        else
                            farmName = g_i18n:getText("fieldInfo_ownerNobody")
                        end

                        box:addLine(g_i18n:getText("fieldInfo_ownedBy"), farmName)

                        if splitTypeName ~= nil then
                            box:addLine(g_i18n:getText("infohud_type"), splitTypeName)
                        end

                        box:showNextFrame()

                        eventIdActive = true
                        eventText = EasyDevUtils.formatText("easyDevControls_deleteObject", eventText)
                    end
                end
            end
        end

        if self.lastEventIdActive ~= eventIdActive then
            self.lastEventIdActive = eventIdActive

            g_inputBinding:setActionEventTextVisibility(self.eventIdObjectDelete, eventIdActive)
            g_inputBinding:setActionEventActive(self.eventIdObjectDelete, eventIdActive)
        end

        if eventIdActive then
            g_inputBinding:setActionEventText(self.eventIdObjectDelete, eventText)
        end
    end

    if self.isClient then
        if self.thirdPersonAvailable and self.thirdPersonActive then
            self.controlledPlayer.baseInformation.isCrouched = self.controlledPlayer.playerStateMachine:isActive("crouch")
        end
    end
end

-- Cheat Money (Add | Remove | Set)
function EasyDevControls:changeMoney(amount, typeId, farmId)
    amount = amount ~= nil and tonumber(amount)

    if amount == nil then
        return EasyDevUtils.getText("easyDevControls_invalidMoneyWarning")
    end

    if farmId == nil or farmId == FarmManager.SPECTATOR_FARM_ID then
        return EasyDevUtils.getText("easyDevControls_invalidFarmWarning")
    end

    if self.isServer then
        local farm = g_farmManager:getFarmById(farmId)
        local l10n = "easyDevControls_addMoneyInfo"
        local money = amount

        if farm == nil then
            return EasyDevUtils.getText("easyDevControls_invalidFarmWarning")
        end

        if typeId == EasyDevControlsMoneyEvent.TYPES.REMOVEMONEY then
            amount = -amount
            l10n = "easyDevControls_removeMoneyInfo"
        elseif typeId == EasyDevControlsMoneyEvent.TYPES.SETMONEY then
            local balance = farm:getBalance()

            amount = -balance + amount
            l10n = "easyDevControls_setMoneyInfo"
        end

        farm:changeBalance(amount, MoneyType.OTHER)
        g_currentMission:addMoneyChange(amount, farmId, MoneyType.OTHER, true)

        return EasyDevUtils.formatText(l10n, g_i18n:formatMoney(money, 0, true, true))
    else
        return self:clientSendEvent(EasyDevControlsMoneyEvent.new(amount, typeId))
    end
end

-- Hud Key
function EasyDevControls:setToggleHudInputEnabled(enabled)
    self.toggleHudInputEnabled = Utils.getNoNil(enabled, false)

    if self.eventIdToggleHud ~= nil then
        g_inputBinding:setActionEventActive(self.eventIdToggleHud, self.toggleHudInputEnabled)
    end

    return self.toggleHudInputEnabled
end

-- Delete Objects Key
function EasyDevControls:setDeleteObjectsInputEnabled(enabled)
    if self.isServer or g_currentMission.isMasterUser then
        enabled = Utils.getNoNil(enabled, false)
    else
        enabled = false
    end

    self.deleteObjectsInputEnabled = enabled

    if self.eventIdObjectDelete ~= nil then
        g_inputBinding:setActionEventTextVisibility(self.eventIdObjectDelete, false)
        g_inputBinding:setActionEventActive(self.eventIdObjectDelete, false)
        g_inputBinding:setActionEventText(self.eventIdObjectDelete, EasyDevUtils.getText("input_EDC_OBJECT_DELETE"))
    end

    return self.deleteObjectsInputEnabled
end

-- Teleport Player or Vehicle
function EasyDevControls:teleport(object, positionX, positionZ, rotationY)
    if object == nil or positionX == nil then
        EasyDevUtils.devInfo("Teleport failed no object or (field id or x/z coordinates) given!")

        return
    end

    if self.isServer then
        local fieldId = positionX
        local isField = positionZ == nil

        local mapPosX = math.floor(positionX + 0.5)
        local mapPosZ = not isField and math.floor(positionZ + 0.5) or 0

        -- If there is no positionZ then check if it is a field
        if isField then
            local field = g_fieldManager:getFieldByIndex(positionX)

            if field ~= nil then
                positionX = field.posX
                positionZ = field.posZ
            else
                EasyDevUtils.devInfo("Teleport failed, no z coordinate given and '%s' is not a valid field id!", positionX)

                return
            end
        else
            local terrainSize = g_currentMission.terrainSize
            local halfTerrainSize = terrainSize * 0.5

            positionX = EasyDevUtils.getNoNilClamp(positionX, 0, terrainSize, halfTerrainSize) - halfTerrainSize
            positionZ = EasyDevUtils.getNoNilClamp(positionZ, 0, terrainSize, halfTerrainSize) - halfTerrainSize
        end

        if object:isa(Player) then
            object:moveTo(positionX, 1.2, positionZ, false, false)

            if rotationY ~= nil and object == g_currentMission.player then
                -- No point syncing this, not hard to turn a player around in MP.

                if not object.thirdPersonViewActive then
                    object:setRotation(0, rotationY + math.pi)
                elseif self.thirdPersonAvailable and self.thirdPersonActive then
                    object:setRotation(0, rotationY)
                    object.model:setSkeletonRotation(rotationY)
                else
                    object:setRotation(0, rotationY - math.pi)
                end
            end

            if isField then
                return EasyDevUtils.formatText("easyDevControls_teleportPlayerFieldInfo", fieldId)
            end

            return EasyDevUtils.formatText("easyDevControls_teleportPlayerInfo", mapPosX, mapPosZ)
        end

        if object:isa(Vehicle) then
            local rootVehicle = object:findRootVehicle() or object
            local vehicles, attachedVehicles = EasyDevUtils.getVehiclesPositionData(rootVehicle, object)

            -- Move all vehicles
            for i = 1, #vehicles do
                local vehicleData = vehicles[i]
                local vehicle = vehicleData.vehicle

                local x, y, z = positionX, 0.5, positionZ
                local _, ry, _ = getWorldRotation(vehicle.rootNode)

                if vehicleData.isImplement and vehicleData.offset ~= nil then
                    x, y, z = localToWorld(rootVehicle.rootNode, unpack(vehicleData.offset))
                end

                vehicle:setRelativePosition(x, 0.5, z, rotationY or ry, true)
                vehicle:addToPhysics()
            end

            -- Attach implements to the root vehicle
            for i = 1, #attachedVehicles do
                local attachedVehicle = attachedVehicles[i]

                attachedVehicle.vehicle:attachImplement(attachedVehicle.object, attachedVehicle.inputAttacherJointDescIndex, attachedVehicle.jointDescIndex, true, nil, nil, false)
            end

            if isField then
                return EasyDevUtils.formatText("easyDevControls_teleportVehiclesFieldInfo", tostring(#vehicles), tostring(fieldId))
            end

            return EasyDevUtils.formatText("easyDevControls_teleportVehiclesInfo", tostring(#vehicles), tostring(mapPosX), tostring(mapPosZ))
        end
    else
        return self:clientSendEvent(EasyDevControlsTeleportEvent.new(object, positionX, positionZ, rotationY))
    end
end

-- Extra Time Scales
function EasyDevControls:setCustomTimeScaleState(active)
    edc_timeScaleCustomSettingsActive = Utils.getNoNil(active, false)

    if self.isServer then
        g_server:broadcastEvent(EasyDevControlsTimeScaleEvent.new(edc_timeScaleCustomSettingsActive))

        if g_currentMission ~= nil and (g_currentMission.environment ~= nil and g_currentMission.missionInfo ~= nil) then
            local timeScaleIndex = Utils.getTimeScaleIndex(g_currentMission.missionInfo.timeScale or 5)
            local timeScale = Utils.getTimeScaleFromIndex(timeScaleIndex or 2)

            if timeScale ~= nil then
                g_currentMission:setTimeScale(timeScale)
            end
        end
    end

    if self.isEnabled then
        self:onSetCustomTimeScaleState()
    end
end

function EasyDevControls:onSetCustomTimeScaleState()
    if g_currentMission.inGameMenu ~= nil and g_currentMission.inGameMenu.pageSettingsGame ~= nil then
        local pageSettingsGame = g_currentMission.inGameMenu.pageSettingsGame

        if pageSettingsGame.assignTimeScaleTexts ~= nil then
            pageSettingsGame:assignTimeScaleTexts()
        end
    end

    g_messageCenter:publish(EasyDevUtils.MESSAGE_TYPE_SETTINGS_CHANGED, EasyDevUtils.SETTING_TIMESCALE, edc_timeScaleCustomSettingsActive)
end

function EasyDevControls:getCustomTimeScaleState()
    return edc_timeScaleCustomSettingsActive
end

function EasyDevControls:getCustomTimeScaleParams()
    local defaultTimeScaleSettings = {}
    local customTimeScales = {}

    for i, timeScale in pairs (Platform.gameplay.timeScaleSettings) do
        defaultTimeScaleSettings[timeScale] = i
    end

    for i, timeScale in pairs (edc_timeScaleCustomSettings) do
        if defaultTimeScaleSettings[timeScale] == nil then
            table.insert(customTimeScales, timeScale)
        end
    end

    table.sort(customTimeScales)

    local str = ""
    local numCustomTimeScales = #customTimeScales

    for i = 1, numCustomTimeScales do
        str = str .. tostring(customTimeScales[i]) .. "x"

        if i < numCustomTimeScales then
            str = str .. ", "
        end
    end

    return str
end

-- Super Strength
function EasyDevControls:setSuperStrengthState(active)
    active = Utils.getNoNil(active, false)

    if self.isServer then
        local userId = g_currentMission.player.userId

        g_server:broadcastEvent(EasyDevControlsSuperStrengthEvent.new(active, userId))

        return self:setSuperStrengthPlayerValues(active, userId)
    else
        return self:clientSendEvent(EasyDevControlsSuperStrengthEvent.new(active))
    end
end

function EasyDevControls:setSuperStrengthPlayerValues(superStrengthEnabled, userId)
    local currentPlayer = g_currentMission.player
    local infoText = ""

    currentPlayer.superStrengthEnabled = superStrengthEnabled

    if superStrengthEnabled then
        currentPlayer.superStrengthPickupMassBackup = 0.2 -- compatibility
        currentPlayer.superStrengthPickupDistanceBackup = 3 -- compatibility

        Player.MAX_PICKABLE_OBJECT_MASS = 50
        Player.MAX_PICKABLE_OBJECT_DISTANCE = 6

        infoText = "easyDevControls_superStrengthOnInfo"
    else
        Player.MAX_PICKABLE_OBJECT_MASS = 0.2
        Player.MAX_PICKABLE_OBJECT_DISTANCE = 3

        currentPlayer.superStrengthPickupMassBackup = nil
        currentPlayer.superStrengthPickupDistanceBackup = nil

        infoText = "easyDevControls_superStrengthOffInfo"
    end

    if self.isMultiplayer then
        local user = g_currentMission.userManager:getUserByUserId(userId)
        local nickname = user ~= nil and user:getNickname() or ""

        for _, player in pairs(g_currentMission.players) do
            player.superStrengthEnabled = superStrengthEnabled
        end

        if nickname ~= "" then
            local message = ""

            if superStrengthEnabled then
                message = EasyDevUtils.formatText("easyDevControls_superStrengthOnMessage", nickname)
                g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_OK, message)
            else
                message = EasyDevUtils.formatText("easyDevControls_superStrengthOffMessage", nickname)
                g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_INFO, message)
            end

            if g_dedicatedServer ~= nil then
                return message
            end
        end
    end

    return EasyDevUtils.getText(infoText)
end

-- Player Jump Height
function EasyDevControls:setPlayerJumpHeight(jumpHeight)
    if g_currentMission ~= nil and g_currentMission.player ~= nil then
        self.jumpHeight = EasyDevUtils.getNoNilClamp(math.floor(jumpHeight or 1), 1, 10, 1)

        g_currentMission.player.motionInformation.jumpHeight = self.jumpHeight

        return self.jumpHeight
    end
end

-- Running Speed
function EasyDevControls:setRunningSpeedMultiplier(multiplier)
    edc_maxRunningSpeedMultiplier = math.max(multiplier or 2, 2)
    edc_maxRunningSpeed = 9 * edc_maxRunningSpeedMultiplier

    return edc_maxRunningSpeed
end

function EasyDevControls:setRunningSpeedActive(active)
    edc_maxRunningSpeedActive = Utils.getNoNil(active, false)

    return edc_maxRunningSpeedActive
end

function EasyDevControls:setRunningSpeedKeyActive(active)
    edc_maxRunningSpeedInputActive = Utils.getNoNil(active, false)

    -- Add / Remove Input Binding if required
    if self.eventIdTogglePlayerRunSpeed ~= nil then
        g_inputBinding:setActionEventActive(self.eventIdTogglePlayerRunSpeed, edc_maxRunningSpeedInputActive)
    end

    return edc_maxRunningSpeedInputActive
end

function EasyDevControls:getRunningSpeedUiInfo()
    return {
        edc_maxRunningSpeedMultiplier - 1,
        edc_maxRunningSpeedActive,
        edc_maxRunningSpeedInputActive
    }
end

-- Third Person
function EasyDevControls:updateThirdPersonCameraModelTarget(player)
    self.thirdPersonActive = false

    -- Fix the rotation data, this is a base game option but not finished. Only included for photo taking reasons so not perfect
    if player ~= nil then
        player.model:setVisibility(player.isControlled)

        link(player.thirdPersonLookfromNode, player.cameraNode)
        player.rotX, player.rotY = 0, math.pi

        setRotation(player.cameraNode, player.rotX, -player.rotY, 0)
        setTranslation(player.cameraNode, 0, 0, 0)

        setRotation(player.thirdPersonLookatNode, -player.rotX, player.rotY, 0)

        player.model:linkTorchToCamera(player.cameraNode)
        player.model:linkRightHandToCamera(player.cameraNode)
        player.model:linkKinematicHelperToCamera(player.cameraNode)

        player:setRotation(player.rotX, player.rotY)
        player.model:setSkeletonRotation(player.rotY)
        player:updateCameraTranslation(0)

        self.thirdPersonActive = true
    end
end

-- Vehicle Condition
function EasyDevControls:setVehicleCondition(vehicle, isEntered, typeId, setToAmount, amount)
    if not self:getIsValidVehicle(vehicle) then
        return EasyDevUtils.getText("easyDevControls_noValidVehicleWarning")
    end

    setToAmount = Utils.getNoNil(setToAmount, false)
    amount = amount or 0

    if setToAmount then
        amount = math.abs(amount)
    end

    if self.isServer then
        local addDirt, addWear, addDamage = false, false, false

        local function setConditionValues(v)
            if not self:getIsValidVehicle(v) then
                return
            end

            local washableSpec = v.spec_washable
            local wearableSpec = v.spec_wearable

            if addDirt and washableSpec ~= nil then
                for i = 1, #washableSpec.washableNodes do
                    local nodeData = washableSpec.washableNodes[i]

                    if setToAmount then
                        v:setNodeDirtAmount(nodeData, amount, force)
                    else
                        v:setNodeDirtAmount(nodeData, nodeData.dirtAmount + amount, force)
                    end
                end
            end

            if wearableSpec ~= nil then
                if addWear then
                    if wearableSpec.wearableNodes ~= nil then
                        for _, nodeData in ipairs(wearableSpec.wearableNodes) do
                            if setToAmount then
                                v:setNodeWearAmount(nodeData, amount, true)
                            else
                                v:setNodeWearAmount(nodeData, v:getNodeWearAmount(nodeData) + amount, true)
                            end
                        end
                    end
                end

                if addDamage then
                    if setToAmount then
                        v:setDamageAmount(amount, true)
                    else
                        v:setDamageAmount(wearableSpec.damage + amount, true)
                    end
                end
            end
        end

        if typeId == EasyDevControlsVehicleConditionEvent.TYPE_DIRT then
            addDirt = true
        elseif typeId == EasyDevControlsVehicleConditionEvent.TYPE_WEAR then
            addWear = true
        elseif typeId == EasyDevControlsVehicleConditionEvent.TYPE_DAMAGE then
            addDamage = true
        else
            addDirt, addWear, addDamage = true, true, true
        end

        setConditionValues(vehicle)

        if isEntered and vehicle.getAttachedImplements ~= nil then
            for _, implement in ipairs (vehicle:getAttachedImplements()) do
                setConditionValues(implement.object)
            end

            return EasyDevUtils.formatText("easyDevControls_vehicleAndImplementsConditionInfo", vehicle:getFullName())
        end

        return EasyDevUtils.formatText("easyDevControls_vehicleConditionInfo", vehicle:getFullName())
    else
        return self:clientSendEvent(EasyDevControlsVehicleConditionEvent.new(vehicle, isEntered, typeId, setToAmount, amount))
    end
end

-- Vehicle Fuel
function EasyDevControls:setVehicleFuel(vehicle, amount)
    if not self:getIsValidVehicle(vehicle, "getConsumerFillUnitIndex") then
        return EasyDevUtils.getText("easyDevControls_noValidVehicleWarning")
    end

    amount = amount or 1e+7

    if self.isServer then
        EasyDevControlsVehiclesFrame.createFuelTypeIndexs()

        for _, fillTypeIndex in pairs (EasyDevControlsVehiclesFrame.FUEL_TYPE_INDEXS) do
            local fillUnitIndex = vehicle:getConsumerFillUnitIndex(fillTypeIndex)

            if fillUnitIndex ~= nil then
                local newFillLevel = amount - vehicle:getFillUnitFillLevel(fillUnitIndex)
                local fillType = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)

                vehicle:addFillUnitFillLevel(vehicle:getOwnerFarmId(), fillUnitIndex, newFillLevel, vehicle:getFillUnitFirstSupportedFillType(fillUnitIndex), ToolType.UNDEFINED, nil)
                newFillLevel = vehicle:getFillUnitFillLevel(fillUnitIndex) or 0

                return EasyDevUtils.formatText("easyDevControls_vehicleFuelInfo", fillType.title, vehicle:getFullName(), newFillLevel, g_i18n:getVolumeUnit(true))
            end
        end

        return EasyDevUtils.getText("easyDevControls_noValidVehicleWarning")
    else
        return self:clientSendEvent(EasyDevControlsVehicleOperatingValueEvent.new(vehicle, EasyDevControlsVehicleOperatingValueEvent.FUEL, amount))
    end
end

-- Vehicle Motor Temp
function EasyDevControls:setVehicleMotorTemperature(vehicle, temperature)
    if not self:getIsValidVehicle(vehicle, "spec_motorized") then
        return EasyDevUtils.getText("easyDevControls_noValidVehicleWarning")
    end

    if self.isServer then
        local spec = vehicle.spec_motorized

        spec.motorTemperature.value = EasyDevUtils.getNoNilClamp(temperature, spec.motorTemperature.valueMin, spec.motorTemperature.valueMax, 0)

        return EasyDevUtils.formatText("easyDevControls_vehicleMotorTempInfo", vehicle:getFullName(), spec.motorTemperature.value)
    else
        return self:clientSendEvent(EasyDevControlsVehicleOperatingValueEvent.new(vehicle, EasyDevControlsVehicleOperatingValueEvent.MOTOR_TEMP, temperature))
    end
end

-- Vehicle Operating Time
function EasyDevControls:setVehicleOperatingTime(vehicle, operatingTime)
    if not self:getIsValidVehicle(vehicle, "setOperatingTime") then
        return EasyDevUtils.getText("easyDevControls_noValidVehicleWarning")
    end

    operatingTime = math.abs(operatingTime or 0)

    if self.isServer then
        vehicle:setOperatingTime(operatingTime * 1000 * 60 * 60)

        return EasyDevUtils.formatText("easyDevControls_vehicleOperatingTimeInfo", vehicle:getFullName(), Enterable.getFormattedOperatingTime(vehicle))
    else
        return self:clientSendEvent(EasyDevControlsVehicleOperatingValueEvent.new(vehicle, EasyDevControlsVehicleOperatingValueEvent.OPERATING_TIME, operatingTime))
    end
end

-- Power Consumer
function EasyDevControls:setPowerConsumer(powerConsumerVehicle, neededMinPtoPower, neededMaxPtoPower, forceFactor, maxForce, forceDir, ptoRpm, syncVehicles)
    if powerConsumerVehicle ~= nil and powerConsumerVehicle.spec_powerConsumer ~= nil then
        local spec = powerConsumerVehicle.spec_powerConsumer

        if spec.edcOriginalValues == nil then
            spec.edcOriginalValues = {
                neededMinPtoPower = spec.neededMinPtoPower,
                neededMaxPtoPower = spec.neededMaxPtoPower,
                forceFactor = spec.forceFactor,
                maxForce = spec.maxForce,
                forceDir = spec.forceDir,
                ptoRpm = spec.ptoRpm
                -- syncVehicles = 2
            }
        end

        spec.neededMinPtoPower = Utils.getNoNil(neededMinPtoPower, spec.neededMinPtoPower)
        spec.neededMaxPtoPower = Utils.getNoNil(neededMaxPtoPower, spec.neededMaxPtoPower)
        spec.forceFactor = Utils.getNoNil(forceFactor, spec.forceFactor)
        spec.maxForce = Utils.getNoNil(maxForce, spec.maxForce)
        spec.forceDir = Utils.getNoNil(forceDir, spec.forceDir)
        spec.ptoRpm = Utils.getNoNil(ptoRpm, spec.ptoRpm)

        if spec.neededMaxPtoPower < spec.neededMinPtoPower then
            spec.neededMaxPtoPower = spec.neededMinPtoPower
        end

        if spec.forceDir < -1 or spec.forceDir == 0  or spec.forceDir > 1 then
            spec.forceDir = 1
        end

        -- Update all vehicles with matching configFileName
        syncVehicles = Utils.getNoNil(syncVehicles, false)

        if syncVehicles then
            for _, vehicle in pairs(g_currentMission.vehicles) do
                if vehicle.configFileName == powerConsumerVehicle.configFileName then
                    local powerConsumerSpec = vehicle.spec_powerConsumer

                    if powerConsumerSpec.edcOriginalValues == nil then
                        powerConsumerSpec.edcOriginalValues = {
                            neededMinPtoPower = spec.neededMinPtoPower,
                            neededMaxPtoPower = spec.neededMaxPtoPower,
                            forceFactor = spec.forceFactor,
                            maxForce = spec.maxForce,
                            forceDir = spec.forceDir,
                            ptoRpm = spec.ptoRpm
                            -- syncVehicles = 2
                        }
                    end

                    powerConsumerSpec.neededMinPtoPower = spec.neededMinPtoPower
                    powerConsumerSpec.neededMaxPtoPower = spec.neededMaxPtoPower
                    powerConsumerSpec.forceFactor = spec.forceFactor
                    powerConsumerSpec.maxForce = spec.maxForce
                    powerConsumerSpec.forceDir = spec.forceDir
                    powerConsumerSpec.ptoRpm = spec.ptoRpm
                end
            end
        end

        return EasyDevUtils.formatText("easyDevControls_setPowerConsumerInfo", powerConsumerVehicle:getFullName(), tostring(syncVehicles))
    else
        return EasyDevUtils.getText("easyDevControls_noValidVehicleWarning")
    end
end

function EasyDevControls:getSelectedImplementIsPowerConsumer(vehicle)
    if self:getIsValidVehicle(vehicle, "getSelectedImplement") then
        local selectedImplement = vehicle:getSelectedImplement()

        if selectedImplement ~= nil and selectedImplement.object.spec_powerConsumer ~= nil then
            return true, selectedImplement.object
        end
    end

    return false
end

-- Set Fill Level
function EasyDevControls:setFillUnitFillLevel(vehicle, fillUnitIndex, fillTypeIndex, amount, ignoreRemoveIfEmpty)
    if not self:getIsValidVehicle(vehicle, "spec_fillUnit") then
        return EasyDevUtils.getText("easyDevControls_noValidVehicleWarning")
    end

    if fillUnitIndex == nil or fillTypeIndex == nil or amount == nil then
        return self.requestFailedText
    end

    local fillType = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)

    if fillType ~= nil then
        local spec = vehicle.spec_fillUnit
        local fillUnit = spec.fillUnits[fillUnitIndex]

        if fillUnit ~= nil and fillUnit.supportedFillTypes[fillTypeIndex] and fillUnit.capacity ~= 0 then
            ignoreRemoveIfEmpty = Utils.getNoNil(ignoreRemoveIfEmpty, false)

            if self.isServer then
                local farmId = vehicle:getOwnerFarmId() or 1
                local balerSpec = vehicle.spec_baler
                local oldRemoveVehicleIfEmpty = spec.removeVehicleIfEmpty

                -- Causes to many issues so not possible
                if balerSpec ~= nil and balerSpec.hasUnloadingAnimation then
                    return self.requestFailedText
                end

                if fillUnit.fillLevel > 0 then
                    spec.removeVehicleIfEmpty = false
                    vehicle:addFillUnitFillLevel(farmId, fillUnitIndex, -math.huge, fillUnit.fillType, ToolType.UNDEFINED)
                    spec.removeVehicleIfEmpty = oldRemoveVehicleIfEmpty
                end

                if ignoreRemoveIfEmpty then
                    spec.removeVehicleIfEmpty = false
                end

                amount = amount > 0 and amount or -math.huge

                if amount > 0 and vehicle.finishedFirstUpdate then
                    if fillUnit.updateMass and not fillUnit.ignoreFillLimit and g_currentMission.missionInfo.trailerFillLimit then
                        vehicle:updateMass()
                    end
                end

                local deltaLevel = vehicle:addFillUnitFillLevel(farmId, fillUnitIndex, math.min(amount, fillUnit.capacity), fillTypeIndex, ToolType.UNDEFINED)
                spec.removeVehicleIfEmpty = oldRemoveVehicleIfEmpty

                -- Move the bale down the chute so it does not spew them when unloading, not recommended really. This updates fast so Ready, aim.... FIRE!!!
                if balerSpec ~= nil and not balerSpec.hasUnloadingAnimation then
                    vehicle:moveBales(vehicle:getTimeFromLevel(deltaLevel))
                end

                if fillUnit.fillLevel > 0 then
                    local fillLevelString = string.format("%s %s", g_i18n:formatNumber(g_i18n:getVolume(fillUnit.fillLevel), 0), g_i18n:getVolumeUnit(true))

                    return EasyDevUtils.formatText("easyDevControls_setFillUnitFillLevelInfo", tostring(fillUnitIndex), vehicle:getFullName(), fillType.title, fillLevelString)
                end

                return EasyDevUtils.formatText("easyDevControls_setFillUnitEmptyInfo", tostring(fillUnitIndex), vehicle:getFullName())
            else
                return self:clientSendEvent(EasyDevControlsSetFillUnitFillLevel.new(vehicle, fillUnitIndex, fillTypeIndex, amount, ignoreRemoveIfEmpty))
            end
        else
            return self.requestFailedText
        end
    else
        return EasyDevUtils.getText("easyDevControls_invalidFillTypeWarning")
    end
end

-- Add Bale
function EasyDevControls:spawnBale(baleIndex, fillTypeIndex, wrappingState, farmId, x, y, z, ry, fillLevel, wrapDiffuse, wrapDiffuseColor)
    if baleIndex == nil or x == nil or y == nil or z == nil or ry == nil then
        return self.requestFailedText
    end

    if g_baleManager.bales[baleIndex] == nil or g_fillTypeManager:getFillTypeByIndex(fillTypeIndex) == nil then
        return EasyDevUtils.getText("easyDevControls_invalidFillTypeWarning")
    end

    wrappingState = EasyDevUtils.getNoNilClamp(wrappingState, 0, 1, 1)
    farmId = farmId or 1

    if self.isServer then
        local xmlFilename = g_baleManager.bales[baleIndex].xmlFilename
        local bale = Bale.new(self.isServer, self.isClient)

        if bale:loadFromConfigXML(xmlFilename, x, y, z, 0, ry, 0) then
            local setFillLevel = fillLevel ~= nil

            bale:setFillType(fillTypeIndex, not setFillLevel)

            if setFillLevel then
                bale:setFillLevel(fillLevel)
            end

            bale:setWrappingState(wrappingState)

            if wrappingState > 0 then
                if wrapDiffuse == nil then
                    local r, g, b = 0.01, 0.01, 0.01 -- Black

                    if fillTypeIndex == FillType.SILAGE then
                        r, g, b, a = 1, 0.1413, 0 -- FI_O
                    elseif fillTypeIndex == FillType.GRASS_WINDROW then
                        r, g, b, a = 0, 0.2051, 0.0685 -- FI_G
                    end

                    bale:setColor(r, g, b, 1)
                else
                    bale:setWrapTextures(wrapDiffuse)

                    if wrapDiffuseColor ~= nil then
                        bale:setColor(unpack(wrapDiffuseColor))
                    end
                end
            end

            bale:setOwnerFarmId(farmId, true)
            bale:register()

            return EasyDevUtils.formatText("easyDevControls_spawnObjectsInfo", EasyDevUtils.getText("easyDevControls_typeBale"))
        else
            if bale.delete ~= nil then
                bale:delete()
            end
        end

        return self.requestFailedText
    else
        local params = {
            baleIndex = baleIndex,
            fillTypeIndex = fillTypeIndex,
            wrappingState = wrappingState,
            x = x,
            y = y,
            z = z,
            ry = ry
        }

        return self:clientSendEvent(EasyDevControlsSpawnObjectEvent.new(EasyDevControlsSpawnObjectEvent.TYPE_BALE, params))
    end
end

-- Add Pallet
function EasyDevControls:spawnPallet(fillTypeIndex, xmlFilename, farmId, x, y, z)
    local fillType = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)

    if fillType == nil then
        return EasyDevUtils.getText("easyDevControls_invalidFillTypeWarning")
    end

    if x == nil or y == nil or z == nil then
        return self.requestFailedText
    end

    xmlFilename = xmlFilename or fillType.palletFilename

    if xmlFilename == nil then
        return self.requestFailedText
    end

    farmId = farmId or 1

    if self.isServer then
        local locationData = {
            x = x,
            y = y,
            z = z
        }

        local asyncCallbackFunction = function(_, vehicle, vehicleLoadState, arguments)
            if vehicleLoadState == VehicleLoadingUtil.VEHICLE_LOAD_OK then
                vehicle:addFillUnitFillLevel(farmId, 1, math.huge, fillTypeIndex, ToolType.UNDEFINED, nil)
            end
        end

        VehicleLoadingUtil.loadVehicle(xmlFilename, locationData, true, 0, Vehicle.PROPERTY_STATE_OWNED, farmId, {}, nil, asyncCallbackFunction, nil, nil, true, false)

        return EasyDevUtils.formatText("easyDevControls_spawnObjectsInfo", EasyDevUtils.getText("easyDevControls_typePallet"))
    else
        local params = {
            xmlFilename = xmlFilename,
            fillTypeIndex = fillTypeIndex,
            x = x,
            y = y,
            z = z
        }

        return self:clientSendEvent(EasyDevControlsSpawnObjectEvent.new(EasyDevControlsSpawnObjectEvent.TYPE_PALLET, params))
    end
end

-- Add Log
function EasyDevControls:spawnLog(treeType, length, growthState, x, y, z, dirX, dirY, dirZ)
    if treeType == nil or x == nil or y == nil or z == nil then
        return self.requestFailedText
    end

    local treeTypeDesc = g_treePlantManager:getTreeTypeDescFromIndex(treeType)

    if treeTypeDesc == nil or #treeTypeDesc.treeFilenames <= 1 then
        return EasyDevUtils.getText("easyDevControls_invalidTreeTypeWarning")
    end

    length = EasyDevUtils.getNoNilClamp(length, 1, 8, 1)
    growthState = EasyDevUtils.getNoNilClamp(growthState, 0, 1, 1)

    if self.isServer then
        local title = g_i18n:getText(treeTypeDesc.nameI18N, g_currentMission.baseDirectory)
        local typeText = string.format("%s (%s) %s", EasyDevUtils.formatLength(length), title, EasyDevUtils.getText("easyDevControls_typeLog"))

        local growthStateI = math.floor(growthState * (#treeTypeDesc.treeFilenames - 1)) + 1
        local treeId, splitShapeFileId = g_treePlantManager:loadTreeNode(treeTypeDesc, x, y, z, 0, 0, 0, growthStateI)

        if getFileIdHasSplitShapes(splitShapeFileId) then
            table.insert(g_treePlantManager.treesData.splitTrees, {
                x = x,
                y = y,
                z = z,
                rx = 0,
                ry = 0,
                rz = 0,
                node = treeId,
                treeType = treeType,
                growthState = growthState,
                splitShapeFileId = splitShapeFileId,
                hasSplitShapes = true
            })

            g_server:broadcastEvent(TreePlantEvent.new(treeType, x, y, z, 0, 0, 0, growthState, splitShapeFileId, false))

            self.addingTreeToCut = true

            if self.treesToCut == nil then
                self.treesToCut = {}
            end

            table.insert(self.treesToCut, {
                x = x,
                y = y,
                z = z,
                dirX = dirX,
                dirY = dirY,
                dirZ = dirZ,
                offset = 0.5,
                framesLeft = 2,
                length = length,
                dataAdded = false,
                shape = treeId + 2
            })

            self.addingTreeToCut = false
        else
            delete(treeId)

            return EasyDevUtils.formatText("easyDevControls_failedToSpawnObjectWarning", typeText)
        end

        return EasyDevUtils.formatText("easyDevControls_spawnObjectsInfo", typeText)
    else
        local params = {
            treeType = treeType,
            length = length,
            growthState = growthState,
            rx = dirX,
            ry = dirY,
            rz = dirZ,
            x = x,
            y = y,
            z = z
        }

        return self:clientSendEvent(EasyDevControlsSpawnObjectEvent.new(EasyDevControlsSpawnObjectEvent.TYPE_LOG, params))
    end
end

-- Show Locations
function EasyDevControls:showObjectLocations(typeId, active)
    if not EasyDevHotspotsManager.VALID_TYPE_IDS[typeId] then
        return self.requestFailedText
    end

    local enabled, typeText = g_easyDevHotspotsManager:setActive(typeId, active)

    if enabled then
        return EasyDevUtils.formatText("easyDevControls_hotspotsEnabledInfo", typeText)
    end

    return EasyDevUtils.formatText("easyDevControls_hotspotsDisabledInfo", typeText)
end

-- Tip To Trigger (Needs to be reworked so animals and silos work)
function EasyDevControls:setTargetFillLevel(target, fillTypeIndex, deltaFillLevel, farmId)
    if self.isServer then
        local appliedFillLevel = 0

        if target.setFillLevel ~= nil then
            appliedFillLevel = target:setFillLevel(deltaFillLevel, fillTypeIndex, nil)
        elseif target.targetStorages ~= nil then
            local movedFillLevel = 0

            if deltaFillLevel == 0 or deltaFillLevel < 1e+6 then
                for _, storage in pairs(target.targetStorages) do
                    if target:hasFarmAccessToStorage(farmId, storage) then
                        storage:setFillLevel(0, fillTypeIndex, nil)
                    end
                end
            end

            if deltaFillLevel > 0 then
                for _, storage in pairs(target.targetStorages) do
                    if target:hasFarmAccessToStorage(farmId, storage) then
                        storage:setFillLevel(deltaFillLevel, fillTypeIndex, nil)

                        appliedFillLevel = appliedFillLevel + (storage:getFillLevel(fillTypeIndex) or 0)
                    end

                    if appliedFillLevel >= deltaFillLevel - 0.001 then
                        if target.startFx ~= nil then
                            target:startFx(fillTypeIndex)
                        end

                        break
                    end
                end
            end
        end

        return appliedFillLevel
    else

    end
end

-- Tip Anywhere
function EasyDevControls:tipHeightType(amount, fillTypeIndex, x, y, z, dirX, dirZ, length, vehicle, player)
    if amount == nil or fillTypeIndex == nil or not EasyDevUtils.getHasValidLocationValues(x, y, z) then
        return self.requestFailedText
    end

    length = length or 2

    dirX = dirX or 1
    dirZ = dirZ or 0

    if self.isServer then
        if player ~= nil and EasyDevUtils.getCanTipToGround(amount, fillTypeIndex, x, y, z, dirX, dirZ, length, vehicle, player.farmId) then
            local tipped, lineOffset = DensityMapHeightUtil.tipToGroundAroundLine(vehicle, amount, fillTypeIndex, x, y, z, x + length * dirX, y, z + length * dirZ, 10, 40, 0, false, nil, nil, true)

            if tipped > 0 then
                local height, heapHeight = DensityMapHeightUtil.getHeightAtWorldPos(x, y, z)
                player:moveTo(x, heapHeight + 0.05, z, false, false) -- Try and stop player getting stuck in the heap

                return EasyDevUtils.formatText("easyDevControls_tipToGroundInfo", EasyDevUtils.getFillTypeTitle(fillTypeIndex), g_i18n:formatFluid(tipped), EasyDevUtils.formatLength(length))
            end

            return self.requestFailedText
        end

        return g_i18n:getText("warning_youDontHaveAccessToThisLand")
    else
        self:clientSendEvent(EasyDevControlsTipHeightTypeEvent.new(amount, fillTypeIndex, x, y, z, dirX, dirZ, length, vehicle))
    end
end

-- Clear Tip Area
function EasyDevControls:clearHeightType(typeId, fillTypeIndex, x, z, radius, farmId)
    if typeId == EasyDevControlsClearHeightTypeEvent.TYPE_AREA then
        if not EasyDevUtils.getHasValidLocationValues(x, 0, z) then
            return self.requestFailedText
        end

        radius = EasyDevUtils.getNoNilClamp(radius, 1, EasyDevControlsObjectsFrame.CLEAR_RADIUS[#EasyDevControlsObjectsFrame.CLEAR_RADIUS], 1)
    elseif typeId == EasyDevControlsClearHeightTypeEvent.TYPE_FIELD and x == nil then
        return self.requestFailedText
    end

    if fillTypeIndex == FillType.UNKNOWN then
        fillTypeIndex = nil
    end

    if self.isServer then
        if typeId == EasyDevControlsClearHeightTypeEvent.TYPE_AREA then
            if EasyDevUtils.getIsFarmlandAccessible(x, z, farmId, radius) then
                local startX, startZ, widthX, widthZ, heightX, heightZ = EasyDevUtils.getArea(x, z, radius)

                EasyDevUtils.clearArea(startX, startZ, widthX, widthZ, heightX, heightZ, fillTypeIndex)

                return EasyDevUtils.formatText("easyDevControls_clearTipAreaRadiusInfo", EasyDevUtils.getFillTypeTitle(fillTypeIndex), EasyDevUtils.formatLength(radius))
            end

            return g_i18n:getText("warning_youDontHaveAccessToThisLand")
        elseif typeId == EasyDevControlsClearHeightTypeEvent.TYPE_FIELD then
            if EasyDevUtils.clearField(g_fieldManager:getFieldByIndex(x), fillTypeIndex, farmId, 1) then
                local fieldName = string.format("%s %d ", EasyDevUtils.getText("easyDevControls_typeField"), x)

                return EasyDevUtils.formatText("easyDevControls_clearTipAreaFieldInfo", fieldName, EasyDevUtils.getFillTypeTitle(fillTypeIndex))
            end

            return g_i18n:getText("warning_youDontOwnThisField")
        elseif typeId == EasyDevControlsClearHeightTypeEvent.TYPE_FIELDS then
            local numCleared = 0

            for _, field in ipairs (g_fieldManager:getFields()) do
                if EasyDevUtils.clearField(field, fillTypeIndex, farmId, 1) then
                    numCleared = numCleared + 1
                end
            end

            return EasyDevUtils.formatText("easyDevControls_clearTipAreaFieldInfo", EasyDevUtils.getTypeText("FIELD", numCleared, true), EasyDevUtils.getFillTypeTitle(fillTypeIndex))
        elseif typeId == EasyDevControlsClearHeightTypeEvent.TYPE_MAP then
            local sizeHalf = g_currentMission.terrainSize * 0.5

            EasyDevUtils.clearArea(-sizeHalf, sizeHalf, sizeHalf, sizeHalf, -sizeHalf, -sizeHalf, fillTypeIndex)

            return EasyDevUtils.formatText("easyDevControls_clearTipAreaMapInfo", EasyDevUtils.getFillTypeTitle(fillTypeIndex))
        end
    else
        self:clientSendEvent(EasyDevControlsClearHeightTypeEvent.new(typeId, fillTypeIndex, x, z, radius))
    end
end

-- Remove All Objects
function EasyDevControls:removeAllObjects(typeId)
    local removeVehicles, removePallets, removeBales, removeLogs, removeStumps, removePlaceables, removeMapPlaceables = EasyDevControlsRemoveAllObjectsEvent.typeToRemove(typeId)

    if self.isServer then
        local numRemoved = 0
        local typeText = ""

        if removeVehicles or removePallets then
            local mission = g_currentMission

            local function getVehicleIsPallet(vehicle)
                if vehicle.typeName == "pallet" or vehicle.typeName == "treeSaplingPallet" or vehicle.typeName == "bigBag" then
                    return true
                end

                if vehicle.spec_wheels == nil and vehicle.spec_enterable == nil then
                    -- Allow custom pallets with different type names. Must include a valid spec of either Pallet, BigBag or TreeSaplingPallet
                    -- Specialisations 'Wheels' and 'Enterable' are not invalid and ignored as these should not be part of a pallet
                    for _, spec in pairs(vehicle.specializations) do
                        if spec == Pallet or spec == BigBag or spec == TreeSaplingPallet then
                            return true
                        end
                    end
                end

                return false
            end

            for i = #mission.vehicles, 1, -1 do
                local vehicle = mission.vehicles[i]

                if vehicle.isa ~= nil and vehicle:isa(Vehicle) and vehicle.trainSystem == nil then
                    if getVehicleIsPallet(vehicle) then
                        if removePallets then
                            mission:removeVehicle(vehicle)
                            numRemoved = numRemoved + 1
                        end
                    elseif removeVehicles then
                        mission:removeVehicle(vehicle)
                        numRemoved = numRemoved + 1
                    end
                end
            end

            typeText = EasyDevUtils.getTypeText(removePallets and "PALLET" or "VEHICLE", numRemoved)
        elseif removeBales then
            local itemsToSave = g_currentMission.itemSystem.itemsToSave
            local balesToRemove = {}

            for _, item in pairs(itemsToSave) do
                local object = item.item

                if object.isa ~= nil and object:isa(Bale) then
                    balesToRemove[#balesToRemove + 1] = object
                end
            end

            for i = #balesToRemove, 1, -1 do
                balesToRemove[i]:delete()
                numRemoved = numRemoved + 1
            end

            typeText = EasyDevUtils.getTypeText("BALE", numRemoved)
        elseif removeLogs or removeStumps then
            local _, numSplit = getNumOfSplitShapes()

            if numSplit > 0 then
                local splitSplitShapes = {}

                self:findAllSplitSplitShapes(getRootNode(), removeLogs, removeStumps, splitSplitShapes)

                for _, splitShape in pairs (splitSplitShapes) do
                    delete(splitShape)
                    numRemoved = numRemoved + 1
                end

                if numRemoved > 0 then
                    g_treePlantManager:cleanupDeletedTrees()
                end
            end

            typeText = EasyDevUtils.getTypeText(removeLogs and "LOG" or "STUMP", numRemoved)
        elseif removePlaceables or removeMapPlaceables then
            local placeableSystem = g_currentMission.placeableSystem

            for i = #placeableSystem.placeables, 1, -1 do
                local placeable = placeableSystem.placeables[i]
                local canRemove = false

                if placeable:isMapBound() then
                    canRemove = removeMapPlaceables
                else
                    canRemove = removePlaceables
                end

                if canRemove then
                    placeable:delete()
                    numRemoved = numRemoved + 1
                end
            end

            typeText = EasyDevUtils.getTypeText(removePlaceables and "PLACEABLE" or "MAP_PLACEABLE", numRemoved)
        end

        if typeText ~= "" then
            return EasyDevUtils.formatText("easyDevControls_removeAllObjectsInfo", tostring(numRemoved), typeText)
        end
    else
        if removeVehicles or removePallets or removeBales or removeLogs or removeStumps or removePlaceables or removeMapPlaceables then
            return self:clientSendEvent(EasyDevControlsRemoveAllObjectsEvent.new(typeId))
        end
    end

    EasyDevUtils.devInfo("Failed to remove objects using function [removeAllObjects] as valid type was not specified!")
end

function EasyDevControls:findAllSplitSplitShapes(node, findLogs, findStumps, splitSplitShapes)
    for i = 0, getNumOfChildren(node) - 1 do
        local node = getChildAt(node, i)

        if (getName(node) == "splitGeom" and getHasClassId(node, ClassIds.SHAPE)) and (getSplitType(node) ~= 0 and getIsSplitShapeSplit(node)) then
            local rigidBodyType = getRigidBodyType(node)

            if (findLogs and rigidBodyType == RigidBodyType.DYNAMIC) or (findStumps and rigidBodyType == RigidBodyType.STATIC) then
                splitSplitShapes[node] = node
            end
        else
            self:findAllSplitSplitShapes(node, findLogs, findStumps, splitSplitShapes)
        end
    end
end

function EasyDevControls:treeRaycastCallback(hitObjectId, x, y, z, distance)
    if hitObjectId ~= g_currentMission.terrainRootNode and getRigidBodyType(hitObjectId) == RigidBodyType.STATIC then
        if not g_currentMission:getNodeObject(hitObjectId) then
            local splitType = getSplitType(hitObjectId)

            if splitType ~= 0 then
                self.lastHitObject = hitObjectId

                return false
            end
        end
    end

    return true
end

-- Set Production Point Fill Levels
function EasyDevControls:setProductionPointFillLevels(productionPoint, fillLevel, fillTypeIndex, isOutput, suppressText)
    if productionPoint ~= nil or fillLevel ~= nil then
        local fillTypeIds = isOutput and productionPoint.outputFillTypeIds or productionPoint.inputFillTypeIds

        if fillTypeIds ~= nil then
            if fillTypeIndex ~= nil then
                if fillTypeIds[fillTypeIndex] ~= nil then
                    if self.isServer then
                        local modeL10N = isOutput and "easyDevControls_output" or "easyDevControls_input"
                        local fillType = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)

                        productionPoint.storage:setFillLevel(fillLevel, fillTypeIndex)

                        return EasyDevUtils.formatText("easyDevControls_productionPointFillLevelInfo", EasyDevUtils.getText(modeL10N):lower(), fillType.title, productionPoint:getName())
                    else
                        return self:clientSendEvent(EasyDevControlsSetProductionPointFillLevelsEvent.new(productionPoint, fillLevel, fillTypeIndex, isOutput))
                    end
                else
                    return EasyDevUtils.getText("easyDevControls_invalidFillTypeWarning")
                end
            else
                if self.isServer then
                    for supportedFillType in pairs (fillTypeIds) do
                        productionPoint.storage:setFillLevel(fillLevel, supportedFillType)
                    end

                    if suppressText then
                        return true
                    else
                        local modeL10N = isOutput and "easyDevControls_output" or "easyDevControls_input"
                        local typeText = EasyDevUtils.getTypeText("PRODUCTION_POINT", 1)

                        return EasyDevUtils.formatText("easyDevControls_productionPointFillLevelAllInfo", EasyDevUtils.getText(modeL10N):lower(), "1", typeText)
                    end
                else
                    local text = self:clientSendEvent(EasyDevControlsSetProductionPointFillLevelsEvent.new(productionPoint, fillLevel, nil, isOutput))

                    if not suppressText then
                        return text
                    end
                end
            end
        end
    end

    if suppressText then
        return false
    end

    return self.requestFailedText
end

-- Reload Placeables
function EasyDevControls:reloadPlaceables(target, resultFunction)
    local placeableSystem = g_currentMission.placeableSystem
    local placeablesToReload = {}
    local failedToReload = {}
    local numReloaded = 0

    -- No need for this in multiplayer as mods must be zipped
    if (not self.isServer or self.isMultiplayer) or (placeableSystem == nil or placeableSystem.isReloadRunning) then
        return self.requestFailedText
    end

    for _, placeable in ipairs(placeableSystem.placeables) do
        if placeable.spec_trainSystem == nil then
            if target == nil then
                table.insert(placeablesToReload, placeable)
            elseif target == placeable then
                table.insert(placeablesToReload, placeable)

                break
            end
        end
    end

    if #placeablesToReload > 0 then
        g_i3DManager:clearEntireSharedI3DFileCache(false)

        placeableSystem.isReloadRunning = true
        placeableSystem:setSaveIds()

        local callback = function(_, placeable, loadingState, args)
            local oldPlaceable = args.placeable
            local xmlFile = args.xmlFile

            xmlFile:delete()

            table.removeElement(placeablesToReload, oldPlaceable)

            if loadingState == Placeable.LOADING_STATE_ERROR then
                local configFileName = args.filename or "Unknown"

                if placeable ~= nil then
                    configFileName = placeable.configFileName
                    placeable:delete()
                end

                table.insert(failedToReload, configFileName)
            else
                oldPlaceable.isReloading = true  -- flag to skip some actions in onDelete()
                oldPlaceable:delete()

                placeable:register()
                numReloaded = numReloaded + 1
            end

            if #placeablesToReload == 0 then
                placeableSystem.isReloadRunning = false

                if resultFunction ~= nil then
                    resultFunction(numReloaded, failedToReload)
                end

                g_messageCenter:publish(EasyDevUtils.MESSAGE_TYPE_PRODUCTIONS_CHANGED, true)
            end
        end

        for _, placeable in ipairs(placeablesToReload) do
            local xmlFile = XMLFile.create("placeableXMLFile", "", "placeables", Placeable.xmlSchemaSavegame)
            local usedModNames = {}

            placeableSystem:savePlaceableToXML(placeable, xmlFile, 0, 1, usedModNames)

            local key = "placeables.placeable(0)"
            local missionInfo = g_currentMission.missionInfo
            local missionDynamicInfo = g_currentMission.missionDynamicInfo

            local arguments = {
                filename = xmlFile:getValue(key .. "#filename"),
                placeable = placeable,
                xmlFile = xmlFile
            }

            placeableSystem:loadPlaceableFromXML(xmlFile, key, missionInfo, missionDynamicInfo, false, callback, nil, arguments)
        end
    else
        return EasyDevUtils.formatText("easyDevControls_reloadPlaceablesInfo", "0", EasyDevUtils.getText("easyDevControls_typePlaceables"))
    end
end

-- Set Field
function EasyDevControls:setFieldFruit(fieldIndex, fruitIndex, growthState, groundLayer, fertilizerState, plowingState, limeState, stubbleState, weedState, herbicideState, rollerState, stonesState, buyFarmland, farmId)
    if self.isServer then
        local modifierData, extraParamaters = EasyDevUtils.getFieldFruitModifierData(fruitIndex, growthState, groundLayer, fertilizerState, plowingState, limeState, stubbleState, weedState, herbicideState, rollerState, stonesState)

        return self:setField(fieldIndex, modifierData, extraParamaters, farmId, buyFarmland)
    else
        return self:clientSendEvent(EasyDevControlsSetFieldEvent.new(true, fieldIndex, fruitIndex, growthState, false, groundLayer, fertilizerState, plowingState, limeState, stubbleState, weedState, herbicideState, rollerState, stonesState, buyFarmland))
    end
end

function EasyDevControls:setFieldGround(fieldIndex, groundTypeValue, angleValue, removeFoliage, groundLayer, fertilizerState, plowingState, limeState, stubbleState, weedState, herbicideState, rollerState, stonesState, buyFarmland, farmId)
    if self.isServer then
        local modifierData, extraParamaters = EasyDevUtils.getFieldGroundModifierData(groundTypeValue, angleValue, removeFoliage, groundLayer, fertilizerState, plowingState, limeState, stubbleState, weedState, herbicideState, rollerState, stonesState)

        return self:setField(fieldIndex, modifierData, extraParamaters, farmId, buyFarmland)
    else
        return self:clientSendEvent(EasyDevControlsSetFieldEvent.new(false, fieldIndex, groundTypeValue, angleValue, removeFoliage, groundLayer, fertilizerState, plowingState, limeState, stubbleState, weedState, herbicideState, rollerState, stonesState, buyFarmland))
    end
end

function EasyDevControls:setField(fieldIndex, modifierData, extraParamaters, farmId, buyFarmland)
    if modifierData == nil then
        return self.requestFailedText
    end

    if fieldIndex == 0 then
        local numFieldsUpdated = 0

        for _, field in ipairs (g_fieldManager:getFields()) do
            if EasyDevUtils.setField(field, modifierData, extraParamaters, farmId, buyFarmland) then
                numFieldsUpdated = numFieldsUpdated + 1
            end
        end

        if numFieldsUpdated > 0 then
            return EasyDevUtils.formatText("easyDevControls_setAllFieldSuccessInfo", tostring(numFieldsUpdated))
        end
    else
        if EasyDevUtils.setField(g_fieldManager:getFieldByIndex(fieldIndex), modifierData, extraParamaters, farmId, buyFarmland) then
            return EasyDevUtils.formatText("easyDevControls_setFieldSuccessInfo", tostring(fieldIndex))
        end
    end

    return EasyDevUtils.getText("easyDevControls_setFieldFailedInfo")
end

-- Vine System Set State
function EasyDevControls:vineSystemSetState(placeableVine, fruitTypeIndex, growthState, farmId)
    if fruitTypeIndex == nil or growthState == nil then
        return self.requestFailedText
    end

    local fruitType = g_fruitTypeManager:getFillTypeByFruitTypeIndex(fruitTypeIndex)

    if fruitType == nil then
        return self.requestFailedText
    end

    if self.isServer then
        local vineSystem = g_currentMission.vineSystem
        local accessHandler = g_currentMission.accessHandler

        local vinePlaceables = EasyDevUtils.getVinePlaceables()
        local numUpdated = 0

        if placeableVine == nil then
            for placeable, nodes in pairs(vinePlaceables) do
                if placeable:getVineFruitType() == fruitTypeIndex and accessHandler:canFarmAccessOtherId(farmId, placeable:getOwnerFarmId()) then
                    for _, node in ipairs (nodes) do
                        local startX, startZ, widthX, widthZ, heightX, heightZ = placeable:getVineAreaByNode(node)

                        FSDensityMapUtil:setVineAreaValue(fruitTypeIndex, startX, startZ, widthX, widthZ, heightX, heightZ, growthState)
                        vineSystem.dirtyNodes[node] = true
                    end
                end

                if placeable.spec_fence ~= nil and placeable.spec_fence.segments ~= nil then
                    numUpdated = numUpdated + #placeable.spec_fence.segments
                else
                    numUpdated = numUpdated + 1
                end
            end
        else
            local nodes = vinePlaceables[placeableVine]

            if nodes ~= nil and accessHandler:canFarmAccessOtherId(farmId, placeableVine:getOwnerFarmId()) then
                if placeableVine:getVineFruitType() ~= fruitTypeIndex then
                    fruitTypeIndex = placeableVine:getVineFruitType()
                    fruitType = g_fruitTypeManager:getFillTypeByFruitTypeIndex(fruitTypeIndex)
                end

                for _, node in ipairs (nodes) do
                    local startX, startZ, widthX, widthZ, heightX, heightZ = placeableVine:getVineAreaByNode(node)

                    FSDensityMapUtil:setVineAreaValue(fruitTypeIndex, startX, startZ, widthX, widthZ, heightX, heightZ, growthState)
                    vineSystem.dirtyNodes[node] = true

                    numUpdated = 1
                end
            end
        end

        return EasyDevUtils.formatText("easyDevControls_vineSetStateInfo", tostring(numUpdated), fruitType.title, tostring(growthState))
    else
        return self:clientSendEvent(EasyDevControlsVineSystemSetStateEvent.new(placeableVine, fruitTypeIndex, growthState))
    end
end

-- Add / Remove Weeds
function EasyDevControls:addRemoveWeedsDelta(fieldIndex, delta)
    local weedSystem = g_currentMission.weedSystem

    if not weedSystem:getMapHasWeed() or (fieldIndex == nil or fieldIndex > 2 ^ EasyDevControlsAddRemoveDeltaEvent.FIELD_SEND_NUM_BITS - 1) then
        return self.requestFailedText
    end

    if self.isServer then
        weedSystem:consoleCommandAddDelta(fieldIndex, delta)

        if delta < 0 then
            return EasyDevUtils.formatText("easyDevControls_removeWeedOrStoneDelta", g_i18n:getText("setting_weedsEnabled"), tostring(math.abs(delta)))
        end

        return EasyDevUtils.formatText("easyDevControls_addWeedOrStoneDelta", g_i18n:getText("setting_weedsEnabled"), tostring(math.abs(delta)))
    else
        self:clientSendEvent(EasyDevControlsAddRemoveDeltaEvent.new(true, fieldIndex, delta))
    end
end

-- Add / Remove Stones
function EasyDevControls:addRemoveStonesDelta(fieldIndex, delta)
    local stoneSystem = g_currentMission.stoneSystem

    if not stoneSystem:getMapHasStones() or (fieldIndex == nil or fieldIndex > 2 ^ EasyDevControlsAddRemoveDeltaEvent.FIELD_SEND_NUM_BITS - 1) then
        return self.requestFailedText
    end

    if self.isServer then
        stoneSystem:consoleCommandAddDelta(fieldIndex, delta)

        if delta < 0 then
            return EasyDevUtils.formatText("easyDevControls_removeWeedOrStoneDelta", g_i18n:getText("setting_stonesEnabled"), tostring(math.abs(delta)))
        end

        return EasyDevUtils.formatText("easyDevControls_addWeedOrStoneDelta", g_i18n:getText("setting_stonesEnabled"), tostring(math.abs(delta)))
    else
        self:clientSendEvent(EasyDevControlsAddRemoveDeltaEvent.new(false, fieldIndex, delta))
    end
end

-- Advance Growth / Set Seasonal Growth Period
function EasyDevControls:setGrowthPeriod(seasonal, period)
    period = period or g_currentMission.environment.currentPeriod

    if seasonal and period > 2 ^ EasyDevControlsUpdateSetGrowthPeriodEvent.PERIOD_SEND_NUM_BITS - 1 then
        return self.requestFailedText
    end

    if self.isServer then
        local growthSystem = g_currentMission.growthSystem

        if not seasonal and growthSystem:getGrowthMode() ~= GrowthSystem.MODE.DAILY then
            return self.requestFailedText
        end

        growthSystem:triggerGrowth(period)

        return EasyDevUtils.getText("easyDevControls_updatingAllFieldsMessage")
    else
        -- Event send Dialogue is not required as that is handled by the Frame even in SP
        g_client:getServerConnection():sendEvent(EasyDevControlsUpdateSetGrowthPeriodEvent.new(seasonal, period))

        return self.serverRequestText
    end
end

-- Set Time (Month, Day, Hour)
function EasyDevControls:setCurrentTime(hourToSet, daysToAdvance)
    if hourToSet == nil or daysToAdvance == nil then
        return ""
    end

    if self.isServer then
        local environment = g_currentMission.environment
        local hourToSet = math.floor(hourToSet * 1000 * 60 * 60)

        if daysToAdvance <= 0 and hourToSet <= environment.dayTime then
            return ""
        end

        local monotonicDayToSet = environment.currentMonotonicDay + daysToAdvance
        local dayToSet = environment.currentDay + daysToAdvance

        environment:setEnvironmentTime(monotonicDayToSet, dayToSet, hourToSet, environment.daysPerPeriod, false)
        environment.lighting:update(1, true)

        -- To Do update UI
        g_server:broadcastEvent(EnvironmentTimeEvent.new(monotonicDayToSet, dayToSet, hourToSet, environment.daysPerPeriod))

        local hourFormat = string.format("%02.f:00", environment.currentHour)
        local periodFormat = g_i18n:formatDayInPeriod(environment.currentDayInPeriod, environment.currentPeriod, false)

        return EasyDevUtils.formatText("easyDevControls_setTimeInfo", periodFormat, hourFormat)
    else
        return self:clientSendEvent(EasyDevControlsTimeEvent.new(hourToSet, daysToAdvance))
    end
end

-- Add / Set Snow
function EasyDevControls:updateSnowAndSalt(typeId, value)
    if (g_currentMission == nil or g_currentMission.snowSystem == nil) or (EasyDevControlsUpdateSnowAndSaltEvent.requiresValue(typeId) and value == nil) then
        return self.requestFailedText
    end

    if self.isServer then
        local snowSystem = g_currentMission.snowSystem

        if typeId == EasyDevControlsUpdateSnowAndSaltEvent.ADD_SALT then
            local x, _, z = getWorldTranslation(getCamera(0))
            local startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ = EasyDevUtils.getArea(x, z, value, false)

            snowSystem:removeSnow(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, 1) -- Remove only one layer around player at give radius
            -- snowSystem:consoleCommandSalt(value)

            return EasyDevUtils.formatText("easyDevControls_addSaltInfo", value)
        end

        local environment = g_currentMission.environment

        if environment ~= nil and environment.weather ~= nil then
            if typeId == EasyDevControlsUpdateSnowAndSaltEvent.ADD_SNOW then
                environment.weather.snowHeight = SnowSystem.MAX_HEIGHT
                snowSystem:setSnowHeight(SnowSystem.MAX_HEIGHT)

                return EasyDevUtils.getText("easyDevControls_addSnowInfo")
            elseif typeId == EasyDevControlsUpdateSnowAndSaltEvent.SET_SNOW then
                environment.weather.snowHeight = value
                snowSystem:setSnowHeight(value)

                return EasyDevUtils.formatText("easyDevControls_setSnowInfo", snowSystem.height)
            elseif typeId == EasyDevControlsUpdateSnowAndSaltEvent.REMOVE_SNOW then
                environment.weather.snowHeight = 0
                snowSystem:removeAll()

                return EasyDevUtils.getText("easyDevControls_removeSnowInfo")
            end
        end

        return self.requestFailedText
    else
        return self:clientSendEvent(EasyDevControlsUpdateSnowAndSaltEvent.new(typeId, value))
    end
end

function EasyDevControls:clientSendEvent(event)
    if self.isClient then
        g_client:getServerConnection():sendEvent(event)

        if self.ui ~= nil and self.ui.menu ~= nil then
            self.ui.menu:onSendServerRequest(g_client.currentLatency, nil, nil)
        end

        return self.serverRequestText
    end
end

function EasyDevControls:setDevelopmentMode(active)
    g_easyDevDevelopmentMode  = Utils.getNoNil(active, false)
end

function EasyDevControls:getVehicle(ignoreFarm, getRootVehicle)
    if g_currentMission ~= nil then
        local vehicle = g_currentMission.controlledVehicle

        if vehicle ~= nil then
            return vehicle, true
        end

        local player = g_currentMission.player

        if player ~= nil and player.lastFoundAnyObject ~= nil then
            local object = g_currentMission:getNodeObject(player.lastFoundAnyObject)

            if object ~= nil and object:isa(Vehicle) then
                ignoreFarm = ignoreFarm or (self.isServer or g_currentMission.isMasterUser)

                if ignoreFarm or (object:getOwnerFarmId() == player.farmId) then
                    if getRootVehicle then
                        return object:findRootVehicle() or object, false
                    end

                    return object, false
                end
            end
        end
    end

    return nil, false
end

function EasyDevControls:getSelectedVehicle(requiredName, ignoreFarm)
    local vehicle, isEntered = self:getVehicle(ignoreFarm)
    local selectedVehicle

    if vehicle ~= nil then
        if self:getIsValidVehicle(vehicle, requiredName) then
            selectedVehicle = vehicle
        end

        if isEntered and vehicle.getSelectedObject ~= nil then
            local selectedObject = vehicle:getSelectedObject()

            if selectedObject ~= nil and self:getIsValidVehicle(selectedObject.vehicle, requiredName) then
                selectedVehicle = selectedObject.vehicle
            end
        end
    end

    return selectedVehicle
end

function EasyDevControls:getIsValidVehicle(vehicle, requiredName)
    if vehicle == nil or (vehicle.isDeleted or vehicle.isDeleting) then
        return false
    end

    if requiredName ~= nil and vehicle[requiredName] == nil then
        return false
    end

    return true
end

function EasyDevControls:getObjectSpawnLocation(setY)
    setY = setY or 1

    if g_currentMission.controlPlayer then
        local player = g_currentMission.player

        if player ~= nil and player.isControlled and player.rootNode ~= nil and player.rootNode ~= 0 then
            local x, y, z = getWorldTranslation(player.rootNode)
            local dirX, dirY, dirZ = -math.sin(player.rotY), 0, -math.cos(player.rotY)
            local ry = MathUtil.getYRotationFromDirection(dirX, dirZ)

            return (x + dirX * 4), (y + setY), (z + dirZ * 4), dirX, dirY, dirZ, ry
        end
    elseif g_currentMission.controlledVehicle ~= nil then
        local x, y, z = getWorldTranslation(g_currentMission.controlledVehicle.rootNode)
        local dirX, dirY, dirZ = localDirectionToWorld(g_currentMission.controlledVehicle.rootNode, 0, 0, 1)
        local ry = MathUtil.getYRotationFromDirection(dirX, dirZ)

        return (x + dirX * 4), (y + setY), (z + dirZ * 4), dirX, dirY, dirZ, ry
    end

    return nil
end

function EasyDevControls:onConnectionFinishedLoading(mission, connection, x, y, z, viewDistanceCoeff)
    local suppressInfo = g_easyDevDevelopmentMode == nil or g_easyDevDevelopmentMode == false

    connection:sendEvent(EasyDevControlsPermissionsEvent.new(suppressInfo))
    connection:sendEvent(EasyDevControlsTimeScaleEvent.new(Utils.getNoNil(edc_timeScaleCustomSettingsActive, false)))
end

function EasyDevControls:onRegisterActionEvents(mission, inputManager)
    local _, eventId = inputManager:registerActionEvent(InputAction.EDC_SHOW_UI, self, self.onInputOpenMenu, false, true, false, true)

    inputManager:setActionEventTextVisibility(eventId, false)
    self.eventIdOpenMenu = eventId

    _, eventId = inputManager:registerActionEvent(InputAction.EDC_TOGGLE_HUD, self, self.onInputToggleHud, false, true, false, true)

    inputManager:setActionEventTextVisibility(eventId, false)
    inputManager:setActionEventActive(eventId, self.toggleHudInputEnabled)
    self.eventIdToggleHud = eventId
end

function EasyDevControls:onUnregisterActionEvents(mission, inputManager)
    inputManager:removeActionEventsByTarget(self)

    self.eventIdOpenMenu = nil
    self.eventIdToggleHud = nil
end

function EasyDevControls:onRegisterPlayerActionEvents(player, inputManager)
    self.controlledPlayer = player

    if self.thirdPersonAvailable and player.thirdPersonViewActive then
        self:updateThirdPersonCameraModelTarget(player) -- Fix for third person mode, hand tools are not great but this is for picture taking not playing
    end

    local _, eventId = inputManager:registerActionEvent(InputAction.EDC_PLAYER_RUN_SPEED, self, self.onInputPlayerRunSpeed, false, true, false, true)

    inputManager:setActionEventTextVisibility(eventId, false)
    inputManager:setActionEventActive(eventId, edc_maxRunningSpeedInputActive)

    self.eventIdTogglePlayerRunSpeed = eventId

    if self.isServer or g_currentMission.isMasterUser then
        _, eventId = inputManager:registerActionEvent(InputAction.EDC_OBJECT_DELETE, self, self.onInputObjectDelete, false, true, false, true)

        inputManager:setActionEventTextVisibility(eventId, false)
        inputManager:setActionEventActive(eventId, false)

        self.eventIdObjectDelete = eventId
    end
end

function EasyDevControls:onRemovePlayerActionEvents(player, inputManager)
    self.controlledPlayer = nil
    self.thirdPersonActive = false

    if self.eventIdTogglePlayerRunSpeed ~= nil then
        inputManager:removeActionEvent(self.eventIdTogglePlayerRunSpeed)
        self.eventIdTogglePlayerRunSpeed = nil
    end

    if self.eventIdObjectDelete ~= nil then
        inputManager:removeActionEvent(self.eventIdObjectDelete)
        self.eventIdObjectDelete = nil
    end
end

function EasyDevControls:onInputOpenMenu(actionName, inputValue, callbackState, isAnalog, isMouse, deviceCategory, binding)
    if self.isEnabled and self.ui ~= nil then
        self.ui:onOpenMenu(false)
    end
end

function EasyDevControls:onInputPlayerRunSpeed(actionName, inputValue, callbackState, isAnalog, isMouse, deviceCategory, binding)
    edc_maxRunningSpeedActive = not edc_maxRunningSpeedActive
end

function EasyDevControls:onInputObjectDelete(actionName, inputValue, callbackState, isAnalog, isMouse, deviceCategory, binding)
    if self.isServer or g_currentMission.isMasterUser then
        if self.controlledPlayer ~= nil and not self.controlledPlayer.isCarryingObject then
            local hudUpdater = self.controlledPlayer.hudUpdater

            if hudUpdater.object ~= nil then
                if hudUpdater.isVehicle or hudUpdater.isPallet then
                    if hudUpdater.object.trainSystem == nil then
                        g_currentMission:removeVehicle(hudUpdater.object)
                    end
                elseif hudUpdater.isBale then
                    if self.isServer then
                        hudUpdater.object:delete()
                    else
                        g_client:getServerConnection():sendEvent(EasyDevControlsDeleteObjectEvent.new(EasyDevControlsDeleteObjectEvent.TYPE_BALE, hudUpdater.object))
                    end
                elseif hudUpdater.isSplitShape and entityExists(hudUpdater.object) then
                    if self.isServer then
                        EasyDevUtils.deleteTree(hudUpdater.object, false)
                    else
                        g_client:getServerConnection():sendEvent(EasyDevControlsDeleteObjectEvent.new(EasyDevControlsDeleteObjectEvent.TYPE_LOG, hudUpdater.object))
                    end
                end
            elseif self.lastHitObject ~= nil and self.lastHitObjectTypeId ~= nil and entityExists(self.lastHitObject) then
                if self.isServer then
                    EasyDevUtils.deleteTree(self.lastHitObject, self.lastHitObjectTypeId == EasyDevControlsDeleteObjectEvent.TYPE_TREE)
                else
                    g_client:getServerConnection():sendEvent(EasyDevControlsDeleteObjectEvent.new(self.lastHitObjectTypeId, self.lastHitObject))
                end
            end
        end
    end
end

function EasyDevControls:onInputToggleHud(actionName, inputValue, callbackState, isAnalog, isMouse, deviceCategory, binding)
    if g_currentMission ~= nil and g_currentMission.hud ~= nil then
        g_currentMission.hud:consoleCommandToggleVisibility()
    end
end

function EasyDevControls:consoleCommandLeave(keepLogFile)
    EasyDevUtils.doRestart(Utils.stringToBoolean(keepLogFile), "")
end

function EasyDevControls:consoleCommandRestartWithParamater(parameter, loadSavegame, clearLogFile)
    if parameter ~= nil then
        local function restartWithParamaters()
            local savegameIndex = 0

            loadSavegame = Utils.stringToBoolean(loadSavegame)

            if loadSavegame and g_currentMission ~= nil and g_currentMission.missionInfo ~= nil then
                local savegameController = g_currentMission.savegameController
                local savegame = g_careerScreen.savegameController:getSavegame(g_currentMission.missionInfo.savegameIndex)

                if savegame == SavegameController.NO_SAVEGAME or not savegame.isValid then
                    loadSavegame = false
                else
                    savegameIndex = savegame.savegameIndex
                end
            end

            RestartManager:setStartScreen(RestartManager.START_SCREEN_MAIN)

            if loadSavegame then
                Logging.info("[Easy Development Controls] - Restarting and reloading savegame with parameter ( %s ).", parameter)

                EasyDevUtils.doRestart(not Utils.stringToBoolean(clearLogFile), string.format("-autoStartSavegameId %d %s", savegameIndex, parameter))
            else
                Logging.info("[Easy Development Controls] - Restarting with parameter ( %s ).", parameter)

                EasyDevUtils.doRestart(not Utils.stringToBoolean(clearLogFile), parameter)
            end
        end

        g_gui:showInfoDialog({
            text = "This function will continue to be used until complete application exit!",
            callback = restartWithParamaters
        })

        return "WARNING: This function will continue to be used until complete application exit!"
    end

    return "No parameter given!"
end

function EasyDevControls:consoleCommandRestartCurrentSaveGame(clearLogFile)
    if g_currentMission ~= nil and g_currentMission.missionInfo ~= nil then
        local savegameController = g_currentMission.savegameController
        local savegame = g_careerScreen.savegameController:getSavegame(g_currentMission.missionInfo.savegameIndex)

        if savegame == SavegameController.NO_SAVEGAME or not savegame.isValid then
            return "No savegame found for current game!"
        end

        local function restartCurrentSaveGame()
            Logging.info("[Easy Development Controls] - Restarting Savegame with ID %d.", savegame.savegameIndex)

            EasyDevUtils.doRestart(not Utils.stringToBoolean(clearLogFile), string.format("-autoStartSavegameId %d", savegame.savegameIndex))
        end

        g_gui:showInfoDialog({
            text = "This function will continue to be used until complete application exit!",
            callback = restartCurrentSaveGame
        })

        return "WARNING: This function will continue to be used until complete application exit!"
    end

    return "Not possible when loading game!"
end

function EasyDevControls:consoleCommandResetEDC(timeScale)
    if g_currentMission ~= nil and not g_gui:getIsGuiVisible() and self.ui ~= nil then
        local updateResult = "Hud Input Enabled: false"

        self:setToggleHudInputEnabled(false)

        if Utils.stringToBoolean(timeScale) and g_currentMission.isMasterUser then
            self:setCustomTimeScaleState(true)

            updateResult = updateResult .. " | Custom time scale: true"
        end

        if self.ui:getHasPermission("runningSpeed", EasyDevControlsUI.ACCESS_NONE) then
            self:setRunningSpeedKeyActive(true)
            self:setRunningSpeedMultiplier(4)

            updateResult = updateResult .. " | Running Speed Input Active: true | Running Speed Multiplier: 4x"
        end

        if self.ui:getHasPermission("jumpHeight", EasyDevControlsUI.ACCESS_NONE) then
            self:setPlayerJumpHeight(2)

            updateResult = updateResult .. " | Jump Height Multiplier: 2x"
        end

        return updateResult
    end

    return "Not possible when loading game or while a GUI is open!"
end

function EasyDevControls:consoleCommandPrintScenegraph(nodeName, visibleOnly, clearLog)
    local node = getRootNode()

    nodeName = nodeName or "rootNode"
    nodeNameUpper = nodeName:upper()

    if nodeNameUpper ~= "ROOTNODE" then
        if nodeNameUpper == "TREES" then
            if g_treePlantManager.treesData ~= nil then
                node = g_treePlantManager.treesData.rootNode
            end
        else
            node = getChild(node, nodeName)
        end
    end

    if node == nil or node == 0 then
        return "Failed to find valid scenegraph node"
    end

    if clearLog ~= "false" then
        EasyDevUtils.clearFile(getUserProfileAppPath() .. "log.txt")
    end

    setFileLogPrefixTimestamp(false)

    printScenegraph(node, Utils.stringToBoolean(visibleOnly))

    setFileLogPrefixTimestamp(g_logFilePrefixTimestamp)

    return
end

function EasyDevControls:consoleCommandPrintEnvironment(clearLog, path, ...)
    local environment = _G

    if self.godMode ~= nil and self.godMode.getValidEnvironment ~= nil then
        if path == nil or path:sub(1, 6) ~= "local." then
            environment = self.godMode:getValidEnvironment(environment)
        else
            path = path:sub(7, #path)
        end
    end

    local valid, variable, owner, name = EasyDevUtils.getPathFromString(environment, path)

    if valid then
        clearLog = clearLog or "false"

        if clearLog:lower() == "true" then
            EasyDevUtils.clearFile(getUserProfileAppPath() .. "log.txt")
        end

        local variableType = type(variable)

        setFileLogPrefixTimestamp(false)

        if variableType == "table" then
            local depthValues = {...}

            local maxDepth = tonumber(depthValues[2]) or 2
            local depth = math.min(tonumber(depthValues[1]) or 1, maxDepth)

            print("", "##  Start  ##", "")
            DebugUtil.printTableRecursively(variable, " ", depth, maxDepth)
            print("", "##  Finish  ##", "")
        elseif variableType == "function" then
            local parameters = {...}
            local params = {}

            name = name or "..."

            local nameLength = (name ~= "..." and #name or -1) + 2

            for i, parameter in ipairs (parameters) do
                local number = tonumber(parameter)

                if number ~= nil then
                    parameters[i] = number
                elseif parameter == "self" then
                    parameters[i] = owner
                elseif parameter == "true" or parameter == "false" then
                    parameters[i] = parameter == "true"
                end

                params[i] = parameter
            end

            local function printProtectedCall(doPrint, func, ...)
                local returned = {pcall(func, ...)}

                if not returned[1] then
                    if doPrint then
                        print("Function call failed or return was nil:" .. returned[2])

                        return
                    end

                    return "Function call failed or return was nil:" .. returned[2]
                end

                if doPrint then
                    for i = 2, #returned do
                        if type(returned[i]) == "table" then
                            print("")
                            DebugUtil.printTableRecursively(returned[i], " ", 1, 1)
                            print("")
                        else
                            print(tostring(returned[i]))
                        end
                    end

                    return
                end

                return unpack(returned, 2)
            end

            print("", "##  Start | Executed function: " .. name .. "(" .. table.concat(params, ", ") .. ") | Environment: " .. path:sub(1, -nameLength) .. "  ##", "")
            printProtectedCall(true, variable, unpack(parameters))
            print("", "##  Finish  ##", "")
        else
            print("", "##  Start  ##", "", path .. " = " .. tostring(variable), "", "##  Finish  ##")
        end

        setFileLogPrefixTimestamp(g_logFilePrefixTimestamp)

        return
    end

    return "Invalid path given!"
end

function EasyDevControls.inj_utils_getNumTimeScales(_, superFunc)
    if edc_timeScaleCustomSettingsActive then
        return #edc_timeScaleCustomSettings
    end

    return superFunc()
end

function EasyDevControls.inj_utils_getTimeScaleString(timeScaleIndex, superFunc)
    if edc_timeScaleCustomSettingsActive then
        local timeScale = Utils.getTimeScaleFromIndex(timeScaleIndex)

        if timeScale == 1 then
            return g_i18n:getText("ui_realTime")
        elseif timeScale < 1 then
            return string.format("%0.2fx", timeScale)
        else
            return string.format("%dx", timeScale)
        end
    end

    return superFunc(timeScaleIndex)
end

function EasyDevControls.inj_utils_getTimeScaleIndex(timeScale, superFunc)
    if timeScale == 0 then
        return 1
    end

    if edc_timeScaleCustomSettingsActive then
        for i = #edc_timeScaleCustomSettings, 1, -1 do
            if edc_timeScaleCustomSettings[i] <= timeScale then
                return i
            end
        end

        return 2
    end

    return superFunc(timeScale)
end

function EasyDevControls.inj_utils_getTimeScaleFromIndex(timeScaleIndex, superFunc)
    if edc_timeScaleCustomSettingsActive then
        timeScaleIndex = math.max(timeScaleIndex, 1)

        return edc_timeScaleCustomSettings[timeScaleIndex]
    end

    return superFunc(timeScaleIndex)
end

function EasyDevControls.inj_player_getDesiredSpeed(self, superFunc)
    local inputRight = self.inputInformation.moveRight
    local inputForward = self.inputInformation.moveForward

    if ((inputForward ~= 0.0) or (inputRight ~= 0.0)) then
        local isSwimming = self.playerStateMachine:isActive("swim")
        local isCrouching = self.playerStateMachine:isActive("crouch")
        local isFalling = self.playerStateMachine:isActive("fall")
        local isUsingHandtool = self:hasHandtoolEquipped()
        local baseSpeed = self.motionInformation.maxWalkingSpeed

        if isFalling then
            baseSpeed = self.motionInformation.maxFallingSpeed
        elseif isSwimming then
            baseSpeed = self.motionInformation.maxSwimmingSpeed
        elseif isCrouching then
            baseSpeed = self.motionInformation.maxCrouchingSpeed
        end

        local magnitude = math.sqrt(inputRight * inputRight + inputForward * inputForward)
        local desiredSpeed = MathUtil.clamp(magnitude, 0.0, 1.0) * baseSpeed
        local inputRun = self.inputInformation.runAxis

        if (inputRun > 0.0) and not (isSwimming or isCrouching or isUsingHandtool) then -- do running check
            local runningSpeed = self.motionInformation.maxRunningSpeed

            -- Need to overwrite the whole function so other mods do not interfere / conflict, also not necessary to have fast running mods when EDC is active
            if edc_maxRunningSpeedActive then
                runningSpeed = edc_maxRunningSpeed
            elseif g_addTestCommands and not g_isPresentationVersion then
                runningSpeed = self.motionInformation.maxPresentationRunningSpeed
            elseif g_addCheatCommands and not g_isPresentationVersion and (g_currentMission.isMasterUser or g_currentMission:getIsServer()) then
                runningSpeed = self.motionInformation.maxCheatRunningSpeed
            end

            desiredSpeed = math.max(desiredSpeed + (runningSpeed - desiredSpeed) * MathUtil.clamp(inputRun, 0.0, 1.0), desiredSpeed)
        end

        return desiredSpeed
    end

    return 0.0
end
