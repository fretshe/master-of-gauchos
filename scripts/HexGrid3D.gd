extends Node3D

const HexCell3DScript      := preload("res://scripts/HexCell3D.gd")
const CombatHexWallSystemScript := preload("res://scripts/CombatHexWallSystem.gd")
const UnitRenderer3DScript := preload("res://scripts/UnitRenderer3D.gd")
const TowerScript          := preload("res://scripts/Tower.gd")
const MasterScript         := preload("res://scripts/Master.gd")
const TerrainShader        := preload("res://shaders/terrain.gdshader")
const TowerShader          := preload("res://shaders/tower.gdshader")
const CombatObstructionShader := preload("res://shaders/combat_obstruction.gdshader")
const GrassBladeTexture    := preload("res://assets/sprites/tiles/grass_blade.png")
const EssenceIconTexture   := preload("res://assets/sprites/ui/icon_essence.png")
const GRASS_TILE_TEXTURES: Array[Texture2D] = [
	preload("res://assets/sprites/tiles/grass_01.png"),
	preload("res://assets/sprites/tiles/grass_02.png"),
	preload("res://assets/sprites/tiles/grass_03.png"),
	preload("res://assets/sprites/tiles/grass_04.png"),
]
const FOREST_TILE_TEXTURES: Array[Texture2D] = [
	preload("res://assets/sprites/tiles/forest_01.png"),
	preload("res://assets/sprites/tiles/forest_02.png"),
	preload("res://assets/sprites/tiles/forest_03.png"),
	preload("res://assets/sprites/tiles/forest_04.png"),
]

# ─── Constants ──────────────────────────────────────────────────────────────────
var   COLS:     int   = 24
var   ROWS:     int   = 16
const HEX_SIZE: float = 1.0   # circumradius in world units

enum Terrain { GRASS, WATER, MOUNTAIN, FOREST, DESERT, VOLCANO, CORDILLERA }

const TERRAIN_COLORS: Dictionary = {
	0: Color(0.44, 0.76, 0.33),   # GRASS
	1: Color(0.20, 0.53, 0.87),   # WATER
	2: Color(0.60, 0.60, 0.60),   # MOUNTAIN
	3: Color(0.13, 0.45, 0.13),   # FOREST
	4: Color(0.76, 0.66, 0.34),   # DESERT
	5: Color(0.72, 0.18, 0.05),   # VOLCANO
	6: Color(0.20, 0.22, 0.26),   # CORDILLERA
}

const TERRAIN_HEIGHTS: Dictionary = {
	0: 0.12,   # GRASS
	1: 0.04,   # WATER
	2: 0.60,   # MOUNTAIN
	3: 0.26,   # FOREST
	4: 0.12,   # DESERT
	5: 0.44,   # VOLCANO
	6: 0.82,   # CORDILLERA
}

const OWNER_COLORS: Dictionary = {
	0: Color(0.70, 0.70, 0.70),
	1: Color(0.15, 0.40, 0.85),
	2: Color(0.85, 0.18, 0.18),
	3: Color(0.24, 0.88, 0.34),
	4: Color(1.00, 0.88, 0.24),
}

const C_GOLD   := Color(0.42, 0.88, 1.00)
const C_MOVE   := Color(0.25, 0.85, 0.25)
const C_ATTACK := Color(0.90, 0.18, 0.18)
const C_SUMMON := Color(0.70, 0.15, 0.90)
const TOWER_VISUAL_OFFSET := Vector3(-0.08, 0.0, -0.50)
const HEX_VISUAL_RADIUS_FACTOR: float = 0.96
const COMBAT_STAGE_WALL_EXTRA_HEIGHT: float = 1.0
const COMBAT_STAGE_WALL_UNIT_HEIGHT: float = 1.45
const COMBAT_STAGE_WALL_THICKNESS: float = 0.05
const COMBAT_STAGE_WALL_SIDE_COUNT: int = 2
const COMBAT_STAGE_WALL_ALPHA: float = 0.94
const ENEMY_TOWER_CAPTURE_EXP_REWARD: int = 1
const CLOUD_SHADOW_SCALE_LARGE: float = 0.07
const CLOUD_SHADOW_SCALE_SMALL: float = 0.12
const CLOUD_SHADOW_SPEED_LARGE: float = 0.022
const CLOUD_SHADOW_SPEED_SMALL: float = 0.030
const CLOUD_SHADOW_STRENGTH_LARGE: float = 0.32
const CLOUD_SHADOW_STRENGTH_SMALL: float = 0.38
const CLOUD_SHADOW_SOFTNESS: float = 0.11
const CLOUD_PIXEL_SIZE_LARGE: float = 0.34
const CLOUD_PIXEL_SIZE_SMALL: float = 0.22
const CLOUD_SUNBREAK_STRENGTH_LARGE: float = 0.08
const CLOUD_SUNBREAK_STRENGTH_SMALL: float = 0.11
const CLOUD_SUNBREAK_TINT: Color = Color(1.12, 1.06, 0.88, 1.0)

# Flat-top odd-q neighbor offsets
const NEIGHBORS_EVEN: Array = [
	Vector2i( 1, -1), Vector2i(1, 0),
	Vector2i( 0,  1), Vector2i(-1, 1),
	Vector2i(-1,  0), Vector2i(0, -1),
]
const NEIGHBORS_ODD: Array = [
	Vector2i( 1,  0), Vector2i(1, 1),
	Vector2i( 0,  1), Vector2i(-1, 1),
	Vector2i(-1,  0), Vector2i(0, -1),
]

# ─── Signals ────────────────────────────────────────────────────────────────────
signal unit_selected(unit: Unit)
signal unit_deselected()
signal tower_captured(tower_name: String, player_id: int)
signal placement_confirmed(col: int, row: int, unit_type: int, player_id: int)
signal master_killed(player_id: int)
signal master_placement_confirmed(col: int, row: int, unit_type: int, player_id: int)
signal enemy_inspected(enemy: Unit, multiplier: float)
signal combat_resolved(attacker: Unit, defender: Unit, result: Dictionary)
signal card_target_selected(card_index: int, target_unit: Unit)
signal card_tower_selected(card_index: int, tower_cell: Vector2i)
signal unit_hovered(unit: Unit)
signal unit_hover_cleared()
signal cell_hovered(cell: Vector2i)
signal cell_hover_cleared()

# ─── State ──────────────────────────────────────────────────────────────────────
var current_player:  int = 1
var combat_manager       = null
var resource_manager     = null
var camera_override: Camera3D = null
var _terrain_collision_shapes: Dictionary = {}   # terrain_int -> ConvexPolygonShape3D

var _map_terrain:    Array      = []
var _tile_instances: Dictionary = {}   # Vector2i → MeshInstance3D
var _tile_materials: Dictionary = {}   # Vector2i → StandardMaterial3D
var _terrain_meshes: Dictionary = {}   # terrain_int → CylinderMesh

var _unit_renderers: Dictionary = {}   # Vector2i → Node3D
var _units:          Dictionary = {}   # Vector2i → Unit
var _towers:         Dictionary = {}   # Vector2i → Tower
var _tower_instances: Dictionary = {}  # Vector2i → Node3D
var _team_rings:      Dictionary = {}  # Vector2i → MeshInstance3D
var _pending_tower_captures: Dictionary = {}  # Vector2i -> player_id

var _selected_cell:     Vector2i = Vector2i(-1, -1)
var _selected_unit:     Unit     = null
var _selected_renderer: Node3D   = null
var _move_cells:    Array    = []
var _attack_cells:  Array    = []
var _hovered_cell: Vector2i = Vector2i(-1, -1)
var _hovered_unit: Unit = null

var _highlighted_cells: Array[Vector2i] = []   # external/placement highlights
var _range_cells:       Array[Vector2i] = []   # internal selection/move/attack highlights
var _tutorial_ring: Node3D = null
var _tutorial_ring_material: StandardMaterial3D = null
var _tutorial_ring_cell: Vector2i = Vector2i(-1, -1)
var _move_outline_root: Node3D = null
var _move_outline_material: StandardMaterial3D = null
var _summon_outline_root: Node3D = null
var _summon_outline_material: StandardMaterial3D = null

var _animating: bool = false
var _is_night_visuals: bool = false
var _moon_visual_strength: float = 0.0
var _selection_focus_active: bool = false
var _grass_deco_container: Node3D = null
var _grass_blade_texture: Texture2D = null
var _grass_cluster_roots: Array[Node3D] = []
var _grass_cluster_base_positions: Array[Vector3] = []
var _grass_cluster_phases: Array[float] = []
var _grass_cluster_strengths: Array[float] = []
var _combat_stage_root: Node3D = null
var _combat_stage_tween: Tween = null
var _combat_wall_system: CombatHexWallSystem = null
const TILE_DIM_FACTOR_FOCUSED: float = 0.78

@export var combat_wall_scene: PackedScene = preload("res://scenes/CombatHexWall.tscn")
@export var combat_wall_extra_height: float = COMBAT_STAGE_WALL_EXTRA_HEIGHT
@export var combat_wall_unit_height: float = COMBAT_STAGE_WALL_UNIT_HEIGHT
@export var combat_wall_thickness: float = COMBAT_STAGE_WALL_THICKNESS
@export var combat_wall_side_count: int = COMBAT_STAGE_WALL_SIDE_COUNT
@export var combat_wall_container_path: NodePath

# Normal placement mode
var _placement_mode:        bool     = false
var _placement_type:        int      = -1
var _placement_player:      int      = 0
var _placement_master_cell: Vector2i = Vector2i(-1, -1)
var _placement_preview_renderer: Node3D = null
var _placement_preview_cell: Vector2i = Vector2i(-1, -1)

# Master free-summon placement mode
var _master_placement_mode: bool     = false
var _master_placement_cell: Vector2i = Vector2i(-1, -1)
var _card_target_mode: bool = false
var _card_target_player: int = 0
var _card_target_index: int = -1
var _card_target_type: String = ""
var _card_target_cells: Array[Vector2i] = []
var _card_target_towers: bool = false

var units_container: Node3D = null   # set by Main3D before setup_units()

# Shared outline next_pass materials (one per width — cached to avoid per-tile duplication)
var _terrain_outline_mat: StandardMaterial3D = null
var _tower_outline_mat:   StandardMaterial3D = null

# Inline outline shader: inverted-hull, expands only side normals (skips top/bottom faces)
const _OUTLINE_CODE: String = """shader_type spatial;
render_mode cull_front, unshaded;
uniform float outline_width : hint_range(0.0, 0.15) = 0.018;
void vertex() {
	if (abs(NORMAL.y) < 0.5) {
		vec3 side_n = normalize(vec3(NORMAL.x, 0.0, NORMAL.z));
		VERTEX += side_n * outline_width;
	}
}
void fragment() { ALBEDO = vec3(0.0); }
"""

# ─── Public API ─────────────────────────────────────────────────────────────────
func hex_to_world(col: int, row: int) -> Vector3:
	var x: float = HEX_SIZE * 1.5 * float(col)
	var z: float = HEX_SIZE * sqrt(3.0) * (float(row) + (0.5 if col % 2 == 1 else 0.0))
	return Vector3(x, 0.0, z)

func get_map_center() -> Vector3:
	var cx: float = HEX_SIZE * 1.5 * float(COLS - 1) * 0.5
	var cz: float = HEX_SIZE * sqrt(3.0) * float(ROWS - 1) * 0.5
	return Vector3(cx, 0.0, cz)

func world_to_hex(world_pos: Vector3) -> Vector2i:
	var best:      Vector2i = Vector2i(-1, -1)
	var best_dist: float    = HEX_SIZE * 2.0
	for c: int in range(COLS):
		for r: int in range(ROWS):
			var wc: Vector3 = hex_to_world(c, r)
			var d:  float   = Vector2(world_pos.x - wc.x, world_pos.z - wc.z).length()
			if d < best_dist:
				best_dist = d
				best = Vector2i(c, r)
	return best

func place_unit(unit: Unit, col: int, row: int, defer_tower_capture: bool = false) -> void:
	var cell:      Vector2i = Vector2i(col, row)
	var world_pos: Vector3  = hex_to_world(col, row)
	var terrain:   int      = _map_terrain[row][col] as int
	var base_y:    float    = TERRAIN_HEIGHTS.get(terrain, 0.12)

	# hex tile: CylinderMesh centered at hex_h/2, so top surface = hex_h = base_y
	var hex_top_y: float = base_y

	var renderer: Node3D = UnitRenderer3DScript.new()
	renderer.call("setup", unit)
	renderer.position = Vector3(world_pos.x, hex_top_y, world_pos.z)

	var container: Node3D = units_container if units_container != null else self
	container.add_child(renderer)

	_unit_renderers[cell] = renderer
	_units[cell]          = unit
	unit.set_hex_cell(cell)
	_add_team_ring(cell, unit.owner_id)
	_update_team_ring_state(cell, unit)

	var tower: Tower = _towers.get(cell, null)
	if tower != null and tower.owner_id != unit.owner_id:
		if defer_tower_capture:
			_pending_tower_captures[cell] = unit.owner_id
		else:
			# Immediate capture — happens right when the unit is placed (summon on tower)
			var previous_owner_id: int = tower.owner_id
			var capture_bonus: int = tower.capture(unit.owner_id)
			if resource_manager != null and capture_bonus > 0:
				resource_manager.add_essence(unit.owner_id, capture_bonus)
			var tower_exp_reward: int = (ENEMY_TOWER_CAPTURE_EXP_REWARD if previous_owner_id > 0 else 0) + (2 if unit.bonus_raider else 0)
			var exp_result: Dictionary = unit.gain_exp_with_result(tower_exp_reward)
			var placed_renderer: Node3D = _unit_renderers.get(cell, null)
			if placed_renderer != null and placed_renderer.has_method("set_health_bar_values"):
				placed_renderer.call("set_health_bar_values", unit.hp, unit.max_hp, true)
			_update_tower_visual(cell)
			emit_signal("tower_captured", tower.tower_name, unit.owner_id)
			AudioManager.play_capture()
			if capture_bonus > 0:
				AudioManager.play_essence()
			if int(exp_result.get("gained", 0)) > 0:
				VFXManager.show_world_text_label(
					_get_unit_world_anchor(cell),
					"+%d XP" % int(exp_result.get("gained", 0)),
					Color(0.84, 0.42, 1.0, 1.0),
					48, 1.85
				)

func get_unit_at(col: int, row: int) -> Unit:
	return _units.get(Vector2i(col, row), null)

func get_all_units() -> Array:
	return _units.values()

func _sanitize_loaded_attack_range(unit: Unit, saved_attack_range: int) -> int:
	var default_attack_range: int = unit.get_default_attack_range()
	if not unit.has_ranged_attack():
		return 1
	return maxi(default_attack_range, saved_attack_range)

func get_neighbors_of(cell: Vector2i) -> Array:
	return _get_neighbors(cell.x, cell.y)

func get_hex_distance(a: Vector2i, b: Vector2i) -> int:
	return _hex_distance(a, b)

func get_all_towers() -> Array:
	return _towers.values()

func get_enemy_units_near_towers(player_id: int) -> Array:
	var result: Array = []
	for cell_value: Variant in _towers.keys():
		var cell: Vector2i = cell_value as Vector2i
		var tower: Tower = _towers.get(cell, null)
		if tower == null or tower.owner_id != player_id:
			continue
		for nb: Vector2i in _get_neighbors(cell.x, cell.y):
			var unit: Unit = _units.get(nb, null)
			if unit != null and unit.owner_id != player_id and unit not in result:
				result.append(unit)
	return result

func get_terrain_at(col: int, row: int) -> int:
	if row < 0 or row >= _map_terrain.size():
		return -1
	var terrain_row: Array = _map_terrain[row] as Array
	if col < 0 or col >= terrain_row.size():
		return -1
	return int(terrain_row[col])

func get_tower_at(col: int, row: int) -> Tower:
	return _towers.get(Vector2i(col, row), null)

func set_tower_special_effect(cell: Vector2i, effect_type: String, effect_owner_id: int, effect_value: int) -> void:
	var tower: Tower = _towers.get(cell, null)
	if tower == null:
		return
	tower.set_special_effect(effect_type, effect_owner_id, effect_value)
	_update_tower_visual(cell)

func clear_tower_special_effect(cell: Vector2i) -> void:
	var tower: Tower = _towers.get(cell, null)
	if tower == null:
		return
	tower.clear_special_effect()
	_update_tower_visual(cell)

func resolve_end_turn_tower_captures(player_id: int) -> void:
	var pending_cells: Array[Vector2i] = []
	for cell_value: Variant in _pending_tower_captures.keys():
		var cell: Vector2i = cell_value as Vector2i
		if int(_pending_tower_captures.get(cell, 0)) == player_id:
			pending_cells.append(cell)
	for cell: Vector2i in pending_cells:
		_pending_tower_captures.erase(cell)
		var unit: Unit = _units.get(cell, null)
		var tower: Tower = _towers.get(cell, null)
		if unit == null or tower == null:
			continue
		if unit.owner_id != player_id or tower.owner_id == unit.owner_id:
			continue
		var previous_owner_id: int = tower.owner_id
		var capture_bonus: int = tower.capture(unit.owner_id)
		if resource_manager != null and capture_bonus > 0:
			resource_manager.add_essence(unit.owner_id, capture_bonus)
		var tower_exp_reward: int = (ENEMY_TOWER_CAPTURE_EXP_REWARD if previous_owner_id > 0 else 0) + (2 if unit.bonus_raider else 0)
		var exp_result: Dictionary = unit.gain_exp_with_result(tower_exp_reward)
		var renderer: Node3D = _unit_renderers.get(cell, null)
		if renderer != null and renderer.has_method("set_health_bar_values"):
			renderer.call("set_health_bar_values", unit.hp, unit.max_hp, true)
		_update_tower_visual(cell)
		emit_signal("tower_captured", tower.tower_name, unit.owner_id)
		AudioManager.play_capture()
		if capture_bonus > 0:
			AudioManager.play_essence()
		if int(exp_result.get("gained", 0)) > 0:
			VFXManager.show_world_text_label(
				_get_unit_world_anchor(cell),
				"+%d XP" % int(exp_result.get("gained", 0)),
				Color(0.84, 0.42, 1.0, 1.0),
				48,
				1.85
			)

func heal_units_on_owned_towers(player_id: int, amount: int = 1) -> int:
	var healed_count: int = 0
	for cell_value: Variant in _towers.keys():
		var cell: Vector2i = cell_value as Vector2i
		var tower: Tower = _towers.get(cell, null)
		if tower == null or tower.owner_id != player_id:
			continue
		var unit: Unit = _units.get(cell, null)
		if unit == null or unit.owner_id != player_id:
			continue
		if unit.hp >= unit.max_hp:
			continue
		unit.hp = mini(unit.max_hp, unit.hp + amount)
		var renderer: Node3D = _unit_renderers.get(cell, null)
		if renderer != null and renderer.has_method("set_health_bar_values"):
			renderer.call("set_health_bar_values", unit.hp, unit.max_hp, true)
		VFXManager.show_world_text_label(
			_get_unit_world_anchor(cell),
			"Curación +%d" % amount,
			Color(0.28, 1.0, 0.36, 1.0),
			46,
			1.55
		)
		healed_count += 1
	return healed_count

func heal_unit_on_cell(cell: Vector2i, amount: int) -> void:
	var unit: Unit = _units.get(cell, null)
	if unit == null or unit.hp >= unit.max_hp:
		return
	unit.hp = mini(unit.max_hp, unit.hp + amount)
	var renderer: Node3D = _unit_renderers.get(cell, null)
	if renderer != null and renderer.has_method("set_health_bar_values"):
		renderer.call("set_health_bar_values", unit.hp, unit.max_hp, true)
	VFXManager.show_world_text_label(
		_get_unit_world_anchor(cell),
		"Curación +%d" % amount,
		Color(0.28, 1.0, 0.36, 1.0),
		46,
		1.55
	)

func get_units_for_player(player_id: int) -> Array[Unit]:
	var result: Array[Unit] = []
	for unit_value: Variant in _units.values():
		var unit: Unit = unit_value as Unit
		if unit != null and unit.owner_id == player_id:
			result.append(unit)
	return result

func get_valid_summon_cells(player_id: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var master_cell: Vector2i = _find_master_cell(player_id)
	if master_cell == Vector2i(-1, -1):
		return result
	for nb_value: Variant in _get_neighbors(master_cell.x, master_cell.y):
		var nb: Vector2i = nb_value as Vector2i
		if _is_valid_summon_cell(nb):
			result.append(nb)
	return result

func get_action_options_for_unit(unit: Unit) -> Dictionary:
	var cell: Vector2i = get_cell_for_unit(unit)
	if cell == Vector2i(-1, -1) or unit == null:
		return {"cell": Vector2i(-1, -1), "move_cells": [], "attack_cells": []}
	var saved_move: Array = _move_cells.duplicate()
	var saved_attack: Array = _attack_cells.duplicate()
	_compute_highlights(cell.x, cell.y, unit)
	var result := {
		"cell": cell,
		"move_cells": _move_cells.duplicate(),
		"attack_cells": _attack_cells.duplicate(),
	}
	_move_cells = saved_move
	_attack_cells = saved_attack
	return result

func get_distance_between_cells(a: Vector2i, b: Vector2i) -> int:
	return _hex_distance(a, b)

func execute_ai_move(unit: Unit, to_cell: Vector2i) -> void:
	var from_cell: Vector2i = get_cell_for_unit(unit)
	if from_cell == Vector2i(-1, -1):
		return
	await _move_unit(from_cell, to_cell)

func execute_ai_attack(attacker: Unit, defender: Unit) -> void:
	var attacker_cell: Vector2i = get_cell_for_unit(attacker)
	var defender_cell: Vector2i = get_cell_for_unit(defender)
	if attacker_cell == Vector2i(-1, -1) or defender_cell == Vector2i(-1, -1):
		return
	await _initiate_combat(attacker_cell, defender_cell)

func refresh_unit_action_indicators() -> void:
	for cell_value: Variant in _units.keys():
		var cell: Vector2i = cell_value as Vector2i
		var unit: Unit = _units.get(cell)
		if unit != null:
			_update_team_ring_state(cell, unit)

func remove_units_for_player(player_id: int) -> void:
	var to_remove: Array[Vector2i] = []
	for cell_value: Variant in _units.keys():
		var cell: Vector2i = cell_value as Vector2i
		var unit: Unit = _units.get(cell)
		if unit != null and unit.owner_id == player_id:
			to_remove.append(cell)
	for cell: Vector2i in to_remove:
		var renderer: Node3D = _unit_renderers.get(cell)
		if renderer != null:
			renderer.queue_free()
		_remove_team_ring(cell)
		_unit_renderers.erase(cell)
		var unit: Unit = _units.get(cell)
		_units.erase(cell)
		if unit != null:
			unit.clear_hex_cell()
			unit.free()
	if _selected_unit != null and _selected_unit.owner_id == player_id:
		_deselect()

func get_selected_unit() -> Unit:
	return _selected_unit

func is_attack_target_cell(cell: Vector2i) -> bool:
	return cell in _attack_cells

func get_selected_cell() -> Vector2i:
	return _selected_cell

func get_cell_for_unit(unit: Unit) -> Vector2i:
	if unit != null and unit.get_hex_cell() != Vector2i(-1, -1):
		return unit.get_hex_cell()
	for cell_value: Variant in _units.keys():
		var cell: Vector2i = cell_value as Vector2i
		if _units.get(cell) == unit:
			return cell
	return Vector2i(-1, -1)

func get_unit_world_position(unit: Unit) -> Vector3:
	var cell: Vector2i = get_cell_for_unit(unit)
	if cell == Vector2i(-1, -1):
		return Vector3.ZERO
	var renderer: Node3D = _unit_renderers.get(cell, null)
	if renderer != null:
		return renderer.global_position
	return _get_unit_world_anchor(cell)

func get_unit_renderer(unit: Unit) -> Node3D:
	var cell: Vector2i = get_cell_for_unit(unit)
	if cell == Vector2i(-1, -1):
		return null
	return _unit_renderers.get(cell, null)

func remove_unit(unit: Unit) -> void:
	var cell: Vector2i = get_cell_for_unit(unit)
	if cell == Vector2i(-1, -1):
		return
	var renderer: Node3D = _unit_renderers.get(cell)
	if renderer != null:
		renderer.queue_free()
	_remove_team_ring(cell)
	_unit_renderers.erase(cell)
	_units.erase(cell)
	if _selected_unit == unit:
		_deselect()
	unit.clear_hex_cell()
	unit.free()

func deselect() -> void:
	_deselect()

func enter_placement_mode(unit_type: int, player_id: int) -> void:
	_placement_mode        = true
	_placement_type        = unit_type
	_placement_player      = player_id
	_placement_master_cell = _find_master_cell(player_id)
	_deselect()
	_set_selection_focus(true)
	_show_placement_hints()
	print("[HexGrid3D] Placement mode — click adjacent to your Master to summon.")

func exit_placement_mode() -> void:
	if not _placement_mode:
		return
	_placement_mode        = false
	_placement_type        = -1
	_placement_master_cell = Vector2i(-1, -1)
	_clear_placement_preview()
	clear_highlights()
	_set_selection_focus(false)

func enter_master_placement_mode(unit_type: int, player_id: int, master_cell: Vector2i) -> void:
	_master_placement_mode = true
	_placement_type        = unit_type
	_placement_player      = player_id
	_master_placement_cell = master_cell
	_deselect()
	_set_selection_focus(true)
	_show_master_placement_hints()
	print("[HexGrid3D] Master placement mode — click adjacent cell for free summon.")

func exit_master_placement_mode() -> void:
	if not _master_placement_mode:
		return
	_master_placement_mode = false
	_master_placement_cell = Vector2i(-1, -1)
	_placement_type        = -1
	_clear_placement_preview()
	clear_highlights()
	_set_selection_focus(false)

func enter_card_target_mode(player_id: int, card_index: int, card: Dictionary) -> void:
	exit_placement_mode()
	exit_master_placement_mode()
	_deselect()
	_exit_card_target_mode()

	_card_target_mode = true
	_card_target_player = player_id
	_card_target_index = card_index
	if str(card.get("type", "")) == "faction":
		_card_target_type = str(card.get("effect", ""))
	else:
		_card_target_type = str(card.get("type", ""))
	_set_selection_focus(true)
	clear_highlights()
	_card_target_cells.clear()

	if _card_target_type == "tower_heal":
		_card_target_towers = true
		for cell_value: Variant in _towers.keys():
			var cell: Vector2i = cell_value as Vector2i
			var tower: Tower = _towers.get(cell, null)
			if tower == null or tower.owner_id != player_id:
				continue
			_card_target_cells.append(cell)
			_set_highlight(cell, true, "card_tower_heal")
			_highlighted_cells.append(cell)
			_set_tower_target_glow(cell, true)
		return

	for unit_value: Variant in _units.values():
		var unit: Unit = unit_value as Unit
		if unit == null:
			continue
		var valid: bool = false
		match _card_target_type:
			"heal":
				valid = unit.owner_id == player_id and unit.hp < unit.max_hp
			"exp":
				valid = unit.owner_id == player_id
			"refresh":
				valid = unit.owner_id == player_id and (unit.moved or unit.has_attacked)
			"damage":
				valid = unit.owner_id != player_id and not (unit is Master)
			"immobilize", "poison", "attack_debuff":
				valid = unit.owner_id != player_id and not (unit is Master)
			"swap_hp":
				valid = unit.owner_id != player_id and not (unit is Master)
			"extra_move":
				valid = unit.owner_id == player_id and not unit.moved
			"double_attack":
				valid = unit.owner_id == player_id and not unit.has_attacked
			"defense_buff", "untargetable":
				valid = unit.owner_id == player_id
		if not valid:
			continue
		var cell: Vector2i = get_cell_for_unit(unit)
		if cell == Vector2i(-1, -1):
			continue
		_card_target_cells.append(cell)
		_set_highlight(cell, true, "card_" + _card_target_type)
		_highlighted_cells.append(cell)
		var renderer: Node3D = _unit_renderers.get(cell)
		if renderer != null and renderer.has_method("set_card_target_highlight"):
			renderer.call("set_card_target_highlight", true, _card_target_color())

func exit_card_target_mode() -> void:
	_exit_card_target_mode()

func highlight_cells(cells: Array, mode: String) -> void:
	for item: Variant in cells:
		if not (item is Vector2i):
			continue
		var cell: Vector2i = item as Vector2i
		if not _tile_materials.has(cell):
			continue
		_set_highlight(cell, true, mode)
		_highlighted_cells.append(cell)

func clear_highlights() -> void:
	for cell: Vector2i in _highlighted_cells:
		if cell != _selected_cell:
			_set_highlight(cell, false)
	_highlighted_cells.clear()
	_clear_summon_outline()

func set_tutorial_focus_cell(cell: Vector2i) -> void:
	if not _tile_materials.has(cell):
		clear_tutorial_focus_cell()
		return
	if _tutorial_ring_cell == cell and _tutorial_ring != null:
		if cell not in _highlighted_cells:
			_highlighted_cells.append(cell)
		_set_highlight(cell, true, "tutorial")
		return
	clear_tutorial_focus_cell()
	_tutorial_ring_cell = cell
	_ensure_tutorial_focus_ring()
	_update_tutorial_focus_ring()
	_tutorial_ring.visible = true
	_set_highlight(cell, true, "tutorial")
	if cell not in _highlighted_cells:
		_highlighted_cells.append(cell)

func clear_tutorial_focus_cell() -> void:
	if _tutorial_ring_cell != Vector2i(-1, -1):
		_set_highlight(_tutorial_ring_cell, false)
		_highlighted_cells.erase(_tutorial_ring_cell)
	_tutorial_ring_cell = Vector2i(-1, -1)
	if _tutorial_ring != null:
		_tutorial_ring.visible = false

func _card_target_color() -> Color:
	match _card_target_type:
		"heal":
			return Color(0.18, 0.84, 0.76, 1.0)
		"refresh":
			return Color(1.0, 0.84, 0.28, 1.0)
		"damage":
			return Color(0.96, 0.28, 0.28, 1.0)
		"exp":
			return Color(0.78, 0.34, 0.96, 1.0)
		"immobilize", "poison", "attack_debuff", "swap_hp":
			return Color(0.94, 0.34, 0.22, 1.0)
		"extra_move", "double_attack", "defense_buff", "untargetable":
			return Color(0.94, 0.74, 0.22, 1.0)
		"tower_heal":
			return Color(1.0, 0.82, 0.18, 1.0)
		_:
			return Color(1.0, 1.0, 1.0, 1.0)

## No-op stub — SummonManager calls queue_redraw() on hex_grid after place_unit.
func queue_redraw() -> void:
	pass

## Called by Main3D after units_container is assigned.
func setup_units() -> void:
	_place_masters()

func serialize_state() -> Dictionary:
	var units: Array[Dictionary] = []
	for cell_value: Variant in _units.keys():
		var cell: Vector2i = cell_value as Vector2i
		var unit: Unit = _units.get(cell, null)
		if unit == null:
			continue
		var unit_data: Dictionary = {
			"cell": cell,
			"unit_name": unit.unit_name,
			"unit_type": unit.unit_type,
			"owner_id": unit.owner_id,
			"level": unit.level,
			"experience": unit.experience,
			"hp": unit.hp,
			"max_hp": unit.max_hp,
			"move_range": unit.move_range,
			"attack_range": unit.attack_range,
			"active_bonuses": unit.active_bonuses.duplicate(),
			"moved": unit.moved,
			"has_attacked": unit.has_attacked,
			"is_master": unit is Master,
		}
		if unit is Master:
			unit_data["free_summon_used"] = bool((unit as Master).free_summon_used)
			unit_data["faction"] = int((unit as Master).faction)
		units.append(unit_data)

	var towers: Array[Dictionary] = []
	for cell_value: Variant in _towers.keys():
		var cell: Vector2i = cell_value as Vector2i
		var tower: Tower = _towers.get(cell, null)
		if tower == null:
			continue
		towers.append({
			"cell": cell,
			"tower_name": tower.tower_name,
			"owner_id": tower.owner_id,
			"income": tower.income,
			"special_effect_type": tower.special_effect_type,
			"special_effect_owner_id": tower.special_effect_owner_id,
			"special_effect_value": tower.special_effect_value,
		})

	return {
		"units": units,
		"towers": towers,
		"pending_tower_captures": _pending_tower_captures.duplicate(true),
		"current_player": current_player,
	}

func restore_saved_state(state: Dictionary) -> void:
	_clear_saved_units()
	_restore_saved_towers(state.get("towers", []))
	_pending_tower_captures = (state.get("pending_tower_captures", {}) as Dictionary).duplicate(true)
	current_player = int(state.get("current_player", 1))

	for unit_value: Variant in state.get("units", []):
		if not (unit_value is Dictionary):
			continue
		_restore_saved_unit(unit_value as Dictionary)

	_deselect()
	_clear_range_highlights()
	clear_highlights()

func _clear_saved_units() -> void:
	for renderer_value: Variant in _unit_renderers.values():
		var renderer: Node3D = renderer_value as Node3D
		if renderer != null:
			renderer.queue_free()
	_unit_renderers.clear()
	_units.clear()
	for ring_value: Variant in _team_rings.values():
		var ring: MeshInstance3D = ring_value as MeshInstance3D
		if ring != null:
			ring.queue_free()
	_team_rings.clear()

func _restore_saved_towers(saved_towers: Array) -> void:
	for tower_value: Variant in saved_towers:
		if not (tower_value is Dictionary):
			continue
		var tower_data: Dictionary = tower_value as Dictionary
		var cell: Vector2i = tower_data.get("cell", Vector2i(-1, -1))
		var tower: Tower = _towers.get(cell, null)
		if tower == null:
			continue
		tower.tower_name = str(tower_data.get("tower_name", tower.tower_name))
		tower.owner_id = int(tower_data.get("owner_id", tower.owner_id))
		tower.income = int(tower_data.get("income", tower.income))
		tower.special_effect_type = str(tower_data.get("special_effect_type", tower.special_effect_type))
		tower.special_effect_owner_id = int(tower_data.get("special_effect_owner_id", tower.special_effect_owner_id))
		tower.special_effect_value = int(tower_data.get("special_effect_value", tower.special_effect_value))
		_update_tower_visual(cell)

func _restore_saved_unit(unit_data: Dictionary) -> void:
	var cell: Vector2i = unit_data.get("cell", Vector2i(-1, -1))
	if cell == Vector2i(-1, -1):
		return
	var unit: Unit = Master.new() if bool(unit_data.get("is_master", false)) else Unit.new()
	unit.unit_name = str(unit_data.get("unit_name", "Unidad"))
	unit.unit_type = int(unit_data.get("unit_type", Unit.UnitType.WARRIOR))
	unit.owner_id = int(unit_data.get("owner_id", 1))
	unit.level = int(unit_data.get("level", Unit.Level.BRONZE))
	unit.experience = int(unit_data.get("experience", 0))
	unit.max_hp = int(unit_data.get("max_hp", 1))
	unit.hp = int(unit_data.get("hp", unit.max_hp))
	unit.move_range = int(unit_data.get("move_range", 3))
	unit.moved = bool(unit_data.get("moved", false))
	unit.has_attacked = bool(unit_data.get("has_attacked", false))
	unit.active_bonuses = []
	for bonus_value: Variant in unit_data.get("active_bonuses", []):
		unit.active_bonuses.append(str(bonus_value))
	if unit is Master:
		(unit as Master).faction = int(unit_data.get("faction", 0))
		(unit as Master).free_summon_used = bool(unit_data.get("free_summon_used", false))
	unit.attack_range = _sanitize_loaded_attack_range(unit, int(unit_data.get("attack_range", unit.get_default_attack_range())))
	BonusSystem.rebuild_bonus_flags(unit)
	place_unit(unit, cell.x, cell.y, false)


func get_hex_cell_data(col: int, row: int) -> HexCell3D:
	if col < 0 or col >= COLS or row < 0 or row >= ROWS:
		return null
	var tile: Node3D = _tile_instances.get(Vector2i(col, row)) as Node3D
	if tile == null:
		return null
	return HexCell3DScript.new(Vector2i(col, row), tile)


func start_combat(units_in_combat: Array, camera: Camera3D = null) -> void:
	_ensure_combat_wall_system()
	if _combat_wall_system == null:
		return
	if camera == null:
		camera = camera_override if camera_override != null else get_viewport().get_camera_3d()
	_combat_wall_system.start_combat(units_in_combat, camera)


func end_combat() -> void:
	if _combat_wall_system != null:
		_combat_wall_system.end_combat()

# ─── Geometry ───────────────────────────────────────────────────────────────────
func _hex_distance(a: Vector2i, b: Vector2i) -> int:
	var aq:  int = a.x
	var ar:  int = a.y - (a.x - (a.x % 2)) / 2
	var bq:  int = b.x
	var br:  int = b.y - (b.x - (b.x % 2)) / 2
	var as_: int = -aq - ar
	var bs:  int = -bq - br
	return (abs(aq - bq) + abs(ar - br) + abs(as_ - bs)) / 2

func _get_neighbors(col: int, row: int) -> Array:
	var origin: Vector2i = Vector2i(col, row)
	var result: Array = []
	for dc: int in range(-1, 2):
		for dr: int in range(-1, 2):
			if dc == 0 and dr == 0:
				continue
			var candidate: Vector2i = Vector2i(col + dc, row + dr)
			if candidate.x < 0 or candidate.x >= COLS or candidate.y < 0 or candidate.y >= ROWS:
				continue
			if _hex_distance(origin, candidate) == 1:
				result.append(candidate)
	return result

func _get_terrain_cost(col: int, row: int) -> int:
	return 1

func _find_master_cell(player_id: int) -> Vector2i:
	for cell: Vector2i in _units.keys():
		var u: Unit = _units[cell]
		if u is Master and u.owner_id == player_id:
			return cell
	return Vector2i(-1, -1)

# ─── Highlight logic ─────────────────────────────────────────────────────────────
func _apply_selection_highlights() -> void:
	_clear_range_highlights()
	_set_selection_focus(true)
	if _selected_cell != Vector2i(-1, -1):
		_set_highlight_range(_selected_cell, "select")
	for cell: Vector2i in _move_cells:
		_set_highlight_range(cell, "move")
	for cell: Vector2i in _attack_cells:
		var dist: int = _hex_distance(_selected_cell, cell) if _selected_cell != Vector2i(-1, -1) else 1
		_set_highlight_range(cell, "attack_ranged" if dist > 1 else "attack")
	_refresh_move_outline()

func _clear_range_highlights() -> void:
	_set_selection_focus(false)
	for cell: Vector2i in _range_cells:
		_set_highlight(cell, false)
	_range_cells.clear()
	_clear_move_outline()

func _set_highlight_range(cell: Vector2i, mode: String) -> void:
	if not _tile_materials.has(cell):
		return
	_set_highlight(cell, true, mode)
	if cell not in _range_cells:
		_range_cells.append(cell)

func _set_highlight(cell: Vector2i, on: bool, mode: String = "select") -> void:
	var mat: ShaderMaterial = _tile_materials.get(cell)
	if mat == null:
		return
	var terrain: int = _map_terrain[cell.y][cell.x]
	var base_albedo: Color = _get_terrain_albedo_color(terrain)
	if on:
		match mode:
			"move":
				mat.set_shader_parameter("albedo_color",   base_albedo.lerp(Color(0.92, 1.0, 0.92), 0.34))
				mat.set_shader_parameter("emission_color", Color.BLACK)
			"attack":
				mat.set_shader_parameter("albedo_color",   base_albedo)
				mat.set_shader_parameter("emission_color", Color(0.55, 0.12, 0.12))
			"attack_ranged":
				mat.set_shader_parameter("albedo_color",   base_albedo)
				mat.set_shader_parameter("emission_color", Color(0.55, 0.32, 0.04))
			"summon":
				mat.set_shader_parameter("albedo_color",   base_albedo.lerp(Color(0.98, 0.92, 1.0), 0.28))
				mat.set_shader_parameter("emission_color", Color.BLACK)
			"card_heal", "card_damage", "card_exp", "card_refresh", \
			"card_immobilize", "card_poison", "card_attack_debuff", "card_swap_hp", \
			"card_extra_move", "card_double_attack", "card_defense_buff", "card_untargetable", \
			"card_tower_heal":
				mat.set_shader_parameter("albedo_color",   base_albedo)
				mat.set_shader_parameter("emission_color", _card_target_color())
			"tutorial":
				mat.set_shader_parameter("albedo_color",   base_albedo)
				mat.set_shader_parameter("emission_color", Color(1.0, 0.82, 0.18, 1.0))
			_:
				mat.set_shader_parameter("albedo_color",   base_albedo)
				mat.set_shader_parameter("emission_color", Color(0.68, 0.52, 0.08))
		var emission_strength: float = 0.0 if mode == "move" or mode == "summon" else 0.95
		if mode == "tutorial":
			emission_strength = 1.35
		mat.set_shader_parameter("emission_strength", emission_strength)
		var highlight_dim_factor: float = 1.0
		if mode == "move":
			highlight_dim_factor = 1.14
		elif mode == "summon":
			highlight_dim_factor = 1.10
		mat.set_shader_parameter("dim_factor", highlight_dim_factor)
	else:
		mat.set_shader_parameter("albedo_color",      base_albedo)
		mat.set_shader_parameter("emission_strength", 0.0)
		mat.set_shader_parameter("emission_color", Color.BLACK)
		mat.set_shader_parameter("dim_factor", TILE_DIM_FACTOR_FOCUSED if _selection_focus_active else 1.0)

func _set_selection_focus(active: bool) -> void:
	if _selection_focus_active == active:
		return
	_selection_focus_active = active
	var dim_factor: float = TILE_DIM_FACTOR_FOCUSED if active else 1.0
	for mat_value: Variant in _tile_materials.values():
		var mat: ShaderMaterial = mat_value as ShaderMaterial
		if mat != null:
			mat.set_shader_parameter("dim_factor", dim_factor)

func _clear_matchup_indicators() -> void:
	for renderer_value: Variant in _unit_renderers.values():
		var renderer: Node3D = renderer_value as Node3D
		if renderer != null and renderer.has_method("set_matchup_indicator"):
			renderer.call("set_matchup_indicator", 0)

func _refresh_matchup_indicators() -> void:
	_clear_matchup_indicators()
	if _selected_unit == null:
		return
	for cell: Vector2i in _attack_cells:
		var target: Unit = _units.get(cell, null)
		var renderer: Node3D = _unit_renderers.get(cell)
		if target == null or renderer == null or not renderer.has_method("set_matchup_indicator"):
			continue
		var mult: float = Unit.get_damage_multiplier(_selected_unit.unit_type, target.unit_type)
		var state: int = 0
		if mult > 1.0:
			state = 1
		elif mult < 1.0:
			state = -1
		renderer.call("set_matchup_indicator", state)

func _show_placement_hints() -> void:
	_clear_matchup_indicators()
	clear_highlights()
	if _placement_master_cell == Vector2i(-1, -1):
		return
	for nb: Vector2i in _get_neighbors(_placement_master_cell.x, _placement_master_cell.y):
		if _is_valid_summon_cell(nb):
			_set_highlight(nb, true, "summon")
			_highlighted_cells.append(nb)
	_refresh_summon_outline()

func _show_master_placement_hints() -> void:
	_clear_matchup_indicators()
	clear_highlights()
	if _master_placement_cell == Vector2i(-1, -1):
		return
	for nb: Vector2i in _get_neighbors(_master_placement_cell.x, _master_placement_cell.y):
		if _is_valid_summon_cell(nb):
			_set_highlight(nb, true, "summon")
			_highlighted_cells.append(nb)
	_refresh_summon_outline()

# ─── Highlight computation (Dijkstra with terrain costs) ─────────────────────────
func _compute_highlights(col: int, row: int, unit: Unit) -> void:
	_move_cells.clear()
	_attack_cells.clear()

	var moves_left: int = unit.get_moves_left()

	var visited: Dictionary = { Vector2i(col, row): 0 }
	var queue:   Array      = [[0, Vector2i(col, row)]]

	while not queue.is_empty():
		var min_i: int = 0
		for i: int in range(1, queue.size()):
			if queue[i][0] < queue[min_i][0]:
				min_i = i
		var entry:   Array    = queue[min_i]
		queue.remove_at(min_i)
		var cost:    int      = entry[0]
		var current: Vector2i = entry[1]

		if visited.get(current, INF) < cost:
			continue

		for nb: Vector2i in _get_neighbors(current.x, current.y):
			var terrain: int = _map_terrain[nb.y][nb.x]
			if terrain == Terrain.WATER or terrain == Terrain.CORDILLERA:
				continue
			var step:     int = 1
			var new_cost: int = cost + step
			var nb_unit:  Unit = _units.get(nb, null)

			if nb_unit == null:
				if new_cost <= moves_left and (not visited.has(nb) or visited[nb] > new_cost):
					visited[nb] = new_cost
					if nb not in _move_cells:
						_move_cells.append(nb)
					queue.append([new_cost, nb])

	if unit.has_attacked:
		return

	# Direct adjacency attack (attack without moving)
	for nb: Vector2i in _get_neighbors(col, row):
		var nb_unit: Unit = _units.get(nb, null)
		if nb_unit != null and nb_unit.owner_id != unit.owner_id and not nb_unit.untargetable:
			if nb not in _attack_cells:
				_attack_cells.append(nb)

	# Ranged attack (Archer, Lancer, Nativos/Brujos Master): distance 2
	for distance: int in range(2, maxi(2, unit.attack_range) + 1):
		if not unit.can_attack_at_distance(distance):
			continue
		for c2: int in range(COLS):
			for r2: int in range(ROWS):
				var target: Vector2i = Vector2i(c2, r2)
				if _hex_distance(Vector2i(col, row), target) != distance:
					continue
				var t_unit: Unit = _units.get(target, null)
				if t_unit != null and t_unit.owner_id != unit.owner_id and not t_unit.untargetable:
					if target not in _attack_cells:
						_attack_cells.append(target)

func _unit_has_actions(col: int, row: int, unit: Unit) -> bool:
	_compute_highlights(col, row, unit)
	return not _move_cells.is_empty() or not _attack_cells.is_empty()

func _is_valid_summon_cell(cell: Vector2i) -> bool:
	if cell == Vector2i(-1, -1):
		return false
	if get_unit_at(cell.x, cell.y) != null:
		return false
	var terrain: int = _map_terrain[cell.y][cell.x]
	return terrain != Terrain.WATER and terrain != Terrain.CORDILLERA

func _update_placement_preview(cell: Vector2i) -> void:
	if not _placement_mode and not _master_placement_mode:
		_clear_placement_preview()
		return
	var anchor_cell: Vector2i = _placement_master_cell if _placement_mode else _master_placement_cell
	if anchor_cell == Vector2i(-1, -1) or cell == Vector2i(-1, -1):
		_clear_placement_preview()
		return
	var adjacent_cells: Array = _get_neighbors(anchor_cell.x, anchor_cell.y)
	if cell not in adjacent_cells or not _is_valid_summon_cell(cell):
		_clear_placement_preview()
		return
	if _placement_preview_renderer != null and _placement_preview_cell == cell:
		return
	_clear_placement_preview()
	var preview_unit := Unit.new()
	preview_unit.setup(str(Unit.TYPE_NAMES.get(_placement_type, "Unit")), _placement_type, _placement_player, 1)
	var preview_renderer: Node3D = UnitRenderer3DScript.new()
	preview_renderer.call("setup", preview_unit)
	if preview_renderer.has_method("set_placement_preview_style"):
		preview_renderer.call("set_placement_preview_style", 0.42)
	var world_pos: Vector3 = hex_to_world(cell.x, cell.y)
	var terrain: int = _map_terrain[cell.y][cell.x] as int
	var hex_top_y: float = TERRAIN_HEIGHTS.get(terrain, 0.12)
	preview_renderer.position = Vector3(world_pos.x, hex_top_y, world_pos.z)
	var container: Node3D = units_container if units_container != null else self
	container.add_child(preview_renderer)
	_placement_preview_renderer = preview_renderer
	_placement_preview_cell = cell

func _clear_placement_preview() -> void:
	_placement_preview_cell = Vector2i(-1, -1)
	if _placement_preview_renderer != null:
		_placement_preview_renderer.queue_free()
		_placement_preview_renderer = null

# ─── Godot callbacks ─────────────────────────────────────────────────────────────
func _ready() -> void:
	if GameData.map_terrain.size() > 0:
		_map_terrain = GameData.map_terrain
		ROWS = _map_terrain.size()
		COLS = _map_terrain[0].size() if ROWS > 0 else 24
	else:
		_fallback_terrain()
	_build_meshes()
	_build_grid()
	_build_grass_billboards()
	_build_underboard_base()
	_place_towers()
	# Masters are placed via setup_units() called from Main3D after units_container is set.

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mme: InputEventMouseMotion = event as InputEventMouseMotion
		_handle_hover(mme.position)
		return
	if event is InputEventMouseButton:
		var mbe: InputEventMouseButton = event as InputEventMouseButton
		if mbe.button_index == MOUSE_BUTTON_LEFT and mbe.pressed:
			_handle_click(mbe.position)

func _process(_delta: float) -> void:
	_update_grass_wind()
	_update_tutorial_focus_ring()
	_update_move_outline_visual()
	_update_summon_outline_visual()

func _screen_to_cell(screen_pos: Vector2) -> Vector2i:
	var cam: Camera3D = camera_override if camera_override != null else get_viewport().get_camera_3d()
	if cam == null:
		return Vector2i(-1, -1)
	var origin: Vector3 = cam.project_ray_origin(screen_pos)
	var direction: Vector3 = cam.project_ray_normal(screen_pos)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + direction * 256.0)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return Vector2i(-1, -1)
	var collider: Object = result.get("collider", null)
	if collider is Node:
		var node: Node = collider as Node
		if node.has_meta("hex_cell"):
			return node.get_meta("hex_cell", Vector2i(-1, -1))
	return Vector2i(-1, -1)

func _handle_hover(screen_pos: Vector2) -> void:
	var cell: Vector2i = _screen_to_cell(screen_pos)
	_update_placement_preview(cell)
	if cell == _hovered_cell:
		return
	_hovered_cell = cell
	if cell != Vector2i(-1, -1):
		emit_signal("cell_hovered", cell)
	else:
		emit_signal("cell_hover_cleared")
	var hovered_unit: Unit = null
	if cell != Vector2i(-1, -1):
		hovered_unit = _units.get(cell, null)
	if hovered_unit == _hovered_unit:
		return
	_hovered_unit = hovered_unit
	if hovered_unit != null:
		if _selected_unit != null and hovered_unit.owner_id != _selected_unit.owner_id and cell in _attack_cells:
			var mult: float = Unit.get_damage_multiplier(_selected_unit.unit_type, hovered_unit.unit_type)
			emit_signal("enemy_inspected", hovered_unit, mult)
		emit_signal("unit_hovered", hovered_unit)
	else:
		emit_signal("unit_hover_cleared")

# ─── Click handling ───────────────────────────────────────────────────────────────
func _handle_click(screen_pos: Vector2) -> void:
	if _animating:
		return
	if GameData.get_player_mode(current_player) == "ai":
		return

	var cell: Vector2i = _screen_to_cell(screen_pos)
	if cell == Vector2i(-1, -1):
		return
	if _card_target_mode:
		if _card_target_towers:
			if cell in _card_target_cells:
				var chosen_index: int = _card_target_index
				_exit_card_target_mode()
				emit_signal("card_tower_selected", chosen_index, cell)
		else:
			var target_unit: Unit = _units.get(cell, null)
			if target_unit != null and cell in _card_target_cells:
				var chosen_index: int = _card_target_index
				_exit_card_target_mode()
				emit_signal("card_target_selected", chosen_index, target_unit)
		return

	# ── Master placement mode ──────────────────────────────────────────────────
	if _master_placement_mode:
		if _master_placement_cell != Vector2i(-1, -1):
			var adj: Array = _get_neighbors(_master_placement_cell.x, _master_placement_cell.y)
			if cell in adj and _is_valid_summon_cell(cell):
				emit_signal("master_placement_confirmed", cell.x, cell.y,
						_placement_type, _placement_player)
				exit_master_placement_mode()
		return

	# ── Normal placement mode ──────────────────────────────────────────────────
	if _placement_mode:
		if _placement_master_cell != Vector2i(-1, -1):
			var adj: Array = _get_neighbors(_placement_master_cell.x, _placement_master_cell.y)
			if cell in adj and _is_valid_summon_cell(cell):
				emit_signal("placement_confirmed", cell.x, cell.y,
						_placement_type, _placement_player)
				exit_placement_mode()
		return

	# ── Nothing selected ──────────────────────────────────────────────────────
	if _selected_cell == Vector2i(-1, -1):
		var unit: Unit = _units.get(cell, null)
		if unit != null and unit.owner_id == current_player:
			var has_actions: bool = _unit_has_actions(cell.x, cell.y, unit)
			if _selected_renderer != null:
				_selected_renderer.call("set_selected", false)
			_selected_renderer = _unit_renderers.get(cell)
			if _selected_renderer != null:
				_selected_renderer.call("set_selected", true)
			if has_actions:
				_selected_cell = cell
				_selected_unit = unit
				_apply_selection_highlights()
				_refresh_matchup_indicators()
			else:
				_clear_range_highlights()
				_selected_cell = Vector2i(-1, -1)
				_selected_unit = null
				if _selected_renderer != null:
					_selected_renderer.call("set_selected", false)
			emit_signal("unit_selected", unit)
			print("[HexGrid3D] Seleccionado → " + unit.stats_string())
		elif unit != null:
			print("[HexGrid3D] Enemigo → " + unit.stats_string())
			emit_signal("enemy_inspected", unit, 1.0)
		return

	# ── Unit selected — react to target cell ──────────────────────────────────
	if cell == _selected_cell:
		_deselect()
		return

	if cell in _move_cells:
		_move_unit(_selected_cell, cell)
		return

	if cell in _attack_cells:
		var target: Unit = _units.get(cell, null)
		if target != null:
			var mult: float = Unit.get_damage_multiplier(
					_selected_unit.unit_type, target.unit_type)
			emit_signal("enemy_inspected", target, mult)
		_initiate_combat(_selected_cell, cell)
		return

	var other: Unit = _units.get(cell, null)
	if other != null and other.owner_id == current_player:
		_clear_range_highlights()
		if _selected_renderer != null:
			_selected_renderer.call("set_selected", false)
		_selected_renderer = _unit_renderers.get(cell)
		if _selected_renderer != null:
			_selected_renderer.call("set_selected", true)
		var has_actions: bool = _unit_has_actions(cell.x, cell.y, other)
		if has_actions:
			_selected_cell = cell
			_selected_unit = other
			_apply_selection_highlights()
			_refresh_matchup_indicators()
		else:
			_selected_cell = Vector2i(-1, -1)
			_selected_unit = null
			if _selected_renderer != null:
				_selected_renderer.call("set_selected", false)
		emit_signal("unit_selected", other)
		print("[HexGrid3D] Cambio → " + other.stats_string())
		return

	_deselect()

# ─── Actions ─────────────────────────────────────────────────────────────────────
func _move_unit(from: Vector2i, to: Vector2i) -> void:
	_animating = true
	_clear_matchup_indicators()
	_clear_range_highlights()

	var unit: Unit = _units[from]
	_units.erase(from)
	_units[to] = unit
	unit.set_hex_cell(to)
	unit.use_move(_get_terrain_cost(to.x, to.y))
	unit.moves_this_turn += _hex_distance(from, to)
	if to != from:
		unit.facing = to - from

	# Animate renderer
	if _unit_renderers.has(from):
		var renderer: Node3D  = _unit_renderers[from]
		_unit_renderers.erase(from)
		_unit_renderers[to] = renderer

		var to_world: Vector3 = hex_to_world(to.x, to.y)
		var terrain:  int     = _map_terrain[to.y][to.x] as int
		var base_y:   float   = TERRAIN_HEIGHTS.get(terrain, 0.12)
		var target:   Vector3 = Vector3(to_world.x, base_y, to_world.z)

		AudioManager.play_move()
		var arc_mid: Vector3 = renderer.position.lerp(target, 0.5) \
				+ Vector3(0.0, 0.45, 0.0)
		var tween: Tween = create_tween()
		tween.tween_property(renderer, "position", arc_mid, 0.18) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(renderer, "position", target,  0.18) \
				.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		await tween.finished
		if renderer.has_method("play_move_landing"):
			renderer.call("play_move_landing")

	_move_team_ring(from, to)
	_update_team_ring_state(to, unit)

	# Tower capture
	var tower: Tower = _towers.get(to, null)
	if tower != null and tower.owner_id != unit.owner_id:
		var previous_owner_id: int = tower.owner_id
		var capture_bonus: int = tower.capture(unit.owner_id)
		if resource_manager != null and capture_bonus > 0:
			resource_manager.add_essence(unit.owner_id, capture_bonus)
		var tower_exp_reward: int = (ENEMY_TOWER_CAPTURE_EXP_REWARD if previous_owner_id > 0 else 0) + (2 if unit.bonus_raider else 0)
		var exp_result: Dictionary = unit.gain_exp_with_result(tower_exp_reward)
		var renderer_after_capture: Node3D = _unit_renderers.get(to, null)
		if renderer_after_capture != null and renderer_after_capture.has_method("set_health_bar_values"):
			renderer_after_capture.call("set_health_bar_values", unit.hp, unit.max_hp, true)
		_update_tower_visual(to)
		emit_signal("tower_captured", tower.tower_name, unit.owner_id)
		AudioManager.play_capture()
		if capture_bonus > 0:
			AudioManager.play_essence()
		if int(exp_result.get("gained", 0)) > 0:
			VFXManager.show_world_text_label(
				_get_unit_world_anchor(to),
				"+%d XP" % int(exp_result.get("gained", 0)),
				Color(0.84, 0.42, 1.0, 1.0),
				48,
				1.85
			)
		print("[HexGrid3D] J%d capturó una torre en (%d,%d)" % [unit.owner_id, to.x, to.y])

	print("[HexGrid3D] %s movido a (%d,%d) | movimientos restantes: %d" % [
			unit.unit_name, to.x, to.y, unit.get_moves_left()])

	_selected_cell = to
	_selected_unit = unit
	_compute_highlights(to.x, to.y, unit)
	_selected_renderer = _unit_renderers.get(to)
	if _selected_renderer != null:
		_selected_renderer.call("set_selected", true)
	if _move_cells.is_empty() and _attack_cells.is_empty():
		_selected_cell = Vector2i(-1, -1)
		_selected_unit = null
		_clear_range_highlights()
		if _selected_renderer != null:
			_selected_renderer.call("set_selected", false)
	else:
		_apply_selection_highlights()
		_refresh_matchup_indicators()
	emit_signal("unit_selected", unit)
	_animating = false

func _initiate_combat(attacker_cell: Vector2i, defender_cell: Vector2i) -> void:
	if combat_manager == null:
		push_error("[HexGrid3D] combat_manager not set!")
		return

	_animating = true
	_clear_matchup_indicators()
	_clear_range_highlights()

	var attacker: Unit = _units[attacker_cell]
	var defender: Unit = _units[defender_cell]
	var attacker_terrain: int = _map_terrain[attacker_cell.y][attacker_cell.x] as int
	var defender_terrain: int = _map_terrain[defender_cell.y][defender_cell.x] as int
	var is_ranged: bool = attacker.can_attack_at_distance(_hex_distance(attacker_cell, defender_cell)) and \
			_hex_distance(attacker_cell, defender_cell) > 1

	attacker.exhaust()
	_update_team_ring_state(attacker_cell, attacker)

	# ── Build visual context for cinematic combat ──────────────────────────────
	var cam: Camera3D = camera_override if camera_override != null else get_viewport().get_camera_3d()
	var atk_renderer: Node3D = _unit_renderers.get(attacker_cell)
	var def_renderer: Node3D = _unit_renderers.get(defender_cell)

	var visual_context: Dictionary = {
		"camera":            cam if (cam != null and cam.has_method("enter_combat_mode")) else null,
		"attacker_pos":      _get_unit_world_anchor(attacker_cell),
		"defender_pos":      _get_unit_world_anchor(defender_cell),
		"attacker_cell":     attacker_cell,
		"defender_cell":     defender_cell,
		"attacker_terrain":  attacker_terrain,
		"defender_terrain":  defender_terrain,
		"attacker_renderer": atk_renderer,
		"defender_renderer": def_renderer,
		"all_renderers":     _unit_renderers.values(),
		"host":              self,
		"is_night":          _is_night_visuals,
	}

	# ── Run cinematic + combat (CombatManager owns the full sequence) ──────────
	var result: Dictionary = await combat_manager.resolve_combat(
			attacker, defender, is_ranged, visual_context)

	emit_signal("combat_resolved", attacker, defender, result)

	# ── Tree cleanup — renderers were already animated by CombatManager ────────
	if result.defender_died:
		if def_renderer != null:
			def_renderer.queue_free()
		_remove_team_ring(defender_cell)
		_unit_renderers.erase(defender_cell)
		_units.erase(defender_cell)

		var def_is_master: bool = defender is Master
		var def_owner:     int  = defender.owner_id
		defender.clear_hex_cell()
		defender.free()

		if def_is_master:
			print("[HexGrid3D] *** Maestro del Jugador %d ha caído! ***" % def_owner)
			_animating = false
			_deselect()
			emit_signal("master_killed", def_owner)
			return

	if result.attacker_died:
		if atk_renderer != null:
			atk_renderer.queue_free()
		_remove_team_ring(attacker_cell)
		_unit_renderers.erase(attacker_cell)
		_units.erase(attacker_cell)

		var atk_is_master: bool = attacker is Master
		var atk_owner:     int  = attacker.owner_id
		attacker.clear_hex_cell()
		attacker.free()

		if atk_is_master:
			print("[HexGrid3D] *** Maestro del Jugador %d ha caído! ***" % atk_owner)
			_animating = false
			_deselect()
			emit_signal("master_killed", atk_owner)
			return

	_animating = false
	_deselect()

func _get_unit_world_anchor(cell: Vector2i) -> Vector3:
	var base_pos: Vector3 = hex_to_world(cell.x, cell.y)
	var terrain: int = _map_terrain[cell.y][cell.x] as int
	base_pos.y = TERRAIN_HEIGHTS.get(terrain, 0.12)
	var renderer: Node3D = _unit_renderers.get(cell, null)
	if renderer != null:
		base_pos.y = renderer.position.y
	return base_pos

func _deselect() -> void:
	_clear_matchup_indicators()
	if _selected_renderer != null:
		_selected_renderer.call("set_selected", false)
		_selected_renderer = null
	_selected_cell = Vector2i(-1, -1)
	_selected_unit = null
	_move_cells.clear()
	_attack_cells.clear()
	_clear_range_highlights()
	emit_signal("unit_deselected")
	if _hovered_unit != null:
		emit_signal("unit_hovered", _hovered_unit)

func _exit_card_target_mode() -> void:
	if not _card_target_mode and _card_target_cells.is_empty():
		return
	for cell: Vector2i in _card_target_cells:
		if _card_target_towers:
			_set_tower_target_glow(cell, false)
		else:
			var renderer: Node3D = _unit_renderers.get(cell)
			if renderer != null and renderer.has_method("set_card_target_highlight"):
				renderer.call("set_card_target_highlight", false, Color.WHITE)
	_card_target_mode = false
	_card_target_player = 0
	_card_target_index = -1
	_card_target_type = ""
	_card_target_towers = false
	_card_target_cells.clear()
	clear_highlights()
	_set_selection_focus(false)

func _set_tower_target_glow(cell: Vector2i, active: bool) -> void:
	var tower_root: Node3D = _tower_instances.get(cell, null)
	if tower_root == null:
		return
	var mats: Array = tower_root.get_meta("tower_materials", [])
	for mat_value: Variant in mats:
		var mat: ShaderMaterial = mat_value as ShaderMaterial
		if mat == null:
			continue
		if active:
			mat.set_shader_parameter("emission_color", Color(1.0, 0.82, 0.18, 1.0))
			mat.set_shader_parameter("emission_strength", 1.4)
		else:
			mat.set_shader_parameter("emission_color", Color.BLACK)
			mat.set_shader_parameter("emission_strength", 0.0)

# ─── Grid construction ────────────────────────────────────────────────────────────
func _build_meshes() -> void:
	for t: int in range(TERRAIN_HEIGHTS.size()):
		var h:   float        = TERRAIN_HEIGHTS.get(t, 0.12)
		var cyl: CylinderMesh = CylinderMesh.new()
		cyl.top_radius      = HEX_SIZE * 0.96
		cyl.bottom_radius   = HEX_SIZE * 0.96
		cyl.height          = h
		cyl.radial_segments = 6
		cyl.rings           = 1
		_terrain_meshes[t]  = cyl
		_terrain_collision_shapes[t] = _make_hex_collision_shape(h, HEX_SIZE * HEX_VISUAL_RADIUS_FACTOR)

func _build_grid() -> void:
	for col: int in range(COLS):
		for row: int in range(ROWS):
			var terrain:   int     = _map_terrain[row][col]
			var h:         float   = TERRAIN_HEIGHTS.get(terrain, 0.12)
			var world_pos: Vector3 = hex_to_world(col, row)

			var mat: ShaderMaterial = ShaderMaterial.new()
			mat.shader = TerrainShader
			mat.set_shader_parameter("albedo_color",    _get_terrain_albedo_color(terrain))
			mat.set_shader_parameter("use_albedo_texture", terrain == Terrain.GRASS or terrain == Terrain.FOREST)
			mat.set_shader_parameter("albedo_texture", _get_terrain_tile_texture(terrain, col, row))
			mat.set_shader_parameter("texture_tint_strength", 0.82 if terrain == Terrain.FOREST else 1.0)
			mat.set_shader_parameter("texture_brightness", 1.55 if terrain == Terrain.GRASS else (1.48 if terrain == Terrain.FOREST else 1.0))
			mat.set_shader_parameter("deco_strength", 0.24 if terrain == Terrain.FOREST else 0.20)
			mat.set_shader_parameter("deco_profile", 1 if terrain == Terrain.FOREST else 0)
			mat.set_shader_parameter("pixel_density", 22.0)
			mat.set_shader_parameter("patch_pixel_size", 6.0)
			mat.set_shader_parameter("light_bands", 3.0)
			mat.set_shader_parameter("emission_color",  Color.BLACK)
			mat.set_shader_parameter("emission_strength", 0.0)
			mat.set_shader_parameter("dim_factor", 1.0)
			mat.set_shader_parameter("night_glow_strength", 0.0)
			_apply_cloud_shadow_params(mat, false)
			mat.next_pass = _get_terrain_outline_mat()

			var inst: MeshInstance3D = MeshInstance3D.new()
			inst.mesh              = _terrain_meshes[terrain]
			inst.material_override = mat
			inst.position   = Vector3(world_pos.x, h * 0.5, world_pos.z)
			inst.rotation.y = deg_to_rad(30.0)
			_add_hex_side_markers(inst, h, HEX_SIZE * HEX_VISUAL_RADIUS_FACTOR)
			add_child(inst)

			var key: Vector2i = Vector2i(col, row)
			_tile_instances[key] = inst
			_tile_materials[key] = mat

			var body: StaticBody3D = StaticBody3D.new()
			body.name = "TileBody_%d_%d" % [col, row]
			body.position = Vector3(world_pos.x, h * 0.5, world_pos.z)
			body.set_meta("hex_cell", key)
			var collision: CollisionShape3D = CollisionShape3D.new()
			collision.shape = _terrain_collision_shapes.get(terrain, null)
			body.add_child(collision)
			add_child(body)


func _make_hex_collision_shape(tile_height: float, radius: float) -> ConvexPolygonShape3D:
	var shape: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
	var points: PackedVector3Array = PackedVector3Array()
	var half_height: float = tile_height * 0.5
	var angle_offset: float = deg_to_rad(30.0)
	for side_index: int in range(HexCell3DScript.SIDE_COUNT):
		var angle: float = angle_offset + deg_to_rad(60.0 * float(side_index))
		var x: float = cos(angle) * radius
		var z: float = sin(angle) * radius
		points.append(Vector3(x, half_height, z))
		points.append(Vector3(x, -half_height, z))
	shape.points = points
	return shape


func _ensure_combat_wall_system() -> void:
	if _combat_wall_system != null:
		_combat_wall_system.wall_scene = combat_wall_scene
		_combat_wall_system.wall_extra_height = combat_wall_extra_height
		_combat_wall_system.unit_height_reference = combat_wall_unit_height
		_combat_wall_system.wall_thickness = combat_wall_thickness
		_combat_wall_system.wall_side_count = combat_wall_side_count
		_combat_wall_system.wall_container_path = combat_wall_container_path
		return

	_combat_wall_system = CombatHexWallSystemScript.new()
	_combat_wall_system.name = "CombatHexWallSystem"
	_combat_wall_system.hex_grid = self
	_combat_wall_system.wall_scene = combat_wall_scene
	_combat_wall_system.wall_extra_height = combat_wall_extra_height
	_combat_wall_system.unit_height_reference = combat_wall_unit_height
	_combat_wall_system.wall_thickness = combat_wall_thickness
	_combat_wall_system.wall_side_count = combat_wall_side_count
	_combat_wall_system.wall_container_path = combat_wall_container_path
	add_child(_combat_wall_system)


func _add_hex_side_markers(tile: Node3D, tile_height: float, side_radius: float) -> void:
	var top_y: float = tile_height * 0.5
	var vertices: Array[Vector3] = []
	var mesh_angle_offset: float = deg_to_rad(30.0)
	for side_index: int in range(HexCell3DScript.SIDE_COUNT):
		var angle: float = mesh_angle_offset + deg_to_rad(60.0 * float(side_index))
		vertices.append(Vector3(cos(angle) * side_radius, top_y, sin(angle) * side_radius))

	for side_index: int in range(HexCell3DScript.SIDE_COUNT):
		var start: Vector3 = vertices[side_index]
		var finish: Vector3 = vertices[(side_index + 1) % HexCell3DScript.SIDE_COUNT]
		var tangent: Vector3 = finish - start
		var side_length: float = tangent.length()
		if side_length <= 0.0001:
			continue

		tangent /= side_length
		var outward_normal: Vector3 = Vector3(tangent.z, 0.0, -tangent.x).normalized()
		var midpoint: Vector3 = (start + finish) * 0.5
		var marker := Marker3D.new()
		marker.name = "edge[%d]" % side_index
		marker.transform = Transform3D(Basis(-tangent, Vector3.UP, outward_normal), midpoint)
		marker.set_meta("side_length", side_length)
		tile.add_child(marker)

func _build_grass_billboards() -> void:
	if _grass_deco_container != null:
		_grass_deco_container.queue_free()
	_grass_cluster_roots.clear()
	_grass_cluster_base_positions.clear()
	_grass_cluster_phases.clear()
	_grass_cluster_strengths.clear()
	_grass_deco_container = Node3D.new()
	_grass_deco_container.name = "GrassDecorations"
	add_child(_grass_deco_container)

	if _grass_blade_texture == null:
		_grass_blade_texture = GrassBladeTexture

	for col: int in range(COLS):
		for row: int in range(ROWS):
			var terrain: int = _map_terrain[row][col]
			if terrain != Terrain.GRASS and terrain != Terrain.FOREST:
				continue
			var cluster_count: int = _get_grass_cluster_count(col, row, terrain)
			if cluster_count <= 0:
				continue
			var base_pos: Vector3 = hex_to_world(col, row)
			var tile_top_y: float = TERRAIN_HEIGHTS.get(terrain, 0.12)
			for i: int in range(cluster_count):
				var cluster_offset: Vector3 = _get_grass_cluster_position(col, row, i, cluster_count)
				var cluster_root := Node3D.new()
				cluster_root.position = base_pos + Vector3(cluster_offset.x, tile_top_y + 0.015, cluster_offset.z)
				_grass_deco_container.add_child(cluster_root)
				_grass_cluster_roots.append(cluster_root)
				_grass_cluster_base_positions.append(cluster_root.position)
				_grass_cluster_phases.append(float(abs((col * 83) + (row * 47) + (i * 29) + GameData.map_seed)) * 0.09)
				_grass_cluster_strengths.append(lerp(0.020, 0.042, (_get_grass_offset(col, row, i, 11) + 1.0) * 0.5) if terrain == Terrain.FOREST else lerp(0.030, 0.060, (_get_grass_offset(col, row, i, 11) + 1.0) * 0.5))

				var blade_count: int = (1 + int(abs((col * 17) + (row * 31) + i + GameData.map_seed) % 2)) if terrain == Terrain.FOREST else (2 + int(abs((col * 17) + (row * 31) + i + GameData.map_seed) % 2))
				for blade_index: int in range(blade_count):
					var blade := Sprite3D.new()
					blade.texture = _grass_blade_texture
					blade.centered = false
					blade.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
					blade.pixel_size = (0.018 + (0.0020 * blade_index)) if terrain == Terrain.FOREST else (0.021 + (0.0030 * blade_index))
					blade.shaded = true
					blade.no_depth_test = false
					blade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
					blade.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
					blade.alpha_scissor_threshold = 0.12
					blade.offset = Vector2(0.0, -15.0)
					blade.modulate = _get_grass_blade_color(col, row, i * 3 + blade_index, terrain)
					blade.position = Vector3(
						_get_grass_offset(col, row, i * 3 + blade_index, 3) * 0.075,
						0.0,
						_get_grass_offset(col, row, i * 3 + blade_index, 4) * 0.050
					)
					blade.rotation_degrees.y = float(((col + row + i + blade_index) % 6) * 60)
					cluster_root.add_child(blade)

func _get_terrain_tile_texture(terrain: int, col: int, row: int) -> Texture2D:
	var textures: Array[Texture2D] = []
	match terrain:
		Terrain.GRASS:
			textures = GRASS_TILE_TEXTURES
		Terrain.FOREST:
			textures = FOREST_TILE_TEXTURES
		_:
			return null
	if textures.is_empty():
		return null
	var index: int = abs((col * 92821) + (row * 68917) + GameData.map_seed) % textures.size()
	return textures[index]

func _get_terrain_albedo_color(terrain: int) -> Color:
	if terrain == Terrain.FOREST:
		return Color(0.30, 0.64, 0.28, 1.0)
	return TERRAIN_COLORS.get(terrain, Color.WHITE)

func _get_grass_cluster_count(col: int, row: int, terrain: int = Terrain.GRASS) -> int:
	var hash_value: int = abs((col * 19349663) ^ (row * 83492791) ^ (GameData.map_seed * 29791))
	var roll: int = hash_value % 100
	if terrain == Terrain.FOREST:
		if roll < 40:
			return 0
		if roll < 82:
			return 1
		return 2
	if roll < 28:
		return 0
	if roll < 70:
		return 1
	if roll < 92:
		return 2
	return 3

func _get_grass_cluster_position(col: int, row: int, index: int, cluster_count: int) -> Vector3:
	var angle_step: float = TAU / float(max(cluster_count, 1))
	var angle: float = angle_step * float(index) + (_get_grass_offset(col, row, index, 9) * 0.22)
	var radius: float = 0.23 + ((_get_grass_offset(col, row, index, 10) + 1.0) * 0.5 * 0.12)
	return Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)

func _get_grass_offset(col: int, row: int, index: int, axis: int) -> float:
	var seed_base: int = GameData.map_seed + (axis * 1297)
	var hash_value: int = abs((col * 73856093) + (row * 19349663) + (index * 83492791) + seed_base)
	return (float(hash_value % 1000) / 999.0) * 2.0 - 1.0

func _get_grass_blade_color(col: int, row: int, index: int, terrain: int = Terrain.GRASS) -> Color:
	var shift: float = (_get_grass_offset(col, row, index, 2) + 1.0) * 0.5
	if terrain == Terrain.FOREST:
		return Color(
			lerp(0.16, 0.28, shift),
			lerp(0.42, 0.62, shift),
			lerp(0.12, 0.20, shift),
			0.88
		)
	return Color(
		lerp(0.22, 0.42, shift),
		lerp(0.72, 1.00, shift),
		lerp(0.16, 0.30, shift),
		0.95
	)

func _update_grass_wind() -> void:
	if _grass_cluster_roots.is_empty():
		return
	var time_now: float = Time.get_ticks_msec() / 1000.0
	for i: int in range(_grass_cluster_roots.size()):
		var root: Node3D = _grass_cluster_roots[i]
		if root == null or not is_instance_valid(root):
			continue
		var base_position: Vector3 = _grass_cluster_base_positions[i]
		var phase: float = _grass_cluster_phases[i]
		var strength: float = _grass_cluster_strengths[i]
		var snapped_wave: float = round(sin(time_now * 1.55 + phase) * 5.0) / 5.0
		root.position = Vector3(
			base_position.x + snapped_wave * strength,
			base_position.y,
			base_position.z + snapped_wave * strength * 0.28
		)

func _build_underboard_base() -> void:
	var center: Vector3 = get_map_center()
	var max_world: Vector3 = hex_to_world(COLS - 1, ROWS - 1)
	var board_width: float = max_world.x + HEX_SIZE * 2.3
	var board_depth: float = max_world.z + HEX_SIZE * 2.5

	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(board_width, 1.6, board_depth)

	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.11, 0.07, 0.06, 1.0)
	base_mat.roughness = 1.0
	base_mat.metallic = 0.0

	var base := MeshInstance3D.new()
	base.mesh = base_mesh
	base.material_override = base_mat
	base.position = Vector3(center.x, -0.84, center.z)
	add_child(base)

	var shadow_mesh := BoxMesh.new()
	shadow_mesh.size = Vector3(board_width * 0.985, 0.08, board_depth * 0.985)

	var shadow_mat := StandardMaterial3D.new()
	shadow_mat.albedo_color = Color(0.04, 0.02, 0.02, 1.0)
	shadow_mat.emission_enabled = true
	shadow_mat.emission = Color(0.08, 0.04, 0.03, 1.0)
	shadow_mat.emission_energy_multiplier = 0.35
	shadow_mat.roughness = 1.0

	var shadow_cap := MeshInstance3D.new()
	shadow_cap.mesh = shadow_mesh
	shadow_cap.material_override = shadow_mat
	shadow_cap.position = Vector3(center.x, -0.02, center.z)
	add_child(shadow_cap)

# ─── Tower placement ──────────────────────────────────────────────────────────────
func _place_towers() -> void:
	var positions: Array
	var incomes: Array = []
	if GameData.map_terrain.size() > 0:
		positions = GameData.map_tower_positions
		incomes = GameData.map_tower_incomes
	else:
		positions = [
			Vector2i(4, 4),  Vector2i(4, 11),
			Vector2i(10, 6), Vector2i(12, 8), Vector2i(13, 11),
			Vector2i(19, 4), Vector2i(19, 11),
		]

	for i: int in range(positions.size()):
		var pos:   Vector2i = positions[i]
		var tower: Tower    = TowerScript.new()
		tower.tower_name = "Torre %d" % (i + 1)
		tower.owner_id   = 0
		tower.income     = int(incomes[i]) if i < incomes.size() else 2
		tower.position   = pos
		_towers[pos]     = tower
		_spawn_tower_3d(pos, tower)

	print("[HexGrid3D] Torres colocadas: %d" % positions.size())

func _spawn_tower_3d(cell: Vector2i, tower: Tower) -> void:
	var world_pos: Vector3 = hex_to_world(cell.x, cell.y)
	var base_y: float = TERRAIN_HEIGHTS.get(_map_terrain[cell.y][cell.x] as int, 0.12)
	var tower_pos: Vector3 = Vector3(world_pos.x, base_y, world_pos.z) + TOWER_VISUAL_OFFSET

	var tower_root := Node3D.new()
	tower_root.position = tower_pos
	add_child(tower_root)

	var tower_materials: Array[ShaderMaterial] = [
		_create_tower_material(Color(0.70, 0.70, 0.72, 1.0), tower.owner_id, 0.62, 0.34),
		_create_tower_material(Color(0.58, 0.60, 0.64, 1.0), tower.owner_id, 0.72, 0.40),
		_create_tower_material(Color(0.92, 0.92, 0.96, 1.0), tower.owner_id, 0.46, 0.22),
	]
	tower_root.set_meta("tower_materials", tower_materials)

	_add_tower_piece(tower_root, Vector3(0.34, 0.08, 0.34), Vector3(0.0, 0.04, 0.0), tower_materials[1])
	_add_tower_piece(tower_root, Vector3(0.26, 0.08, 0.26), Vector3(0.0, 0.11, 0.0), tower_materials[1])
	_add_tower_piece(tower_root, Vector3(0.18, 0.50, 0.18), Vector3(0.0, 0.40, 0.0), tower_materials[0])
	_add_tower_piece(tower_root, Vector3(0.24, 0.08, 0.24), Vector3(0.0, 0.67, 0.0), tower_materials[1])
	_add_tower_piece(tower_root, Vector3(0.30, 0.08, 0.30), Vector3(0.0, 0.75, 0.0), tower_materials[0])
	_add_tower_piece(tower_root, Vector3(0.26, 0.04, 0.26), Vector3(0.0, 0.81, 0.0), tower_materials[1])

	var crenel_positions: Array[Vector3] = [
		Vector3(-0.10, 0.89, -0.10),
		Vector3(0.00, 0.89, -0.10),
		Vector3(0.10, 0.89, -0.10),
		Vector3(-0.10, 0.89, 0.10),
		Vector3(0.00, 0.89, 0.10),
		Vector3(0.10, 0.89, 0.10),
		Vector3(-0.10, 0.89, 0.00),
		Vector3(0.10, 0.89, 0.00),
	]
	for pos: Vector3 in crenel_positions:
		_add_tower_piece(tower_root, Vector3(0.055, 0.11, 0.055), pos, tower_materials[1])

	_add_tower_piece(tower_root, Vector3(0.045, 0.13, 0.018), Vector3(0.0, 0.48, -0.100), tower_materials[2])
	_add_tower_piece(tower_root, Vector3(0.07, 0.012, 0.02), Vector3(0.0, 0.40, -0.094), tower_materials[1])

	var special_root := Node3D.new()
	special_root.name = "SpecialEffectRoot"
	special_root.visible = false
	tower_root.add_child(special_root)
	tower_root.set_meta("special_root", special_root)

	var special_ring := MeshInstance3D.new()
	var special_ring_mesh := TorusMesh.new()
	special_ring_mesh.outer_radius = 0.26
	special_ring_mesh.inner_radius = 0.028
	special_ring_mesh.rings = 6
	special_ring_mesh.ring_segments = 20
	special_ring.mesh = special_ring_mesh
	var special_ring_mat := StandardMaterial3D.new()
	special_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	special_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	special_ring_mat.albedo_color = Color(0.54, 0.98, 0.78, 0.92)
	special_ring_mat.emission_enabled = true
	special_ring_mat.emission = Color(0.54, 0.98, 0.78, 1.0)
	special_ring_mat.emission_energy_multiplier = 1.35
	special_ring.material_override = special_ring_mat
	special_ring.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	special_ring.position = Vector3(0.0, 1.06, 0.0)
	special_root.add_child(special_ring)
	tower_root.set_meta("special_ring_material", special_ring_mat)

	var special_gem := MeshInstance3D.new()
	var special_gem_mesh := BoxMesh.new()
	special_gem_mesh.size = Vector3(0.10, 0.18, 0.10)
	special_gem.mesh = special_gem_mesh
	var special_gem_mat := StandardMaterial3D.new()
	special_gem_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	special_gem_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	special_gem_mat.albedo_color = Color(0.74, 1.0, 0.86, 0.95)
	special_gem_mat.emission_enabled = true
	special_gem_mat.emission = Color(0.66, 1.0, 0.84, 1.0)
	special_gem_mat.emission_energy_multiplier = 1.55
	special_gem.material_override = special_gem_mat
	special_gem.position = Vector3(0.0, 1.14, 0.0)
	special_root.add_child(special_gem)
	tower_root.set_meta("special_gem_material", special_gem_mat)

	var special_label := Label3D.new()
	special_label.text = "SAGRADA"
	special_label.pixel_size = 0.0065
	special_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	special_label.modulate = Color(0.70, 1.0, 0.82, 0.95)
	special_label.outline_modulate = Color(0.10, 0.18, 0.14, 0.95)
	special_label.position = Vector3(0.0, 1.42, 0.0)
	GameData.apply_selected_font_to_label3d(special_label)
	special_root.add_child(special_label)
	tower_root.set_meta("special_label", special_label)

	_tower_instances[cell] = tower_root

	# Income label
	var income_root := Node3D.new()
	income_root.position = tower_pos + Vector3(0.0, 1.30, 0.0)
	add_child(income_root)
	tower_root.set_meta("income_root", income_root)

	var icon := Sprite3D.new()
	icon.texture = EssenceIconTexture
	icon.pixel_size = 0.006
	icon.centered = true
	icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	icon.modulate = C_GOLD
	icon.position = Vector3(-0.12, 0.0, 0.0)
	income_root.add_child(icon)
	tower_root.set_meta("income_icon", icon)

	var lbl: Label3D = Label3D.new()
	lbl.text = "+%d" % tower.income
	lbl.pixel_size = 0.008
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.modulate = C_GOLD
	lbl.position = Vector3(0.05, 0.0, 0.0)
	GameData.apply_selected_font_to_label3d(lbl)
	income_root.add_child(lbl)
	tower_root.set_meta("income_label", lbl)

func _update_tower_visual(cell: Vector2i) -> void:
	var tower: Tower = _towers.get(cell)
	if tower == null:
		return
	var tower_root: Node3D = _tower_instances.get(cell) as Node3D
	if tower_root == null:
		return
	var materials: Array = tower_root.get_meta("tower_materials", [])
	for material_value: Variant in materials:
		var mat: ShaderMaterial = material_value as ShaderMaterial
		if mat != null:
			_configure_tower_material(mat, tower.owner_id)
	var special_root: Node3D = tower_root.get_meta("special_root", null) as Node3D
	var special_label: Label3D = tower_root.get_meta("special_label", null) as Label3D
	var ring_mat: StandardMaterial3D = tower_root.get_meta("special_ring_material", null) as StandardMaterial3D
	var gem_mat: StandardMaterial3D = tower_root.get_meta("special_gem_material", null) as StandardMaterial3D
	if special_root != null:
		var is_special: bool = tower.has_special_effect()
		special_root.visible = is_special
		if is_special:
			var accent_color: Color = GameData.get_player_color(tower.special_effect_owner_id) if tower.special_effect_owner_id > 0 else Color(0.70, 1.0, 0.82, 1.0)
			var sacred_color: Color = accent_color.lerp(Color(0.70, 1.0, 0.82, 1.0), 0.55)
			if ring_mat != null:
				ring_mat.albedo_color = Color(sacred_color.r, sacred_color.g, sacred_color.b, 0.90)
				ring_mat.emission = sacred_color
			if gem_mat != null:
				gem_mat.albedo_color = Color(sacred_color.r, minf(1.0, sacred_color.g + 0.08), minf(1.0, sacred_color.b + 0.04), 0.95)
				gem_mat.emission = sacred_color.lightened(0.12)
			if special_label != null:
				match tower.special_effect_type:
					"tower_heal":
						special_label.text = "SAGRADA +%d" % tower.special_effect_value
					_:
						special_label.text = tower.special_effect_type.to_upper()
				special_label.modulate = Color(sacred_color.r, sacred_color.g, sacred_color.b, 0.95)

func play_tower_income_feedback(player_id: int) -> void:
	for cell_value: Variant in _towers.keys():
		var cell: Vector2i = cell_value as Vector2i
		var tower: Tower = _towers.get(cell) as Tower
		if tower == null or tower.owner_id != player_id:
			continue
		var tower_root: Node3D = _tower_instances.get(cell) as Node3D
		if tower_root == null:
			continue
		_animate_tower_income_feedback(tower_root, tower)

func apply_time_of_day_visuals(is_night: bool, moon_strength: float) -> void:
	_is_night_visuals = is_night
	_moon_visual_strength = clampf(moon_strength, 0.0, 1.0)

	for cell: Variant in _tile_materials.keys():
		var tile: Vector2i = cell as Vector2i
		var mat: ShaderMaterial = _tile_materials[tile] as ShaderMaterial
		if mat != null:
			_configure_tile_material(mat, _map_terrain[tile.y][tile.x] as int)

	for cell: Variant in _tower_instances.keys():
		var tower_cell: Vector2i = cell as Vector2i
		var tower_root: Node3D = _tower_instances[tower_cell] as Node3D
		if tower_root == null:
			continue
		var tower: Tower = _towers.get(tower_cell)
		if tower == null:
			continue
		var materials: Array = tower_root.get_meta("tower_materials", [])
		for material_value: Variant in materials:
			var mat: ShaderMaterial = material_value as ShaderMaterial
			if mat != null:
				_configure_tower_material(mat, tower.owner_id)

func set_combat_tower_obstruction_fade(active: bool, focus_mid: Vector3 = Vector3.ZERO, camera_pos: Vector3 = Vector3.ZERO) -> void:
	if not active:
		for tower_root_value: Variant in _tower_instances.values():
			var tower_root: Node3D = tower_root_value as Node3D
			if tower_root != null:
				_set_tower_root_opacity(tower_root, 1.0)
		for renderer_value: Variant in _unit_renderers.values():
			var renderer: Node3D = renderer_value as Node3D
			if renderer != null and renderer.has_method("set_combat_obstruction_opacity"):
				renderer.call("set_combat_obstruction_opacity", 1.0)
		return

	for tower_root_value: Variant in _tower_instances.values():
		var tower_root: Node3D = tower_root_value as Node3D
		if tower_root == null:
			continue
		var tower_pos: Vector3 = tower_root.global_position
		var segment_distance: float = _point_to_segment_distance_xz(tower_pos, camera_pos, focus_mid)
		var toward_focus: float = (focus_mid - camera_pos).length()
		var toward_tower: float = (tower_pos - camera_pos).length()
		var opacity: float = 1.0
		if segment_distance < 0.44 and toward_tower < toward_focus - 0.08:
			opacity = 0.08
		_set_tower_root_opacity(tower_root, opacity)

	for renderer_value: Variant in _unit_renderers.values():
		var renderer: Node3D = renderer_value as Node3D
		if renderer == null or not renderer.has_method("set_combat_obstruction_opacity"):
			continue
		var unit_pos: Vector3 = renderer.global_position
		var segment_distance: float = _point_to_segment_distance_xz(unit_pos, camera_pos, focus_mid)
		var toward_focus: float = (focus_mid - camera_pos).length()
		var toward_unit: float = (unit_pos - camera_pos).length()
		var opacity: float = 1.0
		if segment_distance < 0.40 and toward_unit < toward_focus - 0.04:
			opacity = 0.10
		renderer.call("set_combat_obstruction_opacity", opacity)

func set_combat_team_rings_visible(visible: bool) -> void:
	for ring_value: Variant in _team_rings.values():
		var ring: MeshInstance3D = ring_value as MeshInstance3D
		if ring != null:
			ring.visible = visible

func set_combat_unit_badges_visible(visible: bool) -> void:
	for renderer_value: Variant in _unit_renderers.values():
		var renderer: Node3D = renderer_value as Node3D
		if renderer != null and renderer.has_method("set_class_badge_visible"):
			renderer.call("set_class_badge_visible", visible)

func pulse_board_units_for_master_crit(attacker_cell: Vector2i, defender_cell: Vector2i, lift_height: float = 0.18, duration: float = 0.26) -> void:
	for cell_value: Variant in _unit_renderers.keys():
		var cell: Vector2i = cell_value as Vector2i
		if cell == attacker_cell or cell == defender_cell:
			continue
		var renderer: Node3D = _unit_renderers.get(cell) as Node3D
		if renderer == null or not is_instance_valid(renderer):
			continue
		var base_pos: Vector3 = renderer.position
		var tw := create_tween()
		tw.tween_property(renderer, "position:y", base_pos.y + lift_height, duration * 0.42) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(renderer, "position:y", base_pos.y, duration * 0.58) \
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func pulse_board_units_for_super_crit(attacker_cell: Vector2i, defender_cell: Vector2i, lift_height: float = 0.28, duration: float = 0.42) -> void:
	for cell_value: Variant in _unit_renderers.keys():
		var cell: Vector2i = cell_value as Vector2i
		if cell == attacker_cell or cell == defender_cell:
			continue
		var renderer: Node3D = _unit_renderers.get(cell) as Node3D
		if renderer == null or not is_instance_valid(renderer):
			continue
		var base_pos: Vector3 = renderer.position
		var tw := create_tween()
		tw.tween_property(renderer, "position:y", base_pos.y + lift_height, duration * 0.34) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(renderer, "position:y", base_pos.y, duration * 0.66) \
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func show_combat_stage(attacker_cell: Vector2i, defender_cell: Vector2i, _camera_pos: Vector3 = Vector3.ZERO) -> void:
	var parent_node: Node = get_parent()
	if parent_node != null and parent_node.has_method("set_combat_cinematic_ui"):
		parent_node.call("set_combat_cinematic_ui", true, [attacker_cell, defender_cell])
	var units_in_combat: Array[Unit] = []
	var attacker: Unit = _units.get(attacker_cell)
	var defender: Unit = _units.get(defender_cell)
	if attacker != null:
		units_in_combat.append(attacker)
	if defender != null:
		units_in_combat.append(defender)
	start_combat(units_in_combat, camera_override if camera_override != null else get_viewport().get_camera_3d())

func hide_combat_stage(immediate: bool = false) -> void:
	var parent_node: Node = get_parent()
	if parent_node != null and parent_node.has_method("set_combat_cinematic_ui"):
		parent_node.call("set_combat_cinematic_ui", false, [])
	end_combat()

func set_combat_board_theater(active: bool, focus_cells: Array = []) -> void:
	var focus_lookup: Dictionary = {}
	for cell_value: Variant in focus_cells:
		if cell_value is Vector2i:
			focus_lookup[cell_value] = true

	var default_dim: float = TILE_DIM_FACTOR_FOCUSED if _selection_focus_active else 1.0
	var board_dim: float = 0.34 if active else default_dim
	for cell_value: Variant in _tile_materials.keys():
		var cell: Vector2i = cell_value as Vector2i
		var mat: ShaderMaterial = _tile_materials.get(cell, null) as ShaderMaterial
		if mat == null:
			continue
		var tile_dim: float = board_dim
		if focus_lookup.has(cell):
			tile_dim = 1.0
		elif active:
			for focus_value: Variant in focus_lookup.keys():
				var focus_cell: Vector2i = focus_value as Vector2i
				var dist: int = _hex_distance(cell, focus_cell)
				if dist <= 1:
					tile_dim = maxf(tile_dim, 0.74)
					break
				elif dist <= 2:
					tile_dim = maxf(tile_dim, 0.54)
		mat.set_shader_parameter("dim_factor", tile_dim)

	for tower_root_value: Variant in _tower_instances.values():
		var tower_root: Node3D = tower_root_value as Node3D
		if tower_root == null:
			continue
		_set_tower_root_opacity(tower_root, 0.20 if active else 1.0)

	if _grass_deco_container != null:
		_grass_deco_container.visible = true

func _add_combat_stage_side(root: Node3D, offset: Vector3, terrain: int) -> void:
	var stage_color: Color = TERRAIN_COLORS.get(terrain, Color(0.44, 0.76, 0.33)).darkened(0.08)
	var side_root := Node3D.new()
	side_root.position = offset
	root.add_child(side_root)

	var wall_height: float = COMBAT_STAGE_WALL_UNIT_HEIGHT + COMBAT_STAGE_WALL_EXTRA_HEIGHT
	var hex_points: Array[Vector3] = _get_combat_stage_hex_points(HEX_SIZE * 0.96)
	for i: int in range(hex_points.size()):
		var start: Vector3 = hex_points[i]
		var finish: Vector3 = hex_points[(i + 1) % hex_points.size()]
		_add_combat_stage_wall_segment(side_root, start, finish, wall_height, stage_color, COMBAT_STAGE_WALL_ALPHA)

func _get_combat_stage_hex_points(radius: float) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for i: int in range(6):
		var angle: float = deg_to_rad(30.0 + (60.0 * float(i)))
		points.append(Vector3(cos(angle) * radius, 0.0, sin(angle) * radius))
	return points

func _create_combat_stage_piece(size: Vector3, local_pos: Vector3, color: Color, alpha: float) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var piece := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, alpha)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.roughness = 1.0
	mat.emission_enabled = true
	mat.emission = color.darkened(0.10)
	mat.emission_energy_multiplier = 0.05
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	piece.mesh = mesh
	piece.material_override = mat
	piece.position = local_pos
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return piece

func _add_combat_stage_wall_segment(root: Node3D, start: Vector3, finish: Vector3, height: float, color: Color, alpha: float) -> void:
	var delta: Vector3 = finish - start
	var length: float = delta.length()
	if length <= 0.001:
		return
	var midpoint: Vector3 = (start + finish) * 0.5
	var wall := _create_combat_stage_piece(
		Vector3(length, height, COMBAT_STAGE_WALL_THICKNESS),
		Vector3(midpoint.x, height * 0.5, midpoint.z),
		color,
		alpha
	)
	wall.rotation_degrees.y = rad_to_deg(atan2(delta.x, delta.z))
	root.add_child(wall)

func _configure_tile_material(mat: ShaderMaterial, terrain: int) -> void:
	_apply_cloud_shadow_params(mat, false)
	_apply_terrain_style_params(mat, terrain)
	if _is_night_visuals:
		mat.set_shader_parameter("shadow_threshold", 0.40)
		mat.set_shader_parameter("highlight_threshold", 0.84)
		mat.set_shader_parameter("band_smoothness", 0.012)
		mat.set_shader_parameter("light_bands", 3.0)
		mat.set_shader_parameter("shadow_tint", Vector3(0.26, 0.30, 0.40))
		mat.set_shader_parameter("mid_tint", Vector3(0.70, 0.74, 0.84))
		mat.set_shader_parameter("highlight_tint", Vector3(0.96, 1.00, 1.06))
		mat.set_shader_parameter("night_glow_color", _terrain_night_glow_color(terrain))
		mat.set_shader_parameter("night_glow_strength", _terrain_night_glow_strength(terrain))
		return

	mat.set_shader_parameter("shadow_threshold", 0.28)
	mat.set_shader_parameter("highlight_threshold", 0.72)
	mat.set_shader_parameter("band_smoothness", 0.016)
	mat.set_shader_parameter("light_bands", 3.0)
	mat.set_shader_parameter("shadow_tint", Vector3(0.52, 0.52, 0.60))
	mat.set_shader_parameter("mid_tint", Vector3(0.82, 0.82, 0.88))
	mat.set_shader_parameter("highlight_tint", Vector3(1.08, 1.08, 1.00))
	mat.set_shader_parameter("night_glow_color", Color(0.20, 0.32, 0.55, 1.0))
	mat.set_shader_parameter("night_glow_strength", 0.0)

func _apply_terrain_style_params(mat: ShaderMaterial, terrain: int) -> void:
	mat.set_shader_parameter("terrain_shadow_response", 1.0)
	mat.set_shader_parameter("terrain_sunbreak_response", 1.0)
	mat.set_shader_parameter("terrain_ambient_lift", 1.0)
	mat.set_shader_parameter("water_shimmer_strength", 0.0)
	mat.set_shader_parameter("water_shimmer_speed", 0.0)
	mat.set_shader_parameter("water_shimmer_tint", Vector3(0.88, 0.96, 1.10))
	match terrain:
		Terrain.WATER:
			mat.set_shader_parameter("terrain_shadow_response", 0.68)
			mat.set_shader_parameter("terrain_sunbreak_response", 1.35)
			mat.set_shader_parameter("terrain_ambient_lift", 1.06)
			mat.set_shader_parameter("water_shimmer_strength", 0.22 if not _is_night_visuals else 0.12)
			mat.set_shader_parameter("water_shimmer_speed", 0.085 if not _is_night_visuals else 0.040)
			mat.set_shader_parameter("water_shimmer_tint", Vector3(0.92, 1.00, 1.14))
		Terrain.MOUNTAIN, Terrain.CORDILLERA:
			mat.set_shader_parameter("terrain_shadow_response", 1.24)
			mat.set_shader_parameter("terrain_sunbreak_response", 0.72)
			mat.set_shader_parameter("terrain_ambient_lift", 0.94)
		Terrain.FOREST:
			mat.set_shader_parameter("terrain_shadow_response", 0.66 if _is_night_visuals else 0.74)
			mat.set_shader_parameter("terrain_sunbreak_response", 0.74)
			mat.set_shader_parameter("terrain_ambient_lift", 1.20 if _is_night_visuals else 1.10)
		Terrain.DESERT:
			mat.set_shader_parameter("terrain_shadow_response", 0.82)
			mat.set_shader_parameter("terrain_sunbreak_response", 1.22)
			mat.set_shader_parameter("terrain_ambient_lift", 1.04)

func _create_tower_material(base_color: Color, owner_id: int, owner_mix: float, emission_strength: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = TowerShader
	mat.next_pass = _get_tower_outline_mat()
	mat.set_meta("base_color", base_color)
	mat.set_meta("owner_mix", owner_mix)
	mat.set_meta("day_emission_strength", emission_strength)
	mat.set_meta("opacity", 1.0)
	_configure_tower_material(mat, owner_id)
	return mat

func _add_tower_piece(root: Node3D, size: Vector3, local_pos: Vector3, mat: ShaderMaterial) -> void:
	var box := BoxMesh.new()
	box.size = size
	var piece := MeshInstance3D.new()
	piece.mesh = box
	piece.material_override = mat
	piece.position = local_pos
	root.add_child(piece)

func _configure_tower_material(mat: ShaderMaterial, owner_id: int) -> void:
	_apply_cloud_shadow_params(mat, true)
	var owner_color: Color = GameData.get_player_color(owner_id) if owner_id > 0 else OWNER_COLORS[0]
	var base_color: Color = mat.get_meta("base_color", Color(0.70, 0.70, 0.72, 1.0)) as Color
	var owner_mix: float = float(mat.get_meta("owner_mix", 0.10))
	var emission_strength: float = float(mat.get_meta("day_emission_strength", 0.22))
	var opacity: float = float(mat.get_meta("opacity", 1.0))
	mat.set_shader_parameter("albedo_color", base_color.lerp(owner_color, owner_mix))
	mat.set_shader_parameter("emission_color", owner_color)
	mat.set_shader_parameter("opacity", opacity)
	if _is_night_visuals:
		mat.set_shader_parameter("emission_strength", emission_strength + 0.30)
		mat.set_shader_parameter("shadow_threshold", 0.38)
		mat.set_shader_parameter("highlight_threshold", 0.78)
		mat.set_shader_parameter("band_smoothness", 0.012)
		mat.set_shader_parameter("light_bands", 3.0)
		mat.set_shader_parameter("shadow_tint", Vector3(0.24, 0.28, 0.38))
		mat.set_shader_parameter("mid_tint", Vector3(0.72, 0.76, 0.88))
		mat.set_shader_parameter("highlight_tint", Vector3(1.02, 1.06, 1.14))
		mat.set_shader_parameter("night_glow_color", owner_color.lerp(Color(0.55, 0.72, 1.0), 0.40))
		mat.set_shader_parameter("night_glow_strength", 0.16 + _moon_visual_strength * 0.18)
		return

	mat.set_shader_parameter("emission_strength", emission_strength + (0.10 if owner_id != 0 else 0.0))
	mat.set_shader_parameter("shadow_threshold", 0.24)
	mat.set_shader_parameter("highlight_threshold", 0.68)
	mat.set_shader_parameter("band_smoothness", 0.016)
	mat.set_shader_parameter("light_bands", 3.0)
	mat.set_shader_parameter("shadow_tint", Vector3(0.46, 0.46, 0.54))
	mat.set_shader_parameter("mid_tint", Vector3(0.82, 0.82, 0.88))
	mat.set_shader_parameter("highlight_tint", Vector3(1.12, 1.12, 1.16))
	mat.set_shader_parameter("night_glow_color", Color(0.24, 0.36, 0.62, 1.0))
	mat.set_shader_parameter("night_glow_strength", 0.0)

func _cloud_shadow_size_weight() -> float:
	var map_span: float = float(mini(COLS, ROWS))
	return 1.0 - clampf(inverse_lerp(8.0, 16.0, map_span), 0.0, 1.0)

func _apply_cloud_shadow_params(mat: ShaderMaterial, is_tower: bool) -> void:
	if mat == null:
		return
	var small_map_weight: float = _cloud_shadow_size_weight()
	var scale_value: float = lerpf(CLOUD_SHADOW_SCALE_LARGE, CLOUD_SHADOW_SCALE_SMALL, small_map_weight)
	var speed_value: float = lerpf(CLOUD_SHADOW_SPEED_LARGE, CLOUD_SHADOW_SPEED_SMALL, small_map_weight)
	var pixel_size_value: float = lerpf(CLOUD_PIXEL_SIZE_LARGE, CLOUD_PIXEL_SIZE_SMALL, small_map_weight)
	var strength_large: float = CLOUD_SHADOW_STRENGTH_LARGE * (0.70 if is_tower else 1.0)
	var strength_small: float = CLOUD_SHADOW_STRENGTH_SMALL * (0.74 if is_tower else 1.0)
	var strength_value: float = lerpf(strength_large, strength_small, small_map_weight)
	var sunbreak_large: float = CLOUD_SUNBREAK_STRENGTH_LARGE * (0.75 if is_tower else 1.0)
	var sunbreak_small: float = CLOUD_SUNBREAK_STRENGTH_SMALL * (0.78 if is_tower else 1.0)
	var sunbreak_value: float = lerpf(sunbreak_large, sunbreak_small, small_map_weight)
	mat.set_shader_parameter("cloud_shadow_scale", scale_value)
	mat.set_shader_parameter("cloud_shadow_speed", speed_value)
	mat.set_shader_parameter("cloud_shadow_strength", strength_value)
	mat.set_shader_parameter("cloud_shadow_softness", CLOUD_SHADOW_SOFTNESS)
	mat.set_shader_parameter("cloud_pixel_size", pixel_size_value)
	mat.set_shader_parameter("cloud_sunbreak_strength", sunbreak_value)
	mat.set_shader_parameter("cloud_sunbreak_tint", CLOUD_SUNBREAK_TINT)

func _animate_tower_income_feedback(tower_root: Node3D, tower: Tower) -> void:
	var materials: Array = tower_root.get_meta("tower_materials", [])
	var income_root: Node3D = tower_root.get_meta("income_root", null) as Node3D
	var income_icon: Sprite3D = tower_root.get_meta("income_icon", null) as Sprite3D
	var income_label: Label3D = tower_root.get_meta("income_label", null) as Label3D
	var glow_color: Color = Color(0.42, 0.88, 1.0, 1.0)

	for material_value: Variant in materials:
		var mat: ShaderMaterial = material_value as ShaderMaterial
		if mat == null:
			continue
		var base_emission: float = float(mat.get_shader_parameter("emission_strength"))
		var base_emission_color: Color = mat.get_shader_parameter("emission_color") as Color
		var tw := create_tween()
		tw.tween_method(
			func(v: float) -> void:
				if is_instance_valid(mat):
					mat.set_shader_parameter("emission_strength", v),
			base_emission,
			base_emission + 0.60,
			0.16
		)
		tw.parallel().tween_method(
			func(c: Color) -> void:
				if is_instance_valid(mat):
					mat.set_shader_parameter("emission_color", c),
			base_emission_color,
			glow_color,
			0.16
		)
		tw.chain().tween_interval(0.12)
		tw.tween_method(
			func(v: float) -> void:
				if is_instance_valid(mat):
					mat.set_shader_parameter("emission_strength", v),
			base_emission + 0.60,
			base_emission,
			0.26
		)
		tw.parallel().tween_method(
			func(c: Color) -> void:
				if is_instance_valid(mat):
					mat.set_shader_parameter("emission_color", c),
			glow_color,
			base_emission_color,
			0.26
		)

	if income_root != null:
		var base_pos: Vector3 = income_root.position
		var jump_tw := create_tween()
		jump_tw.tween_property(income_root, "position", base_pos + Vector3(0.0, 0.14, 0.0), 0.14) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		jump_tw.tween_property(income_root, "position", base_pos, 0.22) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	if income_icon != null:
		var icon_tw := create_tween()
		icon_tw.tween_property(income_icon, "modulate", glow_color, 0.14)
		icon_tw.tween_property(income_icon, "modulate", C_GOLD, 0.26)

	if income_label != null:
		var label_tw := create_tween()
		label_tw.tween_property(income_label, "modulate", glow_color, 0.14)
		label_tw.tween_property(income_label, "modulate", C_GOLD, 0.26)

	VFXManager.show_world_text_label(
		tower_root.global_position + Vector3(0.0, 1.50, 0.0),
		"+%d" % tower.income,
		glow_color,
		24,
		0.0
	)

func _set_tower_root_opacity(tower_root: Node3D, opacity: float) -> void:
	var obstructed: bool = opacity < 0.999
	for child: Node in tower_root.get_children():
		var mesh_instance: MeshInstance3D = child as MeshInstance3D
		if mesh_instance == null:
			continue
		_set_mesh_obstruction_material(mesh_instance, obstructed, opacity)
	var income_icon: Sprite3D = tower_root.get_meta("income_icon") as Sprite3D if tower_root.has_meta("income_icon") else null
	if income_icon != null:
		income_icon.visible = opacity >= 0.999
	var income_label: Label3D = tower_root.get_meta("income_label") as Label3D if tower_root.has_meta("income_label") else null
	if income_label != null:
		income_label.visible = opacity >= 0.999


func _set_mesh_obstruction_material(mesh_instance: MeshInstance3D, obstructed: bool, opacity: float) -> void:
	if not obstructed:
		var original_material: Material = mesh_instance.get_meta("combat_original_material") as Material if mesh_instance.has_meta("combat_original_material") else null
		if original_material != null:
			mesh_instance.material_override = original_material
		return

	if not mesh_instance.has_meta("combat_original_material"):
		mesh_instance.set_meta("combat_original_material", mesh_instance.material_override)

	var obstruction_material: ShaderMaterial = mesh_instance.get_meta("combat_obstruction_material") as ShaderMaterial if mesh_instance.has_meta("combat_obstruction_material") else null
	if obstruction_material == null:
		obstruction_material = _create_combat_obstruction_material(mesh_instance)
		mesh_instance.set_meta("combat_obstruction_material", obstruction_material)

	obstruction_material.set_shader_parameter("opacity", opacity)
	mesh_instance.material_override = obstruction_material


func _create_combat_obstruction_material(mesh_instance: MeshInstance3D) -> ShaderMaterial:
	var base_color: Color = Color(0.72, 0.78, 0.86, 1.0)
	var edge_color: Color = Color(0.94, 0.98, 1.0, 1.0)
	var original_material: Material = mesh_instance.material_override

	if original_material is ShaderMaterial:
		var shader_material: ShaderMaterial = original_material as ShaderMaterial
		var shader_albedo: Variant = shader_material.get_shader_parameter("albedo_color")
		var shader_emission: Variant = shader_material.get_shader_parameter("emission_color")
		if shader_albedo is Color:
			base_color = shader_albedo as Color
		if shader_emission is Color:
			edge_color = (shader_emission as Color).lerp(Color(1.0, 1.0, 1.0, 1.0), 0.35)
	elif original_material is StandardMaterial3D:
		var standard_material: StandardMaterial3D = original_material as StandardMaterial3D
		base_color = standard_material.albedo_color
		edge_color = standard_material.albedo_color.lerp(Color(1.0, 1.0, 1.0, 1.0), 0.35)

	var obstruction_material := ShaderMaterial.new()
	obstruction_material.shader = CombatObstructionShader
	obstruction_material.set_shader_parameter("base_color", base_color)
	obstruction_material.set_shader_parameter("edge_color", edge_color)
	obstruction_material.set_shader_parameter("opacity", 0.18)
	obstruction_material.set_shader_parameter("rim_strength", 1.8)
	obstruction_material.set_shader_parameter("emission_strength", 0.35 if not _is_night_visuals else 0.55)
	obstruction_material.set_shader_parameter("roughness_value", 0.84)
	return obstruction_material

func _point_to_segment_distance_xz(point: Vector3, a: Vector3, b: Vector3) -> float:
	var p := Vector2(point.x, point.z)
	var start := Vector2(a.x, a.z)
	var finish := Vector2(b.x, b.z)
	var segment: Vector2 = finish - start
	var segment_length_sq: float = segment.length_squared()
	if segment_length_sq <= 0.0001:
		return p.distance_to(start)
	var t: float = clampf((p - start).dot(segment) / segment_length_sq, 0.0, 1.0)
	var projection: Vector2 = start + segment * t
	return p.distance_to(projection)

func _terrain_night_glow_color(terrain: int) -> Color:
	match terrain:
		Terrain.WATER:
			return Color(0.24, 0.42, 0.72, 1.0)
		Terrain.MOUNTAIN:
			return Color(0.26, 0.34, 0.54, 1.0)
		Terrain.FOREST:
			return Color(0.12, 0.22, 0.28, 1.0)
		Terrain.DESERT:
			return Color(0.22, 0.26, 0.40, 1.0)
		Terrain.VOLCANO:
			return Color(0.26, 0.20, 0.30, 1.0)
		Terrain.CORDILLERA:
			return Color(0.16, 0.18, 0.24, 1.0)
		_:
			return Color(0.18, 0.28, 0.42, 1.0)

func _terrain_night_glow_strength(terrain: int) -> float:
	var base_strength: float = 0.02
	match terrain:
		Terrain.WATER:
			base_strength = 0.14
		Terrain.MOUNTAIN:
			base_strength = 0.03
		Terrain.FOREST:
			base_strength = 0.030
		Terrain.DESERT:
			base_strength = 0.025
		Terrain.VOLCANO:
			base_strength = 0.05
		Terrain.CORDILLERA:
			base_strength = 0.01
		_:
			base_strength = 0.04
	return base_strength * _moon_visual_strength

# ─── Master placement ─────────────────────────────────────────────────────────────
func _place_masters() -> void:
	var placed_info: Array[String] = []
	for player_id: int in GameData.get_player_ids():
		var player_cell: Vector2i = GameData.get_master_cell_for_player(player_id)
		var master: Master = MasterScript.new()
		master.init_master(player_id, GameData.get_faction_for_player(player_id))
		place_unit(master, player_cell.x, player_cell.y)
		placed_info.append("J%d en %s" % [player_id, str(player_cell)])

	print("[HexGrid3D] Maestros colocados: %s" % " | ".join(placed_info))

# ─── Shader helpers ───────────────────────────────────────────────────────────────
## Shared terrain outline material (1 px side outline, cached for all 384 hex tiles).
func _get_terrain_outline_mat() -> StandardMaterial3D:
	if _terrain_outline_mat != null:
		return _terrain_outline_mat
	_terrain_outline_mat = StandardMaterial3D.new()
	_terrain_outline_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_terrain_outline_mat.albedo_color = Color.BLACK
	_terrain_outline_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	_terrain_outline_mat.grow = true
	_terrain_outline_mat.grow_amount = 0.018
	return _terrain_outline_mat

## Shared tower outline material (2 px side outline, cached for all tower meshes).
func _get_tower_outline_mat() -> StandardMaterial3D:
	if _tower_outline_mat != null:
		return _tower_outline_mat
	_tower_outline_mat = StandardMaterial3D.new()
	_tower_outline_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tower_outline_mat.albedo_color = Color.BLACK
	_tower_outline_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	_tower_outline_mat.grow = true
	_tower_outline_mat.grow_amount = 0.034
	return _tower_outline_mat

# ─── Team ring helpers ────────────────────────────────────────────────────────────
func _add_team_ring(cell: Vector2i, owner_id: int) -> void:
	var color: Color = GameData.get_player_color(owner_id) if owner_id > 0 else Color.WHITE
	var terrain: int = _map_terrain[cell.y][cell.x] as int
	var base_y: float = TERRAIN_HEIGHTS.get(terrain, 0.12)
	var world_pos: Vector3 = hex_to_world(cell.x, cell.y)

	var torus := TorusMesh.new()
	torus.outer_radius = 0.43
	torus.inner_radius = 0.05
	torus.rings = 4
	torus.ring_segments = 24

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.2
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var ring := MeshInstance3D.new()
	ring.mesh = torus
	ring.material_override = mat
	ring.position = Vector3(world_pos.x, base_y + 0.03, world_pos.z)
	add_child(ring)
	_team_rings[cell] = ring

func _update_team_ring_state(cell: Vector2i, unit: Unit) -> void:
	var ring: MeshInstance3D = _team_rings.get(cell)
	if ring == null or unit == null:
		return
	if not (ring.material_override is StandardMaterial3D):
		return
	var mat: StandardMaterial3D = ring.material_override as StandardMaterial3D
	var base_color: Color = GameData.get_player_color(unit.owner_id) if unit.owner_id > 0 else Color.WHITE
	var spent: bool = bool(unit.moved) or bool(unit.has_attacked)
	if spent:
		mat.albedo_color = base_color.darkened(0.58)
		mat.emission = base_color.darkened(0.46)
		mat.emission_energy_multiplier = 0.28
	else:
		mat.albedo_color = base_color
		mat.emission = base_color
		mat.emission_energy_multiplier = 1.2

func _remove_team_ring(cell: Vector2i) -> void:
	var ring: MeshInstance3D = _team_rings.get(cell)
	if ring != null:
		ring.queue_free()
	_team_rings.erase(cell)

func _move_team_ring(from: Vector2i, to: Vector2i) -> void:
	var ring: MeshInstance3D = _team_rings.get(from)
	if ring == null:
		return
	_team_rings.erase(from)
	_team_rings[to] = ring
	var terrain: int = _map_terrain[to.y][to.x] as int
	var base_y: float = TERRAIN_HEIGHTS.get(terrain, 0.12)
	var world_pos: Vector3 = hex_to_world(to.x, to.y)
	ring.position = Vector3(world_pos.x, base_y + 0.03, world_pos.z)

func _ensure_tutorial_focus_ring() -> void:
	if _tutorial_ring != null:
		return
	_tutorial_ring_material = StandardMaterial3D.new()
	_tutorial_ring_material.albedo_color = Color(1.0, 0.9, 0.32, 0.95)
	_tutorial_ring_material.emission_enabled = true
	_tutorial_ring_material.emission = Color(1.0, 0.86, 0.28, 1.0)
	_tutorial_ring_material.emission_energy_multiplier = 1.85
	_tutorial_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tutorial_ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_tutorial_ring_material.no_depth_test = true

	_tutorial_ring = Node3D.new()
	_tutorial_ring.visible = false
	add_child(_tutorial_ring)

	for side_index: int in range(6):
		var marker_box := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.22, 0.03, 0.035)
		marker_box.mesh = box
		marker_box.material_override = _tutorial_ring_material
		_tutorial_ring.add_child(marker_box)

		var corner_box := MeshInstance3D.new()
		var corner_mesh := BoxMesh.new()
		corner_mesh.size = Vector3(0.12, 0.03, 0.035)
		corner_box.mesh = corner_mesh
		corner_box.material_override = _tutorial_ring_material
		_tutorial_ring.add_child(corner_box)

func _update_tutorial_focus_ring() -> void:
	if _tutorial_ring == null or _tutorial_ring_material == null:
		return
	if _tutorial_ring_cell == Vector2i(-1, -1):
		_tutorial_ring.visible = false
		return
	if not _tile_materials.has(_tutorial_ring_cell):
		clear_tutorial_focus_cell()
		return
	var terrain: int = _map_terrain[_tutorial_ring_cell.y][_tutorial_ring_cell.x] as int
	var base_y: float = TERRAIN_HEIGHTS.get(terrain, 0.12)
	var world_pos: Vector3 = hex_to_world(_tutorial_ring_cell.x, _tutorial_ring_cell.y)
	var tile: Node3D = _tile_instances.get(_tutorial_ring_cell) as Node3D
	if tile == null:
		return
	var t: float = Time.get_ticks_msec() * 0.001
	var pulse: float = 0.96 + 0.06 * (0.5 + 0.5 * sin(t * 3.4))
	var bob: float = 0.05 + 0.015 * (0.5 + 0.5 * sin(t * 4.8))
	var glow_pulse: float = 0.95 + 0.45 * (0.5 + 0.5 * sin(t * 3.9))
	_tutorial_ring.visible = true
	_tutorial_ring.position = Vector3(world_pos.x, base_y + bob, world_pos.z)
	_tutorial_ring.rotation = Vector3.ZERO
	_tutorial_ring.scale = Vector3.ONE * pulse
	_tutorial_ring_material.albedo_color = Color(1.0, 0.9, 0.32, 0.75 + 0.18 * pulse)
	_tutorial_ring_material.emission_energy_multiplier = 1.5 + pulse * 0.9
	var tile_mat: ShaderMaterial = _tile_materials.get(_tutorial_ring_cell)
	if tile_mat != null:
		tile_mat.set_shader_parameter("emission_color", Color(1.0, 0.84, 0.20, 1.0))
		tile_mat.set_shader_parameter("emission_strength", glow_pulse)
		tile_mat.set_shader_parameter("dim_factor", 1.0)
	for side_index: int in range(6):
		var edge_marker: Node3D = tile.get_node_or_null("edge[%d]" % side_index) as Node3D
		if edge_marker == null:
			continue
		var edge_piece: MeshInstance3D = _tutorial_ring.get_child(side_index * 2) as MeshInstance3D
		var corner_piece: MeshInstance3D = _tutorial_ring.get_child(side_index * 2 + 1) as MeshInstance3D
		if edge_piece != null:
			edge_piece.global_transform = edge_marker.global_transform
			edge_piece.position += edge_marker.global_transform.basis.z.normalized() * 0.06
		if corner_piece != null:
			corner_piece.global_transform = edge_marker.global_transform
			corner_piece.position += edge_marker.global_transform.basis.x.normalized() * 0.22 + edge_marker.global_transform.basis.z.normalized() * 0.05

func _ensure_move_outline_root() -> void:
	if _move_outline_root != null:
		return
	_move_outline_material = StandardMaterial3D.new()
	_move_outline_material.albedo_color = Color(1.0, 0.92, 0.16, 0.98)
	_move_outline_material.emission_enabled = true
	_move_outline_material.emission = Color(1.0, 0.88, 0.12, 1.0)
	_move_outline_material.emission_energy_multiplier = 1.35
	_move_outline_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_move_outline_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_move_outline_material.no_depth_test = true
	_move_outline_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	_move_outline_root = Node3D.new()
	_move_outline_root.visible = false
	add_child(_move_outline_root)

func _clear_move_outline() -> void:
	if _move_outline_root == null:
		return
	for child: Node in _move_outline_root.get_children():
		child.queue_free()
	_move_outline_root.visible = false

func _refresh_move_outline() -> void:
	_clear_move_outline()
	if _move_cells.is_empty():
		return
	_ensure_move_outline_root()
	if _move_outline_root == null:
		return

	var boundary_cells: Dictionary = {}
	for cell: Vector2i in _move_cells:
		boundary_cells[cell] = true
	if _selected_cell != Vector2i(-1, -1):
		boundary_cells[_selected_cell] = true

	for cell: Vector2i in _move_cells:
		var tile: Node3D = _tile_instances.get(cell) as Node3D
		if tile == null:
			continue
		var terrain: int = _map_terrain[cell.y][cell.x] as int
		var base_y: float = TERRAIN_HEIGHTS.get(terrain, 0.12)
		for side_index: int in range(HexCell3DScript.SIDE_COUNT):
			var edge_marker: Marker3D = tile.get_node_or_null("edge[%d]" % side_index) as Marker3D
			if edge_marker == null:
				continue
			var outward: Vector3 = edge_marker.global_transform.basis.z.normalized()
			var sample_pos: Vector3 = edge_marker.global_transform.origin + outward * (HEX_SIZE * 0.9)
			var nb: Vector2i = world_to_hex(sample_pos)
			if nb != cell and boundary_cells.has(nb):
				continue
			var side_length: float = float(edge_marker.get_meta("side_length", 0.82))
			var segment_mesh := BoxMesh.new()
			segment_mesh.size = Vector3(side_length + 0.08, 0.03, 0.045)
			var segment := MeshInstance3D.new()
			segment.mesh = segment_mesh
			segment.material_override = _move_outline_material
			segment.global_transform = edge_marker.global_transform
			segment.position += outward * 0.08
			segment.position.y = base_y + 0.055
			_move_outline_root.add_child(segment)

	_move_outline_root.visible = _move_outline_root.get_child_count() > 0

func _update_move_outline_visual() -> void:
	if _move_outline_root == null or _move_outline_material == null or not _move_outline_root.visible:
		return
	var t: float = Time.get_ticks_msec() * 0.001
	var pulse_phase: float = 0.5 + 0.5 * sin(t * 3.6)
	var pulse: float = 1.12 + 0.58 * pulse_phase
	var alpha: float = 0.78 + 0.20 * pulse_phase
	_move_outline_material.emission_energy_multiplier = pulse
	_move_outline_material.albedo_color = Color(1.0, 0.92, 0.16, alpha)

func _ensure_summon_outline_root() -> void:
	if _summon_outline_root != null:
		return
	_summon_outline_material = StandardMaterial3D.new()
	_summon_outline_material.albedo_color = Color(0.38, 0.88, 1.0, 0.96)
	_summon_outline_material.emission_enabled = true
	_summon_outline_material.emission = Color(0.36, 0.86, 1.0, 1.0)
	_summon_outline_material.emission_energy_multiplier = 1.25
	_summon_outline_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_summon_outline_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_summon_outline_material.no_depth_test = true
	_summon_outline_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	_summon_outline_root = Node3D.new()
	_summon_outline_root.visible = false
	add_child(_summon_outline_root)

func _clear_summon_outline() -> void:
	if _summon_outline_root == null:
		return
	for child: Node in _summon_outline_root.get_children():
		child.queue_free()
	_summon_outline_root.visible = false

func _refresh_summon_outline() -> void:
	_clear_summon_outline()
	if _highlighted_cells.is_empty():
		return
	_ensure_summon_outline_root()
	if _summon_outline_root == null:
		return

	var boundary_cells: Dictionary = {}
	for cell: Vector2i in _highlighted_cells:
		boundary_cells[cell] = true

	for cell: Vector2i in _highlighted_cells:
		var tile: Node3D = _tile_instances.get(cell) as Node3D
		if tile == null:
			continue
		var terrain: int = _map_terrain[cell.y][cell.x] as int
		var base_y: float = TERRAIN_HEIGHTS.get(terrain, 0.12)
		for side_index: int in range(HexCell3DScript.SIDE_COUNT):
			var edge_marker: Marker3D = tile.get_node_or_null("edge[%d]" % side_index) as Marker3D
			if edge_marker == null:
				continue
			var outward: Vector3 = edge_marker.global_transform.basis.z.normalized()
			var sample_pos: Vector3 = edge_marker.global_transform.origin + outward * (HEX_SIZE * 0.9)
			var nb: Vector2i = world_to_hex(sample_pos)
			if nb != cell and boundary_cells.has(nb):
				continue
			var side_length: float = float(edge_marker.get_meta("side_length", 0.82))
			var segment_mesh := BoxMesh.new()
			segment_mesh.size = Vector3(side_length + 0.08, 0.03, 0.045)
			var segment := MeshInstance3D.new()
			segment.mesh = segment_mesh
			segment.material_override = _summon_outline_material
			segment.global_transform = edge_marker.global_transform
			segment.position += outward * 0.08
			segment.position.y = base_y + 0.055
			_summon_outline_root.add_child(segment)

	_summon_outline_root.visible = _summon_outline_root.get_child_count() > 0

func _update_summon_outline_visual() -> void:
	if _summon_outline_root == null or _summon_outline_material == null or not _summon_outline_root.visible:
		return
	var t: float = Time.get_ticks_msec() * 0.001
	var pulse_phase: float = 0.5 + 0.5 * sin(t * 3.2)
	var pulse: float = 1.02 + 0.42 * pulse_phase
	var alpha: float = 0.74 + 0.20 * pulse_phase
	_summon_outline_material.emission_energy_multiplier = pulse
	_summon_outline_material.albedo_color = Color(0.38, 0.88, 1.0, alpha)

# ─── Fallback terrain ─────────────────────────────────────────────────────────────
func _fallback_terrain() -> void:
	for r: int in range(ROWS):
		var row: Array = []
		for c: int in range(COLS):
			row.append(0)   # all GRASS
		_map_terrain.append(row)
