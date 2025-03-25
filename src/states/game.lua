-- Game State for Nightfall Chess
-- Handles the main gameplay loop, exploration, and world interaction

local gamestate = require("lib.hump.gamestate")
local timer = require("lib.hump.timer")
local camera = require("lib.hump.camera")
local Grid = require("src.systems.grid")
local Unit = require("src.entities.unit")
local ChessMovement = require("src.systems.chess_movement")

local Game = {}

-- Game state variables
local grid = nil
local playerUnits = {}
local enemyUnits = {}
local selectedUnit = nil
local validMoves = {}
local currentLevel = 1
local playerTurn = true
local actionPoints = 3
local gameCamera = nil
local uiElements = {}

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
    
    -- Create player units
    self:createPlayerUnits()
    
    -- Create enemy units
    self:createEnemyUnits()
    
    -- Initialize UI elements
    self:initUI()
    
    -- Set up game state
    currentLevel = 1
    playerTurn = true
    actionPoints = 3
    selectedUnit = nil
    validMoves = {}
    
    -- Update visibility
    grid:updateVisibility()
    
    -- Start turn
    self:startPlayerTurn()
end

-- Leave the game state
function Game:leave()
    -- Clean up resources
    playerUnits = {}
    enemyUnits = {}
    validMoves = {}
    selectedUnit = nil
    grid = nil
end

-- Update game logic
function Game:update(dt)
    -- Update timers
    timer.update(dt)
    
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
        
        local currentX, currentY = gameCamera:position()
        local newX = currentX + (targetX - currentX) * dt * 5
        local newY = currentY + (targetY - currentY) * dt * 5
        
        gameCamera:lookAt(newX, newY)
    end
    
    -- Check for end of turn
    if playerTurn and actionPoints <= 0 then
        self:endPlayerTurn()
    end
    
    -- Check for end of game conditions
    self:checkGameOver()
end

-- Draw the game
function Game:draw()
    local width, height = love.graphics.getDimensions()
    
    -- Apply camera transformations
    gameCamera:attach()
    
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
    if selectedUnit and playerTurn then
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
    
    if playerTurn then
        love.graphics.printf("Player Turn", 0, 20, width, "center")
    else
        love.graphics.printf("Enemy Turn", 0, 20, width, "center")
    end
    
    -- Draw action points
    love.graphics.printf("Action Points: " .. actionPoints, 0, 50, width, "center")
    
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
    love.graphics.print("WASD/Arrows: Move | Space: Select | Esc: Menu", 10, height - 25)
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
    
    -- Create knight
    local knight = Unit:new({
        unitType = "knight",
        faction = "player",
        isPlayerControlled = true,
        health = 15,
        maxHealth = 15,
        attack = 4,
        defense = 2,
        moveRange = 2,
        attackRange = 1,
        movementPattern = "knight",
        x = 2,
        y = 5
    })
    
    -- Create rook
    local rook = Unit:new({
        unitType = "rook",
        faction = "player",
        isPlayerControlled = true,
        health = 20,
        maxHealth = 20,
        attack = 5,
        defense = 3,
        moveRange = 3,
        attackRange = 2,
        movementPattern = "orthogonal",
        x = 1,
        y = 3
    })
    
    -- Create bishop
    local bishop = Unit:new({
        unitType = "bishop",
        faction = "player",
        isPlayerControlled = true,
        health = 12,
        maxHealth = 12,
        attack = 3,
        defense = 1,
        moveRange = 3,
        attackRange = 2,
        movementPattern = "diagonal",
        x = 1,
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

-- Create enemy units
function Game:createEnemyUnits()
    -- Clear existing units
    enemyUnits = {}
    
    -- Create pawn
    local pawn1 = Unit:new({
        unitType = "pawn",
        faction = "enemy",
        isPlayerControlled = false,
        health = 8,
        maxHealth = 8,
        attack = 2,
        defense = 1,
        moveRange = 1,
        attackRange = 1,
        movementPattern = "orthogonal",
        behavior = "aggressive",
        x = 8,
        y = 4
    })
    
    -- Create another pawn
    local pawn2 = Unit:new({
        unitType = "pawn",
        faction = "enemy",
        isPlayerControlled = false,
        health = 8,
        maxHealth = 8,
        attack = 2,
        defense = 1,
        moveRange = 1,
        attackRange = 1,
        movementPattern = "orthogonal",
        behavior = "aggressive",
        x = 8,
        y = 6
    })
    
    -- Create enemy knight
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
        behavior = "aggressive",
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

-- Start player turn
function Game:startPlayerTurn()
    playerTurn = true
    actionPoints = 3
    
    -- Reset unit action states
    for _, unit in ipairs(playerUnits) do
        unit.hasMoved = false
        unit.hasAttacked = false
        unit.hasUsedAbility = false
    end
    
    -- Update visibility
    grid:updateVisibility()
    
    -- Show turn start message
    print("Player turn started")
end

-- End player turn
function Game:endPlayerTurn()
    playerTurn = false
    
    -- Start enemy turn
    self:startEnemyTurn()
end

-- Start enemy turn
function Game:startEnemyTurn()
    -- Reset enemy unit action states
    for _, unit in ipairs(enemyUnits) do
        unit.hasMoved = false
        unit.hasAttacked = false
        unit.hasUsedAbility = false
    end
    
    -- Show turn start message
    print("Enemy turn started")
    
    -- Process enemy AI
    timer.after(0.5, function() self:processEnemyTurn() end)
end

-- Process enemy turn
function Game:processEnemyTurn()
    -- Simple AI for enemy units
    for i, unit in ipairs(enemyUnits) do
        -- Wait a bit between each enemy unit's actions
        timer.after(i * 0.8, function()
            self:processEnemyUnit(unit)
        end)
    end
    
    -- End enemy turn after all units have acted
    timer.after(#enemyUnits * 0.8 + 0.5, function()
        self:endEnemyTurn()
    end)
end

-- Process individual enemy unit
function Game:processEnemyUnit(unit)
    -- Simple AI: Find closest player unit and move toward it
    local closestUnit = nil
    local closestDistance = math.huge
    
    for _, playerUnit in ipairs(playerUnits) do
        local distance = math.abs(playerUnit.x - unit.x) + math.abs(playerUnit.y - unit.y)
        
        if distance < closestDistance then
            closestUnit = playerUnit
            closestDistance = distance
        end
    end
    
    if closestUnit then
        -- Try to attack if in range
        local attackTargets = ChessMovement.getAttackTargets(
            unit.movementPattern, 
            unit.x, 
            unit.y, 
            grid, 
            unit, 
            unit.stats.attackRange
        )
        
        local canAttack = false
        for _, target in ipairs(attackTargets) do
            if target.entity and target.entity.faction == "player" then
                -- Attack player unit
                self:attackUnit(unit, target.entity)
                canAttack = true
                break
            end
        end
        
        -- If couldn't attack, try to move toward player
        if not canAttack then
            local path = grid:findPath(unit.x, unit.y, closestUnit.x, closestUnit.y)
            
            if path and #path > 1 then
                -- Move along path (second node, as first is current position)
                local moveTarget = path[2]
                grid:moveEntity(unit, moveTarget.x, moveTarget.y)
                
                -- Try to attack again after moving
                attackTargets = ChessMovement.getAttackTargets(
                    unit.movementPattern, 
                    unit.x, 
                    unit.y, 
                    grid, 
                    unit, 
                    unit.stats.attackRange
                )
                
                for _, target in ipairs(attackTargets) do
                    if target.entity and target.entity.faction == "player" then
                        -- Attack player unit
                        self:attackUnit(unit, target.entity)
                        break
                    end
                end
            end
        end
    end
end

-- End enemy turn
function Game:endEnemyTurn()
    -- Start player turn
    self:startPlayerTurn()
end

-- Select a unit
function Game:selectUnit(unit)
    selectedUnit = unit
    
    -- Calculate valid moves
    if unit and playerTurn then
        validMoves = unit:getValidMovePositions()
    else
        validMoves = {}
    end
end

-- Move selected unit
function Game:moveSelectedUnit(x, y)
    if not selectedUnit or not playerTurn then
        return false
    end
    
    -- Check if move is valid
    local isValidMove = false
    for _, move in ipairs(validMoves) do
        if move.x == x and move.y == y then
            isValidMove = true
            break
        end
    end
    
    if not isValidMove then
        return false
    end
    
    -- Move the unit
    local success = grid:moveEntity(selectedUnit, x, y)
    
    if success then
        -- Mark unit as moved
        selectedUnit.hasMoved = true
        
        -- Consume action point
        actionPoints = actionPoints - 1
        
        -- Update valid moves
        validMoves = selectedUnit:getValidMovePositions()
        
        -- Update visibility
        grid:updateVisibility()
        
        return true
    end
    
    return false
end

-- Attack a unit
function Game:attackUnit(attacker, defender)
    -- Calculate damage
    local damage = math.max(1, attacker.stats.attack - defender.stats.defense)
    
    -- Apply damage
    defender.stats.health = math.max(0, defender.stats.health - damage)
    
    -- Mark attacker as having attacked
    attacker.hasAttacked = true
    
    -- Consume action point if it's player's turn
    if playerTurn then
        actionPoints = actionPoints - 1
    end
    
    -- Check if defender is defeated
    if defender.stats.health <= 0 then
        self:defeatUnit(defender)
    end
    
    -- Update valid moves if attacker is selected unit
    if attacker == selectedUnit then
        validMoves = attacker:getValidMovePositions()
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
    
    -- Clear selection if defeated unit was selected
    if unit == selectedUnit then
        self:selectUnit(nil)
    end
end

-- Check for game over conditions
function Game:checkGameOver()
    -- Check if all player units are defeated
    if #playerUnits == 0 then
        -- Game over - player lost
        gamestate.switch(require("src.states.gameover"), self.game, false)
    end
    
    -- Check if all enemy units are defeated
    if #enemyUnits == 0 then
        -- Level complete - player won
        -- For now, just go to game over with win condition
        gamestate.switch(require("src.states.gameover"), self.game, true)
    end
end

-- Handle keypresses
function Game:keypressed(key)
    if key == "escape" then
        -- Return to menu
        gamestate.switch(require("src.states.menu"), self.game)
    elseif playerTurn then
        -- Player input handling
        if key == "space" then
            -- Select unit under cursor or confirm action
            local mouseX, mouseY = love.mouse.getPosition()
            local worldX, worldY = gameCamera:mousePosition()
            local gridX, gridY = grid:screenToGrid(worldX, worldY)
            
            if grid:isInBounds(gridX, gridY) then
                local entity = grid:getEntityAt(gridX, gridY)
                
                if entity and entity.faction == "player" then
                    -- Select player unit
                    self:selectUnit(entity)
                elseif selectedUnit and not selectedUnit.hasMoved then
                    -- Try to move selected unit
                    self:moveSelectedUnit(gridX, gridY)
                end
            end
        elseif key == "tab" then
            -- Cycle through player units
            if #playerUnits > 0 then
                local currentIndex = 0
                
                -- Find current selected unit index
                if selectedUnit then
                    for i, unit in ipairs(playerUnits) do
                        if unit == selectedUnit then
                            currentIndex = i
                            break
                        end
                    end
                end
                
                -- Select next unit
                currentIndex = currentIndex % #playerUnits + 1
                self:selectUnit(playerUnits[currentIndex])
                
                -- Center camera on selected unit
                local screenX, screenY = grid:gridToScreen(selectedUnit.x, selectedUnit.y)
                gameCamera:lookAt(screenX + grid.tileSize / 2, screenY + grid.tileSize / 2)
            end
        elseif key == "return" then
            -- End turn
            self:endPlayerTurn()
        end
    end
end

-- Handle mouse presses
function Game:mousepressed(x, y, button)
    if button == 1 and playerTurn then -- Left click
        local worldX, worldY = gameCamera:mousePosition()
        local gridX, gridY = grid:screenToGrid(worldX, worldY)
        
        if grid:isInBounds(gridX, gridY) then
            local entity = grid:getEntityAt(gridX, gridY)
            
            if entity and entity.faction == "player" then
                -- Select player unit
                self:selectUnit(entity)
            elseif selectedUnit and not selectedUnit.hasMoved then
                -- Try to move selected unit
                self:moveSelectedUnit(gridX, gridY)
            end
        end
    end
end

return Game
