extends Node

signal change_camera(camera)

var main_camera : Camera3D = null:
	set(camera):
		if (main_camera == camera): return
		main_camera = camera
		change_camera.emit(main_camera)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
