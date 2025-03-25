-- LovelyToasts - Simple notification system for LÖVE2D
-- Custom implementation for Nightfall Chess

local lovelytoasts = {
  _VERSION     = 'LovelyToasts 0.1',
  _DESCRIPTION = 'Simple notification system for LÖVE2D',
  _LICENSE     = 'MIT'
}

local toasts = {}
local defaultDuration = 3 -- seconds
local defaultFadeTime = 0.5 -- seconds
local padding = 10
local margin = 10
local maxWidth = 300
local font = nil

-- Initialize the toast system
function lovelytoasts.init(options)
  options = options or {}
  defaultDuration = options.duration or defaultDuration
  defaultFadeTime = options.fadeTime or defaultFadeTime
  padding = options.padding or padding
  margin = options.margin or margin
  maxWidth = options.maxWidth or maxWidth
  font = options.font or love.graphics.getFont()
end

-- Create a new toast notification
function lovelytoasts.show(message, options)
  options = options or {}
  
  local toast = {
    message = message,
    duration = options.duration or defaultDuration,
    fadeTime = options.fadeTime or defaultFadeTime,
    color = options.color or {1, 1, 1, 1},
    backgroundColor = options.backgroundColor or {0.2, 0.2, 0.2, 0.8},
    position = options.position or "bottom", -- "top", "bottom", "center"
    x = 0,
    y = 0,
    width = 0,
    height = 0,
    alpha = 0,
    timer = 0,
    state = "fadein" -- "fadein", "visible", "fadeout", "done"
  }
  
  -- Calculate text dimensions
  local textWidth = font:getWidth(message)
  local textHeight = font:getHeight()
  local wrappedText = message
  
  if textWidth > maxWidth then
    wrappedText = love.graphics.newText(font)
    wrappedText:setf(message, maxWidth, "left")
    textWidth = math.min(textWidth, maxWidth)
    textHeight = wrappedText:getHeight()
  end
  
  toast.wrappedText = wrappedText
  toast.width = textWidth + padding * 2
  toast.height = textHeight + padding * 2
  
  -- Set initial position
  toast.x = (love.graphics.getWidth() - toast.width) / 2
  
  if toast.position == "top" then
    toast.y = margin
  elseif toast.position == "center" then
    toast.y = (love.graphics.getHeight() - toast.height) / 2
  else -- "bottom"
    toast.y = love.graphics.getHeight() - toast.height - margin
  end
  
  -- Adjust position based on existing toasts
  for _, existingToast in ipairs(toasts) do
    if existingToast.position == toast.position and existingToast.state ~= "done" then
      if toast.position == "top" then
        toast.y = existingToast.y + existingToast.height + margin
      elseif toast.position == "bottom" then
        toast.y = existingToast.y - toast.height - margin
      end
    end
  end
  
  table.insert(toasts, toast)
  return toast
end

-- Update all toast notifications
function lovelytoasts.update(dt)
  for i = #toasts, 1, -1 do
    local toast = toasts[i]
    
    if toast.state == "fadein" then
      toast.timer = toast.timer + dt
      toast.alpha = math.min(1, toast.timer / toast.fadeTime)
      
      if toast.timer >= toast.fadeTime then
        toast.timer = 0
        toast.state = "visible"
      end
    elseif toast.state == "visible" then
      toast.timer = toast.timer + dt
      
      if toast.timer >= toast.duration then
        toast.timer = 0
        toast.state = "fadeout"
      end
    elseif toast.state == "fadeout" then
      toast.timer = toast.timer + dt
      toast.alpha = math.max(0, 1 - (toast.timer / toast.fadeTime))
      
      if toast.timer >= toast.fadeTime then
        toast.state = "done"
      end
    elseif toast.state == "done" then
      table.remove(toasts, i)
    end
  end
end

-- Draw all toast notifications
function lovelytoasts.draw()
  local originalColor = {love.graphics.getColor()}
  
  for _, toast in ipairs(toasts) do
    if toast.state ~= "done" then
      -- Draw background
      love.graphics.setColor(
        toast.backgroundColor[1],
        toast.backgroundColor[2],
        toast.backgroundColor[3],
        toast.backgroundColor[4] * toast.alpha
      )
      love.graphics.rectangle("fill", toast.x, toast.y, toast.width, toast.height, 5, 5)
      
      -- Draw text
      love.graphics.setColor(
        toast.color[1],
        toast.color[2],
        toast.color[3],
        toast.color[4] * toast.alpha
      )
      
      if type(toast.wrappedText) == "string" then
        love.graphics.print(toast.wrappedText, toast.x + padding, toast.y + padding)
      else
        love.graphics.draw(toast.wrappedText, toast.x + padding, toast.y + padding)
      end
    end
  end
  
  -- Restore original color
  love.graphics.setColor(originalColor)
end

-- Clear all toast notifications
function lovelytoasts.clear()
  toasts = {}
end

return lovelytoasts
