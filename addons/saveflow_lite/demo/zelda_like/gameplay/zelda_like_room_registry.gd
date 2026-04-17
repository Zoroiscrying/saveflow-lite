extends Node

const WorldStateModelScript := preload("res://addons/saveflow_lite/demo/zelda_like/gameplay/zelda_like_world_state_model.gd")

var _state_model = null

var system_state: Dictionary:
	get:
		return export_save_data()
	set(value):
		import_save_data(value)


func _ready() -> void:
	if _state_model == null:
		_state_model = WorldStateModelScript.create_default()


func reset_state() -> void:
	_state_model = WorldStateModelScript.create_default()


func export_save_data() -> Dictionary:
	return _state_model.to_dictionary()


func import_save_data(data: Dictionary) -> void:
	_state_model = WorldStateModelScript.from_dictionary(data)


func set_active_room(room_id: String) -> void:
	_state_model.set_active_room(room_id)


func mark_enemy_defeated(room_id: String, persistent_id: String) -> void:
	_state_model.get_room_state_model(room_id).mark_enemy_defeated(persistent_id)


func is_enemy_defeated(room_id: String, persistent_id: String) -> bool:
	return bool(_state_model.get_room_state_model(room_id).defeated_enemies_set.get(persistent_id, false))


func mark_chest_opened(room_id: String, persistent_id: String) -> void:
	_state_model.get_room_state_model(room_id).mark_chest_opened(persistent_id)


func is_chest_opened(room_id: String, persistent_id: String) -> bool:
	return _state_model.get_room_state_model(room_id).opened_chests.has(persistent_id)


func register_delivery(room_id: String, delivery_id: String) -> void:
	_state_model.get_room_state_model(room_id).register_delivery(delivery_id)


func set_world_flag(flag_key: String, value: Variant) -> void:
	_state_model.set_world_flag(flag_key, value)


func get_room_state(room_id: String) -> Dictionary:
	return _state_model.get_room_state_model(room_id).to_dictionary()


func to_debug_string() -> String:
	return "active=%s loaded=%s flags=%s room_states=%s" % [
		_state_model.active_room_id,
		str(_state_model.loaded_room_ids),
		str(_state_model.world_flags),
		str(export_save_data().get("room_states", {})),
	]
