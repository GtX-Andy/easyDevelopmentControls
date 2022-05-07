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

EasyDevControlsEnvironmentFrame = {}

local EasyDevControlsEnvironmentFrame_mt = Class(EasyDevControlsEnvironmentFrame, EasyDevControlsBaseFrame)
local EMPTY_TABLE = {}

-- No translation as this is for debugging only and needs to replicate the XML in some way
local WEATHER_VARIATION_TEXT = [[
variation:
  - weight: %d
  - minHours: %d
  - maxHours: %d
  - minTemperature: %d
  - maxTemperature: %d

clouds:
  - presetId: %s

wind:
  - angle: %.3f
  - speed: %.3f
  - cirrusSpeedFactor: %.3f
]]

EasyDevControlsEnvironmentFrame.L10N_SYMBOL = {}

EasyDevControlsEnvironmentFrame.CONTROLS = {
    "multiSetMonth",
    "multiSetHour",
    "multiSetDay",
    "buttonConfirmTime",
    "buttonEnvironmentReloadData",
    "buttonWeatherReloadData",
    "multiWeatherSetAdd",
    "textWeatherSetAdd",
    "multiWeatherType",
    "multiWeatherVariation",
    "buttonVariationInfo",
    "buttonConfirmWeather",
    "multiRemoveTireTracksRadius",
    "buttonRemoveTireTracks",
    "checkedWeatherDebug",
    "checkedRandomWindWaving",
    "checkedSeasonalShaderDebug",
    "checkedEnvironmentMaskDebug",
    "multiAddSaltRadius",
    "buttonConfirmAddSalt",
    "buttonAddSnow",
    "textInputSetSnow",
    "buttonRemoveSnow",
}

EasyDevControlsEnvironmentFrame.RADIUS_TIRE_TRACKS = {0, 1, 2, 3, 4, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 100}
EasyDevControlsEnvironmentFrame.RADIUS_SALT = {1, 2, 3, 4, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 100}

function EasyDevControlsEnvironmentFrame.new(ui, easyDevControls, accessLevel)
    local self = EasyDevControlsBaseFrame.new(EasyDevControlsEnvironmentFrame_mt, ui, easyDevControls, accessLevel)

    self:registerControls(EasyDevControlsEnvironmentFrame.CONTROLS)

    return self
end

function EasyDevControlsEnvironmentFrame:initialize()
    self.isServer = self.ui.isServer
    self.isMultiplayer = self.ui.isMultiplayer

    self.multiWeatherSetAdd:setTexts({
        EasyDevUtils.getText("easyDevControls_set"),
        EasyDevUtils.getText("easyDevControls_add")
    })

    local removeTireTrackTexts = {
        EasyDevUtils.getText("easyDevControls_all")
    }

    for i = 2, #EasyDevControlsEnvironmentFrame.RADIUS_TIRE_TRACKS do
        table.insert(removeTireTrackTexts, string.format("%d m", EasyDevControlsEnvironmentFrame.RADIUS_TIRE_TRACKS[i]))
    end

    self.multiRemoveTireTracksRadius:setTexts(removeTireTrackTexts)

    local saltRadiusTexts = {}

    for i = 1, #EasyDevControlsEnvironmentFrame.RADIUS_SALT do
        saltRadiusTexts[i] = string.format("%d m", EasyDevControlsEnvironmentFrame.RADIUS_SALT[i])
    end

    self.multiAddSaltRadius:setTexts(saltRadiusTexts)
end

function EasyDevControlsEnvironmentFrame:subscribeToMessages(messageCenter)
    messageCenter:subscribe(EasyDevUtils.MESSAGE_TYPE_SETTINGS_CHANGED, self.onSettingChanged, self)

    messageCenter:subscribe(MessageType.HOUR_CHANGED, self.onHourChanged, self)
    messageCenter:subscribe(MessageType.DAY_CHANGED, self.onDayChanged, self)
    messageCenter:subscribe(MessageType.PERIOD_CHANGED, self.onPeriodChanged, self)
    messageCenter:subscribe(MessageType.PERIOD_LENGTH_CHANGED, self.onPeriodLengthChanged, self)

    if self.isServer and not self.isMultiplayer then
        messageCenter:subscribe(MessageType.SEASON_CHANGED, self.onSeasonChanged, self)
    end
end

function EasyDevControlsEnvironmentFrame:updateAvailableProperties()
    local environment = g_currentMission.environment
    local mpDisabled = self.isMultiplayer or not self.isServer

    -- Time Set
    self.setTimeDisabled = self:getIsPropertyDisabled("setTime")

    self.multiSetMonth:setState(self:getMonthFromPeriod(environment.currentPeriod))
    self.multiSetMonth:setDisabled(self.setTimeDisabled)

    self:onPeriodLengthChanged(environment.daysPerPeriod, timeAdjustment)

    self.multiSetHour:setState(environment.currentHour + 2)
    self.multiSetHour:setDisabled(self.setTimeDisabled)

    self.buttonConfirmTime:setDisabled(self.setTimeDisabled)

    -- Reload Environment Data
    self.buttonEnvironmentReloadData:setDisabled(mpDisabled)

    -- Reload Weather Data
    self.buttonWeatherReloadData:setDisabled(mpDisabled)

    -- Weather Set / Add
    self:updateWeatherData(environment)

    -- Remove Tire Tracks
    local removeTireTracksDisabled = g_currentMission == nil or g_currentMission.tireTrackSystem == nil

    self.multiRemoveTireTracksRadius:setState(1)
    self.multiRemoveTireTracksRadius:setDisabled(removeTireTracksDisabled)
    self.buttonRemoveTireTracks:setDisabled(removeTireTracksDisabled)

    -- Seasonal Shader Debug
    self.checkedSeasonalShaderDebug:setIsChecked(environment.debugSeasonalShaderParameter)

    -- Environment Mask System Debug
    local environmentMaskSystem = environment.environmentMaskSystem

    if environmentMaskSystem ~= nil then
        self.checkedEnvironmentMaskDebug:setIsChecked(environmentMaskSystem.isDebugViewActive)
    else
        self.checkedEnvironmentMaskDebug:setIsChecked(1)
    end

    self.checkedEnvironmentMaskDebug:setDisabled(environmentMaskSystem == nil)

    -- Random Wind Waving
    self.checkedRandomWindWaving:setDisabled(mpDisabled)

    local updateSnowDisabled = self:getIsPropertyDisabled("updateSnow")

    -- Add Snow
    self.buttonAddSnow:setDisabled(updateSnowDisabled)

    -- Set Snow
    self.textInputSetSnow.lastValidText = ""
    self.textInputSetSnow:setText("")
    self.textInputSetSnow:setDisabled(updateSnowDisabled)

    -- Remove Snow
    self.buttonRemoveSnow:setDisabled(updateSnowDisabled)

    -- Add Salt
    local saltDisabled = self:getIsPropertyDisabled("addSalt")

    self.multiAddSaltRadius:setDisabled(saltDisabled)
    self.buttonConfirmAddSalt:setDisabled(saltDisabled)

    EasyDevControlsEnvironmentFrame:superClass().updateAvailableProperties(self)
end

-- Time Set (Month | Day | Hour)
function EasyDevControlsEnvironmentFrame:onClickConfirmTime(element)
    local maxTimeScale = self.isMultiplayer and 1 or 120 -- Need to limit so that the season can catch up especially in MP

    if g_currentMission.missionInfo.timeScale <= maxTimeScale then
        local environment = g_currentMission.environment
        local daysPerPeriod = environment.daysPerPeriod
        local currentDayInPeriod = environment.currentDayInPeriod
        local currentMonth = self:getMonthFromPeriod()

        local showWarning = false
        local daysToAdvance  = 0

        local monthToSet = self.multiSetMonth:getState()
        local dayToSet = self.multiSetDay:getState()
        local hourToSet = self.multiSetHour:getState() - 1

        if monthToSet == currentMonth then
            if dayToSet > currentDayInPeriod then
                daysToAdvance = dayToSet - 1
            elseif dayToSet < currentDayInPeriod then
                daysToAdvance = (12 * daysPerPeriod) + (dayToSet - daysPerPeriod)
                showWarning = true
            elseif dayToSet == currentDayInPeriod and hourToSet <= environment.currentHour then
                daysToAdvance = 12 * daysPerPeriod
                showWarning = true
            end
        else
            daysToAdvance = (((12 - currentMonth) + monthToSet) % 12) * daysPerPeriod

            if dayToSet > currentDayInPeriod then
                daysToAdvance = daysToAdvance + (dayToSet - 1)
            elseif dayToSet < currentDayInPeriod then
                daysToAdvance = daysToAdvance + (dayToSet - daysPerPeriod)
            end
        end

        local function setCurrentTime(yes)
            if yes then
                self:setInfoText(self.easyDevControls:setCurrentTime(hourToSet, daysToAdvance))
                self.multiSetHour:setState(self:getNextHour(environment.currentHour) + 1, true)

                self:onSeasonChanged(environment.currentSeason) -- Update the available weather types
            end
        end

        if not showWarning then
            setCurrentTime(true)
        else
            local numMonths = math.floor(daysToAdvance / daysPerPeriod)
            local numDays = ((daysToAdvance / daysPerPeriod) - numMonths) * daysPerPeriod

            g_gui:showYesNoDialog({
                text = EasyDevUtils.formatText("easyDevControls_setTimeWarning", g_i18n:formatNumMonth(numMonths), g_i18n:formatNumDay(numDays)),
                callback = setCurrentTime
            })
        end
    else
        local timeScaleText = "120x"

        if maxTimeScale == 1 then
            timeScaleText = g_i18n:getText("ui_realTime")
        end

        g_gui:showInfoDialog({
            text = EasyDevUtils.formatText("easyDevControls_timeScaleWarning", timeScaleText),
            dialogType = DialogElement.TYPE_INFO
        })
    end
end

-- Reload Weather / Environment Data
function EasyDevControlsEnvironmentFrame:onClickConfirmReloadData(element)
    if self:getWeatherIsLoaded() then
        local function clearModifiers()
            -- @Giants does not reload the following sounds, no good if your trying to apply modifier XML sound changes. Also stops log warnings
            if g_currentMission.ambientSoundSystem ~= nil and g_currentMission.ambientSoundSystem.modifiers ~= nil then
                local modifiersToRemove = {
                    ["sun"] = true,
                    ["rain"] = true,
                    ["cloudy"] = true,
                    ["snow"] = true
                }

                for i = #g_currentMission.ambientSoundSystem.modifiers, 1, -1 do
                    if modifiersToRemove[g_currentMission.ambientSoundSystem.modifiers[i].xmlAttributeName] then
                        g_currentMission.ambientSoundSystem.modifiers[i] = nil
                    end
                end
            end
        end

        if element.name == "environmentReload" then
            clearModifiers()

            g_currentMission.environment:consoleCommandReloadEnvironment()

            self:setInfoText(EasyDevUtils.formatText("easyDevControls_reloadedEnvironmentDataInfo", g_currentMission.environment.xmlFilename))
        elseif element.name == "weatherReload" then
            clearModifiers()

            g_currentMission.environment.weather:consoleCommandWeatherReloadData()

            self:setInfoText(EasyDevUtils.formatText("easyDevControls_reloadedWeatherDataInfo", g_currentMission.environment.xmlFilename))
        end

        element:setDisabled(true)
    else
        self:setInfoText(EasyDevUtils.getText("easyDevControls_requestFailedMessage"))
    end
end

-- Weather Set / Add
function EasyDevControlsEnvironmentFrame:updateWeatherData(environment)
    local setAddWeatherDisabled = not self.isServer or self.isMultiplayer
    local variationText = EasyDevUtils.getText("easyDevControls_variation")

    local typeState =  1
    local variationState = 1
    local setAddState = 1

    if environment == nil then
        environment = g_currentMission.environment
    end

    if not setAddWeatherDisabled and not self:getSeasonChanged(environment.currentSeason) then
        typeState = self.multiWeatherType:getState()
        variationState = self.multiWeatherVariation:getState()
        setAddState = self.multiWeatherSetAdd:getState()
    end

    self.weatherTypes = {}
    self.weatherTypeTexts = {}

    self.weatherTypeVariations = {}
    self.weatherVariationTexts = {}

    self.currentSeason = environment.currentSeason
    self.setAddWeatherDisabled = setAddWeatherDisabled

    -- Only load the available weather types for the current season
    for weatherTypeIndex, weatherTypeObject in pairs(environment.weather.typeToWeatherObject[self.currentSeason]) do
        local weatherTypeName = g_weatherTypeManager:getWeatherTypeByIndex(weatherTypeIndex).name

        local variations = {
            0
        }

        local variationTexts = {
            EasyDevUtils.getText("easyDevControls_random")
        }

        for _, variation in pairs (weatherTypeObject.variations) do
            table.insert(variations, variation.index)
            table.insert(variationTexts, string.format("%s %i", variationText, variation.index))
        end

        table.insert(self.weatherTypes, weatherTypeName)
        table.insert(self.weatherTypeTexts, EasyDevUtils.getWeatherTypeText(weatherTypeName))

        table.insert(self.weatherTypeVariations, variations)
        table.insert(self.weatherVariationTexts, variationTexts)

        if setAddWeatherDisabled then
            typeState = 1
            variationState = 1

            break
        end
    end

    if typeState > #self.weatherTypes then
        typeState = 1
    end

    if variationState > #self.weatherVariationTexts[typeState] then
        variationState = 1
    end

    self.multiWeatherSetAdd:setState(setAddState)
    self.textWeatherSetAdd:setText(EasyDevUtils.formatText("easyDevControls_setAddWeatherTitle", self.multiWeatherSetAdd.texts[setAddState]))

    self.multiWeatherType:setTexts(self.weatherTypeTexts)
    self.multiWeatherType:setState(typeState)
    self.multiWeatherVariation:setTexts(self.weatherVariationTexts[typeState])
    self.multiWeatherVariation:setState(variationState)

    self.multiWeatherSetAdd:setDisabled(setAddWeatherDisabled)
    self.multiWeatherType:setDisabled(setAddWeatherDisabled)
    self.multiWeatherVariation:setDisabled(setAddWeatherDisabled or self:getIsCheckedIndex(setAddState))
    self.buttonVariationInfo:setDisabled(setAddWeatherDisabled)
    self.buttonConfirmWeather:setDisabled(setAddWeatherDisabled)
end

function EasyDevControlsEnvironmentFrame:onClickWeatherSetAdd(index, element)
    local isDisabled = self.setAddWeatherDisabled or self:getIsCheckedIndex(index)

    self.textWeatherSetAdd:setText(EasyDevUtils.formatText("easyDevControls_setAddWeatherTitle", element.texts[index]))
    self.multiWeatherVariation:setDisabled(isDisabled)

    if isDisabled then
        self.multiWeatherVariation:setState(1)
    end
end

function EasyDevControlsEnvironmentFrame:onClickWeatherType(index, element)
    self.multiWeatherVariation:setTexts(self.weatherVariationTexts[index])
    self.multiWeatherVariation:setState(1)
end

function EasyDevControlsEnvironmentFrame:onClickVariationInfo(element)
    if g_currentMission.environment ~= nil and g_currentMission.environment.weather ~= nil then
        local weather = g_currentMission.environment.weather
        local typeState = self.multiWeatherType:getState()
        local weatherType = g_weatherTypeManager:getWeatherTypeByName(self.weatherTypes[typeState])

        if weatherType ~= nil then
            local weatherTypeObject = weather.typeToWeatherObject[self.currentSeason][weatherType.index]

            if weatherTypeObject ~= nil then
                local variationText = EasyDevUtils.getText("easyDevControls_variation")
                local list = {}

                for _, variation in pairs (weatherTypeObject.variations) do
                    table.insert(list, {
                        overlayColour = EasyDevUtils.OVERLAY_COLOUR_PRODUCTION_POINT,
                        title = string.format("%s %i", variationText, variation.index),
                        text = string.format(
                            WEATHER_VARIATION_TEXT,
                            variation.weight,
                            variation.minHours,
                            variation.maxHours,
                            variation.minTemperature,
                            variation.maxTemperature,
                            variation.clouds.id,
                            variation.wind.windAngle,
                            MathUtil.mpsToKmh(variation.wind.windVelocity),
                            variation.wind.cirrusSpeedFactor
                        )
                    })
                end

                self.ui:showDynamicListDialog({
                    headerText = string.format("%s '%s' %s", EasyDevUtils.getSeasonText(self.currentSeason or 0), weatherType.name, EasyDevUtils.getText("easyDevControls_variations")),
                    callback = nil,
                    target = nil,
                    list = list
                })
            end
        end
    end
end

function EasyDevControlsEnvironmentFrame:onClickConfirmWeather(element)
    local weatherType = self.multiWeatherType:getState()
    local weatherTypeName = self.weatherTypes[weatherType]

    if weatherType ~= nil and self:getWeatherIsLoaded() then
        local weather = g_currentMission.environment.weather

        if self:getIsCheckedIndex(self.multiWeatherSetAdd:getState()) then
            local resultText = weather:consoleCommandWeatherAdd(weatherTypeName)

            if resultText:sub(1, 3) == "Add" then
                self:setInfoText(resultText)

                return
            end
        else
            -- Console command was breaking the Forecast so added my own set weather
            local variationState = self.multiWeatherVariation:getState()
            local variationIndex

            if variationState > 1 then
                variationIndex = self.weatherTypeVariations[weatherType][variationState]
            end

            local currentInstance = weather.forecastItems[1]
            local currentObject

            if currentInstance ~= nil then
                currentObject = weather:getWeatherObjectByIndex(currentInstance.season, currentInstance.objectIndex)
            end

            weatherType = g_weatherTypeManager:getWeatherTypeByName(weatherTypeName)

            if weatherType ~= nil then
                local environment = g_currentMission.environment
                local currentSeason = environment.currentSeason
                local weatherObject = weather.typeToWeatherObject[currentSeason][weatherType.index]

                if weatherObject ~= nil then
                    local variation = weatherObject:getVariationByIndex(variationIndex)

                    if variation == nil then
                        variation = weatherObject:getVariationByIndex(weatherObject:getRandomVariationIndex())
                    end

                    local duration = math.random(variation.minHours, variation.maxHours) * 60 * 60 * 1000
                    local startDay, startDayTime = environment:getDayAndDayTime(environment.dayTime, environment.currentMonotonicDay) -- ??

                    weather.forecastItems = {
                        WeatherInstance.createInstance(weatherObject.index, variation.index, startDay, startDayTime, duration, currentSeason)
                    }

                    weather:fillWeatherForecast() -- create the rest of the forecast

                    if currentObject ~= nil then
                        currentObject:deactivate(1) -- deactivate original
                        currentObject:update(99999999) -- push update to finalise
                    end

                    weather:init() -- reset environment factors for new forecast

                    self:setInfoText(string.format("Set weather to '%s'", weatherTypeName:upper())) -- currently no translation but matches the 'ADD' console command.

                    return
                end
            end
        end
    end

    self:setInfoText(EasyDevUtils.getText("easyDevControls_requestFailedMessage"))
end

-- Remove Tire Tracks
function EasyDevControlsEnvironmentFrame:onClickRemoveTireTracks(element)
    if g_currentMission.tireTrackSystem ~= nil then
        local radiusState = self.multiRemoveTireTracksRadius:getState()

        if radiusState == 1 then
            local halfTerrainSize  = g_currentMission.terrainSize / 2 + 1

            g_currentMission.tireTrackSystem:eraseParallelogram(-halfTerrainSize, -halfTerrainSize, halfTerrainSize, -halfTerrainSize, -halfTerrainSize, halfTerrainSize)

            self:setInfoText(EasyDevUtils.getText("easyDevControls_removeAllTireTracksInfo"))
        else
            local radius = EasyDevControlsEnvironmentFrame.RADIUS_TIRE_TRACKS[radiusState]
            local x, _, z = EasyDevUtils.getPlayerWorldLocation(true)

            -- g_currentMission.tireTrackSystem:eraseParallelogram(x - radius, z - radius, x + radius, z - radius, x - radius, z + radius)
            g_currentMission.tireTrackSystem:eraseParallelogram(EasyDevUtils.getArea(x, z, radius))

            self:setInfoText(EasyDevUtils.formatText("easyDevControls_removeTireTracksInfo", self.multiRemoveTireTracksRadius.texts[radiusState]))
        end
    else
        self:setInfoText(EasyDevUtils.getText("easyDevControls_requestFailedMessage"))
    end
end

-- Weather Debug
function EasyDevControlsEnvironmentFrame:onClickWeatherDebug(index, element)
    local active = self:getIsCheckedIndex(index)

    if active and not Weather.DEBUG_ENABLED or not active and Weather.DEBUG_ENABLED then
        g_currentMission.environment.weather:consoleCommandWeatherToggleDebug()

        self:setInfoText(EasyDevUtils.formatText("easyDevControls_weatherDebugInfo", self:getStateText(index, true)))
    end
end

-- Seasonal Shader Debug
function EasyDevControlsEnvironmentFrame:onClickSeasonalShaderDebug(index, element)
    local environment = g_currentMission.environment

    if environment ~= nil then
        if environment.debugSeasonalShaderParameter ~= self:getIsCheckedIndex(index) then
            environment:consoleCommandSeasonalShaderDebug()
        end

        self:setInfoText(EasyDevUtils.formatText("easyDevControls_seasonalShaderDebugInfo", self:getStateText(index, true)))
    else
        self:setInfoText(EasyDevUtils.getText("easyDevControls_requestFailedMessage"))
    end
end

-- Environment Mask System Debug
function EasyDevControlsEnvironmentFrame:onClickEnvironmentMaskDebug(index, element)
    local environment = g_currentMission.environment

    if environment ~= nil and environment.environmentMaskSystem ~= nil then
        local environmentMaskSystem = environment.environmentMaskSystem

        if environmentMaskSystem.isDebugViewActive ~= self:getIsCheckedIndex(index) then
            environmentMaskSystem:consoleCommandToggleDebugView()
        end

        self:setInfoText(EasyDevUtils.formatText("easyDevControls_environmentMaskDebugInfo", self:getStateText(index, true)))
    else
        self:setInfoText(EasyDevUtils.getText("easyDevControls_requestFailedMessage"))
    end
end

-- Random Wind Waving
function EasyDevControlsEnvironmentFrame:onClickRandomWindWaving(index, element)
    if self:getWeatherIsLoaded() then
        local weather = g_currentMission.environment.weather

        if weather.windUpdater.randomWindWaving ~= self:getIsCheckedIndex(index) then
            weather:consoleCommandWeatherToggleRandomWindWaving()
        end

        self:setInfoText(EasyDevUtils.formatText("easyDevControls_randomWindWavingInfo", self:getStateText(index, true)))
    else
        element:setState(1)
        element:setDisabled(true)

        self:setInfoText(EasyDevUtils.getText("easyDevControls_requestFailedMessage"))
    end
end

-- Set Snow
function EasyDevControlsEnvironmentFrame:onSetSnowEnterPressed(element)
    if element.text ~= "" then
        self:setInfoText(self.easyDevControls:updateSnowAndSalt(EasyDevControlsUpdateSnowAndSaltEvent.SET_SNOW, tonumber(element.text)))

        element:setText("")
    end

    element.lastValidText = ""
end

function EasyDevControlsEnvironmentFrame:onSetSnowTextChanged(element, text)
    if text ~= "" then
        local value = tonumber(text)

        if #text == 1 and text == "-" then
            element.lastValidText = text
        elseif value ~= nil then
            if value > SnowSystem.MAX_HEIGHT then
                element.lastValidText = tostring(SnowSystem.MAX_HEIGHT)
                element:setText(element.lastValidText)
            elseif value < -4 then
                element.lastValidText = "-4"
                element:setText(element.lastValidText)
            end

            element.lastValidText = text
        else
            element:setText(element.lastValidText)
        end
    else
        element.lastValidText = ""
    end
end

-- Add / Remove Snow
function EasyDevControlsEnvironmentFrame:onClickAddRemoveSnow(element)
    self:setInfoText(self.easyDevControls:updateSnowAndSalt(EasyDevControlsUpdateSnowAndSaltEvent[element.name]))
end

-- Add Salt
function EasyDevControlsEnvironmentFrame:onClickConfirmAddSalt(element)
    local state = self.multiAddSaltRadius:getState()
    local radius =  EasyDevControlsEnvironmentFrame.RADIUS_SALT[state] or 5

    self:setInfoText(self.easyDevControls:updateSnowAndSalt(EasyDevControlsUpdateSnowAndSaltEvent.ADD_SALT, radius))
end

-- Listeners
function EasyDevControlsEnvironmentFrame:onSettingChanged(id, value)

end

function EasyDevControlsEnvironmentFrame:onHourChanged(currentHour)
    self.multiSetHour:setState(self:getNextHour(currentHour) + 1, true)
end

function EasyDevControlsEnvironmentFrame:onDayChanged(currentDay)
    local environment = g_currentMission.environment

    if environment.daysPerPeriod > 1 then
        self.multiSetDay:setState(environment.currentDayInPeriod, true)
    end
end

function EasyDevControlsEnvironmentFrame:onPeriodChanged(currentPeriod)
    self.multiSetMonth:setState(self:getMonthFromPeriod(currentPeriod))
end

function EasyDevControlsEnvironmentFrame:onPeriodLengthChanged(daysPerPeriod, timeAdjustment)
    local dayText = g_i18n:getText("ui_day")
    local daysPerPeriodTexts = {}

    for i = 1, daysPerPeriod do
        daysPerPeriodTexts[i] = string.format("%s %d", dayText, i)
    end

    self.multiSetDay:setTexts(daysPerPeriodTexts)
    self.multiSetDay:setState(g_currentMission.environment.currentDayInPeriod, true)
    self.multiSetDay:setDisabled(self.setTimeDisabled or daysPerPeriod == 1)
end

function EasyDevControlsEnvironmentFrame:onSeasonChanged(currentSeason)
    if self:getSeasonChanged(currentSeason) then
        self.buttonVariationInfo:setDisabled(true)
        self.buttonConfirmWeather:setDisabled(true)

        self:updateWeatherData(g_currentMission.environment)
    end
end

-- Extra
function EasyDevControlsEnvironmentFrame:getNextHour(currentHour)
    if currentHour == nil then
        currentHour = g_currentMission.environment.currentHour
    end

    return (currentHour + 1) % 24
end

function EasyDevControlsEnvironmentFrame:getMonthFromPeriod(currentPeriod)
    local environment = g_currentMission.environment

    if currentPeriod == nil then
        currentPeriod = environment.currentPeriod
    end

    local month = currentPeriod + 2

    if environment.daylight.latitude < 0 then
        month = month + 6
    end

    return (month - 1) % 12 + 1
end

function EasyDevControlsEnvironmentFrame:getSeasonChanged(season)
    return self.currentSeason ~= season
end

function EasyDevControlsEnvironmentFrame:getWeatherIsLoaded()
    return g_currentMission.environment ~= nil and g_currentMission.environment.weather ~= nil
end

-- Extras
function EasyDevControlsEnvironmentFrame:getResetValues()
    local unchecked = CheckedOptionElement.STATE_UNCHECKED

    return {
        multiRemoveTireTracksRadius = {
            value = 1
        },
        checkedWeatherDebug = {
            value = unchecked
        },
        checkedRandomWindWaving = {
            value = unchecked
        },
        checkedSeasonalShaderDebug = {
            value = unchecked
        },
        checkedEnvironmentMaskDebug = {
            value = unchecked
        },
        multiAddSaltRadius = {
            value = 1
        }
    }
end
