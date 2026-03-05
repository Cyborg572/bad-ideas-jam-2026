extends Node

signal change_camera(camera: CameraRig)

var main_camera : CameraRig = null:
	set(camera):
		if (main_camera == camera): return
		main_camera = camera
		change_camera.emit(main_camera)
