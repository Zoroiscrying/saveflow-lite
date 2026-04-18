extends Node

@export var member_id := ""
@export var level := 1
@export var affinity := 0
@export var unlocked_skill := ""
var runtime_dialogue_context := {}


func mutate_supported() -> void:
	level += 1
	affinity += 3
	if unlocked_skill.is_empty():
		unlocked_skill = "combo_strike"


func reset_state(default_member_id: String, default_level: int, default_affinity: int, default_skill: String) -> void:
	member_id = default_member_id
	level = default_level
	affinity = default_affinity
	unlocked_skill = default_skill
	runtime_dialogue_context = {}


func to_debug_string() -> String:
	return "%s lv=%d affinity=%d skill=%s" % [member_id, level, affinity, unlocked_skill]
