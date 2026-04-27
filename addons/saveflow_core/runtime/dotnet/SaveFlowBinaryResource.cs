using Godot;

using GodotArray = Godot.Collections.Array;
using GodotDictionary = Godot.Collections.Dictionary;

namespace SaveFlow.DotNet;

/// <summary>
/// Resource base for project-owned binary payloads. SaveFlow only stores the
/// returned bytes; the project chooses the binary serializer and schema.
/// </summary>
public abstract partial class SaveFlowBinaryResource : Resource, ISaveFlowEncodedPayloadProvider
{
	protected virtual string SaveFlowPayloadSchema => GetType().FullName ?? GetType().Name;
	protected virtual int SaveFlowPayloadDataVersion => 1;
	protected virtual string SaveFlowBinaryEncoding => SaveFlowEncodedPayload.EncodingBinary;
	protected virtual string SaveFlowBinaryContentType => SaveFlowEncodedPayload.ContentTypeBinary;
	protected virtual GodotArray? SaveFlowPayloadSections => null;

	protected abstract object? CaptureSaveData();

	protected abstract byte[] SerializeSaveData(object? data);

	protected abstract object? DeserializeSaveData(byte[] bytes);

	protected abstract void ApplySaveData(object? data);

	public GodotDictionary ToSaveFlowEncodedPayload()
		=> SaveFlowEncodedPayload.FromBytes(
			SerializeSaveData(CaptureSaveData()),
			SaveFlowBinaryEncoding,
			SaveFlowBinaryContentType,
			SaveFlowPayloadSchema,
			SaveFlowPayloadDataVersion);

	public void ApplySaveFlowEncodedPayload(GodotDictionary payload)
	{
		var bytes = SaveFlowEncodedPayload.GetBytes(payload);
		if (bytes.Length == 0)
			return;
		ApplySaveData(DeserializeSaveData(bytes));
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
