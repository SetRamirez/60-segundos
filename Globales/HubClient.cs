using Godot;
using System.Collections.Generic;

/// <summary>
/// Cliente WebSocket que conecta Godot con el servidor Node.
/// Se registra como Autoload con el nombre "Hub" (Project Settings > Globals > Autoload)
/// y se usa con HubClient.Instancia.
/// </summary>
public partial class HubClient : Node
{
    public static HubClient Instancia { get; private set; }

    [Signal] public delegate void ConnectionChangedEventHandler(bool isOpen);
    [Signal] public delegate void UrlReceivedEventHandler(string url);
    [Signal] public delegate void RosterReceivedEventHandler();
    [Signal] public delegate void PlayerJoinedEventHandler(string id, string playerName, int team);
    [Signal] public delegate void PlayerLeftEventHandler(string id);
    [Signal] public delegate void PlayerMessageEventHandler(string id, Godot.Collections.Dictionary data);

    private const string ServerUrl = "ws://127.0.0.1:3000/host";
    private const double RetrySeconds = 2.0;

    /// <summary>Jugadores conectados, en orden de llegada. Se vacía al desconectarse.</summary>
    public IReadOnlyList<Jugador> Players => _players;
    public string JoinUrl { get; private set; } = "";

    // Es una lista y no un Dictionary porque el Dictionary de C# no garantiza el orden:
    // tras quitar un jugador, el siguiente que entra puede ocupar su hueco.
    private readonly List<Jugador> _players = new();
    private WebSocketPeer _ws;
    private bool _wasOpen = false;
    private double _retryLeft = 0.0;

    public override void _EnterTree()
    {
        Instancia = this;
    }

    public override void _Ready()
    {
        Conectar();
    }

    public bool IsServerOpen()
    {
        return _wasOpen;
    }

    /// <summary>Envía un mensaje a un jugador concreto (por ejemplo, su carta o "es tu turno").</summary>
    public void SendToPlayer(string id, Godot.Collections.Dictionary data)
    {
        Send(new Godot.Collections.Dictionary { { "type", "send" }, { "id", id }, { "data", data } });
    }

    /// <summary>Envía un mensaje a todos los jugadores.</summary>
    public void Broadcast(Godot.Collections.Dictionary data)
    {
        Send(new Godot.Collections.Dictionary { { "type", "broadcast" }, { "data", data } });
    }

    private void Send(Godot.Collections.Dictionary msg)
    {
        if (_wasOpen)
            _ws.SendText(Json.Stringify(msg));
    }

    private void Conectar()
    {
        _ws = new WebSocketPeer();
        _retryLeft = RetrySeconds;
        if (_ws.ConnectToUrl(ServerUrl) != Error.Ok)
            GD.PushWarning($"Hub: no se pudo iniciar la conexión con {ServerUrl}");
    }

    public override void _Process(double delta)
    {
        _ws.Poll();
        switch (_ws.GetReadyState())
        {
            case WebSocketPeer.State.Open:
                if (!_wasOpen)
                {
                    _wasOpen = true;
                    EmitSignal(SignalName.ConnectionChanged, true);
                }
                while (_ws.GetAvailablePacketCount() > 0)
                    Handle(_ws.GetPacket().GetStringFromUtf8());
                break;
            case WebSocketPeer.State.Closed:
                if (_wasOpen)
                {
                    _wasOpen = false;
                    _players.Clear();
                    JoinUrl = "";
                    EmitSignal(SignalName.ConnectionChanged, false);
                }
                _retryLeft -= delta;
                if (_retryLeft <= 0.0)
                    Conectar();
                break;
        }
    }

    private void Handle(string text)
    {
        Variant parsed = Json.ParseString(text);
        if (parsed.VariantType != Variant.Type.Dictionary)
            return;
        var msg = parsed.AsGodotDictionary();
        switch (msg.GetValueOrDefault("type", "").AsString())
        {
            case "info":
                JoinUrl = msg.GetValueOrDefault("url", "").ToString();
                EmitSignal(SignalName.UrlReceived, JoinUrl);
                break;
            case "roster":
                _players.Clear();
                foreach (Variant p in msg.GetValueOrDefault("players", new Godot.Collections.Array()).AsGodotArray())
                    _players.Add(LeerJugador(p.AsGodotDictionary()));
                EmitSignal(SignalName.RosterReceived);
                break;
            case "player_joined":
            {
                Jugador jugador = LeerJugador(msg);
                _players.RemoveAll(j => j.Id == jugador.Id);
                _players.Add(jugador);
                EmitSignal(SignalName.PlayerJoined, jugador.Id, jugador.Nombre, jugador.EquipoId);
                break;
            }
            case "player_left":
            {
                string id = msg["id"].ToString();
                _players.RemoveAll(j => j.Id == id);
                EmitSignal(SignalName.PlayerLeft, id);
                break;
            }
            case "player_message":
                EmitSignal(SignalName.PlayerMessage, msg["id"].ToString(),
                    msg.GetValueOrDefault("data", new Godot.Collections.Dictionary()).AsGodotDictionary());
                break;
        }
    }

    // El JSON trae los números como float: AsInt32() los convierte a int.
    private static Jugador LeerJugador(Godot.Collections.Dictionary datos)
    {
        return new Jugador(datos["id"].ToString(), datos["name"].ToString(), datos["team"].AsInt32());
    }
}
