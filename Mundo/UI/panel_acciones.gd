extends PanelContainer

signal tirar_pulsado  # mundo.gd la escucha y hace la tirada completa

@onready var botonTirarDado = $MarginContainer/VBoxContainer/botonTirarDado
@onready var labelEquipo = $MarginContainer/VBoxContainer/labelEquipoDeTurno

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

func configurar_estado(puedeTirar: bool) -> void:
	botonTirarDado.disabled = not puedeTirar

# Aviso de inicio de turno: muestra el panel con el equipo que juega.
func mostrar_turno(nombreEquipo: String) -> void:
	labelEquipo.text ="Turno de %s" % nombreEquipo
	configurar_estado(true)
	show()


func _on_boton_tirar_dado_pressed() -> void:
	tirar_pulsado.emit()
