extends Node3D

class_name CombatHexWallSystem

const CombatHexWallScript := preload("res://scripts/CombatHexWall.gd")

@export var wall_scene: PackedScene = preload("res://scenes/CombatHexWall.tscn")
@export var wall_extra_height: float = 1.0
@export var unit_height_reference: float = 1.45
@export var wall_thickness: float = 0.05
@export var wall_side_count: int = 2
@export var wall_container_path: NodePath

var hex_grid: Node = null
var _active_walls: Array[Node3D] = []


func start_combat(units_in_combat: Array, camera: Camera3D = null) -> void:
	end_combat()

	if hex_grid == null:
		push_warning("[CombatHexWallSystem] hex_grid is not assigned.")
		return
	if camera == null and hex_grid != null:
		camera = hex_grid.get_viewport().get_camera_3d()
	if camera == null:
		push_warning("[CombatHexWallSystem] No camera available to choose combat wall sides.")
		return

	var occupied_cells: Dictionary = {}
	for unit_value: Variant in units_in_combat:
		var unit: Unit = unit_value as Unit
		if unit == null:
			continue

		var cell: Vector2i = unit.get_hex_cell() if unit.has_method("get_hex_cell") else Vector2i(-1, -1)
		if cell == Vector2i(-1, -1) and hex_grid.has_method("get_cell_for_unit"):
			cell = hex_grid.call("get_cell_for_unit", unit)
		if cell == Vector2i(-1, -1):
			continue
		occupied_cells[cell] = true

	for cell_key: Variant in occupied_cells.keys():
		var cell: Vector2i = cell_key as Vector2i
		var hex_cell = hex_grid.call("get_hex_cell_data", cell.x, cell.y)
		if hex_cell == null:
			continue
		_generate_walls_for_hex(hex_cell, camera.global_transform.origin)


func end_combat() -> void:
	for wall: Node3D in _active_walls:
		if wall != null and is_instance_valid(wall):
			wall.queue_free()
	_active_walls.clear()


func _generate_walls_for_hex(hex_cell: HexCell3D, camera_world_pos: Vector3) -> void:
	var target_container: Node = _get_wall_container()
	var wall_height: float = unit_height_reference + wall_extra_height
	var selected_sides: Array[Dictionary] = hex_cell.get_camera_opposite_side_geometries(
		camera_world_pos,
		maxi(1, wall_side_count)
	)
	for side_geometry: Dictionary in selected_sides:
		var wall: Node3D = _instantiate_wall()
		if wall == null:
			continue
		target_container.add_child(wall)
		if wall.has_method("configure_from_side"):
			wall.call("configure_from_side", side_geometry, wall_height, wall_thickness)
		_active_walls.append(wall)


func _instantiate_wall() -> Node3D:
	if wall_scene != null:
		var instance: Node = wall_scene.instantiate()
		if instance is Node3D:
			return instance as Node3D
	var fallback_wall: Node3D = CombatHexWallScript.new()
	return fallback_wall


func _get_wall_container() -> Node:
	if wall_container_path != NodePath():
		var configured_container: Node = get_node_or_null(wall_container_path)
		if configured_container != null:
			return configured_container
	return self
