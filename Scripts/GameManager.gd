extends Node

signal change_camera(camera: CameraRig)
signal interaction(interaction_point : InteractionPoint)

var main_camera : CameraRig = null:
	set(camera):
		if (main_camera == camera): return
		main_camera = camera
		change_camera.emit(main_camera)

var jack : Jack = null

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


func trigger_interaction() -> void:
	if active_interaction_point:
		# First the interaction point gets to react.
		active_interaction_point.interact()

		# Then everything else.
		interaction.emit(active_interaction_point)


func kill_player() -> void:
	if jack.is_boxed:
		print("Figure this out!")
		jack.position = Vector3(0, 20, 0)
	else:
		jack.velocity = Vector3.ZERO
		jack.popToBox()


func kill_the_box() -> void:
	print("Figure this out too!")
	jack.box.position = Vector3(0, 20, 0)
	kill_player()
