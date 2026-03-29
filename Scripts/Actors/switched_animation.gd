class_name SwitchedAnimation
extends Node

## Plays animations in other nodes when triggered

@export var trigger: Node3D
@export var targets: Array[Node]
@export var on_animation: StringName
@export var off_animation: StringName


func _ready() -> void:
	if trigger.has_signal("triggered"):
		trigger.triggered.connect(_on_trigger_triggered)
		trigger.untriggered.connect(_on_trigger_untriggered)


func _on_trigger_triggered(_by: Node3D) -> void:
	for target in targets:
		if target is AnimationPlayer:
			play_on_animation(target)
			continue

		var anim = target.get_node_or_null("AnimationPlayer")
		if not anim == null:
			play_on_animation(anim)

func _on_trigger_untriggered() -> void:
	for target in targets:
		if target is AnimationPlayer:
			play_off_animation(target)
			continue

		var anim = target.get_node_or_null("AnimationPlayer")
		if not anim == null:
			play_off_animation(anim)


func play_on_animation(player: AnimationPlayer) -> void:
	player.play(on_animation)


func play_off_animation(player: AnimationPlayer) -> void:
	if off_animation == &"":
		player.play_backwards(on_animation)
	else:
		player.play(off_animation)
