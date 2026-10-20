using Godot;
using System.Collections.Generic;

/// <summary>
/// Panel visual de un equipo en el lobby: muestra las casillas y los jugadores conectados.
/// No guarda la lista de jugadores: Lobby.cs le pasa los nombres (de Hub.Players) cada vez que cambia.
/// </summary>
public partial class TeamPanel : PanelContainer
{
    /// <summary>Debe coincidir con MAX_PER_TEAM de server/server.js: si cambias uno, cambia el otro.</summary>
    public const int JugadoresPorEquipo = 20;

    [Export] public int TeamNumber { get; set; } = 1;
    [Export] public Color PanelColor { get; set; } = new Color("#7ca7a5");
    [Export] public PackedScene SlotScene { get; set; }

    private Label _title;
    private Label _count;
    private Label _teamName;
    private LineEdit _teamInput;
    private GridContainer _slots;

    public override void _Ready()
    {
        _title = GetNode<Label>("%TeamTitle");
        _count = GetNode<Label>("%PlayerCount");
        _teamName = GetNode<Label>("%TeamName");
        _teamInput = GetNode<LineEdit>("%TeamInput");
        _slots = GetNode<GridContainer>("%Slots");

        // El estilo es un recurso compartido entre instancias: se duplica para cambiar el color.
        var style = (StyleBoxFlat)GetThemeStylebox("panel").Duplicate();
        style.BgColor = PanelColor;
        AddThemeStyleboxOverride("panel", style);

        _title.Text = $"EQUIPO {TeamNumber}";
        _teamName.Text = $"Equipo {TeamNumber}";
        _teamInput.PlaceholderText = $"Nombre del equipo {TeamNumber}";

        for (int i = 0; i < JugadoresPorEquipo; i++)
            _slots.AddChild(SlotScene.Instantiate());
        MostrarJugadores(new List<string>());
    }

    /// <summary>Pinta las casillas con los nombres de los jugadores del equipo, en orden de llegada.</summary>
    public void MostrarJugadores(IReadOnlyList<string> nombres)
    {
        _count.Text = $"{nombres.Count} / {JugadoresPorEquipo} jugadores";
        for (int i = 0; i < _slots.GetChildCount(); i++)
        {
            Node slot = _slots.GetChild(i);
            bool taken = i < nombres.Count;
            slot.GetNode<Label>("Row/Name").Text = taken ? nombres[i] : $"Jugador {i + 1}";
            slot.GetNode<Label>("Row/Status").Text = taken ? "Conectado" : "Esperando…";
        }
    }

    /// <summary>Nombre escrito en el campo del equipo, o "Equipo N" si está vacío.</summary>
    public string NombreEquipo()
    {
        string nombre = _teamInput.Text.StripEdges();
        return nombre != "" ? nombre : $"Equipo {TeamNumber}";
    }
}
