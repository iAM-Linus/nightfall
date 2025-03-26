-- Ability Panel UI for Nightfall Chess
-- Displays and manages unit abilities

local class = require("lib.middleclass.middleclass")

local AbilityPanel = class("AbilityPanel")

function AbilityPanel:initialize(game)
    self.game = game
    
    -- Panel dimensions and position
    self.width = 300
    self.height = 100
    self.x = 0
    self.y = 0
    
    -- Ability slots
    self.slots = {}
    self.selectedSlot = nil
    
    -- Current unit
    self.unit = nil
    
    -- Tooltip
    self.showTooltip = false
    self.tooltipAbility = nil
    self.tooltipX = 0
    self.tooltipY = 0
    
    -- Animation
    self.visible = false
    self.alpha = 0
    self.targetAlpha = 0
end

-- Set panel position
function AbilityPanel:setPosition(x, y)
    self.x = x
    self.y = y
end

-- Set current unit
function AbilityPanel:setUnit(unit)
    self.unit = unit
    self:updateAbilitySlots()
    
    -- Show panel if unit has abilities
    if unit and #unit.abilities > 0 then
        self:show()
    else
        self:hide()
    end
end

-- Update ability slots based on current unit
function AbilityPanel:updateAbilitySlots()
    self.slots = {}
    
    if not self.unit then return end
    
    -- Create slots for each ability
    for i, abilityId in ipairs(self.unit.abilities) do
        local ability = nil
        
        -- Get ability definition from special abilities system
        if self.game.specialAbilitiesSystem then
            ability = self.game.specialAbilitiesSystem:getAbility(abilityId)
        end
        
        if ability then
            table.insert(self.slots, {
                id = abilityId,
                name = ability.name,
                description = ability.description,
                icon = ability.icon,
                energyCost = ability.energyCost,
                cooldown = ability.cooldown,
                currentCooldown = self.unit:getAbilityCooldown(abilityId),
                canUse = self.unit:canUseAbility(abilityId)
            })
        end
    end
end

-- Show the panel
function AbilityPanel:show()
    self.visible = true
    self.targetAlpha = 1
end

-- Hide the panel
function AbilityPanel:hide()
    self.targetAlpha = 0
end

-- Update panel state
function AbilityPanel:update(dt)
    -- Animate alpha
    if self.alpha < self.targetAlpha then
        self.alpha = math.min(self.alpha + dt * 5, self.targetAlpha)
    elseif self.alpha > self.targetAlpha then
        self.alpha = math.max(self.alpha - dt * 5, self.targetAlpha)
        if self.alpha <= 0 then
            self.visible = false
        end
    end
    
    -- Update ability slots
    if self.unit then
        for i, slot in ipairs(self.slots) do
            slot.currentCooldown = self.unit:getAbilityCooldown(slot.id)
            slot.canUse = self.unit:canUseAbility(slot.id)
        end
    end
end

-- Draw the panel
function AbilityPanel:draw()
    if not self.visible then return end
    
    local slotSize = 64
    local padding = 10
    local spacing = 10
    
    -- Draw panel background
    love.graphics.setColor(0.2, 0.2, 0.3, 0.8 * self.alpha)
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height, 8, 8)
    
    love.graphics.setColor(0.5, 0.5, 0.6, 0.8 * self.alpha)
    love.graphics.rectangle("line", self.x, self.y, self.width, self.height, 8, 8)
    
    -- Draw title
    love.graphics.setColor(1, 1, 1, self.alpha)
    love.graphics.setFont(self.game.assets.fonts.medium)
    love.graphics.print("Abilities", self.x + padding, self.y + padding)
    
    -- Draw ability slots
    for i, slot in ipairs(self.slots) do
        local slotX = self.x + padding + (i-1) * (slotSize + spacing)
        local slotY = self.y + padding + 30
        
        -- Draw slot background
        if slot.canUse then
            love.graphics.setColor(0.3, 0.3, 0.6, 0.8 * self.alpha)
        else
            love.graphics.setColor(0.3, 0.3, 0.3, 0.8 * self.alpha)
        end
        love.graphics.rectangle("fill", slotX, slotY, slotSize, slotSize, 4, 4)
        
        -- Draw slot border
        if self.selectedSlot == i then
            love.graphics.setColor(0.9, 0.9, 0.2, 0.8 * self.alpha)
        else
            love.graphics.setColor(0.5, 0.5, 0.6, 0.8 * self.alpha)
        end
        love.graphics.rectangle("line", slotX, slotY, slotSize, slotSize, 4, 4)
        
        -- Draw ability icon or placeholder
        love.graphics.setColor(1, 1, 1, self.alpha)
        if slot.icon then
            love.graphics.draw(slot.icon, slotX + 4, slotY + 4, 0, (slotSize-8)/slot.icon:getWidth(), (slotSize-8)/slot.icon:getHeight())
        else
            -- Draw placeholder icon
            love.graphics.setColor(0.7, 0.7, 0.7, 0.5 * self.alpha)
            love.graphics.rectangle("fill", slotX + 8, slotY + 8, slotSize - 16, slotSize - 16)
            
            -- Draw ability initial
            love.graphics.setColor(1, 1, 1, self.alpha)
            love.graphics.setFont(self.game.assets.fonts.medium)
            love.graphics.printf(slot.name:sub(1, 1), slotX, slotY + slotSize/2 - 10, slotSize, "center")
        end
        
        -- Draw cooldown overlay
        if slot.currentCooldown > 0 then
            love.graphics.setColor(0, 0, 0, 0.7 * self.alpha)
            love.graphics.rectangle("fill", slotX, slotY, slotSize, slotSize, 4, 4)
            
            love.graphics.setColor(1, 1, 1, self.alpha)
            love.graphics.setFont(self.game.assets.fonts.medium)
            love.graphics.printf(tostring(slot.currentCooldown), slotX, slotY + slotSize/2 - 10, slotSize, "center")
        end
        
        -- Draw energy cost
        love.graphics.setColor(0.2, 0.6, 0.9, self.alpha)
        love.graphics.setFont(self.game.assets.fonts.small)
        love.graphics.print(tostring(slot.energyCost), slotX + 4, slotY + slotSize - 18)
        
        -- Draw key binding
        love.graphics.setColor(1, 1, 1, 0.7 * self.alpha)
        love.graphics.rectangle("fill", slotX + slotSize - 18, slotY + 4, 14, 14)
        
        love.graphics.setColor(0, 0, 0, self.alpha)
        love.graphics.setFont(self.game.assets.fonts.small)
        love.graphics.printf(tostring(i), slotX + slotSize - 18, slotY + 5, 14, "center")
    end
    
    -- Draw tooltip
    if self.showTooltip and self.tooltipAbility then
        self:drawTooltip()
    end
end

-- Draw ability tooltip
function AbilityPanel:drawTooltip()
    local ability = self.tooltipAbility
    local padding = 10
    local width = 200
    local height = 120
    
    -- Calculate tooltip position
    local x = self.tooltipX
    local y = self.tooltipY - height - 10
    
    -- Ensure tooltip stays on screen
    local screenWidth, screenHeight = love.graphics.getDimensions()
    if x + width > screenWidth then
        x = screenWidth - width
    end
    if y < 0 then
        y = self.tooltipY + 10
    end
    
    -- Draw tooltip background
    love.graphics.setColor(0.1, 0.1, 0.2, 0.9 * self.alpha)
    love.graphics.rectangle("fill", x, y, width, height, 6, 6)
    
    love.graphics.setColor(0.5, 0.5, 0.6, 0.8 * self.alpha)
    love.graphics.rectangle("line", x, y, width, height, 6, 6)
    
    -- Draw ability name
    love.graphics.setColor(1, 1, 1, self.alpha)
    love.graphics.setFont(self.game.assets.fonts.medium)
    love.graphics.print(ability.name, x + padding, y + padding)
    
    -- Draw ability description
    love.graphics.setColor(0.9, 0.9, 0.9, 0.9 * self.alpha)
    love.graphics.setFont(self.game.assets.fonts.small)
    love.graphics.printf(ability.description, x + padding, y + padding + 25, width - padding * 2, "left")
    
    -- Draw ability stats
    love.graphics.setColor(0.7, 0.7, 0.9, self.alpha)
    love.graphics.setFont(self.game.assets.fonts.small)
    love.graphics.print("Energy: " .. ability.energyCost, x + padding, y + height - 40)
    love.graphics.print("Cooldown: " .. ability.cooldown, x + padding, y + height - 25)
end

-- Handle mouse movement
function AbilityPanel:mousemoved(x, y)
    if not self.visible then return end
    
    local slotSize = 64
    local padding = 10
    local spacing = 10
    
    -- Check if mouse is over an ability slot
    self.showTooltip = false
    
    for i, slot in ipairs(self.slots) do
        local slotX = self.x + padding + (i-1) * (slotSize + spacing)
        local slotY = self.y + padding + 30
        
        if x >= slotX and x <= slotX + slotSize and
           y >= slotY and y <= slotY + slotSize then
            -- Show tooltip for this ability
            self.showTooltip = true
            self.tooltipAbility = slot
            self.tooltipX = x
            self.tooltipY = y
            break
        end
    end
end

-- Handle mouse press
function AbilityPanel:mousepressed(x, y, button)
    if not self.visible or not self.unit then return false end
    
    local slotSize = 64
    local padding = 10
    local spacing = 10
    
    -- Check if an ability slot was clicked
    for i, slot in ipairs(self.slots) do
        local slotX = self.x + padding + (i-1) * (slotSize + spacing)
        local slotY = self.y + padding + 30
        
        if x >= slotX and x <= slotX + slotSize and
           y >= slotY and y <= slotY + slotSize then
            -- Select this ability
            if self.selectedSlot == i then
                self.selectedSlot = nil
            else
                self.selectedSlot = i
            end
            
            return true
        end
    end
    
    return false
end

-- Get the currently selected ability
function AbilityPanel:getSelectedAbility()
    if not self.selectedSlot or not self.slots[self.selectedSlot] then
        return nil
    end
    
    return self.slots[self.selectedSlot]
end

-- Use the selected ability
function AbilityPanel:useSelectedAbility(target, x, y)
    if not self.unit or not self.selectedSlot then
        return false
    end
    
    local ability = self.slots[self.selectedSlot]
    if not ability then
        return false
    end
    
    -- Use the ability
    local success = self.unit:useAbility(ability.id, target, x, y)
    
    if success then
        -- Reset selection
        self.selectedSlot = nil
        
        -- Update slots
        self:updateAbilitySlots()
    end
    
    return success
end

-- Handle key press
function AbilityPanel:keypressed(key)
    if not self.visible or not self.unit then return false end
    
    -- Check for number keys 1-9
    local num = tonumber(key)
    if num and num >= 1 and num <= #self.slots then
        -- Select this ability
        if self.selectedSlot == num then
            self.selectedSlot = nil
        else
            self.selectedSlot = num
        end
        
        return true
    end
    
    return false
end

return AbilityPanel
