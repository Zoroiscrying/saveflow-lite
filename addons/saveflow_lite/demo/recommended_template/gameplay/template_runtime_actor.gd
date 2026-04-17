extends Node2D

@export var actor_type := "slime"
@export var hp := 12
@export var loot_table: Array = ["gel"]
@export var tags: PackedStringArray = PackedStringArray(["ground"])
@export var is_alerted := false


func reset_state(data: Dictionary = {}) -> void:
	actor_type = String(data.get("actor_type", actor_type))
	hp = int(data.get("hp", hp))
	loot_table = Array(data.get("loot_table", loot_table)).duplicate(true)
	tags = PackedStringArray(data.get("tags", tags))
	is_alerted = bool(data.get("is_alerted", is_alerted))
	position = data.get("position", position)


func describe_state() -> String:
	return "%s hp=%d pos=%s loot=%s tags=%s alerted=%s" % [
		actor_type,
		hp,
		str(position),
		str(loot_table),
		str(tags),
		str(is_alerted),
	]
