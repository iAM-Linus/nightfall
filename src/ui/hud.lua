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

    -- Position ability panel at the bottom of the screen
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    self.abilityPanel:setPosition((screenWidth - self.abilityPanel.width) / 2, screenHeight - self.abilityPanel.height - 40)
    self.abilityPanel.game = game
    
    -- Initialize HUD elements
    self:initElements()
end

-- Initialize HUD elements
function HUD:initElements()
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()

    -- Create action panel (Add this section)
    self.elements.actionPanel = {
        x = screenWidth/2 - 200,
        y = screenHeight - 60,
        width = 400,
        height = 50,
        backgroundColor = COLORS.background,
        borderColor = COLORS.border,
        buttons = {
            {id = "move", text = "MOVE", x = 10, width = 80, color = COLORS.speed},
            {id = "attack", text = "ATTACK", x = 100, width = 80, color = COLORS.attack},
            {id = "ability", text = "ABILITY", x = 190, width = 80, color = COLORS.mana},
            {id = "end", text = "END TURN", x = 280, width = 110, color = COLORS.gold}
        },
        visible = true,

        update = function(element_self, dt) -- Renamed inner self
            -- Animation updates if needed
        end,

        draw = function(element_self) -- Renamed inner self
            -- Draw background
            love.graphics.setColor(element_self.backgroundColor)
            love.graphics.rectangle("fill", element_self.x, element_self.y, element_self.width, element_self.height, 5, 5)

            -- Draw border
            love.graphics.setColor(element_self.borderColor)
            love.graphics.rectangle("line", element_self.x, element_self.y, element_self.width, element_self.height, 5, 5)

            -- Draw action buttons
            -- Use outer 'self' (HUD instance) to access game assets
            if not self.game or not self.game.assets or not self.game.assets.fonts then
                print("Error: HUD 'game' or 'assets' or 'fonts' not available in actionPanel draw")
                return
            end
            love.graphics.setFont(self.game.assets.fonts.medium)

            for _, button in ipairs(element_self.buttons) do
                local buttonX = element_self.x + button.x
                local buttonY = element_self.y + 10
                local buttonHeight = 30

                -- Button background
                love.graphics.setColor(button.color)
                love.graphics.rectangle("fill", buttonX, buttonY, button.width, buttonHeight)

                -- Button border
                love.graphics.setColor(COLORS.border)
                love.graphics.rectangle("line", buttonX, buttonY, button.width, buttonHeight)

                -- Button text
                -- Use outer 'self' for alpha
                love.graphics.setColor(COLORS.text[1], COLORS.text[2], COLORS.text[3], COLORS.text[4] * self.alpha)
                love.graphics.printf(button.text, buttonX, buttonY + 5, button.width, "center")
            end
        end,

        handleClick = function(element_self, x, y) -- Renamed inner self
            if not element_self.visible then return nil end

            -- Check if click is within the panel bounds first
            if x >= element_self.x and x <= element_self.x + element_self.width and
               y >= element_self.y and y <= element_self.y + element_self.height then

                local buttonY = element_self.y + 10
                local buttonHeight = 30

                -- Check if click is within the button row vertically
                if y >= buttonY and y <= buttonY + buttonHeight then
                    -- Check each button horizontally
                    for _, button in ipairs(element_self.buttons) do
                        local buttonX = element_self.x + button.x

                        if x >= buttonX and x <= buttonX + button.width then
                            return button.id -- Return the ID of the clicked button
                        end
                    end
                end
            end

            return nil -- No button clicked
        end
    }

    -- Top bar with player resources
    self.elements.topBar = {
        x = 0,
        y = 0,
        width = screenWidth,
        height = 40,
        backgroundColor = COLORS.background,
        borderColor = COLORS.border,
        visible = true,

        update = function(element_self, dt) -- Renamed inner self
            -- Animation updates if needed
        end,

        draw = function(element_self) -- Renamed inner self
            -- Draw background
            love.graphics.setColor(element_self.backgroundColor) -- Use element properties
            love.graphics.rectangle("fill", element_self.x, element_self.y, element_self.width, element_self.height)

            -- Draw border
            love.graphics.setColor(element_self.borderColor)
            love.graphics.rectangle("line", element_self.x, element_self.y, element_self.width, element_self.height)

            -- Use the outer 'self' (the HUD instance) to access game and resources
            if not self.game or not self.game.assets or not self.game.assets.fonts then
                 print("Error: HUD 'game' or 'assets' or 'fonts' not available in topBar draw")
                 return -- Prevent further errors if game/assets aren't ready
            end
             if not self.resources then
                 print("Error: HUD 'resources' not available in topBar draw")
                 return -- Prevent errors if resources aren't ready
             end

            -- Draw turn indicator
            love.graphics.setFont(self.game.assets.fonts.medium)
            love.graphics.setColor(COLORS.title)
            -- Assuming game state stores currentTurn, access it via self.game
            local currentTurnText = (self.game.state and self.game.state.currentTurn) and ("TURN: " .. self.game.state.currentTurn) or "TURN: ?"
            love.graphics.printf(currentTurnText, 10, element_self.y + 10, 100, "left")

            -- Draw gold
            love.graphics.setColor(COLORS.gold)
            love.graphics.print("GOLD: " .. self.resources.gold, screenWidth - 150, element_self.y + 10)

            -- Draw action points
            local apText = "AP: " .. self.resources.actionPoints .. "/" .. self.resources.maxActionPoints
            local apFont = love.graphics.getFont() -- Get the currently set font
            local apWidth = apFont and apFont:getWidth(apText) or 100 -- Calculate width safely
            love.graphics.setColor(COLORS.text)
            love.graphics.print(apText, screenWidth/2 - apWidth/2, element_self.y + 10)

            -- Draw action point indicators
            local indicatorWidth = 15
            local indicatorHeight = 8
            local totalWidth = self.resources.maxActionPoints * (indicatorWidth + 5)
            local startX = screenWidth/2 - totalWidth/2

            for i = 1, self.resources.maxActionPoints do
                if i <= self.resources.actionPoints then
                    love.graphics.setColor(COLORS.gold)
                else
                    love.graphics.setColor(COLORS.textDim)
                end

                love.graphics.rectangle("fill", startX + (i-1) * (indicatorWidth + 5), element_self.y + 25, indicatorWidth, indicatorHeight)
            end
        end
    }
    
    -- Create turn indicator
    self.elements.turnIndicator = {
        x = 0,
        y = 50,
        width = screenWidth,
        height = 30,
        text = "Player Turn",
        align = "center",
        -- font will be set from the outer self in draw
        color = COLORS.text,
        backgroundColor = COLORS.background,
        borderColor = COLORS.border,
        visible = true,

        update = function(element_self, dt) -- Renamed inner self
            -- Animation updates if needed
        end,

        draw = function(element_self) -- Renamed inner self
            -- Draw background
            love.graphics.setColor(element_self.backgroundColor)
            love.graphics.rectangle("fill", element_self.x, element_self.y, element_self.width, element_self.height)

            -- Draw border
            love.graphics.setColor(element_self.borderColor)
            love.graphics.rectangle("line", element_self.x, element_self.y, element_self.width, element_self.height)

            -- Draw text
            love.graphics.setColor(element_self.color)
            -- Use outer 'self' to get game assets
            if not self.game or not self.game.assets or not self.game.assets.fonts then
                 print("Error: HUD 'game' or 'assets' or 'fonts' not available in turnIndicator draw")
                 return
            end
            love.graphics.setFont(self.game.assets.fonts.medium)
            love.graphics.printf(element_self.text, element_self.x, element_self.y + 5, element_self.width, element_self.align)
        end
    }

    -- Create unit info panel (enhanced)
    self.elements.unitInfo = {
        x = 10,
        y = screenHeight - 180,
        width = 250,
        height = 170,
        unit = nil,
        -- font and titleFont will be set from outer self in draw
        backgroundColor = COLORS.panel,
        borderColor = COLORS.border,
        textColor = COLORS.text,
        statColors = {
            health = COLORS.health,
            energy = COLORS.mana,
            attack = COLORS.attack,
            defense = COLORS.defense,
            speed = COLORS.speed,
            moveRange = COLORS.gold
        },
        visible = false,

        update = function(element_self, dt) -- Renamed inner self
            -- Animation updates if needed
        end,

        draw = function(element_self) -- Renamed inner self
            if not element_self.unit then return end

             -- Use outer 'self' to get game assets
            if not self.game or not self.game.assets or not self.game.assets.fonts then
                 print("Error: HUD 'game' or 'assets' or 'fonts' not available in unitInfo draw")
                 return
            end
            local smallFont = self.game.assets.fonts.small
            local mediumFont = self.game.assets.fonts.medium

            -- Draw background
            love.graphics.setColor(element_self.backgroundColor)
            love.graphics.rectangle("fill", element_self.x, element_self.y, element_self.width, element_self.height, 5, 5)

            -- Draw border
            love.graphics.setColor(element_self.borderColor)
            love.graphics.rectangle("line", element_self.x, element_self.y, element_self.width, element_self.height, 5, 5)

            -- Draw unit portrait (placeholder)
            local portraitSize = 60
            local portraitX = element_self.x + 10
            local portraitY = element_self.y + 10

            -- Unit portrait background based on type
            local unitColor
            if element_self.unit.unitType == "knight" then unitColor = COLORS.attack
            elseif element_self.unit.unitType == "bishop" then unitColor = COLORS.mana
            elseif element_self.unit.unitType == "rook" then unitColor = COLORS.defense
            elseif element_self.unit.unitType == "pawn" then unitColor = COLORS.neutral
            elseif element_self.unit.unitType == "queen" then unitColor = COLORS.gold
            else unitColor = COLORS.neutral end
            love.graphics.setColor(unitColor)
            love.graphics.rectangle("fill", portraitX, portraitY, portraitSize, portraitSize)

            -- Draw unit name/type
            love.graphics.setColor(element_self.textColor)
            love.graphics.setFont(mediumFont) -- Use captured font
            love.graphics.print(element_self.unit.unitType:upper(), element_self.x + 80, element_self.y + 10)

            -- Draw level if available
            if element_self.unit.level then
                love.graphics.setFont(smallFont) -- Use captured font
                love.graphics.print("Level: " .. element_self.unit.level, element_self.x + 80, element_self.y + 35)
            end

            -- Draw HP bar
            local barWidth = 150; local barHeight = 15
            local barX = element_self.x + 80; local barY = element_self.y + 55
            love.graphics.setColor(0.2, 0.2, 0.2, 0.7)
            love.graphics.rectangle("fill", barX, barY, barWidth, barHeight)
            local hpRatio = element_self.unit.stats.health / element_self.unit.stats.maxHealth
            love.graphics.setColor(element_self.statColors.health)
            love.graphics.rectangle("fill", barX, barY, barWidth * hpRatio, barHeight)
            love.graphics.setColor(COLORS.text); love.graphics.setFont(smallFont)
            love.graphics.print("HP: " .. element_self.unit.stats.health .. "/" .. element_self.unit.stats.maxHealth, barX + 5, barY + 1)

            -- Draw MP/Energy bar if available
            if element_self.unit.stats.energy then
                local mpBarY = barY + barHeight + 5
                love.graphics.setColor(0.2, 0.2, 0.2, 0.7)
                love.graphics.rectangle("fill", barX, mpBarY, barWidth, barHeight)
                local mpRatio = element_self.unit.stats.energy / element_self.unit.stats.maxEnergy
                love.graphics.setColor(element_self.statColors.energy)
                love.graphics.rectangle("fill", barX, mpBarY, barWidth * mpRatio, barHeight)
                love.graphics.setColor(COLORS.text)
                love.graphics.print("MP: " .. element_self.unit.stats.energy .. "/" .. element_self.unit.stats.maxEnergy, barX + 5, mpBarY + 1)
            end

            -- Draw stats
            local statsY = element_self.y + 95
            local statsX1 = element_self.x + 10
            local statsX2 = element_self.x + 130
            love.graphics.setFont(smallFont)
            love.graphics.setColor(element_self.statColors.attack)
            love.graphics.print("ATK: " .. element_self.unit.stats.attack, statsX1, statsY)
            love.graphics.setColor(element_self.statColors.defense)
            love.graphics.print("DEF: " .. element_self.unit.stats.defense, statsX2, statsY)
            love.graphics.setColor(element_self.statColors.moveRange)
            love.graphics.print("MOV: " .. element_self.unit.stats.moveRange, statsX1, statsY + 20)
            love.graphics.setColor(element_self.statColors.speed)
            love.graphics.print("SPD: " .. (element_self.unit.stats.initiative or element_self.unit.stats.speed), statsX2, statsY + 20)

            -- Draw equipment if available (Simplified, assuming item.name exists)
            if element_self.unit.equipment then
                love.graphics.setColor(COLORS.title)
                love.graphics.print("EQUIPMENT:", element_self.x + 10, statsY + 45)
                local equipY = statsY + 65; local equipX = element_self.x + 20
                local slots = {"weapon", "armor", "accessory"}
                for i, slot in ipairs(slots) do
                    local item = element_self.unit.equipment[slot]
                    if item then
                        local slotColor
                        if slot == "weapon" then slotColor = COLORS.attack
                        elseif slot == "armor" then slotColor = COLORS.defense
                        else slotColor = COLORS.gold end
                        love.graphics.setColor(slotColor)
                        love.graphics.print(slot:sub(1,1):upper() .. slot:sub(2) .. ": " .. (item.name or "Unknown"), equipX, equipY + (i-1) * 15)
                    end
                end
            end

            -- Draw status effects if any (Simplified, assuming effect.name exists)
            if element_self.unit.statusEffects and #element_self.unit.statusEffects > 0 then
                local statusX = element_self.x + 10
                local statusY = element_self.y + element_self.height - 25
                love.graphics.setColor(COLORS.title)
                love.graphics.print("STATUS:", statusX, statusY)
                local effectsX = statusX + 70
                for i, effect in ipairs(element_self.unit.statusEffects) do
                    if i <= 3 then
                        love.graphics.setColor(COLORS.text)
                        love.graphics.print(effect.name or "Unknown", effectsX + (i-1) * 60, statusY)
                    end
                end
            end
        end,

        -- setUnit is defined on the element itself, so its 'self' is correct
        setUnit = function(element_self, unit)
            element_self.unit = unit
            element_self.visible = (unit ~= nil)
        end
    }

    -- Create enemy info panel (enhanced)
    self.elements.enemyInfo = {
        x = screenWidth - 260,
        y = screenHeight - 180,
        width = 250,
        height = 170,
        unit = nil,
        -- font and titleFont will be set from outer self in draw
        backgroundColor = COLORS.panel,
        borderColor = COLORS.border,
        textColor = COLORS.text,
        statColors = {
            health = COLORS.health,
            energy = COLORS.mana,
            attack = COLORS.attack,
            defense = COLORS.defense,
            speed = COLORS.speed,
            moveRange = COLORS.gold
        },
        visible = false,

        update = function(element_self, dt) -- Renamed inner self
            -- Animation updates if needed
        end,

        draw = function(element_self) -- Renamed inner self
            if not element_self.unit then return end

            -- Use outer 'self' to get game assets
            if not self.game or not self.game.assets or not self.game.assets.fonts then
                 print("Error: HUD 'game' or 'assets' or 'fonts' not available in enemyInfo draw")
                 return
            end
            local smallFont = self.game.assets.fonts.small
            local mediumFont = self.game.assets.fonts.medium

            -- Draw background
            love.graphics.setColor(element_self.backgroundColor)
            love.graphics.rectangle("fill", element_self.x, element_self.y, element_self.width, element_self.height, 5, 5)

            -- Draw border
            love.graphics.setColor(element_self.borderColor)
            love.graphics.rectangle("line", element_self.x, element_self.y, element_self.width, element_self.height, 5, 5)

            -- Draw unit portrait (placeholder)
            local portraitSize = 60
            local portraitX = element_self.x + element_self.width - portraitSize - 10
            local portraitY = element_self.y + 10

            local unitColor -- Same logic as unitInfo draw
            if element_self.unit.unitType == "knight" then unitColor = COLORS.attack
            elseif element_self.unit.unitType == "bishop" then unitColor = COLORS.mana
            elseif element_self.unit.unitType == "rook" then unitColor = COLORS.defense
            elseif element_self.unit.unitType == "pawn" then unitColor = COLORS.neutral
            elseif element_self.unit.unitType == "queen" then unitColor = COLORS.gold
            else unitColor = COLORS.neutral end
            love.graphics.setColor(unitColor)
            love.graphics.rectangle("fill", portraitX, portraitY, portraitSize, portraitSize)

            -- Draw unit name/type
            love.graphics.setColor(element_self.textColor)
            love.graphics.setFont(mediumFont)
            local nameWidth = mediumFont:getWidth(element_self.unit.unitType:upper())
            love.graphics.print(element_self.unit.unitType:upper(), element_self.x + element_self.width - nameWidth - 80, element_self.y + 10)

            -- Draw level if available
            if element_self.unit.level then
                love.graphics.setFont(smallFont)
                local levelText = "Level: " .. element_self.unit.level
                local levelWidth = smallFont:getWidth(levelText)
                love.graphics.print(levelText, element_self.x + element_self.width - levelWidth - 80, element_self.y + 35)
            end

            -- Draw HP bar
            local barWidth = 150; local barHeight = 15
            local barX = element_self.x + 20; local barY = element_self.y + 55
            love.graphics.setColor(0.2, 0.2, 0.2, 0.7)
            love.graphics.rectangle("fill", barX, barY, barWidth, barHeight)
            local hpRatio = element_self.unit.stats.health / element_self.unit.stats.maxHealth
            love.graphics.setColor(element_self.statColors.health)
            love.graphics.rectangle("fill", barX, barY, barWidth * hpRatio, barHeight)
            love.graphics.setColor(COLORS.text); love.graphics.setFont(smallFont)
            love.graphics.print("HP: " .. element_self.unit.stats.health .. "/" .. element_self.unit.stats.maxHealth, barX + 5, barY + 1)

            -- Draw MP/Energy bar if available
            if element_self.unit.stats.energy then
                local mpBarY = barY + barHeight + 5
                love.graphics.setColor(0.2, 0.2, 0.2, 0.7)
                love.graphics.rectangle("fill", barX, mpBarY, barWidth, barHeight)
                local mpRatio = element_self.unit.stats.energy / element_self.unit.stats.maxEnergy
                love.graphics.setColor(element_self.statColors.energy)
                love.graphics.rectangle("fill", barX, mpBarY, barWidth * mpRatio, barHeight)
                love.graphics.setColor(COLORS.text)
                love.graphics.print("MP: " .. element_self.unit.stats.energy .. "/" .. element_self.unit.stats.maxEnergy, barX + 5, mpBarY + 1)
            end

            -- Draw stats
            local statsY = element_self.y + 95
            local statsX1 = element_self.x + 20; local statsX2 = element_self.x + 140
            love.graphics.setFont(smallFont)
            love.graphics.setColor(element_self.statColors.attack)
            love.graphics.print("ATK: " .. element_self.unit.stats.attack, statsX1, statsY)
            love.graphics.setColor(element_self.statColors.defense)
            love.graphics.print("DEF: " .. element_self.unit.stats.defense, statsX2, statsY)
            love.graphics.setColor(element_self.statColors.moveRange)
            love.graphics.print("MOV: " .. element_self.unit.stats.moveRange, statsX1, statsY + 20)
            love.graphics.setColor(element_self.statColors.speed)
            love.graphics.print("SPD: " .. (element_self.unit.stats.initiative or element_self.unit.stats.speed), statsX2, statsY + 20)

            -- Draw equipment (Simplified)
            if element_self.unit.equipment then
                love.graphics.setColor(COLORS.title); love.graphics.print("EQUIPMENT:", element_self.x + 20, statsY + 45)
                local equipY = statsY + 65; local equipX = element_self.x + 30
                local slots = {"weapon", "armor", "accessory"}
                for i, slot in ipairs(slots) do
                    local item = element_self.unit.equipment[slot]
                    if item then
                        local slotColor
                        if slot == "weapon" then slotColor = COLORS.attack
                        elseif slot == "armor" then slotColor = COLORS.defense
                        else slotColor = COLORS.gold end
                        love.graphics.setColor(slotColor)
                        love.graphics.print(slot:sub(1,1):upper() .. slot:sub(2) .. ": " .. (item.name or "Unknown"), equipX, equipY + (i-1) * 15)
                    end
                end
            end

            -- Draw status effects (Simplified)
            if element_self.unit.statusEffects and #element_self.unit.statusEffects > 0 then
                local statusX = element_self.x + 20; local statusY = element_self.y + element_self.height - 25
                love.graphics.setColor(COLORS.title); love.graphics.print("STATUS:", statusX, statusY)
                local effectsX = statusX + 70
                for i, effect in ipairs(element_self.unit.statusEffects) do
                    if i <= 3 then
                        love.graphics.setColor(COLORS.text)
                        love.graphics.print(effect.name or "Unknown", effectsX + (i-1) * 60, statusY)
                    end
                end
            end
        end,

        setUnit = function(element_self, unit) -- Renamed inner self
            element_self.unit = unit
            element_self.visible = (unit ~= nil)
        end
    }
    
    -- Create minimap
    self.elements.minimap = {
        x = 10,
        y = 90,
        width = 150,
        height = 150,
        grid = nil, -- This grid reference should be set via setGrid
        backgroundColor = COLORS.background,
        borderColor = COLORS.border,
        visible = true,

        update = function(element_self, dt) -- Renamed inner self
            -- Animation updates if needed
        end,

        draw = function(element_self) -- Renamed inner self
            -- Use the outer 'self' (HUD instance) to access game, camera, grid
            if not self.game or not self.game.grid then return end -- Safety check
            local grid = self.game.grid -- Get the grid from the HUD's game reference

            -- Draw background
            love.graphics.setColor(element_self.backgroundColor)
            love.graphics.rectangle("fill", element_self.x, element_self.y, element_self.width, element_self.height, 5, 5)

            -- Draw border
            love.graphics.setColor(element_self.borderColor)
            love.graphics.rectangle("line", element_self.x, element_self.y, element_self.width, element_self.height, 5, 5)

            -- Draw grid cells
            local cellSize = math.min(element_self.width / grid.width, element_self.height / grid.height)

            for y = 1, grid.height do
                for x = 1, grid.width do
                    local cellX = element_self.x + (x - 1) * cellSize
                    local cellY = element_self.y + (y - 1) * cellSize

                    -- Draw cell background based on terrain
                    local cell = grid:getTile(x, y) -- Use grid method safely
                    local cellColor = {0.2, 0.2, 0.3, 1} -- Default

                    -- Adjusted terrain check to use cell.type
                    if cell and cell.type then
                        if cell.type == "wall" then cellColor = {0.4, 0.4, 0.4, 1}
                        elseif cell.type == "water" then cellColor = {0.2, 0.4, 0.8, 1}
                        elseif cell.type == "forest" then cellColor = {0.2, 0.6, 0.3, 1}
                        -- Add other terrain types as needed
                        end
                    end

                    love.graphics.setColor(cellColor)
                    love.graphics.rectangle("fill", cellX, cellY, cellSize, cellSize)

                    -- Draw unit on cell if present
                    local unit = grid:getEntityAt(x, y) -- Use grid method safely
                    if unit then
                        local unitColor
                        if unit.faction == "player" then unitColor = COLORS.player
                        else unitColor = COLORS.enemy end
                        love.graphics.setColor(unitColor)
                        love.graphics.rectangle("fill", cellX + 1, cellY + 1, cellSize - 2, cellSize - 2)
                    end
                end
            end

            -- Draw viewport indicator (current view area)
            -- Access camera via self.game.camera (assuming it exists)
            if self.game.camera and grid.tileSize and grid.tileSize > 0 then
                local viewportX = element_self.x + (self.game.camera.x / grid.tileSize) * cellSize
                local viewportY = element_self.y + (self.game.camera.y / grid.tileSize) * cellSize
                local viewportWidth = (love.graphics.getWidth() / self.scale / grid.tileSize) * cellSize -- Adjusted for camera scale
                local viewportHeight = (love.graphics.getHeight() / self.scale / grid.tileSize) * cellSize -- Adjusted for camera scale

                love.graphics.setColor(1, 1, 1, 0.3)
                love.graphics.rectangle("line", viewportX, viewportY, viewportWidth, viewportHeight)
            end
        end,

        -- setGrid is correct, it modifies the element's grid property
        setGrid = function(element_self, grid)
            element_self.grid = grid
            -- Don't set visibility here, let the main HUD control it
        end
    }

    -- Create turn order tracker
    self.elements.turnOrder = {
        x = screenWidth - 160,
        y = 90,
        width = 150,
        height = 200,
        backgroundColor = COLORS.background,
        borderColor = COLORS.border,
        visible = true,

        update = function(element_self, dt) -- Renamed inner self
            -- Animation updates if needed
        end,

        draw = function(element_self) -- Renamed inner self
            -- Draw background
            love.graphics.setColor(element_self.backgroundColor)
            love.graphics.rectangle("fill", element_self.x, element_self.y, element_self.width, element_self.height, 5, 5)

            -- Draw border
            love.graphics.setColor(element_self.borderColor)
            love.graphics.rectangle("line", element_self.x, element_self.y, element_self.width, element_self.height, 5, 5)

            -- Use outer 'self' (HUD instance) to access game assets, turnOrder, currentTurnIndex
            if not self.game or not self.game.assets or not self.game.assets.fonts then
                 print("Error: HUD 'game' or 'assets' or 'fonts' not available in turnOrder draw")
                 return
            end
            if not self.turnOrder then -- Check if turnOrder exists on HUD instance
                 print("Error: HUD 'turnOrder' not available in turnOrder draw")
                 return
             end

            -- Draw title
            love.graphics.setFont(self.game.assets.fonts.medium)
            love.graphics.setColor(COLORS.title)
            love.graphics.printf("TURN ORDER", element_self.x, element_self.y + 10, element_self.width, "center")

            -- Draw turn order list
            love.graphics.setFont(self.game.assets.fonts.small)

            local entryHeight = 25
            local startY = element_self.y + 40

            for i, unit in ipairs(self.turnOrder) do -- Use self.turnOrder
                local entryY = startY + (i-1) * entryHeight

                -- Skip if outside visible area
                if entryY > element_self.y + element_self.height - entryHeight then
                    break
                end

                -- Highlight current turn
                if i == self.currentTurnIndex then -- Use self.currentTurnIndex
                    love.graphics.setColor(COLORS.highlight)
                    love.graphics.rectangle("fill", element_self.x + 5, entryY, element_self.width - 10, entryHeight)
                end

                -- Draw unit indicator
                local unitColor
                if unit.faction == "player" then unitColor = COLORS.player
                else unitColor = COLORS.enemy end
                love.graphics.setColor(unitColor)
                love.graphics.rectangle("fill", element_self.x + 10, entryY + 5, 15, 15)

                -- Draw unit name
                love.graphics.setColor(COLORS.text)
                love.graphics.print(unit.unitType:upper(), element_self.x + 35, entryY + 5)

                -- Draw initiative (ensure unit.stats exists)
                love.graphics.setColor(COLORS.speed)
                local initiative = (unit.stats and (unit.stats.initiative or unit.stats.speed)) or "?"
                love.graphics.print("SPD: " .. initiative, element_self.x + 100, entryY + 5)
            end
        end,

        -- setTurnOrder should modify the HUD instance's properties
        setTurnOrder = function(element_self, turnOrder, currentIndex)
             -- Use outer 'self' to modify HUD properties
            self.turnOrder = turnOrder or {}
            self.currentTurnIndex = currentIndex or 1
        end
    }
    
    -- Create notification panel
    self.elements.notifications = {
        x = screenWidth/2 - 150,
        y = 90,
        width = 300,
        height = 100,
        backgroundColor = COLORS.background,
        borderColor = COLORS.border,
        visible = true,

        -- Use the outer 'self' which refers to the HUD instance
        update = function(element_self, dt) -- Renamed inner 'self' for clarity
            local i = 1
            -- Access the HUD instance's notifications table via the captured 'self'
            while i <= #self.notifications do
                self.notifications[i].timer = self.notifications[i].timer - dt

                if self.notifications[i].timer <= 0 then
                    table.remove(self.notifications, i)
                else
                    i = i + 1
                end
            end
        end,

        draw = function(element_self) -- Renamed inner 'self' for clarity
             -- Access the HUD instance's notifications table via the captured 'self'
            if #self.notifications == 0 then return end

            -- Draw background
            love.graphics.setColor(element_self.backgroundColor) -- Use element_self for element properties
            love.graphics.rectangle("fill", element_self.x, element_self.y, element_self.width, element_self.height, 5, 5)

            -- Draw border
            love.graphics.setColor(element_self.borderColor)
            love.graphics.rectangle("line", element_self.x, element_self.y, element_self.width, element_self.height, 5, 5)

            -- Draw notifications (most recent at top)
            love.graphics.setFont(self.game.assets.fonts.small) -- Use outer 'self' for game assets

            local notificationHeight = 20
            local maxNotifications = 4
            local startY = element_self.y + 10

            for i = 1, math.min(maxNotifications, #self.notifications) do
                local notification = self.notifications[i] -- Access outer 'self'
                local notificationY = startY + (i-1) * notificationHeight

                -- Fade out based on remaining time
                -- Access outer 'self' for notificationDuration
                local alpha = math.min(1, notification.timer / (self.notificationDuration * 0.5)) 

                -- Draw notification text with appropriate color
                love.graphics.setColor(notification.color[1], notification.color[2], notification.color[3], alpha)
                love.graphics.print(notification.text, element_self.x + 10, notificationY)
            end
        end,

        addNotification = function(element_self, text, color) -- Renamed inner 'self'
            -- Ensure the notifications table exists on the HUD instance before inserting
            if self.notifications ~= nil then
                 -- Access the HUD instance's notifications table via the captured 'self'
                 -- Access outer 'self' for notificationDuration and COLORS
                table.insert(self.notifications, 1, {
                    text = text,
                    color = color or COLORS.text, 
                    timer = self.notificationDuration 
                })

                -- Limit number of notifications
                if #self.notifications > 10 then
                    table.remove(self.notifications)
                end
            else
                 print("ERROR: HUD.notifications is nil in addNotification")
            end
        end
    }
    
    -- Create help text panel
    self.elements.helpText = {
        x = 0,
        y = screenHeight - 25,
        width = screenWidth,
        height = 25,
        text = self.helpText, -- Reads initial text from HUD instance
        backgroundColor = COLORS.background,
        textColor = COLORS.text,
        visible = true,

        update = function(element_self, dt) -- Renamed inner self
            -- Animation updates if needed
        end,

        draw = function(element_self) -- Renamed inner self
            -- Draw background
            love.graphics.setColor(element_self.backgroundColor)
            love.graphics.rectangle("fill", element_self.x, element_self.y, element_self.width, element_self.height)

            -- Draw text
            love.graphics.setColor(element_self.textColor)
            -- Use outer 'self' (HUD instance) to access game assets
            if not self.game or not self.game.assets or not self.game.assets.fonts then
                 print("Error: HUD 'game' or 'assets' or 'fonts' not available in helpText draw")
                 return
            end
            love.graphics.setFont(self.game.assets.fonts.small)
            -- Use element_self.text to get the text for this specific element
            love.graphics.printf(element_self.text, element_self.x + 10, element_self.y + 5, element_self.width - 20, "center")
        end,

        -- setText correctly uses element_self
        setText = function(element_self, text)
            element_self.text = text
        end
    }
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
    self.abilityPanel:update(dt)
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
    self.abilityPanel:draw()
    
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

-- Set turn order
function HUD:setTurnOrder(units, currentIndex)
    if self.elements.turnOrder and self.elements.turnOrder.setTurnOrder then
        self.elements.turnOrder:setTurnOrder(units, currentIndex)
    else
         -- Fallback or direct update if element method doesn't exist (though it should)
         self.turnOrder = units or {}
         self.currentTurnIndex = currentIndex or 1
    end
end

-- Add notification
function HUD:addNotification(text, color)
    if self.elements.notifications and self.elements.notifications.addNotification then
        self.elements.notifications:addNotification(text, color)
    else
        print("ERROR: Notification element or addNotification method not found")
    end
end

-- Set resources
function HUD:setResources(resources)
    self.resources = resources
end

-- Set action points
function HUD:setActionPoints(current, max)
    self.resources.actionPoints = current
    self.resources.maxActionPoints = max
end

-- Handle key presses
function HUD:keypressed(key)
    if self.abilityPanel and self.abilityPanel.keypressed then
        return
    end
end

-- Handle mouse press
function HUD:mousepressed(x, y, button)
    if button ~= 1 or not self.visible then return nil end
    
    -- Check action panel buttons first, as they are likely common interactions
    if self.elements.actionPanel and self.elements.actionPanel.handleClick then
        local actionResult = self.elements.actionPanel.handleClick(self.elements.actionPanel, x, y)
        if actionResult then
            -- Return the action ID (e.g., "move", "attack") to the calling state
            -- The calling state (Game or Combat) will handle this action.
            print("Action panel clicked: " .. actionResult)
            return actionResult
        end
    else
        print("WARNING: actionPanel or actionPanel.handleClick not found in HUD:mousepressed")
    end
    
    -- Check ability panel
    if self.abilityPanel and self.abilityPanel.mousepressed then
        local abilityResult = self.abilityPanel:mousepressed(x, y)
        if abilityResult then
            return {type = "ability", id = abilityResult}
        end
    else
        print("WARNING: abilityPanel or abilityPanel.mousepressed not found in HUD:mousepressed")
    end
    
    -- Check minimap clicks
    if self.elements.minimap.visible and 
       x >= self.elements.minimap.x and x <= self.elements.minimap.x + self.elements.minimap.width and
       y >= self.elements.minimap.y and y <= self.elements.minimap.y + self.elements.minimap.height then
        
        local grid = self.game.grid
        if grid then
            local cellSize = math.min(self.elements.minimap.width / grid.width, self.elements.minimap.height / grid.height)
            local gridX = math.floor((x - self.elements.minimap.x) / cellSize) + 1
            local gridY = math.floor((y - self.elements.minimap.y) / cellSize) + 1
            
            if gridX >= 1 and gridX <= grid.width and gridY >= 1 and gridY <= grid.height then
                return {type = "minimap", x = gridX, y = gridY}
            end
        end
    end
    
    return nil
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
    self.grid = grid
    
    if self.elements.minimap then
        self.elements.minimap:setGrid(grid)
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

return HUD
