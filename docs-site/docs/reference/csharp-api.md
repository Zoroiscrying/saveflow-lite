---
sidebar_position: 7
title: C# API
---

The C# API is a thin wrapper over the same SaveFlow runtime.

Use it for C# gameplay code, C# state Sources, and C# save-menu helpers.

## SaveFlowClient

Runtime access:

```csharp
SaveFlowClient.ResolveRuntime()
SaveFlowClient.IsRuntimeAvailable()
SaveFlowClient.Configure(...)
SaveFlowClient.SetStorageFormat(int mode)
```

Raw slot/data calls:

```csharp
SaveFlowClient.SaveSlot(string slotId, Variant data, Dictionary? meta = null)
SaveFlowClient.SaveData(string slotId, Variant data, Dictionary? meta = null)
SaveFlowClient.LoadData(string slotId)
SaveFlowClient.LoadSlot(string slotId)
SaveFlowClient.LoadSlotData(string slotId)
SaveFlowClient.LoadSlotOrDefault(string slotId, Variant defaultData)
```

Slot metadata and save menus:

```csharp
SaveFlowClient.BuildSlotMetadata(...)
SaveFlowClient.BuildSlotMetadataPatch(...)
SaveFlowClient.ReadSlotSummary(string slotId)
SaveFlowClient.ListSlotSummaries()
SaveFlowClient.InspectSlotCompatibility(string slotId)
SaveFlowClient.ListSlots()
SaveFlowClient.ReadSlotMetadata(string slotId)
SaveFlowClient.ReadSlotMetadataAsObject(string slotId)
SaveFlowClient.TryReadSlotMetadata<TMetadata>(string slotId, out TMetadata metadata)
SaveFlowClient.ReadMeta(string slotId)
SaveFlowClient.WriteMeta(string slotId, Dictionary metaPatch)
SaveFlowClient.DeleteSlot(string slotId)
SaveFlowClient.CopySlot(string fromSlot, string toSlot, bool overwrite = false)
SaveFlowClient.RenameSlot(string oldId, string newId, bool overwrite = false)
SaveFlowClient.ValidateSlot(string slotId)
SaveFlowClient.GetSlotPath(string slotId)
SaveFlowClient.SlotExists(string slotId)
SaveFlowClient.GetIndexPath()
```

Scene and Scope calls:

```csharp
SaveFlowClient.SaveNodes(string slotId, Node root, Dictionary? meta = null, string groupName = "saveflow")
SaveFlowClient.LoadNodes(string slotId, Node root, bool strict = false, string groupName = "saveflow")
SaveFlowClient.InspectScene(Node root, string groupName = "saveflow")
SaveFlowClient.CollectNodes(Node root, string groupName = "saveflow")
SaveFlowClient.ApplyNodes(Node root, Dictionary saveablesData, bool strict = false, string groupName = "saveflow")
SaveFlowClient.SaveScope(string slotId, Node scopeRoot, Dictionary? meta = null)
SaveFlowClient.LoadScope(string slotId, Node scopeRoot, bool strict = false)
SaveFlowClient.InspectScope(Node scopeRoot)
SaveFlowClient.GatherScope(Node scopeRoot)
SaveFlowClient.ApplyScope(Node scopeRoot, Dictionary scopePayload, bool strict = false)
```

Current data helpers:

```csharp
SaveFlowClient.SaveCurrent(string slotId, Dictionary? meta = null)
SaveFlowClient.LoadCurrent(string slotId)
SaveFlowClient.SetValue(string path, Variant value)
SaveFlowClient.GetValue(string path, Variant defaultValue = default)
SaveFlowClient.ClearCurrent()
SaveFlowClient.GetCurrentData()
```

Runtime entity helpers:

```csharp
SaveFlowClient.RegisterEntityFactory(Node factory)
SaveFlowClient.UnregisterEntityFactory(Node factory)
SaveFlowClient.ClearEntityFactories()
SaveFlowClient.RestoreEntities(Godot.Collections.Array descriptors, Dictionary? context = null, bool strict = false, Dictionary? options = null)
```

Dev helpers:

```csharp
SaveFlowClient.SaveDevNamedEntry(string entryName)
SaveFlowClient.LoadDevNamedEntry(string entryName)
```

## SaveFlowCallResult

Most C# calls return `SaveFlowCallResult`.

Use:

```csharp
var result = SaveFlowClient.SaveScope("slot_1", roomScope, metadata);
if (!result.Ok)
{
	GD.PushWarning(result.Message);
}
```

## SaveFlowTypedStateSource

Use this for one direct C# typed Source in the Save Graph.

Key members:

```csharp
[Export] public SaveFlowStatePayloadEncoding PayloadEncoding { get; set; }
protected virtual JsonTypeInfo SaveFlowStateTypeInfo { get; }
protected virtual string SaveFlowPayloadSchema { get; }
protected virtual GodotArray? SaveFlowPayloadSections { get; }
protected virtual object? SaveFlowState { get; set; }
protected void InitializeSaveFlowState<TState>(TState state, JsonTypeInfo<TState> typeInfo)
protected TState GetSaveFlowState<TState>()
protected void SetSaveFlowState<TState>(TState state)
protected virtual void OnSaveFlowStateApplied(object? state)
```

Encoding options:

```csharp
SaveFlowStatePayloadEncoding.JsonText
SaveFlowStatePayloadEncoding.JsonBytes
```

Use source-generated `JsonTypeInfo`.
Do not rely on runtime reflection for the direct typed-state Source path.

## SaveFlowSlotWorkflow

```csharp
var workflow = new SaveFlowSlotWorkflow();
workflow.SelectSlotIndex(1);
var metadata = workflow.BuildActiveSlotMetadata(
	displayName: "Village Start",
	saveType: "manual",
	chapterName: "Chapter 1",
	locationName: "Forest Gate",
	playtimeSeconds: 960);
SaveFlowClient.SaveScope(workflow.ActiveSlotId(), roomScope, metadata);
```

Common methods:

```csharp
SelectSlotIndex(int slotIndex)
ActiveSlotId()
SetSlotIdOverride(int slotIndex, string slotId)
ClearSlotIdOverrides()
SlotIdForIndex(int slotIndex)
FallbackDisplayNameForIndex(int slotIndex)
BuildActiveSlotMetadata(...)
BuildSlotMetadata(...)
BuildEmptyCard(int slotIndex)
BuildCardForIndex(int slotIndex, GodotDictionary? summary = null)
BuildCardsForIndices(IEnumerable<int> slotIndices, GodotArray? summaries = null)
```

## SaveFlowSlotMetadata

`SaveFlowSlotMetadata` is subclassable.

Use typed properties for project-owned metadata.
Use `CustomMetadata` only for small extension fields.

Important methods:

```csharp
SaveFlowSlotMetadata.FromValues(...)
SaveFlowSlotMetadata.FromDictionary(GodotDictionary? source)
ApplyExtra(GodotDictionary? extra)
ApplyPatch(GodotDictionary? source)
ToDictionary()
ToPatchDictionary()
GetExtraFieldNames()
GetSaveFlowAuthoringWarnings()
```

## SaveFlowEntityDescriptor

Use this helper when C# code needs to create or inspect runtime entity
descriptors.

```csharp
SaveFlowEntityDescriptor.FromValues(...)
SaveFlowEntityDescriptor.FromDictionary(GodotDictionary data)
descriptor.ToDictionary()
descriptor.GetPayloadDictionary()
descriptor.GetValidationMessage()
descriptor.GetExtraValue(key, defaultValue)
descriptor.SetExtraValue(key, value)
```
