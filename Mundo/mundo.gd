extends Node3D

@onready var camara3D = $Camera3D

@onready var vistaMesaDados = $posicionCamaras/vistaMesaDados

@onready var resultado_dado = $"resultado-dado"
@onready var mensajeGanador = $mensajeGanador  # Label3D en el centro del tablero
@onready var mensajeCategoria = $mensajeCategoria  # Label3D con la categoría de la casilla

@onready var tablero = $Path3D  # tablero.gd: crea y anima las fichas
@onready var dado = $Dado
@onready var temporizador = $Temporizador
@onready var panelAcciones = $HUD/PanelAcciones

## Segundos que la cámara se queda en la mesa mostrando el resultado antes de volver.
@export var pausa_resultado := 1.0

var _tirada_en_curso := false  # desde que se pulsa tirar hasta que la ficha termina de moverse



func _ready():
	# Al ejecutar Mundo.tscn directamente (F6) no se pasa por el lobby: partida con equipos de prueba.
	if GameManager.equipos.is_empty():
		GameManager.prepararPartida(["Equipo 1", "Equipo 2"])
	# Se llama desde aquí y no desde el _ready del tablero: los hijos ejecutan _ready antes
	# que el padre, y el tablero aún no vería los equipos de prueba.
	tablero.crearFichas()
	panelAcciones.tirar_pulsado.connect(_tirar)
	GameManager.turno_equipo_cambiado.connect(_on_turno_equipo_cambiado)
	temporizador.tiempo_agotado.connect(GameManager.avanzarTurno)
	_mostrar_turno()

# Aviso de inicio de turno: el panel centrado con el equipo que juega y el botón de tirar.
func _mostrar_turno() -> void:
	var nombre: String = GameManager.equipos[GameManager.turnoEquipoId].nombre
	panelAcciones.mostrar_turno(nombre)

# Una tirada completa, de principio a fin. Solo se avanza dentro del minuto: si el reloj
# se agota a mitad de la tirada, el turno cambia en ese momento (avanzarTurno), y aquí se
# compara turno_actual con el de cuando se pulsó tirar.
func _tirar() -> void:
	var turno := GameManager.turno_actual
	_tirada_en_curso = true
	panelAcciones.hide()  # no tapa la tirada y evita pulsar dos veces
	mensajeCategoria.hide()  # la categoría anterior ya no vale

	# Solo se usa la posición del marcador: se conserva la rotación actual (mirando hacia abajo).
	var vista: Transform3D = camara3D.global_transform
	var mesa := vista
	mesa.origin = vistaMesaDados.global_position
	mover_camara_a(mesa)  # sin await: el dado rueda mientras la cámara llega a la mesa
	var valor: int = await dado.lanzar()
	resultado_dado.text = str(valor)
	await get_tree().create_timer(pausa_resultado).timeout
	await mover_camara_a(vista).finished

	# La ficha avanza cuando la cámara ya volvió al tablero, para que se vea el movimiento.
	# Si el tiempo se acaba con la ficha ya en marcha, termina de moverse (y puede ganar).
	if GameManager.turno_actual == turno:
		var movimiento := GameManager.moverFicha(valor)
		await tablero.animarFicha(movimiento).finished
		if GameManager.haGanado(movimiento.equipoId):
			_mostrar_ganador(movimiento.equipoId)
			return

	_tirada_en_curso = false
	if GameManager.turno_actual != turno:
		_mostrar_turno()  # el aviso del nuevo equipo quedó pendiente
		return
	# El tiempo del turno empieza cuando la ficha termina su primer movimiento.
	# Después de moverse, el panel vuelve para que el equipo pueda tirar otra vez en su turno.
	_mostrar_categoria()
	temporizador.iniciar()
	panelAcciones.show()

# Por ahora solo se muestra; aquí se engancharán las preguntas de esa categoría.
func _mostrar_categoria() -> void:
	var casilla: int = GameManager.equipos[GameManager.turnoEquipoId].posicion
	mensajeCategoria.text = "Categoría: %s" % GameManager.categoriaDeCasilla(casilla)
	mensajeCategoria.show()

func _mostrar_ganador(equipoId: int) -> void:
	temporizador.reiniciar()
	panelAcciones.hide()
	mensajeCategoria.hide()
	mensajeGanador.text = "¡Gana %s!" % GameManager.equipos[equipoId].nombre
	mensajeGanador.show()

func mover_camara_a(destino: Transform3D, duracion := 0.6) -> Tween:
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(camara3D, "global_transform", destino, duracion)
	return tween

# El nuevo equipo empieza con el reloj en 60; corre tras su primer movimiento.
# Si hay una tirada a medias, el aviso espera a que termine para no mezclar dos tiradas.
func _on_turno_equipo_cambiado(_equipoId: int) -> void:
	temporizador.reiniciar()
	mensajeCategoria.hide()
	if not _tirada_en_curso:
		_mostrar_turno()
