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
func save_named_entry(_entry_name: String) -> SaveResult:
	var result := SaveResult.new()
	result.ok = false
	result.error_code = SaveError.INVALID_SAVEABLE
	result.error_key = "SAVE_MANAGER_BRIDGE_NOT_IMPLEMENTED"
	result.error_message = "save_named_entry() is not implemented on this SaveFlowSaveManagerBridge."
	return result


## Override in game code to load a named save entry.
func load_named_entry(_entry_name: String) -> SaveResult:
	var result := SaveResult.new()
	result.ok = false
	result.error_code = SaveError.INVALID_SAVEABLE
	result.error_key = "SAVE_MANAGER_BRIDGE_NOT_IMPLEMENTED"
	result.error_message = "load_named_entry() is not implemented on this SaveFlowSaveManagerBridge."
	return result
