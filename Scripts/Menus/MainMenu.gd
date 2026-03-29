extends Control

@export var start_button: Button
@export var continue_button: Button
@export var main_scene: PackedScene
@export var credits_scene: PackedScene


@onready var jack: JackModel = $HBoxContainer/SubViewportContainer/SubViewport/Node3D/Jack
@onready var the_box: TheBox = $HBoxContainer/SubViewportContainer/SubViewport/Node3D/TheBox

func _ready() -> void:
	if GameManager.game_state.has_saved_game():
		continue_button.disabled = false
		continue_button.grab_focus.call_deferred()
	else:
		continue_button.disabled = true
		start_button.grab_focus.call_deferred()
	jack.animation_tree.process_mode = Node.PROCESS_MODE_DISABLED
	jack.anim.play("SideFlip")
	jack.anim.seek(0.38, true)
	jack.anim.pause()
	the_box.anim.play("Open")
	the_box.anim.seek(0.5, true)
	the_box.anim.pause()
	the_box.start_cranking()


func _on_start_button_pressed() -> void:
	GameManager.game_state.creat_blank_player_state()
	get_tree().change_scene_to_packed(main_scene)


func _on_options_button_pressed() -> void:
	pass # Replace with function body.


func _on_credits_button_pressed() -> void:
	get_tree().change_scene_to_packed(credits_scene)


func _on_quit_button_pressed() -> void:
	get_tree().quit()


func _on_continue_button_pressed() -> void:
	GameManager.game_state.load_game()
	get_tree().change_scene_to_packed(main_scene)
