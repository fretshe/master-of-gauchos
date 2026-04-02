extends Control

const MapGeneratorScript := preload("res://scripts/MapGenerator.gd")
const MENU_BACKGROUND_PATH := "res://assets/sprites/title/menu_background.png"

const MAP_TYPES: Array[String] = ["plains", "sierras", "precordillera"]
const MAP_NAMES: Array[String] = ["Llanuras", "Sierras", "Precordillera"]
const MAP_DESCS: Array[String] = [
	"Campos abiertos y monte.\nMapa amistoso para comenzar.",
	"Lomas, pasos y altura.\nTerreno mas tactico.",
	"Suelo arido y sierras secas.\nTerreno aspero y abierto.",
]
const MAP_ACCENT: Array[Color] = [
	Color(0.24, 0.82, 0.36),
	Color(0.92, 0.72, 0.34),
	Color(0.66, 0.72, 0.78),
]
const SIZE_NAMES: Array[String] = ["Pequeno", "Mediano", "Grande", "Amplio"]
const SIZE_DIMS: Array[Vector2i] = [
	Vector2i(10, 8), Vector2i(16, 12), Vector2i(22, 16), Vector2i(28, 20),
]
const SIZE_TOWERS: Array[int] = [5, 10, 16, 22]
const TERRAIN_COLS: Array[Color] = [
	Color(0.44, 0.76, 0.33),
	Color(0.22, 0.52, 0.88),
	Color(0.52, 0.52, 0.52),
	Color(0.13, 0.44, 0.13),
	Color(0.76, 0.66, 0.34),
	Color(0.74, 0.18, 0.05),
	Color(0.20, 0.22, 0.26),
]

const BG_TOP := Color(0.10, 0.07, 0.12, 1.0)
const BG_BOTTOM := Color(0.93, 0.58, 0.30, 1.0)
const SKY_HAZE := Color(1.0, 0.78, 0.58, 0.16)
const C_BG := Color(0.10, 0.07, 0.12)
const C_PANEL := Color(0.06, 0.07, 0.10, 0.92)
const C_BORDER := Color(0.92, 0.86, 0.66, 0.22)
const C_TEXT := Color(0.96, 0.95, 0.92)
const C_DIM := Color(0.80, 0.76, 0.68, 0.82)
const C_PLAY := Color(0.95, 0.79, 0.24)
const RANDOM_FACTION := -99
const COLOR_NAMES := ["Azul", "Rojo", "Verde", "Amarillo", "Celeste", "Naranja", "Violeta", "Rosa"]
const PLAYER_DEFAULT_COLOR_IDX := [0, 1, 2, 3]  # índice inicial por jugador en AVAILABLE_COLORS
const COL_SELECTED := Color(0.95, 0.80, 0.20)
const COL_IDLE := Color(0.44, 0.34, 0.24)
const BG_SELECTED := Color(0.20, 0.12, 0.09, 0.95)
const BG_IDLE := Color(0.12, 0.10, 0.10, 0.82)
const SCREEN_SIZE := Vector2(1280.0, 720.0)

const LEFT_X := 28.0
const LEFT_Y := 88.0
const LEFT_W := 564.0
const LEFT_H := 504.0
const RIGHT_X := 617.0
const RIGHT_Y := 88.0
const RIGHT_W := 636.0
const RIGHT_H := 504.0

const PRV_X := 920.0
const PRV_Y := 344.0
const PRV_W := 244.0
const PRV_H := 224.0

var _faction_p1: int = 0
var _faction_p2: int = 1
var _faction_p3: int = 0
var _faction_p4: int = 1
var _player_color_idx: Dictionary = {1: 0, 2: 1, 3: 2, 4: 3}
var _player3_enabled: bool = false
var _player4_enabled: bool = false
var _player_modes := {1: "human", 2: "human", 3: "human", 4: "human"}
var _type_idx: int = 0
var _size_idx: int = 1
var _seed: int = 0

var _player_cards: Dictionary = {}
var _player_headers: Dictionary = {}
var _player_subheaders: Dictionary = {}
var _player_panels: Dictionary = {}
var _player_enable_btns: Dictionary = {}
var _player_faction_btns: Dictionary = {}
var _player_color_selects: Dictionary = {}
var _player_mode_btns: Dictionary = {}
var _player_preview_rows: Dictionary = {}
var _type_cards: Array[Control] = []
var _size_btns: Array[Button] = []
var _seed_input: LineEdit = null
var _info_lbl: Label = null
var _preview_terrain: Array = []
var _preview_tower_pos: Array = []
var _particles: Array[Dictionary] = []
var _star_particles: Array[Dictionary] = []
var _view_scale: float = 1.0
var _view_origin: Vector2 = Vector2.ZERO
var _background_texture: Texture2D = null

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	size = SCREEN_SIZE
	mouse_filter = Control.MOUSE_FILTER_PASS
	GameData.load_meta()
	randomize()
	_seed = randi() % 999999 + 1
	_init_particles(24)
	_build_ui()
	_refresh_preview()
	GameData.call_deferred("apply_selected_theme", get_window())
	_update_layout()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.35)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_update_layout()

func _process(delta: float) -> void:
	for p: Dictionary in _particles:
		var pos: Vector2 = p["pos"]
		pos += (p["vel"] as Vector2) * delta
		p["rot"] = float(p["rot"]) + float(p["rot_spd"]) * delta
		if pos.x < -48.0:
			pos.x = 1328.0
		elif pos.x > 1328.0:
			pos.x = -48.0
		if pos.y < -48.0:
			pos.y = 768.0
		elif pos.y > 768.0:
			pos.y = -48.0
		p["pos"] = pos
	for star: Dictionary in _star_particles:
		star["twinkle"] = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.001 * star["speed"] + star["phase"])
	queue_redraw()

func _viewport_size() -> Vector2:
	var rect: Rect2 = get_viewport_rect()
	return rect.size if rect.size != Vector2.ZERO else SCREEN_SIZE

func _update_layout() -> void:
	var viewport_size: Vector2 = _viewport_size()
	_view_scale = minf(viewport_size.x / SCREEN_SIZE.x, viewport_size.y / SCREEN_SIZE.y)
	if _view_scale <= 0.0:
		_view_scale = 1.0
	var scaled_size: Vector2 = SCREEN_SIZE * _view_scale
	_view_origin = (viewport_size - scaled_size) * 0.5
	position = _view_origin
	scale = Vector2.ONE * _view_scale

func _draw() -> void:
	_draw_background()
	draw_rect(Rect2(LEFT_X - 1.0, LEFT_Y - 1.0, LEFT_W + 2.0, LEFT_H + 2.0), C_BORDER)
	draw_rect(Rect2(LEFT_X, LEFT_Y, LEFT_W, LEFT_H), C_PANEL)
	draw_rect(Rect2(RIGHT_X - 1.0, RIGHT_Y - 1.0, RIGHT_W + 2.0, RIGHT_H + 2.0), C_BORDER)
	draw_rect(Rect2(RIGHT_X, RIGHT_Y, RIGHT_W, RIGHT_H), C_PANEL)

	for p: Dictionary in _particles:
		var pts := _hex_pts(p["pos"] as Vector2, float(p["size"]), float(p["rot"]))
		var packed := PackedVector2Array(pts)
		packed.append(pts[0])
		draw_polyline(packed, Color(0.58, 0.26, 0.92, float(p["alpha"])), 1.0)

	_draw_preview()

func _draw_background() -> void:
	if _background_texture != null:
		draw_texture_rect(_background_texture, Rect2(Vector2.ZERO, size), false)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.03, 0.05, 0.30))
	for i: int in range(14):
		var t: float = float(i) / 13.0
		var color := BG_TOP.lerp(BG_BOTTOM, pow(t, 1.6))
		color.a *= 0.22
		draw_rect(Rect2(0.0, float(i) * size.y / 14.0, size.x, size.y / 14.0 + 2.0), color)
	draw_rect(Rect2(0.0, 0.0, size.x, size.y * 0.48), Color(SKY_HAZE.r, SKY_HAZE.g, SKY_HAZE.b, 0.06))
	for star: Dictionary in _star_particles:
		draw_circle(star["pos"], star["radius"], Color(1.0, 0.94, 0.76, 0.08 + 0.22 * float(star["twinkle"])))
	for p: Dictionary in _particles:
		var pts := _hex_pts(p["pos"] as Vector2, float(p["size"]), float(p["rot"]))
		var packed := PackedVector2Array(pts)
		packed.append(pts[0])
		draw_polyline(packed, Color(0.70, 0.56, 0.26, float(p["alpha"])), 1.0)
	var ridge_back := PackedVector2Array([
		Vector2(0.0, 430.0), Vector2(96.0, 396.0), Vector2(208.0, 420.0), Vector2(336.0, 352.0),
		Vector2(478.0, 380.0), Vector2(622.0, 316.0), Vector2(792.0, 354.0), Vector2(960.0, 290.0),
		Vector2(1120.0, 340.0), Vector2(1280.0, 286.0), Vector2(1280.0, 720.0), Vector2(0.0, 720.0),
	])
	draw_colored_polygon(ridge_back, Color(0.35, 0.20, 0.14, 0.58))
	var ridge_mid := PackedVector2Array([
		Vector2(0.0, 512.0), Vector2(144.0, 470.0), Vector2(288.0, 530.0), Vector2(438.0, 456.0),
		Vector2(608.0, 502.0), Vector2(760.0, 434.0), Vector2(936.0, 480.0), Vector2(1112.0, 430.0),
		Vector2(1280.0, 456.0), Vector2(1280.0, 720.0), Vector2(0.0, 720.0),
	])
	draw_colored_polygon(ridge_mid, Color(0.24, 0.18, 0.12, 0.72))
	var ridge_front := PackedVector2Array([
		Vector2(0.0, 596.0), Vector2(150.0, 570.0), Vector2(310.0, 602.0), Vector2(474.0, 552.0),
		Vector2(678.0, 594.0), Vector2(870.0, 534.0), Vector2(1042.0, 584.0), Vector2(1280.0, 560.0),
		Vector2(1280.0, 720.0), Vector2(0.0, 720.0),
	])
	draw_colored_polygon(ridge_front, Color(0.15, 0.14, 0.10, 0.95))
	_draw_far_tower(Vector2(706.0, 468.0), 0.78, Color(0.92, 0.85, 0.74, 0.48))
	_draw_far_tower(Vector2(924.0, 500.0), 0.62, Color(0.90, 0.83, 0.72, 0.38))
	_draw_far_tower(Vector2(1116.0, 474.0), 0.86, Color(0.92, 0.85, 0.74, 0.56))

func _draw_far_tower(base_pos: Vector2, scale: float, color: Color) -> void:
	var shaft_w: float = 10.0 * scale
	var shaft_h: float = 52.0 * scale
	var base_w: float = 20.0 * scale
	var base_h: float = 6.0 * scale
	var crown_w: float = 24.0 * scale
	var crown_h: float = 8.0 * scale
	var merlon_w: float = 4.0 * scale
	var merlon_h: float = 7.0 * scale
	draw_rect(Rect2(base_pos.x - base_w * 0.5, base_pos.y - base_h, base_w, base_h), color)
	draw_rect(Rect2(base_pos.x - shaft_w * 0.5, base_pos.y - shaft_h, shaft_w, shaft_h - base_h), color)
	draw_rect(Rect2(base_pos.x - crown_w * 0.5, base_pos.y - shaft_h - crown_h, crown_w, crown_h), color)
	for i: int in range(3):
		var mx: float = base_pos.x - crown_w * 0.5 + 2.0 * scale + float(i) * (merlon_w + 3.0 * scale)
		draw_rect(Rect2(mx, base_pos.y - shaft_h - crown_h - merlon_h, merlon_w, merlon_h), color)

func _build_ui() -> void:
	_background_texture = load(MENU_BACKGROUND_PATH) as Texture2D

	var title := Label.new()
	title.text = "SUMMONERS OF THE ANDES"
	title.position = Vector2(0.0, 14.0)
	title.size = Vector2(1280.0, 52.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", C_PLAY)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Nueva partida"
	subtitle.position = Vector2(0.0, 50.0)
	subtitle.size = Vector2(1280.0, 24.0)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", C_DIM)
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(subtitle)

	_build_faction_panel()
	_build_map_panel()
	_build_bottom_bar()

func _build_faction_panel() -> void:
	_section_lbl("FACCIONES", Vector2(LEFT_X + 16.0, LEFT_Y + 14.0))
	_player_cards.clear()
	_player_headers.clear()
	_player_subheaders.clear()
	_player_panels.clear()
	_player_enable_btns.clear()
	_player_faction_btns.clear()
	_player_color_selects.clear()
	_player_mode_btns.clear()
	_player_preview_rows.clear()

	var cols := {
		"enable": LEFT_X + 18.0,
		"name": LEFT_X + 78.0,
		"faction": LEFT_X + 222.0,
		"mode": LEFT_X + 394.0,
		"preview": LEFT_X + 494.0,
	}
	_section_lbl("ACTIVO", Vector2(cols["enable"], LEFT_Y + 38.0))
	_section_lbl("JUGADOR", Vector2(cols["name"], LEFT_Y + 38.0))
	_section_lbl("FACCION", Vector2(cols["faction"], LEFT_Y + 38.0))
	_section_lbl("CONTROL", Vector2(cols["mode"], LEFT_Y + 38.0))
	_section_lbl("VISTA", Vector2(cols["preview"], LEFT_Y + 38.0))

	for player_id: int in [1, 2, 3, 4]:
		var y: float = LEFT_Y + 62.0 + float(player_id - 1) * 102.0
		var row_panel := Panel.new()
		row_panel.position = Vector2(LEFT_X + 16.0, y)
		row_panel.size = Vector2(528.0, 84.0)
		row_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var row_style := StyleBoxFlat.new()
		row_style.bg_color = Color(0.08, 0.08, 0.10, 0.84)
		row_style.border_color = Color(_get_player_setup_color(player_id).r, _get_player_setup_color(player_id).g, _get_player_setup_color(player_id).b, 0.22)
		row_style.set_border_width_all(1)
		row_style.set_corner_radius_all(3)
		row_panel.add_theme_stylebox_override("panel", row_style)
		add_child(row_panel)
		_player_panels[player_id] = row_panel

		var enable_btn := _mk_btn("", Vector2(cols["enable"], y + 24.0), Vector2(42.0, 32.0), Color(0.08, 0.08, 0.16, 0.95), C_BORDER)
		enable_btn.add_theme_font_size_override("font_size", 15)
		enable_btn.pressed.connect(func(pid := player_id): _toggle_player_enabled(pid))
		enable_btn.pressed.connect(AudioManager.play_menu_button)
		add_child(enable_btn)
		_player_enable_btns[player_id] = enable_btn

		var header := Label.new()
		header.text = "Jugador %d" % player_id
		header.position = Vector2(cols["name"], y + 12.0)
		header.size = Vector2(132.0, 22.0)
		header.add_theme_font_size_override("font_size", 19)
		header.add_theme_color_override("font_color", _get_player_setup_color(player_id))
		add_child(header)
		_player_headers[player_id] = header

		var subheader := Label.new()
		subheader.position = Vector2(cols["name"], y + 34.0)
		subheader.size = Vector2(118.0, 16.0)
		subheader.add_theme_font_size_override("font_size", 11)
		subheader.add_theme_color_override("font_color", C_DIM)
		subheader.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(subheader)
		_player_subheaders[player_id] = subheader

		var color_select := _mk_option(Vector2(cols["name"], y + 54.0), Vector2(140.0, 24.0), 12)
		for ci: int in range(min(GameData.AVAILABLE_COLORS.size(), COLOR_NAMES.size())):
			color_select.add_icon_item(_make_color_chip(GameData.AVAILABLE_COLORS[ci]), COLOR_NAMES[ci], ci)
		color_select.item_selected.connect(func(index: int, pid := player_id): _on_color_selected(pid, index))
		add_child(color_select)
		_player_color_selects[player_id] = color_select

		var faction_btn := _mk_option(Vector2(cols["faction"], y + 20.0), Vector2(146.0, 42.0), 16)
		faction_btn.add_item("Aleatorio", RANDOM_FACTION)
		for faction_id: int in FactionData.get_all_faction_ids():
			faction_btn.add_item(FactionData.get_faction_name(faction_id), faction_id)
		faction_btn.item_selected.connect(func(index: int, pid := player_id, opt := faction_btn):
			_on_faction_selected(pid, opt.get_item_id(index))
		)
		add_child(faction_btn)
		_player_faction_btns[player_id] = faction_btn

		var mode_btn := _mk_btn("", Vector2(cols["mode"], y + 20.0), Vector2(90.0, 42.0), Color(0.08, 0.08, 0.16, 0.95), C_BORDER)
		mode_btn.add_theme_font_size_override("font_size", 14)
		mode_btn.pressed.connect(func(pid := player_id): _cycle_player_mode(pid))
		mode_btn.pressed.connect(AudioManager.play_menu_button)
		add_child(mode_btn)
		_player_mode_btns[player_id] = mode_btn

		var preview := HBoxContainer.new()
		preview.position = Vector2(cols["preview"] - 6.0, y + 10.0)
		preview.custom_minimum_size = Vector2(82.0, 60.0)
		preview.alignment = BoxContainer.ALIGNMENT_CENTER
		preview.add_theme_constant_override("separation", 4)
		add_child(preview)
		_player_preview_rows[player_id] = preview

	_refresh_player_rows()

func _build_map_panel() -> void:
	_section_lbl("MAPA", Vector2(RIGHT_X + 16.0, RIGHT_Y + 14.0))

	var card_w := 184.0
	for i: int in range(MAP_NAMES.size()):
		var card := _build_type_card(i, Vector2(RIGHT_X + 16.0 + float(i) * (card_w + 8.0), RIGHT_Y + 36.0), Vector2(card_w, 86.0))
		add_child(card)
		_type_cards.append(card)

	_section_lbl("TAMANO", Vector2(RIGHT_X + 16.0, RIGHT_Y + 138.0))
	for i: int in range(SIZE_NAMES.size()):
		var btn := _mk_btn(
			"%s\n%dx%d" % [SIZE_NAMES[i], SIZE_DIMS[i].x, SIZE_DIMS[i].y],
			Vector2(RIGHT_X + 16.0 + float(i) * 144.0, RIGHT_Y + 158.0),
			Vector2(136.0, 52.0),
			Color(0.12, 0.10, 0.10),
			C_BORDER
		)
		btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(func(index := i): _select_size(index))
		btn.pressed.connect(AudioManager.play_menu_button)
		add_child(btn)
		_size_btns.append(btn)

	_section_lbl("SEMILLA", Vector2(RIGHT_X + 16.0, RIGHT_Y + 226.0))
	_seed_input = _line_edit(str(_seed), Vector2(RIGHT_X + 16.0, RIGHT_Y + 246.0), Vector2(190.0, 40.0))
	_seed_input.text_changed.connect(_on_seed_changed)
	_seed_input.text_submitted.connect(_on_seed_submitted)
	add_child(_seed_input)

	var btn_random := _mk_btn("Aleatorio", Vector2(RIGHT_X + 16.0, RIGHT_Y + 294.0), Vector2(136.0, 36.0), Color(0.12, 0.06, 0.24), Color(0.66, 0.28, 0.95))
	btn_random.pressed.connect(_on_random_seed)
	btn_random.pressed.connect(AudioManager.play_menu_button)
	add_child(btn_random)

	var btn_copy := _mk_btn("Copiar", Vector2(RIGHT_X + 160.0, RIGHT_Y + 294.0), Vector2(104.0, 36.0), Color(0.12, 0.10, 0.10), C_BORDER)
	btn_copy.pressed.connect(_on_copy_seed)
	btn_copy.pressed.connect(AudioManager.play_menu_button)
	add_child(btn_copy)

	var preview_lbl := Label.new()
	preview_lbl.text = "Vista previa"
	preview_lbl.position = Vector2(PRV_X, PRV_Y - 22.0)
	preview_lbl.add_theme_font_size_override("font_size", 11)
	preview_lbl.add_theme_color_override("font_color", C_DIM)
	add_child(preview_lbl)

	_section_lbl("PRESETS", Vector2(RIGHT_X + 16.0, RIGHT_Y + 382.0))

	var btn_duel := _mk_btn("Duelo", Vector2(RIGHT_X + 16.0, RIGHT_Y + 402.0), Vector2(118.0, 34.0), Color(0.10, 0.09, 0.10, 0.94), C_BORDER)
	btn_duel.add_theme_font_size_override("font_size", 13)
	btn_duel.pressed.connect(_apply_preset_duel)
	btn_duel.pressed.connect(AudioManager.play_menu_button)
	add_child(btn_duel)

	var btn_trios := _mk_btn("3 jugadores", Vector2(RIGHT_X + 150.0, RIGHT_Y + 402.0), Vector2(118.0, 34.0), Color(0.10, 0.09, 0.10, 0.94), C_BORDER)
	btn_trios.add_theme_font_size_override("font_size", 13)
	btn_trios.pressed.connect(_apply_preset_trios)
	btn_trios.pressed.connect(AudioManager.play_menu_button)
	add_child(btn_trios)

	var btn_chaos := _mk_btn("Caos", Vector2(RIGHT_X + 16.0, RIGHT_Y + 444.0), Vector2(118.0, 34.0), Color(0.10, 0.09, 0.10, 0.94), C_BORDER)
	btn_chaos.add_theme_font_size_override("font_size", 13)
	btn_chaos.pressed.connect(_apply_preset_chaos)
	btn_chaos.pressed.connect(AudioManager.play_menu_button)
	add_child(btn_chaos)

	var btn_shuffle := _mk_btn("Mezclar", Vector2(RIGHT_X + 150.0, RIGHT_Y + 444.0), Vector2(118.0, 34.0), Color(0.16, 0.08, 0.22, 0.94), Color(0.72, 0.38, 0.96))
	btn_shuffle.add_theme_font_size_override("font_size", 13)
	btn_shuffle.pressed.connect(_randomize_setup)
	btn_shuffle.pressed.connect(AudioManager.play_menu_button)
	add_child(btn_shuffle)

	_info_lbl = Label.new()
	_info_lbl.position = Vector2(PRV_X - 12.0, PRV_Y + PRV_H + 8.0)
	_info_lbl.size = Vector2(PRV_W + 24.0, 34.0)
	_info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	_info_lbl.add_theme_font_size_override("font_size", 12)
	_info_lbl.add_theme_color_override("font_color", C_DIM)
	_info_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_info_lbl)

func _build_bottom_bar() -> void:
	var btn_back := _mk_btn("Volver", Vector2(28.0, 624.0), Vector2(180.0, 48.0), Color(0.10, 0.06, 0.06, 0.95), Color(0.55, 0.30, 0.30))
	btn_back.add_theme_font_size_override("font_size", 18)
	btn_back.pressed.connect(_on_back)
	btn_back.pressed.connect(AudioManager.play_menu_button)
	add_child(btn_back)

	var btn_play := _mk_btn("Jugar", Vector2(510.0, 620.0), Vector2(260.0, 54.0), Color(0.22, 0.15, 0.02, 0.95), C_PLAY)
	btn_play.add_theme_font_size_override("font_size", 24)
	btn_play.add_theme_color_override("font_color", C_PLAY)
	btn_play.pressed.connect(_on_play)
	btn_play.pressed.connect(AudioManager.play_menu_button)
	add_child(btn_play)

func _build_faction_card(player: int, faction: int, pos: Vector2, sz: Vector2) -> Panel:
	var panel := Panel.new()
	panel.position = pos
	panel.size = sz
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var style := StyleBoxFlat.new()
	style.bg_color = BG_IDLE
	style.border_color = COL_IDLE
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)

	var player_name := Label.new()
	player_name.text = FactionData.get_faction_name(faction)
	player_name.position = Vector2(10.0, 8.0)
	player_name.size = Vector2(sz.x - 20.0, 22.0)
	player_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_name.add_theme_font_size_override("font_size", 16)
	player_name.add_theme_color_override("font_color", FactionData.get_color(faction))
	panel.add_child(player_name)

	var desc := Label.new()
	desc.text = FactionData.get_desc(faction)
	desc.position = Vector2(10.0, 28.0)
	desc.size = Vector2(sz.x - 20.0, 22.0)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 10)
	desc.add_theme_color_override("font_color", C_DIM)
	panel.add_child(desc)

	var sprites_row := HBoxContainer.new()
	sprites_row.position = Vector2(8.0, 48.0)
	sprites_row.custom_minimum_size = Vector2(sz.x - 16.0, 22.0)
	sprites_row.alignment = BoxContainer.ALIGNMENT_CENTER
	sprites_row.add_theme_constant_override("separation", 6)
	panel.add_child(sprites_row)

	for unit_type: int in [-1, 0, 1]:
		var path: String = FactionData.get_sprite_path(faction, unit_type)
		if not ResourceLoader.exists(path):
			continue
		var tex: Texture2D = load(path)
		if tex == null:
			continue
		var transform_val := TextureRect.new()
		transform_val.texture = tex
		transform_val.custom_minimum_size = Vector2(20, 20)
		transform_val.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		transform_val.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		sprites_row.add_child(transform_val)

	var btn := Button.new()
	btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.flat = true
	var empty := StyleBoxEmpty.new()
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(state, empty)
	btn.pressed.connect(func(): _on_faction_selected(player, faction))
	btn.pressed.connect(AudioManager.play_menu_button)
	panel.add_child(btn)

	return panel

func _build_type_card(idx: int, pos: Vector2, sz: Vector2) -> Button:
	var btn := Button.new()
	btn.position = pos
	btn.size = sz
	btn.text = ""
	btn.clip_contents = true

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.10, 0.10, 0.88)
	normal.border_color = MAP_ACCENT[idx].darkened(0.35)
	normal.set_border_width_all(1)
	btn.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.20, 0.12, 0.09, 0.96)
	hover.border_color = MAP_ACCENT[idx]
	hover.set_border_width_all(2)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("focus", normal)

	var player_name := Label.new()
	player_name.text = MAP_NAMES[idx]
	player_name.position = Vector2(10.0, 10.0)
	player_name.add_theme_font_size_override("font_size", 17)
	player_name.add_theme_color_override("font_color", MAP_ACCENT[idx])
	btn.add_child(player_name)

	var desc := Label.new()
	desc.text = MAP_DESCS[idx]
	desc.position = Vector2(10.0, 34.0)
	desc.size = Vector2(sz.x - 16.0, 40.0)
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", C_DIM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn.add_child(desc)

	btn.pressed.connect(func(): _select_type(idx))
	btn.pressed.connect(AudioManager.play_menu_button)
	return btn

func _section_lbl(text: String, pos: Vector2) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.position = pos
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", C_DIM)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lbl)

func _apply_panel_style(panel: Panel, bg: Color, border: Color, border_width: int = 1, radius: int = 2) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	panel.add_theme_stylebox_override("panel", style)

func _mk_btn(text: String, pos: Vector2, sz: Vector2, bg: Color, border: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.position = pos
	btn.size = sz
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", C_TEXT)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var st := StyleBoxFlat.new()
		match state:
			"hover":
				st.bg_color = bg.lightened(0.12)
			"pressed":
				st.bg_color = bg.darkened(0.18)
			_:
				st.bg_color = bg
		st.border_color = border
		st.set_border_width_all(1)
		st.content_margin_left = 6.0
		st.content_margin_right = 6.0
		st.content_margin_top = 4.0
		st.content_margin_bottom = 4.0
		btn.add_theme_stylebox_override(state, st)
	return btn

func _mk_option(pos: Vector2, sz: Vector2, font_size: int = 13) -> OptionButton:
	var opt := OptionButton.new()
	opt.position = pos
	opt.size = sz
	opt.fit_to_longest_item = false
	opt.focus_mode = Control.FOCUS_NONE
	opt.add_theme_font_size_override("font_size", font_size)
	opt.add_theme_color_override("font_color", C_TEXT)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var st := StyleBoxFlat.new()
		match state:
			"hover":
				st.bg_color = Color(0.12, 0.12, 0.20, 0.96)
			"pressed":
				st.bg_color = Color(0.06, 0.06, 0.12, 0.96)
			_:
				st.bg_color = Color(0.08, 0.08, 0.16, 0.95)
		st.border_color = C_BORDER
		st.set_border_width_all(1)
		st.content_margin_left = 8.0
		st.content_margin_right = 20.0
		st.content_margin_top = 4.0
		st.content_margin_bottom = 4.0
		opt.add_theme_stylebox_override(state, st)
	var popup := opt.get_popup()
	popup.add_theme_font_size_override("font_size", font_size)
	return opt

func _make_color_chip(color: Color) -> Texture2D:
	var image := Image.create(14, 14, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	for y: int in range(14):
		for x: int in range(14):
			var edge: bool = x <= 1 or x >= 12 or y <= 1 or y >= 12
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, 0.92) if edge else color)
	return ImageTexture.create_from_image(image)

func _line_edit(text: String, pos: Vector2, sz: Vector2) -> LineEdit:
	var le := LineEdit.new()
	le.text = text
	le.position = pos
	le.size = sz
	le.add_theme_font_size_override("font_size", 16)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.10, 0.09, 0.10, 0.92)
	st.border_color = C_BORDER
	st.set_border_width_all(1)
	st.content_margin_left = 8.0
	st.content_margin_right = 8.0
	for state: String in ["normal", "focus", "read_only"]:
		le.add_theme_stylebox_override(state, st)
	return le

func _refresh_preview() -> void:
	var gen := MapGeneratorScript.new()
	var map_size: Vector2i = SIZE_DIMS[_size_idx]
	gen.generate(_seed, MAP_TYPES[_type_idx], map_size)
	_preview_terrain = gen.get_terrain()
	_preview_tower_pos = gen.get_tower_positions()
	_update_info_lbl()
	_update_type_cards()
	_update_size_btns()
	queue_redraw()

func _draw_preview() -> void:
	if _preview_terrain.is_empty():
		draw_rect(Rect2(PRV_X, PRV_Y, PRV_W, PRV_H), Color(0.10, 0.09, 0.10, 0.92))
		return
	var rows: int = _preview_terrain.size()
	var cols: int = (_preview_terrain[0] as Array).size() if rows > 0 else 1
	draw_rect(Rect2(PRV_X, PRV_Y, PRV_W, PRV_H), Color(0.10, 0.09, 0.10, 0.92))

	var local_hexes: Array[PackedVector2Array] = []
	var min_pt := Vector2(1e20, 1e20)
	var max_pt := Vector2(-1e20, -1e20)
	for c: int in range(cols):
		for r: int in range(rows):
			var points: PackedVector2Array = _preview_hex_points(c, r, 1.0)
			local_hexes.append(points)
			for pt: Vector2 in points:
				min_pt.x = minf(min_pt.x, pt.x)
				min_pt.y = minf(min_pt.y, pt.y)
				max_pt.x = maxf(max_pt.x, pt.x)
				max_pt.y = maxf(max_pt.y, pt.y)

	var bounds_size: Vector2 = max_pt - min_pt
	var scale_factor: float = minf(PRV_W / bounds_size.x, PRV_H / bounds_size.y) * 0.88
	var offset: Vector2 = Vector2(PRV_X, PRV_Y) + (Vector2(PRV_W, PRV_H) - bounds_size * scale_factor) * 0.5 - min_pt * scale_factor
	var hex_index: int = 0

	for r: int in range(rows):
		for c: int in range(cols):
			var t: int = (_preview_terrain[r] as Array)[c]
			var transformed := PackedVector2Array()
			for pt: Vector2 in local_hexes[hex_index]:
				transformed.append(pt * scale_factor + offset)
			draw_colored_polygon(transformed, TERRAIN_COLS[clampi(t, 0, TERRAIN_COLS.size() - 1)])
			draw_polyline(transformed, Color(0.08, 0.08, 0.12, 0.55), 1.0, true)
			hex_index += 1

	for tower_value: Variant in _preview_tower_pos:
		var tower_pos: Vector2i = tower_value as Vector2i
		var center: Vector2 = _preview_hex_center(tower_pos.x, tower_pos.y, scale_factor) + offset
		var marker := PackedVector2Array()
		for i: int in range(6):
			var angle: float = deg_to_rad(60.0 * float(i) + 30.0)
			marker.append(center + Vector2(cos(angle), sin(angle)) * maxf(scale_factor * 0.46, 2.8))
		draw_colored_polygon(marker, Color(1.0, 0.95, 0.6, 0.90))
	draw_rect(Rect2(PRV_X - 1.0, PRV_Y - 1.0, PRV_W + 2.0, PRV_H + 2.0), C_BORDER, false, 1.0)

func _preview_hex_center(col: int, row: int, radius: float) -> Vector2:
	var width: float = radius * 2.0
	var height: float = sqrt(3.0) * radius
	return Vector2(
		radius + float(col) * radius * 1.5,
		height * 0.5 + (float(row) + (0.5 if col % 2 == 1 else 0.0)) * height
	)

func _preview_hex_points(col: int, row: int, radius: float) -> PackedVector2Array:
	var center: Vector2 = _preview_hex_center(col, row, radius)
	var points := PackedVector2Array()
	for i: int in range(6):
		var angle: float = deg_to_rad(60.0 * float(i))
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points

func _update_info_lbl() -> void:
	if _info_lbl == null:
		return
	var dims: Vector2i = SIZE_DIMS[_size_idx]
	var towers: int = _preview_tower_pos.size() if not _preview_tower_pos.is_empty() else SIZE_TOWERS[_size_idx]
	_info_lbl.text = "%s  |  %dx%d  |  %d torres  |  Semilla %d" % [MAP_NAMES[_type_idx], dims.x, dims.y, towers, _seed]

func _update_type_cards() -> void:
	for i: int in range(_type_cards.size()):
		var btn := _type_cards[i] as Button
		var st := btn.get_theme_stylebox("normal") as StyleBoxFlat
		if st != null:
			st.border_color = MAP_ACCENT[i] if i == _type_idx else MAP_ACCENT[i].darkened(0.35)
			st.set_border_width_all(3 if i == _type_idx else 1)

func _update_size_btns() -> void:
	for i: int in range(_size_btns.size()):
		var st := _size_btns[i].get_theme_stylebox("normal") as StyleBoxFlat
		if st != null:
			st.bg_color = Color(0.22, 0.15, 0.02, 0.95) if i == _size_idx else Color(0.12, 0.10, 0.10, 0.92)
			st.border_color = C_PLAY if i == _size_idx else C_BORDER

func _get_player_faction(player_id: int) -> int:
	match player_id:
		1:
			return _faction_p1
		2:
			return _faction_p2
		3:
			return _faction_p3
		4:
			return _faction_p4
		_:
			return _faction_p1

func _get_faction_display_name(faction: int) -> String:
	return "Aleatorio" if faction == RANDOM_FACTION else FactionData.get_faction_name(faction)

func _get_faction_display_color(faction: int) -> Color:
	return Color(0.70, 0.70, 0.74) if faction == RANDOM_FACTION else FactionData.get_color(faction)

func _resolve_random_faction(excluded: Array[int]) -> int:
	var pool: Array[int] = []
	for faction_id: int in FactionData.get_all_faction_ids():
		if not excluded.has(faction_id):
			pool.append(faction_id)
	if pool.is_empty():
		pool = FactionData.get_all_faction_ids()
	return pool[randi() % pool.size()]

func _set_player_faction(player_id: int, faction: int) -> void:
	match player_id:
		1:
			_faction_p1 = faction
		2:
			_faction_p2 = faction
		3:
			_faction_p3 = faction
		4:
			_faction_p4 = faction

func _on_faction_selected(player: int, faction: int) -> void:
	_set_player_faction(player, faction)
	AudioManager.play_menu_button()
	_refresh_player_rows()

func _is_player_enabled(player_id: int) -> bool:
	match player_id:
		1, 2:
			return true
		3:
			return _player3_enabled
		4:
			return _player4_enabled
		_:
			return false

func _toggle_player_enabled(player_id: int) -> void:
	match player_id:
		3:
			_player3_enabled = not _player3_enabled
		4:
			_player4_enabled = not _player4_enabled
		_:
			return
	_refresh_player_rows()

func _cycle_player_mode(player_id: int) -> void:
	_player_modes[player_id] = "ai" if str(_player_modes.get(player_id, "human")) == "human" else "human"
	_refresh_player_rows()

func _refresh_player_rows() -> void:
	for player_id: int in [1, 2, 3, 4]:
		var enabled: bool = _is_player_enabled(player_id)
		var header: Label = _player_headers.get(player_id, null)
		if header != null:
			header.modulate.a = 1.0 if enabled else 0.42
		var subheader: Label = _player_subheaders.get(player_id, null)
		if subheader != null:
			var mode: String = str(_player_modes.get(player_id, "human"))
			subheader.text = ("Activo" if enabled else "Reservado") + "  •  " + ("Humano" if mode == "human" else "IA")
			subheader.modulate.a = 1.0 if enabled else 0.46
		var panel: Panel = _player_panels.get(player_id, null)
		if panel != null:
			panel.modulate.a = 1.0 if enabled else 0.34

		var enable_btn: Button = _player_enable_btns.get(player_id, null)
		if enable_btn != null:
			enable_btn.disabled = player_id <= 2
			enable_btn.text = "ON" if enabled else "OFF"
			var enable_normal := enable_btn.get_theme_stylebox("normal") as StyleBoxFlat
			if enable_normal != null:
				enable_normal.bg_color = Color(0.10, 0.18, 0.12, 0.95) if enabled else Color(0.12, 0.10, 0.10, 0.92)
				enable_normal.border_color = Color(0.36, 0.92, 0.44) if enabled else C_BORDER

		var faction_btn: OptionButton = _player_faction_btns.get(player_id, null)
		var faction: int = _get_player_faction(player_id)
		if faction_btn != null:
			for item_idx: int in range(faction_btn.item_count):
				if faction_btn.get_item_id(item_idx) == faction:
					faction_btn.select(item_idx)
					break
			faction_btn.disabled = not enabled
			faction_btn.add_theme_color_override("font_color", _get_faction_display_color(faction))

		var color_select: OptionButton = _player_color_selects.get(player_id, null)
		if color_select != null:
			var selected_color_idx: int = _player_color_idx.get(player_id, player_id - 1)
			color_select.select(clampi(selected_color_idx, 0, max(color_select.item_count - 1, 0)))
			color_select.disabled = not enabled
			color_select.add_theme_color_override("font_color", _get_player_setup_color(player_id))

		var mode_btn: Button = _player_mode_btns.get(player_id, null)
		var mode: String = str(_player_modes.get(player_id, "human"))
		if mode_btn != null:
			mode_btn.text = "Humano" if mode == "human" else "IA"
			mode_btn.disabled = not enabled
			var mode_normal := mode_btn.get_theme_stylebox("normal") as StyleBoxFlat
			if mode_normal != null:
				mode_normal.bg_color = Color(0.08, 0.12, 0.22, 0.95) if mode == "human" else Color(0.20, 0.12, 0.09, 0.95)
				mode_normal.border_color = Color(0.42, 0.88, 1.0) if mode == "human" else Color(0.88, 0.48, 0.96)

		var preview: HBoxContainer = _player_preview_rows.get(player_id, null)
		if preview != null:
			for child: Node in preview.get_children():
				child.queue_free()
			preview.modulate.a = 1.0 if enabled else 0.30
			if faction == RANDOM_FACTION:
				var random_lbl := Label.new()
				random_lbl.text = "?"
				random_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				random_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				random_lbl.custom_minimum_size = Vector2(54.0, 54.0)
				random_lbl.add_theme_font_size_override("font_size", 34)
				random_lbl.add_theme_color_override("font_color", Color(0.74, 0.74, 0.78, 0.96))
				preview.add_child(random_lbl)
			else:
				var path: String = FactionData.get_sprite_path(faction, -1)
				if ResourceLoader.exists(path):
					var tex: Texture2D = load(path)
					if tex != null:
						var portrait := TextureRect.new()
						portrait.texture = tex
						portrait.custom_minimum_size = Vector2(52, 52)
						portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
						portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
						portrait.modulate = Color(1.0, 1.0, 1.0, 0.98)
						preview.add_child(portrait)

		# ── Color circles: highlight selected, dim taken ──────────────────────────

		# ── Update row border and header to use chosen color ──────────────────────
		var chosen: Color = _get_player_setup_color(player_id)
		var hdr: Label = _player_headers.get(player_id, null)
		if hdr != null:
			hdr.add_theme_color_override("font_color", chosen)
		var row_panel: Panel = _player_panels.get(player_id, null)
		if row_panel != null:
			var rs: StyleBoxFlat = row_panel.get_theme_stylebox("panel") as StyleBoxFlat
			if rs != null:
				rs.border_color = Color(chosen.r, chosen.g, chosen.b, 0.22)
	_update_info_lbl()

func _get_player_setup_color(player_id: int) -> Color:
	return GameData.AVAILABLE_COLORS[_player_color_idx.get(player_id, player_id - 1)]

func _on_color_selected(player_id: int, color_idx: int) -> void:
	if color_idx < 0 or color_idx >= GameData.AVAILABLE_COLORS.size():
		return
	for other: int in [1, 2, 3, 4]:
		if other != player_id and _is_player_enabled(other) and _player_color_idx.get(other, other - 1) == color_idx:
			_refresh_player_rows()
			return  # color ya en uso por otro jugador habilitado
	_player_color_idx[player_id] = color_idx
	AudioManager.play_menu_button()
	_refresh_player_rows()

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
	var value: int = text.to_int()
	if value > 0:
		_seed = value
		_refresh_preview()

func _on_random_seed() -> void:
	_seed = randi() % 999999 + 1
	if _seed_input != null:
		_seed_input.text = str(_seed)
	_refresh_preview()

func _on_copy_seed() -> void:
	DisplayServer.clipboard_set(str(_seed))

func _apply_preset_duel() -> void:
	_player3_enabled = false
	_player4_enabled = false
	_player_modes[1] = "human"
	_player_modes[2] = "human"
	_player_modes[3] = "human"
	_player_modes[4] = "human"
	_faction_p1 = 0
	_faction_p2 = 1
	_assign_player_colors([0, 1, 2, 3])
	_type_idx = 0
	_size_idx = 1
	_on_random_seed()
	_refresh_player_rows()

func _apply_preset_trios() -> void:
	_player3_enabled = true
	_player4_enabled = false
	_player_modes[1] = "human"
	_player_modes[2] = "human"
	_player_modes[3] = "ai"
	_player_modes[4] = "human"
	_faction_p1 = 0
	_faction_p2 = 1
	_faction_p3 = 2
	_assign_player_colors([0, 1, 2, 3])
	_type_idx = 1
	_size_idx = 2
	_on_random_seed()
	_refresh_player_rows()

func _apply_preset_chaos() -> void:
	_player3_enabled = true
	_player4_enabled = true
	_player_modes[1] = "human"
	_player_modes[2] = "ai"
	_player_modes[3] = "ai"
	_player_modes[4] = "ai"
	_randomize_player_factions(true)
	_assign_player_colors(_shuffled_color_indices())
	_type_idx = randi() % MAP_TYPES.size()
	_size_idx = clampi(2 + (randi() % 2), 0, SIZE_NAMES.size() - 1)
	_on_random_seed()
	_refresh_player_rows()

func _randomize_setup() -> void:
	_randomize_player_factions(_player3_enabled or _player4_enabled)
	_assign_player_colors(_shuffled_color_indices())
	for player_id: int in [1, 2, 3, 4]:
		if player_id <= 2 or _is_player_enabled(player_id):
			_player_modes[player_id] = "human" if randf() < 0.5 else "ai"
	_type_idx = randi() % MAP_TYPES.size()
	_size_idx = randi() % SIZE_NAMES.size()
	_on_random_seed()
	_refresh_player_rows()

func _randomize_player_factions(include_extras: bool) -> void:
	var faction_ids: Array[int] = FactionData.get_all_faction_ids()
	if faction_ids.is_empty():
		return
	faction_ids.shuffle()
	_faction_p1 = faction_ids[0 % faction_ids.size()]
	_faction_p2 = faction_ids[1 % faction_ids.size()]
	_faction_p3 = faction_ids[2 % faction_ids.size()] if include_extras else _faction_p3
	_faction_p4 = faction_ids[3 % faction_ids.size()] if include_extras else _faction_p4

func _shuffled_color_indices() -> Array[int]:
	var indices: Array[int] = []
	for i: int in range(GameData.AVAILABLE_COLORS.size()):
		indices.append(i)
	indices.shuffle()
	return indices

func _assign_player_colors(indices: Array[int]) -> void:
	if indices.size() < 4:
		return
	_player_color_idx[1] = indices[0]
	_player_color_idx[2] = indices[1]
	_player_color_idx[3] = indices[2]
	_player_color_idx[4] = indices[3]

func _on_play() -> void:
	GameData.reset()
	var resolved_p1: int = _faction_p1 if _faction_p1 != RANDOM_FACTION else _resolve_random_faction([])
	var resolved_p2: int = _faction_p2 if _faction_p2 != RANDOM_FACTION else _resolve_random_faction([resolved_p1])
	var resolved_p3: int = _faction_p3 if _faction_p3 != RANDOM_FACTION else _resolve_random_faction([resolved_p1, resolved_p2])
	var resolved_p4: int = _faction_p4 if _faction_p4 != RANDOM_FACTION else _resolve_random_faction([resolved_p1, resolved_p2, resolved_p3])
	GameData.faction_p1 = resolved_p1
	GameData.faction_p2 = resolved_p2
	GameData.faction_p3 = resolved_p3
	GameData.faction_p4 = resolved_p4
	GameData.player3_enabled = _player3_enabled
	GameData.player4_enabled = _player4_enabled
	GameData.extra_players_enabled = _player3_enabled or _player4_enabled
	GameData.player_mode_p1 = str(_player_modes.get(1, "human"))
	GameData.player_mode_p2 = str(_player_modes.get(2, "human"))
	GameData.player_mode_p3 = str(_player_modes.get(3, "human"))
	GameData.player_mode_p4 = str(_player_modes.get(4, "human"))
	GameData.player_count = GameData.get_player_ids().size()
	for pid: int in [1, 2, 3, 4]:
		GameData.set_player_color(pid, _get_player_setup_color(pid))
	GameData.current_map = _type_idx
	GameData.map_seed = _seed
	GameData.map_size = SIZE_DIMS[_size_idx]
	GameData.map_terrain = []
	get_tree().change_scene_to_file("res://scenes/Main3D.tscn")

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/TitleScreen.tscn")

func _hex_pts(center: Vector2, radius: float, rot: float) -> Array[Vector2]:
	var pts: Array[Vector2] = []
	for i: int in range(6):
		var angle: float = rot + TAU * float(i) / 6.0
		pts.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return pts

func _init_particles(count: int) -> void:
	_particles.clear()
	_star_particles.clear()
	for _i: int in range(count):
		var angle: float = randf() * TAU
		var speed: float = randf_range(5.0, 16.0)
		_particles.append({
			"pos": Vector2(randf() * 1280.0, randf() * 720.0),
			"vel": Vector2(cos(angle), sin(angle)) * speed,
			"size": randf_range(8.0, 20.0),
			"alpha": randf_range(0.03, 0.10),
			"rot": randf() * TAU,
			"rot_spd": randf_range(-0.22, 0.22),
		})
	for _j: int in range(28):
		_star_particles.append({
			"pos": Vector2(randf_range(80.0, 1240.0), randf_range(24.0, 214.0)),
			"radius": randf_range(0.8, 1.7),
			"phase": randf() * TAU,
			"speed": randf_range(0.8, 2.2),
			"twinkle": randf(),
		})
