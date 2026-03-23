class_name LevelExit
extends Node3D

@export var destination : PackedScene

@export_group("Locked", "lock_")
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "") var lock_enabled : bool = false
@export var lock_gem_count : int = 0

@export_group("Sign", "sign_")
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "") var sign_enabled : bool = false
@export var sign_image : Texture2D

var is_open = false

@onready var lock_trigger: TriggerZone = $LockTrigger
@onready var exit_trigger: TriggerZone = $ExitTrigger
@onready var door: CollisionShape3D = $Door/Blocker
@onready var signpost: StaticBody3D = $signpost
@onready var anim: AnimationTree = $AnimationTree


func _ready() -> void:
	if sign_enabled:
		signpost.show()
	else:
		signpost.hide()

	anim.active = true

	if not lock_enabled:
		door.disabled = true

	lock_trigger.triggered.connect(_on_lock_triggered)
	lock_trigger.untriggered.connect(_on_lock_untriggered)


func _on_lock_triggered(_by: Node3D) -> void:
	print("Triggered! Checking lock...")
	if not lock_enabled:
		print("Not locked. Opening")
		is_open = true
	else:
		print("Locked.")


func _on_lock_untriggered() -> void:
	print("Closing.")
	is_open = false
