# SaveFlow C# Quickstart

This document shows the minimal C# path for calling SaveFlow runtime APIs.

## Wrapper Location

The baseline C# wrapper is shipped in `saveflow_core`:

- `res://addons/saveflow_core/runtime/dotnet/SaveFlowClient.cs`
- `res://addons/saveflow_core/runtime/dotnet/SaveFlowCallResult.cs`

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

## Notes

- The wrapper is intentionally thin: it forwards to the `SaveFlow` autoload.
- Return values are normalized to `SaveFlowCallResult`.
- Prefer the explicit metadata overloads for common save rows; keep `BuildSlotMetadata(...)` for advanced or reusable metadata assembly.
- Compatibility inspection is available in C# too, so schema/data-version checks do not become a GDScript-only workflow.
- Slot-summary reads are available in C# too, so save-list UI does not need to load the full gameplay payload first.
- This baseline is the starting point for future typed C# APIs.
