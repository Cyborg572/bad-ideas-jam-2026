class_name DeathZone
extends Area3D

func _ready() -> void:
	body_entered.connect(kill_player)

func kill_player(body: Node3D) -> void:
	if body is Jack:
		GameManager.player_out_of_bounds()
	elif body is TheBox:
		GameManager.box_out_of_bounds()
