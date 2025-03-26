-- Menu State for Nightfall Chess
-- Handles the main menu interface and navigation

local gamestate = require("lib.hump.gamestate")
local timer = require("lib.hump.timer")

local Menu = {}

-- Menu options
local options = {
    {text = "New Game", action = "newGame"},
    {text = "Continue", action = "continue"},
    {text = "Options", action = "options"},
    {text = "Credits", action = "credits"},
    {text = "Quit", action = "quit"}
}

local selectedOption = 1
local titleFont = nil
local menuFont = nil
local smallFont = nil
local backgroundImage = nil
local logoImage = nil

-- Initialize the menu state
function Menu:init()
    -- This function is called only once when the state is first created
end

-- Enter the menu state
function Menu:enter(previous, game)
    self.game = game
    
    -- Load fonts
    titleFont = game.assets.fonts.title
    menuFont = game.assets.fonts.large
    smallFont = game.assets.fonts.small
    
    -- Set up background animation timer
    self.backgroundTimer = 0
    self.logoScale = 1
    self.logoScaleDir = 1
    
    -- Reset selection
    selectedOption = 1
    
    -- Set up menu animations
    self.menuAlpha = 0
    timer.tween(0.5, self, {menuAlpha = 1}, 'out-quad')
    
    -- Set up option animations
    self.optionOffsets = {}
    for i = 1, #options do
        self.optionOffsets[i] = -50
        timer.tween(0.5 + i * 0.1, self.optionOffsets, {[i] = 0}, 'out-back')
    end
    
    -- Play menu music if available
    -- if game.assets.sounds.menuMusic then
    --     love.audio.play(game.assets.sounds.menuMusic)
    -- end
end

-- Leave the menu state
function Menu:leave()
    -- Stop menu music if it's playing
    -- if self.game.assets.sounds.menuMusic then
    --     love.audio.stop(self.game.assets.sounds.menuMusic)
    -- end
end

-- Update menu logic
function Menu:update(dt)
    -- Update background animation
    self.backgroundTimer = self.backgroundTimer + dt
    
    -- Animate logo
    self.logoScale = self.logoScale + self.logoScaleDir * dt * 0.05
    if self.logoScale > 1.05 then
        self.logoScale = 1.05
        self.logoScaleDir = -1
    elseif self.logoScale < 0.95 then
        self.logoScale = 0.95
        self.logoScaleDir = 1
    end
    
    -- Update timers
    timer.update(dt)
end

-- Draw the menu
function Menu:draw()
    local width, height = love.graphics.getDimensions()
    
    -- Draw background
    love.graphics.setColor(0.1, 0.1, 0.2, 1)
    love.graphics.rectangle("fill", 0, 0, width, height)
    
    -- Draw animated background elements
    self:drawBackgroundElements(width, height)
    
    -- Draw title
    love.graphics.setColor(0.9, 0.9, 1, 1)
    love.graphics.setFont(titleFont)
    love.graphics.printf("Nightfall Chess", 0, height * 0.15, width, "center")
    
    -- Draw menu options
    love.graphics.setFont(menuFont)
    for i, option in ipairs(options) do
        local y = height * 0.4 + (i - 1) * 50 + self.optionOffsets[i]
        
        -- Highlight selected option
        if i == selectedOption then
            love.graphics.setColor(0.9, 0.7, 0.2, self.menuAlpha)
            love.graphics.printf("> " .. option.text .. " <", 0, y, width, "center")
        else
            love.graphics.setColor(0.7, 0.7, 0.8, self.menuAlpha * 0.8)
            love.graphics.printf(option.text, 0, y, width, "center")
        end
    end
    
    -- Draw version info
    love.graphics.setFont(smallFont)
    love.graphics.setColor(0.6, 0.6, 0.7, 0.8)
    love.graphics.printf("Version 0.1 - Prototype", 0, height - 30, width, "center")
end

-- Draw animated background elements
function Menu:drawBackgroundElements(width, height)
    -- Draw chess-themed background elements
    love.graphics.setColor(0.15, 0.15, 0.25, 0.5)
    
    -- Draw grid of chess pieces silhouettes
    local gridSize = 100
    local pieceSize = 40
    
    for x = 0, width / gridSize do
        for y = 0, height / gridSize do
            local xPos = x * gridSize + math.sin(self.backgroundTimer + y * 0.2) * 10
            local yPos = y * gridSize + math.cos(self.backgroundTimer + x * 0.2) * 10
            
            -- Alternate piece types
            local pieceType = (x + y) % 6
            local pieceChar = ""
            
            if pieceType == 0 then pieceChar = "♚"
            elseif pieceType == 1 then pieceChar = "♛"
            elseif pieceType == 2 then pieceChar = "♜"
            elseif pieceType == 3 then pieceChar = "♝"
            elseif pieceType == 4 then pieceChar = "♞"
            else pieceChar = "♟"
            end
            
            love.graphics.setFont(titleFont)
            love.graphics.print(pieceChar, xPos, yPos)
        end
    end
end

-- Handle keypresses
function Menu:keypressed(key)
    if key == "up" or key == "w" then
        -- Play sound effect if available
        -- if self.game.assets.sounds.menuMove then
        --     love.audio.play(self.game.assets.sounds.menuMove)
        -- end
        
        selectedOption = selectedOption - 1
        if selectedOption < 1 then
            selectedOption = #options
        end
    elseif key == "down" or key == "s" then
        -- Play sound effect if available
        -- if self.game.assets.sounds.menuMove then
        --     love.audio.play(self.game.assets.sounds.menuMove)
        -- end
        
        selectedOption = selectedOption + 1
        if selectedOption > #options then
            selectedOption = 1
        end
    elseif key == "return" or key == "space" then
        -- Play sound effect if available
        -- if self.game.assets.sounds.menuSelect then
        --     love.audio.play(self.game.assets.sounds.menuSelect)
        -- end
        
        self:selectOption(options[selectedOption].action)
    elseif key == "escape" then
        -- Quit the game
        love.event.quit()
    end
end

-- Handle option selection
function Menu:selectOption(action)
    if action == "newGame" then
        -- Go to team management screen before starting a new game
        gamestate.switch(require("src.states.team_management"), self.game)
    elseif action == "continue" then
        -- Load saved game (not implemented yet)
        -- For now, just start a new game
        gamestate.switch(require("src.states.game"), self.game)
    elseif action == "options" then
        -- Show options menu (not implemented yet)
        -- For now, just show a message
        print("Options menu not implemented yet")
    elseif action == "credits" then
        -- Show credits (not implemented yet)
        -- For now, just show a message
        print("Credits not implemented yet")
    elseif action == "quit" then
        -- Quit the game
        love.event.quit()
    end
end

return Menu
