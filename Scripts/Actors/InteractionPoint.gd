@tool
class_name InteractionPoint
extends Area3D

signal interaction(interaction_point: InteractionPoint)

enum InteractionType {
	## The object will define the interaction type dynamically.
	custom,

	## The object can be picked up.
	attachable,

	## The object is a sign (or speaking NPC)
	sign,

	## The object is switch
	switch,

	## The object can be given an attachable object to hold
	carrier,
}

## What kind of interaction's are triggerd by this interaction point.
@export var type := InteractionType.custom

## Prevent interactions entirely
@export var disabled : bool = false

@export_subgroup("Options")

## Only activates when the player is close and roughly facing the interaction center
@export var require_focus : bool = false

## This object takes priority over other interactable objects
@export var sticky : bool = false

@export_subgroup("Indicator", "pointer_")
## Show the interaction indicator's position in the editor.
@export var pointer_show_reference : bool = true

## Where should the player interaction indicator appear?
@export var pointer_position : Vector3 = Vector3.UP


## Indicates this is the current focused interactable.
var active : bool = false

## Bodies to monitor (when focus is required)
var monitored_bodies : Array[CharacterBody3D] = []

## The indictor reference (appears only in the editor, and only when enabled)
var pointer_refence : MeshInstance3D


func get_global_pointer_position() -> Vector3:
	return global_position + pointer_position


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if Engine.is_editor_hint():
		pointer_refence = MeshInstance3D.new()
		pointer_refence.mesh = BoxMesh.new()
		pointer_refence.mesh.size = Vector3(0.1, 0.1, 0.1)
		self.add_child(pointer_refence, false, Node.INTERNAL_MODE_FRONT)
		

	# Connect the signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Configure the collision mask and layers
	collision_layer = 3 # Layers 1(1) and 2(2) 
	collision_mask = 4 # Layer 3(4)

	if disabled:
		disable()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		pointer_refence.position = pointer_position
		pointer_refence.visible = pointer_show_reference

	if require_focus and not disabled:
		check_for_focus()


func interact() -> void:
	interaction.emit(self)


## Make this interaction point non-interactable
func disable() -> void:
	disabled = true
	visible = false
	monitored_bodies = []
	GameManager.clear_active_interaction_point(self)


## Make this interaction point non-interactable
func enable() -> void:
	visible = true
	disabled = false

	# Pretend any bodies that are already in the Area just entered.
	if has_overlapping_bodies():
		for body in get_overlapping_bodies():
			_on_body_entered.call_deferred(body)


## Mark this interaction point as the currently focused point
func activate() -> void:
	active = true


## Clear this interaction point as the currently focused point
func deactivate() -> void:
	active = false


## Checks if a body that could trigger the interaction is looking at this point.
func check_for_focus() -> void:
	if monitored_bodies.is_empty(): return

	for body in monitored_bodies:
		var offset = (global_position - body.global_position).normalized()
		var facing = Vector3.MODEL_FRONT.rotated(Vector3.UP, body.rotation.y).normalized()
		if (offset.dot(facing) > 0.5):
			GameManager.set_active_interaction_point(self)
		else:
			GameManager.clear_active_interaction_point(self)


func _on_body_entered(body: Node3D) -> void:
	if disabled: return

	if not require_focus:
		GameManager.set_active_interaction_point(self)
		return

	if body in monitored_bodies || not body is CharacterBody3D:
		return

	monitored_bodies.push_back(body)


func _on_body_exited(body: Node3D) -> void:
	if not disabled:
		GameManager.clear_active_interaction_point(self)
		monitored_bodies.erase(body)
