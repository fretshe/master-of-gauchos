extends RefCounted

# ─── Terrain constants (match HexGrid.Terrain enum) ────────────────────────────
const GRASS    := 0
const WATER    := 1
const MOUNTAIN := 2
const FOREST   := 3
const DESERT   := 4
const VOLCANO  := 5
const CORDILLERA := 6

const NEIGHBORS_EVEN: Array = [
	Vector2i(1, -1), Vector2i(1, 0),
	Vector2i(0, 1), Vector2i(-1, 1),
	Vector2i(-1, 0), Vector2i(0, -1),
]
const NEIGHBORS_ODD: Array = [
	Vector2i(1, 0), Vector2i(1, 1),
	Vector2i(0, 1), Vector2i(-1, 1),
	Vector2i(-1, 0), Vector2i(0, -1),
]

# ─── State ──────────────────────────────────────────────────────────────────────
var COLS: int = 24
var ROWS: int = 16

var _seed:    int  = 0
var _map_type: String = "plains"
var _terrain: Array = []           # Array[Array[int]] — [row][col]
var _tower_positions: Array = []   # Array[Vector2i]
var _tower_incomes: Array = []     # Array[int]
var _protected_open_cells: Dictionary = {}
var _master_p1: Vector2i = Vector2i(2, 7)
var _master_p2: Vector2i = Vector2i(21, 8)
var _master_p3: Vector2i = Vector2i(2, 8)
var _master_p4: Vector2i = Vector2i(21, 7)

# ─── Public API ─────────────────────────────────────────────────────────────────
func generate(p_seed: int, map_type: String, map_size: Vector2i = Vector2i(24, 16)) -> void:
	_seed = p_seed
	_map_type = map_type
	COLS  = map_size.x
	ROWS  = map_size.y
	_terrain.clear()
	_tower_positions.clear()
	_tower_incomes.clear()
	_protected_open_cells.clear()

	match map_type:
		"plains":         _gen_plains()
		"sierras":        _gen_sierras()
		"precordillera":  _gen_precordillera()
		"mountains":      _gen_sierras()
		"volcanic":       _gen_precordillera()
		_:                _gen_plains()

	_ensure_small_map_mountains()
	_place_towers()
	_place_masters()
	_ensure_home_towers()
	_assign_tower_incomes()

func get_terrain() -> Array:
	return _terrain

func get_tower_positions() -> Array:
	return _tower_positions

func get_tower_incomes() -> Array:
	return _tower_incomes

func get_master_p1_cell() -> Vector2i:
	return _master_p1

func get_master_p2_cell() -> Vector2i:
	return _master_p2

func get_master_p3_cell() -> Vector2i:
	return _master_p3

func get_master_p4_cell() -> Vector2i:
	return _master_p4

func get_seed() -> int:
	return _seed

# ─── Noise heightmap ─────────────────────────────────────────────────────────────
## Returns a [0.0, 1.0] heightmap built from FastNoiseLite Simplex noise.
## Different seeds produce visually distinct maps.
func _gen_heightmap() -> Array:
	var noise := FastNoiseLite.new()
	noise.seed = _seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.15

	var grid: Array = []
	for r: int in range(ROWS):
		var row: Array = []
		for c: int in range(COLS):
			# get_noise_2d returns [-1, 1] — normalize to [0, 1]
			var v: float = (noise.get_noise_2d(float(c), float(r)) + 1.0) * 0.5
			row.append(v)
		grid.append(row)
	return grid

# ─── Map types ──────────────────────────────────────────────────────────────────
func _gen_plains() -> void:
	var h: Array = _gen_heightmap()
	for r: int in range(ROWS):
		var row: Array = []
		for c: int in range(COLS):
			var v: float = h[r][c]
			if v < 0.38:
				row.append(GRASS)
			elif v < 0.46:
				row.append(FOREST)
			elif v < 0.71:
				row.append(GRASS)
			elif v < 0.82:
				row.append(WATER)
			else:
				row.append(MOUNTAIN)
		_terrain.append(row)
	_ensure_variety([GRASS, FOREST, WATER])

func _gen_sierras() -> void:
	var h: Array = _gen_heightmap()
	for r: int in range(ROWS):
		var row: Array = []
		for c: int in range(COLS):
			var v: float = h[r][c]
			if v < 0.32:
				row.append(GRASS)
			elif v < 0.52:
				row.append(MOUNTAIN)
			elif v < 0.66:
				row.append(FOREST)
			elif v < 0.92:
				row.append(GRASS)
			else:
				row.append(WATER)
		_terrain.append(row)
	_soften_sierra_map()
	_ensure_variety([GRASS, MOUNTAIN, FOREST])

func _gen_precordillera() -> void:
	var h: Array = _gen_heightmap()
	var ridge_noise := FastNoiseLite.new()
	ridge_noise.seed = _seed ^ 0x3A71C0DE
	ridge_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	ridge_noise.frequency = 0.10
	var cordillera_noise := FastNoiseLite.new()
	cordillera_noise.seed = _seed ^ 0x4C0D1117
	cordillera_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	cordillera_noise.frequency = 0.18
	var east_ridge_noise := FastNoiseLite.new()
	east_ridge_noise.seed = _seed ^ 0x51EA57
	east_ridge_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	east_ridge_noise.frequency = 0.14
	var oasis_row: float = float(ROWS - 1) * 0.68
	var oasis_col: float = float(COLS - 1) * 0.56
	var oasis_radius_r: float = maxf(2.0, float(ROWS) * 0.16)
	var oasis_radius_c: float = maxf(2.0, float(COLS) * 0.11)
	for r: int in range(ROWS):
		var row: Array = []
		var ridge_bias: float = (ridge_noise.get_noise_2d(0.0, float(r)) + 1.0) * 0.5
		var west_core: int = int(round(float(COLS) * lerpf(0.16, 0.30, ridge_bias)))
		var precordillera_end: int = int(round(float(COLS) * lerpf(0.28, 0.42, ridge_bias)))
		for c: int in range(COLS):
			var v: float = h[r][c]
			var cord_noise: float = (cordillera_noise.get_noise_2d(float(c) * 0.9, float(r) * 0.9) + 1.0) * 0.5
			var east_noise: float = (east_ridge_noise.get_noise_2d(float(c), float(r)) + 1.0) * 0.5
			var ridge_distance: float = abs(float(c) - oasis_col) / oasis_radius_c + abs(float(r) - oasis_row) / oasis_radius_r
			var in_oasis: bool = ridge_distance < 1.0 and c > west_core + 1
			var eastern_sierra: bool = c > int(float(COLS) * 0.58) and c < int(float(COLS) * 0.90) and east_noise > 0.74 + (abs(float(r) - float(ROWS) * 0.55) / float(ROWS)) * 0.10
			var west_ratio: float = clampf(1.0 - (float(c) / maxf(1.0, float(COLS - 1))), 0.0, 1.0)
			var blended: float = clampf(v * 0.72 + west_ratio * 0.28, 0.0, 1.0)

			if c == 0:
				row.append(CORDILLERA)
			elif c <= west_core:
				var cordillera_cut: float = 0.84 + float(c) * 0.06
				if c <= 2 and cord_noise > cordillera_cut:
					row.append(CORDILLERA)
				elif c == 1 and cord_noise > 0.72:
					row.append(CORDILLERA)
				elif blended < 0.58:
					row.append(MOUNTAIN)
				elif blended < 0.76:
					row.append(FOREST)
				else:
					row.append(MOUNTAIN)
			elif c <= precordillera_end:
				if blended < 0.22:
					row.append(MOUNTAIN)
				elif blended < 0.36:
					row.append(FOREST)
				elif blended < 0.54:
					row.append(GRASS)
				elif blended < 0.78:
					row.append(DESERT)
				else:
					row.append(MOUNTAIN)
			elif in_oasis:
				if v < 0.20:
					row.append(WATER)
				elif v < 0.72:
					row.append(GRASS)
				else:
					row.append(FOREST)
			elif eastern_sierra:
				if blended < 0.70:
					row.append(MOUNTAIN)
				else:
					row.append(FOREST)
			else:
				if blended < 0.34:
					row.append(DESERT)
				elif blended < 0.52:
					row.append(GRASS)
				elif blended < 0.68:
					row.append(FOREST)
				elif blended < 0.72 and c > int(float(COLS) * 0.45):
					row.append(WATER)
				else:
					row.append(DESERT)
		_terrain.append(row)
	_soften_precordillera_map()
	_enforce_precordillera_ridge()
	_carve_cordillera_valleys()
	_rebalance_precordillera_distribution()
	_blend_precordillera_biomes()
	_ensure_variety([DESERT, MOUNTAIN, GRASS])

## Forces at least one cell of each required terrain type if it's missing after
## noise classification (rare edge case with extreme seeds).
func _ensure_variety(required: Array) -> void:
	var col_step: int = int(float(COLS) / float(required.size() + 1))
	var fallback_r: int = int(float(ROWS) / 2.0)
	for i: int in range(required.size()):
		var terrain_type: int = required[i]
		var found: bool = false
		for row: Array in _terrain:
			if row.has(terrain_type):
				found = true
				break
		if not found:
			var fallback_c: int = col_step * (i + 1)
			_terrain[fallback_r][fallback_c] = terrain_type

func _soften_sierra_map() -> void:
	var smoothed: Array = []
	for r: int in range(ROWS):
		var row: Array = []
		for c: int in range(COLS):
			var current: int = _terrain[r][c]
			var mountain_neighbors: int = _count_neighbors_of_type(c, r, MOUNTAIN)
			var grass_neighbors: int = _count_neighbors_of_type(c, r, GRASS)
			var forest_neighbors: int = _count_neighbors_of_type(c, r, FOREST)
			var water_neighbors: int = _count_neighbors_of_type(c, r, WATER)

			if current == MOUNTAIN and mountain_neighbors <= 1:
				row.append(GRASS)
			elif current == WATER and water_neighbors <= 1:
				row.append(GRASS)
			elif current == FOREST and mountain_neighbors >= 4 and grass_neighbors == 0:
				row.append(MOUNTAIN)
			elif current == GRASS and mountain_neighbors >= 5 and forest_neighbors >= 1:
				row.append(MOUNTAIN)
			else:
				row.append(current)
		smoothed.append(row)
	_terrain = smoothed

func _soften_precordillera_map() -> void:
	var smoothed: Array = []
	for r: int in range(ROWS):
		var row: Array = []
		for c: int in range(COLS):
			var current: int = _terrain[r][c]
			var mountain_neighbors: int = _count_neighbors_of_type(c, r, MOUNTAIN)
			var desert_neighbors: int = _count_neighbors_of_type(c, r, DESERT)
			var grass_neighbors: int = _count_neighbors_of_type(c, r, GRASS)
			var forest_neighbors: int = _count_neighbors_of_type(c, r, FOREST)
			var water_neighbors: int = _count_neighbors_of_type(c, r, WATER)

			if current == WATER and water_neighbors <= 1:
				row.append(DESERT)
			elif current == FOREST and desert_neighbors >= 4:
				row.append(GRASS)
			elif current == GRASS and mountain_neighbors >= 5:
				row.append(MOUNTAIN)
			elif current == DESERT and forest_neighbors >= 4 and grass_neighbors >= 2:
				row.append(GRASS)
			else:
				row.append(current)
		smoothed.append(row)
	_terrain = smoothed

func _enforce_precordillera_ridge() -> void:
	var ridge_noise := FastNoiseLite.new()
	ridge_noise.seed = _seed ^ 0x77AA114
	ridge_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	ridge_noise.frequency = 0.10
	var cordillera_noise := FastNoiseLite.new()
	cordillera_noise.seed = _seed ^ 0x4C0D1117
	cordillera_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	cordillera_noise.frequency = 0.18
	var east_ridge_noise := FastNoiseLite.new()
	east_ridge_noise.seed = _seed ^ 0x51EA57
	east_ridge_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	east_ridge_noise.frequency = 0.14
	for r: int in range(ROWS):
		var ridge_bias: float = (ridge_noise.get_noise_2d(0.0, float(r)) + 1.0) * 0.5
		var west_core: int = int(round(float(COLS) * lerpf(0.20, 0.32, ridge_bias)))
		var cordillera_front: int = _get_cordillera_front_for_row(r)
		for c: int in range(COLS):
			var cord_noise: float = (cordillera_noise.get_noise_2d(float(c) * 0.9, float(r) * 0.9) + 1.0) * 0.5
			var east_noise: float = (east_ridge_noise.get_noise_2d(float(c), float(r)) + 1.0) * 0.5
			if c == 0:
				_terrain[r][c] = CORDILLERA
			elif c <= west_core and _terrain[r][c] != WATER:
				_terrain[r][c] = CORDILLERA
			elif c <= cordillera_front and _terrain[r][c] != WATER:
				var front_ratio: float = clampf(float(c) / maxf(1.0, float(cordillera_front)), 0.0, 1.0)
				var cordillera_cut: float = lerpf(0.24, 0.72, front_ratio)
				if c <= west_core + 1 or cord_noise >= cordillera_cut:
					_terrain[r][c] = CORDILLERA
				else:
					_terrain[r][c] = MOUNTAIN
			elif c <= cordillera_front + 1 and _terrain[r][c] == WATER:
				_terrain[r][c] = GRASS
			elif c >= int(float(COLS) * 0.62) and c < int(float(COLS) * 0.90) and east_noise > 0.82:
				_terrain[r][c] = MOUNTAIN
			elif c >= int(float(COLS) * 0.78) and _terrain[r][c] == MOUNTAIN and east_noise < 0.70:
				_terrain[r][c] = DESERT
	_promote_precordillera_ascent()

func _get_cordillera_front_for_row(row: int) -> int:
	return _get_cordillera_band_limit()

func _get_cordillera_band_limit() -> int:
	return clampi(int(floor(float(COLS) * 0.70)), 2, COLS - 3)

func _get_mountain_band_limit() -> int:
	return clampi(int(floor(float(COLS) * 0.80)), _get_cordillera_band_limit() + 1, COLS - 2)

func _promote_precordillera_ascent() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed ^ 0x190C411A
	var promoted: Array = []
	for r: int in range(ROWS):
		var max_band: int = maxi(2, _get_cordillera_front_for_row(r) - 1)
		for c: int in range(1, mini(COLS - 1, max_band + 1)):
			var current: int = _terrain[r][c]
			if current == WATER or current == CORDILLERA or current == MOUNTAIN:
				continue
			var adjacent_relief: bool = false
			for neighbor: Vector2i in _get_hex_neighbors(Vector2i(c, r)):
				var neighbor_terrain: int = _terrain[neighbor.y][neighbor.x]
				if neighbor_terrain == CORDILLERA or neighbor_terrain == MOUNTAIN:
					adjacent_relief = true
					break
			if not adjacent_relief:
				continue
			if rng.randf() <= 0.90:
				promoted.append(Vector2i(c, r))
	for cell: Vector2i in promoted:
		_terrain[cell.y][cell.x] = MOUNTAIN

func _carve_cordillera_valleys() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed ^ 0x6A11E977
	var valley_count: int = clampi(int(round(float(ROWS) / 4.0)), 4, 7)
	var valleys: Array[Vector2i] = []
	var row_spacing: int = maxi(4, int(floor(float(ROWS) / float(valley_count + 1))))
	for i: int in range(valley_count):
		var target_row: int = clampi((i + 1) * row_spacing + rng.randi_range(-1, 1), 1, ROWS - 2)
		var front: int = _get_cordillera_band_limit()
		var min_x: int = 1
		var max_x: int = maxi(min_x + 1, int(round(float(front) * 0.72)))
		var attempts: int = 0
		var valley_center := Vector2i(rng.randi_range(min_x, max_x), target_row)
		while attempts < 10:
			var candidate := Vector2i(rng.randi_range(min_x, max_x), target_row)
			var too_close: bool = false
			for existing: Vector2i in valleys:
				if abs(existing.y - candidate.y) < row_spacing and abs(existing.x - candidate.x) < 6:
					too_close = true
					break
			if not too_close:
				valley_center = candidate
				break
			attempts += 1
		valleys.append(valley_center)
		_carve_valley_ellipse(
			valley_center,
			rng.randi_range(2, maxi(3, int(round(float(COLS) * 0.04)))),
			rng.randi_range(2, 3),
			rng
		)

	valleys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y
	)

	for i: int in range(valleys.size() - 1):
		# Keep inter-valley links as single-cell passes.
		_carve_corridor_between_valleys(valleys[i], valleys[i + 1], rng)

	for i: int in range(1, valleys.size()):
		var nearest_idx: int = -1
		var nearest_dist: int = 1 << 30
		for j: int in range(i):
			var dx: int = valleys[i].x - valleys[j].x
			var dy: int = valleys[i].y - valleys[j].y
			var dist: int = dx * dx + dy * dy
			if dist < nearest_dist:
				nearest_dist = dist
				nearest_idx = j
		if nearest_idx >= 0:
			_carve_corridor_between_valleys(valleys[i], valleys[nearest_idx], rng)

	for valley: Vector2i in valleys:
		var front: int = _get_cordillera_band_limit()
		if valley.x < int(round(float(front) * 0.55)):
			continue
		var exit_target := Vector2i(
			mini(COLS - 2, _get_mountain_band_limit() + rng.randi_range(0, 1)),
			clampi(valley.y + rng.randi_range(-1, 1), 1, ROWS - 2)
		)
		_carve_corridor_to_lowlands(valley, exit_target, rng)

func _carve_valley_ellipse(center: Vector2i, radius_x: int, radius_y: int, rng: RandomNumberGenerator) -> void:
	for r: int in range(maxi(1, center.y - radius_y - 1), mini(ROWS - 1, center.y + radius_y + 2)):
		for c: int in range(maxi(1, center.x - radius_x - 1), mini(COLS - 1, center.x + radius_x + 2)):
			var terrain_here: int = _terrain[r][c]
			if terrain_here != CORDILLERA:
				continue
			var dx: float = float(c - center.x) / maxf(1.0, float(radius_x))
			var dy: float = float(r - center.y) / maxf(1.0, float(radius_y))
			var cave_mask: float = dx * dx + dy * dy
			if cave_mask > 1.0:
				continue
			if cave_mask > 0.88 and rng.randf() < 0.18:
				continue
			_terrain[r][c] = GRASS if rng.randf() < 0.78 else FOREST
			_protected_open_cells[Vector2i(c, r)] = true

func _carve_corridor_between_valleys(from_cell: Vector2i, to_cell: Vector2i, rng: RandomNumberGenerator) -> void:
	var current: Vector2i = from_cell
	_carve_1x1_step(current, rng)
	var guard: int = COLS * ROWS
	while current != to_cell and guard > 0:
		guard -= 1
		var next_cell: Vector2i = current
		var step_x: int = signi(to_cell.x - current.x)
		var step_y: int = signi(to_cell.y - current.y)
		if current.x != to_cell.x:
			next_cell.x += step_x
		elif current.y != to_cell.y:
			next_cell.y += step_y
		if current.y != to_cell.y and rng.randf() < 0.35:
			next_cell.y = current.y + step_y
			if current.x != to_cell.x and rng.randf() < 0.45:
				next_cell.x = current.x
		next_cell.x = clampi(next_cell.x, 1, COLS - 2)
		next_cell.y = clampi(next_cell.y, 1, ROWS - 2)
		if next_cell == current:
			break
		current = next_cell
		_carve_1x1_step(current, rng)

func _carve_corridor_to_lowlands(from_cell: Vector2i, to_cell: Vector2i, rng: RandomNumberGenerator) -> void:
	var steps: int = maxi(absi(to_cell.x - from_cell.x), absi(to_cell.y - from_cell.y))
	if steps <= 0:
		_carve_2x2_step(from_cell, rng)
		return
	for i: int in range(steps + 1):
		var t: float = float(i) / float(steps)
		var c: int = int(round(lerpf(float(from_cell.x), float(to_cell.x), t)))
		var r: int = int(round(lerpf(float(from_cell.y), float(to_cell.y), t)))
		if i > 0 and i < steps:
			r = clampi(r + rng.randi_range(-1, 1), 1, ROWS - 2)
		_carve_2x2_step(Vector2i(c, r), rng)

func _carve_1x1_step(cell: Vector2i, rng: RandomNumberGenerator) -> void:
	if cell.x < 1 or cell.x >= COLS - 1 or cell.y < 1 or cell.y >= ROWS - 1:
		return
	_terrain[cell.y][cell.x] = GRASS if rng.randf() < 0.82 else FOREST
	_protected_open_cells[cell] = true

func _carve_2x2_step(cell: Vector2i, rng: RandomNumberGenerator) -> void:
	for dy: int in range(0, 2):
		for dx: int in range(0, 2):
			var c: int = cell.x + dx
			var r: int = cell.y + dy
			if c < 1 or c >= COLS - 1 or r < 1 or r >= ROWS - 1:
				continue
			_terrain[r][c] = GRASS if rng.randf() < 0.82 else FOREST
			_protected_open_cells[Vector2i(c, r)] = true

func _rebalance_precordillera_distribution() -> void:
	var cordillera_limit: int = _get_cordillera_band_limit()
	var mountain_limit: int = _get_mountain_band_limit()
	var lowland_noise := FastNoiseLite.new()
	lowland_noise.seed = _seed ^ 0x22B19A4
	lowland_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	lowland_noise.frequency = 0.14
	var blend_noise := FastNoiseLite.new()
	blend_noise.seed = _seed ^ 0x41A77C3
	blend_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	blend_noise.frequency = 0.09
	var cordillera_transition: int = maxi(4, int(round(float(COLS) * 0.14)))
	var mountain_transition: int = maxi(4, int(round(float(COLS) * 0.12)))

	for r: int in range(ROWS):
		for c: int in range(COLS):
			var cell := Vector2i(c, r)
			if _protected_open_cells.has(cell):
				continue
			var blend_value: float = (blend_noise.get_noise_2d(float(c), float(r)) + 1.0) * 0.5
			var lowland_value: float = (lowland_noise.get_noise_2d(float(c), float(r)) + 1.0) * 0.5
			var terrain_choice: int = -1
			if c <= cordillera_limit - cordillera_transition:
				terrain_choice = CORDILLERA
			elif c <= cordillera_limit + cordillera_transition:
				var t_cord_to_mountain: float = inverse_lerp(
					float(cordillera_limit - cordillera_transition),
					float(cordillera_limit + cordillera_transition),
					float(c)
				)
				var cordillera_strength: float = clampf(1.0 - t_cord_to_mountain + (blend_value - 0.5) * 0.75, 0.0, 1.0)
				if cordillera_strength >= 0.42:
					terrain_choice = CORDILLERA
				elif blend_value >= 0.72 and t_cord_to_mountain > 0.55:
					terrain_choice = _pick_lowland_terrain(lowland_value)
				else:
					terrain_choice = MOUNTAIN
			elif c <= mountain_limit - mountain_transition:
				if blend_value < 0.22:
					terrain_choice = CORDILLERA
				elif blend_value > 0.78 and c > cordillera_limit + 1:
					terrain_choice = _pick_lowland_terrain(lowland_value)
				else:
					terrain_choice = MOUNTAIN
			elif c <= mountain_limit + mountain_transition:
				var t_mountain_to_lowland: float = inverse_lerp(
					float(mountain_limit - mountain_transition),
					float(mountain_limit + mountain_transition),
					float(c)
				)
				var mountain_strength: float = clampf(1.0 - t_mountain_to_lowland + (blend_value - 0.5) * 0.70, 0.0, 1.0)
				if mountain_strength >= 0.44:
					terrain_choice = MOUNTAIN
				elif blend_value < 0.18 and c < mountain_limit:
					terrain_choice = CORDILLERA
				else:
					terrain_choice = _pick_lowland_terrain(lowland_value)
			else:
				if blend_value < 0.10 and c <= mountain_limit + 1:
					terrain_choice = MOUNTAIN
				else:
					terrain_choice = _pick_lowland_terrain(lowland_value)

			if terrain_choice == -1:
				terrain_choice = CORDILLERA

			if c <= cordillera_limit:
				if terrain_choice != CORDILLERA and blend_value < 0.04:
					terrain_choice = CORDILLERA
			elif c <= mountain_limit:
				if terrain_choice != MOUNTAIN and blend_value < 0.03:
					terrain_choice = MOUNTAIN
			_terrain[r][c] = terrain_choice

func _pick_lowland_terrain(lowland_value: float) -> int:
	if lowland_value < 0.18:
		return DESERT
	if lowland_value < 0.48:
		return GRASS
	if lowland_value < 0.74:
		return FOREST
	if lowland_value < 0.82:
		return WATER
	return GRASS

func _blend_precordillera_biomes() -> void:
	var blend_noise := FastNoiseLite.new()
	blend_noise.seed = _seed ^ 0x5EED123
	blend_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	blend_noise.frequency = 0.16
	var updates: Dictionary = {}

	for r: int in range(1, ROWS - 1):
		for c: int in range(1, COLS - 1):
			var cell := Vector2i(c, r)
			if _protected_open_cells.has(cell):
				continue
			var current: int = _terrain[r][c]
			var has_cordillera_neighbor: bool = false
			var has_mountain_neighbor: bool = false
			var has_lowland_neighbor: bool = false
			for neighbor: Vector2i in _get_hex_neighbors(cell):
				var neighbor_terrain: int = _terrain[neighbor.y][neighbor.x]
				if neighbor_terrain == CORDILLERA:
					has_cordillera_neighbor = true
				elif neighbor_terrain == MOUNTAIN:
					has_mountain_neighbor = true
				else:
					has_lowland_neighbor = true

			var blend_value: float = (blend_noise.get_noise_2d(float(c), float(r)) + 1.0) * 0.5
			if current == CORDILLERA and has_mountain_neighbor and blend_value > 0.42:
				updates[cell] = MOUNTAIN
			elif current == MOUNTAIN:
				if has_cordillera_neighbor and has_lowland_neighbor:
					if blend_value < 0.30:
						updates[cell] = CORDILLERA
					elif blend_value > 0.72:
						updates[cell] = GRASS
				elif has_cordillera_neighbor and blend_value < 0.22:
					updates[cell] = CORDILLERA
				elif has_lowland_neighbor and blend_value > 0.78:
					updates[cell] = FOREST if ((c + r + _seed) % 2 == 0) else GRASS
			elif has_mountain_neighbor and (current == GRASS or current == FOREST or current == DESERT):
				if blend_value < 0.24:
					updates[cell] = MOUNTAIN

	for cell_value: Variant in updates.keys():
		var cell: Vector2i = cell_value as Vector2i
		_terrain[cell.y][cell.x] = int(updates[cell])

func _count_neighbors_of_type(col: int, row: int, terrain_type: int) -> int:
	var count: int = 0
	for dr: int in range(-1, 2):
		for dc: int in range(-1, 2):
			if dc == 0 and dr == 0:
				continue
			var nc: int = col + dc
			var nr: int = row + dr
			if nc < 0 or nc >= COLS or nr < 0 or nr >= ROWS:
				continue
			if _terrain[nr][nc] == terrain_type:
				count += 1
	return count

func _ensure_small_map_mountains() -> void:
	if COLS > 12:
		return

	var mountain_count: int = 0
	for row: Array in _terrain:
		for terrain_type: Variant in row:
			if int(terrain_type) == MOUNTAIN:
				mountain_count += 1

	var required_mountains: int = 2
	if mountain_count >= required_mountains:
		return

	var candidates: Array[Vector2i] = []
	var center: Vector2 = Vector2((COLS - 1) * 0.5, (ROWS - 1) * 0.5)
	for r: int in range(1, ROWS - 1):
		for c: int in range(1, COLS - 1):
			if _terrain[r][c] == WATER or _terrain[r][c] == VOLCANO or _terrain[r][c] == CORDILLERA:
				continue
			candidates.append(Vector2i(c, r))

	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da: float = Vector2(a.x, a.y).distance_squared_to(center)
		var db: float = Vector2(b.x, b.y).distance_squared_to(center)
		return da < db
	)

	for cell: Vector2i in candidates:
		if mountain_count >= required_mountains:
			break
		if _terrain[cell.y][cell.x] == MOUNTAIN:
			continue
		_terrain[cell.y][cell.x] = MOUNTAIN
		mountain_count += 1

# ─── Placement ──────────────────────────────────────────────────────────────────
func _place_towers() -> void:
	if _map_type == "precordillera" or _map_type == "volcanic":
		_place_towers_precordillera()
		return

	# Count, min spacing, and home towers per player corner
	var count: int
	var min_dist: int
	var home_per_player: int
	if COLS <= 12:
		count = 14; min_dist = 2; home_per_player = 1
	elif COLS <= 24:
		count = 28; min_dist = 3; home_per_player = 2
	elif COLS <= 36:
		count = 40; min_dist = 3; home_per_player = 2
	else:
		count = 56; min_dist = 4; home_per_player = 3

	var rng := RandomNumberGenerator.new()
	rng.seed = _seed ^ 0xF00D1234

	# Home zone radius around each corner anchor
	var hr_c: int = maxi(2, COLS / 5)
	var hr_r: int = maxi(2, ROWS / 4)
	var corners: Array = [
		Vector2i(2,       2),
		Vector2i(COLS-3,  2),
		Vector2i(2,       ROWS-3),
		Vector2i(COLS-3,  ROWS-3),
	]

	# Classify walkable interior cells: one pool per corner + center pool
	var home_pools: Array = [[], [], [], []]
	var center_pool: Array = []
	for r: int in range(1, ROWS - 1):
		for c: int in range(1, COLS - 1):
			if _terrain[r][c] == WATER or _terrain[r][c] == CORDILLERA:
				continue
			var cell := Vector2i(c, r)
			var in_home := false
			for i: int in range(corners.size()):
				var corner: Vector2i = corners[i]
				if absi(c - corner.x) <= hr_c and absi(r - corner.y) <= hr_r:
					home_pools[i].append(cell)
					in_home = true
					break
			if not in_home:
				center_pool.append(cell)

	_tower_positions.clear()
	var min_dist_sq: int = min_dist * min_dist

	# Phase 1: home_per_player towers near each player's starting corner
	for i: int in range(corners.size()):
		_shuffle(home_pools[i], rng)
		_greedy_place(home_pools[i], home_per_player, min_dist_sq)

	# Phase 2: remaining towers in the contested center
	_shuffle(center_pool, rng)
	_greedy_place(center_pool, count - _tower_positions.size(), min_dist_sq)

	# Phase 3: fallback with relaxed spacing if still short (rare)
	if _tower_positions.size() < count:
		var relax_sq: int = maxi(1, (min_dist - 1) * (min_dist - 1))
		var fallback_pool: Array = []
		for pool: Array in home_pools:
			fallback_pool.append_array(pool)
		fallback_pool.append_array(center_pool)
		_shuffle(fallback_pool, rng)
		_greedy_place(fallback_pool, count - _tower_positions.size(), relax_sq)

func _place_towers_precordillera() -> void:
	var count: int
	var min_dist: int
	if COLS <= 12:
		count = 14; min_dist = 2
	elif COLS <= 24:
		count = 28; min_dist = 3
	elif COLS <= 36:
		count = 40; min_dist = 3
	else:
		count = 56; min_dist = 4

	var rng := RandomNumberGenerator.new()
	rng.seed = _seed ^ 0x51E772A
	var min_dist_sq: int = min_dist * min_dist
	var west_mountain_limit: int = maxi(3, int(round(float(COLS) * 0.36)))
	var left_half_limit: int = maxi(west_mountain_limit + 1, int(floor(float(COLS - 1) * 0.5)))
	var east_lowland_start: int = mini(COLS - 3, maxi(west_mountain_limit + 2, int(round(float(COLS) * 0.64))))
	var west_foothill_limit: int = mini(left_half_limit, east_lowland_start - 1)
	var reserved_home_towers: int = 4
	var target_generated_towers: int = maxi(0, count - reserved_home_towers)
	var max_right_side_total: int = int(floor(float(count) * 0.20))
	var max_right_generated_towers: int = maxi(0, max_right_side_total - reserved_home_towers)

	var mountain_pool: Array = []
	var west_foothill_pool: Array = []
	var east_foothill_pool: Array = []
	var fallback_left_pool: Array = []
	var fallback_right_pool: Array = []

	for r: int in range(1, ROWS - 1):
		for c: int in range(1, COLS - 1):
			if _terrain[r][c] == WATER or _terrain[r][c] == CORDILLERA:
				continue
			var cell := Vector2i(c, r)
			if c <= left_half_limit:
				fallback_left_pool.append(cell)
			else:
				fallback_right_pool.append(cell)
			if c <= west_mountain_limit and (_terrain[r][c] == MOUNTAIN or _terrain[r][c] == CORDILLERA):
				mountain_pool.append(cell)
			elif c <= west_foothill_limit:
				west_foothill_pool.append(cell)
			elif c < east_lowland_start:
				east_foothill_pool.append(cell)

	_tower_positions.clear()

	var target_mountain_towers: int = mini(target_generated_towers, int(round(float(target_generated_towers) * 0.70)))
	_shuffle(mountain_pool, rng)
	_greedy_place(mountain_pool, target_mountain_towers, min_dist_sq)

	var target_west_foothill_towers: int = target_generated_towers - _tower_positions.size()
	_shuffle(west_foothill_pool, rng)
	_greedy_place(west_foothill_pool, target_west_foothill_towers, min_dist_sq)

	if max_right_generated_towers > 0 and _tower_positions.size() < target_generated_towers:
		_shuffle(east_foothill_pool, rng)
		_greedy_place(
			east_foothill_pool,
			mini(target_generated_towers - _tower_positions.size(), max_right_generated_towers),
			min_dist_sq
		)

	if _tower_positions.size() < target_generated_towers:
		var relax_sq: int = maxi(1, (min_dist - 1) * (min_dist - 1))
		_shuffle(fallback_left_pool, rng)
		_greedy_place(fallback_left_pool, target_generated_towers - _tower_positions.size(), relax_sq)
		if max_right_generated_towers > 0 and _tower_positions.size() < target_generated_towers:
			_shuffle(fallback_right_pool, rng)
			_greedy_place(
				fallback_right_pool,
				mini(target_generated_towers - _tower_positions.size(), max_right_generated_towers),
				relax_sq
			)

func _assign_tower_incomes() -> void:
	_tower_incomes.clear()
	var total_towers: int = _tower_positions.size()
	if total_towers <= 0:
		return

	var six_count: int = maxi(1, int(round(float(total_towers) / 14.0)))
	var four_count: int = int(round(float(total_towers) * 3.0 / 14.0))
	if total_towers >= 4:
		four_count = maxi(1, four_count)
	four_count = mini(four_count, maxi(0, total_towers - six_count))
	var two_count: int = maxi(0, total_towers - four_count - six_count)

	for _i: int in range(two_count):
		_tower_incomes.append(2)
	for _i: int in range(four_count):
		_tower_incomes.append(4)
	for _i: int in range(six_count):
		_tower_incomes.append(6)

	var rng := RandomNumberGenerator.new()
	rng.seed = _seed ^ 0x70AEE123
	_shuffle(_tower_incomes, rng)

func _place_masters() -> void:
	if _map_type == "precordillera" or _map_type == "volcanic":
		_place_masters_precordillera()
		return

	if COLS <= 12:
		_master_p1 = _find_grass_near(2,  2);  _master_p2 = _find_grass_near(9,  2)
		_master_p3 = _find_grass_near(2,  5);  _master_p4 = _find_grass_near(9,  5)
	elif COLS <= 24:
		_master_p1 = _find_grass_near(2,  2);  _master_p2 = _find_grass_near(21, 2)
		_master_p3 = _find_grass_near(2, 13);  _master_p4 = _find_grass_near(21,13)
	elif COLS <= 36:
		_master_p1 = _find_grass_near(3,  3);  _master_p2 = _find_grass_near(32, 3)
		_master_p3 = _find_grass_near(3, 20);  _master_p4 = _find_grass_near(32,20)
	else:
		_master_p1 = _find_grass_near(4,  4);  _master_p2 = _find_grass_near(43, 4)
		_master_p3 = _find_grass_near(4, 27);  _master_p4 = _find_grass_near(43,27)

func _place_masters_precordillera() -> void:
	var right_a: int = COLS - 3
	var right_b: int = mini(COLS - 3, maxi(2, int(round(float(COLS) * 0.82))))
	if COLS <= 12:
		_master_p1 = _find_lowland_near(right_a, 1)
		_master_p2 = _find_lowland_near(right_a, ROWS - 2)
		_master_p3 = _find_lowland_near(right_b, maxi(1, ROWS / 3))
		_master_p4 = _find_lowland_near(right_b, mini(ROWS - 2, (ROWS * 2) / 3))
	elif COLS <= 24:
		_master_p1 = _find_lowland_near(right_a, 2)
		_master_p2 = _find_lowland_near(right_a, ROWS - 3)
		_master_p3 = _find_lowland_near(right_b, maxi(2, ROWS / 3))
		_master_p4 = _find_lowland_near(right_b, mini(ROWS - 3, (ROWS * 2) / 3))
	elif COLS <= 36:
		_master_p1 = _find_lowland_near(right_a, 3)
		_master_p2 = _find_lowland_near(right_a, ROWS - 4)
		_master_p3 = _find_lowland_near(right_b, maxi(3, ROWS / 3))
		_master_p4 = _find_lowland_near(right_b, mini(ROWS - 4, (ROWS * 2) / 3))
	else:
		_master_p1 = _find_lowland_near(right_a, 4)
		_master_p2 = _find_lowland_near(right_a, ROWS - 5)
		_master_p3 = _find_lowland_near(right_b, maxi(4, ROWS / 3))
		_master_p4 = _find_lowland_near(right_b, mini(ROWS - 5, (ROWS * 2) / 3))

func _ensure_home_towers() -> void:
	var masters: Array[Vector2i] = [_master_p1, _master_p2, _master_p3, _master_p4]
	for master_cell: Vector2i in masters:
		if master_cell == Vector2i(-1, -1):
			continue
		if _has_adjacent_tower(master_cell):
			continue
		var tower_cell: Vector2i = _find_adjacent_tower_cell(master_cell)
		if tower_cell != Vector2i(-1, -1) and not _tower_positions.has(tower_cell):
			_tower_positions.append(tower_cell)

func _has_adjacent_tower(master_cell: Vector2i) -> bool:
	for neighbor: Vector2i in _get_hex_neighbors(master_cell):
		if _tower_positions.has(neighbor):
			return true
	return false

func _find_adjacent_tower_cell(master_cell: Vector2i) -> Vector2i:
	for neighbor: Vector2i in _get_hex_neighbors(master_cell):
		if _is_valid_home_tower_cell(neighbor):
			return neighbor
	return _find_walkable_near(master_cell.x, master_cell.y)

func _get_hex_neighbors(cell: Vector2i) -> Array[Vector2i]:
	var offsets: Array = NEIGHBORS_ODD if cell.x % 2 == 1 else NEIGHBORS_EVEN
	var result: Array[Vector2i] = []
	for offset: Vector2i in offsets:
		var nc: int = cell.x + offset.x
		var nr: int = cell.y + offset.y
		if nc < 0 or nc >= COLS or nr < 0 or nr >= ROWS:
			continue
		result.append(Vector2i(nc, nr))
	return result

func _is_valid_home_tower_cell(cell: Vector2i) -> bool:
	if cell == Vector2i(-1, -1):
		return false
	if _tower_positions.has(cell):
		return false
	if cell == _master_p1 or cell == _master_p2 or cell == _master_p3 or cell == _master_p4:
		return false
	var terrain_type: int = _terrain[cell.y][cell.x]
	return terrain_type != WATER and terrain_type != CORDILLERA

# ─── Helpers ────────────────────────────────────────────────────────────────────
func _find_grass_near(tc: int, transform_val: int) -> Vector2i:
	for radius: int in range(10):
		for dc: int in range(-radius, radius + 1):
			for dr: int in range(-radius, radius + 1):
				if maxi(absi(dc), absi(dr)) != radius:
					continue
				var c: int = tc + dc
				var r: int = transform_val + dr
				if c < 0 or c >= COLS or r < 0 or r >= ROWS:
					continue
				if Vector2i(c, r) in _tower_positions:
					continue
				if _terrain[r][c] == GRASS:
					return Vector2i(c, r)
	var fallback := Vector2i(clampi(tc, 0, COLS - 1), clampi(transform_val, 0, ROWS - 1))
	if fallback in _tower_positions:
		return _find_walkable_near(tc, transform_val)
	return fallback

func _find_lowland_near(tc: int, transform_val: int) -> Vector2i:
	for radius: int in range(12):
		for dc: int in range(-radius, radius + 1):
			for dr: int in range(-radius, radius + 1):
				if maxi(absi(dc), absi(dr)) != radius:
					continue
				var c: int = tc + dc
				var r: int = transform_val + dr
				if c < 0 or c >= COLS or r < 0 or r >= ROWS:
					continue
				if Vector2i(c, r) in _tower_positions:
					continue
				var terrain_type: int = _terrain[r][c]
				if terrain_type == GRASS or terrain_type == DESERT or terrain_type == FOREST:
					return Vector2i(c, r)
	return _find_walkable_near(tc, transform_val)

## Fisher-Yates in-place shuffle using the map's seeded RNG.
func _shuffle(pool: Array, rng: RandomNumberGenerator) -> void:
	for i: int in range(pool.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Variant = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp

## Greedy placement: adds up to `n` candidates from `pool` to `_tower_positions`
## keeping each new tower at least sqrt(min_dist_sq) cells away from existing ones.
func _greedy_place(pool: Array, n: int, min_dist_sq: int) -> void:
	var added: int = 0
	for cand: Variant in pool:
		if added >= n:
			break
		if _tower_positions.has(cand):
			continue
		var too_close := false
		for placed: Variant in _tower_positions:
			var p := placed as Vector2i
			var cv := cand as Vector2i
			var dx: int = cv.x - p.x
			var dy: int = cv.y - p.y
			if dx * dx + dy * dy < min_dist_sq:
				too_close = true
				break
		if not too_close:
			_tower_positions.append(cand)
			added += 1

func _find_walkable_near(tc: int, transform_val: int) -> Vector2i:
	for radius: int in range(10):
		for dc: int in range(-radius, radius + 1):
			for dr: int in range(-radius, radius + 1):
				if maxi(absi(dc), absi(dr)) != radius:
					continue
				var c: int = tc + dc
				var r: int = transform_val + dr
				if c < 0 or c >= COLS or r < 0 or r >= ROWS:
					continue
				if Vector2i(c, r) in _tower_positions:
					continue
				if _terrain[r][c] != WATER and _terrain[r][c] != CORDILLERA:
					return Vector2i(c, r)
	return Vector2i(clampi(tc, 0, COLS - 1), clampi(transform_val, 0, ROWS - 1))
