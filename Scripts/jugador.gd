class_name Equipo
extends Node3D



var nombre : String
var id : int
var pathFicha : PathFollow3D  # la casilla no se guarda aquí: está en GameManager.equipos[id].posicion

func configurar(_nombre:String, _id:int, _pathFicha : PathFollow3D):
	nombre = _nombre
	id = _id
	pathFicha = _pathFicha
