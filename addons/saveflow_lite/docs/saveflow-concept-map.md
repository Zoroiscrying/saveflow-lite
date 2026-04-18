# SaveFlow Concept Map

This document is a fast visual explanation of the current SaveFlow Lite model.

## 1. The three main save paths

```mermaid
flowchart LR
    A["Gameplay Object"] --> B["SaveFlowNodeSource"]
    C["System / Model / Table"] --> D["SaveFlowDataSource"]
F["Runtime Entity Set"] --> G["SaveFlowEntityCollectionSource"]
G --> H["SaveFlowEntityFactory"]
```

Interpretation:
- if the thing is "this object", use `SaveFlowNodeSource`
- if the thing is "this system model", use `SaveFlowDataSource`
- if the thing is "this changing entity set", use `SaveFlowEntityCollectionSource + SaveFlowEntityFactory`

## 2. Node-centric object save

```mermaid
flowchart TD
    A["Player Prefab"] --> B["AnimationPlayer"]
    A --> C["SaveFlowNodeSource"]
    C --> D["Exported Fields"]
    C --> E["Built-In Serializers"]
    C --> F["Selected Child Participants"]
```

Interpretation:
- `SaveFlowNodeSource` is the main object-facing entry
- one node source can save the object's fields, built-ins, and selected child parts together

## 3. System state save

```mermaid
flowchart TD
    A["World State Model"] --> B["Custom SaveFlowDataSource"]
    B --> C["Save Graph / Scene Save"]
```

Interpretation:
- the gameplay system owns the runtime state
- the custom data source translates runtime state to save data
- the data source plugs directly into SaveFlow

## 4. Entity collection save

```mermaid
flowchart TD
A["Runtime Container"] --> B["SaveFlowEntityCollectionSource"]
    C["Entity Factory"] --> B
    B --> D["SaveFlow.restore_entities()"]
    D --> C
    C --> E["Spawn / Find / Apply Entity"]
```

Interpretation:
- the collection owns the runtime set
- the entity factory owns project-specific spawn/find/apply logic
- SaveFlow orchestrates restore without taking over the game's factory system

## 5. Runtime entity prefab structure

```mermaid
flowchart TD
    A["Enemy Prefab"] --> B["SaveFlowIdentity"]
    A --> C["SaveFlowNodeSource"]
    A --> D["SaveFlowScope (optional)"]
    D --> E["Core Source"]
    D --> F["Combat Source"]
    D --> G["Animation Source"]
```

Interpretation:
- `SaveFlowIdentity` answers "who is this entity?"
- the prefab owns its own save logic
- use a local `SaveFlowScope` only when the entity has composite state

## 6. Save and load flow

```mermaid
sequenceDiagram
    participant User as User Code
    participant SF as SaveFlow
    participant NS as NodeSource / DataSource / EntityCollectionSource
    participant FB as EntityFactory
    participant Slot as Slot File

    User->>SF: save_scene() / save_scope()
    SF->>NS: gather_save_data()
    NS-->>SF: payload
    SF->>Slot: write slot

    User->>SF: load_scene() / load_scope()
    SF->>Slot: read slot
    SF->>NS: apply_save_data()
    NS->>FB: restore runtime entities when needed
```

Interpretation:
- SaveFlow owns orchestration and file IO
- sources own data gathering / applying
- entity factories own project-specific runtime reconstruction
