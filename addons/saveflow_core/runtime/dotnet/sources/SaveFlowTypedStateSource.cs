using System;
using System.Text.Json;
using System.Text.Json.Serialization.Metadata;

using Godot;

using GodotArray = Godot.Collections.Array;
using GodotDictionary = Godot.Collections.Dictionary;

namespace SaveFlow.DotNet;

public enum SaveFlowStatePayloadEncoding
{
	JsonText = 0,
	JsonBytes = 1,
}

/// <summary>
/// Direct C# SaveFlow source for one typed state object.
/// Add a derived node directly under a SaveFlowScope/SaveGraph, provide a
/// source-generated JsonTypeInfo, and SaveFlow will gather/apply it without a
/// separate GDScript SaveFlowTypedDataSource target.
///
/// JsonTypeInfo is required by design: SaveFlowTypedStateSource uses
/// System.Text.Json source generation instead of runtime reflection. That keeps
/// DTO serialization type-checked, AOT/export friendly, and predictable for
/// frequently saved gameplay state while letting SaveFlow treat the result as
/// one encoded payload.
///
/// Keep this script base non-generic and in its same-name file. Generic DTOs and
/// JsonTypeInfo&lt;T&gt; are safe; generic Node script bases can collide with Godot's
/// C# editor reload registration.
/// </summary>
[GlobalClass, Icon("res://addons/saveflow_lite/icons/components/saveflow_typed_data_source_icon.svg")]
public abstract partial class SaveFlowTypedStateSource : SaveFlowEncodedSource
{
	private JsonTypeInfo? _registeredStateTypeInfo;

	/// <summary>
	/// Controls how the same typed state is written into the SaveFlow payload.
	/// JsonText is easier to inspect in editor/debug builds; JsonBytes stores
	/// the same JSON as bytes while keeping the same DTO and load behavior.
	/// </summary>
	[Export] public SaveFlowStatePayloadEncoding PayloadEncoding { get; set; } = SaveFlowStatePayloadEncoding.JsonText;

	/// <summary>
	/// Return the source-generated JSON metadata for the DTO this source saves.
	/// Most sources do not need to override this; call InitializeSaveFlowState
	/// once in the constructor with MyJsonContext.Default.MySaveState instead.
	/// Override only when the type info is naturally owned by the subclass.
	/// </summary>
	protected virtual JsonTypeInfo SaveFlowStateTypeInfo
		=> _registeredStateTypeInfo
			?? throw new InvalidOperationException(
				$"{GetType().Name} must call InitializeSaveFlowState(initialState, jsonTypeInfo) "
				+ "or override SaveFlowStateTypeInfo.");

	/// <summary>
	/// Stable identity for this payload's data shape. By default this uses the
	/// DTO full name from JsonTypeInfo, which is enough for demos and prototypes.
	/// This is not the SaveGraph source key; it describes what kind of data lives
	/// inside the encoded payload and is used for compatibility checks,
	/// diagnostics, and future migration routing.
	/// Prefer a project-owned stable string over GetType().FullName if old saves
	/// must survive class or namespace renames.
	/// </summary>
	protected virtual string SaveFlowPayloadSchema => SaveFlowStateTypeInfo.Type.FullName ?? SaveFlowStateTypeInfo.Type.Name;

	/// <summary>
	/// Human-readable summary of the main business sections inside the payload.
	/// By default this is generated from JsonTypeInfo.Properties, so the names
	/// match the JSON field names that System.Text.Json will actually write.
	/// Override only when you want broader business groups or custom wording.
	/// Sections do not control serialization and are not a field whitelist; the
	/// DTO and JsonTypeInfo decide what is saved. SaveFlow uses sections only for
	/// inspector previews, setup health, validator messages, and future
	/// compatibility/migration reports.
	/// </summary>
	protected virtual GodotArray? SaveFlowPayloadSections => BuildPayloadSectionsFromTypeInfo();

	/// <summary>
	/// Current in-memory state object captured on save and replaced on load.
	/// Most sources wrap this with a small typed property that calls
	/// GetSaveFlowState&lt;T&gt;() and SetSaveFlowState(...).
	/// </summary>
	protected virtual object? SaveFlowState { get; set; }
	protected override string SaveFlowPlanSummary => "C# typed state";
	protected override string SaveFlowContractLabel => "SaveFlowTypedStateSource direct C# source";

	protected virtual object? CaptureSaveState()
		=> SaveFlowState;

	protected virtual void ApplySaveState(object? state)
	{
		SaveFlowState = state;
		OnSaveFlowStateApplied(state);
	}

	protected virtual void OnSaveFlowStateApplied(object? state)
	{
	}

	/// <summary>
	/// Registers the source-generated DTO metadata and initial runtime state in
	/// one line. This is the recommended path because it avoids a property
	/// override while still using source-generated System.Text.Json metadata
	/// instead of runtime reflection.
	/// </summary>
	protected void InitializeSaveFlowState<TState>(TState state, JsonTypeInfo<TState> typeInfo)
	{
		_registeredStateTypeInfo = typeInfo ?? throw new ArgumentNullException(nameof(typeInfo));
		SaveFlowState = state;
	}

	protected TState GetSaveFlowState<TState>()
		=> SaveFlowState is TState state ? state : default!;

	protected void SetSaveFlowState<TState>(TState state)
		=> SaveFlowState = state;

	public override GodotDictionary ToSaveFlowEncodedPayload()
	{
		var state = CaptureSaveState();
		return PayloadEncoding switch
		{
			SaveFlowStatePayloadEncoding.JsonBytes => SaveFlowEncodedPayload.FromBytes(
				JsonSerializer.SerializeToUtf8Bytes(state, SaveFlowStateTypeInfo),
				SaveFlowEncodedPayload.EncodingJsonBytes,
				SaveFlowEncodedPayload.ContentTypeJson,
				SaveFlowPayloadSchema,
				DataVersion),
			_ => SaveFlowEncodedPayload.FromText(
				JsonSerializer.Serialize(state, SaveFlowStateTypeInfo),
				SaveFlowEncodedPayload.EncodingJson,
				SaveFlowEncodedPayload.ContentTypeJson,
				SaveFlowPayloadSchema,
				DataVersion),
		};
	}

	public override void ApplySaveFlowEncodedPayload(GodotDictionary payload)
	{
		var bytes = SaveFlowEncodedPayload.GetBytes(payload);
		if (bytes.Length > 0)
		{
			ApplySaveState(JsonSerializer.Deserialize(bytes, SaveFlowStateTypeInfo));
			return;
		}

		var text = SaveFlowEncodedPayload.GetText(payload);
		if (string.IsNullOrEmpty(text))
			return;
		ApplySaveState(JsonSerializer.Deserialize(text, SaveFlowStateTypeInfo));
	}

	public override GodotDictionary GetSaveFlowPayloadInfo()
		=> PayloadEncoding switch
		{
			SaveFlowStatePayloadEncoding.JsonBytes => SaveFlowEncodedPayload.BinaryInfo(
				SaveFlowPayloadSchema,
				DataVersion,
				SaveFlowPayloadSections,
				SaveFlowEncodedPayload.EncodingJsonBytes,
				SaveFlowEncodedPayload.ContentTypeJson),
			_ => SaveFlowEncodedPayload.JsonInfo(
				SaveFlowPayloadSchema,
				DataVersion,
				SaveFlowPayloadSections),
		};

	private GodotArray BuildPayloadSectionsFromTypeInfo()
	{
		var sections = new GodotArray();
		foreach (var property in SaveFlowStateTypeInfo.Properties)
		{
			if (!string.IsNullOrWhiteSpace(property.Name))
				sections.Add(property.Name);
		}
		return sections;
	}
}
