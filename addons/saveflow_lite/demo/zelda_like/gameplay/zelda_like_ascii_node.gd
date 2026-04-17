extends Node2D

@export_multiline var ascii_text := ""
@export var font_size := 16
@export var tint := Color("d7dbe6")

var _font: SystemFont


func _ready() -> void:
	_font = _build_font()
	queue_redraw()


func configure(text_value: String, color_value: Color, size_value: int = 16) -> void:
	ascii_text = text_value
	tint = color_value
	font_size = size_value
	queue_redraw()


func _draw() -> void:
	if _font == null or ascii_text.is_empty():
		return
	var lines: PackedStringArray = ascii_text.split("\n", false)
	for index in range(lines.size()):
		draw_string(_font, Vector2.ZERO + Vector2(0, index * (font_size - 2)), lines[index], HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, tint)


func _build_font() -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Cascadia Mono", "Consolas", "Courier New", "Monospace"])
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return font
