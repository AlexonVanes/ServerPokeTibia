battleWindow = nil
battleButton = nil
battlePanel = nil
filterPanel = nil
toggleFilterButton = nil

mouseWidget = nil
updateEvent = nil

hoveredCreature = nil
newHoveredCreature = nil
prevCreature = nil

battleButtons = {}
local ageNumber = 1
local ages = {}

function init()
  g_ui.importStyle('battlebutton')

  battleButton = modules.client_topmenu.addLeftGameButton(
    'battleButton',
    tr('Battle') .. ' (Ctrl+B)',
    '/images/TOPBUTTONS_REWORK/ICON_BATTLE',
    toggle,
    false,
    2
  )
  battleButton:setOn(true)

  battleWindow = g_ui.loadUI('battle', modules.game_interface.getRightPanel())
  if not battleWindow then
    error('Nao foi possivel carregar battle.otui. Verifique indentacao e estilos do arquivo modules/game_battle/battle.otui')
  end

  g_keyboard.bindKeyDown('Ctrl+B', toggle)

  -- this disables scrollbar auto hiding
  local scrollbar = battleWindow:getChildById('miniwindowScrollBar')
  if scrollbar then
    scrollbar:mergeStyle({ ['$!on'] = { } })
  end

  battlePanel = battleWindow:recursiveGetChildById('battlePanel')
  filterPanel = battleWindow:recursiveGetChildById('filterPanel')
  toggleFilterButton = battleWindow:recursiveGetChildById('toggleFilterButton')

  if isHidingFilters() then
    hideFilterPanel()
  end

  local sortTypeBox = filterPanel.sortPanel.sortTypeBox
  local sortOrderBox = filterPanel.sortPanel.sortOrderBox

  mouseWidget = g_ui.createWidget('UIButton')
  mouseWidget:setVisible(false)
  mouseWidget:setFocusable(false)
  mouseWidget.cancelNextRelease = false

  battleWindow:setContentMinimumHeight(80)

  sortTypeBox:addOption('Nome', 'name')
  sortTypeBox:addOption('Distancia', 'distance')
  sortTypeBox:addOption('Entrada', 'age')
  sortTypeBox:addOption('Tela', 'screenage')
  sortTypeBox:addOption('Vida', 'health')
  sortTypeBox:setCurrentOptionByData(getSortType())
  sortTypeBox.onOptionChange = onChangeSortType

  sortOrderBox:addOption('Cima', 'asc')
  sortOrderBox:addOption('Baixo', 'desc')
  sortOrderBox:setCurrentOptionByData(getSortOrder())
  sortOrderBox.onOptionChange = onChangeSortOrder

  battleWindow:setup()

  for i = 1, 30 do
    local button = g_ui.createWidget('BattleButton', battlePanel)
    button:setup()
    button:hide()
    button.onHoverChange = onBattleButtonHoverChange
    button.onMouseRelease = onBattleButtonMouseRelease
    table.insert(battleButtons, button)
  end

  updateBattleList()

  connect(LocalPlayer, {
    onPositionChange = onPlayerPositionChange
  })

  connect(Creature, {
    onAppear = updateSquare,
    onDisappear = updateSquare
  })

  connect(g_game, {
    onAttackingCreatureChange = updateSquare,
    onFollowingCreatureChange = updateSquare
  })
end

function terminate()
  if battleButton == nil then
    return
  end

  if updateEvent then
    removeEvent(updateEvent)
    updateEvent = nil
  end

  g_keyboard.unbindKeyDown('Ctrl+B')

  disconnect(LocalPlayer, {
    onPositionChange = onPlayerPositionChange
  })

  disconnect(Creature, {
    onAppear = updateSquare,
    onDisappear = updateSquare
  })

  disconnect(g_game, {
    onAttackingCreatureChange = updateSquare,
    onFollowingCreatureChange = updateSquare
  })

  for _, button in ipairs(battleButtons) do
    if button then
      button:destroy()
    end
  end
  battleButtons = {}

  if battleButton then
    battleButton:destroy()
    battleButton = nil
  end

  if battleWindow then
    battleWindow:destroy()
    battleWindow = nil
  end

  if mouseWidget then
    mouseWidget:destroy()
    mouseWidget = nil
  end

  battlePanel = nil
  filterPanel = nil
  toggleFilterButton = nil
  hoveredCreature = nil
  newHoveredCreature = nil
  prevCreature = nil
end

function toggle()
  if not battleWindow or not battleButton then
    return
  end

  if battleWindow:isVisible() then
    battleWindow:close()
    battleButton:setOn(false)
  else
    battleWindow:open()
    battleButton:setOn(true)
  end
end

function onMiniWindowClose()
  if battleButton then
    battleButton:setOn(false)
  end
end

function getSortType()
  local settings = g_settings.getNode('BattleList')
  if not settings then
    if g_app.isMobile() then
      return 'distance'
    else
      return 'name'
    end
  end
  return settings['sortType'] or 'name'
end

function setSortType(state)
  local settings = {}
  settings['sortType'] = state
  g_settings.mergeNode('BattleList', settings)
  checkCreatures()
end

function getSortOrder()
  local settings = g_settings.getNode('BattleList')
  if not settings then
    return 'asc'
  end
  return settings['sortOrder'] or 'asc'
end

function setSortOrder(state)
  local settings = {}
  settings['sortOrder'] = state
  g_settings.mergeNode('BattleList', settings)
  checkCreatures()
end

function isSortAsc()
  return getSortOrder() == 'asc'
end

function isSortDesc()
  return getSortOrder() == 'desc'
end

function isHidingFilters()
  local settings = g_settings.getNode('BattleList')
  if not settings then
    return false
  end
  return settings['hidingFilters'] == true
end

function setHidingFilters(state)
  local settings = {}
  settings['hidingFilters'] = state
  g_settings.mergeNode('BattleList', settings)
end

function hideFilterPanel()
  if not filterPanel then
    return
  end

  filterPanel.originalHeight = filterPanel:getHeight()
  filterPanel:setHeight(0)

  if toggleFilterButton then
    toggleFilterButton:getParent():setMarginTop(0)
    toggleFilterButton:setImageClip(torect('0 0 21 12'))
  end

  setHidingFilters(true)
  filterPanel:setVisible(false)
end

function showFilterPanel()
  if not filterPanel then
    return
  end

  if toggleFilterButton then
    toggleFilterButton:getParent():setMarginTop(5)
    toggleFilterButton:setImageClip(torect('21 0 21 12'))
  end

  filterPanel:setHeight(filterPanel.originalHeight or 76)
  setHidingFilters(false)
  filterPanel:setVisible(true)
end

function toggleFilterPanel()
  if not filterPanel then
    return
  end

  if filterPanel:isVisible() then
    hideFilterPanel()
  else
    showFilterPanel()
  end
end

function onChangeSortType(comboBox, option, value)
  setSortType(value:lower())
end

function onChangeSortOrder(comboBox, option, value)
  -- Replace dot in option name
  setSortOrder(value:lower():gsub('[.]', ''))
end

function updateBattleList()
  if updateEvent then
    removeEvent(updateEvent)
    updateEvent = nil
  end

  updateEvent = scheduleEvent(updateBattleList, 100)
  checkCreatures()
end

function checkCreatures()
  if not battlePanel or not g_game.isOnline() then
    return
  end

  local player = g_game.getLocalPlayer()
  if not player then
    return
  end

  local mapPanel = modules.game_interface.getMapPanel()
  if not mapPanel then
    return
  end

  local dimension = mapPanel:getVisibleDimension()
  local spectators = g_map.getSpectatorsInRangeEx(
    player:getPosition(),
    false,
    math.floor(dimension.width / 3),
    math.floor(dimension.width / 3),
    math.floor(dimension.height / 3),
    math.floor(dimension.height / 3)
  )

  local maxCreatures = battlePanel:getChildCount()
  local creatures = {}
  local now = g_clock.millis()
  local resetAgePoint = now - 250

  for _, creature in ipairs(spectators) do
    if doCreatureFitFilters(creature) and #creatures < maxCreatures then
      if not creature.lastSeen or creature.lastSeen < resetAgePoint then
        creature.screenAge = now
      end

      creature.lastSeen = now

      if not ages[creature:getId()] then
        if ageNumber > 1000 then
          ageNumber = 1
          ages = {}
        end
        ages[creature:getId()] = ageNumber
        ageNumber = ageNumber + 1
      end

      table.insert(creatures, creature)
    end
  end

  updateSquare()
  sortCreatures(creatures)

  battlePanel:getLayout():disableUpdates()

  local ascOrder = isSortAsc()
  for i = 1, #creatures do
    local creature = creatures[i]
    if ascOrder then
      creature = creatures[#creatures - i + 1]
    end

    local button = battleButtons[i]
    button:creatureSetup(creature)
    button:setTooltip(creature:getName())
    button:show()
    button:setOn(true)
  end

  if g_app.isMobile() and #creatures > 0 then
    onBattleButtonHoverChange(battleButtons[1], true)
  end

  for i = #creatures + 1, maxCreatures do
    if battleButtons[i]:isHidden() then
      break
    end
    battleButtons[i]:hide()
    battleButtons[i]:setOn(false)
  end

  battlePanel:getLayout():enableUpdates()
  battlePanel:getLayout():update()
end

local function safeCall(obj, methodName)
  if not obj then
    return nil
  end

  local ok, result = pcall(function()
    if obj[methodName] then
      return obj[methodName](obj)
    end
    return nil
  end)

  if ok then
    return result
  end

  return nil
end

local function safeCreatureName(creature)
  local name = safeCall(creature, 'getName')
  if name then
    return tostring(name):lower()
  end
  return ''
end

function isOwnPokemon(creature)
  if not creature then
    return false
  end

  if creature:isLocalPlayer() then
    return false
  end

  local player = g_game.getLocalPlayer()
  if not player then
    return false
  end

  local playerId = safeCall(player, 'getId')

  -- Custom Pokemon/summon clients sometimes expose one of these methods.
  local isOwnSummon = safeCall(creature, 'isOwnSummon')
  local isLocalSummon = safeCall(creature, 'isLocalSummon')
  local isMySummon = safeCall(creature, 'isMySummon')
  local isSummon = safeCall(creature, 'isSummon')

  if isOwnSummon == true or isLocalSummon == true or isMySummon == true then
    return true
  end

  -- Owner/master/summoner id methods, when available.
  local ownerId = safeCall(creature, 'getOwnerId')
  local masterId = safeCall(creature, 'getMasterId')
  local summonerId = safeCall(creature, 'getSummonerId')

  if playerId then
    if ownerId and tonumber(ownerId) == tonumber(playerId) then
      return true
    end
    if masterId and tonumber(masterId) == tonumber(playerId) then
      return true
    end
    if summonerId and tonumber(summonerId) == tonumber(playerId) then
      return true
    end
  end

  -- Owner/master/summoner object methods, when available.
  local owner = safeCall(creature, 'getOwner')
  local master = safeCall(creature, 'getMaster')
  local summoner = safeCall(creature, 'getSummoner')

  if playerId then
    if owner and safeCall(owner, 'getId') and tonumber(safeCall(owner, 'getId')) == tonumber(playerId) then
      return true
    end
    if master and safeCall(master, 'getId') and tonumber(safeCall(master, 'getId')) == tonumber(playerId) then
      return true
    end
    if summoner and safeCall(summoner, 'getId') and tonumber(safeCall(summoner, 'getId')) == tonumber(playerId) then
      return true
    end
  end

  -- Name fallback used by some Pokemon clients: "Player's Pokemon".
  local playerName = safeCall(player, 'getName')
  local creatureName = safeCreatureName(creature)
  if playerName then
    playerName = tostring(playerName):lower()
    if creatureName:find(playerName .. "'s", 1, true) then
      return true
    end
  end

  -- Conservative fallback: some clients mark summons with ShieldYellow/ShieldBlue/etc.
  -- This only applies if the creature is a monster/summon-like creature and the client exposes isSummon.
  if isSummon == true and creature:isMonster() then
    return true
  end

  return false
end

function doCreatureFitFilters(creature)
  if creature:isLocalPlayer() then
    return false
  end

  if creature:getHealthPercent() <= 0 then
    return false
  end

  local pos = creature:getPosition()
  if not pos then
    return false
  end

  local localPlayer = g_game.getLocalPlayer()
  if not localPlayer then
    return false
  end

  local localPlayerPos = localPlayer:getPosition()
  if not localPlayerPos then
    return false
  end

  if pos.z ~= localPlayerPos.z or not creature:canBeSeen() then
    return false
  end

  local buttons = filterPanel and filterPanel.buttons
  if not buttons then
    return true
  end

  local hidePlayers = buttons.hidePlayers and buttons.hidePlayers:isChecked()
  local hideNPCs = buttons.hideNPCs and buttons.hideNPCs:isChecked()
  local hideMonsters = buttons.hideMonsters and buttons.hideMonsters:isChecked()
  local hideParty = buttons.hideParty and buttons.hideParty:isChecked()
  local hideOwnPokemon = buttons.hideOwnPokemon and buttons.hideOwnPokemon:isChecked()

  if hideOwnPokemon and isOwnPokemon(creature) then
    return false
  end

  if hidePlayers and creature:isPlayer() then
    return false
  elseif hideNPCs and creature:isNpc() then
    return false
  elseif hideMonsters and creature:isMonster() then
    return false
  elseif hideParty and creature:getShield() > ShieldWhiteBlue then
    return false
  end

  return true
end

local function getDistanceBetween(p1, p2)
  return math.max(math.abs(p1.x - p2.x), math.abs(p1.y - p2.y))
end

function sortCreatures(creatures)
  local player = g_game.getLocalPlayer()
  if not player then
    return
  end

  if getSortType() == 'distance' then
    local playerPos = player:getPosition()
    table.sort(creatures, function(a, b)
      if getDistanceBetween(playerPos, a:getPosition()) == getDistanceBetween(playerPos, b:getPosition()) then
        return ages[a:getId()] > ages[b:getId()]
      end
      return getDistanceBetween(playerPos, a:getPosition()) > getDistanceBetween(playerPos, b:getPosition())
    end)
  elseif getSortType() == 'health' then
    table.sort(creatures, function(a, b)
      if a:getHealthPercent() == b:getHealthPercent() then
        return ages[a:getId()] > ages[b:getId()]
      end
      return a:getHealthPercent() > b:getHealthPercent()
    end)
  elseif getSortType() == 'age' then
    table.sort(creatures, function(a, b)
      return ages[a:getId()] > ages[b:getId()]
    end)
  elseif getSortType() == 'screenage' then
    table.sort(creatures, function(a, b)
      return a.screenAge > b.screenAge
    end)
  else
    table.sort(creatures, function(a, b)
      if a:getName():lower() == b:getName():lower() then
        return ages[a:getId()] > ages[b:getId()]
      end
      return a:getName():lower() > b:getName():lower()
    end)
  end
end

function onBattleButtonMouseRelease(self, mousePosition, mouseButton)
  if mouseWidget.cancelNextRelease then
    mouseWidget.cancelNextRelease = false
    return false
  end

  if not self.creature then
    return false
  end

  if ((g_mouse.isPressed(MouseLeftButton) and mouseButton == MouseRightButton)
    or (g_mouse.isPressed(MouseRightButton) and mouseButton == MouseLeftButton)) then
    mouseWidget.cancelNextRelease = true
    g_game.look(self.creature, true)
    return true
  elseif mouseButton == MouseLeftButton and g_keyboard.isShiftPressed() then
    g_game.look(self.creature, true)
    return true
  elseif mouseButton == MouseRightButton and not g_mouse.isPressed(MouseLeftButton) then
    modules.game_interface.createThingMenu(mousePosition, nil, nil, self.creature)
    return true
  elseif mouseButton == MouseLeftButton and not g_mouse.isPressed(MouseRightButton) then
    if self.isTarget then
      g_game.cancelAttack()
    else
      g_game.attack(self.creature)
    end
    return true
  end

  return false
end

function onBattleButtonHoverChange(button, hovered)
  if not hovered then
    newHoveredCreature = nil
  else
    newHoveredCreature = button.creature
  end

  if button.isHovered ~= hovered then
    button.isHovered = hovered
    button:update()
  end

  updateSquare()
end

function onPlayerPositionChange(creature, newPos, oldPos)
  addEvent(checkCreatures)
end

local CreatureButtonColors = {
  onIdle = { notHovered = '#888888', hovered = '#FFFFFF' },
  onTargeted = { notHovered = '#FF0000', hovered = '#FF8888' },
  onFollowed = { notHovered = '#00FF00', hovered = '#88FF88' }
}

function updateSquare()
  local following = g_game.getFollowingCreature()
  local attacking = g_game.getAttackingCreature()

  if newHoveredCreature == nil then
    if hoveredCreature ~= nil then
      hoveredCreature:hideStaticSquare()
      hoveredCreature = nil
    end
  else
    if hoveredCreature ~= nil then
      hoveredCreature:hideStaticSquare()
    end
    hoveredCreature = newHoveredCreature
    hoveredCreature:showStaticSquare(CreatureButtonColors.onIdle.hovered)
  end

  local color = CreatureButtonColors.onIdle
  local creature = nil

  if attacking then
    color = CreatureButtonColors.onTargeted
    creature = attacking
  elseif following then
    color = CreatureButtonColors.onFollowed
    creature = following
  end

  if prevCreature ~= creature then
    if prevCreature ~= nil then
      prevCreature:hideStaticSquare()
    end
    prevCreature = creature
  end

  if not creature then
    return
  end

  color = creature == hoveredCreature and color.hovered or color.notHovered
  creature:showStaticSquare(color)
end
