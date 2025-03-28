-- Unit Animation Extension for Nightfall
-- Extends the Unit class with animation properties and methods
-- Implements arcade-style animations for movement, attacks, and abilities

print("--- LOADING unit_animation_extension.lua ---")

local class = require("lib.middleclass.middleclass")
local Unit = require("src.entities.unit")

-- Store the original Unit:initialize method
local originalInitialize = Unit.initialize
local originalUpdate = Unit.update
local originalDraw = Unit.draw
local originalMoveTo = Unit.moveTo or function() return true end

-- Extend the Unit:initialize method to add animation properties
function Unit:initialize(params)
    -- Call the original initialize method
    originalInitialize(self, params)
    
    -- Add visual position (separate from logical grid position)
    self.visualX = self.x
    self.visualY = self.y
    
    -- Add animation properties
    self.scale = {x = 1, y = 1}
    self.rotation = 0
    self.offset = {x = 0, y = 0}
    self.color = {1, 1, 1, 1}
    
    -- Animation state tracking
    self.animationState = "idle"
    self.animationTimer = 0
    self.animationFrame = 1
    self.animationDirection = 1 -- 1 = right, -1 = left
    
    -- Flash effect
    self.flashTimer = 0
    self.flashDuration = 0
    self.flashColor = {1, 1, 1, 0}
    
    -- Shadow properties
    self.shadowScale = 1
    self.shadowAlpha = 0.5
end

-- Extend the Unit:update method to update animation state
function Unit:update(dt)
    -- Call the original update method
    originalUpdate(self, dt)
    
    -- Update flash effect
    if self.flashTimer > 0 then
        self.flashTimer = self.flashTimer - dt
        
        -- Update flash color alpha based on remaining time
        local flashProgress = self.flashTimer / self.flashDuration
        self.flashColor[4] = flashProgress
    end
    
    -- Update animation frame for idle animation
    if self.animationState == "idle" then
        self.animationTimer = self.animationTimer + dt
        
        -- Subtle idle animation - slight bobbing
        local idleBobAmount = 0.03
        local idleBobSpeed = 2
        self.offset.y = -math.sin(self.animationTimer * idleBobSpeed) * idleBobAmount
    end
end

-- Extend the Unit:draw method to apply animation transformations
function Unit:draw()
    if not self.grid then return end
    
    -- Calculate screen position based on visual position
    local screenX, screenY = self.grid:gridToScreen(self.visualX, self.visualY)
    local tileSize = self.grid.tileSize
    
    -- Draw shadow
    love.graphics.setColor(0, 0, 0, self.shadowAlpha)
    local shadowX = screenX + tileSize/2
    local shadowY = screenY + tileSize - 4
    local shadowWidth = tileSize * 0.7 * self.shadowScale
    local shadowHeight = tileSize * 0.2
    love.graphics.ellipse("fill", shadowX, shadowY, shadowWidth/2, shadowHeight/2)
    
    -- Apply transformations
    love.graphics.push()
    
    -- Translate to center of tile
    love.graphics.translate(
        screenX + tileSize/2 + self.offset.x, 
        screenY + tileSize/2 + self.offset.y
    )
    
    -- Apply rotation
    love.graphics.rotate(self.rotation)
    
    -- Apply scale
    love.graphics.scale(self.scale.x, self.scale.y)
    
    -- Translate back to corner for drawing
    love.graphics.translate(-tileSize/2, -tileSize/2)
    
    -- Draw unit based on type
    local color = self.faction == "player" and {0.2, 0.6, 0.9} or {0.9, 0.3, 0.3}
    
    -- Apply unit color
    love.graphics.setColor(
        color[1] * self.color[1],
        color[2] * self.color[2],
        color[3] * self.color[3],
        self.color[4]
    )
    
    -- Draw unit body
    love.graphics.rectangle("fill", 4, 4, tileSize - 8, tileSize - 8)
    
    -- Draw unit border
    love.graphics.setColor(1, 1, 1, 0.8 * self.color[4])
    love.graphics.rectangle("line", 4, 4, tileSize - 8, tileSize - 8)
    
    -- Draw unit type indicator
    love.graphics.setColor(1, 1, 1, self.color[4])
    love.graphics.printf(self.unitType:sub(1, 1):upper(), 0, tileSize/2 - 10, tileSize, "center")
    
    -- Draw action state indicators
    if self.hasMoved then
        love.graphics.setColor(0.8, 0.8, 0.2, 0.5 * self.color[4])
        love.graphics.rectangle("fill", tileSize - 8, 0, 8, 8)
    end
    
    if self.hasAttacked then
        love.graphics.setColor(0.8, 0.2, 0.2, 0.5 * self.color[4])
        love.graphics.rectangle("fill", tileSize - 8, 8, 8, 8)
    end
    
    if self.hasUsedAbility then
        love.graphics.setColor(0.2, 0.2, 0.8, 0.5 * self.color[4])
        love.graphics.rectangle("fill", tileSize - 8, 16, 8, 8)
    end
    
    -- Restore transformation
    love.graphics.pop()
    
    -- Draw flash effect on top
    if self.flashTimer > 0 then
        love.graphics.setColor(
            self.flashColor[1], 
            self.flashColor[2], 
            self.flashColor[3], 
            self.flashColor[4]
        )
        love.graphics.rectangle("fill", screenX, screenY, tileSize, tileSize)
    end
end

-- Override the Unit:moveTo method to use animations
function Unit:moveTo(targetX, targetY)
    print(string.format(">>> Unit:moveTo (Extended) - Unit: %s, Target: (%d,%d)", self.id or "N/A", targetX, targetY)) -- Log entry

    -- Store old position for grid update if needed later
    local oldX, oldY = self.x, self.y

    -- Update logical position immediately
    self.x = targetX
    self.y = targetY
    print(string.format("  Updated logical position to (%d,%d)", self.x, self.y))

    -- Check for Animation Manager
    local animManager = nil
    if self.grid and self.grid.game and self.grid.game.animationManager then
        animManager = self.grid.game.animationManager
        print("  Animation Manager FOUND.")
    else
        print("  Animation Manager NOT FOUND. Checking references:")
        print("    self.grid:", tostring(self.grid))
        if self.grid then print("    self.grid.game:", tostring(self.grid.game)) end
        if self.grid and self.grid.game then print("    self.grid.game.animationManager:", tostring(self.grid.game.animationManager)) end
    end

    -- If animation manager exists, create movement animation
    if animManager then
        -- Check if unit is already animating (important!)
        if animManager:isUnitAnimating(self) then
             print("  WARNING: Unit is already animating. Skipping new move animation.")
             -- Optionally, decide how to handle this: queue the move, cancel old anim, etc.
             -- For now, we just skip creating a new one. The logical position IS updated.
             -- We might need to manually update visual pos here if we skip the anim.
             self.visualX = targetX
             self.visualY = targetY
             return true -- Indicate logical move happened
        end

        print("  Attempting to create movement animation...")
        -- Set animation direction based on movement
        if targetX > oldX then self.animationDirection = 1
        elseif targetX < oldX then self.animationDirection = -1 end
        -- Consider adding vertical check if needed:
        -- elseif targetY > oldY then ...
        -- elseif targetY < oldY then ...

        -- Create movement animation
        local animId = animManager:createMovementAnimation(
            self,
            targetX,
            targetY,
            function()
                -- Animation completed callback
                print(string.format("  Movement animation COMPLETE for unit %s.", self.id or "N/A"))
                self.animationState = "idle"
                -- If the grid needs explicit updating after animation:
                -- if self.grid and self.grid.updateEntityPosition then
                --    self.grid:updateEntityPosition(self, oldX, oldY) -- Update grid spatial data if necessary
                -- end
            end
        )

        if animId then
            print("  Movement animation created successfully (ID: " .. animId .. ")")
            -- Update animation state
            self.animationState = "moving"
            print("<<< Unit:moveTo (Extended) - Returning true (animation started)")
            return true
        else
            print("  ERROR: createMovementAnimation returned nil!")
            -- Fallback: update visual position directly if animation fails
            self.visualX = targetX
            self.visualY = targetY
            print("<<< Unit:moveTo (Extended) - Returning true (animation failed, fallback)")
            return true
        end
    else
        -- No animation manager, just update visual position immediately
        print("  No Animation Manager. Updating visual position directly.")
        self.visualX = targetX
        self.visualY = targetY

        -- Update the grid spatial hash if necessary (since there's no animation callback)
        -- This depends on how your grid/collision works. If placeEntity/moveEntity handles it, call it.
        if self.grid and self.grid.world and self.grid.world.update then -- Check bump world specifically
             local screenX, screenY = self.grid:gridToScreen(targetX, targetY)
             self.grid.world:update(self, screenX, screenY)
             print("  Manually updated bump world position.")
        end

        print("<<< Unit:moveTo (Extended) - Returning true (no animation manager)")
        return true -- Still return true as the logical move happened
    end
end

-- Add method to create a flash effect
function Unit:flash(duration, color)
    self.flashTimer = duration or 0.2
    self.flashDuration = self.flashTimer
    self.flashColor = color or {1, 1, 1, 1}
end

-- Add method to create a hit effect
function Unit:showHitEffect()
    -- Flash red
    self:flash(0.2, {1, 0.3, 0.3, 1})
    
    -- Shake briefly
    if self.grid and self.grid.game and self.grid.game.animationManager then
        self.grid.game.animationManager:shakeScreen(0.3, 0.2)
    end
end

-- Add method to create a heal effect
function Unit:showHealEffect()
    -- Flash green
    self:flash(0.3, {0.3, 1, 0.3, 0.7})
end

-- Add method to create an ability effect
function Unit:showAbilityEffect(abilityType)
    -- Flash based on ability type
    local color = {0.3, 0.3, 1, 0.7} -- Default blue
    
    if abilityType == "attack" then
        color = {1, 0.3, 0.3, 0.7} -- Red for attack
    elseif abilityType == "defense" then
        color = {0.3, 0.7, 1, 0.7} -- Blue for defense
    elseif abilityType == "support" then
        color = {0.3, 1, 0.3, 0.7} -- Green for support
    elseif abilityType == "special" then
        color = {1, 0.8, 0.2, 0.7} -- Gold for special
    end
    
    self:flash(0.4, color)
end

return Unit
