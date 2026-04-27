# SaveFlow Concept Map

This document is a fast visual explanation of the current SaveFlow Lite model.

## 1. The three main save paths

```mermaid
flowchart LR
    A["Gameplay Object"] --> B["SaveFlowNodeSource"]
    C["Typed System / Payload Provider"] --> D["SaveFlowTypedDataSource"]
    C2["C# Typed State"] --> D2["SaveFlowTypedStateSource"]
    E["Custom Table / Registry"] --> F["SaveFlowDataSource"]
    G["Runtime Entity Set"] --> H["SaveFlowEntityCollectionSource"]
    H --> I["SaveFlowEntityFactory"]
```

Interpretation:
- if the thing is "this object", use `SaveFlowNodeSource`
- if the thing is "this typed system model or payload provider", use `SaveFlowTypedDataSource`
- if the thing is "this C# typed state object", use `SaveFlowTypedStateSource`
- if the thing needs custom table/registry translation, use `SaveFlowDataSource`
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
    A["World State Typed Data"] --> B["SaveFlowTypedDataSource"]
    C["C# Room State"] --> C2["SaveFlowTypedStateSource"]
    D["Registry / Service"] --> F["Custom SaveFlowDataSource"]
    B --> G["Save Graph / Scene Save"]
    C2 --> G
    F --> G
```

Interpretation:
- the gameplay system owns the runtime state
- typed data source converts exported fields to save data
- typed state source lets C# DTO state live directly as a save graph source
- custom data source translates runtime state when field persistence is not enough
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
    participant NS as NodeSource / TypedDataSource / DataSource / EntityCollectionSource
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
