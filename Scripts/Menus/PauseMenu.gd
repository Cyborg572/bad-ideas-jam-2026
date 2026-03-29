extends Control

@onready var animations: AnimationPlayer = $AnimationPlayer
@onready var continue_button: Button = %ContinueButton

@onready var level_title: Label = %LevelTitle
@onready var berry_counter: Label = %BerryCounter
@onready var record_counter: Label = %RecordCounter
@onready var gem_counter: Label = %GemCounter

var is_paused : bool = false
var gems: Dictionary[Gem.GemID, TextureRect] = {}
var gem_shards: Dictionary[GemShard.ShardId, TextureRect] = {}
var active_level: Level


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	gems[Gem.GemID.GEM_1] = %Gem1
	gems[Gem.GemID.GEM_2] = %Gem2
	gems[Gem.GemID.GEM_3] = %Gem3

	gem_shards[GemShard.ShardId.SHARD_1] = %shard1
	gem_shards[GemShard.ShardId.SHARD_2] = %shard2
	gem_shards[GemShard.ShardId.SHARD_3] = %shard3
	gem_shards[GemShard.ShardId.SHARD_4] = %shard4
	gem_shards[GemShard.ShardId.SHARD_5] = %shard5
	gem_shards[GemShard.ShardId.SHARD_6] = %shard6
	gem_shards[GemShard.ShardId.SHARD_7] = %shard7
	gem_shards[GemShard.ShardId.SHARD_8] = %shard8


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("Pause"):
		toggle_paused()


func _on_continue_button_pressed() -> void:
	resume()


func _on_options_button_pressed() -> void:
	pass # Replace with function body.


func _on_main_menu_button_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Menus/MainMenu.tscn")


func _on_quit_button_pressed() -> void:
	get_tree().quit()


func _on_save_button_pressed() -> void:
	GameManager.game_state.save_game()


func _on_main_level_loaded(level_scene: Level) -> void:
	active_level = level_scene
	update_status_display()


func update_status_display():
	var state: PlayerState.LevelData = active_level.level_state
	level_title.text = active_level.get_title()

	for gem in Gem.GemID.values():
		if gem == Gem.GemID.NONE:
			continue
		gems[gem].visible = state.is_gem_collected(gem)


	for gem_shard in GemShard.ShardId.values():
		if gem_shard == GemShard.ShardId.NONE:
			continue
		gem_shards[gem_shard].visible = state.is_gem_shard_collected(gem_shard)

	var collected_berries = active_level.collected_mullberries
	var total_berries = state.get_mullberry_total()
	berry_counter.text = "%d/%d" % [collected_berries, total_berries]
	record_counter.text = "%d/%d" % [state.get_mullberry_record(), total_berries]
	gem_counter.text = "%d" % GameManager.game_state.player_state.total_gems


func pause() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = true
	is_paused = true
	animations.play_backwards("HideMenu")
	await animations.animation_finished
	continue_button.grab_focus.call_deferred()


func resume() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	is_paused = false
	animations.play("HideMenu")
	get_tree().paused = false


func toggle_paused() -> void:
	if is_paused:
		resume()
	else:
		pause()
