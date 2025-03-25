-- Experience and Leveling System for Nightfall Chess
-- Handles unit progression, experience gain, level ups, and stat improvements

local class = require("lib.middleclass.middleclass")

local ExperienceSystem = class("ExperienceSystem")

function ExperienceSystem:initialize(game)
    self.game = game
    
    -- Experience configuration
    self.config = {
        -- Base experience needed for each level
        baseExpPerLevel = 100,
        
        -- Experience growth factor per level
        expGrowthFactor = 1.5,
        
        -- Maximum level
        maxLevel = 10,
        
        -- Experience rewards
        expRewards = {
            -- Experience for defeating enemies based on their type
            enemyDefeat = {
                pawn = 25,
                knight = 50,
                bishop = 50,
                rook = 75,
                queen = 100,
                king = 150
            },
            
            -- Experience for completing objectives
            objectives = {
                roomClear = 50,
                bossDefeat = 200,
                treasureFound = 25,
                puzzleSolved = 40
            }
        },
        
        -- Stat growth per level for each unit type
        statGrowth = {
            king = {
                health = 5,
                attack = 1,
                defense = 1,
                energy = 2
            },
            rook = {
                health = 8,
                attack = 2,
                defense = 2,
                energy = 1
            },
            bishop = {
                health = 4,
                attack = 2,
                defense = 0,
                energy = 3
            },
            knight = {
                health = 6,
                attack = 2,
                defense = 1,
                energy = 2
            },
            pawn = {
                health = 5,
                attack = 1,
                defense = 1,
                energy = 1
            },
            queen = {
                health = 5,
                attack = 3,
                defense = 1,
                energy = 2
            }
        },
        
        -- Special level milestones that grant additional bonuses
        levelMilestones = {
            [3] = "Unlock second special ability",
            [5] = "Stat boost and ability upgrade",
            [7] = "Unlock third special ability",
            [10] = "Master level - all abilities enhanced"
        }
    }
end

-- Calculate experience required for a specific level
function ExperienceSystem:getExpRequiredForLevel(level)
    if level <= 1 then
        return 0
    end
    
    return math.floor(self.config.baseExpPerLevel * (level - 1) * self.config.expGrowthFactor^(level - 2))
end

-- Initialize experience for a new unit
function ExperienceSystem:initializeUnit(unit)
    unit.level = unit.level or 1
    unit.experience = unit.experience or 0
    unit.totalExperience = unit.totalExperience or 0
    unit.nextLevelExp = self:getExpRequiredForLevel(unit.level + 1)
    
    -- Store base stats for reference
    unit.baseStats = {
        health = unit.stats.health,
        maxHealth = unit.stats.maxHealth,
        attack = unit.stats.attack,
        defense = unit.stats.defense,
        energy = unit.stats.energy,
        maxEnergy = unit.stats.maxEnergy,
        moveRange = unit.stats.moveRange,
        attackRange = unit.stats.attackRange
    }
    
    -- Initialize skill points if not already set
    unit.skillPoints = unit.skillPoints or 0
    
    -- Initialize skill trees based on unit type
    self:initializeSkillTree(unit)
    
    return unit
end

-- Initialize skill tree for a unit based on its type
function ExperienceSystem:initializeSkillTree(unit)
    unit.skillTree = unit.skillTree or {}
    
    if unit.unitType == "king" then
        unit.skillTree = {
            leadership = {
                name = "Leadership",
                description = "Enhances command abilities and team support",
                level = 0,
                maxLevel = 5,
                effects = {
                    "Tactical Command grants +1 action point",
                    "Royal Guard affects units 2 tiles away",
                    "Inspiring Presence lasts 1 additional turn",
                    "Tactical Command cooldown reduced by 1",
                    "All command abilities cost 1 less energy"
                }
            },
            combat = {
                name = "Combat",
                description = "Improves personal combat capabilities",
                level = 0,
                maxLevel = 5,
                effects = {
                    "+2 Attack",
                    "+10 Health",
                    "+2 Defense",
                    "Critical hit chance +10%",
                    "Can attack twice per turn"
                }
            },
            tactics = {
                name = "Tactics",
                description = "Enhances strategic options",
                level = 0,
                maxLevel = 5,
                effects = {
                    "+1 Movement range",
                    "Can move through allies",
                    "Gain 1 action point when an ally defeats an enemy",
                    "Nearby allies gain +1 defense",
                    "Can swap positions with any ally once per turn"
                }
            }
        }
    elseif unit.unitType == "rook" then
        unit.skillTree = {
            fortress = {
                name = "Fortress",
                description = "Enhances defensive capabilities",
                level = 0,
                maxLevel = 5,
                effects = {
                    "+3 Defense",
                    "Fortify lasts 1 additional turn",
                    "Stone Skin grants 50% damage reduction",
                    "Regenerate 2 health per turn",
                    "Immune to critical hits"
                }
            },
            demolition = {
                name = "Demolition",
                description = "Improves offensive power",
                level = 0,
                maxLevel = 5,
                effects = {
                    "+3 Attack",
                    "Shockwave range +1",
                    "Attacks have 20% chance to stun",
                    "Shockwave cooldown reduced by 1",
                    "Attacks damage adjacent enemies for 50% damage"
                }
            },
            guardian = {
                name = "Guardian",
                description = "Enhances protection of allies",
                level = 0,
                maxLevel = 5,
                effects = {
                    "Adjacent allies take 20% less damage",
                    "Can intercept attacks targeting adjacent allies",
                    "Gain 1 energy when an ally is attacked",
                    "Stone Skin can be cast on allies",
                    "When health drops below 25%, gain temporary invulnerability"
                }
            }
        }
    elseif unit.unitType == "bishop" then
        unit.skillTree = {
            healing = {
                name = "Healing",
                description = "Enhances healing capabilities",
                level = 0,
                maxLevel = 5,
                effects = {
                    "Healing Light heals +3 health",
                    "Healing Light affects adjacent allies",
                    "Gain passive healing aura (1 HP/turn to allies)",
                    "Healing Light removes negative status effects",
                    "Resurrect defeated ally with 50% health (once per battle)"
                }
            },
            arcane = {
                name = "Arcane",
                description = "Improves magical attacks",
                level = 0,
                maxLevel = 5,
                effects = {
                    "+3 Attack",
                    "Arcane Bolt range +1",
                    "Arcane Bolt can hit multiple enemies",
                    "Arcane Bolt has 25% chance to apply random status effect",
                    "Unlock Arcane Nova - damages all enemies within 2 tiles"
                }
            },
            protection = {
                name = "Protection",
                description = "Enhances defensive magic",
                level = 0,
                maxLevel = 5,
                effects = {
                    "Mystic Barrier blocks 2 attacks",
                    "Mystic Barrier reflects 50% damage back to attacker",
                    "Gain +2 defense for each active barrier",
                    "Mystic Barrier cooldown reduced by 1",
                    "When casting protective spells, gain a barrier yourself"
                }
            }
        }
    elseif unit.unitType == "pawn" then
        unit.skillTree = {
            vanguard = {
                name = "Vanguard",
                description = "Enhances frontline capabilities",
                level = 0,
                maxLevel = 5,
                effects = {
                    "+2 Defense",
                    "Shield Bash stuns for 1 additional turn",
                    "Gain +1 defense for each adjacent ally",
                    "Shield Bash cooldown reduced by 1",
                    "Adjacent allies gain +1 attack"
                }
            },
            assault = {
                name = "Assault",
                description = "Improves offensive capabilities",
                level = 0,
                maxLevel = 5,
                effects = {
                    "+2 Attack",
                    "Advance deals +50% damage",
                    "Can move diagonally",
                    "Gain +1 attack for each tile moved before attacking",
                    "Critical hit chance +15%"
                }
            },
            promotion = {
                name = "Promotion",
                description = "Enhances promotion ability",
                level = 0,
                maxLevel = 5,
                effects = {
                    "Promotion costs 1 less energy",
                    "Gain +2 to all stats after promotion",
                    "Can promote after defeating 3 enemies (anywhere on board)",
                    "Temporary promotion lasts 3 turns (without reaching opposite side)",
                    "Can promote to any piece type regardless of position"
                }
            }
        }
    elseif unit.unitType == "queen" then
        unit.skillTree = {
            sovereignty = {
                name = "Sovereignty",
                description = "Enhances command and control",
                level = 0,
                maxLevel = 5,
                effects = {
                    "Royal Decree grants +2 action points",
                    "Strategic Repositioning range increased to entire board",
                    "Royal Decree affects allies for 2 turns",
                    "Allies affected by Royal Decree gain +1 attack",
                    "Can use Royal Decree twice per battle"
                }
            },
            destruction = {
                name = "Destruction",
                description = "Improves offensive power",
                level = 0,
                maxLevel = 5,
                effects = {
                    "+4 Attack",
                    "Sovereign's Wrath damage +50%",
                    "Sovereign's Wrath applies burning status",
                    "Attack range +1",
                    "Sovereign's Wrath cooldown reduced by 1"
                }
            },
            mobility = {
                name = "Mobility",
                description = "Enhances movement capabilities",
                level = 0,
                maxLevel = 5,
                effects = {
                    "+1 Movement range",
                    "Strategic Repositioning costs 1 less energy",
                    "Gain 1 action point after using Strategic Repositioning",
                    "Can move through enemies (dealing 2 damage)",
                    "After moving, gain +1 attack until end of turn"
                }
            }
        }
    elseif unit.unitType == "knight" then
        unit.skillTree = {
            mobility = {
                name = "Mobility",
                description = "Enhances movement capabilities",
                level = 0,
                maxLevel = 5,
                effects = {
                    "+1 Movement range",
                    "Knight's Charge cooldown reduced by 1",
                    "Can move through obstacles and units",
                    "Gain +1 attack for each tile moved",
                    "Can perform two Knight's Charges per turn"
                }
            },
            ambush = {
                name = "Ambush",
                description = "Improves flanking and surprise attacks",
                level = 0,
                maxLevel = 5,
                effects = {
                    "+25% damage when attacking from behind",
                    "Feint applies confused for 1 additional turn",
                    "Gain invisibility for 1 turn after defeating an enemy",
                    "Critical hit chance +20% against isolated enemies",
                    "First attack each battle is guaranteed critical"
                }
            },
            duelist = {
                name = "Duelist",
                description = "Enhances one-on-one combat",
                level = 0,
                maxLevel = 5,
                effects = {
                    "+3 Attack",
                    "+10% damage for each adjacent enemy",
                    "20% chance to counterattack",
                    "Gain 1 energy when successfully dodging an attack",
                    "When attacking a single isolated enemy, deal double damage"
                }
            }
        }
    end
end

-- Award experience to a unit
function ExperienceSystem:awardExperience(unit, amount, source)
    if not unit or unit.level >= self.config.maxLevel then
        return false
    end
    
    -- Add experience
    unit.experience = unit.experience + amount
    unit.totalExperience = unit.totalExperience + amount
    
    -- Check for level up
    local leveledUp = false
    while unit.experience >= unit.nextLevelExp and unit.level < self.config.maxLevel do
        leveledUp = true
        self:levelUp(unit)
    end
    
    -- Visual feedback
    if self.game.ui then
        if source then
            self.game.ui:showNotification(unit.unitType:upper() .. " gained " .. amount .. " XP from " .. source .. "!", 1.5)
        else
            self.game.ui:showNotification(unit.unitType:upper() .. " gained " .. amount .. " XP!", 1.5)
        end
        
        if leveledUp then
            self.game.ui:showNotification(unit.unitType:upper() .. " reached level " .. unit.level .. "!", 2)
        end
    end
    
    return leveledUp
end

-- Level up a unit
function ExperienceSystem:levelUp(unit)
    -- Increment level
    unit.level = unit.level + 1
    
    -- Reset experience for next level
    unit.experience = unit.experience - unit.nextLevelExp
    unit.nextLevelExp = self:getExpRequiredForLevel(unit.level + 1)
    
    -- Increase stats based on unit type
    local growth = self.config.statGrowth[unit.unitType]
    if growth then
        unit.stats.health = unit.stats.health + growth.health
        unit.stats.maxHealth = unit.stats.maxHealth + growth.health
        unit.stats.attack = unit.stats.attack + growth.attack
        unit.stats.defense = unit.stats.defense + growth.defense
        unit.stats.energy = unit.stats.energy + growth.energy
        unit.stats.maxEnergy = unit.stats.maxEnergy + growth.energy
    end
    
    -- Award skill point
    unit.skillPoints = unit.skillPoints + 1
    
    -- Check for level milestones
    if self.config.levelMilestones[unit.level] then
        self:applyLevelMilestone(unit, unit.level)
    end
    
    -- Heal unit partially on level up
    unit.stats.health = math.min(unit.stats.maxHealth, unit.stats.health + math.floor(unit.stats.maxHealth * 0.3))
    
    -- Restore some energy on level up
    unit.stats.energy = math.min(unit.stats.maxEnergy, unit.stats.energy + math.floor(unit.stats.maxEnergy * 0.5))
    
    -- Visual effects for level up
    if self.game.ui then
        self.game.ui:showLevelUpAnimation(unit)
    end
    
    return true
end

-- Apply special bonuses for reaching level milestones
function ExperienceSystem:applyLevelMilestone(unit, level)
    if level == 3 then
        -- Unlock second special ability
        if unit.unitType == "king" then
            unit.unlockedAbilities = unit.unlockedAbilities or {}
            unit.unlockedAbilities.inspiring_presence = true
        elseif unit.unitType == "rook" then
            unit.unlockedAbilities = unit.unlockedAbilities or {}
            unit.unlockedAbilities.stone_skin = true
        elseif unit.unitType == "bishop" then
            unit.unlockedAbilities = unit.unlockedAbilities or {}
            unit.unlockedAbilities.mystic_barrier = true
        elseif unit.unitType == "pawn" then
            unit.unlockedAbilities = unit.unlockedAbilities or {}
            unit.unlockedAbilities.advance = true
        elseif unit.unitType == "queen" then
            unit.unlockedAbilities = unit.unlockedAbilities or {}
            unit.unlockedAbilities.strategic_repositioning = true
        elseif unit.unitType == "knight" then
            unit.unlockedAbilities = unit.unlockedAbilities or {}
            unit.unlockedAbilities.feint = true
        end
    elseif level == 5 then
        -- Stat boost and ability upgrade
        unit.stats.attack = unit.stats.attack + 2
        unit.stats.defense = unit.stats.defense + 2
        unit.stats.maxHealth = unit.stats.maxHealth + 10
        unit.stats.health = unit.stats.health + 10
        unit.stats.maxEnergy = unit.stats.maxEnergy + 5
        unit.stats.energy = unit.stats.energy + 5
        
        -- Ability upgrades depend on unit type
        if unit.unitType == "king" then
            -- Reduce cooldowns
            unit.abilityCooldownReduction = (unit.abilityCooldownReduction or 0) + 1
        elseif unit.unitType == "rook" then
            -- Increase ability damage
            unit.abilityDamageBonus = (unit.abilityDamageBonus or 0) + 0.2
        elseif unit.unitType == "bishop" then
            -- Increase healing power
            unit.healingBonus = (unit.healingBonus or 0) + 0.3
        elseif unit.unitType == "pawn" then
            -- Increase ability range
            unit.abilityRangeBonus = (unit.abilityRangeBonus or 0) + 1
        elseif unit.unitType == "queen" then
            -- Reduce energy costs
            unit.energyCostReduction = (unit.energyCostReduction or 0) + 1
        elseif unit.unitType == "knight" then
            -- Increase critical hit chance
            unit.criticalHitBonus = (unit.criticalHitBonus or 0) + 0.15
        end
    elseif level == 7 then
        -- Unlock third special ability or enhance existing ones
        if unit.unitType == "king" then
            -- New ability: Royal Inspiration
            unit.unlockedAbilities = unit.unlockedAbilities or {}
            unit.unlockedAbilities.royal_inspiration = true
        elseif unit.unitType == "rook" then
            -- New ability: Earthquake
            unit.unlockedAbilities = unit.unlockedAbilities or {}
            unit.unlockedAbilities.earthquake = true
        elseif unit.unitType == "bishop" then
            -- New ability: Divine Intervention
            unit.unlockedAbilities = unit.unlockedAbilities or {}
            unit.unlockedAbilities.divine_intervention = true
        elseif unit.unitType == "pawn" then
            -- New ability: Phalanx Formation
            unit.unlockedAbilities = unit.unlockedAbilities or {}
            unit.unlockedAbilities.phalanx_formation = true
        elseif unit.unitType == "queen" then
            -- New ability: Checkmate
            unit.unlockedAbilities = unit.unlockedAbilities or {}
            unit.unlockedAbilities.checkmate = true
        elseif unit.unitType == "knight" then
            -- New ability: Blitz
            unit.unlockedAbilities = unit.unlockedAbilities or {}
            unit.unlockedAbilities.blitz = true
        end
    elseif level == 10 then
        -- Master level - all abilities enhanced
        -- Significant stat boost
        unit.stats.attack = unit.stats.attack + 5
        unit.stats.defense = unit.stats.defense + 5
        unit.stats.maxHealth = unit.stats.maxHealth + 25
        unit.stats.health = unit.stats.health + 25
        unit.stats.maxEnergy = unit.stats.maxEnergy + 10
        unit.stats.energy = unit.stats.energy + 10
        unit.stats.moveRange = unit.stats.moveRange + 1
        
        -- All abilities enhanced
        unit.masterLevel = true
        
        -- Special master ability based on unit type
        if unit.unitType == "king" then
            -- Master ability: Supreme Command
            unit.unlockedAbilities = unit.unlockedAbilities or {}
            unit.unlockedAbilities.supreme_command = true
        elseif unit.unitType == "rook" then
            -- Master ability: Impenetrable Fortress
            unit.unlockedAbilities = unit.unlockedAbilities or {}
            unit.unlockedAbilities.impenetrable_fortress = true
        elseif unit.unitType == "bishop" then
            -- Master ability: Miracle
            unit.unlockedAbilities = unit.unlockedAbilities or {}
            unit.unlockedAbilities.miracle = true
        elseif unit.unitType == "pawn" then
            -- Master ability: Heroic Sacrifice
            unit.unlockedAbilities = unit.unlockedAbilities or {}
            unit.unlockedAbilities.heroic_sacrifice = true
        elseif unit.unitType == "queen" then
            -- Master ability: Absolute Dominion
            unit.unlockedAbilities = unit.unlockedAbilities or {}
            unit.unlockedAbilities.absolute_dominion = true
        elseif unit.unitType == "knight" then
            -- Master ability: Perfect Strike
            unit.unlockedAbilities = unit.unlockedAbilities or {}
            unit.unlockedAbilities.perfect_strike = true
        end
    end
    
    -- Visual feedback
    if self.game.ui then
        self.game.ui:showNotification("Level " .. level .. " milestone reached: " .. self.config.levelMilestones[level], 2)
    end
end

-- Spend skill points to improve a skill tree
function ExperienceSystem:improveSkill(unit, skillTreeName)
    if not unit or not unit.skillTree or not unit.skillTree[skillTreeName] then
        return false, "Invalid skill tree"
    end
    
    local skillTree = unit.skillTree[skillTreeName]
    
    -- Check if skill is already maxed
    if skillTree.level >= skillTree.maxLevel then
        return false, "Skill already at maximum level"
    end
    
    -- Check if unit has skill points
    if unit.skillPoints <= 0 then
        return false, "Not enough skill points"
    end
    
    -- Improve skill
    skillTree.level = skillTree.level + 1
    unit.skillPoints = unit.skillPoints - 1
    
    -- Apply skill effect
    self:applySkillEffect(unit, skillTreeName, skillTree.level)
    
    -- Visual feedback
    if self.game.ui then
        self.game.ui:showNotification(unit.unitType:upper() .. " improved " .. skillTree.name .. " to level " .. skillTree.level .. "!", 2)
        self.game.ui:showNotification("Effect: " .. skillTree.effects[skillTree.level], 2)
    end
    
    return true
end

-- Apply the effect of a skill level
function ExperienceSystem:applySkillEffect(unit, skillTreeName, level)
    local effect = unit.skillTree[skillTreeName].effects[level]
    
    -- Parse and apply the effect
    -- This would be a complex implementation in a real game
    -- For now, we'll just store the effects and assume they're applied elsewhere
    
    unit.appliedSkillEffects = unit.appliedSkillEffects or {}
    table.insert(unit.appliedSkillEffects, {
        skillTree = skillTreeName,
        level = level,
        effect = effect
    })
    
    -- Apply some basic effects that we can handle directly
    if effect:find("+%d+ Attack") then
        local bonus = tonumber(effect:match("+(%d+) Attack"))
        unit.stats.attack = unit.stats.attack + bonus
    elseif effect:find("+%d+ Defense") then
        local bonus = tonumber(effect:match("+(%d+) Defense"))
        unit.stats.defense = unit.stats.defense + bonus
    elseif effect:find("+%d+ Health") then
        local bonus = tonumber(effect:match("+(%d+) Health"))
        unit.stats.maxHealth = unit.stats.maxHealth + bonus
        unit.stats.health = unit.stats.health + bonus
    elseif effect:find("+%d+ Movement range") then
        local bonus = tonumber(effect:match("+(%d+) Movement range"))
        unit.stats.moveRange = unit.stats.moveRange + bonus
    end
    
    return true
end

-- Calculate experience reward for defeating an enemy
function ExperienceSystem:calculateEnemyDefeatExp(enemyUnit)
    local baseExp = self.config.expRewards.enemyDefeat[enemyUnit.unitType] or 25
    
    -- Scale based on enemy level
    local levelFactor = enemyUnit.level or 1
    
    -- Scale based on difficulty (if applicable)
    local difficultyFactor = 1
    if self.game.difficulty then
        if self.game.difficulty == "easy" then
            difficultyFactor = 1.2
        elseif self.game.difficulty == "hard" then
            difficultyFactor = 0.8
        end
    end
    
    return math.floor(baseExp * levelFactor * difficultyFactor)
end

-- Award experience for defeating an enemy
function ExperienceSystem:awardDefeatExperience(attacker, defeated)
    if not attacker or not defeated then
        return
    end
    
    -- Calculate experience
    local expAmount = self:calculateEnemyDefeatExp(defeated)
    
    -- Award experience to the attacker
    self:awardExperience(attacker, expAmount, "defeating " .. defeated.unitType)
    
    -- Award some experience to nearby allies (if they exist)
    local nearbyAllies = self:getNearbyAllies(attacker, 2)
    for _, ally in ipairs(nearbyAllies) do
        -- Nearby allies get 50% of the experience
        self:awardExperience(ally, math.floor(expAmount * 0.5), "assist")
    end
end

-- Award experience for completing an objective
function ExperienceSystem:awardObjectiveExperience(unit, objectiveType)
    if not unit or not objectiveType then
        return
    end
    
    local expAmount = self.config.expRewards.objectives[objectiveType] or 0
    
    if expAmount > 0 then
        self:awardExperience(unit, expAmount, "completing " .. objectiveType)
    end
end

-- Get nearby allies within a certain range
function ExperienceSystem:getNearbyAllies(unit, range)
    local allies = {}
    
    -- This would use the grid system to find nearby allies
    -- For now, we'll just return an empty list
    
    return allies
end

-- Get experience progress as a percentage
function ExperienceSystem:getExpProgressPercentage(unit)
    if unit.level >= self.config.maxLevel then
        return 100
    end
    
    return math.floor((unit.experience / unit.nextLevelExp) * 100)
end

-- Get total stats gained from leveling
function ExperienceSystem:getStatsGainedFromLeveling(unit)
    local gains = {
        health = 0,
        attack = 0,
        defense = 0,
        energy = 0,
        moveRange = 0,
        attackRange = 0
    }
    
    if not unit.baseStats then
        return gains
    end
    
    gains.health = unit.stats.maxHealth - unit.baseStats.maxHealth
    gains.attack = unit.stats.attack - unit.baseStats.attack
    gains.defense = unit.stats.defense - unit.baseStats.defense
    gains.energy = unit.stats.maxEnergy - unit.baseStats.maxEnergy
    gains.moveRange = unit.stats.moveRange - unit.baseStats.moveRange
    gains.attackRange = unit.stats.attackRange - unit.baseStats.attackRange
    
    return gains
end

-- Reset a unit's level and stats (for testing)
function ExperienceSystem:resetUnit(unit)
    if not unit or not unit.baseStats then
        return false
    end
    
    unit.level = 1
    unit.experience = 0
    unit.totalExperience = 0
    unit.nextLevelExp = self:getExpRequiredForLevel(2)
    unit.skillPoints = 0
    
    -- Reset stats to base values
    unit.stats.health = unit.baseStats.health
    unit.stats.maxHealth = unit.baseStats.maxHealth
    unit.stats.attack = unit.baseStats.attack
    unit.stats.defense = unit.baseStats.defense
    unit.stats.energy = unit.baseStats.energy
    unit.stats.maxEnergy = unit.baseStats.maxEnergy
    unit.stats.moveRange = unit.baseStats.moveRange
    unit.stats.attackRange = unit.baseStats.attackRange
    
    -- Reset skill trees
    self:initializeSkillTree(unit)
    
    -- Reset unlocked abilities
    unit.unlockedAbilities = {}
    
    -- Reset applied skill effects
    unit.appliedSkillEffects = {}
    
    -- Reset special bonuses
    unit.abilityCooldownReduction = 0
    unit.abilityDamageBonus = 0
    unit.healingBonus = 0
    unit.abilityRangeBonus = 0
    unit.energyCostReduction = 0
    unit.criticalHitBonus = 0
    unit.masterLevel = false
    
    return true
end

-- Save experience data for a unit
function ExperienceSystem:saveUnitExpData(unit)
    if not unit then
        return nil
    end
    
    local data = {
        level = unit.level,
        experience = unit.experience,
        totalExperience = unit.totalExperience,
        nextLevelExp = unit.nextLevelExp,
        skillPoints = unit.skillPoints,
        skillTree = unit.skillTree,
        unlockedAbilities = unit.unlockedAbilities,
        appliedSkillEffects = unit.appliedSkillEffects,
        abilityCooldownReduction = unit.abilityCooldownReduction,
        abilityDamageBonus = unit.abilityDamageBonus,
        healingBonus = unit.healingBonus,
        abilityRangeBonus = unit.abilityRangeBonus,
        energyCostReduction = unit.energyCostReduction,
        criticalHitBonus = unit.criticalHitBonus,
        masterLevel = unit.masterLevel
    }
    
    return data
end

-- Load experience data for a unit
function ExperienceSystem:loadUnitExpData(unit, data)
    if not unit or not data then
        return false
    end
    
    unit.level = data.level or 1
    unit.experience = data.experience or 0
    unit.totalExperience = data.totalExperience or 0
    unit.nextLevelExp = data.nextLevelExp or self:getExpRequiredForLevel(unit.level + 1)
    unit.skillPoints = data.skillPoints or 0
    unit.skillTree = data.skillTree or {}
    unit.unlockedAbilities = data.unlockedAbilities or {}
    unit.appliedSkillEffects = data.appliedSkillEffects or {}
    unit.abilityCooldownReduction = data.abilityCooldownReduction or 0
    unit.abilityDamageBonus = data.abilityDamageBonus or 0
    unit.healingBonus = data.healingBonus or 0
    unit.abilityRangeBonus = data.abilityRangeBonus or 0
    unit.energyCostReduction = data.energyCostReduction or 0
    unit.criticalHitBonus = data.criticalHitBonus or 0
    unit.masterLevel = data.masterLevel or false
    
    -- If skill tree is empty, initialize it
    if not next(unit.skillTree) then
        self:initializeSkillTree(unit)
    end
    
    return true
end

-- Update the experience system
function ExperienceSystem:update(dt)
    -- This would handle any time-based experience rewards or effects
    -- For now, we'll leave it empty
end

return ExperienceSystem
