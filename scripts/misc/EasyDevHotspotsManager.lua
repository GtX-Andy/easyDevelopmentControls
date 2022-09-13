--[[
Copyright (C) GtX (Andy), 2019

Author: GtX | Andy
Date: 07.04.2019
Revision: FS22-02

Contact:
https://forum.giants-software.com
https://github.com/GtX-Andy

Important:
Not to be added to any mods / maps or modified from its current release form.
No modifications may be made to this script, including conversion to other game versions without written permission from GtX | Andy

Darf nicht zu Mods / Maps hinzugefügt oder von der aktuellen Release-Form geändert werden.
Ohne schriftliche Genehmigung von GtX | Andy dürfen keine Änderungen an diesem Skript vorgenommen werden, einschließlich der Konvertierung in andere Spielversionen
]]

EasyDevHotspotsManager = {}

EasyDevHotspotsManager.TYPE_BALE = 1
EasyDevHotspotsManager.TYPE_PALLET = 2

EasyDevHotspotsManager.DEFAULT_COLOURS = {
    BALE = {1, 0.1, 0.01},
    PALLET = {0.1, 1, 0.01}
}

EasyDevHotspotsManager.COLOUR_BLIND_COLOURS = {
    BALE = {0.2541, 0.0065, 0.5089},
    PALLET = {0.0227, 0.5346, 0.8519}
}

EasyDevHotspotsManager.VALID_TYPE_IDS = {
    true,
    true
}

EasyDevHotspotsManager.MIN_HEIGHT = -200  -- Under map, delete it

EasyDevHotspotsManager.VALID_TYPE_NAMES = {
    ["pallet"] = true,
    ["treeSaplingPallet"] = true,
    ["bigBag"] = true
}

local EasyDevHotspotsManager_mt = Class(EasyDevHotspotsManager)

function EasyDevHotspotsManager.new()
    local self = setmetatable({}, EasyDevHotspotsManager_mt)

    self.baleToHotspot = {}
    self.palletToHotspot = {}

    self.updateBales = false
    self.updatePallets = false

    self.useColorBlindMode = g_gameSettings:getValue(GameSettings.SETTING.USE_COLORBLIND_MODE) or false

    return self
end

function EasyDevHotspotsManager:delete()
    self.baleToHotspot = {}
    self.palletToHotspot = {}

    self.updateBales = false
    self.updatePallets = false
end

function EasyDevHotspotsManager:setCurrentMission(mission)
    self.mission = mission
    self.accessHandler = mission.accessHandler
end

function EasyDevHotspotsManager:onPlayerFarmChanged(player, farmId)
    self.farmId = farmId or FarmManager.SPECTATOR_FARM_ID

    local updateBales = self.updateBales
    local updatePallets = self.updatePallets

    if updateBales or updatePallets then
        self:destroyHotspots(EasyDevHotspotsManager.TYPE_BALE, true)
        self:destroyHotspots(EasyDevHotspotsManager.TYPE_PALLET, true)

        if self.farmId ~= FarmManager.SPECTATOR_FARM_ID then
            if updateBales then
                self:setActive(EasyDevHotspotsManager.TYPE_BALE, true)
            end

            if updatePallets then
                self:setActive(EasyDevHotspotsManager.TYPE_PALLET, true)
            end
        else
            g_messageCenter:publish(EasyDevUtils.MESSAGE_TYPE_SETTINGS_CHANGED, EasyDevUtils.SETTING_HOTSPOTS, self.farmId)
        end
    end
end

function EasyDevHotspotsManager:onColourBlindModeChanged(useColorBlindMode)
    if useColorBlindMode ~= self.useColorBlindMode then
        self.useColorBlindMode = useColorBlindMode

        local r, g, b = self:getColour(true)

        for _, hotspot in pairs (self.baleToHotspot) do
            hotspot:setColor(r, g, b)
        end

        r, g, b = self:getColour(false)

        for _, hotspot in pairs (self.palletToHotspot) do
            hotspot:setColor(r, g, b)
        end
    end
end

function EasyDevHotspotsManager:setActive(typeId, active)
    local active = Utils.getNoNil(active, false)
    local typeText = ""

    if self.mission == nil or self.accessHandler == nil then
        self:setCurrentMission(g_currentMission)
    end

    if self.farmId == nil then
        self:onPlayerFarmChanged(self.mission.player, self.mission:getFarmId())
    end

    if typeId == EasyDevHotspotsManager.TYPE_BALE then
        self.updateBales = active
        typeText = EasyDevUtils.getText("easyDevControls_typeBale")
    elseif typeId == EasyDevHotspotsManager.TYPE_PALLET then
        self.updatePallets = active
        typeText = EasyDevUtils.getText("easyDevControls_typePallet")
    end

    if not active then
        self:destroyHotspots(typeId)
    end

    if not self.updateBales and not self.updatePallets then
        self.mission:removeUpdateable(self)
    else
        self.mission:addUpdateable(self)
    end

    return active, typeText
end

function EasyDevHotspotsManager:createBaleHotspot(bale)
    local hotspot = EasyDevObjectHotspot.new(bale.nodeId, true)

    bale:addDeleteListener(self, "onDeleteBale")
    self.mission:addMapHotspot(hotspot)

    self.baleToHotspot[bale] = hotspot
end

function EasyDevHotspotsManager:createPalletHotspot(pallet)
    local hotspot = EasyDevObjectHotspot.new(pallet.rootNode, false)

    pallet:addDeleteListener(self, "onDeletePallet")
    self.mission:addMapHotspot(hotspot)

    self.palletToHotspot[pallet] = hotspot
end

function EasyDevHotspotsManager:destroyHotspots(typeId, farmChange)
    self.mission:removeUpdateable(self)

    if typeId == EasyDevHotspotsManager.TYPE_BALE then
        for bale, hotspot in pairs (self.baleToHotspot) do
            bale:removeDeleteListener(self, "onDeleteBale")

            self.mission:removeMapHotspot(hotspot)
            hotspot:delete()
        end

        self.baleToHotspot = {}
        self.updateBales = false
    elseif typeId == EasyDevHotspotsManager.TYPE_PALLET then
        for pallet, hotspot in pairs (self.palletToHotspot) do
            pallet:removeDeleteListener(self, "onDeletePallet")

            self.mission:removeMapHotspot(hotspot)
            hotspot:delete()
        end

        self.palletToHotspot = {}
        self.updatePallets = false
    end

    if (farmChange == nil or farmChange == false) and (self.updateBales or self.updatePallets) then
        self.mission:addUpdateable(self)
    end
end

function EasyDevHotspotsManager:onDeleteBale(bale)
    local hotspot = self.baleToHotspot[bale]

    if hotspot ~= nil then
        self.baleToHotspot[bale] = nil

        self.mission:removeMapHotspot(hotspot)
        hotspot:delete()
    end
end

function EasyDevHotspotsManager:onDeletePallet(pallet)
    local hotspot = self.palletToHotspot[pallet]

    if hotspot ~= nil then
        self.palletToHotspot[pallet] = nil

        self.mission:removeMapHotspot(hotspot)
        hotspot:delete()
    end
end

function EasyDevHotspotsManager:update(dt)
    if self.updateBales then
        for object, _ in pairs (self.mission.objectsToClassName) do
            if self.baleToHotspot[object] ~= nil then
                local x, y, z = getWorldTranslation(object.nodeId)

                if y > EasyDevHotspotsManager.MIN_HEIGHT then
                    self.baleToHotspot[object]:setWorldPosition(x, z)
                else
                    object:delete()
                end
            elseif object.isa ~= nil and object:isa(Bale) and self.accessHandler:canFarmAccessOtherId(self.farmId, object:getOwnerFarmId()) then
                self:createBaleHotspot(object)
            end
        end
    end

    if self.updatePallets then
        for _, vehicle in ipairs (self.mission.vehicles) do
            if self.palletToHotspot[vehicle] ~= nil then
                local x, y, z = getWorldTranslation(vehicle.rootNode)

                if y > EasyDevHotspotsManager.MIN_HEIGHT then
                    self.palletToHotspot[vehicle]:setWorldPosition(x, z)
                else
                    vehicle:delete()
                end
            elseif vehicle.isa ~= nil and vehicle:isa(Vehicle) and EasyDevHotspotsManager.VALID_TYPE_NAMES[vehicle.typeName] then
                if self.accessHandler:canFarmAccessOtherId(self.farmId, vehicle:getOwnerFarmId()) then
                    self:createPalletHotspot(vehicle)
                end
            end
        end
    end
end

function EasyDevHotspotsManager:getColour(isBale)
    local COLOURS = EasyDevHotspotsManager.DEFAULT_COLOURS

    if self.useColorBlindMode then
        COLOURS = EasyDevHotspotsManager.COLOUR_BLIND_COLOURS
    end

    if isBale then
        return COLOURS.BALE[1], COLOURS.BALE[2], COLOURS.BALE[3]
    end

    return COLOURS.PALLET[1], COLOURS.PALLET[2], COLOURS.PALLET[3]
end

EasyDevObjectHotspot = {}
local EasyDevObjectHotspot_mt = Class(EasyDevObjectHotspot, MapHotspot)

function EasyDevObjectHotspot.new(rootNode, isBale)
    local self = MapHotspot.new(EasyDevObjectHotspot_mt)

    local x, y, z = 0, 0, 0
    local r, g, b = 1, 0, 1

    self.width, self.height = getNormalizedScreenValues(40, 40)

    self.icon = Overlay.new(PlaceableHotspot.FILENAME, 0, 0, self.width, self.height)
    self.icon:setUVs(GuiUtils.getUVs({652, 4, 100, 100}, PlaceableHotspot.FILE_RESOLUTION))

    if g_easyDevHotspotsManager ~= nil then
        r, g, b = g_easyDevHotspotsManager:getColour(isBale)
    end

    self:setColor(r or 1, g or 1, b or 1)

    if rootNode ~= nil then
        x, y, z = getWorldTranslation(rootNode)
    end

    self:setWorldPosition(x, z)
    self:setVisible(true)

    return self
end

function EasyDevObjectHotspot:getCategory()
    return MapHotspot.CATEGORY_OTHER
end

g_easyDevHotspotsManager = EasyDevHotspotsManager.new()
