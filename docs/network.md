# Сетевая архитектура DICE

## Компоненты

| Класс | Файл | Роль |
|---|---|---|
| `NetworkManager` | `src/network/NetworkManager.cpp` | Точка входа; регистрирует Lua-биндинги |
| `HostServer` | `src/network/HostServer.cpp` | TCP-сервер; авторитет игровой логики |
| `GameClient` | `src/network/GameClient.cpp` | TCP-клиент; применяет события от сервера |
| `NetworkMessage` | `src/network/NetworkMessage.cpp` | Сериализация/десериализация сообщений |

## Типы сообщений (MessageType)

| Значение | Имя | Направление | Описание |
|---|---|---|---|
| 0 | Handshake | Client→Host | Начало рукопожатия с именем игрока |
| 1 | HandshakeAck | Host→Client | Подтверждение, clientId, флаг gameStarted |
| 2 | Ping | любое | Проверка живости соединения |
| 3 | Pong | ответ на Ping | |
| 4 | Disconnect | любое | Корректное отключение |
| 5 | PlayerJoined | Host→All | Новый игрок подключился |
| 6 | PlayerLeft | Host→All | Игрок отключился |
| 7 | PlayerReady | Client→Host | Игрок готов |
| 8 | StartGame | Host→All | Игра начата |
| 9 | Snapshot | Host→All | Снепшот состояния объектов сцены (каждые 100ms) |
| 10 | Event | Client→Host→All | Игровое событие (триггер на объекте) |
| 11 | MoveObject | Client→Host→All | Перемещение объекта |
| 12 | Chat | любое→All | Чат-сообщение |
| 13 | State | Host→All | Произвольное Lua-состояние игры (JSON-строка) |

## Жизненный цикл соединения

```
Хост: ./dice scenes/kosti.json --host 7777
  → HostServer::start(7777) — слушаем порт

Клиент: ./dice scenes/kosti.json --join 192.168.1.5:7777
  → GameClient::connect(...)
  → send Handshake{playerName}
  ← recv HandshakeAck{clientId}

Хост: onClientJoined → NetworkManager::startGame()
  → broadcast StartGame
  → broadcast Snapshot (начальное состояние)

Игра:
  Client click → send Event{object_id, event_name}
  Host: lua_.fireEvent → обрабатывает, вызывает send_state(json)
  → broadcast State{payload: json_str}
  Client: on_state_received(json_str) → game = json_decode(json_str)
```

## Безопасность событий

`HostServer::allowedEvents_` содержит белый список триггеров, разрешённых от клиента.
По умолчанию: `{"on_click", "on_drag_start", "on_drag_end"}`.
Игра добавляет свои триггеры через Lua: `network_allow_event("roll_dice")`.
