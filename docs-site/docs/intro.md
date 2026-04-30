---
sidebar_position: 1
slug: /
title: SaveFlow Lite Docs
---

SaveFlow Lite is a comfort-first save workflow plugin for Godot 4.

It helps you build a project-ready save system by putting save ownership in the
scene tree instead of hiding everything inside one large save script.

For a game project, install from the Godot Asset Library or the
`saveflow-lite-vX.Y.Z-addons.zip` release package. Repository-only paths such as
`docs-site`, `tmp`, `.github`, tests, and release tooling should stay out of
your Godot project.

![SaveFlow save graph overview](/img/saveflow/savegraph-overview.svg)

Use this documentation to answer three questions:

- Which part of my game owns this saved data?
- Which SaveFlow Source should write and restore it?
- Which workflow should I copy into my Godot project?

## What Lite Covers

SaveFlow Lite focuses on the baseline save model:

- explicit Save Graph composition
- node state through `SaveFlowNodeSource`
- typed GDScript data through `SaveFlowTypedDataSource`
- typed C# state through `SaveFlowTypedStateSource`
- runtime-spawned objects through `SaveFlowEntityCollectionSource`
- domain boundaries through `SaveFlowScope`
- slot metadata, active slots, save cards, autosave, and checkpoint examples
- editor diagnostics, scene validator feedback, and setup health checks

## What Lite Does Not Try To Be

Lite does not try to become a full commercial orchestration layer.

Advanced workflows such as staged multi-scene restore, migration pipelines,
cloud conflict handling, storage profiles, reference repair, and seamless
background saves belong to SaveFlow Pro.

## Recommended Reading Path

1. Install the plugin from the Asset Library or release zip and confirm the editor tools are visible.
2. Build your first Save Graph.
3. Copy the common API calls into your first save/load buttons.
4. Learn the ownership model.
5. Choose the right Source for each kind of data.
6. Open the recommended template and compare the docs to the scene tree.
7. Use the Examples One-Page Starter to decide which demo to open next.
8. Use Reference when you need exact method names, properties, and signals.

## The Short Version

If the thing being saved is "this object", start with `SaveFlowNodeSource`.

If the thing being saved is "this typed system model", start with
`SaveFlowTypedDataSource` in GDScript or `SaveFlowTypedStateSource` in C#.

If the thing being saved is "this changing runtime set", start with
`SaveFlowEntityCollectionSource` and an entity factory.

If several Sources form one gameplay domain, group them with `SaveFlowScope`.
