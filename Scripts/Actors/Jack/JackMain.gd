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
var aiming : bool = false

var active_camera : CameraRig

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
	#print_debug("leaving ", State.keys()[from])
	match from:
		_:
			pass


func _enter_state(from : State, to : State) -> void:
	if from == to: return
	#print_debug("entering ", State.keys()[to])
	match to:
		State.Airborn:
			falling = false
			if (anim.current_animation != "Flip"):
				anim.play("Jump", 0.1)
		_:
			pass

#endregion


#region Utilities
func set_active_camera(camera: CameraRig):
	active_camera = camera


func get_ground_speed(vector: Vector3) -> Vector3:
	return vector * Vector3(1, 0, 1)

#endregion

#region Process helpers

func apply_movement(acceleration: Vector3, delta : float, multiplier : float = 1.0 ) -> void:
	var movement = acceleration * delta * (get_move_speed() * multiplier)
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
	#var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y))#.normalized()
	var direction := Vector3(input_dir.x, 0, input_dir.y)
	
	if active_camera:
		direction = active_camera.rotate_relative_to_view(direction)
	
	return direction

func follow_motion(direction: Vector3, rate: float) -> void:
	var look_angle = Vector2(direction.z, direction.x).angle()
	var q1 = Quaternion(Vector3.UP, look_angle)
	#var q2 = Quaternion.from_euler(model.rotation).normalized()
	#model.rotation = q2.slerp(q1, rate).get_euler()
	var q2 = Quaternion.from_euler(rotation).normalized()
	rotation = q2.slerp(q1, rate).get_euler()

func get_best_side_view(normal: Vector3) -> float:
	var ccw = normal.rotated(Vector3.UP, PI/2).normalized()
	var cw = normal.rotated(Vector3.UP, -PI/2).normalized()
	var cam_direction = Vector3.FORWARD.rotated(Vector3.UP, active_camera.rotation.y)
	
	print("ccw: ", ccw)
	print("cw: ", cw)
	print("cam: ", cam_direction)

	if ((ccw - cam_direction).length_squared() > (cw - cam_direction).length_squared()):
		print("CCW is closest ", ccw - cam_direction, ' ', cw - cam_direction)
		return Vector2(ccw.z, -ccw.x).angle()
	else:
		print("CW is closest ", ccw - cam_direction, ' ', cw - cam_direction)
		return Vector2(cw.z, -cw.x).angle()

#endregion


func _physics_process(delta: float) -> void:
	# Toggle Airborn state automatically
	if not is_on_floor():
		if state != State.Airborn:
			change_state(State.Airborn)
	elif state == State.Airborn:
		change_state(State.Grounded)

	if Input.is_action_just_pressed("camera_reset"):
		active_camera.align(rotation.y, 10)

	match state:
		State.Grounded:
			var direction := get_direction()
			apply_movement(direction, delta)

			var speed := get_ground_speed(velocity).length()
			var sharp := is_sharp_turn(velocity, direction)

			if get_max_move_speed() - speed < 0.2:
				active_camera.align(rotation.y, 1)

			if sharp:
				if can_flip == false:
					anim.play("Skid", 0.25)
				can_flip = true
			else:
				if can_flip == true:
					anim.play_backwards("Skid")

				can_flip = false

				if (direction):
					follow_motion(direction, delta * 6)

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

		State.Airborn when is_on_wall_only():
			#print("Wall! Wall!")
			var wall_normal := get_wall_normal()
			var direction := get_direction()
			var gravity := get_gravity()

			if is_falling():
				direction = direction.slide(wall_normal)
				gravity = ((wall_normal * -1) + (gravity / 10))
				follow_motion(wall_normal, 30 * delta)
			#else:
				#gravity = ((wall_normal * -1) + (gravity / 10)) * delta

			# Handle movement
			apply_movement(direction, delta)

			# Apply gravity
			velocity += gravity * delta

			# Handle jump.
			if Input.is_action_just_pressed("Jump"):
				active_camera.align(get_best_side_view(wall_normal), 5)
				velocity = (get_jump_strength() * Vector3.UP) + (wall_normal * 2)
				follow_motion(wall_normal, 60 * delta)

		State.Airborn:
			# Apply gravity
			velocity += get_gravity() * delta

			var direction = get_direction()
			apply_movement(direction, delta, 1.5 if anim.current_animation == "Flip" else 1.0)
			
			if !falling && is_falling():
				falling = true
				anim.play("Fall", 1)
				anim.queue("Falling")

		State.Crouched:
			print("Crouching")

		State.Armed when aiming:
			print("Aiming!")

		State.Armed:
			print("Armed!")


	

	move_and_slide()
