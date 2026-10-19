/// <summary>
/// Datos de un equipo en la partida. Los guarda GameManager.Equipos (clave: id 1 o 2).
/// </summary>
public class Equipo
{
    public string Nombre { get; }

    /// <summary>Casilla en la que está la ficha (0 = salida).</summary>
    public int Posicion { get; set; }

    public Equipo(string nombre)
    {
        Nombre = nombre;
        Posicion = 0;
    }
}
