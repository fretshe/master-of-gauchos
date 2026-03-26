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

	# Collect income for the newly active player
	if resource_manager != null:
		resource_manager.add_income(current_player)
		AudioManager.play_essence()
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

## Called when HexGrid detects a Master has been killed during combat.
func handle_master_killed(dead_player_id: int) -> void:
	_eliminated_players[dead_player_id] = true
	if hex_grid != null and hex_grid.has_method("remove_units_for_player"):
		hex_grid.call("remove_units_for_player", dead_player_id)
	if current_player == dead_player_id:
		current_player = _get_next_active_player(dead_player_id)
	emit_signal("turn_changed", current_player)
	_check_win_condition()

func _declare_winner(winner_id: int) -> void:
	_game_ended = true
	if winner_id == 0:
		print("[TurnManager] *** DRAW — all units eliminated simultaneously ***")
	else:
		print("[TurnManager] *** GAME OVER — Player %d wins! ***" % winner_id)
	emit_signal("game_over", winner_id)
