class_name TheBox
extends Attachable

@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var interaction_point: InteractionPoint = $InteractionPoint

var is_open : bool = false

func _ready() -> void:
	super()
	anim.animation_finished.connect(_on_anim_complete)


func pop() -> void:
	if is_open: return

	is_open = true
	anim.play("Pop")

func open() -> void:
	if is_open: return

	is_open = true
	anim.play("Open")

func close() -> void:
	if not is_open: return
	
	is_open = false
	anim.play_backwards("Open")


func slam() -> void:
	if not is_open: return

	is_open = false
	anim.speed_scale = 2
	anim.play_backwards("Open")

func _attach(_target : Node3D) -> void:
	interaction_point.disable()
	$CollisionShape3D.disabled = true


func _detach(_target : Node3D) -> void:
	interaction_point.enable()
	$CollisionShape3D.disabled = false


func _on_interaction_point_interaction(_interaction_point: InteractionPoint) -> void:
	close()


func _on_anim_complete(_animation: String):
	anim.speed_scale = 1
