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

- [SaveFlowClient.cs](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/dotnet/SaveFlowClient.cs)
  Thin C# wrapper around the `SaveFlow` autoload.
- [SaveFlowTypedData.cs](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/dotnet/SaveFlowTypedData.cs)
  C# typed-data helper. Provides encoded payload helpers (`SaveFlowEncodedPayload`, `ISaveFlowEncodedPayloadProvider`, `SaveFlowJsonStateProvider`, `SaveFlowBinaryStateProvider`) for source-generated JSON, binary bytes, or project-owned encoders, plus reflection convenience helpers (`SaveFlowTypedResource`, `SaveFlowTypedRefCounted`, `SaveFlowTypedPayload`) for small state.

### `addons/saveflow_core/runtime/entities`

- [saveflow_entity_collection_source.gd](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/entities/saveflow_entity_collection_source.gd)
  Main user path for runtime entity sets. Gathers entity descriptors and restores them through an entity factory.
- [saveflow_prefab_entity_factory.gd](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/entities/saveflow_prefab_entity_factory.gd)
  Default low-boilerplate entity factory. Maps one `type_key` to one prefab scene, can auto-create a runtime container, and reuses local entity save graphs.
- [saveflow_entity_factory.gd](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/entities/saveflow_entity_factory.gd)
  Advanced project-owned runtime entity creation contract. Use it when pooling, authored spawn systems, or custom lookup logic should replace the prefab default path.
- [saveflow_identity.gd](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/entities/saveflow_identity.gd)
  Stable runtime identity for entities. Carries `persistent_id` and `type_key`.

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
4. [saveflow_typed_data.gd](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/sources/saveflow_typed_data.gd)
5. [saveflow_typed_data_source.gd](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/sources/saveflow_typed_data_source.gd)
6. [SaveFlowTypedData.cs](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/dotnet/SaveFlowTypedData.cs)
7. [saveflow_data_source.gd](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/sources/saveflow_data_source.gd)
8. [saveflow_entity_collection_source.gd](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/entities/saveflow_entity_collection_source.gd)
9. [saveflow_prefab_entity_factory.gd](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/entities/saveflow_prefab_entity_factory.gd)
10. [saveflow_entity_factory.gd](F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/entities/saveflow_entity_factory.gd)

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
  Use when the project already owns runtime entity creation and lookup.

## Dependency Rules

- User-facing scene wiring should prefer direct node references over `NodePath` where possible.
- `SaveFlow` is a fixed autoload singleton, not a user-configured runtime dependency.
- `preload(...)` should be reserved for fixed resources and registries, not ordinary user integration paths.
