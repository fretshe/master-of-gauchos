extends "res://scripts/Unit.gd"

class_name Master

const UNIT_TYPE_MASTER := Unit.MASTER_UNIT_TYPE

var is_master: bool = true
var free_summon_used: bool = false
var faction: int = 0

func init_master(p_owner: int, p_faction: int = 0) -> void:
	owner_id = p_owner
	unit_name = "Maestro J%d" % p_owner
	unit_type = UNIT_TYPE_MASTER
	level = Level.GOLD
	faction = p_faction
	max_hp = get_max_hp()
	hp = max_hp
	move_range = get_master_move_range()
	attack_range = 2 if (p_faction == 2 or p_faction == 3) else 1
	experience = 0

func get_master_move_range() -> int:
	return 3 if faction == FactionData.Faction.MILITARES else 2

func get_max_level() -> int:
	return Level.DIAMOND

func get_max_hp() -> int:
	match level:
		Level.GOLD:
			return 60
		Level.PLATINUM:
			return 72
		Level.DIAMOND:
			return 86
		_:
			return 52

func get_melee_dice() -> Array:
	match level:
		Level.DIAMOND:
			return [DiceColor.DIAMOND]
		Level.PLATINUM:
			return [DiceColor.PLATINUM]
		_:
			return [DiceColor.GOLD]

func get_ranged_dice() -> Array:
	if faction == 2:
		match level:
			Level.DIAMOND:
				return [DiceColor.DIAMOND]
			Level.PLATINUM:
				return [DiceColor.PLATINUM]
			_:
				return [DiceColor.GOLD]
	elif faction == 3:
		match level:
			Level.DIAMOND:
				return [DiceColor.DIAMOND]
			Level.PLATINUM:
				return [DiceColor.PLATINUM]
			_:
				return [DiceColor.GOLD]
	return []

func has_ranged_attack() -> bool:
	return faction == 2 or faction == 3

func get_damage_scale_per_hit() -> float:
	match level:
		Level.DIAMOND:
			return 0.56
		Level.PLATINUM:
			return 0.54
		_:
			return 0.52

func get_exp_required() -> int:
	match level:
		Level.GOLD:
			return 42
		Level.PLATINUM:
			return 58
		_:
			return 76

func gain_exp(amount: int) -> void:
	gain_exp_with_result(amount)

func reset_moves() -> void:
	moved = false
	has_attacked = false
	move_bonus = 0
	extra_attacks = 0
	attack_debuff = 0
	defense_buff = 0
	untargetable = false
	moves_this_turn = 0
	leadership_xp_bonus = false
	free_summon_used = false

func stats_string() -> String:
	return "[Master] %s (P%d) | %s | HP:%d/%d | MOV:%d(%s) | HIT:%d | EXP:%d/%d" % [
		unit_name, owner_id, _level_name(), hp, max_hp,
		move_range, "OK" if not moved else "X",
		get_base_attack_count(),
		experience, get_exp_required()
	]
