-- Dialog System for Nightfall Chess
-- Handles in-game dialogs, conversations, and message boxes

local class = require("lib.middleclass.middleclass")
local timer = require("lib.hump.timer")

local Dialog = class("Dialog")

function Dialog:initialize(game)
    self.game = game
    
    -- Dialog properties
    self.active = false
    self.text = ""
    self.title = ""
    self.options = {}
    self.selectedOption = 1
    self.callback = nil
    self.portrait = nil
    
    -- Animation properties
    self.alpha = 0
    self.textProgress = 0
    self.textSpeed = 40 -- characters per second
    self.animating = false
    
    -- Dialog box dimensions and position
    self.width = 600
    self.height = 200
    self.x = (love.graphics.getWidth() - self.width) / 2
    self.y = love.graphics.getHeight() - self.height - 20
    
    -- Styling
    self.backgroundColor = {0.1, 0.1, 0.2, 0.9}
    self.borderColor = {0.5, 0.5, 0.7, 1}
    self.textColor = {0.9, 0.9, 1, 1}
    self.titleColor = {0.9, 0.7, 0.2, 1}
    self.optionColor = {0.7, 0.7, 0.9, 1}
    self.selectedOptionColor = {1, 0.8, 0.2, 1}
    
    -- Fonts
    self.titleFont = game.assets.fonts.medium
    self.textFont = game.assets.fonts.small
    self.optionFont = game.assets.fonts.small
end

-- Show a dialog
function Dialog:show(params)
    params = params or {}
    
    self.title = params.title or ""
    self.text = params.text or ""
    self.options = params.options or {}
    self.callback = params.callback
    self.portrait = params.portrait
    
    -- Reset dialog state
    self.active = true
    self.selectedOption = 1
    self.textProgress = 0
    self.animating = true
    
    -- Start animations
    self.alpha = 0
    timer.tween(0.3, self, {alpha = 1}, 'out-quad')
end

-- Hide the dialog
function Dialog:hide()
    timer.tween(0.3, self, {alpha = 0}, 'out-quad', function()
        self.active = false
    end)
end

-- Update dialog
function Dialog:update(dt)
    if not self.active then return end
    
    -- Update text animation
    if self.animating then
        self.textProgress = self.textProgress + self.textSpeed * dt
        if self.textProgress >= #self.text then
            self.textProgress = #self.text
            self.animating = false
        end
    end
    
    -- Update timers
    timer.update(dt)
end

-- Draw dialog
function Dialog:draw()
    if not self.active then return end
    
    -- Draw dialog background
    love.graphics.setColor(self.backgroundColor[1], self.backgroundColor[2], self.backgroundColor[3], self.backgroundColor[4] * self.alpha)
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height, 10, 10)
    
    -- Draw dialog border
    love.graphics.setColor(self.borderColor[1], self.borderColor[2], self.borderColor[3], self.borderColor[4] * self.alpha)
    love.graphics.rectangle("line", self.x, self.y, self.width, self.height, 10, 10)
    
    -- Draw portrait if available
    if self.portrait then
        local portraitSize = 80
        local portraitX = self.x + 20
        local portraitY = self.y + 20
        
        love.graphics.setColor(1, 1, 1, self.alpha)
        love.graphics.draw(self.portrait, portraitX, portraitY, 0, portraitSize / self.portrait:getWidth(), portraitSize / self.portrait:getHeight())
        
        -- Adjust text position when portrait is present
        self:drawText(portraitX + portraitSize + 20)
    else
        -- Draw text normally
        self:drawText(self.x + 20)
    end
    
    -- Draw "continue" indicator if text animation is complete and no options
    if not self.animating and #self.options == 0 then
        love.graphics.setColor(1, 1, 1, 0.7 + math.sin(love.timer.getTime() * 5) * 0.3)
        love.graphics.setFont(self.textFont)
        love.graphics.print("Press SPACE to continue", self.x + self.width - 200, self.y + self.height - 30)
    end
end

-- Draw dialog text content
function Dialog:drawText(startX)
    -- Draw title if present
    if self.title and self.title ~= "" then
        love.graphics.setColor(self.titleColor[1], self.titleColor[2], self.titleColor[3], self.titleColor[4] * self.alpha)
        love.graphics.setFont(self.titleFont)
        love.graphics.print(self.title, startX, self.y + 20)
    end
    
    -- Draw text (animated)
    love.graphics.setColor(self.textColor[1], self.textColor[2], self.textColor[3], self.textColor[4] * self.alpha)
    love.graphics.setFont(self.textFont)
    
    local displayText = self.text:sub(1, math.floor(self.textProgress))
    love.graphics.printf(displayText, startX, self.y + 50, self.width - 40 - (startX - self.x), "left")
    
    -- Draw options if text animation is complete
    if not self.animating and #self.options > 0 then
        self:drawOptions()
    end
end

-- Draw dialog options
function Dialog:drawOptions()
    local optionY = self.y + self.height - 20 - (#self.options * 25)
    
    for i, option in ipairs(self.options) do
        if i == self.selectedOption then
            love.graphics.setColor(self.selectedOptionColor[1], self.selectedOptionColor[2], self.selectedOptionColor[3], self.selectedOptionColor[4] * self.alpha)
            love.graphics.print("> " .. option.text, self.x + 40, optionY + (i-1) * 25)
        else
            love.graphics.setColor(self.optionColor[1], self.optionColor[2], self.optionColor[3], self.optionColor[4] * self.alpha)
            love.graphics.print(option.text, self.x + 40, optionY + (i-1) * 25)
        end
    end
end

-- Handle keypresses
function Dialog:keypressed(key)
    if not self.active then return false end
    
    if self.animating then
        -- Skip text animation
        if key == "space" or key == "return" then
            self.textProgress = #self.text
            self.animating = false
        end
    else
        -- Handle options navigation
        if #self.options > 0 then
            if key == "up" then
                self.selectedOption = self.selectedOption - 1
                if self.selectedOption < 1 then
                    self.selectedOption = #self.options
                end
            elseif key == "down" then
                self.selectedOption = self.selectedOption + 1
                if self.selectedOption > #self.options then
                    self.selectedOption = 1
                end
            elseif key == "space" or key == "return" then
                -- Select option
                local selectedOption = self.options[self.selectedOption]
                if selectedOption and selectedOption.action then
                    selectedOption.action()
                end
                
                if self.callback then
                    self.callback(self.selectedOption)
                end
                
                self:hide()
            end
        else
            -- No options, just continue
            if key == "space" or key == "return" then
                if self.callback then
                    self.callback()
                end
                
                self:hide()
            end
        end
    end
    
    -- Dialog handled the keypress
    return true
end

-- Handle mouse presses
function Dialog:mousepressed(x, y, button)
    if not self.active then return false end
    
    if self.animating then
        -- Skip text animation
        if button == 1 then
            self.textProgress = #self.text
            self.animating = false
        end
    else
        -- Check if clicking on an option
        if #self.options > 0 then
            local optionY = self.y + self.height - 20 - (#self.options * 25)
            
            for i, option in ipairs(self.options) do
                local optionTop = optionY + (i-1) * 25
                local optionBottom = optionTop + 25
                
                if x >= self.x + 40 and x <= self.x + self.width - 40 and
                   y >= optionTop and y <= optionBottom then
                    -- Select this option
                    self.selectedOption = i
                    
                    if option.action then
                        option.action()
                    end
                    
                    if self.callback then
                        self.callback(self.selectedOption)
                    end
                    
                    self:hide()
                    return true
                end
            end
        else
            -- No options, just continue
            if button == 1 and not self.animating then
                if self.callback then
                    self.callback()
                end
                
                self:hide()
            end
        end
    end
    
    -- Dialog handled the mousepress if we're active
    return true
end

-- Resize dialog
function Dialog:resize(width, height)
    self.width = math.min(600, width - 40)
    self.x = (width - self.width) / 2
    self.y = height - self.height - 20
end

return Dialog
