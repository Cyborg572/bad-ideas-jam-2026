extends Node

@onready var weasel_2: Weasle = $"../weasel2"
@onready var gem_plinth_1: GemPlinth = $"../gem_plinth1"

func _on_death_zone_body_entered(body: Node3D) -> void:
	if body is Spikus:
		GameManager.achieve_goal()
		gem_plinth_1.unlock()
		weasel_2.chat()
