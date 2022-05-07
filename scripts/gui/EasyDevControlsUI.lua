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

EasyDevControlsUI = {}

local EasyDevControlsUI_mt = Class(EasyDevControlsUI)
local EMPTY_TABLE = {}

EasyDevControlsUI.FORCE_MULTIPLAYER_MODE = false

EasyDevControlsUI.ACCESS_ADMIN = 1
EasyDevControlsUI.ACCESS_FARM_MANAGER = 2
EasyDevControlsUI.ACCESS_STANDARD = 3
EasyDevControlsUI.ACCESS_NONE = 4

EasyDevControlsUI.ACCESS_NAMES = {
    "ADMIN",
    "FARM_MANAGER",
    "STANDARD",
    "NONE"
}

function EasyDevControlsUI.new(isServer, isClient, easyDevControls, isMultiplayer, mission)
    local self = setmetatable({}, EasyDevControlsUI_mt)

    self.isServer = isServer
    self.isClient = isClient

    self.easyDevControls = easyDevControls
    self.isMultiplayer = isMultiplayer

    self.customEnvironment = EasyDevUtils.getCustomEnvironment()
    self.baseDirectory = EasyDevUtils.getBaseDirectory()

    self.modConflicts = {}
    self.helpPages = {}

    self.accessLevel = EasyDevControlsUI.ACCESS_NONE
    self.iconsUIFilename = self.baseDirectory .. "resources/ui_icons.dds"

    self:initializePermissions()

    return self
end

function EasyDevControlsUI:load(isReload)
    if self.isClient then
        if isReload and g_easyDevDevelopmentMode then
            if self.dynamicSelectionDialog ~= nil then
                self.dynamicSelectionDialog:delete()
                self.dynamicSelectionDialog = nil
            end

            if self.dynamicListDialog ~= nil then
                self.dynamicListDialog:delete()
                self.dynamicListDialog = nil
            end

            if self.menu ~= nil then
                self.menu:delete()
                self.menu = nil

                self.helpPages = {}
                self:reloadTextsFromModDesc()
            end
        end

        -- Load Help
        self:loadHelpFromXMLFile()

        -- Load Profiles
        g_gui:loadProfiles(self.baseDirectory .. "gui/guiProfiles.xml")

        -- Load Frames
        local generalFrame = EasyDevControlsGeneralFrame.new(self, self.easyDevControls, self.accessLevel)
        local playerFrame = EasyDevControlsPlayerFrame.new(self, self.easyDevControls, self.accessLevel)
        local objectsFrame = EasyDevControlsObjectsFrame.new(self, self.easyDevControls, self.accessLevel)
        local vehiclesFrame = EasyDevControlsVehiclesFrame.new(self, self.easyDevControls, self.accessLevel)
        local placeablesFrame = EasyDevControlsPlaceablesFrame.new(self, self.easyDevControls, self.accessLevel)
        local fieldsFrame = EasyDevControlsFieldsFrame.new(self, self.easyDevControls, self.accessLevel)
        local environmentFrame = EasyDevControlsEnvironmentFrame.new(self, self.easyDevControls, self.accessLevel)
        local permissionsFrame = EasyDevControlsPermissionsFrame.new(self, self.easyDevControls)
        local helpFrame = EasyDevControlsHelpFrame.new(self, self.easyDevControls, self.helpPages)

        -- Load Dialogs
        self.dynamicSelectionDialog = DynamicSelectionDialog.new(self, self.easyDevControls, self.accessLevel)
        self.dynamicListDialog = DynamicListDialog.new(self, self.easyDevControls, self.accessLevel)

        -- Load Teleport Screen
        self.mapTeleportScreen = EasyDevControlsTeleportScreen.new(self, self.easyDevControls, self.accessLevel)

        -- Load Tabbed Menu
        self.menu = EasyDevControlsTabbedMenu.new(g_messageCenter, g_i18n, g_inputBinding, self, self.accessLevel)

        -- Load GUI
        g_gui:loadGui(self.baseDirectory .. "gui/EasyDevControlsGeneralFrame.xml", "EasyDevControlsGeneralFrame", generalFrame, true)
        g_gui:loadGui(self.baseDirectory .. "gui/EasyDevControlsPlayerFrame.xml", "EasyDevControlsPlayerFrame", playerFrame, true)
        g_gui:loadGui(self.baseDirectory .. "gui/EasyDevControlsObjectsFrame.xml", "EasyDevControlsObjectsFrame", objectsFrame, true)
        g_gui:loadGui(self.baseDirectory .. "gui/EasyDevControlsVehiclesFrame.xml", "EasyDevControlsVehiclesFrame", vehiclesFrame, true)
        g_gui:loadGui(self.baseDirectory .. "gui/EasyDevControlsPlaceablesFrame.xml", "EasyDevControlsPlaceablesFrame", placeablesFrame, true)
        g_gui:loadGui(self.baseDirectory .. "gui/EasyDevControlsFieldsFrame.xml", "EasyDevControlsFieldsFrame", fieldsFrame, true)
        g_gui:loadGui(self.baseDirectory .. "gui/EasyDevControlsEnvironmentFrame.xml", "EasyDevControlsEnvironmentFrame", environmentFrame, true)
        g_gui:loadGui(self.baseDirectory .. "gui/EasyDevControlsPermissionsFrame.xml", "EasyDevControlsPermissionsFrame", permissionsFrame, true)
        g_gui:loadGui(self.baseDirectory .. "gui/EasyDevControlsHelpFrame.xml", "EasyDevControlsHelpFrame", helpFrame, true)

        g_gui:loadGui(self.baseDirectory .. "gui/dialogs/DynamicSelectionDialog.xml", "DynamicSelectionDialog", self.dynamicSelectionDialog)
        g_gui:loadGui(self.baseDirectory .. "gui/dialogs/DynamicListDialog.xml", "DynamicListDialog", self.dynamicListDialog)

        g_gui:loadGui(self.baseDirectory .. "gui/EasyDevControlsTeleportScreen.xml", "EasyDevControlsTeleportScreen", self.mapTeleportScreen)
        g_gui:loadGui(self.baseDirectory .. "gui/EasyDevControlsTabbedMenu.xml", "EasyDevControlsTabbedMenu", self.menu)

        -- Initialise if required
        self.mapTeleportScreen:setIngameMap(g_currentMission.hud:getIngameMap())
        self.mapTeleportScreen:setTerrainSize(g_currentMission.terrainSize)
    end

    if not isReload then
        if not self.isMultiplayer then
            local mod = g_modManager:getModByName(self.customEnvironment)

            -- Only when unzipped for easy updating of the translation files.
            if mod ~= nil and mod.fileHash == nil then
                addConsoleCommand("gtxReloadEasyDevControlsTranslations", "Reloads the translation files for the current language. Helper command for translators", "consoleCommandReloadTranslations", self)
            end

            -- Permission testing for development only
            if g_easyDevDevelopmentMode then
                addConsoleCommand("gtxSetEasyDevControlsAccessLevel", "Forces the given access level. [accessLevel]", "consoleCommandSetAccessLevel", self)
            end
        end

        FocusManager:setGui("MPLoadingScreen") -- Reset focus so that pressing 'Q' or 'A' before mission start does not cause errors

        g_messageCenter:subscribe(PlayerPermissionsEvent, self.onPermissionsChanged, self)
        g_messageCenter:subscribe(MessageType.MASTERUSER_ADDED, self.onMasterUserAdded, self)
        g_messageCenter:subscribe(MessageType.PLAYER_FARM_CHANGED, self.onPlayerFarmChanged, self)

        if GameSettings.SETTING.USE_COLORBLIND_MODE ~= nil then
            g_messageCenter:subscribe(MessageType.SETTING_CHANGED[GameSettings.SETTING.USE_COLORBLIND_MODE], self.onColourBlindModeChanged, self)
        end
    end

    return true
end

function EasyDevControlsUI:onMissionStarted()
    if self.easyDevControls.isEnabled then
        return
    end

    g_asyncTaskManager:addTask(function ()
        self:onAccessLevelChanged(true)
    end)
end

function EasyDevControlsUI:delete()
    g_messageCenter:unsubscribeAll(self)

    removeConsoleCommand("gtxReloadEasyDevControlsTranslations")
    removeConsoleCommand("gtxSetEasyDevControlsAccessLevel")
end

function EasyDevControlsUI:initializePermissions()
    self.permissions = {}

    if self.isMultiplayer or EasyDevControlsUI.FORCE_MULTIPLAYER_MODE then
        local getSuperStrengthDisabled = function()
            return not self.easyDevControls.superStrengthAvailable
        end

        self.indexedPagePermissions = {
            {
                key = "general",
                title = "easyDevControls_generalHeader",
                permissions = {
                    {key = "cheatMoney", toolTipParams = "easyDevControls_addMoneyTitle|easyDevControls_removeMoneyTitle|easyDevControls_setMoneyTitle", title = "easyDevControls_cheatMoneyTitle"},
                    {key = "teleport", title = "easyDevControls_teleportTitle", minimumLevel = EasyDevControlsUI.ACCESS_STANDARD},
                    {key = "flipVehicles", title = "easyDevControls_flipVehiclesTitle", minimumLevel = EasyDevControlsUI.ACCESS_STANDARD}
                }
            },
            {
                key = "player",
                title = "easyDevControls_playerHeader",
                permissions = {
                    {key = "superStrength", title = "easyDevControls_superStrengthTitle", minimumLevel = EasyDevControlsUI.ACCESS_STANDARD, getIsDisabled = getSuperStrengthDisabled},
                    {key = "jumpHeight", title = "easyDevControls_jumpMultiplierTitle", minimumLevel = EasyDevControlsUI.ACCESS_NONE, defualtValue = EasyDevControlsUI.ACCESS_NONE},
                    {key = "runningSpeed", title = "easyDevControls_runSpeedTitle", minimumLevel = EasyDevControlsUI.ACCESS_NONE, defualtValue = EasyDevControlsUI.ACCESS_NONE},
                    {key = "setFarm", title = "easyDevControls_setFarmTitle", disabled = true}
                }
            },
            {
                key = "objects",
                title = "easyDevControls_objectsHeader",
                permissions = {
                    {key = "addBale", title = "easyDevControls_addBaleTitle", minimumLevel = EasyDevControlsUI.ACCESS_STANDARD},
                    {key = "addPallet", title = "easyDevControls_addPalletTitle", minimumLevel = EasyDevControlsUI.ACCESS_STANDARD},
                    {key = "addLog", title = "easyDevControls_addLogTitle", minimumLevel = EasyDevControlsUI.ACCESS_STANDARD}
                }
            },
            {
                key = "vehicles",
                title = "easyDevControls_vehiclesHeader",
                permissions = {
                    {key = "vehicleFillLevel", title = "easyDevControls_fillUnitFillLevelTitle"},
                    {key = "vehicleCondition", title = "easyDevControls_vehicleConditionTitle"},
                    {key = "vehicleFuel", title = "easyDevControls_vehicleFuelTitle"},
                    {key = "vehicleMotorTemp", title = "easyDevControls_vehicleMotorTempTitle"},
                    {key = "vehicleOperatingTime", title = "easyDevControls_vehicleOperatingTimeTitle"}
                }
            },
            {
                key = "placeables",
                title = "easyDevControls_placeablesHeader",
                permissions = {
                    {key = "productionPoints", title = "easyDevControls_productionPointTitle"}
                }
            },
            {
                key = "fields",
                title = "easyDevControls_fieldsHeader",
                permissions = {
                    {key = "fieldSetFruit", title = "easyDevControls_fieldSetFruitTitle"},
                    {key = "fieldSetGround", title = "easyDevControls_fieldSetGroundTitle"},
                    {key = "vineSetState", title = "easyDevControls_vineSetStateTitle"},
                    {key = "addRemoveWeedsStones", toolTipParams = "easyDevControls_weedStateTitle|easyDevControls_stonesStateTitle", title = "easyDevControls_addRemoveWeedsStonesTitle"},
                    {key = "updateGrowthSystem", title = "easyDevControls_advanceGrowthTitle"}
                }
            },
            {
                key = "environment",
                title = "easyDevControls_environmentHeader",
                permissions = {
                    {key = "setTime", title = "easyDevControls_setTimeTitle"},
                    {key = "updateSnow", toolTipParams = "easyDevControls_addSnowTitle|easyDevControls_removeSnowTitle|easyDevControls_setSnowTitle", title = "easyDevControls_updateSnowTitle"},
                    {key = "addSalt", title = "easyDevControls_addSaltTitle", minimumLevel = EasyDevControlsUI.ACCESS_STANDARD}
                }
            }
        }

        for _, page in ipairs (self.indexedPagePermissions) do
            for _, permission in ipairs (page.permissions) do
                self.permissions[permission.key] = permission.defualtValue or EasyDevControlsUI.ACCESS_ADMIN
            end
        end

        return true
    end

    return false
end

function EasyDevControlsUI:savePermissionsToXMLFile(xmlFile, key, xmlFilename, missionInfo, mission)
    if self.permissions == nil or self.indexedPagePermissions == nil then
        return false
    end

    for _, page in ipairs (self.indexedPagePermissions) do
        for _, permission in ipairs (page.permissions) do
            local permissionKey = permission.key

            setXMLInt(xmlFile, string.format("%s.%s.%s", key, page.key, permissionKey), EasyDevControlsUI.getValidPermissionLevel(self.permissions[permissionKey]))
        end
    end
end

function EasyDevControlsUI:loadPermissionsFromXMLFile(xmlFile, key, xmlFilename, missionInfo, mission)
    if self.permissions == nil or self.indexedPagePermissions == nil then
        if not self:initializePermissions() then
            return false
        end
    end

    for _, page in ipairs (self.indexedPagePermissions) do
        for _, permission in ipairs (page.permissions) do
            local permissionKey = permission.key

            self.permissions[permissionKey] = EasyDevControlsUI.getValidPermissionLevel(getXMLInt(xmlFile, string.format("%s.%s.%s", key, page.key, permissionKey)), permission.defualtValue)
        end
    end

    return table.size(self.permissions) > 0
end

function EasyDevControlsUI:loadHelpFromXMLFile()
    local xmlFilename = self.baseDirectory .. "resources/help.xml"
    local xmlFile = loadXMLFile("helpXML", xmlFilename)

    if xmlFile ~= nil and xmlFile ~= 0 then
        local i = 0

        while true do
            local key = string.format("help.page(%d)", i)

            if not hasXMLProperty(xmlFile, key) then
                break
            end

            if not Utils.getNoNil(getXMLBool(xmlFile, key .. "#multiplayerOnly"), false) or (self.isMultiplayer or EasyDevControlsUI.FORCE_MULTIPLAYER_MODE) then
                local page = {
                    title = EasyDevUtils.convertText(getXMLString(xmlFile, key .. "#title") or "Missing Title: " .. key),
                    name = getXMLString(xmlFile, key .. "#name"),
                    commands = {}
                }

                local j = 0

                while true do
                    local commandKey = string.format("%s.command(%d)", key, j)

                    if not hasXMLProperty(xmlFile, commandKey) then
                        break
                    end

                    local text = ""
                    local name = getXMLString(xmlFile, commandKey .. "#name")
                    local title = getXMLString(xmlFile, commandKey .. "#title")

                    if name == nil or self.modConflicts[name] == nil then
                        text = getXMLString(xmlFile, commandKey .. "#text") or text

                        local params = getXMLString(xmlFile, commandKey .. "#params")
                        local getParamsFunc = getXMLString(xmlFile, commandKey .. "#getParamsFunc")

                        if params ~= nil then
                            local paramsFormatting = getXMLString(xmlFile, commandKey .. "#paramsFormatting")

                            params = params:split("|")

                            for index = 1, #params do
                                params[index] = EasyDevUtils.convertText(params[index])
                            end

                            if paramsFormatting ~= nil then
                                text = string.gsub(EasyDevUtils.convertText(text) .. paramsFormatting, "\\([n])", "\n")
                            end

                            text = EasyDevUtils.formatConvertedText(text, unpack(params))
                        elseif getParamsFunc ~= nil then
                            local funcTarget = self
                            local func = funcTarget[getParamsFunc]

                            if func == nil then
                                funcTarget = self.easyDevControls
                                func = funcTarget[getParamsFunc]
                            end

                            if func ~= nil then
                                -- local funcArgs = getXMLString(xmlFile, commandKey .. "#funcArgs")

                                -- if funcArgs ~= nil then
                                    -- funcArgs = funcArgs:split("|")

                                    -- for index, arg in ipairs (funcArgs) do
                                        -- if arg == "true" then
                                            -- funcArgs[index] = true
                                        -- elseif arg == "false" then
                                            -- funcArgs[index] = false
                                        -- elseif tonumber(arg) ~= nil then
                                            -- funcArgs[index] = tonumber(arg)
                                        -- end
                                    -- end
                                -- else
                                    -- funcArgs = EMPTY_TABLE
                                -- end

                                -- text = EasyDevUtils.formatConvertedText(text, func(funcTarget, unpack(funcArgs)))
                                text = EasyDevUtils.formatConvertedText(text, func(funcTarget))
                            else
                                EasyDevUtils.devInfo("Function with name '%s' could not be found in help page XML '%s'!", getParamsFunc, xmlFilename)
                            end
                        else
                            text = EasyDevUtils.convertText(text)
                        end
                    else
                        local conflictInfo = self.modConflicts[name]

                        text = EasyDevUtils.formatText("easyDevControls_modConflictWarning", conflictInfo.modName or "N/A", conflictInfo.author or "- - -")
                    end

                    if title ~= nil and text ~= "" then
                        table.insert(page.commands, {
                            title = EasyDevUtils.convertText(title),
                            text = text,
                            name = name
                        })
                    end

                    j = j + 1
                end

                if page.name == "PERMISSIONS" then
                    for _, pagePermission in ipairs (self.indexedPagePermissions) do
                        local text = ""

                        for index, permission in ipairs (pagePermission.permissions) do
                            if index > 1 then
                                text = string.format("%s\n-    %s", text, EasyDevUtils.getText(permission.title))
                            else
                                text = string.format("-    %s", EasyDevUtils.getText(permission.title))
                            end
                        end

                        table.insert(page.commands, {
                            title = EasyDevUtils.getText(pagePermission.title),
                            text = text
                        })
                    end
                end

                table.insert(self.helpPages, page)
            end

            i = i + 1
        end

        delete(xmlFile)
    else
        EasyDevUtils.devInfo("Failed to open help page XML with filename '%s'!", xmlFilename)
    end
end

function EasyDevControlsUI:reloadTextsFromModDesc()
    local l10nPrefix = self.baseDirectory .. "translations/translation_"

    for _, languageCode in ipairs({g_languageShort, "en", "de"}) do
        local l10nFilename = l10nPrefix .. languageCode .. ".xml"

        if fileExists(l10nFilename) then
            local l10nXmlFile = loadXMLFile("modL10n", l10nFilename)

            if l10nXmlFile ~= nil then
                local i = 0

                while true do
                    local key = string.format("l10n.texts.text(%d)", i)

                    if not hasXMLProperty(l10nXmlFile, key) then
                        break
                    end

                    local name = getXMLString(l10nXmlFile, key .. "#name")
                    local text = getXMLString(l10nXmlFile, key .. "#text")

                    if name ~= nil and text ~= nil then
                        if g_i18n.texts[name] ~= text then
                            g_i18n.texts[name] = string.gsub(text, "\r\n", "\n")

                            EasyDevUtils.devInfo("Update text for l10n entry '%s'", name)
                        end
                    end

                    i = i + 1
                end

                delete(l10nXmlFile)

                return
            end
        end
    end

    EasyDevUtils.devInfo("No l10n files found with prefix '%s'!", l10nPrefix)
end

function EasyDevControlsUI:checkModConflicts()
    self.modConflicts = {}

    -- This mod sadly does hard overwrites instead of using an event to sync
    if g_modIsLoaded["FS22_LumberJack"] then
        self.modConflicts.superStrength = {
            modName = "FS22_LumberJack",
            author = "Loki_79"
        }

        self.easyDevControls.superStrengthAvailable = false
    else
        Player.MAX_PICKABLE_OBJECT_MASS = 0.2
        Player.MAX_PICKABLE_OBJECT_DISTANCE = 3
    end

    -- No need for the testing mode if this is active
    if g_modIsLoaded["FS22_3rdPerson"] then
        self.modConflicts.thirdPersonView = {
            modName = "FS22_3rdPerson",
            author = "ViperGTS96"
        }

        self.easyDevControls.thirdPersonAvailable = false
    end
end

function EasyDevControlsUI:getTranslationParams()
    local l10nPrefix = self.baseDirectory .. "translations/translation_"

    local contributorsText = ""
    local languageContributors = {}

    for k, v in ipairs (g_availableLanguagesTable) do
        local languageName = g_availableLanguageNamesTable[k]
        local languageCode = getLanguageCode(v)

        if languageName ~= nil and languageCode ~= nil then
            local l10nFilename = l10nPrefix .. languageCode .. ".xml"

            if fileExists(l10nFilename) then
                local l10nXmlFile = loadXMLFile("modL10n", l10nFilename)
                local language = {
                    name = languageName,
                    contributors = {}
                }

                local i = 0

                while true do
                    local key = string.format("l10n.contributors.name(%d)", i)

                    if not hasXMLProperty(l10nXmlFile, key) then
                        break
                    end

                    local contributor = getXMLString(l10nXmlFile, key)

                    if contributor ~= nil then
                        table.insert(language.contributors, contributor)
                    end

                    i = i + 1
                end

                delete(l10nXmlFile)

                table.insert(languageContributors, language)
            end
        end
    end

    for _, language in ipairs (languageContributors) do
        local languageName = language.name

        -- Localise only when game is operating in that language
        if g_languageShort ~= "de" and languageName == "Deutsch" then
            languageName = "German"
        elseif g_languageShort ~= "pl" and languageName == "Polski" then
            languageName = "Polish"
        elseif g_languageShort ~= "it" and languageName == "Italiano" then
            languageName = "Italian"
        end

        contributorsText = contributorsText .. string.format("%s: %s\n", languageName, table.concat(language.contributors, ", "))
    end

    return contributorsText
end

function EasyDevControlsUI:getReleaseParams()
    local edc = self.easyDevControls

    local text = "Release: %s\nVersion: %s\nBuild: %s"
    local newLine = "\n\n"

    if edc.godMode ~= nil then
        text = text .. newLine .. "God Mode: Yes"
        newLine = "\n"
    end

    if g_easyDevDevelopmentMode then
        text = text .. newLine .. "Development: Yes"
        newLine = "\n"
    end

    if EasyDevControlsUI.FORCE_MULTIPLAYER_MODE then
        text = text .. newLine .. "Forced MP: Yes"
        newLine = "\n"
    end

    return string.format(text, edc.releaseType, edc.versionString, edc.buildId)
end

function EasyDevControlsUI:onPermissionsChanged(userId)
    if userId == g_currentMission.playerUserId then
        self:onAccessLevelChanged()
    end
end

function EasyDevControlsUI:onMasterUserAdded(user)
    if user:getId() == g_currentMission.playerUserId then
        self:onAccessLevelChanged()
    end
end

function EasyDevControlsUI:onPlayerFarmChanged(player)
    if player == g_currentMission.player then
        self:onAccessLevelChanged()

        if g_easyDevHotspotsManager ~= nil then
            g_easyDevHotspotsManager:onPlayerFarmChanged(player, player.farmId)
        end
    end
end

function EasyDevControlsUI:onColourBlindModeChanged(useColorBlindMode)
    if g_easyDevHotspotsManager ~= nil then
        g_easyDevHotspotsManager:onColourBlindModeChanged(useColorBlindMode)
    end
end

function EasyDevControlsUI:setPermission(key, accessLevel, suppressInfo, userSetting)
    local currentLevel = self.permissions[key]

    if currentLevel ~= nil then
        accessLevel = EasyDevControlsUI.getValidPermissionLevel(accessLevel, currentLevel)

        self.permissions[key] = accessLevel

        if userSetting and self.easyDevControls.defaultUserSettings ~= nil then
            local userSettingFunc = self.easyDevControls.defaultUserSettings[key]

            if userSettingFunc ~= nil then
                userSettingFunc(self:getHasPermission(key, EasyDevControlsUI.ACCESS_NONE))
            end
        end

        if accessLevel ~= currentLevel and not suppressInfo then
            Logging.info("Easy Development Controls Permission '%s': %d", key, accessLevel)
        end

        return true
    end

    return false
end

function EasyDevControlsUI:getHasPermission(key, defaultLevel)
    if self.isMultiplayer or EasyDevControlsUI.FORCE_MULTIPLAYER_MODE then
        defaultLevel = defaultLevel or EasyDevControlsUI.ACCESS_ADMIN

        return self.accessLevel <= (self.permissions[key] or defaultLevel)
    end

    return true
end

function EasyDevControlsUI:getPermissions()
    return self.permissions or EMPTY_TABLE
end

function EasyDevControlsUI:getAccessLevel()
    return self.accessLevel
end

function EasyDevControlsUI:onAccessLevelChanged(force)
    local accessLevel = EasyDevControlsUI.ACCESS_NONE

    if g_dedicatedServer == nil then
        local farm = g_farmManager:getFarmById(g_currentMission:getFarmId())

        if farm ~= nil and not farm.isSpectator then
            accessLevel = EasyDevControlsUI.ACCESS_STANDARD

            if self.isServer or g_currentMission.isMasterUser then
                accessLevel = EasyDevControlsUI.ACCESS_ADMIN
            elseif farm:isUserFarmManager(g_currentMission.playerUserId) then
                accessLevel = EasyDevControlsUI.ACCESS_FARM_MANAGER
            end
        end
    else
        accessLevel = EasyDevControlsUI.ACCESS_ADMIN
    end

    if (accessLevel ~= self.accessLevel) or (force == true) then
        self.accessLevel = accessLevel

        g_messageCenter:publish(EasyDevUtils.MESSAGE_TYPE_ACCESS_LEVEL_CHANGED, accessLevel)

        local easyDevControls = self.easyDevControls

        if easyDevControls.isEnabled and easyDevControls.defaultUserSettings ~= nil then
            for key, func in pairs (easyDevControls.defaultUserSettings) do
                func(self:getHasPermission(key, EasyDevControlsUI.ACCESS_NONE))
            end
        end

        EasyDevUtils.devInfo("Access level changed to %s (%d)", EasyDevControlsUI.ACCESS_NAMES[accessLevel], accessLevel)
    end
end

function EasyDevControlsUI:onOpenMenu(isReload, pageIndex)
    if not g_currentMission.isSynchronizingWithPlayers and not g_gui:getIsGuiVisible() then
        if isReload and self.menu ~= nil then
            self.menu:setSoundSuppressed(true)

            self.activeMenu = g_gui:showGui("EasyDevControlsTabbedMenu")

            if pageIndex ~= nil then
                self.menu:setSoundSuppressed(true)
                self.menu.pageSelector:setState(pageIndex, true)
                self.menu:setSoundSuppressed(false)
                -- self.menu:onAccessLevelChanged(self.accessLevel)
            end

            return
        end

        self.activeMenu = g_gui:showGui("EasyDevControlsTabbedMenu")
    end
end

function EasyDevControlsUI:showDynamicSelectionDialog(args)
    local dialog = g_gui.guis.DynamicSelectionDialog

    if dialog ~= nil and args ~= nil then
        local target = dialog.target

        target:setHeader(args.headerText, args.hideBackground)
        target:setCallback(args.callback, args.target)
        target:setNotifyOnClose(args.onCloseTarget, args.onCloseArguments)
        target:setConfirmButtonDisabled(args.confirmButtonDisabled, args.confirmButtonAction)
        target:setButtonTexts(args.confirmText, args.backText)
        target:setAvailableProperties(args.properties, args.numHorizontal, args.numVertical, args.numVerticalClosePerRow, args.flowDirection)

        g_gui:showDialog("DynamicSelectionDialog") -- Need to resize before calling 'showDialog' so blur is correct

        return target
    end

    return
end

function EasyDevControlsUI:showDynamicListDialog(args)
    local dialog = g_gui.guis.DynamicListDialog

    if dialog ~= nil and args ~= nil then
        local target = dialog.target

        target:setHeader(args.headerText, args.hideBackground)
        target:setCallback(args.callback, args.target, args.clearCallbackFunc)
        target:setList(args.list, args.updateOnOpen)

        g_gui:showDialog("DynamicListDialog") -- Need to resize before calling 'showDialog' so blur is correct

        return target
    end

    return
end

function EasyDevControlsUI:getActiveMenu()
    return self.activeMenu
end

function EasyDevControlsUI:getDynamicSelectionDialog()
    return self.dynamicSelectionDialog
end

function EasyDevControlsUI:getDynamicListDialog()
    return self.dynamicListDialog
end

function EasyDevControlsUI.getValidPermissionLevel(level, default)
    if level == nil or (level > EasyDevControlsUI.ACCESS_NONE or level < EasyDevControlsUI.ACCESS_ADMIN) then
        return default or EasyDevControlsUI.ACCESS_ADMIN
    end

    return level
end

function EasyDevControlsUI:consoleCommandReloadTranslations()
    if self.isMultiplayer then
        return "Command is for SP updating of translation only!"
    end

    local currentGui = g_gui.currentGui
    local oldDevMode = g_easyDevDevelopmentMode

    local pageIndex = nil
    local openOnReload = false
    local returnText = "Reloading of 'Easy Development Controls' translation file and UI failed!"

    if currentGui ~= nil and currentGui == self:getActiveMenu() then
        if self.menu ~= nil and self.menu.pagingElement ~= nil then
            pageIndex = self.menu.pagingElement.currentPageIndex
        end

        currentGui:setSoundSuppressed(true)
        openOnReload = true
    end

    g_gui:showGui("")
    g_easyDevDevelopmentMode = true

    if self:load(true) then
        if openOnReload then
            self:onOpenMenu(true, pageIndex)
        end

        g_easyDevDevelopmentMode = oldDevMode

        self.accessLevel = EasyDevControlsUI.ACCESS_ADMIN
        g_messageCenter:publish(EasyDevUtils.MESSAGE_TYPE_ACCESS_LEVEL_CHANGED, self.accessLevel)

        returnText = "Translation files reloaded and 'Easy Development Controls' UI successfully updated"
    else
        g_easyDevDevelopmentMode = oldDevMode
    end

    return returnText
end

function EasyDevControlsUI:consoleCommandSetAccessLevel(levelName)
    if self.isMultiplayer or not g_easyDevDevelopmentMode then
        return "Command is for Development SP testing by GtX only!"
    end

    local accessLevel = EasyDevControlsUI.ACCESS_STANDARD

    levelName = levelName ~= nil and levelName:upper() or "STANDARD"

    if levelName == "ADMIN" then
        accessLevel = EasyDevControlsUI.ACCESS_ADMIN
    elseif levelName == "FARM_MANAGER" then
        accessLevel = EasyDevControlsUI.ACCESS_FARM_MANAGER
    elseif levelName == "NONE" then
        accessLevel = EasyDevControlsUI.ACCESS_NONE
    else
        levelName = "STANDARD"
    end

    self.accessLevel = accessLevel

    g_messageCenter:publish(EasyDevUtils.MESSAGE_TYPE_ACCESS_LEVEL_CHANGED, accessLevel)

    local easyDevControls = self.easyDevControls

    if easyDevControls.isEnabled and easyDevControls.defaultUserSettings ~= nil then
        for key, func in pairs (easyDevControls.defaultUserSettings) do
            func(self:getHasPermission(key, EasyDevControlsUI.ACCESS_NONE))
        end
    end

    return string.format("Access level set to %s (%s).", levelName, accessLevel)
end
