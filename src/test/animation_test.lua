-- Animation Integration Test for Nightfall
-- Tests the fixed animation system implementation

-- Load required modules
local AnimationManager = require("src.systems.animation_manager")
local AnimationIntegration = require("src.systems.animation_integration")

-- Test function to verify the animation system works correctly
local function testAnimationSystem()
    print("Testing fixed animation system...")
    
    -- Create mock game object
    local game = {
        update = function(self, dt) end,
        draw = function(self) end,
        grid = {
            tileSize = 32,
            width = 8,
            height = 8,
            gridToScreen = function(self, x, y)
                return x * self.tileSize, y * self.tileSize
            end
        }
    }
    
    -- Add reference to game in grid
    game.grid.game = game
    
    -- Integrate animation system
    local animationManager = AnimationIntegration.integrateAnimationSystem(game)
    
    -- Verify animation manager was created
    if not animationManager then
        print("ERROR: Animation manager was not created")
        return false
    end
    
    print("Animation manager created successfully")
    
    -- Verify animation manager methods
    local requiredMethods = {
        "update", "draw", "createMovementAnimation", "createAttackAnimation", 
        "createAbilityAnimation", "createParticles", "shakeScreen",
        "setPlayerTurn", "setActionPoints", "setLevel", "setGrid", 
        "setHelpText", "showNotification"
    }
    
    for _, method in ipairs(requiredMethods) do
        if not animationManager[method] then
            print("ERROR: Animation manager missing required method: " .. method)
            return false
        end
    end
    
    print("All required methods are present")
    
    -- Create mock unit
    local unit = {
        id = 1,
        x = 1,
        y = 1,
        visualX = 1,
        visualY = 1,
        scale = {x = 1, y = 1},
        rotation = 0,
        offset = {x = 0, y = 0},
        grid = game.grid,
        animationState = "idle"
    }
    
    -- Test movement animation
    local moveAnimId = animationManager:createMovementAnimation(
        unit,
        3, 3,
        function()
            print("Movement animation completed")
        end
    )
    
    if not moveAnimId then
        print("ERROR: Failed to create movement animation")
        return false
    end
    
    print("Movement animation created successfully")
    
    -- Test attack animation
    local targetUnit = {
        id = 2,
        x = 2,
        y = 2,
        visualX = 2,
        visualY = 2,
        scale = {x = 1, y = 1},
        rotation = 0,
        offset = {x = 0, y = 0},
        grid = game.grid,
        animationState = "idle",
        showHitEffect = function() end
    }
    
    -- Cancel movement animation first
    animationManager:cancelAnimation(moveAnimId)
    
    local attackAnimId = animationManager:createAttackAnimation(
        unit,
        targetUnit,
        function()
            print("Attack animation completed")
        end
    )
    
    if not attackAnimId then
        print("ERROR: Failed to create attack animation")
        return false
    end
    
    print("Attack animation created successfully")
    
    -- Test ability animation
    -- Cancel attack animation first
    animationManager:cancelAnimation(attackAnimId)
    
    local abilityAnimId = animationManager:createAbilityAnimation(
        unit,
        "special",
        {x = 3, y = 3},
        function()
            print("Ability animation completed")
        end
    )
    
    if not abilityAnimId then
        print("ERROR: Failed to create ability animation")
        return false
    end
    
    print("Ability animation created successfully")
    
    -- Test game.lua compatibility methods
    animationManager:setPlayerTurn(true)
    animationManager:setActionPoints(3, 5)
    animationManager:setLevel(1)
    animationManager:setGrid(game.grid)
    animationManager:setHelpText("Test help text")
    animationManager:showNotification("Test notification", 3)
    
    print("All compatibility methods executed without errors")
    
    print("Animation system test completed successfully!")
    return true
end

-- Run test when script is executed directly
if arg and arg[0] and arg[0]:find("fixed_animation_test.lua") then
    local success = testAnimationSystem()
    if success then
        os.exit(0)
    else
        os.exit(1)
    end
end

return {
    testAnimationSystem = testAnimationSystem
}
