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
            name = "Knight's Charge",
            description = "Dash to a location and damage enemies in path",
            icon = nil, -- Would be an image in a full implementation
            energyCost = 4,
            actionPointCost = 1,
            cooldown = 3,
            targetType = "position",
            range = 4,
            unitType = "knight",
            onUse = function(user, target, x, y)
                -- Check if target position is valid
                if not x or not y or not user.grid:isInBounds(x, y) then
                    return false
                end
                
                -- Check if position is reachable
                local distance = math.abs(user.x - x) + math.abs(user.y - y)
                if distance > 4 then
                    return false
                end
                
                -- Get all units in path
                local path = self:getLinePath(user.x, user.y, x, y)
                local hitUnits = {}
                
                for _, pos in ipairs(path) do
                    local entity = user.grid:getEntity(pos.x, pos.y)
                    if entity and entity ~= user and entity.faction ~= user.faction then
                        table.insert(hitUnits, entity)
                    end
                end
                
                -- Move user to target position
                user.grid:removeEntity(user.x, user.y)
                user.x = x
                user.y = y
                user.grid:placeEntity(user, x, y)
                
                -- Deal damage to hit units
                for _, hitUnit in ipairs(hitUnits) do
                    local damage = math.ceil(user.stats.attack * 0.8)
                    
                    if self.game.combatSystem then
                        self.game.combatSystem:applyDirectDamage(hitUnit, damage, {
                            source = "ability",
                            ability = "knights_charge",
                            user = user,
                            isCritical = false,
                            isMiss = false
                        })
                    else
                        hitUnit:takeDamage(damage, user)
                    end
                end
                
                -- Visual feedback
                print(user.unitType:upper() .. " used Knight's Charge!")
                
                return true
            end
        },
        
        -- Feint: Reduce damage taken and counter next attack
        feint = {
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
                if user.grid:getEntity(oppositeX, oppositeY) then
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
                    local entity = user.grid:getEntity(pos.x, pos.y)
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
                    if user.grid:isInBounds(pushX, pushY) and not user.grid:getEntity(pushX, pushY) then
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
                    local entity = user.grid:getEntity(pos.x, pos.y)
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
            name = "Mystic Barrier",
            description = "Create impassable barriers",
            icon = nil,
            energyCost = 5,
            actionPointCost = 1,
            cooldown = 3,
            targetType = "position",
            range = 3,
            unitType = "bishop",
            onUse = function(user, target, x, y)
                -- Check if target position is valid
                if not x or not y or not user.grid:isInBounds(x, y) then
                    return false
                end
                
                -- Check if position is empty
                if user.grid:getEntity(x, y) then
                    return false
                end
                
                -- Create barrier entity
                local barrier = {
                    type = "barrier",
                    x = x,
                    y = y,
                    isBarrier = true,
                    duration = 3,
                    creator = user
                }
                
                -- Place barrier on grid
                user.grid:placeEntity(barrier, x, y)
                
                -- Set up barrier removal
                timer.after(3, function()
                    user.grid:removeEntity(x, y)
                    print("Mystic Barrier dissipates")
                end)
                
                -- Visual feedback
                print(user.unitType:upper() .. " used Mystic Barrier!")
                
                return true
            end
        },
        
        -- Arcane Bolt: Long-range attack that ignores defense
        arcane_bolt = {
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
                if user.grid:getEntity(newX, newY) then
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
        }
    }
end

-- Get ability definition
function SpecialAbilitiesSystem:getAbility(abilityId)
    return self.abilities[abilityId]
end

-- Check if a unit can use an ability
function SpecialAbilitiesSystem:canUseAbility(unit, abilityId)
    -- Check if ability exists
    local ability = self.abilities[abilityId]
    if not ability then
        return false
    end
    
    -- Check if unit has this ability
    local hasAbility = false
    for _, id in ipairs(unit.abilities) do
        if id == abilityId then
            hasAbility = true
            break
        end
    end
    
    if not hasAbility then
        return false
    end
    
    -- Check if ability is on cooldown
    if (unit.abilityCooldowns[abilityId] or 0) > 0 then
        return false
    end
    
    -- Check if unit has already used an ability this turn
    if unit.hasUsedAbility then
        return false
    end
    
    -- Check energy cost
    if ability.energyCost and unit.stats.energy < ability.energyCost then
        return false
    end
    
    -- Check unit type restriction
    if ability.unitType and unit.unitType ~= ability.unitType then
        return false
    end
    
    return true
end

-- Use an ability
function SpecialAbilitiesSystem:useAbility(unit, abilityId, target, x, y)
    -- Check if ability can be used
    if not self:canUseAbility(unit, abilityId) then
        return false
    end
    
    -- Get ability definition
    local ability = self.abilities[abilityId]
    
    -- Use the ability
    local success = false
    if ability.onUse then
        success = ability.onUse(unit, target, x, y)
    end
    
    if success then
        -- Use energy
        if ability.energyCost then
            unit.stats.energy = unit.stats.energy - ability.energyCost
        end
        
        -- Set cooldown
        if ability.cooldown then
            unit.abilityCooldowns[abilityId] = ability.cooldown
        end
        
        -- Mark as having used an ability
        unit.hasUsedAbility = true
    end
    
    return success
end

-- Get valid targets for an ability
function SpecialAbilitiesSystem:getValidTargets(unit, abilityId)
    -- Check if ability exists
    local ability = self.abilities[abilityId]
    if not ability then
        return {}
    end
    
    -- Check if unit can use this ability
    if not self:canUseAbility(unit, abilityId) then
        return {}
    end
    
    local targets = {}
    
    -- Get targets based on ability target type
    if ability.targetType == "self" then
        -- Self-targeted ability
        targets = {{x = unit.x, y = unit.y, unit = unit}}
    elseif ability.targetType == "ally" then
        -- Ally-targeted ability
        for _, ally in ipairs(self:getAllies(unit)) do
            local distance = math.abs(unit.x - ally.x) + math.abs(unit.y - ally.y)
            if distance <= ability.range then
                table.insert(targets, {x = ally.x, y = ally.y, unit = ally})
            end
        end
    elseif ability.targetType == "enemy" then
        -- Enemy-targeted ability
        for _, enemy in ipairs(self:getEnemies(unit)) do
            local distance = math.abs(unit.x - enemy.x) + math.abs(unit.y - enemy.y)
            if distance <= ability.range then
                table.insert(targets, {x = enemy.x, y = enemy.y, unit = enemy})
            end
        end
    elseif ability.targetType == "position" then
        -- Position-targeted ability
        for y = math.max(1, unit.y - ability.range), math.min(unit.grid.height, unit.y + ability.range) do
            for x = math.max(1, unit.x - ability.range), math.min(unit.grid.width, unit.x + ability.range) do
                local distance = math.abs(unit.x - x) + math.abs(unit.y - y)
                if distance <= ability.range then
                    table.insert(targets, {x = x, y = y})
                end
            end
        end
    end
    
    return targets
end

-- Get all allies of a unit
function SpecialAbilitiesSystem:getAllies(unit)
    local allies = {}
    
    if not unit.grid then
        return allies
    end
    
    -- Get all units on the grid
    for y = 1, unit.grid.height do
        for x = 1, unit.grid.width do
            local entity = unit.grid:getEntity(x, y)
            if entity and entity ~= unit and entity.faction == unit.faction then
                table.insert(allies, entity)
            end
        end
    end
    
    return allies
end

-- Get all enemies of a unit
function SpecialAbilitiesSystem:getEnemies(unit)
    local enemies = {}
    
    if not unit.grid then
        return enemies
    end
    
    -- Get all units on the grid
    for y = 1, unit.grid.height do
        for x = 1, unit.grid.width do
            local entity = unit.grid:getEntity(x, y)
            if entity and entity.faction ~= unit.faction then
                table.insert(enemies, entity)
            end
        end
    end
    
    return enemies
end

-- Get adjacent allies of a unit
function SpecialAbilitiesSystem:getAdjacentAllies(unit)
    local allies = {}
    
    if not unit.grid then
        return allies
    end
    
    -- Check adjacent positions
    local adjacentPositions = {
        {x = unit.x - 1, y = unit.y},
        {x = unit.x + 1, y = unit.y},
        {x = unit.x, y = unit.y - 1},
        {x = unit.x, y = unit.y + 1}
    }
    
    for _, pos in ipairs(adjacentPositions) do
        local entity = unit.grid:getEntity(pos.x, pos.y)
        if entity and entity.faction == unit.faction then
            table.insert(allies, entity)
        end
    end
    
    return allies
end

-- Get adjacent enemies of a unit
function SpecialAbilitiesSystem:getAdjacentEnemies(unit)
    local enemies = {}
    
    if not unit.grid then
        return enemies
    end
    
    -- Check adjacent positions
    local adjacentPositions = {
        {x = unit.x - 1, y = unit.y},
        {x = unit.x + 1, y = unit.y},
        {x = unit.x, y = unit.y - 1},
        {x = unit.x, y = unit.y + 1}
    }
    
    for _, pos in ipairs(adjacentPositions) do
        local entity = unit.grid:getEntity(pos.x, pos.y)
        if entity and entity.faction ~= unit.faction then
            table.insert(enemies, entity)
        end
    end
    
    return enemies
end

-- Get a line path between two points
function SpecialAbilitiesSystem:getLinePath(x1, y1, x2, y2)
    local path = {}
    
    -- Use Bresenham's line algorithm
    local dx = math.abs(x2 - x1)
    local dy = math.abs(y2 - y1)
    local sx = x1 < x2 and 1 or -1
    local sy = y1 < y2 and 1 or -1
    local err = dx - dy
    
    while true do
        table.insert(path, {x = x1, y = y1})
        
        if x1 == x2 and y1 == y2 then
            break
        end
        
        local e2 = 2 * err
        if e2 > -dy then
            err = err - dy
            x1 = x1 + sx
        end
        if e2 < dx then
            err = err + dx
            y1 = y1 + sy
        end
    end
    
    return path
end

-- Initialize a unit with abilities
function SpecialAbilitiesSystem:initializeUnit(unit)
    -- Make sure unit has abilities
    if not unit.abilities or #unit.abilities == 0 then
        unit.abilities = unit:getDefaultAbilities()
    end
    
    -- Initialize ability cooldowns
    unit.abilityCooldowns = {}
    for _, abilityId in ipairs(unit.abilities) do
        unit.abilityCooldowns[abilityId] = 0
    end
    
    return unit
end

return SpecialAbilitiesSystem
