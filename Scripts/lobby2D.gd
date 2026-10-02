extends Control

@onready var botonComenzar = $PanelContainer/MarginContainer/MarginContainer2/botonComenzar
@onready var NombreEquipo1 = $"PanelContainer/MarginContainer/ContenedorEquipos/Equipo 1"
@onready var NombreEquipo2 = $"PanelContainer/MarginContainer/ContenedorEquipos/Equipo 2"


func _on_boton_comenzar_pressed():
	var nombre1 = NombreEquipo1.text.strip_edges()
	var nombre2 = NombreEquipo2.text.strip_edges()
	if nombre1.is_empty() && nombre2.is_empty():
		print("Introduzca ambos nombres")
		return
	GameManager.recibirDatos(nombre1,nombre2)
