class_name SaveFlowSerializerTileMap
extends SaveFlowBuiltInSerializer


func get_serializer_id() -> String:
	return "tile_map_cells"


func get_display_name() -> String:
	return "TileMap Cells"


func supports_node(node: Node) -> bool:
	return node != null and node.is_class("TileMap")


func gather_from_node(node: Node) -> Variant:
	if node == null:
		return {}
	if not node.has_method("get_layers_count"):
		return {}
	var layer_count: int = int(node.call("get_layers_count"))
	var layers: Array = []
	for layer_index in layer_count:
		var cells: Array = _gather_layer_cells(node, layer_index)
		layers.append(
			{
				"layer": layer_index,
				"cells": cells,
			}
		)
	return {"layers": layers}


func apply_to_node(node: Node, data: Variant) -> void:
	if node == null or not (data is Dictionary):
		return
	var payload: Dictionary = data
	var layers: Array = Array(payload.get("layers", []))
	if node.has_method("clear"):
		node.call("clear")
	for layer_variant in layers:
		if not (layer_variant is Dictionary):
			continue
		var layer_payload: Dictionary = layer_variant
		var layer_index: int = int(layer_payload.get("layer", 0))
		var cells: Array = Array(layer_payload.get("cells", []))
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
				node.call("set_cell", layer_index, coords, source_id, atlas_coords, alternative_tile)


func _gather_layer_cells(node: Node, layer_index: int) -> Array:
	if not node.has_method("get_used_cells"):
		return []
	var used_cells_variant: Variant = node.call("get_used_cells", layer_index)
	if not (used_cells_variant is Array):
		return []
	var cells: Array = []
	for cell_variant in used_cells_variant:
		if not (cell_variant is Vector2i):
			continue
		var cell: Vector2i = cell_variant
		var source_id: int = int(node.call("get_cell_source_id", layer_index, cell))
		if source_id < 0:
			continue
		var atlas_coords := Vector2i.ZERO
		if node.has_method("get_cell_atlas_coords"):
			atlas_coords = node.call("get_cell_atlas_coords", layer_index, cell)
		var alternative_tile := 0
		if node.has_method("get_cell_alternative_tile"):
			alternative_tile = int(node.call("get_cell_alternative_tile", layer_index, cell))
		cells.append(
			{
				"x": cell.x,
				"y": cell.y,
				"source_id": source_id,
				"atlas_x": atlas_coords.x,
				"atlas_y": atlas_coords.y,
				"alternative_tile": alternative_tile,
			}
		)
	return cells
