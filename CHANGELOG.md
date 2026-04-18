# Changelog

## 0.1.5

Updated in this release:
- Restored `addons/saveflow_core` in `saveflow-lite` distribution packaging
- Fixed repository sync workflow so Lite releases always include both `saveflow_core` and `saveflow_lite`
- Updated install guidance to copy both addon folders

## 0.1.4

Updated in this release:
- Refined component icon set for better inspector readability and faster visual recognition
- Increased and simplified component badges (`Scope`, `NodeSource`, `EntityCollectionSource`, `EntityFactory`) to improve list-view legibility
- Unified database base icon to a cleaner mono-color style across core SaveFlow components
- Updated release automation to keep `saveflow-lite` synced safely while preserving Asset Library archive filtering

## 0.1.2

Updated in this release:
- Fixed `SaveFlowEntityFactory` method detection so custom factory overrides are no longer misreported as missing
- Improved entity-factory inspector invalid diagnostics with clearer reasons and placeholder/tool-mode handling
- Stabilized `SaveFlowNodeSource` inspector foldouts so toggling options no longer resets expanded panels
- Fixed `Open DevSaveManager` navigation from `SaveFlow Settings` so the target dock/tab is focused correctly
- Simplified `DevSaveManager` panel by removing verbose path labels
- Fixed `DevSaveManager` copy/rename/delete workflow and operation feedback visibility
- Added fallback action-map initialization in Zelda-like demo player to avoid missing `sf_move_*` errors in isolated runs
- Expanded built-in serializer coverage and related runtime tests/docs updates

## 0.1.1

Updated in this release:
- Added `DevSaveManager` editor dock for runtime testing workflows
- Added runtime bridge bus (`SaveFlowSaveManagerBus`) and bridge contract (`SaveFlowSaveManagerBridge`)
- Added Zelda-like demo bridge integration for runtime save/load requests from the editor
- Added separate dev-save workflow (`devSaves`) alongside formal slot saves
- Added dual-list management in the dock: `Dev Saves` and `Formal Saves (Slot Index)`
- Added search, sort, copy, rename, delete, and folder-open actions in the new manager panel
- Added project settings entrypoint button to open `DevSaveManager`

## 0.1.0

Initial public repository version.

Included in this release:
- `SaveFlowNodeSource` for node-owned object state
- `SaveFlowDataSource` for custom system/model state
- `SaveFlowScope` for domain grouping and restore order
- `SaveFlowEntityCollectionSource` for runtime entity sets
- `SaveFlowPrefabEntityFactory` as the default runtime prefab path
- `SaveFlowEntityFactory` for advanced runtime spawn and lookup logic
- custom inspector previews for core SaveFlow nodes
- demo scenes:
  - plugin sandbox
  - recommended template
  - Zelda-like sample
- runtime test coverage for node, scope, data, and entity workflows

Known current boundaries:
- no first-class reference resolution system yet
- no formal migration pipeline beyond current version fields and contracts
- advanced runtime pooling still requires a custom `SaveFlowEntityFactory`
