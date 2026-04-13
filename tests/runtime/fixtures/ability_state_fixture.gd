extends Node

@export var cooldown_slot := 3
@export_storage var active_tags: PackedStringArray = PackedStringArray(["dash", "parry"])
var runtime_resolver := {}
