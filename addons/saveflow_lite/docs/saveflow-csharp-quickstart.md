# SaveFlow C# Quickstart

This document shows the minimal C# path for calling SaveFlow runtime APIs.

## Wrapper Location

The baseline C# wrapper is shipped in `saveflow_core`:

- `res://addons/saveflow_core/runtime/dotnet/SaveFlowClient.cs`
- `res://addons/saveflow_core/runtime/dotnet/SaveFlowCallResult.cs`
- `res://addons/saveflow_core/runtime/dotnet/SaveFlowSlotMetadata.cs`
- `res://addons/saveflow_core/runtime/dotnet/SaveFlowEntityDescriptor.cs`

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
- `SaveFlowClient.BuildSlotMetadata(...)`
- `SaveFlowClient.BuildSlotMetadataPatch(...)`
- `SaveFlowClient.ReadSlotSummary(...)`
- `SaveFlowClient.ListSlotSummaries(...)`
- `SaveFlowClient.SaveNodes(...)`
- `SaveFlowClient.LoadNodes(...)`
- `SaveFlowClient.SaveScope(...)`
- `SaveFlowClient.LoadScope(...)`
- `SaveFlowClient.SaveCurrent(...)`
- `SaveFlowClient.LoadCurrent(...)`
- `SaveFlowClient.InspectSlotCompatibility(...)`
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

For C# gameplay state, prefer an encoded payload provider. The C# side owns
serialization, and SaveFlow stores the result as one typed payload inside the
normal save graph. This avoids per-field SaveFlow reflection and avoids
hand-written dictionary keys in gameplay code.

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
`SaveFlowJsonStateProvider<TState>`. The default load behavior replaces
`State` and then calls `OnSaveFlowStateApplied(...)`.

```csharp
public partial class RoomStateProvider : SaveFlowJsonStateProvider<RoomSaveState>
{
	private RoomSaveState _state = new(10, false, "");

	protected override RoomSaveState State
	{
		get => _state;
		set => _state = value;
	}

	protected override JsonTypeInfo<RoomSaveState> SaveFlowJsonTypeInfo
		=> RoomSaveJsonContext.Default.RoomSaveState;

	protected override void OnSaveFlowStateApplied(RoomSaveState state)
	{
		// Refresh visuals, collisions, UI, or derived runtime state here.
	}
}
```

Use the explicit `ToSaveFlowEncodedPayload` / `ApplySaveFlowEncodedPayload`
shape when applying loaded data requires custom restore logic instead of simple
state replacement.

### Binary Payloads

JSON is the recommended editor-friendly default, but C# projects can also store
binary encoded payloads. SaveFlow does not choose a binary format for you; it
stores the `byte[]` returned by your provider. That keeps the path compatible
with `BinaryWriter`, MessagePack, protobuf, MemoryPack, or any project-owned
encoder.

For the common state-object shape, inherit
`SaveFlowBinaryStateProvider<TState>`:

```csharp
using System.IO;
using System.Text;
using Godot;
using SaveFlow.DotNet;

public sealed record RoomBinaryState(
	int Coins,
	bool DoorOpen,
	string CheckpointId);

public partial class RoomBinaryStateProvider
	: SaveFlowBinaryStateProvider<RoomBinaryState>
{
	private RoomBinaryState _state = new(10, false, "");

	protected override string SaveFlowPayloadSchema => "my_game.room_state";
	protected override string SaveFlowBinaryEncoding => "binary-writer";

	protected override RoomBinaryState State
	{
		get => _state;
		set => _state = value;
	}

	protected override byte[] SerializeSaveState(RoomBinaryState state)
	{
		using var stream = new MemoryStream();
		using var writer = new BinaryWriter(stream, Encoding.UTF8, leaveOpen: true);
		writer.Write(state.Coins);
		writer.Write(state.DoorOpen);
		writer.Write(state.CheckpointId);
		writer.Flush();
		return stream.ToArray();
	}

	protected override RoomBinaryState DeserializeSaveState(byte[] bytes)
	{
		using var stream = new MemoryStream(bytes);
		using var reader = new BinaryReader(stream, Encoding.UTF8);
		return new(reader.ReadInt32(), reader.ReadBoolean(), reader.ReadString());
	}

	protected override void OnSaveFlowStateApplied(RoomBinaryState state)
	{
		// Refresh visuals, collisions, UI, or derived runtime state here.
	}
}
```

Use `SaveFlowBinaryResource<TData>` for resource-backed binary data, or call
`SaveFlowEncodedPayload.CreateBinaryPayload(...)` directly if an existing
manager needs full control over capture/apply.

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
- `SaveFlowEncodedPayload` is the preferred C# path when performance matters; it uses user-owned serialization such as source-generated `System.Text.Json` or binary encoders.
- `SaveFlowTypedResource`, `SaveFlowTypedRefCounted`, and `SaveFlowTypedPayload` are reflection convenience helpers for small or low-frequency state.
