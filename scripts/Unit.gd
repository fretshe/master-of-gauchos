extends Node2D

class_name Unit

enum UnitType  { WARRIOR, ARCHER, LANCER, RIDER }
enum Level     { BRONZE = 1, SILVER = 2, GOLD = 3, PLATINUM = 4, DIAMOND = 5 }
enum DiceColor { BRONZE, SILVER, GOLD, PLATINUM, DIAMOND }
const MASTER_UNIT_TYPE: int = -1

const TYPE_NAMES := {
	MASTER_UNIT_TYPE: "Master",
	UnitType.WARRIOR: "Warrior",
	UnitType.ARCHER: "Archer",
	UnitType.LANCER: "Lancer",
	UnitType.RIDER: "Rider",
}

const COUNTER_CHART: Array = [
	[UnitType.WARRIOR, UnitType.LANCER],
	[UnitType.LANCER, UnitType.RIDER],
	[UnitType.RIDER, UnitType.ARCHER],
	[UnitType.ARCHER, UnitType.WARRIOR],
]

const DICE := {
	DiceColor.BRONZE: [0, 0, 1, 1, 2, 2, 3, 3],
	DiceColor.SILVER: [0, 1, 1, 2, 2, 3, 3, 3],
	DiceColor.GOLD: [1, 1, 2, 2, 3, 3, 4, 4],
	DiceColor.PLATINUM: [1, 2, 2, 3, 3, 4, 4, 5],
	DiceColor.DIAMOND: [2, 2, 3, 4, 4, 5, 6, 7],
}

const UNIT_MELEE_DICE := {
	UnitType.WARRIOR: [DiceColor.BRONZE, DiceColor.SILVER, DiceColor.GOLD, DiceColor.PLATINUM, DiceColor.DIAMOND],
	UnitType.ARCHER: [DiceColor.BRONZE, DiceColor.SILVER, DiceColor.GOLD, DiceColor.GOLD, DiceColor.PLATINUM],
	UnitType.LANCER: [DiceColor.BRONZE, DiceColor.SILVER, DiceColor.GOLD, DiceColor.GOLD, DiceColor.PLATINUM],
	UnitType.RIDER: [DiceColor.BRONZE, DiceColor.SILVER, DiceColor.GOLD, DiceColor.PLATINUM, DiceColor.DIAMOND],
}

const UNIT_RANGED_DICE := {
	UnitType.WARRIOR: [null, null, null, null, null],
	UnitType.ARCHER: [DiceColor.SILVER, DiceColor.GOLD, DiceColor.GOLD, DiceColor.PLATINUM, DiceColor.DIAMOND],
	UnitType.LANCER: [DiceColor.SILVER, DiceColor.SILVER, DiceColor.GOLD, DiceColor.PLATINUM, DiceColor.DIAMOND],
	UnitType.RIDER: [null, null, null, null, null],
}

const BASE_HP := {
	UnitType.WARRIOR: 6,
	UnitType.ARCHER: 4,
	UnitType.LANCER: 5,
	UnitType.RIDER: 5,
}

const BASE_MOVE := {
	UnitType.WARRIOR: 3,
	UnitType.ARCHER: 3,
	UnitType.LANCER: 3,
	UnitType.RIDER: 4,
}

const BASE_ATTACKS_PER_COMBAT := {
	MASTER_UNIT_TYPE: 2,
	UnitType.WARRIOR: 3,
	UnitType.ARCHER: 2,
	UnitType.LANCER: 3,
	UnitType.RIDER: 2,
}

const BASE_RANGED_ATTACKS_PER_COMBAT := {
	UnitType.ARCHER: 2,
	UnitType.LANCER: 1,
}

const TERRAIN_ATTACK_MODIFIERS := {
	0: 0,
	1: -1,
	2: 2,
	3: 1,
	4: 0,
	5: 0,
	6: 0,
}

const DAMAGE_SCALE_PER_HIT := {
	UnitType.WARRIOR: [0.38, 0.37, 0.39, 0.40, 0.42],
	UnitType.ARCHER: [0.40, 0.39, 0.38, 0.39, 0.40],
	UnitType.LANCER: [0.34, 0.35, 0.36, 0.37, 0.38],
	UnitType.RIDER: [0.40, 0.41, 0.42, 0.43, 0.45],
}
const EXP_REQUIRED_BY_LEVEL := {
	UnitType.WARRIOR: [16, 26, 38, 52],
	UnitType.ARCHER: [14, 22, 32, 44],
	UnitType.LANCER: [17, 27, 39, 54],
	UnitType.RIDER: [15, 24, 35, 48],
}

var unit_name: String = ""
var unit_type: int = UnitType.WARRIOR
var owner_id: int = 1
var level: int = Level.BRONZE
var experience: int = 0

var hp: int = 0
var max_hp: int = 0
var move_range: int = 0
var attack_range: int = 1
var current_hex_cell: Vector2i = Vector2i(-1, -1)

var moved: bool = false
var has_attacked: bool = false
var move_bonus: int = 0
var extra_attacks: int = 0
var attack_debuff: int = 0
var defense_buff: int = 0
var untargetable: bool = false

var active_bonuses: Array[String] = []
var bonus_tough_skin: bool = false
var bonus_hardened_hide: bool = false
var bonus_colossus: bool = false
var bonus_veteran: bool = false
var bonus_immune: bool = false
var bonus_resistant: bool = false
var bonus_swiftness: bool = false
var bonus_raider: bool = false
var bonus_bloodletting: bool = false
var bonus_slayer_instinct: bool = false
var bonus_cataclysm: bool = false
var bonus_fury: bool = false
var bonus_battle_veteran: bool = false
var bonus_cleaver: bool = false
var bonus_executioner: bool = false
var bonus_precision: bool = false
var bonus_long_range: bool = false
var bonus_volley: bool = false
var bonus_marksman: bool = false
var bonus_javelin_expert: bool = false
var bonus_charge: bool = false
var bonus_pathfinder: bool = false
var bonus_pinning: bool = false
var bonus_flanking: bool = false
var bonus_brutal_charge: bool = false
var bonus_trample: bool = false
var bonus_outrider: bool = false
var bonus_aura: bool = false
var bonus_leadership: bool = false
var bonus_command: bool = false
var bonus_royal_guard: bool = false
var moves_this_turn: int = 0
var facing: Vector2i = Vector2i(0, 1)
var leadership_xp_bonus: bool = false

var visual_pos: Vector2 = Vector2.ZERO
var visual_scale: float = 1.0
var visual_alpha: float = 1.0
var visual_flash: float = 0.0
var visual_flash_color: Color = Color(0.95, 0.80, 0.20)

func setup(p_name: String, p_type: int, p_owner: int, p_level: int = 1) -> void:
	unit_name = p_name
	unit_type = p_type
	owner_id = p_owner
	level = clampi(p_level, Level.BRONZE, get_max_level())
	_apply_stats()

func get_max_hp() -> int:
	match unit_type:
		UnitType.WARRIOR:
			match level:
				Level.BRONZE: return 20
				Level.SILVER: return 36
				Level.GOLD: return 54
				Level.PLATINUM: return 72
				Level.DIAMOND: return 92
		UnitType.ARCHER:
			match level:
				Level.BRONZE: return 13
				Level.SILVER: return 21
				Level.GOLD: return 32
				Level.PLATINUM: return 42
				Level.DIAMOND: return 54
		UnitType.LANCER:
			match level:
				Level.BRONZE: return 23
				Level.SILVER: return 40
				Level.GOLD: return 60
				Level.PLATINUM: return 79
				Level.DIAMOND: return 100
		UnitType.RIDER:
			match level:
				Level.BRONZE: return 18
				Level.SILVER: return 32
				Level.GOLD: return 48
				Level.PLATINUM: return 64
				Level.DIAMOND: return 82
	return 5

func _apply_stats() -> void:
	max_hp = get_max_hp()
	move_range = BASE_MOVE.get(unit_type, 3)
	hp = max_hp
	attack_range = get_default_attack_range()

func take_damage(amount: int) -> bool:
	var reduction: int = defense_buff + (1 if bonus_resistant else 0)
	var actual: int = maxi(0, amount - reduction)
	hp = maxi(0, hp - actual)
	return hp == 0

func set_hex_cell(cell: Vector2i) -> void:
	current_hex_cell = cell

func clear_hex_cell() -> void:
	current_hex_cell = Vector2i(-1, -1)

func get_hex_cell() -> Vector2i:
	return current_hex_cell

func get_base_attack_count() -> int:
	return BASE_ATTACKS_PER_COMBAT.get(unit_type, 2) + (1 if bonus_cleaver or bonus_trample else 0)

func get_terrain_attack_modifier(terrain_type: int) -> int:
	return TERRAIN_ATTACK_MODIFIERS.get(terrain_type, 0)

func get_attack_count_for_terrain(terrain_type: int) -> int:
	return maxi(1, clampi(get_base_attack_count() + get_terrain_attack_modifier(terrain_type), 1, 6) - attack_debuff)

func get_ranged_attack_count_for_terrain(terrain_type: int) -> int:
	if not has_ranged_attack():
		return 0
	if unit_type == UnitType.LANCER:
		return 1
	var base: int = BASE_RANGED_ATTACKS_PER_COMBAT.get(unit_type, get_base_attack_count())
	if bonus_volley:
		base += 1
	return maxi(1, clampi(base + get_terrain_attack_modifier(terrain_type), 1, 6) - attack_debuff)

func get_damage_scale_per_hit() -> float:
	var table: Array = DAMAGE_SCALE_PER_HIT.get(unit_type, [])
	if table.is_empty():
		return 1.0
	var idx: int = clampi(level - 1, 0, table.size() - 1)
	return float(table[idx]) * get_bonus_damage_multiplier()

func get_bonus_damage_multiplier() -> float:
	var bonus_multiplier: float = 1.0
	if bonus_bloodletting:
		bonus_multiplier += 0.08
	if bonus_slayer_instinct:
		bonus_multiplier += 0.14
	if bonus_cataclysm:
		bonus_multiplier += 0.20
	return bonus_multiplier

func get_bonus_critical_damage_multiplier() -> float:
	var crit_multiplier: float = 1.0
	if bonus_bloodletting:
		crit_multiplier += 0.05
	if bonus_slayer_instinct:
		crit_multiplier += 0.10
	if bonus_cataclysm:
		crit_multiplier += 0.20
	return crit_multiplier

func get_exp_required() -> int:
	var curve: Array = EXP_REQUIRED_BY_LEVEL.get(unit_type, [12, 18, 24, 30])
	var idx: int = clampi(level - 1, 0, curve.size() - 1)
	return int(curve[idx])

func get_max_level() -> int:
	return Level.DIAMOND

func gain_exp(amount: int) -> void:
	gain_exp_with_result(amount)

func gain_exp_with_result(amount: int) -> Dictionary:
	var gained: int = maxi(0, amount)
	var previous_level: int = level
	if gained <= 0:
		return {
			"gained": 0,
			"leveled_up": false,
			"previous_level": previous_level,
			"current_level": level,
			"current_exp": experience,
			"required_exp": get_exp_required(),
			"hp": hp,
			"max_hp": max_hp,
		}
	experience += gained
	var leveled_up: bool = false
	if experience >= get_exp_required():
		experience = 0
		if level < get_max_level():
			_level_up()
			leveled_up = true
		else:
			AudioManager.play_level_up()
			VFXManager.flash_unit(self, Color(0.95, 0.82, 0.20))
	return {
		"gained": gained,
		"leveled_up": leveled_up,
		"previous_level": previous_level,
		"current_level": level,
		"current_exp": experience,
		"required_exp": get_exp_required(),
		"hp": hp,
		"max_hp": max_hp,
	}

func _level_up() -> void:
	var previous_hp: int = hp
	var was_dead: bool = previous_hp <= 0
	level += 1
	max_hp = get_max_hp()
	if was_dead:
		hp = 0
	else:
		var level_up_heal: int = maxi(2, int(round(float(max_hp) * 0.75)))
		hp = mini(max_hp, previous_hp + level_up_heal)
	attack_range = get_default_attack_range()
	BonusSystem.reapply_stat_bonuses(self)
	print("[Unit] %s subio a %s! HP:%d/%d MOV:%d" % [
		unit_name, _level_name(), hp, max_hp, move_range
	])
	if was_dead:
		return
	AudioManager.play_level_up()
	VFXManager.particles_level_up(visual_pos)
	VFXManager.flash_unit(self, Color(0.95, 0.82, 0.20))
	BonusSystem.queue_bonus_selection(self)

func _level_name() -> String:
	match level:
		Level.BRONZE: return "BRONCE"
		Level.SILVER: return "PLATA"
		Level.GOLD: return "ORO"
		Level.PLATINUM: return "PLATINO"
		Level.DIAMOND: return "DIAMANTE"
		_: return str(level)

func get_moves_left() -> int:
	return (move_range + move_bonus) if not moved else 0

func use_move(_cost: int = 1) -> void:
	moved = true

func exhaust() -> void:
	moved = true

func reset_moves() -> void:
	moved = false
	has_attacked = false
	move_bonus = 0
	extra_attacks = 1 if bonus_javelin_expert else 0
	attack_debuff = 0
	defense_buff = 0
	untargetable = false
	moves_this_turn = 0
	leadership_xp_bonus = false

func get_melee_dice() -> Array:
	var table: Array = UNIT_MELEE_DICE.get(unit_type, [])
	if table.is_empty():
		return []
	var idx: int = clampi(level - 1, 0, table.size() - 1)
	var die = table[idx]
	return [] if die == null else [die]

func get_ranged_dice() -> Array:
	var table: Array = UNIT_RANGED_DICE.get(unit_type, [])
	if table.is_empty():
		return []
	var idx: int = clampi(level - 1, 0, table.size() - 1)
	var die = table[idx]
	return [] if die == null else [die]

func has_ranged_attack() -> bool:
	return has_extended_attack_range() and not get_ranged_dice().is_empty()

func has_extended_attack_range() -> bool:
	if unit_type == MASTER_UNIT_TYPE:
		return not get_ranged_dice().is_empty()
	return unit_type == UnitType.ARCHER or unit_type == UnitType.LANCER

func get_default_attack_range() -> int:
	return 2 if has_extended_attack_range() else 1

func can_attack_at_distance(distance: int) -> bool:
	if distance <= 1:
		return true
	return distance <= attack_range and has_extended_attack_range() and has_ranged_attack()

func roll_dice(color: int) -> int:
	var faces: Array = DICE.get(color, [0])
	return faces[randi() % faces.size()]

static func get_damage_multiplier(attacker_type: int, defender_type: int) -> float:
	for pair: Array in COUNTER_CHART:
		if pair[0] == attacker_type and pair[1] == defender_type:
			return 1.75
		if pair[0] == defender_type and pair[1] == attacker_type:
			return 0.60
	return 1.0

func stats_string() -> String:
	return "[%s] %s (P%d) | %s | HP:%d/%d | MOV:%d(%s) | HIT:%d | EXP:%d/%d" % [
		TYPE_NAMES.get(unit_type, "?"), unit_name, owner_id,
		_level_name(), hp, max_hp,
		move_range, "OK" if not moved else "X",
		get_base_attack_count(),
		experience, get_exp_required()
	]
