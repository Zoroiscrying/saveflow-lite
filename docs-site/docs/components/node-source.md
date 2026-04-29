---
sidebar_position: 2
title: SaveFlowNodeSource
---

Use `SaveFlowNodeSource` when the user story is:

> Save this Godot object.

It is the main object-facing Source in Lite.

![SaveFlowNodeSource inspector preview](/img/saveflow/SaveFlowNodeSource.png)

## What It Saves

`SaveFlowNodeSource` can save:

- exported fields on the target node
- selected additional properties
- built-in Godot node state
- selected child participants that belong to the same object

Common built-in state includes transforms, controls, animation players, sprites,
cameras, timers, audio players, physics nodes, sensors, navigation agents, and
tile runtime edits.

## Recommended Scene Shape

```text
Player
|- Sprite2D
|- AnimationPlayer
|- SaveFlowNodeSource
```

Leave `target` empty when the Source sits under or near the object it saves.
Only set `target` explicitly when one object intentionally owns save logic for a
different node.

## Property Selection

Use exported fields for project-owned gameplay state.

Use additional properties when a real saved value is not exported.

Use ignored properties when an exported field exists for editor convenience but
should not survive save/load.

If the additional-property list grows large, the object probably wants cleaner
exported fields or a custom Source.

## Child Participants

Include children only when they are part of the same saved object.

Good examples:

- `AnimationPlayer` under `Player`
- `Sprite2D` under `Chest`
- local `Timer` under `Trap`

Avoid including:

- another object with its own Source
- a runtime entity container
- a scene-wide manager

Use direct discovery for simple prefab shapes.
Use recursive discovery only when meaningful participants live deeper in the
tree.

## Warnings To Respect

`SaveFlowNodeSource` warns about:

- missing target nodes
- missing child participants
- missing selected properties
- stale built-in selections
- invalid built-in field overrides
- nested Source ownership mistakes
- runtime entity container double-collection

These warnings are not noise.
They usually mean the graph would load in a surprising order or save the same
object twice.

When a child Source is nested under the helper instead of the gameplay object,
the inspector preview marks the Source invalid and explains where that child
should move.

![SaveFlowNodeSource inspector preview showing an included child ownership warning](/img/saveflow/screenshots/editor-node-source-warning.png)
