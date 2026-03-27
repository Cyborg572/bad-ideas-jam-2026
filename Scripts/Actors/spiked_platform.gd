class_name SpikedPlatform
extends Platform

func _ready() -> void:
	trigger_zone.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not body is Jack:
		return

	var jack = body as Jack

	if not jack.is_boxed:
		hurt_jack()
		jack.popToBox()
		return

	if not jack.is_hiding:
		# Slight offset so the top half of sideways spikes are effective
		if (global_position.y + 1 > jack.global_position.y) or jack.is_hanging:
			hurt_jack()
			var jack_direction = jack.global_position - global_position
			jack.velocity += jack_direction.normalized() * 4


func hurt_jack() -> void:
	GameManager.player_health -= 1
