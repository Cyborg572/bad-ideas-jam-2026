class_name DeathZone
extends Area3D

func _ready() -> void:
	body_entered.connect(kill_player)

func kill_player(body: Node3D) -> void:
	print(body)
	if body is Jack:
		GameManager.kill_player()
	elif body is TheBox:
		print("the box came through here")
		GameManager.kill_the_box()
	else:
		print("unkown objects passing through")
