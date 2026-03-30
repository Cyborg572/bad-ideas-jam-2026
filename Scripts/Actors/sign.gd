@tool
class_name Sign
extends StaticBody3D

@export var enabled : bool = true

@export var image : Texture2D:
	set(new_image):
		image = new_image
		if is_node_ready():
			display.albedo_texture = image

@export_group("Show Message", "message_")
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "") var message_enabled: bool = false
@export_multiline() var message_text: String = ""

var display : Material

@onready var model: MeshInstance3D = $Cylinder
@onready var interaction_point: InteractionPoint = $InteractionPoint
@onready var collision_shape_3d: CollisionShape3D = $CollisionShape3D

func _ready() -> void:
	if message_enabled:
		interaction_point.enable()
		interaction_point.interaction.connect(_on_interaction)
	else:
		interaction_point.disable()

	if enabled:
		enable()
	else:
		disable()

	display = model.get_surface_override_material(2)
	display.albedo_texture = image


func _on_interaction(_point: InteractionPoint) -> void:
	GameManager.show_message(image, message_text)


func change_image(new_image: Texture2D) -> void:
	image = new_image
	display.albedo_texture = image


func disable() -> void:
	hide()
	collision_shape_3d.disabled = true
	interaction_point.disable()


func enable() -> void:
	show()
	collision_shape_3d.disabled = false
	if message_enabled:
		interaction_point.enable()
