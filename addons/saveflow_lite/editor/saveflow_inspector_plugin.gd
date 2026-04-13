@tool
extends EditorInspectorPlugin

const NodePreviewScript := preload("res://addons/saveflow_lite/editor/previews/saveflow_node_source_inspector_preview.gd")
const EntityCollectionPreviewScript := preload("res://addons/saveflow_lite/editor/previews/saveflow_entity_collection_inspector_preview.gd")
const EntityFactoryPreviewScript := preload("res://addons/saveflow_lite/editor/previews/saveflow_entity_factory_inspector_preview.gd")
const DataSourcePreviewScript := preload("res://addons/saveflow_lite/editor/previews/saveflow_data_source_inspector_preview.gd")
const ScopePreviewScript := preload("res://addons/saveflow_lite/editor/previews/saveflow_scope_inspector_preview.gd")


func _can_handle(object: Object) -> bool:
	return object is SaveFlowNodeSource or object is SaveFlowEntityCollectionSource or object is SaveFlowEntityFactory or object is SaveFlowDataSource or object is SaveFlowScope


func _parse_begin(object: Object) -> void:
	if object is SaveFlowNodeSource:
		var node_preview := NodePreviewScript.new()
		node_preview.set_node_source(object)
		add_custom_control(node_preview)
	elif object is SaveFlowScope:
		var scope_preview := ScopePreviewScript.new()
		scope_preview.set_scope(object)
		add_custom_control(scope_preview)
	elif object is SaveFlowDataSource:
		var data_source_preview := DataSourcePreviewScript.new()
		data_source_preview.set_data_source(object)
		add_custom_control(data_source_preview)
	elif object is SaveFlowEntityCollectionSource:
		var entity_collection_preview := EntityCollectionPreviewScript.new()
		entity_collection_preview.set_entity_collection_source(object)
		add_custom_control(entity_collection_preview)
	elif object is SaveFlowEntityFactory:
		var entity_factory_preview := EntityFactoryPreviewScript.new()
		entity_factory_preview.set_entity_factory(object)
		add_custom_control(entity_factory_preview)
