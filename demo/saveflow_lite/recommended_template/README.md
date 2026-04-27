# SaveFlow Recommended Template

This folder intentionally keeps one main project-style workflow, plus one small
pipeline-signals scene. It does not bring back the old set of disconnected
reference cases.

Open:
- `res://demo/saveflow_lite/recommended_template/scenes/project_workflow/recommended_project_workflow_main.tscn`
- `res://demo/saveflow_lite/recommended_template/scenes/pipeline_notifications/pipeline_notification_demo.tscn`
- `res://demo/saveflow_lite/recommended_template/scenes/csharp_workflow/csharp_workflow_demo.tscn`

What the project workflow demonstrates:
- main-scene data decides whether the player is in the hub, forest room, or dungeon room
- each authored subscene owns its own room save slot
- `SaveFlowTypedDataSource` saves room data from `TemplateRoomSaveData` exported fields
- `SaveFlowNodeSource` saves the room player transform and `AnimationPlayer` state
- `SaveFlowEntityCollectionSource + SaveFlowPrefabEntityFactory` saves runtime coins
- ordinary scene nodes carry most of the visible gameplay state

What the pipeline notification demo demonstrates:
- `SaveFlowPipelineSignals` nodes live under the scope and under each source
- each source emits its own "Profile/Inventory/Quest Data Saved" notification
- the scope-level bridge emits the final "Data Saved!" notification
- scene-authored signal connections can react to save/load lifecycle stages without subclassing every source

What the C# workflow demo demonstrates:
- `SaveFlowTypedStateSource` stores C# typed room data without per-field dictionaries
- C# source Godot scripts stay non-generic; typed state still uses
  `JsonTypeInfo<T>` and `GetSaveFlowState<T>()` inside the source
- the C# source is a direct child of `SaveGraph`, so no extra target node is needed
- `SaveFlowSlotWorkflow` owns the active slot id and typed metadata construction
- `SaveFlowSlotCard` renders a save-list style summary without loading full payload data
- `SaveFlowClient.SaveScope()` / `LoadScope()` keep the C# call site thin

Folder layout:
- `scenes/project_workflow`
  Runnable hub and room scenes.
- `scenes/pipeline_notifications`
  Runnable pipeline notification scene.
- `scenes/csharp_workflow`
  Small C# typed-data and slot-workflow scene.
- `scenes/prefabs`
  Small runtime prefab used by the room entity collection.
- `gameplay/project_workflow`
  The minimal scripts that make the playable workflow run.
- `gameplay/pipeline_notifications`
  Small typed data and notification controller used by the pipeline demo.
- `gameplay/csharp_workflow`
  C# typed state source and C# scene controller using the public wrapper helpers.
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

For C#, the recommended path is the same scene shape with a direct C# source:

```csharp
public partial class RoomStateSource : SaveFlowTypedStateSource
{
	private RoomState State
	{
		get => GetSaveFlowState<RoomState>();
		set => SetSaveFlowState(value);
	}

	public RoomStateSource()
	{
		SourceKey = "room_state";
		InitializeSaveFlowState(
			new RoomState(12, false, "entry"),
			RoomStateJsonContext.Default.RoomState);
	}
}
```

Place `RoomStateSource` directly under `SaveGraph`, then call SaveFlow from C#
through `SaveFlowClient` and use `SaveFlowSlotWorkflow` to keep active slot ids
and save-card metadata out of ad-hoc string-key dictionaries.
