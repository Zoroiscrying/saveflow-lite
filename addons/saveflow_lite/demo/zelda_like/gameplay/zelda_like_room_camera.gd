extends Camera2D

@export var design_room_size := Vector2(1200, 960)
@export var padding := Vector2(72, 72)


func _ready() -> void:
	make_current()
	if get_viewport() != null:
		get_viewport().size_changed.connect(_update_zoom)
	_update_zoom()


func _exit_tree() -> void:
	if get_viewport() != null and get_viewport().size_changed.is_connected(_update_zoom):
		get_viewport().size_changed.disconnect(_update_zoom)


func focus_room(room_rect: Rect2) -> void:
	position = room_rect.get_center()
	_update_zoom()


func _update_zoom() -> void:
	if get_viewport() == null:
		return
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var target_size := design_room_size + padding * 2.0
	var scale_x := viewport_size.x / target_size.x
	var scale_y := viewport_size.y / target_size.y
	var scale := maxf(minf(scale_x, scale_y), 0.5)
	zoom = Vector2.ONE / scale
