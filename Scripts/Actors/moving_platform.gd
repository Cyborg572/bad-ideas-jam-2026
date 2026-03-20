class_name MovingPlatform
extends PathFollow3D

## Modified PathFollow3D node to allow setting up rules for timing and motion


@export_range(0.0, 5.0, 0.1, "or_greater", "hide_control", "suffix:m/s")
var speed : float = 0.5

var platform_position : RemoteTransform3D = RemoteTransform3D.new()
var platform : AnimatableBody3D


func _ready() -> void:
	add_child(platform_position)
	setup_platform.call_deferred()



func _process(delta: float) -> void:
	progress += speed * delta


func setup_platform() -> void:
	var path_parent = get_parent().get_parent()
	print("Path parent: ", path_parent)

	# Move the child platform out of the path?
	var children : Array[Node] = get_children()
	for child in children:
		if child is AnimatableBody3D:
			platform = child
			platform.reparent.call_deferred(path_parent)
			platform_position.remote_path = platform_position.get_path_to(platform)
			break
