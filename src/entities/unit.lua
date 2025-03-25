-- Unit System for Nightfall Chess
-- Extends Entity class to represent playable units and enemies

local class = require("lib.middleclass.middleclass")
local Entity = require("src.entities.entity")

local Unit = class("Unit", Entity)

function Unit:initialize(params)
    params = params or {}
    
    -- Call parent constructor
    Entity.initialize(self, params)
    
    -- Unit type and faction
    self.unitType = params.unitType or "pawn"
    self.faction = params.faction or "neutral" -- player, enemy, neutral
    self.isPlayerControlled = params.isPlayerControlled or (self.faction == "player")
    
    -- Stats
    self.stats = {
        health = params.health or 10,
        maxHealth = params.maxHealth or 10,
        energy = params.energy or 5,
        maxEnergy = params.maxEnergy or 5,
        attack = params.attack or 2,
        defense = params.defense or 1,
        moveRange = params.moveRange or 1,
        attackRange = params.attackRange or 1,
        visibilityRange = params.visibilityRange or 3
    }
    
    -- Movement pattern (based on chess piece)
    self.movementPattern = params.movementPattern or "orthogonal" -- orthogonal, diagonal, knight, queen, king
    
    -- Experience and level
    self.level = params.level or 1
    self.experience = params.experience or 0
    self.experienceToNextLevel = 10 * self.level
    
    -- Abilities
    self.abilities = params.abilities or {}
    
    -- Status effects
    self.statusEffects = {}
    
    -- Action state
    self.hasMoved = false
    self.hasAttacked = false
    self.hasUsedAbility = false
    
    -- AI behavior (for enemy units)
    self.behavior = params.behavior or "aggressive" -- aggressive, defensive, support
end

-- Update unit logic
function Unit:update(dt)
    -- Update status effects
    self:updateStatusEffects(dt)
    
    -- Base update logic
    Entity.update(self, dt)
end

-- Draw the unit
function Unit:draw(offsetX, offsetY)
    offsetX = offsetX or 0
    offsetY = offsetY or 0
    
    if not self.visible or not self.grid then
        return
    end
    
    -- Get screen position
    local screenX, screenY = self.grid:gridToScreen(self.x, self.y)
    screenX = screenX - offsetX
    screenY = screenY - offsetY
    
    -- Draw sprite if available
    if self.sprite then
        love.graphics.setColor(self.color)
        love.graphics.draw(
            self.sprite,
            screenX + self.grid.tileSize / 2,
            screenY + self.grid.tileSize / 2,
            self.rotation,
            self.scale,
            self.scale,
            self.sprite:getWidth() / 2,
            self.sprite:getHeight() / 2
        )
    else
        -- Draw placeholder
        local factionColor = {
            player = {0.2, 0.6, 1, 1},
            enemy = {1, 0.3, 0.3, 1},
            neutral = {0.7, 0.7, 0.7, 1}
        }
        
        love.graphics.setColor(factionColor[self.faction] or self.color)
        love.graphics.rectangle(
            "fill",
            screenX + 4,
            screenY + 4,
            self.grid.tileSize - 8,
            self.grid.tileSize - 8
        )
        
        -- Draw unit type indicator
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(
            self.unitType:sub(1, 1):upper(),
            screenX,
            screenY + self.grid.tileSize / 2 - 8,
            self.grid.tileSize,
            "center"
        )
    end
    
    -- Draw health bar
    local healthPercentage = self.stats.health / self.stats.maxHealth
    local barWidth = self.grid.tileSize - 10
    
    -- Background
    love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
    love.graphics.rectangle(
        "fill",
        screenX + 5,
        screenY + self.grid.tileSize - 10,
        barWidth,
        5
    )
    
    -- Health
    love.graphics.setColor(0.2, 0.8, 0.2, 1)
    love.graphics.rectangle(
        "fill",
        screenX + 5,
        screenY + self.grid.tileSize - 10,
        barWidth * healthPercentage,
        5
    )
    
    -- Draw status effect indicators
    if #self.statusEffects > 0 then
        love.graphics.setColor(1, 1, 0, 1)
        love.graphics.circle(
            "fill",
            screenX + self.grid.tileSize - 8,
            screenY + 8,
            4
        )
    end
    
    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

-- Get valid move positions based on movement pattern
function Unit:getValidMovePositions()
    if not self.grid then
        return {}
    end
    
    local validPositions = {}
    local moveRange = self.stats.moveRange
    
    -- Different movement patterns based on chess pieces
    if self.movementPattern == "orthogonal" then
        -- Rook-like movement (horizontal and vertical)
        self:addOrthogonalMoves(validPositions, moveRange)
    elseif self.movementPattern == "diagonal" then
        -- Bishop-like movement (diagonals)
        self:addDiagonalMoves(validPositions, moveRange)
    elseif self.movementPattern == "knight" then
        -- Knight movement (L-shape)
        self:addKnightMoves(validPositions)
    elseif self.movementPattern == "queen" then
        -- Queen movement (orthogonal and diagonal)
        self:addOrthogonalMoves(validPositions, moveRange)
        self:addDiagonalMoves(validPositions, moveRange)
    elseif self.movementPattern == "king" then
        -- King movement (one square in any direction)
        self:addOrthogonalMoves(validPositions, 1)
        self:addDiagonalMoves(validPositions, 1)
    end
    
    return validPositions
end

-- Add orthogonal moves (horizontal and vertical)
function Unit:addOrthogonalMoves(positions, range)
    local directions = {
        {dx = 0, dy = -1}, -- North
        {dx = 1, dy = 0},  -- East
        {dx = 0, dy = 1},  -- South
        {dx = -1, dy = 0}  -- West
    }
    
    for _, dir in ipairs(directions) do
        for dist = 1, range do
            local newX, newY = self.x + dir.dx * dist, self.y + dir.dy * dist
            
            -- Check if position is valid
            if not self.grid:isInBounds(newX, newY) then
                break
            end
            
            local tile = self.grid:getTile(newX, newY)
            
            -- Check if tile is walkable
            if not tile.walkable then
                break
            end
            
            -- Check if tile has an entity
            if tile.entity then
                -- Can't move to tiles with entities
                break
            end
            
            -- Add valid position
            table.insert(positions, {x = newX, y = newY})
        end
    end
end

-- Add diagonal moves
function Unit:addDiagonalMoves(positions, range)
    local directions = {
        {dx = 1, dy = -1},  -- Northeast
        {dx = 1, dy = 1},   -- Southeast
        {dx = -1, dy = 1},  -- Southwest
        {dx = -1, dy = -1}  -- Northwest
    }
    
    for _, dir in ipairs(directions) do
        for dist = 1, range do
            local newX, newY = self.x + dir.dx * dist, self.y + dir.dy * dist
            
            -- Check if position is valid
            if not self.grid:isInBounds(newX, newY) then
                break
            end
            
            local tile = self.grid:getTile(newX, newY)
            
            -- Check if tile is walkable
            if not tile.walkable then
                break
            end
            
            -- Check if tile has an entity
            if tile.entity then
                -- Can't move to tiles with entities
                break
            end
            
            -- Add valid position
            table.insert(positions, {x = newX, y = newY})
        end
    end
end

-- Add knight moves (L-shape)
function Unit:addKnightMoves(positions)
    local knightMoves = {
        {dx = 1, dy = -2},
        {dx = 2, dy = -1},
        {dx = 2, dy = 1},
        {dx = 1, dy = 2},
        {dx = -1, dy = 2},
        {dx = -2, dy = 1},
        {dx = -2, dy = -1},
        {dx = -1, dy = -2}
    }
    
    for _, move in ipairs(knightMoves) do
        local newX, newY = self.x + move.dx, self.y + move.dy
        
        -- Check if position is valid
        if self.grid:isInBounds(newX, newY) then
            local tile = self.grid:getTile(newX, newY)
            
            -- Check if tile is walkable and doesn't have an entity
            if tile.walkable and not tile.entity then
                table.insert(positions, {x = newX, y = newY})
            end
        end
    end
end

-- Get valid attack targets
function Unit:getValidAttackTargets()
    if not self.grid then
        return {}
    end
    
    local validTargets = {}
    local attackRange = self.stats.attackRange
    
    -- Different attack patterns based on movement patterns
    if self.movementPattern == "orthogonal" then
        -- Rook-like attacks
        self:addOrthogonalAttacks(validTargets, attackRange)
    elseif self.movementPattern == "diagonal" then
        -- Bishop-like attacks
        self:addDiagonalAttacks(validTargets, attackRange)
    elseif self.movementPattern == "knight" then
        -- Knight attacks
        self:addKnightAttacks(validTargets)
    elseif self.movementPattern == "queen" then
        -- Queen attacks
        self:addOrthogonalAttacks(validTargets, attackRange)
        self:addDiagonalAttacks(validTargets, attackRange)
    elseif self.movementPattern == "king" then
        -- King attacks
        self:addOrthogonalAttacks(validTargets, 1)
        self:addDiagonalAttacks(validTargets, 1)
    end
    
    return validTargets
end

-- Add orthogonal attack targets
function Unit:addOrthogonalAttacks(targets, range)
    local directions = {
        {dx = 0, dy = -1}, -- North
        {dx = 1, dy = 0},  -- East
        {dx = 0, dy = 1},  -- South
        {dx = -1, dy = 0}  -- West
    }
    
    for _, dir in ipairs(directions) do
        for dist = 1, range do
            local newX, newY = self.x + dir.dx * dist, self.y + dir.dy * dist
            
            -- Check if position is valid
            if not self.grid:isInBounds(newX, newY) then
                break
            end
            
            local tile = self.grid:getTile(newX, newY)
            
            -- Check if tile has an entity
            if tile.entity then
                -- Can attack enemy units
                if tile.entity.faction ~= self.faction then
                    table.insert(targets, {x = newX, y = newY, entity = tile.entity})
                end
                -- Can't attack through entities
                break
            end
            
            -- Can't attack through walls
            if not tile.walkable then
                break
            end
        end
    end
end

-- Add diagonal attack targets
function Unit:addDiagonalAttacks(targets, range)
    local directions = {
        {dx = 1, dy = -1},  -- Northeast
        {dx = 1, dy = 1},   -- Southeast
        {dx = -1, dy = 1},  -- Southwest
        {dx = -1, dy = -1}  -- Northwest
    }
    
    for _, dir in ipairs(directions) do
        for dist = 1, range do
            local newX, newY = self.x + dir.dx * dist, self.y + dir.dy * dist
            
            -- Check if position is valid
            if not self.grid:isInBounds(newX, newY) then
                break
            end
            
            local tile = self.grid:getTile(newX, newY)
            
            -- Check if tile has an entity
            if tile.entity then
                -- Can attack enemy units
                if tile.entity.faction ~= self.faction then
                    table.insert(targets, {x = newX, y = newY, entity = tile.entity})
                end
                -- Can't attack through entities
                break
            end
            
            -- Can't attack through walls
            if not tile.walkable then
                break
            end
        end
    end
end

-- Add knight attack targets
function Unit:addKnightAttacks(targets)
    local knightMoves = {
        {dx = 1, dy = -2},
        {dx = 2, dy = -1},
        {dx = 2, dy = 1},
        {dx = 1, dy = 2},
        {dx = -1, dy = 2},
        {dx = -2, dy = 1},
        {dx = -2, dy = -1},
        {dx = -1, dy = -2}
    }
    
    for _, move in ipairs(knightMoves) do
        local newX, newY = self.x + move.dx, self.y + move.dy
        
        -- Check if position is valid
        if self.grid:isInBounds(newX, newY) then
            local tile = self.grid:getTile(newX, newY)
            
            -- Check if tile has an enemy entity
            if tile.entity and tile.entity.faction ~= self.faction then
                table.insert(targets, {x = newX, y = newY, entity = tile.entity})
            end
        end
    end
end

-- Attack another unit
function Unit:attack(target)
    if not target or not target.stats then
        return false
    end
    
    -- Calculate damage
    local damage = self.stats.attack
    
    -- Apply defense reduction
    damage = math.max(1, damage - target.stats.defense)
    
    -- Apply damage
    target:takeDamage(damage, self)
    
    -- Mark as attacked
    self.hasAttacked = true
    
    return true
end

-- Take damage
function Unit:takeDamage(amount, source)
    -- Reduce health
    self.stats.health = math.max(0, self.stats.health - amount)
    
    -- Check if defeated
    if self.stats.health <= 0 then
        self:onDefeat(source)
    end
    
    return amount
end

-- Heal function that performs healing without overhealing
-- Parameters:
--   amount: The amount of health to restore
-- Returns:
--   The unit's new health value after healing (capped at max health)
function Unit:heal(amount)
    -- Assuming these variables exist in your game context
    local currentHealth = self.stats.health -- Current health of the unit
    local maxHealth = self.stats.maxHealth -- Maximum possible health of the unit
    
    -- Ensure amount is a number and positive
    amount = tonumber(amount) or 0
    if amount < 0 then amount = 0 end
    
    -- Calculate new health but cap it at max health to prevent overhealing
    local newHealth = currentHealth + amount
    if newHealth > maxHealth then
        newHealth = maxHealth
    end
    
    -- Update the unit's health
    self.stats.health = newHealth
    
    -- Return the new health value
    return newHealth
end

-- Use energy
function Unit:useEnergy(amount)
    if self.stats.energy < amount then
        return false
    end
    
    self.stats.energy = self.stats.energy - amount
    return true
end

-- Restore energy function that restores energy 
-- Parameters:
--   amount: The amount of energy to restore
-- Returns:
--   The unit's new energy value after restoring (capped at max energy)
function Unit:restoreEnergy(amount)
    -- Assuming these variables exist in your game context
    local currentEnergy = self.stats.energy -- Current health of the unit
    local maxEnergy = self.stats.maxEnergy -- Maximum possible health of the unit
    
    -- Ensure amount is a number and positive
    amount = tonumber(amount) or 0
    if amount < 0 then amount = 0 end
    
    -- Calculate new health but cap it at max health to prevent overhealing
    local newEnergy = currentEnergy + amount
    if newEnergy > maxEnergy then
        newEnergy = maxEnergy
    end
    
    -- Update the unit's health
    self.stats.energy = newEnergy
    
    -- Return the new health value
    return newEnergy
end

-- Called when unit is defeated
function Unit:onDefeat(source)
    -- Remove from grid
    if self.grid then
        self.grid:removeEntity(self)
    end
    
    -- Grant experience to source if it's a unit
    if source and source.addExperience then
        local expGained = 5 * self.level
        source:addExperience(expGained)
    end
end

-- Add experience and handle level up
function Unit:addExperience(amount)
    self.experience = self.experience + amount
    
    -- Check for level up
    while self.experience >= self.experienceToNextLevel do
        self:levelUp()
    end
    
    return amount
end

-- Level up the unit
function Unit:levelUp()
    self.level = self.level + 1
    self.experience = self.experience - self.experienceToNextLevel
    self.experienceToNextLevel = 10 * self.level
    
    -- Increase stats
    self.stats.maxHealth = self.stats.maxHealth + 2
    self.stats.health = self.stats.maxHealth
    self.stats.maxEnergy = self.stats.maxEnergy + 1
    self.stats.energy = self.stats.maxEnergy
    self.stats.attack = self.stats.attack + 1
    
    -- Every other level, increase defense
    if self.level % 2 == 0 then
        self.stats.defense = self.stats.defense + 1
    end
    
    -- Every third level, increase move or attack range
    if self.level % 3 == 0 then
        if math.random() < 0.5 then
            self.stats.moveRange = self.stats.moveRange + 1
        else
            self.stats.attackRange = self.stats.attackRange + 1
        end
    end
    
    return self.level
end

-- Add a status effect
function Unit:addStatusEffect(effect)
    table.insert(self.statusEffects, effect)
end

-- Remove a status effect
function Unit:removeStatusEffect(effectType)
    for i = #self.statusEffects, 1, -1 do
        if self.statusEffects[i].type == effectType then
            table.remove(self.statusEffects, i)
            return true
        end
    end
end

function Unit:updateStatusEffects(dt)
    -- If no status effects, nothing to do
    if not self.statusEffects then
        return
    end
    
    -- Create a list of effects to remove
    local effectsToRemove = {}
    
    -- Update each status effect
    for name, effect in pairs(self.statusEffects) do
        -- Decrease duration if applicable
        if effect.duration then
            effect.duration = effect.duration - dt
            
            -- Mark for removal if duration is expired
            if effect.duration <= 0 then
                table.insert(effectsToRemove, name)
            end
        end
        
        -- Call effect's update function if it has one
        if effect.onUpdate then
            effect.onUpdate(self, dt)
        end
    end
    
    -- Remove expired effects
    for _, name in ipairs(effectsToRemove) do
        -- Call the effect's removal function if it exists
        if self.statusEffects[name] and self.statusEffects[name].onRemove then
            self.statusEffects[name].onRemove(self)
        end
        
        -- Remove the effect
        self.statusEffects[name] = nil
    end
    
    -- Update visual indicators for active effects
    --self:updateStatusVisuals(dt)
end
return Unit