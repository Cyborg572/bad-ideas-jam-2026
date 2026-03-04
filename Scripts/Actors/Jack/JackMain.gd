class_name Jack
extends CharacterBody3D

enum Attachment { Free, Boxed, Carry }
enum State { Grounded, Airborn, Crouched, Aiming, Armed }

@export var state_config : Dictionary[State, JackStateConfiguration]

@onready var model := $Model
@onready var indicator := $InteractionIndicator
@onready var camera_target := $CameraTarget
@onready var anim: AnimationPlayer = $AnimationPlayer

var state : State = State.Grounded
var attachment : Attachment = Attachment.Free
var can_flip : bool = false
var falling : bool = false
var wallslide : bool = false
var aiming : bool = false

var active_camera : Camera3D

func _ready() -> void:
	set_active_camera(GameManager.main_camera)
	GameManager.change_camera.connect(set_active_camera)


#region State value accessors
func get_move_speed() -> float:
	return state_config[state].get_move_speed(attachment)


func get_friction() -> float:
	return state_config[state].get_friction(attachment)


func get_jump_strength() -> float:
	return state_config[state].get_jump_strength(attachment)


func get_max_move_speed() -> float:
	return state_config[state].get_max_move_speed(attachment)


func get_max_speed() -> float:
	return state_config[state].get_max_speed(attachment)
#endregion

#region State management
func change_state(to : State) -> void:
	var from : State = state
	_leave_state(from, to)
	state = to
	_enter_state(from, to)


func _leave_state(from : State, to : State) -> void:
	if from == to: return
	print_debug("leaving ", State.keys()[from])
	match from:
		_:
			pass


func _enter_state(from : State, to : State) -> void:
	if from == to: return
	print_debug("entering ", State.keys()[to])
	match to:
		_:
			pass

#endregion


#region Utilities
func set_active_camera(camera):
	active_camera = camera


func get_ground_speed(vector: Vector3) -> Vector3:
	return vector * Vector3(1, 0, 1)

#endregion

#region Process helpers

func apply_movement(acceleration: Vector3, delta) -> void:
	var movement = acceleration * delta * get_move_speed()
	var ground_speed := get_ground_speed(velocity)
	var vertical_speed : Vector3 = velocity * Vector3.UP
	var max_move_speed : float = get_max_move_speed()
	var max_speed : float = get_max_speed()
	var current_speed : float = ground_speed.length()
	var friction : float = get_friction()
	
	var direction : Vector3 = movement.normalized()
	
	if current_speed < max_move_speed:
		ground_speed += movement
	else:
		ground_speed += movement.slide(ground_speed.normalized())

	ground_speed = ground_speed.move_toward(direction * ground_speed.length(), friction * delta)
	ground_speed.limit_length(max_speed)
	
	velocity = ground_speed + vertical_speed


func is_sharp_turn(direction : Vector3, current_speed : Vector3) -> bool:
	var dot = current_speed.normalized().dot(direction.normalized())
	return dot < 0

func is_falling() -> bool:
	return velocity.y < 0

func is_freefall() -> bool:
	return !is_on_floor() && !is_on_wall() && velocity.y < 0


func get_direction() -> Vector3:
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("Left", "Right", "Forward", "Back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y))#.normalized()
	
	if active_camera:
		direction = direction.rotated(Vector3.UP, active_camera.global_rotation.y)
	
	return direction

func follow_motion(direction: Vector3, rate: float) -> void:
	var look_angle = Vector2(direction.z, direction.x).angle()
	var q1 = Quaternion(Vector3.UP, look_angle)
	var q2 = Quaternion.from_euler(model.rotation).normalized()
	model.rotation = q2.slerp(q1, rate).get_euler()
#endregion


func _physics_process(delta: float) -> void:
	# Toggle Airborn state automatically
	if not is_on_floor():
		if state != State.Airborn:
			change_state(State.Airborn)
	elif state == State.Airborn:
		change_state(State.Grounded)

	match state:
		State.Grounded:
			#print("Grounded. ", is_on_floor())

			var direction = get_direction()
			apply_movement(direction, delta)

			var speed := get_ground_speed(velocity).length()
			var sharp := is_sharp_turn(velocity, direction)
			if sharp:
				if can_flip == false:
					anim.play("Skid", 0.25)
				can_flip = true
				# follow_motion(direction, delta * 20)
			else:
				if can_flip == true:
					anim.play_backwards("Skid")

				can_flip = false

				if (direction):
					follow_motion(direction, delta * 3)

				if speed > get_max_move_speed() / 2:
					anim.play("Run", 0.5)
				elif speed > 0:
					anim.play("Walk", 0.5)
				else:
					anim.play("Idle", 0.5)

			# Handle jump.
			if Input.is_action_just_pressed("Jump"):
				if (can_flip):
					anim.play("Flip")
					velocity = Vector3.UP * (get_jump_strength() * 1.5)
				else:
					velocity.y = get_jump_strength()

		State.Airborn when is_on_wall_only() && is_falling():
			print("Wall! Wall!")

			# Apply gravity
			velocity += (get_gravity() / 2) * delta

			# Handle jump.
			if Input.is_action_just_pressed("Jump"):
				wallslide = false
				velocity = (get_jump_strength() * Vector3.UP) + (get_wall_normal() * 2)

		State.Airborn:
			print("Airborn")

			# Apply gravity
			velocity += get_gravity() * delta

			var direction = get_direction()
			apply_movement(direction, delta)


		State.Crouched:
			print("Crouching")

		State.Armed when aiming:
			print("Aiming!")

		State.Aiming:
			print("Armed!")


	

	move_and_slide()
