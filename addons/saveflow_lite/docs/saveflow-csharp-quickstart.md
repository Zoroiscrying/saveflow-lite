# SaveFlow C# Quickstart

This document shows the minimal C# path for calling SaveFlow runtime APIs.

Runnable demo:

- `res://demo/saveflow_lite/recommended_template/scenes/csharp_workflow/csharp_workflow_demo.tscn`

That scene uses `SaveFlowTypedStateSource`,
`SaveFlowSlotWorkflow`, `SaveFlowSlotCard`, and
`SaveFlowClient.SaveScope()` together.

## Wrapper Location

The baseline C# wrapper is shipped in `saveflow_core`:

- `res://addons/saveflow_core/runtime/dotnet/client/SaveFlowClient.cs`
- `res://addons/saveflow_core/runtime/dotnet/client/SaveFlowCallResult.cs`
- `res://addons/saveflow_core/runtime/dotnet/slots/SaveFlowSlotMetadata.cs`
- `res://addons/saveflow_core/runtime/dotnet/slots/SaveFlowSlotWorkflow.cs`
- `res://addons/saveflow_core/runtime/dotnet/slots/SaveFlowSlotCard.cs`
- `res://addons/saveflow_core/runtime/dotnet/entities/SaveFlowEntityDescriptor.cs`

## Godot C# Script Registration Boundary

SaveFlow's C# source bases are intentionally **non-generic Godot script
classes**:

```csharp
public partial class RoomStateSource : SaveFlowTypedStateSource
{
}
```

Do not write a Godot script base like this:

```csharp
public partial class RoomStateSource : SaveFlowTypedStateSource<RoomSaveState>
{
}
```

Plain C# generics are still fine. Use them for DTOs, source-generated
`JsonTypeInfo<T>`, `SaveFlowEncodedPayload.CreateJsonPayload<T>()`, and the
typed state wrapper:

```csharp
private RoomSaveState State
{
	get => GetSaveFlowState<RoomSaveState>();
	set => SetSaveFlowState(value);
}
```

The boundary is Godot's script registration system: `Node`, `Resource`, and
`RefCounted` script classes should stay non-generic and live in a `.cs` file
whose filename matches the class name. Generic `GodotObject` script bases can
compile, but they are unsafe during editor reload because Godot maps script
resources to C# types differently from ordinary .NET code.

## Basic Usage

```csharp
using Godot;
using Godot.Collections;
using SaveFlow.DotNet;

public partial class SaveFlowCSharpExample : Node
{
	public override void _Ready()
	{
		if (!SaveFlowClient.IsRuntimeAvailable())
		{
			GD.PrintErr("SaveFlow runtime is not available.");
			return;
		}

		SaveFlowClient.Configure(
			"user://my_game/saves",
			"user://my_game/slots.index");

		var payload = new Dictionary
		{
			["coins"] = 42,
			["room"] = "forest_gate"
		};

		var saveResult = SaveFlowClient.SaveData(
			"slot_a",
			payload,
			"Forest Gate",
			"manual",
			"Chapter 2",
			"Forest Gate",
			1320);
		if (!saveResult.Ok)
		{
			GD.PrintErr($"Save failed: {saveResult.ErrorKey} {saveResult.ErrorMessage}");
			return;
		}

		var loadResult = SaveFlowClient.LoadData("slot_a");
		if (!loadResult.Ok)
		{
			GD.PrintErr($"Load failed: {loadResult.ErrorKey} {loadResult.ErrorMessage}");
			return;
		}

		GD.Print($"Loaded payload: {loadResult.Data}");
	}
}
```

## Current API Surface

- `SaveFlowClient.SaveData(...)`
- `SaveFlowClient.LoadData(...)`
- `SaveFlowClient.SaveSlot(...)`
- `SaveFlowClient.LoadSlot(...)`
- `SaveFlowClient.LoadSlotData(...)`
- `SaveFlowClient.BuildSlotMetadata(...)`
- `SaveFlowClient.BuildSlotMetadataPatch(...)`
- `SaveFlowClient.ListSlots(...)`
- `SaveFlowClient.ReadSlotSummary(...)`
- `SaveFlowClient.ReadSlotMetadata(...)`
- `SaveFlowClient.ReadSlotMetadataAsObject<TMetadata>(...)`
- `SaveFlowClient.TryReadSlotMetadata<TMetadata>(...)`
- `SaveFlowClient.ListSlotSummaries(...)`
- `SaveFlowClient.DeleteSlot(...)`
- `SaveFlowClient.CopySlot(...)`
- `SaveFlowClient.RenameSlot(...)`
- `SaveFlowClient.ValidateSlot(...)`
- `SaveFlowClient.InspectSlotStorage(...)`
- `SaveFlowClient.SaveNodes(...)`
- `SaveFlowClient.LoadNodes(...)`
- `SaveFlowClient.InspectScene(...)`
- `SaveFlowClient.CollectNodes(...)`
- `SaveFlowClient.ApplyNodes(...)`
- `SaveFlowClient.SaveScope(...)`
- `SaveFlowClient.LoadScope(...)`
- `SaveFlowClient.InspectScope(...)`
- `SaveFlowClient.GatherScope(...)`
- `SaveFlowClient.ApplyScope(...)`
- `SaveFlowClient.SaveCurrent(...)`
- `SaveFlowClient.LoadCurrent(...)`
- `SaveFlowClient.InspectSlotCompatibility(...)`
- `SaveFlowClient.RestoreEntities(...)`
- `SaveFlowClient.SaveDevNamedEntry(...)`
- `SaveFlowClient.LoadDevNamedEntry(...)`

## Typed Slot Metadata

SaveFlow stores slot metadata as dictionaries on disk, but new C# gameplay code
should use `SaveFlowSlotMetadata` and extend it for project-specific save-list
fields.

```csharp
using Godot;
using Godot.Collections;
using SaveFlow.DotNet;

public sealed class MySlotMetadata : SaveFlowSlotMetadata
{
	[Export] public int SlotIndex { get; set; }
	[Export] public string StorageKey { get; set; } = "";
	[Export] public string SlotRole { get; set; } = "";
}
```

Grouped metadata can also live in a typed helper object. Prefer
`SaveFlowTypedResource` for small editable metadata groups, or an encoded payload
provider when the group should use project-owned JSON/binary serialization:

```csharp
using Godot;
using SaveFlow.DotNet;

public partial class MySlotRowData : SaveFlowTypedResource
{
	[Export] public int SlotIndex { get; set; }
	[Export] public string StorageKey { get; set; } = "";
}

public sealed class MyGroupedSlotMetadata : SaveFlowSlotMetadata
{
	[Export] public MySlotRowData RowData { get; set; } = new();
}
```

```csharp
using Godot;
using Godot.Collections;
using SaveFlow.DotNet;

public partial class SaveMenuExample : Node
{
	public void SaveSlot()
	{
		var payload = new Dictionary
		{
			["coins"] = 14,
			["location"] = "forest_gate",
		};

		var meta = new MySlotMetadata
		{
			DisplayName = "Forest Gate",
			SaveType = "autosave",
			ChapterName = "Chapter 2",
			LocationName = "Forest Gate",
			PlaytimeSeconds = 1320,
			Difficulty = "normal",
			SlotIndex = 1,
			StorageKey = "slot_1",
			SlotRole = "room_subscene",
		};

var saveResult = SaveFlowClient.SaveData("slot_1", payload, meta);
	}
}
```

`BuildSlotMetadata(...)` returns the typed default metadata object. Use
`BuildSlotMetadataPatch(...)` only when a low-level integration explicitly needs
a `Godot.Collections.Dictionary`.

SaveFlow emits an authoring warning when metadata contains runtime objects, raw
Godot objects, or too many custom fields. Keep metadata focused on save-list UI;
move full gameplay state into the payload, a SaveFlow source, or an encoded C#
payload provider.

## Active Slot and Save Cards

Use `SaveFlowSlotWorkflow` when your C# save menu owns an integer selected slot
and needs stable storage keys plus UI-facing cards.

```csharp
using Godot;
using SaveFlow.DotNet;

public sealed class MySlotMetadata : SaveFlowSlotMetadata
{
	[Export] public int SlotIndex { get; set; }
	[Export] public string StorageKey { get; set; } = "";
	[Export] public string SlotRole { get; set; } = "";
}

public partial class SaveMenuController : Node
{
	private readonly SaveFlowSlotWorkflow _slots = new()
	{
		SlotIdTemplate = "slot_{index}",
		EmptyDisplayNameTemplate = "Manual Slot {index}",
	};

	public void SelectSlot(int index)
	{
		_slots.SelectSlotIndex(index);
	}

	public void SaveSelectedSlot()
	{
		var metadata = _slots.BuildActiveSlotMetadata<MySlotMetadata>(
			"Forest Gate",
			saveType: "manual",
			chapterName: "Chapter 2",
			locationName: "Forest Gate",
			playtimeSeconds: 960,
			slotRole: "manual");

		var result = SaveFlowClient.SaveData(
			_slots.ActiveSlotId(),
			new Godot.Collections.Dictionary { ["coins"] = 14 },
			metadata);
	}
}
```

To build a load screen, read summaries and map them to cards:

```csharp
var summaries = SaveFlowClient.ListSlotSummaries();
var summaryArray = summaries.Ok && summaries.Data.VariantType == Variant.Type.Array
	? summaries.Data.AsGodotArray()
	: new Godot.Collections.Array();

var cards = _slots.BuildCardsForIndices(new[] { 1, 2, 3 }, summaryArray);
```

The workflow keeps three concepts separate:

- `SlotIndex` is the user-facing selected row/order.
- `StorageKey` / `SlotId` is the stable SaveFlow slot id, such as `slot_2`.
- `DisplayName` is metadata shown in the save-list UI.

## Runtime Entity Descriptor Helper

Runtime entity descriptors are stored as dictionaries because they cross the
GDScript save graph boundary. C# integrations should still read them through
`SaveFlowEntityDescriptor` instead of handwritten keys:

```csharp
using Godot;
using Godot.Collections;
using SaveFlow.DotNet;

public static Node SpawnEnemy(Dictionary descriptor)
{
	var entityDescriptor = SaveFlowEntityDescriptor.FromDictionary(descriptor);
	var enemy = new Node { Name = entityDescriptor.PersistentId };
	return enemy;
}
```

## C# Typed Data Without Manual Dictionary Keys

For C# gameplay state, prefer a direct encoded typed source. The C# side owns
serialization, and SaveFlow stores the result as one typed payload inside the
normal save graph. This avoids per-field SaveFlow reflection and avoids
hand-written dictionary keys in gameplay code.

For most new C# save data, start with `SaveFlowTypedStateSource`.
You define one DTO and one source-generated `JsonTypeInfo`. SaveFlow can derive
the default schema from the DTO type and the default inspector/diagnostic
sections from the serialized JSON property names:

The source class itself stays non-generic for Godot editor reload safety.
Register the source-generated `JsonTypeInfo<T>` once with
`InitializeSaveFlowState(...)`; after that, typed gameplay state is kept through
`GetSaveFlowState<T>()` / `SetSaveFlowState(...)`.

Users should not write separate JSON and binary classes for the same business
state. `SaveFlowTypedStateSource` keeps one typed state lifecycle and exposes
`PayloadEncoding` as a setting. `JsonText` is editor-friendly; `JsonBytes`
stores the same typed state as bytes. In both cases load ends with the same
typed `State` object and calls `OnSaveFlowStateApplied(...)`.

`SaveFlowPayloadSchema` and `SaveFlowPayloadSections` have defaults. Schema uses
the DTO type name from `JsonTypeInfo`; sections use the serialized JSON property
names from `JsonTypeInfo.Properties`. Override schema for long-lived commercial
saves that must survive class/namespace renames. Override sections only when the
inspector should show broader business groups instead of field names.

```csharp
using System.Text.Json.Serialization;
using Godot;
using SaveFlow.DotNet;

public sealed record RoomSaveState(
	int Coins,
	bool DoorOpen,
	string CheckpointId);

[JsonSourceGenerationOptions(PropertyNamingPolicy = JsonKnownNamingPolicy.SnakeCaseLower)]
[JsonSerializable(typeof(RoomSaveState))]
internal partial class RoomSaveJsonContext : JsonSerializerContext
{
}

public partial class RoomStateSource : SaveFlowTypedStateSource
{
	private RoomSaveState State
	{
		get => GetSaveFlowState<RoomSaveState>();
		set => SetSaveFlowState(value);
	}

	public RoomStateSource()
	{
		SourceKey = "room_state";
		InitializeSaveFlowState(
			new RoomSaveState(10, false, ""),
			RoomSaveJsonContext.Default.RoomSaveState);
	}

	protected override void OnSaveFlowStateApplied(object? state)
	{
		if (state is not RoomSaveState roomState)
			return;

		// Refresh visuals, collisions, UI, or derived runtime state here.
	}
}
```

Put that C# source directly under the `SaveGraph`/`SaveFlowScope`:

```text
RoomRoot
|- SaveGraph
   |- RoomStateSource (C# script extends SaveFlowTypedStateSource)
```

Use the explicit encoded-payload methods only when an existing manager node cannot
inherit from a SaveFlow base class, or when capture/apply needs custom project
logic:

```csharp
using System.Text.Json.Serialization;

using Godot;
using Godot.Collections;
using SaveFlow.DotNet;

public sealed record RoomSaveState(
	int Coins,
	bool DoorOpen,
	string CheckpointId);

[JsonSourceGenerationOptions(PropertyNamingPolicy = JsonKnownNamingPolicy.SnakeCaseLower)]
[JsonSerializable(typeof(RoomSaveState))]
internal partial class RoomSaveJsonContext : JsonSerializerContext
{
}

public partial class CSharpRoomManager : Node
{
	private const string Schema = "my_game.room_state";

	[Export] public int Coins { get; set; } = 10;
	[Export] public bool DoorOpen { get; set; }
	[Export] public string CheckpointId { get; set; } = "";

	public Dictionary ToSaveFlowEncodedPayload()
		=> SaveFlowEncodedPayload.CreateJsonPayload(
			new RoomSaveState(Coins, DoorOpen, CheckpointId),
			RoomSaveJsonContext.Default.RoomSaveState,
			Schema);

	public void ApplySaveFlowEncodedPayload(Dictionary payload)
		=> SaveFlowEncodedPayload.ApplyJsonPayload(
			payload,
			RoomSaveJsonContext.Default.RoomSaveState,
			state =>
			{
				Coins = state.Coins;
				DoorOpen = state.DoorOpen;
				CheckpointId = state.CheckpointId;
			});

	public Dictionary GetSaveFlowPayloadInfo()
		=> SaveFlowEncodedPayload.JsonInfo(
			Schema,
			sections: new Godot.Collections.Array { "coins", "door_open", "checkpoint_id" });
}
```

In the scene, point `SaveFlowTypedDataSource.target` at the manager node and
leave `data_property` empty.

```text
RoomRoot
|- RoomManager (CSharpRoomManager)
|- SaveGraph
   |- RoomStateSource (SaveFlowTypedDataSource, target=RoomManager)
```

Then save/load the graph from C#:

```csharp
var graph = GetNode<Node>("SaveGraph");

var saveResult = SaveFlowClient.SaveScope(
	"slot_1",
	graph,
	"Room Save",
	saveType: "manual",
	locationName: "Forest Room");

var loadResult = SaveFlowClient.LoadScope("slot_1", graph, strict: true);
```

### Default State Apply

If the saveable C# object is just one state snapshot, inherit
`SaveFlowTypedStateSource`. The default load behavior replaces
`SaveFlowState` and then calls `OnSaveFlowStateApplied(...)`. Use a tiny typed
property around `GetSaveFlowState<T>()` / `SetSaveFlowState(...)` when gameplay
code wants a strongly typed `State` member.

```csharp
public partial class RoomStateSource : SaveFlowTypedStateSource
{
	private RoomSaveState State
	{
		get => GetSaveFlowState<RoomSaveState>();
		set => SetSaveFlowState(value);
	}

	public RoomStateSource()
	{
		SourceKey = "room_state";
		InitializeSaveFlowState(
			new RoomSaveState(10, false, ""),
			RoomSaveJsonContext.Default.RoomSaveState);
	}

	protected override void OnSaveFlowStateApplied(object? state)
	{
		if (state is not RoomSaveState roomState)
			return;

		// Refresh visuals, collisions, UI, or derived runtime state here.
	}
}
```

Use the explicit `ToSaveFlowEncodedPayload` / `ApplySaveFlowEncodedPayload`
shape only when applying loaded data requires custom restore logic instead of
simple state replacement.

### Binary Payloads

For normal typed state, do not write a second class just to switch storage
shape. Keep `SaveFlowTypedStateSource` and change `PayloadEncoding`:

```csharp
public RoomStateSource()
{
	SourceKey = "room_state";
	State = new RoomSaveState(10, false, "");
	PayloadEncoding = SaveFlowStatePayloadEncoding.JsonBytes;
}
```

This still uses the same DTO, same `State` property, same post-apply hook, and
same `JsonTypeInfo`. SaveFlow writes bytes in the payload, but the loaded result
is still a typed `RoomSaveState`.

Use `SaveFlowEncodedSource` only for an advanced custom binary format, such as
`BinaryWriter`, MessagePack, protobuf, MemoryPack, or a project-owned encoder.
This keeps the node directly composable in the SaveGraph without introducing a
separate binary source type.

Advanced custom binary shape:

```csharp
using System.IO;
using System.Text;
using Godot;
using Godot.Collections;
using SaveFlow.DotNet;

public sealed record RoomBinaryState(
	int Coins,
	bool DoorOpen,
	string CheckpointId);

public partial class RoomBinaryStateSource : SaveFlowEncodedSource
{
	private RoomBinaryState State { get; set; } = new(10, false, "");

	public RoomBinaryStateSource()
	{
		SourceKey = "room_state";
	}

	public override Dictionary ToSaveFlowEncodedPayload()
		=> SaveFlowEncodedPayload.FromBytes(
			SerializeState(State),
			"binary-writer",
			SaveFlowEncodedPayload.ContentTypeBinary,
			"my_game.room_state");

	public override void ApplySaveFlowEncodedPayload(Dictionary payload)
	{
		var bytes = SaveFlowEncodedPayload.GetBytes(payload);
		if (bytes.Length == 0)
			return;
		State = DeserializeState(bytes);
		RefreshRoomFromState(State);
	}

	public override Dictionary GetSaveFlowPayloadInfo()
		=> SaveFlowEncodedPayload.BinaryInfo(
			"my_game.room_state",
			sections: new Godot.Collections.Array { "coins", "door_open", "checkpoint_id" },
			encoding: "binary-writer");

	private static byte[] SerializeState(RoomBinaryState state)
	{
		using var stream = new MemoryStream();
		using var writer = new BinaryWriter(stream, Encoding.UTF8, leaveOpen: true);
		writer.Write(state.Coins);
		writer.Write(state.DoorOpen);
		writer.Write(state.CheckpointId);
		writer.Flush();
		return stream.ToArray();
	}

	private static RoomBinaryState DeserializeState(byte[] bytes)
	{
		using var stream = new MemoryStream(bytes);
		using var reader = new BinaryReader(stream, Encoding.UTF8);
		return new(reader.ReadInt32(), reader.ReadBoolean(), reader.ReadString());
	}

	private void RefreshRoomFromState(RoomBinaryState state)
	{
		// Refresh visuals, collisions, UI, or derived runtime state here.
	}
}
```

Put that source directly under the graph. If an existing manager cannot inherit
from `SaveFlowEncodedSource`, implement the same encoded-payload methods on the
manager and point a `SaveFlowTypedDataSource` at it.

## Reflection Convenience Path

For small C# data where convenience matters more than throughput, inherit
`SaveFlowTypedResource` and write exported fields or properties. SaveFlow maps
member names to `snake_case` payload keys through a cached reflection helper.

```csharp
using Godot;
using SaveFlow.DotNet;

[GlobalClass]
public partial class CSharpRoomData : SaveFlowTypedResource
{
	[Export] public int Coins { get; set; } = 10;
	[Export] public bool DoorOpen { get; set; }

	[Export]
	[SaveFlowKey("checkpoint_id")]
	public string CheckpointId { get; set; } = "";

	[Export]
	[SaveFlowIgnore]
	public string DebugLabel { get; set; } = "";
}
```

If the data already lives on an existing C# node or manager, use the helper
instead of writing per-field dictionary code:

```csharp
using Godot;
using Godot.Collections;
using SaveFlow.DotNet;

public partial class CSharpRoomManager : Node
{
	[Export] public int Coins { get; set; } = 10;
	[Export] public bool DoorOpen { get; set; }

	public Dictionary ToSaveFlowPayload()
		=> SaveFlowTypedPayload.ToPayload(this);

	public void ApplySaveFlowPayload(Dictionary payload)
		=> SaveFlowTypedPayload.ApplyPayload(this, payload);

	public Array GetSaveFlowPropertyNames()
		=> SaveFlowTypedPayload.GetPropertyNames(this);
}
```

For this node-manager shape, set `SaveFlowTypedDataSource.target` to the manager
node and leave `data_property` empty. This path is intentionally a compatibility
and low-boilerplate option; use encoded payloads for large state or frequent
autosave.

## Notes

- The wrapper is intentionally thin: it forwards to the `SaveFlow` autoload.
- Return values are normalized to `SaveFlowCallResult`.
- Prefer `SaveFlowSlotMetadata` and subclasses for save-list fields; use `BuildSlotMetadataPatch(...)` only for compatibility call sites that still expect dictionaries.
- Compatibility inspection is available in C# too, so schema/data-version checks do not become a GDScript-only workflow.
- Slot-summary reads are available in C# too, so save-list UI does not need to load the full gameplay payload first.
- `SaveFlowTypedStateSource` is the preferred C# path for one typed state object. Put it directly under a `SaveFlowScope`/`SaveGraph`; `PayloadEncoding` only changes payload shape.
- `SaveFlowEncodedPayload` is the advanced C# path when a manager owns custom capture/apply or a custom binary encoder.
- `SaveFlowTypedStateSource` owns the common C# typed-state lifecycle and is the preferred direct graph source. Use explicit encoded-payload methods only when a project-owned manager or custom encoder cannot inherit from the source.
- Keep `Node`/`Resource`/`RefCounted` C# script bases non-generic and in same-name files. Use generics inside DTOs, `JsonTypeInfo<T>`, encoded payload helpers, and typed state wrappers instead.
- `SaveFlowTypedResource`, `SaveFlowTypedRefCounted`, and `SaveFlowTypedPayload` are reflection convenience helpers for small or low-frequency state.
