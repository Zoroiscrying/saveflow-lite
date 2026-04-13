class_name SaveResult
extends RefCounted

var ok: bool = false
var error_code: int = SaveError.UNKNOWN
var error_key: String = "UNKNOWN"
var error_message: String = ""
var data: Variant = null
var meta: Dictionary = {}
