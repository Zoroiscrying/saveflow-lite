## SaveFlowSaveManagerBridge connects the editor save manager dock to actual
## runtime save/load logic while the game is running.
class_name SaveFlowSaveManagerBridge
extends Node


## Disable the bridge without unregistering it when a game state temporarily
## should not answer save-manager requests.
func is_bridge_enabled() -> bool:
	return true


## Name shown in the editor save manager status area.
func get_bridge_name() -> String:
	return name if not name.is_empty() else "SaveFlowSaveManagerBridge"


## Optional dedicated settings for DevSaveManager entries. Return an empty
## dictionary to let the editor fall back to the runtime's normal save root.
func get_dev_save_settings() -> Dictionary:
	return {}


## Override in game code to capture a named save entry.
func save_named_entry(entry_name: String) -> SaveResult:
	var runtime := _resolve_saveflow_runtime()
	if runtime == null or not runtime.has_method("save_dev_named_entry"):
		return _error("SaveFlow runtime cannot handle save_named_entry(). Ensure the SaveFlow autoload is running.")
	return runtime.call("save_dev_named_entry", entry_name)


## Override in game code to load a named save entry.
func load_named_entry(entry_name: String) -> SaveResult:
	var runtime := _resolve_saveflow_runtime()
	if runtime == null or not runtime.has_method("load_dev_named_entry"):
		return _error("SaveFlow runtime cannot handle load_named_entry(). Ensure the SaveFlow autoload is running.")
	return runtime.call("load_dev_named_entry", entry_name)


func _resolve_saveflow_runtime() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().root.get_node_or_null("/root/SaveFlow")


func _error(message: String) -> SaveResult:
	var result := SaveResult.new()
	result.ok = false
	result.error_code = SaveError.INVALID_SAVEABLE
	result.error_key = "SAVE_MANAGER_BRIDGE_ERROR"
	result.error_message = message
	return result
