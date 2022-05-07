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

EasyDevControlsVehicleConditionEvent = {}

EasyDevControlsVehicleConditionEvent.TYPE_DIRT = 0
EasyDevControlsVehicleConditionEvent.TYPE_WEAR = 1
EasyDevControlsVehicleConditionEvent.TYPE_DAMAGE = 2
EasyDevControlsVehicleConditionEvent.TYPE_ALL = 3

EasyDevControlsVehicleConditionEvent.SEND_NUM_BITS = 3

local EasyDevControlsVehicleConditionEvent_mt = Class(EasyDevControlsVehicleConditionEvent, Event)
InitEventClass(EasyDevControlsVehicleConditionEvent, "EasyDevControlsVehicleConditionEvent")

function EasyDevControlsVehicleConditionEvent.emptyNew()
    local self = Event.new(EasyDevControlsVehicleConditionEvent_mt)

    return self
end

function EasyDevControlsVehicleConditionEvent.new(vehicle, isEntered, typeId, setToAmount, amount)
    local self = EasyDevControlsVehicleConditionEvent.emptyNew()

    self.vehicle = vehicle

    self.isEntered = isEntered
    self.typeId = typeId

    self.setToAmount = setToAmount
    self.amount = amount

    return self
end

function EasyDevControlsVehicleConditionEvent:readStream(streamId, connection)
    self.vehicle = NetworkUtil.readNodeObject(streamId)

    self.isEntered = streamReadBool(streamId)
    self.typeId = streamReadUIntN(streamId, EasyDevControlsVehicleConditionEvent.SEND_NUM_BITS)

    self.setToAmount = streamReadBool(streamId)
    self.amount = streamReadInt8(streamId) / 100

    self:run(connection)
end

function EasyDevControlsVehicleConditionEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.vehicle)

    streamWriteBool(streamId, self.isEntered)
    streamWriteUIntN(streamId, self.typeId, EasyDevControlsVehicleConditionEvent.SEND_NUM_BITS)

    streamWriteBool(streamId, self.setToAmount)
    streamWriteInt8(streamId, self.amount * 100)
end

function EasyDevControlsVehicleConditionEvent:run(connection)
    if g_easyDevControls ~= nil then
        if not connection:getIsServer() then
            local message = g_easyDevControls:setVehicleCondition(self.vehicle, self.isEntered, self.typeId, self.setToAmount, self.amount)

            -- Only for 'setToAmount' so the log is no full of prints
            if g_dedicatedServer ~= nil and self.setToAmount and message ~= nil then
                Logging.info(message)
            end
        else
            print("Error: EasyDevControlsVehicleConditionEvent is a client to server only event")
        end
    end
end
