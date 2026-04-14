class_name SaveSettings
extends Resource

@export var save_root: String = "user://saves"
@export var slot_index_file: String = "user://saves/slots.index"
@export var storage_format: int = 0
@export var pretty_json_in_editor: bool = true
@export var use_safe_write: bool = true
@export var file_extension_json: String = "json"
@export var file_extension_binary: String = "sav"
@export var log_level: int = 2
@export var include_meta_in_slot_file: bool = true
@export var auto_create_dirs: bool = true
