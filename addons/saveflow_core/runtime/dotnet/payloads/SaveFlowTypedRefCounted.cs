using Godot;

using GodotArray = Godot.Collections.Array;
using GodotDictionary = Godot.Collections.Dictionary;

namespace SaveFlow.DotNet;

/// <summary>
/// Runtime-only reflection convenience path for small C# models.
/// Prefer explicit encoded payload providers for large or frequently saved state.
///
/// Keep GodotObject-derived SaveFlow bases non-generic and in same-name files.
/// Use typed fields/properties or helper methods for generic C# data instead.
/// </summary>
[GlobalClass, Icon("res://addons/saveflow_lite/icons/components/saveflow_typed_data_icon.svg")]
public abstract partial class SaveFlowTypedRefCounted : RefCounted, ISaveFlowPayloadProvider
{
	public GodotDictionary ToSaveFlowPayload()
		=> SaveFlowTypedDataReflection.ToPayload(this);

	public void ApplySaveFlowPayload(GodotDictionary payload)
		=> SaveFlowTypedDataReflection.ApplyPayload(this, payload);

	public GodotArray GetSaveFlowPropertyNames()
		=> SaveFlowTypedDataReflection.GetPropertyNames(this);

	public GodotDictionary to_saveflow_payload()
		=> ToSaveFlowPayload();

	public void apply_saveflow_payload(GodotDictionary payload)
		=> ApplySaveFlowPayload(payload);

	public GodotArray get_saveflow_property_names()
		=> GetSaveFlowPropertyNames();
}
