extends Control

const SCREEN_SIZE := Vector2(1280.0, 720.0)
const TITLE_LOGO_PATH := "res://assets/sprites/title/game_logo.png"
const MENU_BACKGROUND_PATH := "res://assets/sprites/title/menu_background.png"
const PARALLAX_LAYER_PATHS := {
	"sky": "res://assets/sprites/title/parallax/sky.png",
	"clouds": "res://assets/sprites/title/parallax/clouds.png",
	"field": "res://assets/sprites/title/parallax/field.png",
	"gauchos": "res://assets/sprites/title/parallax/gauchos.png",
	"grass": "res://assets/sprites/title/parallax/grass.png",
	"trees": "res://assets/sprites/title/parallax/trees.png",
}
const PARALLAX_LAYER_DEPTHS := {
	"sky": 0.06,
	"clouds": 0.12,
	"field": 0.18,
	"gauchos": 0.26,
	"grass": 0.34,
	"trees": 0.42,
}
const BG_TOP := Color(0.10, 0.07, 0.12, 1.0)
const BG_BOTTOM := Color(0.93, 0.58, 0.30, 1.0)
const SKY_HAZE := Color(1.0, 0.78, 0.58, 0.16)
const PANEL_BG := Color(0.08, 0.08, 0.12, 0.82)
const PANEL_BORDER := Color(0.92, 0.86, 0.66, 0.22)
const GOLD := Color(0.95, 0.79, 0.24, 1.0)
const CYAN := Color(0.38, 0.86, 1.0, 1.0)
const TEXT := Color(0.96, 0.95, 0.92, 1.0)
const DIM := Color(0.80, 0.76, 0.68, 0.82)
const BUTTON_IDLE := Color(0.12, 0.10, 0.10, 0.92)
const BUTTON_HOVER := Color(0.27, 0.18, 0.10, 0.96)
const BUTTON_DISABLED := Color(0.14, 0.14, 0.16, 0.76)
const BUTTON_BORDER := Color(0.96, 0.84, 0.46, 0.38)
const BUTTON_ACCENT := Color(0.94, 0.70, 0.18, 1.0)

var _dust_particles: Array[Dictionary] = []
var _hex_particles: Array[Dictionary] = []
var _star_particles: Array[Dictionary] = []
var _shooting_stars: Array[Dictionary] = []
var _meteor_fragments: Array[Dictionary] = []
var _parallax_time: float = 0.0
var _parallax_mouse_offset: Vector2 = Vector2.ZERO
var _menu_shell: Control = null
var _background_rect: TextureRect = null
var _parallax_root: Control = null
var _parallax_layers: Dictionary = {}
var _left_panel: Panel = null
var _title_logo: TextureRect = null
var _menu_box: VBoxContainer = null
var _play_modes_panel: Control = null
var _footer_bar: HBoxContainer = null
var _unlock_overlay: Control = null
var _unlock_list: GridContainer = null
var _unlock_summary_label: Label = null
var _unlock_faction_selector: HBoxContainer = null
var _unlock_side_panel: Panel = null
var _unlock_selected_faction: int = FactionData.Faction.GAUCHOS
var _unlock_hover_card: Dictionary = {}
var _unlock_hover_is_base: bool = false
var _unlock_hover_unlock_id: String = ""
var _unlock_hover_progress: Dictionary = {}
var _patch_notes_overlay: Control = null
var _help_overlay: Control = null
var _options_overlay: Control = null
var _options_font_value_label: Label = null
var _options_font_modern_btn: Button = null
var _options_font_tiny_btn: Button = null
var _options_fullscreen_btn: Button = null
var _options_music_slider: HSlider = null
var _options_music_pct:    Label   = null
var _options_sfx_slider:   HSlider = null
var _options_sfx_pct:      Label   = null


func _get_help_glossary_bbcode() -> String:
	var glossary_script = load("res://scripts/HelpGlossary.gd")
	if glossary_script == null:
		return "[color=#ff8d8d]No se pudo cargar la ayuda.[/color]"
	if glossary_script.has_method("build_bbcode"):
		return str(glossary_script.call("build_bbcode"))
	return "[color=#ff8d8d]La ayuda no esta disponible por ahora.[/color]"


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	GameData.load_meta()
	GameData.apply_window_mode(get_window())
	randomize()
	_init_particles()
	_build_ui()
	GameData.call_deferred("apply_selected_theme", get_window())
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.42)
	MusicManager.play_menu_music()
	_update_layout()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_layout()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var screen_size: Vector2 = _screen_size()
		if screen_size != Vector2.ZERO:
			var mouse_pos: Vector2 = (event as InputEventMouseMotion).position
			var normalized: Vector2 = Vector2(
				(mouse_pos.x / screen_size.x) * 2.0 - 1.0,
				(mouse_pos.y / screen_size.y) * 2.0 - 1.0
			)
			_parallax_mouse_offset = normalized.clamp(Vector2(-1.0, -1.0), Vector2(1.0, 1.0))
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_P and _menu_shell != null:
		_menu_shell.visible = not _menu_shell.visible


func _process(delta: float) -> void:
	_parallax_time += delta
	_update_parallax_visuals()
	for particle: Dictionary in _dust_particles:
		var pos: Vector2 = particle["pos"]
		pos += particle["vel"] * delta
		var screen_size: Vector2 = _screen_size()
		if pos.x > screen_size.x + 90.0:
			pos.x = -90.0
		if pos.y < -40.0:
			pos.y = screen_size.y + 40.0
		elif pos.y > screen_size.y + 40.0:
			pos.y = -40.0
		particle["pos"] = pos
	for particle: Dictionary in _hex_particles:
		var pos: Vector2 = particle["pos"]
		pos.x += sin(_parallax_time * particle["speed"] + particle["phase"]) * delta * 6.0
		particle["rot"] = float(particle["rot"]) + float(particle["rot_speed"]) * delta
		particle["pos"] = pos
	for star: Dictionary in _star_particles:
		star["twinkle"] = 0.5 + 0.5 * sin(_parallax_time * star["speed"] + star["phase"])
	for meteor: Dictionary in _shooting_stars:
		var active: bool = bool(meteor["active"])
		if active:
			var pos: Vector2 = meteor["pos"]
			pos += meteor["vel"] * delta
			meteor["pos"] = pos
			meteor["life"] = float(meteor["life"]) - delta
			var screen_size: Vector2 = _screen_size()
			if float(meteor["life"]) <= 0.0 or pos.x > screen_size.x + 120.0 or pos.y > screen_size.y * 0.48:
				_spawn_meteor_fragments(pos, (meteor["vel"] as Vector2).normalized())
				_reset_shooting_star(meteor)
		else:
			meteor["delay"] = float(meteor["delay"]) - delta
			if float(meteor["delay"]) <= 0.0:
				_activate_shooting_star(meteor)
	for fragment: Dictionary in _meteor_fragments:
		if not bool(fragment["active"]):
			continue
		var frag_pos: Vector2 = fragment["pos"]
		frag_pos += fragment["vel"] * delta
		fragment["pos"] = frag_pos
		fragment["vel"] = (fragment["vel"] as Vector2) * 0.965
		fragment["life"] = float(fragment["life"]) - delta
		if float(fragment["life"]) <= 0.0:
			fragment["active"] = false
	queue_redraw()


func _draw() -> void:
	if not _parallax_layers.is_empty():
		return
	_draw_sky()
	_draw_stars()
	_draw_shooting_stars()
	_draw_meteor_fragments()
	_draw_hex_field()
	_draw_mountains()
	_draw_dust()
	_draw_horizon_glow()


func _build_ui() -> void:
	_menu_shell = Control.new()
	_menu_shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu_shell.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_menu_shell)

	_background_rect = TextureRect.new()
	_background_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_background_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_background_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var menu_bg_tex: Texture2D = load(MENU_BACKGROUND_PATH)
	if menu_bg_tex != null:
		_background_rect.texture = menu_bg_tex
	add_child(_background_rect)
	move_child(_background_rect, 0)
	_build_parallax_layers()

	_left_panel = Panel.new()
	_left_panel.position = Vector2(56.0, 44.0)
	_left_panel.size = Vector2(488.0, 628.0)
	_apply_panel_style(_left_panel, PANEL_BG, PANEL_BORDER)
	_menu_shell.add_child(_left_panel)
	_title_logo = TextureRect.new()
	_title_logo.position = Vector2(2.0, 6.0)
	_title_logo.size = Vector2(484.0, 230.0)
	_title_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_title_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_title_logo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_title_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title_logo_tex: Texture2D = load(TITLE_LOGO_PATH)
	if title_logo_tex != null:
		_title_logo.texture = title_logo_tex
	_left_panel.add_child(_title_logo)
	_menu_box = VBoxContainer.new()
	_menu_box.position = Vector2(44.0, 242.0)
	_menu_box.size = Vector2(400.0, 374.0)
	_menu_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_menu_box.add_theme_constant_override("separation", 8)
	_left_panel.add_child(_menu_box)

	var btn_new := _make_menu_button("Jugar")
	btn_new.add_theme_color_override("font_color", GOLD)
	btn_new.pressed.connect(_on_play_menu)
	btn_new.pressed.connect(AudioManager.play_menu_button)
	_bind_button_description(btn_new, "Elegi el modo de juego disponible.")
	_menu_box.add_child(btn_new)

	var btn_cont := _make_menu_button("Continuar")
	btn_cont.disabled = not GameData.has_saved_match()
	btn_cont.pressed.connect(_on_continue)
	btn_cont.pressed.connect(AudioManager.play_menu_button)
	_bind_button_description(btn_cont, "Retoma la ultima partida guardada con tu mapa y progreso actuales.")
	_menu_box.add_child(btn_cont)

	var btn_opts := _make_menu_button("Opciones")
	btn_opts.pressed.connect(_on_options)
	btn_opts.pressed.connect(AudioManager.play_menu_button)
	_bind_button_description(btn_opts, "Ajustes y accesos rapidos. Por ahora queda como punto de entrada futuro.")
	_menu_box.add_child(btn_opts)

	var btn_unlocks := _make_menu_button("Desbloqueos")
	btn_unlocks.pressed.connect(_on_unlocks)
	btn_unlocks.pressed.connect(AudioManager.play_menu_button)
	_bind_button_description(btn_unlocks, "Consulta tu progreso meta entre partidas y equipa mejoras permanentes.")
	_menu_box.add_child(btn_unlocks)

	var btn_help := _make_menu_button("Ayuda")
	btn_help.pressed.connect(_on_help)
	btn_help.pressed.connect(AudioManager.play_menu_button)
	_bind_button_description(btn_help, "Abre el glosario general de sistemas, facciones, cartas y combate.")
	_menu_box.add_child(btn_help)

	var btn_quit := _make_menu_button("Salir")
	btn_quit.pressed.connect(_on_quit)
	btn_quit.pressed.connect(AudioManager.play_menu_button)
	_bind_button_description(btn_quit, "Cierra el juego.")
	_menu_box.add_child(btn_quit)

	_build_play_modes_panel()
	_build_version_label()
	_build_options_overlay()
	_build_patch_notes_overlay()
	_build_help_overlay()
	_build_unlock_overlay()


func _build_version_label() -> void:
	_footer_bar = HBoxContainer.new()
	_footer_bar.position = Vector2(1038.0, 676.0)
	_footer_bar.size = Vector2(214.0, 28.0)
	_footer_bar.alignment = BoxContainer.ALIGNMENT_END
	_footer_bar.add_theme_constant_override("separation", 8)
	_menu_shell.add_child(_footer_bar)

	var version_label := Label.new()
	version_label.text = GameData.get_build_version_label()
	version_label.custom_minimum_size = Vector2(114.0, 28.0)
	version_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	version_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	version_label.add_theme_font_size_override("font_size", 14)
	version_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.88, 0.34))
	_footer_bar.add_child(version_label)

	var notes_btn := Button.new()
	notes_btn.text = "Notas"
	notes_btn.custom_minimum_size = Vector2(92.0, 28.0)
	notes_btn.focus_mode = Control.FOCUS_NONE
	notes_btn.tooltip_text = "Ver cambios y ajustes de la version actual"
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.10, 0.10, 0.12, 0.28)
	normal.border_color = Color(1.0, 0.92, 0.76, 0.18)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.18, 0.14, 0.10, 0.56)
	hover.border_color = Color(0.96, 0.84, 0.46, 0.52)
	var pressed := hover.duplicate()
	pressed.bg_color = Color(0.24, 0.16, 0.08, 0.72)
	for state_name: String in ["normal", "focus"]:
		notes_btn.add_theme_stylebox_override(state_name, normal)
	notes_btn.add_theme_stylebox_override("hover", hover)
	notes_btn.add_theme_stylebox_override("pressed", pressed)
	notes_btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.88, 0.62))
	notes_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.98, 0.90, 0.98))
	notes_btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.98, 0.90, 0.98))
	notes_btn.add_theme_font_size_override("font_size", 13)
	notes_btn.pressed.connect(_on_patch_notes_pressed)
	notes_btn.pressed.connect(AudioManager.play_menu_button)
	_footer_bar.add_child(notes_btn)

func _screen_size() -> Vector2:
	var rect: Rect2 = get_viewport_rect()
	return rect.size if rect.size != Vector2.ZERO else SCREEN_SIZE

func _update_layout() -> void:
	var screen_size: Vector2 = _screen_size()
	var scale_factor: float = minf(screen_size.x / SCREEN_SIZE.x, screen_size.y / SCREEN_SIZE.y)
	var scaled_size: Vector2 = SCREEN_SIZE * scale_factor
	var origin: Vector2 = (screen_size - scaled_size) * 0.5
	if _parallax_root != null:
		_parallax_root.position = Vector2.ZERO
		_parallax_root.size = screen_size
		_update_parallax_visuals()
	if _left_panel != null:
		_left_panel.scale = Vector2.ONE * scale_factor
		_left_panel.position = origin + Vector2(56.0, 44.0) * scale_factor
	if _footer_bar != null:
		_footer_bar.scale = Vector2.ONE * scale_factor
		_footer_bar.position = origin + Vector2(1038.0, 676.0) * scale_factor

func _build_parallax_layers() -> void:
	_parallax_root = Control.new()
	_parallax_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_parallax_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_parallax_root)
	move_child(_parallax_root, 1)

	var ordered_layers: Array[String] = ["sky", "clouds", "field", "gauchos", "grass", "trees"]
	var has_any_layer: bool = false
	for layer_name: String in ordered_layers:
		var texture_path: String = str(PARALLAX_LAYER_PATHS.get(layer_name, ""))
		if texture_path == "" or not ResourceLoader.exists(texture_path):
			continue
		var layer_rect := TextureRect.new()
		layer_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		layer_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		layer_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		layer_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer_rect.texture = load(texture_path)
		_parallax_root.add_child(layer_rect)
		_parallax_layers[layer_name] = layer_rect
		has_any_layer = true
	if has_any_layer and _background_rect != null:
		_background_rect.visible = false

func _update_parallax_visuals() -> void:
	if _parallax_root == null:
		return
	var screen_size: Vector2 = _screen_size()
	if screen_size == Vector2.ZERO:
		return
	var auto_sway: Vector2 = Vector2(
		sin(_parallax_time * 0.22) * 0.35,
		cos(_parallax_time * 0.18) * 0.18
	)
	var final_offset: Vector2 = _parallax_mouse_offset * 0.65 + auto_sway
	for layer_name: Variant in _parallax_layers.keys():
		var layer_rect: TextureRect = _parallax_layers[layer_name] as TextureRect
		if layer_rect == null:
			continue
		var depth: float = float(PARALLAX_LAYER_DEPTHS.get(str(layer_name), 0.1))
		var extra_margin: float = 48.0 + depth * 120.0
		layer_rect.position = Vector2(-extra_margin, -extra_margin)
		layer_rect.size = screen_size + Vector2.ONE * extra_margin * 2.0
		layer_rect.scale = Vector2.ONE
		layer_rect.rotation = 0.0
		layer_rect.modulate = Color.WHITE
		layer_rect.position += Vector2(
			final_offset.x * extra_margin * depth,
			final_offset.y * extra_margin * depth * 0.55
		)

func _build_patch_notes_overlay() -> void:
	var patch_notes: Dictionary = GameData.get_patch_notes()
	_patch_notes_overlay = Control.new()
	_patch_notes_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_patch_notes_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_patch_notes_overlay.visible = false
	add_child(_patch_notes_overlay)

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.02, 0.04, 0.86)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_patch_notes_overlay.add_child(bg)

	var panel := Panel.new()
	panel.position = Vector2(210.0, 70.0)
	panel.size = Vector2(860.0, 580.0)
	_apply_panel_style(panel, Color(0.07, 0.08, 0.11, 0.97), Color(0.96, 0.84, 0.46, 0.30))
	_patch_notes_overlay.add_child(panel)

	var title := Label.new()
	title.text = "Patch Notes"
	title.position = Vector2(28.0, 22.0)
	title.size = Vector2(220.0, 34.0)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", GOLD)
	panel.add_child(title)

	var version_lbl := Label.new()
	version_lbl.text = "%s  |  %s" % [str(patch_notes.get("version", "")), str(patch_notes.get("date", ""))]
	version_lbl.position = Vector2(30.0, 60.0)
	version_lbl.size = Vector2(360.0, 20.0)
	version_lbl.add_theme_font_size_override("font_size", 14)
	version_lbl.add_theme_color_override("font_color", CYAN)
	panel.add_child(version_lbl)

	var subtitle := Label.new()
	subtitle.text = str(patch_notes.get("title", ""))
	subtitle.position = Vector2(30.0, 86.0)
	subtitle.size = Vector2(640.0, 24.0)
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", TEXT)
	panel.add_child(subtitle)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(28.0, 126.0)
	scroll.size = Vector2(804.0, 376.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 18)
	scroll.add_child(content)

	for section_value: Variant in patch_notes.get("sections", []):
		if not (section_value is Dictionary):
			continue
		var section: Dictionary = section_value as Dictionary
		content.add_child(_build_patch_notes_section(section))

	var hint := Label.new()
	hint.text = "Estas notas resumen los cambios mas visibles de la build actual."
	hint.position = Vector2(30.0, 534.0)
	hint.size = Vector2(520.0, 18.0)
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", DIM)
	panel.add_child(hint)

	var close_btn := _make_menu_button("Cerrar")
	close_btn.position = Vector2(430.0, 522.0)
	close_btn.size = Vector2(220.0, 36.0)
	close_btn.custom_minimum_size = Vector2(220.0, 36.0)
	close_btn.pressed.connect(_close_patch_notes)
	close_btn.pressed.connect(AudioManager.play_menu_button)
	panel.add_child(close_btn)

func _build_patch_notes_section(section: Dictionary) -> Panel:
	var items: Array = section.get("items", [])
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(780.0, 92.0 + float(items.size()) * 24.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.10, 0.14, 0.88)
	style.border_color = Color(1.0, 1.0, 1.0, 0.08)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)

	var section_title := Label.new()
	section_title.text = str(section.get("title", ""))
	section_title.position = Vector2(18.0, 14.0)
	section_title.size = Vector2(320.0, 22.0)
	section_title.add_theme_font_size_override("font_size", 20)
	section_title.add_theme_color_override("font_color", GOLD)
	panel.add_child(section_title)

	var y: float = 46.0
	for item_value: Variant in items:
		var item_label := Label.new()
		item_label.text = "- %s" % str(item_value)
		item_label.position = Vector2(18.0, y)
		item_label.size = Vector2(736.0, 22.0)
		item_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		item_label.add_theme_font_size_override("font_size", 14)
		item_label.add_theme_color_override("font_color", TEXT)
		panel.add_child(item_label)
		y += 24.0

	return panel

func _on_patch_notes_pressed() -> void:
	if _patch_notes_overlay != null:
		_patch_notes_overlay.visible = true

func _close_patch_notes() -> void:
	if _patch_notes_overlay != null:
		_patch_notes_overlay.visible = false

func _build_help_overlay() -> void:
	_help_overlay = Control.new()
	_help_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_help_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_help_overlay.visible = false
	add_child(_help_overlay)

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.02, 0.04, 0.88)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_help_overlay.add_child(bg)

	var panel := Panel.new()
	panel.position = Vector2(170.0, 44.0)
	panel.size = Vector2(940.0, 652.0)
	_apply_panel_style(panel, Color(0.07, 0.08, 0.11, 0.98), Color(0.96, 0.84, 0.46, 0.30))
	_help_overlay.add_child(panel)

	var title := Label.new()
	title.text = "Ayuda y glosario"
	title.position = Vector2(28.0, 22.0)
	title.size = Vector2(320.0, 34.0)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", GOLD)
	panel.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Resumen ordenado de sistemas, combate, dados, facciones, cartas y objetivos."
	subtitle.position = Vector2(30.0, 60.0)
	subtitle.size = Vector2(760.0, 22.0)
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", DIM)
	panel.add_child(subtitle)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(28.0, 102.0)
	scroll.size = Vector2(884.0, 472.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	var glossary_text := RichTextLabel.new()
	glossary_text.bbcode_enabled = true
	glossary_text.fit_content = true
	glossary_text.scroll_active = false
	glossary_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	glossary_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	glossary_text.custom_minimum_size = Vector2(860.0, 0.0)
	glossary_text.text = _get_help_glossary_bbcode()
	glossary_text.add_theme_font_size_override("normal_font_size", 16)
	scroll.add_child(glossary_text)

	var hint := Label.new()
	hint.text = "Podes abrir esta ayuda tanto desde el menu principal como desde la pausa en partida."
	hint.position = Vector2(30.0, 586.0)
	hint.size = Vector2(640.0, 18.0)
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", DIM)
	panel.add_child(hint)

	var close_btn := _make_menu_button("Cerrar")
	close_btn.position = Vector2(360.0, 608.0)
	close_btn.size = Vector2(220.0, 36.0)
	close_btn.custom_minimum_size = Vector2(220.0, 36.0)
	close_btn.pressed.connect(_close_help)
	close_btn.pressed.connect(AudioManager.play_menu_button)
	panel.add_child(close_btn)

func _on_help() -> void:
	if _help_overlay != null:
		_help_overlay.visible = true

func _close_help() -> void:
	if _help_overlay != null:
		_help_overlay.visible = false

func _build_options_overlay() -> void:
	_options_overlay = Control.new()
	_options_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_options_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_options_overlay.visible = false
	add_child(_options_overlay)

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.02, 0.04, 0.84)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_options_overlay.add_child(bg)

	var panel := Panel.new()
	panel.position = Vector2(272.0, 40.0)
	panel.size = Vector2(740.0, 660.0)
	_apply_panel_style(panel, Color(0.07, 0.08, 0.11, 0.97), Color(0.96, 0.84, 0.46, 0.30))
	_options_overlay.add_child(panel)

	var title := Label.new()
	title.text = "Opciones"
	title.position = Vector2(28.0, 24.0)
	title.size = Vector2(220.0, 34.0)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", GOLD)
	panel.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Ajusta fuente y pantalla para priorizar legibilidad o comodidad."
	subtitle.position = Vector2(30.0, 64.0)
	subtitle.size = Vector2(660.0, 22.0)
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", DIM)
	panel.add_child(subtitle)

	var font_panel := Panel.new()
	font_panel.position = Vector2(28.0, 112.0)
	font_panel.size = Vector2(684.0, 214.0)
	_apply_panel_style(font_panel, Color(0.10, 0.10, 0.14, 0.88), Color(1.0, 1.0, 1.0, 0.08))
	panel.add_child(font_panel)

	var font_title := Label.new()
	font_title.text = "Fuente del juego"
	font_title.position = Vector2(18.0, 16.0)
	font_title.size = Vector2(240.0, 24.0)
	font_title.add_theme_font_size_override("font_size", 22)
	font_title.add_theme_color_override("font_color", GOLD)
	font_panel.add_child(font_title)

	_options_font_value_label = Label.new()
	_options_font_value_label.position = Vector2(18.0, 52.0)
	_options_font_value_label.size = Vector2(320.0, 20.0)
	_options_font_value_label.add_theme_font_size_override("font_size", 16)
	_options_font_value_label.add_theme_color_override("font_color", CYAN)
	font_panel.add_child(_options_font_value_label)

	var preview := Label.new()
	preview.text = "Vista previa: Summoners of the Andes"
	preview.position = Vector2(18.0, 86.0)
	preview.size = Vector2(460.0, 26.0)
	preview.add_theme_font_size_override("font_size", 18)
	preview.add_theme_color_override("font_color", TEXT)
	font_panel.add_child(preview)

	var help := Label.new()
	help.text = "Pixel prioriza estilo retro. Normal mejora lectura general en menus y paneles."
	help.position = Vector2(18.0, 118.0)
	help.size = Vector2(640.0, 22.0)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_font_size_override("font_size", 13)
	help.add_theme_color_override("font_color", DIM)
	font_panel.add_child(help)

	var font_actions := HBoxContainer.new()
	font_actions.position = Vector2(18.0, 164.0)
	font_actions.size = Vector2(648.0, 34.0)
	font_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	font_actions.add_theme_constant_override("separation", 18)
	font_panel.add_child(font_actions)

	_options_font_modern_btn = _make_compact_button("Usar Normal", Vector2(250.0, 34.0), 18)
	_options_font_modern_btn.pressed.connect(func(): _on_options_set_font_pressed("normal"))
	_options_font_modern_btn.pressed.connect(AudioManager.play_menu_button)
	font_actions.add_child(_options_font_modern_btn)

	_options_font_tiny_btn = _make_compact_button("Usar Pixel", Vector2(250.0, 34.0), 18)
	_options_font_tiny_btn.pressed.connect(func(): _on_options_set_font_pressed("pixel"))
	_options_font_tiny_btn.pressed.connect(AudioManager.play_menu_button)
	font_actions.add_child(_options_font_tiny_btn)

	var screen_panel := Panel.new()
	screen_panel.position = Vector2(28.0, 344.0)
	screen_panel.size = Vector2(684.0, 100.0)
	_apply_panel_style(screen_panel, Color(0.10, 0.10, 0.14, 0.88), Color(1.0, 1.0, 1.0, 0.08))
	panel.add_child(screen_panel)

	var screen_title := Label.new()
	screen_title.text = "Pantalla"
	screen_title.position = Vector2(18.0, 16.0)
	screen_title.size = Vector2(240.0, 24.0)
	screen_title.add_theme_font_size_override("font_size", 22)
	screen_title.add_theme_color_override("font_color", GOLD)
	screen_panel.add_child(screen_title)

	var screen_help := Label.new()
	screen_help.text = "Activa o desactiva el modo pantalla completa."
	screen_help.position = Vector2(18.0, 46.0)
	screen_help.size = Vector2(420.0, 18.0)
	screen_help.add_theme_font_size_override("font_size", 13)
	screen_help.add_theme_color_override("font_color", DIM)
	screen_panel.add_child(screen_help)

	_options_fullscreen_btn = _make_compact_button("Pantalla completa: OFF", Vector2(250.0, 36.0), 18)
	_options_fullscreen_btn.position = Vector2(412.0, 32.0)
	_options_fullscreen_btn.pressed.connect(_on_options_toggle_fullscreen_pressed)
	_options_fullscreen_btn.pressed.connect(AudioManager.play_menu_button)
	screen_panel.add_child(_options_fullscreen_btn)

	# â”€â”€â”€ Audio â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
	var audio_panel := Panel.new()
	audio_panel.position = Vector2(28.0, 460.0)
	audio_panel.size = Vector2(684.0, 124.0)
	_apply_panel_style(audio_panel, Color(0.10, 0.10, 0.14, 0.88), Color(1.0, 1.0, 1.0, 0.08))
	panel.add_child(audio_panel)

	var audio_title := Label.new()
	audio_title.text = "Audio"
	audio_title.position = Vector2(18.0, 14.0)
	audio_title.size = Vector2(180.0, 24.0)
	audio_title.add_theme_font_size_override("font_size", 22)
	audio_title.add_theme_color_override("font_color", GOLD)
	audio_panel.add_child(audio_title)

	_options_music_slider = _build_volume_row(audio_panel, "Música",  56.0, SettingsManager.music_volume)
	_options_music_pct    = audio_panel.get_child(audio_panel.get_child_count() - 1) as Label
	_options_music_slider.value_changed.connect(func(v: float) -> void:
		SettingsManager.set_music_volume(v)
		if _options_music_pct != null:
			_options_music_pct.text = "%d%%" % roundi(v * 100.0)
	)

	_options_sfx_slider = _build_volume_row(audio_panel, "Efectos", 88.0, SettingsManager.sfx_volume)
	_options_sfx_pct    = audio_panel.get_child(audio_panel.get_child_count() - 1) as Label
	_options_sfx_slider.value_changed.connect(func(v: float) -> void:
		SettingsManager.set_sfx_volume(v)
		if _options_sfx_pct != null:
			_options_sfx_pct.text = "%d%%" % roundi(v * 100.0)
	)

	var close_btn := _make_compact_button("Cerrar", Vector2(316.0, 40.0), 20)
	close_btn.position = Vector2(212.0, 598.0)
	close_btn.pressed.connect(func(): _options_overlay.visible = false)
	close_btn.pressed.connect(AudioManager.play_menu_button)
	panel.add_child(close_btn)

	_refresh_options_overlay()

func _build_volume_row(parent: Control, label_text: String, y: float, initial: float) -> HSlider:
	var lbl := Label.new()
	lbl.text = label_text
	lbl.position = Vector2(18.0, y)
	lbl.size = Vector2(78.0, 20.0)
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", TEXT)
	parent.add_child(lbl)

	var slider := HSlider.new()
	slider.position = Vector2(102.0, y + 2.0)
	slider.size = Vector2(480.0, 16.0)
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = initial
	slider.focus_mode = Control.FOCUS_NONE
	parent.add_child(slider)

	var pct := Label.new()
	pct.text = "%d%%" % roundi(initial * 100.0)
	pct.position = Vector2(590.0, y)
	pct.size = Vector2(58.0, 20.0)
	pct.add_theme_font_size_override("font_size", 16)
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pct.add_theme_color_override("font_color", CYAN)
	parent.add_child(pct)
	return slider

func _refresh_options_overlay() -> void:
	if _options_font_value_label != null:
		_options_font_value_label.text = "Actual: %s" % GameData.get_selected_font_label()
	if _options_font_modern_btn != null:
		var modern_active: bool = GameData.get_selected_font_id() == "normal"
		_options_font_modern_btn.text = "Activa: %s" % GameData.get_font_label("normal") if modern_active else "Usar %s" % GameData.get_font_label("normal")
		_options_font_modern_btn.disabled = modern_active
	if _options_font_tiny_btn != null:
		var tiny_active: bool = GameData.get_selected_font_id() == "pixel"
		_options_font_tiny_btn.text = "Activa: %s" % GameData.get_font_label("pixel") if tiny_active else "Usar %s" % GameData.get_font_label("pixel")
		_options_font_tiny_btn.disabled = tiny_active
	if _options_fullscreen_btn != null:
		_options_fullscreen_btn.text = "Pantalla completa: ON" if GameData.is_fullscreen_enabled() else "Pantalla completa: OFF"
	if _options_music_slider != null:
		_options_music_slider.value = SettingsManager.music_volume
		if _options_music_pct != null:
			_options_music_pct.text = "%d%%" % roundi(SettingsManager.music_volume * 100.0)
	if _options_sfx_slider != null:
		_options_sfx_slider.value = SettingsManager.sfx_volume
		if _options_sfx_pct != null:
			_options_sfx_pct.text = "%d%%" % roundi(SettingsManager.sfx_volume * 100.0)

func _on_options_set_font_pressed(font_id: String) -> void:
	if GameData.get_selected_font_id() == font_id:
		_refresh_options_overlay()
		return
	GameData.set_selected_font_id(font_id)
	GameData.apply_selected_theme(get_window())
	var scene_path: String = ""
	if get_tree() != null and get_tree().current_scene != null:
		scene_path = str(get_tree().current_scene.scene_file_path)
	if scene_path != "":
		get_tree().change_scene_to_file(scene_path)
	else:
		get_tree().reload_current_scene()

func _on_options_toggle_fullscreen_pressed() -> void:
	GameData.toggle_fullscreen_enabled()
	GameData.apply_window_mode(get_window())
	_update_layout()
	_refresh_options_overlay()


func _make_menu_button(label_text: String) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(412.0, 54.0)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 21)
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = BUTTON_IDLE
	style_normal.border_color = BUTTON_BORDER
	style_normal.set_border_width_all(1)
	style_normal.set_corner_radius_all(4)
	var style_hover := style_normal.duplicate()
	style_hover.bg_color = BUTTON_HOVER
	style_hover.border_color = Color(BUTTON_ACCENT.r, BUTTON_ACCENT.g, BUTTON_ACCENT.b, 0.72)
	var style_pressed := style_hover.duplicate()
	style_pressed.bg_color = Color(0.34, 0.20, 0.08, 0.96)
	var style_disabled := style_normal.duplicate()
	style_disabled.bg_color = BUTTON_DISABLED
	style_disabled.border_color = Color(1.0, 1.0, 1.0, 0.10)
	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_pressed)
	btn.add_theme_stylebox_override("disabled", style_disabled)
	btn.add_theme_color_override("font_color", TEXT)
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.97, 0.88, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.98, 0.90, 1.0))
	btn.add_theme_color_override("font_disabled_color", Color(0.62, 0.62, 0.66, 1.0))
	return btn

func _make_compact_button(label_text: String, min_size: Vector2, font_size: int) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = min_size
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", font_size)
	var normal := StyleBoxFlat.new()
	normal.bg_color = BUTTON_IDLE
	normal.border_color = BUTTON_BORDER
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	var hover := normal.duplicate()
	hover.bg_color = BUTTON_HOVER
	hover.border_color = Color(BUTTON_ACCENT.r, BUTTON_ACCENT.g, BUTTON_ACCENT.b, 0.72)
	var pressed := hover.duplicate()
	pressed.bg_color = Color(0.34, 0.20, 0.08, 0.96)
	var disabled := normal.duplicate()
	disabled.bg_color = BUTTON_DISABLED
	disabled.border_color = Color(1.0, 1.0, 1.0, 0.10)
	for state_name: String in ["normal", "focus"]:
		btn.add_theme_stylebox_override(state_name, normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", TEXT)
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.97, 0.88, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.98, 0.90, 1.0))
	btn.add_theme_color_override("font_disabled_color", Color(0.62, 0.62, 0.66, 1.0))
	return btn

func _make_mode_button(label_text: String, blocked: bool = false) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(412.0, 56.0)
	btn.size = btn.custom_minimum_size
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 24)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.13, 0.10, 0.10, 0.96) if not blocked else Color(0.18, 0.18, 0.20, 0.92)
	normal.border_color = Color(BUTTON_ACCENT.r, BUTTON_ACCENT.g, BUTTON_ACCENT.b, 0.60) if not blocked else Color(1.0, 1.0, 1.0, 0.12)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(6)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.30, 0.18, 0.10, 0.98) if not blocked else Color(0.20, 0.20, 0.22, 0.92)
	hover.border_color = Color(BUTTON_ACCENT.r, BUTTON_ACCENT.g, BUTTON_ACCENT.b, 0.85) if not blocked else Color(1.0, 1.0, 1.0, 0.14)
	var pressed := hover.duplicate()
	pressed.bg_color = Color(0.36, 0.20, 0.08, 0.98) if not blocked else Color(0.18, 0.18, 0.20, 0.92)
	var disabled := normal.duplicate()
	disabled.bg_color = Color(0.18, 0.18, 0.20, 0.92)
	disabled.border_color = Color(1.0, 1.0, 1.0, 0.12)
	for state_name: String in ["normal", "focus"]:
		btn.add_theme_stylebox_override(state_name, normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", GOLD if not blocked else Color(0.70, 0.70, 0.74, 1.0))
	btn.add_theme_color_override("font_hover_color", TEXT if not blocked else Color(0.70, 0.70, 0.74, 1.0))
	btn.add_theme_color_override("font_pressed_color", TEXT if not blocked else Color(0.70, 0.70, 0.74, 1.0))
	btn.add_theme_color_override("font_disabled_color", Color(0.70, 0.70, 0.74, 1.0))
	btn.disabled = blocked
	return btn


func _bind_button_description(button: Button, description: String) -> void:
	button.tooltip_text = description


func _apply_panel_style(panel: Panel, bg_color: Color, border_color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)

func _build_play_modes_panel() -> void:
	_play_modes_panel = Control.new()
	_play_modes_panel.position = Vector2(44.0, 184.0)
	_play_modes_panel.size = Vector2(412.0, 374.0)
	_play_modes_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	_play_modes_panel.visible = false
	_left_panel.add_child(_play_modes_panel)

	var back_btn := _make_compact_button("Volver", Vector2(104.0, 28.0), 14)
	back_btn.position = Vector2(154.0, 346.0)
	back_btn.pressed.connect(_on_back_from_play_menu)
	back_btn.pressed.connect(AudioManager.play_menu_button)
	_bind_button_description(back_btn, "Regresa al menu principal.")
	_play_modes_panel.add_child(back_btn)

	var title := Label.new()
	title.text = "Modos de juego"
	title.position = Vector2(0.0, 0.0)
	title.size = Vector2(412.0, 28.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", TEXT)
	_play_modes_panel.add_child(title)

	var campaign_btn := _make_mode_button("Campaña", true)
	campaign_btn.position = Vector2(0.0, 40.0)
	_bind_button_description(campaign_btn, "Proximamente.")
	_play_modes_panel.add_child(campaign_btn)

	var campaign_note := Label.new()
	campaign_note.text = "Proximamente"
	campaign_note.position = Vector2(0.0, 98.0)
	campaign_note.size = Vector2(412.0, 16.0)
	campaign_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	campaign_note.add_theme_font_size_override("font_size", 12)
	campaign_note.add_theme_color_override("font_color", Color(0.66, 0.66, 0.70, 0.95))
	_play_modes_panel.add_child(campaign_note)

	var quick_btn := _make_mode_button("Partida rápida")
	quick_btn.position = Vector2(0.0, 120.0)
	quick_btn.pressed.connect(_on_quick_match)
	quick_btn.pressed.connect(AudioManager.play_menu_button)
	_bind_button_description(quick_btn, "Abre el menu de nueva partida.")
	_play_modes_panel.add_child(quick_btn)

	var challenge_btn := _make_mode_button("Desafío", true)
	challenge_btn.position = Vector2(0.0, 200.0)
	_bind_button_description(challenge_btn, "Proximamente.")
	_play_modes_panel.add_child(challenge_btn)

	var challenge_note := Label.new()
	challenge_note.text = "Proximamente"
	challenge_note.position = Vector2(0.0, 258.0)
	challenge_note.size = Vector2(412.0, 16.0)
	challenge_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	challenge_note.add_theme_font_size_override("font_size", 12)
	challenge_note.add_theme_color_override("font_color", Color(0.66, 0.66, 0.70, 0.95))
	_play_modes_panel.add_child(challenge_note)

	var tutorial_btn := _make_menu_button("Tutorial")
	tutorial_btn.custom_minimum_size = Vector2(412.0, 44.0)
	tutorial_btn.size = tutorial_btn.custom_minimum_size
	tutorial_btn.position = Vector2(0.0, 282.0)
	tutorial_btn.pressed.connect(_on_tutorial)
	tutorial_btn.pressed.connect(AudioManager.play_menu_button)
	_bind_button_description(tutorial_btn, "Accede a capitulos guiados para aprender combate, economia e invocacion paso a paso.")
	_play_modes_panel.add_child(tutorial_btn)


func _draw_sky() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG_BOTTOM)
	for i: int in range(14):
		var t: float = float(i) / 13.0
		var color := BG_TOP.lerp(BG_BOTTOM, pow(t, 1.6))
		color.a = 1.0
		draw_rect(Rect2(0.0, float(i) * size.y / 14.0, size.x, size.y / 14.0 + 2.0), color)
	draw_rect(Rect2(0.0, 0.0, size.x, size.y * 0.48), SKY_HAZE)


func _draw_hex_field() -> void:
	for particle: Dictionary in _hex_particles:
		var pts: Array[Vector2] = _hex_points(particle["pos"], particle["radius"], particle["rot"])
		var packed := PackedVector2Array(pts)
		packed.append(pts[0])
		draw_polyline(packed, Color(0.70, 0.56, 0.26, particle["alpha"]), 1.0)

func _draw_stars() -> void:
	for star: Dictionary in _star_particles:
		var alpha: float = lerpf(0.08, 0.42, float(star["twinkle"]))
		draw_circle(star["pos"], star["radius"], Color(1.0, 0.94, 0.76, alpha))


func _draw_shooting_stars() -> void:
	for meteor: Dictionary in _shooting_stars:
		if not bool(meteor["active"]):
			continue
		var pos: Vector2 = meteor["pos"]
		var dir: Vector2 = (meteor["vel"] as Vector2).normalized()
		var trail_len: float = float(meteor["trail_len"])
		var tail: Vector2 = pos - dir * trail_len
		var life_ratio: float = clampf(float(meteor["life"]) / float(meteor["max_life"]), 0.0, 1.0)
		var glow: float = sin((1.0 - life_ratio) * PI)
		var alpha: float = clampf(life_ratio * 0.7 + glow * 0.6, 0.0, 1.0)
		draw_line(tail, pos, Color(0.34, 0.88, 1.0, 0.10 * alpha), 12.0)
		draw_line(tail, pos, Color(0.42, 0.94, 1.0, 0.22 * alpha), 8.0)
		draw_line(tail, pos, Color(0.54, 0.98, 1.0, 0.42 * alpha), 4.0)
		draw_circle(pos, 14.0, Color(0.24, 0.86, 1.0, 0.08 * alpha))
		draw_circle(pos, 8.0, Color(0.40, 0.94, 1.0, 0.18 * alpha))
		draw_circle(pos, 3.4, Color(0.82, 1.0, 1.0, 0.92 * alpha))


func _draw_meteor_fragments() -> void:
	for fragment: Dictionary in _meteor_fragments:
		if not bool(fragment["active"]):
			continue
		var alpha: float = clampf(float(fragment["life"]) / float(fragment["max_life"]), 0.0, 1.0)
		var pos: Vector2 = fragment["pos"]
		draw_circle(pos, float(fragment["radius"]) * 2.2, Color(0.28, 0.88, 1.0, 0.06 * alpha))
		draw_circle(pos, float(fragment["radius"]), Color(0.72, 1.0, 1.0, 0.62 * alpha))


func _draw_mountains() -> void:
	var ridge_back := PackedVector2Array([
		Vector2(0.0, 430.0),
		Vector2(90.0, 392.0),
		Vector2(190.0, 416.0),
		Vector2(320.0, 350.0),
		Vector2(462.0, 378.0),
		Vector2(608.0, 312.0),
		Vector2(780.0, 352.0),
		Vector2(948.0, 286.0),
		Vector2(1114.0, 336.0),
		Vector2(1280.0, 282.0),
		Vector2(1280.0, 720.0),
		Vector2(0.0, 720.0),
	])
	draw_colored_polygon(ridge_back, Color(0.35, 0.20, 0.14, 0.78))

	var ridge_mid := PackedVector2Array([
		Vector2(0.0, 510.0),
		Vector2(134.0, 474.0),
		Vector2(252.0, 528.0),
		Vector2(402.0, 452.0),
		Vector2(564.0, 496.0),
		Vector2(730.0, 430.0),
		Vector2(876.0, 472.0),
		Vector2(1048.0, 420.0),
		Vector2(1184.0, 458.0),
		Vector2(1280.0, 430.0),
		Vector2(1280.0, 720.0),
		Vector2(0.0, 720.0),
	])
	draw_colored_polygon(ridge_mid, Color(0.26, 0.18, 0.12, 0.92))

	var ridge_front := PackedVector2Array([
		Vector2(0.0, 592.0),
		Vector2(154.0, 566.0),
		Vector2(316.0, 602.0),
		Vector2(488.0, 548.0),
		Vector2(692.0, 594.0),
		Vector2(884.0, 532.0),
		Vector2(1050.0, 584.0),
		Vector2(1280.0, 558.0),
		Vector2(1280.0, 720.0),
		Vector2(0.0, 720.0),
	])
	draw_colored_polygon(ridge_front, Color(0.15, 0.14, 0.10, 1.0))

	_draw_far_tower(Vector2(624.0, 500.0), 0.64, Color(0.92, 0.85, 0.74, 0.44))
	_draw_far_tower(Vector2(702.0, 468.0), 0.82, Color(0.92, 0.85, 0.74, 0.56))
	_draw_far_tower(Vector2(786.0, 520.0), 0.58, Color(0.90, 0.83, 0.72, 0.38))
	_draw_far_tower(Vector2(872.0, 478.0), 0.76, Color(0.92, 0.85, 0.74, 0.50))
	_draw_far_tower(Vector2(958.0, 514.0), 0.60, Color(0.90, 0.83, 0.72, 0.40))
	_draw_far_tower(Vector2(1044.0, 474.0), 0.88, Color(0.92, 0.85, 0.74, 0.60))
	_draw_far_tower(Vector2(1128.0, 502.0), 0.70, Color(0.90, 0.83, 0.72, 0.46))


func _draw_dust() -> void:
	for particle: Dictionary in _dust_particles:
		draw_circle(particle["pos"], particle["radius"], Color(1.0, 0.84, 0.56, particle["alpha"]))


func _draw_horizon_glow() -> void:
	draw_rect(Rect2(0.0, 468.0, size.x, 64.0), Color(1.0, 0.76, 0.42, 0.10))


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

	var shade := Color(color.r * 0.70, color.g * 0.70, color.b * 0.74, color.a * 0.75)
	draw_rect(Rect2(base_pos.x + shaft_w * 0.06, base_pos.y - shaft_h, shaft_w * 0.26, shaft_h - base_h), shade)


func _hex_points(center: Vector2, radius: float, rotation: float) -> Array[Vector2]:
	var pts: Array[Vector2] = []
	for i: int in range(6):
		var angle: float = rotation + TAU * float(i) / 6.0
		pts.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return pts


func _init_particles() -> void:
	_dust_particles.clear()
	_hex_particles.clear()
	_star_particles.clear()
	_shooting_stars.clear()
	_meteor_fragments.clear()
	var screen_size: Vector2 = _screen_size()
	for _i: int in range(28):
		_dust_particles.append({
			"pos": Vector2(randf_range(-40.0, screen_size.x + 40.0), randf_range(120.0, screen_size.y - 10.0)),
			"vel": Vector2(randf_range(18.0, 42.0), randf_range(-2.0, 2.0)),
			"radius": randf_range(1.4, 3.6),
			"alpha": randf_range(0.05, 0.16),
		})
	for _j: int in range(22):
		_hex_particles.append({
			"pos": Vector2(randf_range(560.0, 1240.0), randf_range(54.0, 324.0)),
			"radius": randf_range(10.0, 22.0),
			"rot": randf_range(0.0, TAU),
			"rot_speed": randf_range(-0.08, 0.08),
			"alpha": randf_range(0.06, 0.18),
			"speed": randf_range(0.4, 1.1),
			"phase": randf_range(0.0, TAU),
		})
	for _k: int in range(34):
		_star_particles.append({
			"pos": Vector2(randf_range(120.0, screen_size.x - 40.0), randf_range(28.0, 246.0)),
			"radius": randf_range(0.7, 1.8),
			"phase": randf_range(0.0, TAU),
			"speed": randf_range(0.8, 2.4),
			"twinkle": randf(),
		})
	for _m: int in range(3):
		var meteor := {}
		_reset_shooting_star(meteor)
		_shooting_stars.append(meteor)
	for _n: int in range(22):
		_meteor_fragments.append({
			"active": false,
			"pos": Vector2.ZERO,
			"vel": Vector2.ZERO,
			"life": 0.0,
			"max_life": 0.0,
			"radius": 1.0,
		})


func _reset_shooting_star(meteor: Dictionary) -> void:
	var screen_size: Vector2 = _screen_size()
	meteor["active"] = false
	meteor["pos"] = Vector2(randf_range(-160.0, screen_size.x * 0.4), randf_range(24.0, 180.0))
	meteor["vel"] = Vector2(randf_range(280.0, 420.0), randf_range(90.0, 150.0))
	meteor["trail_len"] = randf_range(72.0, 118.0)
	meteor["max_life"] = randf_range(0.55, 0.95)
	meteor["life"] = float(meteor["max_life"])
	meteor["delay"] = randf_range(2.8, 7.6)


func _activate_shooting_star(meteor: Dictionary) -> void:
	var screen_size: Vector2 = _screen_size()
	meteor["active"] = true
	meteor["pos"] = Vector2(randf_range(-120.0, screen_size.x * 0.52), randf_range(18.0, 172.0))
	meteor["vel"] = Vector2(randf_range(290.0, 450.0), randf_range(96.0, 160.0))
	meteor["trail_len"] = randf_range(80.0, 128.0)
	meteor["max_life"] = randf_range(0.52, 0.90)
	meteor["life"] = float(meteor["max_life"])


func _spawn_meteor_fragments(origin: Vector2, dir: Vector2) -> void:
	var spawned: int = 0
	for fragment: Dictionary in _meteor_fragments:
		if bool(fragment["active"]):
			continue
		var spread: Vector2 = dir.rotated(randf_range(-0.65, 0.65))
		fragment["active"] = true
		fragment["pos"] = origin + Vector2(randf_range(-6.0, 6.0), randf_range(-4.0, 4.0))
		fragment["vel"] = spread * randf_range(54.0, 118.0)
		fragment["max_life"] = randf_range(0.22, 0.48)
		fragment["life"] = float(fragment["max_life"])
		fragment["radius"] = randf_range(1.1, 2.2)
		spawned += 1
		if spawned >= 6:
			break


func _on_new_game() -> void:
	var err := get_tree().change_scene_to_file("res://scenes/NewGameSetup.tscn")
	if err != OK:
		push_error("[TitleScreen] change_scene_to_file fallo: %d" % err)

func _on_play_menu() -> void:
	if _menu_box != null:
		_menu_box.visible = false
	if _play_modes_panel != null:
		_play_modes_panel.visible = true

func _on_back_from_play_menu() -> void:
	if _play_modes_panel != null:
		_play_modes_panel.visible = false
	if _menu_box != null:
		_menu_box.visible = true

func _on_quick_match() -> void:
	_on_new_game()

func _on_campaign() -> void:
	pass

func _on_challenge() -> void:
	pass


func _on_continue() -> void:
	GameData.load()
	get_tree().change_scene_to_file(GameData.loaded_scene_path if GameData.loaded_scene_path != "" else GameData.DEFAULT_CONTINUE_SCENE_PATH)

func _on_tutorial() -> void:
	var err := get_tree().change_scene_to_file("res://scenes/TutorialMenu.tscn")
	if err != OK:
		push_error("[TitleScreen] No se pudo abrir TutorialMenu: %d" % err)

func _on_options() -> void:
	if _options_overlay == null:
		return
	_refresh_options_overlay()
	_options_overlay.visible = true

func _on_unlocks() -> void:
	if _unlock_overlay == null:
		return
	GameData.load_meta()
	_refresh_unlock_overlay()
	_unlock_overlay.visible = true


func _on_quit() -> void:
	get_tree().quit()

func _build_unlock_overlay() -> void:
	_unlock_overlay = Control.new()
	_unlock_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_unlock_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_unlock_overlay.visible = false
	add_child(_unlock_overlay)

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.02, 0.04, 0.84)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_unlock_overlay.add_child(bg)

	var panel := Panel.new()
	panel.position = Vector2(64.0, 24.0)
	panel.size = Vector2(1152.0, 672.0)
	_apply_panel_style(panel, Color(0.07, 0.08, 0.11, 0.96), Color(0.96, 0.84, 0.46, 0.32))
	_unlock_overlay.add_child(panel)

	var title := Label.new()
	title.text = "Desbloqueos"
	title.position = Vector2(28.0, 24.0)
	title.size = Vector2(280.0, 36.0)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", GOLD)
	panel.add_child(title)

	_unlock_summary_label = Label.new()
	_unlock_summary_label.position = Vector2(28.0, 64.0)
	_unlock_summary_label.size = Vector2(740.0, 24.0)
	_unlock_summary_label.add_theme_font_size_override("font_size", 14)
	_unlock_summary_label.add_theme_color_override("font_color", DIM)
	panel.add_child(_unlock_summary_label)

	_unlock_faction_selector = HBoxContainer.new()
	_unlock_faction_selector.position = Vector2(28.0, 98.0)
	_unlock_faction_selector.size = Vector2(784.0, 72.0)
	_unlock_faction_selector.add_theme_constant_override("separation", 12)
	panel.add_child(_unlock_faction_selector)

	for faction_id: int in FactionData.get_all_faction_ids():
		_unlock_faction_selector.add_child(_build_unlock_faction_button(faction_id))

	_unlock_side_panel = Panel.new()
	_unlock_side_panel.position = Vector2(844.0, 24.0)
	_unlock_side_panel.size = Vector2(280.0, 578.0)
	_apply_panel_style(_unlock_side_panel, Color(0.10, 0.09, 0.12, 0.96), Color(0.96, 0.84, 0.46, 0.24))
	panel.add_child(_unlock_side_panel)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(28.0, 184.0)
	scroll.size = Vector2(784.0, 418.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	_unlock_list = GridContainer.new()
	_unlock_list.columns = 3
	_unlock_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_unlock_list.add_theme_constant_override("h_separation", 18)
	_unlock_list.add_theme_constant_override("v_separation", 18)
	scroll.add_child(_unlock_list)

	var hint := Label.new()
	hint.text = "Las cartas desbloqueadas se suman al mazo solo si estan equipadas."
	hint.position = Vector2(28.0, 620.0)
	hint.size = Vector2(620.0, 20.0)
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", DIM)
	panel.add_child(hint)

	var close_btn := _make_compact_button("Cerrar", Vector2(224.0, 44.0), 20)
	close_btn.position = Vector2(900.0, 614.0)
	close_btn.pressed.connect(func(): _unlock_overlay.visible = false)
	close_btn.pressed.connect(AudioManager.play_menu_button)
	panel.add_child(close_btn)

	_refresh_unlock_overlay()

func _refresh_unlock_overlay() -> void:
	if _unlock_list == null:
		return
	_unlock_hover_card = {}
	_unlock_hover_is_base = false
	_unlock_hover_unlock_id = ""
	_unlock_hover_progress = {}
	for child: Node in _unlock_list.get_children():
		child.queue_free()
	if _unlock_side_panel != null:
		for child: Node in _unlock_side_panel.get_children():
			child.queue_free()

	var unlocked_count: int = 0
	var total_count: int = 0
	var faction_unlock_ids: Array[String] = _get_unlock_ids_for_faction(_unlock_selected_faction)
	for unlock_id: String in faction_unlock_ids:
		total_count += 1
		if GameData.is_unlock_unlocked(unlock_id):
			unlocked_count += 1

	for faction_id: int in FactionData.get_all_faction_ids():
		var button := _unlock_faction_selector.get_node_or_null("FactionButton%d" % faction_id) as Button
		if button != null:
			_apply_unlock_faction_button_style(button, faction_id == _unlock_selected_faction, FactionData.get_color(faction_id))

	var base_cards: Array[Dictionary] = GameData.get_default_faction_cards(_unlock_selected_faction)
	for card_data: Dictionary in base_cards:
		_unlock_list.add_child(_build_card_entry(card_data, true, "", {"current": 1, "required": 1, "complete": true}))
	for unlock_id: String in faction_unlock_ids:
		_unlock_list.add_child(_build_unlock_entry(unlock_id))

	_build_unlock_side_panel(base_cards, faction_unlock_ids, unlocked_count, total_count)

	if _unlock_summary_label != null:
		_unlock_summary_label.text = "%s  |  Coleccion de faccion  |  Iniciales: %d  |  Desbloqueadas: %d/%d  |  En mazo: %d/%d  |  Partidas completadas (J1): %d" % [
			FactionData.get_faction_name(_unlock_selected_faction),
			base_cards.size(),
			unlocked_count,
			total_count,
			GameData.get_equipped_faction_card_count_for_faction(_unlock_selected_faction),
			GameData.get_max_equipped_faction_cards_for_faction(_unlock_selected_faction),
			GameData.get_runs_for_faction(_unlock_selected_faction),
		]

func _build_unlock_entry(unlock_id: String) -> Panel:
	var unlock_def: Dictionary = GameData.get_unlock_def(unlock_id)
	var progress: Dictionary = GameData.get_unlock_progress(unlock_id)
	var reward_cards: Array = unlock_def.get("reward_cards", [])
	var reward_card: Dictionary = reward_cards[0] if not reward_cards.is_empty() else {}
	return _build_card_entry(reward_card, false, unlock_id, progress)

func _build_unlock_faction_button(faction_id: int) -> Button:
	var button := Button.new()
	button.name = "FactionButton%d" % faction_id
	button.custom_minimum_size = Vector2(187.0, 72.0)
	button.focus_mode = Control.FOCUS_NONE
	button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.expand_icon = true
	button.clip_text = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 18)
	button.text = "  %s" % FactionData.get_faction_name(faction_id)
	var master_texture: Texture2D = load(FactionData.get_sprite_path(faction_id, -1))
	if master_texture != null:
		button.icon = master_texture
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_apply_unlock_faction_button_style(button, faction_id == _unlock_selected_faction, FactionData.get_color(faction_id))
	button.pressed.connect(func() -> void:
		_unlock_selected_faction = faction_id
		_refresh_unlock_overlay()
	)
	return button

func _apply_unlock_faction_button_style(button: Button, selected: bool, faction_color: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.11, 0.10, 0.14, 0.96)
	normal.border_color = faction_color if selected else Color(1.0, 1.0, 1.0, 0.10)
	normal.set_border_width_all(2 if selected else 1)
	normal.set_corner_radius_all(6)
	var hover := normal.duplicate()
	hover.bg_color = normal.bg_color.lightened(0.08)
	var pressed := hover.duplicate()
	pressed.bg_color = hover.bg_color.darkened(0.08)
	for state_name: String in ["normal", "focus"]:
		button.add_theme_stylebox_override(state_name, normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", faction_color.lerp(TEXT, 0.35) if selected else TEXT)

func _build_card_entry(card_data: Dictionary, is_base: bool, unlock_id: String, progress: Dictionary) -> Panel:
	var base_card_id: String = str(card_data.get("source_card_id", ""))
	var unlocked: bool = is_base or GameData.is_unlock_unlocked(unlock_id)
	var equipped: bool = GameData.is_base_card_equipped(base_card_id) if is_base else GameData.is_unlock_equipped(unlock_id)
	var can_equip: bool = true if is_base else GameData.can_equip_unlock(unlock_id)
	var entry := Panel.new()
	entry.custom_minimum_size = Vector2(248.0, 336.0)
	entry.mouse_filter = Control.MOUSE_FILTER_STOP
	var clear_style := StyleBoxFlat.new()
	clear_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	clear_style.border_color = Color(0.0, 0.0, 0.0, 0.0)
	clear_style.set_border_width_all(0)
	clear_style.set_corner_radius_all(0)
	entry.add_theme_stylebox_override("panel", clear_style)

	var preview := Panel.new()
	preview.position = Vector2(16.0, 16.0)
	preview.size = Vector2(216.0, 272.0)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_panel_style(preview, Color(0.18, 0.15, 0.12, 0.98) if unlocked else Color(0.12, 0.12, 0.12, 0.98), Color(0.98, 0.82, 0.34, 0.34) if unlocked else Color(0.42, 0.42, 0.42, 0.28))
	entry.add_child(preview)

	var art_path: String = str(card_data.get("art_path", ""))
	var texture: Texture2D = load(art_path) if art_path != "" else null
	if texture != null:
		var tex_rect := TextureRect.new()
		tex_rect.position = Vector2(6.0, 6.0)
		tex_rect.size = Vector2(204.0, 260.0)
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tex_rect.texture = texture
		tex_rect.modulate = Color(1.0, 1.0, 1.0, 1.0) if unlocked else Color(0.45, 0.45, 0.45, 1.0)
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview.add_child(tex_rect)
	else:
		var card_title := Label.new()
		card_title.text = str(card_data.get("display_name", "Carta")).to_upper()
		card_title.position = Vector2(16.0, 18.0)
		card_title.size = Vector2(184.0, 132.0)
		card_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		card_title.add_theme_font_size_override("font_size", 18)
		card_title.add_theme_color_override("font_color", TEXT if unlocked else Color(0.68, 0.68, 0.68, 1.0))
		card_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview.add_child(card_title)

		var value_lbl := Label.new()
		value_lbl.text = _get_unlock_card_preview_value(card_data)
		value_lbl.position = Vector2(16.0, 146.0)
		value_lbl.size = Vector2(184.0, 42.0)
		value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		value_lbl.add_theme_font_size_override("font_size", 30)
		value_lbl.add_theme_color_override("font_color", GOLD if unlocked else DIM)
		value_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview.add_child(value_lbl)

	var top_band := ColorRect.new()
	top_band.position = Vector2(6.0, 6.0)
	top_band.size = Vector2(204.0, 28.0)
	top_band.color = Color(0.10, 0.08, 0.08, 0.82) if unlocked else Color(0.10, 0.10, 0.10, 0.88)
	top_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.add_child(top_band)

	var top_name := Label.new()
	top_name.text = str(card_data.get("display_name", unlock_id if unlock_id != "" else "Carta base"))
	top_name.position = Vector2(12.0, 9.0)
	top_name.size = Vector2(192.0, 20.0)
	top_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_name.add_theme_font_size_override("font_size", 16)
	top_name.add_theme_color_override("font_color", TEXT if unlocked else Color(0.78, 0.78, 0.78, 1.0))
	top_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.add_child(top_name)

	var toggle_btn := Button.new()
	toggle_btn.position = Vector2(178.0, 240.0)
	toggle_btn.size = Vector2(32.0, 32.0)
	toggle_btn.focus_mode = Control.FOCUS_NONE
	toggle_btn.disabled = not unlocked or (not equipped and not can_equip)
	toggle_btn.text = "✓" if equipped else ""
	toggle_btn.add_theme_font_size_override("font_size", 22)
	var toggle_normal := StyleBoxFlat.new()
	toggle_normal.bg_color = Color(0.18, 0.28, 0.14, 0.96) if equipped else Color(0.11, 0.11, 0.14, 0.94)
	toggle_normal.border_color = Color(0.36, 0.92, 0.44, 0.84) if equipped else BUTTON_BORDER
	toggle_normal.set_border_width_all(2)
	toggle_normal.set_corner_radius_all(4)
	var toggle_hover := toggle_normal.duplicate()
	toggle_hover.bg_color = toggle_normal.bg_color.lightened(0.1)
	var toggle_pressed := toggle_hover.duplicate()
	toggle_pressed.bg_color = toggle_normal.bg_color.darkened(0.1)
	var toggle_disabled := toggle_normal.duplicate()
	toggle_disabled.bg_color = BUTTON_DISABLED
	toggle_disabled.border_color = Color(1.0, 1.0, 1.0, 0.08)
	for state_name: String in ["normal", "focus"]:
		toggle_btn.add_theme_stylebox_override(state_name, toggle_normal)
	toggle_btn.add_theme_stylebox_override("hover", toggle_hover)
	toggle_btn.add_theme_stylebox_override("pressed", toggle_pressed)
	toggle_btn.add_theme_stylebox_override("disabled", toggle_disabled)
	toggle_btn.add_theme_color_override("font_color", Color(0.46, 1.0, 0.54, 1.0) if equipped else TEXT)
	toggle_btn.add_theme_color_override("font_disabled_color", Color(0.62, 0.62, 0.66, 1.0))
	toggle_btn.tooltip_text = "Quitar del mazo" if equipped else ("Añadir al mazo" if unlocked else "Aún bloqueada")
	toggle_btn.pressed.connect(func() -> void:
		if is_base:
			GameData.toggle_base_card_equipped(base_card_id)
		else:
			GameData.toggle_unlock_equipped(unlock_id)
		_refresh_unlock_overlay()
	)
	preview.add_child(toggle_btn)

	var state_lbl := Label.new()
	state_lbl.text = "En mazo" if equipped else ("Lista para mazo" if can_equip and unlocked else ("Mazo lleno" if unlocked else "Bloqueada"))
	state_lbl.position = Vector2(16.0, 292.0)
	state_lbl.size = Vector2(216.0, 20.0)
	state_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state_lbl.add_theme_font_size_override("font_size", 12)
	state_lbl.add_theme_color_override("font_color", Color(0.36, 0.92, 0.44, 1.0) if equipped else (TEXT if can_equip and unlocked else DIM))
	state_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entry.add_child(state_lbl)

	entry.mouse_entered.connect(func() -> void:
		_unlock_hover_card = card_data.duplicate(true)
		_unlock_hover_is_base = is_base
		_unlock_hover_unlock_id = unlock_id
		_unlock_hover_progress = progress.duplicate(true)
		_refresh_unlock_side_panel_only()
	)
	entry.mouse_exited.connect(func() -> void:
		_unlock_hover_card = {}
		_unlock_hover_hover_reset()
	)

	return entry

func _build_unlock_side_panel(base_cards: Array[Dictionary], faction_unlock_ids: Array[String], unlocked_count: int, total_count: int) -> void:
	if _unlock_side_panel == null:
		return
	var faction_color: Color = FactionData.get_color(_unlock_selected_faction)

	var title := Label.new()
	title.text = FactionData.get_faction_name(_unlock_selected_faction)
	title.position = Vector2(20.0, 18.0)
	title.size = Vector2(180.0, 30.0)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", faction_color)
	_unlock_side_panel.add_child(title)

	var portrait_panel := Panel.new()
	portrait_panel.position = Vector2(20.0, 56.0)
	portrait_panel.size = Vector2(240.0, 160.0)
	_apply_panel_style(portrait_panel, Color(0.16, 0.12, 0.10, 0.98), Color(faction_color.r, faction_color.g, faction_color.b, 0.44))
	_unlock_side_panel.add_child(portrait_panel)

	var portrait := TextureRect.new()
	portrait.position = Vector2(10.0, 10.0)
	portrait.size = Vector2(220.0, 140.0)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.texture = load(FactionData.get_sprite_path(_unlock_selected_faction, -1))
	portrait_panel.add_child(portrait)

	var progress_box := Panel.new()
	progress_box.position = Vector2(20.0, 228.0)
	progress_box.size = Vector2(240.0, 84.0)
	_apply_panel_style(progress_box, Color(0.09, 0.10, 0.13, 0.92), Color(1.0, 1.0, 1.0, 0.08))
	_unlock_side_panel.add_child(progress_box)

	var progress_title := Label.new()
	progress_title.text = "Progreso"
	progress_title.position = Vector2(14.0, 10.0)
	progress_title.size = Vector2(120.0, 22.0)
	progress_title.add_theme_font_size_override("font_size", 20)
	progress_title.add_theme_color_override("font_color", GOLD)
	progress_box.add_child(progress_title)

	var progress_runs := Label.new()
	progress_runs.text = "Partidas completadas: %d" % GameData.get_runs_for_faction(_unlock_selected_faction)
	progress_runs.position = Vector2(14.0, 36.0)
	progress_runs.size = Vector2(212.0, 18.0)
	progress_runs.add_theme_font_size_override("font_size", 13)
	progress_runs.add_theme_color_override("font_color", TEXT)
	progress_box.add_child(progress_runs)

	var progress_cards := Label.new()
	progress_cards.text = "Desbloqueadas: %d/%d" % [unlocked_count, total_count]
	progress_cards.position = Vector2(14.0, 56.0)
	progress_cards.size = Vector2(212.0, 18.0)
	progress_cards.add_theme_font_size_override("font_size", 13)
	progress_cards.add_theme_color_override("font_color", CYAN)
	progress_box.add_child(progress_cards)

	var equipped_cards := Label.new()
	equipped_cards.text = "En mazo: %d/%d" % [GameData.get_equipped_faction_card_count_for_faction(_unlock_selected_faction), GameData.get_max_equipped_faction_cards_for_faction(_unlock_selected_faction)]
	equipped_cards.position = Vector2(14.0, 76.0)
	equipped_cards.size = Vector2(212.0, 18.0)
	equipped_cards.add_theme_font_size_override("font_size", 13)
	equipped_cards.add_theme_color_override("font_color", Color(0.58, 0.92, 0.58, 1.0))
	progress_box.add_child(equipped_cards)

	var info_box := Panel.new()
	info_box.position = Vector2(20.0, 324.0)
	info_box.size = Vector2(240.0, 252.0)
	_apply_panel_style(info_box, Color(0.09, 0.10, 0.13, 0.92), Color(1.0, 1.0, 1.0, 0.08))
	_unlock_side_panel.add_child(info_box)

	var info_title := Label.new()
	info_title.text = "Carta"
	info_title.position = Vector2(14.0, 10.0)
	info_title.size = Vector2(180.0, 22.0)
	info_title.add_theme_font_size_override("font_size", 20)
	info_title.add_theme_color_override("font_color", GOLD)
	info_box.add_child(info_title)

	if _unlock_hover_card.is_empty():
		var hint := RichTextLabel.new()
		hint.text = "Pasá el mouse sobre una carta para ver su efecto, condición y progreso."
		hint.position = Vector2(14.0, 40.0)
		hint.size = Vector2(212.0, 78.0)
		hint.fit_content = false
		hint.scroll_active = false
		hint.bbcode_enabled = false
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.add_theme_font_size_override("font_size", 12)
		hint.add_theme_color_override("default_color", DIM)
		info_box.add_child(hint)

		var deck_hint := RichTextLabel.new()
		deck_hint.text = "Iniciales: %d cartas\nExtras: hasta %d desbloqueadas por mazo.\nTodas se pueden marcar o quitar." % [base_cards.size(), GameData.get_max_equipped_extra_faction_cards()]
		deck_hint.position = Vector2(14.0, 140.0)
		deck_hint.size = Vector2(212.0, 52.0)
		deck_hint.fit_content = false
		deck_hint.scroll_active = false
		deck_hint.bbcode_enabled = false
		deck_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		deck_hint.add_theme_font_size_override("font_size", 12)
		deck_hint.add_theme_color_override("default_color", DIM)
		info_box.add_child(deck_hint)
		return

	var hovered_base_card_id: String = str(_unlock_hover_card.get("source_card_id", ""))
	var hovered_unlocked: bool = _unlock_hover_is_base or GameData.is_unlock_unlocked(_unlock_hover_unlock_id)
	var hovered_equipped: bool = GameData.is_base_card_equipped(hovered_base_card_id) if _unlock_hover_is_base else GameData.is_unlock_equipped(_unlock_hover_unlock_id)
	var hovered_can_equip: bool = true if _unlock_hover_is_base else GameData.can_equip_unlock(_unlock_hover_unlock_id)

	var card_name := RichTextLabel.new()
	card_name.text = str(_unlock_hover_card.get("display_name", "Carta"))
	card_name.position = Vector2(14.0, 40.0)
	card_name.size = Vector2(212.0, 42.0)
	card_name.fit_content = false
	card_name.scroll_active = false
	card_name.bbcode_enabled = false
	card_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_name.add_theme_font_size_override("font_size", 18)
	card_name.add_theme_color_override("default_color", TEXT if hovered_unlocked else DIM)
	info_box.add_child(card_name)

	var effect_lbl := RichTextLabel.new()
	effect_lbl.text = str(_unlock_hover_card.get("description", ""))
	effect_lbl.position = Vector2(14.0, 82.0)
	effect_lbl.size = Vector2(212.0, 68.0)
	effect_lbl.fit_content = false
	effect_lbl.scroll_active = false
	effect_lbl.bbcode_enabled = false
	effect_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect_lbl.add_theme_font_size_override("font_size", 12)
	effect_lbl.add_theme_color_override("default_color", TEXT if hovered_unlocked else DIM)
	info_box.add_child(effect_lbl)

	var condition_lbl := RichTextLabel.new()
	condition_lbl.text = "Condición: disponible desde el inicio" if _unlock_hover_is_base else "Condición: %d/%d partidas completadas" % [int(_unlock_hover_progress.get("current", 0)), int(_unlock_hover_progress.get("required", 0))]
	condition_lbl.position = Vector2(14.0, 156.0)
	condition_lbl.size = Vector2(212.0, 42.0)
	condition_lbl.fit_content = false
	condition_lbl.scroll_active = false
	condition_lbl.bbcode_enabled = false
	condition_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	condition_lbl.add_theme_font_size_override("font_size", 12)
	condition_lbl.add_theme_color_override("default_color", CYAN if hovered_unlocked else DIM)
	info_box.add_child(condition_lbl)

	var status_lbl := RichTextLabel.new()
	status_lbl.text = "Estado: en mazo" if hovered_equipped else ("Estado: lista para añadir" if hovered_can_equip and hovered_unlocked else ("Estado: mazo lleno" if hovered_unlocked else "Estado: bloqueada"))
	status_lbl.position = Vector2(14.0, 204.0)
	status_lbl.size = Vector2(212.0, 30.0)
	status_lbl.fit_content = false
	status_lbl.scroll_active = false
	status_lbl.bbcode_enabled = false
	status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_lbl.add_theme_font_size_override("font_size", 12)
	status_lbl.add_theme_color_override("default_color", Color(0.36, 0.92, 0.44, 1.0) if hovered_equipped else TEXT)
	info_box.add_child(status_lbl)

func _unlock_hover_hover_reset() -> void:
	_unlock_hover_is_base = false
	_unlock_hover_unlock_id = ""
	_unlock_hover_progress = {}
	_refresh_unlock_side_panel_only()

func _refresh_unlock_side_panel_only() -> void:
	if _unlock_side_panel == null:
		return
	for child: Node in _unlock_side_panel.get_children():
		child.queue_free()
	var base_cards: Array[Dictionary] = GameData.get_default_faction_cards(_unlock_selected_faction)
	var faction_unlock_ids: Array[String] = _get_unlock_ids_for_faction(_unlock_selected_faction)
	var unlocked_count: int = 0
	for unlock_id: String in faction_unlock_ids:
		if GameData.is_unlock_unlocked(unlock_id):
			unlocked_count += 1
	_build_unlock_side_panel(base_cards, faction_unlock_ids, unlocked_count, faction_unlock_ids.size())
func _get_unlock_ids_for_faction(faction_id: int) -> Array[String]:
	var result: Array[String] = []
	for unlock_id: String in GameData.get_unlock_ids():
		var unlock_def: Dictionary = GameData.get_unlock_def(unlock_id)
		if int(unlock_def.get("faction", -1)) == faction_id:
			result.append(unlock_id)
	return result

func _get_unlock_card_tooltip(card_data: Dictionary, is_base: bool, unlock_id: String, progress: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append(str(card_data.get("display_name", "Carta")))
	lines.append(str(card_data.get("description", "")))
	if is_base:
		lines.append("Condicion: disponible desde el inicio")
		lines.append("Estado: %s" % ("equipada" if GameData.is_base_card_equipped(str(card_data.get("source_card_id", ""))) else "fuera del mazo"))
	else:
		var unlock_def: Dictionary = GameData.get_unlock_def(unlock_id)
		lines.append("Condicion: %s" % str(unlock_def.get("description", "")))
		lines.append("Progreso: %d/%d" % [int(progress.get("current", 0)), int(progress.get("required", 0))])
		lines.append("Estado: %s" % ("equipada" if GameData.is_unlock_equipped(unlock_id) else ("desbloqueada" if GameData.is_unlock_unlocked(unlock_id) else "bloqueada")))
	return "\n".join(lines)

func _get_unlock_card_preview_value(card_data: Dictionary) -> String:
	var effect: String = str(card_data.get("effect", ""))
	var value: int = int(card_data.get("value", 0))
	if card_data.get("type", "") == "essence":
		return "+%dE" % value
	if effect == "extra_move":
		return "+%dM" % value
	if effect == "damage":
		return "-%dHP" % value
	if effect == "heal":
		return "+%dHP" % value
	if effect == "exp":
		return "+%dXP" % value
	if effect == "defense_buff":
		return "+%dDEF" % value
	if effect == "attack_debuff":
		return "-%dATQ" % value
	if effect == "aoe_damage":
		return "AOE %d" % value
	if effect == "poison":
		return "VEN"
	if effect == "double_attack":
		return "x2"
	if effect == "free_summon":
		return "FREE"
	if effect == "untargetable":
		return "NUBE"
	if effect == "swap_hp":
		return "SWAP"
	if effect == "revive":
		return "REV"
	if effect == "random":
		return "???"
	if effect == "tower_heal":
		return "+%dTOR" % value
	if effect == "immobilize":
		return "ATA"
	if effect == "refresh":
		return "REC"
	if effect == "sacrifice_essence":
		return "+%dE" % value
	return str(value) if value != 0 else "FX"
