class_name SpikedPlatform
extends Platform

func _ready() -> void:
	super()
	trigger_zone.body_shape_entered.connect(_on_body_shape_entered)


func _on_body_shape_entered(_body_rid: RID, body: Node3D, body_shape_index: int, _local_shape_index: int) -> void:
	if not body is Jack:
		return

	var jack = body as Jack

	if jack.is_hiding:
		return

	var collision_shape = jack.shape_owner_get_owner(jack.shape_find_owner(body_shape_index))
	if not collision_shape == jack.body_collider:
		return

	if jack.is_boxed:
		GameManager.hurt_player()
		var jack_direction = jack.global_position - global_position
		print(jack_direction)
		jack.velocity += jack_direction.normalized() * 4
		return

	GameManager.hurt_player()
	jack.popToBox()
