-- Dungeon Map UI for Nightfall Chess
-- Handles display and interaction with procedurally generated dungeons

local class = require("lib.middleclass.middleclass")

local DungeonMapUI = class("DungeonMapUI")

function DungeonMapUI:initialize(game, proceduralGeneration)
    self.game = game
    self.proceduralGeneration = proceduralGeneration
    
    -- UI state
    self.visible = false
    self.alpha = 0
    self.targetAlpha = 0
    
    -- Layout
    self.width = 600
    self.height = 400
    self.x = 0
    self.y = 0
    
    -- Map view
    self.scale = 1.0
    self.offsetX = 0
    self.offsetY = 0
    self.dragging = false
    self.dragStartX = 0
    self.dragStartY = 0
    
    -- Room selection
    self.selectedRoom = nil
    self.hoveredRoom = nil
    
    -- Room info panel
    self.showRoomInfo = false
    self.roomInfoX = 0
    self.roomInfoY = 0
    
    -- Animation
    self.animationTimer = 0
    self.pulseDirection = 1
    
    -- Floor selection
    self.currentFloor = 1
    
    -- Room node visuals
    self.roomNodeSize = 40
    self.connectionWidth = 5
    
    -- Room colors by type
    self.roomColors = {
        combat = {0.8, 0.2, 0.2},
        treasure = {0.8, 0.8, 0.2},
        shop = {0.2, 0.6, 0.8},
        puzzle = {0.8, 0.4, 0.8},
        rest = {0.2, 0.8, 0.4},
        elite = {0.8, 0.4, 0.1},
        boss = {0.9, 0.1, 0.1},
        start = {0.4, 0.8, 0.8},
        cleared = {0.5, 0.5, 0.5}
    }
    
    -- Room icons (would be loaded from assets in a full implementation)
    self.roomIcons = {
        combat = nil,
        treasure = nil,
        shop = nil,
        puzzle = nil,
        rest = nil,
        elite = nil,
        boss = nil,
        start = nil
    }
end

-- Set UI position
function DungeonMapUI:setPosition(x, y)
    self.x = x
    self.y = y
end

-- Show dungeon map UI
function DungeonMapUI:show()
    self.visible = true
    self.targetAlpha = 1
    
    -- Reset view if needed
    if self.proceduralGeneration and self.proceduralGeneration.currentDungeon then
        self:resetView()
    end
end

-- Hide dungeon map UI
function DungeonMapUI:hide()
    self.targetAlpha = 0
    self.showRoomInfo = false
end

-- Reset view to center the current floor
function DungeonMapUI:resetView()
    self.scale = 1.0
    self.offsetX = 0
    self.offsetY = 0
    
    -- Center on current floor
    if self.proceduralGeneration and self.proceduralGeneration.currentDungeon then
        local currentFloorRooms = {}
        
        for _, room in ipairs(self.proceduralGeneration.currentDungeon.rooms) do
            if room.floor == self.currentFloor then
                table.insert(currentFloorRooms, room)
            end
        end
        
        if #currentFloorRooms > 0 then
            -- Find center of rooms
            local centerX, centerY = 0, 0
            for _, room in ipairs(currentFloorRooms) do
                centerX = centerX + room.mapX
                centerY = centerY + room.mapY
            end
            centerX = centerX / #currentFloorRooms
            centerY = centerY / #currentFloorRooms
            
            -- Center view on rooms
            self.offsetX = self.width / 2 - centerX * self.roomNodeSize * 3
            self.offsetY = self.height / 2 - centerY * self.roomNodeSize * 2
        end
    end
end

-- Update dungeon map UI
function DungeonMapUI:update(dt)
    -- Animate alpha
    if self.alpha < self.targetAlpha then
        self.alpha = math.min(self.alpha + dt * 5, self.targetAlpha)
    elseif self.alpha > self.targetAlpha then
        self.alpha = math.max(self.alpha - dt * 5, self.targetAlpha)
        if self.alpha <= 0 then
            self.visible = false
        end
    end
    
    -- Update animation
    self.animationTimer = self.animationTimer + dt
    if self.animationTimer > 1 then
        self.animationTimer = self.animationTimer - 1
    end
    
    -- Pulse animation for current room
    if self.pulseDirection > 0 then
        self.pulse = math.min(1.2, self.pulse + dt)
        if self.pulse >= 1.2 then
            self.pulseDirection = -1
        end
    else
        self.pulse = math.max(0.8, self.pulse - dt)
        if self.pulse <= 0.8 then
            self.pulseDirection = 1
        end
    end
end

-- Draw dungeon map UI
function DungeonMapUI:draw()
    if not self.visible then return end
    
    local width, height = love.graphics.getDimensions()
    
    -- Center the UI if position not set
    if self.x == 0 and self.y == 0 then
        self.x = (width - self.width) / 2
        self.y = (height - self.height) / 2
    end
    
    -- Draw background
    love.graphics.setColor(0.1, 0.1, 0.2, 0.95 * self.alpha)
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height, 10, 10)
    
    love.graphics.setColor(0.3, 0.3, 0.5, 0.8 * self.alpha)
    love.graphics.rectangle("line", self.x, self.y, self.width, self.height, 10, 10)
    
    -- Draw title
    love.graphics.setColor(1, 1, 1, self.alpha)
    love.graphics.setFont(self.game.assets.fonts.medium)
    love.graphics.print("Dungeon Map - Floor " .. self.currentFloor, self.x + 20, self.y + 20)
    
    -- Set up scissor to clip map to the content area
    love.graphics.setScissor(self.x + 10, self.y + 60, self.width - 20, self.height - 70)
    
    -- Draw dungeon map
    self:drawDungeonMap()
    
    -- Reset scissor
    love.graphics.setScissor()
    
    -- Draw floor selection
    self:drawFloorSelection()
    
    -- Draw room info panel
    if self.showRoomInfo and self.selectedRoom then
        self:drawRoomInfo()
    end
    
    -- Draw close button
    love.graphics.setColor(0.8, 0.2, 0.2, 0.8 * self.alpha)
    love.graphics.rectangle("fill", self.x + self.width - 30, self.y + 10, 20, 20, 3, 3)
    
    love.graphics.setColor(1, 1, 1, self.alpha)
    love.graphics.printf("X", self.x + self.width - 30, self.y + 12, 20, "center")
    
    -- Draw controls help
    love.graphics.setColor(0.7, 0.7, 0.7, 0.7 * self.alpha)
    love.graphics.setFont(self.game.assets.fonts.small)
    love.graphics.print("Drag to pan | Mouse wheel to zoom | Click room for details", self.x + 20, self.y + self.height - 25)
end

-- Draw dungeon map
function DungeonMapUI:drawDungeonMap()
    if not self.proceduralGeneration or not self.proceduralGeneration.currentDungeon then
        -- Draw "No dungeon generated" message
        love.graphics.setColor(0.7, 0.7, 0.7, self.alpha)
        love.graphics.setFont(self.game.assets.fonts.medium)
        love.graphics.printf("No dungeon generated", self.x, self.y + self.height / 2 - 20, self.width, "center")
        return
    end
    
    local dungeon = self.proceduralGeneration.currentDungeon
    
    -- Draw connections first (so they appear behind rooms)
    for _, connection in ipairs(dungeon.connections) do
        local roomA = self.proceduralGeneration:getRoomById(connection.roomA)
        local roomB = self.proceduralGeneration:getRoomById(connection.roomB)
        
        if roomA and roomB and roomA.floor == self.currentFloor and roomB.floor == self.currentFloor then
            -- Calculate screen positions
            local x1 = self.x + self.offsetX + roomA.mapX * self.roomNodeSize * 3
            local y1 = self.y + self.offsetY + roomA.mapY * self.roomNodeSize * 2
            local x2 = self.x + self.offsetX + roomB.mapX * self.roomNodeSize * 3
            local y2 = self.y + self.offsetY + roomB.mapY * self.roomNodeSize * 2
            
            -- Determine connection color based on room cleared status
            local connectionColor = {0.3, 0.3, 0.5}
            
            if roomA.cleared and roomB.cleared then
                connectionColor = {0.5, 0.5, 0.5}
            elseif (roomA.cleared and self.proceduralGeneration:isRoomAccessible(roomB.id)) or
                   (roomB.cleared and self.proceduralGeneration:isRoomAccessible(roomA.id)) then
                connectionColor = {0.5, 0.7, 0.5}
            end
            
            -- Draw connection
            love.graphics.setColor(connectionColor[1], connectionColor[2], connectionColor[3], 0.8 * self.alpha)
            love.graphics.setLineWidth(self.connectionWidth * self.scale)
            love.graphics.line(x1, y1, x2, y2)
        end
    end
    
    -- Draw rooms
    for _, room in ipairs(dungeon.rooms) do
        if room.floor == self.currentFloor then
            -- Calculate screen position
            local x = self.x + self.offsetX + room.mapX * self.roomNodeSize * 3
            local y = self.y + self.offsetY + room.mapY * self.roomNodeSize * 2
            
            -- Determine room color based on type and status
            local roomColor = self.roomColors[room.type] or {0.5, 0.5, 0.5}
            
            if room.cleared then
                roomColor = self.roomColors.cleared
            end
            
            -- Determine if room is accessible
            local isAccessible = self.proceduralGeneration:isRoomAccessible(room.id)
            
            -- Determine node size based on selection and hover
            local nodeSize = self.roomNodeSize * self.scale
            
            if self.selectedRoom and self.selectedRoom.id == room.id then
                nodeSize = nodeSize * 1.2
            elseif self.hoveredRoom and self.hoveredRoom.id == room.id then
                nodeSize = nodeSize * 1.1
            end
            
            -- Apply pulse animation to current room
            if room.id == self.proceduralGeneration.currentRoomId then
                nodeSize = nodeSize * (0.9 + 0.2 * math.sin(self.animationTimer * 5))
            end
            
            -- Draw room node
            if isAccessible and not room.cleared then
                -- Draw glow for accessible rooms
                love.graphics.setColor(roomColor[1], roomColor[2], roomColor[3], 0.3 * self.alpha)
                love.graphics.circle("fill", x, y, nodeSize * 1.5)
            end
            
            -- Draw room background
            love.graphics.setColor(roomColor[1], roomColor[2], roomColor[3], 0.8 * self.alpha)
            love.graphics.circle("fill", x, y, nodeSize)
            
            -- Draw room border
            if room.id == self.proceduralGeneration.currentRoomId then
                -- Current room has thicker border
                love.graphics.setColor(1, 1, 1, self.alpha)
                love.graphics.setLineWidth(3 * self.scale)
            else
                love.graphics.setColor(0.8, 0.8, 0.8, 0.8 * self.alpha)
                love.graphics.setLineWidth(1 * self.scale)
            end
            love.graphics.circle("line", x, y, nodeSize)
            
            -- Draw room icon or letter
            love.graphics.setColor(1, 1, 1, self.alpha)
            if self.roomIcons[room.type] then
                -- Draw icon
                love.graphics.draw(self.roomIcons[room.type], x - nodeSize/2, y - nodeSize/2, 0, nodeSize/32, nodeSize/32)
            else
                -- Draw letter
                love.graphics.setFont(self.game.assets.fonts.medium)
                local letter = room.type:sub(1, 1):upper()
                love.graphics.printf(letter, x - nodeSize, y - nodeSize/4, nodeSize * 2, "center")
            end
            
            -- Draw room number
            love.graphics.setColor(1, 1, 1, 0.7 * self.alpha)
            love.graphics.setFont(self.game.assets.fonts.small)
            love.graphics.printf(room.id, x - nodeSize, y + nodeSize/2, nodeSize * 2, "center")
        end
    end
end

-- Draw floor selection
function DungeonMapUI:drawFloorSelection()
    if not self.proceduralGeneration or not self.proceduralGeneration.currentDungeon then
        return
    end
    
    local dungeon = self.proceduralGeneration.currentDungeon
    local maxFloor = dungeon.floors or 1
    
    -- Draw floor selection buttons
    local buttonWidth = 30
    local buttonHeight = 30
    local buttonSpacing = 5
    local totalWidth = (buttonWidth + buttonSpacing) * maxFloor - buttonSpacing
    local startX = self.x + (self.width - totalWidth) / 2
    
    for floor = 1, maxFloor do
        local buttonX = startX + (floor - 1) * (buttonWidth + buttonSpacing)
        local buttonY = self.y + self.height - 40
        
        -- Draw button background
        if floor == self.currentFloor then
            love.graphics.setColor(0.3, 0.5, 0.8, 0.8 * self.alpha)
        else
            love.graphics.setColor(0.3, 0.3, 0.5, 0.8 * self.alpha)
        end
        
        love.graphics.rectangle("fill", buttonX, buttonY, buttonWidth, buttonHeight, 5, 5)
        
        -- Draw button text
        love.graphics.setColor(1, 1, 1, self.alpha)
        love.graphics.setFont(self.game.assets.fonts.small)
        love.graphics.printf(tostring(floor), buttonX, buttonY + 8, buttonWidth, "center")
    end
end

-- Draw room info panel
function DungeonMapUI:drawRoomInfo()
    if not self.selectedRoom then return end
    
    local panelWidth = 250
    local panelHeight = 200
    local panelX = self.roomInfoX
    local panelY = self.roomInfoY
    
    -- Ensure panel stays within UI bounds
    if panelX + panelWidth > self.x + self.width - 10 then
        panelX = self.x + self.width - 10 - panelWidth
    end
    if panelY + panelHeight > self.y + self.height - 10 then
        panelY = self.y + self.height - 10 - panelHeight
    end
    
    -- Draw panel background
    love.graphics.setColor(0.1, 0.1, 0.2, 0.95 * self.alpha)
    love.graphics.rectangle("fill", panelX, panelY, panelWidth, panelHeight, 5, 5)
    
    love.graphics.setColor(0.3, 0.3, 0.5, 0.8 * self.alpha)
    love.graphics.rectangle("line", panelX, panelY, panelWidth, panelHeight, 5, 5)
    
    -- Draw room type
    love.graphics.setColor(1, 1, 1, self.alpha)
    love.graphics.setFont(self.game.assets.fonts.medium)
    local roomTypeName = self.selectedRoom.type:sub(1,1):upper() .. self.selectedRoom.type:sub(2) .. " Room"
    love.graphics.print(roomTypeName, panelX + 10, panelY + 10)
    
    -- Draw room ID
    love.graphics.setColor(0.7, 0.7, 0.7, 0.8 * self.alpha)
    love.graphics.setFont(self.game.assets.fonts.small)
    love.graphics.print("ID: " .. self.selectedRoom.id, panelX + 10, panelY + 35)
    
    -- Draw room status
    local statusText = self.selectedRoom.cleared and "Cleared" or "Not Cleared"
    local statusColor = self.selectedRoom.cleared and {0.2, 0.8, 0.2} or {0.8, 0.2, 0.2}
    
    love.graphics.setColor(statusColor[1], statusColor[2], statusColor[3], self.alpha)
    love.graphics.print("Status: " .. statusText, panelX + 10, panelY + 55)
    
    -- Draw room size
    love.graphics.setColor(0.7, 0.7, 0.7, 0.8 * self.alpha)
    love.graphics.print("Size: " .. self.selectedRoom.width .. "x" .. self.selectedRoom.height, panelX + 10, panelY + 75)
    
    -- Draw room features
    love.graphics.setColor(0.7, 0.7, 0.7, 0.8 * self.alpha)
    local featuresText = "Features: "
    
    if self.selectedRoom.features and #self.selectedRoom.features > 0 then
        local featureNames = {}
        for _, feature in ipairs(self.selectedRoom.features) do
            table.insert(featureNames, feature.type)
        end
        featuresText = featuresText .. table.concat(featureNames, ", ")
    else
        featuresText = featuresText .. "None"
    end
    
    love.graphics.printf(featuresText, panelX + 10, panelY + 95, panelWidth - 20, "left")
    
    -- Draw room connections
    love.graphics.setColor(0.7, 0.7, 0.7, 0.8 * self.alpha)
    local connections = self.proceduralGeneration:getConnectedRooms(self.selectedRoom.id)
    local connectionsText = "Connections: "
    
    if #connections > 0 then
        local connectionIds = {}
        for _, connectedRoom in ipairs(connections) do
            table.insert(connectionIds, connectedRoom.id)
        end
        connectionsText = connectionsText .. table.concat(connectionIds, ", ")
    else
        connectionsText = connectionsText .. "None"
    end
    
    love.graphics.printf(connectionsText, panelX + 10, panelY + 125, panelWidth - 20, "left")
    
    -- Draw travel button if room is accessible and not current room
    if self.proceduralGeneration:isRoomAccessible(self.selectedRoom.id) and 
       self.selectedRoom.id ~= self.proceduralGeneration.currentRoomId then
        love.graphics.setColor(0.3, 0.6, 0.3, 0.8 * self.alpha)
        love.graphics.rectangle("fill", panelX + 50, panelY + 155, 150, 30, 5, 5)
        
        love.graphics.setColor(1, 1, 1, self.alpha)
        love.graphics.printf("Travel to Room", panelX + 50, panelY + 160, 150, "center")
    end
end

-- Handle mouse movement
function DungeonMapUI:mousemoved(x, y, dx, dy)
    if not self.visible then return end
    
    -- Handle dragging
    if self.dragging then
        self.offsetX = self.offsetX + dx
        self.offsetY = self.offsetY + dy
        return true
    end
    
    -- Reset hovered room
    self.hoveredRoom = nil
    
    -- Check if mouse is over a room
    if self.proceduralGeneration and self.proceduralGeneration.currentDungeon then
        local dungeon = self.proceduralGeneration.currentDungeon
        
        for _, room in ipairs(dungeon.rooms) do
            if room.floor == self.currentFloor then
                -- Calculate screen position
                local roomX = self.x + self.offsetX + room.mapX * self.roomNodeSize * 3
                local roomY = self.y + self.offsetY + room.mapY * self.roomNodeSize * 2
                
                -- Check if mouse is over this room
                local distance = math.sqrt((x - roomX)^2 + (y - roomY)^2)
                if distance <= self.roomNodeSize * self.scale then
                    self.hoveredRoom = room
                    break
                end
            end
        end
    end
    
    return false
end

-- Handle mouse press
function DungeonMapUI:mousepressed(x, y, button)
    if not self.visible then return false end
    
    -- Check if close button was clicked
    if x >= self.x + self.width - 30 and x <= self.x + self.width - 10 and
       y >= self.y + 10 and y <= self.y + 30 then
        self:hide()
        return true
    end
    
    -- Check if room info panel is open and clicked
    if self.showRoomInfo and self.selectedRoom then
        local panelWidth = 250
        local panelHeight = 200
        local panelX = self.roomInfoX
        local panelY = self.roomInfoY
        
        -- Ensure panel stays within UI bounds
        if panelX + panelWidth > self.x + self.width - 10 then
            panelX = self.x + self.width - 10 - panelWidth
        end
        if panelY + panelHeight > self.y + self.height - 10 then
            panelY = self.y + self.height - 10 - panelHeight
        end
        
        -- Check if clicked inside panel
        if x >= panelX and x <= panelX + panelWidth and
           y >= panelY and y <= panelY + panelHeight then
            
            -- Check if travel button was clicked
            if self.proceduralGeneration:isRoomAccessible(self.selectedRoom.id) and 
               self.selectedRoom.id ~= self.proceduralGeneration.currentRoomId and
               x >= panelX + 50 and x <= panelX + 200 and
               y >= panelY + 155 and y <= panelY + 185 then
                
                -- Travel to room
                self:travelToRoom(self.selectedRoom.id)
            end
            
            return true
        else
            -- Close panel if clicked outside
            self.showRoomInfo = false
            return true
        end
    end
    
    -- Check if floor selection was clicked
    if self.proceduralGeneration and self.proceduralGeneration.currentDungeon then
        local dungeon = self.proceduralGeneration.currentDungeon
        local maxFloor = dungeon.floors or 1
        
        local buttonWidth = 30
        local buttonHeight = 30
        local buttonSpacing = 5
        local totalWidth = (buttonWidth + buttonSpacing) * maxFloor - buttonSpacing
        local startX = self.x + (self.width - totalWidth) / 2
        
        for floor = 1, maxFloor do
            local buttonX = startX + (floor - 1) * (buttonWidth + buttonSpacing)
            local buttonY = self.y + self.height - 40
            
            if x >= buttonX and x <= buttonX + buttonWidth and
               y >= buttonY and y <= buttonY + buttonHeight then
                self.currentFloor = floor
                self:resetView()
                return true
            end
        end
    end
    
    -- Check if a room was clicked
    if self.hoveredRoom then
        self.selectedRoom = self.hoveredRoom
        self.showRoomInfo = true
        self.roomInfoX = x
        self.roomInfoY = y
        return true
    end
    
    -- Start dragging
    if button == 1 and x >= self.x + 10 and x <= self.x + self.width - 10 and
       y >= self.y + 60 and y <= self.y + self.height - 70 then
        self.dragging = true
        self.dragStartX = x
        self.dragStartY = y
        return true
    end
    
    return false
end

-- Handle mouse release
function DungeonMapUI:mousereleased(x, y, button)
    if not self.visible then return false end
    
    -- Stop dragging
    if button == 1 and self.dragging then
        self.dragging = false
        return true
    end
    
    return false
end

-- Handle mouse wheel
function DungeonMapUI:wheelmoved(x, y)
    if not self.visible then return false end
    
    -- Zoom in/out
    local oldScale = self.scale
    
    if y > 0 then
        -- Zoom in
        self.scale = math.min(2.0, self.scale * 1.1)
    elseif y < 0 then
        -- Zoom out
        self.scale = math.max(0.5, self.scale / 1.1)
    end
    
    -- Adjust offset to zoom toward mouse position
    if oldScale ~= self.scale then
        return true
    end
    
    return false
end

-- Travel to a room
function DungeonMapUI:travelToRoom(roomId)
    if not self.proceduralGeneration then return end
    
    -- Check if room is accessible
    if not self.proceduralGeneration:isRoomAccessible(roomId) then
        return
    end
    
    -- Travel to room
    self.proceduralGeneration:travelToRoom(roomId)
    
    -- Close map
    self:hide()
end

-- Add a new room to the map
function DungeonMapUI:addRoom(room)
    if not self.proceduralGeneration or not self.proceduralGeneration.currentDungeon then
        return
    end
    
    -- Add room to dungeon
    table.insert(self.proceduralGeneration.currentDungeon.rooms, room)
    
    -- Update current floor if needed
    if room.floor > self.currentFloor then
        self.currentFloor = room.floor
    end
end

-- Add a new connection between rooms
function DungeonMapUI:addConnection(roomA, roomB)
    if not self.proceduralGeneration or not self.proceduralGeneration.currentDungeon then
        return
    end
    
    -- Add connection to dungeon
    table.insert(self.proceduralGeneration.currentDungeon.connections, {
        roomA = roomA,
        roomB = roomB
    })
end

-- Mark a room as cleared
function DungeonMapUI:markRoomCleared(roomId)
    if not self.proceduralGeneration then return end
    
    self.proceduralGeneration:markRoomCleared(roomId)
end

-- Check if dungeon is completed
function DungeonMapUI:isDungeonCompleted()
    if not self.proceduralGeneration then return false end
    
    return self.proceduralGeneration:isDungeonCompleted()
end

return DungeonMapUI
