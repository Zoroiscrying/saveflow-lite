# SaveFlow Source Map

This file is the shortest map of the plugin source tree.

Use it to answer two questions quickly:
- where does a concept live?
- which file should be edited for a given behavior?

## Runtime Layout

### `addons/saveflow_core/runtime/core`

- [save_flow.gd](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/core/save_flow.gd)
  The autoload runtime. Owns slot IO, graph traversal, diagnostics, and entity-factory registration.
- [saveflow_source.gd](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/core/saveflow_source.gd)
  Base leaf contract. Every source gathers save data and applies save data.
- [saveflow_scope.gd](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/core/saveflow_scope.gd)
  Graph grouping node. Organizes domains and restore order.

### `addons/saveflow_core/runtime/types`

- [saveflow_pipeline_control.gd](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/types/saveflow_pipeline_control.gd)
  User-facing local save/load callback control. Owns lifecycle callables and routes cancellation/error handling.
- [saveflow_pipeline_event.gd](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/types/saveflow_pipeline_event.gd)
  Typed event object passed to pipeline callbacks. Carries stage, slot id, source/scope, payload, result, and context.
- [saveflow_pipeline_context.gd](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/types/saveflow_pipeline_context.gd)
  Local lifecycle shared data and trace support. Hooks receive its `values` dictionary; results expose its ordered `pipeline_trace`.
- [saveflow_pipeline_signals.gd](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/types/saveflow_pipeline_signals.gd)
  Scene-authored signal bridge for local pipeline events. It can live under a scope/source, emits inspector-connectable signals, and is not serialized.

### `addons/saveflow_core/runtime/sources`

- [saveflow_node_source.gd](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/sources/saveflow_node_source.gd)
  Main user path for saving one Godot object. Handles exported fields, built-ins, and selected child participants.
- [saveflow_typed_data.gd](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/sources/saveflow_typed_data.gd)
  Typed business-data resource. Converts exported fields to and from SaveFlow payload dictionaries.
- [saveflow_typed_data_source.gd](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/sources/saveflow_typed_data_source.gd)
  Low-boilerplate source for typed payload-provider state.
- [saveflow_data_source.gd](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/sources/saveflow_data_source.gd)
  Base class for custom system/model/table adapters. User code lives here when gather/apply logic is project-specific.

### `addons/saveflow_core/runtime/dotnet`

- [README.md](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/dotnet/README.md)
  C# runtime folder map. Explains client, payload, source, slot, and entity helper boundaries plus the rebuild-before-import rule for moved C# Godot scripts.

### `addons/saveflow_core/runtime/dotnet/client`

- [SaveFlowClient.cs](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/dotnet/client/SaveFlowClient.cs)
  Thin C# wrapper around the `SaveFlow` autoload.
- [SaveFlowCallResult.cs](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/dotnet/client/SaveFlowCallResult.cs)
  Result wrapper for C# runtime calls.

### `addons/saveflow_core/runtime/dotnet/payloads`

- [SaveFlowPayloadContracts.cs](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/dotnet/payloads/SaveFlowPayloadContracts.cs)
  C# payload contracts and `[SaveFlowKey]` / `[SaveFlowIgnore]` attributes.
- [SaveFlowEncodedPayload.cs](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/dotnet/payloads/SaveFlowEncodedPayload.cs)
  Helpers for encoded payload dictionaries used by source-generated JSON, binary bytes, or project-owned encoders.
- [SaveFlowTypedPayloadReflection.cs](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/dotnet/payloads/SaveFlowTypedPayloadReflection.cs)
  Cached reflection bridge used by `SaveFlowTypedResource`, `SaveFlowTypedRefCounted`, and slot metadata.
- [SaveFlowTypedResource.cs](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/dotnet/payloads/SaveFlowTypedResource.cs)
  Reflection convenience helper for small editable C# resources.
- [SaveFlowTypedRefCounted.cs](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/dotnet/payloads/SaveFlowTypedRefCounted.cs)
  Runtime-only reflection convenience helper for small C# models.

### `addons/saveflow_core/runtime/dotnet/sources`

- [SaveFlowEncodedSource.cs](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/dotnet/sources/SaveFlowEncodedSource.cs)
  Direct C# SaveGraph source for project-owned encoded payloads such as custom binary serializers.
- [SaveFlowTypedStateSource.cs](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/dotnet/sources/SaveFlowTypedStateSource.cs)
  Direct C# SaveGraph source for one typed DTO/record. Put derived nodes under `SaveFlowScope` without adding a separate `SaveFlowTypedDataSource` target.

### `addons/saveflow_core/runtime/dotnet/entities`

- [SaveFlowEntityDescriptor.cs](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/dotnet/entities/SaveFlowEntityDescriptor.cs)
  C# helper for runtime entity descriptors so integrations can avoid handwritten descriptor keys.

### `addons/saveflow_core/runtime/dotnet/slots`

- [SaveFlowSlotWorkflow.cs](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/dotnet/slots/SaveFlowSlotWorkflow.cs)
  C# active-slot helper that builds stable slot ids, typed metadata, and save-card summaries.
- [SaveFlowSlotMetadata.cs](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/dotnet/slots/SaveFlowSlotMetadata.cs)
  C# typed slot metadata model.
- [SaveFlowSlotCard.cs](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/dotnet/slots/SaveFlowSlotCard.cs)
  C# save-list card data for continue/load/save menu rows.

### `addons/saveflow_core/runtime/entities`

- [saveflow_entity_collection_source.gd](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/entities/saveflow_entity_collection_source.gd)
  Main user path for runtime entity sets. Gathers entity descriptors and restores them through an entity factory.
- [saveflow_entity_descriptor.gd](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/entities/saveflow_entity_descriptor.gd)
  Typed helper for the entity descriptor wire format (`persistent_id`, `type_key`, `payload`, and extra project fields).
- [saveflow_prefab_entity_factory.gd](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/entities/saveflow_prefab_entity_factory.gd)
  Default low-boilerplate entity factory. Maps one `type_key` to one prefab scene, can auto-create a runtime container, and reuses local entity save graphs.
- [saveflow_entity_factory.gd](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/entities/saveflow_entity_factory.gd)
  Advanced project-owned runtime entity creation contract. Use it when pooling, authored spawn systems, or custom lookup logic should replace the prefab default path.
- [saveflow_identity.gd](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/entities/saveflow_identity.gd)
  Stable runtime identity for entities. Carries `persistent_id`, `type_key`, and optional descriptor extra used for factory routing.

### `addons/saveflow_core/runtime/serializers`

- [saveflow_built_in_serializer.gd](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/serializers/saveflow_built_in_serializer.gd)
  Base serializer contract for engine-provided node state.
- [saveflow_built_in_serializer_registry.gd](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/serializers/saveflow_built_in_serializer_registry.gd)
  Registry of built-in serializers used by `SaveFlowNodeSource`.
- [saveflow_serializer_node2d.gd](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/serializers/saveflow_serializer_node2d.gd)
- [saveflow_serializer_node3d.gd](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/serializers/saveflow_serializer_node3d.gd)
- [saveflow_serializer_control.gd](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/serializers/saveflow_serializer_control.gd)
- [saveflow_serializer_animation_player.gd](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/serializers/saveflow_serializer_animation_player.gd)
  First-wave built-in serializers for common Godot node types.

### `addons/saveflow_core/runtime/types`

- [save_result.gd](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/types/save_result.gd)
  Common result wrapper returned by SaveFlow operations.
- [save_settings.gd](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/types/save_settings.gd)
  Runtime save settings model.
- [save_error.gd](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/types/save_error.gd)
- [save_format.gd](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/types/save_format.gd)
- [save_log_level.gd](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/types/save_log_level.gd)
  Shared enums and error constants.

## Editor Layout

### `addons/saveflow_lite/editor`

- [saveflow_inspector_plugin.gd](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_lite/editor/saveflow_inspector_plugin.gd)
  Registers custom inspector panels for SaveFlow nodes.

### `addons/saveflow_lite/editor/previews`

- [saveflow_node_source_inspector_preview.gd](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_lite/editor/previews/saveflow_node_source_inspector_preview.gd)
  Editor panel for node-source configuration and diagnostics.
- [saveflow_entity_collection_inspector_preview.gd](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_lite/editor/previews/saveflow_entity_collection_inspector_preview.gd)
  Editor panel for runtime entity collections.
- [saveflow_entity_factory_inspector_preview.gd](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_lite/editor/previews/saveflow_entity_factory_inspector_preview.gd)
  Editor panel for runtime entity factories.

## Recommended Reading Order

1. [saveflow-recommended-integration.md](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_lite/docs/saveflow-recommended-integration.md)
2. [save_flow.gd](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/core/save_flow.gd)
3. [saveflow_node_source.gd](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/sources/saveflow_node_source.gd)
4. [saveflow_pipeline_control.gd](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/types/saveflow_pipeline_control.gd)
5. [saveflow_pipeline_signals.gd](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/types/saveflow_pipeline_signals.gd)
6. [saveflow_pipeline_context.gd](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/types/saveflow_pipeline_context.gd)
7. [saveflow_typed_data.gd](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/sources/saveflow_typed_data.gd)
8. [saveflow_typed_data_source.gd](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/sources/saveflow_typed_data_source.gd)
9. [SaveFlowPayloadContracts.cs](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/dotnet/payloads/SaveFlowPayloadContracts.cs)
10. [SaveFlowEncodedPayload.cs](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/dotnet/payloads/SaveFlowEncodedPayload.cs)
11. [SaveFlowTypedPayloadReflection.cs](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/dotnet/payloads/SaveFlowTypedPayloadReflection.cs)
12. [saveflow_data_source.gd](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/sources/saveflow_data_source.gd)
13. [saveflow_entity_collection_source.gd](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/entities/saveflow_entity_collection_source.gd)
14. [saveflow_entity_descriptor.gd](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/entities/saveflow_entity_descriptor.gd)
15. [saveflow_prefab_entity_factory.gd](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/entities/saveflow_prefab_entity_factory.gd)
16. [saveflow_entity_factory.gd](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/entities/saveflow_entity_factory.gd)

## Naming Rules

- `SaveFlowNodeSource`
  Use when the user mental model is "save this object".
- `SaveFlowTypedDataSource`
  Use when the user mental model is "save this typed system/model or payload provider".
- `SaveFlowDataSource`
  Use when the user mental model is "save this custom system/model/table adapter".
- `SaveFlowEntityCollectionSource`
  Use when the user mental model is "save this changing runtime set".
- `SaveFlowEntityFactory`
  Use when the project already owns runtime entity creation and lookup. Custom
  factories should convert descriptor dictionaries with
  `resolve_entity_descriptor()` before reading `persistent_id`, `type_key`, or
  payload data.
- `SaveFlowPipelineControl`
  Use when caller code wants per-operation callbacks, cancellation, shared
  values, or trace inspection.
- `SaveFlowPipelineSignals`
  Use when scene-authored nodes should observe or cancel local pipeline stages
  through inspector-connected signals.

## Dependency Rules

- User-facing scene wiring should prefer direct node references over `NodePath` where possible.
- `SaveFlow` is a fixed autoload singleton, not a user-configured runtime dependency.
- `preload(...)` should be reserved for fixed resources and registries, not ordinary user integration paths.
