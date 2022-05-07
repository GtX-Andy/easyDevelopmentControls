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

EasyDevControlsSuperStrengthEvent = {}

local EasyDevControlsSuperStrengthEvent_mt = Class(EasyDevControlsSuperStrengthEvent, Event)
InitEventClass(EasyDevControlsSuperStrengthEvent, "EasyDevControlsSuperStrengthEvent")

function EasyDevControlsSuperStrengthEvent.emptyNew()
    local self = Event.new(EasyDevControlsSuperStrengthEvent_mt)

    return self
end

function EasyDevControlsSuperStrengthEvent.new(active, userId)
    local self = EasyDevControlsSuperStrengthEvent.emptyNew()

    self.active = active
    self.userId = userId

    return self
end

function EasyDevControlsSuperStrengthEvent:readStream(streamId, connection)
    self.active = streamReadBool(streamId)

    if streamReadBool(streamId) then
        self.userId = streamReadInt32(streamId)
    end

    self:run(connection)
end

function EasyDevControlsSuperStrengthEvent:writeStream(streamId, connection)
    streamWriteBool(streamId, self.active)

    if streamWriteBool(streamId, self.userId ~= nil) then
        streamWriteInt32(streamId, self.userId)
    end
end

function EasyDevControlsSuperStrengthEvent:run(connection)
    if g_easyDevControls ~= nil then
        if not connection:getIsServer() then
            self.userId = g_currentMission.userManager:getUserIdByConnection(connection)
            g_server:broadcastEvent(EasyDevControlsSuperStrengthEvent.new(self.active, self.userId))
        end

        local message = g_easyDevControls:setSuperStrengthPlayerValues(self.active, self.userId)

        if g_dedicatedServer ~= nil and message ~= nil then
            Logging.info(message)
        end
    end
end

