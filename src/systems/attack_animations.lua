-- Attack Animation Implementation for Nightfall
-- Extends the AnimationManager with attack animation functionality
-- Implements arcade-style attack animations inspired by Shotgun King

-- This file should be required after animation_manager.lua is loaded
-- It extends the AnimationManager prototype with attack animation methods

-- Get the AnimationManager class (don't try to access it as a global)
local AnimationManager = require("src.systems.animation_manager")

-- Add attack impact particle template to PARTICLE_TEMPLATES
AnimationManager.PARTICLE_TEMPLATES = AnimationManager.PARTICLE_TEMPLATES or {}
AnimationManager.PARTICLE_TEMPLATES.attackImpact = {
    particleCount = 15,
    lifetime = {0.2, 0.5},
    size = {3, 8},
    speed = {30, 80},
    color = {{1, 0.3, 0.3, 0.9}, {1, 0.5, 0.2, 0}},
    spread = math.pi * 0.7
}

AnimationManager.PARTICLE_TEMPLATES.weaponTrail = {
    particleCount = 10,
    lifetime = {0.1, 0.3},
    size = {2, 5},
    speed = {10, 20},
    color = {{1, 1, 1, 0.8}, {0.8, 0.8, 1, 0}},
    spread = math.pi * 0.3
}

-- Create an attack animation
function AnimationManager:createAttackAnimation(unit, targetUnit, onComplete)
    -- Don't create new animation if unit is already animating
    if self.animatingUnits[unit] then
        return nil
    end
    
    -- Mark unit as animating
    self.animatingUnits[unit] = true
    
    -- Get animation style
    local style = self.ANIMATION_PRESETS[self.defaultStyle]
    local attackStyle = style.attack
    
    -- Calculate direction to target
    local dx = targetUnit.x - unit.x
    local dy = targetUnit.y - unit.y
    local distance = math.sqrt(dx*dx + dy*dy)
    local direction = math.atan2(dy, dx)
    
    -- Create animation object
    local animId = "attack_" .. unit.id .. "_" .. os.time() .. "_" .. math.random(1000)
    local animation = {
        id = animId,
        unit = unit,
        targetUnit = targetUnit,
        type = "attack",
        startTime = love.timer.getTime(),
        duration = attackStyle.duration.windup + attackStyle.duration.strike + 
                  attackStyle.duration.followThrough + attackStyle.duration.recover,
        completed = false,
        direction = direction,
        onComplete = onComplete
    }
    
    -- Store animation
    self.activeAnimations[animId] = animation
    
    -- Initialize visual position if not set
    unit.visualX = unit.visualX or unit.x
    unit.visualY = unit.visualY or unit.y
    
    -- Initialize transform properties if not set
    unit.scale = unit.scale or {x = 1, y = 1}
    unit.rotation = unit.rotation or 0
    unit.offset = unit.offset or {x = 0, y = 0}
    
    -- Set animation direction
    unit.animationDirection = (dx > 0) and 1 or -1
    
    -- 1. Windup phase - prepare for attack
    self.timer:tween(
        attackStyle.duration.windup,
        unit.scale,
        {x = 0.8, y = 1.2},
        'in-back',
        function()
            -- Calculate lunge offset in direction of target
            local lungeX = math.cos(direction) * attackStyle.lungeDistance
            local lungeY = math.sin(direction) * attackStyle.lungeDistance
            
            -- 2. Strike phase - lunge toward target
            self.timer:tween(
                attackStyle.duration.strike,
                unit.offset,
                {x = lungeX, y = lungeY},
                'out-quad',
                function()
                    -- Apply attack effect to target
                    if targetUnit.showHitEffect then
                        targetUnit:showHitEffect()
                    end
                    
                    -- Create impact particles
                    self:createParticles(
                        "attackImpact",
                        targetUnit.x,
                        targetUnit.y,
                        direction
                    )
                    
                    -- Add screen shake on impact
                    self:shakeScreen(0.4, 0.2)
                    
                    -- 3. Follow-through phase
                    self.timer:tween(
                        attackStyle.duration.followThrough,
                        unit.scale,
                        {x = 1.2, y = 0.9},
                        'out-quad',
                        function()
                            -- 4. Recovery phase - return to normal
                            self.timer:tween(
                                attackStyle.duration.recover,
                                unit.scale,
                                {x = 1, y = 1},
                                'out-elastic'
                            )
                            
                            -- Return to original position
                            self.timer:tween(
                                attackStyle.duration.recover,
                                unit.offset,
                                {x = 0, y = 0},
                                'in-out-quad',
                                function()
                                    -- Reset rotation
                                    unit.rotation = 0
                                    
                                    -- Mark animation as completed
                                    animation.completed = true
                                    
                                    -- Call completion callback
                                    if onComplete then
                                        onComplete()
                                    end
                                end
                            )
                        end
                    )
                    
                    -- Apply rotation during follow-through
                    self.timer:tween(
                        attackStyle.duration.followThrough,
                        unit,
                        {rotation = unit.animationDirection * attackStyle.rotation},
                        'out-quad',
                        function()
                            -- Return rotation to normal during recovery
                            self.timer:tween(
                                attackStyle.duration.recover,
                                unit,
                                {rotation = 0},
                                'in-out-quad'
                            )
                        end
                    )
                end
            )
            
            -- Apply stretch during strike
            self.timer:tween(
                attackStyle.duration.strike,
                unit.scale,
                {x = 1.4, y = 0.8},
                'out-quad'
            )
        end
    )
    
    return animId
end

-- Extend Unit class with attack animation method
local Unit = require("src.entities.unit")

function Unit:attackWithAnimation(targetUnit)
    -- Store old position
    local oldX, oldY = self.x, self.y
    
    -- If animation manager exists, create attack animation
    if self.grid and self.grid.game and self.grid.game.animationManager then
        -- Set animation direction based on target position
        self.animationDirection = (targetUnit.x > self.x) and 1 or -1
        
        -- Create attack animation
        self.grid.game.animationManager:createAttackAnimation(
            self, 
            targetUnit,
            function()
                -- Animation completed callback
                self.animationState = "idle"
            end
        )
        
        -- Update animation state
        self.animationState = "attacking"
        
        return true
    else
        -- No animation manager, just show basic effect
        if targetUnit.showHitEffect then
            targetUnit:showHitEffect()
        end
        return true
    end
end

-- Override the Unit:attack method to use animations
function Unit:attack(targetUnit)
    -- Call attackWithAnimation instead of direct attack
    return self:attackWithAnimation(targetUnit)
end

return AnimationManager
