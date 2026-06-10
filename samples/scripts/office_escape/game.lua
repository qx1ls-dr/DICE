-- Office Escape — imperative shell: engine glue, state machine, rendering.
-- Pure model: OfficeGen (gen.lua) + OfficeLogic (logic.lua), loaded before this.

-- ── CONFIG ───────────────────────────────────────────────────────────────────
local GRID_W, GRID_H = 48, 32
local TILE = 48
local WORLD_W, WORLD_H = GRID_W * TILE, GRID_H * TILE   -- 2304 x 1536
local VIEW_W, VIEW_H = 1280, 720
local SLIDE_SPEED = 12        -- player slide smoothing (higher = snappier)
local CAM_SPEED = 8           -- camera follow smoothing
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
local render_cx, render_cy = 0, 0   -- interpolated player centre, world px
local cam_x, cam_y = 0, 0           -- camera top-left corner, world px

-- ── HELPERS ──────────────────────────────────────────────────────────────────
local function tile_center(r, c)
    return (c - 1) * TILE + TILE / 2, (r - 1) * TILE + TILE / 2
end

-- Camera goal: player centred, clamped to the world bounds.
local function camera_target()
    local tx = math.max(0, math.min(WORLD_W - VIEW_W, render_cx - VIEW_W / 2))
    local ty = math.max(0, math.min(WORLD_H - VIEW_H, render_cy - VIEW_H / 2))
    return tx, ty
end

local function snap_player_render()
    render_cx, render_cy = tile_center(state.player_r, state.player_c)
    cam_x, cam_y = camera_target()
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
    rect(0, 0, VIEW_W, VIEW_H, C_BG)

    -- Visible tile range only (the world is ~3.4x the viewport area).
    local c0 = math.max(1, math.floor(cam_x / TILE) + 1)
    local c1 = math.min(GRID_W, math.ceil((cam_x + VIEW_W) / TILE))
    local r0 = math.max(1, math.floor(cam_y / TILE) + 1)
    local r1 = math.min(GRID_H, math.ceil((cam_y + VIEW_H) / TILE))

    for r = r0, r1 do
        for c = c0, c1 do
            local x = (c - 1) * TILE - cam_x
            local y = (r - 1) * TILE - cam_y
            local col = (state.grid[r][c] == "wall") and C_WALL or C_FLOOR
            rect(x + 2, y + 2, TILE - 4, TILE - 4, col)
        end
    end

    -- elevator tile
    local er, ec = state.elevator.r, state.elevator.c
    if er >= r0 and er <= r1 and ec >= c0 and ec <= c1 then
        local ex = (ec - 1) * TILE - cam_x
        local ey = (er - 1) * TILE - cam_y
        rect(ex + 2, ey + 2, TILE - 4, TILE - 4, C_EXIT)
        text_center(state.floor == 1 and "OUT" or "v",
            ex + TILE / 2, ey + TILE / 2, 18, C_FLOOR)
    end

    -- coffee (gentle pulse)
    local pulse = 1.0 + 0.15 * math.sin(pulse_t * 4)
    for _, it in ipairs(state.items) do
        if it.r >= r0 and it.r <= r1 and it.c >= c0 and it.c <= c1 then
            local cx = (it.c - 1) * TILE - cam_x + TILE / 2
            local cy = (it.r - 1) * TILE - cam_y + TILE / 2
            local s = TILE * 0.30 * pulse
            rect(cx - s / 2, cy - s / 2, s, s, C_COFFEE)
        end
    end

    -- player (interpolated position)
    local ps = TILE * 0.60
    rect(render_cx - cam_x - ps / 2, render_cy - cam_y - ps / 2, ps, ps, C_PLAYER)
end

local function stress_color()
    if state.stress < 50 then return C_S_LOW
    elseif state.stress < 80 then return C_S_MID
    else return C_S_HIGH end
end

local function draw_hud()
    rect(0, 0, VIEW_W, 44, C_BG, 235)
    cpp_draw_text_left("FLOOR " .. state.floor, 24, 22, 22,
        C_TEXT[1], C_TEXT[2], C_TEXT[3])

    local bw, bh, by = 320, 20, 12
    local bx = (VIEW_W - bw) / 2
    rect(bx, by, bw, bh, C_TRACK)
    local fill = (state.stress / 100) * bw
    if fill > 0 then rect(bx, by, fill, bh, stress_color()) end
    text_center("STRESS " .. math.floor(state.stress) .. "%",
        640, by + bh / 2, 14, C_TEXT)

    cpp_draw_text_right("COFFEE " .. state.coffee, VIEW_W - 24, 22, 22,
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

        local gx, gy = camera_target()
        local ck = math.min(1, dt * CAM_SPEED)
        cam_x = cam_x + (gx - cam_x) * ck
        cam_y = cam_y + (gy - cam_y) * ck
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
        rect(0, VIEW_H - 32, VIEW_W, 32, C_BG, 235)
        text_center("WASD / Arrows - move       R - restart", 640, VIEW_H - 16, 16, C_MUTED)
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
-- No math.randomseed here: the engine has no `os` (seed was always 0 — same
-- map every launch). The generator uses cpp_rand, seeded on the C++ side.