extends CanvasLayer

@onready var panelAcciones = $HUD/PanelAcciones

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	panelAcciones.accion_tirar_dado.connect(_on_accion_tirar_dado)

func _on_accion_tirar_dado() -> void:
	GameManager.solicitar_tirar_dado()
