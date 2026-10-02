extends RigidBody3D

@onready var raycasts = $Raycasts.get_children() 

var pos_inicial
var fuerza_tiro = 30

signal tiro_finalizado(valor)


func _ready():
	GameManager.tirar_dado.connect(_tirar)
	pos_inicial = global_position

func _simular_dado():
	_tirar()

func _tirar():
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


func _on_sleeping_state_changed() -> void:
	if sleeping:
		for raycast in raycasts:
			if raycast.is_colliding():
				tiro_finalizado.emit(raycast.opposite_side)
