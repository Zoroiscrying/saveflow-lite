## Typed save-card data for in-game continue/load/save UIs.
##
## This is intentionally only a UI-facing summary object. It does not own save
## or load behavior; game code still decides which SaveFlow entry point to call.
@icon("res://addons/saveflow_lite/icons/components/saveflow_slot_metadata_icon.svg")
class_name SaveFlowSlotCard
extends Resource

@export var slot_index := -1
@export var slot_id := ""
@export var display_name := ""
@export var save_type := ""
@export var chapter_name := ""
@export var location_name := ""
@export var playtime_seconds := 0
@export var difficulty := ""
@export var thumbnail_path := ""
@export var saved_at_unix := 0
@export var saved_at_iso := ""
@export var exists := false
@export var is_active := false
@export var compatible := true
@export var compatibility_reasons := PackedStringArray()
var custom_metadata: Dictionary = {}
var raw_summary: Dictionary = {}


static func from_summary(
	slot_index_value: int,
	fallback_slot_id: String,
	fallback_display_name: String,
	summary: Dictionary = {},
	active_slot_index: int = -1
) -> Resource:
	var card_script: Script = load("res://addons/saveflow_core/runtime/types/saveflow_slot_card.gd")
	var card: Resource = card_script.new()
	card.set("slot_index", slot_index_value)
	card.set("slot_id", fallback_slot_id)
	card.set("display_name", fallback_display_name)
	card.set("is_active", slot_index_value == active_slot_index)
	if not summary.is_empty():
		card.call("apply_summary", summary)
	return card


func apply_summary(summary: Dictionary) -> void:
	raw_summary = summary.duplicate(true)
	exists = true
	if summary.has("slot_id"):
		slot_id = String(summary["slot_id"])
	if summary.has("display_name"):
		display_name = String(summary["display_name"])
	if summary.has("save_type"):
		save_type = String(summary["save_type"])
	if summary.has("chapter_name"):
		chapter_name = String(summary["chapter_name"])
	if summary.has("location_name"):
		location_name = String(summary["location_name"])
	if summary.has("playtime_seconds"):
		playtime_seconds = int(summary["playtime_seconds"])
	if summary.has("difficulty"):
		difficulty = String(summary["difficulty"])
	if summary.has("thumbnail_path"):
		thumbnail_path = String(summary["thumbnail_path"])
	if summary.has("saved_at_unix"):
		saved_at_unix = int(summary["saved_at_unix"])
	if summary.has("saved_at_iso"):
		saved_at_iso = String(summary["saved_at_iso"])
	custom_metadata = Dictionary(summary.get("custom_metadata", {})).duplicate(true)
	var compatibility_report := Dictionary(summary.get("compatibility_report", {}))
	compatible = bool(compatibility_report.get("compatible", true))
	compatibility_reasons = PackedStringArray(compatibility_report.get("reasons", PackedStringArray()))
	if custom_metadata.has("slot_index"):
		slot_index = int(custom_metadata["slot_index"])


func to_label_text() -> String:
	var active_marker := " [active]" if is_active else ""
	var state := "saved" if exists else "empty"
	var compatibility := "compatible" if compatible else "incompatible"
	return "%s%s\nIndex: #%d\nStorage key: %s\nState: %s | %s\nType: %s\nLocation: %s" % [
		display_name,
		active_marker,
		slot_index,
		slot_id,
		state,
		compatibility,
		save_type if not save_type.is_empty() else "<none>",
		location_name if not location_name.is_empty() else "<unknown>",
	]
