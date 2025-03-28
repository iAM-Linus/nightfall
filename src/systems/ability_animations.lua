-- Ability Animation Implementation for Nightfall
-- Extends the AnimationManager with ability animation functionality
-- Implements arcade-style ability animations inspired by Shotgun King

-- This file should be required after animation_manager.lua is loaded
-- It extends the AnimationManager prototype with ability animation methods

-- Get the AnimationManager class (don't try to access it as a global)
local AnimationManager = require("src.systems.animation_manager")

-- Add ability particle templates to PARTICLE_TEMPLATES
AnimationManager.PARTICLE_TEMPLATES = AnimationManager.PARTICLE_TEMPLATES or {}

-- Ability particle templates
AnimationManager.PARTICLE_TEMPLATES.abilityCharge = {
    particleCount = 5,
    lifetime = {0.3, 0.7},
    size = {2, 6},
    speed = {10, 30},
    color = {{0.5, 0.5, 1, 0.8}, {0.2, 0.2, 1, 0}},
    spread = math.pi * 2 -- All directions
}

AnimationManager.PARTICLE_TEMPLATES.abilityEffect = {
    particleCount = 20,
    lifetime = {0.3, 0.8},
    size = {3, 8},
    speed = {40, 100},
    color = {{0.4, 0.4, 1, 0.9}, {0.2, 0.2, 0.8, 0}},
    spread = math.pi * 0.3
}

AnimationManager.PARTICLE_TEMPLATES.abilityImpact = {
    particleCount = 25,
    lifetime = {0.4, 1.0},
    size = {4, 10},
    speed = {30, 80},
    color = {{0.5, 0.5, 1, 0.9}, {0.3, 0.3, 0.9, 0}},
    spread = math.pi * 2 -- All directions
}

AnimationManager.PARTICLE_TEMPLATES.abilityRadial = {
    particleCount = 30,
    lifetime = {0.4, 0.9},
    size = {3, 8},
    speed = {30, 70},
    color = {{0.4, 0.4, 1, 0.8}, {0.2, 0.2, 0.8, 0}},
    spread = math.pi * 2 -- All directions
}

AnimationManager.PARTICLE_TEMPLATES.healingCharge = {
    particleCount = 5,
    lifetime = {0.3, 0.7},
    size = {2, 6},
    speed = {10, 30},
    color = {{0.3, 1, 0.3, 0.8}, {0.2, 0.8, 0.2, 0}},
    spread = math.pi * 2 -- All directions
}

AnimationManager.PARTICLE_TEMPLATES.healingEffect = {
    particleCount = 25,
    lifetime = {0.5, 1.2},
    size = {4, 10},
    speed = {20, 50},
    color = {{0.3, 1, 0.3, 0.9}, {0.2, 0.8, 0.2, 0}},
    spread = math.pi * 2 -- All directions
}

-- Create an ability animation
function AnimationManager:createAbilityAnimation(unit, abilityType, targetPosition, onComplete)
    -- Don't create new animation if unit is already animating
    if self.animatingUnits[unit] then
        return nil
    end
    
    -- Mark unit as animating
    self.animatingUnits[unit] = true
    
    -- Get animation style
    local style = self.ANIMATION_PRESETS[self.defaultStyle]
    local abilityStyle = style.ability
    
    -- Calculate direction to target if provided
    local direction = 0
    local distance = 0
    
    if targetPosition then
        local dx = targetPosition.x - unit.x
        local dy = targetPosition.y - unit.y
        distance = math.sqrt(dx*dx + dy*dy)
        direction = math.atan2(dy, dx)
    end
    
    -- Create animation object
    local animId = "ability_" .. unit.id .. "_" .. os.time() .. "_" .. math.random(1000)
    local animation = {
        id = animId,
        unit = unit,
        type = "ability",
        abilityType = abilityType or "default",
        startTime = love.timer.getTime(),
        duration = abilityStyle.duration.charge + abilityStyle.duration.release + abilityStyle.duration.recover,
        completed = false,
        direction = direction,
        targetPosition = targetPosition,
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
    
    -- Determine ability color based on type
    local abilityColor = {0.3, 0.3, 1, 1} -- Default blue
    
    if abilityType == "attack" then
        abilityColor = {1, 0.3, 0.3, 1} -- Red for attack
    elseif abilityType == "defense" then
        abilityColor = {0.3, 0.7, 1, 1} -- Blue for defense
    elseif abilityType == "support" then
        abilityColor = {0.3, 1, 0.3, 1} -- Green for support
    elseif abilityType == "special" then
        abilityColor = {1, 0.8, 0.2, 1} -- Gold for special
    end
    
    -- 1. Charge phase - build up energy
    self.timer:during(
        abilityStyle.duration.charge,
        function(dt, timeLeft, totalTime)
            -- Calculate progress (0 to 1)
            local progress = 1 - (timeLeft / totalTime)
            
            -- Pulsing effect
            local pulseScale = 1 + math.sin(progress * abilityStyle.pulse.frequency) * abilityStyle.pulse.scale * progress
            unit.scale.x = pulseScale
            unit.scale.y = pulseScale
            
            -- Slight rotation
            unit.rotation = math.sin(progress * 10) * 0.1
            
            -- Create charging particles
            if math.random() < 0.3 then
                self:createParticles(
                    "abilityCharge",
                    unit.x,
                    unit.y,
                    math.random() * math.pi * 2 -- Random direction
                )
            end
        end,
        function()
            -- Flash unit with ability color
            if unit.flash then
                unit:flash(0.2, abilityColor)
            end
            
            -- 2. Release phase - unleash the ability
            self.timer:tween(
                abilityStyle.duration.release,
                unit.scale,
                {x = 1.5, y = 1.5},
                'out-elastic',
                function()
                    -- Create ability effect particles
                    if targetPosition then
                        -- Create directional effect toward target
                        self:createParticles(
                            "abilityEffect",
                            unit.x,
                            unit.y,
                            direction
                        )
                        
                        -- Create impact effect at target
                        self:createParticles(
                            "abilityImpact",
                            targetPosition.x,
                            targetPosition.y,
                            0 -- All directions
                        )
                    else
                        -- Create radial effect around unit
                        self:createParticles(
                            "abilityRadial",
                            unit.x,
                            unit.y,
                            0 -- All directions
                        )
                    end
                    
                    -- Add screen shake
                    self:shakeScreen(0.3, 0.2)
                    
                    -- 3. Recovery phase - return to normal
                    self.timer:tween(
                        abilityStyle.duration.recover,
                        unit.scale,
                        {x = 1, y = 1},
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
        end
    )
    
    return animId
end

-- Ability-specific animations
local ABILITY_ANIMATIONS = {
    -- Knight abilities
    knights_charge = function(unit, targetPosition, animationManager)
        -- Special animation for Knight's Charge ability
        -- This is a dash attack that covers multiple tiles
        
        -- Calculate direction to target
        local dx = targetPosition.x - unit.x
        local dy = targetPosition.y - unit.y
        local distance = math.sqrt(dx*dx + dy*dy)
        local direction = math.atan2(dy, dx)
        
        -- Create a more exaggerated movement animation
        local animId = "ability_knights_charge_" .. unit.id .. "_" .. os.time()
        
        -- Mark unit as animating
        animationManager.animatingUnits[unit] = true
        
        -- Store original position
        local startX, startY = unit.x, unit.y
        
        -- Create animation object
        local animation = {
            id = animId,
            unit = unit,
            type = "ability",
            abilityType = "knights_charge",
            startTime = love.timer.getTime(),
            duration = 0.8, -- Total duration
            completed = false,
            direction = direction,
            targetPosition = targetPosition
        }
        
        -- Store animation
        animationManager.activeAnimations[animId] = animation
        
        -- 1. Anticipation phase - brief windup
        animationManager.timer:tween(
            0.15, -- Duration
            unit.scale,
            {x = 0.7, y = 1.3}, -- Squash
            'in-back',
            function()
                -- 2. Charge phase - rapid movement with trail
                animationManager.timer:during(
                    0.3, -- Duration
                    function(dt, timeLeft, totalTime)
                        -- Calculate progress (0 to 1)
                        local progress = 1 - (timeLeft / totalTime)
                        
                        -- Accelerating movement
                        local easedProgress = animationManager.timer.tween.out_quad(progress)
                        unit.visualX = startX + (targetPosition.x - startX) * easedProgress
                        unit.visualY = startY + (targetPosition.y - startY) * easedProgress
                        
                        -- Extreme stretch during charge
                        unit.scale.x = 1.8
                        unit.scale.y = 0.6
                        
                        -- Slight upward offset
                        unit.offset.y = -5
                        
                        -- Create trail particles
                        if math.random() < 0.5 then
                            animationManager:createParticles(
                                "movementTrail",
                                unit.visualX,
                                unit.visualY,
                                direction - math.pi -- Behind unit
                            )
                        end
                    end,
                    function()
                        -- 3. Impact phase
                        -- Create impact particles
                        animationManager:createParticles(
                            "abilityImpact",
                            targetPosition.x,
                            targetPosition.y,
                            0 -- All directions
                        )
                        
                        -- Add screen shake
                        animationManager:shakeScreen(0.5, 0.2)
                        
                        -- Flash effect
                        if unit.flash then
                            unit:flash(0.2, {1, 0.3, 0.3, 1})
                        end
                        
                        -- 4. Recovery phase
                        animationManager.timer:tween(
                            0.25, -- Duration
                            unit.scale,
                            {x = 1, y = 1}, -- Return to normal
                            'out-bounce',
                            function()
                                -- Reset offset
                                unit.offset.y = 0
                                
                                -- Mark animation as completed
                                animation.completed = true
                                
                                -- Update unit state
                                unit.animationState = "idle"
                            end
                        )
                    end
                )
            end
        )
        
        return animId
    end,
    
    -- Bishop abilities
    healing_light = function(unit, targetPosition, animationManager)
        -- Special animation for Healing Light ability
        -- This is a healing spell with a glowing effect
        
        -- Create a healing animation
        local animId = "ability_healing_light_" .. unit.id .. "_" .. os.time()
        
        -- Mark unit as animating
        animationManager.animatingUnits[unit] = true
        
        -- Create animation object
        local animation = {
            id = animId,
            unit = unit,
            type = "ability",
            abilityType = "healing_light",
            startTime = love.timer.getTime(),
            duration = 1.0, -- Total duration
            completed = false,
            targetPosition = targetPosition
        }
        
        -- Store animation
        animationManager.activeAnimations[animId] = animation
        
        -- 1. Charge phase - glowing effect
        animationManager.timer:during(
            0.4, -- Duration
            function(dt, timeLeft, totalTime)
                -- Calculate progress (0 to 1)
                local progress = 1 - (timeLeft / totalTime)
                
                -- Pulsing glow effect
                local pulseScale = 1 + math.sin(progress * 15) * 0.1 * progress
                unit.scale.x = pulseScale
                unit.scale.y = pulseScale
                
                -- Create charging particles
                if math.random() < 0.3 then
                    animationManager:createParticles(
                        "healingCharge",
                        unit.x,
                        unit.y,
                        math.random() * math.pi * 2 -- Random direction
                    )
                end
            end,
            function()
                -- 2. Release phase - healing burst
                -- Flash with healing color
                if unit.flash then
                    unit:flash(0.3, {0.3, 1, 0.3, 0.7})
                end
                
                -- Create healing effect at target
                animationManager:createParticles(
                    "healingEffect",
                    targetPosition.x,
                    targetPosition.y,
                    0 -- All directions
                )
                
                -- 3. Recovery phase
                animationManager.timer:tween(
                    0.3, -- Duration
                    unit.scale,
                    {x = 1, y = 1}, -- Return to normal
                    'in-out-quad',
                    function()
                        -- Mark animation as completed
                        animation.completed = true
                        
                        -- Update unit state
                        unit.animationState = "idle"
                    end
                )
            end
        )
        
        return animId
    end
}

-- Extend Unit class with ability animation method
local Unit = require("src.entities.unit")

function Unit:useAbilityWithAnimation(abilityType, targetPosition)
    -- If animation manager exists, create ability animation
    if self.grid and self.grid.game and self.grid.game.animationManager then
        -- Create ability animation
        self.grid.game.animationManager:createAbilityAnimation(
            self, 
            abilityType,
            targetPosition,
            function()
                -- Animation completed callback
                self.animationState = "idle"
            end
        )
        
        -- Update animation state
        self.animationState = "casting"
        
        return true
    else
        -- No animation manager, just show basic effect
        if self.showAbilityEffect then
            self:showAbilityEffect(abilityType)
        end
        return true
    end
end

-- Function to get ability-specific animation
function AnimationManager.getAbilityAnimation(abilityName)
    return ABILITY_ANIMATIONS[abilityName]
end

return AnimationManager
