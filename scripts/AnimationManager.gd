extends Node

# Emitted once every animation call completes.
signal animation_finished

var hex_grid: Node2D = null

var _animating: bool = false

# ─── Process ─────────────────────────────────────────────────────────────────────
func _process(_delta: float) -> void:
	if _animating and is_instance_valid(hex_grid):
		hex_grid.queue_redraw()

# ─── Move ────────────────────────────────────────────────────────────────────────
func animate_move(unit: Unit, from_pos: Vector2, to_pos: Vector2) -> void:
	_animating = true
	unit.visual_pos = from_pos
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(unit, "visual_pos", to_pos, 0.3)
	await tween.finished
	unit.visual_pos = to_pos
	_finish()

# ─── Duel ────────────────────────────────────────────────────────────────────────
## Plays one lunge per round and calls VFXManager for per-blow effects.
## atk_log / def_log: Array of { hit, dodged, damage } from CombatManager.
func animate_duel(attacker: Unit, defender: Unit,
		atk_log: Array, def_log: Array) -> void:
	_animating = true
	var atk_origin: Vector2   = attacker.visual_pos
	var def_origin: Vector2   = defender.visual_pos
	var punch_pos: Vector2    = atk_origin.lerp(def_origin, 0.28)

	var rounds: int = maxi(atk_log.size(), def_log.size())

	for r in range(rounds):
		# ── Attacker lunges ───────────────────────────────────────────────────
		var tw_a: Tween = create_tween()
		tw_a.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		tw_a.tween_property(attacker, "visual_pos", punch_pos,  0.10)
		tw_a.tween_property(attacker, "visual_pos", atk_origin, 0.14)

		# ── Attacker blow VFX ─────────────────────────────────────────────────
		if r < atk_log.size():
			var blow: Dictionary = atk_log[r]
			if blow.hit and not blow.dodged:
				VFXManager.show_damage(def_origin, blow.damage, "damage")
				VFXManager.particles_hit(def_origin, Color(1.0, 0.28, 0.28))
				VFXManager.flash_unit(defender, Color(1.0, 0.18, 0.18))
				_shake(defender, def_origin)
			elif blow.hit and blow.dodged:
				VFXManager.show_damage(def_origin, 0, "dodge")
				VFXManager.flash_unit(defender, Color(1.0, 1.0, 1.0))
			else:
				VFXManager.show_damage(atk_origin, 0, "miss")

		await tw_a.finished

		# ── Pause then defender counter-blow VFX ──────────────────────────────
		if r < def_log.size():
			await get_tree().create_timer(0.4).timeout
			var blow: Dictionary = def_log[r]
			if blow.hit and not blow.dodged:
				VFXManager.show_damage(atk_origin, blow.damage, "damage")
				VFXManager.particles_hit(atk_origin, Color(1.0, 0.55, 0.15))
				VFXManager.flash_unit(attacker, Color(1.0, 0.18, 0.18))
				_shake(attacker, atk_origin)
			elif blow.hit and blow.dodged:
				VFXManager.show_damage(atk_origin, 0, "dodge")
				VFXManager.flash_unit(attacker, Color(1.0, 1.0, 1.0))
			else:
				VFXManager.show_damage(def_origin, 0, "miss")

		# ── Pause between rounds ───────────────────────────────────────────────
		if r < rounds - 1:
			await get_tree().create_timer(0.6).timeout

	# ── Dramatic pause before result ──────────────────────────────────────────
	await get_tree().create_timer(1.0).timeout

	attacker.visual_pos = atk_origin
	defender.visual_pos = def_origin
	_finish()

# ─── Death ───────────────────────────────────────────────────────────────────────
func animate_death(unit: Unit) -> void:
	_animating = true
	VFXManager.particles_death(unit.visual_pos)
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(unit, "visual_scale", 0.0, 0.5)
	tween.tween_property(unit, "visual_alpha", 0.0, 0.5)
	await tween.finished
	_finish()

# ─── Level-up ────────────────────────────────────────────────────────────────────
func animate_level_up(unit: Unit) -> void:
	_animating = true
	var tween: Tween = create_tween()
	tween.tween_property(unit, "visual_flash", 1.0, 0.15)
	tween.tween_property(unit, "visual_flash", 0.0, 0.35)
	await tween.finished
	unit.visual_flash = 0.0
	_finish()

# ─── Capture ─────────────────────────────────────────────────────────────────────
func animate_capture(tower: Tower) -> void:
	_animating = true
	var tween: Tween = create_tween()
	tween.tween_property(tower, "visual_flash", 1.0, 0.15)
	tween.tween_property(tower, "visual_flash", 0.0, 0.40)
	await tween.finished
	tower.visual_flash = 0.0
	_finish()

# ─── Helpers ─────────────────────────────────────────────────────────────────────
func _shake(unit: Unit, origin: Vector2) -> void:
	var s: float  = 7.0
	var tw: Tween = create_tween().set_trans(Tween.TRANS_SINE)
	tw.tween_property(unit, "visual_pos", origin + Vector2(-s,       0), 0.05)
	tw.tween_property(unit, "visual_pos", origin + Vector2( s,       0), 0.05)
	tw.tween_property(unit, "visual_pos", origin + Vector2(-s * 0.4, 0), 0.05)
	tw.tween_property(unit, "visual_pos", origin,                        0.04)

func _finish() -> void:
	_animating = false
	animation_finished.emit()
