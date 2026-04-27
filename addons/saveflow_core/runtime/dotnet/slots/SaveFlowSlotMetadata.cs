using System;
using System.Collections.Generic;

using Godot;

using GodotArray = Godot.Collections.Array;
using GodotDictionary = Godot.Collections.Dictionary;

namespace SaveFlow.DotNet;

/// <summary>
/// Typed helper for SaveFlow's built-in slot metadata fields.
/// SaveFlow still writes dictionaries on disk; this class keeps default metadata
/// call sites away from string-key dictionaries.
/// </summary>
public class SaveFlowSlotMetadata
{
	private const int MaxRecommendedCustomMetadataFields = 12;
	private const int MaxMetadataWarningDepth = 12;

	private static readonly HashSet<string> KnownFields = new(StringComparer.Ordinal)
	{
		"slot_id",
		"display_name",
		"save_type",
		"chapter_name",
		"location_name",
		"playtime_seconds",
		"difficulty",
		"thumbnail_path",
		"created_at_unix",
		"created_at_iso",
		"saved_at_unix",
		"saved_at_iso",
		"scene_path",
		"project_title",
		"game_version",
		"data_version",
		"save_schema",
	};

	public string SlotId { get; set; } = "";
	public string DisplayName { get; set; } = "";
	public string SaveType { get; set; } = "manual";
	public string ChapterName { get; set; } = "";
	public string LocationName { get; set; } = "";
	public int PlaytimeSeconds { get; set; }
	public string Difficulty { get; set; } = "";
	public string ThumbnailPath { get; set; } = "";
	public int CreatedAtUnix { get; set; }
	public string CreatedAtIso { get; set; } = "";
	public int SavedAtUnix { get; set; }
	public string SavedAtIso { get; set; } = "";
	public string ScenePath { get; set; } = "";
	public string ProjectTitle { get; set; } = "";
	public string GameVersion { get; set; } = "";
	public int DataVersion { get; set; }
	public string SaveSchema { get; set; } = "";
	public GodotDictionary CustomMetadata { get; } = new();

	public static SaveFlowSlotMetadata FromValues(
		string displayName = "",
		string saveType = "manual",
		string chapterName = "",
		string locationName = "",
		int playtimeSeconds = 0,
		string difficulty = "",
		string thumbnailPath = "",
		GodotDictionary? extra = null)
	{
		var metadata = new SaveFlowSlotMetadata
		{
			DisplayName = displayName,
			SaveType = saveType,
			ChapterName = chapterName,
			LocationName = locationName,
			PlaytimeSeconds = playtimeSeconds,
			Difficulty = difficulty,
			ThumbnailPath = thumbnailPath,
		};
		metadata.ApplyExtra(extra);
		return metadata;
	}

	public static SaveFlowSlotMetadata FromDictionary(GodotDictionary? source)
	{
		var metadata = new SaveFlowSlotMetadata();
		metadata.ApplyPatch(source);
		return metadata;
	}

	public void ApplyExtra(GodotDictionary? extra)
	{
		if (extra is null)
			return;
		ApplyPatch(extra);
	}

	public void ApplyPatch(GodotDictionary? source)
	{
		if (source is null)
			return;

		var extra = new GodotDictionary();
		foreach (Variant key in source.Keys)
		{
			var fieldId = key.AsString();
			var value = source[key];
			switch (fieldId)
			{
				case "slot_id":
					SlotId = VariantToString(value);
					break;
				case "display_name":
					DisplayName = VariantToString(value);
					break;
				case "save_type":
					SaveType = VariantToString(value);
					break;
				case "chapter_name":
					ChapterName = VariantToString(value);
					break;
				case "location_name":
					LocationName = VariantToString(value);
					break;
				case "playtime_seconds":
					PlaytimeSeconds = VariantToInt(value);
					break;
				case "difficulty":
					Difficulty = VariantToString(value);
					break;
				case "thumbnail_path":
					ThumbnailPath = VariantToString(value);
					break;
				case "created_at_unix":
					CreatedAtUnix = VariantToInt(value);
					break;
				case "created_at_iso":
					CreatedAtIso = VariantToString(value);
					break;
				case "saved_at_unix":
					SavedAtUnix = VariantToInt(value);
					break;
				case "saved_at_iso":
					SavedAtIso = VariantToString(value);
					break;
				case "scene_path":
					ScenePath = VariantToString(value);
					break;
				case "project_title":
					ProjectTitle = VariantToString(value);
					break;
				case "game_version":
					GameVersion = VariantToString(value);
					break;
				case "data_version":
					DataVersion = VariantToInt(value);
					break;
				case "save_schema":
					SaveSchema = VariantToString(value);
					break;
				default:
					extra[fieldId] = value;
					break;
			}
		}

		ApplyTypedExtraFields(extra);
		OnMetadataApplied(source);
	}

	public GodotDictionary ToDictionary()
	{
		PushAuthoringWarnings();
		var meta = new GodotDictionary
		{
			["slot_id"] = SlotId,
			["display_name"] = DisplayName,
			["save_type"] = SaveType,
			["chapter_name"] = ChapterName,
			["location_name"] = LocationName,
			["playtime_seconds"] = PlaytimeSeconds,
			["difficulty"] = Difficulty,
			["thumbnail_path"] = ThumbnailPath,
			["created_at_unix"] = CreatedAtUnix,
			["created_at_iso"] = CreatedAtIso,
			["saved_at_unix"] = SavedAtUnix,
			["saved_at_iso"] = SavedAtIso,
			["scene_path"] = ScenePath,
			["project_title"] = ProjectTitle,
			["game_version"] = GameVersion,
			["data_version"] = DataVersion,
			["save_schema"] = SaveSchema,
		};
		AddTypedExtraFields(meta);
		AddCustomMetadata(meta);
		return meta;
	}

	public GodotDictionary ToPatchDictionary()
	{
		PushAuthoringWarnings();
		var meta = new GodotDictionary
		{
			["display_name"] = DisplayName,
			["save_type"] = SaveType,
			["chapter_name"] = ChapterName,
			["location_name"] = LocationName,
			["playtime_seconds"] = PlaytimeSeconds,
			["difficulty"] = Difficulty,
			["thumbnail_path"] = ThumbnailPath,
		};
		AddIfNotEmpty(meta, "slot_id", SlotId);
		AddIfNotZero(meta, "created_at_unix", CreatedAtUnix);
		AddIfNotEmpty(meta, "created_at_iso", CreatedAtIso);
		AddIfNotZero(meta, "saved_at_unix", SavedAtUnix);
		AddIfNotEmpty(meta, "saved_at_iso", SavedAtIso);
		AddIfNotEmpty(meta, "scene_path", ScenePath);
		AddIfNotEmpty(meta, "project_title", ProjectTitle);
		AddIfNotEmpty(meta, "game_version", GameVersion);
		AddIfNotZero(meta, "data_version", DataVersion);
		AddIfNotEmpty(meta, "save_schema", SaveSchema);
		AddTypedExtraFields(meta);
		AddCustomMetadata(meta);
		return meta;
	}

	protected virtual void OnMetadataApplied(GodotDictionary payload)
	{
	}

	public GodotArray GetExtraFieldNames()
	{
		var names = new GodotArray();
		foreach (Variant key in SaveFlowTypedDataReflection.GetPropertyNames(this))
		{
			var fieldId = key.AsString();
			if (!KnownFields.Contains(fieldId))
				names.Add(fieldId);
		}
		return names;
	}

	public GodotArray GetSaveFlowAuthoringWarnings()
	{
		var warnings = new GodotArray();
		var customFieldCount = 0;

		foreach (Variant key in CustomMetadata.Keys)
		{
			var fieldId = key.AsString();
			if (KnownFields.Contains(fieldId))
				continue;

			customFieldCount++;
			CollectMetadataValueWarnings(
				CustomMetadata[key],
				$"custom_metadata.{fieldId}",
				warnings);
		}

		var typedPayload = SaveFlowTypedDataReflection.ToPayload(this);
		foreach (Variant key in typedPayload.Keys)
		{
			var fieldId = key.AsString();
			if (KnownFields.Contains(fieldId))
				continue;

			customFieldCount++;
			CollectMetadataValueWarnings(
				typedPayload[key],
				fieldId,
				warnings);
		}

		if (customFieldCount > MaxRecommendedCustomMetadataFields)
		{
			warnings.Add(
				$"SaveFlowSlotMetadata has {customFieldCount} custom fields. Keep metadata small for save-list UI; move full gameplay state to save payloads, SaveFlow sources, or encoded payload providers.");
		}
		return warnings;
	}

	public GodotArray get_saveflow_authoring_warnings()
		=> GetSaveFlowAuthoringWarnings();

	public void PushAuthoringWarnings()
	{
		foreach (Variant warning in GetSaveFlowAuthoringWarnings())
			GD.PushWarning(warning.AsString());
	}

	public void push_saveflow_authoring_warnings()
		=> PushAuthoringWarnings();

	private void ApplyTypedExtraFields(GodotDictionary extra)
	{
		if (extra.Count == 0)
			return;

		SaveFlowTypedDataReflection.ApplyPayload(this, extra);
		var typedFieldNames = GetExtraFieldNames();
		foreach (Variant key in extra.Keys)
		{
			var fieldId = key.AsString();
			if (!typedFieldNames.Contains(fieldId))
				CustomMetadata[fieldId] = extra[key];
		}
	}

	private void AddTypedExtraFields(GodotDictionary target)
	{
		var typedPayload = SaveFlowTypedDataReflection.ToPayload(this);
		foreach (Variant key in typedPayload.Keys)
		{
			var fieldId = key.AsString();
			if (!KnownFields.Contains(fieldId))
				target[fieldId] = typedPayload[key];
		}
	}

	private void AddCustomMetadata(GodotDictionary target)
	{
		foreach (Variant key in CustomMetadata.Keys)
		{
			var fieldId = key.AsString();
			if (!KnownFields.Contains(fieldId) && !target.ContainsKey(fieldId))
				target[fieldId] = CustomMetadata[key];
		}
	}

	private static void AddIfNotEmpty(GodotDictionary target, string fieldId, string value)
	{
		if (!string.IsNullOrEmpty(value))
			target[fieldId] = value;
	}

	private static void AddIfNotZero(GodotDictionary target, string fieldId, int value)
	{
		if (value != 0)
			target[fieldId] = value;
	}

	private static string VariantToString(Variant value)
		=> value.VariantType == Variant.Type.Nil ? "" : value.AsString();

	private static int VariantToInt(Variant value)
		=> value.VariantType == Variant.Type.Nil ? 0 : value.AsInt32();

	private static void CollectMetadataValueWarnings(
		Variant value,
		string valuePath,
		GodotArray warnings,
		int depth = 0)
	{
		if (depth > MaxMetadataWarningDepth)
		{
			warnings.Add(
				$"SaveFlowSlotMetadata field '{valuePath}' is deeply nested. Keep metadata shallow for save-list UI and move complex state into the save payload.");
			return;
		}

		if (IsBasicMetadataValue(value))
			return;

		if (value.VariantType == Variant.Type.Array)
		{
			var array = value.AsGodotArray();
			for (var index = 0; index < array.Count; index++)
				CollectMetadataValueWarnings(array[index], $"{valuePath}[{index}]", warnings, depth + 1);
			return;
		}

		if (value.VariantType == Variant.Type.Dictionary)
		{
			var dictionary = value.AsGodotDictionary();
			foreach (Variant key in dictionary.Keys)
			{
				if (!IsBasicMetadataValue(key))
				{
					warnings.Add(
						$"SaveFlowSlotMetadata field '{valuePath}' uses a non-basic Dictionary key of type {DescribeVariantType(key)}. Metadata dictionaries should use basic keys and values.");
				}
				CollectMetadataValueWarnings(
					dictionary[key],
					$"{valuePath}.{key.AsString()}",
					warnings,
					depth + 1);
			}
			return;
		}

		warnings.Add(
			$"SaveFlowSlotMetadata field '{valuePath}' stores {DescribeVariantType(value)}. Metadata should stay small: use basic values, basic Array/Dictionary values, or SaveFlowTypedResource/ISaveFlowPayloadProvider; move gameplay state to save payloads or SaveFlow sources.");
	}

	private static bool IsBasicMetadataValue(Variant value)
		=> value.VariantType switch
		{
			Variant.Type.Nil => true,
			Variant.Type.Bool => true,
			Variant.Type.Int => true,
			Variant.Type.Float => true,
			Variant.Type.String => true,
			Variant.Type.StringName => true,
			Variant.Type.NodePath => true,
			Variant.Type.PackedByteArray => true,
			Variant.Type.PackedInt32Array => true,
			Variant.Type.PackedInt64Array => true,
			Variant.Type.PackedFloat32Array => true,
			Variant.Type.PackedFloat64Array => true,
			Variant.Type.PackedStringArray => true,
			_ => false,
		};

	private static string DescribeVariantType(Variant value)
	{
		if (value.VariantType == Variant.Type.Object)
		{
			var godotObject = value.AsGodotObject();
			return godotObject?.GetClass() ?? Variant.Type.Object.ToString();
		}
		return value.VariantType.ToString();
	}
}
