class_name TheBox
extends Attachable

signal stopped_in_pop()

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
@onready var collisions_enabled : bool = true
@onready var closed_collider: CollisionShape3D = $ClosedCollider
@onready var open_collider: CollisionShape3D = $OpenCollider
@onready var top_point: RayCast3D = $TopPoint
@onready var model: Node3D = $Model
@onready var crank: Node3D = $Model/Crank

var is_open : bool = false
var is_cranking : bool = false
var inventory : Array[Attachable] = []


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
	open(true)


func toggle_open(fast : bool = false) -> void:
	if is_open:
		close(fast)
	else:
		open(fast)


func open(fast : bool = false) -> void:
	if is_open: return

	if top_point.is_colliding():
		var launchable = top_point.get_collider()
		if launchable is CharacterBody3D:
			launch(launchable)
			fast = true

	is_open = true
	switch_collider()
	if fast:
		anim.play("Pop")
	else:
		anim.play("Open")

func close(fast : bool = false) -> void:
	if not is_open: return

	is_open = false
	switch_collider()
	if fast:
		anim.speed_scale = 10
	anim.play_backwards("Open")


func slam() -> void:
	close(true)


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
		print("Stopped at: ", crank_audio.get_playback_position())
		crank_audio.stream_paused = true
	else:
		print("POP!")
		stopped_in_pop.emit()

	return is_pop_window

func start_cranking() -> void:
	is_cranking = true
	print("Start crankin'")
	start_music()


func stop_cranking() -> bool:
	is_cranking = false
	return stop_music()


func launch(item: Node3D):
	var launch_direction = Vector3.UP + Vector3.MODEL_REAR.rotated(Vector3.UP, rotation.y)
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
	pass
	#collisions_enabled = false
	#open_collider.disabled = true
	#closed_collider.disabled = true


func would_recieve_item(_item: Attachable) -> bool:
	return is_open


func recieve_item(item: Attachable) -> bool:
	print("Recieving ", item)
	if is_open:
		item.attach(self)
		inventory.push_back(item)
		return true
	else:
		return false


func give_item(to : CharacterBody3D) -> void:
	var item = inventory.pop_back()
	print("Giving ", item)
	if item.can_attach(to):
		print("Passing to ", to)
		item.detach()
		item.give_to(to)
	else:
		print("Jack didn't want it")


func get_offered_item() -> Attachable:
	return inventory.back()


func hold_item(item: Attachable, delta) -> void:
	if item in inventory:
		item.track(10 * delta, self, 0.2)


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


func _on_interaction_point_interaction(point: InteractionPoint) -> void:
	var jack : Jack = GameManager.jack
	if point.type != InteractionPoint.InteractionType.custom:
		print(jack.is_carrying, inventory.is_empty())
		return

	if jack.is_carrying || inventory.is_empty():
		return

	give_item(jack)


func _on_anim_complete(_animation: String):
	anim.speed_scale = 1

func _on_song_finished() -> void:
	print("It finished!")
	if is_cranking:
		crank_audio.play()
