---
sidebar_position: 2
title: Build Your First Save Graph
---

A Save Graph is the set of scene-authored SaveFlow components that decide what
gets saved and restored.

The smallest useful graph is one Source under one scene root.
The first real project graph is usually one or more Sources grouped under a
`SaveFlowScope`.

## Minimal Object Save

Use `SaveFlowNodeSource` when your goal is:

> Save this Godot object.

Typical examples:

- player position
- a door's open/closed state
- a UI control value
- an `AnimationPlayer` playback state

Workflow:

1. Select the node that owns the state.
2. Add a `SaveFlowNodeSource` near that node.
3. Give the Source a stable save key.
4. Choose built-in node state or selected child nodes.
5. Run the scene and test save/load through `DevSaveManager`.

Example tree:

```text
Player
|- Sprite2D
|- AnimationPlayer
|- SaveFlowNodeSource
```

In this shape, the player owns its own save data.
The `AnimationPlayer` can participate as a child only if it is part of the same
saved object.

## Minimal System Save

Use `SaveFlowTypedDataSource` when your goal is:

> Save this small typed model.

Examples:

- player profile data
- game settings
- unlocked flags
- chapter progress

Export typed fields on a `SaveFlowTypedData` script and let the Source gather
and apply the data without hand-maintaining dictionary keys.

Example tree:

```text
SaveGraph
|- ProfileStateSource
```

`ProfileStateSource` can point at a typed Resource or at a manager node that
exposes a SaveFlow payload contract.

## Minimal Runtime Entity Save

Use `SaveFlowEntityCollectionSource` when your goal is:

> Save objects that can be spawned, collected, destroyed, or restored at runtime.

Examples:

- dropped coins
- spawned enemies
- pickups
- runtime actors

Each entity needs stable identity data, and the collection needs a factory that
knows how to recreate saved entity descriptors.

Example tree:

```text
RuntimeCoins
|- Coin_001
|  |- SaveFlowIdentity
|- Coin_002
|  |- SaveFlowIdentity
|- SaveFlowEntityCollectionSource
|- SaveFlowPrefabEntityFactory
```

The collection Source owns the list.
The factory owns how missing entities are created during load.

## Minimal Scope Save

Use `SaveFlowScope` when your goal is:

> Save this domain.

Example tree:

```text
RoomScope
|- PlayerStateSource
|- RoomStateSource
|- RuntimeCoinsSource
```

Then call:

```gdscript
var metadata := SaveFlowSlotMetadata.new()
metadata.slot_id = "slot_1"
metadata.display_name = "First Save"
metadata.save_type = "manual"

var save_result := SaveFlow.save_scope("slot_1", $RoomScope, metadata)
if not save_result.ok:
	push_warning(save_result.message)

var load_result := SaveFlow.load_scope("slot_1", $RoomScope)
if not load_result.ok:
	push_warning(load_result.message)
```

The Scope does not replace object ownership.
It groups Sources that already know how to save their own data.

## Common Calls You Will Use Immediately

After your first Scope exists, most early gameplay code looks like this:

```gdscript
@onready var room_scope: SaveFlowScope = $RoomScope

var slot_workflow := SaveFlowSlotWorkflow.new()

func _ready() -> void:
	slot_workflow.select_slot_index(1)

func save_game() -> void:
	var metadata := slot_workflow.build_active_slot_metadata(
		"Village Start",
		"manual",
		"Chapter 1",
		"Forest Gate",
		960
	)
	var result := SaveFlow.save_scope(slot_workflow.active_slot_id(), room_scope, metadata)
	if not result.ok:
		push_warning(result.message)

func load_game() -> void:
	var result := SaveFlow.load_scope(slot_workflow.active_slot_id(), room_scope)
	if not result.ok:
		push_warning(result.message)

func refresh_save_cards() -> Array:
	var summaries := SaveFlow.list_slot_summaries()
	if not summaries.ok:
		return []
	return slot_workflow.build_cards_for_indices(PackedInt32Array([1, 2, 3]), summaries.data)

func delete_current_slot() -> void:
	var result := SaveFlow.delete_slot(slot_workflow.active_slot_id())
	if not result.ok:
		push_warning(result.message)
```

The important parts are:

- `slot_workflow` owns the selected slot index and slot ID format.
- `metadata` stores player-facing save-card information.
- `save_scope()` writes one explicit domain.
- `load_scope()` restores that currently loaded domain.
- `list_slot_summaries()` lets UI draw save cards without loading full payloads.
