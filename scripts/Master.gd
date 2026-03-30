extends "res://scripts/Unit.gd"

class_name Master

# â”€â”€â”€ Identification â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
const UNIT_TYPE_MASTER := Unit.MASTER_UNIT_TYPE

var is_master:        bool = true
var free_summon_used: bool = false

# â”€â”€â”€ Constructor â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
func init_master(p_owner: int) -> void:
	owner_id     = p_owner
	unit_name    = "Maestro J%d" % p_owner
	unit_type    = UNIT_TYPE_MASTER
	level        = Level.GOLD
	max_hp       = get_max_hp()
	hp           = max_hp
	move_range   = 2
	attack_range = 2   # always ranged-capable
	experience   = 0

# â”€â”€â”€ Level cap â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
func get_max_level() -> int:
	return Level.DIAMOND

func get_max_hp() -> int:
	match level:
		Level.DIAMOND: return 60
		_:             return 48

# â”€â”€â”€ Dice (Master always uses Blue dice; count grows at Diamond) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
func get_melee_dice() -> Array:
	if level >= Level.DIAMOND:
		return [DiceColor.BLUE, DiceColor.YELLOW]
	return [DiceColor.BLUE]

func get_ranged_dice() -> Array:
	if level >= Level.DIAMOND:
		return [DiceColor.BLUE, DiceColor.YELLOW]
	return [DiceColor.BLUE]

func has_ranged_attack() -> bool:
	return true

func get_damage_scale_per_hit() -> float:
	if level >= Level.DIAMOND:
		return 0.40
	return 0.50

func get_exp_required() -> int:
	return 40

# â”€â”€â”€ Experience â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
func gain_exp(amount: int) -> void:
	if level >= Level.DIAMOND:
		experience = 0
		return
	experience += amount
	if experience >= get_exp_required():
		experience = 0
		hp  = max_hp   # full heal
		if level < Level.DIAMOND:
			_level_up()

# â”€â”€â”€ Movement â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
func reset_moves() -> void:
	moved            = false
	has_attacked     = false
	free_summon_used = false

# â”€â”€â”€ Debug â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
func stats_string() -> String:
	return "[Master] %s (P%d) | %s | HP:%d/%d | MOV:%d(%s) | HIT:%d | EXP:%d/%d" % [
		unit_name, owner_id, _level_name(), hp, max_hp,
		move_range, "OK" if not moved else "X",
		get_base_attack_count(),
		experience, get_exp_required()
	]
