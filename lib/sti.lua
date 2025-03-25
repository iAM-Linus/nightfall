-- Simple Tiled Implementation for LÖVE2D
-- Custom implementation for Nightfall Chess

local sti = {
  _VERSION     = 'Custom STI 0.1',
  _DESCRIPTION = 'Custom Simple Tiled Implementation for Nightfall Chess',
  _URL         = 'https://github.com/karai17/Simple-Tiled-Implementation',
  _LICENSE     = 'MIT'
}

local Grid = {}
local Map = {}

-- Create a new map object
function sti.new(data)
  local map = setmetatable({}, { __index = Map })
  
  map.width = data.width or 8
  map.height = data.height or 8
  map.tilewidth = data.tilewidth or 64
  map.tileheight = data.tileheight or 64
  map.layers = data.layers or {}
  map.tiles = data.tiles or {}
  map.properties = data.properties or {}
  
  return map
end

-- Create a new empty map with specified dimensions
function sti.newMap(width, height, tilewidth, tileheight)
  local map = setmetatable({}, { __index = Map })
  
  map.width = width or 8
  map.height = height or 8
  map.tilewidth = tilewidth or 64
  map.tileheight = tileheight or 64
  map.layers = {}
  map.tiles = {}
  map.properties = {}
  
  return map
end

-- Add a new layer to the map
function Map:addLayer(name, type)
  local layer = {
    name = name,
    type = type or "tilelayer",
    visible = true,
    opacity = 1,
    properties = {},
    data = {}
  }
  
  if type == "tilelayer" then
    for y = 1, self.height do
      layer.data[y] = {}
      for x = 1, self.width do
        layer.data[y][x] = 0
      end
    end
  elseif type == "objectgroup" then
    layer.objects = {}
  end
  
  table.insert(self.layers, layer)
  return layer
end

-- Get a layer by name
function Map:getLayer(name)
  for i, layer in ipairs(self.layers) do
    if layer.name == name then
      return layer, i
    end
  end
  
  return nil
end

-- Set a tile at a specific position in a layer
function Map:setTile(layerName, x, y, tileId)
  local layer = self:getLayer(layerName)
  if layer and layer.type == "tilelayer" then
    if x >= 1 and x <= self.width and y >= 1 and y <= self.height then
      layer.data[y][x] = tileId
    end
  end
end

-- Get a tile at a specific position in a layer
function Map:getTile(layerName, x, y)
  local layer = self:getLayer(layerName)
  if layer and layer.type == "tilelayer" then
    if x >= 1 and x <= self.width and y >= 1 and y <= self.height then
      return layer.data[y][x]
    end
  end
  
  return 0
end

-- Add an object to an object layer
function Map:addObject(layerName, object)
  local layer = self:getLayer(layerName)
  if layer and layer.type == "objectgroup" then
    table.insert(layer.objects, object)
    return #layer.objects
  end
  
  return nil
end

-- Draw the map
function Map:draw()
  for _, layer in ipairs(self.layers) do
    if layer.visible and layer.opacity > 0 then
      if layer.type == "tilelayer" then
        self:drawTileLayer(layer)
      elseif layer.type == "objectgroup" then
        self:drawObjectLayer(layer)
      end
    end
  end
end

-- Draw a tile layer
function Map:drawTileLayer(layer)
  for y = 1, self.height do
    for x = 1, self.width do
      local tileId = layer.data[y][x]
      if tileId > 0 then
        local tile = self.tiles[tileId]
        if tile and tile.image then
          love.graphics.draw(
            tile.image,
            (x - 1) * self.tilewidth,
            (y - 1) * self.tileheight
          )
        end
      end
    end
  end
end

-- Draw an object layer
function Map:drawObjectLayer(layer)
  for _, object in ipairs(layer.objects) do
    if object.visible ~= false then
      if object.draw then
        object:draw()
      end
    end
  end
end

-- Update the map (for animations, etc.)
function Map:update(dt)
  for _, layer in ipairs(self.layers) do
    if layer.visible and layer.update then
      layer:update(dt)
    end
    
    if layer.type == "objectgroup" then
      for _, object in ipairs(layer.objects) do
        if object.update then
          object:update(dt)
        end
      end
    end
  end
end

return sti
