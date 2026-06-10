local M = {}

-- Direction table: step (dr,dc) to next cell, (wr,wc) = wall tile to carve between.
local DIRS = {
    {dr=-2, dc=0,  wr=-1, wc=0 },  -- up
    {dr=2,  dc=0,  wr=1,  wc=0 },  -- down
    {dr=0,  dc=-2, wr=0,  wc=-1},  -- left
    {dr=0,  dc=2,  wr=0,  wc=1 },  -- right
}

-- Iterative DFS (recursive-backtracking) maze on a cell grid.
-- Cells sit at odd (r,c) positions; walls between adjacent cells are at even positions.
-- Every cell is reachable → perfect maze with winding corridors and dead ends.
local function carve_maze(grid, rows, cols)
    local visited = {}
    for r = 1, rows do visited[r] = {} end

    -- Random starting cell (odd row and col).
    local sr = 1 + 2 * math.random(0, (rows - 1) // 2)
    local sc = 1 + 2 * math.random(0, (cols - 1) // 2)
    grid[sr][sc] = "floor"
    visited[sr][sc] = true

    local stack = {{r=sr, c=sc}}
    while #stack > 0 do
        local cur = stack[#stack]
        local r, c = cur.r, cur.c

        -- Shuffle directions for this cell (collect + Fisher-Yates).
        local shuffled = {DIRS[1], DIRS[2], DIRS[3], DIRS[4]}
        for i = 4, 2, -1 do
            local j = math.random(i)
            shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
        end

        local moved = false
        for _, d in ipairs(shuffled) do
            local nr, nc = r + d.dr, c + d.dc
            if nr >= 1 and nr <= rows and nc >= 1 and nc <= cols
               and not visited[nr][nc] then
                -- Carve through the wall between current cell and neighbour.
                grid[r + d.wr][c + d.wc] = "floor"
                grid[nr][nc] = "floor"
                visited[nr][nc] = true
                table.insert(stack, {r=nr, c=nc})
                moved = true
                break
            end
        end
        if not moved then table.remove(stack) end
    end
end

function M.generate(rows, cols)
    local grid = {}
    for r = 1, rows do
        grid[r] = {}
        for c = 1, cols do grid[r][c] = "wall" end
    end

    carve_maze(grid, rows, cols)

    -- Coffee on ~15% of floor tiles; guarantee at least one.
    local items = {}
    for r = 1, rows do
        for c = 1, cols do
            if grid[r][c] == "floor" and math.random() < 0.15 then
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

    -- Collect all floor tiles for start/elevator selection.
    local floors = {}
    for r = 1, rows do
        for c = 1, cols do
            if grid[r][c] == "floor" then
                table.insert(floors, {r=r, c=c})
            end
        end
    end

    -- Random start among cell-grid positions (odd r and c) so the player
    -- always begins inside a proper corridor junction, not a passage tile.
    local cells = {}
    for _, t in ipairs(floors) do
        if t.r % 2 == 1 and t.c % 2 == 1 then
            table.insert(cells, t)
        end
    end
    local pool = #cells > 0 and cells or floors
    local si = math.random(#pool)
    local start = {r = pool[si].r, c = pool[si].c}

    -- Elevator = floor tile with maximum Manhattan distance from start.
    local elevator = {r = start.r, c = start.c}
    for _, t in ipairs(floors) do
        if (math.abs(t.r - start.r) + math.abs(t.c - start.c)) >
           (math.abs(elevator.r - start.r) + math.abs(elevator.c - start.c)) then
            elevator = {r = t.r, c = t.c}
        end
    end

    return grid, items, elevator, start
end

OfficeGen = M
return M
