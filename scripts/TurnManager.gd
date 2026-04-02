extends Node

# ─── Signals ───────────────────────────────────────────────────────────────────
signal turn_changed(player_id: int)
signal game_over(winner_id: int)

# ─── State ─────────────────────────────────────────────────────────────────────
var current_player: int = 1
var turn_number: int    = 1
var _game_ended: bool   = false
var _eliminated_players: Dictionary = {}

func _ready() -> void:
	print("[TurnManager] ¡Protege a tu Maestro! — El jugador que pierda a su Maestro perderá la partida.")

# Set by Main.gd after instantiation
var hex_grid:         Node = null
var resource_manager: Node = null

# ─── Public API ────────────────────────────────────────────────────────────────
func end_turn() -> void:
	if _game_ended:
		return

	if hex_grid != null and hex_grid.has_method("resolve_end_turn_tower_captures"):
		hex_grid.call("resolve_end_turn_tower_captures", current_player)
		_check_win_condition()
		if _game_ended:
			return
	if hex_grid != null and hex_grid.has_method("heal_units_on_owned_towers"):
		var healed_units: int = int(hex_grid.call("heal_units_on_owned_towers", current_player, 1))
		if healed_units > 0:
			AudioManager.play_card("heal")

	_reset_units_for(current_player)
	CardManager.end_turn_reset()

	var next_player: int = _get_next_active_player(current_player)
	if next_player == current_player:
		_check_win_condition()
		return
	if next_player <= current_player:
		turn_number += 1
	current_player = next_player

	print("[TurnManager] Turn %d — Player %d's turn begins." % [turn_number, current_player])

	_reset_units_for(current_player)
	_apply_aura_heals(current_player)
	_apply_leadership_marks(current_player)
	CardManager.process_effects(current_player)

	# Collect income for the newly active player
	if resource_manager != null:
		var gained_income: int = int(resource_manager.add_income(current_player))
		if gained_income > 0:
			AudioManager.play_essence()
			if hex_grid != null and hex_grid.has_method("play_tower_income_feedback"):
				hex_grid.call("play_tower_income_feedback", current_player)
		print("[TurnManager] Esencia — P1: %d  |  P2: %d" % [
			resource_manager.get_essence(1),
			resource_manager.get_essence(2),
		])

	CardManager.draw_card(current_player)
	AudioManager.play_turn_change()
	MusicManager.play_battle_music(current_player)
	emit_signal("turn_changed", current_player)
	_check_win_condition()

# ─── Internal ──────────────────────────────────────────────────────────────────
func _reset_units_for(player_id: int) -> void:
	if hex_grid == null:
		return
	for unit in hex_grid.get_all_units():
		if unit.owner_id == player_id:
			unit.reset_moves()
	if hex_grid.has_method("refresh_unit_action_indicators"):
		hex_grid.call("refresh_unit_action_indicators")

func _get_active_players() -> Array[int]:
	var active: Array[int] = []
	for player_id: int in GameData.get_player_ids():
		if not _eliminated_players.get(player_id, false):
			active.append(player_id)
	return active

func _get_next_active_player(from_player: int) -> int:
	var active: Array[int] = _get_active_players()
	if active.is_empty():
		return from_player
	var idx: int = active.find(from_player)
	if idx == -1:
		return active[0]
	return active[(idx + 1) % active.size()]

func _check_win_condition() -> void:
	if hex_grid == null or _game_ended:
		return

	var tower_winner: int = _get_tower_domination_winner()
	if tower_winner != 0:
		_declare_winner(tower_winner)
		return

	var alive_players: Array[int] = []
	for player_id: int in GameData.get_player_ids():
		if _eliminated_players.get(player_id, false):
			continue
		var has_master: bool = false
		for unit in hex_grid.get_all_units():
			if unit.owner_id == player_id and unit is Master:
				has_master = true
				break
		if has_master:
			alive_players.append(player_id)
		else:
			_eliminated_players[player_id] = true

	if alive_players.is_empty():
		_declare_winner(0)
	elif alive_players.size() == 1:
		_declare_winner(alive_players[0])

func _get_tower_domination_winner() -> int:
	if hex_grid == null or not hex_grid.has_method("get_all_towers"):
		return 0

	var towers: Array = hex_grid.get_all_towers()
	if towers.is_empty():
		return 0

	var owner_id: int = -1
	for tower_value: Variant in towers:
		var tower: Tower = tower_value as Tower
		if tower == null:
			continue
		if tower.owner_id <= 0:
			return 0
		if owner_id == -1:
			owner_id = tower.owner_id
		elif tower.owner_id != owner_id:
			return 0

	return maxi(0, owner_id)

## Called when HexGrid detects a Master has been killed during combat.
func handle_master_killed(dead_player_id: int) -> void:
	_eliminated_players[dead_player_id] = true
	if hex_grid != null and hex_grid.has_method("remove_units_for_player"):
		hex_grid.call("remove_units_for_player", dead_player_id)
	if current_player == dead_player_id:
		current_player = _get_next_active_player(dead_player_id)
	emit_signal("turn_changed", current_player)
	_check_win_condition()

func handle_tower_captured(_capturing_player_id: int) -> void:
	_check_win_condition()

func _declare_winner(winner_id: int) -> void:
	_game_ended = true
	if winner_id == 0:
		print("[TurnManager] *** DRAW — all units eliminated simultaneously ***")
	else:
		print("[TurnManager] *** GAME OVER — Player %d wins! ***" % winner_id)
	emit_signal("game_over", winner_id)

# ─── Bonus passives ─────────────────────────────────────────────────────────────
func _apply_aura_heals(for_player: int) -> void:
	if hex_grid == null:
		return
	for unit_variant: Variant in hex_grid.get_all_units():
		var master: Unit = unit_variant as Unit
		if master == null or not (master is Master):
			continue
		if master.owner_id != for_player or not master.bonus_aura:
			continue
		var master_cell: Vector2i = master.get_hex_cell()
		for nb: Vector2i in hex_grid.get_neighbors_of(master_cell):
			var ally: Unit = hex_grid.get_unit_at(nb.x, nb.y)
			if ally != null and ally.owner_id == for_player and ally.hp < ally.max_hp:
				ally.hp = mini(ally.hp + 1, ally.max_hp)

func _apply_leadership_marks(for_player: int) -> void:
	if hex_grid == null:
		return
	# First clear all marks for this player
	for unit_variant: Variant in hex_grid.get_all_units():
		var unit: Unit = unit_variant as Unit
		if unit != null and unit.owner_id == for_player:
			unit.leadership_xp_bonus = false
	# Then mark units within radius 2 of each leadership master
	for unit_variant: Variant in hex_grid.get_all_units():
		var master: Unit = unit_variant as Unit
		if master == null or not (master is Master):
			continue
		if master.owner_id != for_player or not master.bonus_leadership:
			continue
		var master_cell: Vector2i = master.get_hex_cell()
		for ally_variant: Variant in hex_grid.get_all_units():
			var ally: Unit = ally_variant as Unit
			if ally == null or ally.owner_id != for_player or ally == master:
				continue
			if hex_grid.get_hex_distance(master_cell, ally.get_hex_cell()) <= 2:
				ally.leadership_xp_bonus = true

func serialize_state() -> Dictionary:
	return {
		"current_player": current_player,
		"turn_number": turn_number,
		"eliminated_players": _eliminated_players.duplicate(true),
	}

func load_state(state: Dictionary) -> void:
	current_player = int(state.get("current_player", 1))
	turn_number = int(state.get("turn_number", 1))
	_eliminated_players = (state.get("eliminated_players", {}) as Dictionary).duplicate(true)
	_game_ended = false
