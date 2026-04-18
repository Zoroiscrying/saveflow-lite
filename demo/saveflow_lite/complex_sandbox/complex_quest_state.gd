extends Node

@export var active_quest_id := "find_the_relic"
@export_storage var completed_quests: PackedStringArray = PackedStringArray(["intro_camp"])
@export_storage var objective_progress := {
	"relic_shards": 2,
	"talked_to_guard": 1,
}
@export var tracked_party_member_id := "aria"
var runtime_trace_id := "quest-trace"


func mutate_supported() -> void:
	objective_progress["relic_shards"] = int(objective_progress.get("relic_shards", 0)) + 1
	if not completed_quests.has("bridge_event"):
		completed_quests.append("bridge_event")
	tracked_party_member_id = "bram"


func reset_state() -> void:
	active_quest_id = "find_the_relic"
	completed_quests = PackedStringArray(["intro_camp"])
	objective_progress = {
		"relic_shards": 2,
		"talked_to_guard": 1,
	}
	tracked_party_member_id = "aria"
	runtime_trace_id = "quest-trace"


func to_debug_string() -> String:
	return "active=%s completed=%d tracked=%s progress=%s" % [active_quest_id, completed_quests.size(), tracked_party_member_id, JSON.stringify(objective_progress)]
