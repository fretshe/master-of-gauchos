extends CanvasLayer

const MatchAdvantageScript := preload("res://scripts/MatchAdvantage.gd")
const TutorialOutlineScript := preload("res://scripts/TutorialOutline.gd")
const TutorialSpotlightShader := preload("res://shaders/tutorial_spotlight.gdshader")

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
signal tutorial_skip_pressed()
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
const PLAYER_ONE_COLOR := Color(0.20, 0.50, 1.00, 1.00)
const PLAYER_TWO_COLOR := Color(1.00, 0.20, 0.20, 1.00)
const PLAYER_THREE_COLOR := Color(0.24, 0.88, 0.34, 1.00)
const PLAYER_FOUR_COLOR := Color(1.00, 0.88, 0.24, 1.00)
const HP_ON := Color(0.89, 0.19, 0.19, 1.0)
const HP_OFF := Color(0.96, 0.96, 0.96, 1.0)
const XP_ON := Color(0.86, 0.15, 0.95, 1.0)
const XP_OFF := Color(0.96, 0.96, 0.96, 1.0)
const SEGMENT_DISABLED := Color(0.62, 0.62, 0.62, 1.0)
const DICE_NAMES := ["Rojo", "Amarillo", "Verde", "Azul"]
const DICE_COLORS := [
	Color(1.00, 0.30, 0.30, 1.0),
	Color(1.00, 0.92, 0.20, 1.0),
	Color(0.24, 0.88, 0.34, 1.0),
	Color(0.32, 0.60, 1.00, 1.0),
]
const LEVEL_TEXT := {
	1: "BRONZE",
	2: "SILVER",
	3: "GOLD",
	4: "DIAMOND",
}
const LEVEL_COLORS := {
	1: Color(0.85, 0.55, 0.25, 1.0),
	2: Color(0.80, 0.82, 0.88, 1.0),
	3: Color(1.00, 0.84, 0.24, 1.0),
	4: Color(0.28, 0.88, 1.00, 1.0),
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
var _portrait: TextureRect
var _portrait_bg: TextureRect
var _unit_class_icon: TextureRect
var _unit_level_bar: ColorRect
var _lbl_unit_name: Label
var _lbl_unit_level: Label
var _lbl_unit_tier: Label
var _lbl_hp_value: Label
var _lbl_xp_value: Label
var _lbl_move_value: Label
var _lbl_range_value: Label
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
var _placement_banner: Panel
var _placement_hint_icon: TextureRect
var _lbl_placement_title: Label
var _lbl_placement: Label
var _combat_panel: Panel
var _lbl_cb_title: Label
var _lbl_cb_attacker: Label
var _lbl_cb_defender: Label
var _lbl_cb_log: Label
var _lbl_cb_result: Label
var _minimap_texture: Control
var _unit_accent_line: ColorRect
var _hp_segments: Array[Panel] = []
var _xp_segments: Array[Panel] = []
var _lbl_tw_p1: Label
var _lbl_tw_p2: Label
var _lbl_tw_neutral: Label
var _lbl_tw_income: Label
var _last_combat_data: Dictionary = {}
var _ui_fx_time: float = 0.0
var _portrait_cache: Dictionary = {}
var _pause_overlay: ColorRect
var _pause_panel: Panel
var _btn_pause_resume: Button
var _btn_pause_save: Button
var _btn_pause_save_exit: Button
var _btn_pause_restart: Button
var _btn_pause_sound: Button
var _btn_pause_back_menu: Button
var _pause_confirm_panel: Panel
var _pause_confirm_label: Label
var _btn_pause_confirm_yes: Button
var _btn_pause_confirm_no: Button
var _cell_context_panel: Panel
var _lbl_cell_context_title: Label
var _lbl_cell_context_body: Label
var _tutorial_panel: Panel
var _lbl_tutorial_step: Label
var _lbl_tutorial_title: Label
var _lbl_tutorial_body: Label
var _btn_tutorial_skip: Button
var _btn_tutorial_next: Button
var _tutorial_info_panel: Panel
var _lbl_tutorial_info_title: Label
var _lbl_tutorial_info_body: Label
var _btn_tutorial_info_continue: Button
var _tutorial_info_advantage_icons: Array[TextureRect] = []
var _tutorial_info_advantage_arrows: Array[Label] = []
var _tutorial_panel_outline: TutorialOutline
var _tutorial_summon_outline: TutorialOutline
var _tutorial_end_turn_outline: TutorialOutline
var _tutorial_resources_outline: TutorialOutline
var _tutorial_advantage_outline: TutorialOutline
var _tutorial_minimap_outline: TutorialOutline
var _tutorial_unit_panel_outline: TutorialOutline
var _tutorial_spotlight_layer: CanvasLayer
var _tutorial_spotlight_rect: ColorRect
var _tutorial_spotlight_mat: ShaderMaterial
var _tutorial_overlay_layer: CanvasLayer
var _tutorial_overlay_root: Control
var _tutorial_custom_focus_rect: Rect2 = Rect2()
var _tutorial_summon_arrow: Label
var _tutorial_end_turn_arrow: Label
var _tutorial_resources_arrow: Label
var _tutorial_advantage_arrow: Label
var _tutorial_minimap_arrow: Label
var _tutorial_unit_panel_arrow: Label
var _tutorial_cards_arrow: Label
var _tutorial_master_arrow: Label
var _tutorial_tower_arrow: Label
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
	_build_combat_panel()
	hide_unit()

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
	match player_id:
		1:
			return PLAYER_ONE_COLOR
		2:
			return PLAYER_TWO_COLOR
		3:
			return PLAYER_THREE_COLOR
		4:
			return PLAYER_FOUR_COLOR
		_:
			return LABEL_COLOR

func _process(delta: float) -> void:
	_ui_fx_time += delta
	_update_button_flame(_summon_flame, _btn_summon, SUMMON_READY_COLOR, _is_button_glow_enabled(_summon_glow))
	_update_button_flame(_end_turn_flame, _btn_end_turn, END_TURN_READY_COLOR, _is_button_glow_enabled(_end_turn_glow))
	_update_button_motes(_summon_motes, _btn_summon, SUMMON_READY_COLOR, _is_button_glow_enabled(_summon_glow))
	_update_button_motes(_end_turn_motes, _btn_end_turn, END_TURN_READY_COLOR, _is_button_glow_enabled(_end_turn_glow))
	_update_tutorial_info_diagram()
	_update_tutorial_arrows()

func set_combat_cinematic(active: bool) -> void:
	var target_alpha: float = 0.0 if active else 1.0
	create_tween().tween_property(_root, "modulate:a", target_alpha, 0.24) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var target_height: float = COMBAT_BAR_HEIGHT if active else 0.0
	var target_bar_alpha: float = 0.78 if active else 0.0

	if _cinematic_top_bar != null:
		var top_tw := create_tween().set_parallel(true)
		top_tw.tween_property(_cinematic_top_bar, "size:y", target_height, 0.28) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		top_tw.tween_property(_cinematic_top_bar, "color:a", target_bar_alpha, 0.24) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	if _cinematic_bottom_bar != null:
		var bottom_y: float = HUD_SIZE.y - target_height
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
	_cinematic_top_bar.size = Vector2(HUD_SIZE.x, 0.0)
	_cinematic_top_bar.color = Color(0.0, 0.0, 0.0, 0.0)
	_cinematic_top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cinematic_top_bar)

	_cinematic_bottom_bar = ColorRect.new()
	_cinematic_bottom_bar.position = Vector2(0.0, HUD_SIZE.y)
	_cinematic_bottom_bar.size = Vector2(HUD_SIZE.x, 0.0)
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
	_turn_band_glow.color = Color(PLAYER_ONE_COLOR.r, PLAYER_ONE_COLOR.g, PLAYER_ONE_COLOR.b, 0.20)
	_turn_band_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_turn_band_glow)

	_turn_band_core = ColorRect.new()
	_turn_band_core.position = Vector2(0, 0)
	_turn_band_core.size = Vector2(HUD_SIZE.x, 4)
	_turn_band_core.color = PLAYER_ONE_COLOR
	_turn_band_core.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_turn_band_core)

	_turn_band_glow_bottom = ColorRect.new()
	_turn_band_glow_bottom.position = Vector2(0, HUD_SIZE.y - 12)
	_turn_band_glow_bottom.size = Vector2(HUD_SIZE.x, 12)
	_turn_band_glow_bottom.color = Color(PLAYER_ONE_COLOR.r, PLAYER_ONE_COLOR.g, PLAYER_ONE_COLOR.b, 0.20)
	_turn_band_glow_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_turn_band_glow_bottom)

	_turn_band_core_bottom = ColorRect.new()
	_turn_band_core_bottom.position = Vector2(0, HUD_SIZE.y - 4)
	_turn_band_core_bottom.size = Vector2(HUD_SIZE.x, 4)
	_turn_band_core_bottom.color = PLAYER_ONE_COLOR
	_turn_band_core_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_turn_band_core_bottom)

	_add_glass_panel(Rect2(8, 8, 386, 44), HUD_GLASS_DARK)
	_turn_panel_glow = _add_glass_panel(Rect2(8, 58, 126, 44), Color(PLAYER_ONE_COLOR.r, PLAYER_ONE_COLOR.g, PLAYER_ONE_COLOR.b, 0.16))
	_add_glass_panel(Rect2(408, 8, 472, 44), Color(0.16, 0.18, 0.22, 0.58))
	_add_glass_panel(Rect2(978, 8, 290, 182), Color(0.18, 0.20, 0.24, 0.52))
	_add_glass_panel(Rect2(18, 506, 346, 194), Color(0.18, 0.20, 0.24, 0.58))
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
	for rect: Rect2 in [
		Rect2(8, 8, 386, 44),
		Rect2(8, 58, 126, 44),
		Rect2(408, 8, 472, 44),
		Rect2(978, 8, 290, 182),
		Rect2(18, 506, 346, 194),
		Rect2(384, 640, 136, 54),
		Rect2(1114, 640, 134, 60),
	]:
		_add_panel_corners(rect)

func _add_panel_corners(rect: Rect2) -> void:
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

func _build_top_left_stats() -> void:
	_team_icon = ColorRect.new()
	_team_icon.position = Vector2(18, 15)
	_team_icon.size = Vector2(8, 22)
	_team_icon.color = PLAYER_ONE_COLOR
	_root.add_child(_team_icon)

	_add_stat_texture_icon("res://assets/sprites/ui/icon_tower.png", Vector2(72, 12), Vector2(28, 28))
	_add_stat_texture_icon("res://assets/sprites/ui/icon_essence.png", Vector2(181, 12), Vector2(28, 28), Color(0.42, 0.88, 1.0, 1.0), true)
	_add_stat_texture_icon("res://assets/sprites/ui/icon_units.png", Vector2(292, 12), Vector2(30, 30))

	_lbl_towers = _make_label("0", Vector2(115, 10), HUD_FONT_SIZE_LARGE)
	_lbl_towers.position = Vector2(108, 18)
	_lbl_towers.size = Vector2(52, 20)
	_lbl_towers.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_essence = _make_label("0", Vector2(225, 10), HUD_FONT_SIZE_LARGE)
	_lbl_essence.position = Vector2(218, 18)
	_lbl_essence.size = Vector2(52, 20)
	_lbl_essence.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_unit_count = _make_label("0", Vector2(335, 10), HUD_FONT_SIZE_LARGE)
	_lbl_unit_count.position = Vector2(328, 18)
	_lbl_unit_count.size = Vector2(52, 20)
	_lbl_unit_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_make_label("TORRES", Vector2(100, 34), 11, Vector2(66, 12), LABEL_DIM)
	_make_label("ESENCIA", Vector2(206, 34), 11, Vector2(76, 12), LABEL_DIM)
	_make_label("UNIDADES", Vector2(309, 34), 11, Vector2(88, 12), LABEL_DIM)

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
	_lbl_turn_num = _make_label("1", Vector2(34, 62), HUD_FONT_SIZE_LARGE, Vector2(74, 0))
	_lbl_turn_num.position = Vector2(34, 66)
	_lbl_turn_num.size = Vector2(66, 20)
	_lbl_turn_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_make_label("TURNO", Vector2(32, 84), 11, Vector2(76, 12), LABEL_DIM)

func _build_last_combat_button() -> void:
	_btn_last_combat = _make_button("Ultimo combate", Vector2(700, 12), Vector2(180, 20), HUD_FONT_SIZE_SMALL)
	_btn_last_combat.position = Vector2(-400, -120)
	_btn_last_combat.size = Vector2(1, 1)
	_btn_last_combat.disabled = true
	_btn_last_combat.visible = false
	_btn_last_combat.pressed.connect(_toggle_combat_panel)
	_btn_last_combat.pressed.connect(AudioManager.play_button)

	_btn_pause_menu = _make_button("Menu", Vector2(890, 14), Vector2(76, 32), HUD_FONT_SIZE_SMALL)
	_btn_pause_menu.tooltip_text = "Opciones de partida"
	_btn_pause_menu.pressed.connect(_toggle_pause_menu)
	_btn_pause_menu.pressed.connect(AudioManager.play_button)

func _build_advantage_panel() -> void:
	_advantage_title = _make_label("VENTAJA", Vector2(422, 14), 11, Vector2(90, 14), LABEL_DIM)
	_advantage_status = _make_label("", Vector2(514, 14), HUD_FONT_SIZE_SMALL, Vector2(352, 16), LABEL_COLOR)
	_advantage_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	_advantage_hover_area = Control.new()
	_advantage_hover_area.position = Vector2(408, 8)
	_advantage_hover_area.size = Vector2(472, 58)
	_advantage_hover_area.mouse_filter = Control.MOUSE_FILTER_STOP
	_advantage_hover_area.mouse_entered.connect(func() -> void:
		_set_advantage_details_visible(true)
	)
	_advantage_hover_area.mouse_exited.connect(func() -> void:
		_set_advantage_details_visible(false)
	)
	_root.add_child(_advantage_hover_area)

	_advantage_bar_bg = ColorRect.new()
	_advantage_bar_bg.position = Vector2(422, 30)
	_advantage_bar_bg.size = Vector2(444, 8)
	_advantage_bar_bg.color = Color(1.0, 1.0, 1.0, 0.08)
	_advantage_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_advantage_bar_bg)

	_advantage_bar_fill_container = Control.new()
	_advantage_bar_fill_container.position = _advantage_bar_bg.position
	_advantage_bar_fill_container.size = _advantage_bar_bg.size
	_advantage_bar_fill_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_advantage_bar_fill_container)

	for i: int in range(4):
		var label := _make_label("", Vector2(422 + float(i % 2) * 222.0, 42 + float(i / 2) * 12.0), 11, Vector2(214, 12), LABEL_DIM)
		_advantage_rank_labels.append(label)

	_set_advantage_details_visible(false)
	refresh_advantage()

func _build_minimap() -> void:
	_minimap_texture = Control.new()
	_minimap_texture.position = Vector2(984, 14)
	_minimap_texture.size = Vector2(278, 170)
	_minimap_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_minimap_texture.clip_contents = true
	_root.add_child(_minimap_texture)
	_redraw_minimap()

func _build_unit_panel() -> void:
	_unit_accent_line = ColorRect.new()
	_unit_accent_line.position = Vector2(22, 518)
	_unit_accent_line.size = Vector2(4, 176)
	_unit_accent_line.color = UNIT_PANEL_NEUTRAL
	_unit_accent_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_unit_accent_line)

	_unit_level_bar = ColorRect.new()
	_unit_level_bar.position = Vector2(30, 506)
	_unit_level_bar.size = Vector2(326, 7)
	_unit_level_bar.color = UNIT_PANEL_NEUTRAL
	_unit_level_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_unit_level_bar)

	var portrait_glow := ColorRect.new()
	portrait_glow.position = Vector2(26, 514)
	portrait_glow.size = Vector2(110, 138)
	portrait_glow.color = Color(SUMMON_READY_COLOR.r, SUMMON_READY_COLOR.g, SUMMON_READY_COLOR.b, 0.10)
	portrait_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(portrait_glow)

	var portrait_frame := ColorRect.new()
	portrait_frame.position = Vector2(30, 518)
	portrait_frame.size = Vector2(102, 130)
	portrait_frame.color = Color(0.14, 0.20, 0.26, 0.58)
	portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(portrait_frame)

	_portrait = TextureRect.new()
	_portrait.position = Vector2(26, 514)
	_portrait.size = Vector2(110, 138)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_portrait)

	_portrait_bg = TextureRect.new()
	_portrait_bg.position = Vector2(184, 514)
	_portrait_bg.size = Vector2(152, 122)
	_portrait_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait_bg.modulate = Color(1.0, 1.0, 1.0, 0.18)
	_portrait_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_portrait_bg)

	_unit_class_icon = TextureRect.new()
	_unit_class_icon.position = Vector2(138, 519)
	_unit_class_icon.size = Vector2(20, 20)
	_unit_class_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_unit_class_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_unit_class_icon.modulate = Color(0.96, 0.98, 1.0, 0.92)
	_unit_class_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_unit_class_icon)

	_lbl_unit_name = _make_label("", Vector2(164, 520), HUD_FONT_SIZE_LARGE, Vector2(148, 18))
	_lbl_unit_level = _make_label("", Vector2(138, 540), HUD_FONT_SIZE_SMALL, Vector2(120, 16), LABEL_DIM)
	_lbl_unit_tier = _make_label("", Vector2(0, 0), HUD_FONT_SIZE_SMALL, Vector2.ZERO, LABEL_DIM)
	_lbl_unit_tier.visible = false

	_make_label("VIDA", Vector2(138, 568), 11, Vector2(42, 16), LABEL_DIM)
	_lbl_hp_value = _make_label("", Vector2(176, 566), HUD_FONT_SIZE, Vector2(72, 18), HP_ON)
	_make_label("MOV", Vector2(244, 568), 11, Vector2(34, 16), LABEL_DIM)
	_lbl_move_value = _make_label("", Vector2(272, 566), HUD_FONT_SIZE, Vector2(28, 18), LABEL_COLOR)
	_make_label("ALC", Vector2(306, 568), 11, Vector2(30, 16), LABEL_DIM)
	_lbl_range_value = _make_label("", Vector2(332, 566), HUD_FONT_SIZE, Vector2(24, 18), LABEL_COLOR)

	_make_label("EXPERIENCIA", Vector2(138, 628), 11, Vector2(100, 16), LABEL_DIM)
	_lbl_xp_value = _make_label("", Vector2(240, 626), HUD_FONT_SIZE, Vector2(90, 18), XP_ON)

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

	_melee_dice_container = Control.new()
	_melee_dice_container.position = Vector2(54, 660)
	_melee_dice_container.size = Vector2(84, 12)
	_melee_dice_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_melee_dice_container)

	_ranged_dice_container = Control.new()
	_ranged_dice_container.position = Vector2(54, 682)
	_ranged_dice_container.size = Vector2(84, 12)
	_ranged_dice_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_ranged_dice_container)

	_lbl_melee = _make_label("M", Vector2(32, 656), HUD_FONT_SIZE, Vector2(20, 18))
	_lbl_ranged = _make_label("R", Vector2(32, 680), HUD_FONT_SIZE, Vector2(20, 18))
	_lbl_advantage = _make_label("", Vector2(138, 658), HUD_FONT_SIZE_SMALL, Vector2(206, 18))
	_lbl_advantage_detail = _make_label("", Vector2(138, 676), 12, Vector2(206, 16), LABEL_DIM)
	_lbl_no_unit = _make_label("Selecciona una unidad", Vector2(138, 660), HUD_FONT_SIZE_SMALL, Vector2(200, 18), LABEL_DIM)

func _build_summon_button() -> void:
	_summon_glow = _make_button_glow(Vector2(386, 640), Vector2(126, 54))
	_btn_summon = _make_button("Invocar", Vector2(390, 640), Vector2(110, 50), HUD_FONT_SIZE)
	_btn_summon.position = Vector2(392, 646)
	_btn_summon.size = Vector2(118, 42)
	_btn_summon.tooltip_text = "Tecla: E"
	_btn_summon.mouse_filter = Control.MOUSE_FILTER_STOP
	_btn_summon.pressed.connect(func() -> void: emit_signal("summon_pressed"))
	_btn_summon.pressed.connect(AudioManager.play_button)
	_summon_flame = _make_button_flame(_btn_summon, SUMMON_READY_COLOR)
	_summon_motes = _make_button_motes(_btn_summon, SUMMON_READY_COLOR)

func _build_end_turn_button() -> void:
	_end_turn_glow = _make_button_glow(Vector2(1114, 640), Vector2(134, 60))
	_btn_end_turn = _make_button("Fin de turno", Vector2(1150, 648), Vector2(110, 44), HUD_FONT_SIZE)
	_btn_end_turn.position = Vector2(1120, 646)
	_btn_end_turn.size = Vector2(122, 48)
	_btn_end_turn.tooltip_text = "Tecla: Enter"
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

	_lbl_placement_title = _make_label("Invocacion", Vector2(84, 12), 12, Vector2(492, 14), LABEL_DIM, _placement_banner)
	_lbl_placement = _make_label("Elige una unidad y colocala en un hexagono vacio junto a tu Maestro.", Vector2(84, 30), 13, Vector2(482, 40), LABEL_COLOR, _placement_banner)
	_lbl_placement.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_placement.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

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
	_tutorial_panel.position = Vector2(370, 92)
	_tutorial_panel.size = Vector2(540, 108)
	_tutorial_panel.visible = false
	_tutorial_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_panel_style(_tutorial_panel, Color(0.08, 0.08, 0.10, 0.94))
	_root.add_child(_tutorial_panel)

	_lbl_tutorial_step = _make_label("", Vector2(16, 10), 11, Vector2(120, 14), LABEL_DIM, _tutorial_panel)
	_lbl_tutorial_title = _make_label("", Vector2(16, 28), HUD_FONT_SIZE_LARGE, Vector2(386, 20), LABEL_COLOR, _tutorial_panel)
	_lbl_tutorial_body = _make_label("", Vector2(16, 54), HUD_FONT_SIZE_SMALL, Vector2(386, 38), LABEL_DIM, _tutorial_panel)
	_lbl_tutorial_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_btn_tutorial_skip = _make_button("Saltar tutorial", Vector2(402, 30), Vector2(120, 36), HUD_FONT_SIZE_SMALL)
	_root.remove_child(_btn_tutorial_skip)
	_tutorial_panel.add_child(_btn_tutorial_skip)
	_btn_tutorial_skip.pressed.connect(func() -> void:
		emit_signal("tutorial_skip_pressed")
	)
	_btn_tutorial_skip.pressed.connect(AudioManager.play_button)

	_btn_tutorial_next = _make_button("Siguiente", Vector2(402, 68), Vector2(120, 28), HUD_FONT_SIZE_SMALL)
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

	_tutorial_resources_arrow = _make_tutorial_arrow("▲")
	_tutorial_overlay_root.add_child(_tutorial_resources_arrow)
	_tutorial_advantage_arrow = _make_tutorial_arrow("▲")
	_tutorial_overlay_root.add_child(_tutorial_advantage_arrow)
	_tutorial_minimap_arrow = _make_tutorial_arrow("▲")
	_tutorial_overlay_root.add_child(_tutorial_minimap_arrow)
	_tutorial_unit_panel_arrow = _make_tutorial_arrow()
	_tutorial_overlay_root.add_child(_tutorial_unit_panel_arrow)
	_tutorial_cards_arrow = _make_tutorial_arrow()
	_tutorial_overlay_root.add_child(_tutorial_cards_arrow)
	_tutorial_master_arrow = _make_tutorial_arrow()
	_tutorial_overlay_root.add_child(_tutorial_master_arrow)
	_tutorial_tower_arrow = _make_tutorial_arrow()
	_tutorial_overlay_root.add_child(_tutorial_tower_arrow)
	_tutorial_resources_outline = _make_tutorial_region_outline(Rect2(8, 8, 386, 44))
	_tutorial_advantage_outline = _make_tutorial_region_outline(Rect2(408, 8, 472, 44))
	_tutorial_minimap_outline = _make_tutorial_region_outline(Rect2(978, 8, 290, 182))
	_tutorial_unit_panel_outline = _make_tutorial_region_outline(Rect2(22, 506, 334, 188))

func _build_tutorial_info_panel() -> void:
	_tutorial_info_panel = Panel.new()
	_tutorial_info_panel.position = Vector2(300, 210)
	_tutorial_info_panel.size = Vector2(680, 280)
	_tutorial_info_panel.visible = false
	_tutorial_info_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_panel_style(_tutorial_info_panel, Color(0.06, 0.06, 0.09, 0.96))
	_root.add_child(_tutorial_info_panel)

	_lbl_tutorial_info_title = _make_label("Sistema de ventajas", Vector2(24, 20), 24, Vector2(632, 28), LABEL_COLOR, _tutorial_info_panel)

	_build_tutorial_advantage_diagram(_tutorial_info_panel)

	_lbl_tutorial_info_body = _make_label("", Vector2(212, 74), 18, Vector2(432, 134), LABEL_COLOR, _tutorial_info_panel)
	_lbl_tutorial_info_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_btn_tutorial_info_continue = _make_button("Entendido", Vector2(492, 226), Vector2(152, 36), HUD_FONT_SIZE_SMALL)
	_root.remove_child(_btn_tutorial_info_continue)
	_tutorial_info_panel.add_child(_btn_tutorial_info_continue)
	_btn_tutorial_info_continue.pressed.connect(func() -> void:
		emit_signal("tutorial_next_pressed")
	)
	_btn_tutorial_info_continue.pressed.connect(AudioManager.play_button)

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
	icon.tooltip_text = tooltip
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

	_lbl_cb_log = _make_label("", Vector2(10, 92), HUD_FONT_SIZE_SMALL, Vector2(200, 104), LABEL_DIM, _combat_panel)
	_lbl_cb_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_cb_log.vertical_alignment = VERTICAL_ALIGNMENT_TOP

	_lbl_cb_result = _make_label("", Vector2(10, 206), HUD_FONT_SIZE_SMALL, Vector2(200, 0), LABEL_COLOR, _combat_panel)
	_lbl_cb_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _build_pause_menu() -> void:
	_pause_overlay = ColorRect.new()
	_pause_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.color = Color(0.0, 0.0, 0.0, 0.58)
	_pause_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_overlay.visible = false
	add_child(_pause_overlay)

	_pause_panel = Panel.new()
	_pause_panel.position = Vector2(470, 180)
	_pause_panel.size = Vector2(340, 372)
	_pause_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_panel_style(_pause_panel, Color(0.06, 0.08, 0.12, 0.94))
	_pause_overlay.add_child(_pause_panel)

	var title := _make_label("OPCIONES", Vector2(0, 22), 24, Vector2(340, 24), SUMMON_READY_COLOR, _pause_panel)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var subtitle := _make_label("Ajustes de la partida actual", Vector2(0, 54), 11, Vector2(340, 16), LABEL_DIM, _pause_panel)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_btn_pause_resume = _make_button("Reanudar", Vector2(96, 92), Vector2(148, 38), HUD_FONT_SIZE)
	_root.remove_child(_btn_pause_resume)
	_pause_panel.add_child(_btn_pause_resume)
	_btn_pause_resume.pressed.connect(func() -> void:
		emit_signal("pause_resume_pressed")
	)
	_btn_pause_resume.pressed.connect(AudioManager.play_button)

	_btn_pause_save = _make_button("Guardar", Vector2(96, 138), Vector2(148, 38), HUD_FONT_SIZE)
	_root.remove_child(_btn_pause_save)
	_pause_panel.add_child(_btn_pause_save)
	_btn_pause_save.pressed.connect(func() -> void:
		emit_signal("pause_save_pressed")
	)
	_btn_pause_save.pressed.connect(AudioManager.play_button)

	_btn_pause_save_exit = _make_button("Guardar y salir", Vector2(96, 184), Vector2(148, 38), HUD_FONT_SIZE_SMALL)
	_root.remove_child(_btn_pause_save_exit)
	_pause_panel.add_child(_btn_pause_save_exit)
	_btn_pause_save_exit.pressed.connect(func() -> void:
		_open_pause_confirmation("save_exit", "Deseas guardar la partida y salir al menu principal?")
	)
	_btn_pause_save_exit.pressed.connect(AudioManager.play_button)

	_btn_pause_restart = _make_button("Reiniciar", Vector2(96, 230), Vector2(148, 38), HUD_FONT_SIZE)
	_root.remove_child(_btn_pause_restart)
	_pause_panel.add_child(_btn_pause_restart)
	_btn_pause_restart.pressed.connect(func() -> void:
		_open_pause_confirmation("restart", "Deseas reiniciar la partida?")
	)
	_btn_pause_restart.pressed.connect(AudioManager.play_button)

	_btn_pause_sound = _make_button("", Vector2(96, 276), Vector2(148, 38), HUD_FONT_SIZE)
	_root.remove_child(_btn_pause_sound)
	_pause_panel.add_child(_btn_pause_sound)
	_btn_pause_sound.pressed.connect(_on_pause_sound_pressed)

	_btn_pause_back_menu = _make_button("Volver al menu", Vector2(96, 322), Vector2(148, 38), HUD_FONT_SIZE_SMALL)
	_root.remove_child(_btn_pause_back_menu)
	_pause_panel.add_child(_btn_pause_back_menu)
	_btn_pause_back_menu.pressed.connect(func() -> void:
		_open_pause_confirmation("menu", "Deseas volver al menu principal?")
	)
	_btn_pause_back_menu.pressed.connect(AudioManager.play_button)

	_pause_confirm_panel = Panel.new()
	_pause_confirm_panel.position = Vector2(28, 84)
	_pause_confirm_panel.size = Vector2(284, 124)
	_pause_confirm_panel.visible = false
	_pause_confirm_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_panel_style(_pause_confirm_panel, Color(0.04, 0.05, 0.08, 0.97))
	_pause_panel.add_child(_pause_confirm_panel)

	_pause_confirm_label = _make_label("", Vector2(18, 18), 14, Vector2(248, 32), LABEL_COLOR, _pause_confirm_panel)
	_pause_confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pause_confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_btn_pause_confirm_yes = _make_button("Si", Vector2(34, 74), Vector2(92, 34), HUD_FONT_SIZE_SMALL)
	_root.remove_child(_btn_pause_confirm_yes)
	_pause_confirm_panel.add_child(_btn_pause_confirm_yes)
	_btn_pause_confirm_yes.pressed.connect(_confirm_pause_action)
	_btn_pause_confirm_yes.pressed.connect(AudioManager.play_button)

	_btn_pause_confirm_no = _make_button("No", Vector2(158, 74), Vector2(92, 34), HUD_FONT_SIZE_SMALL)
	_root.remove_child(_btn_pause_confirm_no)
	_pause_confirm_panel.add_child(_btn_pause_confirm_no)
	_btn_pause_confirm_no.pressed.connect(_close_pause_confirmation)
	_btn_pause_confirm_no.pressed.connect(AudioManager.play_button)

	_refresh_pause_sound_button()

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
		_close_pause_confirmation()
	if _btn_pause_menu != null:
		_btn_pause_menu.text = "Cerrar" if open else "Menu"

func is_pause_menu_open() -> bool:
	return _pause_overlay != null and _pause_overlay.visible

func set_sound_enabled(enabled: bool) -> void:
	_audio_enabled = enabled
	_refresh_pause_sound_button()

func _toggle_pause_menu() -> void:
	var open: bool = not is_pause_menu_open()
	set_pause_menu_open(open)
	emit_signal("pause_menu_toggled", open)

func _on_pause_sound_pressed() -> void:
	_audio_enabled = not _audio_enabled
	_refresh_pause_sound_button()
	emit_signal("pause_sound_toggled", _audio_enabled)
	if _audio_enabled:
		AudioManager.play_button()

func _refresh_pause_sound_button() -> void:
	if _btn_pause_sound == null:
		return
	_btn_pause_sound.text = "Sonido: ON" if _audio_enabled else "Sonido: OFF"

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

func update_turn(player_id: int) -> void:
	var turn_num: int = 1
	if turn_manager != null:
		turn_num = turn_manager.turn_number
	_lbl_turn_num.text = str(turn_num)
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

func get_essence_label_screen_position() -> Vector2:
	if _lbl_essence == null:
		return Vector2(244.0, 54.0)
	return _lbl_essence.global_position + Vector2(_lbl_essence.size.x * 0.5, _lbl_essence.size.y + 18.0)

func show_unit(unit: Unit) -> void:
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

	_lbl_unit_name.text = str(unit.get("unit_name"))
	var level: int = int(unit.get("level"))
	var level_color: Color = LEVEL_COLORS.get(level, LABEL_COLOR)
	_lbl_unit_name.add_theme_color_override("font_color", level_color)
	_lbl_unit_level.text = "NIVEL %d" % level
	_lbl_unit_level.add_theme_color_override("font_color", level_color)
	_unit_class_icon.modulate = level_color
	if _unit_level_bar != null:
		_unit_level_bar.color = level_color

	var hp: int = int(unit.get("hp"))
	var max_hp: int = int(unit.get("max_hp"))
	_lbl_hp_value.text = "%d/%d" % [hp, max_hp]
	_lbl_move_value.text = str(int(unit.get("move_range")))
	_lbl_range_value.text = str(int(unit.get("attack_range")))
	_update_segment_row(_hp_segments, hp, max_hp, HP_ON, HP_OFF)

	var experience: int = int(unit.get("experience"))
	var exp_required: int = int(unit.call("get_exp_required"))
	_lbl_xp_value.text = "%d/%d" % [experience, exp_required]
	_update_segment_row(_xp_segments, experience, exp_required, XP_ON, XP_OFF)

	var melee_dice: Array = unit.call("get_melee_dice")
	var ranged_dice: Array = unit.call("get_ranged_dice")
	_rebuild_dice_row(_melee_dice_container, melee_dice)
	_rebuild_dice_row(_ranged_dice_container, ranged_dice)

	var atk_alpha: float = 0.30 if bool(unit.get("has_attacked")) else 1.0
	_lbl_melee.modulate.a             = atk_alpha
	_lbl_ranged.modulate.a            = atk_alpha
	_melee_dice_container.modulate.a  = atk_alpha
	_ranged_dice_container.modulate.a = atk_alpha

	_redraw_minimap(unit)
	refresh_advantage()
	_refresh_action_button_glow()

func hide_unit() -> void:
	_portrait.texture = null
	_portrait_bg.texture = null
	_unit_class_icon.texture = null
	_unit_class_icon.modulate = Color(0.96, 0.98, 1.0, 0.92)
	if _unit_accent_line != null:
		_unit_accent_line.color = UNIT_PANEL_NEUTRAL
	if _unit_level_bar != null:
		_unit_level_bar.color = UNIT_PANEL_NEUTRAL
	_lbl_unit_name.text = ""
	_lbl_unit_name.add_theme_color_override("font_color", LABEL_COLOR)
	_lbl_unit_level.text = ""
	_lbl_unit_level.add_theme_color_override("font_color", LABEL_DIM)
	_lbl_hp_value.text = ""
	_lbl_xp_value.text = ""
	_lbl_move_value.text = ""
	_lbl_range_value.text = ""
	_lbl_no_unit.visible = true
	hide_advantage()
	_update_segment_row(_hp_segments, 0, 0, HP_ON, HP_OFF)
	_update_segment_row(_xp_segments, 0, 0, XP_ON, XP_OFF)
	_rebuild_dice_row(_melee_dice_container, [])
	_rebuild_dice_row(_ranged_dice_container, [])
	_lbl_melee.modulate.a             = 1.0
	_lbl_ranged.modulate.a            = 1.0
	_melee_dice_container.modulate.a  = 1.0
	_ranged_dice_container.modulate.a = 1.0
	_redraw_minimap()
	refresh_advantage()
	_refresh_action_button_glow()

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
		_lbl_advantage.text = "VENTAJA x%.2f" % multiplier
		_lbl_advantage.add_theme_color_override("font_color", Color(0.32, 1.0, 0.40, 1.0))
	elif multiplier < 1.0:
		_lbl_advantage.text = "DESVENTAJA x%.2f" % multiplier
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
		_lbl_advantage_detail.text = "ATQ x%.2f | RESP x%.2f" % [atk_mult, def_mult]

func hide_advantage() -> void:
	_lbl_advantage.text = ""
	if _lbl_advantage_detail != null:
		_lbl_advantage_detail.text = ""

func show_placement_hint(message: String = "Modo invocacion: elige un hexagono vacio junto a tu Maestro", unit_type: int = -999) -> void:
	if _lbl_placement_title != null:
		_lbl_placement_title.text = "Invocacion"
	if _placement_hint_icon != null:
		var icon_path: String = PLACEMENT_ADVANTAGE_ICON_PATH
		if CLASS_ICON_PATHS.has(unit_type):
			icon_path = str(CLASS_ICON_PATHS.get(unit_type, PLACEMENT_ADVANTAGE_ICON_PATH))
		_placement_hint_icon.texture = load(icon_path)
	if _lbl_placement != null:
		_lbl_placement.text = message
	_placement_banner.visible = true
	_refresh_action_button_glow()

func hide_placement_hint() -> void:
	if _lbl_placement_title != null:
		_lbl_placement_title.text = "Invocacion"
	if _placement_hint_icon != null:
		_placement_hint_icon.texture = load(PLACEMENT_ADVANTAGE_ICON_PATH)
	if _lbl_placement != null:
		_lbl_placement.text = "Elige una unidad y colocala en un hexagono vacio junto a tu Maestro."
	_placement_banner.visible = false
	_refresh_action_button_glow()

func show_cell_context(cell: Vector2i) -> void:
	if _cell_context_panel == null or hex_grid == null:
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
	_lbl_tutorial_title.text = title
	_lbl_tutorial_body.text = body
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
	if _lbl_tutorial_info_body != null:
		var body: String = "Invocaste un %s.\n\n%s\n\nUsa este esquema para recordar que cada unidad tiene un objetivo favorable." % [unit_name, counter_hint]
		_lbl_tutorial_info_body.text = body
	_tutorial_info_panel.visible = true

func hide_tutorial_info() -> void:
	if _tutorial_info_panel == null:
		return
	_tutorial_info_panel.visible = false

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

func _make_tutorial_arrow(symbol: String = "▼") -> Label:
	var lbl := Label.new()
	lbl.text = symbol
	lbl.visible = false
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", 34)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.28, 0.96))
	lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.82))
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.size = Vector2(48.0, 40.0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.z_index = 20
	return lbl

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
			focus_rect = Rect2(8, 8, 386, 44)
		"advantage":
			focus_rect = Rect2(408, 8, 472, 44)
		"minimap":
			focus_rect = Rect2(978, 8, 290, 182)
		"unit_panel":
			focus_rect = Rect2(22, 506, 334, 188)
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
	if not show_spotlight:
		return
	_tutorial_spotlight_mat.set_shader_parameter("hole_a", Vector4(panel_rect.position.x, panel_rect.position.y, panel_rect.size.x, panel_rect.size.y))
	_tutorial_spotlight_mat.set_shader_parameter("hole_b", Vector4(focus_rect.position.x, focus_rect.position.y, focus_rect.size.x, focus_rect.size.y))

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
		_tutorial_resources_arrow.position = Vector2(177.0, 48.0 + bob)
	if _tutorial_advantage_arrow != null and _tutorial_advantage_arrow.visible:
		_tutorial_advantage_arrow.position = Vector2(620.0, 48.0 + bob)
	if _tutorial_minimap_arrow != null and _tutorial_minimap_arrow.visible:
		_tutorial_minimap_arrow.position = Vector2(1098.0, 188.0 + bob)
	if _tutorial_unit_panel_arrow != null and _tutorial_unit_panel_arrow.visible:
		_tutorial_unit_panel_arrow.position = Vector2(164.0, 500.0 + bob)
	if _tutorial_cards_arrow != null and _tutorial_cards_arrow.visible:
		_tutorial_cards_arrow.position = Vector2(662.0, 516.0 + bob)
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
		"def_name": defender.unit_name,
		"def_hp": defender.hp,
		"def_max_hp": defender.max_hp,
		"def_owner": defender.owner_id,
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
		mult_tag = " x%.2f" % multiplier
	elif multiplier < 1.0:
		mult_tag = " x%.2f" % multiplier

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
	var parts: Array[String] = []
	for roll: Dictionary in rolls:
		var color_idx: int = clampi(roll.get("color", 0), 0, DICE_NAMES.size() - 1)
		parts.append("%s:%d" % [DICE_NAMES[color_idx], roll.get("value", 0)])
	var multiplier_text := ""
	if multiplier != 1.0:
		multiplier_text = " x%.2f" % multiplier
	return "%s %s -> %d%s -> %d" % [unit_name, " ".join(parts), total, multiplier_text, damage]
