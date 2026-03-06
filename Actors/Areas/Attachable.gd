class_name Attachable
extends CharacterBody3D

signal attached(attachable: Attachable, target : Node3D)
signal detached(attachable: Attachable, target : Node3D)

@export var has_attachment : bool = false
@export var attachment : Node3D

var attachment_point : Node3D = Node3D.new()

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
	_detach(attachment)

	detached.emit(self, attachment)
	_after_detach(attachment)
#endregion


func _ready() -> void:
	var custom_attachment = get_node_or_null("AttachmentPoint")
	print("Using custom attach ", self, " ", custom_attachment)
	if custom_attachment:
		attachment_point = custom_attachment

func _physics_process(_delta: float) -> void:
	if has_attachment:
		print("Following ", attachment)
		self.global_position = attachment.global_position - attachment_point.position
		self.global_rotation = attachment.global_rotation - attachment_point.rotation
