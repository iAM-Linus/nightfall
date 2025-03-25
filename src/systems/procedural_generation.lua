-- Procedural Generation System for Nightfall Chess
-- Handles creation of dynamic dungeons, rooms, and challenges

local class = require("lib.middleclass.middleclass")

local ProceduralGeneration = class("ProceduralGeneration")

function ProceduralGeneration:initialize(game)
    self.game = game
    
    -- Configuration for procedural generation
    self.config = {
        -- Dungeon structure
        dungeon = {
            minFloors = 3,
            maxFloors = 7,
            minRoomsPerFloor = 3,
            maxRoomsPerFloor = 6,
            roomTypes = {
                "combat", "treasure", "shop", "puzzle", "rest", "elite", "boss"
            },
            roomTypeWeights = {
                combat = 50,
                treasure = 15,
                shop = 10,
                puzzle = 10,
                rest = 10,
                elite = 5,
                boss = 0  -- Boss rooms are placed manually
            },
            bossRoomEveryNFloors = 3,  -- Boss every 3 floors
            eliteRoomEveryNRooms = 5,  -- Elite every 5 rooms
            treasureRoomAfterBoss = true,  -- Guaranteed treasure after boss
            restRoomBeforeBoss = true,  -- Guaranteed rest before boss
        },
        
        -- Room sizes
        roomSizes = {
            small = {width = 8, height = 8},
            medium = {width = 10, height = 10},
            large = {width = 12, height = 12},
            boss = {width = 14, height = 14}
        },
        
        -- Room features
        roomFeatures = {
            -- Terrain features that can appear in rooms
            terrain = {
                "water", "lava", "forest", "elevated", "corrupted"
            },
            
            -- Obstacle types
            obstacles = {
                "wall", "pillar", "debris", "spikes", "barrier"
            },
            
            -- Special features
            special = {
                "healing_fountain", "energy_crystal", "teleporter", 
                "trap", "shrine", "chest", "altar"
            }
        },
        
        -- Enemy formations
        enemyFormations = {
            -- Basic formations for normal combat rooms
            basic = {
                -- Formation name = {enemy types and positions}
                pawnLine = {
                    {type = "pawn", relativeX = 0, relativeY = 1},
                    {type = "pawn", relativeX = 1, relativeY = 1},
                    {type = "pawn", relativeX = 2, relativeY = 1},
                    {type = "pawn", relativeX = 3, relativeY = 1}
                },
                knightFlankers = {
                    {type = "knight", relativeX = 0, relativeY = 0},
                    {type = "knight", relativeX = 3, relativeY = 0},
                    {type = "pawn", relativeX = 1, relativeY = 1},
                    {type = "pawn", relativeX = 2, relativeY = 1}
                },
                bishopSupport = {
                    {type = "bishop", relativeX = 1, relativeY = 0},
                    {type = "bishop", relativeX = 2, relativeY = 0},
                    {type = "pawn", relativeX = 0, relativeY = 1},
                    {type = "pawn", relativeX = 3, relativeY = 1}
                },
                rookDefenders = {
                    {type = "rook", relativeX = 1, relativeY = 0},
                    {type = "rook", relativeX = 2, relativeY = 0},
                    {type = "pawn", relativeX = 0, relativeY = 1},
                    {type = "pawn", relativeX = 3, relativeY = 1}
                },
                mixedGroup = {
                    {type = "knight", relativeX = 0, relativeY = 0},
                    {type = "bishop", relativeX = 1, relativeY = 0},
                    {type = "rook", relativeX = 2, relativeY = 0},
                    {type = "pawn", relativeX = 3, relativeY = 1}
                }
            },
            
            -- Elite formations for elite combat rooms
            elite = {
                queenGuards = {
                    {type = "queen", relativeX = 2, relativeY = 0},
                    {type = "knight", relativeX = 0, relativeY = 1},
                    {type = "knight", relativeX = 4, relativeY = 1},
                    {type = "bishop", relativeX = 1, relativeY = 1},
                    {type = "bishop", relativeX = 3, relativeY = 1}
                },
                rookPhalanx = {
                    {type = "rook", relativeX = 0, relativeY = 0},
                    {type = "rook", relativeX = 4, relativeY = 0},
                    {type = "pawn", relativeX = 1, relativeY = 1},
                    {type = "pawn", relativeX = 2, relativeY = 1},
                    {type = "pawn", relativeX = 3, relativeY = 1},
                    {type = "pawn", relativeX = 1, relativeY = 2},
                    {type = "pawn", relativeX = 2, relativeY = 2},
                    {type = "pawn", relativeX = 3, relativeY = 2}
                },
                bishopCoven = {
                    {type = "bishop", relativeX = 1, relativeY = 0},
                    {type = "bishop", relativeX = 3, relativeY = 0},
                    {type = "bishop", relativeX = 2, relativeY = 1},
                    {type = "pawn", relativeX = 0, relativeY = 2},
                    {type = "pawn", relativeX = 4, relativeY = 2}
                },
                knightAmbush = {
                    {type = "knight", relativeX = 0, relativeY = 0},
                    {type = "knight", relativeX = 1, relativeY = 0},
                    {type = "knight", relativeX = 3, relativeY = 0},
                    {type = "knight", relativeX = 4, relativeY = 0},
                    {type = "bishop", relativeX = 2, relativeY = 1}
                }
            },
            
            -- Boss formations for boss rooms
            boss = {
                shadowKing = {
                    {type = "king", relativeX = 2, relativeY = 0, isBoss = true},
                    {type = "queen", relativeX = 1, relativeY = 1},
                    {type = "queen", relativeX = 3, relativeY = 1},
                    {type = "rook", relativeX = 0, relativeY = 2},
                    {type = "rook", relativeX = 4, relativeY = 2}
                },
                twinQueens = {
                    {type = "queen", relativeX = 1, relativeY = 0, isBoss = true},
                    {type = "queen", relativeX = 3, relativeY = 0, isBoss = true},
                    {type = "bishop", relativeX = 0, relativeY = 1},
                    {type = "bishop", relativeX = 4, relativeY = 1},
                    {type = "knight", relativeX = 2, relativeY = 2}
                },
                rookLords = {
                    {type = "rook", relativeX = 0, relativeY = 0, isBoss = true},
                    {type = "rook", relativeX = 4, relativeY = 0, isBoss = true},
                    {type = "pawn", relativeX = 1, relativeY = 1},
                    {type = "pawn", relativeX = 2, relativeY = 1},
                    {type = "pawn", relativeX = 3, relativeY = 1},
                    {type = "bishop", relativeX = 2, relativeY = 2}
                },
                knightOrder = {
                    {type = "knight", relativeX = 1, relativeY = 0, isBoss = true},
                    {type = "knight", relativeX = 3, relativeY = 0, isBoss = true},
                    {type = "knight", relativeX = 0, relativeY = 1, isBoss = true},
                    {type = "knight", relativeX = 4, relativeY = 1, isBoss = true},
                    {type = "bishop", relativeX = 2, relativeY = 2}
                },
                finalBoss = {
                    {type = "king", relativeX = 2, relativeY = 0, isBoss = true, isUnique = true},
                    {type = "queen", relativeX = 1, relativeY = 1, isBoss = true},
                    {type = "queen", relativeX = 3, relativeY = 1, isBoss = true},
                    {type = "rook", relativeX = 0, relativeY = 2, isBoss = true},
                    {type = "rook", relativeX = 4, relativeY = 2, isBoss = true},
                    {type = "bishop", relativeX = 1, relativeY = 3},
                    {type = "bishop", relativeX = 3, relativeY = 3},
                    {type = "knight", relativeX = 0, relativeY = 4},
                    {type = "knight", relativeX = 4, relativeY = 4}
                }
            }
        },
        
        -- Treasure types and rarities
        treasures = {
            types = {
                "gold", "item", "artifact", "skill_point", "health", "energy"
            },
            rarities = {
                common = 60,
                uncommon = 30,
                rare = 9,
                legendary = 1
            },
            valueByRarity = {
                common = {min = 10, max = 30},
                uncommon = {min = 30, max = 60},
                rare = {min = 60, max = 100},
                legendary = {min = 100, max = 200}
            }
        },
        
        -- Puzzle types
        puzzles = {
            types = {
                "pattern_match", "sequence", "pressure_plate", "chess_puzzle", 
                "mirror", "light_beam", "lock_and_key"
            },
            difficulties = {
                easy = 30,
                medium = 50,
                hard = 20
            },
            rewardsMultiplier = {
                easy = 1.0,
                medium = 1.5,
                hard = 2.0
            }
        }
    }
    
    -- Seed for random generation
    self.seed = os.time()
    math.randomseed(self.seed)
    
    -- Current dungeon data
    self.currentDungeon = nil
end

-- Generate a complete dungeon
function ProceduralGeneration:generateDungeon(difficulty)
    difficulty = difficulty or "normal"
    
    -- Create dungeon structure
    local dungeon = {
        seed = self.seed,
        difficulty = difficulty,
        floors = {},
        currentFloor = 1,
        totalRooms = 0,
        clearedRooms = 0,
        treasuresFound = 0,
        enemiesDefeated = 0
    }
    
    -- Determine number of floors based on difficulty
    local numFloors = self:randomInRange(self.config.dungeon.minFloors, self.config.dungeon.maxFloors)
    if difficulty == "easy" then
        numFloors = self.config.dungeon.minFloors
    elseif difficulty == "hard" then
        numFloors = self.config.dungeon.maxFloors
    end
    
    -- Generate each floor
    for i = 1, numFloors do
        local isBossFloor = (i % self.config.dungeon.bossRoomEveryNFloors == 0) or (i == numFloors)
        local floor = self:generateFloor(i, isBossFloor, difficulty)
        table.insert(dungeon.floors, floor)
        dungeon.totalRooms = dungeon.totalRooms + #floor.rooms
    end
    
    -- Store the current dungeon
    self.currentDungeon = dungeon
    
    return dungeon
end

-- Generate a single floor
function ProceduralGeneration:generateFloor(floorNumber, isBossFloor, difficulty)
    local floor = {
        number = floorNumber,
        rooms = {},
        connections = {},
        isBossFloor = isBossFloor,
        isCleared = false
    }
    
    -- Determine number of rooms
    local numRooms = self:randomInRange(self.config.dungeon.minRoomsPerFloor, self.config.dungeon.maxRoomsPerFloor)
    if difficulty == "easy" then
        numRooms = self.config.dungeon.minRoomsPerFloor
    elseif difficulty == "hard" then
        numRooms = self.config.dungeon.maxRoomsPerFloor
    end
    
    -- If it's a boss floor, ensure we have room for special rooms
    if isBossFloor then
        numRooms = math.max(numRooms, 3) -- At least entrance, rest, and boss
    end
    
    -- Create rooms
    for i = 1, numRooms do
        local roomType = self:selectRoomType(i, numRooms, isBossFloor)
        local room = self:generateRoom(roomType, floorNumber, difficulty)
        room.id = floorNumber * 100 + i
        room.position = {x = i, y = floorNumber}
        table.insert(floor.rooms, room)
    end
    
    -- Create connections between rooms
    floor.connections = self:generateConnections(floor.rooms)
    
    return floor
end

-- Select room type based on position and floor type
function ProceduralGeneration:selectRoomType(roomIndex, totalRooms, isBossFloor)
    -- First room is always entrance
    if roomIndex == 1 then
        return "entrance"
    end
    
    -- Last room on boss floor is boss
    if isBossFloor and roomIndex == totalRooms then
        return "boss"
    end
    
    -- Room before boss is rest
    if isBossFloor and roomIndex == totalRooms - 1 and self.config.dungeon.restRoomBeforeBoss then
        return "rest"
    end
    
    -- Elite rooms every N rooms
    if roomIndex % self.config.dungeon.eliteRoomEveryNRooms == 0 then
        return "elite"
    end
    
    -- Random selection for other rooms
    return self:weightedRandomSelection(self.config.dungeon.roomTypeWeights)
end

-- Generate a single room
function ProceduralGeneration:generateRoom(roomType, floorNumber, difficulty)
    local room = {
        type = roomType,
        size = self:selectRoomSize(roomType),
        grid = nil,
        entities = {},
        features = {},
        isCleared = false,
        isVisited = false,
        rewards = {}
    }
    
    -- Create grid based on room size
    room.grid = self:createGrid(room.size.width, room.size.height)
    
    -- Add room features based on type
    self:addRoomFeatures(room, floorNumber, difficulty)
    
    -- Add entities based on room type
    self:addRoomEntities(room, floorNumber, difficulty)
    
    -- Add rewards based on room type
    self:addRoomRewards(room, floorNumber, difficulty)
    
    return room
end

-- Select appropriate room size based on room type
function ProceduralGeneration:selectRoomSize(roomType)
    if roomType == "boss" then
        return self.config.roomSizes.boss
    elseif roomType == "elite" then
        return self.config.roomSizes.large
    elseif roomType == "combat" or roomType == "puzzle" then
        return self.config.roomSizes.medium
    else
        return self.config.roomSizes.small
    end
end

-- Create an empty grid of specified size
function ProceduralGeneration:createGrid(width, height)
    local grid = {
        width = width,
        height = height,
        cells = {}
    }
    
    for y = 1, height do
        grid.cells[y] = {}
        for x = 1, width do
            grid.cells[y][x] = {
                type = "floor",
                walkable = true,
                visible = false,
                explored = false,
                entity = nil,
                feature = nil
            }
        end
    end
    
    return grid
end

-- Add features to a room based on its type
function ProceduralGeneration:addRoomFeatures(room, floorNumber, difficulty)
    local featureCount = 0
    
    -- Determine number of features based on room type and difficulty
    if room.type == "combat" then
        featureCount = self:randomInRange(2, 4)
    elseif room.type == "elite" or room.type == "boss" then
        featureCount = self:randomInRange(3, 6)
    elseif room.type == "puzzle" then
        featureCount = self:randomInRange(4, 8)
    else
        featureCount = self:randomInRange(1, 3)
    end
    
    if difficulty == "easy" then
        featureCount = math.max(1, featureCount - 1)
    elseif difficulty == "hard" then
        featureCount = featureCount + 1
    end
    
    -- Add terrain features
    for i = 1, featureCount do
        local featureType = self:randomSelection(self.config.roomFeatures.terrain)
        local feature = self:createFeature(featureType, room)
        table.insert(room.features, feature)
        
        -- Apply feature to grid
        self:applyFeatureToGrid(feature, room.grid)
    end
    
    -- Add obstacles
    local obstacleCount = math.floor(featureCount / 2)
    for i = 1, obstacleCount do
        local obstacleType = self:randomSelection(self.config.roomFeatures.obstacles)
        local obstacle = self:createObstacle(obstacleType, room)
        table.insert(room.features, obstacle)
        
        -- Apply obstacle to grid
        self:applyObstacleToGrid(obstacle, room.grid)
    end
    
    -- Add special features based on room type
    if room.type == "treasure" then
        local chest = self:createSpecialFeature("chest", room)
        table.insert(room.features, chest)
        self:applySpecialFeatureToGrid(chest, room.grid)
    elseif room.type == "rest" then
        local fountain = self:createSpecialFeature("healing_fountain", room)
        table.insert(room.features, fountain)
        self:applySpecialFeatureToGrid(fountain, room.grid)
    elseif room.type == "puzzle" then
        local puzzleType = self:randomSelection(self.config.puzzles.types)
        local puzzle = self:createPuzzle(puzzleType, room, difficulty)
        table.insert(room.features, puzzle)
        self:applyPuzzleToGrid(puzzle, room.grid)
    elseif room.type == "shop" then
        local shopkeeper = self:createSpecialFeature("shopkeeper", room)
        table.insert(room.features, shopkeeper)
        self:applySpecialFeatureToGrid(shopkeeper, room.grid)
    end
end

-- Create a terrain feature
function ProceduralGeneration:createFeature(featureType, room)
    local feature = {
        type = featureType,
        category = "terrain",
        positions = {},
        properties = {}
    }
    
    -- Set feature properties based on type
    if featureType == "water" then
        feature.properties = {
            movementCost = 2,
            defensiveBonus = 0,
            offensiveBonus = 0,
            damagePerTurn = 0,
            statusEffect = nil
        }
    elseif featureType == "lava" then
        feature.properties = {
            movementCost = 3,
            defensiveBonus = 0,
            offensiveBonus = 1,
            damagePerTurn = 2,
            statusEffect = "burning"
        }
    elseif featureType == "forest" then
        feature.properties = {
            movementCost = 2,
            defensiveBonus = 1,
            offensiveBonus = 0,
            damagePerTurn = 0,
            statusEffect = nil
        }
    elseif featureType == "elevated" then
        feature.properties = {
            movementCost = 2,
            defensiveBonus = 0,
            offensiveBonus = 1,
            damagePerTurn = 0,
            statusEffect = nil
        }
    elseif featureType == "corrupted" then
        feature.properties = {
            movementCost = 1,
            defensiveBonus = -1,
            offensiveBonus = 0,
            damagePerTurn = 0,
            statusEffect = "weakened"
        }
    end
    
    -- Generate feature positions
    local featureSize = self:randomInRange(3, 6)
    local startX = self:randomInRange(2, room.size.width - featureSize - 1)
    local startY = self:randomInRange(2, room.size.height - featureSize - 1)
    
    -- Create a blob-like shape for the feature
    for i = 1, featureSize do
        for j = 1, featureSize do
            -- Add some randomness to create irregular shapes
            if math.random() < 0.7 then
                local x = startX + i
                local y = startY + j
                
                -- Ensure position is within grid bounds
                if x > 0 and x <= room.size.width and y > 0 and y <= room.size.height then
                    table.insert(feature.positions, {x = x, y = y})
                end
            end
        end
    end
    
    return feature
end

-- Create an obstacle
function ProceduralGeneration:createObstacle(obstacleType, room)
    local obstacle = {
        type = obstacleType,
        category = "obstacle",
        positions = {},
        properties = {}
    }
    
    -- Set obstacle properties based on type
    if obstacleType == "wall" then
        obstacle.properties = {
            isBlocking = true,
            isDestructible = false,
            health = 0,
            damageOnContact = 0
        }
    elseif obstacleType == "pillar" then
        obstacle.properties = {
            isBlocking = true,
            isDestructible = false,
            health = 0,
            damageOnContact = 0
        }
    elseif obstacleType == "debris" then
        obstacle.properties = {
            isBlocking = true,
            isDestructible = true,
            health = 10,
            damageOnContact = 0
        }
    elseif obstacleType == "spikes" then
        obstacle.properties = {
            isBlocking = false,
            isDestructible = false,
            health = 0,
            damageOnContact = 3
        }
    elseif obstacleType == "barrier" then
        obstacle.properties = {
            isBlocking = true,
            isDestructible = true,
            health = 20,
            damageOnContact = 0
        }
    end
    
    -- Generate obstacle positions
    if obstacleType == "wall" then
        -- Create a wall-like structure
        local wallLength = self:randomInRange(3, 6)
        local startX = self:randomInRange(2, room.size.width - wallLength - 1)
        local startY = self:randomInRange(2, room.size.height - 2)
        
        for i = 0, wallLength - 1 do
            table.insert(obstacle.positions, {x = startX + i, y = startY})
        end
    elseif obstacleType == "pillar" then
        -- Create individual pillars
        local pillarCount = self:randomInRange(2, 4)
        
        for i = 1, pillarCount do
            local x = self:randomInRange(2, room.size.width - 1)
            local y = self:randomInRange(2, room.size.height - 1)
            table.insert(obstacle.positions, {x = x, y = y})
        end
    else
        -- Create a small cluster
        local clusterSize = self:randomInRange(2, 4)
        local startX = self:randomInRange(2, room.size.width - clusterSize - 1)
        local startY = self:randomInRange(2, room.size.height - clusterSize - 1)
        
        for i = 0, clusterSize - 1 do
            for j = 0, clusterSize - 1 do
                if math.random() < 0.6 then
                    table.insert(obstacle.positions, {x = startX + i, y = startY + j})
                end
            end
        end
    end
    
    return obstacle
end

-- Create a special feature
function ProceduralGeneration:createSpecialFeature(featureType, room)
    local feature = {
        type = featureType,
        category = "special",
        position = {x = 0, y = 0},
        properties = {}
    }
    
    -- Set feature properties based on type
    if featureType == "healing_fountain" then
        feature.properties = {
            healAmount = 10,
            usesRemaining = 1,
            statusEffect = nil
        }
    elseif featureType == "energy_crystal" then
        feature.properties = {
            energyAmount = 5,
            usesRemaining = 1,
            statusEffect = nil
        }
    elseif featureType == "teleporter" then
        feature.properties = {
            targetRoomId = nil, -- Set when connections are established
            isActive = true
        }
    elseif featureType == "trap" then
        feature.properties = {
            damageAmount = 5,
            statusEffect = "slowed",
            isVisible = math.random() < 0.3 -- 30% chance to be visible
        }
    elseif featureType == "shrine" then
        feature.properties = {
            effectType = self:randomSelection({"buff", "debuff", "mixed"}),
            duration = 3,
            isUsed = false
        }
    elseif featureType == "chest" then
        feature.properties = {
            isLocked = math.random() < 0.3, -- 30% chance to be locked
            trapType = math.random() < 0.2 and "damage" or nil, -- 20% chance to be trapped
            isOpen = false,
            contents = nil -- Set when rewards are added
        }
    elseif featureType == "altar" then
        feature.properties = {
            offeringType = self:randomSelection({"health", "energy", "gold"}),
            rewardType = self:randomSelection({"item", "stat", "ability"}),
            isUsed = false
        }
    elseif featureType == "shopkeeper" then
        feature.properties = {
            inventory = {}, -- Will be filled with items
            priceMultiplier = self:randomInRange(8, 12) / 10, -- 0.8 to 1.2
            specialOffer = math.random() < 0.3 -- 30% chance for special offer
        }
    end
    
    -- Place the feature in a suitable location
    local x, y = self:findSuitableLocation(room.grid)
    feature.position = {x = x, y = y}
    
    return feature
end

-- Create a puzzle
function ProceduralGeneration:createPuzzle(puzzleType, room, difficulty)
    local difficultyLevel = self:weightedRandomSelection(self.config.puzzles.difficulties)
    
    local puzzle = {
        type = puzzleType,
        category = "puzzle",
        difficulty = difficultyLevel,
        isSolved = false,
        positions = {},
        solution = nil,
        properties = {}
    }
    
    -- Set puzzle properties based on type
    if puzzleType == "pattern_match" then
        local patternSize = 3
        if difficultyLevel == "medium" then patternSize = 4
        elseif difficultyLevel == "hard" then patternSize = 5 end
        
        puzzle.properties = {
            patternSize = patternSize,
            pattern = self:generateRandomPattern(patternSize),
            attemptsAllowed = difficultyLevel == "easy" and 3 or (difficultyLevel == "medium" and 2 or 1)
        }
    elseif puzzleType == "sequence" then
        local sequenceLength = difficultyLevel == "easy" and 4 or (difficultyLevel == "medium" and 6 or 8)
        
        puzzle.properties = {
            sequenceLength = sequenceLength,
            sequence = self:generateRandomSequence(sequenceLength),
            timeLimit = difficultyLevel == "easy" and 30 or (difficultyLevel == "medium" and 20 or 15)
        }
    elseif puzzleType == "pressure_plate" then
        local plateCount = difficultyLevel == "easy" and 3 or (difficultyLevel == "medium" and 4 or 5)
        
        puzzle.properties = {
            plateCount = plateCount,
            correctOrder = self:generateRandomOrder(plateCount),
            resetOnMistake = difficultyLevel ~= "easy"
        }
    elseif puzzleType == "chess_puzzle" then
        puzzle.properties = {
            pieceType = self:randomSelection({"king", "queen", "rook", "bishop", "knight", "pawn"}),
            moveCount = difficultyLevel == "easy" and 1 or (difficultyLevel == "medium" and 2 or 3),
            boardState = self:generateChessPuzzle(difficultyLevel)
        }
    elseif puzzleType == "mirror" then
        puzzle.properties = {
            mirrorCount = difficultyLevel == "easy" and 2 or (difficultyLevel == "medium" and 3 or 4),
            targetPositions = {},
            rotatable = difficultyLevel ~= "easy"
        }
    elseif puzzleType == "light_beam" then
        puzzle.properties = {
            sourcePosition = {x = 0, y = 0},
            targetPosition = {x = 0, y = 0},
            obstacleCount = difficultyLevel == "easy" and 2 or (difficultyLevel == "medium" and 4 or 6)
        }
    elseif puzzleType == "lock_and_key" then
        puzzle.properties = {
            keyCount = difficultyLevel == "easy" and 1 or (difficultyLevel == "medium" and 2 or 3),
            keyPositions = {},
            lockPosition = {x = 0, y = 0},
            timeLimit = difficultyLevel == "easy" and 0 or (difficultyLevel == "medium" and 30 or 20)
        }
    end
    
    -- Generate puzzle positions
    local puzzleArea = {
        startX = math.floor(room.size.width / 4),
        startY = math.floor(room.size.height / 4),
        width = math.floor(room.size.width / 2),
        height = math.floor(room.size.height / 2)
    }
    
    -- Place puzzle elements based on type
    if puzzleType == "pattern_match" or puzzleType == "chess_puzzle" then
        -- These puzzles use a grid layout
        local size = puzzle.properties.patternSize or 3
        for y = 1, size do
            for x = 1, size do
                table.insert(puzzle.positions, {
                    x = puzzleArea.startX + x,
                    y = puzzleArea.startY + y
                })
            end
        end
    elseif puzzleType == "pressure_plate" then
        -- Place pressure plates in a pattern
        local plateCount = puzzle.properties.plateCount
        for i = 1, plateCount do
            table.insert(puzzle.positions, {
                x = puzzleArea.startX + i,
                y = puzzleArea.startY + math.floor(i / 2)
            })
        end
    elseif puzzleType == "mirror" or puzzleType == "light_beam" then
        -- Place mirrors or obstacles
        local count = puzzle.properties.mirrorCount or puzzle.properties.obstacleCount
        for i = 1, count do
            table.insert(puzzle.positions, {
                x = puzzleArea.startX + i,
                y = puzzleArea.startY + i
            })
        end
        
        -- Add source and target for light beam
        if puzzleType == "light_beam" then
            puzzle.properties.sourcePosition = {
                x = puzzleArea.startX,
                y = puzzleArea.startY
            }
            puzzle.properties.targetPosition = {
                x = puzzleArea.startX + puzzleArea.width,
                y = puzzleArea.startY + puzzleArea.height
            }
        end
    elseif puzzleType == "lock_and_key" then
        -- Place keys and lock
        local keyCount = puzzle.properties.keyCount
        for i = 1, keyCount do
            local keyPos = {
                x = puzzleArea.startX + i * 2,
                y = puzzleArea.startY + i
            }
            table.insert(puzzle.positions, keyPos)
            table.insert(puzzle.properties.keyPositions, keyPos)
        end
        
        puzzle.properties.lockPosition = {
            x = puzzleArea.startX + puzzleArea.width - 1,
            y = puzzleArea.startY + puzzleArea.height - 1
        }
        table.insert(puzzle.positions, puzzle.properties.lockPosition)
    end
    
    -- Generate solution based on puzzle type
    puzzle.solution = self:generatePuzzleSolution(puzzle)
    
    return puzzle
end

-- Apply a terrain feature to the grid
function ProceduralGeneration:applyFeatureToGrid(feature, grid)
    for _, pos in ipairs(feature.positions) do
        if pos.x > 0 and pos.x <= grid.width and pos.y > 0 and pos.y <= grid.height then
            grid.cells[pos.y][pos.x].type = feature.type
            grid.cells[pos.y][pos.x].walkable = true
            grid.cells[pos.y][pos.x].feature = feature
        end
    end
end

-- Apply an obstacle to the grid
function ProceduralGeneration:applyObstacleToGrid(obstacle, grid)
    for _, pos in ipairs(obstacle.positions) do
        if pos.x > 0 and pos.x <= grid.width and pos.y > 0 and pos.y <= grid.height then
            grid.cells[pos.y][pos.x].type = obstacle.type
            grid.cells[pos.y][pos.x].walkable = not obstacle.properties.isBlocking
            grid.cells[pos.y][pos.x].feature = obstacle
        end
    end
end

-- Apply a special feature to the grid
function ProceduralGeneration:applySpecialFeatureToGrid(feature, grid)
    local pos = feature.position
    if pos.x > 0 and pos.x <= grid.width and pos.y > 0 and pos.y <= grid.height then
        grid.cells[pos.y][pos.x].type = feature.type
        grid.cells[pos.y][pos.x].walkable = true
        grid.cells[pos.y][pos.x].feature = feature
    end
end

-- Apply a puzzle to the grid
function ProceduralGeneration:applyPuzzleToGrid(puzzle, grid)
    for _, pos in ipairs(puzzle.positions) do
        if pos.x > 0 and pos.x <= grid.width and pos.y > 0 and pos.y <= grid.height then
            grid.cells[pos.y][pos.x].type = "puzzle_" .. puzzle.type
            grid.cells[pos.y][pos.x].walkable = true
            grid.cells[pos.y][pos.x].feature = puzzle
        end
    end
end

-- Add entities to a room based on its type
function ProceduralGeneration:addRoomEntities(room, floorNumber, difficulty)
    if room.type == "combat" then
        -- Add enemy formation
        local formation = self:selectEnemyFormation("basic")
        self:placeEnemyFormation(formation, room, floorNumber, difficulty)
    elseif room.type == "elite" then
        -- Add elite enemy formation
        local formation = self:selectEnemyFormation("elite")
        self:placeEnemyFormation(formation, room, floorNumber, difficulty)
    elseif room.type == "boss" then
        -- Add boss formation
        local formation = self:selectEnemyFormation("boss")
        self:placeEnemyFormation(formation, room, floorNumber, difficulty)
    elseif room.type == "shop" then
        -- Add shopkeeper
        local shopkeeper = self:createShopkeeper(floorNumber, difficulty)
        table.insert(room.entities, shopkeeper)
    end
    
    -- Add player starting position for entrance rooms
    if room.type == "entrance" then
        room.playerStartPosition = {
            x = math.floor(room.size.width / 2),
            y = room.size.height - 2
        }
    end
end

-- Select an enemy formation based on type
function ProceduralGeneration:selectEnemyFormation(formationType)
    local formations = self.config.enemyFormations[formationType]
    local formationNames = {}
    
    for name, _ in pairs(formations) do
        table.insert(formationNames, name)
    end
    
    local selectedName = self:randomSelection(formationNames)
    return {
        name = selectedName,
        type = formationType,
        units = formations[selectedName]
    }
end

-- Place an enemy formation in a room
function ProceduralGeneration:placeEnemyFormation(formation, room, floorNumber, difficulty)
    -- Calculate center position for formation
    local centerX = math.floor(room.size.width / 2)
    local centerY = math.floor(room.size.height / 3) -- Place in top third of room
    
    -- Place each unit in the formation
    for _, unitData in ipairs(formation.units) do
        local unit = self:createEnemyUnit(unitData.type, floorNumber, difficulty)
        
        -- Apply boss properties if specified
        if unitData.isBoss then
            unit.isBoss = true
            unit.level = unit.level + 2
            unit.stats.health = unit.stats.health * 2
            unit.stats.maxHealth = unit.stats.maxHealth * 2
            unit.stats.attack = unit.stats.attack * 1.5
            unit.stats.defense = unit.stats.defense * 1.5
        end
        
        -- Apply unique properties if specified
        if unitData.isUnique then
            unit.isUnique = true
            unit.name = "Shadow " .. unit.unitType:gsub("^%l", string.upper)
            unit.level = unit.level + 3
            unit.stats.health = unit.stats.health * 3
            unit.stats.maxHealth = unit.stats.maxHealth * 3
            unit.stats.attack = unit.stats.attack * 2
            unit.stats.defense = unit.stats.defense * 2
        end
        
        -- Calculate position
        unit.x = centerX + unitData.relativeX
        unit.y = centerY + unitData.relativeY
        
        -- Ensure position is within grid bounds
        if unit.x > 0 and unit.x <= room.size.width and unit.y > 0 and unit.y <= room.size.height then
            table.insert(room.entities, unit)
            
            -- Mark cell as occupied
            room.grid.cells[unit.y][unit.x].entity = unit
        end
    end
end

-- Create an enemy unit
function ProceduralGeneration:createEnemyUnit(unitType, floorNumber, difficulty)
    local unit = {
        unitType = unitType,
        faction = "enemy",
        level = floorNumber,
        stats = {
            health = 0,
            maxHealth = 0,
            attack = 0,
            defense = 0,
            energy = 0,
            maxEnergy = 0,
            moveRange = 0,
            attackRange = 0,
            initiative = 0
        },
        abilities = {},
        statusEffects = {},
        x = 0,
        y = 0
    }
    
    -- Set base stats based on unit type
    if unitType == "pawn" then
        unit.stats.health = 15
        unit.stats.maxHealth = 15
        unit.stats.attack = 5
        unit.stats.defense = 3
        unit.stats.energy = 5
        unit.stats.maxEnergy = 5
        unit.stats.moveRange = 1
        unit.stats.attackRange = 1
        unit.stats.initiative = 3
        unit.abilities = {"corrupted_strike"}
    elseif unitType == "knight" then
        unit.stats.health = 20
        unit.stats.maxHealth = 20
        unit.stats.attack = 7
        unit.stats.defense = 4
        unit.stats.energy = 8
        unit.stats.maxEnergy = 8
        unit.stats.moveRange = 2
        unit.stats.attackRange = 1
        unit.stats.initiative = 7
        unit.abilities = {"ambush", "shadow_step"}
    elseif unitType == "bishop" then
        unit.stats.health = 18
        unit.stats.maxHealth = 18
        unit.stats.attack = 6
        unit.stats.defense = 2
        unit.stats.energy = 12
        unit.stats.maxEnergy = 12
        unit.stats.moveRange = 2
        unit.stats.attackRange = 2
        unit.stats.initiative = 5
        unit.abilities = {"dark_ritual", "soul_drain"}
    elseif unitType == "rook" then
        unit.stats.health = 25
        unit.stats.maxHealth = 25
        unit.stats.attack = 8
        unit.stats.defense = 6
        unit.stats.energy = 7
        unit.stats.maxEnergy = 7
        unit.stats.moveRange = 2
        unit.stats.attackRange = 1
        unit.stats.initiative = 2
        unit.abilities = {"seismic_slam", "stone_skin"}
    elseif unitType == "queen" then
        unit.stats.health = 22
        unit.stats.maxHealth = 22
        unit.stats.attack = 9
        unit.stats.defense = 3
        unit.stats.energy = 10
        unit.stats.maxEnergy = 10
        unit.stats.moveRange = 3
        unit.stats.attackRange = 2
        unit.stats.initiative = 8
        unit.abilities = {"shadow_bolt", "drain_energy"}
    elseif unitType == "king" then
        unit.stats.health = 30
        unit.stats.maxHealth = 30
        unit.stats.attack = 10
        unit.stats.defense = 5
        unit.stats.energy = 15
        unit.stats.maxEnergy = 15
        unit.stats.moveRange = 1
        unit.stats.attackRange = 1
        unit.stats.initiative = 6
        unit.abilities = {"royal_execution", "summon_pawns", "darkness_descends"}
    end
    
    -- Scale stats based on floor number
    local floorScaling = 1 + (floorNumber - 1) * 0.2
    unit.stats.health = math.floor(unit.stats.health * floorScaling)
    unit.stats.maxHealth = math.floor(unit.stats.maxHealth * floorScaling)
    unit.stats.attack = math.floor(unit.stats.attack * floorScaling)
    unit.stats.defense = math.floor(unit.stats.defense * floorScaling)
    unit.stats.energy = math.floor(unit.stats.energy * floorScaling)
    unit.stats.maxEnergy = math.floor(unit.stats.maxEnergy * floorScaling)
    
    -- Apply difficulty modifier
    if difficulty == "easy" then
        unit.stats.health = math.floor(unit.stats.health * 0.8)
        unit.stats.maxHealth = math.floor(unit.stats.maxHealth * 0.8)
        unit.stats.attack = math.floor(unit.stats.attack * 0.8)
    elseif difficulty == "hard" then
        unit.stats.health = math.floor(unit.stats.health * 1.2)
        unit.stats.maxHealth = math.floor(unit.stats.maxHealth * 1.2)
        unit.stats.attack = math.floor(unit.stats.attack * 1.2)
        unit.stats.defense = math.floor(unit.stats.defense * 1.1)
    end
    
    return unit
end

-- Create a shopkeeper
function ProceduralGeneration:createShopkeeper(floorNumber, difficulty)
    local shopkeeper = {
        type = "shopkeeper",
        faction = "neutral",
        inventory = {},
        priceMultiplier = 1.0,
        x = 0,
        y = 0
    }
    
    -- Adjust price multiplier based on difficulty
    if difficulty == "easy" then
        shopkeeper.priceMultiplier = 0.9
    elseif difficulty == "hard" then
        shopkeeper.priceMultiplier = 1.1
    end
    
    -- Generate inventory
    local itemCount = self:randomInRange(3, 6)
    for i = 1, itemCount do
        local itemType = self:randomSelection({"weapon", "armor", "consumable", "accessory"})
        local rarity = self:weightedRandomSelection(self.config.treasures.rarities)
        
        local item = {
            name = "Shop Item " .. i,
            type = itemType,
            rarity = rarity,
            price = self:calculateItemPrice(itemType, rarity, floorNumber) * shopkeeper.priceMultiplier
        }
        
        table.insert(shopkeeper.inventory, item)
    end
    
    return shopkeeper
end

-- Add rewards to a room based on its type
function ProceduralGeneration:addRoomRewards(room, floorNumber, difficulty)
    if room.type == "combat" then
        -- Basic combat rewards
        self:addCombatRewards(room, floorNumber, difficulty, false)
    elseif room.type == "elite" then
        -- Enhanced combat rewards
        self:addCombatRewards(room, floorNumber, difficulty, true)
    elseif room.type == "boss" then
        -- Boss rewards
        self:addBossRewards(room, floorNumber, difficulty)
    elseif room.type == "treasure" then
        -- Treasure room rewards
        self:addTreasureRewards(room, floorNumber, difficulty)
    elseif room.type == "puzzle" then
        -- Puzzle rewards
        self:addPuzzleRewards(room, floorNumber, difficulty)
    end
end

-- Add rewards for combat rooms
function ProceduralGeneration:addCombatRewards(room, floorNumber, difficulty, isElite)
    local rewards = {}
    
    -- Gold reward
    local goldAmount = self:randomInRange(10, 20) * floorNumber
    if isElite then
        goldAmount = goldAmount * 1.5
    end
    
    if difficulty == "easy" then
        goldAmount = goldAmount * 1.2
    elseif difficulty == "hard" then
        goldAmount = goldAmount * 0.8
    end
    
    table.insert(rewards, {
        type = "gold",
        amount = math.floor(goldAmount)
    })
    
    -- Item reward chance
    local itemChance = isElite and 0.8 or 0.4
    if math.random() < itemChance then
        local itemType = self:randomSelection({"weapon", "armor", "consumable", "accessory"})
        local rarity = self:weightedRandomSelection(self.config.treasures.rarities)
        
        -- Elite rooms have better chance for higher rarity
        if isElite and rarity == "common" and math.random() < 0.5 then
            rarity = "uncommon"
        end
        
        table.insert(rewards, {
            type = "item",
            itemType = itemType,
            rarity = rarity
        })
    end
    
    -- Experience reward
    local expAmount = isElite and 50 * floorNumber or 25 * floorNumber
    
    table.insert(rewards, {
        type = "experience",
        amount = expAmount
    })
    
    room.rewards = rewards
end

-- Add rewards for boss rooms
function ProceduralGeneration:addBossRewards(room, floorNumber, difficulty)
    local rewards = {}
    
    -- Guaranteed gold reward
    local goldAmount = self:randomInRange(50, 100) * floorNumber
    
    if difficulty == "easy" then
        goldAmount = goldAmount * 1.2
    elseif difficulty == "hard" then
        goldAmount = goldAmount * 0.8
    end
    
    table.insert(rewards, {
        type = "gold",
        amount = math.floor(goldAmount)
    })
    
    -- Guaranteed item reward
    local itemTypes = {"weapon", "armor", "accessory"}
    local itemType = self:randomSelection(itemTypes)
    local rarity = "rare"
    
    -- Final boss gives legendary item
    if floorNumber == self:getMaxFloors(difficulty) then
        rarity = "legendary"
    end
    
    table.insert(rewards, {
        type = "item",
        itemType = itemType,
        rarity = rarity
    })
    
    -- Skill point reward
    table.insert(rewards, {
        type = "skill_point",
        amount = 1
    })
    
    -- Large experience reward
    local expAmount = 100 * floorNumber
    
    table.insert(rewards, {
        type = "experience",
        amount = expAmount
    })
    
    room.rewards = rewards
end

-- Add rewards for treasure rooms
function ProceduralGeneration:addTreasureRewards(room, floorNumber, difficulty)
    local rewards = {}
    
    -- Guaranteed gold reward
    local goldAmount = self:randomInRange(30, 60) * floorNumber
    
    if difficulty == "easy" then
        goldAmount = goldAmount * 1.2
    elseif difficulty == "hard" then
        goldAmount = goldAmount * 0.8
    end
    
    table.insert(rewards, {
        type = "gold",
        amount = math.floor(goldAmount)
    })
    
    -- Multiple item rewards
    local itemCount = self:randomInRange(1, 3)
    for i = 1, itemCount do
        local itemType = self:randomSelection({"weapon", "armor", "consumable", "accessory"})
        local rarity = self:weightedRandomSelection(self.config.treasures.rarities)
        
        -- Treasure rooms have better chance for higher rarity
        if rarity == "common" and math.random() < 0.6 then
            rarity = "uncommon"
        end
        
        table.insert(rewards, {
            type = "item",
            itemType = itemType,
            rarity = rarity
        })
    end
    
    -- Chance for skill point
    if math.random() < 0.2 then
        table.insert(rewards, {
            type = "skill_point",
            amount = 1
        })
    end
    
    room.rewards = rewards
end

-- Add rewards for puzzle rooms
function ProceduralGeneration:addPuzzleRewards(room, floorNumber, difficulty)
    local rewards = {}
    local puzzleDifficulty = "medium"
    
    -- Find the puzzle to determine its difficulty
    for _, feature in ipairs(room.features) do
        if feature.category == "puzzle" then
            puzzleDifficulty = feature.difficulty
            break
        end
    end
    
    -- Reward multiplier based on puzzle difficulty
    local multiplier = self.config.puzzles.rewardsMultiplier[puzzleDifficulty]
    
    -- Gold reward
    local goldAmount = self:randomInRange(20, 40) * floorNumber * multiplier
    
    if difficulty == "easy" then
        goldAmount = goldAmount * 1.2
    elseif difficulty == "hard" then
        goldAmount = goldAmount * 0.8
    end
    
    table.insert(rewards, {
        type = "gold",
        amount = math.floor(goldAmount)
    })
    
    -- Item reward
    local itemType = self:randomSelection({"weapon", "armor", "consumable", "accessory"})
    local rarity = self:weightedRandomSelection(self.config.treasures.rarities)
    
    -- Hard puzzles have better chance for higher rarity
    if puzzleDifficulty == "hard" and rarity == "common" then
        rarity = "uncommon"
    elseif puzzleDifficulty == "hard" and rarity == "uncommon" and math.random() < 0.3 then
        rarity = "rare"
    end
    
    table.insert(rewards, {
        type = "item",
        itemType = itemType,
        rarity = rarity
    })
    
    -- Experience reward
    local expAmount = 30 * floorNumber * multiplier
    
    table.insert(rewards, {
        type = "experience",
        amount = math.floor(expAmount)
    })
    
    room.rewards = rewards
end

-- Generate connections between rooms
function ProceduralGeneration:generateConnections(rooms)
    local connections = {}
    
    -- Sort rooms by position
    table.sort(rooms, function(a, b)
        return a.position.x < b.position.x
    end)
    
    -- Connect rooms in sequence
    for i = 1, #rooms - 1 do
        table.insert(connections, {
            from = rooms[i].id,
            to = rooms[i + 1].id,
            isLocked = false
        })
    end
    
    -- Add some additional connections for more complex layouts
    local additionalConnections = math.floor(#rooms / 4)
    for i = 1, additionalConnections do
        local fromIndex = self:randomInRange(1, #rooms - 2)
        local toIndex = fromIndex + 2
        
        if toIndex <= #rooms then
            table.insert(connections, {
                from = rooms[fromIndex].id,
                to = rooms[toIndex].id,
                isLocked = math.random() < 0.3 -- 30% chance to be locked
            })
        end
    end
    
    return connections
end

-- Find a suitable location in a grid
function ProceduralGeneration:findSuitableLocation(grid)
    local attempts = 0
    local maxAttempts = 50
    
    while attempts < maxAttempts do
        local x = self:randomInRange(2, grid.width - 1)
        local y = self:randomInRange(2, grid.height - 1)
        
        -- Check if cell is suitable (floor type and no entity or feature)
        if grid.cells[y][x].type == "floor" and 
           grid.cells[y][x].walkable and
           not grid.cells[y][x].entity and
           not grid.cells[y][x].feature then
            return x, y
        end
        
        attempts = attempts + 1
    end
    
    -- If no suitable location found, return center of grid
    return math.floor(grid.width / 2), math.floor(grid.height / 2)
end

-- Calculate item price based on type, rarity, and floor
function ProceduralGeneration:calculateItemPrice(itemType, rarity, floorNumber)
    local basePrice = 0
    
    -- Base price by item type
    if itemType == "weapon" then
        basePrice = 50
    elseif itemType == "armor" then
        basePrice = 40
    elseif itemType == "accessory" then
        basePrice = 60
    elseif itemType == "consumable" then
        basePrice = 20
    end
    
    -- Rarity multiplier
    local rarityMultiplier = 1
    if rarity == "uncommon" then
        rarityMultiplier = 2
    elseif rarity == "rare" then
        rarityMultiplier = 4
    elseif rarity == "legendary" then
        rarityMultiplier = 10
    end
    
    -- Floor scaling
    local floorScaling = 1 + (floorNumber - 1) * 0.2
    
    return math.floor(basePrice * rarityMultiplier * floorScaling)
end

-- Generate a random pattern for pattern match puzzles
function ProceduralGeneration:generateRandomPattern(size)
    local pattern = {}
    
    for y = 1, size do
        pattern[y] = {}
        for x = 1, size do
            pattern[y][x] = math.random(0, 1)
        end
    end
    
    return pattern
end

-- Generate a random sequence for sequence puzzles
function ProceduralGeneration:generateRandomSequence(length)
    local sequence = {}
    
    for i = 1, length do
        table.insert(sequence, math.random(1, 4))
    end
    
    return sequence
end

-- Generate a random order for pressure plate puzzles
function ProceduralGeneration:generateRandomOrder(count)
    local order = {}
    
    for i = 1, count do
        table.insert(order, i)
    end
    
    -- Shuffle the order
    for i = #order, 2, -1 do
        local j = math.random(i)
        order[i], order[j] = order[j], order[i]
    end
    
    return order
end

-- Generate a chess puzzle
function ProceduralGeneration:generateChessPuzzle(difficulty)
    local boardState = {}
    
    -- Create empty board
    for y = 1, 8 do
        boardState[y] = {}
        for x = 1, 8 do
            boardState[y][x] = nil
        end
    end
    
    -- Add pieces based on difficulty
    local pieceCount = difficulty == "easy" and 4 or (difficulty == "medium" and 6 or 8)
    
    -- Always add player piece
    boardState[7][4] = {type = "king", faction = "player"}
    
    -- Add enemy pieces
    local enemyTypes = {"pawn", "knight", "bishop", "rook", "queen"}
    for i = 1, pieceCount - 1 do
        local pieceType = self:randomSelection(enemyTypes)
        local x, y
        
        -- Find empty position
        repeat
            x = math.random(1, 8)
            y = math.random(1, 6) -- Keep enemies in top 6 rows
        until not boardState[y][x]
        
        boardState[y][x] = {type = pieceType, faction = "enemy"}
    end
    
    return boardState
end

-- Generate a puzzle solution
function ProceduralGeneration:generatePuzzleSolution(puzzle)
    local solution = {}
    
    if puzzle.type == "pattern_match" then
        -- Solution is the pattern itself
        solution = puzzle.properties.pattern
    elseif puzzle.type == "sequence" then
        -- Solution is the sequence
        solution = puzzle.properties.sequence
    elseif puzzle.type == "pressure_plate" then
        -- Solution is the correct order
        solution = puzzle.properties.correctOrder
    elseif puzzle.type == "chess_puzzle" then
        -- Solution is a series of moves
        solution = self:generateChessPuzzleSolution(puzzle.properties.boardState, puzzle.properties.pieceType, puzzle.properties.moveCount)
    elseif puzzle.type == "mirror" then
        -- Solution is mirror positions and rotations
        solution = self:generateMirrorPuzzleSolution(puzzle.properties.mirrorCount)
    elseif puzzle.type == "light_beam" then
        -- Solution is obstacle positions
        solution = self:generateLightBeamPuzzleSolution(puzzle.properties.sourcePosition, puzzle.properties.targetPosition, puzzle.properties.obstacleCount)
    elseif puzzle.type == "lock_and_key" then
        -- Solution is the path to collect keys and reach lock
        solution = self:generateLockAndKeySolution(puzzle.properties.keyPositions, puzzle.properties.lockPosition)
    end
    
    return solution
end

-- Generate a solution for chess puzzles
function ProceduralGeneration:generateChessPuzzleSolution(boardState, pieceType, moveCount)
    -- This would be a complex chess engine implementation
    -- For now, we'll just return a placeholder solution
    local solution = {}
    
    for i = 1, moveCount do
        table.insert(solution, {
            from = {x = 4, y = 7},
            to = {x = 4 - i, y = 7 - i}
        })
    end
    
    return solution
end

-- Generate a solution for mirror puzzles
function ProceduralGeneration:generateMirrorPuzzleSolution(mirrorCount)
    local solution = {}
    
    for i = 1, mirrorCount do
        table.insert(solution, {
            position = {x = i * 2, y = i * 2},
            rotation = math.random(0, 3) * 90 -- 0, 90, 180, or 270 degrees
        })
    end
    
    return solution
end

-- Generate a solution for light beam puzzles
function ProceduralGeneration:generateLightBeamPuzzleSolution(sourcePosition, targetPosition, obstacleCount)
    local solution = {}
    
    for i = 1, obstacleCount do
        table.insert(solution, {
            position = {x = i * 2, y = i},
            type = self:randomSelection({"mirror", "prism", "blocker"})
        })
    end
    
    return solution
end

-- Generate a solution for lock and key puzzles
function ProceduralGeneration:generateLockAndKeySolution(keyPositions, lockPosition)
    local solution = {}
    
    -- Sort keys by distance to make a logical path
    table.sort(keyPositions, function(a, b)
        local distA = math.abs(a.x - lockPosition.x) + math.abs(a.y - lockPosition.y)
        local distB = math.abs(b.x - lockPosition.x) + math.abs(b.y - lockPosition.y)
        return distA > distB
    end)
    
    -- Add keys to solution in order
    for _, keyPos in ipairs(keyPositions) do
        table.insert(solution, keyPos)
    end
    
    -- Add lock as final destination
    table.insert(solution, lockPosition)
    
    return solution
end

-- Get maximum number of floors based on difficulty
function ProceduralGeneration:getMaxFloors(difficulty)
    if difficulty == "easy" then
        return self.config.dungeon.minFloors
    elseif difficulty == "hard" then
        return self.config.dungeon.maxFloors
    else
        return math.floor((self.config.dungeon.minFloors + self.config.dungeon.maxFloors) / 2)
    end
end

-- Utility function: Get random number in range
function ProceduralGeneration:randomInRange(min, max)
    return math.floor(math.random() * (max - min + 1)) + min
end

-- Utility function: Get random selection from table
function ProceduralGeneration:randomSelection(table)
    return table[math.random(1, #table)]
end

-- Utility function: Get weighted random selection
function ProceduralGeneration:weightedRandomSelection(weightTable)
    local totalWeight = 0
    for item, weight in pairs(weightTable) do
        totalWeight = totalWeight + weight
    end
    
    local randomValue = math.random() * totalWeight
    local currentWeight = 0
    
    for item, weight in pairs(weightTable) do
        currentWeight = currentWeight + weight
        if randomValue <= currentWeight then
            return item
        end
    end
    
    -- Fallback (should never reach here)
    local items = {}
    for item, _ in pairs(weightTable) do
        table.insert(items, item)
    end
    return items[1]
end

-- Save the current dungeon to a file
function ProceduralGeneration:saveDungeon(filename)
    -- This would serialize the dungeon to a file
    -- For now, we'll just return success
    return true
end

-- Load a dungeon from a file
function ProceduralGeneration:loadDungeon(filename)
    -- This would deserialize a dungeon from a file
    -- For now, we'll just return nil
    return nil
end

-- Get a specific room by ID
function ProceduralGeneration:getRoomById(roomId)
    if not self.currentDungeon then
        return nil
    end
    
    for _, floor in ipairs(self.currentDungeon.floors) do
        for _, room in ipairs(floor.rooms) do
            if room.id == roomId then
                return room
            end
        end
    end
    
    return nil
end

-- Get connected rooms
function ProceduralGeneration:getConnectedRooms(roomId)
    if not self.currentDungeon then
        return {}
    end
    
    local connectedRooms = {}
    
    for _, floor in ipairs(self.currentDungeon.floors) do
        for _, connection in ipairs(floor.connections) do
            if connection.from == roomId then
                table.insert(connectedRooms, self:getRoomById(connection.to))
            elseif connection.to == roomId then
                table.insert(connectedRooms, self:getRoomById(connection.from))
            end
        end
    end
    
    return connectedRooms
end

-- Mark a room as cleared
function ProceduralGeneration:markRoomCleared(roomId)
    local room = self:getRoomById(roomId)
    if room then
        room.isCleared = true
        self.currentDungeon.clearedRooms = self.currentDungeon.clearedRooms + 1
        
        -- Check if floor is cleared
        local floorNumber = math.floor(roomId / 100)
        local floor = self.currentDungeon.floors[floorNumber]
        
        if floor then
            local allCleared = true
            for _, r in ipairs(floor.rooms) do
                if not r.isCleared then
                    allCleared = false
                    break
                end
            end
            
            floor.isCleared = allCleared
        end
        
        return true
    end
    
    return false
end

-- Check if dungeon is completed
function ProceduralGeneration:isDungeonCompleted()
    if not self.currentDungeon then
        return false
    end
    
    -- Check if final floor's boss room is cleared
    local finalFloor = self.currentDungeon.floors[#self.currentDungeon.floors]
    
    for _, room in ipairs(finalFloor.rooms) do
        if room.type == "boss" and room.isCleared then
            return true
        end
    end
    
    return false
end

-- Generate a visualization of the dungeon (for debugging)
function ProceduralGeneration:visualizeDungeon()
    if not self.currentDungeon then
        return "No dungeon generated"
    end
    
    local visualization = "Dungeon Visualization (Seed: " .. self.currentDungeon.seed .. ")\n\n"
    
    for i, floor in ipairs(self.currentDungeon.floors) do
        visualization = visualization .. "Floor " .. i .. (floor.isBossFloor and " (Boss Floor)" or "") .. ":\n"
        
        -- Create a map of room positions
        local roomMap = {}
        for _, room in ipairs(floor.rooms) do
            local key = room.position.x .. "," .. room.position.y
            roomMap[key] = room
        end
        
        -- Find min/max coordinates
        local minX, maxX, minY, maxY = 999, -999, 999, -999
        for _, room in ipairs(floor.rooms) do
            minX = math.min(minX, room.position.x)
            maxX = math.max(maxX, room.position.x)
            minY = math.min(minY, room.position.y)
            maxY = math.max(maxY, room.position.y)
        end
        
        -- Draw the floor
        for y = minY, maxY do
            local line = ""
            for x = minX, maxX do
                local key = x .. "," .. y
                local room = roomMap[key]
                
                if room then
                    if room.type == "entrance" then
                        line = line .. "E"
                    elseif room.type == "boss" then
                        line = line .. "B"
                    elseif room.type == "elite" then
                        line = line .. "L"
                    elseif room.type == "combat" then
                        line = line .. "C"
                    elseif room.type == "treasure" then
                        line = line .. "T"
                    elseif room.type == "shop" then
                        line = line .. "S"
                    elseif room.type == "puzzle" then
                        line = line .. "P"
                    elseif room.type == "rest" then
                        line = line .. "R"
                    else
                        line = line .. "?"
                    end
                else
                    line = line .. " "
                end
            end
            visualization = visualization .. line .. "\n"
        end
        
        -- Draw connections
        visualization = visualization .. "Connections:\n"
        for _, connection in ipairs(floor.connections) do
            local fromRoom = self:getRoomById(connection.from)
            local toRoom = self:getRoomById(connection.to)
            
            if fromRoom and toRoom then
                visualization = visualization .. "  " .. fromRoom.type .. " (" .. connection.from .. ") -> " .. toRoom.type .. " (" .. connection.to .. ")"
                if connection.isLocked then
                    visualization = visualization .. " [LOCKED]"
                end
                visualization = visualization .. "\n"
            end
        end
        
        visualization = visualization .. "\n"
    end
    
    return visualization
end

return ProceduralGeneration
