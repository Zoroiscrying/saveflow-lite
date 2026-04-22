## SaveFlowProjectSettings bridges Lite's editor-facing settings dock with
## ProjectSettings so one project-wide save profile can configure the runtime.
@tool
class_name SaveFlowProjectSettings
extends RefCounted

const SETTINGS_ROOT := "saveflow_lite/settings/"
const FORMAT_AUTO := 0

const SETTING_SAVE_ROOT := SETTINGS_ROOT + "save_root"
const SETTING_SLOT_INDEX_FILE := SETTINGS_ROOT + "slot_index_file"
const SETTING_STORAGE_FORMAT := SETTINGS_ROOT + "storage_format"
const SETTING_PRETTY_JSON_IN_EDITOR := SETTINGS_ROOT + "pretty_json_in_editor"
const SETTING_USE_SAFE_WRITE := SETTINGS_ROOT + "use_safe_write"
const SETTING_KEEP_LAST_BACKUP := SETTINGS_ROOT + "keep_last_backup"
const SETTING_FILE_EXTENSION_JSON := SETTINGS_ROOT + "file_extension_json"
const SETTING_FILE_EXTENSION_BINARY := SETTINGS_ROOT + "file_extension_binary"
const SETTING_LOG_LEVEL := SETTINGS_ROOT + "log_level"
const SETTING_INCLUDE_META_IN_SLOT_FILE := SETTINGS_ROOT + "include_meta_in_slot_file"
const SETTING_AUTO_CREATE_DIRS := SETTINGS_ROOT + "auto_create_dirs"
const SETTING_PROJECT_TITLE := SETTINGS_ROOT + "project_title"
const SETTING_GAME_VERSION := SETTINGS_ROOT + "game_version"
const SETTING_DATA_VERSION := SETTINGS_ROOT + "data_version"
const SETTING_SAVE_SCHEMA := SETTINGS_ROOT + "save_schema"
const SETTING_ENFORCE_SAVE_SCHEMA_MATCH := SETTINGS_ROOT + "enforce_save_schema_match"
const SETTING_ENFORCE_DATA_VERSION_MATCH := SETTINGS_ROOT + "enforce_data_version_match"
const SETTING_VERIFY_SCENE_PATH_ON_LOAD := SETTINGS_ROOT + "verify_scene_path_on_load"


## Register the SaveFlow Lite project settings keys so they appear in the
## project settings database with stable defaults and hints.
static func register_project_settings() -> void:
	_register(SETTING_SAVE_ROOT, "user://saves", TYPE_STRING)
	_register(SETTING_SLOT_INDEX_FILE, "user://saves/slots.index", TYPE_STRING)
	_register(SETTING_STORAGE_FORMAT, FORMAT_AUTO, TYPE_INT)
	_register(SETTING_PRETTY_JSON_IN_EDITOR, true, TYPE_BOOL)
	_register(SETTING_USE_SAFE_WRITE, true, TYPE_BOOL)
	_register(SETTING_KEEP_LAST_BACKUP, true, TYPE_BOOL)
	_register(SETTING_FILE_EXTENSION_JSON, "json", TYPE_STRING)
	_register(SETTING_FILE_EXTENSION_BINARY, "sav", TYPE_STRING)
	_register(SETTING_LOG_LEVEL, 2, TYPE_INT)
	_register(SETTING_INCLUDE_META_IN_SLOT_FILE, true, TYPE_BOOL)
	_register(SETTING_AUTO_CREATE_DIRS, true, TYPE_BOOL)
	_register(SETTING_PROJECT_TITLE, "", TYPE_STRING)
	_register(SETTING_GAME_VERSION, "", TYPE_STRING)
	_register(SETTING_DATA_VERSION, 1, TYPE_INT)
	_register(SETTING_SAVE_SCHEMA, "main", TYPE_STRING)
	_register(SETTING_ENFORCE_SAVE_SCHEMA_MATCH, true, TYPE_BOOL)
	_register(SETTING_ENFORCE_DATA_VERSION_MATCH, true, TYPE_BOOL)
	_register(SETTING_VERIFY_SCENE_PATH_ON_LOAD, true, TYPE_BOOL)


## Build a SaveSettings resource from the current project-level defaults.
static func load_settings() -> SaveSettings:
	register_project_settings()

	var settings := SaveSettings.new()
	settings.save_root = String(ProjectSettings.get_setting(SETTING_SAVE_ROOT, settings.save_root))
	settings.slot_index_file = String(ProjectSettings.get_setting(SETTING_SLOT_INDEX_FILE, settings.slot_index_file))
	settings.storage_format = int(ProjectSettings.get_setting(SETTING_STORAGE_FORMAT, settings.storage_format))
	settings.pretty_json_in_editor = bool(ProjectSettings.get_setting(SETTING_PRETTY_JSON_IN_EDITOR, settings.pretty_json_in_editor))
	settings.use_safe_write = bool(ProjectSettings.get_setting(SETTING_USE_SAFE_WRITE, settings.use_safe_write))
	settings.keep_last_backup = bool(ProjectSettings.get_setting(SETTING_KEEP_LAST_BACKUP, settings.keep_last_backup))
	settings.file_extension_json = String(ProjectSettings.get_setting(SETTING_FILE_EXTENSION_JSON, settings.file_extension_json))
	settings.file_extension_binary = String(ProjectSettings.get_setting(SETTING_FILE_EXTENSION_BINARY, settings.file_extension_binary))
	settings.log_level = int(ProjectSettings.get_setting(SETTING_LOG_LEVEL, settings.log_level))
	settings.include_meta_in_slot_file = bool(ProjectSettings.get_setting(SETTING_INCLUDE_META_IN_SLOT_FILE, settings.include_meta_in_slot_file))
	settings.auto_create_dirs = bool(ProjectSettings.get_setting(SETTING_AUTO_CREATE_DIRS, settings.auto_create_dirs))
	settings.project_title = String(ProjectSettings.get_setting(SETTING_PROJECT_TITLE, settings.project_title))
	settings.game_version = String(ProjectSettings.get_setting(SETTING_GAME_VERSION, settings.game_version))
	settings.data_version = int(ProjectSettings.get_setting(SETTING_DATA_VERSION, settings.data_version))
	settings.save_schema = String(ProjectSettings.get_setting(SETTING_SAVE_SCHEMA, settings.save_schema))
	settings.enforce_save_schema_match = bool(ProjectSettings.get_setting(SETTING_ENFORCE_SAVE_SCHEMA_MATCH, settings.enforce_save_schema_match))
	settings.enforce_data_version_match = bool(ProjectSettings.get_setting(SETTING_ENFORCE_DATA_VERSION_MATCH, settings.enforce_data_version_match))
	settings.verify_scene_path_on_load = bool(ProjectSettings.get_setting(SETTING_VERIFY_SCENE_PATH_ON_LOAD, settings.verify_scene_path_on_load))
	return settings


## Persist a SaveSettings resource into ProjectSettings so the editor dock and
## the SaveFlow runtime share one source of truth.
static func save_settings(settings: SaveSettings) -> void:
	register_project_settings()

	ProjectSettings.set_setting(SETTING_SAVE_ROOT, settings.save_root)
	ProjectSettings.set_setting(SETTING_SLOT_INDEX_FILE, settings.slot_index_file)
	ProjectSettings.set_setting(SETTING_STORAGE_FORMAT, settings.storage_format)
	ProjectSettings.set_setting(SETTING_PRETTY_JSON_IN_EDITOR, settings.pretty_json_in_editor)
	ProjectSettings.set_setting(SETTING_USE_SAFE_WRITE, settings.use_safe_write)
	ProjectSettings.set_setting(SETTING_KEEP_LAST_BACKUP, settings.keep_last_backup)
	ProjectSettings.set_setting(SETTING_FILE_EXTENSION_JSON, settings.file_extension_json)
	ProjectSettings.set_setting(SETTING_FILE_EXTENSION_BINARY, settings.file_extension_binary)
	ProjectSettings.set_setting(SETTING_LOG_LEVEL, settings.log_level)
	ProjectSettings.set_setting(SETTING_INCLUDE_META_IN_SLOT_FILE, settings.include_meta_in_slot_file)
	ProjectSettings.set_setting(SETTING_AUTO_CREATE_DIRS, settings.auto_create_dirs)
	ProjectSettings.set_setting(SETTING_PROJECT_TITLE, settings.project_title)
	ProjectSettings.set_setting(SETTING_GAME_VERSION, settings.game_version)
	ProjectSettings.set_setting(SETTING_DATA_VERSION, settings.data_version)
	ProjectSettings.set_setting(SETTING_SAVE_SCHEMA, settings.save_schema)
	ProjectSettings.set_setting(SETTING_ENFORCE_SAVE_SCHEMA_MATCH, settings.enforce_save_schema_match)
	ProjectSettings.set_setting(SETTING_ENFORCE_DATA_VERSION_MATCH, settings.enforce_data_version_match)
	ProjectSettings.set_setting(SETTING_VERIFY_SCENE_PATH_ON_LOAD, settings.verify_scene_path_on_load)
	ProjectSettings.save()


## Restore the Lite project settings to their shipped defaults and return the
## resulting SaveSettings resource.
static func reset_to_defaults() -> SaveSettings:
	var defaults := SaveSettings.new()
	save_settings(defaults)
	return defaults


static func _register(path: String, default_value: Variant, type_hint: int) -> void:
	if not ProjectSettings.has_setting(path):
		ProjectSettings.set_setting(path, default_value)
	ProjectSettings.set_initial_value(path, default_value)

	var property_info := {
		"name": path,
		"type": type_hint,
	}
	if path == SETTING_STORAGE_FORMAT:
		property_info["hint"] = PROPERTY_HINT_ENUM
		property_info["hint_string"] = "Auto,JSON,Binary"
	elif path == SETTING_LOG_LEVEL:
		property_info["hint"] = PROPERTY_HINT_ENUM
		property_info["hint_string"] = "Quiet,Error,Info,Verbose"
	elif path == SETTING_DATA_VERSION:
		property_info["hint"] = PROPERTY_HINT_RANGE
		property_info["hint_string"] = "1,1000,1"
	ProjectSettings.add_property_info(property_info)
