-- UI Manager for Nightfall Chess
-- Manages and coordinates all UI components

local class = require("lib.middleclass.middleclass")
local HUD = require("src.ui.hud")
local Dialog = require("src.ui.dialog")
local Tooltip = require("src.ui.tooltip")
local Menu = require("src.ui.menu")

local UIManager = class("UIManager")

function UIManager:initialize(game)
    self.game = game
    
    -- Initialize UI components
    self.hud = HUD:new(game)
    self.dialog = Dialog:new(game)
    self.tooltip = Tooltip:new(game)
    self.menu = Menu:new(game)
    
    -- Create main menu
    self.mainMenu = Menu:new(game):createMainMenu()
    
    -- Create pause menu
    self.pauseMenu = Menu:new(game):createPauseMenu()
    
    -- UI state
    self.paused = false
    self.showHUD = true
end

-- Update UI
function UIManager:update(dt)
    -- Update HUD if visible and not paused
    if self.showHUD and not self.paused then
        self.hud:update(dt)
    end
    
    -- Update dialog
    self.dialog:update(dt)
    
    -- Update tooltip
    self.tooltip:update(dt)
    
    -- Update menus
    if self.paused then
        self.pauseMenu:update(dt)
    end
    
    -- Update main menu if active
    self.mainMenu:update(dt)
end

-- Draw UI
function UIManager:draw()
    -- Draw HUD if visible and not paused
    if self.showHUD and not self.paused then
        self.hud:draw()
    end
    
    -- Draw dialog
    self.dialog:draw()
    
    -- Draw tooltip
    self.tooltip:draw()
    
    -- Draw menus
    if self.paused then
        self.pauseMenu:draw()
    end
    
    -- Draw main menu if active
    self.mainMenu:draw()
end

-- Show main menu
function UIManager:showMainMenu()
    self.mainMenu:show("Nightfall Chess")
    return self
end

-- Hide main menu
function UIManager:hideMainMenu()
    self.mainMenu:hide()
    return self
end

-- Toggle pause menu
function UIManager:togglePause()
    self.paused = not self.paused
    
    if self.paused then
        self.pauseMenu:show("Paused")
    else
        self.pauseMenu:hide()
    end
    
    return self
end

-- Show dialog
function UIManager:showDialog(params)
    self.dialog:show(params)
    return self
end

-- Show tooltip
function UIManager:showTooltip(text, title, x, y)
    self.tooltip:show(text, title, x, y)
    return self
end

-- Hide tooltip
function UIManager:hideTooltip()
    self.tooltip:hide()
    return self
end

-- Set hover element for tooltip
function UIManager:setTooltipHover(element)
    self.tooltip:setHoverElement(element)
    return self
end

-- Show notification
function UIManager:showNotification(text, duration)
    self.hud:showNotification(text, duration)
    return self
end

-- Set player turn
function UIManager:setPlayerTurn(isPlayerTurn)
    self.hud:setPlayerTurn(isPlayerTurn)
    return self
end

-- Set action points
function UIManager:setActionPoints(current, max)
    self.hud:setActionPoints(current, max)
    return self
end

-- Set selected unit (MODIFIED)
function UIManager:setSelectedUnit(unit)
    -- *** FIX: Call setUnit on the specific HUD element ***
    if self.hud and self.hud.elements and self.hud.elements.unitInfo and self.hud.elements.unitInfo.setUnit then
        self.hud.elements.unitInfo:setUnit(unit)
    else
        print("WARNING: Could not set selected unit info in HUD.")
    end
    return self
end

-- Set target unit (MODIFIED)
function UIManager:setTargetUnit(unit)
    -- *** FIX: Call setUnit on the specific HUD element ***
    if self.hud and self.hud.elements and self.hud.elements.enemyInfo and self.hud.elements.enemyInfo.setUnit then
        self.hud.elements.enemyInfo:setUnit(unit)
    else
         print("WARNING: Could not set target unit info in HUD.")
    end
    return self
end

-- Set help text
function UIManager:setHelpText(text)
    self.hud:setHelpText(text)
    return self
end

-- Set grid for minimap
function UIManager:setGrid(grid)
    self.hud:setGrid(grid)
    return self
end

-- Set current level
function UIManager:setLevel(level)
    self.hud:setLevel(level)
    return self
end

-- Show HUD
function UIManager:showHUD()
    self.showHUD = true
    self.hud:show()
    return self
end

-- Hide HUD
function UIManager:hideHUD()
    self.showHUD = false
    self.hud:hide()
    return self
end

-- *** ADD Show/Hide methods for Ability Panel ***
function UIManager:showAbilityPanel()
    print("UIManager:showAbilityPanel called") -- Log
    if self.hud then self.hud:showAbilityPanel() end
    return self
end

function UIManager:hideAbilityPanel()
    print("UIManager:hideAbilityPanel called") -- Log
    if self.hud then self.hud:hideAbilityPanel() end
    return self
end
-- *** END ADDITION ***

-- Handle keypresses
function UIManager:keypressed(key)
    -- Check if dialog handles the keypress
    if self.dialog.active and self.dialog:keypressed(key) then
        return true
    end
    
    -- Check if pause menu handles the keypress
    if self.paused and self.pauseMenu:keypressed(key) then
        return true
    end
    
    -- Check if main menu handles the keypress
    if self.mainMenu.active and self.mainMenu:keypressed(key) then
        return true
    end
    
    -- Toggle pause menu with escape key
    if key == "escape" and not self.mainMenu.active then
        self:togglePause()
        return true
    end
    
    return false
end

-- Handle mouse presses (MODIFIED: Return info from HUD)
function UIManager:mousepressed(x, y, button)
    -- Check dialogs/menus first (they should consume clicks fully)
    if self.dialog.active and self.dialog:mousepressed(x, y, button) then return true end
    if self.paused and self.pauseMenu:mousepressed(x, y, button) then return true end
    if self.mainMenu.active and self.mainMenu:mousepressed(x, y, button) then return true end

    -- Check HUD and return its result
    if self.hud and self.hud.mousepressed then
        local hudResult = self.hud:mousepressed(x, y, button)
        -- Return the detailed result table or nil
        return hudResult
    end

    return nil -- No UI element handled the click
end

-- Handle mouse releases
function UIManager:mousereleased(x, y, button)
    -- Check if dialog handles the mouserelease
    if self.dialog.active and self.dialog:mousereleased() and self.dialog:mousereleased(x, y, button) then
        return true
    end
    
    -- Check if pause menu handles the mouserelease
    if self.paused and self.pauseMenu:mousereleased(x, y, button) then
        return true
    end
    
    -- Check if main menu handles the mouserelease
    if self.mainMenu.active and self.mainMenu:mousereleased(x, y, button) then
        return true
    end
    
    return false
end

-- Handle window resize
function UIManager:resize(width, height)
    -- Resize HUD
    self.hud:resize(width, height)
    
    -- Resize dialog
    if self.dialog.resize then
        self.dialog:resize(width, height)
    end
    
    -- Resize menus
    self.pauseMenu:resize(width, height)
    self.mainMenu:resize(width, height)
    
    return self
end

return UIManager
