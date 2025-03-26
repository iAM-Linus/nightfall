-- Debug Menu for Nightfall Chess
-- Provides access to debugging and optimization tools

local class = require("lib.middleclass.middleclass")

local DebugMenu = class("DebugMenu")

function DebugMenu:initialize(game)
    self.game = game
    
    -- UI state
    self.visible = false
    self.alpha = 0
    self.targetAlpha = 0
    
    -- Layout
    self.width = 300
    self.height = 400
    self.x = 20
    self.y = 20
    
    -- Menu options
    self.options = {}
    
    -- Default options
    self:addOption("Toggle FPS Display", function()
        self.game.showFPS = not self.game.showFPS
        return self.game.showFPS
    end)
    
    -- Scroll position
    self.scrollY = 0
    self.maxScrollY = 0
    
    -- Active submenu
    self.activeSubmenu = nil
    
    -- Key binding to toggle menu (F12)
    self.toggleKey = "f12"
end

-- Add a menu option
function DebugMenu:addOption(name, callback, submenu)
    table.insert(self.options, {
        name = name,
        callback = callback,
        submenu = submenu
    })
end

-- Show debug menu
function DebugMenu:show()
    self.visible = true
    self.targetAlpha = 1
end

-- Hide debug menu
function DebugMenu:hide()
    self.targetAlpha = 0
    self.activeSubmenu = nil
end

-- Toggle debug menu
function DebugMenu:toggle()
    if self.visible and self.alpha > 0.5 then
        self:hide()
    else
        self:show()
    end
end

-- Update debug menu
function DebugMenu:update(dt)
    -- Animate alpha
    if self.alpha < self.targetAlpha then
        self.alpha = math.min(self.alpha + dt * 5, self.targetAlpha)
    elseif self.alpha > self.targetAlpha then
        self.alpha = math.max(self.alpha - dt * 5, self.targetAlpha)
        if self.alpha <= 0 then
            self.visible = false
        end
    end
    
    -- Update max scroll
    self.maxScrollY = math.max(0, #self.options * 40 - (self.height - 60))
    
    -- Clamp scroll position
    self.scrollY = math.max(0, math.min(self.scrollY, self.maxScrollY))
    
    -- Check for toggle key
    if love.keyboard.isDown(self.toggleKey) and not self.keyPressed then
        self:toggle()
        self.keyPressed = true
    elseif not love.keyboard.isDown(self.toggleKey) then
        self.keyPressed = false
    end
end

-- Draw debug menu
function DebugMenu:draw()
    if not self.visible then return end
    
    -- Draw background
    love.graphics.setColor(0.1, 0.1, 0.2, 0.95 * self.alpha)
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height, 10, 10)
    
    love.graphics.setColor(0.3, 0.3, 0.5, 0.8 * self.alpha)
    love.graphics.rectangle("line", self.x, self.y, self.width, self.height, 10, 10)
    
    -- Draw title
    love.graphics.setColor(1, 1, 1, self.alpha)
    love.graphics.setFont(self.game.assets.fonts.medium)
    love.graphics.print("Debug Menu", self.x + 20, self.y + 20)
    
    -- Set up scissor to clip options to the content area
    love.graphics.setScissor(self.x + 10, self.y + 60, self.width - 20, self.height - 70)
    
    -- Draw options
    if self.activeSubmenu then
        self:drawSubmenu()
    else
        self:drawMainMenu()
    end
    
    -- Reset scissor
    love.graphics.setScissor()
    
    -- Draw scroll indicators if needed
    if self.maxScrollY > 0 then
        if self.scrollY > 0 then
            love.graphics.setColor(1, 1, 1, 0.7 * self.alpha)
            love.graphics.polygon("fill", 
                self.x + self.width / 2, self.y + 65,
                self.x + self.width / 2 - 10, self.y + 75,
                self.x + self.width / 2 + 10, self.y + 75
            )
        end
        
        if self.scrollY < self.maxScrollY then
            love.graphics.setColor(1, 1, 1, 0.7 * self.alpha)
            love.graphics.polygon("fill", 
                self.x + self.width / 2, self.y + self.height - 15,
                self.x + self.width / 2 - 10, self.y + self.height - 25,
                self.x + self.width / 2 + 10, self.y + self.height - 25
            )
        end
    end
    
    -- Draw close button
    love.graphics.setColor(0.8, 0.2, 0.2, 0.8 * self.alpha)
    love.graphics.rectangle("fill", self.x + self.width - 30, self.y + 10, 20, 20, 3, 3)
    
    love.graphics.setColor(1, 1, 1, self.alpha)
    love.graphics.printf("X", self.x + self.width - 30, self.y + 12, 20, "center")
    
    -- Draw back button if in submenu
    if self.activeSubmenu then
        love.graphics.setColor(0.3, 0.3, 0.6, 0.8 * self.alpha)
        love.graphics.rectangle("fill", self.x + 10, self.y + self.height - 40, 80, 30, 5, 5)
        
        love.graphics.setColor(1, 1, 1, self.alpha)
        love.graphics.printf("Back", self.x + 10, self.y + self.height - 35, 80, "center")
    end
end

-- Draw main menu options
function DebugMenu:drawMainMenu()
    local contentX = self.x + 20
    local contentY = self.y + 60 - self.scrollY
    local contentWidth = self.width - 40
    
    for i, option in ipairs(self.options) do
        -- Skip if outside visible area
        if contentY + 40 < self.y + 60 or contentY > self.y + self.height - 10 then
            contentY = contentY + 40
            goto continue
        end
        
        -- Draw option background
        love.graphics.setColor(0.2, 0.2, 0.3, 0.8 * self.alpha)
        love.graphics.rectangle("fill", contentX - 10, contentY, contentWidth, 30, 5, 5)
        
        -- Draw option text
        love.graphics.setColor(1, 1, 1, self.alpha)
        love.graphics.setFont(self.game.assets.fonts.small)
        love.graphics.print(option.name, contentX, contentY + 7)
        
        -- Draw submenu indicator if applicable
        if option.submenu then
            love.graphics.print(">", contentX + contentWidth - 20, contentY + 7)
        end
        
        contentY = contentY + 40
        
        ::continue::
    end
end

-- Draw submenu options
function DebugMenu:drawSubmenu()
    local contentX = self.x + 20
    local contentY = self.y + 60 - self.scrollY
    local contentWidth = self.width - 40
    
    -- Draw submenu title
    love.graphics.setColor(0.3, 0.5, 0.8, 0.8 * self.alpha)
    love.graphics.rectangle("fill", contentX - 10, contentY, contentWidth, 30, 5, 5)
    
    love.graphics.setColor(1, 1, 1, self.alpha)
    love.graphics.setFont(self.game.assets.fonts.small)
    love.graphics.print(self.activeSubmenu.name, contentX, contentY + 7)
    
    contentY = contentY + 40
    
    -- Draw submenu options
    for i, option in ipairs(self.activeSubmenu.options) do
        -- Skip if outside visible area
        if contentY + 40 < self.y + 60 or contentY > self.y + self.height - 10 then
            contentY = contentY + 40
            goto continue
        end
        
        -- Draw option background
        love.graphics.setColor(0.2, 0.2, 0.3, 0.8 * self.alpha)
        love.graphics.rectangle("fill", contentX - 10, contentY, contentWidth, 30, 5, 5)
        
        -- Draw option text
        love.graphics.setColor(1, 1, 1, self.alpha)
        love.graphics.print(option.name, contentX, contentY + 7)
        
        -- Draw toggle state if applicable
        if option.isToggle then
            if option.state then
                love.graphics.setColor(0.3, 0.8, 0.3, 0.8 * self.alpha)
                love.graphics.print("ON", contentX + contentWidth - 30, contentY + 7)
            else
                love.graphics.setColor(0.8, 0.3, 0.3, 0.8 * self.alpha)
                love.graphics.print("OFF", contentX + contentWidth - 30, contentY + 7)
            end
        end
        
        contentY = contentY + 40
        
        ::continue::
    end
end

-- Handle mouse press
function DebugMenu:mousepressed(x, y, button)
    if not self.visible then return false end
    
    -- Check if close button was clicked
    if x >= self.x + self.width - 30 and x <= self.x + self.width - 10 and
       y >= self.y + 10 and y <= self.y + 30 then
        self:hide()
        return true
    end
    
    -- Check if back button was clicked when in submenu
    if self.activeSubmenu and
       x >= self.x + 10 and x <= self.x + 90 and
       y >= self.y + self.height - 40 and y <= self.y + self.height - 10 then
        self.activeSubmenu = nil
        return true
    end
    
    -- Check if an option was clicked
    if x >= self.x + 10 and x <= self.x + self.width - 10 and
       y >= self.y + 60 and y <= self.y + self.height - 10 then
        
        local clickY = y + self.scrollY - (self.y + 60)
        local optionIndex = math.floor(clickY / 40) + 1
        
        if self.activeSubmenu then
            -- Handle submenu option click
            if optionIndex > 0 and optionIndex <= #self.activeSubmenu.options then
                local option = self.activeSubmenu.options[optionIndex]
                
                if option.callback then
                    local result = option.callback()
                    
                    -- Update toggle state if applicable
                    if option.isToggle then
                        option.state = result
                    end
                end
                
                return true
            end
        else
            -- Handle main menu option click
            if optionIndex > 0 and optionIndex <= #self.options then
                local option = self.options[optionIndex]
                
                if option.submenu then
                    self.activeSubmenu = option.submenu
                    self.scrollY = 0
                    return true
                elseif option.callback then
                    option.callback()
                    return true
                end
            end
        end
    end
    
    return false
end

-- Handle mouse wheel
function DebugMenu:wheelmoved(x, y)
    if not self.visible then return false end
    
    -- Scroll options
    self.scrollY = self.scrollY - y * 20
    
    -- Clamp scroll position
    self.scrollY = math.max(0, math.min(self.scrollY, self.maxScrollY))
    
    return true
end

-- Create a submenu
function DebugMenu:createSubmenu(name)
    local submenu = {
        name = name,
        options = {}
    }
    
    return submenu
end

-- Add option to submenu
function DebugMenu:addSubmenuOption(submenu, name, callback, isToggle, initialState)
    table.insert(submenu.options, {
        name = name,
        callback = callback,
        isToggle = isToggle,
        state = initialState
    })
end

return DebugMenu
