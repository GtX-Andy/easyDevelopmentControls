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

EasyDevControlsSetFillUnitFillLevel = {}

local EasyDevControlsSetFillUnitFillLevel_mt = Class(EasyDevControlsSetFillUnitFillLevel, Event)
InitEventClass(EasyDevControlsSetFillUnitFillLevel, "EasyDevControlsSetFillUnitFillLevel")

function EasyDevControlsSetFillUnitFillLevel.emptyNew()
    local self = Event.new(EasyDevControlsSetFillUnitFillLevel_mt)

    return self
end

function EasyDevControlsSetFillUnitFillLevel.new(vehicle, fillUnitIndex, fillTypeIndex, amount, ignoreRemoveIfEmpty)
    local self = EasyDevControlsSetFillUnitFillLevel.emptyNew()

    self.vehicle = vehicle

    self.fillUnitIndex = fillUnitIndex
    self.fillTypeIndex = fillTypeIndex

    self.amount = amount
    self.ignoreRemoveIfEmpty = ignoreRemoveIfEmpty

    return self
end

function EasyDevControlsSetFillUnitFillLevel:readStream(streamId, connection)
    self.vehicle = NetworkUtil.readNodeObject(streamId)

    self.fillUnitIndex = streamReadUInt8(streamId)
    self.fillTypeIndex = streamReadUIntN(streamId, FillTypeManager.SEND_NUM_BITS)

    self.amount = streamReadFloat32(streamId)
    self.ignoreRemoveIfEmpty = streamReadBool(streamId)

    self:run(connection)
end

function EasyDevControlsSetFillUnitFillLevel:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.vehicle)

    streamWriteUInt8(streamId, self.fillUnitIndex)
    streamWriteUIntN(streamId, self.fillTypeIndex, FillTypeManager.SEND_NUM_BITS)

    streamWriteFloat32(streamId, self.amount)
    streamWriteBool(streamId, self.ignoreRemoveIfEmpty)
end

function EasyDevControlsSetFillUnitFillLevel:run(connection)
    if g_easyDevControls ~= nil then
        if not connection:getIsServer() then
            local message = g_easyDevControls:setFillUnitFillLevel(self.vehicle, self.fillUnitIndex, self.fillTypeIndex, self.amount, self.ignoreRemoveIfEmpty)

            if g_dedicatedServer ~= nil and message ~= nil then
                Logging.info(message)
            end
        else
            print("Error: EasyDevControlsSetFillUnitFillLevel is a client to server only event!")
        end
    end
end