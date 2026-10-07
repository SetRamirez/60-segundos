# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Proyecto
"60 segundos": juego de mesa 3D de preguntas por equipos (estilo Jackbox), hecho en **Godot 4.7**, con un servidor relay en **Node.js + `ws`** (WebSocket plano, no Socket.io; Express solo sirve `server/public/`). Hay cuatro categorías de preguntas. En su turno, cada equipo tiene 60 segundos para responder todas las que pueda, y gana el primero que llega al final del tablero.

- Godot corre en el PC anfitrión, en la pantalla grande. Los jugadores se unen desde el celular por la LAN.
- Servidor: `cd server && npm install && npm start` (escucha en `0.0.0.0:3000`; se cambia con `PORT=...`). No hay tests, linter ni build. `server/public/` se sirve tal cual.
- F5 abre el lobby (`Escenas/UI/lobby/lobby.tscn`, la escena principal). Con el servidor encendido muestra la URL y los jugadores; sin servidor dice "Conectando con el servidor…", pero "Comenzar juego" funciona igual. Para probar solo el tablero, abre `Escenas/Mundo.tscn` y pulsa F6: sin lobby, `mundo.gd` crea dos equipos de prueba.

## Idioma
- Responde siempre en español.
- Mantén en español los nombres que ya existen en el código (`PanelAcciones`, `turnoEquipoId`, `moverFicha`, etc.) y sigue esa convención al crear nombres nuevos.

## Arquitectura (respétala)
- **Autoload `GameManager`** (`Scripts/GameManager.gd`): guarda el estado y las reglas de la partida, y cambia de escena. **Solo datos, nunca nodos**: un autoload vive todo el juego, pero los nodos de una escena se destruyen al cambiar de escena. `equipos` es `{id: {nombre, posicion}}` (clave `int`, 1 o 2; `posicion` es la casilla). Avisa a las escenas mediante señales: `simular_dado`, `ficha_movida`, `turno_equipo_cambiado`.
- **Autoload `Hub`** (`Scripts/hub_client.gd`): el cliente WebSocket hacia el servidor. Se reconecta solo cada 2 s y sigue conectado al pasar del lobby a `Mundo`. Señales: `connection_changed`, `url_received`, `roster_received`, `player_joined`, `player_left`, `player_message`.
- **Lobby** (`Escenas/UI/lobby/lobby.tscn` + `lobby.gd`, con dos `TeamPanel`): muestra los jugadores de `Hub`. "Comenzar juego" → `GameManager.recibirDatos(nombre1, nombre2)` (usa `TeamPanel.nombre_equipo()`) → `crearEquipos` + `iniciar_partida` → `Mundo.tscn`.
- **`Mundo.tscn` / `mundo.gd`** maneja lo visual en 3D: la cámara, el dado (`dado.gd`), el `Path3D` del tablero y la secuencia del tiro.
- La UI son `CanvasLayer`s dentro de `Mundo.tscn`: `HUD/PanelAcciones` (el botón de tirar) y `Temporizador` (60 s).
- Cada ficha es `Escenas/equipo.tscn`, con el script `Scripts/jugador.gd` (`class_name Equipo`, aunque el archivo se llame "jugador"). Guarda `id`, `nombre` y `pathFicha`; la casilla no está en la ficha, sino en `GameManager.equipos`.
- **`Scripts/tablero.gd`** (en el nodo `Path3D` de `Mundo.tscn`) es el dueño de las fichas: `crearFichas()` (lo llama `mundo.gd` en su `_ready`, después de crear los equipos de prueba si hace falta), `animarFicha(movimiento)` y `actualizarOffsets()`.
- Las fichas se mueven con `PathFollow3D`. La distancia por casilla es la longitud baked de la curva dividida entre `NUMERO_CASILLAS - 1`. `NUMERO_CASILLAS` (61, incluida la salida) está en `GameManager.gd`. Si cambias la textura del tablero, hay que redibujar la curva y actualizar `NUMERO_CASILLAS`.
- Cuando dos fichas comparten casilla, `tablero.actualizarOffsets()` las separa con `h_offset`.
- Usa `call_deferred` cuando haya errores de árbol ocupado en los cambios de escena.
- Muchas conexiones de señales están en los `.tscn`, no en el código (busca `[connection` en `Escenas/`).
- Si un cambio rompe alguno de estos patrones, avísame antes de hacerlo y explica por qué.

### Flujo de un turno
Aviso de turno (`PanelAcciones` centrado con "Turno de X") → botón → `GameManager.tirarDado()` → `simular_dado` (el panel se oculta) → la cámara va a la mesa y el dado rueda → `tiro_finalizado` → la cámara vuelve → `GameManager.moverFicha()` (actualiza la casilla y devuelve `{id, inicio, tope, final}`) → `tablero.animarFicha()` → al terminar el Tween, `GameManager.terminarMovimiento()` → `ficha_movida` → `Temporizador.iniciar()` (solo si estaba parado) y el panel vuelve para poder tirar otra vez → `tiempo_agotado` → `GameManager.avanzarTurno()` → `turno_equipo_cambiado` → `Temporizador.reiniciar()` y aviso del nuevo equipo.

Para ganar hay que caer **exacto** en la última casilla. Si el dado da de más, `moverFicha` calcula el rebote (`tope` = última casilla, `final` = la casilla tras retroceder lo que se pasó) y `animarFicha` hace los dos tramos. Al caer exacto se emite `partida_terminada` en lugar de `ficha_movida`, y `mundo.gd` para el reloj, oculta el panel y muestra al ganador en `mensajeGanador`, un `Label3D` en el centro del tablero.

Solo se avanza dentro del minuto del turno. Si el reloj se agota durante una tirada, el turno cambia en ese momento y la tirada no cuenta: `mundo.gd` compara `GameManager.turno_actual` con el de cuando se pulsó tirar y no llama a `moverFicha`. El aviso del nuevo equipo espera a que termine la tirada descartada. Si la ficha ya estaba en movimiento, termina de moverse pero no arranca el reloj.

### Servidor (`server/server.js`)
- Los celulares se conectan a `/ws`. Godot se conecta a `/host` (`ws://127.0.0.1:3000/host`), que solo se acepta desde la misma máquina. Solo hay un host a la vez.
- El servidor solo maneja la lista de jugadores (nombre de 1 a 16 caracteres, equipo 1 o 2, máximo 20 por equipo) y reenvía mensajes. La lógica del juego va en Godot.
- Protocolo (JSON con campo `type`):
  - Celular → servidor: `join {name, team, id?}` y `leave`. Cualquier otro mensaje se reenvía a Godot como `player_message {id, data}`.
  - Godot → servidor: `send {id, data}` (a un jugador) y `broadcast {data}` (a todos).
  - Servidor → Godot: `info {url}`, `roster`, `player_joined`, `player_left` y `player_message`.
  - Servidor → celular: `joined`, `error {message}`, `left` y `counts {teams, max}` (cuántos hay en cada equipo).
- La URL del host está fija en `SERVER_URL` de `hub_client.gd`. Si arrancas el servidor con otro `PORT`, cámbiala también ahí.
- Reconexión: el celular guarda su `id` y lo reenvía con `join`. Si el `id` ya está en la lista, el servidor cambia el socket sin avisar a Godot.
- Si cambias el protocolo, hay que tocar los tres lados: `server/server.js`, `server/public/index.html` y `Scripts/hub_client.gd`.

### Cabos sueltos conocidos
- `Escenas/gameManager.tscn` existe, pero no se instancia en ninguna parte. No metas `GameManager` ni `Hub` en una escena: son autoloads, y otra instancia duplicaría su estado (y, en `Hub`, abriría una segunda conexión de host).

## Cómo explicarme los cambios
Estoy aprendiendo, así que explica lo que haces:
1. **Antes de modificar o crear un archivo:** 1-2 frases sobre qué vas a cambiar y por qué.
2. **Después de cada cambio:** resume qué hiciste y qué efecto tiene en el resto del proyecto (qué señales, nodos o mensajes del servidor se ven afectados).
3. **Conceptos no triviales** (señales, `Path3D`, `await`, `Tween`, WebSockets, async): explícalos en pocas líneas la primera vez que aparezcan.
4. **Alternativas:** si había otra opción razonable, dime brevemente por qué elegiste esta.
5. Un concepto a la vez; prefiero profundidad a un resumen amplio.

## Forma de trabajo
- Haz cambios pequeños y enfocados; no refactorices cosas que no te pedí.
- Si la petición es ambigua o toca varios sistemas a la vez, propón un plan y espera mi OK antes de editar.
- Si algo del cliente (Godot) y del servidor (Node) tiene que cambiar junto, dime qué toca de cada lado.
- No inventes nodos, señales ni eventos: revisa que existan en el proyecto antes de usarlos.
