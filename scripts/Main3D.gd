extends Node3D

const HexGrid3DScript       := preload("res://scripts/HexGrid3D.gd")
const TurnManagerScript     := preload("res://scripts/TurnManager.gd")
const CombatManagerScript   := preload("res://scripts/CombatManager.gd")
const ResourceManagerScript := preload("res://scripts/ResourceManager.gd")
const SummonManagerScript   := preload("res://scripts/SummonManager.gd")
const MapGeneratorScript    := preload("res://scripts/MapGenerator.gd")
const UnitScript            := preload("res://scripts/Unit.gd")
const HUDScene              := preload("res://scenes/HUD.tscn")
const CardHandScene         := preload("res://scenes/CardHand.tscn")
const SummonMenuScene       := preload("res://scenes/SummonMenu.tscn")
const LevelUpMenuScene      := preload("res://scenes/LevelUpMenu.tscn")
const SimpleAIScript        := preload("res://scripts/SimpleAI.gd")
const CombatBalanceDebugScript := preload("res://scripts/CombatBalanceDebug.gd")
const CardBalanceDebugScript := preload("res://scripts/CardBalanceDebug.gd")
const StarsDomeShader       := preload("res://shaders/stars_dome.gdshader")

# --- Untyped all game systems are accessed via dynamic dispatch, same as Main.gd ---
var hex_grid         = null
var turn_manager     = null
var resource_manager = null
var summon_manager   = null
var hud              = null
var card_hand        = null
var summon_menu      = null
var ai_controller    = null
var level_up_menu    = null
var camera: Camera3D = null
var _sun_light: DirectionalLight3D = null
var _fill_light: DirectionalLight3D = null
var _cloud_cookie_light: SpotLight3D = null
var _cloud_cookie_center: Vector3 = Vector3.ZERO
var _cloud_cookie_drift_radius: Vector2 = Vector2(5.0, 4.0)
var _cloud_cookie_time: float = 0.0
var _world_environment: WorldEnvironment = null
var _sky_material: ProceduralSkyMaterial = null
var _vignette_material: ShaderMaterial = null
var _stars_material: ShaderMaterial = null
var _night_motes: Node3D = null
var _ambient_motes: GPUParticles3D = null
var _firefly_data: Array = []
var _firefly_strength: float = 0.0
var _firefly_time: float = 0.0
var _lighting_tween: Tween = null
var _combat_theater_tween: Tween = null
var _current_is_night: Variant = null
var _ambient_cycle_timer: float = 0.0
var _combat_restore_profile: Dictionary = {}
var _hovered_hud_unit: Unit = null
var _combat_balance_debug: CombatBalanceDebug = null
var _card_balance_debug: CardBalanceDebug = null
var _tutorial_active: bool = false
var _tutorial_step: int = -1
var _tutorial_waiting_for_summon_explanation: bool = false
var _tutorial_last_placed_cell: Vector2i = Vector2i(-1, -1)
var _tutorial_card_target_mode_active: bool = false
var _game_speed_scale: float = 1.0
var _card_vfx_preplayed: bool = false
var _victory_transition_overlay: Control = null
var _victory_transition_label: Label = null
var _victory_transition_subtitle: Label = null
var _victory_transition_continue_button: Button = null
var _victory_transition_active: bool = false
var _victory_transition_center: Vector3 = Vector3.ZERO
var _victory_transition_angle: float = 0.0
var _victory_transition_radius: float = 18.0
var _victory_transition_height: float = 14.0
var _victory_transition_focus_height: float = 2.8
const _TUTORIAL_STEPS_CHAPTER_1: Array[String] = [
	"hud_resources",
	"hud_turn",
	"hud_advantage",
	"victory_goal",
	"hud_minimap",
	"hud_unit_panel",
	"dice_basics",
	"hud_cards",
	"select_master",
	"capture_tower",
	"open_summon",
	"summon_unit",
	"end_turn",
	"combat_response",
	"attack_enemy",
	"combat_panel",
	"exp_and_blessings",
]
const _TUTORIAL_STEPS_CHAPTER_2: Array[String] = [
	"open_summon",
	"summon_unit",
	"terrain_bonus",
	"attack_enemy",
]
const _TUTORIAL_STEPS_CHAPTER_3: Array[String] = [
	"hud_cards",
	"play_card",
	"card_reason",
	"attack_enemy",
	"blessing_result",
	"combat_takeaway",
]

# --- Game stats (collected for GameOver screen) ---
var _summoned_by_player: Dictionary = {}
var _towers_by_player: Dictionary = {}
var _cards_used_by_player: Dictionary = {}
var _kills_by_player: Dictionary = {}
var _timeline_snapshots: Array = []
var _next_summon_is_free: bool = false
var _master_summoning: bool = false
var _master_for_free_summon: Unit = null

# --- Master free-summon tracking ---
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	get_tree().paused = false
	_apply_game_speed(1.0)
	GameData.load_meta()
	for player_id: int in GameData.get_player_ids():
		_summoned_by_player[player_id] = 0
		_towers_by_player[player_id] = 0
		_cards_used_by_player[player_id] = 0
		_kills_by_player[player_id] = 0
	# --- Generate map ---
	if GameData.map_terrain.size() == 0:
		_generate_map()

	# --- Combat manager (RefCounted not a node) ---
	var combat_manager: RefCounted = CombatManagerScript.new()

	# --- Resource manager ---
	resource_manager      = ResourceManagerScript.new()
	resource_manager.name = "ResourceManager"
	add_child(resource_manager)
	resource_manager.setup_players(GameData.player_count)
	CardManager.resource_manager = resource_manager
	CardManager.setup_deck()

	# --- Hex grid ---
	hex_grid                  = HexGrid3DScript.new()
	hex_grid.name             = "HexGrid3D"
	hex_grid.combat_manager   = combat_manager
	hex_grid.resource_manager = resource_manager
	add_child(hex_grid)
	CardManager.hex_grid = hex_grid

	resource_manager.hex_grid = hex_grid   # cross-link after both in tree

	# --- Turn manager ---
	turn_manager                  = TurnManagerScript.new()
	turn_manager.name             = "TurnManager"
	turn_manager.hex_grid         = hex_grid
	turn_manager.resource_manager = resource_manager
	add_child(turn_manager)

	# --- Summon manager ---
	summon_manager                  = SummonManagerScript.new()
	summon_manager.name             = "SummonManager"
	summon_manager.hex_grid         = hex_grid
	summon_manager.resource_manager = resource_manager
	add_child(summon_manager)

	# --- HUD ---
	hud                  = HUDScene.instantiate()
	hud.turn_manager     = turn_manager
	hud.resource_manager = resource_manager
	hud.hex_grid         = hex_grid
	add_child(hud)

	card_hand = CardHandScene.instantiate()
	card_hand.turn_manager = turn_manager
	card_hand.hex_grid = hex_grid
	add_child(card_hand)
	if card_hand.has_signal("tutorial_card_target_mode_changed"):
		card_hand.tutorial_card_target_mode_changed.connect(_on_tutorial_card_target_mode_changed)

	# --- Summon menu ---
	summon_menu = SummonMenuScene.instantiate()
	add_child(summon_menu)

	# --- Level-up bonus menu ---
	level_up_menu = LevelUpMenuScene.instantiate()
	level_up_menu.set("hex_grid", hex_grid)
	level_up_menu.set("hud_ref", hud)
	level_up_menu.set("card_hand_ref", card_hand)
	add_child(level_up_menu)
	BonusSystem.level_up_menu = level_up_menu

	ai_controller = SimpleAIScript.new()
	ai_controller.hex_grid = hex_grid
	ai_controller.resource_manager = resource_manager
	ai_controller.summon_manager = summon_manager
	ai_controller.hud = hud
	add_child(ai_controller)

	_combat_balance_debug = CombatBalanceDebugScript.new()
	_card_balance_debug = CardBalanceDebugScript.new()

	# --- Signal wiring ---
	hud.end_turn_pressed.connect(_on_end_turn_pressed)
	hud.summon_pressed.connect(_open_summon_menu)
	hud.pause_menu_toggled.connect(_set_pause_state)
	hud.pause_resume_pressed.connect(_on_pause_resume_pressed)
	hud.pause_save_pressed.connect(_on_pause_save_pressed)
	hud.pause_save_and_exit_pressed.connect(_on_pause_save_and_exit_pressed)
	hud.pause_restart_pressed.connect(_on_pause_restart_pressed)
	hud.pause_back_to_menu_pressed.connect(_on_pause_back_to_menu_pressed)
	hud.pause_sound_toggled.connect(_on_pause_sound_toggled)
	hud.game_speed_selected.connect(_on_game_speed_selected)
	hud.tutorial_next_pressed.connect(_on_tutorial_next_pressed)

	summon_menu.unit_type_chosen.connect(_on_unit_type_chosen)
	summon_menu.cancelled.connect(_on_summon_cancelled)
	summon_manager.summon_completed.connect(_on_summon_completed)

	hex_grid.unit_selected.connect(hud.show_unit)
	hex_grid.unit_selected.connect(_on_unit_selected_refresh_preview)
	hex_grid.unit_selected.connect(_on_unit_selected_for_tutorial)
	hex_grid.unit_deselected.connect(hud.hide_unit)
	hex_grid.unit_hovered.connect(_on_unit_hovered)
	hex_grid.unit_hover_cleared.connect(_on_unit_hover_cleared)
	hex_grid.cell_hovered.connect(_on_cell_hovered)
	hex_grid.cell_hover_cleared.connect(_on_cell_hover_cleared)
	hex_grid.enemy_inspected.connect(_on_enemy_inspected)
	hex_grid.combat_resolved.connect(_on_combat_resolved)
	hex_grid.card_target_selected.connect(_on_card_target_selected)
	hex_grid.card_tower_selected.connect(_on_card_tower_selected)
	hex_grid.tower_captured.connect(_on_tower_captured)
	hex_grid.placement_confirmed.connect(_on_placement_confirmed)
	hex_grid.master_killed.connect(turn_manager.handle_master_killed)
	turn_manager.turn_changed.connect(_on_turn_changed)
	turn_manager.game_over.connect(_on_game_over)
	resource_manager.resources_changed.connect(hud.update_essence)
	CardManager.card_played.connect(_on_card_played)
	CardManager.card_resolved.connect(_on_card_resolved)
	CardManager.unit_killed_by_card.connect(_on_unit_killed_by_card)
	CardManager.free_summon_requested.connect(_on_free_summon_requested)
	CardManager.revive_requested.connect(_on_revive_requested)

	hud.refresh_towers()
	hud.set_sound_enabled(not MusicManager.is_muted() and not AudioManager.is_muted())

	# --- Lighting ---
	_setup_lighting()

	# --- Camera ---
	camera     = $Camera3D
	camera.fov = 85.0

	var center:  Vector3 = hex_grid.get_map_center()
	var map_max: Vector3 = hex_grid.hex_to_world(hex_grid.COLS - 1, hex_grid.ROWS - 1)

	camera.rotation_degrees = Vector3(-55.0, 0.0, 0.0)
	camera.position         = Vector3(center.x, 18.0, center.z)
	camera._target_pos      = Vector3(center.x, 0.0, center.z)
	camera._target_zoom     = 18.0
	camera.set_map_bounds(
			Vector3(-3.0, 0.0, -3.0),
			Vector3(map_max.x + 3.0, 0.0, map_max.z + 3.0))
	camera.focus_on(center, 18.0)
	if level_up_menu != null:
		level_up_menu.set("camera_controller", camera)

	# --- Place initial units (masters) ---
	var units_node: Node3D = $Units
	hex_grid.units_container = units_node
	if _has_saved_match_state():
		_restore_saved_game()
	else:
		hex_grid.setup_units()
		_setup_tutorial_scenario()
		CardManager.draw_card(turn_manager.current_player)
	if _world_environment != null:
		_apply_unit_time_lighting(_capture_lighting_profile())
	if _has_saved_match_state():
		_on_turn_changed(turn_manager.current_player)
	else:
		_play_intro_camera_sequence()
		_start_tutorial_if_needed()
	_record_timeline_snapshot(turn_manager.turn_number if turn_manager != null else 1)

	MusicManager.play_battle_music(turn_manager.current_player if turn_manager != null else 1)
	GameData.call_deferred("apply_selected_theme", get_window())
	print("[Main3D] Mapa 3D listo — WASD/Flechas: mover | Rueda: zoom | Clic derecho: rotar")
	print("[Main3D] Enter: fin de turno | E: invocar | Esc: cancelar")
	print("[Main3D] Esencia inicial — J1: %d  |  J2: %d" % [
			resource_manager.get_essence(1), resource_manager.get_essence(2)])

func _exit_tree() -> void:
	Engine.time_scale = 1.0

# --- Map generation ---
func _generate_map() -> void:
	if GameData.tutorial_mode_active:
		if _apply_tutorial_map():
			return
	var gen:       RefCounted    = MapGeneratorScript.new()
	var map_types: Array[String] = ["plains", "sierras", "precordillera"]
	var map_type:  String        = map_types[GameData.current_map]
	var seed_val:  int           = GameData.map_seed if GameData.map_seed > 0 else randi()
	gen.generate(seed_val, map_type, GameData.map_size)
	GameData.map_terrain         = gen.get_terrain()
	GameData.map_tower_positions = gen.get_tower_positions()
	GameData.map_tower_incomes   = gen.get_tower_incomes()
	GameData.map_master_p1       = gen.get_master_p1_cell()
	GameData.map_master_p2       = gen.get_master_p2_cell()
	GameData.map_master_p3       = gen.get_master_p3_cell()
	GameData.map_master_p4       = gen.get_master_p4_cell()
	GameData.map_seed            = gen.get_seed()
	print("[Main3D] Mapa generado: tipo=%s semilla=%d | Maestro J1=%s J2=%s J3=%s J4=%s" % [
			map_type, GameData.map_seed,
			str(GameData.map_master_p1), str(GameData.map_master_p2),
			str(GameData.map_master_p3), str(GameData.map_master_p4)])

func _apply_tutorial_map() -> bool:
	match GameData.tutorial_chapter_id:
		"chapter_1":
			_apply_tutorial_chapter_1_map()
			return true
		"chapter_2":
			_apply_tutorial_chapter_2_map()
			return true
		"chapter_3":
			_apply_tutorial_chapter_3_map()
			return true
		_:
			return false

func _apply_tutorial_chapter_1_map() -> void:
	GameData.current_map = 0
	GameData.map_seed = 14026
	GameData.map_size = Vector2i(10, 8)
	GameData.map_terrain = [
		[0, 0, 0, 0, 3, 3, 0, 0, 0, 0],
		[0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
		[0, 0, 3, 0, 0, 0, 0, 3, 0, 0],
		[0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
		[0, 0, 0, 0, 0, 1, 0, 0, 0, 0],
		[0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
		[0, 0, 3, 0, 0, 0, 0, 3, 0, 0],
		[0, 0, 0, 0, 2, 2, 0, 0, 0, 0],
	]
	GameData.map_tower_positions = [
		Vector2i(3, 4),
		Vector2i(5, 3),
		Vector2i(7, 3),
	]
	GameData.map_tower_incomes = [2, 2, 2]
	GameData.map_master_p1 = Vector2i(2, 4)
	GameData.map_master_p2 = Vector2i(8, 3)
	GameData.map_master_p3 = Vector2i(-1, -1)
	GameData.map_master_p4 = Vector2i(-1, -1)
	print("[Main3D] Cargado mapa tutorial %s." % GameData.tutorial_chapter_id)

func _apply_tutorial_chapter_2_map() -> void:
	GameData.current_map = 0
	GameData.map_seed = 24012
	GameData.map_size = Vector2i(8, 6)
	GameData.map_terrain = [
		[0, 0, 0, 0, 0, 0, 0, 0],
		[0, 3, 0, 0, 0, 0, 3, 0],
		[0, 0, 0, 0, 0, 0, 0, 0],
		[0, 0, 0, 3, 0, 0, 0, 0],
		[0, 3, 0, 0, 0, 0, 3, 0],
		[0, 0, 0, 0, 4, 4, 0, 0],
	]
	GameData.map_tower_positions = []
	GameData.map_tower_incomes = []
	GameData.map_master_p1 = Vector2i(2, 3)
	GameData.map_master_p2 = Vector2i(6, 2)
	GameData.map_master_p3 = Vector2i(-1, -1)
	GameData.map_master_p4 = Vector2i(-1, -1)
	print("[Main3D] Cargado mapa tutorial %s." % GameData.tutorial_chapter_id)

func _apply_tutorial_chapter_3_map() -> void:
	GameData.current_map = 0
	GameData.map_seed = 34018
	GameData.map_size = Vector2i(8, 6)
	GameData.map_terrain = [
		[0, 0, 0, 0, 0, 0, 0, 0],
		[0, 3, 0, 0, 0, 0, 3, 0],
		[0, 0, 0, 2, 2, 0, 0, 0],
		[0, 0, 0, 0, 0, 0, 0, 0],
		[0, 3, 0, 0, 0, 0, 3, 0],
		[0, 0, 0, 0, 0, 0, 0, 0],
	]
	GameData.map_tower_positions = []
	GameData.map_tower_incomes = []
	GameData.map_master_p1 = Vector2i(1, 3)
	GameData.map_master_p2 = Vector2i(6, 2)
	GameData.map_master_p3 = Vector2i(-1, -1)
	GameData.map_master_p4 = Vector2i(-1, -1)
	print("[Main3D] Cargado mapa tutorial %s." % GameData.tutorial_chapter_id)

func _setup_tutorial_scenario() -> void:
	if not GameData.tutorial_mode_active or hex_grid == null:
		return
	match GameData.tutorial_chapter_id:
		"chapter_1":
			if resource_manager != null:
				resource_manager.add_essence(2, 2)
		"chapter_2":
			if resource_manager != null:
				resource_manager.add_essence(1, 4)
			var rider := UnitScript.new()
			rider.setup("Rider", UnitScript.UnitType.RIDER, 2, 1)
			hex_grid.place_unit(rider, 4, 3, false)
			hex_grid.queue_redraw()
		"chapter_3":
			var warrior := UnitScript.new()
			warrior.setup("Warrior", UnitScript.UnitType.WARRIOR, 1, 1)
			warrior.hp = 6
			warrior.experience = 15
			hex_grid.place_unit(warrior, 3, 3, false)

			var lancer := UnitScript.new()
			lancer.setup("Lancer", UnitScript.UnitType.LANCER, 2, 1)
			lancer.hp = 2
			hex_grid.place_unit(lancer, 4, 3, false)

			CardManager.hands[1] = []
			CardManager.deck = [{
				"type": "heal",
				"value": 4,
				"color": "teal",
				"allowed_player_ids": [1],
			}]
			CardManager.used_card_this_turn = false
			hex_grid.queue_redraw()

# --- Input ---
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if level_up_menu != null and level_up_menu.visible:
		return
	if get_tree().paused:
		if event.keycode == KEY_ESCAPE and hud != null and hud.has_method("is_pause_menu_open") and hud.call("is_pause_menu_open"):
			_on_pause_resume_pressed()
		elif event.keycode == KEY_F5:
			_regenerate_current_map()
		return
	if turn_manager != null and GameData.get_player_mode(turn_manager.current_player) == "ai":
		return
	match event.keycode:
		KEY_F5:
			_regenerate_current_map()
		KEY_ENTER, KEY_KP_ENTER:
			_on_end_turn_pressed()
		KEY_E:
			_open_summon_menu()
		KEY_F9:
			if _combat_balance_debug != null:
				_combat_balance_debug.print_balance_report()
		KEY_F10:
			if _card_balance_debug != null:
				_card_balance_debug.print_deck_report()
		KEY_ESCAPE:
			if summon_menu != null and summon_menu.visible:
				summon_menu.visible = false
			elif hex_grid != null:
				hex_grid.exit_placement_mode()
				hex_grid.exit_card_target_mode()
				hex_grid.deselect()
			_set_pause_state(true)

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	if _victory_transition_active:
		_update_victory_transition_camera(delta)
	_cloud_cookie_time += delta
	_update_cloud_cookie_light()
	_update_fake_godrays(delta)
	_update_day_night_ambient(delta)
	if _tutorial_active and GameData.tutorial_chapter_id == "chapter_1" and _get_current_tutorial_key() == "attack_enemy":
		_update_tutorial_focus_visuals()
	if _night_motes == null or _firefly_data.is_empty():
		return
	_firefly_time += delta
	for firefly: Dictionary in _firefly_data:
		var node: MeshInstance3D = firefly["node"] as MeshInstance3D
		var mat: StandardMaterial3D = firefly["material"] as StandardMaterial3D
		if node == null or mat == null:
			continue

		var phase: float = float(firefly["phase"])
		var speed: float = float(firefly["speed"])
		var bob_amp: float = float(firefly["bob_amp"])
		var drift_amp: float = float(firefly["drift_amp"])
		var base_pos: Vector3 = firefly["base_pos"] as Vector3
		var blink: float = 0.5 + 0.5 * sin(_firefly_time * speed + phase)
		var flash: float = smoothstep(0.78, 0.96, blink) * _firefly_strength
		var hover_x: float = sin(_firefly_time * speed * 0.42 + phase * 1.7) * drift_amp
		var hover_z: float = cos(_firefly_time * speed * 0.35 + phase * 1.2) * drift_amp
		var hover_y: float = sin(_firefly_time * speed * 0.75 + phase) * bob_amp

		node.position = base_pos + Vector3(hover_x, hover_y, hover_z)
		node.visible = flash > 0.04
		node.scale = Vector3.ONE * (0.85 + flash * 0.45)
		mat.albedo_color = Color(0.36, 1.0, 0.10, flash)
		mat.emission_energy_multiplier = flash * 12.0

func set_combat_cinematic_ui(active: bool, focus_cells: Array = []) -> void:
	if hud != null and hud.has_method("set_combat_cinematic"):
		hud.call("set_combat_cinematic", active)
	if card_hand != null:
		var card_hand_root: CanvasItem = card_hand.get("_root") as CanvasItem
		if card_hand_root != null:
			create_tween().tween_property(card_hand_root, "modulate:a", 0.0 if active else 1.0, 0.20) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if hex_grid != null and hex_grid.has_method("set_combat_board_theater"):
		hex_grid.call("set_combat_board_theater", active, focus_cells)
	_set_combat_theater_lighting(active)

func _set_combat_theater_lighting(active: bool) -> void:
	if _sun_light == null or _fill_light == null or _world_environment == null or _sky_material == null:
		return
	if _combat_theater_tween != null:
		_combat_theater_tween.kill()
	var from_profile: Dictionary = _capture_lighting_profile()
	var to_profile: Dictionary
	if active:
		_combat_restore_profile = from_profile.duplicate(true)
		to_profile = from_profile.duplicate(true)
		to_profile["sun_energy"] = float(from_profile.get("sun_energy", 1.0)) * 0.72
		to_profile["fill_energy"] = float(from_profile.get("fill_energy", 0.2)) * 0.55
		to_profile["ambient_light_energy"] = float(from_profile.get("ambient_light_energy", 0.5)) * 0.74
		to_profile["tonemap_exposure"] = float(from_profile.get("tonemap_exposure", 1.0)) * 0.96
		to_profile["adjustment_brightness"] = float(from_profile.get("adjustment_brightness", 1.0)) * 0.95
		to_profile["fog_density"] = float(from_profile.get("fog_density", 0.003)) * 1.08
		to_profile["vignette_strength"] = minf(0.92, float(from_profile.get("vignette_strength", 0.65)) + 0.12)
		to_profile["cloud_cookie_energy"] = float(from_profile.get("cloud_cookie_energy", 0.45)) * 1.10
	else:
		to_profile = _combat_restore_profile.duplicate(true) if not _combat_restore_profile.is_empty() else from_profile.duplicate(true)
	_combat_theater_tween = create_tween()
	_combat_theater_tween.tween_method(
		func(weight: float) -> void:
			_apply_lighting_profile(_lerp_lighting_profile(from_profile, to_profile, weight)),
		0.0, 1.0, 0.28
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _set_pause_state(paused: bool) -> void:
	if paused:
		if summon_menu != null:
			summon_menu.visible = false
		_clear_transient_board_state(true)
	if hud != null and hud.has_method("set_pause_menu_open"):
		hud.call("set_pause_menu_open", paused)
	# Hide cards while the pause menu is open so they don't overlap the panel
	if card_hand != null:
		if paused:
			card_hand.hide()
		else:
			card_hand.show()
	get_tree().paused = paused

func _clear_transient_board_state(reset_camera: bool = false) -> void:
	if hex_grid != null:
		hex_grid.exit_placement_mode()
		hex_grid.exit_card_target_mode()
		hex_grid.deselect()
		if hex_grid.has_method("hide_combat_stage"):
			hex_grid.call("hide_combat_stage", true)
	set_combat_cinematic_ui(false, [])
	if reset_camera and camera != null and camera.has_method("force_reset_combat_state"):
		camera.call("force_reset_combat_state")

func _on_pause_resume_pressed() -> void:
	_set_pause_state(false)

func _on_pause_save_pressed() -> void:
	_save_current_game()

func _on_pause_save_and_exit_pressed() -> void:
	_save_current_game()
	_set_pause_state(false)
	get_tree().change_scene_to_file("res://scenes/TitleScreen.tscn")

func _on_pause_restart_pressed() -> void:
	_set_pause_state(false)
	GameData.clear_loaded_match_cache()
	get_tree().reload_current_scene()

func _regenerate_current_map() -> void:
	_set_pause_state(false)
	GameData.clear_loaded_match_cache()
	GameData.map_seed = 0
	GameData.map_terrain = []
	GameData.map_tower_positions = []
	GameData.map_tower_incomes = []
	GameData.turns_played = 0
	GameData.winner_id = 0
	get_tree().reload_current_scene()

func _on_pause_back_to_menu_pressed() -> void:
	_set_pause_state(false)
	get_tree().change_scene_to_file("res://scenes/TitleScreen.tscn")

func _on_pause_sound_toggled(enabled: bool) -> void:
	MusicManager.set_muted(not enabled)
	AudioManager.set_muted(not enabled)

func _on_game_speed_selected(scale: float) -> void:
	_apply_game_speed(scale)

func _apply_game_speed(scale: float) -> void:
	_game_speed_scale = clampf(scale, 1.0, 3.0)
	Engine.time_scale = _game_speed_scale
	if hud != null and hud.has_method("set_game_speed_buttons"):
		hud.call("set_game_speed_buttons", _game_speed_scale)

# --- Lighting setup ---
func _setup_lighting() -> void:
	# --- Sun (key light) ---
	_sun_light = DirectionalLight3D.new()
	_sun_light.shadow_enabled                  = true
	_sun_light.directional_shadow_mode         = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	_sun_light.directional_shadow_blend_splits = true
	_sun_light.shadow_opacity                  = 0.78
	_sun_light.shadow_bias                     = 0.03
	_sun_light.shadow_normal_bias              = 1.1
	add_child(_sun_light)

	# --- Fill light (sky bounce) ---
	_fill_light = DirectionalLight3D.new()
	_fill_light.shadow_enabled   = false
	add_child(_fill_light)

	_setup_cloud_cookie_light()

	# --- World environment ---
	var env: Environment = Environment.new()

	_sky_material = ProceduralSkyMaterial.new()
	_sky_material.use_debanding = true

	var sky := Sky.new()
	sky.sky_material = _sky_material

	env.background_mode  = Environment.BG_SKY
	env.sky = sky
	env.glow_enabled = true
	env.glow_intensity = 0.72
	env.glow_strength = 0.58
	env.glow_mix = 0.12
	env.glow_bloom = 0.07
	env.glow_hdr_threshold = 1.05
	env.set_glow_level(0, 0.0)
	env.set_glow_level(1, 0.0)
	env.set_glow_level(2, 0.12)
	env.set_glow_level(3, 0.26)
	env.set_glow_level(4, 0.22)
	env.set_glow_level(5, 0.14)
	env.set_glow_level(6, 0.06)

	# --- Warm amber ambient #fff5e0 (1.00, 0.96, 0.88) ---
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color  = Color(0.86, 0.56, 0.46)
	env.ambient_light_energy = 0.46

	# Filmic tonemapping for a cinematic HD-2D look
	env.tonemap_mode     = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.02
	env.adjustment_enabled = true
	env.adjustment_brightness = 0.98
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.12

	# Subtle depth fog for atmospheric perspective
	env.fog_enabled           = true
	env.fog_density           = 0.0060
	env.fog_light_color       = Color(1.00, 0.53, 0.33)
	env.fog_sun_scatter       = 0.26
	env.fog_aerial_perspective = 0.40

	_world_environment = WorldEnvironment.new()
	_world_environment.environment = env
	add_child(_world_environment)

	_setup_star_dome()
	_setup_ambient_motes()
	_setup_night_motes()
	_setup_vignette()
	_setup_fake_godrays()
	_apply_time_of_day(1)

func _setup_cloud_cookie_light() -> void:
	if hex_grid == null:
		return
	var center: Vector3 = hex_grid.get_map_center()
	var max_world: Vector3 = hex_grid.hex_to_world(hex_grid.COLS - 1, hex_grid.ROWS - 1)
	_cloud_cookie_center = Vector3(center.x, 0.0, center.z)
	_cloud_cookie_drift_radius = Vector2(
		maxf(3.5, max_world.x * 0.16),
		maxf(3.0, max_world.z * 0.14)
	)

	_cloud_cookie_light = SpotLight3D.new()
	_cloud_cookie_light.name = "CloudCookieLight"
	_cloud_cookie_light.shadow_enabled = false
	_cloud_cookie_light.light_negative = true
	_cloud_cookie_light.light_color = Color(0.72, 0.67, 0.62)
	_cloud_cookie_light.light_energy = 0.50
	_cloud_cookie_light.light_specular = 0.0
	_cloud_cookie_light.spot_range = maxf(max_world.length() + 16.0, 34.0)
	_cloud_cookie_light.spot_angle = 72.0
	_cloud_cookie_light.spot_angle_attenuation = 0.55
	_cloud_cookie_light.position = _cloud_cookie_center + Vector3(0.0, 18.0, 0.0)
	_cloud_cookie_light.rotation_degrees = Vector3(-90.0, 0.0, 0.0)

	var projector: Texture2D = _build_cloud_cookie_projector()
	var projector_property: String = ""
	for property_data: Dictionary in _cloud_cookie_light.get_property_list():
		var property_name: String = String(property_data.get("name", ""))
		if property_name == "projector" or property_name == "projector_texture" or property_name == "light_projector":
			projector_property = property_name
			break
	if not projector_property.is_empty():
		_cloud_cookie_light.set(projector_property, projector)

	add_child(_cloud_cookie_light)
	_update_cloud_cookie_light()

func _build_cloud_cookie_projector() -> Texture2D:
	var size: int = 256
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y: int in range(size):
		for x: int in range(size):
			var uv: Vector2 = Vector2(float(x) / float(size - 1), float(y) / float(size - 1))
			var centered: Vector2 = uv * 2.0 - Vector2.ONE
			var radial: float = clampf(1.0 - centered.length(), 0.0, 1.0)
			var layer_a: float = 0.5 + 0.5 * sin(uv.x * 7.8 + uv.y * 3.1)
			var layer_b: float = 0.5 + 0.5 * cos(uv.y * 8.9 - uv.x * 2.7)
			var layer_c: float = 0.5 + 0.5 * sin((uv.x + uv.y) * 9.6 + 1.4)
			var cloud_mask: float = layer_a * 0.44 + layer_b * 0.30 + layer_c * 0.26
			cloud_mask = smoothstep(0.50, 0.78, cloud_mask) * pow(radial, 1.28)
			cloud_mask = pow(cloud_mask, 1.35)
			var shade: float = clampf(cloud_mask, 0.0, 1.0)
			image.set_pixel(x, y, Color(shade, shade, shade, 1.0))
	var texture := ImageTexture.create_from_image(image)
	return texture

func _update_cloud_cookie_light() -> void:
	if _cloud_cookie_light == null:
		return
	var offset_x: float = sin(_cloud_cookie_time * 0.10) * _cloud_cookie_drift_radius.x
	offset_x += sin(_cloud_cookie_time * 0.051 + 1.2) * (_cloud_cookie_drift_radius.x * 0.62)
	var offset_z: float = cos(_cloud_cookie_time * 0.078 + 0.7) * _cloud_cookie_drift_radius.y
	offset_z += sin(_cloud_cookie_time * 0.041 + 0.4) * (_cloud_cookie_drift_radius.y * 0.48)
	_cloud_cookie_light.position = _cloud_cookie_center + Vector3(offset_x, 18.0, offset_z)
	_cloud_cookie_light.rotation_degrees = Vector3(-90.0, 0.0, sin(_cloud_cookie_time * 0.062) * 18.0)

func _setup_vignette() -> void:
	var shader: Shader          = load("res://shaders/vignette.gdshader")
	if shader == null:
		return
	_vignette_material = ShaderMaterial.new()
	_vignette_material.shader = shader

	var rect: ColorRect = ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material     = _vignette_material

	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = 0   # below HUD (CanvasLayer default 1)
	canvas.add_child(rect)
	add_child(canvas)

func _setup_fake_godrays() -> void:
	return

func _update_fake_godrays(delta: float) -> void:
	if _world_environment == null or _sun_light == null:
		return
	var env: Environment = _world_environment.environment
	var opening_primary: float = 0.5 + 0.5 * sin(_cloud_cookie_time * 0.64 + sin(_cloud_cookie_time * 0.17) * 1.8)
	var opening_secondary: float = 0.5 + 0.5 * cos(_cloud_cookie_time * 0.31 + 0.9)
	var opening: float = clampf(opening_primary * 0.62 + opening_secondary * 0.38, 0.0, 1.0)
	var target_scatter: float
	var target_density: float
	var target_cookie_energy: float
	var target_fog_color: Color
	if _current_is_night == true:
		var moon_strength: float = 0.55
		if _stars_material != null:
			moon_strength = clampf(float(_stars_material.get_shader_parameter("star_visibility")), 0.0, 1.0)
		target_scatter = lerpf(0.10, 0.24, opening) * moon_strength
		target_density = lerpf(0.0032, 0.0044, opening)
		target_cookie_energy = lerpf(0.18, 0.34, opening)
		target_fog_color = Color(0.14, 0.20, 0.34).lerp(Color(0.32, 0.42, 0.60), opening * 0.55)
	else:
		target_scatter = lerpf(0.24, 0.46, opening)
		target_density = lerpf(0.0059, 0.0072, opening)
		target_cookie_energy = lerpf(0.48, 0.74, opening)
		target_fog_color = Color(0.98, 0.56, 0.34).lerp(Color(1.0, 0.74, 0.48), opening * 0.45)

	env.fog_sun_scatter = lerpf(env.fog_sun_scatter, target_scatter, minf(delta * 1.8, 1.0))
	env.fog_density = lerpf(env.fog_density, target_density, minf(delta * 1.2, 1.0))
	env.fog_light_color = env.fog_light_color.lerp(target_fog_color, minf(delta * 1.4, 1.0))
	if _cloud_cookie_light != null:
		_cloud_cookie_light.light_energy = lerpf(_cloud_cookie_light.light_energy, target_cookie_energy, minf(delta * 1.6, 1.0))
	if _ambient_motes != null and _ambient_motes.material_override is StandardMaterial3D:
		var motes_mat: StandardMaterial3D = _ambient_motes.material_override as StandardMaterial3D
		if _current_is_night == true:
			motes_mat.albedo_color = Color(0.66, 0.80, 1.0, lerpf(0.04, 0.08, opening))
			motes_mat.emission = Color(0.66, 0.80, 1.0)
			motes_mat.emission_energy_multiplier = lerpf(0.10, 0.22, opening)
		else:
			motes_mat.albedo_color = Color(1.0, 0.92, 0.78, lerpf(0.10, 0.18, opening))
			motes_mat.emission = Color(1.0, 0.90, 0.72)
			motes_mat.emission_energy_multiplier = lerpf(0.18, 0.34, opening)

func _setup_star_dome() -> void:
	if StarsDomeShader == null:
		return
	var center: Vector3 = hex_grid.get_map_center()
	var dome_mesh := SphereMesh.new()
	dome_mesh.radius = 120.0
	dome_mesh.height = 240.0
	dome_mesh.radial_segments = 40
	dome_mesh.rings = 20

	_stars_material = ShaderMaterial.new()
	_stars_material.shader = StarsDomeShader
	_stars_material.set_shader_parameter("star_visibility", 0.0)

	var dome := MeshInstance3D.new()
	dome.mesh = dome_mesh
	dome.material_override = _stars_material
	dome.position = Vector3(center.x, 18.0, center.z)
	add_child(dome)

func _setup_ambient_motes() -> void:
	var center: Vector3 = hex_grid.get_map_center()
	var max_world: Vector3 = hex_grid.hex_to_world(hex_grid.COLS - 1, hex_grid.ROWS - 1)
	var spread_x: float = max_world.x * 0.52 + 5.0
	var spread_z: float = max_world.z * 0.50 + 5.0

	_ambient_motes = GPUParticles3D.new()
	_ambient_motes.amount = 32
	_ambient_motes.lifetime = 8.5
	_ambient_motes.one_shot = false
	_ambient_motes.explosiveness = 0.0
	_ambient_motes.randomness = 0.75
	_ambient_motes.draw_pass_1 = QuadMesh.new()
	(_ambient_motes.draw_pass_1 as QuadMesh).size = Vector2(0.035, 0.035)
	_ambient_motes.position = Vector3(center.x, 3.4, center.z)
	_ambient_motes.visibility_aabb = AABB(
		Vector3(-spread_x, -4.0, -spread_z),
		Vector3(spread_x * 2.0, 10.0, spread_z * 2.0)
	)
	_ambient_motes.emitting = true

	var particles_mat := ParticleProcessMaterial.new()
	particles_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	particles_mat.emission_box_extents = Vector3(spread_x, 2.8, spread_z)
	particles_mat.direction = Vector3(0.18, 0.04, 0.12)
	particles_mat.spread = 40.0
	particles_mat.initial_velocity_min = 0.015
	particles_mat.initial_velocity_max = 0.04
	particles_mat.gravity = Vector3(0.0, 0.003, 0.0)
	particles_mat.scale_min = 0.03
	particles_mat.scale_max = 0.06
	particles_mat.color = Color(1.0, 0.88, 0.72, 0.10)
	particles_mat.color_ramp = _build_ambient_mote_ramp()
	_ambient_motes.process_material = particles_mat

	var motes_mat := StandardMaterial3D.new()
	motes_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	motes_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	motes_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	motes_mat.albedo_color = Color(1.0, 0.90, 0.76, 0.07)
	motes_mat.emission_enabled = true
	motes_mat.emission = Color(1.0, 0.90, 0.76)
	motes_mat.emission_energy_multiplier = 0.24
	motes_mat.no_depth_test = false
	_ambient_motes.material_override = motes_mat
	add_child(_ambient_motes)

func _build_ambient_mote_ramp() -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.0),
		Color(1.0, 1.0, 1.0, 0.20),
		Color(1.0, 1.0, 1.0, 0.16),
		Color(1.0, 1.0, 1.0, 0.0),
	])
	gradient.offsets = PackedFloat32Array([0.0, 0.18, 0.72, 1.0])
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	return texture

func _setup_night_motes() -> void:
	var center: Vector3 = hex_grid.get_map_center()
	var max_world: Vector3 = hex_grid.hex_to_world(hex_grid.COLS - 1, hex_grid.ROWS - 1)
	var spread_x: float = max_world.x * 0.50 + 4.0
	var spread_z: float = max_world.z * 0.48 + 4.0

	_night_motes = Node3D.new()
	_night_motes.position = Vector3(center.x, 0.0, center.z)
	_firefly_data.clear()
	var glow_mesh := QuadMesh.new()
	glow_mesh.size = Vector2(0.12, 0.12)

	for i: int in range(8):
		var dot := MeshInstance3D.new()
		dot.mesh = glow_mesh
		var glow_mat := StandardMaterial3D.new()
		glow_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glow_mat.albedo_color = Color(0.36, 1.0, 0.10, 0.0)
		glow_mat.emission_enabled = true
		glow_mat.emission = Color(0.36, 1.0, 0.10)
		glow_mat.emission_energy_multiplier = 0.0
		glow_mat.no_depth_test = false
		glow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		dot.material_override = glow_mat
		dot.visible = false

		var local_pos := Vector3(
			randf_range(-spread_x, spread_x),
			randf_range(2.6, 5.4),
			randf_range(-spread_z, spread_z)
		)
		dot.position = local_pos
		_night_motes.add_child(dot)
		_firefly_data.append({
			"node": dot,
			"material": glow_mat,
			"base_pos": local_pos,
			"phase": randf_range(0.0, TAU),
			"speed": randf_range(1.4, 2.2),
			"bob_amp": randf_range(0.05, 0.16),
			"drift_amp": randf_range(0.08, 0.28),
		})

	add_child(_night_motes)

func _apply_time_of_day(turn_number: int) -> void:
	if _sun_light == null or _fill_light == null or _world_environment == null or _sky_material == null:
		return

	var cycle_index: int = int((turn_number - 1) / 4) % 2
	var is_night: bool = cycle_index == 1
	var target_profile: Dictionary = _build_lighting_profile(is_night)
	if _current_is_night == null:
		_apply_lighting_profile(target_profile)
		_current_is_night = is_night
		_schedule_next_day_night_ambient()
		return
	if _current_is_night == is_night:
		return

	var start_profile: Dictionary = _capture_lighting_profile()
	_current_is_night = is_night
	AudioManager.play_day_night_transition(is_night)
	_schedule_next_day_night_ambient(true)
	if _lighting_tween != null:
		_lighting_tween.kill()
	_lighting_tween = create_tween()
	_lighting_tween.tween_method(
		func(weight: float) -> void:
			_apply_lighting_profile(_lerp_lighting_profile(start_profile, target_profile, weight)),
		0.0, 1.0, 1.6
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _update_day_night_ambient(delta: float) -> void:
	if _current_is_night == null:
		return
	_ambient_cycle_timer -= delta
	if _ambient_cycle_timer > 0.0:
		return
	AudioManager.play_day_night_ambient(bool(_current_is_night))
	_schedule_next_day_night_ambient()

func _schedule_next_day_night_ambient(after_transition: bool = false) -> void:
	if after_transition:
		_ambient_cycle_timer = randf_range(8.0, 14.0)
		return
	_ambient_cycle_timer = randf_range(14.0, 26.0)

func _build_lighting_profile(is_night: bool) -> Dictionary:
	if is_night:
		return {
			"sun_rotation": Vector3(-42.0, 48.0, 0.0),
			"sun_color": Color(0.82, 0.88, 1.00),
			"sun_energy": 0.82,
			"fill_rotation": Vector3(-18.0, -128.0, 0.0),
			"fill_color": Color(0.18, 0.24, 0.40),
			"fill_energy": 0.08,
			"sky_top_color": Color(0.01, 0.02, 0.05),
			"sky_horizon_color": Color(0.10, 0.14, 0.26),
			"sky_curve": 0.28,
			"sky_energy_multiplier": 0.32,
			"ground_horizon_color": Color(0.05, 0.07, 0.14),
			"ground_bottom_color": Color(0.0, 0.0, 0.0),
			"ground_curve": 0.14,
			"ground_energy_multiplier": 0.14,
			"sun_angle_max": 18.0,
			"sun_curve": 0.12,
			"ambient_light_color": Color(0.18, 0.22, 0.34),
			"ambient_light_energy": 0.34,
			"tonemap_exposure": 0.96,
			"adjustment_brightness": 0.96,
			"adjustment_contrast": 1.06,
			"adjustment_saturation": 0.72,
			"fog_density": 0.0032,
			"fog_light_color": Color(0.12, 0.16, 0.28),
			"fog_sun_scatter": 0.12,
			"fog_aerial_perspective": 0.16,
			"vignette_strength": 0.70,
			"star_visibility": 0.75,
			"cloud_cookie_energy": 0.22,
		}
	return {
		"sun_rotation": Vector3(-28.0, 62.0, 0.0),
		"sun_color": Color(1.00, 0.64, 0.38),
		"sun_energy": 1.65,
		"fill_rotation": Vector3(-42.0, -138.0, 0.0),
		"fill_color": Color(0.45, 0.56, 0.86),
		"fill_energy": 0.18,
		"sky_top_color": Color(0.06, 0.05, 0.08),
		"sky_horizon_color": Color(0.10, 0.08, 0.12),
		"sky_curve": 0.22,
		"sky_energy_multiplier": 0.18,
		"ground_horizon_color": Color(0.02, 0.02, 0.03),
		"ground_bottom_color": Color(0.0, 0.0, 0.0),
		"ground_curve": 0.12,
		"ground_energy_multiplier": 0.05,
		"sun_angle_max": 8.0,
		"sun_curve": 0.08,
		"ambient_light_color": Color(0.86, 0.56, 0.46),
		"ambient_light_energy": 0.52,
		"tonemap_exposure": 1.12,
		"adjustment_brightness": 1.03,
		"adjustment_contrast": 1.08,
		"adjustment_saturation": 1.12,
		"fog_density": 0.0060,
		"fog_light_color": Color(1.00, 0.53, 0.33),
		"fog_sun_scatter": 0.26,
		"fog_aerial_perspective": 0.40,
		"vignette_strength": 0.65,
		"star_visibility": 0.0,
		"cloud_cookie_energy": 0.52,
	}

func _capture_lighting_profile() -> Dictionary:
	var env: Environment = _world_environment.environment
	return {
		"sun_rotation": _sun_light.rotation_degrees,
		"sun_color": _sun_light.light_color,
		"sun_energy": _sun_light.light_energy,
		"fill_rotation": _fill_light.rotation_degrees,
		"fill_color": _fill_light.light_color,
		"fill_energy": _fill_light.light_energy,
		"sky_top_color": _sky_material.sky_top_color,
		"sky_horizon_color": _sky_material.sky_horizon_color,
		"sky_curve": _sky_material.sky_curve,
		"sky_energy_multiplier": _sky_material.sky_energy_multiplier,
		"ground_horizon_color": _sky_material.ground_horizon_color,
		"ground_bottom_color": _sky_material.ground_bottom_color,
		"ground_curve": _sky_material.ground_curve,
		"ground_energy_multiplier": _sky_material.ground_energy_multiplier,
		"sun_angle_max": _sky_material.sun_angle_max,
		"sun_curve": _sky_material.sun_curve,
		"ambient_light_color": env.ambient_light_color,
		"ambient_light_energy": env.ambient_light_energy,
		"tonemap_exposure": env.tonemap_exposure,
		"adjustment_brightness": env.adjustment_brightness,
		"adjustment_contrast": env.adjustment_contrast,
		"adjustment_saturation": env.adjustment_saturation,
		"fog_density": env.fog_density,
		"fog_light_color": env.fog_light_color,
		"fog_sun_scatter": env.fog_sun_scatter,
		"fog_aerial_perspective": env.fog_aerial_perspective,
		"vignette_strength": _vignette_material.get_shader_parameter("strength") if _vignette_material != null else 0.65,
		"star_visibility": _stars_material.get_shader_parameter("star_visibility") if _stars_material != null else 0.0,
		"cloud_cookie_energy": _cloud_cookie_light.light_energy if _cloud_cookie_light != null else 0.0,
	}

func _lerp_lighting_profile(from: Dictionary, to: Dictionary, weight: float) -> Dictionary:
	var result: Dictionary = {}
	for key: Variant in to.keys():
		var target: Variant = to[key]
		var source: Variant = from.get(key, target)
		match typeof(target):
			TYPE_FLOAT:
				result[key] = lerpf(source, target, weight)
			TYPE_VECTOR3:
				result[key] = source.lerp(target, weight)
			TYPE_COLOR:
				result[key] = source.lerp(target, weight)
			_:
				result[key] = target
	return result

func _apply_lighting_profile(profile: Dictionary) -> void:
	var env: Environment = _world_environment.environment
	_sun_light.rotation_degrees = profile["sun_rotation"]
	_sun_light.light_color = profile["sun_color"]
	_sun_light.light_energy = profile["sun_energy"]
	_fill_light.rotation_degrees = profile["fill_rotation"]
	_fill_light.light_color = profile["fill_color"]
	_fill_light.light_energy = profile["fill_energy"]
	_sky_material.sky_top_color = profile["sky_top_color"]
	_sky_material.sky_horizon_color = profile["sky_horizon_color"]
	_sky_material.sky_curve = profile["sky_curve"]
	_sky_material.sky_energy_multiplier = profile["sky_energy_multiplier"]
	_sky_material.ground_horizon_color = profile["ground_horizon_color"]
	_sky_material.ground_bottom_color = profile["ground_bottom_color"]
	_sky_material.ground_curve = profile["ground_curve"]
	_sky_material.ground_energy_multiplier = profile["ground_energy_multiplier"]
	_sky_material.sun_angle_max = profile["sun_angle_max"]
	_sky_material.sun_curve = profile["sun_curve"]
	env.ambient_light_color = profile["ambient_light_color"]
	env.ambient_light_energy = profile["ambient_light_energy"]
	env.tonemap_exposure = profile["tonemap_exposure"]
	env.adjustment_brightness = profile["adjustment_brightness"]
	env.adjustment_contrast = profile["adjustment_contrast"]
	env.adjustment_saturation = profile["adjustment_saturation"]
	env.fog_density = profile["fog_density"]
	env.fog_light_color = profile["fog_light_color"]
	env.fog_sun_scatter = profile["fog_sun_scatter"]
	env.fog_aerial_perspective = profile["fog_aerial_perspective"]
	if _vignette_material != null and _vignette_material.shader != null:
		_vignette_material.set_shader_parameter("strength", profile["vignette_strength"])
	if _stars_material != null and _stars_material.shader != null:
		_stars_material.set_shader_parameter("star_visibility", profile["star_visibility"])
	if _cloud_cookie_light != null:
		_cloud_cookie_light.light_energy = profile["cloud_cookie_energy"]
	if _ambient_motes != null:
		var is_night: bool = float(profile["star_visibility"]) > 0.1
		if _ambient_motes.material_override is StandardMaterial3D:
			var mote_mat: StandardMaterial3D = _ambient_motes.material_override as StandardMaterial3D
			if is_night:
				mote_mat.albedo_color = Color(0.74, 0.84, 1.0, 0.028)
				mote_mat.emission = Color(0.74, 0.84, 1.0)
				mote_mat.emission_energy_multiplier = 0.10
			else:
				mote_mat.albedo_color = Color(1.0, 0.92, 0.78, 0.09)
				mote_mat.emission = Color(1.0, 0.92, 0.78)
				mote_mat.emission_energy_multiplier = 0.34
		if _ambient_motes.process_material is ParticleProcessMaterial:
			var process_mat: ParticleProcessMaterial = _ambient_motes.process_material as ParticleProcessMaterial
			process_mat.color = Color(0.74, 0.84, 1.0, 0.04) if is_night else Color(1.0, 0.92, 0.78, 0.12)
	if _night_motes != null:
		var moon_strength: float = clampf(float(profile["star_visibility"]), 0.0, 1.0)
		_firefly_strength = moon_strength
		_night_motes.visible = moon_strength > 0.05
	_apply_unit_time_lighting(profile)
	_apply_board_time_lighting(profile)

func _apply_unit_time_lighting(profile: Dictionary) -> void:
	var moon_strength: float = clampf(float(profile["star_visibility"]), 0.0, 1.0)
	var is_night: bool = moon_strength > 0.1
	for child: Node in $Units.get_children():
		if child.has_method("set_time_lighting"):
			child.call("set_time_lighting", is_night, moon_strength)

func _apply_board_time_lighting(profile: Dictionary) -> void:
	if hex_grid == null or not hex_grid.has_method("apply_time_of_day_visuals"):
		return
	var moon_strength: float = clampf(float(profile["star_visibility"]), 0.0, 1.0)
	var is_night: bool = moon_strength > 0.1
	hex_grid.call("apply_time_of_day_visuals", is_night, moon_strength)


# --- Handlers ---
func _on_free_summon_requested(player_id: int) -> void:
	# La IA maneja free_summon directamente via SimpleAI._try_summon;
	# no abrir el menu ni setear _next_summon_is_free para evitar que
	# la siguiente invocacion humana quede marcada como gratuita.
	if GameData.get_player_mode(player_id) == "ai":
		return
	_next_summon_is_free = true
	summon_menu.show_for_player(player_id, resource_manager)

func _on_revive_requested(player_id: int, unit_data: Dictionary) -> void:
	if summon_manager == null or hex_grid == null:
		return
	var unit_type: int = int(unit_data.get("type", 0))
	var valid_cells: Array = hex_grid.get_valid_summon_cells(player_id)
	if valid_cells.is_empty():
		return
	var cell: Vector2i = valid_cells[0]
	summon_manager.summon_free(unit_type, cell.x, cell.y, player_id)
	var revived: Unit = hex_grid.get_unit_at(cell.x, cell.y)
	if revived != null:
		revived.hp = maxi(1, revived.max_hp / 2)

func _open_summon_menu() -> void:
	summon_menu.show_for_player(turn_manager.current_player, resource_manager)
	if _tutorial_active and _get_current_tutorial_key() == "open_summon":
		_advance_tutorial()

func _on_end_turn_pressed() -> void:
	if _tutorial_active and _get_current_tutorial_key() == "end_turn":
		_advance_tutorial()
	turn_manager.end_turn()

func _try_master_free_summon() -> void:
	return
	var unit: Unit = hex_grid.get_selected_unit()
	if unit == null or not (unit is Master):
		return
	if unit.owner_id != turn_manager.current_player:
		return
	if unit.free_summon_used:
		print("[Main3D] El Maestro ya usó su invocación gratuita este turno.")
		return
	_master_summoning       = true
	_master_for_free_summon = unit
	summon_menu.show_for_player(turn_manager.current_player, resource_manager)

func _on_unit_type_chosen(unit_type: int) -> void:
	hex_grid.enter_placement_mode(unit_type, turn_manager.current_player)
	var unit_name: String = _get_unit_display_name(unit_type)
	var message: String = "Elegiste %s. Ahora colócalo en un hexágono resaltado junto a tu Maestro." % unit_name
	var counter_hint: String = _get_summon_counter_hint(unit_type)
	if counter_hint != "":
		message += " " + counter_hint
	if not (_tutorial_active and _get_current_tutorial_key() == "summon_unit"):
		hud.show_placement_hint(message, unit_type)

func _on_summon_cancelled() -> void:
	hex_grid.exit_placement_mode()

func _on_tower_captured(_tower_name: String, player_id: int) -> void:
	_towers_by_player[player_id] = int(_towers_by_player.get(player_id, 0)) + 1
	hud.refresh_towers()
	if turn_manager != null and turn_manager.has_method("handle_tower_captured"):
		turn_manager.handle_tower_captured(player_id)
	# A unit can level up by capturing a tower — handle immediately
	await _process_pending_bonuses()
	if _tutorial_active and GameData.tutorial_chapter_id == "chapter_1" and _get_current_tutorial_key() == "attack_enemy":
		_update_tutorial_focus_visuals()
	if _tutorial_active and player_id == 1 and _get_current_tutorial_key() == "capture_tower":
		_advance_tutorial()

func _on_placement_confirmed(col: int, row: int, unit_type: int, player_id: int) -> void:
	if _next_summon_is_free:
		_next_summon_is_free = false
		summon_manager.summon_free(unit_type, col, row, player_id)
	else:
		summon_manager.summon(unit_type, col, row, player_id)
	# If the unit was placed on a tower it may have levelled up — process now.
	# (_on_tower_captured handles this too, but that signal fires asynchronously
	#  so this ensures the bonus panel appears before the player regains control.)
	await _process_pending_bonuses()
	_tutorial_last_placed_cell = Vector2i(col, row)
	hud.hide_placement_hint()
	hud.refresh_towers()
	var placed: Unit = hex_grid.get_unit_at(col, row)
	if placed != null:
		if GameData.tutorial_mode_active and GameData.tutorial_chapter_id == "chapter_2":
			placed.moved = false
			placed.has_attacked = false
		hud.show_unit(placed)
		_apply_unit_time_lighting(_capture_lighting_profile())
	if _tutorial_active and player_id == 1 and _get_current_tutorial_key() == "summon_unit":
		_tutorial_waiting_for_summon_explanation = true
		if hud != null:
			hud.set_tutorial_focus("")
			hud.set_tutorial_world_markers(false, Vector3.ZERO, false, Vector3.ZERO)
			if hud.has_method("show_tutorial_summon_explanation"):
				hud.call("show_tutorial_summon_explanation", _get_unit_display_name(unit_type), _get_summon_counter_hint(unit_type))
		if hex_grid != null:
			hex_grid.clear_tutorial_focus_cell()
			hex_grid.clear_highlights()
		return

func _on_card_target_selected(card_index: int, target_unit: Unit) -> void:
	var current_player_id: int = turn_manager.current_player
	var hand: Array = CardManager.get_hand(current_player_id)
	var card: Dictionary = hand[card_index] if card_index >= 0 and card_index < hand.size() else {}
	if card_hand != null and card_hand.has_method("play_card_use_transition"):
		await card_hand.play_card_use_transition(card_index)
	if is_instance_valid(target_unit):
		var pre_color: Color = _card_color_from_key(str(card.get("color", "")), str(card.get("type", "")))
		var master_unit: Unit = _find_player_master_unit(current_player_id)
		var source_world: Vector3 = CardManager._unit_world_pos(master_unit) if master_unit != null else CardManager._unit_world_pos(target_unit) + Vector3(0.0, 1.0, 0.0)
		_card_vfx_preplayed = true
		await VFXManager.show_card_target_telegraph(
			CardManager._unit_world_pos(target_unit),
			pre_color,
			_card_display_vfx_name(card)
		)
		await VFXManager.show_card_projectile(
			source_world,
			CardManager._unit_world_pos(target_unit),
			pre_color
		)
	var played: bool = CardManager.play_card(current_player_id, card_index, target_unit)
	if not played:
		_card_vfx_preplayed = false
		return
	if is_instance_valid(target_unit) and target_unit.hp > 0:
		hud.show_unit(target_unit)
	else:
		hud.hide_unit()

func _on_card_tower_selected(card_index: int, tower_cell: Vector2i) -> void:
	var current_player_id: int = turn_manager.current_player
	var hand: Array = CardManager.get_hand(current_player_id)
	var card: Dictionary = hand[card_index] if card_index >= 0 and card_index < hand.size() else {}
	if card_hand != null and card_hand.has_method("play_card_use_transition"):
		await card_hand.play_card_use_transition(card_index)
	var tower_world: Vector3 = Vector3.ZERO
	if hex_grid != null and hex_grid.has_method("hex_to_world"):
		tower_world = hex_grid.hex_to_world(tower_cell.x, tower_cell.y)
	var tower_color: Color = _card_color_from_key(str(card.get("color", "")), str(card.get("type", "")))
	var tower_master: Unit = _find_player_master_unit(current_player_id)
	var tower_source_world: Vector3 = CardManager._unit_world_pos(tower_master) if tower_master != null else tower_world + Vector3(0.0, 1.0, 0.0)
	_card_vfx_preplayed = true
	await VFXManager.show_card_target_telegraph(tower_world, tower_color, _card_display_vfx_name(card))
	await VFXManager.show_card_projectile(
		tower_source_world,
		tower_world,
		tower_color
	)
	var played: bool = false
	if CardManager.has_method("play_card_on_tower"):
		played = CardManager.play_card_on_tower(current_player_id, card_index, tower_cell)
	if not played:
		_card_vfx_preplayed = false
		return
	VFXManager.show_world_text_label(tower_world, "TORRE SAGRADA", Color(1.0, 0.82, 0.18, 1.0), 60, 1.45)
	if hud != null:
		hud.hide_unit()

func _on_card_played(player_id: int, card: Dictionary) -> void:
	_cards_used_by_player[player_id] = int(_cards_used_by_player.get(player_id, 0)) + 1
	if turn_manager == null or player_id != turn_manager.current_player:
		return
	var card_type: String = str(card.get("type", ""))
	if card_type != "essence":
		return
	if card_hand == null or hud == null:
		return
	if not card_hand.has_method("get_card_screen_position") or not hud.has_method("get_essence_label_screen_position"):
		return
	var hand_after_play: Array = CardManager.get_hand(player_id)
	var source_index: int = hand_after_play.size()
	var source_pos: Vector2 = card_hand.get_card_screen_position(source_index)
	var target_pos: Vector2 = hud.get_essence_label_screen_position()
	if source_pos == Vector2.ZERO:
		source_pos = Vector2(688.0, 620.0)
	VFXManager.show_screen_projectile(
		source_pos,
		target_pos,
		_card_color_from_key(str(card.get("color", "")), card_type)
	)

func _on_unit_killed_by_card(unit: Unit, _killer_player_id: int) -> void:
	CardManager.track_dead_unit(unit)
	_kills_by_player[_killer_player_id] = int(_kills_by_player.get(_killer_player_id, 0)) + 1
	var was_master: bool = unit is Master
	var owner_id: int = unit.owner_id
	hex_grid.remove_unit(unit)
	hud.hide_unit()
	if was_master:
		turn_manager.handle_master_killed(owner_id)

func _on_card_resolved(player_id: int, card: Dictionary, target_unit: Unit) -> void:
	if turn_manager == null or player_id != turn_manager.current_player:
		return
	if _card_vfx_preplayed:
		_card_vfx_preplayed = false
	else:
		_play_card_board_vfx(player_id, card, target_unit)

	var card_type: String = str(card.get("type", ""))
	var value: int = int(card.get("value", 0))
	match card_type:
		"essence":
			if hud != null and hud.has_method("get_essence_label_screen_position"):
				VFXManager.show_screen_text_label(
					hud.get_essence_label_screen_position(),
					"+%d" % value,
					Color(0.42, 0.88, 1.0, 1.0),
					48
				)
		"heal":
			if target_unit != null:
				var heal_pos: Vector3 = CardManager._unit_world_pos(target_unit)
				VFXManager.show_world_text_label(heal_pos, "+%d" % value, Color(0.28, 1.0, 0.36, 1.0), 70, 1.5)
		"exp":
			if target_unit != null:
				var exp_pos: Vector3 = CardManager._unit_world_pos(target_unit)
				VFXManager.show_world_text_label(exp_pos, "+%d XP" % value, Color(0.82, 0.34, 1.0, 1.0), 66, 1.55)
		"refresh":
			if target_unit != null:
				var refresh_pos: Vector3 = CardManager._unit_world_pos(target_unit)
				VFXManager.show_world_text_label(refresh_pos, "REFRESCO", Color(1.0, 0.84, 0.28, 1.0), 64, 1.5)
				if hex_grid != null and hex_grid.has_method("refresh_unit_action_indicators"):
					hex_grid.refresh_unit_action_indicators()
				if hud != null and target_unit != null and hud.get("_current_unit") == target_unit:
					hud.show_unit(target_unit)
		"faction":
			var effect: String = str(card.get("effect", ""))
			if target_unit != null:
				var pos: Vector3 = CardManager._unit_world_pos(target_unit)
				match effect:
					"heal":
						VFXManager.show_world_text_label(pos, "+%d HP" % int(card.get("value", 0)), Color(0.28, 1.0, 0.36, 1.0), 70, 1.5)
					"exp":
						VFXManager.show_world_text_label(pos, "+%d XP" % int(card.get("value", 0)), Color(0.82, 0.34, 1.0, 1.0), 66, 1.55)
					"extra_move":
						VFXManager.show_world_text_label(pos, "+%d MOV" % int(card.get("value", 0)), Color(0.94, 0.74, 0.22, 1.0), 64, 1.5)
					"double_attack":
						VFXManager.show_world_text_label(pos, "×2 ATK", Color(0.94, 0.74, 0.22, 1.0), 64, 1.5)
					"immobilize":
						VFXManager.show_world_text_label(pos, "INMOVILIZADO", Color(0.96, 0.48, 0.22, 1.0), 60, 1.5)
					"poison":
						VFXManager.show_world_text_label(pos, "VENENO", Color(0.52, 0.84, 0.28, 1.0), 64, 1.5)
					"defense_buff":
						VFXManager.show_world_text_label(pos, "DEF +%d" % int(card.get("value", 0)), Color(0.18, 0.84, 0.76, 1.0), 64, 1.5)
					"attack_debuff":
						VFXManager.show_world_text_label(pos, "-ATK", Color(0.96, 0.28, 0.28, 1.0), 64, 1.5)
					"untargetable":
						VFXManager.show_world_text_label(pos, "NIEBLA", Color(0.72, 0.42, 0.92, 1.0), 64, 1.5)
					"swap_hp":
						VFXManager.show_world_text_label(pos, "SWAP HP", Color(0.72, 0.42, 0.92, 1.0), 64, 1.5)
			if hex_grid != null and hex_grid.has_method("refresh_unit_action_indicators"):
				hex_grid.refresh_unit_action_indicators()
			if hud != null and target_unit != null and hud.get("_current_unit") == target_unit:
				hud.show_unit(target_unit)
	if hud != null and hud.has_method("refresh_advantage"):
		hud.refresh_advantage()
	if _tutorial_active and player_id == 1 and _get_current_tutorial_key() == "play_card":
		_advance_tutorial()

func _play_card_board_vfx(player_id: int, card: Dictionary, target_unit: Unit) -> void:
	if target_unit == null:
		return
	var card_type: String = str(card.get("type", ""))
	if card_type != "heal" and card_type != "damage" and card_type != "exp" \
			and card_type != "refresh" and card_type != "faction":
		return
	var master_unit: Unit = _find_player_master_unit(player_id)
	if master_unit == null:
		return
	VFXManager.show_card_projectile(
		CardManager._unit_world_pos(master_unit),
		CardManager._unit_world_pos(target_unit),
		_card_color_from_key(str(card.get("color", "")), card_type)
	)

func _card_display_vfx_name(card: Dictionary) -> String:
	var card_type: String = str(card.get("type", ""))
	if card_type == "faction":
		return str(card.get("display_name", str(card.get("effect", "Carta")))).to_upper()
	match card_type:
		"heal":
			return "CURA"
		"damage":
			return "DANO"
		"exp":
			return "BENDICION"
		"refresh":
			return "REFRESCO"
		"essence":
			return "ESENCIA"
		_:
			return "CARTA"

func _find_player_master_unit(player_id: int) -> Unit:
	if hex_grid == null or not hex_grid.has_method("get_all_units"):
		return null
	for unit_value: Variant in hex_grid.get_all_units():
		var unit: Unit = unit_value as Unit
		if unit != null and unit.owner_id == player_id and unit is Master:
			return unit
	return null

func _card_color_from_key(color_key: String, card_type: String = "") -> Color:
	match color_key:
		"teal":
			return Color(0.24, 0.92, 0.76, 1.0)
		"cyan":
			return Color(0.34, 0.88, 1.0, 1.0)
		"red":
			return Color(1.0, 0.30, 0.24, 1.0)
		"purple":
			return Color(0.78, 0.40, 1.0, 1.0)
	match card_type:
		"heal":
			return Color(0.24, 0.92, 0.76, 1.0)
		"essence":
			return Color(0.34, 0.88, 1.0, 1.0)
		"damage":
			return Color(1.0, 0.30, 0.24, 1.0)
		"exp":
			return Color(0.78, 0.40, 1.0, 1.0)
		_:
			return Color.WHITE

func _on_master_placement_confirmed(col: int, row: int, unit_type: int, player_id: int) -> void:
	return
	summon_manager.summon_free(unit_type, col, row, player_id)
	if _master_for_free_summon != null:
		_master_for_free_summon.free_summon_used = true
		_master_for_free_summon = null
	hud.hide_placement_hint()
	hud.refresh_towers()
	var placed: Unit = hex_grid.get_unit_at(col, row)
	if placed != null:
		hud.show_unit(placed)
		_apply_unit_time_lighting(_capture_lighting_profile())

func _on_enemy_inspected(_enemy: Unit, multiplier: float) -> void:
	var attacker: Unit = hex_grid.get_selected_unit() if hex_grid != null and hex_grid.has_method("get_selected_unit") else null
	if attacker != null:
		hud.show_combat_preview(attacker, _enemy)
	else:
		hud.show_advantage(multiplier)

func _on_unit_selected_refresh_preview(_unit: Unit) -> void:
	if hud != null:
		hud.hide_advantage()

func _on_unit_hovered(unit: Unit) -> void:
	if hud == null or unit == null:
		return
	_hovered_hud_unit = unit
	hud.show_unit(unit)
	var selected_unit: Unit = hex_grid.get_selected_unit() if hex_grid != null and hex_grid.has_method("get_selected_unit") else null
	var hovered_cell: Vector2i = unit.get_hex_cell() if unit != null and unit.has_method("get_hex_cell") else Vector2i(-1, -1)
	if selected_unit != null and unit.owner_id != selected_unit.owner_id and hex_grid != null and hex_grid.has_method("is_attack_target_cell") and hex_grid.is_attack_target_cell(hovered_cell):
		hud.show_combat_preview(selected_unit, unit)
	else:
		hud.hide_advantage()

func _on_unit_hover_cleared() -> void:
	_hovered_hud_unit = null
	if hud == null or hex_grid == null:
		return
	var selected_unit: Unit = hex_grid.get_selected_unit()
	if selected_unit != null and is_instance_valid(selected_unit):
		hud.show_unit(selected_unit)
		hud.hide_advantage()
	else:
		hud.hide_unit()

func _on_cell_hovered(cell: Vector2i) -> void:
	if hud == null:
		return
	hud.show_cell_context(cell)

func _on_cell_hover_cleared() -> void:
	if hud == null:
		return
	hud.hide_cell_context()

func _on_combat_resolved(attacker: Unit, defender: Unit, result: Dictionary) -> void:
	if result.get("defender_died", false) and defender != null:
		CardManager.track_dead_unit(defender)
		if attacker != null:
			_kills_by_player[attacker.owner_id] = int(_kills_by_player.get(attacker.owner_id, 0)) + 1
	if result.get("attacker_died", false) and attacker != null:
		CardManager.track_dead_unit(attacker)
		if defender != null:
			_kills_by_player[defender.owner_id] = int(_kills_by_player.get(defender.owner_id, 0)) + 1
	hud.show_combat_result(attacker, defender, result)

	# Process any level-up bonus selections triggered during combat
	await _process_pending_bonuses()

	if not _tutorial_active or attacker == null or attacker.owner_id != 1:
		return
	var tutorial_key: String = _get_current_tutorial_key()
	if tutorial_key == "attack_enemy":
		if GameData.tutorial_chapter_id == "chapter_3" and hud != null and is_instance_valid(attacker) and attacker.hp > 0:
			hud.show_unit(attacker)
		_advance_tutorial()
	elif GameData.tutorial_chapter_id == "chapter_1" and tutorial_key == "combat_response":
		# Si el jugador ataca antes de cerrar la explicación previa, saltamos
		# directamente al bloque posterior al combate para no romper el flujo.
		_tutorial_step = _get_tutorial_steps().find("combat_panel")
		if _tutorial_step == -1:
			_tutorial_step = _get_tutorial_steps().size() - 1
		_show_tutorial_step()

## Fallback for level-ups triggered outside combat (e.g. tower captures).
## Combat-triggered level-ups are already resolved inside CombatManager.process_pending().
func _process_pending_bonuses() -> void:
	if BonusSystem.has_pending_bonuses():
		await BonusSystem.process_pending()

func _on_turn_changed(player_id: int) -> void:
	print("[Main3D] *** Turno del Jugador %d ***" % player_id)
	_clear_transient_board_state(false)
	hex_grid.exit_card_target_mode()
	hex_grid.current_player = player_id
	_apply_time_of_day(turn_manager.turn_number)
	hud.update_turn(player_id)
	hud.refresh_towers()
	_hovered_hud_unit = null
	hud.hide_unit()
	_focus_camera_on_master(player_id)
	_record_timeline_snapshot(turn_manager.turn_number if turn_manager != null else 1)
	if _tutorial_active and player_id != 1:
		if hud != null:
			hud.hide_tutorial()
			hud.set_tutorial_focus("")
			hud.set_tutorial_world_markers(false, Vector3.ZERO, false, Vector3.ZERO)
		if card_hand != null and card_hand.has_method("set_tutorial_highlight"):
			card_hand.call("set_tutorial_highlight", false)
		if hex_grid != null:
			hex_grid.clear_tutorial_focus_cell()
			hex_grid.clear_highlights()
	if GameData.get_player_mode(player_id) == "ai":
		call_deferred("_run_ai_turn", player_id)
	elif _tutorial_active and (_get_current_tutorial_key() == "combat_response" or _get_current_tutorial_key() == "attack_enemy"):
		_show_tutorial_step()

func _run_ai_turn(player_id: int) -> void:
	if ai_controller == null or turn_manager == null:
		return
	if turn_manager.current_player != player_id:
		return
	if GameData.get_player_mode(player_id) != "ai":
		return
	await ai_controller.play_turn(player_id)
	if turn_manager != null and turn_manager.current_player == player_id:
		turn_manager.end_turn()

func _play_intro_camera_sequence() -> void:
	call_deferred("_run_intro_camera_sequence")

func _run_intro_camera_sequence() -> void:
	if camera == null or not camera.has_method("focus_on"):
		return
	camera.focus_on(hex_grid.get_map_center(), 18.0)
	await get_tree().create_timer(1.0).timeout
	_focus_camera_on_master(turn_manager.current_player, 7.0)
	if turn_manager != null and GameData.get_player_mode(turn_manager.current_player) == "ai":
		await get_tree().create_timer(0.6).timeout
		if turn_manager.current_player == 1:
			call_deferred("_run_ai_turn", turn_manager.current_player)

func _focus_camera_on_master(player_id: int, zoom_height: float = -1.0) -> void:
	if camera == null or not camera.has_method("focus_on"):
		return
	for cell_variant: Variant in hex_grid._units.keys():
		var cell: Vector2i = cell_variant as Vector2i
		var unit: Unit = hex_grid._units[cell]
		if unit is Master and unit.owner_id == player_id:
			camera.focus_on(hex_grid.hex_to_world(cell.x, cell.y), zoom_height)
			return

func _on_game_over(winner_id: int) -> void:
	var remaining_p1: int = 0
	var remaining_p2: int = 0
	for u: Unit in hex_grid.get_all_units():
		if u.owner_id == 1:
			remaining_p1 += 1
		elif u.owner_id == 2:
			remaining_p2 += 1

	GameData.winner_id          = winner_id
	GameData.turns_played       = turn_manager.turn_number
	GameData.units_killed_p1    = int(_kills_by_player.get(1, 0))
	GameData.units_killed_p2    = int(_kills_by_player.get(2, 0))
	GameData.towers_captured_p1 = int(_towers_by_player.get(1, 0))
	GameData.towers_captured_p2 = int(_towers_by_player.get(2, 0))
	_record_timeline_snapshot(turn_manager.turn_number if turn_manager != null else 1)
	GameData.match_stats        = _build_match_stats()
	GameData.record_completed_run()
	GameData.clear_saved_match()

	if winner_id == 0:
		print("[Main3D] La batalla termina en EMPATE.")
	else:
		print("[Main3D] *** ¡El Jugador %d es victorioso! ***" % winner_id)

	await _play_victory_transition(winner_id)
	get_tree().change_scene_to_file("res://scenes/GameOver.tscn")

func _build_match_stats() -> Dictionary:
	var players: Array[int] = GameData.get_player_ids()
	var remaining_by_player: Dictionary = {}
	var towers_owned_by_player: Dictionary = {}
	var highest_unit_by_player: Dictionary = {}
	var master_hp_by_player: Dictionary = {}
	var losses_by_player: Dictionary = {}
	for player_id: int in players:
		remaining_by_player[player_id] = 0
		towers_owned_by_player[player_id] = 0
		highest_unit_by_player[player_id] = "Sin unidades"
		master_hp_by_player[player_id] = 0
		losses_by_player[player_id] = 0

	if hex_grid != null and hex_grid.has_method("get_all_units"):
		for unit_value: Variant in hex_grid.get_all_units():
			var unit: Unit = unit_value as Unit
			if unit == null:
				continue
			var owner_id: int = unit.owner_id
			remaining_by_player[owner_id] = int(remaining_by_player.get(owner_id, 0)) + 1
			if unit is Master:
				master_hp_by_player[owner_id] = unit.hp
			var current_best: String = str(highest_unit_by_player.get(owner_id, ""))
			var current_level: int = int(current_best.split("|")[0]) if current_best.find("|") != -1 else -1
			if int(unit.level) > current_level:
				highest_unit_by_player[owner_id] = "%d|%s %s" % [
					int(unit.level),
					_get_rank_name(int(unit.level)),
					Unit.TYPE_NAMES.get(unit.unit_type, "Master"),
				]

	if hex_grid != null and hex_grid.has_method("get_all_towers"):
		for tower_value: Variant in hex_grid.get_all_towers():
			var tower: Tower = tower_value as Tower
			if tower != null and tower.owner_id > 0:
				towers_owned_by_player[tower.owner_id] = int(towers_owned_by_player.get(tower.owner_id, 0)) + 1

	for killer_id_value: Variant in _kills_by_player.keys():
		var killer_id: int = int(killer_id_value)
		if not players.has(killer_id):
			continue
		for player_id: int in players:
			if player_id == killer_id:
				continue
			losses_by_player[player_id] = int(losses_by_player.get(player_id, 0)) + int(_kills_by_player.get(killer_id, 0))

	var player_stats: Dictionary = {}
	for player_id: int in players:
		var best_entry: String = str(highest_unit_by_player.get(player_id, "Sin unidades"))
		var best_label: String = best_entry
		if best_entry.find("|") != -1:
			best_label = best_entry.substr(best_entry.find("|") + 1)
		player_stats[player_id] = {
			"kills": int(_kills_by_player.get(player_id, 0)),
			"losses": int(losses_by_player.get(player_id, 0)),
			"summons": int(_summoned_by_player.get(player_id, 0)),
			"towers_captured": int(_towers_by_player.get(player_id, 0)),
			"towers_owned_final": int(towers_owned_by_player.get(player_id, 0)),
			"essence_final": resource_manager.get_essence(player_id) if resource_manager != null and resource_manager.has_method("get_essence") else 0,
			"essence_gained": resource_manager.get_total_gained(player_id) if resource_manager != null and resource_manager.has_method("get_total_gained") else 0,
			"essence_spent": resource_manager.get_total_spent(player_id) if resource_manager != null and resource_manager.has_method("get_total_spent") else 0,
			"cards_used": int(_cards_used_by_player.get(player_id, 0)),
			"highest_unit": best_label,
			"master_hp": int(master_hp_by_player.get(player_id, 0)),
			"remaining_units": int(remaining_by_player.get(player_id, 0)),
		}
	return {
		"players": player_stats,
		"timeline": _timeline_snapshots.duplicate(true),
	}

func _play_victory_transition(winner_id: int) -> void:
	if camera == null:
		return
	_clear_transient_board_state(true)
	if hud != null:
		hud.hide_unit()
		hud.visible = false
	if card_hand != null:
		card_hand.visible = false
	if summon_menu != null:
		summon_menu.visible = false
	if level_up_menu != null:
		level_up_menu.visible = false
	if camera.has_method("set_manual_cinematic_lock"):
		camera.call("set_manual_cinematic_lock", true)
	_victory_transition_center = hex_grid.get_map_center() if hex_grid != null and hex_grid.has_method("get_map_center") else Vector3.ZERO
	_victory_transition_radius = clampf(maxf(float(maxi(hex_grid.COLS, hex_grid.ROWS)) * 0.95, 10.0), 10.0, 26.0) if hex_grid != null else 18.0
	_victory_transition_height = clampf(_victory_transition_radius * 0.82, 11.0, 18.0)
	_victory_transition_focus_height = 2.8
	_victory_transition_angle = -0.55
	_create_victory_transition_overlay(winner_id)
	_victory_transition_active = true
	_update_victory_transition_camera(0.0)

	var fade_in_tween: Tween = create_tween()
	fade_in_tween.set_parallel(true)
	if _victory_transition_overlay != null:
		fade_in_tween.tween_property(_victory_transition_overlay, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if _victory_transition_label != null:
		_victory_transition_label.scale = Vector2(0.90, 0.90)
		fade_in_tween.tween_property(_victory_transition_label, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _victory_transition_continue_button != null:
		_victory_transition_continue_button.modulate.a = 0.0
		fade_in_tween.tween_property(_victory_transition_continue_button, "modulate:a", 1.0, 0.35).set_delay(0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await fade_in_tween.finished
	if _victory_transition_continue_button != null:
		await _victory_transition_continue_button.pressed

	_victory_transition_active = false
	if camera != null and camera.has_method("set_manual_cinematic_lock"):
		camera.call("set_manual_cinematic_lock", false)
	if _victory_transition_overlay != null:
		var fade_out_tween: Tween = create_tween()
		fade_out_tween.tween_property(_victory_transition_overlay, "modulate:a", 0.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		await fade_out_tween.finished
		_victory_transition_overlay.queue_free()
	_victory_transition_overlay = null
	_victory_transition_label = null
	_victory_transition_subtitle = null
	_victory_transition_continue_button = null
	if hud != null:
		hud.visible = true
	if card_hand != null:
		card_hand.visible = true

func _create_victory_transition_overlay(winner_id: int) -> void:
	if _victory_transition_overlay != null:
		_victory_transition_overlay.queue_free()
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.modulate.a = 0.0
	add_child(overlay)
	_victory_transition_overlay = overlay

	var vignette := ColorRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.color = Color(0.02, 0.02, 0.05, 0.42)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(vignette)

	var title := Label.new()
	title.text = "Victoria" if winner_id != 0 else "Empate"
	title.set_anchors_preset(Control.PRESET_CENTER)
	title.position = Vector2(-260.0, -64.0)
	title.size = Vector2(520.0, 92.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 96)
	title.add_theme_color_override("font_color", Color(0.96, 0.82, 0.28, 1.0) if winner_id == 0 else GameData.get_player_color(winner_id))
	title.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.75))
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 4)
	overlay.add_child(title)
	_victory_transition_label = title

	var subtitle := Label.new()
	subtitle.text = "El Jugador %d domina el campo de batalla" % winner_id if winner_id != 0 else "Ningun bando logro imponerse"
	subtitle.set_anchors_preset(Control.PRESET_CENTER)
	subtitle.position = Vector2(-260.0, 18.0)
	subtitle.size = Vector2(520.0, 28.0)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 24)
	subtitle.add_theme_color_override("font_color", Color(0.90, 0.92, 0.98, 0.96))
	overlay.add_child(subtitle)
	_victory_transition_subtitle = subtitle

	var continue_button := Button.new()
	continue_button.text = "Continuar"
	continue_button.set_anchors_preset(Control.PRESET_CENTER)
	continue_button.position = Vector2(-92.0, 82.0)
	continue_button.size = Vector2(184.0, 42.0)
	continue_button.focus_mode = Control.FOCUS_NONE
	continue_button.add_theme_font_size_override("font_size", 22)
	continue_button.add_theme_color_override("font_color", Color(0.95, 0.95, 0.98, 1.0))
	continue_button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	continue_button.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0, 1.0))
	continue_button.add_theme_color_override("font_focus_color", Color(1.0, 1.0, 1.0, 1.0))
	continue_button.add_theme_stylebox_override("normal", _make_victory_transition_button_style(Color(0.14, 0.11, 0.10, 0.92), Color(0.96, 0.82, 0.28, 0.76)))
	continue_button.add_theme_stylebox_override("hover", _make_victory_transition_button_style(Color(0.18, 0.14, 0.10, 0.98), Color(0.98, 0.88, 0.40, 0.98)))
	continue_button.add_theme_stylebox_override("pressed", _make_victory_transition_button_style(Color(0.20, 0.16, 0.10, 1.0), Color(1.0, 0.90, 0.42, 1.0)))
	continue_button.add_theme_stylebox_override("focus", _make_victory_transition_button_style(Color(0.14, 0.11, 0.10, 0.92), Color(0.98, 0.88, 0.40, 1.0)))
	continue_button.pressed.connect(AudioManager.play_button)
	overlay.add_child(continue_button)
	_victory_transition_continue_button = continue_button

func _update_victory_transition_camera(delta: float) -> void:
	if camera == null:
		return
	_victory_transition_angle += delta * 0.34
	var cam_pos := _victory_transition_center + Vector3(
		cos(_victory_transition_angle) * _victory_transition_radius,
		_victory_transition_height,
		sin(_victory_transition_angle) * _victory_transition_radius
	)
	camera.global_position = cam_pos
	camera.look_at(_victory_transition_center + Vector3(0.0, _victory_transition_focus_height, 0.0), Vector3.UP)

func _make_victory_transition_button_style(bg_color: Color, border_color: Color) -> StyleBoxFlat:
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
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

func _get_rank_name(level_value: int) -> String:
	match level_value:
		Unit.Level.BRONZE:
			return "Bronce"
		Unit.Level.SILVER:
			return "Plata"
		Unit.Level.GOLD:
			return "Oro"
		Unit.Level.PLATINUM:
			return "Platino"
		Unit.Level.DIAMOND:
			return "Diamante"
		_:
			return "Nivel %d" % level_value

func _start_tutorial_if_needed() -> void:
	if hud == null or turn_manager == null:
		return
	if not GameData.tutorial_mode_active:
		return
	if GameData.get_player_mode(1) != "human":
		return
	_tutorial_active = true
	_tutorial_step = 0
	_show_tutorial_step()

func _skip_tutorial() -> void:
	if not _tutorial_active:
		return
	_finish_tutorial(false)

func _finish_tutorial(completed: bool = false) -> void:
	_tutorial_active = false
	_tutorial_step = -1
	_tutorial_waiting_for_summon_explanation = false
	_tutorial_last_placed_cell = Vector2i(-1, -1)
	_tutorial_card_target_mode_active = false
	if hud != null:
		hud.hide_tutorial()
		hud.set_tutorial_focus("")
		hud.set_tutorial_world_markers(false, Vector3.ZERO, false, Vector3.ZERO)
		if completed:
			GameData.mark_tutorial_chapter_completed(GameData.tutorial_chapter_id)
		if completed and hud.has_method("show_tutorial_completion"):
			hud.call("show_tutorial_completion", _get_tutorial_completion_title(), _get_tutorial_completion_body())
	if card_hand != null and card_hand.has_method("set_tutorial_highlight"):
		card_hand.call("set_tutorial_highlight", false)
	if hex_grid != null:
		hex_grid.clear_tutorial_focus_cell()
		hex_grid.clear_highlights()

func _advance_tutorial() -> void:
	if not _tutorial_active:
		return
	_tutorial_step += 1
	if _tutorial_step >= _get_tutorial_steps().size():
		_finish_tutorial(true)
		return
	_show_tutorial_step()

func _show_tutorial_step() -> void:
	if hud == null or not _tutorial_active:
		return
	_tutorial_waiting_for_summon_explanation = false
	var title: String = ""
	var body: String = ""
	var show_next: bool = false
	var chapter_id: String = GameData.tutorial_chapter_id
	var tutorial_key: String = _get_current_tutorial_key()
	match tutorial_key:
		"hud_resources":
			title = "Recursos"
			body = "Aquí ves cuántas torres controlas, tu esencia disponible y la cantidad de unidades en juego. Controlar torres te da esencia por turno y también recompensa con XP a la unidad que las capture."
			show_next = true
		"hud_turn":
			title = "Turno y ciclo"
			body = "Este panel te dice el número de turno y si el combate está de día o de noche. Ese ciclo modifica la lectura del campo, así que conviene mirarlo antes de avanzar."
			show_next = true
		"hud_advantage":
			title = "Puntuación de partida"
			body = "Esta barra resume quién lleva la ventaja considerando torres, ejército, esencia y vida del Maestro."
			show_next = true
		"victory_goal":
			title = "Cómo se gana"
			body = "El objetivo principal es derrotar al Maestro enemigo. Las torres, la esencia y las unidades te ayudan a llegar a ese momento con ventaja."
			show_next = true
		"hud_minimap":
			title = "Minimapa"
			body = "Desde el botón Mapa puedes desplegar una vista rápida del campo para ubicar torres y seguir el frente completo sin recargar la pantalla."
			show_next = true
		"hud_unit_panel":
			title = "Información de unidad"
			body = "Al seleccionar una unidad verás un resumen simple con retrato, vida, experiencia, movimiento y ataque. Ahí mismo puedes seguir su progreso y ver cuánto le falta para subir de nivel."
			show_next = true
		"dice_basics":
			title = "Dados y rango"
			body = "Las filas de dados te dicen quÃ© calidad de tirada usa la unidad. Melee sirve para combate cercano y ranged para disparos o jabalinas. Bronce, Plata, Oro, Platino y Diamante marcan una progresiÃ³n: cuanto mejor el dado, mÃ¡s alto y mÃ¡s estable puede ser el resultado."
			show_next = true
		"hud_cards":
			title = "Cartas"
			body = "Aquí está tu mano. Las cartas dan esencia, daño, curación o experiencia y pueden cambiar un turno."
			show_next = true
		"select_master":
			title = "Selecciona tu Maestro"
			body = "Haz clic sobre tu Maestro para ver sus datos y empezar a moverlo por la grilla."
		"capture_tower":
			title = "Captura una torre"
			body = "Mueve tu Maestro o una unidad propia hacia una torre neutral. Al capturarla ganarás esencia, más ingreso por turno y XP para esa unidad, así que vale la pena pelear por ellas."
		"open_summon":
			if chapter_id == "chapter_2":
				title = "Busca un counter"
				body = "Usa Invocar para buscar un refuerzo. Aquí te conviene una unidad capaz de responder al Jinete enemigo."
			else:
				title = "Abre Invocar"
				body = "Usa el botón Invocar para abrir la lista de unidades disponibles para tu facción."
		"summon_unit":
			if chapter_id == "chapter_2":
				title = "Invoca un Lancero"
				body = "El Lancero rinde bien contra Jinete. Elígelo y colócalo junto a tu Maestro para preparar el contraataque."
			else:
				title = "Invoca una unidad"
				body = "Elige una unidad y colócala en un hexágono válido junto a tu Maestro para reforzar tu frente."
		"terrain_bonus":
			title = "Terreno favorable"
			body = _get_tutorial_terrain_bonus_text()
			show_next = true
		"end_turn":
			title = "Termina tu turno"
			body = "Cuando ya no quieras hacer más acciones, pulsa Fin de turno. Al comenzar tu próximo turno recibirás esencia de tus torres y el ciclo de día o noche seguirá avanzando."
		"combat_response":
			title = "Respuesta en combate"
			body = "En combate cuerpo a cuerpo el enemigo también responde si sigue con vida. Antes del intercambio verás el panel de duelo con los dados de ambos lados y, al final, cada unidad gana XP según su resultado."
			show_next = true
		"attack_enemy":
			if chapter_id == "chapter_2":
				title = "Prueba el counter"
				body = "Selecciona tu nueva unidad y ataca al Jinete resaltado. Así verás cómo una buena invocación cambia el combate."
			elif chapter_id == "chapter_3":
				title = "Aprovecha la carta"
				body = "Ahora que tu Guerrero se recuperó, selecciónalo y ataca al Lancero resaltado. Así verás cómo una carta prepara una mejor jugada."
			else:
				title = "Inicia un ataque"
				body = "Selecciona la unidad que invocaste. Primero te guiará a la siguiente torre neutral y, cuando llegues, te marcará el enemigo adyacente para lanzar tu primer combate."
		"play_card":
			title = "Usa una carta"
			body = "Juega la carta de curación sobre tu Guerrero herido. Así verás cómo las cartas cambian una situación táctica al instante."
		"card_reason":
			title = "Por qué fue buena"
			body = "Esta curación no solo recupera vida. También mantiene tu presión en el frente y deja al Guerrero listo para aprovechar su ventaja contra Lancero."
			show_next = true
		"combat_takeaway":
			title = "Idea clave"
			body = "Las cartas rinden mejor cuando preparan una acción inmediata. Curar, dañar o dar experiencia vale más cuando cambia el combate que viene ahora."
			show_next = true
	if title.strip_edges() == "" and body.strip_edges() == "":
		match tutorial_key:
			"combat_response":
				title = "Respuesta en combate"
				body = "En combate cuerpo a cuerpo el enemigo también responde si sigue con vida. Antes del intercambio verás el panel de duelo con los dados de ambos lados y, al final, cada unidad gana XP según su resultado."
				show_next = true
			"attack_enemy":
				if chapter_id == "chapter_2":
					title = "Prueba el counter"
					body = "Selecciona tu nueva unidad y ataca al Jinete resaltado. Así verás cómo una buena invocación cambia el combate."
				elif chapter_id == "chapter_3":
					title = "Aprovecha la carta"
					body = "Ahora que tu Guerrero se recuperó, selecciónalo y ataca al Lancero resaltado. Así verás cómo una carta prepara una mejor jugada."
				else:
					title = "Inicia un ataque"
					body = "Selecciona la unidad que invocaste. Primero te guiará a la siguiente torre neutral y, cuando llegues, te marcará el enemigo adyacente para lanzar tu primer combate."
	if tutorial_key == "dice_basics":
		title = "Dados y rango"
		body = "Las filas de dados te dicen que calidad de tirada usa la unidad. Melee sirve para combate cercano y ranged para disparos o jabalinas. Bronce, Plata, Oro, Platino y Diamante marcan una progresion: cuanto mejor el dado, mas alto y mas estable puede ser el resultado."
		show_next = true
	elif tutorial_key == "combat_response":
		title = "Respuesta en combate"
		body = "En combate cuerpo a cuerpo el enemigo tambien responde si sigue con vida. Si ambos luchan a distancia y el defensor tiene alcance, el intercambio tambien es ida y vuelta. Antes del choque veras el panel de duelo con los dados de ambos lados."
		show_next = true
	elif tutorial_key == "combat_panel":
		title = "Lectura del duelo"
		body = "El panel de combate resume el intercambio: que dados tiro cada lado, cuantos golpes hubo y cuanto dano salio realmente. Miralo siempre para entender por que un combate salio bien o mal."
		show_next = true
	elif tutorial_key == "exp_and_blessings":
		title = "XP, niveles y Bendiciones"
		body = "Cada combate y captura importante da XP. Cuando una unidad sube de nivel mejora su rango y recibe una Bendicion para especializarse. Ese progreso convierte a las veteranas en piezas unicas."
		show_next = true
	elif tutorial_key == "blessing_result":
		title = "Bendiciones"
		body = "Acabas de elegir una Bendicion. Estas mejoras son permanentes y definen el rol final de cada unidad: mas movilidad, mas defensa, mas alcance, mas golpes o mejor presion segun la eleccion."
		show_next = true
	elif tutorial_key == "combat_takeaway" and chapter_id == "chapter_3":
		title = "Idea clave"
		body = "Las cartas rinden mejor cuando preparan una accion inmediata. Curar, danar o dar experiencia vale mas cuando cambia el combate que viene ahora y, a veces, incluso abre una Bendicion decisiva."
		show_next = true
	hud.show_tutorial_step(_tutorial_step + 1, _get_tutorial_steps().size(), title, body, show_next)
	_update_tutorial_focus_visuals()

func _get_current_tutorial_key() -> String:
	var tutorial_steps: Array[String] = _get_tutorial_steps()
	if _tutorial_step < 0 or _tutorial_step >= tutorial_steps.size():
		return ""
	return str(tutorial_steps[_tutorial_step])

func _get_tutorial_steps() -> Array[String]:
	match GameData.tutorial_chapter_id:
		"chapter_2":
			return _TUTORIAL_STEPS_CHAPTER_2
		"chapter_3":
			return _TUTORIAL_STEPS_CHAPTER_3
		_:
			return _TUTORIAL_STEPS_CHAPTER_1

func _get_tutorial_completion_title() -> String:
	match GameData.tutorial_chapter_id:
		"chapter_2":
			return "Capítulo 2 completado"
		"chapter_3":
			return "Capítulo 3 completado"
		_:
			return "Capítulo 1 completado"

func _get_tutorial_completion_body() -> String:
	match GameData.tutorial_chapter_id:
		"chapter_2":
			return "Aprendiste a invocar una respuesta adecuada y a aprovechar mejor el terreno."
		"chapter_3":
			return "Aprendiste a usar cartas con intención táctica y a convertir un buen combate en una Bendición permanente."
		_:
			return "Aprendiste a leer el tablero, capturar torres, interpretar dados, seguir el panel de duelo y entender cómo la XP lleva a nuevas Bendiciones."

func _on_unit_selected_for_tutorial(unit: Unit) -> void:
	if not _tutorial_active or unit == null:
		return
	match _get_current_tutorial_key():
		"select_master":
			if unit.owner_id == 1 and unit is Master:
				_advance_tutorial()
		"attack_enemy":
			if unit.owner_id != 1:
				return
			if GameData.tutorial_chapter_id == "chapter_1":
				if unit is Master:
					return
				_update_tutorial_focus_visuals()
				return
			if GameData.tutorial_chapter_id != "chapter_2" and GameData.tutorial_chapter_id != "chapter_3":
				return
			var attack_target: Dictionary = _get_tutorial_attack_target()
			var attacker_cell: Vector2i = attack_target.get("attacker_cell", Vector2i(-1, -1))
			var defender_cell: Vector2i = attack_target.get("defender_cell", Vector2i(-1, -1))
			if attacker_cell == Vector2i(-1, -1) or defender_cell == Vector2i(-1, -1):
				return
			if unit.get_hex_cell() != attacker_cell:
				return
			if hud != null:
				hud.set_tutorial_world_markers(false, Vector3.ZERO, true, _tutorial_cell_world(defender_cell))
			if hex_grid != null:
				hex_grid.set_tutorial_focus_cell(defender_cell)
		_:
			return

func _on_tutorial_next_pressed() -> void:
	if not _tutorial_active:
		return
	match _get_current_tutorial_key():
		"hud_resources", "hud_turn", "hud_advantage", "victory_goal", "hud_minimap", "hud_unit_panel", "dice_basics", "hud_cards":
			_advance_tutorial()
		"terrain_bonus":
			_advance_tutorial()
		"combat_response":
			_advance_tutorial()
		"combat_panel":
			_advance_tutorial()
		"exp_and_blessings":
			_advance_tutorial()
		"card_reason":
			_advance_tutorial()
		"blessing_result":
			_advance_tutorial()
		"combat_takeaway":
			_advance_tutorial()
		"summon_unit":
			if _tutorial_waiting_for_summon_explanation:
				_tutorial_waiting_for_summon_explanation = false
				if hud != null and hud.has_method("hide_tutorial_info"):
					hud.call("hide_tutorial_info")
				_advance_tutorial()

func _update_tutorial_focus_visuals() -> void:
	if hud != null:
		hud.set_tutorial_focus("")
		hud.set_tutorial_world_markers(false, Vector3.ZERO, false, Vector3.ZERO)
		if hud.has_method("set_tutorial_custom_focus_rect"):
			hud.call("set_tutorial_custom_focus_rect", Rect2())
	if card_hand != null and card_hand.has_method("set_tutorial_highlight"):
		card_hand.call("set_tutorial_highlight", false)
	if summon_menu != null and summon_menu.has_method("clear_tutorial_focus"):
		summon_menu.call("clear_tutorial_focus")
	if hex_grid != null:
		hex_grid.clear_tutorial_focus_cell()
		hex_grid.clear_highlights()
	if not _tutorial_active or hud == null or hex_grid == null:
		return

	var master_cell: Vector2i = GameData.get_master_cell_for_player(1)
	var master_world: Vector3 = _tutorial_cell_world(master_cell)
	var tower_cell: Vector2i = _get_tutorial_target_tower_cell()
	var tower_world: Vector3 = _tutorial_cell_world(tower_cell)
	var attack_target: Dictionary = _get_tutorial_attack_target()

	match _get_current_tutorial_key():
		"hud_resources":
			hud.set_tutorial_focus("resources")
		"hud_turn":
			hud.set_tutorial_focus("turn")
		"hud_advantage":
			hud.set_tutorial_focus("advantage")
		"hud_minimap":
			hud.set_tutorial_focus("minimap")
		"hud_unit_panel":
			hud.set_tutorial_focus("unit_panel")
		"dice_basics":
			hud.set_tutorial_focus("unit_panel")
		"hud_cards":
			if hud != null and hud.has_method("set_tutorial_custom_focus_rect") and card_hand != null and card_hand.has_method("get_tutorial_focus_rect"):
				hud.call("set_tutorial_custom_focus_rect", card_hand.call("get_tutorial_focus_rect"))
			if card_hand != null and card_hand.has_method("set_tutorial_highlight"):
				card_hand.call("set_tutorial_highlight", true)
			hud.set_tutorial_focus("cards")
		"play_card":
			if _tutorial_card_target_mode_active:
				hud.set_tutorial_world_markers(false, Vector3.ZERO, false, Vector3.ZERO)
				hud.set_tutorial_focus("")
				var card_target_cell: Vector2i = _get_tutorial_card_target_cell()
				if card_target_cell != Vector2i(-1, -1):
					hud.set_tutorial_world_markers(false, Vector3.ZERO, true, _tutorial_cell_world(card_target_cell))
					hex_grid.set_tutorial_focus_cell(card_target_cell)
			else:
				if hud != null and hud.has_method("set_tutorial_custom_focus_rect") and card_hand != null and card_hand.has_method("get_card_focus_rect"):
					hud.call("set_tutorial_custom_focus_rect", card_hand.call("get_card_focus_rect", _get_tutorial_card_index()))
				if card_hand != null and card_hand.has_method("set_tutorial_highlight"):
					card_hand.call("set_tutorial_highlight", true)
				hud.set_tutorial_focus("cards")
		"card_reason":
			hud.set_tutorial_world_markers(false, Vector3.ZERO, false, Vector3.ZERO)
			hud.set_tutorial_focus("")
			var healed_cell: Vector2i = _get_tutorial_card_target_cell()
			if healed_cell != Vector2i(-1, -1):
				hex_grid.set_tutorial_focus_cell(healed_cell)
		"select_master":
			hud.set_tutorial_world_markers(master_cell != Vector2i(-1, -1), master_world, false, Vector3.ZERO)
			if master_cell != Vector2i(-1, -1):
				hex_grid.set_tutorial_focus_cell(master_cell)
		"capture_tower":
			hud.set_tutorial_world_markers(false, Vector3.ZERO, tower_cell != Vector2i(-1, -1), tower_world)
			if tower_cell != Vector2i(-1, -1):
				hex_grid.set_tutorial_focus_cell(tower_cell)
		"open_summon":
			hud.set_tutorial_world_markers(false, Vector3.ZERO, false, Vector3.ZERO)
			hud.set_tutorial_focus("summon")
		"summon_unit":
			var is_summon_menu_open: bool = summon_menu != null and summon_menu.visible
			var summon_cell: Vector2i = _get_tutorial_preferred_summon_cell()
			var summon_world: Vector3 = _tutorial_cell_world(summon_cell) if summon_cell != Vector2i(-1, -1) else Vector3.ZERO
			hud.set_tutorial_world_markers(false, Vector3.ZERO, (not is_summon_menu_open) and summon_cell != Vector2i(-1, -1), summon_world)
			hud.set_tutorial_focus("")
			if summon_menu != null and summon_menu.has_method("set_tutorial_focus_unit"):
				summon_menu.call("set_tutorial_focus_unit", _get_tutorial_focus_unit_type())
			if not is_summon_menu_open and summon_cell != Vector2i(-1, -1):
				hex_grid.set_tutorial_focus_cell(summon_cell)
		"terrain_bonus":
			hud.set_tutorial_world_markers(false, Vector3.ZERO, false, Vector3.ZERO)
			hud.set_tutorial_focus("")
			var terrain_focus_cell: Vector2i = _get_tutorial_terrain_focus_cell()
			if terrain_focus_cell != Vector2i(-1, -1):
				hex_grid.set_tutorial_focus_cell(terrain_focus_cell)
		"end_turn":
			hud.set_tutorial_world_markers(false, Vector3.ZERO, false, Vector3.ZERO)
			hud.set_tutorial_focus("end_turn")
		"attack_enemy":
			var attacker_cell: Vector2i = attack_target.get("attacker_cell", Vector2i(-1, -1))
			hud.set_tutorial_focus("")
			var defender_cell: Vector2i = attack_target.get("defender_cell", Vector2i(-1, -1))
			if GameData.tutorial_chapter_id == "chapter_1":
				var summoned_cell: Vector2i = _get_tutorial_chapter_1_summoned_cell()
				var objective_cell: Vector2i = _get_tutorial_chapter_1_objective_cell(summoned_cell)
				var objective_world: Vector3 = _tutorial_cell_world(objective_cell)
				if summoned_cell != Vector2i(-1, -1):
					hud.set_tutorial_world_markers(true, _tutorial_cell_world(summoned_cell), objective_cell != Vector2i(-1, -1), objective_world)
					hex_grid.set_tutorial_focus_cell(objective_cell if objective_cell != Vector2i(-1, -1) else summoned_cell)
				else:
					hud.set_tutorial_world_markers(false, Vector3.ZERO, false, Vector3.ZERO)
			elif (GameData.tutorial_chapter_id == "chapter_2" or GameData.tutorial_chapter_id == "chapter_3") and attacker_cell != Vector2i(-1, -1):
				hud.set_tutorial_world_markers(true, _tutorial_cell_world(attacker_cell), false, Vector3.ZERO)
				hex_grid.set_tutorial_focus_cell(attacker_cell)
			else:
				hud.set_tutorial_world_markers(false, Vector3.ZERO, false, Vector3.ZERO)
				if defender_cell != Vector2i(-1, -1):
					hex_grid.set_tutorial_focus_cell(defender_cell)
		"combat_takeaway":
			hud.set_tutorial_world_markers(false, Vector3.ZERO, false, Vector3.ZERO)
			hud.set_tutorial_focus("")
		"combat_panel":
			hud.set_tutorial_world_markers(false, Vector3.ZERO, false, Vector3.ZERO)
			hud.set_tutorial_focus("")
		"exp_and_blessings":
			hud.set_tutorial_world_markers(false, Vector3.ZERO, false, Vector3.ZERO)
			hud.set_tutorial_focus("unit_panel")
		"blessing_result":
			hud.set_tutorial_world_markers(false, Vector3.ZERO, false, Vector3.ZERO)
			hud.set_tutorial_focus("unit_panel")
		
func _get_tutorial_focus_unit_type() -> int:
	if GameData.tutorial_chapter_id == "chapter_2":
		return UnitScript.UnitType.LANCER
	return UnitScript.UnitType.WARRIOR

func _get_tutorial_preferred_summon_cell() -> Vector2i:
	if GameData.tutorial_chapter_id == "chapter_2":
		return Vector2i(3, 3)
	if GameData.tutorial_chapter_id == "chapter_1":
		return Vector2i(4, 4)
	return Vector2i(-1, -1)

func _get_tutorial_terrain_focus_cell() -> Vector2i:
	if _tutorial_last_placed_cell != Vector2i(-1, -1):
		return _tutorial_last_placed_cell
	return _get_tutorial_preferred_summon_cell()

func _get_tutorial_terrain_bonus_text() -> String:
	if hex_grid == null:
		return "El terreno puede cambiar tu combate: montaña y bosque dan más golpes, mientras agua te debilita."
	var focus_cell: Vector2i = _get_tutorial_terrain_focus_cell()
	var terrain: int = hex_grid.get_terrain_at(focus_cell.x, focus_cell.y) if focus_cell != Vector2i(-1, -1) else 0
	match terrain:
		2:
			return "Montaña da +2 ataques, aunque cuesta más moverse. Vale la pena cuando quieres pegar más fuerte desde una buena posición."
		3:
			return "Bosque da +1 ataque, aunque cuesta 2 de movimiento. En este capítulo conviene porque tu Lancero llega al combate con un golpe extra."
		1:
			return "Agua reduce tus ataques en 1, así que evita pelear desde ahí cuando puedas."
		_:
			return "Pasto y arena no dan bonus. Montaña y bosque sí mejoran tu ataque, y agua lo empeora."

func _get_tutorial_target_tower_cell() -> Vector2i:
	if hex_grid == null:
		return Vector2i(-1, -1)
	var towers: Array = hex_grid.get_all_towers()
	var origin: Vector2i = GameData.get_master_cell_for_player(1)
	var best_cell: Vector2i = Vector2i(-1, -1)
	var best_distance: int = 1_000_000
	for tower_value: Variant in towers:
		var tower: Tower = tower_value as Tower
		if tower == null or tower.owner_id != 0:
			continue
		var dist: int = hex_grid.get_distance_between_cells(origin, tower.position)
		if dist < best_distance:
			best_distance = dist
			best_cell = tower.position
	return best_cell

func _tutorial_cell_world(cell: Vector2i) -> Vector3:
	if hex_grid == null or cell == Vector2i(-1, -1):
		return Vector3.ZERO
	return hex_grid.hex_to_world(cell.x, cell.y)

func _get_tutorial_chapter_1_summoned_cell() -> Vector2i:
	if hex_grid == null or not hex_grid.has_method("get_all_units"):
		return Vector2i(-1, -1)
	var best_cell: Vector2i = Vector2i(-1, -1)
	var best_distance: int = 1_000_000
	for unit_value: Variant in hex_grid.get_all_units():
		var unit: Unit = unit_value as Unit
		if unit == null or unit.owner_id != 1 or unit is Master:
			continue
		var cell: Vector2i = hex_grid.get_cell_for_unit(unit)
		if cell == Vector2i(-1, -1):
			continue
		if _tutorial_last_placed_cell == Vector2i(-1, -1):
			return cell
		var distance: int = hex_grid.get_distance_between_cells(_tutorial_last_placed_cell, cell)
		if distance < best_distance:
			best_distance = distance
			best_cell = cell
	return best_cell

func _get_tutorial_chapter_1_objective_cell(attacker_cell: Vector2i) -> Vector2i:
	if attacker_cell == Vector2i(-1, -1) or hex_grid == null:
		return Vector2i(-1, -1)
	var current_tower: Tower = hex_grid.get_tower_at(attacker_cell.x, attacker_cell.y)
	if current_tower != null and current_tower.owner_id == 1:
		var enemy_cell: Vector2i = _get_tutorial_chapter_1_enemy_cell(attacker_cell)
		if enemy_cell != Vector2i(-1, -1):
			return enemy_cell
	var best_cell: Vector2i = Vector2i(-1, -1)
	var best_distance: int = 1_000_000
	for tower_value: Variant in hex_grid.get_all_towers():
		var tower: Tower = tower_value as Tower
		if tower == null or tower.owner_id != 0:
			continue
		var distance: int = hex_grid.get_distance_between_cells(attacker_cell, tower.position)
		if distance < best_distance:
			best_distance = distance
			best_cell = tower.position
	return best_cell

func _get_tutorial_chapter_1_enemy_cell(attacker_cell: Vector2i) -> Vector2i:
	if attacker_cell == Vector2i(-1, -1) or hex_grid == null:
		return Vector2i(-1, -1)
	var attacker: Unit = hex_grid.get_unit_at(attacker_cell.x, attacker_cell.y)
	if attacker == null or attacker.owner_id != 1:
		return Vector2i(-1, -1)
	var options: Dictionary = hex_grid.get_action_options_for_unit(attacker)
	var attack_cells: Array = options.get("attack_cells", [])
	if attack_cells.is_empty():
		return Vector2i(-1, -1)
	var best_cell: Vector2i = Vector2i(-1, -1)
	var best_distance: int = 1_000_000
	for target_value: Variant in attack_cells:
		if not (target_value is Vector2i):
			continue
		var target_cell: Vector2i = target_value as Vector2i
		var distance: int = hex_grid.get_distance_between_cells(attacker_cell, target_cell)
		if distance < best_distance:
			best_distance = distance
			best_cell = target_cell
	return best_cell

func _get_tutorial_attack_target() -> Dictionary:
	if hex_grid == null or not hex_grid.has_method("get_all_units"):
		return {}
	if GameData.tutorial_chapter_id == "chapter_2" and _tutorial_last_placed_cell != Vector2i(-1, -1):
		var preferred_attacker: Unit = hex_grid.get_unit_at(_tutorial_last_placed_cell.x, _tutorial_last_placed_cell.y)
		if preferred_attacker != null and preferred_attacker.owner_id == 1:
			var preferred_options: Dictionary = hex_grid.get_action_options_for_unit(preferred_attacker)
			var preferred_attack_cells: Array = preferred_options.get("attack_cells", [])
			if not preferred_attack_cells.is_empty():
				var best_defender_cell: Vector2i = Vector2i(-1, -1)
				var best_distance_for_preferred: int = 1_000_000
				var origin_for_preferred: Vector2i = GameData.get_master_cell_for_player(1)
				for target_value: Variant in preferred_attack_cells:
					if not (target_value is Vector2i):
						continue
					var defender_cell_for_preferred: Vector2i = target_value as Vector2i
					var preferred_distance: int = hex_grid.get_distance_between_cells(origin_for_preferred, defender_cell_for_preferred)
					if preferred_distance < best_distance_for_preferred:
						best_distance_for_preferred = preferred_distance
						best_defender_cell = defender_cell_for_preferred
				if best_defender_cell != Vector2i(-1, -1):
					return {
						"attacker_cell": _tutorial_last_placed_cell,
						"defender_cell": best_defender_cell,
					}
	var best_choice: Dictionary = {}
	var best_distance: int = 1_000_000
	var origin: Vector2i = GameData.get_master_cell_for_player(1)
	for unit_value: Variant in hex_grid.get_all_units():
		var unit: Unit = unit_value as Unit
		if unit == null or unit.owner_id != 1:
			continue
		var options: Dictionary = hex_grid.get_action_options_for_unit(unit)
		var attacker_cell: Vector2i = options.get("cell", Vector2i(-1, -1))
		var attack_cells: Array = options.get("attack_cells", [])
		if attacker_cell == Vector2i(-1, -1) or attack_cells.is_empty():
			continue
		for target_value: Variant in attack_cells:
			if not (target_value is Vector2i):
				continue
			var defender_cell: Vector2i = target_value as Vector2i
			var distance: int = hex_grid.get_distance_between_cells(origin, defender_cell)
			if distance < best_distance:
				best_distance = distance
				best_choice = {
					"attacker_cell": attacker_cell,
					"defender_cell": defender_cell,
				}
	return best_choice

func _get_tutorial_card_target_cell() -> Vector2i:
	if hex_grid == null or not hex_grid.has_method("get_all_units"):
		return Vector2i(-1, -1)
	for unit_value: Variant in hex_grid.get_all_units():
		var unit: Unit = unit_value as Unit
		if unit == null or unit.owner_id != 1:
			continue
		if unit.hp < unit.max_hp and not (unit is Master):
			return hex_grid.get_cell_for_unit(unit)
	return Vector2i(-1, -1)

func _get_tutorial_card_index() -> int:
	if card_hand == null or turn_manager == null:
		return 0
	var hand: Array = CardManager.get_hand(turn_manager.current_player)
	for i: int in range(hand.size()):
		var card: Dictionary = hand[i]
		if str(card.get("type", "")) == "heal":
			return i
	return 0

func _on_tutorial_card_target_mode_changed(active: bool) -> void:
	_tutorial_card_target_mode_active = active
	if _tutorial_active and _get_current_tutorial_key() == "play_card":
		_update_tutorial_focus_visuals()

func _get_summon_counter_hint(unit_type: int) -> String:
	for pair: Array in UnitScript.COUNTER_CHART:
		if int(pair[0]) == unit_type:
			return "Rinde bien contra %s." % _get_unit_display_name(int(pair[1]))
	match unit_type:
		UnitScript.UnitType.ARCHER:
			return "Ataca a distancia y ayuda a abrir combate."
		UnitScript.UnitType.RIDER:
			return "Sirve para moverse rapido y presionar flancos."
		_:
			return ""

func _get_unit_display_name(unit_type: int) -> String:
	match unit_type:
		UnitScript.UnitType.WARRIOR:
			return "Guerrero"
		UnitScript.UnitType.ARCHER:
			return "Arquero"
		UnitScript.UnitType.LANCER:
			return "Lancero"
		UnitScript.UnitType.RIDER:
			return "Jinete"
		_:
			return "Unidad"

func _has_saved_match_state() -> bool:
	return GameData.has_loaded_match_state and not GameData.loaded_match_state.is_empty()

func _capture_save_state() -> Dictionary:
	return {
		"turn_manager": turn_manager.serialize_state() if turn_manager != null and turn_manager.has_method("serialize_state") else {},
		"resource_manager": resource_manager.serialize_state() if resource_manager != null and resource_manager.has_method("serialize_state") else {},
		"card_manager": CardManager.serialize_state() if CardManager != null and CardManager.has_method("serialize_state") else {},
		"hex_grid": hex_grid.serialize_state() if hex_grid != null and hex_grid.has_method("serialize_state") else {},
		"summoned_by_player": _summoned_by_player.duplicate(true),
		"towers_by_player": _towers_by_player.duplicate(true),
		"cards_used_by_player": _cards_used_by_player.duplicate(true),
		"kills_by_player": _kills_by_player.duplicate(true),
		"timeline_snapshots": _timeline_snapshots.duplicate(true),
	}

func _save_current_game() -> void:
	GameData.winner_id = 0
	GameData.turns_played = turn_manager.turn_number if turn_manager != null else 0
	GameData.save_match_in_progress("res://scenes/Main3D.tscn", _capture_save_state())
	print("[Main3D] Partida guardada.")

func _restore_saved_game() -> void:
	var saved_state: Dictionary = GameData.loaded_match_state
	_clear_transient_board_state(true)
	if resource_manager != null and resource_manager.has_method("load_state"):
		resource_manager.load_state(saved_state.get("resource_manager", {}))
	if turn_manager != null and turn_manager.has_method("load_state"):
		turn_manager.load_state(saved_state.get("turn_manager", {}))
	if hex_grid != null and hex_grid.has_method("restore_saved_state"):
		hex_grid.restore_saved_state(saved_state.get("hex_grid", {}))
	if CardManager != null and CardManager.has_method("load_state"):
		CardManager.load_state(saved_state.get("card_manager", {}))
	_summoned_by_player = (saved_state.get("summoned_by_player", {}) as Dictionary).duplicate(true)
	_towers_by_player = (saved_state.get("towers_by_player", {}) as Dictionary).duplicate(true)
	_cards_used_by_player = (saved_state.get("cards_used_by_player", {}) as Dictionary).duplicate(true)
	_kills_by_player = (saved_state.get("kills_by_player", {}) as Dictionary).duplicate(true)
	_timeline_snapshots = (saved_state.get("timeline_snapshots", []) as Array).duplicate(true)
	for player_id: int in GameData.get_player_ids():
		if not _summoned_by_player.has(player_id):
			_summoned_by_player[player_id] = 0
		if not _towers_by_player.has(player_id):
			_towers_by_player[player_id] = 0
		if not _cards_used_by_player.has(player_id):
			_cards_used_by_player[player_id] = 0
		if not _kills_by_player.has(player_id):
			_kills_by_player[player_id] = 0
	if _timeline_snapshots.is_empty():
		_record_timeline_snapshot(turn_manager.turn_number if turn_manager != null else 1)
	if hud != null:
		hud.update_turn(turn_manager.current_player)
		hud.update_essence(turn_manager.current_player, resource_manager.get_essence(turn_manager.current_player))
		hud.refresh_towers()
	if card_hand != null and card_hand.has_method("refresh_hand"):
		card_hand.refresh_hand()
	GameData.clear_loaded_match_cache()

func _on_summon_completed(player_id: int, _unit: Unit, _free_summon: bool) -> void:
	_summoned_by_player[player_id] = int(_summoned_by_player.get(player_id, 0)) + 1
	_record_timeline_snapshot(turn_manager.turn_number if turn_manager != null else 1)

func _record_timeline_snapshot(turn_number: int) -> void:
	var players: Array[int] = GameData.get_player_ids()
	if players.is_empty():
		return
	if not _timeline_snapshots.is_empty():
		var last_entry: Dictionary = _timeline_snapshots[_timeline_snapshots.size() - 1] as Dictionary
		if int(last_entry.get("turn", -1)) == turn_number:
			_timeline_snapshots[_timeline_snapshots.size() - 1] = _make_timeline_snapshot(turn_number, players)
			return
	_timeline_snapshots.append(_make_timeline_snapshot(turn_number, players))

func _make_timeline_snapshot(turn_number: int, players: Array[int]) -> Dictionary:
	var values: Dictionary = {}
	for player_id: int in players:
		values[player_id] = _compute_timeline_score(player_id)
	return {"turn": turn_number, "players": values}

func _compute_timeline_score(player_id: int) -> int:
	var units_alive: int = 0
	var towers_owned: int = 0
	var highest_level: int = 0
	if hex_grid != null and hex_grid.has_method("get_units_for_player"):
		for unit: Unit in hex_grid.get_units_for_player(player_id):
			if unit == null:
				continue
			units_alive += 1
			highest_level = maxi(highest_level, int(unit.level))
	if hex_grid != null and hex_grid.has_method("get_all_towers"):
		for tower_value: Variant in hex_grid.get_all_towers():
			var tower: Tower = tower_value as Tower
			if tower != null and tower.owner_id == player_id:
				towers_owned += 1
	var essence_now: int = resource_manager.get_essence(player_id) if resource_manager != null and resource_manager.has_method("get_essence") else 0
	var kills: int = int(_kills_by_player.get(player_id, 0))
	return units_alive * 4 + towers_owned * 6 + highest_level * 3 + int(round(float(essence_now) * 0.35)) + kills * 2
