extends Marker2D

@export var persistent_id := ""
@export var type_key := "enemy"
@export var hp := 1
@export var is_open := false
@export var loot_table: PackedStringArray = PackedStringArray()
@export var tags_set: Dictionary = {}
@export var patrol_route: PackedStringArray = PackedStringArray()
@export var touch_damage := 1
@export var rupee_value := 0
@export var pose := "idle"
@export var mood := "calm"
@export var facing := "left"
@export var accent := "moss"
@export var ornament_flags: Dictionary = {
	"glow": false,
	"rare": false,
}


func to_template(room_id: String) -> Dictionary:
	return {
		"persistent_id": persistent_id,
		"type_key": type_key,
		"node_name": name,
		"hp": hp,
		"is_open": is_open,
		"loot_table": Array(loot_table),
		"tags_set": tags_set.duplicate(true),
		"patrol_route": patrol_route.duplicate(),
		"touch_damage": touch_damage,
		"rupee_value": rupee_value,
		"position": position,
		"pose": pose,
		"mood": mood,
		"facing": facing,
		"accent": accent,
		"ornament_flags": ornament_flags.duplicate(true),
		"room_id": room_id,
	}
