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
    specialAbilitiesSystem = SpecialAbilitiesSystem:new(game)
    turnManager = TurnManager:new(game)
    combatSystem = CombatSystem:new(game)
    
    -- Connect systems to grid
    turnManager:setGrid(grid)
    
    -- Store systems in game object for access by other components
    self.specialAbilitiesSystem = specialAbilitiesSystem
    self.turnManager = turnManager
    self.combatSystem = combatSystem
    

    -- Store references in game object for access by other components
    game.specialAbilitiesSystem = specialAbilitiesSystem
    game.turnManager = turnManager
    game.combatSystem = combatSystem
    
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
    
    -- Set up turn manager callbacks
    turnManager.onTurnStart = function(unit)
        self:handleTurnStart(unit)
    end
    
    turnManager.onTurnEnd = function(unit)
        self:handleTurnEnd(unit)
    end
    
    turnManager.onRoundStart = function(roundNumber)
        self:handleRoundStart(roundNumber)
    end
    
    turnManager.onRoundEnd = function(roundNumber)
        self:handleRoundEnd(roundNumber)
    end
    
    turnManager.onActionPointsChanged = function(current, max)
        self:handleActionPointsChanged(current, max)
    end
    
    -- DEBUGGING Check abilities
    --self:debugAbilities()

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

    -- Update HUD
    if self.hud then
        self.hud:update(dt)
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
    if self.hud then
        self.hud:draw()
    end
end

-- Initialize UI elements
function Game:initUI()
    -- Create UI elements here
    -- Create HUD
    local HUD = require("src.ui.hud")
    self.hud = HUD:new(self.game)
    
    -- Store HUD in game object for access by other components
    self.game.ui = self.hud
    
    -- Set up HUD with initial game state
    self.hud:setPlayerTurn(turnManager:isPlayerTurn())
    self.hud:setActionPoints(turnManager.currentActionPoints, turnManager.maxActionPoints)
    self.hud:setLevel(currentLevel)
    
    -- Set grid for mini-map
    self.hud:setGrid(grid)
    
    -- Set help text
    self.hud:setHelpText("WASD/Arrows: Move | Space: Select | E/Enter: End Turn | Esc: Menu")
    
    -- Show notification at game start
    self.hud:showNotification("Game Started - Round 1", 3)
    uiElements = {
        -- Add UI elements as needed
    }
    
    -- Set up UI to display turn manager info
    if self.game and self.game.ui then
        self.game.ui:setPlayerTurn(turnManager:isPlayerTurn())
        self.game.ui:setActionPoints(turnManager.currentActionPoints, turnManager.maxActionPoints)
    end
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

            -- Standardize abilities
            local abilities = {}
            if unitData.abilities and #unitData.abilities > 0 then
                abilities = unitData.abilities
            else
                -- Default abilities based on unit type
                if unitData.type == "queen" then
                    abilities = {"fireball", "heal", "teleport"}
                elseif unitData.type == "bishop" then
                    abilities = {"heal", "healing_light"}
                elseif unitData.type == "knight" then
                    abilities = {"knights_charge", "feint"}
                elseif unitData.type == "rook" then
                    abilities = {"fireball", "shield"}
                elseif unitData.type == "pawn" then
                    abilities = {"strengthen"}
                end
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
                abilities = abilities,
                energy = unitData.stats.energy or 10,
                maxEnergy = unitData.stats.energy or 10,
                -- Ability cooldown table
                abilityCooldowns = {}
            })

            -- Set game reference for ability usage
            unit.game = self.game
            
            -- Add methods for ability management if not already in Unit class
            if not unit.getAbilityCooldown then
                unit.getAbilityCooldown = function(self, abilityId)
                    return self.abilityCooldowns[abilityId] or 0
                end
            end
            
            if not unit.canUseAbility then
                unit.canUseAbility = function(self, abilityId)
                    local ability = self.game.specialAbilitiesSystem:getAbility(abilityId)
                    if not ability then return false end
                    
                    -- Check cooldown
                    if self:getAbilityCooldown(abilityId) > 0 then
                        return false
                    end
                    
                    -- Check energy
                    if self.energy < (ability.energyCost or 0) then
                        return false
                    end
                    
                    return true
                end
            end
            
            if not unit.useAbility then
                unit.useAbility = function(self, abilityId, target, x, y)
                    return self.game:useAbility(self, abilityId, target, x, y)
                end
            end
            
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

-- Handle round start event
function Game:handleRoundStart(roundNumber)
    print("Round " .. roundNumber .. " started")
    -- Update visibility
    grid:updateVisibility()

    -- Show notification
    if self.hud then
        self.hud:showNotification("Round " .. roundNumber .. " Started", 2)
    end
end

-- Handle round end event
function Game:handleRoundEnd(roundNumber)
    print("Round " .. roundNumber .. " ended")

    -- Show notification
    if self.hud then
        self.hud:showNotification("Round " .. roundNumber .. " Ended", 2)
    end
end

-- Handle turn start event
function Game:handleTurnStart(unit)
    -- Update visibility
    grid:updateVisibility()
    
    -- If it's a player unit, select it
    if unit.faction == "player" then
        self:selectUnit(unit)
        print("Player unit turn started: " .. unit.unitType)
        -- Show notification
        if self.hud then
            self.hud:showNotification("Player Turn: " .. unit.unitType:upper(), 2)
        end
    else
        print("Enemy unit turn started: " .. unit.unitType)
        -- Show notification
        if self.hud then
            self.hud:showNotification("Enemy Turn: " .. unit.unitType:upper(), 2)
        end
    end

    -- Update HUD player turn indicator
    if self.hud then
        self.hud:setPlayerTurn(unit.faction == "player")
    end
end

-- Handle turn end event
function Game:handleTurnEnd(unit)
    -- Deselect unit if it's a player unit
    if unit.faction == "player" and selectedUnit == unit then
        selectedUnit = nil
        validMoves = {}

        -- Update HUD tp clear selected unit
        if self.hud then
            self.hud:setSelectedUnit(nil)
        end
    end
    
    print("Turn ended for: " .. unit.unitType)
end

-- Handle action points changed event
function Game:handleActionPointsChanged(current, max)
    -- Update UI to show new action points
    print("Action points changed to " .. current .. "/" .. max)
    
    if self.game and self.hud then
        self.hud:setActionPoints(current, max)
    end
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
    
    -- Update UI
    if self.game and self.hud then
        self.hud:setSelectedUnit(unit)
    end
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
    if not turnManager:useActionPoints(1) then
        print("Not enough action points")
        return false
    end
    
    if grid:getEntityAt(selectedUnit.x, selectedUnit.y) ~= nil then
        -- Remove from current position
        grid:removeEntity(selectedUnit)
    end
    
    -- Update position
    selectedUnit.x = x
    selectedUnit.y = y
    
    -- Place at new position
    grid:placeEntity(selectedUnit, x, y)
    
    -- Mark as moved
    selectedUnit.hasMoved = true
    
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
    if attacker.faction == "player" and not turnManager:useActionPoints(1) then
        print("Not enough action points")
        return false
    end
    
    -- Process attack using combat system
    combatSystem:processAttack(attacker, defender)
    
    -- Mark as attacked
    attacker.hasAttacked = true

    -- Show combat notification
    if self.hud then
        --self.hud:showNotification(attacker.unitType:upper() .. " dealt " .. damage .. " damage!", 1.5)
        
        -- Show target unit in enemy info panel
        self.hud:setTargetUnit(defender)
    end
    
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

    -- Show defeat notification
    if self.hud then
        self.hud:showNotification(unit.unitType:upper() .. " was defeated!", 2)
        
        -- Clear enemy info if defeated unit was targeted
        if self.hud.elements.enemyInfo.unit == unit then
            self.hud:setTargetUnit(nil)
        end
    end
    
    print(unit.unitType .. " was defeated")
end

-- Use unit ability
function Game:useAbility(unit, abilityId, target, x, y)
    if not specialAbilitiesSystem then
        print("Warning: specialAbilitiesSystem not initialized")
        return false
    end
    
    -- Get ability definition
    local ability = specialAbilitiesSystem:getAbility(abilityId)
    if not ability then
        print("Warning: Ability " .. abilityId .. " not found")
        return false
    end
    
    -- Check if there's enough action points
    if not turnManager:useActionPoints(ability.actionPointCost or 1) then
        print("Not enough action points")
        if self.hud then
            self.hud:showNotification("Not enough action points!", 1.5)
        end
        return false
    end
    
    -- Use the ability
    local success = specialAbilitiesSystem:useAbility(unit, abilityId, target, x, y)
    
    if success then
        -- Mark unit as having used an ability
        unit.hasUsedAbility = true
        
        -- Show notification
        if self.hud then
            self.hud:showNotification(unit.unitType:upper() .. " used " .. ability.name, 2)
        end
        
        -- Update visibility
        grid:updateVisibility()
    end
    
    return success
end

-- Check for game over conditions
function Game:checkGameOver()
    -- Let turn manager check for game over first
    if turnManager:checkGameOver() then
        -- Show game over notification before switching states
        if self.hud then
            if turnManager.winner == "player" then
                self.hud:showNotification("Victory! You have won!", 3)
            else
                self.hud:showNotification("Defeat! Game over...", 3)
            end
        end
        
        -- Delay game state transition to allow notification to be seen
        timer.after(3, function()
            if turnManager.winner == "player" then
                print("Game over - Player victorious")
                gamestate.switch(require("src.states.gameover"), self.game, true)
            else
                print("Game over - Player defeated")
                gamestate.switch(require("src.states.gameover"), self.game, false)
            end
        end)
        
        return true
    end
    
    return false
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

    -- Check if HUD handled the key press
    if self.hud and self.hud:keypressed(key) then
        return -- HUD consumed the key press
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
            -- If an ability is selected, use it on the unit's current position
            if self.hud and self.hud:getSelectedAbility() then
                self.hud:useSelectedAbility(nil, selectedUnit.x, selectedUnit.y)
            else
                -- Deselect if already selected
                selectedUnit = nil
                validMoves = {}

                if self.hud then
                    self.hud:setSelectedUnit(nil)

                end
            end
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
            specialAbilitiesSystem:useAbility(selectedUnit, abilityIndex)
        end
    end
end

-- Handle mouse movement
function Game:mousemoved(x, y)
    -- Forward mouse movement to HUD for ability tooltips
    if self.hud then
        self.hud:mousemoved(x, y)
    end
end

-- Handle mouse presses
function Game:mousepressed(x, y, button)
    -- Only handle mouse input during player turn
    if not turnManager or not turnManager:isPlayerTurn() then
        return
    end

    -- Check if HUD handled the input (e.g., ability panel click)
    if self.hud and self.hud:mousepressed(x, y, button) then
        return -- HUD consumed the click
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

    -- If an ability is selected, try to use it on the clicked target
    if self.hud and selectedUnit then
        local selectedAbility = self.hud:getSelectedAbility()
        if selectedAbility then
            local targetEntity = grid:getEntityAt(gridX, gridY)

            -- Attempt to use the ability
            if self.hud:useSelectedAbility(targetEntity, gridX, gridY) then
                -- Update visibility after ability use
                grid:updateVisibility()

                -- Recalculate valid moves
                if selectedUnit then
                    validMoves = ChessMovement:getValidMoves(selectedUnit.x, selectedUnit.y, grid, selectedUnit, selectedUnit.stats.moveRange)
                end

                -- Show notification
                self.hud:showNotification("Used " .. selectedAbility.name, 1.5)
                return

            end
        end
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
        -- Deselect ability if one is selected
        if self.hud and self.hud:getSelectedAbility() then
            -- Reset ability selection
            self.hud.abilityPanel.selectedSlot = nil
            return
        end

        -- Deselect unit
        selectedUnit = nil
        validMoves = {}

        -- Update HUD to clear selected unit
        if self.hud then
            self.hud:setSelectedUnit(nil)
        end
    end
end

-- Handle resize event
function Game:resize(w, h)
    -- Update HUD element positions
    if self.hud then
        self.hud:resize(w, h)
    end
end

function Game:debugAbilities()
    print("\n=== DEBUGGING ABILITIES ===")
    
    -- Check if special abilities system is initialized
    if not specialAbilitiesSystem then
        print("ERROR: specialAbilitiesSystem not initialized")
        return
    end
    
    -- List all available abilities
    print("\nAvailable abilities in specialAbilitiesSystem:")
    local count = 0
    for id, ability in pairs(specialAbilitiesSystem.abilities) do
        count = count + 1
        print(count .. ". " .. id .. " -> " .. (ability.name or "NO NAME"))
    end
    
    -- Check player units' abilities
    print("\nPlayer Units' Abilities:")
    for i, unit in ipairs(playerUnits) do
        print("Unit " .. i .. " (" .. unit.unitType .. "):")
        
        if not unit.abilities or #unit.abilities == 0 then
            print("  - No abilities")
        else
            for j, abilityId in ipairs(unit.abilities) do
                local ability = specialAbilitiesSystem:getAbility(abilityId)
                if ability then
                    print("  " .. j .. ". " .. abilityId .. " -> " .. ability.name)
                    print("     Cooldown: " .. unit:getAbilityCooldown(abilityId) .. "/" .. (ability.cooldown or 0))
                    print("     Can use: " .. tostring(unit:canUseAbility(abilityId)))
                else
                    print("  " .. j .. ". " .. abilityId .. " -> NOT FOUND IN SYSTEM")
                end
            end
        end
    end
    
    -- Check UI connections
    print("\nUI Connections:")
    print("HUD exists: " .. tostring(self.hud ~= nil))
    if self.hud then
        print("HUD has ability panel: " .. tostring(self.hud.abilityPanel ~= nil))
        if self.hud.abilityPanel then
            print("Ability panel game reference: " .. tostring(self.hud.abilityPanel.game ~= nil))
            if self.hud.abilityPanel.game then
                print("Game has specialAbilitiesSystem: " .. tostring(self.hud.abilityPanel.game.specialAbilitiesSystem ~= nil))
            end
        end
    end
    
    print("=== END DEBUGGING ===\n")
end

return Game