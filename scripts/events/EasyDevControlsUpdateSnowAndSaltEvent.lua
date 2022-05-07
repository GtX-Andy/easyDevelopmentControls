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

EasyDevControlsUpdateSnowAndSaltEvent = {}

EasyDevControlsUpdateSnowAndSaltEvent.SEND_NUM_BITS = 2

EasyDevControlsUpdateSnowAndSaltEvent.SET_SNOW = 0
EasyDevControlsUpdateSnowAndSaltEvent.ADD_SNOW = 1
EasyDevControlsUpdateSnowAndSaltEvent.REMOVE_SNOW = 2
EasyDevControlsUpdateSnowAndSaltEvent.ADD_SALT = 3

local EasyDevControlsUpdateSnowAndSaltEvent_mt = Class(EasyDevControlsUpdateSnowAndSaltEvent, Event)
InitEventClass(EasyDevControlsUpdateSnowAndSaltEvent, "EasyDevControlsUpdateSnowAndSaltEvent")

function EasyDevControlsUpdateSnowAndSaltEvent.emptyNew()
    local self = Event.new(EasyDevControlsUpdateSnowAndSaltEvent_mt)

    return self
end

function EasyDevControlsUpdateSnowAndSaltEvent.new(typeId, value)
    local self = EasyDevControlsUpdateSnowAndSaltEvent.emptyNew()

    self.typeId = typeId
    self.value = value

    return self
end

function EasyDevControlsUpdateSnowAndSaltEvent:readStream(streamId, connection)
    self.typeId = streamReadUIntN(streamId, EasyDevControlsUpdateSnowAndSaltEvent.SEND_NUM_BITS)

    if streamReadBool(streamId) then
        self.value = streamReadFloat32(streamId)
    end

    self:run(connection)
end

function EasyDevControlsUpdateSnowAndSaltEvent:writeStream(streamId, connection)
    streamWriteUIntN(streamId, self.typeId, EasyDevControlsUpdateSnowAndSaltEvent.SEND_NUM_BITS)

    if streamWriteBool(streamId, EasyDevControlsUpdateSnowAndSaltEvent.requiresValue(self.typeId) and self.value ~= nil) then
        streamWriteFloat32(streamId, self.value)
    end
end

function EasyDevControlsUpdateSnowAndSaltEvent:run(connection)
    if g_easyDevControls ~= nil then
        if not connection:getIsServer() then
            local message = g_easyDevControls:updateSnowAndSalt(self.typeId, self.value)

            if g_dedicatedServer ~= nil and message ~= nil then
                Logging.info(message)
            end
        else
            print("  Error: EasyDevControlsUpdateSnowAndSaltEvent is a client to server only event!")
        end
    end
end

function EasyDevControlsUpdateSnowAndSaltEvent.requiresValue(typeId)
    if typeId == EasyDevControlsUpdateSnowAndSaltEvent.SET_SNOW or typeId == EasyDevControlsUpdateSnowAndSaltEvent.ADD_SALT then
        return true
    end

    return false
end
