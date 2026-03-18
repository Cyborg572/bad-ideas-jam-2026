class_name ConfidenceZone
extends Area3D
## Defines a zone that can modify the players confidence

enum AdjustmentType {
	## No adjustment will be made
	NONE,

	## The value will be added to the current confidence score
	ADD,

	## The value will be subtracted from the current confidence score
	SUBTRACT,

	## The current confidence score will be multiplied by the value
	MULTIPLY,

	## The current confidence score will be divided by the value
	DIVIDE
}

## When in this zone, turn off the default, automatic tick down of confidence
@export var prevent_loss: bool = false

## Only applies the bonus once (and then destroys itself)
@export var single_use: bool = false

@export_subgroup("Adjust on Enter", "enter_")

## The type of adjustment to apply when the player enters the zone
@export var enter_type: AdjustmentType = AdjustmentType.NONE

## The amount to adjust by
@export var enter_amount: int = 0

## How many seconds after leaving until the adjustment can apply again.
@export_range(0.0, 15.0, 0.25, "or_greater", "suffix:s") var enter_cooldown: float = 0.0

@export_subgroup("Adjust on Exit", "exit_")

## The type of adjustment to apply when the player leaves the zone
@export var exit_type: AdjustmentType = AdjustmentType.NONE

## The amount to adjust by
@export var exit_amount: int = 0

## How many seconds after leaving until the adjustment can apply again.
@export_range(0, 15, 0.1, "or_greater", "suffix:s") var exit_cooldown: float = 0.0

@export_subgroup("Constant adjustment", "constant_")

## The type of adjustment to apply while the player is in the zone
@export var constant_type: AdjustmentType = AdjustmentType.NONE

## The amount to adjust by
@export var constant_amount: int = 0

## How frequently to apply the adjustment, in "confidence ticks".[br]
## The confidence meter has a default tick frequency, higher values here "skip" some of those ticks.
@export_range(0, 5, 1, "hide_control", "or_greater", "suffix:ticks")
var constant_frequency: int = 0

## True when the enter adjustment is on a cooldown pause
var enter_on_cooldown: bool = false

## True when the exit adjustment is on a cooldown pause
var exit_on_cooldown: bool = false

## Track ticks between constant adjustments
var constant_adjustment_ticks: int = 0

@onready var enter_cooldown_timer: Timer = Timer.new()
@onready var exit_cooldown_timer: Timer = Timer.new()

func _ready() -> void:
	# Configure the collision mask and layers
	collision_layer = 2 # Layer 2(2)
	collision_mask = 4 # Layer 3(4)

	# Wire up the signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Set up the needed timers
	if enter_cooldown > 0:
		enter_cooldown_timer.wait_time = enter_cooldown
		enter_cooldown_timer.one_shot = true
		enter_cooldown_timer.timeout.connect(stop_enter_cooldown)
		add_child(enter_cooldown_timer)

	if exit_cooldown > 0:
		exit_cooldown_timer.wait_time = exit_cooldown
		exit_cooldown_timer.one_shot = true
		exit_cooldown_timer.timeout.connect(stop_exit_cooldown)
		add_child(exit_cooldown_timer)


func _on_body_entered(body: Node3D) -> void:
	if not body is Jack:
		return

	if not enter_on_cooldown:
		start_enter_cooldown()
		apply_adjustment(enter_type, enter_amount)

	constant_adjustment_ticks = 0

	add_to_group("Confidence Zones")


func _on_body_exited(body: Node3D) -> void:
	if not body is Jack:
		return

	if not exit_on_cooldown:
		start_exit_cooldown()
		apply_adjustment(exit_type, exit_amount)

	if enter_cooldown > 0 and not enter_on_cooldown:
		enter_cooldown_timer.start()

	if exit_cooldown > 0 and not exit_on_cooldown:
		exit_cooldown_timer.start()

	remove_from_group("Confidence Zones")

	if single_use:
		queue_free()


func start_enter_cooldown() -> void:
	if enter_cooldown > 0:
		enter_on_cooldown = true
		enter_cooldown_timer.start()


func stop_enter_cooldown() -> void:
	enter_on_cooldown = false


func start_exit_cooldown() -> void:
	if exit_cooldown > 0:
		exit_on_cooldown = true
		exit_cooldown_timer.start()


func stop_exit_cooldown() -> void:
	exit_on_cooldown = false


func apply_adjustment(type: AdjustmentType, amount: int) -> void:
	match type:
		AdjustmentType.ADD:
			GameManager.player_confidence += amount
		AdjustmentType.SUBTRACT:
			GameManager.player_confidence -= amount
		AdjustmentType.MULTIPLY:
			GameManager.player_confidence *= amount
		AdjustmentType.DIVIDE:
			GameManager.player_confidence /= amount
		AdjustmentType.NONE, _:
			pass


func apply_constant_adjustment() -> void:
	constant_adjustment_ticks = clamp(constant_adjustment_ticks + 1, 1, constant_frequency)
	if constant_adjustment_ticks == constant_frequency:
		apply_adjustment(constant_type, constant_amount)
