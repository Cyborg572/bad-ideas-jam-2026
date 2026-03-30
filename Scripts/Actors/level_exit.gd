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

	GameManager.level_ready.connect(_on_level_ready, CONNECT_ONE_SHOT)


func _on_level_ready(_level: Level) -> void:
	if is_locked():
		close()


func _on_lock_triggered(_by: Node3D) -> void:
	if not is_locked():
		open()


func _on_lock_untriggered() -> void:
	close()


func _on_exit_triggered(_by: Node3D) -> void:
	GameManager.change_level(destination_world, destination_gate)


func is_locked() -> bool:
	if not lock_enabled:
		return false

	if not GameManager.active_level.level_state.is_gem_collected(Gem.GemID.GEM_1):
		return true

	if GameManager.game_state.player_state.total_gems < lock_gem_count:
		return true

	return false


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
