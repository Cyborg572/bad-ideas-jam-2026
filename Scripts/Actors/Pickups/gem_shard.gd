class_name GemShard
extends Node3D

enum ShardId {
	NONE,
	SHARD_1,
	SHARD_2,
	SHARD_3,
	SHARD_4,
	SHARD_5,
	SHARD_6,
	SHARD_7,
	SHARD_8,
}

@export var shard_id: ShardId = ShardId.NONE

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var area_3d: Area3D = $Area3D


func _ready() -> void:
	animation_player.play("spin")
	area_3d.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body is Jack:
		GameManager.player_health += 1
		GameManager.player_confidence += 3
		animation_player.play("pickup")
		await animation_player.animation_finished
		queue_free()
