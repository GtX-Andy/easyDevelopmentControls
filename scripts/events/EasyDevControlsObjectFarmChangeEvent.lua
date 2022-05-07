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

EasyDevControlsObjectFarmChangeEvent = {}
local EasyDevControlsObjectFarmChangeEvent_mt = Class(EasyDevControlsObjectFarmChangeEvent, Event)

InitEventClass(EasyDevControlsObjectFarmChangeEvent, "EasyDevControlsObjectFarmChangeEvent")

function EasyDevControlsObjectFarmChangeEvent.emptyNew()
    local self = Event.new(EasyDevControlsObjectFarmChangeEvent_mt)

    return self
end

function EasyDevControlsObjectFarmChangeEvent.new(object, farmId)
    local self = EasyDevControlsObjectFarmChangeEvent.emptyNew()

    self.object = object
    self.farmId = farmId

    return self
end

function EasyDevControlsObjectFarmChangeEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.object)
    streamWriteUIntN(streamId, self.farmId, FarmManager.FARM_ID_SEND_NUM_BITS)
end

function EasyDevControlsObjectFarmChangeEvent:readStream(streamId, connection)
    self.object = NetworkUtil.readNodeObject(streamId)
    self.farmId = streamReadUIntN(streamId, FarmManager.FARM_ID_SEND_NUM_BITS)

    self:run(connection)
end

function EasyDevControlsObjectFarmChangeEvent:run(connection)
    if not connection:getIsServer() then
        if self.object ~= nil and self.farmId ~= nil then
            self.object:setOwnerFarmId(self.farmId)
        end
    end
end
