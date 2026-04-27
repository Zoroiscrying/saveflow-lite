using System.Text.Json.Serialization;

using Godot;

using GodotDictionary = Godot.Collections.Dictionary;

using SaveFlow.DotNet;

public sealed record TemplateCSharpRoomState(
	int Coins,
	bool DoorOpen,
	string CheckpointId,
	int MutationCount,
	float PlayerX,
	float PlayerY);

[JsonSourceGenerationOptions(PropertyNamingPolicy = JsonKnownNamingPolicy.SnakeCaseLower)]
[JsonSerializable(typeof(TemplateCSharpRoomState))]
internal partial class TemplateCSharpRoomStateJsonContext : JsonSerializerContext
{
}

public partial class TemplateCSharpRoomStateSource
	: SaveFlowTypedStateSource
{
	private const string Schema = "saveflow.template.csharp_room_state";

	private TemplateCSharpRoomState State
	{
		get => GetSaveFlowState<TemplateCSharpRoomState>();
		set => SetSaveFlowState(value);
	}

	public TemplateCSharpRoomStateSource()
	{
		SourceKey = "room_state";
		InitializeSaveFlowState(
			CreateInitialState(),
			TemplateCSharpRoomStateJsonContext.Default.TemplateCSharpRoomState);
	}

	public int Coins => State.Coins;
	public bool DoorOpen => State.DoorOpen;
	public string CheckpointId => State.CheckpointId;
	public int MutationCount => State.MutationCount;
	public Vector2 PlayerPosition => new(State.PlayerX, State.PlayerY);
	[Export] public int ApplyCount { get; set; }
	[Export] public string LastApplyLabel { get; set; } = "";

	// Stable payload identity for compatibility checks and future migrations.
	// Keep this stable even if the C# class or namespace is renamed.
	protected override string SaveFlowPayloadSchema => Schema;

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

	public void SetPlayerPosition(Vector2 position)
	{
		State = State with
		{
			PlayerX = position.X,
			PlayerY = position.Y,
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
			["player_x"] = State.PlayerX,
			["player_y"] = State.PlayerY,
			["apply_count"] = ApplyCount,
			["last_apply_label"] = LastApplyLabel,
		};

	public void mutate_for_demo()
		=> MutateForDemo();

	public void reset_for_demo()
		=> ResetForDemo();

	public void set_player_position(Vector2 position)
		=> SetPlayerPosition(position);

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
		=> new(
			Coins: 12,
			DoorOpen: false,
			CheckpointId: "entry",
			MutationCount: 0,
			PlayerX: 325.0f,
			PlayerY: 390.0f);
}
