extends PanelContainer


@onready var botonTirarDado = $MarginContainer/VBoxContainer/botonTirarDado
@onready var labelEquipo = $MarginContainer/VBoxContainer/labelEquipoDeTurno

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

func configurar_estado(puedeTirar: bool) -> void:
	botonTirarDado.disabled = not puedeTirar


func _on_boton_tirar_dado_pressed() -> void:
	GameManager.tirarDados()
