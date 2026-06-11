# Змейка

> Демонстрирует: `update(dt)`, `draw()`, `engine.onKey`, `cpp_draw_rect`, `cpp_draw_text_*`, `cpp_rand`, `game state в Lua`, сцена без объектов

## Механика

Классическая аркадная змейка на сетке 24×16. Змейка непрерывно движется, игрок поворачивает её, собирая еду. Каждая съеденная еда удлиняет змейку и прибавляет очки. Партия заканчивается при столкновении со своим телом (а на уровнях `MEDIUM`/`HARD` — ещё и со стеной). Если змейка заполняет всё поле — экран **YOU WIN!**.

### Уровни сложности

Перед игрой выбирается сложность (клавиши `1` / `2` / `3` в стартовом меню):

| Уровень | Скорость (шаг) | Стены |
|---------|----------------|-------|
| **EASY** | 0.16 с | прозрачные — змейка телепортируется на противоположную сторону |
| **MEDIUM** | 0.11 с | удар об стену = смерть |
| **HARD** | 0.07 с | удар об стену = смерть |

### Управление

- Стрелки или **WASD** — поворот (разворот на 180° запрещён).
- **Space** — пауза / продолжить.
- После Game Over / Win: **R** — рестарт того же уровня, **M** — в меню, **1/2/3** — новая игра на выбранной сложности.

## Файлы

- `samples/scenes/snake.json`
- `samples/scripts/snake.lua`

## Особенность: сцена без объектов

Движок DICE не умеет создавать и удалять объекты в рантайме, а тело змейки постоянно растёт. Поэтому игра вообще не использует игровые объекты — всё состояние хранится в Lua-таблицах, а поле, змейка и еда рисуются напрямую через `cpp_draw_rect` внутри `draw()`. Сцена содержит только список скриптов:

```json
{
  "scripts": ["scripts/snake.lua"],
  "objects": []
}
```

## Ключевые части скрипта

```lua
-- Сложности: step = секунд на шаг, wrap = проходить сквозь стены
local LEVELS = {
    { name = "EASY",   step = 0.16, wrap = true,  food = 10 },
    { name = "MEDIUM", step = 0.11, wrap = false, food = 10 },
    { name = "HARD",   step = 0.07, wrap = false, food = 10 },
}

-- Состояние игры
local snake          -- массив сегментов {c=, r=}, голова первая
local state = "menu" -- "menu" | "play" | "pause" | "over" | "win"
```

Движение — это сдвиг на одну клетку через накопление `dt` в `update(dt)`:

```lua
function update(dt)
    if state ~= "play" or snake == nil then return end
    local interval = LEVELS[level_idx].step
    timer = timer + dt
    while timer >= interval and state == "play" do
        timer = timer - interval
        step()
    end
end
```

Шаг змейки — расчёт новой головы, обработка стен, проверка столкновений и поедания еды:

```lua
local function step()
    local level = LEVELS[level_idx]
    dir = next_dir
    local head = snake[1]
    local nc, nr = head.c + dir.dc, head.r + dir.dr

    if level.wrap then
        nc = (nc + COLS) % COLS    -- телепорт сквозь стену
        nr = (nr + ROWS) % ROWS
    elseif nc < 0 or nc >= COLS or nr < 0 or nr >= ROWS then
        state = "over"             -- удар об стену
        return
    end

    local will_eat = (nc == food.c and nr == food.r)
    -- ... проверка самопересечения, рост, спавн новой еды ...
end
```

**Паттерны:**
- **Тайминг без таймера движка** — интервал шага набирается через `timer = timer + dt` в `update(dt)`.
- **Машина состояний** — переходы `menu → play → pause/over/win` внутри одного скрипта, без смены сцены.
- **Запрет разворота на 180°** — новое направление буферизуется в `next_dir` и сравнивается с текущим `dir`, чтобы змейка не могла мгновенно врезаться в себя.
- **Обёртка стен** через `(n + SIZE) % SIZE` для уровня `EASY`.

## Как запустить

После сборки укажите сцену в `build/game.json`:

```json
{ "startScene": "scenes/snake.json" }
```

И запустите из папки `build/`:

```bash
./dice
```
