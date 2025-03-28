-- Animation Test for Nightfall
-- Tests the fixed animation system with the updated Unit class

-- Load required modules
local AnimationManager = require("src.systems.animation_manager")
local Unit = require("src.entities.unit")

-- Test function to verify the animation system works correctly with the Unit class
local function testUnitAnimations()
    print("Testing fixed Unit class with animation system...")
    
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
            end,
            isOccupied = function() return false end
        }
    }
    
    -- Add reference to game in grid
    game.grid.game = game
    
    -- Create animation manager
    local animationManager = AnimationManager:new(game)
    game.animationManager = animationManager
    
    -- Create test unit
    local unit = Unit:new({
        unitType = "knight",
        faction = "player",
        x = 2,
        y = 2,
        grid = game.grid
    })
    
    -- Test that unit has animation properties initialized
    if unit.animTimer == nil then
        print("ERROR: Unit animTimer is nil after initialization")
        return false
    end
    
    if unit.visualX == nil or unit.visualY == nil then
        print("ERROR: Unit visualX/Y are nil after initialization")
        return false
    end
    
    if unit.scale == nil or unit.rotation == nil or unit.offset == nil then
        print("ERROR: Unit animation transform properties are nil after initialization")
        return false
    end
    
    print("Unit animation properties initialized correctly")
    
    -- Test update with nil animTimer (simulating the error condition)
    unit.animTimer = nil
    
    -- This should not throw an error now
    unit:update(0.1)
    
    if unit.animTimer == nil then
        print("ERROR: Unit animTimer is still nil after update")
        return false
    end
    
    print("Unit update handles nil animTimer correctly")
    
    -- Test movement animation
    local startX, startY = unit.x, unit.y
    local targetX, targetY = 4, 4
    
    -- Create movement animation
    local animId = animationManager:createMovementAnimation(
        unit,
        targetX, targetY,
        function()
            print("Movement animation completed")
        end
    )
    
    if not animId then
        print("ERROR: Failed to create movement animation")
        return false
    end
    
    print("Movement animation created successfully")
    
    -- Simulate a few update cycles
    for i = 1, 10 do
        animationManager:update(0.1)
        unit:update(0.1)
    end
    
    -- Check that unit properties are being updated
    if unit.visualX == startX and unit.visualY == startY then
        print("WARNING: Unit visual position not changing during animation")
    end
    
    -- Cancel animation to clean up
    animationManager:cancelAnimation(animId)
    
    print("Unit animation test completed successfully!")
    return true
end

-- Run test when script is executed directly
if arg and arg[0] and arg[0]:find("unit_animation_test.lua") then
    local success = testUnitAnimations()
    if success then
        os.exit(0)
    else
        os.exit(1)
    end
end

return {
    testUnitAnimations = testUnitAnimations
}
