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

EasyDevControlsTabbedMenu = {}
local EasyDevControlsTabbedMenu_mt = Class(EasyDevControlsTabbedMenu, TabbedMenu)

EasyDevControlsTabbedMenu.CONTROLS = {
    BACKGROUND = "backgroundElement",
    PAGE_GENERAL = "pageGeneral",
    PAGE_PLAYER = "pagePlayer",
    PAGE_OBJECTS = "pageObjects",
    PAGE_VEHICLES = "pageVehicles",
    PAGE_PLACEABLES = "pagePlaceables",
    PAGE_FIELDS = "pageFields",
    PAGE_ENVIRONMENT = "pageEnvironment",
    PAGE_PERMISSIONS = "pagePermissions",
    PAGE_HELP = "pageHelp"
}

EasyDevControlsTabbedMenu.L10N_SYMBOL = {
    ON_PAGE_RESET = "easyDevControls_resetPageWarning",
    BUTTON_ADD_BLUR = "easyDevControls_addBlurButton",
    BUTTON_REMOVE_BLUR = "easyDevControls_removeBlurButton",
    BUTTON_DEFAULTS = "button_defaults",
    BUTTON_SAVE = "button_save",
    BUTTON_BACK = "button_back",
    BUTTON_RESET = "button_reset",
    BUTTON_ADMIN = "button_adminLogin"
}

EasyDevControlsTabbedMenu.TAB_UV = {
    GENERAL = {0, 0, 64, 64},
    PLAYER = {64, 0, 64, 64},
    OBJECTS = {128, 0, 64, 64},
    VEHICLES = {192, 0, 64, 64},
    PLACEABLES = {256, 0, 64, 64},
    FIELDS = {320, 0, 64, 64},
    ENVIRONMENT = {384, 0, 64, 64},
    PERMISSIONS = {448, 0, 64, 64},
    HELP = {512, 0, 64, 64},
    ABOUT = {576, 0, 64, 64}
}

function EasyDevControlsTabbedMenu.new(messageCenter, l10n, inputManager, ui, accessLevel)
    local self = TabbedMenu.new(nil, EasyDevControlsTabbedMenu_mt, messageCenter, l10n, inputManager)

    self:registerControls(EasyDevControlsTabbedMenu.CONTROLS)

    self.ui = ui
    self.accessLevel = accessLevel

    self.performBackgroundBlur = true
    self.defaultMenuButtonInfo = {}

    self.connectedToDedicatedServer = false

    return self
end

function EasyDevControlsTabbedMenu:onGuiSetupFinished()
    EasyDevControlsTabbedMenu:superClass().onGuiSetupFinished(self)

    if self.connectedToDedicatedServer then
        self.messageCenter:subscribe(MessageType.MASTERUSER_ADDED, self.onMasterUserAdded, self)
    end

    self.messageCenter:subscribe(EasyDevUtils.MESSAGE_TYPE_ACCESS_LEVEL_CHANGED, self.onAccessLevelChanged, self)
    self.messageCenter:subscribe(EasyDevUtils.MESSAGE_TYPE_PERMISSIONS_CHANGED, self.onPermissionsChanged, self)

    self:setupPages()
end

function EasyDevControlsTabbedMenu:setupPages()
    local orderedPages = {
        {
            self.pageGeneral,
            self:makeIsVisiblePredicate(),
            self.ui.iconsUIFilename,
            EasyDevControlsTabbedMenu.TAB_UV.GENERAL
        },
        {
            self.pagePlayer,
            self:makeIsVisiblePredicate(),
            self.ui.iconsUIFilename,
            EasyDevControlsTabbedMenu.TAB_UV.PLAYER
        },
        {
            self.pageObjects,
            self:makeIsVisiblePredicate(),
            self.ui.iconsUIFilename,
            EasyDevControlsTabbedMenu.TAB_UV.OBJECTS
        },
        {
            self.pageVehicles,
            self:makeIsVisiblePredicate(),
            self.ui.iconsUIFilename,
            EasyDevControlsTabbedMenu.TAB_UV.VEHICLES
        },
        {
            self.pagePlaceables,
            self:makeIsVisiblePredicate(),
            self.ui.iconsUIFilename,
            EasyDevControlsTabbedMenu.TAB_UV.PLACEABLES
        },
        {
            self.pageFields,
            self:makeIsVisiblePredicate(),
            self.ui.iconsUIFilename,
            EasyDevControlsTabbedMenu.TAB_UV.FIELDS
        },
        {
            self.pageEnvironment,
            self:makeIsVisiblePredicate(),
            self.ui.iconsUIFilename,
            EasyDevControlsTabbedMenu.TAB_UV.ENVIRONMENT
        },
        {
            self.pagePermissions,
            self:makeIsPermissionsVisiblePredicate(),
            self.ui.iconsUIFilename,
            EasyDevControlsTabbedMenu.TAB_UV.PERMISSIONS
        },
        {
            self.pageHelp,
            self:makeIsVisiblePredicate(),
            self.ui.iconsUIFilename,
            EasyDevControlsTabbedMenu.TAB_UV.HELP
        }
    }

    for i, pageDef in ipairs(orderedPages) do
        local page, predicate, iconsUIFilename, iconUVs = unpack(pageDef)

        if page.initializeCustomButtons ~= nil then
            page:initializeCustomButtons(iconsUIFilename)
        end

        page:initialize()

        self:registerPage(page, i, predicate)
        self:addPageTab(page, iconsUIFilename, GuiUtils.getUVs(iconUVs))
    end
end

function EasyDevControlsTabbedMenu:setupMenuButtonInfo()
    self.clickBackCallback = self:makeSelfCallback(self.onButtonBack)
    self.clickResetCallback = self:makeSelfCallback(self.onButtonReset)
    self.clickBackgroundCallback = self:makeSelfCallback(self.onButtonBackground)

    self.backButtonInfo = {
        inputAction = InputAction.MENU_BACK,
        text = self.l10n:getText(EasyDevControlsTabbedMenu.L10N_SYMBOL.BUTTON_BACK),
        callback = self.clickBackCallback
    }

    self.resetButtonInfo = {
        showWhenPaused = true,
        inputAction = InputAction.MENU_EXTRA_1,
        text = self.l10n:getText(EasyDevControlsTabbedMenu.L10N_SYMBOL.BUTTON_DEFAULTS),
        callback = self.clickResetCallback
    }

    self.blurButtonInfo = {
        showWhenPaused = true,
        inputAction = InputAction.MENU_EXTRA_2,
        text = EasyDevUtils.getText(EasyDevControlsTabbedMenu.L10N_SYMBOL.BUTTON_REMOVE_BLUR),
        callback = self.clickBackgroundCallback
    }

    self.defaultMenuButtonInfo = {
        self.backButtonInfo,
        self.resetButtonInfo,
        self.blurButtonInfo
    }

    self.defaultMenuButtonInfoByActions = {
        [InputAction.MENU_BACK] = self.defaultMenuButtonInfo[1],
        [InputAction.MENU_EXTRA_1] = self.defaultMenuButtonInfo[2],
        [InputAction.MENU_EXTRA_2] = self.defaultMenuButtonInfo[3]
    }

    self.defaultButtonActionCallbacks = {
        [InputAction.MENU_BACK] = self.clickBackCallback,
        [InputAction.MENU_EXTRA_1] = self.clickResetCallback,
        [InputAction.MENU_EXTRA_2] = self.clickBackgroundCallback
    }

    if g_currentMission ~= nil and g_currentMission.connectedToDedicatedServer then
        self.clickAdminLoginCallback = self:makeSelfCallback(self.onButtonAdminLogin)

        self.adminButtonInfo = {
            inputAction = InputAction.MENU_ACTIVATE,
            text = self.l10n:getText(EasyDevControlsTabbedMenu.L10N_SYMBOL.BUTTON_ADMIN),
            callback = self.clickAdminLoginCallback
        }

        self.dedicatedMenuButtonInfo = {
            self.backButtonInfo,
            self.adminButtonInfo,
            self.resetButtonInfo,
            self.blurButtonInfo
        }

        self:setDedicatedMenuButtonInfo(self.dedicatedMenuButtonInfo)
        self.connectedToDedicatedServer = true
    end

    self.pageHelpButtonInfo = {
        self.backButtonInfo
    }

    self.pageHelp:setMenuButtonInfo(self.pageHelpButtonInfo)
end

function EasyDevControlsTabbedMenu:setDedicatedMenuButtonInfo(info)
    self.pageGeneral:setMenuButtonInfo(info)
    self.pagePlayer:setMenuButtonInfo(info)
    self.pageObjects:setMenuButtonInfo(info)
    self.pageVehicles:setMenuButtonInfo(info)
    self.pagePlaceables:setMenuButtonInfo(info)
    self.pageFields:setMenuButtonInfo(info)
    self.pageEnvironment:setMenuButtonInfo(info)

    if self.currentPage ~= nil then
        self:updateButtonsPanel(self.currentPage)
    end
end

function EasyDevControlsTabbedMenu:onMasterUserAdded(user)
    if user:getId() == g_currentMission.playerUserId then
        self:setDedicatedMenuButtonInfo(nil)
    end
end

function EasyDevControlsTabbedMenu:onAccessLevelChanged(accessLevel)
    self.accessLevel = accessLevel

    for i, pageFrameElement in ipairs (self.pageFrames) do
        if pageFrameElement ~= nil and pageFrameElement.onAccessLevelChanged ~= nil then
            pageFrameElement:onAccessLevelChanged(accessLevel)
        end
    end

    if self.currentPage ~= nil then
        self:updatePages()
    end
end

function EasyDevControlsTabbedMenu:onPermissionsChanged()
    for i, pageFrameElement in ipairs (self.pageFrames) do
        if pageFrameElement ~= nil and pageFrameElement.onPermissionsChanged ~= nil then
            pageFrameElement:onPermissionsChanged()
        end
    end
end

function EasyDevControlsTabbedMenu:onOpen()
    EasyDevControlsTabbedMenu:superClass().onOpen(self)

    self:disableInputForDuration(150)
    self.muteSound = false -- Reset debugging had muted
end

function EasyDevControlsTabbedMenu:onClose()
    EasyDevControlsTabbedMenu:superClass().onClose(self)

    self:setBackgroundVisable(true, true)
end

function EasyDevControlsTabbedMenu:exitMenu()
    -- Confirm changes are saved if on permissions page
    if self.currentPage == self.pagePermissions and not self.currentPage:requestClose(self.clickBackCallback) then
        return
    end

    EasyDevControlsTabbedMenu:superClass().exitMenu(self)
end

function EasyDevControlsTabbedMenu:onClickPageSelection(state)
    -- Confirm changes are saved if on permissions page
    if self.currentPage == self.pagePermissions then
        local function setPage()
            if self.pagingElement:setPage(state or 1) and not self.muteSound then
                self:playSample(GuiSoundPlayer.SOUND_SAMPLES.PAGING)
            end
        end

        if not self.currentPage:requestClose(setPage) then
            return
        end
    end

    EasyDevControlsTabbedMenu:superClass().onClickPageSelection(self, state)
end

function EasyDevControlsTabbedMenu:onPageChange(pageIndex, pageMappingIndex, element, skipTabVisualUpdate)
    local page = self.pagingElement:getPageElementByIndex(pageIndex)

    if page == self.pagePermissions or page == self.pageHelp then
        self:setBackgroundVisable(true, false)
    end

    EasyDevControlsTabbedMenu:superClass().onPageChange(self, pageIndex, pageMappingIndex, element, skipTabVisualUpdate)
end

function EasyDevControlsTabbedMenu:update(dt)
    if self.serverRequestSent and self.serverRequestEndTime <= getTimeSec() then
        self.serverRequestEndTime = 0

        g_gui:showMessageDialog({
            visible = false
        })

        -- Temporary until the server possibly returns information to the requesting user in V2.0.0.0
        if self.currentPage ~= nil and self.currentPage.setInfoText ~= nil then
            self.currentPage:setInfoText(self.serverRequestSuccessText or EasyDevUtils.getText("easyDevControls_success"))
        end

        self.serverRequestSuccessText = nil
        self.serverRequestSent = false
    end

    if self.serverRequestSent then
        return
    end

    EasyDevControlsTabbedMenu:superClass().update(self, dt)
end

function EasyDevControlsTabbedMenu:onButtonAdminLogin()
    if not self.connectedToDedicatedServer then
        return
    end

    g_gui:showPasswordDialog({
        defaultPassword = "",
        text = self.l10n:getText("ui_enterAdminPassword"),
        callback = function(password, yes)
            if yes then
                g_client:getServerConnection():sendEvent(GetAdminEvent.new(password))
            end
        end
    })
end

function EasyDevControlsTabbedMenu:onButtonReset()
    local currentPage = self.currentPage

    if currentPage ~= nil then
        if currentPage.getResetValues == nil then
            EasyDevUtils.devInfo("Missing function 'getResetValues' in '%s' frame!", currentPage.name)

            return
        end

        local function resetPage(yes)
            if yes then
                local resetValues = currentPage:getResetValues()

                if resetValues ~= nil then
                    for controlName, data in pairs (resetValues) do
                        local control = currentPage[controlName]

                        if control ~= nil then
                            if data.permissionKey == nil or self.ui:getHasPermission(data.permissionKey) then
                                data.force = Utils.getNoNil(data.force, true)

                                if data.setFunction == nil then
                                    if control:getState() ~= data.value then
                                        control:setState(data.value, data.force)
                                    end
                                else
                                    data.setFunction(control, data)
                                end
                            end
                        end
                    end
                end
            end
        end

        g_gui:showYesNoDialog({
            text = EasyDevUtils.getText(EasyDevControlsTabbedMenu.L10N_SYMBOL.ON_PAGE_RESET),
            callback = resetPage
        })
    end
end

function EasyDevControlsTabbedMenu:onButtonBackground()
    self:setBackgroundVisable()
end

function EasyDevControlsTabbedMenu:setBackgroundVisable(isVisible, isClosing)
    isVisible = Utils.getNoNil(isVisible, not self.performBackgroundBlur)

    if isClosing == nil or isClosing == false then
        if not isVisible and self.performBackgroundBlur then
            g_depthOfFieldManager:popArea()
            self.performBackgroundBlur = false
        elseif isVisible and not self.performBackgroundBlur then
            g_depthOfFieldManager:pushArea(0, 0, 1, 1)
            self.performBackgroundBlur = true
        end
    else
        self.performBackgroundBlur = true
    end

    isVisible = self.performBackgroundBlur
    self.backgroundElement:setVisible(isVisible)

    if isVisible then
        self.blurButtonInfo.text = EasyDevUtils.getText(EasyDevControlsTabbedMenu.L10N_SYMBOL.BUTTON_REMOVE_BLUR)
    else
        self.blurButtonInfo.text = EasyDevUtils.getText(EasyDevControlsTabbedMenu.L10N_SYMBOL.BUTTON_ADD_BLUR)
    end

    if self.currentPage ~= nil then
        self:updateButtonsPanel(self.currentPage)

        if self.currentPage.onBackgroundVisibilityChanged ~= nil then
            self.currentPage:onBackgroundVisibilityChanged(isVisible)
        end
    end
end

function EasyDevControlsTabbedMenu:onSendServerRequest(currentLatency, text, successText) -- currentLatency ??
    if g_client ~= nil and self.isOpen then
        currentLatency = currentLatency or 80

        if currentLatency > 50 then
            g_gui:showMessageDialog({
                isCloseAllowed = false,
                visible = true,
                text = text or EasyDevUtils.getText("easyDevControls_serverRequestMessage")
            })

            self.serverRequestEndTime = getTimeSec() + ((currentLatency * 6) / 1000)
            self.serverRequestSuccessText = successText
            self.serverRequestSent = true
        end
    end
end

function EasyDevControlsTabbedMenu:makeIsVisiblePredicate()
    return function()
        return true
    end
end

function EasyDevControlsTabbedMenu:makeIsPermissionsVisiblePredicate()
    return function()
        if g_currentMission.missionDynamicInfo.isMultiplayer or EasyDevControlsUI.FORCE_MULTIPLAYER_MODE then
            return self.accessLevel == EasyDevControlsUI.ACCESS_ADMIN
        end

        return false
    end
end
