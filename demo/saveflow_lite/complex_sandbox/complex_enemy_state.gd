extends Node2D

@export var enemy_id := ""
@export var hp := 0
@export var patrol_index := 0
@export var loot_seed := 0
var runtime_aggro_target := ""


func mutate_supported() -> void:
	hp = max(hp - 17, 0)
	patrol_index += 1
	position += Vector2(16, 0)


func reset_state(default_enemy_id: String, default_hp: int, default_patrol_index: int, default_loot_seed: int, default_position: Vector2) -> void:
	enemy_id = default_enemy_id
	hp = default_hp
	patrol_index = default_patrol_index
	loot_seed = default_loot_seed
	position = default_position
	scale = Vector2.ONE
	runtime_aggro_target = ""


func to_debug_string() -> String:
	return "%s hp=%d patrol=%d pos=%s" % [enemy_id, hp, patrol_index, str(position)]
