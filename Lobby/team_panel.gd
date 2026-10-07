class_name TeamPanel
extends PanelContainer
## Panel visual de un equipo en el lobby: muestra las casillas y los jugadores conectados.

@export var team_number: int = 1
@export var panel_color: Color = Color("#7ca7a5")
@export_range(10, 20) var players_per_team: int = 20
@export var slot_scene: PackedScene

var _ids: Array[String] = []
var _names: Dictionary = {}

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

	for i in players_per_team:
		_slots.add_child(slot_scene.instantiate())
	_refresh()


func add_player(id: String, player_name: String) -> void:
	if _names.has(id) or _ids.size() >= players_per_team:
		return
	_ids.append(id)
	_names[id] = player_name
	_refresh()


func remove_player(id: String) -> void:
	if _names.has(id):
		_ids.erase(id)
		_names.erase(id)
		_refresh()


## Nombre escrito en el campo del equipo, o "Equipo N" si está vacío.
func nombre_equipo() -> String:
	var nombre := _team_input.text.strip_edges()
	return nombre if not nombre.is_empty() else "Equipo %d" % team_number


func clear_players() -> void:
	_ids.clear()
	_names.clear()
	_refresh()


func _refresh() -> void:
	_count.text = "%d / %d jugadores" % [_ids.size(), players_per_team]
	for i in _slots.get_child_count():
		var slot := _slots.get_child(i)
		var taken := i < _ids.size()
		slot.get_node("Row/Name").text = _names[_ids[i]] if taken else "Jugador %d" % (i + 1)
		slot.get_node("Row/Status").text = "Conectado" if taken else "Esperando…"
