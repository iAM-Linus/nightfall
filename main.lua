-- main.lua - Entry point for Nightfall Chess
-- Handles initialization, game states, and the main loop

-- Import required libraries
local gamestate = require("lib.hump.gamestate")
local timer = require("lib.hump.timer")
local lurker = require("lib.lurker")

-- Import Systems
local InputHandler = require("src.systems.input_handler")
local AssetManager = require("src.systems.asset_manager")
local AnimationManager = require("src.systems.animation_manager") -- Load manager base
require("src.systems.attack_animations") -- Extend manager
require("src.systems.ability_animations") -- Extend manager
local SpecialAbilitiesSystem = require("src.systems.special_abilities_system")
local StatusEffectsSystem = require("src.systems.status_effects_system")
local ExperienceSystem = require("src.systems.experience_system")
local CombatSystem = require("src.systems.combat_system")
local TurnManager = require("src.systems.turn_manager")
-- Add other required systems (AI, Inventory, Meta, Procedural, UI etc.)
local UIManager = require("src.ui.ui_manager")
local EnemyAI = require("src.systems.enemy_ai")
local InventoryManager = require("src.systems.inventory_manager")
local MetaProgression = require("src.systems.meta_progression")
local ProceduralGeneration = require("src.systems.procedural_generation")

-- Import game states
local states = {
    -- These will be loaded dynamically later
}

-- Global game object to store shared data
local game = {
    config = {
        gridSize = 8,
        tileSize = 64,
        debug = false,
        showFPS = false -- Added flag for FPS display
    },
    assets = nil, -- Will be initialized by AssetManager
    state = {
        currentLevel = 1,
        playerTurn = true, -- Might be managed by TurnManager later
        actionPoints = 3, -- Might be managed by TurnManager later
        selectedUnit = nil
    },
    -- System instances
    assetManager = nil,
    animationManager = nil,
    specialAbilitiesSystem = nil,
    statusEffectsSystem = nil,
    experienceSystem = nil,
    combatSystem = nil,
    turnManager = nil,
    uiManager = nil,
    enemyAI = nil,
    inventoryManager = nil,
    metaProgression = nil,
    proceduralGeneration = nil,
    grid = nil -- Grid might be state-specific or global
}

-- Test runner integration (conditional)
local runTestRunner = false
for i, arg in ipairs(arg or {}) do
    if arg == "--test" then
        runTestRunner = true
        break
    end
end

-- Initialize the game
function love.load(args)
    if runTestRunner then
        -- Run tests directly and quit
        local testRunner = require "src.test.test_runner" -- Use the correct path
        local success = testRunner() -- Assuming the runner returns true/false
        love.event.quit(success and 0 or 1)
    else
        -- Initialize AssetManager
        game.assetManager = AssetManager:new()
        game.assets = game.assetManager -- Assign manager's tables to game.assets

        -- Load essential assets (fonts first)
        game.assetManager:loadFont("default", 24, "assets/fonts/default.ttf") -- <-- Replace with your actual font filename

        -- Check if the font loaded successfully, otherwise use LÖVE's default
        if not game.assetManager:getFont("default", 12) then
            print("WARNING: Could not load specified default font. Falling back to LÖVE default.")
            game.assets.fonts.small = love.graphics.newFont(12) -- LÖVE default
        else
            game.assets.fonts.small = game.assetManager:getFont("default", 18)
        end
        -- Use getFont for other sizes, it will use the loaded 'default' or the fallback
        game.assets.fonts.medium = game.assetManager:getFont("default", 24)
        game.assets.fonts.large = game.assetManager:getFont("default", 36)
        game.assets.fonts.title = game.assetManager:getFont("default", 48)

        -- Set default font and filter
        love.graphics.setFont(game.assets.fonts.medium or love.graphics.getFont()) -- Use fallback if medium failed
        love.graphics.setDefaultFilter("nearest", "nearest")

        -- Create placeholder assets using AssetManager
        game.assetManager:createPlaceholders(game.config.tileSize)
        print("Main: Placeholders created.")

        -- Initialize other systems, passing the 'game' table
        game.inputHandler = InputHandler:new(game)
        game.animationManager = AnimationManager:new(game)
        game.statusEffectsSystem = StatusEffectsSystem:new(game)
        game.experienceSystem = ExperienceSystem:new(game)
        game.combatSystem = CombatSystem:new(game) -- CombatSystem needs StatusEffectsSystem
        game.specialAbilitiesSystem = SpecialAbilitiesSystem:new(game)
        game.turnManager = TurnManager:new(game)
        game.uiManager = UIManager:new(game)
        game.enemyAI = EnemyAI:new(game)
        game.inventoryManager = InventoryManager:new(game)
        game.metaProgression = MetaProgression:new() -- Meta doesn't strictly need 'game' if self-contained
        game.proceduralGeneration = ProceduralGeneration:new(game)
        
        -- Load game states
        states.menu = require("src.states.menu")
        states.game = require("src.states.game")
        states.combat = require("src.states.combat")
        states.inventory = require("src.states.inventory")
        states.gameover = require("src.states.gameover")
        states.team_management = require("src.states.team_management")
        
        game.inputHandler:registerLoveCallbacks()

        -- Initialize game state system (HUMP)
        gamestate.registerEvents() -- HUMP needs this to hook into LOVE callbacks
        gamestate.switch(states.menu, game) -- Pass the global game table
    end
end

-- Update game logic
function love.update(dt)
    -- HUMP gamestate automatically calls the current state's update function
    -- if gamestate.registerEvents() was called.

    -- Update global systems
    if timer and timer.update then
        timer.update(dt)
    end
    if lurker and lurker.update then
        --lurker.update()
    end
    if game.animationManager and game.animationManager.update then
        game.animationManager:update(dt)
    end
    if game.uiManager and game.uiManager.update then
        game.uiManager:update(dt)
    end

    gamestate.current():update(dt)

    -- Add other global system updates here if needed

    -- *** REMOVE InputHandler:update call ***
    if game.inputHandler and game.inputHandler.update then
         game.inputHandler:update(dt)
    end
end

-- Draw the game
function love.draw()
     -- HUMP gamestate automatically calls the current state's draw function.

    -- Draw FPS counter in debug mode
    if game.config.debug and game.config.showFPS then
        love.graphics.setColor(1, 1, 0, 1)
        love.graphics.setFont(game.assets.fonts.small) -- Use loaded font
        love.graphics.print("FPS: " .. love.timer.getFPS(), 150, 10)
        love.graphics.setColor(1, 1, 1, 1)
    end
end

function love.keypressed(key, scancode, isrepeat)
    if gamestate.current().keypressed then
        gamestate.current():keypressed(key, scancode, isrepeat)
    end
end

function love.keyreleased(key, scancode)
     if gamestate.current().keyreleased then
        gamestate.current():keyreleased(key, scancode)
    end
end

function love.mousepressed(x, y, button, istouch, presses)
    if gamestate.current().mousepressed then
        gamestate.current():mousepressed(x, y, button, istouch, presses)
    end
end

function love.mousereleased(x, y, button, istouch, presses)
     if gamestate.current().mousereleased then
        gamestate.current():mousereleased(x, y, button, istouch, presses)
    end
end

function love.mousemoved(x, y, dx, dy, istouch)
     if gamestate.current().mousemoved then
        gamestate.current():mousemoved(x, y, dx, dy, istouch)
    end
end

function love.wheelmoved(x, y)
     if gamestate.current().wheelmoved then
        gamestate.current():wheelmoved(x, y)
    end
end

function love.resize(w, h)
   if game.uiManager and game.uiManager.resize then
       game.uiManager:resize(w, h)
   end
    -- HUMP handles state-specific resize
end