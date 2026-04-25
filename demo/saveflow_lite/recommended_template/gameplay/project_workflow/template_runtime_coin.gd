extends Node2D

@export var coin_value := 5

@onready var _shadow: Polygon2D = $Shadow
@onready var _body: Polygon2D = $Body


func _ready() -> void:
	_refresh_visuals()


func reset_state(state: Dictionary = {}) -> void:
	coin_value = int(state.get("coin_value", coin_value))
	position = Vector2(state.get("position", position))
	_refresh_visuals()


func _refresh_visuals() -> void:
	_shadow.color = Color("000000", 0.18)
	_body.color = Color("f6e05e")
