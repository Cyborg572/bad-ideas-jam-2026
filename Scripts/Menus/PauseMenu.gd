extends Control

var is_paused : bool = false
@onready var animations: AnimationPlayer = $AnimationPlayer
@onready var continue_button: Button = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/VBoxContainer/ContinueButton


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


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


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
