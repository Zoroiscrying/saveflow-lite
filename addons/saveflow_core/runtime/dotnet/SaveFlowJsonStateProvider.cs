using System.Text.Json;
using System.Text.Json.Serialization.Metadata;

using Godot;

using GodotArray = Godot.Collections.Array;
using GodotDictionary = Godot.Collections.Dictionary;

namespace SaveFlow.DotNet;

/// <summary>
/// Node-backed source-generated JSON provider for the common "one state object"
/// workflow. Keep this Godot script class in a same-name file so Godot's C#
/// reload map has one stable owner.
///
/// Do not turn this GodotObject-derived script base into
/// SaveFlowJsonStateProvider&lt;TState&gt;. Generics are safe inside DTOs,
/// JsonTypeInfo, and helper methods, but generic Node/Resource script bases can
/// collide with Godot's C# script registration during editor reload.
/// </summary>
public abstract partial class SaveFlowJsonStateProvider : Node, ISaveFlowEncodedPayloadProvider
{
	protected virtual int SaveFlowPayloadDataVersion => 1;
	protected virtual GodotArray? SaveFlowPayloadSections => null;
	protected abstract JsonTypeInfo SaveFlowJsonTypeInfo { get; }
	protected virtual string SaveFlowPayloadSchema => SaveFlowJsonTypeInfo.Type.FullName ?? SaveFlowJsonTypeInfo.Type.Name;
	protected virtual object? SaveFlowState { get; set; }

	protected virtual object? CaptureSaveState()
		=> SaveFlowState;

	protected virtual void ApplySaveState(object? state)
	{
		SaveFlowState = state;
		OnSaveFlowStateApplied(state);
	}

	protected virtual void OnSaveFlowStateApplied(object? state)
	{
	}

	protected TState GetSaveFlowState<TState>()
		=> SaveFlowState is TState state ? state : default!;

	protected void SetSaveFlowState<TState>(TState state)
		=> SaveFlowState = state;

	public GodotDictionary ToSaveFlowEncodedPayload()
		=> SaveFlowEncodedPayload.FromText(
			JsonSerializer.Serialize(CaptureSaveState(), SaveFlowJsonTypeInfo),
			SaveFlowEncodedPayload.EncodingJson,
			SaveFlowEncodedPayload.ContentTypeJson,
			SaveFlowPayloadSchema,
			SaveFlowPayloadDataVersion);

	public void ApplySaveFlowEncodedPayload(GodotDictionary payload)
	{
		var text = SaveFlowEncodedPayload.GetText(payload);
		if (string.IsNullOrEmpty(text))
			return;
		ApplySaveState(JsonSerializer.Deserialize(text, SaveFlowJsonTypeInfo));
	}

	public virtual GodotDictionary GetSaveFlowPayloadInfo()
		=> SaveFlowEncodedPayload.JsonInfo(
			SaveFlowPayloadSchema,
			SaveFlowPayloadDataVersion,
			SaveFlowPayloadSections);

	public GodotDictionary to_saveflow_encoded_payload()
		=> ToSaveFlowEncodedPayload();

	public void apply_saveflow_encoded_payload(GodotDictionary payload)
		=> ApplySaveFlowEncodedPayload(payload);

	public GodotDictionary get_saveflow_payload_info()
		=> GetSaveFlowPayloadInfo();
}
