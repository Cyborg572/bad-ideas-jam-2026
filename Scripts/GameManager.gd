extends Node

signal change_camera(camera: CameraRig)
signal interaction(interaction_point : InteractionPoint)

var main_camera : CameraRig = null:
	set(camera):
		if (main_camera == camera): return
		main_camera = camera
		change_camera.emit(main_camera)

var interaction_points : Array[InteractionPoint] = []
var active_interaction_point : InteractionPoint


func set_active_interaction_point(point : InteractionPoint) -> void:
	if active_interaction_point == point:
		return

	# Prevent duplicate elements from building up in the array.
	interaction_points.erase(point)

	# Go right to the queue if the current interaction point is "sticky"
	if active_interaction_point:
		if active_interaction_point.sticky:
			interaction_points.push_back(point)
			return

		# Move the existing active point into the queue
		active_interaction_point.deactivate()
		interaction_points.push_back(active_interaction_point)

	# Turn on the new point
	active_interaction_point = point
	active_interaction_point.activate()


func clear_active_interaction_point(point : InteractionPoint) -> void:
	if active_interaction_point == point:
		point.deactivate()
		active_interaction_point = interaction_points.pop_back()
		if active_interaction_point:
			active_interaction_point.activate()
	else:
		interaction_points.erase(point)


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("Interact"):
		if active_interaction_point:
			active_interaction_point.interact()
			interaction.emit(active_interaction_point)
