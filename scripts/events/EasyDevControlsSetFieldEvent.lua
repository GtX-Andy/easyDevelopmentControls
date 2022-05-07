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

EasyDevControlsSetFieldEvent = {}

EasyDevControlsSetFieldEvent.FIELD_SEND_NUM_BITS = 14

local EasyDevControlsSetFieldEvent_mt = Class(EasyDevControlsSetFieldEvent, Event)
InitEventClass(EasyDevControlsSetFieldEvent, "EasyDevControlsSetFieldEvent")

function EasyDevControlsSetFieldEvent.emptyNew()
    return Event.new(EasyDevControlsSetFieldEvent_mt)
end

function EasyDevControlsSetFieldEvent.new(setFruit, fieldIndex, variable1, variable2, variable3, groundLayer, fertilizerState, plowingState, limeState, stubbleState, weedState, herbicideState, rollerState, stonesState, buyFarmland)
    local self = EasyDevControlsSetFieldEvent.emptyNew()

    self.setFruit = setFruit
    self.fieldIndex = fieldIndex

    if setFruit then
        self.fruitIndex = variable1
        self.growthState = variable2
        self.removeFoliage = variable3 -- Not used
    else
        self.groundTypeValue = variable1
        self.angleValue = variable2
        self.removeFoliage = variable3
    end

    self.groundLayer = groundLayer
    self.fertilizerState = fertilizerState
    self.plowingState = plowingState
    self.limeState = limeState
    self.stubbleState = stubbleState
    self.weedState = weedState
    self.herbicideState = herbicideState
    self.rollerState = rollerState
    self.stonesState = stonesState

    self.buyFarmland = buyFarmland

    return self
end

function EasyDevControlsSetFieldEvent:readStream(streamId, connection)
    self.setFruit = streamReadBool(streamId)
    self.fieldIndex = streamReadUIntN(streamId, EasyDevControlsSetFieldEvent.FIELD_SEND_NUM_BITS)

	if self.setFruit then
		self.fruitIndex = streamReadUIntN(streamId, FruitTypeManager.SEND_NUM_BITS)
        self.growthState = streamReadUInt8(streamId)
    else
        self.groundTypeValue = streamReadUInt8(streamId)
        self.angleValue = streamReadUInt8(streamId)
        self.removeFoliage = streamReadBool(streamId)
    end

    self.groundLayer = streamReadUInt8(streamId)
    self.fertilizerState = streamReadUInt8(streamId)
    self.plowingState = streamReadUInt8(streamId)
    self.limeState = streamReadUInt8(streamId)
    self.stubbleState = streamReadUInt8(streamId)
    self.weedState = streamReadUInt8(streamId)
    self.herbicideState = streamReadUInt8(streamId)
    self.rollerState = streamReadUInt8(streamId)
    self.stonesState = streamReadUInt8(streamId)

    self.buyFarmland = streamReadBool(streamId)

    self:run(connection)
end

function EasyDevControlsSetFieldEvent:writeStream(streamId, connection)
    streamWriteBool(streamId, self.setFruit)
    streamWriteUIntN(streamId, self.fieldIndex, EasyDevControlsSetFieldEvent.FIELD_SEND_NUM_BITS)

    if self.setFruit then
        streamWriteUIntN(streamId, self.fruitIndex, FruitTypeManager.SEND_NUM_BITS)
        streamWriteUInt8(streamId, self.growthState)
    else
        streamWriteUInt8(streamId, self.groundTypeValue)
        streamWriteUInt8(streamId, self.angleValue)
        streamWriteBool(streamId, self.removeFoliage)
    end

    streamWriteUInt8(streamId, self.groundLayer)
    streamWriteUInt8(streamId, self.fertilizerState)
    streamWriteUInt8(streamId, self.plowingState)
    streamWriteUInt8(streamId, self.limeState)
    streamWriteUInt8(streamId, self.stubbleState)
    streamWriteUInt8(streamId, self.weedState)
    streamWriteUInt8(streamId, self.herbicideState)
    streamWriteUInt8(streamId, self.rollerState)
    streamWriteUInt8(streamId, self.stonesState)

    streamWriteBool(streamId, self.buyFarmland)
end

function EasyDevControlsSetFieldEvent:run(connection)
    if g_easyDevControls ~= nil then
        if not connection:getIsServer() then
            local player = g_currentMission:getPlayerByConnection(connection)

            if player ~= nil then
                local farmId = player.farmId

                if farmId ~= nil and farmId ~= FarmManager.SPECTATOR_FARM_ID then
                    local message

                    if self.setFruit then
                        message = g_easyDevControls:setFieldFruit(self.fieldIndex, self.fruitIndex, self.growthState, self.groundLayer, self.fertilizerState, self.plowingState, self.limeState, self.stubbleState, self.weedState, self.herbicideState, self.rollerState, self.stonesState, self.buyFarmland, farmId)
                    else
                        message = g_easyDevControls:setFieldGround(self.fieldIndex, self.groundTypeValue, self.angleValue, self.removeFoliage, self.groundLayer, self.fertilizerState, self.plowingState, self.limeState, self.stubbleState, self.weedState, self.herbicideState, self.rollerState, self.stonesState, self.buyFarmland, farmId)
                    end

                    if g_dedicatedServer ~= nil and message ~= nil then
                        Logging.info(message .. " (" .. farmId .. ") (" .. tostring(self.setFruit) .. ")")
                    end
                end
            end
        else
            print("Error: EasyDevControlsSetFieldEvent is a client to server only event")
        end
    end
end
