# SaveFlow Recommended Integration

This document defines the default user-facing SaveFlow Lite workflow.

If your project has already moved into multi-scene restore, migration, cloud-save, or large runtime-world complexity, read this together with:
- [saveflow-commercial-project-guide.md](saveflow-commercial-project-guide.md)
- [saveflow-common-authoring-mistakes.md](saveflow-common-authoring-mistakes.md)

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
- `SaveFlow.read_slot_metadata(slot_id, my_metadata)` when a save-list row should hydrate a typed metadata object
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
- gameplay code owns the current integer `active_slot_index`
- gameplay code chooses whether the event writes the active slot or a separate project-owned slot
- gameplay code calls the SaveFlow entry point explicitly

Typical examples:

- door transition autosaves the active slot
- shrine or bonfire records checkpoint state and saves the active slot
- pause menu writes a manual save slot
- settings menu writes system data immediately

Important boundary:

- SaveFlow does not maintain "the player's current slot"
- SaveFlow writes exactly the `slot_id` passed to `save_data()`, `save_scene()`, or `save_scope()`
- the game should keep its own active-slot/session state, then pass a stable storage key to SaveFlow
- autosave and checkpoint events should write the current active slot, not every visible save card

Slot identity names should stay separate:

- `slot_index` is an integer owned by your game UI/session. Use it for sorting,
  selected-slot state, controller navigation, and "Manual Slot 2" style
  decisions.
- `slot_id` is the stable storage key passed to SaveFlow. Derive it from the
  index or another stable project rule. Do not localize it and do not use it as
  the player-facing label.
- `display_name` is player-facing metadata. It can say `Forest Gate`,
  `Checkpoint`, or `Manual Slot 2`, and it can change without renaming the saved
  file.

The recommended template shows this as save cards:

- Main slot card: `slot_index = 0`, `slot_id = "project_workflow_main"`, display
  name `Project Workflow Main Data`
- Forest room card: `slot_index = 1`, `slot_id = "project_workflow_room_forest"`,
  display name `Forest Room Subscene Data`
- Dungeon room card: `slot_index = 2`, `slot_id = "project_workflow_room_dungeon"`,
  display name `Dungeon Room Subscene Data`

Use an integer slot index for gameplay identity, selection, and sorting. Derive
the SaveFlow storage key from that index, then store string labels such as
`Forest Gate` or `Manual Slot 2` as metadata.

Use `SaveFlowSlotWorkflow` for the common active-slot pattern. It keeps the
game-owned active index explicit while removing repeated string-key glue for
slot ids, metadata, and save-card UI rows:

```gdscript
class_name MySlotMetadata
extends SaveFlowSlotMetadata

@export var slot_index := 0
@export var storage_key := ""

const SlotWorkflowScript := preload("res://addons/saveflow_core/runtime/types/saveflow_slot_workflow.gd")

var slot_workflow: Resource = SlotWorkflowScript.new()

func _ready() -> void:
    slot_workflow.metadata_script = MySlotMetadata
    slot_workflow.slot_id_template = "slot_{index}"
    slot_workflow.empty_display_name_template = "Manual Slot {index}"
    slot_workflow.select_slot_index(1)

func load_slot(slot_index: int) -> void:
    var slot_id := slot_workflow.slot_id_for_index(slot_index)
    var result := SaveFlow.load_data(slot_id)
    if result.ok:
        slot_workflow.select_slot_index(slot_index)
        apply_payload(result.data)

func manual_save(slot_index: int) -> void:
    slot_workflow.select_slot_index(slot_index)
    var meta := slot_workflow.build_active_slot_metadata(
        "Manual Slot %d" % slot_index,
        "manual",
        "Chapter 1",
        current_location_name(),
        current_playtime_seconds()
    )
    var result := SaveFlow.save_data(slot_workflow.active_slot_id(), build_payload(), meta)
    if result.ok:
        refresh_save_cards()

func autosave_after_door() -> void:
    var meta := slot_workflow.build_active_slot_metadata(
        "Door Autosave",
        "autosave",
        "Chapter 1",
        current_location_name(),
        current_playtime_seconds()
    )
    SaveFlow.save_data(slot_workflow.active_slot_id(), build_payload(), meta)

func checkpoint_reached(checkpoint_id: String) -> void:
    var payload := build_payload()
    payload["active_checkpoint_id"] = checkpoint_id
    var meta := slot_workflow.build_active_slot_metadata(
        "Checkpoint",
        "checkpoint",
        "Chapter 1",
        current_location_name(),
        current_playtime_seconds()
    )
    SaveFlow.save_data(slot_workflow.active_slot_id(), payload, meta)

func refresh_save_cards() -> void:
    var summaries := SaveFlow.list_slot_summaries()
    if not summaries.ok:
        return
    var cards := slot_workflow.build_cards_for_indices(PackedInt32Array([1, 2, 3]), summaries.data)
    render_cards(cards)
```

`SaveFlowSlotWorkflow` is intentionally not a hidden slot manager. It does not
call save/load/delete by itself. Game code still chooses the event, the payload,
and the SaveFlow entry point.

Save-card rule:

- card selection changes `active_slot_index`
- SaveFlow receives one stable `slot_id`
- `display_name` and row labels come from typed metadata
- autosave/checkpoint writes the active card only
- delete removes one storage key, then the UI refreshes summaries

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
- `SaveFlow.build_slot_metadata(...)` for typed default slot fields
- a project metadata class that extends `SaveFlowSlotMetadata` for fields such as `slot_index`, `storage_key`, or `slot_role`
- `SaveFlow.build_slot_metadata_patch(...)` only when you intentionally need low-level dictionary output

Use it to start from the Lite baseline fields, then override the parts your game
actually wants to show in save rows.

Keep summary data such as:

- save label
- save type
- chapter/location
- playtime
- progression summary
- `slot_index` or other UI ordering data when the save-list UI needs it

Typical example:

```gdscript
class_name MySlotMetadata
extends SaveFlowSlotMetadata

@export var slot_index := 0
@export var storage_key := ""

func autosave_slot(payload: Dictionary, active_slot_index: int) -> void:
	var slot_id := "slot_%d" % active_slot_index
	var meta := MySlotMetadata.new()
	meta.display_name = "Forest Gate"
	meta.save_type = "autosave"
	meta.chapter_name = "Chapter 2"
	meta.location_name = "Forest Gate"
	meta.playtime_seconds = 1320
	meta.difficulty = "normal"
	meta.slot_index = active_slot_index
	meta.storage_key = slot_id

	SaveFlow.save_data(slot_id, payload, meta)
```

When metadata needs a grouped project-specific object, make that object extend
`SaveFlowTypedData` and export it from the metadata class:

```gdscript
class_name MySlotRowData
extends SaveFlowTypedData

@export var slot_index := 0
@export var storage_key := ""
@export var tags: PackedStringArray = PackedStringArray()

class_name MyGroupedSlotMetadata
extends SaveFlowSlotMetadata

@export var row_data := MySlotRowData.new()
```

The slot file still stores metadata as a dictionary for compatibility. The typed
metadata object is the authoring surface, so gameplay code does not need to
repeat string keys such as `display_name`, `save_type`, `location_name`, or
`slot_index` at every save call.

SaveFlow emits an authoring warning when metadata contains runtime objects, raw
Resources, or too many custom fields. Treat that as a design smell: metadata is
for save-list summary UI, while gameplay state belongs in the payload or SaveFlow
sources.

Keep save-row fields in metadata, not in the gameplay payload, when the data
mainly exists to render continue/load menus.

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
For the recommended template, keep that setup in a small scene node such as
`SaveFlowConfigurator` instead of burying path setup inside gameplay scripts.

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

Minimal scene pattern:

- Add a `SaveFlowConfigurator` node under the template root scene.
- Set `base_root` to the demo root, for example `user://recommended_template`.
- Set `profile_key` to the project/profile name, for example `project_workflow`.

That resolves to:

```text
save_root = user://recommended_template/project_workflow/saves
slot_index_file = user://recommended_template/project_workflow/slots.index
```

Use direct code only when the project has its own bootstrap/runtime settings
system and there is no scene node that naturally owns the profile selection.

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

## 2. System state: `SaveFlowTypedDataSource` / `SaveFlowTypedStateSource` / `SaveFlowDataSource`

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
   |- WorldTypedDataSource
```

Recommended first path:

```gdscript
class_name WorldStateData
extends SaveFlowTypedData

@export var current_region := "forest"
@export var unlocked_regions: PackedStringArray = []
@export var quest_step := 0
```

Then add a `SaveFlowTypedDataSource` to the save graph. Prefer assigning the
typed data resource directly when the scene owns that data.

`SaveFlowTypedData` is the convenience base, not the only legal shape.
`SaveFlowTypedDataSource` accepts any object that implements:

```gdscript
func to_saveflow_payload() -> Dictionary
func apply_saveflow_payload(payload: Dictionary) -> void
```

Use `target` directly when a manager node implements that contract. Use
`target + data_property` when a manager owns a runtime `RefCounted`, C# object,
or other data object that implements the same contract.

For C# state that is one DTO/record, prefer a direct C# source instead of a
targeted GDScript source:

```text
SaveGraphRoot
|- WorldScope
   |- RoomStateSource (C# script extends SaveFlowTypedStateSource)
```

`SaveFlowTypedStateSource` lets the C# node gather/apply its own encoded payload
while still participating in the normal SaveFlow graph.

This keeps business code focused on fields:

```gdscript
world_state_data.current_region = "dungeon"
world_state_data.quest_step += 1
```

instead of repeatedly managing dictionary keys:

```gdscript
payload["current_region"] = "dungeon"
payload["quest_step"] = int(payload.get("quest_step", 0)) + 1
```

Responsibilities:
- the system object owns the runtime data
- `SaveFlowTypedDataSource` converts payload-provider objects to and from save data
- `SaveFlowTypedStateSource` is the direct C# path for one typed state object
- a custom `SaveFlowDataSource` translates runtime data when typed fields are not enough
- the data source plugs directly into the SaveFlow graph

Use this path when:
- data belongs to a manager or registry
- data is naturally a table, queue, or model object
- a node-centric source would be artificial

Use a custom `SaveFlowDataSource` when:
- the source must merge several registries
- the runtime model cannot be represented as exported fields
- gather/apply needs validation, filtering, or derived data rebuilds

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

The descriptor parameter is still a dictionary at the restore boundary because
that is the on-disk payload shape. Do not read it with ad-hoc string keys in
project code. Convert it first:

```gdscript
func spawn_entity_from_save(descriptor: Dictionary, _context: Dictionary = {}) -> Node:
    var entity_descriptor := resolve_entity_descriptor(descriptor)
    var entity := EnemyScene.instantiate()
    entity.name = entity_descriptor.persistent_id
    return entity
```

`SaveFlowEntityDescriptor` exposes:
- `persistent_id`
- `type_key`
- `payload`
- `extra` for project-specific descriptor fields

Author descriptor extra on `SaveFlowIdentity` when the factory needs a small
piece of spawn/routing data before the payload can be applied:

```gdscript
$Enemy/Identity.descriptor_extra = {
    "spawn_point": "north_gate",
    "pool_id": "forest_enemies",
}
```

You can also implement `get_saveflow_entity_extra()` or
`get_saveflow_entity_descriptor_extra()` on the entity node when the extra data
must be computed at gather time. Keep this data small. Entity health, position,
inventory, animation, and other gameplay state should stay in the payload owned
by the entity's local source or scope.

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
If the thing being saved is "this typed system/model", start with `SaveFlowTypedDataSource`.

Rule 2.1:
If the thing being saved needs custom gather/apply translation, use `SaveFlowDataSource`.

Rule 3:
If the thing being saved is "this changing set of runtime entities", start with `SaveFlowEntityCollectionSource` and an entity factory.

Rule 3.0:
Start with `SaveFlowPrefabEntityFactory` unless the project already has a real reason to own spawning and lookup itself.

Rule 3.1:
Pick restore policy before you write custom factory code. Most mistakes in runtime-entity saves come from the wrong restore behavior, not from serialization itself.

Rule 3.2:
Treat one runtime entity set as having one owner. If an `EntityCollectionSource` owns a runtime container, do not also sweep that same container from a parent `NodeSource` or broad `save_scene()` traversal.

Rule 3.3:
Use descriptor extra only for factory routing before payload application. If the
data can be applied after the entity exists, it belongs in the payload instead.

Rule 4:
Put save logic as close to prefab ownership as possible.

Rule 5:
Use `SaveFlowScope` to organize domains and restore order, not to replace object ownership.

Rule 6:
Disabling `verify_scene_path_on_load` removes a scene-level safety check. It does not add staged restore, scene loading, or orchestration.

Rule 7:
Keep one typed data source or custom data source focused on one system boundary. Split gameplay data, machine-local settings, session caches, and debug-only data instead of hiding them behind one large source.

Rule 8:
Use multiple simple prefab factories before you reach for routing inside one factory. When routing depends on pooling, spawn points, registries, or world state, move to a custom `SaveFlowEntityFactory`.

## Local Pipeline Control

Lite has deterministic local lifecycle hooks, not a full scene/resource
orchestrator. Use pipeline control when gameplay code needs to observe, cancel,
or react to the local save/load phases.

Pipeline callbacks:
- `before_save(event)`
- `after_gather(event)`
- `before_write(event)`
- `after_write(event)`
- `before_load(event)`
- `after_read(event)`
- `before_apply(event)`
- `before_save_scope(event)`
- `after_save_scope(event)`
- `before_load_scope(event)`
- `after_load_scope(event)`
- `before_gather_source(event)`
- `after_gather_source(event)`
- `before_apply_source(event)`
- `after_apply_source(event)`
- `after_load(event)`
- `on_error(event)`

Each callback receives a `SaveFlowPipelineEvent` with fields such as `stage`,
`slot_id`, `key`, `scope`, `source`, `payload`, `result`, and `context`.
Call `event.cancel("reason")` to stop the operation with `PIPELINE_CANCELLED`.

Example:

```gdscript
var control := SaveFlowPipelineControl.new()
control.context.values["restore_reason"] = "manual_load"

control.before_load = func(event: SaveFlowPipelineEvent) -> void:
    print("Loading slot: ", event.slot_id)

control.before_apply_source = func(event: SaveFlowPipelineEvent) -> void:
    if event.key == "inventory" and not inventory_ready:
        event.cancel("Inventory source is not ready.")

control.after_load = func(_event: SaveFlowPipelineEvent) -> void:
    refresh_hud_after_restore()

control.on_error = func(event: SaveFlowPipelineEvent) -> void:
    push_warning(event.result.error_message)

var result := SaveFlow.load_scope("slot_1", $SaveGraphRoot, true, control)
```

Use `SaveFlowPipelineSignals` when the reaction belongs to a scene-authored
node instead of the caller script:

```text
SaveGraphRoot
|- PlayerScope
|  |- PlayerSource
|     |- SaveFlowPipelineSignals
```

Then connect signals such as `before_apply_source(event)`,
`after_gather_source(event)`, or `pipeline_error(event)` from Godot's Node >
Signals panel to any script method you want. Set `Listen Mode` to `Owner Only`
for the parent scope/source, `Owner And Descendants` to observe nested graph
events, or `All Pipeline Events` for diagnostics.

Runnable example:
`res://demo/saveflow_lite/recommended_template/scenes/pipeline_notifications/pipeline_notification_demo.tscn`
uses one scope-level bridge for the final `Data Saved!` message and one bridge
under each typed data source for `Profile/Inventory/Quest Data Saved` sidebar
messages.

`SaveFlowPipelineSignals` is a pipeline helper, not gameplay state. It is not
serialized, and `SaveFlowNodeSource` ignores it when discovering child
participants or reporting "helper has child nodes" warnings.

`SaveFlowPipelineContext` is the support object inside the control. Do not pass
it to SaveFlow directly. Use `control.context.values` for temporary shared
values and `control.context.trace` or `result.meta["pipeline_trace"]` for
diagnostics.

Scope hooks:
- `before_save(context)`
- `before_load(payload, context)`
- `after_load(payload, context)`

Source hooks:
- `before_save(context)`
- `before_load(payload, context)`
- `after_load(payload, context)`

Ordering is controlled by `phase` inside one scope: lower phases run first.

The trace records stages such as `scope.before_load`, `source.apply`, and
`scope.after_load`, plus callback stages when you use `SaveFlowPipelineControl`.
Use it to debug Lite graph restore order. Do not use it as a resource loading
coordinator or cross-scene staged restore plan; those belong to Pro-level
orchestration.

## What SaveFlow Should Feel Like

A user should not need to ask:
- "Should this be a component or a built-ins source?"
- "Should I manually serialize this animation player?"
- "Where does this runtime factory integrate?"

The intended answers are:
- object state uses `SaveFlowNodeSource`
- typed system state uses `SaveFlowTypedDataSource`
- custom system adapters use `SaveFlowDataSource`
- runtime sets use entity collection + entity factory

That is the core recommended workflow for SaveFlow Lite.
