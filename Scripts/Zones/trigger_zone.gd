class_name TriggerZone
extends Area3D

signal triggered(triggering_node: Node3D)
signal retriggered(triggering_node: Node3D)
signal untriggered()

@export var chime: bool = false
@export var single_use: bool = false

@export_group("Triggered by", "trigger_by_")
@export var trigger_by_jack_in_the_box: bool = true
@export var trigger_by_jack: bool = true
@export var trigger_by_box: bool = false
@export var trigger_by_throwable: bool = false
@export var trigger_by_throwable_min : int = 0
@export var trigger_by_throwable_max : int = 0

var is_triggered : bool = false
var occupants : Array[Node3D] = []


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Give other nodes a chance to adjust the trigger settings
	update_trigger_settings.call_deferred()


func _on_body_entered(body: Node3D) -> void:
	# Regardless of trigger state, track potentially valid occupants
	if not occupants.has(body):
		occupants.push_back(body)

	if body is Jack and body.has_the_box() and not occupants.has(body.box):
		occupants.push_back(body.box)

	check_trigger_condition()



func _on_body_exited(body: Node3D) -> void:
	if body is Jack and body.has_the_box() and occupants.has(body.box):
		occupants.erase(body.box)

	# Weird edge case of jack picking up the box in the zone. Do nothing.
	if body is TheBox and GameManager.jack.has_the_box() and occupants.has(GameManager.jack):
		pass
	elif occupants.has(body):
		occupants.erase(body)

	# Re-check the trigger
	check_trigger_condition()


func check_trigger_condition() -> void:
	var jack: Jack = GameManager.jack
	var the_box: TheBox = jack.box
	var jack_is_here: bool = occupants.has(jack)
	var the_box_is_here: bool = occupants.has(the_box)
	var has_player_objects: bool = false
	var has_throwables: bool = false

	# Jack or the box can trigger
	if trigger_by_jack or trigger_by_box or trigger_by_jack_in_the_box:
		has_player_objects = (
			(trigger_by_jack_in_the_box and jack_is_here and the_box_is_here)
			or (trigger_by_jack and jack_is_here and not the_box_is_here)
			or (trigger_by_box and the_box_is_here and not jack_is_here)
		)

	if trigger_by_throwable:
		var throwable_count: int = 0
		for occupant in occupants:
			if occupant is Attachable and not occupant is TheBox:
				throwable_count += 1
		has_throwables = throwable_count > 0 and (
			(throwable_count >= trigger_by_throwable_min)
			and (trigger_by_throwable_max == 0 or throwable_count <= trigger_by_throwable_max)
		)

	if has_player_objects or has_throwables:
		trigger()
	else:
		untrigger()


func trigger() -> void:
	var triggerer: Node3D = occupants.back()
	if not is_triggered:
		is_triggered = true
		if chime:
			GameManager.achieve_goal()
		triggered.emit(triggerer)
	else:
		retriggered.emit(triggerer)


func untrigger() -> void:
	if is_triggered and not single_use:
		is_triggered = false
		untriggered.emit()


func update_trigger_settings() -> void:
	# Configure the collision mask and layers
	collision_layer = 0
	collision_mask = 0

	var need_player_collisions = trigger_by_jack or trigger_by_box or trigger_by_jack_in_the_box
	set_collision_mask_value(3, need_player_collisions)
	set_collision_mask_value(7, need_player_collisions)
	set_collision_mask_value(8, trigger_by_throwable)


func has_occupants() -> bool:
	return not occupants.is_empty()
