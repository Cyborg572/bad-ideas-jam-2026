class_name Jack
extends CharacterBody3D

signal popped(box: TheBox)
signal boxed()
signal unboxed()
signal got_box()
signal lost_box()

enum State { GROUNDED, AIRBORN, CROUCHED, AIMING, ARMED }

enum JumpType {
	## Not a Jump
	NONE,
	## Jump from the ground, no box, no fancyness
	NORMAL,
	## Jump from the ground, attached to the box, but out of it
	SPRING,
	## Jump from the ground while hiding in the box
	HOP,
	## Jump during sudden change in direction
	SIDE_FLIP,
	## Jump from sliding during a crouch
	LONG,
	## Jump from crouch
	BACK_FLIP,
	## Kick off a wall
	WALL,
	## Onto a ledge from hanging
	LEDGE_TOWARDS,
	## Like a wall kick, but from hanging
	LEDGE_AWAY,
	## Stretch and launch with the box, from hanging
	LEDGE_LAUNCH,
	## Shot out of the box, or other launcher
	LAUNCH,
	## Detached from the box
	POP_OUT,
	## The little boost from entering the box while carrying it
	POP_IN
}

## The jump types count as flips for the various things that care.
const FLIP_JUMPS := [
	JumpType.BACK_FLIP,
	JumpType.SIDE_FLIP
]

## These jump types do not qualify for scoring
const UNSCORED_JUMPS := [
	JumpType.NONE,
	JumpType.SPRING,
	JumpType.HOP,
]


#region Export Vars
@export var state_config : Dictionary[State, JackStateConfiguration]
@export var is_carrying : bool = false
@export var carried_item : Attachable
@export var start_with_box : bool = false
@export var box : TheBox
@export var boxed_jump_power: Curve
#endregion

#region OnReady Vars

@onready var input_component: InputComponent = $InputComponent
@onready var model : JackModel = $Jack
@onready var anim : AnimationTree = model.animation_tree
@onready var indicator := $InteractionIndicator
@onready var camera_target := $CameraTarget
@onready var ledge_hook: RayCast3D = $LedgeHook
@onready var wall_detect: RayCast3D = $WallDetect
@onready var body_collider: CollisionShape3D = $BodyCollider
@onready var box_collider: CollisionShape3D = $BoxCollider
@onready var anxiety_timer: Timer = $Timers/AnxietyTimer
@onready var pop_button_timer: Timer = $Timers/PopButtonTimer
#endregion

var state : State = State.GROUNDED
var is_boxed : bool = false
var attachment_points : Dictionary[String, Node3D] = {}

var can_flip : bool = false
var throwing : bool = false
var aiming : bool = false
var is_hanging : bool = false
var hanging_cooldown : float = 0.0
var is_hiding : bool = false
var jump_charge: float = 1.0
var jump_charge_rate : float = 5
var is_jump_charging : bool = false
var jump_type : JumpType = JumpType.NONE
var jump_cancelled : bool = false

var active_camera : CameraRig
var distance_to_box : float = 0

# Movement tracking for controls and animation tree
var speed : float = 0
var sharp : bool = false

# Confidence tracker stats
var jump_start_position := Vector3.ZERO
var walljump_count: int = 0
# Start the jump with any of the FLIP_JUMP jumps
var flipped_into_jump: bool = false
# Need to land on the open box while holding the crouch button
var landed_in_box: bool = false


func _ready() -> void:
	GameManager.jack = self
	set_active_camera(GameManager.main_camera)
	GameManager.change_camera.connect(set_active_camera)
	GameManager.interaction.connect(_on_global_interaction)
	GameManager.player_confidence_changed.connect(_on_player_confidence_changed)
	GameManager.player_confidence_lost.connect(popToBox)
	match_face_to_confidence(GameManager.player_confidence)

	attachment_points['head'] = $AttachmentPoints/Head
	attachment_points['hand'] = model.hand_attachment
	attachment_points['foot'] = $AttachmentPoints/Foot
	attachment_points['model_foot'] = model.foot_attachment
	attachment_points['throw'] = $AttachmentPoints/Throw

	anxiety_timer.timeout.connect(tick_down_confidence)
	pop_button_timer.timeout.connect(popToBox)

	if start_with_box:
		popToBox.call_deferred()


#region State value accessors
func get_move_speed() -> float:
	return state_config[state].get_move_speed(is_boxed)


func get_friction() -> float:
	return state_config[state].get_friction(is_boxed)


func get_jump_strength() -> float:
	return state_config[state].get_jump_strength(is_boxed)


func get_max_move_speed() -> float:
	return state_config[state].get_max_move_speed(is_boxed)


func get_max_speed() -> float:
	return state_config[state].get_max_speed(is_boxed)
#endregion

#region Box management

func leave_box() -> void:
	is_boxed = false
	box_collider.position = Vector3(0, 0.375, 0)
	box_collider.disabled = true

	# Clean up from hiding in box
	is_hiding = false
	model.show()
	body_collider.disabled = false

	# Cinema!
	# box.slam()
	anxiety_timer.start()
	unboxed.emit()
	lost_box.emit()

func enter_box() -> void:
	is_boxed = true
	got_box.emit()
	box_collider.disabled = false
	anxiety_timer.stop()
	GameManager.reset_confidence()
	velocity += box.velocity
	box.attach(self)
	box_collider.position = attachment_points['foot'].position - box.attachment_point.position
	boxed.emit()

func hide_in_box() -> void:
	is_hiding = true
	body_collider.disabled = true
	model.hide()
	box.slam()

func pop_out() -> void:
	is_hiding = false
	body_collider.disabled = false
	box.pop()
	model.show()

## Checks if Jack is in - or (optionally) is carrying - The Box.
func has_the_box(ignore_carrying: bool = false) -> bool:
	# Check if in the box
	if is_boxed or ignore_carrying:
		return is_boxed

	# Check if carrying the box
	return is_carrying && carried_item == box

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
		State.GROUNDED:
			var score_jump: bool = jump_type not in UNSCORED_JUMPS
			jump_type = JumpType.NONE
			jump_cancelled = false

			if not Input.is_action_pressed("Jump"):
				finish_charge_jump()
			if is_standing_on_box() && box.is_open:
				enter_box()
				if Input.is_action_pressed("Crouch"):
					hide_in_box()
					landed_in_box = true

			if score_jump:
				var jump_coolness = caclulate_jump_coolness()
				GameManager.player_confidence += jump_coolness / 10.0

			reset_jump_stats()

		State.AIRBORN:
			is_hanging = false
			hanging_cooldown = 0.0

			jump_start_position = position
			if jump_type in FLIP_JUMPS:
				flipped_into_jump = true
		_:
			pass

#endregion


#region Utilities
func set_active_camera(camera: CameraRig):
	active_camera = camera


func get_angle_to_box() -> float:
	return Utils.direction_to_y_angle(box.position, position)
#endregion

#region Process helpers

func apply_movement(acceleration: Vector3, delta : float, multiplier : float = 1.0 ) -> void:
	var movement = acceleration * delta * (get_move_speed() * multiplier)
	var ground_speed := Utils.get_ground_speed(velocity)
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
	speed = ground_speed.length()
	sharp = Utils.is_sharp_turn(velocity, direction)


func cap_speed() -> void:
	Utils.cap_ground_speed(velocity, get_max_speed())


func is_falling() -> bool:
	return velocity.y < 0


func is_standing_on_box() -> bool:
	return (
		is_on_floor()
		&& !is_boxed
		&& distance_to_box < 0.25
		&& position.y > box.attachment_point.position.y
	)

func get_direction() -> Vector3:
	# Get the input direction and handle the movement/deceleration.
	var direction := input_component.direction

	if active_camera:
		direction = active_camera.rotate_relative_to_view(direction)

	return direction

func follow_motion(direction: Vector3, rate: float) -> void:
	rotation = Utils.rotate_toward_motion(rotation, direction, rate)
	ledge_hook.rotation.y = -rotation.y
	wall_detect.rotation.y = -rotation.y


func popToBox() -> void:
	if is_carrying:
		drop_carried_item(2, PI/2)
	position = box.position
	enter_box()
	hide_in_box()
	active_camera.start_chase()
	await active_camera.chase_ended
	pop_out()
	popped.emit(box)


func would_recieve_item(_item: Attachable) -> bool:
	return not is_carrying


func hold_item(item : Attachable, delta) -> void:
	match item:
		carried_item when is_carrying:
			if is_hiding:
				item.track(0, attachment_points['foot'], 0.1)
			else:
				item.track(10 * delta if item.passing else 0, attachment_points['hand'])
		box:
			var point: String = "model_foot" if (
				is_hanging and is_boxed and not is_jump_charging
			) else "foot"

			item.match_scale(0, attachment_points[point].scale)
			item.reposition(0, attachment_points[point].global_position)
			match state:
				State.AIRBORN:
					item.reorient(10 * delta, global_rotation)
				_:
					item.reorient(0)
			box_collider.global_rotation = box.global_rotation
		_:
			pass


func drop_carried_item(force : float = 0.0, pitch : float = 0.0, from: String = "auto") -> void:
	if not is_carrying: return
	is_carrying = false
	anim.set("parameters/Carrying/blend_amount", 0)
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
	if carried_item == box:
		lost_box.emit()


func recieve_item(item: Attachable):
	carried_item = item
	carried_item.attach(self)
	is_carrying = true
	anim.set("parameters/Carrying/blend_amount", 1)
	if carried_item == box:
		got_box.emit()
		carried_item.close()


func start_charing_jump() -> void:
	is_jump_charging = true
	model.scale.y = 1
	jump_charge = 0.0


func charge_jump(delta) -> void:
	if (jump_charge <= 1.0):
		jump_charge += jump_charge_rate * delta
	else:
		jump_charge_rate = 1
	var jump_multiplier = boxed_jump_power.sample(jump_charge)

	if is_hanging:
		anim.set(
			"parameters/Base/Boxed/WallHang/charge/power/seek_request",
			jump_multiplier
		)

		var offset = -0.375 * jump_multiplier
		attachment_points["foot"].position.y = offset
	elif is_hiding:
		box.model.scale.y = 1 - (0.25 * jump_multiplier)
		box.model.scale.x = 1 + (0.25 * jump_multiplier)
		box.model.scale.z = 1 + (0.25 * jump_multiplier)
	else:
		anim.set(
			"parameters/Base/Boxed/Spring/charge/power/seek_request",
			jump_multiplier
		)
		pass


func finish_charge_jump() -> float:
	var jump_multiplier : float = boxed_jump_power.sample(jump_charge)
	jump_charge = 0.0

	model.scale.y = 1
	box.model.scale = Vector3(1, 1, 1)

	if is_hanging:
		attachment_points["foot"].position.y = 0

	is_jump_charging = false
	return jump_multiplier


func match_face_to_confidence(confidence: float) -> void:
	var frown_amount: float = 1.0 - (confidence / 100.0)
	print("Frown amount: ", frown_amount)
	anim.set("parameters/Frowning/blend_amount", frown_amount)


func tick_down_confidence() -> void:
	var zones := get_tree().get_nodes_in_group("Confidence Zones")
	var skip_default: bool = false
	for zone in zones:
		if not zone is ConfidenceZone:
			return
		zone = zone as ConfidenceZone
		skip_default = skip_default or zone.prevent_loss
		zone.apply_constant_adjustment()

	if distance_to_box < 2 or skip_default:
		return
	elif distance_to_box < 15:
		GameManager.player_confidence -= 0.5
	elif distance_to_box < 30:
		GameManager.player_confidence -= 2
	else:
		GameManager.player_confidence -= 4


func reset_jump_stats() -> void:
	jump_start_position = Vector3.ZERO
	walljump_count = 0
	flipped_into_jump = false


func caclulate_jump_coolness() -> int:
	var jump_distance = position - jump_start_position
	var jump_height = jump_distance.y
	var horizontal_distance = Utils.get_ground_speed(jump_distance).length()

	# Upwards jumps get points, as long as they're more than the basic jump
	var height_bonus: int = 0 if jump_height < 0.75 else floor(jump_height * 2)

	# Big jumps get a "leap of faith" bonus (walking off a ledge doesn't count)
	var leap_of_faith_bonus: int =  0 if jump_height > -10 else 1 + floor(abs(jump_height) / 10)

	# Multiplier for diving into the box (must be holding crouch)
	var dive_bonus: int = 2 if landed_in_box else 0

	# Horizontal distance bonus needs to be longer than standard long jump.
	# 4.5m requires popping into the box to extend the distance, after dipping
	# a bit below the starting jump height
	# 7 requires hoping back out.
	var distance_bonus : int = (
		5 if horizontal_distance > 7
		else 3 if horizontal_distance > 4.5
		else 0
	)

	# Reduce the distance bonus if there was a large loss of height
	if jump_height < 0:
		distance_bonus = ceil(distance_bonus / ceil(abs(jump_height)))

	# BIG multiplier for diving directly into the box from a great height
	var dive_of_faith_multiplier: int = 10 if (
		jump_height < -5
		and landed_in_box
		and walljump_count < 1
	) else 1

	# Multiplier for wall jumps
	var wall_jump_multiplier: int = clamp(1, walljump_count * 2, 16)

	# Any jump that starts with a flip is 3 times cooler
	var flip_multiplier: int = 3 if flipped_into_jump else 1

	var total: int = height_bonus + leap_of_faith_bonus
	total += dive_bonus
	total += distance_bonus
	total *= dive_of_faith_multiplier
	total *= wall_jump_multiplier
	total *= flip_multiplier

	return total
#endregion


func _physics_process(delta: float) -> void:
	# Component ticks
	input_component.update_inputs(self)

	var direction = get_direction()
	distance_to_box = (box.position - position).length()
	GameManager.distance_to_box = distance_to_box

	#print("Ground Speed ", get_ground_speed(velocity).length())
	#print("Fall Speed ", floor(velocity.y))
	#print("distance from box: ", (position - box.position).length())
	#print("Jump type ", JumpType.keys()[jump_type])

	# Toggle Airborn state automatically
	if not is_on_floor():
		if state != State.AIRBORN:
			change_state(State.AIRBORN)
	elif state == State.AIRBORN:
		change_state(State.GROUNDED)

	# Count off cooldowns
	hanging_cooldown -= delta

	#region Universal inputs

	if Input.is_action_just_pressed("camera_reset"):
		active_camera.align(rotation.y, 10)

	if Input.is_action_just_pressed("Interact"):
		var can_interact : bool = false
		var is_pickup : bool = false
		var types := InteractionPoint.InteractionType
		if GameManager.active_interaction_point:
			can_interact = true
			is_pickup = GameManager.active_interaction_point.type == types.attachable
		if can_interact && not (is_carrying && is_pickup):
			GameManager.trigger_interaction()
		elif is_hiding:
			if is_carrying:
				if box.would_recieve_item(carried_item):
					carried_item.detach()
					carried_item.give_to(box)
					is_carrying = false
					anim.set("parameters/Carrying/blend_amount", 0)
			elif not box.inventory.is_empty():
				box.give_item(self)

		elif is_carrying:
			drop_carried_item()

	if Input.is_action_just_pressed("Pop"):
		match is_boxed:
			true:
				if is_hiding:
					box.start_cranking()
				else:
					box.detach()
					leave_box()
					jump_type = JumpType.POP_OUT
					velocity.y = get_jump_strength()
					change_state(State.AIRBORN)

			false when is_carrying && carried_item == box:
				is_carrying = false
				anim.set("parameters/Carrying/blend_amount", 0)
				jump_type = JumpType.POP_IN
				velocity.y = get_jump_strength()
				popToBox()
			false when box:
				if distance_to_box < 1:
					box.toggle_open()
				else:
					box.close()
				if not box.is_open:
					pop_button_timer.start()
			_:
				pass

	if Input.is_action_just_released("Pop"):
		if is_boxed:
			var in_pop_window = box.stop_cranking()
			if in_pop_window:
				box.detach()
				leave_box()
				box.pop()
				jump_type = JumpType.LAUNCH
				velocity.y = get_jump_strength() * 2
				change_state(State.AIRBORN)
		else:
			if pop_button_timer.time_left > pop_button_timer.wait_time / 3 && distance_to_box > 3:
				active_camera.align(get_angle_to_box(), 10)
			if not pop_button_timer.is_stopped():
				pop_button_timer.stop()

	if Input.is_action_just_pressed("Crouch") && is_boxed:
		#if is_carrying:
				#drop_carried_item(0, PI/2, "head")
		hide_in_box()

	if Input.is_action_just_released("Crouch") && is_boxed:
		if not active_camera.chasing:
			pop_out()
	#endregion

	match state:
		State.GROUNDED when is_boxed:
			apply_movement(Vector3.ZERO, delta)

			if (direction):
				follow_motion(direction, delta * 6)

			if Input.is_action_just_pressed("Jump"):
				start_charing_jump()

			if Input.is_action_pressed("Jump"):
				charge_jump(delta)

			if Input.is_action_just_pressed("Attack") && is_carrying:
				if is_hiding:
					drop_carried_item(3, PI/4)
					await box.pop()
					box.slam()
				else:
					drop_carried_item(3, PI/4)

			# Handle jump.
			if Input.is_action_just_released("Jump"):
				if is_hiding:
					var jump_multiplier := finish_charge_jump()
					var launch_height := Vector3.UP * get_jump_strength() * jump_multiplier
					var launch_direction : Vector3 = direction * get_move_speed() * jump_multiplier
					jump_type = JumpType.HOP
					velocity += (launch_direction + launch_height) / 2
					cap_speed()
				else:
					var jump_multiplier := finish_charge_jump()
					var launch_height := Vector3.UP * get_jump_strength() * jump_multiplier
					var launch_direction : Vector3 = direction * get_move_speed() * jump_multiplier
					jump_type = JumpType.SPRING
					velocity += launch_direction + launch_height
					cap_speed()

		State.GROUNDED:
			apply_movement(direction, delta)

			if get_max_move_speed() - speed < 0.2:
				active_camera.align(rotation.y, 1, true)

			if sharp:
				can_flip = true
			else:
				can_flip = false

				if (direction):
					follow_motion(direction, delta * 6)

				if speed > get_max_move_speed() / 2:
					anim.set(
						"parameters/Base/Free/Move/Run/run_speed/scale",
						1 / (3 / speed)
					)
				elif speed > 0:
					anim.set(
						"parameters/Base/Free/Move/Walk/walk_speed/scale",
						1 / (1.5 / speed)
					)

			if Input.is_action_just_pressed("Crouch"):
				if is_carrying:
					if carried_item == box:
						is_carrying = false
						anim.set("parameters/Carrying/blend_amount", 0)
						position.y += box.attachment_point.position.y
						enter_box()
						hide_in_box()
					else:
						drop_carried_item()
						change_state(State.CROUCHED)
				else:
					change_state(State.CROUCHED)

			# Handle jump.
			if Input.is_action_just_pressed("Jump"):
				if (can_flip):
					jump_type = JumpType.SIDE_FLIP
					velocity = Vector3.UP * (get_jump_strength() * 1.5)
				else:
					jump_type = JumpType.NORMAL
					jump_cancelled = false
					velocity.y = get_jump_strength()

			if Input.is_action_just_pressed("Attack") && is_carrying:
				drop_carried_item(3, PI/4)

		State.AIRBORN when is_hanging:
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
			var best_side_view = rotation.y if not back_to_wall else Utils.get_best_side_view(wall_normal, active_camera);

			if direction:
				# Explicit check here, because the else is "rotation" no "rotation.y"
				if back_to_wall:
					active_camera.align(best_side_view, 3, true)
				else:
					active_camera.align(rotation, 3, true)
			else:
				active_camera.cancel_align()

			if is_boxed:
				if Input.is_action_just_pressed("Jump"):
					start_charing_jump()

				if Input.is_action_pressed("Jump"):
					charge_jump(delta)

			# Left the ledge or hit crouch
			if !ledge_hook.is_colliding() || Input.is_action_just_pressed("Crouch"):
				finish_charge_jump()
				active_camera.align(best_side_view, 10)
				hanging_cooldown = 1
				is_hanging = false

			# Handle normal jump.
			elif Input.is_action_just_pressed("Jump") and !is_boxed:
				active_camera.align(best_side_view, 10)
				hanging_cooldown = 1


				is_hanging = false
				if wall_dot > 0.8:
					jump_type = JumpType.LEDGE_AWAY
					velocity = (get_jump_strength() * Vector3.UP) + (wall_normal * 2)
					follow_motion(wall_normal, 60 * delta)
				else:
					jump_type = JumpType.LEDGE_TOWARDS
					velocity = (get_jump_strength() * Vector3.UP) + (wall_normal * -0.5)

			# Handle boxed jump
			elif Input.is_action_just_released("Jump") && is_boxed:
				var jump_multiplier := finish_charge_jump()
				var launch_height := (Vector3.UP * get_jump_strength() * jump_multiplier)
				var launch_direction :=  + (wall_normal * -0.5)

				hanging_cooldown = 1
				is_hanging = false
				jump_type = JumpType.LEDGE_LAUNCH
				velocity = launch_direction + launch_height

			# Move along ledge
			else:
				direction = direction.slide(wall_normal)
				var gravity := wall_normal * -1
				follow_motion(wall_normal * -1, 60 * delta)
				velocity = direction + (gravity * delta)
				velocity.y = 0

		State.AIRBORN when is_on_wall_only():
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
				is_hanging = true
				hanging_cooldown = 1
				velocity = Vector3.ZERO

			if is_falling() && wall_detect.is_colliding():
				active_camera.align(Utils.get_best_side_view(wall_normal, active_camera), 5)
				direction = direction.slide(wall_normal)
				gravity = ((wall_normal * -1) + (gravity / 10))
				follow_motion(wall_normal, 30 * delta)

			# Handle movement
			apply_movement(direction, delta)

			# Apply gravity
			velocity += gravity * delta

			# Handle jump.
			if Input.is_action_just_pressed("Jump"):
				active_camera.align(Utils.get_best_side_view(wall_normal, active_camera), 10)
				if is_boxed:
					jump_type = JumpType.WALL
					velocity = wall_normal
				else:
					jump_type = JumpType.WALL
					walljump_count += 1
					velocity = (get_jump_strength() * Vector3.UP) + (wall_normal * 2)
					follow_motion(wall_normal, 60 * delta)

		State.AIRBORN:
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
				is_hanging = true
				hanging_cooldown = 1
				velocity = Vector3.ZERO

			# Chase camera when boxed
			if is_boxed && Utils.get_ground_speed(velocity).length() > 2:
				active_camera.align(rotation.y, 1, true)

			# Trigger jump cancelling
			if (
				Input.is_action_just_released("Jump")
				&& jump_type == JumpType.NORMAL
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

			else:
				if jump_type == JumpType.NORMAL && jump_cancelled:
					if velocity.y < 3:
						velocity.y *= 0.5

			# Apply gravity
			velocity += gravity * delta

			# TODO: This should be looking at jump type
			var flipping = jump_type in FLIP_JUMPS
			apply_movement(direction, delta, 1.5 if flipping else 1.0)
			#if flipping:
				#follow_motion(direction, 6 * delta)

			if is_boxed:
				if Input.is_action_just_pressed("Jump"):
					start_charing_jump()

				if Input.is_action_pressed("Jump"):
					charge_jump(delta)

			if Input.is_action_just_pressed("Attack") && is_carrying:
				drop_carried_item(3, PI/4)
				velocity = Vector3.UP * 2

			velocity.y = clamp(velocity.y, -10.0, 10.0)

		State.CROUCHED:
			apply_movement(direction, delta)

			if get_max_move_speed() - speed < 0.2:
				active_camera.align(rotation.y, 1, true)

			if speed > 0.01:
				follow_motion(direction, delta * 6)

			if Input.is_action_just_released("Crouch"):
				change_state(State.GROUNDED)

			if Input.is_action_pressed("Jump"):
				if speed > 1.5:
					jump_type = JumpType.LONG
					velocity += (Vector3.UP + (velocity.normalized() * 0.5)) * get_jump_strength()
				else:
					jump_type = JumpType.BACK_FLIP
					velocity = Vector3.UP  * (get_jump_strength() * 1.5)

		State.ARMED when aiming:
			print("Aiming!")

		State.ARMED:
			print("Armed!")

	move_and_slide()


func _on_player_confidence_changed(confidence: float) -> void:
	match_face_to_confidence(confidence)


func _on_global_interaction(interaction_point : InteractionPoint):
	var types := InteractionPoint.InteractionType
	var target := interaction_point.get_parent_node_3d()

	match interaction_point.type:
		types.carrier when is_carrying:
			if carried_item.can_attach(target):
				is_carrying = false
				anim.set("parameters/Carrying/blend_amount", 0)
				if target.has_method("recieve_item"):
					carried_item.detach()
					target.recieve_item(carried_item)
			else:
				drop_carried_item()

		types.attachable when state != State.CROUCHED and not is_hiding:
			if would_recieve_item(target):
				recieve_item(target)
		types.dispenser when state != State.CROUCHED:
			if would_recieve_item(target.get_offered_item()):
				target.give_item(self)
		types.custom:
			print("Do some kind of custom interaction???")
		_:
			print("New interaction. Type: ", types.keys()[interaction_point.type])
