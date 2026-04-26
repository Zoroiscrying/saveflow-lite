# SaveFlow Lite Demo

Open `res://demo/saveflow_lite/plugin_sandbox/plugin_sandbox.tscn` to try the current SaveFlow Lite sandbox.
Open `res://demo/saveflow_lite/complex_sandbox/complex_sandbox.tscn` to pressure SaveFlow with a more realistic mid-size save environment.
Open `res://demo/saveflow_lite/zelda_like/scenes/zelda_like_sandbox.tscn` to run a room-switching Zelda-like sandbox with room physics, animation state, room tables, and runtime entity restore.
Open `res://demo/saveflow_lite/recommended_template/scenes/project_workflow/recommended_project_workflow_main.tscn` to see the recommended integration template: one hub scene, authored subscenes, typed room data, node data, and runtime entity collections in one playable workflow.
Open `res://demo/saveflow_lite/recommended_template/scenes/pipeline_notifications/pipeline_notification_demo.tscn` to see scene-authored pipeline signals drive source-level and final "Data Saved!" notifications.

The Zelda-like sample is further split into:
- `zelda_like/scenes`
- `zelda_like/gameplay`
- `zelda_like/saveflow`

See [zelda_like/README.md](F:/Coding-Projects/Godot/plugin-development/demo/saveflow_lite/zelda_like/README.md) for the intent of each folder.

The scene is meant to demonstrate the main Lite workflow:
- mutate local state
- save a scene through `SaveFlow.save_scene()`
- load the slot back through `SaveFlow.load_scene()`
- inspect the scene through `SaveFlow.inspect_scene()`
- inspect slot listing and deletion behavior

The complex sandbox adds:
- a `SaveFlow.save_scope()` graph over player, world, party, settings, and enemies
- player transform and combat state
- world flags and collected progression
- quest progress and cross-system IDs
- party members
- dynamic enemies that expose current runtime-entity limitations

The current sandbox uses `SaveFlowNodeSource` children plus `@export` fields on the target nodes.
This keeps the target gameplay nodes free from hand-written `get_save_data()` / `apply_save_data()` boilerplate and avoids large manual property lists for ordinary state.

The complex sandbox shows the next architectural step:
- `SaveFlowScope` for logical save domains
- `SaveFlowNodeSource` as the default leaf `SaveFlowSource`
- strict load reporting when a graph source loses its target
- the remaining need for an entity collection + entity factory seam when runtime entities must be recreated

The Zelda-like sandbox adds:
- a top-down room stage with collision, doorway transitions, and in-world ASCII-style rendering
- keyboard movement with `WASD` / arrow keys and sword swing on `Space`
- player fields plus animation playback state
- a custom room data source that represents loaded and unloaded room state
- runtime room entities restored through `SaveFlowEntityCollectionSource + SaveFlowEntityFactory`
- per-entity local `SaveFlowScope` graphs for composite runtime state
- a direct way to break the current room runtime set and verify load-time repair

Related files:
- `plugin_sandbox.gd`
- `sandbox_player.gd`
- `sandbox_settings.gd`
