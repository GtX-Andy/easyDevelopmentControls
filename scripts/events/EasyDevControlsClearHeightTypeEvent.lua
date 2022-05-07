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

EasyDevControlsClearHeightTypeEvent = {}

EasyDevControlsClearHeightTypeEvent.TYPE_NONE = 0
EasyDevControlsClearHeightTypeEvent.TYPE_AREA = 1
EasyDevControlsClearHeightTypeEvent.TYPE_FIELD = 2
EasyDevControlsClearHeightTypeEvent.TYPE_MAP = 3
EasyDevControlsClearHeightTypeEvent.TYPE_FIELDS = 4

EasyDevControlsClearHeightTypeEvent.SEND_NUM_BITS = 3
EasyDevControlsClearHeightTypeEvent.SEND_NUM_BITS_FIELDS = 14

local EasyDevControlsClearHeightTypeEvent_mt = Class(EasyDevControlsClearHeightTypeEvent, Event)
InitEventClass(EasyDevControlsClearHeightTypeEvent, "EasyDevControlsClearHeightTypeEvent")

function EasyDevControlsClearHeightTypeEvent.emptyNew()
    local self = Event.new(EasyDevControlsClearHeightTypeEvent_mt)

    return self
end

function EasyDevControlsClearHeightTypeEvent.new(typeId, fillTypeIndex, x, z, radius)
    local self = EasyDevControlsClearHeightTypeEvent.emptyNew()

    self.typeId = typeId or EasyDevControlsClearHeightTypeEvent.TYPE_NONE

    self.fillTypeIndex = fillTypeIndex

    self.x = x
    self.z = z

    self.radius = radius

    return self
end

function EasyDevControlsClearHeightTypeEvent:readStream(streamId, connection)
    self.typeId = streamReadUIntN(streamId, EasyDevControlsClearHeightTypeEvent.SEND_NUM_BITS)

    if streamReadBool(streamId) then
        self.fillTypeIndex = streamReadUIntN(streamId, FillTypeManager.SEND_NUM_BITS)
    end

    if self.typeId == EasyDevControlsClearHeightTypeEvent.TYPE_AREA then
        self.x = streamReadFloat32(streamId)
        self.z = streamReadFloat32(streamId)

        self.radius = streamReadUInt8(streamId)
    elseif self.typeId == EasyDevControlsClearHeightTypeEvent.TYPE_FIELD then
        self.x = streamReadUIntN(streamId, EasyDevControlsClearHeightTypeEvent.SEND_NUM_BITS_FIELDS)
    end

    self:run(connection)
end

function EasyDevControlsClearHeightTypeEvent:writeStream(streamId, connection)
    streamWriteUIntN(streamId, self.typeId, EasyDevControlsClearHeightTypeEvent.SEND_NUM_BITS)

    if streamWriteBool(streamId, self.fillTypeIndex ~= nil and self.fillTypeIndex ~= FillType.UNKNOWN) then
        streamWriteUIntN(streamId, self.fillTypeIndex, FillTypeManager.SEND_NUM_BITS)
    end

    if self.typeId == EasyDevControlsClearHeightTypeEvent.TYPE_AREA then
        streamWriteFloat32(streamId, self.x)
        streamWriteFloat32(streamId, self.z)

        streamWriteUInt8(streamId, self.radius)
    elseif self.typeId == EasyDevControlsClearHeightTypeEvent.TYPE_FIELD then
        streamWriteUIntN(streamId, self.x, EasyDevControlsClearHeightTypeEvent.SEND_NUM_BITS_FIELDS)
    end
end

function EasyDevControlsClearHeightTypeEvent:run(connection)
    if g_easyDevControls ~= nil then
        if not connection:getIsServer() then
            local player = g_currentMission:getPlayerByConnection(connection)

            if player ~= nil then
                local farmId = player.farmId

                if farmId ~= nil and farmId ~= FarmManager.SPECTATOR_FARM_ID then
                    local message = g_easyDevControls:clearHeightType(self.typeId, self.fillTypeIndex, self.x, self.z, self.radius, farmId)

                    if g_dedicatedServer ~= nil and message ~= nil then
                        Logging.info(message)
                    end
                else
                    Logging.info("Failed to clear area, invalid or no farm!")
                end

            end
        else
            print("  Error: EasyDevControlsClearHeightTypeEvent is a client to server only event!")
        end
    end
end
