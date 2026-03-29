class_name Gem
extends Attachable

signal claimed

enum GemID {
	NONE,
	GEM_1,
	GEM_2,
	GEM_3,
}

@export var gem_id: GemID = GemID.NONE


func claim() -> void:
	GameManager.active_level.level_state.collect_gem(gem_id)
	claimed.emit()
	queue_free()
