-- Tooltip System for Nightfall Chess
-- Provides informational tooltips for game elements

local class = require("lib.middleclass.middleclass")
local timer = require("lib.hump.timer")

local Tooltip = class("Tooltip")

function Tooltip:initialize(game)
    self.game = game
    
    -- Tooltip properties
    self.visible = false
    self.text = ""
    self.title = ""
    self.x = 0
    self.y = 0
    self.width = 200
    self.height = 0
    self.padding = 10
    self.alpha = 0
    
    -- Styling
    self.backgroundColor = {0.1, 0.1, 0.2, 0.9}
    self.borderColor = {0.5, 0.5, 0.7, 1}
    self.titleColor = {0.9, 0.7, 0.2, 1}
    self.textColor = {0.9, 0.9, 1, 1}
    
    -- Fonts
    self.titleFont = game.assets.fonts.small
    self.textFont = game.assets.fonts.small
    
    -- Animation timers
    self.showDelay = 0.5
    self.showTimer = 0
    self.hoverElement = nil
end

-- Show tooltip
function Tooltip:show(text, title, x, y)
    self.text = text or ""
    self.title = title or ""
    
    -- Calculate tooltip dimensions
    love.graphics.setFont(self.textFont)
    local textWidth = love.graphics.getFont():getWidth(self.text)
    local textHeight = love.graphics.getFont():getHeight() * select(2, self.text:gsub("\n", "\n"))
    
    if self.title ~= "" then
        love.graphics.setFont(self.titleFont)
        local titleWidth = love.graphics.getFont():getWidth(self.title)
        textWidth = math.max(textWidth, titleWidth)
        textHeight = textHeight + love.graphics.getFont():getHeight() + 5
    end
    
    self.width = math.min(300, textWidth + self.padding * 2)
    self.height = textHeight + self.padding * 2
    
    -- Position tooltip
    self.x = x or love.mouse.getX()
    self.y = y or love.mouse.getY() - self.height - 10
    
    -- Keep tooltip on screen
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    if self.x + self.width > screenWidth then
        self.x = screenWidth - self.width - 5
    end
    
    if self.x < 5 then
        self.x = 5
    end
    
    if self.y < 5 then
        self.y = love.mouse.getY() + 20
    end
    
    if self.y + self.height > screenHeight then
        self.y = screenHeight - self.height - 5
    end
    
    -- Show tooltip with animation
    self.visible = true
    self.alpha = 0
    timer.tween(0.2, self, {alpha = 1}, 'out-quad')
end

-- Hide tooltip
function Tooltip:hide()
    if not self.visible then return end
    
    timer.tween(0.2, self, {alpha = 0}, 'out-quad', function()
        self.visible = false
    end)
    
    self.hoverElement = nil
    self.showTimer = 0
end

-- Update tooltip
function Tooltip:update(dt)
    -- Update timers
    timer.update(dt)
    
    -- Handle hover delay
    if self.hoverElement then
        self.showTimer = self.showTimer + dt
        if self.showTimer >= self.showDelay and not self.visible then
            self:show(self.hoverElement.tooltip, self.hoverElement.tooltipTitle)
        end
    end
end

-- Draw tooltip
function Tooltip:draw()
    if not self.visible then return end
    
    -- Draw background
    love.graphics.setColor(self.backgroundColor[1], self.backgroundColor[2], self.backgroundColor[3], self.backgroundColor[4] * self.alpha)
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height, 5, 5)
    
    -- Draw border
    love.graphics.setColor(self.borderColor[1], self.borderColor[2], self.borderColor[3], self.borderColor[4] * self.alpha)
    love.graphics.rectangle("line", self.x, self.y, self.width, self.height, 5, 5)
    
    -- Draw title if present
    if self.title ~= "" then
        love.graphics.setFont(self.titleFont)
        love.graphics.setColor(self.titleColor[1], self.titleColor[2], self.titleColor[3], self.titleColor[4] * self.alpha)
        love.graphics.printf(self.title, self.x + self.padding, self.y + self.padding, self.width - self.padding * 2, "left")
        
        -- Draw text below title
        love.graphics.setFont(self.textFont)
        love.graphics.setColor(self.textColor[1], self.textColor[2], self.textColor[3], self.textColor[4] * self.alpha)
        love.graphics.printf(self.text, self.x + self.padding, self.y + self.padding + love.graphics.getFont():getHeight() + 5, self.width - self.padding * 2, "left")
    else
        -- Draw text only
        love.graphics.setFont(self.textFont)
        love.graphics.setColor(self.textColor[1], self.textColor[2], self.textColor[3], self.textColor[4] * self.alpha)
        love.graphics.printf(self.text, self.x + self.padding, self.y + self.padding, self.width - self.padding * 2, "left")
    end
end

-- Set hover element
function Tooltip:setHoverElement(element)
    if element == self.hoverElement then return end
    
    self.hoverElement = element
    self.showTimer = 0
    
    if not element then
        self:hide()
    end
end

-- Check if mouse is over an element
function Tooltip:checkHover(x, y, width, height, tooltipText, tooltipTitle)
    local mx, my = love.mouse.getPosition()
    
    if mx >= x and mx <= x + width and my >= y and my <= y + height then
        self:setHoverElement({
            tooltip = tooltipText,
            tooltipTitle = tooltipTitle
        })
        return true
    end
    
    return false
end

return Tooltip
