-- Special Abilities System for Nightfall Chess
-- Handles creation, management, and execution of special abilities for units

local class = require("lib.middleclass.middleclass")
local timer = require("lib.hump.timer")

local SpecialAbilitiesSystem = class("SpecialAbilitiesSystem")

function SpecialAbilitiesSystem:initialize(game)
    self.game = game
    
    -- Special ability definitions
    self.abilities = {
        -- KNIGHT ABILITIES
        
        -- Knight's Charge: Dash to a location and damage enemies in path
        knights_charge = {
            id = "knights_charge",
            name = "Knight's Charge",
            description = "Dash to a location and damage enemies in path",
            icon = nil, -- Would be an image in a full implementation
            energyCost = 4,
            actionPointCost = 1,
            cooldown = 3,
            targetType = "position",
            range = 4,
            unitType = "knight",
            onUse = function(caster, target, x, y, grid)
                -- Check if target position is valid
                if not x or not y or not grid:isInBounds(x, y) then
                    return false
                end
                
                -- Check if position is reachable
                local distance = math.abs(caster.x - x) + math.abs(caster.y - y)
                if distance > 4 then
                    return false
                end
                
                -- Create a simple line path instead of using getLinePath
                local path = {}
                local dx = x - caster.x
                local dy = y - caster.y
                
                -- Create normalized direction
                if dx ~= 0 then dx = dx / math.abs(dx) end
                if dy ~= 0 then dy = dy / math.abs(dy) end
                
                -- Create path points
                local currentX, currentY = caster.x, caster.y
                while currentX ~= x or currentY ~= y do
                    currentX = currentX + dx
                    currentY = currentY + dy
                    table.insert(path, {x = currentX, y = currentY})
                    
                    -- Safety to prevent infinite loops
                    if #path > 20 then break end
                end
                
                -- Get hit units
                local hitUnits = {}
                for _, pos in ipairs(path) do
                    local entity = grid:getEntityAt(pos.x, pos.y)
                    if entity and entity ~= caster and entity.faction ~= caster.faction then
                        table.insert(hitUnits, entity)
                    end
                end
                
                -- Move user to target position
                grid:removeEntity(caster)
                caster.x = x
                caster.y = y
                grid:placeEntity(caster, x, y)
                
                -- Deal damage to hit units
                for _, hitUnit in ipairs(hitUnits) do
                    local damage = math.ceil(caster.stats.attack * 0.8)
                    hitUnit.stats.health = math.max(0, hitUnit.stats.health - damage)
                    print(hitUnit.unitType .. " took " .. damage .. " damage from Knight's Charge")
                end
                
                -- Visual feedback
                print(caster.unitType:upper() .. " used Knight's Charge!")
                
                return true
            end
        },
        
        -- Feint: Reduce damage taken and counter next attack
        feint = {
            id = "feint",
            name = "Feint",
            description = "Reduce damage taken and counter next attack",
            icon = nil,
            energyCost = 3,
            actionPointCost = 1,
            cooldown = 2,
            targetType = "self",
            range = 0,
            unitType = "knight",
            onUse = function(user, target, x, y)
                -- Apply counter status
                if self.game.statusEffectsSystem then
                    -- Apply shielded effect
                    self.game.statusEffectsSystem:applyEffect(user, "shielded", user)
                    
                    -- Apply custom counter effect
                    user.counterNextAttack = true
                    
                    -- Set up counter removal after turn
                    timer.after(1, function()
                        user.counterNextAttack = false
                    end)
                end
                
                -- Visual feedback
                print(user.unitType:upper() .. " used Feint!")
                
                return true
            end
        },
        
        -- Flanking Maneuver: Move to opposite side of target and attack with bonus damage
        flanking_maneuver = {
            id = "flanking_maneuver",
            name = "Flanking Maneuver",
            description = "Move to opposite side of target and attack with bonus damage",
            icon = nil,
            energyCost = 5,
            actionPointCost = 1,
            cooldown = 3,
            targetType = "enemy",
            range = 3,
            unitType = "knight",
            onUse = function(user, target, x, y)
                if not target or target.faction == user.faction then
                    return false
                end
                
                -- Calculate opposite position
                local dx = target.x - user.x
                local dy = target.y - user.y
                local oppositeX = target.x + dx
                local oppositeY = target.y + dy
                
                -- Check if opposite position is valid
                if not user.grid:isInBounds(oppositeX, oppositeY) then
                    return false
                end
                
                -- Check if opposite position is empty
                if user.grid:getEntityAt(oppositeX, oppositeY) then
                    return false
                end
                
                -- Move user to opposite position
                user.grid:removeEntity(user.x, user.y)
                user.x = oppositeX
                user.y = oppositeY
                user.grid:placeEntity(user, oppositeX, oppositeY)
                
                -- Attack target with bonus damage
                local damage = math.ceil(user.stats.attack * 1.5)
                
                if self.game.combatSystem then
                    self.game.combatSystem:applyDirectDamage(target, damage, {
                        source = "ability",
                        ability = "flanking_maneuver",
                        user = user,
                        isCritical = true,
                        isMiss = false
                    })
                else
                    target:takeDamage(damage, user)
                end
                
                -- Visual feedback
                print(user.unitType:upper() .. " used Flanking Maneuver!")
                
                return true
            end
        },
        
        -- ROOK ABILITIES
        
        -- Fortify: Increase defense and become immovable
        fortify = {
            id = "fortify",
            name = "Fortify",
            description = "Increase defense and become immovable",
            icon = nil,
            energyCost = 3,
            actionPointCost = 1,
            cooldown = 2,
            targetType = "self",
            range = 0,
            unitType = "rook",
            onUse = function(user, target, x, y)
                -- Store original defense
                user.originalDefense = user.stats.defense
                
                -- Increase defense
                user.stats.defense = user.stats.defense * 2
                
                -- Apply immovable status
                user.isImmovable = true
                
                -- Set up effect removal after 2 turns
                timer.after(2, function()
                    -- Restore original defense
                    if user.originalDefense then
                        user.stats.defense = user.originalDefense
                        user.originalDefense = nil
                    end
                    
                    -- Remove immovable status
                    user.isImmovable = false
                    
                    print(user.unitType:upper() .. " is no longer fortified")
                end)
                
                -- Visual feedback
                print(user.unitType:upper() .. " used Fortify!")
                
                return true
            end
        },
        
        -- Shockwave: Damage and push back all adjacent enemies
        shockwave = {
            id = "shockwave",
            name = "Shockwave",
            description = "Damage and push back all adjacent enemies",
            icon = nil,
            energyCost = 5,
            actionPointCost = 1,
            cooldown = 3,
            targetType = "self",
            range = 0,
            unitType = "rook",
            onUse = function(user, target, x, y)
                -- Get all adjacent enemies
                local adjacentPositions = {
                    {x = user.x - 1, y = user.y},
                    {x = user.x + 1, y = user.y},
                    {x = user.x, y = user.y - 1},
                    {x = user.x, y = user.y + 1}
                }
                
                local hitUnits = {}
                
                for _, pos in ipairs(adjacentPositions) do
                    local entity = user.grid:getEntityAt(pos.x, pos.y)
                    if entity and entity.faction ~= user.faction then
                        table.insert(hitUnits, {
                            unit = entity,
                            dx = pos.x - user.x,
                            dy = pos.y - user.y
                        })
                    end
                end
                
                -- Deal damage and push back
                for _, hit in ipairs(hitUnits) do
                    local hitUnit = hit.unit
                    local pushX = hitUnit.x + hit.dx
                    local pushY = hitUnit.y + hit.dy
                    
                    -- Deal damage
                    local damage = math.ceil(user.stats.attack * 0.7)
                    
                    if self.game.combatSystem then
                        self.game.combatSystem:applyDirectDamage(hitUnit, damage, {
                            source = "ability",
                            ability = "shockwave",
                            user = user,
                            isCritical = false,
                            isMiss = false
                        })
                    else
                        hitUnit:takeDamage(damage, user)
                    end
                    
                    -- Push back if possible
                    if user.grid:isInBounds(pushX, pushY) and not user.grid:getEntityAt(pushX, pushY) then
                        user.grid:removeEntity(hitUnit.x, hitUnit.y)
                        hitUnit.x = pushX
                        hitUnit.y = pushY
                        user.grid:placeEntity(hitUnit, pushX, pushY)
                    end
                end
                
                -- Visual feedback
                print(user.unitType:upper() .. " used Shockwave!")
                
                return true
            end
        },
        
        -- Stone Skin: Become immune to status effects
        stone_skin = {
            id = "stone_skin",
            name = "Stone Skin",
            description = "Become immune to status effects",
            icon = nil,
            energyCost = 4,
            actionPointCost = 1,
            cooldown = 4,
            targetType = "self",
            range = 0,
            unitType = "rook",
            onUse = function(user, target, x, y)
                -- Apply status effect immunity
                user.immuneToStatusEffects = true
                
                -- Clear existing negative status effects
                if user.statusEffects then
                    local i = 1
                    while i <= #user.statusEffects do
                        local effect = user.statusEffects[i]
                        if effect.name == "Burning" or effect.name == "Stunned" or 
                           effect.name == "Weakened" or effect.name == "Slowed" then
                            table.remove(user.statusEffects, i)
                        else
                            i = i + 1
                        end
                    end
                end
                
                -- Set up immunity removal after 3 turns
                timer.after(3, function()
                    user.immuneToStatusEffects = false
                    print(user.unitType:upper() .. " is no longer immune to status effects")
                end)
                
                -- Visual feedback
                print(user.unitType:upper() .. " used Stone Skin!")
                
                return true
            end
        },
        
        -- BISHOP ABILITIES
        
        -- Healing Light: Heal self and adjacent allies
        healing_light = {
            id = "healing_light",
            name = "Healing Light",
            description = "Heal self and adjacent allies",
            icon = nil,
            energyCost = 4,
            actionPointCost = 1,
            cooldown = 2,
            targetType = "self",
            range = 0,
            unitType = "bishop",
            onUse = function(user, target, x, y)
                -- Heal self
                local healAmount = math.ceil(user.stats.maxHealth * 0.3)
                
                if self.game.combatSystem then
                    self.game.combatSystem:applyHealing(user, healAmount, {
                        source = "ability",
                        ability = "healing_light",
                        user = user
                    })
                else
                    user:heal(healAmount)
                end
                
                -- Get adjacent allies
                local adjacentPositions = {
                    {x = user.x - 1, y = user.y},
                    {x = user.x + 1, y = user.y},
                    {x = user.x, y = user.y - 1},
                    {x = user.x, y = user.y + 1}
                }
                
                for _, pos in ipairs(adjacentPositions) do
                    local entity = user.grid:getEntityAt(pos.x, pos.y)
                    if entity and entity.faction == user.faction then
                        -- Heal ally
                        if self.game.combatSystem then
                            self.game.combatSystem:applyHealing(entity, healAmount, {
                                source = "ability",
                                ability = "healing_light",
                                user = user
                            })
                        else
                            entity:heal(healAmount)
                        end
                    end
                end
                
                -- Visual feedback
                print(user.unitType:upper() .. " used Healing Light!")
                
                return true
            end
        },
        
        -- Mystic Barrier: Create impassable barriers
        mystic_barrier = {
            id = "mystic_barrier",
            name = "Mystic Barrier",
            description = "Create impassable barriers",
            icon = nil,
            energyCost = 5,
            actionPointCost = 1,
            cooldown = 3,
            targetType = "position",
            range = 3,
            unitType = "bishop",
            onUse = function(caster, target, x, y, grid)
                -- Check if target position is valid
                if not x or not y or not grid:isInBounds(x, y) then
                    return false
                end
                
                -- Check if position is reachable
                local distance = math.abs(caster.x - x) + math.abs(caster.y - y)
                if distance > 4 then
                    return false
                end
                
                -- Check if position is empty
                if grid:getEntityAt(x, y) then
                    return false
                end
                
                -- Create barrier entity
                local barrier = {
                    type = "barrier",
                    x = x,
                    y = y,
                    isBarrier = true,
                    duration = 3,
                    creator = caster
                }
                
                -- Place barrier on grid
                grid:placeEntity(barrier, x, y)
                
                -- Set up barrier removal
                timer.after(3, function()
                    grid:removeEntity(barrier)
                    print("Mystic Barrier dissipates")
                end)
                
                -- Visual feedback
                print(caster.unitType:upper() .. " used Mystic Barrier!")
                
                return true
            end
        },
        
        -- Arcane Bolt: Long-range attack that ignores defense
        arcane_bolt = {
            id = "arcane_bolt",
            name = "Arcane Bolt",
            description = "Long-range attack that ignores defense",
            icon = nil,
            energyCost = 4,
            actionPointCost = 1,
            cooldown = 2,
            targetType = "enemy",
            range = 5,
            unitType = "bishop",
            onUse = function(user, target, x, y)
                if not target or target.faction == user.faction then
                    return false
                end
                
                -- Calculate distance
                local distance = math.abs(user.x - target.x) + math.abs(user.y - target.y)
                if distance > 5 then
                    return false
                end
                
                -- Deal damage ignoring defense
                local damage = user.stats.attack
                
                if self.game.combatSystem then
                    self.game.combatSystem:applyDirectDamage(target, damage, {
                        source = "ability",
                        ability = "arcane_bolt",
                        user = user,
                        ignoreDefense = true,
                        isCritical = false,
                        isMiss = false
                    })
                else
                    -- Manually ignore defense
                    target.stats.health = math.max(0, target.stats.health - damage)
                end
                
                -- Visual feedback
                print(user.unitType:upper() .. " used Arcane Bolt!")
                
                return true
            end
        },
        
        -- PAWN ABILITIES
        
        -- Shield Bash: Stun adjacent enemy
        shield_bash = {
            id = "shield_bash",
            name = "Shield Bash",
            description = "Stun adjacent enemy",
            icon = nil,
            energyCost = 3,
            actionPointCost = 1,
            cooldown = 3,
            targetType = "enemy",
            range = 1,
            unitType = "pawn",
            onUse = function(user, target, x, y)
                if not target or target.faction == user.faction then
                    return false
                end
                
                -- Check if target is adjacent
                local distance = math.abs(user.x - target.x) + math.abs(user.y - target.y)
                if distance > 1 then
                    return false
                end
                
                -- Deal damage
                local damage = math.ceil(user.stats.attack * 0.5)
                
                if self.game.combatSystem then
                    self.game.combatSystem:applyDirectDamage(target, damage, {
                        source = "ability",
                        ability = "shield_bash",
                        user = user,
                        isCritical = false,
                        isMiss = false
                    })
                else
                    target:takeDamage(damage, user)
                end
                
                -- Apply stun
                if self.game.statusEffectsSystem then
                    self.game.statusEffectsSystem:applyEffect(target, "stunned", user)
                end
                
                -- Visual feedback
                print(user.unitType:upper() .. " used Shield Bash!")
                
                return true
            end
        },
        
        -- Advance: Move forward and gain temporary attack boost
        advance = {
            id = "advance",
            name = "Advance",
            description = "Move forward and gain temporary attack boost",
            icon = nil,
            energyCost = 2,
            actionPointCost = 1,
            cooldown = 2,
            targetType = "self",
            range = 0,
            unitType = "pawn",
            onUse = function(user, target, x, y)
                -- Determine forward direction based on faction
                local dx = 0
                local dy = 0
                
                if user.faction == "player" then
                    dx = 1 -- Player pawns move right
                else
                    dx = -1 -- Enemy pawns move left
                end
                
                local newX = user.x + dx
                local newY = user.y
                
                -- Check if position is valid
                if not user.grid:isInBounds(newX, newY) then
                    return false
                end
                
                -- Check if position is empty
                if user.grid:getEntityAt(newX, newY) then
                    return false
                end
                
                -- Move forward
                user.grid:removeEntity(user.x, user.y)
                user.x = newX
                user.y = newY
                user.grid:placeEntity(user, newX, newY)
                
                -- Apply attack boost
                if self.game.statusEffectsSystem then
                    self.game.statusEffectsSystem:applyEffect(user, "empowered", user)
                end
                
                -- Visual feedback
                print(user.unitType:upper() .. " used Advance!")
                
                return true
            end
        },
        
        -- Promotion: Transform into a stronger unit at the cost of health
        promotion = {
            id = "promotion",
            name = "Promotion",
            description = "Transform into a stronger unit at the cost of health",
            icon = nil,
            energyCost = 8,
            actionPointCost = 1,
            cooldown = 0, -- Can only be used once
            targetType = "self",
            range = 0,
            unitType = "pawn",
            onUse = function(user, target, x, y)
                -- Check if pawn has enough health
                if user.stats.health < user.stats.maxHealth * 0.5 then
                    return false
                end
                
                -- Reduce health
                user.stats.health = math.ceil(user.stats.health * 0.5)
                
                -- Increase stats
                user.stats.attack = user.stats.attack + 2
                user.stats.defense = user.stats.defense + 1
                user.stats.moveRange = user.stats.moveRange + 1
                
                -- Change unit type
                user.unitType = "queen"
                
                -- Update abilities
                user.abilities = {"sovereign_wrath", "royal_decree", "strategic_repositioning"}
                
                -- Reset ability cooldowns
                user.abilityCooldowns = {}
                
                -- Visual feedback
                print(user.unitType:upper() .. " used Promotion and transformed into a QUEEN!")
                
                return true
            end
        },

        -- Damage abilities
        fireball = {
            id = "fireball",
            name = "Fireball",
            description = "Launch a fireball that deals 5 damage to target and 2 damage to adjacent tiles.",
            icon = nil,
            energyCost = 3,
            actionPointCost = 1,
            cooldown = 2,
            range = 3,
            targetType = "position", -- can target enemy, ally, tile, self
            onUse = function(self, caster, target, x, y, grid)
                -- Deal damage to primary target
                local primaryDamage = 5
                if target and target.stats then
                    target.stats.health = math.max(0, target.stats.health - primaryDamage)
                    print(target.unitType .. " took " .. primaryDamage .. " damage from fireball")
                end
                
                -- Deal splash damage to adjacent tiles
                local splashDamage = 2
                local adjacentPositions = {
                    {x-1, y}, {x+1, y}, {x, y-1}, {x, y+1}
                }
                
                for _, pos in ipairs(adjacentPositions) do
                    local adjacentEntity = grid:getEntityAt(pos[1], pos[2])
                    if adjacentEntity and adjacentEntity.stats and adjacentEntity.faction ~= caster.faction then
                        adjacentEntity.stats.health = math.max(0, adjacentEntity.stats.health - splashDamage)
                        print(adjacentEntity.unitType .. " took " .. splashDamage .. " splash damage from fireball")
                    end
                end
                
                -- Visual effect (would be implemented with particles)
                print("Fireball visual effect at " .. x .. "," .. y)
                
                return true
            end
        },
        
        -- Healing abilities
        heal = {
            id = "heal",
            name = "Heal",
            description = "Restore 5 health to target unit.",
            icon = nil,
            energyCost = 2,
            actionPointCost = 1,
            cooldown = 1,
            range = 2,
            targetType = "ally", -- can target enemy, ally, tile, self
            onUse = function(self, caster, target, x, y, grid)
                if not target or not target.stats then
                    return false
                end
                
                -- Heal target
                local healAmount = 5
                target.stats.health = math.min(target.stats.maxHealth, target.stats.health + healAmount)
                print(target.unitType .. " healed for " .. healAmount)
                
                -- Visual effect
                print("Heal visual effect on " .. target.unitType)
                
                return true
            end
        },
        
        -- Utility abilities
        teleport = {
            id = "teleport",
            name = "Teleport",
            description = "Teleport to target empty tile within range.",
            icon = nil,
            energyCost = 4,
            actionPointCost = 1,
            cooldown = 3,
            range = 5,
            targetType = "position",
            onUse = function(self, caster, target, x, y, grid)
                -- Check if tile is valid and empty
                if not grid:isValidPosition(x, y) or grid:getEntityAt(x, y) then
                    return false
                end
                
                -- Move from current position
                grid:removeEntity(caster)
                
                -- Update position
                local oldX, oldY = caster.x, caster.y
                caster.x = x
                caster.y = y
                
                -- Place at new position
                grid:placeEntity(caster, x, y)
                
                -- Visual effect
                print("Teleport visual effect from " .. oldX .. "," .. oldY .. " to " .. x .. "," .. y)
                
                return true
            end
        },
        
        -- Buff abilities
        strengthen = {
            id = "strengthen",
            name = "Strengthen",
            description = "Increase target's attack by 2 for 2 turns.",
            icon = nil,
            energyCost = 3,
            actionPointCost = 1,
            cooldown = 3,
            range = 1,
            targetType = "ally",
            onUse = function(self, caster, target, x, y, grid)
                if not target or not target.stats then
                    return false
                end
                
                -- Apply buff
                local attackBuff = 2
                target.stats.attack = target.stats.attack + attackBuff
                
                -- Store original value to restore later
                target.attackBuffExpiry = target.attackBuffExpiry or {}
                table.insert(target.attackBuffExpiry, {
                    value = attackBuff,
                    turnsLeft = 2
                })
                
                print(target.unitType .. " attack increased by " .. attackBuff .. " for 2 turns")
                
                -- Visual effect
                print("Strengthen visual effect on " .. target.unitType)
                
                return true
            end
        },
        
        -- Defensive abilities
        shield = {
            id = "shield",
            name = "Shield",
            description = "Gain +3 defense until your next turn.",
            icon = nil,
            energyCost = 2,
            actionPointCost = 1,
            cooldown = 2,
            range = 0,
            targetType = "self",
            onUse = function(self, caster, target, x, y, grid)
                -- Apply shield
                local defenseBuff = 3
                caster.stats.defense = caster.stats.defense + defenseBuff
                
                -- Store original value to restore later
                caster.defenseBuffExpiry = caster.defenseBuffExpiry or {}
                table.insert(caster.defenseBuffExpiry, {
                    value = defenseBuff,
                    turnsLeft = 1
                })
                
                print(caster.unitType .. " defense increased by " .. defenseBuff .. " until next turn")
                
                -- Visual effect
                print("Shield visual effect on " .. caster.unitType)
                
                return true
            end
        }
    }

    if game and game.turnManager then
        game.turnManager: addTurnStartEvent(function(unit)
        self:processTurnStart(unit)
        end)
    end
end

-- Get ability definition
function SpecialAbilitiesSystem:getAbility(abilityId)
    -- Try direct lookup first
    local ability = self.abilities[abilityId]
    if ability then
        return ability
    end
    
    -- If not found, try to match by name
    for id, abilityDef in pairs(self.abilities) do
        if abilityDef.name == abilityId then
            --print("Warning: Using ability name instead of ID: " .. abilityId .. " -> " .. id)
            return abilityDef
        end
    end
    
    -- Try normalizing the string (convert spaces/apostrophes to underscores)
    local normalizedId = abilityId:gsub("'", ""):gsub(" ", "_"):lower()
    ability = self.abilities[normalizedId]
    if ability then
        --print("Warning: Using normalized ability name: " .. abilityId .. " -> " .. normalizedId)
        return ability
    end
    
    --print("Ability not found: " .. abilityId)
    return nil
end

-- Check if an ability can be used by unit on target
function SpecialAbilitiesSystem:canUseAbility(unit, abilityId, target, x, y)
    local ability = self:getAbility(abilityId)
    if not ability then
        print("Ability not found: " .. abilityId)
        return false
    end
    
    -- Check if unit can use ability (cooldown, energy, etc.)
    if not unit:canUseAbility(abilityId) then
        print("Unit cannot use ability: " .. abilityId)
        return false
    end
    
    -- Check range
    if ability.range > 0 then
        local distance = math.abs(unit.x - x) + math.abs(unit.y - y)
        if distance > ability.range then
            print("Target is out of range")
            return false
        end
    end
    
    -- Check target type validity
    if ability.targetType == "enemy" and (not target or target.faction == unit.faction) then
        print("Invalid target type: need enemy")
        return false
    elseif ability.targetType == "ally" and (not target or target.faction ~= unit.faction) then
        print("Invalid target type: need ally")
        return false
    elseif ability.targetType == "self" and target ~= unit then
        print("Invalid target type: need self")
        return false
    end
    
    return true
end

-- Use an ability
function SpecialAbilitiesSystem:useAbility(unit, abilityId, target, x, y)
    local ability = self:getAbility(abilityId)
    if not ability then
        print("Ability not found: " .. abilityId)
        return false
    end
    
    -- Check if ability can be used
    if not self:canUseAbility(unit, abilityId, target, x, y) then
        print("Cannot use ability: " .. abilityId)
        return false
    end
    
    -- Apply energy cost
    unit.energy = math.max(0, unit.energy - ability.energyCost)
    unit.stats.energy = unit.energy
    
    -- Apply cooldown
    unit:setAbilityCooldown(abilityId, ability.cooldown)
    
    -- Mark as having used an ability this turn
    unit.hasUsedAbility = true
    
    -- Execute ability effect
    local grid = self.game.grid
    local success = ability.onUse(unit, target, x, y, grid)
    
    -- Check if any units were defeated
    --if self.game then
    --    self.game:checkGameOver()
    --end
    
    return success
end

-- Process buff expirations for a unit
function SpecialAbilitiesSystem:processBuffExpirations(unit)
    -- Process attack buffs
    if unit.attackBuffExpiry then
        local i = 1
        while i <= #unit.attackBuffExpiry do
            local buff = unit.attackBuffExpiry[i]
            buff.turnsLeft = buff.turnsLeft - 1
            
            if buff.turnsLeft <= 0 then
                -- Remove expired buff
                unit.stats.attack = unit.stats.attack - buff.value
                table.remove(unit.attackBuffExpiry, i)
                print(unit.unitType .. " attack buff expired")
            else
                i = i + 1
            end
        end
    end
    
    -- Process defense buffs
    if unit.defenseBuffExpiry then
        local i = 1
        while i <= #unit.defenseBuffExpiry do
            local buff = unit.defenseBuffExpiry[i]
            buff.turnsLeft = buff.turnsLeft - 1
            
            if buff.turnsLeft <= 0 then
                -- Remove expired buff
                unit.stats.defense = unit.stats.defense - buff.value
                table.remove(unit.defenseBuffExpiry, i)
                print(unit.unitType .. " defense buff expired")
            else
                i = i + 1
            end
        end
    end
end

-- Get valid targets for an ability
function SpecialAbilitiesSystem:getValidTargets(unit, abilityId)
    local ability = self:getAbility(abilityId)
    if not ability then
        print("Cannot get valid targets: ability not found")
        return {}
    end
    
    local targets = {}
    local grid = self.game.grid
    
    -- Get targets based on ability target type and range
    if ability.targetType == "self" then
        -- Self-targeted ability
        targets = {{x = unit.x, y = unit.y, unit = unit}}
    elseif ability.targetType == "ally" then
        -- Ally-targeted ability
        for y = 1, grid.height do
            for x = 1, grid.width do
                local entity = grid:getEntityAt(x, y)
                if entity and entity.faction == unit.faction then
                    local distance = math.abs(unit.x - x) + math.abs(unit.y - y)
                    if distance <= ability.range then
                        table.insert(targets, {x = x, y = y, unit = entity})
                    end
                end
            end
        end
    elseif ability.targetType == "enemy" then
        -- Enemy-targeted ability
        for y = 1, grid.height do
            for x = 1, grid.width do
                local entity = grid:getEntityAt(x, y)
                if entity and entity.faction ~= unit.faction then
                    local distance = math.abs(unit.x - x) + math.abs(unit.y - y)
                    if distance <= ability.range then
                        table.insert(targets, {x = x, y = y, unit = entity})
                    end
                end
            end
        end
    elseif ability.targetType == "position" then
        -- Position-targeted ability
        for y = math.max(1, unit.y - ability.range), math.min(grid.height, unit.y + ability.range) do
            for x = math.max(1, unit.x - ability.range), math.min(grid.width, unit.x + ability.range) do
                -- Check if within range (Manhattan distance)
                local distance = math.abs(unit.x - x) + math.abs(unit.y - y)
                if distance <= ability.range then
                    -- For position targets, we don't need a unit
                    table.insert(targets, {x = x, y = y, unit = grid:getEntityAt(x, y)})
                end
            end
        end
    end
    
    return targets
end

-- Apply a status effect to a unit
function SpecialAbilitiesSystem:applyStatusEffect(unit, effectType, duration)
    -- Create a basic effect object if a string was passed
    local effect = effectType
    if type(effectType) == "string" then
        effect = {
            name = effectType,
            duration = duration or 2,
            turnsLeft = duration or 2
        }
    end
    
    -- Initialize status effects array if needed
    unit.statusEffects = unit.statusEffects or {}
    
    -- Store the effect
    unit.statusEffects[effect.name] = effect
    
    -- Log application
    print(unit.unitType .. " gained status effect: " .. effect.name)
    
    return true
end

-- Remove a status effect from a unit
function SpecialAbilitiesSystem:removeStatusEffect(unit, effectName)
    if not unit.statusEffects then return false end
    
    local effect = unit.statusEffects[effectName]
    if effect then
        unit.statusEffects[effectName] = nil
        print(unit.unitType .. " lost status effect: " .. effectName)
        return true
    end
    
    return false
end

-- Check if a unit has a particular status effect
function SpecialAbilitiesSystem:hasStatusEffect(unit, effectName)
    if not unit.statusEffects then return false end
    return unit.statusEffects[effectName] ~= nil
end

-- Debug output of all abilities
function SpecialAbilitiesSystem:debugAbilities()
    print("\n=== SPECIAL ABILITIES SYSTEM DEBUG ===")
    print("Total abilities defined: " .. self:countAbilities())
    
    -- Print all abilities
    print("\nABILITIES:")
    local count = 0
    for id, ability in pairs(self.abilities) do
        count = count + 1
        print(count .. ". " .. id .. " -> " .. (ability.name or "NO NAME"))
        print("   Description: " .. (ability.description or "None"))
        print("   Energy Cost: " .. (ability.energyCost or 0))
        print("   Cooldown: " .. (ability.cooldown or 0))
        print("   Target Type: " .. (ability.targetType or "unknown"))
        print("   Range: " .. (ability.range or 0))
        print("   Has execute function: " .. tostring(ability.onUse ~= nil))
        print("")
    end
    
    print("=== END ABILITIES DEBUG ===\n")
end

-- Count abilities
function SpecialAbilitiesSystem:countAbilities()
    local count = 0
    for _ in pairs(self.abilities) do
        count = count + 1
    end
    return count
end

return SpecialAbilitiesSystem