# SaveFlow Recommended Template Regression Checklist

Use this checklist when changing:

- `recommended_template`
- `Quick Access`
- `SaveFlow Settings`
- `DevSaveManager`

The goal is to keep the recommended path small and project-like.

## Editor Entry Points

### SaveFlow Quick Access

- the panel instantiates without script errors
- `popup_quick_access()` still works
- `Open Recommended Template` emits the project workflow scene path
- `Open Pipeline Signals Demo` emits the pipeline notification scene path
- `Open DevSaveManager` still emits the expected signal
- `Open SaveFlow Settings` still emits the expected signal

### SaveFlow Settings

- the panel instantiates without script errors
- `Open Quick Access` emits the expected request
- `Open DevSaveManager` emits the expected request
- `Setup Health` refresh still works

### SaveFlow DevSaveManager

- the panel instantiates without script errors
- `refresh_now()` does not error
- the search field still exists and can receive focus

## Recommended Template

### Project Workflow

- the hub scene opens without errors
- the hub has authored portals for forest and dungeon rooms
- Esc opens the main save menu
- main-scene save/load restores the current location
- entering a room instantiates an authored room scene
- each room has a visible save pad, load pad, mutate pad, and exit pad
- room save/load writes only that room slot
- room reset clears runtime coins and restores authored defaults

### Pipeline Notifications

- the pipeline notification scene opens without errors
- `SaveGraph/PipelineSignals` exists under the scope
- each typed data source has its own child `SaveFlowPipelineSignals`
- saving emits source-level notifications before the final `Data Saved!` message
- loading emits source-level loaded notifications before the final loaded message

### SaveFlow Components

- room `WorldSource` is `SaveFlowTypedDataSource` and saves `TemplateRoomSaveData`
- room `PlayerSource` targets `RoomPlayer` and includes `AnimationPlayer`
- room `RuntimeCoinCollectionSource` targets `RuntimeCoins`
- room `RuntimeCoinFactory` uses `SaveFlowPrefabEntityFactory`
- no standalone case-manager scripts are required for NodeSource/DataSource/EntityCollection examples
- no room-state dictionary adapter script should be reintroduced unless the example truly needs custom gather/apply code

### Directory Shape

- `recommended_template/gameplay` should expose `project_workflow` and `pipeline_notifications` only
- standalone case scenes should not return to `recommended_template/scenes/cases`
- legacy starter/launcher scenes should not be reintroduced as first-class template entry points

## Smoke Test Rule

Every automated regression test should prefer:

- scene opens
- button press
- status text
- item count
- signal emission

Avoid making layout, pixel size, or dock placement part of the regression bar
unless the bug is specifically about layout behavior.
