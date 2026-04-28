---
sidebar_position: 6
title: Pipeline Events
---

`SaveFlowPipelineSignals` bridges SaveFlow lifecycle events into Godot signals.

Use it when a scene wants save/load feedback without subclassing Sources.

## Signals

```gdscript
pipeline_event(event: SaveFlowPipelineEvent)
before_save(event: SaveFlowPipelineEvent)
after_gather(event: SaveFlowPipelineEvent)
before_write(event: SaveFlowPipelineEvent)
after_write(event: SaveFlowPipelineEvent)
before_load(event: SaveFlowPipelineEvent)
after_read(event: SaveFlowPipelineEvent)
before_apply(event: SaveFlowPipelineEvent)
after_load(event: SaveFlowPipelineEvent)
before_save_scope(event: SaveFlowPipelineEvent)
after_save_scope(event: SaveFlowPipelineEvent)
before_load_scope(event: SaveFlowPipelineEvent)
after_load_scope(event: SaveFlowPipelineEvent)
before_gather_source(event: SaveFlowPipelineEvent)
after_gather_source(event: SaveFlowPipelineEvent)
before_apply_source(event: SaveFlowPipelineEvent)
after_apply_source(event: SaveFlowPipelineEvent)
pipeline_error(event: SaveFlowPipelineEvent)
```

## Listen Modes

```gdscript
SaveFlowPipelineSignals.ListenMode.OWNER_ONLY
SaveFlowPipelineSignals.ListenMode.OWNER_AND_DESCENDANTS
SaveFlowPipelineSignals.ListenMode.ALL_PIPELINE_EVENTS
```

Use `OWNER_ONLY` for local Source/Scope feedback.
Use `OWNER_AND_DESCENDANTS` for domain-level feedback.
Use `ALL_PIPELINE_EVENTS` for global debug overlays.

## Event Object

Each signal receives `SaveFlowPipelineEvent`.

Use:

```gdscript
event.describe() -> Dictionary
```

The described payload is the safest way to inspect event details in UI/debug
code because event internals can grow over time.

Example:

```gdscript
func _on_after_write(event: SaveFlowPipelineEvent) -> void:
	var info := event.describe()
	print("Saved slot: ", info.get("slot_id", ""))
```

Pipeline signal nodes are not serialized by `SaveFlowNodeSource`.
They are lifecycle helpers, not gameplay state.
