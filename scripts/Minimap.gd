extends Control

# ─── External references (set by Main.gd) ───────────────────────────────────────
var hex_grid:    Node      = null
var camera_node: Camera2D  = null

# ─── Layout constants ────────────────────────────────────────────────────────────
const MM_W:    float = 220.0
const MM_H:    float = 160.0
const MM_PAD:  float = 10.0   # margin from screen edge
const BORDER:  float = 7.0    # inner padding inside the bg rect

# ─── Colours ─────────────────────────────────────────────────────────────────────
const C_BG         := Color(0.04, 0.04, 0.08, 0.85)
const C_FRAME      := Color(0.40, 0.40, 0.55, 0.90)
const C_MAP_BASE   := Color(0.10, 0.22, 0.10, 1.00)
const C_WATER      := Color(0.20, 0.45, 0.80, 1.00)
const C_MOUNTAIN   := Color(0.50, 0.50, 0.50, 1.00)
const C_FOREST     := Color(0.10, 0.38, 0.10, 1.00)
const C_DESERT     := Color(0.78, 0.72, 0.38, 1.00)
const C_VOLCANO    := Color(0.60, 0.14, 0.04, 1.00)
const C_CORDILLERA := Color(0.20, 0.22, 0.26, 1.00)
const C_TOWER_NEU  := Color(0.70, 0.70, 0.70, 1.00)
const C_P1         := Color(0.15, 0.40, 0.85, 1.00)
const C_P2         := Color(0.85, 0.18, 0.18, 1.00)
const C_VIEWPORT   := Color(1.00, 1.00, 1.00, 0.85)

# Terrain index → minimap colour (matches HexGrid.Terrain enum order)
const TERRAIN_MM_COLORS: Array = [
	Color(0.27, 0.58, 0.25),   # GRASS
	Color(0.20, 0.45, 0.80),   # WATER
	Color(0.50, 0.50, 0.50),   # MOUNTAIN
	Color(0.10, 0.38, 0.10),   # FOREST
	Color(0.78, 0.72, 0.38),   # DESERT
	Color(0.60, 0.14, 0.04),   # VOLCANO
	Color(0.20, 0.22, 0.26),   # CORDILLERA
]

# ─── Godot callbacks ──────────────────────────────────────────────────────────────
func _ready() -> void:
	mouse_filter  = Control.MOUSE_FILTER_IGNORE
	anchor_right  = 1.0
	anchor_bottom = 1.0

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if hex_grid == null:
		return

	var vp: Vector2     = get_viewport_rect().size
	var origin: Vector2 = Vector2(vp.x - MM_W - MM_PAD, vp.y - MM_H - MM_PAD)

	# ── Background & frame ──────────────────────────────────────────────────────
	draw_rect(Rect2(origin, Vector2(MM_W, MM_H)), C_BG)
	draw_rect(Rect2(origin, Vector2(MM_W, MM_H)), C_FRAME, false, 1.5)

	# ── Inner drawing area ──────────────────────────────────────────────────────
	var inner_origin: Vector2 = origin + Vector2(BORDER, BORDER)
	var inner_size:   Vector2 = Vector2(MM_W - BORDER * 2.0, MM_H - BORDER * 2.0)

	# Clip conceptually — we just draw within this area
	draw_rect(Rect2(inner_origin, inner_size), C_MAP_BASE)

	# ── World extents (used for coordinate mapping) ─────────────────────────────
	var world_min: Vector2 = hex_grid.hex_to_screen(0, 0)
	var world_max: Vector2 = hex_grid.hex_to_screen(hex_grid.COLS - 1, hex_grid.ROWS - 1)
	var world_size: Vector2 = world_max - world_min + Vector2(hex_grid.HEX_SIZE, hex_grid.HEX_SIZE)

	# ── Terrain cells (tiny rects) ──────────────────────────────────────────────
	var cell_w: float = inner_size.x / float(hex_grid.COLS)
	var cell_h: float = inner_size.y / float(hex_grid.ROWS)
	var terrain: Array = hex_grid.get_terrain_data()
	for r: int in range(hex_grid.ROWS):
		for c: int in range(hex_grid.COLS):
			var t: int = terrain[r][c]
			if t == 0:
				continue  # skip grass (already the base colour)
			var tc: Color = TERRAIN_MM_COLORS[t] if t < TERRAIN_MM_COLORS.size() \
					else C_MAP_BASE
			var rx: float = inner_origin.x + float(c) * cell_w
			var ry: float = inner_origin.y + float(r) * cell_h
			draw_rect(Rect2(Vector2(rx, ry), Vector2(cell_w + 0.5, cell_h + 0.5)), tc)

	# ── Towers ─────────────────────────────────────────────────────────────────
	for cell: Vector2i in hex_grid.get_all_tower_cells():
		var tower: Tower  = hex_grid.get_tower_at(cell.x, cell.y)
		var wpos: Vector2 = hex_grid.hex_to_screen(cell.x, cell.y)
		var mpos: Vector2 = _w2m(wpos, world_min, world_size, inner_origin, inner_size)
		var tc: Color     = C_TOWER_NEU
		if tower.owner_id == 1:
			tc = C_P1
		elif tower.owner_id == 2:
			tc = C_P2
		draw_rect(Rect2(mpos - Vector2(3.0, 3.0), Vector2(6.0, 6.0)), tc)
		draw_rect(Rect2(mpos - Vector2(3.0, 3.0), Vector2(6.0, 6.0)), Color.WHITE, false, 0.8)

	# ── Units ───────────────────────────────────────────────────────────────────
	for unit: Unit in hex_grid.get_all_units():
		var wpos: Vector2 = unit.visual_pos
		var mpos: Vector2 = _w2m(wpos, world_min, world_size, inner_origin, inner_size)
		var uc: Color     = C_P1 if unit.owner_id == 1 else C_P2
		draw_circle(mpos, 3.5, uc)
		draw_circle(mpos, 3.5, Color.WHITE, false, 0.8)

	# ── Viewport indicator ──────────────────────────────────────────────────────
	if camera_node != null:
		var vp_world: Vector2 = get_viewport_rect().size / camera_node.zoom
		var cam_min: Vector2  = camera_node.position - vp_world * 0.5
		var cam_max: Vector2  = camera_node.position + vp_world * 0.5
		var r_min: Vector2    = _w2m(cam_min, world_min, world_size, inner_origin, inner_size)
		var r_max: Vector2    = _w2m(cam_max, world_min, world_size, inner_origin, inner_size)
		var r_sz: Vector2     = r_max - r_min
		draw_rect(Rect2(r_min, r_sz), Color(1, 1, 1, 0.12))
		draw_rect(Rect2(r_min, r_sz), C_VIEWPORT, false, 1.2)

	# ── Label ───────────────────────────────────────────────────────────────────
	var font: Font = ThemeDB.fallback_font
	draw_string(font, origin + Vector2(BORDER, MM_H - 3.0), "MAPA",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.6, 0.6, 0.7, 0.8))

# ─── Helper ───────────────────────────────────────────────────────────────────────
## Maps a world position to minimap pixel coordinates.
func _w2m(wpos: Vector2, wmin: Vector2, wsize: Vector2,
		morigin: Vector2, msize: Vector2) -> Vector2:
	var t: Vector2 = (wpos - wmin) / wsize
	return morigin + t * msize
