using Godot;
using System.Collections.Generic;

/// <summary>
/// Estado y reglas de la partida. Solo guarda datos: las fichas (nodos) las crea y anima
/// el tablero de Mundo (Tablero.cs), porque los nodos se destruyen al cambiar de escena
/// y este autoload vive durante todo el juego.
/// </summary>
public partial class GameManager : Node
{
    /// <summary>
    /// La única instancia del autoload. En C# no hay un nombre global como en GDScript:
    /// se accede con GameManager.Instancia desde cualquier script.
    /// </summary>
    public static GameManager Instancia { get; private set; }

    /// <summary>Casillas Tile_000..Tile_060 de tablero_juego.glb, incluida la de salida.</summary>
    public const int NumeroCasillas = 61;

    /// <summary>
    /// Categoría de cada color del tablero. En la montaña, la casilla 0 es la salida y desde la 1
    /// los colores repiten azul, rojo, amarillo, verde: la casilla N tiene la categoría
    /// Categorias[N % 4] (las verdes dan 0). Si cambia el modelo del tablero, hay que revisar este orden.
    /// </summary>
    public static readonly string[] Categorias = { "Interpretación", "Arte", "Conocimiento", "Lenguaje" }; // verde, azul, rojo, amarillo

    /// <summary>Contador que sube en cada AvanzarTurno(): sirve para descartar tiradas de un turno que ya acabó.</summary>
    public int TurnoActual { get; private set; } = 0;

    /// <summary>Equipo que juega (1 o 2).</summary>
    public int TurnoEquipoId { get; private set; }

    /// <summary>Id del equipo (1 o 2) -> sus datos (nombre y casilla).</summary>
    public Dictionary<int, Equipo> Equipos { get; } = new();

    [Signal]
    public delegate void TurnoEquipoCambiadoEventHandler(int equipoId);

    // _EnterTree se ejecuta antes que cualquier _Ready: así Instancia ya está lista
    // cuando la primera escena la necesite.
    public override void _EnterTree()
    {
        Instancia = this;
    }

    /// <summary>
    /// Deja lista una partida nueva: los equipos en la salida, el primer turno sorteado y el
    /// contador de turnos a cero. No cambia de escena, para que Mundo.tscn con F6 la use también.
    /// El id de cada equipo es su orden en la lista (1, 2...).
    /// </summary>
    public void PrepararPartida(IReadOnlyList<string> nombres)
    {
        Equipos.Clear();
        for (int i = 0; i < nombres.Count; i++)
            Equipos[i + 1] = new Equipo(nombres[i]);
        TurnoActual = 0;
        TurnoEquipoId = GD.RandRange(1, 2);
    }

    /// <summary>Desde el lobby: prepara la partida y pasa al tablero.</summary>
    public void RecibirDatos(string nombre1, string nombre2)
    {
        PrepararPartida(new[] { nombre1, nombre2 });
        GetTree().ChangeSceneToFile("res://Mundo/Mundo.tscn");
    }

    /// <summary>Mueve en los datos la ficha del equipo en turno y devuelve el recorrido para animarlo.</summary>
    public Movimiento MoverFicha(int casillas)
    {
        Equipo equipo = Equipos[TurnoEquipoId]; // siempre existe: lo crea PrepararPartida

        // Para ganar hay que caer exacto en la última casilla: si sobran puntos,
        // la ficha llega al final y retrocede las casillas que se pasó.
        int ultima = NumeroCasillas - 1;
        int inicio = equipo.Posicion;
        int destino = inicio + casillas;
        int exceso = Mathf.Max(destino - ultima, 0);
        equipo.Posicion = Mathf.Max(destino - 2 * exceso, 0);
        return new Movimiento(TurnoEquipoId, inicio, Mathf.Min(destino, ultima), equipo.Posicion);
    }

    /// <summary>Se gana al caer exacto en la última casilla (MoverFicha ya calcula el rebote).</summary>
    public bool HaGanado(int equipoId)
    {
        return Equipos[equipoId].Posicion == NumeroCasillas - 1;
    }

    public string CategoriaDeCasilla(int casilla)
    {
        return Categorias[casilla % Categorias.Length];
    }

    public void AvanzarTurno()
    {
        TurnoEquipoId = TurnoEquipoId == 1 ? 2 : 1;
        TurnoActual += 1;
        EmitSignal(SignalName.TurnoEquipoCambiado, TurnoEquipoId);
    }
}
