extends GdUnitTestSuite

const SaveScript := preload("res://addons/saveflow_lite/runtime/core/save_flow.gd")
const SaveSettingsScript := preload("res://addons/saveflow_lite/runtime/types/save_settings.gd")
const SaveFlowEntityCollectionSourceScript := preload("res://addons/saveflow_lite/runtime/entities/saveflow_entity_collection_source.gd")
const SaveFlowPrefabEntityFactoryScript := preload("res://addons/saveflow_lite/runtime/entities/saveflow_prefab_entity_factory.gd")
const SaveFlowNodeSourceScript := preload("res://addons/saveflow_lite/runtime/sources/saveflow_node_source.gd")
const SaveFlowIdentityScript := preload("res://addons/saveflow_lite/runtime/entities/saveflow_identity.gd")
const SaveableFixtureScript := preload("res://tests/runtime/fixtures/saveable_fixture.gd")
const AbilityStateFixtureScript := preload("res://tests/runtime/fixtures/ability_state_fixture.gd")
const DataSourceFixtureScript := preload("res://tests/runtime/fixtures/data_source_fixture.gd")
const CustomEntityFactoryFixtureScript := preload("res://tests/runtime/fixtures/custom_entity_factory_fixture.gd")
const SaveFlowScopeFixtureScript := preload("res://tests/runtime/fixtures/saveflow_scope_fixture.gd")
const BasicEntityFactoryFixtureScript := preload("res://tests/runtime/fixtures/basic_entity_factory_fixture.gd")
const CompositeEntityFactoryFixtureScript := preload("res://tests/runtime/fixtures/composite_entity_factory_fixture.gd")
const PlayerStateFixtureScript := preload("res://tests/runtime/fixtures/player_state_fixture.gd")
const SettingsStateFixtureScript := preload("res://tests/runtime/fixtures/settings_state_fixture.gd")
const SystemStateFixtureScript := preload("res://tests/runtime/fixtures/system_state_fixture.gd")
const ZeldaPlayerStateFixtureScript := preload("res://tests/runtime/fixtures/zelda_player_state_fixture.gd")

var _save
var _save_root: String
var _index_path: String
var _saveable_root: Node


func before_test() -> void:
	_save_root = create_temp_dir("saveflow_lite/runtime_%d" % Time.get_ticks_usec())
	_index_path = _save_root + "/slots.index"
	_save = SaveScript.new()
	_save.name = "SaveFlow"
	get_tree().root.add_child(_save)
	var settings: SaveSettings = SaveSettingsScript.new()
	settings.save_root = _save_root
	settings.slot_index_file = _index_path
	settings.auto_create_dirs = true
	settings.use_safe_write = true
	settings.pretty_json_in_editor = false
	assert_bool(_save.configure(settings).ok).is_true()


func after_test() -> void:
	if is_instance_valid(_save):
		_save.free()
	_save = null
	if is_instance_valid(_saveable_root):
		_saveable_root.free()
	_saveable_root = null


func test_save_and_load_json_payload() -> void:
	assert_bool(_save.set_storage_format(1).ok).is_true()
	var payload := {
		"player": {
			"hp": 100,
			"coins": 9,
		},
		"settings": {
			"language": "zh_CN",
		}
	}

	var save_result: SaveResult = _save.save_slot("json_slot", payload, {"game_version": "0.1.0"})
	assert_bool(save_result.ok).is_true()
	assert_bool(FileAccess.file_exists(_save_root + "/json_slot.json")).is_true()

	var load_result: SaveResult = _save.load_slot("json_slot")
	assert_bool(load_result.ok).is_true()
	assert_dict(load_result.data["data"]).is_equal(payload)
	assert_str(str(load_result.data["meta"]["slot_id"])).is_equal("json_slot")


func test_save_and_load_binary_payload() -> void:
	assert_bool(_save.set_storage_format(2).ok).is_true()
	var payload := {
		"player": {
			"position": Vector2(12, 24),
			"alive": true,
		},
	}

	var save_result: SaveResult = _save.save_slot("binary_slot", payload)
	assert_bool(save_result.ok).is_true()
	assert_bool(FileAccess.file_exists(_save_root + "/binary_slot.sav")).is_true()

	var load_result: SaveResult = _save.load_slot("binary_slot")
	assert_bool(load_result.ok).is_true()
	assert_dict(load_result.data["data"]).is_equal(payload)


func test_copy_rename_and_delete_slot() -> void:
	assert_bool(_save.set_storage_format(1).ok).is_true()
	assert_bool(_save.save_slot("slot_a", {"value": 1}).ok).is_true()

	var copy_result: SaveResult = _save.copy_slot("slot_a", "slot_b")
	assert_bool(copy_result.ok).is_true()
	assert_bool(_save.slot_exists("slot_b")).is_true()

	var rename_result: SaveResult = _save.rename_slot("slot_b", "slot_c")
	assert_bool(rename_result.ok).is_true()
	assert_bool(_save.slot_exists("slot_b")).is_false()
	assert_bool(_save.slot_exists("slot_c")).is_true()

	var list_result: SaveResult = _save.list_slots()
	assert_bool(list_result.ok).is_true()
	assert_int(list_result.data.size()).is_equal(2)

	var delete_result: SaveResult = _save.delete_slot("slot_c")
	assert_bool(delete_result.ok).is_true()
	assert_bool(_save.slot_exists("slot_c")).is_false()


func test_save_and_load_source_nodes() -> void:
	assert_bool(_save.set_storage_format(1).ok).is_true()
	_saveable_root = _build_saveable_root()
	add_child(_saveable_root)

	var save_result: SaveResult = _save.save_nodes("nodes_slot", _saveable_root, {"game_version": "0.1.0"})
	assert_bool(save_result.ok).is_true()

	var player: Node = _saveable_root.get_node("PlayerState")
	var settings: Node = _saveable_root.get_node("SettingsState")
	player.set("state", {"hp": 1, "coins": 0})
	settings.set("state", {"language": "en", "music": false})

	var load_result: SaveResult = _save.load_nodes("nodes_slot", _saveable_root)
	assert_bool(load_result.ok).is_true()
	assert_dict(player.get("state")).is_equal({"hp": 100, "coins": 9})
	assert_dict(settings.get("state")).is_equal({"language": "zh_CN", "music": true})

	var collect_result: SaveResult = _save.collect_nodes(_saveable_root)
	assert_bool(collect_result.ok).is_true()
	assert_int(collect_result.data.size()).is_equal(2)


func test_configure_with_and_node_source_scene_workflow() -> void:
	var configure_result: SaveResult = _save.configure_with(
		{
			"save_root": _save_root,
			"slot_index_file": _index_path,
			"auto_create_dirs": true,
			"use_safe_write": true,
			"pretty_json_in_editor": false,
			"storage_format": 1,
		}
	)
	assert_bool(configure_result.ok).is_true()

	_saveable_root = _build_component_root()
	add_child(_saveable_root)

	var save_result: SaveResult = _save.save_scene("scene_slot", _saveable_root, {"game_version": "0.1.0"})
	assert_bool(save_result.ok).is_true()

	var player: Node = _saveable_root.get_node("PlayerState")
	var settings: Node = _saveable_root.get_node("SettingsState")
	player.set("hp", 1)
	player.set("coins", 0)
	player.set("runtime_only", 77)
	settings.set("language", "en")
	settings.set("music_enabled", false)
	settings.set("master_volume", 0.1)
	settings.set("runtime_only", 12)

	var load_result: SaveResult = _save.load_scene("scene_slot", _saveable_root)
	assert_bool(load_result.ok).is_true()
	assert_int(player.get("hp")).is_equal(100)
	assert_int(player.get("coins")).is_equal(9)
	assert_int(player.get("runtime_only")).is_equal(77)
	assert_str(String(settings.get("language"))).is_equal("zh_CN")
	assert_bool(bool(settings.get("music_enabled"))).is_true()
	assert_float(float(settings.get("master_volume"))).is_equal(0.8)
	assert_int(settings.get("runtime_only")).is_equal(12)

	var collect_result: SaveResult = _save.collect_nodes(_saveable_root)
	assert_bool(collect_result.ok).is_true()
	assert_dict(Dictionary(collect_result.data["player"]["properties"])).is_equal({"hp": 100, "coins": 9})
	assert_dict(Dictionary(collect_result.data["settings"]["properties"])).is_equal(
		{
			"language": "zh_CN",
			"music_enabled": true,
			"master_volume": 0.8,
		}
	)

	var inspect_result: SaveResult = _save.inspect_scene(_saveable_root)
	assert_bool(inspect_result.ok).is_true()
	assert_bool(bool(inspect_result.data["valid"])).is_true()
	assert_int(int(inspect_result.data["entries"].size())).is_equal(2)


func test_node_source_restores_target_transform_and_child_animation_player() -> void:
	_saveable_root = Node.new()
	_saveable_root.name = "NodeSourceRoot"
	add_child(_saveable_root)

	var player := Node2D.new()
	player.name = "Player"
	player.set_script(ZeldaPlayerStateFixtureScript)
	player.call("reset_state")
	_saveable_root.add_child(player)

	var animation_player := AnimationPlayer.new()
	animation_player.name = "AnimationPlayer"
	animation_player.add_animation_library("", _build_animation_library(["idle", "run", "attack"]))
	player.add_child(animation_player)
	animation_player.play("run")
	animation_player.seek(0.35, true)

	var node_source := Node.new()
	node_source.name = "PlayerSource"
	node_source.set_script(SaveFlowNodeSourceScript)
	node_source.set("save_key", "player")
	node_source.set("target", player)
	node_source.set("included_paths", PackedStringArray(["AnimationPlayer"]))
	player.add_child(node_source)

	var participant_candidates: Array = node_source.call("discover_participant_candidates")
	assert_bool(participant_candidates.any(func(entry): return String(entry.get("path", "")) == "PlayerSource")).is_false()
	assert_bool(participant_candidates.any(func(entry): return String(entry.get("path", "")) == "AnimationPlayer")).is_true()

	assert_bool(_save.set_storage_format(1).ok).is_true()
	var collect_result: SaveResult = _save.collect_nodes(_saveable_root)
	assert_bool(collect_result.ok).is_true()
	var collected_payload: Dictionary = collect_result.data["player"]
	assert_bool(Dictionary(collected_payload.get("properties", {})).has("hearts")).is_true()
	assert_bool(collected_payload.has("participants")).is_true()
	var participant_payloads: Dictionary = Dictionary(collected_payload["participants"])
	assert_int(participant_payloads.size()).is_equal(1)
	var first_participant_payload: Dictionary = Dictionary(participant_payloads.values()[0])
	assert_bool(first_participant_payload.has("built_ins")).is_true()
	assert_bool(Dictionary(first_participant_payload["built_ins"]).has("animation_player")).is_true()

	player.position = Vector2(384, 192)
	player.set("hearts", 1)
	player.set("rupees", 3)
	animation_player.play("attack")
	animation_player.seek(0.65, true)
	animation_player.speed_scale = 1.5
	node_source.call("apply_save_data", collected_payload)
	assert_that(player.position).is_equal(Vector2(96, 72))
	assert_int(int(player.get("hearts"))).is_equal(5)
	assert_int(int(player.get("rupees"))).is_equal(136)
	assert_str(String(animation_player.current_animation)).is_equal("run")
	assert_float(float(animation_player.current_animation_position)).is_equal(0.35)
	assert_float(float(animation_player.speed_scale)).is_equal(1.0)

	player.call("reset_state")
	animation_player.play("run")
	animation_player.seek(0.35, true)
	animation_player.speed_scale = 1.0
	var save_result: SaveResult = _save.save_scene("node_source_slot", _saveable_root)
	assert_bool(save_result.ok).is_true()

	player.position = Vector2(384, 192)
	player.set("hearts", 1)
	player.set("rupees", 3)
	animation_player.play("attack")
	animation_player.seek(0.65, true)
	animation_player.speed_scale = 1.5

	var load_result: SaveResult = _save.load_scene("node_source_slot", _saveable_root)
	assert_bool(load_result.ok).is_true()
	assert_that(player.position).is_equal(Vector2(96, 72))
	assert_int(int(player.get("hearts"))).is_equal(5)
	assert_int(int(player.get("rupees"))).is_equal(136)
	assert_str(String(animation_player.current_animation)).is_equal("run")
	assert_float(float(animation_player.current_animation_position)).is_equal(0.35)
	assert_float(float(animation_player.speed_scale)).is_equal(1.0)


func test_duplicate_save_key_is_reported() -> void:
	_saveable_root = _build_component_root()
	add_child(_saveable_root)

	var duplicate_component := Node.new()
	duplicate_component.name = "DuplicatePlayerSave"
	duplicate_component.set_script(SaveFlowNodeSourceScript)
	duplicate_component.set("save_key", "player")
	_saveable_root.get_node("SettingsState").add_child(duplicate_component)

	var inspect_result: SaveResult = _save.inspect_scene(_saveable_root)
	assert_bool(inspect_result.ok).is_true()
	assert_bool(bool(inspect_result.data["valid"])).is_false()
	assert_that(inspect_result.data["duplicate_keys"]).contains("player")

	var collect_result: SaveResult = _save.collect_nodes(_saveable_root)
	assert_bool(collect_result.ok).is_false()
	assert_int(collect_result.error_code).is_equal(SaveError.DUPLICATE_SAVE_KEY)


func test_save_and_load_scope_graph_workflow() -> void:
	assert_bool(_save.set_storage_format(1).ok).is_true()
	_saveable_root = _build_scope_graph_root()
	add_child(_saveable_root)

	var graph_root: SaveFlowScope = _saveable_root.get_node("SaveGraphRoot")
	var save_context := {"events": []}
	var save_result: SaveResult = _save.save_scope("graph_slot", graph_root, {"game_version": "0.2.0"}, save_context)
	assert_bool(save_result.ok).is_true()
	assert_that(save_context["events"]).contains_exactly(
		["root:before_save", "player:before_save", "settings:before_save"]
	)

	var player: Node = _saveable_root.get_node("PlayerCore")
	var abilities: Node = _saveable_root.get_node("PlayerAbilities")
	var settings: Node = _saveable_root.get_node("SettingsState")
	player.set("hp", 5)
	player.set("coins", 1)
	abilities.set("cooldown_slot", 0)
	abilities.set("active_tags", PackedStringArray(["empty"]))
	settings.set("language", "en")
	settings.set("music_enabled", false)

	var load_context := {"events": []}
	var load_result: SaveResult = _save.load_scope("graph_slot", graph_root, true, load_context)
	assert_bool(load_result.ok).is_true()
	assert_that(load_context["events"]).contains_exactly(
		[
			"root:before_load",
			"player:before_load",
			"player:after_load",
			"settings:before_load",
			"settings:after_load",
			"root:after_load",
		]
	)

	assert_int(player.get("hp")).is_equal(100)
	assert_int(player.get("coins")).is_equal(9)
	assert_int(abilities.get("cooldown_slot")).is_equal(3)
	assert_that(abilities.get("active_tags")).is_equal(PackedStringArray(["dash", "parry"]))
	assert_str(String(settings.get("language"))).is_equal("zh_CN")
	assert_bool(bool(settings.get("music_enabled"))).is_true()

	var inspect_result: SaveResult = _save.inspect_scope(graph_root)
	assert_bool(inspect_result.ok).is_true()
	assert_bool(bool(inspect_result.data["valid"])).is_true()
	assert_int(int(inspect_result.data["entries"].size())).is_equal(2)


func test_restore_entities_delegates_to_registered_entity_factory() -> void:
	var provider := BasicEntityFactoryFixtureScript.new()
	var existing := Node.new()
	existing.name = "enemy_existing"
	provider.entities["enemy_existing"] = existing

	assert_bool(_save.register_entity_factory(provider).ok).is_true()
	var result: SaveResult = _save.restore_entities(
		[
			{
				"type_key": "enemy",
				"persistent_id": "enemy_existing",
				"payload": {"hp": 41},
			},
			{
				"type_key": "enemy",
				"persistent_id": "enemy_spawned",
				"payload": {"hp": 88},
			},
		],
		{},
		true
	)
	assert_bool(result.ok).is_true()
	assert_int(int(result.data["restored_count"])).is_equal(2)
	assert_int(int(result.data["spawned_count"])).is_equal(1)
	assert_dict(existing.get_meta("payload")).is_equal({"hp": 41})
	assert_dict(provider.entities["enemy_spawned"].get_meta("payload")).is_equal({"hp": 88})

	assert_bool(_save.clear_entity_factories().ok).is_true()
	for entity in provider.entities.values():
		if is_instance_valid(entity):
			entity.free()
	if is_instance_valid(provider):
		provider.free()


func test_entity_factory_delegates_to_custom_factory() -> void:
	var root := Node.new()
	root.name = "CustomEntityFactoryRoot"
	add_child(root)

	var binding := Node.new()
	binding.name = "EntityFactory"
	binding.set_script(CustomEntityFactoryFixtureScript)
	root.add_child(binding)

	var existing := Node.new()
	existing.name = "enemy_existing"
	root.add_child(existing)
	binding.set("entities", {"enemy_existing": existing})

	assert_bool(_save.register_entity_factory(binding).ok).is_true()
	var result: SaveResult = _save.restore_entities(
		[
			{
				"type_key": "enemy",
				"persistent_id": "enemy_existing",
				"payload": {"hp": 11},
			},
			{
				"type_key": "enemy",
				"persistent_id": "enemy_spawned",
				"payload": {"hp": 22},
			},
		],
		{},
		true
	)
	assert_bool(result.ok).is_true()
	assert_int(int(binding.get("spawn_count"))).is_equal(1)
	var spawned_entities: Dictionary = binding.get("entities")
	assert_bool(spawned_entities.has("enemy_spawned")).is_true()
	assert_dict(existing.get_meta("payload")).is_equal({"hp": 11})
	assert_dict(spawned_entities["enemy_spawned"].get_meta("payload")).is_equal({"hp": 22})

	assert_bool(_save.clear_entity_factories().ok).is_true()
	if is_instance_valid(root):
		root.free()


func test_entity_collection_restores_with_registered_entity_factory() -> void:
	var root := Node.new()
	root.name = "EntityCollectionRoot"
	add_child(root)

	var actor_container := Node.new()
	actor_container.name = "RuntimeActors"
	root.add_child(actor_container)

	var binding := Node.new()
	binding.name = "EntityFactory"
	binding.set_script(CustomEntityFactoryFixtureScript)
	root.add_child(binding)

	var collection := Node.new()
	collection.name = "EntityCollection"
	collection.set_script(SaveFlowEntityCollectionSourceScript)
	collection.set("source_key", "actors")
	collection.set("target_container", actor_container)
	collection.set("entity_factory", binding)
	root.add_child(collection)

	await get_tree().process_frame
	assert_bool(_save.register_entity_factory(binding).ok).is_true()

	var result: SaveResult = _save.restore_entities(
		[
			{
				"type_key": "enemy",
				"persistent_id": "enemy_auto_registered",
				"payload": {"hp": 17},
			}
		],
		{},
		true
	)
	assert_bool(result.ok).is_true()
	assert_int(int(binding.get("spawn_count"))).is_equal(1)

	if is_instance_valid(root):
		root.free()


func test_entity_collection_apply_existing_does_not_spawn_missing_entities() -> void:
	var root := Node.new()
	root.name = "EntityCollectionApplyExistingRoot"
	add_child(root)

	var actor_container := Node.new()
	actor_container.name = "RuntimeActors"
	root.add_child(actor_container)

	var factory := Node.new()
	factory.name = "EntityFactory"
	factory.set_script(CustomEntityFactoryFixtureScript)
	root.add_child(factory)

	var collection := Node.new()
	collection.name = "EntityCollection"
	collection.set_script(SaveFlowEntityCollectionSourceScript)
	collection.set("source_key", "actors")
	collection.set("target_container", actor_container)
	collection.set("entity_factory", factory)
	collection.set("failure_policy", SaveFlowEntityCollectionSourceScript.FailurePolicy.REPORT_ONLY)
	collection.set("restore_policy", SaveFlowEntityCollectionSource.RestorePolicy.APPLY_EXISTING)
	root.add_child(collection)

	await get_tree().process_frame
	assert_bool(_save.register_entity_factory(factory).ok).is_true()

	var result: SaveResult = collection.apply_save_data(
		{
			"descriptors": [
				{
					"type_key": "enemy",
					"persistent_id": "enemy_missing",
					"payload": {"hp": 17},
				}
			]
		},
		{}
	)

	assert_bool(result.ok).is_true()
	assert_int(int(factory.get("spawn_count"))).is_equal(0)
	assert_array(Array(result.data.get("failed_ids", []))).is_equal(["enemy_missing"])

	if is_instance_valid(root):
		root.free()


func test_load_scope_reports_missing_source_target_in_strict_mode() -> void:
	assert_bool(_save.set_storage_format(1).ok).is_true()
	_saveable_root = _build_scope_graph_root()
	add_child(_saveable_root)

	var graph_root: SaveFlowScope = _saveable_root.get_node("SaveGraphRoot")
	var save_result: SaveResult = _save.save_scope("graph_slot_missing_target", graph_root)
	assert_bool(save_result.ok).is_true()

	var player: Node = _saveable_root.get_node("PlayerCore")
	player.free()

	var load_result: SaveResult = _save.load_scope("graph_slot_missing_target", graph_root, true)
	assert_bool(load_result.ok).is_false()
	assert_int(load_result.error_code).is_equal(SaveError.INVALID_SAVEABLE)
	assert_that(load_result.meta["missing_keys"]).contains("source:core")


func test_save_and_load_data_source_inside_scope_graph() -> void:
	assert_bool(_save.set_storage_format(1).ok).is_true()
	_saveable_root = _build_data_source_scope_root()
	add_child(_saveable_root)

	var graph_root: SaveFlowScope = _saveable_root.get_node("SaveGraphRoot")
	var save_result: SaveResult = _save.save_scope("graph_slot_data_source", graph_root)
	assert_bool(save_result.ok).is_true()

	var system_state: Node = _saveable_root.get_node("WorldSystemState")
	system_state.set(
		"system_state",
		{
			"region_flags": {
				"bridge_open": true,
				"mail_sent": true,
			},
			"pending_events": ["late_game"],
		}
	)

	var load_result: SaveResult = _save.load_scope("graph_slot_data_source", graph_root, true)
	assert_bool(load_result.ok).is_true()
	assert_dict(system_state.get("system_state")).is_equal(
		{
			"region_flags": {
				"bridge_open": false,
				"mail_sent": false,
			},
			"pending_events": ["intro"],
		}
	)


func test_entity_collection_source_restores_by_identity_and_entity_factory() -> void:
	assert_bool(_save.set_storage_format(1).ok).is_true()
	_saveable_root = _build_entity_collection_scope_root()
	add_child(_saveable_root)

	var graph_root: SaveFlowScope = _saveable_root.get_node("SaveGraphRoot")
	var save_result: SaveResult = _save.save_scope("graph_slot_entities", graph_root)
	assert_bool(save_result.ok).is_true()
	var slot_result: SaveResult = _save.load_slot_data("graph_slot_entities")
	assert_bool(slot_result.ok).is_true()
	var slot_payload: Dictionary = slot_result.data
	var graph_payload: Dictionary = Dictionary(slot_payload.get("graph", {}))
	var root_entries: Array = Array(graph_payload.get("entries", []))
	assert_int(root_entries.size()).is_equal(1)
	var runtime_payload: Dictionary = root_entries[0]["data"]
	var runtime_entries: Array = Array(runtime_payload.get("entries", []))
	assert_int(runtime_entries.size()).is_equal(1)
	var collection_payload: Dictionary = runtime_entries[0]["data"]
	var descriptors: Array = Array(collection_payload.get("descriptors", []))
	assert_int(descriptors.size()).is_equal(2)
	assert_str(String(descriptors[0].get("persistent_id", ""))).is_equal("enemy_alpha")
	assert_str(String(descriptors[0].get("type_key", ""))).is_equal("enemy")
	assert_dict(Dictionary(descriptors[0].get("payload", {}))).is_equal(
		{
			"state": {"hp": 12},
		}
	)
	assert_str(String(descriptors[1].get("persistent_id", ""))).is_equal("enemy_beta")
	assert_str(String(descriptors[1].get("type_key", ""))).is_equal("enemy")
	assert_dict(Dictionary(descriptors[1].get("payload", {}))).is_equal(
		{
			"state": {"hp": 24},
		}
	)


func test_entity_collection_source_restores_nested_entity_scope_graph() -> void:
	assert_bool(_save.set_storage_format(1).ok).is_true()
	_saveable_root = _build_composite_entity_collection_scope_root()
	add_child(_saveable_root)

	var graph_root: SaveFlowScope = _saveable_root.get_node("SaveGraphRoot")
	var save_result: SaveResult = _save.save_scope("graph_slot_entities_nested", graph_root)
	assert_bool(save_result.ok).is_true()

	var slot_result: SaveResult = _save.load_slot_data("graph_slot_entities_nested")
	assert_bool(slot_result.ok).is_true()
	var graph_payload: Dictionary = Dictionary(slot_result.data.get("graph", {}))
	var root_entries: Array = Array(graph_payload.get("entries", []))
	var runtime_payload: Dictionary = root_entries[0]["data"]
	var runtime_entries: Array = Array(runtime_payload.get("entries", []))
	var collection_payload: Dictionary = runtime_entries[0]["data"]
	var descriptors: Array = Array(collection_payload.get("descriptors", []))
	assert_int(descriptors.size()).is_equal(2)
	assert_str(String(descriptors[0]["payload"].get("mode", ""))).is_equal("scope_graph")
	var first_graph: Dictionary = Dictionary(descriptors[0]["payload"].get("graph", {}))
	var first_entries: Array = Array(first_graph.get("entries", []))
	assert_int(first_entries.size()).is_equal(2)
	assert_str(String(first_entries[0].get("key", ""))).is_equal("core")
	assert_str(String(first_entries[1].get("key", ""))).is_equal("abilities")
	var core_payload: Dictionary = Dictionary(first_entries[0].get("data", {}))
	var abilities_payload: Dictionary = Dictionary(first_entries[1].get("data", {}))
	assert_dict(Dictionary(core_payload.get("properties", {}))).is_equal({"hp": 48, "coins": 12})
	assert_dict(Dictionary(abilities_payload.get("properties", {}))).is_equal(
		{
			"cooldown_slot": 2,
			"active_tags": PackedStringArray(["poison", "rush"]),
		}
	)


func test_prefab_entity_factory_auto_creates_container_and_restores_local_node_source() -> void:
	_saveable_root = Node.new()
	_saveable_root.name = "PrefabFactoryRoot"
	add_child(_saveable_root)

	var runtime_scope_root := Node.new()
	runtime_scope_root.name = "RuntimeScopeRoot"
	_saveable_root.add_child(runtime_scope_root)

	var entity_factory := Node.new()
	entity_factory.name = "PrefabFactory"
	entity_factory.set_script(SaveFlowPrefabEntityFactoryScript)
	entity_factory.set("type_key", "enemy")
	entity_factory.set("entity_scene", _build_prefab_entity_scene())
	entity_factory.set("auto_create_container", true)
	entity_factory.set("container_name", "SpawnedActors")
	runtime_scope_root.add_child(entity_factory)

	var entity_collection := Node.new()
	entity_collection.name = "EnemyCollection"
	entity_collection.set_script(SaveFlowEntityCollectionSourceScript)
	entity_collection.set("source_key", "enemies")
	entity_collection.set("entity_factory", entity_factory)
	runtime_scope_root.add_child(entity_collection)

	var spawned_entity := entity_factory.call(
		"spawn_entity_from_save",
		{
			"persistent_id": "enemy_alpha",
			"type_key": "enemy",
		},
		{}
	) as Node
	assert_object(spawned_entity).is_not_null()
	assert_object(spawned_entity.get_parent()).is_not_null()
	assert_str(spawned_entity.get_parent().name).is_equal("SpawnedActors")
	var spawned_identity := spawned_entity.get_node("Identity") as SaveFlowIdentity
	assert_object(spawned_identity).is_not_null()
	assert_str(spawned_identity.get_persistent_id()).is_equal("enemy_alpha")
	assert_str(spawned_identity.get_type_key()).is_equal("enemy")

	spawned_entity.set("hp", 24)
	spawned_entity.set("coins", 7)
	var gather_payload: Dictionary = entity_collection.call("gather_save_data")
	assert_int(Array(gather_payload.get("descriptors", [])).size()).is_equal(1)

	var container := entity_factory.call("get_target_container") as Node
	assert_object(container).is_not_null()
	for child in container.get_children():
		child.queue_free()
	await get_tree().process_frame

	var restore_result: SaveResult = entity_collection.call("apply_save_data", gather_payload, {})
	assert_bool(restore_result.ok).is_true()

	var restored_container := entity_factory.call("get_target_container") as Node
	assert_object(restored_container).is_not_null()
	assert_int(restored_container.get_child_count()).is_equal(1)

	var restored_entity := restored_container.get_child(0) as Node
	assert_object(restored_entity).is_not_null()
	assert_int(int(restored_entity.get("hp"))).is_equal(24)
	assert_int(int(restored_entity.get("coins"))).is_equal(7)
	var restored_identity := restored_entity.get_node("Identity") as SaveFlowIdentity
	assert_object(restored_identity).is_not_null()
	assert_str(restored_identity.get_persistent_id()).is_equal("enemy_alpha")


func _build_saveable_root() -> Node:
	var root := Node.new()
	root.name = "SandboxRoot"

	var player := Node.new()
	player.name = "PlayerState"
	player.set_script(SaveableFixtureScript)
	player.set("save_key", "player")
	player.set("state", {"hp": 100, "coins": 9})
	root.add_child(player)

	var settings := Node.new()
	settings.name = "SettingsState"
	settings.set_script(SaveableFixtureScript)
	settings.set("save_key", "settings")
	settings.set("state", {"language": "zh_CN", "music": true})
	root.add_child(settings)

	return root


func _build_data_source_scope_root() -> Node:
	var root := Node.new()
	root.name = "DataScopeRoot"

	var system_state := Node.new()
	system_state.name = "WorldSystemState"
	system_state.set_script(SystemStateFixtureScript)
	root.add_child(system_state)

	var graph_root := Node.new()
	graph_root.name = "SaveGraphRoot"
	graph_root.set_script(SaveFlowScopeFixtureScript)
	graph_root.set("scope_key", "root")
	graph_root.set("scope_label", "root")
	root.add_child(graph_root)

	var world_scope := Node.new()
	world_scope.name = "WorldScope"
	world_scope.set_script(SaveFlowScopeFixtureScript)
	world_scope.set("scope_key", "world")
	world_scope.set("scope_label", "world")
	graph_root.add_child(world_scope)

	var data_source := Node.new()
	data_source.name = "WorldDataSource"
	data_source.set_script(DataSourceFixtureScript)
	data_source.set("source_key", "world_state")
	data_source.set("target", system_state)
	world_scope.add_child(data_source)

	return root


func _build_entity_collection_scope_root() -> Node:
	var root := Node.new()
	root.name = "EntityCollectionRoot"

	var enemy_container := Node.new()
	enemy_container.name = "EnemyContainer"
	root.add_child(enemy_container)

	var enemy_alpha := _build_entity_node("EnemyAlpha", "enemy_alpha", 12)
	enemy_container.add_child(enemy_alpha)

	var enemy_beta := _build_entity_node("EnemyBeta", "enemy_beta", 24)
	enemy_container.add_child(enemy_beta)

	var graph_root := Node.new()
	graph_root.name = "SaveGraphRoot"
	graph_root.set_script(SaveFlowScopeFixtureScript)
	graph_root.set("scope_key", "root")
	graph_root.set("scope_label", "root")
	root.add_child(graph_root)

	var runtime_scope := Node.new()
	runtime_scope.name = "RuntimeScope"
	runtime_scope.set_script(SaveFlowScopeFixtureScript)
	runtime_scope.set("scope_key", "runtime")
	runtime_scope.set("scope_label", "runtime")
	graph_root.add_child(runtime_scope)

	var enemy_collection := Node.new()
	enemy_collection.name = "EnemyCollection"
	enemy_collection.set_script(SaveFlowEntityCollectionSourceScript)
	enemy_collection.set("source_key", "enemies")
	enemy_collection.set("target_container", enemy_container)
	enemy_collection.set("auto_register_factory", false)
	runtime_scope.add_child(enemy_collection)

	return root


func _build_composite_entity_collection_scope_root() -> Node:
	var root := Node.new()
	root.name = "CompositeEntityCollectionRoot"

	var enemy_container := Node.new()
	enemy_container.name = "EnemyContainer"
	root.add_child(enemy_container)

	enemy_container.add_child(
		_build_composite_entity_node(
			"EnemyAlpha",
			"enemy_alpha",
			48,
			12,
			2,
			PackedStringArray(["poison", "rush"])
		)
	)
	enemy_container.add_child(
		_build_composite_entity_node(
			"EnemyBeta",
			"enemy_beta",
			72,
			18,
			4,
			PackedStringArray(["guard"])
		)
	)

	var graph_root := Node.new()
	graph_root.name = "SaveGraphRoot"
	graph_root.set_script(SaveFlowScopeFixtureScript)
	graph_root.set("scope_key", "root")
	graph_root.set("scope_label", "root")
	root.add_child(graph_root)

	var runtime_scope := Node.new()
	runtime_scope.name = "RuntimeScope"
	runtime_scope.set_script(SaveFlowScopeFixtureScript)
	runtime_scope.set("scope_key", "runtime")
	runtime_scope.set("scope_label", "runtime")
	graph_root.add_child(runtime_scope)

	var enemy_collection := Node.new()
	enemy_collection.name = "EnemyCollection"
	enemy_collection.set_script(SaveFlowEntityCollectionSourceScript)
	enemy_collection.set("source_key", "enemies")
	enemy_collection.set("target_container", enemy_container)
	enemy_collection.set("auto_register_factory", false)
	runtime_scope.add_child(enemy_collection)

	return root


func _build_entity_node(node_name: String, persistent_id: String, hp: int) -> Node:
	var entity := Node.new()
	entity.name = node_name

	var identity := Node.new()
	identity.name = "Identity"
	identity.set_script(SaveFlowIdentityScript)
	identity.set("persistent_id", persistent_id)
	identity.set("type_key", "enemy")
	entity.add_child(identity)

	var state_source := Node.new()
	state_source.name = "State"
	state_source.set_script(SaveableFixtureScript)
	state_source.set("save_key", "state")
	state_source.set("state", {"hp": hp})
	entity.add_child(state_source)

	return entity


func _build_prefab_entity_scene() -> PackedScene:
	var entity := Node.new()
	entity.name = "RuntimeEnemy"
	entity.set_script(PlayerStateFixtureScript)

	var source := Node.new()
	source.name = "EnemyStateSource"
	source.set_script(SaveFlowNodeSourceScript)
	source.set("save_key", "enemy_state")
	entity.add_child(source)
	source.owner = entity

	var packed_scene := PackedScene.new()
	packed_scene.pack(entity)
	entity.free()
	return packed_scene


func _build_composite_entity_node(node_name: String, persistent_id: String, hp: int, coins: int, cooldown_slot: int, active_tags: PackedStringArray) -> Node:
	var entity := Node.new()
	entity.name = node_name

	var identity := Node.new()
	identity.name = "Identity"
	identity.set_script(SaveFlowIdentityScript)
	identity.set("persistent_id", persistent_id)
	identity.set("type_key", "enemy_composite")
	entity.add_child(identity)

	var core := Node.new()
	core.name = "CoreState"
	core.set_script(PlayerStateFixtureScript)
	core.set("hp", hp)
	core.set("coins", coins)
	entity.add_child(core)

	var abilities := Node.new()
	abilities.name = "AbilityState"
	abilities.set_script(AbilityStateFixtureScript)
	abilities.set("cooldown_slot", cooldown_slot)
	abilities.set("active_tags", active_tags)
	entity.add_child(abilities)

	var scope := Node.new()
	scope.name = "EntityScope"
	scope.set_script(SaveFlowScopeFixtureScript)
	scope.set("scope_key", "entity")
	scope.set("scope_label", persistent_id)
	entity.add_child(scope)

	var core_source := Node.new()
	core_source.name = "CoreSource"
	core_source.set_script(SaveFlowNodeSourceScript)
	core_source.set("save_key", "core")
	core_source.set("target", core)
	scope.add_child(core_source)

	var abilities_source := Node.new()
	abilities_source.name = "AbilitiesSource"
	abilities_source.set_script(SaveFlowNodeSourceScript)
	abilities_source.set("save_key", "abilities")
	abilities_source.set("target", abilities)
	scope.add_child(abilities_source)

	return entity


func _build_component_root() -> Node:
	var root := Node.new()
	root.name = "SceneRoot"

	var player := Node.new()
	player.name = "PlayerState"
	player.set_script(PlayerStateFixtureScript)
	player.set("hp", 100)
	player.set("coins", 9)
	root.add_child(player)

	var player_component := Node.new()
	player_component.name = "PlayerSource"
	player_component.set_script(SaveFlowNodeSourceScript)
	player_component.set("save_key", "player")
	player.add_child(player_component)

	var settings := Node.new()
	settings.name = "SettingsState"
	settings.set_script(SettingsStateFixtureScript)
	settings.set("language", "zh_CN")
	settings.set("music_enabled", true)
	settings.set("master_volume", 0.8)
	root.add_child(settings)

	var settings_component := Node.new()
	settings_component.name = "SettingsSource"
	settings_component.set_script(SaveFlowNodeSourceScript)
	settings_component.set("save_key", "settings")
	settings.add_child(settings_component)

	return root


func _build_scope_graph_root() -> Node:
	var root := Node.new()
	root.name = "SceneRoot"

	var player := Node.new()
	player.name = "PlayerCore"
	player.set_script(PlayerStateFixtureScript)
	player.set("hp", 100)
	player.set("coins", 9)
	root.add_child(player)

	var abilities := Node.new()
	abilities.name = "PlayerAbilities"
	abilities.set_script(AbilityStateFixtureScript)
	abilities.set("cooldown_slot", 3)
	abilities.set("active_tags", PackedStringArray(["dash", "parry"]))
	root.add_child(abilities)

	var settings := Node.new()
	settings.name = "SettingsState"
	settings.set_script(SettingsStateFixtureScript)
	settings.set("language", "zh_CN")
	settings.set("music_enabled", true)
	settings.set("master_volume", 0.8)
	root.add_child(settings)

	var graph_root := Node.new()
	graph_root.name = "SaveGraphRoot"
	graph_root.set_script(SaveFlowScopeFixtureScript)
	graph_root.set("scope_key", "root")
	graph_root.set("scope_label", "root")
	root.add_child(graph_root)

	var player_scope := Node.new()
	player_scope.name = "PlayerScope"
	player_scope.set_script(SaveFlowScopeFixtureScript)
	player_scope.set("scope_key", "player")
	player_scope.set("scope_label", "player")
	graph_root.add_child(player_scope)

	var player_source := Node.new()
	player_source.name = "PlayerSource"
	player_source.set_script(SaveFlowNodeSourceScript)
	player_source.set("save_key", "core")
	player_source.set("target", player)
	player_scope.add_child(player_source)

	var abilities_source := Node.new()
	abilities_source.name = "AbilitiesSource"
	abilities_source.set_script(SaveFlowNodeSourceScript)
	abilities_source.set("save_key", "abilities")
	abilities_source.set("target", abilities)
	player_scope.add_child(abilities_source)

	var settings_scope := Node.new()
	settings_scope.name = "SettingsScope"
	settings_scope.set_script(SaveFlowScopeFixtureScript)
	settings_scope.set("scope_key", "settings")
	settings_scope.set("scope_label", "settings")
	graph_root.add_child(settings_scope)

	var settings_source := Node.new()
	settings_source.name = "SettingsSource"
	settings_source.set_script(SaveFlowNodeSourceScript)
	settings_source.set("save_key", "prefs")
	settings_source.set("target", settings)
	settings_scope.add_child(settings_source)

	return root


func _build_animation_library(animation_names: Array) -> AnimationLibrary:
	var library := AnimationLibrary.new()
	for animation_name_variant in animation_names:
		var animation_name: String = String(animation_name_variant)
		var animation := Animation.new()
		animation.length = 0.8 if animation_name == "attack" else 1.0
		library.add_animation(animation_name, animation)
	return library
