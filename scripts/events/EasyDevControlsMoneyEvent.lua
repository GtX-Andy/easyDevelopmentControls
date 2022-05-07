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

EasyDevControlsMoneyEvent = {}

EasyDevControlsMoneyEvent.TYPES = {
    ADDMONEY = 0,
    REMOVEMONEY = 1,
    SETMONEY = 2
}

local EasyDevControlsMoneyEvent_mt = Class(EasyDevControlsMoneyEvent, Event)
InitEventClass(EasyDevControlsMoneyEvent, "EasyDevControlsMoneyEvent")

function EasyDevControlsMoneyEvent.emptyNew()
    local self = Event.new(EasyDevControlsMoneyEvent_mt)

    return self
end

function EasyDevControlsMoneyEvent.new(amount, typeId)
    local self = EasyDevControlsMoneyEvent.emptyNew()

    self.amount = amount
    self.typeId = typeId

    return self
end

function EasyDevControlsMoneyEvent:readStream(streamId, connection)
    self.amount = streamReadInt32(streamId)
    self.typeId = streamReadUIntN(streamId, 2)

    self:run(connection)
end

function EasyDevControlsMoneyEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, self.amount)
    streamWriteUIntN(streamId, self.typeId, 2)
end

function EasyDevControlsMoneyEvent:run(connection)
    if g_easyDevControls ~= nil then
        if not connection:getIsServer() then
            local player = g_currentMission:getPlayerByConnection(connection)

            if player ~= nil then
                local farmId = player.farmId

                if farmId ~= nil and farmId ~= FarmManager.SPECTATOR_FARM_ID then
                    local message = g_easyDevControls:changeMoney(self.amount, self.typeId, farmId)

                    if g_dedicatedServer ~= nil and message ~= nil then
                        Logging.info(message .. " (" .. farmId .. ")")
                    end
                end
            end
        else
            print("  Error: EasyDevControlsMoneyEvent is a client to server only event!")
        end
    end
end
