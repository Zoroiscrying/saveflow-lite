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
