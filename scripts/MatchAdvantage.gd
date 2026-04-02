extends RefCounted

class_name MatchAdvantage

const BASE_UNIT_VALUES := {
	Unit.UnitType.WARRIOR: 10.0,
	Unit.UnitType.ARCHER: 11.0,
	Unit.UnitType.LANCER: 12.0,
	Unit.UnitType.RIDER: 13.0,
}

const LEVEL_MULTIPLIERS := {
	Unit.Level.BRONZE: 1.00,
	Unit.Level.SILVER: 1.35,
	Unit.Level.GOLD: 1.75,
	Unit.Level.PLATINUM: 2.20,
	Unit.Level.DIAMOND: 2.70,
}

const TOWER_CONTROL_WEIGHT := 120
const TOWER_INCOME_WEIGHT := 25
const MASTER_HP_WEIGHT := 3
const HAND_WEIGHT := 8
const ESSENCE_WEIGHT := 1
const ARMY_UNIT_SCALE := 6.0


func calculate_scores(hex_grid: Node, resource_manager: Node) -> Dictionary:
	var results: Dictionary = {}
	var player_ids: Array[int] = GameData.get_player_ids()
	for player_id: int in player_ids:
		results[player_id] = _build_player_score(player_id, hex_grid, resource_manager)
	return results


func get_sorted_rows(hex_grid: Node, resource_manager: Node) -> Array[Dictionary]:
	var scores: Dictionary = calculate_scores(hex_grid, resource_manager)
	var rows: Array[Dictionary] = []
	for player_id: int in scores.keys():
		var row: Dictionary = scores[player_id] as Dictionary
		rows.append(row)

	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var score_a: int = int(a.get("score", 0))
		var score_b: int = int(b.get("score", 0))
		if score_a == score_b:
			return int(a.get("player_id", 0)) < int(b.get("player_id", 0))
		return score_a > score_b
	)
	return rows


func get_status_text(hex_grid: Node, resource_manager: Node) -> String:
	var rows: Array[Dictionary] = get_sorted_rows(hex_grid, resource_manager)
	if rows.size() <= 1:
		return "Sin rival"

	var leader: Dictionary = rows[0]
	var runner_up: Dictionary = rows[1]
	var diff: int = int(leader.get("score", 0)) - int(runner_up.get("score", 0))
	var leader_name: String = GameData.get_player_name(int(leader.get("player_id", 0)))

	if diff <= 35:
		return "Partida equilibrada"
	if diff <= 90:
		return "Ventaja leve %s" % leader_name
	if diff <= 180:
		return "Ventaja clara %s" % leader_name
	return "Dominio %s" % leader_name


func _build_player_score(player_id: int, hex_grid: Node, resource_manager: Node) -> Dictionary:
	var towers_controlled: int = 0
	var tower_income: int = 0
	if hex_grid != null and hex_grid.has_method("get_all_towers"):
		for tower_value: Variant in hex_grid.get_all_towers():
			var tower: Tower = tower_value as Tower
			if tower == null or tower.owner_id != player_id:
				continue
			towers_controlled += 1
			tower_income += int(tower.income)

	var army_score: int = 0
	var master_hp: int = 0
	if hex_grid != null and hex_grid.has_method("get_all_units"):
		for unit_value: Variant in hex_grid.get_all_units():
			var unit: Unit = unit_value as Unit
			if unit == null or unit.owner_id != player_id:
				continue
			if unit is Master:
				master_hp += int(unit.hp)
				continue
			army_score += _score_unit(unit)

	var hand_size: int = CardManager.get_hand(player_id).size()
	var essence: int = 0
	if resource_manager != null and resource_manager.has_method("get_essence"):
		essence = int(resource_manager.get_essence(player_id))

	var score: int = 0
	score += towers_controlled * TOWER_CONTROL_WEIGHT
	score += tower_income * TOWER_INCOME_WEIGHT
	score += army_score
	score += master_hp * MASTER_HP_WEIGHT
	score += hand_size * HAND_WEIGHT
	score += essence * ESSENCE_WEIGHT

	return {
		"player_id": player_id,
		"score": score,
		"towers": towers_controlled,
		"income": tower_income,
		"army": army_score,
		"master_hp": master_hp,
		"hand": hand_size,
		"essence": essence,
	}


func _score_unit(unit: Unit) -> int:
	var base_value: float = float(BASE_UNIT_VALUES.get(int(unit.unit_type), 10.0))
	var multiplier: float = float(LEVEL_MULTIPLIERS.get(int(unit.level), 1.0))
	return int(round(base_value * multiplier * ARMY_UNIT_SCALE))
