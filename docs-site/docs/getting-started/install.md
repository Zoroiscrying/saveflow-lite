---
sidebar_position: 1
title: Install SaveFlow Lite
---

SaveFlow Lite is distributed as a Godot addon.

## Install From A Release Zip

1. Download the latest `saveflow-lite-vX.Y.Z-addons.zip` release.
2. Extract it into your Godot project root.
3. Confirm these folders exist:
   - `res://addons/saveflow_core`
   - `res://addons/saveflow_lite`
4. Open `Project > Project Settings > Plugins`.
5. Enable `SaveFlow Lite`.

## Install The Demo Build

Use `saveflow-lite-vX.Y.Z-addons-demo.zip` when you want the recommended
template and demo scenes in the same project.

That package includes:

- the plugin under `res://addons`
- the SaveFlow Lite demo scenes under `res://demo/saveflow_lite`
- the project file needed to open the demo directly in Godot

For a real project, start from the addon zip and copy only the demo scenes you
want to study.

## Open The Editor Tools

After enabling the plugin, use these editor entry points:

- `SaveFlow Settings` for project-level save settings and setup health.
- the `SaveFlow` validator badge in the 2D/3D editor toolbar for current-scene warnings.
- Source inspectors for local preview, ownership warnings, and quick fixes.
- `DevSaveManager` for editor-time save/load testing while the game is running.

## First Check

Before wiring gameplay, open `SaveFlow Settings` and confirm:

- the runtime is installed
- the save root is configured
- the save format is what you expect
- compatibility fields such as `game_version`, `data_version`, and `save_schema` are visible

This is intentionally boring. A save system should become predictable before it
becomes clever.

## Open The Recommended Template

The main project workflow template lives at:

```text
res://demo/saveflow_lite/recommended_template/scenes/project_workflow/recommended_project_workflow_main.tscn
```

Use it as the first scene to study because it shows the normal Godot workflow:

- a player controlled in a real scene
- manual save/load/delete slot interactions
- active slot behavior
- autosave/checkpoint behavior
- runtime coin/entity collection behavior
- screen-space save menu UI

If you are not sure which demo or case to open after that, read the Examples
One-Page Starter.
