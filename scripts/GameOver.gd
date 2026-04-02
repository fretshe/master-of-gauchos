extends Control

const BG := Color(0.05, 0.05, 0.09, 1.0)
const PANEL := Color(0.08, 0.09, 0.12, 0.96)
const PANEL_SOFT := Color(0.11, 0.12, 0.16, 0.92)
const GOLD := Color(0.96, 0.82, 0.28, 1.0)
const TEXT := Color(0.93, 0.93, 0.97, 1.0)
const DIM := Color(0.66, 0.70, 0.78, 1.0)
const GREEN := Color(0.42, 0.92, 0.54, 1.0)
const CYAN := Color(0.42, 0.84, 1.0, 1.0)
const VICTORY_PURPLE := Color(0.72, 0.30, 0.96, 1.0)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	GameData.load_meta()

	var winner_id: int = GameData.winner_id
	var turns: int = GameData.turns_played
	var player_ids: Array[int] = GameData.get_player_ids()
	var match_stats: Dictionary = GameData.match_stats.duplicate(true)
	if match_stats.is_empty() and not GameData.last_completed_run.is_empty():
		match_stats = (GameData.last_completed_run.get("match_stats", {}) as Dictionary).duplicate(true)
	var raw_players: Dictionary = match_stats.get("players", {})
	var timeline_entries: Array = _normalize_timeline_entries(player_ids, match_stats.get("timeline", []))
	var player_stats: Dictionary = {}
	for player_id: int in player_ids:
		player_stats[player_id] = _merge_player_stats(player_id, raw_players.get(player_id, {}))

	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var shell := Panel.new()
	shell.position = Vector2(72.0, 28.0)
	shell.size = Vector2(1136.0, 664.0)
	_apply_panel_style(shell, PANEL, Color(1.0, 0.88, 0.44, 0.24))
	add_child(shell)

	var title := Label.new()
	title.text = "Victoria" if winner_id != 0 else "Empate"
	title.position = Vector2(28.0, 20.0)
	title.size = Vector2(560.0, 78.0)
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", VICTORY_PURPLE if winner_id != 0 else GOLD)
	shell.add_child(title)

	var subtitle := Label.new()
	subtitle.text = _build_subtitle(winner_id)
	subtitle.position = Vector2(30.0, 96.0)
	subtitle.size = Vector2(700.0, 26.0)
	subtitle.add_theme_font_size_override("font_size", 22)
	subtitle.add_theme_color_override("font_color", DIM)
	shell.add_child(subtitle)

	var chip_specs := [
		{"label": "Turnos", "value": str(turns), "accent": GOLD, "pos": Vector2(748.0, 20.0)},
		{"label": "Mapa", "value": _map_name(GameData.current_map), "accent": CYAN, "pos": Vector2(938.0, 20.0)},
		{"label": "Torres", "value": str(int(GameData.map_tower_positions.size())), "accent": GREEN, "pos": Vector2(748.0, 74.0)},
		{"label": "Modo", "value": "%d jugadores" % player_ids.size(), "accent": Color(0.94, 0.74, 0.40, 1.0), "pos": Vector2(938.0, 74.0)},
	]
	for chip_spec_value: Variant in chip_specs:
		var chip_spec: Dictionary = chip_spec_value as Dictionary
		var chip := _make_chip(
			str(chip_spec.get("label", "")),
			str(chip_spec.get("value", "")),
			chip_spec.get("accent", GOLD) as Color
		)
		chip.position = chip_spec.get("pos", Vector2.ZERO) as Vector2
		shell.add_child(chip)

	var tabs_host := Panel.new()
	tabs_host.position = Vector2(28.0, 196.0)
	tabs_host.size = Vector2(1080.0, 388.0)
	_apply_panel_style(tabs_host, PANEL_SOFT, Color(1.0, 1.0, 1.0, 0.08))
	shell.add_child(tabs_host)

	var tabs_row := HBoxContainer.new()
	tabs_row.position = Vector2(14.0, 12.0)
	tabs_row.size = Vector2(1052.0, 34.0)
	tabs_row.add_theme_constant_override("separation", 10)
	tabs_host.add_child(tabs_row)

	var tabs_content := Control.new()
	tabs_content.position = Vector2(14.0, 56.0)
	tabs_content.size = Vector2(1052.0, 316.0)
	tabs_host.add_child(tabs_content)

	var tab_buttons: Dictionary = {}
	var tab_panels: Dictionary = {}

	var highlights_page := _make_summary_page_panel(tabs_content.size)
	tabs_content.add_child(highlights_page)
	tab_panels["highlights"] = highlights_page

	var highlights_title := Label.new()
	highlights_title.text = "Destacados"
	highlights_title.position = Vector2(18.0, 16.0)
	highlights_title.size = Vector2(220.0, 24.0)
	highlights_title.add_theme_font_size_override("font_size", 24)
	highlights_title.add_theme_color_override("font_color", GOLD)
	highlights_page.add_child(highlights_title)

	var highlights_body := RichTextLabel.new()
	highlights_body.position = Vector2(18.0, 54.0)
	highlights_body.size = Vector2(1016.0, 240.0)
	highlights_body.bbcode_enabled = false
	highlights_body.fit_content = false
	highlights_body.scroll_active = true
	highlights_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	highlights_body.add_theme_font_size_override("normal_font_size", 24)
	highlights_body.add_theme_color_override("default_color", TEXT)
	highlights_body.text = _build_highlights_text(winner_id, player_ids, player_stats)
	highlights_page.add_child(highlights_body)

	var timeline_page := _make_summary_page_panel(tabs_content.size)
	timeline_page.visible = false
	tabs_content.add_child(timeline_page)
	tab_panels["timeline"] = timeline_page

	var timeline_title := Label.new()
	timeline_title.text = "Linea de tiempo"
	timeline_title.position = Vector2(18.0, 12.0)
	timeline_title.size = Vector2(220.0, 24.0)
	timeline_title.add_theme_font_size_override("font_size", 24)
	timeline_title.add_theme_color_override("font_color", GOLD)
	timeline_page.add_child(timeline_title)

	var timeline_hint := Label.new()
	timeline_hint.text = "Presion total por turno: unidades, torres, esencia, bajas y rangos."
	timeline_hint.position = Vector2(234.0, 15.0)
	timeline_hint.size = Vector2(620.0, 18.0)
	timeline_hint.add_theme_font_size_override("font_size", 13)
	timeline_hint.add_theme_color_override("font_color", DIM)
	timeline_page.add_child(timeline_hint)
	_build_timeline_graph(timeline_page, player_ids, timeline_entries)

	var stats_page := _make_summary_page_panel(tabs_content.size)
	stats_page.visible = false
	tabs_content.add_child(stats_page)
	tab_panels["stats"] = stats_page

	var stats_title := Label.new()
	stats_title.text = "Resumen de partida"
	stats_title.position = Vector2(18.0, 12.0)
	stats_title.size = Vector2(320.0, 24.0)
	stats_title.add_theme_font_size_override("font_size", 24)
	stats_title.add_theme_color_override("font_color", GOLD)
	stats_page.add_child(stats_title)

	var metric_width: float = 280.0
	var value_width: float = floor((1016.0 - metric_width) / float(max(1, player_ids.size())))

	var header_row := HBoxContainer.new()
	header_row.position = Vector2(18.0, 52.0)
	header_row.size = Vector2(1016.0, 24.0)
	header_row.add_theme_constant_override("separation", 0)
	stats_page.add_child(header_row)
	header_row.add_child(_make_stat_header("", metric_width, DIM))
	for player_id: int in player_ids:
		header_row.add_child(_make_stat_header("J%d" % player_id, value_width, GameData.get_player_color(player_id)))

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(18.0, 86.0)
	scroll.size = Vector2(1016.0, 210.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stats_page.add_child(scroll)

	var stats_rows := VBoxContainer.new()
	stats_rows.custom_minimum_size = Vector2(1000.0, 0.0)
	stats_rows.add_theme_constant_override("separation", 10)
	scroll.add_child(stats_rows)

	_add_dynamic_row(stats_rows, "Bajas causadas", player_ids, player_stats, "kills", metric_width, value_width)
	_add_dynamic_row(stats_rows, "Unidades perdidas", player_ids, player_stats, "losses", metric_width, value_width)
	_add_dynamic_row(stats_rows, "Invocaciones", player_ids, player_stats, "summons", metric_width, value_width)
	_add_dynamic_row(stats_rows, "Torres capturadas", player_ids, player_stats, "towers_captured", metric_width, value_width)
	_add_dynamic_row(stats_rows, "Esencia final", player_ids, player_stats, "essence_final", metric_width, value_width)
	_add_dynamic_row(stats_rows, "Cartas usadas", player_ids, player_stats, "cards_used", metric_width, value_width)

	var economy_page := _make_summary_page_panel(tabs_content.size)
	economy_page.visible = false
	tabs_content.add_child(economy_page)
	tab_panels["economy"] = economy_page

	var economy_title := Label.new()
	economy_title.text = "Economia y veteranos"
	economy_title.position = Vector2(18.0, 12.0)
	economy_title.size = Vector2(320.0, 24.0)
	economy_title.add_theme_font_size_override("font_size", 24)
	economy_title.add_theme_color_override("font_color", GOLD)
	economy_page.add_child(economy_title)

	var economy_body := RichTextLabel.new()
	economy_body.position = Vector2(18.0, 52.0)
	economy_body.size = Vector2(1016.0, 244.0)
	economy_body.bbcode_enabled = true
	economy_body.fit_content = false
	economy_body.scroll_active = true
	economy_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	economy_body.add_theme_font_size_override("normal_font_size", 19)
	economy_body.text = _build_side_summary_text(player_ids, player_stats)
	economy_page.add_child(economy_body)

	var tab_specs := [
		{"key": "highlights", "label": "Destacados"},
		{"key": "timeline", "label": "Linea de tiempo"},
		{"key": "stats", "label": "Resumen de partida"},
		{"key": "economy", "label": "Economia y veteranos"},
	]
	for tab_spec_value: Variant in tab_specs:
		var tab_spec: Dictionary = tab_spec_value as Dictionary
		var tab_key := str(tab_spec.get("key", ""))
		var tab_button := _make_summary_tab_button(str(tab_spec.get("label", "")), tab_key == "highlights")
		tab_buttons[tab_key] = tab_button
		tabs_row.add_child(tab_button)
		tab_button.pressed.connect(func() -> void:
			for key_variant: Variant in tab_panels.keys():
				var key := str(key_variant)
				var page := tab_panels[key] as Control
				var button := tab_buttons[key] as Button
				var is_active := key == tab_key
				page.visible = is_active
				_apply_summary_tab_state(button, is_active)
		)

	var new_unlocks: Array[String] = GameData.consume_new_unlocks()
	if not new_unlocks.is_empty():
		var unlocks_title := Label.new()
		unlocks_title.text = "Nuevos desbloqueos"
		unlocks_title.position = Vector2(28.0, 594.0)
		unlocks_title.size = Vector2(240.0, 22.0)
		unlocks_title.add_theme_font_size_override("font_size", 22)
		unlocks_title.add_theme_color_override("font_color", GOLD)
		shell.add_child(unlocks_title)

		var unlocks_text := RichTextLabel.new()
		unlocks_text.position = Vector2(28.0, 620.0)
		unlocks_text.size = Vector2(516.0, 26.0)
		unlocks_text.bbcode_enabled = false
		unlocks_text.fit_content = false
		unlocks_text.scroll_active = false
		unlocks_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		unlocks_text.add_theme_font_size_override("normal_font_size", 14)
		unlocks_text.add_theme_color_override("default_color", TEXT)
		unlocks_text.text = " | ".join(_get_unlock_names(new_unlocks))
		shell.add_child(unlocks_text)

	var btn_row := HBoxContainer.new()
	btn_row.position = Vector2(640.0, 604.0)
	btn_row.size = Vector2(468.0, 44.0)
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	btn_row.add_theme_constant_override("separation", 16)
	shell.add_child(btn_row)
	btn_row.add_child(_make_action_button("Jugar de nuevo", func() -> void:
		get_tree().change_scene_to_file("res://scenes/NewGameSetup.tscn")
	))
	btn_row.add_child(_make_action_button("Menu principal", func() -> void:
		get_tree().change_scene_to_file("res://scenes/TitleScreen.tscn")
	))

	GameData.call_deferred("apply_selected_theme", get_window())


func _merge_player_stats(player_id: int, raw: Dictionary) -> Dictionary:
	var defaults := {
		"kills": GameData.units_killed_p1 if player_id == 1 else (GameData.units_killed_p2 if player_id == 2 else 0),
		"losses": 0,
		"summons": 0,
		"towers_captured": GameData.towers_captured_p1 if player_id == 1 else (GameData.towers_captured_p2 if player_id == 2 else 0),
		"towers_owned_final": 0,
		"essence_final": 0,
		"essence_gained": 0,
		"essence_spent": 0,
		"cards_used": 0,
		"highest_unit": "Sin unidades",
		"master_hp": 0,
		"remaining_units": 0,
	}
	for key: String in raw.keys():
		defaults[key] = raw[key]
	return defaults


func _build_subtitle(winner_id: int) -> String:
	if winner_id == 0:
		return "Ningun bando logro imponerse antes del colapso final."
	return "El Jugador %d domino el campo de batalla y cerro la partida." % winner_id


func _build_highlights_text(winner_id: int, player_ids: Array[int], player_stats: Dictionary) -> String:
	var control_leader: int = _best_player_for_key(player_ids, player_stats, "towers_captured")
	var combat_leader: int = _best_player_for_key(player_ids, player_stats, "kills")
	var card_leader: int = _best_player_for_key(player_ids, player_stats, "cards_used")
	if winner_id == 0:
		return "Mejor control del mapa: J%d.\nMas presion de combate: J%d.\nMas uso tactico de cartas: J%d." % [control_leader, combat_leader, card_leader]
	return "J%d gano la batalla.\nControl del mapa: J%d.\nPresion de combate: J%d.\nRitmo con cartas: J%d." % [winner_id, control_leader, combat_leader, card_leader]


func _build_side_summary_text(player_ids: Array[int], player_stats: Dictionary) -> String:
	var lines: Array[String] = []
	for player_id: int in player_ids:
		var stats: Dictionary = player_stats.get(player_id, {})
		var color_hex: String = GameData.get_player_color(player_id).to_html(false)
		lines.append("[color=%s]Jugador %d[/color]" % [color_hex, player_id])
		lines.append("Esencia: +%d / -%d / final %d" % [
			int(stats.get("essence_gained", 0)),
			int(stats.get("essence_spent", 0)),
			int(stats.get("essence_final", 0)),
		])
		lines.append("Unidad mas alta: %s" % str(stats.get("highest_unit", "Sin unidades")))
		lines.append("Maestro: %d HP | Unidades vivas: %d" % [
			int(stats.get("master_hp", 0)),
			int(stats.get("remaining_units", 0)),
		])
		if player_id != player_ids[player_ids.size() - 1]:
			lines.append("")
	return "\n".join(lines)


func _best_player_for_key(player_ids: Array[int], player_stats: Dictionary, key: String) -> int:
	var best_player: int = player_ids[0] if not player_ids.is_empty() else 1
	var best_value: int = -999999
	for player_id: int in player_ids:
		var value: int = int((player_stats.get(player_id, {}) as Dictionary).get(key, 0))
		if value > best_value:
			best_value = value
			best_player = player_id
	return best_player


func _normalize_timeline_entries(player_ids: Array[int], raw_timeline: Array) -> Array:
	var entries: Array = []
	for entry_value: Variant in raw_timeline:
		var entry: Dictionary = entry_value as Dictionary
		if entry.is_empty():
			continue
		var players_dict: Dictionary = {}
		var raw_players: Dictionary = entry.get("players", {})
		for player_id: int in player_ids:
			players_dict[player_id] = int(raw_players.get(player_id, 0))
		entries.append({
			"turn": int(entry.get("turn", entries.size() + 1)),
			"players": players_dict,
		})
	if entries.is_empty():
		var fallback_players: Dictionary = {}
		for player_id: int in player_ids:
			fallback_players[player_id] = 0
		entries.append({"turn": 1, "players": fallback_players})
	return entries


func _build_timeline_graph(parent: Panel, player_ids: Array[int], timeline_entries: Array) -> void:
	var graph_left: float = 54.0
	var graph_top: float = 52.0
	var graph_width: float = 966.0
	var graph_height: float = 218.0

	for y_step: int in range(3):
		var guide := ColorRect.new()
		guide.color = Color(1.0, 1.0, 1.0, 0.08 if y_step == 1 else 0.05)
		guide.position = Vector2(graph_left, graph_top + graph_height * float(y_step) / 2.0)
		guide.size = Vector2(graph_width, 1.0)
		guide.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(guide)

	var graph_origin := Node2D.new()
	graph_origin.position = Vector2(graph_left, graph_top)
	parent.add_child(graph_origin)

	var value_range: Vector2 = _timeline_value_range(player_ids, timeline_entries)
	var min_value: float = value_range.x
	var max_value: float = value_range.y
	var turn_count: int = max(1, timeline_entries.size())

	var min_label := Label.new()
	min_label.text = str(int(min_value))
	min_label.position = Vector2(10.0, graph_top + graph_height - 10.0)
	min_label.size = Vector2(40.0, 18.0)
	min_label.add_theme_font_size_override("font_size", 12)
	min_label.add_theme_color_override("font_color", DIM)
	parent.add_child(min_label)

	var max_label := Label.new()
	max_label.text = str(int(max_value))
	max_label.position = Vector2(10.0, graph_top - 6.0)
	max_label.size = Vector2(40.0, 18.0)
	max_label.add_theme_font_size_override("font_size", 12)
	max_label.add_theme_color_override("font_color", DIM)
	parent.add_child(max_label)

	for turn_index: int in range(turn_count):
		var tick_x: float = graph_width * float(turn_index) / float(max(1, turn_count - 1))
		var tick := ColorRect.new()
		tick.color = Color(1.0, 1.0, 1.0, 0.06)
		tick.position = Vector2(graph_left + tick_x, graph_top)
		tick.size = Vector2(1.0, graph_height)
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(tick)

		var turn_label := Label.new()
		turn_label.text = "T%d" % int((timeline_entries[turn_index] as Dictionary).get("turn", turn_index + 1))
		turn_label.position = Vector2(graph_left + tick_x - 12.0, graph_top + graph_height + 6.0)
		turn_label.size = Vector2(28.0, 16.0)
		turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		turn_label.add_theme_font_size_override("font_size", 11)
		turn_label.add_theme_color_override("font_color", DIM)
		parent.add_child(turn_label)

	for player_id: int in player_ids:
		var color: Color = GameData.get_player_color(player_id)
		var line := Line2D.new()
		line.width = 3.0
		line.default_color = color
		line.antialiased = true
		graph_origin.add_child(line)

		for turn_index: int in range(turn_count):
			var entry: Dictionary = timeline_entries[turn_index] as Dictionary
			var value: float = float((entry.get("players", {}) as Dictionary).get(player_id, 0))
			var px: float = graph_width * float(turn_index) / float(max(1, turn_count - 1))
			var py: float = _timeline_y(value, min_value, max_value, graph_height)
			line.add_point(Vector2(px, py))

			var dot := ColorRect.new()
			dot.color = color
			dot.position = Vector2(graph_left + px - 2.0, graph_top + py - 2.0)
			dot.size = Vector2(4.0, 4.0)
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			parent.add_child(dot)

	var legend := HBoxContainer.new()
	legend.position = Vector2(820.0, 14.0)
	legend.size = Vector2(214.0, 18.0)
	legend.alignment = BoxContainer.ALIGNMENT_END
	legend.add_theme_constant_override("separation", 12)
	parent.add_child(legend)
	for player_id: int in player_ids:
		legend.add_child(_make_timeline_legend_item(player_id))


func _timeline_value_range(player_ids: Array[int], timeline_entries: Array) -> Vector2:
	var min_value: float = INF
	var max_value: float = -INF
	for entry_value: Variant in timeline_entries:
		var entry: Dictionary = entry_value as Dictionary
		var players_dict: Dictionary = entry.get("players", {})
		for player_id: int in player_ids:
			var value: float = float(players_dict.get(player_id, 0))
			min_value = minf(min_value, value)
			max_value = maxf(max_value, value)
	if min_value == INF:
		return Vector2(0.0, 1.0)
	if is_equal_approx(min_value, max_value):
		max_value += 1.0
	return Vector2(min_value, max_value)


func _timeline_y(value: float, min_value: float, max_value: float, graph_height: float) -> float:
	var t: float = inverse_lerp(min_value, max_value, value)
	return lerp(graph_height, 0.0, t)


func _make_timeline_legend_item(player_id: int) -> Control:
	var wrap := HBoxContainer.new()
	wrap.custom_minimum_size = Vector2(48.0, 16.0)
	wrap.add_theme_constant_override("separation", 4)

	var swatch := ColorRect.new()
	swatch.color = GameData.get_player_color(player_id)
	swatch.custom_minimum_size = Vector2(10.0, 10.0)
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(swatch)

	var label := Label.new()
	label.text = "J%d" % player_id
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", TEXT)
	wrap.add_child(label)
	return wrap


func _map_name(map_id: int) -> String:
	match map_id:
		1:
			return "Sierras"
		2:
			return "Precordillera"
		_:
			return "Llanuras"


func _make_chip(label_text: String, value_text: String, accent: Color) -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(180.0, 42.0)
	panel.size = panel.custom_minimum_size
	_apply_panel_style(panel, PANEL_SOFT, Color(accent.r, accent.g, accent.b, 0.28))

	var label := Label.new()
	label.text = label_text
	label.position = Vector2(12.0, 9.0)
	label.size = Vector2(78.0, 18.0)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", DIM)
	panel.add_child(label)

	var value := Label.new()
	value.text = value_text
	value.position = Vector2(88.0, 7.0)
	value.size = Vector2(80.0, 22.0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.add_theme_font_size_override("font_size", 16)
	value.add_theme_color_override("font_color", accent)
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(value)
	return panel


func _make_summary_page_panel(size_value: Vector2) -> Panel:
	var panel := Panel.new()
	panel.position = Vector2.ZERO
	panel.size = size_value
	_apply_panel_style(panel, Color(0.10, 0.11, 0.15, 0.84), Color(1.0, 1.0, 1.0, 0.06))
	return panel


func _make_summary_tab_button(text_value: String, active: bool = false) -> Button:
	var btn := Button.new()
	btn.text = text_value
	btn.custom_minimum_size = Vector2(184.0, 32.0)
	btn.add_theme_font_size_override("font_size", 16)
	_apply_summary_tab_state(btn, active)
	return btn


func _apply_summary_tab_state(button: Button, active: bool) -> void:
	if button == null:
		return
	if active:
		button.add_theme_stylebox_override("normal", _make_button_style(Color(0.18, 0.14, 0.10, 0.98), Color(0.98, 0.86, 0.34, 0.98)))
		button.add_theme_stylebox_override("hover", _make_button_style(Color(0.18, 0.14, 0.10, 0.98), Color(0.98, 0.86, 0.34, 0.98)))
		button.add_theme_stylebox_override("pressed", _make_button_style(Color(0.20, 0.16, 0.10, 1.0), Color(1.0, 0.90, 0.42, 1.0)))
		button.add_theme_stylebox_override("focus", _make_button_style(Color(0.18, 0.14, 0.10, 0.98), Color(1.0, 0.90, 0.42, 1.0)))
		button.add_theme_color_override("font_color", TEXT)
	else:
		button.add_theme_stylebox_override("normal", _make_button_style(Color(0.12, 0.13, 0.18, 0.94), Color(1.0, 1.0, 1.0, 0.14)))
		button.add_theme_stylebox_override("hover", _make_button_style(Color(0.15, 0.16, 0.21, 0.98), Color(1.0, 1.0, 1.0, 0.28)))
		button.add_theme_stylebox_override("pressed", _make_button_style(Color(0.17, 0.18, 0.24, 1.0), Color(1.0, 1.0, 1.0, 0.34)))
		button.add_theme_stylebox_override("focus", _make_button_style(Color(0.15, 0.16, 0.21, 0.98), Color(1.0, 1.0, 1.0, 0.28)))
		button.add_theme_color_override("font_color", DIM)


func _make_stat_header(text_value: String, width: float, tint: Color) -> Control:
	var lbl := Label.new()
	lbl.text = text_value
	lbl.custom_minimum_size = Vector2(width, 22.0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", tint)
	return lbl


func _add_dynamic_row(parent: VBoxContainer, key_text: String, player_ids: Array[int], player_stats: Dictionary, stat_key: String, metric_width: float, value_width: float) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(metric_width + value_width * player_ids.size(), 28.0)
	row.add_theme_constant_override("separation", 0)
	parent.add_child(row)

	var key_lbl := Label.new()
	key_lbl.text = key_text
	key_lbl.custom_minimum_size = Vector2(metric_width, 28.0)
	key_lbl.add_theme_font_size_override("font_size", 18)
	key_lbl.add_theme_color_override("font_color", DIM)
	row.add_child(key_lbl)

	for player_id: int in player_ids:
		var value_lbl := Label.new()
		value_lbl.text = str(int((player_stats.get(player_id, {}) as Dictionary).get(stat_key, 0)))
		value_lbl.custom_minimum_size = Vector2(value_width, 28.0)
		value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value_lbl.add_theme_font_size_override("font_size", 18)
		value_lbl.add_theme_color_override("font_color", TEXT)
		row.add_child(value_lbl)


func _make_action_button(text_value: String, on_press: Callable) -> Button:
	var btn := Button.new()
	btn.text = text_value
	btn.custom_minimum_size = Vector2(220.0, 44.0)
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_stylebox_override("normal", _make_button_style(Color(0.12, 0.11, 0.10, 0.96), Color(0.96, 0.82, 0.28, 0.72)))
	btn.add_theme_stylebox_override("hover", _make_button_style(Color(0.16, 0.14, 0.10, 0.98), Color(0.98, 0.86, 0.34, 0.94)))
	btn.add_theme_stylebox_override("pressed", _make_button_style(Color(0.18, 0.15, 0.10, 1.0), Color(0.98, 0.88, 0.38, 1.0)))
	btn.add_theme_stylebox_override("focus", _make_button_style(Color(0.12, 0.11, 0.10, 0.96), Color(0.98, 0.88, 0.38, 1.0)))
	btn.pressed.connect(on_press)
	return btn


func _make_button_style(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = border_color
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	return style


func _get_unlock_names(ids: Array[String]) -> Array[String]:
	var names: Array[String] = []
	for unlock_id: String in ids:
		var unlock_def: Dictionary = GameData.get_unlock_def(unlock_id)
		names.append(str(unlock_def.get("name", unlock_id)))
	return names


func _apply_panel_style(panel: Panel, bg_color: Color, border_color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = border_color
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	panel.add_theme_stylebox_override("panel", style)
