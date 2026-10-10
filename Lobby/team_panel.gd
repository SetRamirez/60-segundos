class_name TeamPanel
extends PanelContainer
## Panel visual de un equipo en el lobby: muestra las casillas y los jugadores conectados.
## No guarda la lista de jugadores: lobby.gd le pasa los nombres (de Hub.players) cada vez que cambia.

## Debe coincidir con MAX_PER_TEAM de server/server.js: si cambias uno, cambia el otro.
const JUGADORES_POR_EQUIPO := 20

@export var team_number: int = 1
@export var panel_color: Color = Color("#7ca7a5")
@export var slot_scene: PackedScene

@onready var _title: Label = %TeamTitle
@onready var _count: Label = %PlayerCount
@onready var _team_name: Label = %TeamName
@onready var _team_input: LineEdit = %TeamInput
@onready var _slots: GridContainer = %Slots


func _ready() -> void:
	# El estilo es un recurso compartido entre instancias: se duplica para cambiar el color.
	var style := get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.bg_color = panel_color
	add_theme_stylebox_override("panel", style)

	_title.text = "EQUIPO %d" % team_number
	_team_name.text = "Equipo %d" % team_number
	_team_input.placeholder_text = "Nombre del equipo %d" % team_number

	for i in JUGADORES_POR_EQUIPO:
		_slots.add_child(slot_scene.instantiate())
	mostrar_jugadores([])


## Pinta las casillas con los nombres de los jugadores del equipo, en orden de llegada.
func mostrar_jugadores(nombres: Array[String]) -> void:
	_count.text = "%d / %d jugadores" % [nombres.size(), JUGADORES_POR_EQUIPO]
	for i in _slots.get_child_count():
		var slot := _slots.get_child(i)
		var taken := i < nombres.size()
		slot.get_node("Row/Name").text = nombres[i] if taken else "Jugador %d" % (i + 1)
		slot.get_node("Row/Status").text = "Conectado" if taken else "Esperando…"


## Nombre escrito en el campo del equipo, o "Equipo N" si está vacío.
func nombre_equipo() -> String:
	var nombre := _team_input.text.strip_edges()
	return nombre if not nombre.is_empty() else "Equipo %d" % team_number
