extends CanvasLayer

@onready var mostrar_temporizador =$Control/Node2D/texto_temporizador
@onready var temporizador = $temporizador

func _process(_delta: float) -> void:
	mostrar_temporizador.text=str(temporizador.time_left).pad_decimals(0)
