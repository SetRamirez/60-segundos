extends PanelContainer
## Panel visual de un equipo en el lobby.
## Solo maquetación: todavía no tiene lógica de juego.

@export var team_number: int = 1
@export var panel_color: Color = Color("#7ca7a5")
@export_range(10, 20) var players_per_team: int = 20
@export var slot_scene: PackedScene

@onready var _title: Label = %TeamTitle
@onready var _count: Label = %PlayerCount
@onready var _name: Label = %TeamName
@onready var _input: LineEdit = %TeamInput
@onready var _slots: GridContainer = %Slots


func _ready() -> void:
	# El estilo es un recurso compartido entre instancias: se duplica para cambiar el color.
	var style := get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.bg_color = panel_color
	add_theme_stylebox_override("panel", style)

	_title.text = "EQUIPO %d" % team_number
	_count.text = "0 / %d jugadores" % players_per_team
	_name.text = "Equipo %d" % team_number
	_input.placeholder_text = "Nombre del equipo %d" % team_number

	for i in players_per_team:
		var slot := slot_scene.instantiate()
		_slots.add_child(slot)
		slot.get_node("Row/Name").text = "Jugador %d" % (i + 1)
