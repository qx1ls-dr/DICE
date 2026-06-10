local gen = require("scripts.office_escape.gen")

-- Deterministic runs in plain Lua (the engine uses cpp_rand instead).
math.randomseed(42)

-- BFS over floor tiles; returns dist[r][c] (nil = unreachable).
local function bfs_dist(grid, sr, sc)
    local rows, cols = #grid, #grid[1]
    local D4 = {{-1, 0}, {1, 0}, {0, -1}, {0, 1}}
    local dist = {}
    for r = 1, rows do dist[r] = {} end
    dist[sr][sc] = 0
    local q, head = {{sr, sc}}, 1
    while head <= #q do
        local r, c = q[head][1], q[head][2]
        head = head + 1
        for _, d in ipairs(D4) do
            local nr, nc = r + d[1], c + d[2]
            if nr >= 1 and nr <= rows and nc >= 1 and nc <= cols
               and grid[nr][nc] == "floor" and dist[nr][nc] == nil then
                dist[nr][nc] = dist[r][c] + 1
                q[#q + 1] = {nr, nc}
            end
        end
    end
    return dist
end

function test_generate_grid()
    local rows, cols = 10, 10
    local grid, items, elevator = gen.generate(rows, cols)
    assert(#grid == rows, "Grid should have " .. rows .. " rows")
    assert(#grid[1] == cols, "Grid should have " .. cols .. " cols")

    local floorCount = 0
    for r = 1, rows do
        for c = 1, cols do
            local val = grid[r][c]
            assert(val == "wall" or val == "floor", "Invalid tile value: " .. tostring(val))
            if val == "floor" then floorCount = floorCount + 1 end
        end
    end
    assert(floorCount > 0, "Generator should create at least one floor tile")
    assert(elevator ~= nil, "Generator should return an elevator position")
    assert(grid[elevator.r][elevator.c] == "floor", "Elevator should be on a floor tile")
end

function test_generate_items()
    local rows, cols = 10, 10
    local grid, items, elevator = gen.generate(rows, cols)
    assert(items ~= nil, "Generator should return an items list")
    assert(type(items) == "table", "Items should be a table")

    local coffeeCount = 0
    for _, item in ipairs(items) do
        assert(item.type == "coffee", "Item type should be 'coffee'")
        assert(item.r >= 1 and item.r <= rows, "Item row out of bounds")
        assert(item.c >= 1 and item.c <= cols, "Item col out of bounds")
        assert(grid[item.r][item.c] == "floor", "Items should only be placed on floor tiles")
        coffeeCount = coffeeCount + 1
    end
    assert(coffeeCount > 0, "Generator should create at least one coffee item")
end

function test_generate_start()
    local rows, cols = 10, 10
    local grid, items, elevator, start = gen.generate(rows, cols)
    assert(start ~= nil, "Generator should return a start position")
    assert(start.r >= 1 and start.r <= rows, "Start row out of bounds")
    assert(start.c >= 1 and start.c <= cols, "Start col out of bounds")
    assert(grid[start.r][start.c] == "floor", "Start should be on a floor tile")
end

function test_generate_dimensions()
    local grid = gen.generate(32, 48)
    assert(#grid == 32, "Grid should have 32 rows")
    assert(#grid[1] == 48, "Grid should have 48 cols")
end

function test_rooms_exist()
    -- Office floors have open rooms: at least one 3x3 all-floor block.
    -- A perfect maze with 1-wide corridors has none.
    local grid = gen.generate(32, 48)
    for r = 1, 32 - 2 do
        for c = 1, 48 - 2 do
            local open = true
            for dr = 0, 2 do
                for dc = 0, 2 do
                    if grid[r + dr][c + dc] ~= "floor" then open = false end
                end
            end
            if open then return end
        end
    end
    error("Expected at least one 3x3 open floor block (a room)")
end

function test_elevator_reachable_and_calibrated()
    for _ = 1, 20 do
        local grid, items, elevator, start = gen.generate(32, 48)
        local dist = bfs_dist(grid, start.r, start.c)
        local L = dist[elevator.r][elevator.c]
        assert(L ~= nil, "Elevator must be reachable from start")
        assert(L > 0, "Elevator must not sit on the start tile")
        -- Mirrors gen.lua calibration: STRESS_PER_STEP=2, COFFEE_RELIEF=25,
        -- search slack x1.5, full 100-point stress bar as budget.
        local relief = #items * 25
        assert(relief >= L * 2 * 1.5 - 100,
            "Coffee relief " .. relief .. " too low for path length " .. L)
    end
end

test_generate_grid()
test_generate_items()
test_generate_start()
test_generate_dimensions()
test_rooms_exist()
test_elevator_reachable_and_calibrated()
print("Office Gen Test: PASS")
