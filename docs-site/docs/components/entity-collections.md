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

## Factory Choice

Use `SaveFlowPrefabEntityFactory` when one prefab maps cleanly to one type key.

Use a custom `SaveFlowEntityFactory` when:

- several type keys route to different prefabs
- the project already has a spawn pipeline
- factory logic needs gameplay systems
- restore requires project-specific placement or initialization

For complex routing, prefer several small factories or a custom factory over
stuffing unrelated rules into one prefab factory.
