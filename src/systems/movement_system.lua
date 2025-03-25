-- Movement System for Nightfall Chess
-- Handles grid-based movement, turn management, and action points

local class = require("lib.middleclass.middleclass")

local MovementSystem = class("MovementSystem")

function MovementSystem:initialize(grid, game)
    self.grid = grid
    self.game = game
    
    -- Turn management
    self.currentTurn = "player" -- "player" or "enemy"
    self.turnNumber = 1
    
    -- Action points
    self.actionPoints = 3
    self.maxActionPoints = 3
    
    -- Selected unit and target
    self.selectedUnit = nil
    self.targetPosition = nil
    self.highlightedTiles = {}
    self.movePath = nil
    
    -- Movement states
    self.state = "idle" -- "idle", "unit_selected", "moving", "attacking", "using_ability"
    
    -- Callbacks
    self.onTurnStart = nil
    self.onTurnEnd = nil
    self.onUnitMoved = nil
    self.onUnitAttacked = nil
    self.onActionPointsChanged = nil
end

-- Update movement system
function MovementSystem:update(dt)
    -- Update based on current state
    if self.state == "moving" then
        self:updateMovement(dt)
    elseif self.state == "attacking" then
        self:updateAttack(dt)
    elseif self.state == "using_ability" then
        self:updateAbility(dt)
    end
end

-- Handle input for movement
function MovementSystem:handleInput(input)
    if self.currentTurn ~= "player" then
        return
    end
    
    if self.state == "idle" then
        -- Select a unit
        if input:wasMousePressed(1) then
            local mouseX, mouseY = input.mouse.x, input.mouse.y
            local gridX, gridY = self.grid:screenToGrid(mouseX, mouseY)
            
            local entity = self.grid:getEntityAt(gridX, gridY)
            
            if entity and entity.faction == "player" and entity.canAct and entity:canAct() then
                self:selectUnit(entity)
            end
        end
        
        -- End turn
        if input:wasBindingPressed("endTurn") then
            self:endTurn()
        end
    elseif self.state == "unit_selected" then
        -- Move or attack with selected unit
        if input:wasMousePressed(1) then
            local mouseX, mouseY = input.mouse.x, input.mouse.y
            local gridX, gridY = self.grid:screenToGrid(mouseX, mouseY)
            
            -- Check if clicked on a valid move position
            local validMove = false
            for _, pos in ipairs(self.highlightedTiles.move or {}) do
                if pos.x == gridX and pos.y == gridY then
                    validMove = true
                    break
                end
            end
            
            if validMove then
                self:moveSelectedUnit(gridX, gridY)
            else
                -- Check if clicked on a valid attack target
                local validAttack = false
                local targetEntity = nil
                
                for _, target in ipairs(self.highlightedTiles.attack or {}) do
                    if target.x == gridX and target.y == gridY then
                        validAttack = true
                        targetEntity = target.entity
                        break
                    end
                end
                
                if validAttack and targetEntity then
                    self:attackWithSelectedUnit(targetEntity)
                else
                    -- Deselect if clicked elsewhere
                    self:deselectUnit()
                end
            end
        end
        
        -- Cancel selection
        if input:wasBindingPressed("cancel") then
            self:deselectUnit()
        end
    end
end

-- Select a unit
function MovementSystem:selectUnit(unit)
    self.selectedUnit = unit
    self.state = "unit_selected"
    
    -- Get valid move positions and attack targets
    self.highlightedTiles = {
        move = unit:getValidMovePositions(),
        attack = unit:getValidAttackTargets()
    }
    
    -- Calculate path to mouse position
    self:updatePathToMouse()
end

-- Deselect the current unit
function MovementSystem:deselectUnit()
    self.selectedUnit = nil
    self.targetPosition = nil
    self.highlightedTiles = {}
    self.movePath = nil
    self.state = "idle"
end

-- Update path to mouse position
function MovementSystem:updatePathToMouse()
    if not self.selectedUnit or self.state ~= "unit_selected" then
        return
    end
    
    local mouseX, mouseY = love.mouse.getPosition()
    local gridX, gridY = self.grid:screenToGrid(mouseX, mouseY)
    
    -- Check if mouse is over a valid move position
    local isValidMove = false
    for _, pos in ipairs(self.highlightedTiles.move or {}) do
        if pos.x == gridX and pos.y == gridY then
            isValidMove = true
            break
        end
    end
    
    if isValidMove then
        -- Calculate path to mouse position
        self.movePath = self.grid:findPath(
            self.selectedUnit.x,
            self.selectedUnit.y,
            gridX,
            gridY
        )
    else
        self.movePath = nil
    end
end

-- Move the selected unit to a position
function MovementSystem:moveSelectedUnit(x, y)
    if not self.selectedUnit or self.actionPoints <= 0 then
        return false
    end
    
    -- Calculate path
    local path = self.grid:findPath(
        self.selectedUnit.x,
        self.selectedUnit.y,
        x,
        y
    )
    
    if not path then
        return false
    end
    
    -- Set target position
    self.targetPosition = {x = x, y = y}
    self.movePath = path
    self.state = "moving"
    
    -- Use action point
    self:useActionPoint()
    
    -- Mark unit as moved
    self.selectedUnit.hasMoved = true
    
    return true
end

-- Update unit movement along path
function MovementSystem:updateMovement(dt)
    if not self.selectedUnit or not self.targetPosition or not self.movePath then
        self.state = "idle"
        return
    end
    
    -- Move unit to target position
    local success = self.selectedUnit:moveTo(self.targetPosition.x, self.targetPosition.y)
    
    if success then
        -- Trigger callback
        if self.onUnitMoved then
            self.onUnitMoved(self.selectedUnit, self.targetPosition)
        end
        
        -- Update visibility
        self.grid:updateVisibility()
        
        -- Reset state
        self.targetPosition = nil
        self.movePath = nil
        
        -- Check if unit can still act
        if self.selectedUnit:canAct() and self.actionPoints > 0 then
            -- Keep unit selected
            self.state = "unit_selected"
            
            -- Update highlighted tiles
            self.highlightedTiles = {
                move = self.selectedUnit:getValidMovePositions(),
                attack = self.selectedUnit:getValidAttackTargets()
            }
        else
            -- Deselect unit if it can't act anymore
            self:deselectUnit()
        end
    else
        -- Movement failed
        self.state = "unit_selected"
    end
end

-- Attack with the selected unit
function MovementSystem:attackWithSelectedUnit(target)
    if not self.selectedUnit or not target or self.actionPoints <= 0 then
        return false
    end
    
    -- Check if target is valid
    local validTarget = false
    for _, t in ipairs(self.highlightedTiles.attack or {}) do
        if t.entity == target then
            validTarget = true
            break
        end
    end
    
    if not validTarget then
        return false
    end
    
    -- Set target and state
    self.targetEntity = target
    self.state = "attacking"
    
    -- Use action point
    self:useActionPoint()
    
    -- Perform attack
    local success = self.selectedUnit:attack(target)
    
    if success then
        -- Trigger callback
        if self.onUnitAttacked then
            self.onUnitAttacked(self.selectedUnit, target)
        end
        
        -- Reset state
        self.targetEntity = nil
        
        -- Check if unit can still act
        if self.selectedUnit:canAct() and self.actionPoints > 0 then
            -- Keep unit selected
            self.state = "unit_selected"
            
            -- Update highlighted tiles
            self.highlightedTiles = {
                move = self.selectedUnit:getValidMovePositions(),
                attack = self.selectedUnit:getValidAttackTargets()
            }
        else
            -- Deselect unit if it can't act anymore
            self:deselectUnit()
        end
    else
        -- Attack failed
        self.state = "unit_selected"
    end
    
    return success
end

-- Update attack animation/effects
function MovementSystem:updateAttack(dt)
    -- This would handle attack animations
    -- For now, just reset state
    self.state = "unit_selected"
end

-- Use an ability with the selected unit
function MovementSystem:useAbilityWithSelectedUnit(abilityIndex, target)
    if not self.selectedUnit or self.actionPoints <= 0 then
        return false
    end
    
    -- Set target and state
    self.targetEntity = target
    self.state = "using_ability"
    
    -- Use action point
    self:useActionPoint()
    
    -- Use ability
    local success = self.selectedUnit:useAbility(abilityIndex, target)
    
    if success then
        -- Reset state
        self.targetEntity = nil
        
        -- Check if unit can still act
        if self.selectedUnit:canAct() and self.actionPoints > 0 then
            -- Keep unit selected
            self.state = "unit_selected"
            
            -- Update highlighted tiles
            self.highlightedTiles = {
                move = self.selectedUnit:getValidMovePositions(),
                attack = self.selectedUnit:getValidAttackTargets()
            }
        else
            -- Deselect unit if it can't act anymore
            self:deselectUnit()
        end
    else
        -- Ability use failed
        self.state = "unit_selected"
    end
    
    return success
end

-- Update ability animation/effects
function MovementSystem:updateAbility(dt)
    -- This would handle ability animations
    -- For now, just reset state
    self.state = "unit_selected"
end

-- Start a new turn
function MovementSystem:startTurn(faction)
    self.currentTurn = faction
    
    if faction == "player" then
        -- Reset action points
        self.actionPoints = self.maxActionPoints
        
        -- Reset all player units
        for entity, _ in pairs(self.grid.entities) do
            if entity.faction == "player" and entity.resetActionState then
                entity:resetActionState()
            end
        end
        
        -- Trigger callback
        if self.onTurnStart then
            self.onTurnStart(faction)
        end
        
        -- Trigger action points changed callback
        if self.onActionPointsChanged then
            self.onActionPointsChanged(self.actionPoints, self.maxActionPoints)
        end
    else
        -- Enemy turn
        self:startEnemyTurn()
    end
end

-- End the current turn
function MovementSystem:endTurn()
    -- Deselect current unit
    self:deselectUnit()
    
    -- Trigger callback
    if self.onTurnEnd then
        self.onTurnEnd(self.currentTurn)
    end
    
    -- Switch turns
    if self.currentTurn == "player" then
        self.currentTurn = "enemy"
        self:startTurn("enemy")
    else
        self.currentTurn = "player"
        self.turnNumber = self.turnNumber + 1
        self:startTurn("player")
    end
end

-- Start enemy turn (AI)
function MovementSystem:startEnemyTurn()
    -- This would be replaced with actual AI logic
    -- For now, just end the turn after a delay
    self.game.timer.after(1, function()
        self:endTurn()
    end)
end

-- Use an action point
function MovementSystem:useActionPoint()
    if self.actionPoints <= 0 then
        return false
    end
    
    self.actionPoints = self.actionPoints - 1
    
    -- Trigger callback
    if self.onActionPointsChanged then
        self.onActionPointsChanged(self.actionPoints, self.maxActionPoints)
    end
    
    return true
end

-- Draw movement-related visuals
function MovementSystem:draw(camera)
    -- Draw highlighted tiles
    self:drawHighlightedTiles(camera)
    
    -- Draw movement path
    self:drawMovementPath(camera)
end

-- Draw highlighted tiles
function MovementSystem:drawHighlightedTiles(camera)
    if self.state ~= "unit_selected" or not self.highlightedTiles then
        return
    end
    
    local offsetX = camera and camera.x or 0
    local offsetY = camera and camera.y or 0
    
    -- Draw move positions
    love.graphics.setColor(0.2, 0.7, 0.2, 0.3)
    
    for _, pos in ipairs(self.highlightedTiles.move or {}) do
        local screenX, screenY = self.grid:gridToScreen(pos.x, pos.y)
        screenX = screenX - offsetX
        screenY = screenY - offsetY
        
        love.graphics.rectangle(
            "fill",
            screenX,
            screenY,
            self.grid.tileSize,
            self.grid.tileSize
        )
    end
    
    -- Draw attack targets
    love.graphics.setColor(0.7, 0.2, 0.2, 0.3)
    
    for _, target in ipairs(self.highlightedTiles.attack or {}) do
        local screenX, screenY = self.grid:gridToScreen(target.x, target.y)
        screenX = screenX - offsetX
        screenY = screenY - offsetY
        
        love.graphics.rectangle(
            "fill",
            screenX,
            screenY,
            self.grid.tileSize,
            self.grid.tileSize
        )
    end
    
    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

-- Draw movement path
function MovementSystem:drawMovementPath(camera)
    if not self.movePath or #self.movePath < 2 then
        return
    end
    
    local offsetX = camera and camera.x or 0
    local offsetY = camera and camera.y or 0
    
    -- Draw path
    love.graphics.setColor(0.2, 0.7, 0.2, 0.7)
    love.graphics.setLineWidth(2)
    
    for i = 1, #self.movePath - 1 do
        local current = self.movePath[i]
        local next = self.movePath[i + 1]
        
        local x1, y1 = self.grid:gridToScreen(current.x, current.y)
        local x2, y2 = self.grid:gridToScreen(next.x, next.y)
        
        -- Center points in tiles
        x1 = x1 + self.grid.tileSize / 2 - offsetX
        y1 = y1 + self.grid.tileSize / 2 - offsetY
        x2 = x2 + self.grid.tileSize / 2 - offsetX
        y2 = y2 + self.grid.tileSize / 2 - offsetY
        
        love.graphics.line(x1, y1, x2, y2)
    end
    
    -- Draw points
    for i, point in ipairs(self.movePath) do
        local x, y = self.grid:gridToScreen(point.x, point.y)
        
        -- Center point in tile
        x = x + self.grid.tileSize / 2 - offsetX
        y = y + self.grid.tileSize / 2 - offsetY
        
        if i == 1 then
            -- Start point
            love.graphics.setColor(0.2, 0.7, 0.2, 0.7)
        elseif i == #self.movePath then
            -- End point
            love.graphics.setColor(0.7, 0.7, 0.2, 0.7)
        else
            -- Intermediate point
            love.graphics.setColor(0.2, 0.7, 0.2, 0.5)
        end
        
        love.graphics.circle("fill", x, y, 4)
    end
    
    -- Reset color and line width
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
end

return MovementSystem
