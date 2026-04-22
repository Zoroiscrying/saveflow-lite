using Godot;
using Godot.Collections;
using SaveFlow.DotNet;

public partial class TemplateCSharpCase : Node
{
	private const string SlotId = "recommended_csharp_case";

	private int _coins;
	private string _room = "spawn";

	public override void _Ready()
	{
		ConfigureRuntime();
		ResetCase();
	}

	public Dictionary GetStateSnapshot()
	{
		return new Dictionary
		{
			["coins"] = _coins,
			["room"] = _room,
		};
	}

	public Dictionary SaveCase()
	{
		var payload = BuildPayload();
		var meta = SaveFlowClient.BuildSlotMetadata(
			"CSharp Case",
			"manual",
			"Recommended Cases",
			_room,
			_coins * 10,
			"",
			"",
			new Dictionary { ["scene_path"] = SceneFilePath });
		var result = SaveFlowClient.SaveData(SlotId, payload, meta);
		return BuildResponse(result);
	}

	public Dictionary LoadCase()
	{
		var result = SaveFlowClient.LoadData(SlotId);
		if (result.Ok && result.Data.VariantType == Variant.Type.Dictionary)
			ApplyPayload(result.Data.AsGodotDictionary());
		return BuildResponse(result);
	}

	public void MutateCase()
	{
		_coins += 5;
		_room = _room == "forest_gate" ? "cave_entrance" : "forest_gate";
	}

	public void ResetCase()
	{
		_coins = 10;
		_room = "spawn";
	}

	private void ConfigureRuntime()
	{
		SaveFlowClient.Configure(
			"user://recommended_cases/csharp/saves",
			"user://recommended_cases/csharp/slots.index");
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
	}

	private Dictionary BuildResponse(SaveFlowCallResult result)
	{
		return new Dictionary
		{
			["ok"] = result.Ok,
			["error_key"] = result.ErrorKey,
			["error_message"] = result.ErrorMessage,
			["summary"] = result.Ok ? FormatSummary(SaveFlowClient.ReadSlotSummary(SlotId)) : "",
		};
	}

	private static string FormatSummary(SaveFlowCallResult result)
	{
		if (!result.Ok || result.Data.VariantType != Variant.Type.Dictionary)
			return $"Summary unavailable: {result.ErrorMessage} ({result.ErrorKey})";

		var summary = result.Data.AsGodotDictionary();
		return
			$"Summary: name={summary["display_name"]}, type={summary["save_type"]}, chapter={summary["chapter_name"]}, location={summary["location_name"]}";
	}
}
