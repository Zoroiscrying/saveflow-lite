extends Node2D

@export var hearts := 5
@export var rupees := 136


func reset_state() -> void:
	position = Vector2(96, 72)
	hearts = 5
	rupees = 136


func describe_state() -> String:
	return "pos=%s hearts=%d rupees=%d" % [str(position), hearts, rupees]
