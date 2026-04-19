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

	public static SaveFlowCallResult SaveData(string slotId, Variant data, Dictionary? meta = null)
		=> CallRuntime("save_data", slotId, data, meta ?? new Dictionary());

	public static SaveFlowCallResult LoadData(string slotId)
		=> CallRuntime("load_data", slotId);

	public static SaveFlowCallResult SaveNodes(string slotId, Node root, Dictionary? meta = null, string groupName = "saveflow")
		=> CallRuntime("save_scene", slotId, root, meta ?? new Dictionary(), groupName);

	public static SaveFlowCallResult LoadNodes(string slotId, Node root, bool strict = false, string groupName = "saveflow")
		=> CallRuntime("load_scene", slotId, root, strict, groupName);

	public static SaveFlowCallResult SaveScope(string slotId, Node scopeRoot, Dictionary? meta = null, Dictionary? context = null)
		=> CallRuntime("save_scope", slotId, scopeRoot, meta ?? new Dictionary(), context ?? new Dictionary());

	public static SaveFlowCallResult LoadScope(string slotId, Node scopeRoot, bool strict = false, Dictionary? context = null)
		=> CallRuntime("load_scope", slotId, scopeRoot, strict, context ?? new Dictionary());

	public static SaveFlowCallResult SaveCurrent(string slotId, Dictionary? meta = null)
		=> CallRuntime("save_current", slotId, meta ?? new Dictionary());

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
