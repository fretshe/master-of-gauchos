extends Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS

	# Background — IGNORE so it never blocks buttons
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.07, 0.12)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Center container — PASS so clicks reach children
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	center.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "MASTER OF MONSTERS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(0.95, 0.80, 0.20))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title)

	# Subtitle
	var sub := Label.new()
	sub.text = "Un juego de estrategia por turnos"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", Color(0.20, 0.50, 0.90))
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sub)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 32)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(spacer)

	# Buttons — mouse_filter = STOP (default) so they receive clicks
	var btn_new := _make_btn("Nueva Partida")
	btn_new.pressed.connect(_on_new_game)
	vbox.add_child(btn_new)

	var btn_cont := _make_btn("Continuar")
	btn_cont.disabled = not FileAccess.file_exists(GameData.SAVE_PATH)
	btn_cont.pressed.connect(_on_continue)
	vbox.add_child(btn_cont)

	var btn_opts := _make_btn("Opciones")
	btn_opts.pressed.connect(_on_options)
	vbox.add_child(btn_opts)

	var btn_quit := _make_btn("Salir")
	btn_quit.pressed.connect(_on_quit)
	vbox.add_child(btn_quit)

	MusicManager.play_menu_music()
	print("[TitleScreen] UI lista")

func _make_btn(label_text: String) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(300, 52)
	btn.add_theme_font_size_override("font_size", 20)
	return btn

func _on_new_game() -> void:
	print("[TitleScreen] Nueva Partida presionado")
	var err := get_tree().change_scene_to_file("res://scenes/NewGameSetup.tscn")
	if err != OK:
		push_error("[TitleScreen] change_scene_to_file fallo: %d" % err)

func _on_continue() -> void:
	GameData.load()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_options() -> void:
	pass  # TODO: options menu

func _on_quit() -> void:
	get_tree().quit()
