extends Control

signal closed

const C_PANEL  := Color(0.07, 0.08, 0.11, 0.97)
const C_BORDER := Color(0.96, 0.84, 0.46, 0.30)
const C_GOLD   := Color(1.00, 0.88, 0.28)
const C_TEXT   := Color(0.94, 0.92, 0.88)
const C_DIM    := Color(0.72, 0.68, 0.60, 0.82)
const C_CYAN   := Color(0.42, 0.88, 1.00)

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 100

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.02, 0.04, 0.80)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var panel := Panel.new()
	panel.position = Vector2(390.0, 230.0)
	panel.size = Vector2(500.0, 228.0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = C_PANEL
	panel_style.border_color = C_BORDER
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	var title := Label.new()
	title.text = "Audio"
	title.position = Vector2(24.0, 20.0)
	title.size = Vector2(200.0, 30.0)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", C_GOLD)
	GameData.apply_selected_font_to_control(title)
	panel.add_child(title)

	var sub := Label.new()
	sub.text = "Ajusta el volumen de música y efectos de sonido."
	sub.position = Vector2(24.0, 56.0)
	sub.size = Vector2(450.0, 18.0)
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", C_DIM)
	GameData.apply_selected_font_to_control(sub)
	panel.add_child(sub)

	_add_slider_row(panel, "Música",   82.0,  SettingsManager.music_volume,
		func(v: float) -> void: SettingsManager.set_music_volume(v), true)
	_add_slider_row(panel, "Efectos", 122.0, SettingsManager.sfx_volume,
		func(v: float) -> void: SettingsManager.set_sfx_volume(v), false)

	var close_btn := _make_button("Cerrar")
	close_btn.position = Vector2(174.0, 172.0)
	close_btn.pressed.connect(_close)
	close_btn.pressed.connect(AudioManager.play_button)
	panel.add_child(close_btn)

func _add_slider_row(parent: Control, label_text: String, y: float,
		initial: float, on_change: Callable, _unused: bool) -> void:
	var lbl := Label.new()
	lbl.text = label_text
	lbl.position = Vector2(24.0, y + 2.0)
	lbl.size = Vector2(78.0, 20.0)
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", C_TEXT)
	GameData.apply_selected_font_to_control(lbl)
	parent.add_child(lbl)

	var slider := HSlider.new()
	slider.position = Vector2(108.0, y + 4.0)
	slider.size = Vector2(300.0, 16.0)
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = initial
	slider.focus_mode = Control.FOCUS_NONE
	parent.add_child(slider)

	var pct := Label.new()
	pct.text = "%d%%" % roundi(initial * 100.0)
	pct.position = Vector2(416.0, y + 2.0)
	pct.size = Vector2(58.0, 20.0)
	pct.add_theme_font_size_override("font_size", 16)
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pct.add_theme_color_override("font_color", C_CYAN)
	GameData.apply_selected_font_to_control(pct)
	parent.add_child(pct)

	slider.value_changed.connect(func(v: float) -> void:
		pct.text = "%d%%" % roundi(v * 100.0)
		on_change.call(v)
	)

func _make_button(label_text: String) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.size = Vector2(152.0, 36.0)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 17)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.10, 0.09, 0.14, 0.95)
	st.border_color = Color(0.96, 0.84, 0.46, 0.40)
	st.set_border_width_all(1)
	st.set_corner_radius_all(4)
	var st_hover := st.duplicate()
	st_hover.bg_color = Color(0.18, 0.15, 0.22, 0.95)
	btn.add_theme_stylebox_override("normal", st)
	btn.add_theme_stylebox_override("hover", st_hover)
	btn.add_theme_stylebox_override("pressed", st)
	btn.add_theme_color_override("font_color", C_TEXT)
	GameData.apply_selected_font_to_control(btn)
	return btn

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close()
		get_viewport().set_input_as_handled()

func _close() -> void:
	emit_signal("closed")
	queue_free()
