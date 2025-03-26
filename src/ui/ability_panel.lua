-- src/ui/ability_panel.lua
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
    
    print("AbilityPanel initialized, game reference: " .. tostring(game ~= nil))
end

-- Set panel position
function AbilityPanel:setPosition(x, y)
    self.x = x
    self.y = y
end

-- Set current unit
function AbilityPanel:setUnit(unit)
    -- Debug info
    if unit then
        print("AbilityPanel: Setting unit " .. unit.unitType)
        if unit.abilities then
            print("Unit has " .. #unit.abilities .. " abilities")
        else
            print("Unit has no abilities array!")
        end
    else
        print("AbilityPanel: Clearing unit")
        self:hide()
        self.unit = nil
        self.slots = {}
        return
    end

    self.unit = unit
    self:updateAbilitySlots()
    
    -- Show panel if unit has abilities
    if unit and unit.abilities and #unit.abilities > 0 then
        self:show()
    else
        self:hide()
    end
end

function AbilityPanel:updateAbilitySlots()
    self.slots = {}
    
    if not self.unit then 
        print("AbilityPanel: No unit to update slots for")
        return 
    end
    
    if not self.unit.abilities then
        print("AbilityPanel: Unit has no abilities array")
        return
    end
    
    -- Get proper system reference
    local specialAbilitiesSystem = nil
    if self.game and self.game.specialAbilitiesSystem then
        specialAbilitiesSystem = self.game.specialAbilitiesSystem
    else
        print("AbilityPanel: No specialAbilitiesSystem available")
        return
    end

    -- Create slots for each ability
    for i, abilityId in ipairs(self.unit.abilities) do
        print("AbilityPanel: Processing ability: " .. abilityId)
        
        local ability = specialAbilitiesSystem:getAbility(abilityId)
        
        if ability then
            print("AbilityPanel: Found ability: " .. ability.name)
            
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
        else
            print("AbilityPanel: Ability not found: " .. abilityId)
            -- Create a placeholder slot for missing abilities
            table.insert(self.slots, {
                id = abilityId,
                name = "Unknown Ability",
                description = "This ability could not be found in the system.",
                icon = nil,
                energyCost = 0,
                cooldown = 0,
                currentCooldown = 0,
                canUse = false
            })
        end
    end
    
    print("AbilityPanel: Created " .. #self.slots .. " ability slots")
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
    if self.unit and self.unit.getAbilityCooldown and self.unit.canUseAbility then
        for i, slot in ipairs(self.slots) do
            if slot and slot.id then
                slot.currentCooldown = self.unit:getAbilityCooldown(slot.id)
                slot.canUse = self.unit:canUseAbility(slot.id)
            end
        end
    end
end

-- Draw the panel
function AbilityPanel:draw()
    if not self.visible or self.alpha <= 0 then return end
    
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
    if self.game and self.game.assets and self.game.assets.fonts and self.game.assets.fonts.medium then
        love.graphics.setFont(self.game.assets.fonts.medium)
    end
    love.graphics.print("Abilities", self.x + padding, self.y + padding)
    
    -- Draw ability slots
    for i, slot in ipairs(self.slots) do
        local slotX = self.x + padding + (i-1) * (slotSize + spacing)
        local slotY = self.y + padding + 30
        
        -- Make sure slot doesn't go off panel width
        if slotX + slotSize > self.x + self.width - padding then
            -- Skip drawing if too many slots
            goto continue
        end
        
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
        if slot.icon and type(slot.icon) == "userdata" and slot.icon.getWidth then
            -- Only draw the icon if it's a valid image
            love.graphics.draw(slot.icon, slotX + 4, slotY + 4, 0, (slotSize-8)/slot.icon:getWidth(), (slotSize-8)/slot.icon:getHeight())
        else
            -- Draw placeholder icon
            love.graphics.setColor(0.7, 0.7, 0.7, 0.5 * self.alpha)
            love.graphics.rectangle("fill", slotX + 8, slotY + 8, slotSize - 16, slotSize - 16)
            
            -- Draw ability initial
            love.graphics.setColor(1, 1, 1, self.alpha)
            if self.game and self.game.assets and self.game.assets.fonts and self.game.assets.fonts.medium then
                love.graphics.setFont(self.game.assets.fonts.medium)
            end
            
            if slot.name and type(slot.name) == "string" and #slot.name > 0 then
                love.graphics.printf(slot.name:sub(1, 1), slotX, slotY + slotSize/2 - 10, slotSize, "center")
            else
                love.graphics.printf("?", slotX, slotY + slotSize/2 - 10, slotSize, "center")
            end
        end
        
        -- Draw cooldown overlay
        if slot.currentCooldown and slot.currentCooldown > 0 then
            love.graphics.setColor(0, 0, 0, 0.7 * self.alpha)
            love.graphics.rectangle("fill", slotX, slotY, slotSize, slotSize, 4, 4)
            
            love.graphics.setColor(1, 1, 1, self.alpha)
            if self.game and self.game.assets and self.game.assets.fonts and self.game.assets.fonts.medium then
                love.graphics.setFont(self.game.assets.fonts.medium)
            end
            love.graphics.printf(tostring(slot.currentCooldown), slotX, slotY + slotSize/2 - 10, slotSize, "center")
        end
        
        -- Draw energy cost
        love.graphics.setColor(0.2, 0.6, 0.9, self.alpha)
        if self.game and self.game.assets and self.game.assets.fonts and self.game.assets.fonts.small then
            love.graphics.setFont(self.game.assets.fonts.small)
        end
        if slot.energyCost then
            love.graphics.print(tostring(slot.energyCost), slotX + 4, slotY + slotSize - 18)
        end
        
        -- Draw key binding
        love.graphics.setColor(1, 1, 1, 0.7 * self.alpha)
        love.graphics.rectangle("fill", slotX + slotSize - 18, slotY + 4, 14, 14)
        
        love.graphics.setColor(0, 0, 0, self.alpha)
        if self.game and self.game.assets and self.game.assets.fonts and self.game.assets.fonts.small then
            love.graphics.setFont(self.game.assets.fonts.small)
        end
        love.graphics.printf(tostring(i), slotX + slotSize - 18, slotY + 5, 14, "center")
        
        ::continue::
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
    if self.game and self.game.assets and self.game.assets.fonts and self.game.assets.fonts.medium then
        love.graphics.setFont(self.game.assets.fonts.medium)
    end
    love.graphics.print(ability.name, x + padding, y + padding)
    
    -- Draw ability description
    love.graphics.setColor(0.9, 0.9, 0.9, 0.9 * self.alpha)
    if self.game and self.game.assets and self.game.assets.fonts and self.game.assets.fonts.small then
        love.graphics.setFont(self.game.assets.fonts.small)
    end
    love.graphics.printf(ability.description, x + padding, y + padding + 25, width - padding * 2, "left")
    
    -- Draw ability stats
    love.graphics.setColor(0.7, 0.7, 0.9, self.alpha)
    if self.game and self.game.assets and self.game.assets.fonts and self.game.assets.fonts.small then
        love.graphics.setFont(self.game.assets.fonts.small)
    end
    love.graphics.print("Energy: " .. (ability.energyCost or 0), x + padding, y + height - 40)
    love.graphics.print("Cooldown: " .. (ability.cooldown or 0), x + padding, y + height - 25)
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
                print("AbilityPanel: Deselected ability")
            else
                self.selectedSlot = i
                print("AbilityPanel: Selected ability: " .. slot.name)
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
        print("AbilityPanel: Cannot use ability - no unit or no selected slot")
        return false
    end
    
    local ability = self.slots[self.selectedSlot]
    if not ability then
        print("AbilityPanel: Cannot use ability - no ability found in selected slot")
        return false
    end
    
    print("AbilityPanel: Trying to use ability: " .. ability.name)
    
    -- Use the ability
    local success = self.unit:useAbility(ability.id, target, x, y)
    
    if success then
        print("AbilityPanel: Successfully used ability")
        -- Reset selection
        self.selectedSlot = nil
        
        -- Update slots
        self:updateAbilitySlots()
    else
        print("AbilityPanel: Failed to use ability")
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
            print("AbilityPanel: Deselected ability via key")
        else
            self.selectedSlot = num
            local ability = self.slots[num]
            if ability then
                print("AbilityPanel: Selected ability via key: " .. ability.name)
            end
        end
        
        return true
    end
    
    return false
end

-- Resize method to handle window size changes
function AbilityPanel:resize(width, height)
    -- Update position to stay centered at bottom
    self.x = (width - self.width) / 2
    self.y = height - self.height - 40
end

return AbilityPanel
