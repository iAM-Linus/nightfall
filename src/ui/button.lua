-- Button UI Component for Nightfall Chess
-- Provides interactive button elements for menus and interfaces

local class = require("lib.middleclass.middleclass")
local timer = require("lib.hump.timer")

local Button = class("Button")

function Button:initialize(params)
    params = params or {}
    
    -- Button properties
    self.x = params.x or 0
    self.y = params.y or 0
    self.width = params.width or 100
    self.height = params.height or 40
    self.text = params.text or "Button"
    self.icon = params.icon
    self.iconScale = params.iconScale or 1
    self.callback = params.callback
    self.id = params.id
    self.tooltip = params.tooltip
    self.tooltipTitle = params.tooltipTitle
    
    -- Button state
    self.enabled = params.enabled ~= false
    self.visible = params.visible ~= false
    self.hovered = false
    self.pressed = false
    self.selected = params.selected or false
    
    -- Animation properties
    self.alpha = 1
    self.scale = 1
    self.targetScale = 1
    
    -- Styling
    self.backgroundColor = params.backgroundColor or {0.2, 0.2, 0.3, 0.9}
    self.hoverColor = params.hoverColor or {0.3, 0.3, 0.5, 0.9}
    self.pressedColor = params.pressedColor or {0.15, 0.15, 0.25, 0.9}
    self.disabledColor = params.disabledColor or {0.2, 0.2, 0.2, 0.5}
    self.selectedColor = params.selectedColor or {0.3, 0.5, 0.7, 0.9}
    
    self.borderColor = params.borderColor or {0.5, 0.5, 0.7, 1}
    self.borderHoverColor = params.borderHoverColor or {0.7, 0.7, 0.9, 1}
    self.borderPressedColor = params.borderPressedColor or {0.4, 0.4, 0.6, 1}
    self.borderDisabledColor = params.borderDisabledColor or {0.3, 0.3, 0.3, 0.5}
    self.borderSelectedColor = params.borderSelectedColor or {0.7, 0.8, 1, 1}
    
    self.textColor = params.textColor or {0.9, 0.9, 1, 1}
    self.textHoverColor = params.textHoverColor or {1, 1, 1, 1}
    self.textPressedColor = params.textPressedColor or {0.8, 0.8, 0.9, 1}
    self.textDisabledColor = params.textDisabledColor or {0.6, 0.6, 0.6, 0.5}
    self.textSelectedColor = params.textSelectedColor or {1, 1, 1, 1}
    
    -- Rounded corners
    self.cornerRadius = params.cornerRadius or 5
    
    -- Font
    self.font = params.font or love.graphics.getFont()
    
    -- Sound effects
    self.hoverSound = params.hoverSound
    self.clickSound = params.clickSound
end

-- Update button
function Button:update(dt)
    if not self.visible then return end
    
    -- Check if mouse is over button
    local mx, my = love.mouse.getPosition()
    local wasHovered = self.hovered
    
    self.hovered = self:isPointInside(mx, my)
    
    -- Play hover sound if just started hovering
    if self.hovered and not wasHovered and self.enabled then
        if self.hoverSound then
            love.audio.play(self.hoverSound)
        end
        
        -- Animate scale on hover
        self.targetScale = 1.05
        timer.tween(0.1, self, {scale = self.targetScale}, 'out-quad')
    elseif not self.hovered and wasHovered then
        -- Reset scale when not hovering
        self.targetScale = 1
        timer.tween(0.1, self, {scale = self.targetScale}, 'out-quad')
    end
    
    -- Update animations
    timer.update(dt)
end

-- Draw button
function Button:draw()
    if not self.visible then return end
    
    -- Save current transformation
    love.graphics.push()
    
    -- Apply scale transformation centered on button
    local centerX = self.x + self.width / 2
    local centerY = self.y + self.height / 2
    love.graphics.translate(centerX, centerY)
    love.graphics.scale(self.scale, self.scale)
    love.graphics.translate(-centerX, -centerY)
    
    -- Determine colors based on button state
    local bgColor, borderColor, textColor
    
    if not self.enabled then
        bgColor = self.disabledColor
        borderColor = self.borderDisabledColor
        textColor = self.textDisabledColor
    elseif self.pressed then
        bgColor = self.pressedColor
        borderColor = self.borderPressedColor
        textColor = self.textPressedColor
    elseif self.selected then
        bgColor = self.selectedColor
        borderColor = self.borderSelectedColor
        textColor = self.textSelectedColor
    elseif self.hovered then
        bgColor = self.hoverColor
        borderColor = self.borderHoverColor
        textColor = self.textHoverColor
    else
        bgColor = self.backgroundColor
        borderColor = self.borderColor
        textColor = self.textColor
    end
    
    -- Apply alpha
    bgColor[4] = bgColor[4] * self.alpha
    borderColor[4] = borderColor[4] * self.alpha
    textColor[4] = textColor[4] * self.alpha
    
    -- Draw background
    love.graphics.setColor(bgColor)
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height, self.cornerRadius, self.cornerRadius)
    
    -- Draw border
    love.graphics.setColor(borderColor)
    love.graphics.rectangle("line", self.x, self.y, self.width, self.height, self.cornerRadius, self.cornerRadius)
    
    -- Draw icon if available
    if self.icon then
        love.graphics.setColor(1, 1, 1, self.alpha)
        
        local iconX, iconY
        
        if self.text and self.text ~= "" then
            -- Position icon to the left of text
            iconX = self.x + 10
            iconY = self.y + self.height / 2 - self.icon:getHeight() * self.iconScale / 2
            
            -- Draw icon
            love.graphics.draw(self.icon, iconX, iconY, 0, self.iconScale, self.iconScale)
            
            -- Draw text with offset for icon
            love.graphics.setColor(textColor)
            love.graphics.setFont(self.font)
            love.graphics.printf(self.text, self.x + 20 + self.icon:getWidth() * self.iconScale, self.y + self.height / 2 - self.font:getHeight() / 2, self.width - 30 - self.icon:getWidth() * self.iconScale, "center")
        else
            -- Center icon if no text
            iconX = self.x + self.width / 2 - self.icon:getWidth() * self.iconScale / 2
            iconY = self.y + self.height / 2 - self.icon:getHeight() * self.iconScale / 2
            
            -- Draw icon
            love.graphics.draw(self.icon, iconX, iconY, 0, self.iconScale, self.iconScale)
        end
    else
        -- Draw text centered
        love.graphics.setColor(textColor)
        love.graphics.setFont(self.font)
        love.graphics.printf(self.text, self.x, self.y + self.height / 2 - self.font:getHeight() / 2, self.width, "center")
    end
    
    -- Restore transformation
    love.graphics.pop()
end

-- Check if a point is inside the button
function Button:isPointInside(x, y)
    return x >= self.x and x <= self.x + self.width and
           y >= self.y and y <= self.y + self.height
end

-- Handle mouse press
function Button:mousepressed(x, y, button)
    if not self.visible or not self.enabled then return false end
    
    if button == 1 and self:isPointInside(x, y) then
        self.pressed = true
        
        -- Animate scale on press
        self.targetScale = 0.95
        timer.tween(0.1, self, {scale = self.targetScale}, 'out-quad')
        
        return true
    end
    
    return false
end

-- Handle mouse release
function Button:mousereleased(x, y, button)
    if not self.visible or not self.enabled then return false end
    
    if button == 1 and self.pressed then
        self.pressed = false
        
        -- Reset scale
        self.targetScale = self.hovered and 1.05 or 1
        timer.tween(0.1, self, {scale = self.targetScale}, 'out-quad')
        
        -- Check if release was inside button (click completed)
        if self:isPointInside(x, y) then
            -- Play click sound
            if self.clickSound then
                love.audio.play(self.clickSound)
            end
            
            -- Call callback if provided
            if self.callback then
                self.callback(self)
            end
            
            return true
        end
    end
    
    return false
end

-- Set button enabled state
function Button:setEnabled(enabled)
    self.enabled = enabled
end

-- Set button visibility
function Button:setVisible(visible)
    self.visible = visible
end

-- Set button selected state
function Button:setSelected(selected)
    self.selected = selected
end

-- Set button text
function Button:setText(text)
    self.text = text
end

-- Set button position
function Button:setPosition(x, y)
    self.x = x
    self.y = y
end

-- Set button size
function Button:setSize(width, height)
    self.width = width
    self.height = height
end

-- Set button callback
function Button:setCallback(callback)
    self.callback = callback
end

-- Show button with animation
function Button:show(duration)
    duration = duration or 0.3
    self.visible = true
    self.alpha = 0
    timer.tween(duration, self, {alpha = 1}, 'out-quad')
end

-- Hide button with animation
function Button:hide(duration)
    duration = duration or 0.3
    timer.tween(duration, self, {alpha = 0}, 'out-quad', function()
        self.visible = false
    end)
end

return Button
