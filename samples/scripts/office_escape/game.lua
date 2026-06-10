local gen = require("scripts.office_escape.gen")
local hud = require("scripts.office_escape.hud")
local grid_w, grid_h = 15, 10
local tile_size = 64

player_r, player_c = 1, 1
items = {}
grid = {}
elevator = {r = 1, c = 1}

function init()
    math.randomseed(os.time())
    local g, generatedItems, elev = gen.generate(grid_h, grid_w)
    grid = g
    items = generatedItems
    elevator = elev
    -- Find a floor tile for start position
    for r = 1, grid_h do
        for c = 1, grid_w do
            if grid[r][c] == "floor" then
                player_r, player_c = r, c
                goto found
            end
        end
    end
    ::found::
    print("Office Escape Initialized")
end

function checkPickup(r, c)
    for i = #items, 1, -1 do
        local item = items[i]
        if item.r == r and item.c == c then
            if item.type == "coffee" then
                hud.addStress(-20)
            end
            table.remove(items, i)
            print("Picked up: " .. item.type)
        end
    end
end

function move(dr, dc)
    local nr, nc = player_r + dr, player_c + dc
    -- Bounds check
    if nr >= 1 and nr <= grid_h and nc >= 1 and nc <= grid_w then
        -- Collision check
        if grid[nr][nc] == "wall" then
            print("Ouch! A wall.")
            return
        end
        
        player_r, player_c = nr, nc
        checkPickup(nr, nc)
        hud.addStress(1) -- Stress per step
        
        -- Win condition check
        if nr == elevator.r and nc == elevator.c then
            print("YOU ESCAPED!")
            engine.reloadScene() -- Reload to new floor
        end
    end
end

function draw()
    hud.draw()
end

engine.onKey("W", function() move(-1, 0) end)
engine.onKey("A", function() move(0, -1) end)
engine.onKey("S", function() move(1, 0) end)
engine.onKey("D", function() move(0, 1) end)
engine.onKey("Space", function() hud.addStress(5) end)

init()
