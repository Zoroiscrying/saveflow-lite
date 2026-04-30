---
sidebar_position: 1
title: Reference
---

This section lists the key public interfaces most SaveFlow Lite users touch.

It is intentionally not a dump of every internal helper.
Start with the workflow pages when learning the concepts, then use this section
when you need exact method names, exported properties, and signal names.

If you only need quick copy/paste examples, start with Common API Calls in
Getting Started.

## Read This First

Most projects use only a small surface:

- `SaveFlow.save_scope()` / `SaveFlow.load_scope()`
- `SaveFlow.save_scene()` / `SaveFlow.load_scene()`
- `SaveFlow.read_slot_summary()` / `SaveFlow.list_slot_summaries()`
- `SaveFlowSlotWorkflow`
- `SaveFlowSlotMetadata`
- `SaveFlowNodeSource`
- `SaveFlowTypedDataSource`
- `SaveFlowEntityCollectionSource`
- `SaveFlowPipelineSignals`
- `SaveFlowClient` and `SaveFlowTypedStateSource` for C#

## Result Shape

Most runtime calls return `SaveResult`.

Treat it as:

```gdscript
var result := SaveFlow.save_scope("slot_1", $RoomScope, metadata)
if not result.ok:
	push_warning(result.message)
```

The exact payload lives in `result.data` when the call produces data.

## Naming Rule

The GDScript API uses snake_case.

The C# wrapper uses PascalCase while calling the same runtime model.

## 0.8 API-Freeze Surface

The 0.8 line treats these public entry points as the Lite API surface being
prepared for freeze:

- the `SaveFlow` runtime facade methods documented in GDScript Runtime API
- the `SaveFlowClient` wrapper methods documented in C# API
- Source contracts for `SaveFlowNodeSource`, `SaveFlowTypedDataSource`, and
  `SaveFlowEntityCollectionSource`
- slot metadata helpers and `SaveFlowSlotWorkflow`
- runtime entity restore report fields: `restored_count`, `spawned_count`,
  `created_count`, `reused_count`, `skipped_count`, `missing_types`,
  `failed_ids`, `entity_restore_issues`, and `first_issue`

Internal helper methods may still change while the 0.8 beta line closes.
