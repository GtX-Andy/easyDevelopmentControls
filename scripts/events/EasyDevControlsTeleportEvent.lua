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

EasyDevControlsTeleportEvent = {}

local EasyDevControlsTeleportEvent_mt = Class(EasyDevControlsTeleportEvent, Event)
InitEventClass(EasyDevControlsTeleportEvent, "EasyDevControlsTeleportEvent")

function EasyDevControlsTeleportEvent.emptyNew()
    local self = Event.new(EasyDevControlsTeleportEvent_mt)

    return self
end

function EasyDevControlsTeleportEvent.new(object, positionX, positionZ, rotationY)
    local self = EasyDevControlsTeleportEvent.emptyNew()

    self.object = object

    self.positionX = positionX
    self.positionZ = positionZ

    self.rotationY = rotationY

    return self
end

function EasyDevControlsTeleportEvent:readStream(streamId, connection)
    self.object = NetworkUtil.readNodeObject(streamId)

    self.positionX = streamReadFloat32(streamId)

    if streamReadBool(streamId) then
        self.positionZ = streamReadFloat32(streamId)
    end

    if streamReadBool(streamId) then
        self.rotationY = streamReadFloat32(streamId)
    end

    self:run(connection)
end

function EasyDevControlsTeleportEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.object)

    streamWriteFloat32(streamId, self.positionX)

    if streamWriteBool(streamId, self.positionZ ~= nil) then
        streamWriteFloat32(streamId, self.positionZ)
    end

    if streamWriteBool(streamId, self.rotationY ~= nil) then
        streamWriteFloat32(streamId, self.rotationY)
    end
end

function EasyDevControlsTeleportEvent:run(connection)
    if g_easyDevControls ~= nil then
        if not connection:getIsServer() then
            local message = g_easyDevControls:teleport(self.object, self.positionX, self.positionZ, self.rotationY)

            if g_dedicatedServer ~= nil and message ~= nil then
                Logging.info(message)
            end
        else
            print("Error: EasyDevControlsTeleportEvent is a client to server only event")
        end
    end
end
