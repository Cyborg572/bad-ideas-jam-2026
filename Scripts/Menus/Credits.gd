extends Control

@onready var player: AnimationPlayer = $AnimationPlayer
@onready var main_menu_button: Button = $ScrollContainer/VBoxContainer/PanelContainer/MarginContainer/HBoxContainer/MainMenuButton


func _ready() -> void:
	player.play("scroll_credits")
	await player.animation_finished
	main_menu_button.grab_focus.call_deferred()


func _on_main_menu_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Menus/MainMenu.tscn")


func _on_quit_button_pressed() -> void:
	get_tree().quit()
