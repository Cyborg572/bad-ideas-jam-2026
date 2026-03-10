class_name Attachable
extends CharacterBody3D

signal attached(attachable: Attachable, target : Node3D)
signal detached(attachable: Attachable, target : Node3D)

@export var has_attachment : bool = false
@export var attachment : PhysicsBody3D

var attachment_point : Node3D = Node3D.new()
var interaction_point : InteractionPoint

#region Attach
## Override in a child class to do stuff before attachments.
@warning_ignore("unused_parameter")
func _before_attach(target : Node3D) -> void:
	pass


## Override in a child class to do stuff during attachments.
@warning_ignore("unused_parameter")
func _attach(target : Node3D) -> void:
	pass


## Override in a child class to do stuff after attachments.
@warning_ignore("unused_parameter")
func _after_attach(target : Node3D) -> void:
	pass


func attach(target : Node3D):
	_before_attach(target)

	has_attachment = true
	attachment = target
	velocity = Vector3.ZERO
	interaction_point.disable()
	attachment.add_collision_exception_with(self)
	_attach(target)

	attached.emit(self, target)
	_after_attach(target)
#endregion


#region Dettach
## Override in a child class to do stuff before detachments.
@warning_ignore("unused_parameter")
func _before_detach(target : Node3D) -> void:
	pass


## Override in a child class to do stuff during detachments.
@warning_ignore("unused_parameter")
func _detach(target : Node3D) -> void:
	pass


## Override in a child class to do stuff after detachments.
@warning_ignore("unused_parameter")
func _after_detach(target : Node3D) -> void:
	pass


func detach():
	_before_detach(attachment)

	has_attachment = false
	interaction_point.enable()
	_detach(attachment)

	detached.emit(self, attachment)
	_after_detach(attachment)
#endregion


func be_held(delta : float) -> void:
	if attachment.has_method("hold_item"):
		attachment.hold_item(self, delta)
	else:
		track(0, attachment)


func reposition(speed : float, target_position: Vector3 = attachment.global_position):
	var offset_position := target_position - attachment_point.position
	if speed == 0:
		position = target_position
		position = offset_position
	else:
		position = position.move_toward(offset_position, speed)


func reorient(speed : float, orientation: Vector3 = Vector3(0, rotation.y, 0)):
	if speed == 0:
		rotation = orientation
		return

	var current_rotation = Quaternion.from_euler(rotation)
	var target_rotation = Quaternion.from_euler(orientation)
	rotation = current_rotation.slerp(target_rotation, speed).get_euler()


func track(speed: float, target: Node3D = attachment):
	reposition(speed, target.global_position)
	reorient(speed, target.global_rotation)


func _ready() -> void:
	var maybe_interaction = get_node_or_null("InteractionPoint")
	if maybe_interaction is InteractionPoint:
		interaction_point = maybe_interaction
	else:
		print("Creating an interaction point.")
		var default_point : PackedScene = load("res://Actors/Areas/InteractionPoint.tscn")
		interaction_point = default_point.instantiate()
		interaction_point.type = InteractionPoint.InteractionType.attachable
		add_child(interaction_point)
	var custom_attachment = get_node_or_null("AttachmentPoint")
	if custom_attachment:
		attachment_point = custom_attachment

func _physics_process(delta: float) -> void:
	if has_attachment:
		be_held(delta)
	else:
		if not is_on_floor():
			velocity += get_gravity() * delta
			velocity.x = move_toward(velocity.x, 0.0, 0.5 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 0.5 * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, 6 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 6 * delta)
			if attachment:
				attachment.remove_collision_exception_with(self)

		reorient(10 * delta)
		move_and_slide();
