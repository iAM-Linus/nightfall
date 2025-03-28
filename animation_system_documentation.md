# Nightfall Animation System Documentation

## Overview

This document provides comprehensive documentation for the new animation system implemented in the Nightfall game. The animation system adds exaggerated, arcade-style animations to unit movement, attacks, abilities, and other game actions, inspired by games like Shotgun King and Moonring.

## Features

- **Exaggerated Movement Animations**: Units move with squash and stretch effects, arc-based paths, and bouncy landings
- **Dynamic Attack Animations**: Attacks feature windup, strike, follow-through, and recovery phases
- **Flashy Ability Animations**: Abilities have charge-up effects, dramatic releases, and colorful particle effects
- **Particle Effects System**: Dust clouds, movement trails, impact effects, and ability particles
- **Screen Shake Effects**: Dynamic camera shake on impacts and powerful abilities
- **Animation Presets**: Different animation styles (arcade vs. subtle) that can be selected

## Implementation Details

The animation system consists of several components:

1. **Animation Manager** (`src/systems/animation_manager.lua`): Core class that manages all animations and effects
2. **Unit Animation Extension** (`src/entities/unit_animation_extension.lua`): Extends the Unit class with animation properties
3. **Attack Animations** (`src/systems/attack_animations.lua`): Implements attack animation sequences
4. **Ability Animations** (`src/systems/ability_animations.lua`): Implements ability animation sequences
5. **Animation Integration** (`src/systems/animation_integration.lua`): Integrates animations with existing game systems

## Integration Guide

### Basic Integration

To integrate the animation system into your game:

1. Add the following line to your main game initialization code:

```lua
local AnimationIntegration = require("src.systems.animation_integration")
local animationManager = AnimationIntegration.integrateAnimationSystem(game)
```

This will automatically:
- Create an animation manager instance
- Hook into your game's update and draw loops
- Override the necessary methods in movement, combat, and ability systems

No further code changes are needed - animations will automatically play when units move, attack, or use abilities.

### Manual Animation Triggering

If you need to manually trigger animations:

```lua
-- Create movement animation
game.animationManager:createMovementAnimation(unit, targetX, targetY, function()
    print("Movement completed!")
end)

-- Create attack animation
game.animationManager:createAttackAnimation(attacker, defender, function()
    print("Attack completed!")
end)

-- Create ability animation
game.animationManager:createAbilityAnimation(unit, "special", targetPos, function()
    print("Ability completed!")
end)
```

### Customizing Animations

To customize animation parameters:

```lua
-- Change the default animation style
game.animationManager.defaultStyle = "subtle" -- Use more subtle animations

-- Customize screen shake intensity
game.animationManager:shakeScreen(0.2, 0.2) -- Reduced intensity
```

## Animation Types

### Movement Animations

Movement animations consist of four phases:
1. **Anticipation**: Unit "squashes" down and leans in the direction of movement
2. **Jump/Movement**: Unit follows an arc path to the target position with stretching effects
3. **Landing**: Unit "squashes" on impact with dust particles
4. **Settle**: Unit returns to normal proportions with a small bounce

### Attack Animations

Attack animations consist of four phases:
1. **Windup**: Unit prepares for attack with anticipation pose
2. **Strike**: Unit lunges toward target with stretching effects
3. **Follow-through**: Unit continues motion after the impact
4. **Recovery**: Unit returns to normal position and pose

### Ability Animations

Ability animations consist of three phases:
1. **Charge**: Unit builds up energy with pulsing effects and particles
2. **Release**: Unit unleashes the ability with flash effects and particles
3. **Recovery**: Unit returns to normal state

## Particle Effects

The animation system includes various particle effects:

- **Movement Start**: Dust clouds when a unit starts moving
- **Movement Trail**: Particles that follow a unit during movement
- **Landing**: Dust clouds when a unit lands
- **Attack Impact**: Particles that appear when an attack hits
- **Ability Charge**: Particles that appear during ability charge-up
- **Ability Effect**: Particles that appear when an ability is released
- **Ability Impact**: Particles that appear at the target of an ability

## Testing

Two test scripts are provided to verify the animation system:

1. **Animation Test** (`src/tests/animation_test.lua`): Tests individual animation components
2. **Animation Integration Test** (`src/tests/animation_integration_test.lua`): Demonstrates integration with the game

## Performance Considerations

The animation system is designed to be efficient, but complex animations with many particles can impact performance. If you experience performance issues:

1. Reduce the number of particles by modifying the `particleCount` parameter in particle templates
2. Use the "subtle" animation style instead of "arcade" for less intensive animations
3. Disable screen shake effects for lower-end devices

## Troubleshooting

Common issues and solutions:

- **Animations not playing**: Ensure the animation manager is properly integrated with your game object
- **Units not returning to normal state**: Check if animation completion callbacks are being triggered
- **Visual glitches**: Ensure unit visual properties are properly initialized
- **Performance issues**: Reduce particle counts or use subtle animation style

## Future Enhancements

Potential future enhancements for the animation system:

1. **Animation Queueing**: Allow multiple animations to be queued for a unit
2. **Animation Blending**: Smooth transitions between different animation states
3. **Custom Animation Paths**: Define custom movement paths beyond simple arcs
4. **Animation Events**: Trigger specific events at key points in animations
5. **Unit-Specific Animations**: Different animation styles for different unit types
