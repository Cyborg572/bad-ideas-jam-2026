class_name JackStateConfiguration
extends Resource

@export_subgroup("Default")
@export var move_speed : float = 4.0
@export var friction : float = 6.0
@export var jump_strength : float = 4.0
@export var max_move_speed : float = 3.0
@export var max_speed : float = 6.0

@export_subgroup("Boxed", "boxed_")
@export var boxed_move_speed : float = 0
@export var boxed_friction : float = 10.0
@export var boxed_jump_strength : float = 0.5
@export var boxed_max_move_speed : float = 0
@export var boxed_max_speed : float = 6.0

func get_move_speed(is_boxed: bool):
	match is_boxed:
		false:
			return move_speed
		true:
			return boxed_move_speed


func get_friction(is_boxed: bool):
	match is_boxed:
		false:
			return friction
		true:
			return boxed_friction


func get_jump_strength(is_boxed: bool):
	match is_boxed:
		false:
			return jump_strength
		true:
			return boxed_jump_strength


func get_max_move_speed(is_boxed: bool):
	match is_boxed:
		false:
			return max_move_speed
		true:
			return boxed_max_move_speed


func get_max_speed(is_boxed: bool):
	match is_boxed:
		false:
			return max_speed
		true:
			return boxed_max_speed
