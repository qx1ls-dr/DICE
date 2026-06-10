local gen = require("scripts.office_escape.gen")

function test_generate_grid()
    local rows, cols = 10, 10
    local grid = gen.generate(rows, cols)
    assert(#grid == rows, "Grid should have " .. rows .. " rows")
    assert(#grid[1] == cols, "Grid should have " .. cols .. " cols")
end

test_generate_grid()
print("Task 1 Step 1: PASS")
