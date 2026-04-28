---
sidebar_position: 1
title: Components
---

This page is the public component map for Lite.

Start from a workflow question:

- "save this object" -> `SaveFlowNodeSource`
- "save this typed model" -> `SaveFlowTypedDataSource` or `SaveFlowTypedStateSource`
- "save this runtime set" -> `SaveFlowEntityCollectionSource`
- "save this domain" -> `SaveFlowScope`

![SaveFlow component choice in Godot](/img/saveflow/saveflow-component-choice-v2.svg)

## Core Sources

- `SaveFlowNodeSource`: saves selected state from Godot nodes.
- `SaveFlowTypedDataSource`: saves typed GDScript data.
- `SaveFlowDataSource`: custom gather/apply source for project-specific logic.
- `SaveFlowEntityCollectionSource`: saves runtime entity containers.
- `SaveFlowTypedStateSource`: saves typed C# state.

## Domain And Runtime Helpers

- `SaveFlowScope`: groups Sources into a save/load domain.
- `SaveFlowIdentity`: gives runtime entities stable identity.
- `SaveFlowPrefabEntityFactory`: restores entity descriptors into scene nodes.
- `SaveFlowPipelineSignals`: emits save/load lifecycle signals without requiring every Source to be subclassed.

## Slot Workflow Helpers

- `SaveFlowSlotWorkflow`: active slot and slot ID helpers.
- `SaveFlowSlotCard`: typed save-list summary data.
- slot metadata resources: typed metadata stored with save files.

## Editor Tools

- `SaveFlow Settings`: project-level configuration and setup health.
- Scene validator badge: current-scene authoring warnings.
- Source inspector previews: local save plan visibility.
- `DevSaveManager`: runtime save/load testing from the editor.

## Component Pages

Read these pages when you are wiring a real scene:

- `SaveFlowNodeSource` for authored scene objects.
- typed data and C# typed state for system data.
- entity collections for runtime-spawned objects.
- Scopes for domain boundaries.
- slot workflow helpers for save menus, active slots, autosave, and checkpoints.
- pipeline signals for save/load lifecycle hooks.
- editor tools for setup health and scene validation.

For exact method signatures and exported fields, use the Reference section.
