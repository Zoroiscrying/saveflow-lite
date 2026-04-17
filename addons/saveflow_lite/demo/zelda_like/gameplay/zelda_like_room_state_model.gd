class_name ZeldaLikeRoomStateModel
extends RefCounted

var doors: Dictionary = {}
var opened_chests: Array = []
var defeated_enemies_set: Dictionary = {}
var switch_states: Dictionary = {}
var pending_deliveries: Array = []


static func from_dictionary(data: Dictionary) -> ZeldaLikeRoomStateModel:
	var model := ZeldaLikeRoomStateModel.new()
	model.apply_dictionary(data)
	return model


func apply_dictionary(data: Dictionary) -> void:
	doors = Dictionary(data.get("doors", {})).duplicate(true)
	opened_chests = Array(data.get("opened_chests", [])).duplicate(true)
	defeated_enemies_set = Dictionary(data.get("defeated_enemies_set", {})).duplicate(true)
	switch_states = Dictionary(data.get("switch_states", {})).duplicate(true)
	pending_deliveries = Array(data.get("pending_deliveries", [])).duplicate(true)


func to_dictionary() -> Dictionary:
	return {
		"doors": doors.duplicate(true),
		"opened_chests": opened_chests.duplicate(true),
		"defeated_enemies_set": defeated_enemies_set.duplicate(true),
		"switch_states": switch_states.duplicate(true),
		"pending_deliveries": pending_deliveries.duplicate(true),
	}


func mark_enemy_defeated(persistent_id: String) -> void:
	defeated_enemies_set[persistent_id] = true


func mark_chest_opened(persistent_id: String) -> void:
	if not opened_chests.has(persistent_id):
		opened_chests.append(persistent_id)


func register_delivery(delivery_id: String) -> void:
	if not pending_deliveries.has(delivery_id):
		pending_deliveries.append(delivery_id)
