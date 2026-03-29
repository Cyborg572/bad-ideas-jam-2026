class_name TheBox
extends Attachable

signal stopped_in_pop()
signal cranking_started()
signal cranking_stopped(was_pop: bool)
signal settled

@export var launch_force : float = 6
@export var cranking_song : AudioStream
@export_subgroup("Cranking Pop Window", "cranking_pop_window_")

## The number of seconds into the cranking tune where the "Pop" starts
@export_range(0, 5, 0.1, "or_greater", "hide_control", "suffix:s")
var cranking_pop_window_start :  float = 3.8

## The number of seconds into the cranking tune where the "Pop" ends
@export_range(0, 5, 0.1, "or_greater", "hide_control", "suffix:s")
var cranking_pop_window_end : float = 4.2

@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var crank_audio: AudioStreamPlayer3D = $CrankAudio
@onready var pop_sound: AudioStreamPlayer3D = $PopSound
@onready var collisions_enabled : bool = true
@onready var closed_collider: CollisionShape3D = $ClosedCollider
@onready var open_collider: CollisionShape3D = $OpenCollider
@onready var top_point: RayCast3D = $TopPoint
@onready var floor_detect: RayCast3D = $FloorDetect
@onready var model: Node3D = $Model
@onready var crank: Node3D = $Model/Crank

var is_open : bool = false
var is_cranking : bool = false
var inventory : Array[Attachable] = []
var is_settled = false

# Tracking last safe location
var last_ground_position := Vector3.ZERO
var last_ground_speed := Vector3.ZERO


func _ready() -> void:
	super()
	set_collision_layer_value(1, true)
	crank_audio.stream = cranking_song
	crank_audio.finished.connect(_on_song_finished)
	anim.animation_finished.connect(_on_anim_complete)


func _process(delta: float) -> void:
	if is_cranking:
		crank.rotation.x += PI/2 * delta
		crank.rotation.x = wrapf(crank.rotation.x, 0, 2 * PI)


func pop() -> void:
	await open(true)


func toggle_open(fast : bool = false) -> void:
	if is_open:
		await close(fast)
	else:
		await open(fast)


func open(fast : bool = false) -> void:
	if is_open: return

	if top_point.is_colliding() and is_on_floor():
		var launchable = top_point.get_collider()
		if launchable is CharacterBody3D:
			launch(launchable)
			fast = true

	is_open = true
	switch_collider()
	if fast:
		pop_sound.play()
		anim.play("Pop")
	else:
		anim.play("Open")
	await anim.animation_finished

func close(fast : bool = false) -> void:
	if not is_open: return

	is_open = false
	switch_collider()
	if fast:
		anim.speed_scale = 10
	anim.play_backwards("Open")
	await  anim.animation_finished


func slam() -> void:
	await close(true)


func start_music() -> void:
	if crank_audio.stream_paused:
		crank_audio.stream_paused = false
	else:
		crank_audio.play()


func stop_music() -> bool:
	var is_pop_window : bool = false
	var stopped_position : float = crank_audio.get_playback_position()

	if (
		stopped_position >= cranking_pop_window_start
		&& stopped_position <= cranking_pop_window_end
	):
		is_pop_window = true

	if not is_pop_window:
		crank_audio.stream_paused = true
	else:
		stopped_in_pop.emit()

	return is_pop_window

func start_cranking() -> void:
	is_cranking = true
	cranking_started.emit()
	start_music()


func stop_cranking() -> bool:
	is_cranking = false
	var was_pop = stop_music()
	cranking_stopped.emit(was_pop)
	return was_pop


func launch(item: Node3D):
	var launch_direction = Vector3.UP + Vector3.MODEL_REAR.rotated(Vector3.UP, rotation.y)
	if item.has_method("get_launched"):
		item.get_launched(launch_direction, launch_force)
	else:
		item.velocity = launch_direction * launch_force


## If collisions are enabled, set the appropriate collider (open vs. closed).
func switch_collider() -> void:
	if collisions_enabled: enable_collisions()


func enable_collisions() -> void:
	collisions_enabled = true
	if is_open:
		open_collider.disabled = false
		closed_collider.disabled = true
	else:
		open_collider.disabled = true
		closed_collider.disabled = false


func disable_collisions() -> void:
	collisions_enabled = false
	open_collider.disabled = true
	closed_collider.disabled = true


func would_recieve_item(_item: Attachable) -> bool:
	return has_attachment or is_open


func recieve_item(item: Attachable) -> bool:
	if item is Gem:
		item.claim()
		return true

	inventory.push_back(item)
	item.get_parent().remove_child(item)
	return true


func give_item(to : CharacterBody3D) -> void:
	var item = inventory.pop_back()
	if item.can_attach(to):
		get_parent().add_child(item)
		item.give_to(to)
	else:
		inventory.push_back(item)


func get_offered_item() -> Attachable:
	return inventory.back()


func hold_item(item: Attachable, delta) -> void:
	if item in inventory:
		item.track(10 * delta, self, 0.2)


func is_floor_solid() -> bool:
	if floor_detect.is_colliding():
		var floor_type = floor_detect.get_collider()
		return Utils.is_solid_ground(floor_type)
	return false


func is_floor_safe() -> bool:
	if floor_detect.is_colliding():
		var floor_type = floor_detect.get_collider()
		return not floor_type is SpikedPlatform
	return false


func _physics_process(delta: float) -> void:
	super(delta)

	if is_on_floor():
		if is_floor_solid():
			last_ground_position = floor_detect.get_collision_point()
	elif (
		has_attachment
		and attachment is Jack
		and (attachment as Jack).is_on_floor()
	):
		if attachment.is_carrying and attachment.carried_item == self and attachment.is_floor_solid():
			last_ground_position = attachment.position
		elif is_floor_solid():
			last_ground_position = floor_detect.get_collision_point()


	if velocity.length() > 0 or not is_on_floor():
		is_settled = false
	elif not is_settled:
		is_settled = true
		settled.emit()

func _attach(_target : Node3D) -> void:
	disable_collisions()


func _detach(_target : Node3D) -> void:
	stop_cranking()
	enable_collisions()


func get_interaction_type(point: InteractionPoint) -> InteractionPoint.InteractionType:
	if point != interaction_point: return InteractionPoint.InteractionType.custom
	var jack : Jack = GameManager.jack

	match is_open:
		true when jack.is_carrying != inventory.is_empty():
			return InteractionPoint.InteractionType.sign
		true when jack.is_carrying:
			return InteractionPoint.InteractionType.carrier
		true:
			return InteractionPoint.InteractionType.dispenser
		_:
			return InteractionPoint.InteractionType.attachable


func _on_anim_complete(_animation: String):
	anim.speed_scale = 1

func _on_song_finished() -> void:
	if is_cranking:
		crank_audio.play()


func get_safe_return_point() -> Vector3:
		var nav_map = get_world_3d().navigation_map
		var safe_target = NavigationServer3D.map_get_closest_point(nav_map, last_ground_position)
		var ground_offset := Vector3(0, 0.125, 0)
		if (safe_target - last_ground_position).length() < 2:
			safe_target.y = last_ground_position.y + ground_offset.y
		else:
			safe_target = last_ground_position + ground_offset
		return safe_target
