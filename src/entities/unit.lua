-- Unit Entity for Nightfall Chess
-- Represents a playable character or enemy on the grid
-- Includes base stats, abilities, status effects, leveling, and animation properties

local class = require("lib.middleclass.middleclass")
-- Ensure timer is available, either globally via main or required here if needed standalone
local timer = require("lib.hump.timer") -- Assuming HUMP timer is used

-- Forward declare or require Item if strict type checking is desired
local Item = require("src.entities.item") -- Ensure Item is loaded before Unit if needed

local Unit = class("Unit")

function Unit:initialize(params)
    -- Basic properties
    self.unitType = params.unitType or "pawn"
    self.faction = params.faction or "player"
    self.isPlayerControlled = params.isPlayerControlled or (self.faction == "player")

    -- Position (Logical grid position)
    self.x = params.x or 1
    self.y = params.y or 1

    -- References (Assigned later when placed on grid/added to game)
    self.grid = params.grid -- Should be set externally
    self.game = params.game -- Should be set externally

    -- Stats (Initialize with defaults first)
    self.stats = {
        health = 10,
        maxHealth = 10,
        attack = 2,
        defense = 1,
        moveRange = 2,
        attackRange = 1,
        energy = 10,    -- Renamed from mana for consistency
        maxEnergy = 10, -- Renamed from maxMana
        initiative = 5,
        actionPoints = 2,
        maxActionPoints = 2
    }
    -- Override defaults with params.stats if provided
    if params.stats then
        for k, v in pairs(params.stats) do
            -- Handle potential renaming (e.g., mana -> energy)
            local key = k
            if k == "mana" then key = "energy"
            elseif k == "maxMana" then key = "maxEnergy" end

            if self.stats[key] ~= nil then
                self.stats[key] = v
            else
                if key == "actionPoints" or key == "maxActionPoints" then
                    self.stats[key] = v
                end
            end
        end
        -- Ensure current values don't exceed max after overrides
        self.stats.health = math.min(self.stats.health, self.stats.maxHealth)
        self.stats.energy = math.min(self.stats.energy, self.stats.maxEnergy)
        self.stats.actionPoints = math.min(self.stats.actionPoints, self.stats.maxActionPoints)
    end

    -- Movement pattern (derived or from params)
    self.movementPattern = params.movementPattern or self:getDefaultMovementPattern()

    -- Action state
    self.hasMoved = false
    self.hasAttacked = false
    self.hasUsedAbility = false

    -- --- Animation Properties ---
    self.visualX = self.x             -- Current visual grid X (can differ during animation)
    self.visualY = self.y             -- Current visual grid Y
    self.scale = {x = 1, y = 1}       -- Scale factor {x, y}
    self.rotation = 0                 -- Rotation in radians
    self.offset = {x = 0, y = 0}       -- Pixel offset from grid position {x, y}
    self.color = params.color or {1, 1, 1, 1} -- Color modulation {r, g, b, a}
    self.animationState = "idle"      -- Current animation state (idle, moving, attacking, hit, casting)
    self.animationTimer = 0           -- Timer for current animation state/frame
    self.animationDirection = 1       -- Facing direction (1 for right, -1 for left)

    -- Flash effect properties
    self.flashTimer = 0               -- Remaining duration of flash effect
    self.flashDuration = 0            -- Total duration of the flash
    self.flashColor = {1, 1, 1, 0}    -- Color and alpha of the flash overlay

    -- Shadow properties (Optional, but kept from original)
    self.shadowScale = 1              -- Scale of the shadow ellipse
    self.shadowAlpha = 0.5            -- Opacity of the shadow
    -- --- End Animation Properties ---

    -- Abilities
    self.abilities = params.abilities or self:getDefaultAbilities()
    self.abilityCooldowns = params.abilityCooldowns or {}
    for _, abilityId in ipairs(self.abilities) do
        if self.abilityCooldowns[abilityId] == nil then
             self.abilityCooldowns[abilityId] = 0
        end
    end

    -- Status effects (Initialized as empty table)
    self.statusEffects = {}

    -- Experience and level
    self.level = params.level or 1
    self.experience = params.experience or 0
    self.skillPoints = params.skillPoints or 0

    -- Equipment (Initialized with nil slots)
    self.equipment = {
        weapon = nil,
        armor = nil,
        accessory = nil
    }
    self.originalStats = {} -- For tracking stat changes from equipment/effects
    if params.equipment then
        for slot, itemData in pairs(params.equipment) do
            if itemData and (slot == "weapon" or slot == "armor" or slot == "accessory") then
               local item = (type(itemData) == "table" and itemData.isInstanceOf and itemData:isInstanceOf(Item)) and itemData or Item:new(itemData)
               self:equipItem(item, slot) -- Use the equip method
            end
        end
    end

    -- AI behavior type
    self.aiType = params.aiType or "balanced"

    -- Unique identifier
    self.id = params.id or self.unitType .. "_" .. tostring(math.random(1000, 9999))

    -- Initialize with ExperienceSystem if available
    if self.game and self.game.experienceSystem and self.game.experienceSystem.initializeUnit then
         self.game.experienceSystem:initializeUnit(self)
    end
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

-- Get default movement pattern based on unit type
function Unit:getDefaultMovementPattern()
    local patterns = {
        king = "king", queen = "queen", rook = "orthogonal",
        bishop = "diagonal", knight = "knight", pawn = "pawn"
    }
    return patterns[self.unitType] or "orthogonal"
end

-- Update unit state (Simplified animation update)
function Unit:update(dt)
    -- Update status effect durations/triggers
    self:updateStatusEffects(dt) -- Call this first

    -- Check if stunned or otherwise prevented from acting
    if self:isActionPrevented() then return end

    -- Update flash effect
    if self.flashTimer > 0 then
        self.flashTimer = self.flashTimer - dt
        self.flashColor[4] = math.max(0, self.flashTimer / self.flashDuration)
    end

    -- Update animation state timer (handle nil case)
    self.animationTimer = (self.animationTimer or 0) + dt
    if self.animationState == "idle" then
        -- Subtle idle animation - slight bobbing
        local idleBobAmount = 0.03 * (self.grid and self.grid.tileSize or 64)
        local idleBobSpeed = 2
        self.offset.y = -math.sin(self.animationTimer * idleBobSpeed) * idleBobAmount
    elseif self.animationState == "hit" then
         -- Reset state after hit animation duration (e.g., 0.2s)
         if self.animationTimer > 0.2 then self.animationState = "idle" end
    elseif self.animationState == "casting" then
         -- Reset state after casting animation duration (e.g., 0.4s)
         if self.animationTimer > 0.4 then self.animationState = "idle" end
    -- Note: 'moving' state is managed by the animation manager callback
    end

    -- Regenerate energy over time (Simplified)
    if self.stats.energy < self.stats.maxEnergy then
        self.energyRegenTimer = (self.energyRegenTimer or 0) + dt
        if self.energyRegenTimer >= 1 then
            self.energyRegenTimer = 0
            self:gainEnergy(1) -- Use a method for clarity
        end
    end
end

-- Check if action is prevented by status effects
function Unit:isActionPrevented()
    if self.statusEffects then
        for _, effect in pairs(self.statusEffects) do
             if effect.preventAction then return true end
        end
    end
    return false
end


-- Draw the unit using animation properties
function Unit:draw()
    -- Basic checks
    if not self.grid then print("Warning: Unit:draw ID="..(self.id or 'N/A').." called without grid"); return end
    if not self.game then print("Warning: Unit:draw ID="..(self.id or 'N/A').." called without game reference"); return end
    if not self.game.assetManager then print("Warning: Unit:draw ID="..(self.id or 'N/A').." called without assetManager"); return end
    if not self.game.assets or not self.game.assets.fonts then print("Warning: Unit:draw ID="..(self.id or 'N/A').." called without loaded fonts"); return end

    local tileSize = self.grid.tileSize

    -- Calculate screen position based on VISUAL position
    local screenX, screenY = self.grid:gridToScreen(self.visualX, self.visualY)

    -- Draw shadow
    love.graphics.setColor(0, 0, 0, self.shadowAlpha)
    love.graphics.ellipse("fill", screenX + tileSize/2, screenY + tileSize - 4, tileSize * 0.7 * self.shadowScale / 2, tileSize * 0.2 * self.shadowScale / 2)

    -- Apply transformations
    love.graphics.push()
    love.graphics.translate(screenX + tileSize/2 + (self.offset.x or 0), screenY + tileSize/2 + (self.offset.y or 0))
    love.graphics.rotate(self.rotation or 0)
    local scaleX = (self.scale and self.scale.x or 1) * (self.animationDirection or 1)
    local scaleY = self.scale and self.scale.y or 1
    love.graphics.scale(scaleX, scaleY)
    love.graphics.translate(-tileSize/2, -tileSize/2) -- Translate back to corner relative to center

    -- --- Get Sprite ---
    local imageName = (self.faction or "unknown") .. "_" .. (self.unitType or "unknown")
    local sprite = self.game.assetManager:getImage(imageName)
    -- print(string.format("Unit:draw [%s] - Image: '%s', Sprite Found: %s", self.id or 'N/A', imageName, tostring(sprite ~= nil))) -- Optional Debug

    -- --- Determine Draw Color ---
    -- Start with the unit's base color property {r,g,b,a}
    local drawR = self.color and self.color[1] or 1
    local drawG = self.color and self.color[2] or 1
    local drawB = self.color and self.color[3] or 1
    local drawA = self.color and self.color[4] or 1 -- CRUCIAL: Use the unit's alpha

    -- If drawing fallback, modulate with faction color
    if not sprite then
        local factionColor = (self.faction == "player") and {0.2, 0.6, 0.9} or {0.9, 0.3, 0.3}
        drawR = drawR * factionColor[1]
        drawG = drawG * factionColor[2]
        drawB = drawB * factionColor[3]
        -- Keep the unit's alpha (drawA)
    end

    -- --- Draw Unit ---
    if sprite and sprite:getWidth() > 0 and sprite:getHeight() > 0 then
        love.graphics.setColor(drawR, drawG, drawB, drawA) -- Apply final calculated color
        -- Calculate scale to fit tileSize exactly
        local spriteScaleX = tileSize / sprite:getWidth()
        local spriteScaleY = tileSize / sprite:getHeight()
        love.graphics.draw(sprite, 0, 0, 0, spriteScaleX, spriteScaleY)
        -- print(string.format("Unit:draw [%s] - Drawing SPRITE. Alpha=%.2f", self.id or 'N/A', drawA)) -- Optional Debug
    else
        -- Fallback drawing
        love.graphics.setColor(drawR, drawG, drawB, drawA) -- Apply final calculated color
        love.graphics.rectangle("fill", 2, 2, tileSize - 4, tileSize - 4) -- Smaller rect to see border
        love.graphics.setColor(1, 1, 1, 0.8 * drawA) -- Border using unit alpha
        love.graphics.rectangle("line", 2, 2, tileSize - 4, tileSize - 4)
        love.graphics.setColor(1, 1, 1, drawA) -- Text using unit alpha
        local font = self.game.assets.fonts.medium or love.graphics.getFont()
        love.graphics.setFont(font)
        love.graphics.printf((self.unitType or "?"):sub(1, 1):upper(), 0, tileSize/2 - font:getHeight()/2, tileSize, "center")
        -- print(string.format("Unit:draw [%s] - Drawing FALLBACK. Alpha=%.2f", self.id or 'N/A', drawA)) -- Optional Debug
    end

    -- Restore transformation
    love.graphics.pop()

    -- Draw health bar, indicators, flash (These seem okay based on screenshot)
    self:drawHealthBar(screenX, screenY, tileSize)
    self:drawActionIndicators(screenX, screenY, tileSize)
    if self.flashTimer > 0 and self.flashColor and self.flashColor[4] > 0 then
        love.graphics.setColor(self.flashColor[1], self.flashColor[2], self.flashColor[3], self.flashColor[4])
        local logicalScreenX, logicalScreenY = self.grid:gridToScreen(self.x, self.y)
        love.graphics.rectangle("fill", logicalScreenX, logicalScreenY, tileSize, tileSize)
    end

    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

-- Helper to draw health bar
function Unit:drawHealthBar(screenX, screenY, tileSize)
    local barWidth = tileSize * 0.8
    local barHeight = 4
    local barX = screenX + (tileSize - barWidth) / 2
    local barY = screenY + tileSize - barHeight - 2
    local healthPercent = self.stats.health / self.stats.maxHealth

    -- Background
    love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
    love.graphics.rectangle("fill", barX, barY, barWidth, barHeight)
    -- Health fill (Green to Red gradient)
    local r = math.min(1, (1 - healthPercent) * 2)
    local g = math.min(1, healthPercent * 2)
    love.graphics.setColor(r, g, 0, 0.8)
    love.graphics.rectangle("fill", barX, barY, barWidth * healthPercent, barHeight)
    -- Border
    love.graphics.setColor(0.8, 0.8, 0.8, 0.5)
    love.graphics.rectangle("line", barX, barY, barWidth, barHeight)
end

-- Helper to draw action indicators
function Unit:drawActionIndicators(screenX, screenY, tileSize)
    local indicatorX = screenX + tileSize - 10
    local indicatorY = screenY + 2
    local indicatorSize = 8
    local indicatorSpacing = 2

    if self.hasMoved then
        love.graphics.setColor(0.8, 0.8, 0.2, 0.7) -- Yellow for move
        love.graphics.rectangle("fill", indicatorX, indicatorY, indicatorSize, indicatorSize)
        indicatorY = indicatorY + indicatorSize + indicatorSpacing
    end
    if self.hasAttacked then
        love.graphics.setColor(0.8, 0.2, 0.2, 0.7) -- Red for attack
        love.graphics.rectangle("fill", indicatorX, indicatorY, indicatorSize, indicatorSize)
        indicatorY = indicatorY + indicatorSize + indicatorSpacing
    end
    if self.hasUsedAbility then
        love.graphics.setColor(0.2, 0.2, 0.8, 0.7) -- Blue for ability
        love.graphics.rectangle("fill", indicatorX, indicatorY, indicatorSize, indicatorSize)
    end
end


-- Reset action state for a new turn
function Unit:resetActionState()
    self.hasMoved = false
    self.hasAttacked = false
    self.hasUsedAbility = false

    -- Replenish Action Points
    if self.stats then -- Safety check
        self.stats.actionPoints = self.stats.maxActionPoints or 0
        -- print(string.format("Unit %s AP reset to %d/%d", self.id or 'N/A', self.stats.actionPoints, self.stats.maxActionPoints)) -- Debug
    end

    -- Reduce ability cooldowns
    self.abilityCooldowns = self.abilityCooldowns or {}
    for abilityId, cooldown in pairs(self.abilityCooldowns) do
        if cooldown > 0 then
            self.abilityCooldowns[abilityId] = cooldown - 1
        end
    end

    -- Regenerate some energy (Example: +2 per turn)
    self:gainEnergy(2)
end

-- Take damage (handles defense, effects)
function Unit:takeDamage(amount, source)
    local defense = self.stats.defense or 0
    local actualDamage = math.max(1, amount - defense) -- Ensure at least 1 damage

    -- Check for shielded status effect
    if self:hasStatusEffect("shielded") then
        actualDamage = math.floor(actualDamage * 0.5) -- Reduce damage if shielded
    end

    self.stats.health = math.max(0, self.stats.health - actualDamage)

    -- Trigger hit animation/effect
    self:showHitEffect()

    -- Check for death
    if self.stats.health <= 0 then
        print(self.id .. " was defeated!")
        -- Trigger death event/handling here
        if self.game and self.game.combatSystem and self.game.combatSystem.handleUnitDefeat then
            self.game.combatSystem:handleUnitDefeat(source, self) -- Pass attacker and defeated unit
        end
    end

    return actualDamage
end

-- Heal health
function Unit:heal(amount, source)
    local oldHealth = self.stats.health
    self.stats.health = math.min(self.stats.health + amount, self.stats.maxHealth)
    local healedAmount = self.stats.health - oldHealth

    -- Trigger heal animation/effect if healed
    if healedAmount > 0 then
        self:showHealEffect()
    end

    return healedAmount
end

-- Use energy
function Unit:useEnergy(amount)
    if self.stats.energy >= amount then
        self.stats.energy = self.stats.energy - amount
        return true
    end
    return false
end

-- Gain energy
function Unit:gainEnergy(amount)
    self.stats.energy = math.min(self.stats.energy + amount, self.stats.maxEnergy)
end

-- *** NEW: Helper function to gain AP (optional, TurnManager handles deduction mainly) ***
-- We might not need this if TurnManager handles addition centrally
function Unit:gainActionPoints(amount)
    self.stats.actionPoints = math.min(self.stats.actionPoints + amount, self.stats.maxActionPoints)
end


-- *** NEW: Helper function to use AP (optional, TurnManager handles deduction mainly) ***
-- We might not need this if TurnManager handles deduction centrally
    function Unit:useActionPoints(amount)
    amount = amount or 1
    if self.stats and self.stats.actionPoints >= amount then
        self.stats.actionPoints = self.stats.actionPoints - amount
        return true
    end
    return false
end


-- Add status effect (more robust, handles duration timer)
function Unit:addStatusEffect(effect)
    self.statusEffects = self.statusEffects or {}
    local effectName = effect.name

    if not effectName then return end -- Need a name to track

    -- Check stacking/refreshing
    if self.statusEffects[effectName] and not effect.stackable then
        -- Refresh duration
        self.statusEffects[effectName].duration = effect.duration
        self.statusEffects[effectName].durationTimer = effect.duration -- Reset timer
        print("Refreshed status effect: " .. effectName)
    else
        -- Add new effect (clone it)
        local newEffect = {}
        for k, v in pairs(effect) do newEffect[k] = v end
        newEffect.durationTimer = newEffect.duration -- Initialize timer

        self.statusEffects[effectName] = newEffect

        -- Call onApply callback if it exists
        if newEffect.onApply then
            newEffect.onApply(self)
        end
        print("Applied status effect: " .. newEffect.name)
    end
end

-- Remove status effect by name
function Unit:removeStatusEffect(effectName)
    if not self.statusEffects or not self.statusEffects[effectName] then return false end

    local effect = self.statusEffects[effectName]
    -- Call onRemove callback if it exists
    if effect.onRemove then
        effect.onRemove(self)
    end
    self.statusEffects[effectName] = nil
    print("Removed status effect: " .. effectName)
    return true
end

-- Update status effects (Called from Unit:update)
function Unit:updateStatusEffects(dt)
    if not self.statusEffects then return end

    for effectName, effect in pairs(self.statusEffects) do
        local removeEffect = false

        -- Reduce duration if it's time-based
        if effect.durationTimer then
             effect.durationTimer = effect.durationTimer - dt
             if effect.durationTimer <= 0 then
                 removeEffect = true
             end
        end

        -- Handle removal OR trigger onTick
        if removeEffect then
            -- onRemove is called by removeStatusEffect
            self:removeStatusEffect(effectName)
            -- Note: Need to break or handle loop carefully if modifying table during iteration
            -- Using pairs might be safe here, but iterating backwards with indices is safer if removing.
        else
            -- Call onTick if it exists and effect is still active
            if effect.onTick then
                effect.onTick(self, dt)
            end
        end
    end
end

-- Check if unit has a specific status effect
function Unit:hasStatusEffect(effectName)
    return self.statusEffects and self.statusEffects[effectName] ~= nil
end

-- Add experience (Delegates to ExperienceSystem)
function Unit:addExperience(amount)
    if self.game and self.game.experienceSystem then
        return self.game.experienceSystem:awardExperience(self, amount)
    else
        print("Warning: ExperienceSystem not available to award experience.")
        return false
    end
end

-- Get experience required for next level (delegates or uses fallback)
function Unit:getExpRequiredForNextLevel()
    if self.game and self.game.experienceSystem then
        return self.game.experienceSystem:getExpRequiredForLevel(self.level + 1)
    else
        return math.floor(100 * (self.level ^ 1.5)) -- Fallback formula
    end
end

-- Level up (Delegates to ExperienceSystem)
function Unit:levelUp()
     if self.game and self.game.experienceSystem then
        return self.game.experienceSystem:levelUp(self)
     else
         print("Warning: ExperienceSystem not available for level up.")
         return false
     end
end

-- Equip an item (using Item class methods)
function Unit:equipItem(item, slot)
    if not item or not item.equip then return false, "Invalid item" end
    if not slot then slot = item.slot end

    -- Ensure the slot exists in the unit's equipment table
    if not self.equipment[slot] then self.equipment[slot] = nil end

    -- Attempt to equip using the Item's method
    local equipped, message = item:equip(self) -- Item:equip handles unequip/stats
    if equipped then
        print(self.unitType .. " equipped " .. item.name .. " in " .. slot .. " slot.")
    else
         print("Failed to equip " .. item.name .. ": " .. (message or "Unknown reason"))
    end
    return equipped, message
end

-- Unequip item by slot (using Item class methods)
function Unit:unequipItemBySlot(slot)
    if not self.equipment or not self.equipment[slot] then return false, "Nothing in slot" end

    local item = self.equipment[slot]
    if not item or not item.unequip then return false, "Invalid item in slot" end

    -- Attempt to unequip using the Item's method
    local unequipped, message = item:unequip(self)
    if unequipped then
        print(self.unitType .. " unequipped " .. item.name .. " from " .. slot .. " slot.")
        return true, item -- Return true and the item
    else
        print("Failed to unequip " .. item.name .. ": " .. (message or "Unknown reason"))
        return false, message
    end
end

-- Unequip a specific item instance
function Unit:unequipItem(itemToUnequip)
    if not itemToUnequip then return false, "No item provided" end
    local foundSlot = nil
    for slot, item in pairs(self.equipment or {}) do
        if item == itemToUnequip then
            foundSlot = slot
            break
        end
    end
    if foundSlot then
        return self:unequipItemBySlot(foundSlot)
    else
        return false, "Item not equipped"
    end
end

-- Use an ability (delegates to system)
function Unit:useAbility(abilityId, target, x, y)
    if not self.game or not self.game.specialAbilitiesSystem then
        print("Warning: Cannot use ability - SpecialAbilitiesSystem not available")
        return false, "System not available"
    end

    -- Check if the unit *can* use the ability first (cooldown, energy, action state)
    local canUse, reason = self:canUseAbility(abilityId)
    if not canUse then
         print("Unit cannot use ability " .. abilityId .. ": " .. (reason or "Unknown reason"))
         return false, reason
    end

    -- Attempt to use the ability via the system
    local success, message = self.game.specialAbilitiesSystem:useAbility(self, abilityId, target, x, y)

    if success then
        -- System should handle energy cost and cooldown setting
        -- Mark action state here
        self.hasUsedAbility = true
        print("Successfully used ability: " .. abilityId)
    else
        print("Failed to use ability '" .. abilityId .. "': " .. (message or "System reported failure"))
    end

    return success, message
end

-- Check if unit can use an ability (More robust)
function Unit:canUseAbility(abilityId)
    if not abilityId then return false, "No ability ID" end

    -- Check action state
    if self.hasUsedAbility then return false, "Already used ability this turn" end

    -- Check game state / system availability
    if not self.game or not self.game.specialAbilitiesSystem then
        return false, "Ability system unavailable"
    end

    local ability = self.game.specialAbilitiesSystem:getAbility(abilityId)
    if not ability then return false, "Ability definition not found" end

    -- Check cooldown
    if (self:getAbilityCooldown(abilityId) or 0) > 0 then
        return false, "On cooldown (" .. self:getAbilityCooldown(abilityId) .. " turns left)"
    end

    -- Check energy cost
    local energyCost = ability.energyCost or 0
    if self.stats.energy < energyCost then
        return false, "Not enough energy (" .. self.stats.energy .. "/" .. energyCost .. ")"
    end

    -- *** NEW: Check unit's own action points ***
    local requiredAP = ability.actionPointCost or 1 -- Assume 1 AP if not specified
    if not self.stats or self.stats.actionPoints < requiredAP then
        return false, "Not enough action points (" .. (self.stats and self.stats.actionPoints or 'N/A') .. "/" .. requiredAP .. ")"
    end

    --[[ -- Old check using TurnManager's global AP
    if self.game.turnManager and self.game.turnManager.currentActionPoints < requiredAP then
       return false, "Not enough action points"
    end
    ]]

    -- TODO: Add range/target checks if needed for specific UI feedback

    return true -- If all checks pass
end

-- Get ability cooldown
function Unit:getAbilityCooldown(abilityId)
    self.abilityCooldowns = self.abilityCooldowns or {}
    return self.abilityCooldowns[abilityId] or 0
end

-- Set ability cooldown
function Unit:setAbilityCooldown(abilityId, cooldown)
    if not abilityId then return end
    self.abilityCooldowns = self.abilityCooldowns or {}
    self.abilityCooldowns[abilityId] = math.max(0, cooldown or 0) -- Ensure non-negative
end


-- Clone the unit (Improved deep copy)
function Unit:clone()
    -- Deep copy stats
    local clonedStats = {}
    for k, v in pairs(self.stats) do clonedStats[k] = v end

    -- Deep copy abilities and cooldowns
    local clonedAbilities = {}
    for _, v in ipairs(self.abilities or {}) do table.insert(clonedAbilities, v) end
    local clonedCooldowns = {}
    for k, v in pairs(self.abilityCooldowns or {}) do clonedCooldowns[k] = v end

    -- Deep copy equipment (clone items using Item:clone)
    local clonedEquipment = {}
    if self.equipment then
        for slot, item in pairs(self.equipment) do
            clonedEquipment[slot] = (item and item.clone) and item:clone() or nil
        end
    end

    local cloneParams = {
        unitType = self.unitType, faction = self.faction,
        isPlayerControlled = self.isPlayerControlled,
        x = self.x, y = self.y,
        grid = self.grid, -- Shallow copy grid/game reference
        game = self.game,
        stats = clonedStats, -- Use the cloned stats table
        movementPattern = self.movementPattern,
        abilities = clonedAbilities, -- Use cloned abilities
        abilityCooldowns = clonedCooldowns, -- Use cloned cooldowns
        level = self.level, experience = self.experience, skillPoints = self.skillPoints,
        aiType = self.aiType,
        equipment = clonedEquipment, -- Use cloned equipment
        sprite = self.sprite, -- Shallow copy sprite reference
        color = {self.color[1], self.color[2], self.color[3], self.color[4]}, -- Copy color table
        id = self.id .. "_clone" -- Modify ID slightly
    }

    local clone = Unit:new(cloneParams)

    -- Deep copy status effects (clone if they have specific state)
    clone.statusEffects = {}
    if self.statusEffects then
        for name, effect in pairs(self.statusEffects) do
             local clonedEffect = {}
             for k, v in pairs(effect) do clonedEffect[k] = v end
             clone.statusEffects[name] = clonedEffect
        end
    end

    -- Copy animation state properties
    clone.visualX = self.visualX; clone.visualY = self.visualY
    clone.scale = {x = self.scale.x, y = self.scale.y}
    clone.rotation = self.rotation
    clone.offset = {x = self.offset.x, y = self.offset.y}
    clone.animationState = self.animationState
    clone.animationTimer = self.animationTimer
    clone.animationDirection = self.animationDirection

    return clone
end


-- --- Animation Helper Methods ---

-- Create a flash effect
function Unit:flash(duration, color)
    self.flashTimer = duration or 0.2
    self.flashDuration = self.flashTimer
    local r, g, b, a = 1, 1, 1, 1
    if color then r, g, b, a = color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1 end
    self.flashColor = {r, g, b, a}
end

-- Show hit effect
function Unit:showHitEffect()
    self:flash(0.2, {1, 0.3, 0.3, 1}) -- Flash red
    self.animationState = "hit"
    self.animationTimer = 0

    -- Optional screen shake (called by CombatSystem or AnimationManager after attack)
    -- if self.game and self.game.animationManager then
    --     self.game.animationManager:shakeScreen(0.15, 3) -- Shorter, stronger shake
    -- end
end

-- Show heal effect
function Unit:showHealEffect()
    self:flash(0.3, {0.3, 1, 0.3, 0.7}) -- Flash green
    self.animationState = "idle" -- Or a specific "heal" state if needed
    self.animationTimer = 0
    -- Optionally add particles via AnimationManager
end

-- Show ability effect
function Unit:showAbilityEffect(abilityType)
    local flashColor = {0.3, 0.3, 1, 0.7} -- Default blue
    if abilityType == "attack" then flashColor = {1, 0.3, 0.3, 0.7}
    elseif abilityType == "defense" then flashColor = {0.3, 0.7, 1, 0.7}
    elseif abilityType == "support" then flashColor = {0.3, 1, 0.3, 0.7}
    elseif abilityType == "special" then flashColor = {1, 0.8, 0.2, 0.7} end
    self:flash(0.4, flashColor)
    self.animationState = "casting"
    self.animationTimer = 0
end

-- MoveTo that integrates with animation manager
function Unit:moveTo(targetX, targetY)
    local oldX, oldY = self.x, self.y

    -- Check grid walkability before logical move
    if not self.grid or not self.grid:isWalkable(targetX, targetY) then
         print(string.format("Unit %s cannot move to unwalkable tile (%d,%d)", self.id or "N/A", targetX, targetY))
         return false -- Cannot move logically
    end

    -- Update logical position immediately
    self.x = targetX
    self.y = targetY

    -- Update grid's internal state (important!)
    if self.grid and self.grid.moveEntity then
         if not self.grid:moveEntity(self, targetX, targetY) then
              -- If grid move fails (e.g., tile became occupied), revert logical position
              print(string.format("Grid move failed for unit %s to (%d,%d). Reverting.", self.id or "N/A", targetX, targetY))
              self.x, self.y = oldX, oldY
              return false
         end
    else
         print("Warning: Unit moved without updating grid state.")
    end

    -- Trigger animation if manager exists
    if self.game and self.game.animationManager then
        -- Set animation direction
        if targetX > oldX then self.animationDirection = 1
        elseif targetX < oldX then self.animationDirection = -1 end

        -- Create movement animation
        local animId = self.game.animationManager:createMovementAnimation(
            self, targetX, targetY,
            function() -- onComplete callback
                self.animationState = "idle"
                print(string.format("Movement animation complete for %s", self.id or "N/A"))
            end
        )
        if animId then
             self.animationState = "moving"
             return true -- Animation started
        else
             -- Animation failed to start (e.g., unit already animating)
             -- Since logical move succeeded, update visual pos immediately as fallback
             print(string.format("WARN: Move animation failed for %s, snapping visual pos.", self.id or "N/A"))
             self.visualX = targetX
             self.visualY = targetY
             return true
        end
    else
        -- No animation manager, snap visual position
        self.visualX = targetX
        self.visualY = targetY
        return true
    end
end


return Unit