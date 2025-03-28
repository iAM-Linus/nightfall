-- main.lua - Entry point for Nightfall Chess
-- Handles initialization, game states, and the main loop

-- Import required libraries
local gamestate = require("lib.hump.gamestate")
local timer = require("lib.hump.timer")
local lurker = require("lib.lurker")
-- Require the animation integration module
local AnimationIntegration = require("src.systems.animation_integration")

-- Import game states
local states = {
    -- These will be loaded from the src/states directory
}

-- Global game object to store shared data
local game = {
    -- Game configuration
    config = {
        gridSize = 8,
        tileSize = 64,
        debug = false
    },
    
    -- Asset storage
    assets = {
        images = {},
        fonts = {},
        sounds = {}
    },
    
    -- Game state
    state = {
        currentLevel = 1,
        playerTurn = true,
        actionPoints = 3,
        selectedUnit = nil
    }
}

-- Initialize the game
function love.load(arg)
    if arg[1] == "--test" then
        local testRunner = require "src.test_runner"
        local success = testRunner()
        print(success)
        love.event.quit(success and 0 or 1)
    else
    
        -- Set default filter mode for pixel art
        love.graphics.setDefaultFilter("nearest", "nearest")

        local animationManager = AnimationIntegration.integrateAnimationSystem(game)
        
        -- Load game states
        states.menu = require("src.states.menu")
        states.game = require("src.states.game")
        states.combat = require("src.states.combat")
        states.inventory = require("src.states.inventory")
        states.gameover = require("src.states.gameover")

        
        
        -- Load assets
        loadAssets()


        
        -- Initialize game state system
        gamestate.registerEvents()
        gamestate.switch(states.menu, game)
    end
end

-- Update game logic
function love.update(dt)
    if timer and timer.update then
        timer.update(dt)
    end

    -- Check for hot reloading changes
    if lurker and lurker.update then
        lurker.update()
    end

    -- Update the Animation Manager (Check if game.animationManager exists)
    if game and game.animationManager and game.animationManager.update then
        game.animationManager:update(dt)
    end

    -- Update the current game state via HUMP Gamestate (This calls the active state's update)
    if gamestate and gamestate.update then
       -- gamestate:update(dt) -- HUMP gamestate usually hooks love.update directly
       -- If you are manually calling the state's update, make sure it happens.
       -- If gamestate.registerEvents() was called, this might be redundant.
       -- Check how HUMP integrates love.update.
       -- Let's assume HUMP handles calling the current state's update.
    end
end

-- Draw the game
function love.draw()
    -- Drawing is handled by the current game state
    -- Additional global UI elements can be drawn here
    
    -- Draw FPS counter in debug mode
    if game.config.debug then
        love.graphics.setColor(1, 1, 1, 1)
        --love.graphics.print("FPS: " .. love.timer.getFPS(), 10, 10)
    end
end

-- Handle key presses
function love.keypressed(key)
    -- Global key handlers
    if key == "f1" then
        game.config.debug = not game.config.debug
    elseif key == "escape" then
        -- This will be handled by individual states
    end
end

-- Load all game assets
function loadAssets()
    -- Load fonts
    game.assets.fonts.small = love.graphics.newFont(12)
    game.assets.fonts.medium = love.graphics.newFont(18)
    game.assets.fonts.large = love.graphics.newFont(24)
    game.assets.fonts.title = love.graphics.newFont(36)
    
    -- Set default font
    love.graphics.setFont(game.assets.fonts.medium)
    
    -- Create placeholder images for development
    createPlaceholderAssets()
end

-- Create placeholder assets for development
function createPlaceholderAssets()
    -- Create placeholder unit images
    local unitTypes = {"pawn", "knight", "bishop", "rook", "queen", "king"}
    local unitColors = {"white", "black"}
    
    for _, color in ipairs(unitColors) do
        for _, unitType in ipairs(unitTypes) do
            local canvas = love.graphics.newCanvas(game.config.tileSize, game.config.tileSize)
            love.graphics.setCanvas(canvas)
            
            -- Background
            love.graphics.setColor(0.2, 0.2, 0.3, 1)
            love.graphics.rectangle("fill", 0, 0, game.config.tileSize, game.config.tileSize)
            
            -- Border
            love.graphics.setColor(color == "white" and 0.9 or 0.1, 0.9, 0.9, 1)
            love.graphics.rectangle("line", 2, 2, game.config.tileSize-4, game.config.tileSize-4)
            
            -- Unit type text
            love.graphics.setColor(color == "white" and 0.9 or 0.1, 0.9, 0.9, 1)
            love.graphics.printf(unitType:sub(1, 1):upper(), 0, game.config.tileSize/2-10, game.config.tileSize, "center")
            
            love.graphics.setCanvas()
            
            -- Store the image
            game.assets.images[color .. "_" .. unitType] = canvas
        end
    end
    
    -- Create placeholder tile images
    local tileTypes = {"floor", "wall", "water", "lava", "grass"}
    
    for _, tileType in ipairs(tileTypes) do
        local canvas = love.graphics.newCanvas(game.config.tileSize, game.config.tileSize)
        love.graphics.setCanvas(canvas)
        
        -- Base color
        local colors = {
            floor = {0.5, 0.5, 0.5},
            wall = {0.3, 0.3, 0.3},
            water = {0.2, 0.2, 0.8},
            lava = {0.8, 0.2, 0.2},
            grass = {0.2, 0.7, 0.2}
        }
        
        love.graphics.setColor(colors[tileType][1], colors[tileType][2], colors[tileType][3], 1)
        love.graphics.rectangle("fill", 0, 0, game.config.tileSize, game.config.tileSize)
        
        -- Border
        love.graphics.setColor(0.8, 0.8, 0.8, 0.5)
        love.graphics.rectangle("line", 0, 0, game.config.tileSize, game.config.tileSize)
        
        love.graphics.setCanvas()
        
        -- Store the image
        game.assets.images["tile_" .. tileType] = canvas
    end
    
    -- Create UI elements
    local uiElements = {"button", "panel", "highlight", "selected"}
    
    for _, element in ipairs(uiElements) do
        local canvas = love.graphics.newCanvas(game.config.tileSize, game.config.tileSize)
        love.graphics.setCanvas(canvas)
        
        if element == "button" then
            love.graphics.setColor(0.3, 0.3, 0.6, 1)
            love.graphics.rectangle("fill", 0, 0, game.config.tileSize, game.config.tileSize, 8, 8)
            love.graphics.setColor(0.8, 0.8, 0.9, 1)
            love.graphics.rectangle("line", 2, 2, game.config.tileSize-4, game.config.tileSize-4, 6, 6)
        elseif element == "panel" then
            love.graphics.setColor(0.2, 0.2, 0.3, 0.9)
            love.graphics.rectangle("fill", 0, 0, game.config.tileSize, game.config.tileSize, 4, 4)
            love.graphics.setColor(0.5, 0.5, 0.6, 1)
            love.graphics.rectangle("line", 1, 1, game.config.tileSize-2, game.config.tileSize-2, 3, 3)
        elseif element == "highlight" then
            love.graphics.setColor(0.9, 0.9, 0.2, 0.5)
            love.graphics.rectangle("fill", 0, 0, game.config.tileSize, game.config.tileSize)
        elseif element == "selected" then
            love.graphics.setColor(0.2, 0.9, 0.2, 0.7)
            love.graphics.rectangle("line", 2, 2, game.config.tileSize-4, game.config.tileSize-4, 2, 2)
            love.graphics.rectangle("line", 4, 4, game.config.tileSize-8, game.config.tileSize-8, 2, 2)
        end
        
        love.graphics.setCanvas()
        
        -- Store the image
        game.assets.images["ui_" .. element] = canvas
    end
end

-- Return the game object for use in other modules
return game