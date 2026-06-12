local SUIT_NAME = { "clubs", "diamonds", "hearts", "spades" }
local BACK_TEX  = "assets/blackjack/card_back.png"

local function card_tex(suit, rank)
    return "assets/blackjack/card_" .. SUIT_NAME[suit] .. "_" .. rank .. ".png"
end
local CARD_STEP = 110
local DEALER_Y  = 220
local PLAYER_Y  = 460
local HAND_X0   = 260
local BTN_Y     = 648
local DECK_X    = 1130
local DECK_Y    = 360
local ANIM_SEC  = 0.20   -- seconds per card slide

local phase        = "idle"
local player_cards = {}
local dealer_cards = {}
local status_msg   = ""

-- ── Lua-managed deck ──────────────────────────────────────────────────────────

local lua_deck   = {}
local deck_index = 1

local OCHKO_RANKS = { 1, 6, 7, 8, 9, 10, 11, 12, 13 }

local function build_deck()
    lua_deck = {}
    for s = 1, 4 do
        for _, r in ipairs(OCHKO_RANKS) do
            lua_deck[#lua_deck + 1] = { id = "card_s" .. s .. "_r" .. r, rank = r, suit = s }
        end
    end
    cpp_shuffle(lua_deck)
    deck_index = 1
end

local function draw_from_deck()
    if deck_index > #lua_deck then return nil end
    local c = lua_deck[deck_index]
    deck_index = deck_index + 1
    return c
end

-- ── animation queue ───────────────────────────────────────────────────────────

local anim_queue   = {}   -- { entry, on_done }
local anim_current = nil  -- { entry, elapsed, on_done }

local function anim_start_next()
    if #anim_queue == 0 then return end
    local item  = table.remove(anim_queue, 1)
    local entry = item.entry
    local obj   = engine.getObject(entry.id)
    if obj then
        cpp_set_obj_texture(entry.id, entry.hidden and BACK_TEX or card_tex(entry.suit, entry.rank))
        obj:setPosition(DECK_X, DECK_Y)
        obj:setVisible(true)
        obj:setZOrder(10)
    end
    anim_current = { entry = entry, elapsed = 0, on_done = item.on_done }
end

-- ── pure helpers ──────────────────────────────────────────────────────────────

local function card_value(r)
    if r == 1  then return 11 end
    if r == 11 then return 2  end
    if r == 12 then return 3  end
    if r == 13 then return 4  end
    return r
end

local function is_picture(r) return r == 11 or r == 12 or r == 13 end

local function best_score(hand)
    local total, aces = 0, 0
    for _, c in ipairs(hand) do
        total = total + card_value(c.rank)
        if c.rank == 1 then aces = aces + 1 end
    end
    while total > 21 and aces > 0 do
        total = total - 10
        aces  = aces  - 1
    end
    return total
end

local function has_five_pictures(hand)
    if #hand < 5 then return false end
    local pics = 0
    for _, c in ipairs(hand) do if is_picture(c.rank) then pics = pics + 1 end end
    return pics >= 5
end

local function is_golden(hand)
    return #hand == 2 and hand[1].rank == 1 and hand[2].rank == 1
end

local function is_natural(hand)
    if #hand ~= 2 then return false end
    local r1, r2 = hand[1].rank, hand[2].rank
    return (r1 == 1 and r2 == 10) or (r2 == 1 and r1 == 10)
end

-- ── state mutators ────────────────────────────────────────────────────────────

local BTN_W  = 220
local BTN_H  = 52
local DEAL_W = 260

local function show_buttons(deal, hit, stand)
    local btns = { btn_deal = deal, btn_hit = hit, btn_stand = stand }
    for id, on in pairs(btns) do
        local obj = engine.getObject(id)
        if obj then obj:setActive(on) obj:setVisible(on) end
    end
end

local function draw_button(label, cx, cy, w, r, g, b)
    local x = cx - w / 2
    local y = cy - BTN_H / 2
    cpp_draw_rect(x + 3, y + 4, w, BTN_H, 0, 0, 0, 90)
    cpp_draw_rect(x, y, w, BTN_H, r, g, b, 255)
    cpp_draw_rect(x, y, w, 2, 255, 255, 255, 55)
    cpp_draw_rect(x, y + BTN_H - 2, w, 2, 0, 0, 0, 60)
    cpp_draw_text_center(label, cx, cy + 1, 20, 255, 255, 255)
end

local function place_card(entry)  -- instant placement (used for reveal_hole)
    local obj = engine.getObject(entry.id)
    if not obj then return end
    obj:setPosition(entry.x, entry.y)
    obj:setVisible(true)
    obj:setZOrder(3)
    cpp_set_obj_texture(entry.id, entry.hidden and BACK_TEX or card_tex(entry.suit, entry.rank))
end

local function deal_card(hand, y, hidden, on_done)
    local c = draw_from_deck()
    if not c then
        if on_done then on_done() end
        return
    end
    local entry = {
        id     = c.id,
        rank   = c.rank,
        suit   = c.suit,
        x      = HAND_X0 + #hand * CARD_STEP,
        y      = y,
        hidden = hidden,
    }
    hand[#hand + 1] = entry
    anim_queue[#anim_queue + 1] = { entry = entry, on_done = on_done }
    if not anim_current then anim_start_next() end
end

local function reveal_hole()
    local c = dealer_cards[2]
    if c and c.hidden then
        c.hidden = false
        place_card(c)
    end
end

-- ── round logic ───────────────────────────────────────────────────────────────

local function end_round(result, msg)
    if     result == "win"  then blackjack_wins   = blackjack_wins   + 1
    elseif result == "lose" then blackjack_losses = blackjack_losses + 1
    else                         blackjack_ties   = blackjack_ties   + 1
    end
    if msg then status_msg = msg end
    phase = "game_over"
    show_buttons(true, false, false)
end

local function dealer_play()
    local function dealer_step()
        if best_score(dealer_cards) < 17 then
            deal_card(dealer_cards, DEALER_Y, false, dealer_step)
        else
            local ds = best_score(dealer_cards)
            local ps = best_score(player_cards)
            if     ds > 21 then end_round("win",  "Дилер перебрал! Вы победили!")
            elseif ps > ds then end_round("win",  "Вы победили! (" .. ps .. " vs " .. ds .. ")")
            elseif ps < ds then end_round("lose", "Дилер победил. (" .. ds .. " vs " .. ps .. ")")
            else                end_round("tie",  "Ничья. (" .. ps .. ")")
            end
        end
    end
    dealer_step()
end

local function do_hit()
    if phase ~= "player_turn" then return end
    phase = "dealing"
    show_buttons(false, false, false)
    deal_card(player_cards, PLAYER_Y, false, function()
        local ps = best_score(player_cards)
        if has_five_pictures(player_cards) then
            status_msg = "Пять картинок — 21!"
            dealer_play()
        elseif ps > 21 then
            end_round("lose", "Перебор! (" .. ps .. ")")
        elseif ps == 21 then
            dealer_play()
        else
            phase      = "player_turn"
            status_msg = "Берёте карту? [H] или Пас [S]"
            show_buttons(false, true, true)
        end
    end)
end

local function do_stand()
    if phase ~= "player_turn" then return end
    phase = "dealing"
    show_buttons(false, false, false)
    dealer_play()
end

-- ── trigger registrations ─────────────────────────────────────────────────────

engine.trigger("deal_round",   function() engine.reloadScene() end)
engine.trigger("player_hit",   function() do_hit()   end)
engine.trigger("player_stand", function() do_stand() end)

engine.onKey("D", function() if phase == "game_over" or phase == "idle" then engine.reloadScene() end end)
engine.onKey("H", function() do_hit()   end)
engine.onKey("S", function() do_stand() end)

-- ── initial deal ──────────────────────────────────────────────────────────────

local started = false

local function start_game()
    for s = 1, 4 do
        for r = 1, 13 do
            local obj = engine.getObject("card_s" .. s .. "_r" .. r)
            if obj then obj:setVisible(false) obj:setPosition(-2000, -2000) end
        end
    end

    build_deck()
    phase      = "dealing"
    status_msg = ""

    -- Очко: игрок получает 2 карты, дилер — 1 открытую карту
    deal_card(player_cards, PLAYER_Y, false, nil)
    deal_card(player_cards, PLAYER_Y, false, nil)
    deal_card(dealer_cards, DEALER_Y, false, function()
        if is_golden(player_cards) then
            end_round("win", "Золотое очко! Мгновенная победа!")
            return
        end
        if is_natural(player_cards) then
            end_round("win", "Натуральное очко!")
            return
        end
        phase      = "player_turn"
        status_msg = "Берёте карту? [H] или Пас [S]"
        show_buttons(false, true, true)
    end)
end

-- ── frame loop ────────────────────────────────────────────────────────────────

function update(dt)
    if not started then
        started = true
        start_game()
    end

    if not anim_current then return end

    local a = anim_current
    a.elapsed = a.elapsed + dt
    local t   = math.min(a.elapsed / ANIM_SEC, 1.0)
    local e   = 1.0 - (1.0 - t) * (1.0 - t)   -- ease-out quadratic
    local obj = engine.getObject(a.entry.id)
    if obj then
        obj:setPosition(
            DECK_X + (a.entry.x - DECK_X) * e,
            DECK_Y + (a.entry.y - DECK_Y) * e)
    end

    if t < 1.0 then return end

    -- animation finished
    if obj then
        obj:setPosition(a.entry.x, a.entry.y)
        obj:setZOrder(3)
    end
    local cb     = a.on_done
    anim_current = nil
    if cb then cb() end
    -- cb may have queued more cards via deal_card (which auto-starts);
    -- only start here if cb didn't trigger it
    if not anim_current and #anim_queue > 0 then
        anim_start_next()
    end
end

-- ── draw ─────────────────────────────────────────────────────────────────────

function draw()
    cpp_draw_rect(0, 0, 1280, 52, 0, 0, 0, 170)

    cpp_draw_text_left(
        "Победы: "    .. blackjack_wins   ..
        "   Поражения: " .. blackjack_losses ..
        "   Ничьи: "  .. blackjack_ties,
        16, 26, 24, 200, 200, 200)

    cpp_draw_text_center(status_msg, 640, 26, 24, 255, 230, 60)

    cpp_draw_text_left("ДИЛЕР", 16, 72,  20, 160, 200, 160)
    cpp_draw_text_left("ИГРОК", 16, 418, 20, 160, 200, 160)

    if #dealer_cards > 0 then
        local visible = {}
        for _, c in ipairs(dealer_cards) do
            if not c.hidden then visible[#visible+1] = c end
        end
        cpp_draw_text_left("Очки: " .. best_score(visible), 16, 92, 18, 160, 200, 160)
    end

    if #player_cards > 0 then
        local ps = best_score(player_cards)
        local r  = ps > 21 and 220 or 160
        local g  = ps > 21 and 60  or 200
        cpp_draw_text_left("Очки: " .. ps, 16, 438, 18, r, g, 160)
    end

    if phase == "game_over" or phase == "idle" then
        draw_button("НОВАЯ ИГРА  [D]", 640, BTN_Y, DEAL_W, 60, 110, 190)
    end
    if phase == "player_turn" or phase == "dealing" then
        draw_button("КАРТУ  [H]", 430, BTN_Y, BTN_W, 55, 160, 70)
        draw_button("ПАС  [S]",   850, BTN_Y, BTN_W, 190, 60, 60)
    end
end
