-- ============================================================
--  LOGIC
-- ============================================================
local logic = {}
logic.cols = 0
logic.rows = 0
logic.mines = 0
logic.grid = {}
logic.first_move = true

function logic.init(cols, rows, mines)
    logic.cols = cols
    logic.rows = rows
    logic.mines = mines
    logic.grid = {}
    logic.first_move = true
    for c = 0, cols - 1 do
        logic.grid[c] = {}
        for r = 0, rows - 1 do
            logic.grid[c][r] = { is_mine = false, neighbor_count = 0, state = 0 }
        end
    end
end

function logic.toggle_flag(c, r)
    local cell = logic.grid[c][r]
    if cell.state == 0 then cell.state = 2
    elseif cell.state == 2 then cell.state = 0 end
end

function logic.generate_mines(start_c, start_r)
    local placed = 0
    while placed < logic.mines do
        local c = cpp_rand(0, logic.cols - 1)
        local r = cpp_rand(0, logic.rows - 1)
        local in_safe = math.abs(c - start_c) <= 1 and math.abs(r - start_r) <= 1
        if not logic.grid[c][r].is_mine and not in_safe then
            logic.grid[c][r].is_mine = true
            placed = placed + 1
        end
    end
    logic.calc_neighbors()
end

function logic.calc_neighbors()
    for c = 0, logic.cols - 1 do
        for r = 0, logic.rows - 1 do
            if not logic.grid[c][r].is_mine then
                local n = 0
                for dc = -1, 1 do
                    for dr = -1, 1 do
                        local nc, nr = c + dc, r + dr
                        if nc >= 0 and nc < logic.cols and nr >= 0 and nr < logic.rows then
                            if logic.grid[nc][nr].is_mine then n = n + 1 end
                        end
                    end
                end
                logic.grid[c][r].neighbor_count = n
            end
        end
    end
end

function logic.open_cell(c, r)
    if logic.first_move then
        logic.generate_mines(c, r)
        logic.first_move = false
    end
    local cell = logic.grid[c][r]
    if cell.state ~= 0 then return "ok" end
    if cell.is_mine then cell.state = 1; return "lose" end
    local queue = { {c, r} }
    cell.state = 1
    local head = 1
    while head <= #queue do
        local cc, cr = queue[head][1], queue[head][2]
        head = head + 1
        if logic.grid[cc][cr].neighbor_count == 0 then
            for dc = -1, 1 do
                for dr = -1, 1 do
                    local nc, nr = cc + dc, cr + dr
                    if nc >= 0 and nc < logic.cols and nr >= 0 and nr < logic.rows then
                        local nb = logic.grid[nc][nr]
                        if nb.state == 0 and not nb.is_mine then
                            nb.state = 1
                            table.insert(queue, { nc, nr })
                        end
                    end
                end
            end
        end
    end
    return "ok"
end

function logic.check_win()
    for c = 0, logic.cols - 1 do
        for r = 0, logic.rows - 1 do
            local cell = logic.grid[c][r]
            if not cell.is_mine and cell.state ~= 1 then return false end
        end
    end
    return true
end

function logic.count_flags()
    local n = 0
    for c = 0, logic.cols - 1 do
        for r = 0, logic.rows - 1 do
            if logic.grid[c][r].state == 2 then n = n + 1 end
        end
    end
    return n
end

-- ============================================================
--  GAME
-- ============================================================
local CELL  = 32
local MAX_C = 30
local MAX_R = 16

-- Header geometry
local TITLE_H  = 30   -- navy title bar
local ROW1_Y   = 30   -- LCD + smiley row top
local ROW1_H   = 64   -- height of row 1
local ROW2_Y   = 94   -- difficulty buttons row top
local ROW2_H   = 38
local HEADER_H = 132  -- total header height

-- Smiley button geometry. The face itself is the "smiley" scene object, shown
-- through a gap left in the row-1 panel; draw() only frames it with a bevel.
local SMILEY_W = 48
local SMILEY_H = 44
local SMILEY_X = math.floor((1280 - SMILEY_W) / 2)  -- 616
local SMILEY_Y = ROW1_Y + 10                        -- 40

local TEX = {
    closed   = "assets/minesweeper/unknown_1_64x64.png",
    flag     = "assets/minesweeper/flag_1_64x64.png",
    empty    = "assets/minesweeper/empty_64x64.png",
    bomb     = "assets/minesweeper/bomb_64x64.png",
    exploded = "assets/minesweeper/bomb_exploded_64x64.png",
    num = {
        "assets/minesweeper/1_64x64.png", "assets/minesweeper/2_64x64.png",
        "assets/minesweeper/3_64x64.png", "assets/minesweeper/4_64x64.png",
        "assets/minesweeper/5_64x64.png", "assets/minesweeper/6_64x64.png",
        "assets/minesweeper/7_64x64.png", "assets/minesweeper/8_64x64.png",
    }
}

local flag_mode       = false
local game_over       = false
local game_won        = false
local clicked_mine_id = nil
local diff            = { cols = 9, rows = 9, mines = 10 }
local diff_name       = "easy"   -- for active button highlight
local started         = false
local timer_sec       = 0
local timer_running   = false

-- Smiley face state (drives the "smiley" scene object's texture)
local SMILEY_TEX = {
    play  = "assets/minesweeper/smiley_play.png",
    press = "assets/minesweeper/smiley_press.png",
    win   = "assets/minesweeper/smiley_win.png",
    lose  = "assets/minesweeper/smiley_lose.png",
}
local smiley_cur  = nil
local press_timer = 0    -- seconds left to show the "pressed" face
local function set_smiley(face)
    if face ~= smiley_cur then
        cpp_set_obj_texture("smiley", SMILEY_TEX[face])
        smiley_cur = face
    end
end

-- ---- Retro draw helpers ----

local function draw_bevel_out(x, y, w, h)
    cpp_draw_rect(x,       y,       w,   2,   255, 255, 255, 255)
    cpp_draw_rect(x,       y,       2,   h,   255, 255, 255, 255)
    cpp_draw_rect(x,       y+h-2,   w,   2,   128, 128, 128, 255)
    cpp_draw_rect(x+w-2,   y,       2,   h,   128, 128, 128, 255)
end

local function draw_bevel_in(x, y, w, h)
    cpp_draw_rect(x,       y,       w,   2,   128, 128, 128, 255)
    cpp_draw_rect(x,       y,       2,   h,   128, 128, 128, 255)
    cpp_draw_rect(x,       y+h-2,   w,   2,   255, 255, 255, 255)
    cpp_draw_rect(x+w-2,   y,       2,   h,   255, 255, 255, 255)
end

local TEXT_SIZE = 20  -- base font size — large enough to avoid SFML antialiasing halo

local function draw_lcd(x, y, w, h, value)
    local txt = string.format("%03d", math.min(math.max(value, 0), 999))
    cpp_draw_rect(x, y, w, h, 0, 0, 0, 255)
    draw_bevel_in(x, y, w, h)
    -- cpp_draw_text_center anchors y at the text's visual center → pass the box center
    cpp_draw_text_center(txt, x + w/2, y + math.floor(h / 2), 28, 255, 0, 0)
end

local function draw_diff_btn(label, x, y, w, h, active)
    cpp_draw_rect(x, y, w, h, 192, 192, 192, 255)
    if active then draw_bevel_in(x, y, w, h) else draw_bevel_out(x, y, w, h) end
    cpp_draw_text_center(label, x + w/2, y + math.floor(h / 2), TEXT_SIZE, 0, 0, 0)
end

-- ---- Grid helpers ----

local function grid_origin(cols, rows)
    local ox = math.floor((1280 - cols * CELL) / 2)
    local oy = HEADER_H + 24
    return ox, oy
end

local function init_game()
    logic.init(diff.cols, diff.rows, diff.mines)
    game_over = false; game_won = false; flag_mode = false
    clicked_mine_id = nil; timer_sec = 0; timer_running = false
    press_timer = 0; set_smiley("play")

    local ox, oy = grid_origin(diff.cols, diff.rows)
    for r = 0, MAX_R - 1 do
        for c = 0, MAX_C - 1 do
            local obj = engine.getObject("cell_" .. c .. "_" .. r)
            if obj then obj:setVisible(false); obj:setActive(false) end
        end
    end
    for r = 0, diff.rows - 1 do
        for c = 0, diff.cols - 1 do
            local id  = "cell_" .. c .. "_" .. r
            local obj = engine.getObject(id)
            if obj then
                obj:setPosition(ox + c*CELL + CELL/2, oy + r*CELL + CELL/2)
                obj:setVisible(true); obj:setActive(true)
                cpp_set_obj_texture(id, TEX.closed)
            end
        end
    end
end

local function cell_tex(id, cell)
    if cell.state == 0 then
        cpp_set_obj_texture(id, TEX.closed)
    elseif cell.state == 2 then
        cpp_set_obj_texture(id, TEX.flag)
    else
        if cell.is_mine then
            cpp_set_obj_texture(id, id == clicked_mine_id and TEX.exploded or TEX.bomb)
        elseif cell.neighbor_count == 0 then
            cpp_set_obj_texture(id, TEX.empty)
        else
            cpp_set_obj_texture(id, TEX.num[cell.neighbor_count])
        end
    end
end

local function refresh_board()
    for r = 0, diff.rows - 1 do
        for c = 0, diff.cols - 1 do
            cell_tex("cell_" .. c .. "_" .. r, logic.grid[c][r])
        end
    end
end

local function reveal_mines()
    for r = 0, diff.rows - 1 do
        for c = 0, diff.cols - 1 do
            if logic.grid[c][r].is_mine then logic.grid[c][r].state = 1 end
        end
    end
    refresh_board()
end

-- ---- Triggers ----

engine.trigger("restart_game", function()
    init_game()
end)

engine.trigger("set_easy", function()
    diff = { cols=9, rows=9, mines=10 }; diff_name = "easy"; init_game()
end)
engine.trigger("set_medium", function()
    diff = { cols=16, rows=16, mines=40 }; diff_name = "medium"; init_game()
end)
engine.trigger("set_hard", function()
    diff = { cols=30, rows=16, mines=99 }; diff_name = "hard"; init_game()
end)

engine.onKey("R", function() init_game() end)
engine.onKey("Space", function()
    if game_over or game_won then return end
    flag_mode = not flag_mode
end)

engine.trigger("cell_clicked", function(self)
    if game_over or game_won then return end
    local c = self:getCol()
    local r = self:getRow()

    if not timer_running and logic.first_move == false then
        -- already started
    elseif logic.first_move then
        -- will start on open
    end

    if flag_mode then
        if logic.grid[c][r].state ~= 1 then
            logic.toggle_flag(c, r)
            refresh_board()
        end
        return
    end

    local result = logic.open_cell(c, r)
    timer_running = true
    press_timer = 0.12   -- brief "pressed" face; win/lose below overrides it

    if result == "lose" then
        game_over = true; timer_running = false
        clicked_mine_id = self:getId()
        reveal_mines()
        return
    end
    if logic.check_win() then
        game_won = true; timer_running = false
    end
    refresh_board()
end)

-- ---- Frame hooks ----

function update(dt)
    if not started then started = true; init_game() end
    if timer_running then
        timer_sec = timer_sec + dt
    end

    -- Smiley face: lose/win take priority, else a brief "pressed" flash, else playing
    if game_over then
        set_smiley("lose")
    elseif game_won then
        set_smiley("win")
    elseif press_timer > 0 then
        press_timer = press_timer - dt
        set_smiley(press_timer > 0 and "press" or "play")
    else
        set_smiley("play")
    end
end

function draw()
    -- ---- Title bar (navy) ----
    cpp_draw_rect(0, 0, 1280, TITLE_H, 0, 0, 128, 255)
    cpp_draw_text_center("M I N E S W E E P E R", 640, math.floor(TITLE_H / 2), 18, 255, 255, 160)

    -- ---- Row 1 (grey panel) — leave a gap for the smiley object behind it ----
    cpp_draw_rect(0, ROW1_Y, SMILEY_X, ROW1_H, 192, 192, 192, 255)
    local rx = SMILEY_X + SMILEY_W
    cpp_draw_rect(rx, ROW1_Y, 1280 - rx, ROW1_H, 192, 192, 192, 255)
    cpp_draw_rect(0, ROW1_Y,           1280, 2, 128, 128, 128, 255)
    cpp_draw_rect(0, ROW1_Y+ROW1_H-2, 1280, 2, 255, 255, 255, 255)

    -- Mine counter LCD
    local mines_left = diff.mines - logic.count_flags()
    draw_lcd(20, ROW1_Y + 10, 96, 44, mines_left)

    -- Smiley button frame (the face is the "smiley" object showing through the gap)
    if game_won or game_over then
        draw_bevel_in(SMILEY_X, SMILEY_Y, SMILEY_W, SMILEY_H)
    else
        draw_bevel_out(SMILEY_X, SMILEY_Y, SMILEY_W, SMILEY_H)
    end

    -- Timer LCD
    local t = math.min(math.floor(timer_sec), 999)
    draw_lcd(1164, ROW1_Y + 10, 96, 44, t)

    -- ---- Row 2 (difficulty + mode) ----
    cpp_draw_rect(0, ROW2_Y, 1280, ROW2_H, 192, 192, 192, 255)
    cpp_draw_rect(0, ROW2_Y,           1280, 2, 128, 128, 128, 255)
    cpp_draw_rect(0, ROW2_Y+ROW2_H-2, 1280, 2, 255, 255, 255, 255)

    draw_diff_btn("Easy",   12,  ROW2_Y+5, 90, 28, diff_name == "easy")
    draw_diff_btn("Medium", 108, ROW2_Y+5, 90, 28, diff_name == "medium")
    draw_diff_btn("Hard",   204, ROW2_Y+5, 90, 28, diff_name == "hard")

    -- Status text — centered vertically in Row 2
    local ty = ROW2_Y + math.floor((ROW2_H - TEXT_SIZE) / 2)
    if game_won then
        cpp_draw_text_left("YOU WIN!  (R = restart)", 318, ty, TEXT_SIZE, 0, 100, 0)
    elseif game_over then
        cpp_draw_text_left("GAME OVER  (R = restart)", 318, ty, TEXT_SIZE, 160, 0, 0)
    else
        if flag_mode then
            cpp_draw_text_left("FLAG mode  |  Space = open", 318, ty, TEXT_SIZE, 0, 0, 0)
        else
            cpp_draw_text_left("OPEN mode  |  Space = flag", 318, ty, TEXT_SIZE, 0, 0, 0)
        end
    end

    -- ---- Grid border (light on dark) ----
    local ox, oy = grid_origin(diff.cols, diff.rows)
    local gw = diff.cols * CELL
    local gh = diff.rows * CELL
    cpp_draw_rect(ox-4, oy-4, gw+8, 4, 80, 80, 90, 255)
    cpp_draw_rect(ox-4, oy-4, 4, gh+8, 80, 80, 90, 255)
    cpp_draw_rect(ox-4, oy+gh, gw+8, 4, 160, 160, 170, 255)
    cpp_draw_rect(ox+gw, oy-4, 4, gh+8, 160, 160, 170, 255)
end
