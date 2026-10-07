extends Path3D
## Tablero: dueño de las fichas. Crea un PathFollow3D + equipo.tscn por cada equipo de
## GameManager.equipos y las anima. GameManager guarda la casilla; aquí se convierte en
## distancia sobre la curva.

const OFFSET_MISMA_CASILLA = 0.5  # separación lateral de las fichas que comparten casilla
const DURACION_MOVIMIENTO = 0.8  # segundos que tarda una ficha en hacer todo su recorrido
const ESCENA_FICHA := preload("res://Escenas/equipo.tscn")

var fichas: Dictionary = {}  # id del equipo -> Equipo (jugador.gd)


func crearFichas() -> void:
	for id in GameManager.equipos:
		var pathFollow := PathFollow3D.new()
		pathFollow.name = "PathFollow_%s" % id
		pathFollow.loop = false
		pathFollow.rotation_mode = PathFollow3D.ROTATION_NONE
		add_child(pathFollow)

		var ficha: Equipo = ESCENA_FICHA.instantiate()
		ficha.name = "equipo%s" % id
		pathFollow.add_child(ficha)
		ficha.configurar(GameManager.equipos[id].nombre, id, pathFollow)

		pathFollow.progress = GameManager.equipos[id].posicion * _distanciaPorCasilla()
		fichas[id] = ficha
	actualizarOffsets()


# Anima el recorrido que devuelve GameManager.moverFicha: avanza hasta "tope" y,
# si se pasó de la última casilla, retrocede hasta "final".
func animarFicha(movimiento: Dictionary) -> Tween:
	var pathFicha: PathFollow3D = fichas[movimiento.id].pathFicha
	var distancia := _distanciaPorCasilla()
	var avance: int = movimiento.tope - movimiento.inicio
	var retroceso: int = movimiento.tope - movimiento.final

	# Los tramos se ejecutan en orden; el tiempo se reparte según las casillas de cada uno.
	var segundosPorCasilla := DURACION_MOVIMIENTO / maxi(avance + retroceso, 1)
	var tween := create_tween()
	tween.tween_property(
		pathFicha, "progress", movimiento.tope * distancia, avance * segundosPorCasilla
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if retroceso > 0:
		tween.tween_property(
			pathFicha, "progress", movimiento.final * distancia, retroceso * segundosPorCasilla
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	actualizarOffsets(DURACION_MOVIMIENTO)
	return tween


# Separa las fichas que comparten casilla; una ficha sola en su casilla vuelve al centro.
# Con duracion > 0 el cambio se anima (animarFicha lo hace a la vez que el avance).
func actualizarOffsets(duracion := 0.0) -> void:
	var equipos := GameManager.equipos
	for id in fichas:
		var compartida: bool = equipos.keys().any(
			func(otro): return otro != id and equipos[otro].posicion == equipos[id].posicion)
		var offset := 0.0
		if compartida:
			offset = OFFSET_MISMA_CASILLA if id == 1 else -OFFSET_MISMA_CASILLA
		var pathFicha: PathFollow3D = fichas[id].pathFicha
		if duracion > 0.0:
			create_tween().tween_property(pathFicha, "h_offset", offset, duracion)
		else:
			pathFicha.h_offset = offset


# La casilla 0 es la salida; el camino tiene NUMERO_CASILLAS - 1 tramos iguales.
func _distanciaPorCasilla() -> float:
	return curve.get_baked_length() / float(GameManager.NUMERO_CASILLAS - 1)
