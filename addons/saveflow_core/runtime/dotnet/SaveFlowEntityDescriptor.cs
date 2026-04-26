using Godot;

using GodotDictionary = Godot.Collections.Dictionary;

namespace SaveFlow.DotNet;

/// <summary>
/// Typed helper for one runtime-entity save descriptor.
/// SaveFlow stores descriptors as dictionaries on disk, but C# factory code can
/// read and write them through this class instead of hand-managed string keys.
/// </summary>
public sealed class SaveFlowEntityDescriptor
{
	public const string PersistentIdKey = "persistent_id";
	public const string TypeKeyKey = "type_key";
	public const string PayloadKey = "payload";

	public string PersistentId { get; set; } = "";
	public string TypeKey { get; set; } = "";
	public Variant Payload { get; set; } = new GodotDictionary();
	public GodotDictionary Extra { get; } = new();

	public bool IsValid => !string.IsNullOrWhiteSpace(TypeKey);

	public static SaveFlowEntityDescriptor FromValues(
		string persistentId,
		string typeKey,
		Variant payload = default,
		GodotDictionary? extra = null)
	{
		var descriptor = new SaveFlowEntityDescriptor
		{
			PersistentId = persistentId.Trim(),
			TypeKey = typeKey.Trim(),
			Payload = payload.VariantType == Variant.Type.Nil ? new GodotDictionary() : payload,
		};
		if (extra is not null)
		{
			foreach (Variant key in extra.Keys)
				descriptor.Extra[key] = extra[key];
		}
		return descriptor;
	}

	public static SaveFlowEntityDescriptor FromDictionary(GodotDictionary data)
	{
		var descriptor = new SaveFlowEntityDescriptor();
		descriptor.ApplyDictionary(data);
		return descriptor;
	}

	public void ApplyDictionary(GodotDictionary data)
	{
		if (data.TryGetValue(PersistentIdKey, out var persistentId))
			PersistentId = persistentId.AsString().Trim();
		if (data.TryGetValue(TypeKeyKey, out var typeKey))
			TypeKey = typeKey.AsString().Trim();
		if (data.TryGetValue(PayloadKey, out var payload))
			Payload = payload;

		Extra.Clear();
		foreach (Variant key in data.Keys)
		{
			var keyText = key.AsString();
			if (keyText is PersistentIdKey or TypeKeyKey or PayloadKey)
				continue;
			Extra[key] = data[key];
		}
	}

	public GodotDictionary ToDictionary()
	{
		var data = new GodotDictionary();
		foreach (Variant key in Extra.Keys)
			data[key] = Extra[key];
		data[PersistentIdKey] = PersistentId;
		data[TypeKeyKey] = TypeKey;
		data[PayloadKey] = Payload;
		return data;
	}

	public GodotDictionary GetPayloadDictionary()
		=> Payload.VariantType == Variant.Type.Dictionary ? Payload.AsGodotDictionary() : new GodotDictionary();

	public string GetValidationMessage()
		=> IsValid ? "" : "entity descriptor must contain type_key";

	public Variant GetExtraValue(Variant key, Variant defaultValue = default)
		=> Extra.TryGetValue(key, out var value) ? value : defaultValue;

	public void SetExtraValue(Variant key, Variant value)
		=> Extra[key] = value;
}
