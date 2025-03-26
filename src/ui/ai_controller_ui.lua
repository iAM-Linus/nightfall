-- AI Controller UI for Nightfall Chess
-- Handles display and interaction with enemy AI system

local class = require("lib.middleclass.middleclass")

local AIControllerUI = class("AIControllerUI")

function AIControllerUI:initialize(game, enemyAI)
    self.game = game
    self.enemyAI = enemyAI
    
    -- UI state
    self.visible = false
    self.alpha = 0
    self.targetAlpha = 0
    
    -- Layout
    self.width = 300
    self.height = 400
    self.x = 0
    self.y = 0
    
    -- Current tab
    self.currentTab = "status"
    
    -- AI settings
    self.difficultyOptions = {"easy", "normal", "hard"}
    self.selectedDifficulty = "normal"
    
    -- AI behavior toggles
    self.enableTacticalPlanning = true
    self.enableMemory = true
    self.enableCoordination = true
    
    -- Debug visualization
    self.showThreatMap = false
    self.showOpportunityMap = false
    self.showTargetPriority = false
    self.showDecisionTree = false
    
    -- Animation
    self.animationTimer = 0
    
    -- Decision history
    self.decisionHistory = {}
    self.maxHistoryEntries = 10
    
    -- Unit focus
    self.focusedUnit = nil
end

-- Set UI position
function AIControllerUI:setPosition(x, y)
    self.x = x
    self.y = y
end

-- Show AI controller UI
function AIControllerUI:show()
    self.visible = true
    self.targetAlpha = 1
end

-- Hide AI controller UI
function AIControllerUI:hide()
    self.targetAlpha = 0
end

-- Update AI controller UI
function AIControllerUI:update(dt)
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
end

-- Draw AI controller UI
function AIControllerUI:draw()
    if not self.visible then return end
    
    local width, height = love.graphics.getDimensions()
    
    -- Center the UI if position not set
    if self.x == 0 and self.y == 0 then
        self.x = width - self.width - 20
        self.y = 100
    end
    
    -- Draw background
    love.graphics.setColor(0.1, 0.1, 0.2, 0.95 * self.alpha)
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height, 10, 10)
    
    love.graphics.setColor(0.3, 0.3, 0.5, 0.8 * self.alpha)
    love.graphics.rectangle("line", self.x, self.y, self.width, self.height, 10, 10)
    
    -- Draw title
    love.graphics.setColor(1, 1, 1, self.alpha)
    love.graphics.setFont(self.game.assets.fonts.medium)
    love.graphics.print("AI Controller", self.x + 20, self.y + 20)
    
    -- Draw tabs
    self:drawTabs()
    
    -- Draw content based on current tab
    if self.currentTab == "status" then
        self:drawStatusTab()
    elseif self.currentTab == "settings" then
        self:drawSettingsTab()
    elseif self.currentTab == "debug" then
        self:drawDebugTab()
    elseif self.currentTab == "history" then
        self:drawHistoryTab()
    end
    
    -- Draw close button
    love.graphics.setColor(0.8, 0.2, 0.2, 0.8 * self.alpha)
    love.graphics.rectangle("fill", self.x + self.width - 30, self.y + 10, 20, 20, 3, 3)
    
    love.graphics.setColor(1, 1, 1, self.alpha)
    love.graphics.printf("X", self.x + self.width - 30, self.y + 12, 20, "center")
end

-- Draw tabs
function AIControllerUI:drawTabs()
    local tabs = {
        {id = "status", name = "Status"},
        {id = "settings", name = "Settings"},
        {id = "debug", name = "Debug"},
        {id = "history", name = "History"}
    }
    
    local tabWidth = 65
    local tabHeight = 25
    local tabY = self.y + 50
    
    for i, tab in ipairs(tabs) do
        local tabX = self.x + 10 + (i-1) * (tabWidth + 5)
        
        -- Draw tab background
        if self.currentTab == tab.id then
            love.graphics.setColor(0.3, 0.3, 0.6, 0.8 * self.alpha)
        else
            love.graphics.setColor(0.2, 0.2, 0.3, 0.8 * self.alpha)
        end
        
        love.graphics.rectangle("fill", tabX, tabY, tabWidth, tabHeight, 5, 5, 5, 0)
        
        -- Draw tab text
        love.graphics.setColor(1, 1, 1, self.alpha)
        love.graphics.setFont(self.game.assets.fonts.small)
        love.graphics.printf(tab.name, tabX, tabY + 5, tabWidth, "center")
    end
    
    -- Draw content area
    love.graphics.setColor(0.2, 0.2, 0.3, 0.8 * self.alpha)
    love.graphics.rectangle("fill", self.x + 10, self.y + 75, self.width - 20, self.height - 85, 5, 5)
    
    love.graphics.setColor(0.3, 0.3, 0.5, 0.8 * self.alpha)
    love.graphics.rectangle("line", self.x + 10, self.y + 75, self.width - 20, self.height - 85, 5, 5)
end

-- Draw status tab
function AIControllerUI:drawStatusTab()
    if not self.enemyAI then
        love.graphics.setColor(0.7, 0.7, 0.7, self.alpha)
        love.graphics.setFont(self.game.assets.fonts.small)
        love.graphics.printf("AI system not available", self.x + 20, self.y + 100, self.width - 40, "center")
        return
    end
    
    local contentX = self.x + 20
    local contentY = self.y + 85
    local contentWidth = self.width - 40
    
    -- Draw AI status
    love.graphics.setColor(0.8, 0.8, 1.0, self.alpha)
    love.graphics.setFont(self.game.assets.fonts.small)
    love.graphics.print("AI Status", contentX, contentY)
    contentY = contentY + 25
    
    -- Draw current difficulty
    love.graphics.setColor(0.7, 0.7, 0.7, 0.9 * self.alpha)
    love.graphics.print("Difficulty: " .. self.selectedDifficulty:sub(1,1):upper() .. self.selectedDifficulty:sub(2), contentX, contentY)
    contentY = contentY + 20
    
    -- Draw current turn
    love.graphics.setColor(0.7, 0.7, 0.7, 0.9 * self.alpha)
    love.graphics.print("Current Turn: " .. self.enemyAI.currentTurn, contentX, contentY)
    contentY = contentY + 20
    
    -- Draw active enemies count
    love.graphics.setColor(0.7, 0.7, 0.7, 0.9 * self.alpha)
    love.graphics.print("Active Enemies: " .. #self.enemyAI.activeEnemies, contentX, contentY)
    contentY = contentY + 30
    
    -- Draw active tactical plans
    love.graphics.setColor(0.8, 0.8, 1.0, self.alpha)
    love.graphics.print("Active Tactical Plans", contentX, contentY)
    contentY = contentY + 25
    
    if self.enemyAI.tacticalPlans and #self.enemyAI.tacticalPlans > 0 then
        for i, plan in ipairs(self.enemyAI.tacticalPlans) do
            if i > 3 then break end -- Show only top 3 plans
            
            love.graphics.setColor(0.7, 0.7, 0.7, 0.9 * self.alpha)
            love.graphics.print(plan.type .. " - " .. plan.priority .. " priority", contentX, contentY)
            contentY = contentY + 20
        end
    else
        love.graphics.setColor(0.7, 0.7, 0.7, 0.9 * self.alpha)
        love.graphics.print("No active tactical plans", contentX, contentY)
        contentY = contentY + 20
    end
    
    contentY = contentY + 10
    
    -- Draw focused unit info
    love.graphics.setColor(0.8, 0.8, 1.0, self.alpha)
    love.graphics.print("Focused Unit", contentX, contentY)
    contentY = contentY + 25
    
    if self.focusedUnit then
        -- Draw unit type
        love.graphics.setColor(0.7, 0.7, 0.7, 0.9 * self.alpha)
        love.graphics.print("Type: " .. self.focusedUnit.unitType:sub(1,1):upper() .. self.focusedUnit.unitType:sub(2), contentX, contentY)
        contentY = contentY + 20
        
        -- Draw AI type
        local aiType = self.enemyAI:getAITypeForUnit(self.focusedUnit)
        love.graphics.setColor(0.7, 0.7, 0.7, 0.9 * self.alpha)
        love.graphics.print("AI Type: " .. aiType:sub(1,1):upper() .. aiType:sub(2), contentX, contentY)
        contentY = contentY + 20
        
        -- Draw health
        local healthPercent = self.focusedUnit.stats.health / self.focusedUnit.stats.maxHealth
        love.graphics.setColor(0.7, 0.7, 0.7, 0.9 * self.alpha)
        love.graphics.print("Health: " .. self.focusedUnit.stats.health .. "/" .. self.focusedUnit.stats.maxHealth, contentX, contentY)
        contentY = contentY + 20
        
        -- Draw health bar
        love.graphics.setColor(0.2, 0.2, 0.2, 0.8 * self.alpha)
        love.graphics.rectangle("fill", contentX, contentY, 150, 10)
        
        if healthPercent > 0.6 then
            love.graphics.setColor(0.2, 0.8, 0.2, 0.8 * self.alpha)
        elseif healthPercent > 0.3 then
            love.graphics.setColor(0.8, 0.8, 0.2, 0.8 * self.alpha)
        else
            love.graphics.setColor(0.8, 0.2, 0.2, 0.8 * self.alpha)
        end
        
        love.graphics.rectangle("fill", contentX, contentY, 150 * healthPercent, 10)
        contentY = contentY + 20
    else
        love.graphics.setColor(0.7, 0.7, 0.7, 0.9 * self.alpha)
        love.graphics.print("No unit selected", contentX, contentY)
    end
end

-- Draw settings tab
function AIControllerUI:drawSettingsTab()
    local contentX = self.x + 20
    local contentY = self.y + 85
    local contentWidth = self.width - 40
    
    -- Draw difficulty settings
    love.graphics.setColor(0.8, 0.8, 1.0, self.alpha)
    love.graphics.setFont(self.game.assets.fonts.small)
    love.graphics.print("Difficulty", contentX, contentY)
    contentY = contentY + 25
    
    -- Draw difficulty options
    for i, difficulty in ipairs(self.difficultyOptions) do
        local buttonX = contentX
        local buttonY = contentY
        local buttonWidth = 80
        local buttonHeight = 25
        
        -- Draw button background
        if self.selectedDifficulty == difficulty then
            love.graphics.setColor(0.3, 0.5, 0.8, 0.8 * self.alpha)
        else
            love.graphics.setColor(0.3, 0.3, 0.5, 0.8 * self.alpha)
        end
        
        love.graphics.rectangle("fill", buttonX, buttonY, buttonWidth, buttonHeight, 5, 5)
        
        -- Draw button text
        love.graphics.setColor(1, 1, 1, self.alpha)
        love.graphics.printf(difficulty:sub(1,1):upper() .. difficulty:sub(2), buttonX, buttonY + 5, buttonWidth, "center")
        
        contentY = contentY + 30
    end
    
    contentY = contentY + 10
    
    -- Draw behavior toggles
    love.graphics.setColor(0.8, 0.8, 1.0, self.alpha)
    love.graphics.print("AI Behavior", contentX, contentY)
    contentY = contentY + 25
    
    -- Tactical planning toggle
    local toggleX = contentX
    local toggleY = contentY
    local toggleWidth = 20
    local toggleHeight = 20
    
    -- Draw toggle background
    if self.enableTacticalPlanning then
        love.graphics.setColor(0.3, 0.8, 0.3, 0.8 * self.alpha)
    else
        love.graphics.setColor(0.8, 0.3, 0.3, 0.8 * self.alpha)
    end
    
    love.graphics.rectangle("fill", toggleX, toggleY, toggleWidth, toggleHeight, 3, 3)
    
    -- Draw toggle label
    love.graphics.setColor(0.7, 0.7, 0.7, 0.9 * self.alpha)
    love.graphics.print("Enable Tactical Planning", toggleX + 30, toggleY)
    contentY = contentY + 30
    
    -- Memory toggle
    toggleY = contentY
    
    -- Draw toggle background
    if self.enableMemory then
        love.graphics.setColor(0.3, 0.8, 0.3, 0.8 * self.alpha)
    else
        love.graphics.setColor(0.8, 0.3, 0.3, 0.8 * self.alpha)
    end
    
    love.graphics.rectangle("fill", toggleX, toggleY, toggleWidth, toggleHeight, 3, 3)
    
    -- Draw toggle label
    love.graphics.setColor(0.7, 0.7, 0.7, 0.9 * self.alpha)
    love.graphics.print("Enable Memory System", toggleX + 30, toggleY)
    contentY = contentY + 30
    
    -- Coordination toggle
    toggleY = contentY
    
    -- Draw toggle background
    if self.enableCoordination then
        love.graphics.setColor(0.3, 0.8, 0.3, 0.8 * self.alpha)
    else
        love.graphics.setColor(0.8, 0.3, 0.3, 0.8 * self.alpha)
    end
    
    love.graphics.rectangle("fill", toggleX, toggleY, toggleWidth, toggleHeight, 3, 3)
    
    -- Draw toggle label
    love.graphics.setColor(0.7, 0.7, 0.7, 0.9 * self.alpha)
    love.graphics.print("Enable Unit Coordination", toggleX + 30, toggleY)
    contentY = contentY + 40
    
    -- Draw apply button
    local buttonX = contentX + 50
    local buttonY = contentY
    local buttonWidth = 100
    local buttonHeight = 30
    
    love.graphics.setColor(0.3, 0.5, 0.8, 0.8 * self.alpha)
    love.graphics.rectangle("fill", buttonX, buttonY, buttonWidth, buttonHeight, 5, 5)
    
    love.graphics.setColor(1, 1, 1, self.alpha)
    love.graphics.printf("Apply Settings", buttonX, buttonY + 7, buttonWidth, "center")
end

-- Draw debug tab
function AIControllerUI:drawDebugTab()
    local contentX = self.x + 20
    local contentY = self.y + 85
    local contentWidth = self.width - 40
    
    -- Draw visualization toggles
    love.graphics.setColor(0.8, 0.8, 1.0, self.alpha)
    love.graphics.setFont(self.game.assets.fonts.small)
    love.graphics.print("Visualizations", contentX, contentY)
    contentY = contentY + 25
    
    -- Threat map toggle
    local toggleX = contentX
    local toggleY = contentY
    local toggleWidth = 20
    local toggleHeight = 20
    
    -- Draw toggle background
    if self.showThreatMap then
        love.graphics.setColor(0.3, 0.8, 0.3, 0.8 * self.alpha)
    else
        love.graphics.setColor(0.8, 0.3, 0.3, 0.8 * self.alpha)
    end
    
    love.graphics.rectangle("fill", toggleX, toggleY, toggleWidth, toggleHeight, 3, 3)
    
    -- Draw toggle label
    love.graphics.setColor(0.7, 0.7, 0.7, 0.9 * self.alpha)
    love.graphics.print("Show Threat Map", toggleX + 30, toggleY)
    contentY = contentY + 30
    
    -- Opportunity map toggle
    toggleY = contentY
    
    -- Draw toggle background
    if self.showOpportunityMap then
        love.graphics.setColor(0.3, 0.8, 0.3, 0.8 * self.alpha)
    else
        love.graphics.setColor(0.8, 0.3, 0.3, 0.8 * self.alpha)
    end
    
    love.graphics.rectangle("fill", toggleX, toggleY, toggleWidth, toggleHeight, 3, 3)
    
    -- Draw toggle label
    love.graphics.setColor(0.7, 0.7, 0.7, 0.9 * self.alpha)
    love.graphics.print("Show Opportunity Map", toggleX + 30, toggleY)
    contentY = contentY + 30
    
    -- Target priority toggle
    toggleY = contentY
    
    -- Draw toggle background
    if self.showTargetPriority then
        love.graphics.setColor(0.3, 0.8, 0.3, 0.8 * self.alpha)
    else
        love.graphics.setColor(0.8, 0.3, 0.3, 0.8 * self.alpha)
    end
    
    love.graphics.rectangle("fill", toggleX, toggleY, toggleWidth, toggleHeight, 3, 3)
    
    -- Draw toggle label
    love.graphics.setColor(0.7, 0.7, 0.7, 0.9 * self.alpha)
    love.graphics.print("Show Target Priority", toggleX + 30, toggleY)
    contentY = contentY + 30
    
    -- Decision tree toggle
    toggleY = contentY
    
    -- Draw toggle background
    if self.showDecisionTree then
        love.graphics.setColor(0.3, 0.8, 0.3, 0.8 * self.alpha)
    else
        love.graphics.setColor(0.8, 0.3, 0.3, 0.8 * self.alpha)
    end
    
    love.graphics.rectangle("fill", toggleX, toggleY, toggleWidth, toggleHeight, 3, 3)
    
    -- Draw toggle label
    love.graphics.setColor(0.7, 0.7, 0.7, 0.9 * self.alpha)
    love.graphics.print("Show Decision Tree", toggleX + 30, toggleY)
    contentY = contentY + 40
    
    -- Draw debug info
    love.graphics.setColor(0.8, 0.8, 1.0, self.alpha)
    love.graphics.print("Debug Info", contentX, contentY)
    contentY = contentY + 25
    
    if self.enemyAI then
        local debugInfo = self.enemyAI:getDebugInfo()
        
        for key, value in pairs(debugInfo) do
            love.graphics.setColor(0.7, 0.7, 0.7, 0.9 * self.alpha)
            love.graphics.print(key .. ": " .. tostring(value), contentX, contentY)
            contentY = contentY + 20
            
            if contentY > self.y + self.height - 20 then
                break -- Prevent drawing outside the UI
            end
        end
    else
        love.graphics.setColor(0.7, 0.7, 0.7, 0.9 * self.alpha)
        love.graphics.print("AI system not available", contentX, contentY)
    end
end

-- Draw history tab
function AIControllerUI:drawHistoryTab()
    local contentX = self.x + 20
    local contentY = self.y + 85
    local contentWidth = self.width - 40
    
    -- Draw decision history
    love.graphics.setColor(0.8, 0.8, 1.0, self.alpha)
    love.graphics.setFont(self.game.assets.fonts.small)
    love.graphics.print("Decision History", contentX, contentY)
    contentY = contentY + 25
    
    if #self.decisionHistory > 0 then
        for i, decision in ipairs(self.decisionHistory) do
            -- Draw decision background
            love.graphics.setColor(0.25, 0.25, 0.35, 0.8 * self.alpha)
            love.graphics.rectangle("fill", contentX, contentY, contentWidth, 40, 3, 3)
            
            -- Draw decision text
            love.graphics.setColor(0.7, 0.7, 0.7, 0.9 * self.alpha)
            love.graphics.print("Turn " .. decision.turn .. ": " .. decision.unitType, contentX + 5, contentY + 5)
            love.graphics.print(decision.action, contentX + 5, contentY + 20)
            
            contentY = contentY + 45
            
            if contentY > self.y + self.height - 20 then
                break -- Prevent drawing outside the UI
            end
        end
    else
        love.graphics.setColor(0.7, 0.7, 0.7, 0.9 * self.alpha)
        love.graphics.print("No decisions recorded yet", contentX, contentY)
    end
    
    -- Draw clear history button
    if #self.decisionHistory > 0 then
        local buttonX = contentX + 50
        local buttonY = self.y + self.height - 40
        local buttonWidth = 100
        local buttonHeight = 25
        
        love.graphics.setColor(0.8, 0.3, 0.3, 0.8 * self.alpha)
        love.graphics.rectangle("fill", buttonX, buttonY, buttonWidth, buttonHeight, 5, 5)
        
        love.graphics.setColor(1, 1, 1, self.alpha)
        love.graphics.printf("Clear History", buttonX, buttonY + 5, buttonWidth, "center")
    end
end

-- Handle mouse press
function AIControllerUI:mousepressed(x, y, button)
    if not self.visible then return false end
    
    -- Check if close button was clicked
    if x >= self.x + self.width - 30 and x <= self.x + self.width - 10 and
       y >= self.y + 10 and y <= self.y + 30 then
        self:hide()
        return true
    end
    
    -- Check if a tab was clicked
    local tabs = {
        {id = "status", name = "Status"},
        {id = "settings", name = "Settings"},
        {id = "debug", name = "Debug"},
        {id = "history", name = "History"}
    }
    
    local tabWidth = 65
    local tabHeight = 25
    local tabY = self.y + 50
    
    for i, tab in ipairs(tabs) do
        local tabX = self.x + 10 + (i-1) * (tabWidth + 5)
        
        if x >= tabX and x <= tabX + tabWidth and
           y >= tabY and y <= tabY + tabHeight then
            self.currentTab = tab.id
            return true
        end
    end
    
    -- Check tab-specific interactions
    if self.currentTab == "settings" then
        -- Check difficulty buttons
        local contentX = self.x + 20
        local contentY = self.y + 85 + 25
        
        for i, difficulty in ipairs(self.difficultyOptions) do
            local buttonX = contentX
            local buttonY = contentY + (i-1) * 30
            local buttonWidth = 80
            local buttonHeight = 25
            
            if x >= buttonX and x <= buttonX + buttonWidth and
               y >= buttonY and y <= buttonY + buttonHeight then
                self.selectedDifficulty = difficulty
                return true
            end
        end
        
        -- Check behavior toggles
        local toggleX = contentX
        local toggleY = contentY + #self.difficultyOptions * 30 + 35
        local toggleWidth = 20
        local toggleHeight = 20
        
        -- Tactical planning toggle
        if x >= toggleX and x <= toggleX + toggleWidth and
           y >= toggleY and y <= toggleY + toggleHeight then
            self.enableTacticalPlanning = not self.enableTacticalPlanning
            return true
        end
        
        -- Memory toggle
        toggleY = toggleY + 30
        if x >= toggleX and x <= toggleX + toggleWidth and
           y >= toggleY and y <= toggleY + toggleHeight then
            self.enableMemory = not self.enableMemory
            return true
        end
        
        -- Coordination toggle
        toggleY = toggleY + 30
        if x >= toggleX and x <= toggleX + toggleWidth and
           y >= toggleY and y <= toggleY + toggleHeight then
            self.enableCoordination = not self.enableCoordination
            return true
        end
        
        -- Apply button
        local buttonX = contentX + 50
        local buttonY = toggleY + 40
        local buttonWidth = 100
        local buttonHeight = 30
        
        if x >= buttonX and x <= buttonX + buttonWidth and
           y >= buttonY and y <= buttonY + buttonHeight then
            self:applySettings()
            return true
        end
    elseif self.currentTab == "debug" then
        -- Check visualization toggles
        local contentX = self.x + 20
        local contentY = self.y + 85 + 25
        local toggleX = contentX
        local toggleWidth = 20
        local toggleHeight = 20
        
        -- Threat map toggle
        local toggleY = contentY
        if x >= toggleX and x <= toggleX + toggleWidth and
           y >= toggleY and y <= toggleY + toggleHeight then
            self.showThreatMap = not self.showThreatMap
            return true
        end
        
        -- Opportunity map toggle
        toggleY = toggleY + 30
        if x >= toggleX and x <= toggleX + toggleWidth and
           y >= toggleY and y <= toggleY + toggleHeight then
            self.showOpportunityMap = not self.showOpportunityMap
            return true
        end
        
        -- Target priority toggle
        toggleY = toggleY + 30
        if x >= toggleX and x <= toggleX + toggleWidth and
           y >= toggleY and y <= toggleY + toggleHeight then
            self.showTargetPriority = not self.showTargetPriority
            return true
        end
        
        -- Decision tree toggle
        toggleY = toggleY + 30
        if x >= toggleX and x <= toggleX + toggleWidth and
           y >= toggleY and y <= toggleY + toggleHeight then
            self.showDecisionTree = not self.showDecisionTree
            return true
        end
    elseif self.currentTab == "history" then
        -- Check clear history button
        if #self.decisionHistory > 0 then
            local contentX = self.x + 20
            local buttonX = contentX + 50
            local buttonY = self.y + self.height - 40
            local buttonWidth = 100
            local buttonHeight = 25
            
            if x >= buttonX and x <= buttonX + buttonWidth and
               y >= buttonY and y <= buttonY + buttonHeight then
                self:clearDecisionHistory()
                return true
            end
        end
    end
    
    return false
end

-- Apply settings
function AIControllerUI:applySettings()
    if not self.enemyAI then return end
    
    -- Apply difficulty
    self.enemyAI:setDifficulty(self.selectedDifficulty)
    
    -- Apply behavior settings
    self.enemyAI.enableTacticalPlanning = self.enableTacticalPlanning
    self.enemyAI.enableMemory = self.enableMemory
    self.enemyAI.enableCoordination = self.enableCoordination
    
    -- Notify user
    print("AI settings applied")
end

-- Clear decision history
function AIControllerUI:clearDecisionHistory()
    self.decisionHistory = {}
end

-- Record a decision
function AIControllerUI:recordDecision(unit, action)
    if not unit then return end
    
    local decision = {
        turn = self.enemyAI and self.enemyAI.currentTurn or 0,
        unitType = unit.unitType,
        action = action
    }
    
    -- Add to history
    table.insert(self.decisionHistory, 1, decision)
    
    -- Limit history size
    while #self.decisionHistory > self.maxHistoryEntries do
        table.remove(self.decisionHistory)
    end
end

-- Set focused unit
function AIControllerUI:setFocusedUnit(unit)
    self.focusedUnit = unit
end

-- Connect to enemy AI
function AIControllerUI:connectToEnemyAI(enemyAI)
    self.enemyAI = enemyAI
    
    if enemyAI then
        -- Set initial values from AI
        self.selectedDifficulty = enemyAI.difficulty
        self.enableTacticalPlanning = enemyAI.enableTacticalPlanning or true
        self.enableMemory = enemyAI.enableMemory or true
        self.enableCoordination = enemyAI.enableCoordination or true
        
        -- Hook into AI decision making
        local originalMakeDecision = enemyAI.makeDecision
        
        enemyAI.makeDecision = function(self, unit, aiType, grid, ...)
            local decision = originalMakeDecision(self, unit, aiType, grid, ...)
            
            -- Record decision
            if decision then
                AIControllerUI:recordDecision(unit, decision.type .. " " .. (decision.target and ("target: " .. decision.target.unitType) or ""))
            end
            
            return decision
        end
    end
end

-- Draw visualizations on game grid
function AIControllerUI:drawVisualizations(grid)
    if not self.visible or not self.enemyAI or not grid then return end
    
    -- Draw threat map
    if self.showThreatMap and self.enemyAI.threatMap then
        for y = 1, grid.height do
            for x = 1, grid.width do
                local threat = self.enemyAI.threatMap[y][x] or 0
                if threat > 0 then
                    local screenX, screenY = grid:gridToScreen(x, y)
                    
                    -- Draw threat indicator
                    love.graphics.setColor(0.8, 0.2, 0.2, 0.3 * math.min(1, threat / 5))
                    love.graphics.rectangle("fill", screenX, screenY, grid.tileSize, grid.tileSize)
                    
                    -- Draw threat value
                    if threat >= 2 then
                        love.graphics.setColor(1, 1, 1, 0.7)
                        love.graphics.setFont(self.game.assets.fonts.small)
                        love.graphics.printf(string.format("%.1f", threat), screenX, screenY + grid.tileSize/2 - 10, grid.tileSize, "center")
                    end
                end
            end
        end
    end
    
    -- Draw opportunity map
    if self.showOpportunityMap and self.enemyAI.opportunityMap then
        for y = 1, grid.height do
            for x = 1, grid.width do
                local opportunity = self.enemyAI.opportunityMap[y][x] or 0
                if opportunity > 0 then
                    local screenX, screenY = grid:gridToScreen(x, y)
                    
                    -- Draw opportunity indicator
                    love.graphics.setColor(0.2, 0.8, 0.2, 0.3 * math.min(1, opportunity / 5))
                    love.graphics.rectangle("fill", screenX, screenY, grid.tileSize, grid.tileSize)
                    
                    -- Draw opportunity value
                    if opportunity >= 2 then
                        love.graphics.setColor(1, 1, 1, 0.7)
                        love.graphics.setFont(self.game.assets.fonts.small)
                        love.graphics.printf(string.format("%.1f", opportunity), screenX, screenY + grid.tileSize/2 - 10, grid.tileSize, "center")
                    end
                end
            end
        end
    end
    
    -- Draw target priority
    if self.showTargetPriority and self.focusedUnit then
        local aiType = self.enemyAI:getAITypeForUnit(self.focusedUnit)
        local targetPriority = self.enemyAI.aiTypes[aiType].targetPriority
        
        -- Find all player units
        for y = 1, grid.height do
            for x = 1, grid.width do
                local entity = grid:getEntity(x, y)
                if entity and entity.faction == "player" then
                    local screenX, screenY = grid:gridToScreen(x, y)
                    
                    -- Find priority for this unit type
                    local priority = 0
                    for i, unitType in ipairs(targetPriority) do
                        if entity.unitType == unitType then
                            priority = #targetPriority - i + 1
                            break
                        end
                    end
                    
                    -- Draw priority indicator
                    if priority > 0 then
                        love.graphics.setColor(1, 0.5, 0, 0.7)
                        love.graphics.setFont(self.game.assets.fonts.medium)
                        love.graphics.printf(tostring(priority), screenX, screenY - 20, grid.tileSize, "center")
                    end
                end
            end
        end
    end
    
    -- Draw decision tree
    if self.showDecisionTree and self.focusedUnit and self.enemyAI.decisionTrees and self.enemyAI.decisionTrees[self.focusedUnit.id] then
        local tree = self.enemyAI.decisionTrees[self.focusedUnit.id]
        local screenX, screenY = grid:gridToScreen(self.focusedUnit.x, self.focusedUnit.y)
        
        -- Draw decision tree lines
        love.graphics.setColor(0.8, 0.8, 0.2, 0.7)
        love.graphics.setLineWidth(2)
        
        for _, decision in ipairs(tree) do
            if decision.targetX and decision.targetY then
                local targetScreenX, targetScreenY = grid:gridToScreen(decision.targetX, decision.targetY)
                love.graphics.line(screenX + grid.tileSize/2, screenY + grid.tileSize/2, 
                                  targetScreenX + grid.tileSize/2, targetScreenY + grid.tileSize/2)
                
                -- Draw decision weight
                local midX = (screenX + targetScreenX) / 2 + grid.tileSize/2
                local midY = (screenY + targetScreenY) / 2 + grid.tileSize/2
                
                love.graphics.setColor(1, 1, 1, 0.8)
                love.graphics.setFont(self.game.assets.fonts.small)
                love.graphics.printf(string.format("%.2f", decision.weight), midX - 20, midY - 10, 40, "center")
            end
        end
    end
end

return AIControllerUI
