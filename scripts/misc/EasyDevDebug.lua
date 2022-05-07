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

----------------------
-- Production Debug --
----------------------

EasyDevDebugProduction = {}

local EasyDevDebugProduction_mt = Class(EasyDevDebugProduction)
local emptyTable = {}

function EasyDevDebugProduction.new()
    local self = setmetatable({}, EasyDevDebugProduction_mt)

    self.debugTexts = {}
    self.active = false

    return self
end

function EasyDevDebugProduction:setActive(active)
    if g_currentMission ~= nil then
        self.active = Utils.getNoNil(active, false)

        if g_currentMission.productionChainManager ~= nil then
            g_currentMission.productionChainManager.debugEnabled = false
        end

        if self.active then
            g_currentMission:addDrawable(self)
        else
            g_currentMission:removeDrawable(self)
            self.debugTexts = {}
        end
    end

    return self.active
end

function EasyDevDebugProduction:draw()
    if g_currentMission ~= nil and g_currentMission.productionChainManager ~= nil then
        for _, pp in pairs(g_currentMission.productionChainManager.productionPoints) do
            local playerNode = (pp.mission.controlledVehicle or emptyTable).rootNode or (pp.mission.player or emptyTable).rootNode

            local px, py, pz = getWorldTranslation(playerNode)
            local ppx, ppy, ppz = getWorldTranslation(pp.node)

            local distance = MathUtil.vector3Length(px - ppx, py - ppy, pz - ppz)

            if distance < 40 then
                local text = {}

                table.insert(text, string.format("PP %s (%s) | ownerFarmId: %s | isOwned: %s", pp:getName(), pp:tableId(), pp.ownerFarmId, pp.isOwned))

                for i = 1, #pp.productions do
                    local production = pp.productions[i]

                    table.insert(text, string.format("  prodId '%s': cyclesPerMinute: %.2f | enabled: %s", production.id, production.cyclesPerMinute, table.hasElement(pp.activeProductions, production)))

                    for n = 1, #production.inputs do
                        local input = production.inputs[n]

                        table.insert(text, string.format("    input: %s: %.2f", g_fillTypeManager:getFillTypeNameByIndex(input.type), input.amount))
                    end

                    for n = 1, #production.outputs do
                        local output = production.outputs[n]

                        table.insert(text, string.format("    output: %s: %.2f | directSell: %s | autoDeliver: %s", g_fillTypeManager:getFillTypeNameByIndex(output.type), output.amount, tostring(pp.outputFillTypeIdsDirectSell[output.type] == true), tostring(pp.outputFillTypeIdsAutoDeliver[output.type] == true)))
                    end
                end

                -- No client data
                if pp.isServer then
                    table.insert(text, string.format("productionCostsToClaim : %.1f", pp.productionCostsToClaim))
                    table.insert(text, string.format("waitingForPalletToSpawn: %s", pp.waitingForPalletToSpawn))

                    if g_time < pp.palletSpawnCooldown then
                        table.insert(text, string.format("palletSpawnCooldown: %.1f sec", (pp.palletSpawnCooldown - g_time) / 1000))
                    end
                end

                local debugText = self.debugTexts[pp]

                if debugText == nil then
                    local node = pp.node

                    if pp.interactionTriggerNode ~= nil then
                        node = pp.interactionTriggerNode
                    elseif pp.storage ~= nil then
                        node = pp.storage.rootNode
                    end

                    debugText = DebugText.new()

                    local x, y, z = getWorldTranslation(node)
                    -- local triggerMarkerSpec = pp.owningPlaceable.spec_triggerMarkers

                    y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 0, z)

                    if triggerMarkerSpec ~= nil then
                        local markerY, lastDistance = y, math.huge

                        for _, marker in ipairs(triggerMarkerSpec.triggerMarkers) do
                            local mx, my, mz = getWorldTranslation(marker.node)
                            local triggerDistance = MathUtil.vector3Length(x - mx, y - my, z - mz)

                            if triggerDistance < 5 and triggerDistance < lastDistance then
                                lastDistance = triggerDistance
                                markerY = my
                            end
                        end

                        y = math.max(y, markerY)
                    end

                    debugText:createWithWorldPosAndRot(x, y + 2, z, 0, 0, 0, "", 0.05)
                    debugText.alignment = RenderText.ALIGN_CENTER
                    debugText.alignToCamera = true

                    self.debugTexts[pp] = debugText
                end

                if pp.storage ~= nil then
                    local storage = pp.storage

                    table.insert(text, " ")

                    for fillType, accepted in pairs(storage.fillTypes) do
                        if accepted then
                            table.insert(text, string.format("%s : %.3f / %.3f", g_fillTypeManager:getFillTypeNameByIndex(fillType), storage.fillLevels[fillType] or 0, storage.capacities[fillType] or storage.capacity or -1))
                        end
                    end
                end

                debugText.text = table.concat(text, "\n")
                debugText.y = py + 0.8

                debugText:update()

                g_debugManager:addFrameElement(debugText)
            end
        end
    end
end

g_easyDevDebugProduction = EasyDevDebugProduction.new()

--------------------------
-- Tip Collisions Debug --
--------------------------

EasyDevDebugTipCollisions = {}

local EasyDevDebugTipCollisions_mt = Class(EasyDevDebugTipCollisions)

function EasyDevDebugTipCollisions.new()
    local self = setmetatable({}, EasyDevDebugTipCollisions_mt)

    self.active = false

    return self
end

function EasyDevDebugTipCollisions:setActive(active)
    if g_currentMission ~= nil and g_currentMission:getIsServer() then
        self.active = Utils.getNoNil(active, false)

        if self.active then
            g_currentMission:addDrawable(self)
        else
            g_currentMission:removeDrawable(self)
        end
    end

    return self.active
end

function EasyDevDebugTipCollisions:draw()
    if g_showTipCollisions then
        return
    end

    if g_densityMapHeightManager.visualizeCollisionMap ~= nil then
        g_densityMapHeightManager:visualizeCollisionMap()
    else
        self:setActive(false)
    end
end

g_easyDevDebugTipCollisions = EasyDevDebugTipCollisions.new()

--------------------------------
-- Placement Collisions Debug --
--------------------------------

EasyDevDebugPlacementCollisions = {}

local EasyDevDebugPlacementCollisions_mt = Class(EasyDevDebugPlacementCollisions)

function EasyDevDebugPlacementCollisions.new()
    local self = setmetatable({}, EasyDevDebugPlacementCollisions_mt)

    self.active = false

    return self
end

function EasyDevDebugPlacementCollisions:setActive(active)
    if g_currentMission ~= nil and g_currentMission:getIsServer() then
        self.active = Utils.getNoNil(active, false)

        if self.active then
            g_currentMission:addDrawable(self)
        else
            g_currentMission:removeDrawable(self)
        end
    end

    return self.active
end

function EasyDevDebugPlacementCollisions:draw()
    if g_showPlacementCollisions then
        return
    end

    if g_densityMapHeightManager.visualizePlacementCollisionMap ~= nil then
        g_densityMapHeightManager:visualizePlacementCollisionMap()
    else
        self:setActive(false)
    end
end

g_easyDevDebugPlacementCollisions = EasyDevDebugPlacementCollisions.new()
