class_name Mullberry
extends Node3D

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var area_3d: Area3D = $Area3D


func _ready() -> void:
	animation_player.play("bob")
	area_3d.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body is Jack:
		GameManager.player_health += 1
		GameManager.player_confidence += 3
		animation_player.play("pickup")
		await animation_player.animation_finished
		queue_free()
