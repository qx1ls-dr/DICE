local gen = require("scripts.office_escape.gen")
local grid_w, grid_h = 15, 10
local tile_size = 64

function init()
    math.randomseed(os.time())
    local grid = gen.generate(grid_h, grid_w)
    for r = 1, grid_h do
        for c = 1, grid_w do
            local type = grid[r][c]
            local id = "tile_" .. r .. "_" .. c
            -- Note: In this task we just verify initialization. 
            -- Entity creation logic will be added in a later task.
        end
    end
    print("Office Escape Initialized")
end

engine.onKey("W", function() print("Move Up") end)
engine.onKey("A", function() print("Move Left") end)
engine.onKey("S", function() print("Move Down") end)
engine.onKey("D", function() print("Move Right") end)
init()
