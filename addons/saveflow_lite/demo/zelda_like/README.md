# Zelda-Like Demo Structure

This demo is split into three parts so the SaveFlow integration surface is easy to inspect.

## scenes

Files in `scenes/` are authored scene resources:
- `zelda_like_sandbox.tscn`
- `rooms/`
- `prefabs/`

This folder answers:
- what the playable demo scene looks like
- what a room scene looks like
- what a runtime entity prefab looks like

## gameplay

Files in `gameplay/` are game-side runtime logic and state models:
- player movement and combat
- room stage rendering and collision helpers
- room markers and spawn markers
- entity runtime behavior
- world and room state models

These files represent code a game would still need even without SaveFlow.

## saveflow

Files in `saveflow/` are the explicit SaveFlow integration layer:
- node sources, sources
- custom data sources
- runtime restore scope
- entity factory bridge

These files represent the SaveFlow-specific work needed to connect the game to the save graph.

Current Zelda-like integration demonstrates three SaveFlow paths together:
- `SaveFlowNodeSource` for player exported gameplay fields plus built-in node state such as `Node2D` transform and `AnimationPlayer`
- one custom `SaveFlowDataSource` for world-state import/export
- `SaveFlowEntityCollectionSource + SaveFlowEntityFactory` for runtime entity restore

The runtime room entity set is also the main restore-policy example:
- `Create Missing` is the normal room-load path because missing runtime actors should be recreated
- `Apply Existing` is useful for partial refresh workflows where the room already owns the full runtime set
- `Clear And Restore` is useful when stale room actors must never survive a load

The demo keeps its SaveFlow-specific code in `saveflow/`, but avoids empty wrapper nodes when the base class is already the real user-facing path.

## Reading The Integration Cost

If you want to see "how much SaveFlow code does this demo need?", inspect `saveflow/` first.

If you want to see "what does the game itself need regardless of the save plugin?", inspect `gameplay/` and `scenes/`.
