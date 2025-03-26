-- Inventory UI for Nightfall Chess
-- Handles display and interaction with inventory items

local class = require("lib.middleclass.middleclass")

local InventoryUI = class("InventoryUI")

function InventoryUI:initialize(game, inventoryManager)
    self.game = game
    self.inventoryManager = inventoryManager
    
    -- UI state
    self.visible = false
    self.alpha = 0
    self.targetAlpha = 0
    
    -- Layout
    self.width = 600
    self.height = 400
    self.x = 0
    self.y = 0
    
    -- Item slots
    self.itemSlots = {}
    self.itemsPerPage = 20
    self.currentPage = 1
    self.selectedSlot = nil
    self.hoveredSlot = nil
    
    -- Equipment slots
    self.equipmentSlots = {
        weapon = {x = 50, y = 100, width = 64, height = 64, label = "Weapon"},
        armor = {x = 50, y = 180, width = 64, height = 64, label = "Armor"},
        accessory = {x = 50, y = 260, width = 64, height = 64, label = "Accessory"}
    }
    
    -- Filter and sort
    self.currentFilter = "all"
    self.currentSort = "type"
    
    -- Item tooltip
    self.showTooltip = false
    self.tooltipItem = nil
    self.tooltipX = 0
    self.tooltipY = 0
    
    -- Item context menu
    self.showContextMenu = false
    self.contextMenuItem = nil
    self.contextMenuX = 0
    self.contextMenuY = 0
    self.contextMenuOptions = {}
    
    -- Selected unit for equipment
    self.selectedUnit = nil
    
    -- Register callbacks
    if inventoryManager then
        inventoryManager.onItemAdded = function(item, quantity)
            self:onItemAdded(item, quantity)
        end
        
        inventoryManager.onItemRemoved = function(item, quantity)
            self:onItemRemoved(item, quantity)
        end
        
        inventoryManager.onItemUsed = function(item, unit)
            self:onItemUsed(item, unit)
        end
        
        inventoryManager.onItemEquipped = function(item, unit)
            self:onItemEquipped(item, unit)
        end
        
        inventoryManager.onItemUnequipped = function(item, unit)
            self:onItemUnequipped(item, unit)
        end
        
        inventoryManager.onGoldChanged = function(oldValue, newValue)
            self:onGoldChanged(oldValue, newValue)
        end
    end
end

-- Set UI position
function InventoryUI:setPosition(x, y)
    self.x = x
    self.y = y
end

-- Show inventory UI
function InventoryUI:show(unit)
    self.visible = true
    self.targetAlpha = 1
    self.selectedUnit = unit
    self:updateItemSlots()
end

-- Hide inventory UI
function InventoryUI:hide()
    self.targetAlpha = 0
    self.showTooltip = false
    self.showContextMenu = false
end

-- Update inventory UI
function InventoryUI:update(dt)
    -- Animate alpha
    if self.alpha < self.targetAlpha then
        self.alpha = math.min(self.alpha + dt * 5, self.targetAlpha)
    elseif self.alpha > self.targetAlpha then
        self.alpha = math.max(self.alpha - dt * 5, self.targetAlpha)
        if self.alpha <= 0 then
            self.visible = false
        end
    end
    
    -- Update item slots if inventory changed
    if self.inventoryManager and self.visible then
        self:updateItemSlots()
    end
end

-- Update item slots based on current inventory
function InventoryUI:updateItemSlots()
    self.itemSlots = {}
    
    if not self.inventoryManager then return end
    
    -- Get filtered items
    local filteredItems = {}
    for _, item in ipairs(self.inventoryManager.items) do
        if self.currentFilter == "all" or item.type == self.currentFilter then
            table.insert(filteredItems, item)
        end
    end
    
    -- Sort items
    self:sortItems(filteredItems, self.currentSort)
    
    -- Calculate pagination
    local totalPages = math.ceil(#filteredItems / self.itemsPerPage)
    if totalPages == 0 then totalPages = 1 end
    
    if self.currentPage > totalPages then
        self.currentPage = totalPages
    end
    
    -- Create item slots
    local startIndex = (self.currentPage - 1) * self.itemsPerPage + 1
    local endIndex = math.min(startIndex + self.itemsPerPage - 1, #filteredItems)
    
    for i = startIndex, endIndex do
        local item = filteredItems[i]
        local slotIndex = i - startIndex + 1
        local row = math.floor((slotIndex - 1) / 5)
        local col = (slotIndex - 1) % 5
        
        local slot = {
            item = item,
            x = self.x + 150 + col * 70,
            y = self.y + 100 + row * 70,
            width = 64,
            height = 64
        }
        
        table.insert(self.itemSlots, slot)
    end
    
    -- Update equipment slots
    for slotName, slotInfo in pairs(self.equipmentSlots) do
        slotInfo.item = nil
        
        if self.selectedUnit and self.selectedUnit.equipment and self.selectedUnit.equipment[slotName] then
            slotInfo.item = self.selectedUnit.equipment[slotName]
        end
    end
end

-- Sort items
function InventoryUI:sortItems(items, sortType)
    if sortType == "type" then
        table.sort(items, function(a, b)
            if a.type == b.type then
                return a.name < b.name
            end
            return a.type < b.type
        end)
    elseif sortType == "name" then
        table.sort(items, function(a, b)
            return a.name < b.name
        end)
    elseif sortType == "value" then
        table.sort(items, function(a, b)
            return (a.value or 0) > (b.value or 0)
        end)
    elseif sortType == "rarity" then
        table.sort(items, function(a, b)
            if a.rarity == b.rarity then
                return a.name < b.name
            end
            
            local rarityOrder = {
                common = 1,
                uncommon = 2,
                rare = 3,
                epic = 4,
                legendary = 5
            }
            
            return (rarityOrder[a.rarity] or 0) > (rarityOrder[b.rarity] or 0)
        end)
    end
end

-- Draw inventory UI
function InventoryUI:draw()
    if not self.visible then return end
    
    local width, height = love.graphics.getDimensions()
    
    -- Center the UI if position not set
    if self.x == 0 and self.y == 0 then
        self.x = (width - self.width) / 2
        self.y = (height - self.height) / 2
    end
    
    -- Draw background
    love.graphics.setColor(0.1, 0.1, 0.2, 0.9 * self.alpha)
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height, 10, 10)
    
    love.graphics.setColor(0.3, 0.3, 0.5, 0.8 * self.alpha)
    love.graphics.rectangle("line", self.x, self.y, self.width, self.height, 10, 10)
    
    -- Draw title
    love.graphics.setColor(1, 1, 1, self.alpha)
    love.graphics.setFont(self.game.assets.fonts.medium)
    love.graphics.print("Inventory", self.x + 20, self.y + 20)
    
    -- Draw gold
    if self.inventoryManager then
        love.graphics.setColor(1, 0.8, 0.2, self.alpha)
        love.graphics.print("Gold: " .. self.inventoryManager.gold, self.x + self.width - 150, self.y + 20)
    end
    
    -- Draw equipment section
    love.graphics.setColor(0.2, 0.2, 0.3, 0.8 * self.alpha)
    love.graphics.rectangle("fill", self.x + 20, self.y + 60, 110, 280, 5, 5)
    
    love.graphics.setColor(0.4, 0.4, 0.6, 0.8 * self.alpha)
    love.graphics.rectangle("line", self.x + 20, self.y + 60, 110, 280, 5, 5)
    
    love.graphics.setColor(1, 1, 1, self.alpha)
    love.graphics.setFont(self.game.assets.fonts.small)
    love.graphics.print("Equipment", self.x + 35, self.y + 70)
    
    -- Draw equipment slots
    for slotName, slotInfo in pairs(self.equipmentSlots) do
        -- Draw slot background
        love.graphics.setColor(0.15, 0.15, 0.25, 0.8 * self.alpha)
        love.graphics.rectangle("fill", self.x + slotInfo.x, self.y + slotInfo.y, slotInfo.width, slotInfo.height, 3, 3)
        
        -- Draw slot border
        love.graphics.setColor(0.4, 0.4, 0.6, 0.8 * self.alpha)
        love.graphics.rectangle("line", self.x + slotInfo.x, self.y + slotInfo.y, slotInfo.width, slotInfo.height, 3, 3)
        
        -- Draw slot label
        love.graphics.setColor(0.8, 0.8, 0.8, 0.8 * self.alpha)
        love.graphics.print(slotInfo.label, self.x + slotInfo.x, self.y + slotInfo.y - 15)
        
        -- Draw equipped item
        if slotInfo.item then
            self:drawItem(slotInfo.item, self.x + slotInfo.x + 2, self.y + slotInfo.y + 2, slotInfo.width - 4, slotInfo.height - 4)
        end
    end
    
    -- Draw items section
    love.graphics.setColor(0.2, 0.2, 0.3, 0.8 * self.alpha)
    love.graphics.rectangle("fill", self.x + 140, self.y + 60, 440, 280, 5, 5)
    
    love.graphics.setColor(0.4, 0.4, 0.6, 0.8 * self.alpha)
    love.graphics.rectangle("line", self.x + 140, self.y + 60, 440, 280, 5, 5)
    
    love.graphics.setColor(1, 1, 1, self.alpha)
    love.graphics.setFont(self.game.assets.fonts.small)
    love.graphics.print("Items", self.x + 155, self.y + 70)
    
    -- Draw filter buttons
    local filters = {"all", "weapon", "armor", "accessory", "consumable"}
    for i, filter in ipairs(filters) do
        local buttonX = self.x + 155 + (i-1) * 70
        local buttonY = self.y + 70
        
        -- Draw button background
        if self.currentFilter == filter then
            love.graphics.setColor(0.3, 0.3, 0.6, 0.8 * self.alpha)
        else
            love.graphics.setColor(0.2, 0.2, 0.3, 0.8 * self.alpha)
        end
        
        love.graphics.rectangle("fill", buttonX, buttonY, 60, 20, 3, 3)
        
        -- Draw button text
        love.graphics.setColor(1, 1, 1, self.alpha)
        love.graphics.printf(filter:sub(1,1):upper() .. filter:sub(2), buttonX, buttonY + 3, 60, "center")
    end
    
    -- Draw item slots
    for i, slot in ipairs(self.itemSlots) do
        -- Draw slot background
        if self.selectedSlot == i then
            love.graphics.setColor(0.3, 0.3, 0.6, 0.8 * self.alpha)
        elseif self.hoveredSlot == i then
            love.graphics.setColor(0.25, 0.25, 0.4, 0.8 * self.alpha)
        else
            love.graphics.setColor(0.15, 0.15, 0.25, 0.8 * self.alpha)
        end
        
        love.graphics.rectangle("fill", slot.x, slot.y, slot.width, slot.height, 3, 3)
        
        -- Draw slot border
        love.graphics.setColor(0.4, 0.4, 0.6, 0.8 * self.alpha)
        love.graphics.rectangle("line", slot.x, slot.y, slot.width, slot.height, 3, 3)
        
        -- Draw item
        if slot.item then
            self:drawItem(slot.item, slot.x + 2, slot.y + 2, slot.width - 4, slot.height - 4)
        end
    end
    
    -- Draw pagination
    if self.inventoryManager then
        local totalItems = 0
        for _, item in ipairs(self.inventoryManager.items) do
            if self.currentFilter == "all" or item.type == self.currentFilter then
                totalItems = totalItems + 1
            end
        end
        
        local totalPages = math.ceil(totalItems / self.itemsPerPage)
        if totalPages == 0 then totalPages = 1 end
        
        love.graphics.setColor(1, 1, 1, self.alpha)
        love.graphics.printf("Page " .. self.currentPage .. " / " .. totalPages, self.x + 140, self.y + self.height - 30, 440, "center")
        
        -- Draw page buttons
        if self.currentPage > 1 then
            love.graphics.setColor(0.3, 0.3, 0.6, 0.8 * self.alpha)
            love.graphics.rectangle("fill", self.x + 150, self.y + self.height - 30, 30, 20, 3, 3)
            love.graphics.setColor(1, 1, 1, self.alpha)
            love.graphics.printf("<", self.x + 150, self.y + self.height - 27, 30, "center")
        end
        
        if self.currentPage < totalPages then
            love.graphics.setColor(0.3, 0.3, 0.6, 0.8 * self.alpha)
            love.graphics.rectangle("fill", self.x + 540, self.y + self.height - 30, 30, 20, 3, 3)
            love.graphics.setColor(1, 1, 1, self.alpha)
            love.graphics.printf(">", self.x + 540, self.y + self.height - 27, 30, "center")
        end
    end
    
    -- Draw tooltip
    if self.showTooltip and self.tooltipItem then
        self:drawTooltip()
    end
    
    -- Draw context menu
    if self.showContextMenu and self.contextMenuItem then
        self:drawContextMenu()
    end
    
    -- Draw close button
    love.graphics.setColor(0.8, 0.2, 0.2, 0.8 * self.alpha)
    love.graphics.rectangle("fill", self.x + self.width - 30, self.y + 10, 20, 20, 3, 3)
    
    love.graphics.setColor(1, 1, 1, self.alpha)
    love.graphics.printf("X", self.x + self.width - 30, self.y + 12, 20, "center")
end

-- Draw an item
function InventoryUI:drawItem(item, x, y, width, height)
    -- Draw item background based on rarity
    local rarityColors = {
        common = {0.7, 0.7, 0.7},
        uncommon = {0.2, 0.8, 0.2},
        rare = {0.2, 0.2, 0.8},
        epic = {0.8, 0.2, 0.8},
        legendary = {1.0, 0.6, 0.1}
    }
    
    local color = rarityColors[item.rarity] or {0.7, 0.7, 0.7}
    
    love.graphics.setColor(color[1], color[2], color[3], 0.3 * self.alpha)
    love.graphics.rectangle("fill", x, y, width, height)
    
    -- Draw item icon or placeholder
    if item.icon then
        love.graphics.setColor(1, 1, 1, self.alpha)
        love.graphics.draw(item.icon, x, y, 0, width/item.icon:getWidth(), height/item.icon:getHeight())
    else
        -- Draw placeholder based on item type
        local typeColors = {
            weapon = {0.8, 0.2, 0.2},
            armor = {0.2, 0.2, 0.8},
            accessory = {0.8, 0.8, 0.2},
            consumable = {0.2, 0.8, 0.2},
            key = {0.8, 0.5, 0.2},
            quest = {0.5, 0.2, 0.8}
        }
        
        local typeColor = typeColors[item.type] or {0.7, 0.7, 0.7}
        
        love.graphics.setColor(typeColor[1], typeColor[2], typeColor[3], 0.5 * self.alpha)
        love.graphics.rectangle("fill", x + 5, y + 5, width - 10, height - 10)
        
        -- Draw item initial
        love.graphics.setColor(1, 1, 1, self.alpha)
        love.graphics.setFont(self.game.assets.fonts.medium)
        love.graphics.printf(item.name:sub(1, 1), x, y + height/2 - 10, width, "center")
    end
    
    -- Draw quantity for stackable items
    if item.stackable and item.quantity > 1 then
        love.graphics.setColor(0, 0, 0, 0.7 * self.alpha)
        love.graphics.rectangle("fill", x + width - 20, y + height - 20, 20, 20)
        
        love.graphics.setColor(1, 1, 1, self.alpha)
        love.graphics.setFont(self.game.assets.fonts.small)
        love.graphics.printf(tostring(item.quantity), x + width - 20, y + height - 18, 20, "center")
    end
    
    -- Draw equipped indicator
    if item.equipped then
        love.graphics.setColor(0.2, 0.8, 0.2, 0.8 * self.alpha)
        love.graphics.rectangle("fill", x, y, 10, 10)
    end
end

-- Draw item tooltip
function InventoryUI:drawTooltip()
    local item = self.tooltipItem
    local padding = 10
    local width = 250
    local height = 200
    
    -- Calculate tooltip position
    local x = self.tooltipX + 20
    local y = self.tooltipY
    
    -- Ensure tooltip stays on screen
    local screenWidth, screenHeight = love.graphics.getDimensions()
    if x + width > screenWidth then
        x = screenWidth - width - 10
    end
    if y + height > screenHeight then
        y = screenHeight - height - 10
    end
    
    -- Draw tooltip background
    love.graphics.setColor(0.1, 0.1, 0.2, 0.95 * self.alpha)
    love.graphics.rectangle("fill", x, y, width, height, 5, 5)
    
    love.graphics.setColor(0.4, 0.4, 0.6, 0.8 * self.alpha)
    love.graphics.rectangle("line", x, y, width, height, 5, 5)
    
    -- Draw item name with rarity color
    local rarityColors = {
        common = {0.7, 0.7, 0.7},
        uncommon = {0.2, 0.8, 0.2},
        rare = {0.2, 0.2, 0.8},
        epic = {0.8, 0.2, 0.8},
        legendary = {1.0, 0.6, 0.1}
    }
    
    local color = rarityColors[item.rarity] or {0.7, 0.7, 0.7}
    
    love.graphics.setColor(color[1], color[2], color[3], self.alpha)
    love.graphics.setFont(self.game.assets.fonts.medium)
    love.graphics.print(item.name, x + padding, y + padding)
    
    -- Draw item type and rarity
    love.graphics.setColor(0.7, 0.7, 0.7, 0.8 * self.alpha)
    love.graphics.setFont(self.game.assets.fonts.small)
    love.graphics.print(item.type:sub(1,1):upper() .. item.type:sub(2) .. " - " .. 
                       (item.rarity:sub(1,1):upper() .. item.rarity:sub(2)), 
                       x + padding, y + padding + 25)
    
    -- Draw item description
    love.graphics.setColor(0.9, 0.9, 0.9, 0.9 * self.alpha)
    love.graphics.printf(item.description or "No description available", 
                        x + padding, y + padding + 45, width - padding * 2, "left")
    
    -- Draw item stats
    local yPos = y + padding + 85
    
    if item.type == "weapon" then
        love.graphics.setColor(0.8, 0.2, 0.2, 0.9 * self.alpha)
        love.graphics.print("Damage: " .. (item.damage or 0), x + padding, yPos)
        yPos = yPos + 15
    elseif item.type == "armor" then
        love.graphics.setColor(0.2, 0.2, 0.8, 0.9 * self.alpha)
        love.graphics.print("Defense: " .. (item.defense or 0), x + padding, yPos)
        yPos = yPos + 15
    end
    
    -- Draw stat bonuses
    if item.stats then
        for stat, value in pairs(item.stats) do
            local statName = stat:sub(1,1):upper() .. stat:sub(2)
            local prefix = value > 0 and "+" or ""
            
            love.graphics.setColor(0.2, 0.8, 0.2, 0.9 * self.alpha)
            love.graphics.print(statName .. ": " .. prefix .. value, x + padding, yPos)
            yPos = yPos + 15
        end
    end
    
    -- Draw value
    love.graphics.setColor(1, 0.8, 0.2, 0.9 * self.alpha)
    love.graphics.print("Value: " .. (item.value or 0) .. " gold", x + padding, y + height - 40)
    
    -- Draw weight
    love.graphics.setColor(0.7, 0.7, 0.7, 0.9 * self.alpha)
    love.graphics.print("Weight: " .. (item.weight or 0), x + padding, y + height - 25)
end

-- Draw context menu
function InventoryUI:drawContextMenu()
    local padding = 5
    local width = 120
    local height = #self.contextMenuOptions * 25 + padding * 2
    
    -- Draw menu background
    love.graphics.setColor(0.1, 0.1, 0.2, 0.95 * self.alpha)
    love.graphics.rectangle("fill", self.contextMenuX, self.contextMenuY, width, height, 3, 3)
    
    love.graphics.setColor(0.4, 0.4, 0.6, 0.8 * self.alpha)
    love.graphics.rectangle("line", self.contextMenuX, self.contextMenuY, width, height, 3, 3)
    
    -- Draw options
    love.graphics.setFont(self.game.assets.fonts.small)
    
    for i, option in ipairs(self.contextMenuOptions) do
        local y = self.contextMenuY + padding + (i-1) * 25
        
        -- Draw option background
        love.graphics.setColor(0.2, 0.2, 0.3, 0.8 * self.alpha)
        love.graphics.rectangle("fill", self.contextMenuX + padding, y, width - padding * 2, 20, 2, 2)
        
        -- Draw option text
        love.graphics.setColor(1, 1, 1, self.alpha)
        love.graphics.printf(option.text, self.contextMenuX + padding, y + 3, width - padding * 2, "center")
    end
end

-- Handle mouse movement
function InventoryUI:mousemoved(x, y)
    if not self.visible then return end
    
    -- Check if mouse is over an item slot
    self.hoveredSlot = nil
    self.showTooltip = false
    
    for i, slot in ipairs(self.itemSlots) do
        if x >= slot.x and x <= slot.x + slot.width and
           y >= slot.y and y <= slot.y + slot.height then
            self.hoveredSlot = i
            
            if slot.item then
                self.showTooltip = true
                self.tooltipItem = slot.item
                self.tooltipX = x
                self.tooltipY = y
            end
            
            break
        end
    end
    
    -- Check if mouse is over an equipment slot
    for slotName, slotInfo in pairs(self.equipmentSlots) do
        local slotX = self.x + slotInfo.x
        local slotY = self.y + slotInfo.y
        
        if x >= slotX and x <= slotX + slotInfo.width and
           y >= slotY and y <= slotY + slotInfo.height and
           slotInfo.item then
            self.showTooltip = true
            self.tooltipItem = slotInfo.item
            self.tooltipX = x
            self.tooltipY = y
            break
        end
    end
end

-- Handle mouse press
function InventoryUI:mousepressed(x, y, button)
    if not self.visible then return false end
    
    -- Check if close button was clicked
    if x >= self.x + self.width - 30 and x <= self.x + self.width - 10 and
       y >= self.y + 10 and y <= self.y + 30 then
        self:hide()
        return true
    end
    
    -- Check if an item slot was clicked
    for i, slot in ipairs(self.itemSlots) do
        if x >= slot.x and x <= slot.x + slot.width and
           y >= slot.y and y <= slot.y + slot.height then
            
            if button == 1 then -- Left click
                self.selectedSlot = i
                
                if slot.item then
                    -- Double click to use/equip
                    local currentTime = love.timer.getTime()
                    if self.lastClickTime and currentTime - self.lastClickTime < 0.3 and
                       self.lastClickSlot == i then
                        self:useSelectedItem()
                    end
                    
                    self.lastClickTime = currentTime
                    self.lastClickSlot = i
                end
            elseif button == 2 and slot.item then -- Right click
                -- Show context menu
                self.showContextMenu = true
                self.contextMenuItem = slot.item
                self.contextMenuX = x
                self.contextMenuY = y
                
                -- Build context menu options
                self.contextMenuOptions = {}
                
                if slot.item.type == "consumable" then
                    table.insert(self.contextMenuOptions, {
                        text = "Use",
                        action = function() self:useItem(slot.item) end
                    })
                elseif slot.item.type == "weapon" or slot.item.type == "armor" or slot.item.type == "accessory" then
                    if slot.item.equipped then
                        table.insert(self.contextMenuOptions, {
                            text = "Unequip",
                            action = function() self:unequipItem(slot.item) end
                        })
                    else
                        table.insert(self.contextMenuOptions, {
                            text = "Equip",
                            action = function() self:equipItem(slot.item) end
                        })
                    end
                end
                
                table.insert(self.contextMenuOptions, {
                    text = "Drop",
                    action = function() self:dropItem(slot.item) end
                })
            end
            
            return true
        end
    end
    
    -- Check if an equipment slot was clicked
    for slotName, slotInfo in pairs(self.equipmentSlots) do
        local slotX = self.x + slotInfo.x
        local slotY = self.y + slotInfo.y
        
        if x >= slotX and x <= slotX + slotInfo.width and
           y >= slotY and y <= slotY + slotInfo.height then
            
            if button == 1 and slotInfo.item then -- Left click
                -- Unequip on double click
                local currentTime = love.timer.getTime()
                if self.lastClickTime and currentTime - self.lastClickTime < 0.3 and
                   self.lastClickSlot == "equip_" .. slotName then
                    self:unequipItem(slotInfo.item)
                end
                
                self.lastClickTime = currentTime
                self.lastClickSlot = "equip_" .. slotName
            elseif button == 2 and slotInfo.item then -- Right click
                -- Show context menu
                self.showContextMenu = true
                self.contextMenuItem = slotInfo.item
                self.contextMenuX = x
                self.contextMenuY = y
                
                -- Build context menu options
                self.contextMenuOptions = {
                    {
                        text = "Unequip",
                        action = function() self:unequipItem(slotInfo.item) end
                    }
                }
            end
            
            return true
        end
    end
    
    -- Check if a filter button was clicked
    local filters = {"all", "weapon", "armor", "accessory", "consumable"}
    for i, filter in ipairs(filters) do
        local buttonX = self.x + 155 + (i-1) * 70
        local buttonY = self.y + 70
        
        if x >= buttonX and x <= buttonX + 60 and
           y >= buttonY and y <= buttonY + 20 then
            self.currentFilter = filter
            self:updateItemSlots()
            return true
        end
    end
    
    -- Check if pagination buttons were clicked
    if self.inventoryManager then
        local totalItems = 0
        for _, item in ipairs(self.inventoryManager.items) do
            if self.currentFilter == "all" or item.type == self.currentFilter then
                totalItems = totalItems + 1
            end
        end
        
        local totalPages = math.ceil(totalItems / self.itemsPerPage)
        if totalPages == 0 then totalPages = 1 end
        
        -- Previous page button
        if self.currentPage > 1 and
           x >= self.x + 150 and x <= self.x + 180 and
           y >= self.y + self.height - 30 and y <= self.y + self.height - 10 then
            self.currentPage = self.currentPage - 1
            self:updateItemSlots()
            return true
        end
        
        -- Next page button
        if self.currentPage < totalPages and
           x >= self.x + 540 and x <= self.x + 570 and
           y >= self.y + self.height - 30 and y <= self.y + self.height - 10 then
            self.currentPage = self.currentPage + 1
            self:updateItemSlots()
            return true
        end
    end
    
    -- Check if context menu option was clicked
    if self.showContextMenu then
        for i, option in ipairs(self.contextMenuOptions) do
            local optionY = self.contextMenuY + 5 + (i-1) * 25
            
            if x >= self.contextMenuX + 5 and x <= self.contextMenuX + 115 and
               y >= optionY and y <= optionY + 20 then
                -- Execute option action
                if option.action then
                    option.action()
                end
                
                self.showContextMenu = false
                return true
            end
        end
        
        -- Close context menu if clicked outside
        self.showContextMenu = false
        return true
    end
    
    return false
end

-- Use the selected item
function InventoryUI:useSelectedItem()
    if not self.selectedSlot or not self.itemSlots[self.selectedSlot] then
        return false
    end
    
    local item = self.itemSlots[self.selectedSlot].item
    if not item then
        return false
    end
    
    if item.type == "consumable" then
        return self:useItem(item)
    elseif item.type == "weapon" or item.type == "armor" or item.type == "accessory" then
        if item.equipped then
            return self:unequipItem(item)
        else
            return self:equipItem(item)
        end
    end
    
    return false
end

-- Use an item
function InventoryUI:useItem(item)
    if not self.inventoryManager or not self.selectedUnit then
        return false
    end
    
    return self.inventoryManager:useItem(item, self.selectedUnit)
end

-- Equip an item
function InventoryUI:equipItem(item)
    if not self.inventoryManager or not self.selectedUnit then
        return false
    end
    
    return self.inventoryManager:equipItem(item, self.selectedUnit)
end

-- Unequip an item
function InventoryUI:unequipItem(item)
    if not self.inventoryManager or not self.selectedUnit then
        return false
    end
    
    return self.inventoryManager:unequipItem(item, self.selectedUnit)
end

-- Drop an item
function InventoryUI:dropItem(item)
    if not self.inventoryManager then
        return false
    end
    
    -- Ask for confirmation
    -- This would be implemented with a proper UI system
    
    -- For now, just remove the item
    return self.inventoryManager:removeItem(item)
end

-- Item added callback
function InventoryUI:onItemAdded(item, quantity)
    -- Update item slots
    self:updateItemSlots()
    
    -- Show notification
    print("Added " .. quantity .. "x " .. item.name)
end

-- Item removed callback
function InventoryUI:onItemRemoved(item, quantity)
    -- Update item slots
    self:updateItemSlots()
    
    -- Show notification
    print("Removed " .. quantity .. "x " .. item.name)
end

-- Item used callback
function InventoryUI:onItemUsed(item, unit)
    -- Update item slots
    self:updateItemSlots()
    
    -- Show notification
    print(unit.unitType:upper() .. " used " .. item.name)
end

-- Item equipped callback
function InventoryUI:onItemEquipped(item, unit)
    -- Update item slots
    self:updateItemSlots()
    
    -- Show notification
    print(unit.unitType:upper() .. " equipped " .. item.name)
end

-- Item unequipped callback
function InventoryUI:onItemUnequipped(item, unit)
    -- Update item slots
    self:updateItemSlots()
    
    -- Show notification
    print(unit.unitType:upper() .. " unequipped " .. item.name)
end

-- Gold changed callback
function InventoryUI:onGoldChanged(oldValue, newValue)
    -- Show notification
    local difference = newValue - oldValue
    if difference > 0 then
        print("Gained " .. difference .. " gold")
    else
        print("Lost " .. math.abs(difference) .. " gold")
    end
end

return InventoryUI
