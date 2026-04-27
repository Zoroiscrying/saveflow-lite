using System;

using Godot;

using GodotArray = Godot.Collections.Array;
using GodotDictionary = Godot.Collections.Dictionary;

namespace SaveFlow.DotNet;

/// <summary>
/// Typed save-card data for C# continue/load/save UIs.
/// This is a summary object only; game code still decides which SaveFlow call
/// to run when the card is selected.
/// </summary>
public sealed class SaveFlowSlotCard
{
	public int SlotIndex { get; set; } = -1;
	public string SlotId { get; set; } = "";
	public string DisplayName { get; set; } = "";
	public string SaveType { get; set; } = "";
	public string ChapterName { get; set; } = "";
	public string LocationName { get; set; } = "";
	public int PlaytimeSeconds { get; set; }
	public string Difficulty { get; set; } = "";
	public string ThumbnailPath { get; set; } = "";
	public int SavedAtUnix { get; set; }
	public string SavedAtIso { get; set; } = "";
	public bool Exists { get; set; }
	public bool IsActive { get; set; }
	public bool Compatible { get; set; } = true;
	public string[] CompatibilityReasons { get; set; } = Array.Empty<string>();
	public GodotDictionary CustomMetadata { get; private set; } = new();
	public GodotDictionary RawSummary { get; private set; } = new();

	public static SaveFlowSlotCard FromSummary(
		int slotIndex,
		string fallbackSlotId,
		string fallbackDisplayName,
		GodotDictionary? summary = null,
		int activeSlotIndex = -1)
	{
		var card = new SaveFlowSlotCard
		{
			SlotIndex = slotIndex,
			SlotId = fallbackSlotId,
			DisplayName = fallbackDisplayName,
			IsActive = slotIndex == activeSlotIndex,
		};
		if (summary is not null && summary.Count > 0)
			card.ApplySummary(summary);
		return card;
	}

	public void ApplySummary(GodotDictionary summary)
	{
		RawSummary = CopyDictionary(summary);
		Exists = true;
		SlotId = ReadString(summary, "slot_id", SlotId);
		DisplayName = ReadString(summary, "display_name", DisplayName);
		SaveType = ReadString(summary, "save_type", SaveType);
		ChapterName = ReadString(summary, "chapter_name", ChapterName);
		LocationName = ReadString(summary, "location_name", LocationName);
		PlaytimeSeconds = ReadInt(summary, "playtime_seconds", PlaytimeSeconds);
		Difficulty = ReadString(summary, "difficulty", Difficulty);
		ThumbnailPath = ReadString(summary, "thumbnail_path", ThumbnailPath);
		SavedAtUnix = ReadInt(summary, "saved_at_unix", SavedAtUnix);
		SavedAtIso = ReadString(summary, "saved_at_iso", SavedAtIso);
		CustomMetadata = ReadDictionary(summary, "custom_metadata");

		var compatibilityReport = ReadDictionary(summary, "compatibility_report");
		Compatible = ReadBool(compatibilityReport, "compatible", true);
		CompatibilityReasons = ReadStringArray(compatibilityReport, "reasons");

		if (CustomMetadata.TryGetValue("slot_index", out var slotIndex))
			SlotIndex = slotIndex.AsInt32();
	}

	public string ToLabelText()
	{
		var activeMarker = IsActive ? " [active]" : "";
		var state = Exists ? "saved" : "empty";
		var compatibility = Compatible ? "compatible" : "incompatible";
		var saveType = string.IsNullOrEmpty(SaveType) ? "<none>" : SaveType;
		var location = string.IsNullOrEmpty(LocationName) ? "<unknown>" : LocationName;
		return $"{DisplayName}{activeMarker}\nIndex: #{SlotIndex}\nStorage key: {SlotId}\nState: {state} | {compatibility}\nType: {saveType}\nLocation: {location}";
	}

	private static string ReadString(GodotDictionary source, string key, string fallback = "")
		=> source.TryGetValue(key, out var value) && value.VariantType != Variant.Type.Nil
			? value.AsString()
			: fallback;

	private static int ReadInt(GodotDictionary source, string key, int fallback = 0)
		=> source.TryGetValue(key, out var value) && value.VariantType != Variant.Type.Nil
			? value.AsInt32()
			: fallback;

	private static bool ReadBool(GodotDictionary source, string key, bool fallback = false)
		=> source.TryGetValue(key, out var value) && value.VariantType != Variant.Type.Nil
			? value.AsBool()
			: fallback;

	private static GodotDictionary ReadDictionary(GodotDictionary source, string key)
		=> source.TryGetValue(key, out var value) && value.VariantType == Variant.Type.Dictionary
			? CopyDictionary(value.AsGodotDictionary())
			: new GodotDictionary();

	private static string[] ReadStringArray(GodotDictionary source, string key)
	{
		if (!source.TryGetValue(key, out var value) || value.VariantType == Variant.Type.Nil)
			return Array.Empty<string>();
		if (value.VariantType == Variant.Type.PackedStringArray)
			return value.AsStringArray();
		if (value.VariantType == Variant.Type.Array)
		{
			var array = value.AsGodotArray();
			var values = new string[array.Count];
			for (var i = 0; i < array.Count; i++)
				values[i] = array[i].AsString();
			return values;
		}
		return new[] { value.AsString() };
	}

	private static GodotDictionary CopyDictionary(GodotDictionary source)
	{
		var copy = new GodotDictionary();
		foreach (Variant key in source.Keys)
			copy[key] = source[key];
		return copy;
	}
}
