class_name FlipSwitch
extends Node3D

signal triggered(by: Node3D)
signal untriggered

## Start "on"
@export var start_triggered: bool = false

## If true, the player can't unflip the switch
@export var single_use: bool = false

## Will reset to starting state after a set time. Single-use switches will
## become usable again
@export_range(0.0, 30.0, 0.1, "or_greater", "suffix:s") var time_limit: float = 0.0

## Play the success noise when flipped
@export var chime: bool = false

var timer := Timer.new()
var is_triggered: bool = false

@onready var interaction_point: InteractionPoint = $InteractionPoint

func _ready() -> void:
	if time_limit > 0:
		add_child(timer)
		timer.wait_time = time_limit
		timer.timeout.connect(restore_start_state)

	interaction_point.interaction.connect(_on_interaction)
	restore_start_state()


func _on_interaction(point: InteractionPoint) -> void:
	toggle()
	if single_use:
		point.disable.call_deferred()


func start_timer() -> void:
	if time_limit > 0:
		timer.start()


func stop_timer() -> void:
	timer.stop()


func toggle() -> void:
	if is_triggered:
		untrigger()
	else:
		trigger()


func restore_start_state() -> void:
	if start_triggered:
		trigger()
	else:
		untrigger()
	interaction_point.enable.call_deferred()


func trigger(by: Node3D = self) -> void:
	is_triggered = true
	if not start_triggered:
		start_timer()
		if chime:
			GameManager.achieve_goal()
	else:
		stop_timer()
	triggered.emit(by)


func untrigger() -> void:
	is_triggered = false
	if start_triggered:
		start_timer()
		if chime:
			GameManager.achieve_goal()
	else:
		stop_timer()
	untriggered.emit()
