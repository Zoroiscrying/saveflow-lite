extends Node2D

@export var entity_type := "enemy"
@export var room_id := "room_hub"
@export var hp := 0
@export var is_open := false
@export var loot_table: Array = []
@export var tags_set: Dictionary = {}
@export var patrol_route: PackedStringArray = PackedStringArray()


func reset_state(next_entity_type: String, next_room_id: String, next_hp: int, next_is_open: bool, next_loot_table: Array, next_tags_set: Dictionary, next_patrol_route: PackedStringArray, next_position: Vector2) -> void:
	entity_type = next_entity_type
	room_id = next_room_id
	hp = next_hp
	is_open = next_is_open
	loot_table = next_loot_table.duplicate(true)
	tags_set = next_tags_set.duplicate(true)
	patrol_route = next_patrol_route.duplicate()
	position = next_position
