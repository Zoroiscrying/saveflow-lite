extends Node

@export var hp := 100
@export var coins := 42
var runtime_only_seed := 7

func mutate() -> void:
	hp = max(hp - 15, 1)
	coins += 11


func reset_state() -> void:
	hp = 100
	coins = 42


func to_debug_string() -> String:
	return "hp=%d coins=%d" % [hp, coins]
