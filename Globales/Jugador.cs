/// <summary>
/// Un jugador conectado desde el celular. Hub.Players los guarda en orden de llegada.
/// </summary>
/// <param name="Id">Id que le da el servidor (se conserva al reconectarse).</param>
/// <param name="Nombre">Nombre que escribió en el celular (1 a 16 caracteres).</param>
/// <param name="EquipoId">Equipo elegido (1 o 2).</param>
public record Jugador(string Id, string Nombre, int EquipoId);
