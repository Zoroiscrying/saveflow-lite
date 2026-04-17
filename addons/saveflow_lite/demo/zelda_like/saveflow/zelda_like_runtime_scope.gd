@tool
extends SaveFlowScope

@export var sandbox: Node
@export_storage var _sandbox_ref_path: NodePath = NodePath()


func _ready() -> void:
	_hydrate_sandbox_from_ref_path()


func before_load(payload: Dictionary = {}, context: Dictionary = {}) -> void:
	super.before_load(payload, context)
	var resolved_sandbox := _resolve_sandbox()
	if resolved_sandbox != null and resolved_sandbox.has_method("prepare_loaded_room_for_runtime_restore"):
		resolved_sandbox.call("prepare_loaded_room_for_runtime_restore")


func _resolve_sandbox() -> Node:
	if is_instance_valid(sandbox):
		if _sandbox_ref_path.is_empty():
			_sandbox_ref_path = _resolve_relative_node_path(sandbox)
		return sandbox
	if _sandbox_ref_path.is_empty():
		return null
	var resolved := get_node_or_null(_sandbox_ref_path)
	if is_instance_valid(resolved):
		return resolved
	return null


func _hydrate_sandbox_from_ref_path() -> void:
	var resolved := _resolve_sandbox()
	if is_instance_valid(resolved) and sandbox == null:
		sandbox = resolved


func _resolve_relative_node_path(node: Node) -> NodePath:
	if node == null:
		return NodePath()
	if not is_inside_tree() or not node.is_inside_tree():
		return NodePath()
	return get_path_to(node)
