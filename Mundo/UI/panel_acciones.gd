extends PanelContainer
## Panel del turno: "Turno de X" y el botón de tirar. Para que no se pueda tirar,
## mundo.gd oculta el panel con hide() (el botón nunca se deshabilita).

signal tirar_pulsado  # mundo.gd la escucha y hace la tirada completa

@onready var labelEquipo = $MarginContainer/VBoxContainer/labelEquipoDeTurno

# Aviso de inicio de turno: muestra el panel con el equipo que juega.
func mostrar_turno(nombreEquipo: String) -> void:
	labelEquipo.text ="Turno de %s" % nombreEquipo
	show()


func _on_boton_tirar_dado_pressed() -> void:
	tirar_pulsado.emit()
