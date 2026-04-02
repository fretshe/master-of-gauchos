extends CanvasLayer

const UnitScript := preload("res://scripts/Unit.gd")
const SummonManagerScript := preload("res://scripts/SummonManager.gd")
const TutorialOutlineScript := preload("res://scripts/TutorialOutline.gd")
const TUTORIAL_ARROW_TEXTURE := preload("res://assets/sprites/ui/tutorial/tutorial_arrow_pixel.png")

signal unit_type_chosen(unit_type: int)
signal cancelled()

const UNIT_TYPES: Array[int] = [
	UnitScript.UnitType.WARRIOR,
	UnitScript.UnitType.ARCHER,
	UnitScript.UnitType.LANCER,
	UnitScript.UnitType.RIDER,
]

const TYPE_COSTS: Dictionary = SummonManagerScript.SUMMON_COSTS

const TYPE_ACCENTS: Dictionary = {
	UnitScript.UnitType.WARRIOR: Color(0.52, 0.90, 1.00, 1.0),
	UnitScript.UnitType.ARCHER: Color(0.42, 0.84, 1.00, 1.0),
	UnitScript.UnitType.LANCER: Color(0.62, 0.92, 1.00, 1.0),
	UnitScript.UnitType.RIDER: Color(0.74, 0.96, 1.00, 1.0),
}

const C_BG := Color(0.05, 0.06, 0.09, 0.78)
const C_PANEL := Color(0.08, 0.11, 0.15, 0.86)
const C_PANEL_SOFT := Color(0.14, 0.20, 0.26, 0.58)
const C_BORDER := Color(0.42, 0.88, 1.0, 0.28)
const C_TEXT := Color(0.96, 0.97, 1.0, 0.96)
const C_DIM := Color(0.70, 0.73, 0.82, 0.90)
const C_MUTED := Color(0.52, 0.56, 0.64, 0.88)
const C_ESSENCE := Color(0.42, 0.88, 1.0, 1.0)
const C_OK := Color(0.40, 0.96, 0.56, 1.0)
const C_NO := Color(1.0, 0.46, 0.46, 1.0)

var _player_id: int = 1
var _resource_manager = null
var _overlay: ColorRect = null
var _panel: Panel = null
var _essence_label: Label = null
var _player_label: Label = null
var _faction_label: Label = null
var _portrait_cache: Dictionary = {}
var _tutorial_focus_unit_type: int = -999

const CLASS_ICON_PATHS := {
	UnitScript.UnitType.WARRIOR: "res://assets/sprites/ui/class_icons/warrior_icon.png",
	UnitScript.UnitType.ARCHER: "res://assets/sprites/ui/class_icons/archer_icon.png",
	UnitScript.UnitType.LANCER: "res://assets/sprites/ui/class_icons/lancer_icon.png",
	UnitScript.UnitType.RIDER: "res://assets/sprites/ui/class_icons/rider_icon.png",
}
const MASTER_ICON_PATH := "res://assets/sprites/ui/class_icons/master_icon.png"
const UNIT_DISPLAY_NAMES := {
	UnitScript.UnitType.WARRIOR: "Guerrero",
	UnitScript.UnitType.ARCHER: "Arquero",
	UnitScript.UnitType.LANCER: "Lancero",
	UnitScript.UnitType.RIDER: "Jinete",
}

func _ready() -> void:
	layer = 20
	_build_ui()
	visible = false

func show_for_player(player_id: int, resource_mgr) -> void:
	_player_id = player_id
	_resource_manager = resource_mgr
	_refresh_cards()
	visible = true

func _process(_delta: float) -> void:
	_update_tutorial_card_focus()

func _build_ui() -> void:
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color = C_BG
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	_panel = _make_panel(Vector2(280.0, 120.0), Vector2(720.0, 470.0))
	add_child(_panel)

	var top_line := ColorRect.new()
	top_line.position = Vector2(26.0, 18.0)
	top_line.size = Vector2(668.0, 2.0)
	top_line.color = Color(C_ESSENCE.r, C_ESSENCE.g, C_ESSENCE.b, 0.24)
	_panel.add_child(top_line)

	var title := _make_label("INVOCAR UNIDAD", Vector2(28.0, 28.0), 24, C_ESSENCE.lightened(0.12))
	_panel.add_child(title)

	var subtitle := _make_label("Seleccioná una unidad para colocar junto a tu Maestro", Vector2(30.0, 56.0), 11, C_DIM)
	_panel.add_child(subtitle)

	_player_label = _make_label("", Vector2(30.0, 88.0), 16, C_TEXT)
	_panel.add_child(_player_label)

	_faction_label = _make_label("", Vector2(172.0, 90.0), 13, C_DIM)
	_panel.add_child(_faction_label)

	var essence_chip := _make_chip(Vector2(518.0, 24.0), Vector2(176.0, 58.0), C_ESSENCE, "ESENCIA")
	_panel.add_child(essence_chip)
	_essence_label = _make_label("", Vector2(18.0, 16.0), 28, C_ESSENCE)
	_essence_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_essence_label.size = Vector2(136.0, 32.0)
	essence_chip.add_child(_essence_label)

	var helper := _make_label("Las unidades invocadas no pueden moverse hasta el próximo turno", Vector2(30.0, 120.0), 11, C_MUTED)
	_panel.add_child(helper)

	var card_positions: Array[Vector2] = [
		Vector2(28.0, 154.0),
		Vector2(372.0, 154.0),
		Vector2(28.0, 304.0),
		Vector2(372.0, 304.0),
	]

	for i: int in range(UNIT_TYPES.size()):
		var card := _build_card(UNIT_TYPES[i], card_positions[i])
		_panel.add_child(card)

	var cancel := _make_action_button("Cancelar", Vector2(292.0, 430.0), Vector2(136.0, 28.0), false)
	cancel.pressed.connect(_on_cancel)
	_panel.add_child(cancel)

func _build_card(unit_type: int, rel_pos: Vector2) -> Button:
	var unit_preview: UnitScript = UnitScript.new()
	unit_preview.setup(_get_unit_name(unit_type), unit_type, _player_id, 1)
	var accent: Color = TYPE_ACCENTS.get(unit_type, Color.WHITE)

	var btn := Button.new()
	btn.position = rel_pos
	btn.size = Vector2(320.0, 132.0)
	btn.text = ""
	btn.name = "Card_%d" % unit_type
	btn.clip_contents = true
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var normal := StyleBoxFlat.new()
	normal.bg_color = C_PANEL
	normal.border_color = Color(C_ESSENCE.r, C_ESSENCE.g, C_ESSENCE.b, 0.16)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(2)
	btn.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.12, 0.17, 0.22, 0.94)
	hover.border_color = C_ESSENCE.lightened(0.14)
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(2)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(0.08, 0.12, 0.16, 0.96)
	pressed.border_color = C_ESSENCE
	pressed.set_border_width_all(1)
	pressed.set_corner_radius_all(2)
	btn.add_theme_stylebox_override("pressed", pressed)

	var disabled := StyleBoxFlat.new()
	disabled.bg_color = Color(0.08, 0.09, 0.13, 0.55)
	disabled.border_color = Color(0.50, 0.54, 0.62, 0.12)
	disabled.set_border_width_all(1)
	disabled.set_corner_radius_all(2)
	btn.add_theme_stylebox_override("disabled", disabled)

	var accent_glow := ColorRect.new()
	accent_glow.name = "AccentGlow"
	accent_glow.position = Vector2(0.0, 0.0)
	accent_glow.size = Vector2(4.0, btn.size.y)
	accent_glow.color = C_ESSENCE
	accent_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(accent_glow)

	var accent_fade := ColorRect.new()
	accent_fade.position = Vector2(0.0, 0.0)
	accent_fade.size = Vector2(btn.size.x, 20.0)
	accent_fade.color = Color(C_ESSENCE.r, C_ESSENCE.g, C_ESSENCE.b, 0.08)
	accent_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(accent_fade)

	var portrait_glow := ColorRect.new()
	portrait_glow.position = Vector2(12.0, 12.0)
	portrait_glow.size = Vector2(84.0, 108.0)
	portrait_glow.color = Color(C_ESSENCE.r, C_ESSENCE.g, C_ESSENCE.b, 0.10)
	portrait_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(portrait_glow)

	var tutorial_glow := ColorRect.new()
	tutorial_glow.name = "TutorialGlow"
	tutorial_glow.position = Vector2(6.0, 6.0)
	tutorial_glow.size = btn.size - Vector2(12.0, 12.0)
	tutorial_glow.color = Color(1.0, 0.88, 0.24, 0.0)
	tutorial_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tutorial_glow.visible = false
	btn.add_child(tutorial_glow)

	var tutorial_outline := TutorialOutlineScript.new()
	tutorial_outline.name = "TutorialOutline"
	tutorial_outline.position = Vector2(-6.0, -6.0)
	tutorial_outline.size = btn.size + Vector2(12.0, 12.0)
	tutorial_outline.visible = false
	btn.add_child(tutorial_outline)

	var tutorial_arrow := TextureRect.new()
	tutorial_arrow.name = "TutorialArrow"
	tutorial_arrow.texture = TUTORIAL_ARROW_TEXTURE
	tutorial_arrow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tutorial_arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tutorial_arrow.stretch_mode = TextureRect.STRETCH_SCALE
	var arrow_size: Vector2 = TUTORIAL_ARROW_TEXTURE.get_size() * 2.5
	tutorial_arrow.size = arrow_size if arrow_size != Vector2.ZERO else Vector2(20.0, 20.0)
	tutorial_arrow.pivot_offset = tutorial_arrow.size * 0.5
	tutorial_arrow.position = Vector2(btn.size.x * 0.5 - tutorial_arrow.size.x * 0.5, 6.0)
	tutorial_arrow.modulate = Color(1.0, 0.88, 0.24, 0.96)
	tutorial_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tutorial_arrow.visible = false
	btn.add_child(tutorial_arrow)

	var portrait_frame := ColorRect.new()
	portrait_frame.position = Vector2(16.0, 16.0)
	portrait_frame.size = Vector2(80.0, 100.0)
	portrait_frame.color = C_PANEL_SOFT
	portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(portrait_frame)

	var portrait_path: String = FactionData.get_sprite_path(GameData.get_faction_for_player(_player_id), unit_type)
	if ResourceLoader.exists(portrait_path):
		var bg_portrait := TextureRect.new()
		bg_portrait.name = "BgPortrait"
		bg_portrait.texture = _get_portrait_texture(portrait_path, unit_type, true)
		bg_portrait.position = Vector2(146.0, 8.0)
		bg_portrait.size = Vector2(154.0, 120.0)
		bg_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		bg_portrait.modulate = Color(1.0, 1.0, 1.0, 0.20)
		bg_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(bg_portrait)

		var portrait := TextureRect.new()
		portrait.name = "Portrait"
		portrait.texture = _get_portrait_texture(portrait_path, unit_type, false)
		portrait.position = Vector2(14.0, 14.0)
		portrait.size = Vector2(84.0, 108.0)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(portrait)
		btn.move_child(portrait, btn.get_child_count() - 1)

	var title := _make_label(_get_unit_name(unit_type), Vector2(126.0, 14.0), 17, C_TEXT)
	title.add_theme_color_override("font_color", C_ESSENCE.lightened(0.14))
	btn.add_child(title)

	var class_icon := TextureRect.new()
	class_icon.name = "ClassIcon"
	class_icon.position = Vector2(102.0, 14.0)
	class_icon.size = Vector2(18.0, 18.0)
	class_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	class_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	class_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	class_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	class_icon.modulate = Color(0.95, 0.98, 1.0, 0.92)
	class_icon.texture = load(_get_class_icon_path(unit_type))
	btn.add_child(class_icon)
	btn.move_child(class_icon, btn.get_child_count() - 1)

	var cost_box := Panel.new()
	cost_box.position = Vector2(226.0, 18.0)
	cost_box.size = Vector2(80.0, 40.0)
	cost_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cost_style := StyleBoxFlat.new()
	cost_style.bg_color = Color(0.10, 0.16, 0.22, 0.78)
	cost_style.border_color = Color(C_ESSENCE.r, C_ESSENCE.g, C_ESSENCE.b, 0.26)
	cost_style.set_border_width_all(1)
	cost_style.set_corner_radius_all(2)
	cost_box.add_theme_stylebox_override("panel", cost_style)
	btn.add_child(cost_box)

	var cost_line := ColorRect.new()
	cost_line.position = Vector2(0.0, 0.0)
	cost_line.size = Vector2(80.0, 2.0)
	cost_line.color = Color(C_ESSENCE.r, C_ESSENCE.g, C_ESSENCE.b, 0.72)
	cost_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_box.add_child(cost_line)

	var cost_label := _make_label("", Vector2(0.0, 4.0), 22, C_ESSENCE)
	cost_label.name = "CostLabel"
	cost_label.size = Vector2(80.0, 24.0)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.text = "%d" % TYPE_COSTS[unit_type]
	cost_box.add_child(cost_label)

	var cost_caption := _make_label("ESENCIA", Vector2(0.0, 26.0), 9, C_MUTED)
	cost_caption.size = Vector2(80.0, 12.0)
	cost_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_box.add_child(cost_caption)

	var stat_hp := _make_stat_line("Vida", "%d" % unit_preview.max_hp, Vector2(102.0, 52.0), accent)
	btn.add_child(stat_hp)
	var stat_mov := _make_stat_line("Mov", "%d" % unit_preview.move_range, Vector2(152.0, 52.0), accent)
	btn.add_child(stat_mov)
	var stat_rng := _make_stat_line("Alc", "%d" % unit_preview.attack_range, Vector2(202.0, 52.0), accent)
	btn.add_child(stat_rng)

	var melee_row := _make_label("M  %s" % _format_dice_row(unit_preview.get_melee_dice()), Vector2(102.0, 82.0), 11, C_DIM)
	btn.add_child(melee_row)
	var ranged_row := _make_label("R  %s" % _format_dice_row(unit_preview.get_ranged_dice()), Vector2(102.0, 98.0), 11, C_DIM)
	btn.add_child(ranged_row)

	var counter_icon := TextureRect.new()
	counter_icon.name = "CounterIcon"
	counter_icon.position = Vector2(102.0, 112.0)
	counter_icon.size = Vector2(14.0, 14.0)
	counter_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	counter_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	counter_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	counter_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	counter_icon.texture = load(_get_class_icon_path(_get_counter_target_unit_type(unit_type)))
	counter_icon.modulate = Color(0.88, 0.92, 1.0, 0.86)
	btn.add_child(counter_icon)

	var counter_row := _make_label(_get_counter_text(unit_type), Vector2(120.0, 114.0), 10, C_MUTED)
	counter_row.size = Vector2(172.0, 14.0)
	btn.add_child(counter_row)

	var status := _make_label("", Vector2(208.0, 110.0), 11, C_OK)
	status.name = "StatusLbl"
	status.size = Vector2(96.0, 16.0)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	btn.add_child(status)

	btn.pressed.connect(func(): _on_card_pressed(unit_type))
	return btn

func _refresh_cards() -> void:
	if _panel == null:
		return

	var essence: int = _resource_manager.get_essence(_player_id) if _resource_manager != null else 0
	var faction: int = GameData.get_faction_for_player(_player_id)
	_player_label.text = "Jugador %d" % _player_id
	_player_label.add_theme_color_override("font_color", GameData.get_player_color(_player_id))
	_faction_label.text = FactionData.get_faction_name(faction)
	_faction_label.add_theme_color_override("font_color", FactionData.get_color(faction))
	_essence_label.text = str(essence)

	for unit_type: int in UNIT_TYPES:
		var card := _panel.get_node_or_null("Card_%d" % unit_type) as Button
		if card == null:
			continue
		var cost: int = TYPE_COSTS[unit_type]
		var can_afford: bool = _resource_manager != null and _resource_manager.can_afford(_player_id, cost)
		card.disabled = not can_afford

		var status_lbl := card.get_node_or_null("StatusLbl") as Label
		if status_lbl != null:
			status_lbl.text = "Disponible" if can_afford else "Sin esencia"
			status_lbl.add_theme_color_override("font_color", C_OK if can_afford else C_NO)

		var cost_lbl := card.get_node_or_null("CostLabel") as Label
		if cost_lbl != null:
			cost_lbl.add_theme_color_override("font_color", C_ESSENCE if can_afford else C_MUTED)

		var accent_glow := card.get_node_or_null("AccentGlow") as ColorRect
		if accent_glow != null:
			accent_glow.color = Color(C_ESSENCE.r, C_ESSENCE.g, C_ESSENCE.b, 1.0 if can_afford else 0.32)

		var portrait := card.get_node_or_null("Portrait") as TextureRect
		if portrait != null:
			var portrait_path: String = FactionData.get_sprite_path(faction, unit_type)
			if ResourceLoader.exists(portrait_path):
				portrait.texture = _get_portrait_texture(portrait_path, unit_type, false)
		var bg_portrait := card.get_node_or_null("BgPortrait") as TextureRect
		if bg_portrait != null:
			var bg_path: String = FactionData.get_sprite_path(faction, unit_type)
			if ResourceLoader.exists(bg_path):
				bg_portrait.texture = _get_portrait_texture(bg_path, unit_type, true)
		var class_icon := card.get_node_or_null("ClassIcon") as TextureRect
		if class_icon != null:
			class_icon.texture = load(_get_class_icon_path(unit_type))
		var counter_icon := card.get_node_or_null("CounterIcon") as TextureRect
		if counter_icon != null:
			counter_icon.texture = load(_get_class_icon_path(_get_counter_target_unit_type(unit_type)))

func _on_card_pressed(unit_type: int) -> void:
	var cost: int = TYPE_COSTS[unit_type]
	if _resource_manager != null and not _resource_manager.can_afford(_player_id, cost):
		return
	clear_tutorial_focus()
	visible = false
	emit_signal("unit_type_chosen", unit_type)

func _on_cancel() -> void:
	clear_tutorial_focus()
	visible = false
	emit_signal("cancelled")

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_on_cancel()

func set_tutorial_focus_unit(unit_type: int) -> void:
	_tutorial_focus_unit_type = unit_type
	_update_tutorial_card_focus()

func clear_tutorial_focus() -> void:
	_tutorial_focus_unit_type = -999
	_update_tutorial_card_focus()

func _update_tutorial_card_focus() -> void:
	if _panel == null:
		return

	var pulse: float = 0.58 + 0.42 * (0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006))
	for unit_type: int in UNIT_TYPES:
		var card := _panel.get_node_or_null("Card_%d" % unit_type) as Button
		if card == null:
			continue
		var is_target: bool = visible and unit_type == _tutorial_focus_unit_type
		var bob: float = sin(Time.get_ticks_msec() * 0.006) * 4.0
		var glow := card.get_node_or_null("TutorialGlow") as ColorRect
		if glow != null:
			glow.visible = is_target
			if is_target:
				glow.color = Color(1.0, 0.88, 0.24, 0.10 + pulse * 0.18)
		var outline := card.get_node_or_null("TutorialOutline") as Control
		if outline != null:
			outline.visible = is_target
		var arrow := card.get_node_or_null("TutorialArrow") as TextureRect
		if arrow != null:
			arrow.visible = is_target
			if is_target:
				arrow.position = Vector2(card.size.x * 0.5 - arrow.size.x * 0.5, 6.0 + bob)

func _make_panel(pos: Vector2, sz: Vector2) -> Panel:
	var panel := Panel.new()
	panel.position = pos
	panel.size = sz
	var style := StyleBoxFlat.new()
	style.bg_color = C_BG
	style.border_color = C_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _make_label(text: String, pos: Vector2, fs: int, col: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.position = pos
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", fs)
	lbl.add_theme_color_override("font_color", col)
	return lbl

func _make_chip(pos: Vector2, sz: Vector2, accent: Color, caption: String) -> Panel:
	var chip := Panel.new()
	chip.position = pos
	chip.size = sz
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.12, 0.18, 0.82)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.48)
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	chip.add_theme_stylebox_override("panel", style)

	var accent_line := ColorRect.new()
	accent_line.position = Vector2(0.0, 0.0)
	accent_line.size = Vector2(sz.x, 2.0)
	accent_line.color = Color(accent.r, accent.g, accent.b, 0.75)
	accent_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(accent_line)

	var lbl := _make_label(caption, Vector2(18.0, 6.0), 11, C_MUTED.lightened(0.12))
	chip.add_child(lbl)
	return chip

func _make_action_button(text: String, pos: Vector2, sz: Vector2, is_primary: bool) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.position = pos
	btn.size = sz
	btn.add_theme_font_size_override("font_size", 12)
	btn.add_theme_color_override("font_color", C_TEXT if is_primary else C_DIM)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.11, 0.16, 0.86)
	style.border_color = Color(0.82, 0.88, 1.0, 0.18)
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	for key: String in ["normal", "hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(key, style)
	return btn

func _make_stat_line(label_text: String, value_text: String, pos: Vector2, accent: Color) -> Control:
	var root := Control.new()
	root.position = pos
	root.size = Vector2(46.0, 32.0)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var cap := _make_label(label_text, Vector2.ZERO, 11, C_MUTED.lightened(0.10))
	root.add_child(cap)

	var val := _make_label(value_text, Vector2(0.0, 11.0), 18, accent.lightened(0.16))
	root.add_child(val)
	return root

func _get_unit_name(unit_type: int) -> String:
	return UNIT_DISPLAY_NAMES.get(unit_type, "Unidad")

func _get_class_icon_path(unit_type: int) -> String:
	return CLASS_ICON_PATHS.get(unit_type, MASTER_ICON_PATH)

func _format_dice_row(dice: Array) -> String:
	if dice.is_empty():
		return "-"
	var parts: Array[String] = []
	for die_value: Variant in dice:
		parts.append(_dice_color_name(int(die_value)))
	return "/".join(parts)

func _dice_color_name(die_color: int) -> String:
	match die_color:
		UnitScript.DiceColor.BRONZE:
			return "Br"
		UnitScript.DiceColor.SILVER:
			return "Pl"
		UnitScript.DiceColor.GOLD:
			return "Or"
		UnitScript.DiceColor.PLATINUM:
			return "Pt"
		UnitScript.DiceColor.DIAMOND:
			return "Di"
		_:
			return "-"

func _get_counter_text(unit_type: int) -> String:
	for pair: Array in UnitScript.COUNTER_CHART:
		if int(pair[0]) == unit_type:
			return "Ventaja vs %s" % _get_unit_name(int(pair[1]))
	return ""

func _get_counter_target_unit_type(unit_type: int) -> int:
	for pair: Array in UnitScript.COUNTER_CHART:
		if int(pair[0]) == unit_type:
			return int(pair[1])
	return unit_type

func _get_portrait_texture(path: String, unit_type: int = -999, background_variant: bool = false) -> Texture2D:
	var cache_key: String = "%s|%d|%s" % [path, unit_type, "bg" if background_variant else "main"]
	if _portrait_cache.has(cache_key):
		return _portrait_cache[cache_key]
	var base_texture: Texture2D = load(path)
	if base_texture == null:
		return null
	var image: Image = base_texture.get_image()
	if image == null or image.is_empty():
		_portrait_cache[cache_key] = base_texture
		return base_texture

	var min_x: int = image.get_width()
	var min_y: int = image.get_height()
	var max_x: int = -1
	var max_y: int = -1
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			if image.get_pixel(x, y).a <= 0.02:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)

	if max_x < min_x or max_y < min_y:
		_portrait_cache[cache_key] = base_texture
		return base_texture

	var margin: int = 6
	var start_x: int = maxi(0, min_x - margin)
	var start_y: int = maxi(0, min_y - margin)
	var width: int = mini(image.get_width() - start_x, (max_x - min_x + 1) + margin * 2)
	var height: int = mini(image.get_height() - start_y, (max_y - min_y + 1) + margin * 2)

	if unit_type == UnitScript.UnitType.RIDER:
		start_x = clampi(min_x + 55, 0, image.get_width() - 1)
		start_y = clampi(min_y - 10, 0, image.get_height() - 1)
		width = mini(image.get_width() - start_x, 92 if not background_variant else 118)
		height = mini(image.get_height() - start_y, image.get_height() - start_y)

	if background_variant:
		start_x = maxi(0, start_x - 10)
		start_y = maxi(0, start_y - 4)
		width = mini(image.get_width() - start_x, width + 18)
		height = mini(image.get_height() - start_y, height + 10)

	var region := Rect2(
		start_x,
		start_y,
		width,
		height
	)
	var atlas := AtlasTexture.new()
	atlas.atlas = base_texture
	atlas.region = region
	_portrait_cache[cache_key] = atlas
	return atlas
