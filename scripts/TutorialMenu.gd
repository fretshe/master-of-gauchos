extends Control

const SCREEN_SIZE := Vector2(1280.0, 720.0)
const BG_TOP := Color(0.10, 0.07, 0.12, 1.0)
const BG_BOTTOM := Color(0.93, 0.58, 0.30, 1.0)
const SKY_HAZE := Color(1.0, 0.78, 0.58, 0.16)
const PANEL_BG := Color(0.08, 0.08, 0.12, 0.86)
const PANEL_BORDER := Color(0.92, 0.86, 0.66, 0.24)
const GOLD := Color(0.95, 0.79, 0.24, 1.0)
const CYAN := Color(0.38, 0.86, 1.0, 1.0)
const TEXT := Color(0.96, 0.95, 0.92, 1.0)
const DIM := Color(0.80, 0.76, 0.68, 0.82)
const BUTTON_IDLE := Color(0.12, 0.10, 0.10, 0.92)
const BUTTON_HOVER := Color(0.27, 0.18, 0.10, 0.96)
const BUTTON_DISABLED := Color(0.14, 0.14, 0.16, 0.76)
const BUTTON_BORDER := Color(0.96, 0.84, 0.46, 0.38)
const BUTTON_ACCENT := Color(0.94, 0.70, 0.18, 1.0)

const CHAPTERS := [
	{
		"id": "chapter_1",
		"title": "Capitulo 1",
		"subtitle": "Primeros pasos",
		"body": "Aprende a leer el tablero, capturar torres, invocar una unidad y lanzar tu primer ataque.",
		"status": "Disponible",
		"button": "Jugar",
		"enabled": true,
		"accent": Color(0.38, 0.86, 1.0, 1.0),
	},
	{
		"id": "chapter_2",
		"title": "Capitulo 2",
		"subtitle": "Invocación y counters",
		"body": "Profundiza en esencia, ventajas entre clases y decisiones de refuerzo para cada frente.",
		"status": "Disponible",
		"button": "Jugar",
		"enabled": true,
		"accent": Color(0.98, 0.78, 0.28, 1.0),
	},
	{
		"id": "chapter_3",
		"title": "Capitulo 3",
		"subtitle": "Cartas y presion tactica",
		"body": "Combina cartas, posicionamiento y control del mapa para cerrar una partida con criterio.",
		"status": "Disponible",
		"button": "Jugar",
		"enabled": true,
		"accent": Color(0.64, 0.92, 0.54, 1.0),
	},
]

var _chapter_buttons: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	GameData.load_meta()
	_build_ui()
	GameData.call_deferred("apply_selected_theme", get_window())
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.28)

func _draw() -> void:
	for i: int in range(14):
		var t: float = float(i) / 13.0
		var color := BG_TOP.lerp(BG_BOTTOM, pow(t, 1.6))
		draw_rect(Rect2(0.0, float(i) * size.y / 14.0, size.x, size.y / 14.0 + 2.0), color)
	draw_rect(Rect2(0.0, 0.0, size.x, size.y * 0.50), SKY_HAZE)

func _build_ui() -> void:
	var title := Label.new()
	title.text = "Tutorial"
	title.position = Vector2(0.0, 34.0)
	title.size = Vector2(1280.0, 46.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", GOLD)
	add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Tres capitulos para aprender las mecanicas con calma."
	subtitle.position = Vector2(0.0, 78.0)
	subtitle.size = Vector2(1280.0, 24.0)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", DIM)
	add_child(subtitle)

	var panel := Panel.new()
	panel.position = Vector2(90.0, 136.0)
	panel.size = Vector2(1100.0, 468.0)
	_apply_panel_style(panel, PANEL_BG, PANEL_BORDER)
	add_child(panel)

	var intro := Label.new()
	intro.text = "Este espacio concentra los mapas tutoriales hechos a mano. Ya puedes recorrer los tres capitulos base para aprender tablero, counters y cartas."
	intro.position = Vector2(28.0, 22.0)
	intro.size = Vector2(1044.0, 44.0)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_font_size_override("font_size", 15)
	intro.add_theme_color_override("font_color", DIM)
	panel.add_child(intro)

	for i: int in range(CHAPTERS.size()):
		var chapter: Dictionary = CHAPTERS[i]
		var card := _build_chapter_card(chapter)
		card.position = Vector2(28.0 + float(i) * 352.0, 92.0)
		panel.add_child(card)

	var back_btn := _make_menu_button("Volver al menu")
	back_btn.position = Vector2(90.0, 632.0)
	back_btn.custom_minimum_size = Vector2(256.0, 48.0)
	back_btn.pressed.connect(_on_back_pressed)
	back_btn.pressed.connect(AudioManager.play_menu_button)
	add_child(back_btn)

func _build_chapter_card(chapter: Dictionary) -> Panel:
	var card := Panel.new()
	card.size = Vector2(324.0, 332.0)
	var accent: Color = chapter.get("accent", CYAN)
	var chapter_id: String = str(chapter.get("id", ""))
	var completed: bool = GameData.is_tutorial_chapter_completed(chapter_id)
	_apply_panel_style(card, Color(0.09, 0.09, 0.12, 0.94), Color(accent.r, accent.g, accent.b, 0.30))

	var badge := ColorRect.new()
	badge.position = Vector2(20.0, 20.0)
	badge.size = Vector2(112.0, 28.0)
	badge.color = Color(0.20, 0.72, 0.34, 0.18) if completed else Color(accent.r, accent.g, accent.b, 0.14)
	card.add_child(badge)

	var status := Label.new()
	status.text = "Completado" if completed else str(chapter.get("status", ""))
	status.position = Vector2(20.0, 22.0)
	status.size = Vector2(140.0, 20.0)
	status.add_theme_font_size_override("font_size", 12)
	status.add_theme_color_override("font_color", Color(0.48, 1.0, 0.56, 1.0) if completed else accent)
	card.add_child(status)

	if completed:
		var check := Label.new()
		check.text = char(0x2713)
		check.position = Vector2(284.0, 18.0)
		check.size = Vector2(24.0, 24.0)
		check.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		check.add_theme_font_size_override("font_size", 22)
		check.add_theme_color_override("font_color", Color(0.48, 1.0, 0.56, 1.0))
		card.add_child(check)

	var title := Label.new()
	title.text = "%s\n%s" % [str(chapter.get("title", "")), str(chapter.get("subtitle", ""))]
	title.position = Vector2(20.0, 64.0)
	title.size = Vector2(284.0, 74.0)
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", TEXT)
	card.add_child(title)

	var body := Label.new()
	body.text = str(chapter.get("body", ""))
	body.position = Vector2(20.0, 152.0)
	body.size = Vector2(284.0, 84.0)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 15)
	body.add_theme_color_override("font_color", DIM)
	card.add_child(body)

	var map_hint := Label.new()
	map_hint.text = "Mapa guiado" if bool(chapter.get("enabled", false)) else "Mapa en preparacion"
	map_hint.position = Vector2(20.0, 246.0)
	map_hint.size = Vector2(180.0, 18.0)
	map_hint.add_theme_font_size_override("font_size", 13)
	map_hint.add_theme_color_override("font_color", accent)
	card.add_child(map_hint)

	var btn := _make_menu_button(str(chapter.get("button", "Abrir")))
	btn.position = Vector2(20.0, 276.0)
	btn.custom_minimum_size = Vector2(284.0, 40.0)
	btn.disabled = not bool(chapter.get("enabled", false))
	btn.pressed.connect(func(chapter_id := str(chapter.get("id", ""))): _on_chapter_pressed(chapter_id))
	btn.pressed.connect(AudioManager.play_menu_button)
	card.add_child(btn)
	_chapter_buttons[chapter_id] = btn

	return card

func _on_chapter_pressed(chapter_id: String) -> void:
	if chapter_id != "chapter_1" and chapter_id != "chapter_2" and chapter_id != "chapter_3":
		return
	GameData.clear_saved_match()
	GameData.reset()
	GameData.faction_p1 = 0
	GameData.faction_p2 = 1
	GameData.player_mode_p1 = "human"
	GameData.player_mode_p2 = "ai"
	GameData.player_count = 2
	GameData.current_map = 0
	if chapter_id == "chapter_2":
		GameData.map_seed = 24012
		GameData.map_size = Vector2i(8, 6)
	elif chapter_id == "chapter_3":
		GameData.map_seed = 34018
		GameData.map_size = Vector2i(8, 6)
	else:
		GameData.map_seed = 14026
		GameData.map_size = Vector2i(10, 8)
	GameData.map_terrain = []
	GameData.map_tower_positions = []
	GameData.map_tower_incomes = []
	GameData.tutorial_mode_active = true
	GameData.tutorial_chapter_id = chapter_id
	get_tree().change_scene_to_file("res://scenes/Main3D.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/TitleScreen.tscn")

func _make_menu_button(label_text: String) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(284.0, 48.0)
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var normal := StyleBoxFlat.new()
	normal.bg_color = BUTTON_IDLE
	normal.border_color = BUTTON_BORDER
	normal.set_corner_radius_all(8)
	normal.set_border_width_all(1)

	var hover := normal.duplicate()
	hover.bg_color = BUTTON_HOVER
	hover.border_color = Color(BUTTON_ACCENT.r, BUTTON_ACCENT.g, BUTTON_ACCENT.b, 0.62)

	var pressed := hover.duplicate()
	pressed.bg_color = Color(0.18, 0.12, 0.08, 0.98)

	var disabled := normal.duplicate()
	disabled.bg_color = BUTTON_DISABLED
	disabled.border_color = Color(0.70, 0.70, 0.76, 0.16)

	for state_name: String in ["normal", "focus"]:
		btn.add_theme_stylebox_override(state_name, normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", TEXT)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", Color(0.72, 0.72, 0.76, 0.42))
	return btn

func _apply_panel_style(panel: Panel, bg: Color, border: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
