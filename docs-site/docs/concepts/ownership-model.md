---
sidebar_position: 1
title: Ownership Model
---

SaveFlow works best when each piece of saved data has one obvious owner.

The most common integration mistakes happen when two Sources try to own the
same object or when a parent Source accidentally saves through a child Source's
subtree.

## The Rule

One saved object or runtime set should have one save owner.

That owner may be:

- one `SaveFlowNodeSource`
- one `SaveFlowTypedDataSource`
- one `SaveFlowTypedStateSource`
- one custom `SaveFlowDataSource`
- one `SaveFlowEntityCollectionSource`

If you need a larger unit, group those owners with `SaveFlowScope`.
Do not make the Scope gather the same object again through another path.

## Source Ownership

A Source owns one save boundary.

Examples:

- `SaveFlowNodeSource` owns selected state from one node or selected child nodes.
- `SaveFlowTypedDataSource` owns one typed GDScript data object.
- `SaveFlowTypedStateSource` owns one typed C# state object.
- `SaveFlowEntityCollectionSource` owns one runtime entity container.

If an object already has its own Source, include that Source directly in the
graph. Do not also save that object as part of a parent subtree.

### What "Parent Should Own It" Means

The parent should own a child only when the child is not meaningful on its own.

Good parent-owned child examples:

- `AnimationPlayer` under `Player`
- `Sprite2D` under `Chest`
- a local `Timer` that belongs only to one trap

Bad parent-owned child examples:

- a nested enemy that has its own `SaveFlowNodeSource`
- a runtime coin container owned by `SaveFlowEntityCollectionSource`
- a settings manager that should be its own typed data Source

When the child has its own Source, include that child Source directly in the
graph instead of including the child's whole subtree in the parent payload.

## Scope Ownership

`SaveFlowScope` groups Sources into a domain.

Use a Scope when you want to say:

> Save or load this part of the project as one domain.

Examples:

- profile data
- world data
- current room data
- settings data

Lite can save and load Scopes explicitly. Pro orchestration is reserved for
multi-stage restore plans across scenes, resources, and late reference repair.

## Entity Ownership

Runtime entities should be owned by an entity collection, not by a broad parent
`NodeSource`.

If a runtime container is inside a node subtree, the parent `NodeSource` should
not recursively save through that container. The collection Source owns the
entity list, and the factory owns reconstruction.

## Why Lite Warns About This

Duplicate ownership creates save files that are hard to reason about:

- one payload says an object exists
- another payload says the same object was deleted
- one Source restores an older value after another Source already applied a newer value
- a runtime container keeps stale children after load

SaveFlow Lite catches the common authoring mistakes early through inspector
warnings and the scene validator.
