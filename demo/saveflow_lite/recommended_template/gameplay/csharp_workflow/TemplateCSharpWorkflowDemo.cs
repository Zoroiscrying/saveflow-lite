using System;

using Godot;

using GodotDictionary = Godot.Collections.Dictionary;

using SaveFlow.DotNet;

public partial class TemplateCSharpWorkflowDemo : Control
{
	private const int SlotIndex = 30;
	private const string SlotId = "csharp_workflow_demo";

	private readonly SaveFlowSlotWorkflow _slotWorkflow = new()
	{
		SlotIdTemplate = "csharp_workflow_slot_{index}",
		EmptyDisplayNameTemplate = "C# Slot {index}",
	};

	public override void _Ready()
	{
		_slotWorkflow.SelectSlotIndex(SlotIndex);
		_slotWorkflow.SetSlotIdOverride(SlotIndex, SlotId);
		ConnectButton("Screen/MainLayout/LeftColumn/ButtonRow/SaveButton", OnSaveButtonPressed);
		ConnectButton("Screen/MainLayout/LeftColumn/ButtonRow/LoadButton", OnLoadButtonPressed);
		ConnectButton("Screen/MainLayout/LeftColumn/ButtonRow/MutateButton", OnMutateButtonPressed);
		ConnectButton("Screen/MainLayout/LeftColumn/ButtonRow/ResetButton", OnResetButtonPressed);
		RefreshView("C# workflow ready. Mutate, Save, Reset, then Load.");
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
		RoomStateProvider().MutateForDemo();
		RefreshView("C# state mutated. SaveFlow has not saved it yet.");
		return StateSnapshot();
	}

	public GodotDictionary reset_demo()
	{
		RoomStateProvider().ResetForDemo();
		RefreshView("C# state reset locally. Load restores the saved slot.");
		return StateSnapshot();
	}

	public GodotDictionary state_snapshot()
		=> StateSnapshot();

	public string slot_card_text()
		=> BuildSlotCard().ToLabelText();

	private SaveFlowCallResult SaveDemo()
	{
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
		RefreshView(result.Ok ? "Loaded C# typed state and refreshed derived UI." : $"Load failed: {result.ErrorKey}");
		return result;
	}

	private SaveFlowSlotMetadata BuildMetadata()
		=> _slotWorkflow.BuildActiveSlotMetadata(
			"C# Typed Room Save",
			"manual",
			"C# Chapter",
			"C# Workflow Room",
			120 + RoomStateProvider().MutationCount * 10,
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
		=> RoomStateProvider().Snapshot();

	private TemplateCSharpRoomStateProvider RoomStateProvider()
		=> GetNode<TemplateCSharpRoomStateProvider>("RoomStateProvider");

	private void RefreshView(string status)
	{
		var state = RoomStateProvider();
		SetLabelText(
			"Screen/MainLayout/LeftColumn/StatePanel/StateMargin/StateLabel",
			$"C# typed state\ncoins={state.Coins}\ndoor_open={state.DoorOpen}\ncheckpoint_id={state.CheckpointId}\nmutation_count={state.MutationCount}\npost_apply={state.LastApplyLabel}");
		SetLabelText("Screen/MainLayout/RightColumn/SlotPanel/SlotMargin/SlotCardLabel", BuildSlotCard().ToLabelText());
		SetLabelText("Screen/MainLayout/RightColumn/StatusPanel/StatusMargin/StatusLabel", status);
		SetLabelText("Screen/TopBar/CoinsLabel", $"$ {state.Coins}");
		SetLabelText(
			"WorldRoot/Room/RoomStateLabel",
			state.DoorOpen ? "Door is open" : "Door is closed");
	}

	private void OnSaveButtonPressed()
		=> SaveDemo();

	private void OnLoadButtonPressed()
		=> LoadDemo();

	private void OnMutateButtonPressed()
		=> mutate_demo();

	private void OnResetButtonPressed()
		=> reset_demo();

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
