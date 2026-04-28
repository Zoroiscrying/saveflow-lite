---
sidebar_position: 1
title: Save Graph
---

A Save Graph is the scene-authored map of what SaveFlow should save.

It is not a separate visual graph editor.
It is the set of SaveFlow nodes already visible in the Godot scene tree.

## What A Save Graph Contains

A normal Lite graph contains:

- Sources that own payloads
- Scopes that group Sources into domains
- entity factories that recreate runtime objects
- pipeline signal bridges that observe save/load lifecycle events

Example:

```text
GameRoot
|- SaveGraph
|  |- ProfileScope
|  |  |- ProfileStateSource
|  |- RoomScope
|  |  |- PlayerSource
|  |  |- RoomStateSource
|  |  |- RuntimeCoinsSource
|  |  |- CoinFactory
```

The graph answers:

- which data is saved?
- which key stores each payload?
- which domain is being saved or loaded?
- which runtime factory is responsible for restore?

## Source Keys

Every Source needs a stable key inside its active graph.

The key is how SaveFlow matches saved payloads back to scene Sources during
load.

Good keys:

- `player`
- `room_state`
- `runtime_coins`
- `settings`

Bad keys:

- empty strings
- temporary node names
- duplicated keys in the same graph
- keys derived from data that changes during play

## Save Data vs Restore Contract

Saving answers:

> What payload did this Source write?

Loading also needs a restore contract:

> Is the expected scene, Scope, Source, and runtime target present right now?

Lite handles the baseline contract for currently loaded scene content.
If the target scene or domain is not loaded, Lite should report that clearly.
Full multi-scene staged restore belongs to Pro orchestration.

## The Three Common Calls

Use `save_scene()` when the current scene has a group-based save graph.

Use `save_scope()` when one domain should be saved or loaded directly.

Use `save_data()` when you already own a complete payload and only need storage.

Most Godot projects should start with `save_scope()` for real gameplay domains
because it keeps the save boundary explicit.
