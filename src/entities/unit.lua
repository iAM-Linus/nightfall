-- Unit Entity for Nightfall Chess
-- Represents a playable character or enemy on the grid

local class = require("lib.middleclass.middleclass")

local Unit = class("Unit")

function Unit:initialize(params)
    -- Basic properties
    self.unitType = params.unitType or "pawn"
    self.faction = params.faction or "player"
    self.isPlayerControlled = params.isPlayerControlled or false
    
    -- Position
    self.x = params.x or 1
    self.y = params.y or 1
    self.grid = params.grid or nil
    
    -- Stats
    self.stats = {
        health = params.health or params.stats and params.stats.health or 10,
        maxHealth = params.maxHealth or params.stats and params.stats.maxHealth or 10,
        attack = params.attack or params.stats and params.stats.attack or 2,
        defense = params.defense or params.stats and params.stats.defense or 1,
        moveRange = params.moveRange or params.stats and params.stats.moveRange or 1,
        attackRange = params.attackRange or params.stats and params.stats.attackRange or 1,
        energy = params.energy or params.stats and params.stats.energy or 10,
        maxEnergy = params.maxEnergy or params.stats and params.stats.maxEnergy or 10,
        initiative = params.initiative or params.stats and params.stats.initiative or 5
    }
    
    -- Movement pattern
    self.movementPattern = params.movementPattern or "pawn"
    
    -- Action state
    self.hasMoved = false
    self.hasAttacked = false
    self.hasUsedAbility = false
    
    -- Animation state
    self.animState = "idle"
    self.animTimer = 0
    self.animFrame = 1
    
    -- Special abilities
    self.abilities = params.abilities or self:getDefaultAbilities()
    
    -- Ability cooldowns
    self.abilityCooldowns = {}
    for _, abilityId in ipairs(self.abilities) do
        self.abilityCooldowns[abilityId] = 0
    end
    
    -- Status effects
    self.statusEffects = {}
    
    -- Experience and level
    self.level = params.level or 1
    self.experience = params.experience or 0
    
    -- Equipment
    self.equipment = {
        weapon = nil,
        armor = nil,
        accessory = nil
    }
    
    -- Inventory
    self.inventory = params.inventory or {}
    
    -- Visual representation
    self.sprite = nil
    self.color = params.color or {1, 1, 1}
    
    -- AI behavior type (for enemy units)
    self.aiType = params.aiType or "balanced"
    
    -- Unique identifier
    self.id = params.id or self.unitType .. "_" .. tostring(math.random(1000, 9999))
end

-- Get default abilities based on unit type
function Unit:getDefaultAbilities()
    local defaultAbilities = {
        king = {"royal_guard", "tactical_command", "inspiring_presence"},
        queen = {"sovereign_wrath", "royal_decree", "strategic_repositioning"},
        rook = {"fortify", "shockwave", "stone_skin"},
        bishop = {"healing_light", "mystic_barrier", "arcane_bolt"},
        knight = {"knights_charge", "feint", "flanking_maneuver"},
        pawn = {"shield_bash", "advance", "promotion"}
    }
    
    return defaultAbilities[self.unitType] or {}
end

-- Update unit state
function Unit:update(dt)
    -- Update animation
    self.animTimer = self.animTimer + dt
    
    -- Update animation frame
    if self.animTimer > 0.2 then
        self.animTimer = 0
        self.animFrame = self.animFrame % 4 + 1
    end
    
    -- Update status effect durations
    self:updateStatusEffects(dt)
    
    -- Regenerate energy over time
    if self.stats.energy < self.stats.maxEnergy then
        self.energyRegenTimer = (self.energyRegenTimer or 0) + dt
        if self.energyRegenTimer >= 1 then
            self.energyRegenTimer = 0
            self.stats.energy = math.min(self.stats.energy + 1, self.stats.maxEnergy)
        end
    end
end

-- Draw the unit
function Unit:draw()
    if not self.grid then return end
    
    local screenX, screenY = self.grid:gridToScreen(self.x, self.y)
    local tileSize = self.grid.tileSize
    
    -- Draw unit based on type
    local color = self.faction == "player" and {0.2, 0.6, 0.9} or {0.9, 0.3, 0.3}
    
    -- Draw unit body
    love.graphics.setColor(color[1], color[2], color[3], 1)
    love.graphics.rectangle("fill", screenX + 4, screenY + 4, tileSize - 8, tileSize - 8)
    
    -- Draw unit border
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.rectangle("line", screenX + 4, screenY + 4, tileSize - 8, tileSize - 8)
    
    -- Draw unit type indicator
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(self.unitType:sub(1, 1):upper(), screenX, screenY + tileSize/2 - 10, tileSize, "center")
    
    -- Draw action state indicators
    if self.hasMoved then
        love.graphics.setColor(0.8, 0.8, 0.2, 0.5)
        love.graphics.rectangle("fill", screenX + tileSize - 8, screenY, 8, 8)
    end
    
    if self.hasAttacked then
        love.graphics.setColor(0.8, 0.2, 0.2, 0.5)
        love.graphics.rectangle("fill", screenX + tileSize - 8, screenY + 8, 8, 8)
    end
    
    if self.hasUsedAbility then
        love.graphics.setColor(0.2, 0.2, 0.8, 0.5)
        love.graphics.rectangle("fill", screenX + tileSize - 8, screenY + 16, 8, 8)
    end
end

-- Reset action state for a new turn
function Unit:resetActionState()
    self.hasMoved = false
    self.hasAttacked = false
    self.hasUsedAbility = false
    
    -- Reduce ability cooldowns
    for abilityId, cooldown in pairs(self.abilityCooldowns) do
        if cooldown > 0 then
            self.abilityCooldowns[abilityId] = cooldown - 1
        end
    end
    
    -- Regenerate some energy
    self.stats.energy = math.min(self.stats.energy + 2, self.stats.maxEnergy)
end

-- Take damage
function Unit:takeDamage(amount, source)
    -- Apply defense reduction
    local actualDamage = math.max(1, amount - self.stats.defense)
    
    -- Check for shielded status effect
    for _, effect in ipairs(self.statusEffects or {}) do
        if effect.name == "shielded" then
            actualDamage = math.floor(actualDamage * 0.5)
            break
        end
    end
    
    -- Apply damage
    self.stats.health = math.max(0, self.stats.health - actualDamage)
    
    -- Set animation state
    self.animState = "hit"
    self.animTimer = 0
    
    return actualDamage
end

-- Heal health
function Unit:heal(amount, source)
    local oldHealth = self.stats.health
    self.stats.health = math.min(self.stats.health + amount, self.stats.maxHealth)
    return self.stats.health - oldHealth
end

-- Use energy
function Unit:useEnergy(amount)
    if self.stats.energy >= amount then
        self.stats.energy = self.stats.energy - amount
        return true
    end
    return false
end

-- Add status effect
function Unit:addStatusEffect(effect)
    -- Check if effect already exists
    for i, existingEffect in ipairs(self.statusEffects or {}) do
        if existingEffect.name == effect.name then
            -- If not stackable, just reset duration
            if not effect.stackable then
                existingEffect.duration = effect.duration
                return
            end
        end
    end
    
    -- Initialize statusEffects if it doesn't exist
    self.statusEffects = self.statusEffects or {}
    
    -- Add new effect
    table.insert(self.statusEffects, effect)
    
    -- Call onApply callback if it exists
    if effect.onApply then
        effect.onApply(self)
    end
end

-- Remove status effect
function Unit:removeStatusEffect(effectName)
    if not self.statusEffects then return end
    
    for i, effect in ipairs(self.statusEffects) do
        if effect.name == effectName then
            -- Call onRemove callback if it exists
            if effect.onRemove then
                effect.onRemove(self)
            end
            
            table.remove(self.statusEffects, i)
            return true
        end
    end
    
    return false
end

-- Update status effects
function Unit:updateStatusEffects(dt)
    if not self.statusEffects then return end
    
    local i = 1
    while i <= #self.statusEffects do
        local effect = self.statusEffects[i]
        
        -- Reduce duration if it's time-based
        if effect.duration then
            effect.durationTimer = (effect.durationTimer or 0) + dt
            
            -- Check if effect should be removed
            if effect.durationTimer >= 1 then
                effect.durationTimer = effect.durationTimer - 1
                effect.duration = effect.duration - 1
                
                if effect.duration <= 0 then
                    -- Call onRemove callback if it exists
                    if effect.onRemove then
                        effect.onRemove(self)
                    end
                    
                    table.remove(self.statusEffects, i)
                    goto continue
                end
            end
        end
        
        i = i + 1
        ::continue::
    end
end

-- Check if unit has a specific status effect
function Unit:hasStatusEffect(effectName)
    if not self.statusEffects then return false end
    
    for _, effect in ipairs(self.statusEffects) do
        if effect.name == effectName then
            return true
        end
    end
    
    return false
end

-- Add experience
function Unit:addExperience(amount)
    self.experience = self.experience + amount
    
    -- Check for level up
    local leveledUp = false
    local expForNextLevel = self:getExpRequiredForNextLevel()
    
    while self.experience >= expForNextLevel do
        self:levelUp()
        leveledUp = true
        expForNextLevel = self:getExpRequiredForNextLevel()
    end
    
    return leveledUp
end

-- Get experience required for next level
function Unit:getExpRequiredForNextLevel()
    -- Simple formula: 100 * level^1.5
    return math.floor(100 * (self.level ^ 1.5))
end

-- Level up
function Unit:levelUp()
    self.level = self.level + 1
    
    -- Increase stats based on unit type
    local statGrowth = {
        king = {health = 5, attack = 1, defense = 1, energy = 2},
        queen = {health = 5, attack = 3, defense = 1, energy = 2},
        rook = {health = 8, attack = 2, defense = 2, energy = 1},
        bishop = {health = 4, attack = 2, defense = 0, energy = 3},
        knight = {health = 6, attack = 2, defense = 1, energy = 2},
        pawn = {health = 5, attack = 1, defense = 1, energy = 1}
    }
    
    local growth = statGrowth[self.unitType] or {health = 5, attack = 1, defense = 1, energy = 1}
    
    -- Apply stat increases
    self.stats.maxHealth = self.stats.maxHealth + growth.health
    self.stats.health = self.stats.maxHealth -- Fully heal on level up
    self.stats.attack = self.stats.attack + growth.attack
    self.stats.defense = self.stats.defense + growth.defense
    self.stats.maxEnergy = self.stats.maxEnergy + growth.energy
    self.stats.energy = self.stats.maxEnergy -- Fully restore energy on level up
    
    -- Every 3 levels, increase move or attack range
    if self.level % 3 == 0 then
        if math.random() < 0.7 then
            self.stats.moveRange = self.stats.moveRange + 1
        else
            self.stats.attackRange = self.stats.attackRange + 1
        end
    end
    
    -- Unlock new abilities at specific levels
    if self.level == 3 or self.level == 7 then
        -- Would add new abilities here
    end
    
    return true
end

-- Equip an item
function Unit:equipItem(item, slot)
    if not slot then
        -- Determine slot based on item type
        if item.type == "weapon" then
            slot = "weapon"
        elseif item.type == "armor" then
            slot = "armor"
        elseif item.type == "accessory" then
            slot = "accessory"
        else
            return false, "Cannot equip this item type"
        end
    end
    
    -- Check if slot is valid
    if not self.equipment[slot] then
        return false, "Invalid equipment slot"
    end
    
    -- Unequip current item in that slot
    local currentItem = self.equipment[slot]
    if currentItem then
        self:unequipItem(currentItem)
    end
    
    -- Equip new item
    self.equipment[slot] = item
    item.equipped = true
    
    -- Apply item stats
    if item.stats then
        for stat, value in pairs(item.stats) do
            if self.stats[stat] then
                self.stats[stat] = self.stats[stat] + value
            end
        end
    end
    
    return true
end

-- Unequip an item
function Unit:unequipItem(item)
    -- Find the slot this item is equipped in
    local slot = nil
    for s, equippedItem in pairs(self.equipment) do
        if equippedItem == item then
            slot = s
            break
        end
    end
    
    if not slot then
        return false, "Item is not equipped"
    end
    
    -- Remove item from equipment
    self.equipment[slot] = nil
    item.equipped = false
    
    -- Remove item stats
    if item.stats then
        for stat, value in pairs(item.stats) do
            if self.stats[stat] then
                self.stats[stat] = self.stats[stat] - value
            end
        end
    end
    
    return true
end

-- Use an ability
function Unit:useAbility(abilityId, target, x, y)
    -- Check if unit has this ability
    local hasAbility = false
    for _, id in ipairs(self.abilities) do
        if id == abilityId then
            hasAbility = true
            break
        end
    end
    
    if not hasAbility then
        return false, "Unit does not have this ability"
    end
    
    -- Check if ability is on cooldown
    if (self.abilityCooldowns[abilityId] or 0) > 0 then
        return false, "Ability is on cooldown"
    end
    
    -- Check if unit has already used an ability this turn
    if self.hasUsedAbility then
        return false, "Unit has already used an ability this turn"
    end
    
    -- Get ability definition from the special abilities system
    local ability = nil
    if self.grid and self.grid.game and self.grid.game.specialAbilitiesSystem then
        ability = self.grid.game.specialAbilitiesSystem:getAbility(abilityId)
    end
    
    if not ability then
        return false, "Ability not found"
    end
    
    -- Check energy cost
    if ability.energyCost and self.stats.energy < ability.energyCost then
        return false, "Not enough energy"
    end
    
    -- Use the ability
    local success = false
    if ability.onUse then
        success = ability.onUse(self, target, x, y)
    end
    
    if success then
        -- Use energy
        if ability.energyCost then
            self.stats.energy = self.stats.energy - ability.energyCost
        end
        
        -- Set cooldown
        if ability.cooldown then
            self.abilityCooldowns[abilityId] = ability.cooldown
        end
        
        -- Mark as having used an ability
        self.hasUsedAbility = true
    end
    
    return success
end

-- Get ability cooldown
function Unit:getAbilityCooldown(abilityId)
    return self.abilityCooldowns[abilityId] or 0
end

-- Check if unit can use an ability
function Unit:canUseAbility(abilityId)
    -- Check if unit has this ability
    local hasAbility = false
    for _, id in ipairs(self.abilities) do
        if id == abilityId then
            hasAbility = true
            break
        end
    end
    
    if not hasAbility then
        return false
    end
    
    -- Check if ability is on cooldown
    if (self.abilityCooldowns[abilityId] or 0) > 0 then
        return false
    end
    
    -- Check if unit has already used an ability this turn
    if self.hasUsedAbility then
        return false
    end
    
    -- Get ability definition from the special abilities system
    local ability = nil
    if self.grid and self.grid.game and self.grid.game.specialAbilitiesSystem then
        ability = self.grid.game.specialAbilitiesSystem:getAbility(abilityId)
    end
    
    if not ability then
        return false
    end
    
    -- Check energy cost
    if ability.energyCost and self.stats.energy < ability.energyCost then
        return false
    end
    
    return true
end

-- Clone the unit
function Unit:clone()
    local clone = Unit:new({
        unitType = self.unitType,
        faction = self.faction,
        isPlayerControlled = self.isPlayerControlled,
        x = self.x,
        y = self.y,
        grid = self.grid,
        stats = {
            health = self.stats.health,
            maxHealth = self.stats.maxHealth,
            attack = self.stats.attack,
            defense = self.stats.defense,
            moveRange = self.stats.moveRange,
            attackRange = self.stats.attackRange,
            energy = self.stats.energy,
            maxEnergy = self.stats.maxEnergy,
            initiative = self.stats.initiative
        },
        movementPattern = self.movementPattern,
        abilities = self.abilities,
        level = self.level,
        experience = self.experience,
        aiType = self.aiType
    })
    
    return clone
end

return Unit
