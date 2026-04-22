# SaveFlow in Commercial-Scale Projects

This document is for teams building larger Godot projects.

It does not try to market future features.
It answers a simpler question:

**Why do save/load problems become harder as a project grows, and how should you map those problems back to SaveFlow's model and workflow?**

---

## 1. Where the complexity actually comes from

In a small project, save/load often looks like this:

- save one player
- save a few settings
- save one room or level state

At that stage:

- `SaveFlowNodeSource`
- `SaveFlowDataSource`
- `SaveFlowEntityCollectionSource`

are often enough.

As the project grows, the problem stops being "how do I write data to a file?" and starts becoming:

- is the restore order correct?
- is the current scene the right restore target?
- are required resources ready?
- do runtime actors exist yet?
- do some references need to wait until other domains finish restoring?
- can an older save open safely after an update?
- what happens if local and cloud data both changed?

That is not a sign that you "forgot one more Source".

It is a sign that the project has moved into a different problem space:

- restore orchestration
- long-term compatibility
- delivery and storage policy
- sync and conflict handling
- reference repair
- save performance

---

## 2. Why a complex save is not just one big dictionary

A real project save usually spans multiple kinds of state:

- authored object state
- system-owned data
- runtime entity sets
- slot metadata
- restore order and external storage concerns

That means restore is not usually one immediate `apply()`.

A more realistic flow is:

`profile -> world bootstrap -> current map -> runtime actors -> late references`

In practice that means:

1. check whether the save is safe to load
2. ensure the correct scene or domain is active
3. restore system data and runtime actors
4. repair references that could not be resolved in the first pass

This is why larger projects stop being mainly about serialization and start being about restore orchestration.

---

## 3. What SaveFlow Lite/Core is meant to solve first

### Problem: the project needs an explicit save graph

Why it appears:

- a project never has only one kind of state
- object-owned, system-owned, and runtime-owned state are naturally different

SaveFlow's baseline approach:

- `SaveFlowNodeSource` for object-owned state
- `SaveFlowDataSource` for system-owned state
- `SaveFlowEntityCollectionSource` for changing runtime entity sets
- `SaveFlowScope` for save domains and restore order

Current product ownership:

- **Lite/Core**

Godot workflow implication:

- split state first by ownership
- then use `SaveFlowScope` to express domain boundaries and restore order

If your question is still "which object, system, or runtime set owns this state?", you are probably still in Lite/Core territory.

---

## 4. When restore order matters, the problem is no longer "add one more Source"

### Problem: cross-scene or cross-domain restore needs staged restore

Why it appears:

- the target scene may not be loaded yet
- runtime containers may not exist yet
- some resources may not be ready
- some references can only be repaired after other domains finish restoring

SaveFlow's split:

- Lite/Core handles:
  - `SaveFlow.save_scene()` / `SaveFlow.load_scene()`
  - `SaveFlow.save_scope()` / `SaveFlow.load_scope()`
  - scene and scope restore contracts
- Higher-level orchestration belongs above that baseline

Current product ownership:

- restore contract for loaded scene/scope targets: **Lite/Core**
- staged restore orchestration: outside the baseline Lite workflow

Godot workflow implication:

- for medium-sized projects, start by making domain order explicit with `SaveFlowScope`
- once you need clear pre-load / load / post-load stages, you are no longer solving a Source-level problem

Important boundary:

- if `verify_scene_path_on_load` is enabled, `load_scene()` and `load_scope()` first verify that the saved `scene_path` matches the current restore target
- if it is disabled, SaveFlow skips that scene-level precheck and continues with whatever save graph, source keys, and runtime identities resolve under the current target

So disabling scene-path verification does **not** create staged orchestration.
It only removes one restore-contract safety check.

---

## 5. When the project ships updates, the problem becomes compatibility

### Problem: can an older save still load safely?

Why it appears:

- field names change
- payload structures move
- runtime entity descriptors evolve
- scene or domain organization may change over time

SaveFlow's split:

- Lite/Core handles:
  - `save_schema`
  - `data_version`
  - compatibility checks
  - explicit refusal when a save is not safe to load
- Full migration tooling belongs above that baseline

Current product ownership:

- compatibility reporting: **Lite/Core**
- migration pipelines and upgrade steps: outside the baseline Lite workflow

Godot workflow implication:

- keep project-level version metadata in `SaveFlow Settings`
- make "unsafe to load" visible first
- do not push long-term migration logic down into every Source

---

## 6. When the project needs shipping-grade storage behavior

### Problem: how should save files be stored, protected, and recovered?

Why it appears:

- save files may become large
- the project may need compression, encryption, or integrity checks
- the team may need backup and recovery
- different platforms may need different storage rules

SaveFlow's split:

- Lite/Core handles:
  - baseline file IO
  - safe write
  - last-known-good local backup
- richer storage policy belongs above that baseline

Current product ownership:

- baseline safety: **Lite/Core**
- delivery-grade storage strategy: outside the baseline Lite workflow

Godot workflow implication:

- do not treat `FileAccess` low-level APIs as the whole storage solution
- `FileAccess` compression and encryption are building blocks, not a complete project policy

---

## 7. Cloud save is not just "upload the file"

### Problem: what wins when local and remote data both changed?

Why it appears:

- multiple devices create multiple "latest" states
- not every kind of data should be synced
- machine-specific settings should not be treated like gameplay progression

SaveFlow's split:

- Lite/Core should keep local slot structure, metadata, and compatibility boundaries clear
- Cloud sync policy belongs above that baseline

Current product ownership:

- cloud sync workflow: outside the baseline Lite workflow

---

## 8. When the game needs a real save-slot screen

### Problem: the game UI needs save summaries, not full payload loads

Why it appears:

- players expect a save list to show chapter, map, playtime, or save type
- designers and QA need to tell slots apart quickly
- many games want a `Continue` button without loading full gameplay state just to build the menu

What this means in practice:

- not every save read should become a full restore attempt
- slot metadata becomes part of the product UI, not just an internal detail

SaveFlow's split:

- Lite/Core should keep slot metadata explicit and readable
- Lite/Core should support the idea of lightweight slot-summary reads
- full cloud sync, migration pipelines, and backup catalogs still belong above that baseline

Godot workflow implication:

- use slot metadata for list rows and menu summaries
- use full payload restore only when the player actually loads a slot
- keep business-facing slot summary fields stable instead of rebuilding them from runtime payload every time

Recommended business fields for slot metadata:

- `display_name`
- `save_type` such as `manual`, `autosave`, or `checkpoint`
- `chapter_name`
- `location_name`
- `playtime_seconds`
- `difficulty`
- optional thumbnail path or screenshot reference

These fields are not a replacement for gameplay payload.
They exist so the game can present save slots cleanly.

---

## 9. When save is driven by gameplay events instead of a debug button

### Problem: real projects need autosave and checkpoint patterns

Why it appears:

- room transitions
- boss gates
- story milestones
- return-to-menu flows
- settings changes that should persist immediately

This is still not the same problem as staged restore orchestration.
It is a baseline product workflow problem:

- what kind of slot should this event write?
- when should the game refuse to save right now?
- should this event call `save_scene()`, `save_scope()`, or `save_data()`?

SaveFlow's split:

- Lite/Core should document and support clear autosave/checkpoint entry patterns
- full seamless-save scheduling and background pipelines still belong above the baseline

Godot workflow implication:

- use gameplay events to trigger explicit SaveFlow entry points
- keep the decision local to the game system that owns the event
- avoid hiding save triggers behind too many generic wrappers too early

Recommended baseline pattern:

1. gameplay code decides that a save-worthy event happened
2. gameplay code checks whether the current scene/domain is stable enough to save
3. gameplay code chooses one slot strategy:
   - manual slot
   - rotating autosave slot
   - checkpoint slot
4. gameplay code calls the matching SaveFlow entry point

What Lite should help clarify:

- when to use `save_scene()`
- when to use `save_scope()`
- when a system should save via `save_data()`
- what "do not save right now" usually means in a Godot project

---

## 10. When business metadata and gameplay payload should be kept separate

### Problem: teams often mix save-list data with gameplay-state data

Why it appears:

- the slot file already has metadata, so teams keep adding fields until it becomes messy
- some data belongs in the save list UI
- some data belongs in the actual gameplay payload
- some data should not be in the slot at all

SaveFlow's split:

- Lite/Core should keep this boundary easy to explain
- advanced migration and storage strategy still belong above the baseline

Godot workflow implication:

- put save-list summary fields in slot metadata
- put restorable gameplay state in Sources and payload data
- keep machine-local or rebuildable cache data outside the slot

Good candidates for slot metadata:

- display label
- save type
- chapter/location summary
- playtime summary
- high-level progression summary

Good candidates for gameplay payload:

- player stats and inventory
- quest state
- world progression
- runtime entity state

Usually not good slot payload candidates:

- temporary debug flags
- machine-specific graphics settings
- rebuildable caches
- analytics/session-only values

This boundary matters because it keeps:

- save-list UI simpler
- restore logic cleaner
- future compatibility pressure lower

---

## 11. One Godot project can host many demo save profiles, but that is isolation, not one shared game save

### Problem: why do several demo games in one project not overwrite each other?

Why it appears:

- this repository contains several runnable SaveFlow demos
- each demo wants to save real files
- all of them still run inside one Godot project

The key idea:

- they do **not** share one logical save profile
- they stay compatible by using **isolated save roots and slot indexes**
- the currently running demo scene also configures the `SaveFlow` runtime for its own profile

That means the coexistence model is:

- one Godot project
- many demo save profiles
- one active runtime profile at a time

It is **not**:

- many games writing into one shared slot directory
- one runtime reading every slot format as if they were interchangeable

### How the current demos do it

`complex_sandbox` writes to its own folder:

- `user://complex_sandbox/saves`
- `user://complex_sandbox/slots.index`

`plugin_sandbox` writes to its own folder:

- `user://plugin_sandbox/saves`
- `user://plugin_sandbox/slots.index`

`zelda_like` writes to its own formal and dev folders:

- formal: `user://zelda_like_sandbox/saves`
- formal index: `user://zelda_like_sandbox/slots.index`
- dev: `user://zelda_like_sandbox/devSaves`
- dev index: `user://zelda_like_sandbox/dev-slots.index`

Examples in this project:

- [`complex_sandbox.gd`](F:/Coding-Projects/Godot/plugin-development/demo/saveflow_lite/complex_sandbox/complex_sandbox.gd)
- [`plugin_sandbox.gd`](F:/Coding-Projects/Godot/plugin-development/demo/saveflow_lite/plugin_sandbox/plugin_sandbox.gd)
- [`zelda_like_sandbox.gd`](F:/Coding-Projects/Godot/plugin-development/demo/saveflow_lite/zelda_like/scenes/zelda_like_sandbox.gd)

### How it is implemented

There are two layers:

1. **Path isolation**

- each demo uses a different `save_root`
- each demo uses a different `slot_index_file`
- dev saves also get their own isolated root

2. **Runtime profile isolation**

- the scene that boots the demo calls `SaveFlow.configure(...)` or `SaveFlow.configure_with(...)`
- that scene becomes the owner of the currently active `SaveSettings`
- while that demo is running, `SaveFlow` reads and writes only that profile

For `zelda_like`, DevSaveManager also receives explicit dev-save settings from the demo bridge so editor requests target the correct dev folder instead of the project default.

### Recommended workflow if you want the same pattern

Use this pattern when:

- you are building multiple demos or sandboxes inside one repository
- each demo should behave like its own small game
- you want each demo to keep its own save files for testing

Do it like this:

1. pick a dedicated `user://` subtree for each demo
2. give each demo its own `save_root`
3. give each demo its own `slot_index_file`
4. if you use dev saves, give each demo its own `devSaves` folder too
5. configure `SaveFlow` when that demo scene starts
6. if your editor-side DevSaveManager should target demo-specific dev saves, expose those settings through a bridge

Minimal example:

```gdscript
func _ready() -> void:
    SaveFlow.configure_with(
        "user://my_demo/saves",
        "user://my_demo/slots.index",
        SaveFlow.FORMAT_AUTO,
        true,
        true,
        true,
        true,
        true,
        "My Demo",
        "0.1.0",
        1,
        "my_demo_v1"
    )
```

If you also want isolated dev saves:

```gdscript
func build_dev_save_settings() -> Dictionary:
    return {
        "save_root": "user://my_demo/devSaves",
        "slot_index_file": "user://my_demo/dev-slots.index",
    }
```

### What to do in a shipped game

For a real shipped game, the usual recommendation is different:

- one game
- one primary save profile
- one clear save-root strategy
- multiple domains inside that profile via `SaveFlowScope`

So the normal shipped pattern is:

- shared game profile
- domain boundaries inside the save graph

Not:

- many unrelated save roots for one gameplay experience

If your problem is "player, world, quest log, and runtime actors must restore in the correct order", use one game profile plus multiple scopes.

If your problem is "three separate demo games live in one repository", isolate them by profile path instead.

Godot workflow implication:

- separate progression data from machine-specific configuration
- keep slot and domain structure explicit before adding any sync layer
- do not assume one giant save file is the best sync unit

---

## 8. When objects start pointing at each other, the problem becomes late reference repair

### Problem: the first restore pass cannot resolve every reference safely

Why it appears:

- runtime entities may restore later than system data
- cross-domain objects may come online at different times
- authored objects and runtime objects do not share the same lifecycle

SaveFlow's split:

- Lite/Core handles:
  - explicit save graph structure
  - runtime entity restore seam
  - restore contracts
- Late reference repair belongs above that baseline

Current product ownership:

- advanced post-load reference repair: outside the baseline Lite workflow

Godot workflow implication:

- if you need a second pass to fix links, you are no longer dealing with normal Source apply logic
- that problem should move into an explicit higher-level restore layer instead of being spread across many node scripts

---

## 9. When autosave must not hitch, the problem becomes snapshot and background work

### Problem: saving a large world cannot create visible frame spikes

Why it appears:

- synchronous gather + serialize + write can easily stretch one frame
- large payloads increase write cost and follow-up sync cost

SaveFlow's split:

- Lite/Core handles:
  - correct, explicit, inspectable baseline save behavior
- Background and seamless save workflows belong above that baseline

Current product ownership:

- seamless/background save workflows: outside the baseline Lite workflow

Godot workflow implication:

- Godot's resource loading and thread-safety rules still matter:
  - some preparation can move off the critical path
  - scene attachment and many node operations still need the main thread
- so "seamless save" should be treated as an explicit capture/write workflow, not just "call save on another thread"

---

## 10. What the practical Godot workflow should look like

### Small project

Recommended path:

- `SaveFlowNodeSource`
- `SaveFlowDataSource`
- `SaveFlowEntityCollectionSource`

That is often enough.

### Medium-sized project

Recommended path:

- add `SaveFlowScope`
- define save domains clearly
- define restore order clearly

A typical split:

- player
- world
- settings
- runtime actors

### Commercial-scale project

Recommended path:

- let Lite/Core own:
  - the save graph
  - restore contracts
  - compatibility visibility
  - baseline safety
- keep higher-level orchestration, migration, sync, advanced recovery, and late repair out of leaf Sources

The most useful rule is:

- if you are still answering "which object, system, or runtime set owns this state?", keep working with Sources and Scopes
- if you are answering "which phase restores first, when are references repaired, what wins in sync conflicts, how do old saves evolve?", you are solving a higher-level workflow problem

---

## 11. Terms worth keeping stable

Use these terms consistently:

- **Save Graph**
  - what gets saved, and how it is organized
- **Restore Contract**
  - what must be true before a restore is safe
- **Restore Orchestration**
  - the order and staging of multi-step restore
- **Storage Profile**
  - file format, compression, encryption, integrity, backup, platform policy
- **Compatibility**
  - whether the current slot is safe to restore
- **Migration**
  - upgrading an older slot to a newer project shape
- **Reference Repair**
  - a post-restore link pass
- **Cloud Sync**
  - freshness, conflict policy, merge rules, failure handling

Avoid vague phrasing like:

- "enterprise features"
- "more powerful workflows"
- "commercial support"

Describe the actual project problem instead.

---

## 12. The key boundary to remember

If you already need any of the following:

- staged restore across scenes
- resource-ready gating
- migration instead of simple compatibility refusal
- storage policy beyond baseline file safety
- cloud sync conflict handling
- post-load reference repair
- save performance work to avoid visible hitches

then the project has moved beyond "just add one more Source".

That does not mean Lite/Core failed.

It means the project has moved from:

**"how do I save this state?"**

to:

**"how do I make a complex save/load workflow reliable over time?"**
