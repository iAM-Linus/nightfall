-- Improved Test Runner for Nightfall Chess
-- Properly initializes the environment and runs the test suite

-- Set up path for requiring modules
package.path = package.path .. ";./?.lua"

-- Mock love2d framework for tests that require it
if not love then
    love = {}
    love.graphics = {
        newFont = function(size) return {size = size} end,
        getWidth = function() return 800 end,
        getHeight = function() return 600 end,
        setColor = function() end,
        rectangle = function() end,
        print = function() end,
        printf = function() end,
        draw = function() end,
        setFont = function() end,
        circle = function() end,
        polygon = function() end,
        line = function() end
    }
    love.keyboard = {
        isDown = function() return false end
    }
    love.mouse = {
        getPosition = function() return 0, 0 end
    }
    love.timer = {
        getTime = function() return os.clock() end
    }
    love.audio = {
        play = function() end,
        stop = function() end
    }
    love.event = {
        quit = function() end
    }
end

-- Create a minimal game object for testing
local function createTestGame()
    local game = {
        config = {
            tileSize = 32,
            screenWidth = 800,
            screenHeight = 600,
            debug = true
        },
        assets = {
            fonts = {
                small = love.graphics.newFont(12),
                medium = love.graphics.newFont(16),
                large = love.graphics.newFont(24),
                title = love.graphics.newFont(32)
            },
            sprites = {},
            sounds = {}
        }
    }
    return game
end

-- Load test suite
local TestSuite = require("src.test_suite")

-- Create game and test suite
local game = createTestGame()
local testSuite = TestSuite:new(game)

-- Run all tests or specific test if provided
local function runTests()
    local specificTest = arg[1]
    local results
    
    if specificTest then
        local found = false
        for i, test in ipairs(testSuite.tests) do
            if test.id == specificTest then
                print("Running specific test: " .. test.name)
                testSuite:runTest(i)
                found = true
                results = testSuite:getResults()
                break
            end
        end
        
        if not found then
            print("Test with ID '" .. specificTest .. "' not found.")
            return false
        end
    else
        results = testSuite:runAllTests()
    end
    
    -- Print summary
    print("\n=== TEST SUMMARY ===")
    print("Passed: " .. results.passed .. "/" .. results.total)
    print("Failed: " .. results.failed)
    print("Skipped: " .. results.skipped)
    print("Success rate: " .. math.floor((results.passed / results.total) * 100) .. "%")

    -- Generate detailed report
    local reportFile = io.open("test_results.md", "w")
    if reportFile then
        reportFile:write("# Nightfall Chess - Test Results\n\n")
        reportFile:write("## Summary\n")
        reportFile:write("- **Date:** " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n")
        reportFile:write("- **Tests Run:** " .. results.total .. "\n")
        reportFile:write("- **Passed:** " .. results.passed .. "\n")
        reportFile:write("- **Failed:** " .. results.failed .. "\n")
        reportFile:write("- **Skipped:** " .. results.skipped .. "\n")
        reportFile:write("- **Success Rate:** " .. math.floor((results.passed / results.total) * 100) .. "%\n\n")
        
        reportFile:write("## Test Details\n\n")
        
        for i, test in ipairs(testSuite.tests) do
            local status = "❓ Unknown"
            if test.result == true then
                status = "✅ Passed"
            elseif test.result == false then
                status = "❌ Failed"
            elseif test.result == "skipped" then
                status = "⏭️ Skipped"
            end
            
            reportFile:write("### " .. test.name .. " (" .. test.id .. ")\n")
            reportFile:write("**Status:** " .. status .. "\n")
            
            if test.error then
                reportFile:write("**Error:** " .. tostring(test.error) .. "\n")
            end
            
            reportFile:write("\n")
        end
        
        reportFile:write("## Log\n\n")
        reportFile:write("```\n")
        for _, log in ipairs(testSuite:getLogs()) do
            reportFile:write(log .. "\n")
        end
        reportFile:write("```\n")
        
        reportFile:close()
        print("Detailed test report written to test_results.md")
    end

    -- Return overall success status
    return results.failed == 0
end

-- Run tests and get the result
local success = runTests()

-- If running as a standalone script, exit with appropriate status code
if arg and arg[0] and arg[0]:find("test_runner.lua") then
    os.exit(success and 0 or 1)
end

-- Return success status for use in LÖVE environment
return success