extends Node

const UnitScript := preload("res://scripts/Unit.gd")

# ─── Summon costs ──────────────────────────────────────────────────────────────
const SUMMON_COSTS: Dictionary = {
	UnitScript.UnitType.WARRIOR: 10,
	UnitScript.UnitType.ARCHER:  13,
	UnitScript.UnitType.LANCER:  12,
	UnitScript.UnitType.RIDER:   12,
}

const TYPE_NAMES: Dictionary = {
	UnitScript.UnitType.WARRIOR: "Warrior",
	UnitScript.UnitType.ARCHER:  "Archer",
	UnitScript.UnitType.LANCER:  "Lancer",
	UnitScript.UnitType.RIDER:   "Rider",
}

# ─── References (set by Main.gd) ───────────────────────────────────────────────
var hex_grid         = null
var resource_manager = null

# ─── Public API ────────────────────────────────────────────────────────────────
## Prints the summon menu to the console for the given player.
func show_menu(player_id: int) -> void:
	var essence: int = resource_manager.get_essence(player_id) if resource_manager != null else 0
	print("")
	print("[SummonMenu] ══════════════════════════════════")
	print("[SummonMenu]  Player %d — Available Summons" % player_id)
	print("[SummonMenu]  Esencia: %d" % essence)
	print("[SummonMenu] ──────────────────────────────────")
	for unit_type: int in SUMMON_COSTS.keys():
		var cost: int    = SUMMON_COSTS[unit_type]
		var uname: String = TYPE_NAMES[unit_type]
		var can: bool    = resource_manager != null and resource_manager.can_afford(player_id, cost)
		var mark: String = "✓" if can else "✗"
		print("[SummonMenu]  [%s] %-8s  %d esencia" % [mark, uname, cost])
	print("[SummonMenu] ──────────────────────────────────")
	print("[SummonMenu]  (call summon_manager.summon(type, col, row, player))")
	print("[SummonMenu] ══════════════════════════════════")
	print("")

## Summons a unit for free (Master active ability) — no gold cost, no affordability check.
## Returns true on success.
func summon_free(unit_type: int, col: int, row: int, player_id: int) -> bool:
	if hex_grid == null:
		push_error("[SummonManager] Missing hex_grid reference.")
		return false
	if not SUMMON_COSTS.has(unit_type):
		push_error("[SummonManager] Unknown unit_type: %d" % unit_type)
		return false
	if hex_grid.get_unit_at(col, row) != null:
		print("[SummonManager] Cell (%d,%d) is occupied — Master free summon failed." % [col, row])
		return false

	var unit := UnitScript.new()
	unit.setup(TYPE_NAMES[unit_type], unit_type, player_id, 1)
	unit.exhaust()
	hex_grid.place_unit(unit, col, row, true)
	hex_grid.queue_redraw()
	AudioManager.play_summon()
	print("[SummonManager] Master free summon: Player %d summoned %s at (%d,%d)" % [
		player_id, unit.unit_name, col, row
	])
	return true

## Attempts to summon a unit of unit_type at (col, row) for player_id.
## Returns true on success.
func summon(unit_type: int, col: int, row: int, player_id: int) -> bool:
	if resource_manager == null or hex_grid == null:
		push_error("[SummonManager] Missing references — cannot summon.")
		return false

	if not SUMMON_COSTS.has(unit_type):
		push_error("[SummonManager] Unknown unit_type: %d" % unit_type)
		return false

	var cost: int = SUMMON_COSTS[unit_type]

	if not resource_manager.can_afford(player_id, cost):
		print("[SummonManager] Player %d cannot afford %s (need %d, have %d)" % [
			player_id, TYPE_NAMES[unit_type], cost, resource_manager.get_essence(player_id)
		])
		return false

	if hex_grid.get_unit_at(col, row) != null:
		print("[SummonManager] Cell (%d,%d) is occupied." % [col, row])
		return false

	resource_manager.spend(player_id, cost)

	var unit := UnitScript.new()
	unit.setup(TYPE_NAMES[unit_type], unit_type, player_id, 1)
	unit.exhaust()
	hex_grid.place_unit(unit, col, row, true)
	hex_grid.queue_redraw()
	AudioManager.play_summon()

	print("[SummonManager] Player %d summoned %s at (%d,%d) — spent %d esencia, remaining: %d" % [
		player_id, unit.unit_name, col, row, cost, resource_manager.get_essence(player_id)
	])
	return true
