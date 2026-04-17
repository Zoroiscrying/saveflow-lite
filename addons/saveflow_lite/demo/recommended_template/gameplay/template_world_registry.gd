extends Node

var system_state: Dictionary = {}


func _ready() -> void:
	if system_state.is_empty():
		reset_state()


func reset_state() -> void:
	system_state = {
		"opened_doors": {
			"moss_gate": false,
			"cellar_gate": false,
		},
		"quest_flags": {
			"met_blacksmith": true,
			"found_map": false,
		},
		"pending_mail": ["starter_letter"],
	}


func describe_state() -> String:
	return JSON.stringify(system_state)
