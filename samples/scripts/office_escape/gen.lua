local M = {}

function M.generate(rows, cols)
    local grid = {}
    for r = 1, rows do
        grid[r] = {}
        for c = 1, cols do
            grid[r][c] = "wall"
        end
    end

    -- Random walk carves the floor.
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

    -- Coffee on ~10% of floor tiles; guarantee at least one.
    local items = {}
    for r = 1, rows do
        for c = 1, cols do
            if grid[r][c] == "floor" and math.random() < 0.1 then
                table.insert(items, {type = "coffee", r = r, c = c})
            end
        end
    end
    if #items == 0 then
        for r = 1, rows do
            for c = 1, cols do
                if grid[r][c] == "floor" then
                    table.insert(items, {type = "coffee", r = r, c = c})
                    goto found
                end
            end
        end
    end
    ::found::

    -- start = first floor tile found; elevator = farthest floor tile from start.
    local start = {r = 1, c = 1}
    local elevator = {r = 1, c = 1}
    local start_set = false
    for r = 1, rows do
        for c = 1, cols do
            if grid[r][c] == "floor" then
                if not start_set then
                    start.r, start.c = r, c
                    elevator.r, elevator.c = r, c
                    start_set = true
                elseif (math.abs(r - start.r) + math.abs(c - start.c)) >
                       (math.abs(elevator.r - start.r) + math.abs(elevator.c - start.c)) then
                    elevator.r, elevator.c = r, c
                end
            end
        end
    end

    return grid, items, elevator, start
end

OfficeGen = M
return M
