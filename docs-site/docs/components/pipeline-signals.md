---
sidebar_position: 6
title: Pipeline Signals
---

Use `SaveFlowPipelineSignals` when the user story is:

> React to save/load lifecycle events without subclassing every Source.

Pipeline signals are scene-authored event bridges.
They are not saved as gameplay data.

![SaveFlow pipeline signals flow](/img/saveflow/pipeline-signals-flow.svg)

## Common Uses

Use pipeline signals for:

- "Data Saved!" toast messages
- analytics or debug logging
- disabling UI during load
- refreshing derived UI after load
- cancelling or warning around unsafe actions

## Signal Shape

`SaveFlowPipelineSignals` exposes lifecycle signals such as:

- `before_save`
- `after_gather`
- `before_write`
- `after_write`
- `before_load`
- `after_read`
- `before_apply`
- `after_load`
- `before_gather_source`
- `after_gather_source`
- `before_apply_source`
- `after_apply_source`
- `pipeline_error`

Each signal receives a `SaveFlowPipelineEvent`.

Example scene behavior:

```gdscript
func _on_after_write(event: SaveFlowPipelineEvent) -> void:
	_show_toast("Data Saved")

func _on_after_gather_source(event: SaveFlowPipelineEvent) -> void:
	_show_toast("%s Saved" % event.source_key)
```

Connect these from the Godot inspector when possible.
That keeps the Source script focused on data and lets UI feedback live in UI
nodes.

## Listen Modes

Use `Owner Only` when the signal node should observe one Source or Scope.

Use `Owner And Descendants` when it should observe a nested domain.

Use `All Pipeline Events` only for global debug or UI feedback nodes.

## Why This Exists

Without signal bridges, users often subclass Sources just to run small side
effects.

Signals keep data ownership and presentation behavior separate:

- Sources own save/load data
- gameplay nodes respond to save/load events
- UI can show feedback without becoming part of the saved payload
