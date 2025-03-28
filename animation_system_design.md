# Animation System Design for Nightfall

## Overview
This document outlines the design for implementing arcade-style animations in the Nightfall game, with a focus on unit movement animations. The design draws inspiration from games like Shotgun King and Moonring, emphasizing stylized, exaggerated animations that fit the 16-bit aesthetic.

## Animation System Architecture

### 1. Core Animation Manager
We'll create a new `AnimationManager` class that will:
- Track all active animations
- Update animations based on game time
- Provide an interface for creating and canceling animations
- Handle animation queuing and chaining

### 2. Unit Animation Extension
We'll extend the existing `Unit` class with:
- Visual position properties separate from logical grid position
- Animation state tracking for different actions
- Visual effects for different states (movement, attack, ability use)
- Sprite sheet support for frame-based animations

### 3. Movement Animation Implementation
For unit movement, we'll implement:
- Tweened movement between grid positions
- Exaggerated "squash and stretch" effects
- Arc-based movement paths (units "jump" between positions)
- Anticipation and follow-through phases
- Particle effects for movement trails

### 4. Integration Points
The animation system will integrate with the existing codebase at these points:
- `MovementSystem:moveSelectedUnit()` - Trigger movement animations
- `Unit:update()` - Update visual position and animation state
- `Unit:draw()` - Render the unit with animation effects
- Game state transitions - Handle animation completion callbacks

## Animation Tweening Design

### Movement Animation Sequence
1. **Anticipation Phase (0.1s)**
   - Unit "squashes" down and leans in the direction of movement
   - Small dust particles appear at the unit's feet

2. **Jump/Movement Phase (0.2-0.4s)**
   - Unit follows an arc path to the target position
   - Unit stretches in the direction of movement
   - Trail particles follow the unit's path
   - Shadow remains on ground and follows unit

3. **Landing Phase (0.1s)**
   - Unit "squashes" on impact
   - Dust particles burst from landing point
   - Unit bounces slightly before settling

4. **Settle Phase (0.1s)**
   - Unit returns to normal proportions
   - Small bounce effect for emphasis

### Tween Functions
We'll use the following tween functions from the timer library:
- `out-bounce` - For landing effects
- `in-out-back` - For anticipation and follow-through
- `in-out-elastic` - For exaggerated stretching effects
- `out-quad` - For smooth acceleration

## Visual Effects

### Particle Systems
- **Dust Clouds**: Small particles that appear when a unit starts moving or lands
- **Movement Trails**: Fading particles that follow the unit's path
- **Impact Effects**: Burst of particles when a unit lands or collides

### Sprite Transformations
- **Squash and Stretch**: Deforming the unit sprite during movement
- **Rotation**: Slight rotation during movement for dynamic feel
- **Color Shifts**: Brief color changes to emphasize actions
- **Flash Effects**: White flash on important actions

## Implementation Plan

### Phase 1: Core Animation System
1. Create `AnimationManager` class
2. Implement tween-based animation functions
3. Add visual position properties to `Unit` class
4. Integrate with game update loop

### Phase 2: Movement Animations
1. Implement basic tweened movement between grid positions
2. Add arc movement paths
3. Implement squash and stretch effects
4. Add anticipation and follow-through phases

### Phase 3: Visual Effects
1. Implement dust particle effects
2. Add movement trails
3. Implement impact effects
4. Add color and flash effects

### Phase 4: Polish and Integration
1. Fine-tune animation timing and easing
2. Ensure animations work with game state transitions
3. Add animation cancellation for interrupted actions
4. Optimize performance

## Code Structure

```lua
-- Animation Manager
local AnimationManager = class("AnimationManager")

function AnimationManager:initialize()
    self.activeAnimations = {}
    self.timer = timer.new()
end

function AnimationManager:update(dt)
    self.timer:update(dt)
    -- Update active animations
end

function AnimationManager:createMovementAnimation(unit, targetX, targetY, duration, style)
    -- Create and return a movement animation
end

-- Unit Animation Extension
function Unit:initializeAnimation()
    -- Visual position (separate from logical grid position)
    self.visualX = self.x
    self.visualY = self.y
    
    -- Animation properties
    self.scale = {x = 1, y = 1}
    self.rotation = 0
    self.color = {1, 1, 1, 1}
    self.animationState = "idle"
end

function Unit:moveTo(targetX, targetY)
    -- Logical position update
    local oldX, oldY = self.x, self.y
    self.x, self.y = targetX, targetY
    
    -- Create movement animation
    game.animationManager:createMovementAnimation(self, oldX, oldY, targetX, targetY)
    
    return true
end

function Unit:draw()
    -- Draw unit with current visual properties
    local screenX, screenY = self.grid:gridToScreen(self.visualX, self.visualY)
    
    -- Apply transformations
    love.graphics.push()
    love.graphics.translate(screenX + self.grid.tileSize/2, screenY + self.grid.tileSize/2)
    love.graphics.rotate(self.rotation)
    love.graphics.scale(self.scale.x, self.scale.y)
    
    -- Draw unit sprite
    -- ...
    
    love.graphics.pop()
end
```

## Arcade-Style Animation Characteristics

To achieve the "crazy arcade style" requested:

1. **Exaggerated Motion**: Movements will be more dramatic than realistic
2. **Snappy Timing**: Quick anticipation, fast movement, impactful landing
3. **Visual Feedback**: Abundant particles and effects for every action
4. **Dynamic Scaling**: Units will stretch when moving quickly
5. **Juicy Impacts**: Emphasized landing effects with screen shake for important actions
6. **Vibrant Colors**: Bright, saturated effects that pop against the background
7. **Playful Physics**: Bouncy, elastic movements that defy realistic physics

## Next Steps

1. Implement the core `AnimationManager` class
2. Extend the `Unit` class with visual properties
3. Modify the movement system to use animations
4. Implement the movement animation sequence
5. Add particle effects and visual enhancements
