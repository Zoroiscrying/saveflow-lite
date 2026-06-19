---
sidebar_position: 3
title: Player Slots And Records
---

SaveFlow separates the player's save slot from the stored records under that
slot.

The player-facing concept is the slot:

```text
slot_1
```

The developer-facing storage shape is:

```text
slot_1
|- main
|- scene:res://world/project_room_dungeon.tscn
|- scope:res://world/project_room_dungeon.tscn:room
|- custom:quest_log
```

This lets one playthrough keep one stable slot while different gameplay
domains can still be saved, loaded, inspected, backed up, and migrated as
separate records.

## Slot

A slot is the stable identity that a player understands.

Use the same `slot_id` for a playthrough:

- manual save
- autosave
- checkpoint
- scene save
- scope save
- custom domain save

The slot is what a save menu should present as "Slot 1", "Village Start", or
"Chapter 2".

Do not create a new player slot just because the project changes scene.
Changing scene should usually change the active record under the same slot.

## Record

A record is one saved payload inside a slot.

SaveFlow uses records so a single slot can own more than one physical save file
or payload boundary.

Common record kinds:

| Kind | Meaning |
| --- | --- |
| `main` | The legacy/default slot payload. |
| `scene` | A scene graph payload saved for a specific scene target. |
| `scope` | A scope graph payload saved for a specific scene and scope target. |
| `custom` | Project-owned payloads written through explicit record calls. |

`save_slot()`, `load_slot()`, `save_data()`, and `load_data()` operate on the
`main` record.

`save_scene()` and `load_scene()` use a scene-qualified record key.

`save_scope()` and `load_scope()` use a scene-and-scope-qualified record key.
That means two different scenes can both have a `room` Scope without silently
reading each other's saved record.

## Why Scene Qualification Matters

Scope keys are local to a save graph.

This is normal:

```text
res://world/forest_room.tscn
|- RoomScope(scope_key = "room")

res://world/dungeon_room.tscn
|- RoomScope(scope_key = "room")
```

The player still expects both rooms to belong to the same slot:

```text
slot_1
```

But the project expects them to restore different records:

```text
slot_1 / scope:res://world/forest_room.tscn:room
slot_1 / scope:res://world/dungeon_room.tscn:room
```

Without the scene path in the record identity, those two `room` scopes would be
ambiguous.

## Storage Shape

SaveFlow can keep a slot file for the `main` record and a slot folder for
additional records.

The exact extension follows the configured storage format, but the practical
shape is:

```text
user://saves/
|- slot_1.sav
|- slot_1/
|  |- scene_res___world_project_room_dungeon.tscn.sav
|  |- scope_res___world_project_room_dungeon.tscn_room.sav
```

The slot index tracks the records that belong to each slot so editor tools and
runtime code can list them without guessing from filenames alone.

## What Save Menus Should Show

Most player UI should still show slots, not every record.

Good save menu:

```text
Slot 1 - Village Start - Chapter 1 - 00:16:00
```

Good developer inspector:

```text
slot_1
|- main
|- forest room scope
|- dungeon room scope
```

That split is important:

- players choose a playthrough
- developers inspect the records that make that playthrough complete

## Compatibility And Migration

Compatibility belongs to each record as well as the slot summary.

A slot may contain:

- a compatible `main` record
- an outdated scene record
- a missing scope record
- a custom record with a schema conflict

Lite reports baseline compatibility and storage issues.
SaveFlow Pro uses the same model to inspect records, show diagnostics, and run
migration decisions before release.

Editor tools read this same structure. DevSaveManager uses it to separate dev
snapshots from formal slot-index saves, and SaveFlow Pro's Save Files tab uses
it to group physical files, slots, records, diagnostics, and payload edits.

## Product Boundary

This model belongs to Lite/Core.

SaveFlow Pro does not define what a slot or record means.
Pro makes the existing model easier to inspect, search, diagnose, migrate, and
release safely.
