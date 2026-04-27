using System;

using Godot;

using GodotArray = Godot.Collections.Array;
using GodotDictionary = Godot.Collections.Dictionary;

namespace SaveFlow.DotNet;

/// <summary>
/// Overrides the SaveFlow payload key for one exported C# field or property.
/// </summary>
[AttributeUsage(AttributeTargets.Field | AttributeTargets.Property)]
public sealed class SaveFlowKeyAttribute : Attribute
{
	public string Key { get; }

	public SaveFlowKeyAttribute(string key)
		=> Key = key;
}

/// <summary>
/// Excludes one exported C# field or property from typed SaveFlow payloads.
/// </summary>
[AttributeUsage(AttributeTargets.Field | AttributeTargets.Property)]
public sealed class SaveFlowIgnoreAttribute : Attribute
{
}

/// <summary>
/// Optional compile-time contract for objects consumed by SaveFlowTypedDataSource.
/// GDScript integration is duck-typed: the object only needs these public methods.
/// </summary>
public interface ISaveFlowPayloadProvider
{
	GodotDictionary ToSaveFlowPayload();

	void ApplySaveFlowPayload(GodotDictionary payload);

	GodotArray GetSaveFlowPropertyNames();
}

/// <summary>
/// Non-reflection payload contract for C# objects that encode their own save data.
/// SaveFlow stores the returned dictionary as an opaque typed payload and sends it
/// back during load.
/// </summary>
public interface ISaveFlowEncodedPayloadProvider
{
	GodotDictionary ToSaveFlowEncodedPayload();

	void ApplySaveFlowEncodedPayload(GodotDictionary payload);

	GodotDictionary GetSaveFlowPayloadInfo();
}
