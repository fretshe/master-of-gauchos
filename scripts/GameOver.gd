extends Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS

	var winner_id := GameData.winner_id
	var turns     := GameData.turns_played
	var kills_p1  := GameData.units_killed_p1
	var kills_p2  := GameData.units_killed_p2
	var towers_p1 := GameData.towers_captured_p1
	var towers_p2 := GameData.towers_captured_p2

	# Background
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.07, 0.12)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Center container
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	center.add_child(vbox)

	# Result title
	var result_lbl := Label.new()
	if winner_id == 0:
		result_lbl.text = "Empate"
		result_lbl.add_theme_color_override("font_color", Color(0.95, 0.80, 0.20))
	else:
		result_lbl.text = "Victoria"
		result_lbl.add_theme_color_override("font_color", GameData.get_player_color(winner_id))
	result_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_lbl.add_theme_font_size_override("font_size", 96)
	result_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(result_lbl)

	# Subtitle
	var sub_lbl := Label.new()
	if winner_id == 0:
		sub_lbl.text = "Ambos jugadores han caido en batalla"
	else:
		sub_lbl.text = "El Jugador %d domina el campo de batalla" % winner_id
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_font_size_override("font_size", 22)
	sub_lbl.add_theme_color_override("font_color", Color(0.68, 0.72, 0.82))
	sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sub_lbl)

	# Stats
	var stats_vbox := VBoxContainer.new()
	stats_vbox.add_theme_constant_override("separation", 8)
	stats_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(stats_vbox)

	_add_stat(stats_vbox, "Turnos jugados",          str(turns))
	_add_stat(stats_vbox, "Bajas causadas (J1)",     str(kills_p1))
	_add_stat(stats_vbox, "Bajas causadas (J2)",     str(kills_p2))
	_add_stat(stats_vbox, "Torres capturadas (J1)",  str(towers_p1))
	_add_stat(stats_vbox, "Torres capturadas (J2)",  str(towers_p2))

	# Buttons
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 32)
	btn_row.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(btn_row)

	var btn_retry := Button.new()
	btn_retry.text = "Jugar de nuevo"
	btn_retry.custom_minimum_size = Vector2(200, 48)
	btn_retry.add_theme_font_size_override("font_size", 20)
	btn_retry.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/NewGameSetup.tscn"))
	btn_row.add_child(btn_retry)

	var btn_menu := Button.new()
	btn_menu.text = "Menu principal"
	btn_menu.custom_minimum_size = Vector2(200, 48)
	btn_menu.add_theme_font_size_override("font_size", 20)
	btn_menu.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/TitleScreen.tscn"))
	btn_row.add_child(btn_menu)

func _add_stat(parent: VBoxContainer, key: String, value: String) -> void:
	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(hbox)

	var key_lbl := Label.new()
	key_lbl.text = key + ":"
	key_lbl.custom_minimum_size = Vector2(280, 0)
	key_lbl.add_theme_font_size_override("font_size", 18)
	key_lbl.add_theme_color_override("font_color", Color(0.68, 0.72, 0.82))
	key_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(key_lbl)

	var val_lbl := Label.new()
	val_lbl.text = value
	val_lbl.add_theme_font_size_override("font_size", 18)
	val_lbl.add_theme_color_override("font_color", Color(0.92, 0.92, 0.95))
	val_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(val_lbl)
