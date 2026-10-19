using Godot;
using System.Collections.Generic;
using System.Linq;

/// <summary>
/// Tablero: dueño de las fichas. Crea un PathFollow3D + equipo.tscn por cada equipo de
/// GameManager.Equipos y las anima. GameManager guarda la casilla; aquí se convierte en
/// distancia sobre la curva.
/// </summary>
public partial class Tablero : Path3D
{
    private const float OffsetMismaCasilla = 0.5f; // separación lateral de las fichas que comparten casilla
    private const float DuracionMovimiento = 0.8f; // segundos que tarda una ficha en hacer todo su recorrido

    // En C# no hay preload: GD.Load carga la escena cuando se crea el tablero.
    private readonly PackedScene _escenaFicha = GD.Load<PackedScene>("res://Mundo/Ficha/equipo.tscn");

    /// <summary>Id del equipo -> PathFollow3D que lleva su ficha (equipo.tscn).</summary>
    public Dictionary<int, PathFollow3D> Fichas { get; } = new();

    public void CrearFichas()
    {
        foreach (var (id, equipo) in GameManager.Instancia.Equipos)
        {
            var pathFollow = new PathFollow3D
            {
                Name = $"PathFollow_{id}",
                Loop = false,
                RotationMode = PathFollow3D.RotationModeEnum.None,
            };
            AddChild(pathFollow);

            var ficha = _escenaFicha.Instantiate<Node3D>();
            ficha.Name = $"equipo{id}";
            pathFollow.AddChild(ficha);

            pathFollow.Progress = equipo.Posicion * DistanciaPorCasilla();
            Fichas[id] = pathFollow;
        }
        ActualizarOffsets();
    }

    /// <summary>
    /// Anima el recorrido que devuelve GameManager.MoverFicha: avanza hasta Tope y,
    /// si se pasó de la última casilla, retrocede hasta Final.
    /// </summary>
    public Tween AnimarFicha(Movimiento movimiento)
    {
        PathFollow3D pathFicha = Fichas[movimiento.EquipoId];
        float distancia = DistanciaPorCasilla();
        int avance = movimiento.Tope - movimiento.Inicio;
        int retroceso = movimiento.Tope - movimiento.Final;

        // Los tramos se ejecutan en orden; el tiempo se reparte según las casillas de cada uno.
        // Las propiedades se nombran como en Godot (snake_case): "progress", no "Progress".
        float segundosPorCasilla = DuracionMovimiento / Mathf.Max(avance + retroceso, 1);
        Tween tween = CreateTween();
        tween.TweenProperty(pathFicha, "progress", movimiento.Tope * distancia, avance * segundosPorCasilla)
            .SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.InOut);
        if (retroceso > 0)
        {
            tween.TweenProperty(pathFicha, "progress", movimiento.Final * distancia, retroceso * segundosPorCasilla)
                .SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.InOut);
        }
        ActualizarOffsets(DuracionMovimiento);
        return tween;
    }

    /// <summary>
    /// Separa las fichas que comparten casilla; una ficha sola en su casilla vuelve al centro.
    /// Con duracion > 0 el cambio se anima (AnimarFicha lo hace a la vez que el avance).
    /// </summary>
    public void ActualizarOffsets(float duracion = 0.0f)
    {
        var equipos = GameManager.Instancia.Equipos;
        foreach (var (id, pathFicha) in Fichas)
        {
            bool compartida = equipos.Any(otro => otro.Key != id && otro.Value.Posicion == equipos[id].Posicion);
            float offset = 0.0f;
            if (compartida)
                offset = id == 1 ? OffsetMismaCasilla : -OffsetMismaCasilla;
            if (duracion > 0.0f)
                CreateTween().TweenProperty(pathFicha, "h_offset", offset, duracion);
            else
                pathFicha.HOffset = offset;
        }
    }

    // La casilla 0 es la salida; el camino tiene NumeroCasillas - 1 tramos iguales.
    private float DistanciaPorCasilla()
    {
        return Curve.GetBakedLength() / (GameManager.NumeroCasillas - 1);
    }
}
