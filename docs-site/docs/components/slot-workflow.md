---
sidebar_position: 6
title: Slot Workflow
---

Use `SaveFlowSlotWorkflow` when the user story is:

> Build a save menu without rewriting slot IDs, metadata, and save cards every time.

SaveFlow deliberately does not own "the player's current slot".
That state belongs to the project.
`SaveFlowSlotWorkflow` keeps it explicit while removing repeated glue.

![SaveFlow slot workflow](/img/saveflow/slot-workflow.svg)

## What It Owns

`SaveFlowSlotWorkflow` owns:

- active slot index
- slot ID template
- empty display-name template
- slot ID overrides
- metadata construction
- empty save-card construction
- save-card construction from slot summaries

It does not save gameplay data by itself.

## Recommended Shape

```gdscript
var slot_workflow := SaveFlowSlotWorkflow.new()

func select_slot(slot_index: int) -> void:
	slot_workflow.select_slot_index(slot_index)

func save_active_slot(scope: SaveFlowScope) -> void:
	var metadata := slot_workflow.build_active_slot_metadata(
		"Village Start",
		"manual",
		"Chapter 1",
		"Forest Gate",
		960
	)
	SaveFlow.save_scope(slot_workflow.active_slot_id(), scope, metadata)
```

## Save Card Menu

Use cards to render a save/load menu without loading every full payload.

```gdscript
func refresh_cards() -> Array:
	var summaries_result := SaveFlow.list_slot_summaries()
	if not summaries_result.ok:
		return []
	return slot_workflow.build_cards_for_indices(
		PackedInt32Array([1, 2, 3]),
		summaries_result.data
	)
```

Each card contains user-facing fields such as display name, chapter, location,
playtime, save type, active state, and compatibility status.

## Autosave And Checkpoint

Autosave and checkpoint usually write the active slot.

```gdscript
func trigger_autosave(scope: SaveFlowScope) -> void:
	var metadata := slot_workflow.build_active_slot_metadata(
		"",
		"autosave",
		"Chapter 1",
		"West Room",
		_current_playtime_seconds
	)
	SaveFlow.save_scope(slot_workflow.active_slot_id(), scope, metadata)
```

This keeps autosave understandable:

- the active slot is still the storage target
- metadata records that the write was an autosave
- the save menu can display the new slot state through cards

## Slot ID vs Metadata

Keep storage identity stable.

Keep player-facing naming in metadata.

Good:

```text
slot_id = slot_1
display_name = Village Start
save_type = manual
```

Avoid using player-facing names as storage IDs.
Names change; storage keys should not.
