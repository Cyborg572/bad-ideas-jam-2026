class_name CameraRig
extends Node3D

signal chase_started(target: Node3D)
signal chase_ended(target: Node3D)

enum Shot {
	Closeup,
	Normal,
	Wide
}


@export var is_main_camera : bool = false
@export var target:Node3D;
@export var camera_sensitivity: float = 2.5
@export var mouse_sensitivity: float = 5
@export var camera_speed:float = 5
@export var default_shot_type : Shot = Shot.Normal

@export_subgroup("Distance", "distance_")
## How far away is the camera for closeups
@export var distance_closeup : float = 0.5
## How far away is the camera for normal tracking
@export var distance_normal : float = 1.5
## How far way is the camera for wide tracking
@export var distance_wide : float = 3

var is_frozen: bool = false

@onready var arm: SpringArm3D = $SpringArm3D
@onready var camera_position: Node3D = $SpringArm3D/CameraPosition
@onready var camera: Camera3D = $Camera3D

const default_pitch : float  = -PI/8.0
const default_alignment := Vector3(default_pitch, 0, 0);

var aligning : bool = false:
	set(value):
		aligning = value
var alignment_target : Vector3 = default_alignment
var alignment_speed : float = 0.0
var alignment_one_time : bool = false
var shot_type : Shot = Shot.Normal
var chasing = false
var chase_speed = 10

func get_target_position() -> Vector3:
	var target_position : Vector3 = target.position
	if "camera_target" in target:
		target_position += target.camera_target.position
	return target_position


func get_target_rotation() -> Vector3:
	var target_rotation : Vector3 = target.rotation
	if target.camera_target:
		target_rotation += target.camera_target.rotation
	#else:
		#target_rotation.y += PI
	return target_rotation


func rotate_relative_to_view(direction: Vector3) -> Vector3:
	return direction.rotated(Vector3.UP, camera.global_rotation.y)


func start_chase(speed: float = 10, force_speed:bool = false, force_jump: bool = false):
	if force_speed || chase_speed < speed:
		chase_speed = speed
	if not chasing:
		chasing = true
		chase_started.emit(target)
		var target_position = get_target_position()
		var distance = (target_position - position).length()
		if distance > 20 or force_jump:
			is_frozen = true
			await GameManager.hide_game()
			is_frozen = false
		else:
			if distance > 1:
				align(Utils.direction_to_y_angle(get_target_position() - position), chase_speed)



func end_chase():
	if chasing:
		chasing = false
		chase_speed = 10
		#align(get_target_rotation().y, 5)
		await GameManager.show_game()
		chase_ended.emit(target)


func set_shot_type(new_shot_type: Shot) -> void:
	match new_shot_type:
		Shot.Closeup:
			arm.spring_length = distance_closeup
		Shot.Normal:
			arm.spring_length = distance_normal
		Shot.Wide:
			arm.spring_length = distance_wide
	shot_type = new_shot_type


func push_in() -> void:
	match shot_type:
		Shot.Closeup:
			pass
		Shot.Normal:
			set_shot_type(Shot.Closeup)
		Shot.Wide:
			set_shot_type(Shot.Normal)


func pull_out() -> void:
	match shot_type:
		Shot.Closeup:
			set_shot_type(Shot.Normal)
		Shot.Normal:
			set_shot_type(Shot.Wide)
		Shot.Wide:
			pass


func align(target_angle = default_alignment, speed: float = 0.0, one_time = false) -> void:
	aligning = true
	alignment_speed = speed
	alignment_one_time = one_time
	if target_angle is Vector3:
		alignment_target = target_angle
	elif target_angle is float:
		alignment_target = Vector3(default_pitch, target_angle, 0)
	else:
		alignment_target = default_alignment

	# The camera looks in the opposite of the direction you'd expect.
	alignment_target.y = wrapf(alignment_target.y + PI, 0.0, TAU)
	alignment_target.z = 0


func cancel_align() -> void:
	aligning = false
	alignment_target = default_alignment
	alignment_speed = 0.0
	alignment_one_time = false


func _ready() -> void:
	if !target: return

	position = get_target_position()
	rotation.x = -PI/8
	camera.position = camera_position.position
	set_shot_type(default_shot_type)


#func _unhandled_input(event: InputEvent) -> void:
	#if event is InputEventMouseMotion:
		#rotation.y -= event.relative.x * (mouse_sensitivity / 1000)
		#rotation.x -= event.relative.y * (mouse_sensitivity / 1000)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if is_frozen:
		return

	var movement_x := Input.get_axis("camera_left", "camera_right")
	var movement_y := Input.get_axis("camera_up", "camera_down")

	if movement_x || movement_y:
		cancel_align()

	if aligning:
		# Get the current and intended rotations as Quaternions
		var goal = Quaternion.from_euler(alignment_target).normalized()
		var current = Quaternion.from_euler(rotation).normalized()
		var sweep_angle = current.angle_to(goal);

		if alignment_speed <= 0:
			rotation = alignment_target
		else:
			rotation = current.slerp(goal, alignment_speed * delta).get_euler()

		if sweep_angle < 0.05 || alignment_one_time:
			cancel_align()

	rotation.y -= delta * movement_x * camera_sensitivity
	rotation.x -= delta * movement_y * camera_sensitivity

	# Contstrain the rotation
	rotation.y = wrapf(rotation.y, 0.0, TAU)
	rotation.x = clamp(rotation.x, -PI/2 + PI/8, PI/4)

	if !target:
		return

	var target_position = get_target_position()
	var distance = (target_position - position).length()

	if distance > 5:
		start_chase(20)
	elif distance > 2:
		start_chase(10)

	if distance < 0.5:
		end_chase()

	# Once the bearing is right, jump if the distance is _really_ far
	if distance > 5 and not aligning:
		position = position.move_toward(target_position, distance - 5)

	position = position.move_toward(target_position, chase_speed * delta)

	camera.position = lerp(camera.position, camera_position.position, delta*camera_speed)
	camera.global_rotation.z = 0


## Jump the camera to the position node immediately.
func skip_camera_travel() -> void:
	camera.position = camera_position.position
