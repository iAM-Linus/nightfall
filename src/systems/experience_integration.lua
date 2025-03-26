-- Experience System Integration for Nightfall Chess
-- Connects the Experience System to the game and combat states

local class = require("lib.middleclass.middleclass")
local timer = require("lib.hump.timer")

local ExperienceIntegration = class("ExperienceIntegration")

function ExperienceIntegration:initialize(game, experienceSystem)
    self.game = game
    self.experienceSystem = experienceSystem
    
    -- UI elements
    self.levelUpNotifications = {}
    self.expGainNotifications = {}
    
    -- Animation timers
    self.animationTimers = {}
    
    -- Level up queue (to handle multiple level ups)
    self.levelUpQueue = {}
    
    -- Experience gain visual effects
    self.expGainEffects = {}
    
    -- Skill point allocation pending flag
    self.pendingSkillPoints = {}
end

-- Connect to combat system
function ExperienceIntegration:connectToCombatSystem(combatSystem)
    if not combatSystem then return end
    
    -- Hook into combat events
    local originalProcessAttack = combatSystem.processAttack
    
    combatSystem.processAttack = function(self, attacker, defender, ...)
        local damage, isCritical, isMiss = originalProcessAttack(self, attacker, defender, ...)
        
        -- Check if defender was defeated
        if defender.stats.health <= 0 then
            -- Award experience for defeating an enemy
            if attacker.faction == "player" and defender.faction == "enemy" then
                ExperienceIntegration:awardDefeatExperience(attacker, defender)
            end
        end
        
        return damage, isCritical, isMiss
    end
end

-- Connect to turn manager
function ExperienceIntegration:connectToTurnManager(turnManager)
    if not turnManager then return end
    
    -- Hook into turn events
    local originalEndTurn = turnManager.endTurn
    
    turnManager.endTurn = function(self, ...)
        -- Process any pending level ups before ending turn
        ExperienceIntegration:processPendingLevelUps()
        
        return originalEndTurn(self, ...)
    end
end

-- Award experience for defeating an enemy
function ExperienceIntegration:awardDefeatExperience(attacker, defeated)
    if not self.experienceSystem then return end
    
    -- Calculate experience amount
    local expAmount = self.experienceSystem:calculateEnemyDefeatExp(defeated)
    
    -- Award experience to attacker
    self:awardExperienceWithEffects(attacker, expAmount, {
        source = "defeat",
        defeatedUnit = defeated
    })
    
    -- Award reduced experience to nearby allies
    local allies = self.experienceSystem:getNearbyAllies(attacker, 3)
    for _, ally in ipairs(allies) do
        -- Allies get 50% of the experience
        local allyExp = math.floor(expAmount * 0.5)
        self:awardExperienceWithEffects(ally, allyExp, {
            source = "assist",
            defeatedUnit = defeated
        })
    end
end

-- Award experience with visual effects
function ExperienceIntegration:awardExperienceWithEffects(unit, amount, source)
    if not self.experienceSystem then return end
    
    -- Award the experience
    local leveledUp = self.experienceSystem:awardExperience(unit, amount, source)
    
    -- Create visual effect for experience gain
    self:createExpGainEffect(unit, amount)
    
    -- If unit leveled up, add to level up queue
    if leveledUp then
        table.insert(self.levelUpQueue, unit)
        
        -- Mark unit as having pending skill points
        self.pendingSkillPoints[unit] = true
    end
end

-- Create visual effect for experience gain
function ExperienceIntegration:createExpGainEffect(unit, amount)
    if not unit or not unit.grid then return end
    
    -- Create floating text effect
    local effect = {
        x = unit.x,
        y = unit.y,
        text = "+" .. amount .. " EXP",
        color = {0.3, 0.8, 1.0},
        alpha = 1.0,
        offsetY = 0,
        lifetime = 2.0,
        timer = 0
    }
    
    table.insert(self.expGainEffects, effect)
    
    -- Create notification
    self:addExpGainNotification(unit, amount)
end

-- Add experience gain notification
function ExperienceIntegration:addExpGainNotification(unit, amount)
    local notification = {
        text = unit.unitType:upper() .. " gained " .. amount .. " experience",
        timer = 3.0,
        alpha = 1.0
    }
    
    table.insert(self.expGainNotifications, notification)
    
    -- Limit number of notifications
    if #self.expGainNotifications > 5 then
        table.remove(self.expGainNotifications, 1)
    end
end

-- Process pending level ups
function ExperienceIntegration:processPendingLevelUps()
    if #self.levelUpQueue == 0 then return end
    
    -- Process one level up at a time
    local unit = table.remove(self.levelUpQueue, 1)
    
    -- Create level up notification
    self:createLevelUpNotification(unit)
    
    -- If in combat, pause for level up screen
    if self.game.currentState == "combat" then
        -- Would show level up screen here
    end
end

-- Create level up notification
function ExperienceIntegration:createLevelUpNotification(unit)
    local notification = {
        text = unit.unitType:upper() .. " reached level " .. unit.level .. "!",
        timer = 5.0,
        alpha = 1.0,
        isLevelUp = true
    }
    
    table.insert(self.levelUpNotifications, notification)
    
    -- Limit number of notifications
    if #self.levelUpNotifications > 3 then
        table.remove(self.levelUpNotifications, 1)
    end
    
    -- Play level up sound
    -- self.game.audio:playSound("level_up")
    
    -- Create visual effect on unit
    self:createLevelUpEffect(unit)
end

-- Create visual effect for level up
function ExperienceIntegration:createLevelUpEffect(unit)
    if not unit or not unit.grid then return end
    
    -- Store animation timer
    self.animationTimers[unit] = 2.0
    
    -- Create particle effect or animation
    -- Would be implemented with a particle system
end

-- Update experience integration
function ExperienceIntegration:update(dt)
    -- Update experience gain effects
    for i = #self.expGainEffects, 1, -1 do
        local effect = self.expGainEffects[i]
        effect.timer = effect.timer + dt
        effect.offsetY = effect.offsetY - 20 * dt
        effect.alpha = 1.0 - (effect.timer / effect.lifetime)
        
        if effect.timer >= effect.lifetime then
            table.remove(self.expGainEffects, i)
        end
    end
    
    -- Update notifications
    for i = #self.expGainNotifications, 1, -1 do
        local notification = self.expGainNotifications[i]
        notification.timer = notification.timer - dt
        
        if notification.timer <= 0 then
            table.remove(self.expGainNotifications, i)
        elseif notification.timer < 1.0 then
            notification.alpha = notification.timer
        end
    end
    
    for i = #self.levelUpNotifications, 1, -1 do
        local notification = self.levelUpNotifications[i]
        notification.timer = notification.timer - dt
        
        if notification.timer <= 0 then
            table.remove(self.levelUpNotifications, i)
        elseif notification.timer < 1.0 then
            notification.alpha = notification.timer
        end
    end
    
    -- Update animation timers
    for unit, time in pairs(self.animationTimers) do
        self.animationTimers[unit] = time - dt
        
        if self.animationTimers[unit] <= 0 then
            self.animationTimers[unit] = nil
        end
    end
    
    -- Process level up queue with delay
    if #self.levelUpQueue > 0 and not self.levelUpProcessing then
        self.levelUpProcessing = true
        
        timer.after(1.0, function()
            self:processPendingLevelUps()
            self.levelUpProcessing = false
        end)
    end
end

-- Draw experience integration UI
function ExperienceIntegration:draw()
    -- Draw experience gain effects
    for _, effect in ipairs(self.expGainEffects) do
        local screenX, screenY = nil, nil
        
        -- Convert grid position to screen position
        if self.game.grid then
            screenX, screenY = self.game.grid:gridToScreen(effect.x, effect.y)
            screenX = screenX + self.game.grid.tileSize / 2
            screenY = screenY + effect.offsetY
        else
            -- Fallback if grid not available
            screenX, screenY = 400, 300
        end
        
        love.graphics.setColor(effect.color[1], effect.color[2], effect.color[3], effect.alpha)
        love.graphics.printf(effect.text, screenX - 50, screenY, 100, "center")
    end
    
    -- Draw notifications
    local width, height = love.graphics.getDimensions()
    
    -- Draw experience gain notifications
    for i, notification in ipairs(self.expGainNotifications) do
        love.graphics.setColor(0.3, 0.8, 1.0, notification.alpha * 0.8)
        love.graphics.printf(notification.text, 10, height - 120 - (i-1) * 20, 300, "left")
    end
    
    -- Draw level up notifications
    for i, notification in ipairs(self.levelUpNotifications) do
        if notification.isLevelUp then
            -- Draw with special styling for level ups
            love.graphics.setColor(1.0, 0.8, 0.2, notification.alpha * 0.9)
            
            -- Draw background
            love.graphics.rectangle("fill", width/2 - 150, 100 + (i-1) * 40, 300, 30, 5, 5)
            
            -- Draw text
            love.graphics.setColor(0.1, 0.1, 0.1, notification.alpha)
            love.graphics.printf(notification.text, width/2 - 145, 105 + (i-1) * 40, 290, "center")
        else
            -- Draw regular notification
            love.graphics.setColor(0.8, 0.8, 1.0, notification.alpha * 0.8)
            love.graphics.printf(notification.text, width - 310, 100 + (i-1) * 20, 300, "right")
        end
    end
    
    -- Draw level up effects on units
    for unit, time in pairs(self.animationTimers) do
        if unit and unit.grid then
            local screenX, screenY = unit.grid:gridToScreen(unit.x, unit.y)
            screenX = screenX + unit.grid.tileSize / 2
            screenY = screenY + unit.grid.tileSize / 2
            
            -- Draw glow effect
            local size = unit.grid.tileSize * (1.2 + math.sin(love.timer.getTime() * 5) * 0.1)
            local alpha = time / 2.0
            
            love.graphics.setColor(1.0, 0.8, 0.2, alpha * 0.7)
            love.graphics.circle("fill", screenX, screenY, size)
            
            love.graphics.setColor(1.0, 1.0, 1.0, alpha)
            love.graphics.circle("line", screenX, screenY, size)
        end
    end
    
    -- Draw skill point indicators
    for unit, _ in pairs(self.pendingSkillPoints) do
        if unit and unit.grid then
            local screenX, screenY = unit.grid:gridToScreen(unit.x, unit.y)
            
            love.graphics.setColor(0.2, 0.8, 0.2, 0.8 + math.sin(love.timer.getTime() * 3) * 0.2)
            love.graphics.circle("fill", screenX + unit.grid.tileSize - 5, screenY + 5, 5)
        end
    end
end

-- Show skill tree UI for a unit
function ExperienceIntegration:showSkillTreeUI(unit)
    if not unit or not unit.skillTree then return end
    
    -- This would be implemented with a proper UI system
    -- For now, just mark skill points as spent
    self.pendingSkillPoints[unit] = nil
    
    -- Auto-allocate skill points for demonstration
    if unit.skillPoints > 0 and unit.skillTree then
        local skillTrees = {}
        for name, _ in pairs(unit.skillTree) do
            table.insert(skillTrees, name)
        end
        
        if #skillTrees > 0 then
            local randomSkill = skillTrees[math.random(#skillTrees)]
            self.experienceSystem:improveSkill(unit, randomSkill)
            unit.skillPoints = unit.skillPoints - 1
        end
    end
end

-- Check if a unit has pending skill points
function ExperienceIntegration:hasPendingSkillPoints(unit)
    return self.pendingSkillPoints[unit] == true
end

-- Handle mouse click on unit
function ExperienceIntegration:handleUnitClick(unit)
    if self:hasPendingSkillPoints(unit) then
        self:showSkillTreeUI(unit)
        return true
    end
    return false
end

return ExperienceIntegration
