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

		var payload = new Dictionary
		{
			["coins"] = 42,
			["room"] = "forest_gate"
		};

		var saveResult = SaveFlowClient.SaveData("slot_a", payload);
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
- `SaveFlowClient.SaveNodes(...)`
- `SaveFlowClient.LoadNodes(...)`
- `SaveFlowClient.SaveScope(...)`
- `SaveFlowClient.LoadScope(...)`
- `SaveFlowClient.SaveCurrent(...)`
- `SaveFlowClient.LoadCurrent(...)`
- `SaveFlowClient.SaveDevNamedEntry(...)`
- `SaveFlowClient.LoadDevNamedEntry(...)`

## Notes

- The wrapper is intentionally thin: it forwards to the `SaveFlow` autoload.
- Return values are normalized to `SaveFlowCallResult`.
- This baseline is the starting point for future typed C# APIs.
