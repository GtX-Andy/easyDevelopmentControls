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

EasyDevControlsBaseFrame = {}

local EasyDevControlsBaseFrame_mt = Class(EasyDevControlsBaseFrame, TabbedMenuFrameElement)

local EMPTY_TABLE = {}

local function NO_CALLBACK()
end

EasyDevControlsBaseFrame.L10N_SYMBOL = {}

EasyDevControlsBaseFrame.CONTROLS = {
    "frameHeaderText",
    "buttonShowInfo",
    "container",
    "boxLayout",
    "infoBox",
    "infoBoxIcon",
    "infoBoxText"
}

function EasyDevControlsBaseFrame.new(customMt, ui, easyDevControls, accessLevel)
    local self = TabbedMenuFrameElement.new(nil, customMt or EasyDevControlsBaseFrame_mt)

    self.isOpen = false

    self.ui = ui
    self.easyDevControls = easyDevControls

    self.accessLevel = accessLevel
    self.hasMasterRights = false

    self.hasInfoText = false
    self:registerControls(EasyDevControlsBaseFrame.CONTROLS)

    return self
end

function EasyDevControlsBaseFrame:copyAttributes(src)
    EasyDevControlsBaseFrame:superClass().copyAttributes(self, src)

    self.ui = src.ui
    self.easyDevControls = src.easyDevControls

    self.accessLevel = src.accessLevel
    self.hasMasterRights = src.hasMasterRights
end

function EasyDevControlsBaseFrame:initialize()
end

function EasyDevControlsBaseFrame:initializeCustomButtons(iconsUIFilename)
    if self.buttonShowInfo ~= nil then
        self.buttonShowInfo:setImageFilename(nil, iconsUIFilename)
    end
end

function EasyDevControlsBaseFrame:onFrameOpen()
    self:setContainerVisibility(true)

    EasyDevControlsBaseFrame:superClass().onFrameOpen(self)

    if self.stateTexts == nil then
        self.stateTexts = {
            g_i18n:getText("ui_off"):lower(),
            g_i18n:getText("ui_on"):lower()
        }
    end

    if self.toggleTexts == nil then
        self.toggleTexts = {
            EasyDevUtils.getText("easyDevControls_disabled"):lower(),
            EasyDevUtils.getText("easyDevControls_enabled"):lower()
        }
    end

    if self.onOpenInfoText == nil then
        self.hasInfoText = false
        self.infoBoxText:setText("")
    else
        self.infoBoxText:setText(self.onOpenInfoText)
        self.onOpenInfoText = nil
    end

    self:updateAvailableProperties()
    self:subscribeToMessages(g_messageCenter)

    self.isOpen = true

    if FocusManager:getFocusedElement() == nil then
        self:setSoundSuppressed(true)
        FocusManager:setFocus(self.boxLayout)
        self:setSoundSuppressed(false)
    end
end

function EasyDevControlsBaseFrame:onFrameClose()
    self:setContainerVisibility(true)

    EasyDevControlsBaseFrame:superClass().onFrameClose(self)

    g_messageCenter:unsubscribeAll(self)

    self.isOpen = false

    self.hasInfoText = false
    self.infoBoxText:setText("")
end

function EasyDevControlsBaseFrame:updateAvailableProperties()
    self.boxLayout:invalidateLayout()
end

function EasyDevControlsBaseFrame:subscribeToMessages(messageCenter)
end

function EasyDevControlsBaseFrame:update(dt)
    EasyDevControlsBaseFrame:superClass().update(self, dt)

    if self.hasInfoText and g_currentMission ~= nil then
        if g_currentMission.time > self.updateTimeInfoText then
            self.infoBoxText:setText("")
            self.hasInfoText = false
        end
    end
end

function EasyDevControlsBaseFrame:onTextInputTextChanged(element) -- ??
    local text = element.text

    if text ~= "" then
        if tonumber(text) ~= nil then
            element.lastValidText = text
        else
            element:setText(element.lastValidText)
        end
    else
        element.lastValidText = ""
    end
end

function EasyDevControlsBaseFrame:onTextInputEscPressed(element)
    element:setText("")
    element.lastValidText = ""
end

function EasyDevControlsBaseFrame:setInfoText(text)
    if text ~= nil then
        if self.infoBoxText.text ~= text then
            self.infoBoxText:setText(text)
        end

        if text ~= "" then
            self.updateTimeInfoText = g_currentMission.time + 10000
            self.hasInfoText = true
        end
    else
        self.hasInfoText = false
        self.infoBoxText:setText("")
    end
end

function EasyDevControlsBaseFrame:onClickShowInfo(element)
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

function EasyDevControlsBaseFrame:onSettingChanged(id, value)
end

function EasyDevControlsBaseFrame:onAccessLevelChanged(accessLevel)
    self.accessLevel = accessLevel
    self.hasMasterRights = accessLevel == EasyDevControlsUI.ACCESS_ADMIN

    if self.isOpen then
        self:updateAvailableProperties()

        EasyDevUtils.devInfo("Access level changed, available properties for frame '%s' updated.", self.name)
    end
end

function EasyDevControlsBaseFrame:onPermissionsChanged()
    if self.isOpen then
        self:updateAvailableProperties()

        EasyDevUtils.devInfo("Page settings changed, available properties for frame '%s' updated.", self.name)
    end
end

function EasyDevControlsBaseFrame:setContainerVisibility(isVisible, hideInfoBox)
    if self.container ~= nil then
        self.container:setVisible(isVisible)
    end

    if self.frameHeaderText ~= nil then
        self.frameHeaderText:setVisible(isVisible)
    end

    if self.infoBox ~= nil then
        if hideInfoBox and not isVisible then
            self.infoBox:setVisible(false)
        else
            self.infoBox:setVisible(true)
        end
    end
end

function EasyDevControlsBaseFrame:getIsPropertyDisabled(key, defaultLevel)
    return not self.ui:getHasPermission(key, defaultLevel)
end

function EasyDevControlsBaseFrame:getStateText(state, toggleTexts)
    local index = state and 2 or 1

    if toggleTexts then
        return self.toggleTexts[index]
    end

    return self.stateTexts[index]
end

function EasyDevControlsBaseFrame:getIsCheckedIndex(index)
    return index == CheckedOptionElement.STATE_CHECKED
end

function EasyDevControlsBaseFrame:getResetValues()
    return EMPTY_TABLE
end

function EasyDevControlsBaseFrame:getMainElementSize()
    return self.container.size
end

function EasyDevControlsBaseFrame:getMainElementPosition()
    return self.container.absPosition
end
