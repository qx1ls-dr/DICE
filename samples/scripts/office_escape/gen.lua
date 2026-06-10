local M = {}

function M.generate(rows, cols)
    local grid = {}
    for r = 1, rows do
        grid[r] = {}
        for c = 1, cols do
            grid[r][c] = "wall"
        end
    end
    -- Simple random walk for now
    local cr, cc = math.random(1, rows), math.random(1, cols)
    for i = 1, 20 do
        grid[cr][cc] = "floor"
        local dir = math.random(1, 4)
        if dir == 1 and cr > 1 then cr = cr - 1
        elseif dir == 2 and cr < rows then cr = cr + 1
        elseif dir == 3 and cc > 1 then cc = cc - 1
        elseif dir == 4 and cc < cols then cc = cc + 1 end
    end
    return grid
end

return M
