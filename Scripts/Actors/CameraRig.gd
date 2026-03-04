extends Node3D

@export var is_main_camera : bool = false
@export var target:Node3D;
@export var camera_sensitivity: float = 2.5
@export var mouse_sensitivity: float = 5
@export var camera_speed:float = 5

@onready var camera_position: Node3D = $SpringArm3D/CameraPosition
@onready var camera: Camera3D = $Camera3D


func get_target_position() -> Vector3:
	var target_position : Vector3 = target.position
	if target.camera_target:
		target_position += target.camera_target.position
	else:
		target_position.y += 1.5
	return target_position


func _ready() -> void:
	if is_main_camera:
		GameManager.main_camera = camera
	
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
	rotation.y -= delta * movement_x * camera_sensitivity
	rotation.y = wrapf(rotation.y, 0.0, TAU)
	rotation.x -= delta * movement_y * camera_sensitivity
	rotation.x = clamp(rotation.x, -PI/4, 0)
	
	if !target:
		return

	position = get_target_position()
	
	camera.position = lerp(camera.position, camera_position.position, delta*camera_speed)
