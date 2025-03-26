# Nightfall Chess - Developer Documentation

## Architecture Overview

Nightfall Chess follows a component-based architecture with clear separation of concerns. The main components are:

1. **States**: Game states that control the flow of the application
2. **Systems**: Core gameplay systems that implement game mechanics
3. **Entities**: Game objects with properties and behaviors
4. **UI**: User interface components for player interaction
5. **Utilities**: Helper functions and classes

## Directory Structure

```
nightfall/
├── assets/           # Game assets (images, sounds, fonts)
├── lib/              # Third-party libraries
├── src/              # Source code
│   ├── entities/     # Game entities
│   ├── optimization/ # Performance and code quality tools
│   ├── states/       # Game states
│   ├── systems/      # Game systems
│   ├── test/         # Testing infrastructure
│   └── ui/           # User interface components
└── main.lua          # Entry point
```

## System Dependencies

The following diagram shows the dependencies between major systems:

```
Game
 ├── TurnManager
 │    ├── CombatSystem
 │    └── EnemyAI
 ├── SpecialAbilitiesSystem
 │    └── StatusEffectsSystem
 ├── ExperienceSystem
 ├── InventoryManager
 ├── MetaProgression
 └── ProceduralGeneration
```

## State Flow

The game follows this state flow:

1. **MainMenu**: Entry point with options
2. **Game**: Main gameplay state
   - **Combat**: Turn-based combat encounters
   - **Inventory**: Item management
   - **Map**: Dungeon navigation
   - **LevelUp**: Character progression
3. **GameOver**: End of run with results
4. **MetaProgression**: Between-run upgrades

## Implementation Details

### Entity Component System

Entities in Nightfall Chess use a lightweight component system:

```lua
-- Entity base class
local Entity = class("Entity")

function Entity:initialize(components)
    self.components = components or {}
    self.id = generateUniqueId()
end

function Entity:addComponent(name, component)
    self.components[name] = component
end

function Entity:getComponent(name)
    return self.components[name]
end

function Entity:hasComponent(name)
    return self.components[name] ~= nil
end
```

### Event System

The game uses an event system for communication between components:

```lua
-- Event system
local EventSystem = class("EventSystem")

function EventSystem:initialize()
    self.listeners = {}
end

function EventSystem:addEventListener(eventType, listener)
    if not self.listeners[eventType] then
        self.listeners[eventType] = {}
    end
    table.insert(self.listeners[eventType], listener)
end

function EventSystem:dispatchEvent(eventType, data)
    if not self.listeners[eventType] then return end
    
    for _, listener in ipairs(self.listeners[eventType]) do
        listener(data)
    end
end
```

### Grid System

The game uses a grid-based system for positioning and movement:

```lua
-- Grid system
local Grid = class("Grid")

function Grid:initialize(width, height, tileSize)
    self.width = width
    self.height = height
    self.tileSize = tileSize
    self.cells = {}
    
    -- Initialize grid
    for x = 1, width do
        self.cells[x] = {}
        for y = 1, height do
            self.cells[x][y] = {
                entities = {},
                walkable = true,
                visible = false
            }
        end
    end
end

function Grid:getCell(x, y)
    if x < 1 or x > self.width or y < 1 or y > self.height then
        return nil
    end
    return self.cells[x][y]
end

function Grid:addEntity(entity, x, y)
    local cell = self:getCell(x, y)
    if not cell then return false end
    
    entity.x = x
    entity.y = y
    table.insert(cell.entities, entity)
    return true
end

function Grid:moveEntity(entity, newX, newY)
    -- Remove from current cell
    local currentCell = self:getCell(entity.x, entity.y)
    if currentCell then
        for i, e in ipairs(currentCell.entities) do
            if e == entity then
                table.remove(currentCell.entities, i)
                break
            end
        end
    end
    
    -- Add to new cell
    return self:addEntity(entity, newX, newY)
end
```

## Performance Considerations

### Rendering Optimization

The game uses several techniques to optimize rendering:

1. **Culling**: Only rendering visible elements
2. **Batching**: Grouping similar draw calls
3. **Caching**: Pre-rendering static elements

Example implementation:

```lua
function RenderSystem:draw()
    -- Get visible area
    local visibleX, visibleY, visibleWidth, visibleHeight = self:getVisibleArea()
    
    -- Calculate visible cells
    local startX = math.max(1, math.floor(visibleX / self.grid.tileSize))
    local startY = math.max(1, math.floor(visibleY / self.grid.tileSize))
    local endX = math.min(self.grid.width, math.ceil((visibleX + visibleWidth) / self.grid.tileSize))
    local endY = math.min(self.grid.height, math.ceil((visibleY + visibleHeight) / self.grid.tileSize))
    
    -- Draw only visible cells
    for x = startX, endX do
        for y = startY, endY do
            self:drawCell(x, y)
        end
    end
end
```

### Memory Management

The game uses object pooling to reduce garbage collection:

```lua
function ObjectPool:initialize(factory, initialSize)
    self.factory = factory
    self.available = {}
    self.inUse = {}
    
    -- Pre-create objects
    for i = 1, initialSize do
        table.insert(self.available, factory())
    end
end

function ObjectPool:get()
    local object
    
    if #self.available > 0 then
        object = table.remove(self.available)
    else
        object = self.factory()
    end
    
    table.insert(self.inUse, object)
    return object
end

function ObjectPool:release(object)
    for i, obj in ipairs(self.inUse) do
        if obj == object then
            table.remove(self.inUse, i)
            
            -- Reset object if it has a reset method
            if object.reset then
                object:reset()
            end
            
            table.insert(self.available, object)
            break
        end
    end
end
```

## Testing Strategy

The game uses a comprehensive testing approach:

1. **Unit Tests**: Testing individual functions and methods
2. **Integration Tests**: Testing system interactions
3. **Gameplay Tests**: Testing complete gameplay scenarios

Example test:

```lua
function GameplayTest:testCombatSystem()
    -- Setup
    local attacker = Unit:new("Knight")
    local defender = Unit:new("Pawn")
    local combatSystem = CombatSystem:new()
    
    -- Execute
    local result = combatSystem:performAttack(attacker, defender)
    
    -- Verify
    assert(result.success, "Attack should succeed")
    assert(defender.health < defender.maxHealth, "Defender should take damage")
    
    return true, "Combat system test passed"
end
```

## Extending the Game

### Adding New Units

To add a new unit type:

1. Create a new unit class in `src/entities/units/`
2. Define unit properties and abilities
3. Add unit to the unit factory
4. Create AI behavior for the unit
5. Add unit to procedural generation

Example:

```lua
-- New unit: Queen
local Queen = class("Queen", Unit)

function Queen:initialize()
    Unit.initialize(self)
    
    self.type = "Queen"
    self.maxHealth = 150
    self.health = 150
    self.attack = 12
    self.defense = 8
    self.speed = 8
    
    -- Add abilities
    self:addAbility("RoyalCommand")
    self:addAbility("DiagonalStrike")
    self:addAbility("HorizontalSweep")
end

-- Register unit
UnitFactory:registerUnit("Queen", Queen)
```

### Adding New Abilities

To add a new ability:

1. Create a new ability class in `src/systems/abilities/`
2. Define ability properties and effects
3. Add ability to the ability registry
4. Assign ability to appropriate units

Example:

```lua
-- New ability: RoyalCommand
local RoyalCommand = class("RoyalCommand", Ability)

function RoyalCommand:initialize()
    Ability.initialize(self)
    
    self.name = "Royal Command"
    self.description = "Grants an extra action to an allied unit"
    self.cooldown = 3
    self.energyCost = 30
    self.targetType = "ally"
    self.range = 3
end

function RoyalCommand:execute(user, target)
    -- Grant extra action
    target:grantExtraAction()
    
    -- Apply cooldown
    user:setAbilityCooldown(self.id, self.cooldown)
    
    -- Use energy
    user:useEnergy(self.energyCost)
    
    return true
end

-- Register ability
AbilityRegistry:registerAbility("RoyalCommand", RoyalCommand)
```

## Troubleshooting

### Common Issues

1. **Performance Problems**
   - Use the Performance Optimizer to identify bottlenecks
   - Check for excessive object creation in update loops
   - Verify that culling is working correctly

2. **Memory Leaks**
   - Check for objects not being properly released
   - Verify that event listeners are being removed
   - Use object pooling for frequently created objects

3. **AI Issues**
   - Check pathfinding calculations
   - Verify threat assessment logic
   - Ensure proper coordination between units

### Debugging Tools

1. **Debug Menu (F12)**
   - Performance monitoring
   - System toggles
   - Visual debugging

2. **Console Logging**
   - Set log level in config
   - Filter by system
   - Export logs for analysis

3. **Test Runner**
   - Run specific tests
   - Generate test reports
   - Automate regression testing

## Coding Standards

1. **Naming Conventions**
   - Classes: PascalCase
   - Functions and variables: camelCase
   - Constants: UPPER_CASE
   - Private members: _prefixedWithUnderscore

2. **File Organization**
   - One class per file
   - Group related files in directories
   - Use clear, descriptive file names

3. **Documentation**
   - Document all public functions
   - Include parameter descriptions
   - Explain complex algorithms
   - Add examples for important functions

4. **Code Style**
   - Use 4 spaces for indentation
   - Limit line length to 100 characters
   - Add blank lines between logical sections
   - Use meaningful variable names
