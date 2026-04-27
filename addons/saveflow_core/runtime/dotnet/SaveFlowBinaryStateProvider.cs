using Godot;

using GodotArray = Godot.Collections.Array;
using GodotDictionary = Godot.Collections.Dictionary;

namespace SaveFlow.DotNet;

/// <summary>
/// Node-backed binary provider for the common "one state object" workflow.
/// Use this with BinaryWriter, MessagePack, protobuf, or any project-owned
/// serializer that can convert a state object to and from byte[].
/// </summary>
public abstract partial class SaveFlowBinaryStateProvider : Node, ISaveFlowEncodedPayloadProvider
{
	protected virtual string SaveFlowPayloadSchema => GetType().FullName ?? GetType().Name;
	protected virtual int SaveFlowPayloadDataVersion => 1;
	protected virtual string SaveFlowBinaryEncoding => SaveFlowEncodedPayload.EncodingBinary;
	protected virtual string SaveFlowBinaryContentType => SaveFlowEncodedPayload.ContentTypeBinary;
	protected virtual GodotArray? SaveFlowPayloadSections => null;
	protected virtual object? SaveFlowState { get; set; }

	protected virtual object? CaptureSaveState()
		=> SaveFlowState;

	protected abstract byte[] SerializeSaveState(object? state);

	protected abstract object? DeserializeSaveState(byte[] bytes);

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
		=> SaveFlowEncodedPayload.FromBytes(
			SerializeSaveState(CaptureSaveState()),
			SaveFlowBinaryEncoding,
			SaveFlowBinaryContentType,
			SaveFlowPayloadSchema,
			SaveFlowPayloadDataVersion);

	public void ApplySaveFlowEncodedPayload(GodotDictionary payload)
	{
		var bytes = SaveFlowEncodedPayload.GetBytes(payload);
		if (bytes.Length == 0)
			return;
		ApplySaveState(DeserializeSaveState(bytes));
	}

	public virtual GodotDictionary GetSaveFlowPayloadInfo()
		=> SaveFlowEncodedPayload.BinaryInfo(
			SaveFlowPayloadSchema,
			SaveFlowPayloadDataVersion,
			SaveFlowPayloadSections,
			SaveFlowBinaryEncoding,
			contentType: SaveFlowBinaryContentType);

	public GodotDictionary to_saveflow_encoded_payload()
		=> ToSaveFlowEncodedPayload();

	public void apply_saveflow_encoded_payload(GodotDictionary payload)
		=> ApplySaveFlowEncodedPayload(payload);

	public GodotDictionary get_saveflow_payload_info()
		=> GetSaveFlowPayloadInfo();
}
