extends "res://scripts/Unit.gd"

class_name Master

# ─── Identification ──────────────────────────────────────────────────────────────
const UNIT_TYPE_MASTER := -1

var is_master:        bool = true
var free_summon_used: bool = false

# ─── Constructor ─────────────────────────────────────────────────────────────────
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

# ─── Level cap ───────────────────────────────────────────────────────────────────
func get_max_level() -> int:
	return Level.DIAMOND

func get_max_hp() -> int:
	match level:
		Level.DIAMOND: return 40
		_:             return 30

# ─── Dice (Master always uses Blue dice; count grows at Diamond) ─────────────────
func get_melee_dice() -> Array:
	if level >= Level.DIAMOND:
		return [DiceColor.BLUE, DiceColor.BLUE]
	return [DiceColor.BLUE]

func get_ranged_dice() -> Array:
	if level >= Level.DIAMOND:
		return [DiceColor.BLUE, DiceColor.BLUE]
	return [DiceColor.BLUE]

func has_ranged_attack() -> bool:
	return true

# ─── Experience ──────────────────────────────────────────────────────────────────
func gain_exp(amount: int) -> void:
	experience += amount
	if experience >= get_exp_required():
		experience = 0
		hp  = max_hp   # full heal
		if level < Level.DIAMOND:
			_level_up()
		else:
			# Diamond max: heal only, flash diamond color
			AudioManager.play_level_up()
			VFXManager.flash_unit(self, Color(0.20, 0.85, 1.00))

# ─── Movement ────────────────────────────────────────────────────────────────────
func reset_moves() -> void:
	moved            = false
	has_attacked     = false
	free_summon_used = false

# ─── Debug ───────────────────────────────────────────────────────────────────────
func stats_string() -> String:
	return "[Master] %s (P%d) | %s | HP:%d/%d | MOV:%d(%s) | EXP:%d/%d" % [
		unit_name, owner_id, _level_name(), hp, max_hp,
		move_range, "OK" if not moved else "X",
		experience, get_exp_required()
	]
