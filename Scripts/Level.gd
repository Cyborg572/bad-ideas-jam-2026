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


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


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
