class_name CameraZone
extends Area3D

## Overrides the camera in specific situations

@export var alignment_vector: Vector3 = Vector3.MODEL_FRONT
@export var shot_type: CameraRig.Shot = CameraRig.Shot.Normal

var jack_in_zone: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Configure the collision mask and layers
	collision_layer = 0
	collision_mask = 0
	set_collision_mask_value(3, true)


#func _physics_process(_delta: float) -> void:
	#if jack_in_zone:
		#var new_rotation = Quaternion(Vector3.MODEL_FRONT, alignment_vector).get_euler()
		#GameManager.main_camera.align(new_rotation, 3, true)


func _on_body_entered(body: Node3D) -> void:
	if body is Jack:
		jack_in_zone = true
		var new_rotation = Quaternion(Vector3.MODEL_FRONT, alignment_vector).get_euler()
		GameManager.main_camera.lock_angle(new_rotation, shot_type)


func _on_body_exited(body: Node3D) -> void:
	if body is Jack:
		jack_in_zone = false
		GameManager.main_camera.unlock_angle()
