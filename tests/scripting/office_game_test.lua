-- Mock engine and other globals
engine = {
    onKey = function() end,
    reloadScene = function() engine.reloaded = true end,
    reloaded = false
}
hud = {
    stress = 50,
    addStress = function(v) hud.stress = hud.stress + v end,
    draw = function() end,
    getStress = function() return hud.stress end
}
-- We need to mock the require for hud to return our mock
package.loaded["scripts.office_escape.hud"] = hud

-- Mock some engine functions that might be called
function cpp_draw_rect() end
function cpp_draw_text_left() end

local game_file = "/home/xxrq1/Документы/work/DICE/samples/scripts/office_escape/game.lua"
local game_func = loadfile(game_file)

-- Minimal game script requires some globals to exist
init = function() end
draw = function() end
game_func() -- execute the script to define functions

function test_pickup()
    -- Initialize game state manually
    _G.items = {{type="coffee", r=5, c=5}}
    _G.player_r, _G.player_c = 1, 1
    
    _G.checkPickup(5, 5)
    
    assert(#_G.items == 0, "Item should be removed after pickup")
    assert(hud.getStress() < 50, "Stress should be reduced after picking up coffee")
end

function test_collision()
    -- Mock grid with a wall at 1,2
    _G.grid = {}
    for r=1,10 do _G.grid[r] = {} for c=1,15 do _G.grid[r][c] = "floor" end end
    _G.grid[1][2] = "wall"
    
    _G.player_r, _G.player_c = 1, 1
    _G.move(0, 1) -- Try to move into the wall
    
    assert(_G.player_r == 1 and _G.player_c == 1, "Player should not move into a wall")
end

function test_win_condition()
    _G.grid = {}
    for r=1,10 do _G.grid[r] = {} for c=1,15 do _G.grid[r][c] = "floor" end end
    _G.elevator = {r=1, c=2}
    engine.reloaded = false
    
    _G.player_r, _G.player_c = 1, 1
    _G.move(0, 1) -- Move into elevator
    
    assert(engine.reloaded == true, "Scene should reload on win")
end

test_pickup()
test_collision()
test_win_condition()
print("Office Game Test: PASS")
