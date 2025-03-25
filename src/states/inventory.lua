-- Inventory State for Nightfall Chess
-- Handles inventory management, item usage, and equipment

local gamestate = require("lib.hump.gamestate")
local timer = require("lib.hump.timer")

local Inventory = {}

-- Inventory state variables
local items = {}
local selectedItemIndex = 1
local selectedUnitIndex = 1
local playerUnits = {}
local returnState = nil
local uiElements = {}
local scrollOffset = 0
local maxScroll = 0
local itemCategories = {"Weapon", "Armor", "Accessory", "Consumable", "Key"}
local selectedCategory = "All"

-- Initialize the inventory state
function Inventory:init()
    -- This function is called only once when the state is first created
end

-- Enter the inventory state
function Inventory:enter(previous, game, unitsList, itemsList, returnToState)
    self.game = game
    returnState = returnToState or require("src.states.game")
    
    -- Use provided units or empty list
    playerUnits = unitsList or {}
    
    -- Use provided items or create default ones
    if itemsList then
        items = itemsList
    else
        self:createDefaultItems()
    end
    
    -- Initialize UI elements
    self:initUI()
    
    -- Reset selection
    selectedItemIndex = math.min(selectedItemIndex, #items)
    if selectedItemIndex < 1 and #items > 0 then selectedItemIndex = 1 end
    
    selectedUnitIndex = math.min(selectedUnitIndex, #playerUnits)
    if selectedUnitIndex < 1 and #playerUnits > 0 then selectedUnitIndex = 1 end
    
    -- Calculate max scroll
    self:updateMaxScroll()
    
    -- Set up animations
    self.menuAlpha = 0
    timer.tween(0.3, self, {menuAlpha = 1}, 'out-quad')
end

-- Leave the inventory state
function Inventory:leave()
    -- Clean up resources
end

-- Update inventory logic
function Inventory:update(dt)
    -- Update timers
    timer.update(dt)
    
    -- Update UI animations
    for _, element in pairs(uiElements) do
        if element.update then
            element:update(dt)
        end
    end
end

-- Draw the inventory
function Inventory:draw()
    local width, height = love.graphics.getDimensions()
    
    -- Draw background
    love.graphics.setColor(0.1, 0.1, 0.15, self.menuAlpha)
    love.graphics.rectangle("fill", 0, 0, width, height)
    
    -- Draw inventory panel
    self:drawInventoryPanel(width, height)
    
    -- Draw unit panel
    self:drawUnitPanel(width, height)
    
    -- Draw item details panel
    self:drawItemDetailsPanel(width, height)
    
    -- Draw category tabs
    self:drawCategoryTabs(width, height)
    
    -- Draw help text
    love.graphics.setColor(0.8, 0.8, 0.8, self.menuAlpha * 0.8)
    love.graphics.setFont(self.game.assets.fonts.small)
    love.graphics.printf("Arrow Keys: Navigate | Space: Use/Equip | Tab: Switch Panel | C: Filter Category | Esc: Back", 0, height - 25, width, "center")
end

-- Draw inventory panel
function Inventory:drawInventoryPanel(width, height)
    -- Draw panel background
    love.graphics.setColor(0.2, 0.2, 0.25, self.menuAlpha * 0.9)
    love.graphics.rectangle("fill", 20, 60, 300, height - 100, 5, 5)
    
    love.graphics.setColor(0.4, 0.4, 0.5, self.menuAlpha)
    love.graphics.rectangle("line", 20, 60, 300, height - 100, 5, 5)
    
    -- Draw panel title
    love.graphics.setColor(0.9, 0.9, 1, self.menuAlpha)
    love.graphics.setFont(self.game.assets.fonts.medium)
    love.graphics.print("Inventory", 35, 70)
    
    -- Draw items
    love.graphics.setFont(self.game.assets.fonts.small)
    
    local itemsPerPage = 15
    local startIndex = math.max(1, math.min(scrollOffset + 1, #items - itemsPerPage + 1))
    local endIndex = math.min(startIndex + itemsPerPage - 1, #items)
    
    for i = startIndex, endIndex do
        local item = items[i]
        local y = 100 + (i - startIndex) * 25
        
        -- Draw selection highlight
        if i == selectedItemIndex then
            love.graphics.setColor(0.3, 0.5, 0.7, self.menuAlpha * 0.7)
            love.graphics.rectangle("fill", 25, y, 290, 24)
            love.graphics.setColor(0.5, 0.7, 0.9, self.menuAlpha)
            love.graphics.rectangle("line", 25, y, 290, 24)
        end
        
        -- Draw item icon (placeholder)
        love.graphics.setColor(0.8, 0.8, 0.8, self.menuAlpha)
        love.graphics.rectangle("line", 30, y + 2, 20, 20)
        
        -- Draw item name with color based on rarity
        local rarityColors = {
            common = {0.8, 0.8, 0.8},
            uncommon = {0.2, 0.8, 0.2},
            rare = {0.2, 0.2, 0.9},
            epic = {0.8, 0.2, 0.8},
            legendary = {0.9, 0.6, 0.1}
        }
        
        local color = rarityColors[item.rarity] or rarityColors.common
        love.graphics.setColor(color[1], color[2], color[3], self.menuAlpha)
        love.graphics.print(item.name, 55, y + 3)
        
        -- Draw item quantity if stackable
        if item.quantity and item.quantity > 1 then
            love.graphics.setColor(0.7, 0.7, 0.7, self.menuAlpha)
            love.graphics.printf("x" .. item.quantity, 200, y + 3, 100, "right")
        end
        
        -- Draw equipped indicator
        if item.equipped then
            love.graphics.setColor(0.2, 0.8, 0.2, self.menuAlpha)
            love.graphics.print("[E]", 280, y + 3)
        end
    end
    
    -- Draw scrollbar if needed
    if #items > itemsPerPage then
        local scrollbarHeight = (itemsPerPage / #items) * (height - 120)
        local scrollbarY = 70 + (scrollOffset / (#items - itemsPerPage)) * (height - 120 - scrollbarHeight)
        
        love.graphics.setColor(0.3, 0.3, 0.4, self.menuAlpha * 0.7)
        love.graphics.rectangle("fill", 315, 70, 5, height - 120)
        
        love.graphics.setColor(0.5, 0.5, 0.6, self.menuAlpha)
        love.graphics.rectangle("fill", 315, scrollbarY, 5, scrollbarHeight)
    end
end

-- Draw unit panel
function Inventory:drawUnitPanel(width, height)
    -- Draw panel background
    love.graphics.setColor(0.2, 0.2, 0.25, self.menuAlpha * 0.9)
    love.graphics.rectangle("fill", width - 320, 60, 300, 200, 5, 5)
    
    love.graphics.setColor(0.4, 0.4, 0.5, self.menuAlpha)
    love.graphics.rectangle("line", width - 320, 60, 300, 200, 5, 5)
    
    -- Draw panel title
    love.graphics.setColor(0.9, 0.9, 1, self.menuAlpha)
    love.graphics.setFont(self.game.assets.fonts.medium)
    love.graphics.print("Units", width - 305, 70)
    
    -- Draw units
    if #playerUnits == 0 then
        love.graphics.setColor(0.7, 0.7, 0.7, self.menuAlpha)
        love.graphics.setFont(self.game.assets.fonts.small)
        love.graphics.printf("No units available", width - 310, 130, 280, "center")
        return
    end
    
    for i, unit in ipairs(playerUnits) do
        local y = 100 + (i - 1) * 30
        
        -- Draw selection highlight
        if i == selectedUnitIndex then
            love.graphics.setColor(0.3, 0.5, 0.7, self.menuAlpha * 0.7)
            love.graphics.rectangle("fill", width - 315, y, 290, 29)
            love.graphics.setColor(0.5, 0.7, 0.9, self.menuAlpha)
            love.graphics.rectangle("line", width - 315, y, 290, 29)
        end
        
        -- Draw unit icon (placeholder)
        love.graphics.setColor(0.8, 0.8, 0.8, self.menuAlpha)
        love.graphics.rectangle("line", width - 310, y + 2, 25, 25)
        
        -- Draw unit name
        love.graphics.setColor(0.9, 0.9, 0.9, self.menuAlpha)
        love.graphics.setFont(self.game.assets.fonts.small)
        love.graphics.print(unit.unitType:upper(), width - 280, y + 2)
        
        -- Draw unit health
        love.graphics.setColor(0.2, 0.8, 0.2, self.menuAlpha)
        love.graphics.print("HP: " .. unit.stats.health .. "/" .. unit.stats.maxHealth, width - 280, y + 17)
        
        -- Draw unit level
        love.graphics.setColor(0.8, 0.8, 0.2, self.menuAlpha)
        love.graphics.print("LVL: " .. unit.level, width - 180, y + 17)
    end
end

-- Draw item details panel
function Inventory:drawItemDetailsPanel(width, height)
    -- Draw panel background
    love.graphics.setColor(0.2, 0.2, 0.25, self.menuAlpha * 0.9)
    love.graphics.rectangle("fill", width - 320, 280, 300, height - 320, 5, 5)
    
    love.graphics.setColor(0.4, 0.4, 0.5, self.menuAlpha)
    love.graphics.rectangle("line", width - 320, 280, 300, height - 320, 5, 5)
    
    -- Draw panel title
    love.graphics.setColor(0.9, 0.9, 1, self.menuAlpha)
    love.graphics.setFont(self.game.assets.fonts.medium)
    love.graphics.print("Item Details", width - 305, 290)
    
    -- Draw item details if an item is selected
    if selectedItemIndex > 0 and selectedItemIndex <= #items then
        local item = items[selectedItemIndex]
        
        -- Draw item name with color based on rarity
        local rarityColors = {
            common = {0.8, 0.8, 0.8},
            uncommon = {0.2, 0.8, 0.2},
            rare = {0.2, 0.2, 0.9},
            epic = {0.8, 0.2, 0.8},
            legendary = {0.9, 0.6, 0.1}
        }
        
        local color = rarityColors[item.rarity] or rarityColors.common
        love.graphics.setColor(color[1], color[2], color[3], self.menuAlpha)
        love.graphics.setFont(self.game.assets.fonts.medium)
        love.graphics.printf(item.name, width - 310, 320, 280, "center")
        
        -- Draw item type and rarity
        love.graphics.setColor(0.7, 0.7, 0.7, self.menuAlpha)
        love.graphics.setFont(self.game.assets.fonts.small)
        love.graphics.printf(item.type .. " - " .. item.rarity:sub(1,1):upper() .. item.rarity:sub(2), width - 310, 350, 280, "center")
        
        -- Draw item stats
        love.graphics.setColor(0.9, 0.9, 0.9, self.menuAlpha)
        local y = 380
        
        if item.stats then
            for stat, value in pairs(item.stats) do
                local statText = stat:sub(1,1):upper() .. stat:sub(2) .. ": "
                
                if value > 0 then
                    statText = statText .. "+" .. value
                    love.graphics.setColor(0.2, 0.8, 0.2, self.menuAlpha)
                else
                    statText = statText .. value
                    love.graphics.setColor(0.8, 0.2, 0.2, self.menuAlpha)
                end
                
                love.graphics.print(statText, width - 300, y)
                y = y + 20
            end
        end
        
        -- Draw item description
        love.graphics.setColor(0.8, 0.8, 0.8, self.menuAlpha)
        love.graphics.printf(item.description, width - 300, y + 10, 260, "left")
        
        -- Draw usage instructions
        if item.type == "Consumable" then
            love.graphics.setColor(0.2, 0.8, 0.8, self.menuAlpha)
            love.graphics.printf("Press SPACE to use", width - 310, height - 80, 280, "center")
        elseif item.type == "Weapon" or item.type == "Armor" or item.type == "Accessory" then
            love.graphics.setColor(0.2, 0.8, 0.8, self.menuAlpha)
            love.graphics.printf("Press SPACE to equip/unequip", width - 310, height - 80, 280, "center")
        end
    else
        -- No item selected
        love.graphics.setColor(0.7, 0.7, 0.7, self.menuAlpha)
        love.graphics.setFont(self.game.assets.fonts.small)
        love.graphics.printf("No item selected", width - 310, 350, 280, "center")
    end
end

-- Draw category tabs
function Inventory:drawCategoryTabs(width, height)
    local tabWidth = 80
    local tabHeight = 30
    local startX = 20
    local y = 30
    
    -- Draw "All" tab
    self:drawCategoryTab("All", startX, y, tabWidth, tabHeight)
    
    -- Draw category tabs
    for i, category in ipairs(itemCategories) do
        self:drawCategoryTab(category, startX + i * tabWidth, y, tabWidth, tabHeight)
    end
end

-- Draw a single category tab
function Inventory:drawCategoryTab(category, x, y, width, height)
    local isSelected = (category == selectedCategory)
    
    -- Draw tab background
    if isSelected then
        love.graphics.setColor(0.3, 0.5, 0.7, self.menuAlpha * 0.9)
    else
        love.graphics.setColor(0.2, 0.2, 0.25, self.menuAlpha * 0.7)
    end
    
    love.graphics.rectangle("fill", x, y, width, height, 5, 5)
    
    -- Draw tab border
    if isSelected then
        love.graphics.setColor(0.5, 0.7, 0.9, self.menuAlpha)
    else
        love.graphics.setColor(0.4, 0.4, 0.5, self.menuAlpha * 0.7)
    end
    
    love.graphics.rectangle("line", x, y, width, height, 5, 5)
    
    -- Draw tab text
    love.graphics.setColor(0.9, 0.9, 1, self.menuAlpha)
    love.graphics.setFont(self.game.assets.fonts.small)
    love.graphics.printf(category, x, y + 8, width, "center")
end

-- Initialize UI elements
function Inventory:initUI()
    -- Create UI elements here
    uiElements = {
        -- Add UI elements as needed
    }
end

-- Create default items
function Inventory:createDefaultItems()
    items = {
        {
            name = "Steel Sword",
            type = "Weapon",
            rarity = "common",
            description = "A standard steel sword. Provides a small boost to attack.",
            stats = {
                attack = 2
            },
            equipped = false
        },
        {
            name = "Leather Armor",
            type = "Armor",
            rarity = "common",
            description = "Basic leather armor. Provides minimal protection.",
            stats = {
                defense = 1
            },
            equipped = false
        },
        {
            name = "Health Potion",
            type = "Consumable",
            rarity = "common",
            description = "Restores 10 health points when consumed.",
            effect = {
                health = 10
            },
            quantity = 3
        },
        {
            name = "Energy Crystal",
            type = "Consumable",
            rarity = "uncommon",
            description = "Restores 5 energy points when consumed.",
            effect = {
                energy = 5
            },
            quantity = 2
        },
        {
            name = "Knight's Gauntlet",
            type = "Accessory",
            rarity = "uncommon",
            description = "Enhances knight movement, allowing for more aggressive positioning.",
            stats = {
                moveRange = 1
            },
            equipped = false
        },
        {
            name = "Enchanted Bishop Staff",
            type = "Weapon",
            rarity = "rare",
            description = "A magical staff that enhances the bishop's diagonal attacks.",
            stats = {
                attack = 3,
                attackRange = 1
            },
            equipped = false
        },
        {
            name = "Rook's Bulwark",
            type = "Armor",
            rarity = "rare",
            description = "Heavy armor designed for the rook. Significantly increases defense at the cost of mobility.",
            stats = {
                defense = 4,
                moveRange = -1
            },
            equipped = false
        },
        {
            name = "Queen's Crown",
            type = "Accessory",
            rarity = "epic",
            description = "A royal crown that enhances all attributes of the wearer.",
            stats = {
                attack = 2,
                defense = 2,
                moveRange = 1,
                health = 10
            },
            equipped = false
        },
        {
            name = "Dungeon Key",
            type = "Key",
            rarity = "common",
            description = "A key that unlocks standard doors in the dungeon.",
            quantity = 1
        }
    }
end

-- Update maximum scroll value
function Inventory:updateMaxScroll()
    local itemsPerPage = 15
    maxScroll = math.max(0, #self:getFilteredItems() - itemsPerPage)
    scrollOffset = math.min(scrollOffset, maxScroll)
end

-- Get filtered items based on selected category
function Inventory:getFilteredItems()
    if selectedCategory == "All" then
        return items
    end
    
    local filtered = {}
    for _, item in ipairs(items) do
        if item.type == selectedCategory then
            table.insert(filtered, item)
        end
    end
    
    return filtered
end

-- Use or equip the selected item
function Inventory:useSelectedItem()
    if selectedItemIndex <= 0 or selectedItemIndex > #items then
        return false
    end
    
    local item = items[selectedItemIndex]
    
    -- Check if we have a selected unit
    if selectedUnitIndex <= 0 or selectedUnitIndex > #playerUnits then
        return false
    end
    
    local unit = playerUnits[selectedUnitIndex]
    
    -- Handle different item types
    if item.type == "Consumable" then
        -- Use consumable item
        if item.effect then
            -- Apply effects
            if item.effect.health then
                unit.stats.health = math.min(unit.stats.maxHealth, unit.stats.health + item.effect.health)
            end
            
            if item.effect.energy then
                unit.stats.energy = math.min(unit.stats.maxEnergy, unit.stats.energy + item.effect.energy)
            end
            
            -- Reduce quantity
            item.quantity = item.quantity - 1
            
            -- Remove if quantity is zero
            if item.quantity <= 0 then
                table.remove(items, selectedItemIndex)
                selectedItemIndex = math.min(selectedItemIndex, #items)
            end
            
            return true
        end
    elseif item.type == "Weapon" or item.type == "Armor" or item.type == "Accessory" then
        -- Toggle equipped state
        item.equipped = not item.equipped
        
        -- If equipped, apply stats
        if item.equipped then
            -- Unequip any other items of the same type
            for i, otherItem in ipairs(items) do
                if i ~= selectedItemIndex and otherItem.type == item.type and otherItem.equipped then
                    otherItem.equipped = false
                end
            end
        end
        
        return true
    end
    
    return false
end

-- Select a category
function Inventory:selectCategory(category)
    if category == selectedCategory then
        return
    end
    
    selectedCategory = category
    scrollOffset = 0
    selectedItemIndex = 1
    self:updateMaxScroll()
end

-- Handle keypresses
function Inventory:keypressed(key)
    if key == "escape" then
        -- Return to previous state
        gamestate.switch(returnState, self.game)
    elseif key == "up" then
        -- Navigate up
        if love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift") then
            -- Scroll inventory
            scrollOffset = math.max(0, scrollOffset - 1)
        else
            -- Select previous item/unit
            if uiElements.activePanel == "units" then
                selectedUnitIndex = selectedUnitIndex - 1
                if selectedUnitIndex < 1 then
                    selectedUnitIndex = #playerUnits
                end
            else
                selectedItemIndex = selectedItemIndex - 1
                if selectedItemIndex < 1 then
                    selectedItemIndex = #items
                end
                
                -- Adjust scroll if needed
                if selectedItemIndex < scrollOffset + 1 then
                    scrollOffset = math.max(0, selectedItemIndex - 1)
                end
            end
        end
    elseif key == "down" then
        -- Navigate down
        if love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift") then
            -- Scroll inventory
            scrollOffset = math.min(maxScroll, scrollOffset + 1)
        else
            -- Select next item/unit
            if uiElements.activePanel == "units" then
                selectedUnitIndex = selectedUnitIndex + 1
                if selectedUnitIndex > #playerUnits then
                    selectedUnitIndex = 1
                end
            else
                selectedItemIndex = selectedItemIndex + 1
                if selectedItemIndex > #items then
                    selectedItemIndex = 1
                end
                
                -- Adjust scroll if needed
                local itemsPerPage = 15
                if selectedItemIndex > scrollOffset + itemsPerPage then
                    scrollOffset = selectedItemIndex - itemsPerPage
                end
            end
        end
    elseif key == "tab" then
        -- Switch between inventory and units panel
        if uiElements.activePanel == "inventory" then
            uiElements.activePanel = "units"
        else
            uiElements.activePanel = "inventory"
        end
    elseif key == "space" then
        -- Use or equip selected item
        self:useSelectedItem()
    elseif key == "c" then
        -- Cycle through categories
        local categories = {"All"}
        for _, category in ipairs(itemCategories) do
            table.insert(categories, category)
        end
        
        local currentIndex = 1
        for i, category in ipairs(categories) do
            if category == selectedCategory then
                currentIndex = i
                break
            end
        end
        
        currentIndex = currentIndex % #categories + 1
        self:selectCategory(categories[currentIndex])
    end
end

-- Handle mouse wheel movement
function Inventory:wheelmoved(x, y)
    -- Scroll inventory
    if y > 0 then
        -- Scroll up
        scrollOffset = math.max(0, scrollOffset - 1)
    elseif y < 0 then
        -- Scroll down
        scrollOffset = math.min(maxScroll, scrollOffset + 1)
    end
end

-- Handle mouse presses
function Inventory:mousepressed(x, y, button)
    if button == 1 then -- Left click
        -- Check if clicking on category tabs
        local tabWidth = 80
        local tabHeight = 30
        local startX = 20
        local tabY = 30
        
        -- Check "All" tab
        if x >= startX and x < startX + tabWidth and y >= tabY and y < tabY + tabHeight then
            self:selectCategory("All")
            return
        end
        
        -- Check other category tabs
        for i, category in ipairs(itemCategories) do
            local tabX = startX + i * tabWidth
            if x >= tabX and x < tabX + tabWidth and y >= tabY and y < tabY + tabHeight then
                self:selectCategory(category)
                return
            end
        end
        
        -- Check if clicking on inventory items
        if x >= 20 and x < 320 and y >= 100 and y < 100 + 15 * 25 then
            local itemIndex = math.floor((y - 100) / 25) + scrollOffset + 1
            if itemIndex >= 1 and itemIndex <= #items then
                selectedItemIndex = itemIndex
            end
        end
        
        -- Check if clicking on units
        local width = love.graphics.getWidth()
        if x >= width - 320 and x < width - 20 and y >= 100 and y < 100 + #playerUnits * 30 then
            local unitIndex = math.floor((y - 100) / 30) + 1
            if unitIndex >= 1 and unitIndex <= #playerUnits then
                selectedUnitIndex = unitIndex
            end
        end
    end
end

return Inventory
