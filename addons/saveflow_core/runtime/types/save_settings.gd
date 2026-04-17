## SaveSettings stores the project-wide defaults used by the SaveFlow runtime.
## In Lite, these values are edited through the SaveFlow Settings dock rather
## than repeated on every source or slot call.
class_name SaveSettings
extends Resource

## Root directory for slot payload files. Keep this under `user://` unless you
## deliberately need a platform-specific external path.
@export var save_root: String = "user://saves"
## Path to the slot index file. Change this only when the whole project should
## maintain its slot catalog somewhere else.
@export var slot_index_file: String = "user://saves/slots.index"
## Default save format used by `SaveFlow`. `Auto` keeps JSON in editor and
## binary in exported builds, which is the recommended Lite default.
@export var storage_format: int = 0
## Pretty-print JSON while working in the editor. This improves inspection and
## diff readability, but it should not be treated as an exported-build feature.
@export var pretty_json_in_editor: bool = true
## Write to a temp file first, then replace the final slot file. Keep this on
## unless you have a very specific platform reason to skip safe writes.
@export var use_safe_write: bool = true
## File extension used when JSON is the resolved storage format.
@export var file_extension_json: String = "json"
## File extension used when binary is the resolved storage format.
@export var file_extension_binary: String = "sav"
## Runtime logging verbosity for the SaveFlow singleton.
@export var log_level: int = 2
## Include slot metadata in the index file so slot lists can be rendered
## without opening every payload file.
@export var include_meta_in_slot_file: bool = true
## Automatically create the parent save directories before writing files.
@export var auto_create_dirs: bool = true
## Project-level title used as the default slot display name and metadata label
## when the caller does not provide a custom display name.
@export var project_title: String = ""
## Default game version written into slot metadata.
@export var game_version: String = ""
## Default data version written into slot metadata. Increment this when the
## project-level save structure changes in a meaningful way.
@export var data_version: int = 1
## Logical save schema identifier written into slot metadata. Use this when the
## project distinguishes several save graphs or storage schemas.
@export var save_schema: String = "main"
