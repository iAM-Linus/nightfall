-- Game State Manager for Nightfall Chess
-- Handles different game states (menu, gameplay, combat, etc.)

local class = require("lib.middleclass.middleclass")
local gamestate = require("lib.hump.gamestate")
local timer = require("lib.hump.timer")
local lovelytoasts = require("lib.lovelytoasts")

local GameStateManager = class("GameStateManager")

function GameStateManager:initialize(game)
    self.game = game
    self.states = {}
    self.currentState = nil
    
    -- Initialize toast system
    lovelytoasts.init({
        font = game.assets.fonts.medium,
        duration = 3,
        fadeTime = 0.5
    })
    
    -- Register game states
    self:registerStates()
end

-- Register all game states
function GameStateManager:registerStates()
    -- Load state modules
    self.states.menu= require("src.states.menu")
    self.states.game = require("src.states.game")
    self.states.combat = require("src.states.combat")
    self.states.inventory = require("src.states.inventory")
    self.states.gameover = require("src.states.gameover")
    
    -- Register events with HUMP gamestate
    gamestate.registerEvents()
end

-- Switch to a different state
function GameStateManager:switchTo(stateName, ...)
    if not self.states[stateName] then
        error("State '" .. stateName .. "' does not exist")
    end
    
    self.currentState = stateName
    gamestate.switch(self.states[stateName], self.game, ...)
end

-- Push a state onto the stack
function GameStateManager:pushState(stateName, ...)
    if not self.states[stateName] then
        error("State '" .. stateName .. "' does not exist")
    end
    
    self.currentState = stateName
    gamestate.push(self.states[stateName], self.game, ...)
end

-- Pop the current state from the stack
function GameStateManager:popState()
    gamestate.pop()
    
    -- Update current state name
    for name, state in pairs(self.states) do
        if gamestate.current() == state then
            self.currentState = name
            break
        end
    end
end

-- Update the current state
function GameStateManager:update(dt)
    -- Update timers
    timer.update(dt)
    
    -- Update toast notifications
    lovelytoasts.update(dt)
end

-- Draw the current state
function GameStateManager:draw()
    -- Draw toast notifications on top
    lovelytoasts.draw()
end

-- Show a toast notification
function GameStateManager:showToast(message, options)
    lovelytoasts.show(message, options)
end

return GameStateManager
