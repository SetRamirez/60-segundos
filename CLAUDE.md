# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

"60 segundos": a team-based timed quiz board game. Two parts:

- **Godot 4.7 game** (repo root: `project.godot`, `Scripts/`, `Escenas/`, `Assets/`). Forward Plus, Jolt physics, d3d12 on Windows. Runs on the host PC, shown on a big screen.
- **Node relay server** (`server/`). Players join from their phones over the LAN; the server sits between the phones and Godot.

Code, identifiers and user-facing strings are in Spanish — keep it that way.

## Commands

```sh
cd server && npm install && npm start   # listens on 0.0.0.0:3000 (override with PORT=...)
```

Then run the project from the Godot editor. There are no tests, linter, or build step. `server/public/` is served statically as-is (plain HTML/JS, no bundler).

- Running the main scene (F5) currently breaks: `GameManager._ready` jumps straight to the missing `lobby_2d.tscn` (see loose ends). To test the board, open `Escenas/Mundo.tscn` and press F6.
- Many signal connections live in `.tscn` files rather than in code. For example, `Mundo.tscn` connects `Dado.tiro_finalizado` to `mundo.gd`. To trace a flow, grep `\[connection` in `Escenas/`.

## Godot game

- **Autoload `GameManager`** (`Scripts/GameManager.gd`) holds game state and drives scene changes: `_ready` → lobby scene → `recibirDatos(nombre1, nombre2)` → `iniciar_partida()` picks a random starting team and loads `Escenas/Mundo.tscn`.
- **Board**: `Mundo.tscn` (`mundo.gd`) calls `GameManager.registarPath($Path3D)` on ready. Team pieces (`Escenas/equipo.tscn`, script `jugador.gd`, `class_name Equipo`) are spawned as children of a `PathFollow3D` on that path. If a piece is requested before the path exists, it is queued in `colaFichasPendientes`. The `Path3D` curve in `Mundo.tscn` passes through the centers of the 61 squares on `tablero-textura.png`. It is a spiral that starts at the bottom-right corner, `(13,0,8)`; each square is 2×2 world units. Movement tweens `PathFollow3D.progress` to `posicion * baked_length / (NUMERO_CASILLAS - 1)`. If you change the board texture, you have to redraw that curve and update `NUMERO_CASILLAS`.
- **Dice**: `dado.gd` is a physics `RigidBody3D` with child `RayCast3D`s (`raycast_dado.gd`, each exporting `opposite_side`). When the body goes to sleep, the colliding raycast's value is emitted as `tiro_finalizado`. `GameManager.conectar_dado` wires that to `moverFicha`.
- **UI**: `Escenas/UI/UI.tscn` (`ui.gd`) hosts `panelAcciones` (the roll button) and `temporizador` (a `Timer` shown as text).
- **Lobby**: `Escenas/UI/lobby/lobby.tscn` + `Scripts/lobby.gd` show two `TeamPanel`s (`team_panel.gd`) filled from the `Hub` autoload's signals.

### Known loose ends (work in progress — verify before relying on them)

- `Hub` (`Scripts/hub_client.gd`) is not yet registered in `[autoload]` in `project.godot`.
- `Escenas/UI/lobby/lobby.tscn` has no script attached. `Scripts/lobby.tscn` is a stray copy pointing at nonexistent `res://scenes/lobby/...` paths.
- `GameManager.EmpezarLobby` loads `res://Escenas/lobby_2d.tscn`, which no longer exists.
- Roll flow that works: `Mundo.tscn` → `HUD/PanelAcciones` button → `GameManager.tirarDado()` → signal `simular_dado` → `dado._tirar()`. `Escenas/UI/UI.tscn` / `ui.gd` is a dead copy of this: it looks for `$HUD/PanelAcciones` (not in that scene) and calls a nonexistent `solicitar_tirar_dado`.
- Camera sequence in `mundo.gd`: on `simular_dado`, the camera moves to `vistaMesaDados` (only the marker's position is used; the camera keeps its downward rotation). On `tiro_finalizado`, it waits `pausa_resultado`, returns to its saved transform, and only then calls `GameManager.moverFicha` to move the piece of `turnoEquipoId`. `GameManager.conectar_dado` is unused. `avanzarTurno` is never called, so the same team keeps moving.
- When `Mundo.tscn` runs directly (F6), with no lobby, `mundo.gd` creates two test pieces.
- `avanzarTurno` uses `==` where it means `=`.
- `Escenas/main.tscn` (the main scene) also instances `gameManager.tscn`, so a second `GameManager` node exists alongside the autoload. That node runs its own `_ready`, which also calls `EmpezarLobby`.

## Relay server (`server/server.js`)

- **Phones** load `server/public/index.html` and open a WebSocket to `/ws`.
- **Godot** connects to `/host` (`ws://127.0.0.1:3000/host`, hardcoded in `Scripts/hub_client.gd`). The upgrade handler rejects `/host` from any non-loopback address. Only one host connects at a time; a new host connection closes the previous one.
- The server owns the player roster (`players` Map, in memory only) and enforces the join rules: name ≤16 chars, team 1 or 2, and `MAX_PER_TEAM` = 20. Game logic belongs in Godot. Apart from managing the roster, the server only relays messages.

### Message protocol (JSON, `type` field)

- **Phone → server**: `join {name, team, id?}` and `leave`. Anything else from a joined player is forwarded to Godot wrapped as `player_message {id, data}`.
- **Server → phone**: `joined {id,name,team}`, `left`, `error {message}`, and `counts {teams, max}`. `counts` is broadcast to every connected socket, whether it has joined or not. Phones also receive any payload Godot sends.
- **Godot → server**: `send {id, data}` goes to one player and `broadcast {data}` goes to all joined players. `data` is delivered to the phone unwrapped.
- **Server → Godot**: `info {url}` (the LAN URL for phones) and `roster {players}` on connect, then `player_joined`, `player_left` and `player_message`.

When changing the protocol, update all three ends: `server/server.js`, `server/public/index.html`, and `Scripts/hub_client.gd`.

### Reconnects

The phone stores its `{id, name, team}` in localStorage and re-sends `join` with that `id` on reconnect. If the id (12 hex chars) is already in the roster, the server swaps in the new socket and replies `joined` *without* notifying Godot, so page reloads are invisible to the game. A player is removed (and `player_left` sent) only on an explicit `leave`, or when their current socket closes.

### Godot side of the connection

`hub_client.gd` (intended autoload `Hub`):
- reconnects every 2 seconds;
- mirrors the roster in `Hub.players` (`id -> {name, team}`) and clears it on disconnect;
- exposes signals plus `send_to_player(id, data)` and `broadcast(data)`.
