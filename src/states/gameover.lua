-- Game Over State for Nightfall Chess
-- Handles victory and defeat screens, stats, and returning to menu

local gamestate = require("lib.hump.gamestate")
local timer = require("lib.hump.timer")

local GameOver = {}

-- Game over state variables
local isVictory = false
local stats = {}
local uiElements = {}
local animationTimer = 0

-- Initialize the game over state
function GameOver:init()
    -- This function is called only once when the state is first created
end

-- Enter the game over state
function GameOver:enter(previous, game, victory, gameStats)
    self.game = game
    isVictory = victory or false
    stats = gameStats or self:createDefaultStats()
    
    -- Initialize UI elements
    self:initUI()
    
    -- Set up animations
    self.backgroundAlpha = 0
    self.titleAlpha = 0
    self.statsAlpha = 0
    self.promptAlpha = 0
    
    -- Sequence animations
    timer.after(0.5, function()
        timer.tween(1.0, self, {backgroundAlpha = 1}, 'out-quad')
    end)
    
    timer.after(1.0, function()
        timer.tween(1.0, self, {titleAlpha = 1}, 'out-quad')
    end)
    
    timer.after(2.0, function()
        timer.tween(1.0, self, {statsAlpha = 1}, 'out-quad')
    end)
    
    timer.after(3.0, function()
        timer.tween(1.0, self, {promptAlpha = 1}, 'out-quad')
    end)
    
    -- Play victory or defeat sound
    -- if isVictory and game.assets.sounds.victory then
    --     love.audio.play(game.assets.sounds.victory)
    -- elseif game.assets.sounds.defeat then
    --     love.audio.play(game.assets.sounds.defeat)
    -- end
end

-- Leave the game over state
function GameOver:leave()
    -- Clean up resources
end

-- Update game over logic
function GameOver:update(dt)
    -- Update timers
    timer.update(dt)
    
    -- Update animation timer
    animationTimer = animationTimer + dt
    
    -- Update UI animations
    for _, element in pairs(uiElements) do
        if element.update then
            element:update(dt)
        end
    end
end

-- Draw the game over screen
function GameOver:draw()
    local width, height = love.graphics.getDimensions()
    
    -- Draw background
    if isVictory then
        -- Victory background (dark blue with light rays)
        love.graphics.setColor(0.1, 0.1, 0.3, self.backgroundAlpha)
        love.graphics.rectangle("fill", 0, 0, width, height)
        
        -- Draw light rays
        self:drawLightRays(width, height)
    else
        -- Defeat background (dark red with smoke)
        love.graphics.setColor(0.3, 0.1, 0.1, self.backgroundAlpha)
        love.graphics.rectangle("fill", 0, 0, width, height)
        
        -- Draw smoke effect
        self:drawSmoke(width, height)
    end
    
    -- Draw title
    love.graphics.setFont(self.game.assets.fonts.title)
    
    if isVictory then
        love.graphics.setColor(0.9, 0.9, 0.2, self.titleAlpha)
        love.graphics.printf("VICTORY", 0, height * 0.2, width, "center")
    else
        love.graphics.setColor(0.9, 0.2, 0.2, self.titleAlpha)
        love.graphics.printf("DEFEAT", 0, height * 0.2, width, "center")
    end
    
    -- Draw stats panel
    self:drawStatsPanel(width, height)
    
    -- Draw continue prompt
    love.graphics.setFont(self.game.assets.fonts.medium)
    love.graphics.setColor(1, 1, 1, self.promptAlpha * (0.7 + math.sin(animationTimer * 3) * 0.3))
    love.graphics.printf("Press SPACE to continue", 0, height * 0.8, width, "center")
end

-- Draw light rays effect for victory
function GameOver:drawLightRays(width, height)
    local centerX = width / 2
    local centerY = height * 0.4
    local rayCount = 12
    local maxRadius = math.max(width, height) * 1.5
    
    for i = 1, rayCount do
        local angle = (i / rayCount) * math.pi * 2 + animationTimer * 0.2
        local rayWidth = 30 + math.sin(animationTimer + i) * 10
        
        love.graphics.setColor(0.9, 0.9, 0.2, 0.1 * self.backgroundAlpha)
        
        -- Draw ray as a triangle
        love.graphics.polygon(
            "fill",
            centerX, centerY,
            centerX + math.cos(angle - rayWidth/1000) * maxRadius,
            centerY + math.sin(angle - rayWidth/1000) * maxRadius,
            centerX + math.cos(angle + rayWidth/1000) * maxRadius,
            centerY + math.sin(angle + rayWidth/1000) * maxRadius
        )
    end
end

-- Draw smoke effect for defeat
function GameOver:drawSmoke(width, height)
    local smokeCount = 20
    
    for i = 1, smokeCount do
        local x = (i / smokeCount) * width
        local y = height - (animationTimer * 50 + i * 20) % (height * 1.5)
        local size = 50 + math.sin(animationTimer + i) * 20
        
        love.graphics.setColor(0.3, 0.1, 0.1, 0.2 * self.backgroundAlpha)
        love.graphics.circle("fill", x, y, size)
    end
end

-- Draw stats panel
function GameOver:drawStatsPanel(width, height)
    -- Draw panel background
    love.graphics.setColor(0.2, 0.2, 0.3, self.statsAlpha * 0.8)
    love.graphics.rectangle("fill", width/2 - 200, height * 0.35, 400, 250, 10, 10)
    
    love.graphics.setColor(0.5, 0.5, 0.7, self.statsAlpha)
    love.graphics.rectangle("line", width/2 - 200, height * 0.35, 400, 250, 10, 10)
    
    -- Draw stats title
    love.graphics.setFont(self.game.assets.fonts.medium)
    love.graphics.setColor(0.9, 0.9, 1, self.statsAlpha)
    love.graphics.printf("Battle Statistics", width/2 - 190, height * 0.36, 380, "center")
    
    -- Draw stats
    love.graphics.setFont(self.game.assets.fonts.small)
    
    local y = height * 0.42
    local leftX = width/2 - 180
    local rightX = width/2 + 20
    
    -- Draw each stat
    for _, stat in ipairs(stats) do
        love.graphics.setColor(0.8, 0.8, 0.9, self.statsAlpha)
        love.graphics.print(stat.name .. ":", leftX, y)
        
        love.graphics.setColor(1, 1, 1, self.statsAlpha)
        love.graphics.print(stat.value, rightX, y)
        
        y = y + 25
    end
    
    -- Draw result message
    love.graphics.setFont(self.game.assets.fonts.medium)
    
    if isVictory then
        love.graphics.setColor(0.2, 0.9, 0.2, self.statsAlpha)
        love.graphics.printf("You have conquered the darkness!", width/2 - 190, height * 0.55, 380, "center")
    else
        love.graphics.setColor(0.9, 0.2, 0.2, self.statsAlpha)
        love.graphics.printf("The darkness has consumed you...", width/2 - 190, height * 0.55, 380, "center")
    end
end

-- Initialize UI elements
function GameOver:initUI()
    -- Create UI elements here
    uiElements = {
        -- Add UI elements as needed
    }
end

-- Create default stats
function GameOver:createDefaultStats()
    return {
        {name = "Turns Played", value = "12"},
        {name = "Units Defeated", value = "8"},
        {name = "Units Lost", value = "2"},
        {name = "Damage Dealt", value = "87"},
        {name = "Damage Taken", value = "45"},
        {name = "Items Used", value = "3"},
        {name = "Critical Hits", value = "2"},
        {name = "Time Played", value = "10:23"}
    }
end

-- Handle keypresses
function GameOver:keypressed(key)
    -- Only respond to input after animations are complete
    if self.promptAlpha < 0.5 then
        return
    end
    
    if key == "space" or key == "return" or key == "escape" then
        -- Return to menu
        gamestate.switch(require("src.states.menu"), self.game)
    end
end

-- Handle mouse presses
function GameOver:mousepressed(x, y, button)
    -- Only respond to input after animations are complete
    if self.promptAlpha < 0.5 then
        return
    end
    
    if button == 1 then -- Left click
        -- Return to menu
        gamestate.switch(require("src.states.menu"), self.game)
    end
end

return GameOver
