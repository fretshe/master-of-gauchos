extends CanvasLayer

var turn_manager: Node = null
var hex_grid: Node = null

var _root: Control = null
var _panel: Panel = null
var _message_label: Label = null
var _slot_nodes: Array[Dictionary] = []
var _hovered_card_index: int = -1
var _armed_card_index: int = -1
var _fx_time: float = 0.0

func _ready() -> void:
	layer = 11
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

	for i: int in range(_slot_nodes.size()):
		var slot: Dictionary = _slot_nodes[i]
		var panel: Panel = slot["panel"] as Panel
		var value_label: Label = slot["value"] as Label
		var type_label: Label = slot["type"] as Label
		var icon_label: Label = slot["icon"] as Label
		var button: Button = slot["button"] as Button
		var style: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
		var glow: ColorRect = slot["glow"] as ColorRect
		var motes: Array = slot["motes"] as Array

		if i >= hand.size():
			panel.visible = false
			button.disabled = true
			glow.visible = false
			for mote_value: Variant in motes:
				var mote: ColorRect = mote_value as ColorRect
				if mote != null:
					mote.visible = false
			continue

		var card: Dictionary = hand[i]
		var card_color: Color = _card_color(str(card.get("color", "cyan")))
		var is_active: bool = not spent and (i == _armed_card_index or (_armed_card_index == -1 and i == _hovered_card_index))
		var is_dimmed: bool = not spent and _has_active_card() and not is_active

		panel.visible = true
		button.disabled = spent
		value_label.text = str(int(card.get("value", 0)))
		type_label.text = _card_name(card)
		icon_label.text = _card_icon(card)
		panel.pivot_offset = panel.size * 0.5
		panel.scale = Vector2(1.10, 1.10) if is_active else Vector2.ONE

		if style != null:
			if spent:
				style.bg_color = Color(0.28, 0.28, 0.32, 0.94)
				style.border_color = Color(0.80, 0.80, 0.84, 0.9)
			elif is_dimmed:
				style.bg_color = card_color.darkened(0.55)
				style.border_color = Color(0.52, 0.52, 0.56, 0.72)
			elif is_active:
				style.bg_color = card_color.lightened(0.12)
				style.border_color = Color.WHITE
			else:
				style.bg_color = card_color
				style.border_color = Color(0.92, 0.92, 0.96, 0.92)
			style.set_border_width_all(2 if is_active else 1)

		if glow != null:
			glow.visible = is_active
			glow.color = Color(card_color.r, card_color.g, card_color.b, 0.26)
			glow.scale = Vector2(1.18, 1.18) if is_active else Vector2.ONE

		for mote_value: Variant in motes:
			var mote: ColorRect = mote_value as ColorRect
			if mote != null:
				mote.visible = is_active and not spent
				mote.color = Color(card_color.r, card_color.g, card_color.b, 0.0)

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_panel = Panel.new()
	_panel.position = Vector2(520.0, 518.0)
	_panel.size = Vector2(240.0, 108.0)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.09, 0.12, 0.55)
	panel_style.border_color = Color(1.0, 1.0, 1.0, 0.08)
	panel_style.set_border_width_all(1)
	_panel.add_theme_stylebox_override("panel", panel_style)
	_root.add_child(_panel)

	_message_label = Label.new()
	_message_label.position = Vector2(460.0, 488.0)
	_message_label.size = Vector2(360.0, 24.0)
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.add_theme_font_size_override("font_size", 14)
	_message_label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.96, 0.0))
	_root.add_child(_message_label)

	for i: int in range(3):
		var slot_panel := Panel.new()
		slot_panel.position = Vector2(10.0 + float(i) * 76.0, 9.0)
		slot_panel.size = Vector2(60.0, 90.0)
		slot_panel.mouse_filter = Control.MOUSE_FILTER_STOP

		var glow := ColorRect.new()
		glow.position = Vector2(-5.0, -5.0)
		glow.size = Vector2(70.0, 100.0)
		glow.color = Color(1.0, 1.0, 1.0, 0.0)
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow.visible = false
		slot_panel.add_child(glow)

		var motes: Array = []
		for mote_index: int in range(4):
			var mote := ColorRect.new()
			mote.size = Vector2(5.0, 5.0)
			mote.position = Vector2(10.0 + float(mote_index) * 11.0, 72.0)
			mote.color = Color(1.0, 1.0, 1.0, 0.0)
			mote.mouse_filter = Control.MOUSE_FILTER_IGNORE
			mote.visible = false
			slot_panel.add_child(mote)
			motes.append(mote)

		var slot_style := StyleBoxFlat.new()
		slot_style.bg_color = Color(0.12, 0.16, 0.20, 0.96)
		slot_style.border_color = Color.WHITE
		slot_style.set_border_width_all(1)
		slot_panel.add_theme_stylebox_override("panel", slot_style)
		_panel.add_child(slot_panel)

		var type_label := Label.new()
		type_label.position = Vector2(4.0, 5.0)
		type_label.size = Vector2(52.0, 12.0)
		type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		type_label.add_theme_font_size_override("font_size", 9)
		type_label.add_theme_color_override("font_color", Color(0.98, 0.98, 1.0))
		slot_panel.add_child(type_label)

		var icon_label := Label.new()
		icon_label.position = Vector2(0.0, 18.0)
		icon_label.size = Vector2(60.0, 18.0)
		icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_label.add_theme_font_size_override("font_size", 16)
		icon_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
		slot_panel.add_child(icon_label)

		var value_label := Label.new()
		value_label.position = Vector2(0.0, 40.0)
		value_label.size = Vector2(60.0, 28.0)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		value_label.add_theme_font_size_override("font_size", 28)
		value_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
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
			"glow": glow,
			"motes": motes,
			"type": type_label,
			"icon": icon_label,
			"value": value_label,
			"button": button,
		})

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
		CardManager.play_card(player_id, card_index)
		_armed_card_index = -1
		return

	if hex_grid != null and hex_grid.has_method("enter_card_target_mode"):
		_armed_card_index = card_index
		refresh_hand()
		hex_grid.call("enter_card_target_mode", player_id, card_index, card)
		_show_message("Selecciona una unidad objetivo", _card_color(str(card.get("color", "cyan"))))

func _on_hand_changed(player_id: int) -> void:
	if turn_manager == null or player_id != turn_manager.current_player:
		return
	_armed_card_index = -1
	refresh_hand()

func _on_card_played(_player_id: int, _card: Dictionary) -> void:
	_armed_card_index = -1
	refresh_hand()

func _on_turn_changed(_player_id: int) -> void:
	_hovered_card_index = -1
	_armed_card_index = -1
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

func _cancel_armed_card() -> void:
	_armed_card_index = -1
	if hex_grid != null and hex_grid.has_method("exit_card_target_mode"):
		hex_grid.call("exit_card_target_mode")
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
			var rise: float = fmod(_fx_time * (16.0 + float(mote_index) * 1.8), 28.0)
			mote.position = Vector2(9.0 + float(mote_index) * 12.0 + sway_x, 78.0 - rise)
			mote.color = Color(base_color.r, base_color.g, base_color.b, 0.25 + flash * 0.95)

func _card_color(color_name: String) -> Color:
	match color_name:
		"cyan":
			return Color(0.18, 0.82, 0.96, 0.96)
		"teal":
			return Color(0.10, 0.74, 0.64, 0.96)
		"red":
			return Color(0.84, 0.22, 0.22, 0.96)
		"purple":
			return Color(0.58, 0.30, 0.88, 0.96)
		_:
			return Color(0.30, 0.30, 0.36, 0.96)

func _card_name(card: Dictionary) -> String:
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

func _card_icon(card: Dictionary) -> String:
	match str(card.get("type", "")):
		"essence":
			return "^"
		"heal":
			return "+"
		"damage":
			return "X"
		"exp":
			return "*"
		_:
			return "?"

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
