extends Node

const UnitScript := preload("res://scripts/Unit.gd")
const SummonManagerScript := preload("res://scripts/SummonManager.gd")

var hex_grid = null
var resource_manager = null
var summon_manager = null
var hud = null

func play_turn(player_id: int) -> void:
	if hex_grid == null or resource_manager == null or summon_manager == null:
		return

	await _wait(0.7)
	await _try_play_best_card(player_id)
	await _try_summon(player_id)

	var safety: int = 0
	while safety < 20:
		safety += 1
		var unit: Unit = _choose_next_unit(player_id)
		if unit == null:
			break
		if hud != null:
			hud.show_unit(unit)
		var acted: bool = await _play_unit_turn(unit)
		if not acted:
			break
		await _wait(0.2)

	await _wait(0.4)

func _choose_next_unit(player_id: int) -> Unit:
	var units: Array[Unit] = hex_grid.get_units_for_player(player_id)
	var best_unit: Unit = null
	var best_score: float = -INF
	for unit: Unit in units:
		if unit == null:
			continue
		var options: Dictionary = hex_grid.get_action_options_for_unit(unit)
		var move_cells: Array = options.get("move_cells", [])
		var attack_cells: Array = options.get("attack_cells", [])
		if move_cells.is_empty() and attack_cells.is_empty():
			continue
		var score: float = 0.0
		score += 100.0 if not attack_cells.is_empty() else 0.0
		score += 12.0 if unit is Master else 0.0
		score += float(unit.level) * 3.0
		score += randf() * 0.5
		if score > best_score:
			best_score = score
			best_unit = unit
	return best_unit

func _play_unit_turn(unit: Unit) -> bool:
	if unit == null:
		return false
	var options: Dictionary = hex_grid.get_action_options_for_unit(unit)
	var attack_cells: Array = options.get("attack_cells", [])
	if not attack_cells.is_empty():
		var target: Unit = _choose_attack_target(unit, attack_cells)
		if target != null:
			await hex_grid.execute_ai_attack(unit, target)
			return true

	var move_cells: Array = options.get("move_cells", [])
	if move_cells.is_empty():
		return false

	var move_target: Vector2i = _choose_move_target(unit, move_cells)
	if move_target == Vector2i(-1, -1):
		return false

	await hex_grid.execute_ai_move(unit, move_target)

	if not is_instance_valid(unit) or unit.hp <= 0:
		return true

	var post_options: Dictionary = hex_grid.get_action_options_for_unit(unit)
	var post_attacks: Array = post_options.get("attack_cells", [])
	if not post_attacks.is_empty():
		var target_after_move: Unit = _choose_attack_target(unit, post_attacks)
		if target_after_move != null:
			await hex_grid.execute_ai_attack(unit, target_after_move)
	return true

func _choose_attack_target(attacker: Unit, attack_cells: Array) -> Unit:
	var best_target: Unit = null
	var best_score: float = -INF
	for cell_value: Variant in attack_cells:
		var cell: Vector2i = cell_value as Vector2i
		var target: Unit = hex_grid.get_unit_at(cell.x, cell.y)
		if target == null:
			continue
		var multiplier: float = UnitScript.get_damage_multiplier(attacker.unit_type, target.unit_type)
		var score: float = 0.0
		score += 200.0 if target.hp <= 4 else 0.0
		score += 80.0 if target is Master else 0.0
		score += (float(target.max_hp - target.hp) * 2.0)
		score += multiplier * 12.0
		score += float(target.level) * 4.0
		score += randf()
		if score > best_score:
			best_score = score
			best_target = target
	return best_target

func _choose_move_target(unit: Unit, move_cells: Array) -> Vector2i:
	var best_cell := Vector2i(-1, -1)
	var best_score: float = -INF
	var enemy_cells: Array[Vector2i] = []
	var tower_targets: Array[Vector2i] = []

	for unit_value: Variant in hex_grid.get_all_units():
		var other: Unit = unit_value as Unit
		if other == null or other.owner_id == unit.owner_id:
			continue
		var other_cell: Vector2i = hex_grid.get_cell_for_unit(other)
		if other_cell != Vector2i(-1, -1):
			enemy_cells.append(other_cell)

	for tower_value: Variant in hex_grid.get_all_towers():
		var tower = tower_value
		if tower == null:
			continue
		if int(tower.owner_id) != unit.owner_id:
			tower_targets.append(tower.position)

	for cell_value: Variant in move_cells:
		var cell: Vector2i = cell_value as Vector2i
		var score: float = 0.0

		for tower_cell: Vector2i in tower_targets:
			if tower_cell == cell:
				score += 120.0
			else:
				score -= float(hex_grid.get_distance_between_cells(cell, tower_cell)) * 6.0

		for enemy_cell: Vector2i in enemy_cells:
			score -= float(hex_grid.get_distance_between_cells(cell, enemy_cell)) * 3.2

		score += randf() * 0.5
		if score > best_score:
			best_score = score
			best_cell = cell
	return best_cell

func _try_summon(player_id: int) -> void:
	var summon_cells: Array[Vector2i] = hex_grid.get_valid_summon_cells(player_id)
	if summon_cells.is_empty():
		return

	var affordable: Array[int] = []
	for unit_type_value: Variant in SummonManagerScript.SUMMON_COSTS.keys():
		var unit_type: int = int(unit_type_value)
		var cost: int = int(SummonManagerScript.SUMMON_COSTS[unit_type])
		if resource_manager.can_afford(player_id, cost):
			affordable.append(unit_type)
	if affordable.is_empty():
		return

	affordable.sort_custom(func(a: int, b: int) -> bool:
		return int(SummonManagerScript.SUMMON_COSTS[a]) > int(SummonManagerScript.SUMMON_COSTS[b])
	)
	var chosen_type: int = int(affordable[0])
	var chosen_cell: Vector2i = _choose_summon_cell(player_id, summon_cells)
	if chosen_cell == Vector2i(-1, -1):
		return
	if summon_manager.summon(chosen_type, chosen_cell.x, chosen_cell.y, player_id):
		await _wait(0.35)

func _try_play_best_card(player_id: int) -> void:
	if CardManager.used_card_this_turn:
		return
	var hand: Array = CardManager.get_hand(player_id)
	if hand.is_empty():
		return

	var best_index: int = -1
	var best_target: Unit = null
	var best_score: float = -INF

	for i: int in range(hand.size()):
		var card: Dictionary = hand[i]
		var card_type: String = str(card.get("type", ""))
		var value: int = int(card.get("value", 0))
		var score: float = -INF
		var target: Unit = null

		match card_type:
			"damage":
				target = _choose_damage_card_target(player_id, value)
				if target != null:
					score = _score_damage_card(target, value)
			"heal":
				target = _choose_heal_card_target(player_id, value)
				if target != null:
					score = _score_heal_card(target, value)
			"exp":
				target = _choose_exp_card_target(player_id, value)
				if target != null:
					score = _score_exp_card(target, value)
			"essence":
				score = _score_essence_card(player_id, value)

		score += randf() * 0.05
		if score > best_score:
			best_score = score
			best_index = i
			best_target = target

	if best_index < 0 or best_score < 1.0:
		return

	var played: bool = CardManager.play_card(player_id, best_index, best_target)
	if played:
		await _wait(0.35)

func _choose_summon_cell(player_id: int, summon_cells: Array) -> Vector2i:
	var best_cell := Vector2i(-1, -1)
	var best_score: float = -INF
	var enemy_cells: Array[Vector2i] = []
	for unit_value: Variant in hex_grid.get_all_units():
		var unit: Unit = unit_value as Unit
		if unit == null or unit.owner_id == player_id:
			continue
		var cell: Vector2i = hex_grid.get_cell_for_unit(unit)
		if cell != Vector2i(-1, -1):
			enemy_cells.append(cell)

	for cell_value: Variant in summon_cells:
		var cell: Vector2i = cell_value as Vector2i
		var score: float = 0.0
		for enemy_cell: Vector2i in enemy_cells:
			score -= float(hex_grid.get_distance_between_cells(cell, enemy_cell)) * 3.5
		score += randf() * 0.5
		if score > best_score:
			best_score = score
			best_cell = cell
	return best_cell

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _choose_damage_card_target(player_id: int, value: int) -> Unit:
	var best_target: Unit = null
	var best_score: float = -INF
	for unit_value: Variant in hex_grid.get_all_units():
		var unit: Unit = unit_value as Unit
		if unit == null or unit.owner_id == player_id or unit is Master:
			continue
		var score: float = _score_damage_card(unit, value)
		if score > best_score:
			best_score = score
			best_target = unit
	return best_target

func _score_damage_card(target: Unit, value: int) -> float:
	var score: float = float(value) * 2.5
	score += 120.0 if target.hp <= value else 0.0
	score += float(target.max_hp - target.hp) * 1.5
	score += float(target.level) * 6.0
	return score

func _choose_heal_card_target(player_id: int, value: int) -> Unit:
	var best_target: Unit = null
	var best_score: float = -INF
	for unit_value: Variant in hex_grid.get_all_units():
		var unit: Unit = unit_value as Unit
		if unit == null or unit.owner_id != player_id or unit.hp >= unit.max_hp:
			continue
		var score: float = _score_heal_card(unit, value)
		if score > best_score:
			best_score = score
			best_target = unit
	return best_target

func _score_heal_card(target: Unit, value: int) -> float:
	var missing_hp: int = target.max_hp - target.hp
	var effective_heal: int = mini(missing_hp, value)
	var score: float = float(effective_heal) * 5.0
	score += 20.0 if target is Master else 0.0
	score += float(target.level) * 3.0
	return score

func _choose_exp_card_target(player_id: int, value: int) -> Unit:
	var best_target: Unit = null
	var best_score: float = -INF
	for unit_value: Variant in hex_grid.get_all_units():
		var unit: Unit = unit_value as Unit
		if unit == null or unit.owner_id != player_id:
			continue
		var score: float = _score_exp_card(unit, value)
		if score > best_score:
			best_score = score
			best_target = unit
	return best_target

func _score_exp_card(target: Unit, value: int) -> float:
	var exp_required: int = int(target.get_exp_required())
	var to_level: int = maxi(0, exp_required - int(target.experience))
	var score: float = float(value) * 3.0
	score += 80.0 if value >= to_level and to_level > 0 else 0.0
	score += float(target.level) * 4.0
	score += 12.0 if target is Master else 0.0
	return score

func _score_essence_card(player_id: int, value: int) -> float:
	var current_essence: int = resource_manager.get_essence(player_id)
	var best_now: int = _best_affordable_summon_cost(current_essence)
	var best_after: int = _best_affordable_summon_cost(current_essence + value)
	if best_after > best_now:
		return 95.0 + float(best_after - best_now) * 4.0
	if current_essence < 10:
		return 16.0 + float(value)
	return 4.0 + float(value) * 0.5

func _best_affordable_summon_cost(essence: int) -> int:
	var best: int = 0
	for unit_type_value: Variant in SummonManagerScript.SUMMON_COSTS.keys():
		var unit_type: int = int(unit_type_value)
		var cost: int = int(SummonManagerScript.SUMMON_COSTS[unit_type])
		if cost <= essence and cost > best:
			best = cost
	return best
