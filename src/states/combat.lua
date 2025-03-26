-- Combat State for Nightfall Chess
-- Handles turn-based combat encounters between player and enemy units

local gamestate = require("lib.hump.gamestate")
local timer = require("lib.hump.timer")
local camera = require("lib.hump.camera")
local ChessMovement = require("src.systems.chess_movement")
local TurnManager = require("src.systems.turn_manager")
local CombatSystem = require("src.systems.combat_system")
local SpecialAbilitiesSystem = require("src.systems.special_abilities_system")
local StatusEffectsSystem = require("src.systems.status_effects_system")

local Combat = {}

-- Combat state variables
local grid = nil
local playerUnits = {}
local enemyUnits = {}
local selectedUnit = nil
local targetUnit = nil
local validMoves = {}
local validAttacks = {}
local combatCamera = nil
local uiElements = {}
local combatLog = {}
local turnCount = 1
local battleResult = nil -- nil = ongoing, "victory", "defeat"
local returnState = nil

-- Combat systems
local turnManager = nil
local combatSystem = nil
local specialAbilitiesSystem = nil
local statusEffectsSystem = nil

-- Initialize the combat state
function Combat:init()
    -- This function is called only once when the state is first created
end

-- Enter the combat state
function Combat:enter(previous, game, playerUnitsList, enemyUnitsList, gridInstance, returnToState)
    self.game = game
    returnState = returnToState or require("src.states.game")
    
    -- Initialize camera
    combatCamera = camera()
    
    -- Use provided grid or create a new one
    if gridInstance then
        grid = gridInstance
    else
        -- Create a default combat grid
        grid = require("src.systems.grid"):new(8, 8, game.config.tileSize)
        self:setupDefaultGrid()
    end
    
    -- Use provided units or create default ones
    if playerUnitsList then
        playerUnits = playerUnitsList
    else
        self:createDefaultPlayerUnits()
    end
    
    if enemyUnitsList then
        enemyUnits = enemyUnitsList
    else
        self:createDefaultEnemyUnits()
    end
    
    -- Make sure all units have grid reference
    for _, unit in ipairs(playerUnits) do
        unit.grid = grid
        unit.faction = "player"
    end
    
    for _, unit in ipairs(enemyUnits) do
        unit.grid = grid
        unit.faction = "enemy"
    end
    
    -- Initialize combat systems
    turnManager = TurnManager:new(game)
    combatSystem = CombatSystem:new(game)
    specialAbilitiesSystem = SpecialAbilitiesSystem:new(game)
    statusEffectsSystem = StatusEffectsSystem:new(game)
    
    -- Store systems in combat object for access by other components
    self.turnManager = turnManager
    self.combatSystem = combatSystem
    self.specialAbilitiesSystem = specialAbilitiesSystem
    self.statusEffectsSystem = statusEffectsSystem
    
    -- Initialize UI elements
    self:initUI()
    
    -- Set up combat state
    selectedUnit = nil
    targetUnit = nil
    validMoves = {}
    validAttacks = {}
    combatLog = {}
    turnCount = 1
    battleResult = nil
    
    -- Update visibility
    grid:updateVisibility()
    
    -- Set up turn manager callbacks
    turnManager.onTurnStart = function(unit)
        self:handleTurnStart(unit)
    end
    
    turnManager.onTurnEnd = function(unit)
        self:handleTurnEnd(unit)
    end
    
    turnManager.onPhaseChange = function(newPhase)
        self:handlePhaseChange(newPhase)
    end
    
    turnManager.onActionPointsChanged = function(oldValue, newValue)
        self:handleActionPointsChanged(oldValue, newValue)
    end
    
    -- Initialize all units with the combat system
    local allUnits = {}
    for _, unit in ipairs(playerUnits) do
        table.insert(allUnits, unit)
        combatSystem:initializeUnit(unit)
    end
    for _, unit in ipairs(enemyUnits) do
        table.insert(allUnits, unit)
        combatSystem:initializeUnit(unit)
    end
    
    -- Start combat
    self:addToCombatLog("Combat started!")
    
    -- Start the game with turn manager
    turnManager:startGame()
    
    -- Center camera on the grid
    local centerX = grid.width * grid.tileSize / 2
    local centerY = grid.height * grid.tileSize / 2
    combatCamera:lookAt(centerX, centerY)
end

-- Leave the combat state
function Combat:leave()
    -- Clean up resources
    selectedUnit = nil
    targetUnit = nil
    validMoves = {}
    validAttacks = {}
    combatLog = {}
    turnManager = nil
    combatSystem = nil
    specialAbilitiesSystem = nil
    statusEffectsSystem = nil
end

-- Update combat logic
function Combat:update(dt)
    -- Update timers
    timer.update(dt)
    
    -- Update turn manager
    turnManager:update(dt)
    
    -- Update units
    for _, unit in ipairs(playerUnits) do
        unit:update(dt)
    end
    
    for _, unit in ipairs(enemyUnits) do
        unit:update(dt)
    end
    
    -- Update camera (smooth follow if there's a selected unit)
    if selectedUnit then
        local targetX, targetY = grid:gridToScreen(selectedUnit.x, selectedUnit.y)
        targetX = targetX + grid.tileSize / 2
        targetY = targetY + grid.tileSize / 2
        
        local currentX, currentY = combatCamera:position()
        local newX = currentX + (targetX - currentX) * dt * 5
        local newY = currentY + (targetY - currentY) * dt * 5
        
        combatCamera:lookAt(newX, newY)
    end
    
    -- Check for end of combat conditions
    self:checkCombatEnd()
end

-- Draw the combat state
function Combat:draw()
    local width, height = love.graphics.getDimensions()
    
    -- Apply camera transformations
    combatCamera:attach()
    
    -- Draw grid
    self:drawGrid()
    
    -- Draw units
    self:drawUnits()
    
    -- Draw movement highlights
    self:drawMovementHighlights()
    
    -- Draw attack highlights
    self:drawAttackHighlights()
    
    -- Draw selection highlight
    self:drawSelectionHighlight()
    
    -- End camera transformations
    combatCamera:detach()
    
    -- Draw UI elements (not affected by camera)
    self:drawUI(width, height)
    
    -- Draw combat log
    self:drawCombatLog(width, height)
    
    -- Draw battle result if combat has ended
    if battleResult then
        self:drawBattleResult(width, height)
    end
end

-- Draw the grid
function Combat:drawGrid()
    for y = 1, grid.height do
        for x = 1, grid.width do
            local tile = grid:getTile(x, y)
            
            -- Skip if not visible and fog of war is enabled
            if grid.fogOfWar and not tile.visible and not tile.explored then
                goto continue
            end
            
            local screenX, screenY = grid:gridToScreen(x, y)
            
            -- Draw tile based on type
            local tileColor = {
                floor = {0.5, 0.5, 0.5},
                wall = {0.3, 0.3, 0.3},
                water = {0.2, 0.2, 0.8},
                lava = {0.8, 0.2, 0.2},
                grass = {0.2, 0.7, 0.2}
            }
            
            -- Chess-like alternating pattern for floor tiles
            if tile.type == "floor" then
                if (x + y) % 2 == 0 then
                    tileColor.floor = {0.6, 0.6, 0.6}
                else
                    tileColor.floor = {0.4, 0.4, 0.4}
                end
            end
            
            local color = tileColor[tile.type] or {0.5, 0.5, 0.5}
            
            -- Apply fog of war effect
            if grid.fogOfWar and not tile.visible and tile.explored then
                -- Darken explored but not visible tiles
                color[1] = color[1] * 0.5
                color[2] = color[2] * 0.5
                color[3] = color[3] * 0.5
            end
            
            -- Draw tile
            love.graphics.setColor(color[1], color[2], color[3], 1)
            love.graphics.rectangle("fill", screenX, screenY, grid.tileSize, grid.tileSize)
            
            -- Draw tile border
            love.graphics.setColor(0.8, 0.8, 0.8, 0.3)
            love.graphics.rectangle("line", screenX, screenY, grid.tileSize, grid.tileSize)
            
            ::continue::
        end
    end
end

-- Draw all units
function Combat:drawUnits()
    -- Draw player units
    for _, unit in ipairs(playerUnits) do
        local tile = grid:getTile(unit.x, unit.y)
        if tile and (tile.visible or not grid.fogOfWar) then
            unit:draw()
            
            -- Draw health bar
            self:drawHealthBar(unit)
            
            -- Draw status effects
            self:drawStatusEffects(unit)
        end
    end
    
    -- Draw enemy units
    for _, unit in ipairs(enemyUnits) do
        local tile = grid:getTile(unit.x, unit.y)
        if tile and (tile.visible or not grid.fogOfWar) then
            unit:draw()
            
            -- Draw health bar
            self:drawHealthBar(unit)
            
            -- Draw status effects
            self:drawStatusEffects(unit)
        end
    end
end

-- Draw health bar for a unit
function Combat:drawHealthBar(unit)
    local screenX, screenY = grid:gridToScreen(unit.x, unit.y)
    local barWidth = grid.tileSize * 0.8
    local barHeight = 4
    local barX = screenX + (grid.tileSize - barWidth) / 2
    local barY = screenY + grid.tileSize - barHeight - 2
    
    -- Background
    love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
    love.graphics.rectangle("fill", barX, barY, barWidth, barHeight)
    
    -- Health fill
    local healthPercent = unit.stats.health / unit.stats.maxHealth
    local fillWidth = barWidth * healthPercent
    
    -- Color based on health percentage
    local r, g, b = 0, 0, 0
    if healthPercent > 0.6 then
        -- Green to yellow
        r = 1 - (healthPercent - 0.6) / 0.4
        g = 1
    else
        -- Yellow to red
        r = 1
        g = healthPercent / 0.6
    end
    
    love.graphics.setColor(r, g, 0, 0.8)
    love.graphics.rectangle("fill", barX, barY, fillWidth, barHeight)
    
    -- Border
    love.graphics.setColor(0.8, 0.8, 0.8, 0.5)
    love.graphics.rectangle("line", barX, barY, barWidth, barHeight)
end

-- Draw status effects for a unit
function Combat:drawStatusEffects(unit)
    if not unit.statusEffects or #unit.statusEffects == 0 then
        return
    end
    
    local screenX, screenY = grid:gridToScreen(unit.x, unit.y)
    local iconSize = 8
    local spacing = 2
    local startX = screenX + 2
    local startY = screenY + 2
    
    for i, effect in ipairs(unit.statusEffects) do
        -- Draw status effect icon
        local x = startX + (i-1) * (iconSize + spacing)
        
        -- Different colors for different effect types
        local effectColors = {
            burning = {0.9, 0.3, 0.1},
            stunned = {0.9, 0.9, 0.1},
            weakened = {0.5, 0.1, 0.5},
            shielded = {0.1, 0.5, 0.9},
            slowed = {0.1, 0.7, 0.7}
        }
        
        local color = effectColors[effect.name] or {0.7, 0.7, 0.7}
        
        love.graphics.setColor(color[1], color[2], color[3], 0.8)
        love.graphics.rectangle("fill", x, startY, iconSize, iconSize)
        
        -- Draw border
        love.graphics.setColor(0.9, 0.9, 0.9, 0.7)
        love.graphics.rectangle("line", x, startY, iconSize, iconSize)
    end
end

-- Draw movement highlights
function Combat:drawMovementHighlights()
    if selectedUnit and turnManager:isPlayerTurn() then
        love.graphics.setColor(0.2, 0.8, 0.2, 0.3)
        
        for _, move in ipairs(validMoves) do
            local screenX, screenY = grid:gridToScreen(move.x, move.y)
            love.graphics.rectangle("fill", screenX, screenY, grid.tileSize, grid.tileSize)
        end
    end
end

-- Draw attack highlights
function Combat:drawAttackHighlights()
    if selectedUnit and turnManager:isPlayerTurn() and not selectedUnit.hasAttacked then
        love.graphics.setColor(0.8, 0.2, 0.2, 0.3)
        
        for _, attack in ipairs(validAttacks) do
            local screenX, screenY = grid:gridToScreen(attack.x, attack.y)
            love.graphics.rectangle("fill", screenX, screenY, grid.tileSize, grid.tileSize)
        end
    end
end

-- Draw selection highlight
function Combat:drawSelectionHighlight()
    if selectedUnit then
        local screenX, screenY = grid:gridToScreen(selectedUnit.x, selectedUnit.y)
        
        love.graphics.setColor(0.9, 0.9, 0.2, 0.7)
        love.graphics.rectangle("line", screenX + 2, screenY + 2, grid.tileSize - 4, grid.tileSize - 4)
        love.graphics.rectangle("line", screenX + 4, screenY + 4, grid.tileSize - 8, grid.tileSize - 8)
    end
    
    if targetUnit then
        local screenX, screenY = grid:gridToScreen(targetUnit.x, targetUnit.y)
        
        love.graphics.setColor(0.9, 0.2, 0.2, 0.7)
        love.graphics.rectangle("line", screenX + 2, screenY + 2, grid.tileSize - 4, grid.tileSize - 4)
        love.graphics.rectangle("line", screenX + 4, screenY + 4, grid.tileSize - 8, grid.tileSize - 8)
    end
end

-- Draw UI elements
function Combat:drawUI(width, height)
    -- Draw turn indicator
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(self.game.assets.fonts.medium)
    
    if turnManager:isPlayerTurn() then
        love.graphics.printf("Player Turn", 0, 20, width, "center")
    else
        love.graphics.printf("Enemy Turn", 0, 20, width, "center")
    end
    
    -- Draw action points
    love.graphics.printf("Action Points: " .. turnManager.currentActionPoints, 0, 50, width, "center")
    
    -- Draw turn count
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(self.game.assets.fonts.small)
    love.graphics.print("Turn: " .. turnCount, width - 100, 20)
    
    -- Draw selected unit info
    if selectedUnit then
        love.graphics.setColor(0.2, 0.2, 0.3, 0.8)
        love.graphics.rectangle("fill", 10, height - 100, 200, 90)
        
        love.graphics.setColor(0.8, 0.8, 0.8, 1)
        love.graphics.rectangle("line", 10, height - 100, 200, 90)
        
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setFont(self.game.assets.fonts.medium)
        love.graphics.print(selectedUnit.unitType:upper(), 20, height - 90)
        
        love.graphics.setFont(self.game.assets.fonts.small)
        love.graphics.print("HP: " .. selectedUnit.stats.health .. "/" .. selectedUnit.stats.maxHealth, 20, height - 70)
        love.graphics.print("ATK: " .. selectedUnit.stats.attack, 20, height - 55)
        love.graphics.print("DEF: " .. selectedUnit.stats.defense, 20, height - 40)
        love.graphics.print("Move: " .. selectedUnit.stats.moveRange, 20, height - 25)
    end
    
    -- Draw target unit info if different from selected
    if targetUnit and targetUnit ~= selectedUnit then
        love.graphics.setColor(0.2, 0.2, 0.3, 0.8)
        love.graphics.rectangle("fill", width - 210, height - 100, 200, 90)
        
        love.graphics.setColor(0.8, 0.8, 0.8, 1)
        love.graphics.rectangle("line", width - 210, height - 100, 200, 90)
        
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setFont(self.game.assets.fonts.medium)
        love.graphics.print(targetUnit.unitType:upper(), width - 200, height - 90)
        
        love.graphics.setFont(self.game.assets.fonts.small)
        love.graphics.print("HP: " .. targetUnit.stats.health .. "/" .. targetUnit.stats.maxHealth, width - 200, height - 70)
        love.graphics.print("ATK: " .. targetUnit.stats.attack, width - 200, height - 55)
        love.graphics.print("DEF: " .. targetUnit.stats.defense, width - 200, height - 40)
        love.graphics.print("Move: " .. targetUnit.stats.moveRange, width - 200, height - 25)
    end
    
    -- Draw help text
    love.graphics.setColor(0.8, 0.8, 0.8, 0.8)
    love.graphics.setFont(self.game.assets.fonts.small)
    love.graphics.print("WASD/Arrows: Move | Space: Select | E: End Turn | Esc: Menu", 10, height - 25)
end

-- Draw combat log
function Combat:drawCombatLog(width, height)
    -- Draw log background
    love.graphics.setColor(0.1, 0.1, 0.1, 0.7)
    love.graphics.rectangle("fill", width - 300, 80, 290, 150)
    
    love.graphics.setColor(0.5, 0.5, 0.5, 0.8)
    love.graphics.rectangle("line", width - 300, 80, 290, 150)
    
    -- Draw log title
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(self.game.assets.fonts.medium)
    love.graphics.print("Combat Log", width - 290, 85)
    
    -- Draw log entries
    love.graphics.setFont(self.game.assets.fonts.small)
    
    local maxEntries = 8
    local startIndex = math.max(1, #combatLog - maxEntries + 1)
    
    for i = startIndex, #combatLog do
        local entry = combatLog[i]
        local displayIndex = i - startIndex + 1
        
        -- Alternate row colors for readability
        if displayIndex % 2 == 0 then
            love.graphics.setColor(0.8, 0.8, 0.8, 0.8)
        else
            love.graphics.setColor(1, 1, 1, 0.8)
        end
        
        love.graphics.print(entry, width - 290, 110 + (displayIndex - 1) * 15)
    end
end

-- Draw battle result
function Combat:drawBattleResult(width, height)
    -- Darken the screen
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, width, height)
    
    -- Draw result text
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(self.game.assets.fonts.title)
    
    local resultText = battleResult == "victory" and "Victory!" or "Defeat!"
    love.graphics.printf(resultText, 0, height / 2 - 50, width, "center")
    
    -- Draw continue text
    love.graphics.setFont(self.game.assets.fonts.medium)
    love.graphics.printf("Press any key to continue", 0, height / 2 + 20, width, "center")
end

-- Initialize UI elements
function Combat:initUI()
    -- Create UI elements here
    uiElements = {
        -- Add UI elements as needed
    }
end

-- Set up default grid
function Combat:setupDefaultGrid()
    -- Create a simple 8x8 grid with walls around the edges
    for y = 1, grid.height do
        for x = 1, grid.width do
            local tileType = "floor"
            
            -- Add walls around the edges
            if x == 1 or x == grid.width or y == 1 or y == grid.height then
                tileType = "wall"
            end
            
            grid:setTile(x, y, {
                type = tileType,
                walkable = tileType ~= "wall",
                visible = false,
                explored = false
            })
        end
    end
end

-- Create default player units
function Combat:createDefaultPlayerUnits()
    -- Clear existing units
    playerUnits = {}
    
    -- Create knight
    local knight = require("src.entities.unit"):new({
        unitType = "knight",
        faction = "player",
        isPlayerControlled = true,
        stats = {
            health = 15,
            maxHealth = 15,
            attack = 4,
            defense = 2,
            moveRange = 2,
            attackRange = 1,
            energy = 10,
            maxEnergy = 10
        },
        movementPattern = "knight",
        x = 2,
        y = 3
    })
    
    -- Create rook
    local rook = require("src.entities.unit"):new({
        unitType = "rook",
        faction = "player",
        isPlayerControlled = true,
        stats = {
            health = 20,
            maxHealth = 20,
            attack = 5,
            defense = 3,
            moveRange = 3,
            attackRange = 2,
            energy = 8,
            maxEnergy = 8
        },
        movementPattern = "orthogonal",
        x = 2,
        y = 5
    })
    
    -- Create bishop
    local bishop = require("src.entities.unit"):new({
        unitType = "bishop",
        faction = "player",
        isPlayerControlled = true,
        stats = {
            health = 12,
            maxHealth = 12,
            attack = 3,
            defense = 1,
            moveRange = 3,
            attackRange = 2,
            energy = 12,
            maxEnergy = 12
        },
        movementPattern = "diagonal",
        x = 2,
        y = 7
    })
    
    -- Add units to grid and player units list
    grid:placeEntity(knight, knight.x, knight.y)
    grid:placeEntity(rook, rook.x, rook.y)
    grid:placeEntity(bishop, bishop.x, bishop.y)
    
    table.insert(playerUnits, knight)
    table.insert(playerUnits, rook)
    table.insert(playerUnits, bishop)
    
    -- Set grid reference for each unit
    for _, unit in ipairs(playerUnits) do
        unit.grid = grid
    end
end

-- Create default enemy units
function Combat:createDefaultEnemyUnits()
    -- Clear existing units
    enemyUnits = {}
    
    -- Create pawn
    local pawn1 = require("src.entities.unit"):new({
        unitType = "pawn",
        faction = "enemy",
        isPlayerControlled = false,
        stats = {
            health = 10,
            maxHealth = 10,
            attack = 2,
            defense = 1,
            moveRange = 1,
            attackRange = 1,
            energy = 5,
            maxEnergy = 5
        },
        movementPattern = "pawn",
        x = 6,
        y = 3
    })
    
    -- Create another pawn
    local pawn2 = require("src.entities.unit"):new({
        unitType = "pawn",
        faction = "enemy",
        isPlayerControlled = false,
        stats = {
            health = 10,
            maxHealth = 10,
            attack = 2,
            defense = 1,
            moveRange = 1,
            attackRange = 1,
            energy = 5,
            maxEnergy = 5
        },
        movementPattern = "pawn",
        x = 6,
        y = 7
    })
    
    -- Create knight
    local knight = require("src.entities.unit"):new({
        unitType = "knight",
        faction = "enemy",
        isPlayerControlled = false,
        stats = {
            health = 15,
            maxHealth = 15,
            attack = 4,
            defense = 2,
            moveRange = 2,
            attackRange = 1,
            energy = 10,
            maxEnergy = 10
        },
        movementPattern = "knight",
        x = 7,
        y = 5
    })
    
    -- Add units to grid and enemy units list
    grid:placeEntity(pawn1, pawn1.x, pawn1.y)
    grid:placeEntity(pawn2, pawn2.x, pawn2.y)
    grid:placeEntity(knight, knight.x, knight.y)
    
    table.insert(enemyUnits, pawn1)
    table.insert(enemyUnits, pawn2)
    table.insert(enemyUnits, knight)
    
    -- Set grid reference for each unit
    for _, unit in ipairs(enemyUnits) do
        unit.grid = grid
    end
end

-- Handle turn start event
function Combat:handleTurnStart(unit)
    -- Reset unit action states
    unit.hasMoved = false
    unit.hasAttacked = false
    unit.hasUsedAbility = false
    
    -- Update visibility
    grid:updateVisibility()
    
    -- If it's a player unit, select it
    if unit.faction == "player" then
        self:selectUnit(unit)
        self:addToCombatLog(unit.unitType:upper() .. "'s turn started")
    else
        self:addToCombatLog("Enemy " .. unit.unitType:upper() .. "'s turn started")
        -- Process enemy AI after a short delay
        timer.after(0.5, function() 
            self:processEnemyUnit(unit) 
        end)
    end
    
    -- Apply status effects that trigger at turn start
    statusEffectsSystem:triggerEffects(unit, "turnStart")
end

-- Handle turn end event
function Combat:handleTurnEnd(unit)
    -- Apply status effects that trigger at turn end
    statusEffectsSystem:triggerEffects(unit, "turnEnd")
    
    -- Deselect unit if it's a player unit
    if unit.faction == "player" and selectedUnit == unit then
        selectedUnit = nil
        validMoves = {}
        validAttacks = {}
    end
    
    self:addToCombatLog(unit.unitType:upper() .. "'s turn ended")
    
    -- Increment turn count if we've gone through all units
    if turnManager.currentInitiativeIndex == 1 then
        turnCount = turnCount + 1
    end
end

-- Handle phase change event
function Combat:handlePhaseChange(newPhase)
    self:addToCombatLog("Phase changed to: " .. newPhase)
    
    -- Update UI based on phase
    if newPhase == "player" then
        -- Player phase started
    elseif newPhase == "enemy" then
        -- Enemy phase started
    end
end

-- Handle action points changed event
function Combat:handleActionPointsChanged(oldValue, newValue)
    -- Update UI to show new action points
    -- This is handled in the draw function
end

-- Process enemy unit turn
function Combat:processEnemyUnit(unit)
    -- Simple AI for enemy units
    local targetUnit = self:findClosestPlayerUnit(unit)
    
    if targetUnit then
        -- Try to attack if in range
        if self:canAttack(unit, targetUnit) then
            self:attackUnit(unit, targetUnit)
        else
            -- Move towards target
            local movePos = self:findBestMoveTowardsTarget(unit, targetUnit)
            if movePos then
                self:moveEnemyUnit(unit, movePos.x, movePos.y)
                
                -- Try to attack after moving
                if self:canAttack(unit, targetUnit) then
                    timer.after(0.3, function()
                        self:attackUnit(unit, targetUnit)
                    end)
                end
            end
        end
    end
    
    -- End turn after a delay
    timer.after(0.8, function()
        turnManager:endTurn()
    end)
end

-- Find closest player unit
function Combat:findClosestPlayerUnit(enemyUnit)
    local closestUnit = nil
    local closestDistance = math.huge
    
    for _, unit in ipairs(playerUnits) do
        local distance = math.abs(unit.x - enemyUnit.x) + math.abs(unit.y - enemyUnit.y)
        if distance < closestDistance then
            closestDistance = distance
            closestUnit = unit
        end
    end
    
    return closestUnit
end

-- Find best move position towards target
function Combat:findBestMoveTowardsTarget(unit, target)
    local possibleMoves = ChessMovement:getValidMoves(unit, grid)
    if #possibleMoves == 0 then
        return nil
    end
    
    local bestMove = nil
    local bestDistance = math.huge
    
    for _, move in ipairs(possibleMoves) do
        local distance = math.abs(move.x - target.x) + math.abs(move.y - target.y)
        if distance < bestDistance then
            bestDistance = distance
            bestMove = move
        end
    end
    
    return bestMove
end

-- Move enemy unit
function Combat:moveEnemyUnit(unit, x, y)
    -- Remove from current position
    grid:removeEntity(unit.x, unit.y)
    
    -- Update position
    unit.x = x
    unit.y = y
    
    -- Place at new position
    grid:placeEntity(unit, x, y)
    
    -- Mark as moved
    unit.hasMoved = true
    
    -- Use action points
    turnManager:useActionPoints(1)
    
    self:addToCombatLog("Enemy " .. unit.unitType:upper() .. " moved to " .. x .. "," .. y)
end

-- Select a unit
function Combat:selectUnit(unit)
    -- Can only select units during player turn
    if not turnManager:isPlayerTurn() then
        return
    end
    
    -- Can only select player units
    if unit.faction ~= "player" then
        return
    end
    
    selectedUnit = unit
    
    -- Calculate valid moves
    validMoves = ChessMovement:getValidMoves(unit, grid)
    
    -- Calculate valid attacks
    validAttacks = self:getValidAttacks(unit)
    
    self:addToCombatLog("Selected " .. unit.unitType:upper())
end

-- Get valid attack targets for a unit
function Combat:getValidAttacks(unit)
    local attacks = {}
    
    -- Can't attack if already attacked
    if unit.hasAttacked then
        return attacks
    end
    
    -- Check all enemy units
    for _, enemy in ipairs(enemyUnits) do
        -- Check if in attack range
        local distance = math.abs(unit.x - enemy.x) + math.abs(unit.y - enemy.y)
        if distance <= unit.stats.attackRange then
            table.insert(attacks, {x = enemy.x, y = enemy.y, unit = enemy})
        end
    end
    
    return attacks
end

-- Move the selected unit
function Combat:moveSelectedUnit(x, y)
    -- Check if there's a selected unit and it's the player's turn
    if not selectedUnit or not turnManager:isPlayerTurn() then
        return false
    end
    
    -- Check if the unit has already moved
    if selectedUnit.hasMoved then
        self:addToCombatLog("Unit has already moved this turn")
        return false
    end
    
    -- Check if the move is valid
    local isValidMove = false
    for _, move in ipairs(validMoves) do
        if move.x == x and move.y == y then
            isValidMove = true
            break
        end
    end
    
    if not isValidMove then
        self:addToCombatLog("Invalid move")
        return false
    end
    
    -- Check if there's enough action points
    if turnManager.currentActionPoints < 1 then
        self:addToCombatLog("Not enough action points")
        return false
    end
    
    -- Remove from current position
    grid:removeEntity(selectedUnit.x, selectedUnit.y)
    
    -- Update position
    selectedUnit.x = x
    selectedUnit.y = y
    
    -- Place at new position
    grid:placeEntity(selectedUnit, x, y)
    
    -- Mark as moved
    selectedUnit.hasMoved = true
    
    -- Use action points
    turnManager:useActionPoints(1)
    
    -- Recalculate valid moves
    validMoves = ChessMovement:getValidMoves(selectedUnit, grid)
    
    -- Recalculate valid attacks
    validAttacks = self:getValidAttacks(selectedUnit)
    
    -- Update visibility
    grid:updateVisibility()
    
    self:addToCombatLog(selectedUnit.unitType:upper() .. " moved to " .. x .. "," .. y)
    
    return true
end

-- Check if a unit can attack another unit
function Combat:canAttack(attacker, defender)
    -- Check if units are on different teams
    if attacker.faction == defender.faction then
        return false
    end
    
    -- Check if attacker has already attacked
    if attacker.hasAttacked then
        return false
    end
    
    -- Check if defender is in attack range
    local distance = math.abs(attacker.x - defender.x) + math.abs(attacker.y - defender.y)
    return distance <= attacker.stats.attackRange
end

-- Attack a unit
function Combat:attackUnit(attacker, defender)
    -- Check if attack is valid
    if not self:canAttack(attacker, defender) then
        return false
    end
    
    -- Check if there's enough action points (for player units)
    if attacker.faction == "player" and turnManager.currentActionPoints < 1 then
        self:addToCombatLog("Not enough action points")
        return false
    end
    
    -- Process attack using combat system
    local damage, isCritical, isMiss = combatSystem:processAttack(attacker, defender)
    
    -- Create combat log entry
    local logEntry = attacker.unitType:upper() .. " attacked " .. defender.unitType:upper()
    
    if isMiss then
        logEntry = logEntry .. " but missed!"
    else
        logEntry = logEntry .. " for " .. damage .. " damage"
        if isCritical then
            logEntry = logEntry .. " (Critical Hit!)"
        end
    end
    
    self:addToCombatLog(logEntry)
    
    -- Mark attacker as having attacked
    attacker.hasAttacked = true
    
    -- Use action points (for player units)
    if attacker.faction == "player" then
        turnManager:useActionPoints(1)
    end
    
    -- Check if defender is defeated
    if defender.stats.health <= 0 then
        self:defeatUnit(defender)
    end
    
    -- Try to apply status effect
    if not isMiss and math.random() < 0.2 then
        combatSystem:tryApplyRandomStatusEffect(attacker, defender)
    end
    
    return true
end

-- Defeat a unit
function Combat:defeatUnit(unit)
    -- Remove from grid
    grid:removeEntity(unit.x, unit.y)
    
    -- Remove from appropriate list
    if unit.faction == "player" then
        for i, playerUnit in ipairs(playerUnits) do
            if playerUnit == unit then
                table.remove(playerUnits, i)
                break
            end
        end
    else
        for i, enemyUnit in ipairs(enemyUnits) do
            if enemyUnit == unit then
                table.remove(enemyUnits, i)
                break
            end
        end
    end
    
    self:addToCombatLog(unit.unitType:upper() .. " was defeated")
    
    -- Award experience if an enemy was defeated by a player unit
    if unit.faction == "enemy" then
        -- Experience would be awarded here using the experience system
    end
end

-- Add entry to combat log
function Combat:addToCombatLog(text)
    table.insert(combatLog, text)
    
    -- Limit log size
    if #combatLog > 50 then
        table.remove(combatLog, 1)
    end
end

-- Check for end of combat conditions
function Combat:checkCombatEnd()
    -- Check if all player units are defeated
    if #playerUnits == 0 and not battleResult then
        battleResult = "defeat"
        self:addToCombatLog("Combat ended - Player defeated")
        
        -- Show defeat screen after a delay
        timer.after(1, function()
            -- Handle defeat
        end)
    end
    
    -- Check if all enemy units are defeated
    if #enemyUnits == 0 and not battleResult then
        battleResult = "victory"
        self:addToCombatLog("Combat ended - Player victorious")
        
        -- Show victory screen after a delay
        timer.after(1, function()
            -- Handle victory
        end)
    end
end

-- Handle key presses
function Combat:keypressed(key)
    -- If battle is over, any key returns to previous state
    if battleResult then
        if battleResult == "victory" then
            gamestate.switch(returnState, self.game, true)
        else
            gamestate.switch(require("src.states.gameover"), self.game, false)
        end
        return
    end
    
    -- Global key handlers
    if key == "escape" then
        gamestate.switch(require("src.states.menu"), self.game)
    end
    
    -- Only handle gameplay keys during player turn
    if not turnManager:isPlayerTurn() then
        return
    end
    
    -- Movement keys
    if key == "up" or key == "w" then
        if selectedUnit then
            local targetX, targetY = selectedUnit.x, selectedUnit.y - 1
            self:moveSelectedUnit(targetX, targetY)
        end
    elseif key == "down" or key == "s" then
        if selectedUnit then
            local targetX, targetY = selectedUnit.x, selectedUnit.y + 1
            self:moveSelectedUnit(targetX, targetY)
        end
    elseif key == "left" or key == "a" then
        if selectedUnit then
            local targetX, targetY = selectedUnit.x - 1, selectedUnit.y
            self:moveSelectedUnit(targetX, targetY)
        end
    elseif key == "right" or key == "d" then
        if selectedUnit then
            local targetX, targetY = selectedUnit.x + 1, selectedUnit.y
            self:moveSelectedUnit(targetX, targetY)
        end
    end
    
    -- Selection and action keys
    if key == "space" then
        if selectedUnit then
            -- Deselect if already selected
            selectedUnit = nil
            validMoves = {}
            validAttacks = {}
        else
            -- Try to select a unit at cursor position
            -- (This would be implemented with cursor position tracking)
        end
    end
    
    -- End turn key
    if key == "return" or key == "e" then
        turnManager:endTurn()
    end
    
    -- Ability keys
    if key == "1" or key == "2" or key == "3" then
        if selectedUnit then
            local abilityIndex = tonumber(key)
            -- Use ability (would be implemented with special abilities system)
            self:useAbility(selectedUnit, abilityIndex)
        end
    end
end

-- Use a special ability
function Combat:useAbility(unit, abilityIndex)
    -- Check if unit has abilities
    if not unit.abilities or #unit.abilities < abilityIndex then
        self:addToCombatLog("No ability in that slot")
        return false
    end
    
    local abilityId = unit.abilities[abilityIndex]
    
    -- Check if ability can be used
    if not specialAbilitiesSystem:canUseAbility(unit, abilityId) then
        self:addToCombatLog("Cannot use that ability now")
        return false
    end
    
    -- Use ability
    local success = specialAbilitiesSystem:useAbility(unit, abilityId)
    
    if success then
        self:addToCombatLog(unit.unitType:upper() .. " used " .. abilityId)
        unit.hasUsedAbility = true
        turnManager:useActionPoints(1)
        return true
    else
        self:addToCombatLog("Failed to use ability")
        return false
    end
end

-- Handle mouse presses
function Combat:mousepressed(x, y, button)
    -- If battle is over, any click returns to previous state
    if battleResult then
        if battleResult == "victory" then
            gamestate.switch(returnState, self.game, true)
        else
            gamestate.switch(require("src.states.gameover"), self.game, false)
        end
        return
    end
    
    -- Only handle mouse input during player turn
    if not turnManager:isPlayerTurn() then
        return
    end
    
    -- Convert screen coordinates to grid coordinates
    local worldX, worldY = combatCamera:toWorld(x, y)
    local gridX, gridY = grid:screenToGrid(worldX, worldY)
    
    -- Check if coordinates are within grid bounds
    if not grid:isInBounds(gridX, gridY) then
        return
    end
    
    -- Left click
    if button == 1 then
        -- Check if there's a unit at the clicked position
        local entity = grid:getEntity(gridX, gridY)
        
        if entity and entity.faction == "player" then
            -- Select player unit
            self:selectUnit(entity)
        elseif selectedUnit then
            -- Check if it's a valid move position
            local isValidMove = false
            for _, move in ipairs(validMoves) do
                if move.x == gridX and move.y == gridY then
                    isValidMove = true
                    break
                end
            end
            
            if isValidMove then
                -- Move to empty tile
                self:moveSelectedUnit(gridX, gridY)
            elseif entity and entity.faction == "enemy" then
                -- Attack enemy unit if in range
                if self:canAttack(selectedUnit, entity) then
                    self:attackUnit(selectedUnit, entity)
                else
                    -- Set as target for abilities
                    targetUnit = entity
                    self:addToCombatLog("Targeting " .. entity.unitType:upper())
                end
            end
        end
    end
    
    -- Right click
    if button == 2 then
        -- Deselect unit and target
        selectedUnit = nil
        targetUnit = nil
        validMoves = {}
        validAttacks = {}
    end
end

return Combat
