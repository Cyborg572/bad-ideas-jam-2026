class_name TheBox
extends Attachable

@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var collisions_enabled : bool = true
@onready var closed_collider: CollisionShape3D = $ClosedCollider
@onready var open_collider: CollisionShape3D = $OpenCollider

var is_open : bool = false

func _ready() -> void:
	super()
	anim.animation_finished.connect(_on_anim_complete)


func pop() -> void:
	open(true)


func toggle_open(fast : bool = false) -> void:
	if is_open:
		close(fast)
	else:
		open(fast)


func open(fast : bool = false) -> void:
	if is_open: return

	is_open = true
	switch_collider()
	if fast:
		anim.play("Pop")
	else:
		anim.play("Open")

func close(fast : bool = false) -> void:
	if not is_open: return
	
	is_open = false
	switch_collider()
	if fast:
		anim.speed_scale = 10
	anim.play_backwards("Open")


func slam() -> void:
	close(true)


## If collisions are enabled, set the appropriate collider (open vs. closed).
func switch_collider() -> void:
	if collisions_enabled: enable_collisions()


func enable_collisions() -> void:
	collisions_enabled = true
	if is_open:
		open_collider.disabled = false
		closed_collider.disabled = true
	else:
		open_collider.disabled = true
		closed_collider.disabled = false


func disable_collisions() -> void:
	collisions_enabled = false
	open_collider.disabled = true
	closed_collider.disabled = true


func _attach(_target : Node3D) -> void:
	disable_collisions()


func _detach(_target : Node3D) -> void:
	enable_collisions()


func _on_interaction_point_interaction(point: InteractionPoint) -> void:
	if point != interaction_point: return

	point.type = InteractionPoint.InteractionType.attachable


func _on_anim_complete(_animation: String):
	anim.speed_scale = 1
