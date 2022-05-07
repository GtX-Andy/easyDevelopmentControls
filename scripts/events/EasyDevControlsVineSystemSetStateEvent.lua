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

EasyDevControlsVineSystemSetStateEvent = {}

local EasyDevControlsVineSystemSetStateEvent_mt = Class(EasyDevControlsVineSystemSetStateEvent, Event)
InitEventClass(EasyDevControlsVineSystemSetStateEvent, "EasyDevControlsVineSystemSetStateEvent")

function EasyDevControlsVineSystemSetStateEvent.emptyNew()
    local self = Event.new(EasyDevControlsVineSystemSetStateEvent_mt)

    return self
end

function EasyDevControlsVineSystemSetStateEvent.new(placeableVine, fruitTypeIndex, growthState)
    local self = EasyDevControlsVineSystemSetStateEvent.emptyNew()

    self.placeableVine = placeableVine
    self.fruitTypeIndex = fruitTypeIndex
    self.growthState = growthState

    return self
end

function EasyDevControlsVineSystemSetStateEvent:readStream(streamId, connection)
    if streamReadBool(streamId) then
        self.placeableVine = NetworkUtil.readNodeObject(streamId)
    end

    self.fruitTypeIndex = streamReadUIntN(streamId, FruitTypeManager.SEND_NUM_BITS)
    self.growthState = streamReadUInt8(streamId)

    self:run(connection)
end

function EasyDevControlsVineSystemSetStateEvent:writeStream(streamId, connection)
    if streamWriteBool(streamId, self.placeableVine ~= nil) then
        NetworkUtil.writeNodeObject(streamId, self.placeableVine)
    end

    streamWriteUIntN(streamId, self.fruitTypeIndex, FruitTypeManager.SEND_NUM_BITS)
    streamWriteUInt8(streamId, self.growthState)
end

function EasyDevControlsVineSystemSetStateEvent:run(connection)
    if g_easyDevControls ~= nil then
        if not connection:getIsServer() then
            local player = g_currentMission:getPlayerByConnection(connection)

            if player ~= nil then
                local farmId = player.farmId

                if farmId ~= nil and farmId ~= FarmManager.SPECTATOR_FARM_ID then
                    local message = g_easyDevControls:vineSystemSetState(self.placeableVine, self.fruitTypeIndex, self.growthState, farmId)

                    if g_dedicatedServer ~= nil and message ~= nil then
                        Logging.info(message .. " (" .. farmId .. ")")
                    end
                end
            end
        else
            print("  Error: EasyDevControlsVineSystemSetStateEvent is a client to server only event!")
        end
    end
end
