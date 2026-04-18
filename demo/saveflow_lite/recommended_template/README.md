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

What the template demonstrates:
- one local prefab-owned `SaveFlowNodeSource` on `Player`
- one custom `SaveFlowDataSource` for world state
- one `SaveFlowEntityCollectionSource` with an entity factory; the collection owns descriptor gather/apply and the factory owns runtime find/spawn/apply behavior
- one `save_scene()` / `load_scene()` entry over a single `StateRoot`

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
