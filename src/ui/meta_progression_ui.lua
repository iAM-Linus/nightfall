-- Meta Progression UI for Nightfall Chess
-- Handles display and interaction with meta progression systems

local class = require("lib.middleclass.middleclass")

local MetaProgressionUI = class("MetaProgressionUI")

function MetaProgressionUI:initialize(game, metaProgression)
    self.game = game
    self.metaProgression = metaProgression
    
    -- UI state
    self.visible = false
    self.alpha = 0
    self.targetAlpha = 0
    
    -- Layout
    self.width = 800
    self.height = 600
    self.x = 0
    self.y = 0
    
    -- Current tab
    self.currentTab = "upgrades"
    
    -- Scroll positions
    self.scrollPositions = {
        upgrades = 0,
        characters = 0,
        items = 0,
        challenges = 0,
        achievements = 0
    }
    
    -- Selected items
    self.selectedUpgrade = nil
    self.selectedCharacter = nil
    self.selectedItem = nil
    self.selectedChallenge = nil
    
    -- Confirmation dialog
    self.showConfirmation = false
    self.confirmationAction = nil
    self.confirmationText = ""
    self.confirmationCost = 0
end

-- Set UI position
function MetaProgressionUI:setPosition(x, y)
    self.x = x
    self.y = y
end

-- Show meta progression UI
function MetaProgressionUI:show()
    self.visible = true
    self.targetAlpha = 1
end

-- Hide meta progression UI
function MetaProgressionUI:hide()
    self.targetAlpha = 0
    self.showConfirmation = false
end

-- Update meta progression UI
function MetaProgressionUI:update(dt)
    -- Animate alpha
    if self.alpha < self.targetAlpha then
        self.alpha = math.min(self.alpha + dt * 5, self.targetAlpha)
    elseif self.alpha > self.targetAlpha then
        self.alpha = math.max(self.alpha - dt * 5, self.targetAlpha)
        if self.alpha <= 0 then
            self.visible = false
        end
    end
end

-- Draw meta progression UI
function MetaProgressionUI:draw()
    if not self.visible then return end
    
    local width, height = love.graphics.getDimensions()
    
    -- Center the UI if position not set
    if self.x == 0 and self.y == 0 then
        self.x = (width - self.width) / 2
        self.y = (height - self.height) / 2
    end
    
    -- Draw background
    love.graphics.setColor(0.1, 0.1, 0.2, 0.95 * self.alpha)
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height, 10, 10)
    
    love.graphics.setColor(0.3, 0.3, 0.5, 0.8 * self.alpha)
    love.graphics.rectangle("line", self.x, self.y, self.width, self.height, 10, 10)
    
    -- Draw title
    love.graphics.setColor(1, 1, 1, self.alpha)
    love.graphics.setFont(self.game.assets.fonts.large)
    love.graphics.print("Meta Progression", self.x + 20, self.y + 20)
    
    -- Draw dark essence
    if self.metaProgression then
        love.graphics.setColor(0.7, 0.3, 0.9, self.alpha)
        love.graphics.setFont(self.game.assets.fonts.medium)
        love.graphics.print("Dark Essence: " .. self.metaProgression:getDarkEssence(), self.x + self.width - 250, self.y + 25)
    end
    
    -- Draw tabs
    self:drawTabs()
    
    -- Draw content based on current tab
    if self.currentTab == "upgrades" then
        self:drawUpgradesTab()
    elseif self.currentTab == "characters" then
        self:drawCharactersTab()
    elseif self.currentTab == "items" then
        self:drawItemsTab()
    elseif self.currentTab == "challenges" then
        self:drawChallengesTab()
    elseif self.currentTab == "achievements" then
        self:drawAchievementsTab()
    end
    
    -- Draw confirmation dialog
    if self.showConfirmation then
        self:drawConfirmationDialog()
    end
    
    -- Draw close button
    love.graphics.setColor(0.8, 0.2, 0.2, 0.8 * self.alpha)
    love.graphics.rectangle("fill", self.x + self.width - 30, self.y + 10, 20, 20, 3, 3)
    
    love.graphics.setColor(1, 1, 1, self.alpha)
    love.graphics.printf("X", self.x + self.width - 30, self.y + 12, 20, "center")
end

-- Draw tabs
function MetaProgressionUI:drawTabs()
    local tabs = {
        {id = "upgrades", name = "Upgrades"},
        {id = "characters", name = "Characters"},
        {id = "items", name = "Starting Items"},
        {id = "challenges", name = "Challenges"},
        {id = "achievements", name = "Achievements"}
    }
    
    local tabWidth = 150
    local tabHeight = 30
    local tabY = self.y + 70
    
    for i, tab in ipairs(tabs) do
        local tabX = self.x + 20 + (i-1) * (tabWidth + 10)
        
        -- Draw tab background
        if self.currentTab == tab.id then
            love.graphics.setColor(0.3, 0.3, 0.6, 0.8 * self.alpha)
        else
            love.graphics.setColor(0.2, 0.2, 0.3, 0.8 * self.alpha)
        end
        
        love.graphics.rectangle("fill", tabX, tabY, tabWidth, tabHeight, 5, 5, 5, 0)
        
        -- Draw tab text
        love.graphics.setColor(1, 1, 1, self.alpha)
        love.graphics.setFont(self.game.assets.fonts.small)
        love.graphics.printf(tab.name, tabX, tabY + 8, tabWidth, "center")
    end
    
    -- Draw content area
    love.graphics.setColor(0.2, 0.2, 0.3, 0.8 * self.alpha)
    love.graphics.rectangle("fill", self.x + 20, self.y + 100, self.width - 40, self.height - 120, 5, 5)
    
    love.graphics.setColor(0.3, 0.3, 0.5, 0.8 * self.alpha)
    love.graphics.rectangle("line", self.x + 20, self.y + 100, self.width - 40, self.height - 120, 5, 5)
end

-- Draw upgrades tab
function MetaProgressionUI:drawUpgradesTab()
    if not self.metaProgression then return end
    
    local contentX = self.x + 30
    local contentY = self.y + 110 + self.scrollPositions.upgrades
    local contentWidth = self.width - 60
    
    -- Draw section titles
    love.graphics.setColor(0.8, 0.8, 1.0, self.alpha)
    love.graphics.setFont(self.game.assets.fonts.medium)
    
    -- Starting stats section
    love.graphics.print("Starting Stats", contentX, contentY)
    contentY = contentY + 30
    
    local upgradeCategories = {
        {
            title = "Starting Stats",
            upgrades = {
                {id = "startingHealth", name = "Starting Health", description = "+1 health per level"},
                {id = "startingEnergy", name = "Starting Energy", description = "+1 energy per level"},
                {id = "startingGold", name = "Starting Gold", description = "+10 gold per level"}
            }
        },
        {
            title = "Combat Bonuses",
            upgrades = {
                {id = "attackBonus", name = "Attack Bonus", description = "+1 attack per level"},
                {id = "defenseBonus", name = "Defense Bonus", description = "+1 defense per level"},
                {id = "critChance", name = "Critical Chance", description = "+2% crit chance per level"}
            }
        },
        {
            title = "Resource Bonuses",
            upgrades = {
                {id = "healthRegen", name = "Health Regeneration", description = "+0.5 health regen per level"},
                {id = "energyRegen", name = "Energy Regeneration", description = "+0.5 energy regen per level"},
                {id = "goldBonus", name = "Gold Bonus", description = "+5% gold drops per level"}
            }
        },
        {
            title = "Gameplay Bonuses",
            upgrades = {
                {id = "extraActionPoint", name = "Extra Action Point", description = "+1 action point at level 3"},
                {id = "movementBonus", name = "Movement Bonus", description = "+1 movement range per level"},
                {id = "itemSlots", name = "Item Slots", description = "+1 item slot per level"}
            }
        },
        {
            title = "Special Bonuses",
            upgrades = {
                {id = "reviveChance", name = "Revive Chance", description = "Chance to revive once per run"},
                {id = "treasureChance", name = "Treasure Chance", description = "Increased chance for treasure rooms"},
                {id = "eliteDropRate", name = "Elite Drop Rate", description = "Better drops from elite enemies"}
            }
        }
    }
    
    for _, category in ipairs(upgradeCategories) do
        -- Draw category title
        love.graphics.setColor(0.8, 0.8, 1.0, self.alpha)
        love.graphics.setFont(self.game.assets.fonts.medium)
        love.graphics.print(category.title, contentX, contentY)
        contentY = contentY + 30
        
        -- Draw upgrades
        for _, upgrade in ipairs(category.upgrades) do
            local upgradeLevel = self.metaProgression:getUpgradeLevel(upgrade.id)
            local upgradeCost = self.metaProgression:getUpgradeCost(upgrade.id)
            
            -- Draw upgrade background
            if self.selectedUpgrade == upgrade.id then
                love.graphics.setColor(0.3, 0.3, 0.6, 0.8 * self.alpha)
            else
                love.graphics.setColor(0.25, 0.25, 0.35, 0.8 * self.alpha)
            end
            
            love.graphics.rectangle("fill", contentX, contentY, contentWidth - 20, 60, 5, 5)
            
            -- Draw upgrade name
            love.graphics.setColor(1, 1, 1, self.alpha)
            love.graphics.setFont(self.game.assets.fonts.medium)
            love.graphics.print(upgrade.name, contentX + 10, contentY + 10)
            
            -- Draw upgrade description
            love.graphics.setColor(0.8, 0.8, 0.8, 0.9 * self.alpha)
            love.graphics.setFont(self.game.assets.fonts.small)
            love.graphics.print(upgrade.description, contentX + 10, contentY + 35)
            
            -- Draw upgrade level
            love.graphics.setColor(0.7, 0.7, 1.0, self.alpha)
            love.graphics.print("Level: " .. upgradeLevel, contentX + contentWidth - 200, contentY + 10)
            
            -- Draw upgrade cost
            love.graphics.setColor(0.7, 0.3, 0.9, self.alpha)
            love.graphics.print("Cost: " .. upgradeCost, contentX + contentWidth - 200, contentY + 35)
            
            -- Draw upgrade button
            if self.metaProgression:getDarkEssence() >= upgradeCost then
                love.graphics.setColor(0.3, 0.6, 0.3, 0.8 * self.alpha)
            else
                love.graphics.setColor(0.6, 0.3, 0.3, 0.8 * self.alpha)
            end
            
            love.graphics.rectangle("fill", contentX + contentWidth - 100, contentY + 20, 80, 30, 5, 5)
            
            love.graphics.setColor(1, 1, 1, self.alpha)
            love.graphics.printf("Upgrade", contentX + contentWidth - 100, contentY + 25, 80, "center")
            
            contentY = contentY + 70
        end
        
        contentY = contentY + 20
    end
    
    -- Draw scroll indicators if needed
    local totalHeight = contentY - (self.y + 110)
    local viewHeight = self.height - 120
    
    if totalHeight > viewHeight then
        -- Draw up arrow
        if self.scrollPositions.upgrades < 0 then
            love.graphics.setColor(0.7, 0.7, 0.7, 0.8 * self.alpha)
            love.graphics.polygon("fill", 
                self.x + self.width - 30, self.y + 120,
                self.x + self.width - 20, self.y + 110,
                self.x + self.width - 10, self.y + 120
            )
        end
        
        -- Draw down arrow
        if self.scrollPositions.upgrades > -(totalHeight - viewHeight) then
            love.graphics.setColor(0.7, 0.7, 0.7, 0.8 * self.alpha)
            love.graphics.polygon("fill", 
                self.x + self.width - 30, self.y + self.height - 30,
                self.x + self.width - 20, self.y + self.height - 20,
                self.x + self.width - 10, self.y + self.height - 30
            )
        end
    end
end

-- Draw characters tab
function MetaProgressionUI:drawCharactersTab()
    if not self.metaProgression then return end
    
    local contentX = self.x + 30
    local contentY = self.y + 110 + self.scrollPositions.characters
    local contentWidth = self.width - 60
    
    -- Draw title
    love.graphics.setColor(0.8, 0.8, 1.0, self.alpha)
    love.graphics.setFont(self.game.assets.fonts.medium)
    love.graphics.print("Unlockable Characters", contentX, contentY)
    contentY = contentY + 30
    
    -- Get characters
    local characters = self.metaProgression.characters
    
    -- Draw characters
    for _, character in ipairs(characters) do
        -- Draw character background
        if self.selectedCharacter == character.id then
            love.graphics.setColor(0.3, 0.3, 0.6, 0.8 * self.alpha)
        else
            love.graphics.setColor(0.25, 0.25, 0.35, 0.8 * self.alpha)
        end
        
        love.graphics.rectangle("fill", contentX, contentY, contentWidth - 20, 100, 5, 5)
        
        -- Draw character name
        love.graphics.setColor(1, 1, 1, self.alpha)
        love.graphics.setFont(self.game.assets.fonts.medium)
        love.graphics.print(character.name, contentX + 10, contentY + 10)
        
        -- Draw character description
        love.graphics.setColor(0.8, 0.8, 0.8, 0.9 * self.alpha)
        love.graphics.setFont(self.game.assets.fonts.small)
        love.graphics.print(character.description, contentX + 10, contentY + 35)
        
        -- Draw character abilities
        love.graphics.setColor(0.7, 0.7, 1.0, self.alpha)
        local abilitiesText = "Abilities: " .. table.concat(character.abilities, ", ")
        love.graphics.print(abilitiesText, contentX + 10, contentY + 60)
        
        -- Draw unlock status
        if character.unlocked then
            love.graphics.setColor(0.3, 0.8, 0.3, self.alpha)
            love.graphics.print("UNLOCKED", contentX + contentWidth - 150, contentY + 10)
        else
            -- Draw cost
            love.graphics.setColor(0.7, 0.3, 0.9, self.alpha)
            love.graphics.print("Cost: " .. character.cost, contentX + contentWidth - 150, contentY + 10)
            
            -- Draw unlock button
            if self.metaProgression:getDarkEssence() >= character.cost then
                love.graphics.setColor(0.3, 0.6, 0.3, 0.8 * self.alpha)
            else
                love.graphics.setColor(0.6, 0.3, 0.3, 0.8 * self.alpha)
            end
            
            love.graphics.rectangle("fill", contentX + contentWidth - 150, contentY + 40, 100, 30, 5, 5)
            
            love.graphics.setColor(1, 1, 1, self.alpha)
            love.graphics.printf("Unlock", contentX + contentWidth - 150, contentY + 45, 100, "center")
        end
        
        contentY = contentY + 110
    end
    
    -- Draw scroll indicators if needed
    local totalHeight = contentY - (self.y + 110)
    local viewHeight = self.height - 120
    
    if totalHeight > viewHeight then
        -- Draw up arrow
        if self.scrollPositions.characters < 0 then
            love.graphics.setColor(0.7, 0.7, 0.7, 0.8 * self.alpha)
            love.graphics.polygon("fill", 
                self.x + self.width - 30, self.y + 120,
                self.x + self.width - 20, self.y + 110,
                self.x + self.width - 10, self.y + 120
            )
        end
        
        -- Draw down arrow
        if self.scrollPositions.characters > -(totalHeight - viewHeight) then
            love.graphics.setColor(0.7, 0.7, 0.7, 0.8 * self.alpha)
            love.graphics.polygon("fill", 
                self.x + self.width - 30, self.y + self.height - 30,
                self.x + self.width - 20, self.y + self.height - 20,
                self.x + self.width - 10, self.y + self.height - 30
            )
        end
    end
end

-- Draw items tab
function MetaProgressionUI:drawItemsTab()
    if not self.metaProgression then return end
    
    local contentX = self.x + 30
    local contentY = self.y + 110 + self.scrollPositions.items
    local contentWidth = self.width - 60
    
    -- Draw title
    love.graphics.setColor(0.8, 0.8, 1.0, self.alpha)
    love.graphics.setFont(self.game.assets.fonts.medium)
    love.graphics.print("Unlockable Starting Items", contentX, contentY)
    contentY = contentY + 30
    
    -- Get items
    local items = self.metaProgression.startingItems
    
    -- Draw items
    for _, item in ipairs(items) do
        -- Draw item background
        if self.selectedItem == item.id then
            love.graphics.setColor(0.3, 0.3, 0.6, 0.8 * self.alpha)
        else
            love.graphics.setColor(0.25, 0.25, 0.35, 0.8 * self.alpha)
        end
        
        love.graphics.rectangle("fill", contentX, contentY, contentWidth - 20, 70, 5, 5)
        
        -- Draw item name
        love.graphics.setColor(1, 1, 1, self.alpha)
        love.graphics.setFont(self.game.assets.fonts.medium)
        love.graphics.print(item.name, contentX + 10, contentY + 10)
        
        -- Draw item description
        love.graphics.setColor(0.8, 0.8, 0.8, 0.9 * self.alpha)
        love.graphics.setFont(self.game.assets.fonts.small)
        love.graphics.print(item.description, contentX + 10, contentY + 35)
        
        -- Draw unlock status
        if item.unlocked then
            love.graphics.setColor(0.3, 0.8, 0.3, self.alpha)
            love.graphics.print("UNLOCKED", contentX + contentWidth - 150, contentY + 10)
        else
            -- Draw cost
            love.graphics.setColor(0.7, 0.3, 0.9, self.alpha)
            love.graphics.print("Cost: " .. item.cost, contentX + contentWidth - 150, contentY + 10)
            
            -- Draw unlock button
            if self.metaProgression:getDarkEssence() >= item.cost then
                love.graphics.setColor(0.3, 0.6, 0.3, 0.8 * self.alpha)
            else
                love.graphics.setColor(0.6, 0.3, 0.3, 0.8 * self.alpha)
            end
            
            love.graphics.rectangle("fill", contentX + contentWidth - 150, contentY + 35, 100, 30, 5, 5)
            
            love.graphics.setColor(1, 1, 1, self.alpha)
            love.graphics.printf("Unlock", contentX + contentWidth - 150, contentY + 40, 100, "center")
        end
        
        contentY = contentY + 80
    end
    
    -- Draw scroll indicators if needed
    local totalHeight = contentY - (self.y + 110)
    local viewHeight = self.height - 120
    
    if totalHeight > viewHeight then
        -- Draw up arrow
        if self.scrollPositions.items < 0 then
            love.graphics.setColor(0.7, 0.7, 0.7, 0.8 * self.alpha)
            love.graphics.polygon("fill", 
                self.x + self.width - 30, self.y + 120,
                self.x + self.width - 20, self.y + 110,
                self.x + self.width - 10, self.y + 120
            )
        end
        
        -- Draw down arrow
        if self.scrollPositions.items > -(totalHeight - viewHeight) then
            love.graphics.setColor(0.7, 0.7, 0.7, 0.8 * self.alpha)
            love.graphics.polygon("fill", 
                self.x + self.width - 30, self.y + self.height - 30,
                self.x + self.width - 20, self.y + self.height - 20,
                self.x + self.width - 10, self.y + self.height - 30
            )
        end
    end
end

-- Draw challenges tab
function MetaProgressionUI:drawChallengesTab()
    if not self.metaProgression then return end
    
    local contentX = self.x + 30
    local contentY = self.y + 110 + self.scrollPositions.challenges
    local contentWidth = self.width - 60
    
    -- Draw title
    love.graphics.setColor(0.8, 0.8, 1.0, self.alpha)
    love.graphics.setFont(self.game.assets.fonts.medium)
    love.graphics.print("Challenges", contentX, contentY)
    contentY = contentY + 30
    
    -- Get challenges
    local challenges = self.metaProgression.challenges.available
    
    -- Draw challenges
    for _, challenge in ipairs(challenges) do
        -- Draw challenge background
        if self.selectedChallenge == challenge.id then
            love.graphics.setColor(0.3, 0.3, 0.6, 0.8 * self.alpha)
        else
            love.graphics.setColor(0.25, 0.25, 0.35, 0.8 * self.alpha)
        end
        
        love.graphics.rectangle("fill", contentX, contentY, contentWidth - 20, 70, 5, 5)
        
        -- Draw challenge name
        love.graphics.setColor(1, 1, 1, self.alpha)
        love.graphics.setFont(self.game.assets.fonts.medium)
        love.graphics.print(challenge.name, contentX + 10, contentY + 10)
        
        -- Draw challenge description
        love.graphics.setColor(0.8, 0.8, 0.8, 0.9 * self.alpha)
        love.graphics.setFont(self.game.assets.fonts.small)
        love.graphics.print(challenge.description, contentX + 10, contentY + 35)
        
        -- Draw challenge reward
        love.graphics.setColor(0.7, 0.3, 0.9, self.alpha)
        love.graphics.print("Reward: " .. challenge.reward .. " Dark Essence", contentX + contentWidth - 250, contentY + 10)
        
        -- Draw challenge status
        if challenge.completed then
            love.graphics.setColor(0.3, 0.8, 0.3, self.alpha)
            love.graphics.print("COMPLETED", contentX + contentWidth - 150, contentY + 35)
        else
            -- Draw activate button
            love.graphics.setColor(0.3, 0.6, 0.3, 0.8 * self.alpha)
            love.graphics.rectangle("fill", contentX + contentWidth - 150, contentY + 35, 100, 30, 5, 5)
            
            love.graphics.setColor(1, 1, 1, self.alpha)
            love.graphics.printf("Activate", contentX + contentWidth - 150, contentY + 40, 100, "center")
        end
        
        contentY = contentY + 80
    end
    
    -- Draw scroll indicators if needed
    local totalHeight = contentY - (self.y + 110)
    local viewHeight = self.height - 120
    
    if totalHeight > viewHeight then
        -- Draw up arrow
        if self.scrollPositions.challenges < 0 then
            love.graphics.setColor(0.7, 0.7, 0.7, 0.8 * self.alpha)
            love.graphics.polygon("fill", 
                self.x + self.width - 30, self.y + 120,
                self.x + self.width - 20, self.y + 110,
                self.x + self.width - 10, self.y + 120
            )
        end
        
        -- Draw down arrow
        if self.scrollPositions.challenges > -(totalHeight - viewHeight) then
            love.graphics.setColor(0.7, 0.7, 0.7, 0.8 * self.alpha)
            love.graphics.polygon("fill", 
                self.x + self.width - 30, self.y + self.height - 30,
                self.x + self.width - 20, self.y + self.height - 20,
                self.x + self.width - 10, self.y + self.height - 30
            )
        end
    end
end

-- Draw achievements tab
function MetaProgressionUI:drawAchievementsTab()
    if not self.metaProgression then return end
    
    local contentX = self.x + 30
    local contentY = self.y + 110 + self.scrollPositions.achievements
    local contentWidth = self.width - 60
    
    -- Draw title
    love.graphics.setColor(0.8, 0.8, 1.0, self.alpha)
    love.graphics.setFont(self.game.assets.fonts.medium)
    love.graphics.print("Achievements", contentX, contentY)
    contentY = contentY + 30
    
    -- Get achievements
    local achievements = self.metaProgression:getAchievements()
    
    -- Draw achievement categories
    local categories = {
        {name = "Completion", achievements = {"completedRuns", "highestFloor", "fastestCompletion"}},
        {name = "Combat", achievements = {"totalKills", "bossesDefeated", "damageDealt"}},
        {name = "Collection", achievements = {"itemsCollected", "goldCollected", "abilitiesUsed"}},
        {name = "Special", achievements = {"perfectRuns", "noHitRuns", "lowLevelRuns"}}
    }
    
    for _, category in ipairs(categories) do
        -- Draw category title
        love.graphics.setColor(0.8, 0.8, 1.0, self.alpha)
        love.graphics.setFont(self.game.assets.fonts.medium)
        love.graphics.print(category.name, contentX, contentY)
        contentY = contentY + 30
        
        -- Draw achievements
        for _, achievementId in ipairs(category.achievements) do
            local value = achievements[achievementId]
            local displayName = achievementId:gsub("([A-Z])", " %1"):gsub("^%l", string.upper)
            
            -- Draw achievement background
            love.graphics.setColor(0.25, 0.25, 0.35, 0.8 * self.alpha)
            love.graphics.rectangle("fill", contentX, contentY, contentWidth - 20, 40, 5, 5)
            
            -- Draw achievement name
            love.graphics.setColor(1, 1, 1, self.alpha)
            love.graphics.setFont(self.game.assets.fonts.small)
            love.graphics.print(displayName, contentX + 10, contentY + 10)
            
            -- Draw achievement value
            love.graphics.setColor(0.7, 0.7, 1.0, self.alpha)
            
            local displayValue = value
            if achievementId == "fastestCompletion" and value then
                -- Format time
                local minutes = math.floor(value / 60)
                local seconds = value % 60
                displayValue = string.format("%d:%02d", minutes, seconds)
            end
            
            love.graphics.print(tostring(displayValue or "0"), contentX + contentWidth - 100, contentY + 10)
            
            contentY = contentY + 50
        end
        
        contentY = contentY + 20
    end
    
    -- Draw scroll indicators if needed
    local totalHeight = contentY - (self.y + 110)
    local viewHeight = self.height - 120
    
    if totalHeight > viewHeight then
        -- Draw up arrow
        if self.scrollPositions.achievements < 0 then
            love.graphics.setColor(0.7, 0.7, 0.7, 0.8 * self.alpha)
            love.graphics.polygon("fill", 
                self.x + self.width - 30, self.y + 120,
                self.x + self.width - 20, self.y + 110,
                self.x + self.width - 10, self.y + 120
            )
        end
        
        -- Draw down arrow
        if self.scrollPositions.achievements > -(totalHeight - viewHeight) then
            love.graphics.setColor(0.7, 0.7, 0.7, 0.8 * self.alpha)
            love.graphics.polygon("fill", 
                self.x + self.width - 30, self.y + self.height - 30,
                self.x + self.width - 20, self.y + self.height - 20,
                self.x + self.width - 10, self.y + self.height - 30
            )
        end
    end
end

-- Draw confirmation dialog
function MetaProgressionUI:drawConfirmationDialog()
    local dialogWidth = 400
    local dialogHeight = 200
    local dialogX = self.x + (self.width - dialogWidth) / 2
    local dialogY = self.y + (self.height - dialogHeight) / 2
    
    -- Draw dialog background
    love.graphics.setColor(0.1, 0.1, 0.2, 0.95 * self.alpha)
    love.graphics.rectangle("fill", dialogX, dialogY, dialogWidth, dialogHeight, 10, 10)
    
    love.graphics.setColor(0.3, 0.3, 0.5, 0.8 * self.alpha)
    love.graphics.rectangle("line", dialogX, dialogY, dialogWidth, dialogHeight, 10, 10)
    
    -- Draw dialog title
    love.graphics.setColor(1, 1, 1, self.alpha)
    love.graphics.setFont(self.game.assets.fonts.medium)
    love.graphics.printf("Confirmation", dialogX, dialogY + 20, dialogWidth, "center")
    
    -- Draw dialog text
    love.graphics.setColor(0.9, 0.9, 0.9, self.alpha)
    love.graphics.setFont(self.game.assets.fonts.small)
    love.graphics.printf(self.confirmationText, dialogX + 20, dialogY + 60, dialogWidth - 40, "center")
    
    -- Draw cost
    if self.confirmationCost > 0 then
        love.graphics.setColor(0.7, 0.3, 0.9, self.alpha)
        love.graphics.printf("Cost: " .. self.confirmationCost .. " Dark Essence", dialogX + 20, dialogY + 100, dialogWidth - 40, "center")
    end
    
    -- Draw buttons
    -- Confirm button
    love.graphics.setColor(0.3, 0.6, 0.3, 0.8 * self.alpha)
    love.graphics.rectangle("fill", dialogX + 80, dialogY + 140, 100, 30, 5, 5)
    
    love.graphics.setColor(1, 1, 1, self.alpha)
    love.graphics.printf("Confirm", dialogX + 80, dialogY + 145, 100, "center")
    
    -- Cancel button
    love.graphics.setColor(0.6, 0.3, 0.3, 0.8 * self.alpha)
    love.graphics.rectangle("fill", dialogX + 220, dialogY + 140, 100, 30, 5, 5)
    
    love.graphics.setColor(1, 1, 1, self.alpha)
    love.graphics.printf("Cancel", dialogX + 220, dialogY + 145, 100, "center")
end

-- Handle mouse movement
function MetaProgressionUI:mousemoved(x, y)
    if not self.visible then return end
    
    -- Reset selections
    self.selectedUpgrade = nil
    self.selectedCharacter = nil
    self.selectedItem = nil
    self.selectedChallenge = nil
    
    -- Check if mouse is over a tab
    local tabs = {
        {id = "upgrades", name = "Upgrades"},
        {id = "characters", name = "Characters"},
        {id = "items", name = "Starting Items"},
        {id = "challenges", name = "Challenges"},
        {id = "achievements", name = "Achievements"}
    }
    
    local tabWidth = 150
    local tabHeight = 30
    local tabY = self.y + 70
    
    for i, tab in ipairs(tabs) do
        local tabX = self.x + 20 + (i-1) * (tabWidth + 10)
        
        if x >= tabX and x <= tabX + tabWidth and
           y >= tabY and y <= tabY + tabHeight then
            -- Tab is hovered
            break
        end
    end
    
    -- Check content based on current tab
    if self.currentTab == "upgrades" then
        -- Check upgrades
        local contentX = self.x + 30
        local contentY = self.y + 110 + self.scrollPositions.upgrades
        local contentWidth = self.width - 60
        
        local upgradeCategories = {
            {
                title = "Starting Stats",
                upgrades = {
                    {id = "startingHealth", name = "Starting Health", description = "+1 health per level"},
                    {id = "startingEnergy", name = "Starting Energy", description = "+1 energy per level"},
                    {id = "startingGold", name = "Starting Gold", description = "+10 gold per level"}
                }
            },
            {
                title = "Combat Bonuses",
                upgrades = {
                    {id = "attackBonus", name = "Attack Bonus", description = "+1 attack per level"},
                    {id = "defenseBonus", name = "Defense Bonus", description = "+1 defense per level"},
                    {id = "critChance", name = "Critical Chance", description = "+2% crit chance per level"}
                }
            },
            {
                title = "Resource Bonuses",
                upgrades = {
                    {id = "healthRegen", name = "Health Regeneration", description = "+0.5 health regen per level"},
                    {id = "energyRegen", name = "Energy Regeneration", description = "+0.5 energy regen per level"},
                    {id = "goldBonus", name = "Gold Bonus", description = "+5% gold drops per level"}
                }
            },
            {
                title = "Gameplay Bonuses",
                upgrades = {
                    {id = "extraActionPoint", name = "Extra Action Point", description = "+1 action point at level 3"},
                    {id = "movementBonus", name = "Movement Bonus", description = "+1 movement range per level"},
                    {id = "itemSlots", name = "Item Slots", description = "+1 item slot per level"}
                }
            },
            {
                title = "Special Bonuses",
                upgrades = {
                    {id = "reviveChance", name = "Revive Chance", description = "Chance to revive once per run"},
                    {id = "treasureChance", name = "Treasure Chance", description = "Increased chance for treasure rooms"},
                    {id = "eliteDropRate", name = "Elite Drop Rate", description = "Better drops from elite enemies"}
                }
            }
        }
        
        for _, category in ipairs(upgradeCategories) do
            contentY = contentY + 30 -- Skip category title
            
            for _, upgrade in ipairs(category.upgrades) do
                if x >= contentX and x <= contentX + contentWidth - 20 and
                   y >= contentY and y <= contentY + 60 then
                    self.selectedUpgrade = upgrade.id
                    break
                end
                
                contentY = contentY + 70
            end
            
            contentY = contentY + 20
        end
    elseif self.currentTab == "characters" then
        -- Check characters
        local contentX = self.x + 30
        local contentY = self.y + 110 + self.scrollPositions.characters
        local contentWidth = self.width - 60
        
        contentY = contentY + 30 -- Skip title
        
        for _, character in ipairs(self.metaProgression.characters) do
            if x >= contentX and x <= contentX + contentWidth - 20 and
               y >= contentY and y <= contentY + 100 then
                self.selectedCharacter = character.id
                break
            end
            
            contentY = contentY + 110
        end
    elseif self.currentTab == "items" then
        -- Check items
        local contentX = self.x + 30
        local contentY = self.y + 110 + self.scrollPositions.items
        local contentWidth = self.width - 60
        
        contentY = contentY + 30 -- Skip title
        
        for _, item in ipairs(self.metaProgression.startingItems) do
            if x >= contentX and x <= contentX + contentWidth - 20 and
               y >= contentY and y <= contentY + 70 then
                self.selectedItem = item.id
                break
            end
            
            contentY = contentY + 80
        end
    elseif self.currentTab == "challenges" then
        -- Check challenges
        local contentX = self.x + 30
        local contentY = self.y + 110 + self.scrollPositions.challenges
        local contentWidth = self.width - 60
        
        contentY = contentY + 30 -- Skip title
        
        for _, challenge in ipairs(self.metaProgression.challenges.available) do
            if x >= contentX and x <= contentX + contentWidth - 20 and
               y >= contentY and y <= contentY + 70 then
                self.selectedChallenge = challenge.id
                break
            end
            
            contentY = contentY + 80
        end
    end
end

-- Handle mouse press
function MetaProgressionUI:mousepressed(x, y, button)
    if not self.visible then return false end
    
    -- Check if close button was clicked
    if x >= self.x + self.width - 30 and x <= self.x + self.width - 10 and
       y >= self.y + 10 and y <= self.y + 30 then
        self:hide()
        return true
    end
    
    -- Check if confirmation dialog is open
    if self.showConfirmation then
        local dialogWidth = 400
        local dialogHeight = 200
        local dialogX = self.x + (self.width - dialogWidth) / 2
        local dialogY = self.y + (self.height - dialogHeight) / 2
        
        -- Check confirm button
        if x >= dialogX + 80 and x <= dialogX + 180 and
           y >= dialogY + 140 and y <= dialogY + 170 then
            -- Execute confirmation action
            if self.confirmationAction then
                self.confirmationAction()
            end
            
            self.showConfirmation = false
            return true
        end
        
        -- Check cancel button
        if x >= dialogX + 220 and x <= dialogX + 320 and
           y >= dialogY + 140 and y <= dialogY + 170 then
            self.showConfirmation = false
            return true
        end
        
        -- Clicked inside dialog but not on buttons
        if x >= dialogX and x <= dialogX + dialogWidth and
           y >= dialogY and y <= dialogY + dialogHeight then
            return true
        end
        
        -- Clicked outside dialog, close it
        self.showConfirmation = false
        return true
    end
    
    -- Check if a tab was clicked
    local tabs = {
        {id = "upgrades", name = "Upgrades"},
        {id = "characters", name = "Characters"},
        {id = "items", name = "Starting Items"},
        {id = "challenges", name = "Challenges"},
        {id = "achievements", name = "Achievements"}
    }
    
    local tabWidth = 150
    local tabHeight = 30
    local tabY = self.y + 70
    
    for i, tab in ipairs(tabs) do
        local tabX = self.x + 20 + (i-1) * (tabWidth + 10)
        
        if x >= tabX and x <= tabX + tabWidth and
           y >= tabY and y <= tabY + tabHeight then
            self.currentTab = tab.id
            return true
        end
    end
    
    -- Check scroll arrows
    local totalHeight = 0
    local viewHeight = self.height - 120
    
    if self.currentTab == "upgrades" then
        -- Calculate total height for upgrades tab
        totalHeight = 1500 -- Approximate height
    elseif self.currentTab == "characters" then
        totalHeight = 110 * #self.metaProgression.characters + 50
    elseif self.currentTab == "items" then
        totalHeight = 80 * #self.metaProgression.startingItems + 50
    elseif self.currentTab == "challenges" then
        totalHeight = 80 * #self.metaProgression.challenges.available + 50
    elseif self.currentTab == "achievements" then
        totalHeight = 800 -- Approximate height
    end
    
    -- Check up arrow
    if x >= self.x + self.width - 30 and x <= self.x + self.width - 10 and
       y >= self.y + 110 and y <= self.y + 130 and
       self.scrollPositions[self.currentTab] < 0 then
        self.scrollPositions[self.currentTab] = self.scrollPositions[self.currentTab] + 50
        if self.scrollPositions[self.currentTab] > 0 then
            self.scrollPositions[self.currentTab] = 0
        end
        return true
    end
    
    -- Check down arrow
    if x >= self.x + self.width - 30 and x <= self.x + self.width - 10 and
       y >= self.y + self.height - 30 and y <= self.y + self.height - 10 and
       self.scrollPositions[self.currentTab] > -(totalHeight - viewHeight) then
        self.scrollPositions[self.currentTab] = self.scrollPositions[self.currentTab] - 50
        if self.scrollPositions[self.currentTab] < -(totalHeight - viewHeight) then
            self.scrollPositions[self.currentTab] = -(totalHeight - viewHeight)
        end
        return true
    end
    
    -- Check content based on current tab
    if self.currentTab == "upgrades" then
        -- Check upgrade buttons
        local contentX = self.x + 30
        local contentY = self.y + 110 + self.scrollPositions.upgrades
        local contentWidth = self.width - 60
        
        local upgradeCategories = {
            {
                title = "Starting Stats",
                upgrades = {
                    {id = "startingHealth", name = "Starting Health", description = "+1 health per level"},
                    {id = "startingEnergy", name = "Starting Energy", description = "+1 energy per level"},
                    {id = "startingGold", name = "Starting Gold", description = "+10 gold per level"}
                }
            },
            {
                title = "Combat Bonuses",
                upgrades = {
                    {id = "attackBonus", name = "Attack Bonus", description = "+1 attack per level"},
                    {id = "defenseBonus", name = "Defense Bonus", description = "+1 defense per level"},
                    {id = "critChance", name = "Critical Chance", description = "+2% crit chance per level"}
                }
            },
            {
                title = "Resource Bonuses",
                upgrades = {
                    {id = "healthRegen", name = "Health Regeneration", description = "+0.5 health regen per level"},
                    {id = "energyRegen", name = "Energy Regeneration", description = "+0.5 energy regen per level"},
                    {id = "goldBonus", name = "Gold Bonus", description = "+5% gold drops per level"}
                }
            },
            {
                title = "Gameplay Bonuses",
                upgrades = {
                    {id = "extraActionPoint", name = "Extra Action Point", description = "+1 action point at level 3"},
                    {id = "movementBonus", name = "Movement Bonus", description = "+1 movement range per level"},
                    {id = "itemSlots", name = "Item Slots", description = "+1 item slot per level"}
                }
            },
            {
                title = "Special Bonuses",
                upgrades = {
                    {id = "reviveChance", name = "Revive Chance", description = "Chance to revive once per run"},
                    {id = "treasureChance", name = "Treasure Chance", description = "Increased chance for treasure rooms"},
                    {id = "eliteDropRate", name = "Elite Drop Rate", description = "Better drops from elite enemies"}
                }
            }
        }
        
        for _, category in ipairs(upgradeCategories) do
            contentY = contentY + 30 -- Skip category title
            
            for _, upgrade in ipairs(category.upgrades) do
                -- Check upgrade button
                if x >= contentX + contentWidth - 100 and x <= contentX + contentWidth - 20 and
                   y >= contentY + 20 and y <= contentY + 50 then
                    self:purchaseUpgrade(upgrade.id)
                    return true
                end
                
                contentY = contentY + 70
            end
            
            contentY = contentY + 20
        end
    elseif self.currentTab == "characters" then
        -- Check character unlock buttons
        local contentX = self.x + 30
        local contentY = self.y + 110 + self.scrollPositions.characters
        local contentWidth = self.width - 60
        
        contentY = contentY + 30 -- Skip title
        
        for _, character in ipairs(self.metaProgression.characters) do
            if not character.unlocked then
                -- Check unlock button
                if x >= contentX + contentWidth - 150 and x <= contentX + contentWidth - 50 and
                   y >= contentY + 40 and y <= contentY + 70 then
                    self:unlockCharacter(character.id)
                    return true
                end
            end
            
            contentY = contentY + 110
        end
    elseif self.currentTab == "items" then
        -- Check item unlock buttons
        local contentX = self.x + 30
        local contentY = self.y + 110 + self.scrollPositions.items
        local contentWidth = self.width - 60
        
        contentY = contentY + 30 -- Skip title
        
        for _, item in ipairs(self.metaProgression.startingItems) do
            if not item.unlocked then
                -- Check unlock button
                if x >= contentX + contentWidth - 150 and x <= contentX + contentWidth - 50 and
                   y >= contentY + 35 and y <= contentY + 65 then
                    self:unlockStartingItem(item.id)
                    return true
                end
            end
            
            contentY = contentY + 80
        end
    elseif self.currentTab == "challenges" then
        -- Check challenge activate buttons
        local contentX = self.x + 30
        local contentY = self.y + 110 + self.scrollPositions.challenges
        local contentWidth = self.width - 60
        
        contentY = contentY + 30 -- Skip title
        
        for _, challenge in ipairs(self.metaProgression.challenges.available) do
            if not challenge.completed then
                -- Check activate button
                if x >= contentX + contentWidth - 150 and x <= contentX + contentWidth - 50 and
                   y >= contentY + 35 and y <= contentY + 65 then
                    self:activateChallenge(challenge.id)
                    return true
                end
            end
            
            contentY = contentY + 80
        end
    end
    
    return false
end

-- Purchase upgrade
function MetaProgressionUI:purchaseUpgrade(upgradeId)
    if not self.metaProgression then return end
    
    local upgradeCost = self.metaProgression:getUpgradeCost(upgradeId)
    local currentEssence = self.metaProgression:getDarkEssence()
    
    if currentEssence >= upgradeCost then
        -- Show confirmation dialog
        self.showConfirmation = true
        self.confirmationText = "Are you sure you want to purchase the " .. upgradeId:gsub("([A-Z])", " %1"):gsub("^%l", string.upper) .. " upgrade?"
        self.confirmationCost = upgradeCost
        self.confirmationAction = function()
            self.metaProgression:purchaseUpgrade(upgradeId)
        end
    else
        -- Not enough essence
        print("Not enough Dark Essence to purchase this upgrade")
    end
end

-- Unlock character
function MetaProgressionUI:unlockCharacter(characterId)
    if not self.metaProgression then return end
    
    local character = nil
    for _, c in ipairs(self.metaProgression.characters) do
        if c.id == characterId then
            character = c
            break
        end
    end
    
    if not character then return end
    
    local characterCost = character.cost
    local currentEssence = self.metaProgression:getDarkEssence()
    
    if currentEssence >= characterCost then
        -- Show confirmation dialog
        self.showConfirmation = true
        self.confirmationText = "Are you sure you want to unlock the " .. character.name .. " character?"
        self.confirmationCost = characterCost
        self.confirmationAction = function()
            self.metaProgression:unlockCharacter(characterId)
        end
    else
        -- Not enough essence
        print("Not enough Dark Essence to unlock this character")
    end
end

-- Unlock starting item
function MetaProgressionUI:unlockStartingItem(itemId)
    if not self.metaProgression then return end
    
    local item = nil
    for _, i in ipairs(self.metaProgression.startingItems) do
        if i.id == itemId then
            item = i
            break
        end
    end
    
    if not item then return end
    
    local itemCost = item.cost
    local currentEssence = self.metaProgression:getDarkEssence()
    
    if currentEssence >= itemCost then
        -- Show confirmation dialog
        self.showConfirmation = true
        self.confirmationText = "Are you sure you want to unlock the " .. item.name .. " starting item?"
        self.confirmationCost = itemCost
        self.confirmationAction = function()
            self.metaProgression:unlockStartingItem(itemId)
        end
    else
        -- Not enough essence
        print("Not enough Dark Essence to unlock this item")
    end
end

-- Activate challenge
function MetaProgressionUI:activateChallenge(challengeId)
    if not self.metaProgression then return end
    
    local challenge = nil
    for _, c in ipairs(self.metaProgression.challenges.available) do
        if c.id == challengeId then
            challenge = c
            break
        end
    end
    
    if not challenge then return end
    
    -- Show confirmation dialog
    self.showConfirmation = true
    self.confirmationText = "Are you sure you want to activate the " .. challenge.name .. " challenge? This will apply to your next run."
    self.confirmationCost = 0
    self.confirmationAction = function()
        self.metaProgression:activateChallenge(challengeId)
    end
end

return MetaProgressionUI
