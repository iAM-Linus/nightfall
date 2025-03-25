-- Inventory Manager for Nightfall Chess
-- Handles item collections, storage, and interactions

local class = require("lib.middleclass.middleclass")
local Item = require("src.entities.item")

local InventoryManager = class("InventoryManager")

function InventoryManager:initialize(game)
    self.game = game
    
    -- Inventory storage
    self.items = {}
    self.maxItems = 50 -- Maximum inventory capacity
    
    -- Equipment slots
    self.equipmentSlots = {
        "weapon",
        "armor",
        "accessory"
    }
    
    -- Item categories
    self.categories = {
        "weapon",
        "armor",
        "accessory",
        "consumable",
        "key",
        "quest"
    }
    
    -- Gold/currency
    self.gold = 0
    
    -- Callbacks
    self.onItemAdded = nil
    self.onItemRemoved = nil
    self.onItemUsed = nil
    self.onItemEquipped = nil
    self.onItemUnequipped = nil
    self.onGoldChanged = nil
end

-- Add item to inventory
function InventoryManager:addItem(item, quantity)
    quantity = quantity or item.quantity or 1
    
    -- Check if inventory is full
    if #self.items >= self.maxItems and not self:canStack(item) then
        return false, "Inventory is full"
    end
    
    -- Check if item is unique and already exists
    if item.unique then
        for _, existingItem in ipairs(self.items) do
            if existingItem.id == item.id then
                return false, "You already have this unique item"
            end
        end
    end
    
    -- Try to stack with existing items
    if item.stackable then
        for _, existingItem in ipairs(self.items) do
            if Item.canStack(existingItem, item) then
                local overflow = existingItem:addToStack(quantity)
                
                -- If fully stacked
                if overflow == 0 then
                    -- Call callback
                    if self.onItemAdded then
                        self.onItemAdded(existingItem, quantity)
                    end
                    
                    return true
                end
                
                -- Partially stacked, continue with remainder
                quantity = overflow
            end
        end
    end
    
    -- Create new item entry if couldn't fully stack
    local newItem = item:clone()
    newItem.quantity = quantity
    
    -- Add to inventory
    table.insert(self.items, newItem)
    
    -- Call callback
    if self.onItemAdded then
        self.onItemAdded(newItem, quantity)
    end
    
    return true
end

-- Remove item from inventory
function InventoryManager:removeItem(item, quantity)
    quantity = quantity or 1
    
    -- Find item in inventory
    for i, inventoryItem in ipairs(self.items) do
        if inventoryItem == item then
            -- Remove from stack
            local removed = inventoryItem:removeFromStack(quantity)
            
            -- Remove item completely if quantity is 0
            if inventoryItem.quantity <= 0 then
                -- Unequip if equipped
                if inventoryItem.equipped then
                    self:unequipItem(inventoryItem)
                end
                
                table.remove(self.items, i)
            end
            
            -- Call callback
            if self.onItemRemoved then
                self.onItemRemoved(item, removed)
            end
            
            return true, removed
        end
    end
    
    return false, 0
end

-- Use item
function InventoryManager:useItem(item, unit)
    -- Find item in inventory
    for i, inventoryItem in ipairs(self.items) do
        if inventoryItem == item then
            -- Use the item
            local success, shouldRemove = inventoryItem:use(unit)
            
            if success then
                -- Call callback
                if self.onItemUsed then
                    self.onItemUsed(item, unit)
                end
                
                -- Remove item if needed
                if shouldRemove then
                    table.remove(self.items, i)
                end
                
                return true
            end
            
            return false, "Item could not be used"
        end
    end
    
    return false, "Item not found in inventory"
end

-- Equip item
function InventoryManager:equipItem(item, unit)
    -- Find item in inventory
    for _, inventoryItem in ipairs(self.items) do
        if inventoryItem == item then
            -- Equip the item
            local success = inventoryItem:equip(unit)
            
            if success then
                -- Call callback
                if self.onItemEquipped then
                    self.onItemEquipped(item, unit)
                end
                
                return true
            end
            
            return false, "Item could not be equipped"
        end
    end
    
    return false, "Item not found in inventory"
end

-- Unequip item
function InventoryManager:unequipItem(item, unit)
    -- Find item in inventory
    for _, inventoryItem in ipairs(self.items) do
        if inventoryItem == item then
            -- Unequip the item
            local success = inventoryItem:unequip(unit)
            
            if success then
                -- Call callback
                if self.onItemUnequipped then
                    self.onItemUnequipped(item, unit)
                end
                
                return true
            end
            
            return false, "Item could not be unequipped"
        end
    end
    
    return false, "Item not found in inventory"
end

-- Check if an item can be stacked in the inventory
function InventoryManager:canStack(item)
    if not item.stackable then
        return false
    end
    
    for _, existingItem in ipairs(self.items) do
        if Item.canStack(existingItem, item) and existingItem.quantity < existingItem.maxStack then
            return true
        end
    end
    
    return false
end

-- Get all items of a specific type
function InventoryManager:getItemsByType(itemType)
    local result = {}
    
    for _, item in ipairs(self.items) do
        if item.type == itemType then
            table.insert(result, item)
        end
    end
    
    return result
end

-- Get all equipped items
function InventoryManager:getEquippedItems()
    local result = {}
    
    for _, item in ipairs(self.items) do
        if item.equipped then
            table.insert(result, item)
        end
    end
    
    return result
end

-- Get item in a specific equipment slot
function InventoryManager:getEquippedItemInSlot(slot, unit)
    if unit and unit.equipment then
        return unit.equipment[slot]
    end
    
    for _, item in ipairs(self.items) do
        if item.equipped and item.slot == slot then
            return item
        end
    end
    
    return nil
end

-- Get total inventory weight
function InventoryManager:getTotalWeight()
    local weight = 0
    
    for _, item in ipairs(self.items) do
        if item.weight then
            weight = weight + (item.weight * item.quantity)
        end
    end
    
    return weight
end

-- Get total inventory value
function InventoryManager:getTotalValue()
    local value = 0
    
    for _, item in ipairs(self.items) do
        value = value + item:getTotalValue()
    end
    
    return value
end

-- Check if inventory is full
function InventoryManager:isFull()
    return #self.items >= self.maxItems
end

-- Get number of free slots
function InventoryManager:getFreeSlots()
    return self.maxItems - #self.items
end

-- Sort inventory
function InventoryManager:sortInventory(sortType)
    sortType = sortType or "type"
    
    if sortType == "type" then
        table.sort(self.items, function(a, b)
            if a.type ~= b.type then
                return a.type < b.type
            end
            return a.name < b.name
        end)
    elseif sortType == "name" then
        table.sort(self.items, function(a, b)
            return a.name < b.name
        end)
    elseif sortType == "value" then
        table.sort(self.items, function(a, b)
            return a.value > b.value
        end)
    elseif sortType == "rarity" then
        local rarityOrder = {
            common = 1,
            uncommon = 2,
            rare = 3,
            epic = 4,
            legendary = 5
        }
        
        table.sort(self.items, function(a, b)
            local aOrder = rarityOrder[a.rarity] or 0
            local bOrder = rarityOrder[b.rarity] or 0
            
            if aOrder ~= bOrder then
                return aOrder > bOrder
            end
            return a.name < b.name
        end)
    end
end

-- Add gold
function InventoryManager:addGold(amount)
    self.gold = self.gold + amount
    
    -- Call callback
    if self.onGoldChanged then
        self.onGoldChanged(self.gold)
    end
    
    return self.gold
end

-- Remove gold
function InventoryManager:removeGold(amount)
    if amount > self.gold then
        return false, "Not enough gold"
    end
    
    self.gold = self.gold - amount
    
    -- Call callback
    if self.onGoldChanged then
        self.onGoldChanged(self.gold)
    end
    
    return true
end

-- Create a new item
function InventoryManager:createItem(params)
    return Item:new(params)
end

-- Create a random item
function InventoryManager:createRandomItem(level, itemType)
    level = level or 1
    
    -- Determine item type if not specified
    if not itemType then
        local types = {"weapon", "armor", "accessory", "consumable"}
        itemType = types[math.random(#types)]
    end
    
    -- Determine rarity based on level
    local rarities = {"common", "uncommon", "rare", "epic", "legendary"}
    local rarityChances = {
        {0.80, 0.20, 0.00, 0.00, 0.00}, -- Level 1
        {0.60, 0.30, 0.10, 0.00, 0.00}, -- Level 2
        {0.40, 0.40, 0.15, 0.05, 0.00}, -- Level 3
        {0.30, 0.35, 0.25, 0.08, 0.02}, -- Level 4
        {0.20, 0.30, 0.30, 0.15, 0.05}  -- Level 5+
    }
    
    local rarityTable = rarityChances[math.min(level, 5)]
    local rarity = "common"
    local roll = math.random()
    local cumulativeChance = 0
    
    for i, chance in ipairs(rarityTable) do
        cumulativeChance = cumulativeChance + chance
        if roll <= cumulativeChance then
            rarity = rarities[i]
            break
        end
    end
    
    -- Base stats based on level and rarity
    local statMultiplier = {
        common = 1.0,
        uncommon = 1.5,
        rare = 2.0,
        epic = 3.0,
        legendary = 5.0
    }
    
    local multiplier = statMultiplier[rarity] * (1 + (level - 1) * 0.2)
    
    -- Create item based on type
    if itemType == "weapon" then
        return self:createRandomWeapon(level, rarity, multiplier)
    elseif itemType == "armor" then
        return self:createRandomArmor(level, rarity, multiplier)
    elseif itemType == "accessory" then
        return self:createRandomAccessory(level, rarity, multiplier)
    elseif itemType == "consumable" then
        return self:createRandomConsumable(level, rarity, multiplier)
    end
    
    -- Fallback
    return Item:new({
        name = "Random Item",
        description = "A randomly generated item.",
        type = itemType,
        rarity = rarity
    })
end

-- Create a random weapon
function InventoryManager:createRandomWeapon(level, rarity, multiplier)
    -- Weapon types based on chess pieces
    local weaponTypes = {
        {name = "Pawn's Dagger", attack = 2, defense = 0},
        {name = "Knight's Sword", attack = 3, defense = 1},
        {name = "Bishop's Staff", attack = 4, defense = 0},
        {name = "Rook's Hammer", attack = 5, defense = 2},
        {name = "Queen's Scepter", attack = 6, defense = 1},
        {name = "King's Blade", attack = 4, defense = 3}
    }
    
    local weaponType = weaponTypes[math.random(#weaponTypes)]
    
    -- Generate name based on rarity
    local rarityPrefix = {
        common = "",
        uncommon = "Fine ",
        rare = "Superior ",
        epic = "Exquisite ",
        legendary = "Legendary "
    }
    
    local name = rarityPrefix[rarity] .. weaponType.name
    
    -- Generate stats
    local stats = {
        attack = math.floor(weaponType.attack * multiplier),
        defense = math.floor(weaponType.defense * multiplier)
    }
    
    -- Add random bonus stat for higher rarities
    if rarity == "rare" or rarity == "epic" or rarity == "legendary" then
        local bonusStats = {"moveRange", "attackRange", "initiative"}
        local bonusStat = bonusStats[math.random(#bonusStats)]
        stats[bonusStat] = math.max(1, math.floor(multiplier / 2))
    end
    
    -- Create weapon item
    return Item:new({
        name = name,
        description = "A " .. rarity .. " weapon that increases combat effectiveness.",
        type = "weapon",
        rarity = rarity,
        slot = "weapon",
        stats = stats,
        value = math.floor(10 * multiplier),
        equippableBy = {"king", "queen", "rook", "bishop", "knight", "pawn"}
    })
end

-- Create a random armor
function InventoryManager:createRandomArmor(level, rarity, multiplier)
    -- Armor types
    local armorTypes = {
        {name = "Leather Armor", defense = 3, attack = 0},
        {name = "Chain Mail", defense = 4, attack = -1},
        {name = "Plate Armor", defense = 5, attack = -1},
        {name = "Royal Guard Armor", defense = 6, attack = 0},
        {name = "Knight's Armor", defense = 4, attack = 1},
        {name = "Battle Robes", defense = 2, attack = 2}
    }
    
    local armorType = armorTypes[math.random(#armorTypes)]
    
    -- Generate name based on rarity
    local rarityPrefix = {
        common = "",
        uncommon = "Sturdy ",
        rare = "Reinforced ",
        epic = "Ancient ",
        legendary = "Mythical "
    }
    
    local name = rarityPrefix[rarity] .. armorType.name
    
    -- Generate stats
    local stats = {
        defense = math.floor(armorType.defense * multiplier),
        attack = math.floor(armorType.attack * multiplier)
    }
    
    -- Add random bonus stat for higher rarities
    if rarity == "rare" or rarity == "epic" or rarity == "legendary" then
        local bonusStats = {"health", "moveRange", "initiative"}
        local bonusStat = bonusStats[math.random(#bonusStats)]
        
        if bonusStat == "health" then
            stats[bonusStat] = math.floor(10 * multiplier)
        else
            stats[bonusStat] = math.max(1, math.floor(multiplier / 2))
        end
    end
    
    -- Create armor item
    return Item:new({
        name = name,
        description = "A " .. rarity .. " armor that provides protection in battle.",
        type = "armor",
        rarity = rarity,
        slot = "armor",
        stats = stats,
        value = math.floor(12 * multiplier),
        equippableBy = {"king", "queen", "rook", "bishop", "knight", "pawn"}
    })
end

-- Create a random accessory
function InventoryManager:createRandomAccessory(level, rarity, multiplier)
    -- Accessory types
    local accessoryTypes = {
        {name = "Ring of Power", stat = "attack", value = 2},
        {name = "Amulet of Protection", stat = "defense", value = 2},
        {name = "Boots of Speed", stat = "moveRange", value = 1},
        {name = "Crown of Command", stat = "initiative", value = 2},
        {name = "Belt of Vitality", stat = "health", value = 10},
        {name = "Cloak of Shadows", stat = "attackRange", value = 1}
    }
    
    local accessoryType = accessoryTypes[math.random(#accessoryTypes)]
    
    -- Generate name based on rarity
    local rarityPrefix = {
        common = "",
        uncommon = "Polished ",
        rare = "Enchanted ",
        epic = "Mystical ",
        legendary = "Divine "
    }
    
    local name = rarityPrefix[rarity] .. accessoryType.name
    
    -- Generate stats
    local stats = {}
    stats[accessoryType.stat] = math.floor(accessoryType.value * multiplier)
    
    -- Add random bonus stat for higher rarities
    if rarity == "rare" or rarity == "epic" or rarity == "legendary" then
        local bonusStats = {"attack", "defense", "moveRange", "initiative", "health", "attackRange"}
        
        -- Remove the primary stat from bonus options
        for i, stat in ipairs(bonusStats) do
            if stat == accessoryType.stat then
                table.remove(bonusStats, i)
                break
            end
        end
        
        local bonusStat = bonusStats[math.random(#bonusStats)]
        
        if bonusStat == "health" then
            stats[bonusStat] = math.floor(5 * multiplier)
        else
            stats[bonusStat] = math.max(1, math.floor(multiplier / 3))
        end
    end
    
    -- Create accessory item
    return Item:new({
        name = name,
        description = "A " .. rarity .. " accessory that enhances abilities.",
        type = "accessory",
        rarity = rarity,
        slot = "accessory",
        stats = stats,
        value = math.floor(15 * multiplier),
        equippableBy = {"king", "queen", "rook", "bishop", "knight", "pawn"}
    })
end

-- Create a random consumable
function InventoryManager:createRandomConsumable(level, rarity, multiplier)
    -- Consumable types
    local consumableTypes = {
        {
            name = "Health Potion",
            description = "Restores health when consumed.",
            effect = function(unit)
                local healAmount = math.floor(10 * multiplier)
                if self.game.combatSystem then
                    self.game.combatSystem:applyHealing(unit, healAmount, {
                        source = "item",
                        effect = "Health Potion"
                    })
                    return true
                else
                    unit.stats.health = math.min(unit.stats.maxHealth, unit.stats.health + healAmount)
                    return true
                end
            end
        },
        {
            name = "Strength Elixir",
            description = "Temporarily increases attack power.",
            effect = function(unit)
                local attackBoost = math.floor(2 * multiplier)
                unit.originalAttack = unit.stats.attack
                unit.stats.attack = unit.stats.attack + attackBoost
                
                -- Register temporary effect
                if self.game.turnManager then
                    self.game.turnManager:registerUnitStatusEffect(unit, "strengthElixir", {
                        name = "Strength Boost",
                        description = "Attack increased",
                        duration = 3,
                        triggerOn = "turnStart",
                        onRemove = function(unit)
                            if unit.originalAttack then
                                unit.stats.attack = unit.originalAttack
                                unit.originalAttack = nil
                            end
                        end
                    })
                end
                
                return true
            end
        },
        {
            name = "Shield Potion",
            description = "Temporarily increases defense.",
            effect = function(unit)
                local defenseBoost = math.floor(2 * multiplier)
                unit.originalDefense = unit.stats.defense
                unit.stats.defense = unit.stats.defense + defenseBoost
                
                -- Register temporary effect
                if self.game.turnManager then
                    self.game.turnManager:registerUnitStatusEffect(unit, "shieldPotion", {
                        name = "Defense Boost",
                        description = "Defense increased",
                        duration = 3,
                        triggerOn = "turnStart",
                        onRemove = function(unit)
                            if unit.originalDefense then
                                unit.stats.defense = unit.originalDefense
                                unit.originalDefense = nil
                            end
                        end
                    })
                end
                
                return true
            end
        },
        {
            name = "Speed Draught",
            description = "Temporarily increases movement range.",
            effect = function(unit)
                local moveBoost = 1
                unit.originalMoveRange = unit.stats.moveRange
                unit.stats.moveRange = unit.stats.moveRange + moveBoost
                
                -- Register temporary effect
                if self.game.turnManager then
                    self.game.turnManager:registerUnitStatusEffect(unit, "speedDraught", {
                        name = "Speed Boost",
                        description = "Movement increased",
                        duration = 3,
                        triggerOn = "turnStart",
                        onRemove = function(unit)
                            if unit.originalMoveRange then
                                unit.stats.moveRange = unit.originalMoveRange
                                unit.originalMoveRange = nil
                            end
                        end
                    })
                end
                
                return true
            end
        },
        {
            name = "Cleansing Tonic",
            description = "Removes negative status effects.",
            effect = function(unit)
                local effectsRemoved = 0
                
                if unit.statusEffects then
                    for id, effect in pairs(unit.statusEffects) do
                        -- Only remove negative effects
                        if effect.name == "Burning" or effect.name == "Stunned" or 
                           effect.name == "Weakened" or effect.name == "Slowed" then
                            
                            if effect.onRemove then
                                effect.onRemove(unit)
                            end
                            
                            unit.statusEffects[id] = nil
                            effectsRemoved = effectsRemoved + 1
                        end
                    end
                end
                
                return effectsRemoved > 0
            end
        }
    }
    
    local consumableType = consumableTypes[math.random(#consumableTypes)]
    
    -- Generate name based on rarity
    local rarityPrefix = {
        common = "",
        uncommon = "Quality ",
        rare = "Superior ",
        epic = "Master's ",
        legendary = "Legendary "
    }
    
    local name = rarityPrefix[rarity] .. consumableType.name
    
    -- Determine charges based on rarity
    local charges = nil
    if rarity == "uncommon" or rarity == "rare" then
        charges = 2
    elseif rarity == "epic" or rarity == "legendary" then
        charges = 3
    end
    
    -- Create consumable item
    return Item:new({
        name = name,
        description = consumableType.description,
        type = "consumable",
        rarity = rarity,
        consumable = true,
        useEffect = consumableType.effect,
        charges = charges,
        stackable = (rarity == "common"),
        maxStack = 5,
        value = math.floor(8 * multiplier)
    })
end

-- Generate starting inventory
function InventoryManager:generateStartingInventory()
    -- Add basic equipment
    self:addItem(self:createItem({
        name = "Wooden Sword",
        description = "A basic wooden sword. Better than nothing.",
        type = "weapon",
        rarity = "common",
        slot = "weapon",
        stats = {attack = 1},
        value = 5,
        equippableBy = {"king", "queen", "rook", "bishop", "knight", "pawn"}
    }))
    
    self:addItem(self:createItem({
        name = "Padded Vest",
        description = "A simple padded vest offering minimal protection.",
        type = "armor",
        rarity = "common",
        slot = "armor",
        stats = {defense = 1},
        value = 5,
        equippableBy = {"king", "queen", "rook", "bishop", "knight", "pawn"}
    }))
    
    -- Add consumables
    self:addItem(self:createItem({
        name = "Health Potion",
        description = "Restores 10 health when consumed.",
        type = "consumable",
        rarity = "common",
        consumable = true,
        useEffect = function(unit)
            local healAmount = 10
            if self.game.combatSystem then
                self.game.combatSystem:applyHealing(unit, healAmount, {
                    source = "item",
                    effect = "Health Potion"
                })
                return true
            else
                unit.stats.health = math.min(unit.stats.maxHealth, unit.stats.health + healAmount)
                return true
            end
        end,
        stackable = true,
        quantity = 3,
        maxStack = 5,
        value = 5
    }))
    
    -- Add starting gold
    self.gold = 50
end

-- Save inventory to table
function InventoryManager:saveToTable()
    local data = {
        gold = self.gold,
        items = {}
    }
    
    for i, item in ipairs(self.items) do
        local itemData = {
            id = item.id,
            name = item.name,
            description = item.description,
            type = item.type,
            rarity = item.rarity,
            quantity = item.quantity,
            stackable = item.stackable,
            maxStack = item.maxStack,
            value = item.value,
            equipped = item.equipped,
            equippableBy = item.equippableBy,
            slot = item.slot,
            consumable = item.consumable,
            charges = item.charges,
            unique = item.unique,
            questItem = item.questItem,
            hidden = item.hidden
        }
        
        -- Save stats
        if item.stats then
            itemData.stats = {}
            for k, v in pairs(item.stats) do
                itemData.stats[k] = v
            end
        end
        
        -- Save properties
        if item.properties then
            itemData.properties = {}
            for k, v in pairs(item.properties) do
                itemData.properties[k] = v
            end
        end
        
        table.insert(data.items, itemData)
    end
    
    return data
end

-- Load inventory from table
function InventoryManager:loadFromTable(data)
    if not data then return false end
    
    -- Clear current inventory
    self.items = {}
    
    -- Load gold
    self.gold = data.gold or 0
    
    -- Load items
    for _, itemData in ipairs(data.items or {}) do
        local item = Item:new(itemData)
        table.insert(self.items, item)
    end
    
    return true
end

return InventoryManager
