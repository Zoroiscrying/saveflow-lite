using System;
using System.Collections.Generic;
using System.Reflection;
using System.Text;

using Godot;

using GodotArray = Godot.Collections.Array;
using GodotDictionary = Godot.Collections.Dictionary;

namespace SaveFlow.DotNet;

/// <summary>
/// Lightweight C# helper for active-slot and save-card workflows.
/// SaveFlow does not own the player's current slot; this helper keeps that
/// project-owned state explicit while reducing repeated slot-id and metadata
/// glue in C# gameplay code.
/// </summary>
public sealed class SaveFlowSlotWorkflow
{
	private readonly Dictionary<int, string> _slotIdOverrides = new();

	public int ActiveSlotIndex { get; set; }
	public string SlotIdTemplate { get; set; } = "slot_{index}";
	public string EmptyDisplayNameTemplate { get; set; } = "Slot {index}";

	public string SelectSlotIndex(int slotIndex)
	{
		ActiveSlotIndex = slotIndex;
		return ActiveSlotId();
	}

	public string ActiveSlotId()
		=> SlotIdForIndex(ActiveSlotIndex);

	public void SetSlotIdOverride(int slotIndex, string slotId)
	{
		if (string.IsNullOrWhiteSpace(slotId))
		{
			_slotIdOverrides.Remove(slotIndex);
			return;
		}
		_slotIdOverrides[slotIndex] = slotId.Trim();
	}

	public void ClearSlotIdOverrides()
		=> _slotIdOverrides.Clear();

	public string SlotIdForIndex(int slotIndex)
		=> _slotIdOverrides.TryGetValue(slotIndex, out var slotId)
			? slotId
			: FormatIndexedText(SlotIdTemplate, slotIndex, $"slot_{slotIndex}");

	public string FallbackDisplayNameForIndex(int slotIndex)
		=> FormatIndexedText(EmptyDisplayNameTemplate, slotIndex, $"Slot {slotIndex}");

	public SaveFlowSlotMetadata BuildActiveSlotMetadata(
		string displayName = "",
		string saveType = "manual",
		string chapterName = "",
		string locationName = "",
		int playtimeSeconds = 0,
		string difficulty = "",
		string thumbnailPath = "",
		string slotRole = "")
		=> BuildSlotMetadata(
			ActiveSlotIndex,
			displayName,
			saveType,
			chapterName,
			locationName,
			playtimeSeconds,
			difficulty,
			thumbnailPath,
			slotRole);

	public TMetadata BuildActiveSlotMetadata<TMetadata>(
		string displayName = "",
		string saveType = "manual",
		string chapterName = "",
		string locationName = "",
		int playtimeSeconds = 0,
		string difficulty = "",
		string thumbnailPath = "",
		string slotRole = "")
		where TMetadata : SaveFlowSlotMetadata, new()
		=> BuildSlotMetadata<TMetadata>(
			ActiveSlotIndex,
			displayName,
			saveType,
			chapterName,
			locationName,
			playtimeSeconds,
			difficulty,
			thumbnailPath,
			slotRole);

	public SaveFlowSlotMetadata BuildSlotMetadata(
		int slotIndex,
		string displayName = "",
		string saveType = "manual",
		string chapterName = "",
		string locationName = "",
		int playtimeSeconds = 0,
		string difficulty = "",
		string thumbnailPath = "",
		string slotRole = "")
		=> BuildSlotMetadata<SaveFlowSlotMetadata>(
			slotIndex,
			displayName,
			saveType,
			chapterName,
			locationName,
			playtimeSeconds,
			difficulty,
			thumbnailPath,
			slotRole);

	public TMetadata BuildSlotMetadata<TMetadata>(
		int slotIndex,
		string displayName = "",
		string saveType = "manual",
		string chapterName = "",
		string locationName = "",
		int playtimeSeconds = 0,
		string difficulty = "",
		string thumbnailPath = "",
		string slotRole = "")
		where TMetadata : SaveFlowSlotMetadata, new()
	{
		var metadata = new TMetadata();
		var storageKey = SlotIdForIndex(slotIndex);
		metadata.SlotId = storageKey;
		metadata.DisplayName = string.IsNullOrEmpty(displayName)
			? FallbackDisplayNameForIndex(slotIndex)
			: displayName;
		metadata.SaveType = saveType;
		metadata.ChapterName = chapterName;
		metadata.LocationName = locationName;
		metadata.PlaytimeSeconds = playtimeSeconds;
		metadata.Difficulty = difficulty;
		metadata.ThumbnailPath = thumbnailPath;
		SetMetadataField(metadata, "slot_index", slotIndex);
		SetMetadataField(metadata, "storage_key", storageKey);
		if (!string.IsNullOrEmpty(slotRole))
			SetMetadataField(metadata, "slot_role", slotRole);
		return metadata;
	}

	public SaveFlowSlotCard BuildEmptyCard(int slotIndex)
		=> SaveFlowSlotCard.FromSummary(
			slotIndex,
			SlotIdForIndex(slotIndex),
			FallbackDisplayNameForIndex(slotIndex),
			activeSlotIndex: ActiveSlotIndex);

	public SaveFlowSlotCard BuildCardForIndex(int slotIndex, GodotDictionary? summary = null)
		=> SaveFlowSlotCard.FromSummary(
			slotIndex,
			SlotIdForIndex(slotIndex),
			FallbackDisplayNameForIndex(slotIndex),
			summary,
			ActiveSlotIndex);

	public SaveFlowSlotCard[] BuildCardsForIndices(IEnumerable<int> slotIndices, GodotArray? summaries = null)
	{
		var summariesBySlotId = new GodotDictionary();
		if (summaries is not null)
		{
			foreach (Variant summaryVariant in summaries)
			{
				if (summaryVariant.VariantType != Variant.Type.Dictionary)
					continue;
				var summary = summaryVariant.AsGodotDictionary();
				var slotId = ReadString(summary, "slot_id");
				if (!string.IsNullOrEmpty(slotId))
					summariesBySlotId[slotId] = summary;
			}
		}

		var cards = new List<SaveFlowSlotCard>();
		foreach (var slotIndex in slotIndices)
		{
			var slotId = SlotIdForIndex(slotIndex);
			GodotDictionary? summary = null;
			if (summariesBySlotId.TryGetValue(slotId, out var summaryVariant)
				&& summaryVariant.VariantType == Variant.Type.Dictionary)
			{
				summary = summaryVariant.AsGodotDictionary();
			}
			cards.Add(BuildCardForIndex(slotIndex, summary));
		}
		return cards.ToArray();
	}

	private static void SetMetadataField(SaveFlowSlotMetadata metadata, string fieldId, object value)
	{
		if (TrySetMember(metadata, fieldId, value))
			return;
		metadata.CustomMetadata[fieldId] = ToVariant(value);
	}

	private static bool TrySetMember(object target, string fieldId, object value)
	{
		var type = target.GetType();
		var flags = BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic;
		foreach (var candidateName in CandidateMemberNames(fieldId))
		{
			var property = type.GetProperty(candidateName, flags);
			if (property is not null && property.CanWrite)
			{
				property.SetValue(target, ConvertValue(value, property.PropertyType));
				return true;
			}

			var field = type.GetField(candidateName, flags);
			if (field is not null && !field.IsInitOnly)
			{
				field.SetValue(target, ConvertValue(value, field.FieldType));
				return true;
			}
		}
		return false;
	}

	private static IEnumerable<string> CandidateMemberNames(string fieldId)
	{
		yield return fieldId;
		yield return ToPascalCase(fieldId);
		yield return ToCamelCase(fieldId);
	}

	private static object? ConvertValue(object value, Type targetType)
	{
		var nullableType = Nullable.GetUnderlyingType(targetType);
		if (nullableType is not null)
			targetType = nullableType;
		if (targetType == typeof(Variant))
			return ToVariant(value);
		if (targetType == typeof(string))
			return Convert.ToString(value) ?? "";
		if (targetType.IsEnum)
			return Enum.ToObject(targetType, value);
		return Convert.ChangeType(value, targetType);
	}

	private static Variant ToVariant(object value)
		=> value switch
		{
			int typedValue => Variant.CreateFrom(typedValue),
			string typedValue => Variant.CreateFrom(typedValue),
			bool typedValue => Variant.CreateFrom(typedValue),
			float typedValue => Variant.CreateFrom(typedValue),
			double typedValue => Variant.CreateFrom(typedValue),
			long typedValue => Variant.CreateFrom(typedValue),
			_ => default,
		};

	private static string FormatIndexedText(string template, int slotIndex, string fallback)
	{
		var normalized = template.Trim();
		if (string.IsNullOrEmpty(normalized))
			return fallback;
		return normalized
			.Replace("{index}", slotIndex.ToString(), StringComparison.Ordinal)
			.Replace("%d", slotIndex.ToString(), StringComparison.Ordinal);
	}

	private static string ReadString(GodotDictionary source, string key)
		=> source.TryGetValue(key, out var value) && value.VariantType != Variant.Type.Nil
			? value.AsString()
			: "";

	private static string ToPascalCase(string value)
	{
		if (string.IsNullOrEmpty(value))
			return value;
		var builder = new StringBuilder(value.Length);
		var upperNext = true;
		foreach (var character in value)
		{
			if (character == '_')
			{
				upperNext = true;
				continue;
			}
			builder.Append(upperNext ? char.ToUpperInvariant(character) : character);
			upperNext = false;
		}
		return builder.ToString();
	}

	private static string ToCamelCase(string value)
	{
		var pascal = ToPascalCase(value);
		return string.IsNullOrEmpty(pascal)
			? pascal
			: char.ToLowerInvariant(pascal[0]) + pascal[1..];
	}
}
