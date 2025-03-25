-- Meta-Progression System for Nightfall Chess
-- Provides persistent upgrades and unlocks between game runs

local class = require("lib.middleclass.middleclass")

local MetaProgression = class("MetaProgression")

function MetaProgression:initialize()
    -- Persistent currency
    self.darkEssence = 0
    
    -- Unlockable content
    self.unlockedContent = {
        characters = {}, -- Additional playable characters
        abilities = {}, -- Special abilities
        items = {}, -- Rare items
        rooms = {}, -- Special room types
        enemies = {} -- Enemy variants
    }
    
    -- Permanent upgrades
    self.permanentUpgrades = {
        -- Starting stats
        startingHealth = 0, -- +1 health per level
        startingEnergy = 0, -- +1 energy per level
        startingGold = 0,   -- +10 gold per level
        
        -- Combat bonuses
        attackBonus = 0,    -- +1 attack per level
        defenseBonus = 0,   -- +1 defense per level
        critChance = 0,     -- +2% crit chance per level
        
        -- Resource bonuses
        healthRegen = 0,    -- +0.5 health regen per level
        energyRegen = 0,    -- +0.5 energy regen per level
        goldBonus = 0,      -- +5% gold drops per level
        
        -- Gameplay bonuses
        extraActionPoint = 0, -- +1 action point at level 3
        movementBonus = 0,    -- +1 movement range per level
        itemSlots = 0,        -- +1 item slot per level
        
        -- Special bonuses
        reviveChance = 0,     -- Chance to revive once per run
        treasureChance = 0,   -- Increased chance for treasure rooms
        eliteDropRate = 0     -- Better drops from elite enemies
    }
    
    -- Achievement tracking
    self.achievements = {
        -- Completion achievements
        completedRuns = 0,
        highestFloor = 0,
        fastestCompletion = nil,
        
        -- Combat achievements
        totalKills = 0,
        bossesDefeated = 0,
        damageDealt = 0,
        
        -- Collection achievements
        itemsCollected = 0,
        goldCollected = 0,
        abilitiesUsed = 0,
        
        -- Special achievements
        perfectRuns = 0,
        noHitRuns = 0,
        lowLevelRuns = 0
    }
    
    -- Challenge system
    self.challenges = {
        -- List of available challenges
        available = {
            {
                id = "no_items",
                name = "Ascetic",
                description = "Complete a run without using any items",
                reward = 100,
                completed = false
            },
            {
                id = "time_limit",
                name = "Speed Chess",
                description = "Complete a run in under 30 minutes",
                reward = 150,
                completed = false
            },
            {
                id = "low_health",
                name = "Glass Knight",
                description = "Complete a run with max health reduced by 50%",
                reward = 200,
                completed = false
            },
            {
                id = "solo_run",
                name = "Lone Wolf",
                description = "Complete a run with only one unit",
                reward = 250,
                completed = false
            },
            {
                id = "no_abilities",
                name = "Basic Tactics",
                description = "Complete a run without using special abilities",
                reward = 150,
                completed = false
            },
            {
                id = "elite_hunter",
                name = "Elite Hunter",
                description = "Defeat 10 elite enemies in a single run",
                reward = 100,
                completed = false
            },
            {
                id = "pacifist",
                name = "Pacifist",
                description = "Complete a floor without attacking any enemies",
                reward = 75,
                completed = false
            },
            {
                id = "treasure_hunter",
                name = "Treasure Hunter",
                description = "Find all treasure rooms in a run",
                reward = 125,
                completed = false
            }
        },
        
        -- Currently active challenges
        active = {},
        
        -- Completed challenges
        completed = {}
    }
    
    -- Unlockable characters
    self.characters = {
        {
            id = "shadow_king",
            name = "Shadow King",
            description = "A corrupted king with powerful darkness abilities",
            cost = 500,
            unlocked = false,
            abilities = {"shadow_step", "royal_execution", "darkness_descends"}
        },
        {
            id = "crystal_queen",
            name = "Crystal Queen",
            description = "A queen with crystalline powers and high defense",
            cost = 500,
            unlocked = false,
            abilities = {"crystal_shield", "shatter_strike", "diamond_dust"}
        },
        {
            id = "flame_bishop",
            name = "Flame Bishop",
            description = "A bishop infused with fire magic",
            cost = 400,
            unlocked = false,
            abilities = {"flame_burst", "healing_flames", "fire_wall"}
        },
        {
            id = "steel_rook",
            name = "Steel Rook",
            description = "A heavily armored rook with mechanical enhancements",
            cost = 400,
            unlocked = false,
            abilities = {"steam_charge", "gear_shield", "quake_slam"}
        },
        {
            id = "phantom_knight",
            name = "Phantom Knight",
            description = "A spectral knight that can phase through obstacles",
            cost = 350,
            unlocked = false,
            abilities = {"ghost_strike", "phase_shift", "soul_harvest"}
        },
        {
            id = "arcane_pawn",
            name = "Arcane Pawn",
            description = "A pawn imbued with magical energy, capable of powerful transformations",
            cost = 300,
            unlocked = false,
            abilities = {"magic_missile", "arcane_promotion", "mana_shield"}
        }
    }
    
    -- Unlockable starting items
    self.startingItems = {
        {
            id = "royal_crown",
            name = "Royal Crown",
            description = "Increases maximum health by 20%",
            cost = 200,
            unlocked = false
        },
        {
            id = "ancient_tome",
            name = "Ancient Tome",
            description = "Start with an extra ability for each unit",
            cost = 250,
            unlocked = false
        },
        {
            id = "lucky_coin",
            name = "Lucky Coin",
            description = "Increases gold drops by 15%",
            cost = 150,
            unlocked = false
        },
        {
            id = "battle_standard",
            name = "Battle Standard",
            description = "All units start with +2 attack",
            cost = 200,
            unlocked = false
        },
        {
            id = "guardian_shield",
            name = "Guardian Shield",
            description = "All units start with +2 defense",
            cost = 200,
            unlocked = false
        },
        {
            id = "mystic_orb",
            name = "Mystic Orb",
            description = "Increases energy regeneration by 1 per turn",
            cost = 175,
            unlocked = false
        },
        {
            id = "adventurer_map",
            name = "Adventurer's Map",
            description = "Reveals special rooms on each floor",
            cost = 150,
            unlocked = false
        },
        {
            id = "resurrection_charm",
            name = "Resurrection Charm",
            description = "Once per run, revive a fallen unit",
            cost = 300,
            unlocked = false
        }
    }
    
    -- Unlockable game modes
    self.gameModes = {
        {
            id = "standard",
            name = "Standard Mode",
            description = "The normal game experience",
            unlocked = true
        },
        {
            id = "endless",
            name = "Endless Mode",
            description = "Play through infinite procedurally generated floors with increasing difficulty",
            cost = 400,
            unlocked = false
        },
        {
            id = "daily_challenge",
            name = "Daily Challenge",
            description = "A unique run each day with special modifiers and leaderboards",
            cost = 300,
            unlocked = false
        },
        {
            id = "boss_rush",
            name = "Boss Rush",
            description = "Face a gauntlet of bosses with minimal preparation between fights",
            cost = 350,
            unlocked = false
        },
        {
            id = "puzzle_mode",
            name = "Puzzle Mode",
            description = "Solve chess-like puzzles with special rules and objectives",
            cost = 250,
            unlocked = false
        },
        {
            id = "arena",
            name = "Arena Mode",
            description = "Face waves of enemies in a single room with special rewards",
            cost = 300,
            unlocked = false
        }
    }
    
    -- Upgrade costs (increases with each purchase)
    self.baseCosts = {
        startingHealth = 50,
        startingEnergy = 50,
        startingGold = 30,
        attackBonus = 75,
        defenseBonus = 75,
        critChance = 60,
        healthRegen = 80,
        energyRegen = 80,
        goldBonus = 40,
        extraActionPoint = 200,
        movementBonus = 100,
        itemSlots = 90,
        reviveChance = 150,
        treasureChance = 70,
        eliteDropRate = 60
    }
    
    -- Cost multiplier per level
    self.costMultiplier = 1.5
    
    -- Max levels for each upgrade
    self.maxLevels = {
        startingHealth = 10,
        startingEnergy = 10,
        startingGold = 10,
        attackBonus = 5,
        defenseBonus = 5,
        critChance = 5,
        healthRegen = 5,
        energyRegen = 5,
        goldBonus = 10,
        extraActionPoint = 1,
        movementBonus = 3,
        itemSlots = 5,
        reviveChance = 3,
        treasureChance = 5,
        eliteDropRate = 5
    }
    
    -- Tutorial and tips system
    self.tutorials = {
        basic_movement = { completed = false, reward = 10 },
        combat = { completed = false, reward = 10 },
        abilities = { completed = false, reward = 10 },
        items = { completed = false, reward = 10 },
        status_effects = { completed = false, reward = 10 },
        boss_fights = { completed = false, reward = 20 },
        meta_progression = { completed = false, reward = 20 }
    }
    
    -- Run history
    self.runHistory = {}
    
    -- Load saved data if available
    self:loadProgress()
end

-- Add dark essence (meta currency)
function MetaProgression:addDarkEssence(amount)
    self.darkEssence = self.darkEssence + amount
    self:saveProgress()
    return self.darkEssence
end

-- Spend dark essence
function MetaProgression:spendDarkEssence(amount)
    if self.darkEssence >= amount then
        self.darkEssence = self.darkEssence - amount
        self:saveProgress()
        return true
    end
    return false
end

-- Get current dark essence
function MetaProgression:getDarkEssence()
    return self.darkEssence
end

-- Purchase a permanent upgrade
function MetaProgression:purchaseUpgrade(upgradeType)
    -- Check if upgrade exists
    if not self.permanentUpgrades[upgradeType] then
        return false, "Invalid upgrade type"
    end
    
    -- Check if upgrade is at max level
    local currentLevel = self.permanentUpgrades[upgradeType]
    if currentLevel >= self.maxLevels[upgradeType] then
        return false, "Upgrade already at maximum level"
    end
    
    -- Calculate cost
    local baseCost = self.baseCosts[upgradeType]
    local cost = math.floor(baseCost * (self.costMultiplier ^ currentLevel))
    
    -- Check if player has enough currency
    if self.darkEssence < cost then
        return false, "Not enough dark essence"
    end
    
    -- Purchase upgrade
    self:spendDarkEssence(cost)
    self.permanentUpgrades[upgradeType] = currentLevel + 1
    self:saveProgress()
    
    return true, "Upgrade purchased successfully"
end

-- Get upgrade level
function MetaProgression:getUpgradeLevel(upgradeType)
    return self.permanentUpgrades[upgradeType] or 0
end

-- Get upgrade cost
function MetaProgression:getUpgradeCost(upgradeType)
    local currentLevel = self.permanentUpgrades[upgradeType] or 0
    local baseCost = self.baseCosts[upgradeType]
    return math.floor(baseCost * (self.costMultiplier ^ currentLevel))
end

-- Unlock a character
function MetaProgression:unlockCharacter(characterId)
    for i, character in ipairs(self.characters) do
        if character.id == characterId and not character.unlocked then
            if self:spendDarkEssence(character.cost) then
                self.characters[i].unlocked = true
                table.insert(self.unlockedContent.characters, characterId)
                self:saveProgress()
                return true, "Character unlocked successfully"
            else
                return false, "Not enough dark essence"
            end
        end
    end
    return false, "Character not found or already unlocked"
end

-- Unlock a starting item
function MetaProgression:unlockStartingItem(itemId)
    for i, item in ipairs(self.startingItems) do
        if item.id == itemId and not item.unlocked then
            if self:spendDarkEssence(item.cost) then
                self.startingItems[i].unlocked = true
                table.insert(self.unlockedContent.items, itemId)
                self:saveProgress()
                return true, "Starting item unlocked successfully"
            else
                return false, "Not enough dark essence"
            end
        end
    end
    return false, "Item not found or already unlocked"
end

-- Unlock a game mode
function MetaProgression:unlockGameMode(modeId)
    for i, mode in ipairs(self.gameModes) do
        if mode.id == modeId and not mode.unlocked then
            if self:spendDarkEssence(mode.cost) then
                self.gameModes[i].unlocked = true
                self:saveProgress()
                return true, "Game mode unlocked successfully"
            else
                return false, "Not enough dark essence"
            end
        end
    end
    return false, "Game mode not found or already unlocked"
end

-- Activate a challenge
function MetaProgression:activateChallenge(challengeId)
    -- Find the challenge
    local challenge = nil
    for _, c in ipairs(self.challenges.available) do
        if c.id == challengeId and not c.completed then
            challenge = c
            break
        end
    end
    
    if not challenge then
        return false, "Challenge not found or already completed"
    end
    
    -- Check if challenge is already active
    for _, c in ipairs(self.challenges.active) do
        if c.id == challengeId then
            return false, "Challenge already active"
        end
    end
    
    -- Activate the challenge
    table.insert(self.challenges.active, challenge)
    self:saveProgress()
    
    return true, "Challenge activated successfully"
end

-- Complete a challenge
function MetaProgression:completeChallenge(challengeId)
    -- Find the challenge in active challenges
    local index = nil
    local challenge = nil
    
    for i, c in ipairs(self.challenges.active) do
        if c.id == challengeId then
            index = i
            challenge = c
            break
        end
    end
    
    if not index then
        return false, "Challenge not active"
    end
    
    -- Remove from active and add to completed
    table.remove(self.challenges.active, index)
    challenge.completed = true
    table.insert(self.challenges.completed, challenge)
    
    -- Award dark essence
    self:addDarkEssence(challenge.reward)
    self:saveProgress()
    
    return true, "Challenge completed successfully", challenge.reward
end

-- Complete a tutorial
function MetaProgression:completeTutorial(tutorialId)
    if self.tutorials[tutorialId] and not self.tutorials[tutorialId].completed then
        self.tutorials[tutorialId].completed = true
        local reward = self.tutorials[tutorialId].reward
        self:addDarkEssence(reward)
        self:saveProgress()
        return true, "Tutorial completed", reward
    end
    return false, "Tutorial not found or already completed"
end

-- Update achievement progress
function MetaProgression:updateAchievement(achievementType, value)
    if self.achievements[achievementType] ~= nil then
        if type(self.achievements[achievementType]) == "number" then
            self.achievements[achievementType] = self.achievements[achievementType] + value
        else
            self.achievements[achievementType] = value
        end
        self:saveProgress()
        return true
    end
    return false
end

-- Record a completed run
function MetaProgression:recordRun(runData)
    -- Update achievements
    self:updateAchievement("completedRuns", 1)
    
    if runData.highestFloor > self.achievements.highestFloor then
        self:updateAchievement("highestFloor", runData.highestFloor)
    end
    
    if not self.achievements.fastestCompletion or runData.completionTime < self.achievements.fastestCompletion then
        self:updateAchievement("fastestCompletion", runData.completionTime)
    end
    
    self:updateAchievement("totalKills", runData.kills)
    self:updateAchievement("bossesDefeated", runData.bossesDefeated)
    self:updateAchievement("damageDealt", runData.damageDealt)
    self:updateAchievement("itemsCollected", runData.itemsCollected)
    self:updateAchievement("goldCollected", runData.goldCollected)
    self:updateAchievement("abilitiesUsed", runData.abilitiesUsed)
    
    if runData.perfect then
        self:updateAchievement("perfectRuns", 1)
    end
    
    if runData.noHit then
        self:updateAchievement("noHitRuns", 1)
    end
    
    if runData.lowLevel then
        self:updateAchievement("lowLevelRuns", 1)
    end
    
    -- Add dark essence reward
    local essenceReward = runData.baseReward
    
    -- Bonus for high floor
    essenceReward = essenceReward + (runData.highestFloor * 5)
    
    -- Bonus for bosses defeated
    essenceReward = essenceReward + (runData.bossesDefeated * 25)
    
    -- Bonus for perfect run
    if runData.perfect then
        essenceReward = essenceReward * 1.5
    end
    
    -- Bonus for no-hit run
    if runData.noHit then
        essenceReward = essenceReward * 2
    end
    
    -- Bonus for low-level run
    if runData.lowLevel then
        essenceReward = essenceReward * 1.25
    end
    
    -- Add to run history
    table.insert(self.runHistory, {
        timestamp = os.time(),
        data = runData,
        reward = essenceReward
    })
    
    -- Limit history size
    if #self.runHistory > 20 then
        table.remove(self.runHistory, 1)
    end
    
    -- Add the reward
    self:addDarkEssence(essenceReward)
    
    return essenceReward
end

-- Apply meta progression bonuses to a new game
function MetaProgression:applyBonusesToNewGame(gameState)
    -- Apply stat bonuses
    gameState.player.baseHealth = gameState.player.baseHealth + (self.permanentUpgrades.startingHealth * 1)
    gameState.player.baseEnergy = gameState.player.baseEnergy + (self.permanentUpgrades.startingEnergy * 1)
    gameState.player.gold = gameState.player.gold + (self.permanentUpgrades.startingGold * 10)
    
    -- Apply combat bonuses to all player units
    for _, unit in ipairs(gameState.player.units) do
        unit.stats.attack = unit.stats.attack + (self.permanentUpgrades.attackBonus * 1)
        unit.stats.defense = unit.stats.defense + (self.permanentUpgrades.defenseBonus * 1)
        unit.stats.critChance = unit.stats.critChance + (self.permanentUpgrades.critChance * 0.02)
    end
    
    -- Apply resource bonuses
    gameState.player.healthRegenBonus = (self.permanentUpgrades.healthRegen * 0.5)
    gameState.player.energyRegenBonus = (self.permanentUpgrades.energyRegen * 0.5)
    gameState.player.goldBonus = (self.permanentUpgrades.goldBonus * 0.05)
    
    -- Apply gameplay bonuses
    if self.permanentUpgrades.extraActionPoint > 0 then
        for _, unit in ipairs(gameState.player.units) do
            unit.stats.maxActionPoints = unit.stats.maxActionPoints + 1
            unit.stats.actionPoints = unit.stats.actionPoints + 1
        end
    end
    
    for _, unit in ipairs(gameState.player.units) do
        unit.stats.moveRange = unit.stats.moveRange + self.permanentUpgrades.movementBonus
    end
    
    gameState.player.maxItemSlots = gameState.player.maxItemSlots + self.permanentUpgrades.itemSlots
    
    -- Apply special bonuses
    gameState.player.reviveChance = (self.permanentUpgrades.reviveChance * 0.33) -- Up to 99% at max level
    gameState.player.treasureChance = (self.permanentUpgrades.treasureChance * 0.05) -- Up to 25% at max level
    gameState.player.eliteDropRate = (self.permanentUpgrades.eliteDropRate * 0.1) -- Up to 50% at max level
    
    -- Apply unlocked starting items
    for _, item in ipairs(self.startingItems) do
        if item.unlocked then
            -- Add the item to player's inventory
            gameState.player:addStartingItem(item.id)
        end
    end
    
    return gameState
end

-- Get all unlocked characters
function MetaProgression:getUnlockedCharacters()
    local unlocked = {}
    for _, character in ipairs(self.characters) do
        if character.unlocked then
            table.insert(unlocked, character)
        end
    end
    return unlocked
end

-- Get all unlocked starting items
function MetaProgression:getUnlockedStartingItems()
    local unlocked = {}
    for _, item in ipairs(self.startingItems) do
        if item.unlocked then
            table.insert(unlocked, item)
        end
    end
    return unlocked
end

-- Get all unlocked game modes
function MetaProgression:getUnlockedGameModes()
    local unlocked = {}
    for _, mode in ipairs(self.gameModes) do
        if mode.unlocked then
            table.insert(unlocked, mode)
        end
    end
    return unlocked
end

-- Get all available challenges
function MetaProgression:getAvailableChallenges()
    local available = {}
    for _, challenge in ipairs(self.challenges.available) do
        if not challenge.completed then
            table.insert(available, challenge)
        end
    end
    return available
end

-- Get all active challenges
function MetaProgression:getActiveChallenges()
    return self.challenges.active
end

-- Get all completed challenges
function MetaProgression:getCompletedChallenges()
    return self.challenges.completed
end

-- Get run history
function MetaProgression:getRunHistory()
    return self.runHistory
end

-- Get achievement progress
function MetaProgression:getAchievements()
    return self.achievements
end

-- Reset all progress (for testing)
function MetaProgression:resetProgress()
    self.darkEssence = 0
    self.unlockedContent = {
        characters = {},
        abilities = {},
        items = {},
        rooms = {},
        enemies = {}
    }
    
    for key, _ in pairs(self.permanentUpgrades) do
        self.permanentUpgrades[key] = 0
    end
    
    for i, character in ipairs(self.characters) do
        if character.id ~= "standard" then -- Keep standard character unlocked
            self.characters[i].unlocked = false
        end
    end
    
    for i, item in ipairs(self.startingItems) do
        self.startingItems[i].unlocked = false
    end
    
    for i, mode in ipairs(self.gameModes) do
        if mode.id ~= "standard" then -- Keep standard mode unlocked
            self.gameModes[i].unlocked = false
        end
    end
    
    for key, tutorial in pairs(self.tutorials) do
        self.tutorials[key].completed = false
    end
    
    for key, _ in pairs(self.achievements) do
        if type(self.achievements[key]) == "number" then
            self.achievements[key] = 0
        else
            self.achievements[key] = nil
        end
    end
    
    self.challenges.active = {}
    self.challenges.completed = {}
    
    for i, challenge in ipairs(self.challenges.available) do
        self.challenges.available[i].completed = false
    end
    
    self.runHistory = {}
    
    self:saveProgress()
    
    return true, "Progress reset successfully"
end

-- Save progress to file
function MetaProgression:saveProgress()
    local saveData = {
        darkEssence = self.darkEssence,
        unlockedContent = self.unlockedContent,
        permanentUpgrades = self.permanentUpgrades,
        achievements = self.achievements,
        characters = self.characters,
        startingItems = self.startingItems,
        gameModes = self.gameModes,
        challenges = {
            available = self.challenges.available,
            completed = self.challenges.completed
        },
        tutorials = self.tutorials,
        runHistory = self.runHistory
    }
    
    -- Convert to JSON string
    local json = require("lib.json")
    local saveString = json.encode(saveData)
    
    -- Save to file
    love.filesystem.write("meta_progress.save", saveString)
    
    return true
end

-- Load progress from file
function MetaProgression:loadProgress()
    if not love.filesystem.exists("meta_progress.save") then
        return false, "No save file found"
    end
    
    local saveString = love.filesystem.read("meta_progress.save")
    local json = require("lib.json")
    
    local success, saveData = pcall(json.decode, saveString)
    
    if not success or not saveData then
        return false, "Failed to load save data"
    end
    
    -- Load data
    self.darkEssence = saveData.darkEssence or 0
    self.unlockedContent = saveData.unlockedContent or {
        characters = {},
        abilities = {},
        items = {},
        rooms = {},
        enemies = {}
    }
    
    self.permanentUpgrades = saveData.permanentUpgrades or {}
    self.achievements = saveData.achievements or {}
    self.characters = saveData.characters or self.characters
    self.startingItems = saveData.startingItems or self.startingItems
    self.gameModes = saveData.gameModes or self.gameModes
    
    if saveData.challenges then
        self.challenges.available = saveData.challenges.available or self.challenges.available
        self.challenges.completed = saveData.challenges.completed or {}
    end
    
    self.tutorials = saveData.tutorials or self.tutorials
    self.runHistory = saveData.runHistory or {}
    
    return true, "Progress loaded successfully"
end

-- Get a summary of current progress
function MetaProgression:getProgressSummary()
    local summary = {
        darkEssence = self.darkEssence,
        upgradesCount = 0,
        charactersUnlocked = 0,
        itemsUnlocked = 0,
        gameModesUnlocked = 0,
        challengesCompleted = #self.challenges.completed,
        tutorialsCompleted = 0,
        runsCompleted = self.achievements.completedRuns,
        highestFloor = self.achievements.highestFloor
    }
    
    -- Count upgrades
    for key, level in pairs(self.permanentUpgrades) do
        summary.upgradesCount = summary.upgradesCount + level
    end
    
    -- Count unlocked characters
    for _, character in ipairs(self.characters) do
        if character.unlocked then
            summary.charactersUnlocked = summary.charactersUnlocked + 1
        end
    end
    
    -- Count unlocked items
    for _, item in ipairs(self.startingItems) do
        if item.unlocked then
            summary.itemsUnlocked = summary.itemsUnlocked + 1
        end
    end
    
    -- Count unlocked game modes
    for _, mode in ipairs(self.gameModes) do
        if mode.unlocked then
            summary.gameModesUnlocked = summary.gameModesUnlocked + 1
        end
    end
    
    -- Count completed tutorials
    for _, tutorial in pairs(self.tutorials) do
        if tutorial.completed then
            summary.tutorialsCompleted = summary.tutorialsCompleted + 1
        end
    end
    
    return summary
end

return MetaProgression
