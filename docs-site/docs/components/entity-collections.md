---
sidebar_position: 4
title: Entity Collections
---

Use `SaveFlowEntityCollectionSource` when the user story is:

> Save this changing set of runtime entities.

This is the right path for pickups, dropped items, spawned enemies, temporary
actors, and other objects that can appear or disappear during gameplay.

## Scene Shape

```text
RuntimeCoins
|- Coin_001
|  |- SaveFlowIdentity
|- Coin_002
|  |- SaveFlowIdentity
|- SaveFlowEntityCollectionSource
|- SaveFlowPrefabEntityFactory
```

The collection Source owns descriptor gathering.
The factory owns runtime find, spawn, and apply logic.

## Identity

Each runtime entity needs a stable identity.

Use `SaveFlowIdentity` on the entity node so SaveFlow can tell whether a saved
descriptor refers to an existing object or a missing one that needs to be
created.

Do not rely on a generic fallback id such as `Identity` for duplicated runtime
objects.

Set both identity fields intentionally:

- `persistent_id` should be unique within the runtime collection and stable
  across saves.
- `type_key` should match the route owned by the entity factory.

If either value is left to a node-name fallback, the Entity Collection preview
will report it before you test restore.

## Authoring Diagnostics

Select a `SaveFlowEntityCollectionSource` to read its preview.

The first screen now includes a Next Action row. It tells you the most likely
thing to fix next, such as:

- assign a target container
- assign or manually register an entity factory
- add missing `SaveFlowIdentity` nodes
- replace duplicate or fallback `persistent_id` values
- set explicit `type_key` values
- update factory routes for unsupported entity types
- remove runtime containers from parent `SaveFlowNodeSource` subtree saves

Use this preview before running the game. Runtime entity restore problems are
much easier to fix while the scene tree still shows the container, factory, and
identity nodes together.

## Restore Policy

Pick restore policy before writing factory code:

| Policy | Use when |
| --- | --- |
| `Apply Existing` | The scene already owns all possible entity nodes and load should never spawn. |
| `Create Missing` | Most runtime collections; existing valid entities can stay, missing ones are spawned. |
| `Clear And Restore` | The saved payload is the full truth and stale runtime children must never survive load. |

## Failure Policy

Failure policy is separate from restore policy.

Use `Report Only` while iterating or when partial recovery is acceptable.

Use `Fail On Missing Or Invalid` when the collection must be consistent after
load.

## Restore Report

Entity restore returns the same report shape in both failure policies.

Read `entity_restore_issues` when a runtime object did not come back. Each issue
includes a `code`, the descriptor `persistent_id` when available, the `type_key`
when available, and a short message.

The report also includes summary fields:

- `restored_count`: total entities applied
- `spawned_count` and `created_count`: missing entities created through a factory
- `reused_count`: existing entities that were found and applied
- `skipped_count`: descriptors that could not be restored
- `missing_types`: type keys without a factory route
- `failed_ids`: descriptor ids that could not be restored
- `first_issue`: the first structured issue, useful for compact UI messages

After a gather or restore, `SaveFlowEntityCollectionSource.get_last_restore_report()`
returns the latest report copy. The Entity Collection inspector preview also
shows a Last Restore row with restored, spawned, reused, and skipped counts. If
the report has a `first_issue`, the preview shows its issue code and the same
next-action language used by runtime entity troubleshooting.

Common issue codes are:

| Code | Meaning |
| --- | --- |
| `INVALID_DESCRIPTOR` | The restore input is not a dictionary or `SaveFlowEntityDescriptor`. |
| `MISSING_TYPE_KEY` | The descriptor or identity does not provide a usable `type_key`. |
| `MISSING_PERSISTENT_ID` | The descriptor or identity does not provide a usable `persistent_id`. |
| `FACTORY_NOT_FOUND` | No registered factory can restore that `type_key`. |
| `EXISTING_ENTITY_NOT_FOUND` | Restore policy is `Apply Existing`, but the matching node is absent. |
| `SPAWN_RETURNED_NULL` | The factory route exists, but spawning did not return an entity node. |
| `ENTITY_GRAPH_APPLY_FAILED` | The entity spawned or reused, but its nested save graph failed to apply. |

## Factory Choice

Use `SaveFlowPrefabEntityFactory` when one prefab maps cleanly to one type key.

Use a custom `SaveFlowEntityFactory` when:

- several type keys route to different prefabs
- the project already has a spawn pipeline
- factory logic needs gameplay systems
- restore requires project-specific placement or initialization

For complex routing, prefer several small factories or a custom factory over
stuffing unrelated rules into one prefab factory.
