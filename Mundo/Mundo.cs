using Godot;

public partial class Mundo : Node3D
{
    /// <summary>Segundos que la cámara se queda en la mesa mostrando el resultado antes de volver.</summary>
    [Export] public float PausaResultado { get; set; } = 1.0f;

    private Camera3D _camara3D;
    private Marker3D _vistaMesaDados;
    private Label3D _resultadoDado;
    private Label3D _mensajeGanador; // en el centro del tablero
    private Label3D _mensajeCategoria; // categoría de la casilla
    private Tablero _tablero; // crea y anima las fichas
    private Dado _dado;
    private Temporizador _temporizador;
    private PanelAcciones _panelAcciones;

    private bool _tiradaEnCurso = false; // desde que se pulsa tirar hasta que la ficha termina de moverse

    public override void _Ready()
    {
        _camara3D = GetNode<Camera3D>("Camera3D");
        _vistaMesaDados = GetNode<Marker3D>("posicionCamaras/vistaMesaDados");
        _resultadoDado = GetNode<Label3D>("resultado-dado");
        _mensajeGanador = GetNode<Label3D>("mensajeGanador");
        _mensajeCategoria = GetNode<Label3D>("mensajeCategoria");
        _tablero = GetNode<Tablero>("Path3D");
        _dado = GetNode<Dado>("Dado");
        _temporizador = GetNode<Temporizador>("Temporizador");
        _panelAcciones = GetNode<PanelAcciones>("HUD/PanelAcciones");

        var gm = GameManager.Instancia;
        // Al ejecutar Mundo.tscn directamente (F6) no se pasa por el lobby: partida con equipos de prueba.
        if (gm.Equipos.Count == 0)
            gm.PrepararPartida(new[] { "Equipo 1", "Equipo 2" });
        // Se llama desde aquí y no desde el _Ready del tablero: los hijos ejecutan _Ready antes
        // que el padre, y el tablero aún no vería los equipos de prueba.
        _tablero.CrearFichas();
        _panelAcciones.TirarPulsado += Tirar;
        gm.TurnoEquipoCambiado += OnTurnoEquipoCambiado;
        _temporizador.TiempoAgotado += gm.AvanzarTurno;
        MostrarTurno();
    }

    // GameManager es un autoload y sobrevive a esta escena: se desconecta su señal al salir.
    public override void _ExitTree()
    {
        GameManager.Instancia.TurnoEquipoCambiado -= OnTurnoEquipoCambiado;
    }

    // Aviso de inicio de turno: el panel centrado con el equipo que juega y el botón de tirar.
    private void MostrarTurno()
    {
        var gm = GameManager.Instancia;
        _panelAcciones.MostrarTurno(gm.Equipos[gm.TurnoEquipoId].Nombre);
    }

    // Una tirada completa, de principio a fin. Solo se avanza dentro del minuto: si el reloj
    // se agota a mitad de la tirada, el turno cambia en ese momento (AvanzarTurno), y aquí se
    // compara TurnoActual con el de cuando se pulsó tirar.
    // Es "async void" porque la llama una señal, que no espera ningún resultado.
    private async void Tirar()
    {
        var gm = GameManager.Instancia;
        int turno = gm.TurnoActual;
        _tiradaEnCurso = true;
        _panelAcciones.Hide(); // no tapa la tirada y evita pulsar dos veces
        _mensajeCategoria.Hide(); // la categoría anterior ya no vale

        // Solo se usa la posición del marcador: se conserva la rotación actual (mirando hacia abajo).
        Transform3D vista = _camara3D.GlobalTransform;
        Transform3D mesa = vista;
        mesa.Origin = _vistaMesaDados.GlobalPosition;
        MoverCamaraA(mesa); // sin await: el dado rueda mientras la cámara llega a la mesa
        int valor = await _dado.Lanzar();
        _resultadoDado.Text = valor.ToString();
        await ToSignal(GetTree().CreateTimer(PausaResultado), SceneTreeTimer.SignalName.Timeout);
        await ToSignal(MoverCamaraA(vista), Tween.SignalName.Finished);

        // La ficha avanza cuando la cámara ya volvió al tablero, para que se vea el movimiento.
        // Si el tiempo se acaba con la ficha ya en marcha, termina de moverse (y puede ganar).
        if (gm.TurnoActual == turno)
        {
            Movimiento movimiento = gm.MoverFicha(valor);
            await ToSignal(_tablero.AnimarFicha(movimiento), Tween.SignalName.Finished);
            if (gm.HaGanado(movimiento.EquipoId))
            {
                MostrarGanador(movimiento.EquipoId);
                return;
            }
        }

        _tiradaEnCurso = false;
        if (gm.TurnoActual != turno)
        {
            MostrarTurno(); // el aviso del nuevo equipo quedó pendiente
            return;
        }
        // El tiempo del turno empieza cuando la ficha termina su primer movimiento.
        // Después de moverse, el panel vuelve para que el equipo pueda tirar otra vez en su turno.
        MostrarCategoria();
        _temporizador.Iniciar();
        _panelAcciones.Show();
    }

    // Por ahora solo se muestra; aquí se engancharán las preguntas de esa categoría.
    private void MostrarCategoria()
    {
        var gm = GameManager.Instancia;
        int casilla = gm.Equipos[gm.TurnoEquipoId].Posicion;
        _mensajeCategoria.Text = $"Categoría: {gm.CategoriaDeCasilla(casilla)}";
        _mensajeCategoria.Show();
    }

    private void MostrarGanador(int equipoId)
    {
        _temporizador.Reiniciar();
        _panelAcciones.Hide();
        _mensajeCategoria.Hide();
        _mensajeGanador.Text = $"¡Gana {GameManager.Instancia.Equipos[equipoId].Nombre}!";
        _mensajeGanador.Show();
    }

    private Tween MoverCamaraA(Transform3D destino, float duracion = 0.6f)
    {
        Tween tween = CreateTween();
        tween.SetTrans(Tween.TransitionType.Cubic).SetEase(Tween.EaseType.Out);
        tween.TweenProperty(_camara3D, "global_transform", destino, duracion);
        return tween;
    }

    // El nuevo equipo empieza con el reloj en 60; corre tras su primer movimiento.
    // Si hay una tirada a medias, el aviso espera a que termine para no mezclar dos tiradas.
    private void OnTurnoEquipoCambiado(int equipoId)
    {
        _temporizador.Reiniciar();
        _mensajeCategoria.Hide();
        if (!_tiradaEnCurso)
            MostrarTurno();
    }
}
