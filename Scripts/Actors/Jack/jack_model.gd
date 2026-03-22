class_name JackModel
extends Node3D

@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var hand_attachment: Node3D = $Armature/Skeleton3D/Hand/Attachment
@onready var foot_attachment: Node3D = $Armature/Skeleton3D/Foot/Attachment

@export var parent : Jack = null

func _ready() -> void:
	if not parent == null:
		var jack_path = animation_tree.get_path_to(parent)
		animation_tree.advance_expression_base_node = jack_path
