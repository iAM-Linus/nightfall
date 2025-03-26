-- Gameplay Test for Nightfall Chess
-- Tests the complete gameplay loop with all integrated systems

local class = require("lib.middleclass.middleclass")

local GameplayTest = class("GameplayTest")

function GameplayTest:initialize(game)
    self.game = game
    self.testResults = {}
    self.currentTest = nil
    self.testStatus = "idle" -- idle, running, passed, failed
    self.testMessage = ""
    self.testProgress = 0
    self.totalTests = 10
    
    -- Test definitions
    self.tests = {
        {
            name = "Turn Manager Integration",
            description = "Tests if the turn manager properly handles turn transitions and action points",
            run = function() return self:testTurnManager() end
        },
        {
            name = "Combat System Integration",
            description = "Tests if the combat system properly handles attacks and damage",
            run = function() return self:testCombatSystem() end
        },
        {
            name = "Special Abilities System Integration",
            description = "Tests if special abilities can be used and have proper effects",
            run = function() return self:testSpecialAbilitiesSystem() end
        },
        {
            name = "Experience System Integration",
            description = "Tests if units gain experience and level up properly",
            run = function() return self:testExperienceSystem() end
        },
        {
            name = "Inventory System Integration",
            description = "Tests if items can be acquired, equipped, and used",
            run = function() return self:testInventorySystem() end
        },
        {
            name = "Meta Progression Integration",
            description = "Tests if meta progression unlocks and upgrades work properly",
            run = function() return self:testMetaProgressionSystem() end
        },
        {
            name = "Procedural Generation Integration",
            description = "Tests if dungeons are properly generated and can be navigated",
            run = function() return self:testProceduralGenerationSystem() end
        },
        {
            name = "Enemy AI Integration",
            description = "Tests if enemy AI makes decisions and acts appropriately",
            run = function() return self:testEnemyAISystem() end
        },
        {
            name = "Complete Gameplay Loop",
            description = "Tests a complete gameplay sequence from start to finish",
            run = function() return self:testCompleteGameplayLoop() end
        },
        {
            name = "System Interaction",
            description = "Tests interactions between multiple systems",
            run = function() return self:testSystemInteraction() end
        }
    }
end

-- Run all tests
function GameplayTest:runAllTests()
    self.testResults = {}
    
    for i, test in ipairs(self.tests) do
        self.currentTest = test
        self.testStatus = "running"
        self.testMessage = "Running test: " .. test.name
        self.testProgress = (i - 1) / self.totalTests
        
        print("Running test: " .. test.name)
        local success, message = test.run()
        
        table.insert(self.testResults, {
            name = test.name,
            description = test.description,
            success = success,
            message = message
        })
        
        if success then
            self.testStatus = "passed"
            self.testMessage = "Test passed: " .. test.name
        else
            self.testStatus = "failed"
            self.testMessage = "Test failed: " .. test.name .. " - " .. message
        end
        
        self.testProgress = i / self.totalTests
        print(self.testMessage)
    end
    
    self.currentTest = nil
    self.testStatus = "idle"
    self.testMessage = "All tests completed"
    self.testProgress = 1
    
    return self:generateTestReport()
end

-- Run a specific test
function GameplayTest:runTest(testName)
    for i, test in ipairs(self.tests) do
        if test.name == testName then
            self.currentTest = test
            self.testStatus = "running"
            self.testMessage = "Running test: " .. test.name
            self.testProgress = 0
            
            print("Running test: " .. test.name)
            local success, message = test.run()
            
            local result = {
                name = test.name,
                description = test.description,
                success = success,
                message = message
            }
            
            if success then
                self.testStatus = "passed"
                self.testMessage = "Test passed: " .. test.name
            else
                self.testStatus = "failed"
                self.testMessage = "Test failed: " .. test.name .. " - " .. message
            end
            
            self.testProgress = 1
            print(self.testMessage)
            
            self.currentTest = nil
            return result
        end
    end
    
    return {
        name = testName,
        description = "Test not found",
        success = false,
        message = "Test not found: " .. testName
    }
end

-- Generate test report
function GameplayTest:generateTestReport()
    local report = {
        totalTests = #self.testResults,
        passedTests = 0,
        failedTests = 0,
        results = self.testResults
    }
    
    for _, result in ipairs(self.testResults) do
        if result.success then
            report.passedTests = report.passedTests + 1
        else
            report.failedTests = report.failedTests + 1
        end
    end
    
    report.success = (report.failedTests == 0)
    
    return report
end

-- Test Turn Manager Integration
function GameplayTest:testTurnManager()
    local success = true
    local message = "Turn Manager Integration test passed"
    
    -- Create test environment
    local turnManager = self.game.turnManager
    if not turnManager then
        return false, "Turn Manager not found"
    end
    
    -- Test 1: Turn initialization
    if turnManager.currentTurn ~= 1 then
        success = false
        message = "Turn Manager not properly initialized"
        return success, message
    end
    
    -- Test 2: Action points
    local testUnit = {
        id = "test_unit",
        stats = {
            actionPoints = 0,
            maxActionPoints = 3
        }
    }
    
    turnManager:registerUnit(testUnit)
    turnManager:startTurn()
    
    if testUnit.stats.actionPoints ~= testUnit.stats.maxActionPoints then
        success = false
        message = "Action points not properly reset on turn start"
        return success, message
    end
    
    -- Test 3: Turn phases
    if turnManager.currentPhase ~= "player" then
        success = false
        message = "Turn phase not properly initialized"
        return success, message
    end
    
    turnManager:endPhase()
    
    if turnManager.currentPhase ~= "enemy" then
        success = false
        message = "Turn phase not properly transitioning"
        return success, message
    end
    
    -- Test 4: Turn callbacks
    local callbackCalled = false
    turnManager:registerCallback("onTurnEnd", function()
        callbackCalled = true
    end)
    
    turnManager:endPhase() -- Should end the turn
    
    if not callbackCalled then
        success = false
        message = "Turn callbacks not properly triggered"
        return success, message
    end
    
    -- Test 5: Turn counter
    if turnManager.currentTurn ~= 2 then
        success = false
        message = "Turn counter not properly incremented"
        return success, message
    end
    
    return success, message
end

-- Test Combat System Integration
function GameplayTest:testCombatSystem()
    local success = true
    local message = "Combat System Integration test passed"
    
    -- Create test environment
    local combatSystem = self.game.combatSystem
    if not combatSystem then
        return false, "Combat System not found"
    end
    
    -- Test 1: Attack calculation
    local attacker = {
        id = "attacker",
        unitType = "knight",
        stats = {
            attack = 10,
            critChance = 0.1
        }
    }
    
    local defender = {
        id = "defender",
        unitType = "pawn",
        stats = {
            health = 20,
            maxHealth = 20,
            defense = 5
        }
    }
    
    local attackResult = combatSystem:calculateAttack(attacker, defender)
    
    if not attackResult or not attackResult.damage or attackResult.damage <= 0 then
        success = false
        message = "Attack calculation not working properly"
        return success, message
    end
    
    -- Test 2: Damage application
    local originalHealth = defender.stats.health
    combatSystem:applyDamage(defender, attackResult.damage)
    
    if defender.stats.health >= originalHealth then
        success = false
        message = "Damage not properly applied"
        return success, message
    end
    
    -- Test 3: Critical hits
    -- Force a critical hit
    attacker.stats.critChance = 1.0
    attackResult = combatSystem:calculateAttack(attacker, defender, true)
    
    if not attackResult.isCritical then
        success = false
        message = "Critical hit system not working properly"
        return success, message
    end
    
    -- Test 4: Miss chance
    -- Force a miss
    combatSystem.forceMiss = true
    attackResult = combatSystem:calculateAttack(attacker, defender)
    combatSystem.forceMiss = false
    
    if not attackResult.isMiss then
        success = false
        message = "Miss chance system not working properly"
        return success, message
    end
    
    -- Test 5: Death handling
    defender.stats.health = 1
    combatSystem:applyDamage(defender, 10)
    
    if defender.stats.health > 0 then
        success = false
        message = "Death handling not working properly"
        return success, message
    end
    
    return success, message
end

-- Test Special Abilities System Integration
function GameplayTest:testSpecialAbilitiesSystem()
    local success = true
    local message = "Special Abilities System Integration test passed"
    
    -- Create test environment
    local specialAbilitiesSystem = self.game.specialAbilitiesSystem
    if not specialAbilitiesSystem then
        return false, "Special Abilities System not found"
    end
    
    -- Test 1: Ability registration
    local testAbility = {
        id = "test_ability",
        name = "Test Ability",
        description = "A test ability",
        energyCost = 10,
        cooldown = 3,
        targetType = "enemy",
        range = 3,
        effect = function(caster, target)
            if target then
                target.stats.health = target.stats.health - 5
                return true
            end
            return false
        end
    }
    
    specialAbilitiesSystem:registerAbility(testAbility)
    
    local retrievedAbility = specialAbilitiesSystem:getAbility("test_ability")
    if not retrievedAbility or retrievedAbility.name ~= "Test Ability" then
        success = false
        message = "Ability registration not working properly"
        return success, message
    end
    
    -- Test 2: Ability usage
    local caster = {
        id = "caster",
        unitType = "bishop",
        stats = {
            energy = 20,
            maxEnergy = 30
        },
        abilities = {"test_ability"},
        abilityCooldowns = {}
    }
    
    local target = {
        id = "target",
        unitType = "pawn",
        stats = {
            health = 20,
            maxHealth = 20
        }
    }
    
    local useResult = specialAbilitiesSystem:useAbility(caster, "test_ability", target)
    
    if not useResult.success then
        success = false
        message = "Ability usage not working properly: " .. (useResult.message or "Unknown error")
        return success, message
    end
    
    -- Test 3: Energy cost
    if caster.stats.energy ~= 10 then
        success = false
        message = "Ability energy cost not properly applied"
        return success, message
    end
    
    -- Test 4: Cooldown
    if not caster.abilityCooldowns["test_ability"] or caster.abilityCooldowns["test_ability"] ~= 3 then
        success = false
        message = "Ability cooldown not properly applied"
        return success, message
    end
    
    -- Test 5: Effect application
    if target.stats.health ~= 15 then
        success = false
        message = "Ability effect not properly applied"
        return success, message
    end
    
    return success, message
end

-- Test Experience System Integration
function GameplayTest:testExperienceSystem()
    local success = true
    local message = "Experience System Integration test passed"
    
    -- Create test environment
    local experienceSystem = self.game.experienceSystem
    if not experienceSystem then
        return false, "Experience System not found"
    end
    
    -- Test 1: Experience gain
    local unit = {
        id = "test_unit",
        unitType = "knight",
        level = 1,
        experience = 0,
        experienceToNextLevel = 100,
        stats = {
            attack = 10,
            defense = 5,
            health = 20,
            maxHealth = 20
        }
    }
    
    experienceSystem:addExperience(unit, 50)
    
    if unit.experience ~= 50 then
        success = false
        message = "Experience gain not working properly"
        return success, message
    end
    
    -- Test 2: Level up
    experienceSystem:addExperience(unit, 50)
    
    if unit.level ~= 2 then
        success = false
        message = "Level up not working properly"
        return success, message
    end
    
    -- Test 3: Stat growth
    if unit.stats.attack <= 10 or unit.stats.defense <= 5 or unit.stats.maxHealth <= 20 then
        success = false
        message = "Stat growth not working properly"
        return success, message
    end
    
    -- Test 4: Experience reset
    if unit.experience ~= 0 then
        success = false
        message = "Experience reset after level up not working properly"
        return success, message
    end
    
    -- Test 5: Experience scaling
    local enemy = {
        id = "enemy",
        unitType = "pawn",
        level = 1
    }
    
    local expReward = experienceSystem:calculateExperienceReward(enemy)
    
    enemy.level = 2
    local higherExpReward = experienceSystem:calculateExperienceReward(enemy)
    
    if higherExpReward <= expReward then
        success = false
        message = "Experience scaling not working properly"
        return success, message
    end
    
    return success, message
end

-- Test Inventory System Integration
function GameplayTest:testInventorySystem()
    local success = true
    local message = "Inventory System Integration test passed"
    
    -- Create test environment
    local inventoryManager = self.game.inventoryManager
    if not inventoryManager then
        return false, "Inventory Manager not found"
    end
    
    -- Test 1: Item creation
    local testItem = {
        id = "test_item",
        name = "Test Item",
        description = "A test item",
        type = "weapon",
        rarity = "common",
        stats = {
            attack = 5
        }
    }
    
    inventoryManager:registerItemTemplate(testItem)
    
    local createdItem = inventoryManager:createItem("test_item")
    if not createdItem or createdItem.name ~= "Test Item" then
        success = false
        message = "Item creation not working properly"
        return success, message
    end
    
    -- Test 2: Add item to inventory
    inventoryManager:addItem(createdItem)
    
    local items = inventoryManager:getItems()
    local found = false
    for _, item in ipairs(items) do
        if item.id == createdItem.id then
            found = true
            break
        end
    end
    
    if not found then
        success = false
        message = "Adding item to inventory not working properly"
        return success, message
    end
    
    -- Test 3: Equip item
    local unit = {
        id = "test_unit",
        unitType = "knight",
        equipment = {},
        stats = {
            attack = 10
        }
    }
    
    local equipResult = inventoryManager:equipItem(unit, createdItem)
    
    if not equipResult.success then
        success = false
        message = "Equipping item not working properly: " .. (equipResult.message or "Unknown error")
        return success, message
    end
    
    -- Test 4: Stat modification
    if unit.stats.attack ~= 15 then
        success = false
        message = "Item stat modification not working properly"
        return success, message
    end
    
    -- Test 5: Unequip item
    local unequipResult = inventoryManager:unequipItem(unit, "weapon")
    
    if not unequipResult.success then
        success = false
        message = "Unequipping item not working properly: " .. (unequipResult.message or "Unknown error")
        return success, message
    end
    
    if unit.stats.attack ~= 10 then
        success = false
        message = "Item stat removal not working properly"
        return success, message
    end
    
    return success, message
end

-- Test Meta Progression System Integration
function GameplayTest:testMetaProgressionSystem()
    local success = true
    local message = "Meta Progression System Integration test passed"
    
    -- Create test environment
    local metaProgression = self.game.metaProgression
    if not metaProgression then
        return false, "Meta Progression System not found"
    end
    
    -- Test 1: Currency management
    local initialCurrency = metaProgression:getCurrency()
    metaProgression:addCurrency(100)
    
    if metaProgression:getCurrency() ~= initialCurrency + 100 then
        success = false
        message = "Currency management not working properly"
        return success, message
    end
    
    -- Test 2: Upgrade purchase
    local testUpgrade = {
        id = "test_upgrade",
        name = "Test Upgrade",
        description = "A test upgrade",
        cost = 50,
        maxLevel = 3,
        effect = function(level)
            return {
                statBonus = level * 5
            }
        end
    }
    
    metaProgression:registerUpgrade(testUpgrade)
    
    local purchaseResult = metaProgression:purchaseUpgrade("test_upgrade")
    
    if not purchaseResult.success then
        success = false
        message = "Upgrade purchase not working properly: " .. (purchaseResult.message or "Unknown error")
        return success, message
    end
    
    -- Test 3: Currency deduction
    if metaProgression:getCurrency() ~= initialCurrency + 50 then
        success = false
        message = "Currency deduction not working properly"
        return success, message
    end
    
    -- Test 4: Upgrade level
    if metaProgression:getUpgradeLevel("test_upgrade") ~= 1 then
        success = false
        message = "Upgrade level tracking not working properly"
        return success, message
    end
    
    -- Test 5: Upgrade effect
    local upgradeEffect = metaProgression:getUpgradeEffect("test_upgrade")
    
    if not upgradeEffect or upgradeEffect.statBonus ~= 5 then
        success = false
        message = "Upgrade effect not working properly"
        return success, message
    end
    
    return success, message
end

-- Test Procedural Generation System Integration
function GameplayTest:testProceduralGenerationSystem()
    local success = true
    local message = "Procedural Generation System Integration test passed"
    
    -- Create test environment
    local proceduralGeneration = self.game.proceduralGeneration
    if not proceduralGeneration then
        return false, "Procedural Generation System not found"
    end
    
    -- Test 1: Dungeon generation
    local dungeon = proceduralGeneration:generateDungeon("normal")
    
    if not dungeon or not dungeon.rooms or #dungeon.rooms == 0 then
        success = false
        message = "Dungeon generation not working properly"
        return success, message
    end
    
    -- Test 2: Room connections
    if not dungeon.connections or #dungeon.connections == 0 then
        success = false
        message = "Room connections not generated properly"
        return success, message
    end
    
    -- Test 3: Room types
    local roomTypes = {}
    for _, room in ipairs(dungeon.rooms) do
        roomTypes[room.type] = true
    end
    
    if not (roomTypes["combat"] and roomTypes["treasure"]) then
        success = false
        message = "Room type variety not working properly"
        return success, message
    end
    
    -- Test 4: Room clearing
    local firstRoom = dungeon.rooms[1]
    proceduralGeneration:markRoomCleared(firstRoom.id)
    
    local updatedRoom = proceduralGeneration:getRoomById(firstRoom.id)
    if not updatedRoom.cleared then
        success = false
        message = "Room clearing not working properly"
        return success, message
    end
    
    -- Test 5: Room accessibility
    local connections = proceduralGeneration:getConnectedRooms(firstRoom.id)
    
    if #connections == 0 then
        success = false
        message = "Room connections not working properly"
        return success, message
    end
    
    local connectedRoom = connections[1]
    if not proceduralGeneration:isRoomAccessible(connectedRoom.id) then
        success = false
        message = "Room accessibility not working properly"
        return success, message
    end
    
    return success, message
end

-- Test Enemy AI System Integration
function GameplayTest:testEnemyAISystem()
    local success = true
    local message = "Enemy AI System Integration test passed"
    
    -- Create test environment
    local enemyAI = self.game.enemyAI
    if not enemyAI then
        return false, "Enemy AI System not found"
    end
    
    -- Test 1: AI type assignment
    local testUnit = {
        id = "test_unit",
        unitType = "knight",
        faction = "enemy",
        x = 5,
        y = 5,
        stats = {
            health = 20,
            maxHealth = 20,
            attack = 10,
            defense = 5,
            actionPoints = 3,
            maxActionPoints = 3
        }
    }
    
    local aiType = enemyAI:getAITypeForUnit(testUnit)
    
    if not aiType or aiType == "" then
        success = false
        message = "AI type assignment not working properly"
        return success, message
    end
    
    -- Test 2: Decision making
    local grid = {
        width = 10,
        height = 10,
        getEntity = function(x, y)
            if x == 7 and y == 5 then
                return {
                    id = "player_unit",
                    unitType = "pawn",
                    faction = "player",
                    x = 7,
                    y = 5,
                    stats = {
                        health = 15,
                        maxHealth = 15
                    }
                }
            end
            return nil
        end,
        isWalkable = function(x, y)
            return x >= 1 and x <= 10 and y >= 1 and y <= 10
        end
    }
    
    local decision = enemyAI:makeDecision(testUnit, aiType, grid)
    
    if not decision or not decision.type then
        success = false
        message = "AI decision making not working properly"
        return success, message
    end
    
    -- Test 3: Threat map
    enemyAI:updateThreatMap(grid)
    
    if not enemyAI.threatMap then
        success = false
        message = "Threat map generation not working properly"
        return success, message
    end
    
    -- Test 4: Opportunity map
    enemyAI:updateOpportunityMap(grid)
    
    if not enemyAI.opportunityMap then
        success = false
        message = "Opportunity map generation not working properly"
        return success, message
    end
    
    -- Test 5: Tactical planning
    enemyAI.activeEnemies = {testUnit}
    enemyAI:generateTacticalPlans()
    
    if not enemyAI.tacticalPlans then
        success = false
        message = "Tactical planning not working properly"
        return success, message
    end
    
    return success, message
end

-- Test Complete Gameplay Loop
function GameplayTest:testCompleteGameplayLoop()
    local success = true
    local message = "Complete Gameplay Loop test passed"
    
    -- This test simulates a complete gameplay loop
    -- from dungeon generation to combat to rewards
    
    -- Step 1: Generate dungeon
    local proceduralGeneration = self.game.proceduralGeneration
    if not proceduralGeneration then
        return false, "Procedural Generation System not found"
    end
    
    local dungeon = proceduralGeneration:generateDungeon("normal")
    
    if not dungeon or not dungeon.rooms or #dungeon.rooms == 0 then
        success = false
        message = "Dungeon generation failed"
        return success, message
    end
    
    -- Step 2: Initialize player units
    local playerUnits = {
        {
            id = "player_knight",
            unitType = "knight",
            faction = "player",
            x = 3,
            y = 3,
            level = 1,
            experience = 0,
            experienceToNextLevel = 100,
            abilities = {"knight's_charge", "feint"},
            abilityCooldowns = {},
            equipment = {},
            stats = {
                health = 30,
                maxHealth = 30,
                attack = 12,
                defense = 8,
                actionPoints = 0,
                maxActionPoints = 3,
                energy = 20,
                maxEnergy = 20
            }
        }
    }
    
    -- Step 3: Initialize enemy units
    local enemyUnits = {
        {
            id = "enemy_pawn",
            unitType = "pawn",
            faction = "enemy",
            x = 6,
            y = 3,
            level = 1,
            abilities = {"shield_bash"},
            abilityCooldowns = {},
            stats = {
                health = 20,
                maxHealth = 20,
                attack = 8,
                defense = 5,
                actionPoints = 0,
                maxActionPoints = 2,
                energy = 10,
                maxEnergy = 10
            }
        }
    }
    
    -- Step 4: Initialize turn manager
    local turnManager = self.game.turnManager
    if not turnManager then
        return false, "Turn Manager not found"
    end
    
    turnManager:reset()
    
    for _, unit in ipairs(playerUnits) do
        turnManager:registerUnit(unit)
    end
    
    for _, unit in ipairs(enemyUnits) do
        turnManager:registerUnit(unit)
    end
    
    -- Step 5: Start combat
    turnManager:startTurn()
    
    if playerUnits[1].stats.actionPoints ~= playerUnits[1].stats.maxActionPoints then
        success = false
        message = "Turn manager failed to reset action points"
        return success, message
    end
    
    -- Step 6: Player attacks enemy
    local combatSystem = self.game.combatSystem
    if not combatSystem then
        return false, "Combat System not found"
    end
    
    local attackResult = combatSystem:calculateAttack(playerUnits[1], enemyUnits[1])
    combatSystem:applyDamage(enemyUnits[1], attackResult.damage)
    
    if enemyUnits[1].stats.health >= enemyUnits[1].stats.maxHealth then
        success = false
        message = "Combat system failed to apply damage"
        return success, message
    end
    
    -- Step 7: Player uses ability
    local specialAbilitiesSystem = self.game.specialAbilitiesSystem
    if not specialAbilitiesSystem then
        return false, "Special Abilities System not found"
    end
    
    local abilityResult = specialAbilitiesSystem:useAbility(playerUnits[1], "knight's_charge", enemyUnits[1])
    
    if not abilityResult.success then
        success = false
        message = "Special abilities system failed to use ability"
        return success, message
    end
    
    -- Step 8: End player turn
    turnManager:endPhase()
    
    if turnManager.currentPhase ~= "enemy" then
        success = false
        message = "Turn manager failed to transition to enemy phase"
        return success, message
    end
    
    -- Step 9: Enemy AI makes decision
    local enemyAI = self.game.enemyAI
    if not enemyAI then
        return false, "Enemy AI System not found"
    end
    
    local grid = {
        width = 10,
        height = 10,
        getEntity = function(x, y)
            for _, unit in ipairs(playerUnits) do
                if unit.x == x and unit.y == y then
                    return unit
                end
            end
            for _, unit in ipairs(enemyUnits) do
                if unit.x == x and unit.y == y then
                    return unit
                end
            end
            return nil
        end,
        isWalkable = function(x, y)
            return x >= 1 and x <= 10 and y >= 1 and y <= 10
        end
    }
    
    local aiType = enemyAI:getAITypeForUnit(enemyUnits[1])
    local decision = enemyAI:makeDecision(enemyUnits[1], aiType, grid)
    
    if not decision or not decision.type then
        success = false
        message = "Enemy AI failed to make decision"
        return success, message
    end
    
    -- Step 10: End enemy turn and award experience
    turnManager:endPhase()
    
    local experienceSystem = self.game.experienceSystem
    if not experienceSystem then
        return false, "Experience System not found"
    end
    
    -- Simulate enemy defeat
    enemyUnits[1].stats.health = 0
    
    experienceSystem:addExperience(playerUnits[1], experienceSystem:calculateExperienceReward(enemyUnits[1]))
    
    if playerUnits[1].experience <= 0 then
        success = false
        message = "Experience system failed to award experience"
        return success, message
    end
    
    -- Step 11: Add item to inventory
    local inventoryManager = self.game.inventoryManager
    if not inventoryManager then
        return false, "Inventory Manager not found"
    end
    
    local lootItem = {
        id = "loot_sword",
        name = "Loot Sword",
        description = "A sword looted from an enemy",
        type = "weapon",
        rarity = "uncommon",
        stats = {
            attack = 7
        }
    }
    
    inventoryManager:addItem(lootItem)
    
    local items = inventoryManager:getItems()
    local found = false
    for _, item in ipairs(items) do
        if item.id == lootItem.id then
            found = true
            break
        end
    end
    
    if not found then
        success = false
        message = "Inventory system failed to add looted item"
        return success, message
    end
    
    -- Step 12: Mark room as cleared
    proceduralGeneration:markRoomCleared(dungeon.rooms[1].id)
    
    local updatedRoom = proceduralGeneration:getRoomById(dungeon.rooms[1].id)
    if not updatedRoom.cleared then
        success = false
        message = "Procedural generation system failed to mark room as cleared"
        return success, message
    end
    
    -- Step 13: Update meta progression
    local metaProgression = self.game.metaProgression
    if not metaProgression then
        return false, "Meta Progression System not found"
    end
    
    local initialCurrency = metaProgression:getCurrency()
    metaProgression:addCurrency(50)
    
    if metaProgression:getCurrency() ~= initialCurrency + 50 then
        success = false
        message = "Meta progression system failed to add currency"
        return success, message
    end
    
    return success, message
end

-- Test System Interaction
function GameplayTest:testSystemInteraction()
    local success = true
    local message = "System Interaction test passed"
    
    -- Test 1: Combat and Experience interaction
    local combatSystem = self.game.combatSystem
    local experienceSystem = self.game.experienceSystem
    
    if not combatSystem or not experienceSystem then
        return false, "Required systems not found"
    end
    
    local attacker = {
        id = "attacker",
        unitType = "knight",
        faction = "player",
        level = 1,
        experience = 0,
        experienceToNextLevel = 100,
        stats = {
            attack = 15,
            critChance = 0.1
        }
    }
    
    local defender = {
        id = "defender",
        unitType = "pawn",
        faction = "enemy",
        level = 1,
        stats = {
            health = 10,
            maxHealth = 10,
            defense = 5
        }
    }
    
    local attackResult = combatSystem:calculateAttack(attacker, defender)
    combatSystem:applyDamage(defender, attackResult.damage)
    
    -- Check if defender died
    if defender.stats.health <= 0 then
        experienceSystem:addExperience(attacker, experienceSystem:calculateExperienceReward(defender))
        
        if attacker.experience <= 0 then
            success = false
            message = "Combat and Experience interaction failed"
            return success, message
        end
    end
    
    -- Test 2: Turn Manager and Special Abilities interaction
    local turnManager = self.game.turnManager
    local specialAbilitiesSystem = self.game.specialAbilitiesSystem
    
    if not turnManager or not specialAbilitiesSystem then
        return false, "Required systems not found"
    end
    
    local unit = {
        id = "test_unit",
        unitType = "bishop",
        stats = {
            actionPoints = 3,
            maxActionPoints = 3,
            energy = 20,
            maxEnergy = 20
        },
        abilities = {"healing_light"},
        abilityCooldowns = {}
    }
    
    turnManager:registerUnit(unit)
    
    -- Register test ability
    specialAbilitiesSystem:registerAbility({
        id = "healing_light",
        name = "Healing Light",
        description = "Heals an ally",
        energyCost = 10,
        cooldown = 2,
        actionPointCost = 2,
        targetType = "ally",
        range = 3,
        effect = function(caster, target)
            if target then
                target.stats.health = math.min(target.stats.health + 10, target.stats.maxHealth)
                return true
            end
            return false
        end
    })
    
    -- Use ability
    local target = {
        id = "target",
        unitType = "knight",
        stats = {
            health = 10,
            maxHealth = 30
        }
    }
    
    local abilityResult = specialAbilitiesSystem:useAbility(unit, "healing_light", target)
    
    if not abilityResult.success then
        success = false
        message = "Special ability usage failed: " .. (abilityResult.message or "Unknown error")
        return success, message
    end
    
    -- Check if action points were deducted
    if unit.stats.actionPoints ~= 1 then
        success = false
        message = "Turn Manager and Special Abilities interaction failed - action points not deducted"
        return success, message
    end
    
    -- Test 3: Inventory and Combat interaction
    local inventoryManager = self.game.inventoryManager
    
    if not inventoryManager then
        return false, "Required systems not found"
    end
    
    local weapon = {
        id = "test_weapon",
        name = "Test Weapon",
        description = "A test weapon",
        type = "weapon",
        rarity = "rare",
        stats = {
            attack = 10
        }
    }
    
    local combatUnit = {
        id = "combat_unit",
        unitType = "knight",
        equipment = {},
        stats = {
            attack = 5,
            defense = 5
        }
    }
    
    -- Equip weapon
    inventoryManager:equipItem(combatUnit, weapon)
    
    -- Check if stats were updated
    if combatUnit.stats.attack ~= 15 then
        success = false
        message = "Inventory and Combat interaction failed - stats not updated"
        return success, message
    end
    
    -- Test attack with equipped weapon
    local enemy = {
        id = "enemy",
        unitType = "pawn",
        stats = {
            health = 20,
            maxHealth = 20,
            defense = 5
        }
    }
    
    local attackResult = combatSystem:calculateAttack(combatUnit, enemy)
    
    -- Check if attack calculation includes weapon bonus
    if attackResult.damage <= 5 then
        success = false
        message = "Inventory and Combat interaction failed - weapon bonus not applied to attack"
        return success, message
    end
    
    -- Test 4: Procedural Generation and Enemy AI interaction
    local proceduralGeneration = self.game.proceduralGeneration
    local enemyAI = self.game.enemyAI
    
    if not proceduralGeneration or not enemyAI then
        return false, "Required systems not found"
    end
    
    -- Generate a room
    local room = proceduralGeneration:generateRoom("combat", 1, "normal")
    
    if not room then
        success = false
        message = "Room generation failed"
        return success, message
    end
    
    -- Create enemy units for the room
    local enemyUnits = {}
    for i = 1, 3 do
        local enemyUnit = proceduralGeneration:createEnemyUnit("pawn", 1, "normal")
        enemyUnit.x = i + 2
        enemyUnit.y = 3
        table.insert(enemyUnits, enemyUnit)
    end
    
    -- Set up AI for these units
    enemyAI.activeEnemies = enemyUnits
    
    -- Generate tactical plans
    enemyAI:generateTacticalPlans()
    
    if not enemyAI.tacticalPlans or #enemyAI.tacticalPlans == 0 then
        success = false
        message = "Procedural Generation and Enemy AI interaction failed - no tactical plans generated"
        return success, message
    end
    
    -- Test 5: Meta Progression and Experience interaction
    local metaProgression = self.game.metaProgression
    
    if not metaProgression then
        return false, "Required systems not found"
    end
    
    -- Register an upgrade that affects experience gain
    metaProgression:registerUpgrade({
        id = "exp_boost",
        name = "Experience Boost",
        description = "Increases experience gain",
        cost = 50,
        maxLevel = 3,
        effect = function(level)
            return {
                experienceMultiplier = 1 + (level * 0.1)
            }
        end
    })
    
    -- Purchase the upgrade
    local initialCurrency = metaProgression:getCurrency()
    metaProgression:purchaseUpgrade("exp_boost")
    
    -- Check if upgrade was purchased
    if metaProgression:getUpgradeLevel("exp_boost") ~= 1 then
        success = false
        message = "Meta Progression upgrade purchase failed"
        return success, message
    end
    
    -- Check if experience calculation is affected by the upgrade
    local expUnit = {
        id = "exp_unit",
        unitType = "knight",
        level = 1,
        experience = 0,
        experienceToNextLevel = 100
    }
    
    local baseExpReward = experienceSystem:calculateExperienceReward({
        id = "exp_enemy",
        unitType = "pawn",
        level = 1
    })
    
    -- Apply meta progression bonus
    local upgradeEffect = metaProgression:getUpgradeEffect("exp_boost")
    local modifiedExpReward = baseExpReward * (upgradeEffect.experienceMultiplier or 1)
    
    -- Add the modified experience
    experienceSystem:addExperience(expUnit, modifiedExpReward)
    
    -- Check if the correct amount was added
    if math.abs(expUnit.experience - modifiedExpReward) > 0.1 then
        success = false
        message = "Meta Progression and Experience interaction failed - experience bonus not applied"
        return success, message
    end
    
    return success, message
end

-- Get current test status
function GameplayTest:getStatus()
    return {
        currentTest = self.currentTest and self.currentTest.name or nil,
        status = self.testStatus,
        message = self.testMessage,
        progress = self.testProgress
    }
end

return GameplayTest
