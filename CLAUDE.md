# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Proyecto
"60 segundos": juego de mesa 3D de preguntas por equipos (estilo Jackbox), hecho en **Godot 4.7 .NET** con scripts en **C#**, con un servidor relay en **Node.js + `ws`** (WebSocket plano, no Socket.io; Express solo sirve `server/public/`). Hay cuatro categorías de preguntas. En su turno, cada equipo tiene 60 segundos para responder todas las que pueda, y gana el primero que llega al final del tablero.

- Godot corre en el PC anfitrión, en la pantalla grande. Los jugadores se unen desde el celular por la LAN.
- Godot: hace falta la edición **.NET** de Godot 4.7 (otra descarga distinta de la normal) y el SDK de .NET 8 o más nuevo. El proyecto C# es `60_segundos.csproj` (+ `60_segundos.sln`); el editor compila al pulsar F5, o se compila a mano con `dotnet build` en la raíz. El editor sube solo la versión de `Godot.NET.Sdk` del `.csproj` a la suya.
- Servidor: `cd server && npm install && npm start` (escucha en `0.0.0.0:3000`; se cambia con `PORT=...`). No hay tests, linter ni build. `server/public/` se sirve tal cual.
- F5 abre el lobby (`Lobby/lobby.tscn`, la escena principal). Con el servidor encendido muestra la URL y los jugadores; sin servidor dice "Conectando con el servidor…", pero "Comenzar juego" funciona igual. Para probar solo el tablero, abre `Mundo/Mundo.tscn` y pulsa F6: sin lobby, `Mundo.cs` crea dos equipos de prueba.

## Idioma
- Responde siempre en español.
- Mantén en español los nombres que ya existen en el código (`PanelAcciones`, `TurnoEquipoId`, `MoverFicha`, etc.) y sigue esa convención al crear nombres nuevos.
- Convención de C#: PascalCase para clases, métodos, propiedades, constantes y señales (`MoverFicha`, `NumeroCasillas`, `TurnoEquipoCambiado`); `_camelCase` para los campos privados (`_tiradaEnCurso`). Cada script se llama igual que su clase (`Tablero.cs` → `partial class Tablero`).

## Carpetas
Cada escena va junto a su script, agrupados por funcionalidad:
- `Globales/`: los autoloads (`GameManager.cs`, `HubClient.cs`) y las clases de datos que usan (`Movimiento.cs`, `Equipo.cs`, `Jugador.cs`). Estas tres son clases C# normales (no heredan de `Node` ni de `GodotObject`), así que no se pueden pasar por señales ni exportar.
- `Lobby/`: el lobby y los paneles de equipo.
- `Mundo/`: el tablero 3D. Dentro están `Dado/` (dado, raycasts, mesa), `Ficha/` (`equipo.tscn`) y `UI/` (`PanelAcciones` y `Temporizador`).
- `Assets/`: modelos y texturas.

Mueve o renombra archivos solo desde el panel FileSystem de Godot: así los `.uid` se mueven con los scripts y se actualizan las rutas de los `.tscn`. Las rutas `res://` escritas en los scripts no se actualizan solas (`ChangeSceneToFile` en `GameManager.cs` y `GD.Load` en `Tablero.cs`); búscalas con `grep -rn 'res://' --include=*.cs`. Si renombras un script C#, renombra también su clase: deben coincidir.

## Arquitectura (respétala)
- **Acceso a los autoloads**: en C# no hay nombre global como en GDScript. Cada autoload guarda su instancia en una propiedad estática al entrar en el árbol (`_EnterTree`): `GameManager.Instancia` y `HubClient.Instancia` (el autoload se sigue llamando `Hub` en `project.godot`). Si una escena se conecta a una señal de un autoload, se desconecta en su `_ExitTree` con `-=`, porque el autoload sobrevive a la escena.
- **Autoload `GameManager`** (`Globales/GameManager.cs`): guarda el estado y las reglas de la partida, y cambia de escena. **Solo datos, nunca nodos**: un autoload vive todo el juego, pero los nodos de una escena se destruyen al cambiar de escena. `Equipos` es `Dictionary<int, Equipo>` (clave 1 o 2; `Equipo` tiene `Nombre` y `Posicion`, que es la casilla). Las reglas se consultan con métodos (`MoverFicha`, `HaGanado`, `CategoriaDeCasilla`); la única señal es `TurnoEquipoCambiado`, porque el cambio de turno lo dispara el reloj y no la escena. `TurnoEquipoId` es el equipo que juega (1 o 2); `TurnoActual` es un contador que sube en cada `AvanzarTurno()` y sirve para descartar tiradas de un turno que ya acabó. Ambos solo se cambian desde dentro de `GameManager` (`private set`).
- **Autoload `Hub`** (`Globales/HubClient.cs`, clase `HubClient`): el cliente WebSocket hacia el servidor. Se reconecta solo cada 2 s y sigue conectado al pasar del lobby a `Mundo`. Señales: `ConnectionChanged`, `UrlReceived`, `RosterReceived`, `PlayerJoined`, `PlayerLeft`, `PlayerMessage`. Para enviar: `SendToPlayer(id, data)` y `Broadcast(data)` (`data` es un `Godot.Collections.Dictionary`, porque es JSON libre; si no hay conexión, no hacen nada). `Players` es una lista de `Jugador` (`Id`, `Nombre`, `EquipoId`) en orden de llegada y se vacía al desconectarse; es lista y no `Dictionary` porque el `Dictionary` de C# no garantiza el orden después de quitar elementos. Además están `IsServerOpen()` y `JoinUrl`.
- **Lobby** (`Lobby/lobby.tscn` + `Lobby.cs`, con dos `TeamPanel`): muestra los jugadores de `Hub`. `TeamPanel` no guarda la lista: todas las señales de jugadores de `Hub` van a `Lobby.cs::Refrescar()`, que lee `Hub.Players` y llama a `MostrarJugadores(nombres)` de cada panel. `TeamPanel.JugadoresPorEquipo` debe coincidir con `MAX_PER_TEAM` de `server.js`. "Comenzar juego" → `GameManager.RecibirDatos(nombre1, nombre2)` (usa `TeamPanel.NombreEquipo()`) → `PrepararPartida(nombres)` (equipos en la salida, primer turno sorteado, `TurnoActual = 0`) → `Mundo.tscn`. Con F6, `Mundo.cs` llama a la misma `PrepararPartida` con equipos de prueba.
- **`Mundo.tscn` / `Mundo.cs`** maneja lo visual en 3D: la cámara, el dado (`Dado.cs`), el `Path3D` del tablero y la secuencia del tiro. Toda la tirada es un solo método `async void Tirar()` con `await`: cada paso nuevo del turno (p. ej. las preguntas) va ahí, no en otra señal de ida y vuelta. El dado se lanza con `int valor = await _dado.Lanzar();` (`Lanzar` devuelve `Task<int>`), y para esperar una señal de Godot (un `Tween`, un timer) se usa `await ToSignal(objeto, Clase.SignalName.Señal)`.
- La UI son `CanvasLayer`s dentro de `Mundo.tscn`: `HUD/PanelAcciones` (el botón de tirar) y `Temporizador` (60 s). `PanelAcciones` (`PanelAcciones.cs`) expone `MostrarTurno(nombreEquipo)` (pone "Turno de X" y se muestra) y la señal `TirarPulsado`; para que no se pueda tirar, `Mundo.cs` lo oculta con `Hide()` (el botón nunca se deshabilita). `Temporizador` (`Temporizador.cs`) expone `Iniciar()`, `Reiniciar()` y la señal `TiempoAgotado`.
- Cada ficha es `Mundo/Ficha/equipo.tscn`: solo el modelo, sin script. Cuelga de un `PathFollow3D` que crea el tablero, y `Tablero.Fichas` es `Dictionary<int, PathFollow3D>`. La casilla no está en la ficha, sino en `GameManager.Equipos`.
- **`Mundo/Tablero.cs`** (en el nodo `Path3D` de `Mundo.tscn`) es el dueño de las fichas: `CrearFichas()`, `AnimarFicha(movimiento)` y `ActualizarOffsets()`. `CrearFichas()` se llama desde el `_Ready` de `Mundo.cs`, después de crear los equipos de prueba, y **no** desde el `_Ready` del tablero: en Godot los hijos ejecutan `_Ready` antes que el padre, así que con F6 el tablero aún no vería equipos. No lo muevas.
- Las fichas se mueven con `PathFollow3D`. La distancia por casilla es la longitud baked de la curva dividida entre `NumeroCasillas - 1`. `NumeroCasillas` (61, incluida la salida) está en `GameManager.cs`. En `TweenProperty` las propiedades se nombran como en Godot, en snake_case (`"progress"`, `"h_offset"`), no con el nombre de C#.
- El tablero es el modelo `Assets/tablero_montana/tablero_juego.glb` (nodo `tablero_montana` en el origen de `Mundo.tscn`): terreno simplificado, decoración nueva (vallas que bordean el camino, flora, letreros) y la colección `Casillas` (copiada de un `tablero_montana.blend` anterior, que ya no está en el repo; el archivo de Blender de `tablero_juego` tampoco está, y se exportó sin casillas). Si vuelves a exportarlo, incluye las casillas. El terreno usa el material externo `Assets/tablero_montana/Mat_Terreno.tres` (asignado en `tablero_juego.glb.import`, con `vertex_color_use_as_albedo`), porque sus colores van en los vértices; si reimportas el `.glb`, comprueba que siga asignado. Sus casillas son `Tile_000` (salida) … `Tile_060` (meta), separadas 1,53 entre sí. La curva del `Path3D` tiene un punto 0,14 sobre el centro de cada `Tile_XXX`. Si mueves la montaña, mueve el `Path3D` con ella. Si cambias el modelo en Blender, hay que regenerar los puntos de la curva desde las posiciones de los `Tile_XXX` y revisar `NumeroCasillas`.
- Categorías: en la montaña, la casilla 0 es la salida y desde la 1 los colores repiten azul, rojo, amarillo, verde, así que la categoría de la casilla N es `GameManager.Categorias[N % 4]`, con el orden verde, azul, rojo, amarillo (Interpretación, Arte, Conocimiento, Lenguaje). Se obtiene con `GameManager.Instancia.CategoriaDeCasilla(casilla)`; no se lee el color del modelo. Si cambias el modelo, revisa también este orden.
- Cuando dos fichas comparten casilla, `Tablero.ActualizarOffsets()` las separa con `HOffset`.
- Usa `CallDeferred` cuando haya errores de árbol ocupado en los cambios de escena.
- Hay una conexión de señal hecha en un `.tscn` y no en el código: `botonTirarDado.pressed` → `OnBotonTirarDadoPressed` (en `UI/panelAcciones.tscn`), que emite `TirarPulsado`. Si renombras ese método, cambia también el `method=` de la conexión. Las demás se hacen con `+=` en el `_Ready` de cada script (sobre todo `Mundo.cs` y `Lobby.cs`).
- Las propiedades `[Export]` se guardan en los `.tscn` con su nombre de C# (`TeamNumber`, `PanelColor`, `SlotScene`, `OppositeSide`). Si renombras una, cambia también los `.tscn` o se pierde el valor. Si añades una nueva desde el editor, búscala con `[connection` en los `.tscn`.
- Si un cambio rompe alguno de estos patrones, avísame antes de hacerlo y explica por qué.

### Flujo de un turno
Aviso de turno (`PanelAcciones` centrado con "Turno de X") → botón → `TirarPulsado` → `Mundo.cs::Tirar()`, que hace en orden: ocultar el panel → la cámara va a la mesa y `await _dado.Lanzar()` → la cámara vuelve → `GameManager.MoverFicha()` (actualiza la casilla y devuelve un `Movimiento`: `EquipoId`, `Inicio`, `Tope`, `Final`; un `record` en `Globales/Movimiento.cs`) → `await` de `Tablero.AnimarFicha()` → `GameManager.HaGanado()` → "Categoría: X" en el `Label3D` `mensajeCategoria` (que se oculta al tirar, al cambiar de turno y al ganar) → `Temporizador.Iniciar()` (solo si estaba parado) y el panel vuelve para poder tirar otra vez → `TiempoAgotado` → `GameManager.AvanzarTurno()` → `TurnoEquipoCambiado` → `Temporizador.Reiniciar()` y aviso del nuevo equipo.

Para ganar hay que caer **exacto** en la última casilla. Si el dado da de más, `MoverFicha` calcula el rebote (`Tope` = última casilla, `Final` = la casilla tras retroceder lo que se pasó) y `AnimarFicha` hace los dos tramos. Al caer exacto, `HaGanado()` da `true` y `Mundo.cs` (`MostrarGanador`) para el reloj, oculta el panel y muestra al ganador en `mensajeGanador`, un `Label3D` en el centro del tablero.

Solo se avanza dentro del minuto del turno. Si el reloj se agota durante una tirada, el turno cambia en ese momento y la tirada no cuenta: `Tirar()` guarda `GameManager.TurnoActual` al empezar y lo compara al volver la cámara (si cambió, no llama a `MoverFicha`) y al acabar (si cambió, no hay categoría ni reloj). El aviso del nuevo equipo espera a que termine la tirada descartada (`_tiradaEnCurso`). Si la ficha ya estaba en movimiento, termina de moverse (y puede ganar) pero no arranca el reloj.

### Servidor (`server/server.js`)
- Los celulares se conectan a `/ws`. Godot se conecta a `/host` (`ws://127.0.0.1:3000/host`), que solo se acepta desde la misma máquina. Solo hay un host a la vez.
- El servidor solo maneja la lista de jugadores (nombre de 1 a 16 caracteres, equipo 1 o 2, máximo 20 por equipo) y reenvía mensajes. La lógica del juego va en Godot.
- Protocolo (JSON con campo `type`):
  - Celular → servidor: `join {name, team, id?}` y `leave`. Cualquier otro mensaje se reenvía a Godot como `player_message {id, data}`.
  - Godot → servidor: `send {id, data}` (a un jugador) y `broadcast {data}` (a todos).
  - Servidor → Godot: `info {url}`, `roster`, `player_joined`, `player_left` y `player_message`.
  - Servidor → celular: `joined`, `error {message}`, `left` y `counts {teams, max}` (cuántos hay en cada equipo).
- La URL del host está fija en `ServerUrl` de `HubClient.cs`. Si arrancas el servidor con otro `PORT`, cámbiala también ahí.
- Reconexión: el celular guarda su `id` y lo reenvía con `join`. Si el `id` ya está en la lista, el servidor cambia el socket sin avisar a Godot.
- Si cambias el protocolo, hay que tocar los tres lados: `server/server.js`, `server/public/index.html` y `Globales/HubClient.cs`.

### Cabos sueltos conocidos
- Las preguntas aún no están implementadas: ya se sabe la categoría de cada casilla (`MostrarCategoria()` en `Mundo.cs`), pero todavía no hay datos de preguntas ni mensajes del protocolo para responderlas. Hoy un turno es tirar el dado, mover la ficha, mostrar la categoría y esperar al reloj.
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
