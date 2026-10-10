# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Proyecto
"60 segundos": juego de mesa 3D de preguntas por equipos (estilo Jackbox), hecho en **Godot 4.7**, con un servidor relay en **Node.js + `ws`** (WebSocket plano, no Socket.io; Express solo sirve `server/public/`). Hay cuatro categorías de preguntas. En su turno, cada equipo tiene 60 segundos para responder todas las que pueda, y gana el primero que llega al final del tablero.

- Godot corre en el PC anfitrión, en la pantalla grande. Los jugadores se unen desde el celular por la LAN.
- Servidor: `cd server && npm install && npm start` (escucha en `0.0.0.0:3000`; se cambia con `PORT=...`). No hay tests, linter ni build. `server/public/` se sirve tal cual.
- F5 abre el lobby (`Lobby/lobby.tscn`, la escena principal). Con el servidor encendido muestra la URL y los jugadores; sin servidor dice "Conectando con el servidor…", pero "Comenzar juego" funciona igual. Para probar solo el tablero, abre `Mundo/Mundo.tscn` y pulsa F6: sin lobby, `mundo.gd` crea dos equipos de prueba.

## Idioma
- Responde siempre en español.
- Mantén en español los nombres que ya existen en el código (`PanelAcciones`, `turnoEquipoId`, `moverFicha`, etc.) y sigue esa convención al crear nombres nuevos.

## Carpetas
Cada escena va junto a su script, agrupados por funcionalidad:
- `Globales/`: los autoloads (`GameManager.gd`, `hub_client.gd`).
- `Lobby/`: el lobby y los paneles de equipo.
- `Mundo/`: el tablero 3D. Dentro están `Dado/` (dado, raycasts, mesa), `Ficha/` (`equipo.tscn`) y `UI/` (`PanelAcciones` y `Temporizador`).
- `Assets/`: modelos y texturas.

Mueve o renombra archivos solo desde el panel FileSystem de Godot: así los `.uid` se mueven con los scripts y se actualizan las rutas de los `.tscn`. Las rutas `res://` escritas en los scripts no se actualizan solas (`change_scene_to_file` en `GameManager.gd` y `preload` en `tablero.gd`); búscalas con `grep -rn 'res://' --include=*.gd`.

## Arquitectura (respétala)
- **Autoload `GameManager`** (`Globales/GameManager.gd`): guarda el estado y las reglas de la partida, y cambia de escena. **Solo datos, nunca nodos**: un autoload vive todo el juego, pero los nodos de una escena se destruyen al cambiar de escena. `equipos` es `{id: {nombre, posicion}}` (clave `int`, 1 o 2; `posicion` es la casilla). Las reglas se consultan con funciones (`moverFicha`, `haGanado`, `categoriaDeCasilla`); la única señal es `turno_equipo_cambiado`, porque el cambio de turno lo dispara el reloj y no la escena. `turnoEquipoId` es el equipo que juega (1 o 2); `turno_actual` es un contador que sube en cada `avanzarTurno()` y sirve para descartar tiradas de un turno que ya acabó.
- **Autoload `Hub`** (`Globales/hub_client.gd`): el cliente WebSocket hacia el servidor. Se reconecta solo cada 2 s y sigue conectado al pasar del lobby a `Mundo`. Señales: `connection_changed`, `url_received`, `roster_received`, `player_joined`, `player_left`, `player_message`. Para enviar: `Hub.send_to_player(id, data)` y `Hub.broadcast(data)` (si no hay conexión, no hacen nada). `Hub.players` es `{id: {name, team}}` (el `id` es `String`) y se vacía al desconectarse; además están `Hub.is_server_open()` y `Hub.join_url`.
- **Lobby** (`Lobby/lobby.tscn` + `lobby.gd`, con dos `TeamPanel`): muestra los jugadores de `Hub`. `TeamPanel` no guarda la lista: todas las señales de jugadores de `Hub` van a `lobby.gd::_refrescar()`, que lee `Hub.players` y llama a `mostrar_jugadores(nombres)` de cada panel. `TeamPanel.JUGADORES_POR_EQUIPO` debe coincidir con `MAX_PER_TEAM` de `server.js`. "Comenzar juego" → `GameManager.recibirDatos(nombre1, nombre2)` (usa `TeamPanel.nombre_equipo()`) → `crearEquipos` + `iniciar_partida` → `Mundo.tscn`.
- **`Mundo.tscn` / `mundo.gd`** maneja lo visual en 3D: la cámara, el dado (`dado.gd`), el `Path3D` del tablero y la secuencia del tiro. Toda la tirada es una sola función con `await`, `_tirar()`: cada paso nuevo del turno (p. ej. las preguntas) va ahí, no en otra señal de ida y vuelta. El dado se lanza con `var valor: int = await dado.lanzar()`.
- La UI son `CanvasLayer`s dentro de `Mundo.tscn`: `HUD/PanelAcciones` (el botón de tirar) y `Temporizador` (60 s). `PanelAcciones` (`panel_acciones.gd`) expone `mostrar_turno(nombreEquipo)` (pone "Turno de X", habilita el botón y se muestra), `configurar_estado(puedeTirar)` y la señal `tirar_pulsado`; para ocultarlo, `mundo.gd` usa `hide()`/`show()`. `Temporizador` expone `iniciar()`, `reiniciar()` y la señal `tiempo_agotado`.
- Cada ficha es `Mundo/Ficha/equipo.tscn`: solo el modelo, sin script. Cuelga de un `PathFollow3D` que crea el tablero, y `tablero.fichas` es `{id: PathFollow3D}`. La casilla no está en la ficha, sino en `GameManager.equipos`.
- **`Mundo/tablero.gd`** (en el nodo `Path3D` de `Mundo.tscn`) es el dueño de las fichas: `crearFichas()`, `animarFicha(movimiento)` y `actualizarOffsets()`. `crearFichas()` se llama desde el `_ready` de `mundo.gd`, después de crear los equipos de prueba, y **no** desde el `_ready` del tablero: en Godot los hijos ejecutan `_ready` antes que el padre, así que con F6 el tablero aún no vería equipos. No lo muevas.
- Las fichas se mueven con `PathFollow3D`. La distancia por casilla es la longitud baked de la curva dividida entre `NUMERO_CASILLAS - 1`. `NUMERO_CASILLAS` (61, incluida la salida) está en `GameManager.gd`.
- El tablero es el modelo `Assets/tablero_montana/tablero_juego.glb` (nodo `tablero_montana` en el origen de `Mundo.tscn`): terreno simplificado, decoración nueva (vallas que bordean el camino, flora, letreros) y la colección `Casillas` (copiada de un `tablero_montana.blend` anterior, que ya no está en el repo; el archivo de Blender de `tablero_juego` tampoco está, y se exportó sin casillas). Si vuelves a exportarlo, incluye las casillas. El terreno usa el material externo `Assets/tablero_montana/Mat_Terreno.tres` (asignado en `tablero_juego.glb.import`, con `vertex_color_use_as_albedo`), porque sus colores van en los vértices; si reimportas el `.glb`, comprueba que siga asignado. Sus casillas son `Tile_000` (salida) … `Tile_060` (meta), separadas 1,53 entre sí. La curva del `Path3D` tiene un punto 0,14 sobre el centro de cada `Tile_XXX`. Si mueves la montaña, mueve el `Path3D` con ella. Si cambias el modelo en Blender, hay que regenerar los puntos de la curva desde las posiciones de los `Tile_XXX` y revisar `NUMERO_CASILLAS`.
- Categorías: en la montaña, la casilla 0 es la salida y desde la 1 los colores repiten azul, rojo, amarillo, verde, así que la categoría de la casilla N es `GameManager.CATEGORIAS[N % 4]`, con el orden verde, azul, rojo, amarillo (Interpretación, Arte, Conocimiento, Lenguaje). Se obtiene con `GameManager.categoriaDeCasilla(casilla)`; no se lee el color del modelo. Si cambias el modelo, revisa también este orden.
- Cuando dos fichas comparten casilla, `tablero.actualizarOffsets()` las separa con `h_offset`.
- Usa `call_deferred` cuando haya errores de árbol ocupado en los cambios de escena.
- Hay una conexión de señal hecha en un `.tscn` y no en el código: `botonTirarDado.pressed` → `_on_boton_tirar_dado_pressed` (en `UI/panelAcciones.tscn`), que emite `tirar_pulsado`. Las demás se hacen con `.connect()` en el `_ready` de `mundo.gd`. Si añades una nueva desde el editor, búscala con `[connection` en los `.tscn`.
- Si un cambio rompe alguno de estos patrones, avísame antes de hacerlo y explica por qué.

### Flujo de un turno
Aviso de turno (`PanelAcciones` centrado con "Turno de X") → botón → `tirar_pulsado` → `mundo.gd::_tirar()`, que hace en orden: ocultar el panel → la cámara va a la mesa y `await dado.lanzar()` → la cámara vuelve → `GameManager.moverFicha()` (actualiza la casilla y devuelve `{id, inicio, tope, final}`) → `await tablero.animarFicha()` → `GameManager.haGanado()` → "Categoría: X" en el `Label3D` `mensajeCategoria` (que se oculta al tirar, al cambiar de turno y al ganar) → `Temporizador.iniciar()` (solo si estaba parado) y el panel vuelve para poder tirar otra vez → `tiempo_agotado` → `GameManager.avanzarTurno()` → `turno_equipo_cambiado` → `Temporizador.reiniciar()` y aviso del nuevo equipo.

Para ganar hay que caer **exacto** en la última casilla. Si el dado da de más, `moverFicha` calcula el rebote (`tope` = última casilla, `final` = la casilla tras retroceder lo que se pasó) y `animarFicha` hace los dos tramos. Al caer exacto, `haGanado()` da `true` y `mundo.gd` (`_mostrar_ganador`) para el reloj, oculta el panel y muestra al ganador en `mensajeGanador`, un `Label3D` en el centro del tablero.

Solo se avanza dentro del minuto del turno. Si el reloj se agota durante una tirada, el turno cambia en ese momento y la tirada no cuenta: `_tirar()` guarda `GameManager.turno_actual` al empezar y lo compara al volver la cámara (si cambió, no llama a `moverFicha`) y al acabar (si cambió, no hay categoría ni reloj). El aviso del nuevo equipo espera a que termine la tirada descartada (`_tirada_en_curso`). Si la ficha ya estaba en movimiento, termina de moverse (y puede ganar) pero no arranca el reloj.

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
- Si cambias el protocolo, hay que tocar los tres lados: `server/server.js`, `server/public/index.html` y `Globales/hub_client.gd`.

### Cabos sueltos conocidos
- Las preguntas aún no están implementadas: ya se sabe la categoría de cada casilla (`_mostrar_categoria()` en `mundo.gd`), pero todavía no hay datos de preguntas ni mensajes del protocolo para responderlas. Hoy un turno es tirar el dado, mover la ficha, mostrar la categoría y esperar al reloj.
- `Globales/gameManager.tscn` existe, pero no se instancia en ninguna parte. No metas `GameManager` ni `Hub` en una escena: son autoloads, y otra instancia duplicaría su estado (y, en `Hub`, abriría una segunda conexión de host).

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
