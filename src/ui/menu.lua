-- Menu UI Component for Nightfall Chess
-- Provides menu interfaces with options, panels, and navigation

local class = require("lib.middleclass.middleclass")
local timer = require("lib.hump.timer")
local Button = require("src.ui.button")

local Menu = class("Menu")

function Menu:initialize(game)
    self.game = game
    
    -- Menu properties
    self.visible = false
    self.active = false
    self.title = ""
    self.buttons = {}
    self.panels = {}
    self.currentPanel = nil
    self.alpha = 0
    
    -- Styling
    self.backgroundColor = {0.1, 0.1, 0.2, 0.9}
    self.borderColor = {0.5, 0.5, 0.7, 1}
    self.titleColor = {0.9, 0.7, 0.2, 1}
    
    -- Fonts
    self.titleFont = game.assets.fonts.title
    self.subtitleFont = game.assets.fonts.medium
    
    -- Dimensions
    self.width = 600
    self.height = 400
    self.x = (love.graphics.getWidth() - self.width) / 2
    self.y = (love.graphics.getHeight() - self.height) / 2
end

-- Show menu
function Menu:show(title, panelName)
    self.title = title or "Menu"
    self.visible = true
    self.active = true
    
    -- Start animation
    self.alpha = 0
    timer.tween(0.3, self, {alpha = 1}, 'out-quad')
    
    -- Show specified panel or first panel
    if panelName and self.panels[panelName] then
        self:showPanel(panelName)
    elseif next(self.panels) then
        local firstPanel = next(self.panels)
        self:showPanel(firstPanel)
    end
    
    -- Animate buttons
    for _, button in pairs(self.buttons) do
        button:show(0.5)
    end
    
    return self
end

-- Hide menu
function Menu:hide()
    timer.tween(0.3, self, {alpha = 0}, 'out-quad', function()
        self.visible = false
        self.active = false
    end)
    
    -- Hide buttons
    for _, button in pairs(self.buttons) do
        button:hide(0.2)
    end
    
    return self
end

-- Update menu
function Menu:update(dt)
    if not self.visible then return end
    
    -- Update timers
    timer.update(dt)
    
    -- Update buttons
    for _, button in pairs(self.buttons) do
        button:update(dt)
    end
    
    -- Update current panel
    if self.currentPanel and self.panels[self.currentPanel] and self.panels[self.currentPanel].update then
        self.panels[self.currentPanel].update(dt)
    end
end

-- Draw menu
function Menu:draw()
    if not self.visible then return end
    
    -- Draw semi-transparent background overlay
    love.graphics.setColor(0, 0, 0, 0.7 * self.alpha)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    
    -- Draw menu background
    love.graphics.setColor(self.backgroundColor[1], self.backgroundColor[2], self.backgroundColor[3], self.backgroundColor[4] * self.alpha)
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height, 10, 10)
    
    -- Draw menu border
    love.graphics.setColor(self.borderColor[1], self.borderColor[2], self.borderColor[3], self.borderColor[4] * self.alpha)
    love.graphics.rectangle("line", self.x, self.y, self.width, self.height, 10, 10)
    
    -- Draw title
    love.graphics.setColor(self.titleColor[1], self.titleColor[2], self.titleColor[3], self.titleColor[4] * self.alpha)
    love.graphics.setFont(self.titleFont)
    love.graphics.printf(self.title, self.x, self.y + 20, self.width, "center")
    
    -- Draw buttons
    for _, button in pairs(self.buttons) do
        button:draw()
    end
    
    -- Draw current panel
    if self.currentPanel and self.panels[self.currentPanel] and self.panels[self.currentPanel].draw then
        self.panels[self.currentPanel].draw()
    end
end

-- Add button to menu
function Menu:addButton(id, params)
    params = params or {}
    params.id = id
    
    -- Create button
    self.buttons[id] = Button:new(params)
    
    return self.buttons[id]
end

-- Add panel to menu
function Menu:addPanel(name, panel)
    self.panels[name] = panel
    
    -- Set initial visibility
    if panel.setVisible then
        panel.setVisible(false)
    end
    
    return self
end

-- Show specific panel
function Menu:showPanel(name)
    -- Hide current panel
    if self.currentPanel and self.panels[self.currentPanel] then
        if self.panels[self.currentPanel].setVisible then
            self.panels[self.currentPanel].setVisible(false)
        end
    end
    
    -- Show new panel
    self.currentPanel = name
    
    if self.panels[name] then
        if self.panels[name].setVisible then
            self.panels[name].setVisible(true)
        end
    end
    
    return self
end

-- Handle mouse press
function Menu:mousepressed(x, y, button)
    if not self.visible or not self.active then return false end
    
    -- Check buttons
    for _, btn in pairs(self.buttons) do
        if btn:mousepressed(x, y, button) then
            return true
        end
    end
    
    -- Check current panel
    if self.currentPanel and self.panels[self.currentPanel] and self.panels[self.currentPanel].mousepressed then
        if self.panels[self.currentPanel].mousepressed(x, y, button) then
            return true
        end
    end
    
    -- Check if click is inside menu area
    if x >= self.x and x <= self.x + self.width and
       y >= self.y and y <= self.y + self.height then
        return true
    end
    
    return false
end

-- Handle mouse release
function Menu:mousereleased(x, y, button)
    if not self.visible or not self.active then return false end
    
    -- Check buttons
    for _, btn in pairs(self.buttons) do
        if btn:mousereleased(x, y, button) then
            return true
        end
    end
    
    -- Check current panel
    if self.currentPanel and self.panels[self.currentPanel] and self.panels[self.currentPanel].mousereleased then
        if self.panels[self.currentPanel].mousereleased(x, y, button) then
            return true
        end
    end
    
    return false
end

-- Handle key press
function Menu:keypressed(key)
    if not self.visible or not self.active then return false end
    
    -- Handle escape key to close menu
    if key == "escape" then
        self:hide()
        return true
    end
    
    -- Check current panel
    if self.currentPanel and self.panels[self.currentPanel] and self.panels[self.currentPanel].keypressed then
        if self.panels[self.currentPanel].keypressed(key) then
            return true
        end
    end
    
    return false
end

-- Resize menu
function Menu:resize(width, height)
    self.width = math.min(600, width - 40)
    self.height = math.min(400, height - 40)
    self.x = (width - self.width) / 2
    self.y = (height - self.height) / 2
    
    -- Resize panels
    for name, panel in pairs(self.panels) do
        if panel.resize then
            panel.resize(width, height)
        end
    end
    
    return self
end

-- Create a main menu
function Menu:createMainMenu()
    -- Clear existing elements
    self.buttons = {}
    self.panels = {}
    
    -- Set title
    self.title = "Nightfall Chess"
    
    -- Create buttons
    local buttonWidth = 200
    local buttonHeight = 50
    local buttonX = self.x + (self.width - buttonWidth) / 2
    local startY = self.y + 120
    local spacing = 20
    
    -- New Game button
    self:addButton("newGame", {
        x = buttonX,
        y = startY,
        width = buttonWidth,
        height = buttonHeight,
        text = "New Game",
        font = self.game.assets.fonts.medium,
        callback = function()
            -- Switch to game state
            self:hide()
            -- Implementation would call gamestate.switch to the game state
        end
    })
    
    -- Continue button (disabled if no save)
    self:addButton("continue", {
        x = buttonX,
        y = startY + buttonHeight + spacing,
        width = buttonWidth,
        height = buttonHeight,
        text = "Continue",
        font = self.game.assets.fonts.medium,
        enabled = false, -- Would be enabled if save exists
        callback = function()
            -- Load saved game
            self:hide()
            -- Implementation would load save and switch to game state
        end
    })
    
    -- Options button
    self:addButton("options", {
        x = buttonX,
        y = startY + (buttonHeight + spacing) * 2,
        width = buttonWidth,
        height = buttonHeight,
        text = "Options",
        font = self.game.assets.fonts.medium,
        callback = function()
            -- Show options panel
            self:showPanel("options")
        end
    })
    
    -- Credits button
    self:addButton("credits", {
        x = buttonX,
        y = startY + (buttonHeight + spacing) * 3,
        width = buttonWidth,
        height = buttonHeight,
        text = "Credits",
        font = self.game.assets.fonts.medium,
        callback = function()
            -- Show credits panel
            self:showPanel("credits")
        end
    })
    
    -- Quit button
    self:addButton("quit", {
        x = buttonX,
        y = startY + (buttonHeight + spacing) * 4,
        width = buttonWidth,
        height = buttonHeight,
        text = "Quit",
        font = self.game.assets.fonts.medium,
        callback = function()
            -- Quit game
            love.event.quit()
        end
    })
    
    -- Create options panel
    local optionsPanel = {
        buttons = {},
        
        initialize = function(self)
            -- Volume slider, resolution options, etc. would go here
            self.buttons.back = Button:new({
                x = buttonX,
                y = startY + (buttonHeight + spacing) * 4,
                width = buttonWidth,
                height = buttonHeight,
                text = "Back",
                font = self.game.assets.fonts.medium,
                callback = function()
                    -- Return to main menu
                    self:showPanel("main")
                end
            })
        end,
        
        update = function(dt)
            for _, button in pairs(self.buttons) do
                button:update(dt)
            end
        end,
        
        draw = function()
            -- Draw panel title
            love.graphics.setColor(self.titleColor[1], self.titleColor[2], self.titleColor[3], self.titleColor[4] * self.alpha)
            love.graphics.setFont(self.subtitleFont)
            love.graphics.printf("Options", self.x, self.y + 80, self.width, "center")
            
            -- Draw options
            -- Volume, resolution, etc. would be drawn here
            
            -- Draw buttons
            for _, button in pairs(self.buttons) do
                button:draw()
            end
        end,
        
        setVisible = function(visible)
            for _, button in pairs(self.buttons) do
                button:setVisible(visible)
            end
        end,
        
        mousepressed = function(x, y, button)
            for _, btn in pairs(self.buttons) do
                if btn:mousepressed(x, y, button) then
                    return true
                end
            end
            return false
        end,
        
        mousereleased = function(x, y, button)
            for _, btn in pairs(self.buttons) do
                if btn:mousereleased(x, y, button) then
                    return true
                end
            end
            return false
        end
    }
    
    -- Create credits panel
    local creditsPanel = {
        setVisible = function(visible) end,
        
        update = function(dt) end,
        
        draw = function()
            -- Draw panel title
            love.graphics.setColor(self.titleColor[1], self.titleColor[2], self.titleColor[3], self.titleColor[4] * self.alpha)
            love.graphics.setFont(self.subtitleFont)
            love.graphics.printf("Credits", self.x, self.y + 80, self.width, "center")
            
            -- Draw credits text
            love.graphics.setColor(1, 1, 1, self.alpha)
            love.graphics.setFont(self.game.assets.fonts.small)
            
            local creditsText = {
                "Nightfall Chess",
                "A strategic roguelite chess game",
                "",
                "Created by: The Nightfall Team",
                "",
                "Programming: Manus AI",
                "Game Design: Manus AI",
                "Art: Placeholder Assets",
                "",
                "Made with LÖVE framework",
                "",
                "Press ESC to return"
            }
            
            local y = self.y + 120
            for _, line in ipairs(creditsText) do
                love.graphics.printf(line, self.x + 50, y, self.width - 100, "center")
                y = y + 20
            end
        end,
        
        mousepressed = function(x, y, button)
            return false
        end,
        
        mousereleased = function(x, y, button)
            return false
        end,
        
        keypressed = function(key)
            if key == "escape" then
                self:showPanel("main")
                return true
            end
            return false
        end
    }
    
    -- Add panels to menu
    self:addPanel("main", {
        setVisible = function(visible) end,
        update = function(dt) end,
        draw = function() end
    })
    self:addPanel("options", optionsPanel)
    self:addPanel("credits", creditsPanel)
    
    -- Initialize panels
    if optionsPanel.initialize then
        optionsPanel.initialize(self)
    end
    
    -- Show main panel by default
    self:showPanel("main")
    
    return self
end

-- Create a pause menu
function Menu:createPauseMenu()
    -- Clear existing elements
    self.buttons = {}
    self.panels = {}
    
    -- Set title
    self.title = "Paused"
    
    -- Create buttons
    local buttonWidth = 200
    local buttonHeight = 50
    local buttonX = self.x + (self.width - buttonWidth) / 2
    local startY = self.y + 120
    local spacing = 20
    
    -- Resume button
    self:addButton("resume", {
        x = buttonX,
        y = startY,
        width = buttonWidth,
        height = buttonHeight,
        text = "Resume",
        font = self.game.assets.fonts.medium,
        callback = function()
            -- Hide menu and resume game
            self:hide()
        end
    })
    
    -- Options button
    self:addButton("options", {
        x = buttonX,
        y = startY + buttonHeight + spacing,
        width = buttonWidth,
        height = buttonHeight,
        text = "Options",
        font = self.game.assets.fonts.medium,
        callback = function()
            -- Show options panel
            self:showPanel("options")
        end
    })
    
    -- Save button
    self:addButton("save", {
        x = buttonX,
        y = startY + (buttonHeight + spacing) * 2,
        width = buttonWidth,
        height = buttonHeight,
        text = "Save Game",
        font = self.game.assets.fonts.medium,
        callback = function()
            -- Save game
            -- Implementation would save game state
            self:hide()
        end
    })
    
    -- Main Menu button
    self:addButton("mainMenu", {
        x = buttonX,
        y = startY + (buttonHeight + spacing) * 3,
        width = buttonWidth,
        height = buttonHeight,
        text = "Main Menu",
        font = self.game.assets.fonts.medium,
        callback = function()
            -- Return to main menu
            self:hide()
            -- Implementation would switch to menu state
        end
    })
    
    -- Create options panel (similar to main menu options)
    local optionsPanel = {
        buttons = {},
        
        initialize = function(self)
            self.buttons.back = Button:new({
                x = buttonX,
                y = startY + (buttonHeight + spacing) * 3,
                width = buttonWidth,
                height = buttonHeight,
                text = "Back",
                font = self.game.assets.fonts.medium,
                callback = function()
                    -- Return to pause menu
                    self:showPanel("main")
                end
            })
        end,
        
        update = function(dt)
            for _, button in pairs(self.buttons) do
                button:update(dt)
            end
        end,
        
        draw = function()
            -- Draw panel title
            love.graphics.setColor(self.titleColor[1], self.titleColor[2], self.titleColor[3], self.titleColor[4] * self.alpha)
            love.graphics.setFont(self.subtitleFont)
            love.graphics.printf("Options", self.x, self.y + 80, self.width, "center")
            
            -- Draw options
            -- Volume, resolution, etc. would be drawn here
            
            -- Draw buttons
            for _, button in pairs(self.buttons) do
                button:draw()
            end
        end,
        
        setVisible = function(visible)
            for _, button in pairs(self.buttons) do
                button:setVisible(visible)
            end
        end,
        
        mousepressed = function(x, y, button)
            for _, btn in pairs(self.buttons) do
                if btn:mousepressed(x, y, button) then
                    return true
                end
            end
            return false
        end,
        
        mousereleased = function(x, y, button)
            for _, btn in pairs(self.buttons) do
                if btn:mousereleased(x, y, button) then
                    return true
                end
            end
            return false
        end
    }
    
    -- Add panels to menu
    self:addPanel("main", {
        setVisible = function(visible) end,
        update = function(dt) end,
        draw = function() end
    })
    self:addPanel("options", optionsPanel)
    
    -- Initialize panels
    if optionsPanel.initialize then
        optionsPanel.initialize(self)
    end
    
    -- Show main panel by default
    self:showPanel("main")
    
    return self
end

return Menu
