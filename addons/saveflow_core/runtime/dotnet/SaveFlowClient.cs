using System;

using Godot;
using Godot.Collections;

namespace SaveFlow.DotNet;

/// <summary>
/// Minimal C# entrypoints for the SaveFlow runtime singleton.
/// This layer keeps call sites stable while the API evolves.
/// </summary>
public static class SaveFlowClient
{
	private const string RuntimeNodePath = "/root/SaveFlow";

	public static Node? ResolveRuntime()
	{
		if (Engine.GetMainLoop() is not SceneTree tree)
			return null;
		return tree.Root.GetNodeOrNull<Node>(RuntimeNodePath);
	}

	public static bool IsRuntimeAvailable()
		=> ResolveRuntime() is not null;

	public static SaveFlowCallResult Configure(
		string saveRoot,
		string slotIndexFile,
		int storageFormat = 0,
		bool prettyJsonInEditor = true,
		bool useSafeWrite = true,
		bool keepLastBackup = true,
		bool autoCreateDirs = true,
		bool includeMetaInSlotFile = true,
		string projectTitle = "",
		string gameVersion = "",
		int dataVersion = 1,
		string saveSchema = "main",
		bool enforceSaveSchemaMatch = true,
		bool enforceDataVersionMatch = true,
		bool verifyScenePathOnLoad = true,
		string fileExtensionJson = "json",
		string fileExtensionBinary = "sav",
		int logLevel = 2)
		=> CallRuntime(
			"configure_with",
			saveRoot,
			slotIndexFile,
			storageFormat,
			prettyJsonInEditor,
			useSafeWrite,
			keepLastBackup,
			autoCreateDirs,
			includeMetaInSlotFile,
			projectTitle,
			gameVersion,
			dataVersion,
			saveSchema,
			enforceSaveSchemaMatch,
			enforceDataVersionMatch,
			verifyScenePathOnLoad,
			fileExtensionJson,
			fileExtensionBinary,
			logLevel);

	public static SaveFlowSlotMetadata BuildSlotMetadata(Dictionary? overrides = null)
		=> SaveFlowSlotMetadata.FromDictionary(overrides);

	public static Dictionary BuildSlotMetadataPatch(Dictionary? overrides = null)
		=> BuildSlotMetadata(overrides).ToPatchDictionary();

	public static SaveFlowSlotMetadata BuildSlotMetadata(
		string displayName = "",
		string saveType = "manual",
		string chapterName = "",
		string locationName = "",
		int playtimeSeconds = 0,
		string difficulty = "",
		string thumbnailPath = "",
		Dictionary? extra = null)
		=> SaveFlowSlotMetadata.FromValues(
			displayName,
			saveType,
			chapterName,
			locationName,
			playtimeSeconds,
			difficulty,
			thumbnailPath,
			extra);

	public static Dictionary BuildSlotMetadataPatch(
		string displayName = "",
		string saveType = "manual",
		string chapterName = "",
		string locationName = "",
		int playtimeSeconds = 0,
		string difficulty = "",
		string thumbnailPath = "",
		Dictionary? extra = null)
		=> BuildSlotMetadata(
			displayName,
			saveType,
			chapterName,
			locationName,
			playtimeSeconds,
			difficulty,
			thumbnailPath,
			extra).ToPatchDictionary();

	public static SaveFlowCallResult SaveData(string slotId, Variant data, Dictionary? meta = null)
		=> CallRuntime("save_data", slotId, data, meta ?? new Dictionary());

	public static SaveFlowCallResult SaveData(string slotId, Variant data, SaveFlowSlotMetadata meta)
		=> CallRuntime("save_data", slotId, data, meta.ToPatchDictionary());

	public static SaveFlowCallResult SaveData(
		string slotId,
		Variant data,
		string displayName,
		string saveType = "manual",
		string chapterName = "",
		string locationName = "",
		int playtimeSeconds = 0,
		string difficulty = "",
		string thumbnailPath = "",
		Dictionary? extraMeta = null)
		=> CallRuntime(
			"save_data",
			slotId,
			data,
			displayName,
			saveType,
			chapterName,
			locationName,
			playtimeSeconds,
			difficulty,
			thumbnailPath,
			extraMeta ?? new Dictionary());

	public static SaveFlowCallResult LoadData(string slotId)
		=> CallRuntime("load_data", slotId);

	public static SaveFlowCallResult ReadSlotSummary(string slotId)
		=> CallRuntime("read_slot_summary", slotId);

	public static SaveFlowCallResult ListSlotSummaries()
		=> CallRuntime("list_slot_summaries");

	public static SaveFlowCallResult InspectSlotCompatibility(string slotId)
		=> CallRuntime("inspect_slot_compatibility", slotId);

	public static SaveFlowCallResult SaveNodes(string slotId, Node root, Dictionary? meta = null, string groupName = "saveflow")
		=> CallRuntime("save_scene", slotId, root, meta ?? new Dictionary(), groupName);

	public static SaveFlowCallResult SaveNodes(string slotId, Node root, SaveFlowSlotMetadata meta, string groupName = "saveflow")
		=> CallRuntime("save_scene", slotId, root, meta.ToPatchDictionary(), groupName);

	public static SaveFlowCallResult SaveNodes(
		string slotId,
		Node root,
		string displayName,
		string groupName = "saveflow",
		string saveType = "manual",
		string chapterName = "",
		string locationName = "",
		int playtimeSeconds = 0,
		string difficulty = "",
		string thumbnailPath = "",
		Dictionary? extraMeta = null)
		=> CallRuntime(
			"save_scene",
			slotId,
			root,
			displayName,
			groupName,
			saveType,
			chapterName,
			locationName,
			playtimeSeconds,
			difficulty,
			thumbnailPath,
			extraMeta ?? new Dictionary());

	public static SaveFlowCallResult LoadNodes(string slotId, Node root, bool strict = false, string groupName = "saveflow")
		=> CallRuntime("load_scene", slotId, root, strict, groupName);

	public static SaveFlowCallResult SaveScope(string slotId, Node scopeRoot, Dictionary? meta = null)
		=> CallRuntime("save_scope", slotId, scopeRoot, meta ?? new Dictionary());

	public static SaveFlowCallResult SaveScope(
		string slotId,
		Node scopeRoot,
		SaveFlowSlotMetadata meta)
		=> CallRuntime("save_scope", slotId, scopeRoot, meta.ToPatchDictionary());

	public static SaveFlowCallResult SaveScope(
		string slotId,
		Node scopeRoot,
		string displayName,
		string saveType = "manual",
		string chapterName = "",
		string locationName = "",
		int playtimeSeconds = 0,
		string difficulty = "",
		string thumbnailPath = "",
		Dictionary? extraMeta = null)
		=> CallRuntime(
			"save_scope",
			slotId,
			scopeRoot,
			displayName,
			default,
			saveType,
			chapterName,
			locationName,
			playtimeSeconds,
			difficulty,
			thumbnailPath,
			extraMeta ?? new Dictionary());

	public static SaveFlowCallResult LoadScope(string slotId, Node scopeRoot, bool strict = false)
		=> CallRuntime("load_scope", slotId, scopeRoot, strict);

	public static SaveFlowCallResult SaveCurrent(string slotId, Dictionary? meta = null)
		=> CallRuntime("save_current", slotId, meta ?? new Dictionary());

	public static SaveFlowCallResult SaveCurrent(string slotId, SaveFlowSlotMetadata meta)
		=> CallRuntime("save_current", slotId, meta.ToPatchDictionary());

	public static SaveFlowCallResult SaveCurrent(
		string slotId,
		string displayName,
		string saveType = "manual",
		string chapterName = "",
		string locationName = "",
		int playtimeSeconds = 0,
		string difficulty = "",
		string thumbnailPath = "",
		Dictionary? extraMeta = null)
		=> CallRuntime(
			"save_current",
			slotId,
			displayName,
			saveType,
			chapterName,
			locationName,
			playtimeSeconds,
			difficulty,
			thumbnailPath,
			extraMeta ?? new Dictionary());

	public static SaveFlowCallResult LoadCurrent(string slotId)
		=> CallRuntime("load_current", slotId);

	public static SaveFlowCallResult SaveDevNamedEntry(string entryName)
		=> CallRuntime("save_dev_named_entry", entryName);

	public static SaveFlowCallResult LoadDevNamedEntry(string entryName)
		=> CallRuntime("load_dev_named_entry", entryName);

	private static SaveFlowCallResult CallRuntime(StringName methodName, params Variant[] args)
	{
		var runtime = ResolveRuntime();
		if (runtime is null)
			return SaveFlowCallResult.RuntimeNotAvailable(methodName);

		try
		{
			var raw = runtime.Call(methodName, args);
			return SaveFlowCallResult.FromVariant(methodName, raw);
		}
		catch (Exception exception)
		{
			return SaveFlowCallResult.FromException(methodName, exception);
		}
	}
}
