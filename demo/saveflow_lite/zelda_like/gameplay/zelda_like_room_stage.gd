extends Node2D

signal door_requested(target_room_id: String, spawn_position: Vector2)

const AsciiNodeScript := preload("res://demo/saveflow_lite/zelda_like/gameplay/zelda_like_ascii_node.gd")
const ROOM_SIZE := Vector2(560, 250)
const WALL_THICKNESS := 18.0
const DOOR_DEPTH := 18.0
const FONT_SIZE := 16
const FLOOR_STEP := Vector2(28, 22)
const FLOOR_GLYPHS := [".", "`", ":", ","]

var _room_id := ""
var _layout: Dictionary = {}
var _font: SystemFont
var _wall_root: Node2D
var _door_root: Node2D
var _obstacle_root: Node2D
var _visual_root: Node2D


func _ready() -> void:
	_font = _build_font()
	_wall_root = _ensure_child("Walls")
	_door_root = _ensure_child("Doors")
	_obstacle_root = _ensure_child("Obstacles")
	_visual_root = _ensure_child("Visuals")
	_wall_root.z_index = -20
	_door_root.z_index = -10
	_obstacle_root.z_index = -15
	_visual_root.z_index = -30


func configure_room(room_id: String, layout: Dictionary) -> void:
	_room_id = room_id
	_layout = layout.duplicate(true)
	_rebuild_room()


func get_room_rect() -> Rect2:
	return Rect2(Vector2.ZERO, ROOM_SIZE)


func _build_floor_pattern(color: Color) -> void:
	var room_name: String = String(_layout.get("title", _room_id))
	var glyph_index := 0
	for y in range(26, int(ROOM_SIZE.y) - 24, int(FLOOR_STEP.y)):
		for x in range(24, int(ROOM_SIZE.x) - 24, int(FLOOR_STEP.x)):
			var glyph: String = FLOOR_GLYPHS[glyph_index % FLOOR_GLYPHS.size()]
			if room_name.length() > 0 and (glyph_index % 7) == 0:
				glyph = room_name.substr(glyph_index % room_name.length(), 1)
			_add_ascii_visual("Floor_%d" % glyph_index, glyph, Vector2(x, y), color, FONT_SIZE - 2)
			glyph_index += 1


func _build_border_visuals(color: Color) -> void:
	for x in range(8, int(ROOM_SIZE.x) - 12, 18):
		_add_ascii_visual("BorderTop_%d" % x, "##", Vector2(x, 18), color)
		_add_ascii_visual("BorderBottom_%d" % x, "##", Vector2(x, ROOM_SIZE.y - 8), color)
	for y in range(32, int(ROOM_SIZE.y) - 6, 18):
		_add_ascii_visual("BorderLeft_%d" % y, "#", Vector2(8, y), color)
		_add_ascii_visual("BorderRight_%d" % y, "#", Vector2(ROOM_SIZE.x - 18, y), color)


func _build_obstacle_visuals(base_color: Color, accent_color: Color) -> void:
	for obstacle_variant in _layout.get("obstacles", []):
		var obstacle: Dictionary = obstacle_variant
		var rect: Rect2 = obstacle.get("rect", Rect2())
		var glyph: String = String(obstacle.get("glyph", "[]"))
		var accent := Color(obstacle.get("color", accent_color))
		var backdrop := Polygon2D.new()
		backdrop.name = "%sBackdrop" % String(obstacle.get("name", "Obstacle"))
		backdrop.polygon = PackedVector2Array([
			rect.position,
			rect.position + Vector2(rect.size.x, 0),
			rect.position + rect.size,
			rect.position + Vector2(0, rect.size.y),
		])
		backdrop.color = Color(base_color.r, base_color.g, base_color.b, 0.08)
		_visual_root.add_child(backdrop)
		var y := rect.position.y + 18.0
		var line_index := 0
		while y < rect.end.y - 4.0:
			var line := ""
			while line.length() < max(2, int(rect.size.x / 10.0)):
				line += glyph
			_add_ascii_visual(
				"%sLine%d" % [String(obstacle.get("name", "Obstacle")), line_index],
				line.substr(0, max(1, int(rect.size.x / 10.0))),
				Vector2(rect.position.x + 4.0, y),
				accent,
				FONT_SIZE - 2
			)
			y += 16.0
			line_index += 1


func _build_door_visuals(color: Color) -> void:
	for door_variant in _layout.get("doors", []):
		var door: Dictionary = door_variant
		var rect: Rect2 = _get_door_rect(door)
		var edge: String = String(door.get("edge", ""))
		var glyph := "=="
		if edge == "north" or edge == "south":
			glyph = "===="
		_add_ascii_visual(String(door.get("name", "Door")), glyph, rect.position + Vector2(4, 14), color)


func _rebuild_room() -> void:
	_clear_children(_wall_root)
	_clear_children(_door_root)
	_clear_children(_obstacle_root)
	_clear_children(_visual_root)
	_build_background()
	_build_boundaries()
	_build_obstacles()
	_build_doors()
	_build_floor_pattern(Color("7b7f8e"))
	_build_border_visuals(Color("c2c3c7"))
	_build_obstacle_visuals(Color("c2c3c7"), Color("f2c879"))
	_build_door_visuals(Color("f2c879"))


func _build_boundaries() -> void:
	var north_ranges := _collect_edge_ranges("north")
	var south_ranges := _collect_edge_ranges("south")
	var west_ranges := _collect_edge_ranges("west")
	var east_ranges := _collect_edge_ranges("east")
	_build_horizontal_edge(Vector2(ROOM_SIZE.x * 0.5, WALL_THICKNESS * 0.5), ROOM_SIZE.x, north_ranges, "north")
	_build_horizontal_edge(Vector2(ROOM_SIZE.x * 0.5, ROOM_SIZE.y - WALL_THICKNESS * 0.5), ROOM_SIZE.x, south_ranges, "south")
	_build_vertical_edge(Vector2(WALL_THICKNESS * 0.5, ROOM_SIZE.y * 0.5), ROOM_SIZE.y, west_ranges, "west")
	_build_vertical_edge(Vector2(ROOM_SIZE.x - WALL_THICKNESS * 0.5, ROOM_SIZE.y * 0.5), ROOM_SIZE.y, east_ranges, "east")


func _build_horizontal_edge(anchor: Vector2, total_width: float, openings: Array, edge: String) -> void:
	var segments: Array = _build_segments(total_width, openings)
	for segment_variant in segments:
		var segment: Vector2 = segment_variant
		var body := StaticBody2D.new()
		body.name = "%sWall%.0f" % [edge.capitalize(), segment.x]
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := CollisionShape2D.new()
		var rect_shape := RectangleShape2D.new()
		rect_shape.size = Vector2(segment.y - segment.x, WALL_THICKNESS)
		shape.shape = rect_shape
		body.position = anchor + Vector2(segment.x + (segment.y - segment.x) * 0.5 - total_width * 0.5, 0)
		body.add_child(shape)
		_wall_root.add_child(body)


func _build_vertical_edge(anchor: Vector2, total_height: float, openings: Array, edge: String) -> void:
	var segments: Array = _build_segments(total_height, openings)
	for segment_variant in segments:
		var segment: Vector2 = segment_variant
		var body := StaticBody2D.new()
		body.name = "%sWall%.0f" % [edge.capitalize(), segment.x]
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := CollisionShape2D.new()
		var rect_shape := RectangleShape2D.new()
		rect_shape.size = Vector2(WALL_THICKNESS, segment.y - segment.x)
		shape.shape = rect_shape
		body.position = anchor + Vector2(0, segment.x + (segment.y - segment.x) * 0.5 - total_height * 0.5)
		body.add_child(shape)
		_wall_root.add_child(body)


func _build_obstacles() -> void:
	for obstacle_variant in _layout.get("obstacles", []):
		var obstacle: Dictionary = obstacle_variant
		var rect: Rect2 = obstacle.get("rect", Rect2())
		var body := StaticBody2D.new()
		body.name = String(obstacle.get("name", "Obstacle"))
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = rect.position + rect.size * 0.5
		var shape := CollisionShape2D.new()
		var rect_shape := RectangleShape2D.new()
		rect_shape.size = rect.size
		shape.shape = rect_shape
		body.add_child(shape)
		_obstacle_root.add_child(body)


func _build_background() -> void:
	var background := Polygon2D.new()
	background.name = "Background"
	background.polygon = PackedVector2Array([
		Vector2.ZERO,
		Vector2(ROOM_SIZE.x, 0),
		ROOM_SIZE,
		Vector2(0, ROOM_SIZE.y),
	])
	background.color = Color("141418")
	_visual_root.add_child(background)

	var frame := Line2D.new()
	frame.name = "Frame"
	frame.default_color = Color("08080a")
	frame.width = 2.0
	frame.closed = true
	frame.points = PackedVector2Array([
		Vector2.ZERO,
		Vector2(ROOM_SIZE.x, 0),
		ROOM_SIZE,
		Vector2(0, ROOM_SIZE.y),
	])
	_visual_root.add_child(frame)


func _build_doors() -> void:
	for door_variant in _layout.get("doors", []):
		var door: Dictionary = door_variant
		var area := Area2D.new()
		area.name = String(door.get("name", "Door"))
		area.collision_layer = 8
		area.collision_mask = 1
		var shape := CollisionShape2D.new()
		var rect_shape := RectangleShape2D.new()
		var rect: Rect2 = _get_door_rect(door)
		rect_shape.size = rect.size
		shape.shape = rect_shape
		area.position = rect.position + rect.size * 0.5
		area.add_child(shape)
		area.body_entered.connect(_on_door_body_entered.bind(door))
		_door_root.add_child(area)


func _collect_edge_ranges(edge: String) -> Array:
	var ranges: Array = []
	for door_variant in _layout.get("doors", []):
		var door: Dictionary = door_variant
		if String(door.get("edge", "")) != edge:
			continue
		var offset: float = float(door.get("offset", 0.0))
		var size: float = float(door.get("size", 48.0))
		ranges.append(Vector2(offset, offset + size))
	return ranges


func _build_segments(total: float, openings: Array) -> Array:
	var sorted_ranges := openings.duplicate()
	sorted_ranges.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var segments: Array = []
	var cursor := 0.0
	for opening_variant in sorted_ranges:
		var opening: Vector2 = opening_variant
		if opening.x > cursor:
			segments.append(Vector2(cursor, opening.x))
		cursor = max(cursor, opening.y)
	if cursor < total:
		segments.append(Vector2(cursor, total))
	return segments


func _get_door_rect(door: Dictionary) -> Rect2:
	var edge: String = String(door.get("edge", ""))
	var offset: float = float(door.get("offset", 0.0))
	var size: float = float(door.get("size", 48.0))
	match edge:
		"north":
			return Rect2(Vector2(offset, -DOOR_DEPTH * 0.5), Vector2(size, DOOR_DEPTH))
		"south":
			return Rect2(Vector2(offset, ROOM_SIZE.y - DOOR_DEPTH * 0.5), Vector2(size, DOOR_DEPTH))
		"west":
			return Rect2(Vector2(-DOOR_DEPTH * 0.5, offset), Vector2(DOOR_DEPTH, size))
		_:
			return Rect2(Vector2(ROOM_SIZE.x - DOOR_DEPTH * 0.5, offset), Vector2(DOOR_DEPTH, size))


func _on_door_body_entered(body: Node, door: Dictionary) -> void:
	if not is_instance_valid(body):
		return
	if not body.is_in_group("saveflow_demo_player"):
		return
	door_requested.emit(String(door.get("target_room_id", "")), Vector2(door.get("spawn_position", Vector2.ZERO)))


func _add_ascii_visual(node_name: String, text: String, position: Vector2, color: Color, font_size: int = FONT_SIZE) -> void:
	var node := Node2D.new()
	node.name = node_name
	node.position = position
	node.set_script(AsciiNodeScript)
	_visual_root.add_child(node)
	node.call("configure", text, color, font_size)


func _ensure_child(node_name: String) -> Node2D:
	var existing := get_node_or_null(node_name)
	if existing is Node2D:
		return existing
	var node := Node2D.new()
	node.name = node_name
	add_child(node)
	return node


func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		child.queue_free()


func _build_font() -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Cascadia Mono", "Consolas", "Courier New", "Monospace"])
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return font
