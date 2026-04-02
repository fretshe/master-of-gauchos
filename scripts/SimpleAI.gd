extends Node

const UnitScript := preload("res://scripts/Unit.gd")
const SummonManagerScript := preload("res://scripts/SummonManager.gd")
const FactionDataScript := preload("res://scripts/FactionData.gd")

var hex_grid = null
var resource_manager = null
var summon_manager = null
var hud = null

const AI_TURN_START_DELAY := 1.05
const AI_PRE_CARD_DELAY := 0.58
const AI_POST_CARD_DELAY := 0.90
const AI_POST_SUMMON_DELAY := 0.55
const AI_PRE_ACTION_DELAY := 0.45
const AI_POST_ACTION_DELAY := 0.55
const AI_BETWEEN_UNITS_DELAY := 0.75
const AI_TURN_END_DELAY := 0.95

const PERSONA_NAMES: Array[String] = [
	"Arrollador", "Calculador", "Custodio", "Asediante",
	"Oportunista", "Territorial", "Temerario", "Paciente",
]

var _profiles: Dictionary = {}

func play_turn(player_id: int) -> void:
	if hex_grid == null or resource_manager == null or summon_manager == null:
		return
	var profile: Dictionary = _get_profile(player_id)
	await _wait(AI_TURN_START_DELAY)
	if _is_scripted_tutorial_enemy(player_id):
		await _play_scripted_tutorial_turn(player_id)
		await _wait(AI_TURN_END_DELAY)
		return
	await _try_play_best_card(player_id, profile)
	await _try_summon(player_id, profile)
	var safety: int = 0
	while safety < 20:
		safety += 1
		var unit: Unit = _choose_next_unit(player_id, profile)
		if unit == null:
			break
		if hud != null:
			hud.show_unit(unit)
		var acted: bool = await _play_unit_turn(unit, profile)
		if not acted:
			break
		await _wait(AI_BETWEEN_UNITS_DELAY)
	await _wait(AI_TURN_END_DELAY)

func _play_scripted_tutorial_turn(player_id: int) -> void:
	var master: Unit = _get_scripted_enemy_master(player_id)
	if master == null:
		return
	if hud != null:
		hud.show_unit(master)
	var move_target: Vector2i = _get_scripted_enemy_master_target_cell(player_id)
	var options: Dictionary = hex_grid.get_action_options_for_unit(master)
	if move_target in options.get("move_cells", []):
		await _wait(AI_PRE_ACTION_DELAY)
		await hex_grid.execute_ai_move(master, move_target)
		await _wait(AI_POST_ACTION_DELAY)
	await _try_summon(player_id, _get_profile(player_id))

func _choose_next_unit(player_id: int, profile: Dictionary) -> Unit:
	if _is_scripted_tutorial_enemy(player_id):
		var scripted_master: Unit = _get_scripted_enemy_master(player_id)
		if scripted_master != null:
			var scripted_options: Dictionary = hex_grid.get_action_options_for_unit(scripted_master)
			if not (scripted_options.get("move_cells", []) as Array).is_empty() or not (scripted_options.get("attack_cells", []) as Array).is_empty():
				return scripted_master
	var best_unit: Unit = null
	var best_score: float = -INF
	var opening_phase: bool = _is_opening_phase()
	var contested_towers: Array[Vector2i] = _get_contested_owned_tower_cells(player_id)
	for unit: Unit in hex_grid.get_units_for_player(player_id):
		if unit == null:
			continue
		var options: Dictionary = hex_grid.get_action_options_for_unit(unit)
		var move_cells: Array = options.get("move_cells", [])
		var attack_cells: Array = options.get("attack_cells", [])
		if move_cells.is_empty() and attack_cells.is_empty():
			continue
		var score: float = 0.0
		score += 70.0 + _stat(profile, "aggression") * 34.0 if not attack_cells.is_empty() else 0.0
		score += 18.0 + _stat(profile, "tower_focus") * 10.0 if not move_cells.is_empty() else 0.0
		score += 96.0 if _has_tower_capture_move(unit.owner_id, move_cells) else 0.0
		score += 78.0 if _can_reinforce_tower(move_cells, contested_towers) else 0.0
		if opening_phase and _has_tower_capture_move(unit.owner_id, move_cells):
			score += 42.0
		elif opening_phase and not attack_cells.is_empty() and not _has_tower_capture_move(unit.owner_id, move_cells):
			score -= 18.0
		score += float(unit.level) * (2.5 + _stat(profile, "tempo_focus"))
		score += _urgency(unit, profile)
		score += randf() * 0.5
		if score > best_score:
			best_score = score
			best_unit = unit
	return best_unit

func _play_unit_turn(unit: Unit, profile: Dictionary) -> bool:
	if unit == null:
		return false
	var options: Dictionary = hex_grid.get_action_options_for_unit(unit)
	var attack_cells: Array = options.get("attack_cells", [])
	var move_cells: Array = options.get("move_cells", [])
	var enemy_cells: Array[Vector2i] = _get_enemy_cells(unit.owner_id)
	var tower_targets: Array[Vector2i] = _get_enemy_or_neutral_tower_cells(unit.owner_id)
	var own_master_cell: Vector2i = _get_player_master_cell(unit.owner_id)
	var owned_towers: Array[Vector2i] = _get_owned_tower_cells(unit.owner_id)
	var contested_towers: Array[Vector2i] = _get_contested_owned_tower_cells(unit.owner_id)
	var target: Unit = _choose_attack_target(unit, attack_cells, profile)
	var attack_score: float = _score_attack_target(unit, target, profile) if target != null else -INF
	var move_target: Vector2i = _choose_move_target(unit, move_cells, profile)
	var move_score: float = _score_move_target(unit, move_target, profile, enemy_cells, tower_targets, own_master_cell, owned_towers, contested_towers) if move_target != Vector2i(-1, -1) else -INF
	var should_move_first: bool = _should_prioritize_move(unit.owner_id, move_target, move_score, target, attack_score)

	if target != null and not should_move_first:
		await _wait(AI_PRE_ACTION_DELAY)
		await hex_grid.execute_ai_attack(unit, target)
		await _wait(AI_POST_ACTION_DELAY)
		return true
	if move_target == Vector2i(-1, -1):
		return false
	await _wait(AI_PRE_ACTION_DELAY)
	await hex_grid.execute_ai_move(unit, move_target)
	await _wait(AI_POST_ACTION_DELAY)
	if not is_instance_valid(unit) or unit.hp <= 0:
		return true
	var post_attacks: Array = (hex_grid.get_action_options_for_unit(unit).get("attack_cells", []) as Array)
	if not post_attacks.is_empty():
		var target_after_move: Unit = _choose_attack_target(unit, post_attacks, profile)
		if target_after_move != null:
			await _wait(AI_PRE_ACTION_DELAY)
			await hex_grid.execute_ai_attack(unit, target_after_move)
			await _wait(AI_POST_ACTION_DELAY)
	return true

func _choose_attack_target(attacker: Unit, attack_cells: Array, profile: Dictionary) -> Unit:
	var best_target: Unit = null
	var best_score: float = -INF
	for cell_value: Variant in attack_cells:
		var cell: Vector2i = cell_value as Vector2i
		var target: Unit = hex_grid.get_unit_at(cell.x, cell.y)
		if target == null:
			continue
		var score: float = _score_attack_target(attacker, target, profile) + randf()
		if score > best_score:
			best_score = score
			best_target = target
	return best_target

func _choose_move_target(unit: Unit, move_cells: Array, profile: Dictionary) -> Vector2i:
	if _is_scripted_tutorial_enemy(unit.owner_id) and unit is Master:
		var tutorial_cell: Vector2i = _get_scripted_enemy_master_target_cell(unit.owner_id)
		if tutorial_cell in move_cells:
			return tutorial_cell
	var best_cell := Vector2i(-1, -1)
	var best_score: float = -INF
	var enemy_cells: Array[Vector2i] = _get_enemy_cells(unit.owner_id)
	var tower_targets: Array[Vector2i] = _get_enemy_or_neutral_tower_cells(unit.owner_id)
	var own_master_cell: Vector2i = _get_player_master_cell(unit.owner_id)
	var owned_towers: Array[Vector2i] = _get_owned_tower_cells(unit.owner_id)
	var contested_towers: Array[Vector2i] = _get_contested_owned_tower_cells(unit.owner_id)
	for cell_value: Variant in move_cells:
		var cell: Vector2i = cell_value as Vector2i
		var score: float = _score_move_target(unit, cell, profile, enemy_cells, tower_targets, own_master_cell, owned_towers, contested_towers) + randf() * 0.4
		if score > best_score:
			best_score = score
			best_cell = cell
	return best_cell

func _try_summon(player_id: int, profile: Dictionary) -> void:
	var chosen_type: int = -1
	if CardManager.free_summon_active:
		var free_cells: Array[Vector2i] = hex_grid.get_valid_summon_cells(player_id)
		if free_cells.is_empty():
			return
		chosen_type = _choose_best_summon_type(player_id, profile, true)
		if chosen_type == -1:
			return
		var free_cell: Vector2i = _choose_summon_cell(player_id, free_cells, profile, chosen_type)
		if free_cell == Vector2i(-1, -1):
			return
		if summon_manager.summon_free(chosen_type, free_cell.x, free_cell.y, player_id):
			CardManager.free_summon_active = false
			await _wait(AI_POST_SUMMON_DELAY)
	var failed_attempts: int = 0
	while failed_attempts < 4:
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
		if _is_scripted_tutorial_enemy(player_id):
			if not affordable.has(UnitScript.UnitType.LANCER):
				return
			chosen_type = UnitScript.UnitType.LANCER
		else:
			chosen_type = _choose_best_summon_type(player_id, profile, false, affordable)
		if chosen_type == -1:
			return
		var chosen_cell: Vector2i = _choose_summon_cell(player_id, summon_cells, profile, chosen_type)
		if chosen_cell == Vector2i(-1, -1):
			failed_attempts += 1
			affordable.erase(chosen_type)
			if affordable.is_empty():
				return
			chosen_type = _choose_best_summon_type(player_id, profile, false, affordable)
			if chosen_type == -1:
				return
			chosen_cell = _choose_summon_cell(player_id, summon_cells, profile, chosen_type)
			if chosen_cell == Vector2i(-1, -1):
				return
		if summon_manager.summon(chosen_type, chosen_cell.x, chosen_cell.y, player_id):
			failed_attempts = 0
			await _wait(AI_POST_SUMMON_DELAY)
			if _is_scripted_tutorial_enemy(player_id):
				return
			continue
		failed_attempts += 1

func _try_play_best_card(player_id: int, profile: Dictionary) -> void:
	if _is_scripted_tutorial_enemy(player_id) or CardManager.used_card_this_turn:
		return
	var hand: Array = CardManager.get_hand(player_id)
	if hand.is_empty():
		return
	var best_action: Dictionary = {}
	var best_score: float = -INF
	for i: int in range(hand.size()):
		var action: Dictionary = _score_card_action(player_id, i, hand[i], profile)
		if action.is_empty():
			continue
		var score: float = float(action.get("score", -INF)) + randf() * 0.05
		if score > best_score:
			best_score = score
			best_action = action
	if best_action.is_empty() or best_score < 1.0:
		return
	var best_target: Unit = best_action.get("target_unit", null) as Unit
	if best_target != null and hud != null:
		hud.show_unit(best_target)
	await _wait(AI_PRE_CARD_DELAY)
	var played: bool = false
	match str(best_action.get("mode", "immediate")):
		"unit":
			played = CardManager.play_card(player_id, int(best_action.get("index", -1)), best_target)
		"tower":
			played = CardManager.play_card_on_tower(player_id, int(best_action.get("index", -1)), best_action.get("tower_cell", Vector2i(-1, -1)))
		_:
			played = CardManager.play_card(player_id, int(best_action.get("index", -1)), null)
	if played:
		await _wait(AI_POST_CARD_DELAY)
		var card: Dictionary = best_action.get("card", {})
		if str(card.get("type", "")) == "faction" and str(card.get("effect", "")) == "free_summon":
			await _try_summon(player_id, profile)

func _score_card_action(player_id: int, card_index: int, card: Dictionary, profile: Dictionary) -> Dictionary:
	var mode: String = "immediate"
	var target: Unit = null
	var tower_cell: Vector2i = Vector2i(-1, -1)
	var score: float = -INF
	var value: int = int(card.get("value", 0))
	match str(card.get("type", "")):
		"damage":
			target = _best_unit_by_score(_get_enemy_units(player_id), func(u: Unit) -> float: return _score_damage_card(u, value, profile), true)
			if target != null:
				mode = "unit"; score = _score_damage_card(target, value, profile)
		"heal":
			target = _best_unit_by_score(hex_grid.get_units_for_player(player_id), func(u: Unit) -> float: return _score_heal_card(u, value, profile) if u.hp < u.max_hp else -INF)
			if target != null:
				mode = "unit"; score = _score_heal_card(target, value, profile)
		"exp":
			target = _best_unit_by_score(hex_grid.get_units_for_player(player_id), func(u: Unit) -> float: return _score_exp_card(u, value, profile))
			if target != null:
				mode = "unit"; score = _score_exp_card(target, value, profile)
		"essence":
			score = _score_essence_card(player_id, value, profile)
		"refresh":
			target = _best_unit_by_score(hex_grid.get_units_for_player(player_id), func(u: Unit) -> float: return _score_refresh_card(u, profile) if u.moved or u.has_attacked else -INF)
			if target != null:
				mode = "unit"; score = _score_refresh_card(target, profile)
		"faction":
			match str(card.get("effect", "")):
				"essence":
					score = _score_essence_card(player_id, value, profile) + 18.0
				"damage":
					target = _best_unit_by_score(_get_enemy_units(player_id), func(u: Unit) -> float: return -INF if u is Master else _score_damage_card(u, value, profile), true)
					if target != null:
						mode = "unit"; score = _score_damage_card(target, value, profile) + 12.0
				"heal":
					target = _best_unit_by_score(hex_grid.get_units_for_player(player_id), func(u: Unit) -> float: return _score_heal_card(u, value, profile) if u.hp < u.max_hp else -INF)
					if target != null:
						mode = "unit"; score = _score_heal_card(target, value, profile) + 10.0
				"exp":
					target = _best_unit_by_score(hex_grid.get_units_for_player(player_id), func(u: Unit) -> float: return _score_exp_card(u, value, profile))
					if target != null:
						mode = "unit"; score = _score_exp_card(target, value, profile) + 9.0
				"immobilize", "poison", "attack_debuff":
					target = _best_unit_by_score(_get_enemy_units(player_id), func(u: Unit) -> float: return -INF if u is Master else _score_control(u, str(card.get("effect", "")), profile), true)
					if target != null:
						mode = "unit"; score = _score_control(target, str(card.get("effect", "")), profile)
				"extra_move":
					target = _best_unit_by_score(hex_grid.get_units_for_player(player_id), func(u: Unit) -> float: return _score_extra_move(u, profile))
					if target != null:
						mode = "unit"; score = _score_extra_move(target, profile)
				"double_attack":
					target = _best_unit_by_score(hex_grid.get_units_for_player(player_id), func(u: Unit) -> float: return _score_double_attack(u, profile))
					if target != null:
						mode = "unit"; score = _score_double_attack(target, profile)
				"defense_buff":
					target = _best_unit_by_score(hex_grid.get_units_for_player(player_id), func(u: Unit) -> float: return _score_defense(u, profile))
					if target != null:
						mode = "unit"; score = _score_defense(target, profile)
				"untargetable":
					target = _best_unit_by_score(hex_grid.get_units_for_player(player_id), func(u: Unit) -> float: return _score_defense(u, profile) + 16.0)
					if target != null:
						mode = "unit"; score = _score_defense(target, profile) + 16.0
				"tower_heal":
					tower_cell = _best_tower_heal_cell(player_id, profile)
					if tower_cell != Vector2i(-1, -1):
						mode = "tower"; score = _score_tower_heal(player_id, tower_cell, value, profile)
				"heal_all":
					score = _score_heal_all(player_id, value, profile)
				"sacrifice_essence":
					score = _score_sacrifice_essence(player_id, value, profile)
				"swap_hp":
					target = _best_swap_target(player_id, profile)
					if target != null:
						mode = "unit"; score = _score_swap_hp(player_id, target, profile)
				"free_summon":
					score = _score_free_summon(player_id, profile)
				"revive":
					score = _score_revive(player_id, profile)
				"aoe_damage":
					score = _score_aoe_damage(player_id, value, profile)
				"random":
					score = 24.0 + _stat(profile, "risk_tolerance") * 8.0
	if score == -INF:
		return {}
	var result: Dictionary = {"index": card_index, "card": card, "mode": mode, "score": score}
	if target != null:
		result["target_unit"] = target
	if tower_cell != Vector2i(-1, -1):
		result["tower_cell"] = tower_cell
	return result

func _choose_best_summon_type(player_id: int, profile: Dictionary, free_summon: bool = false, affordable: Array[int] = []) -> int:
	var candidates: Array[int] = affordable.duplicate()
	if free_summon:
		candidates.clear()
		for unit_type_value: Variant in SummonManagerScript.SUMMON_COSTS.keys():
			candidates.append(int(unit_type_value))
	if candidates.is_empty():
		return -1
	var best_type: int = -1
	var best_score: float = -INF
	var enemy_units: Array[Unit] = _get_enemy_units(player_id)
	for unit_type: int in candidates:
		var score: float = float(SummonManagerScript.SUMMON_COSTS.get(unit_type, 0)) * (0.5 + _stat(profile, "economy_focus") * 0.35)
		match unit_type:
			UnitScript.UnitType.WARRIOR:
				score += 14.0 * _stat(profile, "aggression")
			UnitScript.UnitType.ARCHER:
				score += 14.0 * _stat(profile, "master_focus") + 10.0 * _stat(profile, "support_focus")
			UnitScript.UnitType.LANCER:
				score += 11.0 * _stat(profile, "tower_focus")
			UnitScript.UnitType.RIDER:
				score += 16.0 * _stat(profile, "tempo_focus") + 8.0 * _stat(profile, "risk_tolerance")
		for enemy: Unit in enemy_units:
			score += UnitScript.get_damage_multiplier(unit_type, enemy.unit_type) * 7.0
		if free_summon:
			score += 10.0
		if score > best_score:
			best_score = score
			best_type = unit_type
	return best_type

func _choose_summon_cell(player_id: int, summon_cells: Array, profile: Dictionary, chosen_type: int = -1) -> Vector2i:
	var best_cell := Vector2i(-1, -1)
	var best_score: float = -INF
	var enemy_cells: Array[Vector2i] = _get_enemy_cells(player_id)
	var own_master_cell: Vector2i = _get_player_master_cell(player_id)
	for cell_value: Variant in summon_cells:
		var cell: Vector2i = cell_value as Vector2i
		var score: float = _board_position_score(cell, profile, enemy_cells, [], own_master_cell)
		if chosen_type == UnitScript.UnitType.ARCHER:
			score += float(_nearest_enemy_distance(cell, enemy_cells)) * 1.6
		elif chosen_type == UnitScript.UnitType.RIDER:
			score -= float(_nearest_enemy_distance(cell, enemy_cells)) * 1.9
		else:
			score -= float(_nearest_enemy_distance(cell, enemy_cells)) * 1.2
		score += float(UnitScript.TERRAIN_ATTACK_MODIFIERS.get(hex_grid.get_terrain_at(cell.x, cell.y), 0)) * 3.0
		score += randf() * 0.5
		if score > best_score:
			best_score = score
			best_cell = cell
	return best_cell

func _wait(seconds: float) -> void:
	var tree: SceneTree = get_tree()
	if tree == null and is_instance_valid(hex_grid):
		tree = hex_grid.get_tree()
	if tree == null and is_instance_valid(hud):
		tree = hud.get_tree()
	if tree == null:
		return
	await tree.create_timer(seconds).timeout

func _is_scripted_tutorial_enemy(player_id: int) -> bool:
	return GameData.tutorial_mode_active and GameData.tutorial_chapter_id == "chapter_1" and player_id == 2

func _get_scripted_enemy_master(player_id: int) -> Unit:
	for unit: Unit in hex_grid.get_units_for_player(player_id):
		if unit is Master:
			return unit
	return null

func _get_scripted_enemy_master_target_cell(player_id: int) -> Vector2i:
	return Vector2i(7, 3) if _is_scripted_tutorial_enemy(player_id) else Vector2i(-1, -1)

func _get_profile(player_id: int) -> Dictionary:
	if _profiles.has(player_id):
		return _profiles[player_id]
	var faction: int = GameData.get_faction_for_player(player_id)
	var rng := RandomNumberGenerator.new()
	var seed_value: int = int(GameData.map_seed) + player_id * 997 + faction * 131
	rng.seed = seed_value if seed_value != 0 else (player_id * 7001 + 17)
	var p: Dictionary = {
		"name": PERSONA_NAMES[int(rng.randi() % PERSONA_NAMES.size())],
		"aggression": 1.0, "tower_focus": 1.0, "economy_focus": 1.0, "card_focus": 1.0,
		"risk_tolerance": 1.0, "support_focus": 1.0, "master_focus": 1.0, "tempo_focus": 1.0,
	}
	match faction:
		FactionDataScript.Faction.GAUCHOS:
			p["aggression"] = 1.18; p["tempo_focus"] = 1.22; p["risk_tolerance"] = 1.12; p["card_focus"] = 1.08
		FactionDataScript.Faction.MILITARES:
			p["economy_focus"] = 1.18; p["tower_focus"] = 1.12; p["aggression"] = 1.08; p["master_focus"] = 1.06
		FactionDataScript.Faction.INDIOS:
			p["support_focus"] = 1.26; p["tower_focus"] = 1.22; p["card_focus"] = 1.16; p["risk_tolerance"] = 0.92
		FactionDataScript.Faction.BRUJOS:
			p["card_focus"] = 1.28; p["master_focus"] = 1.18; p["risk_tolerance"] = 1.05; p["aggression"] = 0.96
	for key: String in ["aggression", "tower_focus", "economy_focus", "card_focus", "risk_tolerance", "support_focus", "master_focus", "tempo_focus"]:
		p[key] = clampf(float(p[key]) + rng.randf_range(-0.16, 0.16), 0.72, 1.36)
	_profiles[player_id] = p
	return p

func _stat(profile: Dictionary, key: String) -> float:
	return float(profile.get(key, 1.0))

func _urgency(unit: Unit, profile: Dictionary) -> float:
	var score: float = 0.0
	if unit is Master:
		score += 8.0 * _stat(profile, "master_focus")
	if unit.hp <= maxi(5, unit.max_hp / 3):
		score -= 14.0 * (1.2 - _stat(profile, "risk_tolerance") * 0.35)
	score += _threat(unit) * 0.7
	return score

func _retaliation_risk(attacker: Unit, target: Unit) -> float:
	var cell: Vector2i = target.get_hex_cell()
	var terrain: int = hex_grid.get_terrain_at(cell.x, cell.y) if cell != Vector2i(-1, -1) else 0
	var score: float = float(target.get_attack_count_for_terrain(terrain)) * 1.6 + float(target.hp) * 0.15
	if target is Master:
		score += 9.0
	return score

func _score_attack_target(attacker: Unit, target: Unit, profile: Dictionary) -> float:
	if attacker == null or target == null:
		return -INF
	var multiplier: float = UnitScript.get_damage_multiplier(attacker.unit_type, target.unit_type)
	var score: float = 0.0
	score += 130.0 if target.hp <= 4 else 0.0
	score += 55.0 * _stat(profile, "master_focus") if target is Master else 0.0
	score += float(target.max_hp - target.hp) * (1.8 + _stat(profile, "aggression"))
	score += multiplier * (10.0 + _stat(profile, "aggression") * 6.0)
	score += float(target.level) * 4.5
	score -= _retaliation_risk(attacker, target) * (1.45 - _stat(profile, "risk_tolerance") * 0.55)
	var target_cell: Vector2i = target.get_hex_cell()
	var owned_towers: Array[Vector2i] = _get_owned_tower_cells(attacker.owner_id)
	if _is_cell_in_list(target_cell, owned_towers):
		score += 48.0
	elif _is_cell_adjacent_to_any(target_cell, owned_towers):
		score += 24.0
	return score

func _threat(unit: Unit) -> float:
	var score: float = 0.0
	var unit_cell: Vector2i = hex_grid.get_cell_for_unit(unit)
	if unit_cell == Vector2i(-1, -1):
		return score
	for unit_value: Variant in hex_grid.get_all_units():
		var other: Unit = unit_value as Unit
		if other == null or other.owner_id == unit.owner_id:
			continue
		var other_cell: Vector2i = hex_grid.get_cell_for_unit(other)
		if other_cell == Vector2i(-1, -1):
			continue
		var dist: int = hex_grid.get_distance_between_cells(unit_cell, other_cell)
		if dist <= 1:
			score += 4.0
		elif dist == 2 and other.has_ranged_attack():
			score += 2.5
	return score

func _board_position_score(cell: Vector2i, profile: Dictionary, enemy_cells: Array[Vector2i], tower_targets: Array[Vector2i], own_master_cell: Vector2i) -> float:
	var score: float = 0.0
	for tower_cell: Vector2i in tower_targets:
		if tower_cell == cell:
			score += 84.0 * _stat(profile, "tower_focus")
		else:
			score -= float(hex_grid.get_distance_between_cells(cell, tower_cell)) * (3.4 + _stat(profile, "tower_focus") * 2.0)
	for enemy_cell: Vector2i in enemy_cells:
		score -= float(hex_grid.get_distance_between_cells(cell, enemy_cell)) * (1.6 + _stat(profile, "aggression") * 1.8)
	if own_master_cell != Vector2i(-1, -1):
		score -= float(hex_grid.get_distance_between_cells(cell, own_master_cell)) * (0.5 + _stat(profile, "master_focus") * 0.35)
	return score

func _score_move_target(unit: Unit, cell: Vector2i, profile: Dictionary, enemy_cells: Array[Vector2i], tower_targets: Array[Vector2i], own_master_cell: Vector2i, owned_towers: Array[Vector2i], contested_towers: Array[Vector2i]) -> float:
	if unit == null or cell == Vector2i(-1, -1):
		return -INF
	var score: float = 0.0
	score += _board_position_score(cell, profile, enemy_cells, tower_targets, own_master_cell)
	score += float(UnitScript.TERRAIN_ATTACK_MODIFIERS.get(hex_grid.get_terrain_at(cell.x, cell.y), 0)) * 5.0
	if unit.hp <= maxi(5, unit.max_hp / 3):
		score += float(_nearest_enemy_distance(cell, enemy_cells)) * 4.0
	var opening_phase: bool = _is_opening_phase()
	if _is_cell_in_list(cell, tower_targets):
		score += 92.0
		if opening_phase:
			score += 72.0
	if _is_cell_in_list(cell, owned_towers):
		score += 28.0
	if _is_cell_in_list(cell, contested_towers):
		score += 88.0
	elif _is_cell_adjacent_to_any(cell, contested_towers):
		score += 34.0
	for tower_cell: Vector2i in contested_towers:
		score -= float(hex_grid.get_distance_between_cells(cell, tower_cell)) * 4.0
	if opening_phase:
		for tower_cell: Vector2i in tower_targets:
			score -= float(hex_grid.get_distance_between_cells(cell, tower_cell)) * 2.8
	return score

func _should_prioritize_move(player_id: int, move_target: Vector2i, move_score: float, attack_target: Unit, attack_score: float) -> bool:
	if move_target == Vector2i(-1, -1):
		return false
	var tower_targets: Array[Vector2i] = _get_enemy_or_neutral_tower_cells(player_id)
	var contested_towers: Array[Vector2i] = _get_contested_owned_tower_cells(player_id)
	var captures_tower: bool = _is_cell_in_list(move_target, tower_targets)
	var reinforces_tower: bool = _is_cell_in_list(move_target, contested_towers) or _is_cell_adjacent_to_any(move_target, contested_towers)
	var attack_is_emergency: bool = _is_high_priority_attack(player_id, attack_target, attack_score)
	if captures_tower and not attack_is_emergency:
		return true
	if reinforces_tower and (not attack_is_emergency or move_score >= attack_score - 10.0):
		return true
	if _is_opening_phase() and move_score > attack_score + 20.0:
		return true
	return false

func _is_high_priority_attack(player_id: int, target: Unit, attack_score: float) -> bool:
	if target == null:
		return false
	if target is Master or target.hp <= 4:
		return true
	var target_cell: Vector2i = target.get_hex_cell()
	var owned_towers: Array[Vector2i] = _get_owned_tower_cells(player_id)
	if _is_cell_in_list(target_cell, owned_towers) or _is_cell_adjacent_to_any(target_cell, owned_towers):
		return true
	return attack_score >= 120.0

func _best_unit_by_score(units: Array, scorer: Callable, skip_null: bool = false) -> Unit:
	var best_unit: Unit = null
	var best_score: float = -INF
	for unit_value: Variant in units:
		var unit: Unit = unit_value as Unit
		if unit == null and skip_null:
			continue
		var score: float = float(scorer.call(unit))
		if score > best_score:
			best_score = score
			best_unit = unit
	return best_unit

func _score_control(target: Unit, effect: String, profile: Dictionary) -> float:
	var score: float = 24.0 + float(target.level) * 5.0 + _threat(target) * (2.2 + _stat(profile, "support_focus"))
	if effect == "poison":
		score += float(target.hp) * 0.85
	elif effect == "attack_debuff":
		var cell: Vector2i = target.get_hex_cell()
		var terrain: int = hex_grid.get_terrain_at(cell.x, cell.y) if cell != Vector2i(-1, -1) else 0
		score += float(target.get_attack_count_for_terrain(terrain)) * 6.0
	return score

func _score_damage_card(target: Unit, value: int, profile: Dictionary) -> float:
	if target == null:
		return -INF
	var score: float = float(value) * (2.4 + _stat(profile, "aggression"))
	score += 110.0 if target.hp <= value else 0.0
	score += float(target.max_hp - target.hp) * 1.6
	score += float(target.level) * (4.5 + _stat(profile, "master_focus"))
	return score

func _score_heal_card(target: Unit, value: int, profile: Dictionary) -> float:
	if target == null:
		return -INF
	var missing_hp: int = target.max_hp - target.hp
	var effective_heal: int = mini(missing_hp, value)
	var score: float = float(effective_heal) * (4.4 + _stat(profile, "support_focus"))
	score += 28.0 * _stat(profile, "master_focus") if target is Master else 0.0
	score += float(target.level) * 2.8
	score += _threat(target) * 3.0
	return score

func _score_exp_card(target: Unit, value: int, profile: Dictionary) -> float:
	if target == null:
		return -INF
	var exp_required: int = int(target.get_exp_required())
	var to_level: int = maxi(0, exp_required - int(target.experience))
	var score: float = float(value) * (2.8 + _stat(profile, "tempo_focus"))
	score += 72.0 if value >= to_level and to_level > 0 else 0.0
	score += float(target.level) * 3.6
	score += 10.0 * _stat(profile, "master_focus") if target is Master else 0.0
	return score

func _score_essence_card(player_id: int, value: int, profile: Dictionary) -> float:
	var current_essence: int = resource_manager.get_essence(player_id)
	var best_now: int = _best_affordable_summon_cost(current_essence)
	var best_after: int = _best_affordable_summon_cost(current_essence + value)
	if best_after > best_now:
		return 88.0 + float(best_after - best_now) * 5.0 + _stat(profile, "economy_focus") * 16.0
	if current_essence < 10:
		return 12.0 + float(value) * (0.8 + _stat(profile, "economy_focus"))
	return 3.5 + float(value) * 0.45

func _score_refresh_card(target: Unit, profile: Dictionary) -> float:
	if target == null or (not target.moved and not target.has_attacked):
		return -INF
	var score: float = 20.0 + float(target.level) * 6.0
	score += _threat(target) * (2.8 + _stat(profile, "support_focus"))
	score += 18.0 * _stat(profile, "master_focus") if target is Master else 0.0
	score += 12.0 * _stat(profile, "tempo_focus") if target.moved else 0.0
	score += 16.0 * _stat(profile, "aggression") if target.has_attacked else 0.0
	return score

func _score_extra_move(target: Unit, profile: Dictionary) -> float:
	if target == null or target.moved or (hex_grid.get_action_options_for_unit(target).get("move_cells", []) as Array).is_empty():
		return -INF
	var score: float = 16.0 + float(target.level) * 5.0 + _stat(profile, "tempo_focus") * 11.0
	score += 12.0 if target.unit_type == UnitScript.UnitType.RIDER else 0.0
	return score

func _score_double_attack(target: Unit, profile: Dictionary) -> float:
	if target == null or target.has_attacked or not _unit_has_attack_options(target):
		return -INF
	var score: float = 32.0 + float(target.level) * 8.0 + _stat(profile, "aggression") * 14.0
	score += 18.0 if target.unit_type == UnitScript.UnitType.LANCER else 0.0
	score += 16.0 if target.unit_type == UnitScript.UnitType.WARRIOR else 0.0
	return score

func _score_defense(target: Unit, profile: Dictionary) -> float:
	if target == null:
		return -INF
	var score: float = 10.0 + _threat(target) * (3.0 + _stat(profile, "support_focus"))
	score += 24.0 * _stat(profile, "master_focus") if target is Master else 0.0
	score += 12.0 if target.hp <= target.max_hp / 2 else 0.0
	return score

func _best_tower_heal_cell(player_id: int, profile: Dictionary) -> Vector2i:
	var best_cell: Vector2i = Vector2i(-1, -1)
	var best_score: float = -INF
	for tower_value: Variant in hex_grid.get_all_towers():
		var tower = tower_value
		if tower == null or int(tower.owner_id) != player_id:
			continue
		var cell: Vector2i = tower.position
		var score: float = _score_tower_heal(player_id, cell, 1, profile)
		if score > best_score:
			best_score = score
			best_cell = cell
	return best_cell

func _score_tower_heal(player_id: int, cell: Vector2i, value: int, profile: Dictionary) -> float:
	var unit: Unit = hex_grid.get_unit_at(cell.x, cell.y)
	if unit == null or unit.owner_id != player_id or unit.hp >= unit.max_hp:
		return -INF
	var heal_value: int = mini(unit.max_hp - unit.hp, maxi(1, value))
	return float(heal_value) * (10.0 + _stat(profile, "support_focus") * 2.0) + _stat(profile, "tower_focus") * 12.0

func _score_heal_all(player_id: int, value: int, profile: Dictionary) -> float:
	var total_missing: int = 0
	var affected: int = 0
	for unit: Unit in hex_grid.get_units_for_player(player_id):
		if unit != null and unit.hp < unit.max_hp:
			total_missing += mini(value, unit.max_hp - unit.hp)
			affected += 1
	if affected == 0:
		return -INF
	return float(total_missing) * (2.6 + _stat(profile, "support_focus")) + float(affected) * 8.0

func _score_sacrifice_essence(player_id: int, value: int, profile: Dictionary) -> float:
	var master: Unit = _get_player_master(player_id)
	if master == null or master.hp <= 10:
		return -INF
	return _score_essence_card(player_id, value, profile) + 18.0 - float(18 - master.hp) * (1.4 - _stat(profile, "risk_tolerance") * 0.4)

func _best_swap_target(player_id: int, profile: Dictionary) -> Unit:
	var master: Unit = _get_player_master(player_id)
	if master == null or master.hp >= master.max_hp:
		return null
	return _best_unit_by_score(_get_enemy_units(player_id), func(u: Unit) -> float: return -INF if u is Master else _score_swap_hp(player_id, u, profile), true)

func _score_swap_hp(player_id: int, target: Unit, profile: Dictionary) -> float:
	var master: Unit = _get_player_master(player_id)
	if master == null or target == null:
		return -INF
	var hp_gain: int = maxi(0, mini(target.hp, master.max_hp) - master.hp)
	if hp_gain <= 0:
		return -INF
	return float(hp_gain) * (4.5 + _stat(profile, "master_focus")) + float(target.level) * 6.0 + (18.0 if master.hp <= master.max_hp / 2 else 0.0)

func _score_free_summon(player_id: int, profile: Dictionary) -> float:
	var summon_cells: Array[Vector2i] = hex_grid.get_valid_summon_cells(player_id)
	if summon_cells.is_empty():
		return -INF
	return 64.0 + _stat(profile, "tempo_focus") * 12.0 + float(maxi(0, 3 - hex_grid.get_units_for_player(player_id).size())) * 7.0

func _score_revive(player_id: int, profile: Dictionary) -> float:
	var dead_units: Array = CardManager.dead_units_by_player.get(player_id, [])
	if dead_units.is_empty() or (hex_grid.get_valid_summon_cells(player_id) as Array).is_empty():
		return -INF
	return 54.0 + float(dead_units.size()) * 9.0 + _stat(profile, "tempo_focus") * 8.0

func _score_aoe_damage(player_id: int, value: int, profile: Dictionary) -> float:
	if hex_grid == null or not hex_grid.has_method("get_enemy_units_near_towers"):
		return -INF
	var targets: Array = hex_grid.call("get_enemy_units_near_towers", player_id)
	if targets.is_empty():
		return -INF
	var score: float = 0.0
	for target_value: Variant in targets:
		var target: Unit = target_value as Unit
		if target != null:
			score += float(value) * 4.0
			score += 16.0 if target.hp <= value else 0.0
			score += float(target.level) * 3.0
	return score + _stat(profile, "aggression") * 8.0

func _unit_has_attack_options(unit: Unit) -> bool:
	return unit != null and not (hex_grid.get_action_options_for_unit(unit).get("attack_cells", []) as Array).is_empty()

func _get_enemy_units(player_id: int) -> Array[Unit]:
	var result: Array[Unit] = []
	for unit_value: Variant in hex_grid.get_all_units():
		var unit: Unit = unit_value as Unit
		if unit != null and unit.owner_id != player_id:
			result.append(unit)
	return result

func _get_enemy_cells(player_id: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for enemy: Unit in _get_enemy_units(player_id):
		var cell: Vector2i = hex_grid.get_cell_for_unit(enemy)
		if cell != Vector2i(-1, -1):
			result.append(cell)
	return result

func _get_enemy_or_neutral_tower_cells(player_id: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for tower_value: Variant in hex_grid.get_all_towers():
		var tower = tower_value
		if tower != null and int(tower.owner_id) != player_id:
			result.append(tower.position)
	return result

func _get_owned_tower_cells(player_id: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for tower_value: Variant in hex_grid.get_all_towers():
		var tower = tower_value
		if tower != null and int(tower.owner_id) == player_id:
			result.append(tower.position)
	return result

func _get_contested_owned_tower_cells(player_id: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var owned_towers: Array[Vector2i] = _get_owned_tower_cells(player_id)
	for tower_cell: Vector2i in owned_towers:
		for neighbor_value: Variant in hex_grid.get_neighbors_of(tower_cell):
			var neighbor: Vector2i = neighbor_value as Vector2i
			var unit: Unit = hex_grid.get_unit_at(neighbor.x, neighbor.y)
			if unit != null and unit.owner_id != player_id:
				result.append(tower_cell)
				break
	return result

func _has_tower_capture_move(player_id: int, move_cells: Array) -> bool:
	for cell_value: Variant in move_cells:
		var cell: Vector2i = cell_value as Vector2i
		var tower = hex_grid.get_tower_at(cell.x, cell.y)
		if tower != null and int(tower.owner_id) != player_id:
			return true
	return false

func _can_reinforce_tower(move_cells: Array, contested_towers: Array[Vector2i]) -> bool:
	for cell_value: Variant in move_cells:
		var cell: Vector2i = cell_value as Vector2i
		if _is_cell_in_list(cell, contested_towers) or _is_cell_adjacent_to_any(cell, contested_towers):
			return true
	return false

func _get_player_master(player_id: int) -> Unit:
	for unit: Unit in hex_grid.get_units_for_player(player_id):
		if unit is Master:
			return unit
	return null

func _get_player_master_cell(player_id: int) -> Vector2i:
	var master: Unit = _get_player_master(player_id)
	return hex_grid.get_cell_for_unit(master) if master != null else Vector2i(-1, -1)

func _nearest_enemy_distance(cell: Vector2i, enemy_cells: Array[Vector2i]) -> int:
	var best: int = 999
	for enemy_cell: Vector2i in enemy_cells:
		best = mini(best, hex_grid.get_distance_between_cells(cell, enemy_cell))
	return best if best != 999 else 6

func _is_cell_in_list(cell: Vector2i, cells: Array[Vector2i]) -> bool:
	for other: Vector2i in cells:
		if other == cell:
			return true
	return false

func _is_cell_adjacent_to_any(cell: Vector2i, targets: Array[Vector2i]) -> bool:
	for target: Vector2i in targets:
		if hex_grid.get_distance_between_cells(cell, target) == 1:
			return true
	return false

func _is_opening_phase() -> bool:
	return int(GameData.turns_played) <= 3

func _best_affordable_summon_cost(essence_amount: int) -> int:
	var best_cost: int = 0
	for cost_value: Variant in SummonManagerScript.SUMMON_COSTS.values():
		var cost: int = int(cost_value)
		if cost <= essence_amount and cost > best_cost:
			best_cost = cost
	return best_cost
