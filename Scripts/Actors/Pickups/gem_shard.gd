class_name GemShard
extends Node3D

signal collected(shard_id: GemShard.ShardId)

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
@onready var sound: AudioStreamPlayer3D = $Sound
@onready var collision_shape_3d: CollisionShape3D = $Area3D/CollisionShape3D

var host_level: Level

func _ready() -> void:
	animation_player.play("spin")
	area_3d.body_entered.connect(_on_body_entered)
	GameManager.level_ready.connect(_on_level_ready)
	add_to_group("gem_shards")


func _on_level_ready(level: Level):
	host_level = level
	if level.level_state.is_gem_shard_collected(shard_id):
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	if body is Jack:
		GameManager.player_health += 1
		GameManager.player_confidence += 3
		animation_player.play("pickup")
		host_level.level_state.collect_gem_shard(shard_id)
		sound.play()
		await animation_player.animation_finished
		collected.emit(shard_id)
		queue_free()


func disable():
	hide()
	collision_shape_3d.disabled = true


func enable():
	show()
	collision_shape_3d.disabled = false
