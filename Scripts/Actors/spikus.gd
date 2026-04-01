class_name Spikus
extends CharacterBody3D

const SPEED = 3
const ATTACK_SPEED = 12

enum State {
	IDLE,
	SCANNING,
	ATTACKING,
}

var speed : float = 0
var state : State = State.IDLE
var min_attack_distance: float = 14
var target_position: Vector3

@onready var patrol_beat: Timer = $PatrolBeat
@onready var anim: AnimationTree = $AnimationTree
@onready var hit_box: Area3D = $HitBox
@onready var model: Node3D = $Armature
@onready var spawn_point: Vector3 = global_position


func _ready() -> void:
	anim.active = true
	#nav.velocity_computed.connect(_on_velocity_computed)
	patrol_beat.timeout.connect(_on_patrol_beat)
	patrol_beat.start()
	hit_box.body_shape_entered.connect(_on_hitbox_entered)


func _physics_process(delta: float) -> void:
	if GameManager.dialog_active:
		return

	velocity += get_gravity() * delta

	match state:
		State.IDLE:
			_on_idle(delta)
		State.SCANNING:
			_on_scanning(delta)
		State.ATTACKING:
			_on_attacking(delta)
		_:
			pass

	var ground_speed = Utils.get_ground_speed(velocity)
	speed = ground_speed.length()
	if speed > 0:
		rotation = Utils.rotate_toward_motion(rotation, ground_speed, delta * 30)
		var playback: AnimationNodeStateMachinePlayback = anim.get("parameters/StateMachine/playback")
		playback.set("parameters/StateMachine/roll/speed/scale", speed)
		playback.set("parameters/StateMachine/walk/speed/scale", speed)


	move_and_slide()


func _on_idle(delta: float):
	if is_on_floor():
		velocity = velocity.move_toward(Vector3.ZERO, 3 * delta)


func _on_scanning(_delta: float):
	pass


func _on_attacking(delta:float):
	# Wait for the ball
	var playback: AnimationNodeStateMachinePlayback = anim.get("parameters/StateMachine/playback")
	var current_animation: StringName = playback.get_current_node()
	#if current_animation != "curled" and current_animation != "roll":
		#return

	if is_on_wall():
		print("stuck on wall")
		velocity = velocity.bounce(get_wall_normal()) + (Vector3.UP * 3)
		enter_state(State.IDLE)
		return

	var straight_line = (target_position - global_position).normalized()
	var new_velocity = straight_line * ATTACK_SPEED * delta
	if speed > 3 and Utils.is_sharp_turn(new_velocity, velocity):
		enter_state(State.IDLE)
	velocity += new_velocity



func _on_patrol_beat() -> void:
	print("Shoudl change now")
	if state == State.SCANNING:
		patrol_beat.stop()
		enter_state(State.ATTACKING)
	else:
		enter_state(State.SCANNING)


func _on_target_reached() -> void:
	match state:
		State.ATTACKING:
			enter_state(State.SCANNING)
		_:
			enter_state(State.IDLE)


#func _on_velocity_computed(safe_velocity: Vector3) -> void:
	#velocity = safe_velocity


func _on_hitbox_entered(_body_rid: RID, body: Node3D, body_shape_index: int, _local_shape_index: int) -> void:

	if body is Jack:
		var jack = body as Jack

		var collision_shape = jack.shape_owner_get_owner(jack.shape_find_owner(body_shape_index))

		match collision_shape:
			jack.body_collider:
				if jack.is_boxed:
					GameManager.hurt_player()
					var jack_direction = jack.global_position - global_position
					print(jack_direction)
					jack.velocity += jack_direction.normalized() * 4
					return

				GameManager.hurt_player()
				jack.popToBox()
				return


func get_target_location_opposing_jack() -> Vector3:
	var jack: Jack = GameManager.jack
	var to_jack = (jack.global_position - global_position)
	var away_from_jack = to_jack.normalized() * Vector3(-1, 0, -1) * min_attack_distance
	var target = global_position + away_from_jack
	return target

func get_target_nearest_jack() -> Vector3:
	var jack: Jack = GameManager.jack
	var target = jack.global_position
	return target

func get_new_target_location() -> Vector3:
	var offset_x = randf_range(1, 2) * [-1, 1].pick_random()
	var offset_z = randf_range(1, 2) * [-1, 1].pick_random()
	var target = global_position + Vector3(offset_x, 0, offset_z)
	return target


func enter_state(new_state: State) -> void:
	#var old_state: State = state
	print("New state ", State.keys()[new_state])
	state = new_state
	match state:
		State.IDLE:
			patrol_beat.start()
		State.SCANNING:
			print("restarting timer")
			patrol_beat.start()
		State.ATTACKING:
			target_position = get_target_nearest_jack()
