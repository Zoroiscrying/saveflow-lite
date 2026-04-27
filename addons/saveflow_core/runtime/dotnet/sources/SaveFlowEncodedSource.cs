using System.Text;

using Godot;

using GodotArray = Godot.Collections.Array;
using GodotDictionary = Godot.Collections.Dictionary;

namespace SaveFlow.DotNet;

/// <summary>
/// Direct C# SaveFlow source for project-owned encoded payloads.
/// Use this when a source needs a custom binary/JSON encoder instead of the
/// default SaveFlowTypedStateSource JSON state lifecycle.
///
/// Keep this GodotObject-derived script base non-generic and in its same-name
/// file. Generic DTOs and encoder helpers are normal C# and are safe; generic
/// Node/Resource script bases can collide with Godot's editor reload map.
/// </summary>
[GlobalClass, Icon("res://addons/saveflow_lite/icons/components/saveflow_data_source_icon.svg")]
public abstract partial class SaveFlowEncodedSource : Node, ISaveFlowEncodedPayloadProvider
{
	/// <summary>
	/// SaveGraph key for this source, such as "room_state". This identifies the
	/// source's position in the graph and is separate from the payload schema,
	/// which identifies the encoded data shape inside the source.
	/// </summary>
	[Export] public string SourceKey { get; set; } = "";

	/// <summary>
	/// Master switch for this source. Disabled sources are skipped by both save
	/// and load.
	/// </summary>
	[Export] public bool Enabled { get; set; } = true;

	/// <summary>
	/// Allows save-only disabling while keeping load enabled for old payloads.
	/// </summary>
	[Export] public bool SaveEnabled { get; set; } = true;

	/// <summary>
	/// Allows load-only disabling while still writing current data.
	/// </summary>
	[Export] public bool LoadEnabled { get; set; } = true;

	/// <summary>
	/// Optional ordering hint used by SaveGraph runners. Lower phases run first.
	/// Use it only when one source must be restored before another.
	/// </summary>
	[Export] public int Phase { get; set; }

	/// <summary>
	/// Version for this source's payload shape. SaveFlow records it with the
	/// payload so compatibility checks and future migrations can tell whether an
	/// old save needs an upgrade.
	/// </summary>
	[Export] public int DataVersion { get; set; } = 1;

	protected virtual string SaveFlowPlanSummary => "C# encoded payload";
	protected virtual string SaveFlowSourceKind => "data";
	protected virtual string SaveFlowContractLabel => "SaveFlowEncodedSource direct C# source";

	public string GetSaveKey()
		=> GetSourceKey();

	public string GetSourceKey()
	{
		if (!string.IsNullOrWhiteSpace(SourceKey))
			return SourceKey.Trim();
		return ToSnakeCase(Name.ToString());
	}

	public void SetSourceKey(string sourceKey)
		=> SourceKey = sourceKey;

	public bool IsSourceEnabled()
		=> Enabled;

	public bool CanSaveSource()
		=> Enabled && SaveEnabled;

	public bool CanLoadSource()
		=> Enabled && LoadEnabled;

	public int GetPhase()
		=> Phase;

	public virtual void BeforeSave(GodotDictionary context)
	{
	}

	public virtual void BeforeLoad(Variant payload, GodotDictionary context)
	{
	}

	public virtual void AfterLoad(Variant payload, GodotDictionary context)
	{
	}

	public GodotDictionary GatherSaveData()
		=> ToSaveFlowEncodedPayload();

	public void ApplySaveData(Variant payload, GodotDictionary context)
	{
		if (payload.VariantType != Variant.Type.Dictionary)
			return;
		ApplySaveFlowEncodedPayload(payload.AsGodotDictionary());
	}

	public abstract GodotDictionary ToSaveFlowEncodedPayload();

	public abstract void ApplySaveFlowEncodedPayload(GodotDictionary payload);

	public abstract GodotDictionary GetSaveFlowPayloadInfo();

	public virtual GodotDictionary DescribeSource()
		=> new()
		{
			["source_key"] = GetSourceKey(),
			["enabled"] = IsSourceEnabled(),
			["save_enabled"] = CanSaveSource(),
			["load_enabled"] = CanLoadSource(),
			["phase"] = GetPhase(),
			["kind"] = SaveFlowSourceKind,
			["data_version"] = DataVersion,
			["plan"] = DescribeDataPlan(),
		};

	public virtual GodotDictionary DescribeDataPlan()
	{
		var payloadInfo = GetSaveFlowPayloadInfo();
		return new GodotDictionary
		{
			["valid"] = true,
			["reason"] = "",
			["source_key"] = GetSourceKey(),
			["data_version"] = DataVersion,
			["phase"] = GetPhase(),
			["enabled"] = IsSourceEnabled(),
			["save_enabled"] = CanSaveSource(),
			["load_enabled"] = CanLoadSource(),
			["summary"] = BuildPlanSummary(payloadInfo),
			["sections"] = ResolveSections(payloadInfo),
			["details"] = new GodotDictionary
			{
				["source_type"] = GetType().Name,
				["payload_info"] = payloadInfo,
				["contract"] = SaveFlowContractLabel,
			},
		};
	}

	public string get_save_key()
		=> GetSaveKey();

	public string get_source_key()
		=> GetSourceKey();

	public void set_source_key(string sourceKey)
		=> SetSourceKey(sourceKey);

	public bool is_source_enabled()
		=> IsSourceEnabled();

	public bool can_save_source()
		=> CanSaveSource();

	public bool can_load_source()
		=> CanLoadSource();

	public int get_phase()
		=> GetPhase();

	public void before_save(GodotDictionary context)
		=> BeforeSave(context);

	public void before_load(Variant payload, GodotDictionary context)
		=> BeforeLoad(payload, context);

	public void after_load(Variant payload, GodotDictionary context)
		=> AfterLoad(payload, context);

	public GodotDictionary gather_save_data()
		=> GatherSaveData();

	public void apply_save_data(Variant payload, GodotDictionary context)
		=> ApplySaveData(payload, context);

	public GodotDictionary describe_source()
		=> DescribeSource();

	public GodotDictionary describe_data_plan()
		=> DescribeDataPlan();

	public GodotDictionary to_saveflow_encoded_payload()
		=> ToSaveFlowEncodedPayload();

	public void apply_saveflow_encoded_payload(GodotDictionary payload)
		=> ApplySaveFlowEncodedPayload(payload);

	public GodotDictionary get_saveflow_payload_info()
		=> GetSaveFlowPayloadInfo();

	private string BuildPlanSummary(GodotDictionary payloadInfo)
	{
		var schema = StringFromPayloadInfo(payloadInfo, "schema");
		if (!string.IsNullOrEmpty(schema))
			return $"{SaveFlowPlanSummary}: {schema}";
		return SaveFlowPlanSummary;
	}

	private static string StringFromPayloadInfo(GodotDictionary payloadInfo, string key)
	{
		if (!payloadInfo.TryGetValue(key, out var value))
			return "";
		return StringFromVariant(value);
	}

	private static string StringFromVariant(Variant value)
	{
		return value.VariantType == Variant.Type.Nil ? "" : value.AsString();
	}

	private static GodotArray ResolveSections(GodotDictionary payloadInfo)
	{
		if (payloadInfo.TryGetValue(SaveFlowEncodedPayload.SectionsKey, out var sectionsVariant)
			&& sectionsVariant.VariantType == Variant.Type.Array)
			return sectionsVariant.AsGodotArray();

		return new GodotArray();
	}

	private static string ToSnakeCase(string value)
	{
		if (string.IsNullOrEmpty(value))
			return value;

		var builder = new StringBuilder(value.Length + 8);
		for (var i = 0; i < value.Length; i++)
		{
			var current = value[i];
			var previous = i > 0 ? value[i - 1] : '\0';
			var next = i + 1 < value.Length ? value[i + 1] : '\0';
			var shouldSplit = i > 0
				&& char.IsUpper(current)
				&& (char.IsLower(previous) || char.IsDigit(previous) || char.IsLower(next));
			if (shouldSplit)
				builder.Append('_');
			builder.Append(char.ToLowerInvariant(current));
		}
		return builder.ToString();
	}
}
