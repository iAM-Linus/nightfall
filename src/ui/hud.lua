-- HUD (Heads-Up Display) for Nightfall Chess
-- Provides UI elements for displaying game information during gameplay

local class = require("lib.middleclass.middleclass")
local timer = require("lib.hump.timer")

local HUD = class("HUD")

function HUD:initialize(game)
    self.game = game
    
    -- HUD elements
    self.elements = {}
    
    -- Animation timers
    self.animations = {}
    
    -- HUD state
    self.visible = true
    self.alpha = 1
    
    -- Initialize HUD elements
    self:initElements()
end

-- Initialize HUD elements
function HUD:initElements()
    -- Create turn indicator
    self.elements.turnIndicator = {
        x = 0,
        y = 20,
        width = love.graphics.getWidth(),
        height = 30,
        text = "Player Turn",
        align = "center",
        font = self.game.assets.fonts.medium,
        color = {1, 1, 1, 1},
        backgroundColor = {0.2, 0.2, 0.3, 0.7},
        borderColor = {0.4, 0.4, 0.5, 0.8},
        visible = true,
        
        update = function(self, dt)
            -- Animation updates if needed
        end,
        
        draw = function(self)
            -- Draw background
            love.graphics.setColor(self.backgroundColor)
            love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
            
            -- Draw border
            love.graphics.setColor(self.borderColor)
            love.graphics.rectangle("line", self.x, self.y, self.width, self.height)
            
            -- Draw text
            love.graphics.setColor(self.color)
            love.graphics.setFont(self.font)
            love.graphics.printf(self.text, self.x, self.y + 5, self.width, self.align)
        end
    }
    
    -- Create action points indicator
    self.elements.actionPoints = {
        x = 0,
        y = 50,
        width = love.graphics.getWidth(),
        height = 25,
        value = 3,
        maxValue = 3,
        text = "Action Points: ",
        align = "center",
        font = self.game.assets.fonts.medium,
        color = {1, 1, 1, 1},
        valueColor = {0.9, 0.9, 0.2, 1},
        visible = true,
        
        update = function(self, dt)
            -- Animation updates if needed
        end,
        
        draw = function(self)
            -- Draw text
            love.graphics.setColor(self.color)
            love.graphics.setFont(self.font)
            
            local fullText = self.text .. self.value .. "/" .. self.maxValue
            love.graphics.printf(fullText, self.x, self.y, self.width, self.align)
            
            -- Draw action point indicators
            local indicatorWidth = 20
            local indicatorHeight = 10
            local totalWidth = self.maxValue * (indicatorWidth + 5)
            local startX = (self.width - totalWidth) / 2
            
            for i = 1, self.maxValue do
                if i <= self.value then
                    love.graphics.setColor(0.9, 0.9, 0.2, 1)
                else
                    love.graphics.setColor(0.4, 0.4, 0.4, 0.7)
                end
                
                love.graphics.rectangle("fill", startX + (i-1) * (indicatorWidth + 5), self.y + 20, indicatorWidth, indicatorHeight)
                love.graphics.setColor(0.8, 0.8, 0.8, 0.5)
                love.graphics.rectangle("line", startX + (i-1) * (indicatorWidth + 5), self.y + 20, indicatorWidth, indicatorHeight)
            end
        end,
        
        setValue = function(self, value)
            self.value = math.min(value, self.maxValue)
        end
    }
    
    -- Create unit info panel
    self.elements.unitInfo = {
        x = 10,
        y = love.graphics.getHeight() - 100,
        width = 200,
        height = 90,
        unit = nil,
        font = self.game.assets.fonts.small,
        titleFont = self.game.assets.fonts.medium,
        backgroundColor = {0.2, 0.2, 0.3, 0.8},
        borderColor = {0.5, 0.5, 0.6, 1},
        textColor = {0.9, 0.9, 0.9, 1},
        statColors = {
            health = {0.2, 0.8, 0.2, 1},
            energy = {0.2, 0.7, 0.9, 1},
            attack = {0.9, 0.2, 0.2, 1},
            defense = {0.2, 0.2, 0.9, 1},
            moveRange = {0.9, 0.7, 0.2, 1}
        },
        visible = false,
        
        update = function(self, dt)
            -- Animation updates if needed
        end,
        
        draw = function(self)
            if not self.unit then return end
            
            -- Draw background
            love.graphics.setColor(self.backgroundColor)
            love.graphics.rectangle("fill", self.x, self.y, self.width, self.height, 5, 5)
            
            -- Draw border
            love.graphics.setColor(self.borderColor)
            love.graphics.rectangle("line", self.x, self.y, self.width, self.height, 5, 5)
            
            -- Draw unit name/type
            love.graphics.setColor(self.textColor)
            love.graphics.setFont(self.titleFont)
            love.graphics.print(self.unit.unitType:upper(), self.x + 10, self.y + 5)
            
            -- Draw unit stats
            love.graphics.setFont(self.font)
            
            -- Health
            love.graphics.setColor(self.statColors.health)
            love.graphics.print("HP: " .. self.unit.stats.health .. "/" .. self.unit.stats.maxHealth, self.x + 10, self.y + 30)
            
            -- Energy if available
            if self.unit.stats.energy then
                love.graphics.setColor(self.statColors.energy)
                love.graphics.print("EP: " .. self.unit.stats.energy .. "/" .. self.unit.stats.maxEnergy, self.x + 10, self.y + 45)
            end
            
            -- Attack
            love.graphics.setColor(self.statColors.attack)
            love.graphics.print("ATK: " .. self.unit.stats.attack, self.x + 10, self.y + 60)
            
            -- Defense
            love.graphics.setColor(self.statColors.defense)
            love.graphics.print("DEF: " .. self.unit.stats.defense, self.x + 100, self.y + 60)
            
            -- Move range
            love.graphics.setColor(self.statColors.moveRange)
            love.graphics.print("MOV: " .. self.unit.stats.moveRange, self.x + 10, self.y + 75)
        end,
        
        setUnit = function(self, unit)
            self.unit = unit
            self.visible = (unit ~= nil)
        end
    }
    
    -- Create enemy info panel
    self.elements.enemyInfo = {
        x = love.graphics.getWidth() - 210,
        y = love.graphics.getHeight() - 100,
        width = 200,
        height = 90,
        unit = nil,
        font = self.game.assets.fonts.small,
        titleFont = self.game.assets.fonts.medium,
        backgroundColor = {0.3, 0.2, 0.2, 0.8},
        borderColor = {0.6, 0.5, 0.5, 1},
        textColor = {0.9, 0.9, 0.9, 1},
        statColors = {
            health = {0.2, 0.8, 0.2, 1},
            energy = {0.2, 0.7, 0.9, 1},
            attack = {0.9, 0.2, 0.2, 1},
            defense = {0.2, 0.2, 0.9, 1},
            moveRange = {0.9, 0.7, 0.2, 1}
        },
        visible = false,
        
        update = function(self, dt)
            -- Animation updates if needed
        end,
        
        draw = function(self)
            if not self.unit then return end
            
            -- Draw background
            love.graphics.setColor(self.backgroundColor)
            love.graphics.rectangle("fill", self.x, self.y, self.width, self.height, 5, 5)
            
            -- Draw border
            love.graphics.setColor(self.borderColor)
            love.graphics.rectangle("line", self.x, self.y, self.width, self.height, 5, 5)
            
            -- Draw unit name/type
            love.graphics.setColor(self.textColor)
            love.graphics.setFont(self.titleFont)
            love.graphics.print(self.unit.unitType:upper(), self.x + 10, self.y + 5)
            
            -- Draw unit stats
            love.graphics.setFont(self.font)
            
            -- Health
            love.graphics.setColor(self.statColors.health)
            love.graphics.print("HP: " .. self.unit.stats.health .. "/" .. self.unit.stats.maxHealth, self.x + 10, self.y + 30)
            
            -- Energy if available
            if self.unit.stats.energy then
                love.graphics.setColor(self.statColors.energy)
                love.graphics.print("EP: " .. self.unit.stats.energy .. "/" .. self.unit.stats.maxEnergy, self.x + 10, self.y + 45)
            end
            
            -- Attack
            love.graphics.setColor(self.statColors.attack)
            love.graphics.print("ATK: " .. self.unit.stats.attack, self.x + 10, self.y + 60)
            
            -- Defense
            love.graphics.setColor(self.statColors.defense)
            love.graphics.print("DEF: " .. self.unit.stats.defense, self.x + 100, self.y + 60)
            
            -- Move range
            love.graphics.setColor(self.statColors.moveRange)
            love.graphics.print("MOV: " .. self.unit.stats.moveRange, self.x + 10, self.y + 75)
        end,
        
        setUnit = function(self, unit)
            self.unit = unit
            self.visible = (unit ~= nil)
        end
    }
    
    -- Create help text panel
    self.elements.helpText = {
        x = 10,
        y = love.graphics.getHeight() - 25,
        width = love.graphics.getWidth() - 20,
        height = 20,
        text = "WASD/Arrows: Move | Space: Select/Action | Tab: Next Unit | Enter: End Turn | Esc: Menu",
        font = self.game.assets.fonts.small,
        color = {0.8, 0.8, 0.8, 0.8},
        visible = true,
        
        update = function(self, dt)
            -- Animation updates if needed
        end,
        
        draw = function(self)
            love.graphics.setColor(self.color)
            love.graphics.setFont(self.font)
            love.graphics.print(self.text, self.x, self.y)
        end,
        
        setText = function(self, text)
            self.text = text
        end
    }
    
    -- Create notification system
    self.elements.notification = {
        x = love.graphics.getWidth() / 2 - 150,
        y = 100,
        width = 300,
        height = 40,
        text = "",
        font = self.game.assets.fonts.medium,
        backgroundColor = {0.2, 0.2, 0.3, 0.9},
        borderColor = {0.5, 0.5, 0.6, 1},
        textColor = {1, 1, 1, 1},
        visible = false,
        duration = 0,
        maxDuration = 3,
        
        update = function(self, dt)
            if self.visible then
                self.duration = self.duration - dt
                if self.duration <= 0 then
                    self.visible = false
                end
                
                -- Fade out near the end
                if self.duration < 1 then
                    self.textColor[4] = self.duration
                    self.backgroundColor[4] = self.duration * 0.9
                    self.borderColor[4] = self.duration
                end
            end
        end,
        
        draw = function(self)
            if not self.visible then return end
            
            -- Draw background
            love.graphics.setColor(self.backgroundColor)
            love.graphics.rectangle("fill", self.x, self.y, self.width, self.height, 5, 5)
            
            -- Draw border
            love.graphics.setColor(self.borderColor)
            love.graphics.rectangle("line", self.x, self.y, self.width, self.height, 5, 5)
            
            -- Draw text
            love.graphics.setColor(self.textColor)
            love.graphics.setFont(self.font)
            love.graphics.printf(self.text, self.x + 10, self.y + 10, self.width - 20, "center")
        end,
        
        show = function(self, text, duration)
            self.text = text
            self.duration = duration or self.maxDuration
            self.visible = true
            self.textColor[4] = 1
            self.backgroundColor[4] = 0.9
            self.borderColor[4] = 1
        end
    }
    
    -- Create mini-map (placeholder)
    self.elements.miniMap = {
        x = love.graphics.getWidth() - 110,
        y = 10,
        width = 100,
        height = 100,
        grid = nil,
        backgroundColor = {0.1, 0.1, 0.15, 0.8},
        borderColor = {0.4, 0.4, 0.5, 1},
        tileColors = {
            floor = {0.5, 0.5, 0.5},
            wall = {0.3, 0.3, 0.3},
            water = {0.2, 0.2, 0.8},
            lava = {0.8, 0.2, 0.2},
            grass = {0.2, 0.7, 0.2}
        },
        unitColors = {
            player = {0.2, 0.6, 1},
            enemy = {1, 0.3, 0.3},
            neutral = {0.7, 0.7, 0.7}
        },
        visible = false,
        
        update = function(self, dt)
            -- Animation updates if needed
        end,
        
        draw = function(self)
            if not self.grid then return end
            
            -- Draw background
            love.graphics.setColor(self.backgroundColor)
            love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
            
            -- Draw border
            love.graphics.setColor(self.borderColor)
            love.graphics.rectangle("line", self.x, self.y, self.width, self.height)
            
            -- Calculate tile size
            local tileSize = math.min(
                self.width / self.grid.width,
                self.height / self.grid.height
            )
            
            -- Draw tiles
            for y = 1, self.grid.height do
                for x = 1, self.grid.width do
                    local tile = self.grid:getTile(x, y)
                    
                    -- Skip if not explored and fog of war is enabled
                    if self.grid.fogOfWar and not tile.explored then
                        goto continue
                    end
                    
                    local pixelX = self.x + (x - 1) * tileSize
                    local pixelY = self.y + (y - 1) * tileSize
                    
                    -- Draw tile
                    local color = self.tileColors[tile.type] or self.tileColors.floor
                    
                    -- Apply fog of war effect
                    if self.grid.fogOfWar and not tile.visible and tile.explored then
                        -- Darken explored but not visible tiles
                        color = {color[1] * 0.5, color[2] * 0.5, color[3] * 0.5}
                    end
                    
                    love.graphics.setColor(color)
                    love.graphics.rectangle("fill", pixelX, pixelY, tileSize, tileSize)
                    
                    -- Draw entity if present
                    if tile.entity then
                        local entityColor = self.unitColors[tile.entity.faction] or self.unitColors.neutral
                        love.graphics.setColor(entityColor)
                        love.graphics.rectangle("fill", pixelX + tileSize * 0.25, pixelY + tileSize * 0.25, tileSize * 0.5, tileSize * 0.5)
                    end
                    
                    ::continue::
                end
            end
        end,
        
        setGrid = function(self, grid)
            self.grid = grid
            self.visible = (grid ~= nil)
        end
    }
    
    -- Create level indicator
    self.elements.levelIndicator = {
        x = 10,
        y = 10,
        width = 100,
        height = 25,
        level = 1,
        font = self.game.assets.fonts.small,
        color = {0.9, 0.9, 0.9, 1},
        visible = true,
        
        update = function(self, dt)
            -- Animation updates if needed
        end,
        
        draw = function(self)
            love.graphics.setColor(self.color)
            love.graphics.setFont(self.font)
            love.graphics.print("Level: " .. self.level, self.x, self.y)
        end,
        
        setLevel = function(self, level)
            self.level = level
        end
    }
end

-- Update HUD
function HUD:update(dt)
    -- Update animations
    timer.update(dt)
    
    -- Update HUD elements
    for name, element in pairs(self.elements) do
        if element.visible and element.update then
            element:update(dt)
        end
    end
end

-- Draw HUD
function HUD:draw()
    if not self.visible then return end
    
    -- Draw HUD elements
    for name, element in pairs(self.elements) do
        if element.visible then
            element:draw()
        end
    end
end

-- Show notification
function HUD:showNotification(text, duration)
    self.elements.notification:show(text, duration)
end

-- Set player turn
function HUD:setPlayerTurn(isPlayerTurn)
    if isPlayerTurn then
        self.elements.turnIndicator.text = "Player Turn"
        self.elements.turnIndicator.backgroundColor = {0.2, 0.2, 0.3, 0.7}
    else
        self.elements.turnIndicator.text = "Enemy Turn"
        self.elements.turnIndicator.backgroundColor = {0.3, 0.2, 0.2, 0.7}
    end
end

-- Set action points
function HUD:setActionPoints(current, max)
    self.elements.actionPoints.value = current
    self.elements.actionPoints.maxValue = max
end

-- Set selected unit
function HUD:setSelectedUnit(unit)
    self.elements.unitInfo:setUnit(unit)
end

-- Set target unit
function HUD:setTargetUnit(unit)
    self.elements.enemyInfo:setUnit(unit)
end

-- Set help text
function HUD:setHelpText(text)
    self.elements.helpText.text = text
end

-- Set grid for minimap
function HUD:setGrid(grid)
    self.elements.miniMap:setGrid(grid)
end

-- Set current level
function HUD:setLevel(level)
    self.elements.levelIndicator.level = level
end

-- Show HUD
function HUD:show()
    self.visible = true
end

-- Hide HUD
function HUD:hide()
    self.visible = false
end

-- Resize HUD elements
function HUD:resize(width, height)
    -- Update elements that depend on screen size
    self.elements.turnIndicator.width = width
    self.elements.actionPoints.width = width
    self.elements.unitInfo.y = height - 100
    self.elements.enemyInfo.x = width - 210
    self.elements.enemyInfo.y = height - 100
    self.elements.helpText.y = height - 25
    self.elements.helpText.width = width - 20
    self.elements.notification.x = width / 2 - 150
    self.elements.miniMap.x = width - 110
end

return HUD
