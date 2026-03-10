class_name TheBox
extends Attachable

@export var launch_force : float = 6

@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var collisions_enabled : bool = true
@onready var closed_collider: CollisionShape3D = $ClosedCollider
@onready var open_collider: CollisionShape3D = $OpenCollider
@onready var top_point: RayCast3D = $TopPoint

var is_open : bool = false
var inventory : Array[Attachable] = []

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

	if top_point.is_colliding():
		var launchable = top_point.get_collider()
		if launchable is CharacterBody3D:
			launch(launchable)
			fast = true

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


func launch(item: Node3D):
	var launch_direction = Vector3.UP + Vector3.MODEL_REAR.rotated(Vector3.UP, rotation.y)
	item.velocity = launch_direction * launch_force


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
	pass
	#collisions_enabled = false
	#open_collider.disabled = true
	#closed_collider.disabled = true


func would_recieve_item(_item: Attachable) -> bool:
	return is_open


func recieve_item(item: Attachable) -> bool:
	print("Recieving ", item)
	if is_open:
		item.attach(self)
		inventory.push_back(item)
		return true
	else:
		return false


func give_item(to : CharacterBody3D) -> void:
	var item = inventory.pop_back()
	print("Giving ", item)
	if item.can_attach(to):
		print("Passing to ", to)
		item.detach()
		item.give_to(to)
	else:
		print("Jack didn't want it")


func get_offered_item() -> Attachable:
	return inventory.back()


func hold_item(item: Attachable, delta) -> void:
	if item in inventory:
		item.track(10 * delta, self, 0.2)


func _attach(_target : Node3D) -> void:
	disable_collisions()


func _detach(_target : Node3D) -> void:
	enable_collisions()


func get_interaction_type(point: InteractionPoint) -> InteractionPoint.InteractionType:
	if point != interaction_point: return InteractionPoint.InteractionType.custom
	var jack : Jack = GameManager.jack
	
	match is_open:
		true when jack.is_carrying != inventory.is_empty():
			return InteractionPoint.InteractionType.sign
		true when jack.is_carrying:
			return InteractionPoint.InteractionType.carrier
		true:
			return InteractionPoint.InteractionType.dispenser
		_:
			return InteractionPoint.InteractionType.attachable


func _on_interaction_point_interaction(point: InteractionPoint) -> void:
	var jack : Jack = GameManager.jack
	if point.type != InteractionPoint.InteractionType.custom:
		print(jack.is_carrying, inventory.is_empty())
		return
	
	if jack.is_carrying || inventory.is_empty():
		return

	give_item(jack)


func _on_anim_complete(_animation: String):
	anim.speed_scale = 1
