-- Mock engine and other globals
engine = {
    onKey = function() end
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

function test_pickup()
    -- Initialize game state manually since init() calls gen.generate
    -- but we want to control items
    _G.items = {{type="coffee", r=5, c=5}}
    _G.player_r, _G.player_c = 1, 1
    
    -- Simulate movement to 5,5
    if _G.checkPickup then
        _G.checkPickup(5, 5)
    else
        error("checkPickup function not defined")
    end
    
    assert(#_G.items == 0, "Item should be removed after pickup")
    assert(hud:getStress() < 50, "Stress should be reduced after picking up coffee")
end

-- Minimal game script requires some globals to exist
init = function() end
draw = function() end
game_func() -- execute the script to define functions

test_pickup()
print("Task 4 Step 2: PASS")
