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

## If Something Looks Wrong

Check in this order:

1. `Compatibility`
2. `Restore Contract`
3. `Slot Safety`
4. save-owner boundaries
5. source-specific gameplay logic

If the first three are already green, the next most likely cause is ownership or authoring shape, not file corruption or version policy.
