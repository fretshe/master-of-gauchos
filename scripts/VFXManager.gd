extends Node

# ─── Canvas layer ───────────────────────────────────────────────────────────────
# All VFX nodes (labels, particles) live here so they render above the game world.
var _canvas: CanvasLayer
var _dice_overlay_root: Control = null
var _dice_overlay_left_count: int = 0
var _dice_overlay_right_count: int = 0

const LEVEL_NAME_COLORS := {
	1: Color(0.85, 0.55, 0.25, 1.0),
	2: Color(0.80, 0.82, 0.88, 1.0),
	3: Color(1.00, 0.84, 0.24, 1.0),
	4: Color(0.16, 0.58, 0.36, 1.0),
	5: Color(0.28, 0.88, 1.00, 1.0),
}
const CLASS_ICON_PATHS := {
	-1: "res://assets/sprites/ui/class_icons/master_icon.png",
	0: "res://assets/sprites/ui/class_icons/warrior_icon.png",
	1: "res://assets/sprites/ui/class_icons/archer_icon.png",
	2: "res://assets/sprites/ui/class_icons/lancer_icon.png",
	3: "res://assets/sprites/ui/class_icons/rider_icon.png",
}
const UNIT_TYPE_DISPLAY_NAMES := {
	-1: "Maestro",
	0: "Guerrero",
	1: "Arquero",
	2: "Lancero",
	3: "Jinete",
}

func _ready() -> void:
	_canvas       = CanvasLayer.new()
	_canvas.layer = 100         # always above 3D viewport and HUD
	add_child(_canvas)

func _style_runtime_label(label: Label) -> void:
	if label == null:
		return
	GameData.apply_selected_font_to_control(label)

func show_card_target_telegraph(world_pos: Vector3, color: Color, label_text: String = "") -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	var screen_pos: Vector2 = cam.unproject_position(world_pos + Vector3(0.0, 1.10, 0.0))
	var root := Node2D.new()
	root.position = screen_pos
	_canvas.add_child(root)

	var outer := Line2D.new()
	outer.width = 5.0
	outer.default_color = Color(color.r, color.g, color.b, 0.92)
	outer.closed = true
	outer.antialiased = false
	for i: int in range(8):
		var angle: float = (TAU * float(i)) / 8.0
		var radius: float = 36.0 if i % 2 == 0 else 28.0
		outer.add_point(Vector2.RIGHT.rotated(angle) * radius)
	root.add_child(outer)

	var inner := Line2D.new()
	inner.width = 3.0
	inner.default_color = Color(1.0, 1.0, 1.0, 0.82)
	inner.closed = true
	inner.antialiased = false
	for i: int in range(8):
		var angle: float = (TAU * float(i)) / 8.0
		var radius: float = 22.0 if i % 2 == 0 else 16.0
		inner.add_point(Vector2.RIGHT.rotated(angle) * radius)
	root.add_child(inner)

	var glow := Polygon2D.new()
	glow.polygon = PackedVector2Array([
		Vector2(0.0, -26.0),
		Vector2(26.0, 0.0),
		Vector2(0.0, 26.0),
		Vector2(-26.0, 0.0),
	])
	glow.color = Color(color.r, color.g, color.b, 0.22)
	glow.scale = Vector2(1.8, 1.8)
	root.add_child(glow)

	if label_text != "":
		var lbl := Label.new()
		_style_runtime_label(lbl)
		lbl.text = label_text
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.custom_minimum_size = Vector2(220.0, 0.0)
		lbl.position = Vector2(-110.0, -62.0)
		lbl.add_theme_font_size_override("font_size", 24)
		lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.96))
		lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.03, 0.92))
		lbl.add_theme_constant_override("outline_size", 3)
		root.add_child(lbl)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(root, "scale", Vector2(1.14, 1.14), 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(outer, "rotation", 0.38, 0.26)
	tw.tween_property(inner, "rotation", -0.52, 0.26)
	tw.tween_method(
		func(progress: float) -> void:
			var pulse: float = 1.0 + sin(progress * TAU * 2.0) * 0.10
			glow.scale = Vector2.ONE * (1.55 + pulse * 0.30),
		0.0, 1.0, 0.26
	)
	await tw.finished
	var fade := create_tween().set_parallel(true)
	fade.tween_property(root, "scale", Vector2(0.88, 0.88), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fade.tween_property(root, "modulate:a", 0.0, 0.12)
	await fade.finished
	if is_instance_valid(root):
		root.queue_free()

func show_card_projectile(world_from: Vector3, world_to: Vector3, color: Color) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	var start: Vector2 = cam.unproject_position(world_from + Vector3(0.0, 1.55, 0.0))
	var finish: Vector2 = cam.unproject_position(world_to + Vector3(0.0, 1.35, 0.0))
	var root := Node2D.new()
	root.position = start
	_canvas.add_child(root)

	var trail := Line2D.new()
	trail.width = 12.0
	trail.default_color = Color(color.r, color.g, color.b, 0.86)
	trail.antialiased = false
	trail.add_point(Vector2.ZERO)
	trail.add_point(Vector2.ZERO)
	root.add_child(trail)

	var trail_core := Line2D.new()
	trail_core.width = 5.0
	trail_core.default_color = Color(1.0, 1.0, 1.0, 0.88)
	trail_core.antialiased = false
	trail_core.add_point(Vector2.ZERO)
	trail_core.add_point(Vector2.ZERO)
	root.add_child(trail_core)

	var glow := Polygon2D.new()
	glow.polygon = PackedVector2Array([
		Vector2(0.0, -24.0),
		Vector2(24.0, 0.0),
		Vector2(0.0, 24.0),
		Vector2(-24.0, 0.0),
	])
	glow.color = Color(color.r, color.g, color.b, 0.34)
	glow.scale = Vector2(1.7, 1.7)
	root.add_child(glow)

	var core := Polygon2D.new()
	core.polygon = PackedVector2Array([
		Vector2(0.0, -12.0),
		Vector2(12.0, 0.0),
		Vector2(0.0, 12.0),
		Vector2(-12.0, 0.0),
	])
	core.color = color.lightened(0.28)
	root.add_child(core)

	var sparks: Array[ColorRect] = []
	for _i: int in range(6):
		var spark := ColorRect.new()
		spark.size = Vector2(4.0, 4.0)
		spark.position = Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0))
		spark.color = Color(1.0, 1.0, 1.0, randf_range(0.55, 0.92))
		root.add_child(spark)
		sparks.append(spark)

	var travel: Vector2 = finish - start
	root.rotation = travel.angle() + PI * 0.5

	var tw := create_tween().set_parallel(true)
	tw.tween_property(root, "position", finish, 0.56).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	var update_projectile := func(progress: float) -> void:
		trail.set_point_position(1, Vector2(0.0, -travel.length() * progress))
		trail_core.set_point_position(1, Vector2(0.0, -travel.length() * progress))
		var pulse: float = 1.0 + sin(progress * TAU * 2.2) * 0.16
		core.scale = Vector2.ONE * pulse
		glow.scale = Vector2.ONE * (1.55 + progress * 0.65)
		for spark_value: Variant in sparks:
			var spark: ColorRect = spark_value as ColorRect
			if spark != null:
				var seed: float = float(spark.get_instance_id() % 17)
				spark.position = Vector2(
					sin(progress * TAU * 3.0 + seed) * 12.0,
					cos(progress * TAU * 2.0 + seed) * 12.0
				)
	tw.tween_method(update_projectile, 0.0, 1.0, 0.56)
	tw.tween_property(trail, "modulate:a", 0.12, 0.56)
	tw.tween_property(trail_core, "modulate:a", 0.10, 0.56)
	await tw.finished

	var burst := Node2D.new()
	burst.position = finish
	_canvas.add_child(burst)
	for radius: float in [20.0, 40.0, 58.0]:
		var ring := Line2D.new()
		ring.width = 4.0 if radius < 24.0 else 2.0
		ring.default_color = Color(color.r, color.g, color.b, 0.9)
		ring.closed = true
		ring.antialiased = false
		for i: int in range(12):
			var angle: float = (TAU * float(i)) / 12.0
			ring.add_point(Vector2.RIGHT.rotated(angle) * radius)
		burst.add_child(ring)
		var ring_tw := create_tween().set_parallel(true)
		ring_tw.tween_property(ring, "scale", Vector2.ONE * 1.65, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		ring_tw.tween_property(ring, "modulate:a", 0.0, 0.28)

	var flash := Polygon2D.new()
	flash.polygon = PackedVector2Array([
		Vector2(0.0, -22.0),
		Vector2(22.0, 0.0),
		Vector2(0.0, 22.0),
		Vector2(-22.0, 0.0),
	])
	flash.color = color.lightened(0.45)
	burst.add_child(flash)
	var burst_tw := create_tween().set_parallel(true)
	burst_tw.tween_property(flash, "scale", Vector2.ONE * 2.4, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	burst_tw.tween_property(flash, "modulate:a", 0.0, 0.22)
	await get_tree().create_timer(0.30).timeout
	root.queue_free()
	burst.queue_free()

func show_screen_projectile(screen_from: Vector2, screen_to: Vector2, color: Color) -> void:
	var root := Node2D.new()
	root.position = screen_from
	_canvas.add_child(root)

	var trail := Line2D.new()
	trail.width = 10.0
	trail.default_color = Color(color.r, color.g, color.b, 0.86)
	trail.antialiased = false
	trail.add_point(Vector2.ZERO)
	trail.add_point(Vector2.ZERO)
	root.add_child(trail)

	var trail_core := Line2D.new()
	trail_core.width = 4.0
	trail_core.default_color = Color(1.0, 1.0, 1.0, 0.88)
	trail_core.antialiased = false
	trail_core.add_point(Vector2.ZERO)
	trail_core.add_point(Vector2.ZERO)
	root.add_child(trail_core)

	var glow := Polygon2D.new()
	glow.polygon = PackedVector2Array([
		Vector2(0.0, -18.0),
		Vector2(18.0, 0.0),
		Vector2(0.0, 18.0),
		Vector2(-18.0, 0.0),
	])
	glow.color = Color(color.r, color.g, color.b, 0.30)
	glow.scale = Vector2(1.50, 1.50)
	root.add_child(glow)

	var core := Polygon2D.new()
	core.polygon = PackedVector2Array([
		Vector2(0.0, -10.0),
		Vector2(10.0, 0.0),
		Vector2(0.0, 10.0),
		Vector2(-10.0, 0.0),
	])
	core.color = color.lightened(0.32)
	root.add_child(core)

	var travel: Vector2 = screen_to - screen_from
	root.rotation = travel.angle() + PI * 0.5
	var tw := create_tween().set_parallel(true)
	tw.tween_property(root, "position", screen_to, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(
		func(progress: float) -> void:
			trail.set_point_position(1, Vector2(0.0, -travel.length() * progress))
			trail_core.set_point_position(1, Vector2(0.0, -travel.length() * progress))
			core.scale = Vector2.ONE * (1.0 + sin(progress * TAU * 2.4) * 0.14)
			glow.scale = Vector2.ONE * (1.35 + progress * 0.45),
		0.0, 1.0, 0.42
	)
	tw.tween_property(trail, "modulate:a", 0.18, 0.42)
	tw.tween_property(trail_core, "modulate:a", 0.12, 0.42)
	await tw.finished

	var burst := Node2D.new()
	burst.position = screen_to
	_canvas.add_child(burst)
	var flash := Polygon2D.new()
	flash.polygon = PackedVector2Array([
		Vector2(0.0, -18.0),
		Vector2(18.0, 0.0),
		Vector2(0.0, 18.0),
		Vector2(-18.0, 0.0),
	])
	flash.color = color.lightened(0.45)
	burst.add_child(flash)
	for radius: float in [16.0, 30.0, 42.0]:
		var ring := Line2D.new()
		ring.width = 3.0 if radius < 20.0 else 2.0
		ring.default_color = Color(color.r, color.g, color.b, 0.88)
		ring.closed = true
		ring.antialiased = false
		for i: int in range(12):
			var angle: float = (TAU * float(i)) / 12.0
			ring.add_point(Vector2.RIGHT.rotated(angle) * radius)
		burst.add_child(ring)
		var ring_tw := create_tween().set_parallel(true)
		ring_tw.tween_property(ring, "scale", Vector2.ONE * 1.58, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		ring_tw.tween_property(ring, "modulate:a", 0.0, 0.22)

	var flash_tw := create_tween().set_parallel(true)
	flash_tw.tween_property(flash, "scale", Vector2.ONE * 2.25, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	flash_tw.tween_property(flash, "modulate:a", 0.0, 0.18)
	await get_tree().create_timer(0.26).timeout
	root.queue_free()
	burst.queue_free()

func show_pixel_burst_world(
	world_pos: Vector3,
	color: Color,
	amount: int = 18,
	lifetime: float = 0.55,
	velocity_min: float = 60.0,
	velocity_max: float = 120.0,
	gravity_y: float = 220.0,
	scale_min: float = 0.35,
	scale_max: float = 0.75
) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	var screen_pos: Vector2 = cam.unproject_position(world_pos + Vector3(0.0, 1.05, 0.0))
	var particles := GPUParticles2D.new()
	particles.position = screen_pos
	particles.amount = amount
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.lifetime = lifetime
	particles.preprocess = 0.0
	particles.emitting = false
	particles.local_coords = false
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	process.spread = 180.0
	process.initial_velocity_min = velocity_min
	process.initial_velocity_max = velocity_max
	process.gravity = Vector3(0.0, gravity_y, 0.0)
	process.scale_min = scale_min
	process.scale_max = scale_max
	process.color = color
	particles.process_material = process
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(color)
	particles.texture = ImageTexture.create_from_image(img)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
	particles.material = mat
	_canvas.add_child(particles)
	particles.emitting = true
	await get_tree().create_timer(lifetime + 0.15).timeout
	if is_instance_valid(particles):
		particles.queue_free()

func show_critical_burst_world(world_pos: Vector3) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	var screen_pos: Vector2 = cam.unproject_position(world_pos + Vector3(0.0, 1.05, 0.0))

	# --- CPUParticles2D pixel squares ---
	var particles := CPUParticles2D.new()
	particles.position = screen_pos
	particles.amount = 12
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.lifetime = 0.8
	particles.preprocess = 0.0
	particles.emitting = false
	particles.local_coords = false
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 20.0
	particles.spread = 180.0
	particles.initial_velocity_min = 80.0
	particles.initial_velocity_max = 150.0
	particles.gravity = Vector2(0.0, 30.0)
	particles.scale_amount_min = 8.0
	particles.scale_amount_max = 16.0
	particles.texture = null
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	grad.add_point(0.5, Color(1.0, 0.78, 0.18, 0.8))
	grad.add_point(1.0, Color(1.0, 0.5, 0.0, 0.0))
	particles.color_ramp = grad
	_canvas.add_child(particles)
	particles.emitting = true
	await get_tree().create_timer(0.95).timeout
	if is_instance_valid(particles):
		particles.queue_free()

func show_super_critical_burst_world(world_pos: Vector3) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	var screen_pos: Vector2 = cam.unproject_position(world_pos + Vector3(0.0, 1.05, 0.0))

	var particles := CPUParticles2D.new()
	particles.position = screen_pos
	particles.amount = 22
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.lifetime = 0.95
	particles.preprocess = 0.0
	particles.emitting = false
	particles.local_coords = false
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 54.0
	particles.spread = 180.0
	particles.initial_velocity_min = 88.0
	particles.initial_velocity_max = 176.0
	particles.gravity = Vector2(0.0, 42.0)
	particles.scale_amount_min = 12.0
	particles.scale_amount_max = 24.0
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.94, 0.94, 1.0))
	grad.add_point(0.35, Color(1.0, 0.22, 0.22, 0.95))
	grad.add_point(0.75, Color(0.82, 0.06, 0.06, 0.52))
	grad.add_point(1.0, Color(0.42, 0.02, 0.02, 0.0))
	particles.color_ramp = grad
	_canvas.add_child(particles)
	particles.emitting = true

	show_pixel_burst_world(world_pos, Color(1.00, 0.12, 0.12, 0.98), 34, 0.84, 120.0, 248.0, 280.0, 1.65, 2.85)
	await get_tree().create_timer(1.10).timeout
	if is_instance_valid(particles):
		particles.queue_free()

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
			"super_critical":
				text        = "-%d!!" % amount
				color       = SUPER_CRIT_COLOR
				font_size   = 100
				punch_scale = 1.92
				hold_time   = 0.32
				float_dist  = 112.0
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
			"super_critical":
				text        = "-%d!!" % amount
				color       = SUPER_CRIT_COLOR
				font_size   = 116
				punch_scale = 2.0
				hold_time   = 0.58
				float_dist  = 170.0
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
	_style_runtime_label(shadow)
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
	_style_runtime_label(lbl)
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
	if type == "critical" or type == "super_critical":
		var tw_f: Tween = lbl.create_tween()
		var flash_color := Color(3.1, 1.25, 1.25, 1.0) if type == "super_critical" else Color(2.5, 2.5, 2.5, 1.0)
		tw_f.tween_property(lbl, "modulate", flash_color, 0.06)
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

func show_combat_hit_label(world_pos: Vector3, hit_index: int, hit_count: int, color: Color = Color(1.0, 0.96, 0.72)) -> void:
	show_world_text_label(
		world_pos,
		"GOLPE %d/%d" % [hit_index, hit_count],
		color,
		30,
		2.25
	)

func create_combat_health_bar(world_pos: Vector3, current_hp: int, max_hp: int, unit_name: String = "", unit_level: int = 1, unit_type: int = -1, owner_id: int = 0, current_exp: int = 0, required_exp: int = 0) -> Control:
	var panel_size := Vector2(260.0, 148.0)
	var bar_root := Control.new()
	bar_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_root.custom_minimum_size = panel_size
	_canvas.add_child(bar_root)
	var team_color: Color = GameData.get_player_color(owner_id)

	var team_tint := ColorRect.new()
	team_tint.name = "TeamTint"
	team_tint.position = Vector2(-4.0, -28.0)
	team_tint.size = Vector2(268.0, 166.0)
	team_tint.color = Color(team_color.r, team_color.g, team_color.b, 0.10)
	bar_root.add_child(team_tint)

	var team_frame := Panel.new()
	team_frame.name = "TeamFrame"
	team_frame.position = Vector2(-4.0, -28.0)
	team_frame.size = Vector2(268.0, 166.0)
	team_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var team_frame_style := StyleBoxFlat.new()
	team_frame_style.bg_color = Color(0.02, 0.03, 0.05, 0.22)
	team_frame_style.border_color = Color(team_color.r, team_color.g, team_color.b, 0.48)
	team_frame_style.set_border_width_all(2)
	team_frame_style.set_corner_radius_all(4)
	team_frame.add_theme_stylebox_override("panel", team_frame_style)
	bar_root.add_child(team_frame)

	var header_back := ColorRect.new()
	header_back.name = "HeaderBack"
	header_back.position = Vector2(-2.0, -26.0)
	header_back.size = Vector2(264.0, 22.0)
	header_back.color = Color(team_color.r, team_color.g, team_color.b, 0.12)
	bar_root.add_child(header_back)

	var header := HBoxContainer.new()
	header.name = "Header"
	header.position = Vector2(0.0, -24.0)
	header.size = Vector2(260.0, 22.0)
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 4)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_root.add_child(header)

	var name_icon := TextureRect.new()
	name_icon.name = "UnitIcon"
	name_icon.custom_minimum_size = Vector2(18.0, 18.0)
	name_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	name_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	name_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	name_icon.modulate = LEVEL_NAME_COLORS.get(unit_level, Color.WHITE)
	var icon_path: String = str(CLASS_ICON_PATHS.get(unit_type, ""))
	if icon_path != "":
		name_icon.texture = load(icon_path)
	header.add_child(name_icon)

	var name_label := Label.new()
	_style_runtime_label(name_label)
	name_label.name = "UnitName"
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", LEVEL_NAME_COLORS.get(unit_level, Color.WHITE))
	name_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.78))
	name_label.add_theme_constant_override("shadow_offset_x", 1)
	name_label.add_theme_constant_override("shadow_offset_y", 1)
	name_label.text = str(UNIT_TYPE_DISPLAY_NAMES.get(unit_type, unit_name))
	header.add_child(name_label)

	var back := ColorRect.new()
	back.name = "Back"
	back.position = Vector2.ZERO
	back.size = Vector2(260.0, 24.0)
	back.color = Color(0.03, 0.03, 0.03, 0.86)
	bar_root.add_child(back)

	var fill := ColorRect.new()
	fill.name = "Fill"
	fill.position = Vector2(3.0, 3.0)
	fill.size = Vector2(254.0, 18.0)
	bar_root.add_child(fill)

	var label := Label.new()
	_style_runtime_label(label)
	label.name = "Value"
	label.position = Vector2(0.0, 0.0)
	label.size = Vector2(260.0, 24.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.75))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	bar_root.add_child(label)

	var exp_back := ColorRect.new()
	exp_back.name = "ExpBack"
	exp_back.position = Vector2(0.0, 24.0)
	exp_back.size = Vector2(260.0, 8.0)
	exp_back.color = Color(0.07, 0.04, 0.10, 0.88)
	bar_root.add_child(exp_back)

	var exp_fill := ColorRect.new()
	exp_fill.name = "ExpFill"
	exp_fill.position = Vector2(3.0, 27.0)
	exp_fill.size = Vector2(0.0, 2.0)
	exp_fill.color = Color(0.84, 0.42, 1.0, 0.96)
	bar_root.add_child(exp_fill)

	var exp_label := Label.new()
	_style_runtime_label(exp_label)
	exp_label.name = "ExpValue"
	exp_label.position = Vector2(0.0, 31.0)
	exp_label.size = Vector2(260.0, 18.0)
	exp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	exp_label.add_theme_font_size_override("font_size", 12)
	exp_label.add_theme_color_override("font_color", Color(0.84, 0.42, 1.0, 0.96))
	exp_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.75))
	exp_label.add_theme_constant_override("shadow_offset_x", 1)
	exp_label.add_theme_constant_override("shadow_offset_y", 1)
	exp_label.text = "XP %d/%d" % [maxi(0, current_exp), maxi(0, required_exp)]
	bar_root.add_child(exp_label)

	var divider_top := ColorRect.new()
	divider_top.position = Vector2(8.0, 46.0)
	divider_top.size = Vector2(244.0, 1.0)
	divider_top.color = Color(1.0, 1.0, 1.0, 0.08)
	bar_root.add_child(divider_top)

	var matchup_back := Panel.new()
	matchup_back.name = "MatchupBack"
	matchup_back.position = Vector2(8.0, 54.0)
	matchup_back.size = Vector2(118.0, 18.0)
	matchup_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var matchup_back_style := StyleBoxFlat.new()
	matchup_back_style.bg_color = Color(0.05, 0.06, 0.08, 0.74)
	matchup_back_style.border_color = Color(1.0, 1.0, 1.0, 0.08)
	matchup_back_style.set_border_width_all(1)
	matchup_back_style.set_corner_radius_all(4)
	matchup_back.add_theme_stylebox_override("panel", matchup_back_style)
	bar_root.add_child(matchup_back)

	var matchup := Label.new()
	_style_runtime_label(matchup)
	matchup.name = "Matchup"
	matchup.position = Vector2(10.0, 55.0)
	matchup.size = Vector2(114.0, 18.0)
	matchup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	matchup.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	matchup.add_theme_font_size_override("font_size", 11)
	matchup.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.7))
	matchup.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.75))
	matchup.add_theme_constant_override("shadow_offset_x", 1)
	matchup.add_theme_constant_override("shadow_offset_y", 1)
	matchup.text = ""
	bar_root.add_child(matchup)

	var bonus_back := Panel.new()
	bonus_back.name = "BonusBack"
	bonus_back.position = Vector2(134.0, 54.0)
	bonus_back.size = Vector2(118.0, 18.0)
	bonus_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bonus_back_style := StyleBoxFlat.new()
	bonus_back_style.bg_color = Color(0.05, 0.06, 0.08, 0.74)
	bonus_back_style.border_color = Color(1.0, 1.0, 1.0, 0.08)
	bonus_back_style.set_border_width_all(1)
	bonus_back_style.set_corner_radius_all(4)
	bonus_back.add_theme_stylebox_override("panel", bonus_back_style)
	bar_root.add_child(bonus_back)

	var bonus_lbl := Label.new()
	_style_runtime_label(bonus_lbl)
	bonus_lbl.name = "BonusIcon"
	bonus_lbl.position = Vector2(136.0, 55.0)
	bonus_lbl.size = Vector2(114.0, 18.0)
	bonus_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bonus_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bonus_lbl.add_theme_font_size_override("font_size", 11)
	bonus_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.7))
	bonus_lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.80))
	bonus_lbl.add_theme_constant_override("shadow_offset_x", 1)
	bonus_lbl.add_theme_constant_override("shadow_offset_y", 1)
	bonus_lbl.text = ""
	bar_root.add_child(bonus_lbl)

	var divider_bottom := ColorRect.new()
	divider_bottom.position = Vector2(8.0, 80.0)
	divider_bottom.size = Vector2(244.0, 1.0)
	divider_bottom.color = Color(1.0, 1.0, 1.0, 0.08)
	bar_root.add_child(divider_bottom)

	var rolls_root := HBoxContainer.new()
	rolls_root.name = "Rolls"
	rolls_root.position = Vector2(0.0, 92.0)
	rolls_root.size = Vector2(260.0, 50.0)
	rolls_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rolls_root.alignment = BoxContainer.ALIGNMENT_CENTER
	rolls_root.add_theme_constant_override("separation", 6)
	bar_root.add_child(rolls_root)

	update_combat_health_bar(bar_root, world_pos, current_hp, max_hp, false)
	set_combat_health_bar_experience(bar_root, current_exp, required_exp)
	return bar_root

func update_combat_health_bar(bar_root: Control, world_pos: Vector3, current_hp: int, max_hp: int, animate: bool = true) -> void:
	if bar_root == null or not is_instance_valid(bar_root):
		return
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return

	var screen_pos: Vector2 = _combat_bar_screen_pos(cam, world_pos)
	bar_root.position = screen_pos - Vector2(130.0, 30.0)

	var ratio: float = 0.0 if max_hp <= 0 else clampf(float(current_hp) / float(max_hp), 0.0, 1.0)
	var fill: ColorRect = bar_root.get_node_or_null("Fill") as ColorRect
	var label: Label = bar_root.get_node_or_null("Value") as Label
	if fill != null:
		fill.color = _combat_health_color(ratio)
		var target_width: float = maxf(2.0, 254.0 * ratio)
		if animate:
			var tw := fill.create_tween()
			tw.tween_property(fill, "size:x", target_width, 0.18) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		else:
			fill.size.x = target_width
	if label != null:
		label.text = "%d / %d" % [current_hp, max_hp]

func set_combat_health_bar_experience(bar_root: Control, current_exp: int, required_exp: int) -> void:
	if bar_root == null or not is_instance_valid(bar_root):
		return
	var exp_label: Label = bar_root.get_node_or_null("ExpValue") as Label
	var exp_fill: ColorRect = bar_root.get_node_or_null("ExpFill") as ColorRect
	if exp_label == null:
		return
	exp_label.text = "XP %d/%d" % [maxi(0, current_exp), maxi(0, required_exp)]
	if exp_fill != null:
		var ratio: float = 0.0 if required_exp <= 0 else clampf(float(current_exp) / float(required_exp), 0.0, 1.0)
		exp_fill.size.x = 254.0 * ratio

func set_combat_health_bar_matchup(bar_root: Control, state: int) -> void:
	if bar_root == null or not is_instance_valid(bar_root):
		return
	var matchup: Label = bar_root.get_node_or_null("Matchup") as Label
	if matchup == null:
		return
	match state:
		1:
			matchup.text = "▲ VENTAJA"
			matchup.add_theme_color_override("font_color", Color(0.36, 1.0, 0.42, 1.0))
		-1:
			matchup.text = "▼ DESVENTAJA"
			matchup.add_theme_color_override("font_color", Color(1.0, 0.34, 0.34, 1.0))
		_:
			matchup.text = ""
			matchup.add_theme_color_override("font_color", Color.WHITE)

func set_combat_bonus_icon(bar_root: Control, is_night: bool, faction_name: String) -> void:
	if bar_root == null or not is_instance_valid(bar_root):
		return
	var bonus_lbl: Label = bar_root.get_node_or_null("BonusIcon") as Label
	if bonus_lbl == null:
		bonus_lbl = Label.new()
		_style_runtime_label(bonus_lbl)
		bonus_lbl.name = "BonusIcon"
		bonus_lbl.position = Vector2(0.0, 68.0)
		bonus_lbl.size = Vector2(260.0, 16.0)
		bonus_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bonus_lbl.add_theme_font_size_override("font_size", 12)
		bonus_lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.80))
		bonus_lbl.add_theme_constant_override("shadow_offset_x", 1)
		bonus_lbl.add_theme_constant_override("shadow_offset_y", 1)
		bar_root.add_child(bonus_lbl)
	var icon: String = "☾" if is_night else "☀"
	var col: Color = Color(0.60, 0.82, 1.0) if is_night else Color(1.0, 0.88, 0.28)
	bonus_lbl.text = "%s %s +15%% crít" % [icon, faction_name]
	bonus_lbl.add_theme_color_override("font_color", col)

func remove_combat_health_bar(bar_root: Control) -> void:
	if bar_root != null and is_instance_valid(bar_root):
		bar_root.queue_free()

func set_combat_health_bar_matchup_badge(bar_root: Control, state: int) -> void:
	if bar_root == null or not is_instance_valid(bar_root):
		return
	var matchup: Label = bar_root.get_node_or_null("Matchup") as Label
	if matchup == null:
		return
	match state:
		1:
			matchup.text = "VENTAJA"
			matchup.add_theme_color_override("font_color", Color(0.36, 1.0, 0.42, 1.0))
		-1:
			matchup.text = "DESVENTAJA"
			matchup.add_theme_color_override("font_color", Color(1.0, 0.34, 0.34, 1.0))
		_:
			matchup.text = "SIN VENTAJA"
			matchup.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.62))

func set_combat_health_bar_bonus_badge(bar_root: Control, is_night: bool, faction_name: String) -> void:
	if bar_root == null or not is_instance_valid(bar_root):
		return
	var bonus_lbl: Label = bar_root.get_node_or_null("BonusIcon") as Label
	if bonus_lbl == null:
		return
	var icon: String = "☾" if is_night else "☀"
	var col: Color = Color(0.60, 0.82, 1.0) if is_night else Color(1.0, 0.88, 0.28)
	var short_name: String = faction_name.substr(0, 8) if faction_name.length() > 8 else faction_name
	bonus_lbl.text = "%s %s CRIT+" % [icon, short_name]
	bonus_lbl.add_theme_color_override("font_color", col)

func show_combat_health_bar_rolls(bar_root: Control, rolls: Array) -> void:
	if bar_root == null or not is_instance_valid(bar_root):
		return
	var rolls_root: Control = bar_root.get_node_or_null("Rolls") as Control
	if rolls_root == null:
		return

	for i: int in range(rolls.size()):
		var roll: Dictionary = rolls[i]
		var die_color: int = int(roll.get("color", 0))
		var result: int = int(roll.get("value", 0))
		var is_critical: bool = bool(roll.get("critical", false))
		var is_super_critical: bool = bool(roll.get("super_critical", false))
		var die_slot := CenterContainer.new()
		die_slot.custom_minimum_size = Vector2(34.0, 34.0)
		die_slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		die_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rolls_root.add_child(die_slot)

		var die_panel := Panel.new()
		die_panel.custom_minimum_size = Vector2(30.0, 30.0)
		die_panel.scale = Vector2(0.7, 0.7)
		die_panel.modulate.a = 0.0
		var style := StyleBoxFlat.new()
		style.bg_color = DICE_COLORS[clampi(die_color, 0, DICE_COLORS.size() - 1)]
		style.set_corner_radius_all(6)
		style.set_border_width_all(3)
		if is_super_critical:
			style.border_color = SUPER_CRIT_COLOR
		elif is_critical:
			style.border_color = Color(1.0, 0.82, 0.22, 1.0)
		else:
			style.border_color = Color(1.0, 1.0, 1.0, 0.60)
		die_panel.add_theme_stylebox_override("panel", style)
		die_slot.add_child(die_panel)

		if is_critical:
			var crit_glow := ColorRect.new()
			crit_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
			crit_glow.position = Vector2(-2.0, -2.0)
			crit_glow.size = Vector2(34.0, 34.0)
			crit_glow.color = Color(0.92, 0.14, 0.10, 0.38) if is_super_critical else Color(0.92, 0.14, 0.10, 0.24)
			die_panel.add_child(crit_glow)
			die_panel.move_child(crit_glow, 0)
		if is_super_critical:
			_spawn_super_crit_die_motes(die_panel)

		var value := Label.new()
		_style_runtime_label(value)
		value.text = str(result)
		value.set_anchors_preset(Control.PRESET_FULL_RECT)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		value.add_theme_font_size_override("font_size", 18)
		value.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
		value.add_theme_constant_override("shadow_offset_x", 1)
		value.add_theme_constant_override("shadow_offset_y", 1)
		if is_super_critical:
			value.add_theme_color_override("font_color", SUPER_CRIT_VALUE_COLOR)
		elif is_critical:
			value.add_theme_color_override("font_color", Color(1.0, 0.90, 0.68))
		else:
			value.add_theme_color_override("font_color", Color.WHITE)
		die_panel.add_child(value)

		var shine := ColorRect.new()
		shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shine.position = Vector2(4.0, 4.0)
		shine.size = Vector2(10.0, 4.0)
		shine.color = Color(1.0, 0.20, 0.20, 0.34) if is_super_critical else (Color(1.0, 0.84, 0.52, 0.24) if is_critical else Color(1.0, 1.0, 1.0, 0.18))
		die_panel.add_child(shine)

		var tw := die_panel.create_tween().set_parallel(true)
		tw.tween_property(die_panel, "scale", Vector2(1.18, 1.18) if is_super_critical else (Vector2(1.08, 1.08) if is_critical else Vector2.ONE), 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(die_panel, "modulate:a", 1.0, 0.08)
		await tw.finished

func clear_combat_health_bar_rolls(bar_root: Control) -> void:
	if bar_root == null or not is_instance_valid(bar_root):
		return
	var rolls_root: Control = bar_root.get_node_or_null("Rolls") as Control
	if rolls_root == null:
		return
	for child: Node in rolls_root.get_children():
		child.queue_free()

func dim_combat_health_bar_rolls(bar_root: Control) -> void:
	if bar_root == null or not is_instance_valid(bar_root):
		return
	var rolls_root: Control = bar_root.get_node_or_null("Rolls") as Control
	if rolls_root == null:
		return
	for child: Node in rolls_root.get_children():
		var die_panel: Panel = _extract_die_panel(child)
		if die_panel != null:
			_set_die_panel_visual_state(die_panel, false)

func highlight_combat_health_bar_rolls(bar_root: Control, start_index: int, count: int) -> void:
	if bar_root == null or not is_instance_valid(bar_root):
		return
	var rolls_root: Control = bar_root.get_node_or_null("Rolls") as Control
	if rolls_root == null:
		return
	var end_index: int = start_index + maxi(0, count)
	var current_index: int = 0
	for child: Node in rolls_root.get_children():
		var die_panel: Panel = _extract_die_panel(child)
		if die_panel == null:
			continue
		var is_active: bool = current_index >= start_index and current_index < end_index
		_set_die_panel_visual_state(die_panel, is_active)
		current_index += 1

func _combat_health_color(ratio: float) -> Color:
	if ratio <= 0.25:
		return Color(1.00, 0.24, 0.24, 0.96)
	if ratio <= 0.55:
		return Color(0.96, 0.36, 0.30, 0.96)
	return Color(0.90, 0.18, 0.18, 0.96)

func _combat_bar_screen_pos(cam: Camera3D, world_pos: Vector3) -> Vector2:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var anchor_heights: Array[float] = [0.20, 0.12, 0.05, 0.0]
	var projected_base: Vector3 = Vector3(world_pos.x, 0.0, world_pos.z)
	var projected: Vector2 = viewport_size * 0.5

	for height: float in anchor_heights:
		var sample_pos: Vector3 = projected_base + Vector3(0.0, height, 0.0)
		if cam.is_position_behind(sample_pos):
			continue
		projected = cam.unproject_position(sample_pos)
		break

	projected += Vector2(0.0, 108.0)

	projected.x = clampf(projected.x, 78.0, viewport_size.x - 78.0)
	projected.y = clampf(projected.y, 120.0, viewport_size.y - 70.0)
	return projected

func show_screen_text_label(screen_pos: Vector2, text: String, color: Color, font_size: int = 56) -> void:
	var w: float = 320.0
	var base_x: float = screen_pos.x - w * 0.5
	var shadow := Label.new()
	_style_runtime_label(shadow)
	shadow.text = text
	shadow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shadow.custom_minimum_size = Vector2(w, 0.0)
	shadow.position = Vector2(base_x + 2.0, screen_pos.y + 3.0)
	shadow.scale = Vector2.ZERO
	shadow.add_theme_font_size_override("font_size", font_size)
	shadow.add_theme_color_override("font_color", Color(0.0, 0.0, 0.0, 0.78))
	_canvas.add_child(shadow)

	var lbl := Label.new()
	_style_runtime_label(lbl)
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
	_style_runtime_label(shadow)
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
	_style_runtime_label(lbl)
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
	_style_runtime_label(lbl)
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
	Color(0.76, 0.50, 0.26),
	Color(0.80, 0.82, 0.88),
	Color(1.00, 0.84, 0.24),
	Color(0.16, 0.58, 0.36),
	Color(0.28, 0.88, 1.00),
]

const DICE_LABELS: Array[String] = ["Br", "Pl", "Or", "Pt", "Di"]
const COMBAT_DIE_ROLL_STEPS := 7
const COMBAT_DIE_ROLL_STEP_TIME := 0.03
const COMBAT_DIE_REVEAL_BOUNCE := 0.06
const COMBAT_DIE_REVEAL_SETTLE := 0.08
const COMBAT_DIE_APPEAR_TIME := 0.075
const COMBAT_DIE_APPEAR_STAGGER := 0.024
const COMBAT_DIE_CRIT_SHIFT_TIME := 0.075
const COMBAT_DIE_CRIT_FLASH_TIME := 0.12
const SUPER_CRIT_COLOR := Color(1.00, 0.10, 0.10, 1.0)
const SUPER_CRIT_VALUE_COLOR := Color(1.00, 0.88, 0.88, 1.0)

func show_combat_health_bar_roll(bar_root: Control, roll: Dictionary) -> void:
	if bar_root == null or not is_instance_valid(bar_root):
		return
	var rolls_root: Control = bar_root.get_node_or_null("Rolls") as Control
	if rolls_root == null:
		return
	var die_panel: Panel = _append_combat_roll_die(rolls_root, roll)
	if die_panel == null:
		return

	var value: Label = die_panel.get_node_or_null("Value") as Label
	if value == null:
		return

	var die_color: int = int(roll.get("color", 0))
	var result: int = int(roll.get("value", 0))
	var is_critical: bool = bool(roll.get("critical", false))
	var is_super_critical: bool = bool(roll.get("super_critical", false))
	var crit_display_value: int = int(roll.get("display_value", result))
	var faces: Array = Unit.DICE.get(die_color, [0, 1, 2, 3])

	AudioManager.play_dice_roll()
	for _i: int in range(COMBAT_DIE_ROLL_STEPS):
		value.text = str(faces[randi() % faces.size()])
		await get_tree().create_timer(COMBAT_DIE_ROLL_STEP_TIME).timeout

	value.text = str(result)
	AudioManager.play_dice_reveal()
	var pulse_tw := die_panel.create_tween().set_parallel(true)
	pulse_tw.tween_property(die_panel, "scale", Vector2(1.20, 1.20) if is_super_critical else Vector2(1.08, 1.08), COMBAT_DIE_REVEAL_BOUNCE).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pulse_tw.tween_property(die_panel, "modulate", Color(1.18, 1.18, 1.18, 1.0), COMBAT_DIE_REVEAL_BOUNCE)
	pulse_tw.tween_property(die_panel, "scale", Vector2.ONE, COMBAT_DIE_REVEAL_SETTLE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pulse_tw.tween_property(die_panel, "modulate", Color.WHITE, COMBAT_DIE_REVEAL_SETTLE)

	if is_critical:
		if not is_super_critical:
			AudioManager.play_dice_critical()
		var crit_glow: ColorRect = die_panel.get_node_or_null("CritGlow") as ColorRect
		if crit_glow != null:
			var glow_tw := crit_glow.create_tween()
			glow_tw.tween_property(crit_glow, "color", Color(1.0, 0.18, 0.18, 0.62) if is_super_critical else Color(1.0, 0.86, 0.36, 0.42), 0.06)
			glow_tw.tween_property(crit_glow, "color", Color(1.0, 0.16, 0.16, 0.0) if is_super_critical else Color(1.0, 0.86, 0.36, 0.0), 0.12)
		await _animate_critical_die_upgrade(die_panel, value, result, crit_display_value)

func show_combat_health_bar_roll_batch(bar_root: Control, rolls: Array) -> void:
	if bar_root == null or not is_instance_valid(bar_root):
		return
	var rolls_root: Control = bar_root.get_node_or_null("Rolls") as Control
	if rolls_root == null:
		return

	var die_panels: Array[Panel] = []
	var value_labels: Array[Label] = []
	var critical_flags: Array[bool] = []
	var die_faces: Array[Array] = []
	var final_values: Array[int] = []
	var crit_display_values: Array[int] = []

	for roll: Dictionary in rolls:
		var die_panel: Panel = _append_combat_roll_die(rolls_root, roll)
		if die_panel == null:
			continue
		var value: Label = die_panel.get_node_or_null("Value") as Label
		if value == null:
			continue
		die_panels.append(die_panel)
		value_labels.append(value)
		critical_flags.append(bool(roll.get("critical", false)))
		die_faces.append(Unit.DICE.get(int(roll.get("color", 0)), [0, 1, 2, 3]))
		var final_value: int = int(roll.get("value", 0))
		final_values.append(final_value)
		crit_display_values.append(int(roll.get("display_value", final_value)))

	if die_panels.is_empty():
		return

	for i: int in range(die_panels.size()):
		var die_panel: Panel = die_panels[i]
		var intro_tw := die_panel.create_tween().set_parallel(true)
		intro_tw.tween_property(die_panel, "position:y", 0.0, COMBAT_DIE_APPEAR_TIME).set_delay(float(i) * COMBAT_DIE_APPEAR_STAGGER).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		intro_tw.tween_property(die_panel, "scale", Vector2.ONE, COMBAT_DIE_APPEAR_TIME).set_delay(float(i) * COMBAT_DIE_APPEAR_STAGGER).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		intro_tw.tween_property(die_panel, "modulate:a", 1.0, COMBAT_DIE_APPEAR_TIME * 0.9).set_delay(float(i) * COMBAT_DIE_APPEAR_STAGGER)
	await get_tree().create_timer(COMBAT_DIE_APPEAR_TIME + float(maxi(0, die_panels.size() - 1)) * COMBAT_DIE_APPEAR_STAGGER).timeout

	AudioManager.play_dice_roll()
	for _step: int in range(COMBAT_DIE_ROLL_STEPS):
		for i: int in range(value_labels.size()):
			var faces: Array = die_faces[i]
			value_labels[i].text = str(faces[randi() % faces.size()])
		await get_tree().create_timer(COMBAT_DIE_ROLL_STEP_TIME).timeout

	AudioManager.play_dice_reveal()
	for i: int in range(value_labels.size()):
		value_labels[i].text = str(final_values[i])
		var die_panel: Panel = die_panels[i]
		var pulse_tw := die_panel.create_tween().set_parallel(true)
		pulse_tw.tween_property(die_panel, "scale", Vector2(1.08, 1.08), COMBAT_DIE_REVEAL_BOUNCE).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pulse_tw.tween_property(die_panel, "modulate", Color(1.18, 1.18, 1.18, 1.0), COMBAT_DIE_REVEAL_BOUNCE)
		pulse_tw.tween_property(die_panel, "scale", Vector2.ONE, COMBAT_DIE_REVEAL_SETTLE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		pulse_tw.tween_property(die_panel, "modulate", Color.WHITE, COMBAT_DIE_REVEAL_SETTLE)

		var is_super_critical: bool = bool((rolls[i] as Dictionary).get("super_critical", false))
		if critical_flags[i]:
			if not is_super_critical:
				AudioManager.play_dice_critical()
			var crit_glow: ColorRect = die_panel.get_node_or_null("CritGlow") as ColorRect
			if crit_glow != null:
				var glow_tw := crit_glow.create_tween()
				glow_tw.tween_property(crit_glow, "color", Color(1.0, 0.18, 0.18, 0.62) if is_super_critical else Color(1.0, 0.86, 0.36, 0.42), 0.06)
				glow_tw.tween_property(crit_glow, "color", Color(1.0, 0.16, 0.16, 0.0) if is_super_critical else Color(1.0, 0.86, 0.36, 0.0), 0.12)
			await _animate_critical_die_upgrade(die_panel, value_labels[i], final_values[i], crit_display_values[i])


func _append_combat_roll_die(rolls_root: Control, roll: Dictionary) -> Panel:
	var die_color: int = int(roll.get("color", 0))
	var is_critical: bool = bool(roll.get("critical", false))
	var is_super_critical: bool = bool(roll.get("super_critical", false))

	var die_slot := CenterContainer.new()
	die_slot.custom_minimum_size = Vector2(34.0, 34.0)
	die_slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	die_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rolls_root.add_child(die_slot)

	var die_panel := Panel.new()
	die_panel.custom_minimum_size = Vector2(30.0, 30.0)
	die_panel.scale = Vector2(0.7, 0.7)
	die_panel.modulate.a = 0.0
	die_panel.position = Vector2(0.0, 5.0)
	var style := StyleBoxFlat.new()
	var base_color: Color = DICE_COLORS[clampi(die_color, 0, DICE_COLORS.size() - 1)]
	var tinted_color: Color = base_color.lerp(Color(0.62, 0.08, 0.08, 1.0), 0.32) if is_super_critical else base_color
	var base_border: Color = SUPER_CRIT_COLOR if is_super_critical else (Color(1.0, 0.82, 0.22, 1.0) if is_critical else Color(1.0, 1.0, 1.0, 0.60))
	style.bg_color = tinted_color
	style.set_corner_radius_all(6)
	style.set_border_width_all(3)
	style.border_color = base_border
	die_panel.add_theme_stylebox_override("panel", style)
	die_panel.set_meta("base_color", tinted_color)
	die_panel.set_meta("base_border_color", base_border)
	die_panel.set_meta("is_critical", is_critical)
	die_panel.set_meta("is_super_critical", is_super_critical)
	die_slot.add_child(die_panel)

	var crit_glow := ColorRect.new()
	crit_glow.name = "CritGlow"
	crit_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crit_glow.position = Vector2(-2.0, -2.0)
	crit_glow.size = Vector2(34.0, 34.0)
	crit_glow.color = Color(1.0, 0.18, 0.18, 0.0) if is_super_critical else Color(1.0, 0.86, 0.36, 0.0)
	die_panel.add_child(crit_glow)
	die_panel.move_child(crit_glow, 0)
	if is_super_critical:
		_spawn_super_crit_die_motes(die_panel)

	var value := Label.new()
	value.name = "Value"
	_style_runtime_label(value)
	value.text = "?"
	value.set_anchors_preset(Control.PRESET_FULL_RECT)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.add_theme_font_size_override("font_size", 18)
	value.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	value.add_theme_constant_override("shadow_offset_x", 1)
	value.add_theme_constant_override("shadow_offset_y", 1)
	value.add_theme_color_override("font_color", SUPER_CRIT_VALUE_COLOR if is_super_critical else (Color(1.0, 0.90, 0.68) if is_critical else Color.WHITE))
	die_panel.add_child(value)

	var shine := ColorRect.new()
	shine.name = "Shine"
	shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shine.position = Vector2(4.0, 4.0)
	shine.size = Vector2(10.0, 4.0)
	shine.color = Color(1.0, 0.22, 0.22, 0.32) if is_super_critical else (Color(1.0, 0.84, 0.52, 0.24) if is_critical else Color(1.0, 1.0, 1.0, 0.18))
	die_panel.add_child(shine)

	return die_panel

func _animate_critical_die_upgrade(die_panel: Panel, value_label: Label, base_value: int, upgraded_value: int) -> void:
	if die_panel == null or value_label == null:
		return
	if upgraded_value <= base_value:
		return
	var crit_glow: ColorRect = die_panel.get_node_or_null("CritGlow") as ColorRect
	var is_super_critical: bool = bool(die_panel.get_meta("is_super_critical", false))
	var original_text: String = str(base_value)
	var upgraded_text: String = str(upgraded_value)
	await get_tree().create_timer(0.035).timeout
	var shrink_tw := value_label.create_tween().set_parallel(true)
	shrink_tw.tween_property(value_label, "scale", Vector2(0.78, 0.78), COMBAT_DIE_CRIT_SHIFT_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	shrink_tw.tween_property(value_label, "modulate", Color(1.0, 0.44, 0.44, 0.62) if is_super_critical else Color(1.0, 0.80, 0.46, 0.55), COMBAT_DIE_CRIT_SHIFT_TIME)
	if crit_glow != null:
		shrink_tw.tween_property(crit_glow, "color", Color(1.0, 0.14, 0.14, 0.68) if is_super_critical else Color(1.0, 0.78, 0.18, 0.58), COMBAT_DIE_CRIT_SHIFT_TIME)
	await shrink_tw.finished
	value_label.text = upgraded_text
	var pop_tw := value_label.create_tween().set_parallel(true)
	pop_tw.tween_property(value_label, "scale", Vector2(1.52, 1.52) if is_super_critical else Vector2(1.36, 1.36), COMBAT_DIE_REVEAL_BOUNCE).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop_tw.tween_property(value_label, "modulate", Color(1.64, 0.68, 0.68, 1.0) if is_super_critical else Color(1.45, 1.12, 0.58, 1.0), COMBAT_DIE_REVEAL_BOUNCE)
	pop_tw.tween_property(value_label, "scale", Vector2.ONE, COMBAT_DIE_REVEAL_SETTLE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pop_tw.tween_property(value_label, "modulate", Color.WHITE, COMBAT_DIE_REVEAL_SETTLE)
	if crit_glow != null:
		pop_tw.tween_property(crit_glow, "color", Color(1.0, 0.12, 0.12, 0.82) if is_super_critical else Color(1.0, 0.88, 0.30, 0.72), COMBAT_DIE_REVEAL_BOUNCE)
		pop_tw.tween_property(crit_glow, "color", Color(1.0, 0.10, 0.10, 0.22) if is_super_critical else Color(1.0, 0.86, 0.36, 0.16), COMBAT_DIE_CRIT_FLASH_TIME)
	await pop_tw.finished
	if value_label.text == original_text:
		value_label.text = upgraded_text


func _spawn_super_crit_die_motes(die_panel: Panel) -> void:
	if die_panel == null:
		return
	var motes := Control.new()
	motes.name = "SuperCritMotes"
	motes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	motes.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	die_panel.add_child(motes)
	for i: int in range(4):
		var mote := ColorRect.new()
		mote.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mote.color = Color(1.0, 0.18, 0.18, 0.78)
		mote.position = Vector2(6.0 + float(i) * 5.0, 20.0 - float(i % 2) * 6.0)
		mote.size = Vector2(3.0, 3.0)
		motes.add_child(mote)
		var tw := mote.create_tween().set_loops()
		tw.tween_property(mote, "position:y", mote.position.y - 4.0, 0.22 + float(i) * 0.03).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(mote, "modulate:a", 0.10, 0.22 + float(i) * 0.03)
		tw.tween_property(mote, "position:y", mote.position.y, 0.18 + float(i) * 0.02).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_property(mote, "modulate:a", 0.78, 0.18 + float(i) * 0.02)

func _extract_die_panel(node: Node) -> Panel:
	if node is Panel:
		return node as Panel
	if node is CenterContainer and node.get_child_count() > 0 and node.get_child(0) is Panel:
		return node.get_child(0) as Panel
	return null

func _set_die_panel_visual_state(die_panel: Panel, is_active: bool) -> void:
	if die_panel == null or not is_instance_valid(die_panel):
		return
	var style: StyleBoxFlat = die_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style == null:
		return
	var style_copy := style.duplicate() as StyleBoxFlat
	var base_color: Color = die_panel.get_meta("base_color", Color.WHITE)
	var base_border: Color = die_panel.get_meta("base_border_color", Color.WHITE)
	var is_critical: bool = bool(die_panel.get_meta("is_critical", false))
	var is_super_critical: bool = bool(die_panel.get_meta("is_super_critical", false))
	if is_active:
		style_copy.bg_color = base_color
		style_copy.border_color = base_border
	else:
		var gray_value: float = base_color.get_luminance()
		style_copy.bg_color = Color(gray_value, gray_value, gray_value, 0.55)
		style_copy.border_color = base_border if is_critical else Color(0.62, 0.62, 0.62, 0.75)
	die_panel.add_theme_stylebox_override("panel", style_copy)

	var value: Label = die_panel.get_node_or_null("Value") as Label
	if value != null:
		if is_active:
			value.add_theme_color_override("font_color", SUPER_CRIT_VALUE_COLOR if is_super_critical else (Color(1.0, 0.90, 0.68) if is_critical else Color.WHITE))
		else:
			value.add_theme_color_override("font_color", Color(0.72, 0.72, 0.72, 0.92))

	var shine: ColorRect = die_panel.get_node_or_null("Shine") as ColorRect
	if shine != null:
		shine.color = Color(1.0, 0.22, 0.22, 0.32) if is_active and is_super_critical else (Color(1.0, 0.84, 0.52, 0.24) if is_active and is_critical else (Color(1.0, 1.0, 1.0, 0.18) if is_active else Color(0.8, 0.8, 0.8, 0.08)))

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
	_style_runtime_label(lbl_color)
	lbl_color.text = DICE_LABELS[clampi(die_color, 0, DICE_LABELS.size() - 1)]
	lbl_color.position = Vector2(4.0, 2.0)
	lbl_color.add_theme_font_size_override("font_size", 11)
	lbl_color.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.85))
	panel.add_child(lbl_color)

	# Main result label (centered)
	var lbl_val: Label = Label.new()
	_style_runtime_label(lbl_val)
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

func show_combat_roll_panel_3d(world_from: Vector3, world_to: Vector3, rolls: Array,
		hit_index: int, hit_count: int, total: int, damage: int) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return

	var screen_from: Vector2 = cam.unproject_position(world_from + Vector3(0.0, 2.0, 0.0))
	var screen_to: Vector2 = cam.unproject_position(world_to + Vector3(0.0, 2.0, 0.0))
	var center: Vector2 = screen_from.lerp(screen_to, 0.5)
	var dice_count: int = maxi(1, rolls.size())
	var panel_width: float = maxf(280.0, 120.0 + dice_count * 94.0)
	var panel_height: float = 176.0
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	center.y += 96.0
	center.x = clampf(center.x, panel_width * 0.5 + 20.0, viewport_size.x - panel_width * 0.5 - 20.0)
	center.y = clampf(center.y, panel_height * 0.5 + 20.0, viewport_size.y - panel_height * 0.5 - 20.0)

	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.add_child(root)

	var shadow := Panel.new()
	shadow.size = Vector2(panel_width, panel_height)
	shadow.position = center - shadow.size * 0.5 + Vector2(6.0, 8.0)
	shadow.modulate = Color(0.0, 0.0, 0.0, 0.38)
	var shadow_style := StyleBoxFlat.new()
	shadow_style.bg_color = Color(0.0, 0.0, 0.0, 0.86)
	shadow_style.set_corner_radius_all(16)
	shadow.add_theme_stylebox_override("panel", shadow_style)
	root.add_child(shadow)

	var panel := Panel.new()
	panel.size = Vector2(panel_width, panel_height)
	panel.position = center - panel.size * 0.5
	panel.scale = Vector2(0.92, 0.92)
	panel.modulate.a = 0.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.08, 0.96)
	style.border_color = Color(0.50, 0.82, 1.0, 0.70)
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)

	var title := Label.new()
	_style_runtime_label(title)
	title.text = "Golpe %d/%d" % [hit_index, hit_count]
	title.position = Vector2(0.0, 10.0)
	title.size = Vector2(panel_width, 28.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.92, 0.97, 1.0))
	panel.add_child(title)

	var subtitle := Label.new()
	_style_runtime_label(subtitle)
	subtitle.text = "Tirada de dados"
	subtitle.position = Vector2(0.0, 34.0)
	subtitle.size = Vector2(panel_width, 22.0)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.70, 0.82, 0.92, 0.92))
	panel.add_child(subtitle)

	var dice_y: float = 64.0
	var die_size: Vector2 = Vector2(74.0, 74.0)
	var spacing: float = 16.0
	var row_width: float = float(dice_count) * die_size.x + float(dice_count - 1) * spacing
	var start_x: float = (panel_width - row_width) * 0.5
	var value_labels: Array[Label] = []
	var die_panels: Array[Panel] = []

	for i: int in range(dice_count):
		var die_panel := Panel.new()
		die_panel.size = die_size
		die_panel.position = Vector2(start_x + float(i) * (die_size.x + spacing), dice_y)
		die_panel.scale = Vector2(0.5, 0.5)
		var die_style := StyleBoxFlat.new()
		var die_color: int = 0
		if i < rolls.size():
			var roll: Dictionary = rolls[i]
			die_color = int(roll.get("color", 0))
		die_style.bg_color = DICE_COLORS[clampi(die_color, 0, DICE_COLORS.size() - 1)]
		die_style.border_color = Color(1.0, 1.0, 1.0, 0.72)
		die_style.set_border_width_all(3)
		die_style.set_corner_radius_all(14)
		die_panel.add_theme_stylebox_override("panel", die_style)
		panel.add_child(die_panel)
		die_panels.append(die_panel)

		var die_tag := Label.new()
		_style_runtime_label(die_tag)
		die_tag.text = DICE_LABELS[clampi(die_color, 0, DICE_LABELS.size() - 1)]
		die_tag.position = Vector2(7.0, 4.0)
		die_tag.size = Vector2(24.0, 16.0)
		die_tag.add_theme_font_size_override("font_size", 13)
		die_tag.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.92))
		die_panel.add_child(die_tag)

		var die_value := Label.new()
		_style_runtime_label(die_value)
		die_value.text = "?"
		die_value.set_anchors_preset(Control.PRESET_FULL_RECT)
		die_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		die_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		die_value.add_theme_font_size_override("font_size", 34)
		die_value.add_theme_color_override("font_color", Color.WHITE)
		die_panel.add_child(die_value)
		value_labels.append(die_value)

	var total_label := Label.new()
	_style_runtime_label(total_label)
	total_label.text = "Total %d" % total
	total_label.position = Vector2(28.0, 146.0)
	total_label.size = Vector2(panel_width * 0.5 - 28.0, 22.0)
	total_label.add_theme_font_size_override("font_size", 16)
	total_label.add_theme_color_override("font_color", Color(0.82, 0.90, 1.0))
	panel.add_child(total_label)

	var damage_label := Label.new()
	_style_runtime_label(damage_label)
	if damage > 0:
		damage_label.text = "Daño %d" % damage
		damage_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.58))
	else:
		damage_label.text = "Sin daño"
		damage_label.add_theme_color_override("font_color", Color(0.76, 0.82, 0.90))
	damage_label.position = Vector2(panel_width * 0.5, 146.0)
	damage_label.size = Vector2(panel_width * 0.5 - 28.0, 22.0)
	damage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	damage_label.add_theme_font_size_override("font_size", 16)
	panel.add_child(damage_label)

	var intro_tw := panel.create_tween().set_parallel(true)
	intro_tw.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	intro_tw.tween_property(panel, "modulate:a", 1.0, 0.10)
	await intro_tw.finished

	for i: int in range(value_labels.size()):
		var label: Label = value_labels[i]
		var die_panel: Panel = die_panels[i]
		var final_value: int = 0
		var die_color: int = 0
		if i < rolls.size():
			var roll: Dictionary = rolls[i]
			final_value = int(roll.get("value", 0))
			die_color = int(roll.get("color", 0))
		var faces: Array = Unit.DICE.get(die_color, [0, 1, 2, 3])
		for _j: int in range(8):
			label.text = str(faces[randi() % faces.size()])
			await get_tree().create_timer(0.035).timeout
		label.text = str(final_value)
		var pulse_tw := die_panel.create_tween().set_parallel(true)
		pulse_tw.tween_property(die_panel, "scale", Vector2(1.08, 1.08), 0.07).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pulse_tw.tween_property(die_panel, "modulate", Color(1.18, 1.18, 1.18, 1.0), 0.07)
		pulse_tw.tween_property(die_panel, "scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		pulse_tw.tween_property(die_panel, "modulate", Color.WHITE, 0.12)
		await pulse_tw.finished

	await get_tree().create_timer(0.24).timeout

	var out_tw := panel.create_tween().set_parallel(true)
	out_tw.tween_property(panel, "position", panel.position + Vector2(0.0, -18.0), 0.18)
	out_tw.tween_property(panel, "modulate:a", 0.0, 0.18)
	out_tw.tween_property(shadow, "modulate:a", 0.0, 0.18)
	await out_tw.finished
	root.queue_free()

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
