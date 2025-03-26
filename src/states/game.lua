-- Game State for Nightfall Chess
-- Handles the main gameplay loop, exploration, and world interaction

local gamestate = require("lib.hump.gamestate")
local timer = require("lib.hump.timer")
local camera = require("lib.hump.camera")
local Grid = require("src.systems.grid")
local Unit = require("src.entities.unit")
local ChessMovement = require("src.systems.chess_movement")
local TurnManager = require("src.systems.turn_manager")
local CombatSystem = require("src.systems.combat_system")
local SpecialAbilitiesSystem = require("src.systems.special_abilities_system")

local Game = {}

-- Game state variables
local grid = nil
local playerUnits = {}
local enemyUnits = {}
local selectedUnit = nil
local validMoves = {}
local currentLevel = 1
local gameCamera = nil
local uiElements = {}

-- Game systems
local turnManager = nil
local combatSystem = nil
local specialAbilitiesSystem = nil

-- Initialize the game state
function Game:init()
    -- This function is called only once when the state is first created
end

-- Enter the game state
function Game:enter(previous, game)
    self.game = game
    
    -- Initialize camera
    gameCamera = camera()
    
    -- Initialize grid
    grid = Grid:new(10, 10, game.config.tileSize)
    
    -- Store grid in game object immediately to ensure it's available
    self.grid = grid
    game.grid = grid
    
    -- Initialize game systems
    turnManager = TurnManager:new(game)
    combatSystem = CombatSystem:new(game)
    specialAbilitiesSystem = SpecialAbilitiesSystem:new(game)
    
    -- Connect systems to grid
    turnManager:setGrid(grid)
    
    -- Store systems in game object for access by other components
    self.turnManager = turnManager
    self.combatSystem = combatSystem
    self.specialAbilitiesSystem = specialAbilitiesSystem
    
    -- Create player units
    self:createPlayerUnits()
    
    -- Create enemy units
    self:createEnemyUnits()
    
    -- Initialize UI elements
    self:initUI()
    
    -- Set up game state
    currentLevel = 1
    selectedUnit = nil
    validMoves = {}
    
    -- Update visibility
    grid:updateVisibility()
    
    -- Register units with turn manager
    for _, unit in ipairs(playerUnits) do
        unit.faction = "player"
    end
    
    for _, unit in ipairs(enemyUnits) do
        unit.faction = "enemy"
    end
    
    -- Initialize turn manager with all units
    local allUnits = {}
    for _, unit in ipairs(playerUnits) do
        table.insert(allUnits, unit)
    end
    for _, unit in ipairs(enemyUnits) do
        table.insert(allUnits, unit)
    end
    
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
    
    -- Start the game
    turnManager:startGame()
end

-- Leave the game state
function Game:leave()
    -- Clean up resources
    playerUnits = {}
    enemyUnits = {}
    validMoves = {}
    selectedUnit = nil
    grid = nil
    turnManager = nil
    combatSystem = nil
    specialAbilitiesSystem = nil
end

-- Update game logic
function Game:update(dt)
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
    -- Safety check for camera and grid
    if not gameCamera then
        print("Warning: gameCamera not initialized in update")
        return
    end
    
    if not grid then
        print("Warning: grid not initialized in update")
        return
    end
    
    if selectedUnit then
        local targetX, targetY = grid:gridToScreen(selectedUnit.x, selectedUnit.y)
        targetX = targetX + grid.tileSize / 2
        targetY = targetY + grid.tileSize / 2
        
        local currentX, currentY = gameCamera:position()
        local newX = currentX + (targetX - currentX) * dt * 5
        local newY = currentY + (targetY - currentY) * dt * 5
        
        gameCamera:lookAt(newX, newY)
    end
    
    -- Check for game over conditions
    self:checkGameOver()
end

-- Draw the game
function Game:draw()
    local width, height = love.graphics.getDimensions()
    
    -- Safety check for gameCamera
    if not gameCamera then
        print("Warning: gameCamera not initialized in draw")
        return
    end
    
    -- Apply camera transformations
    gameCamera:attach()
    
    -- Safety check for grid
    if not grid then
        print("Warning: grid not initialized in draw")
        gameCamera:detach()
        return
    end
    
    -- Draw grid
    self:drawGrid()
    
    -- Draw units
    self:drawUnits()
    
    -- Draw movement highlights
    self:drawMovementHighlights()
    
    -- Draw selection highlight
    self:drawSelectionHighlight()
    
    -- End camera transformations
    gameCamera:detach()
    
    -- Draw UI elements (not affected by camera)
    self:drawUI(width, height)
end

-- Draw the grid
function Game:drawGrid()
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
function Game:drawUnits()
    -- Draw player units
    for _, unit in ipairs(playerUnits) do
        local tile = grid:getTile(unit.x, unit.y)
        if tile and (tile.visible or not grid.fogOfWar) then
            unit:draw()
        end
    end
    
    -- Draw enemy units
    for _, unit in ipairs(enemyUnits) do
        local tile = grid:getTile(unit.x, unit.y)
        if tile and (tile.visible or not grid.fogOfWar) then
            unit:draw()
        end
    end
end

-- Draw movement highlights
function Game:drawMovementHighlights()
    if selectedUnit and turnManager:isPlayerTurn() then
        love.graphics.setColor(0.2, 0.8, 0.2, 0.3)
        
        for _, move in ipairs(validMoves) do
            local screenX, screenY = grid:gridToScreen(move.x, move.y)
            love.graphics.rectangle("fill", screenX, screenY, grid.tileSize, grid.tileSize)
        end
    end
end

-- Draw selection highlight
function Game:drawSelectionHighlight()
    if selectedUnit then
        local screenX, screenY = grid:gridToScreen(selectedUnit.x, selectedUnit.y)
        
        love.graphics.setColor(0.9, 0.9, 0.2, 0.7)
        love.graphics.rectangle("line", screenX + 2, screenY + 2, grid.tileSize - 4, grid.tileSize - 4)
        love.graphics.rectangle("line", screenX + 4, screenY + 4, grid.tileSize - 8, grid.tileSize - 8)
    end
end

-- Draw UI elements
function Game:drawUI(width, height)
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
    
    -- Draw level indicator
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(self.game.assets.fonts.small)
    love.graphics.print("Level: " .. currentLevel, width - 100, 20)
    
    -- Draw help text
    love.graphics.setColor(0.8, 0.8, 0.8, 0.8)
    love.graphics.setFont(self.game.assets.fonts.small)
    love.graphics.print("WASD/Arrows: Move | Space: Select | Esc: Menu", 200, height - 25)
end

-- Initialize UI elements
function Game:initUI()
    -- Create UI elements here
    uiElements = {
        -- Add UI elements as needed
    }
end

-- Create player units

function Game:createPlayerUnits()
    -- Clear existing units
    playerUnits = {}
    
    -- Check if units were selected in team management
    if self.game.playerUnits and #self.game.playerUnits > 0 then
        -- Use units selected in team management
        for i, unitData in ipairs(self.game.playerUnits) do
            -- Determine starting position based on index
            local startX, startY
            if i == 1 then
                startX, startY = 2, 5
            elseif i == 2 then
                startX, startY = 1, 3
            elseif i == 3 then
                startX, startY = 1, 7
            elseif i == 4 then
                startX, startY = 3, 5
            else
                -- Additional units get placed in remaining positions
                startX, startY = math.min(3, i-3), 3 + ((i-1) % 5)
            end
            
            -- Map unit type to movement pattern
            local movementPattern = "orthogonal"
            if unitData.type == "knight" then
                movementPattern = "knight"
            elseif unitData.type == "rook" then
                movementPattern = "orthogonal"
            elseif unitData.type == "bishop" then
                movementPattern = "diagonal"
            elseif unitData.type == "pawn" then
                movementPattern = "pawn"
            elseif unitData.type == "queen" then
                movementPattern = "queen"
            end
            
            -- Create unit with data from team management
            local unit = Unit:new({
                unitType = unitData.type,
                faction = "player",
                isPlayerControlled = true,
                health = unitData.stats.health or 15,
                maxHealth = unitData.stats.health or 15,
                attack = unitData.stats.attack or 4,
                defense = unitData.stats.defense or 2,
                moveRange = unitData.stats.speed and math.max(1, math.floor(unitData.stats.speed / 2)) or 2,
                attackRange = 1,
                movementPattern = movementPattern,
                x = startX,
                y = startY,
                abilities = unitData.abilities or {}
            })
            
            -- Add unit to grid and player units list
            grid:placeEntity(unit, startX, startY)
            table.insert(playerUnits, unit)
            
            -- Apply items if available
            if unitData.items then
                for _, item in ipairs(unitData.items) do
                    -- Apply item effects to unit stats
                    if item.stats then
                        for stat, value in pairs(item.stats) do
                            if stat == "health" or stat == "maxHealth" then
                                unit.health = unit.health + value
                                unit.maxHealth = unit.maxHealth + value
                            elseif stat == "attack" then
                                unit.attack = unit.attack + value
                            elseif stat == "defense" then
                                unit.defense = unit.defense + value
                            elseif stat == "speed" then
                                unit.moveRange = unit.moveRange + math.max(0, math.floor(value / 2))
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- Set grid reference for each unit
    for _, unit in ipairs(playerUnits) do
        unit.grid = grid
    end
end

-- Create enemy units
function Game:createEnemyUnits()
    -- Clear existing units
    enemyUnits = {}
    
    -- Create pawn
    local pawn1 = Unit:new({
        unitType = "pawn",
        faction = "enemy",
        isPlayerControlled = false,
        health = 10,
        maxHealth = 10,
        attack = 2,
        defense = 1,
        moveRange = 1,
        attackRange = 1,
        movementPattern = "pawn",
        x = 8,
        y = 3
    })
    
    -- Create another pawn
    local pawn2 = Unit:new({
        unitType = "pawn",
        faction = "enemy",
        isPlayerControlled = false,
        health = 10,
        maxHealth = 10,
        attack = 2,
        defense = 1,
        moveRange = 1,
        attackRange = 1,
        movementPattern = "pawn",
        x = 8,
        y = 7
    })
    
    -- Create knight
    local knight = Unit:new({
        unitType = "knight",
        faction = "enemy",
        isPlayerControlled = false,
        health = 15,
        maxHealth = 15,
        attack = 4,
        defense = 2,
        moveRange = 2,
        attackRange = 1,
        movementPattern = "knight",
        x = 9,
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
function Game:handleTurnStart(unit)
    -- Reset unit action states
    unit.hasMoved = false
    unit.hasAttacked = false
    unit.hasUsedAbility = false
    
    -- Update visibility
    grid:updateVisibility()
    
    -- If it's a player unit, select it
    if unit.faction == "player" then
        self:selectUnit(unit)
        print("Player unit turn started: " .. unit.unitType)
    else
        print("Enemy unit turn started: " .. unit.unitType)
        -- Process enemy AI after a short delay
        timer.after(0.5, function() 
            self:processEnemyUnit(unit) 
        end)
    end
end

-- Handle turn end event
function Game:handleTurnEnd(unit)
    -- Deselect unit if it's a player unit
    if unit.faction == "player" and selectedUnit == unit then
        selectedUnit = nil
        validMoves = {}
    end
    
    print("Turn ended for: " .. unit.unitType)
end

-- Handle phase change event
function Game:handlePhaseChange(newPhase)
    print("Phase changed to: " .. newPhase)
    
    -- Update UI based on phase
    if newPhase == "player" then
        -- Player phase started
    elseif newPhase == "enemy" then
        -- Enemy phase started
    end
end

-- Handle action points changed event
function Game:handleActionPointsChanged(oldValue, newValue)
    -- Update UI to show new action points
    print("Action points changed from " .. oldValue .. " to " .. newValue)
end

-- Process enemy unit turn
function Game:processEnemyUnit(unit)
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
function Game:findClosestPlayerUnit(enemyUnit)
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
function Game:findBestMoveTowardsTarget(unit, target)
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
function Game:moveEnemyUnit(unit, x, y)
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
    
    print("Enemy " .. unit.unitType .. " moved to " .. x .. "," .. y)
end

-- Select a unit
function Game:selectUnit(unit)
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
    validMoves = ChessMovement.getValidMoves(unit.movementPattern, unit.x, unit.y, grid, unit, unit.moveRange)
    
    print("Selected " .. unit.unitType)
end

-- Move the selected unit
function Game:moveSelectedUnit(x, y)
    -- Check if there's a selected unit and it's the player's turn
    if not selectedUnit or not turnManager:isPlayerTurn() then
        return false
    end
    
    -- Check if the unit has already moved
    if selectedUnit.hasMoved then
        print("Unit has already moved this turn")
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
        print("Invalid move")
        return false
    end
    
    -- Check if there's enough action points
    if turnManager.currentActionPoints < 1 then
        print("Not enough action points")
        return false
    end
    
    if grid:getEntityAt(x, y) ~= nil then
        -- Remove from current position
        grid:removeEntity(selectedUnit.x, selectedUnit.y)
    end
    
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
    
    -- Update visibility
    grid:updateVisibility()
    
    print("Moved " .. selectedUnit.unitType .. " to " .. x .. "," .. y)
    
    return true
end

-- Check if a unit can attack another unit
function Game:canAttack(attacker, defender)
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
function Game:attackUnit(attacker, defender)
    -- Check if attack is valid
    if not self:canAttack(attacker, defender) then
        return false
    end
    
    -- Check if there's enough action points (for player units)
    if attacker.faction == "player" and turnManager.currentActionPoints < 1 then
        print("Not enough action points")
        return false
    end
    
    -- Process attack using combat system
    combatSystem:processAttack(attacker, defender)

    -- Check for defeat
    if defender.stats.health <= 0 then
        self:defeatUnit(defender)
    end
    
    return true
end

-- Defeat a unit
function Game:defeatUnit(unit)
    -- Remove from grid
    grid:removeEntity(unit)
    
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
    
    print(unit.unitType .. " was defeated")
end

-- Check for game over conditions
function Game:checkGameOver()
    -- Check if all player units are defeated
    if #playerUnits == 0 then
        print("Game over - Player defeated")
        gamestate.switch(require("src.states.gameover"), self.game, false)
    end
    
    -- Check if all enemy units are defeated
    if #enemyUnits == 0 then
        print("Game over - Player victorious")
        gamestate.switch(require("src.states.gameover"), self.game, true)
    end
end

-- Handle key presses
function Game:keypressed(key)
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
        end
    end
end

-- Handle mouse presses
function Game:mousepressed(x, y, button)
    -- Only handle mouse input during player turn
    if not turnManager or not turnManager:isPlayerTurn() then
        return
    end
    
    -- Safety check for gameCamera
    if not gameCamera then
        print("Warning: gameCamera not initialized in mousepressed")
        return
    end
    
    -- Convert screen coordinates to grid coordinates
    local worldX, worldY = gameCamera:toWorld(x, y)
    
    -- Safety check for grid
    if not grid then
        print("Warning: grid not initialized in mousepressed")
        return
    end
    
    local gridX, gridY = grid:screenToGrid(worldX, worldY)
    
    -- Check if coordinates are within grid bounds
    if not grid:isInBounds(gridX, gridY) then
        return
    end
    
    -- Left click
    if button == 1 then
        -- Check if there's a unit at the clicked position
        local entity = grid:getEntityAt(gridX, gridY)
        
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
                end
            end
        end
    end
    
    -- Right click
    if button == 2 then
        -- Deselect unit
        selectedUnit = nil
        validMoves = {}
    end
end

return Game
