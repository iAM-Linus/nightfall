-- Combat System for Nightfall Chess
-- Handles damage calculation, combat effects, and battle mechanics

local class = require("lib.middleclass.middleclass")
local timer = require("lib.hump.timer")

local CombatSystem = class("CombatSystem")

function CombatSystem:initialize(game)
    self.game = game
    
    -- Combat configuration
    self.config = {
        baseDamageMultiplier = 1.0,
        criticalHitChance = 0.1,
        criticalHitMultiplier = 1.5,
        missChance = 0.05,
        counterAttackChance = 0.3,
        statusEffectChance = 0.2,
        damageRandomness = 0.2, -- +/- 20% damage randomness
        chessPieceAdvantages = {
            -- Attacker vs Defender advantage multipliers
            -- Based on chess piece matchups
            king = {
                king = 1.0, queen = 0.5, rook = 0.6, bishop = 0.7, knight = 0.7, pawn = 1.2
            },
            queen = {
                king = 1.5, queen = 1.0, rook = 1.2, bishop = 1.2, knight = 1.2, pawn = 1.5
            },
            rook = {
                king = 1.3, queen = 0.8, rook = 1.0, bishop = 1.1, knight = 1.1, pawn = 1.3
            },
            bishop = {
                king = 1.2, queen = 0.8, rook = 0.9, bishop = 1.0, knight = 1.0, pawn = 1.2
            },
            knight = {
                king = 1.2, queen = 0.8, rook = 0.9, bishop = 1.0, knight = 1.0, pawn = 1.2
            },
            pawn = {
                king = 0.7, queen = 0.5, rook = 0.7, bishop = 0.8, knight = 0.8, pawn = 1.0
            }
        }
    }
    
    -- Combat log
    self.combatLog = {}
    self.maxLogEntries = 50
    
    -- Special attack definitions
    self.specialAttacks = {
        -- King's special attack
        royalDecree = {
            name = "Royal Decree",
            description = "Stuns all adjacent enemies",
            cooldown = 3,
            actionPointCost = 2,
            range = 1,
            targetType = "area",
            onUse = function(unit, targetX, targetY)
                -- Get all adjacent enemies
                local targets = {}
                for dx = -1, 1 do
                    for dy = -1, 1 do
                        if dx ~= 0 or dy ~= 0 then
                            local x, y = unit.x + dx, unit.y + dy
                            local targetUnit = self.game.grid:getEntityAt(x, y)
                            
                            if targetUnit and targetUnit.faction ~= unit.faction then
                                table.insert(targets, targetUnit)
                            end
                        end
                    end
                end
                
                -- Apply stun to all targets
                for _, target in ipairs(targets) do
                    self:applyStatusEffect(target, "stunned")
                end
                
                -- Log the attack
                self:addToCombatLog(unit.unitType:upper() .. " used Royal Decree!")
                
                -- Show notification
                if self.game.ui then
                    self.game.ui:showNotification(unit.unitType:upper() .. " used Royal Decree!", 2)
                end
                
                -- Use action points
                if self.game.turnManager then
                    self.game.turnManager:useActionPoints(2)
                end
                
                -- Set cooldown
                unit.specialAttackCooldown = 3
                
                return true
            end
        },
        
        -- Queen's special attack
        royalWrath = {
            name = "Royal Wrath",
            description = "Powerful attack that hits in all directions",
            cooldown = 3,
            actionPointCost = 2,
            range = 2,
            targetType = "area",
            onUse = function(unit, targetX, targetY)
                -- Get all units in range
                local targets = {}
                for dx = -2, 2 do
                    for dy = -2, 2 do
                        if dx ~= 0 or dy ~= 0 then
                            local x, y = unit.x + dx, unit.y + dy
                            local targetUnit = self.game.grid:getEntityAt(x, y)
                            
                            if targetUnit and targetUnit.faction ~= unit.faction then
                                table.insert(targets, targetUnit)
                            end
                        end
                    end
                end
                
                -- Apply damage to all targets
                for _, target in ipairs(targets) do
                    local damage = unit.stats.attack * 1.5
                    self:applyDamage(unit, target, damage, {
                        source = "special",
                        attackName = "Royal Wrath",
                        isCritical = false,
                        isMiss = false
                    })
                end
                
                -- Log the attack
                self:addToCombatLog(unit.unitType:upper() .. " used Royal Wrath!")
                
                -- Show notification
                if self.game.ui then
                    self.game.ui:showNotification(unit.unitType:upper() .. " used Royal Wrath!", 2)
                end
                
                -- Use action points
                if self.game.turnManager then
                    self.game.turnManager:useActionPoints(2)
                end
                
                -- Set cooldown
                unit.specialAttackCooldown = 3
                
                return true
            end
        },
        
        -- Rook's special attack
        castleRush = {
            name = "Castle Rush",
            description = "Charge attack that pushes enemies back",
            cooldown = 2,
            actionPointCost = 2,
            range = 3,
            targetType = "line",
            onUse = function(unit, targetX, targetY)
                -- Determine direction
                local dx = targetX - unit.x
                local dy = targetY - unit.y
                
                if dx ~= 0 then dx = dx / math.abs(dx) end
                if dy ~= 0 then dy = dy / math.abs(dy) end
                
                -- Check all units in the line
                local targets = {}
                for i = 1, 3 do
                    local x, y = unit.x + dx * i, unit.y + dy * i
                    local targetUnit = self.game.grid:getEntityAt(x, y)
                    
                    if targetUnit then
                        if targetUnit.faction ~= unit.faction then
                            table.insert(targets, {unit = targetUnit, distance = i})
                        end
                        break -- Stop at first unit hit
                    end
                end
                
                -- Apply damage and push back
                for _, target in ipairs(targets) do
                    local damage = unit.stats.attack * (1 + target.distance * 0.2)
                    self:applyDamage(unit, target.unit, damage, {
                        source = "special",
                        attackName = "Castle Rush",
                        isCritical = false,
                        isMiss = false
                    })
                    
                    -- Push target back
                    local pushX = target.unit.x + dx
                    local pushY = target.unit.y + dy
                    
                    if self.game.grid:isWalkable(pushX, pushY) then
                        target.unit.x = pushX
                        target.unit.y = pushY
                    end
                end
                
                -- Log the attack
                self:addToCombatLog(unit.unitType:upper() .. " used Castle Rush!")
                
                -- Show notification
                if self.game.ui then
                    self.game.ui:showNotification(unit.unitType:upper() .. " used Castle Rush!", 2)
                end
                
                -- Use action points
                if self.game.turnManager then
                    self.game.turnManager:useActionPoints(2)
                end
                
                -- Set cooldown
                unit.specialAttackCooldown = 2
                
                return true
            end
        },
        
        -- Bishop's special attack
        divineBlessing = {
            name = "Divine Blessing",
            description = "Heals allies and applies regeneration",
            cooldown = 3,
            actionPointCost = 2,
            range = 2,
            targetType = "area",
            onUse = function(unit, targetX, targetY)
                -- Get all allies in range
                local targets = {}
                for dx = -2, 2 do
                    for dy = -2, 2 do
                        local x, y = unit.x + dx, unit.y + dy
                        local targetUnit = self.game.grid:getEntityAt(x, y)
                        
                        if targetUnit and targetUnit.faction == unit.faction then
                            table.insert(targets, targetUnit)
                        end
                    end
                end
                
                -- Apply healing to all targets
                for _, target in ipairs(targets) do
                    local healAmount = unit.stats.attack * 1.2
                    self:applyHealing(target, healAmount, {
                        source = "special",
                        attackName = "Divine Blessing"
                    })
                    
                    -- Apply regeneration
                    self:applyStatusEffect(target, "regenerating")
                end
                
                -- Log the attack
                self:addToCombatLog(unit.unitType:upper() .. " used Divine Blessing!")
                
                -- Show notification
                if self.game.ui then
                    self.game.ui:showNotification(unit.unitType:upper() .. " used Divine Blessing!", 2)
                end
                
                -- Use action points
                if self.game.turnManager then
                    self.game.turnManager:useActionPoints(2)
                end
                
                -- Set cooldown
                unit.specialAttackCooldown = 3
                
                return true
            end
        },
        
        -- Knight's special attack
        knightsTrick = {
            name = "Knight's Trick",
            description = "Teleport behind enemy and attack with bonus damage",
            cooldown = 2,
            actionPointCost = 2,
            range = 3,
            targetType = "unit",
            onUse = function(unit, targetX, targetY)
                local targetUnit = self.game.grid:getEntityAt(targetX, targetY)
                
                if not targetUnit or targetUnit.faction == unit.faction then
                    return false
                end
                
                -- Determine position behind target
                local dx = targetUnit.x - unit.x
                local dy = targetUnit.y - unit.y
                
                if dx ~= 0 then dx = dx / math.abs(dx) end
                if dy ~= 0 then dy = dy / math.abs(dy) end
                
                local behindX = targetUnit.x + dx
                local behindY = targetUnit.y + dy
                
                -- Check if position is valid
                if not self.game.grid:isWalkable(behindX, behindY) then
                    -- Find alternative position
                    local positions = {
                        {x = targetUnit.x + 1, y = targetUnit.y},
                        {x = targetUnit.x - 1, y = targetUnit.y},
                        {x = targetUnit.x, y = targetUnit.y + 1},
                        {x = targetUnit.x, y = targetUnit.y - 1}
                    }
                    
                    local validPosition = nil
                    for _, pos in ipairs(positions) do
                        if self.game.grid:isWalkable(pos.x, pos.y) then
                            validPosition = pos
                            break
                        end
                    end
                    
                    if validPosition then
                        behindX = validPosition.x
                        behindY = validPosition.y
                    else
                        return false
                    end
                end
                
                -- Teleport
                unit.x = behindX
                unit.y = behindY
                
                -- Apply damage with bonus
                local damage = unit.stats.attack * 2
                self:applyDamage(unit, targetUnit, damage, {
                    source = "special",
                    attackName = "Knight's Trick",
                    isCritical = true,
                    isMiss = false
                })
                
                -- Log the attack
                self:addToCombatLog(unit.unitType:upper() .. " used Knight's Trick!")
                
                -- Show notification
                if self.game.ui then
                    self.game.ui:showNotification(unit.unitType:upper() .. " used Knight's Trick!", 2)
                end
                
                -- Use action points
                if self.game.turnManager then
                    self.game.turnManager:useActionPoints(2)
                end
                
                -- Set cooldown
                unit.specialAttackCooldown = 2
                
                return true
            end
        },
        
        -- Pawn's special attack
        promotion = {
            name = "Promotion",
            description = "Temporarily gain abilities of a stronger piece",
            cooldown = 4,
            actionPointCost = 3,
            range = 0,
            targetType = "self",
            onUse = function(unit, targetX, targetY)
                -- Store original stats
                unit.originalStats = {
                    attack = unit.stats.attack,
                    defense = unit.stats.defense,
                    moveRange = unit.stats.moveRange
                }
                
                -- Enhance stats
                unit.stats.attack = unit.stats.attack * 2
                unit.stats.defense = unit.stats.defense * 1.5
                unit.stats.moveRange = unit.stats.moveRange + 1
                
                -- Apply status effect to track duration
                self:applyStatusEffect(unit, {
                    name = "Promoted",
                    description = "Enhanced with abilities of a stronger piece",
                    icon = nil,
                    duration = 3,
                    triggerOn = "turnStart",
                    stackable = false,
                    preventAction = false,
                    onApply = function(unit)
                        if self.game.ui then
                            self.game.ui:showNotification(unit.unitType:upper() .. " has been promoted!", 2)
                        end
                    end,
                    onTrigger = function(unit)
                        -- Nothing to do on trigger
                    end,
                    onRemove = function(unit)
                        -- Restore original stats
                        if unit.originalStats then
                            unit.stats.attack = unit.originalStats.attack
                            unit.stats.defense = unit.originalStats.defense
                            unit.stats.moveRange = unit.originalStats.moveRange
                            unit.originalStats = nil
                        end
                        
                        if self.game.ui then
                            self.game.ui:showNotification(unit.unitType:upper() .. " is no longer promoted", 1.5)
                        end
                    end
                })
                
                -- Log the attack
                self:addToCombatLog(unit.unitType:upper() .. " used Promotion!")
                
                -- Show notification
                if self.game.ui then
                    self.game.ui:showNotification(unit.unitType:upper() .. " used Promotion!", 2)
                end
                
                -- Use action points
                if self.game.turnManager then
                    self.game.turnManager:useActionPoints(3)
                end
                
                -- Set cooldown
                unit.specialAttackCooldown = 4
                
                return true
            end
        }
    }

    -- Ensure access to the StatusEffectsSystem
    if not self.game.statusEffectsSystem then
        print("WARNING: CombatSystem requires game.statusEffectsSystem")
        -- Optionally, load it here if not guaranteed to be present
        self.game.statusEffectsSystem = require("src.systems.status_effects_system"):new(game)
    end
end

-- Process an attack between two units
function CombatSystem:processAttack(attacker, defender)
    -- Check if units are valid
    if not attacker or not defender then
        return false
    end
    
    -- Check if attacker has already attacked
    if attacker.hasAttacked then
        return false
    end
    
    -- Check if defender is in range
    local distance = math.abs(attacker.x - defender.x) + math.abs(attacker.y - defender.y)
    if distance > attacker.stats.attackRange then
        return false
    end
    
    -- Check if attacker and defender are on different teams
    if attacker.faction == defender.faction then
        return false
    end
    
    -- Mark attacker as having attacked
    attacker.hasAttacked = true
    
    -- Use action points if it's a player turn
    if self.game.turnManager and self.game.turnManager:isPlayerTurn() then
        self.game.turnManager:useActionPoints(1)
    end
    
    -- Calculate damage
    local damage = self:calculateDamage(attacker, defender)
    
    -- Check for miss
    local isMiss = math.random() < self.config.missChance
    
    -- Check for critical hit
    local isCritical = not isMiss and math.random() < self.config.criticalHitChance
    
    -- Apply critical hit multiplier
    if isCritical then
        damage = damage * self.config.criticalHitMultiplier
    end
    
    -- Apply damage
    if not isMiss then
        self:applyDamage(attacker, defender, damage, {
            source = "attack",
            isCritical = isCritical,
            isMiss = isMiss
        })
    else
        -- Log miss
        self:addToCombatLog(attacker.unitType:upper() .. " missed " .. defender.unitType:upper() .. "!")
        
        -- Show miss notification
        if self.game.ui then
            self.game.ui:showNotification("MISS!", 1)
        end
    end
    
    -- Check for counter attack
    if not isMiss and not defender.hasCounterAttacked and math.random() < self.config.counterAttackChance then
        -- Check if defender is still alive
        if defender.stats.health > 0 then
            -- Mark defender as having counter attacked
            defender.hasCounterAttacked = true
            
            -- Calculate counter attack damage (reduced)
            local counterDamage = self:calculateDamage(defender, attacker) * 0.7
            
            -- Apply counter attack damage
            self:applyDamage(defender, attacker, counterDamage, {
                source = "counterAttack",
                isCritical = false,
                isMiss = false
            })
        end
    end
    
    -- Check for status effect application
    if not isMiss and math.random() < self.config.statusEffectChance then
        self:tryApplyRandomStatusEffect(attacker, defender)
    end
    
    return true
end

-- Calculate base damage between two units
function CombatSystem:calculateDamage(attacker, defender)
    -- Base damage from attacker's attack stat
    local damage = attacker.stats.attack
    
    -- Apply defender's defense
    damage = damage * (1 - (defender.stats.defense / (defender.stats.defense + 20)))
    
    -- Apply chess piece advantage multiplier
    local advantageMultiplier = 1.0
    if self.config.chessPieceAdvantages[attacker.unitType] and 
       self.config.chessPieceAdvantages[attacker.unitType][defender.unitType] then
        advantageMultiplier = self.config.chessPieceAdvantages[attacker.unitType][defender.unitType]
    end
    
    damage = damage * advantageMultiplier
    
    -- Apply randomness
    local randomFactor = 1 - self.config.damageRandomness + math.random() * self.config.damageRandomness * 2
    damage = damage * randomFactor
    
    -- Apply global damage multiplier
    damage = damage * self.config.baseDamageMultiplier
    
    -- Round to integer
    return math.max(1, math.floor(damage))
end

-- Apply damage to a unit
function CombatSystem:applyDamage(attacker, defender, damage, options)
    options = options or {}
    
    -- Check for shielded status effect
    if defender.statusEffects and defender.statusEffects.shielded then
        damage = damage * 0.5
    end
    
    -- Apply damage
    self:applyDirectDamage(defender, damage, options)
    
    -- Log the attack
    local attackType = options.source or "attack"
    local attackName = options.attackName or "attack"
    
    if attackType == "counterAttack" then
        self:addToCombatLog(defender.unitType:upper() .. " counter-attacked for " .. damage .. " damage!")
    elseif attackType == "special" then
        self:addToCombatLog(attacker.unitType:upper() .. " used " .. attackName .. " for " .. damage .. " damage!")
    else
        if options.isCritical then
            self:addToCombatLog(attacker.unitType:upper() .. " critically hit " .. defender.unitType:upper() .. " for " .. damage .. " damage!")
        else
            self:addToCombatLog(attacker.unitType:upper() .. " attacked " .. defender.unitType:upper() .. " for " .. damage .. " damage!")
        end
    end
    
    -- Show damage notification
    if self.game.ui then
        local text = damage
        if options.isCritical then
            text = "CRIT! " .. text
        end
        self.game.ui:showNotification(text, 1)
    end
    
    -- Check for defeat
    if defender.stats.health <= 0 then
        self:handleUnitDefeat(attacker, defender)
    end
end

-- Apply direct damage to a unit (without attacker)
function CombatSystem:applyDirectDamage(unit, damage, options)
    options = options or {}
    
    -- Apply damage
    unit.stats.health = math.max(0, unit.stats.health - damage)
    
    -- Log the damage
    if options.source == "status" then
        self:addToCombatLog(unit.unitType:upper() .. " took " .. damage .. " damage from " .. (options.effect or "status effect") .. "!")
    elseif options.source ~= "attack" and options.source ~= "counterAttack" and options.source ~= "special" then
        self:addToCombatLog(unit.unitType:upper() .. " took " .. damage .. " damage!")
    end
    
    -- Check for defeat
    if unit.stats.health <= 0 and not options.skipDefeatCheck then
        self:handleUnitDefeat(nil, unit)
    end
end

-- Apply healing to a unit
function CombatSystem:applyHealing(unit, amount, options)
    options = options or {}
    
    -- Calculate actual healing (can't exceed max health)
    local actualHealing = math.min(amount, unit.stats.maxHealth - unit.stats.health)
    
    -- Apply healing
    unit.stats.health = math.min(unit.stats.maxHealth, unit.stats.health + actualHealing)
    
    -- Log the healing
    if options.source == "special" then
        self:addToCombatLog(unit.unitType:upper() .. " healed for " .. actualHealing .. " from " .. (options.attackName or "special ability") .. "!")
    elseif options.source == "status" then
        self:addToCombatLog(unit.unitType:upper() .. " healed for " .. actualHealing .. " from " .. (options.effect or "status effect") .. "!")
    else
        self:addToCombatLog(unit.unitType:upper() .. " healed for " .. actualHealing .. "!")
    end
    
    -- Show healing notification
    if self.game.ui and actualHealing > 0 then
        self.game.ui:showNotification("+" .. actualHealing .. " HP", 1)
    end
end

-- Handle unit defeat
function CombatSystem:handleUnitDefeat(attacker, defender)
    -- Log the defeat
    if attacker then
        self:addToCombatLog(attacker.unitType:upper() .. " defeated " .. defender.unitType:upper() .. "!")
    else
        self:addToCombatLog(defender.unitType:upper() .. " was defeated!")
    end
    
    -- Show defeat notification
    if self.game.ui then
        self.game.ui:showNotification(defender.unitType:upper() .. " defeated!", 2)
    end
    
    -- Check for game over condition
    if defender.unitType == "king" then
        if defender.faction == "player" then
            -- Player king defeated - game over
            if self.game.turnManager then
                self.game.turnManager:setGameOver("enemy")
            end
        else
            -- Enemy king defeated - victory
            if self.game.turnManager then
                self.game.turnManager:setGameOver("player")
            end
        end
    end
    
    -- Award experience to attacker
    if attacker and attacker.addExperience then
        local expGain = 0
        
        -- Experience based on unit type
        local expValues = {
            pawn = 10,
            knight = 20,
            bishop = 20,
            rook = 30,
            queen = 50,
            king = 100
        }
        
        expGain = expValues[defender.unitType] or 10
        
        -- Apply experience
        attacker:addExperience(expGain)
    end

    -- Remove unit using game
    --self.game:defeatUnit(defender)
end

-- Apply a status effect to a unit (Uses StatusEffectsSystem)
function CombatSystem:applyStatusEffect(unit, effectType)
    if self.game.statusEffectsSystem then
        return self.game.statusEffectsSystem:applyEffect(unit, effectType, unit) -- Pass source
    else
        print("ERROR: StatusEffectsSystem not available in CombatSystem")
        return false
    end
end

-- Try to apply a random status effect (Uses StatusEffectsSystem)
function CombatSystem:tryApplyRandomStatusEffect(attacker, defender)
    if self.game.statusEffectsSystem then
        -- Let StatusEffectsSystem handle the logic
        return self.game.statusEffectsSystem:applyRandomNegativeEffect(defender, attacker)
    else
        print("ERROR: StatusEffectsSystem not available in CombatSystem")
        return false
    end
end

-- Use a special attack
function CombatSystem:useSpecialAttack(unit, attackName, targetX, targetY)
    -- Check if unit has the special attack
    local specialAttack = nil
    
    -- Get special attack based on unit type if not specified
    if not attackName then
        if unit.unitType == "king" then
            specialAttack = self.specialAttacks.royalDecree
        elseif unit.unitType == "queen" then
            specialAttack = self.specialAttacks.royalWrath
        elseif unit.unitType == "rook" then
            specialAttack = self.specialAttacks.castleRush
        elseif unit.unitType == "bishop" then
            specialAttack = self.specialAttacks.divineBlessing
        elseif unit.unitType == "knight" then
            specialAttack = self.specialAttacks.knightsTrick
        elseif unit.unitType == "pawn" then
            specialAttack = self.specialAttacks.promotion
        end
    else
        specialAttack = self.specialAttacks[attackName]
    end
    
    if not specialAttack then
        return false
    end
    
    -- Check cooldown
    if unit.specialAttackCooldown and unit.specialAttackCooldown > 0 then
        return false
    end
    
    -- Check action points
    if self.game.turnManager and self.game.turnManager:isPlayerTurn() then
        if self.game.turnManager.currentActionPoints < specialAttack.actionPointCost then
            return false
        end
    end
    
    -- Use the special attack
    return specialAttack.onUse(unit, targetX, targetY)
end

-- Add entry to combat log
function CombatSystem:addToCombatLog(text)
    -- Add timestamp
    local entry = {
        text = text,
        turn = self.game.turnManager and self.game.turnManager.turnNumber or 0,
        round = self.game.turnManager and self.game.turnManager.roundNumber or 0,
        timestamp = os.time()
    }
    
    -- Add to log
    table.insert(self.combatLog, entry)
    
    -- Trim log if too long
    if #self.combatLog > self.maxLogEntries then
        table.remove(self.combatLog, 1)
    end
    
    -- Print to console for debugging
    print("[Combat] " .. text)
end

-- Get recent combat log entries
function CombatSystem:getRecentLogEntries(count)
    count = count or 5
    local entries = {}
    
    for i = math.max(1, #self.combatLog - count + 1), #self.combatLog do
        table.insert(entries, self.combatLog[i])
    end
    
    return entries
end

-- Clear combat log
function CombatSystem:clearCombatLog()
    self.combatLog = {}
end

-- Get status effect by name
function CombatSystem:getStatusEffect(name)
    return self.statusEffects[name]
end

-- Get special attack by name
function CombatSystem:getSpecialAttack(name)
    return self.specialAttacks[name]
end

-- Update combat system
function CombatSystem:update(dt)
    -- Update animations or other time-based effects
end

return CombatSystem
