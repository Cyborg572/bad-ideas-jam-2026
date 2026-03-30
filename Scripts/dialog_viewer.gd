class_name DialogViewer
extends PanelContainer

@onready var dialog_portrait: TextureRect = %DialogPortrait
@onready var dialog_text: RichTextLabel = %DialogText

@onready var dialog_continue: Button = %DialogContinue

func show_message(image: Texture2D, message: String) -> void:
	dialog_portrait.texture = image
	dialog_text.text = message

	show()
	dialog_continue.grab_focus.call_deferred()
	await dialog_continue.pressed
	hide()
