extends Node

var system_state: Dictionary = {}


func _init() -> void:
	reset_state()


func reset_state() -> void:
	system_state = {
		"active_room_id": "room_hub",
		"loaded_room_ids": PackedStringArray(["room_hub"]),
		"world_flags": {
			"boss_key_found": false,
			"courier_dispatched": true,
		},
		"room_states": {
			"room_hub": {
				"doors": {
					"north": true,
					"east": false,
				},
				"opened_chests": ["hub_chest_1"],
				"defeated_enemies_set": {
					"hub_bat_1": true,
				},
				"switch_states": {
					"bridge_switch": false,
				},
				"pending_deliveries": [],
			},
			"room_east": {
				"doors": {
					"west": true,
					"basement": false,
				},
				"opened_chests": [],
				"defeated_enemies_set": {},
				"switch_states": {
					"torch_puzzle": true,
				},
				"pending_deliveries": [],
			},
			"room_basement": {
				"doors": {
					"ladder": false,
				},
				"opened_chests": [],
				"defeated_enemies_set": {
					"basement_slime_1": true,
				},
				"switch_states": {
					"floodgate": true,
				},
				"pending_deliveries": ["courier_package"],
			},
		},
	}
