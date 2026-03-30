class_name Level
extends Node3D

@export var title : String = "A Level"
@export var world : int = 1
@export var level_number : int


@export var spawn_point : Node3D = null

## A level exit gate to use as the entrance instead of the spawn point
@export var entrance_gate: int = 0


@export_group("Audio")
@export var ambient_noise : AudioStream
@export var background_music : AudioStream
@export var cranking_sound : AudioStream


var level_reference: PlayerState.LevelReference
var level_state: PlayerState.LevelData
var collected_mullberries: int = 0


func _ready() -> void:
	level_reference = PlayerState.LevelReference.new(world, level_number)
	level_state = GameManager.game_state.get_level_data(level_reference)
	if GameManager.game_state.get_active_gate_id() != 0:
		entrance_gate = GameManager.game_state.get_active_gate_id()

	var berries = get_tree().get_nodes_in_group("berries")
	level_state.set_mullberry_total(berries.size())
	for berry in berries:
		if berry is Mullberry:
			berry.collected.connect(_on_mullberry_collected)


func get_title() -> String:
	if level_number > 0:
		return "%d-%d: %s" % [world, level_number, title]
	return title


func get_active_spawn_point(_use_checkpoint: bool = true) -> Node3D:
	return get_gate_by_id(entrance_gate)


func get_gate_by_id(gate_id: int) -> Variant:
	var default = self if spawn_point == null else spawn_point
	if gate_id == 0:
		return default

	var gates: Array[Node] = get_tree().get_nodes_in_group("level_gates")
	for gate in gates:
		if gate is LevelExit:
			if gate.gate_id == gate_id:
				return gate

	return default


func _on_mullberry_collected() -> void:
	collected_mullberries += 1
	level_state.set_mullberry_record(collected_mullberries)
