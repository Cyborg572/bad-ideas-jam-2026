extends Node3D


@onready var pain_sounds: AudioStreamPlayer3D = $PainSounds
@onready var jump_sounds: AudioStreamPlayer3D = $JumpSounds
@onready var falling_sounds: AudioStreamPlayer3D = $FallingSounds
@onready var box_loss_sounds: AudioStreamPlayer3D = $BoxLossSounds
@onready var nervous_sounds: AudioStreamPlayer3D = $NervousSounds
@onready var panic_sounds: AudioStreamPlayer3D = $PanicSounds
@onready var success_sounds: AudioStreamPlayer3D = $SuccessSounds


func _ready() -> void:
	GameManager.player_damaged.connect(play_hurt_sound)
	GameManager.player_rewarded.connect(_on_player_rewarded)
	GameManager.player_confidence_changed.connect(_on_confidence_changed)
	GameManager.player_confidence_lost.connect(play_panic_sound)


func _on_player_rewarded(amount: float) -> void:
	print("Player earned: ", amount)
	var odds: int = 100

	if amount > 5:
		odds = 1
	elif amount >= 3:
		odds = 40
	else:
		return

	print("Odds are ", odds)
	if randi() % odds == 0:
		print("play it!")
		play_success_sound()
	else:
		print("meh")


func _on_confidence_changed(new: float, old: float) -> void:
	# Gaining and fully losing confidence are handled elsewhere
	if new == 0 or old < new:
		return

	var difference: float = old - new
	var odds: int = 100
	if difference > 10:
		odds = 1
	elif difference > 4:
		odds = 2
	elif difference > 2:
		odds = 3
	elif difference > 0.5:
		odds = 10
	else:
		return

	if randi() % odds == 0:
		play_nervous_sound()


func play_hurt_sound() -> void:
	pain_sounds.play()


func play_jump_sound() -> void:
	jump_sounds.play()


func play_falling_sound() -> void:
	falling_sounds.play()


func play_box_loss_sound() -> void:
	box_loss_sounds.play()


func play_nervous_sound() -> void:
	nervous_sounds.play()


func play_panic_sound() -> void:
	panic_sounds.play()


func play_success_sound() -> void:
	success_sounds.play()
