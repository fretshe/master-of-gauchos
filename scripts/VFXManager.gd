extends Node

# ─── Canvas layer ───────────────────────────────────────────────────────────────
# All VFX nodes (labels, particles) live here so they render above the game world.
var _canvas: CanvasLayer

func _ready() -> void:
	_canvas       = CanvasLayer.new()
	_canvas.layer = 100         # always above 3D viewport and HUD
	add_child(_canvas)

# ─── Coordinate helper ──────────────────────────────────────────────────────────
## Converts a world-space position to screen-space using the active camera transform.
func _w2s(world_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * world_pos

# ═══════════════════════════════════════════════════════════════════════════════
# Floating damage labels
# ═══════════════════════════════════════════════════════════════════════════════

## Muestra texto de daño proyectando la posición 3D a pantalla y usando un Label 2D en CanvasLayer.
## Garantiza que aparece siempre encima de los sprites 3D.
## is_combat=true usa tamaños reducidos (cámara cerca); false usa tamaños tácticos (cámara lejos).
func show_damage_label(_host: Node, world_pos: Vector3, amount: int, type: String,
		is_combat: bool = false) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return

	var y_world: float = 1.0 if is_combat else 1.4
	var screen_pos: Vector2 = cam.unproject_position(world_pos + Vector3(0.0, y_world, 0.0))

	var text:        String = ""
	var color:       Color  = Color.WHITE
	var font_size:   int    = 80
	var punch_scale: float  = 1.4
	var hold_time:   float  = 0.20
	var float_dist:  float  = 80.0
	var float_dur:   float  = 1.2

	if is_combat:
		match type:
			"damage":
				text        = "-%d" % amount
				color       = Color(1.00, 0.12, 0.12)
				font_size   = 72
				hold_time   = 0.15
			"critical":
				text        = "-%d!" % amount
				color       = Color(1.00, 0.62, 0.00)
				font_size   = 88
				punch_scale = 1.65
				hold_time   = 0.25
				float_dist  = 95.0
			"miss":
				text        = "FALLO"
				color       = Color(0.55, 0.55, 0.60)
				font_size   = 56
				punch_scale = 1.15
				hold_time   = 0.12
			_:
				return
	else:
		float_dist = 130.0
		float_dur  = 2.0
		match type:
			"damage":
				text        = "-%d" % amount
				color       = Color(1.00, 0.12, 0.12)
				font_size   = 86
				hold_time   = 0.30
			"critical":
				text        = "-%d!" % amount
				color       = Color(1.00, 0.62, 0.00)
				font_size   = 104
				punch_scale = 1.65
				hold_time   = 0.50
				float_dist  = 150.0
			"miss":
				text        = "FALLO"
				color       = Color(0.58, 0.58, 0.64)
				font_size   = 62
				punch_scale = 1.15
				hold_time   = 0.15
				float_dur   = 1.6
			_:
				return

	var w: float      = 520.0
	var base_x: float = screen_pos.x - w * 0.5

	# Sombra
	var shadow := Label.new()
	shadow.text                 = text
	shadow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shadow.custom_minimum_size  = Vector2(w, 0.0)
	shadow.position             = Vector2(base_x + 3.0, screen_pos.y + 5.0)
	shadow.scale                = Vector2.ZERO
	shadow.add_theme_font_size_override("font_size", font_size)
	shadow.add_theme_color_override("font_color", Color(0.0, 0.0, 0.0, 0.80))
	_canvas.add_child(shadow)

	# Label principal
	var lbl := Label.new()
	lbl.text                 = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.custom_minimum_size  = Vector2(w, 0.0)
	lbl.position             = Vector2(base_x, screen_pos.y)
	lbl.scale                = Vector2.ZERO
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	_canvas.add_child(lbl)

	# Pop-in
	var sv := Vector2(punch_scale, punch_scale)
	var tw_pop: Tween = lbl.create_tween()
	tw_pop.tween_property(lbl,    "scale", sv,                0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_pop.tween_property(lbl,    "scale", Vector2(1.0, 1.0), 0.07)
	var tw_pop_s: Tween = shadow.create_tween()
	tw_pop_s.tween_property(shadow, "scale", sv,                0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_pop_s.tween_property(shadow, "scale", Vector2(1.0, 1.0), 0.07)
	await tw_pop.finished

	# Flash extra en crítico
	if type == "critical":
		var tw_f: Tween = lbl.create_tween()
		tw_f.tween_property(lbl, "modulate", Color(2.5, 2.5, 2.5, 1.0), 0.06)
		tw_f.tween_property(lbl, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.12)
		await tw_f.finished

	await get_tree().create_timer(hold_time).timeout

	# Flota hacia arriba y desaparece
	var drift := Vector2(0.0, -float_dist)
	var tw: Tween = lbl.create_tween().set_parallel(true)
	tw.tween_property(lbl, "position",   lbl.position + drift, float_dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0,                  float_dur)
	var tw_s: Tween = shadow.create_tween().set_parallel(true)
	tw_s.tween_property(shadow, "position",   shadow.position + drift, float_dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw_s.tween_property(shadow, "modulate:a", 0.0,                     float_dur)
	await tw.finished
	lbl.queue_free()
	shadow.queue_free()

func show_world_text_label(world_pos: Vector3, text: String, color: Color, font_size: int = 72, y_world: float = 1.4) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	var screen_pos: Vector2 = cam.unproject_position(world_pos + Vector3(0.0, y_world, 0.0))
	show_screen_text_label(screen_pos, text, color, font_size)

func show_screen_text_label(screen_pos: Vector2, text: String, color: Color, font_size: int = 56) -> void:
	var w: float = 320.0
	var base_x: float = screen_pos.x - w * 0.5
	var shadow := Label.new()
	shadow.text = text
	shadow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shadow.custom_minimum_size = Vector2(w, 0.0)
	shadow.position = Vector2(base_x + 2.0, screen_pos.y + 3.0)
	shadow.scale = Vector2.ZERO
	shadow.add_theme_font_size_override("font_size", font_size)
	shadow.add_theme_color_override("font_color", Color(0.0, 0.0, 0.0, 0.78))
	_canvas.add_child(shadow)

	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.custom_minimum_size = Vector2(w, 0.0)
	lbl.position = Vector2(base_x, screen_pos.y)
	lbl.scale = Vector2.ZERO
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	_canvas.add_child(lbl)

	var punch := Vector2(1.28, 1.28)
	var tw_pop: Tween = lbl.create_tween()
	tw_pop.tween_property(lbl, "scale", punch, 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_pop.tween_property(lbl, "scale", Vector2.ONE, 0.07)
	var tw_shadow: Tween = shadow.create_tween()
	tw_shadow.tween_property(shadow, "scale", punch, 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_shadow.tween_property(shadow, "scale", Vector2.ONE, 0.07)

	var drift := Vector2(0.0, -72.0)
	var tw: Tween = lbl.create_tween().set_parallel(true)
	tw.tween_interval(0.25)
	tw.tween_property(lbl, "position", lbl.position + drift, 0.90).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.90)
	var tw_s: Tween = shadow.create_tween().set_parallel(true)
	tw_s.tween_interval(0.25)
	tw_s.tween_property(shadow, "position", shadow.position + drift, 0.90).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw_s.tween_property(shadow, "modulate:a", 0.0, 0.90)
	await tw.finished
	lbl.queue_free()
	shadow.queue_free()

## 3D combat version of show_damage (legacy — uses 2D canvas projection).
## Converts world_pos_3d to screen using the active Camera3D.
## Call without `await` for fire-and-forget (label runs asynchronously).
func show_damage_3d(world_pos_3d: Vector3, amount: int, type: String) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	var screen_pos: Vector2 = cam.unproject_position(world_pos_3d + Vector3(0.0, 1.4, 0.0))
	screen_pos += Vector2(randf_range(-10.0, 10.0), randf_range(-5.0, 5.0))

	var text:       String = ""
	var color:      Color  = Color.WHITE
	var font_size:  int    = 80
	var punch_scale: float = 1.4
	var hold_time:  float  = 0.30
	var float_dist: float  = 130.0
	var float_dur:  float  = 2.0

	match type:
		"damage":
			text        = "-%d" % amount
			color       = Color(1.00, 0.12, 0.12)
			font_size   = 86
			punch_scale = 1.4
		"critical":
			text        = "-%d!" % amount
			color       = Color(1.00, 0.62, 0.00)
			font_size   = 104
			punch_scale = 1.65
			hold_time   = 0.50
			float_dist  = 150.0
		"miss":
			text        = "FALLO"
			color       = Color(0.58, 0.58, 0.64)
			font_size   = 62
			punch_scale = 1.15
			float_dur   = 1.6
		"dodge":
			text        = "ESQUIVA"
			color       = Color(0.28, 0.82, 1.00)
			font_size   = 72
			punch_scale = 1.35
		_:
			return

	var w: float = 520.0
	var base_x: float = screen_pos.x - w * 0.5

	# ── Shadow label (rendered behind for depth) ──────────────────────────────
	var shadow := Label.new()
	shadow.text                  = text
	shadow.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	shadow.custom_minimum_size   = Vector2(w, 0.0)
	shadow.position              = Vector2(base_x + 3.0, screen_pos.y + 5.0)
	shadow.scale                 = Vector2.ZERO
	shadow.add_theme_font_size_override("font_size", font_size)
	shadow.add_theme_color_override("font_color", Color(0.0, 0.0, 0.0, 0.80))
	_canvas.add_child(shadow)

	# ── Main label ────────────────────────────────────────────────────────────
	var lbl := Label.new()
	lbl.text                 = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.custom_minimum_size  = Vector2(w, 0.0)
	lbl.position             = Vector2(base_x, screen_pos.y)
	lbl.scale                = Vector2.ZERO
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	_canvas.add_child(lbl)

	# ── Pop-in punch ──────────────────────────────────────────────────────────
	var sv := Vector2(punch_scale, punch_scale)
	var tw_pop: Tween = lbl.create_tween()
	tw_pop.tween_property(lbl, "scale", sv,               0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_pop.tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.07)

	var tw_pop_s: Tween = shadow.create_tween()
	tw_pop_s.tween_property(shadow, "scale", sv,               0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_pop_s.tween_property(shadow, "scale", Vector2(1.0, 1.0), 0.07)

	await tw_pop.finished

	# Extra brightness flash on critical
	if type == "critical":
		var tw_flash: Tween = lbl.create_tween()
		tw_flash.tween_property(lbl, "modulate", Color(2.5, 2.5, 2.5, 1.0), 0.06)
		tw_flash.tween_property(lbl, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.12)
		await tw_flash.finished

	# ── Hold ──────────────────────────────────────────────────────────────────
	await get_tree().create_timer(hold_time).timeout

	# ── Float up and fade ─────────────────────────────────────────────────────
	var drift := Vector2(0.0, -float_dist)
	var tw: Tween = lbl.create_tween().set_parallel(true)
	tw.tween_property(lbl, "position",   lbl.position + drift, float_dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0,                  float_dur)

	var tw_s: Tween = shadow.create_tween().set_parallel(true)
	tw_s.tween_property(shadow, "position",   shadow.position + drift, float_dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw_s.tween_property(shadow, "modulate:a", 0.0,                     float_dur)

	await tw.finished
	lbl.queue_free()
	shadow.queue_free()

## Spawns a floating label at world_pos.
## type: "damage" | "critical" | "miss" | "dodge"
## amount is used for "damage" and "critical"; ignored otherwise.
func show_damage(world_pos: Vector2, amount: int, type: String) -> void:
	var lbl := Label.new()
	var jitter := Vector2(randf_range(-10.0, 10.0), randf_range(-4.0, 4.0))
	var screen_pos: Vector2 = _w2s(world_pos) + jitter + Vector2(-14.0, -28.0)

	match type:
		"damage":
			lbl.text = "-%d" % amount
			lbl.add_theme_color_override("font_color", Color(1.00, 0.20, 0.20))
			lbl.add_theme_font_size_override("font_size", 28)
		"critical":
			lbl.text = "-%d!" % amount
			lbl.add_theme_color_override("font_color", Color(1.00, 0.55, 0.00))
			lbl.add_theme_font_size_override("font_size", 36)
		"miss":
			lbl.text = "FALLO"
			lbl.add_theme_color_override("font_color", Color(0.58, 0.58, 0.58))
			lbl.add_theme_font_size_override("font_size", 13)
		"dodge":
			lbl.text = "ESQUIVA"
			lbl.add_theme_color_override("font_color", Color(0.35, 0.62, 1.00))
			lbl.add_theme_font_size_override("font_size", 15)
		_:
			lbl.queue_free()
			return

	lbl.scale    = Vector2(0.3, 0.3)
	lbl.position = screen_pos
	_canvas.add_child(lbl)

	# Pop-in scale
	var tw_pop: Tween = lbl.create_tween()
	tw_pop.tween_property(lbl, "scale", Vector2(1.2, 1.2), 0.08)
	tw_pop.tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.05)
	await tw_pop.finished

	# Float up and fade
	var tw: Tween = lbl.create_tween().set_parallel(true)
	tw.tween_property(lbl, "position",   screen_pos + Vector2(0.0, -100.0), 1.8)
	tw.tween_property(lbl, "modulate:a", 0.0,                               1.8)
	await tw.finished
	lbl.queue_free()

# ═══════════════════════════════════════════════════════════════════════════════
# Particle effects
# ═══════════════════════════════════════════════════════════════════════════════

## Small colour sparks when a unit is hit.
func particles_hit(world_pos: Vector2, color: Color) -> void:
	var p := _make_particles(world_pos)
	p.amount                  = 14
	p.lifetime                = 0.45
	p.explosiveness           = 1.0
	p.spread                  = 180.0
	p.gravity                 = Vector2(0.0, 280.0)
	p.initial_velocity_min    = 55.0
	p.initial_velocity_max    = 115.0
	p.scale_amount_min        = 2.0
	p.scale_amount_max        = 4.5
	p.color                   = color
	_canvas.add_child(p)
	p.emitting = true
	await get_tree().create_timer(1.2).timeout
	p.queue_free()

## Large burst of particles when a unit dies.
func particles_death(world_pos: Vector2) -> void:
	var p := _make_particles(world_pos)
	p.amount               = 32
	p.lifetime             = 0.90
	p.explosiveness        = 1.0
	p.spread               = 180.0
	p.gravity              = Vector2(0.0, 160.0)
	p.initial_velocity_min = 80.0
	p.initial_velocity_max = 190.0
	p.scale_amount_min     = 3.0
	p.scale_amount_max     = 7.0
	# Orange → dark-red gradient
	var grad := Gradient.new()
	grad.set_color(0, Color(1.00, 0.75, 0.10))
	grad.set_color(1, Color(0.60, 0.08, 0.00, 0.00))
	p.color_ramp = grad
	_canvas.add_child(p)
	p.emitting = true
	await get_tree().create_timer(1.8).timeout
	p.queue_free()

## Golden stars rising upward on level-up.
func particles_level_up(world_pos: Vector2) -> void:
	var p := _make_particles(world_pos)
	p.amount               = 22
	p.lifetime             = 1.10
	p.explosiveness        = 0.70
	p.spread               = 55.0
	p.direction            = Vector2(0.0, -1.0)
	p.gravity              = Vector2(0.0, -25.0)
	p.initial_velocity_min = 50.0
	p.initial_velocity_max = 105.0
	p.scale_amount_min     = 3.0
	p.scale_amount_max     = 6.0
	p.color                = Color(0.95, 0.82, 0.20)
	_canvas.add_child(p)
	p.emitting = true
	await get_tree().create_timer(1.8).timeout
	p.queue_free()

## Multi-colour confetti burst when a tower is captured.
func particles_capture(world_pos: Vector2) -> void:
	var screen_pos: Vector2 = _w2s(world_pos)
	var colors: Array[Color] = [
		Color(0.20, 0.82, 0.34),
		Color(0.95, 0.80, 0.12),
		Color(0.30, 0.52, 1.00),
	]
	for i in range(3):
		var p := CPUParticles2D.new()
		p.position             = screen_pos + Vector2(randf_range(-8.0, 8.0), 0.0)
		p.amount               = 16
		p.lifetime             = 1.20
		p.one_shot             = true
		p.explosiveness        = 0.85
		p.spread               = 85.0
		p.direction            = Vector2(0.0, -1.0)
		p.gravity              = Vector2(0.0, 220.0)
		p.initial_velocity_min = 55.0
		p.initial_velocity_max = 130.0
		p.scale_amount_min     = 3.0
		p.scale_amount_max     = 6.0
		p.color                = colors[i]
		_canvas.add_child(p)
		p.emitting = true
	await get_tree().create_timer(2.0).timeout
	# Clean up any leftover particles (already freed if parented correctly)

# ═══════════════════════════════════════════════════════════════════════════════
# Unit flash
# ═══════════════════════════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════════════════════════
# Dice roll display
# ═══════════════════════════════════════════════════════════════════════════════

const DICE_COLORS: Array[Color] = [
	Color(0.85, 0.15, 0.15),   # RED
	Color(0.88, 0.78, 0.05),   # YELLOW
	Color(0.10, 0.72, 0.22),   # GREEN
	Color(0.18, 0.42, 0.90),   # BLUE
]

const DICE_LABELS: Array[String] = ["R", "A", "V", "Az"]

## Shows an animated dice roll at a 3D world position.
## die_color: Unit.DiceColor int.
## result: the face value rolled.
## screen_x_offset: horizontal pixel offset for side-by-side dice.
## Call without await for fire-and-forget.
func show_dice_roll_3d(world_pos_3d: Vector3, die_color: int, result: int,
		screen_x_offset: int = 0) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	var base_pos: Vector2 = cam.unproject_position(world_pos_3d + Vector3(0.0, 2.2, 0.0))
	var screen_pos: Vector2 = base_pos + Vector2(screen_x_offset, 0.0)

	# ── Build die panel ────────────────────────────────────────────────────────
	var panel: Panel = Panel.new()
	panel.size = Vector2(58.0, 58.0)
	panel.position = screen_pos - Vector2(29.0, 29.0)
	panel.scale = Vector2(0.05, 0.05)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	var bg_col: Color = DICE_COLORS[clampi(die_color, 0, DICE_COLORS.size() - 1)]
	style.bg_color = bg_col
	style.set_corner_radius_all(8)
	style.border_color = Color(1.0, 1.0, 1.0, 0.6)
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)

	# Color abbreviation label (top-left)
	var lbl_color: Label = Label.new()
	lbl_color.text = DICE_LABELS[clampi(die_color, 0, DICE_LABELS.size() - 1)]
	lbl_color.position = Vector2(4.0, 2.0)
	lbl_color.add_theme_font_size_override("font_size", 11)
	lbl_color.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.85))
	panel.add_child(lbl_color)

	# Main result label (centered)
	var lbl_val: Label = Label.new()
	lbl_val.text = "?"
	lbl_val.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_val.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl_val.add_theme_font_size_override("font_size", 26)
	lbl_val.add_theme_color_override("font_color", Color.WHITE)
	panel.add_child(lbl_val)

	_canvas.add_child(panel)

	# ── Pop-in ─────────────────────────────────────────────────────────────────
	var tw_in: Tween = panel.create_tween()
	tw_in.tween_property(panel, "scale", Vector2(1.2, 1.2), 0.12)
	tw_in.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.06)
	await tw_in.finished

	# ── Simulate rolling (flash random faces) ─────────────────────────────────
	var faces: Array = Unit.DICE.get(die_color, [0, 1, 2, 3])
	for _i: int in range(10):
		lbl_val.text = str(faces[randi() % faces.size()])
		await get_tree().create_timer(0.05).timeout

	# ── Reveal result ──────────────────────────────────────────────────────────
	lbl_val.text = str(result)

	var tw_reveal: Tween = panel.create_tween()
	tw_reveal.tween_property(panel, "modulate", Color(2.0, 2.0, 2.0, 1.0), 0.08)
	tw_reveal.tween_property(panel, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.20)
	await tw_reveal.finished

	# ── Hold ──────────────────────────────────────────────────────────────────
	await get_tree().create_timer(0.75).timeout

	# ── Float up and fade ─────────────────────────────────────────────────────
	var tw_out: Tween = panel.create_tween().set_parallel(true)
	tw_out.tween_property(panel, "position", panel.position + Vector2(0.0, -40.0), 0.35)
	tw_out.tween_property(panel, "modulate:a", 0.0, 0.35)
	await tw_out.finished
	panel.queue_free()

## Flashes the unit token in `color` for ~0.3 s.
## Uses Unit.visual_flash_color + Unit.visual_flash (driven by HexGrid._draw_unit_token).
func flash_unit(unit: Unit, color: Color) -> void:
	unit.visual_flash_color = color
	var tw: Tween = create_tween()
	tw.tween_property(unit, "visual_flash", 1.0, 0.08)
	tw.tween_property(unit, "visual_flash", 0.0, 0.22)
	await tw.finished
	unit.visual_flash = 0.0

# ─── Internal factory ───────────────────────────────────────────────────────────
func _make_particles(world_pos: Vector2) -> CPUParticles2D:
	var p               := CPUParticles2D.new()
	p.position          = _w2s(world_pos)
	p.one_shot          = true
	p.emitting          = false   # caller sets true after add_child
	p.direction         = Vector2(0.0, -1.0)
	p.spread            = 180.0
	p.gravity           = Vector2(0.0, 200.0)
	p.local_coords      = true
	return p
