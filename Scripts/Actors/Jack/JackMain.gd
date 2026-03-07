class_name Jack
extends CharacterBody3D

signal popped(box: TheBox)

enum Attachment { Free, Boxed }
enum State { Grounded, Airborn, Crouched, Aiming, Armed }

@export var state_config : Dictionary[State, JackStateConfiguration]
@export var is_carrying : bool = false
@export var carried_item : Attachable
@export var attachment : Attachment = Attachment.Free
@export var box : TheBox

@onready var model := $Model
@onready var indicator := $InteractionIndicator
@onready var camera_target := $CameraTarget
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var ledge_hook: RayCast3D = $LedgeHook
@onready var wall_detect: RayCast3D = $WallDetect
@onready var box_collider: CollisionShape3D = $BoxCollider
@onready var pop_timer: Timer = $Timers/PopTimer
@onready var pop_button_timer: Timer = $Timers/PopButtonTimer

var state : State = State.Grounded
var attachment_points : Dictionary[String, Node3D] = {}

var can_flip : bool = false
var falling : bool = false
var throwing : bool = false
var aiming : bool = false
var hanging : bool = false
var hanging_cooldown : float = 0.0

var active_camera : CameraRig
var distance_to_box : float = 0

func _ready() -> void:
	set_active_camera(GameManager.main_camera)
	GameManager.change_camera.connect(set_active_camera)
	GameManager.interaction.connect(_on_global_interaction)
	attachment_points['head'] = $AttachmentPoints/Head
	attachment_points['hand'] = $AttachmentPoints/Hand
	attachment_points['foot'] = $AttachmentPoints/Foot
	attachment_points['throw'] = $AttachmentPoints/Throw
	pop_timer.timeout.connect(popToBox)
	pop_button_timer.timeout.connect(popToBox)


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

#region Attachment management
func change_attachment(to : Attachment) -> void:
	var from : Attachment = attachment
	_leave_attachment(from, to)
	attachment = to
	_enter_attachment(from, to)


func _leave_attachment(from : Attachment, to : Attachment) -> void:
	if from == to: return
	#print_debug("leaving attachment ", State.keys()[from])
	match from:
		Attachment.Free:
			#add_collision_exception_with(box)
			box_collider.disabled = false
		_:
			pass


func _enter_attachment(from : Attachment, to : Attachment) -> void:
	if from == to: return
	#print_debug("entering attachment", State.keys()[to])
	match to:
		Attachment.Free:
			#remove_collision_exception_with(box)
			box_collider.position = model.position
			box_collider.disabled = true
			box.slam()
		Attachment.Boxed:
			box_collider.position = attachment_points['foot'].position - box.attachment_point.position
			#box.pop()
		_:
			pass
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
			hanging = false
			hanging_cooldown = 0.0
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


func get_angle_to_box() -> float:
	var box_direction = (box.position - position).normalized()
	var look_angle = Vector2(box_direction.z, box_direction.x).angle()
	return look_angle
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
	elif max_move_speed > 0:
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
	var input_dir := Input.get_vector("Left", "Right", "Forward", "Back")
	var direction := Vector3(input_dir.x, 0, input_dir.y)
	
	if active_camera:
		direction = active_camera.rotate_relative_to_view(direction)

	return direction

func follow_motion(direction: Vector3, rate: float) -> void:
	var look_angle = Vector2(direction.z, direction.x).angle()
	var q1 = Quaternion(Vector3.UP, look_angle)
	var q2 = Quaternion.from_euler(rotation).normalized()
	rotation = q2.slerp(q1, rate).get_euler()
	ledge_hook.rotation.y = -rotation.y
	wall_detect.rotation.y = -rotation.y

func get_best_side_view(normal: Vector3) -> float:
	var ccw = normal.rotated(Vector3.UP, PI/2).normalized()
	var cw = normal.rotated(Vector3.UP, -PI/2).normalized()
	var cam_direction = Vector3.FORWARD.rotated(Vector3.UP, active_camera.rotation.y)

	if ((ccw - cam_direction).length_squared() > (cw - cam_direction).length_squared()):
		return Vector2(-ccw.z, -ccw.x).angle()
	else:
		return Vector2(-cw.z, -cw.x).angle()

#endregion

func popToBox() -> void:
	position = box.position
	box.attach(self)
	change_attachment(Attachment.Boxed)
	visible = false
	model.scale.y = 0.1
	active_camera.start_chase()
	await active_camera.chase_ended
	box.pop()
	visible = true
	model.scale.y = 1
	popped.emit(box)


func hold_item(item : Attachable, delta) -> void:
	match item:
		carried_item when is_carrying:
			print("Holding ", item)
			item.track(10 * delta, attachment_points['hand'])
		box:
			print("Doing the box, actually.")
			item.reposition(0, attachment_points['foot'].global_position)
			item.reorient(0)
		_:
			pass

func drop_carried_item() -> void:
	if not is_carrying: return
	is_carrying = false
	carried_item.reposition(0, attachment_points['throw'].global_position)
	carried_item.velocity = Vector3.MODEL_FRONT.rotated(Vector3.UP, rotation.y).normalized() * 2
	carried_item.detach()

func _physics_process(delta: float) -> void:
	var direction = get_direction()
	distance_to_box = (box.position - position).length()
	#print("distance from box: ", (position - box.position).length())
	# Toggle Airborn state automatically
	if not is_on_floor():
		if state != State.Airborn:
			change_state(State.Airborn)
	elif state == State.Airborn:
		change_state(State.Grounded)

	# Count off cooldowns
	hanging_cooldown -= delta

	if Input.is_action_just_pressed("camera_reset"):
		active_camera.align(rotation.y, 10)

	if Input.is_action_just_pressed("Interact"):
		if GameManager.active_interaction_point: return
		drop_carried_item()
		#if not is_carrying: return
		#is_carrying = false
		#carried_item.detach()

	if Input.is_action_just_pressed("Pop"):
		print("Distance: ", distance_to_box)
		match attachment:
			Attachment.Boxed:
				box.detach()
				change_attachment(Attachment.Free)
				velocity.y = get_jump_strength()
			Attachment.Free when is_carrying && carried_item == box:
				is_carrying = false
				velocity.y = get_jump_strength()
				popToBox()
			Attachment.Free when box:
				if distance_to_box < 1:
					box.toggle_open()
				else:
					box.close()
				if not box.is_open:
					pop_button_timer.start()
			_:
				print("No pop!")

	if Input.is_action_just_released("Pop"):
		if pop_button_timer.time_left > pop_button_timer.wait_time / 3 && distance_to_box > 3:
			active_camera.align(get_angle_to_box(), 10)
		if not pop_button_timer.is_stopped():
			pop_button_timer.stop()

	match state:
		State.Grounded:
			apply_movement(direction, delta)

			var speed := get_ground_speed(velocity).length()
			var sharp := is_sharp_turn(velocity, direction)

			if get_max_move_speed() - speed < 0.2:
				active_camera.align(rotation.y, 1, true)

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

		State.Airborn when hanging:
			var wall_normal : Vector3

			if is_on_wall():
				wall_normal = get_wall_normal()
				ledge_hook.target_position = wall_normal * -0.3
				wall_detect.target_position = wall_normal * 2
			else:
				# If the wall's gone, we can work out what the normal was
				wall_normal = ledge_hook.target_position.normalized() * -1

			var back_to_wall := wall_detect.is_colliding()
			var wall_dot := direction.normalized().dot(wall_normal)
			var best_side_view = rotation.y if not back_to_wall else get_best_side_view(wall_normal);

			if direction:
				# Explicit check here, because the else is "rotation" no "rotation.y"
				if back_to_wall:
					active_camera.align(best_side_view, 3, true)
				else:
					active_camera.align(rotation, 3, true)
			else:
				active_camera.cancel_align()

			# Left the ledge or hit crouch
			if !ledge_hook.is_colliding() || Input.is_action_just_pressed("Crouch"):
				active_camera.align(best_side_view, 10)
				hanging_cooldown = 1
				hanging = false

			# Handle jump.
			elif Input.is_action_just_pressed("Jump"):
				active_camera.align(best_side_view, 10)
				hanging = false
				if wall_dot > 0.8:
					velocity = (get_jump_strength() * Vector3.UP) + (wall_normal * 2)
					follow_motion(wall_normal, 60 * delta)
				else:
					velocity = (get_jump_strength() * Vector3.UP) + (wall_normal * -0.5)

			# Move along ledge
			else:
				direction = direction.slide(wall_normal)
				var gravity := wall_normal * -1
				follow_motion(wall_normal * -1, 60 * delta)
				velocity = direction + (gravity * delta)
				velocity.y = 0

		State.Airborn when is_on_wall_only():
			var wall_normal := get_wall_normal()
			var gravity := get_gravity()

			# Ledge Logic
			ledge_hook.target_position = wall_normal * -0.3
			wall_detect.target_position = wall_normal * -0.5

			if (
				hanging_cooldown <= 0
				&& ledge_hook.is_colliding()
				&& not wall_detect.is_colliding()
			):
				hanging = true
				hanging_cooldown = 1
				velocity = Vector3.ZERO

			if is_falling() && wall_detect.is_colliding():
				direction = direction.slide(wall_normal)
				gravity = ((wall_normal * -1) + (gravity / 10))
				follow_motion(wall_normal, 30 * delta)

			# Handle movement
			apply_movement(direction, delta)

			# Apply gravity
			velocity += gravity * delta

			# Handle jump.
			if Input.is_action_just_pressed("Jump"):
				active_camera.align(get_best_side_view(wall_normal), 10)
				velocity = (get_jump_strength() * Vector3.UP) + (wall_normal * 2)
				follow_motion(wall_normal, 60 * delta)

		State.Airborn:
			# Apply gravity
			velocity += get_gravity() * delta

			# Ledge Logic
			var ledge_direction := Vector3.MODEL_FRONT.rotated(Vector3.UP, rotation.y).normalized()
			ledge_hook.target_position = ledge_direction * 0.3
			wall_detect.target_position = ledge_direction * 0.5

			if (
				hanging_cooldown <= 0
				&& is_falling()
				&& ledge_hook.is_colliding()
				&& not wall_detect.is_colliding()
			):
				hanging = true
				hanging_cooldown = 1
				velocity = Vector3.ZERO

			if is_falling() && wall_detect.is_colliding():
				velocity += ledge_direction * 0.5

			var flipping = anim.current_animation == "Flip"

			apply_movement(direction, delta, 1.5 if flipping else 1.0)
			if flipping:
				follow_motion(direction, 6 * delta)
			
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


func _on_global_interaction(interaction_point : InteractionPoint):
	var types := InteractionPoint.InteractionType
	match interaction_point.type:
		types.attachable:
			carried_item = interaction_point.get_parent_node_3d()
			carried_item.attach(self)
			is_carrying = true
			print("Carrying ", box)
			if carried_item == box:
				carried_item.close()
		_:
			print("New interaction. Type: ", types.keys()[interaction_point.type])
