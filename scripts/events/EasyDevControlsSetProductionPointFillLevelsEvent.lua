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

EasyDevControlsSetProductionPointFillLevelsEvent = {}

local EasyDevControlsSetProductionPointFillLevelsEvent_mt = Class(EasyDevControlsSetProductionPointFillLevelsEvent, Event)
InitEventClass(EasyDevControlsSetProductionPointFillLevelsEvent, "EasyDevControlsSetProductionPointFillLevelsEvent")

function EasyDevControlsSetProductionPointFillLevelsEvent.emptyNew()
    local self = Event.new(EasyDevControlsSetProductionPointFillLevelsEvent_mt)

    return self
end

function EasyDevControlsSetProductionPointFillLevelsEvent.new(productionPoint, fillLevel, fillTypeIndex, isOutput)
    local self = EasyDevControlsSetProductionPointFillLevelsEvent.emptyNew()

    self.productionPoint = productionPoint
    self.fillLevel = fillLevel

    self.fillTypeIndex = fillTypeIndex
    self.isOutput = isOutput

    return self
end

function EasyDevControlsSetProductionPointFillLevelsEvent:readStream(streamId, connection)
    self.productionPoint = NetworkUtil.readNodeObject(streamId)

    self.fillLevel = streamReadFloat32(streamId)
    self.fillTypeIndex = nil

    if streamReadBool(streamId) then
        self.fillTypeIndex = streamReadUIntN(streamId, FillTypeManager.SEND_NUM_BITS)
    end

    self.isOutput = streamReadBool(streamId)

    self:run(connection)
end

function EasyDevControlsSetProductionPointFillLevelsEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.productionPoint)

    streamWriteFloat32(streamId, self.fillLevel)

    if streamWriteBool(streamId, self.fillTypeIndex ~= nil) then
        streamWriteUIntN(streamId, self.fillTypeIndex, FillTypeManager.SEND_NUM_BITS)
    end

    streamWriteBool(streamId, self.isOutput)
end

function EasyDevControlsSetProductionPointFillLevelsEvent:run(connection)
    if g_easyDevControls ~= nil then
        if not connection:getIsServer() then
            local message = g_easyDevControls:setProductionPointFillLevels(self.productionPoint, self.fillLevel, self.fillTypeIndex, self.isOutput, false)

            if g_dedicatedServer ~= nil and message ~= nil then
                Logging.info(message)
            end
        else
            print("Error: EasyDevControlsSetProductionPointFillLevelsEvent is a client to server only event!")
        end
    end
end