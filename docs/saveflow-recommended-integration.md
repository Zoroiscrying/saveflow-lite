# SaveFlow Recommended Integration

This document defines the default user-facing SaveFlow Lite workflow.

The goal is simple:
- one obvious way to save a gameplay object
- one obvious way to save system state
- one obvious way to save runtime entity collections
- one obvious way to organize domains and restore order

## The Three Main Paths

### 0. Domain boundaries: `SaveFlowScope`

Use `SaveFlowScope` to organize a save graph into gameplay domains.

Examples:
- player
- world
- settings
- runtime actors

`SaveFlowScope` is not a leaf serializer.
It should answer:
- which child domains belong together
- which leaf sources belong to this domain
- what order sibling domains restore in
- how this domain reacts to restore errors

Use this path when:
- one gameplay concept spans multiple save sources
- restore order matters between domains
- you want one domain-level restore policy instead of repeating decisions on every source

Do not use `SaveFlowScope` as a replacement for object-owned save logic.
If the thing being saved is still "this object", start with `SaveFlowNodeSource`.

### 1. Node objects: `SaveFlowNodeSource`

Use `SaveFlowNodeSource` when the user mental model is:

- "save this player"
- "save this chest"
- "save this interactable"
- "save this authored scene object"

Recommended scene shape:

```text
Player
|- AnimationPlayer
|- SaveFlowNodeSource
```

Recommended defaults:
- put `SaveFlowNodeSource` under the target prefab
- leave `target` empty so it defaults to the parent node
- let it persist exported fields by default
- enable built-ins only when they add real value
- include child participants only when they are conceptually part of the same object

Use `SaveFlowNodeSource` for:
- exported gameplay fields
- target built-ins such as `Node2D`, `Node3D`, `Control`, `AnimationPlayer`
- selected child participants under the same object

Do not split one object into separate "state source" and "built-ins source" nodes unless there is a very strong reason.

## 2. System state: `SaveFlowDataSource`

Use this path when the state does not naturally live on one scene object.

Examples:
- quest manager
- world state model
- inventory backend
- event queue
- region mutation table

Recommended scene shape:

```text
WorldState
SaveGraphRoot
|- WorldScope
   |- WorldDataSource
```

Responsibilities:
- the system object owns the runtime data
- the custom data source translates runtime data to and from save data
- the data source plugs directly into the SaveFlow graph

Use this path when:
- data belongs to a manager or registry
- data is naturally a table, queue, or model object
- a node-centric source would be artificial

If you implement `describe_data_plan()` for editor preview, keep to the fixed
top-level schema:
- `valid`
- `reason`
- `source_key`
- `data_version`
- `phase`
- `enabled`
- `save_enabled`
- `load_enabled`
- `summary`
- `sections`
- `details`

The built-in preview only renders those fields.
Project-specific preview content should go inside `details`.

## 3. Entity collections: `SaveFlowEntityCollectionSource` + entity factory

Use this path when a domain owns a changing set of runtime entities.

Examples:
- enemies in a room
- spawned loot
- summoned units
- temporary world actors

Recommended scene shape:

```text
RuntimeContainer
EntityFactory
SaveGraphRoot
|- RuntimeScope
|- EntityCollection
```

Entity prefabs should usually own their own local save graph:

```text
Enemy
|- SaveFlowIdentity
|- SaveFlowNodeSource
|- SaveFlowScope (optional, when state is composite)
```

Responsibilities:
- the collection source manages the set
- the entity factory decides how existing entities are found, how missing entities are spawned, and how saved payload is applied
- each entity owns its own local save logic

Default factory path:
- use `SaveFlowPrefabEntityFactory` when one `type_key` maps directly to one prefab scene
- let the prefab own `SaveFlowIdentity` plus its local `SaveFlowNodeSource` or `SaveFlowScope`
- enable container auto-creation only when the collection really owns that container at runtime

Advanced factory path:
- inherit `SaveFlowEntityFactory` when spawning must go through pooling, authored spawn points, registries, or other project-owned runtime systems

Minimum custom entity factory contract:
- required: `can_handle_type(type_key)`, `spawn_entity_from_save(descriptor)`, `apply_saved_data(node, payload)`
- optional: `find_existing_entity(persistent_id)` when authored or pooled entities should be reused
- optional: `prepare_restore(...)` when restore needs container cleanup or cache reset before entities are reapplied

Restore policy:
- `Apply Existing`
  Only apply saved payload to entities the factory can already find. Missing entities are reported and are not spawned.
- `Create Missing`
  Apply to existing entities and let the factory spawn missing entities from saved descriptors. This is the default path for most runtime sets.
- `Clear And Restore`
  Clear the target container first, then rebuild the saved set through the entity factory. Use this when stale runtime instances should never survive a load.

Failure policy:
- `Report Only`
  SaveFlow restores what it can and reports missing ids/types in the result.
- `Fail On Missing Or Invalid`
  The load fails if one or more saved entities cannot be resolved or restored.

Use this path when:
- entities can appear or disappear at runtime
- the project already has a factory/spawn pipeline
- restore order matters across a collection

## Recommended Project Structure

For a typical project, prefer this split:

```text
StateRoot
|- Player
|  |- SaveFlowNodeSource
|- UISettings
|  |- SaveFlowNodeSource
|- WorldState
|- RuntimeActors
|- ActorEntityFactory
|- SaveGraphRoot
   |- PlayerScope
   |  |- PlayerSource
   |- WorldScope
   |  |- WorldDataSource
   |- RuntimeScope
      |- EntityCollection
```

## Practical Rules

Rule 1:
If the thing being saved is "this object", start with `SaveFlowNodeSource`.

Rule 2:
If the thing being saved is "this system/model/table", start with `SaveFlowDataSource`.

Rule 3:
If the thing being saved is "this changing set of runtime entities", start with `SaveFlowEntityCollectionSource` and an entity factory.

Rule 3.0:
Start with `SaveFlowPrefabEntityFactory` unless the project already has a real reason to own spawning and lookup itself.

Rule 3.1:
Pick restore policy before you write custom factory code. Most mistakes in runtime-entity saves come from the wrong restore behavior, not from serialization itself.

Rule 4:
Put save logic as close to prefab ownership as possible.

Rule 5:
Use `SaveFlowScope` to organize domains and restore order, not to replace object ownership.

## What SaveFlow Should Feel Like

A user should not need to ask:
- "Should this be a component or a built-ins source?"
- "Should I manually serialize this animation player?"
- "Where does this runtime factory integrate?"

The intended answers are:
- object state uses `SaveFlowNodeSource`
- system state uses a custom `SaveFlowDataSource`
- runtime sets use entity collection + entity factory

That is the core recommended workflow for SaveFlow Lite.
