extends Node

@export var configure_on_ready := true
@export var base_root := "user://recommended_template"
@export var profile_key := ""
@export var save_root := ""
@export var slot_index_file := ""
@export var project_title := ""
@export var save_schema := "main"
@export var data_version := 1
@export var verify_scene_path_on_load := true


func _ready() -> void:
	if configure_on_ready:
		configure_runtime()


func configure_runtime() -> SaveResult:
	return SaveFlow.configure_with(
		_resolved_save_root(),
		_resolved_slot_index_file(),
		SaveFlow.FORMAT_AUTO,
		true,
		true,
		true,
		true,
		true,
		project_title,
		"",
		data_version,
		save_schema,
		true,
		true,
		verify_scene_path_on_load
	)


func _resolved_save_root() -> String:
	var explicit_root := save_root.strip_edges()
	if not explicit_root.is_empty():
		return explicit_root
	return "%s/saves" % _resolved_profile_root()


func _resolved_slot_index_file() -> String:
	var explicit_index_file := slot_index_file.strip_edges()
	if not explicit_index_file.is_empty():
		return explicit_index_file
	return "%s/slots.index" % _resolved_profile_root()


func _resolved_profile_root() -> String:
	var root := base_root.strip_edges().trim_suffix("/")
	if root.is_empty():
		root = "user://saveflow"
	var profile := profile_key.strip_edges().trim_prefix("/").trim_suffix("/")
	if profile.is_empty():
		return root
	return "%s/%s" % [root, profile]
