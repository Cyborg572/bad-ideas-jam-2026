@tool
class_name InteractionPoint
extends Area3D

signal interaction(interaction_point: InteractionPoint)

@export var sticky : bool = false
@export var pointer_position : Vector3 = Vector3.UP
@export var show_pointer_reference : bool = true

var active : bool = false
var pointer_refence : MeshInstance3D

func get_global_pointer_position() -> Vector3:
	return global_position + pointer_position

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if Engine.is_editor_hint():
		pointer_refence = MeshInstance3D.new()
		pointer_refence.mesh = BoxMesh.new()
		pointer_refence.mesh.size = Vector3(0.1, 0.1, 0.1)
		self.add_child(pointer_refence, false, Node.INTERNAL_MODE_FRONT)
		

	# Connect the signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Configure the collision mask and layers
	collision_layer = 3 # Layers 1(1) and 2(2) 
	collision_mask = 4 # Layer 3(4)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		pointer_refence.position = pointer_position
		pointer_refence.visible = show_pointer_reference


func interact() -> void:
	interaction.emit(self)


func activate() -> void:
	active = true


func deactivate() -> void:
	active = false


func _on_body_entered(_body: Node3D) -> void:
	GameManager.set_active_interaction_point(self)


func _on_body_exited(_body: Node3D) -> void:
	GameManager.clear_active_interaction_point(self)
