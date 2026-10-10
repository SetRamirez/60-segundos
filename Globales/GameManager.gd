extends Node
# GameManager.gd
# Estado y reglas de la partida. Solo guarda datos: las fichas (nodos) las crea y anima
# el tablero de Mundo (tablero.gd), porque los nodos se destruyen al cambiar de escena
# y este autoload vive durante todo el juego.
const NUMERO_CASILLAS = 61  # casillas Tile_000..Tile_060 de tablero_juego.glb, incluida la de salida
## Categoría de cada color del tablero. En la montaña, la casilla 0 es la salida y desde la 1
## los colores repiten azul, rojo, amarillo, verde: la casilla N tiene la categoría
## CATEGORIAS[N % 4] (las verdes dan 0). Si cambia el modelo del tablero, hay que revisar este orden.
const CATEGORIAS = ["Interpretación", "Arte", "Conocimiento", "Lenguaje"]  # verde, azul, rojo, amarillo
var turno_actual: int = 0
var turnoEquipoId: int;
## id del equipo (1 o 2) -> {"nombre": String, "posicion": int (casilla, 0 = salida)}
var equipos: Dictionary = {}

signal turno_equipo_cambiado(equipoId: int)

# Deja lista una partida nueva: los equipos en la salida, el primer turno sorteado y el
# contador de turnos a cero. No cambia de escena, para que Mundo.tscn con F6 la use también.
# El id de cada equipo es su orden en la lista (1, 2...).
func prepararPartida(nombres: Array) -> void:
	equipos.clear()
	for i in nombres.size():
		equipos[i + 1] = {"nombre": nombres[i], "posicion": 0}
	turno_actual = 0
	turnoEquipoId = randi_range(1, 2)

# Desde el lobby: prepara la partida y pasa al tablero.
func recibirDatos(nombre1: String, nombre2: String):
	prepararPartida([nombre1, nombre2])
	get_tree().change_scene_to_file("res://Mundo/Mundo.tscn")

# Mueve en los datos la ficha del equipo en turno y devuelve el recorrido para animarlo.
func moverFicha(casillas: int) -> Movimiento:
	var equipo: Dictionary = equipos[turnoEquipoId]  # siempre existe: lo crea prepararPartida

	# Para ganar hay que caer exacto en la última casilla: si sobran puntos,
	# la ficha llega al final y retrocede las casillas que se pasó.
	var ultima := NUMERO_CASILLAS - 1
	var inicio: int = equipo.posicion
	var destino: int = inicio + casillas
	var exceso := maxi(destino - ultima, 0)
	equipo.posicion = maxi(destino - 2 * exceso, 0)
	return Movimiento.new(turnoEquipoId, inicio, mini(destino, ultima), equipo.posicion)

# Se gana al caer exacto en la última casilla (moverFicha ya calcula el rebote).
func haGanado(equipoId: int) -> bool:
	return equipos[equipoId].posicion == NUMERO_CASILLAS - 1

func categoriaDeCasilla(casilla: int) -> String:
	return CATEGORIAS[casilla % CATEGORIAS.size()]

func avanzarTurno():
	#Cambiar turnos
	if turnoEquipoId ==1:
		turnoEquipoId =2
	else :
		turnoEquipoId =1
	turno_actual += 1
	turno_equipo_cambiado.emit(turnoEquipoId)
