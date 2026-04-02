extends Node

# ─── Signals ───────────────────────────────────────────────────────────────────
signal resources_changed(player_id: int, amount: int)

# ─── State ─────────────────────────────────────────────────────────────────────
var _essence: Dictionary = { 1: 10, 2: 10, 3: 10, 4: 10 }
var _gained_by_player: Dictionary = {}
var _spent_by_player: Dictionary = {}

# Set by Main.gd after both nodes are in the tree
var hex_grid = null

# ─── Public API ────────────────────────────────────────────────────────────────
func get_essence(player_id: int) -> int:
	return _essence.get(player_id, 0)

func setup_players(player_count: int, starting_essence: int = 10) -> void:
	_essence.clear()
	_gained_by_player.clear()
	_spent_by_player.clear()
	var player_ids: Array[int] = GameData.get_player_ids() if GameData != null and GameData.has_method("get_player_ids") else []
	if player_ids.is_empty():
		for player_id: int in range(1, maxi(2, player_count) + 1):
			_essence[player_id] = starting_essence
			_gained_by_player[player_id] = 0
			_spent_by_player[player_id] = 0
		return
	for player_id: int in player_ids:
		_essence[player_id] = starting_essence
		_gained_by_player[player_id] = 0
		_spent_by_player[player_id] = 0

func add_essence(player_id: int, amount: int) -> void:
	_essence[player_id] = int(_essence.get(player_id, 0)) + amount
	_gained_by_player[player_id] = int(_gained_by_player.get(player_id, 0)) + maxi(0, amount)
	emit_signal("resources_changed", player_id, _essence[player_id])

## Sums income from all towers owned by player_id and adds it to their essence.
func add_income(player_id: int) -> int:
	if hex_grid == null:
		return 0
	var total_income: int = 0
	for tower in hex_grid.get_all_towers():
		if tower.owner_id == player_id:
			total_income += tower.income
	if total_income > 0:
		_essence[player_id] += total_income
		_gained_by_player[player_id] = int(_gained_by_player.get(player_id, 0)) + total_income
		emit_signal("resources_changed", player_id, _essence[player_id])
	return total_income

func can_afford(player_id: int, cost: int) -> bool:
	return _essence.get(player_id, 0) >= cost

## Deducts cost from player's essence. Returns false without spending if insufficient.
func spend(player_id: int, cost: int) -> bool:
	if not can_afford(player_id, cost):
		return false
	_essence[player_id] -= cost
	_spent_by_player[player_id] = int(_spent_by_player.get(player_id, 0)) + maxi(0, cost)
	emit_signal("resources_changed", player_id, _essence[player_id])
	return true

func get_total_gained(player_id: int) -> int:
	return int(_gained_by_player.get(player_id, 0))

func get_total_spent(player_id: int) -> int:
	return int(_spent_by_player.get(player_id, 0))

func serialize_state() -> Dictionary:
	return {
		"essence": _essence.duplicate(true),
		"gained_by_player": _gained_by_player.duplicate(true),
		"spent_by_player": _spent_by_player.duplicate(true),
	}

func load_state(state: Dictionary) -> void:
	_essence = state.get("essence", {}).duplicate(true)
	_gained_by_player = state.get("gained_by_player", {}).duplicate(true)
	_spent_by_player = state.get("spent_by_player", {}).duplicate(true)
	for player_id: int in GameData.get_player_ids():
		if not _essence.has(player_id):
			_essence[player_id] = 10
		if not _gained_by_player.has(player_id):
			_gained_by_player[player_id] = 0
		if not _spent_by_player.has(player_id):
			_spent_by_player[player_id] = 0
