-- chunkname: @/modules/client_topmenu/topmenu.lua

local topMenu, topMenuHide, fpsUpdateEvent

local TOP_BUTTON_SIZE = 40
local TOP_BUTTON_SPACING = 5
local TOP_MENU_PADDING = 8
local TOP_MENU_MIN_WIDTH = 120

local TopMenuIcons = {
	logoutButton = "/images/TOPBUTTONS_REWORK/ICON_LOGOUT",
	optionsButton = "/images/TOPBUTTONS_REWORK/ICON_CONFIG",
	terminalButton = "/images/TOPBUTTONS_REWORK/ICON_TERMINAL",
	skillsButton = "/images/TOPBUTTONS_REWORK/ICON_SKILL",
	battleButton = "/images/TOPBUTTONS_REWORK/ICON_BATTLE",
	vipListButton = "/images/TOPBUTTONS_REWORK/ICON_FRIENDLIST",
	hotkeysButton = "/images/TOPBUTTONS_REWORK/ICON_HOTKEY",
	questLogButton = "/images/TOPBUTTONS_REWORK/ICON_QUEST",
	inventoryButton = "/images/TOPBUTTONS_REWORK/ICON_INVENTARIO",
	minimapButton = "/images/TOPBUTTONS_REWORK/ICON_MINIMAP",
	autoloot = "/images/TOPBUTTONS_REWORK/ICON_AUTOLOOT",
	task_kill = "/images/TOPBUTTONS_REWORK/ICON_TASK",
	MainButton = "/images/TOPBUTTONS_REWORK/ICON_PASS",
	buttonShop = "/images/TOPBUTTONS_REWORK/ICON_SHOP",
	guildManagement = "/images/TOPBUTTONS_REWORK/ICON_GUILD",
	lootButton = "/images/TOPBUTTONS_REWORK/ICON_LOOT",
	dailyRewards = "/images/TOPBUTTONS_REWORK/ICON_REWARD",
	starterguideTopButton = "/images/TOPBUTTONS_REWORK/ICON_QUEST"
}

local function getVisibleButtonCount(panel)
	if not panel or not panel:isVisible() then
		return 0
	end

	local count = 0
	for _, child in ipairs(panel:getChildren()) do
		if child:isVisible() then
			count = count + 1
		end
	end
	return count
end

local function getButtonsWidth(panel)
	local count = getVisibleButtonCount(panel)
	if count == 0 then
		return 0
	end
	return count * TOP_BUTTON_SIZE + math.max(count - 1, 0) * TOP_BUTTON_SPACING
end

local function updateTopMenuSize()
	if not topMenu then
		return
	end

	local leftWidth = getButtonsWidth(topMenu.leftButtonsPanel)
	local leftGameWidth = getButtonsWidth(topMenu.leftGameButtonsPanel)
	local rightWidth = getButtonsWidth(topMenu.rightButtonsPanel)
	local rightGameWidth = getButtonsWidth(topMenu.rightGameButtonsPanel)

	local leftSeparator = topMenu:recursiveGetChildById("leftGameSeparator")
	local rightSeparator = topMenu:recursiveGetChildById("rightGameSeparator")
	local showLeftSeparator = leftGameWidth > 0 and rightWidth > 0
	local showRightSeparator = rightGameWidth > 0 and (leftWidth + leftGameWidth + rightWidth) > 0

	if leftSeparator then
		leftSeparator:setVisible(showLeftSeparator)
	end
	if rightSeparator then
		rightSeparator:setVisible(showRightSeparator)
	end

	local width = TOP_MENU_PADDING * 2 + leftWidth + leftGameWidth + rightWidth + rightGameWidth

	if rightWidth > 0 and (leftWidth + leftGameWidth) > 0 then
		width = width + 5
	end
	if showLeftSeparator then
		width = width + 12
	end
	if showRightSeparator then
		width = width + 7
	end
	if rightGameWidth > 0 then
		width = width + 5
	end

	topMenu:setWidth(math.max(TOP_MENU_MIN_WIDTH, width))
end

local function scheduleTopMenuSizeUpdate()
	scheduleEvent(updateTopMenuSize, 1)
end

local function addButton(id, description, icon, callback, panel, front, index)
	if topMenu.reverseButtons then
		front = not front
	end

	local button = panel:getChildById(id)

	if not button then
		button = g_ui.createWidget("TopButton")

		if front then
			panel:insertChild(1, button)
		else
			panel:addChild(button)
		end
	end

	button:setId(id)
	button:setTooltip(description)
	button:setIcon(resolvepath(TopMenuIcons[id] or icon, 3))

	function button.onMouseRelease(widget, mousePos, mouseButton)
		if widget:containsPoint(mousePos) and mouseButton ~= MouseMidButton and mouseButton ~= MouseTouch then
			callback()

			return true
		end
	end

	button.onTouchRelease = button.onMouseRelease

	if not button.index and type(index) == "number" then
		button.index = index
	end

	scheduleTopMenuSizeUpdate()

	return button
end

local function updateOrder(panel)
	local children = panel:getChildren()

	table.sort(children, function(a, b)
		return (a.index or 1000) < (b.index or 1000)
	end)
	panel:reorderChildren(children)
	scheduleTopMenuSizeUpdate()
end

function init()
	connect(g_game, {
		onGameStart = online,
		onGameEnd = offline,
		onPingBack = updatePing
	})

	local rootWidget = g_ui.getRootWidget()

	topMenuHide = g_ui.createWidget("TopMenuHide", rootWidget)
	topMenu = g_ui.createWidget("TopMenu", rootWidget)
	topMenu.hideMenu = topMenuHide
	topMenu.fpsLabel = g_ui.createWidget("TopMenuFrameCounterLabel", rootWidget)

	hide()

	if g_game.isOnline() then
		scheduleEvent(online, 10)
	end

	updateFps()
end

function terminate()
	disconnect(g_game, {
		onGameStart = online,
		onGameEnd = offline,
		onPingBack = updatePing
	})
	removeEvent(fpsUpdateEvent)

	if topMenu.fpsLabel then
		topMenu.fpsLabel:destroy()
	end

	topMenu:destroy()
	topMenuHide:destroy()
end

function online()
	show()
	showGameButtons()

	if topMenu.pingLabel then
		addEvent(function()
			if modules.client_options.getOption("showPing") and (g_game.getFeature(GameClientPing) or g_game.getFeature(GameExtendedClientPing)) then
				topMenu.pingLabel:show()
			else
				topMenu.pingLabel:hide()
			end
		end)
	end
end

function offline()
	if topMenu.hideIngame then
		show()
	end

	hide()
	hideGameButtons()

	if topMenu.pingLabel then
		topMenu.pingLabel:hide()
	end
end

function updateFps()
	if not topMenu.fpsLabel then
		return
	end

	fpsUpdateEvent = scheduleEvent(updateFps, 500)
	text = "FPS: " .. g_app.getFps()

	topMenu.fpsLabel:setText(text)
end

function updatePing(ping)
	if not topMenu.pingLabel then
		return
	end

	if g_proxy and g_proxy.getPing() > 0 then
		ping = g_proxy.getPing()
	end

	local text = "Ping: "
	local color

	if ping < 0 then
		text = text .. "??"
		color = "yellow"
	else
		text = text .. ping .. " ms"
		color = ping >= 500 and "red" or ping >= 250 and "yellow" or "green"
	end

	topMenu.pingLabel:setColor(color)
	topMenu.pingLabel:setText(text)
end

function setPingVisible(enable)
	if not topMenu.pingLabel then
		return
	end

	topMenu.pingLabel:setVisible(enable)
end

function setFpsVisible(enable)
	if not topMenu.fpsLabel then
		return
	end

	topMenu.fpsLabel:setVisible(enable)
end

function addLeftButton(id, description, icon, callback, front, index)
	local button = addButton(id, description, icon, callback, topMenu.leftButtonsPanel, front, index)

	updateOrder(topMenu.leftButtonsPanel)

	return button
end

function addLeftGameButton(id, description, icon, callback, front, index)
	local button = addButton(id, description, icon, callback, topMenu.leftGameButtonsPanel, front, index)

	updateOrder(topMenu.leftGameButtonsPanel)

	return button
end

function addRightButton(id, description, icon, callback, front, index)
	local button = addButton(id, description, icon, callback, topMenu.rightButtonsPanel, front, index)

	updateOrder(topMenu.rightButtonsPanel)

	return button
end

function addRightGameButton(id, description, icon, callback, front, index)
	local button = addButton(id, description, icon, callback, topMenu.rightGameButtonsPanel, front, index)

	updateOrder(topMenu.rightGameButtonsPanel)

	return button
end

function addLeftToggleButton(id, description, icon, callback, front, index)
	local button = addButton(id, description, icon, callback, topMenu.leftButtonsPanel, front, index)

	updateOrder(topMenu.leftButtonsPanel)

	return button
end

function addLeftGameToggleButton(id, description, icon, callback, front, index)
	local button = addButton(id, description, icon, callback, topMenu.leftGameButtonsPanel, front, index)

	updateOrder(topMenu.leftGameButtonsPanel)

	return button
end

function addRightToggleButton(id, description, icon, callback, front, index)
	local button = addButton(id, description, icon, callback, topMenu.rightButtonsPanel, front, index)

	updateOrder(topMenu.rightButtonsPanel)

	return button
end

function addRightGameToggleButton(id, description, icon, callback, front, index)
	local button = addButton(id, description, icon, callback, topMenu.rightGameButtonsPanel, front, index)

	updateOrder(topMenu.rightGameButtonsPanel)

	return button
end

function showGameButtons()
	topMenu.leftGameButtonsPanel:show()
	topMenu.rightGameButtonsPanel:show()
	scheduleTopMenuSizeUpdate()
end

function hideGameButtons()
	topMenu.leftGameButtonsPanel:hide()
	topMenu.rightGameButtonsPanel:hide()
	scheduleTopMenuSizeUpdate()
end

function getButton(id)
	return topMenu:recursiveGetChildById(id)
end

function getTopMenu()
	return topMenu
end

function toggle()
	if not topMenu then
		return
	end

	if topMenu:isVisible() then
		hide()
	else
		show()
	end
end

function hide()
	topMenu:hide()
	topMenuHide:hide()
	scheduleTopMenuSizeUpdate()

	if topMenu.fpsLabel then
		topMenu.fpsLabel:setOn(false)
	end

	if modules.game_stats then
		modules.game_stats.show()
	end
end

function show()
	topMenu:show()
	topMenuHide:show()
	scheduleTopMenuSizeUpdate()

	if topMenu.fpsLabel then
		topMenu.fpsLabel:setOn(true)
	end

	if modules.game_stats then
		modules.game_stats.hide()
	end
end

function showAndHide()
	local isOn = not topMenuHide:isOn()

	topMenu:setOn(isOn)
	topMenuHide:setOn(isOn)
end
