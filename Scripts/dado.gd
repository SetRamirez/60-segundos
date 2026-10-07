extends RigidBody3D

@onready var raycasts = $Raycasts.get_children()

## Velocidad (lineal y angular) por debajo de la cual el dado se considera quieto.
@export var umbral_quieto := 0.1
## Segundos seguidos que tiene que estar quieto para leer el resultado.
@export var tiempo_quieto := 0.4
## Si pasado este tiempo el dado sigue moviéndose (vibra, se cayó de la mesa...), se vuelve a tirar.
@export var tiempo_maximo := 8.0
## Qué tan hacia abajo debe apuntar la cara apoyada (1 = perfectamente plana) para aceptar el resultado.
@export var alineacion_minima := 0.9

var pos_inicial
var fuerza_tiro = 30
var lanzando := false  # evita emitir un resultado cuando el dado se queda quieto sin haber sido tirado
var _segundos_quieto := 0.0
var _segundos_lanzado := 0.0

signal tiro_finalizado(valor)


func _ready():
	GameManager.simular_dado.connect(_tirar)
	pos_inicial = global_position

func _tirar():
	if lanzando:
		return
	_lanzar()

# También se usa para repetir la tirada cuando el dado queda inclinado o no se detiene.
func _lanzar():
	lanzando = true
	_segundos_quieto = 0.0
	_segundos_lanzado = 0.0
	sleeping = false
	freeze = false
	transform.origin = pos_inicial
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

	transform.basis = Basis(Vector3.RIGHT, randf_range(0, 2*PI))*transform.basis
	transform.basis = Basis(Vector3.UP, randf_range(0, 2*PI))*transform.basis
	transform.basis = Basis(Vector3.FORWARD, randf_range(0, 2*PI))*transform.basis

	var throw_vector = Vector3(randf_range(-1,1),0,randf_range(-1,1)).normalized()
	angular_velocity = throw_vector * fuerza_tiro / 2
	apply_central_impulse(throw_vector*fuerza_tiro)


func _physics_process(delta: float) -> void:
	if not lanzando:
		return
	_segundos_lanzado += delta
	if linear_velocity.length() < umbral_quieto and angular_velocity.length() < umbral_quieto:
		_segundos_quieto += delta
		if _segundos_quieto >= tiempo_quieto:
			_leer_resultado()
	else:
		_segundos_quieto = 0.0
		if _segundos_lanzado > tiempo_maximo:
			_lanzar()

# La cara apoyada en la mesa es la del raycast que apunta más hacia abajo.
func _leer_resultado():
	var cara_abajo = null
	var mejor_alineacion := -1.0
	for raycast in raycasts:
		var direccion: Vector3 = (raycast.global_basis * raycast.target_position).normalized()
		var alineacion := direccion.dot(Vector3.DOWN)
		if alineacion > mejor_alineacion:
			mejor_alineacion = alineacion
			cara_abajo = raycast
	if mejor_alineacion < alineacion_minima:
		_lanzar()  # quedó inclinado (apoyado en una pared o en una arista): se repite
		return
	lanzando = false
	tiro_finalizado.emit(cara_abajo.opposite_side)
