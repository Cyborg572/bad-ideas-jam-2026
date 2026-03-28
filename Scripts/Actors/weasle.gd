class_name Weasle
extends Node3D

## A unique name for this weasel, used to prevent re-appearance
@export var weasel_id: String = ""
## If checked, this weasel is gone after it disappears
@export var one_shot: bool = false
## If checked, the weasel will hide on it's own after talking.
@export var hide_automaticaly = false
## If checked, the weasel will start the conversation as soon as it appears
@export var force_conversation = true

@export_multiline() var message_text: String = ""

var hiding : bool = true
var chatting : bool = false

@onready var interaction_point: InteractionPoint = $InteractionPoint
@onready var trigger_zone: Area3D = $TriggerZone
@onready var vanish_timer: Timer = $vanishTimer
@onready var anim: AnimationTree = $AnimationTree


func _ready() -> void:
	anim.active = true
	disappear()

	add_to_group("weasels")

	trigger_zone.collision_layer = 0
	trigger_zone.collision_mask = 0
	trigger_zone.set_collision_mask_value(3, true)
	trigger_zone.body_entered.connect(_on_body_entered)
	trigger_zone.body_exited.connect(_on_body_exited)

	interaction_point.interaction.connect(_on_interaction)

	vanish_timer.timeout.connect(disappear)


func _process(_delta: float) -> void:
	if not GameManager.jack == null:
		look_at(GameManager.jack.position, Vector3.UP, true)
		rotation.x = 0
		rotation.z = 0


func _on_interaction(_point: InteractionPoint) -> void:
	# TODO: Actually open a dialog. This is just to test animations
	chatting = not chatting


func _on_body_entered(body: Node3D) -> void:
	if body is Jack:
		vanish_timer.stop()
		appear()


func _on_body_exited(body: Node3D) -> void:
	if body is Jack:
		vanish_timer.start()


func appear() -> void:
	get_tree().call_group("weasels", "disappear")
	hiding = false
	interaction_point.disabled = false



func disappear() -> void:
	hiding = true
	chatting = false
	interaction_point.disabled = true
