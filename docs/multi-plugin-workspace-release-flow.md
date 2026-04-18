# Multi-Plugin Workspace Release Flow

This workspace is the development project.

It can contain several plugins at once:
- `saveflow_lite`
- `saveflow_pro`
- `control_center`

That does **not** mean they should share one public repository.

## Recommended Model

- one Godot project for local development
- one public repository per plugin
- one release manifest per plugin

The Godot project remains the shared workbench for:
- editor plugin iteration
- demo scenes
- shared test setup
- fast local validation across plugins

Each public repository should contain only one product line.

## Current Release Projection

The first release projection is:

- [saveflow-lite.json](/F:/Coding-Projects/Godot/plugin-development/release-manifests/saveflow-lite.json)

It defines:
- which workspace files belong to the `saveflow-lite` public repository
- which workspace files must stay out of the public repository

## Export Script

Use:

- [export_plugin_release.ps1](/F:/Coding-Projects/Godot/plugin-development/tools/export_plugin_release.ps1)

Example:

```powershell
.\tools\export_plugin_release.ps1 `
  -Manifest .\release-manifests\saveflow-lite.json `
  -Destination ..\release\saveflow-lite `
  -Clean
```

This creates a clean release projection from the shared workspace into a dedicated release directory.

## Why This Split Exists

This model keeps the tradeoff explicit:

- local development stays fast because all plugins share one Godot project
- public repositories stay clean because each plugin exports only its own files

Do not use the shared workspace itself as the public release repository for every plugin.
