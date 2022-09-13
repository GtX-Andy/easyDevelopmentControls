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

EasyDevUtils = {}

local emptyTable = {}
local modName = g_currentModName or ""
local modDirectory = g_currentModDirectory or ""
local modSettingsDirectory = g_currentModSettingsDirectory or ""

g_easyDevDevelopmentMode = false

EasyDevUtils.TYPE_TEXTS = {
    UNKNOWN = "easyDevControls_typeUnknownType",
    PLACEABLE = "easyDevControls_typePlaceable",
    MAP_PLACEABLE = "easyDevControls_typePrePlacedPlaceable",
    PRODUCTION_POINT = "easyDevControls_typeProductionPoint",
    PRODUCTION = "easyDevControls_typeProduction",
    VEHICLE = "easyDevControls_typeVehicle",
    TRAIN_SYSTEM = "easyDevControls_typeTrainSystem",
    PALLET = "easyDevControls_typePallet",
    BALE = "easyDevControls_typeBale",
    LOG = "easyDevControls_typeLog",
    STUMP = "easyDevControls_typeStump",
    FIELD = "easyDevControls_typeField"
}

EasyDevUtils.WEATHER_TYPE_TEXTS = {
    SUN = "easyDevControls_weatherTypeSunny",
    CLOUDY = "easyDevControls_weatherTypeCloudy",
    RAIN = "easyDevControls_weatherTypeRaining",
    SNOW = "easyDevControls_weatherTypeSnowing"
}

EasyDevUtils.FIELD_SPRAY_TYPE_TEXTS = {
    NONE = "ui_none",
    FERTILIZER = "easyDevControls_fertilizerStateTitle",
    LIME = "fillType_lime",
    MANURE = "fillType_manure",
    LIQUID_MANURE = "fillType_liquidManure",
    STRAW = "fillType_straw",
    MAIZE = "fillType_maize",
    MASK = "easyDevControls_mask"
}

EasyDevUtils.FIELD_GROUND_TYPE_TEXTS = {
    NONE = "ui_none",
    STUBBLE_TILLAGE = "ui_growthMapStubbleTillage",
    CULTIVATED = "ui_growthMapCultivated",
    SEEDBED = "ui_growthMapSeedbed",
    PLOWED = "ui_growthMapPlowed",
    ROLLED_SEEDBED = "easyDevControls_rolledSeedbed",
    SOWN = "ui_growthMapSown",
    DIRECT_SOWN = "easyDevControls_directSown",
    PLANTED = "easyDevControls_planted",
    RIDGE = "easyDevControls_ridge",
    ROLLER_LINES = "easyDevControls_rollerLines",
    HARVEST_READY = "ui_growthMapReadyToHarvest",
    HARVEST_READY_OTHER = "easyDevControls_harvestReadyOther",
    GRASS = "groundType_grass",
    GRASS_CUT = "easyDevControls_grassCut"
}

EasyDevUtils.SEASON_TEXTS = {
    [Environment.SEASON.SPRING] = "easyDevControls_seasonSpring",
    [Environment.SEASON.SUMMER] = "easyDevControls_seasonSummer",
    [Environment.SEASON.AUTUMN] = "easyDevControls_seasonAutumn",
    [Environment.SEASON.WINTER] = "easyDevControls_seasonWinter"
}

EasyDevUtils.INVALID_FILLTYPE = 2 ^ FillTypeManager.SEND_NUM_BITS

EasyDevUtils.OVERLAY_COLOUR_PRODUCTION_POINT = {0.0227, 0.5346, 0.8519, 0.3}
EasyDevUtils.DEFAULT_RANGES = {1, 2, 3, 4, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 100}

EasyDevUtils.SETTING_TIMESCALE = 1
EasyDevUtils.SETTING_SUPER_STRENGTH = 2
EasyDevUtils.SETTING_HOTSPOTS = 3
EasyDevUtils.SETTING_TOGGLE_HUD_INPUT = 4
EasyDevUtils.SETTING_JUMP_MULTIPLIER = 5
EasyDevUtils.SETTING_RUNNING_SPEED = 6

EasyDevUtils.MESSAGE_TYPE_SETTINGS_CHANGED = "EDC_SETTING_CHANGED"
EasyDevUtils.MESSAGE_TYPE_ACCESS_LEVEL_CHANGED = "EDC_ACCESS_LEVEL_CHANGED"
EasyDevUtils.MESSAGE_TYPE_PERMISSIONS_CHANGED = "EDC_PERMISSIONS_CHANGED"
EasyDevUtils.MESSAGE_TYPE_PRODUCTIONS_CHANGED = "EDC_PRODUCTIONS_CHANGED"

function EasyDevUtils.getCustomEnvironment()
    return modName
end

function EasyDevUtils.getBaseDirectory()
    return modDirectory
end

function EasyDevUtils.getModSettingsDirectory()
    if modName:endsWith("_update") then
        return getUserProfileAppPath() .. "modSettings/FS22_EasyDevControls/"
    end

    if EasyDevUtils.getIsNilOrEmpty(modSettingsDirectory) then
        modSettingsDirectory = string.format("%smodSettings/%s/", getUserProfileAppPath(), modName)
    end

    return modSettingsDirectory
end

function EasyDevUtils.getText(text)
    return g_i18n:getText(text, modName)
end

function EasyDevUtils.convertText(text)
    return g_i18n:convertText(text, modName)
end

function EasyDevUtils.formatText(text, ...)
    return EasyDevUtils.getText(text):format(...)
end

function EasyDevUtils.formatConvertedText(text, ...)
    return EasyDevUtils.convertText(text):format(...)
end

function EasyDevUtils.formatLength(length, useCentimetres)
    if useCentimetres == true then
        return string.format("%d cm", length * 100)
    end

    return string.format("%d m", length)
end

function EasyDevUtils.getFormatedRangeTexts(rangeTable, useCentimetres)
    local rangeTexts = {}

    rangeTable = rangeTable or EasyDevUtils.DEFAULT_RANGES

    for i = 1, #rangeTable do
        table.insert(rangeTexts, EasyDevUtils.formatLength(rangeTable[i], useCentimetres))
    end

    return rangeTexts
end

function EasyDevUtils.getDefaultRangeValue(index, getValueIndex)
    if getValueIndex == true then
        return Utils.getValueIndex(index, EasyDevUtils.DEFAULT_RANGES)
    end

    return EasyDevUtils.DEFAULT_RANGES[index]
end

function EasyDevUtils.getTypeText(typeName, count, formatText)
    local l10n = EasyDevUtils.TYPE_TEXTS[typeName] or EasyDevUtils.TYPE_TEXTS.UNKNOWN

    if count ~= 1 then
        l10n = l10n .. "s"
    end

    if formatText then
        return string.format("%i %s", count, EasyDevUtils.getText(l10n))
    end

    return EasyDevUtils.getText(l10n)
end

function EasyDevUtils.getWeatherTypeText(typeName)
    local l10n = EasyDevUtils.WEATHER_TYPE_TEXTS[typeName]

    if l10n == nil then
        return EasyDevUtils.capitalise(typeName, false)
    end

    return EasyDevUtils.getText(l10n)
end

function EasyDevUtils.getSeasonText(seasonID)
    local l10n = EasyDevUtils.SEASON_TEXTS[seasonID]

    if l10n == nil then
        return EasyDevUtils.getText("easyDevControls_unknown")
    end

    return EasyDevUtils.getText(l10n)
end

function EasyDevUtils.getNoNilText(text, setTo)
    if EasyDevUtils.getIsNilOrEmpty(text) or not g_i18n:hasText(text, modName) then
        return EasyDevUtils.convertText(setTo)
    end

    return g_i18n:getText(text, modName)
end

function EasyDevUtils.getIsNilOrEmpty(value)
    return value == nil or value == ""
end

function EasyDevUtils.getNoNilClamp(value, minValue, maxValue, setTo)
    return math.min(math.max((value or setTo), minValue), maxValue)
end

function EasyDevUtils.getNoNilOrEmpty(value, setTo)
    if EasyDevUtils.getIsNilOrEmpty(value) then
        return setTo
    end

    return value
end

function EasyDevUtils.getHasValidLocationValues(x, y, z)
    return x ~= nil and y ~= nil and z ~= nil -- need to check terrain size?
end

function EasyDevUtils.getValidAngle(angle)
    angle = angle % (2 * math.pi)

    if angle < 0 then
        angle = angle + 2 * math.pi
    end

    return angle
end

function EasyDevUtils.getIsValidFarmId(farmId)
    return farmId ~= nil and farmId > FarmManager.SPECTATOR_FARM_ID and farmId <= FarmManager.MAX_NUM_FARMS
end

function EasyDevUtils.getFillTypeTitle(fillTypeIndex, backup)
    local fillType = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex or EasyDevUtils.INVALID_FILLTYPE)

    if fillType == nil then
        return EasyDevUtils.convertText(backup or "$l10n_easyDevControls_all")
    end

    return fillType.title
end

function EasyDevUtils.getFieldSprayTypeTitle(typeName, backup)
    local l10n = EasyDevUtils.FIELD_SPRAY_TYPE_TEXTS[typeName]

    if l10n == nil then
        if backup ~= nil then
            return EasyDevUtils.removeUnderscores(backup, true, true)
        end

        return EasyDevUtils.getText("easyDevControls_unknown")
    end

    return EasyDevUtils.getText(l10n)
end

function EasyDevUtils.getFieldGroundTypeTitle(typeName, backup)
    local l10n = EasyDevUtils.FIELD_GROUND_TYPE_TEXTS[typeName]

    if l10n == nil then
        if backup ~= nil then
            return EasyDevUtils.removeUnderscores(backup, true, true)
        end

        return EasyDevUtils.getText("easyDevControls_unknown")
    end

    return EasyDevUtils.getText(l10n)
end

function EasyDevUtils.getPlayerWorldLocation(getCameraBackup)
    if g_currentMission ~= nil then
        local player = g_currentMission.player
        local controlledVehicle = g_currentMission.controlledVehicle

        if controlledVehicle ~= nil then
            local x, y, z = getWorldTranslation(controlledVehicle.rootNode)
            local dirX, _, dirZ = localDirectionToWorld(controlledVehicle.rootNode, 0, 0, 1)

            return x, y, z, dirX, dirZ, player, controlledVehicle
        end

        if g_currentMission.controlPlayer and player ~= nil and (player.rootNode ~= nil and player.rootNode ~= 0) then
            local x, y, z = getWorldTranslation(player.rootNode)

            return x, y, z, -math.sin(player.rotY), -math.cos(player.rotY), player
        end

        if getCameraBackup then
            local x, y, z = getWorldTranslation(getCamera(0))

            return x, y, z, 0, 0, player
        end
    end

    return nil
end

function EasyDevUtils.getArea(x, z, radius, getWidthAndHeight)
    local halfRadius = (radius or 1) / 2

    if x == nil or z == nil then
        local _ = nil
        x, _, z = EasyDevUtils.getPlayerWorldLocation(true)
    end

    if getWidthAndHeight then
        return MathUtil.getXZWidthAndHeight(x - halfRadius, z - halfRadius, x + halfRadius, z - halfRadius, x - halfRadius, z + halfRadius)
    end

    return x - halfRadius, z - halfRadius, x + halfRadius, z - halfRadius, x - halfRadius, z + halfRadius
end

function EasyDevUtils.getProjectedArea(sizeX, sizeZ, distance, getWidthAndHeight)
    local posX, _, posZ, dirX, dirZ = EasyDevUtils.getPlayerWorldLocation(true)

    sizeX = sizeX or 5
    sizeZ = sizeZ or 5
    distance = distance or 2

    local sideX, _, sideZ = MathUtil.crossProduct(dirX, 0, dirZ, 0, 1, 0)
    local startWorldX = posX - sideX * sizeX * 0.5 + dirX * distance
    local startWorldZ = posZ - sideZ * sizeX * 0.5 + dirZ * distance
    local widthWorldX = posX + sideX * sizeX * 0.5 + dirX * distance
    local widthWorldZ = posZ + sideZ * sizeX * 0.5 + dirZ * distance
    local heightWorldX = posX - sideX * sizeX * 0.5 + dirX * (distance + sizeZ)
    local heightWorldZ = posZ - sideZ * sizeX * 0.5 + dirZ * (distance + sizeZ)

    local positionX = (startWorldX + widthWorldX + heightWorldX) / 3
    local positionZ = (startWorldZ + widthWorldZ + heightWorldZ) / 3

    if getWidthAndHeight then
        startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ = MathUtil.getXZWidthAndHeight(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ)
    end

    return startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, positionX, positionZ
end

function EasyDevUtils.getObjectLocationString(node, owningPlaceable)
    if g_currentMission ~= nil or g_currentMission.hud ~= nil then
        local ingameMap = g_currentMission.hud:getIngameMap()

        if ingameMap ~= nil and node ~= nil then
            local x, y, z = getWorldTranslation(node)

            if owningPlaceable ~= nil then
                local hotspot = owningPlaceable:getHotspot(1)

                if hotspot ~= nil then
                    x = hotspot.teleportWorldX
                    y = hotspot.teleportWorldY
                    z = hotspot.teleportWorldZ
                end
            end

            local normalizedPosX = EasyDevUtils.getNoNilClamp((x + ingameMap.worldCenterOffsetX) / ingameMap.worldSizeX, 0, 1, x)
            local normalizedPosZ = EasyDevUtils.getNoNilClamp((z + ingameMap.worldCenterOffsetZ) / ingameMap.worldSizeZ, 0, 1, z)

            return string.format("%d, %d", normalizedPosX * ingameMap.worldSizeX, normalizedPosZ * ingameMap.worldSizeZ)
        end
    end

    return "N/A"
end

function EasyDevUtils.getIsFarmlandAccessible(x, z, farmId, radius)
    if farmId ~= nil or farmId ~= FarmManager.SPECTATOR_FARM_ID then
        local farmlandId = g_farmlandManager:getFarmlandIdAtWorldPosition(x, z)

        if farmlandId ~= nil and farmlandId ~= FarmlandManager.NOT_BUYABLE_FARM_ID then
            local landOwner = g_farmlandManager:getFarmlandOwner(farmlandId)

            if landOwner ~= 0 and g_currentMission.accessHandler:canFarmAccessOtherId(farmId, landOwner) then
                if radius == nil then
                    return true
                end

                local startX, startZ, widthX, widthZ, heightX, heightZ = EasyDevUtils.getArea(x, z, radius)

                if EasyDevUtils.getIsFarmlandAccessible(startX, startZ, farmId) then
                    if EasyDevUtils.getIsFarmlandAccessible(widthX, widthZ, farmId) then
                        return EasyDevUtils.getIsFarmlandAccessible(heightX, heightZ, farmId)
                    end
                end
            end
        end
    end

    return false
end

function EasyDevUtils.getCanTipToGround(amount, fillTypeIndex, x, y, z, dirX, dirZ, length, vehicle, farmId, radius)
    if farmId ~= nil and not EasyDevUtils.getIsFarmlandAccessible(x, z, farmId, radius) then
        return false
    end

    length = length or 1
    amount = amount or 100
    fillTypeIndex = fillTypeIndex or FillType.CHAFF

    return DensityMapHeightUtil.getCanTipToGroundAroundLine(vehicle, amount, fillTypeIndex, x, y, z, x + length * dirX, y, z + length * dirZ, 10, 40, 0, false, nil, nil)
end

function EasyDevUtils.getMonthFromPeriod(currentPeriod)
    local environment = g_currentMission.environment
    local month = 1

    if environment ~= nil then
        currentPeriod = currentPeriod or environment.currentPeriod

        month = currentPeriod + 2

        if environment.daylight.latitude < 0 then
            month = month + 6
        end

        month = (month - 1) % 12 + 1
    end

    return month
end

function EasyDevUtils.getPeriodFromMonth(month)
    local environment = g_currentMission.environment
    local period = Environment.PERIOD.EARLY_SPRING

    if environment ~= nil and month ~= nil then
        period = month - 2

        if environment.daylight.latitude < 0 then
            period = period - 6
        end

        period = (period - 1) % 12 + 1
    end

    return period
end

function EasyDevUtils.getPathFromString(env, pathString)
    local paths = string.split(pathString, ".")

    local valid = pathString == nil
    local validPath = env
    local owner = env
    local name = nil

    if not valid then
        valid = #paths > 0
    end

    for _, path in pairs (paths) do
        path = tostring(path)

        if validPath[path] ~= nil then
            owner = validPath
            name = path
            validPath = validPath[path]
        else
            valid = false

            break
        end
    end

    return valid, validPath, owner, name
end

function EasyDevUtils.capitalise(text, capitaliseEachWord)
    if text == nil then
        return ""
    end

    text = text:lower()

    if capitaliseEachWord == true then
        return text:gsub("(%w[%w]*)", function(word)
            return word:sub(1, 1):upper() .. word:sub(2)
        end)
    end

    return text:sub(1, 1):upper() .. text:sub(2)
end

function EasyDevUtils.removeUnderscores(text, capitalise, capitaliseEachWord)
    if text == nil then
        return ""
    end

    text = text:gsub("_", " ")

    if capitalise == true then
        return EasyDevUtils.capitalise(text, capitaliseEachWord)
    end

    return text
end

function EasyDevUtils.clearTable(table)
    for i = #table, 1, -1 do
        table[i] = nil
    end
end

function EasyDevUtils.collectPositionData(vehicle, isImplement, vehicles, attachedVehicles, rootVehicle)
    local x, y, z = getWorldTranslation(vehicle.rootNode)

    if rootVehicle == nil then
        rootVehicle = vehicle

        if vehicles[1] ~= nil and vehicles[1].vehicle ~= nil then
            rootVehicle = vehicles[1].vehicle
        end
    end

    table.insert(vehicles, {
        vehicle = vehicle,
        isImplement = isImplement,
        offset = {worldToLocal(rootVehicle.rootNode, x, y, z)}
    })

    -- Only with 'spec_attacherJoints'
    if vehicle.getAttachedImplements ~= nil then
        local attachedImplements = vehicle:getAttachedImplements()
        local numAttachedImplements = #attachedImplements

        -- If there are implements then record their position
        if numAttachedImplements > 0 then
            for _, implement in pairs(attachedImplements) do
                EasyDevUtils.collectPositionData(implement.object, true, vehicles, attachedVehicles, rootVehicle)

                table.insert(attachedVehicles, {
                    vehicle = vehicle,
                    object = implement.object,
                    jointDescIndex = implement.jointDescIndex,
                    inputAttacherJointDescIndex = implement.object:getActiveInputAttacherJointDescIndex()
                })
            end

            -- Disconnect implements
            for i = numAttachedImplements, 1, -1 do
                vehicle:detachImplement(1, true)
            end
        end
    end

    vehicle:removeFromPhysics()
end

function EasyDevUtils.getVehiclesPositionData(vehicle, targetVehicle)
    local vehicles = {}
    local attachedVehicles = {}

    if vehicle ~= nil then
        EasyDevUtils.collectPositionData(vehicle, false, vehicles, attachedVehicles, vehicle)
    end

    return vehicles, attachedVehicles
end

function EasyDevUtils.getVinePlaceables()
    local vineSystem = g_currentMission.vineSystem
    local vinePlaceables = {}

    if vineSystem ~= nil and vineSystem.nodes ~= nil then
        for node, placeable in pairs (vineSystem.nodes) do
            if vinePlaceables[placeable] == nil then
                vinePlaceables[placeable] = {}
            end

            table.insert(vinePlaceables[placeable], node)
        end
    end

    return vinePlaceables
end

function EasyDevUtils.getFieldFruitModifierData(fruitIndex, growthState, sprayTypeState, fertilizerState, plowingState, limeState, stubbleState, weedState, herbicideState, rollerState, stonesValue)
    local fruitType = g_fruitTypeManager:getFruitTypeByIndex(fruitIndex)
    local modifierData, extraParamaters

    if fruitType ~= nil then
        local fieldGroundSystem = g_currentMission.fieldGroundSystem
        local groundTypeValue = fieldGroundSystem:getFieldGroundValue(FieldGroundType.SOWN)

        growthState = EasyDevUtils.getNoNilClamp(growthState, 0, 2 ^ fruitType.numStateChannels - 1, fruitType.maxHarvestingGrowthState)

        if fruitType.groundTypeChangeGrowthState >= 0 and fruitType.groundTypeChangeGrowthState <= growthState then
            groundTypeValue = fieldGroundSystem:getFieldGroundValue(fruitType.groundTypeChangeType)
        end

        local defaultModifier, preparingModifier = g_fieldManager:getFruitModifier(fruitType)

        if defaultModifier ~= nil then
            modifierData, extraParamaters = EasyDevUtils.getFieldGroundModifierData(groundTypeValue, 0, false, sprayTypeState, fertilizerState, plowingState, limeState, stubbleState, weedState, herbicideState, rollerState, stonesValue)

            table.insert(modifierData, 1, {
                modifier = defaultModifier,
                modifierValue = growthState
            })

            if preparingModifier ~= nil then
                table.insert(modifierData, 1, {
                    modifier = preparingModifier,
                    modifierValue = (growthState == fruitType.preparedGrowthState or growthState == fruitType.cutState) and 1 or 0
                })
            end

            extraParamaters.clearArea = true
            extraParamaters.fruitType = fruitType.index
        end
    end

    return modifierData, extraParamaters
end

function EasyDevUtils.getFieldGroundModifierData(groundTypeValue, angleValue, removeFoliage, sprayTypeState, fertilizerState, plowingState, limeState, stubbleState, weedState, herbicideState, rollerState, stonesValue)
    local modifierData = {
        {modifier = g_fieldManager.groundTypeModifier, modifierValue = groundTypeValue or 0},
        {modifier = g_fieldManager.angleModifier, modifierValue = angleValue or 0},
        {modifier = g_fieldManager.sprayTypeModifier, modifierValue = sprayTypeState or 0},
        {modifier = g_fieldManager.sprayLevelModifier, modifierValue = fertilizerState or 0},
        {modifier = g_fieldManager.plowLevelModifier, modifierValue = plowingState or 0},
        {modifier = g_fieldManager.limeLevelModifier, modifierValue = limeState or 0},
        {modifier = g_fieldManager.stubbleShredModifier, modifierValue = stubbleState or 0}
    }

    if rollerState ~= nil then
        if EasyDevUtils.cachedRollerLevelModifier == nil then
            local rollerLevelMapId, rollerLevelFirstChannel, rollerLevelNumChannels = g_currentMission.fieldGroundSystem:getDensityMapData(FieldDensityMap.ROLLER_LEVEL)

            EasyDevUtils.cachedRollerLevelModifier = DensityMapModifier.new(rollerLevelMapId, rollerLevelFirstChannel, rollerLevelNumChannels, g_currentMission.terrainRootNode)
        end

        if EasyDevUtils.cachedRollerLevelModifier ~= nil then
            table.insert(modifierData, {modifier = EasyDevUtils.cachedRollerLevelModifier, modifierValue = math.min(math.max(rollerState, 0), 1)})
        end
    end

    if weedState ~= nil and g_fieldManager.weedModifier ~= nil then
        table.insert(modifierData, {modifier = g_fieldManager.weedModifier, modifierValue = weedState})
    end

    if stonesValue ~= nil and g_currentMission.stoneSystem ~= nil then
        local stoneSystem = g_currentMission.stoneSystem

        table.insert(modifierData, {
            modifier = stoneSystem.stoneModifier,
            modifierValue = math.max(stonesValue, 1),
            filter = stoneSystem.stoneFilter,
            filterParams = {DensityValueCompareType.GREATER, 0}
        })
    end

    local extraParamaters = {
        removeFoliage = Utils.getNoNil(removeFoliage, true),
        herbicideState = herbicideState or 0,
        clearArea = false
    }

    return modifierData, extraParamaters
end

function EasyDevUtils.setField(field, modifiersData, extraParamaters, farmId, buyFarmland)
    if (field == nil or field.fieldDimensions == nil or field.farmland == nil) or modifiersData == nil or not EasyDevUtils.getIsValidFarmId(farmId) then
        return false
    end

    local currentOwner = g_farmlandManager:getFarmlandOwner(field.farmland.id)
    local notFarmOwned = currentOwner ~= farmId

    if notFarmOwned and currentOwner ~= FarmlandManager.NO_OWNER_FARM_ID then
        return false
    end

    if buyFarmland and notFarmOwned then
        g_server:broadcastEvent(FarmlandStateEvent.new(field.farmland.id, farmId, 0), false)
        g_farmlandManager:setLandOwnership(field.farmland.id, farmId)
    end

    local numAreasSet = 0
    local setWeeds = g_currentMission.missionInfo.weedsEnabled and g_currentMission.weedSystem:getMapHasWeed()

    extraParamaters = extraParamaters or emptyTable

    for i = 1, getNumOfChildren(field.fieldDimensions) do
        local dimWidth = getChildAt(field.fieldDimensions, i - 1)
        local dimStart = getChildAt(dimWidth, 0)
        local dimHeight = getChildAt(dimWidth, 1)

        local startX, _, startZ = getWorldTranslation(dimStart)
        local widthX, _, widthZ = getWorldTranslation(dimWidth)
        local heightX, _, heightZ = getWorldTranslation(dimHeight)

        if extraParamaters.removeFoliage then
            FSDensityMapUtil.updateDestroyCommonArea(startX, startZ, widthX, widthZ, heightX, heightZ, true, false) -- Only if setting ground.
        end

        if extraParamaters.clearArea or not extraParamaters.removeFoliage then
            EasyDevUtils.clearArea(startX, startZ, widthX, widthZ, heightX, heightZ, nil)
        end

        field.fruitType = extraParamaters.fruitType -- ??

        for _, data in ipairs (modifiersData) do
            if data.modifier ~= nil then
                data.modifier:setParallelogramWorldCoords(startX, startZ, widthX, widthZ, heightX, heightZ, DensityCoordType.POINT_POINT_POINT)

                if data.filter ~= nil and data.filterParams ~= nil then
                    data.filter:setValueCompareParams(data.filterParams[1], data.filterParams[2])
                end

                data.modifier:executeSet(data.modifierValue, data.filter)
            end
        end

        if setWeeds then
            if extraParamaters.herbicideState == 0 then
                FSDensityMapUtil.removeWeedBlockingState(startX, startZ, widthX, widthZ, heightX, heightZ)
            else
                FSDensityMapUtil.setWeedBlockingState(startX, startZ, widthX, widthZ, heightX, heightZ)
            end
        end

        numAreasSet = i
    end

    return numAreasSet > 0
end

function EasyDevUtils.clearArea(startX, startZ, widthX, widthZ, heightX, heightZ, fillTypeIndex)
    if fillTypeIndex == nil or fillTypeIndex == FillType.UNKNOWN then
        DensityMapHeightUtil.clearArea(startX, startZ, widthX, widthZ, heightX, heightZ)
    else
        DensityMapHeightUtil.removeFromGroundByArea(startX, startZ, widthX, widthZ, heightX, heightZ, fillTypeIndex)
    end
end

function EasyDevUtils.clearField(field, fillTypeIndex, farmId, offset)
    local numAreasCleared = 0

    if field ~= nil and field.fieldDimensions ~= nil then
        if farmId ~= nil and field.farmland ~= nil then
            if g_farmlandManager:getFarmlandOwner(field.farmland.id) ~= farmId then
                return false
            end
        end

        for i = 1, getNumOfChildren(field.fieldDimensions) do
            local dimWidth = getChildAt(field.fieldDimensions, i - 1)
            local dimStart = getChildAt(dimWidth, 0)
            local dimHeight = getChildAt(dimWidth, 1)

            local startX, _, startZ = getWorldTranslation(dimStart)
            local widthX, _, widthZ = getWorldTranslation(dimWidth)
            local heightX, _, heightZ = getWorldTranslation(dimHeight)

            EasyDevUtils.clearArea(startX, startZ, widthX, widthZ, heightX, heightZ, fillTypeIndex)
            numAreasCleared = i
        end
    end

    return numAreasCleared > 0
end

function EasyDevUtils.deleteTree(shape, isPlanted)
    if g_server ~= nil and shape ~= nil and entityExists(shape) then
        g_currentMission:removeKnownSplitShape(shape)

        if isPlanted then
            local x, y, z = getWorldTranslation(shape)

            splitShape(shape, x, y + 0.2, z, 0, 1, 0, 0, 0, 0, 4, 4, "deleteCutSplitShapeCallback", EasyDevUtils)
        else
            delete(shape)
        end

        g_treePlantManager:removingSplitShape(shape)
        -- g_treePlantManager:cleanupDeletedTrees()
    end
end

function EasyDevUtils.deleteCutSplitShapeCallback(unused, shape, isBelow, isAbove, minY, maxY, minZ, maxZ)
    if shape ~= nil then
        delete(shape)
    end
end

function EasyDevUtils.clearFile(file)
    if not EasyDevUtils.getIsNilOrEmpty(file) and fileExists(file) then
       io.open(file, "w"):close()
   end
end

function EasyDevUtils.copyFile(file, filename, subDirPath, overwrite)
    if not EasyDevUtils.getIsNilOrEmpty(file) and not EasyDevUtils.getIsNilOrEmpty(filename) and fileExists(file) then
        local directory = EasyDevUtils.getModSettingsDirectory()

        if not EasyDevUtils.getIsNilOrEmpty(subDirPath) then
            if subDirPath:sub(-1) ~= "/" then
                subDirPath = subDirPath .. "/"
            end

            directory = directory .. subDirPath
        end

        overwrite = Utils.getNoNil(overwrite, false)

        createFolder(directory)
        copyFile(file, directory .. filename, overwrite)

        return directory .. filename
   end

   return ""
end

function EasyDevUtils.doRestart(keepLogFile, aruments)
    local logFile = ""

    if not keepLogFile then
        logFile = (getUserProfileAppPath() or "") .. "log.txt"
    end

    RestartManager:setStartScreen(RestartManager.START_SCREEN_MAIN)
    doRestart(true, aruments or "")

    EasyDevUtils.clearFile(logFile) -- clear the log??
end

function EasyDevUtils.devInfo(message, ...)
    if g_easyDevDevelopmentMode then
        print(string.format("  DevInfo: [EasyDevControls] " .. message, ...))
    end
end
