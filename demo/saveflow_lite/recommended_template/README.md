# SaveFlow Recommended Template

This folder is the smallest scene-oriented SaveFlow template in the repo.

Use it when you want to answer:
- how does `SaveFlowNodeSource` attach to a prefab?
- how does system state use one custom `SaveFlowDataSource`?
- how does an entity collection use `SaveFlowEntityCollectionSource + SaveFlowEntityFactory`?

Folder layout:
- `scenes`
  The runnable template scene and runtime actor prefab
- `gameplay`
  Plain gameplay/state scripts
- `saveflow`
  The minimum SaveFlow extension points that the project must implement

Open:
- `res://demo/saveflow_lite/recommended_template/scenes/recommended_template_sandbox.tscn`
- `res://demo/saveflow_lite/recommended_template/scenes/recommended_template_overview.tscn`
- `res://demo/saveflow_lite/recommended_template/scenes/cases/recommended_node_source_case.tscn`
- `res://demo/saveflow_lite/recommended_template/scenes/cases/recommended_data_source_case.tscn`
- `res://demo/saveflow_lite/recommended_template/scenes/cases/recommended_entity_collection_case.tscn`
- `res://demo/saveflow_lite/recommended_template/scenes/cases/recommended_csharp_case.tscn`
- `res://demo/saveflow_lite/recommended_template/scenes/cases/recommended_slot_summary_case.tscn`
- `res://demo/saveflow_lite/recommended_template/scenes/cases/recommended_autosave_case.tscn`
- `res://demo/saveflow_lite/recommended_template/scenes/cases/recommended_in_game_save_panel_case.tscn`

Regression checklist:
- `res://addons/saveflow_lite/docs/recommended-case-regression-checklist.md`

Common authoring mistakes:
- `res://addons/saveflow_lite/docs/saveflow-common-authoring-mistakes.md`

Recommended first pass:
- Open `recommended_template_sandbox.tscn` as the case launcher
- Open `recommended_node_source_case.tscn` when you want to save one authored or prefab-owned object with `SaveFlowNodeSource`
- Open `recommended_data_source_case.tscn` when you want to save one system, model, table, or queue with `SaveFlowDataSource`
- Open `recommended_entity_collection_case.tscn` when you want to save one changing runtime set with `SaveFlowEntityCollectionSource + SaveFlowPrefabEntityFactory`
- Open `recommended_csharp_case.tscn` when you want to call SaveFlow from C# through `SaveFlowClient`
- Open `recommended_slot_summary_case.tscn` when you want to build a continue/load menu from `list_slot_summaries()` without loading full payloads
- Open `recommended_autosave_case.tscn` when you want gameplay events to write autosave, checkpoint, and manual-save slots explicitly
- Open `recommended_in_game_save_panel_case.tscn` when you want a fuller in-game save/load panel with slot rows, continue, delete, and overwrite confirmation
- Open `recommended_template_overview.tscn` only after the single-path scenes feel clear

What the template demonstrates:
- one object path through `SaveFlowNodeSource`
- one system path through `SaveFlowDataSource`
- one runtime-set path through `SaveFlowEntityCollectionSource + SaveFlowPrefabEntityFactory`
- one `save_scene()` / `load_scene()` entry over a single `StateRoot`

Case scenes:
- `recommended_node_source_case.tscn`
  One authored `Player` node plus one included `AnimationPlayer`
- `recommended_data_source_case.tscn`
  One `WorldRegistry` system node gathered/applied through a custom data source
- `recommended_entity_collection_case.tscn`
  One runtime actor set restored through `SaveFlowEntityCollectionSource + SaveFlowPrefabEntityFactory`
- `recommended_csharp_case.tscn`
  One minimal C# SaveData/LoadData flow using `SaveFlow.DotNet.SaveFlowClient`, plus a slot-summary read for save-list style UI
- `recommended_slot_summary_case.tscn`
  One minimal save-list UI flow driven by `list_slot_summaries()` and `read_slot_summary()`
- `recommended_autosave_case.tscn`
  One minimal gameplay-event flow for autosave, checkpoint, manual save, and project-owned save gating
- `recommended_in_game_save_panel_case.tscn`
  One fuller in-game save/load panel flow driven by slot summaries plus explicit Continue, Load, Save, Delete, and overwrite confirmation
- `recommended_template_overview.tscn`
  The original all-in-one scene kept for side-by-side comparison after the case scenes

Minimum entity factory contract:
- required: `can_handle_type(type_key)`, `spawn_entity_from_save(descriptor)`, `apply_saved_data(node, payload)`
- optional: `find_existing_entity(persistent_id)` when authored or pooled entities should be reused
- optional: `prepare_restore(...)` when `Clear And Restore` needs container cleanup or cache reset

If you are building your first runtime collection, start by implementing only the
required three methods. Add `find_existing_entity()` or `prepare_restore()` only
when the runtime set actually needs reuse or pre-restore cleanup.

Runtime entity collections now have an explicit restore policy:
- `Apply Existing` keeps the current set and only updates found entities
- `Create Missing` keeps the current set and spawns missing ones through the factory
- `Clear And Restore` clears the container first, then rebuilds the saved set

This template is intentionally smaller than the Zelda-like sandbox.
It exists to show the recommended integration shape, not to showcase gameplay.
