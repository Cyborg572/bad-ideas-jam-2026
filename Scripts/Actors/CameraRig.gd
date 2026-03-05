class_name CameraRig
extends Node3D

@export var is_main_camera : bool = false
@export var target:Node3D;
@export var camera_sensitivity: float = 2.5
@export var mouse_sensitivity: float = 5
@export var camera_speed:float = 5

@onready var camera_position: Node3D = $SpringArm3D/CameraPosition
@onready var camera: Camera3D = $Camera3D

const default_pitch : float  = -PI/8.0
const default_alignment := Vector3(default_pitch, 0, 0);

var aligning : bool = false
var alignment_target : Vector3 = default_alignment
var alignment_speed : float = 0.0

func get_target_position() -> Vector3:
	var target_position : Vector3 = target.position
	if target.camera_target:
		target_position += target.camera_target.position
	else:
		target_position.y += 1.5
	return target_position


func rotate_relative_to_view(direction: Vector3) -> Vector3:
	return direction.rotated(Vector3.UP, camera.global_rotation.y)


func align(target_angle = default_alignment, speed: float = 0.0) -> void:
	aligning = true
	alignment_speed = speed
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


func _ready() -> void:
	if is_main_camera:
		GameManager.main_camera = self
	
	if !target: return

	position = get_target_position()
	rotation.x = -PI/8
	camera.position = camera_position.position


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotation.y -= event.relative.x * (mouse_sensitivity / 1000)
		rotation.x -= event.relative.y * (mouse_sensitivity / 1000)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
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
			print("Snap Aligning")
			rotation = alignment_target
		else:
			rotation = current.slerp(goal, alignment_speed * delta).get_euler()

		if sweep_angle < 0.05:
			cancel_align()
			print("Aligned")

	rotation.y -= delta * movement_x * camera_sensitivity
	rotation.x -= delta * movement_y * camera_sensitivity

	# Contstrain the rotation
	rotation.y = wrapf(rotation.y, 0.0, TAU)
	rotation.x = clamp(rotation.x, -PI/4, 0)

	if !target:
		return

	position = get_target_position()
	
	camera.position = lerp(camera.position, camera_position.position, delta*camera_speed)
	camera.global_rotation.z = 0
