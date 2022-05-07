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

EasyDevControlsPermissionsFrame = {}

local EasyDevControlsPermissionsFrame_mt = Class(EasyDevControlsPermissionsFrame, TabbedMenuFrameElement)

local EMPTY_TABLE = {}

local function NO_CALLBACK()
end

EasyDevControlsPermissionsFrame.L10N_SYMBOL = {
    ON_PAGE_RESET = "easyDevControls_resetPermissionsWarning",
    BUTTON_RESET_ALL = "button_defaults",
    BUTTON_SAVE = "button_save",
    BUTTON_BACK = "button_back",
    SAVED_CHANGES_INFO = "ui_savingFinished",
    SAVE_FAILED_INFO = "easyDevControls_savingFailed",
    SAVE_CHANGES_PROMPT = "ui_saveChanges"
}

EasyDevControlsPermissionsFrame.CONTROLS = {
    "container",
    "buttonShowInfo",
    "scrollingLayoutElement",
    "buttonReset",
    "headerTextTemplate",
    "multiTextOptionTemplate",
}


function EasyDevControlsPermissionsFrame.new(ui, easyDevControls)
    local self = TabbedMenuFrameElement.new(nil, EasyDevControlsPermissionsFrame_mt)

    self.isOpen = false

    self.ui = ui
    self.easyDevControls = easyDevControls

    self.hasUserChanges = false
    self.hasCustomMenuButtons = true

    self.backButtonInfo = {}
    self.saveButtonInfo = {}
    self.resetButtonInfo = {}

    self:registerControls(EasyDevControlsPermissionsFrame.CONTROLS)

    return self
end

function EasyDevControlsPermissionsFrame:copyAttributes(src)
    EasyDevControlsPermissionsFrame:superClass().copyAttributes(self, src)

    self.ui = src.ui
    self.easyDevControls = src.easyDevControls
end

function EasyDevControlsPermissionsFrame:initializeCustomButtons(iconsUIFilename)
    if self.buttonShowInfo ~= nil then
        self.buttonShowInfo:setImageFilename(nil, iconsUIFilename)
    end
end

function EasyDevControlsPermissionsFrame:initialize()
    self.keyToElement = {}

    self.headerTextTemplate:unlinkElement()
	FocusManager:removeElement(self.headerTextTemplate)
    self.multiTextOptionTemplate:unlinkElement()
	FocusManager:removeElement(self.multiTextOptionTemplate)

    self.backButtonInfo = {
        inputAction = InputAction.MENU_BACK
    }

    self.resetButtonInfo = {
        showWhenPaused = true,
        inputAction = InputAction.MENU_EXTRA_1,
        text = g_i18n:getText(EasyDevControlsPermissionsFrame.L10N_SYMBOL.BUTTON_RESET_ALL),
        callback = function ()
            self:resetToDefaults()
        end
    }

    self.saveButtonInfo = {
        showWhenPaused = true,
        inputAction = InputAction.MENU_ACTIVATE,
        text = g_i18n:getText(EasyDevControlsPermissionsFrame.L10N_SYMBOL.BUTTON_SAVE),
        callback = function()
            self:saveChanges()
        end
    }

    self:initializeScrollingLayout(false)

    if self.scrollingLayoutElement.sliderElement ~= nil then
        self.scrollingLayoutElement.sliderElement:setValue(1, true)
    end
end

function EasyDevControlsPermissionsFrame:initializeScrollingLayout(isReset)
    for i = #self.scrollingLayoutElement.elements, 1, -1 do
        self.scrollingLayoutElement.elements[i]:delete()
    end

    local permissionTexts = {
        g_i18n:getText("ui_admin"),
        g_i18n:getText("ui_farmManager"),
        g_i18n:getText("configuration_valueDefault"),
        g_i18n:getText("ui_none")
    }

    local indexedPagePermissions = self.ui.indexedPagePermissions
    local toolTipText = EasyDevUtils.getText("easyDevControls_permissionsToolTip")

	local firstElement

	if indexedPagePermissions ~= nil then
		for _, page in ipairs (indexedPagePermissions) do
            local headerElement = self.headerTextTemplate:clone(self.scrollingLayoutElement)
            local headerText = "..."

            if page.title ~= nil then
                headerText = EasyDevUtils.getText(page.title)
            end

			headerElement:setText(headerText)
			headerElement:reloadFocusHandling(true)

            for _, permission in ipairs (page.permissions) do
                local element = self.multiTextOptionTemplate:clone(self.scrollingLayoutElement)
                local titleElement = element:getDescendantByName("title")
                local toolTipElement = element:getDescendantByName("toolTip")

                local elementTexts = {}
                local titleText = "Missing Title"

				element:reloadFocusHandling(true)

				if firstElement == nil then
					firstElement = element
				end

                if permission.title ~= nil then
                    titleText = EasyDevUtils.getText(permission.title)
                end
				
				if permission.getIsDisabled ~= nil then
					permission.disabled = permission.getIsDisabled()
				end

                if permission.disabled == nil or permission.disabled == false then
                    for i = 1, math.min((permission.minimumLevel or EasyDevControlsUI.ACCESS_FARM_MANAGER), EasyDevControlsUI.ACCESS_NONE) do
                        elementTexts[i] = permissionTexts[i]
                    end
                else
                    elementTexts[1] = EasyDevUtils.getText("easyDevControls_disabled")
                    element:setDisabled(true)
                end

                element.name = permission.key
                self.keyToElement[permission.key] = element

                element:setTexts(elementTexts)
                element:setState(permission.defualtValue or 1, isReset)

                if titleElement ~= nil then
                    titleElement:setText(titleText)
                end

                if toolTipElement ~= nil then
                    local toolTip = ""

                    if permission.toolTipParams == nil or permission.toolTipParams == "" then
                        toolTip = string.format("'%s'", titleText)
                    else
                        local texts = permission.toolTipParams:split("|")

                        for i, textPart in pairs(texts) do
                            texts[i] = string.format("'%s'", EasyDevUtils.getText(textPart))
                        end

                        toolTip = table.concat(texts, " | ")
                    end

                    toolTipElement:setText(toolTipText:format(toolTip))
                end
            end
        end
    end

	self.scrollingLayoutElement:scrollTo(0, true)
	self.scrollingLayoutElement:invalidateLayout()

	if firstElement ~= nil then
		self.scrollingLayoutElement:scrollToMakeElementVisible(firstElement)
		FocusManager:setFocus(firstElement)

		firstElement.forceFocusScrollToTop = true

		self.scrollingLayoutElement.wrapAround = true
		
		local lastElement = self.scrollingLayoutElement.elements[#self.scrollingLayoutElement.elements]
		
		FocusManager:linkElements(lastElement, FocusManager.BOTTOM, firstElement)
		FocusManager:linkElements(firstElement, FocusManager.TOP, lastElement)
	end
end

function EasyDevControlsPermissionsFrame:focusLinkElement()
	for i = 1, #self.scrollingLayoutElement.elements do
		local button = self.scrollingLayoutElement.elements[i]
		local topButton = self.scrollingLayoutElement.elements[i - 1]
		local bottomButton = self.scrollingLayoutElement.elements[i + 1]

		if topButton ~= nil then
			FocusManager:linkElements(button, FocusManager.TOP, topButton)
		else
			FocusManager:linkElements(button, FocusManager.TOP, button)
		end

		if bottomButton ~= nil then
			FocusManager:linkElements(button, FocusManager.BOTTOM, bottomButton)
		else
			FocusManager:linkElements(button, FocusManager.BOTTOM, button)
		end
	end
end

function EasyDevControlsPermissionsFrame:onFrameOpen()
    EasyDevControlsPermissionsFrame:superClass().onFrameOpen(self)

    self.isOpen = true
    self.scrollingLayoutElement:registerActionEvents()

    self:updateProperties()
    self:updateMenuButtons()
end

function EasyDevControlsPermissionsFrame:onFrameClose()
    self.scrollingLayoutElement:removeActionEvents()

    EasyDevControlsPermissionsFrame:superClass().onFrameClose(self)

    self.isOpen = false
end

function EasyDevControlsPermissionsFrame:delete()
    self.headerTextTemplate:delete()
    self.multiTextOptionTemplate:delete()

    EasyDevControlsPermissionsFrame:superClass().delete(self)
end

function EasyDevControlsPermissionsFrame:updateProperties()
    self:initializeScrollingLayout(false)

	self.currentPermissions = {}
    self.changedPermissions = {}

    for key, value in pairs (self.ui:getPermissions()) do
        local element = self.keyToElement[key]

        if element ~= nil then
            element:setState(value)

            self.currentPermissions[key] = value
        end
    end

	self.scrollingLayoutElement:invalidateLayout()
end

function EasyDevControlsPermissionsFrame:updateMenuButtons()
    if self.hasUserChanges then
        self.menuButtonInfo = {
            self.backButtonInfo,
            self.saveButtonInfo,
            self.resetButtonInfo
        }
    else
        self.menuButtonInfo = {
            self.backButtonInfo,
            self.resetButtonInfo
        }
    end

    self:setMenuButtonInfoDirty()
end

function EasyDevControlsPermissionsFrame:onClickChangePermission(index, element)
    local permissionKey = element.name

    if permissionKey ~= nil then
        if self.currentPermissions[permissionKey] ~= index then
            self.changedPermissions[permissionKey] = index
        else
            self.changedPermissions[permissionKey] = nil
        end

        self.hasUserChanges = next(self.changedPermissions) ~= nil
        self:updateMenuButtons()
    end
end

function EasyDevControlsPermissionsFrame:requestClose(callback)
    if self.hasUserChanges then
        EasyDevControlsPermissionsFrame:superClass().requestClose(self, callback)

        g_gui:showYesNoDialog({
            text = g_i18n:getText(EasyDevControlsPermissionsFrame.L10N_SYMBOL.SAVE_CHANGES_PROMPT),
            callback = self.onYesNoSavePermissions,
            target = self
        })

        return false
    end

    return true
end

function EasyDevControlsPermissionsFrame:onYesNoSavePermissions(yes)
    if yes then
        self:saveChanges()
    else
        self:resetChanges()

        self.requestCloseCallback() -- Complete then page close
        self.requestCloseCallback = NO_CALLBACK --  Clear callback
    end
end

function EasyDevControlsPermissionsFrame:onClickShowInfo(element)
    local tabbedMenu = self.parent.target

    if tabbedMenu ~= nil and tabbedMenu.pageHelp ~= nil and tabbedMenu.pagingElement ~= nil then
        local pageMappingIndex = tabbedMenu.pagingElement:getPageMappingIndexByElement(tabbedMenu.pageHelp)
        local currentPageIndex = tabbedMenu.pagingElement.currentPageIndex

        if pageMappingIndex ~= nil and tabbedMenu.pageSelector ~= nil then
            tabbedMenu.pageSelector:setState(pageMappingIndex, true)
            tabbedMenu.pageHelp:openPage(currentPageIndex or 1)
        end
    end
end

function EasyDevControlsPermissionsFrame:resetChanges()
    for key, value in pairs (self.currentPermissions) do
        local element = self.keyToElement[key]

        if element ~= nil then
            element:setState(value)
        end
    end

    self.hasUserChanges = false
    self.changedPermissions = {}

    self:updateMenuButtons()
end

function EasyDevControlsPermissionsFrame:saveChanges()
    local text = EasyDevControlsPermissionsFrame.L10N_SYMBOL.SAVE_FAILED_INFO
    local numUpdated = 0

    for key, accessLevel in pairs (self.changedPermissions) do
        if self.ui:setPermission(key, accessLevel) then
            self.currentPermissions[key] = accessLevel

            numUpdated = numUpdated + 1
        end
    end

    self.hasUserChanges = false
    self.changedPermissions = {}

    self:updateMenuButtons()

    if numUpdated > 0 then
        text = EasyDevControlsPermissionsFrame.L10N_SYMBOL.SAVED_CHANGES_INFO
        EasyDevControlsPermissionsEvent.sendEvent(false) -- Sync
    end

    g_gui:showInfoDialog({
        text = EasyDevUtils.getText(text),
        callback = self.requestCloseCallback
    })

    self.requestCloseCallback = NO_CALLBACK
end

function EasyDevControlsPermissionsFrame:resetToDefaults()
    g_gui:showYesNoDialog({
        text = EasyDevUtils.getText(EasyDevControlsPermissionsFrame.L10N_SYMBOL.ON_PAGE_RESET),
        callback = function (yes)
            if yes then
                self.hasUserChanges = false
                self.changedPermissions = {}

                self:initializeScrollingLayout(true)
                self:updateMenuButtons()
            end
        end
    })
end

function EasyDevControlsPermissionsFrame:getMainElementSize()
    return self.container.size
end

function EasyDevControlsPermissionsFrame:getMainElementPosition()
    return self.container.absPosition
end
