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

EasyDevControlsVehicleOperatingValueEvent = {}

EasyDevControlsVehicleOperatingValueEvent.FUEL = 0
EasyDevControlsVehicleOperatingValueEvent.MOTOR_TEMP = 1
EasyDevControlsVehicleOperatingValueEvent.OPERATING_TIME = 2

local EasyDevControlsVehicleOperatingValueEvent_mt = Class(EasyDevControlsVehicleOperatingValueEvent, Event)
InitEventClass(EasyDevControlsVehicleOperatingValueEvent, "EasyDevControlsVehicleOperatingValueEvent")

function EasyDevControlsVehicleOperatingValueEvent.emptyNew()
    local self = Event.new(EasyDevControlsVehicleOperatingValueEvent_mt)

    return self
end

function EasyDevControlsVehicleOperatingValueEvent.new(vehicle, typeId, value)
    local self = EasyDevControlsVehicleOperatingValueEvent.emptyNew()

    self.vehicle = vehicle
    self.typeId = typeId
    self.value = value

    return self
end

function EasyDevControlsVehicleOperatingValueEvent:readStream(streamId, connection)
    self.vehicle = NetworkUtil.readNodeObject(streamId)
    self.typeId = streamReadUIntN(streamId, 2)
    self.value = streamReadFloat32(streamId)

    self:run(connection)
end

function EasyDevControlsVehicleOperatingValueEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.vehicle)
    streamWriteUIntN(streamId, self.typeId, 2)
    streamWriteFloat32(streamId, self.value)
end

function EasyDevControlsVehicleOperatingValueEvent:run(connection)
    if g_easyDevControls ~= nil then
        if not connection:getIsServer() then
            local message

            if self.typeId == EasyDevControlsVehicleOperatingValueEvent.FUEL then
                message = g_easyDevControls:setVehicleFuel(self.vehicle, self.value)
            elseif self.typeId == EasyDevControlsVehicleOperatingValueEvent.MOTOR_TEMP then
                message = g_easyDevControls:setVehicleMotorTemperature(self.vehicle, self.value)
            elseif self.typeId == EasyDevControlsVehicleOperatingValueEvent.OPERATING_TIME then
                message = g_easyDevControls:setVehicleOperatingTime(self.vehicle, self.value)

                g_server:broadcastEvent(EasyDevControlsVehicleOperatingValueEvent.new(self.vehicle, EasyDevControlsVehicleOperatingValueEvent.OPERATING_TIME, self.value * 1000 * 60 * 60))
            end

            if g_dedicatedServer ~= nil and message ~= nil then
                Logging.info(message)
            end
        else
            if self.typeId == EasyDevControlsVehicleOperatingValueEvent.OPERATING_TIME then
                if (self.vehicle ~= nil and self.vehicle.setOperatingTime ~= nil) and self.value ~= nil then
                    self.vehicle:setOperatingTime(self.value)
                end
            else
                print("Error: EasyDevControlsVehicleOperatingValueEvent is a client to server only event! Type ID: " .. tostring(self.typeId or "N/A"))
            end
        end
    end
end
