@tool
extends VBoxContainer

const SaveFlowSaveManagerBusScript := preload("res://addons/saveflow_core/runtime/core/saveflow_save_manager_bus.gd")
const SaveFlowRuntimeScript := preload("res://addons/saveflow_core/runtime/core/save_flow.gd")
const PATH_UNAVAILABLE := "<unavailable>"
const FORMAT_JSON := 1
const FORMAT_BINARY := 2
const SCOPE_DEV := "dev"
const SCOPE_FORMAL := "formal"
const BACKUP_FILE_SUFFIX := ".bak"

const REFRESH_INTERVAL := 1.0
const STATUS_TIMEOUT_SECONDS := 3

enum SortMode {
	NAME_ASC,
	NAME_DESC,
	CREATED_NEWEST,
	CREATED_OLDEST,
	SAVED_NEWEST,
	SAVED_OLDEST,
}

var _content_scroll: ScrollContainer
var _content_root: VBoxContainer
var _search_edit: LineEdit
var _sort_option: OptionButton
var _new_name_edit: LineEdit
var _runtime_status_label: Label
var _request_status_label: Label
var _dev_list_box: VBoxContainer
var _formal_list_box: VBoxContainer
var _name_dialog: ConfirmationDialog
var _name_dialog_line: LineEdit
var _name_dialog_mode := ""
var _name_dialog_source := ""
var _name_dialog_scope := SCOPE_DEV
var _delete_dialog: ConfirmationDialog
var _delete_target := ""
var _delete_scope := SCOPE_DEV
var _refresh_timer := 0.0
var _request_status_hold_until_unix := 0
var _fallback_runtime: Node
var _expanded_entry_keys: Dictionary = {}


func _ready() -> void:
	_build_ui()
	_refresh_all()
	set_process(true)


func _process(delta: float) -> void:
	_refresh_timer += delta
	if _refresh_timer < REFRESH_INTERVAL:
		return
	_refresh_timer = 0.0
	_refresh_all()


func refresh_now() -> void:
	_refresh_all()


func focus_primary_input() -> void:
	if _search_edit == null or not is_instance_valid(_search_edit):
		return
	_search_edit.grab_focus()


func _build_ui() -> void:
	if _dev_list_box != null:
		return

	add_theme_constant_override("separation", 10)
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	_content_scroll = ScrollContainer.new()
	_content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_content_scroll)

	_content_root = VBoxContainer.new()
	_content_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_root.add_theme_constant_override("separation", 10)
	_content_scroll.add_child(_content_root)

	var title := Label.new()
	title.text = "SaveFlow DevSaveManager"
	title.add_theme_font_size_override("font_size", 18)
	_content_root.add_child(title)

	var description := Label.new()
	description.text = "Manage dev snapshots and formal slot saves side by side. Runtime save/load requests only target dev saves."
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.modulate = get_theme_color("font_placeholder_color", "Editor")
	_content_root.add_child(description)

	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 8)
	_content_root.add_child(toolbar)

	_search_edit = LineEdit.new()
	_search_edit.placeholder_text = "Search saves"
	_search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_edit.text_changed.connect(func(_value: String) -> void: _refresh_lists())
	toolbar.add_child(_search_edit)

	_sort_option = OptionButton.new()
	_sort_option.add_item("Name (A-Z)", SortMode.NAME_ASC)
	_sort_option.add_item("Name (Z-A)", SortMode.NAME_DESC)
	_sort_option.add_item("Created (Newest)", SortMode.CREATED_NEWEST)
	_sort_option.add_item("Created (Oldest)", SortMode.CREATED_OLDEST)
	_sort_option.add_item("Saved (Newest)", SortMode.SAVED_NEWEST)
	_sort_option.add_item("Saved (Oldest)", SortMode.SAVED_OLDEST)
	_sort_option.item_selected.connect(func(_index: int) -> void: _refresh_lists())
	toolbar.add_child(_sort_option)

	var refresh_button := Button.new()
	refresh_button.text = "Refresh"
	refresh_button.pressed.connect(_refresh_all)
	toolbar.add_child(refresh_button)

	var folder_bar := HBoxContainer.new()
	folder_bar.add_theme_constant_override("separation", 8)
	_content_root.add_child(folder_bar)

	var open_formal_folder_button := Button.new()
	open_formal_folder_button.text = "Open Formal Saves"
	open_formal_folder_button.pressed.connect(_open_formal_save_folder)
	folder_bar.add_child(open_formal_folder_button)

	var open_dev_folder_button := Button.new()
	open_dev_folder_button.text = "Open Dev Saves"
	open_dev_folder_button.pressed.connect(_open_dev_save_folder)
	folder_bar.add_child(open_dev_folder_button)

	var save_bar := HBoxContainer.new()
	save_bar.add_theme_constant_override("separation", 8)
	_content_root.add_child(save_bar)

	_new_name_edit = LineEdit.new()
	_new_name_edit.placeholder_text = "New dev save name"
	_new_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_bar.add_child(_new_name_edit)

	var save_button := Button.new()
	save_button.text = "Save Dev Runtime Snapshot"
	save_button.pressed.connect(_queue_save_request)
	save_bar.add_child(save_button)

	_runtime_status_label = Label.new()
	_runtime_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content_root.add_child(_runtime_status_label)

	_request_status_label = Label.new()
	_request_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_request_status_label.modulate = get_theme_color("font_placeholder_color", "Editor")
	_content_root.add_child(_request_status_label)

	var lists_split := HSplitContainer.new()
	lists_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lists_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lists_split.custom_minimum_size.y = 520
	_content_root.add_child(lists_split)

	lists_split.add_child(_build_scope_list_section("Dev Saves", SCOPE_DEV))
	lists_split.add_child(_build_scope_list_section("Formal Saves (Slot Index)", SCOPE_FORMAL))

	_name_dialog = ConfirmationDialog.new()
	_name_dialog.min_size = Vector2(420, 0)
	_name_dialog.confirmed.connect(_on_name_dialog_confirmed)
	add_child(_name_dialog)

	var name_dialog_box := VBoxContainer.new()
	name_dialog_box.add_theme_constant_override("separation", 8)
	_name_dialog.add_child(name_dialog_box)

	_name_dialog_line = LineEdit.new()
	name_dialog_box.add_child(_name_dialog_line)

	_delete_dialog = ConfirmationDialog.new()
	_delete_dialog.title = "Delete Save"
	_delete_dialog.confirmed.connect(_confirm_delete)
	add_child(_delete_dialog)


func _build_scope_list_section(title_text: String, scope: String) -> Control:
	var wrapper := VBoxContainer.new()
	wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.add_theme_constant_override("separation", 6)

	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 14)
	wrapper.add_child(title)

	if scope == SCOPE_FORMAL:
		var hint := Label.new()
		hint.text = "Formal list is index-based management only. Runtime Save/Load requests are disabled here."
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.modulate = get_theme_color("font_placeholder_color", "Editor")
		wrapper.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.add_child(scroll)

	var list_box := VBoxContainer.new()
	list_box.add_theme_constant_override("separation", 6)
	scroll.add_child(list_box)

	if scope == SCOPE_DEV:
		_dev_list_box = list_box
	else:
		_formal_list_box = list_box

	return wrapper


func _refresh_all() -> void:
	_refresh_runtime_status()
	_refresh_request_status()
	_refresh_lists()


func _refresh_runtime_status() -> void:
	var status := _read_runtime_status()
	var heartbeat_age := int(Time.get_unix_time_from_system()) - int(status.get("updated_at_unix", 0))
	var active := bool(status.get("runtime_available", false)) and heartbeat_age <= STATUS_TIMEOUT_SECONDS
	var bridge_name := String(status.get("bridge_name", "SaveFlow"))
	if active:
		_runtime_status_label.text = "Runtime bridge active: %s" % bridge_name
		_runtime_status_label.modulate = Color(0.35, 0.8, 0.45, 1.0)
	else:
		_runtime_status_label.text = "Runtime handler inactive. Save/load requests require a running game with SaveFlow available."
		_runtime_status_label.modulate = Color(0.85, 0.6, 0.3, 1.0)


func _refresh_request_status() -> void:
	var now_unix := int(Time.get_unix_time_from_system())
	if now_unix < _request_status_hold_until_unix:
		return
	var requests := Array(SaveFlowSaveManagerBusScript.read_requests().get("requests", []))
	if requests.is_empty():
		_request_status_label.text = "No runtime requests yet."
		return
	var latest: Dictionary = requests[requests.size() - 1]
	_request_status_label.text = "Last request: [%s] %s" % [String(latest.get("status", "pending")), String(latest.get("message", ""))]


func _refresh_lists() -> void:
	_refresh_scope_list(SCOPE_DEV)
	_refresh_scope_list(SCOPE_FORMAL)


func _refresh_scope_list(scope: String) -> void:
	var list_box := _get_list_box_for_scope(scope)
	for child in list_box.get_children():
		child.queue_free()

	var entries := _read_entries(scope)
	if entries.is_empty():
		var empty_label := Label.new()
		empty_label.modulate = get_theme_color("font_placeholder_color", "Editor")
		empty_label.text = "No dev saves found." if scope == SCOPE_DEV else "No formal slot saves found."
		list_box.add_child(empty_label)
		return

	for entry in entries:
		list_box.add_child(_build_row(entry, scope))


func _get_list_box_for_scope(scope: String) -> VBoxContainer:
	return _dev_list_box if scope == SCOPE_DEV else _formal_list_box


func _read_entries(scope: String) -> Array:
	var runtime := _get_editor_saveflow()
	var status := _read_runtime_status()
	var settings: SaveSettings
	var entries: Array = []

	if runtime != null:
		settings = _prepare_runtime_for_scope(runtime, scope, status)
		var list_result = runtime.list_slots()
		if list_result.ok:
			entries = _build_entries_from_slot_meta(Array(list_result.data))
		if scope == SCOPE_DEV and entries.is_empty():
			entries = _scan_entries_from_save_root(settings)
	else:
		# Runtime not available, use default settings and scan filesystem
		settings = _get_default_settings_for_scope(scope, status)
		entries = _scan_entries_from_save_root(settings)

	if entries.is_empty():
		return []

	for index in range(entries.size()):
		if not (entries[index] is Dictionary):
			continue
		entries[index] = _attach_entry_reports(Dictionary(entries[index]), settings, status, runtime)

	var search_text := _search_edit.text.strip_edges().to_lower()
	var filtered: Array = []
	for entry_variant in entries:
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		var entry_name := String(entry.get("name", ""))
		var display_name := String(entry.get("display_name", entry_name))
		var haystack := ("%s %s" % [entry_name, display_name]).to_lower()
		if not search_text.is_empty() and haystack.find(search_text) == -1:
			continue
		filtered.append(entry)

	filtered.sort_custom(_sort_entries)
	return filtered


func _prepare_runtime_for_scope(runtime: Node, scope: String, status: Dictionary) -> SaveSettings:
	if scope == SCOPE_DEV:
		return _sync_editor_dev_settings_from_status(runtime, status)
	return _sync_editor_runtime_settings_from_status(runtime, status)


func _build_entries_from_slot_meta(meta_entries: Array) -> Array:
	var entries: Array = []
	for meta_variant in meta_entries:
		if not (meta_variant is Dictionary):
			continue
		var meta: Dictionary = meta_variant
		entries.append(_entry_from_meta(meta))
	return entries


func _scan_entries_from_save_root(settings: SaveSettings) -> Array:
	if settings == null:
		return []
	if settings.save_root.is_empty():
		return []

	var entries: Array = []
	var expected_extensions := {
		settings.file_extension_json.to_lower(): FORMAT_JSON,
		settings.file_extension_binary.to_lower(): FORMAT_BINARY,
	}
	var directory := DirAccess.open(settings.save_root)
	if directory == null:
		return []

	directory.list_dir_begin()
	while true:
		var file_name := directory.get_next()
		if file_name.is_empty():
			break
		if directory.current_is_dir():
			continue
		var extension := file_name.get_extension().to_lower()
		if not expected_extensions.has(extension):
			continue
		var meta := _read_meta_from_slot_file(settings.save_root.path_join(file_name), int(expected_extensions[extension]))
		if meta.is_empty():
			continue
		entries.append(_entry_from_meta(meta))
	directory.list_dir_end()
	return entries


func _read_meta_from_slot_file(path: String, format: int) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}

	var payload: Variant = {}
	if format == FORMAT_JSON:
		var json_string := file.get_as_text()
		var json_result = JSON.parse_string(json_string)
		if json_result == null:
			return {}
		payload = json_result
	else:
		payload = bytes_to_var(file.get_buffer(file.get_length()))

	if not (payload is Dictionary):
		return {}
	var payload_dict: Dictionary = payload
	if not payload_dict.has("meta") or not (payload_dict["meta"] is Dictionary):
		return {}
	return Dictionary(payload_dict["meta"])


func _entry_from_meta(meta: Dictionary) -> Dictionary:
	var entry_name := String(meta.get("slot_id", ""))
	var display_name := String(meta.get("display_name", entry_name))
	var created_at := int(meta.get("created_at_unix", meta.get("saved_at_unix", 0)))
	var saved_at := int(meta.get("saved_at_unix", 0))
	return {
		"name": entry_name,
		"display_name": display_name,
		"created_at_unix": created_at,
		"saved_at_unix": saved_at,
		"meta": meta.duplicate(true),
	}


func _sort_entries(a: Dictionary, b: Dictionary) -> bool:
	match _sort_option.get_selected_id():
		SortMode.NAME_DESC:
			return String(a.get("display_name", "")).naturalnocasecmp_to(String(b.get("display_name", ""))) > 0
		SortMode.CREATED_NEWEST:
			return int(a.get("created_at_unix", 0)) > int(b.get("created_at_unix", 0))
		SortMode.CREATED_OLDEST:
			return int(a.get("created_at_unix", 0)) < int(b.get("created_at_unix", 0))
		SortMode.SAVED_NEWEST:
			return int(a.get("saved_at_unix", 0)) > int(b.get("saved_at_unix", 0))
		SortMode.SAVED_OLDEST:
			return int(a.get("saved_at_unix", 0)) < int(b.get("saved_at_unix", 0))
		_:
			return String(a.get("display_name", "")).naturalnocasecmp_to(String(b.get("display_name", ""))) < 0


func _build_row(entry: Dictionary, scope: String) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 96)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_box)

	var title := Label.new()
	title.text = String(entry.get("display_name", ""))
	title.add_theme_font_size_override("font_size", 15)
	text_box.add_child(title)

	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 6)
	text_box.add_child(status_row)

	var compatibility_report := Dictionary(entry.get("compatibility_report", {}))
	status_row.add_child(
		_make_status_badge_clean(
			"Compatibility",
			_build_compatibility_status_text(compatibility_report).trim_prefix("Compatibility: "),
			_build_compatibility_status_color(compatibility_report),
			_build_compatibility_tooltip(
				compatibility_report,
				Dictionary(entry.get("meta", {}))
			)
		)
	)

	var restore_readiness_report := Dictionary(entry.get("restore_readiness_report", {}))
	status_row.add_child(
		_make_status_badge_clean(
			"Restore Contract",
			_build_restore_readiness_status_text(restore_readiness_report).trim_prefix("Restore Readiness: "),
			_build_restore_readiness_status_color(restore_readiness_report),
			_build_restore_readiness_tooltip(
				restore_readiness_report,
				Dictionary(entry.get("meta", {}))
			)
		)
	)

	status_row.add_child(
		_make_status_badge_clean(
			"Slot Safety",
			_build_slot_safety_status_text(entry),
			_build_slot_safety_summary_color(entry),
			_build_slot_safety_tooltip(entry)
		)
	)

	# Create a horizontal container for buttons
	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 6)
	text_box.add_child(button_row)

	var subtitle := Label.new()
	subtitle.text = "Created: %s | Saved: %s" % [
		_format_unix_time(int(entry.get("created_at_unix", 0))),
		_format_unix_time(int(entry.get("saved_at_unix", 0))),
	]
	subtitle.modulate = get_theme_color("font_placeholder_color", "Editor")
	subtitle.add_theme_font_size_override("font_size", 12)  # Smaller font size
	text_box.add_child(subtitle)

	var entry_name := String(entry.get("name", ""))
	var display_name := String(entry.get("display_name", entry_name))
	var details_key := _entry_ui_key(scope, entry_name)
	var details_expanded := bool(_expanded_entry_keys.get(details_key, false))

	var details_toggle := Button.new()
	details_toggle.flat = true
	details_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	details_toggle.text = ("%s Slot Details" % ("v" if details_expanded else ">"))
	details_toggle.pressed.connect(
		func() -> void:
			_expanded_entry_keys[details_key] = not details_expanded
			_refresh_scope_list(scope)
	)
	text_box.add_child(details_toggle)

	var details_box := VBoxContainer.new()
	details_box.visible = details_expanded
	details_box.add_theme_constant_override("separation", 4)
	text_box.add_child(details_box)

	if details_expanded:
		var safety_summary := Label.new()
		safety_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		safety_summary.text = _build_slot_safety_summary(entry)
		safety_summary.modulate = _build_slot_safety_summary_color(entry)
		details_box.add_child(safety_summary)

		var storage_info := Dictionary(entry.get("storage_info", {}))
		details_box.add_child(_make_detail_label("Slot Path", String(storage_info.get("slot_path", PATH_UNAVAILABLE))))
		details_box.add_child(_make_detail_label("Primary File", _build_primary_status_text(storage_info)))
		details_box.add_child(_make_detail_label("Backup", _build_backup_status_text(storage_info)))

		var meta := Dictionary(entry.get("meta", {}))
		details_box.add_child(_make_detail_label("Save Schema", _fallback_detail_text(String(meta.get("save_schema", "")))))
		details_box.add_child(_make_detail_label("Data Version", _detail_number_text(meta.get("data_version", 0))))
		details_box.add_child(_make_detail_label("Game Version", _fallback_detail_text(String(meta.get("game_version", "")))))
		details_box.add_child(_make_detail_label("Scene Path", _fallback_detail_text(String(meta.get("scene_path", "")))))

	if scope == SCOPE_DEV:
		button_row.add_child(_make_row_button("Ld", _is_runtime_available(), func() -> void: _queue_load_request(entry_name)))
		button_row.add_child(_make_row_button("Sv", _is_runtime_available(), func() -> void: _queue_save_request_named(entry_name)))
	# Add Load button for formal saves too
	if scope == SCOPE_FORMAL:
		button_row.add_child(_make_row_button("Ld", _is_runtime_available(), func() -> void: _queue_load_request(entry_name)))
	button_row.add_child(_make_row_button("Cp", true, func() -> void: _open_name_dialog(scope, "copy", entry_name, "Copy Save", "Copy", "%s Copy" % display_name)))
	button_row.add_child(_make_row_button("Rn", true, func() -> void: _open_name_dialog(scope, "rename", entry_name, "Rename Save", "Rename", display_name)))
	button_row.add_child(_make_row_button("Dl", true, func() -> void: _open_delete_dialog(scope, entry_name)))
	return panel


func _make_row_button(text: String, enabled: bool, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.disabled = not enabled
	button.pressed.connect(action)
	return button


func _make_status_badge(title: String, value: String, tone: Color, tooltip: String) -> Control:
	var panel := PanelContainer.new()
	panel.tooltip_text = tooltip

	var style := StyleBoxFlat.new()
	style.bg_color = Color(tone.r, tone.g, tone.b, 0.14)
	style.border_color = Color(tone.r, tone.g, tone.b, 0.55)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = "%s · %s" % [title, value]
	label.modulate = tone
	label.add_theme_font_size_override("font_size", 11)
	panel.add_child(label)
	return panel


func _make_status_badge_clean(title: String, value: String, tone: Color, tooltip: String) -> Control:
	var panel := PanelContainer.new()
	panel.tooltip_text = tooltip

	var style := StyleBoxFlat.new()
	style.bg_color = Color(tone.r, tone.g, tone.b, 0.14)
	style.border_color = Color(tone.r, tone.g, tone.b, 0.55)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = "%s | %s" % [title, value]
	label.modulate = tone
	label.add_theme_font_size_override("font_size", 11)
	panel.add_child(label)
	return panel


func _make_detail_label(label_text: String, value_text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var label := Label.new()
	label.custom_minimum_size.x = 84
	label.text = label_text
	label.modulate = get_theme_color("font_placeholder_color", "Editor")
	row.add_child(label)

	var value := Label.new()
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value.text = value_text
	row.add_child(value)
	return row


func _entry_ui_key(scope: String, entry_name: String) -> String:
	return "%s:%s" % [scope, entry_name]


func _fallback_detail_text(value: String) -> String:
	return value if not value.is_empty() else "<none>"


func _detail_number_text(value: Variant) -> String:
	var number := int(value)
	return str(number) if number > 0 else "<none>"


func _build_backup_status_text(storage_info: Dictionary) -> String:
	if storage_info.is_empty():
		return "Unknown"
	if bool(storage_info.get("recovery_possible", false)):
		return "Backup can recover this slot at %s" % String(storage_info.get("backup_path", PATH_UNAVAILABLE))
	if bool(storage_info.get("backup_exists", false)) and bool(storage_info.get("backup_valid_payload", false)):
		return "Valid backup available at %s" % String(storage_info.get("backup_path", PATH_UNAVAILABLE))
	if bool(storage_info.get("backup_exists", false)):
		return "Backup exists but is not restorable: %s" % String(storage_info.get("backup_probe_error", "INVALID_BACKUP"))
	return "No last-known-good backup beside this slot file."


func _build_primary_status_text(storage_info: Dictionary) -> String:
	if storage_info.is_empty():
		return "Unknown"
	if not bool(storage_info.get("primary_exists", false)):
		return "Primary slot file is missing."
	if bool(storage_info.get("primary_valid_payload", false)):
		return "Primary slot file is readable."
	return "Primary slot file is unreadable: %s" % String(storage_info.get("primary_probe_error", "READ_FAILED"))


func _build_slot_safety_summary(entry: Dictionary) -> String:
	var compatibility_report := Dictionary(entry.get("compatibility_report", {}))
	if not bool(compatibility_report.get("compatible", true)):
		return "Migration required before load. The slot metadata does not satisfy the current compatibility policy."

	var storage_info := Dictionary(entry.get("storage_info", {}))
	if bool(storage_info.get("primary_exists", false)) and not bool(storage_info.get("primary_valid_payload", false)):
		if bool(storage_info.get("recovery_possible", false)):
			return "Primary slot file is unreadable, but a valid backup can recover this slot."
		if bool(storage_info.get("backup_exists", false)):
			return "Primary slot file is unreadable, and the available backup is not restorable."
		return "Primary slot file is unreadable, and no backup is available."

	var readiness_report := Dictionary(entry.get("restore_readiness_report", {}))
	match String(readiness_report.get("status", "ready")):
		"blocked":
			return "Compatible, but the current restore contract is not satisfied yet. Load the expected scene first."
		"unknown":
			return "Compatible, but restore-contract verification is waiting for runtime context."
		"disabled":
			return "Compatible. Scene-level restore-contract verification is disabled, so SaveFlow will restore against whatever target resolves now."
		"advisory":
			return "Compatible. This slot did not record a scene target, so scene-level restore-contract verification is advisory only."

	if bool(storage_info.get("backup_exists", false)):
		return "Safe to restore into the current target. A last-known-good backup is also available beside the slot."
	return "Safe to restore into the current target."


func _build_slot_safety_status_text(entry: Dictionary) -> String:
	var compatibility_report := Dictionary(entry.get("compatibility_report", {}))
	if not bool(compatibility_report.get("compatible", true)):
		return "Migration required"

	var storage_info := Dictionary(entry.get("storage_info", {}))
	if bool(storage_info.get("primary_exists", false)) and not bool(storage_info.get("primary_valid_payload", false)):
		if bool(storage_info.get("recovery_possible", false)):
			return "Backup recovery available"
		if bool(storage_info.get("backup_exists", false)):
			return "Primary unreadable"
		return "No safe recovery"

	var readiness_report := Dictionary(entry.get("restore_readiness_report", {}))
	match String(readiness_report.get("status", "ready")):
		"blocked":
			return "Wrong restore target"
		"unknown":
			return "Waiting for runtime"
		"disabled":
			return "Target check disabled"
		"advisory":
			return "Target not recorded"
		_:
			if bool(storage_info.get("backup_exists", false)):
				return "Safe with backup"
			return "Safe"


func _build_slot_safety_tooltip(entry: Dictionary) -> String:
	var lines: PackedStringArray = []
	lines.append("Slot Safety | %s" % _build_slot_safety_status_text(entry))
	lines.append(_build_slot_safety_summary(entry))

	var storage_info := Dictionary(entry.get("storage_info", {}))
	lines.append("Primary: %s" % _build_primary_status_text(storage_info))
	lines.append("Backup: %s" % _build_backup_status_text(storage_info))

	var compatibility_report := Dictionary(entry.get("compatibility_report", {}))
	if not compatibility_report.is_empty():
		lines.append(_build_compatibility_status_text(compatibility_report))

	var readiness_report := Dictionary(entry.get("restore_readiness_report", {}))
	if not readiness_report.is_empty():
		lines.append(_build_restore_readiness_status_text(readiness_report))

	return "\n".join(lines)


func _build_slot_safety_summary_color(entry: Dictionary) -> Color:
	var compatibility_report := Dictionary(entry.get("compatibility_report", {}))
	if not bool(compatibility_report.get("compatible", true)):
		return Color(0.96, 0.54, 0.54)
	var storage_info := Dictionary(entry.get("storage_info", {}))
	if bool(storage_info.get("primary_exists", false)) and not bool(storage_info.get("primary_valid_payload", false)):
		return Color(0.96, 0.54, 0.54) if not bool(storage_info.get("recovery_possible", false)) else Color(0.95, 0.82, 0.46)
	var readiness_report := Dictionary(entry.get("restore_readiness_report", {}))
	match String(readiness_report.get("status", "ready")):
		"blocked":
			return Color(0.96, 0.54, 0.54)
		"unknown":
			return Color(0.95, 0.82, 0.46)
		"disabled", "advisory":
			return get_theme_color("font_placeholder_color", "Editor")
		_:
			return Color(0.60, 0.92, 0.70)


func _queue_save_request() -> void:
	_queue_save_request_named(_new_name_edit.text.strip_edges())


func _queue_save_request_named(entry_name: String) -> void:
	if entry_name.is_empty():
		_request_status_label.text = "Enter a save name first."
		return
	if not _is_runtime_available():
		_request_status_label.text = "Save requests require a running game with SaveFlow available."
		return
	SaveFlowSaveManagerBusScript.append_request("save", entry_name)
	_request_status_label.text = "Queued dev save request for '%s'." % entry_name
	_refresh_all()


func _queue_load_request(entry_name: String) -> void:
	if entry_name.is_empty():
		return
	if not _is_runtime_available():
		_request_status_label.text = "Load requests require a running game with SaveFlow available."
		return
	SaveFlowSaveManagerBusScript.append_request("load", entry_name)
	_request_status_label.text = "Queued dev load request for '%s'." % entry_name
	_refresh_all()


func _open_name_dialog(scope: String, mode: String, source_name: String, title: String, ok_text: String, default_text: String) -> void:
	_name_dialog_scope = scope
	_name_dialog_mode = mode
	_name_dialog_source = source_name
	_name_dialog.title = title
	_name_dialog.get_ok_button().text = ok_text
	_name_dialog_line.text = default_text
	_name_dialog.popup_centered()
	_name_dialog_line.grab_focus()
	_name_dialog_line.select_all()


func _on_name_dialog_confirmed() -> void:
	var target_name := _name_dialog_line.text.strip_edges()
	if target_name.is_empty():
		_set_operation_status("Name cannot be empty.", true)
		return
	var runtime := _get_runtime_for_slot_operations()
	if runtime == null:
		_set_operation_status("SaveFlow runtime is unavailable for copy/rename.", true)
		return
	var status := _read_runtime_status()
	_prepare_runtime_for_scope(runtime, _name_dialog_scope, status)

	var result: SaveResult = null
	if _name_dialog_mode == "copy":
		result = runtime.copy_slot(_name_dialog_source, target_name, false)
	elif _name_dialog_mode == "rename":
		result = runtime.rename_slot(_name_dialog_source, target_name, false)
	else:
		return
	if result == null:
		_set_operation_status("Operation did not return a SaveResult.", true)
		return
	var verb := "Copied" if _name_dialog_mode == "copy" else "Renamed"
	if result.ok:
		_set_operation_status("%s %s save '%s'." % [verb, _name_dialog_scope, target_name], false)
	else:
		_set_operation_status(
			"%s failed: %s (%s)" % [verb, result.error_key, result.error_message],
			true
		)
	_refresh_lists()


func _open_delete_dialog(scope: String, entry_name: String) -> void:
	_delete_scope = scope
	_delete_target = entry_name
	_delete_dialog.dialog_text = "Delete %s save '%s'?" % [scope, entry_name]
	_delete_dialog.popup_centered()


func _confirm_delete() -> void:
	if _delete_target.is_empty():
		return
	var runtime := _get_runtime_for_slot_operations()
	if runtime == null:
		_set_operation_status("SaveFlow runtime is unavailable for delete.", true)
		return
	var status := _read_runtime_status()
	_prepare_runtime_for_scope(runtime, _delete_scope, status)
	var result: SaveResult = runtime.delete_slot(_delete_target)
	if result.ok:
		_set_operation_status("Deleted %s save '%s'." % [_delete_scope, _delete_target], false)
	else:
		_set_operation_status("Delete failed: %s (%s)" % [result.error_key, result.error_message], true)
	_refresh_lists()


func _get_editor_saveflow() -> Node:
	var main_loop := Engine.get_main_loop()
	if not (main_loop is SceneTree):
		return null
	return (main_loop as SceneTree).root.get_node_or_null("/root/SaveFlow")


func _get_runtime_for_slot_operations() -> Node:
	var runtime := _get_editor_saveflow()
	if runtime != null:
		return runtime
	if _fallback_runtime == null or not is_instance_valid(_fallback_runtime):
		_fallback_runtime = SaveFlowRuntimeScript.new()
	return _fallback_runtime


func _sync_editor_runtime_settings_from_status(runtime: Node, status: Dictionary = {}) -> SaveSettings:
	if status.is_empty():
		status = _read_runtime_status()
	var settings_data := Dictionary(status.get("settings", {}))
	if settings_data.is_empty():
		if runtime.has_method("get_settings"):
			return runtime.get_settings()
		return SaveSettings.new()
	return _configure_runtime_with_settings(runtime, _settings_from_data(settings_data))


func _sync_editor_dev_settings_from_status(runtime: Node, status: Dictionary = {}) -> SaveSettings:
	if status.is_empty():
		status = _read_runtime_status()
	var settings_data := Dictionary(status.get("dev_settings", {}))
	if settings_data.is_empty():
		var derived := _build_derived_dev_settings(status)
		if derived == null:
			return _sync_editor_runtime_settings_from_status(runtime, status)
		return _configure_runtime_with_settings(runtime, derived)
	return _configure_runtime_with_settings(runtime, _settings_from_data(settings_data))


func _configure_runtime_with_settings(runtime: Node, settings: SaveSettings) -> SaveSettings:
	if runtime.has_method("configure"):
		runtime.configure(settings)
	return settings


func _settings_from_data(settings_data: Dictionary, fallback: SaveSettings = null) -> SaveSettings:
	var settings := _clone_settings(fallback) if fallback != null else SaveSettings.new()
	if settings_data.is_empty():
		return settings
	settings.save_root = String(settings_data.get("save_root", settings.save_root))
	settings.slot_index_file = String(settings_data.get("slot_index_file", settings.slot_index_file))
	settings.storage_format = int(settings_data.get("storage_format", settings.storage_format))
	settings.pretty_json_in_editor = bool(settings_data.get("pretty_json_in_editor", settings.pretty_json_in_editor))
	settings.use_safe_write = bool(settings_data.get("use_safe_write", settings.use_safe_write))
	settings.keep_last_backup = bool(settings_data.get("keep_last_backup", settings.keep_last_backup))
	settings.file_extension_json = String(settings_data.get("file_extension_json", settings.file_extension_json))
	settings.file_extension_binary = String(settings_data.get("file_extension_binary", settings.file_extension_binary))
	settings.log_level = int(settings_data.get("log_level", settings.log_level))
	settings.include_meta_in_slot_file = bool(settings_data.get("include_meta_in_slot_file", settings.include_meta_in_slot_file))
	settings.auto_create_dirs = bool(settings_data.get("auto_create_dirs", settings.auto_create_dirs))
	settings.project_title = String(settings_data.get("project_title", settings.project_title))
	settings.game_version = String(settings_data.get("game_version", settings.game_version))
	settings.data_version = int(settings_data.get("data_version", settings.data_version))
	settings.save_schema = String(settings_data.get("save_schema", settings.save_schema))
	settings.enforce_save_schema_match = bool(settings_data.get("enforce_save_schema_match", settings.enforce_save_schema_match))
	settings.enforce_data_version_match = bool(settings_data.get("enforce_data_version_match", settings.enforce_data_version_match))
	settings.verify_scene_path_on_load = bool(settings_data.get("verify_scene_path_on_load", settings.verify_scene_path_on_load))
	return settings


func _clone_settings(source: SaveSettings) -> SaveSettings:
	var clone := SaveSettings.new()
	if source == null:
		return clone
	clone.save_root = source.save_root
	clone.slot_index_file = source.slot_index_file
	clone.storage_format = source.storage_format
	clone.pretty_json_in_editor = source.pretty_json_in_editor
	clone.use_safe_write = source.use_safe_write
	clone.keep_last_backup = source.keep_last_backup
	clone.file_extension_json = source.file_extension_json
	clone.file_extension_binary = source.file_extension_binary
	clone.log_level = source.log_level
	clone.include_meta_in_slot_file = source.include_meta_in_slot_file
	clone.auto_create_dirs = source.auto_create_dirs
	clone.project_title = source.project_title
	clone.game_version = source.game_version
	clone.data_version = source.data_version
	clone.save_schema = source.save_schema
	clone.enforce_save_schema_match = source.enforce_save_schema_match
	clone.enforce_data_version_match = source.enforce_data_version_match
	clone.verify_scene_path_on_load = source.verify_scene_path_on_load
	return clone


func _attach_entry_reports(entry: Dictionary, settings: SaveSettings, status: Dictionary, runtime: Node = null) -> Dictionary:
	var meta := Dictionary(entry.get("meta", {}))
	entry["storage_info"] = _build_entry_storage_info(String(entry.get("name", "")), settings, runtime)
	entry["compatibility_report"] = _build_entry_compatibility_report(meta, settings)
	entry["restore_readiness_report"] = _build_restore_readiness_report(meta, settings, status)
	return entry


func _build_entry_storage_info(entry_name: String, settings: SaveSettings, runtime: Node = null) -> Dictionary:
	if runtime != null and runtime.has_method("inspect_slot_storage"):
		var inspect_result = runtime.inspect_slot_storage(entry_name)
		if inspect_result != null and inspect_result.ok and inspect_result.data is Dictionary:
			return Dictionary(inspect_result.data)

	var slot_path := ""
	if runtime != null and runtime.has_method("get_slot_path"):
		var path_result = runtime.get_slot_path(entry_name)
		if path_result != null and path_result.ok:
			slot_path = String(path_result.data)
	if slot_path.is_empty():
		slot_path = _resolve_slot_path_from_settings(entry_name, settings)

	var backup_path := "%s%s" % [slot_path, BACKUP_FILE_SUFFIX] if not slot_path.is_empty() else ""
	return {
		"slot_path": slot_path,
		"backup_path": backup_path,
		"primary_exists": not slot_path.is_empty() and FileAccess.file_exists(slot_path),
		"primary_valid_payload": not slot_path.is_empty() and _probe_payload_file(slot_path, _detect_format_for_path(slot_path, settings)),
		"primary_probe_error": _probe_payload_error(slot_path, settings),
		"backup_exists": not backup_path.is_empty() and FileAccess.file_exists(backup_path),
		"backup_valid_payload": not backup_path.is_empty() and _probe_payload_file(backup_path, _detect_format_for_path(slot_path, settings)),
		"backup_probe_error": _probe_payload_error(backup_path, settings),
		"recovery_possible": (not slot_path.is_empty() and not _probe_payload_file(slot_path, _detect_format_for_path(slot_path, settings))) and (not backup_path.is_empty() and _probe_payload_file(backup_path, _detect_format_for_path(slot_path, settings))),
	}


func _resolve_slot_path_from_settings(entry_name: String, settings: SaveSettings) -> String:
	if settings == null or entry_name.is_empty():
		return ""
	var candidates := [
		settings.save_root.path_join("%s.%s" % [_sanitize_slot_id(entry_name), settings.file_extension_json]),
		settings.save_root.path_join("%s.%s" % [_sanitize_slot_id(entry_name), settings.file_extension_binary]),
	]
	for candidate in candidates:
		if FileAccess.file_exists(candidate):
			return candidate
	return candidates[0] if not candidates.is_empty() else ""


func _detect_format_for_path(path: String, settings: SaveSettings) -> int:
	if settings != null and path.get_extension().to_lower() == settings.file_extension_binary.to_lower():
		return FORMAT_BINARY
	return FORMAT_JSON


func _probe_payload_file(path: String, format: int) -> bool:
	if path.is_empty() or not FileAccess.file_exists(path):
		return false
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	if format == FORMAT_JSON:
		var text := file.get_as_text()
		var json := JSON.new()
		if json.parse(text) != OK:
			return false
		var native_payload: Variant = json.data
		return native_payload is Dictionary and native_payload.has("meta") and native_payload.has("data") and native_payload["meta"] is Dictionary
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	var payload: Variant = bytes_to_var(bytes)
	return payload is Dictionary and payload.has("meta") and payload.has("data") and payload["meta"] is Dictionary


func _probe_payload_error(path: String, settings: SaveSettings) -> String:
	if path.is_empty() or not FileAccess.file_exists(path):
		return "FILE_NOT_FOUND"
	var format := _detect_format_for_path(path, settings)
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return "READ_FAILED"
	if format == FORMAT_JSON:
		var text := file.get_as_text()
		var json := JSON.new()
		if json.parse(text) != OK:
			return "INVALID_FORMAT"
		var native_payload: Variant = json.data
		if not (native_payload is Dictionary and native_payload.has("meta") and native_payload.has("data") and native_payload["meta"] is Dictionary):
			return "INVALID_PAYLOAD"
		return ""
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	var payload: Variant = bytes_to_var(bytes)
	if not (payload is Dictionary and payload.has("meta") and payload.has("data") and payload["meta"] is Dictionary):
		return "INVALID_PAYLOAD"
	return ""


func _sanitize_slot_id(slot_id: String) -> String:
	var sanitized := slot_id.strip_edges()
	sanitized = sanitized.replace("/", "_")
	sanitized = sanitized.replace("\\", "_")
	sanitized = sanitized.replace(":", "_")
	sanitized = sanitized.replace("*", "_")
	sanitized = sanitized.replace("?", "_")
	sanitized = sanitized.replace("\"", "_")
	sanitized = sanitized.replace("<", "_")
	sanitized = sanitized.replace(">", "_")
	sanitized = sanitized.replace("|", "_")
	if sanitized.is_empty():
		sanitized = "slot"
	return sanitized


func _build_entry_compatibility_report(meta: Dictionary, settings: SaveSettings) -> Dictionary:
	var report := {
		"slot_game_version": String(meta.get("game_version", "")),
		"project_game_version": settings.game_version,
		"slot_data_version": int(meta.get("data_version", 0)),
		"project_data_version": settings.data_version,
		"slot_save_schema": String(meta.get("save_schema", "")),
		"project_save_schema": settings.save_schema,
		"schema_matches": true,
		"data_version_matches": true,
		"game_version_matches": true,
		"compatible": true,
		"reasons": PackedStringArray(),
	}

	var reasons: PackedStringArray = report["reasons"]
	var slot_schema := String(report["slot_save_schema"])
	var project_schema := String(report["project_save_schema"])
	var schema_mismatch := not slot_schema.is_empty() and not project_schema.is_empty() and slot_schema != project_schema
	report["schema_matches"] = not schema_mismatch
	if schema_mismatch and settings.enforce_save_schema_match:
		report["compatible"] = false
		reasons.append("SAVE_SCHEMA_MISMATCH")

	var slot_data_version := int(report["slot_data_version"])
	var project_data_version := int(report["project_data_version"])
	var data_version_mismatch := slot_data_version > 0 and project_data_version > 0 and slot_data_version != project_data_version
	report["data_version_matches"] = not data_version_mismatch
	if data_version_mismatch and settings.enforce_data_version_match:
		report["compatible"] = false
		reasons.append("DATA_VERSION_MISMATCH")

	var slot_game_version := String(report["slot_game_version"])
	var project_game_version := String(report["project_game_version"])
	if not slot_game_version.is_empty() and not project_game_version.is_empty() and slot_game_version != project_game_version:
		report["game_version_matches"] = false
		reasons.append("GAME_VERSION_DIFFERS")

	report["reasons"] = reasons
	return report


func _build_compatibility_status_text(report: Dictionary) -> String:
	if report.is_empty():
		return "Compatibility: Unknown"
	var reasons := PackedStringArray(report.get("reasons", PackedStringArray()))
	if not bool(report.get("compatible", true)):
		return "Compatibility: Migration required"
	if not reasons.is_empty():
		return "Compatibility: Compatible with differences"
	return "Compatibility: OK"


func _build_compatibility_status_color(report: Dictionary) -> Color:
	if report.is_empty():
		return get_theme_color("font_placeholder_color", "Editor")
	var reasons := PackedStringArray(report.get("reasons", PackedStringArray()))
	if not bool(report.get("compatible", true)):
		return Color(0.96, 0.54, 0.54)
	if not reasons.is_empty():
		return Color(0.95, 0.82, 0.46)
	return Color(0.60, 0.92, 0.70)


func _build_compatibility_tooltip(report: Dictionary, _meta: Dictionary) -> String:
	if report.is_empty():
		return "Compatibility could not be derived from slot metadata."

	var lines: PackedStringArray = []
	lines.append(_build_compatibility_status_text(report))
	lines.append("Slot schema: %s | Project schema: %s" % [
		String(report.get("slot_save_schema", "")),
		String(report.get("project_save_schema", "")),
	])
	lines.append("Slot data version: %d | Project data version: %d" % [
		int(report.get("slot_data_version", 0)),
		int(report.get("project_data_version", 0)),
	])
	if String(report.get("slot_game_version", "")).is_empty() and String(report.get("project_game_version", "")).is_empty():
		lines.append("Game version: not compared")
	else:
		lines.append("Slot game version: %s | Project game version: %s" % [
			String(report.get("slot_game_version", "")),
			String(report.get("project_game_version", "")),
		])
	var reasons := PackedStringArray(report.get("reasons", PackedStringArray()))
	lines.append("Reasons: %s" % ("none" if reasons.is_empty() else ", ".join(reasons)))
	return "\n".join(lines)


func _build_restore_readiness_report(meta: Dictionary, settings: SaveSettings, status: Dictionary) -> Dictionary:
	var expected_scene_path := String(meta.get("scene_path", ""))
	var current_scene_path := String(status.get("current_scene_path", ""))
	var runtime_active := _is_runtime_status_active(status)
	var report := {
		"ready": true,
		"status": "ready",
		"expected_scene_path": expected_scene_path,
		"current_scene_path": current_scene_path,
		"reason": "",
	}

	if not settings.verify_scene_path_on_load:
		report["status"] = "disabled"
		report["reason"] = "SCENE_PATH_CHECK_DISABLED"
		return report

	if expected_scene_path.is_empty():
		report["status"] = "advisory"
		report["reason"] = "NO_SAVED_SCENE_PATH"
		return report

	if not runtime_active:
		report["ready"] = false
		report["status"] = "unknown"
		report["reason"] = "RUNTIME_UNAVAILABLE"
		return report

	if current_scene_path.is_empty():
		report["ready"] = false
		report["status"] = "unknown"
		report["reason"] = "CURRENT_SCENE_UNKNOWN"
		return report

	if current_scene_path != expected_scene_path:
		report["ready"] = false
		report["status"] = "blocked"
		report["reason"] = "SCENE_PATH_MISMATCH"
		return report

	return report


func _build_restore_readiness_status_text(report: Dictionary) -> String:
	if report.is_empty():
		return "Restore Contract: Unknown"
	match String(report.get("status", "ready")):
		"blocked":
			return "Restore Contract: Expected scene not active"
		"unknown":
			return "Restore Contract: Runtime context missing"
		"disabled":
			return "Restore Contract: Scene target check disabled"
		"advisory":
			return "Restore Contract: No scene target recorded"
		_:
			return "Restore Contract: Ready"


func _build_restore_readiness_status_color(report: Dictionary) -> Color:
	if report.is_empty():
		return get_theme_color("font_placeholder_color", "Editor")
	match String(report.get("status", "ready")):
		"blocked":
			return Color(0.96, 0.54, 0.54)
		"unknown":
			return Color(0.95, 0.82, 0.46)
		"disabled", "advisory":
			return get_theme_color("font_placeholder_color", "Editor")
		_:
			return Color(0.60, 0.92, 0.70)


func _build_restore_readiness_tooltip(report: Dictionary, meta: Dictionary) -> String:
	if report.is_empty():
		return "Restore contract could not be evaluated."

	var lines: PackedStringArray = []
	lines.append(_build_restore_readiness_status_text(report))
	var expected_scene_path := String(report.get("expected_scene_path", ""))
	var current_scene_path := String(report.get("current_scene_path", ""))
	lines.append("Saved scene path: %s" % (expected_scene_path if not expected_scene_path.is_empty() else "<none recorded>"))
	lines.append("Current runtime scene: %s" % (current_scene_path if not current_scene_path.is_empty() else "<unknown>"))
	match String(report.get("reason", "")):
		"SCENE_PATH_CHECK_DISABLED":
			lines.append("Scene-path verification is disabled, so SaveFlow will not enforce the restore contract against the current scene target.")
		"NO_SAVED_SCENE_PATH":
			lines.append("This slot did not record a scene path, so SaveFlow cannot verify that the expected scene is already active before restore.")
		"RUNTIME_UNAVAILABLE":
			lines.append("SaveFlow verifies this restore contract against the running scene target, but no runtime context is available right now.")
		"CURRENT_SCENE_UNKNOWN":
			lines.append("SaveFlow runtime is active, but it has not reported the current restore target yet.")
		"SCENE_PATH_MISMATCH":
			lines.append("This restore contract expects the saved scene to already be active before restore. Load the expected scene first and retry.")
		_:
			lines.append("The current runtime scene satisfies the saved restore contract.")
	if meta.has("scope_path") and not String(meta.get("scope_path", "")).is_empty():
		lines.append("Saved scope path: %s" % String(meta.get("scope_path", "")))
	return "\n".join(lines)


func _read_runtime_status() -> Dictionary:
	return SaveFlowSaveManagerBusScript.read_status()


func _resolve_formal_save_root_display(status: Dictionary = {}) -> String:
	var save_root := _formal_settings_from_status(status).save_root
	if save_root.is_empty():
		return PATH_UNAVAILABLE
	return _globalize_user_path(save_root)


func _resolve_formal_slot_index_display(status: Dictionary = {}) -> String:
	var slot_index := _formal_settings_from_status(status).slot_index_file
	if slot_index.is_empty():
		return PATH_UNAVAILABLE
	return _globalize_user_path(slot_index)


func _resolve_dev_save_root_display(status: Dictionary = {}) -> String:
	var save_root := _dev_settings_from_status(status).save_root
	if save_root.is_empty():
		return PATH_UNAVAILABLE
	return _globalize_user_path(save_root)


func _resolve_dev_slot_index_display(status: Dictionary = {}) -> String:
	var slot_index := _dev_settings_from_status(status).slot_index_file
	if slot_index.is_empty():
		return PATH_UNAVAILABLE
	return _globalize_user_path(slot_index)


func _resolve_dev_manager_root_display() -> String:
	return _globalize_user_path(SaveFlowSaveManagerBusScript.ROOT_DIR)


func _globalize_user_path(path: String) -> String:
	if path.is_empty():
		return PATH_UNAVAILABLE
	return ProjectSettings.globalize_path(path)


func _get_editor_default_save_root() -> String:
	var runtime := _get_editor_saveflow()
	if runtime == null or not runtime.has_method("get_settings"):
		return ""
	var settings: SaveSettings = runtime.get_settings()
	return settings.save_root


func _get_editor_default_slot_index() -> String:
	var runtime := _get_editor_saveflow()
	if runtime == null or not runtime.has_method("get_settings"):
		return ""
	var settings: SaveSettings = runtime.get_settings()
	return settings.slot_index_file


func _open_formal_save_folder() -> void:
	var path := _resolve_formal_save_root_display(_read_runtime_status())
	_open_folder_path(path, "Formal save folder is unavailable.")


func _open_dev_save_folder() -> void:
	var path := _resolve_dev_save_root_display(_read_runtime_status())
	_open_folder_path(path, "Dev save folder is unavailable.")


func _build_derived_dev_settings(status: Dictionary) -> SaveSettings:
	var formal_settings := _formal_settings_from_status(status)
	var formal_root := formal_settings.save_root
	if formal_root.is_empty():
		return null

	var formal_root_clean := formal_root.trim_suffix("/")
	formal_root_clean = formal_root_clean.trim_suffix("\\")
	var formal_leaf := formal_root_clean.get_file().to_lower()
	var parent := formal_root_clean.get_base_dir()

	var dev_root := ""
	if formal_leaf == "saves":
		dev_root = parent.path_join("devSaves")
	else:
		dev_root = formal_root_clean.path_join("devSaves")

	var slot_index := formal_settings.slot_index_file
	var dev_index := ""
	if not slot_index.is_empty():
		var idx_parent := slot_index.get_base_dir()
		dev_index = idx_parent.path_join("dev-slots.index")

	var derived := _clone_settings(formal_settings)
	derived.save_root = dev_root
	if not dev_index.is_empty():
		derived.slot_index_file = dev_index
	return derived


func _formal_settings_from_status(status: Dictionary = {}) -> SaveSettings:
	if status.is_empty():
		status = _read_runtime_status()
	var fallback := SaveSettings.new()
	fallback.save_root = _get_editor_default_save_root()
	fallback.slot_index_file = _get_editor_default_slot_index()
	return _settings_from_data(Dictionary(status.get("settings", {})), fallback)


func _dev_settings_from_status(status: Dictionary = {}) -> SaveSettings:
	if status.is_empty():
		status = _read_runtime_status()
	var explicit_dev := _settings_from_data(Dictionary(status.get("dev_settings", {})))
	if not explicit_dev.save_root.is_empty() or not explicit_dev.slot_index_file.is_empty():
		return explicit_dev
	var derived := _build_derived_dev_settings(status)
	if derived != null:
		return derived
	var fallback := SaveSettings.new()
	fallback.save_root = "user://devSaves"
	fallback.slot_index_file = "user://dev-slots.index"
	return fallback


func _open_folder_path(path: String, unavailable_message: String) -> void:
	if path == PATH_UNAVAILABLE or path.is_empty():
		_request_status_label.text = unavailable_message
		return
	DirAccess.make_dir_recursive_absolute(path)
	var ok := OS.shell_open(path)
	if ok != OK:
		_request_status_label.text = "Failed to open folder: %s" % path
		return
	_request_status_label.text = "Opened folder: %s" % path


func _is_runtime_available() -> bool:
	return _is_runtime_status_active(_read_runtime_status())


func _is_runtime_status_active(status: Dictionary) -> bool:
	return bool(status.get("runtime_available", false)) and int(Time.get_unix_time_from_system()) - int(status.get("updated_at_unix", 0)) <= STATUS_TIMEOUT_SECONDS


func _set_operation_status(message: String, is_error: bool) -> void:
	_request_status_label.text = message
	_request_status_label.modulate = Color(0.92, 0.58, 0.36, 1.0) if is_error else Color(0.35, 0.8, 0.45, 1.0)
	_request_status_hold_until_unix = int(Time.get_unix_time_from_system()) + 5


func _format_unix_time(value: int) -> String:
	if value <= 0:
		return "<unknown>"
	var dt := Time.get_datetime_dict_from_unix_time(value)
	return "%04d-%02d-%02d %02d:%02d:%02d" % [
		int(dt.get("year", 0)),
		int(dt.get("month", 0)),
		int(dt.get("day", 0)),
		int(dt.get("hour", 0)),
		int(dt.get("minute", 0)),
		int(dt.get("second", 0)),
	]


func _get_default_settings_for_scope(scope: String, status: Dictionary) -> SaveSettings:
	if scope == SCOPE_DEV:
		return _dev_settings_from_status(status)
	return _formal_settings_from_status(status)
