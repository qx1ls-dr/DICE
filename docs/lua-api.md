# Lua API движка DICE

## Базовые функции

| Функция | Описание |
|---|---|
| `cpp_log(msg)` | Вывод в лог |
| `cpp_rand(min, max)` | Случайное целое в диапазоне [min, max] |
| `cpp_draw_text_center(text, x, y, size, r, g, b)` | Текст по центру |
| `cpp_draw_text_left(text, x, y, size, r, g, b)` | Текст слева |
| `cpp_draw_text_right(text, x, y, size, r, g, b)` | Текст справа |
| `cpp_draw_rect(x, y, w, h, r, g, b, a)` | Залитый прямоугольник |
| `cpp_set_obj_texture(id, path)` | Установить текстуру объекту |

## Объект сцены (GameObject)

| Метод | Описание |
|---|---|
| `obj:getId()` | Строковый ID |
| `obj:getX()` / `obj:getY()` | Позиция |
| `obj:setPosition(x, y)` | Установить позицию |
| `obj:setVisible(bool)` | Видимость |
| `obj:setActive(bool)` | Активность |
| `obj:setColor(r, g, b, a)` | Цвет/прозрачность |
| `obj:getIntProperty(key, default)` | Пользовательское свойство (int) |
| `obj:setIntProperty(key, value)` | |

## Engine API

| Функция | Описание |
|---|---|
| `engine.trigger(name, fn)` | Регистрация обработчика триггера |
| `engine.onKey(key, fn)` | Обработка клавиши |
| `engine.getObject(id)` | Получить объект по ID |
| `engine.reloadScene()` | Перезагрузить текущую сцену |

## Network API

| Функция | Описание |
|---|---|
| `is_host()` | `true` если текущий экземпляр — хост |
| `is_client()` | `true` если текущий экземпляр — клиент |
| `get_my_player()` | Номер игрока: `1`=хост, `2`=клиент, `0`=одиночная |
| `send_event(id, event)` | Отправить событие на хост (только клиент) |
| `send_move(id, x, y)` | Отправить перемещение объекта на хост |
| `send_state(json_str)` | Хост рассылает игровое состояние всем клиентам |
| `on_state_received(fn)` | Callback `fn(json_str)` при получении состояния |
| `network_allow_event(name)` | Разрешить триггер от клиентов |

## JSON API

| Функция | Описание |
|---|---|
| `json_encode(table)` | Lua-таблица → JSON-строка |
| `json_decode(str)` | JSON-строка → Lua-таблица |
