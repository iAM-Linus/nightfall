-- Test Runner for Nightfall Chess
-- Executes the gameplay tests and displays results

local class = require("lib.middleclass.middleclass")
local GameplayTest = require("src.test.gameplay_test")

local TestRunner = class("TestRunner")

function TestRunner:initialize(game)
    self.game = game
    self.gameplayTest = GameplayTest:new(game)
    
    -- UI state
    self.visible = false
    self.alpha = 0
    self.targetAlpha = 0
    
    -- Layout
    self.width = 600
    self.height = 500
    self.x = 0
    self.y = 0
    
    -- Test results
    self.testResults = nil
    self.selectedTest = nil
    
    -- Animation
    self.animationTimer = 0
    
    -- Test execution state
    self.isRunning = false
    self.currentStatus = nil
end

-- Set UI position
function TestRunner:setPosition(x, y)
    self.x = x
    self.y = y
end

-- Show test runner UI
function TestRunner:show()
    self.visible = true
    self.targetAlpha = 1
end

-- Hide test runner UI
function TestRunner:hide()
    self.targetAlpha = 0
end

-- Update test runner UI
function TestRunner:update(dt)
    -- Animate alpha
    if self.alpha < self.targetAlpha then
        self.alpha = math.min(self.alpha + dt * 5, self.targetAlpha)
    elseif self.alpha > self.targetAlpha then
        self.alpha = math.max(self.alpha - dt * 5, self.targetAlpha)
        if self.alpha <= 0 then
            self.visible = false
        end
    end
    
    -- Update animation
    self.animationTimer = self.animationTimer + dt
    if self.animationTimer > 1 then
        self.animationTimer = self.animationTimer - 1
    end
    
    -- Update test status if running
    if self.isRunning then
        self.currentStatus = self.gameplayTest:getStatus()
        
        -- Check if tests have completed
        if self.currentStatus.status == "idle" and self.testResults == nil then
            self.isRunning = false
            self.testResults = self.gameplayTest:generateTestReport()
        end
    end
end

-- Draw test runner UI
function TestRunner:draw()
    if not self.visible then return end
    
    local width, height = love.graphics.getDimensions()
    
    -- Center the UI if position not set
    if self.x == 0 and self.y == 0 then
        self.x = (width - self.width) / 2
        self.y = (height - self.height) / 2
    end
    
    -- Draw background
    love.graphics.setColor(0.1, 0.1, 0.2, 0.95 * self.alpha)
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height, 10, 10)
    
    love.graphics.setColor(0.3, 0.3, 0.5, 0.8 * self.alpha)
    love.graphics.rectangle("line", self.x, self.y, self.width, self.height, 10, 10)
    
    -- Draw title
    love.graphics.setColor(1, 1, 1, self.alpha)
    love.graphics.setFont(self.game.assets.fonts.medium)
    love.graphics.print("Nightfall Gameplay Test Runner", self.x + 20, self.y + 20)
    
    -- Draw content
    if self.isRunning then
        self:drawRunningTests()
    elseif self.testResults then
        self:drawTestResults()
    else
        self:drawTestSelection()
    end
    
    -- Draw close button
    love.graphics.setColor(0.8, 0.2, 0.2, 0.8 * self.alpha)
    love.graphics.rectangle("fill", self.x + self.width - 30, self.y + 10, 20, 20, 3, 3)
    
    love.graphics.setColor(1, 1, 1, self.alpha)
    love.graphics.printf("X", self.x + self.width - 30, self.y + 12, 20, "center")
end

-- Draw test selection screen
function TestRunner:drawTestSelection()
    local contentX = self.x + 20
    local contentY = self.y + 60
    local contentWidth = self.width - 40
    
    -- Draw instructions
    love.graphics.setColor(0.7, 0.7, 0.7, 0.9 * self.alpha)
    love.graphics.setFont(self.game.assets.fonts.small)
    love.graphics.printf("Select tests to run or run all tests", contentX, contentY, contentWidth, "center")
    contentY = contentY + 30
    
    -- Draw test list
    love.graphics.setColor(0.8, 0.8, 1.0, self.alpha)
    love.graphics.setFont(self.game.assets.fonts.small)
    love.graphics.print("Available Tests:", contentX, contentY)
    contentY = contentY + 25
    
    for i, test in ipairs(self.gameplayTest.tests) do
        -- Draw test button
        local buttonX = contentX
        local buttonY = contentY
        local buttonWidth = contentWidth
        local buttonHeight = 30
        
        if self.selectedTest == i then
            love.graphics.setColor(0.3, 0.5, 0.8, 0.8 * self.alpha)
        else
            love.graphics.setColor(0.3, 0.3, 0.5, 0.8 * self.alpha)
        end
        
        love.graphics.rectangle("fill", buttonX, buttonY, buttonWidth, buttonHeight, 5, 5)
        
        -- Draw test name
        love.graphics.setColor(1, 1, 1, self.alpha)
        love.graphics.print(test.name, buttonX + 10, buttonY + 7)
        
        contentY = contentY + 35
    end
    
    -- Draw run buttons
    local buttonWidth = 150
    local buttonHeight = 40
    local buttonSpacing = 20
    local totalWidth = buttonWidth * 2 + buttonSpacing
    local startX = self.x + (self.width - totalWidth) / 2
    
    -- Run selected test button
    local buttonX = startX
    local buttonY = self.y + self.height - 60
    
    if self.selectedTest then
        love.graphics.setColor(0.3, 0.6, 0.3, 0.8 * self.alpha)
    else
        love.graphics.setColor(0.3, 0.3, 0.3, 0.8 * self.alpha)
    end
    
    love.graphics.rectangle("fill", buttonX, buttonY, buttonWidth, buttonHeight, 5, 5)
    
    love.graphics.setColor(1, 1, 1, self.alpha)
    love.graphics.printf("Run Selected Test", buttonX, buttonY + 12, buttonWidth, "center")
    
    -- Run all tests button
    buttonX = startX + buttonWidth + buttonSpacing
    
    love.graphics.setColor(0.3, 0.6, 0.3, 0.8 * self.alpha)
    love.graphics.rectangle("fill", buttonX, buttonY, buttonWidth, buttonHeight, 5, 5)
    
    love.graphics.setColor(1, 1, 1, self.alpha)
    love.graphics.printf("Run All Tests", buttonX, buttonY + 12, buttonWidth, "center")
end

-- Draw running tests screen
function TestRunner:drawRunningTests()
    local contentX = self.x + 20
    local contentY = self.y + 60
    local contentWidth = self.width - 40
    
    -- Draw status
    love.graphics.setColor(0.7, 0.7, 0.7, 0.9 * self.alpha)
    love.graphics.setFont(self.game.assets.fonts.small)
    love.graphics.printf("Running tests...", contentX, contentY, contentWidth, "center")
    contentY = contentY + 30
    
    -- Draw current test
    if self.currentStatus and self.currentStatus.currentTest then
        love.graphics.setColor(0.8, 0.8, 1.0, self.alpha)
        love.graphics.printf("Current test: " .. self.currentStatus.currentTest, contentX, contentY, contentWidth, "center")
        contentY = contentY + 25
        
        -- Draw status message
        love.graphics.setColor(0.7, 0.7, 0.7, 0.9 * self.alpha)
        love.graphics.printf(self.currentStatus.message, contentX, contentY, contentWidth, "center")
        contentY = contentY + 40
        
        -- Draw progress bar
        local progressBarWidth = contentWidth
        local progressBarHeight = 20
        local progressBarX = contentX
        local progressBarY = contentY
        
        -- Draw background
        love.graphics.setColor(0.2, 0.2, 0.3, 0.8 * self.alpha)
        love.graphics.rectangle("fill", progressBarX, progressBarY, progressBarWidth, progressBarHeight, 3, 3)
        
        -- Draw progress
        love.graphics.setColor(0.3, 0.6, 0.3, 0.8 * self.alpha)
        love.graphics.rectangle("fill", progressBarX, progressBarY, progressBarWidth * self.currentStatus.progress, progressBarHeight, 3, 3)
        
        -- Draw percentage
        love.graphics.setColor(1, 1, 1, self.alpha)
        love.graphics.printf(math.floor(self.currentStatus.progress * 100) .. "%", progressBarX, progressBarY + 2, progressBarWidth, "center")
    end
    
    -- Draw animated loading indicator
    local centerX = self.x + self.width / 2
    local centerY = self.y + self.height - 100
    local radius = 20
    
    for i = 1, 8 do
        local angle = (i - 1) * math.pi / 4 + self.animationTimer * math.pi * 2
        local dotX = centerX + math.cos(angle) * radius
        local dotY = centerY + math.sin(angle) * radius
        local alpha = 0.3 + 0.7 * math.abs(math.cos(angle - self.animationTimer * math.pi * 2))
        
        love.graphics.setColor(0.7, 0.7, 1.0, alpha * self.alpha)
        love.graphics.circle("fill", dotX, dotY, 5)
    end
    
    -- Draw cancel button
    local buttonWidth = 100
    local buttonHeight = 30
    local buttonX = self.x + (self.width - buttonWidth) / 2
    local buttonY = self.y + self.height - 60
    
    love.graphics.setColor(0.8, 0.3, 0.3, 0.8 * self.alpha)
    love.graphics.rectangle("fill", buttonX, buttonY, buttonWidth, buttonHeight, 5, 5)
    
    love.graphics.setColor(1, 1, 1, self.alpha)
    love.graphics.printf("Cancel", buttonX, buttonY + 7, buttonWidth, "center")
end

-- Draw test results screen
function TestRunner:drawTestResults()
    local contentX = self.x + 20
    local contentY = self.y + 60
    local contentWidth = self.width - 40
    
    -- Draw summary
    love.graphics.setColor(0.7, 0.7, 0.7, 0.9 * self.alpha)
    love.graphics.setFont(self.game.assets.fonts.small)
    love.graphics.printf("Test Results", contentX, contentY, contentWidth, "center")
    contentY = contentY + 30
    
    -- Draw overall status
    if self.testResults.success then
        love.graphics.setColor(0.3, 0.8, 0.3, 0.8 * self.alpha)
        love.graphics.printf("All Tests Passed!", contentX, contentY, contentWidth, "center")
    else
        love.graphics.setColor(0.8, 0.3, 0.3, 0.8 * self.alpha)
        love.graphics.printf("Some Tests Failed", contentX, contentY, contentWidth, "center")
    end
    contentY = contentY + 30
    
    -- Draw statistics
    love.graphics.setColor(0.7, 0.7, 0.7, 0.9 * self.alpha)
    love.graphics.printf("Total Tests: " .. self.testResults.totalTests, contentX, contentY, contentWidth, "center")
    contentY = contentY + 20
    
    love.graphics.setColor(0.3, 0.8, 0.3, 0.8 * self.alpha)
    love.graphics.printf("Passed: " .. self.testResults.passedTests, contentX, contentY, contentWidth, "center")
    contentY = contentY + 20
    
    love.graphics.setColor(0.8, 0.3, 0.3, 0.8 * self.alpha)
    love.graphics.printf("Failed: " .. self.testResults.failedTests, contentX, contentY, contentWidth, "center")
    contentY = contentY + 30
    
    -- Draw result list
    love.graphics.setColor(0.8, 0.8, 1.0, self.alpha)
    love.graphics.setFont(self.game.assets.fonts.small)
    love.graphics.print("Test Details:", contentX, contentY)
    contentY = contentY + 25
    
    -- Set up scrollable area
    local scrollAreaHeight = self.height - contentY - 70
    local scrollAreaY = contentY
    
    -- Draw test results
    for i, result in ipairs(self.testResults.results) do
        -- Skip if outside visible area
        if contentY - scrollAreaY > scrollAreaHeight then
            break
        end
        
        -- Draw result background
        if result.success then
            love.graphics.setColor(0.2, 0.4, 0.2, 0.8 * self.alpha)
        else
            love.graphics.setColor(0.4, 0.2, 0.2, 0.8 * self.alpha)
        end
        
        love.graphics.rectangle("fill", contentX, contentY, contentWidth, 40, 3, 3)
        
        -- Draw result text
        if result.success then
            love.graphics.setColor(0.3, 1.0, 0.3, self.alpha)
        else
            love.graphics.setColor(1.0, 0.3, 0.3, self.alpha)
        end
        
        love.graphics.print(result.name, contentX + 10, contentY + 5)
        
        love.graphics.setColor(0.7, 0.7, 0.7, 0.9 * self.alpha)
        love.graphics.print(result.message, contentX + 20, contentY + 22)
        
        contentY = contentY + 45
    end
    
    -- Draw buttons
    local buttonWidth = 150
    local buttonHeight = 40
    local buttonSpacing = 20
    local totalWidth = buttonWidth * 2 + buttonSpacing
    local startX = self.x + (self.width - totalWidth) / 2
    
    -- Run again button
    local buttonX = startX
    local buttonY = self.y + self.height - 60
    
    love.graphics.setColor(0.3, 0.6, 0.3, 0.8 * self.alpha)
    love.graphics.rectangle("fill", buttonX, buttonY, buttonWidth, buttonHeight, 5, 5)
    
    love.graphics.setColor(1, 1, 1, self.alpha)
    love.graphics.printf("Run Tests Again", buttonX, buttonY + 12, buttonWidth, "center")
    
    -- Back button
    buttonX = startX + buttonWidth + buttonSpacing
    
    love.graphics.setColor(0.3, 0.3, 0.6, 0.8 * self.alpha)
    love.graphics.rectangle("fill", buttonX, buttonY, buttonWidth, buttonHeight, 5, 5)
    
    love.graphics.setColor(1, 1, 1, self.alpha)
    love.graphics.printf("Back to Selection", buttonX, buttonY + 12, buttonWidth, "center")
end

-- Handle mouse press
function TestRunner:mousepressed(x, y, button)
    if not self.visible then return false end
    
    -- Check if close button was clicked
    if x >= self.x + self.width - 30 and x <= self.x + self.width - 10 and
       y >= self.y + 10 and y <= self.y + 30 then
        self:hide()
        return true
    end
    
    -- Handle different screens
    if self.isRunning then
        return self:handleRunningTestsClick(x, y)
    elseif self.testResults then
        return self:handleTestResultsClick(x, y)
    else
        return self:handleTestSelectionClick(x, y)
    end
    
    return false
end

-- Handle clicks on test selection screen
function TestRunner:handleTestSelectionClick(x, y)
    local contentX = self.x + 20
    local contentY = self.y + 60 + 30 + 25
    local contentWidth = self.width - 40
    
    -- Check if a test was clicked
    for i, test in ipairs(self.gameplayTest.tests) do
        local buttonY = contentY + (i-1) * 35
        
        if x >= contentX and x <= contentX + contentWidth and
           y >= buttonY and y <= buttonY + 30 then
            self.selectedTest = i
            return true
        end
    end
    
    -- Check if run buttons were clicked
    local buttonWidth = 150
    local buttonHeight = 40
    local buttonSpacing = 20
    local totalWidth = buttonWidth * 2 + buttonSpacing
    local startX = self.x + (self.width - totalWidth) / 2
    
    -- Run selected test button
    local buttonX = startX
    local buttonY = self.y + self.height - 60
    
    if x >= buttonX and x <= buttonX + buttonWidth and
       y >= buttonY and y <= buttonY + buttonHeight and
       self.selectedTest then
        self:runSelectedTest()
        return true
    end
    
    -- Run all tests button
    buttonX = startX + buttonWidth + buttonSpacing
    
    if x >= buttonX and x <= buttonX + buttonWidth and
       y >= buttonY and y <= buttonY + buttonHeight then
        self:runAllTests()
        return true
    end
    
    return false
end

-- Handle clicks on running tests screen
function TestRunner:handleRunningTestsClick(x, y)
    -- Check if cancel button was clicked
    local buttonWidth = 100
    local buttonHeight = 30
    local buttonX = self.x + (self.width - buttonWidth) / 2
    local buttonY = self.y + self.height - 60
    
    if x >= buttonX and x <= buttonX + buttonWidth and
       y >= buttonY and y <= buttonY + buttonHeight then
        self:cancelTests()
        return true
    end
    
    return false
end

-- Handle clicks on test results screen
function TestRunner:handleTestResultsClick(x, y)
    -- Check if buttons were clicked
    local buttonWidth = 150
    local buttonHeight = 40
    local buttonSpacing = 20
    local totalWidth = buttonWidth * 2 + buttonSpacing
    local startX = self.x + (self.width - totalWidth) / 2
    
    -- Run again button
    local buttonX = startX
    local buttonY = self.y + self.height - 60
    
    if x >= buttonX and x <= buttonX + buttonWidth and
       y >= buttonY and y <= buttonY + buttonHeight then
        self:runAllTests()
        return true
    end
    
    -- Back button
    buttonX = startX + buttonWidth + buttonSpacing
    
    if x >= buttonX and x <= buttonX + buttonWidth and
       y >= buttonY and y <= buttonY + buttonHeight then
        self:resetToSelection()
        return true
    end
    
    return false
end

-- Run selected test
function TestRunner:runSelectedTest()
    if not self.selectedTest then return end
    
    self.isRunning = true
    self.testResults = nil
    
    local testName = self.gameplayTest.tests[self.selectedTest].name
    print("Running test: " .. testName)
    
    -- Run the test asynchronously
    love.thread.newThread([[
        local testName = ...
        local result = self.gameplayTest:runTest(testName)
        return result
    ]])(testName)
end

-- Run all tests
function TestRunner:runAllTests()
    self.isRunning = true
    self.testResults = nil
    
    print("Running all tests")
    
    -- Run the tests asynchronously
    love.thread.newThread([[
        local results = self.gameplayTest:runAllTests()
        return results
    ]])()
end

-- Cancel running tests
function TestRunner:cancelTests()
    self.isRunning = false
    self.testResults = nil
    print("Tests cancelled")
end

-- Reset to test selection screen
function TestRunner:resetToSelection()
    self.testResults = nil
    self.selectedTest = nil
    print("Reset to test selection")
end

-- Export test results to file
function TestRunner:exportResults(filename)
    if not self.testResults then return false end
    
    local file = io.open(filename, "w")
    if not file then return false end
    
    file:write("Nightfall Gameplay Test Results\n")
    file:write("============================\n\n")
    
    file:write("Summary:\n")
    file:write("- Total Tests: " .. self.testResults.totalTests .. "\n")
    file:write("- Passed: " .. self.testResults.passedTests .. "\n")
    file:write("- Failed: " .. self.testResults.failedTests .. "\n")
    file:write("- Overall: " .. (self.testResults.success and "PASSED" or "FAILED") .. "\n\n")
    
    file:write("Test Details:\n")
    for i, result in ipairs(self.testResults.results) do
        file:write(i .. ". " .. result.name .. ": " .. (result.success and "PASSED" or "FAILED") .. "\n")
        file:write("   " .. result.message .. "\n\n")
    end
    
    file:close()
    return true
end

return TestRunner
