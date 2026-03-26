extends RefCounted

# ─── Terrain constants (match HexGrid.Terrain enum) ────────────────────────────
const GRASS    := 0
const WATER    := 1
const MOUNTAIN := 2
const FOREST   := 3
const DESERT   := 4
const VOLCANO  := 5

# ─── State ──────────────────────────────────────────────────────────────────────
var COLS: int = 24
var ROWS: int = 16

var _seed:    int  = 0
var _terrain: Array = []           # Array[Array[int]] — [row][col]
var _tower_positions: Array = []   # Array[Vector2i]
var _master_p1: Vector2i = Vector2i(2, 7)
var _master_p2: Vector2i = Vector2i(21, 8)
var _master_p3: Vector2i = Vector2i(2, 8)
var _master_p4: Vector2i = Vector2i(21, 7)

# ─── Public API ─────────────────────────────────────────────────────────────────
func generate(p_seed: int, map_type: String, map_size: Vector2i = Vector2i(24, 16)) -> void:
	_seed = p_seed
	COLS  = map_size.x
	ROWS  = map_size.y
	_terrain.clear()
	_tower_positions.clear()

	match map_type:
		"plains":    _gen_plains()
		"mountains": _gen_mountains()
		"volcanic":  _gen_volcanic()
		_:           _gen_plains()

	_place_towers()
	_place_masters()

func get_terrain() -> Array:
	return _terrain

func get_tower_positions() -> Array:
	return _tower_positions

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
			if v < 0.3:
				row.append(GRASS)
			elif v < 0.5:
				row.append(FOREST)
			elif v < 0.7:
				row.append(GRASS)
			elif v < 0.85:
				row.append(WATER)
			else:
				row.append(MOUNTAIN)
		_terrain.append(row)
	_ensure_variety([GRASS, FOREST, WATER])

func _gen_mountains() -> void:
	var h: Array = _gen_heightmap()
	for r: int in range(ROWS):
		var row: Array = []
		for c: int in range(COLS):
			var v: float = h[r][c]
			if v < 0.2:
				row.append(GRASS)
			elif v < 0.75:
				row.append(MOUNTAIN)
			elif v < 0.9:
				row.append(FOREST)
			else:
				row.append(GRASS)
		_terrain.append(row)
	_ensure_variety([GRASS, MOUNTAIN, FOREST])

func _gen_volcanic() -> void:
	var h: Array = _gen_heightmap()
	for r: int in range(ROWS):
		var row: Array = []
		for c: int in range(COLS):
			var v: float = h[r][c]
			if v < 0.25:
				row.append(VOLCANO)
			elif v < 0.5:
				row.append(DESERT)
			elif v < 0.7:
				row.append(MOUNTAIN)
			elif v < 0.85:
				row.append(DESERT)
			else:
				row.append(GRASS)
		_terrain.append(row)
	_ensure_variety([VOLCANO, DESERT, MOUNTAIN])

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

# ─── Placement ──────────────────────────────────────────────────────────────────
func _place_towers() -> void:
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
			if _terrain[r][c] == WATER:
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

func _place_masters() -> void:
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
				if _terrain[r][c] == GRASS:
					return Vector2i(c, r)
	return Vector2i(clampi(tc, 0, COLS - 1), clampi(transform_val, 0, ROWS - 1))

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
				if _terrain[r][c] != WATER:
					return Vector2i(c, r)
	return Vector2i(clampi(tc, 0, COLS - 1), clampi(transform_val, 0, ROWS - 1))
