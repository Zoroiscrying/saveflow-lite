using System;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization.Metadata;

using Godot;

using GodotArray = Godot.Collections.Array;
using GodotDictionary = Godot.Collections.Dictionary;

namespace SaveFlow.DotNet;

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
	public const string EncodingJsonBytes = "json-bytes";
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
