-- Team Management State for Nightfall Chess
-- Handles team selection, unit purchasing, and item management before starting a game

local gamestate = require("lib.hump.gamestate")
local timer = require("lib.hump.timer")
local Unit = require("src.entities.unit")
local Item = require("src.entities.item")

local TeamManagement = {}

-- UI elements
local titleFont = nil
local menuFont = nil
local smallFont = nil
local buttonFont = nil

-- Store data
local playerCurrency = 1000  -- Starting currency
local availableUnits = {}
local availableItems = {}
local selectedUnits = {}
local selectedItems = {}
local maxTeamSize = 4

-- UI state
local currentTab = "units"  -- "units" or "items"
local selectedUnitIndex = 1
local selectedItemIndex = 1
local hoveredUnit = nil
local hoveredItem = nil
local scrollOffset = 0
local maxScroll = 0

-- Initialize the team management state
function TeamManagement:init()
    -- This function is called only once when the state is first created
end

-- Enter the team management state
function TeamManagement:enter(previous, game)
    self.game = game
    
    -- Load fonts
    titleFont = game.assets.fonts.title
    menuFont = game.assets.fonts.large
    smallFont = game.assets.fonts.small
    buttonFont = game.assets.fonts.medium
    
    -- Initialize store data
    self:initializeStore()
    
    -- Set up animations
    self.menuAlpha = 0
    timer.tween(0.5, self, {menuAlpha = 1}, 'out-quad')
    
    -- Play store music if available
    -- if game.assets.sounds.storeMusic then
    --     love.audio.play(game.assets.sounds.storeMusic)
    -- end
end

-- Leave the team management state
function TeamManagement:leave()
    -- Stop store music if it's playing
    -- if self.game.assets.sounds.storeMusic then
    --     love.audio.stop(self.game.assets.sounds.storeMusic)
    -- end
end

-- Initialize store with available units and items
function TeamManagement:initializeStore()
    -- Clear previous data
    availableUnits = {}
    availableItems = {}
    selectedUnits = {}
    selectedItems = {}
    
    -- Add available units
    table.insert(availableUnits, {
        type = "knight",
        name = "Knight",
        description = "Moves in L-shape patterns and can jump over other units.",
        cost = 300,
        stats = {
            health = 120,
            attack = 8,
            defense = 6,
            speed = 7
        },
        abilities = {"Knight's Charge", "Feint"}
    })
    
    table.insert(availableUnits, {
        type = "rook",
        name = "Rook",
        description = "Moves in straight lines with high defense.",
        cost = 400,
        stats = {
            health = 150,
            attack = 10,
            defense = 8,
            speed = 5
        },
        abilities = {"Fortify", "Shockwave"}
    })
    
    table.insert(availableUnits, {
        type = "bishop",
        name = "Bishop",
        description = "Moves diagonally with support abilities.",
        cost = 350,
        stats = {
            health = 100,
            attack = 7,
            defense = 5,
            speed = 6
        },
        abilities = {"Healing Light", "Mystic Barrier"}
    })
    
    table.insert(availableUnits, {
        type = "pawn",
        name = "Pawn",
        description = "Basic unit with promotion potential.",
        cost = 150,
        stats = {
            health = 80,
            attack = 5,
            defense = 4,
            speed = 4
        },
        abilities = {"Advance", "Shield Bash"}
    })
    
    table.insert(availableUnits, {
        type = "queen",
        name = "Queen",
        description = "Powerful unit with versatile movement.",
        cost = 800,
        stats = {
            health = 130,
            attack = 12,
            defense = 7,
            speed = 8
        },
        abilities = {"Royal Command", "Multiattack"}
    })
    
    -- Add available items
    table.insert(availableItems, {
        type = "weapon",
        name = "Steel Sword",
        description = "Increases attack by 3.",
        cost = 200,
        stats = {
            attack = 3
        }
    })
    
    table.insert(availableItems, {
        type = "armor",
        name = "Chain Mail",
        description = "Increases defense by 2.",
        cost = 150,
        stats = {
            defense = 2
        }
    })
    
    table.insert(availableItems, {
        type = "accessory",
        name = "Speed Amulet",
        description = "Increases speed by 2.",
        cost = 180,
        stats = {
            speed = 2
        }
    })
    
    table.insert(availableItems, {
        type = "consumable",
        name = "Health Potion",
        description = "Restores 50 health when used.",
        cost = 100,
        effect = "heal",
        value = 50
    })
    
    table.insert(availableItems, {
        type = "consumable",
        name = "Strength Elixir",
        description = "Temporarily increases attack by 5.",
        cost = 120,
        effect = "buff",
        stat = "attack",
        value = 5,
        duration = 3
    })
    
    -- Add a default pawn to the team
    self:addUnitToTeam(1)
end

-- Update team management logic
function TeamManagement:update(dt)
    -- Update animations
    timer.update(dt)
    
    -- Update max scroll based on content
    if currentTab == "units" then
        maxScroll = math.max(0, #availableUnits * 110 - 400)
    else
        maxScroll = math.max(0, #availableItems * 110 - 400)
    end
    
    -- Clamp scroll offset
    scrollOffset = math.max(0, math.min(scrollOffset, maxScroll))
end

-- Draw the team management screen
function TeamManagement:draw()
    local width, height = love.graphics.getDimensions()
    
    -- Draw background
    love.graphics.setColor(0.1, 0.1, 0.2, 1)
    love.graphics.rectangle("fill", 0, 0, width, height)
    
    -- Draw title
    love.graphics.setColor(0.9, 0.9, 1, self.menuAlpha)
    love.graphics.setFont(titleFont)
    love.graphics.printf("Team Management", 0, 30, width, "center")
    
    -- Draw currency
    love.graphics.setColor(0.9, 0.8, 0.3, self.menuAlpha)
    love.graphics.setFont(menuFont)
    love.graphics.printf("Gold: " .. playerCurrency, width - 250, 30, 200, "right")
    
    -- Draw tabs
    self:drawTabs(width, height)
    
    -- Draw store content
    self:drawStoreContent(width, height)
    
    -- Draw selected team
    self:drawSelectedTeam(width, height)
    
    -- Draw buttons
    self:drawButtons(width, height)
    
    -- Draw hover information
    self:drawHoverInfo(width, height)
end

-- Draw the tabs for switching between units and items
function TeamManagement:drawTabs(width, height)
    local tabWidth = 150
    local tabHeight = 40
    local tabY = 100
    
    -- Units tab
    if currentTab == "units" then
        love.graphics.setColor(0.3, 0.5, 0.8, self.menuAlpha)
    else
        love.graphics.setColor(0.2, 0.3, 0.5, self.menuAlpha)
    end
    love.graphics.rectangle("fill", width/4 - tabWidth/2, tabY, tabWidth, tabHeight, 10, 10)
    
    -- Items tab
    if currentTab == "items" then
        love.graphics.setColor(0.3, 0.5, 0.8, self.menuAlpha)
    else
        love.graphics.setColor(0.2, 0.3, 0.5, self.menuAlpha)
    end
    love.graphics.rectangle("fill", width*3/4 - tabWidth/2, tabY, tabWidth, tabHeight, 10, 10)
    
    -- Tab text
    love.graphics.setColor(1, 1, 1, self.menuAlpha)
    love.graphics.setFont(menuFont)
    love.graphics.printf("Units", width/4 - tabWidth/2, tabY + 5, tabWidth, "center")
    love.graphics.printf("Items", width*3/4 - tabWidth/2, tabY + 5, tabWidth, "center")
end

-- Draw the store content (units or items)
function TeamManagement:drawStoreContent(width, height)
    local contentX = 50
    local contentY = 160
    local contentWidth = width - 100
    local contentHeight = height - 300
    
    -- Draw content background
    love.graphics.setColor(0.15, 0.15, 0.25, self.menuAlpha * 0.7)
    love.graphics.rectangle("fill", contentX, contentY, contentWidth, contentHeight, 10, 10)
    
    -- Draw content based on current tab
    if currentTab == "units" then
        self:drawUnitsStore(contentX, contentY, contentWidth, contentHeight)
    else
        self:drawItemsStore(contentX, contentY, contentWidth, contentHeight)
    end
    
    -- Draw scrollbar if needed
    if maxScroll > 0 then
        local scrollbarHeight = contentHeight * (contentHeight / (contentHeight + maxScroll))
        local scrollbarY = contentY + (scrollOffset / maxScroll) * (contentHeight - scrollbarHeight)
        
        love.graphics.setColor(0.5, 0.5, 0.6, self.menuAlpha * 0.7)
        love.graphics.rectangle("fill", contentX + contentWidth - 15, scrollbarY, 10, scrollbarHeight, 5, 5)
    end
end

-- Draw the units store
function TeamManagement:drawUnitsStore(x, y, width, height)
    love.graphics.setFont(menuFont)
    
    -- Draw column headers
    love.graphics.setColor(0.7, 0.7, 0.9, self.menuAlpha)
    love.graphics.printf("Unit", x + 20, y + 10, 150, "left")
    love.graphics.printf("Stats", x + 180, y + 10, 200, "left")
    love.graphics.printf("Cost", x + width - 150, y + 10, 100, "right")
    
    -- Draw separator line
    love.graphics.setColor(0.3, 0.3, 0.5, self.menuAlpha)
    love.graphics.rectangle("fill", x + 20, y + 45, width - 40, 2)
    
    -- Draw units list
    love.graphics.setFont(smallFont)
    for i, unit in ipairs(availableUnits) do
        local unitY = y + 60 + (i-1) * 110 - scrollOffset
        
        -- Only draw if in visible area
        if unitY + 100 > y and unitY < y + height then
            -- Draw selection highlight
            if i == selectedUnitIndex then
                love.graphics.setColor(0.3, 0.5, 0.8, self.menuAlpha * 0.3)
                love.graphics.rectangle("fill", x + 10, unitY - 5, width - 20, 100, 5, 5)
            end
            
            -- Draw hover highlight
            if hoveredUnit == i then
                love.graphics.setColor(0.4, 0.6, 0.9, self.menuAlpha * 0.2)
                love.graphics.rectangle("fill", x + 10, unitY - 5, width - 20, 100, 5, 5)
            end
            
            -- Draw unit info
            love.graphics.setColor(0.9, 0.9, 1, self.menuAlpha)
            love.graphics.setFont(menuFont)
            love.graphics.printf(unit.name, x + 20, unitY, 150, "left")
            
            love.graphics.setFont(smallFont)
            love.graphics.setColor(0.7, 0.7, 0.8, self.menuAlpha)
            love.graphics.printf(unit.description, x + 20, unitY + 35, 150, "left")
            
            -- Draw stats
            love.graphics.setColor(0.7, 0.8, 0.9, self.menuAlpha)
            love.graphics.printf("HP: " .. unit.stats.health, x + 180, unitY + 10, 100, "left")
            love.graphics.printf("ATK: " .. unit.stats.attack, x + 180, unitY + 30, 100, "left")
            love.graphics.printf("DEF: " .. unit.stats.defense, x + 180, unitY + 50, 100, "left")
            love.graphics.printf("SPD: " .. unit.stats.speed, x + 180, unitY + 70, 100, "left")
            
            -- Draw abilities
            love.graphics.setColor(0.6, 0.8, 0.6, self.menuAlpha)
            love.graphics.printf("Abilities: " .. table.concat(unit.abilities, ", "), x + 300, unitY + 40, 200, "left")
            
            -- Draw cost
            love.graphics.setColor(0.9, 0.8, 0.3, self.menuAlpha)
            love.graphics.setFont(menuFont)
            love.graphics.printf(unit.cost .. " G", x + width - 150, unitY + 30, 100, "right")
            
            -- Draw buy button
            local canAfford = playerCurrency >= unit.cost
            local buttonColor = canAfford and {0.3, 0.7, 0.3, self.menuAlpha} or {0.5, 0.5, 0.5, self.menuAlpha * 0.7}
            
            love.graphics.setColor(buttonColor)
            love.graphics.rectangle("fill", x + width - 120, unitY + 60, 80, 30, 5, 5)
            
            love.graphics.setColor(1, 1, 1, self.menuAlpha)
            love.graphics.setFont(smallFont)
            love.graphics.printf("Buy", x + width - 120, unitY + 65, 80, "center")
            
            -- Draw separator line
            love.graphics.setColor(0.2, 0.2, 0.3, self.menuAlpha)
            love.graphics.rectangle("fill", x + 20, unitY + 105, width - 40, 1)
        end
    end
end

-- Draw the items store
function TeamManagement:drawItemsStore(x, y, width, height)
    love.graphics.setFont(menuFont)
    
    -- Draw column headers
    love.graphics.setColor(0.7, 0.7, 0.9, self.menuAlpha)
    love.graphics.printf("Item", x + 20, y + 10, 150, "left")
    love.graphics.printf("Effect", x + 180, y + 10, 300, "left")
    love.graphics.printf("Cost", x + width - 150, y + 10, 100, "right")
    
    -- Draw separator line
    love.graphics.setColor(0.3, 0.3, 0.5, self.menuAlpha)
    love.graphics.rectangle("fill", x + 20, y + 45, width - 40, 2)
    
    -- Draw items list
    love.graphics.setFont(smallFont)
    for i, item in ipairs(availableItems) do
        local itemY = y + 60 + (i-1) * 110 - scrollOffset
        
        -- Only draw if in visible area
        if itemY + 100 > y and itemY < y + height then
            -- Draw selection highlight
            if i == selectedItemIndex then
                love.graphics.setColor(0.3, 0.5, 0.8, self.menuAlpha * 0.3)
                love.graphics.rectangle("fill", x + 10, itemY - 5, width - 20, 100, 5, 5)
            end
            
            -- Draw hover highlight
            if hoveredItem == i then
                love.graphics.setColor(0.4, 0.6, 0.9, self.menuAlpha * 0.2)
                love.graphics.rectangle("fill", x + 10, itemY - 5, width - 20, 100, 5, 5)
            end
            
            -- Draw item info
            love.graphics.setColor(0.9, 0.9, 1, self.menuAlpha)
            love.graphics.setFont(menuFont)
            love.graphics.printf(item.name, x + 20, itemY, 150, "left")
            
            love.graphics.setFont(smallFont)
            love.graphics.setColor(0.7, 0.7, 0.8, self.menuAlpha)
            love.graphics.printf(item.description, x + 20, itemY + 35, 150, "left")
            
            -- Draw item type
            local typeColor = {0.7, 0.7, 0.8, self.menuAlpha}
            if item.type == "weapon" then
                typeColor = {0.8, 0.5, 0.5, self.menuAlpha}
            elseif item.type == "armor" then
                typeColor = {0.5, 0.7, 0.8, self.menuAlpha}
            elseif item.type == "accessory" then
                typeColor = {0.8, 0.7, 0.5, self.menuAlpha}
            elseif item.type == "consumable" then
                typeColor = {0.6, 0.8, 0.6, self.menuAlpha}
            end
            
            love.graphics.setColor(typeColor)
            love.graphics.printf("Type: " .. item.type:sub(1,1):upper() .. item.type:sub(2), x + 20, itemY + 70, 150, "left")
            
            -- Draw effect
            love.graphics.setColor(0.7, 0.8, 0.9, self.menuAlpha)
            love.graphics.printf(item.description, x + 180, itemY + 30, 300, "left")
            
            -- Draw cost
            love.graphics.setColor(0.9, 0.8, 0.3, self.menuAlpha)
            love.graphics.setFont(menuFont)
            love.graphics.printf(item.cost .. " G", x + width - 150, itemY + 30, 100, "right")
            
            -- Draw buy button
            local canAfford = playerCurrency >= item.cost
            local buttonColor = canAfford and {0.3, 0.7, 0.3, self.menuAlpha} or {0.5, 0.5, 0.5, self.menuAlpha * 0.7}
            
            love.graphics.setColor(buttonColor)
            love.graphics.rectangle("fill", x + width - 120, itemY + 60, 80, 30, 5, 5)
            
            love.graphics.setColor(1, 1, 1, self.menuAlpha)
            love.graphics.setFont(smallFont)
            love.graphics.printf("Buy", x + width - 120, itemY + 65, 80, "center")
            
            -- Draw separator line
            love.graphics.setColor(0.2, 0.2, 0.3, self.menuAlpha)
            love.graphics.rectangle("fill", x + 20, itemY + 105, width - 40, 1)
        end
    end
end

-- Draw the selected team
function TeamManagement:drawSelectedTeam(width, height)
    local teamX = 50
    local teamY = height - 120
    local teamWidth = width - 100
    local teamHeight = 100
    
    -- Draw team background
    love.graphics.setColor(0.15, 0.15, 0.25, self.menuAlpha * 0.7)
    love.graphics.rectangle("fill", teamX, teamY, teamWidth, teamHeight, 10, 10)
    
    -- Draw team title
    love.graphics.setColor(0.7, 0.7, 0.9, self.menuAlpha)
    love.graphics.setFont(menuFont)
    love.graphics.printf("Your Team", teamX + 20, teamY + 10, 200, "left")
    
    -- Draw team slots
    local slotWidth = 80
    local slotHeight = 80
    local slotY = teamY + 35
    local slotSpacing = 20
    local startX = width/2 - ((slotWidth + slotSpacing) * maxTeamSize)/2
    
    for i = 1, maxTeamSize do
        local slotX = startX + (i-1) * (slotWidth + slotSpacing)
        
        -- Draw slot background
        love.graphics.setColor(0.2, 0.2, 0.3, self.menuAlpha)
        love.graphics.rectangle("fill", slotX, slotY, slotWidth, slotHeight, 5, 5)
        
        -- Draw unit if slot is filled
        if selectedUnits[i] then
            local unit = availableUnits[selectedUnits[i]]
            
            -- Draw unit background based on type
            local typeColor = {0.3, 0.5, 0.8, self.menuAlpha}
            if unit.type == "knight" then
                typeColor = {0.3, 0.5, 0.8, self.menuAlpha}
            elseif unit.type == "rook" then
                typeColor = {0.7, 0.3, 0.3, self.menuAlpha}
            elseif unit.type == "bishop" then
                typeColor = {0.3, 0.7, 0.3, self.menuAlpha}
            elseif unit.type == "pawn" then
                typeColor = {0.7, 0.7, 0.3, self.menuAlpha}
            elseif unit.type == "queen" then
                typeColor = {0.7, 0.3, 0.7, self.menuAlpha}
            end
            
            love.graphics.setColor(typeColor)
            love.graphics.rectangle("fill", slotX, slotY, slotWidth, slotHeight, 5, 5)
            
            -- Draw unit name
            love.graphics.setColor(1, 1, 1, self.menuAlpha)
            love.graphics.setFont(smallFont)
            love.graphics.printf(unit.name, slotX, slotY + 10, slotWidth, "center")
            
            -- Draw unit icon (placeholder)
            love.graphics.setFont(titleFont)
            local unitChar = "?"
            if unit.type == "knight" then unitChar = "♞"
            elseif unit.type == "rook" then unitChar = "♜"
            elseif unit.type == "bishop" then unitChar = "♝"
            elseif unit.type == "pawn" then unitChar = "♟"
            elseif unit.type == "queen" then unitChar = "♛"
            end
            
            love.graphics.printf(unitChar, slotX, slotY + 25, slotWidth, "center")
            
            -- Draw remove button
            love.graphics.setColor(0.8, 0.3, 0.3, self.menuAlpha)
            love.graphics.rectangle("fill", slotX + slotWidth - 20, slotY, 20, 20, 5, 5)
            
            love.graphics.setColor(1, 1, 1, self.menuAlpha)
            love.graphics.setFont(smallFont)
            love.graphics.printf("X", slotX + slotWidth - 20, slotY + 2, 20, "center")
        else
            -- Draw empty slot text
            love.graphics.setColor(0.5, 0.5, 0.6, self.menuAlpha * 0.5)
            love.graphics.setFont(smallFont)
            love.graphics.printf("Empty", slotX, slotY + 30, slotWidth, "center")
        end
    end
end

-- Draw the action buttons
function TeamManagement:drawButtons(width, height)
    local buttonWidth = 200
    local buttonHeight = 50
    local buttonY = height - 180
    
    -- Draw start mission button
    love.graphics.setColor(0.3, 0.7, 0.3, self.menuAlpha)
    love.graphics.rectangle("fill", width/2 - buttonWidth - 20, buttonY, buttonWidth, buttonHeight, 10, 10)
    
    love.graphics.setColor(1, 1, 1, self.menuAlpha)
    love.graphics.setFont(menuFont)
    love.graphics.printf("Start Mission", width/2 - buttonWidth - 20, buttonY + 10, buttonWidth, "center")
    
    -- Draw back button
    love.graphics.setColor(0.7, 0.3, 0.3, self.menuAlpha)
    love.graphics.rectangle("fill", width/2 + 20, buttonY, buttonWidth, buttonHeight, 10, 10)
    
    love.graphics.setColor(1, 1, 1, self.menuAlpha)
    love.graphics.setFont(menuFont)
    love.graphics.printf("Back to Menu", width/2 + 20, buttonY + 10, buttonWidth, "center")
end

-- Draw hover information
function TeamManagement:drawHoverInfo(width, height)
    -- Draw hover info if hovering over a unit or item
    if hoveredUnit or hoveredItem then
        local infoX = width - 300
        local infoY = 160
        local infoWidth = 250
        local infoHeight = 300
        
        -- Draw info background
        love.graphics.setColor(0.2, 0.2, 0.3, self.menuAlpha * 0.9)
        love.graphics.rectangle("fill", infoX, infoY, infoWidth, infoHeight, 10, 10)
        
        -- Draw info content
        if hoveredUnit then
            local unit = availableUnits[hoveredUnit]
            
            love.graphics.setColor(0.9, 0.9, 1, self.menuAlpha)
            love.graphics.setFont(menuFont)
            love.graphics.printf(unit.name, infoX + 20, infoY + 20, infoWidth - 40, "center")
            
            love.graphics.setFont(smallFont)
            love.graphics.setColor(0.7, 0.7, 0.8, self.menuAlpha)
            love.graphics.printf(unit.description, infoX + 20, infoY + 60, infoWidth - 40, "left")
            
            -- Draw stats
            love.graphics.setColor(0.7, 0.8, 0.9, self.menuAlpha)
            love.graphics.printf("Health: " .. unit.stats.health, infoX + 20, infoY + 120, infoWidth - 40, "left")
            love.graphics.printf("Attack: " .. unit.stats.attack, infoX + 20, infoY + 145, infoWidth - 40, "left")
            love.graphics.printf("Defense: " .. unit.stats.defense, infoX + 20, infoY + 170, infoWidth - 40, "left")
            love.graphics.printf("Speed: " .. unit.stats.speed, infoX + 20, infoY + 195, infoWidth - 40, "left")
            
            -- Draw abilities
            love.graphics.setColor(0.6, 0.8, 0.6, self.menuAlpha)
            love.graphics.printf("Abilities:", infoX + 20, infoY + 230, infoWidth - 40, "left")
            
            for i, ability in ipairs(unit.abilities) do
                love.graphics.printf("- " .. ability, infoX + 30, infoY + 230 + i * 20, infoWidth - 60, "left")
            end
        elseif hoveredItem then
            local item = availableItems[hoveredItem]
            
            love.graphics.setColor(0.9, 0.9, 1, self.menuAlpha)
            love.graphics.setFont(menuFont)
            love.graphics.printf(item.name, infoX + 20, infoY + 20, infoWidth - 40, "center")
            
            -- Draw item type
            local typeColor = {0.7, 0.7, 0.8, self.menuAlpha}
            if item.type == "weapon" then
                typeColor = {0.8, 0.5, 0.5, self.menuAlpha}
            elseif item.type == "armor" then
                typeColor = {0.5, 0.7, 0.8, self.menuAlpha}
            elseif item.type == "accessory" then
                typeColor = {0.8, 0.7, 0.5, self.menuAlpha}
            elseif item.type == "consumable" then
                typeColor = {0.6, 0.8, 0.6, self.menuAlpha}
            end
            
            love.graphics.setColor(typeColor)
            love.graphics.setFont(smallFont)
            love.graphics.printf("Type: " .. item.type:sub(1,1):upper() .. item.type:sub(2), infoX + 20, infoY + 60, infoWidth - 40, "center")
            
            -- Draw description
            love.graphics.setColor(0.7, 0.7, 0.8, self.menuAlpha)
            love.graphics.printf(item.description, infoX + 20, infoY + 100, infoWidth - 40, "left")
            
            -- Draw stats if applicable
            if item.stats then
                love.graphics.setColor(0.7, 0.8, 0.9, self.menuAlpha)
                love.graphics.printf("Stats:", infoX + 20, infoY + 150, infoWidth - 40, "left")
                
                local y = 170
                for stat, value in pairs(item.stats) do
                    local sign = value >= 0 and "+" or ""
                    love.graphics.printf(stat:sub(1,1):upper() .. stat:sub(2) .. ": " .. sign .. value, 
                                        infoX + 30, infoY + y, infoWidth - 60, "left")
                    y = y + 25
                end
            end
            
            -- Draw effect if applicable
            if item.effect then
                love.graphics.setColor(0.6, 0.8, 0.6, self.menuAlpha)
                love.graphics.printf("Effect: " .. item.effect:sub(1,1):upper() .. item.effect:sub(2), 
                                    infoX + 20, infoY + 200, infoWidth - 40, "left")
                
                if item.duration then
                    love.graphics.printf("Duration: " .. item.duration .. " turns", 
                                        infoX + 20, infoY + 225, infoWidth - 40, "left")
                end
            end
        end
    end
end

-- Handle mouse movement
function TeamManagement:mousemoved(x, y)
    local width, height = love.graphics.getDimensions()
    
    -- Check tab hover
    local tabWidth = 150
    local tabHeight = 40
    local tabY = 100
    
    if x >= width/4 - tabWidth/2 and x <= width/4 + tabWidth/2 and
       y >= tabY and y <= tabY + tabHeight then
        -- Units tab hover
        if love.mouse.isDown(1) then
            currentTab = "units"
            scrollOffset = 0
        end
    elseif x >= width*3/4 - tabWidth/2 and x <= width*3/4 + tabWidth/2 and
           y >= tabY and y <= tabY + tabHeight then
        -- Items tab hover
        if love.mouse.isDown(1) then
            currentTab = "items"
            scrollOffset = 0
        end
    end
    
    -- Check store content hover
    local contentX = 50
    local contentY = 160
    local contentWidth = width - 100
    local contentHeight = height - 300
    
    if x >= contentX and x <= contentX + contentWidth and
       y >= contentY and y <= contentY + contentHeight then
        -- Store content hover
        if currentTab == "units" then
            -- Check unit hover
            hoveredUnit = nil
            for i, unit in ipairs(availableUnits) do
                local unitY = contentY + 60 + (i-1) * 110 - scrollOffset
                
                if y >= unitY - 5 and y <= unitY + 95 then
                    hoveredUnit = i
                    break
                end
            end
        else
            -- Check item hover
            hoveredItem = nil
            for i, item in ipairs(availableItems) do
                local itemY = contentY + 60 + (i-1) * 110 - scrollOffset
                
                if y >= itemY - 5 and y <= itemY + 95 then
                    hoveredItem = i
                    break
                end
            end
        end
    else
        hoveredUnit = nil
        hoveredItem = nil
    end
    
    -- Check team slots hover
    local slotWidth = 80
    local slotHeight = 80
    local slotY = height - 120 + 35
    local slotSpacing = 20
    local startX = width/2 - ((slotWidth + slotSpacing) * maxTeamSize)/2
    
    for i = 1, maxTeamSize do
        local slotX = startX + (i-1) * (slotWidth + slotSpacing)
        
        if x >= slotX and x <= slotX + slotWidth and
           y >= slotY and y <= slotY + slotHeight then
            -- Team slot hover
            if selectedUnits[i] and
               x >= slotX + slotWidth - 20 and x <= slotX + slotWidth and
               y >= slotY and y <= slotY + 20 then
                -- Remove button hover
                if love.mouse.isDown(1) then
                    self:removeUnitFromTeam(i)
                end
            end
        end
    end
    
    -- Check action buttons hover
    local buttonWidth = 200
    local buttonHeight = 50
    local buttonY = height - 180
    
    if x >= width/2 - buttonWidth - 20 and x <= width/2 - 20 and
       y >= buttonY and y <= buttonY + buttonHeight then
        -- Start mission button hover
        if love.mouse.isDown(1) then
            self:startMission()
        end
    elseif x >= width/2 + 20 and x <= width/2 + 20 + buttonWidth and
           y >= buttonY and y <= buttonY + buttonHeight then
        -- Back button hover
        if love.mouse.isDown(1) then
            self:backToMenu()
        end
    end
end

-- Handle mouse presses
function TeamManagement:mousepressed(x, y, button)
    local width, height = love.graphics.getDimensions()
    
    if button == 1 then -- Left click
        -- Check store content click
        local contentX = 50
        local contentY = 160
        local contentWidth = width - 100
        local contentHeight = height - 300
        
        if x >= contentX and x <= contentX + contentWidth and
           y >= contentY and y <= contentY + contentHeight then
            -- Store content click
            if currentTab == "units" then
                -- Check unit click
                for i, unit in ipairs(availableUnits) do
                    local unitY = contentY + 60 + (i-1) * 110 - scrollOffset
                    
                    if y >= unitY - 5 and y <= unitY + 95 then
                        -- Unit selection
                        selectedUnitIndex = i
                        
                        -- Check buy button click
                        if x >= contentX + contentWidth - 120 and x <= contentX + contentWidth - 40 and
                           y >= unitY + 60 and y <= unitY + 90 then
                            -- Buy unit
                            self:buyUnit(i)
                        end
                        
                        break
                    end
                end
            else
                -- Check item click
                for i, item in ipairs(availableItems) do
                    local itemY = contentY + 60 + (i-1) * 110 - scrollOffset
                    
                    if y >= itemY - 5 and y <= itemY + 95 then
                        -- Item selection
                        selectedItemIndex = i
                        
                        -- Check buy button click
                        if x >= contentX + contentWidth - 120 and x <= contentX + contentWidth - 40 and
                           y >= itemY + 60 and y <= itemY + 90 then
                            -- Buy item
                            self:buyItem(i)
                        end
                        
                        break
                    end
                end
            end
        end
    end
end

-- Handle mouse wheel
function TeamManagement:wheelmoved(x, y)
    -- Scroll store content
    scrollOffset = scrollOffset - y * 30
    
    -- Clamp scroll offset
    scrollOffset = math.max(0, math.min(scrollOffset, maxScroll))
end

-- Handle keypresses
function TeamManagement:keypressed(key)
    if key == "escape" then
        -- Back to menu
        self:backToMenu()
    elseif key == "return" or key == "space" then
        -- Start mission if team is valid
        if #selectedUnits > 0 then
            self:startMission()
        end
    elseif key == "tab" then
        -- Switch tabs
        currentTab = currentTab == "units" and "items" or "units"
        scrollOffset = 0
    elseif key == "up" or key == "w" then
        -- Scroll up
        scrollOffset = scrollOffset - 30
        scrollOffset = math.max(0, scrollOffset)
    elseif key == "down" or key == "s" then
        -- Scroll down
        scrollOffset = scrollOffset + 30
        scrollOffset = math.min(scrollOffset, maxScroll)
    end
end

-- Buy a unit
function TeamManagement:buyUnit(index)
    local unit = availableUnits[index]
    
    -- Check if can afford
    if playerCurrency >= unit.cost then
        -- Check if team is full
        if #selectedUnits >= maxTeamSize then
            -- Team is full, show message
            print("Team is full! Remove a unit first.")
            return
        end
        
        -- Add unit to team
        self:addUnitToTeam(index)
        
        -- Deduct cost
        playerCurrency = playerCurrency - unit.cost
        
        -- Play purchase sound if available
        -- if self.game.assets.sounds.purchase then
        --     love.audio.play(self.game.assets.sounds.purchase)
        -- end
    else
        -- Can't afford, show message
        print("Not enough gold!")
        
        -- Play error sound if available
        -- if self.game.assets.sounds.error then
        --     love.audio.play(self.game.assets.sounds.error)
        -- end
    end
end

-- Buy an item
function TeamManagement:buyItem(index)
    local item = availableItems[index]
    
    -- Check if can afford
    if playerCurrency >= item.cost then
        -- Add item to inventory
        table.insert(selectedItems, index)
        
        -- Deduct cost
        playerCurrency = playerCurrency - item.cost
        
        -- Play purchase sound if available
        -- if self.game.assets.sounds.purchase then
        --     love.audio.play(self.game.assets.sounds.purchase)
        -- end
    else
        -- Can't afford, show message
        print("Not enough gold!")
        
        -- Play error sound if available
        -- if self.game.assets.sounds.error then
        --     love.audio.play(self.game.assets.sounds.error)
        -- end
    end
end

-- Add unit to team
function TeamManagement:addUnitToTeam(index)
    table.insert(selectedUnits, index)
end

-- Remove unit from team
function TeamManagement:removeUnitFromTeam(slotIndex)
    -- Refund unit cost
    local unitIndex = selectedUnits[slotIndex]
    if unitIndex then
        local unit = availableUnits[unitIndex]
        playerCurrency = playerCurrency + math.floor(unit.cost * 0.8) -- 80% refund
    end
    
    -- Remove unit
    table.remove(selectedUnits, slotIndex)
    
    -- Play remove sound if available
    -- if self.game.assets.sounds.remove then
    --     love.audio.play(self.game.assets.sounds.remove)
    -- end
end

-- Start the mission
function TeamManagement:startMission()
    -- Check if team has at least one unit
    if #selectedUnits == 0 then
        -- No units, show message
        print("You need at least one unit to start a mission!")
        
        -- Play error sound if available
        -- if self.game.assets.sounds.error then
        --     love.audio.play(self.game.assets.sounds.error)
        -- end
        
        return
    end
    
    -- Create actual unit instances for the game
    local gameUnits = {}
    for i, unitIndex in ipairs(selectedUnits) do
        local unitData = availableUnits[unitIndex]
        
        -- Create unit instance
        local unit = {
            type = unitData.type,
            faction = "player",
            stats = unitData.stats,
            abilities = unitData.abilities,
            items = {}
        }
        
        table.insert(gameUnits, unit)
    end
    
    -- Create actual item instances for the game
    local gameItems = {}
    for i, itemIndex in ipairs(selectedItems) do
        local itemData = availableItems[itemIndex]
        
        -- Create item instance
        local item = {
            type = itemData.type,
            name = itemData.name,
            stats = itemData.stats,
            effect = itemData.effect,
            value = itemData.value,
            duration = itemData.duration
        }
        
        table.insert(gameItems, item)
    end
    
    -- Store units and items in game object
    self.game.playerUnits = gameUnits
    self.game.playerItems = gameItems
    
    -- Set a flag to indicate we're coming from team management
    -- This will be used in Game:enter to ensure proper initialization
    self.game.fromTeamManagement = true
    
    -- Switch to game state
    gamestate.switch(require("src.states.game"), self.game)
end

-- Go back to main menu
function TeamManagement:backToMenu()
    gamestate.switch(require("src.states.menu"), self.game)
end

return TeamManagement
