local M = {}

-- RNG: cpp_rand inside the engine (seeded on the C++ side), math.random in
-- plain Lua (tests). The engine has no `os`, so seeding math.random there
-- is impossible — cpp_rand is what makes maps differ between launches.
local rand = (type(cpp_rand) == "function") and cpp_rand
    or function(lo, hi) return math.random(lo, hi) end

-- BSP tuning (tiles).
local MIN_LEAF = 10      -- regions smaller than 2*MIN_LEAF per side never split
local MAX_LEAF = 16      -- regions larger than this per side must split
local SPLIT_CHANCE = 75  -- % chance to split when allowed but not forced

-- ── carving ─────────────────────────────────────────────────────────────────

local function carve_h(grid, r, c1, c2)
    if c2 < c1 then c1, c2 = c2, c1 end
    for c = c1, c2 do grid[r][c] = "floor" end
end

local function carve_v(grid, c, r1, r2)
    if r2 < r1 then r1, r2 = r2, r1 end
    for r = r1, r2 do grid[r][c] = "floor" end
end

-- L-shaped corridor between two points (random elbow orientation).
local function carve_corridor(grid, a, b)
    if rand(1, 2) == 1 then
        carve_h(grid, a.r, a.c, b.c)
        carve_v(grid, b.c, a.r, b.r)
    else
        carve_v(grid, a.c, a.r, b.r)
        carve_h(grid, b.r, a.c, b.c)
    end
end

-- ── BSP ─────────────────────────────────────────────────────────────────────

-- Recursively split `region` {r1,c1,r2,c2} (inclusive tile bounds), carve a
-- room in each leaf and an L-corridor between sibling subtrees. Connectivity
-- is guaranteed by construction. Appends rooms to `rooms`; returns a
-- connection point (the centre of one room in the subtree).
local function build(grid, region, rooms)
    local h = region.r2 - region.r1 + 1
    local w = region.c2 - region.c1 + 1
    local can_h = h >= 2 * MIN_LEAF
    local can_v = w >= 2 * MIN_LEAF
    local must = h > MAX_LEAF or w > MAX_LEAF

    if (can_h or can_v) and (must or rand(1, 100) <= SPLIT_CHANCE) then
        local split_rows
        if can_h and can_v then split_rows = h >= w else split_rows = can_h end

        local a, b
        if split_rows then
            local cut = rand(region.r1 + MIN_LEAF - 1, region.r2 - MIN_LEAF)
            a = {r1 = region.r1, c1 = region.c1, r2 = cut, c2 = region.c2}
            b = {r1 = cut + 1, c1 = region.c1, r2 = region.r2, c2 = region.c2}
        else
            local cut = rand(region.c1 + MIN_LEAF - 1, region.c2 - MIN_LEAF)
            a = {r1 = region.r1, c1 = region.c1, r2 = region.r2, c2 = cut}
            b = {r1 = region.r1, c1 = cut + 1, r2 = region.r2, c2 = region.c2}
        end

        local pa = build(grid, a, rooms)
        local pb = build(grid, b, rooms)
        carve_corridor(grid, pa, pb)
        return rand(1, 2) == 1 and pa or pb
    end

    -- Leaf: carve a room with a >=1 tile gap from the leaf border.
    local max_h = h - 2
    local max_w = w - 2
    local rh = rand(math.max(3, max_h - 4), max_h)
    local rw = rand(math.max(3, max_w - 4), max_w)
    local r1 = rand(region.r1 + 1, region.r2 - rh)
    local c1 = rand(region.c1 + 1, region.c2 - rw)
    local room = {r1 = r1, c1 = c1, r2 = r1 + rh - 1, c2 = c1 + rw - 1}
    for r = room.r1, room.r2 do
        for c = room.c1, room.c2 do grid[r][c] = "floor" end
    end
    rooms[#rooms + 1] = room
    return {r = (room.r1 + room.r2) // 2, c = (room.c1 + room.c2) // 2}
end

-- ── path analysis ───────────────────────────────────────────────────────────

-- BFS over floor tiles. Returns dist[r][c] and `reached` — the list of
-- reachable tiles in breadth-first (distance-sorted) order.
local function bfs(grid, rows, cols, sr, sc)
    local D4 = {{-1, 0}, {1, 0}, {0, -1}, {0, 1}}
    local dist = {}
    for r = 1, rows do dist[r] = {} end
    dist[sr][sc] = 0
    local reached = {{r = sr, c = sc}}
    local head = 1
    while head <= #reached do
        local cur = reached[head]
        head = head + 1
        for _, d in ipairs(D4) do
            local nr, nc = cur.r + d[1], cur.c + d[2]
            if nr >= 1 and nr <= rows and nc >= 1 and nc <= cols
               and grid[nr][nc] == "floor" and dist[nr][nc] == nil then
                dist[nr][nc] = dist[cur.r][cur.c] + 1
                reached[#reached + 1] = {r = nr, c = nc}
            end
        end
    end
    return dist, reached
end

-- ── public API ──────────────────────────────────────────────────────────────

-- generate(rows, cols) -> grid, items, elevator, start
-- Minimum supported size is 10x10 (the unit tests rely on it).
function M.generate(rows, cols)
    local grid = {}
    for r = 1, rows do
        grid[r] = {}
        for c = 1, cols do grid[r][c] = "wall" end
    end

    -- Keep a solid 1-tile wall border around the whole floor plan.
    local rooms = {}
    build(grid, {r1 = 2, c1 = 2, r2 = rows - 1, c2 = cols - 1}, rooms)

    -- Start: centre of a random room.
    local sroom = rooms[rand(1, #rooms)]
    local start = {r = (sroom.r1 + sroom.r2) // 2, c = (sroom.c1 + sroom.c2) // 2}

    -- Real path distances from the start tile.
    local dist, reached = bfs(grid, rows, cols, start.r, start.c)

    -- Elevator: a random tile from the farthest third by path distance —
    -- always far, but not always the same opposite corner.
    local pick = reached[rand(math.floor(#reached * 2 / 3) + 1, #reached)]
    local elevator = {r = pick.r, c = pick.c}

    -- Coffee: 0-2 per room, then top up until a fair run is possible.
    local items = {}
    local occupied = {
        [start.r .. ":" .. start.c] = true,
        [elevator.r .. ":" .. elevator.c] = true,
    }
    local function try_add(r, c)
        local k = r .. ":" .. c
        if grid[r][c] == "floor" and not occupied[k] then
            occupied[k] = true
            items[#items + 1] = {type = "coffee", r = r, c = c}
        end
    end
    for _, room in ipairs(rooms) do
        for _ = 1, rand(0, 2) do
            try_add(rand(room.r1, room.r2), rand(room.c1, room.c2))
        end
    end

    -- Calibration: total coffee relief must cover the fair path with x1.5
    -- search slack minus the full 100-point stress bar. Mirrors OfficeLogic
    -- constants when it is loaded (engine); falls back in plain-Lua tests.
    local sps = (OfficeLogic and OfficeLogic.STRESS_PER_STEP) or 2
    local relief = (OfficeLogic and OfficeLogic.COFFEE_RELIEF) or 25
    local L = dist[elevator.r][elevator.c]
    local needed = math.ceil((L * sps * 1.5 - 100) / relief)
    if needed < 1 then needed = 1 end
    local guard = 0
    while #items < needed and guard < 10000 do
        local t = reached[rand(1, #reached)]
        try_add(t.r, t.c)
        guard = guard + 1
    end

    return grid, items, elevator, start
end

OfficeGen = M
return M
