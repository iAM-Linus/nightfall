-- Animation Manager for Nightfall
-- Core animation system that manages all animations and effects
-- Implements arcade-style animations inspired by Shotgun King

local Timer = require("lib.hump.timer")

-- Animation Manager class
local AnimationManager = {}
AnimationManager.__index = AnimationManager

-- Create a new animation manager
function AnimationManager:new(game)
    print("--- AnimationManager:new START ---") -- Add this
    local manager = {}
    setmetatable(manager, AnimationManager)
    
    -- Store reference to game
    manager.game = game
    
    -- Initialize timer
    manager.timer = Timer.new()
    print("  Created internal hump.timer instance:", tostring(manager.timer)) -- Add this
    
    -- Active animations
    manager.activeAnimations = {}
    
    -- Units currently being animated
    manager.animatingUnits = {}
    
    -- Screen shake effect
    manager.screenShake = {
        active = false,
        intensity = 0,
        duration = 0,
        timer = 0,
        offsetX = 0,
        offsetY = 0
    }
    
    -- Particle systems
    manager.particles = {}
    
    -- Animation style (arcade or subtle)
    manager.defaultStyle = "arcade"
    
    print("--- AnimationManager:new END ---") -- Add this
    return manager
end

-- Animation presets
AnimationManager.ANIMATION_PRESETS = {
    -- Arcade style - exaggerated animations
    arcade = {
        -- Movement animation settings
        movement = {
            -- Jump height for arc movement
            jumpHeight = 16,
            
            -- Squash and stretch factors
            squashFactor = 0.7,
            stretchFactor = 1.3,
            
            -- Duration of each phase
            duration = {
                anticipation = 0.15,
                jump = 0.3,
                landing = 0.1,
                settle = 0.15
            },
            
            -- Bounce settings
            bounce = {
                height = 5,
                count = 1
            }
        },
        
        -- Attack animation settings
        attack = {
            -- Lunge distance toward target
            lungeDistance = 10,
            
            -- Rotation during attack (radians)
            rotation = 0.3,
            
            -- Duration of each phase
            duration = {
                windup = 0.15,
                strike = 0.1,
                followThrough = 0.15,
                recover = 0.2
            }
        },
        
        -- Ability animation settings
        ability = {
            -- Pulse effect during charge
            pulse = {
                scale = 0.2,
                frequency = 15
            },
            
            -- Duration of each phase
            duration = {
                charge = 0.4,
                release = 0.2,
                recover = 0.3
            }
        }
    },
    
    -- Subtle style - less exaggerated animations
    subtle = {
        -- Movement animation settings
        movement = {
            -- Jump height for arc movement
            jumpHeight = 8,
            
            -- Squash and stretch factors
            squashFactor = 0.9,
            stretchFactor = 1.1,
            
            -- Duration of each phase
            duration = {
                anticipation = 0.1,
                jump = 0.2,
                landing = 0.05,
                settle = 0.1
            },
            
            -- Bounce settings
            bounce = {
                height = 2,
                count = 1
            }
        },
        
        -- Attack animation settings
        attack = {
            -- Lunge distance toward target
            lungeDistance = 5,
            
            -- Rotation during attack (radians)
            rotation = 0.1,
            
            -- Duration of each phase
            duration = {
                windup = 0.1,
                strike = 0.1,
                followThrough = 0.1,
                recover = 0.1
            }
        },
        
        -- Ability animation settings
        ability = {
            -- Pulse effect during charge
            pulse = {
                scale = 0.1,
                frequency = 10
            },
            
            -- Duration of each phase
            duration = {
                charge = 0.3,
                release = 0.15,
                recover = 0.2
            }
        }
    }
}

-- Particle effect templates
AnimationManager.PARTICLE_TEMPLATES = {
    -- Movement start particles (dust cloud)
    movementStart = {
        particleCount = 5,
        lifetime = {0.2, 0.5},
        size = {2, 5},
        speed = {20, 40},
        color = {{0.8, 0.8, 0.8, 0.8}, {0.9, 0.9, 0.9, 0}},
        spread = math.pi * 0.5
    },
    
    -- Movement trail particles
    movementTrail = {
        particleCount = 3,
        lifetime = {0.1, 0.3},
        size = {1, 3},
        speed = {5, 15},
        color = {{0.8, 0.8, 0.8, 0.5}, {0.9, 0.9, 0.9, 0}},
        spread = math.pi * 0.3
    },
    
    -- Landing particles (dust cloud)
    landing = {
        particleCount = 8,
        lifetime = {0.3, 0.6},
        size = {2, 6},
        speed = {30, 60},
        color = {{0.8, 0.8, 0.8, 0.8}, {0.9, 0.9, 0.9, 0}},
        spread = math.pi * 0.7
    }
}

-- Update animation manager
function AnimationManager:update(dt)
    -- Optional: print("--- AnimationManager:update START ---")

    -- Update timer (CRUCIAL!)
    if self.timer and self.timer.update then
        self.timer:update(dt)
    else
        print("ERROR: AnimationManager self.timer is nil or has no update method!")
    end

    -- Update screen shake
    self:updateScreenShake(dt) -- Make sure this method exists or comment out

    -- Update active animations
    local animationsProcessed = 0
    if self.activeAnimations and next(self.activeAnimations) then -- Check if table is not empty
        for id, animation in pairs(self.activeAnimations) do
            animationsProcessed = animationsProcessed + 1
            -- Optional: print(string.format("    Processing animation: %s", id))

            if animation.completed then
                print(string.format("    Removing completed animation: %s", id))
                if animation.unit then
                     self.animatingUnits[animation.unit] = nil
                end
                self.activeAnimations[id] = nil
            end
        end
    else
        -- print("  No active animations to process.") -- Can uncomment if needed
    end


    -- Update particle systems
    for i = #self.particles, 1, -1 do
        local particle = self.particles[i]
        
        -- Update particle lifetime
        particle.lifetime = particle.lifetime - dt
        
        -- Remove expired particles
        if particle.lifetime <= 0 then
            table.remove(self.particles, i)
        else
            -- Update particle position
            particle.x = particle.x + particle.vx * dt
            particle.y = particle.y + particle.vy * dt
            
            -- Update particle alpha (fade out)
            local lifeFactor = particle.lifetime / particle.maxLifetime
            particle.color[4] = particle.startColor[4] * lifeFactor + particle.endColor[4] * (1 - lifeFactor)
            
            -- Update particle size (shrink)
            particle.size = particle.startSize * lifeFactor + particle.endSize * (1 - lifeFactor)
        end
    end
    -- print("--- AnimationManager:update END ---") -- Uncomment if needed
end

-- Draw animation effects
function AnimationManager:draw()
    -- Apply screen shake offset
    love.graphics.push()
    love.graphics.translate(self.screenShake.offsetX, self.screenShake.offsetY)
    
    -- Draw particle effects
    for _, particle in ipairs(self.particles) do
        love.graphics.setColor(particle.color)
        love.graphics.circle("fill", particle.x, particle.y, particle.size)
    end
    
    -- Reset transform
    love.graphics.pop()
    
    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

-- Create a movement animation
function AnimationManager:createMovementAnimation(unit, targetX, targetY, grid, onComplete)
    if not grid then print("ERROR: createMovementAnimation called without grid!"); return nil end -- Grid is required

    -- Don't create new animation if unit is already animating
    if self.animatingUnits[unit] then
        print("  WARNING: Unit is already animating. Aborting new move animation.") -- Add this
        return nil
    end
    local manager = self

    -- Mark unit as animating
    self.animatingUnits[unit] = true
    print("  Marked unit as animating.") -- Add this
    
    -- Get animation style
    local style = self.ANIMATION_PRESETS[self.defaultStyle]
    local movementStyle = style.movement
    
    -- Calculate direction
    local dx = targetX - unit.x
    local dy = targetY - unit.y
    local direction = math.atan(dy, dx)
    
    -- Create animation object
    local animId = "move_" .. unit.id .. "_" .. os.time() .. "_" .. math.random(1000)
    local animation = {
        id = animId,
        unit = unit,
        type = "movement",
        startX = unit.visualX, -- Use visualX/Y as start for smooth transitions
        startY = unit.visualY,
        targetX = targetX,
        targetY = targetY,
        startTime = love.timer.getTime(),
        duration = movementStyle.duration.anticipation + movementStyle.duration.jump +
                  movementStyle.duration.landing + movementStyle.duration.settle,
        completed = false,
        direction = direction,
        grid = grid,
        onComplete = onComplete
    }
    
    -- Store animation
    self.activeAnimations[animId] = animation
    --print(string.format("  Stored animation object with ID: %s", animId)) -- Add this
    
    -- Initialize visual position if not set
    unit.visualX = unit.visualX or unit.x
    unit.visualY = unit.visualY or unit.y
    
    -- Initialize transform properties if not set
    unit.scale = unit.scale or {x = 1, y = 1}
    unit.rotation = unit.rotation or 0
    unit.offset = unit.offset or {x = 0, y = 0}
    
    -- Create dust particles at start position
    self:createParticles(
        "movementStart",
        unit.x,
        unit.y,
        direction
    )
    
    -- Use animation.grid for screen coords
    local startScreenX, startScreenY = animation.grid:gridToScreen(unit.visualX, unit.visualY)
    startScreenX = startScreenX + animation.grid.tileSize/2; startScreenY = startScreenY + animation.grid.tileSize/2
    manager:createParticles("movementStart", startScreenX, startScreenY, direction)

    -- Animation sequence using timer
    manager.timer:tween(movementStyle.duration.anticipation, unit.scale, {x = movementStyle.squashFactor, y = 2 - movementStyle.squashFactor}, 'in-out-quad', function()
        local jumpDuration = movementStyle.duration.jump; local jumpHeight = movementStyle.jumpHeight
        manager.timer:during(jumpDuration, function(dt, timeLeft)
            local progress = 0; if jumpDuration > 0 then progress = 1 - (timeLeft / jumpDuration); progress = math.max(0, math.min(1, progress)) else progress = 1 end
            unit.visualX = animation.startX + (animation.targetX - animation.startX) * progress
            unit.visualY = animation.startY + (animation.targetY - animation.startY) * progress
            local arcOffset = -jumpHeight * math.sin(progress * math.pi); unit.offset.y = arcOffset
            local stretchProgress = math.sin(progress * math.pi); local stretchFactor = 1 + (movementStyle.stretchFactor - 1) * stretchProgress
            unit.scale.x = 2 - stretchFactor; unit.scale.y = stretchFactor
            if math.random() < 0.3 then
                -- Use animation.grid for screen coords
                local px, py = animation.grid:gridToScreen(unit.visualX, unit.visualY)
                px = px + animation.grid.tileSize/2; py = py + animation.grid.tileSize/2 + unit.offset.y -- Add offset for trail
                manager:createParticles("movementTrail", px, py, animation.direction - math.pi)
            end
        end, function() -- onComplete for jump phase
            unit.visualX = animation.targetX; unit.visualY = animation.targetY; unit.offset.y = 0
            -- Use animation.grid for screen coords
            local landScreenX, landScreenY = animation.grid:gridToScreen(animation.targetX, animation.targetY)
            landScreenX = landScreenX + animation.grid.tileSize/2; landScreenY = landScreenY + animation.grid.tileSize/2
            manager:createParticles("landing", landScreenX, landScreenY, 0)
            manager.timer:tween(movementStyle.duration.landing, unit.scale, {x = movementStyle.stretchFactor, y = movementStyle.squashFactor}, 'out-quad', function()
                manager.timer:tween(movementStyle.duration.settle * 0.5, unit.scale, {x = 1, y = 1}, 'in-out-quad', function()
                    unit.visualX = unit.x; unit.visualY = unit.y; unit.offset = {x = 0, y = 0}; unit.scale = {x = 1, y = 1}; unit.rotation = 0; animation.completed = true
                    if animation.onComplete then animation.onComplete() end
                end)
            end)
        end)
    end)
    return animId
end

-- Create particles
function AnimationManager:createParticles(templateName, x, y, direction)
    -- Get template
    local template = self.PARTICLE_TEMPLATES[templateName]
    if not template then
        return nil
    end
    
    -- Create particles
    local particleId = templateName .. "_" .. os.time() .. "_" .. math.random(1000)
    
    for i = 1, template.particleCount do
        -- Calculate random direction within spread
        local particleDirection = direction
        if template.spread > 0 then
            particleDirection = direction + (math.random() * 2 - 1) * template.spread
        end
        
        -- Calculate random speed
        local speed = template.speed[1] + math.random() * (template.speed[2] - template.speed[1])
        
        -- Calculate velocity
        local vx = math.cos(particleDirection) * speed
        local vy = math.sin(particleDirection) * speed
        
        -- Calculate random lifetime
        local lifetime = template.lifetime[1] + math.random() * (template.lifetime[2] - template.lifetime[1])
        
        -- Calculate random size
        local startSize = template.size[1] + math.random() * (template.size[2] - template.size[1])
        local endSize = startSize * 0.5
        
        -- Get colors
        local startColor = template.color[1]
        local endColor = template.color[2]
        
        -- Create particle
        local particle = {
            x = x,
            y = y,
            vx = vx,
            vy = vy,
            lifetime = lifetime,
            maxLifetime = lifetime,
            startSize = startSize,
            endSize = endSize,
            size = startSize,
            startColor = startColor,
            endColor = endColor,
            color = {startColor[1], startColor[2], startColor[3], startColor[4]}
        }
        
        -- Add to particles list
        table.insert(self.particles, particle)
    end
    
    return particleId
end

-- Create screen shake effect
function AnimationManager:shakeScreen(intensity, duration)
    self.screenShake.active = true
    self.screenShake.intensity = intensity or 0.5
    self.screenShake.duration = duration or 0.3
    self.screenShake.timer = self.screenShake.duration
end

-- Update screen shake effect
function AnimationManager:updateScreenShake(dt)
    if self.screenShake.active then
        -- Update timer
        self.screenShake.timer = self.screenShake.timer - dt
        
        -- Check if shake is complete
        if self.screenShake.timer <= 0 then
            self.screenShake.active = false
            self.screenShake.offsetX = 0
            self.screenShake.offsetY = 0
        else
            -- Calculate intensity based on remaining time
            local currentIntensity = self.screenShake.intensity * (self.screenShake.timer / self.screenShake.duration)
            
            -- Calculate random offset
            self.screenShake.offsetX = (math.random() * 2 - 1) * currentIntensity * 10
            self.screenShake.offsetY = (math.random() * 2 - 1) * currentIntensity * 10
        end
    end
end

-- Check if a unit is currently being animated
function AnimationManager:isUnitAnimating(unit)
    return self.animatingUnits[unit] ~= nil
end

-- Cancel an animation
function AnimationManager:cancelAnimation(animId)
    local animation = self.activeAnimations[animId]
    if not animation then
        return false
    end
    
    -- Remove from animating units
    self.animatingUnits[animation.unit] = nil
    
    -- Remove from active animations
    self.activeAnimations[animId] = nil
    
    -- Reset unit properties
    if animation.unit then
        animation.unit.scale.x = 1
        animation.unit.scale.y = 1
        animation.unit.rotation = 0
        animation.unit.offset.x = 0
        animation.unit.offset.y = 0
    end
    
    return true
end

-- Required methods for game.lua compatibility
function AnimationManager:setPlayerTurn(isPlayerTurn)
    self.isPlayerTurn = isPlayerTurn
    -- Update UI elements based on turn state
end

function AnimationManager:setActionPoints(current, max)
    self.currentActionPoints = current
    self.maxActionPoints = max
    -- Update UI elements to show action points
end

function AnimationManager:setLevel(level)
    self.currentLevel = level
    -- Update UI elements to show current level
end

function AnimationManager:setGrid(grid)
    self.grid = grid
    -- Set up minimap with grid
end

function AnimationManager:setHelpText(text)
    self.helpText = text
    -- Update help text display
end

function AnimationManager:showNotification(text, duration)
    -- Show notification with text for specified duration
    print("Notification: " .. text)
end

-- Helper function to count active animations (add this to animation_manager.lua)
function AnimationManager:countActiveAnimations()
    local count = 0
    if self.activeAnimations then
        for _ in pairs(self.activeAnimations) do
            count = count + 1
        end
    end
    return count
end

return AnimationManager
