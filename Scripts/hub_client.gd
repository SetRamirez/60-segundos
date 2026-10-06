extends Node
## Cliente WebSocket que conecta Godot con el servidor Node.
## Se registra como Autoload con el nombre "Hub" (Project Settings > Globals > Autoload).

signal connection_changed(is_open: bool)
signal url_received(url: String)
signal roster_received
signal player_joined(id: String, player_name: String, team: int)
signal player_left(id: String)
signal player_message(id: String, data: Dictionary)

const SERVER_URL := "ws://127.0.0.1:3000/host"
const RETRY_SECONDS := 2.0

## id -> {"name": String, "team": int}
var players: Dictionary = {}
var join_url: String = ""

var _ws: WebSocketPeer
var _was_open := false
var _retry_left := 0.0


func _ready() -> void:
	_connect()


func is_server_open() -> bool:
	return _was_open


## Envía un mensaje a un jugador concreto (por ejemplo, su carta o "es tu turno").
func send_to_player(id: String, data: Dictionary) -> void:
	_send({"type": "send", "id": id, "data": data})


## Envía un mensaje a todos los jugadores.
func broadcast(data: Dictionary) -> void:
	_send({"type": "broadcast", "data": data})


func _send(msg: Dictionary) -> void:
	if _was_open:
		_ws.send_text(JSON.stringify(msg))


func _connect() -> void:
	_ws = WebSocketPeer.new()
	_retry_left = RETRY_SECONDS
	if _ws.connect_to_url(SERVER_URL) != OK:
		push_warning("Hub: no se pudo iniciar la conexión con %s" % SERVER_URL)


func _process(delta: float) -> void:
	_ws.poll()
	match _ws.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if not _was_open:
				_was_open = true
				connection_changed.emit(true)
			while _ws.get_available_packet_count() > 0:
				_handle(_ws.get_packet().get_string_from_utf8())
		WebSocketPeer.STATE_CLOSED:
			if _was_open:
				_was_open = false
				players.clear()
				join_url = ""
				connection_changed.emit(false)
			_retry_left -= delta
			if _retry_left <= 0.0:
				_connect()


func _handle(text: String) -> void:
	var msg = JSON.parse_string(text)
	if typeof(msg) != TYPE_DICTIONARY:
		return
	match msg.get("type", ""):
		"info":
			join_url = str(msg.get("url", ""))
			url_received.emit(join_url)
		"roster":
			players.clear()
			for p in msg.get("players", []):
				players[str(p["id"])] = {"name": str(p["name"]), "team": int(p["team"])}
			roster_received.emit()
		"player_joined":
			var id := str(msg["id"])
			players[id] = {"name": str(msg["name"]), "team": int(msg["team"])}
			player_joined.emit(id, str(msg["name"]), int(msg["team"]))
		"player_left":
			var id := str(msg["id"])
			players.erase(id)
			player_left.emit(id)
		"player_message":
			player_message.emit(str(msg["id"]), msg.get("data", {}))
