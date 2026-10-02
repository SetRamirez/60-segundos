extends Node3D

@onready var camara3D = $Camera3D

@onready var vistaTablero = $posicionCamaras/vistaTableroGral
@onready var vistaMesaDados = $posicionCamaras/vistaMesaDados

@onready var resultado_dado = $"resultado-dado"

@onready var path_3D = $Path3D



func _ready():
	GameManager.registarPath(path_3D)
	#GameManager.turno_equipo_cambiado.connect(_on_turno_equipo_cambiado)

func _on_dado_tiro_finalizado(valor: Variant) -> void:
	resultado_dado.text=str(valor)

func _on_turno_equipo_cambiado(jugador_id: int) -> void:
	var marker = vistaTablero
	mover_camara_suave(marker)

func mover_camara_suave(destino: Marker3D, duracion := 0.6) -> void:
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(camara3D, "global_transform", destino.global_transform, duracion)
