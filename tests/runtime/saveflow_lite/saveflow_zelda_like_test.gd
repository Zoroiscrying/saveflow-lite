extends GdUnitTestSuite

const SaveScript := preload("res://addons/saveflow_lite/runtime/core/save_flow.gd")
const SaveSettingsScript := preload("res://addons/saveflow_lite/runtime/types/save_settings.gd")
const SaveFlowEntityCollectionSourceScript := preload("res://addons/saveflow_lite/runtime/entities/saveflow_entity_collection_source.gd")
const SaveFlowNodeSourceScript := preload("res://addons/saveflow_lite/runtime/sources/saveflow_node_source.gd")
const SaveFlowScopeFixtureScript := preload("res://tests/runtime/fixtures/saveflow_scope_fixture.gd")
const SaveFlowIdentityScript := preload("res://addons/saveflow_lite/runtime/entities/saveflow_identity.gd")
const ZeldaPlayerStateFixtureScript := preload("res://tests/runtime/fixtures/zelda_player_state_fixture.gd")
const ZeldaRoomDataSourceFixtureScript := preload("res://tests/runtime/fixtures/zelda_room_data_source_fixture.gd")
const ZeldaRoomEntityFixtureScript := preload("res://tests/runtime/fixtures/zelda_room_entity_fixture.gd")
const ZeldaRoomEntityFactoryFixtureScript := preload("res://tests/runtime/fixtures/zelda_room_entity_factory_fixture.gd")
const ZeldaRoomRegistryFixtureScript := preload("res://tests/runtime/fixtures/zelda_room_registry_fixture.gd")

var _save
var _save_root: String
var _index_path: String
var _scenario_root: Node


func before_test() -> void:
	_save_root = create_temp_dir("saveflow_lite/zelda_like_%d" % Time.get_ticks_usec())
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
	assert_bool(_save.set_storage_format(1).ok).is_true()


func after_test() -> void:
	if is_instance_valid(_save):
		_save.free()
	_save = null
	if is_instance_valid(_scenario_root):
		_scenario_root.free()
	_scenario_root = null


func test_zelda_like_scope_restores_player_animation_world_tables_and_room_entities() -> void:
	_scenario_root = _build_zelda_like_root()
	add_child(_scenario_root)

	var room_entities: Node = _scenario_root.get_node("LoadedRoomEntities")
	var player: Node2D = _scenario_root.get_node("Player")
	var animation_player: AnimationPlayer = _scenario_root.get_node("Player/AnimationPlayer")
	var room_registry: Node = _scenario_root.get_node("RoomRegistry")
	var graph_root: SaveFlowScope = _scenario_root.get_node("SaveGraphRoot")

	var provider := ZeldaRoomEntityFactoryFixtureScript.new()
	provider.target_container = room_entities
	for entity in room_entities.get_children():
		var identity: Node = entity.get_node("Identity")
		provider.entities[String(identity.get("persistent_id"))] = entity
	assert_bool(_save.register_entity_factory(provider).ok).is_true()

	var baseline_save: SaveResult = _save.save_scope("zelda_like_slot", graph_root)
	assert_bool(baseline_save.ok).is_true()
	var slot_result: SaveResult = _save.load_slot_data("zelda_like_slot")
	assert_bool(slot_result.ok).is_true()
	var graph_payload: Dictionary = Dictionary(slot_result.data.get("graph", {}))
	var root_entries: Array = Array(graph_payload.get("entries", []))
	var runtime_scope_payload: Dictionary = {}
	for entry_variant in root_entries:
		var entry: Dictionary = entry_variant
		if String(entry.get("key", "")) == "runtime":
			runtime_scope_payload = Dictionary(entry.get("data", {}))
			break
	var runtime_entries: Array = Array(runtime_scope_payload.get("entries", []))
	assert_int(runtime_entries.size()).is_equal(1)
	var room_entities_payload: Dictionary = Dictionary(runtime_entries[0].get("data", {}))
	var room_entity_descriptors: Array = Array(room_entities_payload.get("descriptors", []))
	assert_int(room_entity_descriptors.size()).is_equal(2)

	player.position = Vector2(384, 192)
	player.set("current_room_id", "room_east")
	player.set("hearts", 1)
	player.set("stamina", 9.5)
	player.set("rupees", 3)
	player.set("equipped_items", {"sword": "rusty_blade", "shield": "none", "utility": "hookshot"})
	player.set("inventory_slots", ["apple"])
	player.set("visited_rooms_set", {"room_east": true})
	player.set("discovered_shortcuts", PackedStringArray(["east_to_basement"]))
	player.set("ability_cooldowns", {"dash": 8.0})

	animation_player.play("attack")
	animation_player.seek(0.65, true)
	animation_player.speed_scale = 1.75

	var mutated_registry := Dictionary(room_registry.get("system_state")).duplicate(true)
	mutated_registry["active_room_id"] = "room_east"
	mutated_registry["loaded_room_ids"] = PackedStringArray(["room_east"])
	mutated_registry["world_flags"] = {
		"boss_key_found": true,
		"courier_dispatched": false,
	}
	mutated_registry["room_states"]["room_basement"]["pending_deliveries"] = []
	mutated_registry["room_states"]["room_hub"]["opened_chests"] = ["hub_chest_1", "hub_chest_2"]
	room_registry.set("system_state", mutated_registry)

	var slime: Node2D = room_entities.get_node("SlimeHub01")
	slime.set("hp", 1)
	slime.set("tags_set", {"poisoned": true})

	var chest: Node2D = room_entities.get_node("HubChest01")
	provider.entities.erase("hub_chest_01")
	chest.free()

	var load_result: SaveResult = _save.load_scope("zelda_like_slot", graph_root, false)
	assert_object(load_result).is_not_null()

	assert_that(player.position).is_equal(Vector2(96, 72))
	assert_str(String(player.get("current_room_id"))).is_equal("room_hub")
	assert_int(int(player.get("hearts"))).is_equal(5)
	assert_float(float(player.get("stamina"))).is_equal(72.5)
	assert_int(int(player.get("rupees"))).is_equal(136)
	assert_dict(player.get("equipped_items")).is_equal(
		{
			"sword": "wood_blade",
			"shield": "pot_lid",
			"utility": "boomerang",
		}
	)
	assert_that(player.get("inventory_slots")).is_equal(["boomerang", "bomb", "small_key"])
	assert_dict(player.get("visited_rooms_set")).is_equal({"room_hub": true, "room_east": true})
	assert_that(player.get("discovered_shortcuts")).is_equal(PackedStringArray(["hub_to_east"]))
	assert_dict(player.get("ability_cooldowns")).is_equal({"dash": 0.4, "spin": 1.2})

	assert_str(String(animation_player.current_animation)).is_equal("run")
	assert_float(float(animation_player.current_animation_position)).is_equal(0.35)
	assert_float(float(animation_player.speed_scale)).is_equal(1.0)

	var restored_registry: Dictionary = Dictionary(room_registry.get("system_state"))
	assert_str(String(restored_registry["active_room_id"])).is_equal("room_hub")
	assert_that(restored_registry["loaded_room_ids"]).is_equal(PackedStringArray(["room_hub"]))
	assert_dict(restored_registry["world_flags"]).is_equal(
		{
			"boss_key_found": false,
			"courier_dispatched": true,
		}
	)
	assert_that(restored_registry["room_states"]["room_hub"]["opened_chests"]).is_equal(["hub_chest_1"])
	assert_that(restored_registry["room_states"]["room_basement"]["pending_deliveries"]).is_equal(["courier_package"])

	assert_bool(_save.clear_entity_factories().ok).is_true()
	if is_instance_valid(provider):
		provider.free()


func _build_zelda_like_root() -> Node:
	var root := Node.new()
	root.name = "ZeldaLikeRoot"

	var player := Node2D.new()
	player.name = "Player"
	player.set_script(ZeldaPlayerStateFixtureScript)
	player.call("reset_state")
	root.add_child(player)

	var animation_player := AnimationPlayer.new()
	animation_player.name = "AnimationPlayer"
	animation_player.add_animation_library("", _build_player_animation_library())
	player.add_child(animation_player)
	animation_player.play("run")
	animation_player.seek(0.35, true)

	var room_registry := Node.new()
	room_registry.name = "RoomRegistry"
	room_registry.set_script(ZeldaRoomRegistryFixtureScript)
	root.add_child(room_registry)

	var loaded_room_entities := Node.new()
	loaded_room_entities.name = "LoadedRoomEntities"
	root.add_child(loaded_room_entities)
	loaded_room_entities.add_child(
		_build_room_entity(
			"SlimeHub01",
			"hub_slime_01",
			"enemy",
			"room_hub",
			14,
			false,
			["slime_gel"],
			{"flying": false, "room_guard": true},
			PackedStringArray(["p0", "p1", "p2"]),
			Vector2(212, 88)
		)
	)
	loaded_room_entities.add_child(
		_build_room_entity(
			"HubChest01",
			"hub_chest_01",
			"chest",
			"room_hub",
			0,
			false,
			["map_fragment", "rupee_blue"],
			{"consumable": false, "reward": true},
			PackedStringArray(),
			Vector2(144, 64)
		)
	)

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

	var built_in_source := Node.new()
	built_in_source.name = "PlayerSource"
	built_in_source.set_script(SaveFlowNodeSourceScript)
	built_in_source.set("save_key", "player")
	built_in_source.set("target", player)
	built_in_source.set("included_paths", PackedStringArray(["AnimationPlayer"]))
	player_scope.add_child(built_in_source)

	var world_scope := Node.new()
	world_scope.name = "WorldScope"
	world_scope.set_script(SaveFlowScopeFixtureScript)
	world_scope.set("scope_key", "world")
	world_scope.set("scope_label", "world")
	graph_root.add_child(world_scope)

	var world_data_source := Node.new()
	world_data_source.name = "RoomRegistrySource"
	world_data_source.set_script(ZeldaRoomDataSourceFixtureScript)
	world_data_source.set("source_key", "room_registry")
	world_data_source.set("registry", room_registry)
	world_scope.add_child(world_data_source)

	var runtime_scope := Node.new()
	runtime_scope.name = "RuntimeScope"
	runtime_scope.set_script(SaveFlowScopeFixtureScript)
	runtime_scope.set("scope_key", "runtime")
	runtime_scope.set("scope_label", "runtime")
	graph_root.add_child(runtime_scope)

	var room_entities_source := Node.new()
	room_entities_source.name = "RoomEntitiesSource"
	room_entities_source.set_script(SaveFlowEntityCollectionSourceScript)
	room_entities_source.set("source_key", "loaded_room_entities")
	room_entities_source.set("target_container", loaded_room_entities)
	room_entities_source.set("auto_register_factory", false)
	runtime_scope.add_child(room_entities_source)

	return root


func _build_player_animation_library() -> AnimationLibrary:
	var library := AnimationLibrary.new()

	var idle := Animation.new()
	idle.length = 1.0
	library.add_animation("idle", idle)

	var run := Animation.new()
	run.length = 1.2
	library.add_animation("run", run)

	var attack := Animation.new()
	attack.length = 0.8
	library.add_animation("attack", attack)

	return library


func _build_room_entity(node_name: String, persistent_id: String, type_key: String, room_id: String, hp: int, is_open: bool, loot_table: Array, tags_set: Dictionary, patrol_route: PackedStringArray, start_position: Vector2) -> Node2D:
	var entity := Node2D.new()
	entity.name = node_name
	entity.set_script(ZeldaRoomEntityFixtureScript)
	entity.call(
		"reset_state",
		type_key,
		room_id,
		hp,
		is_open,
		loot_table,
		tags_set,
		patrol_route,
		start_position
	)

	var identity := Node.new()
	identity.name = "Identity"
	identity.set_script(SaveFlowIdentityScript)
	identity.set("persistent_id", persistent_id)
	identity.set("type_key", type_key)
	entity.add_child(identity)

	var state_source := Node.new()
	state_source.name = "State"
	state_source.set_script(SaveFlowNodeSourceScript)
	state_source.set("save_key", "state")
	entity.add_child(state_source)

	return entity
