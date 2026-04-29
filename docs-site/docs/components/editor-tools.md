---
sidebar_position: 7
title: Editor Tools
---

SaveFlow Lite includes editor tools because save systems fail painfully when
mistakes are discovered only after pressing Load.

## SaveFlow Settings

Use `SaveFlow Settings` to review project-level defaults:

- save root
- slot index file
- storage format
- safe write and backup policy
- project title
- game version
- data version
- save schema
- scene-path verification

Setup health also checks whether the plugin installation and current scene
look ready enough to test.

![SaveFlow Settings with Setup Health expanded](/img/saveflow/screenshots/editor-setup-health-expanded.png)

## Scene Validator Badge

The 2D/3D editor toolbar shows a SaveFlow validator badge.

Use it while editing normal Godot scenes, not only while looking at SaveFlow
panels.

![Scene Validator badge expanded with current-scene warnings](/img/saveflow/screenshots/editor-scene-validator-warnings.png)

It reports issues such as:

- duplicate Source keys
- invalid Source plans
- invalid Scope layouts
- invalid entity factory setup
- invalid pipeline signal targets
- common ownership mistakes

## Source Inspector Preview

Source inspectors show what a Source intends to save.

Use previews to check:

- target node
- source key
- included child participants
- built-in selections
- typed payload sections
- entity collection restore plan

The preview is not decoration.
It is the quickest way to catch "this Source is saving the wrong thing."

![SaveFlowNodeSource inspector preview showing an included child ownership warning](/img/saveflow/screenshots/editor-node-source-warning.png)

## DevSaveManager

Use `DevSaveManager` while the game is running to test save/load without
building a final game menu.

It is for development workflow, not your shipped UI.
