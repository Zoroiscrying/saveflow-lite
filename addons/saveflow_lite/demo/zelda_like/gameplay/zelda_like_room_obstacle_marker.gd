extends Node2D

@export var size := Vector2(42, 42)
@export var glyph := "[]"
@export var color := Color("8fa3bf")


func to_layout_entry() -> Dictionary:
	return {
		"name": name,
		"rect": Rect2(position - size * 0.5, size),
		"glyph": glyph,
		"color": color.to_html(false),
	}
