-- Special Abilities System for Nightfall Chess
-- Handles creation, management, and execution of special abilities for units

local class = require("lib.middleclass.middleclass")

local SpecialAbilitiesSystem = class("SpecialAbilitiesSystem")

function SpecialAbilitiesSystem:initialize(game)
    self.game = game
    
    -- Special ability definitions
    self.abilities = {
        -- KNIGHT COMMANDER ABILITIES
        
        -- Royal Guard: Reduces damage taken by adjacent allies by 50% for 2 turns
        royal_guard = {
            name = "Royal Guard",
            description = "Reduces damage taken by adjacent allies by 50% for 2 turns",
            icon = nil, -- Would be an image in a full implementation
            energyCost = 3,
            actionPointCost = 1,
            cooldown = 3,
            targetType = "self",
            range = 0,
            unitType = "king",
            onUse = function(user, target, x, y)
                -- Apply effect to all adjacent allies
                local allies = self:getAdjacentAllies(user)
                
                for _, ally in ipairs(allies) do
                    -- Apply protected status effect
                    if self.game.statusEffectsSystem then
                        self.game.statusEffectsSystem:applyEffect(ally, "shielded", user)
                    end
                    
                    -- Visual feedback
                    if self.game.ui then
                        self.game.ui:showNotification(ally.unitType:upper() .. " is protected by Royal Guard!", 1.5)
                    end
                end
                
                -- Visual effect for the user
                if self.game.ui then
                    self.game.ui:showNotification("Royal Guard activated!", 1.5)
                end
                
                return true
            end
        },
        
        -- Tactical Command: Target ally gains an extra action point
        tactical_command = {
            name = "Tactical Command",
            description = "Target ally gains an extra action point",
            icon = nil,
            energyCost = 2,
            actionPointCost = 1,
            cooldown = 2,
            targetType = "ally",
            range = 3,
            unitType = "king",
            onUse = function(user, target, x, y)
                if not target or target.faction ~= user.faction then
                    return false
                end
                
                -- Grant extra action point
                if self.game.turnManager then
                    self.game.turnManager:grantExtraActionPoint(target, 1)
                else
                    target.actionPoints = (target.actionPoints or 0) + 1
                end
                
                -- Visual feedback
                if self.game.ui then
                    self.game.ui:showNotification(target.unitType:upper() .. " gains an extra action point!", 1.5)
                end
                
                return true
            end
        },
        
        -- Inspiring Presence: All allies gain +2 attack for 3 turns
        inspiring_presence = {
            name = "Inspiring Presence",
            description = "All allies gain +2 attack for 3 turns",
            icon = nil,
            energyCost = 4,
            actionPointCost = 2,
            cooldown = 4,
            targetType = "self",
            range = 0,
            unitType = "king",
            onUse = function(user, target, x, y)
                -- Apply effect to all allies on the board
                local allies = self:getAllAllies(user)
                
                for _, ally in ipairs(allies) do
                    -- Store original attack
                    ally.originalAttack = ally.stats.attack
                    
                    -- Increase attack
                    ally.stats.attack = ally.stats.attack + 2
                    
                    -- Register temporary effect
                    if self.game.turnManager then
                        self.game.turnManager:registerUnitStatusEffect(ally, "inspiringPresence", {
                            name = "Inspired",
                            description = "Attack increased by 2",
                            duration = 3,
                            triggerOn = "turnStart",
                            onRemove = function(unit)
                                if unit.originalAttack then
                                    unit.stats.attack = unit.originalAttack
                                    unit.originalAttack = nil
                                end
                            end
                        })
                    end
                    
                    -- Visual feedback
                    if self.game.ui then
                        self.game.ui:showNotification(ally.unitType:upper() .. " is inspired!", 1)
                    end
                end
                
                -- Visual effect for the user
                if self.game.ui then
                    self.game.ui:showNotification("Inspiring Presence activated!", 1.5)
                end
                
                return true
            end
        },
        
        -- ROOK GUARDIAN ABILITIES
        
        -- Fortify: Increases defense by 3 for 3 turns
        fortify = {
            name = "Fortify",
            description = "Increases defense by 3 for 3 turns",
            icon = nil,
            energyCost = 2,
            actionPointCost = 1,
            cooldown = 2,
            targetType = "self",
            range = 0,
            unitType = "rook",
            onUse = function(user, target, x, y)
                -- Store original defense
                user.originalDefense = user.stats.defense
                
                -- Increase defense
                user.stats.defense = user.stats.defense + 3
                
                -- Register temporary effect
                if self.game.turnManager then
                    self.game.turnManager:registerUnitStatusEffect(user, "fortify", {
                        name = "Fortified",
                        description = "Defense increased by 3",
                        duration = 3,
                        triggerOn = "turnStart",
                        onRemove = function(unit)
                            if unit.originalDefense then
                                unit.stats.defense = unit.originalDefense
                                unit.originalDefense = nil
                            end
                        end
                    })
                end
                
                -- Visual feedback
                if self.game.ui then
                    self.game.ui:showNotification(user.unitType:upper() .. " is fortified!", 1.5)
                end
                
                return true
            end
        },
        
        -- Shockwave: Damages all enemies in a straight line
        shockwave = {
            name = "Shockwave",
            description = "Damages all enemies in a straight line",
            icon = nil,
            energyCost = 3,
            actionPointCost = 1,
            cooldown = 3,
            targetType = "direction",
            range = 4,
            unitType = "rook",
            onUse = function(user, target, x, y)
                -- Calculate direction
                local dx = 0
                local dy = 0
                
                if x > user.x then dx = 1
                elseif x < user.x then dx = -1 end
                
                if y > user.y then dy = 1
                elseif y < user.y then dy = -1 end
                
                -- If no valid direction, return false
                if dx == 0 and dy == 0 then
                    return false
                end
                
                -- Find all enemies in the line
                local enemies = {}
                local currentX = user.x + dx
                local currentY = user.y + dy
                local distance = 1
                
                while distance <= self.range do
                    -- Check if position is valid
                    if not self.game.grid:isValidPosition(currentX, currentY) then
                        break
                    end
                    
                    -- Check if there's an entity at this position
                    local entity = self.game.grid:getEntityAt(currentX, currentY)
                    if entity and entity.faction ~= user.faction then
                        table.insert(enemies, entity)
                    end
                    
                    -- Move to next position in the line
                    currentX = currentX + dx
                    currentY = currentY + dy
                    distance = distance + 1
                end
                
                -- Apply damage to all enemies in the line
                local baseDamage = user.stats.attack * 1.5
                
                for _, enemy in ipairs(enemies) do
                    if self.game.combatSystem then
                        self.game.combatSystem:applyDamage(user, enemy, baseDamage, {
                            source = "ability",
                            ability = "shockwave",
                            isCritical = false,
                            isMiss = false
                        })
                    else
                        enemy.stats.health = math.max(0, enemy.stats.health - baseDamage)
                    end
                    
                    -- Visual feedback
                    if self.game.ui then
                        self.game.ui:showNotification(enemy.unitType:upper() .. " hit by Shockwave!", 1)
                    end
                end
                
                -- Visual effect for the ability
                if self.game.ui then
                    self.game.ui:showNotification("Shockwave released!", 1.5)
                end
                
                return true
            end
        },
        
        -- Stone Skin: Becomes immune to status effects for 2 turns
        stone_skin = {
            name = "Stone Skin",
            description = "Becomes immune to status effects for 2 turns",
            icon = nil,
            energyCost = 3,
            actionPointCost = 1,
            cooldown = 4,
            targetType = "self",
            range = 0,
            unitType = "rook",
            onUse = function(user, target, x, y)
                -- Set status immunity flag
                user.immuneToStatusEffects = true
                
                -- Register temporary effect
                if self.game.turnManager then
                    self.game.turnManager:registerUnitStatusEffect(user, "stoneSkin", {
                        name = "Stone Skin",
                        description = "Immune to status effects",
                        duration = 2,
                        triggerOn = "turnStart",
                        onRemove = function(unit)
                            unit.immuneToStatusEffects = nil
                        end
                    })
                end
                
                -- Clear existing negative status effects
                if self.game.statusEffectsSystem then
                    self.game.statusEffectsSystem:clearEffectsByCategory(user, "negative")
                end
                
                -- Visual feedback
                if self.game.ui then
                    self.game.ui:showNotification(user.unitType:upper() .. " activates Stone Skin!", 1.5)
                end
                
                return true
            end
        },
        
        -- BISHOP MYSTIC ABILITIES
        
        -- Arcane Bolt: Ranged attack that ignores defense
        arcane_bolt = {
            name = "Arcane Bolt",
            description = "Ranged attack that ignores defense",
            icon = nil,
            energyCost = 2,
            actionPointCost = 1,
            cooldown = 1,
            targetType = "enemy",
            range = 3,
            unitType = "bishop",
            onUse = function(user, target, x, y)
                if not target or target.faction == user.faction then
                    return false
                end
                
                -- Calculate damage (ignores defense)
                local damage = user.stats.attack * 1.2
                
                -- Apply damage
                if self.game.combatSystem then
                    self.game.combatSystem:applyDirectDamage(target, damage, {
                        source = "ability",
                        ability = "arcane_bolt",
                        isCritical = false,
                        isMiss = false
                    })
                else
                    target.stats.health = math.max(0, target.stats.health - damage)
                end
                
                -- Visual feedback
                if self.game.ui then
                    self.game.ui:showNotification("Arcane Bolt hits " .. target.unitType:upper() .. "!", 1.5)
                end
                
                return true
            end
        },
        
        -- Healing Light: Restores 8 health to target ally
        healing_light = {
            name = "Healing Light",
            description = "Restores 8 health to target ally",
            icon = nil,
            energyCost = 3,
            actionPointCost = 1,
            cooldown = 2,
            targetType = "ally",
            range = 3,
            unitType = "bishop",
            onUse = function(user, target, x, y)
                if not target or target.faction ~= user.faction then
                    return false
                end
                
                -- Calculate healing amount
                local healAmount = 8
                
                -- Apply healing
                if self.game.combatSystem then
                    self.game.combatSystem:applyHealing(target, healAmount, {
                        source = "ability",
                        ability = "healing_light"
                    })
                else
                    target.stats.health = math.min(target.stats.maxHealth, target.stats.health + healAmount)
                end
                
                -- Visual feedback
                if self.game.ui then
                    self.game.ui:showNotification(target.unitType:upper() .. " healed for " .. healAmount .. " HP!", 1.5)
                end
                
                return true
            end
        },
        
        -- Mystic Barrier: Creates a protective field that blocks 1 attack
        mystic_barrier = {
            name = "Mystic Barrier",
            description = "Creates a protective field that blocks 1 attack",
            icon = nil,
            energyCost = 4,
            actionPointCost = 1,
            cooldown = 4,
            targetType = "ally",
            range = 2,
            unitType = "bishop",
            onUse = function(user, target, x, y)
                if not target or target.faction ~= user.faction then
                    return false
                end
                
                -- Apply barrier effect
                target.hasBarrier = true
                
                -- Hook into damage calculation
                target.originalTakeDamage = target.takeDamage
                target.takeDamage = function(self, damage, source)
                    if self.hasBarrier then
                        -- Block the attack
                        self.hasBarrier = nil
                        
                        -- Visual feedback
                        if self.game.ui then
                            self.game.ui:showNotification("Mystic Barrier blocks the attack!", 1.5)
                        end
                        
                        return 0
                    end
                    
                    -- Normal damage calculation
                    return self.originalTakeDamage(self, damage, source)
                end
                
                -- Register effect removal after 3 turns if not used
                if self.game.turnManager then
                    self.game.turnManager:registerUnitStatusEffect(target, "mysticBarrier", {
                        name = "Mystic Barrier",
                        description = "Blocks the next attack",
                        duration = 3,
                        triggerOn = "turnStart",
                        onRemove = function(unit)
                            unit.hasBarrier = nil
                            if unit.originalTakeDamage then
                                unit.takeDamage = unit.originalTakeDamage
                                unit.originalTakeDamage = nil
                            end
                        end
                    })
                end
                
                -- Visual feedback
                if self.game.ui then
                    self.game.ui:showNotification("Mystic Barrier protects " .. target.unitType:upper() .. "!", 1.5)
                end
                
                return true
            end
        },
        
        -- PAWN VANGUARD ABILITIES
        
        -- Shield Bash: Stuns target for 1 turn
        shield_bash = {
            name = "Shield Bash",
            description = "Stuns target for 1 turn",
            icon = nil,
            energyCost = 2,
            actionPointCost = 1,
            cooldown = 3,
            targetType = "enemy",
            range = 1, -- Adjacent only
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
                
                -- Apply stun effect
                if self.game.statusEffectsSystem then
                    self.game.statusEffectsSystem:applyEffect(target, "stunned", user)
                end
                
                -- Deal minor damage
                local damage = user.stats.attack * 0.5
                if self.game.combatSystem then
                    self.game.combatSystem:applyDamage(user, target, damage, {
                        source = "ability",
                        ability = "shield_bash",
                        isCritical = false,
                        isMiss = false
                    })
                else
                    target.stats.health = math.max(0, target.stats.health - damage)
                end
                
                -- Visual feedback
                if self.game.ui then
                    self.game.ui:showNotification(target.unitType:upper() .. " is stunned by Shield Bash!", 1.5)
                end
                
                return true
            end
        },
        
        -- Advance: Move 2 squares forward and attack
        advance = {
            name = "Advance",
            description = "Move 2 squares forward and attack",
            icon = nil,
            energyCost = 3,
            actionPointCost = 2,
            cooldown = 2,
            targetType = "direction",
            range = 2,
            unitType = "pawn",
            onUse = function(user, target, x, y)
                -- Determine forward direction based on faction
                local dx = 0
                local dy = 0
                
                if user.faction == "player" then
                    -- Assuming player pawns move up
                    dy = -1
                else
                    -- Assuming enemy pawns move down
                    dy = 1
                end
                
                -- Calculate target position
                local targetX = user.x
                local targetY = user.y + (dy * 2)
                
                -- Check if position is valid
                if not self.game.grid:isValidPosition(targetX, targetY) then
                    return false
                end
                
                -- Check if position is occupied
                if self.game.grid:getEntityAt(targetX, targetY) then
                    return false
                end
                
                -- Move to the position
                local originalX = user.x
                local originalY = user.y
                user.x = targetX
                user.y = targetY
                
                -- Update grid
                self.game.grid:moveEntity(user, originalX, originalY, targetX, targetY)
                
                -- Check for enemies in attack range (diagonally forward)
                local attackPositions = {
                    {targetX - 1, targetY + dy},
                    {targetX + 1, targetY + dy}
                }
                
                local attacked = false
                
                for _, pos in ipairs(attackPositions) do
                    local attackX, attackY = pos[1], pos[2]
                    
                    -- Check if position is valid
                    if self.game.grid:isValidPosition(attackX, attackY) then
                        -- Check if there's an enemy at this position
                        local entity = self.game.grid:getEntityAt(attackX, attackY)
                        if entity and entity.faction ~= user.faction then
                            -- Attack the enemy
                            if self.game.combatSystem then
                                self.game.combatSystem:performAttack(user, entity)
                                attacked = true
                                break
                            end
                        end
                    end
                end
                
                -- Visual feedback
                if self.game.ui then
                    self.game.ui:showNotification(user.unitType:upper() .. " advances forward!", 1.5)
                    if attacked then
                        self.game.ui:showNotification(user.unitType:upper() .. " attacks after advancing!", 1)
                    end
                end
                
                return true
            end
        },
        
        -- Promotion: Transform into a higher-tier unit when reaching the opposite side of the map
        promotion = {
            name = "Promotion",
            description = "Transform into a higher-tier unit",
            icon = nil,
            energyCost = 5,
            actionPointCost = 2,
            cooldown = 0, -- Can only be used once
            targetType = "self",
            range = 0,
            unitType = "pawn",
            onUse = function(user, target, x, y)
                -- Check if pawn is at the opposite side of the board
                local isAtPromotionRank = false
                
                if user.faction == "player" and user.y == 0 then
                    isAtPromotionRank = true
                elseif user.faction == "enemy" and user.y == self.game.grid.height - 1 then
                    isAtPromotionRank = true
                end
                
                if not isAtPromotionRank then
                    if self.game.ui then
                        self.game.ui:showNotification("Must be at the opposite side of the board to promote!", 1.5)
                    end
                    return false
                end
                
                -- Show promotion options
                local promotionOptions = {"queen", "rook", "bishop", "knight"}
                
                -- In a real implementation, this would show a UI for the player to choose
                -- For now, we'll just promote to a queen
                local promotionChoice = "queen"
                
                -- Transform the pawn
                user.unitType = promotionChoice
                
                -- Update stats based on new unit type
                if promotionChoice == "queen" then
                    user.stats.attack = user.stats.attack + 4
                    user.stats.defense = user.stats.defense - 1
                    user.stats.moveRange = 3
                    user.stats.attackRange = 3
                elseif promotionChoice == "rook" then
                    user.stats.attack = user.stats.attack + 3
                    user.stats.defense = user.stats.defense + 1
                    user.stats.moveRange = 3
                    user.stats.attackRange = 2
                elseif promotionChoice == "bishop" then
                    user.stats.attack = user.stats.attack + 2
                    user.stats.defense = user.stats.defense - 2
                    user.stats.moveRange = 2
                    user.stats.attackRange = 2
                elseif promotionChoice == "knight" then
                    user.stats.attack = user.stats.attack + 2
                    user.stats.defense = user.stats.defense + 0
                    user.stats.moveRange = 2
                    user.stats.attackRange = 1
                end
                
                -- Update movement pattern
                user.movementPattern = promotionChoice
                
                -- Visual feedback
                if self.game.ui then
                    self.game.ui:showNotification("Pawn promoted to " .. promotionChoice:upper() .. "!", 2)
                end
                
                return true
            end
        },
        
        -- QUEEN SOVEREIGN ABILITIES
        
        -- Royal Decree: All allies gain +1 action point
        royal_decree = {
            name = "Royal Decree",
            description = "All allies gain +1 action point",
            icon = nil,
            energyCost = 4,
            actionPointCost = 1,
            cooldown = 4,
            targetType = "self",
            range = 0,
            unitType = "queen",
            onUse = function(user, target, x, y)
                -- Apply effect to all allies on the board
                local allies = self:getAllAllies(user)
                
                for _, ally in ipairs(allies) do
                    -- Grant extra action point
                    if self.game.turnManager then
                        self.game.turnManager:grantExtraActionPoint(ally, 1)
                    else
                        ally.actionPoints = (ally.actionPoints or 0) + 1
                    end
                    
                    -- Visual feedback
                    if self.game.ui then
                        self.game.ui:showNotification(ally.unitType:upper() .. " gains an extra action point!", 1)
                    end
                end
                
                -- Visual effect for the user
                if self.game.ui then
                    self.game.ui:showNotification("Royal Decree activated!", 1.5)
                end
                
                return true
            end
        },
        
        -- Sovereign's Wrath: Powerful attack that hits all adjacent enemies
        sovereigns_wrath = {
            name = "Sovereign's Wrath",
            description = "Powerful attack that hits all adjacent enemies",
            icon = nil,
            energyCost = 5,
            actionPointCost = 2,
            cooldown = 3,
            targetType = "self",
            range = 0,
            unitType = "queen",
            onUse = function(user, target, x, y)
                -- Get all adjacent enemies
                local adjacentPositions = {
                    {user.x - 1, user.y - 1},
                    {user.x, user.y - 1},
                    {user.x + 1, user.y - 1},
                    {user.x - 1, user.y},
                    {user.x + 1, user.y},
                    {user.x - 1, user.y + 1},
                    {user.x, user.y + 1},
                    {user.x + 1, user.y + 1}
                }
                
                local enemies = {}
                
                for _, pos in ipairs(adjacentPositions) do
                    local checkX, checkY = pos[1], pos[2]
                    
                    -- Check if position is valid
                    if self.game.grid:isValidPosition(checkX, checkY) then
                        -- Check if there's an enemy at this position
                        local entity = self.game.grid:getEntityAt(checkX, checkY)
                        if entity and entity.faction ~= user.faction then
                            table.insert(enemies, entity)
                        end
                    end
                end
                
                -- Apply damage to all adjacent enemies
                local damage = user.stats.attack * 1.5
                
                for _, enemy in ipairs(enemies) do
                    if self.game.combatSystem then
                        self.game.combatSystem:applyDamage(user, enemy, damage, {
                            source = "ability",
                            ability = "sovereigns_wrath",
                            isCritical = false,
                            isMiss = false
                        })
                    else
                        enemy.stats.health = math.max(0, enemy.stats.health - damage)
                    end
                    
                    -- Apply weakened status effect
                    if self.game.statusEffectsSystem then
                        self.game.statusEffectsSystem:applyEffect(enemy, "weakened", user)
                    end
                    
                    -- Visual feedback
                    if self.game.ui then
                        self.game.ui:showNotification(enemy.unitType:upper() .. " hit by Sovereign's Wrath!", 1)
                    end
                end
                
                -- Visual effect for the ability
                if self.game.ui then
                    self.game.ui:showNotification("Sovereign's Wrath unleashed!", 1.5)
                end
                
                return true
            end
        },
        
        -- Strategic Repositioning: Swap positions with any ally on the board
        strategic_repositioning = {
            name = "Strategic Repositioning",
            description = "Swap positions with any ally on the board",
            icon = nil,
            energyCost = 3,
            actionPointCost = 1,
            cooldown = 3,
            targetType = "ally",
            range = 999, -- Any distance
            unitType = "queen",
            onUse = function(user, target, x, y)
                if not target or target.faction ~= user.faction then
                    return false
                end
                
                -- Swap positions
                local userX, userY = user.x, user.y
                local targetX, targetY = target.x, target.y
                
                -- Update positions
                user.x, user.y = targetX, targetY
                target.x, target.y = userX, userY
                
                -- Update grid
                self.game.grid:swapEntities(user, target)
                
                -- Visual feedback
                if self.game.ui then
                    self.game.ui:showNotification(user.unitType:upper() .. " swaps positions with " .. target.unitType:upper() .. "!", 1.5)
                end
                
                return true
            end
        },
        
        -- KNIGHT ABILITIES
        
        -- Knight's Charge: Move in L-shape and deal bonus damage
        knights_charge = {
            name = "Knight's Charge",
            description = "Move in L-shape and deal bonus damage",
            icon = nil,
            energyCost = 2,
            actionPointCost = 1,
            cooldown = 2,
            targetType = "position",
            range = 3, -- L-shape movement
            unitType = "knight",
            onUse = function(user, target, x, y)
                -- Check if movement is valid L-shape
                local dx = math.abs(x - user.x)
                local dy = math.abs(y - user.y)
                
                if not ((dx == 1 and dy == 2) or (dx == 2 and dy == 1)) then
                    return false
                end
                
                -- Check if position is valid
                if not self.game.grid:isValidPosition(x, y) then
                    return false
                end
                
                -- Check if there's an entity at the target position
                local entity = self.game.grid:getEntityAt(x, y)
                
                if entity then
                    -- If it's an enemy, attack with bonus damage
                    if entity.faction ~= user.faction then
                        local damage = user.stats.attack * 1.5
                        
                        if self.game.combatSystem then
                            self.game.combatSystem:applyDamage(user, entity, damage, {
                                source = "ability",
                                ability = "knights_charge",
                                isCritical = false,
                                isMiss = false
                            })
                        else
                            entity.stats.health = math.max(0, entity.stats.health - damage)
                        end
                        
                        -- Visual feedback
                        if self.game.ui then
                            self.game.ui:showNotification("Knight's Charge hits " .. entity.unitType:upper() .. "!", 1.5)
                        end
                        
                        return true
                    else
                        -- Can't charge into ally
                        return false
                    end
                else
                    -- Move to the position
                    local originalX = user.x
                    local originalY = user.y
                    user.x = x
                    user.y = y
                    
                    -- Update grid
                    self.game.grid:moveEntity(user, originalX, originalY, x, y)
                    
                    -- Visual feedback
                    if self.game.ui then
                        self.game.ui:showNotification(user.unitType:upper() .. " performs Knight's Charge!", 1.5)
                    end
                    
                    return true
                end
            end
        },
        
        -- Feint: Move and apply confused status to adjacent enemies
        feint = {
            name = "Feint",
            description = "Move and apply confused status to adjacent enemies",
            icon = nil,
            energyCost = 3,
            actionPointCost = 1,
            cooldown = 3,
            targetType = "position",
            range = 2,
            unitType = "knight",
            onUse = function(user, target, x, y)
                -- Check if movement is valid
                local dx = math.abs(x - user.x)
                local dy = math.abs(y - user.y)
                
                if dx > 2 or dy > 2 or (dx == 0 and dy == 0) then
                    return false
                end
                
                -- Check if position is valid
                if not self.game.grid:isValidPosition(x, y) then
                    return false
                end
                
                -- Check if position is occupied
                if self.game.grid:getEntityAt(x, y) then
                    return false
                end
                
                -- Move to the position
                local originalX = user.x
                local originalY = user.y
                user.x = x
                user.y = y
                
                -- Update grid
                self.game.grid:moveEntity(user, originalX, originalY, x, y)
                
                -- Apply confused status to adjacent enemies
                local adjacentPositions = {
                    {x - 1, y - 1},
                    {x, y - 1},
                    {x + 1, y - 1},
                    {x - 1, y},
                    {x + 1, y},
                    {x - 1, y + 1},
                    {x, y + 1},
                    {x + 1, y + 1}
                }
                
                for _, pos in ipairs(adjacentPositions) do
                    local checkX, checkY = pos[1], pos[2]
                    
                    -- Check if position is valid
                    if self.game.grid:isValidPosition(checkX, checkY) then
                        -- Check if there's an enemy at this position
                        local entity = self.game.grid:getEntityAt(checkX, checkY)
                        if entity and entity.faction ~= user.faction then
                            -- Apply confused status
                            if self.game.statusEffectsSystem then
                                self.game.statusEffectsSystem:applyEffect(entity, "confused", user)
                            end
                            
                            -- Visual feedback
                            if self.game.ui then
                                self.game.ui:showNotification(entity.unitType:upper() .. " is confused by Feint!", 1)
                            end
                        end
                    end
                end
                
                -- Visual feedback
                if self.game.ui then
                    self.game.ui:showNotification(user.unitType:upper() .. " performs Feint!", 1.5)
                end
                
                return true
            end
        }
    }
    
    -- Register abilities with units
    self:registerUnitAbilities()
end

-- Register abilities with their respective unit types
function SpecialAbilitiesSystem:registerUnitAbilities()
    -- This would be called when units are created
    -- For now, we'll just prepare the ability definitions
end

-- Get all abilities for a specific unit type
function SpecialAbilitiesSystem:getAbilitiesForUnitType(unitType)
    local abilities = {}
    
    for id, ability in pairs(self.abilities) do
        if ability.unitType == unitType then
            abilities[id] = ability
        end
    end
    
    return abilities
end

-- Get a specific ability by ID
function SpecialAbilitiesSystem:getAbility(abilityId)
    return self.abilities[abilityId]
end

-- Use an ability
function SpecialAbilitiesSystem:useAbility(user, abilityId, target, x, y)
    local ability = self.abilities[abilityId]
    
    if not ability then
        return false, "Ability not found"
    end
    
    -- Check if unit type can use this ability
    if ability.unitType ~= user.unitType then
        return false, "Unit cannot use this ability"
    end
    
    -- Check energy cost
    if user.energy < ability.energyCost then
        return false, "Not enough energy"
    end
    
    -- Check action point cost
    if user.actionPoints < ability.actionPointCost then
        return false, "Not enough action points"
    end
    
    -- Check cooldown
    if user.abilityCooldowns and user.abilityCooldowns[abilityId] and user.abilityCooldowns[abilityId] > 0 then
        return false, "Ability on cooldown"
    end
    
    -- Initialize cooldowns if needed
    if not user.abilityCooldowns then
        user.abilityCooldowns = {}
    end
    
    -- Use the ability
    local success = ability.onUse(user, target, x, y)
    
    if success then
        -- Deduct energy
        user.energy = user.energy - ability.energyCost
        
        -- Deduct action points
        user.actionPoints = user.actionPoints - ability.actionPointCost
        
        -- Set cooldown
        user.abilityCooldowns[abilityId] = ability.cooldown
        
        return true
    end
    
    return false, "Ability use failed"
end

-- Update cooldowns at the end of a unit's turn
function SpecialAbilitiesSystem:updateCooldowns(unit)
    if not unit.abilityCooldowns then
        return
    end
    
    for abilityId, cooldown in pairs(unit.abilityCooldowns) do
        if cooldown > 0 then
            unit.abilityCooldowns[abilityId] = cooldown - 1
        end
    end
end

-- Get all allies of a unit
function SpecialAbilitiesSystem:getAllAllies(unit)
    local allies = {}
    
    for entity, _ in pairs(self.game.grid.entities) do
        if entity.faction == unit.faction then
            table.insert(allies, entity)
        end
    end
    
    return allies
end

-- Get adjacent allies of a unit
function SpecialAbilitiesSystem:getAdjacentAllies(unit)
    local allies = {}
    
    local adjacentPositions = {
        {unit.x - 1, unit.y - 1},
        {unit.x, unit.y - 1},
        {unit.x + 1, unit.y - 1},
        {unit.x - 1, unit.y},
        {unit.x + 1, unit.y},
        {unit.x - 1, unit.y + 1},
        {unit.x, unit.y + 1},
        {unit.x + 1, unit.y + 1}
    }
    
    for _, pos in ipairs(adjacentPositions) do
        local x, y = pos[1], pos[2]
        
        -- Check if position is valid
        if self.game.grid:isValidPosition(x, y) then
            -- Check if there's an ally at this position
            local entity = self.game.grid:getEntityAt(x, y)
            if entity and entity.faction == unit.faction then
                table.insert(allies, entity)
            end
        end
    end
    
    return allies
end

-- Get all enemies of a unit
function SpecialAbilitiesSystem:getAllEnemies(unit)
    local enemies = {}
    
    for entity, _ in pairs(self.game.grid.entities) do
        if entity.faction ~= unit.faction then
            table.insert(enemies, entity)
        end
    end
    
    return enemies
end

-- Get adjacent enemies of a unit
function SpecialAbilitiesSystem:getAdjacentEnemies(unit)
    local enemies = {}
    
    local adjacentPositions = {
        {unit.x - 1, unit.y - 1},
        {unit.x, unit.y - 1},
        {unit.x + 1, unit.y - 1},
        {unit.x - 1, unit.y},
        {unit.x + 1, unit.y},
        {unit.x - 1, unit.y + 1},
        {unit.x, unit.y + 1},
        {unit.x + 1, unit.y + 1}
    }
    
    for _, pos in ipairs(adjacentPositions) do
        local x, y = pos[1], pos[2]
        
        -- Check if position is valid
        if self.game.grid:isValidPosition(x, y) then
            -- Check if there's an enemy at this position
            local entity = self.game.grid:getEntityAt(x, y)
            if entity and entity.faction ~= unit.faction then
                table.insert(enemies, entity)
            end
        end
    end
    
    return enemies
end

-- Check if a position is in range of a unit
function SpecialAbilitiesSystem:isInRange(unit, x, y, range)
    local distance = math.abs(unit.x - x) + math.abs(unit.y - y)
    return distance <= range
end

-- Get valid targets for an ability
function SpecialAbilitiesSystem:getValidTargets(unit, abilityId)
    local ability = self.abilities[abilityId]
    
    if not ability then
        return {}
    end
    
    local targets = {}
    
    if ability.targetType == "self" then
        -- Self-targeting ability
        targets = {unit}
    elseif ability.targetType == "ally" then
        -- Ally-targeting ability
        for entity, _ in pairs(self.game.grid.entities) do
            if entity.faction == unit.faction and self:isInRange(unit, entity.x, entity.y, ability.range) then
                table.insert(targets, entity)
            end
        end
    elseif ability.targetType == "enemy" then
        -- Enemy-targeting ability
        for entity, _ in pairs(self.game.grid.entities) do
            if entity.faction ~= unit.faction and self:isInRange(unit, entity.x, entity.y, ability.range) then
                table.insert(targets, entity)
            end
        end
    elseif ability.targetType == "position" or ability.targetType == "direction" then
        -- Position-targeting ability
        -- This would return valid grid positions
        -- Implementation depends on the grid system
    end
    
    return targets
end

-- Get ability cooldown for a unit
function SpecialAbilitiesSystem:getAbilityCooldown(unit, abilityId)
    if not unit.abilityCooldowns or not unit.abilityCooldowns[abilityId] then
        return 0
    end
    
    return unit.abilityCooldowns[abilityId]
end

-- Check if a unit can use an ability
function SpecialAbilitiesSystem:canUseAbility(unit, abilityId)
    local ability = self.abilities[abilityId]
    
    if not ability then
        return false, "Ability not found"
    end
    
    -- Check if unit type can use this ability
    if ability.unitType ~= unit.unitType then
        return false, "Unit cannot use this ability"
    end
    
    -- Check energy cost
    if unit.energy < ability.energyCost then
        return false, "Not enough energy"
    end
    
    -- Check action point cost
    if unit.actionPoints < ability.actionPointCost then
        return false, "Not enough action points"
    end
    
    -- Check cooldown
    if unit.abilityCooldowns and unit.abilityCooldowns[abilityId] and unit.abilityCooldowns[abilityId] > 0 then
        return false, "Ability on cooldown"
    end
    
    return true
end

return SpecialAbilitiesSystem
