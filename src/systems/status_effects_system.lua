-- Status Effects System for Nightfall Chess
-- Handles creation, application, and management of status effects

local class = require("lib.middleclass.middleclass")

local StatusEffectsSystem = class("StatusEffectsSystem")

function StatusEffectsSystem:initialize(game)
    self.game = game
    
    -- Status effect definitions
    self.statusEffects = {
        -- DAMAGE OVER TIME EFFECTS
        
        -- Burning: Deals damage each turn and reduces defense
        burning = {
            name = "Burning",
            description = "Taking damage each turn and defense reduced",
            icon = nil, -- Would be an image in a full implementation
            duration = 3,
            triggerOn = "turnStart",
            stackable = false,
            preventAction = false,
            visualEffect = "fire",
            category = "negative",
            onApply = function(unit)
                -- Store original defense
                unit.originalDefense = unit.stats.defense
                -- Reduce defense
                unit.stats.defense = math.max(0, math.floor(unit.stats.defense * 0.8))
                
                -- Visual effect when applied
                if self.game.ui then
                    self.game.ui:showNotification(unit.unitType:upper() .. " is burning!", 1.5)
                end
            end,
            onTrigger = function(unit)
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
                    unit.stats.health = math.max(0, unit.stats.health - damage)
                end
            end,
            onRemove = function(unit)
                -- Restore original defense
                if unit.originalDefense then
                    unit.stats.defense = unit.originalDefense
                    unit.originalDefense = nil
                end
                
                -- Visual effect when removed
                if self.game.ui then
                    self.game.ui:showNotification(unit.unitType:upper() .. " is no longer burning", 1.5)
                end
            end
        },
        
        -- Poisoned: Deals increasing damage each turn
        poisoned = {
            name = "Poisoned",
            description = "Taking increasing damage each turn",
            icon = nil,
            duration = 4,
            triggerOn = "turnStart",
            stackable = true,
            stackLimit = 3,
            preventAction = false,
            visualEffect = "poison",
            category = "negative",
            onApply = function(unit)
                -- Initialize poison stack counter if not exists
                unit.poisonStacks = (unit.poisonStacks or 0) + 1
                unit.poisonStacks = math.min(unit.poisonStacks, 3)
                
                if self.game.ui then
                    self.game.ui:showNotification(unit.unitType:upper() .. " is poisoned! (" .. unit.poisonStacks .. " stacks)", 1.5)
                end
            end,
            onTrigger = function(unit)
                -- Deal damage based on stacks
                local damage = math.ceil(unit.stats.maxHealth * 0.05 * unit.poisonStacks)
                if self.game.combatSystem then
                    self.game.combatSystem:applyDirectDamage(unit, damage, {
                        source = "status",
                        effect = "poisoned",
                        isCritical = false,
                        isMiss = false
                    })
                else
                    unit.stats.health = math.max(0, unit.stats.health - damage)
                end
            end,
            onRemove = function(unit)
                -- Reset poison stacks
                unit.poisonStacks = nil
                
                if self.game.ui then
                    self.game.ui:showNotification(unit.unitType:upper() .. " is no longer poisoned", 1.5)
                end
            end
        },
        
        -- Bleeding: Deals damage when moving
        bleeding = {
            name = "Bleeding",
            description = "Takes damage when moving",
            icon = nil,
            duration = 3,
            triggerOn = "onMove",
            stackable = false,
            preventAction = false,
            visualEffect = "blood",
            category = "negative",
            onApply = function(unit)
                if self.game.ui then
                    self.game.ui:showNotification(unit.unitType:upper() .. " is bleeding!", 1.5)
                end
                
                -- Hook into unit's move function
                unit.originalMoveTo = unit.moveTo
                unit.moveTo = function(self, x, y)
                    -- Call original move function
                    local success = self.originalMoveTo(self, x, y)
                    
                    -- If move successful, trigger bleeding damage
                    if success and self.statusEffects and self.statusEffects.bleeding then
                        local damage = math.ceil(self.stats.maxHealth * 0.08)
                        if self.game.combatSystem then
                            self.game.combatSystem:applyDirectDamage(self, damage, {
                                source = "status",
                                effect = "bleeding",
                                isCritical = false,
                                isMiss = false
                            })
                        else
                            self.stats.health = math.max(0, self.stats.health - damage)
                        end
                        
                        if self.game.ui then
                            self.game.ui:showNotification("Bleeding: -" .. damage .. " HP", 1)
                        end
                    end
                    
                    return success
                end
            end,
            onTrigger = function(unit)
                -- Nothing to do here, triggered on move
            end,
            onRemove = function(unit)
                -- Restore original move function
                if unit.originalMoveTo then
                    unit.moveTo = unit.originalMoveTo
                    unit.originalMoveTo = nil
                end
                
                if self.game.ui then
                    self.game.ui:showNotification(unit.unitType:upper() .. " is no longer bleeding", 1.5)
                end
            end
        },
        
        -- MOVEMENT IMPAIRMENT EFFECTS
        
        -- Stunned: Cannot take actions
        stunned = {
            name = "Stunned",
            description = "Cannot take actions",
            icon = nil,
            duration = 1,
            triggerOn = "turnStart",
            stackable = false,
            preventAction = true,
            visualEffect = "stun",
            category = "negative",
            onApply = function(unit)
                if self.game.ui then
                    self.game.ui:showNotification(unit.unitType:upper() .. " is stunned!", 1.5)
                end
            end,
            onTrigger = function(unit)
                -- Already handled by turn manager's preventAction check
            end,
            onRemove = function(unit)
                if self.game.ui then
                    self.game.ui:showNotification(unit.unitType:upper() .. " is no longer stunned", 1.5)
                end
            end
        },
        
        -- Slowed: Movement range reduced
        slowed = {
            name = "Slowed",
            description = "Movement range reduced by 1",
            icon = nil,
            duration = 2,
            triggerOn = "turnStart",
            stackable = true,
            stackLimit = 3,
            preventAction = false,
            visualEffect = "slow",
            category = "negative",
            onApply = function(unit)
                -- Store original move range if not already stored
                if not unit.originalMoveRange then
                    unit.originalMoveRange = unit.stats.moveRange
                end
                
                -- Initialize slow stack counter if not exists
                unit.slowStacks = (unit.slowStacks or 0) + 1
                unit.slowStacks = math.min(unit.slowStacks, 3)
                
                -- Reduce move range based on stacks
                unit.stats.moveRange = math.max(1, unit.originalMoveRange - unit.slowStacks)
                
                if self.game.ui then
                    self.game.ui:showNotification(unit.unitType:upper() .. " is slowed! (" .. unit.slowStacks .. " stacks)", 1.5)
                end
            end,
            onTrigger = function(unit)
                -- Nothing to do on trigger
            end,
            onRemove = function(unit)
                -- Restore original move range
                if unit.originalMoveRange then
                    unit.stats.moveRange = unit.originalMoveRange
                    unit.originalMoveRange = nil
                end
                
                -- Reset slow stacks
                unit.slowStacks = nil
                
                if self.game.ui then
                    self.game.ui:showNotification(unit.unitType:upper() .. " is no longer slowed", 1.5)
                end
            end
        },
        
        -- Rooted: Cannot move
        rooted = {
            name = "Rooted",
            description = "Cannot move but can still attack",
            icon = nil,
            duration = 2,
            triggerOn = "turnStart",
            stackable = false,
            preventAction = false,
            visualEffect = "root",
            category = "negative",
            onApply = function(unit)
                -- Store original move range
                unit.originalMoveRange = unit.stats.moveRange
                -- Set move range to 0
                unit.stats.moveRange = 0
                
                if self.game.ui then
                    self.game.ui:showNotification(unit.unitType:upper() .. " is rooted!", 1.5)
                end
            end,
            onTrigger = function(unit)
                -- Nothing to do on trigger
            end,
            onRemove = function(unit)
                -- Restore original move range
                if unit.originalMoveRange then
                    unit.stats.moveRange = unit.originalMoveRange
                    unit.originalMoveRange = nil
                end
                
                if self.game.ui then
                    self.game.ui:showNotification(unit.unitType:upper() .. " is no longer rooted", 1.5)
                end
            end
        },
        
        -- Frozen: Cannot move or attack
        frozen = {
            name = "Frozen",
            description = "Cannot move or attack",
            icon = nil,
            duration = 2,
            triggerOn = "turnStart",
            stackable = false,
            preventAction = true,
            visualEffect = "ice",
            category = "negative",
            onApply = function(unit)
                -- Store original move range
                unit.originalMoveRange = unit.stats.moveRange
                -- Set move range to 0
                unit.stats.moveRange = 0
                
                -- Store original defense and increase it (frozen units are harder to damage)
                unit.originalDefense = unit.stats.defense
                unit.stats.defense = math.floor(unit.stats.defense * 1.5)
                
                if self.game.ui then
                    self.game.ui:showNotification(unit.unitType:upper() .. " is frozen!", 1.5)
                end
            end,
            onTrigger = function(unit)
                -- Nothing to do on trigger
            end,
            onRemove = function(unit)
                -- Restore original move range
                if unit.originalMoveRange then
                    unit.stats.moveRange = unit.originalMoveRange
                    unit.originalMoveRange = nil
                end
                
                -- Restore original defense
                if unit.originalDefense then
                    unit.stats.defense = unit.originalDefense
                    unit.originalDefense = nil
                end
                
                if self.game.ui then
                    self.game.ui:showNotification(unit.unitType:upper() .. " is no longer frozen", 1.5)
                end
            end
        },
        
        -- STAT MODIFICATION EFFECTS
        
        -- Weakened: Attack reduced
        weakened = {
            name = "Weakened",
            description = "Attack reduced by 50%",
            icon = nil,
            duration = 2,
            triggerOn = "turnStart",
            stackable = false,
            preventAction = false,
            visualEffect = "weak",
            category = "negative",
            onApply = function(unit)
                -- Store original attack value
                unit.originalAttack = unit.stats.attack
                -- Reduce attack
                unit.stats.attack = math.ceil(unit.stats.attack * 0.5)
                
                if self.game.ui then
                    self.game.ui:showNotification(unit.unitType:upper() .. " is weakened!", 1.5)
                end
            end,
            onTrigger = function(unit)
                -- Nothing to do on trigger
            end,
            onRemove = function(unit)
                -- Restore original attack
                if unit.originalAttack then
                    unit.stats.attack = unit.originalAttack
                    unit.originalAttack = nil
                end
                
                if self.game.ui then
                    self.game.ui:showNotification(unit.unitType:upper() .. " is no longer weakened", 1.5)
                end
            end
        },
        
        -- Vulnerable: Defense reduced
        vulnerable = {
            name = "Vulnerable",
            description = "Defense reduced by 50%",
            icon = nil,
            duration = 2,
            triggerOn = "turnStart",
            stackable = false,
            preventAction = false,
            visualEffect = "vulnerable",
            category = "negative",
            onApply = function(unit)
                -- Store original defense value
                unit.originalDefense = unit.stats.defense
                -- Reduce defense
                unit.stats.defense = math.ceil(unit.stats.defense * 0.5)
                
                if self.game.ui then
                    self.game.ui:showNotification(unit.unitType:upper() .. " is vulnerable!", 1.5)
                end
            end,
            onTrigger = function(unit)
                -- Nothing to do on trigger
            end,
            onRemove = function(unit)
                -- Restore original defense
                if unit.originalDefense then
                    unit.stats.defense = unit.originalDefense
                    unit.originalDefense = nil
                end
                
                if self.game.ui then
                    self.game.ui:showNotification(unit.unitType:upper() .. " is no longer vulnerable", 1.5)
                end
            end
        },
        
        -- Confused: Attacks random targets
        confused = {
            name = "Confused",
            description = "May attack random targets",
            icon = nil,
            duration = 2,
            triggerOn = "onAttack",
            stackable = false,
            preventAction = false,
            visualEffect = "confusion",
            category = "negative",
            onApply = function(unit)
                if self.game.ui then
                    self.game.ui:showNotification(unit.unitType:upper() .. " is confused!", 1.5)
                end
                
                -- Hook into unit's attack function
                unit.originalAttack = unit.attack
                unit.attack = function(self, target)
                    -- 50% chance to attack a random target instead
                    if math.random() < 0.5 then
                        -- Get all possible targets
                        local targets = {}
                        for entity, _ in pairs(self.game.grid.entities) do
                            if entity.faction and entity.faction ~= self.faction then
                                local distance = math.abs(self.x - entity.x) + math.abs(self.y - entity.y)
                                if distance <= self.stats.attackRange then
                                    table.insert(targets, entity)
                                end
                            end
                        end
                        
                        -- If there are targets, select a random one
                        if #targets > 0 then
                            local randomTarget = targets[math.random(#targets)]
                            
                            if self.game.ui then
                                self.game.ui:showNotification("Confused! Attacking random target", 1)
                            end
                            
                            return self.originalAttack(self, randomTarget)
                        end
                    end
                    
                    -- Otherwise, attack the original target
                    return self.originalAttack(self, target)
                end
            end,
            onTrigger = function(unit)
                -- Nothing to do here, triggered on attack
            end,
            onRemove = function(unit)
                -- Restore original attack function
                if unit.originalAttack then
                    unit.attack = unit.originalAttack
                    unit.originalAttack = nil
                end
                
                if self.game.ui then
                    self.game.ui:showNotification(unit.unitType:upper() .. " is no longer confused", 1.5)
                end
            end
        },
        
        -- POSITIVE EFFECTS
        
        -- Shielded: Damage taken reduced
        shielded = {
            name = "Shielded",
            description = "Damage taken reduced by 50%",
            icon = nil,
            duration = 2,
            triggerOn = "onDamage",
            stackable = false,
            preventAction = false,
            visualEffect = "shield",
            category = "positive",
            onApply = function(unit)
                if self.game.ui then
                    self.game.ui:showNotification(unit.unitType:upper() .. " is shielded!", 1.5)
                end
                
                -- Hook into damage calculation in combat system
                -- This is handled in the combat system's applyDamage function
            end,
            onTrigger = function(unit, damage)
                -- Return modified damage (50% reduction)
                return math.ceil(damage * 0.5)
            end,
            onRemove = function(unit)
                if self.game.ui then
                    self.game.ui:showNotification(unit.unitType:upper() .. " is no longer shielded", 1.5)
                end
            end
        },
        
        -- Regenerating: Recovering health each turn
        regenerating = {
            name = "Regenerating",
            description = "Recovering health each turn",
            icon = nil,
            duration = 3,
            triggerOn = "turnStart",
            stackable = false,
            preventAction = false,
            visualEffect = "heal",
            category = "positive",
            onApply = function(unit)
                if self.game.ui then
                    self.game.ui:showNotification(unit.unitType:upper() .. " is regenerating!", 1.5)
                end
            end,
            onTrigger = function(unit)
                -- Heal each turn
                local healAmount = math.ceil(unit.stats.maxHealth * 0.1)
                if self.game.combatSystem then
                    self.game.combatSystem:applyHealing(unit, healAmount, {
                        source = "status",
                        effect = "regenerating"
                    })
                else
                    unit.stats.health = math.min(unit.stats.maxHealth, unit.stats.health + healAmount)
                    if self.game.ui then
                        self.game.ui:showNotification("+" .. healAmount .. " HP", 1)
                    end
                end
            end,
            onRemove = function(unit)
                if self.game.ui then
                    self.game.ui:showNotification(unit.unitType:upper() .. " is no longer regenerating", 1.5)
                end
            end
        },
        
        -- Strengthened: Attack increased
        strengthened = {
            name = "Strengthened",
            description = "Attack increased by 50%",
            icon = nil,
            duration = 3,
            triggerOn = "turnStart",
            stackable = false,
            preventAction = false,
            visualEffect = "strength",
            category = "positive",
            onApply = function(unit)
                -- Store original attack value
                unit.originalAttack = unit.stats.attack
                -- Increase attack
                unit.stats.attack = math.ceil(unit.stats.attack * 1.5)
                
                if self.game.ui then
                    self.game.ui:showNotification(unit.unitType:upper() .. " is strengthened!", 1.5)
                end
            end,
            onTrigger = function(unit)
                -- Nothing to do on trigger
            end,
            onRemove = function(unit)
                -- Restore original attack
                if unit.originalAttack then
                    unit.stats.attack = unit.originalAttack
                    unit.originalAttack = nil
                end
                
                if self.game.ui then
                    self.game.ui:showNotification(unit.unitType:upper() .. " is no longer strengthened", 1.5)
                end
            end
        },
        
        -- Hastened: Movement range and initiative increased
        hastened = {
            name = "Hastened",
            description = "Movement range and initiative increased",
            icon = nil,
            duration = 3,
            triggerOn = "turnStart",
            stackable = false,
            preventAction = false,
            visualEffect = "haste",
            category = "positive",
            onApply = function(unit)
                -- Store original values
                unit.originalMoveRange = unit.stats.moveRange
                unit.originalInitiative = unit.stats.initiative
                
                -- Increase stats
                unit.stats.moveRange = unit.stats.moveRange + 2
                unit.stats.initiative = unit.stats.initiative + 3
                
                if self.game.ui then
                    self.game.ui:showNotification(unit.unitType:upper() .. " is hastened!", 1.5)
                end
            end,
            onTrigger = function(unit)
                -- Nothing to do on trigger
            end,
            onRemove = function(unit)
                -- Restore original values
                if unit.originalMoveRange then
                    unit.stats.moveRange = unit.originalMoveRange
                    unit.originalMoveRange = nil
                end
                
                if unit.originalInitiative then
                    unit.stats.initiative = unit.originalInitiative
                    unit.originalInitiative = nil
                end
                
                if self.game.ui then
                    self.game.ui:showNotification(unit.unitType:upper() .. " is no longer hastened", 1.5)
                end
            end
        },
        
        -- Invisible: Cannot be targeted by enemies
        invisible = {
            name = "Invisible",
            description = "Cannot be targeted by enemies",
            icon = nil,
            duration = 2,
            triggerOn = "onTargeted",
            stackable = false,
            preventAction = false,
            visualEffect = "invisibility",
            category = "positive",
            onApply = function(unit)
                unit.isInvisible = true
                
                if self.game.ui then
                    self.game.ui:showNotification(unit.unitType:upper() .. " is invisible!", 1.5)
                end
            end,
            onTrigger = function(unit, attacker)
                -- Return whether the unit can be targeted (false if attacker is enemy)
                return attacker.faction == unit.faction
            end,
            onRemove = function(unit)
                unit.isInvisible = nil
                
                if self.game.ui then
                    self.game.ui:showNotification(unit.unitType:upper() .. " is no longer invisible", 1.5)
                end
            end
        },
        
        -- SPECIAL EFFECTS
        
        -- Marked: Takes extra damage from attacks
        marked = {
            name = "Marked",
            description = "Takes 25% extra damage from attacks",
            icon = nil,
            duration = 2,
            triggerOn = "onDamage",
            stackable = false,
            preventAction = false,
            visualEffect = "mark",
            category = "negative",
            onApply = function(unit)
                if self.game.ui then
                    self.game.ui:showNotification(unit.unitType:upper() .. " is marked!", 1.5)
                end
            end,
            onTrigger = function(unit, damage)
                -- Return modified damage (25% increase)
                return math.ceil(damage * 1.25)
            end,
            onRemove = function(unit)
                if self.game.ui then
                    self.game.ui:showNotification(unit.unitType:upper() .. " is no longer marked", 1.5)
                end
            end
        },
        
        -- Taunted: Must attack the taunting unit
        taunted = {
            name = "Taunted",
            description = "Must attack the taunting unit",
            icon = nil,
            duration = 2,
            triggerOn = "onAttackSelect",
            stackable = false,
            preventAction = false,
            visualEffect = "taunt",
            category = "negative",
            onApply = function(unit, source)
                -- Store the source of the taunt
                unit.tauntSource = source
                
                if self.game.ui then
                    self.game.ui:showNotification(unit.unitType:upper() .. " is taunted!", 1.5)
                end
            end,
            onTrigger = function(unit, target)
                -- If target is not the taunt source, prevent the attack
                if unit.tauntSource and target ~= unit.tauntSource then
                    if self.game.ui then
                        self.game.ui:showNotification("Must attack the taunting unit!", 1)
                    end
                    return false
                end
                return true
            end,
            onRemove = function(unit)
                unit.tauntSource = nil
                
                if self.game.ui then
                    self.game.ui:showNotification(unit.unitType:upper() .. " is no longer taunted", 1.5)
                end
            end
        },
        
        -- Reflecting: Returns a portion of damage to attacker
        reflecting = {
            name = "Reflecting",
            description = "Returns 30% of damage to attacker",
            icon = nil,
            duration = 3,
            triggerOn = "onDamaged",
            stackable = false,
            preventAction = false,
            visualEffect = "reflect",
            category = "positive",
            onApply = function(unit)
                if self.game.ui then
                    self.game.ui:showNotification(unit.unitType:upper() .. " is reflecting damage!", 1.5)
                end
            end,
            onTrigger = function(unit, damage, attacker)
                -- Calculate reflect damage
                local reflectDamage = math.ceil(damage * 0.3)
                
                -- Apply damage to attacker
                if attacker and reflectDamage > 0 then
                    if self.game.combatSystem then
                        self.game.combatSystem:applyDirectDamage(attacker, reflectDamage, {
                            source = "status",
                            effect = "reflecting",
                            isCritical = false,
                            isMiss = false
                        })
                    else
                        attacker.stats.health = math.max(0, attacker.stats.health - reflectDamage)
                    end
                    
                    if self.game.ui then
                        self.game.ui:showNotification("Reflected: " .. reflectDamage .. " damage", 1)
                    end
                end
            end,
            onRemove = function(unit)
                if self.game.ui then
                    self.game.ui:showNotification(unit.unitType:upper() .. " is no longer reflecting damage", 1.5)
                end
            end
        },
        
        -- Berserk: Increased attack but decreased defense
        berserk = {
            name = "Berserk",
            description = "Attack doubled but defense halved",
            icon = nil,
            duration = 3,
            triggerOn = "turnStart",
            stackable = false,
            preventAction = false,
            visualEffect = "berserk",
            category = "mixed",
            onApply = function(unit)
                -- Store original values
                unit.originalAttack = unit.stats.attack
                unit.originalDefense = unit.stats.defense
                
                -- Modify stats
                unit.stats.attack = unit.stats.attack * 2
                unit.stats.defense = math.ceil(unit.stats.defense / 2)
                
                if self.game.ui then
                    self.game.ui:showNotification(unit.unitType:upper() .. " is berserk!", 1.5)
                end
            end,
            onTrigger = function(unit)
                -- Nothing to do on trigger
            end,
            onRemove = function(unit)
                -- Restore original values
                if unit.originalAttack then
                    unit.stats.attack = unit.originalAttack
                    unit.originalAttack = nil
                end
                
                if unit.originalDefense then
                    unit.stats.defense = unit.originalDefense
                    unit.originalDefense = nil
                end
                
                if self.game.ui then
                    self.game.ui:showNotification(unit.unitType:upper() .. " is no longer berserk", 1.5)
                end
            end
        }
    }
    
    -- Register status effects with turn manager
    if self.game.turnManager then
        for id, effect in pairs(self.statusEffects) do
            self.game.turnManager:registerStatusEffect(id, effect)
        end
    end
end

-- Apply a status effect to a unit
function StatusEffectsSystem:applyEffect(unit, effectType, source)
    -- If effectType is a string, get the effect from predefined effects
    local effect = effectType
    if type(effectType) == "string" then
        effect = self.statusEffects[effectType]
        if not effect then
            return false
        end
    end
    
    -- Initialize status effects table if needed
    if not unit.statusEffects then
        unit.statusEffects = {}
    end
    
    -- Check if effect is already applied and not stackable
    if not effect.stackable and unit.statusEffects[effect.name] then
        -- Refresh duration instead
        unit.statusEffects[effect.name].duration = effect.duration
        return true
    end
    
    -- Check stack limit for stackable effects
    if effect.stackable and effect.stackLimit and unit.statusEffects[effect.name] then
        local stackCount = 0
        for _, existingEffect in pairs(unit.statusEffects) do
            if existingEffect.name == effect.name then
                stackCount = stackCount + 1
            end
        end
        
        if stackCount >= effect.stackLimit then
            -- Refresh duration instead
            unit.statusEffects[effect.name].duration = effect.duration
            return true
        end
    end
    
    -- Clone the effect to avoid modifying the template
    local newEffect = {}
    for k, v in pairs(effect) do
        newEffect[k] = v
    end
    
    -- Apply the effect
    unit.statusEffects[effect.name] = newEffect
    
    -- Call onApply handler
    if newEffect.onApply then
        newEffect.onApply(unit, source)
    end
    
    -- Register with turn manager if needed
    if self.game.turnManager then
        self.game.turnManager:registerUnitStatusEffect(unit, effect.name, newEffect)
    end
    
    return true
end

-- Remove a status effect from a unit
function StatusEffectsSystem:removeEffect(unit, effectName)
    if not unit.statusEffects or not unit.statusEffects[effectName] then
        return false
    end
    
    local effect = unit.statusEffects[effectName]
    
    -- Call onRemove handler
    if effect.onRemove then
        effect.onRemove(unit)
    end
    
    -- Remove the effect
    unit.statusEffects[effectName] = nil
    
    return true
end

-- Check if a unit has a specific status effect
function StatusEffectsSystem:hasEffect(unit, effectName)
    return unit.statusEffects and unit.statusEffects[effectName] ~= nil
end

-- Get all status effects on a unit
function StatusEffectsSystem:getEffects(unit)
    if not unit.statusEffects then
        return {}
    end
    
    return unit.statusEffects
end

-- Get status effects by category
function StatusEffectsSystem:getEffectsByCategory(unit, category)
    if not unit.statusEffects then
        return {}
    end
    
    local effects = {}
    for name, effect in pairs(unit.statusEffects) do
        if effect.category == category then
            effects[name] = effect
        end
    end
    
    return effects
end

-- Clear all status effects from a unit
function StatusEffectsSystem:clearAllEffects(unit)
    if not unit.statusEffects then
        return
    end
    
    for name, effect in pairs(unit.statusEffects) do
        if effect.onRemove then
            effect.onRemove(unit)
        end
    end
    
    unit.statusEffects = {}
end

-- Clear status effects by category
function StatusEffectsSystem:clearEffectsByCategory(unit, category)
    if not unit.statusEffects then
        return
    end
    
    local effectsToRemove = {}
    for name, effect in pairs(unit.statusEffects) do
        if effect.category == category then
            table.insert(effectsToRemove, name)
        end
    end
    
    for _, name in ipairs(effectsToRemove) do
        self:removeEffect(unit, name)
    end
end

-- Apply a random status effect based on unit type
function StatusEffectsSystem:applyRandomEffect(unit, targetUnit, isPositive)
    local possibleEffects = {}
    
    if isPositive then
        -- Positive effects
        table.insert(possibleEffects, "shielded")
        table.insert(possibleEffects, "regenerating")
        table.insert(possibleEffects, "strengthened")
        table.insert(possibleEffects, "hastened")
        
        -- Special positive effects based on unit type
        if unit.unitType == "king" then
            table.insert(possibleEffects, "reflecting")
        elseif unit.unitType == "queen" then
            table.insert(possibleEffects, "invisible")
        elseif unit.unitType == "rook" then
            table.insert(possibleEffects, "berserk")
        end
    else
        -- Negative effects
        table.insert(possibleEffects, "weakened")
        table.insert(possibleEffects, "vulnerable")
        table.insert(possibleEffects, "slowed")
        
        -- Special negative effects based on unit type
        if unit.unitType == "king" then
            table.insert(possibleEffects, "taunted")
        elseif unit.unitType == "queen" then
            table.insert(possibleEffects, "burning")
        elseif unit.unitType == "rook" then
            table.insert(possibleEffects, "stunned")
        elseif unit.unitType == "bishop" then
            table.insert(possibleEffects, "poisoned")
        elseif unit.unitType == "knight" then
            table.insert(possibleEffects, "confused")
        elseif unit.unitType == "pawn" then
            table.insert(possibleEffects, "marked")
        end
    end
    
    -- Select random effect
    if #possibleEffects > 0 then
        local effect = possibleEffects[math.random(#possibleEffects)]
        return self:applyEffect(targetUnit, effect, unit)
    end
    
    return false
end

-- Process status effect triggers
function StatusEffectsSystem:processTrigger(unit, triggerType, ...)
    if not unit.statusEffects then
        return
    end
    
    for name, effect in pairs(unit.statusEffects) do
        if effect.triggerOn == triggerType and effect.onTrigger then
            effect.onTrigger(unit, ...)
        end
    end
end

-- Update visual effects for status effects
function StatusEffectsSystem:updateVisualEffects(dt)
    -- This would update any visual effects associated with status effects
    -- Implementation would depend on the game's rendering system
end

-- Get a status effect definition
function StatusEffectsSystem:getEffectDefinition(effectName)
    return self.statusEffects[effectName]
end

-- Get all status effect definitions
function StatusEffectsSystem:getAllEffectDefinitions()
    return self.statusEffects
end

return StatusEffectsSystem
