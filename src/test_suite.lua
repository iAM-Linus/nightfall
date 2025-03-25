-- Improved Test Suite for Nightfall Chess
-- Properly loads and tests actual module implementations

local class = require("lib.middleclass.middleclass")

local TestSuite = class("TestSuite")

function TestSuite:initialize(game)
    self.game = game or {} -- Use provided game or create empty placeholder
    self.tests = {}
    self.results = {
        passed = 0,
        failed = 0,
        skipped = 0,
        total = 0
    }
    self.currentTest = nil
    self.logs = {}
    
    -- Initialize required game assets for testing
    self:initializeTestEnvironment()
    
    -- Register all tests
    self:registerTests()
end

-- Initialize a minimal test environment (assets, config, etc.)
function TestSuite:initializeTestEnvironment()
    -- Create minimal game configuration for testing
    if not self.game.config then
        self.game.config = {
            tileSize = 32,
            screenWidth = 800,
            screenHeight = 600,
            debug = true
        }
    end
    
    -- Create minimal asset structure for testing
    if not self.game.assets then
        self.game.assets = {
            fonts = {
                small = love.graphics.newFont(12),
                medium = love.graphics.newFont(16),
                large = love.graphics.newFont(24),
                title = love.graphics.newFont(32)
            },
            sprites = {},
            sounds = {}
        }
    end
end

-- Register all test cases
function TestSuite:registerTests()
    -- Entity System Tests
    self:addTest("entity_initialization", "Test entity initialization", function()
        local Entity = require("src.entities.entity")
        
        -- Test basic entity creation
        local entity = Entity:new({
            name = "Test Entity",
            description = "A test entity",
            x = 5,
            y = 8,
            sprite = nil,
            color = {0.5, 0.7, 0.3, 1}
        })
        
        -- Verify entity properties
        self:assert(entity ~= nil, "Entity should be created successfully")
        self:assert(entity.name == "Test Entity", "Entity should have correct name")
        self:assert(entity.description == "A test entity", "Entity should have correct description")
        self:assert(entity.x == 5, "Entity should have correct x position")
        self:assert(entity.y == 8, "Entity should have correct y position")
        self:assert(entity.solid == true, "Entity should be solid by default")
        self:assert(entity.visible == true, "Entity should be visible by default")
        
        -- Test entity with custom properties
        local entity2 = Entity:new({
            name = "Custom Entity",
            solid = false,
            visible = false,
            properties = {
                customProp = "value",
                customNum = 42
            }
        })
        
        self:assert(entity2.solid == false, "Entity should respect solid parameter")
        self:assert(entity2.visible == false, "Entity should respect visible parameter")
        self:assert(entity2:getProperty("customProp") == "value", "Entity should store custom properties")
        self:assert(entity2:getProperty("customNum") == 42, "Entity should store numeric properties")
        self:assert(entity2:getProperty("nonexistent", "default") == "default", "getProperty should return default for missing props")
        
        -- Test entity methods
        entity:setProperty("test", "newValue")
        self:assert(entity:getProperty("test") == "newValue", "setProperty should set property value")
        
        self:assert(entity:isAt(5, 8) == true, "isAt should return true for matching coordinates")
        self:assert(entity:isAt(6, 8) == false, "isAt should return false for non-matching coordinates")
        
        -- Test distance calculations
        local entity3 = Entity:new({x = 8, y = 12})
        self:assert(entity:distanceTo(entity3) == 7, "distanceTo should calculate Manhattan distance correctly")
        self:assert(entity:isAdjacentTo(entity3) == false, "isAdjacentTo should return false for non-adjacent entities")
        
        local entity4 = Entity:new({x = 5, y = 9})
        self:assert(entity:isAdjacentTo(entity4) == true, "isAdjacentTo should return true for adjacent entities")
        
        -- Test direction calculation
        local dx, dy = entity:directionTo(entity3)
        self:assert(dx == 1 and dy == 1, "directionTo should return normalized direction vector")
        
        return true
    end)
    
    self:addTest("item_system", "Test item system functionality", function()
        local Item = require("src.entities.item")
        
        -- Test basic item creation
        local potion = Item:new({
            name = "Health Potion",
            description = "Restores 20 health",
            type = "consumable",
            rarity = "common",
            quantity = 3,
            stackable = true,
            maxStack = 5,
            value = 10
        })
        
        self:assert(potion ~= nil, "Item should be created successfully")
        self:assert(potion.name == "Health Potion", "Item should have correct name")
        self:assert(potion.quantity == 3, "Item should have correct quantity")
        self:assert(potion.stackable == true, "Item should be stackable")
        
        -- Test stack operations
        local overflow = potion:addToStack(1)
        self:assert(potion.quantity == 4, "addToStack should increase quantity")
        self:assert(overflow == 0, "addToStack should return 0 overflow when under max stack")
        
        overflow = potion:addToStack(2)
        self:assert(potion.quantity == 5, "addToStack should increase quantity up to max")
        self:assert(overflow == 1, "addToStack should return overflow amount")
        
        local removed = potion:removeFromStack(2)
        self:assert(potion.quantity == 3, "removeFromStack should decrease quantity")
        self:assert(removed == 2, "removeFromStack should return amount removed")
        
        -- Test item stacking logic
        local anotherPotion = Item:new({
            id = potion.id:sub(1, potion.id:find("_") - 1), -- Match base ID
            name = "Health Potion",
            stackable = true,
            maxStack = 5,
            quantity = 1
        })
        
        self:assert(Item.canStack(potion, anotherPotion), "canStack should return true for matching stackable items")
        
        anotherPotion.maxStack = 1
        self:assert(not Item.canStack(anotherPotion, potion), "canStack should return false when target is at max stack")
        
        -- Test item cloning
        local clonedPotion = potion:clone()
        self:assert(clonedPotion.name == potion.name, "Cloned item should have same name")
        self:assert(clonedPotion.quantity == potion.quantity, "Cloned item should have same quantity")
        self:assert(clonedPotion ~= potion, "Clone should be a different object")
        
        -- Test equipment functionality
        local sword = Item:new({
            name = "Iron Sword",
            type = "weapon",
            rarity = "common",
            slot = "weapon",
            stats = {attack = 5},
            equippableBy = {"knight", "king"}
        })
        
        local mockUnit = {
            unitType = "knight",
            stats = {attack = 10, defense = 5},
            equipment = {}
        }
        
        self:assert(sword:canEquip(mockUnit), "Knight should be able to equip sword")
        
        local equipped = sword:equip(mockUnit)
        self:assert(equipped, "equip should return true on success")
        self:assert(sword.equipped, "Item should be marked as equipped")
        self:assert(mockUnit.equipment.weapon == sword, "Unit should have item in equipment slot")
        self:assert(mockUnit.stats.attack == 15, "Equipment stats should be applied")
        
        local unequipped = sword:unequip(mockUnit)
        self:assert(unequipped, "unequip should return true on success")
        self:assert(not sword.equipped, "Item should be marked as unequipped")
        self:assert(mockUnit.equipment.weapon == nil, "Equipment slot should be empty")
        self:assert(mockUnit.stats.attack == 10, "Stats should return to original values")
        
        -- Test consumable functionality
        potion.consumable = true
        potion.useEffect = function(unit) 
            unit.stats.health = unit.stats.health + 20
            return true
        end
        
        mockUnit.stats.health = 30
        mockUnit.stats.maxHealth = 100
        
        local used, remove = potion:use(mockUnit)
        self:assert(used, "use should return true when successful")
        self:assert(mockUnit.stats.health == 50, "Consumable effect should be applied")
        self:assert(potion.quantity == 2, "Consumable quantity should decrease")
        self:assert(remove == false, "Item should not be removed yet")
        
        -- Test full description generation
        local desc = sword:getFullDescription()
        self:assert(desc:find("Attack: %+5"), "Full description should include stat bonuses")
        self:assert(desc:find("Equip: Weapon"), "Full description should include equipment slot")
        
        -- Test unique and quest items
        local questItem = Item:new({
            name = "Ancient Key",
            type = "key",
            questItem = true,
            unique = true
        })
        
        local desc2 = questItem:getFullDescription()
        self:assert(desc2:find("Unique"), "Full description should mention unique status")
        self:assert(desc2:find("Quest Item"), "Full description should mention quest item status")
        
        return true
    end)
    
    self:addTest("unit_system", "Test unit system functionality", function()
        local Unit = require("src.entities.unit")
        
        -- Test basic unit creation
        local knight = Unit:new({
            unitType = "knight",
            faction = "player",
            health = 20,
            maxHealth = 20,
            attack = 5,
            defense = 3,
            moveRange = 2,
            attackRange = 1,
            movementPattern = "knight",
            x = 3,
            y = 4
        })
        
        self:assert(knight ~= nil, "Unit should be created successfully")
        self:assert(knight.unitType == "knight", "Unit should have correct type")
        self:assert(knight.faction == "player", "Unit should have correct faction")
        self:assert(knight.isPlayerControlled == true, "Player faction unit should be player controlled")
        self:assert(knight.stats.health == 20, "Unit should have correct health")
        self:assert(knight.stats.attack == 5, "Unit should have correct attack")
        self:assert(knight.movementPattern == "knight", "Unit should have correct movement pattern")
        
        -- Test enemy unit
        local pawn = Unit:new({
            unitType = "pawn",
            faction = "enemy",
            health = 10,
            maxHealth = 10,
            attack = 2,
            defense = 1,
            moveRange = 1,
            attackRange = 1,
            movementPattern = "orthogonal"
        })
        
        self:assert(pawn.isPlayerControlled == false, "Enemy faction unit should not be player controlled")
        -- Test combat mechanics
        local damage = knight:attack(pawn)
        self:assert(pawn.stats.health < 10, "Attack should reduce target health")
        self:assert(knight.hasAttacked == true, "Unit should be marked as having attacked")
        
        -- Test healing
        local healAmount = 1
        local healed = pawn:heal(healAmount)
        self:assert(healed > 0, "heal should return amount healed")
        self:assert(pawn.stats.health == 7, "Health should increase but not exceed max health")
        -- Test taking damage
        local damageTaken = knight:takeDamage(8, pawn)
        self:assert(damageTaken == 8, "takeDamage should return damage amount")
        self:assert(knight.stats.health == 12, "Health should be reduced by damage amount")
        
        -- Test experience and leveling system
        self:assert(knight.level == 1, "Unit should start at level 1")
        
        local xpToLevel = knight.experienceToNextLevel
        knight:addExperience(xpToLevel)
        self:assert(knight.level == 2, "Unit should level up when reaching XP threshold")
        self:assert(knight.stats.maxHealth > 20, "Leveling up should increase max health")
        
        -- Test movement patterns
        -- Create a minimal grid for testing movement
        local mockGrid = {
            width = 8,
            height = 8,
            tileSize = 32,
            tiles = {},
            isInBounds = function(self, x, y)
                return x >= 1 and x <= self.width and y >= 1 and y <= self.height
            end,
            isWalkable = function(self, x, y)
                if not self:isInBounds(x, y) then return false end
                if self.tiles[y] and self.tiles[y][x] then
                    return self.tiles[y][x].walkable
                end
                return true -- Default to walkable
            end,
            getTile = function(self, x, y)
                if not self:isInBounds(x, y) then return nil end
                if not self.tiles[y] then self.tiles[y] = {} end
                if not self.tiles[y][x] then
                    self.tiles[y][x] = {x = x, y = y, walkable = true, entity = nil}
                end
                return self.tiles[y][x]
            end,
            getEntityAt = function(self, x, y)
                local tile = self:getTile(x, y)
                return tile and tile.entity or nil
            end
        }
        
        -- Initialize grid
        for y = 1, mockGrid.height do
            mockGrid.tiles[y] = {}
            for x = 1, mockGrid.width do
                mockGrid.tiles[y][x] = {x = x, y = y, walkable = true, entity = nil}
            end
        end
        
        -- Add a wall for testing
        mockGrid.tiles[3][5].walkable = false
        
        knight.grid = mockGrid
        pawn.grid = mockGrid
        
        -- Place units on grid
        mockGrid.tiles[knight.y][knight.x].entity = knight
        mockGrid.tiles[pawn.y][pawn.x].entity = pawn
        
        -- Test movement patterns
        local knightMoves = knight:getValidMovePositions()
        self:assert(#knightMoves > 0, "Knight should have valid moves")
        
        -- Knight should be able to move in L-shape
        local canJump = false
        for _, move in ipairs(knightMoves) do
            local dx = math.abs(move.x - knight.x)
            local dy = math.abs(move.y - knight.y)
            if (dx == 1 and dy == 2) or (dx == 2 and dy == 1) then
                canJump = true
                break
            end
        end
        self:assert(canJump, "Knight should be able to move in L-shape")
        
        -- Test pawn movement
        pawn.grid = mockGrid
        local pawnMoves = pawn:getValidMovePositions()
        self:assert(#pawnMoves > 0, "Pawn should have valid moves")
        
        -- Add a status effect
        knight:addStatusEffect({
            type = "burning",
            duration = 3,
            damage = 2,
            onUpdate = function(unit, dt)
                -- This would normally be called by the update function
            end
        })
        
        self:assert(#knight.statusEffects == 1, "Status effect should be added")
        
        knight:updateStatusEffects(1.0) -- Simulate 1 second passing
        
        -- Test status effect removal
        knight:removeStatusEffect("burning")
        self:assert(#knight.statusEffects == 0, "Status effect should be removed")
        
        return true
    end)
    
    -- Grid System Tests
    self:addTest("grid_system", "Test grid system functionality", function()
        local Grid = require("src.systems.grid")
        
        -- Create a test grid
        local grid = Grid:new(8, 8, 32)
        
        self:assert(grid ~= nil, "Grid should be created successfully")
        self:assert(grid.width == 8, "Grid should have correct width")
        self:assert(grid.height == 8, "Grid should have correct height")
        self:assert(grid.tileSize == 32, "Grid should have correct tile size")
        
        -- Test tile access and modification
        local tile = grid:getTile(3, 4)
        self:assert(tile ~= nil, "getTile should return a tile")
        self:assert(tile.x == 3 and tile.y == 4, "Tile should have correct coordinates")
        self:assert(tile.walkable == true, "Tile should be walkable by default")
        
        grid:setTileType(3, 4, "wall", false)
        tile = grid:getTile(3, 4)
        self:assert(tile.type == "wall", "setTileType should change tile type")
        self:assert(tile.walkable == false, "setTileType should update walkable status")
        
        -- Test coordinate conversion
        local screenX, screenY = grid:gridToScreen(2, 3)
        self:assert(screenX == 1 * grid.tileSize, "gridToScreen should convert x correctly")
        self:assert(screenY == 2 * grid.tileSize, "gridToScreen should convert y correctly")
        
        local gridX, gridY = grid:screenToGrid(screenX, screenY)
        self:assert(gridX == 2 and gridY == 3, "screenToGrid should convert coordinates correctly")
        
        -- Test entity placement
        local Entity = require("src.entities.entity")
        local entity = Entity:new({x = 1, y = 1, name = "Test Entity"})
        
        local placed = grid:placeEntity(entity, 5, 6)
        self:assert(placed, "placeEntity should return true on success")
        self:assert(entity.x == 5 and entity.y == 6, "Entity position should be updated")
        self:assert(entity.grid == grid, "Entity should reference grid")
        
        local entityAtPos = grid:getEntityAt(5, 6)
        self:assert(entityAtPos == entity, "getEntityAt should return the entity")
        
        -- Test entity movement
        local moved = grid:moveEntity(entity, 7, 7)
        self:assert(moved, "moveEntity should return true on success")
        self:assert(entity.x == 7 and entity.y == 7, "Entity position should be updated")
        self:assert(grid:getEntityAt(5, 6) == nil, "Old position should be empty")
        self:assert(grid:getEntityAt(7, 7) == entity, "New position should contain entity")
        
        -- Test move to occupied tile
        local anotherEntity = Entity:new({name = "Another Entity"})
        grid:placeEntity(anotherEntity, 4, 4)
        
        local blockedMove = grid:moveEntity(entity, 4, 4)
        self:assert(not blockedMove, "moveEntity should return false for occupied tile")
        self:assert(entity.x == 7 and entity.y == 7, "Entity position should not change")
        
        -- Test move to unwalkable tile
        grid:setTileType(3, 3, "wall", false)
        local blockedByWall = grid:moveEntity(entity, 3, 3)
        self:assert(not blockedByWall, "moveEntity should return false for unwalkable tile")
        
        -- Test entity removal
        grid:removeEntity(entity)
        self:assert(grid:getEntityAt(7, 7) == nil, "removeEntity should remove entity from grid")
        
        -- Test visibility and exploration
        grid.fogOfWar = true
        grid:updateVisibility()
        
        -- Mark some tiles as visible
        local visibleTile = grid:getTile(2, 2)
        visibleTile.visible = true
        visibleTile.explored = true
        
        local isVisible = grid:isVisible(2, 2)
        print(isVisible)
        self:assert(isVisible, "isVisible should return true for visible tile")
        
        local isExplored = grid:isExplored(2, 2)
        self:assert(isExplored, "isExplored should return true for explored tile")
        
        return true
    end)
    
    -- Game States Tests
    self:addTest("menu_state", "Test menu state functionality", function()
        local Menu = require("src.states.menu")
        
        -- Since Menu is a gamestate, we can't fully test it without a running game
        -- But we can test some of its functions
        
        self:assert(Menu ~= nil, "Menu state should load successfully")
        self:assert(type(Menu.draw) == "function", "Menu should have a draw function")
        self:assert(type(Menu.update) == "function", "Menu should have an update function")
        self:assert(type(Menu.keypressed) == "function", "Menu should have a keypressed function")
        
        -- Test menu initialization with mock game
        local mockGame = {
            assets = {
                fonts = {
                    title = love.graphics.newFont(32),
                    large = love.graphics.newFont(24),
                    small = love.graphics.newFont(12)
                }
            }
        }
        
        -- Test that it doesn't error
        local success, err = pcall(function()
            Menu:enter(nil, mockGame)
        end)
        
        self:assert(success, "Menu:enter should not throw an error: " .. (err or ""))
        
        return true
    end)
    
    self:addTest("game_state", "Test game state functionality", function()
        local Game = require("src.states.game")
        
        self:assert(Game ~= nil, "Game state should load successfully")
        self:assert(type(Game.draw) == "function", "Game should have a draw function")
        self:assert(type(Game.update) == "function", "Game should have an update function")
        self:assert(type(Game.keypressed) == "function", "Game should have a keypressed function")
        
        -- Create a minimal mock game for testing
        local mockGame = {
            config = {
                tileSize = 32
            },
            assets = {
                fonts = {
                    small = love.graphics.newFont(12),
                    medium = love.graphics.newFont(16),
                    large = love.graphics.newFont(24),
                    title = love.graphics.newFont(32)
                }
            }
        }
        
        -- Test that enter doesn't error
        local success, err = pcall(function()
            -- Don't actually call enter as it sets up the full game
            -- Just verify the function exists and has the right format
            self:assert(type(Game.enter) == "function", "Game should have an enter function")
        end)
        
        self:assert(success, "Game state test should not throw an error: " .. (err or ""))
        
        return true
    end)
    
    self:addTest("inventory_state", "Test inventory state functionality", function()
        local Inventory = require("src.states.inventory")
        
        self:assert(Inventory ~= nil, "Inventory state should load successfully")
        self:assert(type(Inventory.draw) == "function", "Inventory should have a draw function")
        self:assert(type(Inventory.update) == "function", "Inventory should have an update function")
        self:assert(type(Inventory.keypressed) == "function", "Inventory should have a keypressed function")
        
        -- Since we can't test the full rendering, focus on utility functions
        
        -- Test the creation of default items
        local success, err = pcall(function()
            Inventory:createDefaultItems()
        end)
        
        self:assert(success, "createDefaultItems should not throw an error: " .. (err or ""))
        
        return true
    end)
    
    -- Integration Tests
    self:addTest("item_database", "Test item database content", function()
        local ItemDatabase = require("src.data.item_database")
        
        -- Check that database loaded properly
        self:assert(ItemDatabase ~= nil, "ItemDatabase should load successfully")
        
        -- Check database categories
        self:assert(type(ItemDatabase.weapons) == "table", "ItemDatabase should have weapons table")
        self:assert(type(ItemDatabase.armor) == "table", "ItemDatabase should have armor table")
        self:assert(type(ItemDatabase.accessories) == "table", "ItemDatabase should have accessories table")
        self:assert(type(ItemDatabase.consumables) == "table", "ItemDatabase should have consumables table")
        self:assert(type(ItemDatabase.keyItems) == "table", "ItemDatabase should have keyItems table")
        
        -- Check that database has content
        self:assert(next(ItemDatabase.weapons) ~= nil, "Weapons database should not be empty")
        self:assert(next(ItemDatabase.armor) ~= nil, "Armor database should not be empty")
        
        -- Check database utility functions
        local allItems = ItemDatabase.getAllItems()
        self:assert(type(allItems) == "table", "getAllItems should return a table")
        self:assert(next(allItems) ~= nil, "getAllItems should return non-empty table")
        
        -- Test random item generation
        local randomItem = ItemDatabase.getRandomItem(1, "weapon")
        self:assert(randomItem ~= nil, "getRandomItem should return an item")
        self:assert(type(randomItem.id) == "string", "Random item should have an id")
        self:assert(type(randomItem.data) == "table", "Random item should have data")
        self:assert(randomItem.data.type == "weapon", "Random item should be of requested type")
        
        -- Test item by level filtering
        local lowLevelItem = ItemDatabase.getRandomItem(1)
        self:assert(lowLevelItem.data.rarity == "common", "Level 1 items should be common rarity")
        
        -- Higher level items might not always be uncommon or better, so don't test that
        
        return true
    end)
    
    self:addTest("entity_item_unit_integration", "Test entity, item, and unit integration", function()
        local Entity = require("src.entities.entity")
        local Item = require("src.entities.item")
        local Unit = require("src.entities.unit")
        
        -- Test that Unit extends Entity
        local knight = Unit:new({
            unitType = "knight",
            name = "Sir Testington",
            x = 3,
            y = 4
        })
        
        self:assert(knight:isInstanceOf(Entity), "Unit should be an instance of Entity")
        
        -- Test equipping an item to a unit
        local sword = Item:new({
            name = "Test Sword",
            type = "weapon",
            slot = "weapon",
            stats = {
                attack = 5
            },
            equippableBy = {"knight"}
        })
        
        local originalAttack = knight.stats.attack
        local equipped = sword:equip(knight)
        
        self:assert(equipped, "Knight should be able to equip the sword")
        self:assert(knight.stats.attack == originalAttack + 5, "Sword should increase knight's attack")
        
        -- Test item with status effect
        local poisonPotion = Item:new({
            name = "Poison Potion",
            type = "consumable",
            consumable = true,
            onUse = function(target)
                target:addStatusEffect({
                    type = "poison",
                    duration = 3,
                    damage = 2
                })
                return true
            end
        })
        
        local used = poisonPotion:use(knight)
        self:assert(used, "Item use effect should execute successfully")
        
        local hasPoison = false
        for _, effect in pairs(knight.statusEffects) do
            if effect.type == "poison" then
                hasPoison = true
                break
            end
        end
        
        self:assert(hasPoison, "Status effect from item should be applied to unit")
        
        return true
    end)
end

-- Add a test to the suite
function TestSuite:addTest(id, name, testFunction)
    table.insert(self.tests, {
        id = id,
        name = name,
        func = testFunction,
        result = nil,
        error = nil
    })
    self.results.total = self.results.total + 1
end

-- Run all tests
function TestSuite:runAllTests()
    self:log("Starting test suite for Nightfall Chess")
    self:log("Total tests: " .. self.results.total)
    self:log("------------------------------------")
    
    for i, test in ipairs(self.tests) do
        self:runTest(i)
    end
    
    self:log("------------------------------------")
    self:log("Test results:")
    self:log("  Passed: " .. self.results.passed)
    self:log("  Failed: " .. self.results.failed)
    self:log("  Skipped: " .. self.results.skipped)
    self:log("  Total: " .. self.results.total)
    
    return self.results
end

-- Run a specific test
function TestSuite:runTest(index)
    local test = self.tests[index]
    if not test then
        return false, "Test not found"
    end
    
    self.currentTest = test
    self:log("Running test: " .. test.name .. " (" .. test.id .. ")")
    
    local success, result = pcall(function()
        return test.func(self)
    end)
    
    if success then
        if result then
            test.result = true
            self.results.passed = self.results.passed + 1
            self:log("  ✓ PASS")
        else
            test.result = false
            self.results.failed = self.results.failed + 1
            self:log("  ✗ FAIL: Test returned false")
        end
    else
        test.result = false
        test.error = result
        self.results.failed = self.results.failed + 1
        self:log("  ✗ ERROR: " .. tostring(result))
    end
    
    self.currentTest = nil
    return test.result, test.error
end

-- Skip a test
function TestSuite:skipTest(index)
    local test = self.tests[index]
    if not test then
        return false, "Test not found"
    end
    
    test.result = "skipped"
    self.results.skipped = self.results.skipped + 1
    self.results.total = self.results.total - 1
    
    self:log("Skipping test: " .. test.name)
    return true
end

-- Assert a condition
function TestSuite:assert(condition, message)
    if not condition then
        error(message or "Assertion failed", 2)
    end
    return condition
end

-- Log a message
function TestSuite:log(message)
    table.insert(self.logs, message)
    print(message)
    return message
end

-- Get test results
function TestSuite:getResults()
    return self.results
end

-- Get test logs
function TestSuite:getLogs()
    return self.logs
end

return TestSuite