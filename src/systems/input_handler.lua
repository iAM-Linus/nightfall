-- Input Handler System for Nightfall Chess
-- Manages keyboard, mouse, and touch input

local class = require("lib.middleclass.middleclass")

local InputHandler = class("InputHandler")

function InputHandler:initialize(game)
    self.game = game
    
    -- Track key states
    self.keys = {}
    self.keysPressed = {}
    self.keysReleased = {}
    
    -- Track mouse state
    self.mouse = {
        x = 0,
        y = 0,
        dx = 0,
        dy = 0,
        buttons = {},
        buttonsPressed = {},
        buttonsReleased = {}
    }
    
    -- Track touch state (for mobile)
    self.touches = {}
    self.touchesPressed = {}
    self.touchesReleased = {}
    
    -- Input bindings
    self.bindings = {
        -- Movement
        moveUp = {"w", "up"},
        moveDown = {"s", "down"},
        moveLeft = {"a", "left"},
        moveRight = {"d", "right"},
        
        -- Actions
        confirm = {"return", "space"},
        cancel = {"escape", "backspace"},
        
        -- Game controls
        pause = {"escape", "p"},
        inventory = {"i", "tab"},
        nextUnit = {"tab", "n"},
        endTurn = {"e", "space"},
        
        -- Debug
        debug = {"f1"},
        reload = {"f5"}
    }
    
    -- Callback functions
    self.callbacks = {}
end

-- Update input state
function InputHandler:update(dt)
    -- Update mouse delta
    local mx, my = love.mouse.getPosition()
    self.mouse.dx = mx - self.mouse.x
    self.mouse.dy = my - self.mouse.y
    self.mouse.x = mx
    self.mouse.y = my
    
    -- *** ADD LOG before clearing ***
    local pressedKeys = {}
    for k, v in pairs(self.keysPressed) do if v then table.insert(pressedKeys, k) end end
    if #pressedKeys > 0 then print("[InputHandler] Clearing keysPressed:", table.concat(pressedKeys, ", ")) end
    local pressedBtns = {}
    for k, v in pairs(self.mouse.buttonsPressed) do if v then table.insert(pressedBtns, k) end end
    if #pressedBtns > 0 then print("[InputHandler] Clearing buttonsPressed:", table.concat(pressedBtns, ", ")) end
    -- *** END LOG ***

    -- *** REMOVE CLEARING LOGIC FROM HERE ***
    -- self.keysPressed = {}
    -- self.keysReleased = {}
    -- self.mouse.buttonsPressed = {}
    -- self.mouse.buttonsReleased = {}
    -- self.touchesPressed = {}
    -- self.touchesReleased = {}
end

-- *** ADD: New method to clear pressed states ***
function InputHandler:clearPressedState()
    -- Optional: Log when clearing
    -- local pressedKeys = {}
    -- for k, v in pairs(self.keysPressed) do if v then table.insert(pressedKeys, k) end end
    -- if #pressedKeys > 0 then print("[InputHandler] Clearing keysPressed:", table.concat(pressedKeys, ", ")) end
    -- local pressedBtns = {}
    -- for k, v in pairs(self.mouse.buttonsPressed) do if v then table.insert(pressedBtns, k) end end
    -- if #pressedBtns > 0 then print("[InputHandler] Clearing buttonsPressed:", table.concat(pressedBtns, ", ")) end

    self.keysPressed = {}
    self.mouse.buttonsPressed = {}
    self.touchesPressed = {}
    -- Keep released flags for one frame? Or clear them too? Let's clear them for simplicity.
    self.keysReleased = {}
    self.mouse.buttonsReleased = {}
    self.touchesReleased = {}
end

-- Check if a key is currently down
function InputHandler:isDown(key)
    return self.keys[key] == true
end

-- Check if a key was pressed this frame
function InputHandler:wasPressed(key)
    return self.keysPressed[key] == true
end

-- Check if a key was released this frame
function InputHandler:wasReleased(key)
    return self.keysReleased[key] == true
end

-- Check if a mouse button is currently down
function InputHandler:isMouseDown(button)
    return self.mouse.buttons[button] == true
end

-- Check if a mouse button was pressed this frame
function InputHandler:wasMousePressed(button)
    return self.mouse.buttonsPressed[button] == true
end

-- Check if a mouse button was released this frame
function InputHandler:wasMouseReleased(button)
    return self.mouse.buttonsReleased[button] == true
end

-- Check if a binding is currently active
function InputHandler:isBindingDown(bindingName)
    local keys = self.bindings[bindingName]
    if not keys then
        return false
    end
    
    for _, key in ipairs(keys) do
        if self:isDown(key) then
            return true
        end
    end
    
    return false
end

-- Check if a binding was activated this frame
function InputHandler:wasBindingPressed(bindingName)
    local keys = self.bindings[bindingName]
    if not keys then
        return false
    end
    
    for _, key in ipairs(keys) do
        if self:wasPressed(key) then
            return true
        end
    end
    
    return false
end

-- Check if a binding was deactivated this frame
function InputHandler:wasBindingReleased(bindingName)
    local keys = self.bindings[bindingName]
    if not keys then
        return false
    end
    
    for _, key in ipairs(keys) do
        if self:wasReleased(key) then
            return true
        end
    end
    
    return false
end

-- Register a callback for a specific input event
function InputHandler:registerCallback(event, callback)
    if not self.callbacks[event] then
        self.callbacks[event] = {}
    end
    
    table.insert(self.callbacks[event], callback)
end

-- Remove a callback
function InputHandler:removeCallback(event, callback)
    if not self.callbacks[event] then
        return
    end
    
    for i, cb in ipairs(self.callbacks[event]) do
        if cb == callback then
            table.remove(self.callbacks[event], i)
            return
        end
    end
end

-- Trigger callbacks for an event
function InputHandler:triggerCallbacks(event, ...)
    if not self.callbacks[event] then
        return
    end
    
    for _, callback in ipairs(self.callbacks[event]) do
        callback(...)
    end
end

-- LÖVE2D input callbacks

-- Key pressed callback
function InputHandler:keypressed(key, scancode, isrepeat)
    print("[InputHandler] keypressed:", key) -- *** ADD LOG ***
    self.keys[key] = true
    self.keysPressed[key] = true
    print("  -> keysPressed["..key.."] set to", self.keysPressed[key]) -- *** ADD LOG ***

    self:triggerCallbacks("keypressed", key, scancode, isrepeat)
end

-- Key released callback
function InputHandler:keyreleased(key, scancode)
    -- print("[InputHandler] keyreleased:", key) -- Optional log
    self.keys[key] = false
    self.keysReleased[key] = true

    self:triggerCallbacks("keyreleased", key, scancode)
end

-- Mouse pressed callback
function InputHandler:mousepressed(x, y, button, istouch, presses)
    print("[InputHandler] mousepressed:", button, "at", x, y) -- *** ADD LOG ***
    self.mouse.buttons[button] = true
    self.mouse.buttonsPressed[button] = true
    print("  -> buttonsPressed["..button.."] set to", self.mouse.buttonsPressed[button]) -- *** ADD LOG ***

    self:triggerCallbacks("mousepressed", x, y, button, istouch, presses)
end

-- Mouse released callback
function InputHandler:mousereleased(x, y, button, istouch, presses)
    -- print("[InputHandler] mousereleased:", button, "at", x, y) -- Optional log
    self.mouse.buttons[button] = false
    self.mouse.buttonsReleased[button] = true

    self:triggerCallbacks("mousereleased", x, y, button, istouch, presses)
end

-- Mouse moved callback
function InputHandler:mousemoved(x, y, dx, dy, istouch)
    self.mouse.x = x
    self.mouse.y = y
    self.mouse.dx = dx
    self.mouse.dy = dy
    
    self:triggerCallbacks("mousemoved", x, y, dx, dy, istouch)
end

-- Mouse wheel callback
function InputHandler:wheelmoved(x, y)
    self:triggerCallbacks("wheelmoved", x, y)
end

-- Touch pressed callback
function InputHandler:touchpressed(id, x, y, dx, dy, pressure)
    self.touches[id] = {x = x, y = y, pressure = pressure}
    self.touchesPressed[id] = {x = x, y = y, pressure = pressure}
    
    self:triggerCallbacks("touchpressed", id, x, y, dx, dy, pressure)
end

-- Touch released callback
function InputHandler:touchreleased(id, x, y, dx, dy, pressure)
    self.touchesReleased[id] = {x = x, y = y, pressure = pressure}
    self.touches[id] = nil
    
    self:triggerCallbacks("touchreleased", id, x, y, dx, dy, pressure)
end

-- Touch moved callback
function InputHandler:touchmoved(id, x, y, dx, dy, pressure)
    if self.touches[id] then
        self.touches[id].x = x
        self.touches[id].y = y
        self.touches[id].pressure = pressure
    end
    
    self:triggerCallbacks("touchmoved", id, x, y, dx, dy, pressure)
end

-- Register all LÖVE2D callbacks
function InputHandler:registerLoveCallbacks()
    -- Store original callbacks
    local originalCallbacks = {
        keypressed = love.keypressed,
        keyreleased = love.keyreleased,
        mousepressed = love.mousepressed,
        mousereleased = love.mousereleased,
        mousemoved = love.mousemoved,
        wheelmoved = love.wheelmoved,
        touchpressed = love.touchpressed,
        touchreleased = love.touchreleased,
        touchmoved = love.touchmoved
    }
    
    -- Override with our callbacks
    love.keypressed = function(key, scancode, isrepeat)
        self:keypressed(key, scancode, isrepeat)
        if originalCallbacks.keypressed then
            originalCallbacks.keypressed(key, scancode, isrepeat)
        end
    end
    
    love.keyreleased = function(key, scancode)
        self:keyreleased(key, scancode)
        if originalCallbacks.keyreleased then
            originalCallbacks.keyreleased(key, scancode)
        end
    end
    
    love.mousepressed = function(x, y, button, istouch, presses)
        self:mousepressed(x, y, button, istouch, presses)
        if originalCallbacks.mousepressed then
            originalCallbacks.mousepressed(x, y, button, istouch, presses)
        end
    end
    
    love.mousereleased = function(x, y, button, istouch, presses)
        self:mousereleased(x, y, button, istouch, presses)
        if originalCallbacks.mousereleased then
            originalCallbacks.mousereleased(x, y, button, istouch, presses)
        end
    end
    
    love.mousemoved = function(x, y, dx, dy, istouch)
        self:mousemoved(x, y, dx, dy, istouch)
        if originalCallbacks.mousemoved then
            originalCallbacks.mousemoved(x, y, dx, dy, istouch)
        end
    end
    
    love.wheelmoved = function(x, y)
        self:wheelmoved(x, y)
        if originalCallbacks.wheelmoved then
            originalCallbacks.wheelmoved(x, y)
        end
    end
    
    love.touchpressed = function(id, x, y, dx, dy, pressure)
        self:touchpressed(id, x, y, dx, dy, pressure)
        if originalCallbacks.touchpressed then
            originalCallbacks.touchpressed(id, x, y, dx, dy, pressure)
        end
    end
    
    love.touchreleased = function(id, x, y, dx, dy, pressure)
        self:touchreleased(id, x, y, dx, dy, pressure)
        if originalCallbacks.touchreleased then
            originalCallbacks.touchreleased(id, x, y, dx, dy, pressure)
        end
    end
    
    love.touchmoved = function(id, x, y, dx, dy, pressure)
        self:touchmoved(id, x, y, dx, dy, pressure)
        if originalCallbacks.touchmoved then
            originalCallbacks.touchmoved(id, x, y, dx, dy, pressure)
        end
    end
end

return InputHandler
