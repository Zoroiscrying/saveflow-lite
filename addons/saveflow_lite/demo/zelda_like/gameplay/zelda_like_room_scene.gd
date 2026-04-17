extends Node2D

@export var room_id := ""
@export var room_title := ""


func build_layout() -> Dictionary:
	return {
		"title": room_title,
		"doors": _collect_door_entries(),
		"obstacles": _collect_obstacle_entries(),
	}


func build_entity_templates() -> Array:
	var templates: Array = []
	for child in _get_entity_spawn_root().get_children():
		if child.has_method("to_template"):
			templates.append(child.call("to_template", room_id))
	return templates


func get_room_title() -> String:
	return room_title


func _collect_door_entries() -> Array:
	var entries: Array = []
	for child in _get_door_root().get_children():
		if child.has_method("to_layout_entry"):
			entries.append(child.call("to_layout_entry"))
	return entries


func _collect_obstacle_entries() -> Array:
	var entries: Array = []
	for child in _get_obstacle_root().get_children():
		if child.has_method("to_layout_entry"):
			entries.append(child.call("to_layout_entry"))
	return entries


func _get_door_root() -> Node:
	var node := get_node_or_null("Doors")
	if node == null:
		node = Node2D.new()
		node.name = "Doors"
		add_child(node)
	return node


func _get_obstacle_root() -> Node:
	var node := get_node_or_null("Obstacles")
	if node == null:
		node = Node2D.new()
		node.name = "Obstacles"
		add_child(node)
	return node


func _get_entity_spawn_root() -> Node:
	var node := get_node_or_null("EntitySpawns")
	if node == null:
		node = Node2D.new()
		node.name = "EntitySpawns"
		add_child(node)
	return node
