extends RefCounted

const COMBAT_FEEL_BY_TYPE := {
	Unit.MASTER_UNIT_TYPE: {
		"anticipation": 0.13,
		"recovery": 0.34,
		"intensity": 1.18,
		"label_color": Color(1.00, 0.92, 0.62),
	},
	Unit.UnitType.WARRIOR: {
		"anticipation": 0.11,
		"recovery": 0.24,
		"intensity": 1.00,
		"label_color": Color(1.00, 0.86, 0.40),
	},
	Unit.UnitType.ARCHER: {
		"anticipation": 0.08,
		"recovery": 0.20,
		"intensity": 0.86,
		"label_color": Color(0.76, 0.96, 1.00),
	},
	Unit.UnitType.LANCER: {
		"anticipation": 0.07,
		"recovery": 0.17,
		"intensity": 0.82,
		"label_color": Color(0.92, 1.00, 0.72),
	},
	Unit.UnitType.RIDER: {
		"anticipation": 0.09,
		"recovery": 0.18,
		"intensity": 0.94,
		"label_color": Color(1.00, 0.84, 0.64),
	},
}
const CRITICAL_CHANCE := 0.12
const SUPER_CRITICAL_BASE_CHANCE := 0.01
const FACTION_CRIT_BONUS := 0.15
const PRE_COMBAT_DRAMATIC_PAUSE := 0.24
const PRE_COMBAT_RESULTS_HOLD := 0.34
const PRE_COMBAT_SIDE_DELAY := 0.18
const SUPER_CRIT_CHARGE_EXTRA := 0.40
const SUPER_CRIT_CHARGE_HOLD := 0.26
const EXP_COMBAT_PARTICIPATION := 1
const EXP_COMBAT_DAMAGE := 2
const EXP_COMBAT_KILL := 4

# ─── Public API ─────────────────────────────────────────────────────────────────
## Resolves a combat between attacker and defender using the dice system.
## is_ranged: ranged attacks may still allow a counter-attack if the defender
## also has a valid ranged response (for example, Archer or Master at distance 2).
##
## visual_context keys (all optional):
##   "camera"            : CameraController3D
##   "attacker_pos"      : Vector3
##   "defender_pos"      : Vector3
##   "attacker_renderer" : UnitRenderer3D
##   "defender_renderer" : UnitRenderer3D
##   "all_renderers"     : Array of all UnitRenderer3D nodes
##   "host"              : Node
##   "attacker_terrain"  : int
##   "defender_terrain"  : int
##
## Returns {
##   attacker_log, defender_log,
##   defender_died, attacker_died,
##   type_mult, is_ranged,
##   attacker_hit_count, defender_hit_count
## }
func resolve_combat(attacker: Unit, defender: Unit,
		is_ranged: bool = false,
		visual_context: Dictionary = {}) -> Dictionary:

	if attacker.has_attacked:
		return {
			"attacker_log": [],
			"defender_log": [],
			"defender_died": false,
			"attacker_died": false,
			"type_mult": 1.0,
			"is_ranged": is_ranged,
			"attacker_hit_count": 0,
			"defender_hit_count": 0,
		}

	var camera = visual_context.get("camera", null)
	var atk_rend = visual_context.get("attacker_renderer", null)
	var def_rend = visual_context.get("defender_renderer", null)
	var all_renderers: Array = visual_context.get("all_renderers", [])
	var host: Node = visual_context.get("host", null)
	var atk_pos: Vector3 = visual_context.get("attacker_pos", Vector3.ZERO)
	var def_pos: Vector3 = visual_context.get("defender_pos", Vector3.ZERO)
	var atk_cell: Vector2i = visual_context.get("attacker_cell", Vector2i(-1, -1))
	var def_cell: Vector2i = visual_context.get("defender_cell", Vector2i(-1, -1))
	var attacker_terrain: int = int(visual_context.get("attacker_terrain", 0))
	var defender_terrain: int = int(visual_context.get("defender_terrain", 0))
	var combat_distance: int = int(visual_context.get("combat_distance", 1))
	var atk_hp_bar: Control = null
	var def_hp_bar: Control = null
	var type_mult: float = Unit.get_damage_multiplier(attacker.unit_type, defender.unit_type)
	var defender_mult: float = Unit.get_damage_multiplier(defender.unit_type, attacker.unit_type)
	var is_night: bool = bool(visual_context.get("is_night", false))
	var atk_crit_bonus: float = _get_faction_crit_bonus(attacker, is_night)
	var def_crit_bonus: float = _get_faction_crit_bonus(defender, is_night)
	if atk_crit_bonus > 0.0:
		var _bf: int = GameData.get_faction_for_player(attacker.owner_id)
		var _bn: String = FactionData.get_faction_name(_bf)
		print("[BONUS %s] %s +15%% crítico" % ["NOCTURNO" if is_night else "DIURNO", _bn])

	if def_crit_bonus > 0.0:
		var _df: int = GameData.get_faction_for_player(defender.owner_id)
		var _dn: String = FactionData.get_faction_name(_df)
		print("[BONUS %s] %s +15%% critico (defensor)" % ["NOCTURNO" if is_night else "DIURNO", _dn])
	if camera != null:
		if atk_rend != null:
			atk_rend.set_combat_facing(def_pos)
		if def_rend != null:
			def_rend.set_combat_facing(atk_pos)

		var enter_tw: Tween = camera.enter_combat_mode(atk_pos, def_pos)
		if atk_rend != null:
			atk_rend.set_combat_focus(true)
		if def_rend != null:
			def_rend.set_combat_focus(true)
		for r: Variant in all_renderers:
			if r != atk_rend and r != def_rend:
				r.set_combat_dim(true)
			r.dim_selection_ring()
			r.set_selection_ring_visible(false)

		await enter_tw.finished
		if host != null and host.has_method("set_combat_team_rings_visible"):
			host.call("set_combat_team_rings_visible", false)
		if host != null and host.has_method("set_combat_unit_badges_visible"):
			host.call("set_combat_unit_badges_visible", false)
		if host != null and host.has_method("show_combat_stage") and atk_cell != Vector2i(-1, -1) and def_cell != Vector2i(-1, -1):
			host.call("show_combat_stage", atk_cell, def_cell, camera.global_position)
		if host != null and host.has_method("set_combat_tower_obstruction_fade"):
			host.call("set_combat_tower_obstruction_fade", true, (atk_pos + def_pos) / 2.0, camera.global_position)
		if atk_rend != null:
			atk_rend.set_combat_mode()
			atk_rend.set_health_bar_values(attacker.hp, attacker.max_hp, false)
		if def_rend != null:
			def_rend.set_combat_mode()
			def_rend.set_health_bar_values(defender.hp, defender.max_hp, false)
		_apply_combat_sprite_facing(camera, atk_rend, def_rend)
		if atk_rend != null:
			atk_hp_bar = VFXManager.create_combat_health_bar(
				atk_rend.global_position,
				attacker.hp,
				attacker.max_hp,
				str(attacker.unit_name),
				int(attacker.level),
				int(attacker.unit_type),
				int(attacker.owner_id),
				int(attacker.experience),
				int(attacker.get_exp_required())
			)
		if def_rend != null:
			def_hp_bar = VFXManager.create_combat_health_bar(
				def_rend.global_position,
				defender.hp,
				defender.max_hp,
				str(defender.unit_name),
				int(defender.level),
				int(defender.unit_type),
				int(defender.owner_id),
				int(defender.experience),
				int(defender.get_exp_required())
			)
		VFXManager.set_combat_health_bar_matchup_badge(atk_hp_bar, 1 if type_mult > 1.0 else (-1 if type_mult < 1.0 else 0))
		VFXManager.set_combat_health_bar_matchup_badge(def_hp_bar, 1 if defender_mult > 1.0 else (-1 if defender_mult < 1.0 else 0))
		if atk_crit_bonus > 0.0 and atk_hp_bar != null:
			var _bf2: int = GameData.get_faction_for_player(attacker.owner_id)
			VFXManager.set_combat_health_bar_bonus_badge(atk_hp_bar, is_night, FactionData.get_faction_name(_bf2))
		if def_crit_bonus > 0.0 and def_hp_bar != null:
			var _df2: int = GameData.get_faction_for_player(defender.owner_id)
			VFXManager.set_combat_health_bar_bonus_badge(def_hp_bar, is_night, FactionData.get_faction_name(_df2))

	if host != null:
		await host.get_tree().create_timer(PRE_COMBAT_DRAMATIC_PAUSE).timeout

	MusicManager.play_combat_music()

	# For ranged attacks use the ranged-specific count (Lancer = 1 javelin, Archer = 2 arrows).
	var attacker_hit_count: int = attacker.get_ranged_attack_count_for_terrain(attacker_terrain) if is_ranged else attacker.get_attack_count_for_terrain(attacker_terrain)
	if atk_cell != Vector2i(-1, -1) and def_cell != Vector2i(-1, -1):
		combat_distance = _hex_distance(atk_cell, def_cell)
	var ranged_counter_allowed: bool = is_ranged and defender != null and defender.has_ranged_attack() and defender.can_attack_at_distance(combat_distance)
	var defender_hit_count: int = defender.get_ranged_attack_count_for_terrain(defender_terrain) if ranged_counter_allowed else defender.get_attack_count_for_terrain(defender_terrain)

	# ── Bonus modifiers ──────────────────────────────────────────────────────────
	var atk_roll_bonus:      int  = 0
	var atk_force_first_blue: bool = false
	var atk_fury_upgrade:    bool = false
	var atk_no_miss_first:   bool = false

	if not is_ranged:
		# Fury (Warrior): below 50% HP → upgrade melee die one level
		if attacker.bonus_fury and float(attacker.hp) < float(attacker.max_hp) * 0.5:
			atk_fury_upgrade = true
		# Charge (Lancer): moved before attacking → +1 roll result
		if attacker.bonus_charge and attacker.moves_this_turn > 0:
			atk_roll_bonus += 1
		# Brutal charge (Rider): moved 3+ hexes → first die becomes BLUE
		if attacker.bonus_brutal_charge and attacker.moves_this_turn >= 3:
			atk_force_first_blue = true

	# Flanking (Rider): lateral/rear attack → +1 roll result
	if attacker.bonus_flanking and _check_flanking(atk_cell, def_cell, defender):
		atk_roll_bonus += 1
	if attacker.bonus_executioner and defender.hp <= maxi(1, defender.max_hp / 2):
		atk_roll_bonus += 1
	if is_ranged and attacker.bonus_marksman:
		atk_roll_bonus += 1

	# Precision (Archer): first attack of the turn always hits
	if attacker.bonus_precision and not attacker.has_attacked:
		atk_no_miss_first = true

	var planned_combat: Dictionary = _plan_combat_sequence(
		attacker,
		defender,
		is_ranged,
		type_mult,
		defender_mult,
		attacker_hit_count,
		defender_hit_count,
		ranged_counter_allowed,
		atk_crit_bonus,
		def_crit_bonus,
		atk_roll_bonus,
		atk_force_first_blue,
		atk_fury_upgrade,
		atk_no_miss_first
	)
	var atk_log: Array = planned_combat.get("attacker_log", [])
	var def_log: Array = planned_combat.get("defender_log", [])
	var timeline: Array = planned_combat.get("timeline", [])

	await _play_pre_combat_dice_intro(atk_log, def_log, atk_hp_bar, def_hp_bar, host)

	for entry: Dictionary in timeline:
		var is_attacker_turn: bool = bool(entry.get("attacker_turn", true))
		var roll_result: Dictionary = entry.get("result", {})
		if is_attacker_turn:
			await _animate_dice_attack(roll_result, attacker, defender, atk_rend, def_rend, atk_hp_bar, def_hp_bar, host, attacker.unit_type)
			defender.take_damage(int(roll_result.get("damage", 0)))
			if def_rend != null:
				def_rend.set_health_bar_values(defender.hp, defender.max_hp)
				VFXManager.update_combat_health_bar(def_hp_bar, def_rend.global_position, defender.hp, defender.max_hp)
			if atk_rend != null:
				VFXManager.update_combat_health_bar(atk_hp_bar, atk_rend.global_position, attacker.hp, attacker.max_hp, false)
		else:
			await _animate_dice_attack(roll_result, defender, attacker, def_rend, atk_rend, def_hp_bar, atk_hp_bar, host, defender.unit_type)
			attacker.take_damage(int(roll_result.get("damage", 0)))
			if atk_rend != null:
				atk_rend.set_health_bar_values(attacker.hp, attacker.max_hp)
				VFXManager.update_combat_health_bar(atk_hp_bar, atk_rend.global_position, attacker.hp, attacker.max_hp)
			if def_rend != null:
				VFXManager.update_combat_health_bar(def_hp_bar, def_rend.global_position, defender.hp, defender.max_hp, false)

		if defender.hp <= 0 or attacker.hp <= 0:
			break

	var defender_died: bool = defender.hp == 0
	var attacker_died: bool = attacker.hp == 0

	MusicManager.stop_combat_music()

	attacker.has_attacked = true
	if attacker.extra_attacks > 0:
		attacker.extra_attacks -= 1
		attacker.has_attacked = false

	var atk_damage: int = 0
	for attack_entry: Dictionary in atk_log:
		atk_damage += int(attack_entry.get("damage", 0))
	var def_damage: int = 0
	for defense_entry: Dictionary in def_log:
		def_damage += int(defense_entry.get("damage", 0))
	if attacker.bonus_pinning and atk_damage > 0 and defender.hp > 0:
		defender.attack_debuff += 1
	if defender.bonus_pinning and def_damage > 0 and attacker.hp > 0:
		attacker.attack_debuff += 1
	var exp_awards: Dictionary = _award_exp(attacker, defender, atk_damage, def_damage, defender_died, attacker_died)
	_show_combat_exp_feedback(exp_awards, attacker, defender, atk_rend, def_rend, atk_hp_bar, def_hp_bar)

	_print_summary(attacker, defender, atk_log, def_log, type_mult, is_ranged, defender_died, attacker_died)

	if host != null:
		if defender_died and def_rend != null:
			VFXManager.update_combat_health_bar(def_hp_bar, def_rend.global_position, defender.hp, defender.max_hp)
			AudioManager.play_death()
			await def_rend.anim_death(
				atk_rend.position if atk_rend != null else atk_pos, host
			).finished

		if attacker_died and atk_rend != null:
			VFXManager.update_combat_health_bar(atk_hp_bar, atk_rend.global_position, attacker.hp, attacker.max_hp)
			AudioManager.play_death()
			await atk_rend.anim_death(
				def_rend.position if def_rend != null else def_pos, host
			).finished

	await _cleanup_visual_state(
		camera,
		host,
		all_renderers,
		atk_rend,
		def_rend,
		atk_pos,
		def_pos,
		atk_hp_bar,
		def_hp_bar,
		attacker_died,
		defender_died
	)

	# Process level-up bonus selections BEFORE returning so the caller (HexGrid3D)
	# stays paused until the player has chosen — no AI move can slip through.
	if BonusSystem.has_pending_bonuses():
		await BonusSystem.process_pending()

	return {
		"attacker_log": atk_log,
		"defender_log": def_log,
		"defender_died": defender_died,
		"attacker_died": attacker_died,
		"type_mult": type_mult,
		"is_ranged": is_ranged,
		"attacker_hit_count": attacker_hit_count,
		"defender_hit_count": defender_hit_count,
	}

func _cleanup_visual_state(
		camera,
		host: Node,
		all_renderers: Array,
		atk_rend,
		def_rend,
		atk_pos: Vector3,
		def_pos: Vector3,
		atk_hp_bar: Control,
		def_hp_bar: Control,
		attacker_died: bool,
		defender_died: bool) -> void:
	if host != null and host.has_method("set_combat_tower_obstruction_fade"):
		host.call("set_combat_tower_obstruction_fade", false)
	if host != null and host.has_method("hide_combat_stage"):
		host.call("hide_combat_stage")
	if host != null and host.has_method("set_combat_team_rings_visible"):
		host.call("set_combat_team_rings_visible", true)
	if host != null and host.has_method("set_combat_unit_badges_visible"):
		host.call("set_combat_unit_badges_visible", true)
	if not attacker_died and atk_rend != null:
		atk_rend.snap_to_world_position(atk_pos)
		atk_rend.set_combat_focus(false)
		atk_rend.reset_combat_facing()
		atk_rend.set_tactical_mode()
	if not defender_died and def_rend != null:
		def_rend.snap_to_world_position(def_pos)
		def_rend.set_combat_focus(false)
		def_rend.reset_combat_facing()
		def_rend.set_tactical_mode()
	for r: Variant in all_renderers:
		if r == null:
			continue
		r.set_combat_dim(false)
		r.set_selection_ring_visible(true)
		r.restore_selection_ring()
	VFXManager.remove_combat_health_bar(atk_hp_bar)
	VFXManager.remove_combat_health_bar(def_hp_bar)
	if camera != null and camera.has_method("exit_combat_mode"):
		await camera.exit_combat_mode().finished
	elif camera != null and camera.has_method("force_reset_combat_state"):
		camera.force_reset_combat_state()


# ─── Internal ───────────────────────────────────────────────────────────────────
func _get_faction_crit_bonus(unit: Unit, is_night: bool) -> float:
	var faction: int = GameData.get_faction_for_player(unit.owner_id)
	if not is_night and faction in [FactionData.Faction.GAUCHOS, FactionData.Faction.MILITARES]:
		return FACTION_CRIT_BONUS
	if is_night and faction in [FactionData.Faction.INDIOS, FactionData.Faction.BRUJOS]:
		return FACTION_CRIT_BONUS
	return 0.0


func _get_super_critical_chance(unit: Unit) -> float:
	if unit == null:
		return SUPER_CRITICAL_BASE_CHANCE
	return SUPER_CRITICAL_BASE_CHANCE * float(maxi(1, int(unit.level)))


func _plan_combat_sequence(attacker: Unit, defender: Unit, is_ranged: bool, type_mult: float,
		defender_mult: float, attacker_hit_count: int, defender_hit_count: int, ranged_counter_allowed: bool,
		atk_crit_bonus: float, def_crit_bonus: float,
		atk_roll_bonus: int = 0, atk_force_first_blue: bool = false,
		atk_fury_upgrade: bool = false, atk_no_miss_first: bool = false) -> Dictionary:
	var atk_log: Array = []
	var def_log: Array = []
	var timeline: Array = []
	var simulated_attacker_hp: int = attacker.hp
	var simulated_defender_hp: int = defender.hp
	var attacker_roll_offset: int = 0
	var defender_roll_offset: int = 0
	var atk_dice: Array = attacker.get_ranged_dice() if is_ranged else attacker.get_melee_dice()
	var def_dice: Array = defender.get_ranged_dice() if is_ranged else defender.get_melee_dice()

	if is_ranged:
		if ranged_counter_allowed:
			var ranged_round_count: int = maxi(attacker_hit_count, defender_hit_count)
			for hit_index: int in range(ranged_round_count):
				if simulated_defender_hp > 0 and hit_index < attacker_hit_count:
					var is_first: bool = (hit_index == 0)
					var atk_result: Dictionary = _roll_attack(
						attacker,
						atk_dice,
						type_mult,
						attacker.get_bonus_damage_multiplier(),
						atk_crit_bonus,
						0,  # ranged attacks don't benefit from melee bonuses
						false, false,
						atk_no_miss_first and is_first
					)
					atk_result["hit_index"] = hit_index + 1
					atk_result["hit_count"] = attacker_hit_count
					atk_result["roll_offset"] = attacker_roll_offset
					atk_log.append(atk_result)
					timeline.append({"attacker_turn": true, "result": atk_result})
					attacker_roll_offset += int(atk_result.get("rolls", []).size())
					simulated_defender_hp = maxi(0, simulated_defender_hp - int(atk_result.get("damage", 0)))
				if simulated_defender_hp <= 0:
					break
				if simulated_attacker_hp > 0 and hit_index < defender_hit_count:
					var def_result: Dictionary = _roll_attack(
						defender,
						def_dice,
						defender_mult,
						defender.get_bonus_damage_multiplier(),
						def_crit_bonus
					)
					def_result["hit_index"] = hit_index + 1
					def_result["hit_count"] = defender_hit_count
					def_result["roll_offset"] = defender_roll_offset
					def_log.append(def_result)
					timeline.append({"attacker_turn": false, "result": def_result})
					defender_roll_offset += int(def_result.get("rolls", []).size())
					simulated_attacker_hp = maxi(0, simulated_attacker_hp - int(def_result.get("damage", 0)))
				if simulated_attacker_hp <= 0:
					break
		else:
			for hit_index: int in range(attacker_hit_count):
				if simulated_defender_hp <= 0:
					break
				var is_first: bool = (hit_index == 0)
				var atk_result: Dictionary = _roll_attack(
					attacker,
					atk_dice,
					type_mult,
					attacker.get_bonus_damage_multiplier(),
					atk_crit_bonus,
					0,  # ranged attacks don't benefit from melee bonuses
					false, false,
					atk_no_miss_first and is_first
				)
				atk_result["hit_index"] = hit_index + 1
				atk_result["hit_count"] = attacker_hit_count
				atk_result["roll_offset"] = attacker_roll_offset
				atk_log.append(atk_result)
				timeline.append({"attacker_turn": true, "result": atk_result})
				attacker_roll_offset += int(atk_result.get("rolls", []).size())
				simulated_defender_hp = maxi(0, simulated_defender_hp - int(atk_result.get("damage", 0)))
	else:
		var round_count: int = maxi(attacker_hit_count, defender_hit_count)
		for hit_index: int in range(round_count):
			if simulated_defender_hp > 0 and hit_index < attacker_hit_count:
				var is_first: bool = (hit_index == 0)
				var atk_result: Dictionary = _roll_attack(
					attacker,
					atk_dice,
					type_mult,
					attacker.get_bonus_damage_multiplier(),
					atk_crit_bonus,
					atk_roll_bonus,
					atk_force_first_blue and is_first,
					atk_fury_upgrade,
					atk_no_miss_first and is_first
				)
				atk_result["hit_index"] = hit_index + 1
				atk_result["hit_count"] = attacker_hit_count
				atk_result["roll_offset"] = attacker_roll_offset
				atk_log.append(atk_result)
				timeline.append({"attacker_turn": true, "result": atk_result})
				attacker_roll_offset += int(atk_result.get("rolls", []).size())
				simulated_defender_hp = maxi(0, simulated_defender_hp - int(atk_result.get("damage", 0)))
			if simulated_defender_hp <= 0:
				break
			if simulated_attacker_hp > 0 and hit_index < defender_hit_count:
				var def_result: Dictionary = _roll_attack(
					defender,
					def_dice,
					defender_mult,
					defender.get_bonus_damage_multiplier(),
					def_crit_bonus
				)
				def_result["hit_index"] = hit_index + 1
				def_result["hit_count"] = defender_hit_count
				def_result["roll_offset"] = defender_roll_offset
				def_log.append(def_result)
				timeline.append({"attacker_turn": false, "result": def_result})
				defender_roll_offset += int(def_result.get("rolls", []).size())
				simulated_attacker_hp = maxi(0, simulated_attacker_hp - int(def_result.get("damage", 0)))
			if simulated_attacker_hp <= 0:
				break

	return {
		"attacker_log": atk_log,
		"defender_log": def_log,
		"timeline": timeline,
	}


func _play_pre_combat_dice_intro(atk_log: Array, def_log: Array, atk_hp_bar: Control, def_hp_bar: Control, host: Node) -> void:
	if host == null:
		return

	var tree := host.get_tree()
	VFXManager.clear_combat_health_bar_rolls(atk_hp_bar)
	VFXManager.clear_combat_health_bar_rolls(def_hp_bar)

	var attacker_rolls: Array = _flatten_rolls(atk_log)
	var defender_rolls: Array = _flatten_rolls(def_log)
	if not attacker_rolls.is_empty():
		await VFXManager.show_combat_health_bar_roll_batch(atk_hp_bar, attacker_rolls)
		await tree.create_timer(PRE_COMBAT_SIDE_DELAY).timeout
	if not defender_rolls.is_empty():
		await VFXManager.show_combat_health_bar_roll_batch(def_hp_bar, defender_rolls)
		await tree.create_timer(PRE_COMBAT_SIDE_DELAY).timeout

	VFXManager.dim_combat_health_bar_rolls(atk_hp_bar)
	VFXManager.dim_combat_health_bar_rolls(def_hp_bar)
	await tree.create_timer(PRE_COMBAT_RESULTS_HOLD).timeout


func _flatten_rolls(log_entries: Array) -> Array:
	var flat_rolls: Array = []
	for entry: Dictionary in log_entries:
		for roll: Dictionary in entry.get("rolls", []):
			flat_rolls.append(roll)
	return flat_rolls

func _apply_combat_sprite_facing(camera, atk_rend, def_rend) -> void:
	if camera == null or atk_rend == null or def_rend == null:
		return
	var attacker_sample: Vector3 = atk_rend.global_position + Vector3(0.0, 1.2, 0.0)
	var defender_sample: Vector3 = def_rend.global_position + Vector3(0.0, 1.2, 0.0)
	if camera.is_position_behind(attacker_sample) or camera.is_position_behind(defender_sample):
		return
	var attacker_screen: Vector2 = camera.unproject_position(attacker_sample)
	var defender_screen: Vector2 = camera.unproject_position(defender_sample)
	atk_rend.set_sprite_mirror(attacker_screen.x > defender_screen.x)
	def_rend.set_sprite_mirror(defender_screen.x > attacker_screen.x)


func _roll_attack(unit: Unit, dice: Array, type_mult: float, damage_scale: float = 1.0,
		crit_bonus: float = 0.0, roll_bonus: int = 0,
		force_blue: bool = false, fury_upgrade: bool = false,
		no_miss: bool = false) -> Dictionary:
	# Apply die modifications
	var effective_dice: Array = dice.duplicate()
	if fury_upgrade and not effective_dice.is_empty():
		effective_dice[0] = mini(int(effective_dice[0]) + 1, Unit.DiceColor.DIAMOND)
	if force_blue and not effective_dice.is_empty():
		effective_dice[0] = Unit.DiceColor.PLATINUM

	var rolls: Array = []
	var total: int = 0
	var has_critical: bool = false
	var has_super_critical: bool = false
	var max_total: int = 0
	var super_critical_chance: float = _get_super_critical_chance(unit)
	for die_color: int in effective_dice:
		var val: int = unit.roll_dice(die_color)
		var faces: Array = Unit.DICE.get(die_color, [0])
		var die_max: int = 0
		for face_value: Variant in faces:
			die_max = maxi(die_max, int(face_value))
		var die_is_super_critical: bool = val > 0 and randf() < super_critical_chance
		if die_is_super_critical:
			val = die_max
		var die_is_critical: bool = die_is_super_critical or (val > 0 and randf() < (CRITICAL_CHANCE + crit_bonus))
		if die_is_super_critical and val <= 0:
			val = maxi(1, die_max)
		rolls.append({"color": die_color, "value": val, "critical": die_is_critical, "super_critical": die_is_super_critical})
		total += val
		max_total += die_max
		if die_is_super_critical:
			has_super_critical = true
		if die_is_critical:
			has_critical = true

	# Precision: first attack can't miss
	if no_miss and total == 0:
		total = 1

	# Roll bonus (charge, flanking)
	total     = maxi(0, total + roll_bonus)
	max_total = maxi(0, max_total + roll_bonus)

	var advantage_bonus: int = 1 if type_mult > 1.0 and total > 0 else 0
	if advantage_bonus > 0:
		var marked_index: int = -1
		for i: int in range(rolls.size()):
			if int((rolls[i] as Dictionary).get("value", 0)) > 0:
				marked_index = i
				break
		if marked_index == -1 and not rolls.is_empty():
			marked_index = 0
		if marked_index != -1:
			var advantage_roll: Dictionary = rolls[marked_index]
			advantage_roll["advantage_bonus"] = advantage_bonus
			advantage_roll["display_value"] = int(advantage_roll.get("value", 0)) + advantage_bonus
			rolls[marked_index] = advantage_roll
	var scaled_total: float = float(total + advantage_bonus) * damage_scale
	var damage: int = maxi(0, int(round(scaled_total)))
	var critical_damage_multiplier: float = unit.get_bonus_critical_damage_multiplier()
	if has_super_critical and damage > 0:
		damage = maxi(0, int(round(float(damage) * 2.7 * critical_damage_multiplier)))
	elif has_critical and damage > 0:
		damage = maxi(0, int(round(float(damage) * 2.0 * critical_damage_multiplier)))
	if damage > 0:
		for i: int in range(rolls.size()):
			var die_roll: Dictionary = rolls[i]
			if bool(die_roll.get("critical", false)) or bool(die_roll.get("super_critical", false)):
				die_roll["display_value"] = damage
				rolls[i] = die_roll
	var max_critical: bool = has_critical and total >= max_total and max_total > 0
	var special_crit: String = ""
	if has_super_critical:
		special_crit = "super"
	elif max_critical:
		if unit is Master:
			special_crit = "master"
		elif int(unit.level) == 3:
			special_crit = "gold"
	return {
		"rolls": rolls,
		"total": total,
		"max_total": max_total,
		"damage": damage,
		"advantage_bonus": advantage_bonus,
		"critical": has_critical,
		"super_critical": has_super_critical,
		"max_critical": max_critical,
		"special_crit": special_crit,
	}

func _hex_distance(a: Vector2i, b: Vector2i) -> int:
	var dq: int = a.x - b.x
	var dr: int = a.y - b.y
	var ds: int = (-a.x - a.y) - (-b.x - b.y)
	return maxi(maxi(abs(dq), abs(dr)), abs(ds))


func _animate_dice_attack(roll_result: Dictionary, attacker_unit: Unit, defender_unit: Unit, src_rend, dst_rend, src_hp_bar: Control, dst_hp_bar: Control, host: Node, unit_type: int) -> void:
	if host == null:
		return

	var feel: Dictionary = _get_combat_feel(unit_type)
	var anticipation: float = float(feel.get("anticipation", 0.10))
	var recovery: float = float(feel.get("recovery", 0.22))
	var intensity: float = float(feel.get("intensity", 1.0))
	var label_color: Color = feel.get("label_color", Color(1.0, 0.96, 0.72))
	var is_super_critical: bool = bool(roll_result.get("super_critical", false))

	if src_rend != null and dst_rend != null:
		VFXManager.show_combat_hit_label(
			src_rend.position.lerp(dst_rend.position, 0.38),
			int(roll_result.get("hit_index", 1)),
			int(roll_result.get("hit_count", 1)),
			label_color
		)
		if is_super_critical and src_rend.has_method("anim_super_critical_charge"):
			AudioManager.play_super_critical_charge()
			if host != null and host.has_method("play_super_critical_camera_vignette"):
				host.call("play_super_critical_camera_vignette", anticipation + SUPER_CRIT_CHARGE_EXTRA + 0.14, 0.34)
			else:
				VFXManager.show_super_critical_vignette(anticipation + SUPER_CRIT_CHARGE_EXTRA + 0.14)
			var charge_camera = host.get_viewport().get_camera_3d()
			if charge_camera != null and charge_camera.has_method("shake_combat"):
				charge_camera.call("shake_combat", 0.08, anticipation + SUPER_CRIT_CHARGE_EXTRA + 0.18)
			await src_rend.anim_super_critical_charge(host, intensity * 1.22, anticipation + SUPER_CRIT_CHARGE_EXTRA).finished
			await host.get_tree().create_timer(SUPER_CRIT_CHARGE_HOLD).timeout
		else:
			await src_rend.anim_attack_anticipation(host, intensity, anticipation).finished
		await src_rend.anim_lunge(dst_rend.position, host).finished

	AudioManager.play_attack(unit_type)

	var rolls: Array = roll_result.get("rolls", [])
	VFXManager.dim_combat_health_bar_rolls(dst_hp_bar)
	VFXManager.highlight_combat_health_bar_rolls(
		src_hp_bar,
		int(roll_result.get("roll_offset", 0)),
		rolls.size()
	)

	var dmg: int = int(roll_result.get("damage", 0))
	var is_critical: bool = bool(roll_result.get("critical", false))
	var special_crit: String = str(roll_result.get("special_crit", ""))
	if dmg > 0 and dst_rend != null:
		if is_super_critical:
			AudioManager.play_super_critical()
			AudioManager.play_massive_impact()
			AudioManager.play_crowd_super_critical()
			var crit_camera = host.get_viewport().get_camera_3d()
			if crit_camera != null and crit_camera.has_method("shake_combat"):
				crit_camera.call("shake_combat", 0.34, 0.34)
			VFXManager.show_super_critical_burst_world(dst_rend.global_position)
			_trigger_special_critical_fx(special_crit, attacker_unit, defender_unit, src_rend, dst_rend, host)
		elif is_critical:
			AudioManager.play_critical()
			AudioManager.play_crowd_crit()
			var crit_camera = host.get_viewport().get_camera_3d()
			if crit_camera != null and crit_camera.has_method("shake_combat"):
				crit_camera.call("shake_combat", 0.08, 0.14)
			VFXManager.show_critical_burst_world(dst_rend.global_position)
			_trigger_special_critical_fx(special_crit, attacker_unit, defender_unit, src_rend, dst_rend, host)
		else:
			AudioManager.play_hurt()
		var dmg_type: String = "super_critical" if is_super_critical else ("critical" if is_critical else "damage")
		VFXManager.show_damage_label(host, dst_rend.position, dmg, dmg_type, true)
		if src_rend != null:
			if is_super_critical and dst_rend.has_method("anim_super_critical_hit"):
				await dst_rend.anim_super_critical_hit(src_rend.position, host).finished
			else:
				await dst_rend.anim_hit(src_rend.position, host).finished
	elif dmg == 0 and dst_rend != null:
		AudioManager.play_dodge()
		VFXManager.show_damage_label(host, dst_rend.position, 0, "miss", true)
		if src_rend != null:
			await dst_rend.anim_dodge(src_rend.position, host).finished

	await host.get_tree().create_timer(recovery).timeout

func _trigger_special_critical_fx(special_crit: String, attacker_unit: Unit, defender_unit: Unit, src_rend, dst_rend, host: Node) -> void:
	if special_crit == "" or dst_rend == null:
		return
	var camera = host.get_viewport().get_camera_3d()
	if special_crit == "super":
		if camera != null and camera.has_method("shake_combat"):
			camera.call("shake_combat", 0.30, 0.34)
		if host.has_method("pulse_board_units_for_super_crit") and attacker_unit != null and defender_unit != null:
			host.call("pulse_board_units_for_super_crit", attacker_unit.get_hex_cell(), defender_unit.get_hex_cell(), 0.28, 0.42)
	elif special_crit == "gold":
		AudioManager.play_heavy_impact()
		AudioManager.play_crowd_gold()
		AudioManager.play_sapucay_crit()
		if camera != null and camera.has_method("shake_combat"):
			camera.call("shake_combat", 0.16, 0.24)
	elif special_crit == "master":
		AudioManager.play_massive_impact()
		AudioManager.play_crowd_master()
		AudioManager.play_sapucay_crit()
		if camera != null and camera.has_method("shake_combat"):
			camera.call("shake_combat", 0.28, 0.34)
		VFXManager.show_pixel_burst_world(dst_rend.global_position, Color(0.58, 0.32, 0.18, 0.95), 24, 0.55, 72.0, 132.0, 220.0, 0.92, 1.62)
		if host.has_method("pulse_board_units_for_master_crit") and attacker_unit != null and defender_unit != null:
			host.call("pulse_board_units_for_master_crit", attacker_unit.get_hex_cell(), defender_unit.get_hex_cell(), 0.18, 0.30)


func _get_combat_feel(unit_type: int) -> Dictionary:
	return COMBAT_FEEL_BY_TYPE.get(unit_type, COMBAT_FEEL_BY_TYPE[Unit.UnitType.WARRIOR])


func _award_exp(attacker: Unit, defender: Unit, atk_damage: int, def_damage: int, defender_died: bool, attacker_died: bool) -> Dictionary:
	var attacker_award: int = EXP_COMBAT_PARTICIPATION
	var defender_award: int = EXP_COMBAT_PARTICIPATION
	if atk_damage > 0:
		attacker_award += EXP_COMBAT_DAMAGE
	if def_damage > 0:
		defender_award += EXP_COMBAT_DAMAGE
	if defender_died:
		attacker_award += EXP_COMBAT_KILL
	if attacker_died:
		defender_award += EXP_COMBAT_KILL
	# Battle veteran (Warrior): double XP when fighting a higher-level unit
	if attacker.bonus_battle_veteran and int(defender.level) > int(attacker.level):
		attacker_award *= 2
	if defender.bonus_battle_veteran and int(attacker.level) > int(defender.level):
		defender_award *= 2
	# Veteran: +1 XP per combat
	if attacker.bonus_veteran:
		attacker_award += 1
	if defender.bonus_veteran:
		defender_award += 1
	# Leadership: +1 XP if within radius 2 of a leadership master (set by TurnManager)
	if attacker.leadership_xp_bonus:
		attacker_award += 1
	if defender.leadership_xp_bonus:
		defender_award += 1
	attacker_award = _scale_exp_for_level_difference(attacker_award, int(attacker.level) - int(defender.level))
	defender_award = _scale_exp_for_level_difference(defender_award, int(defender.level) - int(attacker.level))
	return {
		"attacker": attacker.gain_exp_with_result(attacker_award),
		"defender": defender.gain_exp_with_result(defender_award),
	}

func _scale_exp_for_level_difference(base_award: int, level_advantage: int) -> int:
	var scaled: float = float(base_award)
	match level_advantage:
		4:
			scaled *= 0.25
		3:
			scaled *= 0.35
		2:
			scaled *= 0.50
		1:
			scaled *= 0.72
		0:
			scaled *= 1.0
		-1:
			scaled *= 1.18
		-2:
			scaled *= 1.38
		-3:
			scaled *= 1.60
		_:
			if level_advantage >= 5:
				scaled *= 0.20
			elif level_advantage <= -4:
				scaled *= 1.80
	return maxi(1, int(round(scaled)))

func _check_flanking(atk_cell: Vector2i, def_cell: Vector2i, defender: Unit) -> bool:
	if atk_cell == Vector2i(-1, -1) or def_cell == Vector2i(-1, -1):
		return false
	if defender.facing == Vector2i.ZERO:
		return false
	# Vector from defender to attacker
	var attack_dir: Vector2i = atk_cell - def_cell
	# Dot product: if <= 0 the attack comes from the side or rear
	var dot: int = attack_dir.x * defender.facing.x + attack_dir.y * defender.facing.y
	return dot <= 0

func _show_combat_exp_feedback(exp_awards: Dictionary, attacker: Unit, defender: Unit, atk_rend, def_rend, atk_hp_bar: Control, def_hp_bar: Control) -> void:
	var attacker_exp: Dictionary = exp_awards.get("attacker", {})
	var defender_exp: Dictionary = exp_awards.get("defender", {})
	if atk_rend != null and not attacker_exp.is_empty():
		var gained: int = int(attacker_exp.get("gained", 0))
		if gained > 0:
			VFXManager.show_world_text_label(atk_rend.global_position, "+%d XP" % gained, Color(0.84, 0.42, 1.0, 1.0), 48, 1.75)
		VFXManager.update_combat_health_bar(atk_hp_bar, atk_rend.global_position, attacker.hp, attacker.max_hp, false)
		VFXManager.set_combat_health_bar_experience(atk_hp_bar, int(attacker.experience), int(attacker.get_exp_required()))
		if atk_rend.has_method("set_health_bar_values"):
			atk_rend.call("set_health_bar_values", attacker.hp, attacker.max_hp, false)
	if def_rend != null and not defender_exp.is_empty():
		var gained: int = int(defender_exp.get("gained", 0))
		if gained > 0:
			VFXManager.show_world_text_label(def_rend.global_position, "+%d XP" % gained, Color(0.84, 0.42, 1.0, 1.0), 48, 1.75)
		VFXManager.update_combat_health_bar(def_hp_bar, def_rend.global_position, defender.hp, defender.max_hp, false)
		VFXManager.set_combat_health_bar_experience(def_hp_bar, int(defender.experience), int(defender.get_exp_required()))
		if def_rend.has_method("set_health_bar_values"):
			def_rend.call("set_health_bar_values", defender.hp, defender.max_hp, false)


func _print_summary(attacker: Unit, defender: Unit,
		atk_log: Array, def_log: Array,
		type_mult: float, is_ranged: bool,
		defender_died: bool, attacker_died: bool) -> void:

	var mult_tag: String = ""
	if type_mult > 1.0:
		mult_tag = " [VENTAJA +1 %s→%s]" % [
			Unit.TYPE_NAMES.get(attacker.unit_type, "?"),
			Unit.TYPE_NAMES.get(defender.unit_type, "?"),
		]
	elif type_mult < 1.0:
		mult_tag = " [DESVENTAJA %s←%s]" % [
			Unit.TYPE_NAMES.get(attacker.unit_type, "?"),
			Unit.TYPE_NAMES.get(defender.unit_type, "?"),
		]
	var ranged_tag: String = ""
	if is_ranged:
		ranged_tag = " [RANGED - respuesta a distancia]" if not def_log.is_empty() else " [RANGED - sin contraataque]"
	print("[Combat] %s (P%d) vs %s (P%d)%s%s | golpes %d/%d" % [
		attacker.unit_name, attacker.owner_id,
		defender.unit_name, defender.owner_id,
		mult_tag, ranged_tag,
		atk_log.size(), def_log.size(),
	])

	for entry: Dictionary in atk_log:
		print("  %s -> %s" % [attacker.unit_name, _roll_line(entry)])
	for entry: Dictionary in def_log:
		print("  %s <- %s" % [defender.unit_name, _roll_line(entry)])

	if defender_died:
		print("  -> %s DERROTADO" % defender.unit_name)
	if attacker_died:
		print("  -> %s DERROTADO por contraataque" % attacker.unit_name)


func _roll_line(entry: Dictionary) -> String:
	var rolls: Array = entry.get("rolls", [])
	var dice_names: Array[String] = ["R", "A", "V", "Az"]
	var parts: Array[String] = []
	for r: Dictionary in rolls:
		var color_idx: int = r.get("color", 0)
		var name: String = dice_names[clampi(color_idx, 0, dice_names.size() - 1)]
		parts.append("[%s:%d]" % [name, r.get("value", 0)])
	var advantage_bonus: int = int(entry.get("advantage_bonus", 0))
	var bonus_text: String = " + %d ventaja" % advantage_bonus if advantage_bonus > 0 else ""
	return "#%d/%d %s -> total %d%s -> %d daño" % [
		int(entry.get("hit_index", 1)),
		int(entry.get("hit_count", 1)),
		" ".join(parts),
		int(entry.get("total", 0)),
		bonus_text,
		int(entry.get("damage", 0)),
	]
