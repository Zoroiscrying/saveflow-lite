# SaveFlow C# Runtime Layout

The C# runtime helpers live under the `SaveFlow.DotNet` namespace. Folder names
describe responsibility only; they do not change the public namespace or the
classes users import.

## Folders

- `client`
  Thin runtime wrapper around the `SaveFlow` autoload.
  Start here when C# gameplay code wants to call save/load APIs directly.

- `sources`
  Direct C# SaveGraph source bases.
  Use `SaveFlowTypedStateSource` for one typed DTO/record owned by a SaveGraph
  node, or `SaveFlowEncodedSource` when the project owns a custom encoded
  payload such as a binary serializer.

- `payloads`
  Payload contracts, encoded payload helpers, and low-boilerplate reflection
  helpers. Prefer direct sources for normal project save data. Use
  `SaveFlowTypedResource`, `SaveFlowTypedRefCounted`, or `SaveFlowTypedPayload`
  for small or low-frequency state where reflection convenience is acceptable.

- `slots`
  Active-slot workflow helpers, typed slot metadata, and save-list card data.
  Use these when building Continue/Load/Save menus without repeated string-key
  metadata glue.

- `entities`
  Runtime entity descriptor helpers for `persistent_id`, `type_key`, payload,
  and extra project-owned descriptor fields.

## Godot C# Script Move Workflow

Godot stores script path metadata for C# `GodotObject`-derived classes in the
compiled assembly. After moving C# Godot script files, rebuild before asking
Godot to import or validate the project:

```powershell
dotnet build PluginDevelopment.csproj
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\import_project.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\godot_cli.ps1 --headless --quit --check-only
```

If import runs before the rebuild, Godot may temporarily look for the old
`res://` script path even when no source file references it anymore.

## Script Registration Boundary

Keep Godot script base classes non-generic. For typed C# save state, derive from
`SaveFlowTypedStateSource` and initialize the state with `InitializeSaveFlowState`
and a `JsonTypeInfo<TState>`. This avoids Godot C# script reload collisions while
keeping save data strongly typed in user code.

Godot editor icons are applied only to C# `GodotObject`-derived script bases that
are registered with `[GlobalClass, Icon("res://...")]`. Plain C# helper classes,
static helpers, attributes, and interfaces are not Godot editor script classes
and should stay icon-free.
