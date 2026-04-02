extends CanvasLayer

signal bonus_chosen(bonus_id: String)

const TutorialSpotlightShader := preload("res://shaders/tutorial_spotlight.gdshader")
const CARD_SIZE := Vector2(330.0, 232.0)
const CLASS_ICON_PATHS := {
	0: "res://assets/sprites/ui/class_icons/warrior_icon.png",
	1: "res://assets/sprites/ui/class_icons/archer_icon.png",
	2: "res://assets/sprites/ui/class_icons/lancer_icon.png",
	3: "res://assets/sprites/ui/class_icons/rider_icon.png",
}
const MASTER_ICON_PATH := "res://assets/sprites/ui/class_icons/master_icon.png"
const UNIT_TYPE_DISPLAY_NAMES := {
	-1: "Maestro",
	0: "Guerrero",
	1: "Arquero",
	2: "Lancero",
	3: "Jinete",
}
const LEVEL_COLORS := {
	1: Color(0.72, 0.45, 0.18),
	2: Color(0.75, 0.75, 0.80),
	3: Color(0.95, 0.82, 0.20),
	4: Color(0.16, 0.58, 0.36),
	5: Color(0.56, 0.87, 0.96),
}

var camera_controller: Camera3D = null
var hex_grid: Node = null
var hud_ref: CanvasItem = null
var card_hand_ref: CanvasItem = null

var _unit: Unit = null
var _options: Array = []
var _overlay: Control = null
var _spotlight_rect: ColorRect = null
var _spotlight_mat: ShaderMaterial = null
var _top_title: Label = null
var _top_subtitle: Label = null
var _unit_name_label: RichTextLabel = null
var _unit_level_label: Label = null
var _unit_stats_label: Label = null
var _hint_label: Label = null
var _left_refs: Dictionary = {}
var _right_refs: Dictionary = {}
var _showcase_renderer: Node3D = null
var _tween: Tween = null
var _fx_time: float = 0.0
var _hidden_ui: Array[CanvasItem] = []
var _motes: Array[Dictionary] = []
var _focus_cell: Vector2i = Vector2i(-1, -1)
var _using_parent_cinematic: bool = false
var _using_board_theater: bool = false

func _ready() -> void:
	layer = 50
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()

func _process(delta: float) -> void:
	if not visible:
		return
	_fx_time += delta
	_update_spotlight()
	_update_motes(delta)

func _build_ui() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	_spotlight_rect = ColorRect.new()
	_spotlight_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_spotlight_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spotlight_mat = ShaderMaterial.new()
	_spotlight_mat.shader = TutorialSpotlightShader
	_spotlight_mat.set_shader_parameter("dim_color", Color(0.0, 0.0, 0.0, 0.56))
	_spotlight_mat.set_shader_parameter("feather", 30.0)
	_spotlight_rect.material = _spotlight_mat
	_overlay.add_child(_spotlight_rect)

	_top_title = _make_label("NUEVA BENDICION", 30, Color(0.98, 0.74, 0.16), HORIZONTAL_ALIGNMENT_CENTER)
	_top_title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_top_title.position = Vector2(-260.0, 24.0)
	_top_title.size = Vector2(520.0, 34.0)
	_overlay.add_child(_top_title)

	_top_subtitle = _make_label("ELIGE UNA DE DOS BENDICIONES", 24, Color(0.98, 0.95, 0.90), HORIZONTAL_ALIGNMENT_CENTER)
	_top_subtitle.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_top_subtitle.position = Vector2(-320.0, 70.0)
	_top_subtitle.size = Vector2(640.0, 30.0)
	_overlay.add_child(_top_subtitle)

	_left_refs = _build_option_card(Vector2(170.0, 244.0), 1)
	_right_refs = _build_option_card(Vector2(780.0, 244.0), 2)

	_unit_name_label = RichTextLabel.new()
	_unit_name_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_unit_name_label.position = Vector2(-220.0, 546.0)
	_unit_name_label.size = Vector2(440.0, 34.0)
	_unit_name_label.bbcode_enabled = true
	_unit_name_label.fit_content = false
	_unit_name_label.scroll_active = false
	_unit_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_unit_name_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_unit_name_label.add_theme_font_size_override("normal_font_size", 26)
	_unit_name_label.add_theme_color_override("default_color", Color(0.98, 0.95, 0.90))
	_overlay.add_child(_unit_name_label)

	_unit_level_label = _make_label("", 18, Color(0.90, 0.90, 0.94), HORIZONTAL_ALIGNMENT_CENTER)
	_unit_level_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_unit_level_label.position = Vector2(-180.0, 580.0)
	_unit_level_label.size = Vector2(360.0, 24.0)
	_overlay.add_child(_unit_level_label)

	_unit_stats_label = _make_label("", 18, Color(0.56, 1.0, 0.34), HORIZONTAL_ALIGNMENT_CENTER)
	_unit_stats_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_unit_stats_label.position = Vector2(-220.0, 608.0)
	_unit_stats_label.size = Vector2(440.0, 24.0)
	_overlay.add_child(_unit_stats_label)

	_hint_label = _make_label("Pulsa [1] o [2] para elegir rapidamente", 12, Color(0.62, 0.60, 0.56), HORIZONTAL_ALIGNMENT_CENTER)
	_hint_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_hint_label.position = Vector2(-220.0, 636.0)
	_hint_label.size = Vector2(440.0, 18.0)
	_overlay.add_child(_hint_label)

	_build_motes()

func show_for_unit(unit: Unit) -> void:
	_unit = unit
	_focus_cell = _unit.get_hex_cell() if _unit != null and _unit.has_method("get_hex_cell") else Vector2i(-1, -1)
	_options = BonusSystem.get_bonus_options(unit)
	if _options.is_empty():
		bonus_chosen.emit("")
		return
	_fx_time = 0.0
	_hide_unrelated_ui()
	_enable_level_up_theater()
	_focus_camera_on_unit()
	_populate_ui()
	visible = true
	_animate_in()

func _populate_ui() -> void:
	var lvl_color: Color = LEVEL_COLORS.get(int(_unit.level), Color.WHITE)
	(_left_refs["button"] as Button).disabled = false
	(_left_refs["button"] as Button).visible = true
	(_right_refs["button"] as Button).disabled = false
	(_right_refs["button"] as Button).visible = false
	_unit_name_label.clear()
	_unit_name_label.add_theme_color_override("default_color", lvl_color.lightened(0.18))
	_unit_name_label.append_text(_build_inline_unit_name_rich_text(_unit))
	_unit_level_label.text = "Nivel %d" % int(_unit.level)
	_unit_level_label.add_theme_color_override("font_color", lvl_color.lightened(0.08))
	_unit_stats_label.text = _level_up_stat_summary(_unit)
	_apply_option_refs(_left_refs, _options[0], lvl_color)
	if _options.size() > 1:
		_apply_option_refs(_right_refs, _options[1], lvl_color)
		(_right_refs["button"] as Button).visible = true
	else:
		(_right_refs["button"] as Button).visible = false

func _focus_camera_on_unit() -> void:
	if camera_controller == null or hex_grid == null or _unit == null:
		return
	if hex_grid.has_method("get_unit_renderer"):
		_showcase_renderer = hex_grid.call("get_unit_renderer", _unit) as Node3D
		if _showcase_renderer != null:
			if _showcase_renderer.has_method("set_combat_mode"):
				_showcase_renderer.call("set_combat_mode")
			if _showcase_renderer.has_method("set_combat_focus"):
				_showcase_renderer.call("set_combat_focus", true)
	if hex_grid.has_method("get_unit_world_position") and camera_controller.has_method("enter_showcase_mode"):
		var world_pos: Vector3 = hex_grid.call("get_unit_world_position", _unit)
		camera_controller.call("enter_showcase_mode", world_pos, 1.72, 0.78, 58.0)
		if _showcase_renderer != null and _showcase_renderer.has_method("set_combat_facing"):
			_showcase_renderer.call("set_combat_facing", camera_controller.global_position)

func _build_option_card(pos: Vector2, index: int) -> Dictionary:
	var btn := Button.new()
	btn.position = pos
	btn.size = CARD_SIZE
	btn.text = ""
	btn.focus_mode = Control.FOCUS_NONE
	btn.clip_contents = true
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_stylebox_override("normal", _make_card_style(Color(0.18, 0.14, 0.10, 0.90), Color(0.95, 0.70, 0.18, 0.95), 3))
	btn.add_theme_stylebox_override("hover", _make_card_style(Color(0.23, 0.17, 0.12, 0.96), Color(1.0, 0.80, 0.26, 1.0), 4))
	btn.add_theme_stylebox_override("pressed", _make_card_style(Color(0.14, 0.11, 0.08, 0.98), Color(1.0, 0.88, 0.40, 1.0), 4))
	btn.add_theme_color_override("font_color", Color.TRANSPARENT)
	_overlay.add_child(btn)

	var idx_label := _make_label("[%d]" % index, 10, Color(0.58, 0.56, 0.52), HORIZONTAL_ALIGNMENT_CENTER)
	idx_label.position = Vector2(0.0, 18.0)
	idx_label.size = Vector2(CARD_SIZE.x, 14.0)
	btn.add_child(idx_label)

	var title_label := _make_label("", 20, Color(0.98, 0.86, 0.52), HORIZONTAL_ALIGNMENT_CENTER)
	title_label.position = Vector2(18.0, 66.0)
	title_label.size = Vector2(CARD_SIZE.x - 36.0, 26.0)
	btn.add_child(title_label)

	var type_label := _make_label("", 13, Color(0.94, 0.72, 0.22), HORIZONTAL_ALIGNMENT_CENTER)
	type_label.position = Vector2(18.0, 98.0)
	type_label.size = Vector2(CARD_SIZE.x - 36.0, 18.0)
	btn.add_child(type_label)

	var divider := ColorRect.new()
	divider.position = Vector2(0.0, 140.0)
	divider.size = Vector2(CARD_SIZE.x, 1.0)
	divider.color = Color(0.88, 0.72, 0.30, 0.46)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(divider)

	var desc_label := _make_label("", 14, Color(0.92, 0.88, 0.82), HORIZONTAL_ALIGNMENT_CENTER)
	desc_label.position = Vector2(24.0, 156.0)
	desc_label.size = Vector2(CARD_SIZE.x - 48.0, 58.0)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	btn.add_child(desc_label)

	return {
		"button": btn,
		"title": title_label,
		"type": type_label,
		"desc": desc_label,
	}

func _apply_option_refs(refs: Dictionary, bonus: Dictionary, accent: Color) -> void:
	var btn := refs.get("button") as Button
	if btn == null:
		return
	(refs.get("title") as Label).text = str(bonus.get("name", ""))
	var type_label := refs.get("type") as Label
	type_label.text = _blessing_type_text(str(bonus.get("type", "")))
	type_label.add_theme_color_override("font_color", accent)
	(refs.get("desc") as Label).text = str(bonus.get("description", ""))
	for connection: Dictionary in btn.pressed.get_connections():
		btn.pressed.disconnect(connection.callable)
	var bonus_id: String = str(bonus.get("id", ""))
	btn.pressed.connect(func() -> void: _select(bonus_id), CONNECT_ONE_SHOT)

func _select(bonus_id: String) -> void:
	if _left_refs.has("button"):
		(_left_refs["button"] as Button).disabled = true
	if _right_refs.has("button"):
		(_right_refs["button"] as Button).disabled = true
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_overlay, "modulate:a", 0.0, 0.16)
	await _tween.finished
	_restore_showcase_unit()
	if camera_controller != null and camera_controller.has_method("exit_showcase_mode"):
		var exit_tw: Tween = camera_controller.call("exit_showcase_mode")
		if exit_tw != null:
			await exit_tw.finished
	_disable_level_up_theater()
	_restore_unrelated_ui()
	visible = false
	bonus_chosen.emit(bonus_id)

func _restore_showcase_unit() -> void:
	if _showcase_renderer == null:
		return
	if _showcase_renderer.has_method("set_combat_focus"):
		_showcase_renderer.call("set_combat_focus", false)
	if _showcase_renderer.has_method("reset_combat_facing"):
		_showcase_renderer.call("reset_combat_facing")
	if _showcase_renderer.has_method("set_tactical_mode"):
		_showcase_renderer.call("set_tactical_mode")
	_showcase_renderer = null

func _hide_unrelated_ui() -> void:
	_hidden_ui.clear()
	for item: CanvasItem in [hud_ref, card_hand_ref]:
		if item == null or not is_instance_valid(item):
			continue
		if item.visible:
			_hidden_ui.append(item)
		item.visible = false

func _restore_unrelated_ui() -> void:
	for item: CanvasItem in _hidden_ui:
		if item != null and is_instance_valid(item):
			item.visible = true
	_hidden_ui.clear()

func _enable_level_up_theater() -> void:
	_using_parent_cinematic = false
	_using_board_theater = false
	var focus_cells: Array = []
	if _focus_cell != Vector2i(-1, -1):
		focus_cells.append(_focus_cell)
	var parent_node: Node = get_parent()
	if parent_node != null and parent_node.has_method("set_combat_cinematic_ui"):
		parent_node.call("set_combat_cinematic_ui", true, focus_cells)
		_using_parent_cinematic = true
	elif hex_grid != null and hex_grid.has_method("set_combat_board_theater"):
		hex_grid.call("set_combat_board_theater", true, focus_cells)
		_using_board_theater = true
	if hex_grid != null:
		if hex_grid.has_method("set_combat_team_rings_visible"):
			hex_grid.call("set_combat_team_rings_visible", false)
		if hex_grid.has_method("set_combat_unit_badges_visible"):
			hex_grid.call("set_combat_unit_badges_visible", false)

func _disable_level_up_theater() -> void:
	if hex_grid != null:
		if hex_grid.has_method("set_combat_team_rings_visible"):
			hex_grid.call("set_combat_team_rings_visible", true)
		if hex_grid.has_method("set_combat_unit_badges_visible"):
			hex_grid.call("set_combat_unit_badges_visible", true)
	if _using_parent_cinematic:
		var parent_node: Node = get_parent()
		if parent_node != null and parent_node.has_method("set_combat_cinematic_ui"):
			parent_node.call("set_combat_cinematic_ui", false, [])
	elif _using_board_theater and hex_grid != null and hex_grid.has_method("set_combat_board_theater"):
		hex_grid.call("set_combat_board_theater", false, [])
	_using_parent_cinematic = false
	_using_board_theater = false

func _update_spotlight() -> void:
	if _spotlight_rect == null or _spotlight_mat == null or _spotlight_mat.shader == null or camera_controller == null or hex_grid == null or _unit == null:
		return
	var world_pos: Vector3 = hex_grid.call("get_unit_world_position", _unit)
	var sample: Vector3 = world_pos + Vector3(0.0, 0.85, 0.0)
	if camera_controller.is_position_behind(sample):
		_spotlight_mat.set_shader_parameter("hole_a", Vector4(-1000.0, -1000.0, 0.0, 0.0))
		_spotlight_mat.set_shader_parameter("hole_b", Vector4(-1000.0, -1000.0, 0.0, 0.0))
		return
	var screen_pos: Vector2 = camera_controller.unproject_position(sample)
	var hole_rect := Rect2(screen_pos - Vector2(108.0, 108.0), Vector2(216.0, 216.0))
	_spotlight_mat.set_shader_parameter("hole_a", Vector4(-1000.0, -1000.0, 0.0, 0.0))
	_spotlight_mat.set_shader_parameter("hole_b", Vector4(hole_rect.position.x, hole_rect.position.y, hole_rect.size.x, hole_rect.size.y))

func _build_motes() -> void:
	for i: int in range(16):
		var mote := ColorRect.new()
		mote.size = Vector2(4.0 + randf() * 4.0, 4.0 + randf() * 8.0)
		mote.color = Color(1.0, 0.84, 0.34, 0.0)
		mote.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_overlay.add_child(mote)
		_motes.append({
			"node": mote,
			"x": randf_range(-54.0, 54.0),
			"y": randf_range(-150.0, 40.0),
			"speed": randf_range(18.0, 46.0),
			"drift": randf_range(-9.0, 9.0),
			"phase": randf_range(0.0, TAU),
		})

func _update_motes(delta: float) -> void:
	for mote_data: Dictionary in _motes:
		var node: ColorRect = mote_data.get("node") as ColorRect
		if node == null:
			continue
		var y: float = float(mote_data.get("y", 0.0)) + float(mote_data.get("speed", 20.0)) * delta
		if y > 154.0:
			y = randf_range(-160.0, -20.0)
			mote_data["x"] = randf_range(-58.0, 58.0)
			mote_data["speed"] = randf_range(18.0, 46.0)
		mote_data["y"] = y
		var phase: float = float(mote_data.get("phase", 0.0))
		var x: float = float(mote_data.get("x", 0.0)) + sin(_fx_time * 1.8 + phase) * float(mote_data.get("drift", 0.0))
		node.position = Vector2(640.0 + x, 208.0 + y)
		node.color = Color(1.0, 0.84, 0.34, 0.18 + 0.28 * sin(_fx_time * 2.4 + phase) * 0.5 + 0.14)

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_1:
			if _options.size() >= 1:
				get_viewport().set_input_as_handled()
				_select(str(_options[0].get("id", "")))
		KEY_2:
			if _options.size() >= 2:
				get_viewport().set_input_as_handled()
				_select(str(_options[1].get("id", "")))

func _animate_in() -> void:
	if _tween != null:
		_tween.kill()
	_overlay.modulate.a = 0.0
	(_left_refs["button"] as Button).scale = Vector2(0.94, 0.94)
	(_right_refs["button"] as Button).scale = Vector2(0.94, 0.94)
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_overlay, "modulate:a", 1.0, 0.20)
	_tween.tween_property(_left_refs["button"], "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_right_refs["button"], "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _make_label(text: String, font_size: int, color: Color, align: HorizontalAlignment) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.horizontal_alignment = align
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl

func _make_style(bg: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style

func _make_card_style(bg: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := _make_style(bg, border, border_width, 8)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	return style

func _display_name_for_unit(unit: Unit) -> String:
	if unit == null:
		return ""
	return str(UNIT_TYPE_DISPLAY_NAMES.get(int(unit.unit_type), str(unit.unit_name)))

func _level_up_stat_summary(unit: Unit) -> String:
	if unit == null:
		return ""
	if int(unit.unit_type) == -1:
		return "+vida  +poder"
	return "+vida  +daño"

func _build_inline_unit_name_rich_text(unit: Unit) -> String:
	if unit == null:
		return ""
	var icon_path: String = _get_class_icon_path(int(unit.unit_type))
	var unit_name: String = _display_name_for_unit(unit)
	if icon_path == "":
		return "[center]%s[/center]" % unit_name
	return "[center][img=22x22]%s[/img] %s[/center]" % [icon_path, unit_name]

func _get_class_icon_path(unit_type: int) -> String:
	if unit_type == -1:
		return MASTER_ICON_PATH
	return str(CLASS_ICON_PATHS.get(unit_type, ""))

func _blessing_type_text(blessing_type: String) -> String:
	match blessing_type:
		"global":
			return "BENDICION GENERAL"
		"warrior":
			return "BENDICION DE GUERRERO"
		"archer":
			return "BENDICION DE ARQUERO"
		"lancer":
			return "BENDICION DE LANCERO"
		"rider":
			return "BENDICION DE JINETE"
		"master":
			return "BENDICION DE MAESTRO"
		_:
			return "BENDICION"
