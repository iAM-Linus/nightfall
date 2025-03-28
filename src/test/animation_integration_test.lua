-- Animation System Integration Test for Nightfall
-- This script demonstrates how to integrate the animation system into the main game

-- Load required modules
local AnimationIntegration = require("src.systems.animation_integration")

-- Example of integrating animation system in main.lua
local function integrateAnimationSystemExample()
    -- In your main.lua or game initialization code:
    
    -- 1. Require the animation integration module
    -- local AnimationIntegration = require("src.systems.animation_integration")
    
    -- 2. After creating your game object, integrate the animation system
    -- local animationManager = AnimationIntegration.integrateAnimationSystem(game)
    
    -- 3. The integration automatically hooks into your game's update and draw loops
    -- and overrides the necessary methods in movement, combat, and ability systems
    
    -- 4. No further code changes are needed - animations will automatically play
    -- when units move, attack, or use abilities
    
    return "Animation system integration example"
end

-- Example of manually triggering animations
local function manualAnimationExample()
    -- If you need to manually trigger animations:
    
    -- 1. Access the animation manager through the game object
    -- local animationManager = game.animationManager
    
    -- 2. Create movement animation
    -- animationManager:createMovementAnimation(unit, targetX, targetY, function()
    --     print("Movement completed!")
    -- end)
    
    -- 3. Create attack animation
    -- animationManager:createAttackAnimation(attacker, defender, function()
    --     print("Attack completed!")
    -- end)
    
    -- 4. Create ability animation
    -- animationManager:createAbilityAnimation(unit, "special", targetPos, function()
    --     print("Ability completed!")
    -- end)
    
    return "Manual animation triggering example"
end

-- Example of customizing animation parameters
local function customizeAnimationsExample()
    -- To customize animation parameters:
    
    -- 1. Access the animation manager through the game object
    -- local animationManager = game.animationManager
    
    -- 2. Change the default animation style
    -- animationManager.defaultStyle = "subtle" -- Use more subtle animations
    
    -- 3. Customize screen shake intensity
    -- Original screen shake call:
    -- animationManager:shakeScreen(0.5, 0.3)
    
    -- Reduced intensity for less dramatic effect:
    -- animationManager:shakeScreen(0.2, 0.2)
    
    -- 4. Create custom particle effects
    -- local customParticles = {
    --     particleCount = 10,
    --     lifetime = {0.3, 0.7},
    --     size = {2, 5},
    --     speed = {20, 40},
    --     color = {{1, 0.5, 0, 0.8}, {1, 0.3, 0, 0}},
    --     spread = math.pi * 0.5
    -- }
    -- 
    -- -- Add to PARTICLE_TEMPLATES table
    -- animationManager.PARTICLE_TEMPLATES["customEffect"] = customParticles
    
    return "Animation customization example"
end

-- Run examples when script is executed directly
if arg and arg[0] and arg[0]:find("animation_integration_test.lua") then
    print("Animation Integration Examples:")
    print("1. " .. integrateAnimationSystemExample())
    print("2. " .. manualAnimationExample())
    print("3. " .. customizeAnimationsExample())
end

return {
    integrateAnimationSystemExample = integrateAnimationSystemExample,
    manualAnimationExample = manualAnimationExample,
    customizeAnimationsExample = customizeAnimationsExample
}
