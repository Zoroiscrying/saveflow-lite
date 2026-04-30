# Changelog

## 0.8.6

Updated in this release:
- Added a clean install release-zip validation script that expands an addons-only package into a temporary Godot project and verifies first-enable behavior
- Fixed clean first-enable loading by delaying SaveFlow Lite editor script loads until after the `SaveFlow` autoload path is registered
- Kept the `SaveFlow` autoload registered across editor shutdown and accepted Godot 4.6 `uid://` autoload paths in setup health and repair checks
- Relaxed C# project-file diagnostics so GDScript-only projects opened with .NET Godot do not see missing `.csproj` as a blocking setup issue

## 0.8.5

Updated in this release:
- Added a shared runtime entity restore diagnostics table for stable issue meanings and next-action text
- Updated the Entity Collection inspector preview to read restore issue next actions from the shared diagnostics table
- Aligned entity restore troubleshooting and reference docs with the same issue-code wording used by the editor preview
- Added editor-smoke coverage that locks the restore issue code, meaning, and next-action wording through the 0.8 line

## 0.8.4

Updated in this release:
- Added release asset allowlist validation so addons-only and demo zip packages fail if repository-only roots such as `docs-site`, `tmp`, `.github`, tests, tools, or unrelated addons appear
- Aligned the Asset Library/plugin description with the README and public docs positioning for the Lite baseline save model
- Clarified install/package wording across the README, addon README, and docs site so users know which paths belong in a Godot game project

## 0.8.3

Updated in this release:
- Added API-freeze smoke coverage for the public `SaveFlow` GDScript facade methods
- Added C# wrapper surface coverage for key `SaveFlowClient` entry points and typed metadata readback
- Added restore report schema coverage so `entity_restore_issues`, `first_issue`, and restore count fields stay stable through the 0.8 line
- Clarified the C# reference around `TryReadSlotMetadata<TMetadata>()` and documented the 0.8 API-freeze surface

## 0.8.2

Updated in this release:
- Added `SaveFlowEntityCollectionSource.get_last_restore_report()` so project code, tests, and tools can read the latest runtime entity restore report directly
- Updated the Entity Collection inspector preview with a Last Restore row that summarizes restored, spawned, reused, and skipped entity counts
- Surfaced the first structured restore issue code and a matching next action in the Entity Collection preview
- Refreshed the public roadmap around the current 0.8.x API-freeze beta focus

## 0.8.1

Updated in this release:
- Added structured runtime entity restore reports with `entity_restore_issues`, `first_issue`, `skipped_count`, `reused_count`, and `created_count`
- Distinguished missing `type_key`, missing `persistent_id`, missing factory routes, disabled creation for missing existing entities, null factory spawns, and nested entity graph apply failures
- Kept compatibility fields such as `missing_types`, `failed_ids`, `restored_count`, and `spawned_count` while giving report-only and strict restore modes the same report shape
- Added regression coverage for report-only restore diagnostics, strict failure diagnostics, and Apply Existing missing entity reporting

## 0.8.0

Updated in this release:
- Started the 0.8.x runtime entity ergonomics pass with clearer `SaveFlowEntityCollectionSource` authoring diagnostics
- Added collection-level recommended next actions so the inspector can explain whether to assign a container, configure a factory, add identities, fix duplicate ids, set explicit type keys, or repair factory routes
- Added warnings for `SaveFlowIdentity` nodes that fall back to parent-node-derived `type_key` values, making factory route drift easier to catch before runtime restore
- Updated the Entity Collection inspector preview with a first-screen Next Action row
- Added regression coverage for entity collection next actions and default `type_key` warnings

## 0.7.2

Updated in this release:
- Clarified install guidance across the root README and public docs so users can choose between the Godot Asset Library path, addons-only release zip, demo zip, and repository clone
- Documented the expected release package shapes, including the addons-only archive root and the demo archive contents
- Added public docs guidance that `docs-site` is documentation source and should not be copied into a Godot game project
- Added Quick Access ordering coverage so the recommended project workflow, pipeline notifications demo, and C# workflow stay first in the editor entry panel

## 0.7.1

Updated in this release:
- Expanded the public docs with real Godot screenshots for pipeline notifications, C# workflow, setup health, scene validator, and NodeSource warnings
- Enlarged the SaveFlow scene validator badge popup and constrained header text so issue lists have room to breathe
- Added a `docs-site/.gdignore` guard and cleaned generated import metadata so the Godot editor no longer scans the Docusaurus workspace
- Clarified example navigation so the recommended project workflow and focused public demos are the first learning path, while older sandboxes are treated as QA and historical references
- Updated SaveFlow Lite GitHub Actions workflows to Node 24 action majors, and moved the docs build runtime from Node 20 to Node 24 ahead of GitHub Actions' Node 20 retirement

## 0.7.0

Updated in this release:
- Added the public SaveFlow Lite documentation site source with concept guides, API reference pages, workflow starters, and screenshot-backed project workflow examples
- Added GitHub Pages deployment workflow syncing to the public `saveflow-lite` repository so the docs site can be published alongside release mirrors
- Updated release automation to sync `docs-site` and its deployment workflow while keeping Godot Asset Library archives limited to `addons/`
- Cleaned user-facing documentation so public docs no longer expose local development paths or internal workspace planning links
- Expanded Lite roadmap and documentation references around the 0.7.x docs/template cleanup phase

## 0.6.3

Updated in this release:
- Moved every C# `GodotObject`-derived SaveFlow helper into its own same-name `.cs` file so Godot's C# script reload map has one stable script owner per registered type
- Split the C# runtime helpers into `client`, `payloads`, `sources`, `slots`, and `entities` folders, with a local dotnet layout README covering responsibilities and the required rebuild-before-import workflow after moving Godot C# scripts
- Added existing SaveFlow component icons to the C# GodotObject-derived source/resource bases through `[GlobalClass, Icon(...)]`
- Replaced the C# typed-state provider path with direct `SaveFlowTypedStateSource` nodes, removing the intermediate state-provider family from the user-facing API
- Added `SaveFlowEncodedSource` for direct custom encoded C# sources and removed the format-specific JSON/Binary resource bases from the user-facing API
- Kept custom C# codec support through explicit encoded-payload methods and typed resources instead of separate provider/resource subclasses per format
- Updated release automation to create a local `.worktrees/.gdignore` development guard so the mirrored release worktree is not scanned as a second Godot project copy

## 0.6.2

Updated in this release:
- Reworked C# typed-state helpers to use non-generic Godot `Node`/`Resource` bases, avoiding Godot C# script reload collisions from generic `GodotObject` base classes
- Kept C# typed payloads dictionary-free by using `JsonTypeInfo`, `SaveFlowState`, and typed capture/apply overrides instead of per-field SaveFlow dictionaries
- Updated the C# workflow demo, fixtures, docs, and source map language to the Godot-safe non-generic source shape
- Preserved C# workflow behavior through C# build, Godot check-only, Lite runtime regression, and recommended-template regression runs

## 0.6.1

Updated in this release:
- Fixed `SaveFlowTypedDataSource` editor previews for non-tool C# payload nodes so inspector rendering no longer calls methods on Godot placeholder instances
- Preserved runtime C# typed-data save/load behavior while keeping editor previews contract-only until the target node is available at runtime
- Added generated script UID sidecars for the new 0.6.x C# helper and demo scripts so public release packages stay aligned with the Godot project state

## 0.6.0

Updated in this release:
- Expanded C# parity with thin `SaveFlowClient` wrappers for baseline slot, metadata, graph, scene, scope, validation, current-data, and entity-restore workflows
- Added C# `SaveFlowSlotWorkflow` and `SaveFlowSlotCard` helpers so active-slot ownership, typed slot metadata, and save-list cards no longer require repeated string-key glue
- Improved C# typed-data ergonomics with default state storage and optional payload sections for typed-state sources and custom encoded payloads
- Added a scene-authored C# workflow demo showing `SaveFlowTypedStateSource`, `SaveFlowSlotWorkflow`, `SaveFlowSlotCard`, and `SaveFlowClient.SaveScope()` working together
- Added Quick Access entry, docs, and runtime coverage for the C# workflow demo so C# users can start from a runnable project-style example
- Updated Setup Health and settings guidance to reference the C# workflow demo instead of the removed standalone Case 4 wording
- Preserved runtime behavior through Lite runtime, recommended-template, editor-smoke, C# build, and Godot check-only regression runs

## 0.5.0

Updated in this release:
- Added `SaveFlowSlotWorkflow` and `SaveFlowSlotCard` helpers for active slot index ownership, stable slot-id construction, typed slot metadata, and production-style save-list cards
- Updated the recommended project workflow so manual saves, load slots, delete slots, autosave, and checkpoint saves all operate through one explicit active slot instead of writing every visible save card
- Added runtime tests for active-slot save/delete behavior, autosave/checkpoint writes, and recommended-template card summaries
- Added `SaveFlowNodeSource` authoring warnings for unsupported target built-in selections and invalid target built-in field overrides so stale inspector settings no longer fail silently
- Added `SaveFlowEntityCollectionSource` authoring warnings for duplicate runtime entity `persistent_id` values, default `Identity` fallback ids, and entity `type_key` values that the configured factory cannot handle
- Expanded scene validator regression coverage so NodeSource built-in warnings and EntityCollection identity/factory warnings surface consistently from validator issue lists
- Expanded user-facing docs for fixing common source ownership, built-in selection, runtime container, identity, and factory routing mistakes

## 0.3.0

Updated in this release:
- Added current-scene SaveFlow preflight diagnostics through Setup Health and the scene validator badge, including source/scope/factory counts, duplicate or empty source-key checks, invalid source plans, pipeline signal warnings, component breakdowns, and next-action guidance
- Hardened Lite release automation with version-consistency checks, clean target-repository enforcement, safer fetch/rebase behavior, and unchanged release asset validation
- Added `RayCast2D` and `RayCast3D` built-in serializers for common gameplay sensor state such as enabled state, target position, collision mask, parent exclusion, area/body collision toggles, and hit options
- Clarified the recommended save-card workflow so games own `active_slot_index`, SaveFlow receives one stable `slot_id`, and `display_name` remains typed metadata for save-list UI
- Updated slot workflow examples to use typed `SaveFlowSlotMetadata` instead of repeated low-level metadata dictionaries
- Preserved runtime behavior through the full runtime regression suite and kept 0.3 scoped to preflight, reliability, and focused built-in polish

## 0.2.0

Updated in this release:
- Refactored the `SaveFlow` runtime singleton into focused internal services for storage, slot lifecycle, slot metadata, graph execution, pipeline lifecycle, DevSaveManager access, and entity restore
- Kept the public `SaveFlow` API stable while reducing the runtime facade and making future reliability work easier to isolate
- Preserved slot compatibility, slot summary, backup fallback, scope graph, node graph, pipeline signal, typed-data, and entity restore behavior through the runtime regression suite
- Fixed broken script resource references in the complex sandbox demo scene
- Cleaned the complex sandbox so its save graph uses one explicit `SaveGraphRoot` without duplicate Source children on the same targets
- Updated release metadata for the SaveFlow Lite 0.2.0 reliability release

## 0.1.10

Updated in this release:
- Added local pipeline lifecycle control through `SaveFlowPipelineControl`, `SaveFlowPipelineEvent`, `SaveFlowPipelineContext`, and scene-authored `SaveFlowPipelineSignals`
- Added a lightweight pipeline notification demo showing source-level `Data Saved` messages and final slot-level save/load notifications
- Added typed `SaveFlowSlotMetadata` and `SaveFlowEntityDescriptor` helpers across Godot and C# so common save metadata and entity routing data no longer require repeated string-key dictionary glue
- Improved C# typed-data support with JSON/binary encoded payload helpers and default apply/post-apply behavior
- Updated runtime entity collection/factory flows to use the typed descriptor helpers while keeping dictionary wire compatibility
- Added official icons for pipeline signals, typed data/source, prefab factory, identity, and slot metadata components
- Updated recommended-template docs, source maps, and regression tests around typed metadata, pipeline signals, entity descriptors, and the new notification demo

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
