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
    
    -- Action points system
    self.maxActionPoints = 3
    self.currentActionPoints = self.maxActionPoints
    
    -- Turn events
    self.turnStartEvents = {}
    self.turnEndEvents = {}
    self.roundStartEvents = {}
    self.roundEndEvents = {}
    self.actionPointEvents = {}
    
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
    self.turnNumber = 1
    self.roundNumber = 1
    self.currentPhase = "player"
    self.gameOver = false
    self.winner = nil
    
    -- Reset action points
    self.currentActionPoints = self.maxActionPoints
    
    -- Clear turn history
    self.turnHistory = {}
    
    -- Calculate initial initiative order
    self:calculateInitiativeOrder()
    
    -- Trigger round start
    self:triggerRoundStart()
    
    -- Start first turn
    self:startTurn()
    
    -- Notify UI
    if self.game and self.game.ui then
        self.game.ui:setPlayerTurn(self:isPlayerTurn())
        self.game.ui:setActionPoints(self.currentActionPoints, self.maxActionPoints)
    end
end

-- Calculate initiative order for all units
function TurnManager:calculateInitiativeOrder()
    self.initiativeOrder = {}
    
    -- Safety check: ensure grid exists
    if not self.game or not self.grid or not self.grid.entities then
        print("Warning: Grid not initialized for initiative calculation")
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
        print("Warning: No units found for initiative calculation")
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
end

-- Start a new turn
function TurnManager:startTurn()
    -- Get current unit
    local currentUnit = self.initiativeOrder[self.currentInitiativeIndex]
    
    if not currentUnit then
        -- End of initiative order, start new round
        self:endRound()
        return
    end
    
    -- Set current phase based on unit faction
    self.currentPhase = currentUnit.faction
    
    -- Reset unit action state
    if currentUnit.resetActionState then
        currentUnit:resetActionState()
    end
    
    -- Reset action points if it's a player turn
    if currentUnit.faction == "player" then
        self.currentActionPoints = self.maxActionPoints
        
        -- Notify UI of action points change
        if self.game and self.game.ui then
            self.game.ui:setActionPoints(self.currentActionPoints, self.maxActionPoints)
        end
    end
    
    -- Apply status effects that trigger at turn start
    self:applyStatusEffects(currentUnit, "turnStart")
    
    -- Trigger turn start events
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
    
    -- Update UI
    if self.game and self.game.ui then
        self.game.ui:setPlayerTurn(self:isPlayerTurn())
        
        -- Update selected unit in HUD
        if self:isPlayerTurn() then
            self.game.ui:setSelectedUnit(currentUnit)
        end
        
        -- Show turn notification
        local turnText = currentUnit.faction:sub(1,1):upper() .. currentUnit.faction:sub(2) .. " Turn: " .. currentUnit.unitType:upper()
        self.game.ui:showNotification(turnText, 2)
    end
    
    -- If it's a player unit, the player will control it through input
    -- The turn will end when the player calls endTurn() or runs out of action points
end

-- End the current turn
function TurnManager:endTurn()
    -- Get current unit
    local currentUnit = self.initiativeOrder[self.currentInitiativeIndex]
    
    if not currentUnit then
        return
    end
    
    -- Apply status effects that trigger at turn end
    self:applyStatusEffects(currentUnit, "turnEnd")
    
    -- Trigger turn end events
    self:triggerTurnEnd(currentUnit)
    
    -- Save turn to history
    self:saveTurnToHistory(currentUnit)
    
    -- Move to next unit in initiative order
    self.currentInitiativeIndex = self.currentInitiativeIndex + 1
    self.turnNumber = self.turnNumber + 1
    
    -- Reset turn timer
    self.turnTimerActive = false
    
    -- Start next turn
    self:startTurn()
end

-- End the current round
function TurnManager:endRound()
    -- Trigger round end events
    self:triggerRoundEnd()
    
    -- Apply status effects that trigger at round end
    self:applyStatusEffects(nil, "roundEnd")
    
    -- Increment round number
    self.roundNumber = self.roundNumber + 1
    
    -- Recalculate initiative order
    self:calculateInitiativeOrder()
    
    -- Apply status effects that trigger at round start
    self:applyStatusEffects(nil, "roundStart")
    
    -- Trigger round start events
    self:triggerRoundStart()
    
    -- Reset initiative index
    self.currentInitiativeIndex = 1
    
    -- Start first turn of new round
    self:startTurn()
end

-- Process enemy turn using AI
function TurnManager:processEnemyTurn(unit)
    -- Safety check
    if not unit or unit.faction ~= "enemy" then return end
    
    -- Use AI to determine action
    if self.game and self.game.enemyAI then
        self.game.enemyAI:processTurn(unit)
    else
        -- Simple fallback AI if no AI system is available
        self:simpleEnemyAI(unit)
    end
    
    -- End turn after AI processing
    timer.after(0.5, function() self:endTurn() end)
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
    return self.currentPhase == "player"
end

-- Use action points
function TurnManager:useActionPoints(amount)
    amount = amount or 1
    
    if self.currentActionPoints >= amount then
        self.currentActionPoints = self.currentActionPoints - amount
        
        -- Trigger action point events
        self:triggerActionPointsChanged()
        
        -- Update UI
        if self.game and self.game.ui then
            self.game.ui:setActionPoints(self.currentActionPoints, self.maxActionPoints)
        end
        
        -- Auto-end turn if out of action points
        if self.currentActionPoints <= 0 and self:isPlayerTurn() then
            timer.after(0.5, function() self:endTurn() end)
        end
        
        return true
    end
    
    return false
end

-- Add action points
function TurnManager:addActionPoints(amount)
    amount = amount or 1
    
    self.currentActionPoints = math.min(self.currentActionPoints + amount, self.maxActionPoints)
    
    -- Trigger action point events
    self:triggerActionPointsChanged()
    
    -- Update UI
    if self.game and self.game.ui then
        self.game.ui:setActionPoints(self.currentActionPoints, self.maxActionPoints)
    end
    
    return true
end

-- Set max action points
function TurnManager:setMaxActionPoints(amount)
    self.maxActionPoints = amount
    self.currentActionPoints = math.min(self.currentActionPoints, self.maxActionPoints)
    
    -- Trigger action point events
    self:triggerActionPointsChanged()
    
    -- Update UI
    if self.game and self.game.ui then
        self.game.ui:setActionPoints(self.currentActionPoints, self.maxActionPoints)
    end
end

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

-- Trigger action points changed events
function TurnManager:triggerActionPointsChanged()
    for _, event in ipairs(self.actionPointEvents) do
        event(self.currentActionPoints, self.maxActionPoints)
    end
    
    if self.onActionPointsChanged then
        self.onActionPointsChanged(self.currentActionPoints, self.maxActionPoints)
    end
end

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

-- Add action point event
function TurnManager:addActionPointEvent(event)
    table.insert(self.actionPointEvents, event)
end

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
    -- Safety check
    if not self.game or not self.grid or not self.grid.entities then
        return false
    end
    
    -- Count units by faction
    local playerUnits = 0
    local enemyUnits = 0
    
    for entity, _ in pairs(self.grid.entities) do
        if entity.faction == "player" then
            playerUnits = playerUnits + 1
        elseif entity.faction == "enemy" then
            enemyUnits = enemyUnits + 1
        end
    end
    
    -- Check win conditions
    if playerUnits == 0 then
        self.gameOver = true
        self.winner = "enemy"
        return true
    elseif enemyUnits == 0 then
        self.gameOver = true
        self.winner = "player"
        return true
    end
    
    return false
end

-- Set grid reference
function TurnManager:setGrid(grid)
    self.grid = grid
end

return TurnManager
