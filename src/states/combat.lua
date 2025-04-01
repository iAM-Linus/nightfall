-- src/states/combat.lua
-- Handles turn-based combat encounters between player and enemy units

local gamestate = require("lib.hump.gamestate")
local timer = require("lib.hump.timer")
local Camera = require("src.systems.camera")
local Grid = require("src.systems.grid")                    -- Need Grid class
local Unit = require("src.entities.unit")                   -- Need Unit class
local ChessMovement = require("src.systems.chess_movement") -- Keep for combat movement
-- Combat systems are initialized here
local TurnManager = require("src.systems.turn_manager")
local CombatSystem = require("src.systems.combat_system")
local SpecialAbilitiesSystem = require("src.systems.special_abilities_system")
local StatusEffectsSystem = require("src.systems.status_effects_system")

local Combat = {}

-- Combat state variables (specific to this instance of combat)
-- local grid = nil -- Use self.grid
-- local playerUnits = {} -- Use self.playerUnits
-- local enemyUnits = {} -- Use self.enemyUnits
-- local selectedUnit = nil -- Use self.selectedUnit
-- local targetUnit = nil -- Use self.targetUnit
-- local validMoves = {} -- Use self.validMoves
-- local validAttacks = {} -- Use self.validAttacks
-- local combatCamera = nil -- Use self.combatCamera
-- local uiElements = {} -- Use self.uiElements (if needed, or rely on HUD)
-- local combatLog = {} -- Use self.combatLog
-- local turnCount = 1 -- Use self.turnCount
-- local battleResult = nil -- Use self.battleResult
-- local returnState = nil -- Use self.returnState

-- Combat systems (specific to this instance)
-- local turnManager = nil -- Use self.turnManager
-- local combatSystem = nil -- Use self.combatSystem
-- local specialAbilitiesSystem = nil -- Use self.specialAbilitiesSystem
-- local statusEffectsSystem = nil -- Use self.statusEffectsSystem

-- Enter the combat state
function Combat:enter(previous, game, playerUnitsList, enemyFormationData, gridLayoutData, returnToStateInstance)
    print("--- Combat:enter START ---")
    self.game = game                         -- Store global game reference
    self.returnState = returnToStateInstance -- Store the specific Game state instance to return to

    -- Initialize combat-specific variables
    self.playerUnits = playerUnitsList or {}
    self.enemyUnits = {}
    self.selectedUnit = nil
    self.targetUnit = nil
    self.currentActionMode = nil
    self.validMoves = {}
    self.validAttacks = {}
    self.game.combatLog = {}
    self.turnCount = 1
    self.battleResult = nil -- nil = ongoing, "victory", "defeat"

    -- Initialize camera for combat view
    self.combatCamera = Camera:new()

    -- Create the combat grid instance
    local gridW = (gridLayoutData and gridLayoutData.width) or 8 -- Default size if no data
    local gridH = (gridLayoutData and gridLayoutData.height) or 8
    self.grid = Grid:new(gridW, gridH, self.game.config.tileSize, self.game)
    -- TODO: Populate grid with terrain/features based on gridLayoutData or room type if needed
    self:setupDefaultGrid() -- Placeholder grid setup

    -- Place player units
    print("  Placing player units...")
    for i, unit in ipairs(self.playerUnits) do
        -- Assign positions (e.g., based on gridLayoutData or defaults)
        local startX = math.floor(gridW / 4)
        local startY = math.floor(gridH / 2) - math.floor(#self.playerUnits / 2) + i
        unit.x = startX
        unit.y = startY
        -- *** FIX: Set initial visual position ***
        unit.visualX = unit.x
        unit.visualY = unit.y
        -- *** END FIX ***
        unit.grid = self.grid -- Ensure unit knows its grid
        if not self.grid:placeEntity(unit, unit.x, unit.y) then
            print("    ERROR: Failed to place player unit " .. unit.id .. " on combat grid!")
        end
        print("    Placed " .. unit.unitType .. " at (" .. unit.x .. "," .. unit.y .. ")")
    end

    -- Create and place enemy units from formation data
    print("  Creating enemy units from formation...")
    if enemyFormationData and enemyFormationData.units then
        for _, unitData in ipairs(enemyFormationData.units) do
            -- Create Unit instance
            -- TODO: Get stats based on unitData.type, unitData.level, game difficulty etc.
            local enemy = Unit:new({
                unitType = unitData.unitType,
                faction = "enemy",
                level = unitData.level or 1,
                isBoss = unitData.isBoss,
                isUnique = unitData.isUnique,
                x = unitData.x,
                y = unitData.y,
                grid = self.grid,  -- Assign grid reference
                game = self.game   -- Assign game reference
                -- stats = generatedStats, -- Generate stats here
            })
            -- *** FIX: Set initial visual position ***
            enemy.visualX = enemy.x
            enemy.visualY = enemy.y
            -- *** END FIX ***
            table.insert(self.enemyUnits, enemy)
            if not self.grid:placeEntity(enemy, enemy.x, enemy.y) then
                print("    ERROR: Failed to place enemy unit " .. enemy.id .. " on combat grid!")
            end
            print("    Created enemy " .. enemy.unitType .. " at (" .. enemy.x .. "," .. enemy.y .. ")")
        end
    else
        print("  WARNING: No enemy formation data provided. Creating default enemies.")
        self:createDefaultEnemyUnits() -- Fallback
    end

    -- Initialize combat systems (use systems from self.game)
    self.turnManager = self.game.turnManager
    self.combatSystem = self.game.combatSystem
    self.specialAbilitiesSystem = self.game.specialAbilitiesSystem
    self.statusEffectsSystem = self.game.statusEffectsSystem

    if not self.turnManager then print("ERROR: TurnManager not found in combat state!") end
    if not self.combatSystem then print("ERROR: CombatSystem not found in combat state!") end
    -- etc.

    -- Initialize UI elements (if specific to combat)
    -- self:initUI() -- Or rely on global HUD

    -- Set up turn manager callbacks for THIS combat instance
    local combatSelf = self -- Capture self for closures
    if self.turnManager then
        self.turnManager.onTurnStart = function(unit) combatSelf:handleTurnStart(unit) end
        self.turnManager.onTurnEnd = function(unit) combatSelf:handleTurnEnd(unit) end
        self.turnManager.onPhaseChange = function(newPhase) combatSelf:handlePhaseChange(newPhase) end
        self.turnManager.onActionPointsChanged = function(current, max) combatSelf:handleActionPointsChanged(current, max) end
        self.turnManager:setGrid(self.grid) -- IMPORTANT: Tell TurnManager which grid to use!
    end

    -- Initialize all units with the combat system
    local allUnits = {}
    for _, unit in ipairs(self.playerUnits) do table.insert(allUnits, unit) end
    for _, unit in ipairs(self.enemyUnits) do table.insert(allUnits, unit) end
    if self.combatSystem and self.combatSystem.initializeUnit then
        for _, unit in ipairs(allUnits) do
            -- self.combatSystem:initializeUnit(unit) -- Might not be needed if stats are set
        end
    end

    -- Start combat
    self:addToCombatLog("Combat started!")
    if self.turnManager then
        self.turnManager:calculateInitiativeOrder() -- Calculate order based on units in THIS combat
        self.turnManager:startTurn()                -- Start the first turn
    end

    -- Center camera on the grid
    local gridWidthPixels = self.grid.width * self.grid.tileSize
    local gridHeightPixels = self.grid.height * self.grid.tileSize
    local centerX = gridWidthPixels / 2
    local centerY = gridHeightPixels / 2
    local screenWidth = love.graphics.getWidth() / self.combatCamera.scale
    local screenHeight = love.graphics.getHeight() / self.combatCamera.scale
    self.combatCamera:setPosition(centerX - screenWidth / 2, centerY - screenHeight / 2, true)

    -- Hide ability panel initially
    if self.game.uiManager then self.game.uiManager:hideAbilityPanel() end

    print("--- Combat:enter END ---")
end

function Combat:leave()
    print("--- Combat:leave START ---")
    -- Clean up combat-specific resources if necessary
    -- Reset turn manager callbacks to avoid conflicts if needed
    if self.turnManager then
        self.turnManager.onTurnStart = nil
        self.turnManager.onTurnEnd = nil
        self.turnManager.onPhaseChange = nil
        self.turnManager.onActionPointsChanged = nil
        self.turnManager:setGrid(nil)  -- Remove grid reference
    end
    -- Clear local references
    self.grid = nil
    self.playerUnits = {}
    self.enemyUnits = {}
    self.selectedUnit = nil
    self.targetUnit = nil
    self.combatCamera = nil
    self.combatLog = {}
    print("--- Combat:leave END ---")
end

-- Update combat logic
function Combat:update(dt)
    if self.turnManager and self.turnManager.gameOver then return end
    timer.update(dt)
    if self.turnManager then self.turnManager:update(dt) end
    if self.combatCamera then self.combatCamera:update(dt) end
    for _, unit in ipairs(self.playerUnits) do unit:update(dt) end
    for _, unit in ipairs(self.enemyUnits) do unit:update(dt) end
    self:checkCombatEnd()

    -- *** ADD LOGGING for state variables ***
    local currentUnitId = self.selectedUnit and self.selectedUnit.id or "None"
    -- print("Combat:update - START - Mode:", self.currentActionMode, "Selected Unit:", currentUnitId) -- Optional: Reduce noise if too much
    -- *** END LOGGING ***

    -- Input Handling
    if self.game.inputHandler and self.turnManager and self.turnManager:isPlayerTurn() then
        local input = self.game.inputHandler

        -- Mouse Input Handling
        local mouse1Pressed = input:wasMousePressed(1)                      -- Get state
        if mouse1Pressed then
            print("Combat:update - input:wasMousePressed(1) returned TRUE") -- *** ADD LOG ***
            local mx, my = input.mouse.x, input.mouse.y
            local uiClickResult = nil
            if self.game.uiManager and self.game.uiManager.mousepressed then
                uiClickResult = self.game.uiManager:mousepressed(mx, my, 1)
            end

            if uiClickResult then
                print("Combat:update - UI Handled Left Click. Result:",
                    serpent and serpent.dump(uiClickResult) or tostring(uiClickResult))
                -- Process UI result
                if type(uiClickResult) == "table" then
                    if uiClickResult.type == "hud_action" then
                        self:handleHudAction(uiClickResult.id)
                    elseif uiClickResult.type == "ability_slot" then
                        self:handleAbilitySlotClick(uiClickResult.index, uiClickResult.id, uiClickResult.canUse)
                    elseif uiClickResult.type == "ability_panel_background" then
                        if self.currentActionMode == "ability" then self:cancelAction() end
                    end
                end
            else
                print("Combat:update - Processing Left Grid Click")
                self:handleGridClick(mx, my, 1)
            end
            -- else -- Optional log for when not pressed
            -- print("Combat:update - input:wasMousePressed(1) returned FALSE")
        end

        local mouse2Pressed = input:wasMousePressed(2)                      -- Get state
        if mouse2Pressed then
            print("Combat:update - input:wasMousePressed(2) returned TRUE") -- *** ADD LOG ***
            local mx, my = input.mouse.x, input.mouse.y
            local uiConsumed = false                                        -- Check if UI consumes right click (optional)
            if not uiConsumed then
                print("Combat:update - Processing Right Grid Click (Cancel)")
                self:handleGridClick(mx, my, 2)
            end
            -- else -- Optional log
            -- print("Combat:update - input:wasMousePressed(2) returned FALSE")
        end

        -- Keyboard Input Handling
        local dx, dy = 0, 0
        local keyLeftPressed = input:wasPressed("left") or input:wasPressed("a")
        local keyRightPressed = input:wasPressed("right") or input:wasPressed("d")
        local keyUpPressed = input:wasPressed("up") or input:wasPressed("w")
        local keyDownPressed = input:wasPressed("down") or input:wasPressed("s")

        if keyLeftPressed then
            dx = -1
        elseif keyRightPressed then
            dx = 1
        elseif keyUpPressed then
            dy = -1
        elseif keyDownPressed then
            dy = 1
        end

        if dx ~= 0 or dy ~= 0 then
            print("Combat:update - Keyboard Move detected via wasPressed. dx,dy:", dx, dy) -- *** ADD LOG ***
            self:handleKeyboardMove(dx, dy)
            -- else -- Optional log
            -- print("Combat:update - No movement key wasPressed.")
        end

        local keyConfirmPressed = input:wasPressed("space") or input:wasPressed("return")
        if keyConfirmPressed then
            print("Combat:update - Keyboard Confirm detected via wasPressed") -- *** ADD LOG ***
            self:handleKeyboardConfirm()
            -- else -- Optional log
            -- print("Combat:update - No confirm key wasPressed.")
        end

        local keyEndTurnPressed = input:wasPressed("e")
        if keyEndTurnPressed then
            print("Combat:update - Keyboard End Turn detected via wasPressed")  -- *** ADD LOG ***
            if self.turnManager then self.turnManager:endTurn() end
        end

        local keyCancelPressed = input:wasPressed("escape")
        if keyCancelPressed then
            print("Combat:update - Keyboard Cancel detected via wasPressed")  -- *** ADD LOG ***
            if self.currentActionMode then self:cancelAction() end
        end

        -- Ability Hotkeys
        for i = 1, 9 do
            local keyNumPressed = input:wasPressed(tostring(i))
            if keyNumPressed then
                print("Combat:update - Keyboard Ability Hotkey detected via wasPressed:", i)   -- *** ADD LOG ***
                self:handleAbilityHotkey(i)
                break
            end
        end

        -- *** ADD LOGGING for state variables at END ***
        currentUnitId = self.selectedUnit and self.selectedUnit.id or "None"
        -- print("Combat:update - END - Mode:", self.currentActionMode, "Selected Unit:", currentUnitId) -- Optional: Reduce noise if too much
        -- *** END LOGGING ***


        -- Clear InputHandler pressed state at the END
        if self.game.inputHandler and self.game.inputHandler.clearPressedState then
            self.game.inputHandler:clearPressedState()
        end
    end
end

function Combat:draw()
    local width, height = love.graphics.getDimensions()

    -- Apply camera transformations
    if self.combatCamera then self.combatCamera:apply() end

    -- Draw grid, units, highlights (using self. variables)
    if self.grid then self:drawGrid() end
    self:drawUnits()

    -- *** FIX: Draw highlights based on action mode ***
    if self.currentActionMode == "move" then
        self:drawMovementHighlights()
    elseif self.currentActionMode == "attack" then
        self:drawAttackHighlights()
    elseif self.currentActionMode == "ability" then
        -- TODO: Draw ability range/target highlights if needed
    end
    -- *** END FIX ***

    self:drawSelectionHighlight()

    -- End camera transformations
    if self.combatCamera then self.combatCamera:reset() end

    -- Rely primarily on the global HUD managed by UIManager
    -- self:drawUI(width, height) -- Keep if specific combat UI is needed

    -- Draw battle result overlay if combat has ended
    if self.battleResult then
        self:drawBattleResult(width, height)
    end

    -- *** Draw the main UI (HUD) last ***
    if self.game.uiManager and self.game.uiManager.draw then
        self.game.uiManager:draw()
    end
    -- *** END ADDITION ***
end

-- Draw the grid (Use self.grid)
function Combat:drawGrid()
    if not self.grid then return end
    for y = 1, self.grid.height do
        for x = 1, self.grid.width do
            local tile = self.grid:getTile(x, y)
            if not tile then goto continue end -- Safety check

            -- Skip if not visible and fog of war is enabled (if fog is used in combat)
            -- if self.grid.fogOfWar and not tile.visible and not tile.explored then
            --     goto continue
            -- end

            local screenX, screenY = self.grid:gridToScreen(x, y)

            -- Draw tile based on type
            local tileColor = { floor = { 0.5, 0.5, 0.5 }, wall = { 0.3, 0.3, 0.3 }, }
            if tile.type == "floor" then
                if (x + y) % 2 == 0 then
                    tileColor.floor = { 0.6, 0.6, 0.6 }
                else
                    tileColor.floor = { 0.4, 0.4, 0.4 }
                end
            end
            local color = tileColor[tile.type] or { 0.5, 0.5, 0.5 }

            -- Apply fog effect if needed
            -- if self.grid.fogOfWar and not tile.visible and tile.explored then
            --     color = {color[1]*0.5, color[2]*0.5, color[3]*0.5}
            -- end

            love.graphics.setColor(color[1], color[2], color[3], 1)
            love.graphics.rectangle("fill", screenX, screenY, self.grid.tileSize, self.grid.tileSize)
            love.graphics.setColor(0.8, 0.8, 0.8, 0.3)
            love.graphics.rectangle("line", screenX, screenY, self.grid.tileSize, self.grid.tileSize)

            ::continue::
        end
    end
end

-- Draw all units (Use self.playerUnits, self.enemyUnits)
function Combat:drawUnits()
    -- Draw player units
    for _, unit in ipairs(self.playerUnits) do
        -- Add visibility check if fog of war is used in combat
        -- local tile = self.grid:getTile(unit.x, unit.y)
        -- if tile and (tile.visible or not self.grid.fogOfWar) then
        unit:draw()
        -- self:drawHealthBar(unit) -- Let Unit draw its own bar
        -- self:drawStatusEffects(unit) -- Let Unit draw its own effects
        -- end
    end

    -- Draw enemy units
    for _, unit in ipairs(self.enemyUnits) do
        -- Add visibility check if needed
        -- local tile = self.grid:getTile(unit.x, unit.y)
        -- if tile and (tile.visible or not self.grid.fogOfWar) then
        unit:draw()
        -- self:drawHealthBar(unit)
        -- self:drawStatusEffects(unit)
        -- end
    end
end

-- Draw movement highlights (Use self.selectedUnit, self.validMoves)
function Combat:drawMovementHighlights()
    if self.selectedUnit and self.turnManager and self.turnManager:isPlayerTurn() then
        love.graphics.setColor(0.2, 0.8, 0.2, 0.3)
        for _, move in ipairs(self.validMoves) do
            local screenX, screenY = self.grid:gridToScreen(move.x, move.y)
            love.graphics.rectangle("fill", screenX, screenY, self.grid.tileSize, self.grid.tileSize)
        end
    end
end

-- Draw attack highlights (Use self.selectedUnit, self.validAttacks)
function Combat:drawAttackHighlights()
    if self.selectedUnit and self.turnManager and self.turnManager:isPlayerTurn() and not self.selectedUnit.hasAttacked then
        love.graphics.setColor(0.8, 0.2, 0.2, 0.3)
        for _, attack in ipairs(self.validAttacks) do
            local screenX, screenY = self.grid:gridToScreen(attack.x, attack.y)
            love.graphics.rectangle("fill", screenX, screenY, self.grid.tileSize, self.grid.tileSize)
        end
    end
end

-- Draw selection highlight (Use self.selectedUnit, self.targetUnit)
function Combat:drawSelectionHighlight()
    if self.selectedUnit then
        local screenX, screenY = self.grid:gridToScreen(self.selectedUnit.x, self.selectedUnit.y)
        love.graphics.setColor(0.9, 0.9, 0.2, 0.7)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", screenX + 1, screenY + 1, self.grid.tileSize - 2, self.grid.tileSize - 2)
        love.graphics.setLineWidth(1)
    end
    if self.targetUnit then
        local screenX, screenY = self.grid:gridToScreen(self.targetUnit.x, self.targetUnit.y)
        love.graphics.setColor(0.9, 0.2, 0.2, 0.7)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", screenX + 1, screenY + 1, self.grid.tileSize - 2, self.grid.tileSize - 2)
        love.graphics.setLineWidth(1)
    end
end

-- Draw combat log (Use self.combatLog)
function Combat:drawCombatLog(width, height)
    -- Draw log background
    local logX = width - 310
    local logY = 90
    local logW = 300
    local logH = 150
    love.graphics.setColor(0.1, 0.1, 0.1, 0.7)
    love.graphics.rectangle("fill", logX, logY, logW, logH)
    love.graphics.setColor(0.5, 0.5, 0.5, 0.8)
    love.graphics.rectangle("line", logX, logY, logW, logH)

    -- Draw log title
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(self.game.assets.fonts.medium)
    love.graphics.print("Combat Log", logX + 10, logY + 5)

    -- Draw log entries
    love.graphics.setFont(self.game.assets.fonts.small)
    local maxEntries = 8
    local startIndex = math.max(1, #self.combatLog - maxEntries + 1)
    local lineY = logY + 30

    for i = startIndex, #self.combatLog do
        local entry = self.combatLog[i]
        local displayIndex = i - startIndex + 1

        if displayIndex % 2 == 0 then
            love.graphics.setColor(0.8, 0.8, 0.8, 0.8)
        else
            love.graphics.setColor(1, 1, 1, 0.8)
        end

        love.graphics.print(entry, logX + 10, lineY)
        lineY = lineY + 15
    end
end

-- Draw battle result overlay (Use self.battleResult)
function Combat:drawBattleResult(width, height)
    -- Darken the screen
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, width, height)

    -- Draw result text
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(self.game.assets.fonts.title)
    local resultText = self.battleResult == "victory" and "Victory!" or "Defeat!"
    love.graphics.printf(resultText, 0, height / 2 - 50, width, "center")

    -- Draw continue text
    love.graphics.setFont(self.game.assets.fonts.medium)
    love.graphics.printf("Press any key to continue", 0, height / 2 + 20, width, "center")
end

-- Set up default grid (Use self.grid)
function Combat:setupDefaultGrid()
    if not self.grid then return end
    -- Create a simple 8x8 grid with walls around the edges
    for y = 1, self.grid.height do
        for x = 1, self.grid.width do
            local tileType = "floor"
            if x == 1 or x == self.grid.width or y == 1 or y == self.grid.height then
                tileType = "wall"
            end
            self.grid:setTileType(x, y, tileType) -- Let setTileType handle walkability
        end
    end
end

-- Create default enemy units (Use self.enemyUnits, self.grid) - Fallback if no formation data
function Combat:createDefaultEnemyUnits()
    self.enemyUnits = {}
    local Unit = require("src.entities.unit")
    local enemyData = { { unitType = "pawn", x = 6, y = 3 }, { unitType = "pawn", x = 6, y = 7 }, { unitType = "knight", x = 7, y = 5 } }

    for _, data in ipairs(enemyData) do
        local enemy = Unit:new({
            unitType = data.unitType,
            faction = "enemy",
            x = data.x,
            y = data.y,
            grid = self.grid,
            game = self.game
        })
        if self.grid:placeEntity(enemy, enemy.x, enemy.y) then
            table.insert(self.enemyUnits, enemy)
        else
            print("Failed to place default enemy: " .. enemy.unitType)
        end
    end
end

-- Handle turn start event (Use self. variables)
function Combat:handleTurnStart(unit)
    if not unit then
        print("ERROR: handleTurnStart called with nil unit"); return
    end

    -- Reset unit action states (now handled by unit:resetActionState)
    -- unit.hasMoved = false
    -- unit.hasAttacked = false
    -- unit.hasUsedAbility = false

    -- Update visibility if fog of war is used in combat
    -- self.grid:updateVisibility()

    -- If it's a player unit, select it
    if unit.faction == "player" then
        self:selectUnit(unit)
        self:addToCombatLog(unit.unitType:upper() .. "'s turn started")
    else
        self:addToCombatLog("Enemy " .. unit.unitType:upper() .. "'s turn started")
        -- Process enemy AI after a short delay (handled by TurnManager now)
        -- timer.after(0.5, function() self:processEnemyUnit(unit) end)
    end

    -- Apply status effects that trigger at turn start (handled by unit:update)
    -- self.statusEffectsSystem:triggerEffects(unit, "turnStart")

    -- Update HUD
    if self.game.uiManager then
        self.game.uiManager:setPlayerTurn(unit.faction == "player")
        if unit.faction == "player" then
            self.game.uiManager:setSelectedUnit(unit)
            self.game.uiManager.hud.abilityPanel:setUnit(unit) -- Update ability panel
        else
            self.game.uiManager:setSelectedUnit(nil)           -- Deselect player unit
            self.game.uiManager.hud.abilityPanel:setUnit(nil)
        end
        -- AP update handled by onActionPointsChanged callback
    end
end

-- Handle turn end event (Use self. variables)
function Combat:handleTurnEnd(unit)
    if not unit then
        print("ERROR: handleTurnEnd called with nil unit"); return
    end

    -- Apply status effects that trigger at turn end (handled by unit:update)
    -- self.statusEffectsSystem:triggerEffects(unit, "turnEnd")

    -- Deselect unit if it's a player unit
    if unit.faction == "player" and self.selectedUnit == unit then
        self.selectedUnit = nil
        self.validMoves = {}
        self.validAttacks = {}
        if self.game.uiManager then self.game.uiManager:setSelectedUnit(nil) end
        if self.game.uiManager.hud.abilityPanel then self.game.uiManager.hud.abilityPanel:setUnit(nil) end
    end

    self:addToCombatLog(unit.unitType:upper() .. "'s turn ended")

    -- Increment turn count if we've gone through all units (handled by TurnManager)
    -- if self.turnManager.currentInitiativeIndex == 1 then
    --     self.turnCount = self.turnCount + 1
    -- end
end

-- Handle phase change event (Use self. variables)
function Combat:handlePhaseChange(newPhase)
    self:addToCombatLog("Phase changed to: " .. newPhase)
    -- Update UI based on phase (handled by handleTurnStart)
end

-- Handle action points changed event (Use self. variables)
function Combat:handleActionPointsChanged(current, max)
    -- Update UI to show new action points
    if self.game.uiManager then
        self.game.uiManager:setActionPoints(current, max)
    end
end

-- Process enemy unit turn (Now called by TurnManager)
-- function Combat:processEnemyUnit(unit) ... end -- This logic is now in TurnManager or EnemyAI

-- Select a unit (MODIFIED: Check action mode before hiding panel)
function Combat:selectUnit(unit)
    if not self.turnManager or not self.turnManager:isPlayerTurn() then return end
    if not unit or unit.faction ~= "player" then return end

    -- If we are re-selecting the same unit, don't reset the action mode
    if self.selectedUnit == unit then
        print("Combat: Re-selected the same unit. Mode:", self.currentActionMode)
        -- Maybe toggle action mode off if clicking self again? Optional.
        -- self.currentActionMode = nil
        -- self.validMoves = {}; self.validAttacks = {}
        -- if self.game.uiManager then self.game.uiManager:hideAbilityPanel() end
        return -- Don't proceed further if re-selecting same unit
    end

    -- *** ADD LOG ***
    print("Combat:selectUnit - CALLED for unit:", unit.id, "Current Mode was:", self.currentActionMode)
    -- *** END LOG ***

    self.selectedUnit = unit
    self.targetUnit = nil
    -- *** FIX: Only reset mode if NOT selecting via ability panel interaction ***
    -- We reset mode when selecting a *different* unit or clicking empty space.
    -- If an ability was just selected, currentActionMode might be 'ability'.
    -- Let's reset it here for now, as selecting a unit implies starting fresh.
    local previousMode = self.currentActionMode
    self.currentActionMode = nil
    self.validMoves = {}
    self.validAttacks = {}

    self:addToCombatLog("Selected " .. unit.unitType:upper())

    -- Update HUD
    if self.game.uiManager then
        self.game.uiManager:setSelectedUnit(unit)
        self.game.uiManager:setTargetUnit(nil)

        -- *** FIX: Check previous mode before hiding ***
        -- Don't hide if we were just in ability mode from a button click
        -- (Though selecting a unit usually means cancelling ability mode anyway)
        -- Let's simplify: ALWAYS hide when selecting a unit initially.
        -- The issue must be elsewhere if it hides *after* slot selection.
        print("Combat:selectUnit - Hiding Ability Panel")
        self.game.uiManager:hideAbilityPanel()
        -- *** END FIX ***

        if self.game.uiManager.hud.abilityPanel then
            self.game.uiManager.hud.abilityPanel:setUnit(unit)
        end
    end
end

-- Get valid attack targets for a unit (Use self. variables)
function Combat:getValidAttacks(unit)
    local attacks = {}
    if not unit or unit.hasAttacked then return attacks end

    for _, enemy in ipairs(self.enemyUnits) do
        -- Check range using canAttack helper
        if self:canAttack(unit, enemy) then
            table.insert(attacks, { x = enemy.x, y = enemy.y, unit = enemy })
        end
        -- Old range check:
        -- local distance = math.abs(unit.x - enemy.x) + math.abs(unit.y - enemy.y)
        -- if distance <= unit.stats.attackRange then
        --     table.insert(attacks, {x = enemy.x, y = enemy.y, unit = enemy})
        -- end
    end
    return attacks
end

-- Move the selected unit (Use self. variables)
function Combat:moveSelectedUnit(x, y)
    if not self.selectedUnit or not self.turnManager:isPlayerTurn() then return false end
    if self.selectedUnit.hasMoved then
        self:addToCombatLog("Unit has already moved this turn")
        return false
    end

    -- Check if the move is valid
    local isValidMove = false
    for _, move in ipairs(self.validMoves) do
        if move.x == x and move.y == y and not move.isAttack then -- Ensure it's a move, not attack target
            isValidMove = true
            break
        end
    end
    if not isValidMove then
        self:addToCombatLog("Invalid move location")
        return false
    end

    -- Check action points (using the unit's AP)
    local moveCost = 1 -- Assume 1 AP for move
    if not self.selectedUnit.stats or self.selectedUnit.stats.actionPoints < moveCost then
        self:addToCombatLog("Not enough action points")
        return false
    end

    -- Attempt move using Unit's method (which updates grid)
    local moveSuccess = self.selectedUnit:moveTo(x, y) -- moveTo handles grid update

    if moveSuccess then
        self.selectedUnit.hasMoved = true
        self.turnManager:useActionPoints(moveCost) -- Deduct AP via TurnManager
        self.currentActionMode = nil               -- *** FIX: Reset mode after action ***
        self.validMoves = {}                       -- Clear highlights
        self.validAttacks = {}                     -- Clear highlights

        -- Update visibility if needed
        -- self.grid:updateVisibility()

        self:addToCombatLog(self.selectedUnit.unitType:upper() .. " moved to " .. x .. "," .. y)
        return true
    else
        self:addToCombatLog("Move failed (blocked?)")
        return false
    end
end

-- Check if a unit can attack another unit (Use self. variables)
function Combat:canAttack(attacker, defender)
    if not attacker or not defender then return false end
    if attacker.faction == defender.faction then return false end
    if attacker.hasAttacked then return false end

    -- Check action points (using the unit's AP)
    local attackCost = 1
    if not attacker.stats or attacker.stats.actionPoints < attackCost then
        return false -- Not enough AP
    end

    -- Check range
    local distance = math.abs(attacker.x - defender.x) + math.abs(attacker.y - defender.y)
    return distance <= (attacker.stats.attackRange or 1)
end

-- Attack a unit (Use self. variables)
function Combat:attackUnit(attacker, defender)
    if not self:canAttack(attacker, defender) then
        self:addToCombatLog("Cannot attack target")
        return false
    end

    -- Process attack using combat system
    local success = self.combatSystem:processAttack(attacker, defender) -- CombatSystem handles logging, AP deduction, defeat check

    if success then
        -- Recalculate valid moves/attacks for the attacker
        self.validMoves = ChessMovement.getValidMoves(attacker.movementPattern, attacker.x, attacker.y, self.grid,
            attacker, attacker.stats.moveRange)
        self.validAttacks = self:getValidAttacks(attacker)
        -- Update target info in HUD
        if self.game.uiManager then self.game.uiManager:setTargetUnit(defender) end
    end

    return success
end

-- Defeat a unit (Use self. variables) - Called by CombatSystem now
function Combat:handleUnitDefeat(unit)
    print("Combat:handleUnitDefeat - Handling defeat for " .. unit.id)
    -- Remove from grid
    self.grid:removeEntity(unit) -- Use grid's method

    -- Remove from appropriate list
    local listToRemoveFrom = nil
    if unit.faction == "player" then
        listToRemoveFrom = self.playerUnits
    else
        listToRemoveFrom = self.enemyUnits
    end

    if listToRemoveFrom then
        for i = #listToRemoveFrom, 1, -1 do -- Iterate backwards when removing
            if listToRemoveFrom[i] == unit then
                table.remove(listToRemoveFrom, i)
                print("  Removed unit from " .. unit.faction .. " list.")
                break
            end
        end
    end

    -- Remove from initiative order in TurnManager
    if self.turnManager and self.turnManager.initiativeOrder then
        for i = #self.turnManager.initiativeOrder, 1, -1 do
            if self.turnManager.initiativeOrder[i] == unit then
                table.remove(self.turnManager.initiativeOrder, i)
                print("  Removed unit from initiative order.")
                -- Adjust current index if needed
                if self.turnManager.currentInitiativeIndex > i then
                    self.turnManager.currentInitiativeIndex = self.turnManager.currentInitiativeIndex - 1
                end
                break
            end
        end
    end


    -- Combat log entry is handled by CombatSystem:applyDamage

    -- Check for combat end immediately after removal
    self:checkCombatEnd(true) -- Pass flag to indicate a unit was just defeated
end

-- Add entry to combat log (Use self.combatLog)
function Combat:addToCombatLog(text)
    table.insert(self.game.combatLog, text)
    if #self.game.combatLog > 50 then table.remove(self.game.combatLog, 1) end
    print("[CombatLog] " .. text)
end

-- Check for end of combat conditions (Use self. variables)
function Combat:checkCombatEnd(unitJustDefeated)
    -- Only check if the battle isn't already decided
    if self.battleResult then return end

    local playerUnitsAlive = #self.playerUnits > 0
    local enemyUnitsAlive = #self.enemyUnits > 0

    -- Check if all player units are defeated
    if not playerUnitsAlive then
        self.battleResult = "defeat"
        self:addToCombatLog("Combat ended - Player defeated")
        self:endCombat()
        return
    end

    -- Check if all enemy units are defeated
    if not enemyUnitsAlive then
        self.battleResult = "victory"
        self:addToCombatLog("Combat ended - Player victorious")
        self:endCombat()
        return
    end

    -- If a unit was just defeated, we might need to force the turn manager to re-evaluate
    -- This is now handled by removing the unit from initiative order in handleUnitDefeat
    -- if unitJustDefeated and self.turnManager then
    --    -- Maybe force recalculation or check if current unit is still valid
    -- end
end

-- NEW: Function to end combat and return to the previous state
function Combat:endCombat()
    print("Combat:endCombat - Result: " .. self.battleResult)
    -- Prepare return data (updated player party)
    local updatedPlayerParty = self.playerParty -- Pass back the (potentially modified) list

    -- Switch back to the return state
    if self.returnState then
        print("  Switching back to return state: " .. tostring(self.returnState))
        -- Ensure the game object is passed correctly
        gamestate.switch(self.returnState, self.game, updatedPlayerParty, self.battleResult)
    else
        print("  ERROR: No return state defined! Switching to main menu as fallback.")
        gamestate.switch(require("src.states.menu"), self.game)
    end
end

-- *** ADD: New function to handle HUD action button clicks ***
function Combat:handleHudAction(actionId)
    if not self.selectedUnit then
        self:addToCombatLog("Select a unit first!")
        return
    end

    if actionId == "end" then
        if self.turnManager then self.turnManager:endTurn() end
    else
        -- Set mode first
        self.currentActionMode = actionId
        self:addToCombatLog("Mode: " .. actionId)
        self.validMoves = {}; self.validAttacks = {}
        -- Deselect ability slot in panel when changing modes
        if self.game.uiManager and self.game.uiManager.hud.abilityPanel then
             self.game.uiManager.hud.abilityPanel:setSelectedSlot(nil)
        end

        -- Handle panel visibility and highlight calculation based on action
        if actionId == "move" then
            print("Combat:handleHudAction - Hiding panel for MOVE")
            if self.game.uiManager then self.game.uiManager:hideAbilityPanel() end -- Hide for move
            if not self.selectedUnit.hasMoved then
                self.validMoves = ChessMovement.getValidMoves(self.selectedUnit.movementPattern, self.selectedUnit.x, self.selectedUnit.y, self.grid, self.selectedUnit, self.selectedUnit.stats.moveRange)
            else
                self:addToCombatLog("Unit has already moved.")
                self.currentActionMode = nil -- Cancel mode if invalid
            end
        elseif actionId == "attack" then
            print("Combat:handleHudAction - Hiding panel for ATTACK")
            if self.game.uiManager then self.game.uiManager:hideAbilityPanel() end -- Hide for attack
            if not self.selectedUnit.hasAttacked then
                self.validAttacks = self:getValidAttacks(self.selectedUnit)
            else
                 self:addToCombatLog("Unit has already attacked.")
                 self.currentActionMode = nil -- Cancel mode if invalid
            end
        elseif actionId == "ability" then
            if not self.selectedUnit.hasUsedAbility then
                 print("Combat:handleHudAction - Showing panel for ABILITY")
                 if self.game.uiManager then self.game.uiManager:showAbilityPanel() end
                 -- TODO: Highlight ability range later if needed
            else
                 self:addToCombatLog("Unit has already used an ability.")
                 self.currentActionMode = nil -- Cancel mode if invalid
                 print("Combat:handleHudAction - Hiding panel (ability already used)")
                 if self.game.uiManager then self.game.uiManager:hideAbilityPanel() end -- Hide if invalid
            end
        end
    end
end

-- *** ADD: New function to handle ability slot clicks from HUD ***
function Combat:handleAbilitySlotClick(slotIndex, abilityId, canUse)
    if not self.selectedUnit then return end  -- Need selected unit
    if self.currentActionMode ~= "ability" then
        print("WARN: Ability slot clicked but not in ability mode.")
        -- Optionally switch to ability mode here?
        -- self.currentActionMode = "ability"
        -- if self.game.uiManager then self.game.uiManager:showAbilityPanel() end
        return
    end

    local abilityPanel = self.game.uiManager and self.game.uiManager.hud.abilityPanel
    if not abilityPanel then return end

    if abilityPanel.selectedSlot == slotIndex then
        -- Clicked the already selected slot -> Deselect
        abilityPanel:setSelectedSlot(nil)
        self:addToCombatLog("Ability deselected.")
        -- Keep ability mode active, but no specific ability selected now
    elseif canUse then
        -- Clicked a new, usable slot -> Select
        abilityPanel:setSelectedSlot(slotIndex)
        self:addToCombatLog("Selected Ability: " .. (abilityPanel:getSelectedAbility().name or abilityId))
    else
        -- Clicked an unusable slot
        self:addToCombatLog("Cannot use this ability now (cooldown/cost).")
    end
end

-- *** ADD: New function to handle grid clicks ***
function Combat:handleGridClick(screenX, screenY, button)
    -- Convert screen coordinates to world/grid
    if not self.combatCamera then return false end
    local worldX, worldY = self.combatCamera:screenToWorld(screenX, screenY)
    local gridX, gridY = self.grid:screenToGrid(worldX, worldY)
    if not self.grid:isInBounds(gridX, gridY) then return end

    -- Right Click: Cancel action/deselect unit
    if button == 2 then
        self:cancelAction()
        return
    end

    -- Left Click on Grid
    if button == 1 then
        local clickedEntity = self.grid:getEntityAt(gridX, gridY)

        -- If an action mode is active
        if self.currentActionMode then
            if not self.selectedUnit then
                self.currentActionMode = nil; return
            end                                                                    -- Safety check

            if self.currentActionMode == "move" then
                local isValidMove = false; for _, move in ipairs(self.validMoves) do if move.x == gridX and move.y == gridY and not move.isAttack then
                        isValidMove = true; break
                    end end
                if isValidMove then self:moveSelectedUnit(gridX, gridY) else self:addToCombatLog("Invalid move target.") end
            elseif self.currentActionMode == "attack" then
                local isValidAttack = false; local targetEntity = nil; for _, attack in ipairs(self.validAttacks) do if attack.x == gridX and attack.y == gridY then
                        isValidAttack = true; targetEntity = attack.unit; break
                    end end
                if isValidAttack and targetEntity then self:attackUnit(self.selectedUnit, targetEntity) else self
                        :addToCombatLog("Invalid attack target.") end
            elseif self.currentActionMode == "ability" then
                local selectedAbilityData = self.game.uiManager and
                self.game.uiManager.hud.abilityPanel:getSelectedAbility()
                if selectedAbilityData then
                    -- Get the ability definition first
                    local ability = self.game.specialAbilitiesSystem:getAbility(selectedAbilityData.id)
                    if not ability then
                        self:addToCombatLog("Unknown ability: " .. selectedAbilityData.id)
                        return
                    end
                    
                    -- Check range BEFORE attempting to use ability
                    if ability.attackRange > 0 then
                        local distance = math.abs(self.selectedUnit.x - gridX) + math.abs(self.selectedUnit.y - gridY)
                        if distance > ability.attackRange then
                            self:addToCombatLog(ability.name .. ": Target out of range (" .. distance .. "/" .. ability.attackRange .. ")")
                            return
                        end
                    end
                    
                    -- Now call useAbility on the UNIT
                    local success = self.selectedUnit:useAbility(selectedAbilityData.id, clickedEntity, gridX, gridY)
                    
                    if success then
                        -- Reset mode etc. after successful use
                        self.currentActionMode = nil
                        self.validMoves = {}
                        self.validAttacks = {}
                        -- Optionally hide panel again?
                        -- if self.game.uiManager then self.game.uiManager:hideAbilityPanel() end
                    end
                    -- No need for addToCombatLog here, Unit:useAbility or system should handle logs
                else
                    self:addToCombatLog("No ability selected. Click an ability icon first.")
                end
            end
        else                                                                   -- No action mode active - handle unit selection
            if clickedEntity and clickedEntity.faction == "player" then
                if clickedEntity == self.selectedUnit then
                    self:cancelAction()                                        -- Deselect if clicking self
                else
                    self:selectUnit(clickedEntity)
                end
            elseif clickedEntity and clickedEntity.faction == "enemy" then
                self.targetUnit = clickedEntity; if self.game.uiManager then self.game.uiManager:setTargetUnit(
                    clickedEntity) end
            else                    -- Clicked empty space
                self:cancelAction() -- Deselect
            end
        end
    end
end

-- *** ADD: New function to handle keyboard movement ***
function Combat:handleKeyboardMove(dx, dy)
    if not self.selectedUnit then return end

    local targetX = self.selectedUnit.x + dx
    local targetY = self.selectedUnit.y + dy

    -- If in move mode, try to move
    if self.currentActionMode == "move" then
        self:moveSelectedUnit(targetX, targetY)
        -- If in attack mode, try to attack
    elseif self.currentActionMode == "attack" then
        local targetEntity = self.grid:getEntityAt(targetX, targetY)
        if targetEntity and targetEntity.faction ~= self.selectedUnit.faction then
            self:attackUnit(self.selectedUnit, targetEntity)
        else
            self:addToCombatLog("No enemy target in that direction.")
        end
        -- If in ability mode with a selected ability, try to use it
    elseif self.currentActionMode == "ability" then
        local selectedAbilityData = self.game.uiManager and self.game.uiManager.hud.abilityPanel:getSelectedAbility()
        if selectedAbilityData then
            local targetEntity = self.grid:getEntityAt(targetX, targetY)
            self:useAbility(self.selectedUnit, selectedAbilityData.id, targetEntity, targetX, targetY)
        else
            self:addToCombatLog("No ability selected.")
        end
        -- If no mode active, maybe just select the tile? (Optional)
        -- else
        --    print("Keyboard move with no action mode active.")
    end
end

-- *** ADD: New function to handle keyboard confirm ***
function Combat:handleKeyboardConfirm()
    if not self.selectedUnit then return end
    -- Example: If targeting an enemy, confirm attack?
    if self.targetUnit and self.currentActionMode ~= "move" then  -- Don't attack if explicitly moving
        if self:canAttack(self.selectedUnit, self.targetUnit) then
            self:attackUnit(self.selectedUnit, self.targetUnit)
        else
            self:addToCombatLog("Cannot attack target.")
        end
        -- Example: If ability selected, use on self?
    elseif self.currentActionMode == "ability" then
        local selectedAbilityData = self.game.uiManager and self.game.uiManager.hud.abilityPanel:getSelectedAbility()
        if selectedAbilityData then
            local ability = self.specialAbilitiesSystem:getAbility(selectedAbilityData.id)
            if ability and ability.targetType == "self" then
                -- *** FIX: Call useAbility on the UNIT ***
                local success = self.selectedUnit:useAbility(selectedAbilityData.id, self.selectedUnit, self.selectedUnit.x, self.selectedUnit.y)
                -- *** END FIX ***
                if success then self.currentActionMode = nil end -- Reset mode
            else
                self:addToCombatLog("Select a target for the ability.")
            end
        end
    else
        -- Default confirm action? Maybe end turn if no other action?
        -- if self.turnManager then self.turnManager:endTurn() end
        print("Confirm pressed - No default action defined.")
    end
end

-- *** ADD: New function to handle ability hotkeys ***
function Combat:handleAbilityHotkey(index)
    if not self.selectedUnit then return end
    local abilityPanel = self.game.uiManager and self.game.uiManager.hud.abilityPanel
    if not abilityPanel or index < 1 or index > #abilityPanel.slots then return end

    local slotData = abilityPanel.slots[index]
    if not slotData then return end

    -- If already in ability mode and this slot is selected, maybe try to use it?
    if self.currentActionMode == "ability" and abilityPanel.selectedSlot == index then
        -- Requires target selection first for most abilities
        self:addToCombatLog("Select a target for " .. slotData.name)
        -- Or if self-targeting, use it:
        local ability = self.specialAbilitiesSystem:getAbility(slotData.id)
        if ability and ability.targetType == "self" then
            -- *** END FIX ***
            if success then self.currentActionMode = nil end -- Reset mode
        else
            self:addToCombatLog("Select a target for " .. slotData.name)
        end
        -- Otherwise, select the ability and enter ability mode
    elseif slotData.canUse then
        self.currentActionMode = "ability"
        abilityPanel:setSelectedSlot(index)
        if self.game.uiManager then self.game.uiManager:showAbilityPanel() end
        self:addToCombatLog("Selected Ability: " .. slotData.name)
    else
        self:addToCombatLog("Cannot use " .. slotData.name .. " (cooldown/cost).")
    end
end

-- Modify cancelAction to log when called
function Combat:cancelAction()
    -- *** ADD LOG ***
    print("Combat:cancelAction - CALLED. Current Mode was:", self.currentActionMode)
    -- *** END LOG ***
    self.currentActionMode = nil
    self.selectedUnit = nil
    self.targetUnit = nil
    self.validMoves = {}
    self.validAttacks = {}
    if self.game.uiManager then
        self.game.uiManager:setSelectedUnit(nil)
        self.game.uiManager:setTargetUnit(nil)
        print("Combat:cancelAction - Hiding Ability Panel")  -- Keep this log
        self.game.uiManager:hideAbilityPanel()               -- This call will now print a traceback
        if self.game.uiManager.hud.abilityPanel then
            self.game.uiManager.hud.abilityPanel:setSelectedSlot(nil)
            self.game.uiManager.hud.abilityPanel:setUnit(nil)
        end
    end
    self:addToCombatLog("Action cancelled")
end

return Combat
