# CLAUDE.md

## Proyecto
"60 segundos": juego de mesa 3D de preguntas por equipos (estilo Jackbox), hecho en **Godot 4.7**, con un servidor relay en **Node.js + `ws`** (WebSocket plano, no Socket.io). Hay cuatro categorías de preguntas. En su turno, cada equipo tiene 60 segundos para responder todas las que pueda, y gana el primero que llega al final del tablero.

- Godot corre en el PC anfitrión, en la pantalla grande. Los jugadores se unen desde el celular por la LAN.
- Servidor: `cd server && npm install && npm start` (escucha en `0.0.0.0:3000`; se cambia con `PORT=...`). No hay tests, linter ni build. `server/public/` se sirve tal cual.
- F5 (escena principal) está roto: `GameManager.EmpezarLobby` carga `res://Escenas/lobby_2d.tscn`, que ya no existe. Para probar el tablero, abre `Escenas/Mundo.tscn` y pulsa F6; sin lobby, `mundo.gd` crea dos fichas de prueba.

## Idioma
- Responde siempre en español.
- Mantén en español los nombres que ya existen en el código (`colaFichasPendientes`, `PanelAcciones`, `turnoEquipoId`, `moverFicha`, etc.) y sigue esa convención al crear nombres nuevos.

## Arquitectura (respétala)
- **Autoload `GameManager`** (`Scripts/GameManager.gd`): guarda el estado de la partida (equipos, `turnoEquipoId`) y cambia de escena. Avisa a las escenas mediante señales: `simular_dado`, `ficha_movida`, `turno_equipo_cambiado`.
- **`Hub`** (`Scripts/hub_client.gd`): el cliente WebSocket hacia el servidor. Va a ser un autoload, pero **todavía no está registrado** en `project.godot`.
- **`Mundo.tscn` / `mundo.gd`** maneja lo visual en 3D: la cámara, el dado (`dado.gd`), el `Path3D` del tablero y la secuencia del tiro.
- La UI son `CanvasLayer`s dentro de `Mundo.tscn`: `HUD/PanelAcciones` (el botón de tirar) y `Temporizador` (60 s).
- Las fichas se mueven con `PathFollow3D`. La distancia por casilla es la longitud baked de la curva dividida entre `NUMERO_CASILLAS - 1`. Si cambias la textura del tablero, hay que redibujar la curva y actualizar `NUMERO_CASILLAS`.
- `colaFichasPendientes` guarda las fichas pedidas antes de que exista el `Path3D`, para evitar problemas de timing entre los datos del lobby y la escena lista.
- Cuando dos fichas comparten casilla, `actualizarOffsets()` las separa con `h_offset`.
- Usa `call_deferred` cuando haya errores de árbol ocupado en los cambios de escena.
- Muchas conexiones de señales están en los `.tscn`, no en el código (busca `[connection` en `Escenas/`).
- Si un cambio rompe alguno de estos patrones, avísame antes de hacerlo y explica por qué.

### Flujo de un turno
Aviso de turno (`PanelAcciones` centrado con "Turno de X") → botón → `GameManager.tirarDado()` → `simular_dado` (el panel se oculta) → la cámara va a la mesa y el dado rueda → `tiro_finalizado` → la cámara vuelve → `GameManager.moverFicha()` → `ficha_movida` → `Temporizador.iniciar()` (solo si estaba parado) y el panel vuelve para poder tirar otra vez → `tiempo_agotado` → `GameManager.avanzarTurno()` → `turno_equipo_cambiado` → `Temporizador.reiniciar()` y aviso del nuevo equipo.

Para ganar hay que caer **exacto** en la última casilla. Si el dado da de más, `moverFicha` lleva la ficha hasta el final y la hace retroceder las casillas que se pasó. Al caer exacto se emite `partida_terminada` en lugar de `ficha_movida`, y `mundo.gd` para el reloj, oculta el panel y muestra al ganador.

Solo se avanza dentro del minuto del turno. Si el reloj se agota durante una tirada, el turno cambia en ese momento y la tirada no cuenta: `mundo.gd` compara `GameManager.turno_actual` con el de cuando se pulsó tirar y no llama a `moverFicha`. El aviso del nuevo equipo espera a que termine la tirada descartada. Si la ficha ya estaba en movimiento, termina de moverse pero no arranca el reloj.

### Servidor (`server/server.js`)
- Los celulares se conectan a `/ws`. Godot se conecta a `/host` (`ws://127.0.0.1:3000/host`), que solo se acepta desde la misma máquina. Solo hay un host a la vez.
- El servidor solo maneja la lista de jugadores (nombre de 1 a 16 caracteres, equipo 1 o 2, máximo 20 por equipo) y reenvía mensajes. La lógica del juego va en Godot.
- Protocolo (JSON con campo `type`):
  - Celular → servidor: `join {name, team, id?}` y `leave`. Cualquier otro mensaje se reenvía a Godot como `player_message {id, data}`.
  - Godot → servidor: `send {id, data}` (a un jugador) y `broadcast {data}` (a todos).
  - Servidor → Godot: `info {url}`, `roster`, `player_joined`, `player_left` y `player_message`.
- Reconexión: el celular guarda su `id` y lo reenvía con `join`. Si el `id` ya está en la lista, el servidor cambia el socket sin avisar a Godot.
- Si cambias el protocolo, hay que tocar los tres lados: `server/server.js`, `server/public/index.html` y `Scripts/hub_client.gd`.

### Cabos sueltos conocidos
- El lobby no está terminado: `Escenas/UI/lobby/lobby.tscn` no tiene script y `Scripts/lobby.tscn` es una copia con rutas rotas.
- `Escenas/UI/UI.tscn` / `ui.gd` es una copia muerta del HUD (llama a `solicitar_tirar_dado`, que no existe). `GameManager.conectar_dado` no se usa.
- `Escenas/main.tscn` instancia `gameManager.tscn`, así que hay un segundo `GameManager` además del autoload.

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
