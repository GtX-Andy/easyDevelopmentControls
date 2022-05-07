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

DynamicSelectionDialog = {}

DynamicSelectionDialog.CONTROLS = {
    DIALOG_BG = "dialogBgElement",
    DIALOG = "dialogElement",
    DIALOG_HEADER = "dialogHeaderElement",
    PROPERTIES_LAYOUT = "propertiesLayoutElement",
    MULTI_TEXT_OPTION_TEMPLATE = "multiTextOptionTemplate",
    TEXT_INPUT_TEMPLATE = "textInputTemplate",
    BUTTON_TEMPLATE = "buttonTemplate",
    SPACER_TEMPLATE = "spacerTemplate",
    CONFIRM_BUTTON = "confirmButton",
    BACK_BUTTON = "backButton"
}

DynamicSelectionDialog.TYPE_MULTI_TEXT_OPTION = 0
DynamicSelectionDialog.TYPE_CHECKED_OPTION = 1
DynamicSelectionDialog.TYPE_TEXT_INPUT = 2
DynamicSelectionDialog.TYPE_BUTTON = 3
DynamicSelectionDialog.TYPE_SPACER = 4

local DynamicSelectionDialog_mt = Class(DynamicSelectionDialog, ScreenElement)
local EMPTY_TABLE = {}

function DynamicSelectionDialog.new(ui, easyDevControls, accessLevel)
    local self = ScreenElement.new(nil, DynamicSelectionDialog_mt)

    self.isCloseAllowed = true
    self.isBackAllowed = false

    self.inputDelay = 250
	self.confirmAction = InputAction.MENU_ACCEPT

	self.properties = nil
	self.numProperties = 0
	self.numHorizontal = 0
	self.numVertical = 0
	self.numVerticalClosePerRow = 0
	self.flowDirection = BoxLayoutElement.FLOW_HORIZONTAL
	self.hasValidProperties = false

    self.callbackValues = {}
    self.dynamicControlIDs = {}

    self.elementsByName = {}
    self.propertiesByName = {}

    self:registerControls(DynamicSelectionDialog.CONTROLS)

    return self
end

function DynamicSelectionDialog:onCreate(onCreateArgs)
    local size = self.multiTextOptionTemplate.size
    local margin = self.multiTextOptionTemplate.margin

    self.templateWidth = size[1] + margin[1] + margin[3]
    self.templateHeight = size[2] + margin[2] + margin[4]

    self.multiTextOptionTemplate:unlinkElement()
	FocusManager:removeElement(self.multiTextOptionTemplate)
    self.textInputTemplate:unlinkElement()
	FocusManager:removeElement(self.textInputTemplate)
    self.buttonTemplate:unlinkElement()
	FocusManager:removeElement(self.buttonTemplate)
    self.spacerTemplate:unlinkElement()
	FocusManager:removeElement(self.spacerTemplate)

    self.defaultDialogWidth = self.dialogElement.size[1]
    self.defaultDialogHeight = self.dialogElement.size[2]

    self.defaultHeader = self.dialogHeaderElement.text

    self.defaultConfirmText = self.confirmButton.text
    self.defaultBackText = self.backButton.text

    self.checkedOptionTexts = {
        g_i18n:getText("ui_off"),
        g_i18n:getText("ui_on")
    }

    self.yesNoTexts = {
        g_i18n:getText("ui_no"),
        g_i18n:getText("ui_yes")
    }
end

function DynamicSelectionDialog:onOpen()
    DynamicSelectionDialog:superClass().onOpen(self)

    self.inputDelay = self.time + 250
	self:updateProperties()
end

function DynamicSelectionDialog:onClose()
    self:setHeader(nil, true)
    self:setButtonTexts(self.defaultConfirmText, self.defaultBackText)

	self.confirmAction = InputAction.MENU_ACCEPT
	self:setConfirmButtonAction(self.confirmAction)

    DynamicSelectionDialog:superClass().onClose(self)
end

function DynamicSelectionDialog:close()
    g_gui:closeDialogByName(self.name)

    if self.notifyOnCloseTarget ~= nil then
        self.notifyOnCloseTarget:onDynamicSelectionDialogClosed(self.onCloseArguments)

        self.notifyOnCloseTarget = nil
        self.onCloseArguments = nil
    end
end

function DynamicSelectionDialog:delete()
    self.multiTextOptionTemplate:delete()
    self.textInputTemplate:delete()
    self.buttonTemplate:delete()
    self.spacerTemplate:delete()

    DynamicSelectionDialog:superClass().delete(self)
end

function DynamicSelectionDialog:onClickBack(forceBack, usedMenuButton)
    if (self.isCloseAllowed or forceBack) and not usedMenuButton then
        self:close()

        return false
    else
        return true
    end
end

function DynamicSelectionDialog:sendCallback(confirm, callbackValues, elementsByName, propertiesByName)
    if self.inputDelay < self.time then
        self:close()

        if self.callbackFunc ~= nil then
            if self.target ~= nil then
                self.callbackFunc(self.target, confirm, callbackValues, elementsByName, propertiesByName)
            else
                self.callbackFunc(confirm, callbackValues, elementsByName, propertiesByName)
            end
        end
    end
end

function DynamicSelectionDialog:onConfirm(element)
    self:sendCallback(
        element == self.confirmButton,
        self.callbackValues,
        self.elementsByName,
        self.propertiesByName
    )
end

function DynamicSelectionDialog:setCallback(callbackFunc, target)
    self.callbackFunc = callbackFunc
    self.target = target
end

function DynamicSelectionDialog:setHeader(text, hideBackground)
    self.dialogHeaderElement:setText(Utils.getNoNil(text, self.defaultHeader))
    self.dialogBgElement:setVisible(not Utils.getNoNil(hideBackground, false))
end

function DynamicSelectionDialog:setButtonTexts(confirmText, backText)
    self.confirmButton:setText(Utils.getNoNil(confirmText, self.defaultConfirmText))
    self.backButton:setText(Utils.getNoNil(backText, self.defaultBackText))
end

function DynamicSelectionDialog:setConfirmButtonDisabled(disabled, confirmAction)
    disabled = Utils.getNoNil(disabled, false)

    self.confirmButton:setDisabled(disabled)
    self.confirmButton:setVisible(not disabled)

	if not disabled then
		self:setConfirmButtonAction(confirmAction)
	end
end

function DynamicSelectionDialog:setConfirmButtonAction(confirmAction)
	if confirmAction ~= nil then
		self.confirmAction = confirmAction
		self.confirmButton:setInputAction(confirmAction)
	end
end

function DynamicSelectionDialog:setNotifyOnClose(target, onCloseArguments)
    if target ~= nil and target.onDynamicSelectionDialogClosed ~= nil then
        self.notifyOnCloseTarget = target
        self.onCloseArguments = onCloseArguments
    end
end

function DynamicSelectionDialog:setAvailableProperties(properties, numHorizontal, numVertical, numVerticalClosePerRow, flowDirection)
	self.properties = properties
	self.numProperties = 0
	self.numHorizontal = 0
	self.numVertical = 0
	self.numVerticalClosePerRow = 0
	self.flowDirection = BoxLayoutElement.FLOW_HORIZONTAL
	self.hasValidProperties = false

	if self.properties ~= nil then
		self:setDialogElementSize(#self.properties, numHorizontal, numVertical, numVerticalClosePerRow, flowDirection)
	end
end

function DynamicSelectionDialog:updateProperties()
    for i = #self.propertiesLayoutElement.elements, 1, -1 do
        self.propertiesLayoutElement.elements[i]:delete()
    end

    for varName, _ in pairs (self.dynamicControlIDs) do
        self[varName] = nil
    end

    self.callbackValues = {}
    self.dynamicControlIDs = {}

    self.elementsByName = {}
    self.propertiesByName = {}

    if self.hasValidProperties then
        for i = 1, self.numProperties do
            local property = self.properties[i]
            local typeId = property.typeId

            local itemElement = nil
            local validElement = false

            if (typeId == DynamicSelectionDialog.TYPE_MULTI_TEXT_OPTION) or (typeId == DynamicSelectionDialog.TYPE_CHECKED_OPTION) then
                local lastIndex = property.lastIndex or 1

                itemElement, validElement = self:cloneTemplate("multiTextOptionTemplate", false, property.name, i)

                itemElement.onClickCallback = function(_, index, element, isLeft)
                    element.lastIndex = index
                    property.lastIndex = index

                    if property.onClickCallback ~= nil then
                        property.onClickCallback(self, index, element, isLeft, property)
                    else
                        self.callbackValues[element.name] = index
                    end
                end

                if property.texts ~= nil then
                    itemElement:setTexts(property.texts)
                elseif property.useCheckedTexts or typeId == DynamicSelectionDialog.TYPE_CHECKED_OPTION then
                    -- No 'getIsChecked' or 'setIsChecked' but not needed
                    itemElement:setTexts(property.useYesNoTexts and self.yesNoTexts or self.checkedOptionTexts)
                end

                itemElement.lastIndex = lastIndex

                self.callbackValues[itemElement.name] = lastIndex
            elseif typeId == DynamicSelectionDialog.TYPE_TEXT_INPUT then
                itemElement, validElement = self:cloneTemplate("textInputTemplate", false, property.name, i)

                itemElement.enterWhenClickOutside = Utils.getNoNil(property.enterWhenClickOutside, true)
                itemElement.maxCharacters = property.maxCharacters

                itemElement.lastValidText = tostring(property.defaultValue or "")

                itemElement.onEnterPressedCallback = function(_, element, clickedOutside)
                    if property.onEnterPressedCallback ~= nil then
                        property.onEnterPressedCallback(self, element, clickedOutside, element.lastValidText, property)
                    else
                        if element.text ~= "" then
                            local value = tonumber(element.text)

                            if value ~= nil then
                                self.callbackValues[element.name] = value
                            else
                                element:setText("")
                                element.lastValidText = ""
                            end
                        end
                    end

                    element.lastValidText = ""
                end

                itemElement.onEscPressedCallback = function(_, element)
                    if property.onEscPressedCallback ~= nil then
                        local lastValidText = element.lastValidText
                        property.onEscPressedCallback(self, element, property, lastValidText)
                    end

                    if not property.ignoreEsc then
                        element:setText("")
                        element.lastValidText = ""
                    end
                end

                itemElement.onTextChangedCallback = function(_, element, text)
                    if property.onTextChangedCallback ~= nil then
                        property.onTextChangedCallback(self, element, text, property)
                    else
                        if text ~= nil and text ~= "" then
                            local value = tonumber(text)

                            if value ~= nil then
                                element.lastValidText = text

                                self.callbackValues[element.name] = value
                            else
                                element:setText(element.lastValidText)
                            end
                        else
                            element.lastValidText = ""
                        end
                    end
                end

                itemElement:setText(itemElement.lastValidText)

                self.callbackValues[itemElement.name] = property.defaultValue or 0
            elseif typeId == DynamicSelectionDialog.TYPE_BUTTON then
                itemElement, validElement = self:cloneTemplate("buttonTemplate", false, property.name, i)

                itemElement.onClickCallback = function(d, element)
                    if property.onClickCallback ~= nil then
                        property.onClickCallback(self, element, property)
                    else
                        self.callbackValues[element.name] = true
                        self:onConfirm(self.confirmButton)
                    end
                end

                self.callbackValues[itemElement.name] = Utils.getNoNil(property.defaultValue, false)
            elseif typeId == DynamicSelectionDialog.TYPE_SPACER then
                itemElement, validElement = self:cloneTemplate("spacerTemplate", false, property.name, i)
            end

            if itemElement ~= nil and validElement then
                local titleElement = itemElement:getDescendantByName("title")

                if property.profile ~= nil then
                    itemElement:applyProfile(property.profile)
                end

                itemElement:setDisabled(Utils.getNoNil(property.disabled, false))
                itemElement:setVisible(true)

                if titleElement ~= nil then
                    if property.title ~= nil then
                        titleElement:setText(property.title)
                    else
                        titleElement:setVisible(false)
                        titleElement:setDisabled(true)
                    end
                end

                itemElement.propertyId = i
                itemElement.dynamicId = property.dynamicId

                self:exposeDynamicIdAsField(itemElement)

                self.elementsByName[itemElement.name] = itemElement
                self.propertiesByName[itemElement.name] = property
            end
        end
	end

	local elements = self.propertiesLayoutElement.elements
	local firstElement = elements[1]
	local lastElement = elements[#elements]

	if firstElement ~= nil then
		for i, element in ipairs (elements) do
			if element.setState ~= nil and (element.name ~= nil and self.propertiesByName[element.name] ~= nil) then
				element:setState(element.lastIndex, self.propertiesByName[element.name].forceState)
			end
	
			if element == firstElement then
				FocusManager:linkElements(element, FocusManager.TOP, lastElement)
				FocusManager:linkElements(element, FocusManager.BOTTOM, elements[i + 1])
			elseif element == lastElement then
				FocusManager:linkElements(element, FocusManager.TOP, elements[i - 1])
				FocusManager:linkElements(element, FocusManager.BOTTOM, firstElement)
			else
				FocusManager:linkElements(element, FocusManager.TOP, elements[i - 1])
				FocusManager:linkElements(element, FocusManager.BOTTOM, elements[i + 1])
			end
		end
	end

    self.propertiesLayoutElement:invalidateLayout()
	FocusManager:setFocus(firstElement)
end

function DynamicSelectionDialog:setDialogElementSize(numProperties, numHorizontal, numVertical, numVerticalClosePerRow, flowDirection)
    local maxProperties = 32
    local maxHorizontal = 4
    local maxVertical = 8

    numProperties = math.min(numProperties or 0, maxProperties)

    numHorizontal = math.max(math.min(numHorizontal or 0, maxHorizontal), 0)
    numVertical = math.max(math.min(numVertical or 0, maxVertical), 0)
    numVerticalClosePerRow = numVerticalClosePerRow or 0

    if numProperties > 1 then
        if numHorizontal == 0 then
            if numProperties <= 12 then
                numHorizontal = 2
            elseif numProperties <= 24 then
                numHorizontal = 3
            else
                numHorizontal = maxHorizontal
            end
        end

        if numVertical == 0 then
            numVertical = math.ceil(numProperties / numHorizontal)
        end
    end

    local widthOffset = self.templateWidth * (numHorizontal - 1)
    local heightOffset = self.templateHeight * ((numVertical - numVerticalClosePerRow) - 1)

    if numVertical > 1 and numVerticalClosePerRow > 0 then
        heightOffset = heightOffset + ((self.templateHeight - (42 / g_referenceScreenHeight)) * numVerticalClosePerRow)
    end

    if flowDirection == nil or (flowDirection ~= "vertical" or flowDirection ~= "horizontal") then
        flowDirection = BoxLayoutElement.FLOW_HORIZONTAL
    end

    if self.flowDirection ~= flowDirection then
        self.flowDirection = flowDirection

        if flowDirection == "vertical" then
            self.propertiesLayoutElement:applyProfile("dynamicSelectionDialogLayoutVertical", true)
        else
            self.propertiesLayoutElement:applyProfile("dynamicSelectionDialogLayout", true)
        end
    end

	self.numProperties = numProperties
	self.numHorizontal = numHorizontal
	self.numVertical = numVertical
	self.numVerticalClosePerRow = numVerticalClosePerRow
	self.hasValidProperties = numProperties > 0

    self.dialogElement:setSize(self.defaultDialogWidth + widthOffset, self.defaultDialogHeight + heightOffset)
    self.propertiesLayoutElement:setSize(self.defaultDialogWidth + widthOffset, self.defaultDialogHeight + heightOffset)

    return numProperties
end

function DynamicSelectionDialog:exposeDynamicIdAsField(element)
    if element.dynamicId ~= nil and element.dynamicId ~= "" then
        local index, varName = GuiElement.extractIndexAndNameFromID(element.dynamicId)

        if varName:find("[^%w_]") ~= nil then
            EasyDevUtils.devInfo("Invalid dynamic id '%s' for GUI property '%s', alphanumeric only with no white spaces or punctuation!", element.dynamicId, element.propertyId)

            return
        end

        if self.dynamicControlIDs[varName] ~= nil then
            EasyDevUtils.devInfo("Duplicate dynamic id '%s' for GUI property '%s'!", varName, element.propertyId)

            return
        end

        if index then
            if self[varName] == nil then
                self[varName] = {}
            end

            self[varName][index] = element
        else
            self[varName] = element
        end

        self.dynamicControlIDs[varName] = true
    end
end

function DynamicSelectionDialog:cloneTemplate(templateControlName, includeId, propertyName, index)
    local control = self[templateControlName]

    if control ~= nil then
        local element = control:clone(self.propertiesLayoutElement, includeId)

        if (propertyName == nil or propertyName == "") or propertyName:find("[^%w_]") ~= nil then
            element.name = string.format("property%d", index)
        else
            element.name = propertyName
        end

		element:reloadFocusHandling(true)

        return element, true
    end

    return {}, false
end

function DynamicSelectionDialog:getBlurArea()
    if self.dialogElement ~= nil then
        return self.dialogElement.absPosition[1], self.dialogElement.absPosition[2], self.dialogElement.absSize[1], self.dialogElement.absSize[2]
    end
end