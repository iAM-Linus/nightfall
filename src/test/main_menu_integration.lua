-- Main Menu Integration for Test Runner
-- Adds a test button to the main menu

local TestRunner = require("src.test.test_runner")

-- Store the original MainMenu:initialize function
local originalMainMenuInitialize = MainMenu.initialize

-- Override the initialize function to add our test button
function MainMenu:initialize(game)
    -- Call the original initialize function
    originalMainMenuInitialize(self, game)
    
    -- Create test runner
    self.testRunner = TestRunner:new(game)
    
    -- Add test button to menu options
    table.insert(self.menuOptions, {
        text = "Run Tests",
        action = function()
            self.testRunner:show()
        end
    })
end

-- Store the original MainMenu:update function
local originalMainMenuUpdate = MainMenu.update

-- Override the update function to update the test runner
function MainMenu:update(dt)
    -- Call the original update function
    originalMainMenuUpdate(self, dt)
    
    -- Update test runner if it exists
    if self.testRunner then
        self.testRunner:update(dt)
    end
end

-- Store the original MainMenu:draw function
local originalMainMenuDraw = MainMenu.draw

-- Override the draw function to draw the test runner
function MainMenu:draw()
    -- Call the original draw function
    originalMainMenuDraw(self)
    
    -- Draw test runner if it exists
    if self.testRunner then
        self.testRunner:draw()
    end
end

-- Store the original MainMenu:mousepressed function
local originalMainMenuMousepressed = MainMenu.mousepressed

-- Override the mousepressed function to handle test runner clicks
function MainMenu:mousepressed(x, y, button)
    -- Check if test runner handled the click
    if self.testRunner and self.testRunner.visible then
        if self.testRunner:mousepressed(x, y, button) then
            return
        end
    end
    
    -- Call the original mousepressed function
    originalMainMenuMousepressed(self, x, y, button)
end

print("Test Runner integrated into Main Menu")
