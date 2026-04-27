# SaveFlow Common Authoring Mistakes

Read this checklist before assuming a save/load bug is inside SaveFlow itself.

The goal is simple:
- catch the most common Lite authoring mistakes in under a minute
- keep ownership boundaries obvious
- keep restore behavior understandable

## One-Minute Checklist

### 1. One subtree, one save owner

Ask:
- is this subtree owned by one `SaveFlowNodeSource`?
- one `SaveFlowTypedDataSource` or custom `SaveFlowDataSource`?
- or one `SaveFlowEntityCollectionSource`?

Do not let the same subtree be owned twice.

### 2. Runtime sets belong to `SaveFlowEntityCollectionSource`

If a container holds runtime entities that can appear or disappear:
- let `SaveFlowEntityCollectionSource` own that set
- let the entity prefab own its own local save logic

Do not also sweep that same runtime container from a parent `NodeSource` or a broad `save_scene()` traversal.

### 3. Child nodes with their own `NodeSource` are not directly owned twice

If a child already has its own `SaveFlowNodeSource`:
- the parent can reference that child source as a participant
- the parent should not also directly own that child subtree as ordinary object state

Use composition, not duplicate ownership.

Concrete prefab example:

```text
Room
|- RoomSource
|- Door
|  |- DoorSource
```

If `RoomSource` needs the door state, include `Door/DoorSource`, not `Door`.
Including `Door` means the room tries to own the door subtree directly, while
`DoorSource` already says the door owns its own save logic.

Also avoid putting sources under sources:

```text
Player
|- PlayerSource
   |- ExtraSource     # wrong
```

`PlayerSource` is a SaveFlow helper, not a gameplay object. Move `ExtraSource`
under the gameplay object it saves, or put it under a `SaveFlowScope` when it is
a separate save graph entry.

The same rule applies if there is an ordinary `Node` between them:

```text
Player
|- PlayerSource
   |- Weapon
      |- WeaponSource     # wrong: Weapon is inside a source helper
```

Fix it by moving the gameplay subtree back under the gameplay object:

```text
Player
|- PlayerSource
|- Weapon
   |- WeaponSource
```

If `PlayerSource` should compose the weapon payload, include `Weapon/WeaponSource`.
If the weapon should be collected as its own save entry by a scope or scene save,
leave it as a separate source and do not include it from `PlayerSource`.

If the extra source was only meant to save more state from `Player` itself, delete
the extra source and configure `PlayerSource` directly with exported fields,
built-ins, or additional properties.

Also avoid plain gameplay children under a source:

```text
Player
|- PlayerSource
   |- Sprite2D     # wrong: source helper is not the Player's content root
```

Move the gameplay child back under the target object:

```text
Player
|- PlayerSource
|- Sprite2D
```

`PlayerSource` can still save `Sprite2D` by including it as a child participant,
because included child paths are resolved from `Player`, not from `PlayerSource`.

### 4. System data sources should stay focused on one system boundary

Good:
- one quest log
- one inventory backend
- one world progression table

Bad:
- gameplay progression
- machine-local settings
- session cache
- debug-only values

all mixed into one large data source.

Start with `SaveFlowTypedDataSource` when one typed object can provide the
payload cleanly. Use custom `SaveFlowDataSource` only when the project needs
broader gather/apply translation logic.

### 5. `verify_scene_path_on_load` is a safety guard, not orchestration

If it is enabled:
- SaveFlow checks whether the expected scene is already active before restore

If it is disabled:
- SaveFlow skips that scene-level safety check
- it does **not** gain staged restore, scene loading, or orchestration logic

### 6. Start with the simplest entity-factory path

Start with:
- `SaveFlowPrefabEntityFactory`

Move to:
- custom `SaveFlowEntityFactory`

only when routing depends on pooling, authored spawn points, registries, or project-owned runtime lookup rules.

### 7. Save UI from business data unless the UI node really owns meaningful state

Usually:
- UI should be rebuilt from gameplay or system data

Only store UI node state directly when it truly behaves like meaningful local runtime state.

## Fix Common SaveFlow Warnings

The Scene Validator badge and Source inspector warnings are designed to point at
authoring shape problems, not file corruption. Start from the node named in the
warning, then use the fixes below.

### Stale target built-in selection

Warning shape:
- `Selected target built-in ... is not supported`

Why it happens:
- a `SaveFlowNodeSource` target changed type
- an old serializer id stayed in `included_target_builtin_ids`
- the source can no longer save that built-in state for this target

Fix:
- select the `SaveFlowNodeSource`
- open the built-in section in the inspector preview
- remove the unsupported built-in
- or point the source back to the node type that actually supports it

Example:

```text
Area2D
|- AreaSource
```

`Area2D` can use `area_2d`, but not `sprite_2d`. If the warning mentions
`sprite_2d`, remove that stale selection or move it to a real `Sprite2D`
participant.

### Invalid target built-in field override

Warning shape:
- `Target built-in ... does not expose field ...`

Why it happens:
- a field override references a field that the serializer does not save
- the field name was renamed, typed incorrectly, or copied from another built-in

Fix:
- select the `SaveFlowNodeSource`
- clear the custom field override
- then reselect fields from the current preview

Do not manually keep unknown fields in the override dictionary. SaveFlow will
ignore them at runtime, and the warning means your mental model no longer
matches the actual serializer contract.

### Duplicate runtime entity `persistent_id`

Warning shape:
- `Duplicate runtime entity persistent_id`

Why it happens:
- two entities in the same `SaveFlowEntityCollectionSource` resolve to the same
  persistent id
- restore cannot safely decide which runtime object owns the saved descriptor

Fix:
- open the entity container named by the warning
- select each entity's `SaveFlowIdentity`
- assign a unique, stable `persistent_id`

Good:

```text
RuntimeActors
|- EnemyA
|  |- Identity persistent_id = enemy_a_001
|- EnemyB
|  |- Identity persistent_id = enemy_b_001
```

Bad:

```text
RuntimeActors
|- EnemyA
|  |- Identity persistent_id = enemy
|- EnemyB
|  |- Identity persistent_id = enemy
```

### `Identity` fallback id

Warning shape:
- `SaveFlowIdentity is using its helper node name as persistent_id`

Why it happens:
- the `SaveFlowIdentity` node's `persistent_id` is empty
- the fallback id becomes the helper node name, usually `identity`
- many entities can accidentally get the same id

Fix:
- do not rely on the `Identity` node's own name
- fill `persistent_id` explicitly
- use a stable authored id, spawn id, or deterministic id from your game data

The entity node name is not enough if the entity can be duplicated, respawned,
or renamed by gameplay code.

### Entity `type_key` is not handled by the factory

Warning shape:
- `Runtime entity ... uses type_key ..., but factory ... does not handle that type`

Why it happens:
- the collection owns an entity whose `SaveFlowIdentity.type_key` does not match
  the configured factory
- restore cannot spawn or apply that descriptor through this factory

Fix:
- update the entity `type_key`
- or update the factory's routing logic
- or split the container into multiple collections with different factories

For simple prefab routing, `SaveFlowPrefabEntityFactory.type_key` should match
the entities in that collection. For custom factories, `can_handle_type()` must
return `true` for every type that the collection owns.

### Runtime container is double-collected

Warning shape:
- `Runtime set may be double-collected`
- or `Included child crosses another save-owner boundary`

Why it happens:
- a parent `SaveFlowNodeSource` includes a runtime entity container directly
- the same container is already owned by `SaveFlowEntityCollectionSource`

Fix:
- let `SaveFlowEntityCollectionSource` own the runtime container
- remove the container path from the parent `NodeSource`
- if the parent object should compose the runtime set, include the collection
  source itself, not the raw container subtree

Good:

```text
Room
|- RoomSource
|- RuntimeActors
|- ActorCollection
```

`ActorCollection` points at `RuntimeActors`. `RoomSource` should not include
`RuntimeActors` directly.

## If Something Looks Wrong

Check in this order:

1. `Compatibility`
2. `Restore Contract`
3. `Slot Safety`
4. save-owner boundaries
5. source-specific gameplay logic

If the first three are already green, the next most likely cause is ownership or authoring shape, not file corruption or version policy.
