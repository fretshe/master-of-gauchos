extends Control

# ─── State ───────────────────────────────────────────────────────────────────────
var _faction_p1: int = -1   # -1 = not yet chosen
var _faction_p2: int = -1

var _confirm_btn: Button
var _p1_cards:    Array = []   # [Panel, Panel] indexed by Faction value
var _p2_cards:    Array = []

const PLAYER_COLORS := [Color(0.30, 0.60, 1.00), Color(1.00, 0.30, 0.30)]
const COL_SELECTED   := Color(0.95, 0.80, 0.20)
const COL_IDLE       := Color(0.28, 0.28, 0.42)
const BG_SELECTED    := Color(0.16, 0.16, 0.26)
const BG_IDLE        := Color(0.10, 0.10, 0.18)

# ─── Godot callbacks ─────────────────────────────────────────────────────────────
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build_ui()

func _build_ui() -> void:
	# Background
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.07, 0.12)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Root VBox — fills screen
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(root)

	# ── Title ────────────────────────────────────────────────────────────────────
	var title := Label.new()
	title.text = "Elegí tu Facción"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.95, 0.80, 0.20))
	title.custom_minimum_size = Vector2(0, 72)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(title)

	# ── Player columns ───────────────────────────────────────────────────────────
	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 6)
	cols.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_child(cols)

	_p1_cards = _build_player_side(1, cols)
	_p2_cards = _build_player_side(2, cols)

	# ── Bottom bar ───────────────────────────────────────────────────────────────
	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.custom_minimum_size = Vector2(0, 64)
	bar.add_theme_constant_override("separation", 24)
	bar.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_child(bar)

	var btn_back := Button.new()
	btn_back.text = "← Volver"
	btn_back.custom_minimum_size = Vector2(150, 46)
	btn_back.add_theme_font_size_override("font_size", 18)
	btn_back.pressed.connect(_on_back)
	bar.add_child(btn_back)

	_confirm_btn = Button.new()
	_confirm_btn.text = "Confirmar →"
	_confirm_btn.custom_minimum_size = Vector2(200, 46)
	_confirm_btn.add_theme_font_size_override("font_size", 18)
	_confirm_btn.disabled = true
	_confirm_btn.pressed.connect(_on_confirm)
	bar.add_child(_confirm_btn)

# ─── Side builder ────────────────────────────────────────────────────────────────
func _build_player_side(player: int, parent: Control) -> Array:
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(vbox)

	# Player label
	var lbl := Label.new()
	lbl.text = "JUGADOR %d" % player
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.custom_minimum_size  = Vector2(0, 44)
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.add_theme_color_override("font_color", GameData.get_player_color(player))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(lbl)

	# One card per faction
	var cards: Array = []
	for f: int in FactionData.get_all_faction_ids():
		var card := _build_faction_card(f, player)
		vbox.add_child(card)
		cards.append(card)

	return cards

# ─── Faction card ────────────────────────────────────────────────────────────────
func _build_faction_card(faction: int, player: int) -> Panel:
	var panel := Panel.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var style := StyleBoxFlat.new()
	style.bg_color            = BG_IDLE
	style.border_color        = COL_IDLE
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)

	# Content VBox
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left   = 14
	vbox.offset_right  = -14
	vbox.offset_top    = 12
	vbox.offset_bottom = -12
	vbox.alignment     = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	vbox.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vbox)

	# Faction name
	var name_lbl := Label.new()
	name_lbl.text = FactionData.get_faction_name(faction)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 28)
	name_lbl.add_theme_color_override("font_color", FactionData.get_color(faction))
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_lbl)

	# Description
	var desc_lbl := Label.new()
	desc_lbl.text = FactionData.get_desc(faction)
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.add_theme_font_size_override("font_size", 14)
	desc_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(desc_lbl)

	# Sprite previews — master + 4 unit types
	var sprites_row := HBoxContainer.new()
	sprites_row.alignment = BoxContainer.ALIGNMENT_CENTER
	sprites_row.add_theme_constant_override("separation", 10)
	sprites_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sprites_row)

	for unit_type: int in [-1, 0, 1, 2, 3]:   # master, warrior, archer, lancer, rider
		var path := FactionData.get_sprite_path(faction, unit_type)
		if not ResourceLoader.exists(path):
			continue
		var tex: Texture2D = load(path)
		if tex == null:
			continue
		var tr := TextureRect.new()
		tr.texture             = tex
		tr.custom_minimum_size = Vector2(56, 56)
		tr.stretch_mode        = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.expand_mode         = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tr.mouse_filter        = Control.MOUSE_FILTER_IGNORE
		sprites_row.add_child(tr)

	# Invisible click button over the whole card
	var btn := Button.new()
	btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.flat = true
	var empty := StyleBoxEmpty.new()
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(state, empty)
	btn.pressed.connect(func(): _on_faction_selected(player, faction))
	panel.add_child(btn)

	return panel

# ─── Selection logic ─────────────────────────────────────────────────────────────
func _on_faction_selected(player: int, faction: int) -> void:
	if player == 1:
		_faction_p1 = faction
		_refresh_highlights(_p1_cards, faction)
	else:
		_faction_p2 = faction
		_refresh_highlights(_p2_cards, faction)
	_confirm_btn.disabled = (_faction_p1 == -1 or _faction_p2 == -1)

func _refresh_highlights(cards: Array, selected: int) -> void:
	for i: int in cards.size():
		var style := cards[i].get_theme_stylebox("panel") as StyleBoxFlat
		if i == selected:
			style.border_color = COL_SELECTED
			style.bg_color     = BG_SELECTED
		else:
			style.border_color = COL_IDLE
			style.bg_color     = BG_IDLE

# ─── Navigation ──────────────────────────────────────────────────────────────────
func _on_confirm() -> void:
	GameData.faction_p1 = _faction_p1
	GameData.faction_p2 = _faction_p2
	get_tree().change_scene_to_file("res://scenes/MapSelect.tscn")

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/TitleScreen.tscn")
