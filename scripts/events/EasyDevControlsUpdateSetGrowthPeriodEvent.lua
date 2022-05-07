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

EasyDevControlsUpdateSetGrowthPeriodEvent = {}
EasyDevControlsUpdateSetGrowthPeriodEvent.PERIOD_SEND_NUM_BITS = 4

local EasyDevControlsUpdateSetGrowthPeriodEvent_mt = Class(EasyDevControlsUpdateSetGrowthPeriodEvent, Event)
InitEventClass(EasyDevControlsUpdateSetGrowthPeriodEvent, "EasyDevControlsUpdateSetGrowthPeriodEvent")

function EasyDevControlsUpdateSetGrowthPeriodEvent.emptyNew()
    local self = Event.new(EasyDevControlsUpdateSetGrowthPeriodEvent_mt)

    return self
end

function EasyDevControlsUpdateSetGrowthPeriodEvent.new(seasonal, period)
    local self = EasyDevControlsUpdateSetGrowthPeriodEvent.emptyNew()

    self.seasonal = seasonal
    self.period = period

    return self
end

function EasyDevControlsUpdateSetGrowthPeriodEvent:readStream(streamId, connection)
    self.seasonal = streamReadBool(streamId)

    if self.seasonal then
        self.period = streamReadUIntN(streamId, EasyDevControlsUpdateSetGrowthPeriodEvent.PERIOD_SEND_NUM_BITS)
    end

    self:run(connection)
end

function EasyDevControlsUpdateSetGrowthPeriodEvent:writeStream(streamId, connection)
    if streamWriteBool(streamId, self.seasonal) then
        streamWriteUIntN(streamId, self.period, EasyDevControlsUpdateSetGrowthPeriodEvent.PERIOD_SEND_NUM_BITS)
    end
end

function EasyDevControlsUpdateSetGrowthPeriodEvent:run(connection)
    if g_easyDevControls ~= nil then
        if not connection:getIsServer() then
            local message = g_easyDevControls:setGrowthPeriod(self.seasonal, self.period)

            if g_dedicatedServer ~= nil and message ~= nil then
                Logging.info(message)
            end
        else
            print("  Error: EasyDevControlsUpdateSetGrowthPeriodEvent is a client to server only event!")
        end
    end
end
