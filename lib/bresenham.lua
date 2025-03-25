-- Bresenham's Line Algorithm implementation for LÖVE2D
-- Used for line-of-sight calculations in Nightfall Chess

local bresenham = {}

-- Implementation of Bresenham's line algorithm
-- Returns a table of points (x,y) along the line from (x0,y0) to (x1,y1)
function bresenham.line(x0, y0, x1, y1)
    local points = {}
    
    local dx = math.abs(x1 - x0)
    local dy = math.abs(y1 - y0)
    local sx = x0 < x1 and 1 or -1
    local sy = y0 < y1 and 1 or -1
    local err = dx - dy
    
    while true do
        table.insert(points, {x = x0, y = y0})
        
        if x0 == x1 and y0 == y1 then
            break
        end
        
        local e2 = 2 * err
        if e2 > -dy then
            err = err - dy
            x0 = x0 + sx
        end
        if e2 < dx then
            err = err + dx
            y0 = y0 + sy
        end
    end
    
    return points
end

-- Check if there's a clear line of sight between two points
-- Returns true if there's a clear line, false if blocked
-- blockingFunc is a function that takes (x,y) and returns true if the cell blocks line of sight
function bresenham.hasLineOfSight(x0, y0, x1, y1, blockingFunc)
    local points = bresenham.line(x0, y0, x1, y1)
    
    -- Skip the first point (starting position)
    for i = 2, #points do
        local point = points[i]
        if blockingFunc(point.x, point.y) then
            return false
        end
        -- If we've reached the end point, there's a clear line of sight
        if point.x == x1 and point.y == y1 then
            return true
        end
    end
    
    return true
end

return bresenham
