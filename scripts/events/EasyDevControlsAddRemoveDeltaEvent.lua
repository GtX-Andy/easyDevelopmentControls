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

EasyDevControlsAddRemoveDeltaEvent = {}
EasyDevControlsAddRemoveDeltaEvent.FIELD_SEND_NUM_BITS = 14

local EasyDevControlsAddRemoveDeltaEvent_mt = Class(EasyDevControlsAddRemoveDeltaEvent, Event)
InitEventClass(EasyDevControlsAddRemoveDeltaEvent, "EasyDevControlsAddRemoveDeltaEvent")

function EasyDevControlsAddRemoveDeltaEvent.emptyNew()
    local self = Event.new(EasyDevControlsAddRemoveDeltaEvent_mt)

    return self
end

function EasyDevControlsAddRemoveDeltaEvent.new(isWeedSystem, fieldIndex, delta)
    local self = EasyDevControlsAddRemoveDeltaEvent.emptyNew()

    self.isWeedSystem = isWeedSystem

    self.fieldIndex = fieldIndex
    self.delta = delta

    return self
end

function EasyDevControlsAddRemoveDeltaEvent:readStream(streamId, connection)
    self.isWeedSystem = streamReadBool(streamId)

    self.fieldIndex = streamReadUIntN(streamId, EasyDevControlsAddRemoveDeltaEvent.FIELD_SEND_NUM_BITS)
    self.delta = streamReadInt8(streamId)

    self:run(connection)
end

function EasyDevControlsAddRemoveDeltaEvent:writeStream(streamId, connection)
    streamWriteBool(streamId, self.isWeedSystem)

    streamWriteUIntN(streamId, self.fieldIndex, EasyDevControlsAddRemoveDeltaEvent.FIELD_SEND_NUM_BITS)
    streamWriteInt8(streamId, self.delta)
end

function EasyDevControlsAddRemoveDeltaEvent:run(connection)
    if g_easyDevControls ~= nil then
        if not connection:getIsServer() then
            local message

            if self.isWeedSystem then
                message = g_easyDevControls:addRemoveWeedsDelta(self.fieldIndex, self.delta)
            else
                message = g_easyDevControls:addRemoveStonesDelta(self.fieldIndex, self.delta)
            end

            if g_dedicatedServer ~= nil and message ~= nil then
                Logging.info(message)
            end
        else
            print("  Error: EasyDevControlsAddRemoveDeltaEvent is a client to server only event!")
        end
    end
end
