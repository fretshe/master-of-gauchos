extends Control

const SCREEN_SIZE := Vector2(1280.0, 720.0)
const TITLE_LOGO_PATH := "res://assets/sprites/title/game_logo.png"
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
var _menu_shell: Control = null
var _unlock_overlay: Control = null
var _unlock_list: VBoxContainer = null
var _unlock_summary_label: Label = null
var _patch_notes_overlay: Control = null
var _options_overlay: Control = null
var _options_font_value_label: Label = null
var _options_font_modern_btn: Button = null
var _options_font_tiny_btn: Button = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	GameData.load_meta()
	randomize()
	_init_particles()
	_build_ui()
	GameData.call_deferred("apply_selected_theme", get_window())
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.42)
	MusicManager.play_menu_music()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_P and _menu_shell != null:
		_menu_shell.visible = not _menu_shell.visible


func _process(delta: float) -> void:
	_parallax_time += delta
	for particle: Dictionary in _dust_particles:
		var pos: Vector2 = particle["pos"]
		pos += particle["vel"] * delta
		if pos.x > SCREEN_SIZE.x + 90.0:
			pos.x = -90.0
		if pos.y < -40.0:
			pos.y = SCREEN_SIZE.y + 40.0
		elif pos.y > SCREEN_SIZE.y + 40.0:
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
			if float(meteor["life"]) <= 0.0 or pos.x > SCREEN_SIZE.x + 120.0 or pos.y > SCREEN_SIZE.y * 0.48:
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

	var left_panel := Panel.new()
	left_panel.position = Vector2(56.0, 72.0)
	left_panel.size = Vector2(488.0, 564.0)
	_apply_panel_style(left_panel, PANEL_BG, PANEL_BORDER)
	_menu_shell.add_child(left_panel)
	var title_logo := TextureRect.new()
	title_logo.position = Vector2(8.0, 8.0)
	title_logo.size = Vector2(472.0, 184.0)
	title_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title_logo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	title_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title_logo_tex: Texture2D = load(TITLE_LOGO_PATH)
	if title_logo_tex != null:
		title_logo.texture = title_logo_tex
	left_panel.add_child(title_logo)
	var menu_box := VBoxContainer.new()
	menu_box.position = Vector2(44.0, 184.0)
	menu_box.size = Vector2(400.0, 324.0)
	menu_box.alignment = BoxContainer.ALIGNMENT_CENTER
	menu_box.add_theme_constant_override("separation", 8)
	left_panel.add_child(menu_box)

	var btn_new := _make_menu_button("Nueva Partida")
	btn_new.pressed.connect(_on_new_game)
	btn_new.pressed.connect(AudioManager.play_menu_button)
	_bind_button_description(btn_new, "Prepara facciones, mapa y semilla para comenzar una nueva disputa.")
	menu_box.add_child(btn_new)

	var btn_cont := _make_menu_button("Continuar")
	btn_cont.disabled = not GameData.has_saved_match()
	btn_cont.pressed.connect(_on_continue)
	btn_cont.pressed.connect(AudioManager.play_menu_button)
	_bind_button_description(btn_cont, "Retoma la ultima partida guardada con tu mapa y progreso actuales.")
	menu_box.add_child(btn_cont)

	var btn_tutorial := _make_menu_button("Tutorial")
	btn_tutorial.pressed.connect(_on_tutorial)
	btn_tutorial.pressed.connect(AudioManager.play_menu_button)
	_bind_button_description(btn_tutorial, "Accede a capítulos guiados para aprender combate, economía e invocación paso a paso.")
	menu_box.add_child(btn_tutorial)
	var btn_opts := _make_menu_button("Opciones")
	btn_opts.pressed.connect(_on_options)
	btn_opts.pressed.connect(AudioManager.play_menu_button)
	_bind_button_description(btn_opts, "Ajustes y accesos rapidos. Por ahora queda como punto de entrada futuro.")
	menu_box.add_child(btn_opts)

	var btn_unlocks := _make_menu_button("Desbloqueos")
	btn_unlocks.pressed.connect(_on_unlocks)
	btn_unlocks.pressed.connect(AudioManager.play_menu_button)
	_bind_button_description(btn_unlocks, "Consulta tu progreso meta entre partidas y equipa mejoras permanentes.")
	menu_box.add_child(btn_unlocks)

	var btn_quit := _make_menu_button("Salir")
	btn_quit.pressed.connect(_on_quit)
	btn_quit.pressed.connect(AudioManager.play_menu_button)
	_bind_button_description(btn_quit, "Cierra el juego.")
	menu_box.add_child(btn_quit)

	_build_version_label()
	_build_options_overlay()
	_build_patch_notes_overlay()
	_build_unlock_overlay()


func _build_version_label() -> void:
	var footer := HBoxContainer.new()
	footer.position = Vector2(1038.0, 676.0)
	footer.size = Vector2(214.0, 28.0)
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_theme_constant_override("separation", 8)
	_menu_shell.add_child(footer)

	var version_label := Label.new()
	version_label.text = GameData.get_build_version_label()
	version_label.custom_minimum_size = Vector2(114.0, 28.0)
	version_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	version_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	version_label.add_theme_font_size_override("font_size", 14)
	version_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.88, 0.34))
	footer.add_child(version_label)

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
	footer.add_child(notes_btn)

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
	panel.position = Vector2(272.0, 76.0)
	panel.size = Vector2(740.0, 548.0)
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
	subtitle.text = "Ajusta la fuente del juego para priorizar estilo o legibilidad."
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

	var close_btn := _make_compact_button("Cerrar", Vector2(316.0, 40.0), 20)
	close_btn.position = Vector2(212.0, 476.0)
	close_btn.pressed.connect(func(): _options_overlay.visible = false)
	close_btn.pressed.connect(AudioManager.play_menu_button)
	panel.add_child(close_btn)

	_refresh_options_overlay()

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


func _bind_button_description(button: Button, description: String) -> void:
	button.tooltip_text = description


func _apply_panel_style(panel: Panel, bg_color: Color, border_color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)


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
	for _i: int in range(28):
		_dust_particles.append({
			"pos": Vector2(randf_range(-40.0, SCREEN_SIZE.x + 40.0), randf_range(120.0, SCREEN_SIZE.y - 10.0)),
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
			"pos": Vector2(randf_range(120.0, SCREEN_SIZE.x - 40.0), randf_range(28.0, 246.0)),
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
	meteor["active"] = false
	meteor["pos"] = Vector2(randf_range(-160.0, SCREEN_SIZE.x * 0.4), randf_range(24.0, 180.0))
	meteor["vel"] = Vector2(randf_range(280.0, 420.0), randf_range(90.0, 150.0))
	meteor["trail_len"] = randf_range(72.0, 118.0)
	meteor["max_life"] = randf_range(0.55, 0.95)
	meteor["life"] = float(meteor["max_life"])
	meteor["delay"] = randf_range(2.8, 7.6)


func _activate_shooting_star(meteor: Dictionary) -> void:
	meteor["active"] = true
	meteor["pos"] = Vector2(randf_range(-120.0, SCREEN_SIZE.x * 0.52), randf_range(18.0, 172.0))
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
	panel.position = Vector2(158.0, 76.0)
	panel.size = Vector2(964.0, 568.0)
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
	_unlock_summary_label.size = Vector2(640.0, 24.0)
	_unlock_summary_label.add_theme_font_size_override("font_size", 14)
	_unlock_summary_label.add_theme_color_override("font_color", DIM)
	panel.add_child(_unlock_summary_label)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(28.0, 104.0)
	scroll.size = Vector2(908.0, 384.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	_unlock_list = VBoxContainer.new()
	_unlock_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_unlock_list.add_theme_constant_override("separation", 14)
	scroll.add_child(_unlock_list)

	var hint := Label.new()
	hint.text = "Los desbloqueos equipados se aplican al comenzar nuevas partidas."
	hint.position = Vector2(28.0, 506.0)
	hint.size = Vector2(520.0, 20.0)
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", DIM)
	panel.add_child(hint)

	var close_btn := _make_menu_button("Cerrar")
	close_btn.position = Vector2(680.0, 498.0)
	close_btn.size = Vector2(256.0, 44.0)
	close_btn.custom_minimum_size = Vector2(256.0, 44.0)
	close_btn.pressed.connect(func(): _unlock_overlay.visible = false)
	close_btn.pressed.connect(AudioManager.play_menu_button)
	panel.add_child(close_btn)

	_refresh_unlock_overlay()

func _refresh_unlock_overlay() -> void:
	if _unlock_list == null:
		return
	for child: Node in _unlock_list.get_children():
		child.queue_free()

	var unlocked_count: int = 0
	var total_count: int = 0
	for unlock_id: String in GameData.get_unlock_ids():
		total_count += 1
		if GameData.is_unlock_unlocked(unlock_id):
			unlocked_count += 1
		_unlock_list.add_child(_build_unlock_entry(unlock_id))

	if _unlock_summary_label != null:
		_unlock_summary_label.text = "Desbloqueados: %d/%d  |  Partidas con Gauchos (J1): %d" % [
			unlocked_count,
			total_count,
			GameData.get_runs_for_faction(FactionData.Faction.GAUCHOS),
		]

func _build_unlock_entry(unlock_id: String) -> Panel:
	var unlock_def: Dictionary = GameData.get_unlock_def(unlock_id)
	var progress: Dictionary = GameData.get_unlock_progress(unlock_id)
	var unlocked: bool = GameData.is_unlock_unlocked(unlock_id)
	var equipped: bool = GameData.is_unlock_equipped(unlock_id)

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(896.0, 126.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.10, 0.14, 0.92) if unlocked else Color(0.08, 0.08, 0.10, 0.84)
	style.border_color = Color(0.96, 0.84, 0.46, 0.42) if unlocked else Color(1.0, 1.0, 1.0, 0.08)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)

	var name_lbl := Label.new()
	name_lbl.text = str(unlock_def.get("name", unlock_id))
	name_lbl.position = Vector2(18.0, 14.0)
	name_lbl.size = Vector2(420.0, 24.0)
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.add_theme_color_override("font_color", GOLD if unlocked else TEXT)
	panel.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = str(unlock_def.get("description", ""))
	desc_lbl.position = Vector2(18.0, 42.0)
	desc_lbl.size = Vector2(620.0, 40.0)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 13)
	desc_lbl.add_theme_color_override("font_color", DIM)
	panel.add_child(desc_lbl)

	var progress_lbl := Label.new()
	progress_lbl.position = Vector2(18.0, 88.0)
	progress_lbl.size = Vector2(340.0, 20.0)
	progress_lbl.text = "Progreso: %d/%d" % [int(progress.get("current", 0)), int(progress.get("required", 0))]
	progress_lbl.add_theme_font_size_override("font_size", 14)
	progress_lbl.add_theme_color_override("font_color", CYAN if unlocked else DIM)
	panel.add_child(progress_lbl)

	var reward_lbl := Label.new()
	reward_lbl.position = Vector2(364.0, 88.0)
	reward_lbl.size = Vector2(310.0, 20.0)
	reward_lbl.text = "Recompensa: +1 Fogon Gaucho al mazo de Gauchos"
	reward_lbl.add_theme_font_size_override("font_size", 14)
	reward_lbl.add_theme_color_override("font_color", TEXT)
	panel.add_child(reward_lbl)

	var state_btn := Button.new()
	state_btn.position = Vector2(700.0, 34.0)
	state_btn.size = Vector2(176.0, 48.0)
	state_btn.focus_mode = Control.FOCUS_NONE
	state_btn.disabled = not unlocked
	state_btn.text = "Equipado" if equipped else ("Equipar" if unlocked else "Bloqueado")
	state_btn.add_theme_font_size_override("font_size", 18)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.18, 0.28, 0.14, 0.96) if equipped else Color(0.12, 0.10, 0.10, 0.92)
	normal.border_color = Color(0.36, 0.92, 0.44, 0.72) if equipped else BUTTON_BORDER
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	var hover := normal.duplicate()
	hover.bg_color = normal.bg_color.lightened(0.12)
	var pressed := hover.duplicate()
	pressed.bg_color = normal.bg_color.darkened(0.12)
	var disabled := normal.duplicate()
	disabled.bg_color = BUTTON_DISABLED
	disabled.border_color = Color(1.0, 1.0, 1.0, 0.08)
	for state_name: String in ["normal", "focus"]:
		state_btn.add_theme_stylebox_override(state_name, normal)
	state_btn.add_theme_stylebox_override("hover", hover)
	state_btn.add_theme_stylebox_override("pressed", pressed)
	state_btn.add_theme_stylebox_override("disabled", disabled)
	state_btn.add_theme_color_override("font_color", TEXT)
	state_btn.add_theme_color_override("font_disabled_color", Color(0.62, 0.62, 0.66, 1.0))
	state_btn.pressed.connect(func():
		GameData.toggle_unlock_equipped(unlock_id)
		_refresh_unlock_overlay()
	)
	panel.add_child(state_btn)

	return panel
