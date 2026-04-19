using Godot;
using Godot.Collections;
using SaveFlow.DotNet;

public partial class TemplateCSharpCase : Control
{
	private const string SlotId = "recommended_csharp_case";

	private Label _stateLabel = null!;
	private TextEdit _statusOutput = null!;

	private int _coins;
	private string _room = "spawn";

	public override void _Ready()
	{
		_stateLabel = GetNode<Label>("MarginContainer/PanelContainer/Content/StateLabel");
		_statusOutput = GetNode<TextEdit>("MarginContainer/PanelContainer/Content/StatusOutput");

		ConfigureRuntime();
		BindButtons();
		ResetState(false);
		SetStatus("C# case ready. This scene uses SaveFlow.DotNet.SaveFlowClient for SaveData/LoadData.");
	}

	private void ConfigureRuntime()
	{
		var runtime = SaveFlowClient.ResolveRuntime();
		if (runtime is null)
		{
			SetStatus("SaveFlow runtime is unavailable. Enable SaveFlow Lite plugin and run the scene again.");
			return;
		}

		runtime.Call("configure_with", new Dictionary
		{
			["save_root"] = "user://recommended_cases/csharp/saves",
			["slot_index_file"] = "user://recommended_cases/csharp/slots.index",
			["storage_format"] = 0,
			["pretty_json_in_editor"] = true,
			["use_safe_write"] = true,
		});
	}

	private void BindButtons()
	{
		GetNode<Button>("MarginContainer/PanelContainer/Content/Buttons/SaveButton").Pressed += OnSavePressed;
		GetNode<Button>("MarginContainer/PanelContainer/Content/Buttons/LoadButton").Pressed += OnLoadPressed;
		GetNode<Button>("MarginContainer/PanelContainer/Content/Buttons/MutateButton").Pressed += OnMutatePressed;
		GetNode<Button>("MarginContainer/PanelContainer/Content/Buttons/ResetButton").Pressed += OnResetPressed;
	}

	private void OnSavePressed()
	{
		var payload = BuildPayload();
		var meta = new Dictionary
		{
			["display_name"] = "CSharp Case",
			["scene_path"] = SceneFilePath,
		};
		var result = SaveFlowClient.SaveData(SlotId, payload, meta);
		SetStatus(FormatResult("Save", result));
	}

	private void OnLoadPressed()
	{
		var result = SaveFlowClient.LoadData(SlotId);
		if (result.Ok && result.Data.VariantType == Variant.Type.Dictionary)
			ApplyPayload(result.Data.AsGodotDictionary());
		SetStatus(FormatResult("Load", result));
	}

	private void OnMutatePressed()
	{
		_coins += 5;
		_room = _room == "forest_gate" ? "cave_entrance" : "forest_gate";
		SetStatus("Mutated C# local state. SaveData stores this dictionary payload.");
	}

	private void OnResetPressed()
	{
		ResetState(true);
	}

	private void ResetState(bool announce)
	{
		_coins = 10;
		_room = "spawn";
		RefreshStateLabel();
		if (announce)
			SetStatus("Reset C# local state.");
	}

	private Dictionary BuildPayload()
	{
		return new Dictionary
		{
			["coins"] = _coins,
			["room"] = _room,
		};
	}

	private void ApplyPayload(Dictionary payload)
	{
		if (payload.ContainsKey("coins"))
			_coins = payload["coins"].AsInt32();
		if (payload.ContainsKey("room"))
			_room = payload["room"].AsString();
		RefreshStateLabel();
	}

	private string FormatResult(string label, SaveFlowCallResult result)
	{
		if (result.Ok)
			return $"{label} OK";
		return $"{label} failed: {result.ErrorMessage} ({result.ErrorKey})";
	}

	private void SetStatus(string message)
	{
		_statusOutput.Text = message;
		RefreshStateLabel();
	}

	private void RefreshStateLabel()
	{
		_stateLabel.Text = $"C# State: coins={_coins}, room={_room}";
	}
}
