extends CanvasLayer

const TutorialOutlineScript := preload("res://scripts/TutorialOutline.gd")
const CardGlossShader := preload("res://shaders/card_gloss.gdshader")
const HAND_LEFT_BOUND := 540.0
const HAND_RIGHT_BOUND := 1104.0
const HAND_BOTTOM_Y := 700.0
const HAND_MAX_VISIBLE_SLOTS := 5
const CARD_SLOT_SIZE := Vector2(114.0, 154.0)
const CARD_SLOT_SPACING := 12.0
const PREVIEW_MARGIN := 18.0

var turn_manager: Node = null
var hex_grid: Node = null

signal tutorial_card_target_mode_changed(active: bool)

var _root: Control = null
var _panel: Panel = null
var _tutorial_outline: TutorialOutline = null
var _message_label: Label = null
var _preview_panel: Panel = null
var _preview_title: Label = null
var _preview_value: Label = null
var _preview_body: RichTextLabel = null
var _preview_target: RichTextLabel = null
var _slot_nodes: Array[Dictionary] = []
var _hovered_card_index: int = -1
var _armed_card_index: int = -1
var _fx_time: float = 0.0
var _consume_overlay: Control = null

func _ready() -> void:
	layer = 10
	_build_ui()
	CardManager.hand_changed.connect(_on_hand_changed)
	CardManager.card_played.connect(_on_card_played)
	CardManager.message_emitted.connect(_show_message)
	if turn_manager != null:
		turn_manager.turn_changed.connect(_on_turn_changed)
	refresh_hand()

func _process(delta: float) -> void:
	_fx_time += delta
	_update_card_motes()
	_update_card_gloss()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
		if _armed_card_index >= 0:
			_cancel_armed_card()
			get_viewport().set_input_as_handled()

func refresh_hand() -> void:
	var player_id: int = turn_manager.current_player if turn_manager != null else 1
	var hand: Array = CardManager.get_hand(player_id)
	var spent: bool = CardManager.used_card_this_turn
	_layout_hand_slots(min(hand.size(), _slot_nodes.size()))

	for i: int in range(_slot_nodes.size()):
		var slot: Dictionary = _slot_nodes[i]
		var panel: Panel = slot["panel"] as Panel
		var art_rect: TextureRect = slot["art"] as TextureRect
		var value_label: Label = slot["value"] as Label
		var type_label: Label = slot["type"] as Label
		var icon_label: Label = slot["icon"] as Label
		var button: Button = slot["button"] as Button
		var style: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
		var motes: Array = slot["motes"] as Array

		if i >= hand.size():
			panel.visible = false
			button.disabled = true
			for mote_value: Variant in motes:
				var mote: ColorRect = mote_value as ColorRect
				if mote != null:
					mote.visible = false
			continue

		var card: Dictionary = hand[i]
		var card_color: Color = _card_color(str(card.get("color", "cyan")))
		var is_active: bool = not spent and (i == _armed_card_index or (_armed_card_index == -1 and i == _hovered_card_index))
		var is_dimmed: bool = not spent and _has_active_card() and not is_active
		var spent_tint: Color = Color(0.42, 0.42, 0.42, 0.92) if spent else Color(1.0, 1.0, 1.0, 1.0)
		var gloss_material: ShaderMaterial = slot.get("gloss_material") as ShaderMaterial

		panel.visible = true
		button.disabled = spent
		value_label.text = str(int(card.get("value", 0)))
		type_label.text = _card_slot_title(card)
		icon_label.visible = false
		if art_rect != null:
			var art_path: String = _card_art_path(card, player_id)
			art_rect.texture = load(art_path) if art_path != "" and ResourceLoader.exists(art_path) else null
			art_rect.modulate = spent_tint
		panel.pivot_offset = panel.size * 0.5
		panel.scale = Vector2(1.12, 1.12) if is_active else Vector2.ONE
		panel.modulate = Color(1.0, 1.0, 1.0, 0.88) if spent else Color.WHITE
		panel.rotation = 0.0
		type_label.modulate = spent_tint
		value_label.modulate = spent_tint
		icon_label.modulate = spent_tint

		if gloss_material != null and gloss_material.shader != null:
			gloss_material.set_shader_parameter("accent_color", Vector4(card_color.r, card_color.g, card_color.b, 1.0))
			gloss_material.set_shader_parameter("hover_amount", 1.0 if is_active else 0.0)
			gloss_material.set_shader_parameter("spent_amount", 1.0 if spent else 0.0)
			gloss_material.set_shader_parameter("fx_time", _fx_time)

		if style != null:
			style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
			if card.has("faction") or str(card.get("type", "")) == "faction":
				style.border_color = Color(0.52, 0.52, 0.52, 0.72) if spent else Color(0.94, 0.74, 0.22, 0.85)
				style.set_border_width_all(2)
				style.set_corner_radius_all(2)
			else:
				style.border_color = Color(0.0, 0.0, 0.0, 0.0)
				style.set_border_width_all(0)

		for mote_value: Variant in motes:
			var mote: ColorRect = mote_value as ColorRect
			if mote != null:
				mote.visible = is_active and not spent
				mote.color = Color(card_color.r, card_color.g, card_color.b, 0.0)

	_update_preview(hand, spent)

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_panel = Panel.new()
	_panel.position = Vector2(HAND_LEFT_BOUND, HAND_BOTTOM_Y - 168.0)
	_panel.size = Vector2(HAND_RIGHT_BOUND - HAND_LEFT_BOUND, 168.0)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	panel_style.border_color = Color(0.0, 0.0, 0.0, 0.0)
	panel_style.set_border_width_all(0)
	_panel.add_theme_stylebox_override("panel", panel_style)
	_root.add_child(_panel)

	_consume_overlay = Control.new()
	_consume_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_consume_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_consume_overlay)

	_tutorial_outline = TutorialOutlineScript.new()
	_tutorial_outline.position = _panel.position - Vector2(8.0, 8.0)
	_tutorial_outline.size = _panel.size + Vector2(16.0, 16.0)
	_tutorial_outline.visible = false
	_root.add_child(_tutorial_outline)

	_message_label = Label.new()
	_message_label.position = Vector2(HAND_LEFT_BOUND + 18.0, HAND_BOTTOM_Y - 174.0)
	_message_label.size = Vector2(HAND_RIGHT_BOUND - HAND_LEFT_BOUND - 36.0, 24.0)
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.add_theme_font_size_override("font_size", 14)
	_message_label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.96, 0.0))
	_root.add_child(_message_label)

	_preview_panel = Panel.new()
	_preview_panel.position = Vector2(576.0, 360.0)
	_preview_panel.size = Vector2(490.0, 168.0)
	_preview_panel.visible = false
	_preview_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var preview_style := StyleBoxFlat.new()
	preview_style.bg_color = Color(0.06, 0.08, 0.11, 0.96)
	preview_style.border_color = Color(0.94, 0.96, 1.0, 0.18)
	preview_style.set_border_width_all(1)
	preview_style.set_corner_radius_all(3)
	_preview_panel.add_theme_stylebox_override("panel", preview_style)
	_root.add_child(_preview_panel)

	_preview_title = Label.new()
	_preview_title.position = Vector2(18.0, 14.0)
	_preview_title.size = Vector2(320.0, 26.0)
	_preview_title.add_theme_font_size_override("font_size", 22)
	_preview_title.add_theme_color_override("font_color", Color(0.96, 0.97, 1.0, 0.98))
	_preview_panel.add_child(_preview_title)

	_preview_value = Label.new()
	_preview_value.position = Vector2(360.0, 12.0)
	_preview_value.size = Vector2(108.0, 32.0)
	_preview_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_preview_value.add_theme_font_size_override("font_size", 28)
	_preview_value.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.98))
	_preview_panel.add_child(_preview_value)

	_preview_body = RichTextLabel.new()
	_preview_body.position = Vector2(18.0, 48.0)
	_preview_body.size = Vector2(454.0, 60.0)
	_preview_body.bbcode_enabled = true
	_preview_body.fit_content = false
	_preview_body.scroll_active = false
	_preview_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview_body.add_theme_font_size_override("normal_font_size", 16)
	_preview_body.add_theme_color_override("default_color", Color(0.88, 0.91, 0.98, 0.94))
	_preview_panel.add_child(_preview_body)

	_preview_target = RichTextLabel.new()
	_preview_target.position = Vector2(18.0, 118.0)
	_preview_target.size = Vector2(454.0, 24.0)
	_preview_target.bbcode_enabled = true
	_preview_target.fit_content = false
	_preview_target.scroll_active = false
	_preview_target.add_theme_font_size_override("normal_font_size", 13)
	_preview_target.add_theme_color_override("default_color", Color(0.70, 0.82, 0.96, 0.92))
	_preview_panel.add_child(_preview_target)

	for i: int in range(HAND_MAX_VISIBLE_SLOTS):
		var slot_panel := Panel.new()
		slot_panel.position = Vector2(0.0, 6.0)
		slot_panel.size = CARD_SLOT_SIZE
		slot_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		slot_panel.self_modulate = Color(1.0, 1.0, 1.0, 0.0)

		var art_rect := TextureRect.new()
		art_rect.position = Vector2(0.0, 0.0)
		art_rect.size = CARD_SLOT_SIZE
		art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		art_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var gloss_material := ShaderMaterial.new()
		if CardGlossShader != null:
			gloss_material.shader = CardGlossShader
			art_rect.material = gloss_material
		slot_panel.add_child(art_rect)

		var motes: Array = []
		for mote_index: int in range(4):
			var mote := ColorRect.new()
			mote.size = Vector2(6.0, 6.0)
			mote.position = Vector2(30.0 + float(mote_index) * 15.0, 130.0)
			mote.color = Color(1.0, 1.0, 1.0, 0.0)
			mote.mouse_filter = Control.MOUSE_FILTER_IGNORE
			mote.visible = false
			slot_panel.add_child(mote)
			motes.append(mote)

		var slot_style := StyleBoxFlat.new()
		slot_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
		slot_style.border_color = Color(0.0, 0.0, 0.0, 0.0)
		slot_style.set_border_width_all(0)
		slot_panel.add_theme_stylebox_override("panel", slot_style)
		_panel.add_child(slot_panel)

		var type_label := Label.new()
		type_label.position = Vector2(12.0, 1.0)
		type_label.size = Vector2(90.0, 20.0)
		type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		type_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		type_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		type_label.add_theme_font_size_override("font_size", 8)
		type_label.add_theme_color_override("font_color", Color(0.98, 0.98, 1.0))
		type_label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.03, 0.95))
		type_label.add_theme_constant_override("outline_size", 2)
		slot_panel.add_child(type_label)

		var icon_label := Label.new()
		icon_label.position = Vector2(0.0, 38.0)
		icon_label.size = Vector2(114.0, 20.0)
		icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_label.add_theme_font_size_override("font_size", 18)
		icon_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
		slot_panel.add_child(icon_label)

		var value_label := Label.new()
		value_label.position = Vector2(0.0, 106.0)
		value_label.size = Vector2(114.0, 36.0)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		value_label.add_theme_font_size_override("font_size", 32)
		value_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
		value_label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.03, 0.95))
		value_label.add_theme_constant_override("outline_size", 3)
		slot_panel.add_child(value_label)

		var button := Button.new()
		button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		button.flat = true
		var empty := StyleBoxEmpty.new()
		for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
			button.add_theme_stylebox_override(state, empty)
		button.pressed.connect(func(index := i): _on_card_pressed(index))
		button.mouse_entered.connect(func(index := i): _on_card_hovered(index))
		button.mouse_exited.connect(func(index := i): _on_card_unhovered(index))
		slot_panel.add_child(button)

		_slot_nodes.append({
			"panel": slot_panel,
			"art": art_rect,
			"gloss_material": gloss_material,
			"motes": motes,
			"type": type_label,
			"icon": icon_label,
			"value": value_label,
			"button": button,
		})

	_layout_hand_slots(HAND_MAX_VISIBLE_SLOTS)

func set_tutorial_highlight(active: bool) -> void:
	if _tutorial_outline != null:
		_tutorial_outline.visible = active

func get_tutorial_focus_rect() -> Rect2:
	if _panel == null:
		return Rect2()
	return Rect2(_panel.position - Vector2(8.0, 8.0), _panel.size + Vector2(16.0, 16.0))

func get_card_focus_rect(card_index: int) -> Rect2:
	if card_index < 0 or card_index >= _slot_nodes.size():
		return get_tutorial_focus_rect()
	var slot: Dictionary = _slot_nodes[card_index]
	var panel: Panel = slot.get("panel") as Panel
	if panel == null or not panel.visible:
		return get_tutorial_focus_rect()
	return Rect2(panel.global_position - Vector2(6.0, 6.0), panel.size + Vector2(12.0, 12.0))

func get_card_screen_position(card_index: int) -> Vector2:
	if card_index < 0 or card_index >= _slot_nodes.size():
		return Vector2.ZERO
	var slot: Dictionary = _slot_nodes[card_index]
	var panel: Panel = slot.get("panel") as Panel
	if panel == null or not panel.visible:
		return Vector2.ZERO
	return panel.global_position + panel.size * 0.5

func play_card_use_transition(card_index: int) -> void:
	if _consume_overlay == null or card_index < 0 or card_index >= _slot_nodes.size():
		return
	var slot: Dictionary = _slot_nodes[card_index]
	var panel: Panel = slot.get("panel") as Panel
	var art_rect: TextureRect = slot.get("art") as TextureRect
	var type_label: Label = slot.get("type") as Label
	var value_label: Label = slot.get("value") as Label
	if panel == null or art_rect == null or not panel.visible:
		return

	var card: Dictionary = {}
	if turn_manager != null:
		var hand: Array = CardManager.get_hand(turn_manager.current_player)
		if card_index >= 0 and card_index < hand.size():
			card = hand[card_index]
	var card_color: Color = _card_color(str(card.get("color", "cyan")))

	var ghost := Control.new()
	ghost.position = panel.global_position
	ghost.size = panel.size
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_consume_overlay.add_child(ghost)

	var glow := ColorRect.new()
	glow.position = Vector2(-8.0, -8.0)
	glow.size = panel.size + Vector2(16.0, 16.0)
	glow.color = Color(card_color.r, card_color.g, card_color.b, 0.20)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.add_child(glow)

	var art_clone := TextureRect.new()
	art_clone.position = Vector2.ZERO
	art_clone.size = panel.size
	art_clone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art_clone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art_clone.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art_clone.texture = art_rect.texture
	art_clone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.add_child(art_clone)

	var title_clone := Label.new()
	title_clone.position = type_label.position
	title_clone.size = type_label.size
	title_clone.text = type_label.text
	title_clone.horizontal_alignment = type_label.horizontal_alignment
	title_clone.vertical_alignment = type_label.vertical_alignment
	title_clone.autowrap_mode = type_label.autowrap_mode
	title_clone.add_theme_font_size_override("font_size", 8)
	title_clone.add_theme_color_override("font_color", Color.WHITE)
	title_clone.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.03, 0.95))
	title_clone.add_theme_constant_override("outline_size", 2)
	ghost.add_child(title_clone)

	var value_clone := Label.new()
	value_clone.position = value_label.position
	value_clone.size = value_label.size
	value_clone.text = value_label.text
	value_clone.horizontal_alignment = value_label.horizontal_alignment
	value_clone.vertical_alignment = value_label.vertical_alignment
	value_clone.add_theme_font_size_override("font_size", 32)
	value_clone.add_theme_color_override("font_color", Color.WHITE)
	value_clone.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.03, 0.95))
	value_clone.add_theme_constant_override("outline_size", 3)
	ghost.add_child(value_clone)

	for i: int in range(14):
		var spark := ColorRect.new()
		var spark_size: float = randf_range(4.0, 8.0)
		spark.size = Vector2.ONE * spark_size
		spark.position = Vector2(
			randf_range(18.0, panel.size.x - 18.0),
			randf_range(20.0, panel.size.y - 28.0)
		)
		spark.color = Color(card_color.r, card_color.g, card_color.b, randf_range(0.55, 0.96))
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ghost.add_child(spark)
		var spark_tw := create_tween().set_parallel(true)
		spark_tw.tween_property(
			spark,
			"position",
			spark.position + Vector2(randf_range(-30.0, 30.0), randf_range(-70.0, -24.0)),
			0.26
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		spark_tw.tween_property(spark, "modulate:a", 0.0, 0.26)
		spark_tw.tween_property(spark, "scale", Vector2.ONE * randf_range(0.25, 0.58), 0.26)

	panel.visible = false
	var tw := create_tween().set_parallel(true)
	tw.tween_property(ghost, "position:y", ghost.position.y - 28.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(ghost, "scale", Vector2(1.09, 1.09), 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(ghost, "modulate:a", 0.0, 0.24).set_delay(0.04)
	await tw.finished
	if is_instance_valid(ghost):
		ghost.queue_free()
	panel.visible = true

func _on_card_pressed(card_index: int) -> void:
	if turn_manager == null:
		return
	if CardManager.used_card_this_turn:
		_show_message("Ya usaste una carta", Color(0.96, 0.84, 0.28))
		return

	var player_id: int = turn_manager.current_player
	var hand: Array = CardManager.get_hand(player_id)
	if card_index < 0 or card_index >= hand.size():
		return
	var card: Dictionary = hand[card_index]

	if str(card.get("type", "")) == "essence":
		await play_card_use_transition(card_index)
		CardManager.play_card(player_id, card_index)
		_armed_card_index = -1
		emit_signal("tutorial_card_target_mode_changed", false)
		return

	if hex_grid != null and hex_grid.has_method("enter_card_target_mode"):
		_armed_card_index = card_index
		refresh_hand()
		hex_grid.call("enter_card_target_mode", player_id, card_index, card)
		emit_signal("tutorial_card_target_mode_changed", true)
		_show_message("Selecciona una unidad objetivo", _card_color(str(card.get("color", "cyan"))))

func _on_hand_changed(player_id: int) -> void:
	if turn_manager == null or player_id != turn_manager.current_player:
		return
	_armed_card_index = -1
	emit_signal("tutorial_card_target_mode_changed", false)
	refresh_hand()

func _on_card_played(_player_id: int, _card: Dictionary) -> void:
	_armed_card_index = -1
	emit_signal("tutorial_card_target_mode_changed", false)
	refresh_hand()

func _on_turn_changed(_player_id: int) -> void:
	_hovered_card_index = -1
	_armed_card_index = -1
	emit_signal("tutorial_card_target_mode_changed", false)
	refresh_hand()

func _on_card_hovered(card_index: int) -> void:
	_hovered_card_index = card_index
	refresh_hand()

func _on_card_unhovered(card_index: int) -> void:
	if _hovered_card_index == card_index:
		_hovered_card_index = -1
	refresh_hand()

func _has_active_card() -> bool:
	return _armed_card_index >= 0 or _hovered_card_index >= 0

func _update_preview(hand: Array, spent: bool) -> void:
	if _preview_panel == null:
		return
	if _armed_card_index >= 0:
		_preview_panel.visible = false
		return
	var preview_index: int = _hovered_card_index
	if spent or preview_index < 0 or preview_index >= hand.size():
		_preview_panel.visible = false
		return

	var card: Dictionary = hand[preview_index]
	var card_color: Color = _card_color(str(card.get("color", "cyan")))
	var preview_style: StyleBoxFlat = _preview_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if preview_style != null:
		preview_style.border_color = Color(card_color.r, card_color.g, card_color.b, 0.46)
		preview_style.bg_color = card_color.darkened(0.82)

	_preview_title.text = _card_display_name(card)
	_preview_value.text = str(int(card.get("value", 0)))
	_preview_value.add_theme_color_override("font_color", card_color.lightened(0.16))
	_preview_body.clear()
	_preview_body.append_text(_format_card_preview_rich_text(_card_description(card)))
	_preview_target.clear()
	_preview_target.append_text(_format_card_preview_rich_text(_card_target_text(card), true))
	_preview_target.add_theme_color_override("default_color", Color(card_color.r, card_color.g, card_color.b, 0.92))
	_position_preview_panel(preview_index)
	_preview_panel.visible = true

func _cancel_armed_card() -> void:
	_armed_card_index = -1
	if hex_grid != null and hex_grid.has_method("exit_card_target_mode"):
		hex_grid.call("exit_card_target_mode")
	emit_signal("tutorial_card_target_mode_changed", false)
	_show_message("Carta cancelada", Color(0.82, 0.82, 0.88, 1.0))
	refresh_hand()

func _update_card_motes() -> void:
	for i: int in range(_slot_nodes.size()):
		var slot: Dictionary = _slot_nodes[i]
		var panel: Panel = slot["panel"] as Panel
		var motes: Array = slot["motes"] as Array
		if panel == null or not panel.visible:
			continue
		var is_active: bool = i == _armed_card_index or (_armed_card_index == -1 and i == _hovered_card_index)
		if not is_active:
			continue
		var hand: Array = CardManager.get_hand(turn_manager.current_player if turn_manager != null else 1)
		if i >= hand.size():
			continue
		var card: Dictionary = hand[i]
		var base_color: Color = _card_color(str(card.get("color", "cyan"))).lightened(0.28)
		for mote_index: int in range(motes.size()):
			var mote: ColorRect = motes[mote_index] as ColorRect
			if mote == null:
				continue
			var phase: float = _fx_time * 3.4 + float(mote_index) * 0.8
			var blink: float = 0.5 + 0.5 * sin(phase)
			var flash: float = smoothstep(0.38, 0.96, blink)
			var sway_x: float = sin(phase * 1.3) * 5.0
			var rise: float = fmod(_fx_time * (18.0 + float(mote_index) * 1.8), 34.0)
			mote.position = Vector2(12.0 + float(mote_index) * 14.0 + sway_x, 90.0 - rise)
			mote.color = Color(base_color.r, base_color.g, base_color.b, 0.25 + flash * 0.95)

func _update_card_gloss() -> void:
	var mouse_position := get_viewport().get_mouse_position()
	for i: int in range(_slot_nodes.size()):
		var slot: Dictionary = _slot_nodes[i]
		var panel: Panel = slot.get("panel") as Panel
		var material: ShaderMaterial = slot.get("gloss_material") as ShaderMaterial
		if panel == null or material == null or material.shader == null or not panel.visible:
			continue
		var active: bool = i == _armed_card_index or (_armed_card_index == -1 and i == _hovered_card_index)
		var rect := Rect2(panel.global_position, panel.size)
		var local_mouse := mouse_position - rect.position
		var mouse_uv := Vector2(
			clamp(local_mouse.x / max(rect.size.x, 1.0), 0.0, 1.0),
			clamp(local_mouse.y / max(rect.size.y, 1.0), 0.0, 1.0)
		)
		var hover_value: float = 1.0 if active and rect.has_point(mouse_position) else 0.0
		material.set_shader_parameter("mouse_uv", mouse_uv)
		material.set_shader_parameter("hover_amount", hover_value)
		material.set_shader_parameter("fx_time", _fx_time)
		if active:
			var centered := mouse_uv - Vector2(0.5, 0.5)
			panel.rotation = centered.x * 0.08
		else:
			panel.rotation = lerpf(panel.rotation, 0.0, 0.22)

func _layout_hand_slots(visible_count: int) -> void:
	if _panel == null:
		return
	var clamped_count: int = clampi(visible_count, 0, _slot_nodes.size())
	if clamped_count <= 0:
		return
	var total_width: float = float(clamped_count) * CARD_SLOT_SIZE.x + float(max(clamped_count - 1, 0)) * CARD_SLOT_SPACING
	var start_x: float = max((_panel.size.x - total_width) * 0.5, 0.0)
	for i: int in range(_slot_nodes.size()):
		var slot: Dictionary = _slot_nodes[i]
		var panel: Panel = slot.get("panel") as Panel
		if panel == null:
			continue
		panel.position = Vector2(start_x + float(i) * (CARD_SLOT_SIZE.x + CARD_SLOT_SPACING), 6.0)

func _position_preview_panel(card_index: int) -> void:
	if _preview_panel == null:
		return
	var card_center: Vector2 = get_card_screen_position(card_index)
	if card_center == Vector2.ZERO:
		return
	var preview_width: float = _preview_panel.size.x
	var preview_height: float = _preview_panel.size.y
	var min_x: float = HAND_LEFT_BOUND
	var max_x: float = HAND_RIGHT_BOUND - preview_width
	var target_x: float = clampf(card_center.x - preview_width * 0.5, min_x, max_x)
	var target_y: float = max(card_center.y - preview_height - PREVIEW_MARGIN, 324.0)
	_preview_panel.position = Vector2(target_x, target_y)

func _card_color(color_name: String) -> Color:
	match color_name:
		"cyan":
			return Color(0.18, 0.82, 0.96, 0.96)
		"teal":
			return Color(0.34, 0.86, 0.42, 0.96)
		"red":
			return Color(0.84, 0.22, 0.22, 0.96)
		"purple":
			return Color(0.58, 0.30, 0.88, 0.96)
		"gold":
			return Color(0.94, 0.74, 0.22, 0.98)
		_:
			return Color(0.30, 0.30, 0.36, 0.96)

func _card_name(card: Dictionary) -> String:
	if card.has("label"):
		return str(card.get("label", "?"))
	match str(card.get("type", "")):
		"essence":
			return "ES"
		"heal":
			return "HP"
		"damage":
			return "DMG"
		"exp":
			return "XP"
		_:
			return "?"

func _card_display_name(card: Dictionary) -> String:
	if card.has("display_name"):
		return str(card.get("display_name", "Carta"))
	match str(card.get("type", "")):
		"essence":
			return "Esencia"
		"heal":
			return "Curación"
		"damage":
			return "Daño"
		"exp":
			return "Experiencia"
		"refresh":
			return "Refresco"
		_:
			return "Carta"

func _card_description(card: Dictionary) -> String:
	if card.has("description"):
		return str(card.get("description", ""))
	var value: int = int(card.get("value", 0))
	match str(card.get("type", "")):
		"essence":
			return "Otorga %d de esencia de inmediato para ayudarte a invocar o sostener el turno." % value
		"heal":
			return "Cura %d puntos de vida a una unidad aliada herida." % value
		"damage":
			return "Inflige %d de daño directo a una unidad enemiga que no sea Maestro." % value
		"exp":
			return "Otorga %d de experiencia a una unidad aliada para acelerar su progreso." % value
		"refresh":
			return "Refresca una unidad aliada que ya actuó para que pueda volver a moverse y atacar."
		_:
			return "Carta táctica."

func _card_target_text(card: Dictionary) -> String:
	if str(card.get("type", "")) == "faction":
		match str(card.get("effect", "")):
			"immobilize":   return "Objetivo: unidad enemiga"
			"poison":       return "Objetivo: unidad enemiga"
			"attack_debuff":return "Objetivo: unidad enemiga"
			"damage":       return "Objetivo: unidad enemiga no Maestro"
			"swap_hp":      return "Objetivo: unidad enemiga (intercambia HP con tu Maestro)"
			"exp":          return "Objetivo: unidad aliada"
			"extra_move":   return "Objetivo: unidad aliada sin mover"
			"double_attack":return "Objetivo: unidad aliada sin atacar"
			"defense_buff": return "Objetivo: unidad aliada"
			"untargetable": return "Objetivo: unidad aliada"
			"heal":         return "Objetivo: unidad aliada herida"
			"heal_all":     return "Objetivo: todas las unidades aliadas"
			"sacrifice_essence", "free_summon", "aoe_damage":
				return "Objetivo: uso inmediato"
			"tower_heal":
				return "Objetivo: torre aliada"
			"revive":       return "Objetivo: última unidad aliada muerta"
			"random":       return "Objetivo: aleatorio"
			_:              return "Objetivo: variable"
	match str(card.get("type", "")):
		"essence":
			return "Objetivo: uso inmediato"
		"heal":
			return "Objetivo: unidad aliada herida"
		"damage":
			return "Objetivo: unidad enemiga no Maestro"
		"exp":
			return "Objetivo: unidad aliada"
		"refresh":
			return "Objetivo: unidad aliada agotada"
		_:
			return "Objetivo: variable"

func _format_card_preview_rich_text(text: String, compact: bool = false) -> String:
	var rich_text: String = text
	rich_text = rich_text.replace("esencia", "[color=#59d7ff]^ esencia[/color]")
	rich_text = rich_text.replace("Curación", "[color=#6fe07a]+ Curación[/color]")
	rich_text = rich_text.replace("curación", "[color=#6fe07a]+ curación[/color]")
	rich_text = rich_text.replace("Cura", "[color=#6fe07a]+ Cura[/color]")
	rich_text = rich_text.replace("cura", "[color=#6fe07a]+ cura[/color]")
	rich_text = rich_text.replace("daño", "[color=#ff6767]X daño[/color]")
	rich_text = rich_text.replace("Daño", "[color=#ff6767]X Daño[/color]")
	rich_text = rich_text.replace("experiencia", "[color=#c971ff]XP experiencia[/color]")
	rich_text = rich_text.replace("Experiencia", "[color=#c971ff]XP Experiencia[/color]")
	rich_text = rich_text.replace("Refresca", "[color=#ffd258]↻ Refresca[/color]")
	rich_text = rich_text.replace("refresca", "[color=#ffd258]↻ refresca[/color]")
	if compact:
		rich_text = rich_text.replace("Objetivo:", "[color=#b8c7ea]Objetivo:[/color]")
	return rich_text

func _card_icon(card: Dictionary) -> String:
	if card.has("icon"):
		return str(card.get("icon", "?"))
	match str(card.get("type", "")):
		"essence":
			return "^"
		"heal":
			return "+"
		"damage":
			return "X"
		"exp":
			return "*"
		"refresh":
			return "↻"
		_:
			return "?"

func _card_slot_title(card: Dictionary) -> String:
	var display_name: String = _card_display_name(card)
	if display_name == "Fogón Gaucho":
		return "Fogón\nGaucho"
	if display_name.length() <= 12:
		return display_name
	return display_name

func _faction_placeholder_path(faction: int) -> String:
	match faction:
		FactionData.Faction.GAUCHOS:
			return "res://assets/sprites/cards/gauchos/card_gauchos_placeholder.png"
		FactionData.Faction.MILITARES:
			return "res://assets/sprites/cards/militares/card_militares_placeholder.png"
		FactionData.Faction.INDIOS:
			return "res://assets/sprites/cards/nativos/card_nativos_placeholder.png"
		FactionData.Faction.BRUJOS:
			return "res://assets/sprites/cards/brujos/card_brujos_placeholder.png"
		_:
			return ""

func _card_art_path(card: Dictionary, player_id: int) -> String:
	if card.has("art_path"):
		return str(card.get("art_path", ""))
	if card.has("faction"):
		var placeholder: String = _faction_placeholder_path(int(card.get("faction", 0)))
		if placeholder != "":
			return placeholder
	var card_type: String = str(card.get("type", ""))
	var value: int = int(card.get("value", 0))
	match card_type:
		"essence":
			return "res://assets/sprites/cards/essence/essence_%d.png" % value
		"heal":
			return "res://assets/sprites/cards/heal/heal_%d.png" % value
		"damage":
			return "res://assets/sprites/cards/damage/damage_%d.png" % value
		"exp":
			return "res://assets/sprites/cards/exp/exp_%d.png" % value
		"refresh":
			var faction: int = GameData.get_faction_for_player(player_id)
			if faction == FactionData.Faction.GAUCHOS:
				return "res://assets/sprites/cards/gauchos/fogon_gaucho.png"
	return ""

func _show_message(text: String, tint: Color) -> void:
	if _message_label == null:
		return
	_message_label.text = text
	_message_label.add_theme_color_override("font_color", tint)
	_message_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	var tween: Tween = create_tween()
	tween.tween_property(_message_label, "modulate:a", 1.0, 0.01)
	tween.tween_interval(1.0)
	tween.tween_property(_message_label, "modulate:a", 0.0, 0.25)
