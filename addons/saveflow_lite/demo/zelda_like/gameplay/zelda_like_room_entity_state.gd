extends Area2D

const FONT_SIZE := 14

@export var entity_type := "enemy"
@export var room_id := "room_hub"
@export var hp := 0
@export var is_open := false
@export var loot_table: Array = []
@export var tags_set: Dictionary = {}
@export var patrol_route: PackedStringArray = PackedStringArray()
@export var touch_damage := 1
@export var rupee_value := 0

var _font: SystemFont
var _visual_state: Node = null


func _ready() -> void:
	_font = _build_font()
	_visual_state = get_node_or_null("VisualState")
	monitoring = true
	monitorable = true
	_update_collision_shape()
	queue_redraw()


func reset_state(core_state: Dictionary, visual_state: Dictionary) -> void:
	entity_type = String(core_state.get("entity_type", entity_type))
	room_id = String(core_state.get("room_id", room_id))
	hp = int(core_state.get("hp", hp))
	is_open = bool(core_state.get("is_open", is_open))
	loot_table = Array(core_state.get("loot_table", loot_table)).duplicate(true)
	tags_set = Dictionary(core_state.get("tags_set", tags_set)).duplicate(true)
	patrol_route = PackedStringArray(core_state.get("patrol_route", patrol_route))
	touch_damage = int(core_state.get("touch_damage", touch_damage))
	rupee_value = int(core_state.get("rupee_value", rupee_value))
	position = Vector2(core_state.get("position", position))
	var visual_node := _resolve_visual_state()
	if visual_node != null:
		visual_node.call(
		"reset_state",
		String(visual_state.get("pose", "idle")),
		String(visual_state.get("mood", "calm")),
		String(visual_state.get("facing", "left")),
		String(visual_state.get("accent", "moss")),
		Dictionary(visual_state.get("ornament_flags", {})).duplicate(true)
		)
	_update_collision_shape()
	queue_redraw()


func apply_player_attack() -> Dictionary:
	if entity_type == "chest":
		if is_open:
			return {"event": "chest_already_open"}
		is_open = true
		var chest_visual := _resolve_visual_state()
		if chest_visual != null:
			chest_visual.set("pose", "open")
			chest_visual.set("mood", "spent")
		queue_redraw()
		return {
			"event": "chest_opened",
			"loot_table": loot_table.duplicate(true),
			"rupee_value": rupee_value,
		}

	hp = max(0, hp - 1)
	var enemy_visual := _resolve_visual_state()
	if enemy_visual != null:
		enemy_visual.set("pose", "hurt")
		enemy_visual.set("mood", "alert")
	queue_redraw()
	if hp <= 0:
		return {
			"event": "enemy_defeated",
			"rupee_value": rupee_value,
		}
	return {"event": "enemy_hit", "hp": hp}


func can_hurt_player() -> bool:
	return entity_type == "enemy" and hp > 0


func get_touch_damage() -> int:
	return touch_damage


func get_visual_state_node() -> Node:
	return _resolve_visual_state()


func get_persistent_id() -> String:
	var identity := get_node_or_null("Identity")
	if identity != null and identity.has_method("get_persistent_id"):
		return String(identity.call("get_persistent_id"))
	return name.to_snake_case()


func to_debug_string() -> String:
	return "%s id=%s room=%s hp=%d open=%s pose=%s pos=%s" % [
		entity_type,
		get_persistent_id(),
		room_id,
		hp,
		str(is_open),
		String(_read_visual_value("pose", "idle")),
		str(position),
	]


func _draw() -> void:
	draw_circle(Vector2.ZERO, 10.0, Color(0, 0, 0, 0.14))
	var color := _resolve_color()
	var lines: PackedStringArray = _get_ascii_lines()
	for index in range(lines.size()):
		draw_string(_font, Vector2(-16, -10 + index * 13), lines[index], HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE, color)


func _get_ascii_lines() -> PackedStringArray:
	if entity_type == "chest":
		return PackedStringArray([".----.", "|[] |" if is_open else "|## |", "'----'"])
	var pose: String = String(_read_visual_value("pose", "idle"))
	if pose == "hurt":
		return PackedStringArray([" /xx\\", "<_==_", " /  \\"])
	if String(_read_visual_value("mood", "calm")) == "alert":
		return PackedStringArray([" /@@\\", "<_==_", " /  \\"])
	return PackedStringArray([" /oo\\", "<_==_", " /  \\"])


func _resolve_color() -> Color:
	if entity_type == "chest":
		return Color("f2c879") if is_open else Color("d9d1b2")
	if String(_read_visual_value("mood", "calm")) == "alert":
		return Color("ff9b71")
	return Color("d7f9ff")


func _read_visual_value(property_name: String, default_value: Variant) -> Variant:
	var visual_node := _resolve_visual_state()
	if visual_node == null:
		return default_value
	if not visual_node.has_method("get"):
		return default_value
	var value: Variant = visual_node.get(property_name)
	if value == null:
		return default_value
	return value


func _resolve_visual_state() -> Node:
	if _visual_state == null:
		_visual_state = get_node_or_null("VisualState")
	return _visual_state


func _update_collision_shape() -> void:
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		return
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = Vector2(26, 18) if entity_type == "enemy" else Vector2(24, 16)
	shape_node.shape = rect_shape


func _build_font() -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Cascadia Mono", "Consolas", "Courier New", "Monospace"])
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return font
