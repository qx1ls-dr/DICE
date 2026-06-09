-- scripts/kosti.lua
-- Игра в кости — одиночная и сетевая (хост-авторитативная модель)

-- Разрешаем триггеры от клиента
network_allow_event("roll_dice")
network_allow_event("end_turn")

local myPlayer = get_my_player()  -- 1=хост, 2=клиент, 0=одиночная

game = {
    currentPlayer = 1,
    scores        = {0, 0},
    diceRoll      = {0, 0},
    hasRolled     = false,
    gameOver      = false,
    winner        = 0,
    targetScore   = 21
}

-- ===== Приём состояния от хоста (только клиент) =====

on_state_received(function(json_str)
    game = json_decode(json_str)
end)

-- ===== Триггеры =====

engine.trigger("roll_dice", function(self)
    local player = self:getIntProperty("player", 0)
    if game.gameOver or game.hasRolled then return end
    if game.currentPlayer ~= player then return end

    -- Клиент пересылает действие хосту
    if is_client() then
        send_event(self:getId(), "roll_dice")
        return
    end

    -- Хост (или одиночная игра) выполняет бросок
    local roll = cpp_rand(1, 6)
    game.diceRoll[player]  = roll
    game.scores[player]    = game.scores[player] + roll
    game.hasRolled         = true
    cpp_log("Игрок " .. player .. " бросил " .. roll ..
            " — итого: " .. game.scores[player])

    if game.scores[player] >= game.targetScore then
        game.gameOver = true
        game.winner   = player
        cpp_log("Игрок " .. player .. " победил!")
    end

    if is_host() then send_state(json_encode(game)) end
end)

engine.trigger("end_turn", function(self)
    if game.gameOver or not game.hasRolled then return end

    if is_client() then
        send_event(self:getId(), "end_turn")
        return
    end

    game.currentPlayer = game.currentPlayer == 1 and 2 or 1
    game.hasRolled     = false
    cpp_log("Ход передан Игроку " .. game.currentPlayer)

    if is_host() then send_state(json_encode(game)) end
end)

-- ===== Клавиатура =====

engine.onKey("R", function()
    engine.reloadScene()
end)

-- ===== Engine hooks =====

function update(dt)
    local d1  = engine.getObject("dice_1")
    local d2  = engine.getObject("dice_2")
    local btn = engine.getObject("end_turn_btn")
    if not d1 or not d2 or not btn then return end

    local function updateDie(obj, player, prefix)
        local roll = game.diceRoll[player]
        if roll > 0 then
            cpp_set_obj_texture(obj:getId(), "assets/" .. prefix .. roll .. ".png")
        end
        -- В сетевом режиме блокируем чужой кубик
        local isMyTurn = (game.currentPlayer == player)
        local isMyDie  = (myPlayer == 0 or myPlayer == player)
        if isMyTurn and not game.hasRolled and not game.gameOver and isMyDie then
            obj:setColor(255, 255, 255, 255)
        else
            obj:setColor(160, 150, 130, 180)
        end
    end

    updateDie(d1, 1, "dieWhite_border")
    updateDie(d2, 2, "dieRed_border")

    if game.gameOver then
        btn:setColor(80, 80, 80, 180)
    elseif game.hasRolled then
        btn:setColor(80, 220, 100, 255)
    else
        btn:setColor(150, 150, 150, 200)
    end
end

function draw()
    local P1  = {220, 80,  80}
    local P2  = {80,  80,  220}
    local cur = game.currentPlayer == 1 and P1 or P2

    cpp_draw_text_left(
        "Игрок 1: " .. game.scores[1] .. " / " .. game.targetScore,
        20, 18, 26, table.unpack(P1))
    cpp_draw_text_right(
        "Игрок 2: " .. game.scores[2] .. " / " .. game.targetScore,
        1260, 18, 26, table.unpack(P2))

    if not game.gameOver then
        cpp_draw_text_center(
            ">>> Ход Игрока " .. game.currentPlayer .. " <<<",
            640, 22, 26, table.unpack(cur))
    end

    -- Подсказка роли
    if myPlayer > 0 then
        local roleText = myPlayer == 1 and "Вы: Игрок 1 (хост)" or "Вы: Игрок 2 (клиент)"
        cpp_draw_text_center(roleText, 640, 50, 16, 160, 160, 160)
    end

    local btnColor = (game.hasRolled and not game.gameOver)
                     and {255, 255, 255} or {160, 160, 160}
    cpp_draw_text_center("Закончить ход", 640, 660, 22, table.unpack(btnColor))

    cpp_draw_text_left(
        "Перемещай кубик | Кликни чтобы бросить | R — перезапуск",
        20, 700, 15, 130, 130, 130)

    if game.gameOver then
        cpp_draw_rect(0, 0, 1280, 720, 0, 0, 0, 190)
        cpp_draw_text_center(
            "Игрок " .. game.winner .. " ПОБЕДИЛ!",
            640, 300, 72, table.unpack(game.winner == 1 and P1 or P2))
        cpp_draw_text_center(
            "Счёт: " .. game.scores[game.winner] .. " очков",
            640, 390, 36, 255, 255, 255)
        cpp_draw_text_center(
            "Нажмите R для перезапуска или ESC для выхода",
            640, 450, 24, 180, 180, 180)
    end
end
