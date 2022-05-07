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

EasyDevControlsDeleteObjectEvent = {}

EasyDevControlsDeleteObjectEvent.TYPE_TREE = 0
EasyDevControlsDeleteObjectEvent.TYPE_STUMP = 1
EasyDevControlsDeleteObjectEvent.TYPE_LOG = 2
EasyDevControlsDeleteObjectEvent.TYPE_BALE = 3

EasyDevControlsDeleteObjectEvent.SEND_NUM_BITS = 3

local EasyDevControlsDeleteObjectEvent_mt = Class(EasyDevControlsDeleteObjectEvent, Event)
InitEventClass(EasyDevControlsDeleteObjectEvent, "EasyDevControlsDeleteObjectEvent")

function EasyDevControlsDeleteObjectEvent.emptyNew()
    local self = Event.new(EasyDevControlsDeleteObjectEvent_mt)

    return self
end

function EasyDevControlsDeleteObjectEvent.new(typeId, object)
    local self = EasyDevControlsDeleteObjectEvent.emptyNew()

    self.typeId = typeId
    self.object = object

    return self
end

function EasyDevControlsDeleteObjectEvent:readStream(streamId, connection)
    self.typeId = streamReadUIntN(streamId, EasyDevControlsDeleteObjectEvent.SEND_NUM_BITS)

    if self.typeId == EasyDevControlsDeleteObjectEvent.TYPE_BALE then
        self.object = NetworkUtil.readNodeObject(streamId)
    else
        self.object = readSplitShapeIdFromStream(streamId)
    end

    self:run(connection)
end

function EasyDevControlsDeleteObjectEvent:writeStream(streamId, connection)
    streamWriteUIntN(streamId, self.typeId, EasyDevControlsDeleteObjectEvent.SEND_NUM_BITS)

    if self.typeId == EasyDevControlsDeleteObjectEvent.TYPE_BALE then
        NetworkUtil.writeNodeObject(streamId, self.object)
    else
        writeSplitShapeIdToStream(streamId, self.object)
    end
end

function EasyDevControlsDeleteObjectEvent:run(connection)
    if g_easyDevControls ~= nil and (self.object ~= nil and self.typeId ~= nil) then
        if not connection:getIsServer() then
            if self.typeId == EasyDevControlsDeleteObjectEvent.TYPE_BALE then
                if self.object.nodeId ~= nil and entityExists(self.object.nodeId) then
                    self.object:delete()
                end
            elseif self.object ~= 0 then
                EasyDevUtils.deleteTree(self.object, self.typeId == EasyDevControlsDeleteObjectEvent.TYPE_TREE)
            end
        else
            print("  Error: EasyDevControlsDeleteObjectEvent is a client to server only event!")
        end
    end
end
