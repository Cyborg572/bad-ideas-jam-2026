class_name HintViewer
extends PanelContainer

const PASSIVE_HINT_DURATION = -1

enum Controls {
	INTERACT,
	ATTACK,
	CAMERA,
	CROUCH,
	JUMP,
	MOVE,
	POP,
	RESET_CAMERA,
}

var icons: Dictionary[Controls, Texture2D] = {
	Controls.INTERACT: preload("uid://bgjdc7yufkx2b"),
	Controls.ATTACK: preload("uid://dj2447ogiv7uu"),
	Controls.CAMERA: preload("uid://djjyimop6ede"),
	Controls.CROUCH: preload("uid://c2ek25tp7eefa"),
	Controls.JUMP: preload("uid://b7ihetfpbwstl"),
	Controls.MOVE: preload("uid://cssouid7kvvf5"),
	Controls.POP: preload("uid://cij6pnk1xsmet"),
	Controls.RESET_CAMERA: preload("uid://d0tgpfr0sipv3"),
}

@onready var hint_control: TextureRect = %hintControl
@onready var hint_message: HBoxContainer = %HintMessage
@onready var hint_text: Label = %hintText
@onready var hint_timer: Timer = %HintTimer

var is_hint_showing: bool = false
var hints: Array = []
var current_hint: Hint


func _ready() -> void:
	hint_timer.timeout.connect(display_next_hint)


func _process(_delta: float) -> void:
	if GameManager.dialog_viewer.visible:
		if is_hint_showing:
			print("Stashing hint")
			hints.push_front(current_hint)
			print("The stash: ", hints)
			disappear()
			hint_timer.stop()
	else:
		if not is_hint_showing and not hints.is_empty():
			print("showing")
			display_next_hint()



func appear() -> void:
	is_hint_showing = true
	hint_message.modulate = Color(1,1,1,1)
	modulate = Color(1, 1, 1, 0)
	show()
	var fade_in = create_tween()
	fade_in.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.25)
	await fade_in.finished


func disappear() -> void:
	is_hint_showing = false
	var fade_out = create_tween()
	fade_out.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.25)
	await fade_out.finished
	hide()


func show_hint(hint: Hint, force:bool = false) -> void:
	var should_force = (
		force or (
			(current_hint and current_hint.duration == PASSIVE_HINT_DURATION)
			and not hint.duration == PASSIVE_HINT_DURATION
		)
	)

	if is_hint_showing and should_force:
		hints.push_front(current_hint)
		hints.push_front(hint)
		display_next_hint()
		return

	hints.push_back(hint)
	if not is_hint_showing:
		display_next_hint()


func remove_hint(hint: Hint) -> void:
	if hint == current_hint and is_hint_showing:
		display_next_hint()
		return

	hints.erase(hint)


func display_next_hint() -> void:
	var next_hint = hints.pop_front()

	if next_hint == null:
		disappear()
		hint_timer.stop()
		return

	if is_hint_showing:
		var fade_out_current = create_tween()
		fade_out_current.tween_property(hint_message, "modulate", Color(1, 1, 1, 0), 0.25)
		await fade_out_current.finished

	current_hint = next_hint
	hint_control.texture = icons[next_hint.control]
	hint_text.text = next_hint.text
	if next_hint.duration == PASSIVE_HINT_DURATION:
		hint_timer.wait_time = 15.0
		hint_timer.stop()
	else:
		hint_timer.wait_time = next_hint.duration
		hint_timer.start()

	if not is_hint_showing:
		hint_timer.start()
		await appear()
	else:
		var fade_in_next = create_tween()
		fade_in_next.tween_property(hint_message, "modulate", Color(1, 1, 1, 1), 0.25)


class Hint:
	var control: Controls = Controls.INTERACT
	var text: String = "Interact"
	var duration: float = 15.0

	func _init(new_control: Controls, new_text: String, new_duration: float = 15.0) -> void:
		control = new_control
		text = new_text
		duration = new_duration
