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
    if self.game.ui then
        self.game.ui:setPlayerTurn(self:isPlayerTurn())
        self.game.ui:setActionPoints(self.currentActionPoints, self.maxActionPoints)
    end
end

-- Calculate initiative order for all units
function TurnManager:calculateInitiativeOrder()
    self.initiativeOrder = {}
    
    -- Get all units from the grid
    local units = {}
    for entity, _ in pairs(self.game.grid.entities) do
        if entity.faction then
            table.insert(units, entity)
        end
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
        if self.game.ui then
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
    if self.game.ui then
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
    
    -- Start first turn of new round
    self:startTurn()
    
    -- Update UI
    if self.game.ui then
        self.game.ui:showNotification("Round " .. self.roundNumber .. " begins!", 2)
    end
end

-- Process an enemy unit's turn (AI)
function TurnManager:processEnemyTurn(unit)
    -- Enhanced AI for enemy units
    
    -- Wait a bit for visual clarity
    timer.after(0.5, function()
        -- Check if unit has status effects that prevent actions
        if self:hasPreventingStatusEffect(unit) then
            -- Skip turn if unit is stunned, frozen, etc.
            if self.game.ui then
                self.game.ui:showNotification(unit.unitType:upper() .. " is unable to act!", 1.5)
            end
            
            timer.after(0.5, function()
                self:endTurn()
            end)
            return
        end
        
        -- Try to attack a player unit if possible
        local attacked = false
        local targets = unit:getValidAttackTargets()
        
        if #targets > 0 then
            -- Sort targets by priority (low health, high threat, etc.)
            table.sort(targets, function(a, b)
                -- Prioritize low health targets
                if a.entity.stats and b.entity.stats then
                    local aHealthPercent = a.entity.stats.health / a.entity.stats.maxHealth
                    local bHealthPercent = b.entity.stats.health / b.entity.stats.maxHealth
                    
                    if math.abs(aHealthPercent - bHealthPercent) > 0.2 then
                        return aHealthPercent < bHealthPercent
                    end
                end
                
                -- Then prioritize high-value targets
                local typePriority = {
                    king = 1,
                    queen = 2,
                    rook = 3,
                    bishop = 4,
                    knight = 5,
                    pawn = 6
                }
                
                local aPriority = typePriority[a.entity.unitType] or 99
                local bPriority = typePriority[b.entity.unitType] or 99
                
                return aPriority < bPriority
            end)
            
            -- Attack the highest priority target
            local target = targets[1].entity
            
            -- Show attack notification
            if self.game.ui then
                self.game.ui:showNotification(unit.unitType:upper() .. " attacks " .. target.unitType:upper() .. "!", 1.5)
                self.game.ui:setTargetUnit(target)
            end
            
            -- Perform attack
            unit:attack(target)
            attacked = true
            
            -- Check for game over condition
            if target.unitType == "king" and target.stats.health <= 0 then
                self:setGameOver("enemy")
            end
        end
        
        -- If didn't attack, try to move
        if not attacked then
            local movePositions = unit:getValidMovePositions()
            
            if #movePositions > 0 then
                -- Find strategic position to move to
                local bestPos = self:findBestEnemyMovePosition(unit, movePositions)
                
                -- Show move notification
                if self.game.ui then
                    self.game.ui:showNotification(unit.unitType:upper() .. " is moving", 1)
                end
                
                -- Move to best position
                if bestPos then
                    unit:moveTo(bestPos.x, bestPos.y)
                else
                    -- Move to random position as fallback
                    local randomPos = movePositions[math.random(#movePositions)]
                    unit:moveTo(randomPos.x, randomPos.y)
                end
            end
        end
        
        -- End turn after AI processing
        timer.after(0.8, function()
            -- Clear target unit from UI
            if self.game.ui then
                self.game.ui:setTargetUnit(nil)
            end
            
            self:endTurn()
        end)
    end)
end

-- Find the best position for an enemy unit to move to
function TurnManager:findBestEnemyMovePosition(unit, movePositions)
    -- Different strategies based on unit type
    if unit.unitType == "king" then
        -- King prioritizes safety
        return self:findSafestPosition(unit, movePositions)
    elseif unit.unitType == "queen" or unit.unitType == "rook" or unit.unitType == "bishop" then
        -- Ranged units prioritize attack positions
        return self:findBestAttackPosition(unit, movePositions)
    elseif unit.unitType == "knight" then
        -- Knights prioritize flanking positions
        return self:findFlankingPosition(unit, movePositions)
    else
        -- Pawns prioritize forward movement
        return self:findForwardPosition(unit, movePositions)
    end
end

-- Find the safest position (furthest from enemy threats)
function TurnManager:findSafestPosition(unit, movePositions)
    local bestPos = nil
    local bestSafetyScore = -math.huge
    
    for _, pos in ipairs(movePositions) do
        local safetyScore = 0
        
        -- Check distance from all player units
        for entity, _ in pairs(self.game.grid.entities) do
            if entity.faction == "player" then
                local distance = math.abs(pos.x - entity.x) + math.abs(pos.y - entity.y)
                safetyScore = safetyScore + distance
            end
        end
        
        if safetyScore > bestSafetyScore then
            bestSafetyScore = safetyScore
            bestPos = pos
        end
    end
    
    return bestPos
end

-- Find the best position for attacking
function TurnManager:findBestAttackPosition(unit, movePositions)
    local bestPos = nil
    local bestAttackScore = -math.huge
    
    for _, pos in ipairs(movePositions) do
        local attackScore = 0
        
        -- Temporarily move unit to this position to check attack options
        local originalX, originalY = unit.x, unit.y
        unit.x, unit.y = pos.x, pos.y
        
        -- Check how many player units can be attacked from this position
        local attackTargets = unit:getValidAttackTargets()
        attackScore = #attackTargets
        
        -- Add bonus for high-value targets
        for _, target in ipairs(attackTargets) do
            if target.entity.unitType == "king" then
                attackScore = attackScore + 10
            elseif target.entity.unitType == "queen" then
                attackScore = attackScore + 5
            elseif target.entity.unitType == "rook" or target.entity.unitType == "bishop" then
                attackScore = attackScore + 3
            end
        end
        
        -- Move unit back
        unit.x, unit.y = originalX, originalY
        
        if attackScore > bestAttackScore then
            bestAttackScore = attackScore
            bestPos = pos
        end
    end
    
    -- If no good attack position, find closest position to player units
    if bestAttackScore <= 0 then
        bestPos = nil
        local bestDistance = math.huge
        
        for _, pos in ipairs(movePositions) do
            for entity, _ in pairs(self.game.grid.entities) do
                if entity.faction == "player" then
                    local distance = math.abs(pos.x - entity.x) + math.abs(pos.y - entity.y)
                    
                    if distance < bestDistance then
                        bestDistance = distance
                        bestPos = pos
                    end
                end
            end
        end
    end
    
    return bestPos
end

-- Find a good flanking position
function TurnManager:findFlankingPosition(unit, movePositions)
    local bestPos = nil
    local bestFlankScore = -math.huge
    
    for _, pos in ipairs(movePositions) do
        local flankScore = 0
        
        -- Check if this position flanks any player units
        for entity, _ in pairs(self.game.grid.entities) do
            if entity.faction == "player" then
                -- Check if there are other enemy units on the opposite side
                local dx = entity.x - pos.x
                local dy = entity.y - pos.y
                local oppositeX = entity.x + dx
                local oppositeY = entity.y + dy
                
                -- Check if there's an enemy at the opposite position
                for otherEntity, _ in pairs(self.game.grid.entities) do
                    if otherEntity.faction == "enemy" and 
                       otherEntity ~= unit and
                       math.abs(otherEntity.x - oppositeX) <= 1 and
                       math.abs(otherEntity.y - oppositeY) <= 1 then
                        flankScore = flankScore + 5
                    end
                end
                
                -- Bonus for being close to player units
                local distance = math.abs(pos.x - entity.x) + math.abs(pos.y - entity.y)
                if distance <= 2 then
                    flankScore = flankScore + (3 - distance)
                end
            end
        end
        
        if flankScore > bestFlankScore then
            bestFlankScore = flankScore
            bestPos = pos
        end
    end
    
    -- If no good flanking position, use attack position
    if bestFlankScore <= 0 then
        return self:findBestAttackPosition(unit, movePositions)
    end
    
    return bestPos
end

-- Find a position that advances toward player units
function TurnManager:findForwardPosition(unit, movePositions)
    local bestPos = nil
    local bestScore = -math.huge
    
    -- Find the closest player unit
    local closestPlayerUnit = nil
    local closestDistance = math.huge
    
    for entity, _ in pairs(self.game.grid.entities) do
        if entity.faction == "player" then
            local distance = math.abs(unit.x - entity.x) + math.abs(unit.y - entity.y)
            
            if distance < closestDistance then
                closestDistance = distance
                closestPlayerUnit = entity
            end
        end
    end
    
    if not closestPlayerUnit then
        -- No player units found, move randomly
        return movePositions[math.random(#movePositions)]
    end
    
    -- Score positions based on how much closer they get to the target
    for _, pos in ipairs(movePositions) do
        local newDistance = math.abs(pos.x - closestPlayerUnit.x) + math.abs(pos.y - closestPlayerUnit.y)
        local distanceImprovement = closestDistance - newDistance
        
        local score = distanceImprovement
        
        -- Bonus for moving toward king
        if closestPlayerUnit.unitType == "king" then
            score = score + 3
        end
        
        if score > bestScore then
            bestScore = score
            bestPos = pos
        end
    end
    
    return bestPos
end

-- Check if a unit has status effects that prevent actions
function TurnManager:hasPreventingStatusEffect(unit)
    if not unit.statusEffects then
        return false
    end
    
    for _, effect in pairs(unit.statusEffects) do
        if effect.preventAction then
            return true
        end
    end
    
    return false
end

-- Apply status effects based on trigger type
function TurnManager:applyStatusEffects(unit, triggerType)
    -- Apply unit-specific status effects
    if unit and unit.statusEffects then
        for id, effect in pairs(unit.statusEffects) do
            if effect.triggerOn == triggerType then
                -- Apply effect
                if effect.onTrigger then
                    effect.onTrigger(unit)
                end
                
                -- Reduce duration
                if effect.duration then
                    effect.duration = effect.duration - 1
                    
                    -- Remove if duration is over
                    if effect.duration <= 0 then
                        if effect.onRemove then
                            effect.onRemove(unit)
                        end
                        unit.statusEffects[id] = nil
                    end
                end
            end
        end
    end
    
    -- Apply global status effects
    for id, effect in pairs(self.statusEffects) do
        if effect.triggerOn == triggerType then
            -- Apply effect
            if effect.onTrigger then
                effect.onTrigger(unit)
            end
            
            -- Reduce duration
            if effect.duration then
                effect.duration = effect.duration - 1
                
                -- Remove if duration is over
                if effect.duration <= 0 then
                    if effect.onRemove then
                        effect.onRemove()
                    end
                    self.statusEffects[id] = nil
                end
            end
        end
    end
end

-- Register a status effect
function TurnManager:registerStatusEffect(id, effect)
    self.statusEffects[id] = effect
end

-- Register a unit status effect
function TurnManager:registerUnitStatusEffect(unit, id, effect)
    if not unit.statusEffects then
        unit.statusEffects = {}
    end
    
    unit.statusEffects[id] = effect
end

-- Register a turn event
function TurnManager:registerTurnEvent(eventType, callback)
    if eventType == "turnStart" then
        table.insert(self.turnStartEvents, callback)
    elseif eventType == "turnEnd" then
        table.insert(self.turnEndEvents, callback)
    elseif eventType == "roundStart" then
        table.insert(self.roundStartEvents, callback)
    elseif eventType == "roundEnd" then
        table.insert(self.roundEndEvents, callback)
    elseif eventType == "actionPointChange" then
        table.insert(self.actionPointEvents, callback)
    end
end

-- Trigger turn start events
function TurnManager:triggerTurnStart(unit)
    -- Call registered events
    for _, callback in ipairs(self.turnStartEvents) do
        callback(unit, self.turnNumber, self.roundNumber)
    end
    
    -- Call main callback
    if self.onTurnStart then
        self.onTurnStart(unit, self.turnNumber, self.roundNumber)
    end
    
    -- Call phase change callback
    if self.onPhaseChange then
        self.onPhaseChange(self.currentPhase)
    end
end

-- Trigger turn end events
function TurnManager:triggerTurnEnd(unit)
    -- Call registered events
    for _, callback in ipairs(self.turnEndEvents) do
        callback(unit, self.turnNumber, self.roundNumber)
    end
    
    -- Call main callback
    if self.onTurnEnd then
        self.onTurnEnd(unit, self.turnNumber, self.roundNumber)
    end
end

-- Trigger round start events
function TurnManager:triggerRoundStart()
    -- Call registered events
    for _, callback in ipairs(self.roundStartEvents) do
        callback(self.roundNumber)
    end
    
    -- Call main callback
    if self.onRoundStart then
        self.onRoundStart(self.roundNumber)
    end
end

-- Trigger round end events
function TurnManager:triggerRoundEnd()
    -- Call registered events
    for _, callback in ipairs(self.roundEndEvents) do
        callback(self.roundNumber)
    end
    
    -- Call main callback
    if self.onRoundEnd then
        self.onRoundEnd(self.roundNumber)
    end
end

-- Trigger action point change events
function TurnManager:triggerActionPointChange(oldValue, newValue)
    -- Call registered events
    for _, callback in ipairs(self.actionPointEvents) do
        callback(oldValue, newValue)
    end
    
    -- Call main callback
    if self.onActionPointsChanged then
        self.onActionPointsChanged(oldValue, newValue)
    end
    
    -- Update UI
    if self.game.ui then
        self.game.ui:setActionPoints(newValue, self.maxActionPoints)
    end
end

-- Get current active unit
function TurnManager:getCurrentUnit()
    return self.initiativeOrder[self.currentInitiativeIndex]
end

-- Check if it's a specific faction's turn
function TurnManager:isPhase(phase)
    return self.currentPhase == phase
end

-- Check if it's the player's turn
function TurnManager:isPlayerTurn()
    return self.currentPhase == "player"
end

-- Check if it's the enemy's turn
function TurnManager:isEnemyTurn()
    return self.currentPhase == "enemy"
end

-- Skip the current unit's turn
function TurnManager:skipTurn()
    -- Get current unit
    local currentUnit = self.initiativeOrder[self.currentInitiativeIndex]
    
    if not currentUnit then
        return
    end
    
    -- Mark unit as having acted
    if currentUnit.hasMoved ~= nil then
        currentUnit.hasMoved = true
    end
    
    if currentUnit.hasAttacked ~= nil then
        currentUnit.hasAttacked = true
    end
    
    if currentUnit.hasUsedAbility ~= nil then
        currentUnit.hasUsedAbility = true
    end
    
    -- Show notification
    if self.game.ui then
        self.game.ui:showNotification(currentUnit.unitType:upper() .. " skipped turn", 1)
    end
    
    -- End the turn
    self:endTurn()
end

-- Use action points
function TurnManager:useActionPoints(amount)
    if not self:isPlayerTurn() then
        return false
    end
    
    amount = amount or 1
    
    if self.currentActionPoints < amount then
        return false
    end
    
    local oldValue = self.currentActionPoints
    self.currentActionPoints = self.currentActionPoints - amount
    
    -- Trigger action point change events
    self:triggerActionPointChange(oldValue, self.currentActionPoints)
    
    -- End turn if out of action points
    if self.currentActionPoints <= 0 then
        timer.after(0.5, function()
            self:endTurn()
        end)
    end
    
    return true
end

-- Add action points
function TurnManager:addActionPoints(amount)
    if not self:isPlayerTurn() then
        return false
    end
    
    amount = amount or 1
    
    local oldValue = self.currentActionPoints
    self.currentActionPoints = math.min(self.currentActionPoints + amount, self.maxActionPoints)
    
    -- Trigger action point change events
    self:triggerActionPointChange(oldValue, self.currentActionPoints)
    
    return true
end

-- Set max action points
function TurnManager:setMaxActionPoints(amount)
    self.maxActionPoints = amount
    self.currentActionPoints = math.min(self.currentActionPoints, self.maxActionPoints)
    
    -- Update UI
    if self.game.ui then
        self.game.ui:setActionPoints(self.currentActionPoints, self.maxActionPoints)
    end
end

-- Save turn to history
function TurnManager:saveTurnToHistory(unit)
    -- Create turn record
    local turnRecord = {
        turnNumber = self.turnNumber,
        roundNumber = self.roundNumber,
        phase = self.currentPhase,
        unitType = unit.unitType,
        unitFaction = unit.faction,
        actionPoints = self.currentActionPoints,
        -- Could add more state here for undo functionality
    }
    
    -- Add to history
    table.insert(self.turnHistory, turnRecord)
    
    -- Trim history if too long
    if #self.turnHistory > self.maxHistoryLength then
        table.remove(self.turnHistory, 1)
    end
end

-- Update turn timer
function TurnManager:update(dt)
    -- Update turn timer if active
    if self.turnTimerActive and self.turnTimer then
        self.turnTimer = self.turnTimer - dt
        
        -- End turn if timer expires
        if self.turnTimer <= 0 then
            self.turnTimerActive = false
            
            -- Show notification
            if self.game.ui then
                self.game.ui:showNotification("Time's up!", 1)
            end
            
            -- End turn
            self:endTurn()
        end
        
        -- Update UI timer if close to expiring
        if self.turnTimer <= 5 and self.game.ui and math.floor(self.turnTimer) ~= math.floor(self.turnTimer + dt) then
            self.game.ui:showNotification(math.ceil(self.turnTimer) .. " seconds left!", 0.5)
        end
    end
end

-- Set turn time limit
function TurnManager:setTurnTimeLimit(seconds)
    self.turnTimeLimit = seconds
end

-- Set game over state
function TurnManager:setGameOver(winner)
    self.gameOver = true
    self.winner = winner
    
    -- Notify game state
    if self.game.setGameOver then
        self.game:setGameOver(winner)
    end
end

-- Check if game is over
function TurnManager:isGameOver()
    return self.gameOver
end

-- Get winner
function TurnManager:getWinner()
    return self.winner
end

return TurnManager
