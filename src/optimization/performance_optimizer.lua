-- Performance Optimization for Nightfall Chess
-- Identifies and addresses performance bottlenecks

local class = require("lib.middleclass.middleclass")

local PerformanceOptimizer = class("PerformanceOptimizer")

function PerformanceOptimizer:initialize(game)
    self.game = game
    
    -- Performance metrics
    self.metrics = {
        frameTime = {},
        updateTime = {},
        drawTime = {},
        systemTimes = {}
    }
    
    -- Maximum samples to keep
    self.maxSamples = 60
    
    -- Optimization settings
    self.settings = {
        enableObjectPooling = true,
        enableSpatialHashing = true,
        enableLazyLoading = true,
        enableCulling = true,
        enableCaching = true
    }
    
    -- Object pools
    self.objectPools = {}
    
    -- Spatial hash grid
    self.spatialHash = {
        cellSize = 64,
        grid = {},
        entities = {}
    }
    
    -- Cache system
    self.cache = {
        pathfinding = {},
        visibility = {},
        calculations = {}
    }
    
    -- Monitoring state
    self.isMonitoring = false
    self.monitoringStartTime = 0
    self.monitoringDuration = 5 -- seconds
    
    -- Debug visualization
    self.showDebugInfo = false
end

-- Start performance monitoring
function PerformanceOptimizer:startMonitoring()
    self.isMonitoring = true
    self.monitoringStartTime = love.timer.getTime()
    
    -- Clear previous metrics
    self.metrics = {
        frameTime = {},
        updateTime = {},
        drawTime = {},
        systemTimes = {}
    }
    
    print("Performance monitoring started")
end

-- Stop performance monitoring
function PerformanceOptimizer:stopMonitoring()
    self.isMonitoring = false
    
    -- Generate report
    local report = self:generateReport()
    print("Performance monitoring stopped")
    print(report)
    
    return report
end

-- Update performance metrics
function PerformanceOptimizer:update(dt)
    if not self.isMonitoring then return end
    
    -- Check if monitoring duration has elapsed
    if love.timer.getTime() - self.monitoringStartTime > self.monitoringDuration then
        self:stopMonitoring()
        return
    end
    
    -- Record frame time
    table.insert(self.metrics.frameTime, dt)
    if #self.metrics.frameTime > self.maxSamples then
        table.remove(self.metrics.frameTime, 1)
    end
end

-- Record update time
function PerformanceOptimizer:recordUpdateTime(time)
    if not self.isMonitoring then return end
    
    table.insert(self.metrics.updateTime, time)
    if #self.metrics.updateTime > self.maxSamples then
        table.remove(self.metrics.updateTime, 1)
    end
end

-- Record draw time
function PerformanceOptimizer:recordDrawTime(time)
    if not self.isMonitoring then return end
    
    table.insert(self.metrics.drawTime, time)
    if #self.metrics.drawTime > self.maxSamples then
        table.remove(self.metrics.drawTime, 1)
    end
end

-- Record system time
function PerformanceOptimizer:recordSystemTime(systemName, time)
    if not self.isMonitoring then return end
    
    if not self.metrics.systemTimes[systemName] then
        self.metrics.systemTimes[systemName] = {}
    end
    
    table.insert(self.metrics.systemTimes[systemName], time)
    if #self.metrics.systemTimes[systemName] > self.maxSamples then
        table.remove(self.metrics.systemTimes[systemName], 1)
    end
end

-- Generate performance report
function PerformanceOptimizer:generateReport()
    local report = "Performance Report\n"
    report = report .. "=================\n\n"
    
    -- Frame time
    local avgFrameTime = self:calculateAverage(self.metrics.frameTime)
    local minFrameTime = self:calculateMin(self.metrics.frameTime)
    local maxFrameTime = self:calculateMax(self.metrics.frameTime)
    
    report = report .. "Frame Time:\n"
    report = report .. string.format("  Average: %.4f ms (%.1f FPS)\n", avgFrameTime * 1000, 1 / avgFrameTime)
    report = report .. string.format("  Min: %.4f ms (%.1f FPS)\n", minFrameTime * 1000, 1 / minFrameTime)
    report = report .. string.format("  Max: %.4f ms (%.1f FPS)\n", maxFrameTime * 1000, 1 / maxFrameTime)
    report = report .. "\n"
    
    -- Update time
    if #self.metrics.updateTime > 0 then
        local avgUpdateTime = self:calculateAverage(self.metrics.updateTime)
        local minUpdateTime = self:calculateMin(self.metrics.updateTime)
        local maxUpdateTime = self:calculateMax(self.metrics.updateTime)
        
        report = report .. "Update Time:\n"
        report = report .. string.format("  Average: %.4f ms (%.1f%% of frame)\n", avgUpdateTime * 1000, (avgUpdateTime / avgFrameTime) * 100)
        report = report .. string.format("  Min: %.4f ms\n", minUpdateTime * 1000)
        report = report .. string.format("  Max: %.4f ms\n", maxUpdateTime * 1000)
        report = report .. "\n"
    end
    
    -- Draw time
    if #self.metrics.drawTime > 0 then
        local avgDrawTime = self:calculateAverage(self.metrics.drawTime)
        local minDrawTime = self:calculateMin(self.metrics.drawTime)
        local maxDrawTime = self:calculateMax(self.metrics.drawTime)
        
        report = report .. "Draw Time:\n"
        report = report .. string.format("  Average: %.4f ms (%.1f%% of frame)\n", avgDrawTime * 1000, (avgDrawTime / avgFrameTime) * 100)
        report = report .. string.format("  Min: %.4f ms\n", minDrawTime * 1000)
        report = report .. string.format("  Max: %.4f ms\n", maxDrawTime * 1000)
        report = report .. "\n"
    end
    
    -- System times
    if next(self.metrics.systemTimes) ~= nil then
        report = report .. "System Times:\n"
        
        -- Sort systems by average time (descending)
        local systems = {}
        for systemName, times in pairs(self.metrics.systemTimes) do
            table.insert(systems, {
                name = systemName,
                avgTime = self:calculateAverage(times)
            })
        end
        
        table.sort(systems, function(a, b) return a.avgTime > b.avgTime end)
        
        -- Report each system
        for _, system in ipairs(systems) do
            local times = self.metrics.systemTimes[system.name]
            local avgTime = system.avgTime
            local minTime = self:calculateMin(times)
            local maxTime = self:calculateMax(times)
            
            report = report .. string.format("  %s:\n", system.name)
            report = report .. string.format("    Average: %.4f ms (%.1f%% of frame)\n", avgTime * 1000, (avgTime / avgFrameTime) * 100)
            report = report .. string.format("    Min: %.4f ms\n", minTime * 1000)
            report = report .. string.format("    Max: %.4f ms\n", maxTime * 1000)
        end
        
        report = report .. "\n"
    end
    
    -- Optimization recommendations
    report = report .. "Optimization Recommendations:\n"
    
    -- Check for frame rate issues
    if avgFrameTime > 1/60 then
        report = report .. "  - Frame rate below 60 FPS, optimization needed\n"
        
        -- Check system times
        if next(self.metrics.systemTimes) ~= nil then
            local heaviestSystem = systems[1]
            if heaviestSystem.avgTime > avgFrameTime * 0.3 then
                report = report .. string.format("  - %s is consuming %.1f%% of frame time, consider optimizing\n", 
                    heaviestSystem.name, (heaviestSystem.avgTime / avgFrameTime) * 100)
            end
        end
        
        -- Check update vs draw balance
        if #self.metrics.updateTime > 0 and #self.metrics.drawTime > 0 then
            local avgUpdateTime = self:calculateAverage(self.metrics.updateTime)
            local avgDrawTime = self:calculateAverage(self.metrics.drawTime)
            
            if avgUpdateTime > avgDrawTime * 2 then
                report = report .. "  - Update time significantly higher than draw time, focus on logic optimization\n"
            elseif avgDrawTime > avgUpdateTime * 2 then
                report = report .. "  - Draw time significantly higher than update time, focus on rendering optimization\n"
            end
        end
    else
        report = report .. "  - Frame rate above 60 FPS, performance is good\n"
    end
    
    -- Check for frame time spikes
    if maxFrameTime > avgFrameTime * 2 then
        report = report .. "  - Significant frame time spikes detected, consider optimizing garbage collection\n"
    end
    
    return report
end

-- Calculate average of a table of values
function PerformanceOptimizer:calculateAverage(values)
    if #values == 0 then return 0 end
    
    local sum = 0
    for _, value in ipairs(values) do
        sum = sum + value
    end
    
    return sum / #values
end

-- Calculate minimum of a table of values
function PerformanceOptimizer:calculateMin(values)
    if #values == 0 then return 0 end
    
    local min = values[1]
    for _, value in ipairs(values) do
        if value < min then
            min = value
        end
    end
    
    return min
end

-- Calculate maximum of a table of values
function PerformanceOptimizer:calculateMax(values)
    if #values == 0 then return 0 end
    
    local max = values[1]
    for _, value in ipairs(values) do
        if value > max then
            max = value
        end
    end
    
    return max
end

-- Initialize object pool
function PerformanceOptimizer:initializeObjectPool(objectType, factory, initialSize)
    if not self.settings.enableObjectPooling then return end
    
    self.objectPools[objectType] = {
        available = {},
        inUse = {},
        factory = factory
    }
    
    -- Pre-create objects
    for i = 1, initialSize do
        local object = factory()
        table.insert(self.objectPools[objectType].available, object)
    end
    
    print(string.format("Object pool initialized for %s with %d objects", objectType, initialSize))
end

-- Get object from pool
function PerformanceOptimizer:getObject(objectType)
    if not self.settings.enableObjectPooling then
        return self.objectPools[objectType].factory()
    end
    
    local pool = self.objectPools[objectType]
    if not pool then
        error("Object pool not initialized for type: " .. objectType)
    end
    
    local object
    
    -- Get from available pool or create new
    if #pool.available > 0 then
        object = table.remove(pool.available)
    else
        object = pool.factory()
    end
    
    -- Add to in-use pool
    table.insert(pool.inUse, object)
    
    return object
end

-- Return object to pool
function PerformanceOptimizer:returnObject(objectType, object)
    if not self.settings.enableObjectPooling then return end
    
    local pool = self.objectPools[objectType]
    if not pool then
        error("Object pool not initialized for type: " .. objectType)
    end
    
    -- Remove from in-use pool
    for i, obj in ipairs(pool.inUse) do
        if obj == object then
            table.remove(pool.inUse, i)
            break
        end
    end
    
    -- Reset object if it has a reset method
    if object.reset then
        object:reset()
    end
    
    -- Add to available pool
    table.insert(pool.available, object)
end

-- Initialize spatial hash grid
function PerformanceOptimizer:initializeSpatialHash(cellSize)
    if not self.settings.enableSpatialHashing then return end
    
    self.spatialHash.cellSize = cellSize or 64
    self.spatialHash.grid = {}
    self.spatialHash.entities = {}
    
    print(string.format("Spatial hash initialized with cell size %d", self.spatialHash.cellSize))
end

-- Get cell key for position
function PerformanceOptimizer:getCellKey(x, y)
    local cellX = math.floor(x / self.spatialHash.cellSize)
    local cellY = math.floor(y / self.spatialHash.cellSize)
    return cellX .. "," .. cellY
end

-- Add entity to spatial hash
function PerformanceOptimizer:addEntityToSpatialHash(entity)
    if not self.settings.enableSpatialHashing then return end
    
    local x, y = entity.x, entity.y
    local key = self:getCellKey(x, y)
    
    -- Create cell if it doesn't exist
    if not self.spatialHash.grid[key] then
        self.spatialHash.grid[key] = {}
    end
    
    -- Add entity to cell
    table.insert(self.spatialHash.grid[key], entity)
    
    -- Store entity's cell
    self.spatialHash.entities[entity] = key
end

-- Remove entity from spatial hash
function PerformanceOptimizer:removeEntityFromSpatialHash(entity)
    if not self.settings.enableSpatialHashing then return end
    
    local key = self.spatialHash.entities[entity]
    if not key then return end
    
    -- Remove entity from cell
    local cell = self.spatialHash.grid[key]
    if cell then
        for i, e in ipairs(cell) do
            if e == entity then
                table.remove(cell, i)
                break
            end
        end
    end
    
    -- Remove entity's cell reference
    self.spatialHash.entities[entity] = nil
end

-- Update entity position in spatial hash
function PerformanceOptimizer:updateEntityInSpatialHash(entity)
    if not self.settings.enableSpatialHashing then return end
    
    local oldKey = self.spatialHash.entities[entity]
    local newKey = self:getCellKey(entity.x, entity.y)
    
    -- If cell hasn't changed, do nothing
    if oldKey == newKey then return end
    
    -- Remove from old cell
    self:removeEntityFromSpatialHash(entity)
    
    -- Add to new cell
    self:addEntityToSpatialHash(entity)
end

-- Get entities in range
function PerformanceOptimizer:getEntitiesInRange(x, y, range)
    if not self.settings.enableSpatialHashing then
        -- Fallback to checking all entities
        local entities = {}
        for entity, _ in pairs(self.spatialHash.entities) do
            local dx = entity.x - x
            local dy = entity.y - y
            local distSquared = dx * dx + dy * dy
            
            if distSquared <= range * range then
                table.insert(entities, entity)
            end
        end
        
        return entities
    end
    
    local entities = {}
    local cellRange = math.ceil(range / self.spatialHash.cellSize)
    
    -- Get center cell
    local centerCellX = math.floor(x / self.spatialHash.cellSize)
    local centerCellY = math.floor(y / self.spatialHash.cellSize)
    
    -- Check cells in range
    for cellX = centerCellX - cellRange, centerCellX + cellRange do
        for cellY = centerCellY - cellRange, centerCellY + cellRange do
            local key = cellX .. "," .. cellY
            local cell = self.spatialHash.grid[key]
            
            if cell then
                for _, entity in ipairs(cell) do
                    local dx = entity.x - x
                    local dy = entity.y - y
                    local distSquared = dx * dx + dy * dy
                    
                    if distSquared <= range * range then
                        table.insert(entities, entity)
                    end
                end
            end
        end
    end
    
    return entities
end

-- Cache result of expensive calculation
function PerformanceOptimizer:cacheResult(cacheType, key, result)
    if not self.settings.enableCaching then return result end
    
    if not self.cache[cacheType] then
        self.cache[cacheType] = {}
    end
    
    self.cache[cacheType][key] = {
        result = result,
        timestamp = love.timer.getTime()
    }
    
    return result
end

-- Get cached result
function PerformanceOptimizer:getCachedResult(cacheType, key, maxAge)
    if not self.settings.enableCaching then return nil end
    
    if not self.cache[cacheType] then return nil end
    
    local cached = self.cache[cacheType][key]
    if not cached then return nil end
    
    -- Check if cache is too old
    if maxAge and love.timer.getTime() - cached.timestamp > maxAge then
        self.cache[cacheType][key] = nil
        return nil
    end
    
    return cached.result
end

-- Clear cache
function PerformanceOptimizer:clearCache(cacheType)
    if cacheType then
        self.cache[cacheType] = {}
    else
        self.cache = {
            pathfinding = {},
            visibility = {},
            calculations = {}
        }
    end
end

-- Draw debug information
function PerformanceOptimizer:drawDebugInfo()
    if not self.showDebugInfo then return end
    
    local x, y = 10, 10
    local lineHeight = 20
    
    -- Set color and font
    love.graphics.setColor(1, 1, 0, 0.8)
    love.graphics.setFont(love.graphics.newFont(12))
    
    -- Draw FPS
    local fps = love.timer.getFPS()
    love.graphics.print("FPS: " .. fps, x, y)
    y = y + lineHeight
    
    -- Draw memory usage
    local memoryUsage = collectgarbage("count")
    love.graphics.print(string.format("Memory: %.2f MB", memoryUsage / 1024), x, y)
    y = y + lineHeight
    
    -- Draw object pool stats
    if self.settings.enableObjectPooling then
        love.graphics.print("Object Pools:", x, y)
        y = y + lineHeight
        
        for objectType, pool in pairs(self.objectPools) do
            love.graphics.print(string.format("  %s: %d available, %d in use", 
                objectType, #pool.available, #pool.inUse), x, y)
            y = y + lineHeight
        end
    end
    
    -- Draw spatial hash stats
    if self.settings.enableSpatialHashing then
        local cellCount = 0
        local entityCount = 0
        
        for _ in pairs(self.spatialHash.grid) do
            cellCount = cellCount + 1
        end
        
        for _ in pairs(self.spatialHash.entities) do
            entityCount = entityCount + 1
        end
        
        love.graphics.print(string.format("Spatial Hash: %d cells, %d entities", 
            cellCount, entityCount), x, y)
        y = y + lineHeight
    end
    
    -- Draw cache stats
    if self.settings.enableCaching then
        local cacheStats = {}
        
        for cacheType, cache in pairs(self.cache) do
            local count = 0
            for _ in pairs(cache) do
                count = count + 1
            end
            
            table.insert(cacheStats, string.format("%s: %d", cacheType, count))
        end
        
        love.graphics.print("Cache: " .. table.concat(cacheStats, ", "), x, y)
    end
end

-- Apply optimizations to game systems
function PerformanceOptimizer:applyOptimizations()
    -- Apply object pooling to particle systems
    if self.settings.enableObjectPooling and self.game.particleManager then
        self:initializeObjectPool("particle", function() 
            return love.graphics.newParticleSystem(self.game.assets.images.particle, 100)
        end, 10)
        
        -- Override particle creation
        local originalCreateParticle = self.game.particleManager.createParticle
        self.game.particleManager.createParticle = function(self, ...)
            local particle = self.game.performanceOptimizer:getObject("particle")
            -- Initialize particle with original function's logic
            originalCreateParticle(self, particle, ...)
            return particle
        end
        
        -- Override particle removal
        local originalRemoveParticle = self.game.particleManager.removeParticle
        self.game.particleManager.removeParticle = function(self, particle, ...)
            originalRemoveParticle(self, particle, ...)
            self.game.performanceOptimizer:returnObject("particle", particle)
        end
    end
    
    -- Apply spatial hashing to game grid
    if self.settings.enableSpatialHashing and self.game.grid then
        self:initializeSpatialHash(self.game.grid.tileSize)
        
        -- Override entity addition
        local originalAddEntity = self.game.grid.addEntity
        self.game.grid.addEntity = function(self, entity, ...)
            originalAddEntity(self, entity, ...)
            self.game.performanceOptimizer:addEntityToSpatialHash(entity)
        end
        
        -- Override entity removal
        local originalRemoveEntity = self.game.grid.removeEntity
        self.game.grid.removeEntity = function(self, entity, ...)
            originalRemoveEntity(self, entity, ...)
            self.game.performanceOptimizer:removeEntityFromSpatialHash(entity)
        end
        
        -- Override entity movement
        local originalMoveEntity = self.game.grid.moveEntity
        self.game.grid.moveEntity = function(self, entity, newX, newY, ...)
            originalMoveEntity(self, entity, newX, newY, ...)
            self.game.performanceOptimizer:updateEntityInSpatialHash(entity)
        end
        
        -- Override getEntitiesInRange
        self.game.grid.getEntitiesInRange = function(self, x, y, range, ...)
            return self.game.performanceOptimizer:getEntitiesInRange(x, y, range)
        end
    end
    
    -- Apply caching to pathfinding
    if self.settings.enableCaching and self.game.pathfinder then
        -- Override findPath
        local originalFindPath = self.game.pathfinder.findPath
        self.game.pathfinder.findPath = function(self, startX, startY, endX, endY, ...)
            local key = startX .. "," .. startY .. "," .. endX .. "," .. endY
            local cachedPath = self.game.performanceOptimizer:getCachedResult("pathfinding", key, 1.0)
            
            if cachedPath then
                return cachedPath
            end
            
            local path = originalFindPath(self, startX, startY, endX, endY, ...)
            return self.game.performanceOptimizer:cacheResult("pathfinding", key, path)
        end
    end
    
    -- Apply culling to rendering
    if self.settings.enableCulling then
        -- Override draw methods to check visibility
        for _, systemName in ipairs({"grid", "units", "effects", "ui"}) do
            local system = self.game[systemName]
            if system and system.draw then
                local originalDraw = system.draw
                system.draw = function(self, ...)
                    -- Skip drawing if system is far off-screen
                    if self.x and self.y and self.width and self.height then
                        local screenWidth, screenHeight = love.graphics.getDimensions()
                        if self.x > screenWidth or self.y > screenHeight or
                           self.x + self.width < 0 or self.y + self.height < 0 then
                            return
                        end
                    end
                    
                    originalDraw(self, ...)
                end
            end
        end
    end
    
    print("Performance optimizations applied")
end

-- Optimize game code
function PerformanceOptimizer:optimizeGame()
    -- Start monitoring to identify bottlenecks
    self:startMonitoring()
    
    -- Apply optimizations
    self:applyOptimizations()
    
    -- Set up performance hooks
    self:setupPerformanceHooks()
    
    return "Optimization process started. Run the game to collect performance data."
end

-- Set up performance hooks
function PerformanceOptimizer:setupPerformanceHooks()
    -- Hook into love.update
    local originalUpdate = love.update
    love.update = function(dt)
        local startTime = love.timer.getTime()
        originalUpdate(dt)
        local endTime = love.timer.getTime()
        
        self:recordUpdateTime(endTime - startTime)
        self:update(dt)
    end
    
    -- Hook into love.draw
    local originalDraw = love.draw
    love.draw = function()
        local startTime = love.timer.getTime()
        originalDraw()
        local endTime = love.timer.getTime()
        
        self:recordDrawTime(endTime - startTime)
        self:drawDebugInfo()
    end
    
    -- Hook into game systems
    for systemName, system in pairs(self.game) do
        if type(system) == "table" and system.update then
            local originalSystemUpdate = system.update
            system.update = function(self, dt, ...)
                local startTime = love.timer.getTime()
                originalSystemUpdate(self, dt, ...)
                local endTime = love.timer.getTime()
                
                self.game.performanceOptimizer:recordSystemTime(systemName, endTime - startTime)
            end
        end
    end
    
    print("Performance hooks set up")
end

-- Toggle debug information display
function PerformanceOptimizer:toggleDebugInfo()
    self.showDebugInfo = not self.showDebugInfo
    return self.showDebugInfo
end

-- Enable or disable optimization
function PerformanceOptimizer:setOptimization(name, enabled)
    if self.settings[name] ~= nil then
        self.settings[name] = enabled
        print(string.format("Optimization '%s' %s", name, enabled and "enabled" or "disabled"))
        return true
    end
    
    return false
end

return PerformanceOptimizer
