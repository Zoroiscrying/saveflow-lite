extends CharacterBody2D

const FONT_SIZE := 15
const MOVE_LEFT_ACTION := "sf_move_left"
const MOVE_RIGHT_ACTION := "sf_move_right"
const MOVE_UP_ACTION := "sf_move_up"
const MOVE_DOWN_ACTION := "sf_move_down"

@export var current_room_id := "room_hub"
@export var hearts := 5
@export var stamina := 72.5
@export var rupees := 136
@export var facing := "down"
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

var move_speed := 135.0
var attack_cooldown := 0.0
var hurt_cooldown := 0.0
var _font: SystemFont

@onready var _interaction_area: Area2D = $InteractionArea
@onready var _interaction_shape: CollisionShape2D = $InteractionArea/CollisionShape2D
@onready var _animation_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	_ensure_player_input_actions()
	add_to_group("saveflow_demo_player")
	_font = _build_font()
	_configure_interaction_area()
	_build_animation_library()
	queue_redraw()


func _physics_process(delta: float) -> void:
	_update_timers(delta)
	_handle_movement()
	_update_animation()
	move_and_slide()
	queue_redraw()


func reset_state() -> void:
	position = Vector2(72, 124)
	current_room_id = "room_hub"
	hearts = 5
	stamina = 72.5
	rupees = 136
	facing = "down"
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
	velocity = Vector2.ZERO
	attack_cooldown = 0.0
	hurt_cooldown = 0.0


func move_to_room(room_id: String, next_position: Vector2) -> void:
	current_room_id = room_id
	position = next_position
	visited_rooms_set[room_id] = true
	velocity = Vector2.ZERO
	queue_redraw()


func trigger_attack() -> bool:
	if attack_cooldown > 0.0:
		return false
	attack_cooldown = 0.35
	stamina = max(0.0, stamina - 4.0)
	_animation_player.speed_scale = 1.0
	_animation_player.play("attack")
	_animation_player.seek(0.0, true)
	queue_redraw()
	return true


func take_damage(amount: int) -> bool:
	if hurt_cooldown > 0.0:
		return false
	hurt_cooldown = 0.75
	hearts = max(0, hearts - amount)
	stamina = max(0.0, stamina - 8.0)
	queue_redraw()
	return true


func add_rupees(amount: int) -> void:
	rupees += amount


func add_inventory_item(item_id: String) -> void:
	if item_id.is_empty():
		return
	inventory_slots.append(item_id)


func register_shortcut(shortcut_id: String) -> void:
	if shortcut_id.is_empty():
		return
	if discovered_shortcuts.has(shortcut_id):
		return
	discovered_shortcuts.append(shortcut_id)


func get_interaction_targets() -> Array:
	return _interaction_area.get_overlapping_areas()


func to_debug_string() -> String:
	return "room=%s hearts=%d stamina=%.1f rupees=%d pos=%s facing=%s inventory=%s" % [
		current_room_id,
		hearts,
		stamina,
		rupees,
		str(position),
		facing,
		str(inventory_slots),
	]


func _draw() -> void:
	draw_circle(Vector2(0, 10), 11.0, Color(0, 0, 0, 0.18))
	for index in range(_get_pose_lines().size()):
		var line: String = _get_pose_lines()[index]
		draw_string(_font, Vector2(-18, -18 + index * 14), line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE, _get_pose_color())


func _handle_movement() -> void:
	if attack_cooldown > 0.0:
		velocity = Vector2.ZERO
		return
	var input_vector := Input.get_vector(MOVE_LEFT_ACTION, MOVE_RIGHT_ACTION, MOVE_UP_ACTION, MOVE_DOWN_ACTION)
	velocity = input_vector * move_speed
	if input_vector.length() > 0.0:
		facing = _facing_from_vector(input_vector)
		stamina = max(0.0, stamina - get_physics_process_delta_time() * 3.0)
	else:
		stamina = min(100.0, stamina + get_physics_process_delta_time() * 5.0)
	_configure_interaction_area()


func _update_animation() -> void:
	if attack_cooldown > 0.0:
		if not _animation_player.is_playing() or _animation_player.current_animation != "attack":
			_animation_player.play("attack")
		return
	if velocity.length() > 0.0:
		_animation_player.play("run")
	else:
		_animation_player.play("idle")


func _update_timers(delta: float) -> void:
	attack_cooldown = max(0.0, attack_cooldown - delta)
	hurt_cooldown = max(0.0, hurt_cooldown - delta)


func _facing_from_vector(input_vector: Vector2) -> String:
	if absf(input_vector.x) > absf(input_vector.y):
		return "right" if input_vector.x > 0.0 else "left"
	return "down" if input_vector.y > 0.0 else "up"


func _configure_interaction_area() -> void:
	if _interaction_shape == null:
		return
	var shape := RectangleShape2D.new()
	shape.size = Vector2(18, 18)
	_interaction_shape.shape = shape
	match facing:
		"up":
			_interaction_area.position = Vector2(0, -18)
		"down":
			_interaction_area.position = Vector2(0, 16)
		"left":
			_interaction_area.position = Vector2(-18, 0)
		_:
			_interaction_area.position = Vector2(18, 0)


func _build_animation_library() -> void:
	if _animation_player.has_animation("idle"):
		return
	var library := AnimationLibrary.new()
	for animation_name in ["idle", "run", "attack"]:
		var animation := Animation.new()
		animation.length = 0.8 if animation_name == "attack" else 1.0
		library.add_animation(animation_name, animation)
	_animation_player.add_animation_library("", library)
	_animation_player.play("idle")


func _get_pose_lines() -> PackedStringArray:
	var animation_name := _animation_player.current_animation
	if attack_cooldown > 0.0 or animation_name == "attack":
		match facing:
			"up":
				return PackedStringArray([" /^\\ ", "/_|_\\", " / \\ "])
			"down":
				return PackedStringArray([" \\o/ ", " _|_ ", " / \\ "])
			"left":
				return PackedStringArray([" <-o ", " /|  ", " / \\ "])
			_:
				return PackedStringArray([" o-> ", "  |\\ ", " / \\ "])
	if velocity.length() > 0.0 or animation_name == "run":
		match facing:
			"up":
				return PackedStringArray([" /^\\ ", " /|\\ ", " / \\ "])
			"down":
				return PackedStringArray([" \\o/ ", " /|\\ ", " _/\\ "])
			"left":
				return PackedStringArray([" <o  ", " /|  ", " /\\  "])
			_:
				return PackedStringArray(["  o> ", "  |\\ ", "  /\\ "])
	match facing:
		"up":
			return PackedStringArray([" /^\\ ", " /|\\ ", " / \\ "])
		"down":
			return PackedStringArray([" \\o/ ", " /|\\ ", " / \\ "])
		"left":
			return PackedStringArray([" <o  ", " /|  ", " / \\ "])
		_:
			return PackedStringArray(["  o> ", "  |\\ ", " / \\ "])


func _get_pose_color() -> Color:
	if hurt_cooldown > 0.0:
		return Color("ff9b71")
	if attack_cooldown > 0.0:
		return Color("f4d35e")
	return Color("f0f4ff")


func _build_font() -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Cascadia Mono", "Consolas", "Courier New", "Monospace"])
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return font


func _ensure_player_input_actions() -> void:
	_ensure_input_action(MOVE_LEFT_ACTION, [KEY_A, KEY_LEFT])
	_ensure_input_action(MOVE_RIGHT_ACTION, [KEY_D, KEY_RIGHT])
	_ensure_input_action(MOVE_UP_ACTION, [KEY_W, KEY_UP])
	_ensure_input_action(MOVE_DOWN_ACTION, [KEY_S, KEY_DOWN])


func _ensure_input_action(action_name: String, keycodes: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	for keycode_variant in keycodes:
		var keycode: Key = int(keycode_variant)
		if _action_has_key(action_name, keycode):
			continue
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		InputMap.action_add_event(action_name, event)


func _action_has_key(action_name: String, keycode: Key) -> bool:
	for event_variant in InputMap.action_get_events(action_name):
		if event_variant is InputEventKey:
			var key_event: InputEventKey = event_variant
			if key_event.keycode == keycode or key_event.physical_keycode == keycode:
				return true
	return false
