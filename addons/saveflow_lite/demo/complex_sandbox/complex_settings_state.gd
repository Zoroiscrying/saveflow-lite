extends Node

@export var language := "zh_CN"
@export var music_enabled := true
@export var master_volume := 0.75
@export var vibration_enabled := true
var runtime_audio_bus_snapshot := {}


func mutate_supported() -> void:
	language = "en" if language == "zh_CN" else "zh_CN"
	music_enabled = not music_enabled
	master_volume = 0.35 if master_volume > 0.5 else 0.75
	vibration_enabled = not vibration_enabled


func reset_state() -> void:
	language = "zh_CN"
	music_enabled = true
	master_volume = 0.75
	vibration_enabled = true
	runtime_audio_bus_snapshot = {}


func to_debug_string() -> String:
	return "lang=%s music=%s volume=%.2f vibration=%s" % [language, str(music_enabled), master_volume, str(vibration_enabled)]
