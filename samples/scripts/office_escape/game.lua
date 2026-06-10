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
    local off_x, off_y = 50, 100
    for r = 1, grid_h do
        for c = 1, grid_w do
            local x, y = off_x + (c-1)*tile_size, off_y + (r-1)*tile_size
            if grid[r][c] == "wall" then
                cpp_draw_rect(x, y, tile_size-2, tile_size-2, 80, 80, 80, 255)
            else
                cpp_draw_rect(x, y, tile_size-2, tile_size-2, 200, 200, 200, 255)
            end
            
            if r == elevator.r and c == elevator.c then
                cpp_draw_text_center("E", x + tile_size/2, y + tile_size/2, 24, 50, 200, 50)
            end
        end
    end
    
    for _, item in ipairs(items) do
        local x, y = off_x + (item.c-1)*tile_size, off_y + (item.r-1)*tile_size
        cpp_draw_text_center("C", x + tile_size/2, y + tile_size/2, 24, 200, 50, 50)
    end
    
    local px, py = off_x + (player_c-1)*tile_size, off_y + (player_r-1)*tile_size
    cpp_draw_text_center("P", px + tile_size/2, py + tile_size/2, 32, 50, 50, 255)
    
    hud.draw()
end

engine.onKey("W", function() move(-1, 0) end)
engine.onKey("A", function() move(0, -1) end)
engine.onKey("S", function() move(1, 0) end)
engine.onKey("D", function() move(0, 1) end)
engine.onKey("Space", function() hud.addStress(5) end)

init()
