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

EasyDevControlsRemoveAllObjectsEvent = {}

EasyDevControlsRemoveAllObjectsEvent.VEHICLES = 0
EasyDevControlsRemoveAllObjectsEvent.PALLETS = 1
EasyDevControlsRemoveAllObjectsEvent.BALES = 2
EasyDevControlsRemoveAllObjectsEvent.LOGS = 3
EasyDevControlsRemoveAllObjectsEvent.STUMPS = 4
EasyDevControlsRemoveAllObjectsEvent.PLACEABLES = 5
EasyDevControlsRemoveAllObjectsEvent.MAP_PLACEABLES = 6

EasyDevControlsRemoveAllObjectsEvent.SEND_NUM_BITS = 3

local EasyDevControlsRemoveAllObjectsEvent_mt = Class(EasyDevControlsRemoveAllObjectsEvent, Event)
InitEventClass(EasyDevControlsRemoveAllObjectsEvent, "EasyDevControlsRemoveAllObjectsEvent")

function EasyDevControlsRemoveAllObjectsEvent.emptyNew()
    local self = Event.new(EasyDevControlsRemoveAllObjectsEvent_mt)

    return self
end

function EasyDevControlsRemoveAllObjectsEvent.new(typeId)
    local self = EasyDevControlsRemoveAllObjectsEvent.emptyNew()

    self.typeId = typeId

    return self
end

function EasyDevControlsRemoveAllObjectsEvent:readStream(streamId, connection)
    self.typeId = streamReadUIntN(streamId, EasyDevControlsRemoveAllObjectsEvent.SEND_NUM_BITS)
    self:run(connection)
end

function EasyDevControlsRemoveAllObjectsEvent:writeStream(streamId, connection)
    streamWriteUIntN(streamId, self.typeId, EasyDevControlsRemoveAllObjectsEvent.SEND_NUM_BITS)
end

function EasyDevControlsRemoveAllObjectsEvent:run(connection)
    if g_easyDevControls ~= nil then
        if not connection:getIsServer() then
            local message = g_easyDevControls:removeAllObjects(self.typeId)

            if g_dedicatedServer ~= nil and message ~= nil then
                Logging.info(message)
            end
        else
            print("  Error: EasyDevControlsRemoveAllObjectsEvent is a client to server only event!")
        end
    end
end

function EasyDevControlsRemoveAllObjectsEvent.typeToRemove(typeId)
    return typeId == EasyDevControlsRemoveAllObjectsEvent.VEHICLES,
           typeId == EasyDevControlsRemoveAllObjectsEvent.PALLETS,
           typeId == EasyDevControlsRemoveAllObjectsEvent.BALES,
           typeId == EasyDevControlsRemoveAllObjectsEvent.LOGS,
           typeId == EasyDevControlsRemoveAllObjectsEvent.STUMPS,
           typeId == EasyDevControlsRemoveAllObjectsEvent.PLACEABLES,
           typeId == EasyDevControlsRemoveAllObjectsEvent.MAP_PLACEABLES
end
