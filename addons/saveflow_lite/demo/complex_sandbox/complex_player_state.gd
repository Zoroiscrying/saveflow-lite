extends Node2D

@export var hp := 125
@export var stamina := 60
@export var coins := 340
@export var equipped_weapon := "bronze_sword"
var runtime_navigation_cache := PackedVector2Array()


func mutate_supported() -> void:
	hp = max(hp - 28, 1)
	stamina = max(stamina - 11, 0)
	coins += 19
	equipped_weapon = "iron_sword" if equipped_weapon == "bronze_sword" else "bronze_sword"
	position += Vector2(24, -18)


func reset_state() -> void:
	hp = 125
	stamina = 60
	coins = 340
	equipped_weapon = "bronze_sword"
	position = Vector2(80, 120)
	scale = Vector2.ONE
	runtime_navigation_cache = PackedVector2Array()


func to_debug_string() -> String:
	return "hp=%d sta=%d coins=%d weapon=%s pos=%s" % [hp, stamina, coins, equipped_weapon, str(position)]
