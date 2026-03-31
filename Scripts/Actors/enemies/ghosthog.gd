class_name Ghosthog
extends Hedgehog

@export var shard_id: GemShard.ShardId

var shard: GemShard = null
var shard_scene: PackedScene = preload("uid://5qgf14nbd4k")
var fake_gem_material: Material = preload("uid://bqlwuf517ds53")
var real_gem_material: Material = preload("uid://bmfpnow5p5tc0")
var active_level: Level

@onready var mesh: MeshInstance3D = $Armature/Skeleton3D/Sphere

func _ready() -> void:
	super()
	GameManager.level_ready.connect(_on_level_ready)

func _on_level_ready(level: Level):
	active_level = level
	if active_level.level_state.is_gem_shard_collected(shard_id):
		make_shell_fake()


func enter_state(new_state: State) -> void:
	if state == State.STUNNED:
		if not shard == null:
			shard.disable()
			make_shell_real()

	super(new_state)

	if new_state == State.STUNNED:
		drop_shard()


func make_shell_fake():
	mesh.set_surface_override_material(1, fake_gem_material)


func make_shell_real():
	mesh.set_surface_override_material(1, real_gem_material)


func drop_shard():
	# Can't drop an already-collected shard
	if active_level.level_state.is_gem_shard_collected(shard_id):
		return

	if shard == null:
		shard = shard_scene.instantiate()
		shard.shard_id = shard_id
		shard.host_level = active_level
		add_sibling(shard)
	else:
		shard.enable()

	make_shell_fake()
	shard.global_position = global_position + Vector3.UP * 0.25
