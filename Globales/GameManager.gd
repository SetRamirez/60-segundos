extends Node
# GameManager.gd
# Estado y reglas de la partida. Solo guarda datos: las fichas (nodos) las crea y anima
# el tablero de Mundo (tablero.gd), porque los nodos se destruyen al cambiar de escena
# y este autoload vive durante todo el juego.
const NUMERO_CASILLAS = 61  # casillas del Path3D de Mundo.tscn, incluida la de salida
var turno_actual: int = 0
var turnoEquipoId: int;
## id del equipo (1 o 2) -> {"nombre": String, "posicion": int (casilla, 0 = salida)}
var equipos: Dictionary = {}

signal simular_dado
signal ficha_movida(equipoId: int)  # al terminar la animación del movimiento (terminarMovimiento)
signal turno_equipo_cambiado(equipoId: int)
signal partida_terminada(equipoId: int)  # un equipo cayó exacto en la última casilla

# Crea los equipos en la salida. El id de cada equipo es su orden en la lista (1, 2...).
func crearEquipos(nombres: Array) -> void:
	equipos.clear()
	for i in nombres.size():
		equipos[i + 1] = {"nombre": nombres[i], "posicion": 0}

func recibirDatos(nombre1: String, nombre2: String):
	crearEquipos([nombre1, nombre2])
	iniciar_partida()

func tirarDado():
	simular_dado.emit()

# Mueve en los datos la ficha del equipo en turno y devuelve el recorrido para animarlo:
# {id, inicio, tope, final}. Si no rebota, tope == final.
func moverFicha(casillas: int) -> Dictionary:
	var equipo: Dictionary = equipos.get(turnoEquipoId, {})
	if equipo.is_empty():
		push_error("No hay ficha para el equipo %s" % turnoEquipoId)
		return {}

	# Para ganar hay que caer exacto en la última casilla: si sobran puntos,
	# la ficha llega al final y retrocede las casillas que se pasó.
	var ultima := NUMERO_CASILLAS - 1
	var inicio: int = equipo.posicion
	var destino: int = inicio + casillas
	var exceso := maxi(destino - ultima, 0)
	equipo.posicion = maxi(destino - 2 * exceso, 0)
	return {"id": turnoEquipoId, "inicio": inicio, "tope": mini(destino, ultima), "final": equipo.posicion}

# Se llama cuando la animación del movimiento termina.
func terminarMovimiento(equipoId: int) -> void:
	if equipos[equipoId].posicion == NUMERO_CASILLAS - 1:
		partida_terminada.emit(equipoId)  # el reloj no arranca: no se emite ficha_movida
	else:
		ficha_movida.emit(equipoId)

func avanzarTurno():
	#Cambiar turnos
	if turnoEquipoId ==1:
		turnoEquipoId =2
	else :
		turnoEquipoId =1
	turno_actual += 1
	turno_equipo_cambiado.emit(turnoEquipoId)

func iniciar_partida():
	turno_actual = 0
	if turno_actual == 0:
		turnoEquipoId = randi_range(1,2)
	get_tree().change_scene_to_file("res://Mundo/Mundo.tscn")
