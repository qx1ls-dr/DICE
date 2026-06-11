local M = {}

M.MAX_FLOOR       = 5    -- tower height; start at the top, escape from floor 1
M.STRESS_PER_STEP = 2    -- stress gained per move
M.COFFEE_RELIEF   = 25   -- stress removed per coffee

-- Generate a fresh floor into `state` using the provided generate function.
function M.new_floor(state, generate_fn, rows, cols)
    local grid, items, elevator, start = generate_fn(rows, cols)
    state.grid = grid
    state.items = items
    state.elevator = elevator
    state.player_r = start.r
    state.player_c = start.c
    return state
end

-- Reset all run state and build the first (top) floor.
function M.new_game(state, generate_fn, rows, cols)
    state.floor = M.MAX_FLOOR
    state.stress = 0
    state.coffee = 0
    state.steps = 0
    state.floors_cleared = 0
    M.new_floor(state, generate_fn, rows, cols)
    return state
end

-- Add stress, clamp to [0,100]. Returns true if at burnout (>= 100).
function M.add_stress(state, delta)
    state.stress = math.min(100, math.max(0, state.stress + delta))
    return state.stress >= 100
end

-- If coffee sits at (r,c), drink it. Returns true if something was picked up.
function M.pickup(state, r, c)
    for i = #state.items, 1, -1 do
        local it = state.items[i]
        if it.r == r and it.c == c then
            if it.type == "coffee" then
                M.add_stress(state, -M.COFFEE_RELIEF)
                state.coffee = state.coffee + 1
            end
            table.remove(state.items, i)
            return true
        end
    end
    return false
end

-- Attempt a move by (dr,dc). Returns one of:
--   "blocked"  — wall or out of bounds, nothing changed
--   "step"     — moved onto a normal tile
--   "elevator" — moved onto the elevator tile (takes priority over burnout)
--   "burnout"  — the step's stress reached 100
function M.try_move(state, dr, dc)
    local nr, nc = state.player_r + dr, state.player_c + dc
    if nr < 1 or nr > #state.grid or nc < 1 or nc > #state.grid[1] then
        return "blocked"
    end
    if state.grid[nr][nc] == "wall" then
        return "blocked"
    end
    state.player_r, state.player_c = nr, nc
    state.steps = state.steps + 1
    M.pickup(state, nr, nc)
    local burnout = M.add_stress(state, M.STRESS_PER_STEP)
    if nr == state.elevator.r and nc == state.elevator.c then return "elevator" end
    if burnout then return "burnout" end
    return "step"
end

-- Take the elevator down. Returns "win" if this was the ground floor (escape),
-- otherwise "next" after decrementing the floor and generating it. Clearing a
-- floor resets stress to 0 — each floor is a fresh, self-contained challenge.
function M.descend(state, generate_fn, rows, cols)
    state.floors_cleared = state.floors_cleared + 1
    if state.floor <= 1 then
        return "win"
    end
    state.floor = state.floor - 1
    state.stress = 0
    M.new_floor(state, generate_fn, rows, cols)
    return "next"
end

OfficeLogic = M
return M
