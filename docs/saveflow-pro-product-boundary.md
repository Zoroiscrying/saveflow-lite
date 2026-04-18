# SaveFlow Pro Product Boundary

`SaveFlow Pro` is the future higher-tier SaveFlow product.

It should be treated as:
- private repository
- self-contained release artifact
- superset product that includes Lite capabilities

It should **not** be treated as:
- a runtime dependency on the public `saveflow-lite` repository
- a thin package that asks users to install Lite separately

## Current State

Right now the workspace contains only a placeholder:

- [addons/saveflow_pro/README.md](/F:/Coding-Projects/Godot/plugin-development/addons/saveflow_pro/README.md)

There is no released Pro plugin shell yet.

That is acceptable.

The first step is to define the product boundary before implementing features.

## Release Direction

Final release shape should be:

```text
addons/
  saveflow_core/
  saveflow_pro/
```

Meaning:
- `saveflow_core` contains the shared SaveFlow engine and editor features
- `saveflow_pro` contains only Pro-specific runtime/editor features and product wrapper files

## What Pro Should Eventually Contain

Examples of likely Pro-only features:
- advanced reference resolving
- migration/version tooling beyond Lite scope
- higher-level authoring workflows
- premium restore orchestration tools
- other commercial-only ergonomics that should not define the Lite baseline

## Immediate Practical Rule

Until `saveflow_core` exists:
- do not ship `saveflow_pro` as if it were ready
- do not copy `saveflow_lite` into `saveflow_pro`
- do not make Pro depend on the public Lite repository at runtime

Instead:
- keep `saveflow_pro` as a product placeholder
- finish the `core / lite / pro` architecture split first

## Release Manifest

The current placeholder release manifest is:

- [saveflow-pro.json](/F:/Coding-Projects/Godot/plugin-development/release-manifests/saveflow-pro.json)

Current feature planning lives here:

- [saveflow-pro-feature-plan.md](/F:/Coding-Projects/Godot/plugin-development/docs/saveflow-pro-feature-plan.md)

The release pipeline now exports:

- workspace-level release files
- `addons/saveflow_core`
- `addons/saveflow_pro`

This keeps the private product repository self-contained before the Pro shell is implemented.
