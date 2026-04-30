---
sidebar_position: 1
title: Troubleshooting
---

Most SaveFlow Lite setup problems fall into a few categories.

Start with the scene validator badge.
Then inspect the specific Source that owns the warning.

![Scene Validator badge expanded with current-scene warnings](/img/saveflow/screenshots/editor-scene-validator-warnings.png)

## Duplicate Save Keys

Each Source in the same active save graph needs a stable, unique key.

Use the scene validator badge or Source warnings to find the duplicate node
paths before testing save/load.

Fix:

1. Select each reported Source.
2. Give each one a stable, unique key.
3. Prefer meaningful keys such as `player`, `settings`, or `runtime_coins`.
4. Save and reload only after the validator no longer reports duplicate keys.

## Nested Source Ownership

If a parent `SaveFlowNodeSource` recursively includes a child object that already
has its own Source, the graph becomes ambiguous.

![SaveFlowNodeSource inspector preview showing an included child ownership warning](/img/saveflow/screenshots/editor-node-source-warning.png)

Fix it by including the child Source directly, or by removing the child Source
if the parent truly owns that object.

Rule of thumb:

- if the child is part of the same object, let the parent own it
- if the child has its own identity or save lifecycle, give it its own Source
- if both are true, the scene probably needs a clearer boundary

## Runtime Entity Containers

Do not save runtime entity containers as ordinary recursive node subtrees.

Use `SaveFlowEntityCollectionSource` so the entity list, identities, descriptors,
and factory restore path stay explicit.

Fix:

1. Put `SaveFlowEntityCollectionSource` under or near the runtime container.
2. Add `SaveFlowIdentity` to runtime entity prefabs.
3. Set explicit `persistent_id` values for authored runtime entities.
4. Set explicit `type_key` values that match factory routes.
5. Configure a prefab factory or custom entity factory.
6. Exclude the runtime container from parent `SaveFlowNodeSource` subtree saves.

If the Entity Collection preview shows a Next Action, fix that item first. It
is built from the same plan data used by scene validator warnings.

## Slot Looks Wrong After Load

Check the active slot first.

Autosave and checkpoint flows should write to the active slot unless your game
intentionally routes them elsewhere.

Then check slot metadata and save card summaries to confirm which slot was
written.

## Stale Built-In Selection

This happens when a `SaveFlowNodeSource` target changes type after built-ins or
field overrides were selected.

Fix:

1. Select the Source.
2. Open the built-in preview/foldout.
3. Remove unsupported built-ins or field overrides.
4. Re-select the state that actually exists on the current target type.

## Missing Included Children

This happens when `included_paths` points to a child node that no longer exists.

Fix:

1. Select the Source.
2. Remove missing child entries.
3. Re-add the child only if it is still part of the same saved object.
4. If the child now has its own Source, include that Source directly instead.

## Scene Path Blocks Load

If `verify_scene_path_on_load` is enabled, SaveFlow treats saved scene path as a
baseline restore safety check.

That means loading can fail before applying data when the saved slot belongs to
a different scene.

Fix:

- load the expected scene first
- or disable scene-path verification if your project intentionally loads by key
  across scene paths

Disabling the check does not change how keys match payloads.
It only removes the scene-path safety guard.
