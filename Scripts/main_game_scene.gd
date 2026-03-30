class_name MainScene
extends Control


signal level_loading
signal level_loaded(level_scene: Level)
signal fade_out_finished
signal fade_in_finished


@export_file("*.world.tscn") var starting_level : String = "uid://dord8un54pu4n"
@export var starting_level_gate: int = 0

var active_level : Level = null
var level_path : String
var level_gate_id: int
var is_loading : bool = false
var is_hiding_game : bool = false

@onready var screen_cover: PanelContainer = %ScreenCover
@onready var loading_text: RichTextLabel = %Loading
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var sub_viewport: SubViewport = %SubViewport
@onready var secret_chime: AudioStreamPlayer = $SecretChime
@onready var background_music_player: AudioStreamPlayer = $BackgroundMusicPlayer
@onready var dialog_viewer: DialogViewer = %DialogViewer
@onready var hint_viewer: HintViewer = %HintViewer

func _ready() -> void:
	GameManager.main_scene = self
	GameManager.bg_music_player = $BackgroundMusicPlayer
	GameManager.dialog_viewer = dialog_viewer
	GameManager.hint_viewer = hint_viewer
	GameManager.level_changed.connect(load_level)
	GameManager.secret_discovered.connect(_on_secret_discovered)
	GameManager.goal_achieved.connect(_on_goal_achieved)

	# Allow a level to be pre-set in the editor
	if sub_viewport.get_child_count() > 0:
		active_level = sub_viewport.get_child(0)
		anim.play_backwards("fade_out")

	if active_level == null:
		var current_level_path = GameManager.game_state.get_scene_file_path()
		if current_level_path != "":
			load_level(current_level_path, GameManager.game_state.get_active_gate_id())
		else:
			load_level(starting_level, starting_level_gate)


func _process(_delta: float) -> void:
	if is_loading:
		check_load_status()


func _on_secret_discovered(_secret_name: String) -> void:
	print("Ther's a new secret!")
	secret_chime.play()


func _on_goal_achieved() -> void:
	secret_chime.play()


func load_level(requested_level_path: String, gate_id: int = 0):
	if background_music_player.has_stream_playback():
		var music: AudioStreamPlayback = background_music_player.get_stream_playback()
		if music is AudioStreamPlaybackInteractive:
			music.switch_to_clip_by_name("silence")

	fade_out()

	if not loading_text.visible:
		anim.play("start_loading")
		await anim.animation_finished


	is_loading = true
	level_loading.emit()

	if not active_level == null:
		unload_current_level()

	level_path = requested_level_path
	level_gate_id = gate_id
	ResourceLoader.load_threaded_request(level_path)


func check_load_status() -> void:
	var progress: Array = []
	var status = ResourceLoader.load_threaded_get_status(level_path, progress)

	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			pass
		ResourceLoader.THREAD_LOAD_LOADED:
			is_loading = false
			finish_loading_level()
		ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("NOT A LEVEL: \"%s\"" % level_path)
			get_tree().quit(1)
		_, ResourceLoader.THREAD_LOAD_FAILED:
			push_error("Couldn't load level: \"%s\"" % level_path)
			get_tree().quit(1)


func unload_current_level() -> void:
	sub_viewport.remove_child(active_level)


func finish_loading_level() -> void:
	var packed_level = ResourceLoader.load_threaded_get(level_path)

	GameManager.game_state.set_scene_file_path(level_path)
	GameManager.game_state.set_active_gate_id(level_gate_id)

	if not packed_level is PackedScene:
		push_error("Error: \"%s\" is not a scene" % level_path)
		get_tree().quit()
	packed_level = packed_level as PackedScene
	active_level = packed_level.instantiate()

	sub_viewport.add_child(active_level)
	background_music_player.stream = active_level.background_music
	background_music_player.play()
	anim.play_backwards("start_loading")
	await anim.animation_finished
	level_loaded.emit(active_level)


func fade_out() -> void:
	if not screen_cover.visible:
		get_tree().paused = true
		anim.play("fade_out")
		await anim.animation_finished
		get_tree().paused = false
		fade_out_finished.emit()
	else:
		fade_out_finished.emit()


func fade_in() -> void:
	if screen_cover.visible:
		anim.play_backwards("fade_out")
		await anim.animation_finished
		fade_in_finished.emit()
	else:
		fade_in_finished.emit()
