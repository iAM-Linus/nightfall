-- Entity System for Nightfall Chess
-- Base class for all game entities (units, items, etc.)

local class = require("lib.middleclass.middleclass")

local Entity = class("Entity")

function Entity:initialize(params)
    params = params or {}
    
    -- Basic properties
    self.id = (params.id or "entity_") .. tostring(math.random(1000000))
    self.name = params.name or "Unknown Entity"
    self.description = params.description or ""
    
    -- Position (grid coordinates)
    self.x = params.x or 1
    self.y = params.y or 1
    
    -- Visual properties
    self.sprite = params.sprite
    self.color = params.color or {1, 1, 1, 1}
    self.scale = params.scale or 1
    self.rotation = params.rotation or 0
    
    -- Gameplay properties
    self.solid = params.solid ~= false  -- Default to solid
    self.interactive = params.interactive or false
    self.visible = params.visible ~= false  -- Default to visible
    
    -- Custom properties
    self.properties = params.properties or {}
    
    -- References
    self.grid = nil  -- Will be set when added to grid
    self.game = nil  -- Will be set when added to game
end

-- Update entity logic
function Entity:update(dt)
    -- Base update logic (to be overridden by subclasses)
end

-- Draw the entity
function Entity:draw(offsetX, offsetY)
    offsetX = offsetX or 0
    offsetY = offsetY or 0
    
    if not self.visible or not self.grid then
        return
    end
    
    -- Get screen position
    local screenX, screenY = self.grid:gridToScreen(self.x, self.y)
    screenX = screenX - offsetX
    screenY = screenY - offsetY
    
    -- Draw sprite if available
    if self.sprite then
        love.graphics.setColor(self.color)
        love.graphics.draw(
            self.sprite,
            screenX + self.grid.tileSize / 2,
            screenY + self.grid.tileSize / 2,
            self.rotation,
            self.scale,
            self.scale,
            self.sprite:getWidth() / 2,
            self.sprite:getHeight() / 2
        )
    else
        -- Draw placeholder
        love.graphics.setColor(self.color)
        love.graphics.rectangle(
            "fill",
            screenX + 4,
            screenY + 4,
            self.grid.tileSize - 8,
            self.grid.tileSize - 8
        )
    end
    
    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

-- Check if entity can move to a position
function Entity:canMoveTo(x, y)
    if not self.grid then
        return false
    end
    
    return self.grid:isWalkable(x, y)
end

-- Move entity to a position
function Entity:moveTo(x, y)
    if not self.grid then
        return false
    end
    
    return self.grid:moveEntity(self, x, y)
end

-- Interact with another entity
function Entity:interact(other)
    -- Base interaction logic (to be overridden by subclasses)
    return false
end

-- Get property value
function Entity:getProperty(key, default)
    return self.properties[key] or default
end

-- Set property value
function Entity:setProperty(key, value)
    self.properties[key] = value
end

-- Check if entity is at position
function Entity:isAt(x, y)
    return self.x == x and self.y == y
end

-- Get distance to another entity or position
function Entity:distanceTo(target)
    local targetX, targetY
    
    if type(target) == "table" and target.x and target.y then
        targetX, targetY = target.x, target.y
    elseif type(target) == "table" and #target >= 2 then
        targetX, targetY = target[1], target[2]
    else
        return math.huge
    end
    
    return math.abs(self.x - targetX) + math.abs(self.y - targetY)
end

-- Check if entity is adjacent to another entity or position
function Entity:isAdjacentTo(target)
    return self:distanceTo(target) == 1
end

-- Get direction to another entity or position (returns dx, dy)
function Entity:directionTo(target)
    local targetX, targetY
    
    if type(target) == "table" and target.x and target.y then
        targetX, targetY = target.x, target.y
    elseif type(target) == "table" and #target >= 2 then
        targetX, targetY = target[1], target[2]
    else
        return 0, 0
    end
    
    local dx = targetX - self.x
    local dy = targetY - self.y
    
    -- Normalize to -1, 0, or 1
    if dx ~= 0 then
        dx = dx / math.abs(dx)
    end
    
    if dy ~= 0 then
        dy = dy / math.abs(dy)
    end
    
    return dx, dy
end

return Entity
