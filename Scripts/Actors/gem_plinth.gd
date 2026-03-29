@tool
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

	if lock_enabled:
		lock()
		if not lock_trigger == null:
			lock_trigger.triggered.connect(_on_unlock_trigger)
			lock_trigger.untriggered.connect(lock)
	else:
		unlock()

	if not is_gem_claimed():
		fake_gem.hide()
		spawn_gem.call_deferred()
	else:
		lock()

	anim.active = true
	interaction_point.interaction.connect(_on_interaction)


func _on_unlock_trigger(_by: Node3D) -> void:
	GameManager.achieve_goal()
	if not is_gem_claimed():
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

	lock()
	gem.detach()
	gem.attach(self)
	unlock()
	change_interaction_type.call_deferred(InteractionPoint.InteractionType.dispenser)


func _on_gem_claimed() -> void:
	lock()


func change_interaction_type(type: InteractionPoint.InteractionType) -> void:
	interaction_point.type = type


func get_active_level() -> Level:
	if GameManager.active_level:
		return GameManager.active_level

	var candidate : Node3D = self
	while candidate and not candidate is Level:
		candidate = candidate.get_parent()

	return candidate


func is_gem_claimed() -> bool:
	var active_level: Level = get_active_level()
	return active_level.level_state.is_gem_collected(gem_id)


func lock() -> void:
	locked = true
	interaction_point.disabled = true


func unlock() -> void:
	locked = false
	interaction_point.disabled = false


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

	add_sibling(gem)
	gem.attach(self)

	gem.claimed.connect(_on_gem_claimed)
