-- Ability Animation Implementation for Nightfall
-- Extends the AnimationManager with ability animation functionality
-- Implements arcade-style ability animations

-- This file should be required after animation_manager.lua is loaded
-- It extends the AnimationManager with ability animation methods

-- Get the AnimationManager class (don't try to access it as a global)
local AnimationManager = require("src.systems.animation_manager")

-- Add ability particle templates to PARTICLE_TEMPLATES
AnimationManager.PARTICLE_TEMPLATES = AnimationManager.PARTICLE_TEMPLATES or {}

-- Ability particle templates
AnimationManager.PARTICLE_TEMPLATES.abilityCharge = {
    particleCount = 5,
    lifetime = { 0.3, 0.7 },
    size = { 2, 6 },
    speed = { 10, 30 },
    color = { { 0.5, 0.5, 1, 0.8 }, { 0.2, 0.2, 1, 0 } },
    spread = math.pi * 2 -- All directions
}

AnimationManager.PARTICLE_TEMPLATES.abilityEffect = {
    particleCount = 20,
    lifetime = { 0.3, 0.8 },
    size = { 3, 8 },
    speed = { 40, 100 },
    color = { { 0.4, 0.4, 1, 0.9 }, { 0.2, 0.2, 0.8, 0 } },
    spread = math.pi * 0.3
}

AnimationManager.PARTICLE_TEMPLATES.abilityImpact = {
    particleCount = 25,
    lifetime = { 0.4, 1.0 },
    size = { 4, 10 },
    speed = { 30, 80 },
    color = { { 0.5, 0.5, 1, 0.9 }, { 0.3, 0.3, 0.9, 0 } },
    spread = math.pi * 2 -- All directions
}

AnimationManager.PARTICLE_TEMPLATES.abilityRadial = {
    particleCount = 30,
    lifetime = { 0.4, 0.9 },
    size = { 3, 8 },
    speed = { 30, 70 },
    color = { { 0.4, 0.4, 1, 0.8 }, { 0.2, 0.2, 0.8, 0 } },
    spread = math.pi * 2 -- All directions
}

AnimationManager.PARTICLE_TEMPLATES.healingCharge = {
    particleCount = 5,
    lifetime = { 0.3, 0.7 },
    size = { 2, 6 },
    speed = { 10, 30 },
    color = { { 0.3, 1, 0.3, 0.8 }, { 0.2, 0.8, 0.2, 0 } },
    spread = math.pi * 2 -- All directions
}

AnimationManager.PARTICLE_TEMPLATES.healingEffect = {
    particleCount = 25,
    lifetime = { 0.5, 1.2 },
    size = { 4, 10 },
    speed = { 20, 50 },
    color = { { 0.3, 1, 0.3, 0.9 }, { 0.2, 0.8, 0.2, 0 } },
    spread = math.pi * 2 -- All directions
}

-- Create an ability animation (MODIFIED: Add logging)
function AnimationManager:createAbilityAnimation(unit, abilityType, targetPosition, grid, onComplete)
    if not grid then print("ERROR: createAbilityAnimation called without grid!"); return nil end -- Grid is required
    if self.animatingUnits[unit] then return nil end
    self.animatingUnits[unit] = true
    local manager = self -- Capture self

    local style = manager.ANIMATION_PRESETS[manager.defaultStyle]; local abilityStyle = style.ability
    local direction = 0; local distance = 0
    if targetPosition then local dx = targetPosition.x - unit.x; local dy = targetPosition.y - unit.y; distance = math.sqrt(dx*dx + dy*dy); direction = math.atan(dy, dx) end
    local animId = "ability_" .. unit.id .. "_" .. os.time() .. "_" .. math.random(1000)
    local animation = {
        id = animId, unit = unit, type = "ability", abilityType = abilityType or "default",
        startTime = love.timer.getTime(),
        duration = abilityStyle.duration.charge + abilityStyle.duration.release + abilityStyle.duration.recover,
        completed = false, direction = direction, targetPosition = targetPosition,
        grid = grid, -- *** ADD: Store grid reference ***
        onComplete = onComplete
    }
    manager.activeAnimations[animId] = animation
    
    unit.visualX = unit.visualX or unit.x; unit.visualY = unit.visualY or unit.y
    unit.scale = unit.scale or {x = 1, y = 1}; unit.rotation = unit.rotation or 0; unit.offset = unit.offset or {x = 0, y = 0}
    local abilityColor = {0.3, 0.3, 1, 1}; if abilityType == "attack" then abilityColor = {1, 0.3, 0.3, 1} elseif abilityType == "defense" then abilityColor = {0.3, 0.7, 1, 1} elseif abilityType == "support" then abilityColor = {0.3, 1, 0.3, 1} elseif abilityType == "special" then abilityColor = {1, 0.8, 0.2, 1} end


    local chargeDuration = abilityStyle.duration.charge
    local elapsedTime = 0
    manager.timer:during(
        chargeDuration,
        function(dt) -- Callback only receives dt
            elapsedTime = elapsedTime + dt
            local progress = 0; if chargeDuration > 0 then progress = math.min(1, elapsedTime / chargeDuration) else progress = 1 end

            -- ... (Pulsing effect, rotation) ...
            local pulseScale = 1 + math.sin(progress * abilityStyle.pulse.frequency) * abilityStyle.pulse.scale * progress
            unit.scale.x = pulseScale; unit.scale.y = pulseScale; unit.rotation = math.sin(progress * 10) * 0.1


            -- Create charging particles
            if math.random() < 0.3 then
                -- Use animation.grid for screen coords
                local px, py = animation.grid:gridToScreen(unit.visualX, unit.visualY)
                px = px + animation.grid.tileSize/2; py = py + animation.grid.tileSize/2
                manager:createParticles("abilityCharge", px, py, math.random() * math.pi * 2)
           end
        end,
        function() -- onComplete for 'during'
            -- ... (rest of the tween chain - ensure 'manager' is used here too) ...
            if unit.flash then unit:flash(0.2, abilityColor) end
            manager.timer:tween(abilityStyle.duration.release, unit.scale, {x = 1.5, y = 1.5}, 'out-elastic', function()
                -- Use animation.grid for screen coords
                local particleOriginX, particleOriginY = animation.grid:gridToScreen(unit.visualX, unit.visualY); particleOriginX = particleOriginX + animation.grid.tileSize / 2; particleOriginY = particleOriginY + animation.grid.tileSize / 2
                if targetPosition then
                    local targetScreenX, targetScreenY = animation.grid:gridToScreen(targetPosition.x, targetPosition.y); targetScreenX = targetScreenX + animation.grid.tileSize / 2; targetScreenY = targetScreenY + animation.grid.tileSize / 2
                    manager:createParticles("abilityEffect", particleOriginX, particleOriginY, direction)
                    manager:createParticles("abilityImpact", targetScreenX, targetScreenY, 0)
                else
                    manager:createParticles("abilityRadial", particleOriginX, particleOriginY, 0)
                end
                manager:shakeScreen(0.3, 0.2)
                manager.timer:tween(abilityStyle.duration.recover, unit.scale, {x = 1, y = 1}, 'in-out-quad', function()
                    unit.rotation = 0; animation.completed = true
                    unit.visualX = unit.x; unit.visualY = unit.y; unit.offset = {x=0, y=0}; unit.scale = {x=1, y=1}; unit.animationState = "idle"
                    if onComplete then onComplete() end
                end)
            end)
        end
    )
    return animId
end

-- Ability-specific animations (MODIFIED: Use 'manager' upvalue)
local ABILITY_ANIMATIONS = {
    knights_charge = function(unit, targetPosition, animationManager)
        -- *** FIX: Capture animationManager instance ***
        local manager = animationManager
        -- *** END FIX ***
        if manager.animatingUnits[unit] then return nil end; manager.animatingUnits[unit] = true
        local dx = targetPosition.x - unit.x; local dy = targetPosition.y - unit.y; local distance = math.sqrt(dx * dx +
        dy * dy); local direction = math.atan(dy, dx)
        local animId = "ability_knights_charge_" .. unit.id .. "_" .. os.time(); local startX, startY = unit.visualX,
            unit.visualY
        local animation = { id = animId, unit = unit, type = "ability", abilityType = "knights_charge", startTime = love
        .timer.getTime(), duration = 0.8, completed = false, direction = direction, targetPosition = targetPosition }
        manager.activeAnimations[animId] = animation

        -- *** FIX: Use 'manager' inside callbacks ***
        manager.timer:tween(0.15, unit.scale, { x = 0.7, y = 1.3 }, 'in-back', function()
            manager.timer:during(0.3,
                function(dt, timeLeft, totalTime)                       -- Note: HUMP during might not pass totalTime, adjust if needed
                    local chargeDuration = 0.3                          -- Hardcode or pass duration
                    local progress = 1 - (timeLeft / chargeDuration); local easedProgress = manager.timer.tween.out_quad(
                    progress)
                    unit.visualX = startX + (targetPosition.x - startX) * easedProgress; unit.visualY = startY +
                    (targetPosition.y - startY) * easedProgress
                    unit.scale.x = 1.8; unit.scale.y = 0.6; unit.offset.y = -5
                    if math.random() < 0.5 then
                        local px, py = manager.game.grid:gridToScreen(unit.visualX, unit.visualY);
                        px = px + manager.game.grid.tileSize / 2; py = py + manager.game.grid.tileSize / 2;
                        manager:createParticles("movementTrail", px, py, direction - math.pi)
                    end
                end, function()
                local targetScreenX, targetScreenY = manager.game.grid:gridToScreen(targetPosition.x, targetPosition.y)
                targetScreenX = targetScreenX + manager.game.grid.tileSize / 2; targetScreenY = targetScreenY +
                manager.game.grid.tileSize / 2;
                manager:createParticles("abilityImpact", targetScreenX, targetScreenY, 0)
                manager:shakeScreen(0.5, 0.2); if unit.flash then unit:flash(0.2, { 1, 0.3, 0.3, 1 }) end
                manager.timer:tween(0.25, unit.scale, { x = 1, y = 1 }, 'out-bounce', function()
                    unit.offset.y = 0; animation.completed = true; unit.animationState = "idle"
                    unit.visualX = unit.x; unit.visualY = unit.y
                end)
            end)
        end)
        -- *** END FIX ***
        return animId
    end,

    -- Bishop abilities
    healing_light = function(unit, targetPosition, animationManager)
        -- *** FIX: Capture animationManager instance ***
        local manager = animationManager
        -- *** END FIX ***
        if manager.animatingUnits[unit] then return nil end; manager.animatingUnits[unit] = true
        local animId = "ability_healing_light_" .. unit.id .. "_" .. os.time()
        local animation = { id = animId, unit = unit, type = "ability", abilityType = "healing_light", startTime = love
        .timer.getTime(), duration = 1.0, completed = false, targetPosition = targetPosition }
        manager.activeAnimations[animId] = animation

        -- *** FIX: Use 'manager' inside callbacks ***
        local chargeDuration = 0.4
        local elapsedTime = 0
        manager.timer:during(chargeDuration, function(dt)
            elapsedTime = elapsedTime + dt
            local progress = 0; if chargeDuration > 0 then progress = math.min(1, elapsedTime / chargeDuration) else progress = 1 end
            local pulseScale = 1 + math.sin(progress * 15) * 0.1 * progress
            unit.scale.x = pulseScale; unit.scale.y = pulseScale
            if math.random() < 0.3 then
                local px, py = manager.game.grid:gridToScreen(unit.visualX, unit.visualY);
                px = px + manager.game.grid.tileSize / 2; py = py + manager.game.grid.tileSize / 2;
                manager:createParticles("healingCharge", px, py, math.random() * math.pi * 2)
            end
        end, function()
            if unit.flash then unit:flash(0.3, { 0.3, 1, 0.3, 0.7 }) end
            local targetScreenX, targetScreenY = manager.game.grid:gridToScreen(targetPosition.x, targetPosition.y)
            targetScreenX = targetScreenX + manager.game.grid.tileSize / 2; targetScreenY = targetScreenY +
            manager.game.grid.tileSize / 2;
            manager:createParticles("healingEffect", targetScreenX, targetScreenY, 0)
            manager.timer:tween(0.3, unit.scale, { x = 1, y = 1 }, 'in-out-quad', function()
                animation.completed = true; unit.animationState = "idle"
                unit.visualX = unit.x; unit.visualY = unit.y
            end)
        end)
        -- *** END FIX ***
        return animId
    end
}

-- *** REMOVE Unit class modifications ***
-- local Unit = require("src.entities.unit")
-- function Unit:useAbilityWithAnimation(abilityType, targetPosition) ... end
-- function Unit:attack(targetUnit) ... end
-- *** END REMOVAL ***

-- *** FIX: Define as a method on the prototype ***
-- Function to get ability-specific animation
function AnimationManager:getAbilityAnimation(abilityName)
    -- *** END FIX ***
    return ABILITY_ANIMATIONS[abilityName]
end

return AnimationManager
