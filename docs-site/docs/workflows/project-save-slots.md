---
sidebar_position: 2
title: Project Save Slots
---

Most real games need more than one file write button.

SaveFlow Lite supports the baseline slot workflow:

- active slot index
- stable slot IDs
- display names
- typed metadata
- save cards
- manual saves
- autosave and checkpoint examples

The key idea is:

> storage identity is stable, UI naming is metadata.

## Slot ID vs Display Name

Use a stable slot ID for storage.

Use display metadata for UI.

This keeps sorting, loading, and deletion predictable while still letting the
player see names such as `Village Start` or `Forest Gate`.

Recommended pattern:

```text
slot_id: slot_1
display_name: Village Start
save_type: manual
location_name: Forest Gate
```

Use an integer slot index in gameplay/UI state, derive `slot_1`, `slot_2`, and
`slot_3` from it, and keep the human-readable name in metadata.

## Active Slot

The active slot is the slot your current play session writes to.

Manual save, autosave, and checkpoint behavior should normally write to the
active slot unless your game intentionally defines a different policy.

This means autosave should not write every visible card.
It should update the current slot unless your project has a separate autosave
slot design.

In the recommended template, the Esc menu writes the main scene data.
Room pads write the active subscene slot.
That split keeps project location data separate from room-local payloads.

![Recommended Project Workflow main save menu showing main scene data and active room slot context](/img/saveflow/screenshots/project-workflow-main-save-menu.png)

## Save Cards

Save cards are lightweight summaries for UI.

Use them to build continue/load/save menus without loading the full gameplay
payload for every slot.

Save cards usually show:

- slot index
- display name
- chapter
- location
- playtime
- save type
- compatibility status

## Manual Save, Autosave, Checkpoint

Manual save is a player-selected write to the active or selected slot.

Autosave is a gameplay event that writes without opening a save menu.
Use it for transitions, safe moments, and major progress points.

Checkpoint is a gameplay recovery marker.
It usually records where the player should resume after failure, then writes the
active slot.

In Lite, these are workflows over the same baseline slot model.
They are not separate storage systems.
