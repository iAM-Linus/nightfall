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
    
        knights_charge = {
            id = "knights_charge",
            name = "Knight's Charge",
            description = "Dash to a location and damage enemies in path",
            icon = nil,
            energyCost = 4,
            actionPointCost = 1,
            cooldown = 3,
            targetType = "position",
            attackRange = 4,
            unitType = "knight",
            onUse = function(caster, target, x, y, grid) -- target might be nil or the entity at x,y
                local ability = self.abilities.knights_charge
                -- Check if target position is valid
                if not x or not y or not grid:isInBounds(x, y) then
                    print("Knight's Charge: Target position out of bounds.")
                    return false
                end
    
                -- Check if position is within attackRange (Manhattan distance)
                print("Caster.x: " .. caster.x .. ", Caster.y: " .. caster.y)
                print("x: " .. x .. ", y: " .. y)
                print("knights_charge.attackRange: " .. ability.attackRange)
                local distance = math.abs(caster.x - x) + math.abs(caster.y - y)
                print(distance)
                if distance == 0 then
                     print("Knight's Charge: Cannot charge to current position.")
                     return false
                end
                if distance > ability.attackRange then
                    print("Knight's Charge: Target position out of attackRange.")
                    return false
                end
    
                -- Check if final position is blocked (optional, depends on if charge can end on occupied tile)
                -- local endEntity = grid:getEntityAt(x, y)
                -- if endEntity and endEntity ~= caster then
                --     print("Knight's Charge: Target position is occupied.")
                --     return false -- Or handle differently if charge can end on enemy/ally
                -- end
    
                -- Create a simple line path (consider using a more robust line algorithm like Bresenham if needed)
                local path = {}
                local currentX, currentY = caster.x, caster.y
                local targetX, targetY = x, y
    
                -- Simplified path generation (assumes direct line, may need refinement for obstacles/turns)
                while currentX ~= targetX or currentY ~= targetY do
                     local stepX, stepY = 0, 0
                     if targetX > currentX then stepX = 1 elseif targetX < currentX then stepX = -1 end
                     if targetY > currentY then stepY = 1 elseif targetY < currentY then stepY = -1 end
    
                     -- Move diagonally first if needed, then straight
                     if stepX ~= 0 and stepY ~= 0 then
                        -- Check diagonal step
                        if not grid:getEntityAt(currentX + stepX, currentY + stepY) then
                             currentX = currentX + stepX
                             currentY = currentY + stepY
                        -- Check horizontal step as alternative
                        elseif not grid:getEntityAt(currentX + stepX, currentY) then
                             currentX = currentX + stepX
                        -- Check vertical step as alternative
                        elseif not grid:getEntityAt(currentX, currentY + stepY) then
                             currentY = currentY + stepY
                        else -- Blocked
                             print("Knight's Charge: Path blocked at", currentX + stepX, currentY + stepY)
                             -- Decide: Stop short, fail, or find alternative path? Let's fail for simplicity.
                             -- Note: A* pathfinding would be better here.
                             -- We will actually just calculate damage along the ideal path and then try to move.
                             -- Recalculating path generation for damage dealing part.
                             path = {} -- Reset path
                             local dx = targetX - caster.x
                             local dy = targetY - caster.y
                             local steps = math.max(math.abs(dx), math.abs(dy))
                             if steps == 0 then break end -- Should not happen due to distance check
                             for i = 1, steps do
                                 local pathX = math.floor(caster.x + dx * i / steps + 0.5) -- Bresenham-like approx
                                 local pathY = math.floor(caster.y + dy * i / steps + 0.5)
                                 -- Avoid adding duplicates if path is short/slow
                                 if #path == 0 or path[#path].x ~= pathX or path[#path].y ~= pathY then
                                     table.insert(path, {x = pathX, y = pathY})
                                 end
                             end
                             break -- Exit the path generation loop used for movement check
                        end
                     elseif stepX ~= 0 then -- Horizontal only
                         currentX = currentX + stepX
                     elseif stepY ~= 0 then -- Vertical only
                         currentY = currentY + stepY
                     end
    
                     -- Add the *intermediate* position to the path for damage check
                     if currentX ~= targetX or currentY ~= targetY then
                         -- Check if path segment is valid (not blocked by terrain/impassable)
                         -- For simplicity, assume no impassable terrain here, only units block movement attempt later
                         table.insert(path, {x = currentX, y = currentY})
                     end
    
                     -- Safety break
                     if #path > (caster.stats.attackRange * 2) then -- Heuristic limit
                         print("Knight's Charge: Path generation exceeded limit.")
                         return false
                     end
                end
                 -- Ensure final target position is in the path if it wasn't added
                if #path == 0 or path[#path].x ~= targetX or path[#path].y ~= targetY then
                     table.insert(path, {x = targetX, y = targetY})
                end
    
    
                -- Get hit units along the calculated path (excluding start, including end tile occupant if any)
                local hitUnits = {}
                local finalPositionBlockedByEnemy = false
                for i, pos in ipairs(path) do
                    local entity = grid:getEntityAt(pos.x, pos.y)
                    if entity and entity ~= caster and entity.faction ~= caster.faction then
                        table.insert(hitUnits, entity)
                        if i == #path then -- Check if the final destination is blocked by an enemy
                            finalPositionBlockedByEnemy = true
                        end
                    elseif entity and entity ~= caster and entity.faction == caster.faction then
                        -- If path is blocked by an ally, cannot charge through/to there
                        print("Knight's Charge: Path blocked by ally at", pos.x, pos.y)
                        return false
                    elseif entity == caster then
                        -- Skip caster's starting position if it somehow gets included
                        goto continue_path_check
                    end
                    ::continue_path_check::
                end
    
                -- Check if the final tile is empty *now* (important for moveTo)
                local finalTileEntity = grid:getEntityAt(x, y)
                if finalTileEntity and finalTileEntity ~= caster then
                     print("Knight's Charge: Final position", x, y, "is occupied by", finalTileEntity.unitType)
                     -- Potentially allow charging *to* an enemy tile but not *through* it? Design decision needed.
                     -- For now, require the final tile to be empty for the move.
                     -- Damage will still apply to units hit along the path.
                     -- If the intent is to stop *before* the occupied tile, adjust 'x' and 'y' here.
                     -- Let's assume the charge *must* end on an empty tile.
                     if finalPositionBlockedByEnemy or grid:getEntityAt(x,y) then
                         print("Knight's Charge: Cannot complete move to occupied tile.")
                         -- We can still deal damage to units hit *before* the final tile, then fail the move part.
                         -- Deal damage first, then check move success.
                     end
                end
    
    
                -- Deal damage to hit units (even if move fails later)
                local damageDealt = false
                if self.game and self.game.combatSystem then
                    for _, hitUnit in ipairs(hitUnits) do
                        -- Check if unit is still valid (might have been killed by another effect)
                        if hitUnit and hitUnit.stats and hitUnit.stats.health > 0 then
                            local damage = math.ceil(caster.stats.attack * 0.8)
                            self.game.combatSystem:applyDirectDamage(hitUnit, damage, {
                                source = "ability",
                                ability = self.id,
                                caster = caster,
                                isCritical = false,
                                isMiss = false
                            })
                            print(hitUnit.unitType .. " took " .. damage .. " damage from Knight's Charge")
                            damageDealt = true
                        end
                    end
                else
                    print("WARNING: CombatSystem not found, cannot apply Knight's Charge damage.")
                    -- Fallback to direct health reduction if needed, but less ideal
                    -- for _, hitUnit in ipairs(hitUnits) do
                    --     if hitUnit and hitUnit.stats and hitUnit.stats.health > 0 then
                    --         local damage = math.ceil(caster.stats.attack * 0.8)
                    --         hitUnit.stats.health = math.max(0, hitUnit.stats.health - damage)
                    --         print(hitUnit.unitType .. " took " .. damage .. " damage from Knight's Charge (direct)")
                    --         damageDealt = true
                    --     end
                    -- end
                end
    
                 -- Check again if the final tile is empty before moving
                if grid:getEntityAt(x, y) then
                    print(caster.unitType:upper() .. " used Knight's Charge (Damage only, move blocked)!")
                    return damageDealt -- Return true if damage was dealt, even if move failed
                end
    
                -- Move caster to target position using moveTo
                local moveSuccess = caster:moveTo(x, y)
    
                if moveSuccess then
                    -- Visual feedback / Log
                    print(caster.unitType:upper() .. " used Knight's Charge!")
                    return true -- Ability use was successful
                else
                    -- moveTo failed
                    print(caster.unitType:upper() .. " failed to complete Knight's Charge move (moveTo returned false).")
                     -- Return true if damage was dealt before move failed, otherwise false
                    return damageDealt
                end
            end
        },
    
        feint = {
            id = "feint",
            name = "Feint",
            description = "Reduce damage taken and counter next attack",
            icon = nil,
            energyCost = 3,
            actionPointCost = 1,
            cooldown = 2,
            targetType = "self",
            attackRange = 0,
            unitType = "knight",
            onUse = function(caster, target, x, y, grid) -- target will be caster
                if self.game and self.game.statusEffectsSystem then
                    -- Apply shielded effect (assuming it reduces damage taken)
                    -- Duration might be 1 turn or until next attack, handled by effect definition
                    self.game.statusEffectsSystem:applyEffect(caster, "shielded", caster)
    
                    -- Apply counter effect (assuming it triggers on next attack received)
                    -- Duration might be 1 turn or until triggered, handled by effect definition
                    self.game.statusEffectsSystem:applyEffect(caster, "counter_stance", caster)
    
                    print(caster.unitType:upper() .. " used Feint!")
                    return true
                else
                    print("WARNING: StatusEffectsSystem not found, cannot apply Feint effects.")
                    return false
                end
            end
        },
    
        flanking_maneuver = {
            id = "flanking_maneuver",
            name = "Flanking Maneuver",
            description = "Move to opposite side of target and attack with bonus damage",
            icon = nil,
            energyCost = 5,
            actionPointCost = 1,
            cooldown = 3,
            targetType = "enemy",
            attackRange = 3, -- Range to initiate the maneuver from
            unitType = "knight",
            onUse = function(caster, target, x, y, grid) -- x,y here are target's coords
                if not target or target.faction == caster.faction or not target.stats then
                     print("Flanking Maneuver: Invalid target.")
                    return false
                end
    
                -- Check attackRange to target
                local distance = math.abs(caster.x - target.x) + math.abs(caster.y - target.y)
                if distance > self.attackRange then
                     print("Flanking Maneuver: Target out of attackRange.")
                    return false
                end
    
                -- Calculate opposite position relative to the target
                -- Simple reflection: T = target, C = caster, O = opposite
                -- O.x = T.x + (T.x - C.x) = 2*T.x - C.x
                -- O.y = T.y + (T.y - C.y) = 2*T.y - C.y
                -- More robust: Find vector C->T, move T by that vector again.
                local dx = target.x - caster.x
                local dy = target.y - caster.y
                local oppositeX = target.x + dx
                local oppositeY = target.y + dy
    
                -- Check if opposite position is valid and in bounds
                if not grid:isInBounds(oppositeX, oppositeY) then
                     print("Flanking Maneuver: Opposite position out of bounds.")
                    return false
                end
    
                -- Check if opposite position is empty
                local entityAtOpposite = grid:getEntityAt(oppositeX, oppositeY)
                if entityAtOpposite and entityAtOpposite ~= caster then -- Allow moving if it's somehow the caster's current spot
                     print("Flanking Maneuver: Opposite position is occupied.")
                    return false
                end
    
                -- Move caster to opposite position using moveTo
                local moveSuccess = caster:moveTo(oppositeX, oppositeY)
    
                if moveSuccess then
                    -- Attack target with bonus damage *after* successful move
                    local damage = math.ceil(caster.stats.attack * 1.5)
    
                    if self.game and self.game.combatSystem then
                        self.game.combatSystem:applyDirectDamage(target, damage, {
                            source = "ability",
                            ability = self.id,
                            caster = caster,
                            isCritical = true, -- Flanking could be considered a critical/bonus hit
                            isMiss = false
                        })
                         print(caster.unitType:upper() .. " used Flanking Maneuver on " .. target.unitType .. "!")
                         return true -- Ability use was successful
                    else
                        print("WARNING: CombatSystem not found, cannot apply Flanking Maneuver damage.")
                        -- Fallback direct damage (less ideal)
                        -- target.stats.health = math.max(0, target.stats.health - damage)
                        -- print(caster.unitType:upper() .. " used Flanking Maneuver on " .. target.unitType .. "! (Direct Damage)")
                        -- return true -- Still counts as success if move worked but damage system missing
                        return false -- Or decide failure if core part (damage) is missing
                    end
                else
                    -- moveTo failed
                    print(caster.unitType:upper() .. " failed Flanking Maneuver (moveTo returned false).")
                    return false -- Ability use failed
                end
            end
        },
    
        -- ROOK ABILITIES
    
        fortify = {
            id = "fortify",
            name = "Fortify",
            description = "Increase defense and become immovable",
            icon = nil,
            energyCost = 3,
            actionPointCost = 1,
            cooldown = 2,
            targetType = "self",
            attackRange = 0,
            unitType = "rook",
            onUse = function(caster, target, x, y, grid) -- target is caster
                if self.game and self.game.statusEffectsSystem then
                    -- Apply fortified effect (increases defense, duration handled by effect)
                    -- Duration might be 2 turns, handled by effect definition
                    self.game.statusEffectsSystem:applyEffect(caster, "fortified", caster) -- Assumes "fortified" handles defense boost
    
                    -- Apply immovable effect (prevents forced movement, duration handled by effect)
                     self.game.statusEffectsSystem:applyEffect(caster, "immovable", caster) -- Assumes "immovable" status exists
    
                    print(caster.unitType:upper() .. " used Fortify!")
                    return true
                else
                    print("WARNING: StatusEffectsSystem not found, cannot apply Fortify effects.")
                    return false
                end
            end
        },
    
        shockwave = {
            id = "shockwave",
            name = "Shockwave",
            description = "Damage and push back all adjacent enemies",
            icon = nil,
            energyCost = 5,
            actionPointCost = 1,
            cooldown = 3,
            targetType = "self",
            attackRange = 0, -- AoE originates from self
            unitType = "rook",
            onUse = function(caster, target, x, y, grid) -- target is caster
                local adjacentOffsets = {
                    {dx = -1, dy = 0}, {dx = 1, dy = 0}, {dx = 0, dy = -1}, {dx = 0, dy = 1},
                    {dx = -1, dy = -1}, {dx = 1, dy = -1}, {dx = -1, dy = 1}, {dx = 1, dy = 1} -- Include diagonals? Original only had cardinal. Let's stick to cardinal.
                }
                 adjacentOffsets = { {dx = -1, dy = 0}, {dx = 1, dy = 0}, {dx = 0, dy = -1}, {dx = 0, dy = 1} }
    
                local affectedUnits = {}
    
                for _, offset in ipairs(adjacentOffsets) do
                    local checkX = caster.x + offset.dx
                    local checkY = caster.y + offset.dy
                    if grid:isInBounds(checkX, checkY) then
                        local entity = grid:getEntityAt(checkX, checkY)
                        -- Target enemies only
                        if entity and entity.faction ~= caster.faction and entity.stats then
                            table.insert(affectedUnits, {
                                unit = entity,
                                pushDx = offset.dx, -- Push direction is away from caster
                                pushDy = offset.dy
                            })
                        end
                    end
                end
    
                if #affectedUnits == 0 then
                    print(caster.unitType:upper() .. " used Shockwave, but no enemies were adjacent.")
                    return true -- Ability used, just had no targets
                end
    
                local actionSuccess = false
                -- Deal damage and attempt pushback
                for _, hit in ipairs(affectedUnits) do
                    local hitUnit = hit.unit
                    local pushToX = hitUnit.x + hit.pushDx
                    local pushToY = hitUnit.y + hit.pushDy
    
                     -- Check if unit is still valid (might have been killed by another effect or previous iteration)
                    if not hitUnit or not hitUnit.stats or hitUnit.stats.health <= 0 then
                        goto continue_shockwave_loop
                    end
    
                    -- 1. Deal damage
                    local damage = math.ceil(caster.stats.attack * 0.7)
                    if self.game and self.game.combatSystem then
                        self.game.combatSystem:applyDirectDamage(hitUnit, damage, {
                            source = "ability",
                            ability = self.id,
                            caster = caster,
                            isCritical = false,
                            isMiss = false
                        })
                        print(hitUnit.unitType .. " took " .. damage .. " damage from Shockwave.")
                        actionSuccess = true -- Mark success if at least damage happens
                    else
                        print("WARNING: CombatSystem not found, cannot apply Shockwave damage to " .. hitUnit.unitType)
                        -- Fallback direct damage
                        -- hitUnit.stats.health = math.max(0, hitUnit.stats.health - damage)
                        -- print(hitUnit.unitType .. " took " .. damage .. " damage from Shockwave (Direct).")
                        -- actionSuccess = true
                    end
    
                     -- Check again if unit survived damage before pushing
                     if not hitUnit or not hitUnit.stats or hitUnit.stats.health <= 0 then
                        goto continue_shockwave_loop
                    end
    
                    -- 2. Attempt Pushback
                    -- Check if the push target position is valid, in bounds, and empty
                    if grid:isInBounds(pushToX, pushToY) and not grid:getEntityAt(pushToX, pushToY) then
                        -- Check if the unit is immovable
                        local isImmovable = false
                        if self.game and self.game.statusEffectsSystem then
                             isImmovable = self.game.statusEffectsSystem:hasEffect(hitUnit, "immovable")
                        else
                             -- Check fallback flag if status system not present (less ideal)
                             isImmovable = hitUnit.isImmovable
                        end
    
                        if not isImmovable then
                            -- Ideally, use a push function: hitUnit:bePushedTo(pushToX, pushToY, caster)
                            -- Or a system call: self.game.movementSystem:pushUnit(hitUnit, pushToX, pushToY)
                            -- Lacking those, use direct grid manipulation (less safe, no animation hook):
                            print("Pushing " .. hitUnit.unitType .. " from (" .. hitUnit.x .. "," .. hitUnit.y .. ") to (" .. pushToX .. "," .. pushToY .. ")")
                            grid:removeEntity(hitUnit) -- Remove from old position
                            hitUnit.x = pushToX       -- Update unit's internal position
                            hitUnit.y = pushToY
                            grid:placeEntity(hitUnit, pushToX, pushToY) -- Place in new position
                            actionSuccess = true -- Mark success if push happens
                            -- Trigger any "onMoved" events if applicable
                        else
                            print(hitUnit.unitType .. " resisted pushback (immovable).")
                        end
                    else
                        print("Cannot push " .. hitUnit.unitType .. ": target square (" .. pushToX .. "," .. pushToY .. ") is invalid, out of bounds, or occupied.")
                    end
                    ::continue_shockwave_loop::
                end
    
                if actionSuccess then
                    print(caster.unitType:upper() .. " used Shockwave!")
                end
    
                return actionSuccess -- Return true if any damage or push occurred
            end
        },
    
        stone_skin = {
            id = "stone_skin",
            name = "Stone Skin",
            description = "Become immune to status effects and clear negative ones",
            icon = nil,
            energyCost = 4,
            actionPointCost = 1,
            cooldown = 4,
            targetType = "self",
            attackRange = 0,
            unitType = "rook",
            onUse = function(caster, target, x, y, grid) -- target is caster
                if self.game and self.game.statusEffectsSystem then
                     -- Apply status immunity effect (duration handled by effect)
                     -- Duration might be 3 turns, handled by effect definition
                    self.game.statusEffectsSystem:applyEffect(caster, "status_immune", caster) -- Assumes "status_immune" status exists
    
                     -- Clear existing negative status effects (this logic might belong *inside* the applyEffect for "status_immune")
                     -- Assuming the status system provides a way to clear effects by type or tag
                     local negativeEffectTypes = {"debuff", "dot", "control"} -- Example categories
                     self.game.statusEffectsSystem:clearEffectsByType(caster, negativeEffectTypes)
                     -- Or if clearing specific known effects:
                     -- self.game.statusEffectsSystem:removeEffectByName(caster, "Burning")
                     -- self.game.statusEffectsSystem:removeEffectByName(caster, "Stunned")
                     -- self.game.statusEffectsSystem:removeEffectByName(caster, "Weakened")
                     -- self.game.statusEffectsSystem:removeEffectByName(caster, "Slowed")
                     print("Cleared negative status effects.")
    
                    print(caster.unitType:upper() .. " used Stone Skin!")
                    return true
                else
                    print("WARNING: StatusEffectsSystem not found, cannot apply Stone Skin effects.")
                     -- Fallback manual implementation (less ideal)
                     -- caster.immuneToStatusEffects = true
                     -- Clear existing negative status effects manually
                     -- if caster.statusEffects then
                     --     local i = #caster.statusEffects
                     --     while i >= 1 do
                     --         local effect = caster.statusEffects[i]
                     --         -- Add more negative effect names as needed
                     --         if effect.type == "debuff" or effect.name == "Burning" or effect.name == "Stunned" then
                     --             table.remove(caster.statusEffects, i)
                     --             print("Removed negative effect:", effect.name)
                     --         end
                     --         i = i - 1
                     --     end
                     -- end
                     -- -- Need a way to handle duration without status system (e.g., turn counter)
                     -- caster.stoneSkinTurns = 3
                     -- print(caster.unitType:upper() .. " used Stone Skin! (Manual Fallback)")
                     -- return true
                     return false -- Fail if system is missing
                end
            end
        },
    
        -- BISHOP ABILITIES
    
        healing_light = {
            id = "healing_light",
            name = "Healing Light",
            description = "Heal self and adjacent allies",
            icon = nil,
            energyCost = 4,
            actionPointCost = 1,
            cooldown = 2,
            targetType = "self",
            attackRange = 0, -- AoE originates from self
            unitType = "bishop",
            onUse = function(caster, target, x, y, grid) -- target is caster
                local healAmount = math.ceil(caster.stats.maxHealth * 0.3) -- Or based on caster's magic/attack stat?
                local healedSomeone = false
    
                -- Heal self
                if self.game and self.game.combatSystem then
                     local selfHealed = self.game.combatSystem:applyHealing(caster, healAmount, {
                        source = "ability",
                        ability = self.id,
                        caster = caster
                    })
                    if selfHealed > 0 then
                        print(caster.unitType:upper() .. " healed self for " .. selfHealed)
                        healedSomeone = true
                    end
                else
                    print("WARNING: CombatSystem not found, cannot apply Healing Light to self.")
                    -- Fallback direct heal
                    -- local currentHealth = caster.stats.health
                    -- caster.stats.health = math.min(caster.stats.maxHealth, caster.stats.health + healAmount)
                    -- if caster.stats.health > currentHealth then healedSomeone = true end
                end
    
                -- Check adjacent allies
                local adjacentOffsets = { {dx = -1, dy = 0}, {dx = 1, dy = 0}, {dx = 0, dy = -1}, {dx = 0, dy = 1} }
                for _, offset in ipairs(adjacentOffsets) do
                    local checkX = caster.x + offset.dx
                    local checkY = caster.y + offset.dy
                    if grid:isInBounds(checkX, checkY) then
                        local entity = grid:getEntityAt(checkX, checkY)
                        -- Target allies only (and not self again)
                        if entity and entity ~= caster and entity.faction == caster.faction and entity.stats then
                            if self.game and self.game.combatSystem then
                                 local allyHealed = self.game.combatSystem:applyHealing(entity, healAmount, {
                                    source = "ability",
                                    ability = self.id,
                                    caster = caster
                                })
                                if allyHealed > 0 then
                                    print("Healing Light healed " .. entity.unitType .. " for " .. allyHealed)
                                    healedSomeone = true
                                end
                            else
                                 print("WARNING: CombatSystem not found, cannot apply Healing Light to ally " .. entity.unitType)
                                  -- Fallback direct heal
                                  -- local currentHealth = entity.stats.health
                                  -- entity.stats.health = math.min(entity.stats.maxHealth, entity.stats.health + healAmount)
                                  -- if entity.stats.health > currentHealth then healedSomeone = true end
                            end
                        end
                    end
                end
    
                 if healedSomeone then
                    print(caster.unitType:upper() .. " used Healing Light!")
                 else
                     print(caster.unitType:upper() .. " used Healing Light, but no one needed healing.")
                 end
    
                return true -- Ability was used, even if no healing occurred due to full health
            end
        },
    
        mystic_barrier = {
            id = "mystic_barrier",
            name = "Mystic Barrier",
            description = "Create temporary impassable barriers",
            icon = nil,
            energyCost = 5,
            actionPointCost = 1,
            cooldown = 3,
            targetType = "position",
            attackRange = 3, -- Range to place the barrier
            unitType = "bishop",
            onUse = function(caster, target, x, y, grid) -- target might be nil or entity at x,y
                -- Check if target position is valid
                if not x or not y or not grid:isInBounds(x, y) then
                     print("Mystic Barrier: Target position out of bounds.")
                    return false
                end
    
                -- Check if position is within attackRange
                local distance = math.abs(caster.x - x) + math.abs(caster.y - y)
                if distance > self.attackRange then
                     print("Mystic Barrier: Target position out of attackRange.")
                    return false
                end
    
                -- Check if position is empty (cannot place on top of units/other barriers)
                if grid:getEntityAt(x, y) then
                     print("Mystic Barrier: Target position is occupied.")
                    return false
                end
    
                -- Create barrier entity
                -- Ideally use a factory: local barrier = self.game.entityFactory:create("mystic_barrier", { x=x, y=y, duration=3, creator=caster })
                -- Simple placeholder implementation:
                local barrier = {
                    id = "barrier_" .. x .. "_" .. y .. "_" .. os.time(), -- Unique-ish ID
                    type = "obstacle", -- Or "barrier"
                    unitType = "Mystic Barrier", -- Display name
                    x = x,
                    y = y,
                    isImpassable = true, -- Blocks movement
                    isTargetable = false, -- Cannot be attacked? Or maybe has health?
                    stats = { health = 1, maxHealth = 1 }, -- Give it 1 HP so it can be removed if needed?
                    faction = "neutral", -- Or caster's faction?
                    -- How duration is handled depends on the game loop/timer system
                    creationTurn = self.game and self.game.turnSystem and self.game.turnSystem:getTurnNumber() or 0,
                    durationTurns = 3,
                    caster = caster
                }
    
                 -- Add a method for removal, to be called by a timer or turn system
                 barrier.destroy = function(self)
                     print("Mystic Barrier at (" .. self.x .. "," .. self.y .. ") dissipates.")
                     grid:removeEntity(self) -- Assumes grid can find entity by object reference
                 end
    
                -- Place barrier on grid
                local placed = grid:placeEntity(barrier, x, y)
    
                if not placed then
                     print("Mystic Barrier: Failed to place barrier on grid (grid:placeEntity returned false).")
                     return false -- Grid placement failed
                end
    
                -- Set up barrier removal
                -- Requires a timer system that can track turns and call the destroy method
                if self.game and self.game.timerSystem then
                     self.game.timerSystem:addTurnEndEvent(barrier.creationTurn + barrier.durationTurns, function()
                         -- Check if barrier still exists before removing
                         local currentEntity = grid:getEntityAt(barrier.x, barrier.y)
                         if currentEntity == barrier then
                             barrier:destroy()
                         end
                     end)
                else
                     print("WARNING: TimerSystem not found. Mystic Barrier duration may not function correctly.")
                     -- Fallback: No automatic removal, or relies on manual cleanup
                end
    
                print(caster.unitType:upper() .. " created a Mystic Barrier at (" .. x .. "," .. y .. ")!")
                return true
            end
        },
    
        arcane_bolt = {
            id = "arcane_bolt",
            name = "Arcane Bolt",
            description = "Long-attackRange attack that ignores defense",
            icon = nil,
            energyCost = 4,
            actionPointCost = 1,
            cooldown = 2,
            targetType = "enemy",
            attackRange = 5,
            unitType = "bishop",
            onUse = function(caster, target, x, y, grid) -- x,y are target's coords
                if not target or target.faction == caster.faction or not target.stats then
                     print("Arcane Bolt: Invalid target.")
                    return false
                end
    
                -- Calculate distance
                local distance = math.abs(caster.x - target.x) + math.abs(caster.y - target.y)
                if distance > self.attackRange then
                     print("Arcane Bolt: Target out of attackRange.")
                    return false
                end
    
                -- Deal damage ignoring defense
                local damage = caster.stats.attack -- Or maybe a different stat like 'magic'?
    
                if self.game and self.game.combatSystem then
                    self.game.combatSystem:applyDirectDamage(target, damage, {
                        source = "ability",
                        ability = self.id,
                        caster = caster,
                        ignoreDefense = true,
                        isCritical = false,
                        isMiss = false -- Or maybe it can miss based on accuracy vs dodge?
                    })
                     print(caster.unitType:upper() .. " hit " .. target.unitType .. " with Arcane Bolt for " .. damage .. " damage!")
                     return true
                else
                    print("WARNING: CombatSystem not found, cannot apply Arcane Bolt damage.")
                    -- Fallback direct damage
                    -- target.stats.health = math.max(0, target.stats.health - damage)
                    -- print(caster.unitType:upper() .. " hit " .. target.unitType .. " with Arcane Bolt for " .. damage .. " damage! (Direct)")
                    -- return true
                    return false -- Fail if damage system missing
                end
            end
        },
    
        -- PAWN ABILITIES
    
        shield_bash = {
            id = "shield_bash",
            name = "Shield Bash",
            description = "Damage and potentially stun an adjacent enemy",
            icon = nil,
            energyCost = 3,
            actionPointCost = 1,
            cooldown = 3,
            targetType = "enemy",
            attackRange = 1, -- Adjacent only
            unitType = "pawn",
            onUse = function(caster, target, x, y, grid) -- x,y are target's coords
                if not target or target.faction == caster.faction or not target.stats then
                    print("Shield Bash: Invalid target.")
                    return false
                end
    
                -- Check if target is adjacent
                local distance = math.abs(caster.x - target.x) + math.abs(caster.y - target.y)
                if distance > self.attackRange then -- attackRange is 1 for adjacent
                    print("Shield Bash: Target not adjacent.")
                    return false
                end
    
                -- 1. Deal damage
                local damage = math.ceil(caster.stats.attack * 0.5)
                local damageSuccess = false
                if self.game and self.game.combatSystem then
                    self.game.combatSystem:applyDirectDamage(target, damage, {
                        source = "ability",
                        ability = self.id,
                        caster = caster,
                        isCritical = false,
                        isMiss = false
                    })
                    print(caster.unitType:upper() .. " dealt " .. damage .. " damage to " .. target.unitType .. " with Shield Bash.")
                    damageSuccess = true
                else
                    print("WARNING: CombatSystem not found, cannot apply Shield Bash damage.")
                    -- Fallback direct damage
                    -- target.stats.health = math.max(0, target.stats.health - damage)
                    -- print(caster.unitType:upper() .. " dealt " .. damage .. " damage to " .. target.unitType .. " with Shield Bash (Direct).")
                    -- damageSuccess = true
                end
    
                -- Check if target survived damage before stunning
                if not target or not target.stats or target.stats.health <= 0 then
                    print(target.unitType .. " was defeated by Shield Bash.")
                    return damageSuccess -- Return true if damage happened
                end
    
                -- 2. Apply stun
                local stunSuccess = false
                if self.game and self.game.statusEffectsSystem then
                     -- Duration might be 1 turn, handled by effect definition
                    stunSuccess = self.game.statusEffectsSystem:applyEffect(target, "stunned", caster) -- ApplyEffect might return true/false
                    if stunSuccess then
                        print(target.unitType .. " is stunned!")
                    else
                        print(target.unitType .. " resisted stun.") -- E.g., if immune
                    end
                else
                    print("WARNING: StatusEffectsSystem not found, cannot apply Stun effect.")
                end
    
                print(caster.unitType:upper() .. " used Shield Bash!")
                return damageSuccess or stunSuccess -- Return true if either damage or stun was applied
            end
        },
    
        advance = {
            id = "advance",
            name = "Advance",
            description = "Move one step forward and gain temporary attack boost",
            icon = nil,
            energyCost = 2,
            actionPointCost = 1,
            cooldown = 2,
            targetType = "self",
            attackRange = 0, -- Movement is fixed relative to self
            unitType = "pawn",
            onUse = function(caster, target, x, y, grid) -- target is caster, x,y are nil
                -- Determine forward direction based on faction
                local dx = 0
                local dy = (caster.faction == "player") and -1 or 1 -- Player moves up (-Y), Enemy moves down (+Y)
    
                local newX = caster.x + dx
                local newY = caster.y + dy
    
                -- Check if position is valid and in bounds
                if not grid:isInBounds(newX, newY) then
                    print("Advance: Cannot move forward, boundary reached.")
                    return false
                end
    
                -- Check if position is empty
                if grid:getEntityAt(newX, newY) then
                     print("Advance: Cannot move forward, position blocked.")
                    return false
                end
    
                -- Use moveTo to handle position change and animation
                local moveSuccess = caster:moveTo(newX, newY)
    
                if moveSuccess then
                    -- Apply attack boost status effect *after* successful move
                    if self.game and self.game.statusEffectsSystem then
                        -- Assuming 'empowered' increases attack, duration handled by effect
                        self.game.statusEffectsSystem:applyEffect(caster, "empowered", caster)
                         print("Gained Empowered buff.")
                    else
                        print("WARNING: StatusEffectsSystem not found, cannot apply Empowered buff.")
                    end
    
                    print(caster.unitType:upper() .. " used Advance!")
                    return true -- Ability use was successful
                else
                    -- moveTo failed
                    print(caster.unitType:upper() .. " failed to Advance (moveTo returned false).")
                    return false -- Ability use failed
                end
            end
        },
    
        promotion = {
            id = "promotion",
            name = "Promotion",
            description = "Transform into a stronger unit (Queen) at the cost of health",
            icon = nil,
            energyCost = 8,
            actionPointCost = 1,
            cooldown = 0, -- Can only be used once (needs mechanism to track usage or remove ability)
            targetType = "self",
            attackRange = 0,
            unitType = "pawn",
            onUse = function(caster, target, x, y, grid) -- target is caster
                -- Check usage limit (this ability should probably be removed after use)
                if caster.promoted then -- Add a flag to the caster instance
                     print("Promotion: Already promoted.")
                     return false
                end
    
                -- Check if pawn is on the back rank (optional, common chess rule)
                local backRankY = (caster.faction == "player") and 0 or (grid:getHeight() - 1) -- Assuming 0-indexed grid
                if caster.y ~= backRankY then
                     print("Promotion: Must be on the back rank to promote.")
                     -- return false -- Enable this check if required by game rules
                end
    
                -- Check health cost
                local healthCost = math.ceil(caster.stats.maxHealth * 0.5) -- Cost is 50% of *max* health
                if caster.stats.health <= healthCost then
                    print("Promotion: Not enough health to promote (requires > " .. healthCost .. ").")
                    return false
                end
    
                -- Apply health cost
                if self.game and self.game.combatSystem then
                     self.game.combatSystem:applyDirectDamage(caster, healthCost, {
                         source = "ability",
                         ability = self.id,
                         caster = caster,
                         ignoreDefense = true, -- Cost ignores defense/shields
                         bypassShields = true
                     })
                     print("Paid " .. healthCost .. " health for Promotion.")
                else
                     print("WARNING: CombatSystem not found, applying health cost directly.")
                     caster.stats.health = caster.stats.health - healthCost
                     -- Need to ensure health doesn't drop below 1 if that's a rule
                     caster.stats.health = math.max(1, caster.stats.health)
                end
    
    
                -- Change unit type and stats
                -- This is highly dependent on how units/classes are structured.
                -- Simple direct modification:
                print("Promoting Pawn to Queen...")
                caster.unitType = "queen" -- Update display/logic type
                caster.name = caster.name .. " (Queen)" -- Optional: Change instance name
    
                -- Update base stats (or apply a permanent "Promoted" status effect that grants bonuses)
                -- These values should ideally come from a "Queen" template
                caster.stats.maxHealth = caster.stats.maxHealth + 20 -- Example boost
                caster.stats.attack = caster.stats.attack + 3       -- Example boost
                caster.stats.defense = caster.stats.defense + 2     -- Example boost
                caster.stats.moveRange = 4                          -- Example Queen move attackRange
                -- Heal to new max health? Or keep current percentage? Let's keep current health for now.
                -- caster.stats.health = caster.stats.maxHealth -- Option: Full heal on promotion
    
    
                -- Update abilities (replace pawn abilities with queen abilities)
                -- Assumes queen abilities are defined elsewhere (e.g., in self.game.abilityData)
                local queenAbilityIDs = {"sovereign_wrath", "royal_decree", "strategic_repositioning"} -- Example IDs
                caster.abilities = {} -- Clear existing abilities (or filter based on type?)
                 if self.game and self.game.abilityData then
                     for _, abilityId in ipairs(queenAbilityIDs) do
                         if self.game.abilityData[abilityId] then
                            -- Add the *ID* or the full ability definition? Depends on how units store abilities. Assume ID.
                            table.insert(caster.abilities, abilityId)
                         else
                            print("Warning: Queen ability not found:", abilityId)
                         end
                     end
                 else
                     print("Warning: Ability data not found. Cannot assign Queen abilities.")
                 end
    
                -- Reset ability cooldowns
                caster.abilityCooldowns = {}
    
                -- Mark as promoted to prevent reuse
                caster.promoted = true
    
                -- Potentially remove the "promotion" ability itself from the caster's list
                for i = #caster.abilities, 1, -1 do
                    if caster.abilities[i] == self.id then
                        table.remove(caster.abilities, i)
                        break
                    end
                end
    
    
                -- Visual feedback / Log
                print(caster.name .. " used Promotion and transformed into a QUEEN!")
    
                -- Update UI / Visuals if necessary
                if caster.sprite then
                    -- caster.sprite:loadTexture("path/to/queen_sprite.png") -- Example
                end
    
                return true
            end
        },
    
        -- GENERIC ABILITIES (add unitType = nil for consistency)
    
        fireball = {
            id = "fireball",
            name = "Fireball",
            description = "Launch a fireball dealing area damage.",
            icon = nil,
            energyCost = 3,
            actionPointCost = 1,
            cooldown = 2,
            attackRange = 3,
            targetType = "position", -- Target ground/unit
            unitType = nil, -- Generic ability, usable by units assigned it
            onUse = function(caster, target, x, y, grid) -- target is entity at x,y, or nil
                -- Validate target position (already checked by core system before calling onUse, but double check)
                if not x or not y or not grid:isInBounds(x, y) then return false end
    
                local primaryDamage = 5
                local splashDamage = 2
                local actionSuccess = false
    
                -- Apply damage to primary target (if it's a unit)
                if target and target.stats and target.faction ~= caster.faction then -- Check if target is an enemy unit
                    if self.game and self.game.combatSystem then
                        self.game.combatSystem:applyDirectDamage(target, primaryDamage, {
                            source = "ability", ability = self.id, caster = caster })
                        print(target.unitType .. " took " .. primaryDamage .. " primary damage from Fireball.")
                        actionSuccess = true
                    else
                        print("WARNING: CombatSystem not found for Fireball primary damage.")
                    end
                elseif target and target.stats and target.faction == caster.faction then
                     -- Hit an ally with primary target? Maybe reduce damage? Or allow friendly fire?
                     print("Fireball hit an allied unit: " .. target.unitType)
                     -- Decide if friendly fire applies
                end
    
    
                -- Apply splash damage to adjacent tiles (excluding center)
                 local adjacentOffsets = { {dx = -1, dy = 0}, {dx = 1, dy = 0}, {dx = 0, dy = -1}, {dx = 0, dy = 1},
                                          {dx = -1, dy = -1}, {dx = 1, dy = -1}, {dx = -1, dy = 1}, {dx = 1, dy = 1} } -- 8 directions
                for _, offset in ipairs(adjacentOffsets) do
                    local splashX = x + offset.dx
                    local splashY = y + offset.dy
    
                    if grid:isInBounds(splashX, splashY) then
                        local adjacentEntity = grid:getEntityAt(splashX, splashY)
                        -- Only damage enemy units in splash zone
                        if adjacentEntity and adjacentEntity.stats and adjacentEntity.faction ~= caster.faction then
                            if self.game and self.game.combatSystem then
                                self.game.combatSystem:applyDirectDamage(adjacentEntity, splashDamage, {
                                    source = "ability", ability = self.id, caster = caster, isSplash = true })
                                 print(adjacentEntity.unitType .. " took " .. splashDamage .. " splash damage from Fireball.")
                                 actionSuccess = true -- Mark success if splash hits
                            else
                                 print("WARNING: CombatSystem not found for Fireball splash damage.")
                            end
                        end
                    end
                end
    
                -- Visual effect
                print("Fireball visual effect detonated at " .. x .. "," .. y)
    
                return actionSuccess -- Return true if any damage was dealt
            end
        },
    
        heal = {
            id = "heal",
            name = "Heal",
            description = "Restore health to an allied unit.",
            icon = nil,
            energyCost = 2,
            actionPointCost = 1,
            cooldown = 1,
            attackRange = 2,
            targetType = "ally", -- Only targets allies
            unitType = nil, -- Generic
            onUse = function(caster, target, x, y, grid) -- target is the allied unit
                if not target or target.faction ~= caster.faction or not target.stats then
                    print("Heal: Invalid target (not an ally or no stats).")
                    return false -- Should be caught by targetType, but double check
                end
    
                -- Check attackRange (Should be caught by core system, but double check)
                local distance = math.abs(caster.x - target.x) + math.abs(caster.y - target.y)
                if distance > self.attackRange then
                    print("Heal: Target out of attackRange.")
                    return false
                end
    
                -- Apply healing
                local healAmount = 5 -- Or based on caster stat?
                local healed = 0
                if self.game and self.game.combatSystem then
                    healed = self.game.combatSystem:applyHealing(target, healAmount, {
                        source = "ability", ability = self.id, caster = caster })
                     if healed > 0 then
                        print(caster.unitType .. " healed " .. target.unitType .. " for " .. healed .. " health.")
                     else
                         print(target.unitType .. " is already at full health.")
                     end
                     -- Visual effect
                     print("Heal visual effect on " .. target.unitType)
                     return true -- Success even if target was full health
                else
                    print("WARNING: CombatSystem not found, cannot apply Heal.")
                    return false
                end
            end
        },
    
        teleport = {
            id = "teleport",
            name = "Teleport",
            description = "Instantly move to an empty tile within attackRange.",
            icon = nil,
            energyCost = 4,
            actionPointCost = 1,
            cooldown = 3,
            attackRange = 5,
            targetType = "position", -- Target empty tile
            unitType = nil, -- Generic
            onUse = function(caster, target, x, y, grid) -- target is nil (or maybe entity if mis-targeted?)
                 -- Check if tile is valid and empty (Core system should validate this based on targetType, but check again)
                if not x or not y or not grid:isInBounds(x, y) then
                     print("Teleport: Target position out of bounds.")
                    return false
                end
                if grid:getEntityAt(x, y) then
                     print("Teleport: Target position is occupied.")
                    return false -- Cannot teleport to occupied tile
                end
    
                 -- Check attackRange
                local distance = math.abs(caster.x - x) + math.abs(caster.y - y)
                if distance > self.attackRange then
                     print("Teleport: Target position out of attackRange.")
                    return false
                end
                 if distance == 0 then
                     print("Teleport: Cannot teleport to current position.")
                     return false
                 end
    
                -- Use moveTo for teleportation (assuming moveTo handles instant movement/animation type)
                local oldX, oldY = caster.x, caster.y
                local moveSuccess = caster:moveTo(x, y) -- Pass target coordinates
    
                if moveSuccess then
                    -- Visual effect
                    print(caster.unitType .. " teleported from " .. oldX .. "," .. oldY .. " to " .. x .. "," .. y)
                    return true
                else
                    print(caster.unitType .. " failed to Teleport (moveTo returned false).")
                    return false
                end
            end
        },
    
        strengthen = {
            id = "strengthen",
            name = "Strengthen",
            description = "Increase target ally's attack for 2 turns.",
            icon = nil,
            energyCost = 3,
            actionPointCost = 1,
            cooldown = 3,
            attackRange = 1, -- Close attackRange buff
            targetType = "ally",
            unitType = nil, -- Generic
            onUse = function(caster, target, x, y, grid) -- target is the allied unit
                if not target or target.faction ~= caster.faction or not target.stats then
                    print("Strengthen: Invalid target.")
                    return false
                end
    
                -- Check attackRange
                local distance = math.abs(caster.x - target.x) + math.abs(caster.y - target.y)
                if distance > self.attackRange then
                    print("Strengthen: Target out of attackRange.")
                    return false
                end
    
                -- Apply buff using status effect system
                if self.game and self.game.statusEffectsSystem then
                     -- Assuming effect "strengthened" exists and handles attack bonus + duration
                     -- Pass parameters if the effect definition needs them
                    local success = self.game.statusEffectsSystem:applyEffect(target, "strengthened", caster, { duration = 2, attackBonus = 2 })
                    if success then
                        print(target.unitType .. "'s attack increased for 2 turns.")
                        -- Visual effect
                        print("Strengthen visual effect on " .. target.unitType)
                        return true
                    else
                        print("Failed to apply Strengthen effect (maybe resisted or system error).")
                        return false
                    end
                else
                    print("WARNING: StatusEffectsSystem not found, cannot apply Strengthen buff.")
                    return false
                end
            end
        },
    
        shield = {
            id = "shield",
            name = "Shield",
            description = "Gain increased defense until your next turn.",
            icon = nil,
            energyCost = 2,
            actionPointCost = 1,
            cooldown = 2,
            attackRange = 0,
            targetType = "self",
            unitType = nil, -- Generic
            onUse = function(caster, target, x, y, grid) -- target is caster
                 -- Apply buff using status effect system
                if self.game and self.game.statusEffectsSystem then
                    -- Assuming effect "shielded" exists and handles defense bonus + duration (1 turn)
                    local success = self.game.statusEffectsSystem:applyEffect(caster, "shielded", caster, { duration = 1, defenseBonus = 3 })
                     if success then
                        print(caster.unitType .. " gained increased defense until next turn.")
                        -- Visual effect
                        print("Shield visual effect on " .. caster.unitType)
                        return true
                     else
                        print("Failed to apply Shield effect.")
                        return false
                     end
                else
                    print("WARNING: StatusEffectsSystem not found, cannot apply Shield buff.")
                    return false
                end
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
    
    -- Check attackRange
    if ability.attackRange > 0 then
        local distance = math.abs(unit.x - x) + math.abs(unit.y - y)
        if distance > ability.attackRange then
            print("Target is out of attackRange")
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

-- Use an ability (MODIFIED: Trigger animation)
function SpecialAbilitiesSystem:useAbility(unit, abilityId, target, x, y, grid)
    local ability = self:getAbility(abilityId)
    if not ability then
        print("Ability not found: " .. abilityId)
        return false
    end
    
    -- Check if ability can be used (already includes AP/cooldown checks via unit:canUseAbility)
    -- We re-check here just before execution for safety, though unit:canUseAbility should be the primary gate
    local canUse, reason = unit:canUseAbility(abilityId, target, x, y)
     if not canUse then
         print("Cannot use ability: " .. abilityId .. " Reason: " .. (reason or 'Unknown'))
         return false, reason or "Cannot use ability"
     end

     -- *** ADD: Trigger Animation ***
    local animationManager = self.game.animationManager
    local targetPosition = nil
    if x and y then targetPosition = {x=x, y=y} end -- Create position table if coords exist

    if animationManager then
        -- *** FIX: Call method on the instance using ':' ***
        local specificAnimationFunc = animationManager:getAbilityAnimation(abilityId)
        -- *** END FIX ***

        if specificAnimationFunc then
            print("Triggering specific animation for:", abilityId)
            -- Call the specific function (it's already retrieved)
            specificAnimationFunc(unit, targetPosition, animationManager)
        else
            print("Triggering generic animation for:", abilityId)
            local genericAbilityType = "default" -- Determine type...
            if ability.name:find("Heal") or ability.name:find("Bless") then genericAbilityType = "support" elseif ability.name:find("Shield") or ability.name:find("Fortify") or ability.name:find("Skin") then genericAbilityType = "defense" elseif ability.name:find("Charge") or ability.name:find("Bash") or ability.name:find("Bolt") or ability.name:find("Wrath") then genericAbilityType = "attack" end
            animationManager:createAbilityAnimation(unit, genericAbilityType, targetPosition, grid, function() unit.animationState = "idle" end)
        end
        unit.animationState = "casting"
    else
        print("WARNING: AnimationManager not found, skipping ability animation.")
    end
    -- *** END ADD ***
    
    -- Apply energy cost
    -- unit.energy = math.max(0, unit.energy - ability.energyCost) -- This should be handled by unit:useAbility
    -- unit.stats.energy = unit.energy
    if unit.useEnergy then unit:useEnergy(ability.energyCost or 0) end -- Use unit method if exists

    -- Apply cooldown
    unit:setAbilityCooldown(abilityId, ability.cooldown or 0)

    -- Mark as having used an ability this turn
    unit.hasUsedAbility = true
    -- Deduct Action Point via TurnManager
    if self.game.turnManager then
        self.game.turnManager:useActionPoints(ability.actionPointCost or 1)
    end

    -- Execute ability effect
    local success = false
    if ability.onUse then
        -- Pass 'self' (SpecialAbilitiesSystem instance) if onUse needs it
        success = ability.onUse(unit, target, x, y, grid)
    else
        print("Warning: Ability " .. abilityId .. " has no onUse function.")
        success = true -- Assume success if no function, but log warning
    end

    -- Check if any units were defeated (CombatSystem should handle this via damage application)
    -- if self.game.combatSystem and self.game.combatSystem.checkDefeat then
    --    self.game.combatSystem:checkDefeat(target)
    --    self.game.combatSystem:checkDefeat(unit) -- If self-damage possible
    -- end

    return success -- Return success of the ability's *logic*
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
    
    -- Get targets based on ability target type and attackRange
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
                    if distance <= ability.attackRange then
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
                    if distance <= ability.attackRange then
                        table.insert(targets, {x = x, y = y, unit = entity})
                    end
                end
            end
        end
    elseif ability.targetType == "position" then
        -- Position-targeted ability
        for y = math.max(1, unit.y - ability.attackRange), math.min(grid.height, unit.y + ability.attackRange) do
            for x = math.max(1, unit.x - ability.attackRange), math.min(grid.width, unit.x + ability.attackRange) do
                -- Check if within attackRange (Manhattan distance)
                local distance = math.abs(unit.x - x) + math.abs(unit.y - y)
                if distance <= ability.attackRange then
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
        print("   Range: " .. (ability.attackRange or 0))
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