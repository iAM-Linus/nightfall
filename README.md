# Nightfall Chess - Documentation

## Overview

Nightfall Chess is a turn-based tactical roguelike game that combines chess-inspired units with RPG elements. Players navigate procedurally generated dungeons, engage in tactical combat, and progress through both in-run and meta-progression systems.

## Game Systems

### Turn Manager

The Turn Manager system handles the flow of gameplay, determining when each unit acts and managing action points.

**Key Components:**
- `TurnManager`: Core class that manages turn order and phases
- `ActionPoints`: Resource used for unit actions
- `TurnPhases`: Different phases within a turn (planning, action, resolution)
- `Initiative`: System for determining turn order

**Usage Example:**
```lua
-- Initialize turn manager
local turnManager = TurnManager:new()

-- Start a new turn
turnManager:startNewTurn()

-- Check if a unit can act
if turnManager:canUnitAct(unit) then
    -- Perform action
    turnManager:useActionPoints(unit, actionCost)
end

-- End current turn
turnManager:endTurn()
```

### Combat System

The Combat System handles all aspects of combat between units, including damage calculation, critical hits, and combat effects.

**Key Components:**
- `CombatSystem`: Core class for combat calculations
- `DamageTypes`: Different types of damage (physical, magical, etc.)
- `CriticalHits`: System for determining and applying critical hits
- `CombatLog`: Record of combat actions and results

**Usage Example:**
```lua
-- Initialize combat system
local combatSystem = CombatSystem:new()

-- Perform an attack
local result = combatSystem:performAttack(attacker, defender, weapon)

-- Apply damage
defender:takeDamage(result.damage, result.damageType)

-- Check for defeat
if defender:isDefeated() then
    combatSystem:handleDefeat(defender)
end
```

### Special Abilities System

The Special Abilities System manages unit abilities, their costs, cooldowns, and effects.

**Key Components:**
- `SpecialAbilitiesSystem`: Core class for ability management
- `Ability`: Base class for all abilities
- `AbilityTargeting`: System for determining valid targets
- `AbilityEffects`: Various effects that abilities can produce

**Usage Example:**
```lua
-- Initialize abilities system
local abilitiesSystem = SpecialAbilitiesSystem:new()

-- Check if ability can be used
if abilitiesSystem:canUseAbility(unit, abilityId, target) then
    -- Use ability
    abilitiesSystem:useAbility(unit, abilityId, target)
end

-- Update cooldowns
abilitiesSystem:updateCooldowns(dt)
```

### Experience System

The Experience System handles unit progression, leveling, and skill point allocation.

**Key Components:**
- `ExperienceSystem`: Core class for experience management
- `LevelUp`: System for handling level increases
- `SkillPoints`: Resource for improving abilities
- `ExperienceDistribution`: Logic for distributing experience among units

**Usage Example:**
```lua
-- Initialize experience system
local experienceSystem = ExperienceSystem:new()

-- Award experience
experienceSystem:awardExperience(unit, amount)

-- Check for level up
if experienceSystem:canLevelUp(unit) then
    experienceSystem:levelUp(unit)
end

-- Spend skill points
experienceSystem:spendSkillPoints(unit, abilityId, amount)
```

### Inventory System

The Inventory System manages items, equipment, and inventory management.

**Key Components:**
- `InventoryManager`: Core class for inventory management
- `Item`: Base class for all items
- `Equipment`: Items that can be equipped
- `Consumable`: Items that can be used

**Usage Example:**
```lua
-- Initialize inventory manager
local inventoryManager = InventoryManager:new()

-- Add item to inventory
inventoryManager:addItem(player, item)

-- Equip item
inventoryManager:equipItem(player, item, slot)

-- Use consumable
inventoryManager:useItem(player, item)
```

### Meta Progression System

The Meta Progression System handles persistent progression between game runs.

**Key Components:**
- `MetaProgression`: Core class for meta progression
- `Unlocks`: System for unlocking new content
- `Challenges`: Special modifiers for runs
- `Achievements`: Tracking of player accomplishments

**Usage Example:**
```lua
-- Initialize meta progression
local metaProgression = MetaProgression:new()

-- Save progress
metaProgression:saveProgress()

-- Unlock character
metaProgression:unlockCharacter(characterId)

-- Apply challenge
metaProgression:applyChallenge(challengeId)
```

### Procedural Generation System

The Procedural Generation System creates varied dungeons and encounters.

**Key Components:**
- `ProceduralGeneration`: Core class for generation
- `RoomTypes`: Different types of rooms
- `Difficulty`: Scaling of challenge based on progression
- `EncounterGeneration`: Creation of enemy groups

**Usage Example:**
```lua
-- Initialize procedural generation
local proceduralGeneration = ProceduralGeneration:new()

-- Generate dungeon
local dungeon = proceduralGeneration:generateDungeon(floor, difficulty)

-- Generate encounter
local encounter = proceduralGeneration:generateEncounter(room, difficulty)
```

### Enemy AI System

The Enemy AI System controls enemy decision making and tactics.

**Key Components:**
- `EnemyAI`: Core class for AI management
- `Tactics`: Different tactical approaches
- `ThreatAssessment`: Evaluation of player units
- `Coordination`: Cooperation between enemy units

**Usage Example:**
```lua
-- Initialize enemy AI
local enemyAI = EnemyAI:new()

-- Process AI turn
enemyAI:processTurn(enemy)

-- Evaluate targets
local target = enemyAI:evaluateTargets(enemy)

-- Perform action
enemyAI:performAction(enemy, target)
```

## Optimization Systems

### Performance Optimizer

The Performance Optimizer improves game performance through various optimization techniques.

**Key Components:**
- `PerformanceOptimizer`: Core class for optimization
- `ObjectPooling`: Reuse of objects to reduce garbage collection
- `SpatialHashing`: Efficient spatial queries
- `Caching`: Storage of expensive calculation results
- `Culling`: Skipping rendering of off-screen elements

**Usage Example:**
```lua
-- Initialize performance optimizer
local performanceOptimizer = PerformanceOptimizer:new(game)

-- Start monitoring
performanceOptimizer:startMonitoring()

-- Apply optimizations
performanceOptimizer:applyOptimizations()

-- Generate report
local report = performanceOptimizer:generateReport()
```

### Code Refactorer

The Code Refactorer improves code quality and maintainability.

**Key Components:**
- `CodeRefactorer`: Core class for refactoring
- `PatternExtraction`: Identification of common code patterns
- `NamingImprovement`: Enhancement of variable and function names
- `NestingReduction`: Simplification of complex conditional logic
- `Documentation`: Addition of code documentation

**Usage Example:**
```lua
-- Initialize code refactorer
local codeRefactorer = CodeRefactorer:new(game)

-- Refactor file
codeRefactorer:refactorFile(filePath)

-- Refactor directory
codeRefactorer:refactorDirectory(dirPath, true)

-- Generate report
local report = codeRefactorer:generateReport()
```

## UI Components

### Debug Menu

The Debug Menu provides access to debugging and optimization tools.

**Key Components:**
- `DebugMenu`: Core class for the debug interface
- `Options`: Various debugging options
- `Submenus`: Categorized tools
- `Toggles`: On/off switches for features

**Usage Example:**
```lua
-- Initialize debug menu
local debugMenu = DebugMenu:new(game)

-- Add option
debugMenu:addOption("Toggle FPS Display", function()
    game.showFPS = not game.showFPS
    return game.showFPS
end)

-- Show menu
debugMenu:show()
```

### Test Runner

The Test Runner executes and visualizes test results.

**Key Components:**
- `TestRunner`: Core class for test execution
- `GameplayTest`: Collection of game tests
- `TestResults`: Storage of test outcomes
- `Reporting`: Generation of test reports

**Usage Example:**
```lua
-- Initialize test runner
local testRunner = TestRunner:new(game)

-- Run tests
testRunner:runAllTests()

-- Export results
testRunner:exportResults("test_results.txt")
```

## Getting Started

1. Clone the repository
2. Install LÖVE framework (version 11.3 or higher)
3. Run the game with `love .` in the project directory

## Development

To access development tools:
1. Press F12 to open the Debug Menu
2. Use the Test Runner from the main menu
3. Check the console for additional information

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
