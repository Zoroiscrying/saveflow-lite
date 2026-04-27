using Godot;

using GodotArray = Godot.Collections.Array;
using GodotDictionary = Godot.Collections.Dictionary;

namespace SaveFlow.DotNet;

/// <summary>
/// Resource-backed reflection convenience path for small C# save data.
/// Prefer SaveFlowJsonResource or an explicit ISaveFlowEncodedPayloadProvider for
/// large or frequently saved state.
/// </summary>
public abstract partial class SaveFlowTypedResource : Resource, ISaveFlowPayloadProvider
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
