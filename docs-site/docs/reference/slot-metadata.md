---
sidebar_position: 5
title: Slot Metadata
---

Slot metadata is the typed summary stored with a save slot.

Use it for menus, compatibility checks, and player-facing save cards.

## SaveFlowSlotMetadata Fields

| Field | Type | Purpose |
| --- | --- | --- |
| `slot_id` | `String` | Stable storage key. |
| `display_name` | `String` | Player-facing name. |
| `save_type` | `String` | `manual`, `autosave`, `checkpoint`, or project-specific value. |
| `chapter_name` | `String` | Chapter or campaign label. |
| `location_name` | `String` | Current area/room label. |
| `playtime_seconds` | `int` | Total playtime shown in save UI. |
| `difficulty` | `String` | Optional difficulty label. |
| `thumbnail_path` | `String` | Optional screenshot/thumbnail path. |
| `created_at_unix` | `int` | Creation timestamp. |
| `created_at_iso` | `String` | Creation timestamp string. |
| `saved_at_unix` | `int` | Last save timestamp. |
| `saved_at_iso` | `String` | Last save timestamp string. |
| `scene_path` | `String` | Scene path captured for restore safety. |
| `project_title` | `String` | Project metadata. |
| `game_version` | `String` | Game build/version metadata. |
| `data_version` | `int` | Data version metadata. |
| `save_schema` | `String` | Schema label used by compatibility checks. |

Extra fields should be basic Variant-safe data or typed SaveFlow data.
Do not store heavy runtime objects in slot metadata.

## Metadata Methods

```gdscript
metadata.apply_extra(extra: Dictionary) -> void
metadata.apply_patch(meta_patch: Dictionary) -> void
metadata.get_saveflow_authoring_warnings() -> PackedStringArray
metadata.get_extra_field_names() -> PackedStringArray
metadata.set_field(field_id: String, value: Variant) -> void
```

Use `set_field()` when code can target either a built-in metadata field or a
custom metadata key.

## SaveFlowSlotWorkflow Methods

```gdscript
slot_workflow.select_slot_index(slot_index: int) -> String
slot_workflow.active_slot_id() -> String
slot_workflow.set_slot_id_override(slot_index: int, slot_id: String) -> void
slot_workflow.clear_slot_id_overrides() -> void
slot_workflow.slot_id_for_index(slot_index: int) -> String
slot_workflow.fallback_display_name_for_index(slot_index: int) -> String
slot_workflow.build_active_slot_metadata(...) -> SaveFlowSlotMetadata
slot_workflow.build_slot_metadata(slot_index: int, ...) -> SaveFlowSlotMetadata
slot_workflow.build_empty_card(slot_index: int) -> Resource
slot_workflow.build_card_for_index(slot_index: int, summary: Dictionary = {}) -> Resource
slot_workflow.build_cards_for_indices(slot_indices: PackedInt32Array, summaries: Array = []) -> Array
```

## SaveFlowSlotCard Fields

| Field | Type | Purpose |
| --- | --- | --- |
| `slot_index` | `int` | UI/order index. |
| `slot_id` | `String` | Stable storage key. |
| `display_name` | `String` | Player-facing name. |
| `save_type` | `String` | Save category. |
| `chapter_name` | `String` | Chapter label. |
| `location_name` | `String` | Location label. |
| `playtime_seconds` | `int` | Playtime display data. |
| `difficulty` | `String` | Difficulty label. |
| `thumbnail_path` | `String` | Thumbnail path. |
| `saved_at_unix` | `int` | Timestamp. |
| `saved_at_iso` | `String` | Timestamp string. |
| `exists` | `bool` | Whether the slot exists. |
| `is_active` | `bool` | Whether this card is the selected active slot. |
| `compatible` | `bool` | Compatibility result. |
| `compatibility_reasons` | `PackedStringArray` | Human-readable compatibility issues. |

Update a card from a summary:

```gdscript
card.apply_summary(summary)
```
