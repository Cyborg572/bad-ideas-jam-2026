class_name Platform
extends AnimatableBody3D

## A basic platform. To make it move add it to [class MovingPlatform] node.

signal boarded(passenger: Node3D, is_trigger: bool)
signal vacated()

@export_group("Triggered by", "trigger_by_")
@export var trigger_by_jack_in_the_box: bool = true
@export var trigger_by_jack: bool = true
@export var trigger_by_box: bool = false

@onready var trigger_zone: TriggerZone = %TriggerZone

func _ready() -> void:
	if trigger_zone:
		trigger_zone.trigger_by_jack_in_the_box = trigger_by_jack_in_the_box
		trigger_zone.trigger_by_jack = trigger_by_jack
		trigger_zone.trigger_by_box = trigger_by_box
		trigger_zone.trigger_by_throwable = false

		trigger_zone.triggered.connect(_on_trigger)
		trigger_zone.retriggered.connect(_on_retrigger)
		trigger_zone.untriggered.connect(_on_untriggered)


func _on_trigger(triggering_node: Node3D) -> void:
	boarded.emit(triggering_node, true)


func _on_retrigger(triggering_node: Node3D) -> void:
	boarded.emit(triggering_node, false)


func _on_untriggered() -> void:
	vacated.emit()


func has_passenger() -> bool:
	return trigger_zone.is_triggered


func get_passengers() -> Array[Node3D]:
	return trigger_zone.occupants
