-- Camera System for Nightfall Chess
-- Handles camera movement, zooming, and screen-to-world coordinate conversion

local class = require("lib.middleclass.middleclass")

local Camera = class("Camera")

function Camera:initialize(params)
    params = params or {}
    
    -- Position
    self.x = params.x or 0
    self.y = params.y or 0
    
    -- Target position (for smooth movement)
    self.targetX = self.x
    self.targetY = self.y
    
    -- Zoom level
    self.scale = params.scale or 1
    self.targetScale = self.scale
    
    -- Movement speed
    self.moveSpeed = params.moveSpeed or 10
    self.zoomSpeed = params.zoomSpeed or 4
    
    -- Bounds
    self.bounds = params.bounds or {
        left = -math.huge,
        right = math.huge,
        top = -math.huge,
        bottom = math.huge
    }
    
    -- Shake effect
    self.shake = {
        intensity = 0,
        duration = 0,
        frequency = 0,
        offsetX = 0,
        offsetY = 0
    }
end

-- Update camera position and effects
function Camera:update(dt)
    -- Smooth movement towards target
    local dx = self.targetX - self.x
    local dy = self.targetY - self.y
    
    if math.abs(dx) > 0.1 then
        self.x = self.x + dx * math.min(1, self.moveSpeed * dt)
    else
        self.x = self.targetX
    end
    
    if math.abs(dy) > 0.1 then
        self.y = self.y + dy * math.min(1, self.moveSpeed * dt)
    else
        self.y = self.targetY
    end
    
    -- Smooth zooming
    local dScale = self.targetScale - self.scale
    
    if math.abs(dScale) > 0.01 then
        self.scale = self.scale + dScale * math.min(1, self.zoomSpeed * dt)
    else
        self.scale = self.targetScale
    end
    
    -- Enforce bounds
    self:enforceBounds()
    
    -- Update shake effect
    self:updateShake(dt)
end

-- Set camera position
function Camera:setPosition(x, y, immediate)
    self.targetX = x
    self.targetY = y
    
    if immediate then
        self.x = x
        self.y = y
    end
    
    self:enforceBounds()
end

-- Move camera by an offset
function Camera:move(dx, dy)
    self.targetX = self.targetX + dx
    self.targetY = self.targetY + dy
    
    self:enforceBounds()
end

-- Set zoom level
function Camera:setZoom(scale, immediate)
    self.targetScale = math.max(0.1, math.min(3, scale))
    
    if immediate then
        self.scale = self.targetScale
    end
end

-- Zoom in or out by a factor
function Camera:zoom(factor)
    self.targetScale = math.max(0.1, math.min(3, self.targetScale * factor))
end

-- Set camera bounds
function Camera:setBounds(left, top, right, bottom)
    self.bounds = {
        left = left or -math.huge,
        top = top or -math.huge,
        right = right or math.huge,
        bottom = bottom or math.huge
    }
    
    self:enforceBounds()
end

-- Enforce camera bounds
function Camera:enforceBounds()
    -- Calculate screen dimensions in world space
    local screenWidth = love.graphics.getWidth() / self.scale
    local screenHeight = love.graphics.getHeight() / self.scale
    
    -- Enforce horizontal bounds
    if self.bounds.right - self.bounds.left < screenWidth then
        -- If bounds are smaller than screen, center camera
        self.targetX = (self.bounds.left + self.bounds.right) / 2 - screenWidth / 2
    else
        -- Otherwise, clamp to bounds
        self.targetX = math.max(self.bounds.left, math.min(self.targetX, self.bounds.right - screenWidth))
    end
    
    -- Enforce vertical bounds
    if self.bounds.bottom - self.bounds.top < screenHeight then
        -- If bounds are smaller than screen, center camera
        self.targetY = (self.bounds.top + self.bounds.bottom) / 2 - screenHeight / 2
    else
        -- Otherwise, clamp to bounds
        self.targetY = math.max(self.bounds.top, math.min(self.targetY, self.bounds.bottom - screenHeight))
    end
end

-- Start a camera shake effect
function Camera:shake(intensity, duration, frequency)
    self.shake.intensity = intensity or 5
    self.shake.duration = duration or 0.5
    self.shake.frequency = frequency or 0.05
    self.shake.timer = 0
end

-- Update shake effect
function Camera:updateShake(dt)
    if self.shake.duration <= 0 then
        self.shake.offsetX = 0
        self.shake.offsetY = 0
        return
    end
    
    self.shake.timer = self.shake.timer + dt
    
    if self.shake.timer >= self.shake.frequency then
        self.shake.timer = 0
        
        -- Calculate random offset based on intensity
        local intensity = self.shake.intensity * (self.shake.duration / self.shake.duration)
        self.shake.offsetX = (math.random() * 2 - 1) * intensity
        self.shake.offsetY = (math.random() * 2 - 1) * intensity
    end
    
    -- Decrease duration
    self.shake.duration = self.shake.duration - dt
end

-- Convert screen coordinates to world coordinates
function Camera:screenToWorld(screenX, screenY)
    local worldX = (screenX / self.scale) + self.x - self.shake.offsetX
    local worldY = (screenY / self.scale) + self.y - self.shake.offsetY
    
    return worldX, worldY
end

-- Convert world coordinates to screen coordinates
function Camera:worldToScreen(worldX, worldY)
    local screenX = (worldX - self.x + self.shake.offsetX) * self.scale
    local screenY = (worldY - self.y + self.shake.offsetY) * self.scale
    
    return screenX, screenY
end

-- Apply camera transformations before rendering
function Camera:apply()
    love.graphics.push()
    love.graphics.scale(self.scale, self.scale)
    love.graphics.translate(-self.x + self.shake.offsetX, -self.y + self.shake.offsetY)
end

-- Reset camera transformations after rendering
function Camera:reset()
    love.graphics.pop()
end

-- Focus camera on a specific entity or position
function Camera:focusOn(target, immediate)
    local targetX, targetY
    
    if type(target) == "table" and target.x and target.y then
        -- Target is an entity with x,y properties
        if target.grid then
            -- Convert grid coordinates to screen coordinates
            targetX, targetY = target.grid:gridToScreen(target.x, target.y)
            
            -- Center on tile
            targetX = targetX + target.grid.tileSize / 2
            targetY = targetY + target.grid.tileSize / 2
        else
            targetX, targetY = target.x, target.y
        end
    elseif type(target) == "table" and #target >= 2 then
        -- Target is a position array [x, y]
        targetX, targetY = target[1], target[2]
    else
        return
    end
    
    -- Center camera on target
    local screenWidth = love.graphics.getWidth() / self.scale
    local screenHeight = love.graphics.getHeight() / self.scale
    
    self:setPosition(
        targetX - screenWidth / 2,
        targetY - screenHeight / 2,
        immediate
    )
end

return Camera
