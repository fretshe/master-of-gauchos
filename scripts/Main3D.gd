extends Node3D

const HexGrid3DScript       := preload("res://scripts/HexGrid3D.gd")
const TurnManagerScript     := preload("res://scripts/TurnManager.gd")
const CombatManagerScript   := preload("res://scripts/CombatManager.gd")
const ResourceManagerScript := preload("res://scripts/ResourceManager.gd")
const SummonManagerScript   := preload("res://scripts/SummonManager.gd")
const MapGeneratorScript    := preload("res://scripts/MapGenerator.gd")
const HUDScene              := preload("res://scenes/HUD.tscn")
const CardHandScene         := preload("res://scenes/CardHand.tscn")
const SummonMenuScene       := preload("res://scenes/SummonMenu.tscn")
const SimpleAIScript        := preload("res://scripts/SimpleAI.gd")
const StarsDomeShader       := preload("res://shaders/stars_dome.gdshader")

# Untyped — all game systems are accessed via dynamic dispatch, same as Main.gd
var hex_grid         = null
var turn_manager     = null
var resource_manager = null
var summon_manager   = null
var hud              = null
var card_hand        = null
var summon_menu      = null
var ai_controller    = null
var camera: Camera3D = null
var _sun_light: DirectionalLight3D = null
var _fill_light: DirectionalLight3D = null
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
var _current_is_night: Variant = null
var _hovered_hud_unit: Unit = null

# ─── Game stats (collected for GameOver screen) ─────────────────────────────────
var _summoned_by_player: Dictionary = {}
var _towers_by_player: Dictionary = {}
var _master_summoning: bool = false
var _master_for_free_summon: Unit = null

# ─── Master free-summon tracking ────────────────────────────────────────────────
func _ready() -> void:
	for player_id: int in GameData.get_player_ids():
		_summoned_by_player[player_id] = 0
		_towers_by_player[player_id] = 0
	# ── Generate map ─────────────────────────────────────────────────────────
	if GameData.map_terrain.size() == 0:
		_generate_map()

	# ── Combat manager (RefCounted — not a node) ──────────────────────────────
	var combat_manager: RefCounted = CombatManagerScript.new()

	# ── Resource manager ──────────────────────────────────────────────────────
	resource_manager      = ResourceManagerScript.new()
	resource_manager.name = "ResourceManager"
	add_child(resource_manager)
	resource_manager.setup_players(GameData.player_count)
	CardManager.resource_manager = resource_manager
	CardManager.setup_deck()

	# ── Hex grid ──────────────────────────────────────────────────────────────
	hex_grid                  = HexGrid3DScript.new()
	hex_grid.name             = "HexGrid3D"
	hex_grid.combat_manager   = combat_manager
	hex_grid.resource_manager = resource_manager
	add_child(hex_grid)
	CardManager.hex_grid = hex_grid

	resource_manager.hex_grid = hex_grid   # cross-link after both in tree

	# ── Turn manager ──────────────────────────────────────────────────────────
	turn_manager                  = TurnManagerScript.new()
	turn_manager.name             = "TurnManager"
	turn_manager.hex_grid         = hex_grid
	turn_manager.resource_manager = resource_manager
	add_child(turn_manager)

	# ── Summon manager ────────────────────────────────────────────────────────
	summon_manager                  = SummonManagerScript.new()
	summon_manager.name             = "SummonManager"
	summon_manager.hex_grid         = hex_grid
	summon_manager.resource_manager = resource_manager
	add_child(summon_manager)

	# ── HUD ───────────────────────────────────────────────────────────────────
	hud                  = HUDScene.instantiate()
	hud.turn_manager     = turn_manager
	hud.resource_manager = resource_manager
	hud.hex_grid         = hex_grid
	add_child(hud)

	card_hand = CardHandScene.instantiate()
	card_hand.turn_manager = turn_manager
	card_hand.hex_grid = hex_grid
	add_child(card_hand)

	# ── Summon menu ───────────────────────────────────────────────────────────
	summon_menu = SummonMenuScene.instantiate()
	add_child(summon_menu)

	ai_controller = SimpleAIScript.new()
	ai_controller.hex_grid = hex_grid
	ai_controller.resource_manager = resource_manager
	ai_controller.summon_manager = summon_manager
	ai_controller.hud = hud
	add_child(ai_controller)

	# ── Signal wiring ─────────────────────────────────────────────────────────
	hud.end_turn_pressed.connect(turn_manager.end_turn)
	hud.summon_pressed.connect(_open_summon_menu)

	summon_menu.unit_type_chosen.connect(_on_unit_type_chosen)
	summon_menu.cancelled.connect(_on_summon_cancelled)

	hex_grid.unit_selected.connect(hud.show_unit)
	hex_grid.unit_deselected.connect(hud.hide_unit)
	hex_grid.unit_hovered.connect(_on_unit_hovered)
	hex_grid.unit_hover_cleared.connect(_on_unit_hover_cleared)
	hex_grid.enemy_inspected.connect(_on_enemy_inspected)
	hex_grid.combat_resolved.connect(_on_combat_resolved)
	hex_grid.card_target_selected.connect(_on_card_target_selected)
	hex_grid.tower_captured.connect(_on_tower_captured)
	hex_grid.placement_confirmed.connect(_on_placement_confirmed)
	hex_grid.master_killed.connect(turn_manager.handle_master_killed)
	turn_manager.turn_changed.connect(_on_turn_changed)
	turn_manager.game_over.connect(_on_game_over)
	resource_manager.resources_changed.connect(hud.update_essence)
	CardManager.card_resolved.connect(_on_card_resolved)
	CardManager.unit_killed_by_card.connect(_on_unit_killed_by_card)

	hud.refresh_towers()
	CardManager.draw_card(turn_manager.current_player)

	# ── Lighting ──────────────────────────────────────────────────────────────
	_setup_lighting()

	# ── Camera ────────────────────────────────────────────────────────────────
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

	# ── Place initial units (masters) ─────────────────────────────────────────
	var units_node: Node3D = $Units
	hex_grid.units_container = units_node
	hex_grid.setup_units()
	if _world_environment != null:
		_apply_unit_time_lighting(_capture_lighting_profile())
	_play_intro_camera_sequence()

	MusicManager.play_battle_music(1)
	print("[Main3D] Mapa 3D listo — WASD/↑↓←→: mover | Rueda: zoom | Clic derecho: rotar")
	print("[Main3D] Enter: fin de turno | E: invocar | Esc: cancelar")
	print("[Main3D] Esencia inicial — J1: %d  |  J2: %d" % [
			resource_manager.get_essence(1), resource_manager.get_essence(2)])

# ─── Map generation ──────────────────────────────────────────────────────────────
func _generate_map() -> void:
	var gen:       RefCounted    = MapGeneratorScript.new()
	var map_types: Array[String] = ["plains", "mountains", "volcanic"]
	var map_type:  String        = map_types[GameData.current_map]
	var seed_val:  int           = GameData.map_seed if GameData.map_seed > 0 else randi()
	gen.generate(seed_val, map_type, GameData.map_size)
	GameData.map_terrain         = gen.get_terrain()
	GameData.map_tower_positions = gen.get_tower_positions()
	GameData.map_master_p1       = gen.get_master_p1_cell()
	GameData.map_master_p2       = gen.get_master_p2_cell()
	GameData.map_master_p3       = gen.get_master_p3_cell()
	GameData.map_master_p4       = gen.get_master_p4_cell()
	GameData.map_seed            = gen.get_seed()
	print("[Main3D] Mapa generado: tipo=%s semilla=%d | Maestro J1=%s J2=%s J3=%s J4=%s" % [
			map_type, GameData.map_seed,
			str(GameData.map_master_p1), str(GameData.map_master_p2),
			str(GameData.map_master_p3), str(GameData.map_master_p4)])

# ─── Input ───────────────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if turn_manager != null and GameData.get_player_mode(turn_manager.current_player) == "ai":
		return
	match event.keycode:
		KEY_ENTER, KEY_KP_ENTER:
			turn_manager.end_turn()
		KEY_E:
			_open_summon_menu()
		KEY_ESCAPE:
			hex_grid.exit_placement_mode()
			hex_grid.exit_card_target_mode()
			hex_grid.deselect()

func _process(delta: float) -> void:
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

# ─── Lighting setup ──────────────────────────────────────────────────────────────
func _setup_lighting() -> void:
	# ── Sun (key light) ────────────────────────────────────────────────────────
	_sun_light = DirectionalLight3D.new()
	_sun_light.shadow_enabled                  = true
	_sun_light.directional_shadow_mode         = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	_sun_light.directional_shadow_blend_splits = true
	_sun_light.shadow_opacity                  = 0.78
	_sun_light.shadow_bias                     = 0.03
	_sun_light.shadow_normal_bias              = 1.1
	add_child(_sun_light)

	# ── Fill light (sky bounce) ────────────────────────────────────────────────
	_fill_light = DirectionalLight3D.new()
	_fill_light.shadow_enabled   = false
	add_child(_fill_light)

	# ── World environment ──────────────────────────────────────────────────────
	var env: Environment = Environment.new()

	_sky_material = ProceduralSkyMaterial.new()
	_sky_material.use_debanding = true

	var sky := Sky.new()
	sky.sky_material = _sky_material

	env.background_mode  = Environment.BG_SKY
	env.sky = sky
	env.glow_enabled = true
	env.glow_intensity = 1.15
	env.glow_strength = 0.92
	env.glow_mix = 0.18
	env.glow_bloom = 0.16
	env.glow_hdr_threshold = 0.9
	env.set_glow_level(0, 0.0)
	env.set_glow_level(1, 0.0)
	env.set_glow_level(2, 0.12)
	env.set_glow_level(3, 0.26)
	env.set_glow_level(4, 0.22)
	env.set_glow_level(5, 0.14)
	env.set_glow_level(6, 0.06)

	# Warm amber ambient — #fff5e0 ≈ (1.00, 0.96, 0.88)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color  = Color(0.86, 0.56, 0.46)
	env.ambient_light_energy = 0.52

	# Filmic tonemapping for a cinematic HD-2D look
	env.tonemap_mode     = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.12
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.03
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.12

	# Subtle depth fog for atmospheric perspective
	env.fog_enabled           = true
	env.fog_density           = 0.0045
	env.fog_light_color       = Color(1.00, 0.53, 0.33)
	env.fog_sun_scatter       = 0.18
	env.fog_aerial_perspective = 0.28

	_world_environment = WorldEnvironment.new()
	_world_environment.environment = env
	add_child(_world_environment)

	_setup_star_dome()
	_setup_ambient_motes()
	_setup_night_motes()
	_setup_vignette()
	_apply_time_of_day(1)

func _setup_vignette() -> void:
	var shader: Shader          = load("res://shaders/vignette.gdshader")
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

func _setup_star_dome() -> void:
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
		return
	if _current_is_night == is_night:
		return

	var start_profile: Dictionary = _capture_lighting_profile()
	_current_is_night = is_night
	if _lighting_tween != null:
		_lighting_tween.kill()
	_lighting_tween = create_tween()
	_lighting_tween.tween_method(
		func(weight: float) -> void:
			_apply_lighting_profile(_lerp_lighting_profile(start_profile, target_profile, weight)),
		0.0, 1.0, 1.6
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

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
			"fog_density": 0.0026,
			"fog_light_color": Color(0.12, 0.16, 0.28),
			"fog_sun_scatter": 0.08,
			"fog_aerial_perspective": 0.10,
			"vignette_strength": 0.70,
			"star_visibility": 0.75,
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
		"fog_density": 0.0045,
		"fog_light_color": Color(1.00, 0.53, 0.33),
		"fog_sun_scatter": 0.18,
		"fog_aerial_perspective": 0.28,
		"vignette_strength": 0.65,
		"star_visibility": 0.0,
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
	if _vignette_material != null:
		_vignette_material.set_shader_parameter("strength", profile["vignette_strength"])
	if _stars_material != null:
		_stars_material.set_shader_parameter("star_visibility", profile["star_visibility"])
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


# ─── Handlers ────────────────────────────────────────────────────────────────────
func _open_summon_menu() -> void:
	summon_menu.show_for_player(turn_manager.current_player, resource_manager)

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
	hud.show_placement_hint()

func _on_summon_cancelled() -> void:
	hex_grid.exit_placement_mode()

func _on_tower_captured(_tower_name: String, player_id: int) -> void:
	_towers_by_player[player_id] = int(_towers_by_player.get(player_id, 0)) + 1
	hud.refresh_towers()

func _on_placement_confirmed(col: int, row: int, unit_type: int, player_id: int) -> void:
	summon_manager.summon(unit_type, col, row, player_id)
	hud.hide_placement_hint()
	hud.refresh_towers()
	_summoned_by_player[player_id] = int(_summoned_by_player.get(player_id, 0)) + 1
	var placed: Unit = hex_grid.get_unit_at(col, row)
	if placed != null:
		hud.show_unit(placed)
		_apply_unit_time_lighting(_capture_lighting_profile())

func _on_card_target_selected(card_index: int, target_unit: Unit) -> void:
	var current_player_id: int = turn_manager.current_player
	var played: bool = CardManager.play_card(current_player_id, card_index, target_unit)
	if not played:
		return
	if is_instance_valid(target_unit) and target_unit.hp > 0:
		hud.show_unit(target_unit)
	else:
		hud.hide_unit()

func _on_unit_killed_by_card(unit: Unit, _killer_player_id: int) -> void:
	var was_master: bool = unit is Master
	var owner_id: int = unit.owner_id
	hex_grid.remove_unit(unit)
	hud.hide_unit()
	if was_master:
		turn_manager.handle_master_killed(owner_id)

func _on_card_resolved(player_id: int, card: Dictionary, target_unit: Unit) -> void:
	if turn_manager == null or player_id != turn_manager.current_player:
		return

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

func _on_master_placement_confirmed(col: int, row: int, unit_type: int, player_id: int) -> void:
	return
	summon_manager.summon_free(unit_type, col, row, player_id)
	if _master_for_free_summon != null:
		_master_for_free_summon.free_summon_used = true
		_master_for_free_summon = null
	hud.hide_placement_hint()
	hud.refresh_towers()
	_summoned_by_player[player_id] = int(_summoned_by_player.get(player_id, 0)) + 1
	var placed: Unit = hex_grid.get_unit_at(col, row)
	if placed != null:
		hud.show_unit(placed)
		_apply_unit_time_lighting(_capture_lighting_profile())

func _on_enemy_inspected(_enemy: Unit, multiplier: float) -> void:
	hud.show_advantage(multiplier)

func _on_unit_hovered(unit: Unit) -> void:
	if hud == null or unit == null:
		return
	_hovered_hud_unit = unit
	hud.show_unit(unit)

func _on_unit_hover_cleared() -> void:
	_hovered_hud_unit = null
	if hud == null or hex_grid == null:
		return
	var selected_unit: Unit = hex_grid.get_selected_unit()
	if selected_unit != null and is_instance_valid(selected_unit):
		hud.show_unit(selected_unit)
	else:
		hud.hide_unit()

func _on_combat_resolved(attacker: Unit, defender: Unit, result: Dictionary) -> void:
	hud.show_combat_result(attacker, defender, result)

func _on_turn_changed(player_id: int) -> void:
	print("[Main3D] *** Turno del Jugador %d ***" % player_id)
	hex_grid.exit_card_target_mode()
	hex_grid.current_player = player_id
	_apply_time_of_day(turn_manager.turn_number)
	hud.update_turn(player_id)
	hud.refresh_towers()
	_hovered_hud_unit = null
	hud.hide_unit()
	_focus_camera_on_master(player_id)
	if GameData.get_player_mode(player_id) == "ai":
		call_deferred("_run_ai_turn", player_id)

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
	GameData.units_killed_p1    = maxi(0, int(_summoned_by_player.get(1, 0)) - remaining_p1)
	GameData.units_killed_p2    = maxi(0, int(_summoned_by_player.get(2, 0)) - remaining_p2)
	GameData.towers_captured_p1 = int(_towers_by_player.get(1, 0))
	GameData.towers_captured_p2 = int(_towers_by_player.get(2, 0))

	if winner_id == 0:
		print("[Main3D] La batalla termina en EMPATE.")
	else:
		print("[Main3D] *** ¡El Jugador %d es victorioso! ***" % winner_id)

	get_tree().change_scene_to_file("res://scenes/GameOver.tscn")
