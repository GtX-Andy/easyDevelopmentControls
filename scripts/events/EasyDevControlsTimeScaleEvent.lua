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

EasyDevControlsTimeScaleEvent = {}

local EasyDevControlsTimeScaleEvent_mt = Class(EasyDevControlsTimeScaleEvent, Event)
InitEventClass(EasyDevControlsTimeScaleEvent, "EasyDevControlsTimeScaleEvent")

function EasyDevControlsTimeScaleEvent.emptyNew()
    local self = Event.new(EasyDevControlsTimeScaleEvent_mt)

    return self
end

function EasyDevControlsTimeScaleEvent.new(active)
    local self = EasyDevControlsTimeScaleEvent.emptyNew()

    self.active = active

    return self
end

function EasyDevControlsTimeScaleEvent:readStream(streamId, connection)
    self.active = streamReadBool(streamId)

    self:run(connection)
end

function EasyDevControlsTimeScaleEvent:writeStream(streamId, connection)
    streamWriteBool(streamId, self.active)
end

function EasyDevControlsTimeScaleEvent:run(connection)
    if g_easyDevControls ~= nil then
        local message = g_easyDevControls:setCustomTimeScaleState(self.active)

        if g_dedicatedServer ~= nil and message ~= nil then
            Logging.info(message)
        end
    end
end
