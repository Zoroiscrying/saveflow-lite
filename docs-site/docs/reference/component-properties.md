---
sidebar_position: 4
title: Component Properties
---

This page summarizes inspector-facing properties by component.

Use it when you know the concept but need to remember which field controls the
behavior.

## SaveFlowNodeSource

| Property | Default | Notes |
| --- | --- | --- |
| `save_key` | `""` | Empty derives the key from the target node name. |
| `target` | `null` | Empty usually means the parent/nearby object is the target. |
| `property_selection_mode` | Exported + additional | Default works for most gameplay nodes. |
| `additional_properties` | `[]` | Use sparingly for non-exported saved properties. |
| `ignored_properties` | `[]` | Use when exported editor fields should not persist. |
| `include_target_built_ins` | `true` | Saves built-in engine state where supported. |
| `included_target_builtin_ids` | `[]` | Usually managed through preview UI. |
| `target_builtin_field_overrides` | `{}` | Advanced field whitelist. |
| `included_paths` | `[]` | Child participants in the same saved object. |
| `excluded_paths` | `[]` | Excludes reachable children. |
| `participant_discovery_mode` | Recursive | Use Direct for simpler prefab shapes. |
| `warn_on_missing_target` | `true` | Keep on except for temporary authoring states. |
| `warn_on_missing_participants` | `true` | Catches stale child paths. |
| `warn_on_missing_property` | `true` | Catches renamed or removed properties. |

## SaveFlowTypedDataSource

| Property | Default | Notes |
| --- | --- | --- |
| `data` | `null` | Direct typed Resource provider. |
| `target` | `null` | Node provider or owner. |
| `data_property` | `""` | Property on `target` containing the provider. |
| `data_version` | `1` | Inherited from `SaveFlowDataSource`. |

## SaveFlowEntityCollectionSource

| Property | Default | Notes |
| --- | --- | --- |
| `target_container` | `null` | Empty means resolve the authored container shape. |
| `failure_policy` | Fail On Missing Or Invalid | Use Report Only during iteration. |
| `restore_policy` | Create Missing | Good default for runtime collections. |
| `include_direct_children_only` | `true` | Keep true unless entities live deeper. |
| `entity_factory` | `null` | Required for create/restore workflows. |
| `auto_register_factory` | `true` | Standard scene-owned workflow. |

## SaveFlowPrefabEntityFactory

| Property | Default | Notes |
| --- | --- | --- |
| `target_container` | `null` | Container for restored instances. |
| `auto_create_container` | `false` | Useful in simple demos, be explicit in real scenes. |
| `container_name` | `RuntimeEntities` | Used only when auto-creating. |
| `type_key` | `""` | Must match entity descriptor type keys. |
| `entity_scene` | `null` | Prefab to instantiate. |

## SaveFlowSlotWorkflow

| Property | Default | Notes |
| --- | --- | --- |
| `active_slot_index` | `0` | Project-owned selected slot index. |
| `slot_id_template` | `slot_{index}` | Converts index to storage key. |
| `empty_display_name_template` | `Slot {index}` | Used for empty save cards. |
| `metadata_script` | `SaveFlowSlotMetadata` | Can create a subclassed metadata type. |

## SaveFlowPipelineSignals

| Property | Default | Notes |
| --- | --- | --- |
| `enabled` | `true` | Disables signal bridge when false. |
| `listen_mode` | Owner Only | Owner, owner descendants, or all events. |
| `target` | empty | Optional target node path. |
