# SaveFlow Core / Lite / Pro Split Plan

This document defines how SaveFlow should evolve from:

- one published `saveflow-lite` product
- one shared multi-plugin workspace

to:

- `saveflow_core`
- `saveflow_lite`
- `saveflow_pro`

The goal is:
- keep one Godot workspace for development
- keep one public repository per product
- make `SaveFlow Pro` a self-contained superset of `SaveFlow Lite`

## Product Model

The intended product relationship is:

- `SaveFlow Lite`
  - public
  - base workflow
- `SaveFlow Pro`
  - private
  - superset product
  - includes Lite capabilities

This means `pro` should **not** be shipped as a runtime dependency on the `lite` repository.

Instead:
- development can share code
- release artifacts must stay self-contained

## Recommended Workspace Structure

Target workspace shape:

```text
addons/
  saveflow_core/
  saveflow_lite/
  saveflow_pro/
demo/
  saveflow_lite/
  saveflow_pro/
tests/
  runtime/
    saveflow_lite/
    saveflow_pro/
```

Notes:
- `saveflow_core` contains shared runtime/editor code
- `saveflow_lite` contains Lite product wrapper, branding, and Lite-specific docs/demo entry points
- `saveflow_pro` contains Pro product wrapper, branding, and Pro-only features

## What Belongs In `saveflow_core`

Everything below is shared product infrastructure and should move to `saveflow_core`.

### Runtime

Current files:
- [save_flow.gd](/F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/core/save_flow.gd)
- [saveflow_scope.gd](/F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/core/saveflow_scope.gd)
- [saveflow_source.gd](/F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/core/saveflow_source.gd)
- [saveflow_node_source.gd](/F:/Coding-Projects/Godot/plugin-development/addons/saveflow_lite/runtime/sources/saveflow_node_source.gd)
- [saveflow_data_source.gd](/F:/Coding-Projects/Godot/plugin-development/addons/saveflow_lite/runtime/sources/saveflow_data_source.gd)
- [saveflow_entity_collection_source.gd](/F:/Coding-Projects/Godot/plugin-development/addons/saveflow_lite/runtime/entities/saveflow_entity_collection_source.gd)
- [saveflow_entity_factory.gd](/F:/Coding-Projects/Godot/plugin-development/addons/saveflow_lite/runtime/entities/saveflow_entity_factory.gd)
- [saveflow_prefab_entity_factory.gd](/F:/Coding-Projects/Godot/plugin-development/addons/saveflow_lite/runtime/entities/saveflow_prefab_entity_factory.gd)
- [saveflow_identity.gd](/F:/Coding-Projects/Godot/plugin-development/addons/saveflow_lite/runtime/entities/saveflow_identity.gd)
- [runtime/types](/F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/types)
- [runtime/serializers](/F:/Coding-Projects/Godot/plugin-development/addons/saveflow_core/runtime/serializers)

Reason:
- these are not Lite-only features
- Pro will almost certainly build on the same graph model

### Editor

Current files:
- [saveflow_inspector_plugin.gd](/F:/Coding-Projects/Godot/plugin-development/addons/saveflow_lite/editor/saveflow_inspector_plugin.gd)
- [editor/previews](/F:/Coding-Projects/Godot/plugin-development/addons/saveflow_lite/editor/previews)

Reason:
- inspector previews describe shared SaveFlow concepts
- Pro should not fork these by default

## What Stays In `saveflow_lite`

`saveflow_lite` should become the Lite product shell.

### Product wrapper

Keep:
- [plugin.cfg](/F:/Coding-Projects/Godot/plugin-development/addons/saveflow_lite/plugin.cfg)
- [plugin.gd](/F:/Coding-Projects/Godot/plugin-development/addons/saveflow_lite/plugin.gd)
- [icons/saveflow_icon.svg](/F:/Coding-Projects/Godot/plugin-development/addons/saveflow_lite/icons/saveflow_icon.svg)
- [README.md](/F:/Coding-Projects/Godot/plugin-development/addons/saveflow_lite/README.md)
- [LICENSE](/F:/Coding-Projects/Godot/plugin-development/addons/saveflow_lite/LICENSE)

Reason:
- these files define the Lite plugin identity
- they are the user-facing addon package

### Lite-specific demos and docs

Keep as Lite-owned release content:
- [demo/saveflow_lite](/F:/Coding-Projects/Godot/plugin-development/demo/saveflow_lite)
- [tests/runtime/saveflow_lite](/F:/Coding-Projects/Godot/plugin-development/tests/runtime/saveflow_lite)
- current SaveFlow Lite documentation set and screenshots

Reason:
- these are part of the Lite product presentation

## What Will Belong In `saveflow_pro`

`saveflow_pro` should contain only Pro-specific additions:

- Pro plugin wrapper
- Pro branding
- Pro-only runtime features
- Pro-only editor features
- Pro-only demos
- Pro-only docs/tests

Examples of features that would belong here:
- advanced reference resolution
- migration/version tooling beyond Lite scope
- commercial-grade restore orchestration
- higher-level authoring tools that are intentionally not in Lite

Rule:
- if a feature is fundamental to the SaveFlow graph model, it should probably live in `core`
- if a feature differentiates the paid or higher-tier product, it belongs in `pro`

## Release Projection Model

Release repositories should be assembled as:

### `saveflow-lite` repository

Include:
- `addons/saveflow_core`
- `addons/saveflow_lite`
- Lite demos
- Lite docs
- Lite tests

### `saveflow-pro` repository

Include:
- `addons/saveflow_core`
- `addons/saveflow_pro`
- Pro demos
- Pro docs
- Pro tests

This keeps both products self-contained.

## Migration Strategy

Do **not** move files immediately in one large pass.

Recommended order:

### Phase 1. Freeze product boundaries

Done or mostly done:
- Lite is published as its own repository
- release manifest flow exists

Next rule:
- no new Pro-only features should be added directly under `saveflow_lite`

### Phase 2. Introduce `saveflow_core` in the workspace

Create:
- `addons/saveflow_core`

Move only shared runtime/editor code into it.

Do not change product repositories yet.

### Phase 3. Repoint Lite to Core

Update Lite wrapper files so Lite addon package references `saveflow_core` internals correctly.

Goal:
- Lite becomes a thin product shell on top of shared code

### Phase 4. Create Pro shell

Create:
- `addons/saveflow_pro`

Add Pro-only product wrapper and features.

### Phase 5. Update release manifests

Replace current single-addon release projection with:
- `saveflow-lite = saveflow_core + saveflow_lite`
- `saveflow-pro = saveflow_core + saveflow_pro`

## Risks

### Risk 1. Breaking the published Lite repository layout

If the core split is done too aggressively, the current published repo becomes unstable.

Mitigation:
- treat the core split as a controlled migration
- keep release projection compatibility until the new layout is validated

### Risk 2. Misclassifying shared vs product-specific code

If Lite-only decisions leak into `core`, Pro will inherit unnecessary product constraints.

Mitigation:
- `core` should stay brandless and product-agnostic

### Risk 3. Duplicated demos and docs

If demo/test/docs ownership is not split by product, repositories will become noisy again.

Mitigation:
- keep demo/docs/tests namespaced by product directory

## Immediate Next Step

The next implementation step should be:

1. create `addons/saveflow_core`
2. move only one thin slice first, preferably:
   - `runtime/types`
   - `runtime/serializers`
   - `runtime/core`

Do not move everything at once.
