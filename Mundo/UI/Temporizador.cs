using Godot;

public partial class Temporizador : CanvasLayer
{
    [Signal]
    public delegate void TiempoAgotadoEventHandler();

    private Label _mostrarTemporizador;
    private Timer _temporizador;

    public override void _Ready()
    {
        _mostrarTemporizador = GetNode<Label>("Control/Node2D/texto_temporizador");
        _temporizador = GetNode<Timer>("temporizador");
        _temporizador.Timeout += () => EmitSignal(SignalName.TiempoAgotado);
    }

    public override void _Process(double delta)
    {
        // Detenido, TimeLeft es 0: se muestra el tiempo completo del turno.
        double segundos = _temporizador.IsStopped() ? _temporizador.WaitTime : _temporizador.TimeLeft;
        _mostrarTemporizador.Text = ((int)segundos).ToString(); // sin decimales, como pad_decimals(0)
    }

    /// <summary>Arranca la cuenta solo si no está corriendo: los movimientos posteriores del turno no la reinician.</summary>
    public void Iniciar()
    {
        if (_temporizador.IsStopped())
            _temporizador.Start();
    }

    /// <summary>Detiene la cuenta y la deja lista (en 60) para el siguiente turno.</summary>
    public void Reiniciar()
    {
        _temporizador.Stop();
    }
}
