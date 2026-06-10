local logic = require("scripts.office_escape.logic")

-- Deterministic generator: all-floor grid, one coffee at (1,2),
-- elevator at the far corner, start at (1,1).
local function fake_gen(rows, cols)
    local grid = {}
    for r = 1, rows do grid[r] = {} for c = 1, cols do grid[r][c] = "floor" end end
    local items = {{type = "coffee", r = 1, c = 2}}
    local elevator = {r = rows, c = cols}
    local start = {r = 1, c = 1}
    return grid, items, elevator, start
end

local function fresh()
    local s = {}
    logic.new_game(s, fake_gen, 5, 5)
    return s
end

function test_new_game()
    local s = fresh()
    assert(s.floor == logic.MAX_FLOOR, "floor should start at MAX_FLOOR")
    assert(s.stress == 0 and s.coffee == 0 and s.steps == 0, "counters reset")
    assert(s.floors_cleared == 0, "floors_cleared reset")
    assert(s.player_r == 1 and s.player_c == 1, "player at start")
end

function test_add_stress_clamp()
    local s = fresh()
    local burn = logic.add_stress(s, 50)
    assert(s.stress == 50 and burn == false, "stress 50, no burnout")
    burn = logic.add_stress(s, 100)
    assert(s.stress == 100 and burn == true, "stress clamps to 100 and burns out")
    logic.add_stress(s, -250)
    assert(s.stress == 0, "stress clamps to 0")
end

function test_pickup()
    local s = fresh()
    s.stress = 50
    local got = logic.pickup(s, 1, 2)
    assert(got == true, "coffee picked up")
    assert(s.stress == 50 - logic.COFFEE_RELIEF, "stress reduced by relief")
    assert(s.coffee == 1, "coffee count incremented")
    assert(#s.items == 0, "item removed")
    assert(logic.pickup(s, 1, 2) == false, "no coffee left at tile")
end

function test_move_blocked_by_wall()
    local s = fresh()
    s.grid[1][2] = "wall"
    local res = logic.try_move(s, 0, 1)
    assert(res == "blocked", "move into wall blocked")
    assert(s.player_c == 1 and s.steps == 0, "no movement, no step counted")
end

function test_move_blocked_by_border()
    local s = fresh()
    local res = logic.try_move(s, -1, 0)
    assert(res == "blocked", "move off the board blocked")
    assert(s.player_r == 1, "player stays put")
end

function test_move_step()
    local s = fresh()
    s.items = {}
    local res = logic.try_move(s, 1, 0)
    assert(res == "step", "normal step reported")
    assert(s.player_r == 2 and s.steps == 1, "player advanced, step counted")
    assert(s.stress == logic.STRESS_PER_STEP, "stress added per step")
end

function test_move_elevator()
    local s = fresh()
    s.items = {}
    s.player_r, s.player_c = 5, 4   -- adjacent to elevator at (5,5)
    local res = logic.try_move(s, 0, 1)
    assert(res == "elevator", "stepping onto elevator reports elevator")
end

function test_move_burnout()
    local s = fresh()
    s.items = {}
    s.stress = 99
    local res = logic.try_move(s, 1, 0)  -- +STRESS_PER_STEP -> clamps to 100
    assert(res == "burnout", "step into max stress reports burnout")
    assert(s.stress == 100, "stress at max")
end

function test_descend_next()
    local s = fresh()
    s.floor = 3
    local outcome = logic.descend(s, fake_gen, 5, 5)
    assert(outcome == "next", "descend from floor 3 continues")
    assert(s.floor == 2, "floor decremented")
    assert(s.floors_cleared == 1, "floor counted as cleared")
    assert(s.player_r == 1 and s.player_c == 1, "player placed at new start")
end

function test_descend_win()
    local s = fresh()
    s.floor = 1
    local outcome = logic.descend(s, fake_gen, 5, 5)
    assert(outcome == "win", "descend from floor 1 wins")
    assert(s.floors_cleared == 1, "escape counted")
end

test_new_game()
test_add_stress_clamp()
test_pickup()
test_move_blocked_by_wall()
test_move_blocked_by_border()
test_move_step()
test_move_elevator()
test_move_burnout()
test_descend_next()
test_descend_win()
print("Office Logic Test: PASS")
