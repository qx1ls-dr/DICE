---
name: dice-game-development
description: Use when creating, editing, or debugging games with the DICE engine — when working with scene JSON files, Lua game scripts, game.json config, object triggers, presets, or the engine Lua API. Also use when asked to add game objects, implement interactions, structure a new game, or fix DICE-specific Lua/JSON issues.
---

# DICE Game Development

## Overview

DICE is a 2D game engine (C++ + SFML) where game logic lives entirely in **Lua scripts** and scene structure in **JSON files** — no C++ recompilation needed.

Architecture: JSON defines objects → Lua scripts register event handlers → engine routes input to handlers.

**Loading order within a scene:** scripts from `"scripts"` execute first → objects are created from JSON → presets are merged into trigger bindings → textures are loaded → Deck `faceDown` state propagates to Card children.

## Mandatory Development Workflow

**STOP. Before any code or JSON — follow these steps in order. No exceptions.**

<HARD-GATE>
Do NOT write any JSON, Lua code, or project files until you have presented a design document and the developer has **explicitly confirmed** it. This applies to every game, regardless of perceived simplicity.
</HARD-GATE>

## Anti-Pattern: "This Game Is Too Simple To Need A Design"

Every game goes through the full workflow. A "simple dice roller," a one-screen clicker, a single-mechanic puzzle — all of them. Simple projects are where unexamined assumptions cause the most wasted work. The design document can be short, but you MUST present it and get confirmation before writing any files.

## Checklist

**Create a TodoWrite task for each item below and complete them in order:**

1. **Explore project context** — check existing files, scenes, scripts, recent commits
2. **Assess scope** — flag if the request spans multiple independent subsystems
3. **Ask clarifying questions** — one at a time until concept, actions, and win/lose are clear
4. **Propose 2-3 design approaches** — with trade-offs and your recommendation
5. **Present design document** — get explicit developer confirmation
6. **Write design doc to file** — save and commit
7. **Spec self-review** — scan for placeholders, contradictions, ambiguity
8. **Developer reviews written doc** — wait for approval before writing the plan
9. **Create development plan** — get explicit developer confirmation
10. **Implement** — only after both documents are confirmed

---

### Step 1: Explore and Clarify

**First, explore the current project state.** Check existing files, scenes, scripts, and recent git commits before asking any questions. If you're working in an existing game project, follow its patterns — don't propose changes without understanding what's already there.

**Assess scope before diving into details.** If the request describes multiple independent subsystems (e.g., "a card game with a shop, a campaign map, and online leaderboards"), flag this immediately. Help the developer decompose into sub-games or phases: what are the independent pieces, how do they relate, what order to build them? Each sub-scope gets its own design doc → plan → implementation cycle.

**Ask clarifying questions — one at a time.** Prefer multiple-choice when possible. Focus on:
- Game concept and theme
- Player actions
- Win/lose conditions
- Number of players
- Objects needed (cards, dice, chips, tiles, etc.)
- Key interactions

Red flags — stop and clarify if:
- The game concept is vague ("make a card game")
- Win/lose conditions are not defined
- The number of players is unclear

---

### Step 2: Design Document

After clarifying, **propose 2-3 design approaches** — with trade-offs and your recommendation — before settling on one. Then create the full design document covering:

- **Game concept** — what kind of game, theme, goal
- **Player actions** — what the player can do
- **Win/lose conditions** — how the game ends
- **Objects needed** — list of game objects with their types
- **Scenes** — how many scenes, what each contains
- **Key interactions** — which events trigger what behavior
- **Script responsibilities** — which Lua file does what (each script = one clear purpose)

**Design for isolation and clarity.** Break the game into scripts and scenes that each have one clear purpose and communicate through well-defined triggers and object ids. Can someone understand what a script does without reading the whole codebase? If not, the boundaries need work.

**Apply YAGNI ruthlessly.** Remove features that are "nice to have" — only design what the game needs to be playable and fun. Don't design for hypothetical future mechanics.

Present the design and **wait for explicit confirmation** before proceeding.

**Write the design document** to `docs/superpowers/specs/YYYY-MM-DD-<game-name>-design.md` and commit it.

**Spec self-review** — after writing, check:
1. **Placeholder scan** — any "TBD," "TODO," vague requirements? Fix them.
2. **Internal consistency** — do object lists match scene descriptions? Do trigger names match script plans?
3. **Scope check** — is this focused enough for a single implementation plan?
4. **Ambiguity** — could any requirement be interpreted two ways? Pick one and make it explicit.

**Developer review gate** — after self-review, ask the developer to review the written spec:

> "Design doc written and committed to `<path>`. Please review it and let me know if you'd like any changes before we move to the development plan."

Wait for the response. Only proceed once the developer approves.

---

### Step 3: Development Plan

After design is confirmed, create a **step-by-step development plan**:

1. File and folder structure
2. `game.json` configuration
3. Scene JSON layout (objects, hierarchy, presets)
4. Lua scripts — list each file and what it does
5. Order of implementation

**Required:** Present the plan to the developer and **wait for explicit confirmation** before writing any files.

---

### Step 4: Implementation

Only after both documents are confirmed — proceed with implementation following the technical reference below.

**Working in existing game projects:** explore the current structure before proposing any changes. Follow existing naming patterns for ids, triggers, and file paths. Where existing code has problems that affect the work (a scene that's grown too large, tangled script responsibilities), include targeted improvements as part of the design — not unrelated refactoring.

---

## Project Structure

```
my_game/
├── game.json              # Window, fonts, entry scene
├── scenes/
│   └── main.json          # Scene: object hierarchy + script list
├── scripts/
│   ├── game.lua           # Global state & trigger registrations
│   └── presets/           # Custom reusable behavior scripts
└── assets/
    ├── images/            # PNG textures
    ├── fonts/             # TTF fonts
    └── presets.json       # Preset behavior definitions
```

## game.json — App Config

```json
{
  "title": "My Game",
  "windowWidth": 1280,
  "windowHeight": 720,
  "framerateLimit": 60,
  "resizable": false,
  "clearR": 30, "clearG": 30, "clearB": 40,
  "startScene": "scenes/main.json",
  "showFPS": true,
  "showObjectCount": false,
  "showControls": false,
  "luaMemoryLimitMb": 64,
  "maxSceneObjects": 1000,
  "fonts": [
    { "id": "default_font", "path": "assets/fonts/OpenSans-Regular.ttf" }
  ]
}
```

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| `title` | string | `"DICE"` | Window title |
| `windowWidth` / `windowHeight` | int | 1280 / 720 | Window size in pixels |
| `framerateLimit` | int | `60` | FPS cap |
| `resizable` | bool | `true` | When `true`: absolute coordinates do **not** scale on window resize — positions drift. Prefer `false` |
| `clearR/G/B` | int | 30/30/40 | Background color (0–255) |
| `startScene` | string | `"scenes/demo.json"` | Path to initial scene |
| `globalScript` | string | `""` | Runs once at app startup, **before** `cpp_rand`/`cpp_draw_*`/`engine.getObject`/`log` are registered (only `engine.trigger`/`on`/`onKey` and `cpp_log` exist), and the first scene load wipes any triggers/key handlers it registered. Useful only for defining global variables/functions — prefer scene `"scripts"` |
| `fonts` | array | `[]` | `[{id, path}]` |
| `showFPS` | bool | `true` | FPS overlay |
| `showObjectCount` | bool | `true` | Object count overlay |
| `showControls` | bool | `true` | Controls hint overlay |
| `luaMemoryLimitMb` | int | `64` | Lua VM memory cap in MB; when exceeded the triggering script call fails with an error in log — engine keeps running |
| `maxSceneObjects` | int | `1000` | Max objects per scene (SceneValidator enforces this) |

## Scene JSON — Object Schemas

All types share the `GameObject` base fields:

```json
{
  "type": "GameObject",
  "id": "board",
  "name": "Game Board",
  "position": [640, 360],
  "scale": [1.0, 1.0],
  "rotation": 0.0,
  "textureFile": "assets/board.png",
  "zOrder": 0,
  "active": true,
  "visible": true,
  "draggable": false,
  "color": [255, 255, 255, 255],
  "tags": ["board"],
  "triggers": { "on_click": "board_clicked" },
  "luaScript": "scripts/board.lua",
  "presets": ["Highlightable"],
  "properties": { "score": 0 },
  "children": []
}
```

**Object types:** `"GameObject"` (base), `"Card"`, `"Chip"` (circular hit-test), `"Dice"`, `"Tile"` (grid cell), `"Deck"` (card stack)

### Dice

```json
{
  "type": "Dice",
  "id": "d6",
  "faceCount": 6,
  "value": 1,
  "faceTextures": [
    "assets/die1.png",
    "assets/die2.png",
    "assets/die3.png",
    "assets/die4.png",
    "assets/die5.png",
    "assets/die6.png"
  ]
}
```

`faceTextures[i]` maps to face value `i+1`. On scene load the texture matching the initial `value` is applied. Use `cpp_dice_roll(id)` from Lua — it rolls, updates `value`, and applies the face texture automatically.

### Card

```json
{
  "type": "Card",
  "id": "card_ace",
  "player": 0,
  "face_up": false
}
```

> **Limitation:** C++ has `setFrontTexture`/`setBackTexture`, but the scene loader never calls them — the visual texture is always `textureFile`. To simulate a flip, call `cpp_set_obj_texture(id, path)` from Lua.

### Deck

```json
{
  "type": "Deck",
  "id": "main_deck",
  "faceDown": true,
  "children": [
    { "type": "Card", "id": "card_1", "face_up": false, "textureFile": "assets/card_back.png" },
    { "type": "Card", "id": "card_2", "face_up": false, "textureFile": "assets/card_back.png" }
  ]
}
```

`faceDown: true` propagates `face_up = false` to all Card children at load time. Cards are ordered back-to-front — `cpp_deck_draw` pulls from the back (last child). Use `cpp_shuffle_children(id)` to shuffle.

### Tile

```json
{
  "type": "Tile",
  "id": "cell_0_0",
  "col": 0,
  "row": 0,
  "occupantId": "",
  "acceptedTypes": ["Chip", "Card"]
}
```

`acceptedTypes` empty = accepts all. Use `self:getCol()`, `self:getRow()`, `self:getOccupantId()`, `self:setOccupant(id)`, `self:clearOccupant()`, `self:isOccupied()`, `self:accepts(type)` from Lua.

### Chip

```json
{
  "type": "Chip",
  "id": "chip_red",
  "player": 1,
  "assetId": "red_chip",
  "radius": 32.0
}
```

Uses circular hit-test instead of AABB. `radius` scales with object scale. Use `self:getRadius()`, `self:setRadius(float)`, `self:getAssetId()`, `self:setAssetId(string)`, `self:getPlayer()`, `self:setPlayer(int)` from Lua.

## Lua API Quick Reference

### engine.*

| Call | Effect |
|------|--------|
| `engine.trigger(name, fn)` | Register named trigger used in JSON `"triggers"` |
| `engine.on(id, event, fn)` | Attach inline handler to object by id |
| `engine.onKey(key, fn)` | Keyboard handler — registering same key twice overwrites silently |
| `engine.getObject(id)` | Returns object or nil (O(1) lookup) |
| `engine.intersects(id1, id2)` | AABB collision → bool; returns false if either object not found |
| `engine.loadScene(path)` | Load new scene (deferred to next frame) |
| `engine.reloadScene()` | Reload current scene (deferred to next frame) |

**Supported key names:** `"A"`–`"Z"`, `"Space"`, `"Enter"`, `"Tab"`, `"Up"`, `"Down"`, `"Left"`, `"Right"`, `"1"`–`"5"`. No other keys are recognized. `Esc` is reserved — it closes the application and cannot be handled via `engine.onKey`.

### Global C++ Functions

| Call | Effect |
|------|--------|
| `cpp_rand(lo, hi)` | Random int in [lo, hi] inclusive |
| `cpp_shuffle(table)` | In-place shuffle Lua table |
| `cpp_shuffle_children(id)` | Shuffle object's children in-place |
| `cpp_draw_text_left(s, x, y, size, r, g, b)` | Left-aligned text (call from `draw()` only) |
| `cpp_draw_text_center(s, x, y, size, r, g, b)` | Centered text |
| `cpp_draw_text_right(s, x, y, size, r, g, b)` | Right-aligned text |
| `cpp_draw_rect(x, y, w, h, r, g, b, a)` | Filled rectangle |
| `cpp_set_obj_color(id, r, g, b, a)` | Set object color by id |
| `cpp_set_obj_texture(id, path)` | Load and apply texture by id (caches texture in ResourceManager) |
| `cpp_dice_roll(id)` | Roll die → int in [1, faceCount]; applies face texture automatically |
| `cpp_deck_draw(id)` | Remove top card from deck → move to scene root → return card id (or `""` if empty) |
| `cpp_deck_count(id)` | Number of cards remaining in deck → int |
| `cpp_log(msg)` | Log via spdlog + fires UI callback if registered |
| `log(msg)` | Log via spdlog only (no UI callback) |

**Available Lua libraries:** `base`, `math`, `string`, `table`. No `io`, `os`, `coroutine`, or `package`.

### GameObject Methods (via `self` in callbacks)

```lua
-- Identity
self:getId()              -- string
self:getName() / self:setName(s)
self:getType()            -- "GameObject" | "Card" | "Chip" | "Dice" | "Tile" | "Deck"

-- Transform
self:getX() / self:getY()
self:setPosition(x, y)
self:getRotation() / self:setRotation(deg)
self:getScaleX() / self:getScaleY() / self:setScale(x, y)
self:getZOrder() / self:setZOrder(z)

-- State
self:isVisible() / self:setVisible(bool)
self:isActive() / self:setActive(bool)   -- setActive(false) disables events on object and children
self:isDraggable() / self:setDraggable(bool)

-- Appearance
self:setColor(r, g, b, a)   -- 0-255

-- Custom properties (defined in JSON "properties": {})
self:getIntProperty(key, default)
self:getFloatProperty(key, default)
self:getStringProperty(key, default)
self:getBoolProperty(key, default)
self:setIntProperty(key, val)
self:setStringProperty(key, val)
-- setFloatProperty / setBoolProperty do NOT exist in Lua API

-- Tags
self:hasTag(tag)
self:getTags()
```

### Type-Specific Methods

`engine.getObject(id)` returns the concrete type — `self:getType()` returns `"Card"`, `"Chip"`, etc. and the matching extra methods are available.

**Card extras:** `self:flip()`, `self:isFaceUp()`, `self:setFaceUp(bool)`, `self:setPlayer(int)`, `self:getPlayer()`

**Chip extras:** `self:getRadius()`, `self:setRadius(float)`, `self:getAssetId()`, `self:setAssetId(string)`, `self:setPlayer(int)`, `self:getPlayer()`

**Dice extras:** `self:getFaceCount()`, `self:getValue()` — use `cpp_dice_roll(id)` to roll (updates value and applies face texture automatically)

**Tile extras:** `self:getCol()`, `self:getRow()`, `self:getOccupantId()`, `self:setOccupant(string)`, `self:clearOccupant()`, `self:isOccupied()`, `self:accepts(string)`

**Deck extras:** `self:isFaceDown()`, `self:count()`, `self:isEmpty()` — use `cpp_deck_draw(id)`, `cpp_deck_count(id)`, `cpp_shuffle_children(id)` for deck operations

## Event System

### Event Types

| Event | Fires when |
|-------|-----------|
| `on_click` | Non-draggable: mouse press. Draggable: mouse release without prior movement |
| `on_hover` | Cursor enters object bounds |
| `on_hover_exit` | Cursor leaves object bounds |
| `on_drag_start` | Mouse press on draggable object (fires immediately, before any movement) |
| `on_drag_end` | Mouse release from draggable object — fires always, including a click without movement |
| `on_move` | Object position changes during drag |

**Drag mechanics:** dragging activates only after the cursor moves 5 px from the press point — below that threshold nothing moves and the release counts as a click. The dragged object's position is **clamped to the field bounds**: if the scene contains an object with id `board`, its bounds become the drag area; otherwise the whole window. A drop zone outside the `board` bounds is unreachable by dragging (though `setPosition` can still place objects there).

**Important:** Scripts in `"scripts"` execute **before** objects are created — register all triggers (`engine.trigger`, `engine.on`, `engine.onKey`) there. On scene transition (`loadScene`/`reloadScene`) all handlers reset — re-register in the new scene's script.

### Two Registration Patterns

```lua
-- 1. Named trigger (referenced in JSON "triggers": { "on_click": "my_trigger" })
engine.trigger("my_trigger", function(self)
    cpp_log("clicked: " .. self:getId())
end)

-- 2. Inline (no JSON change needed)
engine.on("my_button", "on_click", function(self)
    cpp_log("clicked inline")
end)
```

### Global Frame Hooks

```lua
function update(dt)   -- called every frame (dt = delta time in seconds)
end

function draw()       -- called every frame after object rendering
    cpp_draw_text_center("Score: " .. score, 640, 30, 32, 255, 255, 0)
end
```

## Presets — Reusable Behaviors

### assets/presets.json

Presets come in two forms:

**File-based** — handler loaded from `path/file.lua:function_name`:
```json
{
  "presets": {
    "Highlightable": {
      "on_hover":      "scripts/presets/highlightable.lua:on_hover",
      "on_hover_exit": "scripts/presets/highlightable.lua:on_hover_exit"
    }
  }
}
```

**Trigger-based** — calls a named trigger that must exist in your game script:
```json
{
  "presets": {
    "Rollable": { "on_click": "roll_dice" }
  }
}
```

### Preset Script Structure

```lua
-- scripts/presets/highlightable.lua
return {
    on_hover = function(obj)
        obj:setColor(200, 100, 100, 255)
    end,
    on_hover_exit = function(obj)
        obj:setColor(255, 255, 255, 255)
    end
}
```

### Using in Scene JSON

```json
{ "id": "piece", "presets": ["Highlightable", "DragLift"] }
```

Explicit `"triggers"` in JSON override preset handlers for the same event. Unknown preset names produce a `warn` log but do not abort scene loading.

### Built-in Presets

| Preset | Events handled | Type |
|--------|---------------|------|
| `Highlightable` | on_hover, on_hover_exit | File-based |
| `HoverScale` | on_hover, on_hover_exit | File-based |
| `DragLift` | on_drag_start, on_drag_end | File-based |
| `Selectable` | on_click | File-based |
| `LogEvents` | all events | File-based |
| `Rollable` | on_click → `roll_dice` trigger | Trigger-based |
| `Checker` | on_drag_start/end → `checker_drag_start/end` triggers | Trigger-based |
| `PointMarker` | on_click → `dest_click` trigger | Trigger-based |

## Common Task Patterns

### Drag to Target (drop zone detection)

```lua
-- Store origin before drag
engine.trigger("piece_drag_start", function(self)
    self:setIntProperty("origin_x", math.floor(self:getX()))
    self:setIntProperty("origin_y", math.floor(self:getY()))
end)

-- Snap to slot or return to origin
engine.trigger("piece_dropped", function(self)
    local slots = {"slot_1", "slot_2", "slot_3"}
    for _, sid in ipairs(slots) do
        if engine.intersects(self:getId(), sid) then
            local s = engine.getObject(sid)
            self:setPosition(s:getX(), s:getY())
            return
        end
    end
    self:setPosition(
        self:getIntProperty("origin_x", 0),
        self:getIntProperty("origin_y", 0)
    )
end)
```

### Dice Roll with Face Textures

```lua
-- Scene JSON: { "type":"Dice","id":"d6","faceCount":6,"faceTextures":["d1.png",...] }
-- cpp_dice_roll handles rolling AND texture update automatically

engine.trigger("roll_die", function(self)
    local value = cpp_dice_roll(self:getId())
    cpp_log("Rolled: " .. value)
end)
```

### Deck Draw Pattern

```lua
engine.trigger("draw_card", function(self)
    if cpp_deck_count("main_deck") == 0 then
        cpp_log("Deck empty")
        return
    end
    local card_id = cpp_deck_draw("main_deck")
    local card = engine.getObject(card_id)
    card:setPosition(700, 400)
    cpp_set_obj_texture(card_id, "assets/card_front.png")  -- visual flip
end)

engine.onKey("S", function()
    cpp_shuffle_children("main_deck")
end)
```

### Turn-Based State

```lua
local state = { current_player = 1, has_acted = false }

engine.trigger("end_turn", function(self)
    if not state.has_acted then return end
    state.current_player = state.current_player == 1 and 2 or 1
    state.has_acted = false
end)

function update(dt)
    local btn = engine.getObject("player1_btn")
    if btn then btn:setActive(state.current_player == 1) end
end
```

### Simple Timer

```lua
local timer = 0
local INTERVAL = 2.0  -- seconds

function update(dt)
    timer = timer + dt
    if timer >= INTERVAL then
        timer = timer - INTERVAL
        -- do periodic action
    end
end
```

## Debugging

**Errors go to stdout** via spdlog. Run from terminal to capture them:

```bash
cd build && ./dice 2>&1 | tee game.log
```

**Log format for Lua errors:**
```
[error] LuaScriptEngine: global script error 'scripts/game.lua': [string]:12: attempt to index a nil value
[error] LuaScriptEngine: trigger 'my_trigger' on 'coin': [string]:5: stack overflow
```

**Log levels:**
| Level | What it means |
|-------|--------------|
| `[error]` | Script errors, scene load failure, JSON parse errors |
| `[warning]` | Unknown preset, overwritten `onKey` handler, empty Lua script path |
| `[info]` | `cpp_log()` output, scene loaded successfully |
| `[debug]` | Texture loads, dice rolls, script attachments |

**Debugging checklist:**

| Symptom | Check |
|---------|-------|
| Trigger never fires | Name must match exactly (case-sensitive) in JSON and `engine.trigger()` |
| `engine.getObject` returns nil | Typo in id, or object doesn't exist in current scene |
| Scene fails to load | Look for `SceneValidator` or JSON parse error in stdout |
| `cpp_draw_*` not showing | Must be called inside `function draw()` only |
| Key handler stops after scene change | `loadScene`/`reloadScene` clears all handlers — re-register in new script |
| Preset has no effect | Check preset name spelling; verify file-based presets reference correct `lua:function` path |

Use `cpp_log()` for output visible in-game. Use `log()` for terminal-only output.

## Engine Limitations

| Limitation | Workaround |
|-----------|-----------|
| No runtime object creation from Lua | Pre-create objects in JSON; show/hide with `setActive(false)` / `setVisible(false)` |
| No runtime object deletion from Lua | Hide with `setActive(false)` or move off-screen: `setPosition(-9999, -9999)` |
| No mouse position query from Lua | Track position via `on_hover` / `on_move` events |
| No built-in timer/delay | Accumulate `dt` in `update(dt)`: `timer = timer + dt` |
| No child iteration from Lua | Assign predictable ids in JSON; access each with `engine.getObject(id)` |
| `globalScript` runs before most API registration; its triggers are wiped on first scene load | Define plain global variables/functions there at most; register triggers in scene `"scripts"` instead |
| Dragging is clamped to the bounds of the object with id `board` (or the window if absent) | Keep all drop zones inside the `board` bounds, or don't use the id `board` for an object smaller than the play area |
| Network Lua functions (`is_host`, `is_client`, `send_event`, `send_move`) unavailable | `NetworkManager` is never instantiated by the application — the network library exists but is not wired in; single-player only |
| Card visual flip not implemented | Call `cpp_set_obj_texture(id, path)` manually to change the displayed texture |
| `setFloatProperty` / `setBoolProperty` absent | Use `setIntProperty` (0/1 for bool; scale float to int) |
| Key names limited to a fixed set | A–Z, Space, Enter, Tab, Up/Down/Left/Right, 1–5 only |
| Lua standard libraries limited | `base`, `math`, `string`, `table` only — no `io`, `os`, `coroutine`, `package` |
| ActionManager (undo/redo) not connected | Implement state rollback manually in Lua if needed |

## Complete Minimal Game

**game.json**
```json
{
  "title": "Coin Clicker",
  "windowWidth": 1280, "windowHeight": 720,
  "startScene": "scenes/main.json",
  "fonts": [{ "id": "default_font", "path": "assets/fonts/OpenSans-Regular.ttf" }]
}
```

**scenes/main.json**
```json
{
  "scripts": ["scripts/game.lua"],
  "objects": [
    {
      "type": "GameObject",
      "id": "coin",
      "position": [640, 360],
      "textureFile": "assets/coin.png",
      "draggable": false,
      "presets": ["HoverScale"],
      "triggers": { "on_click": "collect_coin" }
    }
  ]
}
```

**scripts/game.lua**
```lua
local score = 0

engine.trigger("collect_coin", function(self)
    score = score + 10
    self:setPosition(cpp_rand(100, 1180), cpp_rand(100, 700))
end)

engine.onKey("R", function()
    engine.reloadScene()
end)

function draw()
    cpp_draw_rect(0, 0, 1280, 50, 0, 0, 0, 180)
    cpp_draw_text_center("Score: " .. score, 640, 30, 32, 255, 255, 0)
end
```

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Trigger name in JSON doesn't match `engine.trigger(name, ...)` | Names are case-sensitive and must match exactly |
| Drawing outside `draw()` | `cpp_draw_*` only work inside the `draw()` global hook |
| Object not responding to clicks | Check `"active": true`; draggable: `on_click` fires on release, not press |
| Scene not loading | Paths in JSON are relative to the **build directory**, not source |
| Custom property missing | Define in JSON `"properties": {}` before calling `getIntProperty` etc. |
| `engine.getObject` returns nil | Object id typo, or object not in current scene |
| `engine.onKey` stops after scene change | All handlers reset on `loadScene`/`reloadScene` — re-register in new scene script |
| Trigger not firing on a specific object | `engine.on` in global script runs before objects exist; use `engine.trigger` + JSON `triggers` instead |
| Card flip has no visual effect | Call `cpp_set_obj_texture(card_id, path)` — C++ front/back textures are never loaded |
| `setFloatProperty` / `setBoolProperty` not found | These don't exist — use `setIntProperty` |
| `engine.intersects` always returns false | Verify both ids exist and bounding boxes actually overlap |
| Deck draw returns `""` | Deck empty — check with `cpp_deck_count(id)` before drawing |
| `engine.onKey` silently stops working | Second call with the same key overwrites the first; check for duplicate registrations |
| Dragged object stops at an invisible boundary | Drag is clamped to the bounds of the object with id `board` if one exists — enlarge it, move drop zones inside it, or rename its id |

## Build & Run

```bash
cmake . -B build && cmake --build build
cd build && ./dice
```

CMake copies `game.json`, `scenes/`, `scripts/`, `assets/` to the build folder automatically.
