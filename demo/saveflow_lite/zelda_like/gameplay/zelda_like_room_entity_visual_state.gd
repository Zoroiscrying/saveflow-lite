extends Node

@export var pose := "idle"
@export var mood := "calm"
@export var facing := "left"
@export var accent := "moss"
@export var ornament_flags: Dictionary = {
	"glow": false,
	"rare": false,
}


func reset_state(next_pose: String, next_mood: String, next_facing: String, next_accent: String, next_ornament_flags: Dictionary) -> void:
	pose = next_pose
	mood = next_mood
	facing = next_facing
	accent = next_accent
	ornament_flags = next_ornament_flags.duplicate(true)
