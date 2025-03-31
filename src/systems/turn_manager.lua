-- Enhanced Turn Manager System for Nightfall Chess
-- Handles turn sequence, initiative, action points, and turn-based events

local class = require("lib.middleclass.middleclass")
local timer = require("lib.hump.timer")

local TurnManager = class("TurnManager")

function TurnManager:initialize(game)
    self.game = game
    
    -- Turn state
    self.currentPhase = "player" -- "player", "enemy", "environment"
    self.turnNumber = 1
    self.roundNumber = 1
    
    -- Unit initiative order
    self.initiativeOrder = {}
    self.currentInitiativeIndex = 1
    
    -- *** REMOVED: Global Action Points System ***
    -- self.maxActionPoints = 3
    -- self.currentActionPoints = self.maxActionPoints
    
    -- Turn events
    self.turnStartEvents = {}
    self.turnEndEvents = {}
    self.roundStartEvents = {}
    self.roundEndEvents = {}
    -- self.actionPointEvents = {} -- Removing this specific list, using onActionPointsChanged callback
    
    -- Status effects that trigger on turns
    self.statusEffects = {}
    
    -- Callbacks
    self.onTurnStart = nil
    self.onTurnEnd = nil
    self.onRoundStart = nil
    self.onRoundEnd = nil
    self.onPhaseChange = nil
    self.onActionPointsChanged = nil
    
    -- Turn history for replay/undo
    self.turnHistory = {}
    self.maxHistoryLength = 10
    
    -- Turn timer (for timed turns)
    self.turnTimeLimit = nil
    self.turnTimer = 0
    self.turnTimerActive = false
    
    -- Game state
    self.gameOver = false
    self.winner = nil
    
    -- Grid reference (will be set by game)
    self.grid = nil
end

-- Start a new game
function TurnManager:startGame()
    print("TurnManager:startGame - self.game.grid:", type(self.game.grid), tostring(self.game.grid))
    self.turnNumber = 1
    self.roundNumber = 1
    self.currentPhase = "player"
    self.gameOver = false
    self.winner = nil
    
    -- *** REMOVED: Reset global action points ***
    -- self.currentActionPoints = self.maxActionPoints
    
    -- Clear turn history
    self.turnHistory = {}
    
    -- Calculate initial initiative order
    self:calculateInitiativeOrder()
    
    -- Trigger round start
    self:triggerRoundStart()

    -- Update HUD turn info
    if self.game and self.game.hud and self.game.hud.setTurnInfo then
        self.game.hud:setTurnInfo(self.turnNumber, self.roundNumber)
    end
    
    -- Start first turn
    self:startTurn()
    
    -- *** REMOVED: Notify UI of global AP (will be handled in startTurn) ***
    -- if self.game and self.game.ui then
    --     self.game.ui:setPlayerTurn(self:isPlayerTurn())
    --     self.game.ui:setActionPoints(self.currentActionPoints, self.maxActionPoints)
    -- end
end

-- Calculate initiative order for all units
function TurnManager:calculateInitiativeOrder()
    self.initiativeOrder = {}
    
    -- Safety check: ensure grid exists
    if not self.game or not self.grid or not self.grid.entities then
        print("  WARNING: Grid/Entities not initialized for initiative calculation. Order will be empty.")
         -- *** FIX: Update HUD even if order is empty ***
         if self.game.uiManager and self.game.uiManager.hud and self.game.uiManager.hud.setTurnOrder then
             self.game.uiManager.hud:setTurnOrder({}, 1)
         end
        return
    end
    
    -- Get all units from the grid
    local units = {}
    for entity, _ in pairs(self.grid.entities) do
        if entity.faction then
            table.insert(units, entity)
        end
    end
    
    -- If no units found, try using the grid reference directly
    if #units == 0 and self.grid and self.grid.entities then
        for entity, _ in pairs(self.grid.entities) do
            if entity.faction then
                table.insert(units, entity)
            end
        end
    end
    
    -- If still no units, return empty initiative order
    if #units == 0 then
        print("  WARNING: No active units found for initiative calculation.")
         -- *** FIX: Update HUD even if order is empty ***
         if self.game.uiManager and self.game.uiManager.hud and self.game.uiManager.hud.setTurnOrder then
             self.game.uiManager.hud:setTurnOrder({}, 1)
         end
        return
    end
    
    -- Sort by initiative (based on unit stats, random factors, etc.)
    table.sort(units, function(a, b)
        -- First sort by faction (player units go first)
        if a.faction ~= b.faction then
            return a.faction == "player"
        end
        
        -- Then sort by initiative stat if available
        if a.stats and b.stats and a.stats.initiative and b.stats.initiative then
            return a.stats.initiative > b.stats.initiative
        end
        
        -- Otherwise sort by unit type priority
        local typePriority = {
            king = 1,
            queen = 2,
            rook = 3,
            bishop = 4,
            knight = 5,
            pawn = 6
        }
        
        local aPriority = typePriority[a.unitType] or 99
        local bPriority = typePriority[b.unitType] or 99
        
        return aPriority < bPriority
    end)
    
    -- Store initiative order
    self.initiativeOrder = units
    self.currentInitiativeIndex = 1

    -- *** FIX: Update the HUD with the new order ***
    if self.game.uiManager and self.game.uiManager.hud and self.game.uiManager.hud.setTurnOrder then
        print("  Updating HUD turn order display.")
        self.game.uiManager.hud:setTurnOrder(self.initiativeOrder, self.currentInitiativeIndex)
    else
        print("  WARNING: Cannot update HUD turn order (UIManager/HUD/setTurnOrder missing).")
    end
    print("---------------------------------------------") -- End log
end

-- Start a new turn
function TurnManager:startTurn()
    print(string.format(">>> TurnManager:startTurn - Turn: %d, Round: %d, Index: %d", self.turnNumber, self.roundNumber, self.currentInitiativeIndex))

    -- Check for game over before starting turn
    if self:checkGameOver() then
        print("  Game over detected, stopping turn sequence.")
        -- Game over handling is initiated within checkGameOver or by Game state observing self.gameOver
        return
    end

    -- Recalculate initiative if units might have been removed mid-round
    -- (More robust: do this check or always recalc in endRound/startRound)
    -- For now, assume initiative is valid until end of round.

    -- Check if index is valid *after* potential removals
    if self.currentInitiativeIndex > #self.initiativeOrder then
        print("  Index out of bounds (#" .. self.currentInitiativeIndex .. " > " .. #self.initiativeOrder .. "), ending round.")
        self:endRound()
        return -- Exit early if index is bad
    end

    local currentUnit = self.initiativeOrder[self.currentInitiativeIndex]

    if not currentUnit then
        print("  ERROR: currentUnit is nil at index " .. self.currentInitiativeIndex .. "! Initiative order might be corrupt. Ending round.")
        self:endRound() -- Attempt recovery
        return
    end
    -- Double check unit health in case it was defeated but not removed from list yet
    if not currentUnit.stats or currentUnit.stats.health <= 0 then
         print(string.format("  Skipping turn for defeated unit %s at index %d", currentUnit.id or 'N/A', self.currentInitiativeIndex))
         self:endTurn() -- Skip this unit's turn
         return
    end


    if self.game and self.game.hud and self.game.hud.setTurnInfo then
        self.game.hud:setTurnInfo(self.turnNumber, self.roundNumber)
    end

    print(string.format("  Current Unit: ID=%s, Type=%s, Faction=%s, AP=%s/%s",
        currentUnit.id or "N/A", currentUnit.unitType or "N/A", currentUnit.faction or "N/A",
        tostring(currentUnit.stats.actionPoints), tostring(currentUnit.stats.maxActionPoints)))

    -- Set current phase based on unit faction
    self.currentPhase = currentUnit.faction

    -- Reset unit action state (includes AP replenishment now)
    if currentUnit.resetActionState then
        currentUnit:resetActionState()
    else
        -- Fallback basic reset if method is missing (shouldn't happen with class)
        currentUnit.hasMoved = false
        currentUnit.hasAttacked = false
        currentUnit.hasUsedAbility = false
        -- Manual AP reset if method is missing (less ideal)
        if currentUnit.stats then
            currentUnit.stats.actionPoints = currentUnit.stats.maxActionPoints or 0
        end
    end

    -- *** FIX: Update the HUD with the current index ***
    if self.game.uiManager and self.game.uiManager.hud and self.game.uiManager.hud.setTurnOrder then
        -- Pass the existing order but the *new* current index
        self.game.uiManager.hud:setTurnOrder(self.initiativeOrder, self.currentInitiativeIndex)
    end
    -- *** END FIX ***
    
    -- *** NEW: Notify UI/Game of the CURRENT UNIT's action points change ***
    if self.onActionPointsChanged and currentUnit.stats then
        self.onActionPointsChanged(currentUnit.stats.actionPoints, currentUnit.stats.maxActionPoints)
    end

    -- Apply status effects that trigger at turn start
    self:applyStatusEffects(currentUnit, "turnStart")

    -- Trigger turn start events (Passes the unit whose turn is starting)
    self:triggerTurnStart(currentUnit)

    -- Start turn timer if enabled
    if self.turnTimeLimit and currentUnit.faction == "player" then
        self.turnTimer = self.turnTimeLimit
        self.turnTimerActive = true
    end

    -- If it's an enemy unit, start AI processing
    if currentUnit.faction == "enemy" then
        self:processEnemyTurn(currentUnit)
    end

    -- Update UI (simplified, assumes Game state handles selection/HUD updates via callbacks)
    if self.game and self.game.uiManager and self.game.uiManager.hud then
        local hud = self.game.uiManager.hud
        hud:setPlayerTurn(self:isPlayerTurn())
        -- Selection is handled by Game state based on turn start callback
        -- AP is handled by the onActionPointsChanged callback
        -- Showing turn notification is handled by Game state callback
    end

    print("<<< TurnManager:startTurn finished")
end

-- End the current turn
function TurnManager:endTurn()
    print(string.format(">>> TurnManager:endTurn - Ending turn for index %d", self.currentInitiativeIndex))

    -- Basic check if game already ended
    if self.gameOver then return end

    -- Get current unit (check if index is still valid)
    if self.currentInitiativeIndex > #self.initiativeOrder then
         print("  EndTurn called with invalid index, likely end of round. Proceeding to next logical step (likely starting next turn/round).")
         -- This might happen if last unit was defeated. Let startTurn handle round end.
         self.currentInitiativeIndex = self.currentInitiativeIndex + 1
         self.turnNumber = self.turnNumber + 1
         self:startTurn() -- Let startTurn figure out if it's a new round
         return
    end

    local currentUnit = self.initiativeOrder[self.currentInitiativeIndex]

    if not currentUnit then
        print("  ERROR: Could not get current unit at index " .. self.currentInitiativeIndex .. " in endTurn.")
        -- Try to recover by moving to next index cautiously
        self.currentInitiativeIndex = self.currentInitiativeIndex + 1
        self.turnNumber = self.turnNumber + 1
        self:startTurn() -- Let startTurn handle round end / next unit
        return
    end

     print(string.format("  Ending turn for Unit: ID=%s, Type=%s, Faction=%s",
        currentUnit.id or "N/A", currentUnit.unitType or "N/A", currentUnit.faction or "N/A"))

    -- Apply status effects that trigger at turn end
    self:applyStatusEffects(currentUnit, "turnEnd")

    -- Trigger turn end events (Passes the unit whose turn just ended)
    self:triggerTurnEnd(currentUnit)

    -- Save turn to history
    -- self:saveTurnToHistory(currentUnit) -- Optional: Decide if history is needed

    -- Move to next unit in initiative order
    self.currentInitiativeIndex = self.currentInitiativeIndex + 1
    self.turnNumber = self.turnNumber + 1

    -- Reset turn timer
    self.turnTimerActive = false

    -- Start next turn (which will handle round end if index is out of bounds)
    self:startTurn()
    print("<<< TurnManager:endTurn finished, called startTurn for next")
end

-- End the current round
function TurnManager:endRound()
    print(">>> TurnManager:endRound - Ending Round: " .. self.roundNumber)
    -- Trigger round end events
    self:triggerRoundEnd()

    -- Apply status effects that trigger at round end
    self:applyStatusEffects(nil, "roundEnd") -- Pass nil for global effects

    -- Increment round number
    self.roundNumber = self.roundNumber + 1
    self.turnNumber = 1 -- Reset turn number for the new round

    -- Recalculate initiative order (important for removed units/new spawns)
    self:calculateInitiativeOrder()

    -- Check for game over *after* recalculating initiative (in case last unit died)
    if self:checkGameOver() then
        print("  Game over detected after round end, stopping turn sequence.")
        return
    end
    -- Check if initiative order is now empty (e.g., draw condition?)
    if #self.initiativeOrder == 0 then
        print("  Initiative order empty after round end. Game might be a draw or ended.")
        -- Potentially set gameOver state here if needed
        self.gameOver = true
        self.winner = "draw" -- Or determine based on game rules
        return
    end

    -- Apply status effects that trigger at round start
    self:applyStatusEffects(nil, "roundStart") -- Pass nil for global effects

    -- Trigger round start events
    self:triggerRoundStart()

    -- Reset initiative index
    self.currentInitiativeIndex = 1

    -- Update HUD turn info
    if self.game and self.game.hud and self.game.hud.setTurnInfo then
        self.game.hud:setTurnInfo(self.turnNumber, self.roundNumber)
    end

    -- Start first turn of new round
    self:startTurn()
    print("<<< TurnManager:endRound finished, started new round.")
end

-- Process enemy turn using AI
function TurnManager:processEnemyTurn(unit)
    -- ... (existing safety checks for unit, game, AI system, grid) ...
    if not unit or unit.faction ~= "enemy" then self:endTurn(); return end
    if not self.game or not self.game.enemyAI or not self.game.enemyAI.processTurn then print("Missing AI"); self:endTurn(); return end
    if not self.grid then print("Missing Grid"); self:endTurn(); return end

    -- Gather lists (as before)
    local activeEnemies = {}
    local activePlayers = {}
    if self.grid.entities then
        for entity, _ in pairs(self.grid.entities) do
            if entity.stats and entity.stats.health > 0 then
                if entity.faction == "enemy" then table.insert(activeEnemies, entity)
                elseif entity.faction == "player" then table.insert(activePlayers, entity) end
            end
        end
    else
        print("Cannot get units from grid.entities."); self:endTurn(); return
    end

    -- *** ADD DEBUG HERE ***
    print("--- TurnManager:processEnemyTurn ---")
    print("  Passing grid to AI:")
    print("  Type:", type(self.grid))
    print("  Value:", tostring(self.grid))
    if self.grid then
         print("  Grid Width:", tostring(self.grid.width))
         print("  Grid Height:", tostring(self.grid.height))
         print("  Grid TileSize:", tostring(self.grid.tileSize))
    else
         print("  ERROR: self.grid is nil in TurnManager!")
    end
    print("---------------------------------")
    -- *** END DEBUG ***


    -- AI logic may need adjustment if it relied on global AP.
    -- Assuming AI decides actions based on unit capabilities (including its own AP if AI is complex enough)
    print(string.format("TurnManager:processEnemyTurn - Processing AI for %s (AP: %d/%d). Passing %d enemies, %d players.",
        unit.id or "N/A", unit.stats.actionPoints, unit.stats.maxActionPoints, #activeEnemies, #activePlayers))

    -- Call AI - IMPORTANT: The AI's processTurn should now ideally consume the unit's AP
    -- If the AI is simple (e.g., move then attack), we might need to manually deduct AP here or in AI.
    -- Let's assume for now the AI *should* handle it. If not, we'd add calls to self:useActionPoints here based on AI actions.
    local actions = self.game.enemyAI:processTurn(activeEnemies, activePlayers, self.grid) -- Pass current unit too

    -- Placeholder for executing AI actions (if processTurn returns them)
    if actions and #actions > 0 then
        print("AI returned " .. #actions .. " actions. (Execution logic not shown)")
        -- Example: Iterate actions, execute move/attack/ability, potentially deduct AP via self:useActionPoints(cost) for each action *if AI doesn't handle it internally*
        -- timer.script(function(wait)
        --    for _, action in ipairs(actions) do
        --       -- execute action (e.g., unit:moveTo, self.game.combatSystem:processAttack)
        --       -- Deduct AP if needed: self:useActionPoints(action.cost or 1)
        --       wait(0.3) -- Small delay between actions
        --    end
        --    self:endTurn() -- End turn after all actions
        -- end)
        -- For now, just end turn after a delay
        timer.after(0.5, function() self:endTurn() end)
    else
        -- If AI doesn't return actions or has simple logic, end turn after delay
        print("AI processing complete (or no actions returned). Ending turn.")
        timer.after(0.5, function() self:endTurn() end)
    end
end

-- Simple fallback AI
function TurnManager:simpleEnemyAI(unit)
    -- Safety check
    if not unit or not self.game or not self.grid then return end
    
    -- Find closest player unit
    local closestUnit = nil
    local closestDistance = math.huge
    
    -- Safety check for grid
    if not self.grid.entities then return end
    
    for entity, _ in pairs(self.grid.entities) do
        if entity.faction == "player" then
            local dx = entity.x - unit.x
            local dy = entity.y - unit.y
            local distance = math.sqrt(dx * dx + dy * dy)
            
            if distance < closestDistance then
                closestUnit = entity
                closestDistance = distance
            end
        end
    end
    
    -- If found a player unit, move toward it
    if closestUnit then
        -- Simple pathfinding: move in direction of player
        local dx = closestUnit.x - unit.x
        local dy = closestUnit.y - unit.y
        
        local moveX = 0
        local moveY = 0
        
        if math.abs(dx) > math.abs(dy) then
            moveX = dx > 0 and 1 or -1
        else
            moveY = dy > 0 and 1 or -1
        end
        
        -- Check if move is valid
        local newX = unit.x + moveX
        local newY = unit.y + moveY
        
        -- Safety check for grid
        if self.grid.isValidPosition and self.grid:isValidPosition(newX, newY) then
            -- Move unit
            self.grid:moveEntity(unit, newX, newY)
        end
    end
end

-- Check if it's currently the player's turn
function TurnManager:isPlayerTurn()
    -- No changes needed here, still relies on self.currentPhase
    -- print("TurnManager:isPlayerTurn - ENTERED") -- Keep for debug if needed
    -- print("  self.currentPhase:", self.currentPhase)
    return self.currentPhase == "player"
end

-- Use action points (Now operates on the CURRENT unit)
function TurnManager:useActionPoints(amount)
    amount = amount or 1

    -- Get the current unit
    if self.currentInitiativeIndex > #self.initiativeOrder then
        print("WARN: useActionPoints called with invalid initiative index.")
        return false -- Cannot determine current unit
    end
    local currentUnit = self.initiativeOrder[self.currentInitiativeIndex]
    if not currentUnit or not currentUnit.stats then
        print("WARN: useActionPoints called but current unit or stats are invalid.")
        return false -- Current unit is invalid
    end

    print(string.format("TurnManager:useActionPoints - Unit %s attempting to use %d AP (has %d/%d)",
          currentUnit.id or 'N/A', amount, currentUnit.stats.actionPoints, currentUnit.stats.maxActionPoints))

    if currentUnit.stats.actionPoints >= amount then
        currentUnit.stats.actionPoints = currentUnit.stats.actionPoints - amount

        -- Trigger action point changed callback with the unit's NEW values
        if self.onActionPointsChanged then
            self.onActionPointsChanged(currentUnit.stats.actionPoints, currentUnit.stats.maxActionPoints)
        end

        -- Auto-end turn if out of action points (Consider if this is desired behavior)
        -- Only for player turns?
        -- if currentUnit.stats.actionPoints <= 0 and self:isPlayerTurn() then
        --    print(string.format("Unit %s ran out of AP. Auto-ending turn.", currentUnit.id or 'N/A'))
        --    timer.after(0.2, function() self:endTurn() end) -- Short delay
        -- end

        print(string.format("  AP Used. Remaining: %d/%d", currentUnit.stats.actionPoints, currentUnit.stats.maxActionPoints))
        return true -- AP successfully used
    else
        print(string.format("  FAILED: Not enough AP. Needed %d.", amount))
        return false -- Not enough AP
    end
end

-- Add action points (Operates on CURRENT unit - less common use case)
function TurnManager:addActionPoints(amount)
    amount = amount or 1
    if self.currentInitiativeIndex > #self.initiativeOrder then return false end
    local currentUnit = self.initiativeOrder[self.currentInitiativeIndex]
    if not currentUnit or not currentUnit.stats then return false end

    currentUnit.stats.actionPoints = math.min(currentUnit.stats.actionPoints + amount, currentUnit.stats.maxActionPoints)

    -- Trigger action point events with updated values
    if self.onActionPointsChanged then
        self.onActionPointsChanged(currentUnit.stats.actionPoints, currentUnit.stats.maxActionPoints)
    end
    print(string.format("TurnManager:addActionPoints - Unit %s gained %d AP. New total: %d/%d",
        currentUnit.id or 'N/A', amount, currentUnit.stats.actionPoints, currentUnit.stats.maxActionPoints))
    return true
end

-- *** REMOVED: Set max action points (Unit-specific now) ***
-- function TurnManager:setMaxActionPoints(amount) ... end

-- Apply status effects
function TurnManager:applyStatusEffects(unit, trigger)
    -- Apply global status effects
    for _, effect in ipairs(self.statusEffects) do
        if effect.trigger == trigger then
            effect.apply(unit)
        end
    end
    
    -- Apply unit-specific status effects
    if unit and unit.statusEffects then
        for _, effect in ipairs(unit.statusEffects) do
            if effect.trigger == trigger then
                effect.apply(unit)
            end
        end
    end
end

-- Add status effect
function TurnManager:addStatusEffect(effect)
    table.insert(self.statusEffects, effect)
end

-- Remove status effect
function TurnManager:removeStatusEffect(effect)
    for i, e in ipairs(self.statusEffects) do
        if e == effect then
            table.remove(self.statusEffects, i)
            return true
        end
    end
    
    return false
end

-- Save turn to history
function TurnManager:saveTurnToHistory(unit)
    local turn = {
        number = self.turnNumber,
        round = self.roundNumber,
        phase = self.currentPhase,
        unit = unit and unit.id or nil,
        actionPoints = self.currentActionPoints
    }
    
    table.insert(self.turnHistory, turn)
    
    -- Limit history length
    if #self.turnHistory > self.maxHistoryLength then
        table.remove(self.turnHistory, 1)
    end
end

-- Trigger turn start events
function TurnManager:triggerTurnStart(unit)
    for _, event in ipairs(self.turnStartEvents) do
        event(unit)
    end
    
    if self.onTurnStart then
        self.onTurnStart(unit)
    end
end

-- Trigger turn end events
function TurnManager:triggerTurnEnd(unit)
    for _, event in ipairs(self.turnEndEvents) do
        event(unit)
    end
    
    if self.onTurnEnd then
        self.onTurnEnd(unit)
    end
end

-- Trigger round start events
function TurnManager:triggerRoundStart()
    for _, event in ipairs(self.roundStartEvents) do
        event(self.roundNumber)
    end
    
    if self.onRoundStart then
        self.onRoundStart(self.roundNumber)
    end
end

-- Trigger round end events
function TurnManager:triggerRoundEnd()
    for _, event in ipairs(self.roundEndEvents) do
        event(self.roundNumber)
    end
    
    if self.onRoundEnd then
        self.onRoundEnd(self.roundNumber)
    end
end

-- *** REMOVED: Trigger action points changed events (integrated into use/add/start) ***
-- function TurnManager:triggerActionPointsChanged() ... end

-- Add turn start event
function TurnManager:addTurnStartEvent(event)
    table.insert(self.turnStartEvents, event)
end

-- Add turn end event
function TurnManager:addTurnEndEvent(event)
    table.insert(self.turnEndEvents, event)
end

-- Add round start event
function TurnManager:addRoundStartEvent(event)
    table.insert(self.roundStartEvents, event)
end

-- Add round end event
function TurnManager:addRoundEndEvent(event)
    table.insert(self.roundEndEvents, event)
end

-- function TurnManager:addActionPointEvent(event) ... end -- Removed

-- Update turn timer
function TurnManager:update(dt)
    if self.turnTimerActive and self.turnTimer then
        self.turnTimer = self.turnTimer - dt
        
        -- Update UI
        if self.game and self.game.ui then
            self.game.ui:setTurnTimer(self.turnTimer)
        end
        
        -- End turn if timer expires
        if self.turnTimer <= 0 then
            self.turnTimerActive = false
            self:endTurn()
        end
    end
end

-- Set turn time limit
function TurnManager:setTurnTimeLimit(seconds)
    self.turnTimeLimit = seconds
end

-- Check if game is over
function TurnManager:checkGameOver()
    -- Ensure grid and entities exist
    if not self.game or not self.grid or not self.grid.entities then
        print("checkGameOver: Invalid game/grid state.")
        return false
    end

    local playerUnitsAlive = 0
    local enemyUnitsAlive = 0

    -- Iterate through the grid's entities
    for entity, _ in pairs(self.grid.entities) do
        -- Check if it's a unit with health
        if entity and entity.stats and entity.stats.health then
            if entity.stats.health > 0 then
                if entity.faction == "player" then
                    playerUnitsAlive = playerUnitsAlive + 1
                elseif entity.faction == "enemy" then
                    enemyUnitsAlive = enemyUnitsAlive + 1
                end
            end
        end
    end
    print(string.format("checkGameOver: Players Alive = %d, Enemies Alive = %d", playerUnitsAlive, enemyUnitsAlive))

    if playerUnitsAlive == 0 and enemyUnitsAlive > 0 then -- Enemies win only if they still exist
        if not self.gameOver then print("Game Over! Winner: Enemy") end
        self.gameOver = true
        self.winner = "enemy"
        return true
    elseif enemyUnitsAlive == 0 and playerUnitsAlive > 0 then -- Player wins only if they still exist
        if not self.gameOver then print("Game Over! Winner: Player") end
        self.gameOver = true
        self.winner = "player"
        return true
    elseif playerUnitsAlive == 0 and enemyUnitsAlive == 0 then -- Draw or mutual destruction
        if not self.gameOver then print("Game Over! Draw (Mutual Destruction)") end
        self.gameOver = true
        self.winner = "draw"
        return true
    end

    return false -- Game is not over
end

-- Set grid reference
function TurnManager:setGrid(grid)
    self.grid = grid
end

return TurnManager
