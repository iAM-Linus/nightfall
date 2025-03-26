-- Status Effects System for Nightfall Chess
-- Handles creation, management, and execution of status effects on units

local class = require("lib.middleclass.middleclass")

local StatusEffectsSystem = class("StatusEffectsSystem")

function StatusEffectsSystem:initialize(game)
    self.game = game
    
    -- Status effect definitions
    self.effects = {
        -- Burning: Damage over time
        burning = {
            name = "Burning",
            description = "Taking damage each turn",
            icon = nil, -- Would be an image in a full implementation
            duration = 3,
            triggerOn = "turnStart",
            stackable = false,
            preventAction = false,
            onApply = function(unit, source)
                -- Visual effect when applied
                print(unit.unitType:upper() .. " is burning!")
            end,
            onTrigger = function(unit, source)
                -- Deal damage each turn
                local damage = math.ceil(unit.stats.maxHealth * 0.1)
                if self.game.combatSystem then
                    self.game.combatSystem:applyDirectDamage(unit, damage, {
                        source = "status",
                        effect = "burning",
                        isCritical = false,
                        isMiss = false
                    })
                else
                    unit:takeDamage(damage)
                end
                print(unit.unitType:upper() .. " takes " .. damage .. " burning damage")
            end,
            onRemove = function(unit)
                -- Visual effect when removed
                print(unit.unitType:upper() .. " is no longer burning")
            end
        },
        
        -- Stunned: Prevent actions
        stunned = {
            name = "Stunned",
            description = "Cannot take actions",
            icon = nil,
            duration = 1,
            triggerOn = "turnStart",
            stackable = false,
            preventAction = true,
            onApply = function(unit, source)
                print(unit.unitType:upper() .. " is stunned!")
            end,
            onTrigger = function(unit, source)
                -- Already handled by turn manager's preventAction check
            end,
            onRemove = function(unit)
                print(unit.unitType:upper() .. " is no longer stunned")
            end
        },
        
        -- Weakened: Reduced attack
        weakened = {
            name = "Weakened",
            description = "Attack reduced by 50%",
            icon = nil,
            duration = 2,
            triggerOn = "turnStart",
            stackable = false,
            preventAction = false,
            onApply = function(unit, source)
                -- Store original attack value
                unit.originalAttack = unit.stats.attack
                -- Reduce attack
                unit.stats.attack = math.ceil(unit.stats.attack * 0.5)
                print(unit.unitType:upper() .. " is weakened!")
            end,
            onTrigger = function(unit, source)
                -- Nothing to do on trigger
            end,
            onRemove = function(unit)
                -- Restore original attack
                if unit.originalAttack then
                    unit.stats.attack = unit.originalAttack
                    unit.originalAttack = nil
                end
                print(unit.unitType:upper() .. " is no longer weakened")
            end
        },
        
        -- Shielded: Reduced damage taken
        shielded = {
            name = "Shielded",
            description = "Damage taken reduced by 50%",
            icon = nil,
            duration = 2,
            triggerOn = "turnStart",
            stackable = false,
            preventAction = false,
            onApply = function(unit, source)
                print(unit.unitType:upper() .. " is shielded!")
            end,
            onTrigger = function(unit, source)
                -- Nothing to do on trigger
                -- Damage reduction is handled in the unit's takeDamage method
            end,
            onRemove = function(unit)
                print(unit.unitType:upper() .. " is no longer shielded")
            end
        },
        
        -- Slowed: Reduced movement
        slowed = {
            name = "Slowed",
            description = "Movement range reduced by 1",
            icon = nil,
            duration = 2,
            triggerOn = "turnStart",
            stackable = false,
            preventAction = false,
            onApply = function(unit, source)
                -- Store original move range
                unit.originalMoveRange = unit.stats.moveRange
                -- Reduce move range
                unit.stats.moveRange = math.max(1, unit.stats.moveRange - 1)
                print(unit.unitType:upper() .. " is slowed!")
            end,
            onTrigger = function(unit, source)
                -- Nothing to do on trigger
            end,
            onRemove = function(unit)
                -- Restore original move range
                if unit.originalMoveRange then
                    unit.stats.moveRange = unit.originalMoveRange
                    unit.originalMoveRange = nil
                end
                print(unit.unitType:upper() .. " is no longer slowed")
            end
        },
        
        -- Regenerating: Heal over time
        regenerating = {
            name = "Regenerating",
            description = "Recovering health each turn",
            icon = nil,
            duration = 3,
            triggerOn = "turnStart",
            stackable = false,
            preventAction = false,
            onApply = function(unit, source)
                print(unit.unitType:upper() .. " is regenerating!")
            end,
            onTrigger = function(unit, source)
                -- Heal each turn
                local healAmount = math.ceil(unit.stats.maxHealth * 0.05)
                if self.game.combatSystem then
                    self.game.combatSystem:applyHealing(unit, healAmount, {
                        source = "status",
                        effect = "regenerating"
                    })
                else
                    unit:heal(healAmount)
                end
                print(unit.unitType:upper() .. " regenerates " .. healAmount .. " health")
            end,
            onRemove = function(unit)
                print(unit.unitType:upper() .. " is no longer regenerating")
            end
        },
        
        -- Empowered: Increased attack
        empowered = {
            name = "Empowered",
            description = "Attack increased by 50%",
            icon = nil,
            duration = 2,
            triggerOn = "turnStart",
            stackable = false,
            preventAction = false,
            onApply = function(unit, source)
                -- Store original attack value
                unit.originalAttack = unit.stats.attack
                -- Increase attack
                unit.stats.attack = math.ceil(unit.stats.attack * 1.5)
                print(unit.unitType:upper() .. " is empowered!")
            end,
            onTrigger = function(unit, source)
                -- Nothing to do on trigger
            end,
            onRemove = function(unit)
                -- Restore original attack
                if unit.originalAttack then
                    unit.stats.attack = unit.originalAttack
                    unit.originalAttack = nil
                end
                print(unit.unitType:upper() .. " is no longer empowered")
            end
        },
        
        -- Hastened: Increased movement
        hastened = {
            name = "Hastened",
            description = "Movement range increased by 1",
            icon = nil,
            duration = 2,
            triggerOn = "turnStart",
            stackable = false,
            preventAction = false,
            onApply = function(unit, source)
                -- Store original move range
                unit.originalMoveRange = unit.stats.moveRange
                -- Increase move range
                unit.stats.moveRange = unit.stats.moveRange + 1
                print(unit.unitType:upper() .. " is hastened!")
            end,
            onTrigger = function(unit, source)
                -- Nothing to do on trigger
            end,
            onRemove = function(unit)
                -- Restore original move range
                if unit.originalMoveRange then
                    unit.stats.moveRange = unit.originalMoveRange
                    unit.originalMoveRange = nil
                end
                print(unit.unitType:upper() .. " is no longer hastened")
            end
        },
        
        -- Invisible: Cannot be targeted
        invisible = {
            name = "Invisible",
            description = "Cannot be targeted by enemies",
            icon = nil,
            duration = 1,
            triggerOn = "turnStart",
            stackable = false,
            preventAction = false,
            onApply = function(unit, source)
                print(unit.unitType:upper() .. " is invisible!")
            end,
            onTrigger = function(unit, source)
                -- Nothing to do on trigger
                -- Targeting prevention is handled in the combat system
            end,
            onRemove = function(unit)
                print(unit.unitType:upper() .. " is no longer invisible")
            end
        }
    }
end

-- Apply a status effect to a unit
function StatusEffectsSystem:applyEffect(unit, effectType, source)
    -- Get effect definition
    local effectDef = self.effects[effectType]
    if not effectDef then
        print("Effect type not found: " .. effectType)
        return false
    end
    
    -- Create effect instance
    local effect = {
        name = effectDef.name,
        description = effectDef.description,
        icon = effectDef.icon,
        duration = effectDef.duration,
        triggerOn = effectDef.triggerOn,
        stackable = effectDef.stackable,
        preventAction = effectDef.preventAction,
        onTrigger = effectDef.onTrigger,
        onRemove = effectDef.onRemove,
        source = source
    }
    
    -- Apply to unit
    unit:addStatusEffect(effect)
    
    -- Call onApply callback
    if effectDef.onApply then
        effectDef.onApply(unit, source)
    end
    
    return true
end

-- Remove a status effect from a unit
function StatusEffectsSystem:removeEffect(unit, effectType)
    return unit:removeStatusEffect(effectType)
end

-- Trigger effects on a unit
function StatusEffectsSystem:triggerEffects(unit, triggerType)
    if not unit.statusEffects then return end
    
    for _, effect in ipairs(unit.statusEffects) do
        if effect.triggerOn == triggerType then
            if effect.onTrigger then
                effect.onTrigger(unit, effect.source)
            end
        end
    end
end

-- Check if a unit has a specific effect
function StatusEffectsSystem:hasEffect(unit, effectType)
    return unit:hasStatusEffect(effectType)
end

-- Get a list of all effects on a unit
function StatusEffectsSystem:getEffects(unit)
    return unit.statusEffects or {}
end

-- Get effect definition
function StatusEffectsSystem:getEffectDefinition(effectType)
    return self.effects[effectType]
end

-- Apply a random negative status effect
function StatusEffectsSystem:applyRandomNegativeEffect(unit, source)
    local negativeEffects = {"burning", "stunned", "weakened", "slowed"}
    local effectType = negativeEffects[math.random(#negativeEffects)]
    return self:applyEffect(unit, effectType, source)
end

-- Apply a random positive status effect
function StatusEffectsSystem:applyRandomPositiveEffect(unit, source)
    local positiveEffects = {"shielded", "regenerating", "empowered", "hastened", "invisible"}
    local effectType = positiveEffects[math.random(#positiveEffects)]
    return self:applyEffect(unit, effectType, source)
end

-- Update all status effects
function StatusEffectsSystem:update(dt)
    -- This is handled by the units themselves in their update method
end

return StatusEffectsSystem
