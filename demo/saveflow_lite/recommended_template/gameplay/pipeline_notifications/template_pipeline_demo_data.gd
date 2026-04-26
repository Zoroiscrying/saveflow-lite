@tool
class_name TemplatePipelineDemoData
extends SaveFlowTypedData

@export var display_name := ""
@export var summary := ""
@export var counter := 0
@export var enabled_flag := false
@export var tags: PackedStringArray = []


func mutate(label: String, tick: int) -> void:
	display_name = label
	counter += 1
	enabled_flag = not enabled_flag
	summary = "%s changed at tick %d" % [label, tick]
	tags = PackedStringArray([label.to_snake_case(), "tick_%d" % tick])
