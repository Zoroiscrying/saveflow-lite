class_name SaveFlowSerializerTileMapLayer
extends SaveFlowBuiltInSerializer


func get_serializer_id() -> String:
	return "tile_map_layer_cells"


func get_display_name() -> String:
	return "TileMapLayer Cells"


func supports_node(node: Node) -> bool:
	return node != null and node.is_class("TileMapLayer")


func gather_from_node(node: Node) -> Variant:
	if node == null:
		return {}
	var payload := {"cells": []}
	if not node.has_method("get_used_cells"):
		return payload
	var used_cells: Variant = node.call("get_used_cells")
	if not (used_cells is Array):
		return payload
	var serialized_cells: Array = []
	for cell_variant in used_cells:
		if not (cell_variant is Vector2i):
			continue
		var cell: Vector2i = cell_variant
		var source_id: int = int(node.call("get_cell_source_id", cell))
		if source_id < 0:
			continue
		var atlas_coords := Vector2i.ZERO
		if node.has_method("get_cell_atlas_coords"):
			atlas_coords = node.call("get_cell_atlas_coords", cell)
		var alternative_tile := 0
		if node.has_method("get_cell_alternative_tile"):
			alternative_tile = int(node.call("get_cell_alternative_tile", cell))
		serialized_cells.append(
			{
				"x": cell.x,
				"y": cell.y,
				"source_id": source_id,
				"atlas_x": atlas_coords.x,
				"atlas_y": atlas_coords.y,
				"alternative_tile": alternative_tile,
			}
		)
	payload["cells"] = serialized_cells
	return payload


func apply_to_node(node: Node, data: Variant) -> void:
	if node == null or not (data is Dictionary):
		return
	var payload: Dictionary = data
	if node.has_method("clear"):
		node.call("clear")
	var cells: Array = Array(payload.get("cells", []))
	for entry_variant in cells:
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		var coords := Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))
		var source_id := int(entry.get("source_id", -1))
		if source_id < 0:
			continue
		var atlas_coords := Vector2i(int(entry.get("atlas_x", 0)), int(entry.get("atlas_y", 0)))
		var alternative_tile := int(entry.get("alternative_tile", 0))
		if node.has_method("set_cell"):
			node.call("set_cell", coords, source_id, atlas_coords, alternative_tile)
