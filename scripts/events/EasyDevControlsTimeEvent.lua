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

EasyDevControlsTimeEvent = {}

local EasyDevControlsTimeEvent_mt = Class(EasyDevControlsTimeEvent, Event)
InitEventClass(EasyDevControlsTimeEvent, "EasyDevControlsTimeEvent")

function EasyDevControlsTimeEvent.emptyNew()
    local self = Event.new(EasyDevControlsTimeEvent_mt)

    return self
end

function EasyDevControlsTimeEvent.new(hourToSet, daysToAdvance)
    local self = EasyDevControlsTimeEvent.emptyNew()

    self.hourToSet = hourToSet
    self.daysToAdvance = daysToAdvance

    return self
end

function EasyDevControlsTimeEvent:readStream(streamId, connection)
    self.hourToSet = streamReadUIntN(streamId, 5)
    self.daysToAdvance = streamReadUIntN(streamId, 9)

    self:run(connection)
end

function EasyDevControlsTimeEvent:writeStream(streamId, connection)
    streamWriteUIntN(streamId, self.hourToSet, 5)
    streamWriteUIntN(streamId, self.daysToAdvance, 9)
end

function EasyDevControlsTimeEvent:run(connection)
    if g_easyDevControls ~= nil then
        if not connection:getIsServer() then
            local message = g_easyDevControls:setCurrentTime(self.hourToSet, self.daysToAdvance)

            if g_dedicatedServer ~= nil and message ~= nil then
                Logging.info(message)
            end
        else
            print("Error: EasyDevControlsTimeEvent is a client to server only event")
        end
    end
end
