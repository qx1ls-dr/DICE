# Сапёр (Minesweeper)

> Демонстрирует: `Tile`, `engine.getObject`, `cpp_set_obj_texture`, `update(dt)`, `draw()`, `cpp_draw_rect`, `cpp_draw_text_*`, `setActive`/`setVisible`, `BFS flood fill`, `ретро-UI через draw()`

## Механика

Классический Сапёр. Поле полностью скрыто в начале; клик открывает клетку. Если под ней мина — поражение. Если клетка пустая (0 соседних мин) — BFS-заливка открывает весь смежный пустой регион. Победа — когда все неминные клетки открыты.

Первый клик всегда безопасен: мины расставляются после него, зона 3×3 вокруг первой клетки гарантированно чиста.

### Уровни сложности

| Уровень | Поле | Мины |
|---------|------|------|
| **Easy** | 9 × 9 | 10 |
| **Medium** | 16 × 16 | 40 |
| **Hard** | 30 × 16 | 99 |

### Управление

- **Клик** на клетку — открыть (в режиме OPEN) или поставить/убрать флаг (в режиме FLAG).
- **Space** — переключить режим OPEN ↔ FLAG.
- **R** — перезапустить с той же сложностью.
- **Кнопки Easy / Medium / Hard** — сменить сложность и перезапустить.
- **Смайлик** в заголовке — кнопка перезапуска; меняет выражение в зависимости от состояния игры.

## Файлы

- `samples/scenes/minesweeper.json`
- `samples/scripts/minesweeper/game.lua`
- `assets/minesweeper/` — 64×64 PNG-спрайты клеток, бомб, цифр, флагов, смайликов

## Особенность: максимальная сетка в JSON + show/hide

Движок DICE не умеет создавать объекты в рантайме. Поэтому в сцене заранее объявлены **все 480 Tile-объектов** (30 × 16 — максимальный размер Hard), именованных `cell_<col>_<row>`. При запуске и смене сложности скрипт скрывает лишние клетки через `setActive(false)` / `setVisible(false)` и показывает только нужные, выставляя им позиции:

```lua
-- Скрыть весь максимальный грид
for r = 0, MAX_R - 1 do
    for c = 0, MAX_C - 1 do
        local obj = engine.getObject("cell_" .. c .. "_" .. r)
        if obj then obj:setVisible(false); obj:setActive(false) end
    end
end

-- Показать клетки текущей сложности и расставить их
local ox, oy = grid_origin(diff.cols, diff.rows)
for r = 0, diff.rows - 1 do
    for c = 0, diff.cols - 1 do
        local id  = "cell_" .. c .. "_" .. r
        local obj = engine.getObject(id)
        if obj then
            obj:setPosition(ox + c * CELL + CELL/2, oy + r * CELL + CELL/2)
            obj:setVisible(true); obj:setActive(true)
            cpp_set_obj_texture(id, TEX.closed)
        end
    end
end
```

## Ключевые части скрипта

### Состояние клетки и BFS-заливка

Каждая клетка хранится как таблица `{ is_mine, neighbor_count, state }`:
- `state = 0` — закрыта
- `state = 1` — открыта
- `state = 2` — флаг

```lua
function logic.open_cell(c, r)
    if logic.first_move then
        logic.generate_mines(c, r)  -- safe zone 3×3 вокруг первого клика
        logic.first_move = false
    end
    local cell = logic.grid[c][r]
    if cell.state ~= 0 then return "ok" end
    if cell.is_mine then cell.state = 1; return "lose" end

    -- BFS flood fill: раскрывает все связанные пустые клетки
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
```

### Таймер и состояние смайлика

Таймер запускается первым кликом и останавливается при победе или поражении:

```lua
function update(dt)
    if not started then started = true; init_game() end
    if timer_running then timer_sec = timer_sec + dt end

    -- Состояние смайлика
    if game_over then
        set_smiley("lose")      -- 😵
    elseif game_won then
        set_smiley("win")       -- 😎
    elseif press_timer > 0 then
        press_timer = press_timer - dt
        set_smiley(press_timer > 0 and "press" or "play")
    else
        set_smiley("play")      -- 🙂
    end
end
```

### Ретро-интерфейс в draw()

Весь HUD — заголовок, панели, LCD-счётчики, кнопки сложности — рисуется напрямую через `cpp_draw_rect` и `cpp_draw_text_*` в `draw()`. Объекты сцены (смайлик, кнопки Easy/Medium/Hard) используются **только как hitbox** для кликов — визуально они перекрыты нарисованными поверх прямоугольниками.

```lua
local function draw_bevel_out(x, y, w, h)  -- выпуклый бортик (3D-эффект)
    cpp_draw_rect(x,     y,     w, 2, 255, 255, 255, 255)  -- top
    cpp_draw_rect(x,     y,     2, h, 255, 255, 255, 255)  -- left
    cpp_draw_rect(x,     y+h-2, w, 2, 128, 128, 128, 255)  -- bottom
    cpp_draw_rect(x+w-2, y,     2, h, 128, 128, 128, 255)  -- right
end

local function draw_lcd(x, y, w, h, value)  -- LCD-дисплей (чёрный фон, красные цифры)
    local txt = string.format("%03d", math.min(math.max(value, 0), 999))
    cpp_draw_rect(x, y, w, h, 0, 0, 0, 255)
    draw_bevel_in(x, y, w, h)
    cpp_draw_text_center(txt, x + w/2, y + math.floor(h / 2), 28, 255, 0, 0)
end
```

**Паттерны:**
- **Ретро-UI без UI-объектов** — весь интерфейс рисуется в `draw()` поверх объектов сцены; объекты нужны только для обработки кликов.
- **Hitbox-объекты** — кнопки Easy/Medium/Hard — это `GameObject` с текстурой `button.png`, визуально перекрытые нарисованными поверх прямоугольниками с бевелом.
- **Смайлик как объект** — единственный видимый объект сцены; его текстура меняется через `cpp_set_obj_texture("smiley", path)` при смене состояния игры.
- **Безопасный первый ход** — мины генерируются после первого клика; зона `|dc| ≤ 1 && |dr| ≤ 1` вокруг него всегда свободна.
- **Обновление текстур клеток** — `cpp_set_obj_texture(id, path)` применяется при каждом изменении состояния (open / flag / reveal mines).

## Как запустить

После сборки укажите сцену в `build/game.json`:

```json
{ "startScene": "scenes/minesweeper.json" }
```

И запустите из папки `build/`:

```bash
./dice
```
