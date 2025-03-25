-- Combat State for Nightfall Chess
-- Handles turn-based combat encounters between player and enemy units

local gamestate = require("lib.hump.gamestate")
local timer = require("lib.hump.timer")
local camera = require("lib.hump.camera")
local ChessMovement = require("src.systems.chess_movement")

local Combat = {}

-- Combat state variables
local grid = nil
local playerUnits = {}
local enemyUnits = {}
local selectedUnit = nil
local targetUnit = nil
local validMoves = {}
local validAttacks = {}
local playerTurn = true
local actionPoints = 3
local combatCamera = nil
local uiElements = {}
local combatLog = {}
local turnCount = 1
local battleResult = nil -- nil = ongoing, "victory", "defeat"
local returnState = nil

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
    end
    
    for _, unit in ipairs(enemyUnits) do
        unit.grid = grid
    end
    
    -- Initialize UI elements
    self:initUI()
    
    -- Set up combat state
    playerTurn = true
    actionPoints = 3
    selectedUnit = nil
    targetUnit = nil
    validMoves = {}
    validAttacks = {}
    combatLog = {}
    turnCount = 1
    battleResult = nil
    
    -- Update visibility
    grid:updateVisibility()
    
    -- Start combat
    self:addToCombatLog("Combat started!")
    self:startPlayerTurn()
    
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
end

-- Update combat logic
function Combat:update(dt)
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
        
        local currentX, currentY = combatCamera:position()
        local newX = currentX + (targetX - currentX) * dt * 5
        local newY = currentY + (targetY - currentY) * dt * 5
        
        combatCamera:lookAt(newX, newY)
    end
    
    -- Check for end of turn
    if playerTurn and actionPoints <= 0 then
        self:endPlayerTurn()
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
function Combat:drawMovementHighlights()
    if selectedUnit and playerTurn and not selectedUnit.hasMoved then
        love.graphics.setColor(0.2, 0.8, 0.2, 0.3)
        
        for _, move in ipairs(validMoves) do
            local screenX, screenY = grid:gridToScreen(move.x, move.y)
            love.graphics.rectangle("fill", screenX, screenY, grid.tileSize, grid.tileSize)
        end
    end
end

-- Draw attack highlights
function Combat:drawAttackHighlights()
    if selectedUnit and playerTurn and not selectedUnit.hasAttacked then
        love.graphics.setColor(0.8, 0.2, 0.2, 0.3)
        
        for _, attack in ipairs(validAttacks) do
            if attack.isAttack then
                local screenX, screenY = grid:gridToScreen(attack.x, attack.y)
                love.graphics.rectangle("fill", screenX, screenY, grid.tileSize, grid.tileSize)
            end
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
    
    if playerTurn then
        love.graphics.printf("Player Turn", 0, 20, width, "center")
    else
        love.graphics.printf("Enemy Turn", 0, 20, width, "center")
    end
    
    -- Draw turn count
    love.graphics.setFont(self.game.assets.fonts.small)
    love.graphics.printf("Turn: " .. turnCount, width - 100, 20, 80, "right")
    
    -- Draw action points
    love.graphics.setFont(self.game.assets.fonts.medium)
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
    
    -- Draw target unit info
    if targetUnit then
        love.graphics.setColor(0.3, 0.2, 0.2, 0.8)
        love.graphics.rectangle("fill", width - 210, height - 100, 200, 90)
        
        love.graphics.setColor(0.8, 0.6, 0.6, 1)
        love.graphics.rectangle("line", width - 210, height - 100, 200, 90)
        
        love.graphics.setColor(1, 0.8, 0.8, 1)
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
    love.graphics.print("Space: Select/Attack | Tab: Next Unit | Enter: End Turn | Esc: Menu", 10, height - 25)
end

-- Draw combat log
function Combat:drawCombatLog(width, height)
    -- Draw combat log background
    love.graphics.setColor(0.1, 0.1, 0.2, 0.8)
    love.graphics.rectangle("fill", width - 300, 80, 290, 150)
    
    love.graphics.setColor(0.5, 0.5, 0.7, 1)
    love.graphics.rectangle("line", width - 300, 80, 290, 150)
    
    -- Draw combat log title
    love.graphics.setColor(0.8, 0.8, 1, 1)
    love.graphics.setFont(self.game.assets.fonts.medium)
    love.graphics.print("Combat Log", width - 290, 85)
    
    -- Draw log entries
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.setFont(self.game.assets.fonts.small)
    
    local maxEntries = 7
    local startIndex = math.max(1, #combatLog - maxEntries + 1)
    
    for i = startIndex, #combatLog do
        local entry = combatLog[i]
        local index = i - startIndex + 1
        love.graphics.print(entry, width - 290, 110 + (index - 1) * 18)
    end
end

-- Draw battle result
function Combat:drawBattleResult(width, height)
    -- Darken the screen
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, width, height)
    
    -- Draw result panel
    love.graphics.setColor(0.2, 0.2, 0.3, 0.9)
    love.graphics.rectangle("fill", width/2 - 200, height/2 - 100, 400, 200, 10, 10)
    
    love.graphics.setColor(0.8, 0.8, 0.9, 1)
    love.graphics.rectangle("line", width/2 - 200, height/2 - 100, 400, 200, 10, 10)
    
    -- Draw result text
    love.graphics.setFont(self.game.assets.fonts.title)
    
    if battleResult == "victory" then
        love.graphics.setColor(0.2, 0.9, 0.2, 1)
        love.graphics.printf("VICTORY!", width/2 - 200, height/2 - 70, 400, "center")
    else
        love.graphics.setColor(0.9, 0.2, 0.2, 1)
        love.graphics.printf("DEFEAT", width/2 - 200, height/2 - 70, 400, "center")
    end
    
    -- Draw continue prompt
    love.graphics.setFont(self.game.assets.fonts.medium)
    love.graphics.setColor(1, 1, 1, 0.8 + math.sin(love.timer.getTime() * 4) * 0.2)
    love.graphics.printf("Press SPACE to continue", width/2 - 200, height/2 + 40, 400, "center")
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
    -- Create a chess-like grid
    for y = 1, grid.height do
        for x = 1, grid.width do
            -- Set all tiles to floor by default
            grid:setTileType(x, y, "floor", true)
            
            -- Add some obstacles
            if (x == 4 and y == 3) or (x == 5 and y == 6) then
                grid:setTileType(x, y, "wall", false)
            end
            
            -- Add some water
            if (x == 2 and y == 5) or (x == 7 and y == 4) then
                grid:setTileType(x, y, "water", false)
            end
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
        health = 15,
        maxHealth = 15,
        attack = 4,
        defense = 2,
        moveRange = 2,
        attackRange = 1,
        movementPattern = "knight",
        x = 2,
        y = 2
    })
    
    -- Create rook
    local rook = require("src.entities.unit"):new({
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
        y = 1
    })
    
    -- Create bishop
    local bishop = require("src.entities.unit"):new({
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
        x = 3,
        y = 1
    })
    
    -- Add units to grid and player units list
    grid:placeEntity(knight, knight.x, knight.y)
    grid:placeEntity(rook, rook.x, rook.y)
    grid:placeEntity(bishop, bishop.x, bishop.y)
    
    table.insert(playerUnits, knight)
    table.insert(playerUnits, rook)
    table.insert(playerUnits, bishop)
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
        health = 8,
        maxHealth = 8,
        attack = 2,
        defense = 1,
        moveRange = 1,
        attackRange = 1,
        movementPattern = "orthogonal",
        behavior = "aggressive",
        x = 6,
        y = 6
    })
    
    -- Create another pawn
    local pawn2 = require("src.entities.unit"):new({
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
        x = 6,
        y = 8
    })
    
    -- Create enemy knight
    local knight = require("src.entities.unit"):new({
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
        x = 8,
        y = 7
    })
    
    -- Add units to grid and enemy units list
    grid:placeEntity(pawn1, pawn1.x, pawn1.y)
    grid:placeEntity(pawn2, pawn2.x, pawn2.y)
    grid:placeEntity(knight, knight.x, knight.y)
    
    table.insert(enemyUnits, pawn1)
    table.insert(enemyUnits, pawn2)
    table.insert(enemyUnits, knight)
end

-- Start player turn
function Combat:startPlayerTurn()
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
    
    -- Add to combat log
    self:addToCombatLog("Player turn " .. turnCount .. " started.")
end

-- End player turn
function Combat:endPlayerTurn()
    playerTurn = false
    
    -- Start enemy turn
    self:startEnemyTurn()
end

-- Start enemy turn
function Combat:startEnemyTurn()
    -- Reset enemy unit action states
    for _, unit in ipairs(enemyUnits) do
        unit.hasMoved = false
        unit.hasAttacked = false
        unit.hasUsedAbility = false
    end
    
    -- Add to combat log
    self:addToCombatLog("Enemy turn " .. turnCount .. " started.")
    
    -- Process enemy AI
    timer.after(0.5, function() self:processEnemyTurn() end)
end

-- Process enemy turn
function Combat:processEnemyTurn()
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
function Combat:processEnemyUnit(unit)
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
                
                -- Add to combat log
                self:addToCombatLog(unit.unitType:upper() .. " moves to " .. moveTarget.x .. "," .. moveTarget.y)
                
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
function Combat:endEnemyTurn()
    -- Increment turn counter
    turnCount = turnCount + 1
    
    -- Start player turn
    self:startPlayerTurn()
end

-- Select a unit
function Combat:selectUnit(unit)
    selectedUnit = unit
    targetUnit = nil
    
    -- Calculate valid moves and attacks
    if unit and playerTurn then
        if not unit.hasMoved then
            validMoves = unit:getValidMovePositions()
        else
            validMoves = {}
        end
        
        if not unit.hasAttacked then
            validAttacks = ChessMovement.getAttackTargets(
                unit.movementPattern, 
                unit.x, 
                unit.y, 
                grid, 
                unit, 
                unit.stats.attackRange
            )
        else
            validAttacks = {}
        end
    else
        validMoves = {}
        validAttacks = {}
    end
end

-- Select a target
function Combat:selectTarget(unit)
    if unit and unit.faction ~= "player" then
        targetUnit = unit
    else
        targetUnit = nil
    end
end

-- Move selected unit
function Combat:moveSelectedUnit(x, y)
    if not selectedUnit or not playerTurn or selectedUnit.hasMoved then
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
    
    -- Add to combat log
    self:addToCombatLog(selectedUnit.unitType:upper() .. " moves to " .. x .. "," .. y)
    
    -- Move the unit
    local success = grid:moveEntity(selectedUnit, x, y)
    
    if success then
        -- Mark unit as moved
        selectedUnit.hasMoved = true
        
        -- Consume action point
        actionPoints = actionPoints - 1
        
        -- Update valid moves and attacks
        validMoves = {}
        
        if not selectedUnit.hasAttacked then
            validAttacks = ChessMovement.getAttackTargets(
                selectedUnit.movementPattern, 
                selectedUnit.x, 
                selectedUnit.y, 
                grid, 
                selectedUnit, 
                selectedUnit.stats.attackRange
            )
        else
            validAttacks = {}
        end
        
        -- Update visibility
        grid:updateVisibility()
        
        return true
    end
    
    return false
end

-- Attack a unit
function Combat:attackUnit(attacker, defender)
    -- Calculate damage
    local damage = math.max(1, attacker.stats.attack - defender.stats.defense)
    
    -- Add to combat log
    self:addToCombatLog(attacker.unitType:upper() .. " attacks " .. defender.unitType:upper() .. " for " .. damage .. " damage!")
    
    -- Apply damage
    defender.stats.health = math.max(0, defender.stats.health - damage)
    
    -- Mark attacker as having attacked
    attacker.hasAttacked = true
    
    -- Consume action point if it's player's turn
    if playerTurn and attacker.faction == "player" then
        actionPoints = actionPoints - 1
    end
    
    -- Check if defender is defeated
    if defender.stats.health <= 0 then
        self:defeatUnit(defender)
    end
    
    -- Update valid moves and attacks if attacker is selected unit
    if attacker == selectedUnit then
        validMoves = {}
        validAttacks = {}
    end
    
    -- Clear target if it was the defender
    if defender == targetUnit then
        targetUnit = nil
    end
    
    return true
end

-- Defeat a unit
function Combat:defeatUnit(unit)
    -- Add to combat log
    self:addToCombatLog(unit.unitType:upper() .. " is defeated!")
    
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
    
    -- Clear target if defeated unit was targeted
    if unit == targetUnit then
        targetUnit = nil
    end
end

-- Check for end of combat conditions
function Combat:checkCombatEnd()
    -- Check if all player units are defeated
    if #playerUnits == 0 and not battleResult then
        -- Combat over - player lost
        battleResult = "defeat"
        self:addToCombatLog("Combat ended in defeat!")
    end
    
    -- Check if all enemy units are defeated
    if #enemyUnits == 0 and not battleResult then
        -- Combat over - player won
        battleResult = "victory"
        self:addToCombatLog("Combat ended in victory!")
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

-- Handle keypresses
function Combat:keypressed(key)
    -- If battle is over, space continues to the next state
    if battleResult and (key == "space" or key == "return") then
        if battleResult == "victory" then
            -- Return to previous state with victory
            gamestate.switch(returnState, self.game, true)
        else
            -- Game over on defeat
            gamestate.switch(require("src.states.gameover"), self.game, false)
        end
        return
    end
    
    if key == "escape" then
        -- Return to menu
        gamestate.switch(require("src.states.menu"), self.game)
    elseif playerTurn then
        -- Player input handling
        if key == "space" then
            -- Select unit under cursor or confirm action
            local mouseX, mouseY = love.mouse.getPosition()
            local worldX, worldY = combatCamera:mousePosition()
            local gridX, gridY = grid:screenToGrid(worldX, worldY)
            
            if grid:isInBounds(gridX, gridY) then
                local entity = grid:getEntityAt(gridX, gridY)
                
                if entity then
                    if entity.faction == "player" then
                        -- Select player unit
                        self:selectUnit(entity)
                    elseif selectedUnit and not selectedUnit.hasAttacked then
                        -- Check if this is a valid attack target
                        local isValidTarget = false
                        for _, attack in ipairs(validAttacks) do
                            if attack.x == entity.x and attack.y == entity.y and attack.isAttack then
                                isValidTarget = true
                                break
                            end
                        end
                        
                        if isValidTarget then
                            -- Attack enemy unit
                            self:attackUnit(selectedUnit, entity)
                        end
                    end
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
                combatCamera:lookAt(screenX + grid.tileSize / 2, screenY + grid.tileSize / 2)
            end
        elseif key == "return" then
            -- End turn
            self:endPlayerTurn()
        end
    end
end

-- Handle mouse presses
function Combat:mousepressed(x, y, button)
    -- If battle is over, clicking continues to the next state
    if battleResult then
        if battleResult == "victory" then
            -- Return to previous state with victory
            gamestate.switch(returnState, self.game, true)
        else
            -- Game over on defeat
            gamestate.switch(require("src.states.gameover"), self.game, false)
        end
        return
    end
    
    if button == 1 and playerTurn then -- Left click
        local worldX, worldY = combatCamera:mousePosition()
        local gridX, gridY = grid:screenToGrid(worldX, worldY)
        
        if grid:isInBounds(gridX, gridY) then
            local entity = grid:getEntityAt(gridX, gridY)
            
            if entity then
                if entity.faction == "player" then
                    -- Select player unit
                    self:selectUnit(entity)
                elseif selectedUnit and not selectedUnit.hasAttacked then
                    -- Check if this is a valid attack target
                    local isValidTarget = false
                    for _, attack in ipairs(validAttacks) do
                        if attack.x == entity.x and attack.y == entity.y and attack.isAttack then
                            isValidTarget = true
                            break
                        end
                    end
                    
                    if isValidTarget then
                        -- Attack enemy unit
                        self:attackUnit(selectedUnit, entity)
                    end
                end
            elseif selectedUnit and not selectedUnit.hasMoved then
                -- Try to move selected unit
                self:moveSelectedUnit(gridX, gridY)
            end
        end
    end
end

return Combat
