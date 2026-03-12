class_name Jack
extends CharacterBody3D

signal popped(box: TheBox)

enum Attachment { Free, Boxed }
enum State { Grounded, Airborn, Crouched, Aiming, Armed }
enum JumpType {
	## Not a Jump
	None,
	## Jump from the ground, no box, no fancyness
	Normal,
	## Jump from the ground, attached to the box, but out of it
	Spring,
	## Jump from the ground while hiding in the box
	Hop,
	## Jump during sudden change in direction
	SideFlip,
	## Jump from sliding during a crouch
	Long,
	## Jump from crouch
	BackFlip,
	## Kick off a wall
	Wall,
	## Onto a ledge from hanging
	LedgeTowards,
	## Like a wall kick, but from hanging
	LedgeAway,
	## Stretch and launch with the box, from hanging
	LedgeLaunch,
	## Shot out of the box, or other launcher
	Launch,
	## Detached from the box
	PopOut,
	## The little boost from entering the box while carrying it
	PopIn
}

@export var state_config : Dictionary[State, JackStateConfiguration]
@export var is_carrying : bool = false
@export var carried_item : Attachable
@export var starting_attachment : Attachment = Attachment.Free
@export var box : TheBox
@export var boxed_jump_power: Curve

@onready var model := $Model
@onready var other_model: Node3D = $Model/Jack
@onready var indicator := $InteractionIndicator
@onready var camera_target := $CameraTarget
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var ledge_hook: RayCast3D = $LedgeHook
@onready var wall_detect: RayCast3D = $WallDetect
@onready var body_collider: CollisionShape3D = $BodyCollider
@onready var box_collider: CollisionShape3D = $BoxCollider
@onready var pop_timer: Timer = $Timers/PopTimer
@onready var pop_button_timer: Timer = $Timers/PopButtonTimer

var state : State = State.Grounded
var attachment : Attachment = Attachment.Free
var attachment_points : Dictionary[String, Node3D] = {}

var can_flip : bool = false
var falling : bool = false
var throwing : bool = false
var aiming : bool = false
var hanging : bool = false
var hanging_cooldown : float = 0.0
var jump_charge: float = 1.0
var jump_charge_rate : float = 5
var jump_type : JumpType = JumpType.None
var jump_cancelled : bool = false

var active_camera : CameraRig
var distance_to_box : float = 0

func _ready() -> void:
	GameManager.jack = self
	set_active_camera(GameManager.main_camera)
	GameManager.change_camera.connect(set_active_camera)
	GameManager.interaction.connect(_on_global_interaction)
	attachment_points['head'] = $AttachmentPoints/Head
	attachment_points['hand'] = $AttachmentPoints/Hand
	attachment_points['foot'] = $AttachmentPoints/Foot
	attachment_points['throw'] = $AttachmentPoints/Throw
	pop_timer.timeout.connect(popToBox)
	pop_button_timer.timeout.connect(popToBox)
	if starting_attachment == Attachment.Boxed:
		popToBox.call_deferred()


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
			active_camera.arm.spring_length = 3
		Attachment.Boxed:
			active_camera.arm.spring_length = 1.5
			velocity += box.velocity
			box.attach(self)
			box_collider.position = attachment_points['foot'].position - box.attachment_point.position
			if not box.inventory.is_empty() && would_recieve_item(box.get_offered_item()):
				box.give_item(self)
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
		State.Crouched:
			other_model.visible = true
			body_collider.disabled = false
			if attachment == Attachment.Boxed:
				box.pop()
			else:
				other_model.scale.y = 1
		_:
			pass


func _enter_state(from : State, to : State) -> void:
	if from == to: return
	#print_debug("entering ", State.keys()[to])
	match to:
		State.Grounded:
			jump_type = JumpType.None
			jump_cancelled = false
			if not Input.is_action_pressed("Jump"):
				finish_charge_jump()
			if is_standing_on_box() && box.is_open:
				change_attachment(Attachment.Boxed)

		State.Airborn:
			falling = false
			hanging = false
			hanging_cooldown = 0.0
			if (anim.current_animation != "Free/Flip"):
				anim.play("Free/Jump", 0.1)

		State.Crouched:
			if attachment == Attachment.Boxed:
				other_model.visible = false
				body_collider.disabled = true
				box.slam()
			else:
				other_model.scale.y = .25
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
		var heading = ground_speed.normalized()
		ground_speed += movement.slide(heading) - (heading * friction * delta)

	ground_speed = ground_speed.move_toward(direction * ground_speed.length(), friction * delta)
	ground_speed = ground_speed.limit_length(max_speed)
	
	velocity = ground_speed + vertical_speed


func cap_speed() -> void:
	var ground_speed := get_ground_speed(velocity)
	var vertical_speed : Vector3 = velocity * Vector3.UP
	ground_speed = ground_speed.limit_length(get_max_speed())
	velocity = ground_speed + vertical_speed


func is_sharp_turn(direction : Vector3, current_speed : Vector3) -> bool:
	var dot = current_speed.normalized().dot(direction.normalized())
	return dot < 0

func is_falling() -> bool:
	return velocity.y < 0

func is_freefall() -> bool:
	return !is_on_floor() && !is_on_wall() && velocity.y < 0


func is_standing_on_box() -> bool:
	return (
		is_on_floor()
		&& attachment == Attachment.Free
		&& distance_to_box < 0.25 
		&& position.y > box.attachment_point.position.y
	)

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


func popToBox() -> void:
	if is_carrying:
		drop_carried_item(2, PI/2)
	position = box.position
	change_attachment(Attachment.Boxed)
	visible = false
	model.scale.y = 0.1
	active_camera.start_chase()
	await active_camera.chase_ended
	box.pop()
	visible = true
	model.scale.y = 1
	popped.emit(box)


func would_recieve_item(_item: Attachable) -> bool:
	return not is_carrying


func hold_item(item : Attachable, delta) -> void:
	match item:
		carried_item when is_carrying:
			item.track(10 * delta, attachment_points['hand'])
		box:
			item.reposition(0, attachment_points['foot'].global_position)
			match state:
				State.Airborn:
					item.reorient(10 * delta, global_rotation)
				_:
					item.reorient(0)
			box_collider.global_rotation = box.global_rotation
		_:
			pass


func drop_carried_item(force : float = 0.0, pitch : float = 0.0, from: String = "auto") -> void:
	if not is_carrying: return
	is_carrying = false
	var throw_origin : Vector3 = attachment_points["throw"].global_position
	var throw_force : Vector3 = velocity
	
	if force > 0:
		var launch_dir = Vector3.MODEL_FRONT
		if pitch > 0:
			launch_dir = launch_dir.rotated(Vector3.MODEL_RIGHT, pitch)
		launch_dir = launch_dir.rotated(Vector3.UP, rotation.y)
		
		throw_force += launch_dir.normalized() * force
	elif velocity.length() > get_max_move_speed() / 2:
		throw_origin = attachment_points["hand"].global_position

	if from != "auto":
		throw_origin = attachment_points[from].global_position

	carried_item.reposition(0, throw_origin)
	carried_item.velocity = throw_force
	carried_item.detach()


func recieve_item(item: Attachable):
	carried_item = item
	carried_item.attach(self)
	is_carrying = true
	print("Carrying ", carried_item)
	if carried_item == box:
		carried_item.close()


func start_charing_jump() -> void:
	other_model.scale.y = 1
	jump_charge = 0.0


func charge_jump(delta) -> void:
	if (jump_charge <= 1.0):
		jump_charge += jump_charge_rate * delta
	else:
		jump_charge_rate = 1
	var jump_multiplier = boxed_jump_power.sample(jump_charge)

	if hanging:
		other_model.scale.y = 1 + (0.5 * jump_multiplier)
		var offset = -0.375 * jump_multiplier
		attachment_points["foot"].position.y = offset
		model.position.y = 0.375 + offset
	else:
		other_model.scale.y = 1 - (0.5 * jump_multiplier)

func finish_charge_jump() -> float:
	var jump_multiplier : float = boxed_jump_power.sample(jump_charge)
	jump_charge = 0.0

	other_model.scale.y = 1
	if hanging:
		attachment_points["foot"].position.y = 0
		model.position.y = 0.375
	return jump_multiplier
#endregion

func _physics_process(delta: float) -> void:
	var direction = get_direction()
	distance_to_box = (box.position - position).length()

	#print("Ground Speed ", get_ground_speed(velocity).length())
	#print("Fall Speed ", floor(velocity.y))
	#print("distance from box: ", (position - box.position).length())
	#print("Jump type ", JumpType.keys()[jump_type])
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
		var can_interact : bool = false
		var is_pickup : bool = false
		var types := InteractionPoint.InteractionType
		if GameManager.active_interaction_point:
			can_interact = true
			is_pickup = GameManager.active_interaction_point.type == types.attachable
		if can_interact && not (is_carrying && is_pickup) :
			GameManager.trigger_interaction()
		else:
			drop_carried_item()

	if Input.is_action_just_pressed("Pop"):
		print("Distance: ", distance_to_box)
		match attachment:
			Attachment.Boxed:
				box.detach()
				change_attachment(Attachment.Free)
				if state == State.Crouched:
					box.pop()
					jump_type = JumpType.Launch
					velocity.y = get_jump_strength() * 2
				else:
					jump_type = JumpType.PopOut
					velocity.y = get_jump_strength()
			Attachment.Free when is_carrying && carried_item == box:
				is_carrying = false
				jump_type = JumpType.PopIn
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
				pass

	if Input.is_action_just_released("Pop"):
		if pop_button_timer.time_left > pop_button_timer.wait_time / 3 && distance_to_box > 3:
			active_camera.align(get_angle_to_box(), 10)
		if not pop_button_timer.is_stopped():
			pop_button_timer.stop()

	match state:
		State.Grounded when attachment == Attachment.Boxed:
			anim.play("Free/Idle")
			other_model.anim.play("Yay")
			apply_movement(Vector3.ZERO, delta)

			if (direction):
				follow_motion(direction, delta * 6)

			if Input.is_action_just_pressed("Crouch"):
				if is_carrying:
					drop_carried_item(0, PI/2, "head")
				change_state(State.Crouched)

			if Input.is_action_just_pressed("Jump"):
				start_charing_jump()

			if Input.is_action_pressed("Jump"):
				charge_jump(delta)

			if Input.is_action_just_pressed("Attack") && is_carrying:
				drop_carried_item(3, PI/4)

			# Handle jump.
			if Input.is_action_just_released("Jump"):
				anim.play("Free/Jump", 0.5)
				var jump_multiplier := finish_charge_jump()
				var launch_height := Vector3.UP * get_jump_strength() * jump_multiplier
				var launch_direction : Vector3 = direction * get_move_speed() * jump_multiplier
				jump_type = JumpType.Spring
				velocity += launch_direction + launch_height
				cap_speed()

		State.Grounded:
			apply_movement(direction, delta)

			var speed := get_ground_speed(velocity).length()
			var sharp := is_sharp_turn(velocity, direction)

			if get_max_move_speed() - speed < 0.2:
				active_camera.align(rotation.y, 1, true)

			if sharp:
				if can_flip == false:
					anim.play("Free/Skid", 0.25)
				can_flip = true
			else:
				if can_flip == true:
					anim.play_backwards("Free/Skid")

				can_flip = false

				if (direction):
					follow_motion(direction, delta * 6)

				other_model.anim.play("BeYouMan")
				if speed > get_max_move_speed() / 2:
					anim.play("Free/Run", 0.5)
				elif speed > 0:
					anim.play("Free/Walk", 0.5)
				else:
					anim.play("Free/Idle", 0.5)

			if Input.is_action_just_pressed("Crouch"):
				if is_carrying:
					if carried_item == box:
						is_carrying = false
						change_attachment(Attachment.Boxed)
					else:
						drop_carried_item()
				change_state(State.Crouched)

			# Handle jump.
			if Input.is_action_just_pressed("Jump"):
				if (can_flip):
					anim.play("Free/Flip")
					jump_type = JumpType.SideFlip
					velocity = Vector3.UP * (get_jump_strength() * 1.5)
				else:
					jump_type = JumpType.Normal
					jump_cancelled = false
					velocity.y = get_jump_strength()

			if Input.is_action_just_pressed("Attack") && is_carrying:
				drop_carried_item(3, PI/4)

		State.Airborn when hanging:
			var wall_normal : Vector3

			if is_on_wall():
				wall_normal = get_wall_normal()
				ledge_hook.target_position = wall_normal * -0.25
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

			if attachment == Attachment.Boxed:
				if Input.is_action_just_pressed("Jump"):
					start_charing_jump()

				if Input.is_action_pressed("Jump"):
					charge_jump(delta)

			# Left the ledge or hit crouch
			if !ledge_hook.is_colliding() || Input.is_action_just_pressed("Crouch"):
				finish_charge_jump()
				active_camera.align(best_side_view, 10)
				hanging_cooldown = 1
				hanging = false

			# Handle normal jump.
			elif Input.is_action_just_pressed("Jump") and attachment != Attachment.Boxed:
				active_camera.align(best_side_view, 10)
				hanging_cooldown = 1
				
				
				hanging = false
				if wall_dot > 0.8:
					jump_type = JumpType.LedgeAway
					velocity = (get_jump_strength() * Vector3.UP) + (wall_normal * 2)
					follow_motion(wall_normal, 60 * delta)
				else:
					jump_type = JumpType.LedgeTowards
					velocity = (get_jump_strength() * Vector3.UP) + (wall_normal * -0.5)

			# Handle boxed jump
			elif Input.is_action_just_released("Jump") && attachment == Attachment.Boxed:
				var jump_multiplier := finish_charge_jump()
				var launch_height := (Vector3.UP * get_jump_strength() * jump_multiplier)
				var launch_direction :=  + (wall_normal * -0.5)

				hanging_cooldown = 1
				hanging = false
				anim.play("Free/Jump", 0.5)
				jump_type = JumpType.LedgeLaunch
				velocity = launch_direction + launch_height

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
			ledge_hook.target_position = wall_normal * -0.25
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
				if attachment == Attachment.Boxed:
					jump_type = JumpType.Wall
					velocity = wall_normal
				else:
					jump_type = JumpType.Wall
					velocity = (get_jump_strength() * Vector3.UP) + (wall_normal * 2)
					follow_motion(wall_normal, 60 * delta)

		State.Airborn:
			# Grab gravity
			var gravity := get_gravity()

			# Ledge Logic
			var ledge_direction := Vector3.MODEL_FRONT.rotated(Vector3.UP, rotation.y).normalized()
			ledge_hook.target_position = ledge_direction * 0.25
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

			# Chase camera when boxed
			if attachment == Attachment.Boxed && get_ground_speed(velocity).length() > 2:
				active_camera.align(rotation.y, 1, true)

			# Trigger jump cancelling
			if (
				Input.is_action_just_released("Jump")
				&& jump_type == JumpType.Normal
				&& jump_cancelled == false
			) :
				jump_cancelled = true

			if is_falling():
				# Fall faster for better Game Feel
				gravity *= 1.5

				# Get pulled against walls for easier wall-jumps
				if wall_detect.is_colliding():
					var distance_to_wall = wall_detect.get_collision_point() - position
					distance_to_wall.y = 0
					if distance_to_wall.length() < .2:
						velocity += ledge_direction * 0.1

				# Animation Logic
				if !falling:
					falling = true
					if not attachment == Attachment.Boxed:
						other_model.anim.play("FallingOff")
					anim.play("Free/Fall", 1)
					anim.queue("Free/Falling")
			elif jump_type == JumpType.Normal && jump_cancelled:
				if velocity.y < 3:
					velocity.y *= 0.5

			# Apply gravity
			velocity += gravity * delta
			
			var flipping = anim.current_animation == "Free/Flip"
			apply_movement(direction, delta, 1.5 if flipping else 1.0)
			if flipping:
				follow_motion(direction, 6 * delta)

			if attachment == Attachment.Boxed:
				if Input.is_action_just_pressed("Jump"):
					start_charing_jump()

				if Input.is_action_pressed("Jump"):
					charge_jump(delta)

			if Input.is_action_just_pressed("Attack") && is_carrying:
				drop_carried_item(3, PI/4)
				velocity = Vector3.UP * 2
			
			velocity.y = clamp(velocity.y, -10.0, 10.0)

		State.Crouched when attachment == Attachment.Boxed:
			apply_movement(direction, delta)
			if Input.is_action_just_released("Crouch"):
				change_state(State.Grounded)

			if Input.is_action_just_pressed("Jump"):
				start_charing_jump()

			if Input.is_action_pressed("Jump"):
				charge_jump(delta)

			# Handle jump.
			if Input.is_action_just_released("Jump"):
				anim.play("Free/Jump", 0.5)
				var jump_multiplier := finish_charge_jump()
				var launch_height := Vector3.UP * get_jump_strength() * jump_multiplier
				var launch_direction : Vector3 = direction * get_move_speed() * jump_multiplier
				jump_type = JumpType.Hop
				velocity = launch_direction + launch_height

		State.Crouched:
			apply_movement(direction, delta)
			var speed := get_ground_speed(velocity).length()
	
			if get_max_move_speed() - speed < 0.2:
				active_camera.align(rotation.y, 1, true)

			if Input.is_action_just_released("Crouch"):
				change_state(State.Grounded)

			if Input.is_action_pressed("Jump"):
				if speed > 1.5:
					jump_type = JumpType.Long
					velocity += (Vector3.UP + (velocity.normalized() * 0.5)) * get_jump_strength()
				else:
					anim.play("Free/Flip")
					jump_type = JumpType.BackFlip
					velocity = Vector3.UP  * (get_jump_strength() * 1.5)

		State.Armed when aiming:
			print("Aiming!")

		State.Armed:
			print("Armed!")

	move_and_slide()


func _on_global_interaction(interaction_point : InteractionPoint):
	var types := InteractionPoint.InteractionType
	var target := interaction_point.get_parent_node_3d()

	match interaction_point.type:
		types.carrier when is_carrying:
			if carried_item.can_attach(target):
				is_carrying = false
				if target.has_method("recieve_item"):
					carried_item.detach()
					target.recieve_item(carried_item)
			else:
				drop_carried_item()
						
		types.attachable when state != State.Crouched:
			if would_recieve_item(target):
				recieve_item(target)
		types.dispenser when state != State.Crouched:
			if would_recieve_item(target.get_offered_item()):
				target.give_item(self)
		types.custom:
			print("Do some kind of custom interaction???")
		_:
			print("New interaction. Type: ", types.keys()[interaction_point.type])
