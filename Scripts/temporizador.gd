extends CanvasLayer

signal tiempo_agotado

@onready var mostrar_temporizador =$Control/Node2D/texto_temporizador
@onready var temporizador = $temporizador

func _ready() -> void:
	temporizador.timeout.connect(tiempo_agotado.emit)

func _process(_delta: float) -> void:
	# Detenido, time_left es 0: se muestra el tiempo completo del turno.
	var segundos = temporizador.wait_time if temporizador.is_stopped() else temporizador.time_left
	mostrar_temporizador.text=str(segundos).pad_decimals(0)

# Arranca la cuenta solo si no está corriendo: los movimientos posteriores del turno no la reinician.
func iniciar() -> void:
	if temporizador.is_stopped():
		temporizador.start()

# Detiene la cuenta y la deja lista (en 60) para el siguiente turno.
func reiniciar() -> void:
	temporizador.stop()
