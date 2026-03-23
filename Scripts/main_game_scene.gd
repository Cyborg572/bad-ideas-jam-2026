extends Control


signal level_loading
signal level_loaded
signal fade_out_finished
signal fade_in_finished


@export_file("*.world.tscn")
var starting_level : String = "uid://dord8un54pu4n"

var active_level : Node = null
var level_path : String
var is_loading : bool = false

@onready var screen_cover: PanelContainer = %ScreenCover
@onready var loading_text: RichTextLabel = %Loading
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var sub_viewport: SubViewport = %SubViewport

func _ready() -> void:
	GameManager.bg_music_player = $BackgroundMusicPlayer
	GameManager.level_changed.connect(load_level)
	GameManager.fade_in_requested.connect(fade_in)
	GameManager.fade_in_signal = fade_in_finished
	GameManager.fade_out_signal = fade_out_finished
	GameManager.fade_out_requested.connect(fade_out)

	# Allow a level to be pre-set in the editor
	if sub_viewport.get_child_count() > 0:
		active_level = sub_viewport.get_child(0)
		anim.play_backwards("fade_out")

	if active_level == null:
		load_level(starting_level)


func _process(_delta: float) -> void:
	if is_loading:
		check_load_status()


func load_level(requested_level_path: String):
	if not screen_cover.visible:
		await anim.animation_finished

	if not loading_text.visible:
		await anim.animation_finished


	is_loading = true
	level_loading.emit()

	if not active_level == null:
		unload_current_level()

	level_path = requested_level_path
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
	print("Do something with the old level?")
	sub_viewport.remove_child(active_level)
	print("Old level is gone...")


func finish_loading_level() -> void:
	var packed_level = ResourceLoader.load_threaded_get(level_path)
	if not packed_level is PackedScene:
		push_error("Error: \"%s\" is not a scene" % level_path)
		get_tree().quit()
	packed_level = packed_level as PackedScene
	active_level = packed_level.instantiate()
	sub_viewport.add_child(active_level)
	anim.play("finish_loading")
	await anim.animation_finished
	level_loaded.emit()


func fade_out() -> void:
	anim.play("fade_out")
	await anim.animation_finished
	fade_out_finished.emit()


func fade_in() -> void:
	anim.play_backwards("fade_out")
	await anim.animation_finished
	fade_in_finished.emit()
