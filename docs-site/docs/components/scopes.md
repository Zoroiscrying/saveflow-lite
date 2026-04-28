---
sidebar_position: 5
title: SaveFlowScope
---

Use `SaveFlowScope` when the user story is:

> Save or load this gameplay domain.

A Scope groups Sources.
It is not a replacement for Sources.

![SaveFlowScope inspector preview](/img/saveflow/SaveFlowScope.png)

## Good Scope Boundaries

Common domains:

- `ProfileScope`
- `SettingsScope`
- `WorldScope`
- `RoomScope`
- `CombatScope`

Example:

```text
RoomScope
|- PlayerSource
|- RoomStateSource
|- RuntimeCoinsSource
```

The Scope lets you call one save/load operation for the room while each child
Source still owns its own data.

## When To Add A Scope

Add a Scope when:

- several Sources should save/load together
- you need a clear domain key
- a scene has multiple independent save domains
- you want to inspect a domain before saving it

Do not add a Scope just because one object has several fields.
That is still a `SaveFlowNodeSource` or typed data Source problem.

## Restore Order

Lite supports explicit Scope save/load for currently loaded scene content.

Pro orchestration is the future layer for staged multi-scene flows such as:

```text
profile -> world bootstrap -> current map -> runtime actors -> late references
```

In Lite, keep the Scope boundary honest:

- the scene or domain should already be loaded
- the Sources should already exist
- runtime factories should be present before entity restore
