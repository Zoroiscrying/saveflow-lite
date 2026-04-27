using System;
using System.Collections.Concurrent;
using System.Reflection;
using System.Text;

using Godot;

using GodotArray = Godot.Collections.Array;
using GodotDictionary = Godot.Collections.Dictionary;

namespace SaveFlow.DotNet;

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

internal static class SaveFlowTypedDataReflection
{
	private const string TypedDataMarkerKey = "__saveflow_typed_data";
	private const string TypedDataPayloadKey = "data";

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
					(target, value) => property.SetValue(
						target,
						ConvertVariant(value, property.PropertyType, property.GetValue(target)))
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
					(target, value) => field.SetValue(
						target,
						ConvertVariant(value, field.FieldType, field.GetValue(target)))
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
		if (value is ISaveFlowEncodedPayloadProvider encodedProvider)
			return Variant.CreateFrom(encodedProvider.ToSaveFlowEncodedPayload());
		if (value is ISaveFlowPayloadProvider payloadProvider)
		{
			return Variant.CreateFrom(
				new GodotDictionary
				{
					[TypedDataMarkerKey] = true,
					[TypedDataPayloadKey] = payloadProvider.ToSaveFlowPayload(),
				}
			);
		}
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

	private static object? ConvertVariant(Variant value, Type targetType, object? currentValue = null)
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

		if (TryApplyEncodedPayloadProvider(value, targetType, currentValue, out var encodedProviderResult))
			return encodedProviderResult;
		if (TryApplyPayloadProvider(value, targetType, currentValue, out var payloadProviderResult))
			return payloadProviderResult;

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

	private static bool TryApplyEncodedPayloadProvider(
		Variant value,
		Type targetType,
		object? currentValue,
		out object? result)
	{
		result = null;
		if (!typeof(ISaveFlowEncodedPayloadProvider).IsAssignableFrom(targetType)
			&& currentValue is not ISaveFlowEncodedPayloadProvider)
		{
			return false;
		}
		if (value.VariantType != Variant.Type.Dictionary)
			return false;

		var provider = currentValue as ISaveFlowEncodedPayloadProvider
			?? Activator.CreateInstance(targetType) as ISaveFlowEncodedPayloadProvider;
		if (provider is null)
			return false;

		provider.ApplySaveFlowEncodedPayload(value.AsGodotDictionary());
		result = provider;
		return true;
	}

	private static bool TryApplyPayloadProvider(
		Variant value,
		Type targetType,
		object? currentValue,
		out object? result)
	{
		result = null;
		if (!typeof(ISaveFlowPayloadProvider).IsAssignableFrom(targetType)
			&& currentValue is not ISaveFlowPayloadProvider)
		{
			return false;
		}
		if (value.VariantType != Variant.Type.Dictionary)
			return false;

		var payload = value.AsGodotDictionary();
		if (payload.ContainsKey(TypedDataMarkerKey)
			&& payload.ContainsKey(TypedDataPayloadKey)
			&& payload[TypedDataPayloadKey].VariantType == Variant.Type.Dictionary)
		{
			payload = payload[TypedDataPayloadKey].AsGodotDictionary();
		}

		var provider = currentValue as ISaveFlowPayloadProvider
			?? Activator.CreateInstance(targetType) as ISaveFlowPayloadProvider;
		if (provider is null)
			return false;

		provider.ApplySaveFlowPayload(payload);
		result = provider;
		return true;
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
