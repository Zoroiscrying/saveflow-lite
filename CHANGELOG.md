# Changelog

## 0.1.9

Updated in this release:
- Added typed-data save workflows for Godot and C# so project data can be saved through explicit data objects/providers instead of repeated string-key dictionary glue
- Added C# encoded payload support, including JSON and binary payload examples, default apply behavior, and post-apply hooks
- Reworked the recommended template into a scene-authored project workflow with main/room save data, authored subscenes, visual interaction zones, manual/load/delete slots, autosave/checkpoint flows, and runtime coin/entity collection examples
- Improved `SaveFlowNodeSource` authoring diagnostics for nested Source helpers, child Source composition, missing included children, and ownership boundaries such as `EntityCollectionSource`
- Refreshed NodeSource inspector guidance so stale or misplaced included children produce actionable warnings and can be cleaned up from the preview
- Added release-facing regression coverage for typed data providers, C# payload providers, recommended project workflow scenes, and NodeSource authoring mistakes
- Updated Lite docs and onboarding language around source selection, common authoring mistakes, C# quickstart, typed data, and recommended integration workflow

## 0.1.8

Updated in this release:
- Expanded built-in serializer coverage with a focused pass over common node-owned state, including `BaseButton`, `Range`, `OptionButton`, `LineEdit`, `TextEdit`, `Area3D`, and `NavigationAgent3D`
- Hardened built-in serializer registry loading so new serializers resolve consistently in editor and CLI test environments
- Unified onboarding language across the root README, Lite README, Quick Access, and recommended template around the same three starting paths:
  - one object -> `SaveFlowNodeSource`
  - one system -> `SaveFlowDataSource`
  - one runtime set -> `SaveFlowEntityCollectionSource + SaveFlowPrefabEntityFactory`
- Added a short `saveflow-common-authoring-mistakes.md` checklist to reinforce the most important Lite authoring rules without making users read the full architecture docs
- Clarified the Lite roadmap so built-in coverage stays focused on meaningful runtime/object state instead of drifting into broad UI-widget persistence
- Added runtime coverage for the new built-ins and kept editor-entry smoke checks green during the onboarding polish pass

## 0.1.7

Updated in this release:
- Added Setup Health diagnostics and guided quick-fix actions in `SaveFlow Settings`
- Added `SaveFlow Quick Access` floating panel with one-click entry to demo cases and editor manager panels
- Added first-run minimal case launcher flow for NodeSource, DataSource, and EntityCollectionSource demo paths
- Improved hierarchy/editor warnings and inspector previews for Scope, DataSource, EntityFactory, and EntityCollection workflows
- Simplified prefab factory defaults back to a safer single-key routing model and improved narrow-layout behavior in editor panels
- Updated Quick Access panel UI with dark surface styling, better responsive layout, and footer version display

## 0.1.6

Updated in this release:
- Split workspace docs and plugin docs into clearer ownership boundaries
- Moved SaveFlow Lite user-facing docs and screenshots to `addons/saveflow_lite/docs`
- Updated README links to plugin-local docs paths
- Updated sync/release projection so plugin repositories no longer carry workspace-level docs

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
