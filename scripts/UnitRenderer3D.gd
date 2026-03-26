extends Node3D

var owner_id: int = 1
var unit_name: String = ""
var is_master: bool = false

var _sprite: Sprite3D = null
var _glow_sprite: Sprite3D = null
var _shadow_blob: MeshInstance3D = null
var _sel_ring: MeshInstance3D = null
var _card_ring: MeshInstance3D = null
var _pulse_tween: Tween = null
var _is_night_lighting: bool = false
var _moon_strength: float = 0.0

var _sprite_y_tactical: float = 1.2
var _sprite_y_combat: float = 1.34

func setup(unit, _camera = null) -> void:
	owner_id = unit.owner_id
	unit_name = unit.unit_name
	is_master = unit is Master
	_build_sprite(unit)

func set_tactical_mode() -> void:
	if _sprite != null:
		_sprite.position.y = _sprite_y_tactical
	if _glow_sprite != null:
		_glow_sprite.position.y = _sprite_y_tactical

func set_combat_mode() -> void:
	if _sprite != null:
		_sprite.position.y = _sprite_y_combat
	if _glow_sprite != null:
		_glow_sprite.position.y = _sprite_y_combat

func set_time_lighting(is_night: bool, moon_strength: float = 0.0) -> void:
	_is_night_lighting = is_night
	_moon_strength = moon_strength
	if _glow_sprite == null:
		_update_shadow_blob()
		return
	_glow_sprite.visible = is_night and moon_strength > 0.01
	_glow_sprite.modulate = Color(0.82, 0.90, 1.0, 0.28 * moon_strength)
	if _glow_sprite.material_override is StandardMaterial3D:
		var mat: StandardMaterial3D = _glow_sprite.material_override as StandardMaterial3D
		mat.emission_energy_multiplier = 1.45 * moon_strength
	_update_shadow_blob()

func set_combat_facing(other_pos: Vector3) -> void:
	var dir := other_pos - position
	dir.y = 0.0
	if dir.length_squared() > 0.001:
		var angle := atan2(dir.x, dir.z)
		create_tween().tween_property(self, "rotation:y", angle, 0.20) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func reset_combat_facing() -> void:
	create_tween().tween_property(self, "rotation:y", 0.0, 0.20) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func set_combat_focus(focused: bool) -> void:
	var target := Vector3(1.08, 1.08, 1.08) if focused else Vector3.ONE
	create_tween() \
		.tween_property(self, "scale", target, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func set_combat_dim(dimmed: bool) -> void:
	var alpha := 0.40 if dimmed else 1.0
	create_tween().tween_property(self, "modulate:a", alpha, 0.20)

func dim_selection_ring() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.stop()
	if _sel_ring == null:
		return
	if _sel_ring.material_override is StandardMaterial3D:
		var mat: StandardMaterial3D = _sel_ring.material_override as StandardMaterial3D
		mat.albedo_color = Color(0.4, 0.4, 0.0, 0.5)
		mat.emission = Color(0.4, 0.4, 0.0)
		mat.emission_energy_multiplier = 0.5

func set_selection_ring_visible(visible: bool) -> void:
	if _sel_ring != null:
		_sel_ring.visible = visible

func restore_selection_ring() -> void:
	if _sel_ring == null:
		return
	if _sel_ring.material_override is StandardMaterial3D:
		var mat: StandardMaterial3D = _sel_ring.material_override as StandardMaterial3D
		mat.albedo_color = Color(1.00, 0.92, 0.20)
		mat.emission = Color(1.00, 0.80, 0.00)
		mat.emission_energy_multiplier = 2.0
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.play()

func set_card_target_highlight(active: bool, color: Color) -> void:
	if _card_ring != null:
		_card_ring.queue_free()
		_card_ring = null
	if not active:
		return

	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = 0.48
	ring_mesh.bottom_radius = 0.48
	ring_mesh.height = 0.02
	ring_mesh.radial_segments = 24
	ring_mesh.rings = 1

	var ring_mat := StandardMaterial3D.new()
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = Color(color.r, color.g, color.b, 0.72)
	ring_mat.emission_enabled = true
	ring_mat.emission = color
	ring_mat.emission_energy_multiplier = 2.4

	_card_ring = MeshInstance3D.new()
	_card_ring.mesh = ring_mesh
	_card_ring.material_override = ring_mat
	_card_ring.position = Vector3(0.0, 0.03, 0.0)
	add_child(_card_ring)

func set_selected(selected: bool) -> void:
	if _pulse_tween != null:
		_pulse_tween.kill()
		_pulse_tween = null
	if _sel_ring != null:
		_sel_ring.queue_free()
		_sel_ring = null
	if _sprite != null:
		_sprite.modulate = _owner_color()

	if not selected:
		return

	var base_col: Color = _owner_color()
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_method(
		func(v: float) -> void:
			if is_instance_valid(_sprite):
				_sprite.modulate = base_col.lightened(v),
		0.0, 0.45, 0.55
	)
	_pulse_tween.tween_method(
		func(v: float) -> void:
			if is_instance_valid(_sprite):
				_sprite.modulate = base_col.lightened(v),
		0.45, 0.0, 0.55
	)

	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = 0.61
	ring_mesh.bottom_radius = 0.61
	ring_mesh.height = 0.03
	ring_mesh.radial_segments = 32
	ring_mesh.rings = 1

	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(1.00, 0.92, 0.20)
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(1.00, 0.80, 0.00)
	ring_mat.emission_energy_multiplier = 2.0

	_sel_ring = MeshInstance3D.new()
	_sel_ring.mesh = ring_mesh
	_sel_ring.material_override = ring_mat
	_sel_ring.position.y = 0.02
	add_child(_sel_ring)

	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_method(
		func(v: float) -> void:
			if is_instance_valid(_sel_ring) and _sel_ring.material_override is StandardMaterial3D:
				var sel_mat: StandardMaterial3D = _sel_ring.material_override as StandardMaterial3D
				sel_mat.emission = Color(1.00, 0.80, 0.00)
				sel_mat.emission_energy_multiplier = v,
		2.0, 5.0, 0.45
	)
	_pulse_tween.tween_method(
		func(v: float) -> void:
			if is_instance_valid(_sel_ring) and _sel_ring.material_override is StandardMaterial3D:
				var sel_mat: StandardMaterial3D = _sel_ring.material_override as StandardMaterial3D
				sel_mat.emission = Color(1.00, 0.80, 0.00)
				sel_mat.emission_energy_multiplier = v,
		5.0, 2.0, 0.45
	)

	_emit_selection_burst()

func anim_lunge(target_pos: Vector3, host: Node) -> Tween:
	var origin := position
	var punch := origin.lerp(target_pos, 0.38)
	var tw := host.create_tween()
	tw.tween_property(self, "position", punch, 0.09) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position", origin, 0.14) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	return tw

func anim_hit(attacker_pos: Vector3, host: Node) -> void:
	var dir := position - attacker_pos
	dir.y = 0.0
	dir = dir.normalized() if dir.length_squared() > 0.001 else Vector3.BACK
	var origin := position
	var recoil := origin + dir * 0.28
	var tw := host.create_tween()
	tw.tween_property(self, "position", recoil, 0.07) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position", origin, 0.16) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_flash_color_async(Color(1.0, 0.10, 0.10), host)
	_emit_impact_burst(Color(1.00, 0.84, 0.36), 0.22)

func anim_dodge(attacker_pos: Vector3, host: Node) -> void:
	var to_atk := attacker_pos - position
	to_atk.y = 0.0
	to_atk = to_atk.normalized() if to_atk.length_squared() > 0.001 else Vector3.FORWARD
	var side := Vector3(-to_atk.z, 0.0, to_atk.x)
	var origin := position
	var dodge_pos := origin + side * 0.42
	var tw := host.create_tween()
	tw.tween_property(self, "position", dodge_pos, 0.10) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position", origin, 0.20) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

func anim_death(attacker_pos: Vector3, host: Node) -> Tween:
	var dir := position - attacker_pos
	dir.y = 0.0
	dir = dir.normalized() if dir.length_squared() > 0.001 else Vector3.BACK
	var fall_target := position + dir * 0.55 + Vector3(0.0, -0.45, 0.0)
	var tw := host.create_tween().set_parallel(true)
	tw.tween_property(self, "position", fall_target, 0.55) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "scale", Vector3(1.15, 0.0, 1.15), 0.50) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if _sprite != null:
		tw.tween_property(_sprite, "modulate:a", 0.0, 0.38).set_delay(0.12)
	return tw

func _owner_color() -> Color:
	var base: Color = GameData.get_player_color(owner_id)
	return base.lightened(0.12) if is_master else base.lightened(0.22)

func _flash_color_async(color: Color, host: Node) -> void:
	if _sprite == null:
		return
	var original: Color = _sprite.modulate
	var tw := host.create_tween()
	tw.tween_property(_sprite, "modulate", color, 0.05)
	tw.tween_property(_sprite, "modulate", original, 0.22)

func _build_sprite(unit) -> void:
	var faction: int = GameData.get_faction_for_player(owner_id)
	var unit_type: int = -1 if is_master else unit.unit_type
	var path: String = FactionData.get_sprite_path(faction, unit_type)
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null

	_sprite = Sprite3D.new()
	_sprite.texture = tex
	_sprite.pixel_size = 0.008
	_sprite.centered = true
	_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_sprite.shaded = true
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_sprite.alpha_scissor_threshold = 0.12
	_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_sprite.no_depth_test = false
	_sprite.modulate = _owner_color()
	_sprite.position = Vector3(0, _sprite_y_tactical, 0)
	add_child(_sprite)

	_shadow_blob = MeshInstance3D.new()
	var shadow_mesh := CylinderMesh.new()
	shadow_mesh.top_radius = 0.42
	shadow_mesh.bottom_radius = 0.42
	shadow_mesh.height = 0.02
	shadow_mesh.radial_segments = 24
	shadow_mesh.rings = 1
	var shadow_mat := StandardMaterial3D.new()
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow_mat.albedo_color = Color(0.0, 0.0, 0.0, 0.20)
	shadow_mat.no_depth_test = false
	shadow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_shadow_blob.mesh = shadow_mesh
	_shadow_blob.material_override = shadow_mat
	_shadow_blob.position = Vector3(0.0, 0.012, 0.0)
	_shadow_blob.scale = Vector3(1.15, 1.0, 0.75)
	add_child(_shadow_blob)

	_glow_sprite = Sprite3D.new()
	_glow_sprite.texture = tex
	_glow_sprite.pixel_size = 0.008
	_glow_sprite.centered = true
	_glow_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_glow_sprite.shaded = false
	_glow_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_glow_sprite.no_depth_test = true
	_glow_sprite.position = Vector3(0, _sprite_y_tactical, -0.002)
	_glow_sprite.scale = Vector3(1.12, 1.12, 1.0)
	_glow_sprite.visible = false

	var glow_mat := StandardMaterial3D.new()
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	glow_mat.albedo_texture = tex
	glow_mat.albedo_color = Color(0.82, 0.90, 1.0, 0.22)
	glow_mat.emission_enabled = true
	glow_mat.emission = Color(0.82, 0.90, 1.0)
	glow_mat.emission_energy_multiplier = 0.0
	glow_mat.no_depth_test = true
	_glow_sprite.material_override = glow_mat
	add_child(_glow_sprite)
	_update_shadow_blob()

func play_move_landing() -> void:
	_emit_selection_burst(Color(0.80, 0.94, 1.0), 0.18, 0.78)

func _update_shadow_blob() -> void:
	if _shadow_blob == null:
		return
	if _shadow_blob.material_override is StandardMaterial3D:
		var mat: StandardMaterial3D = _shadow_blob.material_override as StandardMaterial3D
		var alpha: float = 0.16
		if _is_night_lighting:
			alpha = 0.22 + _moon_strength * 0.06
		mat.albedo_color = Color(0.0, 0.0, 0.0, alpha)

func _emit_selection_burst(color: Color = Color(1.00, 0.92, 0.28), duration: float = 0.24, radius: float = 0.88) -> void:
	var burst := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.56
	mesh.bottom_radius = 0.56
	mesh.height = 0.02
	mesh.radial_segments = 28
	mesh.rings = 1
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.8
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	burst.mesh = mesh
	burst.material_override = mat
	burst.position = Vector3(0.0, 0.03, 0.0)
	burst.scale = Vector3(0.18, 1.0, 0.18)
	add_child(burst)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(burst, "scale", Vector3(radius, 1.0, radius), duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_method(
		func(alpha: float) -> void:
			if is_instance_valid(burst) and burst.material_override is StandardMaterial3D:
				var burst_mat: StandardMaterial3D = burst.material_override as StandardMaterial3D
				burst_mat.albedo_color = Color(color.r, color.g, color.b, alpha)
				burst_mat.emission_energy_multiplier = 1.8 * alpha,
		0.65, 0.0, duration
	)
	tw.finished.connect(func() -> void:
		if is_instance_valid(burst):
			burst.queue_free()
	)

func _emit_impact_burst(color: Color, duration: float) -> void:
	var burst := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.16
	mesh.height = 0.32
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.2
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	burst.mesh = mesh
	burst.material_override = mat
	burst.position = Vector3(0.0, 1.0, 0.0)
	burst.scale = Vector3(0.2, 0.2, 0.2)
	add_child(burst)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(burst, "scale", Vector3(1.0, 1.0, 1.0), duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_method(
		func(alpha: float) -> void:
			if is_instance_valid(burst) and burst.material_override is StandardMaterial3D:
				var burst_mat: StandardMaterial3D = burst.material_override as StandardMaterial3D
				burst_mat.albedo_color = Color(color.r, color.g, color.b, alpha)
				burst_mat.emission_energy_multiplier = 2.2 * alpha,
		0.9, 0.0, duration
	)
	tw.finished.connect(func() -> void:
		if is_instance_valid(burst):
			burst.queue_free()
	)
