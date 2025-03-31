-- src/states/game.lua
-- Handles the main gameplay loop, DUNGEON EXPLORATION, and world interaction

local gamestate = require("lib.hump.gamestate")
local timer = require("lib.hump.timer")
local Camera = require("src.systems.camera")
local Grid = require("src.systems.grid") -- Still needed for map representation? Maybe not.
local Unit = require("src.entities.unit") -- Needed for player party data
-- Remove combat-specific requires if not needed for map state
-- local ChessMovement = require("src.systems.chess_movement")

local Game = {}

-- Game state variables (specific to map/exploration)
local MAP_NODE_SIZE = 64 -- Visual size of a room node on the map
local MAP_NODE_SPACING = 20

function Game:enter(previous, gameInstance, playerPartyData, combatResult)
    print("--- Game:enter START (Map State) ---")
    self.game = gameInstance
    if not self.game then
        error("FATAL: Game state entered without valid game object!")
    end

    -- Get necessary systems
    self.uiManager = self.game.uiManager
    self.proceduralGeneration = self.game.proceduralGeneration
    self.assetManager = self.game.assetManager -- Needed for drawing

    if not self.proceduralGeneration then print("WARNING: ProceduralGeneration system not found!") end
    if not self.uiManager then print("WARNING: UIManager not found!") end

    -- Initialize camera for the map view
    self.mapCamera = Camera:new()

    -- Player party data
    if playerPartyData then
        print("  Returning from combat. Updating player party.")
        self.playerParty = playerPartyData -- Update party with data from combat
    elseif not self.playerParty then
        print("  Initializing player party for the first time.")
        -- Initialize player party only on the very first entry
        self.playerParty = {}
        -- Create initial player units (e.g., from Team Management or defaults)
        -- This part needs data from Team Management state ideally
        local initialUnitsData = self.game.playerUnits or {} -- Get data prepared by Team Management
        if #initialUnitsData == 0 then
             print("  WARNING: No initial player units provided by main game object. Creating defaults.")
             -- Create some default units if none provided (for testing)
             table.insert(self.playerParty, Unit:new({unitType = "knight", faction = "player", x=1, y=1, game=self.game}))
             table.insert(self.playerParty, Unit:new({unitType = "rook", faction = "player", x=1, y=2, game=self.game}))
        else
             print("  Creating player party from provided data (" .. #initialUnitsData .. " units)")
             for _, unitInstance in ipairs(initialUnitsData) do
                 -- Ensure the instance is valid and has game reference
                 if unitInstance and unitInstance.isInstanceOf and unitInstance:isInstanceOf(Unit) then
                     unitInstance.game = self.game -- Ensure game reference is set
                     table.insert(self.playerParty, unitInstance)
                 else
                     print("    WARNING: Skipping invalid unit data during party creation.")
                 end
             end
        end
    else
        print("  Re-entering map state, using existing player party.")
    end
    print("  Player Party Count: " .. #self.playerParty)


    -- Dungeon generation (only if not already generated)
    if not self.dungeon then
        print("  Generating new dungeon...")
        self.dungeon = self.proceduralGeneration:generateDungeon("normal")
        self.currentFloorIndex = 1
        -- Find the starting room ID
        local startRoom = self:findRoomByType(self.currentFloorIndex, "entrance")
        self.currentNodeId = startRoom and startRoom.id or (self.dungeon.floors[1].rooms[1].id) -- Fallback to first room
        print("  Dungeon generated. Starting Node ID: " .. self.currentNodeId)
    else
        print("  Using existing dungeon.")
    end

    -- Handle combat results
    if combatResult then
        print("  Processing combat result: " .. combatResult)
        if combatResult == "victory" then
            local clearedRoom = self:findRoomById(self.lastCombatNodeId)
            if clearedRoom then
                clearedRoom.isCleared = true
                print("  Marked room " .. self.lastCombatNodeId .. " as cleared.")
                -- TODO: Grant rewards from clearedRoom.rewards
            end
        elseif combatResult == "defeat" then
            -- Game Over handled by combat state switching to gameover
            print("  Player was defeated in combat.")
        end
        self.lastCombatNodeId = nil -- Clear the last combat node ID
    end

    -- Map state variables
    self.selectedNodeId = nil -- Which node is currently selected by player input
    self.hoveredNodeId = nil -- Which node the mouse is over

    -- Center camera initially (optional)
    local startNode = self:findRoomById(self.currentNodeId)
    if startNode and startNode.mapPosition then
        self.mapCamera:setPosition(startNode.mapPosition.x - love.graphics.getWidth()/2, startNode.mapPosition.y - love.graphics.getHeight()/2, true)
    end

    print("--- Game:enter END (Map State) ---")
end

-- Helper function to find a room by type on a specific floor
function Game:findRoomByType(floorIndex, roomType)
    if not self.dungeon or not self.dungeon.floors[floorIndex] then return nil end
    for _, room in ipairs(self.dungeon.floors[floorIndex].rooms) do
        if room.type == roomType then
            return room
        end
    end
    return nil
end

-- Helper function to find a room by ID
function Game:findRoomById(roomId)
    if not self.dungeon then return nil end
    local floorIndex = math.floor(roomId / 100)
    if not self.dungeon.floors[floorIndex] then return nil end
    for _, room in ipairs(self.dungeon.floors[floorIndex].rooms) do
        if room.id == roomId then
            return room
        end
    end
    return nil
end

-- Helper function to get connected room IDs
function Game:getConnectedRoomIds(roomId)
    local connectedIds = {}
    if not self.dungeon then return connectedIds end
    local floorIndex = math.floor(roomId / 100)
    if not self.dungeon.floors[floorIndex] then return connectedIds end

    for _, connection in ipairs(self.dungeon.floors[floorIndex].connections or {}) do
        if connection.from == roomId then
            table.insert(connectedIds, connection.to)
        elseif connection.to == roomId then
            table.insert(connectedIds, connection.from)
        end
    end
    return connectedIds
end


function Game:leave()
    print("--- Game:leave (Map State) ---")
    -- No major cleanup needed for map state unless specific resources were loaded
end

function Game:update(dt)
    timer.update(dt)
    self.mapCamera:update(dt)

    -- Handle map navigation input (simplified example)
    -- In a real game, this would involve clicking nodes or using keys
end

function Game:draw()
    if not self.dungeon then print("Warning: No dungeon to draw"); return end
    if not self.mapCamera then print("Warning: mapCamera not initialized"); return end

    self.mapCamera:apply()

    -- Draw dungeon map for the current floor
    self:drawDungeonMap(self.currentFloorIndex)

    self.mapCamera:reset()

    -- Draw Map UI elements (floor number, etc.)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(self.game.assets.fonts.medium)
    love.graphics.print("Floor: " .. self.currentFloorIndex, 10, 10)
    love.graphics.print("Current Node: " .. self.currentNodeId, 10, 40)

    -- Draw Tooltip for hovered node
    if self.hoveredNodeId then
        local room = self:findRoomById(self.hoveredNodeId)
        if room then
            local mx, my = love.mouse.getPosition()
            self:drawMapTooltip(room, mx + 15, my + 15)
        end
    end
end

-- Draw the dungeon map visually
function Game:drawDungeonMap(floorIndex)
    local floor = self.dungeon.floors[floorIndex]
    if not floor then return end

    -- Calculate map bounds to center it (simple approach)
    local minX, maxX, minY, maxY = 1000, -1000, 1000, -1000
    for _, room in ipairs(floor.rooms) do
        -- Assign map positions if they don't exist (simple linear layout for now)
        if not room.mapPosition then
             local roomIndex = room.id % 100
             room.mapPosition = {
                 x = (roomIndex - 1) * (MAP_NODE_SIZE + MAP_NODE_SPACING),
                 y = 0 -- Simple horizontal layout
             }
        end
        minX = math.min(minX, room.mapPosition.x)
        maxX = math.max(maxX, room.mapPosition.x)
        minY = math.min(minY, room.mapPosition.y)
        maxY = math.max(maxY, room.mapPosition.y)
    end
    local mapWidth = maxX - minX + MAP_NODE_SIZE
    local mapHeight = maxY - minY + MAP_NODE_SIZE
    local mapOffsetX = (love.graphics.getWidth() - mapWidth) / 2 - minX
    local mapOffsetY = (love.graphics.getHeight() - mapHeight) / 2 - minY


    -- Draw connections
    love.graphics.setLineWidth(2)
    love.graphics.setColor(0.5, 0.5, 0.6)
    for _, connection in ipairs(floor.connections or {}) do
        local roomFrom = self:findRoomById(connection.from)
        local roomTo = self:findRoomById(connection.to)
        if roomFrom and roomTo and roomFrom.mapPosition and roomTo.mapPosition then
            local x1 = mapOffsetX + roomFrom.mapPosition.x + MAP_NODE_SIZE / 2
            local y1 = mapOffsetY + roomFrom.mapPosition.y + MAP_NODE_SIZE / 2
            local x2 = mapOffsetX + roomTo.mapPosition.x + MAP_NODE_SIZE / 2
            local y2 = mapOffsetY + roomTo.mapPosition.y + MAP_NODE_SIZE / 2
            love.graphics.line(x1, y1, x2, y2)
        end
    end
    love.graphics.setLineWidth(1)

    -- Draw rooms (nodes)
    for _, room in ipairs(floor.rooms) do
        if room.mapPosition then
            local nodeX = mapOffsetX + room.mapPosition.x
            local nodeY = mapOffsetY + room.mapPosition.y

            -- Node color based on type and status
            local nodeColor = {0.4, 0.4, 0.5} -- Default grey
            if room.type == "entrance" then nodeColor = {0.4, 0.8, 0.8}
            elseif room.type == "combat" then nodeColor = {0.8, 0.2, 0.2}
            elseif room.type == "treasure" then nodeColor = {0.8, 0.8, 0.2}
            elseif room.type == "boss" then nodeColor = {0.9, 0.1, 0.1}
            -- Add other types...
            end
            if room.isCleared then nodeColor = {0.2, 0.2, 0.2} end -- Dark grey for cleared

            love.graphics.setColor(nodeColor)
            love.graphics.rectangle("fill", nodeX, nodeY, MAP_NODE_SIZE, MAP_NODE_SIZE, 5, 5)

            -- Highlight current node
            if room.id == self.currentNodeId then
                love.graphics.setColor(1, 1, 0, 0.8) -- Yellow border
                love.graphics.setLineWidth(3)
                love.graphics.rectangle("line", nodeX, nodeY, MAP_NODE_SIZE, MAP_NODE_SIZE, 5, 5)
                love.graphics.setLineWidth(1)
            -- Highlight selected node
            elseif room.id == self.selectedNodeId then
                 love.graphics.setColor(1, 1, 1, 0.7) -- White border
                 love.graphics.setLineWidth(2)
                 love.graphics.rectangle("line", nodeX, nodeY, MAP_NODE_SIZE, MAP_NODE_SIZE, 5, 5)
                 love.graphics.setLineWidth(1)
            -- Standard border
            else
                love.graphics.setColor(0.7, 0.7, 0.8)
                love.graphics.rectangle("line", nodeX, nodeY, MAP_NODE_SIZE, MAP_NODE_SIZE, 5, 5)
            end

            -- Draw room type icon/letter
            love.graphics.setColor(1, 1, 1)
            love.graphics.setFont(self.game.assets.fonts.large)
            love.graphics.printf(room.type:sub(1, 1):upper(), nodeX, nodeY + MAP_NODE_SIZE / 2 - 18, MAP_NODE_SIZE, "center")
        end
    end
end

-- Draw map tooltip
function Game:drawMapTooltip(room, x, y)
    local textLines = {
        "Room ID: " .. room.id,
        "Type: " .. room.type:sub(1,1):upper()..room.type:sub(2),
        "Status: " .. (room.isCleared and "Cleared" or "Uncleared"),
        -- Add more info like potential rewards or enemies if desired
    }
    local maxWidth = 0
    local font = self.game.assets.fonts.small
    love.graphics.setFont(font)
    for _, line in ipairs(textLines) do
        maxWidth = math.max(maxWidth, font:getWidth(line))
    end

    local padding = 5
    local boxWidth = maxWidth + padding * 2
    local boxHeight = #textLines * font:getHeight() + padding * 2
    local boxX = x
    local boxY = y

    -- Adjust position to keep on screen
    local screenW, screenH = love.graphics.getDimensions()
    if boxX + boxWidth > screenW then boxX = screenW - boxWidth end
    if boxY + boxHeight > screenH then boxY = screenH - boxHeight end
    if boxX < 0 then boxX = 0 end
    if boxY < 0 then boxY = 0 end

    -- Draw background
    love.graphics.setColor(0.1, 0.1, 0.15, 0.9)
    love.graphics.rectangle("fill", boxX, boxY, boxWidth, boxHeight, 3, 3)
    love.graphics.setColor(0.5, 0.5, 0.6)
    love.graphics.rectangle("line", boxX, boxY, boxWidth, boxHeight, 3, 3)

    -- Draw text
    love.graphics.setColor(1, 1, 1)
    for i, line in ipairs(textLines) do
        love.graphics.print(line, boxX + padding, boxY + padding + (i - 1) * font:getHeight())
    end
end

function Game:keypressed(key)
    -- Global keys (like opening menu)
    if key == "escape" then
        gamestate.switch(require("src.states.menu"), self.game)
        return
    end
    if key == "m" then -- Example: Toggle map view (if implemented)
        -- Toggle map logic
        return
    end

    -- Map Navigation Keys (Example: Using arrow keys to select adjacent nodes)
    local currentRoom = self:findRoomById(self.currentNodeId)
    if not currentRoom then return end

    local targetNodeId = nil
    local connectedIds = self:getConnectedRoomIds(self.currentNodeId)
    local targetRoom = nil

    -- Find the relative position of connected rooms (this needs map layout logic)
    -- For a simple linear layout as drawn above:
    if key == "left" then
        if self.currentNodeId % 100 > 1 then targetNodeId = self.currentNodeId - 1 end
    elseif key == "right" then
         -- Check if next node exists on this floor
         local nextRoom = self:findRoomById(self.currentNodeId + 1)
         if nextRoom and nextRoom.floor == self.currentFloorIndex then
             targetNodeId = self.currentNodeId + 1
         end
    -- Add up/down logic if map layout supports it
    end

    if targetNodeId then
         -- Check if the target node is actually connected (important for non-linear maps)
         local isConnected = false
         for _, id in ipairs(connectedIds) do
             if id == targetNodeId then isConnected = true; break end
         end

         if isConnected then
             self.selectedNodeId = targetNodeId
             print("Selected node: " .. self.selectedNodeId)
         else
             print("Node " .. targetNodeId .. " is not connected to current node " .. self.currentNodeId)
         end
    end

    -- Action Key (Example: Enter/Space to move to selected node)
    if (key == "return" or key == "space") and self.selectedNodeId then
        local targetRoom = self:findRoomById(self.selectedNodeId)
        if targetRoom then
            print("Attempting to enter room: " .. targetRoom.id .. " Type: " .. targetRoom.type)
            self.currentNodeId = self.selectedNodeId
            self.selectedNodeId = nil -- Deselect after moving

            -- Handle entering the room based on type
            if targetRoom.type == "combat" and not targetRoom.isCleared then
                self:enterCombat(targetRoom)
            elseif targetRoom.type == "treasure" then
                -- Handle treasure room logic
                print("Entered Treasure Room!")
                targetRoom.isCleared = true -- Mark as cleared after entering
                -- Grant rewards...
            elseif targetRoom.type == "boss" and not targetRoom.isCleared then
                 self:enterCombat(targetRoom) -- Boss rooms trigger combat
            -- Add cases for other room types (shop, puzzle, rest)
            else
                print("Entered room type: " .. targetRoom.type)
                -- Mark non-combat rooms as cleared upon entry? Or require interaction?
                if targetRoom.type ~= "combat" and targetRoom.type ~= "boss" then
                     targetRoom.isCleared = true
                end
            end
        end
    end
end

function Game:mousepressed(x, y, button)
    if button == 1 then -- Left Click
        -- Check if a map node was clicked
        local clickedNodeId = self:getNodeAtScreenPos(x, y)
        if clickedNodeId then
            local connectedIds = self:getConnectedRoomIds(self.currentNodeId)
            local isConnected = false
            for _, id in ipairs(connectedIds) do if id == clickedNodeId then isConnected = true; break end end

            if isConnected then
                self.selectedNodeId = clickedNodeId
                print("Selected node via click: " .. self.selectedNodeId)

                -- Double click to enter
                local currentTime = love.timer.getTime()
                if self.lastClickTime and currentTime - self.lastClickTime < 0.3 and self.lastClickedNodeId == clickedNodeId then
                    local targetRoom = self:findRoomById(self.selectedNodeId)
                    if targetRoom then
                        print("Entering room via double click: " .. targetRoom.id .. " Type: " .. targetRoom.type)
                        self.currentNodeId = self.selectedNodeId
                        self.selectedNodeId = nil -- Deselect after moving

                        -- Handle entering the room based on type
                        if (targetRoom.type == "combat" or targetRoom.type == "boss" or targetRoom.type == "elite") and not targetRoom.isCleared then
                            self:enterCombat(targetRoom)
                        else
                            print("Entered room type: " .. targetRoom.type)
                             if targetRoom.type ~= "combat" and targetRoom.type ~= "boss" and targetRoom.type ~= "elite" then
                                 targetRoom.isCleared = true -- Mark non-combat as cleared
                             end
                        end
                    end
                end
                self.lastClickTime = currentTime
                self.lastClickedNodeId = clickedNodeId

            else
                print("Clicked node " .. clickedNodeId .. " is not connected to current node " .. self.currentNodeId)
                self.selectedNodeId = nil -- Deselect if not connected
            end
        else
            self.selectedNodeId = nil -- Clicked empty space
        end
    end
end

function Game:mousemoved(x, y, dx, dy)
    -- Update hovered node
    self.hoveredNodeId = self:getNodeAtScreenPos(x, y)
end

-- Helper to get node ID at screen position
function Game:getNodeAtScreenPos(screenX, screenY)
    local floor = self.dungeon and self.dungeon.floors[self.currentFloorIndex]
    if not floor then return nil end

    -- Need to account for camera offset/scale if map is pannable/zoomable
    -- For now, assume fixed map position as drawn in drawDungeonMap
    local minX, maxX, minY, maxY = 1000, -1000, 1000, -1000
    for _, room in ipairs(floor.rooms) do
        if room.mapPosition then
            minX = math.min(minX, room.mapPosition.x)
            maxX = math.max(maxX, room.mapPosition.x)
            minY = math.min(minY, room.mapPosition.y)
            maxY = math.max(maxY, room.mapPosition.y)
        end
    end
     local mapWidth = maxX - minX + MAP_NODE_SIZE
     local mapHeight = maxY - minY + MAP_NODE_SIZE
     local mapOffsetX = (love.graphics.getWidth() - mapWidth) / 2 - minX
     local mapOffsetY = (love.graphics.getHeight() - mapHeight) / 2 - minY

    for _, room in ipairs(floor.rooms) do
        if room.mapPosition then
            local nodeX = mapOffsetX + room.mapPosition.x
            local nodeY = mapOffsetY + room.mapPosition.y
            if screenX >= nodeX and screenX <= nodeX + MAP_NODE_SIZE and
               screenY >= nodeY and screenY <= nodeY + MAP_NODE_SIZE then
                return room.id
            end
        end
    end
    return nil
end


-- Function to initiate combat
function Game:enterCombat(room)
    print("Entering combat in room: " .. room.id)
    self.lastCombatNodeId = room.id -- Remember which node triggered combat

    -- 1. Prepare Player Data: Create deep copies or pass references carefully.
    --    For simplicity, let's pass references, assuming combat state won't
    --    permanently alter units beyond health/status unless intended.
    local playerCombatParty = {}
    for _, unit in ipairs(self.playerParty) do
        -- TODO: Consider cloning if combat should not affect the main party state directly
        -- until after combat resolution. For now, pass reference.
        table.insert(playerCombatParty, unit)
    end

    -- 2. Prepare Enemy Data: Get the formation data from the room.
    local enemyFormationData = room.enemyFormation
    if not enemyFormationData then
        print("WARNING: Combat room " .. room.id .. " has no enemy formation data!")
        -- Decide how to handle this: maybe generate a default formation?
        -- For now, we'll proceed but combat state needs to handle nil formation.
    end

    -- 3. Prepare Grid Data: Pass dimensions or layout info.
    --    Combat state will create its own Grid instance.
    local gridLayoutData = room.gridData -- Contains width, height, maybe tile info

    -- 4. Get Combat State Reference
    local CombatState = require("src.states.combat") -- Ensure it's loaded

    -- 5. Switch State
    gamestate.switch(CombatState, self.game, playerCombatParty, enemyFormationData, gridLayoutData, self)
end


return Game