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

EasyDevControlsPermissionsEvent = {}

EasyDevControlsPermissionsEvent.SEND_NUM_BITS = 3

local EasyDevControlsPermissionsEvent_mt = Class(EasyDevControlsPermissionsEvent, Event)
InitEventClass(EasyDevControlsPermissionsEvent, "EasyDevControlsPermissionsEvent")

function EasyDevControlsPermissionsEvent.emptyNew()
    local self = Event.new(EasyDevControlsPermissionsEvent_mt)

    return self
end

function EasyDevControlsPermissionsEvent.new(suppressInfo)
    local self = EasyDevControlsPermissionsEvent.emptyNew()

    self.suppressInfo = suppressInfo

    return self
end

function EasyDevControlsPermissionsEvent:readStream(streamId, connection)
    local cheatMoney = streamReadUIntN(streamId, EasyDevControlsPermissionsEvent.SEND_NUM_BITS)
    local teleport = streamReadUIntN(streamId, EasyDevControlsPermissionsEvent.SEND_NUM_BITS)
    local flipVehicles = streamReadUIntN(streamId, EasyDevControlsPermissionsEvent.SEND_NUM_BITS)

    local superStrength = streamReadUIntN(streamId, EasyDevControlsPermissionsEvent.SEND_NUM_BITS)
    local jumpHeight = streamReadUIntN(streamId, EasyDevControlsPermissionsEvent.SEND_NUM_BITS)
    local runningSpeed = streamReadUIntN(streamId, EasyDevControlsPermissionsEvent.SEND_NUM_BITS)
    local setFarm = streamReadUIntN(streamId, EasyDevControlsPermissionsEvent.SEND_NUM_BITS)

    local addBale = streamReadUIntN(streamId, EasyDevControlsPermissionsEvent.SEND_NUM_BITS)
    local addPallet = streamReadUIntN(streamId, EasyDevControlsPermissionsEvent.SEND_NUM_BITS)
    local addLog = streamReadUIntN(streamId, EasyDevControlsPermissionsEvent.SEND_NUM_BITS)

    local vehicleFillLevel = streamReadUIntN(streamId, EasyDevControlsPermissionsEvent.SEND_NUM_BITS)
    local vehicleCondition = streamReadUIntN(streamId, EasyDevControlsPermissionsEvent.SEND_NUM_BITS)
    local vehicleFuel = streamReadUIntN(streamId, EasyDevControlsPermissionsEvent.SEND_NUM_BITS)
    local vehicleMotorTemp = streamReadUIntN(streamId, EasyDevControlsPermissionsEvent.SEND_NUM_BITS)
    local vehicleOperatingTime = streamReadUIntN(streamId, EasyDevControlsPermissionsEvent.SEND_NUM_BITS)

    local productionPoints = streamReadUIntN(streamId, EasyDevControlsPermissionsEvent.SEND_NUM_BITS)

    local fieldSetFruit = streamReadUIntN(streamId, EasyDevControlsPermissionsEvent.SEND_NUM_BITS)
    local fieldSetGround = streamReadUIntN(streamId, EasyDevControlsPermissionsEvent.SEND_NUM_BITS)
    local vineSetState = streamReadUIntN(streamId, EasyDevControlsPermissionsEvent.SEND_NUM_BITS)
    local addRemoveWeedsStones = streamReadUIntN(streamId, EasyDevControlsPermissionsEvent.SEND_NUM_BITS)
    local updateGrowthSystem = streamReadUIntN(streamId, EasyDevControlsPermissionsEvent.SEND_NUM_BITS)

    local setTime = streamReadUIntN(streamId, EasyDevControlsPermissionsEvent.SEND_NUM_BITS)
    local updateSnow = streamReadUIntN(streamId, EasyDevControlsPermissionsEvent.SEND_NUM_BITS)
    local addSalt = streamReadUIntN(streamId, EasyDevControlsPermissionsEvent.SEND_NUM_BITS)

    local suppressInfo = streamReadBool(streamId)

    if g_easyDevControls ~= nil and g_easyDevControls.ui ~= nil then
        local ui = g_easyDevControls.ui

        ui:setPermission("cheatMoney", cheatMoney, suppressInfo)
        ui:setPermission("teleport", teleport, suppressInfo)
        ui:setPermission("flipVehicles", flipVehicles, suppressInfo)

        ui:setPermission("superStrength", superStrength, suppressInfo)
        ui:setPermission("jumpHeight", jumpHeight, suppressInfo, true)
        ui:setPermission("runningSpeed", runningSpeed, suppressInfo, true)
        ui:setPermission("setFarm", setFarm, suppressInfo)

        ui:setPermission("addBale", addBale, suppressInfo)
        ui:setPermission("addPallet", addPallet, suppressInfo)
        ui:setPermission("addLog", addLog, suppressInfo)

        ui:setPermission("vehicleFillLevel", vehicleFillLevel, suppressInfo)
        ui:setPermission("vehicleCondition", vehicleCondition, suppressInfo)
        ui:setPermission("vehicleFuel", vehicleFuel, suppressInfo)
        ui:setPermission("vehicleMotorTemp", vehicleMotorTemp, suppressInfo)
        ui:setPermission("vehicleOperatingTime", vehicleOperatingTime, suppressInfo)

        ui:setPermission("productionPoints", productionPoints, suppressInfo)

        ui:setPermission("fieldSetFruit", fieldSetFruit, suppressInfo)
        ui:setPermission("fieldSetGround", fieldSetGround, suppressInfo)
        ui:setPermission("vineSetState", vineSetState, suppressInfo)
        ui:setPermission("addRemoveWeedsStones", addRemoveWeedsStones, suppressInfo)
        ui:setPermission("updateGrowthSystem", updateGrowthSystem, suppressInfo)

        ui:setPermission("setTime", setTime, suppressInfo)
        ui:setPermission("updateSnow", updateSnow, suppressInfo)
        ui:setPermission("addSalt", addSalt, suppressInfo)

        g_messageCenter:publishDelayed(EasyDevUtils.MESSAGE_TYPE_PERMISSIONS_CHANGED)

        if not connection:getIsServer() then
            self.suppressInfo = suppressInfo

            g_server:broadcastEvent(self, false, connection)
        end
    else
        EasyDevUtils.devInfo("[EasyDevControlsPermissionsEvent] Failed to send event!")
    end
end

function EasyDevControlsPermissionsEvent:writeStream(streamId, connection)
    local admin = EasyDevControlsUI.ACCESS_ADMIN
    local none = EasyDevControlsUI.ACCESS_NONE
    local permissions = {}

    if g_easyDevControls ~= nil and g_easyDevControls.ui ~= nil then
        permissions = g_easyDevControls.ui:getPermissions() or permissions
    end

    streamWriteUIntN(streamId, permissions.cheatMoney or admin, EasyDevControlsPermissionsEvent.SEND_NUM_BITS)
    streamWriteUIntN(streamId, permissions.teleport or admin, EasyDevControlsPermissionsEvent.SEND_NUM_BITS)
    streamWriteUIntN(streamId, permissions.flipVehicles or admin, EasyDevControlsPermissionsEvent.SEND_NUM_BITS)

    streamWriteUIntN(streamId, permissions.superStrength or admin, EasyDevControlsPermissionsEvent.SEND_NUM_BITS)
    streamWriteUIntN(streamId, permissions.jumpHeight or none, EasyDevControlsPermissionsEvent.SEND_NUM_BITS)
    streamWriteUIntN(streamId, permissions.runningSpeed or none, EasyDevControlsPermissionsEvent.SEND_NUM_BITS)
    streamWriteUIntN(streamId, permissions.setFarm or admin, EasyDevControlsPermissionsEvent.SEND_NUM_BITS)

    streamWriteUIntN(streamId, permissions.addBale or admin, EasyDevControlsPermissionsEvent.SEND_NUM_BITS)
    streamWriteUIntN(streamId, permissions.addPallet or admin, EasyDevControlsPermissionsEvent.SEND_NUM_BITS)
    streamWriteUIntN(streamId, permissions.addLog or admin, EasyDevControlsPermissionsEvent.SEND_NUM_BITS)

    streamWriteUIntN(streamId, permissions.vehicleFillLevel or admin, EasyDevControlsPermissionsEvent.SEND_NUM_BITS)
    streamWriteUIntN(streamId, permissions.vehicleCondition or admin, EasyDevControlsPermissionsEvent.SEND_NUM_BITS)
    streamWriteUIntN(streamId, permissions.vehicleFuel or admin, EasyDevControlsPermissionsEvent.SEND_NUM_BITS)
    streamWriteUIntN(streamId, permissions.vehicleMotorTemp or admin, EasyDevControlsPermissionsEvent.SEND_NUM_BITS)
    streamWriteUIntN(streamId, permissions.vehicleOperatingTime or admin, EasyDevControlsPermissionsEvent.SEND_NUM_BITS)

    streamWriteUIntN(streamId, permissions.productionPoints or admin, EasyDevControlsPermissionsEvent.SEND_NUM_BITS)

    streamWriteUIntN(streamId, permissions.fieldSetFruit or admin, EasyDevControlsPermissionsEvent.SEND_NUM_BITS)
    streamWriteUIntN(streamId, permissions.fieldSetGround or admin, EasyDevControlsPermissionsEvent.SEND_NUM_BITS)
    streamWriteUIntN(streamId, permissions.vineSetState or admin, EasyDevControlsPermissionsEvent.SEND_NUM_BITS)
    streamWriteUIntN(streamId, permissions.addRemoveWeedsStones or admin, EasyDevControlsPermissionsEvent.SEND_NUM_BITS)
    streamWriteUIntN(streamId, permissions.updateGrowthSystem or admin, EasyDevControlsPermissionsEvent.SEND_NUM_BITS)

    streamWriteUIntN(streamId, permissions.setTime or admin, EasyDevControlsPermissionsEvent.SEND_NUM_BITS)
    streamWriteUIntN(streamId, permissions.updateSnow or admin, EasyDevControlsPermissionsEvent.SEND_NUM_BITS)
    streamWriteUIntN(streamId, permissions.addSalt or admin, EasyDevControlsPermissionsEvent.SEND_NUM_BITS)

    streamWriteBool(streamId, self.suppressInfo)
end

function EasyDevControlsPermissionsEvent:run(connection)
    print("Error: EasyDevControlsPermissionsEvent is not allowed to be executed on a local client")
end

function EasyDevControlsPermissionsEvent.sendEvent(suppressInfo, noEventSend)
    if noEventSend == nil or noEventSend == false then
        suppressInfo = Utils.getNoNil(suppressInfo, true)

        if g_currentMission:getIsServer() then
            g_server:broadcastEvent(EasyDevControlsPermissionsEvent.new(suppressInfo), false)
        else
            g_client:getServerConnection():sendEvent(EasyDevControlsPermissionsEvent.new(suppressInfo))
        end
    end
end
