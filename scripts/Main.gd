extends Node2D

const HexGridScript         := preload("res://scripts/HexGrid.gd")
const TurnManagerScript     := preload("res://scripts/TurnManager.gd")
const CombatManagerScript   := preload("res://scripts/CombatManager.gd")
const ResourceManagerScript := preload("res://scripts/ResourceManager.gd")
const SummonManagerScript   := preload("res://scripts/SummonManager.gd")
const MapGeneratorScript    := preload("res://scripts/MapGenerator.gd")
const HUDScene              := preload("res://scenes/HUD.tscn")
const SummonMenuScene       := preload("res://scenes/SummonMenu.tscn")

var hex_grid:         Node
var turn_manager:     Node
var resource_manager: Node
var summon_manager:   Node
var hud:              CanvasLayer
var summon_menu:      CanvasLayer

# ─── Game stats (collected for GameOver screen) ────────────────────────────────
var _summoned_p1:    int = 0
var _summoned_p2:    int = 0
var _towers_p1:      int = 0
var _towers_p2:      int = 0

# ─── Camera ─────────────────────────────────────────────────────────────────────
var camera: Camera2D = null

# ─── Master free-summon tracking ───────────────────────────────────────────────
var _master_summoning: bool       = false
var _master_for_free_summon: Unit = null

func _ready() -> void:
	# ── Generate map BEFORE any game system is created ────────────────────────
	_generate_map()

	# ── Game systems ─────────────────────────────────────────────────────────
	var combat_manager := CombatManagerScript.new()

	resource_manager          = ResourceManagerScript.new()
	resource_manager.name     = "ResourceManager"
	add_child(resource_manager)

	hex_grid                  = HexGridScript.new()
	hex_grid.name             = "HexGrid"
	hex_grid.combat_manager   = combat_manager
	hex_grid.resource_manager = resource_manager
	add_child(hex_grid)

	resource_manager.hex_grid = hex_grid   # cross-link after both are in tree

	turn_manager                  = TurnManagerScript.new()
	turn_manager.name             = "TurnManager"
	turn_manager.hex_grid         = hex_grid
	turn_manager.resource_manager = resource_manager
	add_child(turn_manager)

	summon_manager                  = SummonManagerScript.new()
	summon_manager.name             = "SummonManager"
	summon_manager.hex_grid         = hex_grid
	summon_manager.resource_manager = resource_manager
	add_child(summon_manager)

	# ── HUD ──────────────────────────────────────────────────────────────────
	hud                  = HUDScene.instantiate()
	hud.turn_manager     = turn_manager
	hud.resource_manager = resource_manager
	hud.hex_grid         = hex_grid
	add_child(hud)

	# ── Summon menu ───────────────────────────────────────────────────────────
	summon_menu = SummonMenuScene.instantiate()
	add_child(summon_menu)

	# ── Signal wiring ─────────────────────────────────────────────────────────

	# HUD buttons → game actions
	hud.end_turn_pressed.connect(turn_manager.end_turn)
	hud.summon_pressed.connect(_open_summon_menu)

	# Summon menu flow
	summon_menu.unit_type_chosen.connect(_on_unit_type_chosen)
	summon_menu.cancelled.connect(_on_summon_cancelled)

	# HexGrid → HUD live updates
	hex_grid.unit_selected.connect(hud.show_unit)
	hex_grid.unit_deselected.connect(hud.hide_unit)
	hex_grid.enemy_inspected.connect(_on_enemy_inspected)
	hex_grid.combat_resolved.connect(_on_combat_resolved)
	hex_grid.tower_captured.connect(_on_tower_captured)
	hex_grid.placement_confirmed.connect(_on_placement_confirmed)

	# Master signals
	hex_grid.master_killed.connect(turn_manager.handle_master_killed)
	hex_grid.master_placement_confirmed.connect(_on_master_placement_confirmed)

	# Turn / resource → HUD
	turn_manager.turn_changed.connect(_on_turn_changed)
	turn_manager.game_over.connect(_on_game_over)
	resource_manager.resources_changed.connect(hud.update_essence)

	# Initial HUD state
	hud.refresh_towers()

	# ── Camera setup ─────────────────────────────────────────────────────────
	camera = $Camera2D
	# hex_to_screen() returns local coords; to_global() converts to world after
	# the perspective Transform2D that HexGrid applies in _ready().
	var world_br: Vector2 = hex_grid.to_global(
		hex_grid.hex_to_screen(hex_grid.COLS - 1, hex_grid.ROWS - 1))
	camera.set_map_bounds(world_br.x + 128.0, world_br.y + 128.0)
	var p1_world: Vector2 = hex_grid.to_global(hex_grid.hex_to_screen(
		GameData.map_master_p1.x, GameData.map_master_p1.y))
	camera.position    = p1_world
	camera._target_pos = p1_world
	hex_grid.camera_controller = camera

	# ── Minimap setup ────────────────────────────────────────────────────────
	var minimap_ctrl: Control = $MinimapLayer/Minimap
	minimap_ctrl.set("hex_grid",    hex_grid)
	minimap_ctrl.set("camera_node", camera)

	# ── Visual shaders ────────────────────────────────────────────────────────
	# Cel shading for the hex map canvas
	var hex_mat := ShaderMaterial.new()
	hex_mat.shader = load("res://shaders/hex_map.gdshader")
	hex_grid.material = hex_mat

	# Outline + cel shader for Master unit sprites
	var unit_mat := ShaderMaterial.new()
	unit_mat.shader = load("res://shaders/unit.gdshader")
	hex_grid.apply_unit_shader(unit_mat)

	# Screen-edge vignette on its own CanvasLayer above everything
	var vignette_layer := CanvasLayer.new()
	vignette_layer.layer = 50
	var vignette_rect := ColorRect.new()
	vignette_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ui_mat := ShaderMaterial.new()
	ui_mat.shader = load("res://shaders/ui.gdshader")
	vignette_rect.material = ui_mat
	vignette_layer.add_child(vignette_rect)
	add_child(vignette_layer)

	MusicManager.play_battle_music(1)  # game always starts on player 1's turn
	print("[Main] Game ready — map: %s | seed: %d" % [
		["Llanuras", "Montañas", "Volcánico"][GameData.current_map],
		GameData.map_seed
	])
	print("[Main] WASD/↑↓←→: cámara | Enter: fin de turno | E: invocar | Q: habilidad Maestro | Esc: cancelar")
	print("[Main] Esencia inicial — J1: %d  |  J2: %d" % [
		resource_manager.get_essence(1), resource_manager.get_essence(2),
	])

# ─── Map generation ─────────────────────────────────────────────────────────────
func _generate_map() -> void:
	var gen: RefCounted  = MapGeneratorScript.new()
	var map_types: Array[String] = ["plains", "mountains", "volcanic"]
	var map_type: String = map_types[GameData.current_map]
	var seed_val: int    = GameData.map_seed if GameData.map_seed > 0 else randi()
	gen.generate(seed_val, map_type, GameData.map_size)
	GameData.map_terrain         = gen.get_terrain()
	GameData.map_tower_positions = gen.get_tower_positions()
	GameData.map_master_p1       = gen.get_master_p1_cell()
	GameData.map_master_p2       = gen.get_master_p2_cell()
	GameData.map_seed            = gen.get_seed()
	print("[Main] Mapa generado: tipo=%s semilla=%d | Maestro J1=%s J2=%s" % [
		map_type, GameData.map_seed,
		str(GameData.map_master_p1), str(GameData.map_master_p2)
	])

# ─── Input ─────────────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_ENTER, KEY_KP_ENTER:
			turn_manager.end_turn()
		KEY_E:
			_open_summon_menu()
		KEY_Q:
			_try_master_free_summon()
		KEY_ESCAPE:
			hex_grid.exit_placement_mode()
			hex_grid.exit_master_placement_mode()
			hex_grid.deselect()

# ─── Handlers ──────────────────────────────────────────────────────────────────
func _open_summon_menu() -> void:
	_master_summoning = false
	summon_menu.show_for_player(turn_manager.current_player, resource_manager)

func _try_master_free_summon() -> void:
	var unit: Unit = hex_grid.get_selected_unit()
	if unit == null or not (unit is Master):
		return
	if unit.owner_id != turn_manager.current_player:
		return
	if unit.free_summon_used:
		print("[Main] El Maestro ya usó su invocación gratuita este turno.")
		return
	_master_summoning        = true
	_master_for_free_summon  = unit
	summon_menu.show_for_player(turn_manager.current_player, resource_manager)

func _on_unit_type_chosen(unit_type: int) -> void:
	if _master_summoning:
		_master_summoning = false
		# selected_cell is still the Master's cell (summon menu is an overlay)
		var master_cell: Vector2i = hex_grid.get_selected_cell()
		hex_grid.enter_master_placement_mode(unit_type, turn_manager.current_player, master_cell)
	else:
		hex_grid.enter_placement_mode(unit_type, turn_manager.current_player)
	hud.show_placement_hint()

func _on_summon_cancelled() -> void:
	_master_summoning       = false
	_master_for_free_summon = null
	hex_grid.exit_placement_mode()

func _on_tower_captured(_tower_name: String, _player_id: int) -> void:
	if _player_id == 1:
		_towers_p1 += 1
	else:
		_towers_p2 += 1
	hud.refresh_towers()

func _on_placement_confirmed(col: int, row: int, unit_type: int, player_id: int) -> void:
	summon_manager.summon(unit_type, col, row, player_id)
	hud.hide_placement_hint()
	hud.refresh_towers()
	if player_id == 1:
		_summoned_p1 += 1
	else:
		_summoned_p2 += 1
	var placed: Unit = hex_grid.get_unit_at(col, row)
	if placed != null:
		hud.show_unit(placed)

func _on_master_placement_confirmed(col: int, row: int, unit_type: int, player_id: int) -> void:
	summon_manager.summon_free(unit_type, col, row, player_id)

	# Mark the Master's free summon as used
	if _master_for_free_summon != null:
		_master_for_free_summon.free_summon_used = true
		_master_for_free_summon = null

	hud.hide_placement_hint()
	hud.refresh_towers()

	# Count the free summon toward stats too
	if player_id == 1:
		_summoned_p1 += 1
	else:
		_summoned_p2 += 1

	var placed: Unit = hex_grid.get_unit_at(col, row)
	if placed != null:
		hud.show_unit(placed)

func _on_enemy_inspected(_enemy: Unit, multiplier: float) -> void:
	hud.show_advantage(multiplier)

func _on_combat_resolved(attacker: Unit, defender: Unit, result: Dictionary) -> void:
	hud.show_combat_result(attacker, defender, result)

func _on_turn_changed(player_id: int) -> void:
	print("[Main] *** Turno del Jugador %d ***" % player_id)
	hex_grid.current_player = player_id
	hex_grid.queue_redraw()
	hud.update_turn(player_id)
	hud.refresh_towers()
	hud.hide_unit()

func _on_game_over(winner_id: int) -> void:
	# Count surviving units per player to compute kills
	var remaining_p1: int = 0
	var remaining_p2: int = 0
	for u: Unit in hex_grid.get_all_units():
		if u.owner_id == 1:
			remaining_p1 += 1
		else:
			remaining_p2 += 1

	GameData.winner_id          = winner_id
	GameData.turns_played       = turn_manager.turn_number
	GameData.units_killed_p1    = maxi(0, _summoned_p2 - remaining_p2)
	GameData.units_killed_p2    = maxi(0, _summoned_p1 - remaining_p1)
	GameData.towers_captured_p1 = _towers_p1
	GameData.towers_captured_p2 = _towers_p2

	if winner_id == 0:
		print("[Main] La batalla termina en EMPATE.")
	else:
		print("[Main] *** ¡El Jugador %d es victorioso! ***" % winner_id)

	get_tree().change_scene_to_file("res://scenes/GameOver.tscn")
