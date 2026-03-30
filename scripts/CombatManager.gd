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

# ─── Public API ─────────────────────────────────────────────────────────────────
## Resolves a combat between attacker and defender using the dice system.
## is_ranged: ranged attacks prevent the defender from counter-attacking.
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
	var atk_hp_bar: Control = null
	var def_hp_bar: Control = null
	var type_mult: float = Unit.get_damage_multiplier(attacker.unit_type, defender.unit_type)
	var defender_mult: float = Unit.get_damage_multiplier(defender.unit_type, attacker.unit_type)

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
		if atk_rend != null:
			atk_hp_bar = VFXManager.create_combat_health_bar(
				atk_rend.global_position,
				attacker.hp,
				attacker.max_hp,
				str(attacker.unit_name),
				int(attacker.level),
				int(attacker.unit_type)
			)
		if def_rend != null:
			def_hp_bar = VFXManager.create_combat_health_bar(
				def_rend.global_position,
				defender.hp,
				defender.max_hp,
				str(defender.unit_name),
				int(defender.level),
				int(defender.unit_type)
			)
		VFXManager.set_combat_health_bar_matchup(atk_hp_bar, 1 if type_mult > 1.0 else (-1 if type_mult < 1.0 else 0))
		VFXManager.set_combat_health_bar_matchup(def_hp_bar, 1 if defender_mult > 1.0 else (-1 if defender_mult < 1.0 else 0))

	if host != null:
		await host.get_tree().create_timer(0.35).timeout

	MusicManager.play_combat_music()

	var attacker_hit_count: int = attacker.get_attack_count_for_terrain(attacker_terrain)
	var defender_hit_count: int = defender.get_attack_count_for_terrain(defender_terrain)
	var atk_log: Array = []
	var def_log: Array = []

	var atk_dice: Array = attacker.get_ranged_dice() if is_ranged else attacker.get_melee_dice()
	var defender_died: bool = false
	var attacker_died: bool = false

	if is_ranged:
		for hit_index: int in range(attacker_hit_count):
			if defender.hp <= 0:
				break
			var atk_result: Dictionary = _roll_attack(
				attacker,
				atk_dice,
				type_mult,
				attacker.get_damage_scale_per_hit()
			)
			atk_result["hit_index"] = hit_index + 1
			atk_result["hit_count"] = attacker_hit_count
			atk_log.append(atk_result)

			await _animate_dice_attack(atk_result, atk_rend, def_rend, atk_hp_bar, host, attacker.unit_type)
			defender.take_damage(int(atk_result.get("damage", 0)))
			if def_rend != null:
				def_rend.set_health_bar_values(defender.hp, defender.max_hp)
				VFXManager.update_combat_health_bar(def_hp_bar, def_rend.global_position, defender.hp, defender.max_hp)
			if atk_rend != null:
				VFXManager.update_combat_health_bar(atk_hp_bar, atk_rend.global_position, attacker.hp, attacker.max_hp, false)
	else:
		var def_dice: Array = defender.get_melee_dice()
		var round_count: int = maxi(attacker_hit_count, defender_hit_count)
		for hit_index: int in range(round_count):
			if defender.hp > 0 and hit_index < attacker_hit_count:
				var atk_result: Dictionary = _roll_attack(
					attacker,
					atk_dice,
					type_mult,
					attacker.get_damage_scale_per_hit()
				)
				atk_result["hit_index"] = hit_index + 1
				atk_result["hit_count"] = attacker_hit_count
				atk_log.append(atk_result)

				await _animate_dice_attack(atk_result, atk_rend, def_rend, atk_hp_bar, host, attacker.unit_type)
				defender.take_damage(int(atk_result.get("damage", 0)))
				if def_rend != null:
					def_rend.set_health_bar_values(defender.hp, defender.max_hp)
					VFXManager.update_combat_health_bar(def_hp_bar, def_rend.global_position, defender.hp, defender.max_hp)
				if atk_rend != null:
					VFXManager.update_combat_health_bar(atk_hp_bar, atk_rend.global_position, attacker.hp, attacker.max_hp, false)

			if defender.hp <= 0:
				break

			if attacker.hp > 0 and hit_index < defender_hit_count:
				var def_result: Dictionary = _roll_attack(
					defender,
					def_dice,
					1.0,
					defender.get_damage_scale_per_hit()
				)
				def_result["hit_index"] = hit_index + 1
				def_result["hit_count"] = defender_hit_count
				def_log.append(def_result)

				await _animate_dice_attack(def_result, def_rend, atk_rend, def_hp_bar, host, defender.unit_type)
				attacker.take_damage(int(def_result.get("damage", 0)))
				if atk_rend != null:
					atk_rend.set_health_bar_values(attacker.hp, attacker.max_hp)
					VFXManager.update_combat_health_bar(atk_hp_bar, atk_rend.global_position, attacker.hp, attacker.max_hp)
				if def_rend != null:
					VFXManager.update_combat_health_bar(def_hp_bar, def_rend.global_position, defender.hp, defender.max_hp, false)

			if attacker.hp <= 0:
				break

	defender_died = defender.hp == 0
	attacker_died = attacker.hp == 0

	MusicManager.stop_combat_music()

	attacker.has_attacked = true

	var atk_damage: int = 0
	for attack_entry: Dictionary in atk_log:
		atk_damage += int(attack_entry.get("damage", 0))
	_award_exp(attacker, defender, atk_damage, defender_died)

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
func _roll_attack(unit: Unit, dice: Array, type_mult: float, damage_scale: float = 1.0) -> Dictionary:
	var rolls: Array = []
	var total: int = 0
	var has_critical: bool = false
	for die_color: int in dice:
		var val: int = unit.roll_dice(die_color)
		var die_is_critical: bool = val > 0 and randf() < CRITICAL_CHANCE
		rolls.append({"color": die_color, "value": val, "critical": die_is_critical})
		total += val
		if die_is_critical:
			has_critical = true
	var damage: int = maxi(0, roundi(float(total) * type_mult * damage_scale))
	if has_critical and damage > 0:
		damage *= 2
	return {"rolls": rolls, "total": total, "damage": damage, "critical": has_critical}


func _animate_dice_attack(roll_result: Dictionary, src_rend, dst_rend, src_hp_bar: Control, host: Node, unit_type: int) -> void:
	if host == null:
		return

	var feel: Dictionary = _get_combat_feel(unit_type)
	var anticipation: float = float(feel.get("anticipation", 0.10))
	var recovery: float = float(feel.get("recovery", 0.22))
	var intensity: float = float(feel.get("intensity", 1.0))
	var label_color: Color = feel.get("label_color", Color(1.0, 0.96, 0.72))

	if src_rend != null and dst_rend != null:
		VFXManager.show_combat_hit_label(
			src_rend.position.lerp(dst_rend.position, 0.38),
			int(roll_result.get("hit_index", 1)),
			int(roll_result.get("hit_count", 1)),
			label_color
		)
		await src_rend.anim_attack_anticipation(host, intensity, anticipation).finished
		await src_rend.anim_lunge(dst_rend.position, host).finished

	AudioManager.play_attack(unit_type)

	var rolls: Array = roll_result.get("rolls", [])
	await VFXManager.show_combat_health_bar_rolls(src_hp_bar, rolls)

	var dmg: int = int(roll_result.get("damage", 0))
	var is_critical: bool = bool(roll_result.get("critical", false))
	if dmg > 0 and dst_rend != null:
		if is_critical:
			AudioManager.play_critical()
		else:
			AudioManager.play_hurt()
		var dmg_type: String = "critical" if is_critical else "damage"
		VFXManager.show_damage_label(host, dst_rend.position, dmg, dmg_type, true)
		if src_rend != null:
			await dst_rend.anim_hit(src_rend.position, host).finished
	elif dmg == 0 and dst_rend != null:
		AudioManager.play_dodge()
		VFXManager.show_damage_label(host, dst_rend.position, 0, "miss", true)
		if src_rend != null:
			await dst_rend.anim_dodge(src_rend.position, host).finished

	await host.get_tree().create_timer(recovery).timeout


func _get_combat_feel(unit_type: int) -> Dictionary:
	return COMBAT_FEEL_BY_TYPE.get(unit_type, COMBAT_FEEL_BY_TYPE[Unit.UnitType.WARRIOR])


func _award_exp(attacker: Unit, defender: Unit, atk_damage: int, defender_died: bool) -> void:
	attacker.gain_exp(1)
	defender.gain_exp(1)
	if atk_damage > 0:
		attacker.gain_exp(2)
	if defender_died:
		attacker.gain_exp(5)


func _print_summary(attacker: Unit, defender: Unit,
		atk_log: Array, def_log: Array,
		type_mult: float, is_ranged: bool,
		defender_died: bool, attacker_died: bool) -> void:

	var mult_tag: String = ""
	if type_mult > 1.0:
		mult_tag = " [VENTAJA x%.2f %s→%s]" % [
			type_mult,
			Unit.TYPE_NAMES.get(attacker.unit_type, "?"),
			Unit.TYPE_NAMES.get(defender.unit_type, "?"),
		]
	elif type_mult < 1.0:
		mult_tag = " [DESVENTAJA x%.2f %s←%s]" % [
			type_mult,
			Unit.TYPE_NAMES.get(attacker.unit_type, "?"),
			Unit.TYPE_NAMES.get(defender.unit_type, "?"),
		]
	var ranged_tag: String = " [RANGED - sin contraataque]" if is_ranged else ""
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
	return "#%d/%d %s -> total %d -> %d daño" % [
		int(entry.get("hit_index", 1)),
		int(entry.get("hit_count", 1)),
		" ".join(parts),
		int(entry.get("total", 0)),
		int(entry.get("damage", 0)),
	]
