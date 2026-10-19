using Godot;
using System.Linq;

/// <summary>
/// Lobby: muestra en las casillas a los jugadores que se conectan desde el celular.
/// </summary>
public partial class Lobby : Control
{
    private TeamPanel _team1;
    private TeamPanel _team2;
    private Label _joinUrl;
    private Button _startButton;

    public override void _Ready()
    {
        _team1 = GetNode<TeamPanel>("Margin/Main/Teams/Team1");
        _team2 = GetNode<TeamPanel>("Margin/Main/Teams/Team2");
        _joinUrl = GetNode<Label>("Margin/Main/TitleRow/JoinUrl");
        _startButton = GetNode<Button>("Margin/Main/Footer/StartButton");

        _startButton.Pressed += OnStartPressed;
        var hub = HubClient.Instancia;
        hub.UrlReceived += OnUrl;
        hub.ConnectionChanged += OnConnectionChanged;
        // Hub actualiza Hub.Players antes de emitir estas señales: basta con volver a pintar.
        hub.RosterReceived += Refrescar;
        hub.PlayerJoined += OnPlayerJoined;
        hub.PlayerLeft += OnPlayerLeft;

        OnConnectionChanged(hub.IsServerOpen());
        if (hub.IsServerOpen())
        {
            OnUrl(hub.JoinUrl);
            Refrescar();
        }
    }

    // Hub es un autoload y sigue vivo al pasar a Mundo: se desconectan sus señales para que
    // no llamen a este lobby, que ya se habrá destruido.
    public override void _ExitTree()
    {
        var hub = HubClient.Instancia;
        hub.UrlReceived -= OnUrl;
        hub.ConnectionChanged -= OnConnectionChanged;
        hub.RosterReceived -= Refrescar;
        hub.PlayerJoined -= OnPlayerJoined;
        hub.PlayerLeft -= OnPlayerLeft;
    }

    private void OnConnectionChanged(bool isOpen)
    {
        if (!isOpen)
        {
            _joinUrl.Text = "Conectando con el servidor…";
            Refrescar(); // Hub ya vació su lista de jugadores
        }
    }

    private void OnUrl(string url)
    {
        _joinUrl.Text = $"Entra desde el celular: {url}";
    }

    // Refrescar no necesita los argumentos de estas señales; en GDScript se descartaban con unbind().
    private void OnPlayerJoined(string id, string playerName, int team) => Refrescar();
    private void OnPlayerLeft(string id) => Refrescar();

    // Vuelve a pintar los dos equipos desde Hub.Players, la única copia de la lista.
    private void Refrescar()
    {
        foreach (TeamPanel panel in new[] { _team1, _team2 })
        {
            var nombres = HubClient.Instancia.Players
                .Where(j => j.EquipoId == panel.TeamNumber)
                .Select(j => j.Nombre)
                .ToList();
            panel.MostrarJugadores(nombres);
        }
    }

    // Crea los equipos en GameManager y cambia a Mundo.tscn.
    private void OnStartPressed()
    {
        GameManager.Instancia.RecibirDatos(_team1.NombreEquipo(), _team2.NombreEquipo());
    }
}
