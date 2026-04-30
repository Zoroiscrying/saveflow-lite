---
sidebar_position: 1
title: Install SaveFlow Lite
---

SaveFlow Lite is distributed as a Godot addon.

## Which Package Should I Use?

| Package | Use it when | Includes |
| --- | --- | --- |
| Godot Asset Library install | You are adding SaveFlow Lite to an existing project from inside Godot. | `addons/saveflow_core` and `addons/saveflow_lite`. |
| `saveflow-lite-vX.Y.Z-addons.zip` | You want the release zip for an existing project. | Only the addon folders required by a game project. |
| `saveflow-lite-vX.Y.Z-addons-demo.zip` | You want to open the demo project directly or study the recommended template scenes. | Addons, `demo/saveflow_lite`, and `project.godot`. |
| GitHub repository clone | You want docs source, release automation, or to inspect the public repository history. | The full public source mirror, including docs-site. |

For a game project, start with the Asset Library install or the addons zip.
Use the demo zip as a learning project, then copy only the scenes or patterns
you need.
Do not copy repository-only paths such as `docs-site`, `tmp`, `.github`, tests,
or release tooling into your game project.

## Install From A Release Zip

1. Download the latest `saveflow-lite-vX.Y.Z-addons.zip` release.
2. Extract it into your Godot project root.
3. Confirm these folders exist:
   - `res://addons/saveflow_core`
   - `res://addons/saveflow_lite`
4. Confirm you did not create a nested folder such as `res://saveflow-lite/addons`.
5. Open `Project > Project Settings > Plugins`.
6. Enable `SaveFlow Lite`.

The addons zip is also the shape expected by Godot Asset Library style installs:
the archive root is `addons/`, not a full demo project.

## Install The Demo Build

Use `saveflow-lite-vX.Y.Z-addons-demo.zip` when you want the recommended
template and demo scenes in the same project.

That package includes:

- the plugin under `res://addons`
- the SaveFlow Lite demo scenes under `res://demo/saveflow_lite`
- the project file needed to open the demo directly in Godot

For a real project, start from the addon zip and copy only the demo scenes you
want to study.

Do not copy `docs-site` into a game project. It is the Docusaurus source for
the public documentation site, not a Godot addon folder.

## Open The Editor Tools

After enabling the plugin, use these editor entry points:

- `SaveFlow Settings` for project-level save settings and setup health.
- the `SaveFlow` validator badge in the 2D/3D editor toolbar for current-scene warnings.
- Source inspectors for local preview, ownership warnings, and quick fixes.
- `DevSaveManager` for editor-time save/load testing while the game is running.
- `SaveFlow Quick Access` from the editor tool menu for the recommended template,
  pipeline notifications demo, C# workflow demo, and core editor panels.

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
