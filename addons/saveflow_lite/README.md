# SaveFlow Lite

SaveFlow Lite is a comfort-first save workflow plugin for Godot 4.

Main paths:
- `SaveFlowNodeSource` for object-owned state
- `SaveFlowTypedDataSource` for typed system/model-style state
- `SaveFlowDataSource` for custom table, queue, registry, and adapter state
- `SaveFlowEntityCollectionSource` for runtime entity sets
- `SaveFlowScope` for domain boundaries and restore order

Start with one ownership model:
- one object -> `SaveFlowNodeSource`
- one typed system model -> `SaveFlowTypedDataSource`
- one custom table/registry adapter -> `SaveFlowDataSource`
- one runtime set -> `SaveFlowEntityCollectionSource` + `SaveFlowPrefabEntityFactory`

Default runtime entity path:
- `SaveFlowPrefabEntityFactory`

Advanced runtime entity path:
- custom `SaveFlowEntityFactory`

Project repository:
- <https://github.com/Zoroiscrying/saveflow-lite>

Useful docs:
- `addons/saveflow_lite/docs/saveflow-recommended-integration.md`
- `res://demo/saveflow_lite/recommended_template/scenes/project_workflow/recommended_project_workflow_main.tscn`
- `addons/saveflow_lite/docs/saveflow-common-authoring-mistakes.md`
- `addons/saveflow_lite/docs/saveflow-commercial-project-guide.md`

Editor debugging flow:
- `Compatibility` tells you whether the slot satisfies the current schema/data-version policy
- `Restore Contract` tells you whether the expected scene is already active
- `Slot Safety` tells you whether the primary file is healthy and whether backup recovery is available
