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

DynamicListDialog = {}

DynamicListDialog.CONTROLS = {
    "dialogElement",
    "dialogHeaderElement",
    "noInfoElement",
    "noInfoTextElement",
    "contentBoxElement",
    "scrollingLayoutElement",
    "scrollingLayoutItem",
    "backButton",
    "clearButton"
}

local DynamicListDialog_mt = Class(DynamicListDialog, ScreenElement)
local EMPTY_TABLE = {}

function DynamicListDialog.new(ui, easyDevControls, accessLevel)
    local self = ScreenElement.new(nil, DynamicListDialog_mt)

    self:registerControls(DynamicListDialog.CONTROLS)

    self.isCloseAllowed = true
    self.isBackAllowed = false
    self.showNoInfoMessage = true

    self.updateOnOpen = false
    self.inputDelay = 250

    self.ui = ui

    return self
end

function DynamicListDialog:onCreate(onCreateArgs)
    self.scrollingLayoutItem:unlinkElement()

    self.defaultHeaderText = self.dialogHeaderElement.text
    self.defaultNoInformationText = self.noInfoTextElement.text

    self.defaultDialogWidth = self.dialogElement.size[1]
    self.defaultDialogHeight = self.dialogElement.size[2]

    self.defaultBoxWidth = self.contentBoxElement.size[1]
    self.defaultBoxHeight = self.contentBoxElement.size[2]

    self.defaultItemWidth = self.scrollingLayoutItem.size[1]
    self.widthOffset = self.defaultBoxWidth - self.defaultItemWidth

    self.textOffset = 20 / g_referenceScreenWidth
end

function DynamicListDialog:delete()
    self.scrollingLayoutItem:delete()
    DynamicListDialog:superClass().delete(self)
end

function DynamicListDialog:onOpen()
    DynamicListDialog:superClass().onOpen(self)

    self.inputDelay = self.time + 250
    self.scrollingLayoutElement:registerActionEvents()

    if self.updateOnOpen then
        self:updateListContents()
    end
end

function DynamicListDialog:onClose()
    self.scrollingLayoutElement:removeActionEvents()

    self.list = nil
    self.updateOnOpen = false

    self.showNoInfoMessage = true
    self.noInfoTextElement:setText(self.defaultNoInformationText)

    self:setHeader(self.defaultHeaderText)
    -- self:updateListContents()

    self.clearButton:setDisabled(true)
    self.clearButton:setVisible(false)

    DynamicListDialog:superClass().onClose(self)
end

function DynamicListDialog:close()
    g_gui:closeDialogByName(self.name)
end

function DynamicListDialog:updateListContents()
    local width = self.defaultItemWidth * 0.7
    local numElements = 0

    for i = #self.scrollingLayoutElement.elements, 1, -1 do
        self.scrollingLayoutElement.elements[i]:delete()
    end

    if self.list ~= nil and #self.list > 0 then
        for _, listItem in ipairs(self.list) do
            local layoutItem = self.scrollingLayoutItem:clone(self.scrollingLayoutElement)

            local height = 0
            local textElement = layoutItem:getDescendantByName("text")

            if listItem.text ~= nil and listItem.text ~= "" then
                if listItem.textColour ~= nil then
                    local r, g, b, a = unpack(listItem.textColour)

                    textElement:setTextColor(r or 1, g or 1, b or 1, a or 0.5)
                end

                local text = EasyDevUtils.convertText(listItem.text)
                local textWidth = self:getWidthFromText(textElement, text)

                if textWidth > width then
                    width = textWidth
                end

                textElement.textMaxWidth = width
                textElement:setSize(width, nil)

                textElement:setText(text)

                height = height + textElement:getTextHeight() + self.textOffset
            else
                textElement:setVisible(false)
            end

            if listItem.title ~= nil and listItem.title ~= "" then
                local titleElement = layoutItem:getDescendantByName("title")

                if listItem.titleColour ~= nil then
                    local r, g, b, a = unpack(listItem.titleColour)

                    titleElement:setTextColor(r or 1, g or 1, b or 1, a or 1)
                end

                titleElement.textMaxWidth = width
                titleElement:setSize(width, nil)

                titleElement:setVisible(true)
                titleElement:setText(EasyDevUtils.convertText(listItem.title))

                height = height + titleElement.size[2] + self.textOffset
            end

            if listItem.overlayColour ~= nil then
                local r, g, b, a = unpack(listItem.overlayColour)

                if r ~= nil and g ~= nil and b ~= nil then
                    layoutItem:setImageColor(GuiOverlay.STATE_NORMAL, r, g, b, a or 0)
                end
            end

            layoutItem:setSize(width, height)
            layoutItem:invalidateLayout()

            numElements = numElements + 1
        end
    end

    if self.showNoInfoMessage then
        self.noInfoElement:setVisible(numElements == 0)
    end

    self:setDialogSize(width, true)
end

function DynamicListDialog:onClickBack(forceBack, usedMenuButton)
    if (self.isCloseAllowed or forceBack) and not usedMenuButton then
        if self.inputDelay < self.time then
            self:close()

            if self.callbackFunc ~= nil then
                if self.target ~= nil then
                    self.callbackFunc(self.target, self.args)
                else
                    self.callbackFunc(self.args)
                end
            end

            return false
        end
    else
        return true
    end
end

function DynamicListDialog:onClickClear()
    if self.clearCallbackFunc ~= nil then
        local headerText = self.dialogHeaderElement:getText()

        self:close()

        if self.target ~= nil then
            self.clearCallbackFunc(self.target)
        else
            self.clearCallbackFunc()
        end

        self.ui:showDynamicListDialog({
            headerText = headerText
        })
    end
end

function DynamicListDialog:setList(list, updateOnOpen, showNoInfoMessage, noInfoText)
    self.list = list

    self.updateOnOpen = Utils.getNoNil(updateOnOpen, false)
    self.showNoInfoMessage = Utils.getNoNil(showNoInfoMessage, true)

    if self.showNoInfoMessage and noInfoText ~= nil then
        self.noInfoTextElement:setText(noInfoText)
    end

    if not self.updateOnOpen then
        self:updateListContents()
    end
end

function DynamicListDialog:setCallback(callbackFunc, target, clearCallbackFunc)
    self.callbackFunc = callbackFunc
    self.target = target
    self.clearCallbackFunc = clearCallbackFunc

    self.clearButton:setDisabled(clearCallbackFunc == nil)
    self.clearButton:setVisible(clearCallbackFunc ~= nil)
end

function DynamicListDialog:setHeader(text)
    self.dialogHeaderElement:setText(Utils.getNoNil(text, self.defaultHeaderText))
end

function DynamicListDialog:getWidthFromText(textElement, text)
    setTextBold(textElement.textBold) -- Largest size it could get

    local width = getTextWidth(textElement.textSize, text)

    setTextBold(false)

    if textElement.textLayoutMode ~= TextElement.LAYOUT_MODE.OVERFLOW then
        width = math.min(width, textElement.absSize[1])
    end

    return math.min(width + self.textOffset, self.defaultItemWidth) -- textOffset??
end

function DynamicListDialog:setDialogSize(width, invalidateLayout)
    if width == nil then
        width = self.defaultItemWidth
    end

    width = math.max(math.min(width, self.defaultItemWidth) + self.widthOffset, self.defaultBoxWidth * 0.7)

    self.dialogElement:setSize(width + self.widthOffset)
    self.contentBoxElement:setSize(width)
    self.scrollingLayoutElement:setSize(width)

    if invalidateLayout then
        self.scrollingLayoutElement:invalidateLayout(true)
    end
end

function DynamicListDialog:getBlurArea()
    if self.dialogElement ~= nil then
        return self.dialogElement.absPosition[1], self.dialogElement.absPosition[2], self.dialogElement.absSize[1], self.dialogElement.absSize[2]
    end
end
