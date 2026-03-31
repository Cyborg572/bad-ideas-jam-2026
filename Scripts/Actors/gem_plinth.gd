class_name GemPlinth
extends Node3D


@export var gem_id: Gem.GemID:
	set(id):
		gem_id = id
		if signpost and signpost.is_node_ready():
			signpost.visible = gem_id == Gem.GemID.GEM_3

@export_group("Locked", "lock_")
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "") var lock_enabled : bool = false
@export var lock_trigger : Node3D

var locked: bool = true
var gem: Gem
var active_level: Level
var gem_claimed: bool = false
var gem_scene: PackedScene = preload("uid://detj4tonpd81q")

@onready var signpost: Sign = $signpost
@onready var fake_gem: MeshInstance3D = $FakeGem
@onready var attachment_point: Node3D = $FakeGem/AttachmentPoint
@onready var anim: AnimationTree = $AnimationTree
@onready var interaction_point: InteractionPoint = $InteractionPoint


func _ready() -> void:
	if gem_id == Gem.GemID.GEM_3:
		signpost.enable()
	else:
		signpost.disable()

	anim.active = true
	interaction_point.interaction.connect(_on_interaction)
	GameManager.level_ready.connect(_on_level_ready)


func _on_level_ready(level: Level) -> void:
	active_level = level
	gem_claimed = level.level_state.is_gem_collected(gem_id)

	if gem_claimed:
		fake_gem.show()
	else:
		fake_gem.hide()

	if lock_enabled:
		lock()
		if not lock_trigger == null:
			lock_trigger.triggered.connect(_on_unlock_trigger)
			lock_trigger.untriggered.connect(lock)
	else:
		unlock()

	if gem_id == Gem.GemID.GEM_3:
		var shards: Array[Node] = get_tree().get_nodes_in_group("gem_shards")
		for shard in shards:
			if shard is GemShard:
				shard.collected.connect(_on_gem_shard_collected)
		if are_shards_all_collected():
			unlock()
		else:
			lock()


func _on_gem_shard_collected(_shard_id: GemShard.ShardId) -> void:
	if are_shards_all_collected():
		GameManager.achieve_goal()
		GameManager.show_message(signpost.image, "You've collected all 8 gem shards! Come get your prize")
		unlock()


func _on_unlock_trigger(_by: Node3D) -> void:
	GameManager.achieve_goal()
	unlock()


func _on_interaction(point: InteractionPoint) -> void:
	if not point.type == InteractionPoint.InteractionType.custom:
		return

	# A claimed gem will no longer exist
	if gem == null or gem.get_parent() == null:
		return

	# Don't summon from Jack's arms
	if gem.has_attachment:
		return

	#lock()
	gem.detach()
	gem.attach(self)
	unlock()
	change_interaction_type.call_deferred(InteractionPoint.InteractionType.dispenser)


func _on_gem_claimed() -> void:
	lock()


func are_shards_all_collected() -> bool:
	for shard_id in GemShard.ShardId.values():
		if shard_id == GemShard.ShardId.NONE:
			continue
		if not active_level.level_state.is_gem_shard_collected(shard_id):
			return false
	return true


func change_interaction_type(type: InteractionPoint.InteractionType) -> void:
	interaction_point.type = type


func lock() -> void:
	locked = true
	interaction_point.disable()


func unlock() -> void:
	locked = false
	if gem == null and not gem_claimed:
		spawn_gem()
		interaction_point.enable()
	elif gem_claimed:
		fake_gem.show()
		interaction_point.disable()


func would_receive_item(_item: Attachable) -> bool:
	# The plinth only gives, it does not accept
	return false


func hold_item(item: Attachable, _delta: float) -> void:
	item.track(0, attachment_point)


func get_offered_item() -> Attachable:
	return gem


func give_item(to: CharacterBody3D) -> void:
	get_parent().move_child(gem, GameManager.jack.get_index() + 1)
	gem.give_to(to)
	interaction_point.type = InteractionPoint.InteractionType.custom


func spawn_gem() -> void:
	gem = gem_scene.instantiate()
	gem.gem_id = gem_id

	add_sibling.call_deferred(gem)
	await gem.ready

	gem.attach(self)

	gem.claimed.connect(_on_gem_claimed)
