extends Node3D

@onready var camara3D = $Camera3D

@onready var vistaTablero = $posicionCamaras/vistaTableroGral
@onready var vistaMesaDados = $posicionCamaras/vistaMesaDados

@onready var resultado_dado = $"resultado-dado"
@onready var mensajeGanador = $mensajeGanador  # Label3D en el centro del tablero

@onready var path_3D = $Path3D
@onready var dado = $Dado
@onready var temporizador = $Temporizador
@onready var panelAcciones = $HUD/PanelAcciones

## Segundos que la cámara se queda en la mesa mostrando el resultado antes de volver.
@export var pausa_resultado := 1.0

var _vista_anterior = null  # Transform3D de la cámara antes de ir a la mesa de dados
var _tirada_en_curso := false  # desde que se pulsa tirar hasta que la ficha termina de moverse
var _turno_de_tirada := 0  # GameManager.turno_actual cuando se pulsó tirar



func _ready():
	GameManager.registarPath(path_3D)
	GameManager.simular_dado.connect(_on_simular_dado)
	GameManager.ficha_movida.connect(_on_ficha_movida)
	# Al ejecutar Mundo.tscn directamente (F6) no se pasa por el lobby: crea fichas de prueba.
	if GameManager.equipos.is_empty():
		GameManager.instanciarFicha("Equipo 1", 1)
		GameManager.instanciarFicha("Equipo 2", 2)
		GameManager.actualizarOffsets()
		GameManager.turnoEquipoId = randi_range(1, 2)
	GameManager.turno_equipo_cambiado.connect(_on_turno_equipo_cambiado)
	temporizador.tiempo_agotado.connect(GameManager.avanzarTurno)
	GameManager.partida_terminada.connect(_on_partida_terminada)
	_mostrar_turno()

# Aviso de inicio de turno: el panel centrado con el equipo que juega y el botón de tirar.
func _mostrar_turno() -> void:
	var nombre: String = GameManager.equipos["equipo%s" % GameManager.turnoEquipoId].nombre
	panelAcciones.mostrar_turno(nombre)

func _on_simular_dado() -> void:
	panelAcciones.hide()  # no tapa la tirada y evita pulsar dos veces
	_tirada_en_curso = true
	_turno_de_tirada = GameManager.turno_actual
	if _vista_anterior != null:  # ya estamos en la mesa (el dado sigue rodando)
		return
	_vista_anterior = camara3D.global_transform
	# Solo se usa la posición del marcador: se conserva la rotación actual (mirando hacia abajo).
	var destino: Transform3D = camara3D.global_transform
	destino.origin = vistaMesaDados.global_position
	mover_camara_a(destino)

func _on_dado_tiro_finalizado(valor: Variant) -> void:
	resultado_dado.text=str(valor)
	await get_tree().create_timer(pausa_resultado).timeout
	if _vista_anterior != null:
		await mover_camara_a(_vista_anterior).finished
		_vista_anterior = null
	# Solo se avanza dentro del minuto: si el tiempo se acabó durante la tirada, no cuenta.
	if GameManager.turno_actual != _turno_de_tirada:
		_tirada_en_curso = false
		_mostrar_turno()  # el aviso del nuevo equipo quedó pendiente
		return
	# La ficha avanza cuando la cámara ya volvió al tablero, para que se vea el movimiento.
	GameManager.moverFicha(valor)

# El tiempo del turno empieza cuando la ficha termina su primer movimiento.
# Después de moverse, el panel vuelve para que el equipo pueda tirar otra vez en su turno.
func _on_ficha_movida(equipoId: int) -> void:
	_tirada_en_curso = false
	if equipoId != GameManager.turnoEquipoId:  # el tiempo se acabó con la ficha ya en marcha
		_mostrar_turno()
		return
	temporizador.iniciar()
	panelAcciones.show()

func _on_partida_terminada(equipoId: int) -> void:
	temporizador.reiniciar()
	panelAcciones.hide()
	mensajeGanador.text = "¡Gana %s!" % GameManager.equipos["equipo%s" % equipoId].nombre
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
	if not _tirada_en_curso:
		_mostrar_turno()

func mover_camara_suave(destino: Marker3D, duracion := 0.6) -> void:
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(camara3D, "global_transform", destino.global_transform, duracion)
