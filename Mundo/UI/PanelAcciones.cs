using Godot;

/// <summary>
/// Panel del turno: "Turno de X" y el botón de tirar. Para que no se pueda tirar,
/// Mundo.cs oculta el panel con Hide() (el botón nunca se deshabilita).
/// </summary>
public partial class PanelAcciones : PanelContainer
{
    /// <summary>Mundo.cs la escucha y hace la tirada completa.</summary>
    [Signal]
    public delegate void TirarPulsadoEventHandler();

    private Label _labelEquipo;

    public override void _Ready()
    {
        _labelEquipo = GetNode<Label>("MarginContainer/VBoxContainer/labelEquipoDeTurno");
    }

    /// <summary>Aviso de inicio de turno: muestra el panel con el equipo que juega.</summary>
    public void MostrarTurno(string nombreEquipo)
    {
        _labelEquipo.Text = $"Turno de {nombreEquipo}";
        Show();
    }

    // Conectada desde panelAcciones.tscn a botonTirarDado.pressed (no desde el código).
    private void OnBotonTirarDadoPressed()
    {
        EmitSignal(SignalName.TirarPulsado);
    }
}
