extends Control

const MapGeneratorScript := preload("res://scripts/MapGenerator.gd")

# ─── Map type data ────────────────────────────────────────────────────────────
const MAP_TYPES:  Array[String] = ["plains", "sierras", "precordillera"]
const MAP_NAMES:  Array[String] = ["Llanuras", "Sierras", "Precordillera"]
const MAP_DESCS:  Array[String] = [
	"Campos abiertos\ny monte disperso.\nIdeal para comenzar.",
	"Lomas, pasos\ny altura disputada.\nMovilidad con tension.",
	"Suelo arido,\nsierras secas y cauces.\nInspirado en San Juan.",
]
const MAP_ACCENT: Array[Color] = [
	Color(0.22, 0.82, 0.34),
	Color(0.66, 0.72, 0.78),
	Color(0.92, 0.72, 0.34),
]
const MAP_BG_COL: Array[Color] = [
	Color(0.05, 0.16, 0.06, 0.95),
	Color(0.10, 0.11, 0.14, 0.95),
	Color(0.20, 0.14, 0.06, 0.95),
]

# ─── Map size data ────────────────────────────────────────────────────────────
const SIZE_NAMES:  Array[String]   = ["Pequeño", "Mediano", "Grande", "Enorme"]
const SIZE_DIMS:   Array[Vector2i] = [
	Vector2i(12, 8), Vector2i(24, 16), Vector2i(36, 24), Vector2i(48, 32),
]
const SIZE_TOWERS: Array[int] = [6, 14, 24, 36]

# ─── Terrain colors for minimap ───────────────────────────────────────────────
const TERRAIN_COLS: Array[Color] = [
	Color(0.44, 0.76, 0.33),   # GRASS
	Color(0.22, 0.52, 0.88),   # WATER
	Color(0.52, 0.52, 0.52),   # MOUNTAIN
	Color(0.13, 0.44, 0.13),   # FOREST
	Color(0.76, 0.66, 0.34),   # DESERT
	Color(0.74, 0.18, 0.05),   # VOLCANO
	Color(0.20, 0.22, 0.26),   # CORDILLERA
]

# ─── UI palette ───────────────────────────────────────────────────────────────
const C_BG     := Color(0.055, 0.055, 0.095)
const C_PANEL  := Color(0.08,  0.08,  0.14,  0.95)
const C_BORDER := Color(0.24,  0.24,  0.38)
const C_TEXT   := Color(0.95,  0.95,  1.00)
const C_DIM    := Color(0.50,  0.50,  0.62)
const C_PURPLE := Color(0.65,  0.28,  0.95)
const C_PLAY   := Color(0.94,  0.74,  0.12)

# ─── Preview rect (fixed layout, drawn in _draw) ──────────────────────────────
const PRV_X := 636.0
const PRV_Y := 122.0
const PRV_W := 598.0
const PRV_H := 390.0

# ─── State ────────────────────────────────────────────────────────────────────
var _type_idx: int = 0
var _size_idx: int = 1
var _seed:     int = 0

var _type_cards: Array[Control] = []
var _size_btns:  Array[Button]  = []
var _seed_input: LineEdit       = null
var _info_lbl:   Label          = null

var _preview_terrain:   Array = []
var _preview_tower_pos: Array = []

# ─── Hex particles ────────────────────────────────────────────────────────────
var _particles: Array[Dictionary] = []

# ─── Init ─────────────────────────────────────────────────────────────────────
func _ready() -> void:
	print("[MapSelect] _ready() iniciado")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	randomize()
	_seed = randi() % 999999 + 1
	_init_particles(32)
	_build_ui()
	_refresh_preview()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.45)

func _process(delta: float) -> void:
	for p: Dictionary in _particles:
		var pos: Vector2 = p["pos"]
		pos += (p["vel"] as Vector2) * delta
		p["rot"] = float(p["rot"]) + float(p["rot_spd"]) * delta
		if pos.x < -48.0:    pos.x = 1328.0
		elif pos.x > 1328.0: pos.x = -48.0
		if pos.y < -48.0:    pos.y = 768.0
		elif pos.y > 768.0:  pos.y = -48.0
		p["pos"] = pos
	queue_redraw()

func _draw() -> void:
	# Background
	draw_rect(Rect2(Vector2.ZERO, size), C_BG)

	# Panel backgrounds: border rect then fill rect
	draw_rect(Rect2(27.0,  87.0, 564.0, 504.0), C_BORDER)
	draw_rect(Rect2(28.0,  88.0, 562.0, 502.0), C_PANEL)
	draw_rect(Rect2(617.0, 87.0, 636.0, 504.0), C_BORDER)
	draw_rect(Rect2(618.0, 88.0, 634.0, 502.0), C_PANEL)

	# Particles
	for p: Dictionary in _particles:
		var pts := _hex_pts(p["pos"] as Vector2, float(p["size"]), float(p["rot"]))
		var packed := PackedVector2Array(pts)
		packed.append(pts[0])
		draw_polyline(packed, Color(C_PURPLE.r, C_PURPLE.g, C_PURPLE.b, float(p["alpha"])), 1.2)

	# Minimap preview (all drawn inside root's _draw so no child draw signal needed)
	_draw_preview()

func _draw_preview() -> void:
	if _preview_terrain.is_empty():
		draw_rect(Rect2(PRV_X, PRV_Y, PRV_W, PRV_H), Color(0.08, 0.08, 0.12))
		draw_rect(Rect2(PRV_X - 1.0, PRV_Y - 1.0, PRV_W + 2.0, PRV_H + 2.0), C_BORDER, false, 1.0)
		return

	var rows: int = _preview_terrain.size()
	var cols: int = (_preview_terrain[0] as Array).size() if rows > 0 else 1
	var cw: float = PRV_W / float(cols)
	var ch: float = PRV_H / float(rows)

	# Background fill
	draw_rect(Rect2(PRV_X, PRV_Y, PRV_W, PRV_H), Color(0.10, 0.10, 0.15))

	# Terrain cells
	for r: int in range(rows):
		for c: int in range(cols):
			var t: int = (_preview_terrain[r] as Array)[c]
			var col: Color = TERRAIN_COLS[clampi(t, 0, TERRAIN_COLS.size() - 1)]
			draw_rect(Rect2(PRV_X + float(c) * cw, PRV_Y + float(r) * ch, cw + 0.5, ch + 0.5), col)

	# Tower markers
	var dot_r: float = maxf(cw * 0.45, 2.5)
	for tv: Variant in _preview_tower_pos:
		var tp: Vector2i = tv as Vector2i
		var tx: float = PRV_X + (float(tp.x) + 0.5) * cw
		var ty: float = PRV_Y + (float(tp.y) + 0.5) * ch
		draw_circle(Vector2(tx, ty), dot_r + 1.0, Color(0.0, 0.0, 0.0, 0.7))
		draw_circle(Vector2(tx, ty), dot_r,       Color(1.0, 0.95, 0.6, 0.90))

	# Border
	draw_rect(Rect2(PRV_X - 1.0, PRV_Y - 1.0, PRV_W + 2.0, PRV_H + 2.0), C_BORDER, false, 1.0)

func _hex_pts(center: Vector2, r: float, rot: float) -> Array[Vector2]:
	var pts: Array[Vector2] = []
	for i: int in range(6):
		var a: float = rot + TAU * float(i) / 6.0
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	return pts

func _init_particles(n: int) -> void:
	_particles.clear()
	for _i: int in range(n):
		var angle: float = randf() * TAU
		var speed: float = randf_range(6.0, 20.0)
		_particles.append({
			"pos":     Vector2(randf() * 1280.0, randf() * 720.0),
			"vel":     Vector2(cos(angle), sin(angle)) * speed,
			"size":    randf_range(9.0, 30.0),
			"alpha":   randf_range(0.03, 0.12),
			"rot":     randf() * TAU,
			"rot_spd": randf_range(-0.22, 0.22),
		})

# ─── UI construction ──────────────────────────────────────────────────────────
func _build_ui() -> void:
	var title := Label.new()
	title.text = "✦  SELECCIÓN DE MAPA"
	title.position = Vector2(0.0, 20.0)
	title.size     = Vector2(1280.0, 56.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", C_PLAY)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)

	_build_left_panel()
	_build_right_panel()
	_build_bottom_bar()

# ─── Left panel ───────────────────────────────────────────────────────────────
func _build_left_panel() -> void:
	const OX := 28.0
	const OY := 88.0

	# Map type section
	_section_lbl("TIPO DE MAPA", Vector2(OX + 16.0, OY + 14.0))

	var card_w := 178.0
	var card_h := 150.0
	for i: int in range(3):
		var cx: float = OX + 16.0 + float(i) * (card_w + 4.0)
		_build_type_card(i, Vector2(cx, OY + 34.0), Vector2(card_w, card_h))

	# Map size section
	_section_lbl("TAMAÑO DEL MAPA", Vector2(OX + 16.0, OY + 200.0))

	var sbw := 129.0
	var sbh := 50.0
	for i: int in range(4):
		var sx: float = OX + 16.0 + float(i) * (sbw + 6.0)
		_build_size_btn(i, Vector2(sx, OY + 220.0), Vector2(sbw, sbh))

	# Seed section
	_section_lbl("SEMILLA", Vector2(OX + 16.0, OY + 288.0))

	_seed_input = _line_edit(str(_seed), Vector2(OX + 16.0, OY + 308.0), Vector2(180.0, 40.0))
	_seed_input.text_submitted.connect(_on_seed_submitted)
	_seed_input.text_changed.connect(_on_seed_changed)
	add_child(_seed_input)

	var btn_rnd := _mk_btn("⟳  Aleatorio",
			Vector2(OX + 206.0, OY + 308.0), Vector2(118.0, 40.0),
			Color(0.12, 0.06, 0.24), C_PURPLE)
	btn_rnd.pressed.connect(_on_random_seed)
	add_child(btn_rnd)

	var btn_copy := _mk_btn("⎘  Copiar",
			Vector2(OX + 334.0, OY + 308.0), Vector2(92.0, 40.0),
			Color(0.08, 0.08, 0.16), C_BORDER)
	btn_copy.pressed.connect(_on_copy_seed)
	add_child(btn_copy)

	var hint := Label.new()
	hint.text = "Comparte la semilla para reproducir el mismo mapa exacto"
	hint.position = Vector2(OX + 16.0, OY + 356.0)
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", C_DIM)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)

func _section_lbl(text: String, pos: Vector2) -> void:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", C_DIM)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)

func _build_type_card(idx: int, pos: Vector2, sz: Vector2) -> void:
	var btn := Button.new()
	btn.position = pos
	btn.size     = sz
	btn.text     = ""
	btn.clip_contents = true

	var ns := StyleBoxFlat.new()
	ns.bg_color     = MAP_BG_COL[idx]
	ns.border_color = MAP_ACCENT[idx].darkened(0.40)
	ns.set_border_width_all(1)
	btn.add_theme_stylebox_override("normal", ns)

	var hs := StyleBoxFlat.new()
	hs.bg_color     = MAP_BG_COL[idx].lightened(0.10)
	hs.border_color = MAP_ACCENT[idx]
	hs.set_border_width_all(2)
	btn.add_theme_stylebox_override("hover", hs)

	var ps := StyleBoxFlat.new()
	ps.bg_color     = MAP_BG_COL[idx].darkened(0.15)
	ps.border_color = MAP_ACCENT[idx]
	ps.set_border_width_all(2)
	btn.add_theme_stylebox_override("pressed", ps)
	btn.add_theme_stylebox_override("focus", ns)

	var stripe := ColorRect.new()
	stripe.position     = Vector2(0.0, 0.0)
	stripe.size         = Vector2(sz.x, 4.0)
	stripe.color        = MAP_ACCENT[idx]
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(stripe)

	var name_lbl := Label.new()
	name_lbl.text     = MAP_NAMES[idx]
	name_lbl.position = Vector2(10.0, 14.0)
	name_lbl.add_theme_font_size_override("font_size", 19)
	name_lbl.add_theme_color_override("font_color", MAP_ACCENT[idx])
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(name_lbl)

	var desc := Label.new()
	desc.text          = MAP_DESCS[idx]
	desc.position      = Vector2(10.0, 42.0)
	desc.size          = Vector2(sz.x - 16.0, 72.0)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", C_DIM)
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(desc)

	var sel := Label.new()
	sel.name     = "SelLbl"
	sel.text     = ""
	sel.position = Vector2(10.0, sz.y - 24.0)
	sel.add_theme_font_size_override("font_size", 13)
	sel.add_theme_color_override("font_color", MAP_ACCENT[idx])
	sel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(sel)

	btn.pressed.connect(func(): _select_type(idx))
	add_child(btn)
	_type_cards.append(btn)

func _build_size_btn(idx: int, pos: Vector2, sz: Vector2) -> void:
	var dims   := SIZE_DIMS[idx]
	var towers := SIZE_TOWERS[idx]
	var text   := "%s\n%d×%d  ·  %d torres" % [SIZE_NAMES[idx], dims.x, dims.y, towers]
	var btn    := _mk_btn(text, pos, sz, Color(0.08, 0.08, 0.16), C_BORDER)
	btn.add_theme_font_size_override("font_size", 11)
	btn.pressed.connect(func(): _select_size(idx))
	add_child(btn)
	_size_btns.append(btn)

# ─── Right panel ──────────────────────────────────────────────────────────────
func _build_right_panel() -> void:
	_section_lbl("VISTA PREVIA", Vector2(PRV_X, PRV_Y - 20.0))

	_info_lbl = Label.new()
	_info_lbl.position          = Vector2(PRV_X, PRV_Y + PRV_H + 10.0)
	_info_lbl.size              = Vector2(PRV_W, 56.0)
	_info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_lbl.autowrap_mode     = TextServer.AUTOWRAP_WORD_SMART
	_info_lbl.add_theme_font_size_override("font_size", 13)
	_info_lbl.add_theme_color_override("font_color", C_DIM)
	_info_lbl.mouse_filter      = Control.MOUSE_FILTER_IGNORE
	add_child(_info_lbl)

# ─── Bottom bar ───────────────────────────────────────────────────────────────
func _build_bottom_bar() -> void:
	const Y := 610.0

	var btn_back := _mk_btn("◀  Volver", Vector2(28.0, Y), Vector2(180.0, 52.0),
			Color(0.10, 0.06, 0.06, 0.95), Color(0.55, 0.30, 0.30))
	btn_back.add_theme_font_size_override("font_size", 18)
	btn_back.pressed.connect(_on_back)
	add_child(btn_back)

	var btn_play := _mk_btn("✦  ¡Jugar!", Vector2(1072.0, Y), Vector2(180.0, 52.0),
			Color(0.22, 0.15, 0.02, 0.95), C_PLAY)
	btn_play.add_theme_font_size_override("font_size", 20)
	btn_play.add_theme_color_override("font_color", C_PLAY)
	btn_play.pressed.connect(_on_play)
	add_child(btn_play)

# ─── Widget helpers ───────────────────────────────────────────────────────────
func _mk_btn(text: String, pos: Vector2, sz: Vector2, bg: Color, border: Color) -> Button:
	var btn := Button.new()
	btn.text     = text
	btn.position = pos
	btn.size     = sz
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", C_TEXT)
	for k: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var st := StyleBoxFlat.new()
		match k:
			"hover":   st.bg_color = bg.lightened(0.12)
			"pressed": st.bg_color = bg.darkened(0.18)
			_:         st.bg_color = bg
		st.border_color          = border
		st.set_border_width_all(1)
		st.content_margin_left   = 6.0
		st.content_margin_right  = 6.0
		st.content_margin_top    = 4.0
		st.content_margin_bottom = 4.0
		btn.add_theme_stylebox_override(k, st)
	return btn

func _line_edit(text: String, pos: Vector2, sz: Vector2) -> LineEdit:
	var le := LineEdit.new()
	le.text     = text
	le.position = pos
	le.size     = sz
	le.add_theme_font_size_override("font_size", 16)
	var st := StyleBoxFlat.new()
	st.bg_color     = Color(0.06, 0.06, 0.10)
	st.border_color = C_BORDER
	st.set_border_width_all(1)
	st.content_margin_left  = 8.0
	st.content_margin_right = 8.0
	for k: String in ["normal", "focus", "read_only"]:
		le.add_theme_stylebox_override(k, st)
	return le

# ─── Refresh logic ────────────────────────────────────────────────────────────
func _refresh_preview() -> void:
	var gen      := MapGeneratorScript.new()
	var map_size := SIZE_DIMS[_size_idx]
	gen.generate(_seed, MAP_TYPES[_type_idx], map_size)
	_preview_terrain   = gen.get_terrain()
	_preview_tower_pos = gen.get_tower_positions()
	_update_info_lbl()
	_update_type_cards()
	_update_size_btns()
	queue_redraw()

func _update_info_lbl() -> void:
	if _info_lbl == null:
		return
	var dims   := SIZE_DIMS[_size_idx]
	var towers := SIZE_TOWERS[_size_idx]
	_info_lbl.text = (
		"%s  ·  %d × %d celdas  ·  %d torres\nSemilla: %d"
		% [MAP_NAMES[_type_idx], dims.x, dims.y, towers, _seed]
	)

func _update_type_cards() -> void:
	for i: int in range(_type_cards.size()):
		var is_sel: bool = (i == _type_idx)
		var card := _type_cards[i] as Button
		var sel_lbl := card.get_node_or_null("SelLbl") as Label
		if sel_lbl:
			sel_lbl.text = "✓  Seleccionado" if is_sel else ""
		var ns := card.get_theme_stylebox("normal") as StyleBoxFlat
		if ns:
			ns.border_color = MAP_ACCENT[i] if is_sel else MAP_ACCENT[i].darkened(0.40)
			ns.set_border_width_all(3 if is_sel else 1)

func _update_size_btns() -> void:
	for i: int in range(_size_btns.size()):
		var is_sel: bool = (i == _size_idx)
		var bg: Color = Color(0.16, 0.08, 0.30, 0.95) if is_sel else Color(0.08, 0.08, 0.16)
		var bd: Color = C_PURPLE if is_sel else C_BORDER
		var st := _size_btns[i].get_theme_stylebox("normal") as StyleBoxFlat
		if st:
			st.bg_color     = bg
			st.border_color = bd
			st.set_border_width_all(2 if is_sel else 1)

# ─── Callbacks ────────────────────────────────────────────────────────────────
func _select_type(idx: int) -> void:
	_type_idx = idx
	_refresh_preview()

func _select_size(idx: int) -> void:
	_size_idx = idx
	_refresh_preview()

func _on_seed_submitted(text: String) -> void:
	_apply_seed_text(text)

func _on_seed_changed(text: String) -> void:
	_apply_seed_text(text)

func _apply_seed_text(text: String) -> void:
	var v: int = text.to_int()
	if v > 0:
		_seed = v
		_refresh_preview()

func _on_random_seed() -> void:
	_seed = randi() % 999999 + 1
	if _seed_input:
		_seed_input.text = str(_seed)
	_refresh_preview()

func _on_copy_seed() -> void:
	DisplayServer.clipboard_set(str(_seed))

func _on_play() -> void:
	GameData.current_map = _type_idx
	GameData.map_seed    = _seed
	GameData.map_size    = SIZE_DIMS[_size_idx]
	GameData.map_terrain = []   # force regeneration in Main3D._ready()
	get_tree().change_scene_to_file("res://scenes/Main3D.tscn")

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/FactionSelect.tscn")
