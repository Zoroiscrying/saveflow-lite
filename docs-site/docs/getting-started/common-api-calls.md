---
sidebar_position: 3
title: Common API Calls
---

This page is the quick copy/paste layer.

Use it after you understand the basic Save Graph idea and need to wire buttons,
menus, autosave zones, or debug shortcuts.

## Save A Scope

Use this when one gameplay domain owns the save/load boundary.

```gdscript
@onready var room_scope: SaveFlowScope = $RoomScope

func save_room() -> void:
	var metadata := SaveFlowSlotMetadata.new()
	metadata.slot_id = "slot_1"
	metadata.display_name = "Village Start"
	metadata.save_type = "manual"
	metadata.chapter_name = "Chapter 1"
	metadata.location_name = "Forest Gate"
	metadata.playtime_seconds = 960

	var result := SaveFlow.save_scope("slot_1", room_scope, metadata)
	if not result.ok:
		push_warning(result.message)
```

## Load A Scope

The target Scope and its Sources must already exist in the currently loaded
scene.

```gdscript
func load_room() -> void:
	var result := SaveFlow.load_scope("slot_1", room_scope)
	if not result.ok:
		push_warning(result.message)
```

Use `strict: true` only when missing Sources should fail the load:

```gdscript
SaveFlow.load_scope("slot_1", room_scope, true)
```

## Save And Load A Scene Graph

Use this when the scene's Sources are discovered from the `saveflow` group.

```gdscript
func save_current_scene() -> void:
	var result := SaveFlow.save_scene("slot_1", get_tree().current_scene)
	if not result.ok:
		push_warning(result.message)

func load_current_scene() -> void:
	var result := SaveFlow.load_scene("slot_1", get_tree().current_scene)
	if not result.ok:
		push_warning(result.message)
```

Most project-ready workflows should still prefer `save_scope()` when a domain
boundary is clear.

## Use Active Slot Helpers

Use `SaveFlowSlotWorkflow` when a menu or gameplay session has a selected slot.

```gdscript
var slot_workflow := SaveFlowSlotWorkflow.new()

func select_slot(slot_index: int) -> void:
	slot_workflow.select_slot_index(slot_index)

func active_slot_id() -> String:
	return slot_workflow.active_slot_id()
```

Build metadata for the active slot:

```gdscript
func build_metadata(save_type: String) -> SaveFlowSlotMetadata:
	return slot_workflow.build_active_slot_metadata(
		"",
		save_type,
		"Chapter 1",
		"Forest Gate",
		_current_playtime_seconds
	)
```

## Manual Save

```gdscript
func manual_save() -> void:
	var metadata := build_metadata("manual")
	var result := SaveFlow.save_scope(slot_workflow.active_slot_id(), room_scope, metadata)
	if not result.ok:
		push_warning(result.message)
```

## Autosave

Autosave usually writes the active slot without opening a menu.

```gdscript
func trigger_autosave() -> void:
	var metadata := build_metadata("autosave")
	var result := SaveFlow.save_scope(slot_workflow.active_slot_id(), room_scope, metadata)
	if not result.ok:
		push_warning(result.message)
```

## Checkpoint Save

Checkpoint is a gameplay recovery marker.
It usually writes the active slot with checkpoint metadata.

```gdscript
func trigger_checkpoint() -> void:
	var metadata := build_metadata("checkpoint")
	metadata.location_name = "West Room Checkpoint"
	var result := SaveFlow.save_scope(slot_workflow.active_slot_id(), room_scope, metadata)
	if not result.ok:
		push_warning(result.message)
```

## Build Save Cards For UI

Use summaries and cards to draw a save menu without loading every full payload.

```gdscript
func build_save_cards() -> Array:
	var summaries := SaveFlow.list_slot_summaries()
	if not summaries.ok:
		push_warning(summaries.message)
		return []

	return slot_workflow.build_cards_for_indices(
		PackedInt32Array([1, 2, 3]),
		summaries.data
	)
```

Each card can drive a UI card:

```gdscript
for card in build_save_cards():
	print(card.display_name, " ", card.location_name, " ", card.save_type)
```

## Read One Slot Summary

```gdscript
func print_slot_summary(slot_id: String) -> void:
	var result := SaveFlow.read_slot_summary(slot_id)
	if not result.ok:
		push_warning(result.message)
		return
	print(result.data)
```

## Delete A Slot

```gdscript
func delete_selected_slot() -> void:
	var result := SaveFlow.delete_slot(slot_workflow.active_slot_id())
	if not result.ok:
		push_warning(result.message)
```

## Check Compatibility Before Loading

```gdscript
func can_load_slot(slot_id: String) -> bool:
	var result := SaveFlow.inspect_slot_compatibility(slot_id)
	if not result.ok:
		push_warning(result.message)
		return false
	return bool(result.data.get("compatible", false))
```

Compatibility checks report schema/data-version safety.
They do not run Pro migration.

## Store A Raw Payload

Use `save_data()` only when your code already owns the whole payload.

```gdscript
func save_settings_payload() -> void:
	var payload := {
		"volume": 0.8,
		"language": "en",
	}
	SaveFlow.save_data("settings", payload)
```

For gameplay scene state, use Sources and Scopes instead.

## C# Equivalent

In C#, the same Scope workflow is:

```csharp
var workflow = new SaveFlowSlotWorkflow();
workflow.SelectSlotIndex(1);

var metadata = workflow.BuildActiveSlotMetadata(
	displayName: "Village Start",
	saveType: "manual",
	chapterName: "Chapter 1",
	locationName: "Forest Gate",
	playtimeSeconds: 960);

var result = SaveFlowClient.SaveScope(workflow.ActiveSlotId(), roomScope, metadata);
if (!result.Ok)
{
	GD.PushWarning(result.Message);
}
```

See the C# page and C# API reference when you need the full wrapper surface.
