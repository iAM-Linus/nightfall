-- Chess Movement Patterns for Nightfall Chess
-- Defines movement patterns for different chess-inspired units

local ChessMovement = {}

-- Define orthogonal directions (rook-like movement)
ChessMovement.ORTHOGONAL = {
    {x = 1, y = 0},  -- right
    {x = -1, y = 0}, -- left
    {x = 0, y = 1},  -- down
    {x = 0, y = -1}  -- up
}

-- Define diagonal directions (bishop-like movement)
ChessMovement.DIAGONAL = {
    {x = 1, y = 1},   -- down-right
    {x = 1, y = -1},  -- up-right
    {x = -1, y = 1},  -- down-left
    {x = -1, y = -1}  -- up-left
}

-- Define knight movement patterns
ChessMovement.KNIGHT = {
    {x = 2, y = 1},
    {x = 2, y = -1},
    {x = -2, y = 1},
    {x = -2, y = -1},
    {x = 1, y = 2},
    {x = 1, y = -2},
    {x = -1, y = 2},
    {x = -1, y = -2}
}

-- Define king movement (one square in any direction)
ChessMovement.KING = {
    {x = 1, y = 0},
    {x = -1, y = 0},
    {x = 0, y = 1},
    {x = 0, y = -1},
    {x = 1, y = 1},
    {x = 1, y = -1},
    {x = -1, y = 1},
    {x = -1, y = -1}
}

-- Define queen movement (combines rook and bishop)
ChessMovement.QUEEN = {}
for _, dir in ipairs(ChessMovement.ORTHOGONAL) do
    table.insert(ChessMovement.QUEEN, dir)
end
for _, dir in ipairs(ChessMovement.DIAGONAL) do
    table.insert(ChessMovement.QUEEN, dir)
end

-- Define pawn movement (forward only, with special first move)
ChessMovement.PAWN = {
    forward = {x = 0, y = -1},      -- Forward direction (for player)
    forwardEnemy = {x = 0, y = 1},  -- Forward direction (for enemy)
    firstMoveExtra = 1,             -- Extra distance on first move
    captureDirections = {           -- Diagonal capture directions (for player)
        {x = 1, y = -1},
        {x = -1, y = -1}
    },
    captureDirectionsEnemy = {      -- Diagonal capture directions (for enemy)
        {x = 1, y = 1},
        {x = -1, y = 1}
    }
}

-- Get valid moves for a specific pattern
function ChessMovement.getValidMoves(pattern, x, y, grid, unit, maxDistance)
    local validMoves = {}
    
    -- Default max distance
    maxDistance = maxDistance or 8
    
    -- Handle different movement patterns
    if pattern == "pawn" then
        return ChessMovement.getPawnMoves(x, y, grid, unit)
    elseif pattern == "knight" then
        return ChessMovement.getKnightMoves(x, y, grid, unit)
    elseif pattern == "king" then
        return ChessMovement.getKingMoves(x, y, grid, unit)
    elseif pattern == "queen" then
        return ChessMovement.getLinearMoves(ChessMovement.QUEEN, x, y, grid, unit, maxDistance)
    elseif pattern == "rook" then
        return ChessMovement.getLinearMoves(ChessMovement.ORTHOGONAL, x, y, grid, unit, maxDistance)
    elseif pattern == "bishop" then
        return ChessMovement.getLinearMoves(ChessMovement.DIAGONAL, x, y, grid, unit, maxDistance)
    end
    
    return validMoves
end

-- Get linear moves (for queen, rook, bishop)
function ChessMovement.getLinearMoves(directions, x, y, grid, unit, maxDistance)
    local validMoves = {}
    
    for _, dir in ipairs(directions) do
        for dist = 1, maxDistance do
            local newX = x + (dir.x * dist)
            local newY = y + (dir.y * dist)
            
            -- Check if position is valid
            if grid:isValidPosition(newX, newY) then
                local entity = grid:getEntityAt(newX, newY)
                
                if entity then
                    -- Can't move through other entities
                    if entity.faction ~= unit.faction then
                        -- Can attack enemy units
                        table.insert(validMoves, {x = newX, y = newY, isAttack = true, entity = entity})
                    end
                    
                    -- Stop checking this direction
                    break
                else
                    -- Empty space, can move here
                    table.insert(validMoves, {x = newX, y = newY})
                    
                    -- Check if terrain blocks movement
                    local terrain = grid:getTerrainAt(newX, newY)
                    if terrain and terrain.blocksMovement then
                        break
                    end
                end
            else
                -- Out of bounds
                break
            end
        end
    end
    
    return validMoves
end

-- Get knight moves
function ChessMovement.getKnightMoves(x, y, grid, unit)
    local validMoves = {}
    
    for _, move in ipairs(ChessMovement.KNIGHT) do
        local newX = x + move.x
        local newY = y + move.y
        
        -- Check if position is valid
        print(newX, " ", newY)
        if grid:isValidPosition(newX, newY) then
            local entity = grid:getEntityAt(newX, newY)
            
            if entity then
                -- Can't move to occupied space
                if entity.faction ~= unit.faction then
                    -- Can attack enemy units
                    table.insert(validMoves, {x = newX, y = newY, isAttack = true, entity = entity})
                end
            else
                -- Empty space, can move here
                local terrain = grid:getTerrainAt(newX, newY)
                if not terrain or not terrain.blocksMovement then
                    table.insert(validMoves, {x = newX, y = newY})
                end
            end
        end
    end
    
    return validMoves
end

-- Get king moves
function ChessMovement.getKingMoves(x, y, grid, unit)
    local validMoves = {}
    
    for _, move in ipairs(ChessMovement.KING) do
        local newX = x + move.x
        local newY = y + move.y
        
        -- Check if position is valid
        if grid:isValidPosition(newX, newY) then
            local entity = grid:getEntityAt(newX, newY)
            
            if entity then
                -- Can't move to occupied space
                if entity.faction ~= unit.faction then
                    -- Can attack enemy units
                    table.insert(validMoves, {x = newX, y = newY, isAttack = true, entity = entity})
                end
            else
                -- Empty space, can move here
                local terrain = grid:getTerrainAt(newX, newY)
                if not terrain or not terrain.blocksMovement then
                    table.insert(validMoves, {x = newX, y = newY})
                end
            end
        end
    end
    
    return validMoves
end

-- Get pawn moves
function ChessMovement.getPawnMoves(x, y, grid, unit)
    local validMoves = {}
    
    -- Determine forward direction based on faction
    local forward = unit.faction == "player" 
        and ChessMovement.PAWN.forward 
        or ChessMovement.PAWN.forwardEnemy
    
    -- Determine capture directions based on faction
    local captureDirections = unit.faction == "player"
        and ChessMovement.PAWN.captureDirections
        or ChessMovement.PAWN.captureDirectionsEnemy
    
    -- Forward movement
    local newX = x + forward.x
    local newY = y + forward.y
    
    -- Check if forward position is valid
    if grid:isValidPosition(newX, newY) then
        local entity = grid:getEntityAt(newX, newY)
        
        if not entity then
            -- Empty space, can move here
            local terrain = grid:getTerrainAt(newX, newY)
            if not terrain or not terrain.blocksMovement then
                table.insert(validMoves, {x = newX, y = newY})
                
                -- Check for first move extra distance
                if not unit.hasMoved then
                    local extraX = newX + forward.x
                    local extraY = newY + forward.y
                    
                    if grid:isValidPosition(extraX, extraY) then
                        local extraEntity = grid:getEntityAt(extraX, extraY)
                        
                        if not extraEntity then
                            -- Empty space, can move here
                            local extraTerrain = grid:getTerrainAt(extraX, extraY)
                            if not extraTerrain or not extraTerrain.blocksMovement then
                                table.insert(validMoves, {x = extraX, y = extraY})
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- Capture moves
    for _, dir in ipairs(captureDirections) do
        local captureX = x + dir.x
        local captureY = y + dir.y
        
        if grid:isValidPosition(captureX, captureY) then
            local entity = grid:getEntityAt(captureX, captureY)
            
            if entity and entity.faction ~= unit.faction then
                -- Can capture enemy units
                table.insert(validMoves, {x = captureX, y = captureY, isAttack = true, entity = entity})
            end
        end
    end
    
    return validMoves
end

-- Get attack targets for a specific pattern
function ChessMovement.getAttackTargets(pattern, x, y, grid, unit, maxDistance)
    local targets = {}
    
    -- For most pieces, attack targets are the same as movement targets
    local moves = ChessMovement.getValidMoves(pattern, x, y, grid, unit, maxDistance)
    
    for _, move in ipairs(moves) do
        if move.isAttack then
            table.insert(targets, move)
        end
    end
    
    return targets
end

-- Get movement range (for UI highlighting)
function ChessMovement.getMovementRange(pattern, maxDistance)
    local range = {}
    
    if pattern == "pawn" then
        -- Pawn has special movement
        table.insert(range, {x = 0, y = -1})
        table.insert(range, {x = 0, y = -2}) -- First move
        table.insert(range, {x = 1, y = -1}) -- Capture
        table.insert(range, {x = -1, y = -1}) -- Capture
    elseif pattern == "knight" then
        -- Knight has fixed movement
        for _, move in ipairs(ChessMovement.KNIGHT) do
            table.insert(range, move)
        end
    elseif pattern == "king" then
        -- King has fixed movement
        for _, move in ipairs(ChessMovement.KING) do
            table.insert(range, move)
        end
    else
        -- Linear movement (queen, rook, bishop)
        local directions
        
        if pattern == "queen" then
            directions = ChessMovement.QUEEN
        elseif pattern == "rook" then
            directions = ChessMovement.ORTHOGONAL
        elseif pattern == "bishop" then
            directions = ChessMovement.DIAGONAL
        end
        
        for _, dir in ipairs(directions) do
            for dist = 1, maxDistance do
                table.insert(range, {x = dir.x * dist, y = dir.y * dist})
            end
        end
    end
    
    return range
end

return ChessMovement
