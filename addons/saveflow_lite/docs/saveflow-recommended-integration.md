# SaveFlow Recommended Integration

This document defines the default user-facing SaveFlow Lite workflow.

If your project has already moved into multi-scene restore, migration, cloud-save, or large runtime-world complexity, read this together with:
- [saveflow-commercial-project-guide.md](saveflow-commercial-project-guide.md)

The goal is simple:
- one obvious way to save a gameplay object
- one obvious way to save system state
- one obvious way to save runtime entity collections
- one obvious way to organize domains and restore order

## Project-Level Save Defaults

Use the `SaveFlow Settings` dock for project-wide defaults that should affect
the whole runtime:
- storage format
- slot root and slot index paths
- file extensions
- default slot metadata such as project title, game version, save schema, and data version
- write behavior such as safe write and auto-create directories

This panel configures the `SaveFlow` singleton.

Do not use it to replace per-source authoring decisions. Object, system, and
runtime-set ownership still belongs on the matching SaveFlow components.

## Reading slot state in `DevSaveManager`

`DevSaveManager` is meant to answer four practical questions in order:

1. can this slot be loaded under the current compatibility policy?
2. is the current scene or scope the correct restore target?
3. is the slot file itself healthy?
4. is a backup available if the primary file is bad?

Read the status badges in this order:

- `Compatibility`
  - answers whether the slot metadata satisfies the current `save_schema` and `data_version` policy
  - if this says `Migration required`, stop here; this is not a restore-target problem
- `Restore Contract`
  - answers whether the current runtime scene matches the saved restore target
  - if this says `Expected scene not active`, load the expected scene first and retry
- `Slot Safety`
  - answers whether the primary slot file is healthy and whether backup recovery is available
  - this is where you see `Safe`, `Safe with backup`, `Backup recovery available`, or `No safe recovery`

Use `Slot Details` when you need the underlying evidence:

- `Slot Path`
- `Primary File`
- `Backup`
- `Save Schema`
- `Data Version`
- `Game Version`
- `Scene Path`

Recommended debugging flow:

1. if `Compatibility` is blocked, fix version/schema policy first
2. if `Restore Contract` is blocked, load the expected scene first
3. if `Slot Safety` reports an unreadable primary file, check whether backup recovery is available
4. only after those checks pass should you treat the problem as a Source or gameplay-state issue

This is intentional. SaveFlow Lite separates:

- metadata compatibility
- restore-target readiness
- slot-file safety

so users do not have to guess whether a failed load came from the wrong scene,
an incompatible slot, or a damaged save file.

## Business-side save workflow that still belongs in Lite

As projects get more real, teams usually need three things before they need any
Pro-style orchestration:

- a real save-slot list in game UI
- autosave and checkpoint triggers
- a clear slot-metadata convention

These are still Lite concerns when they stay local, explicit, and project-owned.

### Save-slot list workflow

Recommended rule:

- use slot metadata for save-list rows
- use full save payload only when the player actually loads a slot

Typical save-list fields:

- `display_name`
- `save_type`
- `chapter_name`
- `location_name`
- `playtime_seconds`
- `difficulty`

Baseline runtime entry points for this workflow:

- `SaveFlow.read_slot_summary(slot_id)`
- `SaveFlow.list_slot_summaries()`

These reads are meant for:

- continue buttons
- load menus
- QA slot inspection in gameplay UI
- save-slot rows that should not trigger full restore logic

Each slot summary keeps the common business-facing fields at the top level and
exposes:

- `compatibility_report`
- `custom_metadata`

Do not rebuild the whole UI by loading full gameplay payload just to render a
continue screen or load menu.

### Autosave and checkpoint workflow

Recommended rule:

- gameplay code decides when a save-worthy event happened
- gameplay code chooses the slot strategy
- gameplay code calls the SaveFlow entry point explicitly

Typical examples:

- door transition writes an autosave slot
- shrine or bonfire writes a checkpoint slot
- pause menu writes a manual save slot
- settings menu writes system data immediately

Use:

- `save_scene()` when one scene/object tree owns the state
- `save_scope()` when one domain graph should restore together
- `save_data()` when one system/table/model owns the state

### Slot metadata convention

Recommended rule:

- slot metadata is for business-facing slot summary
- Sources and payload are for actual restore state

Recommended helpers:

- `SaveFlow.save_data(..., display_name, save_type, chapter_name, location_name, playtime_seconds, difficulty, thumbnail_path, extra_meta)` for the common explicit path
- `SaveFlow.build_slot_metadata(...)`
- `SaveFlow.build_slot_metadata_patch({...})` when you intentionally want override-by-key behavior

Use it to start from the Lite baseline fields, then override the parts your game
actually wants to show in save rows.

Keep summary data such as:

- save label
- save type
- chapter/location
- playtime
- progression summary

Typical example:

```gdscript
SaveFlow.save_data(
    "autosave_latest",
    payload,
    "Forest Gate",
    "autosave",
    "Chapter 2",
    "Forest Gate",
    1320,
    "normal"
)
```

out of the gameplay payload when the data mainly exists to render save rows.

Likewise, keep machine-local settings, temporary debug values, and rebuildable
caches outside the slot unless they really belong to player progression.

### Scene-path verification

`verify_scene_path_on_load` is a restore-contract precheck for scene and scope loads.

When it is enabled:

- SaveFlow records the owning `scene_path` in slot metadata during save
- `load_scene()` and `load_scope()` require the expected scene to already be active before restore

When it is disabled:

- SaveFlow skips that scene-context precheck
- restore continues against whatever save graph, source keys, and runtime identities resolve under the current target

Use the disabled mode only when you intentionally want key/graph-based restore
without a scene-level safety check.

## One Project, Many Demo Profiles

If one Godot project hosts several demos or sandboxes, do not force them to
share one save folder.

Recommended rule:

- one shipped game usually exposes one primary save profile
- one demo repository may host several isolated demo profiles

In practice, that means each demo should have its own:

- `save_root`
- `slot_index_file`
- optional dev-save root and dev slot index

The scene that boots that demo should configure `SaveFlow` with those paths.

Examples in this repository:

- `complex_sandbox`
  - `user://complex_sandbox/saves`
  - `user://complex_sandbox/slots.index`
- `plugin_sandbox`
  - `user://plugin_sandbox/saves`
  - `user://plugin_sandbox/slots.index`
- `zelda_like`
  - formal: `user://zelda_like_sandbox/saves`
  - formal index: `user://zelda_like_sandbox/slots.index`
  - dev: `user://zelda_like_sandbox/devSaves`
  - dev index: `user://zelda_like_sandbox/dev-slots.index`

This is profile isolation, not one shared multi-game slot system.

Minimal pattern:

```gdscript
func _ready() -> void:
    SaveFlow.configure_with(
        "user://my_demo/saves",
        "user://my_demo/slots.index"
    )
```

If editor-side DevSaveManager should also follow that demo:

```gdscript
func build_dev_save_settings() -> Dictionary:
    return {
        "save_root": "user://my_demo/devSaves",
        "slot_index_file": "user://my_demo/dev-slots.index",
    }
```

Use this only when the repository truly hosts multiple demo experiences.
If it is one game with player/world/runtime domains, keep one main profile and
split the save graph with `SaveFlowScope` instead.

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

Rule 3.2:
Treat one runtime entity set as having one owner. If an `EntityCollectionSource` owns a runtime container, do not also sweep that same container from a parent `NodeSource` or broad `save_scene()` traversal.

Rule 4:
Put save logic as close to prefab ownership as possible.

Rule 5:
Use `SaveFlowScope` to organize domains and restore order, not to replace object ownership.

Rule 6:
Disabling `verify_scene_path_on_load` removes a scene-level safety check. It does not add staged restore, scene loading, or orchestration.

Rule 7:
Keep one `SaveFlowDataSource` focused on one system boundary. Split gameplay data, machine-local settings, session caches, and debug-only data instead of hiding them behind one large custom source.

Rule 8:
Use multiple simple prefab factories before you reach for routing inside one factory. When routing depends on pooling, spawn points, registries, or world state, move to a custom `SaveFlowEntityFactory`.

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
