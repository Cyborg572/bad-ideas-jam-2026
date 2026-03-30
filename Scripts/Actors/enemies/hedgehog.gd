class_name Hedgehog
extends CharacterBody3D

const SPEED = 1

enum State {
	IDLE,
	SCANNING,
	PATROLLING,
	ATTACKING,
}

var speed : float = 0
var state : State = State.IDLE

@onready var nav: NavigationAgent3D = $NavigationAgent3D
@onready var patrol_beat: Timer = $PatrolBeat
@onready var anim: AnimationTree = $AnimationTree


func _ready() -> void:
	anim.active = true
	nav.target_reached.connect(_on_target_reached)
	#nav.velocity_computed.connect(_on_velocity_computed)
	patrol_beat.timeout.connect(_on_patrol_beat)
	patrol_beat.start()


func _physics_process(delta: float) -> void:
	velocity += get_gravity() * delta

	match state:
		State.IDLE:
			_on_idle()
		State.SCANNING:
			_on_scanning(delta)
		State.PATROLLING:
			_on_patrolling(delta)
		State.ATTACKING:
			_on_attacking(delta)
		_:
			pass

	var ground_speed = Utils.get_ground_speed(velocity)
	speed = ground_speed.length()
	if ground_speed.length() > 0:
		rotation = Utils.rotate_toward_motion(rotation, ground_speed, delta * 6)

	move_and_slide()


func _on_idle():
	velocity = Vector3.ZERO


func _on_scanning(_delta: float):
	pass


func _on_patrolling(_delta: float):
	var current_position = global_position
	var next_position = nav.get_next_path_position()
	var direction = (next_position - current_position).normalized()
	var new_velocity = direction * SPEED
	#nav.velocity = new_velocity
	velocity = new_velocity


func _on_attacking(delta:float):
	velocity += Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * 10 * delta


func _on_patrol_beat() -> void:
	if state == State.SCANNING:
		#enter_state(State.ATTACKING)
		enter_state(State.PATROLLING)
	else:
		enter_state([State.SCANNING, State.PATROLLING].pick_random())


func _on_target_reached() -> void:
	enter_state(State.IDLE)


#func _on_velocity_computed(safe_velocity: Vector3) -> void:
	#velocity = safe_velocity


func get_new_target_location():
	var offset_x = randf_range(1, 2) * [-1, 1].pick_random()
	var offset_z = randf_range(1, 2) * [-1, 1].pick_random()
	var target = global_position + Vector3(offset_x, 0, offset_z)
	var nav_map = nav.get_navigation_map()
	var safe_target = NavigationServer3D.map_get_closest_point(nav_map, target)
	return safe_target


func enter_state(new_state: State) -> void:
	#var old_state: State = state
	state = new_state
	match state:
		State.IDLE:
			patrol_beat.start()
		State.SCANNING:
			patrol_beat.start()
		State.PATROLLING:
			nav.target_position = get_new_target_location()
		State.ATTACKING:
			pass
