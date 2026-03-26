extends RefCounted

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
##   "host"              : Node  — used to create tweens / timers
##
## Returns {
##   attacker_log, defender_log,   # Array of roll-result dicts
##   defender_died, attacker_died,
##   type_mult, is_ranged
## }
##
## Each log entry: { "rolls": [{color, value}, …], "total": int, "damage": int }
func resolve_combat(attacker: Unit, defender: Unit,
		is_ranged: bool = false,
		visual_context: Dictionary = {}) -> Dictionary:

	if attacker.has_attacked:
		return {"attacker_log": [], "defender_log": [], "defender_died": false,
				"attacker_died": false, "type_mult": 1.0, "is_ranged": is_ranged}

	# ── Unpack visual context ──────────────────────────────────────────────────
	var camera              = visual_context.get("camera",            null)
	var atk_rend            = visual_context.get("attacker_renderer", null)
	var def_rend            = visual_context.get("defender_renderer", null)
	var all_renderers:Array = visual_context.get("all_renderers",     [])
	var host: Node          = visual_context.get("host",              null)
	var atk_pos: Vector3    = visual_context.get("attacker_pos",      Vector3.ZERO)
	var def_pos: Vector3    = visual_context.get("defender_pos",      Vector3.ZERO)
	var atk_cell: Vector2i  = visual_context.get("attacker_cell",     Vector2i(-1, -1))
	var def_cell: Vector2i  = visual_context.get("defender_cell",     Vector2i(-1, -1))

	# ── Enter cinematic ────────────────────────────────────────────────────────
	if camera != null:
		if atk_rend != null: atk_rend.set_combat_facing(def_pos)
		if def_rend != null: def_rend.set_combat_facing(atk_pos)
		var enter_tw: Tween = camera.enter_combat_mode(atk_pos, def_pos)
		if atk_rend != null: atk_rend.set_combat_focus(true)
		if def_rend != null: def_rend.set_combat_focus(true)
		for r: Variant in all_renderers:
			if r != atk_rend and r != def_rend:
				r.set_combat_dim(true)
			r.dim_selection_ring()
			r.set_selection_ring_visible(false)
		await enter_tw.finished
		if host != null and host.has_method("set_combat_team_rings_visible"):
			host.call("set_combat_team_rings_visible", false)
		if host != null and host.has_method("show_combat_stage") and atk_cell != Vector2i(-1, -1) and def_cell != Vector2i(-1, -1):
			host.call("show_combat_stage", atk_cell, def_cell, camera.global_position)
		if host != null and host.has_method("set_combat_tower_obstruction_fade"):
			host.call("set_combat_tower_obstruction_fade", true, (atk_pos + def_pos) / 2.0, camera.global_position)
		if atk_rend != null: atk_rend.set_combat_mode()
		if def_rend != null: def_rend.set_combat_mode()

	if host != null:
		await host.get_tree().create_timer(0.5).timeout

	MusicManager.play_combat_music()

	var type_mult: float = Unit.get_damage_multiplier(attacker.unit_type, defender.unit_type)
	var atk_log: Array   = []
	var def_log: Array   = []

	# ── Phase 1: attacker strikes ──────────────────────────────────────────────
	var atk_dice: Array = attacker.get_ranged_dice() if is_ranged else attacker.get_melee_dice()
	var atk_result: Dictionary = _roll_attack(attacker, atk_dice, type_mult)
	atk_log.append(atk_result)

	await _animate_dice_attack(atk_result, atk_rend, def_rend, host, attacker.unit_type)

	defender.take_damage(atk_result["damage"])

	var defender_died: bool = defender.hp == 0
	var attacker_died: bool = false

	# ── Phase 2: defender counter-strikes (melee only, if alive) ──────────────
	if not is_ranged and not defender_died:
		if host != null:
			await host.get_tree().create_timer(0.5).timeout

		var def_dice: Array = defender.get_melee_dice()
		# Counter-attack never benefits from type multiplier (defensive action)
		var def_result: Dictionary = _roll_attack(defender, def_dice, 1.0)
		def_log.append(def_result)

		await _animate_dice_attack(def_result, def_rend, atk_rend, host, defender.unit_type)

		attacker.take_damage(def_result["damage"])
		attacker_died = attacker.hp == 0

	MusicManager.stop_combat_music()

	attacker.has_attacked = true

	# ── Award experience ───────────────────────────────────────────────────────
	var atk_damage: int = atk_result["damage"] if not atk_log.is_empty() else 0
	_award_exp(attacker, defender, atk_damage, defender_died)

	# ── Console summary ────────────────────────────────────────────────────────
	_print_summary(attacker, defender, atk_log, def_log, type_mult, is_ranged, defender_died, attacker_died)

	# ── Death animations ───────────────────────────────────────────────────────
	if host != null:
		if defender_died and def_rend != null:
			AudioManager.play_death()
			await def_rend.anim_death(
				atk_rend.position if atk_rend != null else atk_pos, host).finished

		if attacker_died and atk_rend != null:
			AudioManager.play_death()
			await atk_rend.anim_death(
				def_rend.position if def_rend != null else def_pos, host).finished

	# ── Exit cinematic ─────────────────────────────────────────────────────────
	if camera != null:
		if host != null and host.has_method("set_combat_tower_obstruction_fade"):
			host.call("set_combat_tower_obstruction_fade", false)
		if host != null and host.has_method("hide_combat_stage"):
			host.call("hide_combat_stage")
		if host != null and host.has_method("set_combat_team_rings_visible"):
			host.call("set_combat_team_rings_visible", true)
		if not attacker_died and atk_rend != null:
			atk_rend.set_combat_focus(false)
			atk_rend.reset_combat_facing()
			atk_rend.set_tactical_mode()
		if not defender_died and def_rend != null:
			def_rend.set_combat_focus(false)
			def_rend.reset_combat_facing()
			def_rend.set_tactical_mode()
		for r: Variant in all_renderers:
			r.set_combat_dim(false)
			r.set_selection_ring_visible(true)
			r.restore_selection_ring()
		await camera.exit_combat_mode().finished

	return {
		"attacker_log":  atk_log,
		"defender_log":  def_log,
		"defender_died": defender_died,
		"attacker_died": attacker_died,
		"type_mult":     type_mult,
		"is_ranged":     is_ranged,
	}

# ─── Internal ────────────────────────────────────────────────────────────────────

## Rolls all dice for one attack phase.
## Returns { "rolls": [{color, value}, …], "total": int, "damage": int }
func _roll_attack(unit: Unit, dice: Array, type_mult: float) -> Dictionary:
	var rolls: Array = []
	var total: int   = 0
	for die_color: int in dice:
		var val: int = unit.roll_dice(die_color)
		rolls.append({"color": die_color, "value": val})
		total += val
	var damage: int = maxi(0, roundi(float(total) * type_mult))
	return {"rolls": rolls, "total": total, "damage": damage}

## Plays the visual sequence for a single dice attack:
## lunge → [impact: sound + damage label + defender recoil] → dice rolling VFX → hold.
func _animate_dice_attack(roll_result: Dictionary, src_rend, dst_rend, host: Node, unit_type: int) -> void:
	if host == null:
		return

	# 1. Attacker lunges toward defender
	if src_rend != null and dst_rend != null:
		await src_rend.anim_lunge(dst_rend.position, host).finished

	# 2. Moment of impact — sound, damage label and defender recoil all at once, no delay between them
	AudioManager.play_attack(unit_type)

	var dmg: int = roll_result.get("damage", 0)
	if dmg > 0 and dst_rend != null:
		var dmg_type: String = "critical" if dmg >= 4 else "damage"
		VFXManager.show_damage_label(host, dst_rend.position, dmg, dmg_type, true)
		if src_rend != null:
			dst_rend.anim_hit(src_rend.position, host)
	elif dmg == 0 and dst_rend != null:
		VFXManager.show_damage_label(host, dst_rend.position, 0, "miss", true)

	# 3. Dice rolls (fire-and-forget, staggered by slot index)
	var src_pos: Vector3 = src_rend.position if src_rend != null else Vector3.ZERO
	var rolls: Array     = roll_result.get("rolls", [])
	var slot_offset: int = -(rolls.size() - 1) * 35   # center the dice group
	for i: int in range(rolls.size()):
		var roll: Dictionary = rolls[i]
		VFXManager.show_dice_roll_3d(src_pos, roll["color"], roll["value"],
				slot_offset + i * 70)

	# 4. Hold for dice animation and pacing
	await host.get_tree().create_timer(1.6).timeout

## Awards exp after combat resolves.
## Both units get 1 participation exp.
## Attacker gets +2 if their attack dealt damage, +5 if the defender died.
## Defender gets no extra exp for counter-attack hits.
func _award_exp(attacker: Unit, defender: Unit, atk_damage: int, defender_died: bool) -> void:
	# Participation
	attacker.gain_exp(1)
	defender.gain_exp(1)

	# Attacker bonuses
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
	var ranged_tag: String = " [RANGED — sin contraataque]" if is_ranged else ""
	print("[Combat] %s (P%d) vs %s (P%d)%s%s" % [
		attacker.unit_name, attacker.owner_id,
		defender.unit_name, defender.owner_id,
		mult_tag, ranged_tag,
	])

	for entry: Dictionary in atk_log:
		print("  %s → %s" % [attacker.unit_name, _roll_line(entry)])
	for entry: Dictionary in def_log:
		print("  %s ↩ %s" % [defender.unit_name, _roll_line(entry)])

	if defender_died:
		print("  → %s DERROTADO" % defender.unit_name)
	if attacker_died:
		print("  → %s DERROTADO por contraataque" % attacker.unit_name)

func _roll_line(entry: Dictionary) -> String:
	var rolls: Array  = entry.get("rolls", [])
	var dice_names: Array[String] = ["R", "A", "V", "Az"]
	var parts: Array[String] = []
	for r: Dictionary in rolls:
		var color_idx: int = r.get("color", 0)
		var name: String   = dice_names[clampi(color_idx, 0, dice_names.size() - 1)]
		parts.append("[%s:%d]" % [name, r.get("value", 0)])
	return "%s → total %d → %d daño" % [
		" ".join(parts), entry.get("total", 0), entry.get("damage", 0)
	]
