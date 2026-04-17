class_name ZeldaLikeWorldStateModel
extends RefCounted

const RoomStateModelScript := preload("res://addons/saveflow_lite/demo/zelda_like/gameplay/zelda_like_room_state_model.gd")

var active_room_id := "room_hub"
var loaded_room_ids: PackedStringArray = PackedStringArray(["room_hub"])
var world_flags: Dictionary = {}
var room_states: Dictionary = {}


static func create_default():
	var model := ZeldaLikeWorldStateModel.new()
	model.reset_to_defaults()
	return model


static func from_dictionary(data: Dictionary):
	var model := ZeldaLikeWorldStateModel.new()
	model.apply_dictionary(data)
	return model


func reset_to_defaults() -> void:
	active_room_id = "room_hub"
	loaded_room_ids = PackedStringArray(["room_hub"])
	world_flags = {
		"boss_key_found": false,
		"courier_dispatched": true,
		"basement_lamp_lit": false,
	}
	room_states = {
		"room_hub": RoomStateModelScript.from_dictionary(
			{
				"doors": {
					"east": true,
					"south": true,
				},
				"opened_chests": [],
				"defeated_enemies_set": {},
				"switch_states": {
					"entry_switch": false,
				},
				"pending_deliveries": [],
			}
		),
		"room_east": RoomStateModelScript.from_dictionary(
			{
				"doors": {
					"west": true,
				},
				"opened_chests": [],
				"defeated_enemies_set": {},
				"switch_states": {
					"torch_puzzle": true,
				},
				"pending_deliveries": [],
			}
		),
		"room_basement": RoomStateModelScript.from_dictionary(
			{
				"doors": {
					"north": true,
				},
				"opened_chests": [],
				"defeated_enemies_set": {},
				"switch_states": {
					"floodgate": true,
				},
				"pending_deliveries": ["courier_package"],
			}
		),
	}


func apply_dictionary(data: Dictionary) -> void:
	active_room_id = String(data.get("active_room_id", "room_hub"))
	loaded_room_ids = PackedStringArray(data.get("loaded_room_ids", PackedStringArray([active_room_id])))
	world_flags = Dictionary(data.get("world_flags", {})).duplicate(true)
	room_states = {}
	var room_states_dict: Dictionary = Dictionary(data.get("room_states", {}))
	for room_id_variant in room_states_dict.keys():
		var room_id: String = String(room_id_variant)
		room_states[room_id] = RoomStateModelScript.from_dictionary(Dictionary(room_states_dict[room_id]))


func to_dictionary() -> Dictionary:
	var serialized_rooms: Dictionary = {}
	for room_id_variant in room_states.keys():
		var room_id: String = String(room_id_variant)
		var room_state: ZeldaLikeRoomStateModel = room_states[room_id]
		serialized_rooms[room_id] = room_state.to_dictionary()
	return {
		"active_room_id": active_room_id,
		"loaded_room_ids": loaded_room_ids.duplicate(),
		"world_flags": world_flags.duplicate(true),
		"room_states": serialized_rooms,
	}


func set_active_room(room_id: String) -> void:
	active_room_id = room_id
	loaded_room_ids = PackedStringArray([room_id])


func set_world_flag(flag_key: String, value: Variant) -> void:
	world_flags[flag_key] = value


func get_room_state_model(room_id: String):
	if room_states.has(room_id):
		return room_states[room_id]
	var fallback := RoomStateModelScript.new()
	room_states[room_id] = fallback
	return fallback
