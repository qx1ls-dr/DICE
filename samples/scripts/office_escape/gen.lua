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
    local steps = math.floor(rows * cols * 0.3)
    for i = 1, steps do
        grid[cr][cc] = "floor"
        local dir = math.random(1, 4)
        if dir == 1 and cr > 1 then cr = cr - 1
        elseif dir == 2 and cr < rows then cr = cr + 1
        elseif dir == 3 and cc > 1 then cc = cc - 1
        elseif dir == 4 and cc < cols then cc = cc + 1 end
    end

    local items = {}
    -- Place some coffee on floors
    for r = 1, rows do
        for c = 1, cols do
            if grid[r][c] == "floor" and math.random() < 0.1 then
                table.insert(items, {type="coffee", r=r, c=c})
            end
        end
    end
    -- Ensure at least one coffee if floor exists
    if #items == 0 then
        for r = 1, rows do
            for c = 1, cols do
                if grid[r][c] == "floor" then
                    table.insert(items, {type="coffee", r=r, c=c})
                    goto found
                end
            end
        end
    end
    ::found::

    -- Choose elevator position (far from the first floor tile found)
    local elevator = {r = 1, c = 1}
    local start_r, start_c = -1, -1
    for r = 1, rows do
        for c = 1, cols do
            if grid[r][c] == "floor" then
                if start_r == -1 then
                    start_r, start_c = r, c
                end
                -- Furthest tile by Manhattan distance
                if (math.abs(r - start_r) + math.abs(c - start_c)) > (math.abs(elevator.r - start_r) + math.abs(elevator.c - start_c)) then
                    elevator.r, elevator.c = r, c
                end
            end
        end
    end

    return grid, items, elevator
end

return M
