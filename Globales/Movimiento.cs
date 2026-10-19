/// <summary>
/// Recorrido de una ficha: lo calcula GameManager.MoverFicha y lo anima Tablero.AnimarFicha.
/// Las casillas van de 0 (salida) a GameManager.NumeroCasillas - 1 (meta).
/// </summary>
/// <param name="EquipoId">Equipo al que pertenece la ficha (1 o 2).</param>
/// <param name="Inicio">Casilla de partida.</param>
/// <param name="Tope">Casilla más lejana a la que llega; es la meta si se pasó.</param>
/// <param name="Final">Casilla donde se queda; si no rebota, Tope == Final.</param>
public record Movimiento(int EquipoId, int Inicio, int Tope, int Final);
