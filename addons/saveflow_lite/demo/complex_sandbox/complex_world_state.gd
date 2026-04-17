extends Node

@export var current_day := 7
@export var weather_profile := "rain"
@export_storage var opened_chests: PackedStringArray = PackedStringArray(["forest_01", "cave_02"])
@export_storage var world_flags := {
	"gate_north": true,
	"boss_intro_seen": false,
}
var runtime_seed := 9281


func mutate_supported() -> void:
	current_day += 1
	weather_profile = "sunny" if weather_profile == "rain" else "rain"
	if not opened_chests.has("tower_01"):
		opened_chests.append("tower_01")
	world_flags["boss_intro_seen"] = true


func reset_state() -> void:
	current_day = 7
	weather_profile = "rain"
	opened_chests = PackedStringArray(["forest_01", "cave_02"])
	world_flags = {
		"gate_north": true,
		"boss_intro_seen": false,
	}
	runtime_seed = 9281


func to_debug_string() -> String:
	return "day=%d weather=%s chests=%d flags=%s" % [current_day, weather_profile, opened_chests.size(), JSON.stringify(world_flags)]
