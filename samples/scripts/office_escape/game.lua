-- Office Escape — imperative shell: engine glue, state machine, rendering.
-- Pure model: OfficeGen (gen.lua) + OfficeLogic (logic.lua), loaded before this.

-- ── CONFIG ───────────────────────────────────────────────────────────────────
local GRID_W, GRID_H = 15, 10
local TILE = 60
local OFF_X = math.floor((1280 - GRID_W * TILE) / 2)   -- 190
local OFF_Y = 70
local SLIDE_SPEED = 12        -- player slide smoothing (higher = snappier)
local FLOOR_CARD_TIME = 1.0   -- seconds the "FLOOR n" card stays up

-- ── PALETTE (r,g,b) ──────────────────────────────────────────────────────────
local C_FLOOR  = {255, 255, 255}
local C_WALL   = {148, 163, 184}
local C_PLAYER = {59, 130, 246}
local C_COFFEE = {245, 158, 11}
local C_EXIT   = {16, 185, 129}
local C_TEXT   = {31, 41, 55}
local C_MUTED  = {100, 116, 139}
local C_TRACK  = {203, 213, 225}
local C_BG     = {226, 232, 240}
local C_S_LOW  = {16, 185, 129}
local C_S_MID  = {245, 158, 11}
local C_S_HIGH = {239, 68, 68}

-- ── STATE ────────────────────────────────────────────────────────────────────
local state = {
    floor = OfficeLogic.MAX_FLOOR,
    stress = 0, coffee = 0, steps = 0, floors_cleared = 0,
    grid = {}, items = {}, elevator = {r = 1, c = 1},
    player_r = 1, player_c = 1,
}
local phase = "TITLE"   -- TITLE | PLAYING | FLOOR_CARD | WIN | GAME_OVER
local card_t = 0
local pulse_t = 0
local render_cx, render_cy = 0, 0   -- interpolated player center, pixels

-- ── HELPERS ──────────────────────────────────────────────────────────────────
local function tile_center(r, c)
    return OFF_X + (c - 1) * TILE + TILE / 2,
           OFF_Y + (r - 1) * TILE + TILE / 2
end

local function snap_player_render()
    render_cx, render_cy = tile_center(state.player_r, state.player_c)
end

local function rect(x, y, w, h, col, a)
    cpp_draw_rect(x, y, w, h, col[1], col[2], col[3], a or 255)
end

local function text_center(s, x, y, size, col)
    cpp_draw_text_center(s, x, y, size, col[1], col[2], col[3])
end

-- ── GAME CONTROL ─────────────────────────────────────────────────────────────
local function start_game()
    OfficeLogic.new_game(state, OfficeGen.generate, GRID_H, GRID_W)
    phase = "PLAYING"
    snap_player_render()
end

local function do_move(dr, dc)
    if phase ~= "PLAYING" then return end
    local res = OfficeLogic.try_move(state, dr, dc)
    if res == "burnout" then
        phase = "GAME_OVER"
    elseif res == "elevator" then
        local outcome = OfficeLogic.descend(state, OfficeGen.generate, GRID_H, GRID_W)
        if outcome == "win" then
            phase = "WIN"
        else
            phase = "FLOOR_CARD"
            card_t = 0
            snap_player_render()   -- jump to the new floor's start, no slide
        end
    end
    -- "step"/"blocked": render slides toward the new position in update(dt)
end

-- ── RENDER: BOARD + HUD ──────────────────────────────────────────────────────
local function draw_board()
    for r = 1, GRID_H do
        for c = 1, GRID_W do
            local x = OFF_X + (c - 1) * TILE
            local y = OFF_Y + (r - 1) * TILE
            local col = (state.grid[r][c] == "wall") and C_WALL or C_FLOOR
            rect(x + 3, y + 3, TILE - 6, TILE - 6, col)
        end
    end

    -- elevator tile
    local ex = OFF_X + (state.elevator.c - 1) * TILE
    local ey = OFF_Y + (state.elevator.r - 1) * TILE
    rect(ex + 3, ey + 3, TILE - 6, TILE - 6, C_EXIT)
    text_center(state.floor == 1 and "OUT" or "v",
        ex + TILE / 2, ey + TILE / 2, 22, C_FLOOR)

    -- coffee (gentle pulse)
    local pulse = 1.0 + 0.15 * math.sin(pulse_t * 4)
    for _, it in ipairs(state.items) do
        local cx = OFF_X + (it.c - 1) * TILE + TILE / 2
        local cy = OFF_Y + (it.r - 1) * TILE + TILE / 2
        local s = TILE * 0.30 * pulse
        rect(cx - s / 2, cy - s / 2, s, s, C_COFFEE)
    end

    -- player (interpolated position)
    local ps = TILE * 0.60
    rect(render_cx - ps / 2, render_cy - ps / 2, ps, ps, C_PLAYER)
end

local function stress_color()
    if state.stress < 50 then return C_S_LOW
    elseif state.stress < 80 then return C_S_MID
    else return C_S_HIGH end
end

local function draw_hud()
    cpp_draw_text_left("FLOOR " .. state.floor, OFF_X, 22, 22,
        C_TEXT[1], C_TEXT[2], C_TEXT[3])

    local bw, bh, by = 320, 20, 20
    local bx = (1280 - bw) / 2
    rect(bx, by, bw, bh, C_TRACK)
    local fill = (state.stress / 100) * bw
    if fill > 0 then rect(bx, by, fill, bh, stress_color()) end
    text_center("STRESS " .. math.floor(state.stress) .. "%",
        640, by + bh / 2, 14, C_TEXT)

    cpp_draw_text_right("COFFEE " .. state.coffee, OFF_X + GRID_W * TILE, 22, 22,
        C_TEXT[1], C_TEXT[2], C_TEXT[3])
end

-- ── RENDER: SCREENS ──────────────────────────────────────────────────────────
local function draw_title()
    rect(0, 0, 1280, 720, C_BG, 255)
    text_center("OFFICE ESCAPE", 640, 230, 64, C_TEXT)
    text_center("Escape the 5-floor tower before you burn out", 640, 315, 22, C_MUTED)
    text_center("Press ENTER to start", 640, 415, 28, C_PLAYER)
    text_center("WASD / Arrows  -  move        Coffee lowers stress", 640, 510, 18, C_MUTED)
end

local function draw_end(title_text, title_col)
    rect(0, 0, 1280, 720, C_BG, 255)
    text_center(title_text, 640, 230, 56, title_col)
    text_center("Floors cleared:  " .. state.floors_cleared, 640, 330, 24, C_TEXT)
    text_center("Coffee drunk:  " .. state.coffee, 640, 372, 24, C_TEXT)
    text_center("Steps taken:  " .. state.steps, 640, 414, 24, C_TEXT)
    text_center("Press ENTER to play again", 640, 505, 24, C_PLAYER)
end

local function draw_floor_card()
    rect(0, 280, 1280, 160, C_BG, 225)
    text_center("FLOOR " .. state.floor, 640, 350, 56, C_TEXT)
end

-- ── ENGINE HOOKS ─────────────────────────────────────────────────────────────
function update(dt)
    pulse_t = (pulse_t + dt) % (2 * math.pi)
    if phase == "FLOOR_CARD" then
        card_t = card_t + dt
        if card_t >= FLOOR_CARD_TIME then phase = "PLAYING" end
    end
    if phase == "PLAYING" or phase == "FLOOR_CARD" then
        local tx, ty = tile_center(state.player_r, state.player_c)
        local k = math.min(1, dt * SLIDE_SPEED)
        render_cx = render_cx + (tx - render_cx) * k
        render_cy = render_cy + (ty - render_cy) * k
    end
end

function draw()
    if phase == "TITLE" then
        draw_title()
    elseif phase == "WIN" then
        draw_end("YOU ESCAPED!", C_EXIT)
    elseif phase == "GAME_OVER" then
        draw_end("BURNOUT", C_S_HIGH)
    else
        draw_board()
        draw_hud()
        text_center("WASD / Arrows - move       R - restart", 640, 700, 16, C_MUTED)
        if phase == "FLOOR_CARD" then draw_floor_card() end
    end
end

-- ── INPUT ────────────────────────────────────────────────────────────────────
engine.onKey("W", function() do_move(-1, 0) end)
engine.onKey("S", function() do_move(1, 0) end)
engine.onKey("A", function() do_move(0, -1) end)
engine.onKey("D", function() do_move(0, 1) end)
engine.onKey("Up",    function() do_move(-1, 0) end)
engine.onKey("Down",  function() do_move(1, 0) end)
engine.onKey("Left",  function() do_move(0, -1) end)
engine.onKey("Right", function() do_move(0, 1) end)
engine.onKey("Enter", function()
    if phase == "TITLE" or phase == "WIN" or phase == "GAME_OVER" then
        start_game()
    end
end)
engine.onKey("R", function() start_game() end)

-- ── BOOT ─────────────────────────────────────────────────────────────────────
-- Start on the TITLE screen; the board is generated on start_game().
math.randomseed(os and os.time() or 0)
