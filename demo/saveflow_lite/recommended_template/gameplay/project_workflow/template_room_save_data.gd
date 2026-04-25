@tool
class_name TemplateRoomSaveData
extends SaveFlowTypedData

@export var room_id := ""
@export var display_name := ""
@export var door_open := false
@export var switch_on := false
@export var collected_coins: PackedStringArray = []
@export var event_count := 0


func reset_for_room(next_room_id: String, next_display_name: String) -> void:
	room_id = next_room_id
	display_name = next_display_name
	door_open = false
	switch_on = false
	collected_coins = PackedStringArray()
	event_count = 0
