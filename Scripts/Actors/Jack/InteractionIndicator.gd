class_name InteractionIndicator
extends Node3D

@onready var parent : Jack = $".."

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	visible = false
	scale = Vector3.ZERO
	top_level = true


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var should_indicate : bool = false
	var interaction_point := GameManager.active_interaction_point

	if GameManager.active_interaction_point:
		var types := InteractionPoint.InteractionType

		match interaction_point.type:
			types.attachable, types.dispenser:
				should_indicate = not parent.is_carrying && not parent.state == Jack.State.Crouched
			_:
				should_indicate = true

	if should_indicate:
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
