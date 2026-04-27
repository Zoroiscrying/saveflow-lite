using System;

using Godot;

using GodotDictionary = Godot.Collections.Dictionary;

using SaveFlow.DotNet;

public partial class TemplateCSharpWorkflowDemo : Control
{
	private const int SlotIndex = 30;
	private const string SlotId = "csharp_workflow_demo";
	private const float PlayerSpeed = 300.0f;

	private static readonly Rect2 RoomBounds = new(new Vector2(160, 175), new Vector2(910, 390));
	private static readonly Rect2 TypedStateZone = new(new Vector2(190, 220), new Vector2(265, 280));
	private static readonly Rect2 SlotWorkflowZone = new(new Vector2(520, 220), new Vector2(265, 280));
	private static readonly Rect2 SaveClientZone = new(new Vector2(850, 220), new Vector2(200, 280));

	private readonly SaveFlowSlotWorkflow _slotWorkflow = new()
	{
		SlotIdTemplate = "csharp_workflow_slot_{index}",
		EmptyDisplayNameTemplate = "C# Slot {index}",
	};
	private bool _menuOpen;
	private string _lastStatus = "C# workflow ready. Walk into a zone and press Enter, or press Esc for details.";

	public override void _Ready()
	{
		_slotWorkflow.SelectSlotIndex(SlotIndex);
		_slotWorkflow.SetSlotIdOverride(SlotIndex, SlotId);
		ConnectButton("Screen/MainLayout/LeftColumn/ButtonRow/SaveButton", OnSaveButtonPressed);
		ConnectButton("Screen/MainLayout/LeftColumn/ButtonRow/LoadButton", OnLoadButtonPressed);
		ConnectButton("Screen/MainLayout/LeftColumn/ButtonRow/MutateButton", OnMutateButtonPressed);
		ConnectButton("Screen/MainLayout/LeftColumn/ButtonRow/ResetButton", OnResetButtonPressed);
		ConnectButton("Screen/MainLayout/LeftColumn/ButtonRow/CloseButton", () => SetMenuOpen(false));
		SetMenuOpen(false);
		RefreshView(_lastStatus);
	}

	public override void _Input(InputEvent @event)
	{
		if (@event.IsActionPressed("ui_cancel"))
		{
			SetMenuOpen(!_menuOpen);
			GetViewport().SetInputAsHandled();
			return;
		}

		if (!_menuOpen && @event.IsActionPressed("ui_accept"))
		{
			TriggerCurrentWorldInteraction();
			GetViewport().SetInputAsHandled();
		}
	}

	public override void _Process(double delta)
	{
		if (_menuOpen)
			return;

		var moveVector = ReadMoveVector();
		if (moveVector == Vector2.Zero)
			return;

		MovePlayer(moveVector * PlayerSpeed * (float)delta);
		RefreshView(_lastStatus);
	}

	public GodotDictionary save_demo()
	{
		var result = SaveDemo();
		return ResultToDictionary(result);
	}

	public GodotDictionary load_demo()
	{
		var result = LoadDemo();
		return ResultToDictionary(result);
	}

	public GodotDictionary mutate_demo()
	{
		RoomStateSource().MutateForDemo();
		ApplyStateVisuals();
		RefreshView("C# state mutated. SaveFlow has not saved it yet.");
		return StateSnapshot();
	}

	public GodotDictionary reset_demo()
	{
		RoomStateSource().ResetForDemo();
		ApplyStateToScene();
		RefreshView("C# state reset locally. Load restores the saved slot.");
		return StateSnapshot();
	}

	public GodotDictionary state_snapshot()
		=> StateSnapshot();

	public string slot_card_text()
		=> BuildSlotCard().ToLabelText();

	public void set_menu_open(bool open)
		=> SetMenuOpen(open);

	public bool is_menu_open()
		=> _menuOpen;

	public void move_player_for_demo(Vector2 delta)
	{
		MovePlayer(delta);
		RefreshView(_lastStatus);
	}

	public Vector2 player_position()
		=> Player().Position;

	private SaveFlowCallResult SaveDemo()
	{
		RoomStateSource().SetPlayerPosition(Player().Position);
		var result = SaveFlowClient.SaveScope(
			_slotWorkflow.ActiveSlotId(),
			GetNode<Node>("SaveGraph"),
			BuildMetadata());
		RefreshView(result.Ok ? "Saved C# typed state through SaveFlowClient.SaveScope." : $"Save failed: {result.ErrorKey}");
		return result;
	}

	private SaveFlowCallResult LoadDemo()
	{
		var result = SaveFlowClient.LoadScope(_slotWorkflow.ActiveSlotId(), GetNode<Node>("SaveGraph"), strict: true);
		if (result.Ok)
			ApplyStateToScene();
		RefreshView(result.Ok ? "Loaded C# typed state and refreshed derived UI." : $"Load failed: {result.ErrorKey}");
		return result;
	}

	private SaveFlowSlotMetadata BuildMetadata()
		=> _slotWorkflow.BuildActiveSlotMetadata(
			"C# Typed Room Save",
			"manual",
			"C# Chapter",
			"C# Workflow Room",
			120 + RoomStateSource().MutationCount * 10,
			"normal",
			slotRole: "csharp_workflow_demo");

	private SaveFlowSlotCard BuildSlotCard()
	{
		var summaryResult = SaveFlowClient.ReadSlotSummary(_slotWorkflow.ActiveSlotId());
		if (summaryResult.Ok && summaryResult.Data.VariantType == Variant.Type.Dictionary)
			return _slotWorkflow.BuildCardForIndex(SlotIndex, summaryResult.Data.AsGodotDictionary());
		return _slotWorkflow.BuildEmptyCard(SlotIndex);
	}

	private GodotDictionary StateSnapshot()
		=> RoomStateSource().Snapshot();

	private TemplateCSharpRoomStateSource RoomStateSource()
		=> GetNode<TemplateCSharpRoomStateSource>("SaveGraph/RoomStateSource");

	private void RefreshView(string status, bool rememberStatus = true)
	{
		if (rememberStatus)
			_lastStatus = status;
		var state = RoomStateSource();
		SetLabelText(
			"Screen/MainLayout/LeftColumn/StatePanel/StateMargin/StateLabel",
			$"C# typed state\ncoins={state.Coins}\ndoor_open={state.DoorOpen}\ncheckpoint_id={state.CheckpointId}\nmutation_count={state.MutationCount}\nplayer=({state.PlayerPosition.X:0}, {state.PlayerPosition.Y:0})\npost_apply={state.LastApplyLabel}");
		SetLabelText("Screen/MainLayout/RightColumn/SlotPanel/SlotMargin/SlotCardLabel", BuildSlotCard().ToLabelText());
		SetLabelText("Screen/MainLayout/RightColumn/StatusPanel/StatusMargin/StatusLabel", status);
		SetLabelText("Screen/TopBar/CoinsLabel", $"$ {state.Coins}");
		SetLabelText("Screen/BottomHintPanel/BottomHintLabel", BuildBottomHint());
		SetLabelText(
			"WorldRoot/Room/RoomStateLabel",
			state.DoorOpen ? "Door is open" : "Door is closed");
		ApplyStateVisuals();
	}

	private void OnSaveButtonPressed()
		=> SaveDemo();

	private void OnLoadButtonPressed()
		=> LoadDemo();

	private void OnMutateButtonPressed()
		=> mutate_demo();

	private void OnResetButtonPressed()
		=> reset_demo();

	private void SetMenuOpen(bool open)
	{
		_menuOpen = open;
		var menu = GetNodeOrNull<Control>("Screen/MainLayout");
		if (menu is not null)
			menu.Visible = open;
		var background = GetNodeOrNull<ColorRect>("Screen/Background");
		if (background is not null)
			background.Visible = open;
		RefreshView(open ? "Esc or Close returns to the playable scene." : _lastStatus, rememberStatus: false);
	}

	private Vector2 ReadMoveVector()
	{
		var move = Input.GetVector("ui_left", "ui_right", "ui_up", "ui_down");
		if (Input.IsKeyPressed(Key.A))
			move.X -= 1.0f;
		if (Input.IsKeyPressed(Key.D))
			move.X += 1.0f;
		if (Input.IsKeyPressed(Key.W))
			move.Y -= 1.0f;
		if (Input.IsKeyPressed(Key.S))
			move.Y += 1.0f;
		return move.LengthSquared() > 1.0f ? move.Normalized() : move;
	}

	private void MovePlayer(Vector2 delta)
	{
		var player = Player();
		var next = player.Position + delta;
		player.Position = new Vector2(
			Mathf.Clamp(next.X, RoomBounds.Position.X, RoomBounds.End.X),
			Mathf.Clamp(next.Y, RoomBounds.Position.Y, RoomBounds.End.Y));
		RoomStateSource().SetPlayerPosition(player.Position);
	}

	private Node2D Player()
		=> GetNode<Node2D>("WorldRoot/Room/PlayerMarker");

	private void ApplyStateToScene()
	{
		Player().Position = RoomStateSource().PlayerPosition;
		ApplyStateVisuals();
	}

	private void ApplyStateVisuals()
	{
		var state = RoomStateSource();
		var door = GetNodeOrNull<Polygon2D>("WorldRoot/Room/DoorMarker");
		if (door is not null)
		{
			door.RotationDegrees = state.DoorOpen ? -72.0f : 0.0f;
			door.Color = state.DoorOpen ? new Color(0.35f, 0.95f, 0.55f) : new Color(0.95f, 0.38f, 0.32f);
		}

		var coin = GetNodeOrNull<Polygon2D>("WorldRoot/Room/CoinMarker");
		if (coin is not null)
		{
			var scale = 0.9f + Mathf.Min(state.Coins, 64) / 64.0f;
			coin.Scale = new Vector2(scale, scale);
			coin.RotationDegrees = state.MutationCount * 18.0f;
		}
	}

	private string BuildBottomHint()
	{
		var interaction = CurrentInteractionLabel();
		return string.IsNullOrEmpty(interaction)
			? "WASD / arrows move | Enter interact in a colored zone | Esc details"
			: $"Enter: {interaction} | Esc details";
	}

	private string CurrentInteractionLabel()
	{
		var position = Player().Position;
		if (TypedStateZone.HasPoint(position))
			return "mutate typed C# state";
		if (SlotWorkflowZone.HasPoint(position))
			return "save active C# slot";
		if (SaveClientZone.HasPoint(position))
			return "load active C# slot";
		return "";
	}

	private void TriggerCurrentWorldInteraction()
	{
		var position = Player().Position;
		if (TypedStateZone.HasPoint(position))
		{
			mutate_demo();
			return;
		}
		if (SlotWorkflowZone.HasPoint(position))
		{
			SaveDemo();
			return;
		}
		if (SaveClientZone.HasPoint(position))
		{
			LoadDemo();
			return;
		}
		RefreshView("Move into a colored zone before pressing Enter.");
	}

	private void ConnectButton(string path, Action action)
	{
		var button = GetNodeOrNull<Button>(path);
		if (button is not null)
			button.Pressed += action;
	}

	private void SetLabelText(string path, string text)
	{
		var label = GetNodeOrNull<Label>(path);
		if (label is not null)
			label.Text = text;
	}

	private static GodotDictionary ResultToDictionary(SaveFlowCallResult result)
		=> new()
		{
			["ok"] = result.Ok,
			["error_key"] = result.ErrorKey,
			["error_message"] = result.ErrorMessage,
		};
}
