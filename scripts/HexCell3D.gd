extends RefCounted

class_name HexCell3D

const SIDE_COUNT: int = 6

var cell: Vector2i = Vector2i(-1, -1)
var tile_node: Node3D = null


func _init(p_cell: Vector2i = Vector2i(-1, -1), p_tile_node: Node3D = null) -> void:
	cell = p_cell
	tile_node = p_tile_node


func get_side_marker(side_index: int) -> Marker3D:
	if tile_node == null:
		return null
	return tile_node.get_node_or_null("edge[%d]" % posmod(side_index, SIDE_COUNT)) as Marker3D


func get_side_geometry(side_index: int) -> Dictionary:
	var marker: Marker3D = get_side_marker(side_index)
	if marker == null:
		return {}

	var side_length: float = float(marker.get_meta("side_length", 0.0))
	return {
		"cell": cell,
		"side_index": posmod(side_index, SIDE_COUNT),
		"marker": marker,
		"length": side_length,
		"transform": marker.global_transform,
	}


func get_center_world() -> Vector3:
	if tile_node == null:
		return Vector3.ZERO
	return tile_node.global_transform.origin


func get_camera_opposite_side_geometries(camera_world_pos: Vector3, side_count: int = 2) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if tile_node == null:
		return result

	var camera_dir: Vector3 = camera_world_pos - get_center_world()
	if camera_dir.length_squared() <= 0.0001:
		return result
	camera_dir = camera_dir.normalized()

	var scored_sides: Array[Dictionary] = []
	for side_index: int in range(SIDE_COUNT):
		var side_geometry: Dictionary = get_side_geometry(side_index)
		if side_geometry.is_empty():
			continue
		var marker: Marker3D = side_geometry.get("marker") as Marker3D
		if marker == null:
			continue
		var outward_normal: Vector3 = marker.global_transform.basis.z.normalized()
		scored_sides.append({
			"geometry": side_geometry,
			"score": outward_normal.dot(camera_dir),
		})

	scored_sides.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["score"]) < float(b["score"])
	)

	var max_count: int = mini(side_count, scored_sides.size())
	for index: int in range(max_count):
		result.append(scored_sides[index]["geometry"] as Dictionary)
	return result
