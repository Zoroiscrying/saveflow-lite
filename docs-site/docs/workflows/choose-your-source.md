---
sidebar_position: 1
title: Choose Your Source
---

Start with the shape of the gameplay data, not the SaveFlow class list.

![SaveFlow source decision flow](/img/saveflow/source-decision-flow.svg)

## Fast Decision Table

| Your data looks like | Start with | Why |
| --- | --- | --- |
| One scene object owns visible Godot node state | `SaveFlowNodeSource` | The object can gather built-in node state and selected child participants. |
| One GDScript system/model owns typed fields | `SaveFlowTypedDataSource` | The data shape is typed, but SaveFlow still stores a Variant payload. |
| One C# DTO/state object owns the data | `SaveFlowTypedStateSource` | The C# source owns source-generated JSON payload lifecycle. |
| One runtime set changes during gameplay | `SaveFlowEntityCollectionSource` | The list needs identity, descriptors, and factory restore. |
| Several Sources should save/load together | `SaveFlowScope` | The domain needs an explicit boundary. |
| You need project-specific gather/apply logic | `SaveFlowDataSource` | The state is too custom for built-ins or typed helpers. |

## I Need To Save One Node

Use `SaveFlowNodeSource`.

This is the right default for scene-authored Godot objects:

- transform
- animation state
- common control values
- selected child node state

If the data is already visible as node properties, a built-in selection may be
enough.

Do not use it as a vacuum cleaner for an entire scene.
If a child object already has its own Source, include that Source directly.

## I Need To Save One Typed Model

Use `SaveFlowTypedDataSource` in GDScript or `SaveFlowTypedStateSource` in C#.

This is the right default for system data:

- settings
- profile state
- chapter progress
- inventory counters

Prefer typed fields over raw dictionaries when the data shape belongs to your
project.

Use a custom `SaveFlowDataSource` only when the system really needs custom
gather/apply logic.

## I Need To Save Runtime Objects

Use `SaveFlowEntityCollectionSource`.

This is the right default for objects that appear and disappear during gameplay:

- pickups
- enemies
- dropped items
- spawned actors

Each entity needs a stable identity and enough descriptor data for a factory to
restore it.

Use `Clear And Restore` when stale runtime children must never survive load.
Use `Create Missing` when the collection may already contain some valid
entities and only missing ones should be spawned.

## I Need To Save A Domain

Use `SaveFlowScope`.

This is the right default when several Sources form one domain:

- profile
- world
- room
- settings

Save and load the Scope when your gameplay workflow wants that domain to move
together.

## Wrong Turns To Avoid

Do not use `SaveFlowScope` when the real answer is still "save this object".

Do not make a parent `SaveFlowNodeSource` recursively save a runtime entity
container.

Do not store UI text as save data if the UI can be rebuilt from gameplay data.

Do not use raw dictionaries for project-owned data when typed data or typed
state would be clearer.
