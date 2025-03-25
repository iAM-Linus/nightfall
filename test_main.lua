-- test_main.lua - Entry point for Nightfall Chess tests
-- This file is specifically for running the test suite

-- Import the test runner
--local test_runner = require "src.test_runner"
local test_runner = require("src.test_runner")

-- Define love.load to display test status
function love.load()
    print("Starting Nightfall Chess test suite...")
    
    -- Tests will be run automatically when the test_runner is required
    -- The results variable holds the test outcomes
    
    -- Set default font for displaying results
    love.graphics.setNewFont(16)
end

-- Draw test results to the screen
function love.draw()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Nightfall Chess Test Results", 20, 20)
    
    -- Display basic test stats
    love.graphics.print("Total tests: " .. test_runner.total, 20, 60)
    love.graphics.print("Passed: " .. test_runner.passed, 20, 80)
    love.graphics.print("Failed: " .. test_runner.failed, 20, 100)
    love.graphics.print("Skipped: " .. test_runner.skipped, 20, 120)
    
    -- Success rate with color-coding
    local successRate = math.floor((test_runner.passed / test_runner.total) * 100)
    if successRate >= 90 then
        love.graphics.setColor(0, 1, 0, 1)  -- Green for high pass rate
    elseif successRate >= 70 then
        love.graphics.setColor(1, 1, 0, 1)  -- Yellow for medium pass rate
    else
        love.graphics.setColor(1, 0, 0, 1)  -- Red for low pass rate
    end
    
    love.graphics.print("Success rate: " .. successRate .. "%", 20, 150)
    
    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
    
    -- Instruction for detailed results
    love.graphics.print("See console output and test_results.md for detailed results", 20, 190)
    love.graphics.print("Press ESC to exit", 20, 220)
end

-- Handle key presses
function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end
end