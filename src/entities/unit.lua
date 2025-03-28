-- Unit Entity for Nightfall Chess
-- Represents a playable character or enemy on the grid
-- Includes base stats, abilities, status effects, leveling, and animation properties

local class = require("lib.middleclass.middleclass")
local timer = require("lib.hump.timer") -- Needed for animation/effect timers

-- Forward declare Item class if needed for equipItem type checking, or ensure it's required globally before Unit
-- local Item = require("src.entities.item") -- Uncomment if Item is needed and not global

local Unit = class("Unit")

function Unit:initialize(params)
    -- Basic properties
    self.unitType = params.unitType or "pawn"
    self.faction = params.faction or "player"
    self.isPlayerControlled = params.isPlayerControlled or (self.faction == "player") -- Default based on faction

    -- Position
    self.x = params.x or 1
    self.y = params.y or 1
    self.grid = params.grid or nil
    self.game = params.game or nil -- Add game reference

    -- Initialize stats object first
    self.stats = {}

    -- Handle energy/mana consistently
    local maxEnergy = params.stats and (params.stats.maxEnergy or params.stats.maxMana) or 10
    local energy = params.stats and (params.stats.energy or params.stats.mana) or maxEnergy -- Start with full energy

    -- Handle movement range/speed consistently
    local moveRange = params.stats and params.stats.moveRange or
                      (params.stats and params.stats.speed and math.max(1, math.floor(params.stats.speed / 2))) or
                      2 -- Default move range

    -- Set stats, using defaults if needed
    self.stats = {
        health = params.stats and params.stats.health or 10,
        maxHealth = params.stats and params.stats.maxHealth or 10,
        attack = params.stats and params.stats.attack or 2,
        defense = params.stats and params.stats.defense or 1,
        moveRange = moveRange,
        attackRange = params.stats and params.stats.attackRange or 1,
        energy = energy,
        maxEnergy = maxEnergy,
        initiative = params.stats and params.stats.initiative or 5
    }

    -- Ensure current health/energy don't exceed max
    self.stats.health = math.min(self.stats.health, self.stats.maxHealth)
    self.stats.energy = math.min(self.stats.energy, self.stats.maxEnergy)

    -- Use energy from stats for instance properties (optional, could just use stats directly)
    self.energy = self.stats.energy
    self.maxEnergy = self.stats.maxEnergy
    self.energyRegenTimer = 0

    -- Movement pattern (default based on type if not provided)
    self.movementPattern = params.movementPattern or self:getDefaultMovementPattern()

    -- Action state
    self.hasMoved = false
    self.hasAttacked = false
    self.hasUsedAbility = false

    -- Animation properties for the animation system
    self.visualX = self.x             -- Current visual grid X (can differ during animation)
    self.visualY = self.y             -- Current visual grid Y
    self.scale = {x = 1, y = 1}       -- Scale factor {x, y}
    self.rotation = 0                 -- Rotation in radians
    self.offset = {x = 0, y = 0}       -- Pixel offset from grid position {x, y}
    self.color = params.color or {1, 1, 1, 1} -- Color modulation {r, g, b, a}
    self.animationState = "idle"      -- Current animation state (idle, moving, attacking, hit, casting)
    self.animationTimer = 0           -- Timer for current animation state/frame
    self.animationFrame = 1           -- Current frame index for sprite sheet animations (if used)
    self.animationDirection = 1       -- Facing direction (1 for right, -1 for left)

    -- Flash effect properties
    self.flashTimer = 0               -- Remaining duration of flash effect
    self.flashDuration = 0            -- Total duration of the flash
    self.flashColor = {1, 1, 1, 0}    -- Color and alpha of the flash overlay

    -- Shadow properties
    self.shadowScale = 1              -- Scale of the shadow ellipse
    self.shadowAlpha = 0.5            -- Opacity of the shadow

    -- Abilities
    self.abilities = params.abilities or self:getDefaultAbilities()
    self.abilityCooldowns = params.abilityCooldowns or {}
    for _, abilityId in ipairs(self.abilities) do
        if self.abilityCooldowns[abilityId] == nil then
             self.abilityCooldowns[abilityId] = 0
        end
    end

    -- Status effects
    self.statusEffects = {}

    -- Experience and level
    self.level = params.level or 1
    self.experience = params.experience or 0
    self.skillPoints = params.skillPoints or 0 -- Add skill points if using experience system

    -- Equipment
    self.equipment = {
        weapon = nil,
        armor = nil,
        accessory = nil
    }
    -- If equipment data is passed in params, equip it properly
    if params.equipment then
        for slot, itemData in pairs(params.equipment) do
            if itemData then -- Assuming itemData is an Item instance or needs creating
                -- Ensure Item class is available here
                if Item then
                   local item = (type(itemData) == "table" and itemData.isInstanceOf and itemData:isInstanceOf(Item)) and itemData or Item:new(itemData)
                   self:equipItem(item, slot)
                else
                   print("WARNING: Item class not available during Unit initialization")
                end
            end
        end
    end

    -- Inventory (Units typically don't have inventories, maybe player/team does)
    self.inventory = params.inventory or {}

    -- Visual representation
    self.sprite = params.sprite -- Needs actual loading logic

    -- AI behavior type
    self.aiType = params.aiType or "balanced"

    -- Unique identifier
    self.id = params.id or self.unitType .. "_" .. tostring(math.random(1000, 9999))

    -- Experience system initialization (if applicable)
    if self.game and self.game.experienceSystem then
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
if not Unit.getDefaultMovementPattern then
    function Unit:getDefaultMovementPattern()
        local patterns = {
            king = "king", queen = "queen", rook = "orthogonal",
            bishop = "diagonal", knight = "knight", pawn = "pawn"
        }
        return patterns[self.unitType] or "orthogonal" -- Default to rook/orthogonal
    end
end

-- Update unit state
function Unit:update(dt)
    -- Update status effect durations
    self:updateStatusEffects(dt) -- Call this first to handle effects like stun potentially

    -- Check if stunned or otherwise prevented from acting by status effect
    local preventAction = false
    if self.statusEffects then
        for _, effect in pairs(self.statusEffects) do
             if effect.preventAction then
                 preventAction = true
                 break
             end
        end
    end
    if preventAction then return end -- Skip rest of update if stunned

    -- Update flash effect
    if self.flashTimer > 0 then
        self.flashTimer = self.flashTimer - dt
        -- Update flash color alpha based on remaining time
        if self.flashDuration > 0 then
            local flashProgress = self.flashTimer / self.flashDuration
            self.flashColor[4] = flashProgress
        else
            self.flashColor[4] = 0 -- Avoid division by zero
        end
        if self.flashTimer <= 0 then
            self.flashColor[4] = 0 -- Ensure alpha is zero when done
        end
    end

    -- Update animation frame for idle animation (or other states if implemented)
    if self.animationState == "idle" then
        self.animationTimer = (self.animationTimer or 0) + dt
        -- Subtle idle animation - slight bobbing
        local idleBobAmount = 0.03 * (self.grid and self.grid.tileSize or 64) -- Scale bob with tile size
        local idleBobSpeed = 2
        self.offset.y = -math.sin(self.animationTimer * idleBobSpeed) * idleBobAmount
    end
    -- Add updates for other animation states here if needed

    -- Regenerate energy over time
    if self.stats.energy < self.stats.maxEnergy then
        self.energyRegenTimer = (self.energyRegenTimer or 0) + dt
        if self.energyRegenTimer >= 1 then
            self.energyRegenTimer = 0
            self.stats.energy = math.min(self.stats.energy + 1, self.stats.maxEnergy)
            self.energy = self.stats.energy -- Sync instance property if used
        end
    end
end


-- Draw the unit using animation properties
function Unit:draw()
    if not self.grid then return end

    -- Calculate screen position based on VISUAL position
    local screenX, screenY = self.grid:gridToScreen(self.visualX, self.visualY)
    local tileSize = self.grid.tileSize

    -- Draw shadow
    love.graphics.setColor(0, 0, 0, self.shadowAlpha)
    local shadowX = screenX + tileSize/2
    local shadowY = screenY + tileSize - 4 -- Position shadow slightly below the unit
    local shadowWidth = tileSize * 0.7 * self.shadowScale
    local shadowHeight = tileSize * 0.2 * self.shadowScale -- Scale height too
    love.graphics.ellipse("fill", shadowX, shadowY, shadowWidth/2, shadowHeight/2)

    -- Apply transformations
    love.graphics.push()

    -- Calculate center for transformations
    local centerX = screenX + tileSize/2
    local centerY = screenY + tileSize/2

    -- Translate to center of tile + offset
    love.graphics.translate(centerX + (self.offset.x or 0), centerY + (self.offset.y or 0))

    -- Apply rotation
    love.graphics.rotate(self.rotation or 0)

    -- Apply scale (use animationDirection for horizontal flipping if needed)
    local scaleX = (self.scale and self.scale.x or 1) * (self.animationDirection or 1)
    local scaleY = self.scale and self.scale.y or 1
    love.graphics.scale(scaleX, scaleY)

    -- Translate back to corner for drawing (relative to the center)
    love.graphics.translate(-tileSize/2, -tileSize/2)

    -- Draw unit based on type
    local unitDrawColor = self.faction == "player" and {0.2, 0.6, 0.9} or {0.9, 0.3, 0.3}

    -- Apply unit color modulation (from self.color property)
    love.graphics.setColor(
        unitDrawColor[1] * (self.color and self.color[1] or 1),
        unitDrawColor[2] * (self.color and self.color[2] or 1),
        unitDrawColor[3] * (self.color and self.color[3] or 1),
        self.color and self.color[4] or 1 -- Use alpha from self.color
    )

    -- Draw unit body (simple rectangle for now)
    love.graphics.rectangle("fill", 4, 4, tileSize - 8, tileSize - 8)

    -- Draw unit border
    love.graphics.setColor(1, 1, 1, 0.8 * (self.color and self.color[4] or 1))
    love.graphics.rectangle("line", 4, 4, tileSize - 8, tileSize - 8)

    -- Draw unit type indicator
    love.graphics.setColor(1, 1, 1, self.color and self.color[4] or 1)
    -- Ensure font is set before drawing text (ideally set outside this function)
    -- love.graphics.setFont(self.game.assets.fonts.medium) -- Example
    love.graphics.printf(self.unitType:sub(1, 1):upper(), 0, tileSize/2 - 10, tileSize, "center")

    -- Restore transformation
    love.graphics.pop() -- Pops the scale, rotate, translate

    -- Draw action state indicators (outside the main transform)
    local indicatorX = screenX + tileSize - 10 -- Position indicators top-right
    local indicatorY = screenY + 2
    local indicatorSize = 8
    local indicatorSpacing = 2

    if self.hasMoved then
        love.graphics.setColor(0.8, 0.8, 0.2, 0.7)
        love.graphics.rectangle("fill", indicatorX, indicatorY, indicatorSize, indicatorSize)
        indicatorY = indicatorY + indicatorSize + indicatorSpacing
    end

    if self.hasAttacked then
        love.graphics.setColor(0.8, 0.2, 0.2, 0.7)
        love.graphics.rectangle("fill", indicatorX, indicatorY, indicatorSize, indicatorSize)
        indicatorY = indicatorY + indicatorSize + indicatorSpacing
    end

    if self.hasUsedAbility then
        love.graphics.setColor(0.2, 0.2, 0.8, 0.7)
        love.graphics.rectangle("fill", indicatorX, indicatorY, indicatorSize, indicatorSize)
    end

    -- Draw flash effect on top
    if self.flashTimer > 0 and self.flashColor[4] > 0 then
        love.graphics.setColor(
            self.flashColor[1],
            self.flashColor[2],
            self.flashColor[3],
            self.flashColor[4]
        )
        -- Draw over the logical grid position, not the potentially offset visual one
        local logicalScreenX, logicalScreenY = self.grid:gridToScreen(self.x, self.y)
        love.graphics.rectangle("fill", logicalScreenX, logicalScreenY, tileSize, tileSize)
    end

    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end


-- Reset action state for a new turn
function Unit:resetActionState()
    self.hasMoved = false
    self.hasAttacked = false
    self.hasUsedAbility = false

    -- Reduce ability cooldowns
    self.abilityCooldowns = self.abilityCooldowns or {}
    for abilityId, cooldown in pairs(self.abilityCooldowns) do
        if cooldown > 0 then
            self.abilityCooldowns[abilityId] = cooldown - 1
        end
    end

    -- Regenerate some energy
    local energyRegen = 2 -- Amount to regenerate per turn
    self.stats.energy = math.min(self.stats.energy + energyRegen, self.stats.maxEnergy)
    self.energy = self.stats.energy -- Sync instance property if used
end

-- Take damage
function Unit:takeDamage(amount, source)
    local defense = self.stats.defense or 0
    local actualDamage = math.max(1, amount - defense)

    -- Check for shielded status effect
    if self:hasStatusEffect("shielded") then
        actualDamage = math.floor(actualDamage * 0.5)
    end

    self.stats.health = math.max(0, self.stats.health - actualDamage)

    -- Trigger hit animation/effect
    self:showHitEffect()

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
        self.energy = self.stats.energy -- Sync instance property if used
        return true
    end
    return false
end

-- Add status effect
function Unit:addStatusEffect(effect)
    -- Ensure statusEffects table exists
    self.statusEffects = self.statusEffects or {}

    -- Check if effect already exists and handle stacking/refreshing
    local existingEffect = nil
    for i, eff in ipairs(self.statusEffects) do
        if eff.name == effect.name then
            existingEffect = eff
            break
        end
    end

    if existingEffect then
        if not effect.stackable then
            -- Refresh duration
            existingEffect.duration = effect.duration
            print("Refreshed status effect: " .. effect.name)
            return
        else
            -- Stacking logic would go here (e.g., increase intensity or duration)
            existingEffect.duration = existingEffect.duration + effect.duration
            print("Stacked status effect: " .. effect.name)
            return
        end
    end

    -- Add new effect (make a copy to avoid modifying templates)
    local newEffect = {}
    for k, v in pairs(effect) do
        newEffect[k] = v
    end
    newEffect.durationTimer = newEffect.duration -- Initialize timer correctly if needed

    table.insert(self.statusEffects, newEffect)

    -- Call onApply callback if it exists
    if newEffect.onApply then
        newEffect.onApply(self)
    end
    print("Applied status effect: " .. newEffect.name)
end

-- Remove status effect
function Unit:removeStatusEffect(effectName)
    if not self.statusEffects then return false end

    for i = #self.statusEffects, 1, -1 do -- Iterate backwards when removing
        local effect = self.statusEffects[i]
        if effect.name == effectName then
            -- Call onRemove callback if it exists
            if effect.onRemove then
                effect.onRemove(self)
            end
            table.remove(self.statusEffects, i)
            print("Removed status effect: " .. effectName)
            return true
        end
    end
    return false
end


-- Update status effects (Called from Unit:update)
function Unit:updateStatusEffects(dt)
    if not self.statusEffects then return end

    local i = 1
    while i <= #self.statusEffects do
        local effect = self.statusEffects[i]
        local removeEffect = false

        -- Reduce duration if it's time-based
        if effect.duration then
             effect.duration = effect.duration - dt
             if effect.duration <= 0 then
                 removeEffect = true
             end
        end

        -- Handle removal OR trigger onTick
        if removeEffect then
            if effect.onRemove then
                effect.onRemove(self) -- Call onRemove before removing
            end
            print("Status effect expired: " .. effect.name)
            table.remove(self.statusEffects, i)
            -- Don't increment 'i' because the next element shifted into the current index
        else
            -- Call onTick if it exists and effect is still active
            if effect.onTick then
                effect.onTick(self, dt)
            end
            i = i + 1 -- Only increment if not removed
        end
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
    if self.level >= (self.game and self.game.experienceSystem and self.game.experienceSystem.config.maxLevel or 10) then
       return false -- Already max level
    end

    self.experience = (self.experience or 0) + amount
    local leveledUp = false

    -- Check for level up using the experience system
    if self.game and self.game.experienceSystem then
        local expForNextLevel = self.game.experienceSystem:getExpRequiredForLevel(self.level + 1)
        while self.experience >= expForNextLevel and self.level < self.game.experienceSystem.config.maxLevel do
            if self:levelUp() then -- levelUp now handles exp adjustment
                leveledUp = true
                expForNextLevel = self.game.experienceSystem:getExpRequiredForLevel(self.level + 1)
            else
                break -- Stop if levelUp failed for some reason
            end
        end
    else
        -- Fallback logic if experience system isn't available
        local expForNextLevel = 100 * (self.level ^ 1.5)
         while self.experience >= expForNextLevel and self.level < 10 do
            self:levelUp() -- Use the existing levelUp logic
            leveledUp = true
            expForNextLevel = 100 * (self.level ^ 1.5)
         end
    end

    return leveledUp
end

-- Get experience required for next level (delegates or uses fallback)
function Unit:getExpRequiredForNextLevel()
    if self.game and self.game.experienceSystem then
        return self.game.experienceSystem:getExpRequiredForLevel(self.level + 1)
    else
        -- Fallback formula
        return math.floor(100 * (self.level ^ 1.5))
    end
end


-- Level up (improved to use experience system if available)
function Unit:levelUp()
    if self.game and self.game.experienceSystem then
        -- Delegate level up logic to the experience system
        return self.game.experienceSystem:levelUp(self)
    else
        -- Fallback logic if experience system not available
        local expRequired = self:getExpRequiredForNextLevel() -- Use the unit's method
        if self.experience < expRequired then return false end -- Shouldn't happen if called correctly

        self.level = self.level + 1
        self.experience = self.experience - expRequired -- Adjust experience

        local statGrowth = { -- Keep fallback growth rates
            king = {health = 5, attack = 1, defense = 1, energy = 2},
            queen = {health = 5, attack = 3, defense = 1, energy = 2},
            rook = {health = 8, attack = 2, defense = 2, energy = 1},
            bishop = {health = 4, attack = 2, defense = 0, energy = 3},
            knight = {health = 6, attack = 2, defense = 1, energy = 2},
            pawn = {health = 5, attack = 1, defense = 1, energy = 1}
        }
        local growth = statGrowth[self.unitType] or {health = 5, attack = 1, defense = 1, energy = 1}
        self.stats.maxHealth = self.stats.maxHealth + growth.health
        self.stats.health = self.stats.maxHealth
        self.stats.attack = self.stats.attack + growth.attack
        self.stats.defense = self.stats.defense + growth.defense
        self.stats.maxEnergy = self.stats.maxEnergy + growth.energy
        self.stats.energy = self.stats.maxEnergy

        if self.level % 3 == 0 then
            if math.random() < 0.7 then self.stats.moveRange = self.stats.moveRange + 1
            else self.stats.attackRange = self.stats.attackRange + 1 end
        end
        print(self.unitType .. " leveled up to " .. self.level .. "!")
        return true
    end
end


-- Equip an item (more robust, handles stats)
function Unit:equipItem(item, slot)
    if not slot then
        if item.type == "weapon" then slot = "weapon"
        elseif item.type == "armor" then slot = "armor"
        elseif item.type == "accessory" then slot = "accessory"
        else return false, "Cannot equip this item type" end
    end

    if not self.equipment or self.equipment[slot] == nil then -- Check if slot exists (might be nil if not initialized correctly)
        -- Initialize equipment table if it doesn't exist
         if not self.equipment then self.equipment = {weapon=nil, armor=nil, accessory=nil} end
         -- If the specific slot is nil, it's okay to equip
    elseif self.equipment[slot] then
         -- Unequip current item first
         self:unequipItemBySlot(slot) -- Use a new helper function
    end

    -- Equip new item
    self.equipment[slot] = item
    if item.setEquippedState then item:setEquippedState(true, self) end -- If item has this method

    -- Apply stats
    if item.stats then
        for stat, value in pairs(item.stats) do
            if self.stats[stat] then
                -- Store original value before modifying IF NOT ALREADY STORED BY ANOTHER ITEM
                if not self.originalStats then self.originalStats = {} end
                if self.originalStats[stat] == nil then self.originalStats[stat] = {} end -- Use a table to track multiple sources
                if self.originalStats[stat][item.id] == nil then
                    self.originalStats[stat][item.id] = self.stats[stat] -- Store base value for this item's effect
                end

                self.stats[stat] = self.stats[stat] + value
                -- Update health/energy if max changes
                if stat == "maxHealth" then self.stats.health = math.min(self.stats.health, self.stats.maxHealth) end
                if stat == "maxEnergy" then self.stats.energy = math.min(self.stats.energy, self.stats.maxEnergy); self.energy = self.stats.energy end
            end
        end
    end

     -- Call item's onEquip if it exists
     if item.onEquip then
         item:onEquip(self)
     end

    print(self.unitType .. " equipped " .. item.name .. " in " .. slot .. " slot.")
    return true
end

-- Unequip an item by slot (Helper function)
function Unit:unequipItemBySlot(slot)
     if not self.equipment or not self.equipment[slot] then return false end

     local item = self.equipment[slot]
     self.equipment[slot] = nil -- Remove from slot
     if item.setEquippedState then item:setEquippedState(false, self) end

     -- Revert stats
     if item.stats then
         for stat, value in pairs(item.stats) do
             if self.stats[stat] then
                 -- Revert the change caused by this item
                 self.stats[stat] = self.stats[stat] - value

                 -- Remove this item's tracking from originalStats
                 if self.originalStats and self.originalStats[stat] then
                    self.originalStats[stat][item.id] = nil
                    -- If no other items modify this stat, clear the entry
                    if not next(self.originalStats[stat]) then
                       self.originalStats[stat] = nil
                    end
                 end

                 -- Ensure health/energy don't exceed new max
                 if stat == "maxHealth" then self.stats.health = math.min(self.stats.health, self.stats.maxHealth) end
                 if stat == "maxEnergy" then self.stats.energy = math.min(self.stats.energy, self.stats.maxEnergy); self.energy = self.stats.energy end
             end
         end
     end

     -- Call item's onUnequip if it exists
     if item.onUnequip then
         item:onUnequip(self)
     end

     print(self.unitType .. " unequipped " .. item.name .. " from " .. slot .. " slot.")
     return true, item -- Return true and the item unequipped
end

-- Unequip a specific item instance (finds the slot first)
function Unit:unequipItem(itemToUnequip)
    if not self.equipment then return false, "No equipment" end
    for slot, item in pairs(self.equipment) do
        if item == itemToUnequip then
            return self:unequipItemBySlot(slot)
        end
    end
    return false, "Item not equipped"
end


-- Use an ability (delegates to system)
function Unit:useAbility(abilityId, target, x, y)
    if not abilityId then
        print("Unit:useAbility - Error: abilityId is nil")
        return false, "No ability ID provided"
    end

    if not self.game or not self.game.specialAbilitiesSystem then
        print("Warning: Cannot use ability - SpecialAbilitiesSystem not available")
        return false, "System not available"
    end

    local ability = self.game.specialAbilitiesSystem:getAbility(abilityId)
    if not ability then
        print("Warning: Ability '" .. abilityId .. "' not found in system")
        return false, "Ability definition not found"
    end

    -- Check using the unit's own method first (which calls the system's check)
    if not self:canUseAbility(abilityId) then
         print("Unit cannot use ability " .. abilityId .. " (cooldown, energy, or action state)")
         return false, "Cannot use ability now"
    end

    -- Perform the action via the system
    local success, message = self.game.specialAbilitiesSystem:useAbility(self, abilityId, target, x, y)

    if success then
        -- System handles cooldown and energy cost, but mark action state here
        self.hasUsedAbility = true
    else
        print("Failed to use ability '" .. abilityId .. "': " .. (message or "System reported failure"))
    end

    return success, message
end


-- Get ability cooldown
function Unit:getAbilityCooldown(abilityId)
    if not abilityId then
        print("Unit:getAbilityCooldown - Warning: abilityId is nil")
        return 0
    end
    self.abilityCooldowns = self.abilityCooldowns or {}
    return self.abilityCooldowns[abilityId] or 0
end

-- Set ability cooldown
function Unit:setAbilityCooldown(abilityId, cooldown)
    if not abilityId then
        print("Unit:setAbilityCooldown - Warning: abilityId is nil")
        return
    end
    self.abilityCooldowns = self.abilityCooldowns or {}
    self.abilityCooldowns[abilityId] = cooldown or 0
end

-- Check if unit can use an ability (More robust)
function Unit:canUseAbility(abilityId)
    if not abilityId then return false end -- Need an ID

    -- Check action state
    if self.hasUsedAbility then return false, "Already used ability" end

    -- Check game state / system availability
    if not self.game or not self.game.specialAbilitiesSystem then
        return false, "System unavailable"
    end

    local ability = self.game.specialAbilitiesSystem:getAbility(abilityId)
    if not ability then return false, "Ability unknown" end

    -- Check cooldown
    if (self:getAbilityCooldown(abilityId) or 0) > 0 then
        return false, "On cooldown"
    end

    -- Check energy cost
    if self.stats.energy < (ability.energyCost or 0) then
        return false, "Not enough energy"
    end

    -- Check action point cost (if applicable, assuming 1 for now, system might handle this better)
    -- local requiredAP = ability.actionPointCost or 1
    -- if self.game.turnManager and self.game.turnManager.currentActionPoints < requiredAP then
    --     return false, "Not enough action points"
    -- end

    -- TODO: Add checks for range, target validity (maybe in a separate canUseAbilityOnTarget method)

    return true -- If all checks pass
end


-- Clone the unit
function Unit:clone()
    -- Deep copy stats
    local clonedStats = {}
    for k, v in pairs(self.stats) do clonedStats[k] = v end

    -- Deep copy abilities and cooldowns
    local clonedAbilities = {}
    for _, v in ipairs(self.abilities or {}) do table.insert(clonedAbilities, v) end
    local clonedCooldowns = {}
    for k, v in pairs(self.abilityCooldowns or {}) do clonedCooldowns[k] = v end

    -- Deep copy equipment (clone items if they have a clone method)
    local clonedEquipment = {}
    for slot, item in pairs(self.equipment or {}) do
        clonedEquipment[slot] = (item and item.clone) and item:clone() or item -- Clone if possible
    end

    local cloneParams = {
        unitType = self.unitType,
        faction = self.faction,
        isPlayerControlled = self.isPlayerControlled,
        x = self.x,
        y = self.y,
        grid = self.grid, -- Grid and game references are shallow copied
        game = self.game,
        stats = clonedStats,
        movementPattern = self.movementPattern,
        abilities = clonedAbilities,
        abilityCooldowns = clonedCooldowns,
        level = self.level,
        experience = self.experience,
        skillPoints = self.skillPoints,
        aiType = self.aiType,
        equipment = clonedEquipment,
        -- Inventory is usually not per-unit, skip unless intended
        sprite = self.sprite, -- Shallow copy sprite reference
        color = {self.color[1], self.color[2], self.color[3], self.color[4]}, -- Copy color table
        id = self.id .. "_clone" -- Modify ID slightly
    }

    local clone = Unit:new(cloneParams)

    -- Deep copy status effects (clone if they have specific state)
    clone.statusEffects = {}
    for _, effect in ipairs(self.statusEffects or {}) do
         local clonedEffect = {}
         for k, v in pairs(effect) do clonedEffect[k] = v end
         table.insert(clone.statusEffects, clonedEffect)
    end

    return clone
end


-- Debug abilities function for a Unit
function Unit:debugAbilities()
    print("\n=== UNIT ABILITY DEBUG ===")
    print("Unit: " .. (self.id or "N/A") .. " (" .. (self.unitType or "unknown") .. ")")
    print("Energy: " .. (self.stats and self.stats.energy or 0) .. "/" .. (self.stats and self.stats.maxEnergy or 0))

    if not self.abilities or #self.abilities == 0 then
        print("No abilities assigned.")
    else
        print("Assigned Abilities:")
        for i, abilityId in ipairs(self.abilities) do
            local cooldown = self:getAbilityCooldown(abilityId)
            local canUse, reason = self:canUseAbility(abilityId)
            local abilityDef = (self.game and self.game.specialAbilitiesSystem) and self.game.specialAbilitiesSystem:getAbility(abilityId) or nil
            local name = (abilityDef and abilityDef.name) or "Unknown"

            print(string.format("  %d. %s (%s): CD=%d, CanUse=%s (%s)",
                  i, name, abilityId, cooldown, tostring(canUse), reason or ""))
        end
    end
    print("=== END UNIT DEBUG ===\n")
end

-- NEW: Add method to create a flash effect
function Unit:flash(duration, color)
    self.flashTimer = duration or 0.2
    self.flashDuration = self.flashTimer
    -- Ensure color has 4 components (r, g, b, a)
    local flash_r = color and color[1] or 1
    local flash_g = color and color[2] or 1
    local flash_b = color and color[3] or 1
    local flash_a = color and color[4] or 1
    self.flashColor = {flash_r, flash_g, flash_b, flash_a}
end

-- NEW: Add method to create a hit effect
function Unit:showHitEffect()
    -- Flash red
    self:flash(0.2, {1, 0.3, 0.3, 1})

    -- Shake briefly (relies on animationManager being available)
    if self.game and self.game.animationManager then
        self.game.animationManager:shakeScreen(0.3, 0.2)
    end
    self.animationState = "hit" -- Also update state
    self.animationTimer = 0
end

-- NEW: Add method to create a heal effect
function Unit:showHealEffect()
    -- Flash green
    self:flash(0.3, {0.3, 1, 0.3, 0.7})
     self.animationState = "heal" -- Add a heal state? Or just keep idle?
     self.animationTimer = 0
end

-- NEW: Add method to create an ability effect
function Unit:showAbilityEffect(abilityType)
    -- Flash based on ability type
    local flashColor = {0.3, 0.3, 1, 0.7} -- Default blue

    if abilityType == "attack" then flashColor = {1, 0.3, 0.3, 0.7} -- Red for attack
    elseif abilityType == "defense" then flashColor = {0.3, 0.7, 1, 0.7} -- Blue for defense
    elseif abilityType == "support" then flashColor = {0.3, 1, 0.3, 0.7} -- Green for support
    elseif abilityType == "special" then flashColor = {1, 0.8, 0.2, 0.7} -- Gold for special
    end

    self:flash(0.4, flashColor)
    self.animationState = "casting" -- Set casting state
    self.animationTimer = 0
end

-- NEW: MoveTo that integrates with animation manager (from unit_animation_extension)
function Unit:moveTo(targetX, targetY)
    -- Update logical position immediately
    local oldX, oldY = self.x, self.y
    self.x = targetX
    self.y = targetY

    -- If animation manager exists, create movement animation
    if self.game and self.game.animationManager then
        -- Set animation direction based on movement
        if targetX > oldX then self.animationDirection = 1
        elseif targetX < oldX then self.animationDirection = -1
        -- Keep direction if only moving vertically
        end

        -- Create movement animation
        self.game.animationManager:createMovementAnimation(
            self,
            targetX,
            targetY,
            function()
                -- Animation completed callback
                self.animationState = "idle"
                -- Optionally trigger game event: self.game:onUnitFinishedMoving(self)
            end
        )

        -- Update animation state
        self.animationState = "moving"
        return true -- Indicate animation started
    else
        -- No animation manager, just update visual position immediately
        self.visualX = targetX
        self.visualY = targetY
        -- Call original grid update (if it existed) or just return true
        -- If you have a separate grid.moveEntity, call that here for collision updates
        if self.grid and self.grid.updateEntityPosition then -- Example method name
             self.grid:updateEntityPosition(self, oldX, oldY)
        end
        return true
    end
end

return Unit