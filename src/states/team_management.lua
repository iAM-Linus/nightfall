-- Enhanced Team Management State for Nightfall Chess
-- Implements redesigned UI with improved team selection, unit purchasing, and equipment management

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
local statFont = nil
local descFont = nil

-- Store data
local playerCurrency = 1000  -- Starting currency
local availableUnits = {}
local availableItems = {}
local selectedUnits = {}
local selectedItems = {}
local maxTeamSize = 4

-- UI state
local currentTab = "units"  -- "units", "items", or "equipment"
local selectedUnitIndex = 1
local selectedItemIndex = 1
local hoveredUnit = nil
local hoveredItem = nil
local scrollOffset = 0
local maxScroll = 0
local showUnitDetail = false
local showItemDetail = false
local detailUnit = nil
local detailItem = nil
local equipmentSlotSelected = nil
local selectedStoreUnit = nil

-- Color definitions
local COLORS = {
    background = {0.1, 0.1, 0.2, 1},
    panel = {0.15, 0.15, 0.25, 1},
    border = {0.3, 0.3, 0.5, 1},
    title = {0.9, 0.8, 0.3, 1},
    text = {0.9, 0.9, 1, 1},
    textDim = {0.7, 0.7, 0.9, 0.7},
    button = {0.2, 0.5, 0.8, 1},
    buttonHover = {0.3, 0.6, 0.9, 1},
    buttonDisabled = {0.3, 0.3, 0.5, 0.5},
    gold = {0.9, 0.8, 0.3, 1},
    health = {0.8, 0.2, 0.2, 1},
    mana = {0.2, 0.4, 0.8, 1},
    attack = {0.9, 0.9, 0.3, 1},
    defense = {0.3, 0.7, 0.9, 1},
    speed = {0.3, 0.9, 0.3, 1},
    weapon = {0.8, 0.2, 0.2, 1},
    armor = {0.2, 0.4, 0.8, 1},
    accessory = {0.8, 0.8, 0.2, 1},
    rarity = {
        common = {0.8, 0.8, 0.8, 1},
        uncommon = {0.2, 0.8, 0.2, 1},
        rare = {0.2, 0.2, 0.9, 1},
        epic = {0.8, 0.2, 0.8, 1},
        legendary = {0.9, 0.6, 0.1, 1}
    }
}

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
    statFont = game.assets.fonts.medium
    descFont = game.assets.fonts.small
    
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
            maxHealth = 120,
            mana = 50,
            maxMana = 50,
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
            maxHealth = 150,
            mana = 40,
            maxMana = 40,
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
            maxHealth = 100,
            mana = 80,
            maxMana = 80,
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
            maxHealth = 80,
            mana = 30,
            maxMana = 30,
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
            maxHealth = 130,
            mana = 70,
            maxMana = 70,
            attack = 12,
            defense = 7,
            speed = 8
        },
        abilities = {"Royal Command", "Multiattack"}
    })
    
    -- Add available items
    -- Weapons
    table.insert(availableItems, {
        type = "weapon",
        name = "Iron Sword",
        description = "A basic sword that increases attack power.",
        cost = 200,
        rarity = "common",
        stats = {
            attack = 3
        },
        equippableBy = {"pawn", "knight", "queen"}
    })
    
    table.insert(availableItems, {
        type = "weapon",
        name = "Steel Axe",
        description = "A heavy axe with high damage but reduces speed.",
        cost = 350,
        rarity = "uncommon",
        stats = {
            attack = 5,
            speed = -1
        },
        equippableBy = {"knight", "rook", "queen"}
    })
    
    table.insert(availableItems, {
        type = "weapon",
        name = "Magic Staff",
        description = "Enhances magical abilities and MP regeneration.",
        cost = 500,
        rarity = "rare",
        stats = {
            attack = 4,
            mana = 20
        },
        equippableBy = {"bishop", "queen"}
    })
    
    -- Armor
    table.insert(availableItems, {
        type = "armor",
        name = "Leather Armor",
        description = "Light armor that provides basic protection.",
        cost = 150,
        rarity = "common",
        stats = {
            defense = 2
        },
        equippableBy = {"pawn", "knight", "bishop", "rook", "queen"}
    })
    
    table.insert(availableItems, {
        type = "armor",
        name = "Chainmail",
        description = "Medium armor with good protection.",
        cost = 300,
        rarity = "uncommon",
        stats = {
            defense = 4,
            speed = -1
        },
        equippableBy = {"knight", "rook", "queen"}
    })
    
    table.insert(availableItems, {
        type = "armor",
        name = "Magic Robe",
        description = "Enhances magical defense and MP.",
        cost = 450,
        rarity = "rare",
        stats = {
            defense = 3,
            mana = 15
        },
        equippableBy = {"bishop", "queen"}
    })
    
    -- Accessories
    table.insert(availableItems, {
        type = "accessory",
        name = "Speed Amulet",
        description = "Increases movement speed.",
        cost = 250,
        rarity = "uncommon",
        stats = {
            speed = 2
        },
        equippableBy = {"pawn", "knight", "bishop", "rook", "queen"}
    })
    
    table.insert(availableItems, {
        type = "accessory",
        name = "Power Ring",
        description = "Increases attack power and critical hit chance.",
        cost = 400,
        rarity = "rare",
        stats = {
            attack = 3
        },
        equippableBy = {"knight", "rook", "queen"}
    })
    
    table.insert(availableItems, {
        type = "accessory",
        name = "Mana Crystal",
        description = "Increases MP and reduces ability cooldowns.",
        cost = 600,
        rarity = "epic",
        stats = {
            mana = 30
        },
        equippableBy = {"bishop", "queen"}
    })
    
    -- Consumables
    table.insert(availableItems, {
        type = "consumable",
        name = "Health Potion",
        description = "Restores 50 health when used.",
        cost = 100,
        rarity = "common",
        effect = "heal",
        value = 50
    })
    
    table.insert(availableItems, {
        type = "consumable",
        name = "Strength Elixir",
        description = "Temporarily increases attack by 5.",
        cost = 120,
        rarity = "uncommon",
        effect = "buff",
        stat = "attack",
        value = 5,
        duration = 3
    })
    
    -- Add a default pawn to the team
    self:addUnitToTeam(4)
end

-- Update team management logic
function TeamManagement:update(dt)
    -- Update animations
    timer.update(dt)
    
    -- Update max scroll based on content
    if currentTab == "units" then
        maxScroll = math.max(0, #availableUnits * 110 - 400)
    elseif currentTab == "items" then
        maxScroll = math.max(0, #availableItems * 110 - 400)
    else -- equipment tab
        maxScroll = math.max(0, #availableItems * 80 - 400)
    end
    
    -- Clamp scroll offset
    scrollOffset = math.max(0, math.min(scrollOffset, maxScroll))
end

-- Draw the team management screen
function TeamManagement:draw()
    local width, height = love.graphics.getDimensions()
    
    -- Draw background
    love.graphics.setColor(COLORS.background)
    love.graphics.rectangle("fill", 0, 0, width, height)
    
    -- Draw title
    love.graphics.setFont(titleFont)
    love.graphics.setColor(COLORS.title)
    love.graphics.printf("TEAM MANAGEMENT", 0, 30, width, "center")
    
    -- Draw gold amount
    love.graphics.setFont(menuFont)
    love.graphics.setColor(COLORS.gold)
    love.graphics.print("GOLD: " .. playerCurrency, width - 200, 30)
    
    -- Draw tabs
    self:drawTabs(width, height)
    
    -- Draw content based on current tab
    self:drawStoreContent(width, height)
    
    -- Draw selected team
    self:drawSelectedTeam(width, height)
    
    -- Draw navigation buttons
    self:drawButtons(width, height)
    
    -- Draw hover information
    self:drawHoverInfo(width, height)
    
    -- Draw unit detail popup if active
    if showUnitDetail and detailUnit then
        self:drawUnitDetailPopup(width, height, detailUnit)
    end
    
    -- Draw item detail popup if active
    if showItemDetail and detailItem then
        self:drawItemDetailPopup(width, height, detailItem)
    end
end

-- Draw tabs for navigation
function TeamManagement:drawTabs(width, height)
    local tabWidth = 120
    local tabHeight = 40
    local tabY = 80
    local tabSpacing = 10
    local totalWidth = (tabWidth + tabSpacing) * 3 - tabSpacing
    local startX = (width - totalWidth) / 2
    
    -- Units tab
    local unitsTabX = startX
    love.graphics.setColor(currentTab == "units" and COLORS.button or COLORS.panel)
    love.graphics.rectangle("fill", unitsTabX, tabY, tabWidth, tabHeight)
    love.graphics.setColor(COLORS.border)
    love.graphics.rectangle("line", unitsTabX, tabY, tabWidth, tabHeight)
    
    love.graphics.setFont(menuFont)
    love.graphics.setColor(COLORS.text)
    love.graphics.printf("UNITS", unitsTabX, tabY + 10, tabWidth, "center")
    
    -- Items tab
    local itemsTabX = unitsTabX + tabWidth + tabSpacing
    love.graphics.setColor(currentTab == "items" and COLORS.button or COLORS.panel)
    love.graphics.rectangle("fill", itemsTabX, tabY, tabWidth, tabHeight)
    love.graphics.setColor(COLORS.border)
    love.graphics.rectangle("line", itemsTabX, tabY, tabWidth, tabHeight)
    
    love.graphics.setFont(menuFont)
    love.graphics.setColor(COLORS.text)
    love.graphics.printf("ITEMS", itemsTabX, tabY + 10, tabWidth, "center")
    
    -- Equipment tab
    local equipTabX = itemsTabX + tabWidth + tabSpacing
    love.graphics.setColor(currentTab == "equipment" and COLORS.button or COLORS.panel)
    love.graphics.rectangle("fill", equipTabX, tabY, tabWidth, tabHeight)
    love.graphics.setColor(COLORS.border)
    love.graphics.rectangle("line", equipTabX, tabY, tabWidth, tabHeight)
    
    love.graphics.setFont(menuFont)
    love.graphics.setColor(COLORS.text)
    love.graphics.printf("EQUIP", equipTabX, tabY + 10, tabWidth, "center")
end

-- Draw store content based on current tab
function TeamManagement:drawStoreContent(width, height)
    local contentX = 300
    local contentY = 140
    local contentWidth = width - 600
    local contentHeight = height - 250
    
    -- Draw content panel
    love.graphics.setColor(COLORS.panel)
    love.graphics.rectangle("fill", contentX, contentY, contentWidth, contentHeight)
    love.graphics.setColor(COLORS.border)
    love.graphics.rectangle("line", contentX, contentY, contentWidth, contentHeight)
    
    -- Draw content based on current tab
    if currentTab == "units" then
        self:drawUnitsStore(contentX, contentY, contentWidth, contentHeight)
    elseif currentTab == "items" then
        self:drawItemsStore(contentX, contentY, contentWidth, contentHeight)
    else -- equipment tab
        self:drawEquipmentTab(contentX, contentY, contentWidth, contentHeight)
    end
end

-- Updated drawUnitsStore function to handle both hover and selection
function TeamManagement:drawUnitsStore(x, y, width, height)
    -- Draw title
    love.graphics.setFont(menuFont)
    love.graphics.setColor(COLORS.title)
    love.graphics.printf("AVAILABLE UNITS", x, y + 10, width, "center")
    
    -- Draw units in a grid
    local unitSize = 80
    local cols = 4
    local spacing = 20
    local startY = y + 50 - scrollOffset
    
    for i, unit in ipairs(availableUnits) do
        local col = (i-1) % cols
        local row = math.floor((i-1) / cols)
        
        local unitX = x + (width - (cols * unitSize + (cols-1) * spacing)) / 2 + col * (unitSize + spacing)
        local unitY = startY + row * (unitSize + spacing)
        
        -- Only draw if in visible area
        if unitY + unitSize >= y and unitY <= y + height then
            -- Unit background
            love.graphics.setColor(COLORS.panel)
            love.graphics.rectangle("fill", unitX, unitY, unitSize, unitSize)
            
            -- Unit border (highlight if hovered or selected)
            if hoveredUnit == i then
                love.graphics.setColor(COLORS.gold)
                love.graphics.rectangle("line", unitX, unitY, unitSize, unitSize, 2)
            elseif selectedStoreUnit == i then
                -- Use a different color for selected unit to distinguish from hover
                love.graphics.setColor(COLORS.title)
                love.graphics.rectangle("line", unitX, unitY, unitSize, unitSize, 2)
            else
                love.graphics.setColor(COLORS.border)
                love.graphics.rectangle("line", unitX, unitY, unitSize, unitSize)
            end
            
            -- Unit icon (placeholder)
            love.graphics.setColor(0.7, 0.7, 0.8)
            love.graphics.rectangle("fill", unitX + 5, unitY + 5, unitSize - 10, unitSize - 10)
            
            -- Unit type indicator
            love.graphics.setFont(smallFont)
            love.graphics.setColor(COLORS.text)
            love.graphics.print(unit.type:sub(1,1):upper(), unitX + 5, unitY + 5)
            
            -- Unit cost
            love.graphics.setColor(COLORS.gold)
            love.graphics.print(unit.cost .. "g", unitX + 5, unitY + unitSize - 20)
            
            -- Check if can afford
            if unit.cost > playerCurrency then
                -- Draw "can't afford" overlay
                love.graphics.setColor(0, 0, 0, 0.5)
                love.graphics.rectangle("fill", unitX, unitY, unitSize, unitSize)
            end
        end
    end
end

-- Updated drawUnitHoverInfo function to show info for selectedStoreUnit instead of hoveredUnit
function TeamManagement:drawUnitHoverInfo(width, height, unit)
    local infoWidth = 274
    local infoHeight = height - 160
    local infoX = width - infoWidth - 30
    local infoY = 140
    
    -- Draw panel background
    love.graphics.setColor(COLORS.panel)
    love.graphics.rectangle("fill", infoX, infoY, infoWidth, infoHeight)
    love.graphics.setColor(COLORS.border)
    love.graphics.rectangle("line", infoX, infoY, infoWidth, infoHeight)
    
    -- Draw panel title
    love.graphics.setFont(menuFont)
    love.graphics.setColor(COLORS.title)
    love.graphics.printf("UNIT DETAILS", infoX, infoY + 10, infoWidth, "center")
    
    -- Draw unit name and type
    love.graphics.setFont(menuFont)
    love.graphics.setColor(COLORS.text)
    love.graphics.print(unit.name, infoX + 20, infoY + 50)
    
    love.graphics.setFont(smallFont)
    love.graphics.setColor(COLORS.textDim)
    love.graphics.print("Type: " .. unit.type:upper(), infoX + 20, infoY + 80)
    love.graphics.print("Level: 1", infoX + 20, infoY + 100)
    
    -- Draw HP bar
    local barWidth = infoWidth - 40
    love.graphics.setColor(COLORS.panel)
    love.graphics.rectangle("fill", infoX + 20, infoY + 130, barWidth, 20)
    love.graphics.setColor(COLORS.health)
    love.graphics.rectangle("fill", infoX + 20, infoY + 130, barWidth, 20)
    
    love.graphics.setFont(smallFont)
    love.graphics.setColor(COLORS.text)
    love.graphics.print("HP: " .. unit.stats.health .. "/" .. unit.stats.maxHealth, infoX + 25, infoY + 132)
    
    -- Draw MP bar
    love.graphics.setColor(COLORS.panel)
    love.graphics.rectangle("fill", infoX + 20, infoY + 160, barWidth, 20)
    love.graphics.setColor(COLORS.mana)
    love.graphics.rectangle("fill", infoX + 20, infoY + 160, barWidth, 20)
    
    love.graphics.setFont(smallFont)
    love.graphics.setColor(COLORS.text)
    love.graphics.print("MP: " .. unit.stats.mana .. "/" .. unit.stats.maxMana, infoX + 25, infoY + 162)
    
    -- Draw stats
    love.graphics.setFont(smallFont)
    
    love.graphics.setColor(COLORS.attack)
    love.graphics.print("ATK: " .. unit.stats.attack, infoX + 20, infoY + 190)
    
    love.graphics.setColor(COLORS.defense)
    love.graphics.print("DEF: " .. unit.stats.defense, infoX + 20, infoY + 210)
    
    love.graphics.setColor(COLORS.speed)
    love.graphics.print("SPD: " .. unit.stats.speed, infoX + 20, infoY + 230)
    
    -- Draw abilities
    love.graphics.setFont(smallFont)
    love.graphics.setColor(COLORS.title)
    love.graphics.print("ABILITIES:", infoX + 20, infoY + 260)
    
    love.graphics.setColor(COLORS.textDim)
    for i, ability in ipairs(unit.abilities) do
        love.graphics.print("- " .. ability, infoX + 30, infoY + 260 + i * 20)
    end
    
    -- Draw description
    love.graphics.setFont(smallFont)
    love.graphics.setColor(COLORS.textDim)
    love.graphics.printf(unit.description, infoX + 20, infoY + 320, infoWidth - 40, "left")
    
    -- Draw buy button
    local buyButtonWidth = 120
    local buyButtonHeight = 40
    local buyButtonX = infoX + (infoWidth - buyButtonWidth) / 2
    local buyButtonY = infoY + infoHeight - 60
    
    if playerCurrency >= unit.cost then
        love.graphics.setColor(COLORS.button)
    else
        love.graphics.setColor(COLORS.buttonDisabled)
    end
    love.graphics.rectangle("fill", buyButtonX, buyButtonY, buyButtonWidth, buyButtonHeight)
    love.graphics.setColor(COLORS.border)
    love.graphics.rectangle("line", buyButtonX, buyButtonY, buyButtonWidth, buyButtonHeight)
    
    love.graphics.setFont(menuFont)
    love.graphics.setColor(COLORS.text)
    love.graphics.printf("BUY: " .. unit.cost .. "g", buyButtonX, buyButtonY + 10, buyButtonWidth, "center")
end

-- Draw items store
function TeamManagement:drawItemsStore(x, y, width, height)
    -- Draw title
    love.graphics.setFont(menuFont)
    love.graphics.setColor(COLORS.title)
    love.graphics.printf("AVAILABLE ITEMS", x, y + 10, width, "center")
    
    -- Draw items in a grid
    local itemSize = 80
    local cols = 4
    local spacing = 20
    local startY = y + 50 - scrollOffset
    
    for i, item in ipairs(availableItems) do
        local col = (i-1) % cols
        local row = math.floor((i-1) / cols)
        
        local itemX = x + (width - (cols * itemSize + (cols-1) * spacing)) / 2 + col * (itemSize + spacing)
        local itemY = startY + row * (itemSize + spacing)
        
        -- Only draw if in visible area
        if itemY + itemSize >= y and itemY <= y + height then
            -- Item background
            love.graphics.setColor(COLORS.panel)
            love.graphics.rectangle("fill", itemX, itemY, itemSize, itemSize)
            
            -- Item border based on rarity
            if hoveredItem == i then
                love.graphics.setColor(COLORS.gold)
            else
                love.graphics.setColor(COLORS.rarity[item.rarity] or COLORS.border)
            end
            love.graphics.rectangle("line", itemX, itemY, itemSize, itemSize)
            
            -- Item icon based on type
            local itemColor
            if item.type == "weapon" then
                itemColor = COLORS.weapon
            elseif item.type == "armor" then
                itemColor = COLORS.armor
            elseif item.type == "accessory" then
                itemColor = COLORS.accessory
            else
                itemColor = {0.7, 0.7, 0.8}
            end
            
            love.graphics.setColor(itemColor)
            love.graphics.rectangle("fill", itemX + 5, itemY + 5, itemSize - 10, itemSize - 10)
            
            -- Item type indicator
            love.graphics.setFont(smallFont)
            love.graphics.setColor(COLORS.text)
            love.graphics.print(item.type:sub(1,1):upper(), itemX + 5, itemY + 5)
            
            -- Item cost
            love.graphics.setColor(COLORS.gold)
            love.graphics.print(item.cost .. "g", itemX + 5, itemY + itemSize - 20)
            
            -- Check if can afford
            if item.cost > playerCurrency then
                -- Draw "can't afford" overlay
                love.graphics.setColor(0, 0, 0, 0.5)
                love.graphics.rectangle("fill", itemX, itemY, itemSize, itemSize)
            end
        end
    end
end

-- Draw equipment tab
function TeamManagement:drawEquipmentTab(x, y, width, height)
    -- Check if a unit is selected
    if #selectedUnits == 0 or not selectedUnitIndex or selectedUnitIndex > #selectedUnits then
        -- No unit selected
        love.graphics.setFont(menuFont)
        love.graphics.setColor(COLORS.textDim)
        love.graphics.printf("Select a unit to manage equipment", x, y + height/2 - 15, width, "center")
        return
    end
    
    local unit = availableUnits[selectedUnits[selectedUnitIndex]]
    
    -- Draw unit info section
    love.graphics.setFont(menuFont)
    love.graphics.setColor(COLORS.title)
    love.graphics.printf(unit.name, x, y + 10, width, "center")
    
    love.graphics.setFont(smallFont)
    love.graphics.setColor(COLORS.text)
    love.graphics.printf("Level: 1", x, y + 40, width, "center")
    
    -- Draw equipment slots section
    love.graphics.setFont(menuFont)
    love.graphics.setColor(COLORS.title)
    love.graphics.print("EQUIPMENT SLOTS", x + 20, y + 70)
    
    -- Draw equipment slots
    local slotSize = 80
    local slotSpacing = 20
    local slotsY = y + 100
    
    -- Equipment types
    local equipTypes = {"Weapon", "Armor", "Accessory"}
    local equipColors = {COLORS.weapon, COLORS.armor, COLORS.accessory}
    
    for i, typeName, color in ipairs(zip(equipTypes, equipColors)) do
        local slotX = x + 20 + (i-1) * (slotSize + slotSpacing)
        
        -- Slot background
        love.graphics.setColor(COLORS.panel)
        love.graphics.rectangle("fill", slotX, slotsY, slotSize, slotSize)
        
        -- Slot border
        if equipmentSlotSelected == i then
            love.graphics.setColor(COLORS.gold)
        else
            love.graphics.setColor(color)
        end
        love.graphics.rectangle("line", slotX, slotsY, slotSize, slotSize)
        
        -- Slot label
        love.graphics.setFont(smallFont)
        love.graphics.setColor(COLORS.text)
        love.graphics.printf(typeName, slotX, slotsY + slotSize + 5, slotSize, "center")
        
        -- Check if item is equipped in this slot
        local slotType = typeName:lower()
        if unit.equipment and unit.equipment[slotType] then
            -- Draw equipped item
            love.graphics.setColor(color)
            love.graphics.rectangle("fill", slotX + 10, slotsY + 10, slotSize - 20, slotSize - 20)
            
            -- Item name
            love.graphics.setColor(COLORS.text)
            local itemName = unit.equipment[slotType].name
            if #itemName > 8 then
                itemName = itemName:sub(1, 6) .. ".."
            end
            love.graphics.printf(itemName, slotX, slotsY + slotSize - 25, slotSize, "center")
        else
            -- Empty slot
            love.graphics.setColor(COLORS.border)
            love.graphics.line(slotX + 10, slotsY + 10, slotX + slotSize - 10, slotsY + slotSize - 10)
            love.graphics.line(slotX + slotSize - 10, slotsY + 10, slotX + 10, slotsY + slotSize - 10)
        end
    end
    
    -- Draw inventory section
    love.graphics.setFont(menuFont)
    love.graphics.setColor(COLORS.title)
    love.graphics.print("INVENTORY", x + 20, y + 220)
    
    -- Draw inventory panel
    local inventoryRect = {x = x + 20, y = y + 250, width = width - 40, height = height - 270}
    love.graphics.setColor(COLORS.panel)
    love.graphics.rectangle("fill", inventoryRect.x, inventoryRect.y, inventoryRect.width, inventoryRect.height)
    love.graphics.setColor(COLORS.border)
    love.graphics.rectangle("line", inventoryRect.x, inventoryRect.y, inventoryRect.width, inventoryRect.height)
    
    -- Draw inventory items
    local itemSize = 60
    local cols = 6
    local spacing = 10
    local startY = inventoryRect.y + 10 - scrollOffset
    
    -- Filter items by equipment type if a slot is selected
    local filteredItems = {}
    if equipmentSlotSelected then
        local slotType = equipTypes[equipmentSlotSelected]:lower()
        for i, item in ipairs(availableItems) do
            if item.type == slotType then
                table.insert(filteredItems, {index = i, item = item})
            end
        end
    else
        for i, item in ipairs(availableItems) do
            if item.type == "weapon" or item.type == "armor" or item.type == "accessory" then
                table.insert(filteredItems, {index = i, item = item})
            end
        end
    end
    
    if #filteredItems == 0 then
        -- No items to display
        love.graphics.setFont(smallFont)
        love.graphics.setColor(COLORS.textDim)
        love.graphics.printf("No items available", inventoryRect.x, inventoryRect.y + inventoryRect.height/2 - 10, inventoryRect.width, "center")
    else
        for i, itemData in ipairs(filteredItems) do
            local col = (i-1) % cols
            local row = math.floor((i-1) / cols)
            
            local itemX = inventoryRect.x + 10 + col * (itemSize + spacing)
            local itemY = startY + row * (itemSize + spacing)
            
            -- Only draw if in visible area
            if itemY + itemSize >= inventoryRect.y and itemY <= inventoryRect.y + inventoryRect.height then
                local item = itemData.item
                
                -- Item background
                love.graphics.setColor(COLORS.panel)
                love.graphics.rectangle("fill", itemX, itemY, itemSize, itemSize)
                
                -- Item border based on rarity
                if hoveredItem == itemData.index then
                    love.graphics.setColor(COLORS.gold)
                else
                    love.graphics.setColor(COLORS.rarity[item.rarity] or COLORS.border)
                end
                love.graphics.rectangle("line", itemX, itemY, itemSize, itemSize)
                
                -- Item icon based on type
                local itemColor
                if item.type == "weapon" then
                    itemColor = COLORS.weapon
                elseif item.type == "armor" then
                    itemColor = COLORS.armor
                elseif item.type == "accessory" then
                    itemColor = COLORS.accessory
                else
                    itemColor = {0.7, 0.7, 0.8}
                end
                
                love.graphics.setColor(itemColor)
                love.graphics.rectangle("fill", itemX + 5, itemY + 5, itemSize - 10, itemSize - 10)
                
                -- Item type indicator
                love.graphics.setFont(smallFont)
                love.graphics.setColor(COLORS.text)
                love.graphics.print(item.type:sub(1,1):upper(), itemX + 5, itemY + 5)
                
                -- Check if unit can equip this item
                local canEquip = true
                if item.equippableBy and #item.equippableBy > 0 then
                    canEquip = false
                    for _, unitType in ipairs(item.equippableBy) do
                        if unit.type == unitType then
                            canEquip = true
                            break
                        end
                    end
                end
                
                if not canEquip then
                    -- Draw "can't equip" overlay
                    love.graphics.setColor(0, 0, 0, 0.5)
                    love.graphics.rectangle("fill", itemX, itemY, itemSize, itemSize)
                end
            end
        end
    end
end

-- Enhanced drawSelectedTeam function with visual feedback
function TeamManagement:drawSelectedTeam(width, height)
    local panelWidth = 250
    local panelHeight = height - 160
    local panelX = 30
    local panelY = 140
    
    -- Draw panel background
    love.graphics.setColor(COLORS.panel)
    love.graphics.rectangle("fill", panelX, panelY, panelWidth, panelHeight)
    love.graphics.setColor(COLORS.border)
    love.graphics.rectangle("line", panelX, panelY, panelWidth, panelHeight)
    
    -- Draw panel title
    love.graphics.setFont(menuFont)
    love.graphics.setColor(COLORS.title)
    love.graphics.printf("YOUR TEAM", panelX, panelY + 10, panelWidth, "center")
    
    -- Draw unit slots
    local slotSize = 100
    local spacing = 20
    local startY = panelY + 50
    
    for i = 1, maxTeamSize do
        local slotX = panelX + (panelWidth - slotSize) / 2
        local slotY = startY + (i-1) * (slotSize + spacing)
        
        -- Slot background
        love.graphics.setColor(COLORS.panel)
        love.graphics.rectangle("fill", slotX, slotY, slotSize, slotSize)
        
        if i <= #selectedUnits then
            -- Unit is selected
            local unit = availableUnits[selectedUnits[i]]
            
            -- Unit portrait (placeholder)
            if unit.type == "knight" then
                love.graphics.setColor(COLORS.weapon)
            elseif unit.type == "bishop" then
                love.graphics.setColor(COLORS.mana)
            elseif unit.type == "rook" then
                love.graphics.setColor(COLORS.armor)
            elseif unit.type == "pawn" then
                love.graphics.setColor(0.7, 0.7, 0.8)
            elseif unit.type == "queen" then
                love.graphics.setColor(COLORS.gold)
            end
            
            love.graphics.rectangle("fill", slotX + 5, slotY + 5, slotSize - 10, slotSize - 10)
            
            -- Unit name and level
            love.graphics.setFont(smallFont)
            love.graphics.setColor(COLORS.text)
            love.graphics.print(unit.name, slotX + 5, slotY + slotSize - 25)
            love.graphics.print("Lv. 1", slotX + 5, slotY + 5)
            
            -- Highlight selected unit
            if selectedUnitIndex == i then
                love.graphics.setColor(COLORS.gold)
                love.graphics.rectangle("line", slotX - 2, slotY - 2, slotSize + 4, slotSize + 4, 2)
            end
            
            -- Show purchase flash effect if this unit was just bought
            if self.unitPurchaseFlash and self.flashedUnitIndex == i then
                -- Calculate flash intensity based on sin wave for pulsing effect
                local flashIntensity = (math.sin(love.timer.getTime() * 10) + 1) / 2
                love.graphics.setColor(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3], flashIntensity * 0.7)
                love.graphics.rectangle("fill", slotX - 5, slotY - 5, slotSize + 10, slotSize + 10)
            end
        else
            -- Empty slot
            love.graphics.setColor(COLORS.border)
            love.graphics.rectangle("line", slotX, slotY, slotSize, slotSize)
            love.graphics.line(slotX, slotY, slotX + slotSize, slotY + slotSize)
            love.graphics.line(slotX + slotSize, slotY, slotX, slotY + slotSize)
            
            -- "+" icon
            love.graphics.setFont(titleFont)
            love.graphics.setColor(COLORS.border)
            love.graphics.printf("+", slotX, slotY + slotSize/2 - 15, slotSize, "center")
        end
    end
    
    -- Display purchase failure message if there is one
    if self.purchaseFailReason then
        love.graphics.setFont(menuFont)
        love.graphics.setColor(COLORS.health)
        love.graphics.printf(self.purchaseFailReason, panelX, panelY + panelHeight - 40, panelWidth, "center")
    end
end

-- Draw navigation buttons
function TeamManagement:drawButtons(width, height)
    local buttonWidth = 140
    local buttonHeight = 40
    local buttonY = height - 60
    
    -- Back button
    local backX = width/2 - buttonWidth - 10
    love.graphics.setColor(COLORS.panel)
    love.graphics.rectangle("fill", backX, buttonY, buttonWidth, buttonHeight)
    love.graphics.setColor(COLORS.border)
    love.graphics.rectangle("line", backX, buttonY, buttonWidth, buttonHeight)
    
    love.graphics.setFont(menuFont)
    love.graphics.setColor(COLORS.text)
    love.graphics.printf("BACK", backX, buttonY + 10, buttonWidth, "center")
    
    -- Start Game button
    local startX = width/2 + 10
    love.graphics.setColor(COLORS.button)
    love.graphics.rectangle("fill", startX, buttonY, buttonWidth, buttonHeight)
    love.graphics.setColor(COLORS.border)
    love.graphics.rectangle("line", startX, buttonY, buttonWidth, buttonHeight)
    
    love.graphics.setFont(menuFont)
    love.graphics.setColor(COLORS.text)
    love.graphics.printf("START GAME", startX, buttonY + 10, buttonWidth, "center")
end


-- Updated drawHoverInfo function to use selectedStoreUnit
function TeamManagement:drawHoverInfo(width, height)
    if currentTab == "units" then
        -- Use selectedStoreUnit for persistent display, fall back to hoveredUnit if nothing is selected
        if selectedStoreUnit then
            self:drawUnitHoverInfo(width, height, availableUnits[selectedStoreUnit])
        elseif hoveredUnit then
            self:drawUnitHoverInfo(width, height, availableUnits[hoveredUnit])
        end
    elseif (currentTab == "items" or currentTab == "equipment") and hoveredItem then
        self:drawItemHoverInfo(width, height, availableItems[hoveredItem])
    end
end

-- Draw item hover info
function TeamManagement:drawItemHoverInfo(width, height, item)
    local infoWidth = 274
    local infoHeight = height - 160
    local infoX = width - infoWidth - 30
    local infoY = 140
    
    -- Draw panel background
    love.graphics.setColor(COLORS.panel)
    love.graphics.rectangle("fill", infoX, infoY, infoWidth, infoHeight)
    love.graphics.setColor(COLORS.border)
    love.graphics.rectangle("line", infoX, infoY, infoWidth, infoHeight)
    
    -- Draw panel title
    love.graphics.setFont(menuFont)
    love.graphics.setColor(COLORS.title)
    love.graphics.printf("ITEM DETAILS", infoX, infoY + 10, infoWidth, "center")
    
    -- Draw item name and type
    love.graphics.setFont(menuFont)
    love.graphics.setColor(COLORS.text)
    love.graphics.print(item.name, infoX + 20, infoY + 50)
    
    love.graphics.setFont(smallFont)
    love.graphics.setColor(COLORS.textDim)
    love.graphics.print(item.type:upper() .. " (" .. item.rarity:sub(1,1):upper() .. item.rarity:sub(2) .. ")", infoX + 20, infoY + 80)
    
    -- Draw item icon
    local iconSize = 60
    local iconX = infoX + 20
    local iconY = infoY + 100
    
    -- Item icon based on type
    local itemColor
    if item.type == "weapon" then
        itemColor = COLORS.weapon
    elseif item.type == "armor" then
        itemColor = COLORS.armor
    elseif item.type == "accessory" then
        itemColor = COLORS.accessory
    else
        itemColor = {0.7, 0.7, 0.8}
    end
    
    love.graphics.setColor(itemColor)
    love.graphics.rectangle("fill", iconX, iconY, iconSize, iconSize)
    love.graphics.setColor(COLORS.rarity[item.rarity] or COLORS.border)
    love.graphics.rectangle("line", iconX, iconY, iconSize, iconSize)
    
    -- Draw description
    love.graphics.setFont(smallFont)
    love.graphics.setColor(COLORS.textDim)
    love.graphics.printf(item.description, infoX + 90, infoY + 100, infoWidth - 110, "left")
    
    -- Draw stats
    love.graphics.setFont(smallFont)
    love.graphics.setColor(COLORS.title)
    love.graphics.print("STATS:", infoX + 20, infoY + 180)
    
    if item.stats then
        local statY = infoY + 200
        for stat, value in pairs(item.stats) do
            local statColor
            if stat == "attack" then
                statColor = COLORS.attack
            elseif stat == "defense" then
                statColor = COLORS.defense
            elseif stat == "speed" then
                statColor = COLORS.speed
            elseif stat == "mana" or stat == "maxMana" then
                statColor = COLORS.mana
            else
                statColor = COLORS.text
            end
            
            love.graphics.setColor(statColor)
            local prefix = value >= 0 and "+" or ""
            love.graphics.print(stat:upper() .. ": " .. prefix .. value, infoX + 30, statY)
            statY = statY + 20
        end
    else
        love.graphics.setColor(COLORS.textDim)
        love.graphics.print("None", infoX + 30, infoY + 200)
    end
    
    -- Draw equippable by
    if item.type == "weapon" or item.type == "armor" or item.type == "accessory" then
        love.graphics.setFont(smallFont)
        love.graphics.setColor(COLORS.title)
        love.graphics.print("USABLE BY:", infoX + 20, infoY + 260)
        
        love.graphics.setColor(COLORS.textDim)
        if item.equippableBy and #item.equippableBy > 0 then
            local unitTypes = table.concat(item.equippableBy, ", "):upper()
            love.graphics.print(unitTypes, infoX + 30, infoY + 280)
        else
            love.graphics.print("All units", infoX + 30, infoY + 280)
        end
    end
    
    -- Draw buy/equip button
    local buttonWidth = 120
    local buttonHeight = 40
    local buttonX = infoX + (infoWidth - buttonWidth) / 2
    local buttonY = infoY + infoHeight - 60
    
    if currentTab == "items" then
        -- Buy button
        if playerCurrency >= item.cost then
            love.graphics.setColor(COLORS.button)
        else
            love.graphics.setColor(COLORS.buttonDisabled)
        end
        love.graphics.rectangle("fill", buttonX, buttonY, buttonWidth, buttonHeight)
        love.graphics.setColor(COLORS.border)
        love.graphics.rectangle("line", buttonX, buttonY, buttonWidth, buttonHeight)
        
        love.graphics.setFont(menuFont)
        love.graphics.setColor(COLORS.text)
        love.graphics.printf("BUY: " .. item.cost .. "g", buttonX, buttonY + 10, buttonWidth, "center")
    else
        -- Equip button
        love.graphics.setColor(COLORS.button)
        love.graphics.rectangle("fill", buttonX, buttonY, buttonWidth, buttonHeight)
        love.graphics.setColor(COLORS.border)
        love.graphics.rectangle("line", buttonX, buttonY, buttonWidth, buttonHeight)
        
        love.graphics.setFont(menuFont)
        love.graphics.setColor(COLORS.text)
        love.graphics.printf("EQUIP", buttonX, buttonY + 10, buttonWidth, "center")
    end
end

-- Draw unit detail popup
function TeamManagement:drawUnitDetailPopup(width, height, unit)
    -- Semi-transparent overlay
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, width, height)
    
    -- Popup panel
    local popupWidth = 500
    local popupHeight = 400
    local popupX = width/2 - popupWidth/2
    local popupY = height/2 - popupHeight/2
    
    love.graphics.setColor(COLORS.panel)
    love.graphics.rectangle("fill", popupX, popupY, popupWidth, popupHeight, 5, 5)
    love.graphics.setColor(COLORS.border)
    love.graphics.rectangle("line", popupX, popupY, popupWidth, popupHeight, 5, 5)
    
    -- Unit name and type
    love.graphics.setFont(titleFont)
    love.graphics.setColor(COLORS.title)
    love.graphics.printf(unit.name, popupX, popupY + 20, popupWidth, "center")
    
    love.graphics.setFont(menuFont)
    love.graphics.setColor(COLORS.textDim)
    love.graphics.printf(unit.type:upper(), popupX, popupY + 50, popupWidth, "center")
    
    -- Unit portrait
    local portraitSize = 120
    local portraitX = popupX + 30
    local portraitY = popupY + 80
    
    -- Unit portrait background
    if unit.type == "knight" then
        love.graphics.setColor(COLORS.weapon)
    elseif unit.type == "bishop" then
        love.graphics.setColor(COLORS.mana)
    elseif unit.type == "rook" then
        love.graphics.setColor(COLORS.armor)
    elseif unit.type == "pawn" then
        love.graphics.setColor(0.7, 0.7, 0.8)
    elseif unit.type == "queen" then
        love.graphics.setColor(COLORS.gold)
    end
    
    love.graphics.rectangle("fill", portraitX, portraitY, portraitSize, portraitSize)
    
    -- Stats section
    local statsX = popupX + 170
    local statsY = popupY + 80
    
    love.graphics.setFont(menuFont)
    love.graphics.setColor(COLORS.title)
    love.graphics.print("STATS", statsX, statsY)
    
    -- HP bar
    local barWidth = 200
    love.graphics.setColor(COLORS.panel)
    love.graphics.rectangle("fill", statsX, statsY + 30, barWidth, 20)
    love.graphics.setColor(COLORS.health)
    love.graphics.rectangle("fill", statsX, statsY + 30, barWidth, 20)
    
    love.graphics.setFont(smallFont)
    love.graphics.setColor(COLORS.text)
    love.graphics.print("HP: " .. unit.stats.health .. "/" .. unit.stats.maxHealth, statsX + 5, statsY + 32)
    
    -- MP bar
    love.graphics.setColor(COLORS.panel)
    love.graphics.rectangle("fill", statsX, statsY + 60, barWidth, 20)
    love.graphics.setColor(COLORS.mana)
    love.graphics.rectangle("fill", statsX, statsY + 60, barWidth, 20)
    
    love.graphics.setFont(smallFont)
    love.graphics.setColor(COLORS.text)
    love.graphics.print("MP: " .. unit.stats.mana .. "/" .. unit.stats.maxMana, statsX + 5, statsY + 62)
    
    -- Other stats
    love.graphics.setFont(smallFont)
    
    love.graphics.setColor(COLORS.attack)
    love.graphics.print("ATK: " .. unit.stats.attack, statsX, statsY + 90)
    
    love.graphics.setColor(COLORS.defense)
    love.graphics.print("DEF: " .. unit.stats.defense, statsX + 100, statsY + 90)
    
    love.graphics.setColor(COLORS.speed)
    love.graphics.print("SPD: " .. unit.stats.speed, statsX, statsY + 110)
    
    -- Equipment section
    love.graphics.setFont(menuFont)
    love.graphics.setColor(COLORS.title)
    love.graphics.print("EQUIPMENT", popupX + 30, popupY + 220)
    
    -- Equipment slots
    local slotSize = 60
    local slotSpacing = 20
    local equipY = popupY + 250
    
    -- Weapon slot
    local weaponX = popupX + 30
    love.graphics.setColor(COLORS.panel)
    love.graphics.rectangle("fill", weaponX, equipY, slotSize, slotSize)
    love.graphics.setColor(COLORS.weapon)
    love.graphics.rectangle("line", weaponX, equipY, slotSize, slotSize)
    
    love.graphics.setFont(smallFont)
    love.graphics.setColor(COLORS.textDim)
    love.graphics.print("Weapon", weaponX, equipY + slotSize + 5)
    
    -- Armor slot
    local armorX = weaponX + slotSize + slotSpacing
    love.graphics.setColor(COLORS.panel)
    love.graphics.rectangle("fill", armorX, equipY, slotSize, slotSize)
    love.graphics.setColor(COLORS.armor)
    love.graphics.rectangle("line", armorX, equipY, slotSize, slotSize)
    
    love.graphics.setFont(smallFont)
    love.graphics.setColor(COLORS.textDim)
    love.graphics.print("Armor", armorX, equipY + slotSize + 5)
    
    -- Accessory slot
    local accessoryX = armorX + slotSize + slotSpacing
    love.graphics.setColor(COLORS.panel)
    love.graphics.rectangle("fill", accessoryX, equipY, slotSize, slotSize)
    love.graphics.setColor(COLORS.accessory)
    love.graphics.rectangle("line", accessoryX, equipY, slotSize, slotSize)
    
    love.graphics.setFont(smallFont)
    love.graphics.setColor(COLORS.textDim)
    love.graphics.print("Accessory", accessoryX, equipY + slotSize + 5)
    
    -- Abilities section
    love.graphics.setFont(menuFont)
    love.graphics.setColor(COLORS.title)
    love.graphics.print("ABILITIES", statsX, equipY)
    
    love.graphics.setFont(smallFont)
    love.graphics.setColor(COLORS.textDim)
    for i, ability in ipairs(unit.abilities) do
        love.graphics.print("- " .. ability, statsX, equipY + 30 + (i-1) * 25)
    end
    
    -- Close button
    local closeButtonWidth = 60
    local closeButtonHeight = 30
    local closeButtonX = popupX + popupWidth - closeButtonWidth - 20
    local closeButtonY = popupY + 20
    
    love.graphics.setColor(COLORS.health)
    love.graphics.rectangle("fill", closeButtonX, closeButtonY, closeButtonWidth, closeButtonHeight)
    
    love.graphics.setFont(menuFont)
    love.graphics.setColor(COLORS.text)
    love.graphics.print("Close", closeButtonX + 5, closeButtonY + 5)
end

-- Draw item detail popup
function TeamManagement:drawItemDetailPopup(width, height, item)
    -- Semi-transparent overlay
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, width, height)
    
    -- Popup panel
    local popupWidth = 500
    local popupHeight = 400
    local popupX = width/2 - popupWidth/2
    local popupY = height/2 - popupHeight/2
    
    love.graphics.setColor(COLORS.panel)
    love.graphics.rectangle("fill", popupX, popupY, popupWidth, popupHeight, 5, 5)
    love.graphics.setColor(COLORS.border)
    love.graphics.rectangle("line", popupX, popupY, popupWidth, popupHeight, 5, 5)
    
    -- Item name
    love.graphics.setFont(titleFont)
    love.graphics.setColor(COLORS.rarity[item.rarity] or COLORS.title)
    love.graphics.printf(item.name, popupX, popupY + 20, popupWidth, "center")
    
    -- Item type and rarity
    love.graphics.setFont(menuFont)
    love.graphics.setColor(COLORS.textDim)
    love.graphics.printf(item.type:upper() .. " (" .. item.rarity:sub(1,1):upper() .. item.rarity:sub(2) .. ")", 
                        popupX, popupY + 50, popupWidth, "center")
    
    -- Item icon
    local iconSize = 100
    local iconX = popupX + 30
    local iconY = popupY + 80
    
    -- Item icon based on type
    local itemColor
    if item.type == "weapon" then
        itemColor = COLORS.weapon
    elseif item.type == "armor" then
        itemColor = COLORS.armor
    elseif item.type == "accessory" then
        itemColor = COLORS.accessory
    else
        itemColor = {0.7, 0.7, 0.8}
    end
    
    love.graphics.setColor(itemColor)
    love.graphics.rectangle("fill", iconX, iconY, iconSize, iconSize)
    love.graphics.setColor(COLORS.rarity[item.rarity] or COLORS.border)
    love.graphics.rectangle("line", iconX, iconY, iconSize, iconSize)
    
    -- Item description
    love.graphics.setFont(smallFont)
    love.graphics.setColor(COLORS.text)
    love.graphics.printf(item.description, popupX + 150, popupY + 80, popupWidth - 180, "left")
    
    -- Stats section
    love.graphics.setFont(menuFont)
    love.graphics.setColor(COLORS.title)
    love.graphics.print("STATS", popupX + 30, popupY + 200)
    
    if item.stats then
        local statY = popupY + 230
        for stat, value in pairs(item.stats) do
            local statColor
            if stat == "attack" then
                statColor = COLORS.attack
            elseif stat == "defense" then
                statColor = COLORS.defense
            elseif stat == "speed" then
                statColor = COLORS.speed
            elseif stat == "mana" or stat == "maxMana" then
                statColor = COLORS.mana
            else
                statColor = COLORS.text
            end
            
            love.graphics.setFont(smallFont)
            love.graphics.setColor(statColor)
            local prefix = value >= 0 and "+" or ""
            love.graphics.print(stat:upper() .. ": " .. prefix .. value, popupX + 40, statY)
            statY = statY + 20
        end
    else
        love.graphics.setFont(smallFont)
        love.graphics.setColor(COLORS.textDim)
        love.graphics.print("None", popupX + 40, popupY + 230)
    end
    
    -- Requirements section
    if item.type == "weapon" or item.type == "armor" or item.type == "accessory" then
        love.graphics.setFont(menuFont)
        love.graphics.setColor(COLORS.title)
        love.graphics.print("REQUIREMENTS", popupX + 200, popupY + 200)
        
        love.graphics.setFont(smallFont)
        love.graphics.setColor(COLORS.textDim)
        love.graphics.print("Usable by:", popupX + 210, popupY + 230)
        
        if item.equippableBy and #item.equippableBy > 0 then
            local unitTypes = table.concat(item.equippableBy, ", "):upper()
            love.graphics.print(unitTypes, popupX + 210, popupY + 250)
        else
            love.graphics.print("All units", popupX + 210, popupY + 250)
        end
    end
    
    -- Action buttons
    local buttonWidth = 120
    local buttonHeight = 40
    local buttonY = popupY + popupHeight - 60
    
    -- Buy/Equip button
    local actionButtonX = popupX + popupWidth/2 - buttonWidth/2
    
    if currentTab == "items" then
        -- Buy button
        if playerCurrency >= item.cost then
            love.graphics.setColor(COLORS.button)
        else
            love.graphics.setColor(COLORS.buttonDisabled)
        end
        love.graphics.rectangle("fill", actionButtonX, buttonY, buttonWidth, buttonHeight)
        love.graphics.setColor(COLORS.border)
        love.graphics.rectangle("line", actionButtonX, buttonY, buttonWidth, buttonHeight)
        
        love.graphics.setFont(menuFont)
        love.graphics.setColor(COLORS.text)
        love.graphics.printf("BUY: " .. item.cost .. "g", actionButtonX, buttonY + 10, buttonWidth, "center")
    else
        -- Equip button
        love.graphics.setColor(COLORS.button)
        love.graphics.rectangle("fill", actionButtonX, buttonY, buttonWidth, buttonHeight)
        love.graphics.setColor(COLORS.border)
        love.graphics.rectangle("line", actionButtonX, buttonY, buttonWidth, buttonHeight)
        
        love.graphics.setFont(menuFont)
        love.graphics.setColor(COLORS.text)
        love.graphics.printf("EQUIP", actionButtonX, buttonY + 10, buttonWidth, "center")
    end
    
    -- Close button
    local closeButtonWidth = 60
    local closeButtonHeight = 30
    local closeButtonX = popupX + popupWidth - closeButtonWidth - 20
    local closeButtonY = popupY + 20
    
    love.graphics.setColor(COLORS.health)
    love.graphics.rectangle("fill", closeButtonX, closeButtonY, closeButtonWidth, closeButtonHeight)
    
    love.graphics.setFont(menuFont)
    love.graphics.setColor(COLORS.text)
    love.graphics.print("Close", closeButtonX + 5, closeButtonY + 5)
end

-- Update isOverBuyButton to use selectedStoreUnit
function TeamManagement:isOverBuyButton(x, y)
    -- If we're not on the units tab or have no unit selected, we can't be over the buy button
    if currentTab ~= "units" or (not selectedStoreUnit and not hoveredUnit) then 
        return false 
    end
    
    local infoWidth = 274
    local infoHeight = love.graphics.getHeight() - 160
    local infoX = love.graphics.getWidth() - infoWidth - 30
    local infoY = 140
    
    local buyButtonWidth = 120
    local buyButtonHeight = 40
    local buyButtonX = infoX + (infoWidth - buyButtonWidth) / 2
    local buyButtonY = infoY + infoHeight - 60
    
    return x >= buyButtonX and x <= buyButtonX + buyButtonWidth and 
           y >= buyButtonY and y <= buyButtonY + buyButtonHeight
end

-- Enhanced mousepressed function
function TeamManagement:mousepressed(x, y, button)
    if button ~= 1 then return end
    
    -- Check if unit detail popup is active
    if showUnitDetail then
        self:handleUnitDetailPopupClick(x, y)
        return
    end
    
    -- Check if item detail popup is active
    if showItemDetail then
        self:handleItemDetailPopupClick(x, y)
        return
    end

    -- Check buy button click - do this early in the function
    if self:isOverBuyButton(x, y) then
        -- Use selectedStoreUnit for buying if available, otherwise use hoveredUnit
        local unitToBuy = selectedStoreUnit or hoveredUnit
        if unitToBuy then
            self:buyUnit(unitToBuy)
            return
        end
    end
    
    -- Check tab clicks
    local tabWidth = 120
    local tabHeight = 40
    local tabY = 80
    local tabSpacing = 10
    local totalWidth = (tabWidth + tabSpacing) * 3 - tabSpacing
    local startX = (love.graphics.getWidth() - totalWidth) / 2
    
    -- Units tab
    local unitsTabX = startX
    if x >= unitsTabX and x <= unitsTabX + tabWidth and y >= tabY and y <= tabY + tabHeight then
        currentTab = "units"
        return
    end
    
    -- Items tab
    local itemsTabX = unitsTabX + tabWidth + tabSpacing
    if x >= itemsTabX and x <= itemsTabX + tabWidth and y >= tabY and y <= tabY + tabHeight then
        currentTab = "items"
        -- Clear unit selection when switching tabs
        selectedStoreUnit = nil
        return
    end
    
    -- Equipment tab
    local equipTabX = itemsTabX + tabWidth + tabSpacing
    if x >= equipTabX and x <= equipTabX + tabWidth and y >= tabY and y <= tabY + tabHeight then
        currentTab = "equipment"
        equipmentSlotSelected = nil
        -- Clear unit selection when switching tabs
        selectedStoreUnit = nil
        return
    end
    
    -- Check team slot clicks
    local panelWidth = 250
    local panelX = 30
    local panelY = 140
    local slotSize = 100
    local spacing = 20
    local startY = panelY + 50
    
    for i = 1, maxTeamSize do
        local slotX = panelX + (panelWidth - slotSize) / 2
        local slotY = startY + (i-1) * (slotSize + spacing)
        
        if x >= slotX and x <= slotX + slotSize and y >= slotY and y <= slotY + slotSize then
            if i <= #selectedUnits then
                -- Select this unit
                selectedUnitIndex = i
                
                -- Show unit detail on double click
                if self.lastClickedUnit == i and love.timer.getTime() - self.lastClickTime < 0.5 then
                    showUnitDetail = true
                    detailUnit = availableUnits[selectedUnits[i]]
                end
                
                self.lastClickedUnit = i
                self.lastClickTime = love.timer.getTime()
            elseif currentTab == "units" and hoveredUnit then
                -- Try to add unit to team
                self:addUnitToTeam(hoveredUnit)
            end
            return
        end
    end
    
    -- Check store content clicks
    local contentX = 300
    local contentY = 140
    local contentWidth = love.graphics.getWidth() - 600
    local contentHeight = love.graphics.getHeight() - 250
    
    if x >= contentX and x <= contentX + contentWidth and y >= contentY and y <= contentY + contentHeight then
        if currentTab == "units" then
            self:handleUnitsStoreClick(x, y, contentX, contentY, contentWidth, contentHeight)
        elseif currentTab == "items" then
            self:handleItemsStoreClick(x, y, contentX, contentY, contentWidth, contentHeight)
        else -- equipment tab
            self:handleEquipmentTabClick(x, y, contentX, contentY, contentWidth, contentHeight)
        end
        return
    end
    
    -- Check navigation button clicks
    local buttonWidth = 140
    local buttonHeight = 40
    local buttonY = love.graphics.getHeight() - 60
    
    -- Back button
    local backX = love.graphics.getWidth()/2 - buttonWidth - 10
    if x >= backX and x <= backX + buttonWidth and y >= buttonY and y <= buttonY + buttonHeight then
        gamestate.switch(require("src.states.menu"), self.game)
        return
    end
    
    -- Start Game button
    local startX = love.graphics.getWidth()/2 + 10
    if x >= startX and x <= startX + buttonWidth and y >= buttonY and y <= buttonY + buttonHeight then
        if #selectedUnits > 0 then
            self:startGame()
        end
        return
    end
    
    -- Check buy button in unit info panel - important fix!
    if self:isOverBuyButton(x, y) then
        self:buyUnit(hoveredUnit)
        return
    end
    
    -- Check buy button in item info panel 
    if (currentTab == "items" or currentTab == "equipment") and hoveredItem then
        local infoWidth = 274
        local infoX = love.graphics.getWidth() - infoWidth - 30
        local infoY = 140
        local infoHeight = love.graphics.getHeight() - 160
        
        local buttonWidth = 120
        local buttonHeight = 40
        local buttonX = infoX + (infoWidth - buttonWidth) / 2
        local buttonY = infoY + infoHeight - 60
        
        if x >= buttonX and x <= buttonX + buttonWidth and y >= buttonY and y <= buttonY + buttonHeight then
            if currentTab == "items" then
                self:buyItem(hoveredItem)
            else
                self:equipItem(hoveredItem)
            end
            return
        end
    end
end

-- Handle unit detail popup click
function TeamManagement:handleUnitDetailPopupClick(x, y)
    local width, height = love.graphics.getDimensions()
    local popupWidth = 500
    local popupHeight = 400
    local popupX = width/2 - popupWidth/2
    local popupY = height/2 - popupHeight/2
    
    -- Check close button
    local closeButtonWidth = 60
    local closeButtonHeight = 30
    local closeButtonX = popupX + popupWidth - closeButtonWidth - 20
    local closeButtonY = popupY + 20
    
    if x >= closeButtonX and x <= closeButtonX + closeButtonWidth and y >= closeButtonY and y <= closeButtonY + closeButtonHeight then
        showUnitDetail = false
        detailUnit = nil
        return
    end
    
    -- Check equipment slots
    local slotSize = 60
    local slotSpacing = 20
    local equipY = popupY + 250
    
    -- Weapon slot
    local weaponX = popupX + 30
    if x >= weaponX and x <= weaponX + slotSize and y >= equipY and y <= equipY + slotSize then
        currentTab = "equipment"
        equipmentSlotSelected = 1
        showUnitDetail = false
        return
    end
    
    -- Armor slot
    local armorX = weaponX + slotSize + slotSpacing
    if x >= armorX and x <= armorX + slotSize and y >= equipY and y <= equipY + slotSize then
        currentTab = "equipment"
        equipmentSlotSelected = 2
        showUnitDetail = false
        return
    end
    
    -- Accessory slot
    local accessoryX = armorX + slotSize + slotSpacing
    if x >= accessoryX and x <= accessoryX + slotSize and y >= equipY and y <= equipY + slotSize then
        currentTab = "equipment"
        equipmentSlotSelected = 3
        showUnitDetail = false
        return
    end
end

-- Handle item detail popup click
function TeamManagement:handleItemDetailPopupClick(x, y)
    local width, height = love.graphics.getDimensions()
    local popupWidth = 500
    local popupHeight = 400
    local popupX = width/2 - popupWidth/2
    local popupY = height/2 - popupHeight/2
    
    -- Check close button
    local closeButtonWidth = 60
    local closeButtonHeight = 30
    local closeButtonX = popupX + popupWidth - closeButtonWidth - 20
    local closeButtonY = popupY + 20
    
    if x >= closeButtonX and x <= closeButtonX + closeButtonWidth and y >= closeButtonY and y <= closeButtonY + closeButtonHeight then
        showItemDetail = false
        detailItem = nil
        return
    end
    
    -- Check action button
    local buttonWidth = 120
    local buttonHeight = 40
    local buttonY = popupY + popupHeight - 60
    local actionButtonX = popupX + popupWidth/2 - buttonWidth/2
    
    if x >= actionButtonX and x <= actionButtonX + buttonWidth and y >= buttonY and y <= buttonY + buttonHeight then
        if currentTab == "items" then
            self:buyItem(hoveredItem)
        else
            self:equipItem(hoveredItem)
        end
        showItemDetail = false
        detailItem = nil
        return
    end
end

-- Updated handleUnitsStoreClick to set selectedStoreUnit
function TeamManagement:handleUnitsStoreClick(x, y, contentX, contentY, contentWidth, contentHeight)
    local unitSize = 80
    local cols = 4
    local spacing = 20
    local startY = contentY + 50 - scrollOffset
    
    for i, unit in ipairs(availableUnits) do
        local col = (i-1) % cols
        local row = math.floor((i-1) / cols)
        
        local unitX = contentX + (contentWidth - (cols * unitSize + (cols-1) * spacing)) / 2 + col * (unitSize + spacing)
        local unitY = startY + row * (unitSize + spacing)
        
        if x >= unitX and x <= unitX + unitSize and y >= unitY and y <= unitY + unitSize then
            -- Show unit detail on double click
            if self.lastClickedStoreUnit == i and love.timer.getTime() - self.lastClickTime < 0.5 then
                showUnitDetail = true
                detailUnit = availableUnits[i]
            else
                -- Set the persistent selection
                if selectedStoreUnit == i then
                    -- If clicking on already selected unit, deselect it
                    selectedStoreUnit = nil
                else
                    -- Otherwise select the new unit
                    selectedStoreUnit = i
                    hoveredUnit = i  -- Also set hoveredUnit for immediate visual feedback
                end
            end
            
            self.lastClickedStoreUnit = i
            self.lastClickTime = love.timer.getTime()
            return
        end
    end
    
    -- If we click in the store area but not on any unit, keep the selection
    -- This prevents accidental deselection when clicking in empty space
end

-- Handle items store click
function TeamManagement:handleItemsStoreClick(x, y, contentX, contentY, contentWidth, contentHeight)
    local itemSize = 80
    local cols = 4
    local spacing = 20
    local startY = contentY + 50 - scrollOffset
    
    for i, item in ipairs(availableItems) do
        local col = (i-1) % cols
        local row = math.floor((i-1) / cols)
        
        local itemX = contentX + (contentWidth - (cols * itemSize + (cols-1) * spacing)) / 2 + col * (itemSize + spacing)
        local itemY = startY + row * (itemSize + spacing)
        
        if x >= itemX and x <= itemX + itemSize and y >= itemY and y <= itemY + itemSize then
            -- Show item detail on double click
            if self.lastClickedStoreItem == i and love.timer.getTime() - self.lastClickTime < 0.5 then
                showItemDetail = true
                detailItem = availableItems[i]
            else
                -- Single click selects the item
                hoveredItem = i
            end
            
            self.lastClickedStoreItem = i
            self.lastClickTime = love.timer.getTime()
            return
        end
    end
end

-- Handle equipment tab click
function TeamManagement:handleEquipmentTabClick(x, y, contentX, contentY, contentWidth, contentHeight)
    -- Check if a unit is selected
    if #selectedUnits == 0 or not selectedUnitIndex or selectedUnitIndex > #selectedUnits then
        return
    end
    
    -- Check equipment slot clicks
    local slotSize = 80
    local slotSpacing = 20
    local slotsY = contentY + 100
    
    for i = 1, 3 do
        local slotX = contentX + 20 + (i-1) * (slotSize + slotSpacing)
        
        if x >= slotX and x <= slotX + slotSize and y >= slotsY and y <= slotsY + slotSize then
            equipmentSlotSelected = i
            return
        end
    end
    
    -- Check inventory item clicks
    local inventoryRect = {x = contentX + 20, y = contentY + 250, width = contentWidth - 40, height = contentHeight - 270}
    
    if x >= inventoryRect.x and x <= inventoryRect.x + inventoryRect.width and 
       y >= inventoryRect.y and y <= inventoryRect.y + inventoryRect.height then
        
        local itemSize = 60
        local cols = 6
        local spacing = 10
        local startY = inventoryRect.y + 10 - scrollOffset
        
        -- Filter items by equipment type if a slot is selected
        local filteredItems = {}
        local equipTypes = {"weapon", "armor", "accessory"}
        
        if equipmentSlotSelected then
            local slotType = equipTypes[equipmentSlotSelected]
            for i, item in ipairs(availableItems) do
                if item.type == slotType then
                    table.insert(filteredItems, {index = i, item = item})
                end
            end
        else
            for i, item in ipairs(availableItems) do
                if item.type == "weapon" or item.type == "armor" or item.type == "accessory" then
                    table.insert(filteredItems, {index = i, item = item})
                end
            end
        end
        
        for i, itemData in ipairs(filteredItems) do
            local col = (i-1) % cols
            local row = math.floor((i-1) / cols)
            
            local itemX = inventoryRect.x + 10 + col * (itemSize + spacing)
            local itemY = startY + row * (itemSize + spacing)
            
            if x >= itemX and x <= itemX + itemSize and y >= itemY and y <= itemY + itemSize then
                -- Show item detail on double click
                if self.lastClickedInventoryItem == itemData.index and love.timer.getTime() - self.lastClickTime < 0.5 then
                    showItemDetail = true
                    detailItem = availableItems[itemData.index]
                else
                    -- Single click selects the item
                    hoveredItem = itemData.index
                end
                
                self.lastClickedInventoryItem = itemData.index
                self.lastClickTime = love.timer.getTime()
                return
            end
        end
    end
end

-- Handle mouse wheel
function TeamManagement:wheelmoved(x, y)
    -- Adjust scroll offset based on wheel movement
    scrollOffset = scrollOffset - y * 30
    
    -- Clamp scroll offset
    scrollOffset = math.max(0, math.min(scrollOffset, maxScroll))
end

-- Fix for the TeamManagement:mousemoved function
function TeamManagement:mousemoved(x, y)
    -- Only track temporary hovering effects with hoveredUnit/hoveredItem
    -- The persistent selection is tracked by selectedStoreUnit
    hoveredUnit = nil
    hoveredItem = nil
    
    -- Check units store hover for highlighting effect only
    if currentTab == "units" then
        local contentX = 300
        local contentY = 140
        local contentWidth = love.graphics.getWidth() - 600
        local unitSize = 80
        local cols = 4
        local spacing = 20
        local startY = contentY + 50 - scrollOffset

        for i, unit in ipairs(availableUnits) do
            local col = (i - 1) % cols
            local row = math.floor((i - 1) / cols)
            local unitX = contentX + (contentWidth - (cols * unitSize + (cols - 1) * spacing)) / 2 + col * (unitSize + spacing)
            local unitY = startY + row * (unitSize + spacing)

            -- Check if mouse is within the visible area bounds before checking the specific unit
            if unitY + unitSize >= contentY and unitY <= contentY + (love.graphics.getHeight() - 250) then
                if x >= unitX and x <= unitX + unitSize and y >= unitY and y <= unitY + unitSize then
                    hoveredUnit = i
                    break
                end
            end
        end
    
    -- Similarly check items store hover
    elseif currentTab == "items" then
        local contentX = 300
        local contentY = 140
        local contentWidth = love.graphics.getWidth() - 600
        local itemSize = 80
        local cols = 4
        local spacing = 20
        local startY = contentY + 50 - scrollOffset

        for i, item in ipairs(availableItems) do
            local col = (i-1) % cols
            local row = math.floor((i-1) / cols)
            local itemX = contentX + (contentWidth - (cols * itemSize + (cols-1) * spacing)) / 2 + col * (itemSize + spacing)
            local itemY = startY + row * (itemSize + spacing)

            if itemY + itemSize >= contentY and itemY <= contentY + (love.graphics.getHeight() - 250) then
                if x >= itemX and x <= itemX + itemSize and y >= itemY and y <= itemY + itemSize then
                    hoveredItem = i
                    break
                end
            end
        end
    
    -- Check equipment tab hover
    elseif currentTab == "equipment" then
        local contentX = 300
        local contentY = 140
        local contentWidth = love.graphics.getWidth() - 600
        local contentHeight = love.graphics.getHeight() - 250
        local inventoryRect = {x = contentX + 20, y = contentY + 250, width = contentWidth - 40, height = contentHeight - 270}

        if x >= inventoryRect.x and x <= inventoryRect.x + inventoryRect.width and
           y >= inventoryRect.y and y <= inventoryRect.y + inventoryRect.height then

            local itemSize = 60
            local cols = 6
            local spacing = 10
            local startY = inventoryRect.y + 10 - scrollOffset
            local filteredItems = {}
            local equipTypes = {"weapon", "armor", "accessory"}

            if #selectedUnits > 0 and selectedUnitIndex and selectedUnitIndex <= #selectedUnits then
                if equipmentSlotSelected then
                    local slotType = equipTypes[equipmentSlotSelected]
                    for itemIdx, item in ipairs(availableItems) do
                        if item.type == slotType then
                            table.insert(filteredItems, {index = itemIdx, item = item})
                        end
                    end
                else
                    for itemIdx, item in ipairs(availableItems) do
                        if item.type == "weapon" or item.type == "armor" or item.type == "accessory" then
                            table.insert(filteredItems, {index = itemIdx, item = item})
                        end
                    end
                end
            end

            for i, itemData in ipairs(filteredItems) do
                local col = (i-1) % cols
                local row = math.floor((i-1) / cols)
                local itemX = inventoryRect.x + 10 + col * (itemSize + spacing)
                local itemY = startY + row * (itemSize + spacing)

                if itemY + itemSize >= inventoryRect.y and itemY <= inventoryRect.y + inventoryRect.height then
                    if x >= itemX and x <= itemX + itemSize and y >= itemY and y <= itemY + itemSize then
                        hoveredItem = itemData.index
                        break
                    end
                end
            end
        end
    end
end

-- Add unit to team
function TeamManagement:addUnitToTeam(unitIndex)
    if #selectedUnits >= maxTeamSize then
        -- Team is full
        return false
    end
    
    local unit = availableUnits[unitIndex]
    if not unit then
        return false
    end
    
    -- Check if can afford
    if playerCurrency < unit.cost then
        return false
    end
    
    -- Add to team
    table.insert(selectedUnits, unitIndex)
    
    -- Deduct cost
    playerCurrency = playerCurrency - unit.cost
    
    -- Select the newly added unit
    selectedUnitIndex = #selectedUnits
    
    return true
end

-- Remove unit from team
function TeamManagement:removeUnitFromTeam(teamIndex)
    if teamIndex <= 0 or teamIndex > #selectedUnits then
        return false
    end
    
    local unitIndex = selectedUnits[teamIndex]
    local unit = availableUnits[unitIndex]
    
    -- Refund cost
    playerCurrency = playerCurrency + unit.cost
    
    -- Remove from team
    table.remove(selectedUnits, teamIndex)
    
    -- Update selected unit index
    if selectedUnitIndex > #selectedUnits then
        selectedUnitIndex = #selectedUnits
    end
    
    return true
end

-- Update buyUnit function to use selectedStoreUnit
function TeamManagement:buyUnit(unitIndex)
    local unitToBuy = unitIndex or selectedStoreUnit
    if not unitToBuy then return false end
    
    local result = self:addUnitToTeam(unitToBuy)
    
    if result then
        -- Optionally play a purchase sound
        -- if self.game.assets.sounds.purchase then
        --    love.audio.play(self.game.assets.sounds.purchase)
        -- end
        
        -- Show a visual confirmation
        local flashTimer = 0.5
        timer.during(flashTimer, function()
            self.unitPurchaseFlash = true
            self.flashedUnitIndex = #selectedUnits
        end, function()
            self.unitPurchaseFlash = false
            self.flashedUnitIndex = nil
        end)
        
        -- Clear selection after successful purchase
        selectedStoreUnit = nil
    else
        -- Show why the purchase failed
        self.purchaseFailReason = playerCurrency < availableUnits[unitToBuy].cost 
            and "Not enough gold!" 
            or "Team is full!"
        
        -- Show the error message briefly
        timer.after(2, function()
            self.purchaseFailReason = nil
        end)
    end
    
    return result
end

-- Buy item
function TeamManagement:buyItem(itemIndex)
    local item = availableItems[itemIndex]
    if not item then
        return false
    end
    
    -- Check if can afford
    if playerCurrency < item.cost then
        return false
    end
    
    -- Add to inventory (in a real implementation, this would add to player's inventory)
    -- For now, we'll just deduct the cost
    playerCurrency = playerCurrency - item.cost
    
    return true
end

-- Equip item
function TeamManagement:equipItem(itemIndex)
    if not selectedUnitIndex or selectedUnitIndex > #selectedUnits then
        return false
    end
    
    local unit = availableUnits[selectedUnits[selectedUnitIndex]]
    local item = availableItems[itemIndex]
    
    if not unit or not item then
        return false
    end
    
    -- Check if unit can equip this item
    local canEquip = true
    if item.equippableBy and #item.equippableBy > 0 then
        canEquip = false
        for _, unitType in ipairs(item.equippableBy) do
            if unit.type == unitType then
                canEquip = true
                break
            end
        end
    end
    
    if not canEquip then
        return false
    end
    
    -- Determine slot
    local slot = item.type
    
    -- Equip item
    unit.equipment = unit.equipment or {}
    unit.equipment[slot] = item
    
    return true
end

-- Unequip item
function TeamManagement:unequipItem(slot)
    if not selectedUnitIndex or selectedUnitIndex > #selectedUnits then
        return false
    end
    
    local unit = availableUnits[selectedUnits[selectedUnitIndex]]
    
    if not unit or not unit.equipment or not unit.equipment[slot] then
        return false
    end
    
    -- Unequip item
    unit.equipment[slot] = nil
    
    return true
end

-- Start game
function TeamManagement:startGame()
    print("--- TeamManagement:startGame - START ---")
    print("  self.game object ID at start: " .. tostring(self.game))

    -- Create actual Unit instances from selected units
    local gamePlayerUnits = {} -- Use a distinct name for the list being built

    -- Check if any units were actually selected by the player
    if #selectedUnits == 0 then
        print("  ERROR: No units selected for the team! Please add at least one unit.")
        -- Optionally show a message to the player here using a UI element
        -- e.g., self:showNotification("You must select at least one unit!")
        return -- Don't proceed if the team is empty
    end

    print("  Processing " .. #selectedUnits .. " selected unit indices: " .. table.concat(selectedUnits, ", "))

    for i, unitIndex in ipairs(selectedUnits) do
        -- Validate unitIndex
        if not unitIndex or unitIndex <= 0 or unitIndex > #availableUnits then
             print("    WARNING: Invalid unitIndex found in selectedUnits: " .. tostring(unitIndex) .. ". Skipping.")
             goto continue_loop_sg -- Skip this index
        end

        local unitData = availableUnits[unitIndex]

        if not unitData then
            print("    WARNING: No unit data found for index: " .. unitIndex .. ". Skipping.")
            goto continue_loop_sg -- Skip this index
        end

        print(string.format("  Creating Unit instance for index %d (Unit Type: %s)", unitIndex, unitData.type))

        -- Get abilities, ensuring it's an array
        local abilities = unitData.abilities or {}
        if type(abilities) ~= "table" then abilities = {} end

        -- Create PROPER Unit instance, passing the stats table directly
        local unit = Unit:new({
            unitType = unitData.type,
            faction = "player",
            isPlayerControlled = true,
            stats = unitData.stats, -- Pass the whole stats table from availableUnits
            abilities = abilities,
            -- movementPattern will be derived in Unit:initialize based on type
        })

        -- Equip items (needs refinement based on how you store equipped items in TM)
        -- Example: If unitData stores equipment indices/IDs
        if unitData.equipment then
            for slot, itemIdentifier in pairs(unitData.equipment) do
                local itemData = nil
                -- Find item in availableItems or selectedItems based on identifier
                -- For example, if itemIdentifier is an index into availableItems:
                if availableItems[itemIdentifier] then
                     itemData = availableItems[itemIdentifier]
                end

                if itemData then
                    local itemInstance = Item:new(itemData) -- Create Item instance from data
                    -- Ensure slot is valid
                    if slot == "weapon" or slot == "armor" or slot == "accessory" then
                         local equipped, msg = unit:equipItem(itemInstance, slot) -- Use the Unit's equip method
                         if not equipped then print("    Failed to equip item:", msg) end
                    else
                         print("    Invalid slot for item:", slot)
                    end
                else
                    print("    Could not find item data for identifier:", itemIdentifier)
                end
            end
        end

        -- *** FIX: Moved table.insert INSIDE the loop ***
        table.insert(gamePlayerUnits, unit)
        print("    Added Unit instance " .. (unit.id or "N/A") .. " to gamePlayerUnits list.")

        ::continue_loop_sg:: -- Label for goto
    end

    -- Check if any units were actually added (in case of errors above)
    if #gamePlayerUnits == 0 then
        print("  ERROR: No valid player units were created. Aborting start.")
        -- Optionally show an error message to the player
        return
    end

    -- Now assign the fully populated list to the game object
    self.game.playerUnits = gamePlayerUnits
    self.game.playerGold = playerCurrency -- Assuming you want to pass the remaining gold
    print("  Assigned playerUnits to self.game.playerUnits. Count: " .. #self.game.playerUnits)
    print("  self.game object ID before switch: " .. tostring(self.game))

    -- Switch to game state
    gamestate.switch(require("src.states.game"), self.game)
end

-- Helper function to zip two tables together
function zip(t1, t2)
    local result = {}
    for i = 1, math.min(#t1, #t2) do
        table.insert(result, {t1[i], t2[i]})
    end
    return result
end

return TeamManagement
