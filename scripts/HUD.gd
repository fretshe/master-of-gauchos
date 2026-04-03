extends CanvasLayer

const MatchAdvantageScript := preload("res://scripts/MatchAdvantage.gd")
const BonusSystemScript := preload("res://scripts/BonusSystem.gd")
const TutorialOutlineScript := preload("res://scripts/TutorialOutline.gd")
const TutorialSpotlightShader := preload("res://shaders/tutorial_spotlight.gdshader")
const PIXEL_FONT := preload("res://assets/fonts/Pixelon-E4JEg.otf")
const TUTORIAL_ARROW_TEXTURE := preload("res://assets/sprites/ui/tutorial/tutorial_arrow_pixel.png")

var turn_manager: Node = null
var resource_manager: Node = null
var hex_grid: Node = null

signal end_turn_pressed()
signal summon_pressed()
signal pause_menu_toggled(open: bool)
signal pause_resume_pressed()
signal pause_save_pressed()
signal pause_save_and_exit_pressed()
signal pause_restart_pressed()
signal pause_back_to_menu_pressed()
signal pause_sound_toggled(enabled: bool)
signal game_speed_selected(scale: float)
signal tutorial_next_pressed()

const HUD_SIZE := Vector2(1280, 720)
const LABEL_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const LABEL_DIM := Color(1.0, 1.0, 1.0, 0.6)
const HUD_FONT_SIZE := 16
const HUD_FONT_SIZE_SMALL := 14
const HUD_FONT_SIZE_LARGE := 18
const HUD_GLASS := Color(0.30, 0.32, 0.36, 0.44)
const HUD_GLASS_DARK := Color(0.14, 0.15, 0.18, 0.72)
const HUD_BORDER := Color(0.86, 0.88, 0.94, 0.18)
const HUD_BORDER_BRIGHT := Color(1.0, 1.0, 1.0, 0.28)
const HUD_LINE := Color(1.0, 1.0, 1.0, 0.12)
const HUD_LINE_SOFT := Color(1.0, 1.0, 1.0, 0.05)
const SUMMON_READY_COLOR := Color(0.42, 0.88, 1.0, 1.0)
const END_TURN_READY_COLOR := Color(1.0, 0.88, 0.24, 1.0)
const BUTTON_MOTE_IDLE_ALPHA := 0.0
const BUTTON_MOTE_COUNT := 12
const HP_ON := Color(0.89, 0.19, 0.19, 1.0)
const HP_OFF := Color(0.96, 0.96, 0.96, 1.0)
const XP_ON := Color(0.86, 0.15, 0.95, 1.0)
const XP_OFF := Color(0.96, 0.96, 0.96, 1.0)
const SEGMENT_DISABLED := Color(0.62, 0.62, 0.62, 1.0)
const DICE_NAMES := ["Bronce", "Plata", "Oro", "Platino", "Diamante"]
const DICE_COLORS := [
	Color(0.76, 0.50, 0.26, 1.0),
	Color(0.80, 0.82, 0.88, 1.0),
	Color(1.00, 0.84, 0.24, 1.0),
	Color(0.16, 0.58, 0.36, 1.0),
	Color(0.28, 0.88, 1.00, 1.0),
]
const LEVEL_TEXT := {
	1: "BRONCE",
	2: "PLATA",
	3: "ORO",
	4: "PLATINO",
	5: "DIAMANTE",
}
const LEVEL_COLORS := {
	1: Color(0.85, 0.55, 0.25, 1.0),
	2: Color(0.80, 0.82, 0.88, 1.0),
	3: Color(1.00, 0.84, 0.24, 1.0),
	4: Color(0.16, 0.58, 0.36, 1.0),
	5: Color(0.28, 0.88, 1.00, 1.0),
}
const UNIT_PANEL_NEUTRAL := Color(0.52, 0.56, 0.64, 0.90)
const CLASS_ICON_PATHS := {
	0: "res://assets/sprites/ui/class_icons/warrior_icon.png",
	1: "res://assets/sprites/ui/class_icons/archer_icon.png",
	2: "res://assets/sprites/ui/class_icons/lancer_icon.png",
	3: "res://assets/sprites/ui/class_icons/rider_icon.png",
}
const MASTER_ICON_PATH := "res://assets/sprites/ui/class_icons/master_icon.png"
const PLACEMENT_ADVANTAGE_ICON_PATH := "res://assets/sprites/ui/tutorial/ventajas.png"
const TOWER_ICON_PATH := "res://assets/sprites/ui/icon_tower.png"
const ESSENCE_ICON_PATH := "res://assets/sprites/ui/icon_essence.png"
const ESSENCE_ICON_INLINE_PATH := "res://assets/sprites/ui/icon_essence_cyan.png"
const UNITS_ICON_PATH := "res://assets/sprites/ui/icon_units.png"
const UNIT_TYPE_DISPLAY_NAMES := {
	-1: "Maestro",
	0: "Guerrero",
	1: "Arquero",
	2: "Lancero",
	3: "Jinete",
}
const MINIMAP_TERRAIN_COLORS := [
	Color(0.44, 0.76, 0.33, 1.0),
	Color(0.22, 0.52, 0.88, 1.0),
	Color(0.52, 0.52, 0.52, 1.0),
	Color(0.13, 0.44, 0.13, 1.0),
	Color(0.84, 0.78, 0.42, 1.0),
	Color(0.72, 0.18, 0.05, 1.0),
	Color(0.20, 0.22, 0.26, 1.0),
]
const TERRAIN_DISPLAY_NAMES := {
	0: "Pasto",
	1: "Agua",
	2: "Montana",
	3: "Bosque",
	4: "Desierto",
	5: "Volcan",
	6: "Cordillera",
}
const COMBAT_HUD_ALPHA := 0.20
const COMBAT_BAR_HEIGHT := 54.0
const HUD_HP_SEGMENT_COLUMNS := 20
const HUD_HP_SEGMENT_COUNT := 60
const COMBAT_BLESSING_IDS := {
	"tough_skin": true,
	"hardened_hide": true,
	"colossus": true,
	"resistant": true,
	"raider": true,
	"bloodletting": true,
	"slayer_instinct": true,
	"cataclysm": true,
	"fury": true,
	"cleaver": true,
	"executioner": true,
	"precision": true,
	"long_range": true,
	"volley": true,
	"marksman": true,
	"javelin_expert": true,
	"charge": true,
	"pathfinder": true,
	"pinning": true,
	"flanking": true,
	"brutal_charge": true,
	"trample": true,
	"aura": true,
	"leadership": true,
	"royal_guard": true,
}
const COMBAT_BLESSING_LIMIT := 3

var _hud_view_scale: float = 1.0
var _hud_view_origin: Vector2 = Vector2.ZERO
var _root: Control
var _cinematic_top_bar: ColorRect
var _cinematic_bottom_bar: ColorRect
var _turn_band_glow: ColorRect
var _turn_band_core: ColorRect
var _turn_band_glow_bottom: ColorRect
var _turn_band_core_bottom: ColorRect
var _turn_panel_glow: Panel
var _team_icon: ColorRect
var _lbl_towers: Label
var _lbl_essence: Label
var _lbl_unit_count: Label
var _lbl_turn_num: Label
var _lbl_turn_caption: Label
var _lbl_turn_cycle_icon: Label
var _lbl_turn_time: Label
var _portrait: TextureRect
var _portrait_bg: TextureRect
var _unit_class_icon: TextureRect
var _unit_level_bar: ColorRect
var _unit_panel_glass: Panel
var _unit_panel_corner_nodes: Array[ColorRect] = []
var _unit_simple_panel: Panel
var _unit_simple_accent_line: ColorRect
var _unit_simple_top_line: ColorRect
var _unit_simple_portrait: TextureRect
var _unit_simple_class_icon: TextureRect
var _unit_simple_name: Label
var _unit_simple_hp: Label
var _unit_simple_xp: Label
var _unit_simple_move: Label
var _unit_simple_attack: Label
var _unit_simple_defense: Label
var _unit_simple_melee_label: Label
var _unit_simple_ranged_label: Label
var _unit_simple_melee_dice: Control
var _unit_simple_ranged_dice: Control
var _unit_simple_chevron: Label
var _lbl_unit_name: Label
var _lbl_unit_level: Label
var _lbl_unit_tier: Label
var _lbl_hp_caption: Label
var _lbl_hp_value: Label
var _lbl_move_caption: Label
var _lbl_xp_value: Label
var _lbl_range_caption: Label
var _lbl_xp_caption: Label
var _lbl_move_value: Label
var _lbl_range_value: Label
var _lbl_defense_caption: Label
var _lbl_defense_value: Label
var _lbl_melee: Label
var _lbl_ranged: Label
var _lbl_advantage: Label
var _lbl_advantage_detail: Label
var _lbl_no_unit: Label
var _melee_dice_container: Control
var _ranged_dice_container: Control
var _btn_summon: Button
var _btn_end_turn: Button
var _summon_glow: ColorRect
var _end_turn_glow: ColorRect
var _summon_flame: Dictionary = {}
var _end_turn_flame: Dictionary = {}
var _summon_motes: Array[Dictionary] = []
var _end_turn_motes: Array[Dictionary] = []
var _btn_last_combat: Button
var _btn_pause_menu: Button
var _btn_speed_x1: Button
var _btn_speed_x2: Button
var _btn_speed_x3: Button
var _placement_banner: Panel
var _placement_hint_icon: TextureRect
var _lbl_placement_title: Label
var _lbl_placement: RichTextLabel
var _combat_panel: Panel
var _lbl_cb_title: Label
var _lbl_cb_attacker: Label
var _lbl_cb_defender: Label
var _cb_attacker_chips: HBoxContainer
var _cb_defender_chips: HBoxContainer
var _lbl_cb_log: Label
var _lbl_cb_result: Label
var _minimap_texture: Control
var _minimap_panel: Panel
var _btn_minimap_toggle: Button
var _minimap_expanded: bool = false
var _unit_accent_line: ColorRect
var _hp_segments: Array[Panel] = []
var _xp_segments: Array[Panel] = []
var _unit_panel_base_nodes: Array[CanvasItem] = []
var _unit_detail_nodes: Array[CanvasItem] = []
var _btn_unit_panel_mode: Button
var _btn_unit_simple_mode: Button
var _unit_panel_detailed: bool = false
var _current_unit: Unit = null
var _lbl_tw_p1: Label
var _lbl_tw_p2: Label
var _lbl_tw_neutral: Label
var _lbl_tw_income: Label
var _last_combat_data: Dictionary = {}
var _ui_fx_time: float = 0.0
var _portrait_cache: Dictionary = {}
var _pause_canvas: CanvasLayer   # layer 20 — always above CardHand (10)
var _pause_overlay: ColorRect
var _pause_panel: Panel
var _btn_pause_resume: Button
var _btn_pause_save: Button
var _btn_pause_save_exit: Button
var _btn_pause_restart: Button
var _btn_pause_cell_context: Button
var _btn_pause_help: Button
var _btn_pause_back_menu: Button
var _pause_help_panel: Panel
var _pause_confirm_panel: Panel
var _pause_confirm_label: Label
var _btn_pause_confirm_yes: Button
var _btn_pause_confirm_no: Button
var _cell_context_panel: Panel
var _lbl_cell_context_title: Label
var _lbl_cell_context_body: Label
var _tutorial_panel: Panel
var _lbl_tutorial_step: Label
var _lbl_tutorial_title: RichTextLabel
var _lbl_tutorial_body: RichTextLabel
var _btn_tutorial_next: Button
var _tutorial_info_panel: Panel
var _lbl_tutorial_info_title: Label
var _lbl_tutorial_info_body: Label
var _tutorial_info_subject_rich: RichTextLabel
var _tutorial_info_target_rich: RichTextLabel
var _btn_tutorial_info_continue: Button
var _tutorial_completion_panel: Panel
var _lbl_tutorial_completion_title: Label
var _lbl_tutorial_completion_body: Label
var _btn_tutorial_completion_continue: Button
var _tutorial_info_advantage_icons: Array[TextureRect] = []
var _tutorial_info_advantage_arrows: Array[Label] = []
var _tutorial_panel_outline: TutorialOutline
var _tutorial_summon_outline: TutorialOutline
var _tutorial_end_turn_outline: TutorialOutline
var _tutorial_resources_outline: TutorialOutline
var _tutorial_turn_outline: TutorialOutline
var _tutorial_advantage_outline: TutorialOutline
var _tutorial_minimap_outline: TutorialOutline
var _tutorial_unit_panel_outline: TutorialOutline
var _tutorial_spotlight_layer: CanvasLayer
var _tutorial_spotlight_rect: ColorRect
var _tutorial_spotlight_mat: ShaderMaterial
var _tutorial_overlay_layer: CanvasLayer
var _tutorial_overlay_root: Control
var _tutorial_custom_focus_rect: Rect2 = Rect2()


func _get_help_glossary_bbcode() -> String:
	var glossary_script = load("res://scripts/HelpGlossary.gd")
	if glossary_script == null:
		return "[color=#ff8d8d]No se pudo cargar la ayuda.[/color]"
	if glossary_script.has_method("build_bbcode"):
		return str(glossary_script.call("build_bbcode"))
	return "[color=#ff8d8d]La ayuda no esta disponible por ahora.[/color]"
var _tutorial_summon_arrow: TextureRect
var _tutorial_end_turn_arrow: TextureRect
var _tutorial_resources_arrow: TextureRect
var _tutorial_turn_arrow: TextureRect
var _tutorial_advantage_arrow: TextureRect
var _tutorial_minimap_arrow: TextureRect
var _tutorial_unit_panel_arrow: TextureRect
var _tutorial_cards_arrow: TextureRect
var _tutorial_master_arrow: TextureRect
var _tutorial_tower_arrow: TextureRect
var _tutorial_master_world: Vector3 = Vector3.ZERO
var _tutorial_tower_world: Vector3 = Vector3.ZERO
var _tutorial_show_master_arrow: bool = false
var _tutorial_show_tower_arrow: bool = false
var _audio_enabled: bool = true
var _pause_confirm_action: String = ""
var _tutorial_force_summon_glow: bool = false
var _tutorial_force_end_turn_glow: bool = false
var _advantage_tracker: MatchAdvantage = MatchAdvantageScript.new()
var _advantage_title: Label
var _advantage_status: Label
var _advantage_bar_bg: ColorRect
var _advantage_bar_fill_container: Control
var _advantage_hover_area: Control
var _advantage_rank_labels: Array[Label] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_root()
	_build_background()
	_build_style_overlays()
	_build_top_left_stats()
	_build_turn_display()
	_build_last_combat_button()
	_build_advantage_panel()
	_build_pause_menu()
	_build_minimap()
	_build_unit_panel()
	_build_summon_button()
	_build_end_turn_button()
	_build_placement_banner()
	_build_cell_context_panel()
	_build_tutorial_panel()
	_build_tutorial_info_panel()
	_build_tutorial_completion_panel()
	_build_combat_panel()
	_refresh_pause_cell_context_button()
	_apply_tooltip_preferences()
	_update_view_layout()
	hide_unit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_update_view_layout()

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode != KEY_ESCAPE:
		return
	if is_pause_menu_open():
		if _is_pause_confirm_open():
			_close_pause_confirmation()
		else:
			emit_signal("pause_menu_toggled", false)

func _player_color(player_id: int) -> Color:
	return GameData.get_player_color(player_id)

func _clear_blessing_chips(container: HBoxContainer) -> void:
	if container == null:
		return
	for child: Node in container.get_children():
		child.queue_free()

func _blessing_chip_color(bonus_id: String) -> Color:
	match bonus_id:
		"resistant", "pinning", "royal_guard":
			return Color(0.47, 0.80, 1.0, 1.0)
		"long_range", "precision", "volley", "marksman", "javelin_expert":
			return Color(0.42, 0.88, 1.0, 1.0)
		"pathfinder", "raider", "aura", "leadership":
			return Color(0.55, 0.90, 0.56, 1.0)
		_:
			return Color(1.0, 0.80, 0.24, 1.0)

func _make_blessing_chip(text_value: String, color: Color) -> Control:
	var chip := PanelContainer.new()
	chip.custom_minimum_size = Vector2(0, 16)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r * 0.18, color.g * 0.18, color.b * 0.18, 0.92)
	style.border_color = Color(color.r, color.g, color.b, 0.88)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	chip.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(label)
	return chip

func _get_combat_relevant_bonuses(unit: Unit) -> Array:
	var result: Array = []
	if unit == null or not is_instance_valid(unit):
		return result
	for bonus_variant: Variant in unit.active_bonuses:
		var bonus_id := str(bonus_variant)
		if not COMBAT_BLESSING_IDS.has(bonus_id):
			continue
		var bonus_data: Dictionary = BonusSystemScript.BONUSES.get(bonus_id, {})
		var bonus_name := str(bonus_data.get("name", bonus_id))
		result.append({
			"id": bonus_id,
			"name": bonus_name,
			"description": str(bonus_data.get("description", "")),
		})
	return result

func _populate_blessing_chips(container: HBoxContainer, blessings: Array) -> void:
	_clear_blessing_chips(container)
	if container == null:
		return
	var shown := mini(blessings.size(), COMBAT_BLESSING_LIMIT)
	for i: int in range(shown):
		var blessing: Dictionary = blessings[i] as Dictionary
		var bonus_id := str(blessing.get("id", ""))
		var chip := _make_blessing_chip(str(blessing.get("name", bonus_id)), _blessing_chip_color(bonus_id))
		var tip := str(blessing.get("description", ""))
		if not tip.is_empty():
			_set_control_tooltip(chip, tip)
		container.add_child(chip)
	if blessings.size() > COMBAT_BLESSING_LIMIT:
		var extra_count := blessings.size() - COMBAT_BLESSING_LIMIT
		var extra_chip := _make_blessing_chip("+%d" % extra_count, LABEL_DIM)
		var extra_names: Array[String] = []
		for i: int in range(COMBAT_BLESSING_LIMIT, blessings.size()):
			var blessing: Dictionary = blessings[i] as Dictionary
			extra_names.append(str(blessing.get("name", "")))
		_set_control_tooltip(extra_chip, ", ".join(extra_names))
		container.add_child(extra_chip)

func _process(delta: float) -> void:
	_ui_fx_time += delta
	_update_button_flame(_summon_flame, _btn_summon, SUMMON_READY_COLOR, _is_button_glow_enabled(_summon_glow))
	_update_button_flame(_end_turn_flame, _btn_end_turn, END_TURN_READY_COLOR, _is_button_glow_enabled(_end_turn_glow))
	_update_button_motes(_summon_motes, _btn_summon, SUMMON_READY_COLOR, _is_button_glow_enabled(_summon_glow))
	_update_button_motes(_end_turn_motes, _btn_end_turn, END_TURN_READY_COLOR, _is_button_glow_enabled(_end_turn_glow))
	_update_tutorial_info_diagram()
	_update_tutorial_arrows()
	_update_simple_unit_panel_position()

func set_combat_cinematic(active: bool) -> void:
	var target_alpha: float = 0.0 if active else 1.0
	create_tween().tween_property(_root, "modulate:a", target_alpha, 0.24) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var target_height: float = COMBAT_BAR_HEIGHT if active else 0.0
	var target_bar_alpha: float = 0.78 if active else 0.0

	if _cinematic_top_bar != null:
		_cinematic_top_bar.position = Vector2.ZERO
		_cinematic_top_bar.size.x = _viewport_size().x
		var top_tw := create_tween().set_parallel(true)
		top_tw.tween_property(_cinematic_top_bar, "size:y", target_height, 0.28) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		top_tw.tween_property(_cinematic_top_bar, "color:a", target_bar_alpha, 0.24) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	if _cinematic_bottom_bar != null:
		var viewport_size: Vector2 = _viewport_size()
		_cinematic_bottom_bar.size.x = viewport_size.x
		var bottom_y: float = viewport_size.y - target_height
		var bottom_tw := create_tween().set_parallel(true)
		bottom_tw.tween_property(_cinematic_bottom_bar, "position:y", bottom_y, 0.28) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		bottom_tw.tween_property(_cinematic_bottom_bar, "size:y", target_height, 0.28) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		bottom_tw.tween_property(_cinematic_bottom_bar, "color:a", target_bar_alpha, 0.24) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _build_root() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_tutorial_spotlight_layer = CanvasLayer.new()
	_tutorial_spotlight_layer.layer = 40
	add_child(_tutorial_spotlight_layer)

	_tutorial_spotlight_rect = ColorRect.new()
	_tutorial_spotlight_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tutorial_spotlight_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tutorial_spotlight_rect.visible = false
	_tutorial_spotlight_mat = ShaderMaterial.new()
	_tutorial_spotlight_mat.shader = TutorialSpotlightShader
	_tutorial_spotlight_rect.material = _tutorial_spotlight_mat
	_tutorial_spotlight_layer.add_child(_tutorial_spotlight_rect)

	_tutorial_overlay_layer = CanvasLayer.new()
	_tutorial_overlay_layer.layer = 41
	add_child(_tutorial_overlay_layer)

	_tutorial_overlay_root = Control.new()
	_tutorial_overlay_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tutorial_overlay_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tutorial_overlay_layer.add_child(_tutorial_overlay_root)

	_cinematic_top_bar = ColorRect.new()
	_cinematic_top_bar.position = Vector2(0.0, 0.0)
	_cinematic_top_bar.size = Vector2(_viewport_size().x, 0.0)
	_cinematic_top_bar.color = Color(0.0, 0.0, 0.0, 0.0)
	_cinematic_top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cinematic_top_bar)

	_cinematic_bottom_bar = ColorRect.new()
	_cinematic_bottom_bar.position = Vector2(0.0, _viewport_size().y)
	_cinematic_bottom_bar.size = Vector2(_viewport_size().x, 0.0)
	_cinematic_bottom_bar.color = Color(0.0, 0.0, 0.0, 0.0)
	_cinematic_bottom_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cinematic_bottom_bar)

func _build_background() -> void:
	var top_line := ColorRect.new()
	top_line.position = Vector2(0, 58)
	top_line.size = Vector2(HUD_SIZE.x, 1)
	top_line.color = HUD_LINE
	top_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(top_line)

	var top_fade := ColorRect.new()
	top_fade.position = Vector2(0, 59)
	top_fade.size = Vector2(HUD_SIZE.x, 1)
	top_fade.color = HUD_LINE_SOFT
	top_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(top_fade)

	var bottom_line := ColorRect.new()
	bottom_line.position = Vector2(0, 700)
	bottom_line.size = Vector2(HUD_SIZE.x, 1)
	bottom_line.color = HUD_LINE
	bottom_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bottom_line)

	var bottom_fade := ColorRect.new()
	bottom_fade.position = Vector2(0, 699)
	bottom_fade.size = Vector2(HUD_SIZE.x, 1)
	bottom_fade.color = HUD_LINE_SOFT
	bottom_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bottom_fade)

func _build_style_overlays() -> void:
	_turn_band_glow = ColorRect.new()
	_turn_band_glow.position = Vector2(0, 0)
	_turn_band_glow.size = Vector2(HUD_SIZE.x, 12)
	var _p1c: Color = GameData.get_player_color(1)
	_turn_band_glow.color = Color(_p1c.r, _p1c.g, _p1c.b, 0.20)
	_turn_band_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_turn_band_glow)

	_turn_band_core = ColorRect.new()
	_turn_band_core.position = Vector2(0, 0)
	_turn_band_core.size = Vector2(HUD_SIZE.x, 4)
	_turn_band_core.color = _p1c
	_turn_band_core.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_turn_band_core)

	_turn_band_glow_bottom = ColorRect.new()
	_turn_band_glow_bottom.position = Vector2(0, HUD_SIZE.y - 12)
	_turn_band_glow_bottom.size = Vector2(HUD_SIZE.x, 12)
	_turn_band_glow_bottom.color = Color(_p1c.r, _p1c.g, _p1c.b, 0.20)
	_turn_band_glow_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_turn_band_glow_bottom)

	_turn_band_core_bottom = ColorRect.new()
	_turn_band_core_bottom.position = Vector2(0, HUD_SIZE.y - 4)
	_turn_band_core_bottom.size = Vector2(HUD_SIZE.x, 4)
	_turn_band_core_bottom.color = _p1c
	_turn_band_core_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_turn_band_core_bottom)

	_add_glass_panel(Rect2(8, 8, 198, 44), HUD_GLASS_DARK)
	_turn_panel_glow = _add_glass_panel(Rect2(214, 8, 120, 44), Color(_p1c.r, _p1c.g, _p1c.b, 0.16))
	_add_glass_panel(Rect2(332, 8, 580, 44), Color(0.16, 0.18, 0.22, 0.58))
	_unit_panel_glass = _add_glass_panel(Rect2(18, 506, 346, 194), Color(0.18, 0.20, 0.24, 0.58))
	_add_glass_panel(Rect2(384, 640, 136, 54), HUD_GLASS_DARK)
	_add_glass_panel(Rect2(1114, 640, 134, 60), HUD_GLASS_DARK)
	_add_corner_lines()

func _add_glass_panel(rect: Rect2, color: Color) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_panel_style(panel, color)
	_root.add_child(panel)
	return panel

func _add_corner_lines() -> void:
	_unit_panel_corner_nodes.clear()
	for rect: Rect2 in [
		Rect2(8, 8, 198, 44),
		Rect2(214, 8, 120, 44),
		Rect2(332, 8, 580, 44),
		Rect2(18, 506, 346, 194),
		Rect2(384, 640, 136, 54),
		Rect2(1114, 640, 134, 60),
	]:
		var nodes: Array[ColorRect] = _add_panel_corners(rect)
		if rect == Rect2(18, 506, 346, 194):
			_unit_panel_corner_nodes = nodes

func _add_panel_corners(rect: Rect2) -> Array[ColorRect]:
	var nodes: Array[ColorRect] = []
	for segment_rect: Rect2 in [
		Rect2(rect.position.x, rect.position.y, 16, 1),
		Rect2(rect.position.x, rect.position.y, 1, 16),
		Rect2(rect.end.x - 16, rect.position.y, 16, 1),
		Rect2(rect.end.x - 1, rect.position.y, 1, 16),
		Rect2(rect.position.x, rect.end.y - 1, 16, 1),
		Rect2(rect.position.x, rect.end.y - 16, 1, 16),
		Rect2(rect.end.x - 16, rect.end.y - 1, 16, 1),
		Rect2(rect.end.x - 1, rect.end.y - 16, 1, 16),
	]:
		var line := ColorRect.new()
		line.position = segment_rect.position
		line.size = segment_rect.size
		line.color = HUD_BORDER_BRIGHT
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(line)
		nodes.append(line)
	return nodes

func _build_top_left_stats() -> void:
	_team_icon = ColorRect.new()
	_team_icon.position = Vector2(18, 15)
	_team_icon.size = Vector2(8, 22)
	_team_icon.color = GameData.get_player_color(1)
	_root.add_child(_team_icon)

	_add_stat_texture_icon("res://assets/sprites/ui/icon_tower.png", Vector2(34, 12), Vector2(22, 22))
	_add_stat_texture_icon("res://assets/sprites/ui/icon_essence.png", Vector2(95, 12), Vector2(22, 22), Color(0.42, 0.88, 1.0, 1.0), true)
	_add_stat_texture_icon("res://assets/sprites/ui/icon_units.png", Vector2(156, 11), Vector2(24, 24))

	_lbl_towers = _make_label("0", Vector2(54, 10), HUD_FONT_SIZE_LARGE)
	_lbl_towers.position = Vector2(53, 16)
	_lbl_towers.size = Vector2(28, 18)
	_lbl_towers.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_essence = _make_label("0", Vector2(115, 10), HUD_FONT_SIZE_LARGE)
	_lbl_essence.position = Vector2(114, 16)
	_lbl_essence.size = Vector2(28, 18)
	_lbl_essence.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_unit_count = _make_label("0", Vector2(176, 10), HUD_FONT_SIZE_LARGE)
	_lbl_unit_count.position = Vector2(175, 16)
	_lbl_unit_count.size = Vector2(28, 18)
	_lbl_unit_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_make_label("TORRES", Vector2(30, 33), 10, Vector2(58, 10), LABEL_DIM)
	_make_label("ESENCIA", Vector2(87, 33), 10, Vector2(64, 10), LABEL_DIM)
	_make_label("UNIDADES", Vector2(145, 33), 10, Vector2(66, 10), LABEL_DIM)

	_lbl_tw_p1 = Label.new()
	_lbl_tw_p2 = Label.new()
	_lbl_tw_neutral = Label.new()
	_lbl_tw_income = Label.new()

func _add_stat_texture_icon(path: String, pos: Vector2, size: Vector2, modulate_color: Color = Color(1, 1, 1, 1), glow: bool = false) -> void:
	if glow:
		var glow_rect := TextureRect.new()
		glow_rect.texture = load(path)
		glow_rect.position = pos - Vector2(4, 4)
		glow_rect.size = size + Vector2(8, 8)
		glow_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glow_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		glow_rect.modulate = Color(modulate_color.r, modulate_color.g, modulate_color.b, 0.34)
		glow_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(glow_rect)

	var icon := TextureRect.new()
	icon.texture = load(path)
	icon.position = pos
	icon.size = size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = modulate_color
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(icon)

func _build_turn_display() -> void:
	var divider := ColorRect.new()
	divider.position = Vector2(274, 12)
	divider.size = Vector2(1, 32)
	divider.color = Color(1.0, 1.0, 1.0, 0.10)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(divider)

	_lbl_turn_num = _make_label("1", Vector2(224, 12), HUD_FONT_SIZE_LARGE, Vector2(38, 18))
	_lbl_turn_num.position = Vector2(224, 12)
	_lbl_turn_num.size = Vector2(38, 18)
	_lbl_turn_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_turn_caption = _make_label("TURNO", Vector2(218, 30), 10, Vector2(50, 10), LABEL_DIM)
	_lbl_turn_caption.position = Vector2(218, 30)
	_lbl_turn_caption.size = Vector2(50, 10)
	_lbl_turn_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_lbl_turn_cycle_icon = _make_label("☀", Vector2(287, 12), 16, Vector2(20, 16), LABEL_DIM)
	_lbl_turn_cycle_icon.position = Vector2(287, 12)
	_lbl_turn_cycle_icon.size = Vector2(20, 16)
	_lbl_turn_cycle_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_turn_time = _make_label("DIA", Vector2(277, 30), 10, Vector2(40, 10), LABEL_DIM)
	_lbl_turn_time.position = Vector2(277, 30)
	_lbl_turn_time.size = Vector2(40, 10)
	_lbl_turn_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _build_last_combat_button() -> void:
	_btn_last_combat = _make_button("Último combate", Vector2(700, 12), Vector2(180, 20), HUD_FONT_SIZE_SMALL)
	_btn_last_combat.position = Vector2(-400, -120)
	_btn_last_combat.size = Vector2(1, 1)
	_btn_last_combat.disabled = true
	_btn_last_combat.visible = false
	_btn_last_combat.pressed.connect(_toggle_combat_panel)
	_btn_last_combat.pressed.connect(AudioManager.play_button)

	_btn_speed_x1 = _make_button("x1", Vector2(924, 8), Vector2(50, 32), HUD_FONT_SIZE_SMALL)
	_btn_speed_x1.position = Vector2(924, 8)
	_set_control_tooltip(_btn_speed_x1, "Velocidad normal")
	_btn_speed_x1.pressed.connect(func() -> void:
		emit_signal("game_speed_selected", 1.0)
		AudioManager.play_button()
	)

	_btn_speed_x2 = _make_button("x2", Vector2(978, 8), Vector2(50, 32), HUD_FONT_SIZE_SMALL)
	_btn_speed_x2.position = Vector2(978, 8)
	_set_control_tooltip(_btn_speed_x2, "Aumentar velocidad a x2")
	_btn_speed_x2.pressed.connect(func() -> void:
		emit_signal("game_speed_selected", 2.0)
		AudioManager.play_button()
	)

	_btn_speed_x3 = _make_button("x3", Vector2(1032, 8), Vector2(50, 32), HUD_FONT_SIZE_SMALL)
	_btn_speed_x3.position = Vector2(1032, 8)
	_set_control_tooltip(_btn_speed_x3, "Aumentar velocidad a x3")
	_btn_speed_x3.pressed.connect(func() -> void:
		emit_signal("game_speed_selected", 3.0)
		AudioManager.play_button()
	)

	_btn_pause_menu = _make_button("Menu", Vector2(1180, 8), Vector2(84, 32), HUD_FONT_SIZE_SMALL)
	_btn_pause_menu.position = Vector2(1180, 8)
	_set_control_tooltip(_btn_pause_menu, "Opciones de partida")
	_btn_pause_menu.pressed.connect(_toggle_pause_menu)
	_btn_pause_menu.pressed.connect(AudioManager.play_button)

	set_game_speed_buttons(1.0)

func _build_advantage_panel() -> void:
	_advantage_title = _make_label("VENTAJA", Vector2(346, 14), 10, Vector2(78, 12), LABEL_DIM)
	_advantage_status = _make_label("", Vector2(430, 14), HUD_FONT_SIZE_SMALL, Vector2(462, 16), LABEL_COLOR)
	_advantage_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	_advantage_hover_area = Control.new()
	_advantage_hover_area.position = Vector2(332, 8)
	_advantage_hover_area.size = Vector2(580, 58)
	_advantage_hover_area.mouse_filter = Control.MOUSE_FILTER_STOP
	_advantage_hover_area.mouse_entered.connect(func() -> void:
		_set_advantage_details_visible(true)
	)
	_advantage_hover_area.mouse_exited.connect(func() -> void:
		_set_advantage_details_visible(false)
	)
	_root.add_child(_advantage_hover_area)

	_advantage_bar_bg = ColorRect.new()
	_advantage_bar_bg.position = Vector2(346, 28)
	_advantage_bar_bg.size = Vector2(546, 8)
	_advantage_bar_bg.color = Color(1.0, 1.0, 1.0, 0.08)
	_advantage_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_advantage_bar_bg)

	_advantage_bar_fill_container = Control.new()
	_advantage_bar_fill_container.position = _advantage_bar_bg.position
	_advantage_bar_fill_container.size = _advantage_bar_bg.size
	_advantage_bar_fill_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_advantage_bar_fill_container)

	for i: int in range(4):
		var label := _make_label("", Vector2(346 + float(i % 2) * 274.0, 40 + float(i / 2) * 12.0), 10, Vector2(264, 12), LABEL_DIM)
		_advantage_rank_labels.append(label)

	_set_advantage_details_visible(false)
	refresh_advantage()

func _build_minimap() -> void:
	_minimap_panel = Panel.new()
	_minimap_panel.position = Vector2(980, 50)
	_minimap_panel.size = Vector2(286, 166)
	_minimap_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_panel_style(_minimap_panel, Color(0.08, 0.10, 0.14, 0.68))
	_root.add_child(_minimap_panel)

	_btn_minimap_toggle = _make_button("Mapa", Vector2(1086, 8), Vector2(90, 32), HUD_FONT_SIZE_SMALL)
	_btn_minimap_toggle.position = Vector2(1086, 8)
	_set_control_tooltip(_btn_minimap_toggle, "Mostrar u ocultar mapa")
	_btn_minimap_toggle.pressed.connect(func() -> void:
		_set_minimap_expanded(not _minimap_expanded)
		AudioManager.play_button()
	)

	_minimap_texture = Control.new()
	_minimap_texture.position = Vector2(4, 4)
	_minimap_texture.size = Vector2(278, 158)
	_minimap_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_minimap_texture.clip_contents = true
	_minimap_panel.add_child(_minimap_texture)
	_set_minimap_expanded(false)
	_redraw_minimap()

func _set_minimap_expanded(expanded: bool) -> void:
	_minimap_expanded = expanded
	if _minimap_panel != null:
		_minimap_panel.visible = expanded

func _build_unit_panel() -> void:
	_unit_panel_base_nodes.clear()
	_unit_detail_nodes.clear()
	_unit_accent_line = ColorRect.new()
	_unit_accent_line.position = Vector2(22, 518)
	_unit_accent_line.size = Vector2(4, 176)
	_unit_accent_line.color = UNIT_PANEL_NEUTRAL
	_unit_accent_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_unit_accent_line)
	_unit_panel_base_nodes.append(_unit_accent_line)

	_unit_level_bar = ColorRect.new()
	_unit_level_bar.position = Vector2(30, 506)
	_unit_level_bar.size = Vector2(326, 7)
	_unit_level_bar.color = UNIT_PANEL_NEUTRAL
	_unit_level_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_unit_level_bar)
	_unit_panel_base_nodes.append(_unit_level_bar)

	var portrait_glow := ColorRect.new()
	portrait_glow.position = Vector2(26, 514)
	portrait_glow.size = Vector2(110, 138)
	portrait_glow.color = Color(SUMMON_READY_COLOR.r, SUMMON_READY_COLOR.g, SUMMON_READY_COLOR.b, 0.10)
	portrait_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(portrait_glow)
	_unit_panel_base_nodes.append(portrait_glow)

	var portrait_frame := ColorRect.new()
	portrait_frame.position = Vector2(30, 518)
	portrait_frame.size = Vector2(102, 130)
	portrait_frame.color = Color(0.14, 0.20, 0.26, 0.58)
	portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(portrait_frame)
	_unit_panel_base_nodes.append(portrait_frame)

	_portrait = TextureRect.new()
	_portrait.position = Vector2(26, 514)
	_portrait.size = Vector2(110, 138)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_portrait)
	_unit_panel_base_nodes.append(_portrait)

	_portrait_bg = TextureRect.new()
	_portrait_bg.position = Vector2(184, 514)
	_portrait_bg.size = Vector2(152, 122)
	_portrait_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait_bg.modulate = Color(1.0, 1.0, 1.0, 0.18)
	_portrait_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_portrait_bg)
	_unit_panel_base_nodes.append(_portrait_bg)

	_unit_class_icon = TextureRect.new()
	_unit_class_icon.position = Vector2(138, 519)
	_unit_class_icon.size = Vector2(20, 20)
	_unit_class_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_unit_class_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_unit_class_icon.modulate = Color(0.96, 0.98, 1.0, 0.92)
	_unit_class_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_unit_class_icon)
	_unit_panel_base_nodes.append(_unit_class_icon)

	_btn_unit_panel_mode = _make_button("Detalle", Vector2(258, 518), Vector2(86, 24), 11)
	_btn_unit_panel_mode.mouse_filter = Control.MOUSE_FILTER_STOP
	_btn_unit_panel_mode.pressed.connect(_toggle_unit_panel_mode)
	_btn_unit_panel_mode.pressed.connect(AudioManager.play_button)
	_unit_panel_base_nodes.append(_btn_unit_panel_mode)

	_lbl_unit_name = _make_label("", Vector2(164, 520), HUD_FONT_SIZE_LARGE, Vector2(148, 18))
	_lbl_unit_level = _make_label("", Vector2(138, 540), HUD_FONT_SIZE_SMALL, Vector2(120, 16), LABEL_DIM)
	_lbl_unit_tier = _make_label("", Vector2(0, 0), HUD_FONT_SIZE_SMALL, Vector2.ZERO, LABEL_DIM)
	_lbl_unit_tier.visible = false
	_unit_panel_base_nodes.append(_lbl_unit_name)
	_unit_panel_base_nodes.append(_lbl_unit_level)

	_lbl_hp_caption = _make_label("VIDA", Vector2(138, 568), 11, Vector2(42, 16), LABEL_DIM)
	_lbl_hp_value = _make_label("", Vector2(176, 566), HUD_FONT_SIZE, Vector2(72, 18), HP_ON)
	_lbl_move_caption = _make_label("MOV", Vector2(244, 568), 11, Vector2(34, 16), LABEL_DIM)
	_lbl_move_value = _make_label("", Vector2(272, 566), HUD_FONT_SIZE, Vector2(28, 18), LABEL_COLOR)
	_lbl_range_caption = _make_label("ALC", Vector2(306, 568), 11, Vector2(30, 16), LABEL_DIM)
	_lbl_range_value = _make_label("", Vector2(332, 566), HUD_FONT_SIZE, Vector2(24, 18), LABEL_COLOR)
	_lbl_defense_caption = _make_label("DEF", Vector2(244, 588), 11, Vector2(34, 16), Color(0.18, 0.84, 0.76, 0.72))
	_lbl_defense_value = _make_label("", Vector2(274, 586), HUD_FONT_SIZE, Vector2(48, 18), Color(0.18, 0.84, 0.76, 1.0))
	_unit_panel_base_nodes.append(_lbl_hp_caption)
	_unit_panel_base_nodes.append(_lbl_hp_value)
	_unit_panel_base_nodes.append(_lbl_move_caption)
	_unit_panel_base_nodes.append(_lbl_move_value)
	_unit_panel_base_nodes.append(_lbl_range_caption)
	_unit_panel_base_nodes.append(_lbl_range_value)
	_unit_panel_base_nodes.append(_lbl_defense_caption)
	_unit_panel_base_nodes.append(_lbl_defense_value)

	_lbl_xp_caption = _make_label("EXPERIENCIA", Vector2(138, 628), 11, Vector2(100, 16), LABEL_DIM)
	_lbl_xp_value = _make_label("", Vector2(240, 626), HUD_FONT_SIZE, Vector2(90, 18), XP_ON)
	_unit_panel_base_nodes.append(_lbl_xp_caption)
	_unit_panel_base_nodes.append(_lbl_xp_value)

	for i: int in range(HUD_HP_SEGMENT_COUNT):
		var row: int = int(float(i) / float(HUD_HP_SEGMENT_COLUMNS))
		var col: int = i % HUD_HP_SEGMENT_COLUMNS
		var hp_seg := Panel.new()
		hp_seg.position = Vector2(140 + col * 10, 588 + row * 12)
		hp_seg.size = Vector2(9, 10)
		hp_seg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_apply_segment_style(hp_seg, SEGMENT_DISABLED)
		_root.add_child(hp_seg)
		_hp_segments.append(hp_seg)
		_unit_panel_base_nodes.append(hp_seg)

	for i: int in range(40):
		var row: int = int(float(i) / 20.0)
		var col: int = i % 20
		var xp_seg := Panel.new()
		xp_seg.position = Vector2(140 + col * 10, 650 + row * 12)
		xp_seg.size = Vector2(9, 8)
		xp_seg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_apply_segment_style(xp_seg, SEGMENT_DISABLED)
		_root.add_child(xp_seg)
		_xp_segments.append(xp_seg)
		_unit_panel_base_nodes.append(xp_seg)

	_melee_dice_container = Control.new()
	_melee_dice_container.position = Vector2(54, 660)
	_melee_dice_container.size = Vector2(84, 12)
	_melee_dice_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_melee_dice_container)
	_unit_panel_base_nodes.append(_melee_dice_container)

	_ranged_dice_container = Control.new()
	_ranged_dice_container.position = Vector2(54, 682)
	_ranged_dice_container.size = Vector2(84, 12)
	_ranged_dice_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_ranged_dice_container)
	_unit_panel_base_nodes.append(_ranged_dice_container)

	_lbl_melee = _make_label("M", Vector2(32, 656), HUD_FONT_SIZE, Vector2(20, 18))
	_lbl_ranged = _make_label("R", Vector2(32, 680), HUD_FONT_SIZE, Vector2(20, 18))
	_lbl_advantage = _make_label("", Vector2(138, 656), HUD_FONT_SIZE_SMALL, Vector2(206, 18))
	_lbl_advantage_detail = _make_label("", Vector2(138, 672), 11, Vector2(206, 40), LABEL_DIM)
	_lbl_advantage_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_no_unit = _make_label("Selecciona una unidad", Vector2(138, 660), HUD_FONT_SIZE_SMALL, Vector2(200, 18), LABEL_DIM)
	_unit_panel_base_nodes.append(_lbl_melee)
	_unit_panel_base_nodes.append(_lbl_ranged)
	_unit_panel_base_nodes.append(_lbl_advantage)
	_unit_panel_base_nodes.append(_lbl_advantage_detail)
	_unit_panel_base_nodes.append(_lbl_no_unit)
	_unit_detail_nodes = [
		_lbl_xp_caption,
		_lbl_xp_value,
		_lbl_melee,
		_lbl_ranged,
		_lbl_advantage,
		_lbl_advantage_detail,
		_melee_dice_container,
		_ranged_dice_container
	]
	for hp_seg: Panel in _hp_segments:
		_unit_detail_nodes.append(hp_seg)
	for xp_seg: Panel in _xp_segments:
		_unit_detail_nodes.append(xp_seg)
	_build_simple_unit_panel()
	_set_unit_panel_mode(false)

func _build_summon_button() -> void:
	_summon_glow = _make_button_glow(Vector2(386, 640), Vector2(126, 54))
	_btn_summon = _make_button("Invocar", Vector2(390, 640), Vector2(110, 50), HUD_FONT_SIZE)
	_btn_summon.position = Vector2(392, 646)
	_btn_summon.size = Vector2(118, 42)
	_set_control_tooltip(_btn_summon, "Tecla: E")
	_btn_summon.mouse_filter = Control.MOUSE_FILTER_STOP
	_btn_summon.pressed.connect(func() -> void: emit_signal("summon_pressed"))
	_btn_summon.pressed.connect(AudioManager.play_button)
	_summon_flame = _make_button_flame(_btn_summon, SUMMON_READY_COLOR)
	_summon_motes = _make_button_motes(_btn_summon, SUMMON_READY_COLOR)

func _build_simple_unit_panel() -> void:
	_unit_simple_panel = Panel.new()
	_unit_simple_panel.size = Vector2(346, 74)
	_unit_simple_panel.position = Vector2(18, 622)
	_unit_simple_panel.visible = false
	_unit_simple_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_panel_style(_unit_simple_panel, Color(0.08, 0.09, 0.12, 0.90))
	_root.add_child(_unit_simple_panel)

	_unit_simple_accent_line = ColorRect.new()
	_unit_simple_accent_line.position = Vector2(0, 0)
	_unit_simple_accent_line.size = Vector2(4, 74)
	_unit_simple_accent_line.color = GameData.get_player_color(1)
	_unit_simple_accent_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_unit_simple_panel.add_child(_unit_simple_accent_line)

	_unit_simple_top_line = ColorRect.new()
	_unit_simple_top_line.position = Vector2(0, 0)
	_unit_simple_top_line.size = Vector2(346, 4)
	_unit_simple_top_line.color = UNIT_PANEL_NEUTRAL
	_unit_simple_top_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_unit_simple_panel.add_child(_unit_simple_top_line)

	var portrait_frame := ColorRect.new()
	portrait_frame.position = Vector2(12, 12)
	portrait_frame.size = Vector2(42, 50)
	portrait_frame.color = Color(0.14, 0.20, 0.26, 0.72)
	portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_unit_simple_panel.add_child(portrait_frame)

	_unit_simple_portrait = TextureRect.new()
	_unit_simple_portrait.position = Vector2(9, 8)
	_unit_simple_portrait.size = Vector2(48, 56)
	_unit_simple_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_unit_simple_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_unit_simple_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_unit_simple_panel.add_child(_unit_simple_portrait)

	_unit_simple_class_icon = TextureRect.new()
	_unit_simple_class_icon.position = Vector2(68, 12)
	_unit_simple_class_icon.size = Vector2(16, 16)
	_unit_simple_class_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_unit_simple_class_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_unit_simple_class_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_unit_simple_panel.add_child(_unit_simple_class_icon)

	_unit_simple_name = _make_label("", Vector2(88, 10), 15, Vector2(112, 18), LABEL_COLOR, _unit_simple_panel)
	_unit_simple_hp = _make_label("", Vector2(64, 28), 16, Vector2(134, 18), HP_ON, _unit_simple_panel)
	_unit_simple_xp = _make_label("", Vector2(64, 48), 16, Vector2(134, 18), XP_ON, _unit_simple_panel)
	_unit_simple_move = _make_label("", Vector2(202, 10), 13, Vector2(56, 16), LABEL_COLOR, _unit_simple_panel)
	_unit_simple_attack = _make_label("ATK", Vector2(202, 32), 13, Vector2(30, 16), LABEL_DIM, _unit_simple_panel)
	_unit_simple_defense = _make_label("", Vector2(184, 52), 11, Vector2(44, 14), Color(0.18, 0.84, 0.76, 1.0), _unit_simple_panel)
	_unit_simple_melee_label = _make_label("R", Vector2(232, 30), 11, Vector2(14, 12), LABEL_DIM, _unit_simple_panel)
	_unit_simple_ranged_label = _make_label("M", Vector2(232, 46), 11, Vector2(14, 12), LABEL_DIM, _unit_simple_panel)

	_unit_simple_melee_dice = Control.new()
	_unit_simple_melee_dice.position = Vector2(246, 29)
	_unit_simple_melee_dice.size = Vector2(48, 12)
	_unit_simple_melee_dice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_unit_simple_panel.add_child(_unit_simple_melee_dice)

	_unit_simple_ranged_dice = Control.new()
	_unit_simple_ranged_dice.position = Vector2(246, 45)
	_unit_simple_ranged_dice.size = Vector2(48, 12)
	_unit_simple_ranged_dice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_unit_simple_panel.add_child(_unit_simple_ranged_dice)

	_unit_simple_chevron = _make_label("▲", Vector2(311, 25), 18, Vector2(20, 16), LABEL_DIM, _unit_simple_panel)
	_unit_simple_chevron.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_unit_simple_chevron.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_unit_simple_chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_btn_unit_simple_mode = _make_button("", Vector2(304, 14), Vector2(34, 40), 11)
	_root.remove_child(_btn_unit_simple_mode)
	_unit_simple_panel.add_child(_btn_unit_simple_mode)
	_btn_unit_simple_mode.mouse_filter = Control.MOUSE_FILTER_STOP
	_btn_unit_simple_mode.pressed.connect(_toggle_unit_panel_mode)
	_btn_unit_simple_mode.pressed.connect(AudioManager.play_button)

func _build_end_turn_button() -> void:
	_end_turn_glow = _make_button_glow(Vector2(1114, 640), Vector2(134, 60))
	_btn_end_turn = _make_button("Fin de turno", Vector2(1150, 648), Vector2(110, 44), HUD_FONT_SIZE)
	_btn_end_turn.position = Vector2(1120, 646)
	_btn_end_turn.size = Vector2(122, 48)
	_set_control_tooltip(_btn_end_turn, "Tecla: Enter")
	_btn_end_turn.mouse_filter = Control.MOUSE_FILTER_STOP
	_btn_end_turn.pressed.connect(func() -> void: emit_signal("end_turn_pressed"))
	_btn_end_turn.pressed.connect(AudioManager.play_button)
	_end_turn_flame = _make_button_flame(_btn_end_turn, END_TURN_READY_COLOR)
	_end_turn_motes = _make_button_motes(_btn_end_turn, END_TURN_READY_COLOR)

func _build_placement_banner() -> void:
	_placement_banner = Panel.new()
	_placement_banner.position = Vector2(344, 64)
	_placement_banner.size = Vector2(592, 86)
	_placement_banner.visible = false
	_placement_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_panel_style(_placement_banner, Color(0.06, 0.06, 0.08, 0.88))
	_root.add_child(_placement_banner)

	_placement_hint_icon = TextureRect.new()
	_placement_hint_icon.position = Vector2(18, 18)
	_placement_hint_icon.size = Vector2(48, 48)
	_placement_hint_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_placement_hint_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_placement_hint_icon.texture = load(PLACEMENT_ADVANTAGE_ICON_PATH)
	_placement_hint_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_placement_hint_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_placement_banner.add_child(_placement_hint_icon)

	_lbl_placement_title = _make_label("Invocación", Vector2(84, 12), 12, Vector2(492, 14), LABEL_DIM, _placement_banner)
	_lbl_placement = RichTextLabel.new()
	_lbl_placement.position = Vector2(84, 30)
	_lbl_placement.size = Vector2(482, 40)
	_lbl_placement.bbcode_enabled = true
	_lbl_placement.fit_content = false
	_lbl_placement.scroll_active = false
	_lbl_placement.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lbl_placement.add_theme_font_size_override("normal_font_size", 13)
	_lbl_placement.add_theme_color_override("default_color", LABEL_COLOR)
	_placement_banner.add_child(_lbl_placement)
	_lbl_placement.text = "Elige una unidad y colócala en un hexágono vacío junto a tu Maestro."

func _build_cell_context_panel() -> void:
	_cell_context_panel = Panel.new()
	_cell_context_panel.position = Vector2(984, 192)
	_cell_context_panel.size = Vector2(278, 52)
	_cell_context_panel.visible = false
	_apply_panel_style(_cell_context_panel, Color(0.16, 0.17, 0.20, 0.88))
	_root.add_child(_cell_context_panel)

	_lbl_cell_context_title = _make_label("", Vector2(10, 6), HUD_FONT_SIZE_SMALL, Vector2(258, 16), LABEL_COLOR, _cell_context_panel)
	_lbl_cell_context_body = _make_label("", Vector2(10, 24), 12, Vector2(258, 18), LABEL_DIM, _cell_context_panel)

func _build_tutorial_panel() -> void:
	_tutorial_panel = Panel.new()
	_tutorial_panel.position = Vector2(360, 76)
	_tutorial_panel.size = Vector2(560, 146)
	_tutorial_panel.visible = false
	_tutorial_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_panel_style(_tutorial_panel, Color(0.08, 0.08, 0.10, 0.94))
	_root.add_child(_tutorial_panel)

	_lbl_tutorial_step = _make_label("", Vector2(16, 10), 11, Vector2(120, 14), LABEL_DIM, _tutorial_panel)

	_lbl_tutorial_title = RichTextLabel.new()
	_lbl_tutorial_title.position = Vector2(16, 30)
	_lbl_tutorial_title.size = Vector2(528, 22)
	_lbl_tutorial_title.bbcode_enabled = true
	_lbl_tutorial_title.fit_content = false
	_lbl_tutorial_title.scroll_active = false
	_lbl_tutorial_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lbl_tutorial_title.add_theme_font_size_override("normal_font_size", HUD_FONT_SIZE_LARGE)
	_lbl_tutorial_title.add_theme_color_override("default_color", LABEL_COLOR)
	_tutorial_panel.add_child(_lbl_tutorial_title)

	_lbl_tutorial_body = RichTextLabel.new()
	_lbl_tutorial_body.position = Vector2(16, 58)
	_lbl_tutorial_body.size = Vector2(528, 60)
	_lbl_tutorial_body.bbcode_enabled = true
	_lbl_tutorial_body.fit_content = false
	_lbl_tutorial_body.scroll_active = false
	_lbl_tutorial_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lbl_tutorial_body.add_theme_font_size_override("normal_font_size", HUD_FONT_SIZE_SMALL)
	_lbl_tutorial_body.add_theme_color_override("default_color", LABEL_DIM)
	_tutorial_panel.add_child(_lbl_tutorial_body)

	_btn_tutorial_next = _make_button("Siguiente", Vector2(414, 108), Vector2(130, 28), HUD_FONT_SIZE_SMALL)
	_root.remove_child(_btn_tutorial_next)
	_tutorial_panel.add_child(_btn_tutorial_next)
	_btn_tutorial_next.visible = false
	_btn_tutorial_next.pressed.connect(func() -> void:
		emit_signal("tutorial_next_pressed")
	)
	_btn_tutorial_next.pressed.connect(AudioManager.play_button)

	_tutorial_panel_outline = TutorialOutlineScript.new()
	_tutorial_panel_outline.position = Vector2.ZERO
	_tutorial_panel_outline.size = _tutorial_panel.size
	_tutorial_panel_outline.visible = false
	_tutorial_panel.add_child(_tutorial_panel_outline)
	_tutorial_panel.move_child(_tutorial_panel_outline, 0)

	_tutorial_summon_outline = TutorialOutlineScript.new()
	_tutorial_summon_outline.position = _btn_summon.position - Vector2(8, 8) if _btn_summon != null else Vector2.ZERO
	_tutorial_summon_outline.size = _btn_summon.size + Vector2(16, 16) if _btn_summon != null else Vector2.ZERO
	_tutorial_summon_outline.visible = false
	_root.add_child(_tutorial_summon_outline)
	_tutorial_summon_arrow = _make_tutorial_arrow()
	_tutorial_overlay_root.add_child(_tutorial_summon_arrow)

	_tutorial_end_turn_outline = TutorialOutlineScript.new()
	_tutorial_end_turn_outline.position = _btn_end_turn.position - Vector2(8, 8) if _btn_end_turn != null else Vector2.ZERO
	_tutorial_end_turn_outline.size = _btn_end_turn.size + Vector2(16, 16) if _btn_end_turn != null else Vector2.ZERO
	_tutorial_end_turn_outline.visible = false
	_root.add_child(_tutorial_end_turn_outline)
	_tutorial_end_turn_arrow = _make_tutorial_arrow()
	_tutorial_overlay_root.add_child(_tutorial_end_turn_arrow)

	_tutorial_resources_arrow = _make_tutorial_arrow("", true)
	_tutorial_overlay_root.add_child(_tutorial_resources_arrow)
	_tutorial_turn_arrow = _make_tutorial_arrow("", true)
	_tutorial_overlay_root.add_child(_tutorial_turn_arrow)
	_tutorial_advantage_arrow = _make_tutorial_arrow("", true)
	_tutorial_overlay_root.add_child(_tutorial_advantage_arrow)
	_tutorial_minimap_arrow = _make_tutorial_arrow("", true)
	_tutorial_overlay_root.add_child(_tutorial_minimap_arrow)
	_tutorial_unit_panel_arrow = _make_tutorial_arrow()
	_tutorial_overlay_root.add_child(_tutorial_unit_panel_arrow)
	_tutorial_cards_arrow = _make_tutorial_arrow()
	_tutorial_overlay_root.add_child(_tutorial_cards_arrow)
	_tutorial_master_arrow = _make_tutorial_arrow()
	_tutorial_overlay_root.add_child(_tutorial_master_arrow)
	_tutorial_tower_arrow = _make_tutorial_arrow()
	_tutorial_overlay_root.add_child(_tutorial_tower_arrow)
	_tutorial_resources_outline = _make_tutorial_region_outline(Rect2(8, 8, 198, 44))
	_tutorial_turn_outline = _make_tutorial_region_outline(Rect2(214, 8, 120, 44))
	_tutorial_advantage_outline = _make_tutorial_region_outline(Rect2(332, 8, 580, 44))
	_tutorial_minimap_outline = _make_tutorial_region_outline(Rect2(1086, 8, 90, 32))
	_tutorial_unit_panel_outline = _make_tutorial_region_outline(Rect2(18, 622, 346, 74))

func _build_tutorial_info_panel() -> void:
	_tutorial_info_panel = Panel.new()
	_tutorial_info_panel.position = Vector2(300, 210)
	_tutorial_info_panel.size = Vector2(680, 294)
	_tutorial_info_panel.visible = false
	_tutorial_info_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_panel_style(_tutorial_info_panel, Color(0.06, 0.06, 0.09, 0.96))
	_root.add_child(_tutorial_info_panel)

	_lbl_tutorial_info_title = _make_label("Sistema de ventajas", Vector2(24, 20), 24, Vector2(632, 28), LABEL_COLOR, _tutorial_info_panel)

	_build_tutorial_advantage_diagram(_tutorial_info_panel)

	_tutorial_info_subject_rich = RichTextLabel.new()
	_tutorial_info_subject_rich.position = Vector2(212, 74)
	_tutorial_info_subject_rich.size = Vector2(432, 28)
	_tutorial_info_subject_rich.bbcode_enabled = true
	_tutorial_info_subject_rich.fit_content = false
	_tutorial_info_subject_rich.scroll_active = false
	_tutorial_info_subject_rich.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tutorial_info_subject_rich.add_theme_font_size_override("normal_font_size", 18)
	_tutorial_info_subject_rich.add_theme_color_override("default_color", LABEL_COLOR)
	_tutorial_info_panel.add_child(_tutorial_info_subject_rich)

	_tutorial_info_target_rich = RichTextLabel.new()
	_tutorial_info_target_rich.position = Vector2(212, 120)
	_tutorial_info_target_rich.size = Vector2(432, 28)
	_tutorial_info_target_rich.bbcode_enabled = true
	_tutorial_info_target_rich.fit_content = false
	_tutorial_info_target_rich.scroll_active = false
	_tutorial_info_target_rich.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tutorial_info_target_rich.add_theme_font_size_override("normal_font_size", 18)
	_tutorial_info_target_rich.add_theme_color_override("default_color", LABEL_COLOR)
	_tutorial_info_panel.add_child(_tutorial_info_target_rich)

	_lbl_tutorial_info_body = _make_label("", Vector2(212, 166), 18, Vector2(432, 66), LABEL_COLOR, _tutorial_info_panel)
	_lbl_tutorial_info_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_btn_tutorial_info_continue = _make_button("Entendido", Vector2(492, 240), Vector2(152, 36), HUD_FONT_SIZE_SMALL)
	_root.remove_child(_btn_tutorial_info_continue)
	_tutorial_info_panel.add_child(_btn_tutorial_info_continue)
	_btn_tutorial_info_continue.pressed.connect(func() -> void:
		emit_signal("tutorial_next_pressed")
	)
	_btn_tutorial_info_continue.pressed.connect(AudioManager.play_button)

func _build_tutorial_completion_panel() -> void:
	_tutorial_completion_panel = Panel.new()
	_tutorial_completion_panel.position = Vector2(356, 224)
	_tutorial_completion_panel.size = Vector2(568, 184)
	_tutorial_completion_panel.visible = false
	_tutorial_completion_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_panel_style(_tutorial_completion_panel, Color(0.06, 0.07, 0.09, 0.97))
	_root.add_child(_tutorial_completion_panel)

	_lbl_tutorial_completion_title = _make_label("Tutorial completado", Vector2(24, 22), 26, Vector2(520, 30), LABEL_COLOR, _tutorial_completion_panel)
	_lbl_tutorial_completion_body = _make_label("", Vector2(24, 66), 18, Vector2(520, 62), LABEL_DIM, _tutorial_completion_panel)
	_lbl_tutorial_completion_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_btn_tutorial_completion_continue = _make_button("Continuar", Vector2(396, 132), Vector2(148, 34), HUD_FONT_SIZE_SMALL)
	_root.remove_child(_btn_tutorial_completion_continue)
	_tutorial_completion_panel.add_child(_btn_tutorial_completion_continue)
	_btn_tutorial_completion_continue.pressed.connect(func() -> void:
		if _tutorial_completion_panel != null:
			_tutorial_completion_panel.visible = false
		get_tree().change_scene_to_file("res://scenes/TutorialMenu.tscn")
	)
	_btn_tutorial_completion_continue.pressed.connect(AudioManager.play_button)

func _build_tutorial_advantage_diagram(parent: Control) -> void:
	var diagram := Control.new()
	diagram.position = Vector2(30, 62)
	diagram.size = Vector2(160, 160)
	diagram.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(diagram)

	var warrior := _make_tutorial_advantage_icon(CLASS_ICON_PATHS[0], Vector2(8, 0), UNIT_TYPE_DISPLAY_NAMES[0])
	var lancer := _make_tutorial_advantage_icon(CLASS_ICON_PATHS[2], Vector2(100, 0), UNIT_TYPE_DISPLAY_NAMES[2])
	var rider := _make_tutorial_advantage_icon(CLASS_ICON_PATHS[3], Vector2(100, 92), UNIT_TYPE_DISPLAY_NAMES[3])
	var archer := _make_tutorial_advantage_icon(CLASS_ICON_PATHS[1], Vector2(8, 92), UNIT_TYPE_DISPLAY_NAMES[1])
	diagram.add_child(warrior)
	diagram.add_child(lancer)
	diagram.add_child(rider)
	diagram.add_child(archer)
	_tutorial_info_advantage_icons = [warrior, lancer, rider, archer]

	var top_arrow := _make_tutorial_advantage_arrow("->", Vector2(54, 12), Vector2(48, 24), diagram)
	var right_arrow := _make_tutorial_advantage_arrow("v", Vector2(112, 56), Vector2(28, 28), diagram)
	var bottom_arrow := _make_tutorial_advantage_arrow("<-", Vector2(54, 104), Vector2(48, 24), diagram)
	var left_arrow := _make_tutorial_advantage_arrow("^", Vector2(20, 56), Vector2(28, 28), diagram)
	_tutorial_info_advantage_arrows = [top_arrow, right_arrow, bottom_arrow, left_arrow]

func _make_tutorial_advantage_icon(path: String, pos: Vector2, tooltip: String) -> TextureRect:
	var icon := TextureRect.new()
	icon.position = pos
	icon.size = Vector2(52, 52)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = load(path)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.modulate = Color(1.0, 1.0, 1.0, 0.92)
	_set_control_tooltip(icon, tooltip)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon

func _make_tutorial_advantage_arrow(text: String, pos: Vector2, size: Vector2, parent: Control) -> Label:
	var arrow := _make_label(text, pos, 28, size, SUMMON_READY_COLOR, parent)
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return arrow

func _update_tutorial_info_diagram() -> void:
	if _tutorial_info_panel == null or not _tutorial_info_panel.visible:
		return
	for i: int in range(_tutorial_info_advantage_icons.size()):
		var icon: TextureRect = _tutorial_info_advantage_icons[i]
		if icon == null:
			continue
		var pulse: float = 0.92 + 0.08 * sin(_ui_fx_time * 2.2 + float(i) * 1.1)
		icon.scale = Vector2.ONE * pulse
		icon.modulate = Color(1.0, 1.0, 1.0, 0.82 + 0.18 * pulse)
	for i: int in range(_tutorial_info_advantage_arrows.size()):
		var arrow: Label = _tutorial_info_advantage_arrows[i]
		if arrow == null:
			continue
		var glow: float = 0.55 + 0.45 * (0.5 + 0.5 * sin(_ui_fx_time * 3.0 + float(i) * 0.9))
		arrow.modulate = Color(SUMMON_READY_COLOR.r, SUMMON_READY_COLOR.g, SUMMON_READY_COLOR.b, glow)

func _build_combat_panel() -> void:
	_combat_panel = Panel.new()
	_combat_panel.position = Vector2(700, 38)
	_combat_panel.size = Vector2(220, 238)
	_combat_panel.visible = false
	_apply_panel_style(_combat_panel, Color(0.05, 0.05, 0.08, 0.94))
	_root.add_child(_combat_panel)

	_lbl_cb_title = _make_label("", Vector2(10, 10), HUD_FONT_SIZE_SMALL, Vector2(200, 0), LABEL_COLOR, _combat_panel)
	_lbl_cb_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_lbl_cb_attacker = _make_label("", Vector2(10, 40), HUD_FONT_SIZE_SMALL, Vector2(200, 0), LABEL_COLOR, _combat_panel)
	_lbl_cb_attacker.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_lbl_cb_defender = _make_label("", Vector2(10, 62), HUD_FONT_SIZE_SMALL, Vector2(200, 0), LABEL_COLOR, _combat_panel)
	_lbl_cb_defender.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_cb_attacker_chips = HBoxContainer.new()
	_cb_attacker_chips.position = Vector2(10, 58)
	_cb_attacker_chips.size = Vector2(200, 14)
	_cb_attacker_chips.add_theme_constant_override("separation", 4)
	_combat_panel.add_child(_cb_attacker_chips)

	_cb_defender_chips = HBoxContainer.new()
	_cb_defender_chips.position = Vector2(10, 80)
	_cb_defender_chips.size = Vector2(200, 14)
	_cb_defender_chips.add_theme_constant_override("separation", 4)
	_combat_panel.add_child(_cb_defender_chips)

	_lbl_cb_log = _make_label("", Vector2(10, 102), HUD_FONT_SIZE_SMALL, Vector2(200, 94), LABEL_DIM, _combat_panel)
	_lbl_cb_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_cb_log.vertical_alignment = VERTICAL_ALIGNMENT_TOP

	_lbl_cb_result = _make_label("", Vector2(10, 206), HUD_FONT_SIZE_SMALL, Vector2(200, 0), LABEL_COLOR, _combat_panel)
	_lbl_cb_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _build_pause_menu() -> void:
	# Host the pause menu on its own CanvasLayer (20) so it renders above
	# CardHand (10) and the rest of the HUD (10) without z-fighting.
	_pause_canvas = CanvasLayer.new()
	_pause_canvas.layer = 20
	add_child(_pause_canvas)

	_pause_overlay = ColorRect.new()
	_pause_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.color = Color(0.0, 0.0, 0.0, 0.58)
	_pause_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_overlay.visible = false
	_pause_canvas.add_child(_pause_overlay)

	_pause_panel = Panel.new()
	_pause_panel.position = Vector2(430, 138)
	_pause_panel.size = Vector2(420, 484)
	_pause_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_panel_style(_pause_panel, Color(0.06, 0.08, 0.12, 0.94))
	_pause_overlay.add_child(_pause_panel)

	var title := _make_label("OPCIONES", Vector2(0, 18), 24, Vector2(420, 24), SUMMON_READY_COLOR, _pause_panel)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var subtitle := _make_label("Ajustes de la partida actual", Vector2(0, 48), 11, Vector2(420, 16), LABEL_DIM, _pause_panel)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var actions_sep := _make_label("Partida", Vector2(30, 82), 11, Vector2(160, 14), LABEL_DIM, _pause_panel)
	var settings_sep := _make_label("Ajustes", Vector2(30, 208), 11, Vector2(160, 14), LABEL_DIM, _pause_panel)
	var audio_sep := _make_label("Audio", Vector2(30, 324), 11, Vector2(160, 14), LABEL_DIM, _pause_panel)

	_btn_pause_resume = _make_button("Reanudar", Vector2(30, 106), Vector2(170, 40), HUD_FONT_SIZE)
	_root.remove_child(_btn_pause_resume)
	_pause_panel.add_child(_btn_pause_resume)
	_btn_pause_resume.pressed.connect(func() -> void:
		emit_signal("pause_resume_pressed")
	)
	_btn_pause_resume.pressed.connect(AudioManager.play_button)

	_btn_pause_save = _make_button("Guardar", Vector2(220, 106), Vector2(170, 40), HUD_FONT_SIZE)
	_root.remove_child(_btn_pause_save)
	_pause_panel.add_child(_btn_pause_save)
	_btn_pause_save.pressed.connect(func() -> void:
		emit_signal("pause_save_pressed")
	)
	_btn_pause_save.pressed.connect(AudioManager.play_button)

	_btn_pause_restart = _make_button("Reiniciar", Vector2(30, 154), Vector2(170, 36), HUD_FONT_SIZE)
	_root.remove_child(_btn_pause_restart)
	_pause_panel.add_child(_btn_pause_restart)
	_btn_pause_restart.pressed.connect(func() -> void:
		_open_pause_confirmation("restart", "Deseas reiniciar la partida?")
	)
	_btn_pause_restart.pressed.connect(AudioManager.play_button)

	_btn_pause_save_exit = _make_button("Guardar y salir", Vector2(220, 154), Vector2(170, 36), HUD_FONT_SIZE_SMALL)
	_root.remove_child(_btn_pause_save_exit)
	_pause_panel.add_child(_btn_pause_save_exit)
	_btn_pause_save_exit.pressed.connect(func() -> void:
		_open_pause_confirmation("save_exit", "Deseas guardar la partida y salir al menu principal?")
	)
	_btn_pause_save_exit.pressed.connect(AudioManager.play_button)

	_btn_pause_cell_context = _make_button("", Vector2(120, 228), Vector2(170, 38), HUD_FONT_SIZE_SMALL)
	_root.remove_child(_btn_pause_cell_context)
	_pause_panel.add_child(_btn_pause_cell_context)
	_btn_pause_cell_context.pressed.connect(_on_pause_cell_context_pressed)
	_btn_pause_cell_context.pressed.connect(AudioManager.play_button)

	_btn_pause_help = _make_button("Ayuda", Vector2(120, 274), Vector2(170, 38), HUD_FONT_SIZE_SMALL)
	_root.remove_child(_btn_pause_help)
	_pause_panel.add_child(_btn_pause_help)
	_btn_pause_help.pressed.connect(_open_pause_help)
	_btn_pause_help.pressed.connect(AudioManager.play_button)

	_build_pause_volume_row("Música", 348.0, SettingsManager.music_volume,
		func(v: float) -> void: SettingsManager.set_music_volume(v))
	_build_pause_volume_row("Efectos", 378.0, SettingsManager.sfx_volume,
		func(v: float) -> void: SettingsManager.set_sfx_volume(v))

	_btn_pause_back_menu = _make_button("Volver al menu", Vector2(120, 430), Vector2(180, 36), HUD_FONT_SIZE_SMALL)
	_root.remove_child(_btn_pause_back_menu)
	_pause_panel.add_child(_btn_pause_back_menu)
	_btn_pause_back_menu.pressed.connect(func() -> void:
		_open_pause_confirmation("menu", "Deseas volver al menu principal?")
	)
	_btn_pause_back_menu.pressed.connect(AudioManager.play_button)

	_pause_help_panel = Panel.new()
	_pause_help_panel.position = Vector2(230, 38)
	_pause_help_panel.size = Vector2(820, 660)
	_pause_help_panel.visible = false
	_pause_help_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_panel_style(_pause_help_panel, Color(0.05, 0.07, 0.10, 0.98))
	_pause_overlay.add_child(_pause_help_panel)

	var help_title := _make_label("AYUDA Y GLOSARIO", Vector2(0, 18), 22, Vector2(820, 24), SUMMON_READY_COLOR, _pause_help_panel)
	help_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var help_subtitle := _make_label("Consulta reglas, sistemas y terminos clave sin salir de la partida.", Vector2(22, 48), 12, Vector2(776, 18), LABEL_DIM, _pause_help_panel)
	help_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var help_scroll := ScrollContainer.new()
	help_scroll.position = Vector2(24, 84)
	help_scroll.size = Vector2(772, 520)
	help_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_pause_help_panel.add_child(help_scroll)

	var help_rich := RichTextLabel.new()
	help_rich.bbcode_enabled = true
	help_rich.fit_content = true
	help_rich.scroll_active = false
	help_rich.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_rich.custom_minimum_size = Vector2(752, 0)
	help_rich.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	help_rich.text = _get_help_glossary_bbcode()
	help_rich.add_theme_font_size_override("normal_font_size", 16)
	help_scroll.add_child(help_rich)

	var help_close := _make_button("Cerrar", Vector2(320, 618), Vector2(180, 34), HUD_FONT_SIZE_SMALL)
	_root.remove_child(help_close)
	_pause_help_panel.add_child(help_close)
	help_close.pressed.connect(_close_pause_help)
	help_close.pressed.connect(AudioManager.play_button)

	_pause_confirm_panel = Panel.new()
	_pause_confirm_panel.position = Vector2(40, 120)
	_pause_confirm_panel.size = Vector2(340, 132)
	_pause_confirm_panel.visible = false
	_pause_confirm_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_panel_style(_pause_confirm_panel, Color(0.04, 0.05, 0.08, 0.97))
	_pause_panel.add_child(_pause_confirm_panel)

	_pause_confirm_label = _make_label("", Vector2(18, 18), 14, Vector2(304, 38), LABEL_COLOR, _pause_confirm_panel)
	_pause_confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pause_confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_btn_pause_confirm_yes = _make_button("Si", Vector2(54, 82), Vector2(104, 34), HUD_FONT_SIZE_SMALL)
	_root.remove_child(_btn_pause_confirm_yes)
	_pause_confirm_panel.add_child(_btn_pause_confirm_yes)
	_btn_pause_confirm_yes.pressed.connect(_confirm_pause_action)
	_btn_pause_confirm_yes.pressed.connect(AudioManager.play_button)

	_btn_pause_confirm_no = _make_button("No", Vector2(184, 82), Vector2(104, 34), HUD_FONT_SIZE_SMALL)
	_root.remove_child(_btn_pause_confirm_no)
	_pause_confirm_panel.add_child(_btn_pause_confirm_no)
	_btn_pause_confirm_no.pressed.connect(_close_pause_confirmation)
	_btn_pause_confirm_no.pressed.connect(AudioManager.play_button)

	_refresh_pause_cell_context_button()

func _make_label(
		text: String,
		pos: Vector2,
		font_size: int = 11,
		min_size: Vector2 = Vector2.ZERO,
		color: Color = LABEL_COLOR,
		parent: Control = null
) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	if min_size != Vector2.ZERO:
		label.custom_minimum_size = min_size
		label.size = min_size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if parent == null:
		parent = _root
	parent.add_child(label)
	return label

func _make_button(text: String, pos: Vector2, size: Vector2, font_size: int = HUD_FONT_SIZE_SMALL) -> Button:
	var button := Button.new()
	button.text = text
	button.position = pos
	button.size = size
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", LABEL_COLOR)
	button.add_theme_color_override("font_hover_color", LABEL_COLOR)
	button.add_theme_color_override("font_pressed_color", LABEL_COLOR)
	button.add_theme_color_override("font_focus_color", LABEL_COLOR)
	button.focus_mode = Control.FOCUS_NONE
	for style_name: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		match style_name:
			"hover":
				style.bg_color = Color(0.42, 0.44, 0.48, 0.62)
				style.border_color = HUD_BORDER_BRIGHT
			"pressed":
				style.bg_color = Color(0.24, 0.26, 0.30, 0.82)
				style.border_color = HUD_BORDER_BRIGHT
			"disabled":
				style.bg_color = Color(0.18, 0.18, 0.20, 0.36)
				style.border_color = Color(1.0, 1.0, 1.0, 0.08)
			_:
				style.bg_color = Color(0.28, 0.30, 0.34, 0.56)
				style.border_color = HUD_BORDER
		style.set_border_width_all(2)
		style.shadow_color = Color(0.0, 0.0, 0.0, 0.22)
		style.shadow_size = 1
		style.corner_radius_top_left = 1
		style.corner_radius_top_right = 1
		style.corner_radius_bottom_left = 1
		style.corner_radius_bottom_right = 1
		style.content_margin_left = 6
		style.content_margin_right = 6
		style.content_margin_top = 3
		style.content_margin_bottom = 3
		button.add_theme_stylebox_override(style_name, style)
	_root.add_child(button)
	return button

func set_pause_menu_open(open: bool) -> void:
	if _pause_overlay == null:
		return
	_pause_overlay.visible = open
	_pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP if open else Control.MOUSE_FILTER_IGNORE
	if not open:
		_close_pause_help()
		_close_pause_confirmation()
	if _btn_pause_menu != null:
		_btn_pause_menu.text = "Cerrar" if open else "Menu"

func is_pause_menu_open() -> bool:
	return _pause_overlay != null and _pause_overlay.visible

func set_sound_enabled(enabled: bool) -> void:
	_audio_enabled = enabled
	_apply_tooltip_preferences()

func set_game_speed_buttons(scale: float) -> void:
	_apply_speed_button_state(_btn_speed_x1, is_equal_approx(scale, 1.0))
	_apply_speed_button_state(_btn_speed_x2, is_equal_approx(scale, 2.0))
	_apply_speed_button_state(_btn_speed_x3, is_equal_approx(scale, 3.0))

func _toggle_pause_menu() -> void:
	var open: bool = not is_pause_menu_open()
	set_pause_menu_open(open)
	emit_signal("pause_menu_toggled", open)

func _open_pause_help() -> void:
	if _pause_help_panel != null:
		_pause_help_panel.visible = true
	if _pause_confirm_panel != null:
		_pause_confirm_panel.visible = false

func _close_pause_help() -> void:
	if _pause_help_panel != null:
		_pause_help_panel.visible = false

func _on_pause_cell_context_pressed() -> void:
	SettingsManager.set_cell_context_enabled(not SettingsManager.cell_context_enabled)
	_refresh_pause_cell_context_button()
	if not SettingsManager.cell_context_enabled:
		hide_cell_context()

func _apply_speed_button_state(button: Button, active: bool) -> void:
	if button == null:
		return
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.24, 0.42, 0.58, 0.78) if active else Color(0.28, 0.30, 0.34, 0.56)
	normal.border_color = SUMMON_READY_COLOR if active else HUD_BORDER
	normal.set_border_width_all(2)
	normal.shadow_color = Color(0.0, 0.0, 0.0, 0.22)
	normal.shadow_size = 1
	normal.corner_radius_top_left = 1
	normal.corner_radius_top_right = 1
	normal.corner_radius_bottom_left = 1
	normal.corner_radius_bottom_right = 1
	normal.content_margin_left = 6
	normal.content_margin_right = 6
	normal.content_margin_top = 3
	normal.content_margin_bottom = 3
	var hover := normal.duplicate()
	hover.bg_color = normal.bg_color.lightened(0.12)
	hover.border_color = HUD_BORDER_BRIGHT if not active else SUMMON_READY_COLOR.lightened(0.18)
	var pressed := hover.duplicate()
	pressed.bg_color = hover.bg_color.darkened(0.12)
	var disabled := normal.duplicate()
	disabled.bg_color = Color(0.18, 0.18, 0.20, 0.36)
	disabled.border_color = Color(1.0, 1.0, 1.0, 0.08)
	for style_name: String in ["normal", "focus"]:
		button.add_theme_stylebox_override(style_name, normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_color", SUMMON_READY_COLOR if active else LABEL_COLOR)
	button.add_theme_color_override("font_hover_color", SUMMON_READY_COLOR if active else LABEL_COLOR)
	button.add_theme_color_override("font_pressed_color", SUMMON_READY_COLOR if active else LABEL_COLOR)
	button.add_theme_color_override("font_focus_color", SUMMON_READY_COLOR if active else LABEL_COLOR)

func _refresh_pause_cell_context_button() -> void:
	if _btn_pause_cell_context == null:
		return
	_btn_pause_cell_context.text = "Contexto: ON" if SettingsManager.cell_context_enabled else "Contexto: OFF"

func _set_control_tooltip(control: Control, text: String) -> void:
	if control == null:
		return
	control.set_meta("stored_tooltip_text", text)
	control.tooltip_text = text

func _apply_tooltip_preferences() -> void:
	for control in [_btn_pause_menu, _btn_speed_x1, _btn_speed_x2, _btn_speed_x3, _btn_minimap_toggle, _btn_summon, _btn_end_turn]:
		if control != null and control.has_meta("stored_tooltip_text"):
			control.tooltip_text = str(control.get_meta("stored_tooltip_text"))
	for icon: TextureRect in _tutorial_info_advantage_icons:
		if icon != null and icon.has_meta("stored_tooltip_text"):
			icon.tooltip_text = str(icon.get_meta("stored_tooltip_text"))

func _build_pause_volume_row(label_text: String, y: float, initial: float, on_change: Callable) -> void:
	var lbl := _make_label(label_text, Vector2(30, y + 1.0), HUD_FONT_SIZE_SMALL,
		Vector2(70, 18), LABEL_COLOR, _pause_panel)

	var slider := HSlider.new()
	slider.position = Vector2(108.0, y + 4.0)
	slider.size = Vector2(220.0, 14.0)
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = initial
	slider.focus_mode = Control.FOCUS_NONE
	_pause_panel.add_child(slider)

	var pct := _make_label("%d%%" % roundi(initial * 100.0), Vector2(338, y + 1.0),
		HUD_FONT_SIZE_SMALL, Vector2(50, 18), SUMMON_READY_COLOR, _pause_panel)
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	slider.value_changed.connect(func(v: float) -> void:
		pct.text = "%d%%" % roundi(v * 100.0)
		on_change.call(v)
	)

func _open_pause_confirmation(action: String, message: String) -> void:
	_pause_confirm_action = action
	if _pause_confirm_label != null:
		_pause_confirm_label.text = message
	if _pause_confirm_panel != null:
		_pause_confirm_panel.visible = true

func _close_pause_confirmation() -> void:
	_pause_confirm_action = ""
	if _pause_confirm_panel != null:
		_pause_confirm_panel.visible = false

func _confirm_pause_action() -> void:
	var action: String = _pause_confirm_action
	_close_pause_confirmation()
	match action:
		"save_exit":
			emit_signal("pause_save_and_exit_pressed")
		"restart":
			emit_signal("pause_restart_pressed")
		"menu":
			emit_signal("pause_back_to_menu_pressed")

func _is_pause_confirm_open() -> bool:
	return _pause_confirm_panel != null and _pause_confirm_panel.visible

func _make_button_glow(pos: Vector2, size: Vector2) -> ColorRect:
	var glow := ColorRect.new()
	glow.position = pos
	glow.size = size
	glow.color = Color(1.0, 1.0, 1.0, 0.0)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(glow)
	return glow

func _make_button_flame(button: Button, color: Color) -> Dictionary:
	var base := ColorRect.new()
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base.color = Color(color.r, color.g, color.b, 0.0)
	_root.add_child(base)
	_root.move_child(base, button.get_index())

	var band := ColorRect.new()
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.color = Color(color.r, color.g, color.b, 0.0)
	_root.add_child(band)
	_root.move_child(band, button.get_index())

	var hot := ColorRect.new()
	hot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hot.color = Color(color.r, color.g, color.b, 0.0)
	_root.add_child(hot)
	_root.move_child(hot, button.get_index())

	return {
		"base": base,
		"band": band,
		"hot": hot,
		"phase": randf_range(0.0, TAU),
	}

func _make_button_motes(button: Button, color: Color) -> Array[Dictionary]:
	var motes: Array[Dictionary] = []
	if button == null:
		return motes
	for i: int in range(BUTTON_MOTE_COUNT):
		var mote := ColorRect.new()
		mote.size = Vector2(2, 2)
		mote.color = Color(color.r, color.g, color.b, BUTTON_MOTE_IDLE_ALPHA)
		mote.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(mote)
		motes.append({
			"node": mote,
			"base_x": randf_range(6.0, button.size.x - 8.0),
			"base_y": randf_range(button.size.y * 0.58, button.size.y - 4.0),
			"drift_x": randf_range(-6.0, 6.0),
			"rise": randf_range(14.0, 34.0),
			"speed": randf_range(1.2, 2.1),
			"phase": randf_range(0.0, TAU),
			"scale_boost": randf_range(0.0, 1.0),
		})
	return motes

func _apply_panel_style(panel: Panel, color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = HUD_BORDER
	style.set_border_width_all(2)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.18)
	style.shadow_size = 1
	style.corner_radius_top_left = 1
	style.corner_radius_top_right = 1
	style.corner_radius_bottom_left = 1
	style.corner_radius_bottom_right = 1
	panel.add_theme_stylebox_override("panel", style)

func _apply_segment_style(panel: Panel, color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = color.darkened(0.35)
	style.set_border_width_all(1)
	style.corner_detail = 1
	panel.add_theme_stylebox_override("panel", style)

func _rebuild_dice_row(container: Control, dice: Array) -> void:
	for child: Node in container.get_children():
		child.queue_free()
	var active: Dictionary = {}
	for die: int in dice:
		active[int(die)] = true
	var x := 0.0
	for die_color: int in range(DICE_COLORS.size()):
		var dot := Panel.new()
		dot.position = Vector2(x, 0)
		dot.size = Vector2(12, 12)
		var style := StyleBoxFlat.new()
		var base_color: Color = DICE_COLORS[die_color]
		if active.has(die_color):
			style.bg_color = base_color
			style.border_color = base_color.lightened(0.18)
		else:
			style.bg_color = Color(0.34, 0.36, 0.40, 0.40)
			style.border_color = Color(0.22, 0.24, 0.28, 0.58)
		style.set_border_width_all(1)
		style.set_corner_radius_all(6)
		dot.add_theme_stylebox_override("panel", style)
		container.add_child(dot)
		x += 18.0

func _rebuild_simple_dice_row(container: Control, dice: Array) -> void:
	if container == null:
		return
	for child: Node in container.get_children():
		child.queue_free()
	var active: Dictionary = {}
	for die: int in dice:
		active[int(die)] = true
	var x := 0.0
	for die_color: int in range(DICE_COLORS.size()):
		var dot := Panel.new()
		dot.position = Vector2(x, 0)
		dot.size = Vector2(10, 10)
		var style := StyleBoxFlat.new()
		var base_color: Color = DICE_COLORS[die_color]
		if active.has(die_color):
			style.bg_color = base_color
			style.border_color = base_color.lightened(0.15)
		else:
			style.bg_color = Color(0.24, 0.26, 0.30, 0.42)
			style.border_color = Color(0.16, 0.18, 0.22, 0.56)
		style.set_border_width_all(1)
		style.set_corner_radius_all(2)
		dot.add_theme_stylebox_override("panel", style)
		container.add_child(dot)
		x += 13.0

# Muestra "—" en el contenedor de dados a distancia para unidades sin ataque ranged
func _rebuild_dice_row_no_ranged(container: Control) -> void:
	for child: Node in container.get_children():
		child.queue_free()
	var lbl := Label.new()
	lbl.text = "—"
	lbl.position = Vector2(0, -1)
	lbl.size = Vector2(84, 14)
	lbl.add_theme_color_override("font_color", Color(0.45, 0.47, 0.52, 0.75))
	lbl.add_theme_font_size_override("font_size", 11)
	container.add_child(lbl)

# Devuelve true si la unidad usa jabalina (Lancero o Maestro Brujo)
func _unit_is_javelin(unit: Object) -> bool:
	if unit == null:
		return false
	var utype: int = int(unit.get("unit_type"))
	if utype == 2:   # UnitType.LANCER
		return true
	# Maestro Brujo (unit_type == -1, faction == 3)
	if utype == -1 and unit.has_method("has_ranged_attack") and bool(unit.call("has_ranged_attack")):
		var f: int = int(unit.get("faction")) if unit.get("faction") != null else -1
		return f == 3
	return false

func update_turn(player_id: int) -> void:
	var turn_num: int = 1
	if turn_manager != null:
		turn_num = turn_manager.turn_number
	_lbl_turn_num.text = str(turn_num)
	if _lbl_turn_time != null:
		var is_night: bool = _is_night_turn(turn_num)
		_lbl_turn_time.text = "NOCHE" if is_night else "DIA"
		_lbl_turn_time.add_theme_color_override("font_color", Color(0.60, 0.82, 1.0, 0.96) if is_night else Color(1.0, 0.88, 0.28, 0.96))
		if _lbl_turn_cycle_icon != null:
			_lbl_turn_cycle_icon.text = "☾" if is_night else "☀"
			_lbl_turn_cycle_icon.add_theme_color_override("font_color", Color(0.60, 0.82, 1.0, 0.96) if is_night else Color(1.0, 0.88, 0.28, 0.96))
	var team_color: Color = _player_color(player_id)
	_team_icon.color = team_color
	_turn_band_core.color = team_color
	_turn_band_glow.color = Color(team_color.r, team_color.g, team_color.b, 0.22)
	if _turn_band_core_bottom != null:
		_turn_band_core_bottom.color = team_color
	if _turn_band_glow_bottom != null:
		_turn_band_glow_bottom.color = Color(team_color.r, team_color.g, team_color.b, 0.22)
	if _turn_panel_glow != null:
		_apply_panel_style(_turn_panel_glow, Color(team_color.r, team_color.g, team_color.b, 0.18))
	_lbl_turn_num.add_theme_color_override("font_color", team_color.lightened(0.35))
	if resource_manager != null:
		_lbl_essence.text = str(resource_manager.get_essence(player_id))
	if hex_grid != null:
		_lbl_unit_count.text = str(_count_units(player_id))
	refresh_towers()
	_redraw_minimap()
	_refresh_action_button_glow()

func update_essence(player_id: int, amount: int) -> void:
	if turn_manager == null:
		return
	if player_id == turn_manager.current_player:
		_lbl_essence.text = str(amount)
	refresh_advantage()
	_refresh_action_button_glow()

func _is_night_turn(turn_num: int) -> bool:
	var cycle_index: int = int((turn_num - 1) / 4) % 2
	return cycle_index == 1

func get_essence_label_screen_position() -> Vector2:
	if _lbl_essence == null:
		return Vector2(244.0, 54.0)
	return _lbl_essence.global_position + Vector2(_lbl_essence.size.x * 0.5, _lbl_essence.size.y + 18.0)

func show_unit(unit: Unit) -> void:
	if unit == null or not is_instance_valid(unit):
		hide_unit()
		return
	_current_unit = unit
	_lbl_no_unit.visible = false
	hide_advantage()

	var unit_owner: int = int(unit.get("owner_id"))
	var unit_type: int = int(unit.get("unit_type"))
	var faction: int = GameData.get_faction_for_player(unit_owner)
	var owner_color: Color = _player_color(unit_owner)
	if _unit_accent_line != null:
		_unit_accent_line.color = owner_color
	var portrait_path: String = FactionData.get_sprite_path(faction, unit_type)
	if ResourceLoader.exists(portrait_path):
		_portrait.texture = _get_portrait_texture(portrait_path, unit_type, false)
		_portrait_bg.texture = _portrait.texture
	else:
		_portrait.texture = null
		_portrait_bg.texture = null
	_unit_class_icon.texture = load(_get_class_icon_path(unit_type))
	_unit_simple_portrait.texture = _portrait.texture
	if _unit_simple_class_icon != null:
		_unit_simple_class_icon.texture = load(_get_class_icon_path(unit_type))

	var display_name: String = str(UNIT_TYPE_DISPLAY_NAMES.get(unit_type, str(unit.get("unit_name"))))
	_lbl_unit_name.text = display_name
	var level: int = int(unit.get("level"))
	var level_color: Color = LEVEL_COLORS.get(level, LABEL_COLOR)
	_lbl_unit_name.add_theme_color_override("font_color", level_color)
	_lbl_unit_level.text = "NIVEL %d" % level
	_lbl_unit_level.add_theme_color_override("font_color", level_color)
	_unit_class_icon.modulate = level_color
	if _unit_level_bar != null:
		_unit_level_bar.color = level_color
	if _unit_simple_accent_line != null:
		_unit_simple_accent_line.color = owner_color
	if _unit_simple_top_line != null:
		_unit_simple_top_line.color = level_color
	if _unit_simple_name != null:
		_unit_simple_name.text = display_name
		_unit_simple_name.add_theme_color_override("font_color", level_color)
	if _unit_simple_class_icon != null:
		_unit_simple_class_icon.modulate = level_color
	if _unit_simple_move != null:
		_unit_simple_move.text = "MOV %d" % int(unit.get("move_range"))

	var hp: int = int(unit.get("hp"))
	var max_hp: int = int(unit.get("max_hp"))
	_lbl_hp_value.text = "%d/%d" % [hp, max_hp]
	_lbl_move_value.text = str(int(unit.get("move_range")))
	_lbl_range_value.text = str(int(unit.get("attack_range")))
	var defense_buff: int = int(unit.get("defense_buff"))
	_lbl_defense_value.text = "+%d" % defense_buff if defense_buff > 0 else "-"
	_update_segment_row(_hp_segments, hp, max_hp, HP_ON, HP_OFF)
	if _unit_simple_hp != null:
		_unit_simple_hp.text = "HP %d/%d" % [hp, max_hp]

	var experience: int = int(unit.get("experience"))
	var exp_required: int = int(unit.call("get_exp_required"))
	_lbl_xp_value.text = "%d/%d" % [experience, exp_required]
	_update_segment_row(_xp_segments, experience, exp_required, XP_ON, XP_OFF)
	if _unit_simple_xp != null:
		_unit_simple_xp.text = "XP %d/%d" % [experience, exp_required]
	if _unit_simple_defense != null:
		_unit_simple_defense.text = "DEF +%d" % defense_buff if defense_buff > 0 else ""

	var melee_dice: Array = unit.call("get_melee_dice")
	var ranged_dice: Array = unit.call("get_ranged_dice")
	var unit_has_ranged: bool = unit.has_method("has_ranged_attack") and bool(unit.call("has_ranged_attack"))
	_rebuild_dice_row(_melee_dice_container, melee_dice)
	if unit_has_ranged:
		_rebuild_dice_row(_ranged_dice_container, ranged_dice)
	else:
		_rebuild_dice_row_no_ranged(_ranged_dice_container)
	_rebuild_simple_dice_row(_unit_simple_melee_dice, ranged_dice)
	_rebuild_simple_dice_row(_unit_simple_ranged_dice, melee_dice)
	# Label "R" / "J" (jabalina) segun tipo de ataque a distancia
	var is_javelin: bool = _unit_is_javelin(unit)
	if _lbl_ranged != null:
		_lbl_ranged.text = "J" if is_javelin else "R"

	var atk_alpha: float = 0.30 if bool(unit.get("has_attacked")) else 1.0
	_lbl_melee.modulate.a             = atk_alpha
	_lbl_ranged.modulate.a            = atk_alpha
	_melee_dice_container.modulate.a  = atk_alpha
	_ranged_dice_container.modulate.a = atk_alpha
	if _unit_simple_attack != null:
		_unit_simple_attack.modulate.a = atk_alpha
	if _unit_simple_melee_label != null:
		_unit_simple_melee_label.modulate.a = atk_alpha
	if _unit_simple_ranged_label != null:
		_unit_simple_ranged_label.modulate.a = atk_alpha
	if _unit_simple_melee_dice != null:
		_unit_simple_melee_dice.modulate.a = atk_alpha
	if _unit_simple_ranged_dice != null:
		_unit_simple_ranged_dice.modulate.a = atk_alpha

	_redraw_minimap(unit)
	refresh_advantage()
	_refresh_action_button_glow()
	_set_unit_panel_mode(_unit_panel_detailed)

func hide_unit() -> void:
	_current_unit = null
	_portrait.texture = null
	_portrait_bg.texture = null
	_unit_class_icon.texture = null
	_unit_class_icon.modulate = Color(0.96, 0.98, 1.0, 0.92)
	if _unit_accent_line != null:
		_unit_accent_line.color = UNIT_PANEL_NEUTRAL
	if _unit_level_bar != null:
		_unit_level_bar.color = UNIT_PANEL_NEUTRAL
	if _unit_simple_accent_line != null:
		_unit_simple_accent_line.color = UNIT_PANEL_NEUTRAL
	if _unit_simple_top_line != null:
		_unit_simple_top_line.color = UNIT_PANEL_NEUTRAL
	_lbl_unit_name.text = ""
	_lbl_unit_name.add_theme_color_override("font_color", LABEL_COLOR)
	_lbl_unit_level.text = ""
	_lbl_unit_level.add_theme_color_override("font_color", LABEL_DIM)
	if _unit_simple_portrait != null:
		_unit_simple_portrait.texture = null
	if _unit_simple_class_icon != null:
		_unit_simple_class_icon.texture = null
		_unit_simple_class_icon.modulate = Color(0.96, 0.98, 1.0, 0.92)
	if _unit_simple_name != null:
		_unit_simple_name.text = ""
		_unit_simple_name.add_theme_color_override("font_color", LABEL_COLOR)
	if _unit_simple_hp != null:
		_unit_simple_hp.text = ""
	if _unit_simple_xp != null:
		_unit_simple_xp.text = ""
	if _unit_simple_move != null:
		_unit_simple_move.text = ""
	if _unit_simple_defense != null:
		_unit_simple_defense.text = ""
	_lbl_hp_value.text = ""
	_lbl_xp_value.text = ""
	_lbl_move_value.text = ""
	_lbl_range_value.text = ""
	_lbl_defense_value.text = ""
	_lbl_no_unit.visible = _unit_panel_detailed
	hide_advantage()
	_update_segment_row(_hp_segments, 0, 0, HP_ON, HP_OFF)
	_update_segment_row(_xp_segments, 0, 0, XP_ON, XP_OFF)
	_rebuild_dice_row(_melee_dice_container, [])
	_rebuild_dice_row(_ranged_dice_container, [])
	_rebuild_simple_dice_row(_unit_simple_melee_dice, [])
	_rebuild_simple_dice_row(_unit_simple_ranged_dice, [])
	_lbl_melee.modulate.a             = 1.0
	_lbl_ranged.modulate.a            = 1.0
	_lbl_ranged.text                  = "R"
	_melee_dice_container.modulate.a  = 1.0
	_ranged_dice_container.modulate.a = 1.0
	if _unit_simple_attack != null:
		_unit_simple_attack.modulate.a = 1.0
	if _unit_simple_melee_label != null:
		_unit_simple_melee_label.modulate.a = 1.0
	if _unit_simple_ranged_label != null:
		_unit_simple_ranged_label.modulate.a = 1.0
	if _unit_simple_melee_dice != null:
		_unit_simple_melee_dice.modulate.a = 1.0
	if _unit_simple_ranged_dice != null:
		_unit_simple_ranged_dice.modulate.a = 1.0
	_redraw_minimap()
	refresh_advantage()
	_refresh_action_button_glow()
	_set_unit_panel_mode(_unit_panel_detailed)

func _toggle_unit_panel_mode() -> void:
	_set_unit_panel_mode(not _unit_panel_detailed)

func _set_unit_panel_mode(detailed: bool) -> void:
	_unit_panel_detailed = detailed
	if _unit_panel_glass != null:
		_unit_panel_glass.visible = detailed
	for corner: ColorRect in _unit_panel_corner_nodes:
		if corner != null:
			corner.visible = detailed
	if _btn_unit_panel_mode != null:
		_btn_unit_panel_mode.text = "Simple" if detailed else "Detalle"
	for node_value: Variant in _unit_panel_base_nodes:
		var canvas_item: CanvasItem = node_value as CanvasItem
		if canvas_item != null:
			canvas_item.visible = detailed
	for node_value: Variant in _unit_detail_nodes:
		var canvas_item: CanvasItem = node_value as CanvasItem
		if canvas_item != null:
			canvas_item.visible = detailed
	if _lbl_no_unit != null:
		_lbl_no_unit.visible = detailed and _current_unit == null
	if _unit_simple_panel != null:
		_unit_simple_panel.visible = not detailed and _current_unit != null
	if _btn_unit_simple_mode != null:
		_btn_unit_simple_mode.text = ""
	if not detailed:
		hide_advantage()
		_update_simple_unit_panel_position()

func _update_simple_unit_panel_position() -> void:
	if _unit_simple_panel == null:
		return
	if _unit_panel_detailed or _current_unit == null:
		_unit_simple_panel.visible = false
		return
	_unit_simple_panel.position = Vector2(18, 622)
	_unit_simple_panel.visible = true

func _update_segment_row(segments: Array[Panel], value: int, max_value: int, on_color: Color, off_color: Color) -> void:
	var capped_max: int = mini(max_value, segments.size())
	var capped_value: int = mini(value, capped_max)
	for i: int in range(segments.size()):
		if i < capped_value:
			segments[i].visible = true
			_apply_segment_style(segments[i], on_color)
		elif i < capped_max:
			segments[i].visible = true
			_apply_segment_style(segments[i], off_color)
		else:
			segments[i].visible = false

func refresh_towers() -> void:
	if hex_grid == null:
		return

	var counts: Dictionary = {0: 0, 1: 0, 2: 0, 3: 0, 4: 0}
	for tower: Tower in hex_grid.get_all_towers():
		var owner_id: int = int(tower.get("owner_id"))
		counts[owner_id] = int(counts.get(owner_id, 0)) + 1

	_lbl_tw_p1.text = "Jugador 1: %d" % counts[1]
	_lbl_tw_p2.text = "Jugador 2: %d" % counts[2]
	_lbl_tw_neutral.text = "Neutral: %d" % counts[0]

	if turn_manager != null:
		var player_id: int = turn_manager.current_player
		var income: int = 0
		for tower: Tower in hex_grid.get_all_towers():
			if int(tower.get("owner_id")) == player_id:
				income += int(tower.get("income"))
		_lbl_tw_income.text = "Ingreso: +%d" % income
		_lbl_towers.text = str(int(counts.get(player_id, 0)))
		_lbl_unit_count.text = str(_count_units(player_id))
	refresh_advantage()
	_redraw_minimap()
	_refresh_action_button_glow()

func refresh_advantage() -> void:
	if _advantage_tracker == null or hex_grid == null or resource_manager == null:
		return

	var rows: Array[Dictionary] = _advantage_tracker.get_sorted_rows(hex_grid, resource_manager)
	_rebuild_advantage_bar(rows)

	if _advantage_status != null:
		_advantage_status.text = _advantage_tracker.get_status_text(hex_grid, resource_manager)

	for i: int in range(_advantage_rank_labels.size()):
		var label: Label = _advantage_rank_labels[i]
		if label == null:
			continue
		if i >= rows.size():
			label.text = ""
			continue

		var row: Dictionary = rows[i]
		var player_id: int = int(row.get("player_id", 0))
		var score: int = int(row.get("score", 0))
		label.text = "#%d J%d  %d" % [i + 1, player_id, score]
		label.add_theme_color_override("font_color", _player_color(player_id))

func _set_advantage_details_visible(visible: bool) -> void:
	for label: Label in _advantage_rank_labels:
		if label != null:
			label.visible = visible

func _rebuild_advantage_bar(rows: Array[Dictionary]) -> void:
	if _advantage_bar_fill_container == null or _advantage_bar_bg == null:
		return

	for child: Node in _advantage_bar_fill_container.get_children():
		child.queue_free()

	var total_score: int = 0
	for row: Dictionary in rows:
		total_score += maxi(0, int(row.get("score", 0)))
	if total_score <= 0:
		return

	var x_offset: float = 0.0
	for i: int in range(rows.size()):
		var row: Dictionary = rows[i]
		var player_id: int = int(row.get("player_id", 0))
		var score: int = maxi(0, int(row.get("score", 0)))
		var ratio: float = float(score) / float(total_score)
		var width: float = _advantage_bar_bg.size.x * ratio
		if i == rows.size() - 1:
			width = _advantage_bar_bg.size.x - x_offset

		var fill := ColorRect.new()
		fill.position = Vector2(x_offset, 0.0)
		fill.size = Vector2(width, _advantage_bar_bg.size.y)
		var base_color: Color = _player_color(player_id)
		fill.color = Color(base_color.r, base_color.g, base_color.b, 0.88)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_advantage_bar_fill_container.add_child(fill)
		x_offset += width

func _redraw_minimap(selected_unit: Unit = null) -> void:
	if _minimap_texture == null or hex_grid == null:
		return
	var terrain_map: Array = hex_grid.get("_map_terrain") as Array
	if terrain_map.is_empty():
		return
	var rows: int = terrain_map.size()
	var cols: int = (terrain_map[0] as Array).size() if rows > 0 else 0
	if cols <= 0:
		return

	for child: Node in _minimap_texture.get_children():
		child.queue_free()

	var local_points: Array[PackedVector2Array] = []
	var min_pt := Vector2(1e20, 1e20)
	var max_pt := Vector2(-1e20, -1e20)
	for r: int in range(rows):
		for c: int in range(cols):
			var points: PackedVector2Array = _minimap_hex_points(c, r, 1.0)
			local_points.append(points)
			for pt: Vector2 in points:
				min_pt.x = minf(min_pt.x, pt.x)
				min_pt.y = minf(min_pt.y, pt.y)
				max_pt.x = maxf(max_pt.x, pt.x)
				max_pt.y = maxf(max_pt.y, pt.y)

	var bounds_size: Vector2 = max_pt - min_pt
	var scale_factor: float = minf(_minimap_texture.size.x / bounds_size.x, _minimap_texture.size.y / bounds_size.y) * 0.96
	var scaled_size: Vector2 = bounds_size * scale_factor
	var offset: Vector2 = (_minimap_texture.size - scaled_size) * 0.5 - min_pt * scale_factor
	var index: int = 0

	for r: int in range(rows):
		var row_data: Array = terrain_map[r] as Array
		for c: int in range(cols):
			var terrain: int = int(row_data[c])
			var color: Color = MINIMAP_TERRAIN_COLORS[clampi(terrain, 0, MINIMAP_TERRAIN_COLORS.size() - 1)]
			var poly := Polygon2D.new()
			var points: PackedVector2Array = local_points[index]
			var transformed := PackedVector2Array()
			for pt: Vector2 in points:
				transformed.append(pt * scale_factor + offset)
			poly.polygon = transformed
			poly.color = color
			_minimap_texture.add_child(poly)
			index += 1

	var marker_radius: float = maxf(scale_factor * 0.52, 2.2)

	for tower: Tower in hex_grid.get_all_towers():
		var tower_cell: Vector2i = tower.position
		_add_minimap_marker(
			_minimap_hex_center(tower_cell.x, tower_cell.y, scale_factor) + offset,
			marker_radius,
			Color(1.0, 0.95, 0.6, 0.92)
		)

	for unit_value: Variant in hex_grid.get_all_units():
		var unit: Unit = unit_value as Unit
		if unit == null:
			continue
		var cell: Vector2i = hex_grid.get_cell_for_unit(unit)
		if cell == Vector2i(-1, -1):
			continue
		var marker_pos: Vector2 = _minimap_hex_center(cell.x, cell.y, scale_factor) + offset
		var team_color: Color = _player_color(unit.owner_id)
		var radius: float = maxf(scale_factor * 0.28, 1.8)
		if selected_unit != null and unit == selected_unit:
			radius = maxf(scale_factor * 0.38, 2.4)
			_add_minimap_marker(
				marker_pos,
				maxf(scale_factor * 0.56, 3.1),
				Color(1.0, 1.0, 1.0, 0.92)
			)
		_add_minimap_marker(marker_pos, radius, team_color)

func _minimap_hex_center(col: int, row: int, radius: float) -> Vector2:
	var width: float = radius * 2.0
	var height: float = sqrt(3.0) * radius
	return Vector2(
		radius + float(col) * radius * 1.5,
		height * 0.5 + (float(row) + (0.5 if col % 2 == 1 else 0.0)) * height
	)

func _minimap_hex_points(col: int, row: int, radius: float) -> PackedVector2Array:
	var center: Vector2 = _minimap_hex_center(col, row, radius)
	var points := PackedVector2Array()
	for i: int in range(6):
		var angle: float = deg_to_rad(60.0 * float(i) + 30.0)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points

func _add_minimap_marker(center: Vector2, radius: float, color: Color) -> void:
	var marker := Polygon2D.new()
	var points := PackedVector2Array()
	for i: int in range(6):
		var angle: float = deg_to_rad(60.0 * float(i) + 30.0)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	marker.polygon = points
	marker.color = color
	_minimap_texture.add_child(marker)

func _get_portrait_texture(path: String, unit_type: int = -999, background_variant: bool = false) -> Texture2D:
	var cache_key: String = "%s|%d|%s" % [path, unit_type, "bg" if background_variant else "main"]
	if _portrait_cache.has(cache_key):
		return _portrait_cache[cache_key]
	var base_texture: Texture2D = load(path)
	if base_texture == null:
		return null
	var image: Image = Image.load_from_file(path)
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

	if unit_type == -1:
		start_y = maxi(0, start_y - 6)
		height = mini(image.get_height() - start_y, height + 8)

	if background_variant:
		start_x = maxi(0, start_x - 8)
		start_y = maxi(0, start_y - 4)
		width = mini(image.get_width() - start_x, width + 14)
		height = mini(image.get_height() - start_y, height + 10)

	var atlas := AtlasTexture.new()
	atlas.atlas = base_texture
	atlas.region = Rect2(start_x, start_y, width, height)
	_portrait_cache[cache_key] = atlas
	return atlas

func _get_class_icon_path(unit_type: int) -> String:
	return CLASS_ICON_PATHS.get(unit_type, MASTER_ICON_PATH)

func show_advantage(multiplier: float) -> void:
	if _lbl_advantage_detail != null:
		_lbl_advantage_detail.text = ""
	if multiplier > 1.0:
		_lbl_advantage.text = "VENTAJA +1"
		_lbl_advantage.add_theme_color_override("font_color", Color(0.32, 1.0, 0.40, 1.0))
	elif multiplier < 1.0:
		_lbl_advantage.text = "DESVENTAJA"
		_lbl_advantage.add_theme_color_override("font_color", Color(1.0, 0.38, 0.38, 1.0))
	else:
		_lbl_advantage.text = ""

func show_combat_preview(attacker, defender) -> void:
	if attacker == null or defender == null:
		hide_advantage()
		return

	var attacker_type: int = -1 if attacker is Master else int(attacker.get("unit_type"))
	var defender_type: int = -1 if defender is Master else int(defender.get("unit_type"))
	var attacker_name: String = str(UNIT_TYPE_DISPLAY_NAMES.get(attacker_type, str(attacker.get("unit_name"))))
	var defender_name: String = str(UNIT_TYPE_DISPLAY_NAMES.get(defender_type, str(defender.get("unit_name"))))
	var atk_mult: float = Unit.get_damage_multiplier(attacker_type, defender_type)
	var def_mult: float = Unit.get_damage_multiplier(defender_type, attacker_type)
	var context: Dictionary = _get_combat_preview_context(attacker, defender)
	var attacker_hits: int = int(context.get("attacker_hits", 0))
	var defender_hits: int = int(context.get("defender_hits", 0))
	var attacker_dice: String = str(context.get("attacker_dice", "-"))
	var defender_dice: String = str(context.get("defender_dice", "-"))
	var attack_mode: String = str(context.get("mode", "cuerpo a cuerpo"))
	var preview_summary: String = _combat_preview_summary(atk_mult, attack_mode)

	if atk_mult > 1.0:
		_lbl_advantage.text = "%s > %s" % [attacker_name, defender_name]
		_lbl_advantage.add_theme_color_override("font_color", Color(0.32, 1.0, 0.40, 1.0))
	elif atk_mult < 1.0:
		_lbl_advantage.text = "%s < %s" % [attacker_name, defender_name]
		_lbl_advantage.add_theme_color_override("font_color", Color(1.0, 0.38, 0.38, 1.0))
	else:
		_lbl_advantage.text = "%s = %s" % [attacker_name, defender_name]
		_lbl_advantage.add_theme_color_override("font_color", Color(1.0, 0.88, 0.24, 1.0))

	if _lbl_advantage_detail != null:
		_lbl_advantage_detail.text = "%s\n%s | Golpes %d-%d\nDados %s / %s" % [preview_summary, attack_mode, attacker_hits, defender_hits, attacker_dice, defender_dice]

func hide_advantage() -> void:
	_lbl_advantage.text = ""
	if _lbl_advantage_detail != null:
		_lbl_advantage_detail.text = ""

func _get_combat_preview_context(attacker, defender) -> Dictionary:
	if hex_grid == null or not hex_grid.has_method("get_distance_between_cells") or not hex_grid.has_method("get_terrain_at"):
		return {
			"mode": "combate",
			"attacker_hits": attacker.get_base_attack_count() if attacker != null and attacker.has_method("get_base_attack_count") else 0,
			"defender_hits": defender.get_base_attack_count() if defender != null and defender.has_method("get_base_attack_count") else 0,
			"attacker_dice": _format_preview_dice(attacker.get_melee_dice() if attacker != null else []),
			"defender_dice": _format_preview_dice(defender.get_melee_dice() if defender != null else []),
		}

	var attacker_cell: Vector2i = attacker.get_hex_cell() if attacker != null and attacker.has_method("get_hex_cell") else Vector2i(-1, -1)
	var defender_cell: Vector2i = defender.get_hex_cell() if defender != null and defender.has_method("get_hex_cell") else Vector2i(-1, -1)
	var distance: int = hex_grid.get_distance_between_cells(attacker_cell, defender_cell) if attacker_cell != Vector2i(-1, -1) and defender_cell != Vector2i(-1, -1) else 1
	var is_ranged: bool = attacker != null and attacker.has_method("can_attack_at_distance") and attacker.can_attack_at_distance(distance) and distance > 1
	var defender_ranged_response: bool = is_ranged and defender != null and defender.has_method("has_ranged_attack") and defender.has_ranged_attack() and defender.has_method("can_attack_at_distance") and defender.can_attack_at_distance(distance)
	var attacker_terrain: int = int(hex_grid.call("get_terrain_at", attacker_cell.x, attacker_cell.y)) if attacker_cell != Vector2i(-1, -1) else 0
	var defender_terrain: int = int(hex_grid.call("get_terrain_at", defender_cell.x, defender_cell.y)) if defender_cell != Vector2i(-1, -1) else 0
	var attacker_hits: int = attacker.get_attack_count_for_terrain(attacker_terrain) if attacker != null and attacker.has_method("get_attack_count_for_terrain") else 0
	if is_ranged and attacker != null and attacker.has_method("get_ranged_attack_count_for_terrain"):
		attacker_hits = attacker.get_ranged_attack_count_for_terrain(attacker_terrain)
	var defender_hits: int = 0 if (is_ranged and not defender_ranged_response) else (defender.get_ranged_attack_count_for_terrain(defender_terrain) if (is_ranged and defender != null and defender.has_method("get_ranged_attack_count_for_terrain")) else (defender.get_attack_count_for_terrain(defender_terrain) if defender != null and defender.has_method("get_attack_count_for_terrain") else 0))
	var attacker_dice: Array = attacker.get_ranged_dice() if is_ranged else attacker.get_melee_dice()
	var defender_dice: Array = [] if (is_ranged and not defender_ranged_response) else (defender.get_ranged_dice() if is_ranged else defender.get_melee_dice())
	return {
		"mode": "a distancia con respuesta" if (is_ranged and defender_ranged_response) else ("a distancia" if is_ranged else "cuerpo a cuerpo"),
		"attacker_hits": attacker_hits,
		"defender_hits": defender_hits,
		"attacker_dice": _format_preview_dice(attacker_dice),
		"defender_dice": "sin resp." if (is_ranged and not defender_ranged_response) else _format_preview_dice(defender_dice),
	}

func _format_preview_dice(dice: Array) -> String:
	if dice.is_empty():
		return "-"
	var parts: Array[String] = []
	for die_value: Variant in dice:
		var die_color: int = int(die_value)
		if die_color >= 0 and die_color < DICE_NAMES.size():
			parts.append(str(DICE_NAMES[die_color]).left(1))
		else:
			parts.append("?")
	return "/".join(parts)

func _combat_preview_summary(atk_mult: float, attack_mode: String) -> String:
	if attack_mode == "a distancia":
		if atk_mult > 1.0:
			return "Ataque favorable (+1 dano) sin respuesta"
		if atk_mult < 1.0:
			return "Golpeas primero, pero con desventaja"
		return "Golpeas primero sin respuesta"
	if attack_mode == "a distancia con respuesta":
		if atk_mult > 1.0:
			return "Ataque a distancia con respuesta favorable (+1 dano)"
		if atk_mult < 1.0:
			return "Ataque a distancia con respuesta riesgoso"
		return "Intercambio a distancia parejo"
	if atk_mult > 1.0:
		return "Intercambio favorable (+1 dano)"
	if atk_mult < 1.0:
		return "Intercambio riesgoso"
	return "Intercambio parejo"

func show_placement_hint(message: String = "Modo invocación: elige un hexágono vacío junto a tu Maestro", unit_type: int = -999) -> void:
	if _lbl_placement_title != null:
		_lbl_placement_title.text = "Invocación"
	if _placement_hint_icon != null:
		var icon_path: String = PLACEMENT_ADVANTAGE_ICON_PATH
		if CLASS_ICON_PATHS.has(unit_type):
			icon_path = str(CLASS_ICON_PATHS.get(unit_type, PLACEMENT_ADVANTAGE_ICON_PATH))
		_placement_hint_icon.texture = load(icon_path)
	if _lbl_placement != null:
		_lbl_placement.clear()
		_lbl_placement.text = _build_inline_placement_rich_text(message, unit_type)
	_placement_banner.visible = true
	_refresh_action_button_glow()

func hide_placement_hint() -> void:
	if _lbl_placement_title != null:
		_lbl_placement_title.text = "Invocación"
	if _placement_hint_icon != null:
		_placement_hint_icon.texture = load(PLACEMENT_ADVANTAGE_ICON_PATH)
	if _lbl_placement != null:
		_lbl_placement.clear()
		_lbl_placement.text = _build_inline_placement_rich_text("Elige una unidad y colócala en un hexágono vacío junto a tu Maestro.", -999)
	_placement_banner.visible = false
	_refresh_action_button_glow()

func show_cell_context(cell: Vector2i) -> void:
	if _cell_context_panel == null or hex_grid == null:
		return
	if not SettingsManager.cell_context_enabled:
		hide_cell_context()
		return
	var terrain: int = int(hex_grid.call("get_terrain_at", cell.x, cell.y))
	if terrain < 0:
		hide_cell_context()
		return

	var terrain_name: String = str(TERRAIN_DISPLAY_NAMES.get(terrain, "Terreno"))
	var move_text: String = _terrain_move_text(terrain)
	var attack_mod: int = _terrain_attack_modifier(terrain)
	var attack_text: String = _terrain_attack_text(attack_mod)
	var title: String = terrain_name
	var details: Array[String] = [move_text, attack_text]

	var tower: Tower = hex_grid.call("get_tower_at", cell.x, cell.y) as Tower
	if tower != null:
		title += " · Torre +%d" % tower.income
		details.append("Captura +%d / Robo +%d" % [tower.income, maxi(1, int(floor(float(tower.income) * 0.5)))])

	_lbl_cell_context_title.text = title
	_lbl_cell_context_body.text = " | ".join(details)
	_cell_context_panel.visible = true

func hide_cell_context() -> void:
	if _cell_context_panel == null:
		return
	_cell_context_panel.visible = false

func show_tutorial_step(step_index: int, total_steps: int, title: String, body: String, show_next: bool = false) -> void:
	if _tutorial_panel == null:
		return
	hide_tutorial_info()
	_lbl_tutorial_step.text = "TUTORIAL %d/%d" % [step_index, total_steps]
	var title_rich: String = _inline_unit_icons_in_text(title, 18)
	var body_rich: String = _inline_unit_icons_in_text(body, 16)
	_lbl_tutorial_title.clear()
	_lbl_tutorial_title.append_text(title_rich if title_rich != "" else title)
	_lbl_tutorial_body.clear()
	_lbl_tutorial_body.append_text(body_rich if body_rich != "" else body)
	_tutorial_panel.visible = true
	if _btn_tutorial_next != null:
		_btn_tutorial_next.visible = show_next
	if _tutorial_panel_outline != null:
		_tutorial_panel_outline.visible = true

func hide_tutorial() -> void:
	if _tutorial_panel == null:
		return
	_tutorial_panel.visible = false
	hide_tutorial_info()
	hide_tutorial_completion()
	if _btn_tutorial_next != null:
		_btn_tutorial_next.visible = false
	if _tutorial_panel_outline != null:
		_tutorial_panel_outline.visible = false
	set_tutorial_world_markers(false, Vector3.ZERO, false, Vector3.ZERO)
	set_tutorial_focus("")
	_tutorial_custom_focus_rect = Rect2()
	_update_tutorial_spotlight("")

func show_tutorial_summon_explanation(unit_name: String, counter_hint: String) -> void:
	if _tutorial_info_panel == null:
		return
	if _tutorial_panel != null:
		_tutorial_panel.visible = false
	if _btn_tutorial_next != null:
		_btn_tutorial_next.visible = false
	if _lbl_tutorial_info_title != null:
		_lbl_tutorial_info_title.text = "Sistema de ventajas"
	var subject_icon_path: String = _get_unit_icon_path_from_display_name(unit_name)
	var counter_name: String = _extract_counter_target_name(counter_hint)
	var counter_icon_path: String = _get_unit_icon_path_from_display_name(counter_name)
	if _tutorial_info_subject_rich != null:
		_tutorial_info_subject_rich.clear()
		_tutorial_info_subject_rich.text = _build_inline_unit_rich_text("Invocaste un", subject_icon_path, unit_name)
	if _tutorial_info_target_rich != null:
		_tutorial_info_target_rich.clear()
		var target_label: String = counter_name if counter_name != "" else counter_hint
		_tutorial_info_target_rich.text = _build_inline_unit_rich_text("Rinde bien contra", counter_icon_path, target_label)
	if _lbl_tutorial_info_body != null:
		_lbl_tutorial_info_body.text = "Usa este esquema para recordar que cada unidad tiene un objetivo favorable."
	_tutorial_info_panel.visible = true

func hide_tutorial_info() -> void:
	if _tutorial_info_panel == null:
		return
	_tutorial_info_panel.visible = false

func _extract_counter_target_name(counter_hint: String) -> String:
	var marker: String = "contra "
	var start_idx: int = counter_hint.find(marker)
	if start_idx == -1:
		return ""
	var target_name: String = counter_hint.substr(start_idx + marker.length()).strip_edges()
	if target_name.ends_with("."):
		target_name = target_name.substr(0, target_name.length() - 1)
	return target_name

func _get_unit_icon_path_from_display_name(unit_name: String) -> String:
	for unit_type_value: Variant in UNIT_TYPE_DISPLAY_NAMES.keys():
		if str(UNIT_TYPE_DISPLAY_NAMES[unit_type_value]) != unit_name:
			continue
		if int(unit_type_value) == -1:
			return MASTER_ICON_PATH
		if CLASS_ICON_PATHS.has(int(unit_type_value)):
			return str(CLASS_ICON_PATHS[int(unit_type_value)])
	return ""

func _build_inline_unit_rich_text(prefix: String, icon_path: String, unit_name: String) -> String:
	var safe_prefix: String = prefix
	var safe_name: String = unit_name
	if safe_name.ends_with("."):
		safe_name = safe_name.substr(0, safe_name.length() - 1)
	if icon_path == "":
		return "%s %s." % [safe_prefix, safe_name]
	return "%s [img=18x18]%s[/img] %s." % [safe_prefix, icon_path, safe_name]

func _inline_unit_icons_in_text(text: String, icon_size: int = 18) -> String:
	var rich_text: String = text
	var replacements: Array = [
		["Maestro", MASTER_ICON_PATH],
		["Guerrero", str(CLASS_ICON_PATHS.get(0, ""))],
		["Arquero", str(CLASS_ICON_PATHS.get(1, ""))],
		["Lancero", str(CLASS_ICON_PATHS.get(2, ""))],
		["Jinete", str(CLASS_ICON_PATHS.get(3, ""))]
	]
	var staged_replacements: Array = []
	for i: int in range(replacements.size()):
		var entry: Array = replacements[i]
		var unit_name: String = str(entry[0])
		var icon_path: String = str(entry[1])
		if icon_path == "":
			continue
		var token: String = "__UNIT_INLINE_%d__" % i
		rich_text = rich_text.replace(unit_name, token)
		staged_replacements.append([token, "[img=%dx%d]%s[/img] %s" % [icon_size, icon_size, icon_path, unit_name]])
	var resource_replacements: Array = [
		["torres", TOWER_ICON_PATH],
		["Torre", TOWER_ICON_PATH],
		["torre", TOWER_ICON_PATH],
		["Unidades", UNITS_ICON_PATH],
		["unidades", UNITS_ICON_PATH],
		["Esencia", ESSENCE_ICON_INLINE_PATH],
		["esencia", ESSENCE_ICON_INLINE_PATH],
		["Unidad", UNITS_ICON_PATH],
		["unidad", UNITS_ICON_PATH],
	]
	for i: int in range(resource_replacements.size()):
		var entry: Array = resource_replacements[i]
		var label_text: String = str(entry[0])
		var icon_path: String = str(entry[1])
		var token: String = "__RESOURCE_INLINE_%d__" % i
		var replacement: String = "[img=%dx%d]%s[/img] %s" % [icon_size, icon_size, icon_path, label_text]
		if icon_path == ESSENCE_ICON_INLINE_PATH:
			replacement = "[img=%dx%d]%s[/img] [color=#59d7ff]%s[/color]" % [icon_size, icon_size, icon_path, label_text]
		rich_text = rich_text.replace(label_text, token)
		staged_replacements.append([token, replacement])
	for entry: Array in staged_replacements:
		rich_text = rich_text.replace(str(entry[0]), str(entry[1]))
	var card_term_replacements: Array = [
		["+ Curación", "[color=#6fe07a]+ Curación[/color]"],
		["+ Curación", "[color=#6fe07a]+ Curación[/color]"],
		["+ Curacion", "[color=#6fe07a]+ Curacion[/color]"],
		["+ curación", "[color=#6fe07a]+ curación[/color]"],
		["+ curacion", "[color=#6fe07a]+ curacion[/color]"],
		["Curación", "[color=#6fe07a]Curación[/color]"],
		["Curacion", "[color=#6fe07a]Curacion[/color]"],
		["curación", "[color=#6fe07a]curación[/color]"],
		["curacion", "[color=#6fe07a]curacion[/color]"],
		["Cura", "[color=#6fe07a]+ Cura[/color]"],
		["cura", "[color=#6fe07a]+ cura[/color]"],
		["Curar", "[color=#6fe07a]+ Curar[/color]"],
		["curar", "[color=#6fe07a]+ curar[/color]"],
		["Daño", "[color=#ff6767]X Daño[/color]"],
		["Daño", "[color=#ff6767]X Daño[/color]"],
		["Dano", "[color=#ff6767]X Dano[/color]"],
		["daño", "[color=#ff6767]X daño[/color]"],
		["dano", "[color=#ff6767]X dano[/color]"],
		["Dañar", "[color=#ff6767]X Dañar[/color]"],
		["Danar", "[color=#ff6767]X Danar[/color]"],
		["dañar", "[color=#ff6767]X dañar[/color]"],
		["danar", "[color=#ff6767]X danar[/color]"],
		["Experiencia", "[color=#c971ff]XP Experiencia[/color]"],
		["experiencia", "[color=#c971ff]XP experiencia[/color]"]
	]
	for entry: Array in card_term_replacements:
		rich_text = rich_text.replace(str(entry[0]), str(entry[1]))
	return rich_text

func _build_inline_placement_rich_text(message: String, unit_type: int) -> String:
	var rich_text: String = message
	var master_tag: String = "[img=16x16]%s[/img] Maestro" % MASTER_ICON_PATH
	rich_text = rich_text.replace("tu Maestro", "tu %s" % master_tag)
	rich_text = rich_text.replace("al Maestro", "al %s" % master_tag)
	if CLASS_ICON_PATHS.has(unit_type):
		var unit_name: String = str(UNIT_TYPE_DISPLAY_NAMES.get(unit_type, ""))
		var unit_icon_path: String = str(CLASS_ICON_PATHS.get(unit_type, ""))
		if unit_name != "" and unit_icon_path != "":
			rich_text = rich_text.replace(
				"Elegiste %s" % unit_name,
				"Elegiste [img=16x16]%s[/img] %s" % [unit_icon_path, unit_name]
			)
			rich_text = rich_text.replace(
				"Seleccionaste %s" % unit_name,
				"Seleccionaste [img=16x16]%s[/img] %s" % [unit_icon_path, unit_name]
			)
	var counter_name: String = _extract_counter_target_name(message)
	var counter_icon_path: String = _get_unit_icon_path_from_display_name(counter_name)
	if counter_name != "" and counter_icon_path != "":
		rich_text = rich_text.replace(
			"contra %s" % counter_name,
			"contra [img=16x16]%s[/img] %s" % [counter_icon_path, counter_name]
		)
	return rich_text

func show_tutorial_completion(title: String, body: String) -> void:
	if _tutorial_completion_panel == null:
		return
	hide_tutorial_info()
	_tutorial_completion_panel.visible = true
	if _lbl_tutorial_completion_title != null:
		_lbl_tutorial_completion_title.text = title
	if _lbl_tutorial_completion_body != null:
		_lbl_tutorial_completion_body.text = body

func hide_tutorial_completion() -> void:
	if _tutorial_completion_panel == null:
		return
	_tutorial_completion_panel.visible = false

func set_tutorial_focus(target: String) -> void:
	_tutorial_force_summon_glow = target == "summon"
	_tutorial_force_end_turn_glow = target == "end_turn"
	if _tutorial_summon_outline != null:
		_tutorial_summon_outline.visible = target == "summon"
	if _tutorial_end_turn_outline != null:
		_tutorial_end_turn_outline.visible = target == "end_turn"
	if _tutorial_summon_arrow != null:
		_tutorial_summon_arrow.visible = target == "summon"
	if _tutorial_end_turn_arrow != null:
		_tutorial_end_turn_arrow.visible = target == "end_turn"
	if _tutorial_resources_arrow != null:
		_tutorial_resources_arrow.visible = target == "resources"
	if _tutorial_turn_arrow != null:
		_tutorial_turn_arrow.visible = target == "turn"
	if _tutorial_advantage_arrow != null:
		_tutorial_advantage_arrow.visible = target == "advantage"
	if _tutorial_minimap_arrow != null:
		_tutorial_minimap_arrow.visible = target == "minimap"
	if _tutorial_unit_panel_arrow != null:
		_tutorial_unit_panel_arrow.visible = target == "unit_panel"
	if _tutorial_cards_arrow != null:
		_tutorial_cards_arrow.visible = target == "cards"
	if _tutorial_resources_outline != null:
		_tutorial_resources_outline.visible = target == "resources"
	if _tutorial_turn_outline != null:
		_tutorial_turn_outline.visible = target == "turn"
	if _tutorial_advantage_outline != null:
		_tutorial_advantage_outline.visible = target == "advantage"
	if _tutorial_minimap_outline != null:
		_tutorial_minimap_outline.visible = target == "minimap"
	if _tutorial_unit_panel_outline != null:
		_tutorial_unit_panel_outline.visible = target == "unit_panel"
	_refresh_action_button_glow()
	_update_tutorial_spotlight(target)

func set_tutorial_custom_focus_rect(rect: Rect2) -> void:
	_tutorial_custom_focus_rect = rect

func set_tutorial_world_markers(show_master: bool, master_world: Vector3, show_tower: bool, tower_world: Vector3) -> void:
	_tutorial_show_master_arrow = show_master
	_tutorial_master_world = master_world
	_tutorial_show_tower_arrow = show_tower
	_tutorial_tower_world = tower_world
	if _tutorial_master_arrow != null:
		_tutorial_master_arrow.visible = show_master
	if _tutorial_tower_arrow != null:
		_tutorial_tower_arrow.visible = show_tower

func _make_tutorial_arrow(_symbol: String = "", point_up: bool = false) -> TextureRect:
	var arrow := TextureRect.new()
	arrow.texture = TUTORIAL_ARROW_TEXTURE
	arrow.visible = false
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	arrow.stretch_mode = TextureRect.STRETCH_SCALE
	var tex_size: Vector2 = TUTORIAL_ARROW_TEXTURE.get_size()
	arrow.size = tex_size * 3.0 if tex_size != Vector2.ZERO else Vector2(24.0, 24.0)
	arrow.pivot_offset = arrow.size * 0.5
	if point_up:
		arrow.rotation_degrees = 180.0
	arrow.modulate = Color(1.0, 0.88, 0.28, 0.96)
	arrow.z_index = 20
	return arrow

func _make_tutorial_region_outline(rect: Rect2) -> TutorialOutline:
	var outline := TutorialOutlineScript.new()
	outline.position = rect.position
	outline.size = rect.size
	outline.visible = false
	_root.add_child(outline)
	return outline

func _update_tutorial_spotlight(target: String) -> void:
	if _tutorial_spotlight_rect == null or _tutorial_spotlight_mat == null:
		return
	var focus_rect: Rect2 = Rect2()
	match target:
		"resources":
			focus_rect = Rect2(8, 8, 198, 44)
		"turn":
			focus_rect = Rect2(214, 8, 120, 44)
		"advantage":
			focus_rect = Rect2(332, 8, 580, 44)
		"minimap":
			focus_rect = Rect2(1086, 8, 90, 32)
		"unit_panel":
			focus_rect = Rect2(18, 622, 346, 74)
		"summon":
			if _btn_summon != null:
				focus_rect = Rect2(_btn_summon.position.x - 16.0, _btn_summon.position.y - 44.0, _btn_summon.size.x + 32.0, _btn_summon.size.y + 60.0)
		"end_turn":
			if _btn_end_turn != null:
				focus_rect = Rect2(_btn_end_turn.position.x - 16.0, _btn_end_turn.position.y - 44.0, _btn_end_turn.size.x + 32.0, _btn_end_turn.size.y + 60.0)
		"cards":
			focus_rect = _tutorial_custom_focus_rect
	var panel_rect := Rect2(_tutorial_panel.position - Vector2(12.0, 12.0), _tutorial_panel.size + Vector2(24.0, 24.0))
	var show_spotlight: bool = _tutorial_panel != null and _tutorial_panel.visible and focus_rect.size != Vector2.ZERO
	_tutorial_spotlight_rect.visible = show_spotlight
	if not show_spotlight or _tutorial_spotlight_mat == null or _tutorial_spotlight_mat.shader == null:
		return
	var panel_screen_rect: Rect2 = _logical_rect_to_screen(panel_rect)
	var focus_screen_rect: Rect2 = _logical_rect_to_screen(focus_rect)
	_tutorial_spotlight_mat.set_shader_parameter("hole_a", Vector4(panel_screen_rect.position.x, panel_screen_rect.position.y, panel_screen_rect.size.x, panel_screen_rect.size.y))
	_tutorial_spotlight_mat.set_shader_parameter("hole_b", Vector4(focus_screen_rect.position.x, focus_screen_rect.position.y, focus_screen_rect.size.x, focus_screen_rect.size.y))

func _update_tutorial_arrows() -> void:
	var bob: float = sin(_ui_fx_time * 5.4) * 5.0
	if _tutorial_summon_arrow != null and _btn_summon != null and _tutorial_summon_arrow.visible:
		_tutorial_summon_arrow.position = Vector2(
			_btn_summon.position.x + _btn_summon.size.x * 0.5 - _tutorial_summon_arrow.size.x * 0.5,
			_btn_summon.position.y - 34.0 + bob
		)
	if _tutorial_end_turn_arrow != null and _btn_end_turn != null and _tutorial_end_turn_arrow.visible:
		_tutorial_end_turn_arrow.position = Vector2(
			_btn_end_turn.position.x + _btn_end_turn.size.x * 0.5 - _tutorial_end_turn_arrow.size.x * 0.5,
			_btn_end_turn.position.y - 34.0 + bob
		)
	if _tutorial_resources_arrow != null and _tutorial_resources_arrow.visible:
		_tutorial_resources_arrow.position = Vector2(92.0, 56.0 + bob)
	if _tutorial_turn_arrow != null and _tutorial_turn_arrow.visible:
		_tutorial_turn_arrow.position = Vector2(256.0, 56.0 + bob)
	if _tutorial_advantage_arrow != null and _tutorial_advantage_arrow.visible:
		_tutorial_advantage_arrow.position = Vector2(596.0, 56.0 + bob)
	if _tutorial_minimap_arrow != null and _tutorial_minimap_arrow.visible:
		_tutorial_minimap_arrow.position = Vector2(1115.0, 46.0 + bob)
	if _tutorial_unit_panel_arrow != null and _tutorial_unit_panel_arrow.visible:
		_tutorial_unit_panel_arrow.position = Vector2(164.0, 572.0 + bob)
	if _tutorial_cards_arrow != null and _tutorial_cards_arrow.visible:
		var cards_focus_rect: Rect2 = _tutorial_custom_focus_rect
		if cards_focus_rect.size == Vector2.ZERO:
			_tutorial_cards_arrow.position = Vector2(662.0, 516.0 + bob)
		else:
			_tutorial_cards_arrow.position = Vector2(
				cards_focus_rect.position.x + cards_focus_rect.size.x * 0.5 - _tutorial_cards_arrow.size.x * 0.5,
				cards_focus_rect.position.y - _tutorial_cards_arrow.size.y - 8.0 + bob
			)
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	if _tutorial_master_arrow != null and _tutorial_master_arrow.visible:
		_tutorial_master_arrow.position = _tutorial_world_arrow_pos(cam, _tutorial_master_world, bob)
	if _tutorial_tower_arrow != null and _tutorial_tower_arrow.visible:
		_tutorial_tower_arrow.position = _tutorial_world_arrow_pos(cam, _tutorial_tower_world, bob)

func _tutorial_world_arrow_pos(cam: Camera3D, world_pos: Vector3, bob: float) -> Vector2:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var sample: Vector3 = world_pos + Vector3(0.0, 1.5, 0.0)
	if cam.is_position_behind(sample):
		return Vector2(-5000.0, -5000.0)
	var projected: Vector2 = cam.unproject_position(sample)
	projected.x = clampf(projected.x, 20.0, viewport_size.x - 68.0)
	projected.y = clampf(projected.y, 20.0, viewport_size.y - 68.0)
	return projected + Vector2(-24.0, -46.0 + bob)

func _viewport_size() -> Vector2:
	var rect: Rect2 = get_viewport().get_visible_rect()
	return rect.size if rect.size != Vector2.ZERO else HUD_SIZE

func _update_view_layout() -> void:
	var viewport_size: Vector2 = _viewport_size()
	_hud_view_scale = minf(viewport_size.x / HUD_SIZE.x, viewport_size.y / HUD_SIZE.y)
	if _hud_view_scale <= 0.0:
		_hud_view_scale = 1.0
	var scaled_size: Vector2 = HUD_SIZE * _hud_view_scale
	_hud_view_origin = (viewport_size - scaled_size) * 0.5
	if _root != null:
		_root.position = _hud_view_origin
		_root.scale = Vector2.ONE * _hud_view_scale
	if _tutorial_overlay_root != null:
		_tutorial_overlay_root.position = _hud_view_origin
		_tutorial_overlay_root.scale = Vector2.ONE * _hud_view_scale
	if _tutorial_spotlight_rect != null:
		_tutorial_spotlight_rect.size = viewport_size
	if _cinematic_top_bar != null:
		_cinematic_top_bar.position = Vector2.ZERO
		_cinematic_top_bar.size.x = viewport_size.x
	if _cinematic_bottom_bar != null:
		_cinematic_bottom_bar.size.x = viewport_size.x
		_cinematic_bottom_bar.position.y = viewport_size.y - _cinematic_bottom_bar.size.y

func _logical_rect_to_screen(rect: Rect2) -> Rect2:
	var window_size: Vector2 = _window_pixel_size()
	var scale_factor: float = minf(window_size.x / HUD_SIZE.x, window_size.y / HUD_SIZE.y)
	if scale_factor <= 0.0:
		scale_factor = 1.0
	var scaled_size: Vector2 = HUD_SIZE * scale_factor
	var origin: Vector2 = (window_size - scaled_size) * 0.5
	return Rect2(origin + rect.position * scale_factor, rect.size * scale_factor)

func _screen_to_logical(point: Vector2) -> Vector2:
	var window_size: Vector2 = _window_pixel_size()
	var scale_factor: float = minf(window_size.x / HUD_SIZE.x, window_size.y / HUD_SIZE.y)
	if scale_factor <= 0.0:
		scale_factor = 1.0
	var scaled_size: Vector2 = HUD_SIZE * scale_factor
	var origin: Vector2 = (window_size - scaled_size) * 0.5
	return (point - origin) / scale_factor

func _window_pixel_size() -> Vector2:
	var win: Window = get_window()
	if win != null and win.size != Vector2i.ZERO:
		return Vector2(win.size)
	var rect: Rect2 = get_viewport().get_visible_rect()
	return rect.size if rect.size != Vector2.ZERO else HUD_SIZE

func _terrain_move_text(terrain: int) -> String:
	match terrain:
		1:
			return "Inaccesible"
		6:
			return "Inaccesible"
		2, 3:
			return "Movimiento 2"
		_:
			return "Movimiento 1"

func _terrain_attack_modifier(terrain: int) -> int:
	match terrain:
		1:
			return -1
		2:
			return 2
		3:
			return 1
		_:
			return 0

func _terrain_attack_text(modifier: int) -> String:
	if modifier > 0:
		return "Ataques +%d" % modifier
	if modifier < 0:
		return "Ataques %d" % modifier
	return "Ataques sin bonus"

func _refresh_action_button_glow() -> void:
	var current_player: int = turn_manager.current_player if turn_manager != null else 1
	var ai_turn: bool = _is_current_turn_ai()
	var summon_ready: bool = _can_current_player_summon(current_player)
	var no_actions_left: bool = not _has_player_actions_remaining(current_player)
	if _btn_summon != null:
		_btn_summon.disabled = ai_turn
		_btn_summon.mouse_filter = Control.MOUSE_FILTER_IGNORE if ai_turn else Control.MOUSE_FILTER_STOP
	if _btn_end_turn != null:
		_btn_end_turn.disabled = ai_turn
		_btn_end_turn.mouse_filter = Control.MOUSE_FILTER_IGNORE if ai_turn else Control.MOUSE_FILTER_STOP
	var summon_glow_enabled: bool = (summon_ready and not ai_turn) or (_tutorial_force_summon_glow and not ai_turn)
	var end_turn_glow_enabled: bool = (no_actions_left and not ai_turn) or (_tutorial_force_end_turn_glow and not ai_turn)
	_apply_button_glow(_summon_glow, _btn_summon, SUMMON_READY_COLOR, summon_glow_enabled)
	_apply_button_glow(_end_turn_glow, _btn_end_turn, END_TURN_READY_COLOR, end_turn_glow_enabled)

func _is_current_turn_ai() -> bool:
	if turn_manager == null:
		return false
	return GameData.get_player_mode(turn_manager.current_player) == "ai"

func _apply_button_glow(glow: ColorRect, button: Button, color: Color, enabled: bool) -> void:
	if glow == null or button == null:
		return
	if enabled:
		glow.color = Color(color.r, color.g, color.b, 0.26)
		button.add_theme_color_override("font_color", color.lightened(0.18))
		button.add_theme_color_override("font_hover_color", color.lightened(0.28))
		button.add_theme_color_override("font_pressed_color", color.lightened(0.12))
		button.add_theme_color_override("font_focus_color", color.lightened(0.18))
	else:
		glow.color = Color(1.0, 1.0, 1.0, 0.0)
		button.add_theme_color_override("font_color", LABEL_COLOR)
		button.add_theme_color_override("font_hover_color", LABEL_COLOR)
		button.add_theme_color_override("font_pressed_color", LABEL_COLOR)
		button.add_theme_color_override("font_focus_color", LABEL_COLOR)

func _is_button_glow_enabled(glow: ColorRect) -> bool:
	return glow != null and glow.color.a > 0.01

func _update_button_flame(flame: Dictionary, button: Button, color: Color, enabled: bool) -> void:
	if flame.is_empty() or button == null:
		return
	var base: ColorRect = flame.get("base") as ColorRect
	var band: ColorRect = flame.get("band") as ColorRect
	var hot: ColorRect = flame.get("hot") as ColorRect
	if base == null or band == null or hot == null:
		return
	if not enabled:
		base.color = Color(color.r, color.g, color.b, 0.0)
		band.color = Color(color.r, color.g, color.b, 0.0)
		hot.color = Color(color.r, color.g, color.b, 0.0)
		return

	var phase: float = float(flame.get("phase", 0.0))
	var flicker: float = 0.5 + 0.5 * sin(_ui_fx_time * 6.5 + phase)
	var surge: float = 0.5 + 0.5 * sin(_ui_fx_time * 3.2 + phase * 1.7)
	var base_height: float = button.size.y * (0.48 + surge * 0.10)
	var band_height: float = button.size.y * (0.34 + flicker * 0.08)
	var hot_height: float = button.size.y * (0.18 + surge * 0.10)

	base.position = button.position + Vector2(4, button.size.y - base_height - 2)
	base.size = Vector2(button.size.x - 8, base_height)
	base.color = Color(color.r, color.g, color.b, 0.14 + flicker * 0.10)

	band.position = button.position + Vector2(10, button.size.y - band_height - 2)
	band.size = Vector2(button.size.x - 20, band_height)
	band.color = Color(color.r, color.g, color.b, 0.18 + surge * 0.14)

	var hot_width: float = button.size.x * (0.32 + flicker * 0.08)
	hot.position = button.position + Vector2((button.size.x - hot_width) * 0.5, button.size.y - hot_height - 3)
	hot.size = Vector2(hot_width, hot_height)
	hot.color = Color(color.lightened(0.2).r, color.lightened(0.2).g, color.lightened(0.2).b, 0.22 + flicker * 0.16)

func _update_button_motes(motes: Array[Dictionary], button: Button, color: Color, enabled: bool) -> void:
	if button == null:
		return
	for mote_data: Dictionary in motes:
		var mote: ColorRect = mote_data.get("node") as ColorRect
		if mote == null:
			continue
		if not enabled:
			mote.color = Color(color.r, color.g, color.b, BUTTON_MOTE_IDLE_ALPHA)
			continue

		var phase: float = float(mote_data.get("phase", 0.0))
		var speed: float = float(mote_data.get("speed", 1.0))
		var blink: float = 0.5 + 0.5 * sin(_ui_fx_time * speed + phase)
		var pulse: float = smoothstep(0.60, 0.80, blink) * (1.0 - smoothstep(0.88, 0.99, blink))
		var base := Vector2(
			button.position.x + float(mote_data.get("base_x", 8.0)),
			button.position.y + float(mote_data.get("base_y", button.size.y - 6.0))
		)
		var drift_x: float = float(mote_data.get("drift_x", 0.0))
		var rise: float = float(mote_data.get("rise", 10.0))
		var wobble_x: float = sin(_ui_fx_time * speed * 1.8 + phase * 0.7) * 1.8
		var offset_x: float = drift_x * pulse * 0.55 + wobble_x
		var offset_y: float = -rise * pulse

		mote.position = base + Vector2(offset_x, offset_y)
		var mote_alpha: float = pulse * 0.92
		mote.color = Color(color.r, color.g, color.b, mote_alpha)
		var size_px: float = 2.0 + round((pulse + float(mote_data.get("scale_boost", 0.0)) * 0.2) * 3.0)
		mote.size = Vector2(size_px, size_px)

func _has_player_actions_remaining(player_id: int) -> bool:
	return _player_has_moves_left(player_id) or _can_current_player_summon(player_id)

func _player_has_moves_left(player_id: int) -> bool:
	if hex_grid == null or not hex_grid.has_method("get_all_units"):
		return false
	for unit: Variant in hex_grid.get_all_units():
		if int(unit.get("owner_id")) != player_id:
			continue
		if unit.has_method("get_moves_left") and int(unit.call("get_moves_left")) > 0:
			return true
	return false

func _can_current_player_summon(player_id: int) -> bool:
	if resource_manager == null or hex_grid == null:
		return false
	var essence: int = resource_manager.get_essence(player_id)
	return essence >= 10 and _player_has_adjacent_summon_space(player_id)

func _player_has_adjacent_summon_space(player_id: int) -> bool:
	if not hex_grid.has_method("get_all_units") or not hex_grid.has_method("_get_neighbors"):
		return false
	for unit: Variant in hex_grid.get_all_units():
		if int(unit.get("owner_id")) != player_id:
			continue
		if not (unit is Master):
			continue
		var master_cell: Vector2i = _find_unit_cell(unit)
		if master_cell == Vector2i(-1, -1):
			continue
		for nb: Variant in hex_grid.call("_get_neighbors", master_cell.x, master_cell.y):
			var cell: Vector2i = nb as Vector2i
			if hex_grid.get_unit_at(cell.x, cell.y) == null:
				return true
	return false

func _find_unit_cell(target_unit: Variant) -> Vector2i:
	if hex_grid == null:
		return Vector2i(-1, -1)
	var unit_map: Dictionary = hex_grid.get("_units") as Dictionary
	if unit_map == null:
		return Vector2i(-1, -1)
	for key: Variant in unit_map.keys():
		if unit_map[key] == target_unit:
			return key as Vector2i
	return Vector2i(-1, -1)

func show_combat_result(attacker: Unit, defender: Unit, result: Dictionary) -> void:
	_last_combat_data = {
		"atk_name": attacker.unit_name,
		"atk_hp": attacker.hp,
		"atk_max_hp": attacker.max_hp,
		"atk_owner": attacker.owner_id,
		"atk_blessings": _get_combat_relevant_bonuses(attacker),
		"def_name": defender.unit_name,
		"def_hp": defender.hp,
		"def_max_hp": defender.max_hp,
		"def_owner": defender.owner_id,
		"def_blessings": _get_combat_relevant_bonuses(defender),
		"result": result,
	}
	_btn_last_combat.disabled = false
	refresh_advantage()

func _toggle_combat_panel() -> void:
	if _combat_panel.visible:
		_combat_panel.visible = false
	else:
		_populate_combat_panel()
		_combat_panel.visible = true

func _populate_combat_panel() -> void:
	if _last_combat_data.is_empty():
		return

	var result: Dictionary = _last_combat_data["result"]
	var multiplier: float = result.get("type_mult", 1.0)
	var ranged_tag: String = " [distancia]" if result.get("is_ranged", false) else ""
	var mult_tag := ""
	if multiplier > 1.0:
		mult_tag = " [+1]"
	elif multiplier < 1.0:
		mult_tag = " [desventaja]"

	_lbl_cb_title.text = "%s vs %s%s%s" % [
		_last_combat_data["atk_name"],
		_last_combat_data["def_name"],
		mult_tag,
		ranged_tag,
	]
	_lbl_cb_attacker.text = "ATK %s %d/%d HP" % [
		_last_combat_data["atk_name"],
		_last_combat_data["atk_hp"],
		_last_combat_data["atk_max_hp"],
	]
	_lbl_cb_defender.text = "DEF %s %d/%d HP" % [
		_last_combat_data["def_name"],
		_last_combat_data["def_hp"],
		_last_combat_data["def_max_hp"],
	]
	_populate_blessing_chips(_cb_attacker_chips, _last_combat_data.get("atk_blessings", []))
	_populate_blessing_chips(_cb_defender_chips, _last_combat_data.get("def_blessings", []))

	var lines: Array[String] = []
	for entry: Dictionary in result.get("attacker_log", []):
		lines.append(_format_roll(_last_combat_data["atk_name"], entry, multiplier))
	for entry: Dictionary in result.get("defender_log", []):
		lines.append(_format_roll(_last_combat_data["def_name"], entry, 1.0))
	_lbl_cb_log.text = "\n".join(lines)

	if result.get("defender_died", false) and result.get("attacker_died", false):
		_lbl_cb_result.text = "Empate: ambos caidos"
		_lbl_cb_result.add_theme_color_override("font_color", LABEL_DIM)
	elif result.get("defender_died", false):
		_lbl_cb_result.text = "%s gana" % _last_combat_data["atk_name"]
		_lbl_cb_result.add_theme_color_override(
			"font_color",
			_player_color(int(_last_combat_data["atk_owner"]))
		)
	elif result.get("attacker_died", false):
		_lbl_cb_result.text = "%s cae" % _last_combat_data["atk_name"]
		_lbl_cb_result.add_theme_color_override("font_color", HP_ON)
	else:
		_lbl_cb_result.text = "Ambos sobreviven"
		_lbl_cb_result.add_theme_color_override("font_color", LABEL_COLOR)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
			if _combat_panel.visible:
				_combat_panel.visible = false
				get_viewport().set_input_as_handled()

func _count_units(player_id: int) -> int:
	if hex_grid == null or not hex_grid.has_method("get_all_units"):
		return 0
	var count := 0
	for unit: Variant in hex_grid.get_all_units():
		if int(unit.get("owner_id")) == player_id:
			count += 1
	return count

func _dice_text(prefix: String, dice: Array) -> String:
	if dice.is_empty():
		return "%s: -" % prefix
	var names: Array[String] = []
	for die: int in dice:
		var idx: int = clampi(die, 0, DICE_NAMES.size() - 1)
		names.append(DICE_NAMES[idx])
	return "%s: %s" % [prefix, ", ".join(names)]

func _format_roll(unit_name: String, entry: Dictionary, multiplier: float) -> String:
	var rolls: Array = entry.get("rolls", [])
	var total: int = entry.get("total", 0)
	var damage: int = entry.get("damage", 0)
	var advantage_bonus: int = int(entry.get("advantage_bonus", 0))
	var parts: Array[String] = []
	for roll: Dictionary in rolls:
		var color_idx: int = clampi(roll.get("color", 0), 0, DICE_NAMES.size() - 1)
		parts.append("%s:%d" % [DICE_NAMES[color_idx], roll.get("value", 0)])
	var bonus_text := ""
	if advantage_bonus > 0:
		bonus_text = " +1 ventaja"
	elif multiplier < 1.0:
		bonus_text = " desventaja"
	return "%s %s -> %d%s -> %d" % [unit_name, " ".join(parts), total, bonus_text, damage]
