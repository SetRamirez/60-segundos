class_name Equipo
extends Node3D



var nombre : String
var id : int 
var posicion : int = 0
var pathFicha : PathFollow3D

func configurar(_nombre:String, _id:int, _pathFicha : PathFollow3D):
	nombre = _nombre
	id = _id
	pathFicha = _pathFicha
