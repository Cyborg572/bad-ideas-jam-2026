class_name SpikedPlatform
extends Platform

func _ready() -> void:
	super()
	trigger_zone.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not body is Jack:
		return

	var jack = body as Jack

	if jack.is_hiding:
		return

	if jack.is_boxed:
		if (
			(rotation.x != 0.0 or rotation.z != 0.0)
			and (
				# Slight offset so the top half of sideways spikes are effective
				(global_position.y + 1 > jack.global_position.y)
				or jack.is_hanging
			)
		):
			GameManager.hurt_player()
			var jack_direction = jack.global_position - global_position
			print(jack_direction)
			jack.velocity += jack_direction.normalized() * 4
		return

	GameManager.hurt_player()
	jack.popToBox()
