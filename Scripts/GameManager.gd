extends Node

signal change_camera(camera: CameraRig)
signal interaction(interaction_point : InteractionPoint)
signal player_health_changed(current: int, max: int)
signal player_health_depleted
signal player_confidence_lost
signal player_confidence_changed(confidence: float)
signal distance_to_box_changed(distance: float)

var main_camera : CameraRig = null:
	set(camera):
		if (main_camera == camera): return
		main_camera = camera
		change_camera.emit(main_camera)

var jack : Jack = null

var interaction_points : Array[InteractionPoint] = []
var active_interaction_point : InteractionPoint

@export var level_spawn_point := Vector3.ZERO

@export var player_max_health : int = 5:
	set(new_max_health):
		player_max_health = new_max_health
		player_health_changed.emit(player_health, player_max_health)

@export var player_health : int = 5:
	set(new_health):
		player_health = clamp(new_health, 0, player_max_health)
		player_health_changed.emit(player_health, player_max_health)

		if player_health <= 0:
			player_health_depleted.emit()


@export var player_base_confidence : float = 50.0
@export var player_confidence : float = 50.0:
	set(new_confidence):
		player_confidence = clamp(new_confidence, 0.0, 100.0)
		player_confidence_changed.emit(player_confidence)

		if player_confidence <= 0:
			player_confidence_lost.emit()


@export var distance_to_box : float = 0.0:
	set(new_distance):
		distance_to_box = new_distance
		distance_to_box_changed.emit(distance_to_box)


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


func reset_confidence(keep_extra: bool = true) -> void:
	if player_confidence < player_base_confidence or not keep_extra:
		player_confidence = player_base_confidence


func kill_player() -> void:
	jack.velocity = Vector3.ZERO
	jack.box.velocity = Vector3.ZERO
	jack.box.position = level_spawn_point
	jack.popToBox()


func player_out_of_bounds() -> void:
	jack.velocity = Vector3.ZERO
	if jack.box.is_on_floor():
		reset_confidence(false)
		jack.popToBox()
	elif jack.is_boxed:
		jack.position = jack.box.last_ground_position
		player_health -= 1
	else:
		jack.box.position = jack.box.last_ground_position
		jack.position = jack.box.last_ground_position
		jack.popToBox()
		player_health -= 1


func box_out_of_bounds() -> void:
	jack.box.position = jack.box.last_ground_position
	jack.box.velocity = Vector3.ZERO
	if not jack.is_boxed:
		player_health -= 1
		player_out_of_bounds()
