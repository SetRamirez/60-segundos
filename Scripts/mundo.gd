extends Node3D

@onready var camara3D = $Camera3D

@onready var vistaTablero = $posicionCamaras/vistaTableroGral
@onready var vistaMesaDados = $posicionCamaras/vistaMesaDados

@onready var resultado_dado = $"resultado-dado"

@onready var path_3D = $Path3D
@onready var dado = $Dado

## Segundos que la cámara se queda en la mesa mostrando el resultado antes de volver.
@export var pausa_resultado := 1.0

var _vista_anterior = null  # Transform3D de la cámara antes de ir a la mesa de dados



func _ready():
	GameManager.registarPath(path_3D)
	GameManager.simular_dado.connect(_on_simular_dado)
	# Al ejecutar Mundo.tscn directamente (F6) no se pasa por el lobby: crea fichas de prueba.
	if GameManager.equipos.is_empty():
		GameManager.instanciarFicha("Equipo 1", 1)
		GameManager.instanciarFicha("Equipo 2", 2)
		GameManager.verificarMismaCasillaFinal()
		GameManager.turnoEquipoId = randi_range(1, 2)
	#GameManager.turno_equipo_cambiado.connect(_on_turno_equipo_cambiado)

func _on_simular_dado() -> void:
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
	# La ficha avanza cuando la cámara ya volvió al tablero, para que se vea el movimiento.
	GameManager.moverFicha(valor)

func mover_camara_a(destino: Transform3D, duracion := 0.6) -> Tween:
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(camara3D, "global_transform", destino, duracion)
	return tween

func _on_turno_equipo_cambiado(jugador_id: int) -> void:
	var marker = vistaTablero
	mover_camara_suave(marker)

func mover_camara_suave(destino: Marker3D, duracion := 0.6) -> void:
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(camara3D, "global_transform", destino.global_transform, duracion)
