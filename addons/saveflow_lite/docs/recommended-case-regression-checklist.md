# SaveFlow Recommended Case Regression Checklist

Use this checklist when changing:

- `recommended_template` demo scenes
- `Quick Access`
- `SaveFlow Settings`
- `DevSaveManager`
- C# wrapper onboarding

The goal is not pixel-perfect UI verification. The goal is to catch broken
workflow links early.

## Editor Entry Points

### SaveFlow Settings

- the panel instantiates without script errors
- `Open Quick Access` emits the expected request
- `Open DevSaveManager` emits the expected request
- `Setup Health` refresh still works

### SaveFlow DevSaveManager

- the panel instantiates without script errors
- `refresh_now()` does not error
- the search field still exists and can receive focus

### SaveFlow Quick Access

- the panel instantiates without script errors
- `popup_quick_access()` still works
- `Open DevSaveManager` still emits the expected signal
- `Open SaveFlow Settings` still emits the expected signal
- `Open Case Launcher` still emits an `open_scene_requested` path

## Recommended Cases

### Case 1: SaveFlowNodeSource

- the scene opens without errors
- `Mutate` updates the state text
- `Save` succeeds
- `Load` succeeds

### Case 2: SaveFlowDataSource

- the scene opens without errors
- the scene auto-seeds or otherwise makes `Load` meaningful on first open
- `Mutate` updates system-owned state
- `Save` succeeds
- `Load` succeeds

### Case 3: SaveFlowEntityCollectionSource

- the scene opens without errors
- the initial runtime set is present
- `Spawn Runtime` increases runtime actor count
- `Mutate` changes all runtime actors, not only one
- `Load` restores the saved set with clear-and-restore behavior
- no duplicate-save-key failure occurs

### Case 4: SaveFlow C# Wrapper

- the scene opens without errors
- if the C# assembly is available, the scene reports ready state
- if the C# assembly is unavailable, the scene shows guidance instead of throwing runtime errors
- `StateLabel` always renders a meaningful state line

### Case 5: Slot Summary UI

- the scene opens without errors
- `Seed Sample Slots` creates three list rows
- selecting a row renders summary details
- `Load Selected Payload` appends payload details without null-instance errors

### Case 6: Autosave and Checkpoint Workflow

- the scene opens without errors
- `Door Transition -> Autosave` creates or refreshes a slot summary row
- `Shrine -> Checkpoint` creates or refreshes a slot summary row
- `Pause Menu -> Manual Save` creates or refreshes a slot summary row
- save gating can block saves without throwing runtime errors

### Case 7: In-Game Save/Load Panel

- the scene opens without errors
- the slot list renders all fixed slot rows
- `Continue Latest` succeeds when seeded slots exist
- `Save Selected` and overwrite flow remain reachable
- `Delete Selected` and confirmation flow remain reachable

## Smoke Test Rule

Every automated regression test should prefer:

- scene opens
- button press
- status text
- item count
- signal emission

Avoid making layout, pixel size, or dock placement part of the regression bar
unless the bug is specifically about layout behavior.
