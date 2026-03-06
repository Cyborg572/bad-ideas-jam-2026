class_name InteractionIndicator
extends Node3D

@onready var parent : Node3D = $".."

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	visible = false
	scale = Vector3.ZERO


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if GameManager.active_interaction_point:
		var interaction_point := GameManager.active_interaction_point
		var pointer_position = interaction_point.get_global_pointer_position()
		position = position.move_toward(pointer_position, 10 * delta)
		scale = scale.move_toward(Vector3(1, 1, 1), 10 * delta)
	else:
		var rest_position := parent.global_position
		if parent.camera_target:
			rest_position = parent.camera_target.global_position
		position = position.move_toward(rest_position, 10 * delta)
		scale = scale.move_toward(Vector3.ZERO, 10 * delta)
	
	visible = scale.y > 0.1;
