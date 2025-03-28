-- Animation Integration for Nightfall
-- Integrates the animation system with the main game code

-- Properly require the animation modules
local AnimationManager = require("src.systems.animation_manager")
require("src.systems.attack_animations")
require("src.systems.ability_animations")

-- Function to integrate animation system with the game
local function integrateAnimationSystem(game)
    -- Create animation manager instance
    game.animationManager = AnimationManager:new(game)
    
    -- Add animation manager to game update loop
    local originalGameUpdate = game.update
    game.update = function(self, dt)
        -- Call original update method
        originalGameUpdate(self, dt)
        
        -- Update animation manager
        if self.animationManager then
            self.animationManager:update(dt)
        end
    end
    
    -- Add animation manager to game draw loop
    local originalGameDraw = game.draw
    game.draw = function(self)
        -- Call original draw method
        originalGameDraw(self)
        
        -- Draw animation effects
        if self.animationManager then
            self.animationManager:draw()
        end
    end
    
    -- Integrate with movement system
    local MovementSystem = require("src.systems.movement_system")
    local originalMoveSelectedUnit = MovementSystem.moveSelectedUnit
    
    MovementSystem.moveSelectedUnit = function(self, targetX, targetY)
        local unit = self.selectedUnit
        if not unit then return false end
        
        -- Store old position
        local oldX, oldY = unit.x, unit.y
        
        -- Update logical position
        unit.x = targetX
        unit.y = targetY
        
        -- Mark unit as moved
        unit.hasMoved = true
        
        -- Create movement animation if animation manager exists
        if game.animationManager and not game.animationManager:isUnitAnimating(unit) then
            game.animationManager:createMovementAnimation(
                unit, 
                targetX, 
                targetY,
                function()
                    -- Animation completed callback
                    unit.animationState = "idle"
                    
                    -- Trigger any post-movement events
                    if self.onUnitMoved then
                        self.onUnitMoved(unit, oldX, oldY, targetX, targetY)
                    end
                end
            )
            
            -- Update animation state
            unit.animationState = "moving"
            
            return true
        else
            -- No animation manager or unit already animating, just update visual position
            unit.visualX = targetX
            unit.visualY = targetY
            
            -- Trigger any post-movement events
            if self.onUnitMoved then
                self.onUnitMoved(unit, oldX, oldY, targetX, targetY)
            end
            
            return true
        end
    end
    
    -- Integrate with combat system
    local CombatSystem = require("src.systems.combat_system")
    local originalAttack = CombatSystem.attack
    
    CombatSystem.attack = function(self, attacker, defender)
        -- Calculate damage and results first
        local damage, isCritical = self:calculateDamage(attacker, defender)
        
        -- Mark attacker as having attacked
        attacker.hasAttacked = true
        
        -- Create attack animation if animation manager exists
        if game.animationManager and not game.animationManager:isUnitAnimating(attacker) then
            game.animationManager:createAttackAnimation(
                attacker, 
                defender,
                function()
                    -- Animation completed callback
                    attacker.animationState = "idle"
                    
                    -- Apply damage after animation completes
                    defender.stats.currentHP = math.max(0, defender.stats.currentHP - damage)
                    
                    -- Check if defender is defeated
                    if defender.stats.currentHP <= 0 then
                        -- Handle unit defeat
                        if self.onUnitDefeated then
                            self.onUnitDefeated(defender, attacker)
                        end
                    end
                    
                    -- Trigger any post-attack events
                    if self.onAttackComplete then
                        self.onAttackComplete(attacker, defender, damage, isCritical)
                    end
                end
            )
            
            -- Update animation state
            attacker.animationState = "attacking"
            
            return true
        else
            -- No animation manager or unit already animating, just apply damage immediately
            defender.stats.currentHP = math.max(0, defender.stats.currentHP - damage)
            
            -- Show hit effect if available
            if defender.showHitEffect then
                defender:showHitEffect()
            end
            
            -- Check if defender is defeated
            if defender.stats.currentHP <= 0 then
                -- Handle unit defeat
                if self.onUnitDefeated then
                    self.onUnitDefeated(defender, attacker)
                end
            end
            
            -- Trigger any post-attack events
            if self.onAttackComplete then
                self.onAttackComplete(attacker, defender, damage, isCritical)
            end
            
            return true
        end
    end
    
    -- Integrate with ability system
    local AbilitySystem = require("src.systems.special_abilities_system")
    local originalUseAbility = AbilitySystem.useAbility
    
    AbilitySystem.useAbility = function(self, unit, abilityName, targetPosition)
        -- Check if ability exists and can be used
        if not self:canUseAbility(unit, abilityName) then
            return false
        end
        
        -- Mark ability as used
        unit.hasUsedAbility = true
        
        -- Get ability data
        local ability = self.abilities[abilityName]
        
        -- Create ability animation if animation manager exists
        if game.animationManager and not game.animationManager:isUnitAnimating(unit) then
            -- Check for ability-specific animation
            local abilityAnimation = AnimationManager.getAbilityAnimation(abilityName)
            
            if abilityAnimation then
                -- Use custom animation for this specific ability
                abilityAnimation(unit, targetPosition, game.animationManager)
            else
                -- Use generic ability animation
                game.animationManager:createAbilityAnimation(
                    unit, 
                    ability.type,
                    targetPosition,
                    function()
                        -- Animation completed callback
                        unit.animationState = "idle"
                        
                        -- Apply ability effects after animation completes
                        self:applyAbilityEffects(unit, abilityName, targetPosition)
                        
                        -- Trigger any post-ability events
                        if self.onAbilityUsed then
                            self.onAbilityUsed(unit, abilityName, targetPosition)
                        end
                    end
                )
            end
            
            -- Update animation state
            unit.animationState = "casting"
            
            return true
        else
            -- No animation manager or unit already animating, just apply effects immediately
            self:applyAbilityEffects(unit, abilityName, targetPosition)
            
            -- Show ability effect if available
            if unit.showAbilityEffect then
                unit:showAbilityEffect(ability.type)
            end
            
            -- Trigger any post-ability events
            if self.onAbilityUsed then
                self.onAbilityUsed(unit, abilityName, targetPosition)
            end
            
            return true
        end
    end
    
    return game.animationManager
end

return {
    integrateAnimationSystem = integrateAnimationSystem
}
