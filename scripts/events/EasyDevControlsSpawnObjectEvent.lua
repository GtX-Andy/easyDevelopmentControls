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

EasyDevControlsSpawnObjectEvent = {}

EasyDevControlsSpawnObjectEvent.TYPE_NONE = 0
EasyDevControlsSpawnObjectEvent.TYPE_BALE = 1
EasyDevControlsSpawnObjectEvent.TYPE_PALLET = 2
EasyDevControlsSpawnObjectEvent.TYPE_LOG = 3

EasyDevControlsSpawnObjectEvent.SEND_NUM_BITS = 2

local EasyDevControlsSpawnObjectEvent_mt = Class(EasyDevControlsSpawnObjectEvent, Event)
InitEventClass(EasyDevControlsSpawnObjectEvent, "EasyDevControlsSpawnObjectEvent")

function EasyDevControlsSpawnObjectEvent.emptyNew()
    local self = Event.new(EasyDevControlsSpawnObjectEvent_mt)

    return self
end

function EasyDevControlsSpawnObjectEvent.new(typeId, params)
    local self = EasyDevControlsSpawnObjectEvent.emptyNew()

    self.typeId = typeId or EasyDevControlsSpawnObjectEvent.TYPE_NONE

    if self.typeId == EasyDevControlsSpawnObjectEvent.TYPE_BALE then
        self.baleIndex = params.baleIndex
        self.fillTypeIndex = params.fillTypeIndex
        self.wrappingState = params.wrappingState

        self.ry = params.ry
    elseif self.typeId == EasyDevControlsSpawnObjectEvent.TYPE_PALLET then
        self.xmlFilename = params.xmlFilename
        self.fillTypeIndex = params.fillTypeIndex
    elseif self.typeId == EasyDevControlsSpawnObjectEvent.TYPE_LOG then
        self.treeType = params.treeType

        self.length = params.length
        self.growthState = params.growthState

        self.rx = params.rx
        self.ry = params.ry
        self.rz = params.rz
    end

    self.x = params.x
    self.y = params.y
    self.z = params.z

    return self
end

function EasyDevControlsSpawnObjectEvent:readStream(streamId, connection)
    self.typeId = streamReadUIntN(streamId, EasyDevControlsSpawnObjectEvent.SEND_NUM_BITS)

    if self.typeId == EasyDevControlsSpawnObjectEvent.TYPE_BALE then
        self.baleIndex = streamReadUInt8(streamId)

        self.fillTypeIndex = streamReadUIntN(streamId, FillTypeManager.SEND_NUM_BITS)
        self.wrappingState = streamReadUInt8(streamId) / 255

        self.ry = streamReadFloat32(streamId)
    elseif self.typeId == EasyDevControlsSpawnObjectEvent.TYPE_PALLET then
        self.xmlFilename = NetworkUtil.convertFromNetworkFilename(streamReadString(streamId))
        self.fillTypeIndex = streamReadUIntN(streamId, FillTypeManager.SEND_NUM_BITS)
    elseif self.typeId == EasyDevControlsSpawnObjectEvent.TYPE_LOG then
        self.treeType = streamReadInt32(streamId)

        self.length = streamReadInt8(streamId)
        self.growthState = streamReadInt8(streamId)

        self.rx = streamReadFloat32(streamId)
        self.ry = streamReadFloat32(streamId)
        self.rz = streamReadFloat32(streamId)
    end

    self.x = streamReadFloat32(streamId)
    self.y = streamReadFloat32(streamId)
    self.z = streamReadFloat32(streamId)

    self:run(connection)
end

function EasyDevControlsSpawnObjectEvent:writeStream(streamId, connection)
    streamWriteUIntN(streamId, self.typeId, EasyDevControlsSpawnObjectEvent.SEND_NUM_BITS)

    if self.typeId == EasyDevControlsSpawnObjectEvent.TYPE_BALE then
        streamWriteUInt8(streamId, self.baleIndex)

        streamWriteUIntN(streamId, self.fillTypeIndex, FillTypeManager.SEND_NUM_BITS)
        streamWriteUInt8(streamId, EasyDevUtils.getNoNilClamp(self.wrappingState * 255, 0, 255, 0))

        streamWriteFloat32(streamId, self.ry)
    elseif self.typeId == EasyDevControlsSpawnObjectEvent.TYPE_PALLET then
        streamWriteString(streamId, NetworkUtil.convertToNetworkFilename(self.xmlFilename))
        streamWriteUIntN(streamId, self.fillTypeIndex, FillTypeManager.SEND_NUM_BITS)
    elseif self.typeId == EasyDevControlsSpawnObjectEvent.TYPE_LOG then
        streamWriteInt32(streamId, self.treeType)

        streamWriteInt8(streamId, self.length)
        streamWriteInt8(streamId, self.growthState)

        streamWriteFloat32(streamId, self.rx)
        streamWriteFloat32(streamId, self.ry)
        streamWriteFloat32(streamId, self.rz)
    end

    streamWriteFloat32(streamId, self.x)
    streamWriteFloat32(streamId, self.y)
    streamWriteFloat32(streamId, self.z)
end

function EasyDevControlsSpawnObjectEvent:run(connection)
    if g_easyDevControls ~= nil then
        if not connection:getIsServer() then
            local player = g_currentMission:getPlayerByConnection(connection)

            if player ~= nil then
                local farmId = player.farmId

                if farmId ~= nil and farmId ~= FarmManager.SPECTATOR_FARM_ID then
                    local message

                    if self.typeId == EasyDevControlsSpawnObjectEvent.TYPE_BALE then
                        message = g_easyDevControls:spawnBale(self.baleIndex, self.fillTypeIndex, self.wrappingState, farmId, self.x, self.y, self.z, self.ry)
                    elseif self.typeId == EasyDevControlsSpawnObjectEvent.TYPE_PALLET then
                        message = g_easyDevControls:spawnPallet(self.fillTypeIndex, self.xmlFilename, farmId, self.x, self.y, self.z)
                    elseif self.typeId == EasyDevControlsSpawnObjectEvent.TYPE_LOG then
                        message = g_easyDevControls:spawnLog(self.treeType, self.length, self.growthState, self.x, self.y, self.z, self.rx, self.ry, self.rz)
                    end

                    if g_dedicatedServer ~= nil and message ~= nil then
                        Logging.info(message)
                    end
                else
                    Logging.info("Failed to spawn object, invalid or no farm!")
                end

            end
        else
            print("  Error: EasyDevControlsSpawnObjectEvent is a client to server only event!")
        end
    end
end
