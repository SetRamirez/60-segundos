extends Control
## Lobby: muestra en las casillas a los jugadores que se conectan desde el celular.

@onready var _team_1: TeamPanel = $Margin/Main/Teams/Team1
@onready var _team_2: TeamPanel = $Margin/Main/Teams/Team2
@onready var _join_url: Label = $Margin/Main/TitleRow/JoinUrl
@onready var _start_button: Button = $Margin/Main/Footer/StartButton


func _ready() -> void:
	_start_button.pressed.connect(_on_start_pressed)
	Hub.url_received.connect(_on_url)
	Hub.connection_changed.connect(_on_connection_changed)
	# Hub actualiza Hub.players antes de emitir estas señales: basta con volver a pintar.
	# unbind(n) descarta los n argumentos de la señal, que _refrescar no necesita.
	Hub.roster_received.connect(_refrescar)
	Hub.player_joined.connect(_refrescar.unbind(3))
	Hub.player_left.connect(_refrescar.unbind(1))

	_on_connection_changed(Hub.is_server_open())
	if Hub.is_server_open():
		_on_url(Hub.join_url)
		_refrescar()


func _on_connection_changed(is_open: bool) -> void:
	if not is_open:
		_join_url.text = "Conectando con el servidor…"
		_refrescar()  # Hub ya vació su lista de jugadores


func _on_url(url: String) -> void:
	_join_url.text = "Entra desde el celular: %s" % url


# Vuelve a pintar los dos equipos desde Hub.players, la única copia de la lista.
func _refrescar() -> void:
	for panel: TeamPanel in [_team_1, _team_2]:
		var nombres: Array[String] = []
		for p in Hub.players.values():
			if p["team"] == panel.team_number:
				nombres.append(p["name"])
		panel.mostrar_jugadores(nombres)


# Crea los equipos en GameManager y cambia a Mundo.tscn.
func _on_start_pressed() -> void:
	GameManager.recibirDatos(_team_1.nombre_equipo(), _team_2.nombre_equipo())
