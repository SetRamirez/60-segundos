class_name Movimiento
extends RefCounted
## Recorrido de una ficha: lo calcula GameManager.moverFicha y lo anima tablero.animarFicha.
## Las casillas van de 0 (salida) a NUMERO_CASILLAS - 1 (meta).

var equipoId: int
var inicio: int  # casilla de partida
var tope: int  # casilla más lejana a la que llega; es la meta si se pasó
var final: int  # casilla donde se queda; si no rebota, tope == final


func _init(_equipoId: int, _inicio: int, _tope: int, _final: int) -> void:
	equipoId = _equipoId
	inicio = _inicio
	tope = _tope
	final = _final
