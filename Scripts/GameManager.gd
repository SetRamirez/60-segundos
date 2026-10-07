extends Node
# GameManager.gd
#var jugadores: Array = []
const NUMERO_CASILLAS = 61  # casillas del Path3D de Mundo.tscn, incluida la de salida
const OFFSET_MISMA_CASILLA = 0.5  # separación lateral de las fichas que comparten casilla
var turno_actual: int = 0
var turnoEquipoId: int;
var equipos = {}


var path_3D: Path3D=null
var colaFichasPendientes: Array = []

signal simular_dado
signal ficha_movida(equipoId: int)  # al terminar la animación de moverFicha
signal turno_equipo_cambiado(equipoId: int)
signal partida_terminada(equipoId: int)  # un equipo cayó exacto en la última casilla

func _ready():
	EmpezarLobby()

func EmpezarLobby():
	get_tree().change_scene_to_file.call_deferred("res://Escenas/lobby_2d.tscn")

func registarPath(path_node: Path3D):
	path_3D = path_node
	_procesarFichasPendientes()

func _procesarFichasPendientes():
	for datos in colaFichasPendientes:
		_crearFicha(datos[0], datos[1])
	colaFichasPendientes.clear()
	actualizarOffsets()

func instanciarFicha(nombre: String, id: int):
	if path_3D == null:
		push_error("todavia no hay Path3D")
		colaFichasPendientes.append([nombre,id])
		return null
	return _crearFicha(nombre,id)
	
func _crearFicha(nombre: String, id: int) -> Node3D:
	var escenaEquipo := preload("res://Escenas/equipo.tscn")
	var equipo := escenaEquipo.instantiate()
	equipo.name = "equipo%s" % id
	
	var pathFollow := PathFollow3D.new()
	pathFollow.name = "PathFollow_%s" % id
	pathFollow.loop = false
	pathFollow.rotation_mode = PathFollow3D.ROTATION_NONE
	
	path_3D.add_child(pathFollow)
	pathFollow.add_child(equipo)
	
	equipo.configurar(nombre, id, pathFollow)
	pathFollow.progress=0.0
	equipos[equipo.name] = equipo
	
	return equipo
	
func recibirDatos(nombre1: String, nombre2: String):
	instanciarFicha(nombre1,1)
	instanciarFicha(nombre2,2)
	iniciar_partida()
	
func tirarDado():
	simular_dado.emit()

func moverFicha(casillas: int) -> Tween:
	var equipo = equipos.get("equipo%s" % turnoEquipoId)
	if equipo == null:
		push_error("No hay ficha para el equipo %s" % turnoEquipoId)
		return null

	# La casilla 0 es la salida; el camino tiene NUMERO_CASILLAS - 1 tramos iguales.
	var largoTotal := path_3D.curve.get_baked_length()
	var distanciaPorCasilla := largoTotal / float(NUMERO_CASILLAS - 1)

	# Para ganar hay que caer exacto en la última casilla: si sobran puntos,
	# la ficha llega al final y retrocede las casillas que se pasó.
	var ultima := NUMERO_CASILLAS - 1
	var destino: int = equipo.posicion + casillas
	var exceso := maxi(destino - ultima, 0)
	equipo.posicion = maxi(destino - 2 * exceso, 0)

	# Los tramos se ejecutan en orden; los 0.8 s se reparten según las casillas de cada uno.
	var segundosPorCasilla := 0.8 / maxi(casillas, 1)
	var tween := create_tween()
	tween.tween_property(
		equipo.pathFicha, "progress",
		mini(destino, ultima) * distanciaPorCasilla,
		(casillas - exceso) * segundosPorCasilla
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if exceso > 0:
		tween.tween_property(
			equipo.pathFicha, "progress",
			equipo.posicion * distanciaPorCasilla,
			exceso * segundosPorCasilla
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	actualizarOffsets(0.8)
	tween.finished.connect(func():
		if equipo.posicion == ultima:
			partida_terminada.emit(equipo.id)  # el reloj no arranca: no se emite ficha_movida
		else:
			ficha_movida.emit(equipo.id)
	)
	return tween

# Separa las fichas que comparten casilla; una ficha sola en su casilla vuelve al centro.
# Con duracion > 0 el cambio se anima (moverFicha lo hace a la vez que el avance).
func actualizarOffsets(duracion := 0.0) -> void:
	for equipo in equipos.values():
		var compartida: bool = equipos.values().any(
			func(otro): return otro != equipo and otro.posicion == equipo.posicion)
		var offset := 0.0
		if compartida:
			offset = OFFSET_MISMA_CASILLA if equipo.id == 1 else -OFFSET_MISMA_CASILLA
		if duracion > 0.0:
			create_tween().tween_property(equipo.pathFicha, "h_offset", offset, duracion)
		else:
			equipo.pathFicha.h_offset = offset

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
	get_tree().change_scene_to_file("res://Escenas/Mundo.tscn")
	
