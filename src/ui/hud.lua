-- Enhanced HUD (Heads-Up Display) for Nightfall Chess
-- Implements redesigned UI with improved unit information, minimap, and turn order tracking

local class = require("lib.middleclass.middleclass")
local timer = require("lib.hump.timer")

local HUD = class("HUD")

-- Color definitions
local COLORS = {
    background = {0.1, 0.1, 0.2, 0.8},
    panel = {0.15, 0.15, 0.25, 0.9},
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
    player = {0.2, 0.6, 0.9, 1},
    enemy = {0.9, 0.3, 0.3, 1},
    neutral = {0.7, 0.7, 0.7, 1},
    highlight = {1, 1, 1, 0.3},
    shadow = {0, 0, 0, 0.5},
    rarity = {
        common = {0.8, 0.8, 0.8, 1},
        uncommon = {0.2, 0.8, 0.2, 1},
        rare = {0.2, 0.2, 0.9, 1},
        epic = {0.8, 0.2, 0.8, 1},
        legendary = {0.9, 0.6, 0.1, 1}
    }
}

function HUD:initialize(game)
    self.game = game

    -- Create ability panel
    self.abilityPanel = require("src.ui.ability_panel"):new(game)
    self.abilityPanel.width = 400 -- Give it a reasonable width
    self.abilityPanel.height = 80 -- Give it a reasonable height

    -- HUD elements
    self.elements = {}

    -- Animation timers
    self.animations = {}
    
    -- HUD state
    self.visible = true
    self.alpha = 1
    self.showMinimap = true
    self.showTurnOrder = true
    self.showNotifications = true
    self.activeTooltip = nil
    self.hoveredElement = nil
    self.selectedAbility = nil
    
    -- Notification system
    self.notifications = {}
    self.notificationDuration = 3 -- seconds
    
    -- Turn order tracking
    self.turnOrder = {}
    self.currentTurnIndex = 1

    self.currentTurnNum = 1 -- Add field to store turn number
    self.currentRoundNum = 1 -- Add field to store round number
    
    -- Resources
    self.resources = {
        gold = 0,
        actionPoints = 3,
        maxActionPoints = 3
    }
    
    -- Game state
    self.isPlayerTurn = true
    self.currentLevel = 1
    self.helpText = ""
    self.grid = nil

    -- Initialize HUD elements (calls the repositioned initElements)
    self:initElements()

    -- *** FIX: Position ability panel relative to action panel ***
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    local actionPanelHeight = self.elements.actionPanel.height or 50
    local bottomMargin = 10 -- Consistent margin from bottom

    self.abilityPanel:setPosition(
        (screenWidth - self.abilityPanel.width) / 2,
        screenHeight - actionPanelHeight - self.abilityPanel.height - bottomMargin - 5 -- Place it 5px above action panel
    )
    self.abilityPanel.game = game -- Ensure game reference is set

end

-- Initialize HUD elements (REPOSITIONED)
function HUD:initElements()
    local screenWidth, screenHeight = love.graphics.getDimensions()
    local margin = 10 -- General margin from screen edges
    local topBarHeight = 40
    local bottomBarHeight = 50 -- Height of the action panel
    local sidePanelWidth = 250
    local sidePanelHeight = 170
    local bottomMargin = 10 -- Space above bottom elements

    -- Top bar with player resources
    self.elements.topBar = {
        x = 0,
        y = 0,
        width = screenWidth,
        height = topBarHeight,
        backgroundColor = COLORS.background,
        borderColor = COLORS.border,
        visible = true,
        update = function(element_self, dt) end,
        draw = function(element_self)
            -- Draw background
            love.graphics.setColor(element_self.backgroundColor)
            love.graphics.rectangle("fill", element_self.x, element_self.y, element_self.width, element_self.height)
            love.graphics.setColor(element_self.borderColor)
            love.graphics.rectangle("line", element_self.x, element_self.y, element_self.width, element_self.height)

            if not self.game or not self.game.assets or not self.game.assets.fonts or not self.resources then return end
            local mediumFont = self.game.assets.fonts.medium

            -- Draw turn/round indicator
            love.graphics.setFont(mediumFont)
            love.graphics.setColor(COLORS.title)
            local currentTurnText = "R:" .. self.currentRoundNum .. " T:" .. self.currentTurnNum
            love.graphics.printf(currentTurnText, margin, element_self.y + (element_self.height - mediumFont:getHeight()) / 2, 100, "left")

            -- Draw gold
            love.graphics.setColor(COLORS.gold)
            local goldText = "GOLD: " .. self.resources.gold
            local goldWidth = mediumFont:getWidth(goldText)
            love.graphics.print(goldText, screenWidth - goldWidth - margin, element_self.y + (element_self.height - mediumFont:getHeight()) / 2)

            -- Draw action points text centered
            local apText = "AP: " .. self.resources.actionPoints .. "/" .. self.resources.maxActionPoints
            local apWidth = mediumFont:getWidth(apText)
            love.graphics.setColor(COLORS.text)
            love.graphics.print(apText, screenWidth/2 - apWidth/2, element_self.y + (element_self.height - mediumFont:getHeight()) / 2)
        end
    }

    -- Turn Indicator (Below Top Bar) - Removed as it's integrated into Top Bar now
    -- self.elements.turnIndicator = { ... }

    -- Unit Info Panel (Bottom Left)
    self.elements.unitInfo = {
        x = margin,
        y = screenHeight - sidePanelHeight - bottomBarHeight - bottomMargin - (self.abilityPanel.height or 80) - 5, -- Position above ability panel
        width = sidePanelWidth,
        height = sidePanelHeight,
        unit = nil,
        backgroundColor = COLORS.panel,
        borderColor = COLORS.border,
        textColor = COLORS.text,
        statColors = { health = COLORS.health, energy = COLORS.mana, attack = COLORS.attack, defense = COLORS.defense, speed = COLORS.speed, moveRange = COLORS.gold },
        visible = false,
        update = function(element_self, dt) end,
        draw = function(element_self) -- Draw logic remains the same, just uses new position
            if not element_self.unit then return end
            if not self.game or not self.game.assets or not self.game.assets.fonts then return end
            local smallFont = self.game.assets.fonts.small
            local mediumFont = self.game.assets.fonts.medium

            love.graphics.setColor(element_self.backgroundColor)
            love.graphics.rectangle("fill", element_self.x, element_self.y, element_self.width, element_self.height, 5, 5)
            love.graphics.setColor(element_self.borderColor)
            love.graphics.rectangle("line", element_self.x, element_self.y, element_self.width, element_self.height, 5, 5)

            local portraitSize = 60; local portraitX = element_self.x + 10; local portraitY = element_self.y + 10
            local unitColor = COLORS.neutral -- Default
            if element_self.unit.unitType == "knight" then unitColor = COLORS.attack elseif element_self.unit.unitType == "bishop" then unitColor = COLORS.mana elseif element_self.unit.unitType == "rook" then unitColor = COLORS.defense elseif element_self.unit.unitType == "pawn" then unitColor = COLORS.neutral elseif element_self.unit.unitType == "queen" then unitColor = COLORS.gold end
            love.graphics.setColor(unitColor); love.graphics.rectangle("fill", portraitX, portraitY, portraitSize, portraitSize)

            love.graphics.setColor(element_self.textColor); love.graphics.setFont(mediumFont)
            love.graphics.print(element_self.unit.unitType:upper(), element_self.x + 80, element_self.y + 10)
            if element_self.unit.level then love.graphics.setFont(smallFont); love.graphics.print("Level: " .. element_self.unit.level, element_self.x + 80, element_self.y + 35) end

            local barWidth = 150; local barHeight = 15; local barX = element_self.x + 80; local barY = element_self.y + 55
            love.graphics.setColor(0.2, 0.2, 0.2, 0.7); love.graphics.rectangle("fill", barX, barY, barWidth, barHeight)
            local hpRatio = element_self.unit.stats.health / element_self.unit.stats.maxHealth; love.graphics.setColor(element_self.statColors.health); love.graphics.rectangle("fill", barX, barY, barWidth * hpRatio, barHeight)
            love.graphics.setColor(COLORS.text); love.graphics.setFont(smallFont); love.graphics.print("HP: " .. element_self.unit.stats.health .. "/" .. element_self.unit.stats.maxHealth, barX + 5, barY + 1)

            if element_self.unit.stats.energy then
                local mpBarY = barY + barHeight + 5; love.graphics.setColor(0.2, 0.2, 0.2, 0.7); love.graphics.rectangle("fill", barX, mpBarY, barWidth, barHeight)
                local mpRatio = element_self.unit.stats.energy / element_self.unit.stats.maxEnergy; love.graphics.setColor(element_self.statColors.energy); love.graphics.rectangle("fill", barX, mpBarY, barWidth * mpRatio, barHeight)
                love.graphics.setColor(COLORS.text); love.graphics.print("MP: " .. element_self.unit.stats.energy .. "/" .. element_self.unit.stats.maxEnergy, barX + 5, mpBarY + 1)
            end

            local statsY = element_self.y + 105; local statsX1 = element_self.x + 10; local statsX2 = element_self.x + 130
            love.graphics.setFont(smallFont); love.graphics.setColor(element_self.statColors.attack); love.graphics.print("ATK: " .. element_self.unit.stats.attack, statsX1, statsY)
            love.graphics.setColor(element_self.statColors.defense); love.graphics.print("DEF: " .. element_self.unit.stats.defense, statsX2, statsY)
            love.graphics.setColor(element_self.statColors.moveRange); love.graphics.print("MOV: " .. element_self.unit.stats.moveRange, statsX1, statsY + 20)
            love.graphics.setColor(element_self.statColors.speed); love.graphics.print("SPD: " .. (element_self.unit.stats.initiative or element_self.unit.stats.speed), statsX2, statsY + 20)

            -- Simplified Equipment/Status drawing for brevity
            if element_self.unit.equipment and next(element_self.unit.equipment) then love.graphics.setColor(COLORS.title); love.graphics.print("EQUIP:", element_self.x + 10, statsY + 45) end
            if element_self.unit.statusEffects and #element_self.unit.statusEffects > 0 then love.graphics.setColor(COLORS.title); love.graphics.print("STATUS:", element_self.x + 10, element_self.y + element_self.height - 25) end
        end,
        setUnit = function(element_self, unit) element_self.unit = unit; element_self.visible = (unit ~= nil) end
    }

    -- Enemy Info Panel (Bottom Right)
    self.elements.enemyInfo = {
        x = screenWidth - sidePanelWidth - margin,
        y = screenHeight - sidePanelHeight - bottomBarHeight - bottomMargin - (self.abilityPanel.height or 80) - 5, -- Position above ability panel
        width = sidePanelWidth,
        height = sidePanelHeight,
        unit = nil,
        backgroundColor = COLORS.panel,
        borderColor = COLORS.border,
        textColor = COLORS.text,
        statColors = { health = COLORS.health, energy = COLORS.mana, attack = COLORS.attack, defense = COLORS.defense, speed = COLORS.speed, moveRange = COLORS.gold },
        visible = false,
        update = function(element_self, dt) end,
        draw = function(element_self) -- Draw logic similar to unitInfo, just mirrored/adjusted X
            if not element_self.unit then return end
            if not self.game or not self.game.assets or not self.game.assets.fonts then return end
            local smallFont = self.game.assets.fonts.small
            local mediumFont = self.game.assets.fonts.medium

            love.graphics.setColor(element_self.backgroundColor); love.graphics.rectangle("fill", element_self.x, element_self.y, element_self.width, element_self.height, 5, 5)
            love.graphics.setColor(element_self.borderColor); love.graphics.rectangle("line", element_self.x, element_self.y, element_self.width, element_self.height, 5, 5)

            local portraitSize = 60; local portraitX = element_self.x + element_self.width - portraitSize - 10; local portraitY = element_self.y + 10
            local unitColor = COLORS.neutral -- Default
            if element_self.unit.unitType == "knight" then unitColor = COLORS.attack elseif element_self.unit.unitType == "bishop" then unitColor = COLORS.mana elseif element_self.unit.unitType == "rook" then unitColor = COLORS.defense elseif element_self.unit.unitType == "pawn" then unitColor = COLORS.neutral elseif element_self.unit.unitType == "queen" then unitColor = COLORS.gold end
            love.graphics.setColor(unitColor); love.graphics.rectangle("fill", portraitX, portraitY, portraitSize, portraitSize)

            love.graphics.setColor(element_self.textColor); love.graphics.setFont(mediumFont)
            local nameText = element_self.unit.unitType:upper()
            local nameWidth = mediumFont:getWidth(nameText)
            love.graphics.print(nameText, element_self.x + element_self.width - nameWidth - 80, element_self.y + 10)

            if element_self.unit.level then love.graphics.setFont(smallFont); love.graphics.print("Level: " .. element_self.unit.level, element_self.x + 20, element_self.y + 35) end

            local barWidth = 150; local barHeight = 15; local barX = element_self.x + 20; local barY = element_self.y + 55
            love.graphics.setColor(0.2, 0.2, 0.2, 0.7); love.graphics.rectangle("fill", barX, barY, barWidth, barHeight)
            local hpRatio = element_self.unit.stats.health / element_self.unit.stats.maxHealth; love.graphics.setColor(element_self.statColors.health); love.graphics.rectangle("fill", barX, barY, barWidth * hpRatio, barHeight)
            love.graphics.setColor(COLORS.text); love.graphics.setFont(smallFont); love.graphics.print("HP: " .. element_self.unit.stats.health .. "/" .. element_self.unit.stats.maxHealth, barX + 5, barY + 1)

            if element_self.unit.stats.energy then
                local mpBarY = barY + barHeight + 5; love.graphics.setColor(0.2, 0.2, 0.2, 0.7); love.graphics.rectangle("fill", barX, mpBarY, barWidth, barHeight)
                local mpRatio = element_self.unit.stats.energy / element_self.unit.stats.maxEnergy; love.graphics.setColor(element_self.statColors.energy); love.graphics.rectangle("fill", barX, mpBarY, barWidth * mpRatio, barHeight)
                love.graphics.setColor(COLORS.text); love.graphics.print("MP: " .. element_self.unit.stats.energy .. "/" .. element_self.unit.stats.maxEnergy, barX + 5, mpBarY + 1)
            end

            local statsY = element_self.y + 105; local statsX1 = element_self.x + 20; local statsX2 = element_self.x + 140
            love.graphics.setFont(smallFont); love.graphics.setColor(element_self.statColors.attack); love.graphics.print("ATK: " .. element_self.unit.stats.attack, statsX1, statsY)
            love.graphics.setColor(element_self.statColors.defense); love.graphics.print("DEF: " .. element_self.unit.stats.defense, statsX2, statsY)
            love.graphics.setColor(element_self.statColors.moveRange); love.graphics.print("MOV: " .. element_self.unit.stats.moveRange, statsX1, statsY + 20)
            love.graphics.setColor(element_self.statColors.speed); love.graphics.print("SPD: " .. (element_self.unit.stats.initiative or element_self.unit.stats.speed), statsX2, statsY + 20)

            -- Simplified Equipment/Status drawing
            if element_self.unit.equipment and next(element_self.unit.equipment) then love.graphics.setColor(COLORS.title); love.graphics.print("EQUIP:", element_self.x + 20, statsY + 45) end
            if element_self.unit.statusEffects and #element_self.unit.statusEffects > 0 then love.graphics.setColor(COLORS.title); love.graphics.print("STATUS:", element_self.x + 20, element_self.y + element_self.height - 25) end
        end,
        setUnit = function(element_self, unit) element_self.unit = unit; element_self.visible = (unit ~= nil) end
    }

    -- Minimap (Top Left)
    self.elements.minimap = {
        x = margin,
        y = topBarHeight + margin,
        width = 150,
        height = 150,
        grid = nil,
        backgroundColor = COLORS.background,
        borderColor = COLORS.border,
        visible = true, -- Keep visible, but drawing depends on grid
        update = function(element_self, dt) end,
        draw = function(element_self) -- Draw logic remains the same
            if not self.game or not self.grid then return end -- Use HUD's grid reference
            local grid = self.grid

            love.graphics.setColor(element_self.backgroundColor); love.graphics.rectangle("fill", element_self.x, element_self.y, element_self.width, element_self.height, 5, 5)
            love.graphics.setColor(element_self.borderColor); love.graphics.rectangle("line", element_self.x, element_self.y, element_self.width, element_self.height, 5, 5)

            local cellSize = math.min(element_self.width / grid.width, element_self.height / grid.height)
            for y = 1, grid.height do
                for x = 1, grid.width do
                    local cellX = element_self.x + (x - 1) * cellSize; local cellY = element_self.y + (y - 1) * cellSize
                    local cell = grid:getTile(x, y); local cellColor = {0.2, 0.2, 0.3, 1}
                    if cell and cell.type then if cell.type == "wall" then cellColor = {0.4, 0.4, 0.4, 1} elseif cell.type == "water" then cellColor = {0.2, 0.4, 0.8, 1} end end
                    love.graphics.setColor(cellColor); love.graphics.rectangle("fill", cellX, cellY, cellSize, cellSize)
                    local unit = grid:getEntityAt(x, y)
                    if unit then local unitColor = (unit.faction == "player") and COLORS.player or COLORS.enemy; love.graphics.setColor(unitColor); love.graphics.rectangle("fill", cellX + 1, cellY + 1, cellSize - 2, cellSize - 2) end
                end
            end
            -- Draw viewport indicator if camera exists
            if self.game.camera and grid.tileSize and grid.tileSize > 0 and self.game.camera.scale and self.game.camera.scale > 0 then
                 local viewX = element_self.x + (self.game.camera.x / grid.tileSize) * cellSize
                 local viewY = element_self.y + (self.game.camera.y / grid.tileSize) * cellSize
                 local viewW = (love.graphics.getWidth() / self.game.camera.scale / grid.tileSize) * cellSize
                 local viewH = (love.graphics.getHeight() / self.game.camera.scale / grid.tileSize) * cellSize
                 love.graphics.setColor(1, 1, 1, 0.3); love.graphics.rectangle("line", viewX, viewY, viewW, viewH)
            end
        end,
        setGrid = function(element_self, grid) element_self.grid = grid end
    }

    -- Turn Order Tracker (Top Right)
    local turnOrderWidth = 150
    local turnOrderHeight = 200
    self.elements.turnOrder = {
        x = screenWidth - turnOrderWidth - margin,
        y = topBarHeight + margin,
        width = turnOrderWidth,
        height = turnOrderHeight,
        backgroundColor = COLORS.background,
        borderColor = COLORS.border,
        visible = true,
        update = function(element_self, dt) end,
        draw = function(element_self) -- Draw logic remains the same
            love.graphics.setColor(element_self.backgroundColor); love.graphics.rectangle("fill", element_self.x, element_self.y, element_self.width, element_self.height, 5, 5)
            love.graphics.setColor(element_self.borderColor); love.graphics.rectangle("line", element_self.x, element_self.y, element_self.width, element_self.height, 5, 5)
            if not self.game or not self.game.assets or not self.game.assets.fonts or not self.turnOrder then return end
            love.graphics.setFont(self.game.assets.fonts.medium); love.graphics.setColor(COLORS.title); love.graphics.printf("TURN ORDER", element_self.x, element_self.y + 10, element_self.width, "center")
            love.graphics.setFont(self.game.assets.fonts.small)
            local entryHeight = 25; local startY = element_self.y + 40
            for i, unit in ipairs(self.turnOrder) do
                local entryY = startY + (i-1) * entryHeight; if entryY > element_self.y + element_self.height - entryHeight then break end
                if i == self.currentTurnIndex then love.graphics.setColor(COLORS.highlight); love.graphics.rectangle("fill", element_self.x + 5, entryY, element_self.width - 10, entryHeight) end
                local unitColor = (unit.faction == "player") and COLORS.player or COLORS.enemy; love.graphics.setColor(unitColor); love.graphics.rectangle("fill", element_self.x + 10, entryY + 5, 15, 15)
                love.graphics.setColor(COLORS.text); love.graphics.print(unit.unitType:upper(), element_self.x + 35, entryY + 5)
                love.graphics.setColor(COLORS.speed); local initiative = (unit.stats and (unit.stats.initiative or unit.stats.speed)) or "?"; love.graphics.print("SPD: " .. initiative, element_self.x + 100, entryY + 5)
            end
        end,
        setTurnOrder = function(element_self, turnOrder, currentIndex) self.turnOrder = turnOrder or {}; self.currentTurnIndex = currentIndex or 1 end
    }

    -- Combat Log (Below Turn Order)
    local combatLogWidth = 300
    local combatLogHeight = 150
    self.elements.combatLog = {
        x = screenWidth - combatLogWidth - margin,
        y = topBarHeight + margin + turnOrderHeight + margin, -- Position below turn order
        width = combatLogWidth,
        height = combatLogHeight,
        backgroundColor = COLORS.background,
        borderColor = COLORS.border,
        visible = true,
        update = function(element_self, dt) end,
        draw = function(element_self)
             -- Draw background
             love.graphics.setColor(element_self.backgroundColor)
             love.graphics.rectangle("fill", element_self.x, element_self.y, element_self.width, element_self.height)
             love.graphics.setColor(element_self.borderColor)
             love.graphics.rectangle("line", element_self.x, element_self.y, element_self.width, element_self.height)

             if not self.game or not self.game.assets or not self.game.assets.fonts then return end
             love.graphics.setFont(self.game.assets.fonts.medium)
             love.graphics.setColor(COLORS.title)
             love.graphics.print("Combat Log", element_self.x + 10, element_self.y + 5)

             love.graphics.setFont(self.game.assets.fonts.small)
             local maxEntries = 6 -- Adjust based on height
             local combatLogRef = self.game.combatLog or {} -- Access log from game object
             local startIndex = math.max(1, #combatLogRef - maxEntries + 1)
             local lineY = element_self.y + 30

             for i = startIndex, #combatLogRef do
                 local entry = combatLogRef[i]
                 if type(entry) == "string" then -- Check if entry is a string
                     if (i - startIndex + 1) % 2 == 0 then love.graphics.setColor(0.8, 0.8, 0.8, 0.8)
                     else love.graphics.setColor(1, 1, 1, 0.8) end
                     love.graphics.print(entry, element_self.x + 10, lineY)
                     lineY = lineY + 15
                 end
             end
        end
    }

    -- Notification Panel (Center Top, below Top Bar)
    local notificationWidth = 300
    local notificationHeight = 80 -- Adjust height as needed
    self.elements.notifications = {
        x = screenWidth/2 - notificationWidth/2,
        y = topBarHeight + margin,
        width = notificationWidth,
        height = notificationHeight,
        backgroundColor = {COLORS.background[1], COLORS.background[2], COLORS.background[3], 0.7}, -- Slightly more transparent
        borderColor = COLORS.border,
        visible = true,
        update = function(element_self, dt)
            local i = 1
            while i <= #self.notifications do
                self.notifications[i].timer = self.notifications[i].timer - dt
                if self.notifications[i].timer <= 0 then table.remove(self.notifications, i)
                else i = i + 1 end
            end
        end,
        draw = function(element_self)
            if #self.notifications == 0 then return end
            -- Draw background only if there are notifications
            love.graphics.setColor(element_self.backgroundColor)
            love.graphics.rectangle("fill", element_self.x, element_self.y, element_self.width, element_self.height, 5, 5)
            love.graphics.setColor(element_self.borderColor)
            love.graphics.rectangle("line", element_self.x, element_self.y, element_self.width, element_self.height, 5, 5)

            if not self.game or not self.game.assets or not self.game.assets.fonts then return end
            love.graphics.setFont(self.game.assets.fonts.small)
            local notificationHeight = 20; local maxNotifications = 4; local startY = element_self.y + 10
            for i = 1, math.min(maxNotifications, #self.notifications) do
                local notification = self.notifications[i]
                local alpha = math.min(1, notification.timer / (self.notificationDuration * 0.5))
                love.graphics.setColor(notification.color[1], notification.color[2], notification.color[3], alpha)
                love.graphics.printf(notification.text, element_self.x + 10, startY + (i-1) * notificationHeight, element_self.width - 20, "center")
            end
        end,
        addNotification = function(element_self, text, color)
            if self.notifications ~= nil then
                table.insert(self.notifications, 1, { text = text, color = color or COLORS.text, timer = self.notificationDuration })
                if #self.notifications > 10 then table.remove(self.notifications) end
            else print("ERROR: HUD.notifications is nil in addNotification") end
        end
    }

    -- Action Panel (Bottom Center)
    local actionPanelWidth = 400
    self.elements.actionPanel = {
        x = screenWidth/2 - actionPanelWidth/2,
        y = screenHeight - bottomBarHeight - bottomMargin,
        width = actionPanelWidth,
        height = bottomBarHeight,
        backgroundColor = COLORS.background,
        borderColor = COLORS.border,
        buttons = {
            {id = "move", text = "MOVE", x = 10, width = 80, color = COLORS.speed},
            {id = "attack", text = "ATTACK", x = 100, width = 80, color = COLORS.attack},
            {id = "ability", text = "ABILITY", x = 190, width = 80, color = COLORS.mana},
            {id = "end", text = "END TURN", x = 280, width = 110, color = COLORS.gold}
        },
        visible = true,
        update = function(element_self, dt) end,
        draw = function(element_self) -- Draw logic remains the same
            love.graphics.setColor(element_self.backgroundColor); love.graphics.rectangle("fill", element_self.x, element_self.y, element_self.width, element_self.height, 5, 5)
            love.graphics.setColor(element_self.borderColor); love.graphics.rectangle("line", element_self.x, element_self.y, element_self.width, element_self.height, 5, 5)
            if not self.game or not self.game.assets or not self.game.assets.fonts then return end
            love.graphics.setFont(self.game.assets.fonts.medium)
            for _, button in ipairs(element_self.buttons) do
                local buttonX = element_self.x + button.x; local buttonY = element_self.y + 10; local buttonHeight = 30
                love.graphics.setColor(button.color); love.graphics.rectangle("fill", buttonX, buttonY, button.width, buttonHeight)
                love.graphics.setColor(COLORS.border); love.graphics.rectangle("line", buttonX, buttonY, button.width, buttonHeight)
                love.graphics.setColor(COLORS.text[1], COLORS.text[2], COLORS.text[3], COLORS.text[4] * self.alpha); love.graphics.printf(button.text, buttonX, buttonY + 5, button.width, "center")
            end
        end,
        handleClick = function(element_self, x, y) -- Click logic remains the same
            if not element_self.visible then return nil end
            if x >= element_self.x and x <= element_self.x + element_self.width and y >= element_self.y and y <= element_self.y + element_self.height then
                local buttonY = element_self.y + 10; local buttonHeight = 30
                if y >= buttonY and y <= buttonY + buttonHeight then
                    for _, button in ipairs(element_self.buttons) do
                        local buttonX = element_self.x + button.x
                        if x >= buttonX and x <= buttonX + button.width then return button.id end
                    end
                end
            end
            return nil
        end
    }

    -- Help Text Panel (Bottom Edge) - Removed as it overlaps Action Panel
    -- self.elements.helpText = { ... }
end

-- Update HUD
function HUD:update(dt)
    -- Update animation timers
    timer.update(dt)
    
    -- Update HUD elements
    for _, element in pairs(self.elements) do
        if element.visible and element.update then
            element:update(dt)
        end
    end
    
    -- Update ability panel
    -- *** FIX: Check if abilityPanel exists before updating ***
    if self.abilityPanel and self.abilityPanel.update then
        self.abilityPanel:update(dt)
    end
    -- *** END FIX ***
end

-- Draw HUD
function HUD:draw()
    if not self.visible then return end
    
    -- Apply global alpha
    local r, g, b, a = love.graphics.getColor()
    love.graphics.setColor(r, g, b, self.alpha)
    
    -- Draw HUD elements
    for _, element in pairs(self.elements) do
        if element.visible and element.draw then
            element:draw()
        end
    end
    
    -- Draw ability panel
    -- *** FIX: Check if abilityPanel exists before drawing ***
    if self.abilityPanel and self.abilityPanel.draw then
        self.abilityPanel:draw()
    end
    -- *** END FIX ***
    
    -- Draw tooltip if active
    if self.activeTooltip then
        self:drawTooltip(self.activeTooltip)
    end
    
    -- Restore color
    love.graphics.setColor(r, g, b, a)
end

-- Draw tooltip
function HUD:drawTooltip(tooltip)
    local x = tooltip.x
    local y = tooltip.y
    local width = tooltip.width or 200
    local text = tooltip.text
    
    -- Measure text height
    local font = self.game.assets.fonts.small
    local _, textLines = font:getWrap(text, width - 20)
    local textHeight = #textLines * font:getHeight() + 20
    
    -- Draw tooltip background
    love.graphics.setColor(COLORS.background)
    love.graphics.rectangle("fill", x, y, width, textHeight, 5, 5)
    
    -- Draw tooltip border
    love.graphics.setColor(COLORS.border)
    love.graphics.rectangle("line", x, y, width, textHeight, 5, 5)
    
    -- Draw tooltip text
    love.graphics.setColor(COLORS.text)
    love.graphics.setFont(font)
    love.graphics.printf(text, x + 10, y + 10, width - 20, "left")
end

-- Set unit for info panel
function HUD:setUnitInfo(unit, isEnemy)
    if isEnemy then
        self.elements.enemyInfo:setUnit(unit)
    else
        self.elements.unitInfo:setUnit(unit)
    end
end

-- Set turn order (MODIFIED: This function now exists directly on HUD)
function HUD:setTurnOrder(units, currentIndex)
    print("HUD:setTurnOrder - Updating turn order display. Units: " .. #units .. ", Index: " .. currentIndex)
    self.turnOrder = units or {}
    self.currentTurnIndex = currentIndex or 1
    -- The turnOrder element's draw function reads these directly from the HUD instance
end

-- Add notification
function HUD:addNotification(text, color)
    if self.elements.notifications and self.elements.notifications.addNotification then
        self.elements.notifications:addNotification(text, color)
    else
        print("ERROR: Notification element or addNotification method not found")
    end
end

-- Set turn & round number
function HUD:setTurnInfo(turn, round)
    self.currentTurnNum = turn or self.currentTurnNum
    self.currentRoundNum = round or self.currentRoundNum
    -- The topBar draw function now reads these directly
end 

-- Set resources
function HUD:setResources(resources)
    self.resources.gold = resources.gold or self.resources.gold
    -- Note: AP is set via setActionPoints
end

-- Set action points
function HUD:setActionPoints(current, max)
    self.resources.actionPoints = current
    self.resources.maxActionPoints = max
    -- The topBar draw function now reads these directly
end

-- Handle key presses
function HUD:keypressed(key)
    if self.abilityPanel and self.abilityPanel.keypressed then
        return
    end
end

-- Handle mouse press (MODIFIED: Return info from elements)
function HUD:mousepressed(x, y, button)
    if button ~= 1 or not self.visible then return nil end

    -- Check action panel buttons
    if self.elements.actionPanel and self.elements.actionPanel.handleClick then
        local actionResult = self.elements.actionPanel:handleClick(x, y)
        if actionResult then
            print("HUD: Action panel clicked: " .. actionResult)
            -- Return info about the action button click
            return { type = "hud_action", id = actionResult }
        end
    end

    -- Check ability panel
    if self.abilityPanel and self.abilityPanel.visible and self.abilityPanel.mousepressed then
        local abilityResult = self.abilityPanel:mousepressed(x, y, button)
        if abilityResult then
            -- Pass the result from the ability panel up
            return abilityResult -- This will be { type = "ability_slot", ... } or { type = "ability_panel_background" }
        end
    end

    -- Check minimap clicks
    -- ... (keep minimap click logic, return {type="minimap", ...}) ...
     if self.elements.minimap and self.elements.minimap.visible and
        x >= self.elements.minimap.x and x <= self.elements.minimap.x + self.elements.minimap.width and
        y >= self.elements.minimap.y and y <= self.elements.minimap.y + self.elements.minimap.height then
         local grid = self.grid
         if grid then
             local cellSize = math.min(self.elements.minimap.width / grid.width, self.elements.minimap.height / grid.height)
             local gridX = math.floor((x - self.elements.minimap.x) / cellSize) + 1
             local gridY = math.floor((y - self.elements.minimap.y) / cellSize) + 1
             if gridX >= 1 and gridX <= grid.width and gridY >= 1 and gridY <= grid.height then
                 return {type = "minimap", x = gridX, y = gridY}
             end
         end
     end


    return nil -- No relevant HUD element clicked
end

-- Handle mouse movement
function HUD:mousemoved(x, y)
    -- Reset hover state
    self.hoveredElement = nil
    self.activeTooltip = nil
    
    -- Check ability panel hover
    local abilityHover = self.abilityPanel:checkHover(x, y)
    if abilityHover then
        self.hoveredElement = {type = "ability", id = abilityHover}
        
        -- Set tooltip for ability
        local ability = self.abilityPanel:getAbilityById(abilityHover)
        if ability then
            self.activeTooltip = {
                x = x + 10,
                y = y + 10,
                width = 200,
                text = ability.name .. "\n\n" .. ability.description
            }
        end
        
        return
    end
    
    -- Check action panel hover
    if self.elements.actionPanel.visible and 
       x >= self.elements.actionPanel.x and x <= self.elements.actionPanel.x + self.elements.actionPanel.width and
       y >= self.elements.actionPanel.y and y <= self.elements.actionPanel.y + self.elements.actionPanel.height then
        
        local buttonY = self.elements.actionPanel.y + 10
        local buttonHeight = 30
        
        if y >= buttonY and y <= buttonY + buttonHeight then
            for _, button in ipairs(self.elements.actionPanel.buttons) do
                local buttonX = self.elements.actionPanel.x + button.x
                
                if x >= buttonX and x <= buttonX + button.width then
                    self.hoveredElement = {type = "action", id = button.id}
                    
                    -- Set tooltip based on action
                    local tooltipText
                    if button.id == "move" then
                        tooltipText = "Move selected unit to a new position"
                    elseif button.id == "attack" then
                        tooltipText = "Attack an enemy unit"
                    elseif button.id == "ability" then
                        tooltipText = "Use a special ability"
                    elseif button.id == "end" then
                        tooltipText = "End your turn"
                    end
                    
                    if tooltipText then
                        self.activeTooltip = {
                            x = x + 10,
                            y = y - 40,
                            width = 200,
                            text = tooltipText
                        }
                    end
                    
                    return
                end
            end
        end
    end
end

-- Show/hide HUD
function HUD:setVisible(visible)
    self.visible = visible
end

-- Fade in HUD
function HUD:fadeIn(duration)
    duration = duration or 0.5
    self.alpha = 0
    self.visible = true
    timer.tween(duration, self, {alpha = 1}, 'out-quad')
end

-- Fade out HUD
function HUD:fadeOut(duration)
    duration = duration or 0.5
    timer.tween(duration, self, {alpha = 0}, 'out-quad', function()
        self.visible = false
    end)
end

-- Set player turn status
function HUD:setPlayerTurn(isPlayerTurn)
    self.isPlayerTurn = isPlayerTurn
    
    -- Update turn indicator text
    if self.elements.turnIndicator then
        self.elements.turnIndicator.text = isPlayerTurn and "Player Turn" or "Enemy Turn"
        self.elements.turnIndicator.color = isPlayerTurn and COLORS.player or COLORS.enemy
    end
end

-- Set current level
function HUD:setLevel(level)
    self.currentLevel = level
end

-- Set grid for minimap
function HUD:setGrid(grid)
    self.grid = grid -- Store grid reference at HUD level
    if self.elements.minimap and self.elements.minimap.setGrid then
        self.elements.minimap:setGrid(grid) -- Pass to minimap element
    end
end

-- Set help text
function HUD:setHelpText(text)
    self.helpText = text
    
    if self.elements.helpText then
        self.elements.helpText:setText(text)
    end
end

-- Show notification
function HUD:showNotification(text, duration, color)
    duration = duration or self.notificationDuration
    color = color or COLORS.text
    
    if text ~= nil then
        self:addNotification(text, color)
    else
        print("HUD Error - Message is nil")
    end
end

-- *** ADD Show/Hide methods for Ability Panel ***
function HUD:showAbilityPanel()
    if self.abilityPanel then self.abilityPanel:show() end
end

function HUD:hideAbilityPanel()
    if self.abilityPanel then self.abilityPanel:hide() end
end
-- *** END ADDITION ***

return HUD
