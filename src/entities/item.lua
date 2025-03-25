-- Item System for Nightfall Chess
-- Handles item creation, management, and effects

local class = require("lib.middleclass.middleclass")

local Item = class("Item")

function Item:initialize(params)
    params = params or {}
    
    -- Basic properties
    self.id = (params.id or "item_") .. tostring(math.random(1000000))
    self.name = params.name or "Unknown Item"
    self.description = params.description or "A mysterious item."
    self.type = params.type or "consumable" -- consumable, weapon, armor, accessory, key
    self.rarity = params.rarity or "common" -- common, uncommon, rare, epic, legendary
    self.icon = params.icon -- Image for UI display
    self.quantity = params.quantity or 1
    self.stackable = params.stackable ~= false
    self.maxStack = params.maxStack or 99
    self.value = params.value or 10 -- Gold value
    
    -- Equipment properties
    self.equipped = params.equipped or false
    self.equippableBy = params.equippableBy or {} -- List of unit types that can equip this
    self.slot = params.slot or "none" -- Equipment slot: weapon, armor, accessory
    
    -- Stats modifications when equipped
    self.stats = params.stats or {}
    
    -- Consumable properties
    self.consumable = params.consumable or false
    self.useEffect = params.useEffect -- Function to call when used
    self.charges = params.charges -- Number of uses before depleted (nil = infinite)
    
    -- Special properties
    self.unique = params.unique or false -- Only one can exist in inventory
    self.questItem = params.questItem or false -- Cannot be sold or discarded
    self.hidden = params.hidden or false -- Hidden stats/effects until identified
    
    -- Custom properties
    self.properties = params.properties or {}
    
    -- Callbacks
    self.onEquip = params.onEquip
    self.onUnequip = params.onUnequip
    self.onUse = params.onUse
    self.onPickup = params.onPickup
    self.onDrop = params.onDrop
end

-- Check if item can be equipped by a specific unit
function Item:canEquip(unit)
    -- Check if item is equippable
    if self.slot == "none" then
        return false
    end
    
    -- Check if unit can equip this item type
    if #self.equippableBy > 0 then
        local canEquip = false
        for _, unitType in ipairs(self.equippableBy) do
            if unit.unitType == unitType then
                canEquip = true
                break
            end
        end
        
        if not canEquip then
            return false
        end
    end
    
    return true
end

-- Equip item to a unit
function Item:equip(unit)
    if not self:canEquip(unit) then
        return false
    end
    
    -- Unequip any item in the same slot
    if unit.equipment and unit.equipment[self.slot] then
        unit.equipment[self.slot]:unequip(unit)
    end
    
    -- Mark as equipped
    self.equipped = true
    
    -- Add to unit's equipment
    if not unit.equipment then
        unit.equipment = {}
    end
    unit.equipment[self.slot] = self
    
    -- Apply stat modifications
    if self.stats then
        for stat, value in pairs(self.stats) do
            if unit.stats[stat] then
                -- Store original value if not already stored
                if not unit.originalStats then
                    unit.originalStats = {}
                end
                
                if not unit.originalStats[stat] then
                    unit.originalStats[stat] = unit.stats[stat]
                end
                
                -- Apply modification
                unit.stats[stat] = unit.stats[stat] + value
            end
        end
    end
    
    -- Call equip callback
    if self.onEquip then
        self.onEquip(unit)
    end
    
    return true
end

-- Unequip item from a unit
function Item:unequip(unit)
    if not self.equipped then
        return false
    end
    
    -- Mark as unequipped
    self.equipped = false
    
    -- Remove from unit's equipment
    if unit.equipment and unit.equipment[self.slot] == self then
        unit.equipment[self.slot] = nil
    end
    
    -- Remove stat modifications
    if self.stats and unit.originalStats then
        for stat, _ in pairs(self.stats) do
            if unit.originalStats[stat] then
                unit.stats[stat] = unit.originalStats[stat]
                unit.originalStats[stat] = nil
            end
        end
    end
    
    -- Call unequip callback
    if self.onUnequip then
        self.onUnequip(unit)
    end
    
    return true
end

-- Use consumable item
function Item:use(unit)
    if not self.consumable then
        return false
    end
    
    -- Apply use effect
    local success = false
    
    if self.useEffect then
        success = self.useEffect(unit)
    end
    
    -- Call use callback
    if self.onUse then
        local callbackResult = self.onUse(unit)
        success = success or callbackResult
    end
    
    -- Reduce charges if applicable
    if success and self.charges then
        self.charges = self.charges - 1
        
        -- Remove item if out of charges
        if self.charges <= 0 then
            return true, true -- Second return value indicates item should be removed
        end
    end
    
    -- Reduce quantity if successful
    if success and not self.charges then
        self.quantity = self.quantity - 1
        
        -- Return whether item should be removed (quantity <= 0)
        return true, self.quantity <= 0
    end
    
    return success, false
end

-- Add to stack
function Item:addToStack(amount)
    if not self.stackable then
        return false
    end
    
    amount = amount or 1
    
    -- Check max stack
    if self.quantity + amount > self.maxStack then
        local remainder = (self.quantity + amount) - self.maxStack
        self.quantity = self.maxStack
        return remainder -- Return overflow
    end
    
    self.quantity = self.quantity + amount
    return 0 -- No overflow
end

-- Remove from stack
function Item:removeFromStack(amount)
    amount = amount or 1
    
    if amount > self.quantity then
        local removed = self.quantity
        self.quantity = 0
        return removed -- Return actual amount removed
    end
    
    self.quantity = self.quantity - amount
    return amount
end

-- Check if items are stackable together
function Item.canStack(item1, item2)
    -- Must be same item type
    if item1.name ~= item2.name then
        return false
    end
    
    -- Both must be stackable
    if not item1.stackable or not item2.stackable then
        return false
    end
    
    -- Check if item1 has room
    if item1.quantity >= item1.maxStack then
        return false
    end
    
    return true
end

-- Clone item
function Item:clone()
    local params = {
        id = self.id,
        name = self.name,
        description = self.description,
        type = self.type,
        rarity = self.rarity,
        icon = self.icon,
        quantity = self.quantity,
        stackable = self.stackable,
        maxStack = self.maxStack,
        value = self.value,
        equipped = false, -- Clone is never equipped
        equippableBy = self.equippableBy,
        slot = self.slot,
        consumable = self.consumable,
        useEffect = self.useEffect,
        charges = self.charges,
        unique = self.unique,
        questItem = self.questItem,
        hidden = self.hidden,
        onEquip = self.onEquip,
        onUnequip = self.onUnequip,
        onUse = self.onUse,
        onPickup = self.onPickup,
        onDrop = self.onDrop
    }
    
    -- Clone stats
    if self.stats then
        params.stats = {}
        for k, v in pairs(self.stats) do
            params.stats[k] = v
        end
    end
    
    -- Clone properties
    if self.properties then
        params.properties = {}
        for k, v in pairs(self.properties) do
            params.properties[k] = v
        end
    end
    
    return Item:new(params)
end

-- Get item description including stats
function Item:getFullDescription()
    local desc = self.description
    
    -- Add stats information
    if self.stats and not self.hidden then
        desc = desc .. "\n\nStats:"
        for stat, value in pairs(self.stats) do
            local prefix = value >= 0 and "+" or ""
            desc = desc .. "\n" .. stat:sub(1,1):upper() .. stat:sub(2) .. ": " .. prefix .. value
        end
    end
    
    -- Add equipment information
    if self.slot ~= "none" then
        desc = desc .. "\n\nEquip: " .. self.slot:sub(1,1):upper() .. self.slot:sub(2)
    end
    
    -- Add consumable information
    if self.consumable then
        desc = desc .. "\n\nConsumable"
        if self.charges then
            desc = desc .. " (" .. self.charges .. " charges)"
        end
    end
    
    -- Add special properties
    if self.unique then
        desc = desc .. "\n\nUnique"
    end
    
    if self.questItem then
        desc = desc .. "\n\nQuest Item"
    end
    
    return desc
end

-- Compare items for equality
function Item:equals(other)
    return self.id == other.id
end

-- Get item value adjusted for quantity
function Item:getTotalValue()
    return self.value * self.quantity
end

-- Get color based on rarity
function Item:getRarityColor()
    local colors = {
        common = {0.8, 0.8, 0.8},
        uncommon = {0.2, 0.8, 0.2},
        rare = {0.2, 0.2, 0.9},
        epic = {0.8, 0.2, 0.8},
        legendary = {0.9, 0.6, 0.1}
    }
    
    return colors[self.rarity] or colors.common
end

return Item
