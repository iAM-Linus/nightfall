-- Asset Manager System for Nightfall Chess
-- Handles loading, caching, and accessing game assets

local class = require("lib.middleclass.middleclass")

local AssetManager = class("AssetManager")

function AssetManager:initialize()
    -- Asset storage
    self.images = {}
    self.fonts = {}
    self.sounds = {}
    self.music = {}
    self.shaders = {}
    
    -- Asset paths
    self.paths = {
        images = "assets/images/",
        fonts = "assets/fonts/",
        sounds = "assets/sounds/",
        music = "assets/music/",
        shaders = "assets/shaders/"
    }
    
    -- Default assets
    self.defaultImage = nil
    self.defaultFont = nil
    self.defaultSound = nil
end

-- Load an image
function AssetManager:loadImage(name, path, options)
    options = options or {}
    path = path or (self.paths.images .. name .. ".png")
    
    if self.images[name] then
        return self.images[name]
    end
    
    local image
    local success, result = pcall(function()
        image = love.graphics.newImage(path)
        
        -- Apply options
        if options.filter then
            image:setFilter(options.filter, options.filter)
        end
        
        if options.wrap then
            image:setWrap(options.wrap, options.wrap)
        end
        
        return image
    end)
    
    if success then
        self.images[name] = image
        return image
    else
        print("Failed to load image: " .. name .. " (" .. path .. ")")
        print(result)
        return self.defaultImage
    end
end

-- Load a font
function AssetManager:loadFont(name, size, path)
    size = size or 12
    path = path or (self.paths.fonts .. name .. ".ttf")
    
    local key = name .. "_" .. size
    
    if self.fonts[key] then
        return self.fonts[key]
    end
    
    local font
    local success, result = pcall(function()
        font = love.graphics.newFont(path, size)
        return font
    end)
    
    if success then
        self.fonts[key] = font
        return font
    else
        print("Failed to load font: " .. name .. " (" .. path .. ")")
        print(result)
        return self.defaultFont or love.graphics.getFont()
    end
end

-- Load a sound
function AssetManager:loadSound(name, path)
    path = path or (self.paths.sounds .. name .. ".wav")
    
    if self.sounds[name] then
        return self.sounds[name]
    end
    
    local sound
    local success, result = pcall(function()
        sound = love.audio.newSource(path, "static")
        return sound
    end)
    
    if success then
        self.sounds[name] = sound
        return sound
    else
        print("Failed to load sound: " .. name .. " (" .. path .. ")")
        print(result)
        return self.defaultSound
    end
end

-- Load music
function AssetManager:loadMusic(name, path)
    path = path or (self.paths.music .. name .. ".ogg")
    
    if self.music[name] then
        return self.music[name]
    end
    
    local music
    local success, result = pcall(function()
        music = love.audio.newSource(path, "stream")
        music:setLooping(true)
        return music
    end)
    
    if success then
        self.music[name] = music
        return music
    else
        print("Failed to load music: " .. name .. " (" .. path .. ")")
        print(result)
        return nil
    end
end

-- Load a shader
function AssetManager:loadShader(name, path)
    path = path or (self.paths.shaders .. name .. ".glsl")
    
    if self.shaders[name] then
        return self.shaders[name]
    end
    
    local shader
    local success, result = pcall(function()
        shader = love.graphics.newShader(path)
        return shader
    end)
    
    if success then
        self.shaders[name] = shader
        return shader
    else
        print("Failed to load shader: " .. name .. " (" .. path .. ")")
        print(result)
        return nil
    end
end

-- Get an image
function AssetManager:getImage(name)
    return self.images[name] or self.defaultImage
end

-- Get a font
function AssetManager:getFont(name, size)
    size = size or 12
    local key = name .. "_" .. size
    return self.fonts[key] or self.defaultFont or love.graphics.getFont()
end

-- Get a sound
function AssetManager:getSound(name)
    return self.sounds[name] or self.defaultSound
end

-- Get music
function AssetManager:getMusic(name)
    return self.music[name]
end

-- Get a shader
function AssetManager:getShader(name)
    return self.shaders[name]
end

-- Play a sound
function AssetManager:playSound(name, volume, pitch)
    local sound = self:getSound(name)
    
    if sound then
        -- Clone the source to allow overlapping sounds
        local clone = sound:clone()
        
        if volume then
            clone:setVolume(volume)
        end
        
        if pitch then
            clone:setPitch(pitch)
        end
        
        clone:play()
        return clone
    end
    
    return nil
end

-- Play music
function AssetManager:playMusic(name, volume)
    -- Stop current music
    self:stopMusic()
    
    local music = self:getMusic(name)
    
    if music then
        if volume then
            music:setVolume(volume)
        end
        
        music:play()
        return music
    end
    
    return nil
end

-- Stop all music
function AssetManager:stopMusic()
    for _, music in pairs(self.music) do
        if music:isPlaying() then
            music:stop()
        end
    end
end

-- Create placeholder assets for development
function AssetManager:createPlaceholders(tileSize)
    tileSize = tileSize or 64
    
    -- Create placeholder unit images
    local unitTypes = {"pawn", "knight", "bishop", "rook", "queen", "king"}
    local unitColors = {"white", "black"}
    
    for _, color in ipairs(unitColors) do
        for _, unitType in ipairs(unitTypes) do
            local canvas = love.graphics.newCanvas(tileSize, tileSize)
            love.graphics.setCanvas(canvas)
            
            -- Background
            love.graphics.setColor(0.2, 0.2, 0.3, 1)
            love.graphics.rectangle("fill", 0, 0, tileSize, tileSize)
            
            -- Border
            love.graphics.setColor(color == "white" and 0.9 or 0.1, 0.9, 0.9, 1)
            love.graphics.rectangle("line", 2, 2, tileSize-4, tileSize-4)
            
            -- Unit type text
            love.graphics.setColor(color == "white" and 0.9 or 0.1, 0.9, 0.9, 1)
            love.graphics.printf(unitType:sub(1, 1):upper(), 0, tileSize/2-10, tileSize, "center")
            
            love.graphics.setCanvas()
            
            -- Store the image
            self.images[color .. "_" .. unitType] = canvas
        end
    end
    
    -- Create placeholder tile images
    local tileTypes = {"floor", "wall", "water", "lava", "grass"}
    
    for _, tileType in ipairs(tileTypes) do
        local canvas = love.graphics.newCanvas(tileSize, tileSize)
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
        love.graphics.rectangle("fill", 0, 0, tileSize, tileSize)
        
        -- Border
        love.graphics.setColor(0.8, 0.8, 0.8, 0.5)
        love.graphics.rectangle("line", 0, 0, tileSize, tileSize)
        
        love.graphics.setCanvas()
        
        -- Store the image
        self.images["tile_" .. tileType] = canvas
    end
    
    -- Create UI elements
    local uiElements = {"button", "panel", "highlight", "selected"}
    
    for _, element in ipairs(uiElements) do
        local canvas = love.graphics.newCanvas(tileSize, tileSize)
        love.graphics.setCanvas(canvas)
        
        if element == "button" then
            love.graphics.setColor(0.3, 0.3, 0.6, 1)
            love.graphics.rectangle("fill", 0, 0, tileSize, tileSize, 8, 8)
            love.graphics.setColor(0.8, 0.8, 0.9, 1)
            love.graphics.rectangle("line", 2, 2, tileSize-4, tileSize-4, 6, 6)
        elseif element == "panel" then
            love.graphics.setColor(0.2, 0.2, 0.3, 0.9)
            love.graphics.rectangle("fill", 0, 0, tileSize, tileSize, 4, 4)
            love.graphics.setColor(0.5, 0.5, 0.6, 1)
            love.graphics.rectangle("line", 1, 1, tileSize-2, tileSize-2, 3, 3)
        elseif element == "highlight" then
            love.graphics.setColor(0.9, 0.9, 0.2, 0.5)
            love.graphics.rectangle("fill", 0, 0, tileSize, tileSize)
        elseif element == "selected" then
            love.graphics.setColor(0.2, 0.9, 0.2, 0.7)
            love.graphics.rectangle("line", 2, 2, tileSize-4, tileSize-4, 2, 2)
            love.graphics.rectangle("line", 4, 4, tileSize-8, tileSize-8, 2, 2)
        end
        
        love.graphics.setCanvas()
        
        -- Store the image
        self.images["ui_" .. element] = canvas
    end
    
    -- Reset canvas
    love.graphics.setCanvas()
    
    -- Set default image
    self.defaultImage = self.images["ui_panel"]
    
    -- Create default font
    self.defaultFont = love.graphics.getFont()
    
    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

return AssetManager
