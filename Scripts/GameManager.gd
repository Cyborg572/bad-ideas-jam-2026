extends Node

signal interaction(interaction_point : InteractionPoint)
signal player_health_changed(current: int, max: int)
signal player_damaged
signal player_health_depleted
signal player_confidence_lost
signal player_rewarded(amount: float)
signal player_confidence_changed(old_confidence: float, new_confidence: float)
signal distance_to_box_changed(distance: float)
signal level_changed(new_level: String, gate_id: int)
signal secret_discovered(secret_name: String)
signal goal_achieved


@export var jack_scene: PackedScene = preload("uid://wkiytlqj20xh")
@export var the_box_scene: PackedScene = preload("uid://cu1llcu6fuf5h")
@export var camera_scene: PackedScene = preload("uid://duykwhism24sd")

# The current game state
var game_state = PlayerState.new()

# Things managed by the main world scene
var active_level: Level = null
var fade_in_signal: Signal
var fade_out_signal: Signal
var bg_music_player: AudioStreamPlayer = null
var main_scene: MainScene = null:
	set(value):
		main_scene = value
		main_scene.level_loaded.connect(_on_level_loaded)

# The player et all
var jack : Jack = null
var the_box : TheBox = null
var main_camera : CameraRig = null

var interaction_points : Array[InteractionPoint] = []
var active_interaction_point : InteractionPoint

var current_recovery_point := Vector3.ZERO
var current_recovery_rotation := Vector3.ZERO

var discovered_secrets: Array[String] = []

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
			kill_player.call_deferred()


@export var player_base_confidence : float = 50.0
@export var player_confidence : float = 50.0:
	set(new_confidence):
		var old_confidence: float = player_confidence
		player_confidence = clamp(new_confidence, 0.0, 100.0)
		player_confidence_changed.emit(player_confidence, old_confidence)

		if player_confidence <= 0:
			player_confidence_lost.emit()


@export var distance_to_box : float = 0.0:
	set(new_distance):
		distance_to_box = new_distance
		distance_to_box_changed.emit(distance_to_box)

#region Volume variables!
@onready var audio_bus_master: int = AudioServer.get_bus_index("Master")
@onready var audio_master_volume: float = AudioServer.get_bus_volume_linear(audio_bus_master)

@onready var audio_bus_ambiance: int = AudioServer.get_bus_index("Ambiance")
@onready var audio_ambiance_volume: float = AudioServer.get_bus_volume_linear(audio_bus_ambiance)

@onready var audio_bus_music: int = AudioServer.get_bus_index("Music")
@onready var audio_music_volume: float = AudioServer.get_bus_volume_linear(audio_bus_music)

@onready var audio_bus_effects: int = AudioServer.get_bus_index("Sound Effects")
@onready var audio_effects_volume: float = AudioServer.get_bus_volume_linear(audio_bus_effects)

@onready var audio_bus_dialog: int = AudioServer.get_bus_index("Dialog")
@onready var audio_dialog_volume: float = AudioServer.get_bus_volume_linear(audio_bus_dialog)
#endregion


func _on_jack_boxed() -> void:
	# Make the music more confident
	if bg_music_player:
		var stream = bg_music_player.get_stream_playback()
		if stream is AudioStreamPlaybackInteractive:
			stream.switch_to_clip_by_name("boxed")
	main_camera.set_shot_type(CameraRig.Shot.Normal)


func _on_jack_unboxed() -> void:
	# Make the music less confident
	if bg_music_player:
		var stream = bg_music_player.get_stream_playback()
		if stream is AudioStreamPlaybackInteractive:
			stream.switch_to_clip_by_name("unboxed")
	main_camera.set_shot_type(CameraRig.Shot.Wide)


func _on_crank_started() -> void:
	AudioServer.set_bus_volume_linear(audio_bus_music, audio_music_volume / 5)

func _on_crank_stopped(was_pop: bool) -> void:
	if was_pop:
		await jack.box.crank_audio.finished

	AudioServer.set_bus_volume_linear(audio_bus_music, audio_music_volume)


func _on_level_loaded(level_scene: Node3D) -> void:
	active_level = level_scene
	if jack == null:
		create_jack()
	spawn_jack()


#region Interaction Points
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
#endregion

func reset_confidence(keep_extra: bool = true) -> void:
	if player_confidence < player_base_confidence or not keep_extra:
		player_confidence = player_base_confidence


func spawn_jack():
	active_level.add_child(jack)
	active_level.add_child(the_box)
	active_level.add_child(main_camera)

	# Set the cranking music
	the_box.cranking_song = main_scene.active_level.cranking_sound

	# Position everything
	var spawn_point = active_level.get_active_spawn_point()
	the_box.position = spawn_point.global_position
	the_box.rotation = spawn_point.global_rotation
	the_box.velocity = Vector3.ZERO
	jack.velocity = Vector3.ZERO
	jack.position = the_box.position
	jack.rotation = the_box.rotation
	main_camera.position = spawn_point.global_position
	main_camera.rotation.y = jack.rotation.y + PI
	main_camera.skip_camera_travel()

	# Bit of fun for gate entrances
	if the_box.has_attachment:
		the_box.detach()
	else:
		the_box.add_collision_exception_with(jack)
	jack.hide_in_box()
	main_camera.target = the_box
	if spawn_point is LevelExit:
		spawn_point.open(true)
		main_camera.rotation.y += PI - PI/4
		the_box.position.y += 1
		the_box.velocity = Vector3.MODEL_FRONT.rotated(Vector3.UP, the_box.rotation.y) * 3
		the_box.rotation.x = -PI/4
		the_box.rotation.z = -PI/2
	else:
		#main_camera.rotation.y += PI - PI/4
		the_box.position.y += 1
		the_box.velocity = Vector3.UP * 3
		the_box.rotation.x = -PI
		the_box.rotation.z = PI/3

	show_game()

	await the_box.settled
	jack.position = the_box.position

	# TODO: Only close locked gates
	if spawn_point is LevelExit:
		spawn_point.close()

	# Start!
	jack.is_frozen = false
	main_camera.target = jack
	jack.popToBox()
	main_camera.align(jack.rotation.y, 5)


func despawn_jack():
	jack.is_frozen = true
	active_level.remove_child(main_camera)
	active_level.remove_child(jack)
	active_level.remove_child(the_box)


func create_jack() -> void:
	# Set up the box
	the_box = the_box_scene.instantiate()
	the_box.cranking_started.connect(_on_crank_started)
	the_box.cranking_stopped.connect(_on_crank_stopped)

	# Set up Jack
	jack = jack_scene.instantiate()
	jack.is_frozen = true
	jack.start_with_box = true
	jack.box = the_box
	jack.boxed.connect(_on_jack_boxed)
	jack.unboxed.connect(_on_jack_unboxed)

	# Set up the main camera
	main_camera = camera_scene.instantiate()
	main_camera.is_main_camera = true
	main_camera.target = jack



func destroy_jack() -> void:
	if jack:
		if jack.boxed.is_connected(_on_jack_boxed):
			jack.boxed.disconnect(_on_jack_boxed)
		if jack.unboxed.is_connected(_on_jack_unboxed):
			jack.unboxed.disconnect(_on_jack_unboxed)
		if jack.box:
			if jack.box.cranking_started.is_connected(_on_crank_started):
				jack.box.cranking_started.disconnect(_on_crank_started)
			if jack.box.cranking_stopped.is_connected(_on_crank_stopped):
				jack.box.cranking_stopped.disconnect(_on_crank_stopped)


## Give the player some confidence for a job well done
func reward_player(amount: float = 5) -> void:
	if amount > 0:
		player_confidence += amount
		player_rewarded.emit(amount)


func hurt_player(damage: int = 1) -> void:
	player_health -= damage
	if player_health > 0:
		player_damaged.emit()


func kill_player() -> void:
	jack.is_frozen = true
	main_camera.is_frozen = true
	await hide_game()
	var spawn_point = active_level.get_active_spawn_point()
	jack.velocity = Vector3.ZERO
	the_box.position = spawn_point.global_position + Vector3(0, 0.125, 0)
	the_box.position.y += 0.125
	if spawn_point is LevelExit:
		the_box.position += Vector3.MODEL_FRONT.rotated(Vector3.UP, spawn_point.rotation.y)
	the_box.rotation = spawn_point.global_rotation
	the_box.velocity = Vector3.ZERO
	player_health = player_max_health
	jack.popToBox(true)


func player_out_of_bounds() -> void:
	jack.velocity = Vector3.ZERO
	jack.reset_jump_stats()
	main_camera.is_frozen = true
	jack.sound_effects.play_falling_sound()
	await jack.sound_effects.falling_sounds.finished
	if jack.box.is_on_floor():
		reset_confidence(false)
		jack.popToBox(true)
	elif jack.is_boxed:
		var safe_point = jack.box.get_safe_return_point()
		jack.position = safe_point + jack.box.attachment_point.position
		the_box.position = safe_point
		jack.popToBox(true)
		player_health -= 1
	else:
		var safe_point = jack.box.get_safe_return_point()
		jack.box.position = safe_point + jack.box.attachment_point.position
		jack.position = safe_point
		jack.popToBox(true)
		player_health -= 1


func box_out_of_bounds() -> void:
	jack.is_frozen = true
	main_camera.align(jack.get_angle_to_box(), 10)
	jack.sound_effects.play_box_loss_sound()
	await jack.sound_effects.box_loss_sounds.finished
	await hide_game()
	jack.box.position = jack.box.get_safe_return_point()
	jack.box.velocity = Vector3.ZERO
	jack.velocity = Vector3.ZERO
	player_health -= 1
	reset_confidence(false)
	jack.popToBox(true)


func claim_secret(secret_name: String) -> void:
	if active_level.level_state.is_secret_discovered(secret_name):
		print("That secret's claimed alread")
		return

	print("new secret: %s" % secret_name)
	active_level.level_state.discover_secret(secret_name)
	secret_discovered.emit(secret_name)


func achieve_goal() -> void:
	goal_achieved.emit()


func change_level(new_level: String, gate_id: int = 0) -> void:
	jack.is_frozen = true
	await main_scene.fade_out()
	despawn_jack()
	level_changed.emit(new_level, gate_id)


func hide_game() -> void:
	await main_scene.fade_out()


func show_game() -> void:
	await main_scene.fade_in()
