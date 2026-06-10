# Kosti — Игра в кости

Демо-игра DICE. Два игрока по очереди бросают кубики, первый до 21 очка побеждает.

## Запуск

**Одиночная игра:**
```bash
./dice scenes/kosti.json
```

**По сети:**
```bash
# Терминал 1 (Игрок 1 — хост)
./dice scenes/kosti.json --host 7777

# Терминал 2 (Игрок 2 — клиент)
./dice scenes/kosti.json --join 192.168.1.5:7777
```

## Ключевые паттерны

### Перехват действий на клиенте

```lua
engine.trigger("roll_dice", function(self)
    if is_client() then
        send_event(self:getId(), "roll_dice")  -- пересылаем хосту
        return
    end
    -- хост выполняет логику...
end)
```

### Синхронизация состояния

```lua
-- Хост после каждого изменения:
send_state(json_encode(game))

-- Клиент принимает:
on_state_received(function(json_str)
    game = json_decode(json_str)
end)
```
