-- Game State for Nightfall Chess
-- Handles the main gameplay loop, exploration, and world interaction

local gamestate = require("lib.hump.gamestate")
local timer = require("lib.hump.timer")
local camera = require("lib.hump.camera")
local Grid = require("src.systems.grid")
local Unit = require("src.entities.unit")
require("src.entities.unit_animation_extension")
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
    print("--- Game:enter START ---")
    print("  Received Game object ID: " .. tostring(game))
    if game and game.playerUnits then
        print("  RECEIVED game.playerUnits: (" .. #game.playerUnits .. " units)")
        for i, unit in ipairs(game.playerUnits) do
             print("    Unit " .. i .. ": " .. (unit.id or "N/A") .. ", IsInstance=" .. tostring(unit and unit.isInstanceOf ~= nil))
        end
    else
        print("  RECEIVED game.playerUnits: NIL or EMPTY") -- <<< IS THIS LINE PRINTING?
    end

    self.game = game -- Assign the received game object to the state's self.game
    print("  Assigned self.game. Game object ID is now: " .. tostring(self.game))
    if self.game and self.game.playerUnits then
         print("  AFTER self.game assignment, self.game.playerUnits has: (" .. #self.game.playerUnits .. " units)")
    else
         print("  AFTER self.game assignment, self.game.playerUnits is NIL or EMPTY")
    end
    print("--------------------------")
    self.game = game
    
    -- Initialize camera
    gameCamera = camera()
    
    -- Initialize grid
    grid = Grid:new(10, 10, game.config.tileSize, self.game)
    
    -- Store grid in game object immediately to ensure it's available
    self.grid = grid
    game.grid = grid
    
    -- Initialize game systems
    specialAbilitiesSystem = SpecialAbilitiesSystem:new(game)
    turnManager = TurnManager:new(game)
    combatSystem = CombatSystem:new(game)
    self.game.hud = require("src.ui.hud"):new(self.game)
    self.hud = self.game.hud
    
    
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
    
    -- Check right before calling createPlayerUnits
    print("  BEFORE calling createPlayerUnits, self.game.playerUnits has: (" .. #self.game.playerUnits .. " units)")

    -- Create player units
    self:createPlayerUnits()
    
    -- Create enemy units
    self:createEnemyUnits()
    
    -- Initialize UI elements
    --self:initUI()
    
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
    for _, unit in ipairs(self.playerUnits or {}) do -- Add safety check
        local tile = grid:getTile(unit.x, unit.y)
        if tile and (tile.visible or not grid.fogOfWar) then
            unit:draw()
        end
    end
    
    -- Draw enemy units
    --for _, unit in ipairs(enemyUnits) do
    for _, unit in ipairs(self.enemyUnits or {}) do -- Add safety check
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

function Game:createPlayerUnits()
    print(">>> Game:createPlayerUnits - Starting")
    -- Use self.playerUnits for the state instance's list
    self.playerUnits = {} -- CLEAR the state's list first

    -- Safety check for self.game
    if not self.game then
        print("  ERROR: self.game is nil! Cannot access passed player units.")
        print("<<< Game:createPlayerUnits - Finished prematurely. Total self.playerUnits: 0")
        return
    end

    -- Check the units passed via the game object
    if self.game.playerUnits and #self.game.playerUnits > 0 then
        print("  Found " .. #self.game.playerUnits .. " units in self.game.playerUnits.")

        for i, unitInstance in ipairs(self.game.playerUnits) do
            -- Declare position variables for this loop iteration
            local startX, startY

            -- Determine starting position based on index 'i' within the selected team
            print("  Loop iteration i = " .. i) -- Check i value

            -- Assign startX and startY based on 'i' (NO 'local' keyword here)
            if i == 1 then
                print("    Entering i == 1 block")
                startX, startY = 2, 5
                print("    IMMEDIATELY after assignment: startX=", startX, "startY=", startY)
            elseif i == 2 then
                print("    Entering i == 2 block")
                startX, startY = 1, 3
                print("    IMMEDIATELY after assignment: startX=", startX, "startY=", startY)
            elseif i == 3 then
                 print("    Entering i == 3 block")
                 startX, startY = 1, 7
                 print("    IMMEDIATELY after assignment: startX=", startX, "startY=", startY)
            elseif i == 4 then
                 print("    Entering i == 4 block")
                 startX, startY = 3, 5
                 print("    IMMEDIATELY after assignment: startX=", startX, "startY=", startY)
            else
                 print("    Entering else block (i > 4)")
                 startX = math.min(3, i - 3)
                 startY = 3 + ((i - 1) % 5)
                 print("    IMMEDIATELY after assignment: startX=", startX, "startY=", startY)
            end

            -- Check if values were assigned correctly
            if startX == nil or startY == nil then
                 print("    ERROR: startX or startY became nil AFTER if/else block! This is unexpected.")
                 goto continue_loop_create -- Skip this unit if positioning failed
            end

            -- Print values before format call
            print("  DEBUG (before format): i=", i, "startX=", startX, "startY=", startY)
            print(string.format("  Processing unit %d: ID=%s, Type=%s, TargetPos=(%d,%d)",
                  i, unitInstance.id or "N/A", unitInstance.unitType or "N/A", startX, startY))

            -- Safety check unitInstance
             if not unitInstance or type(unitInstance) ~= "table" or not unitInstance.isInstanceOf then
                  print("    ERROR: unitInstance is not a valid Unit object!")
                  goto continue_loop_create -- Skip this entry
             end

            -- Update the unit's position and grid/game references
            unitInstance.x = startX
            unitInstance.y = startY
            unitInstance.visualX = startX
            unitInstance.visualY = startY
            unitInstance.grid = self.grid -- Use self.grid from Game state
            unitInstance.game = self.game -- Use self.game from Game state
            print("    Setting grid and game reference...")

            -- Check grid existence before placing
            if not self.grid then
                 print("    FATAL ERROR: self.grid is NIL right before calling placeEntity!")
                 goto continue_loop_create
            end
             if not self.grid.placeEntity then
                  print("    FATAL ERROR: self.grid does NOT have placeEntity method!")
                  goto continue_loop_create
             end
            print("    Grid object exists, attempting placeEntity...")

            -- Place unit on the grid
            local placeSuccess = self.grid:placeEntity(unitInstance, startX, startY)
            if placeSuccess then
                print("    Successfully placed unit on grid.")
                -- Add to the Game state's instance list
                table.insert(self.playerUnits, unitInstance)
                print("    Added unit to self.playerUnits list.")
            else
                print("    ERROR: Failed to place unit on grid!")
                -- Consider not adding to self.playerUnits if placement fails
            end

            -- Initialize cooldowns if needed (ensure this doesn't cause errors)
            unitInstance.abilityCooldowns = unitInstance.abilityCooldowns or {}
            for _, abilityId in ipairs(unitInstance.abilities or {}) do
                if unitInstance.abilityCooldowns[abilityId] == nil then
                    unitInstance.abilityCooldowns[abilityId] = 0
                end
            end

            -- Ensure HUD reference (assuming HUD is on self.game)
            -- if not self.game.hud then
            --     print("   WARNING: self.game.hud not found.")
            -- end

             ::continue_loop_create:: -- Label for goto
        end
        print("  Finished processing units from team management.")
    else
        print("  WARNING: No player units found in self.game.playerUnits. NO DEFAULT UNITS CREATED.")
        -- If you want a fallback to default units when starting directly into Game state:
        -- print("  Creating default player units as fallback.")
        -- local defaultKnight = Unit:new({ unitType="knight", faction="player", x=2, y=5, grid=self.grid, game=self.game })
        -- if self.grid:placeEntity(defaultKnight, 2, 5) then
        --     table.insert(self.playerUnits, defaultKnight)
        --     print("    Added default knight to self.playerUnits.")
        -- else
        --     print("    ERROR: Failed to place default knight.")
        -- end
        -- -- Add more default units if needed...
    end

    print("<<< Game:createPlayerUnits - Finished. Total self.playerUnits: " .. #self.playerUnits)
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
        self.hud:showNotification(("Round " .. roundNumber .. " Started"), 2)
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
            self.hud:setUnitInfo(nil)
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
        self.hud:setUnitInfo(unit, false)
    end
end

-- Move the selected unit
function Game:moveSelectedUnit(x, y)
    print(string.format(">>> Game:moveSelectedUnit - Attempting move to (%d,%d)", x, y)) -- Add log

    -- Check if there's a selected unit and it's the player's turn
    if not selectedUnit then print("  Cannot move: No unit selected."); return false end
    if not turnManager then print("  Cannot move: turnManager is nil."); return false end
    if not turnManager:isPlayerTurn() then print("  Cannot move: Not player turn."); return false end

    -- Check if the unit has already moved (using the correct property)
    if selectedUnit.hasMoved then
        print("  Cannot move: Unit has already moved this turn.")
        if self.hud then self.hud:showNotification("Unit has already moved!", 1.5) end
        return false
    end

    -- Check if the move is valid (using the Game state's validMoves)
    local isValidMove = false
    for _, move in ipairs(validMoves or {}) do -- Add safety check for validMoves
        if move.x == x and move.y == y then
            isValidMove = true
            break
        end
    end

    if not isValidMove then
        print("  Cannot move: Invalid move position.")
        if self.hud then self.hud:showNotification("Invalid move!", 1.5) end
        return false
    end

    -- Check if there's enough action points
    local moveCost = 1 -- Assuming move costs 1 AP
    if turnManager.currentActionPoints < moveCost then
        print("  Cannot move: Not enough action points.")
        if self.hud then self.hud:showNotification("Not enough action points!", 1.5) end
        return false
    end

    -- *** <<< FIX: Delegate movement to the Unit, don't change coords directly >>> ***
    print(string.format("  Calling selectedUnit:moveTo(%d, %d)", x, y))
    local moveSuccess = selectedUnit:moveTo(x, y) -- Call the unit's (extended) moveTo method
    -- *** <<< END FIX >>> ***

    if moveSuccess then
        print("  Move successful (Unit:moveTo returned true).")
        -- Mark as moved (The Unit:moveTo should ideally handle this if animation starts)
        -- Let's keep it here for now, but might move later if animation handles it
        selectedUnit.hasMoved = true
        print("  Marked unit as moved.")

        -- Use action points
        if not turnManager:useActionPoints(moveCost) then
             print("  ERROR: Failed to deduct action points after successful move check?!")
             -- This shouldn't happen based on the check above, but good to log
        end

        -- Recalculate valid moves and attacks for the *selected unit* at its new logical position
        if selectedUnit.movementPattern and selectedUnit.stats and selectedUnit.stats.moveRange and self.grid and ChessMovement then
            validMoves = ChessMovement.getValidMoves(selectedUnit.movementPattern, selectedUnit.x, selectedUnit.y, self.grid, selectedUnit, selectedUnit.stats.moveRange)
            -- Potentially recalculate attacks here too if needed: validAttacks = self:getValidAttacks(selectedUnit)
            print("  Recalculated valid moves: " .. #validMoves)
        else
            print("  WARNING: Could not recalculate valid moves after moving.")
            validMoves = {}
        end


        -- Update visibility (might be better done after animation)
        if self.grid then self.grid:updateVisibility() end

        -- Add log entry (Optional - Unit:moveTo might add a better one)
        -- print("Moved " .. selectedUnit.unitType .. " to " .. x .. "," .. y)

        print("<<< Game:moveSelectedUnit - Success")
        return true
    else
        print("  Move failed (Unit:moveTo returned false or nil).")
        if self.hud then self.hud:showNotification("Cannot move there!", 1.5) end
        print("<<< Game:moveSelectedUnit - Failure")
        return false
    end
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
        local selectedAbility = self.hud.abilityPanel:getSelectedAbility()
        if selectedAbility then
            local targetEntity = grid:getEntityAt(gridX, gridY)

            -- Attempt to use the ability
            if self.hud.abilityPanel:useSelectedAbility(targetEntity, gridX, gridY) then
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
        if self.hud and self.hud.abilityPanel:getSelectedAbility() then
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