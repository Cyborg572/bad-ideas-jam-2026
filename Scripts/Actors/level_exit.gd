@tool
class_name LevelExit
extends Node3D

## The ID for this exit when used as a spawn point.
@export var gate_id: int = 0
@export_group("Destination", "destination_")
@export_file("*.world.tscn") var destination_world : String = "uid://dord8un54pu4n"
@export var destination_gate: int = 0

@export_group("Locked", "lock_")
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "") var lock_enabled : bool = false
@export var lock_gem_count : int = 0

@export_group("Sign", "sign_")
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "") var sign_enabled : bool = false
@export var sign_image : Texture2D:
	set(new_image):
		sign_image = new_image
		if signpost and signpost.is_node_ready():
			signpost.image = sign_image

var is_open = false

@onready var lock_trigger: TriggerZone = $LockTrigger
@onready var exit_trigger: TriggerZone = $ExitTrigger
@onready var door: CollisionShape3D = $Door/Blocker
@onready var signpost: Sign = $signpost
@onready var anim: AnimationTree = $AnimationTree


func _ready() -> void:
	if sign_enabled:
		signpost.enable()
		if not sign_image == null:
			signpost.change_image(sign_image)
	else:
		signpost.disable()

	anim.active = true

	if not lock_enabled:
		door.disabled = true

	if not Engine.is_editor_hint():
		lock_trigger.triggered.connect(_on_lock_triggered)
		lock_trigger.untriggered.connect(_on_lock_untriggered)
		exit_trigger.triggered.connect(_on_exit_triggered)


func _on_lock_triggered(_by: Node3D) -> void:
	print("Triggered! Checking lock...")
	if not lock_enabled:
		print("Not locked. Opening")
		open()
	else:
		print("Locked.")


func _on_lock_untriggered() -> void:
	print("Closing.")
	close()


func _on_exit_triggered(_by: Node3D) -> void:
	GameManager.change_level(destination_world, destination_gate)


func open(fast: bool = false) -> void:
	is_open = true
	door.disabled = true
	if (fast):
		anim.get("parameters/playback").travel("fast_unlock", true)


func close(fast: bool = false) -> void:
	is_open = false
	door.disabled = false
	if (fast):
		anim.get("parameters/playback").travel("fast_lock", true)
