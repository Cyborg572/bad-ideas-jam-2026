extends SubViewportContainer

@onready var sub_viewport: SubViewport = $SubViewport

func resize_3D_display() -> void:
	print("Resizing!")
	var window_size := get_viewport().get_visible_rect().size
	sub_viewport.size = window_size

func _ready() -> void:
	resize_3D_display()
	get_viewport().size_changed.connect(resize_3D_display)
