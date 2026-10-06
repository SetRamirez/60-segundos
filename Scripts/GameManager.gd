extends Node
# GameManager.gd
#var jugadores: Array = []
const NUMERO_CASILLAS = 61  # casillas del Path3D de Mundo.tscn, incluida la de salida
var turno_actual: int = 0
var turnoEquipoId: int;
var equipos = {}


var path_3D: Path3D=null
var colaFichasPendientes: Array = []

signal tablero_listo
signal simular_dado

func _ready():
	EmpezarLobby()

func EmpezarLobby():
	get_tree().change_scene_to_file.call_deferred("res://Escenas/lobby_2d.tscn")

func registarPath(path_node: Path3D):
	path_3D = path_node
	tablero_listo.emit()
	_procesarFichasPendientes()

func _procesarFichasPendientes():
	for datos in colaFichasPendientes:
		_crearFicha(datos[0], datos[1])
	colaFichasPendientes.clear()
	if path_3D.get_child_count() >= 2:
		verificarMismaCasillaFinal()

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
	
func conectar_dado(dado: Node) -> void:
	dado.tiro_finalizado.connect(_on_dado_tiro_finalizado)

func tirarDado():
	simular_dado.emit()

func _on_dado_tiro_finalizado(resultado: int) -> void:
	moverFicha(resultado)
	
func moverFicha(casillas: int) ->void:
	var equipo = equipos.get("equipo%s" % turnoEquipoId)
	if equipo == null:
		push_error("No hay ficha para el equipo %s" % turnoEquipoId)
		return

	# La casilla 0 es la salida; el camino tiene NUMERO_CASILLAS - 1 tramos iguales.
	var largoTotal := path_3D.curve.get_baked_length()
	var distanciaPorCasilla := largoTotal / float(NUMERO_CASILLAS - 1)

	# evita pasarse del final, arreglar despues para que avanze hasta el final y vuelva
	equipo.posicion = mini(equipo.posicion + casillas, NUMERO_CASILLAS - 1)

	var tween := create_tween()
	tween.tween_property(
		equipo.pathFicha, "progress",
		equipo.posicion * distanciaPorCasilla,
		0.8
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
func verificarMismaCasillaFinal():
	var pathEquipo1 = path_3D.get_child(0)
	var pathEquipo2 = path_3D.get_child(1)
	#luego cambiar el progress por numero de casillas para mejor transicion
	if pathEquipo1.progress == pathEquipo2.progress:
		pathEquipo1.h_offset = 0.5
		pathEquipo2.h_offset = -0.5

func comenzarTurno():
	#hacer visible el panelAcciones
	
	pass

func avanzarTurno(jugador_id: int):
	#Cambiar turnos
	if turnoEquipoId ==1:
		turnoEquipoId ==2
	else : 
		turnoEquipoId =1

func iniciar_partida():
	turno_actual = 0
	if turno_actual == 0:
		turnoEquipoId = randi_range(1,2)
	get_tree().change_scene_to_file("res://Escenas/Mundo.tscn")
	
