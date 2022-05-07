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

EasyDevControlsTeleportScreen = {}

EasyDevControlsTeleportScreen.CONTROLS = {
    "ingameMap",
    "mapCursor",
    "actionMessage",
    "mapZoomGlyph",
    "mapMoveGlyph",
    "mapMoveGlyphText",
    "mapZoomGlyphText",
    "buttonBack",
    "buttonSelect"
}

EasyDevControlsTeleportScreen.L10N_SYMBOL = {
    BUTTON_BACK = "button_back",
    BUTTON_CANCEL = "button_cancel",
    TARGET_LOCATION = "ui_ai_pickTargetLocation",
    TARGET_ROTATION = "ui_ai_pickTargetRotation",
    INPUT_ZOOM_MAP = "ui_ingameMenuMapZoom",
    INPUT_MOVE_CURSOR = "ui_ingameMenuMapMoveCursor",
    INPUT_PAN_MAP = "ui_ingameMenuMapPan",
}

EasyDevControlsTeleportScreen.INPUT_CONTEXT_NAME = "EDC_TELEPORT_SCREEN"

local EasyDevControlsTeleportScreen_mt = Class(EasyDevControlsTeleportScreen, ScreenElement)

function EasyDevControlsTeleportScreen.new(ui, easyDevControls, accessLevel)
    local self = ScreenElement.new(nil, EasyDevControlsTeleportScreen_mt)

    self:registerControls(EasyDevControlsTeleportScreen.CONTROLS)

    self.isCloseAllowed = true
    self.isBackAllowed = true

    self.inputDelay = 250
    self.sendingCallback = false

    self.isPickingLocation = true
    self.isPickingRotation = false

    self.lastInputHelpMode = 0
    self.ingameMapBase = nil

    self.lastMousePosX = 0
    self.lastMousePosY = 0

    self.rotationOrigin = {0, 0}
    self.teleportHotspot = AITargetHotspot.new()

    return self
end

function EasyDevControlsTeleportScreen:onGuiSetupFinished()
    EasyDevControlsTeleportScreen:superClass().onGuiSetupFinished(self)

    self.zoomText = g_i18n:getText(EasyDevControlsTeleportScreen.L10N_SYMBOL.INPUT_ZOOM_MAP)
    self.moveCursorText = g_i18n:getText(EasyDevControlsTeleportScreen.L10N_SYMBOL.INPUT_MOVE_CURSOR)
    self.panMapText = g_i18n:getText(EasyDevControlsTeleportScreen.L10N_SYMBOL.INPUT_PAN_MAP)

    self.setLocationText = g_i18n:getText(EasyDevControlsTeleportScreen.L10N_SYMBOL.TARGET_LOCATION)
    self.setRotationText = g_i18n:getText(EasyDevControlsTeleportScreen.L10N_SYMBOL.TARGET_ROTATION)

    self.buttonBackText = g_i18n:getText(EasyDevControlsTeleportScreen.L10N_SYMBOL.BUTTON_BACK)
    self.buttonCancelText = g_i18n:getText(EasyDevControlsTeleportScreen.L10N_SYMBOL.BUTTON_CANCEL)
end

function EasyDevControlsTeleportScreen:delete()
    -- g_messageCenter:unsubscribeAll(self)

    if self.teleportHotspot ~= nil then
        self.teleportHotspot:delete()

        self.teleportHotspot = nil
    end

    EasyDevControlsTeleportScreen:superClass().delete(self)
end

function EasyDevControlsTeleportScreen:onOpen()
    EasyDevControlsTeleportScreen:superClass().onOpen(self)

    self.inputDelay = self.time + 250

    self.isPickingLocation = true
    self.isPickingRotation = false
    self.sendingCallback = false

	self:toggleMapInput(true)

	if self.ingameMap.ingameMap == nil or self.ingameMapBase == nil then
		if g_currentMission.hud ~= nil then
			self:setIngameMap(g_currentMission.hud:getIngameMap())
		end
	end

    self.ingameMap:onOpen()
    self.ingameMap:registerActionEvents()
    self.ingameMap:setIsCursorAvailable(false) -- Not required

    -- Copy current Filter States
    if self.ingameMapBase ~= nil then
        self.hotspotFilterStates = {}

        for k, v in pairs(self.ingameMapBase.filter) do
            self.hotspotFilterStates[k] = v

            self.ingameMapBase:setHotspotFilter(k, false)
        end

        self.ingameMapBase:setHotspotFilter(MapHotspot.CATEGORY_FIELD, true)
        self.ingameMapBase:setHotspotFilter(MapHotspot.CATEGORY_AI, true)
        self.ingameMapBase:setHotspotFilter(MapHotspot.CATEGORY_COMBINE, true)
        self.ingameMapBase:setHotspotFilter(MapHotspot.CATEGORY_STEERABLE, true)
        self.ingameMapBase:setHotspotFilter(MapHotspot.CATEGORY_PLAYER, true)
        self.ingameMapBase:setHotspotFilter(MapHotspot.CATEGORY_OTHER, true)
    end

    self:updateInputGlyphs()

    self.actionMessage:setText(self.setLocationText)
    self.buttonBack:setText(self.buttonBackText)

    if self.teleportHotspot == nil then
        self.teleportHotspot = AITargetHotspot.new()
    end

    g_currentMission:addMapHotspot(self.teleportHotspot)
    self:updateMapHotspotPosition()
end

function EasyDevControlsTeleportScreen:onClose()
    self.ingameMap:onClose()
	self:toggleMapInput(false)
    self:resetAllValues(true)

    EasyDevControlsTeleportScreen:superClass().onClose(self)
end

function EasyDevControlsTeleportScreen:toggleMapInput(isActive)
	if self.isInputContextActive ~= isActive then
		self.isInputContextActive = isActive

		self:toggleCustomInputContext(isActive, EasyDevControlsTeleportScreen.INPUT_CONTEXT_NAME)

		if isActive then
			g_currentMission.inputManager:removeActionEventsByActionName(InputAction.MENU_EXTRA_2)
		end
	end
end

function EasyDevControlsTeleportScreen:mouseEvent(posX, posY, isDown, isUp, button, eventUsed)
    self.lastMousePoxY = posY
    self.lastMousePosX = posX

    if self.isPickingLocation then
        local localX, localY = self.ingameMap:getLocalPosition(self.lastMousePosX, self.lastMousePoxY)

        self:setTeleportHotspotPosition(localX, localY)
    elseif self.isPickingRotation then
        local localX, localY = self.ingameMap:getLocalPosition(posX, posY)
        local worldX, worldZ = self.ingameMap:localToWorldPos(localX, localY)
        local angle = EasyDevUtils.getValidAngle(math.atan2(worldX - self.rotationOrigin[1], worldZ - self.rotationOrigin[2]) + math.pi)

        self.teleportHotspot:setWorldRotation(angle)
    end

    return EasyDevControlsTeleportScreen:superClass().mouseEvent(self, posX, posY, isDown, isUp, button, eventUsed)
end

function EasyDevControlsTeleportScreen:update(dt)
    EasyDevControlsTeleportScreen:superClass().update(self, dt)

    local currentInputHelpMode = g_currentMission.inputManager:getInputHelpMode()

    if currentInputHelpMode ~= self.lastInputHelpMode then
        self.lastInputHelpMode = currentInputHelpMode

		local showCursor = currentInputHelpMode ~= GS_INPUT_HELP_MODE_GAMEPAD

        g_inputBinding:setShowMouseCursor(showCursor)
		self.buttonSelect:setVisible(not showCursor)

		self:updateInputGlyphs()
    end

    if currentInputHelpMode == GS_INPUT_HELP_MODE_GAMEPAD then
        local localX, localY = self.ingameMap:getLocalPointerTarget()

        if self.isPickingLocation then
            self:setTeleportHotspotPosition(localX, localY)
        elseif self.isPickingRotation then
            local worldX, worldZ = self.ingameMap:localToWorldPos(localX, localY)
            local angle = EasyDevUtils.getValidAngle(math.atan2(worldX - self.rotationOrigin[1], worldZ - self.rotationOrigin[2]) + math.pi)

            self.teleportHotspot:setWorldRotation(angle)
        end
    end
end

function EasyDevControlsTeleportScreen:onClickMap(element, worldX, worldZ)
    if self.inputDelay < self.time then
        if self.isPickingLocation then
            self.rotationOrigin = {
                worldX,
                worldZ
            }

            self.teleportHotspot:setWorldPosition(worldX, worldZ)

            self.buttonBack:setText(self.buttonCancelText)
            self.actionMessage:setText(self.setRotationText)

            self.isPickingLocation = false
            self.isPickingRotation = true
        elseif self.isPickingRotation then
            if self.ingameMapBase ~= nil then
                local x, z = self.teleportHotspot:getWorldPosition()
                local normalizedPosX = EasyDevUtils.getNoNilClamp((x + self.ingameMapBase.worldCenterOffsetX) / self.ingameMapBase.worldSizeX, 0, 1, x)
                local normalizedPosZ = EasyDevUtils.getNoNilClamp((z + self.ingameMapBase.worldCenterOffsetZ) / self.ingameMapBase.worldSizeZ, 0, 1, z)

                local posX, posZ = normalizedPosX * self.ingameMapBase.worldSizeX, normalizedPosZ * self.ingameMapBase.worldSizeZ
                local angle = EasyDevUtils.getValidAngle(math.atan2(worldX - self.rotationOrigin[1], worldZ - self.rotationOrigin[2]))

                self:sendCallback(posX, posZ, angle)
            else
                self:sendCallback(nil, nil, nil)
            end
        end
    end
end

function EasyDevControlsTeleportScreen:onClickBack(forceBack, usedMenuButton)
    local eventUnused = true

    if self.sendingCallback or self.isPickingLocation then
        eventUnused = EasyDevControlsTeleportScreen:superClass().onClickBack(self, forceBack, usedMenuButton)
    end

    self:resetAllValues()

    return eventUnused
end

function EasyDevControlsTeleportScreen:onDrawPostIngameMapHotspots()
    if self.teleportHotspot ~= nil then
        local icon = self.teleportHotspot.icon

        self.actionMessage:setAbsolutePosition(icon.x + icon.width * 0.5, icon.y + icon.height * 0.5)
    end
end

function EasyDevControlsTeleportScreen:sendCallback(posX, posZ, angle)
    if self.callbackFunction ~= nil then
        if self.callbackTarget ~= nil then
            self.callbackFunction(self.callbackTarget, self.teleportObject, posX, posZ, angle)
        else
            self.callbackFunction(self.teleportObject, posX, posZ, angle)
        end
    end

    self.sendingCallback = true
    self:onClickBack(true, false)
end

function EasyDevControlsTeleportScreen:updateInputGlyphs()
    local moveActions, moveText = nil

    if self.lastInputHelpMode == GS_INPUT_HELP_MODE_GAMEPAD then
        moveText = self.moveCursorText
        moveActions = {
            InputAction.AXIS_MAP_SCROLL_LEFT_RIGHT,
            InputAction.AXIS_MAP_SCROLL_UP_DOWN
        }
    else
        moveText = self.panMapText
        moveActions = {
            InputAction.AXIS_LOOK_LEFTRIGHT_DRAG,
            InputAction.AXIS_LOOK_UPDOWN_DRAG
        }
    end

    self.mapMoveGlyph:setActions(moveActions, nil, nil, true, true)
    self.mapMoveGlyphText:setText(moveText)

    self.mapZoomGlyph:setActions({InputAction.AXIS_MAP_ZOOM_IN, InputAction.AXIS_MAP_ZOOM_OUT}, nil, nil, false, true)
    self.mapZoomGlyphText:setText(self.zoomText)
end

function EasyDevControlsTeleportScreen:updateMapHotspotPosition()
    local localX, localY = 0.5, 0.5

    if g_currentMission.inputManager:getLastInputMode() ~= GS_INPUT_HELP_MODE_GAMEPAD then
        local lastMousePosX, lastMousePoxY = g_inputBinding:getMousePosition()

        localX, localY = self.ingameMap:getLocalPosition(lastMousePosX, lastMousePoxY)
    else
        localX, localY = self.ingameMap:getLocalPointerTarget()
    end

    self:setTeleportHotspotPosition(localX, localY)
end

function EasyDevControlsTeleportScreen:resetAllValues(forceReset)
    if self.sendingCallback or forceReset then
        g_currentMission:removeMapHotspot(self.teleportHotspot)

        -- Restore the Filter States
        if self.ingameMapBase ~= nil and self.hotspotFilterStates ~= nil then
            for k, v in pairs(self.ingameMapBase.filter) do
                self.ingameMapBase:setHotspotFilter(k, self.hotspotFilterStates[k])
            end

            self.hotspotFilterStates = nil
        end
    else
        self:updateMapHotspotPosition()
    end

    self.buttonBack:setText(self.buttonBackText)
    self.actionMessage:setText(self.setLocationText)

    self.isPickingLocation = true
    self.isPickingRotation = false
    self.sendingCallback = false
end

function EasyDevControlsTeleportScreen:setTeleportHotspotPosition(localX, localY)
    if self.teleportHotspot ~= nil then
        local worldX, worldZ = self.ingameMap:localToWorldPos(localX, localY)

        self.teleportHotspot:setWorldPosition(worldX, worldZ)
    end
end

function EasyDevControlsTeleportScreen:setCallback(callbackFunction, callbackTarget, teleportObject)
    self.callbackFunction = callbackFunction
    self.callbackTarget = callbackTarget
    self.teleportObject = teleportObject
end

function EasyDevControlsTeleportScreen:setIngameMap(ingameMap)
    self.ingameMapBase = ingameMap
    self.ingameMap:setIngameMap(ingameMap)
end

function EasyDevControlsTeleportScreen:setTerrainSize(terrainSize)
    self.ingameMap:setTerrainSize(terrainSize)
end
