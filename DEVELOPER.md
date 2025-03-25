# Nightfall Chess - Developer Documentation

## Architecture Overview

Nightfall Chess is built using the LÖVE framework and follows a modular architecture with the following components:

### Core Systems

1. **Game State Manager**
   - Handles transitions between different game states
   - Manages the game loop and updates

2. **Grid System**
   - Manages the game grid and pathfinding
   - Handles fog of war and visibility
   - Provides utility functions for grid operations

3. **Chess Movement System**
   - Defines movement patterns for different chess pieces
   - Validates moves based on chess rules
   - Handles special movement cases

4. **Turn Management System**
   - Controls turn order and initiative
   - Manages action points
   - Handles turn transitions and effects

5. **Combat System**
   - Calculates damage and combat outcomes
   - Manages attack patterns and ranges
   - Handles critical hits and special attacks

6. **Status Effects System**
   - Applies and removes status effects
   - Manages effect durations and stacking
   - Handles stat modifications from effects

7. **Special Abilities System**
   - Defines unique abilities for each unit type
   - Manages cooldowns and energy costs
   - Handles targeting and area effects

8. **Experience System**
   - Tracks unit experience and level progression
   - Manages skill points and skill trees
   - Handles stat growth on level up

9. **Procedural Generation System**
   - Creates random dungeon layouts
   - Generates rooms with appropriate challenges
   - Places enemies, treasures, and obstacles

10. **Enemy AI System**
    - Controls enemy decision making
    - Implements different AI personalities
    - Manages tactical patterns and coordination

11. **Meta-Progression System**
    - Tracks persistent upgrades between runs
    - Manages unlockable content
    - Handles challenge and achievement systems

### Game States

1. **Menu State**
   - Main menu interface
   - Options and settings
   - Game start and loading

2. **Game State**
   - Main gameplay loop
   - Grid and unit management
   - Player input handling

3. **Combat State**
   - Combat resolution
   - Attack animations
   - Combat log

4. **Inventory State**
   - Item management
   - Equipment handling
   - Item usage

5. **Game Over State**
   - Victory and defeat screens
   - Run statistics
   - Return to menu options

### Entities

1. **Unit**
   - Base class for all game units
   - Manages stats and abilities
   - Handles movement and combat

2. **Item**
   - Defines item properties and effects
   - Handles equipment and consumables
   - Manages item rarity and quality

### UI Components

1. **HUD**
   - Displays player information
   - Shows turn and action indicators
   - Manages notifications

2. **Dialog System**
   - Handles in-game conversations
   - Manages text display and options
   - Controls dialog flow

3. **Tooltip System**
   - Shows contextual information
   - Manages hover detection
   - Handles positioning

4. **Button Component**
   - Creates interactive buttons
   - Manages states and animations
   - Handles click events

5. **Menu System**
   - Creates navigable menus
   - Manages selection and activation
   - Handles submenu navigation

## Data Flow

1. **Input Handling**
   - Player input is captured in the current game state
   - Input is translated into game actions
   - Actions are validated and executed

2. **Update Loop**
   - Game state is updated based on time
   - Systems are updated in sequence
   - UI is updated to reflect changes

3. **Rendering**
   - Grid and units are rendered first
   - Effects and animations are rendered next
   - UI elements are rendered last

## Extension Points

### Adding New Units
To add a new unit type:
1. Define movement pattern in `chess_movement.lua`
2. Create abilities in `special_abilities_system.lua`
3. Add AI behavior in `enemy_ai.lua`
4. Update unit creation in `unit.lua`

### Adding New Items
To add a new item:
1. Define item properties in `item_database.lua`
2. Implement effects in `item.lua`
3. Add to loot tables in `procedural_generation.lua`

### Adding New Abilities
To add a new ability:
1. Define ability in `special_abilities_system.lua`
2. Add targeting logic and effects
3. Update unit definitions to include the ability

### Adding New Status Effects
To add a new status effect:
1. Define effect in `status_effects_system.lua`
2. Implement application and removal logic
3. Add visual indicators in the UI

## Testing

The game includes a comprehensive test suite in `test_suite.lua` that covers:
- Unit tests for individual components
- Integration tests for system interactions
- Edge case handling
- Complete game loop testing

Run tests using `test_runner.lua` to generate a detailed report.

## Performance Considerations

- **Grid Operations**: Pathfinding can be expensive with large grids
- **Procedural Generation**: Room generation should be optimized for larger dungeons
- **Status Effects**: Many simultaneous effects can impact performance
- **AI Decision Making**: Complex AI can slow down enemy turns

## Future Development

Potential areas for expansion:
- Multiplayer support
- Additional unit types
- More diverse environments
- Enhanced visual effects
- Mobile platform support
