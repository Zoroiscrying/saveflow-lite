using System;
using System.Collections.Concurrent;
using System.Reflection;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization.Metadata;

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

/// <summary>
/// Helpers for encoded C# payloads. These helpers do not inspect fields or
/// properties; callers provide the data object and serializer metadata.
/// </summary>
public static class SaveFlowEncodedPayload
{
	public const string PayloadFormatKey = "saveflow_payload_format";
	public const string PayloadFormatEncoded = "encoded";
	public const string EncodingKey = "encoding";
	public const string ContentTypeKey = "content_type";
	public const string SchemaKey = "schema";
	public const string DataVersionKey = "data_version";
	public const string TextKey = "text";
	public const string BytesKey = "bytes";
	public const string SectionsKey = "sections";
	public const string EncodingJson = "json";
	public const string EncodingBinary = "binary";
	public const string ContentTypeJson = "application/json";
	public const string ContentTypeBinary = "application/octet-stream";

	public static GodotDictionary FromText(
		string text,
		string encoding = EncodingJson,
		string contentType = ContentTypeJson,
		string schema = "",
		int dataVersion = 1)
		=> new()
		{
			[PayloadFormatKey] = PayloadFormatEncoded,
			[EncodingKey] = encoding,
			[ContentTypeKey] = contentType,
			[SchemaKey] = schema,
			[DataVersionKey] = dataVersion,
			[TextKey] = text,
		};

	public static GodotDictionary FromBytes(
		byte[] bytes,
		string encoding = EncodingBinary,
		string contentType = ContentTypeBinary,
		string schema = "",
		int dataVersion = 1)
		=> new()
		{
			[PayloadFormatKey] = PayloadFormatEncoded,
			[EncodingKey] = encoding,
			[ContentTypeKey] = contentType,
			[SchemaKey] = schema,
			[DataVersionKey] = dataVersion,
			[BytesKey] = bytes,
		};

	public static GodotDictionary CreateJsonPayload<TData>(
		TData data,
		JsonTypeInfo<TData> typeInfo,
		string schema = "",
		int dataVersion = 1)
	{
		var text = JsonSerializer.Serialize(data, typeInfo);
		return FromText(text, EncodingJson, ContentTypeJson, schema, dataVersion);
	}

	public static GodotDictionary CreateBinaryPayload<TData>(
		TData data,
		Func<TData, byte[]> serialize,
		string schema = "",
		int dataVersion = 1,
		string encoding = EncodingBinary,
		string contentType = ContentTypeBinary)
		=> FromBytes(serialize(data), encoding, contentType, schema, dataVersion);

	public static TData? ReadJsonPayload<TData>(GodotDictionary payload, JsonTypeInfo<TData> typeInfo)
	{
		var text = GetText(payload);
		return string.IsNullOrEmpty(text)
			? default
			: JsonSerializer.Deserialize(text, typeInfo);
	}

	public static void ApplyJsonPayload<TData>(
		GodotDictionary payload,
		JsonTypeInfo<TData> typeInfo,
		Action<TData> apply)
	{
		var data = ReadJsonPayload(payload, typeInfo);
		if (data is null)
			return;
		apply(data);
	}

	public static TData? ReadBinaryPayload<TData>(
		GodotDictionary payload,
		Func<byte[], TData> deserialize)
	{
		var bytes = GetBytes(payload);
		return bytes.Length == 0 ? default : deserialize(bytes);
	}

	public static void ApplyBinaryPayload<TData>(
		GodotDictionary payload,
		Func<byte[], TData> deserialize,
		Action<TData> apply)
	{
		var data = ReadBinaryPayload(payload, deserialize);
		if (data is null)
			return;
		apply(data);
	}

	public static string GetText(GodotDictionary payload)
	{
		if (!payload.ContainsKey(TextKey))
			return "";
		var value = payload[TextKey];
		return value.VariantType == Variant.Type.Nil ? "" : value.AsString();
	}

	public static byte[] GetBytes(GodotDictionary payload)
	{
		if (payload.ContainsKey(BytesKey))
		{
			var value = payload[BytesKey];
			if (value.VariantType == Variant.Type.PackedByteArray)
				return value.AsByteArray();
			if (value.VariantType == Variant.Type.Array)
			{
				var array = value.AsGodotArray();
				var bytes = new byte[array.Count];
				for (var i = 0; i < array.Count; i++)
					bytes[i] = Convert.ToByte(array[i].AsInt64());
				return bytes;
			}
		}
		var text = GetText(payload);
		return string.IsNullOrEmpty(text) ? Array.Empty<byte>() : Encoding.UTF8.GetBytes(text);
	}

	public static GodotDictionary JsonInfo(
		string schema,
		int dataVersion = 1,
		GodotArray? sections = null)
	{
		var info = new GodotDictionary
		{
			[PayloadFormatKey] = PayloadFormatEncoded,
			[EncodingKey] = EncodingJson,
			[ContentTypeKey] = ContentTypeJson,
			[SchemaKey] = schema,
			[DataVersionKey] = dataVersion,
		};
		if (sections is not null)
			info[SectionsKey] = sections;
		return info;
	}

	public static GodotDictionary BinaryInfo(
		string schema,
		int dataVersion = 1,
		GodotArray? sections = null,
		string encoding = EncodingBinary,
		string contentType = ContentTypeBinary)
	{
		var info = new GodotDictionary
		{
			[PayloadFormatKey] = PayloadFormatEncoded,
			[EncodingKey] = encoding,
			[ContentTypeKey] = contentType,
			[SchemaKey] = schema,
			[DataVersionKey] = dataVersion,
		};
		if (sections is not null)
			info[SectionsKey] = sections;
		return info;
	}
}

/// <summary>
/// Reflection helper for existing C# nodes/managers that cannot inherit a SaveFlow typed base class.
/// </summary>
public static class SaveFlowTypedPayload
{
	public static GodotDictionary ToPayload(object source)
		=> SaveFlowTypedDataReflection.ToPayload(source);

	public static void ApplyPayload(object target, GodotDictionary payload)
		=> SaveFlowTypedDataReflection.ApplyPayload(target, payload);

	public static GodotArray GetPropertyNames(object source)
		=> SaveFlowTypedDataReflection.GetPropertyNames(source);
}

/// <summary>
/// Resource base for source-generated JSON payloads.
/// Use this when the save data can be captured as a DTO and serialized with a
/// JsonSerializerContext-generated JsonTypeInfo.
/// </summary>
public abstract partial class SaveFlowJsonResource<TData> : Resource, ISaveFlowEncodedPayloadProvider
{
	protected virtual string SaveFlowPayloadSchema => typeof(TData).FullName ?? typeof(TData).Name;
	protected virtual int SaveFlowPayloadDataVersion => 1;
	protected abstract JsonTypeInfo<TData> SaveFlowJsonTypeInfo { get; }

	protected abstract TData CaptureSaveData();

	protected abstract void ApplySaveData(TData data);

	public GodotDictionary ToSaveFlowEncodedPayload()
		=> SaveFlowEncodedPayload.CreateJsonPayload(
			CaptureSaveData(),
			SaveFlowJsonTypeInfo,
			SaveFlowPayloadSchema,
			SaveFlowPayloadDataVersion);

	public void ApplySaveFlowEncodedPayload(GodotDictionary payload)
		=> SaveFlowEncodedPayload.ApplyJsonPayload(payload, SaveFlowJsonTypeInfo, ApplySaveData);

	public virtual GodotDictionary GetSaveFlowPayloadInfo()
		=> SaveFlowEncodedPayload.JsonInfo(SaveFlowPayloadSchema, SaveFlowPayloadDataVersion);

	public GodotDictionary to_saveflow_encoded_payload()
		=> ToSaveFlowEncodedPayload();

	public void apply_saveflow_encoded_payload(GodotDictionary payload)
		=> ApplySaveFlowEncodedPayload(payload);

	public GodotDictionary get_saveflow_payload_info()
		=> GetSaveFlowPayloadInfo();
}

/// <summary>
/// Node-backed source-generated JSON provider for the common "one state object"
/// workflow. Loading replaces State by default, then calls OnSaveFlowStateApplied
/// so gameplay code can refresh derived runtime state.
/// </summary>
public abstract partial class SaveFlowJsonStateProvider<TState> : Node, ISaveFlowEncodedPayloadProvider
{
	protected virtual string SaveFlowPayloadSchema => typeof(TState).FullName ?? typeof(TState).Name;
	protected virtual int SaveFlowPayloadDataVersion => 1;
	protected abstract JsonTypeInfo<TState> SaveFlowJsonTypeInfo { get; }
	protected abstract TState State { get; set; }

	protected virtual TState CaptureSaveState()
		=> State;

	protected virtual void ApplySaveState(TState state)
	{
		State = state;
		OnSaveFlowStateApplied(state);
	}

	protected virtual void OnSaveFlowStateApplied(TState state)
	{
	}

	public GodotDictionary ToSaveFlowEncodedPayload()
		=> SaveFlowEncodedPayload.CreateJsonPayload(
			CaptureSaveState(),
			SaveFlowJsonTypeInfo,
			SaveFlowPayloadSchema,
			SaveFlowPayloadDataVersion);

	public void ApplySaveFlowEncodedPayload(GodotDictionary payload)
		=> SaveFlowEncodedPayload.ApplyJsonPayload(payload, SaveFlowJsonTypeInfo, ApplySaveState);

	public virtual GodotDictionary GetSaveFlowPayloadInfo()
		=> SaveFlowEncodedPayload.JsonInfo(SaveFlowPayloadSchema, SaveFlowPayloadDataVersion);

	public GodotDictionary to_saveflow_encoded_payload()
		=> ToSaveFlowEncodedPayload();

	public void apply_saveflow_encoded_payload(GodotDictionary payload)
		=> ApplySaveFlowEncodedPayload(payload);

	public GodotDictionary get_saveflow_payload_info()
		=> GetSaveFlowPayloadInfo();
}

/// <summary>
/// Resource base for project-owned binary payloads. SaveFlow only stores the
/// returned bytes; the project chooses the binary serializer and schema.
/// </summary>
public abstract partial class SaveFlowBinaryResource<TData> : Resource, ISaveFlowEncodedPayloadProvider
{
	protected virtual string SaveFlowPayloadSchema => typeof(TData).FullName ?? typeof(TData).Name;
	protected virtual int SaveFlowPayloadDataVersion => 1;
	protected virtual string SaveFlowBinaryEncoding => SaveFlowEncodedPayload.EncodingBinary;
	protected virtual string SaveFlowBinaryContentType => SaveFlowEncodedPayload.ContentTypeBinary;

	protected abstract TData CaptureSaveData();

	protected abstract byte[] SerializeSaveData(TData data);

	protected abstract TData DeserializeSaveData(byte[] bytes);

	protected abstract void ApplySaveData(TData data);

	public GodotDictionary ToSaveFlowEncodedPayload()
		=> SaveFlowEncodedPayload.CreateBinaryPayload(
			CaptureSaveData(),
			SerializeSaveData,
			SaveFlowPayloadSchema,
			SaveFlowPayloadDataVersion,
			SaveFlowBinaryEncoding,
			SaveFlowBinaryContentType);

	public void ApplySaveFlowEncodedPayload(GodotDictionary payload)
		=> SaveFlowEncodedPayload.ApplyBinaryPayload(payload, DeserializeSaveData, ApplySaveData);

	public virtual GodotDictionary GetSaveFlowPayloadInfo()
		=> SaveFlowEncodedPayload.BinaryInfo(
			SaveFlowPayloadSchema,
			SaveFlowPayloadDataVersion,
			encoding: SaveFlowBinaryEncoding,
			contentType: SaveFlowBinaryContentType);

	public GodotDictionary to_saveflow_encoded_payload()
		=> ToSaveFlowEncodedPayload();

	public void apply_saveflow_encoded_payload(GodotDictionary payload)
		=> ApplySaveFlowEncodedPayload(payload);

	public GodotDictionary get_saveflow_payload_info()
		=> GetSaveFlowPayloadInfo();
}

/// <summary>
/// Node-backed binary provider for the common "one state object" workflow.
/// Use this with BinaryWriter, MessagePack, protobuf, or any project-owned
/// serializer that can convert a state object to and from byte[].
/// </summary>
public abstract partial class SaveFlowBinaryStateProvider<TState> : Node, ISaveFlowEncodedPayloadProvider
{
	protected virtual string SaveFlowPayloadSchema => typeof(TState).FullName ?? typeof(TState).Name;
	protected virtual int SaveFlowPayloadDataVersion => 1;
	protected virtual string SaveFlowBinaryEncoding => SaveFlowEncodedPayload.EncodingBinary;
	protected virtual string SaveFlowBinaryContentType => SaveFlowEncodedPayload.ContentTypeBinary;
	protected abstract TState State { get; set; }

	protected virtual TState CaptureSaveState()
		=> State;

	protected abstract byte[] SerializeSaveState(TState state);

	protected abstract TState DeserializeSaveState(byte[] bytes);

	protected virtual void ApplySaveState(TState state)
	{
		State = state;
		OnSaveFlowStateApplied(state);
	}

	protected virtual void OnSaveFlowStateApplied(TState state)
	{
	}

	public GodotDictionary ToSaveFlowEncodedPayload()
		=> SaveFlowEncodedPayload.CreateBinaryPayload(
			CaptureSaveState(),
			SerializeSaveState,
			SaveFlowPayloadSchema,
			SaveFlowPayloadDataVersion,
			SaveFlowBinaryEncoding,
			SaveFlowBinaryContentType);

	public void ApplySaveFlowEncodedPayload(GodotDictionary payload)
		=> SaveFlowEncodedPayload.ApplyBinaryPayload(payload, DeserializeSaveState, ApplySaveState);

	public virtual GodotDictionary GetSaveFlowPayloadInfo()
		=> SaveFlowEncodedPayload.BinaryInfo(
			SaveFlowPayloadSchema,
			SaveFlowPayloadDataVersion,
			encoding: SaveFlowBinaryEncoding,
			contentType: SaveFlowBinaryContentType);

	public GodotDictionary to_saveflow_encoded_payload()
		=> ToSaveFlowEncodedPayload();

	public void apply_saveflow_encoded_payload(GodotDictionary payload)
		=> ApplySaveFlowEncodedPayload(payload);

	public GodotDictionary get_saveflow_payload_info()
		=> GetSaveFlowPayloadInfo();
}

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

/// <summary>
/// Runtime-only reflection convenience path for small C# models.
/// Prefer explicit encoded payload providers for large or frequently saved state.
/// </summary>
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

internal static class SaveFlowTypedDataReflection
{
	private static readonly ConcurrentDictionary<Type, MemberBinding[]> BindingsByType = new();

	public static GodotDictionary ToPayload(object source)
	{
		var payload = new GodotDictionary();
		foreach (var binding in GetBindings(source.GetType()))
			payload[binding.Key] = ToVariant(binding.GetValue(source));
		return payload;
	}

	public static void ApplyPayload(object target, GodotDictionary payload)
	{
		foreach (var binding in GetBindings(target.GetType()))
		{
			if (!payload.ContainsKey(binding.Key))
				continue;

			binding.SetValue(target, payload[binding.Key]);
		}
	}

	public static GodotArray GetPropertyNames(object source)
	{
		var names = new GodotArray();
		foreach (var binding in GetBindings(source.GetType()))
			names.Add(binding.Key);
		return names;
	}

	private static MemberBinding[] GetBindings(Type type)
		=> BindingsByType.GetOrAdd(type, BuildBindings);

	private static MemberBinding[] BuildBindings(Type type)
	{
		var bindings = new System.Collections.Generic.List<MemberBinding>();
		var flags = BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic;

		foreach (var property in type.GetProperties(flags))
		{
			if (property.GetIndexParameters().Length > 0 || !property.CanRead || !property.CanWrite)
				continue;
			if (!ShouldPersist(property))
				continue;

			bindings.Add(
				new MemberBinding(
					ResolveKey(property),
					property.PropertyType,
					target => property.GetValue(target),
					(target, value) => property.SetValue(target, ConvertVariant(value, property.PropertyType))
				)
			);
		}

		foreach (var field in type.GetFields(flags))
		{
			if (field.IsStatic || field.IsInitOnly)
				continue;
			if (!ShouldPersist(field))
				continue;

			bindings.Add(
				new MemberBinding(
					ResolveKey(field),
					field.FieldType,
					target => field.GetValue(target),
					(target, value) => field.SetValue(target, ConvertVariant(value, field.FieldType))
				)
			);
		}

		bindings.Sort((left, right) => string.CompareOrdinal(left.Key, right.Key));
		return bindings.ToArray();
	}

	private static bool ShouldPersist(MemberInfo member)
	{
		if (member.GetCustomAttribute<SaveFlowIgnoreAttribute>() is not null)
			return false;

		return member.GetCustomAttribute<ExportAttribute>() is not null
			|| member.GetCustomAttribute<SaveFlowKeyAttribute>() is not null;
	}

	private static string ResolveKey(MemberInfo member)
	{
		var keyAttribute = member.GetCustomAttribute<SaveFlowKeyAttribute>();
		if (keyAttribute is not null && !string.IsNullOrWhiteSpace(keyAttribute.Key))
			return keyAttribute.Key;

		return ToSnakeCase(member.Name);
	}

	private static string ToSnakeCase(string value)
	{
		if (string.IsNullOrEmpty(value))
			return value;

		var builder = new StringBuilder(value.Length + 8);
		for (var i = 0; i < value.Length; i++)
		{
			var current = value[i];
			var previous = i > 0 ? value[i - 1] : '\0';
			var next = i + 1 < value.Length ? value[i + 1] : '\0';
			var shouldSplit = i > 0
				&& char.IsUpper(current)
				&& (char.IsLower(previous) || char.IsDigit(previous) || char.IsLower(next));
			if (shouldSplit)
				builder.Append('_');

			builder.Append(char.ToLowerInvariant(current));
		}
		return builder.ToString();
	}

	private static Variant ToVariant(object? value)
	{
		if (value is null)
			return default;
		if (value is Variant variant)
			return variant;
		if (value.GetType().IsEnum)
			return Variant.CreateFrom(Convert.ToInt64(value));
		return value switch
		{
			bool typedValue => Variant.CreateFrom(typedValue),
			byte typedValue => Variant.CreateFrom(typedValue),
			sbyte typedValue => Variant.CreateFrom(typedValue),
			short typedValue => Variant.CreateFrom(typedValue),
			ushort typedValue => Variant.CreateFrom(typedValue),
			int typedValue => Variant.CreateFrom(typedValue),
			uint typedValue => Variant.CreateFrom(typedValue),
			long typedValue => Variant.CreateFrom(typedValue),
			ulong typedValue => Variant.CreateFrom(typedValue),
			float typedValue => Variant.CreateFrom(typedValue),
			double typedValue => Variant.CreateFrom(typedValue),
			string typedValue => Variant.CreateFrom(typedValue),
			StringName typedValue => Variant.CreateFrom(typedValue),
			NodePath typedValue => Variant.CreateFrom(typedValue),
			Vector2 typedValue => Variant.CreateFrom(typedValue),
			Vector2I typedValue => Variant.CreateFrom(typedValue),
			Vector3 typedValue => Variant.CreateFrom(typedValue),
			Vector3I typedValue => Variant.CreateFrom(typedValue),
			Vector4 typedValue => Variant.CreateFrom(typedValue),
			Vector4I typedValue => Variant.CreateFrom(typedValue),
			Color typedValue => Variant.CreateFrom(typedValue),
			Rect2 typedValue => Variant.CreateFrom(typedValue),
			Rect2I typedValue => Variant.CreateFrom(typedValue),
			Quaternion typedValue => Variant.CreateFrom(typedValue),
			Transform2D typedValue => Variant.CreateFrom(typedValue),
			Transform3D typedValue => Variant.CreateFrom(typedValue),
			Basis typedValue => Variant.CreateFrom(typedValue),
			Projection typedValue => Variant.CreateFrom(typedValue),
			Aabb typedValue => Variant.CreateFrom(typedValue),
			Plane typedValue => Variant.CreateFrom(typedValue),
			GodotDictionary typedValue => Variant.CreateFrom(typedValue),
			GodotArray typedValue => Variant.CreateFrom(typedValue),
			byte[] typedValue => Variant.CreateFrom(typedValue),
			int[] typedValue => Variant.CreateFrom(typedValue),
			long[] typedValue => Variant.CreateFrom(typedValue),
			float[] typedValue => Variant.CreateFrom(typedValue),
			double[] typedValue => Variant.CreateFrom(typedValue),
			string[] typedValue => Variant.CreateFrom(typedValue),
			Vector2[] typedValue => Variant.CreateFrom(typedValue),
			Vector3[] typedValue => Variant.CreateFrom(typedValue),
			Color[] typedValue => Variant.CreateFrom(typedValue),
			GodotObject typedValue => Variant.CreateFrom(typedValue),
			_ => default,
		};
	}

	private static object? ConvertVariant(Variant value, Type targetType)
	{
		if (targetType == typeof(Variant))
			return value;

		var nullableType = Nullable.GetUnderlyingType(targetType);
		if (nullableType is not null)
		{
			if (value.VariantType == Variant.Type.Nil)
				return null;
			targetType = nullableType;
		}

		if (targetType == typeof(bool))
			return value.AsBool();
		if (targetType == typeof(byte))
			return Convert.ToByte(value.AsInt64());
		if (targetType == typeof(sbyte))
			return Convert.ToSByte(value.AsInt64());
		if (targetType == typeof(short))
			return Convert.ToInt16(value.AsInt64());
		if (targetType == typeof(ushort))
			return Convert.ToUInt16(value.AsInt64());
		if (targetType == typeof(int))
			return value.AsInt32();
		if (targetType == typeof(uint))
			return Convert.ToUInt32(value.AsInt64());
		if (targetType == typeof(long))
			return value.AsInt64();
		if (targetType == typeof(ulong))
			return Convert.ToUInt64(value.AsInt64());
		if (targetType == typeof(float))
			return value.AsSingle();
		if (targetType == typeof(double))
			return value.AsDouble();
		if (targetType == typeof(string))
			return value.AsString();
		if (targetType == typeof(StringName))
			return value.AsStringName();
		if (targetType == typeof(NodePath))
			return value.AsNodePath();
		if (targetType == typeof(Vector2))
			return value.AsVector2();
		if (targetType == typeof(Vector2I))
			return value.AsVector2I();
		if (targetType == typeof(Vector3))
			return value.AsVector3();
		if (targetType == typeof(Vector3I))
			return value.AsVector3I();
		if (targetType == typeof(Vector4))
			return value.AsVector4();
		if (targetType == typeof(Vector4I))
			return value.AsVector4I();
		if (targetType == typeof(Color))
			return value.AsColor();
		if (targetType == typeof(Rect2))
			return value.AsRect2();
		if (targetType == typeof(Rect2I))
			return value.AsRect2I();
		if (targetType == typeof(Quaternion))
			return value.AsQuaternion();
		if (targetType == typeof(Transform2D))
			return value.AsTransform2D();
		if (targetType == typeof(Transform3D))
			return value.AsTransform3D();
		if (targetType == typeof(Basis))
			return value.AsBasis();
		if (targetType == typeof(Projection))
			return value.AsProjection();
		if (targetType == typeof(Aabb))
			return value.AsAabb();
		if (targetType == typeof(Plane))
			return value.AsPlane();
		if (targetType == typeof(GodotDictionary))
			return value.AsGodotDictionary();
		if (targetType == typeof(GodotArray))
			return value.AsGodotArray();
		if (targetType == typeof(byte[]))
			return value.AsByteArray();
		if (targetType == typeof(int[]))
			return value.AsInt32Array();
		if (targetType == typeof(long[]))
			return value.AsInt64Array();
		if (targetType == typeof(float[]))
			return value.AsFloat32Array();
		if (targetType == typeof(double[]))
			return value.AsFloat64Array();
		if (targetType == typeof(string[]))
			return value.AsStringArray();
		if (targetType == typeof(Vector2[]))
			return value.AsVector2Array();
		if (targetType == typeof(Vector3[]))
			return value.AsVector3Array();
		if (targetType == typeof(Color[]))
			return value.AsColorArray();
		if (targetType.IsEnum)
			return Enum.ToObject(targetType, value.AsInt64());
		if (typeof(GodotObject).IsAssignableFrom(targetType))
			return value.AsGodotObject();

		return value;
	}

	private sealed class MemberBinding
	{
		public string Key { get; }
		private Type ValueType { get; }
		private Func<object, object?> Getter { get; }
		private Action<object, Variant> Setter { get; }

		public MemberBinding(
			string key,
			Type valueType,
			Func<object, object?> getter,
			Action<object, Variant> setter)
		{
			Key = key;
			ValueType = valueType;
			Getter = getter;
			Setter = setter;
		}

		public object? GetValue(object source)
			=> Getter(source);

		public void SetValue(object target, Variant value)
			=> Setter(target, value);
	}
}
