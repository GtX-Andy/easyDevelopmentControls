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

EasyDevControlsHelpFrame = {}
local EasyDevControlsHelpFrame_mt = Class(EasyDevControlsHelpFrame, TabbedMenuFrameElement)

EasyDevControlsHelpFrame.CONTROLS = {
    "listDataElement",
    "contentBoxElement",
    "contentItemTemplate"
}

function EasyDevControlsHelpFrame.new(ui, easyDevControls, helpData)
    local self = EasyDevControlsHelpFrame:superClass().new(nil, EasyDevControlsHelpFrame_mt)

    self:registerControls(EasyDevControlsHelpFrame.CONTROLS)

    self.ui = ui
    self.easyDevControls = easyDevControls
    self.helpData = helpData

    return self
end

function EasyDevControlsHelpFrame:copyAttributes(src)
    EasyDevControlsHelpFrame:superClass().copyAttributes(self, src)

    self.ui = src.ui
    self.easyDevControls = src.easyDevControls
    self.helpData = src.helpData
end

function EasyDevControlsHelpFrame:initialize()
    self.contentItemTemplate:unlinkElement()

    self:resetSlider(self.listDataElement)
    self:resetSlider(self.contentBoxElement)
end

function EasyDevControlsHelpFrame:delete()
    self.contentItemTemplate:delete()

    EasyDevControlsHelpFrame:superClass().delete(self)
end

function EasyDevControlsHelpFrame:onFrameOpen()
    EasyDevControlsHelpFrame:superClass().onFrameOpen(self)

    self.listDataElement:reloadData()

    self:setSoundSuppressed(true)
    FocusManager:setFocus(self.listDataElement)
    self:setSoundSuppressed(false)

    self.contentBoxElement:registerActionEvents()
end

function EasyDevControlsHelpFrame:onFrameClose()
    self.contentBoxElement:removeActionEvents()

    EasyDevControlsHelpFrame:superClass().onFrameClose(self)
end

function EasyDevControlsHelpFrame:resetSlider(element)
    if element.sliderElement ~= nil then
        element.sliderElement:setValue(0, true)
    end
end

function EasyDevControlsHelpFrame:updateContents(page)
    for i = #self.contentBoxElement.elements, 1, -1 do
        self.contentBoxElement.elements[i]:delete()
    end

    if page ~= nil then
        for _, command in ipairs(page.commands) do
            self:addContentRowItem(command.title, command.text)
        end

        if #self.contentBoxElement.elements > 0 then
            self:addContentRowItem("", "") -- Empty space to allow the scrolling to finishes higher
        end
    end

    self.contentBoxElement:invalidateLayout()
end

function EasyDevControlsHelpFrame:addContentRowItem(title, text)
    local row = self.contentItemTemplate:clone(self.contentBoxElement)

    local titleElement = row:getDescendantByName("title")
    titleElement:setText(title)

    local textElement = row:getDescendantByName("text")
    textElement:setText(text)

    local sizeY = titleElement.size[2] + textElement:getTextHeight()
    row:setSize(nil, sizeY)

    row:invalidateLayout()
end

function EasyDevControlsHelpFrame:onListSelectionChanged(list, section, index)
    self:updateContents(self.helpData[index])
end

function EasyDevControlsHelpFrame:getNumberOfSections()
    return 1
end

function EasyDevControlsHelpFrame:getNumberOfItemsInSection(list, section)
    return #self.helpData
end

function EasyDevControlsHelpFrame:populateCellForItemInSection(list, section, index, element)
    local pageHelpData = self.helpData[index]

    local titleElement = element:getAttribute("title")
    local iconElement = element:getAttribute("icon")

    if titleElement ~= nil then
        titleElement:setText(pageHelpData.title or "Missing Page Title")
    end

    if iconElement ~= nil then
        local isVisible = false

        if pageHelpData.name ~= nil then
            local iconUVs = EasyDevControlsTabbedMenu.TAB_UV[pageHelpData.name:upper()]

            if iconUVs ~= nil then
                iconElement:setImageFilename(self.ui.iconsUIFilename)
                iconElement:setImageUVs(nil, unpack(GuiUtils.getUVs(iconUVs)))

                isVisible = true
            end
        end

        iconElement:setVisible(isVisible)
    end
end

function EasyDevControlsHelpFrame:openPage(index)
    self:setSoundSuppressed(true)
    self.listDataElement:setSelectedItem(1, index, true, 1)
    self:setSoundSuppressed(false)
end
