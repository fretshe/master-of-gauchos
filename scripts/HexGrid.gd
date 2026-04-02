extends Node2D

const UnitScript            := preload("res://scripts/Unit.gd")
const TowerScript           := preload("res://scripts/Tower.gd")
const MasterScript          := preload("res://scripts/Master.gd")
const AnimationManagerScript := preload("res://scripts/AnimationManager.gd")

# ─── Signals ───────────────────────────────────────────────────────────────────
signal unit_selected(unit: Unit)
signal unit_deselected()
signal tower_captured(tower_name: String, player_id: int)
signal placement_confirmed(col: int, row: int, unit_type: int, player_id: int)
signal master_killed(player_id: int)
signal master_placement_confirmed(col: int, row: int, unit_type: int, player_id: int)
signal enemy_inspected(enemy: Unit, multiplier: float)
signal combat_resolved(attacker: Unit, defender: Unit, result: Dictionary)

# ─── Grid dimensions ───────────────────────────────────────────────────────────
var   COLS:     int   = 24
var   ROWS:     int   = 16
const HEX_SIZE: float = 64.0

# ─── Terrain ───────────────────────────────────────────────────────────────────
enum Terrain { GRASS, WATER, MOUNTAIN, FOREST, DESERT, VOLCANO, CORDILLERA }

const TERRAIN_COLORS: Dictionary = {
	Terrain.GRASS:    Color(0.44, 0.76, 0.33),
	Terrain.WATER:    Color(0.20, 0.53, 0.87),
	Terrain.MOUNTAIN: Color(0.60, 0.60, 0.60),
	Terrain.FOREST:   Color(0.13, 0.45, 0.13),
	Terrain.DESERT:   Color(0.76, 0.66, 0.34),
	Terrain.VOLCANO:  Color(0.72, 0.18, 0.05),
	Terrain.CORDILLERA: Color(0.20, 0.22, 0.26),
}

const TERRAIN_NAMES: Dictionary = {
	Terrain.GRASS:    "Grass",
	Terrain.WATER:    "Water",
	Terrain.MOUNTAIN: "Mountain",
	Terrain.FOREST:   "Forest",
	Terrain.DESERT:   "Desert",
	Terrain.VOLCANO:  "Volcano",
	Terrain.CORDILLERA: "Cordillera",
}

# Static fallback used in the editor / if MapGenerator hasn't run yet (24 cols × 16 rows)
const MAP_DATA: Array[Array] = [
	[0,0,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,0],
	[0,3,3,0,0,1,1,0,0,3,3,0,0,3,3,0,0,0,1,1,0,3,3,0],
	[0,3,3,3,0,0,0,0,3,3,3,0,0,3,3,3,0,0,0,0,0,3,3,0],
	[0,0,3,0,0,0,0,0,0,3,0,0,0,0,3,0,0,0,0,0,0,0,3,0],
	[0,0,0,0,0,0,0,0,0,0,0,2,2,0,0,0,0,0,0,0,0,0,0,0],
	[0,0,0,0,0,0,0,0,0,0,2,2,2,2,0,0,0,0,0,0,0,0,0,0],
	[0,0,1,1,0,0,0,0,0,2,2,2,2,2,2,0,0,0,0,0,1,1,0,0],
	[0,0,1,1,0,0,0,0,0,0,2,2,2,2,0,0,0,0,0,0,1,1,0,0],
	[0,0,0,0,0,0,0,0,0,0,0,2,2,0,0,0,0,0,0,0,0,0,0,0],
	[0,0,0,0,4,4,0,0,0,0,0,0,0,0,0,0,0,0,4,4,0,0,0,0],
	[0,0,0,4,4,4,0,0,0,0,0,0,0,0,0,0,0,4,4,4,0,0,0,0],
	[0,0,0,4,4,0,0,0,0,5,5,0,0,5,5,0,0,4,4,0,0,0,0,0],
	[0,3,0,0,0,0,0,0,5,5,5,0,0,5,5,5,0,0,0,0,0,0,3,0],
	[0,3,3,0,0,0,0,0,0,5,0,0,0,0,5,0,0,0,0,0,0,3,3,0],
	[0,3,3,3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3,3,3,0],
	[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
]

# ─── Token / Tower visuals ─────────────────────────────────────────────────────
const TOKEN_SIZE  := 36.0
const TOKEN_HALF  := TOKEN_SIZE * 0.5

const OWNER_COLORS: Dictionary = {
	1: Color(0.15, 0.40, 0.85),
	2: Color(0.85, 0.18, 0.18),
}

const TOWER_COLORS: Dictionary = {
	0: Color(0.55, 0.55, 0.55),
	1: Color(0.15, 0.40, 0.85),
	2: Color(0.85, 0.18, 0.18),
}

const C_GOLD := Color(0.95, 0.80, 0.20)

# ─── Perspective transform ──────────────────────────────────────────────────────
# Scale Y = 0.65 (vertical compression) + slight X skew (depth lean).
# Applied to the HexGrid node so _draw() and child sprites are transformed together.
# All external code (camera, VFX) uses world-space positions; place_unit() returns
# world positions via to_global().
const PERSP_SCALE_Y: float = 0.65
const PERSP_SKEW_X:  float = 0.05

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

# ─── State ─────────────────────────────────────────────────────────────────────
var current_player:    int  = 1
var combat_manager          = null
var resource_manager        = null
var camera_controller       = null   # set by Main.gd after both nodes are ready

var selected_cell        := Vector2i(-1, -1)
var _selected_unit       = null
var _move_cells: Array          = []
var _attack_cells: Array        = []
var _ranged_attack_cells: Array = []   # Archer range-2 targets (highlighted orange)

var _units: Dictionary   = {}
var _towers: Dictionary  = {}
var _hex_verts: PackedVector2Array

var _map_terrain: Array  = []   # [row][col] int — populated from GameData in _ready()

# ─── Animation ─────────────────────────────────────────────────────────────────
var animation_manager    = null
var _animating: bool     = false

# ─── Normal placement mode ─────────────────────────────────────────────────────
var _placement_mode: bool     = false
var _placement_unit_type: int = -1
var _placement_player_id: int = 1

# ─── Master placement mode ─────────────────────────────────────────────────────
var _master_placement_mode: bool    = false
var _master_placement_cell: Vector2i = Vector2i(-1, -1)

# ─── Normal placement: master cell for adjacency restriction ───────────────────
var _placement_master_cell: Vector2i = Vector2i(-1, -1)

# ─── Master sprites (AnimatedSprite2D, keyed by Unit reference) ─────────────────
var _master_sprites: Dictionary = {}   # Unit → AnimatedSprite2D
var _pending_tower_captures: Dictionary = {}   # Vector2i -> player_id

# ─── Public API ────────────────────────────────────────────────────────────────
func place_unit(unit: Unit, col: int, row: int, defer_tower_capture: bool = false) -> void:
	var cell := Vector2i(col, row)
	_units[cell] = unit
	unit.visual_pos = to_global(hex_to_screen(col, row))  # store world-space position
	if defer_tower_capture:
		var tower: Tower = _towers.get(cell, null)
		if tower != null and tower.owner_id != unit.owner_id:
			_pending_tower_captures[cell] = unit.owner_id

func get_unit_at(col: int, row: int) -> Unit:
	return _units.get(Vector2i(col, row), null)

func get_all_units() -> Array:
	return _units.values()

func get_all_towers() -> Array:
	return _towers.values()

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
		var capture_bonus: int = tower.capture(unit.owner_id)
		if resource_manager != null and capture_bonus > 0:
			resource_manager.add_essence(unit.owner_id, capture_bonus)
		emit_signal("tower_captured", tower.tower_name, unit.owner_id)
		AudioManager.play_capture()
		if capture_bonus > 0:
			AudioManager.play_essence()

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
		healed_count += 1
	return healed_count

func get_tower_at(col: int, row: int) -> Tower:
	return _towers.get(Vector2i(col, row), null)

func get_all_tower_cells() -> Array:
	return _towers.keys()

## Public wrapper so Main.gd can deselect on Escape without touching private state.
func deselect() -> void:
	_deselect()

## Returns the terrain data array ([row][col] int) for the minimap.
func get_terrain_data() -> Array:
	return _map_terrain

func get_selected_unit() -> Unit:
	return _selected_unit

func get_selected_cell() -> Vector2i:
	return selected_cell

func enter_placement_mode(unit_type: int, player_id: int) -> void:
	_placement_mode        = true
	_placement_unit_type   = unit_type
	_placement_player_id   = player_id
	_placement_master_cell = _find_master_cell(player_id)
	_deselect()
	print("[HexGrid] Placement mode — click adjacent to your Master to summon.")
	queue_redraw()

func exit_placement_mode() -> void:
	if not _placement_mode:
		return
	_placement_mode        = false
	_placement_unit_type   = -1
	_placement_master_cell = Vector2i(-1, -1)
	queue_redraw()

func enter_master_placement_mode(unit_type: int, player_id: int, master_cell: Vector2i) -> void:
	_master_placement_mode = true
	_placement_unit_type   = unit_type
	_placement_player_id   = player_id
	_master_placement_cell = master_cell
	_deselect()
	print("[HexGrid] Master placement mode — click an adjacent cell to summon for free.")
	queue_redraw()

func exit_master_placement_mode() -> void:
	if not _master_placement_mode:
		return
	_master_placement_mode = false
	_master_placement_cell = Vector2i(-1, -1)
	_placement_unit_type   = -1
	queue_redraw()

# ─── Geometry ──────────────────────────────────────────────────────────────────
func _build_unit_hex() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(6):
		var a: float = deg_to_rad(60.0 * i)
		pts.append(Vector2(cos(a), sin(a)))
	return pts

func hex_to_screen(col: int, row: int) -> Vector2:
	var x := HEX_SIZE * 1.5 * col
	var y := HEX_SIZE * sqrt(3.0) * (row + (0.5 if col % 2 == 1 else 0.0))
	return Vector2(x, y) + _grid_origin()

func screen_to_hex(pos: Vector2) -> Vector2i:
	# pos arrives as a world-space position (get_global_mouse_position).
	# hex_to_screen() returns local coordinates, so invert the node transform first.
	var lpos: Vector2 = to_local(pos)
	var best      := Vector2i(-1, -1)
	var best_dist := HEX_SIZE * 2.0
	for c in range(COLS):
		for r in range(ROWS):
			var d := lpos.distance_to(hex_to_screen(c, r))
			if d < best_dist:
				best_dist = d
				best = Vector2i(c, r)
	if best != Vector2i(-1, -1):
		if lpos.distance_to(hex_to_screen(best.x, best.y)) > HEX_SIZE:
			return Vector2i(-1, -1)
	return best

func _grid_origin() -> Vector2:
	# Fixed world-space offset — camera handles panning
	return Vector2(HEX_SIZE * 2.0, HEX_SIZE * 2.0)

func _hex_distance(a: Vector2i, b: Vector2i) -> int:
	var aq  := a.x
	var ar  := a.y - (a.x - (a.x % 2)) / 2
	var bq  := b.x
	var br  := b.y - (b.x - (b.x % 2)) / 2
	var as_ := -aq - ar
	var bs  := -bq - br
	return (abs(aq - bq) + abs(ar - br) + abs(as_ - bs)) / 2

func _get_neighbors(col: int, row: int) -> Array:
	var origin := Vector2i(col, row)
	var result: Array = []
	for dc: int in range(-1, 2):
		for dr: int in range(-1, 2):
			if dc == 0 and dr == 0:
				continue
			var candidate := Vector2i(col + dc, row + dr)
			if candidate.x < 0 or candidate.x >= COLS or candidate.y < 0 or candidate.y >= ROWS:
				continue
			if _hex_distance(origin, candidate) == 1:
				result.append(candidate)
	return result

## Returns the movement point cost to enter a cell based on its terrain.
func _get_terrain_cost(col: int, row: int) -> int:
	var t: int = _map_terrain[row][col]
	if t == Terrain.MOUNTAIN or t == Terrain.FOREST:
		return 2
	return 1

## Finds the cell of the given player's Master, or Vector2i(-1,-1) if not found.
func _find_master_cell(player_id: int) -> Vector2i:
	for cell: Vector2i in _units.keys():
		var u = _units[cell]
		if u is Master and u.owner_id == player_id:
			return cell
	return Vector2i(-1, -1)

func _is_valid_summon_cell(cell: Vector2i) -> bool:
	if cell == Vector2i(-1, -1):
		return false
	if get_unit_at(cell.x, cell.y) != null:
		return false
	var terrain: int = _map_terrain[cell.y][cell.x]
	return terrain != Terrain.WATER and terrain != Terrain.CORDILLERA

# ─── Highlight computation (Dijkstra with terrain costs) ───────────────────────
func _compute_highlights(col: int, row: int, unit: Unit) -> void:
	_move_cells.clear()
	_attack_cells.clear()
	_ranged_attack_cells.clear()

	var moves_left: int = unit.get_moves_left()
	if moves_left == 0:
		return

	# Dijkstra: visited[cell] = minimum movement-point cost to reach it
	var visited: Dictionary = { Vector2i(col, row): 0 }
	# Queue entries: [cost, cell]
	var queue: Array = [[0, Vector2i(col, row)]]

	while not queue.is_empty():
		# Pop cheapest entry (grid is small, linear scan is fine)
		var min_i: int = 0
		for i in range(1, queue.size()):
			if queue[i][0] < queue[min_i][0]:
				min_i = i
		var entry    = queue[min_i]
		queue.remove_at(min_i)

		var cost: int         = entry[0]
		var current: Vector2i = entry[1]

		# Stale entry check
		if visited.get(current, INF) < cost:
			continue

		for nb: Vector2i in _get_neighbors(current.x, current.y):
			var terrain: int = _map_terrain[nb.y][nb.x]
			# Water and Cordillera are completely impassable
			if terrain == Terrain.WATER or terrain == Terrain.CORDILLERA:
				continue
			var step: int     = 2 if (terrain == Terrain.MOUNTAIN or terrain == Terrain.FOREST) else 1
			if unit.bonus_pathfinder and (terrain == Terrain.MOUNTAIN or terrain == Terrain.FOREST):
				step = 1
			var new_cost: int = cost + step

			var nb_unit: Unit = _units.get(nb, null)
			if nb_unit == null:
				# Empty reachable cell
				if new_cost <= moves_left and (not visited.has(nb) or visited[nb] > new_cost):
					visited[nb] = new_cost
					if nb not in _move_cells:
						_move_cells.append(nb)
					queue.append([new_cost, nb])

	# Always include adjacent enemies from starting position (attack without moving)
	for nb: Vector2i in _get_neighbors(col, row):
		var nb_unit: Unit = _units.get(nb, null)
		if nb_unit != null and nb_unit.owner_id != unit.owner_id:
			if nb not in _attack_cells:
				_attack_cells.append(nb)

	# Ranged attack cells: Archer/Master — enemies at exactly hex-distance 2 (orange)
	for distance in range(2, maxi(2, unit.attack_range) + 1):
		if not unit.can_attack_at_distance(distance):
			continue
		for c2 in range(COLS):
			for r2 in range(ROWS):
				var target := Vector2i(c2, r2)
				if _hex_distance(Vector2i(col, row), target) != distance:
					continue
				var t_unit: Unit = _units.get(target, null)
				if t_unit != null and t_unit.owner_id != unit.owner_id:
					if target not in _attack_cells:
						_ranged_attack_cells.append(target)

# ─── Godot callbacks ───────────────────────────────────────────────────────────
func _ready() -> void:
	# Apply perspective transform FIRST — place_unit() calls to_global() which needs it
	transform = Transform2D(
		Vector2(1.0, 0.0),
		Vector2(PERSP_SKEW_X, PERSP_SCALE_Y),
		Vector2.ZERO
	)
	_hex_verts = _build_unit_hex()

	# Load terrain from GameData (generated by MapGenerator in Main._ready())
	if GameData.map_terrain.size() > 0:
		_map_terrain = GameData.map_terrain
		ROWS = _map_terrain.size()
		COLS = _map_terrain[0].size() if ROWS > 0 else 24
	else:
		# Fallback: convert static MAP_DATA const to mutable Array
		_map_terrain = []
		for r_arr: Array in MAP_DATA:
			_map_terrain.append(Array(r_arr))

	_place_towers()
	_place_masters()

	# Initialise AnimationManager as a child node
	animation_manager = AnimationManagerScript.new()
	animation_manager.name    = "AnimationManager"
	animation_manager.hex_grid = self
	add_child(animation_manager)

func _process(_delta: float) -> void:
	for unit: Unit in _master_sprites.keys():
		var sprite: AnimatedSprite2D = _master_sprites[unit]
		# visual_pos is world-space; sprite.position needs local-space (child of HexGrid)
		sprite.position = to_local(unit.visual_pos)
		var base_mod: Color = Color(1.2, 0.7, 0.7) if unit.owner_id == 2 else Color.WHITE
		base_mod.a      = unit.visual_alpha
		sprite.modulate = base_mod

func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	if not (event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return

	# Block all clicks while an animation is running
	if _animating:
		return

	# get_global_mouse_position() converts screen coords → world coords via camera
	var cell := screen_to_hex(get_global_mouse_position())

	# ── Master placement mode (adjacent cells only, free summon) ──────────────
	if _master_placement_mode:
		if _is_valid_summon_cell(cell):
			var adj: Array = _get_neighbors(_master_placement_cell.x, _master_placement_cell.y)
			if cell in adj:
				emit_signal("master_placement_confirmed", cell.x, cell.y,
						_placement_unit_type, _placement_player_id)
				exit_master_placement_mode()
		return

	# ── Normal placement mode ─────────────────────────────────────────────────
	if _placement_mode:
		if _is_valid_summon_cell(cell):
			var can_place: bool = false
			if _placement_master_cell != Vector2i(-1, -1):
				var adj: Array = _get_neighbors(_placement_master_cell.x, _placement_master_cell.y)
				can_place = cell in adj
			else:
				can_place = true  # fallback if Master not found
			if can_place:
				emit_signal("placement_confirmed", cell.x, cell.y,
						_placement_unit_type, _placement_player_id)
				exit_placement_mode()
		return

	# ── Nothing selected ──────────────────────────────────────────────────────
	if selected_cell == Vector2i(-1, -1):
		if cell == Vector2i(-1, -1):
			return
		var unit: Unit = _units.get(cell, null)
		if unit != null and unit.owner_id == current_player:
			selected_cell  = cell
			_selected_unit = unit
			_compute_highlights(cell.x, cell.y, unit)
			emit_signal("unit_selected", unit)
			if camera_controller != null:
				camera_controller.center_on(to_global(hex_to_screen(cell.x, cell.y)))
			print("[HexGrid] Selected → " + unit.stats_string())
		elif unit != null:
			print("[HexGrid] Enemy → " + unit.stats_string())
			emit_signal("enemy_inspected", unit, 1.0)
		queue_redraw()
		return

	# ── Unit selected ─────────────────────────────────────────────────────────
	if cell == selected_cell:
		_deselect()
		return

	if cell in _move_cells:
		_move_unit(selected_cell, cell)
		return

	if cell in _attack_cells:
		var target_unit: Unit = _units.get(cell, null)
		if target_unit != null:
			var mult: float = Unit.get_damage_multiplier(_selected_unit.unit_type, target_unit.unit_type)
			emit_signal("enemy_inspected", target_unit, mult)
		_initiate_combat(selected_cell, cell)
		return

	if cell in _ranged_attack_cells:
		var target_unit: Unit = _units.get(cell, null)
		if target_unit != null:
			var mult: float = Unit.get_damage_multiplier(_selected_unit.unit_type, target_unit.unit_type)
			emit_signal("enemy_inspected", target_unit, mult)
		_initiate_combat(selected_cell, cell)
		return

	var other: Unit = _units.get(cell, null)
	if other != null and other.owner_id == current_player:
		selected_cell  = cell
		_selected_unit = other
		_compute_highlights(cell.x, cell.y, other)
		emit_signal("unit_selected", other)
		if camera_controller != null:
			camera_controller.center_on(to_global(hex_to_screen(cell.x, cell.y)))
		print("[HexGrid] Switched → " + other.stats_string())
		queue_redraw()
		return

	_deselect()

# ─── Actions ───────────────────────────────────────────────────────────────────
func _move_unit(from: Vector2i, to: Vector2i) -> void:
	_animating = true

	var unit: Unit        = _units[from]
	var from_screen: Vector2 = to_global(hex_to_screen(from.x, from.y))
	var to_screen: Vector2   = to_global(hex_to_screen(to.x, to.y))

	# Logical move first — keeps _units consistent during animation
	_units.erase(from)
	_units[to] = unit
	unit.use_move(_get_terrain_cost(to.x, to.y))

	# Animate slide
	AudioManager.play_move()
	animation_manager.animate_move(unit, from_screen, to_screen)
	await animation_manager.animation_finished

	# Tower capture (after move lands)
	var tower: Tower = _towers.get(to, null)
	if tower != null and tower.owner_id != unit.owner_id:
		var capture_bonus: int = tower.capture(unit.owner_id)
		if resource_manager != null and capture_bonus > 0:
			resource_manager.add_essence(unit.owner_id, capture_bonus)
		emit_signal("tower_captured", tower.tower_name, unit.owner_id)
		AudioManager.play_capture()
		if capture_bonus > 0:
			AudioManager.play_essence()
		VFXManager.particles_capture(to_screen)
		animation_manager.animate_capture(tower)
		await animation_manager.animation_finished
		print("[HexGrid] Player %d captured a tower at (%d,%d)!" % [
			unit.owner_id, to.x, to.y
		])

	print("[HexGrid] %s moved to (%d,%d) | moves left: %d" % [
		unit.unit_name, to.x, to.y, unit.get_moves_left()
	])
	selected_cell  = to
	_selected_unit = unit
	_compute_highlights(to.x, to.y, unit)
	emit_signal("unit_selected", unit)
	_animating = false
	queue_redraw()

func _initiate_combat(attacker_cell: Vector2i, defender_cell: Vector2i) -> void:
	if combat_manager == null:
		push_error("HexGrid: combat_manager not set!")
		return

	_animating = true

	var attacker: Unit = _units[attacker_cell]
	var defender: Unit = _units[defender_cell]
	# Ranged only for units with explicit extended range and targets beyond adjacency.
	var is_ranged: bool = attacker.can_attack_at_distance(_hex_distance(attacker_cell, defender_cell)) and \
			_hex_distance(attacker_cell, defender_cell) > 1

	# Exhaust attacker moves
	attacker.exhaust()

	# Track level before combat to detect level-up
	var atk_level_before: int = attacker.level

	# ── Resolve combat (get full blow log) ────────────────────────────────────
	var result: Dictionary = combat_manager.resolve_combat(attacker, defender, is_ranged)

	# ── Cinematic camera zoom ─────────────────────────────────────────────────
	if camera_controller != null:
		await camera_controller.enter_combat_mode(
				attacker.visual_pos, defender.visual_pos)

	# ── Animate duel with floating damage numbers ─────────────────────────────
	AudioManager.play_attack()
	animation_manager.animate_duel(
			attacker, defender,
			result.attacker_log, result.defender_log)
	await animation_manager.animation_finished

	# ── Restore camera (fire-and-forget, runs during death animations) ────────
	if camera_controller != null:
		camera_controller.exit_combat_mode()

	# ── Notify HUD of combat result ───────────────────────────────────────────
	emit_signal("combat_resolved", attacker, defender, result)

	# ── Defender death ────────────────────────────────────────────────────────
	if result.defender_died:
		AudioManager.play_death()
		animation_manager.animate_death(defender)
		await animation_manager.animation_finished
		_remove_master_sprite(defender)
		_units.erase(defender_cell)
		if defender is Master:
			print("[HexGrid] *** Maestro del Jugador %d ha caído! ***" % defender.owner_id)
			_animating = false
			_deselect()
			emit_signal("master_killed", defender.owner_id)
			return

	# ── Attacker death ────────────────────────────────────────────────────────
	if result.attacker_died:
		AudioManager.play_death()
		animation_manager.animate_death(attacker)
		await animation_manager.animation_finished
		_remove_master_sprite(attacker)
		_units.erase(attacker_cell)
		if attacker is Master:
			print("[HexGrid] *** Maestro del Jugador %d ha caído! ***" % attacker.owner_id)
			_animating = false
			_deselect()
			emit_signal("master_killed", attacker.owner_id)
			return

	# ── Level-up animation ────────────────────────────────────────────────────
	if not result.attacker_died and attacker.level > atk_level_before:
		animation_manager.animate_level_up(attacker)
		await animation_manager.animation_finished

	_animating = false
	_deselect()

func _deselect() -> void:
	selected_cell  = Vector2i(-1, -1)
	_selected_unit = null
	_move_cells.clear()
	_attack_cells.clear()
	_ranged_attack_cells.clear()
	emit_signal("unit_deselected")
	queue_redraw()


# ─── Drawing ───────────────────────────────────────────────────────────────────
func _draw() -> void:
	# Pass 1: terrain
	for c in range(COLS):
		for r in range(ROWS):
			_draw_hex(c, r)

	# Pass 1.5: normal placement overlay — purple, adjacent to Master only
	if _placement_mode and _placement_master_cell != Vector2i(-1, -1):
		for adj: Vector2i in _get_neighbors(_placement_master_cell.x, _placement_master_cell.y):
			if _is_valid_summon_cell(adj):
				var ctr := hex_to_screen(adj.x, adj.y)
				var pts2 := PackedVector2Array()
				for v: Vector2 in _hex_verts:
					pts2.append(ctr + v * HEX_SIZE)
				draw_colored_polygon(pts2, Color(0.55, 0.1, 0.9, 0.22))
				for i in range(pts2.size()):
					draw_line(pts2[i], pts2[(i + 1) % pts2.size()],
							Color(0.75, 0.3, 1.0, 0.75), 2.0)

	# Pass 1.6: master placement overlay — purple, adjacent to Master only (free summon)
	if _master_placement_mode and _master_placement_cell != Vector2i(-1, -1):
		for adj: Vector2i in _get_neighbors(_master_placement_cell.x, _master_placement_cell.y):
			if _is_valid_summon_cell(adj):
				var ctr := hex_to_screen(adj.x, adj.y)
				var pts2 := PackedVector2Array()
				for v: Vector2 in _hex_verts:
					pts2.append(ctr + v * HEX_SIZE)
				draw_colored_polygon(pts2, Color(0.55, 0.1, 0.9, 0.22))
				for i in range(pts2.size()):
					draw_line(pts2[i], pts2[(i + 1) % pts2.size()],
							Color(0.75, 0.3, 1.0, 0.75), 2.0)

	# Pass 2: towers
	for cell_key: Vector2i in _towers.keys():
		_draw_tower(_towers[cell_key], cell_key.x, cell_key.y)

	# Pass 3: units — each uses draw_set_transform for scale/position
	for unit: Unit in _units.values():
		_draw_unit_token(unit)

	# Always reset transform after unit drawing pass
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ── Terrain ────────────────────────────────────────────────────────────────────
func _draw_hex(col: int, row: int) -> void:
	var terrain: int = _map_terrain[row][col]
	var center       := hex_to_screen(col, row)
	var cell         := Vector2i(col, row)

	var pts := PackedVector2Array()
	for v: Vector2 in _hex_verts:
		pts.append(center + v * HEX_SIZE)

	draw_colored_polygon(pts, TERRAIN_COLORS[terrain])

	# Water cells are never highlighted, regardless of range
	if terrain != Terrain.WATER:
		if cell in _move_cells:
			draw_colored_polygon(pts, Color(0.0, 1.0, 0.0, 0.30))
		elif cell in _attack_cells:
			draw_colored_polygon(pts, Color(1.0, 0.0, 0.0, 0.30))
		elif cell in _ranged_attack_cells:
			draw_colored_polygon(pts, Color(1.0, 0.55, 0.0, 0.30))

	var is_sel: bool = (cell == selected_cell)
	var border_col: Color
	if is_sel:
		border_col = Color.YELLOW
	elif terrain != Terrain.WATER and cell in _move_cells:
		border_col = Color.GREEN
	elif terrain != Terrain.WATER and cell in _attack_cells:
		border_col = Color.RED
	elif terrain != Terrain.WATER and cell in _ranged_attack_cells:
		border_col = Color(1.0, 0.55, 0.0)   # orange for ranged
	else:
		border_col = Color(0.1, 0.1, 0.1, 0.8)
	var border_w: float = 3.0 if (is_sel or (terrain != Terrain.WATER and (cell in _move_cells \
			or cell in _attack_cells or cell in _ranged_attack_cells))) else 1.0
	for i in range(pts.size()):
		draw_line(pts[i], pts[(i + 1) % pts.size()], border_col, border_w)

	var label: String = TERRAIN_NAMES[terrain].substr(0, 1)
	var font: Font     = ThemeDB.fallback_font
	var fs            := 14
	var ts            := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	draw_string(font, center - ts * 0.5, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
			Color(0.0, 0.0, 0.0, 0.7))

# ── Tower ──────────────────────────────────────────────────────────────────────
func _draw_tower(tower: Tower, col: int, row: int) -> void:
	var center := hex_to_screen(col, row)
	var col_   : Color = TOWER_COLORS[tower.owner_id]
	var dark_  : Color = col_.darkened(0.35)
	var t      := 1.5

	var body := Rect2(center + Vector2(-11.0, -6.0), Vector2(22.0, 18.0))
	draw_rect(body, col_)
	draw_rect(body, dark_, false, t)

	var door := Rect2(center + Vector2(-4.0, 4.0), Vector2(8.0, 8.0))
	draw_rect(door, dark_)

	var merlon_y  := center.y - 13.0
	var merlon_xs: Array[float] = [center.x - 10.0, center.x - 2.5, center.x + 5.0]
	for mx: float in merlon_xs:
		var merlon := Rect2(Vector2(mx, merlon_y), Vector2(5.0, 7.0))
		draw_rect(merlon, col_)
		draw_rect(merlon, dark_, false, t)

	var font       := ThemeDB.fallback_font
	var fs         := 13
	var income_str: String = "+%d" % tower.income
	var ts         := font.get_string_size(income_str, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var lpos       := Vector2(center.x - ts.x * 0.5, center.y - 40.0)
	draw_rect(Rect2(lpos + Vector2(-2.0, -ts.y + 1.0), ts + Vector2(4.0, 3.0)),
			Color(0.0, 0.0, 0.0, 0.65))
	draw_string(font, lpos, income_str, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)

	# Capture pulse — brighten the tower body with owner colour
	if tower.visual_flash > 0.0:
		var flash_col := col_.lightened(0.6)
		flash_col.a   = tower.visual_flash * 0.80
		draw_rect(body, flash_col)

# ── Unit token ─────────────────────────────────────────────────────────────────
## Draws the unit using draw_set_transform for scale animation.
## All geometry is expressed relative to Vector2.ZERO (the transform origin).
func _draw_unit_token(unit: Unit) -> void:
	var u_scale: float       = unit.visual_scale
	var u_alpha: float       = unit.visual_alpha
	var u_flash: float       = unit.visual_flash
	var is_master_unit: bool = unit is Master

	# Position and scale via canvas transform (visual_pos is world; draw_set_transform needs local)
	draw_set_transform(to_local(unit.visual_pos), 0.0, Vector2(u_scale, u_scale))

	var h    := TOKEN_HALF
	var rect := Rect2(Vector2(-h, -h), Vector2(TOKEN_SIZE, TOKEN_SIZE))

	var exhausted: bool = unit.get_moves_left() == 0
	var base_col: Color = OWNER_COLORS[unit.owner_id]
	var fill_col: Color = base_col.darkened(0.45) if exhausted else base_col
	fill_col.a         *= u_alpha

	# Body fill — Master uses AnimatedSprite2D instead
	if not is_master_unit:
		draw_rect(rect, fill_col)

	# Border
	var border_col: Color = C_GOLD if is_master_unit else Color(0, 0, 0, 0.9)
	border_col.a         *= u_alpha
	var border_w: float   = 3.0 if is_master_unit else 2.0
	draw_rect(rect, border_col, false, border_w)

	# Symbol — Master sprite replaces the crown symbol; keep the crown marker above
	var sym_col: Color = Color(0.6, 0.6, 0.6, 0.85 * u_alpha) if exhausted \
		else Color(1, 1, 1, 0.95 * u_alpha)
	if is_master_unit:
		_draw_crown_marker(Vector2.ZERO, h, u_alpha)
	else:
		_draw_unit_symbol(unit.unit_type, Vector2.ZERO, sym_col)

	# HP bar
	var bar_y  := h - 6.0
	var bar_x0 := -h + 2.0
	var bar_w  := TOKEN_SIZE - 4.0
	var hp_pct := float(unit.hp) / float(unit.max_hp)
	draw_rect(Rect2(Vector2(bar_x0, bar_y), Vector2(bar_w, 5)),
			Color(0.2, 0.2, 0.2, u_alpha))
	var hp_col: Color = Color(0.1, 0.9, 0.1) if hp_pct > 0.5 \
		else (Color(0.9, 0.6, 0.1) if hp_pct > 0.25 else Color(0.9, 0.1, 0.1))
	hp_col.a *= u_alpha
	draw_rect(Rect2(Vector2(bar_x0, bar_y), Vector2(bar_w * hp_pct, 5)), hp_col)

	# Movement counter
	var font    := ThemeDB.fallback_font
	var mov_str := str(unit.get_moves_left())
	var fs      := 11
	var ts      := font.get_string_size(mov_str, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var mpos    := Vector2(h - ts.x - 2.0, -h + ts.y)
	draw_rect(Rect2(mpos + Vector2(-1, -ts.y + 1), ts + Vector2(2, 2)),
			Color(0, 0, 0, 0.6 * u_alpha))
	draw_string(font, mpos, mov_str, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
			Color(1, 1, 1, u_alpha))

	# Colour flash overlay (colour set by VFXManager.flash_unit)
	if u_flash > 0.0:
		var fc: Color = unit.visual_flash_color
		fc.a = u_flash * 0.80
		draw_rect(rect, fc)

	# Reset transform for the next draw call
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_unit_symbol(unit_type: int, center: Vector2, col: Color) -> void:
	var t := 2.0
	match unit_type:
		UnitScript.UnitType.WARRIOR:
			# Sword: upright blade + crossguard + pommel
			draw_line(center + Vector2(0, -12), center + Vector2(0, 4), col, t + 1.0)
			draw_line(center + Vector2(-8,  0), center + Vector2(8, 0), col, t)
			draw_circle(center + Vector2(0, 7), 2.5, col)
		UnitScript.UnitType.ARCHER:
			# Bow arc (3-segment curve) + bowstring + arrow pointing right
			draw_line(center + Vector2(-3, -12), center + Vector2(-9,  -4), col, t)
			draw_line(center + Vector2(-9,  -4), center + Vector2(-9,   4), col, t)
			draw_line(center + Vector2(-9,   4), center + Vector2(-3,  12), col, t)
			draw_line(center + Vector2(-3, -12), center + Vector2(-3,  12), col, 1.0)
			draw_line(center + Vector2(-3,   0), center + Vector2(11,   0), col, t)
			draw_line(center + Vector2(11,   0), center + Vector2( 7,  -4), col, t)
			draw_line(center + Vector2(11,   0), center + Vector2( 7,   4), col, t)
		UnitScript.UnitType.LANCER:
			# Lance: long diagonal shaft + spearhead + butt spike
			draw_line(center + Vector2(-11, 11), center + Vector2( 7, -11), col, t)
			draw_line(center + Vector2(  7, -11), center + Vector2(11,  -7), col, t)
			draw_line(center + Vector2(  7, -11), center + Vector2( 3,  -7), col, t)
			draw_circle(center + Vector2(-11, 11), 2.0, col)
		UnitScript.UnitType.RIDER:
			# Horse: body rectangle + neck + head circle + 4 legs
			draw_rect(Rect2(center + Vector2(-9, -3), Vector2(14, 7)), col, false, t)
			draw_line(center + Vector2( 3, -3), center + Vector2( 7,  -9), col, t)
			draw_circle(center + Vector2(8, -11), 3.0, col)
			draw_line(center + Vector2(-7, 4), center + Vector2(-8, 11), col, t)
			draw_line(center + Vector2(-3, 4), center + Vector2(-3, 11), col, t)
			draw_line(center + Vector2( 1, 4), center + Vector2( 1, 11), col, t)
			draw_line(center + Vector2( 5, 4), center + Vector2( 6, 11), col, t)

## Crown symbol drawn inside the Master's token.
func _draw_crown_symbol(center: Vector2, col: Color) -> void:
	var t: float = 2.0
	# Base bar
	draw_line(center + Vector2(-10, 5), center + Vector2(10, 5), col, t)
	# Left side
	draw_line(center + Vector2(-10, 5), center + Vector2(-10, -4), col, t)
	# Center prong (tallest)
	draw_line(center + Vector2(0, 5), center + Vector2(0, -8), col, t)
	# Right side
	draw_line(center + Vector2(10, 5), center + Vector2(10, -4), col, t)
	# Jewels at prong tips
	draw_circle(center + Vector2(-10, -5), 2.5, col)
	draw_circle(center + Vector2(0,   -9), 2.5, col)
	draw_circle(center + Vector2( 10, -5), 2.5, col)

## Small gold crown indicator drawn above the token rect.
func _draw_crown_marker(center: Vector2, h: float, alpha: float = 1.0) -> void:
	var cy: float   = center.y - h - 9.0
	var gold: Color = Color(0.95, 0.80, 0.20, 0.95 * alpha)
	# Three crown tips
	draw_circle(Vector2(center.x - 5.5, cy),       2.5, gold)
	draw_circle(Vector2(center.x,        cy - 4.0), 2.5, gold)
	draw_circle(Vector2(center.x + 5.5, cy),       2.5, gold)
	# Crown base bar
	draw_line(Vector2(center.x - 7.5, cy + 3.0),
			Vector2(center.x + 7.5, cy + 3.0), gold, 2.5)

# ─── Placement helpers ─────────────────────────────────────────────────────────
func _place_towers() -> void:
	var positions: Array
	var incomes: Array = []
	if GameData.map_tower_positions.size() > 0:
		positions = GameData.map_tower_positions
		incomes = GameData.map_tower_incomes
	else:
		positions = [
			Vector2i(4, 4),  Vector2i(4, 11),
			Vector2i(10, 6), Vector2i(12, 8), Vector2i(13, 11),
			Vector2i(19, 4), Vector2i(19, 11),
		]

	for i: int in range(positions.size()):
		var pos: Vector2i = positions[i]
		var tower         := TowerScript.new()
		tower.tower_name  = "Tower %d" % (i + 1)
		tower.owner_id    = 0
		tower.income      = int(incomes[i]) if i < incomes.size() else 2
		tower.position    = pos
		_towers[pos]      = tower
	print("[HexGrid] Towers placed at: %s" % str(positions))

func _place_masters() -> void:
	var p1_cell: Vector2i = GameData.map_master_p1
	var p2_cell: Vector2i = GameData.map_master_p2

	var m1 := MasterScript.new()
	m1.init_master(1)
	place_unit(m1, p1_cell.x, p1_cell.y)
	_create_master_sprite(m1)

	var m2 := MasterScript.new()
	m2.init_master(2)
	place_unit(m2, p2_cell.x, p2_cell.y)
	_create_master_sprite(m2)

	print("[HexGrid] Masters placed: J1 at %s | J2 at %s" % [str(p1_cell), str(p2_cell)])

func _create_master_sprite(master: Unit) -> void:
	var frames := SpriteFrames.new()
	frames.add_animation("idle")
	frames.set_animation_loop("idle", true)
	frames.set_animation_speed("idle", 8.0)
	var tex: Texture2D = load("res://assets/sprites/master.png")
	for i in range(8):
		var atlas := AtlasTexture.new()
		atlas.atlas  = tex
		atlas.region = Rect2(i * 32, 0, 32, 32)
		frames.add_frame("idle", atlas)

	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.scale         = Vector2(2.0, 2.0)   # 32px frame → 64px display
	sprite.modulate      = Color(1.2, 0.7, 0.7) if master.owner_id == 2 else Color.WHITE
	sprite.position      = to_local(master.visual_pos)   # visual_pos is world; sprite needs local
	sprite.play("idle")
	add_child(sprite)
	_master_sprites[master] = sprite

func _remove_master_sprite(master: Unit) -> void:
	if master in _master_sprites:
		_master_sprites[master].queue_free()
		_master_sprites.erase(master)

## Called from Main.gd to assign the unit cel-shader to all master sprites.
func apply_unit_shader(mat: ShaderMaterial) -> void:
	for sprite: AnimatedSprite2D in _master_sprites.values():
		sprite.material = mat
