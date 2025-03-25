# Nightfall Chess

A roguelike chess game where you navigate through procedurally generated dungeons, battling enemies with chess-inspired movement and combat mechanics.

## Overview

Nightfall Chess combines chess-inspired movement with roguelike dungeon crawling. Navigate through procedurally generated dungeons, collect items, level up your units, and defeat enemies using strategic chess-based combat.

## Features

- **Chess-Inspired Movement**: Units move according to their chess piece type
- **Roguelike Elements**: Procedurally generated dungeons, permadeath, and item collection
- **Turn-Based Combat**: Strategic combat with special abilities and status effects
- **Progression System**: Level up units and unlock new abilities
- **Meta-Progression**: Permanent upgrades between runs
- **Item System**: Collect and use various items to enhance your units
- **Multiple Unit Types**: Play as different chess pieces, each with unique abilities

## Installation

### Prerequisites

- LÖVE 11.3 or higher (https://love2d.org/)

### Running the Game

1. Download and install LÖVE from https://love2d.org/
2. Download the Nightfall Chess .love file
3. Double-click the .love file to run the game

Alternatively, you can run from source:

1. Clone this repository
2. Navigate to the repository directory
3. Run `love .` in the terminal

## Controls

- **Arrow Keys/WASD**: Move cursor/selection
- **Space/Enter**: Select/Confirm
- **E**: Use ability
- **I**: Open inventory
- **Esc**: Pause/Menu
- **Tab**: View unit stats

## Gameplay

### Basic Concepts

- **Units**: Each unit moves according to its chess piece type
- **Action Points**: Units have a limited number of actions per turn
- **Energy**: Special abilities consume energy
- **Fog of War**: Unexplored areas are hidden
- **Items**: Collect items to enhance your units

### Game Flow

1. Start a new game from the main menu
2. Navigate through procedurally generated rooms
3. Defeat enemies to gain experience and items
4. Level up your units and unlock new abilities
5. Find the exit to progress to the next floor
6. Defeat the boss to complete the dungeon

### Combat

- Move adjacent to an enemy to attack
- Different units have different attack patterns
- Use special abilities to gain an advantage
- Consider status effects and terrain

## Development

### Project Structure

- `src/`: Source code
  - `entities/`: Game entities (units, items)
  - `states/`: Game states (menu, game, combat)
  - `systems/`: Game systems (grid, combat, AI)
  - `ui/`: User interface components
- `assets/`: Game assets
  - `images/`: Graphics and sprites
  - `sounds/`: Sound effects and music
- `lib/`: External libraries

### Building

To build a distributable .love file:

```bash
cd /path/to/nightfall_chess
zip -9 -r nightfall_chess.love .
```

## Credits

- Game Design & Programming: Nightfall Chess Team
- Art: [Attribution for art assets]
- Sound: [Attribution for sound assets]
- Libraries:
  - LÖVE: https://love2d.org/
  - Middleclass: https://github.com/kikito/middleclass

## License

[License information]
