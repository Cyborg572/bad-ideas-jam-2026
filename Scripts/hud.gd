class_name Hud
extends MarginContainer

@onready var distance_guage: Label = %DistanceGuage
@onready var healthbar: TextureProgressBar = %Healthbar
@onready var confidence_meter: ProgressBar = %ConfidenceMeter

var distance : float = 0.0

var health : int = 5
var max_health : int = 5

var confidence : float = 50.0


func _ready() -> void:
	health = 5
	max_health = 5
	GameManager.player_health_changed.connect(_on_health_changed)

	confidence_meter.value = 50.0
	confidence = 50.0
	GameManager.player_confidence_changed.connect(_on_confidence_changed)

	distance_guage.text = format_distance(GameManager.distance_to_box)
	distance = GameManager.distance_to_box
	GameManager.distance_to_box_changed.connect(_on_distance_changed)


func format_distance(dist: float) -> String:
	if dist < 9:
		return "%02dm" % dist
	else:
		return "%dm" % dist


func _process(_delta: float) -> void:
	# Update health
	healthbar.value = health

	# Update confidence
	confidence_meter.value = move_toward(confidence_meter.value, confidence, 1)

	# Update Distance
	distance_guage.text = format_distance(distance)
	if distance > 30:
		distance_guage.modulate = Color("#ED708A")
	elif distance > 15:
		distance_guage.modulate = Color("#FFB378")
	else:
		distance_guage.modulate = Color.WHITE


func _on_health_changed(new_health: int, new_max: int) -> void:
	max_health = new_max
	health = new_health


func _on_confidence_changed(new_value: float) -> void:
	print("Confidence now %f", new_value)
	confidence = new_value


func _on_distance_changed(new_value: float) -> void:
	distance = new_value
