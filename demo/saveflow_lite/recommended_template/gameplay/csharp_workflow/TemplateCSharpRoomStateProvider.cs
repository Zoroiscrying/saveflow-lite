using System.Text.Json.Serialization;
using System.Text.Json.Serialization.Metadata;

using Godot;

using GodotArray = Godot.Collections.Array;
using GodotDictionary = Godot.Collections.Dictionary;

using SaveFlow.DotNet;

public sealed record TemplateCSharpRoomState(
	int Coins,
	bool DoorOpen,
	string CheckpointId,
	int MutationCount);

[JsonSourceGenerationOptions(PropertyNamingPolicy = JsonKnownNamingPolicy.SnakeCaseLower)]
[JsonSerializable(typeof(TemplateCSharpRoomState))]
internal partial class TemplateCSharpRoomStateJsonContext : JsonSerializerContext
{
}

public partial class TemplateCSharpRoomStateProvider
	: SaveFlowJsonStateProvider
{
	private const string Schema = "saveflow.template.csharp_room_state";

	private TemplateCSharpRoomState State
	{
		get => GetSaveFlowState<TemplateCSharpRoomState>();
		set => SetSaveFlowState(value);
	}

	public TemplateCSharpRoomStateProvider()
	{
		State = CreateInitialState();
	}

	public int Coins => State.Coins;
	public bool DoorOpen => State.DoorOpen;
	public string CheckpointId => State.CheckpointId;
	public int MutationCount => State.MutationCount;
	[Export] public int ApplyCount { get; set; }
	[Export] public string LastApplyLabel { get; set; } = "";

	protected override string SaveFlowPayloadSchema => Schema;

	protected override JsonTypeInfo SaveFlowJsonTypeInfo
		=> TemplateCSharpRoomStateJsonContext.Default.TemplateCSharpRoomState;

	protected override GodotArray SaveFlowPayloadSections
		=> new() { "coins", "door_open", "checkpoint_id", "mutation_count" };

	public void MutateForDemo()
	{
		State = State with
		{
			Coins = State.Coins + 7,
			DoorOpen = !State.DoorOpen,
			CheckpointId = State.DoorOpen ? "door_closed" : "door_open",
			MutationCount = State.MutationCount + 1,
		};
	}

	public void ResetForDemo()
	{
		State = CreateInitialState();
		ApplyCount = 0;
		LastApplyLabel = "";
	}

	public GodotDictionary Snapshot()
		=> new()
		{
			["coins"] = State.Coins,
			["door_open"] = State.DoorOpen,
			["checkpoint_id"] = State.CheckpointId,
			["mutation_count"] = State.MutationCount,
			["apply_count"] = ApplyCount,
			["last_apply_label"] = LastApplyLabel,
		};

	public void mutate_for_demo()
		=> MutateForDemo();

	public void reset_for_demo()
		=> ResetForDemo();

	public GodotDictionary snapshot()
		=> Snapshot();

	protected override void OnSaveFlowStateApplied(object? state)
	{
		if (state is not TemplateCSharpRoomState typedState)
			return;

		ApplyCount += 1;
		LastApplyLabel = $"{typedState.CheckpointId}:{typedState.Coins}";
	}

	private static TemplateCSharpRoomState CreateInitialState()
		=> new(Coins: 12, DoorOpen: false, CheckpointId: "entry", MutationCount: 0);
}
