extends Control

const SLOT_ID := "recommended_entity_collection_case"
const ACTOR_PREFAB := preload("res://demo/saveflow_lite/recommended_template/scenes/prefabs/template_runtime_actor.tscn")
const FACTORY_TYPE_KEY := "runtime_actor"

@onready var _runtime_actors: Node = $StateRoot/RuntimeActors
@onready var _actor_collection: SaveFlowEntityCollectionSource = $StateRoot/ActorCollection
@onready var _actors_label: Label = $MarginContainer/PanelContainer/Content/ActorsLabel
@onready var _status_output: TextEdit = $MarginContainer/PanelContainer/Content/StatusOutput


func _ready() -> void:
	_configure_runtime()
	_bind_buttons()
	_reset_state(false)
	_ensure_seed_slot()
	_set_status("EntityCollection case ready. This scene stores a changing runtime set through EntityCollectionSource + PrefabEntityFactory.")


func _configure_runtime() -> void:
	SaveFlow.configure_with(
		"user://recommended_cases/entity_collection/saves",
		"user://recommended_cases/entity_collection/slots.index"
	)


func _bind_buttons() -> void:
	$MarginContainer/PanelContainer/Content/Buttons/SaveButton.pressed.connect(_on_save_pressed)
	$MarginContainer/PanelContainer/Content/Buttons/LoadButton.pressed.connect(_on_load_pressed)
	$MarginContainer/PanelContainer/Content/Buttons/SpawnButton.pressed.connect(_on_spawn_pressed)
	$MarginContainer/PanelContainer/Content/Buttons/MutateButton.pressed.connect(_on_mutate_pressed)
	$MarginContainer/PanelContainer/Content/Buttons/ResetButton.pressed.connect(_on_reset_pressed)


func _on_save_pressed() -> void:
	_actor_collection.before_save({})
	var payload: Variant = _actor_collection.gather_save_data()
	var result: SaveResult = SaveFlow.save_data(
		SLOT_ID,
		payload,
		{
			"display_name": "EntityCollection Case",
			"scene_path": scene_file_path,
		}
	)
	_set_status(_format_result("Save", result))


func _on_load_pressed() -> void:
	var load_result: SaveResult = SaveFlow.load_data(SLOT_ID)
	if not load_result.ok:
		_set_status(_format_result("Load", load_result))
		return
	_actor_collection.before_load(load_result.data, {})
	var apply_result: SaveResult = _actor_collection.apply_save_data(load_result.data, {})
	_set_status(_format_result("Load", apply_result))


func _on_spawn_pressed() -> void:
	var next_index := _runtime_actors.get_child_count() + 1
	_spawn_actor(
		"runtime_actor_%d" % next_index,
		Vector2(180 + 32 * next_index, 108 + 8 * (next_index % 2)),
		6 + next_index,
		PackedStringArray(["runtime", "spawned"]),
		["gel", "dust"]
	)
	_set_status("Spawned one more runtime entity. EntityCollectionSource is the right path because this set changes over time.")


func _on_mutate_pressed() -> void:
	if _runtime_actors.get_child_count() == 0:
		_set_status("No runtime entity is available to mutate.")
		return
	var index := 0
	for actor_variant in _runtime_actors.get_children():
		var actor := actor_variant as Node2D
		if actor == null or not actor.has_method("reset_state"):
			index += 1
			continue
		actor.call(
			"reset_state",
			{
				"actor_type": FACTORY_TYPE_KEY,
				"hp": max(1, 3 + index),
				"loot_table": ["rare_drop", "bonus_%d" % index],
				"tags": PackedStringArray(["runtime", "mutated", "wave_%d" % index]),
				"is_alerted": true,
				"position": actor.position + Vector2(20 + 8 * index, -10 - 4 * index),
			}
		)
		index += 1
	_set_status("Mutated every runtime entity in the collection. Load uses clear-and-restore so the saved set fully replaces the current one.")


func _on_reset_pressed() -> void:
	_reset_state(true)


func _reset_state(announce: bool) -> void:
	for child in _runtime_actors.get_children():
		child.free()
	_spawn_actor("runtime_actor_alpha", Vector2(176, 112), 12, PackedStringArray(["runtime", "starter"]), ["gel"])
	_spawn_actor("runtime_actor_beta", Vector2(248, 88), 8, PackedStringArray(["runtime", "flying"]), ["wing"])
	_refresh_labels()
	if announce:
		_set_status("Reset the runtime collection back to two tracked actors.")


func _spawn_actor(persistent_id: String, spawn_position: Vector2, hp: int, tags: PackedStringArray, loot_table: Array) -> void:
	var actor := ACTOR_PREFAB.instantiate() as Node2D
	actor.name = persistent_id
	_runtime_actors.add_child(actor)
	if actor.has_method("reset_state"):
		actor.call(
			"reset_state",
			{
				"actor_type": FACTORY_TYPE_KEY,
				"hp": hp,
				"loot_table": loot_table,
				"tags": tags,
				"is_alerted": false,
				"position": spawn_position,
			}
		)
	var identity := actor.get_node_or_null("Identity")
	if identity != null:
		identity.set("persistent_id", persistent_id)
		identity.set("type_key", FACTORY_TYPE_KEY)


func _refresh_labels() -> void:
	var lines: PackedStringArray = []
	for child in _runtime_actors.get_children():
		if child.has_method("describe_state"):
			lines.append("%s -> %s" % [child.name, String(child.call("describe_state"))])
	_actors_label.text = "Runtime Actors:\n%s" % ("\n".join(lines) if not lines.is_empty() else "(none)")


func _format_result(label: String, result: SaveResult) -> String:
	if result.ok:
		return "%s OK" % label
	return "%s failed: %s (%s)" % [label, result.error_message, result.error_key]


func _set_status(message: String) -> void:
	_status_output.text = message
	_refresh_labels()


func _ensure_seed_slot() -> void:
	if SaveFlow.slot_exists(SLOT_ID):
		return
	_actor_collection.before_save({})
	SaveFlow.save_data(
		SLOT_ID,
		_actor_collection.gather_save_data(),
		{
			"display_name": "EntityCollection Case",
			"scene_path": scene_file_path,
		}
	)
