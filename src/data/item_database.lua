-- Item Database for Nightfall Chess
-- Contains definitions for all items in the game

local ItemDatabase = {}

-- Weapons
ItemDatabase.weapons = {
    -- Common weapons
    wooden_sword = {
        name = "Wooden Sword",
        description = "A basic wooden sword. Better than nothing.",
        type = "weapon",
        rarity = "common",
        slot = "weapon",
        stats = {attack = 1},
        value = 5,
        equippableBy = {"king", "queen", "rook", "bishop", "knight", "pawn"}
    },
    rusty_dagger = {
        name = "Rusty Dagger",
        description = "A small, rusty dagger that's seen better days.",
        type = "weapon",
        rarity = "common",
        slot = "weapon",
        stats = {attack = 2, moveRange = -1},
        value = 8,
        equippableBy = {"king", "queen", "bishop", "knight", "pawn"}
    },
    
    -- Uncommon weapons
    iron_sword = {
        name = "Iron Sword",
        description = "A standard iron sword with decent balance.",
        type = "weapon",
        rarity = "uncommon",
        slot = "weapon",
        stats = {attack = 3},
        value = 15,
        equippableBy = {"king", "queen", "knight", "pawn"}
    },
    battle_axe = {
        name = "Battle Axe",
        description = "A heavy axe that deals significant damage but slows movement.",
        type = "weapon",
        rarity = "uncommon",
        slot = "weapon",
        stats = {attack = 4, moveRange = -1},
        value = 18,
        equippableBy = {"king", "rook", "knight"}
    },
    mage_staff = {
        name = "Mage Staff",
        description = "A staff that channels magical energy, increasing attack range.",
        type = "weapon",
        rarity = "uncommon",
        slot = "weapon",
        stats = {attack = 2, attackRange = 1},
        value = 20,
        equippableBy = {"queen", "bishop"}
    },
    
    -- Rare weapons
    steel_greatsword = {
        name = "Steel Greatsword",
        description = "A finely crafted greatsword that deals devastating damage.",
        type = "weapon",
        rarity = "rare",
        slot = "weapon",
        stats = {attack = 5, defense = 1},
        value = 35,
        equippableBy = {"king", "queen", "knight"}
    },
    bishops_crook = {
        name = "Bishop's Crook",
        description = "A blessed crook that enhances magical abilities.",
        type = "weapon",
        rarity = "rare",
        slot = "weapon",
        stats = {attack = 4, attackRange = 1, initiative = 1},
        value = 40,
        equippableBy = {"bishop"}
    },
    knights_lance = {
        name = "Knight's Lance",
        description = "A specialized lance that allows for powerful charging attacks.",
        type = "weapon",
        rarity = "rare",
        slot = "weapon",
        stats = {attack = 6, moveRange = 1},
        value = 45,
        equippableBy = {"knight"}
    },
    
    -- Epic weapons
    queens_rapier = {
        name = "Queen's Rapier",
        description = "An elegant rapier that grants exceptional combat prowess.",
        type = "weapon",
        rarity = "epic",
        slot = "weapon",
        stats = {attack = 7, moveRange = 1, initiative = 2},
        value = 75,
        equippableBy = {"queen"}
    },
    kings_executioner = {
        name = "King's Executioner",
        description = "A royal executioner's blade that strikes fear into enemies.",
        type = "weapon",
        rarity = "epic",
        slot = "weapon",
        stats = {attack = 8, defense = 2},
        value = 80,
        equippableBy = {"king"}
    },
    castle_destroyer = {
        name = "Castle Destroyer",
        description = "A massive hammer capable of bringing down castle walls.",
        type = "weapon",
        rarity = "epic",
        slot = "weapon",
        stats = {attack = 9, moveRange = -1, defense = 1},
        value = 85,
        equippableBy = {"rook"}
    },
    
    -- Legendary weapons
    excalibur = {
        name = "Excalibur",
        description = "The legendary sword of kings, said to choose its wielder.",
        type = "weapon",
        rarity = "legendary",
        slot = "weapon",
        stats = {attack = 10, defense = 3, initiative = 2},
        value = 150,
        equippableBy = {"king"},
        unique = true
    },
    infinity_blade = {
        name = "Infinity Blade",
        description = "A mystical blade that seems to cut through reality itself.",
        type = "weapon",
        rarity = "legendary",
        slot = "weapon",
        stats = {attack = 12, moveRange = 1, attackRange = 1},
        value = 180,
        equippableBy = {"queen", "knight", "bishop"},
        unique = true
    }
}

-- Armor
ItemDatabase.armor = {
    -- Common armor
    padded_vest = {
        name = "Padded Vest",
        description = "A simple padded vest offering minimal protection.",
        type = "armor",
        rarity = "common",
        slot = "armor",
        stats = {defense = 1},
        value = 5,
        equippableBy = {"king", "queen", "rook", "bishop", "knight", "pawn"}
    },
    leather_armor = {
        name = "Leather Armor",
        description = "Basic leather armor that provides some protection.",
        type = "armor",
        rarity = "common",
        slot = "armor",
        stats = {defense = 2},
        value = 10,
        equippableBy = {"king", "queen", "rook", "bishop", "knight", "pawn"}
    },
    
    -- Uncommon armor
    chain_mail = {
        name = "Chain Mail",
        description = "Interlocking metal rings that provide good protection.",
        type = "armor",
        rarity = "uncommon",
        slot = "armor",
        stats = {defense = 3, moveRange = -1},
        value = 20,
        equippableBy = {"king", "rook", "knight", "pawn"}
    },
    battle_robes = {
        name = "Battle Robes",
        description = "Enchanted robes that offer protection without restricting movement.",
        type = "armor",
        rarity = "uncommon",
        slot = "armor",
        stats = {defense = 2, initiative = 1},
        value = 25,
        equippableBy = {"queen", "bishop"}
    },
    
    -- Rare armor
    plate_armor = {
        name = "Plate Armor",
        description = "Heavy plate armor that provides excellent protection.",
        type = "armor",
        rarity = "rare",
        slot = "armor",
        stats = {defense = 5, moveRange = -1},
        value = 40,
        equippableBy = {"king", "rook", "knight"}
    },
    enchanted_cloak = {
        name = "Enchanted Cloak",
        description = "A magical cloak that deflects attacks and enhances mobility.",
        type = "armor",
        rarity = "rare",
        slot = "armor",
        stats = {defense = 3, moveRange = 1},
        value = 45,
        equippableBy = {"queen", "bishop"}
    },
    
    -- Epic armor
    royal_guard_armor = {
        name = "Royal Guard Armor",
        description = "Exquisite armor worn by the elite royal guards.",
        type = "armor",
        rarity = "epic",
        slot = "armor",
        stats = {defense = 6, attack = 1, health = 10},
        value = 80,
        equippableBy = {"king", "rook"}
    },
    shadow_weave = {
        name = "Shadow Weave",
        description = "Armor woven from shadow itself, granting stealth and protection.",
        type = "armor",
        rarity = "epic",
        slot = "armor",
        stats = {defense = 4, moveRange = 1, initiative = 2},
        value = 85,
        equippableBy = {"queen", "bishop", "knight"}
    },
    
    -- Legendary armor
    dragonscale_armor = {
        name = "Dragonscale Armor",
        description = "Legendary armor forged from the scales of an ancient dragon.",
        type = "armor",
        rarity = "legendary",
        slot = "armor",
        stats = {defense = 8, attack = 2, health = 20},
        value = 160,
        equippableBy = {"king", "queen", "rook"},
        unique = true
    },
    celestial_plate = {
        name = "Celestial Plate",
        description = "Armor said to be forged in the heavens, granting divine protection.",
        type = "armor",
        rarity = "legendary",
        slot = "armor",
        stats = {defense = 7, moveRange = 1, health = 15, initiative = 2},
        value = 175,
        equippableBy = {"bishop", "knight", "pawn"},
        unique = true
    }
}

-- Accessories
ItemDatabase.accessories = {
    -- Common accessories
    iron_ring = {
        name = "Iron Ring",
        description = "A simple iron ring that provides a minor boost to defense.",
        type = "accessory",
        rarity = "common",
        slot = "accessory",
        stats = {defense = 1},
        value = 8,
        equippableBy = {"king", "queen", "rook", "bishop", "knight", "pawn"}
    },
    leather_boots = {
        name = "Leather Boots",
        description = "Comfortable boots that slightly improve mobility.",
        type = "accessory",
        rarity = "common",
        slot = "accessory",
        stats = {moveRange = 1},
        value = 10,
        equippableBy = {"king", "queen", "rook", "bishop", "knight", "pawn"}
    },
    
    -- Uncommon accessories
    amulet_of_health = {
        name = "Amulet of Health",
        description = "An amulet that enhances vitality and resilience.",
        type = "accessory",
        rarity = "uncommon",
        slot = "accessory",
        stats = {health = 10},
        value = 20,
        equippableBy = {"king", "queen", "rook", "bishop", "knight", "pawn"}
    },
    ring_of_power = {
        name = "Ring of Power",
        description = "A ring that enhances the wearer's attack strength.",
        type = "accessory",
        rarity = "uncommon",
        slot = "accessory",
        stats = {attack = 2},
        value = 25,
        equippableBy = {"king", "queen", "rook", "bishop", "knight", "pawn"}
    },
    
    -- Rare accessories
    crown_of_command = {
        name = "Crown of Command",
        description = "A crown that enhances leadership and initiative.",
        type = "accessory",
        rarity = "rare",
        slot = "accessory",
        stats = {initiative = 3, attack = 1},
        value = 45,
        equippableBy = {"king", "queen"}
    },
    boots_of_speed = {
        name = "Boots of Speed",
        description = "Enchanted boots that significantly increase mobility.",
        type = "accessory",
        rarity = "rare",
        slot = "accessory",
        stats = {moveRange = 2, initiative = 1},
        value = 50,
        equippableBy = {"knight", "bishop", "pawn"}
    },
    
    -- Epic accessories
    cloak_of_shadows = {
        name = "Cloak of Shadows",
        description = "A mystical cloak that allows the wearer to strike from unexpected angles.",
        type = "accessory",
        rarity = "epic",
        slot = "accessory",
        stats = {attackRange = 1, initiative = 2, attack = 2},
        value = 85,
        equippableBy = {"queen", "bishop", "knight"}
    },
    belt_of_giants = {
        name = "Belt of Giants",
        description = "A belt that grants immense strength and resilience.",
        type = "accessory",
        rarity = "epic",
        slot = "accessory",
        stats = {attack = 3, defense = 2, health = 15},
        value = 90,
        equippableBy = {"king", "rook", "pawn"}
    },
    
    -- Legendary accessories
    crown_of_ascension = {
        name = "Crown of Ascension",
        description = "A legendary crown that elevates the wearer's abilities to godlike levels.",
        type = "accessory",
        rarity = "legendary",
        slot = "accessory",
        stats = {attack = 4, defense = 3, initiative = 3, health = 20},
        value = 180,
        equippableBy = {"king"},
        unique = true
    },
    infinity_gauntlet = {
        name = "Infinity Gauntlet",
        description = "A powerful gauntlet that grants mastery over all aspects of combat.",
        type = "accessory",
        rarity = "legendary",
        slot = "accessory",
        stats = {attack = 3, defense = 2, moveRange = 1, attackRange = 1, initiative = 2},
        value = 200,
        equippableBy = {"queen", "rook", "bishop", "knight", "pawn"},
        unique = true
    }
}

-- Consumables
ItemDatabase.consumables = {
    -- Common consumables
    health_potion = {
        name = "Health Potion",
        description = "Restores 10 health when consumed.",
        type = "consumable",
        rarity = "common",
        consumable = true,
        useEffect = function(unit, game)
            local healAmount = 10
            if game.combatSystem then
                game.combatSystem:applyHealing(unit, healAmount, {
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
        maxStack = 5,
        value = 5
    },
    strength_elixir = {
        name = "Strength Elixir",
        description = "Temporarily increases attack power by 2 for 3 turns.",
        type = "consumable",
        rarity = "common",
        consumable = true,
        useEffect = function(unit, game)
            local attackBoost = 2
            unit.originalAttack = unit.stats.attack
            unit.stats.attack = unit.stats.attack + attackBoost
            
            -- Register temporary effect
            if game.turnManager then
                game.turnManager:registerUnitStatusEffect(unit, "strengthElixir", {
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
        end,
        stackable = true,
        maxStack = 3,
        value = 8
    },
    
    -- Uncommon consumables
    greater_health_potion = {
        name = "Greater Health Potion",
        description = "Restores 25 health when consumed.",
        type = "consumable",
        rarity = "uncommon",
        consumable = true,
        useEffect = function(unit, game)
            local healAmount = 25
            if game.combatSystem then
                game.combatSystem:applyHealing(unit, healAmount, {
                    source = "item",
                    effect = "Greater Health Potion"
                })
                return true
            else
                unit.stats.health = math.min(unit.stats.maxHealth, unit.stats.health + healAmount)
                return true
            end
        end,
        stackable = true,
        maxStack = 3,
        value = 15
    },
    shield_potion = {
        name = "Shield Potion",
        description = "Temporarily increases defense by 3 for 3 turns.",
        type = "consumable",
        rarity = "uncommon",
        consumable = true,
        useEffect = function(unit, game)
            local defenseBoost = 3
            unit.originalDefense = unit.stats.defense
            unit.stats.defense = unit.stats.defense + defenseBoost
            
            -- Register temporary effect
            if game.turnManager then
                game.turnManager:registerUnitStatusEffect(unit, "shieldPotion", {
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
        end,
        stackable = true,
        maxStack = 3,
        value = 18
    },
    
    -- Rare consumables
    cleansing_tonic = {
        name = "Cleansing Tonic",
        description = "Removes all negative status effects.",
        type = "consumable",
        rarity = "rare",
        consumable = true,
        useEffect = function(unit, game)
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
        end,
        stackable = true,
        maxStack = 2,
        value = 30
    },
    speed_draught = {
        name = "Speed Draught",
        description = "Temporarily increases movement range by 2 for 3 turns.",
        type = "consumable",
        rarity = "rare",
        consumable = true,
        useEffect = function(unit, game)
            local moveBoost = 2
            unit.originalMoveRange = unit.stats.moveRange
            unit.stats.moveRange = unit.stats.moveRange + moveBoost
            
            -- Register temporary effect
            if game.turnManager then
                game.turnManager:registerUnitStatusEffect(unit, "speedDraught", {
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
        end,
        stackable = true,
        maxStack = 2,
        value = 35
    },
    
    -- Epic consumables
    elixir_of_life = {
        name = "Elixir of Life",
        description = "Fully restores health and removes all negative status effects.",
        type = "consumable",
        rarity = "epic",
        consumable = true,
        useEffect = function(unit, game)
            -- Restore full health
            local healAmount = unit.stats.maxHealth - unit.stats.health
            unit.stats.health = unit.stats.maxHealth
            
            -- Remove negative status effects
            if unit.statusEffects then
                for id, effect in pairs(unit.statusEffects) do
                    -- Only remove negative effects
                    if effect.name == "Burning" or effect.name == "Stunned" or 
                       effect.name == "Weakened" or effect.name == "Slowed" then
                        
                        if effect.onRemove then
                            effect.onRemove(unit)
                        end
                        
                        unit.statusEffects[id] = nil
                    end
                end
            end
            
            return true
        end,
        stackable = false,
        charges = 2,
        value = 75
    },
    battle_stimulant = {
        name = "Battle Stimulant",
        description = "Temporarily increases all combat stats for 3 turns.",
        type = "consumable",
        rarity = "epic",
        consumable = true,
        useEffect = function(unit, game)
            -- Store original stats
            unit.originalStats = {
                attack = unit.stats.attack,
                defense = unit.stats.defense,
                moveRange = unit.stats.moveRange,
                initiative = unit.stats.initiative
            }
            
            -- Enhance stats
            unit.stats.attack = unit.stats.attack + 3
            unit.stats.defense = unit.stats.defense + 3
            unit.stats.moveRange = unit.stats.moveRange + 1
            unit.stats.initiative = unit.stats.initiative + 2
            
            -- Register temporary effect
            if game.turnManager then
                game.turnManager:registerUnitStatusEffect(unit, "battleStimulant", {
                    name = "Combat Enhancement",
                    description = "All combat stats increased",
                    duration = 3,
                    triggerOn = "turnStart",
                    onRemove = function(unit)
                        if unit.originalStats then
                            unit.stats.attack = unit.originalStats.attack
                            unit.stats.defense = unit.originalStats.defense
                            unit.stats.moveRange = unit.originalStats.moveRange
                            unit.stats.initiative = unit.originalStats.initiative
                            unit.originalStats = nil
                        end
                    end
                })
            end
            
            return true
        end,
        stackable = false,
        charges = 1,
        value = 80
    },
    
    -- Legendary consumables
    phoenix_feather = {
        name = "Phoenix Feather",
        description = "Revives a defeated unit with 50% health.",
        type = "consumable",
        rarity = "legendary",
        consumable = true,
        useEffect = function(unit, game)
            -- This would be used on a defeated unit, so implementation would depend on game mechanics
            -- For now, just heal to 50% if near death
            if unit.stats.health < unit.stats.maxHealth * 0.1 then
                unit.stats.health = math.floor(unit.stats.maxHealth * 0.5)
                return true
            end
            return false
        end,
        stackable = false,
        charges = 1,
        unique = true,
        value = 150
    },
    ambrosia = {
        name = "Ambrosia",
        description = "Permanently increases all stats.",
        type = "consumable",
        rarity = "legendary",
        consumable = true,
        useEffect = function(unit, game)
            -- Permanently enhance stats
            unit.stats.attack = unit.stats.attack + 2
            unit.stats.defense = unit.stats.defense + 2
            unit.stats.moveRange = unit.stats.moveRange + 1
            unit.stats.maxHealth = unit.stats.maxHealth + 15
            unit.stats.health = unit.stats.health + 15
            unit.stats.initiative = unit.stats.initiative + 1
            
            return true
        end,
        stackable = false,
        unique = true,
        value = 200
    }
}

-- Key items
ItemDatabase.keyItems = {
    dungeon_key = {
        name = "Dungeon Key",
        description = "A key that unlocks dungeon doors.",
        type = "key",
        rarity = "uncommon",
        questItem = true,
        value = 0
    },
    ancient_relic = {
        name = "Ancient Relic",
        description = "A mysterious relic with unknown powers.",
        type = "key",
        rarity = "epic",
        questItem = true,
        value = 0
    },
    royal_seal = {
        name = "Royal Seal",
        description = "A seal bearing the royal crest, granting access to restricted areas.",
        type = "key",
        rarity = "rare",
        questItem = true,
        value = 0
    }
}

-- Get all items in a flat table
function ItemDatabase.getAllItems()
    local allItems = {}
    
    -- Add all weapons
    for id, weapon in pairs(ItemDatabase.weapons) do
        allItems[id] = weapon
    end
    
    -- Add all armor
    for id, armor in pairs(ItemDatabase.armor) do
        allItems[id] = armor
    end
    
    -- Add all accessories
    for id, accessory in pairs(ItemDatabase.accessories) do
        allItems[id] = accessory
    end
    
    -- Add all consumables
    for id, consumable in pairs(ItemDatabase.consumables) do
        allItems[id] = consumable
    end
    
    -- Add all key items
    for id, keyItem in pairs(ItemDatabase.keyItems) do
        allItems[id] = keyItem
    end
    
    return allItems
end

-- Get random item by type and level
function ItemDatabase.getRandomItem(level, itemType, rarity)
    level = level or 1
    rarity = rarity or "common" -- Default rarity if none specified
    
    -- Determine item type if not specified
    if not itemType then
        local types = {"weapon", "armor", "accessory", "consumable"}
        itemType = types[math.random(#types)]
    end
    
    -- Get items of the specified type
    local items = {}
    if itemType == "weapon" then
        items = ItemDatabase.weapons
    elseif itemType == "armor" then
        items = ItemDatabase.armor
    elseif itemType == "accessory" then
        items = ItemDatabase.accessories
    elseif itemType == "consumable" then
        items = ItemDatabase.consumables
    elseif itemType == "key" then
        items = ItemDatabase.keyItems
    end
    
    -- Filter by rarity based on level
    local validItems = {}
    for id, item in pairs(items) do
        local include = false
        
        -- If specific rarity is requested, filter by that
        if rarity ~= "common" then
            include = (item.rarity == rarity)
        else
            -- Otherwise filter by level as before
            if level <= 1 and item.rarity == "common" then
                include = true
            elseif level <= 2 and (item.rarity == "common" or item.rarity == "uncommon") then
                include = true
            elseif level <= 3 and (item.rarity == "common" or item.rarity == "uncommon" or item.rarity == "rare") then
                include = true
            elseif level <= 4 then
                include = item.rarity ~= "legendary"
            else
                include = true
            end
        end
        
        -- Don't include unique items that should be special finds
        if item.unique then
            include = false
        end
        
        if include then
            validItems[id] = item
        end
    end
    
    -- Select a random item
    local count = 0
    local selectedItem = nil
    
    for id, item in pairs(validItems) do
        count = count + 1
        if math.random() < (1 / count) then
            selectedItem = {id = id, data = item}
        end
    end
    
    return selectedItem
end

return ItemDatabase
