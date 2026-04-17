extends Marker2D

@export_enum("north", "south", "west", "east") var edge := "east"
@export var door_size := 52.0
@export var target_room_id := ""
@export var spawn_position := Vector2.ZERO


func to_layout_entry() -> Dictionary:
	var offset := 0.0
	if edge == "north" or edge == "south":
		offset = position.x - door_size * 0.5
	else:
		offset = position.y - door_size * 0.5
	return {
		"name": name,
		"edge": edge,
		"offset": maxf(offset, 0.0),
		"size": door_size,
		"target_room_id": target_room_id,
		"spawn_position": spawn_position,
	}
