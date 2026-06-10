local gen = require("scripts.office_escape.gen")

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

test_generate_grid()
test_generate_items()
print("Office Gen Test: PASS")
