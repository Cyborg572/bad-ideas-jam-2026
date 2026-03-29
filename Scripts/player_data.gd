class_name PlayerState
extends RefCounted

const SAVE_FILE = "user://bouncing_back.save"

var player_state: Dictionary = {}


func _init() -> void:
	creat_blank_player_state()


func creat_blank_player_state() -> void:
	player_state = {
		scene_path = "",
		total_gems = 0,
		current_world =  1,
		current_level = -2,
		gate_id = 0,
		worlds = {},
	}


func save_game() -> void:
	var file = FileAccess.open(SAVE_FILE, FileAccess.WRITE)
	file.store_line(JSON.stringify(player_state))


func has_saved_game() -> bool:
	return FileAccess.file_exists(SAVE_FILE)


func load_game() -> void:
	if not has_saved_game():
		return

	var file = FileAccess.open(SAVE_FILE, FileAccess.READ)
	var stringified_state = file.get_line()
	var save_data = JSON.parse_string(stringified_state)
	if save_data == null:
		push_error("Could not load save data")
		return

	creat_blank_player_state()
	player_state.scene_path = save_data.get("scene_path", 1)
	player_state.total_gems = save_data.get("total_gems", 0)
	player_state.current_world = save_data.get("current_world", 1)
	player_state.current_level = save_data.get("current_level", 0)
	player_state.gate_id = save_data.get("gate_id", 0)


	if "worlds" in save_data and save_data.worlds is Dictionary:
		var worlds: Dictionary = save_data.worlds
		for world_key in worlds:
			var world_id := int(world_key)
			var world: Dictionary = player_state.worlds.get_or_add(world_id, {})
			for level_key in worlds[world_key]:
				var level_id := int(level_key)
				var saved_level: Dictionary = worlds[world_key][level_key]

				var level: Dictionary = world.get_or_add(level_id, {})

				var saved_gems: Variant = saved_level.get("gems", [])
				level.gems = []
				if saved_gems is Array:
					for gem_id in saved_gems:
						level.gems.push_back(int(gem_id))

				level.mullberry_record = saved_level.get("mullberry_record", 0)
				level.mullberry_total = saved_level.get("mullberry_total", 0)

				level.gem_shards = []
				var saved_shards: Variant = saved_level.get("gem_shards", [])
				if saved_shards is Array:
					for shard_id in saved_shards:
						level.gem_shards.push_back(int(shard_id))

				level.secrets = []
				var saved_secrets: Variant = saved_level.get("secrets", [])
				if saved_secrets is Array:
					for secret_id in saved_secrets:
						level.secrets.push_back(str(secret_id))

				level.weasels = []
				var saved_weasels: Variant = saved_level.get("weasels", [])
				if saved_weasels is Array:
					for weasel_id in saved_weasels:
						level.weasels.push_back(str(weasel_id))


func set_scene_file_path(scene_path: String) -> void:
	player_state.scene_path = scene_path


func get_scene_file_path() -> String:
	return player_state.get("scene_path", "")


func get_active_gate_id() -> int:
	return player_state.get("gate_id", 0)


func set_active_gate_id(gate_id: int) -> void:
	player_state.set("gate_id", gate_id)


func set_current_level(world: int, level: int) -> void:
	player_state.current_world = world
	player_state.current_level = level


func get_current_level() -> LevelReference:
	var level_ref = LevelReference.new(
		player_state.current_world as int,
		player_state.current_level as int,
	)

	return level_ref


func get_level_data(ref: LevelReference = get_current_level()) -> LevelData:
	var level_data := LevelData.new()
	level_data.ref = ref

	var level_state: Dictionary = (player_state.worlds
		.get_or_add(ref.world, {})
		.get_or_add(ref.level, {})
	)

	level_data.state = level_state

	return level_data


class LevelReference:
	var world: int = 0
	var level: int = 0

	func _init(new_world: int, new_level: int) -> void:
		world = new_world
		level = new_level


class LevelData:
	var ref: LevelReference
	var state: Dictionary

	func set_mullberry_record(count: int) -> void:
		if count > get_mullberry_record():
			state.set("mullberry_record", count)


	func get_mullberry_record() -> int:
		return state.get_or_add("mullberry_record", 0)


	func set_mullberry_total(count: int) -> void:
		state.set("mullberry_count", count)


	func get_mullberry_total() -> int:
		return state.get_or_add("mullberry_count", 0)


	func is_gem_collected(gem_id: Gem.GemID) -> bool:
		return state.get_or_add("gems", []).has(gem_id)


	func collect_gem(gem_id: Gem.GemID):
		var gems: Array = state.get_or_add("gems", [])
		if not gems.has(gem_id):
			gems.push_back(gem_id)


	func is_gem_shard_collected(gem_shard_id: GemShard.ShardId) -> bool:
		return state.get_or_add("gem_shards", []).has(gem_shard_id)


	func collect_gem_shard(gem_shard_id: GemShard.ShardId):
		var gem_shards: Array = state.get_or_add("gem_shards", [])
		if not gem_shards.has(gem_shard_id):
			gem_shards.push_back(gem_shard_id)


	func is_secret_discovered(secret_id: String) -> bool:
		return state.get_or_add("secrets", []).has(secret_id)


	func discover_secret(secret_id: String):
		var secrets: Array = state.get_or_add("secrets", [])
		if not secrets.has(secret_id):
			secrets.push_back(secret_id)


	func is_weasel_done(weasel_id: String) -> bool:
		return state.get_or_add("weasels", []).has(weasel_id)


	func finish_weasel(weasel_id: String):
		var weasels: Array = state.get_or_add("weasels", [])
		if not weasels.has(weasel_id):
			weasels.push_back(weasel_id)
