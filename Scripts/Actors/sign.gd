@tool
class_name Sign
extends StaticBody3D


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

func _ready() -> void:
	if message_enabled:
		interaction_point.enable()
	else:
		interaction_point.disable()

	display = model.get_surface_override_material(2)
	display.albedo_texture = image


func change_image(new_image: Texture2D) -> void:
	image = new_image
	display.albedo_texture = image
