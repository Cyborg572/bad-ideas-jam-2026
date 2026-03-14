class_name Utils
extends RefCounted

## Zeros-out the y component from a Vector3
static func get_ground_speed(vector: Vector3) -> Vector3:
	return Vector3(vector.x, 0, vector.z)


## Caps the X and Z values of a vector, leaving Y alone.
static func cap_ground_speed(velocity: Vector3, max_speed: float) -> void:
	var ground_speed := get_ground_speed(velocity)
	var vertical_speed : Vector3 = Vector3(0, velocity.y, 0)
	ground_speed = ground_speed.limit_length(max_speed)
	velocity = ground_speed + vertical_speed


## Gets the y-axis rotation between two 3D points
static func direction_to_y_angle(target: Vector3, origin: Vector3 = Vector3.ZERO) -> float:
	var direction = (target - origin)
	var y_rotation = Vector2(direction.z, direction.x).angle()
	return y_rotation


## Converts a Vector3D representing a point or direction into a Quaternion
## representing an angle around the Y axis.
static func quaternion_from_direction(direction: Vector3) -> Quaternion:
	return Quaternion(Vector3.UP, direction_to_y_angle(direction))


## Determines if two vectors point in roughly opposite directions.
## The default "sharpness" is any direction on the other side of a plane
## parrallel to the current_velocity.
static func is_sharp_turn(direction : Vector3, current_velocity : Vector3, sharpness: float = 0.0) -> bool:
	var dot = current_velocity.normalized().dot(direction.normalized())
	return dot < (0 - clamp(sharpness, -1, 1))


## Returns a slerped rotation to turn towards the direction of motion
static func rotate_toward_motion(current_rotation: Vector3, direction: Vector3, rate: float) -> Vector3:
	var q1 = quaternion_from_direction(direction)
	var q2 = Quaternion.from_euler(current_rotation).normalized()
	return q2.slerp(q1, rate).get_euler()


## Figures out the best side to view an action from, based on the camera's current position
static func get_best_side_view(normal: Vector3, camera_rig: CameraRig) -> float:
	var ccw = normal.rotated(Vector3.UP, PI/2).normalized()
	var cw = normal.rotated(Vector3.UP, -PI/2).normalized()
	var cam_direction = Vector3.FORWARD.rotated(Vector3.UP, camera_rig.rotation.y)

	if ((ccw - cam_direction).length_squared() > (cw - cam_direction).length_squared()):
		return Vector2(-ccw.z, -ccw.x).angle()
	else:
		return Vector2(-cw.z, -cw.x).angle()
