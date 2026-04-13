extends Node2D

@export var current_room_id := "room_hub"
@export var hearts := 5
@export var stamina := 72.5
@export var rupees := 136
@export var equipped_items: Dictionary = {
	"sword": "wood_blade",
	"shield": "pot_lid",
	"utility": "boomerang",
}
@export var inventory_slots: Array = ["boomerang", "bomb", "small_key"]
@export var visited_rooms_set: Dictionary = {
	"room_hub": true,
	"room_east": true,
}
@export var discovered_shortcuts: PackedStringArray = PackedStringArray(["hub_to_east"])
@export var ability_cooldowns: Dictionary = {
	"dash": 0.4,
	"spin": 1.2,
}


func reset_state() -> void:
	position = Vector2(96, 72)
	current_room_id = "room_hub"
	hearts = 5
	stamina = 72.5
	rupees = 136
	equipped_items = {
		"sword": "wood_blade",
		"shield": "pot_lid",
		"utility": "boomerang",
	}
	inventory_slots = ["boomerang", "bomb", "small_key"]
	visited_rooms_set = {
		"room_hub": true,
		"room_east": true,
	}
	discovered_shortcuts = PackedStringArray(["hub_to_east"])
	ability_cooldowns = {
		"dash": 0.4,
		"spin": 1.2,
	}
