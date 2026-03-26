extends Node2D

class_name Unit

# ─── Enums ──────────────────────────────────────────────────────────────────────
enum UnitType  { WARRIOR, ARCHER, LANCER, RIDER }
enum Level     { BRONZE = 1, SILVER = 2, GOLD = 3, DIAMOND = 4 }
enum DiceColor { RED, YELLOW, GREEN, BLUE }

# ─── Type names ─────────────────────────────────────────────────────────────────
const TYPE_NAMES := {
	UnitType.WARRIOR: "Warrior",
	UnitType.ARCHER:  "Archer",
	UnitType.LANCER:  "Lancer",
	UnitType.RIDER:   "Rider",
}

# ─── Counter wheel: WARRIOR → LANCER → RIDER → ARCHER → WARRIOR ─────────────────
const COUNTER_CHART: Array = [
	[UnitType.WARRIOR, UnitType.LANCER],
	[UnitType.LANCER,  UnitType.RIDER],
	[UnitType.RIDER,   UnitType.ARCHER],
	[UnitType.ARCHER,  UnitType.WARRIOR],
]

# ─── Dice faces per color ────────────────────────────────────────────────────────
const DICE := {
	DiceColor.RED:    [0, 0, 1, 1, 2, 3],
	DiceColor.YELLOW: [0, 0, 1, 2, 3, 3],
	DiceColor.GREEN:  [0, 0, 2, 3, 3, 4],
	DiceColor.BLUE:   [1, 2, 3, 4, 4, 5],
}

# ─── Dice per unit type indexed by level-1 (0=BRONZE, 1=SILVER, 2=GOLD) ─────────
# null means no die at that level
const UNIT_MELEE_DICE := {
	UnitType.WARRIOR: [DiceColor.YELLOW, DiceColor.GREEN, DiceColor.BLUE],
	UnitType.ARCHER:  [DiceColor.RED,    DiceColor.YELLOW, DiceColor.YELLOW],
	UnitType.LANCER:  [DiceColor.RED,    DiceColor.YELLOW, DiceColor.BLUE],
	UnitType.RIDER:   [DiceColor.YELLOW, DiceColor.GREEN,  DiceColor.BLUE],
}

const UNIT_RANGED_DICE := {
	UnitType.WARRIOR: [null,             null,             DiceColor.RED],
	UnitType.ARCHER:  [DiceColor.YELLOW, DiceColor.GREEN,  DiceColor.BLUE],
	UnitType.LANCER:  [DiceColor.RED,    DiceColor.YELLOW, DiceColor.GREEN],
	UnitType.RIDER:   [null,             DiceColor.RED,    DiceColor.RED],
}

# ─── Base stats per type ─────────────────────────────────────────────────────────
const BASE_HP := {
	UnitType.WARRIOR: 6,
	UnitType.ARCHER:  4,
	UnitType.LANCER:  5,
	UnitType.RIDER:   5,
}

const BASE_MOVE := {
	UnitType.WARRIOR: 3,
	UnitType.ARCHER:  3,
	UnitType.LANCER:  3,
	UnitType.RIDER:   5,
}

# ─── Properties ─────────────────────────────────────────────────────────────────
var unit_name:    String = ""
var unit_type:    int    = UnitType.WARRIOR
var owner_id:     int    = 1
var level:        int    = Level.BRONZE
var experience:   int    = 0

var hp:           int    = 0
var max_hp:       int    = 0
var move_range:   int    = 0
var attack_range: int    = 1
var current_hex_cell: Vector2i = Vector2i(-1, -1)

# Turn state
var moved:       bool = false
var has_attacked: bool = false

# ─── Visual animation state ──────────────────────────────────────────────────────
var visual_pos:         Vector2 = Vector2.ZERO
var visual_scale:       float   = 1.0
var visual_alpha:       float   = 1.0
var visual_flash:       float   = 0.0
var visual_flash_color: Color   = Color(0.95, 0.80, 0.20)

# ─── Constructor ─────────────────────────────────────────────────────────────────
func setup(p_name: String, p_type: int, p_owner: int, _p_level: int = 1) -> void:
	unit_name = p_name
	unit_type = p_type
	owner_id  = p_owner
	level     = Level.BRONZE
	_apply_stats()

func get_max_hp() -> int:
	match unit_type:
		UnitType.WARRIOR:
			match level:
				Level.BRONZE: return 8
				Level.SILVER: return 16
				Level.GOLD:   return 26
		UnitType.ARCHER:
			match level:
				Level.BRONZE: return 5
				Level.SILVER: return 12
				Level.GOLD:   return 20
		UnitType.LANCER:
			match level:
				Level.BRONZE: return 10
				Level.SILVER: return 20
				Level.GOLD:   return 35
		UnitType.RIDER:
			match level:
				Level.BRONZE: return 10
				Level.SILVER: return 18
				Level.GOLD:   return 32
	return 5

func _apply_stats() -> void:
	max_hp       = get_max_hp()
	move_range   = BASE_MOVE.get(unit_type, 3)
	hp           = max_hp
	attack_range = 2 if has_ranged_attack() else 1

# ─── Combat ──────────────────────────────────────────────────────────────────────
func take_damage(amount: int) -> bool:
	hp = maxi(0, hp - amount)
	return hp == 0


func set_hex_cell(cell: Vector2i) -> void:
	current_hex_cell = cell


func clear_hex_cell() -> void:
	current_hex_cell = Vector2i(-1, -1)


func get_hex_cell() -> Vector2i:
	return current_hex_cell

# ─── Experience & levelling ──────────────────────────────────────────────────────
func get_exp_required() -> int:
	match level:
		Level.BRONZE: return 10
		Level.SILVER: return 15
		_:            return 20

func get_max_level() -> int:
	return Level.GOLD

func gain_exp(amount: int) -> void:
	experience += amount
	if experience >= get_exp_required():
		experience = 0
		hp  = max_hp   # full heal
		if level < get_max_level():
			_level_up()
		else:
			# Max level: just heal, no further promotion
			AudioManager.play_level_up()
			VFXManager.flash_unit(self, Color(0.95, 0.82, 0.20))

func _level_up() -> void:
	level       += 1
	max_hp       = get_max_hp()
	hp           = max_hp
	attack_range = 2 if has_ranged_attack() else 1
	print("[Unit] %s subió a %s! HP:%d/%d MOV:%d" % [
		unit_name, _level_name(), hp, max_hp, move_range
	])
	AudioManager.play_level_up()
	VFXManager.particles_level_up(visual_pos)
	VFXManager.flash_unit(self, Color(0.95, 0.82, 0.20))

func _level_name() -> String:
	match level:
		Level.BRONZE:  return "BRONCE"
		Level.SILVER:  return "PLATA"
		Level.GOLD:    return "ORO"
		Level.DIAMOND: return "DIAMANTE"
		_:             return str(level)

# ─── Movement ────────────────────────────────────────────────────────────────────
func get_moves_left() -> int:
	return move_range if not moved else 0

func use_move(_cost: int = 1) -> void:
	moved = true

func exhaust() -> void:
	moved = true

func reset_moves() -> void:
	moved        = false
	has_attacked = false

# ─── Dice ────────────────────────────────────────────────────────────────────────
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
	return not get_ranged_dice().is_empty()

func roll_dice(color: int) -> int:
	var faces: Array = DICE.get(color, [0])
	return faces[randi() % faces.size()]

# ─── Counter system ──────────────────────────────────────────────────────────────
static func get_damage_multiplier(attacker_type: int, defender_type: int) -> float:
	for pair: Array in COUNTER_CHART:
		if pair[0] == attacker_type and pair[1] == defender_type:
			return 1.75
		if pair[0] == defender_type and pair[1] == attacker_type:
			return 0.60
	return 1.0

# ─── Debug ───────────────────────────────────────────────────────────────────────
func stats_string() -> String:
	return "[%s] %s (P%d) | %s | HP:%d/%d | MOV:%d(%s) | EXP:%d/%d" % [
		TYPE_NAMES.get(unit_type, "?"), unit_name, owner_id,
		_level_name(), hp, max_hp,
		move_range, "OK" if not moved else "X",
		experience, get_exp_required()
	]
