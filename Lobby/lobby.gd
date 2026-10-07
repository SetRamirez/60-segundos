extends Control
## Lobby: muestra en las casillas a los jugadores que se conectan desde el celular.

@onready var _team_1: TeamPanel = $Margin/Main/Teams/Team1
@onready var _team_2: TeamPanel = $Margin/Main/Teams/Team2
@onready var _join_url: Label = $Margin/Main/TitleRow/JoinUrl
@onready var _start_button: Button = $Margin/Main/Footer/StartButton


func _ready() -> void:
	_start_button.pressed.connect(_on_start_pressed)
	Hub.url_received.connect(_on_url)
	Hub.player_joined.connect(_on_player_joined)
	Hub.player_left.connect(_on_player_left)
	Hub.roster_received.connect(_on_roster)
	Hub.connection_changed.connect(_on_connection_changed)

	_on_connection_changed(Hub.is_server_open())
	if Hub.is_server_open():
		_on_url(Hub.join_url)
		_on_roster()


func _on_connection_changed(is_open: bool) -> void:
	if not is_open:
		_join_url.text = "Conectando con el servidor…"
		_team_1.clear_players()
		_team_2.clear_players()


func _on_url(url: String) -> void:
	_join_url.text = "Entra desde el celular: %s" % url


func _on_roster() -> void:
	_team_1.clear_players()
	_team_2.clear_players()
	for id in Hub.players:
		var p: Dictionary = Hub.players[id]
		_on_player_joined(id, p["name"], p["team"])


func _on_player_joined(id: String, player_name: String, team: int) -> void:
	(_team_1 if team == 1 else _team_2).add_player(id, player_name)


func _on_player_left(id: String) -> void:
	_team_1.remove_player(id)
	_team_2.remove_player(id)


# Crea los equipos en GameManager y cambia a Mundo.tscn.
func _on_start_pressed() -> void:
	GameManager.recibirDatos(_team_1.nombre_equipo(), _team_2.nombre_equipo())
