using System;

using Godot;
using Godot.Collections;

namespace SaveFlow.DotNet;

/// <summary>
/// Normalized result wrapper for SaveFlow GDScript calls from C#.
/// </summary>
public sealed class SaveFlowCallResult
{
	public bool Ok { get; }
	public int ErrorCode { get; }
	public string ErrorKey { get; }
	public string ErrorMessage { get; }
	public Variant Data { get; }
	public Dictionary Meta { get; }
	public string MethodName { get; }

	private SaveFlowCallResult(
		bool ok,
		int errorCode,
		string errorKey,
		string errorMessage,
		Variant data,
		Dictionary meta,
		string methodName
	)
	{
		Ok = ok;
		ErrorCode = errorCode;
		ErrorKey = errorKey;
		ErrorMessage = errorMessage;
		Data = data;
		Meta = meta;
		MethodName = methodName;
	}

	public static SaveFlowCallResult RuntimeNotAvailable(string methodName)
		=> new(
			ok: false,
			errorCode: -1,
			errorKey: "SAVEFLOW_RUNTIME_NOT_AVAILABLE",
			errorMessage: "SaveFlow runtime singleton '/root/SaveFlow' is unavailable.",
			data: default,
			meta: new Dictionary(),
			methodName: methodName
		);

	public static SaveFlowCallResult InvalidResultShape(string methodName)
		=> new(
			ok: false,
			errorCode: -2,
			errorKey: "SAVEFLOW_INVALID_RESULT_SHAPE",
			errorMessage: "SaveFlow call did not return a SaveResult object.",
			data: default,
			meta: new Dictionary(),
			methodName: methodName
		);

	public static SaveFlowCallResult FromException(string methodName, Exception exception)
		=> new(
			ok: false,
			errorCode: -3,
			errorKey: "SAVEFLOW_CALL_EXCEPTION",
			errorMessage: exception.Message,
			data: default,
			meta: new Dictionary(),
			methodName: methodName
		);

	public static SaveFlowCallResult FromVariant(string methodName, Variant raw)
	{
		if (raw.VariantType != Variant.Type.Object)
			return InvalidResultShape(methodName);

		var resultObj = raw.AsGodotObject();
		if (resultObj is null)
			return InvalidResultShape(methodName);

		var ok = resultObj.Get("ok").AsBool();
		var errorCode = resultObj.Get("error_code").AsInt32();
		var errorKey = resultObj.Get("error_key").AsString();
		var errorMessage = resultObj.Get("error_message").AsString();
		var data = resultObj.Get("data");

		var metaValue = resultObj.Get("meta");
		var meta = metaValue.VariantType == Variant.Type.Dictionary
			? metaValue.AsGodotDictionary()
			: new Dictionary();

		return new SaveFlowCallResult(
			ok: ok,
			errorCode: errorCode,
			errorKey: errorKey,
			errorMessage: errorMessage,
			data: data,
			meta: meta,
			methodName: methodName
		);
	}
}
