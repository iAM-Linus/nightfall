-- Grid System for Nightfall Chess
-- Handles the game grid, tile management, and grid-based operations

local class = require("lib.middleclass.middleclass")
local bump = require("lib.bump")
local bresenham = require("lib.bresenham")

local Grid = class("Grid")

function Grid:initialize(width, height, tileSize, game)
    self.width = width or 8
    self.height = height or 8
    self.tileSize = tileSize or 64
    self.game = game
    
    -- Create the collision world
    self.world = bump.newWorld(tileSize)
    
    -- Initialize the grid with empty tiles
    self.tiles = {}
    for y = 1, self.height do
        self.tiles[y] = {}
        for x = 1, self.width do
            self.tiles[y][x] = {
                type = "floor",
                walkable = true,
                visible = false,
                explored = false,
                entity = nil,
                x = x,
                y = y
            }
        end
    end
    
    -- Track entities on the grid
    self.entities = {}
    
    -- Fog of war settings
    self.fogOfWar = true
    self.visibilityRange = 4

    print("Grid initialized. Game reference stored:", tostring(self.game ~= nil)) -- Add confirmation
end

-- Convert grid coordinates to screen coordinates
function Grid:gridToScreen(gridX, gridY)
    return (gridX - 1) * self.tileSize, (gridY - 1) * self.tileSize
end

-- Convert screen coordinates to grid coordinates
function Grid:screenToGrid(screenX, screenY)
    local gridX = math.floor(screenX / self.tileSize) + 1
    local gridY = math.floor(screenY / self.tileSize) + 1
    
    -- Ensure coordinates are within grid bounds
    gridX = math.max(1, math.min(gridX, self.width))
    gridY = math.max(1, math.min(gridY, self.height))
    
    return gridX, gridY
end

-- Check if coordinates are within grid bounds
function Grid:isInBounds(x, y)
    return x >= 1 and x <= self.width and y >= 1 and y <= self.height
end

-- Get a tile at the specified coordinates
function Grid:getTile(x, y)
    if self:isInBounds(x, y) then
        return self.tiles[y][x]
    end
    return nil
end

-- Set a tile type at the specified coordinates
function Grid:setTileType(x, y, tileType, walkable)
    if self:isInBounds(x, y) then
        self.tiles[y][x].type = tileType
        
        if walkable ~= nil then
            self.tiles[y][x].walkable = walkable
        else
            -- Default walkability based on tile type
            local walkableTypes = {floor = true, grass = true, water = false, wall = false, lava = false}
            self.tiles[y][x].walkable = walkableTypes[tileType] or false
        end
    end
end

function Grid:getTileType(x, y)
    if self:isInBounds(x, y) then
        return self.tiles[y][x].type
    end
end

function Grid:isVisible(x, y)
     return self:getTile(x, y).visible
end

function Grid:isExplored(x, y)
    return self:getTile(x, y).explored
end

-- Place an entity on the grid
function Grid:placeEntity(entity, x, y)
    -- Add detailed logging at the start
    print(string.format(">>> Grid:placeEntity - Attempting to place '%s' (ID: %s, Type: %s, Faction: %s) at (%d, %d)",
          entity.name or "N/A", entity.id or "N/A", entity.unitType or "N/A", entity.faction or "N/A", x, y))

    if not self:isInBounds(x, y) then
        print("  ERROR: Position (" .. x .. "," .. y .. ") is out of bounds (" .. self.width .. "x" .. self.height .. ").")
        return false
    end

    local tile = self.tiles[y][x]

    -- Add check for tile existence (shouldn't fail if isInBounds works)
    if not tile then
        print("  ERROR: Tile object doesn't exist at target location! Grid corrupted?")
        return false
    end

    -- Check walkability
    if not tile.walkable then
        print("  WARNING: Target tile (" .. x .. "," .. y .. ") is not walkable (Type: " .. tile.type .. "). Placing anyway for debugging, but this might be an issue.")
        -- Decide if you want to return false here in the future:
        -- return false
    end

    -- Check occupancy
    if tile.entity then
        print(string.format("  ERROR: Target tile (%d, %d) already occupied by '%s' (ID: %s).", x, y, tile.entity.name or "N/A", tile.entity.id or "N/A"))
        return false -- Definitely return false if occupied
    end

    -- Remove entity from its current position if it exists and is on the grid
    if entity.x and entity.y and self:isInBounds(entity.x, entity.y) then
        local oldTile = self.tiles[entity.y][entity.x]
        if oldTile and oldTile.entity == entity then
            oldTile.entity = nil
            print(string.format("  Removed entity from previous position (%d, %d)", entity.x, entity.y))
        else
            print(string.format("  Entity had previous coords (%d,%d) but wasn't found there in grid tile.", entity.x, entity.y))
        end
    else
         print("  Entity had no valid previous position to remove from.")
    end

    -- Place entity at the new position
    tile.entity = entity
    entity.x = x
    entity.y = y
    print(string.format("  Set tile (%d, %d) entity to %s.", x, y, entity.id))

    -- Add to collision world (add more logging here if needed)
    local screenX, screenY = self:gridToScreen(x, y)
    if self.world then
        if self.world:hasItem(entity) then
            print("  Updating entity in bump world.")
            self.world:update(entity, screenX, screenY) -- Use update if it exists
        else
            print("  Adding entity to bump world.")
            self.world:add(entity, screenX, screenY, self.tileSize, self.tileSize)
        end
    else
        print("  WARNING: Bump world (self.world) not initialized in grid.")
    end


    -- Add to entities list if not already there
    if not self.entities[entity] then
        self.entities[entity] = true
        print(string.format("  Added entity %s to grid.entities. Total entities: %d", entity.id, self:countEntities()))
    else
         print(string.format("  Entity %s already in grid.entities. (Likely due to moving)", entity.id))
    end

    -- Update entity grid reference
    entity.grid = self

    -- Update visibility (Deferring this might be safer initially)
    -- print("  Deferring visibility update.")
    -- if entity.isPlayerControlled then
    --    self:updateVisibility()
    -- end

    print(string.format("<<< Grid:placeEntity - Succeeded placing '%s' at (%d, %d)", entity.name or entity.id, x, y))
    return true
end

-- Helper to count entities for debugging (Add this function to grid.lua)
function Grid:countEntities()
    local count = 0
    for _ in pairs(self.entities or {}) do -- Add safety check for self.entities
        count = count + 1
    end
    return count
end

-- Move an entity on the grid
function Grid:moveEntity(entity, newX, newY)
    return self:placeEntity(entity, newX, newY)
end

-- Remove an entity from the grid
function Grid:removeEntity(entity)
    if entity.x and entity.y and self:isInBounds(entity.x, entity.y) then
        self.tiles[entity.y][entity.x].entity = nil
        self.world:remove(entity)
        self.entities[entity] = nil
    end
end

-- Get entity at the specified coordinates
function Grid:getEntityAt(x, y)
    if self:isInBounds(x, y) then
        return self.tiles[y][x].entity
    end
    return nil
end

-- Check if a tile is walkable
function Grid:isWalkable(x, y)
    local tile = self:getTile(x, y)
    return tile and tile.walkable and not tile.entity
end

function Grid:isValidPosition(x, y)
    return self:isWalkable(x, y)
end

-- Get all walkable neighbors of a tile
function Grid:getWalkableNeighbors(x, y)
    local neighbors = {}
    local directions = {
        {x = 0, y = -1}, -- North
        {x = 1, y = 0},  -- East
        {x = 0, y = 1},  -- South
        {x = -1, y = 0}  -- West
    }
    
    for _, dir in ipairs(directions) do
        local nx, ny = x + dir.x, y + dir.y
        if self:isInBounds(nx, ny) and self:isWalkable(nx, ny) then
            table.insert(neighbors, {x = nx, y = ny})
        end
    end
    
    return neighbors
end

-- Calculate path between two points using A* algorithm
function Grid:findPath(startX, startY, endX, endY)
    -- Check if start and end are valid
    if not self:isInBounds(startX, startY) or not self:isInBounds(endX, endY) then
        return nil
    end
    
    -- Check if end is walkable
    if not self:isWalkable(endX, endY) then
        return nil
    end
    
    -- A* implementation
    local openSet = {}
    local closedSet = {}
    local cameFrom = {}
    local gScore = {}
    local fScore = {}
    
    -- Initialize start node
    local startNode = startX .. "," .. startY
    openSet[startNode] = true
    gScore[startNode] = 0
    fScore[startNode] = self:heuristic(startX, startY, endX, endY)
    
    while next(openSet) ~= nil do
        -- Find node with lowest fScore
        local current = nil
        local lowestFScore = math.huge
        
        for node, _ in pairs(openSet) do
            if fScore[node] < lowestFScore then
                current = node
                lowestFScore = fScore[node]
            end
        end
        
        -- Extract x,y from node string
        local cx, cy = current:match("(%d+),(%d+)")
        cx, cy = tonumber(cx), tonumber(cy)
        
        -- Check if we reached the goal
        if cx == endX and cy == endY then
            -- Reconstruct path
            local path = {}
            local curr = current
            
            while curr do
                local x, y = curr:match("(%d+),(%d+)")
                table.insert(path, 1, {x = tonumber(x), y = tonumber(y)})
                curr = cameFrom[curr]
            end
            
            return path
        end
        
        -- Move current from open to closed set
        openSet[current] = nil
        closedSet[current] = true
        
        -- Check neighbors
        local neighbors = self:getWalkableNeighbors(cx, cy)
        for _, neighbor in ipairs(neighbors) do
            local neighborNode = neighbor.x .. "," .. neighbor.y
            
            -- Skip if in closed set
            if closedSet[neighborNode] then
                goto continue
            end
            
            -- Calculate tentative gScore
            local tentativeGScore = gScore[current] + 1
            
            -- Add to open set if not there
            if not openSet[neighborNode] then
                openSet[neighborNode] = true
            elseif tentativeGScore >= (gScore[neighborNode] or math.huge) then
                goto continue
            end
            
            -- This path is better, record it
            cameFrom[neighborNode] = current
            gScore[neighborNode] = tentativeGScore
            fScore[neighborNode] = gScore[neighborNode] + self:heuristic(neighbor.x, neighbor.y, endX, endY)
            
            ::continue::
        end
    end
    
    -- No path found
    return nil
end

-- Heuristic function for A* (Manhattan distance)
function Grid:heuristic(x1, y1, x2, y2)
    return math.abs(x2 - x1) + math.abs(y2 - y1)
end

-- Update visibility based on player units
function Grid:updateVisibility()
    -- Reset visibility
    for y = 1, self.height do
        for x = 1, self.width do
            self.tiles[y][x].visible = false
        end
    end
    
    -- If fog of war is disabled, make everything visible
    if not self.fogOfWar then
        for y = 1, self.height do
            for x = 1, self.width do
                self.tiles[y][x].visible = true
                self.tiles[y][x].explored = true
            end
        end
        return
    end
    
    -- Find all player-controlled units
    local playerUnits = {}
    for entity, _ in pairs(self.entities) do
        if entity.isPlayerControlled then
            table.insert(playerUnits, entity)
        end
    end
    
    -- Update visibility based on each player unit
    for _, unit in ipairs(playerUnits) do
        self:updateVisibilityFromUnit(unit)
    end
end

-- Update visibility from a specific unit
function Grid:updateVisibilityFromUnit(unit)
    local x, y = unit.x, unit.y
    local visibilityRange = unit.visibilityRange or self.visibilityRange
    
    -- Mark the unit's tile as visible
    local tile = self:getTile(x, y)
    if tile then
        tile.visible = true
        tile.explored = true
    end
    
    -- Check visibility in all directions
    for dy = -visibilityRange, visibilityRange do
        for dx = -visibilityRange, visibilityRange do
            local targetX, targetY = x + dx, y + dy
            
            -- Skip if out of bounds or beyond visibility range
            if not self:isInBounds(targetX, targetY) or math.abs(dx) + math.abs(dy) > visibilityRange then
                goto continue
            end
            
            -- Check line of sight
            if self:hasLineOfSight(x, y, targetX, targetY) then
                local targetTile = self:getTile(targetX, targetY)
                targetTile.visible = true
                targetTile.explored = true
            end
            
            ::continue::
        end
    end
end

-- Check if there's a clear line of sight between two points
function Grid:hasLineOfSight(x1, y1, x2, y2)
    local points = bresenham.line(x1, y1, x2, y2)
    
    -- Skip the first point (starting position)
    for i = 2, #points do
        local point = points[i]
        local tile = self:getTile(point.x, point.y)
        
        -- If we hit a wall or other blocking tile, line of sight is blocked
        if tile and not tile.walkable then
            -- Allow seeing the blocking tile itself
            if point.x == x2 and point.y == y2 then
                return true
            end
            return false
        end
        
        -- If we've reached the end point, there's a clear line of sight
        if point.x == x2 and point.y == y2 then
            return true
        end
    end
    
    return true
end

-- Draw the grid
function Grid:draw(camera)
    local offsetX = camera and camera.x or 0
    local offsetY = camera and camera.y or 0
    
    -- Draw tiles
    for y = 1, self.height do
        for x = 1, self.width do
            local tile = self.tiles[y][x]
            local screenX, screenY = self:gridToScreen(x, y)
            
            -- Apply camera offset
            screenX = screenX - offsetX
            screenY = screenY - offsetY
            
            -- Skip if outside screen
            if screenX < -self.tileSize or screenY < -self.tileSize or
               screenX > love.graphics.getWidth() or screenY > love.graphics.getHeight() then
                goto continue
            end
            
            -- Draw based on visibility
            if tile.visible then
                -- Fully visible tile
                love.graphics.setColor(1, 1, 1, 1)
            elseif tile.explored then
                -- Explored but not currently visible
                love.graphics.setColor(0.5, 0.5, 0.5, 1)
            else
                -- Unexplored and not visible
                love.graphics.setColor(0, 0, 0, 1)
                love.graphics.rectangle("fill", screenX, screenY, self.tileSize, self.tileSize)
                goto continue
            end
            
            -- Draw the tile
            local tileImage = love.graphics.getImage("tile_" .. tile.type)
            if tileImage then
                love.graphics.draw(tileImage, screenX, screenY)
            else
                -- Fallback if image not found
                love.graphics.rectangle("fill", screenX, screenY, self.tileSize, self.tileSize)
                love.graphics.setColor(0, 0, 0, 1)
                love.graphics.rectangle("line", screenX, screenY, self.tileSize, self.tileSize)
            end
            
            ::continue::
        end
    end
    
    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

return Grid
