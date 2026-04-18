# SaveFlow Zelda-Like Test Scenario

Updated: 2026-04-08

## Goal

Stress SaveFlow with a more realistic single-player action-adventure structure:
- player state with room switching
- animation playback state
- world state tables for loaded and unloaded rooms
- arrays, dictionaries, packed arrays, and set-like dictionaries
- dynamic room entities restored through `SaveFlowEntityCollectionSource + SaveFlowEntityFactory`

## Covered By

Runtime suite:
- `res://tests/runtime/saveflow_lite/saveflow_zelda_like_test.gd`

Main fixture roles:
- `zelda_player_state_fixture.gd`
  - player gameplay state
- `zelda_animation_source_fixture.gd`
  - animation playback state
- `zelda_room_registry_fixture.gd`
  - room/world table data for loaded and unloaded rooms
- `zelda_room_data_source_fixture.gd`
  - system-state bridge into the graph
- `zelda_room_entity_fixture.gd`
  - current-room runtime entity shape
- `zelda_room_entity_factory_fixture.gd`
  - entity factory seam for restoring missing room entities

## What This Scenario Validates

1. `SaveFlowNodeSource` is the main path for authored node objects and built-in engine state.
2. `SaveFlowSource` is still needed for behavior-heavy state like animation playback.
3. `SaveFlowDataSource` is the correct path for unloaded-room or world-table state.
4. `SaveFlowEntityCollectionSource` plus an entity factory can restore current-room runtime entities without fighting project factories.

## Why This Matters

This is closer to the real shape of a commercial save problem than the earlier minimal fixtures:
- state is split across player, world tables, and runtime entities
- not all important state exists as plain exported fields
- not all important state exists in the currently loaded room
- one load must repair authored state and respawn missing room entities in one pass
