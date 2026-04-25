# SaveFlow Recommended Template

This folder intentionally contains one project-style workflow, not a set of
separate reference cases.

Open:
- `res://demo/saveflow_lite/recommended_template/scenes/project_workflow/recommended_project_workflow_main.tscn`

What it demonstrates:
- main-scene data decides whether the player is in the hub, forest room, or dungeon room
- each authored subscene owns its own room save slot
- `SaveFlowTypedDataSource` saves room data from `TemplateRoomSaveData` exported fields
- `SaveFlowNodeSource` saves the room player transform and `AnimationPlayer` state
- `SaveFlowEntityCollectionSource + SaveFlowPrefabEntityFactory` saves runtime coins
- ordinary scene nodes carry most of the visible gameplay state

Folder layout:
- `scenes/project_workflow`
  Runnable hub and room scenes.
- `scenes/prefabs`
  Small runtime prefab used by the room entity collection.
- `gameplay/project_workflow`
  The minimal scripts that make the playable workflow run.
- `saveflow`
  Small SaveFlow integration helpers shared by the workflow.

The old standalone NodeSource/DataSource/EntityCollection/C# cases were removed
from this template because they made the recommended path feel heavier than a
normal Godot project. Use the project workflow scene tree as the primary example:
the SaveFlow components live next to the nodes they save.

Room business state intentionally avoids hand-written string-key dictionaries.
`TemplateRoomSaveData` is a typed `SaveFlowTypedData` resource:

```gdscript
@export var door_open := false
@export var collected_coins: PackedStringArray = []
@export var event_count := 0
```

`WorldSource` is a `SaveFlowTypedDataSource` that references the same typed
resource directly, converts its exported fields to the normal SaveFlow payload
at save time, and applies them back at load time.
The Source also accepts any object with `to_saveflow_payload()` and
`apply_saveflow_payload()`; this template uses the Resource path because it is
the clearest scene-owned Godot workflow.
Use a custom `SaveFlowDataSource` only when the source itself needs bespoke
gather/apply behavior.
