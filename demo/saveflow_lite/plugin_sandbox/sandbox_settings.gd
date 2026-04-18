extends Node

@export var language := "zh_CN"
@export var music_enabled := true
@export var master_volume := 0.8
var runtime_only_note := "not_saved"

func mutate() -> void:
	language = "en" if language == "zh_CN" else "zh_CN"
	music_enabled = not music_enabled
	master_volume = 0.35 if master_volume > 0.5 else 0.8


func reset_state() -> void:
	language = "zh_CN"
	music_enabled = true
	master_volume = 0.8


func to_debug_string() -> String:
	return "lang=%s music=%s volume=%.2f" % [language, str(music_enabled), master_volume]
