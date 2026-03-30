extends Node

enum Stage {
	WAITING,
	BASIC_BOX_MOVEMENT,
	CAMERA_CONTROL,
	DETACH,
	POP_TO,
}

var progress: Dictionary[Stage, bool] = {}

var hint_viewer = GameManager.hint_viewer
var current_stage: Stage = Stage.WAITING

var H := HintViewer.Hint
var controls := HintViewer.Controls

var hints: Dictionary[String, HintViewer.Hint] = {
	boxed_jump = H.new(controls.JUMP, "Hold and release to charge a jump", 5),
	boxed_jump_move = H.new(controls.MOVE, "Move while jumping", 10),
	crouch = H.new(controls.CROUCH, "Crouch"),
	recenter_camera = H.new(controls.RESET_CAMERA, "Re-center camera", 10),
	switch_to_carry = H.new(controls.POP, "Get in and out of The Box"),
	free_move = H.new(controls.MOVE, "Run", 5),
	free_jump = H.new(controls.JUMP, "Jump", 5),
	easy_in = H.new(controls.CROUCH, "Hide in The Box",5),
	drop_box = H.new(controls.INTERACT, "Pick up or drop The Box",5),
	pop_to_box = H.new(controls.POP, "Tap to look towards and open or close The Box, Hold to go to The Box"),
	deposit_gem = H.new(controls.INTERACT, "Deposit Gem"),
}


func _ready() -> void:
	GameManager.level_ready.connect(_on_start_tutorial, CONNECT_ONE_SHOT)


func _process(_delta: float) -> void:
	match current_stage:
		Stage.BASIC_BOX_MOVEMENT:
			if Input.is_action_just_released("Jump"):
				hint_viewer.remove_hint(hints.boxed_jump)
		Stage.CAMERA_CONTROL:
			if Input.is_action_just_pressed("camera_reset"):
				hint_viewer.remove_hint(hints.recenter_camera)
				progress[Stage.CAMERA_CONTROL] = true
				current_stage = Stage.WAITING
		Stage.DETACH:
			if Input.is_action_just_pressed("Pop") and not progress.get(Stage.DETACH, false):
				progress[Stage.DETACH] = true
				hint_viewer.show_hint(hints.free_move)
				hint_viewer.show_hint(hints.free_jump)
				hint_viewer.show_hint(hints.easy_in)
				hint_viewer.show_hint(hints.drop_box)
				hint_viewer.remove_hint(hints.switch_to_carry)

	if GameManager.jack:
		if GameManager.jack.distance_to_box > 1 and not progress.get(Stage.POP_TO, false):
			hint_viewer.show_hint(hints.pop_to_box)
		else:
			hint_viewer.remove_hint(hints.pop_to_box)

	if (
		Input.is_action_just_pressed("Crouch")
		and GameManager.jack.is_carrying
		and GameManager.jack.is_boxed
	):
		hint_viewer.show_hint(hints.deposit_gem)


func _on_start_tutorial(level: Level) -> void:
	if level.level_state.is_gem_collected(Gem.GemID.GEM_1):
		queue_free()
		return

	await GameManager.jack.popped
	$"../Weasels/IntroWeasel".chat()
	GameManager.jack.popped.connect(_on_jack_popped, CONNECT_ONE_SHOT)


func _on_jack_popped(_the_box: TheBox) -> void:
	progress[Stage.POP_TO] = true
	hint_viewer.remove_hint(hints.pop_to_box)


func _on_intro_weasel_chat_finished() -> void:
	current_stage = Stage.BASIC_BOX_MOVEMENT
	hint_viewer.show_hint(hints.boxed_jump)
	hint_viewer.show_hint(hints.boxed_jump_move)
	$"../Weasels/ExpoWeasel".appear()


func _on_movement_learning_zone_body_exited(body: Node3D) -> void:
	if not body is Jack:
		return

	if current_stage == Stage.BASIC_BOX_MOVEMENT:
		progress[Stage.BASIC_BOX_MOVEMENT] = true
		hint_viewer.remove_hint(hints.boxed_jump)
		hint_viewer.remove_hint(hints.boxed_jump_move)
		current_stage = Stage.WAITING


func _on_crouch_learning_zone_body_entered(body: Node3D) -> void:
	if not body is Jack:
		return

	hint_viewer.show_hint(hints.crouch)


func _on_crouch_learning_zone_body_exited(body: Node3D) -> void:
	if not body is Jack:
		return

	hint_viewer.remove_hint(hints.crouch)


func _on_expo_weasel_chat_finished() -> void:
	$"../Weasels/ExpoWeasel2".appear()


func _on_expo_weasel_2_chat_finished() -> void:
	current_stage = Stage.CAMERA_CONTROL
	hint_viewer.show_hint(hints.recenter_camera)


func _on_detach_weasel_chat_finished() -> void:
	current_stage = Stage.DETACH
	hint_viewer.show_hint(hints.switch_to_carry)
