---
sidebar_position: 1
slug: /
title: SaveFlow Lite Docs
---

SaveFlow Lite is a comfort-first save workflow plugin for Godot 4.

It helps you build a project-ready save system by putting save ownership in the
scene tree instead of hiding everything inside one large save script.

For a game project, install from the Godot Asset Library or the
`saveflow-lite-vX.Y.Z-addons.zip` release package. Repository-only paths such as
`docs-site`, `tmp`, `.github`, tests, and release tooling should stay out of
your Godot project.

![SaveFlow save graph overview](/img/saveflow/savegraph-overview.svg)

Use this documentation to answer three questions:

- Which part of my game owns this saved data?
- Which SaveFlow Source should write and restore it?
- Which workflow should I copy into my Godot project?

## First Mental Model: Slots Own Records

SaveFlow is organized around a stable player slot with one or more save records
inside it.

```text
Player view:
Slot 1

Developer view:
slot_1
|- main
|- scene:res://world/forest_room.tscn
|- scope:res://world/forest_room.tscn:room
|- custom:quest_log
```

Most player-facing UI should show slots. Most developer-facing tools should show
the records inside each slot.

This matters before you choose an API:

- `save_data()` and `save_slot()` write the slot's `main` record
- `save_scene()` writes a scene-qualified record under the same slot
- `save_scope()` writes a scene-and-scope-qualified record under the same slot
- `list_slot_records()` is for tools, QA, diagnostics, and migration work

Changing scene should usually keep the same `slot_id` and change the record that
is read or written.

## What Lite Covers

SaveFlow Lite focuses on the baseline save model:

- explicit Save Graph composition
- node state through `SaveFlowNodeSource`
- typed GDScript data through `SaveFlowTypedDataSource`
- typed C# state through `SaveFlowTypedStateSource`
- runtime-spawned objects through `SaveFlowEntityCollectionSource`
- domain boundaries through `SaveFlowScope`
- player slots with multiple records, slot metadata, active slots, save cards,
  autosave, and checkpoint examples
- editor diagnostics, scene validator feedback, and setup health checks

## What Lite Does Not Try To Be

Lite does not try to become a full commercial orchestration layer.

Advanced workflows such as staged multi-scene restore, migration pipelines,
cloud conflict handling, storage profiles, reference repair, and seamless
background saves belong to SaveFlow Pro.

## Recommended Reading Path

1. Install the plugin from the Asset Library or release zip and confirm the editor tools are visible.
2. Learn how player slots and save records fit together.
3. Build your first Save Graph.
4. Learn the ownership model.
5. Copy the common API calls into your first save/load buttons.
6. Choose the right Source for each kind of data.
7. Open the recommended template and compare the docs to the scene tree.
8. Use the Examples One-Page Starter to decide which demo to open next.
9. Use Reference when you need exact method names, properties, and signals.

## The Short Version

If the thing being saved is "this object", start with `SaveFlowNodeSource`.

If the thing being saved is "this typed system model", start with
`SaveFlowTypedDataSource` in GDScript or `SaveFlowTypedStateSource` in C#.

If the thing being saved is "this changing runtime set", start with
`SaveFlowEntityCollectionSource` and an entity factory.

If several Sources form one gameplay domain, group them with `SaveFlowScope`.
