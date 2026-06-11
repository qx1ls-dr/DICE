-- Snake game for the DICE engine.
-- Everything is rendered via cpp_draw_rect / cpp_draw_text_* inside draw().
-- The engine cannot create/destroy objects at runtime, so the whole game
-- state lives in Lua tables and the scene contains zero game objects.

-- ----------------------------------------------------------------------------
-- Configuration
-- ----------------------------------------------------------------------------
local COLS, ROWS = 24, 16        -- field size in cells
local CELL       = 40            -- cell size in pixels
local OFF_X      = 160           -- field left offset  (1280-960)/2
local OFF_Y      = 70            -- field top offset (room for the score panel)

local FIELD_W = COLS * CELL      -- 960
local FIELD_H = ROWS * CELL      -- 640

-- Difficulty levels: step = seconds per move, wrap = pass through walls.
local LEVELS = {
    { name = "EASY",   step = 0.16, wrap = true,  food = 10 },
    { name = "MEDIUM", step = 0.11, wrap = false, food = 10 },
    { name = "HARD",   step = 0.07, wrap = false, food = 10 },
}

-- ----------------------------------------------------------------------------
-- State
-- ----------------------------------------------------------------------------
local level_idx = 2  -- default highlight in the menu (MEDIUM)
local snake          -- array of {c=, r=}, head first
local dir            -- current applied direction {dc=, dr=}
local next_dir       -- direction buffered from input
local food           -- {c=, r=}
local score          -- current score
local best = 0       -- best score across restarts (single session)
local state = "menu" -- "menu" | "play" | "pause" | "over" | "win"
local timer = 0      -- step accumulator

-- ----------------------------------------------------------------------------
-- Helpers
-- ----------------------------------------------------------------------------
local function occupied(c, r)
    for i = 1, #snake do
        if snake[i].c == c and snake[i].r == r then
            return true
        end
    end
    return false
end

local function spawn_food()
    -- Collect every free cell, then pick one at random.
    local free = {}
    for c = 0, COLS - 1 do
        for r = 0, ROWS - 1 do
            if not occupied(c, r) then
                free[#free + 1] = { c = c, r = r }
            end
        end
    end
    if #free == 0 then
        return false               -- board full -> caller declares win
    end
    food = free[cpp_rand(1, #free)]
    return true
end

-- Start a fresh game on the given difficulty.
local function start(idx)
    level_idx = idx
    snake = {
        { c = 12, r = 8 },
        { c = 11, r = 8 },
        { c = 10, r = 8 },
    }
    dir      = { dc = 1, dr = 0 }   -- moving right
    next_dir = { dc = 1, dr = 0 }
    score    = 0
    state    = "play"
    timer    = 0
    spawn_food()
end

-- Buffer a direction change, forbidding a 180° reversal.
local function set_dir(dc, dr)
    if state ~= "play" then return end
    if dc == -dir.dc and dr == -dir.dr then return end
    next_dir = { dc = dc, dr = dr }
end

local function step()
    local level = LEVELS[level_idx]
    dir = next_dir
    local head = snake[1]
    local nc = head.c + dir.dc
    local nr = head.r + dir.dr

    if level.wrap then
        -- Pass through walls: teleport to the opposite side.
        nc = (nc + COLS) % COLS
        nr = (nr + ROWS) % ROWS
    elseif nc < 0 or nc >= COLS or nr < 0 or nr >= ROWS then
        state = "over"
        return
    end

    local will_eat = (nc == food.c and nr == food.r)

    -- Self collision. When not eating, the tail vacates its cell this step,
    -- so a hit on the very last segment is allowed.
    local limit = will_eat and #snake or (#snake - 1)
    for i = 1, limit do
        if snake[i].c == nc and snake[i].r == nr then
            state = "over"
            return
        end
    end

    table.insert(snake, 1, { c = nc, r = nr })

    if will_eat then
        score = score + level.food
        if score > best then best = score end
        if not spawn_food() then
            state = "win"
        end
    else
        table.remove(snake)
    end
end

-- ----------------------------------------------------------------------------
-- Input
-- ----------------------------------------------------------------------------
engine.onKey("Up",    function() set_dir(0, -1) end)
engine.onKey("Down",  function() set_dir(0,  1) end)
engine.onKey("Left",  function() set_dir(-1, 0) end)
engine.onKey("Right", function() set_dir(1,  0) end)
engine.onKey("W",     function() set_dir(0, -1) end)
engine.onKey("S",     function() set_dir(0,  1) end)
engine.onKey("A",     function() set_dir(-1, 0) end)
engine.onKey("D",     function() set_dir(1,  0) end)

-- Level selection / new game. Allowed from the menu and after a round ends,
-- so it never restarts an in-progress game by accident.
local function pick_level(idx)
    if state == "menu" or state == "over" or state == "win" then
        start(idx)
    end
end
engine.onKey("1", function() pick_level(1) end)
engine.onKey("2", function() pick_level(2) end)
engine.onKey("3", function() pick_level(3) end)

engine.onKey("Space", function()
    if state == "play" then
        state = "pause"
    elseif state == "pause" then
        state = "play"
    end
end)

engine.onKey("R", function()
    if state == "over" or state == "win" then
        start(level_idx)            -- restart the same difficulty
    end
end)

engine.onKey("M", function()
    if state ~= "play" then
        state = "menu"              -- back to the difficulty menu
    end
end)

-- ----------------------------------------------------------------------------
-- Frame hooks
-- ----------------------------------------------------------------------------
function update(dt)
    if state ~= "play" or snake == nil then return end

    local interval = LEVELS[level_idx].step
    timer = timer + dt
    while timer >= interval and state == "play" do
        timer = timer - interval
        step()
    end
end

-- Draw a cell given its grid coordinates.
local function draw_cell(c, r, red, green, blue, inset)
    inset = inset or 0
    cpp_draw_rect(
        OFF_X + c * CELL + inset,
        OFF_Y + r * CELL + inset,
        CELL - inset * 2,
        CELL - inset * 2,
        red, green, blue, 255
    )
end

local function draw_menu()
    cpp_draw_rect(0, 0, 1280, 720, 18, 18, 26, 255)
    cpp_draw_text_center("SNAKE", 640, 110, 80, 120, 230, 120)
    cpp_draw_text_center("Select difficulty", 640, 220, 32, 220, 220, 220)

    cpp_draw_text_center("1   -   EASY    (slow,   walls wrap around)", 640, 320, 30, 150, 230, 150)
    cpp_draw_text_center("2   -   MEDIUM  (normal, walls kill)",        640, 380, 30, 230, 220, 120)
    cpp_draw_text_center("3   -   HARD    (fast,   walls kill)",        640, 440, 30, 230, 120, 120)

    cpp_draw_text_center("Move: Arrows / WASD     Pause: Space", 640, 560, 24, 170, 170, 180)
    cpp_draw_text_center("Best this session: " .. best, 640, 610, 24, 200, 200, 90)
end

local function draw_game()
    local level = LEVELS[level_idx]

    -- Top score panel.
    cpp_draw_rect(0, 0, 1280, OFF_Y, 20, 20, 30, 255)
    cpp_draw_text_left("Score: " .. score, 30, 20, 30, 80, 220, 120)
    cpp_draw_text_center(level.name, 640, 20, 30, 230, 230, 230)
    cpp_draw_text_right("Best: " .. best, 1250, 20, 30, 200, 200, 90)

    -- Field background and border.
    cpp_draw_rect(OFF_X - 4, OFF_Y - 4, FIELD_W + 8, FIELD_H + 8, 90, 90, 110, 255)
    cpp_draw_rect(OFF_X, OFF_Y, FIELD_W, FIELD_H, 24, 24, 32, 255)

    -- Food.
    draw_cell(food.c, food.r, 230, 70, 70, 4)

    -- Snake body (head brighter than the rest).
    for i = #snake, 1, -1 do
        local seg = snake[i]
        if i == 1 then
            draw_cell(seg.c, seg.r, 120, 230, 120, 2)
        else
            draw_cell(seg.c, seg.r, 70, 170, 90, 3)
        end
    end

    -- Overlays.
    if state == "pause" then
        cpp_draw_rect(OFF_X, OFF_Y, FIELD_W, FIELD_H, 0, 0, 0, 150)
        cpp_draw_text_center("PAUSED", 640, 340, 64, 255, 255, 255)
        cpp_draw_text_center("Space - continue     M - menu", 640, 420, 26, 200, 200, 200)
    elseif state == "over" then
        cpp_draw_rect(OFF_X, OFF_Y, FIELD_W, FIELD_H, 0, 0, 0, 160)
        cpp_draw_text_center("GAME OVER", 640, 320, 64, 255, 90, 90)
        cpp_draw_text_center("Score: " .. score, 640, 390, 30, 230, 230, 230)
        cpp_draw_text_center("R - restart     M - menu     1/2/3 - new game", 640, 440, 24, 200, 200, 200)
    elseif state == "win" then
        cpp_draw_rect(OFF_X, OFF_Y, FIELD_W, FIELD_H, 0, 0, 0, 160)
        cpp_draw_text_center("YOU WIN!", 640, 320, 64, 120, 230, 255)
        cpp_draw_text_center("Score: " .. score, 640, 390, 30, 230, 230, 230)
        cpp_draw_text_center("R - restart     M - menu     1/2/3 - new game", 640, 440, 24, 200, 200, 200)
    end
end

function draw()
    if state == "menu" or snake == nil then
        draw_menu()
    else
        draw_game()
    end
end
