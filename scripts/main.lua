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

local validationFail
local easyDevControls

local modName = g_currentModName or ""
local modDirectory = g_currentModDirectory or ""
local modSettingsDirectory = g_modSettingsDirectory or ""

local buildId = 1.1
local versionString = "0.0.0.0"
local releaseType = "GITHUB"

local loadConsoleCommands = StartParams.getIsSet("consoleCommandsGtX") -- Extra GtX console commands

local function isActive()
    return easyDevControls ~= nil
end

local function isGodModeActive()
    return isActive() and easyDevControls.godMode ~= nil
end

local function enableGodMode()
    if StartParams.getIsSet("devControlsGodMode") and not isGodModeActive() then
        local path = getUserProfileAppPath() .. "gtxSettings/easyDevControls/EasyDevControlsGodMode.lua"

        if fileExists(path) then
            source(path)

            if isGodModeActive() then
                Logging.info("[Easy Development Controls] God Mode is now active!")

                return true
            end
        end
    end

    return false
end

local function validateMod()
    if g_globalMods ~= nil then
        local mod = g_modManager:getModByName(modName)

        if g_globalMods.easyDevControls ~= nil then
            Logging.warning("[Easy Development Controls] Validation of '%s' failed, already loaded by '%s'.", mod.modName, g_globalMods.easyDevControls.modName)

            return false
        end

        versionString = mod.version or versionString

        if mod.modName == "FS22_EasyDevControls" or mod.modName == "FS22_EasyDevControls_update" then
            if mod.author ~= nil and #mod.author == 3 then
                return true
            end
        end

        validationFail = {
            startUpdateTime = 2000,

            update = function(self, dt)
                self.startUpdateTime = self.startUpdateTime - dt

                if self.startUpdateTime < 0 then
                    local text = string.format(g_i18n:getText("easyDevControls_loadError", mod.modName), mod.modName, mod.author or "Unknown")

                    if g_dedicatedServerInfo == nil then
                        if not g_gui:getIsGuiVisible() then
                            g_gui:showYesNoDialog({
                                title = string.format("%s - Version %s", mod.title, versionString),
                                text = text,
                                dialogType = DialogElement.TYPE_LOADING,
                                callback = self.openModHubLink,
                                yesText = g_i18n:getText("button_ok"),
                                noText = g_i18n:getText("button_modHubDownload")
                            })
                        end
                    else
                        print("\n" .. text .. "\n    - https://farming-simulator.com/mods.php?lang=en&country=be&title=fs2022&filter=org&org_id=129652&page=0" .. "\n")
                        self.openModHubLink(true)
                    end
                end
            end,

            openModHubLink = function(ignore)
                if ignore == false then
                    local language = g_languageShort
                    local link = "mods.php?lang=en&country=be&title=fs2022&filter=org&org_id=129652&page=0"
                    if language == "de" or language == "fr" then
                        link = "mods.php?lang=" .. language .. "&country=be&title=fs2022&filter=org&org_id=129652&page=0"
                    end

                    openWebFile(link, "")
                end

                removeModEventListener(validationFail)
                validationFail = nil
            end
        }

        addModEventListener(validationFail)
    end

    return false
end

local function loadFromXMLFile(mission, missionInfo, isMultiplayer)
    if isActive() and mission:getIsServer() then
        local loadDefaultPermissions = true
        local firstTimeLoad = true

        if missionInfo.savegameDirectory ~= nil then
            local xmlFilename = missionInfo.savegameDirectory .. "/easyDevControls.xml"

            if fileExists(xmlFilename) then
                local xmlFile = loadXMLFile("EasyDevControlsXML", xmlFilename)

                if xmlFile ~= nil and xmlFile ~= 0 then
                    easyDevControls:loadSettingsFromXMLFile(xmlFile, "easyDevControls.settings", xmlFilename, missionInfo, mission)

                    if isMultiplayer and easyDevControls.ui ~= nil then
                        if easyDevControls.ui:loadPermissionsFromXMLFile(xmlFile, "easyDevControls.permissions", xmlFilename, missionInfo, mission) then
                            loadDefaultPermissions = false
                        end
                    else
                        loadDefaultPermissions = false
                    end

                    firstTimeLoad = false

                    delete(xmlFile)
                end
            end
        end

        if loadDefaultPermissions and isMultiplayer and easyDevControls.ui ~= nil then
            local xmlFilename = modDirectory .. "resources/defaultPermissions.xml"
            local xmlFile = loadXMLFile("EasyDevControlsDefualtXML", xmlFilename)

            if xmlFile ~= nil and xmlFile ~= 0 then
                easyDevControls.ui:loadPermissionsFromXMLFile(xmlFile, "easyDevControls.permissions", xmlFilename, missionInfo, mission)

                delete(xmlFile)
            end
        end

        return firstTimeLoad
    end

    return false
end

local function saveToXMLFile(missionInfo)
    if isActive() and missionInfo.isValid then
        local mission = g_currentMission
        local xmlFilename = missionInfo.savegameDirectory .. "/easyDevControls.xml"
        local xmlFile = createXMLFile("EasyDevControlsXML", xmlFilename, "easyDevControls")

        if xmlFile ~= nil and xmlFile ~= 0 then
            -- Can help with bug reports
            setXMLString(xmlFile, "easyDevControls#type", releaseType)
            setXMLString(xmlFile, "easyDevControls#version", versionString)
            setXMLFloat(xmlFile, "easyDevControls#buildId", buildId)

            easyDevControls:saveSettingsToXMLFile(xmlFile, "easyDevControls.settings", xmlFilename, missionInfo, mission)

            if (mission.missionDynamicInfo.isMultiplayer or EasyDevControlsUI.FORCE_MULTIPLAYER_MODE) and easyDevControls.ui ~= nil then
                setXMLInt(xmlFile, "easyDevControls.permissions#admin", EasyDevControlsUI.ACCESS_ADMIN)
                setXMLInt(xmlFile, "easyDevControls.permissions#farmManager", EasyDevControlsUI.ACCESS_FARM_MANAGER)
                setXMLInt(xmlFile, "easyDevControls.permissions#standard", EasyDevControlsUI.ACCESS_STANDARD)
                setXMLInt(xmlFile, "easyDevControls.permissions#none", EasyDevControlsUI.ACCESS_NONE)

                easyDevControls.ui:savePermissionsToXMLFile(xmlFile, "easyDevControls.permissions", xmlFilename, missionInfo, mission)
            end

            saveXMLFile(xmlFile)
            delete(xmlFile)
        end
    end
end

local function loadDefaultUserSettings(loadSettings)
    local defaultUserSettings = nil

    -- Create a default settings file if it does not exist
    local xmlFilename = EasyDevUtils.copyFile(modDirectory .. "resources/defaultUserSettings.xml", "defaultUserSettings.xml", "", false)

    if loadSettings and not EasyDevUtils.getIsNilOrEmpty(xmlFilename) and fileExists(xmlFilename) then
        local xmlFile = loadXMLFile("EasyDevControlsClientXML", xmlFilename)

        if xmlFile ~= nil and xmlFile ~= 0 then
            defaultUserSettings = {}

            local toggleHudInputEnabled = Utils.getNoNil(getXMLBool(xmlFile, "defaultUserSettings.general.toggleHudInputEnabled"), false)

            -- No permission for this feature so currently ignored
            easyDevControls.toggleHudInputEnabled = toggleHudInputEnabled

            if false then
                defaultUserSettings.toggleHud = function()
                    if easyDevControls ~= nil then
                        easyDevControls:setToggleHudInputEnabled(toggleHudInputEnabled)

                        if g_messageCenter ~= nil and easyDevControls.isEnabled then
                            g_messageCenter:publish(EasyDevUtils.MESSAGE_TYPE_SETTINGS_CHANGED, EasyDevUtils.SETTING_TOGGLE_HUD_INPUT, toggleHudInputEnabled)
                        end

                        if g_easyDevDevelopmentMode then
                            Logging.info("Easy Development Controls User Setting 'toggleHudInputEnabled': %s", toggleHudInputEnabled)
                        end
                    end
                end
            end

            local maxRunningSpeedInputActive = Utils.getNoNil(getXMLBool(xmlFile, "defaultUserSettings.player.maxRunningSpeedInputActive"), false)
            local maxRunningSpeedMultiplier = EasyDevUtils.getNoNilClamp(getXMLInt(xmlFile, "defaultUserSettings.player.maxRunningSpeedMultiplier"), 2, 14, 4)

            defaultUserSettings.runningSpeed = function(hasPermission)
                if easyDevControls ~= nil then
                    local values = {
                        maxRunningSpeedInputActive = false,
                        maxRunningSpeedMultiplier = 4
                    }

                    if hasPermission then
                        values.maxRunningSpeedInputActive = maxRunningSpeedInputActive
                        values.maxRunningSpeedMultiplier = maxRunningSpeedMultiplier

                        easyDevControls:setRunningSpeedKeyActive(maxRunningSpeedInputActive)
                        easyDevControls:setRunningSpeedMultiplier(maxRunningSpeedMultiplier)
                    else
                        easyDevControls:setRunningSpeedActive(false)
                        easyDevControls:setRunningSpeedKeyActive(false)
                        easyDevControls:setRunningSpeedMultiplier(4)
                    end

                    if g_messageCenter ~= nil and easyDevControls.isEnabled then
                        g_messageCenter:publish(EasyDevUtils.MESSAGE_TYPE_SETTINGS_CHANGED, EasyDevUtils.SETTING_RUNNING_SPEED, values)
                    end

                    if g_easyDevDevelopmentMode then
                        Logging.info("Easy Development Controls User Setting 'maxRunningSpeedInputActive': %s", values.maxRunningSpeedInputActive)
                        Logging.info("Easy Development Controls User Setting 'maxRunningSpeedMultiplier': %d", values.maxRunningSpeedMultiplier)
                    end
                end
            end

            local jumpHeight = EasyDevUtils.getNoNilClamp(getXMLInt(xmlFile, "defaultUserSettings.player.jumpHeight"), 1, 10, 1)

            defaultUserSettings.jumpHeight = function(hasPermission)
                if easyDevControls ~= nil then
                    local hasChange = false
                    local newJumpHeight = 1

                    if hasPermission then
                        newJumpHeight = jumpHeight
                    end

                    if easyDevControls.isEnabled then
                        easyDevControls:setPlayerJumpHeight(newJumpHeight)

                        if g_messageCenter ~= nil then
                            g_messageCenter:publish(EasyDevUtils.MESSAGE_TYPE_SETTINGS_CHANGED, EasyDevUtils.SETTING_JUMP_MULTIPLIER, jumpHeight)
                        end

                        if g_easyDevDevelopmentMode then
                            Logging.info("Easy Development Controls User Setting 'jumpHeight': %d", newJumpHeight)
                        end
                    end
                end
            end

            delete(xmlFile)
        end
    end

    return defaultUserSettings
end

local function load(mission)
    if isActive() then
        easyDevControls:load(mission)

        local isMultiplayer = easyDevControls.isMultiplayer or EasyDevControlsUI.FORCE_MULTIPLAYER_MODE
        local firstTimeLoad = loadFromXMLFile(mission, mission.missionInfo, isMultiplayer)

        easyDevControls.defaultUserSettings = loadDefaultUserSettings(isMultiplayer or firstTimeLoad)

        if easyDevControls.godMode ~= nil then
            g_asyncTaskManager:addTask(function ()
                easyDevControls.godMode:load(mission)
            end)
        end

        mission:registerToLoadOnMapFinished(easyDevControls)
        mission:registerObjectToCallOnMissionStart(easyDevControls)

        addModEventListener(easyDevControls)
    end
end

local function unload(mission)
    if isActive() then
        if easyDevControls.godMode ~= nil then
            removeConsoleCommand("gtxReloadEasyDevGodModeSettings")
            easyDevControls.godMode:delete(mission)
        end

        removeModEventListener(easyDevControls)
        easyDevControls:delete(mission)

        if g_globalMods ~= nil then
            g_globalMods.easyDevControls = nil
        end

        g_easyDevControls = nil
        easyDevControls = nil
    end
end

local function onConnectionFinishedLoading(mission, connection, x, y, z, viewDistanceCoeff)
    if mission:getIsServer() and isActive() then
        easyDevControls:onConnectionFinishedLoading(mission, connection, x, y, z, viewDistanceCoeff)
    end
end

local function registerActionEvents(mission)
    if isActive() then
        easyDevControls:onRegisterActionEvents(mission, mission.inputManager)
    end
end

local function unregisterActionEvents(mission)
    if isActive() then
        easyDevControls:onUnregisterActionEvents(mission, mission.inputManager)
    end
end

local function registerPlayerActionEvents(player)
    if isActive() then
        g_inputBinding:beginActionEventsModification(Player.INPUT_CONTEXT_NAME)
        easyDevControls:onRegisterPlayerActionEvents(player, g_inputBinding)
        g_inputBinding:endActionEventsModification()
    end
end

local function removePlayerActionEvents(player)
    if isActive() then
        g_inputBinding:beginActionEventsModification(Player.INPUT_CONTEXT_NAME)
        easyDevControls:onRemovePlayerActionEvents(player, g_inputBinding)
        g_inputBinding:endActionEventsModification()
    end
end

local function init()
    if validateMod() then
        -- MANAGER
        source(modDirectory .. "scripts/EasyDevControls.lua")

        -- MISC
        source(modDirectory .. "scripts/misc/EasyDevUtils.lua")
        source(modDirectory .. "scripts/misc/EasyDevDebug.lua")
        source(modDirectory .. "scripts/misc/EasyDevHotspotsManager.lua")

        -- EVENTS
        source(modDirectory .. "scripts/events/EasyDevControlsMoneyEvent.lua")
        source(modDirectory .. "scripts/events/EasyDevControlsTimeEvent.lua")
        source(modDirectory .. "scripts/events/EasyDevControlsTeleportEvent.lua")
        source(modDirectory .. "scripts/events/EasyDevControlsSetFieldEvent.lua")
        source(modDirectory .. "scripts/events/EasyDevControlsTimeScaleEvent.lua")
        source(modDirectory .. "scripts/events/EasyDevControlsPermissionsEvent.lua")
        source(modDirectory .. "scripts/events/EasyDevControlsSpawnObjectEvent.lua")
        source(modDirectory .. "scripts/events/EasyDevControlsDeleteObjectEvent.lua")
        source(modDirectory .. "scripts/events/EasyDevControlsTipHeightTypeEvent.lua")
        source(modDirectory .. "scripts/events/EasyDevControlsSuperStrengthEvent.lua")
        source(modDirectory .. "scripts/events/EasyDevControlsAddRemoveDeltaEvent.lua")
        source(modDirectory .. "scripts/events/EasyDevControlsSetFillUnitFillLevel.lua")
        source(modDirectory .. "scripts/events/EasyDevControlsVehicleConditionEvent.lua")
        source(modDirectory .. "scripts/events/EasyDevControlsClearHeightTypeEvent.lua")
        source(modDirectory .. "scripts/events/EasyDevControlsRemoveAllObjectsEvent.lua")
        source(modDirectory .. "scripts/events/EasyDevControlsObjectFarmChangeEvent.lua")
        source(modDirectory .. "scripts/events/EasyDevControlsUpdateSnowAndSaltEvent.lua")
        source(modDirectory .. "scripts/events/EasyDevControlsVineSystemSetStateEvent.lua")
        source(modDirectory .. "scripts/events/EasyDevControlsUpdateSetGrowthPeriodEvent.lua")
        source(modDirectory .. "scripts/events/EasyDevControlsVehicleOperatingValueEvent.lua")
        source(modDirectory .. "scripts/events/EasyDevControlsSetProductionPointFillLevelsEvent.lua")

        -- GUI
        source(modDirectory .. "scripts/gui/EasyDevControlsUI.lua")

        source(modDirectory .. "scripts/gui/dialogs/DynamicSelectionDialog.lua")
        source(modDirectory .. "scripts/gui/dialogs/DynamicListDialog.lua")
        source(modDirectory .. "scripts/gui/EasyDevControlsTeleportScreen.lua")
        source(modDirectory .. "scripts/gui/EasyDevControlsTabbedMenu.lua")

        source(modDirectory .. "scripts/gui/EasyDevControlsBaseFrame.lua")
        source(modDirectory .. "scripts/gui/EasyDevControlsGeneralFrame.lua")
        source(modDirectory .. "scripts/gui/EasyDevControlsPlayerFrame.lua")
        source(modDirectory .. "scripts/gui/EasyDevControlsObjectsFrame.lua")
        source(modDirectory .. "scripts/gui/EasyDevControlsVehiclesFrame.lua")
        source(modDirectory .. "scripts/gui/EasyDevControlsPlaceablesFrame.lua")
        source(modDirectory .. "scripts/gui/EasyDevControlsFieldsFrame.lua")
        source(modDirectory .. "scripts/gui/EasyDevControlsEnvironmentFrame.lua")
        source(modDirectory .. "scripts/gui/EasyDevControlsPermissionsFrame.lua")
        source(modDirectory .. "scripts/gui/EasyDevControlsHelpFrame.lua")

        easyDevControls = EasyDevControls.new(g_server ~= nil, g_client ~= nil, buildId, versionString, releaseType, loadConsoleCommands)

        if easyDevControls ~= nil then
            easyDevControls:setDevelopmentMode(buildId == 0)

            g_globalMods.easyDevControls = easyDevControls -- Global access, if abused will be removed. Thanks @Rahkiin for adding this, plus mod fillTypes on console and many other things when I asked :-)
            g_easyDevControls = easyDevControls -- Not a true global, just for internal mod environment use.

            -- GtX only features and testing suite ;-)
            if enableGodMode() then
                easyDevControls.consoleCommandReloadEasyDevGodModeSettings = function(self, ...)
                    if self.godMode ~= nil and self.godMode.reloadSettingsFile ~= nil then
                        return self.godMode:reloadSettingsFile(...)
                    end

                    return "Failed to refresh God Mode settings"
                end

                addConsoleCommand("gtxReloadEasyDevGodModeSettings", "Reload God Mod settings file", "consoleCommandReloadEasyDevGodModeSettings", easyDevControls)
            end

            FSCareerMissionInfo.saveToXMLFile = Utils.appendedFunction(FSCareerMissionInfo.saveToXMLFile, saveToXMLFile)
            Mission00.load = Utils.prependedFunction(Mission00.load, load)
            FSBaseMission.delete = Utils.appendedFunction(FSBaseMission.delete, unload)
            FSBaseMission.onConnectionFinishedLoading = Utils.appendedFunction(FSBaseMission.onConnectionFinishedLoading, onConnectionFinishedLoading)

            FSBaseMission.registerActionEvents = Utils.appendedFunction(FSBaseMission.registerActionEvents, registerActionEvents)
            BaseMission.unregisterActionEvents = Utils.appendedFunction(BaseMission.unregisterActionEvents, unregisterActionEvents)

            Player.registerActionEvents = Utils.appendedFunction(Player.registerActionEvents, registerPlayerActionEvents)
            Player.removeActionEvents = Utils.appendedFunction(Player.removeActionEvents, removePlayerActionEvents)
        end
    end
end

init()
