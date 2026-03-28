extends RefCounted

class_name CombatBalanceDebug

const TERRAIN_NAMES := {
	0: "Pasto",
	1: "Agua",
	2: "Montana",
	3: "Bosque",
	4: "Desierto",
	5: "Volcan",
	6: "Cordillera",
}


func print_balance_report() -> void:
	print("[Balance] ===== Reporte de dano esperado por combate =====")
	_print_unit_family(Unit.MASTER_UNIT_TYPE, "Master", true)
	_print_unit_family(Unit.UnitType.WARRIOR, "Warrior")
	_print_unit_family(Unit.UnitType.ARCHER, "Archer")
	_print_unit_family(Unit.UnitType.LANCER, "Lancer")
	_print_unit_family(Unit.UnitType.RIDER, "Rider")


func _print_unit_family(unit_type: int, label: String, is_master: bool = false) -> void:
	var levels: Array[int] = [Unit.Level.BRONZE, Unit.Level.SILVER, Unit.Level.GOLD]
	if is_master:
		levels = [Unit.Level.GOLD, Unit.Level.DIAMOND]

	for level: int in levels:
		var unit = _build_sample_unit(unit_type, level, is_master)
		if unit == null:
			continue

		print("[Balance] %s %s | HP:%d | dano/golpe melee %.2f | dano/golpe ranged %.2f" % [
			label,
			_level_name(level),
			unit.max_hp,
			_expected_hit_damage(unit, false),
			_expected_hit_damage(unit, true),
		])

		for terrain_type: int in TERRAIN_NAMES.keys():
			var attacks: int = unit.get_attack_count_for_terrain(terrain_type)
			var melee_damage: float = _expected_combat_damage(unit, terrain_type, false)
			var ranged_damage: float = _expected_combat_damage(unit, terrain_type, true)
			print("  %s | golpes:%d | melee:%.2f | ranged:%.2f" % [
				TERRAIN_NAMES[terrain_type],
				attacks,
				melee_damage,
				ranged_damage,
			])


func _build_sample_unit(unit_type: int, level: int, is_master: bool) -> Unit:
	if is_master:
		var master := Master.new()
		master.init_master(1)
		master.level = level
		master.max_hp = master.get_max_hp()
		master.hp = master.max_hp
		return master

	var unit := Unit.new()
	unit.setup("Debug", unit_type, 1, level)
	unit.level = level
	unit.max_hp = unit.get_max_hp()
	unit.hp = unit.max_hp
	unit.attack_range = unit.get_default_attack_range()
	return unit


func _expected_combat_damage(unit: Unit, terrain_type: int, is_ranged: bool) -> float:
	if is_ranged and not unit.has_ranged_attack():
		return 0.0
	return _expected_hit_damage(unit, is_ranged) * float(unit.get_attack_count_for_terrain(terrain_type))


func _expected_hit_damage(unit: Unit, is_ranged: bool) -> float:
	var dice: Array = unit.get_ranged_dice() if is_ranged else unit.get_melee_dice()
	if dice.is_empty():
		return 0.0

	var total_average: float = 0.0
	for die_color: int in dice:
		var faces: Array = Unit.DICE.get(die_color, [0])
		if faces.is_empty():
			continue
		var subtotal: float = 0.0
		for face_value: int in faces:
			subtotal += float(face_value)
		total_average += subtotal / float(faces.size())

	return total_average * unit.get_damage_scale_per_hit()


func _level_name(level: int) -> String:
	match level:
		Unit.Level.BRONZE:
			return "Bronce"
		Unit.Level.SILVER:
			return "Plata"
		Unit.Level.GOLD:
			return "Oro"
		Unit.Level.DIAMOND:
			return "Diamante"
		_:
			return str(level)
