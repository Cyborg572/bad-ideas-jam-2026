class_name MovingPlatform
extends PathFollow3D
## Modified PathFollow3D node to allow setting up rules for timing and motion

## Set the "wait for player" behaviour
enum TripType {
	## The platform will always move along it's path
	AUTO,

	## The platform waits for the player at either end of the path.
	ROUND_TRIP,

	## The platform waits for the player at the start, but returns automatically
	ONE_WAY,

	## The platform only moves when occupied, but otherwise behavious like AUTO
	TRANSIT,

	## The platform moves forwards when occupied, backwards when empty, and
	## reverses immediately (or after delay)
	RATCHET,
}


@export var trip_type: TripType = TripType.AUTO


## How quickly does the platform move along the path
@export_range(0.0, 5.0, 0.1, "or_greater", "hide_control", "suffix:m/s")
var speed : float = 1

## How long to wait at each end of the path before moving.[br]
## For one-way trips, this starts when the player steps off the platform[br]
## For round trips, this acts as a buffer if the player quickly steps off and
## back on.
@export_range(0.1, 5.0, 0.1, "or_greater", "suffix:s") var delay : float = 1.0


## Another trigger to use instead of the platform's built-in triggers
@export var external_trigger: Node3D

var platform_position : RemoteTransform3D = RemoteTransform3D.new()
var platform : Platform
var moving : bool = false
var reverse : bool = false
var delay_timer := Timer.new()


func _ready() -> void:
	add_child(platform_position)
	setup_platform.call_deferred()
	delay_timer.wait_time = delay
	delay_timer.one_shot = true
	delay_timer.timeout.connect(_on_delay_timer_timeout)
	add_child(delay_timer)

	if external_trigger and external_trigger.has_signal(&"triggered"):
		external_trigger.triggered.connect(_on_external_trigger_triggered)
		external_trigger.untriggered.connect(_on_external_trigger_untriggered)

	if trip_type == TripType.AUTO:
		moving = true


func _process(delta: float) -> void:
	if not loop and at_either_end_of_path(true):
			reverse = !reverse
			moving = false

			if should_move_automatically():
				delay_timer.start()

	if moving:
		progress += delta * (speed if not reverse else -speed)


func is_active() -> bool:
	if external_trigger and "is_triggered" in external_trigger:
		return external_trigger.is_triggered

	if platform:
		return platform.has_passenger()

	return false


func setup_platform() -> void:
	var path_parent = get_parent().get_parent()

	# Move the child platform out of the path?
	var children : Array[Node] = get_children()
	for child in children:
		if child is Platform:
			platform = child
			platform.reparent.call_deferred(path_parent)
			platform_position.remote_path = platform_position.get_path_to(platform)
			if not external_trigger:
				platform.boarded.connect(_on_platform_boarded)
				platform.vacated.connect(_on_platform_vacated)
			break


func should_move_automatically() -> bool:
	match trip_type:
		TripType.AUTO:
			return true
		TripType.ROUND_TRIP when is_active():
			return true
		TripType.ONE_WAY when at_path_terminus() and not is_active():
			return true
		TripType.ONE_WAY when at_path_start() and is_active():
			return true
		TripType.TRANSIT when is_active():
			return true
		TripType.RATCHET when at_path_terminus() and not is_active():
			return true
		_:
			return false


func at_path_start() -> bool:
	return progress_ratio <= 0


func at_path_terminus() -> bool:
	return progress_ratio >= 1


func at_either_end_of_path(consider_direction: bool = false) -> bool:
	if not consider_direction:
		return at_path_start() or at_path_terminus()

	return (
		(at_path_start() and reverse)
		or (at_path_terminus() and not reverse)
	)


func _on_platform_boarded(_by: Node3D, _is_trigger: bool) -> void:
	start_trip()


func _on_external_trigger_triggered(_by: Node3D) -> void:
	start_trip()


func _on_platform_vacated() -> void:
	end_trip()


func _on_external_trigger_untriggered() -> void:
	end_trip()


func _on_delay_timer_timeout() -> void:
	moving = true


func start_trip() -> void:
	match trip_type:
		TripType.AUTO:
			pass
		TripType.ROUND_TRIP when not moving:
			delay_timer.start()
		TripType.ONE_WAY when at_path_start():
			delay_timer.start()
		TripType.TRANSIT when not moving:
			delay_timer.start()
		TripType.RATCHET:
			moving = false
			reverse = false
			delay_timer.start()
		_:
			pass



func end_trip() -> void:
	match trip_type:
		TripType.AUTO:
			pass
		TripType.ROUND_TRIP when not moving:
			delay_timer.stop()
		TripType.ONE_WAY when at_path_start():
			delay_timer.stop()
		TripType.ONE_WAY when at_path_terminus():
			delay_timer.start()
		TripType.TRANSIT:
			delay_timer.stop()
			moving = false
		TripType.RATCHET when not at_path_start():
			moving = false
			reverse = true
			delay_timer.start()
		TripType.RATCHET when at_path_start():
			delay_timer.stop()
		_:
			pass
