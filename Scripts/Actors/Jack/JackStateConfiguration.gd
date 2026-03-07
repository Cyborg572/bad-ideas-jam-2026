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

@export_subgroup("Carry", "carry_")
@export var carry_move_speed : float = 3.0
@export var carry_friction : float = 6.0
@export var carry_jump_strength : float = 1.0
@export var carry_max_move_speed : float = 3.0
@export var carry_max_speed : float = 3.0

func get_move_speed(attachment: Jack.Attachment):
	match attachment:
		Jack.Attachment.Free:
			return move_speed
		Jack.Attachment.Boxed:
			return boxed_move_speed


func get_friction(attachment: Jack.Attachment):
	match attachment:
		Jack.Attachment.Free:
			return friction
		Jack.Attachment.Boxed:
			return boxed_friction


func get_jump_strength(attachment: Jack.Attachment):
	match attachment:
		Jack.Attachment.Free:
			return jump_strength
		Jack.Attachment.Boxed:
			return boxed_jump_strength


func get_max_move_speed(attachment: Jack.Attachment):
	match attachment:
		Jack.Attachment.Free:
			return max_move_speed
		Jack.Attachment.Boxed:
			return boxed_max_move_speed


func get_max_speed(attachment: Jack.Attachment):
	match attachment:
		Jack.Attachment.Free:
			return max_speed
		Jack.Attachment.Boxed:
			return boxed_max_speed
