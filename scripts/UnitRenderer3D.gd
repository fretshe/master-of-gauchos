extends Node3D

const UnitScript := preload("res://scripts/Unit.gd")

const CLASS_ICON_PATHS := {
	UnitScript.MASTER_UNIT_TYPE: "res://assets/sprites/ui/class_icons/master_icon.png",
	UnitScript.UnitType.WARRIOR: "res://assets/sprites/ui/class_icons/warrior_icon.png",
	UnitScript.UnitType.ARCHER: "res://assets/sprites/ui/class_icons/archer_icon.png",
	UnitScript.UnitType.LANCER: "res://assets/sprites/ui/class_icons/lancer_icon.png",
	UnitScript.UnitType.RIDER: "res://assets/sprites/ui/class_icons/rider_icon.png",
}

const LEVEL_BADGE_COLORS := {
	UnitScript.Level.BRONZE: Color(0.74, 0.46, 0.22, 0.98),
	UnitScript.Level.SILVER: Color(0.70, 0.76, 0.84, 0.98),
	UnitScript.Level.GOLD: Color(0.96, 0.78, 0.22, 0.98),
	UnitScript.Level.PLATINUM: Color(0.16, 0.58, 0.36, 0.98),
	UnitScript.Level.DIAMOND: Color(0.44, 0.88, 1.00, 0.98),
}

var owner_id: int = 1
var unit_name: String = ""
var is_master: bool = false

var _sprite: Sprite3D = null
var _glow_sprite: Sprite3D = null
var _shadow_blob: MeshInstance3D = null
var _master_aura: MeshInstance3D = null
var _matchup_indicator: Label3D = null
var _status_indicator: Label3D = null
var _class_badge_root: Node3D = null
var _class_badge_shadow: Sprite3D = null
var _class_badge_glow: Sprite3D = null
var _class_badge_fill: Sprite3D = null
var _class_badge_icon: Sprite3D = null
var _health_bar_root: Node3D = null
var _health_bar_back: Sprite3D = null
var _health_bar_fill: Sprite3D = null
var _health_bar_texture: Texture2D = null
var _badge_texture: Texture2D = null
var _master_aura_texture: Texture2D = null
var _sel_ring: MeshInstance3D = null
var _card_ring: MeshInstance3D = null
var _pulse_tween: Tween = null
var _motion_tween: Tween = null
var _rotation_tween: Tween = null
var _level_up_tween: Tween = null
var _is_night_lighting: bool = false
var _moon_strength: float = 0.0
var _bound_unit = null
var _cached_level: int = -1
var _cached_defense_buff: int = -1
var _fx_time: float = 0.0
var _obstruction_opacity: float = 1.0

var _sprite_y_tactical: float = 1.2
var _sprite_y_combat: float = 1.34
var _tactical_scale: Vector3 = Vector3.ONE
var _combat_scale: Vector3 = Vector3(0.9, 0.9, 0.9)
var _combat_base_scale: Vector3 = Vector3(0.9, 0.9, 0.9)

func setup(unit, _camera = null) -> void:
	_bound_unit = unit
	_cached_level = int(unit.level)
	owner_id = unit.owner_id
	unit_name = unit.unit_name
	is_master = unit is Master
	_tactical_scale = scale
	_build_sprite(unit)
	_build_class_badge(unit)
	_build_master_aura()
	_build_matchup_indicator()
	_build_status_indicator()
	set_health_bar_values(unit.hp, unit.max_hp, false)

func _process(delta: float) -> void:
	_fx_time += delta
	_refresh_badge_from_bound_unit()
	_refresh_status_indicator()
	_update_master_aura()

func set_tactical_mode() -> void:
	scale = _tactical_scale
	set_sprite_mirror(false)
	if _sprite != null:
		_sprite.position.y = _sprite_y_tactical
	if _glow_sprite != null:
		_glow_sprite.position.y = _sprite_y_tactical
	_set_class_badge_visible(true)
	_set_master_aura_visible(is_master)
	_set_matchup_indicator_visible(_matchup_indicator != null and _matchup_indicator.text != "")
	if _status_indicator != null:
		_status_indicator.visible = _cached_defense_buff > 0
	set_health_bar_visible(false)

func set_combat_mode() -> void:
	scale = _combat_scale
	_combat_base_scale = _combat_scale
	if _sprite != null:
		_sprite.position.y = _sprite_y_combat
	if _glow_sprite != null:
		_glow_sprite.position.y = _sprite_y_combat
	_set_class_badge_visible(false)
	_set_master_aura_visible(false)
	_set_matchup_indicator_visible(false)
	if _status_indicator != null:
		_status_indicator.visible = false
	set_health_bar_visible(false)

func set_sprite_mirror(mirrored: bool) -> void:
	if _sprite != null:
		_sprite.flip_h = mirrored
	if _glow_sprite != null:
		_glow_sprite.flip_h = mirrored

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
	_apply_obstruction_opacity()
	_update_shadow_blob()

func set_combat_facing(other_pos: Vector3) -> void:
	var dir := other_pos - position
	dir.y = 0.0
	if dir.length_squared() > 0.001:
		var angle := atan2(dir.x, dir.z)
		if _rotation_tween != null and _rotation_tween.is_valid():
			_rotation_tween.kill()
		_rotation_tween = create_tween()
		_rotation_tween.tween_property(self, "rotation:y", angle, 0.20) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func reset_combat_facing() -> void:
	if _rotation_tween != null and _rotation_tween.is_valid():
		_rotation_tween.kill()
	_rotation_tween = create_tween()
	_rotation_tween.tween_property(self, "rotation:y", 0.0, 0.20) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func snap_to_world_position(world_pos: Vector3) -> void:
	if _motion_tween != null and _motion_tween.is_valid():
		_motion_tween.kill()
	position = world_pos

func set_combat_focus(focused: bool) -> void:
	var target := _combat_scale * 1.05 if focused else _combat_scale
	create_tween() \
		.tween_property(self, "scale", target, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_combat_base_scale = target

func set_combat_dim(dimmed: bool) -> void:
	var alpha := 0.18 if dimmed else 1.0
	if _sprite != null:
		create_tween().tween_property(_sprite, "modulate:a", alpha * _obstruction_opacity, 0.20)

func set_combat_obstruction_opacity(opacity: float) -> void:
	_obstruction_opacity = clampf(opacity, 0.0, 1.0)
	_apply_obstruction_opacity()

func set_placement_preview_style(opacity: float = 0.45) -> void:
	_obstruction_opacity = clampf(opacity, 0.0, 1.0)
	_apply_obstruction_opacity()
	set_health_bar_visible(false)
	if _matchup_indicator != null:
		_matchup_indicator.visible = false
	if _sel_ring != null:
		_sel_ring.visible = false

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

	_emit_selection_burst()

func _apply_obstruction_opacity() -> void:
	if _sprite != null:
		_sprite.modulate.a = _obstruction_opacity
	if _glow_sprite != null:
		_glow_sprite.modulate.a = (0.28 * _moon_strength if _glow_sprite.visible else 0.0) * _obstruction_opacity
	if _class_badge_shadow != null:
		_class_badge_shadow.modulate.a = 0.18 * _obstruction_opacity
	if _class_badge_glow != null:
		_class_badge_glow.modulate.a = 1.0 * _obstruction_opacity
		if _class_badge_glow.material_override is StandardMaterial3D:
			var glow_mat: StandardMaterial3D = _class_badge_glow.material_override as StandardMaterial3D
			var glow_color: Color = glow_mat.albedo_color
			glow_mat.albedo_color = Color(glow_color.r, glow_color.g, glow_color.b, 0.24 * _obstruction_opacity)
	if _class_badge_fill != null:
		_class_badge_fill.modulate.a = 0.44 * _obstruction_opacity
	if _class_badge_icon != null:
		_class_badge_icon.modulate.a = _obstruction_opacity
		if _class_badge_icon.material_override is StandardMaterial3D:
			var icon_mat: StandardMaterial3D = _class_badge_icon.material_override as StandardMaterial3D
			var icon_color: Color = icon_mat.albedo_color
			icon_mat.albedo_color = Color(icon_color.r, icon_color.g, icon_color.b, _obstruction_opacity)
	if _matchup_indicator != null:
		var color: Color = _matchup_indicator.modulate
		_matchup_indicator.modulate = Color(color.r, color.g, color.b, _obstruction_opacity)
	if _status_indicator != null:
		var status_color: Color = _status_indicator.modulate
		_status_indicator.modulate = Color(status_color.r, status_color.g, status_color.b, _obstruction_opacity)

func anim_lunge(target_pos: Vector3, host: Node) -> Tween:
	if _motion_tween != null and _motion_tween.is_valid():
		_motion_tween.kill()
	var origin := position
	var punch := origin.lerp(target_pos, 0.38)
	var tw := host.create_tween()
	_motion_tween = tw
	tw.tween_property(self, "position", punch, 0.09) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position", origin, 0.14) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	return tw

func anim_attack_anticipation(host: Node, intensity: float = 1.0, duration: float = 0.10) -> Tween:
	if _motion_tween != null and _motion_tween.is_valid():
		_motion_tween.kill()
	var base_scale := _combat_base_scale if _combat_base_scale != Vector3.ZERO else scale
	var origin := position
	var lift := position + Vector3(0.0, 0.07 * intensity, 0.0)
	var squeeze := Vector3(base_scale.x * (1.0 - 0.06 * intensity), base_scale.y * (1.0 + 0.10 * intensity), base_scale.z * (1.0 - 0.06 * intensity))
	var tw := host.create_tween().set_parallel(true)
	_motion_tween = tw
	tw.tween_property(self, "position", lift, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", squeeze, duration) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(self, "position", origin, duration * 0.70) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(self, "scale", base_scale, duration * 0.70) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	return tw

func anim_super_critical_charge(host: Node, intensity: float = 1.0, duration: float = 0.34) -> Tween:
	if _motion_tween != null and _motion_tween.is_valid():
		_motion_tween.kill()
	var base_scale := _combat_base_scale if _combat_base_scale != Vector3.ZERO else scale
	var origin := position
	var lift := origin + Vector3(0.0, 0.10 * intensity, 0.0)
	var windup_scale := Vector3(base_scale.x * 0.88, base_scale.y * 1.16, base_scale.z * 0.88)
	var tw := host.create_tween()
	_motion_tween = tw
	tw.tween_property(self, "position", lift, duration * 0.30) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "scale", windup_scale, duration * 0.30) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for i: int in range(8):
		var shake_x: float = 0.022 * intensity * (-1.0 if i % 2 == 0 else 1.0)
		tw.tween_property(self, "position:x", origin.x + shake_x, duration * 0.05) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "position:x", origin.x, duration * 0.07) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_interval(duration * 0.18)
	tw.tween_property(self, "position", origin, duration * 0.20) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(self, "scale", base_scale, duration * 0.20) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	return tw

func anim_hit(attacker_pos: Vector3, host: Node) -> Tween:
	if _motion_tween != null and _motion_tween.is_valid():
		_motion_tween.kill()
	var dir := position - attacker_pos
	dir.y = 0.0
	dir = dir.normalized() if dir.length_squared() > 0.001 else Vector3.BACK
	var origin := position
	var recoil := origin + dir * 0.28
	var tw := host.create_tween()
	_motion_tween = tw
	tw.tween_property(self, "position", recoil, 0.07) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position", origin, 0.16) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_flash_color_async(Color(1.0, 0.10, 0.10), host)
	_emit_impact_burst(Color(1.00, 0.84, 0.36), 0.22)
	return tw

func anim_super_critical_hit(attacker_pos: Vector3, host: Node) -> Tween:
	if _motion_tween != null and _motion_tween.is_valid():
		_motion_tween.kill()
	var dir := position - attacker_pos
	dir.y = 0.0
	dir = dir.normalized() if dir.length_squared() > 0.001 else Vector3.BACK
	var origin := position
	var launch := origin + dir * 0.16 + Vector3(0.0, 0.42, 0.0)
	var tw := host.create_tween()
	_motion_tween = tw
	tw.tween_property(self, "position", launch, 0.10) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position", origin, 0.22) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_flash_color_async(Color(1.0, 0.04, 0.04), host)
	_emit_impact_burst(Color(1.00, 0.16, 0.16), 0.30)
	return tw

func anim_dodge(attacker_pos: Vector3, host: Node) -> Tween:
	if _motion_tween != null and _motion_tween.is_valid():
		_motion_tween.kill()
	var to_atk := attacker_pos - position
	to_atk.y = 0.0
	to_atk = to_atk.normalized() if to_atk.length_squared() > 0.001 else Vector3.FORWARD
	var side := Vector3(-to_atk.z, 0.0, to_atk.x)
	var origin := position
	var dodge_pos := origin + side * 0.42
	var tw := host.create_tween()
	_motion_tween = tw
	tw.tween_property(self, "position", dodge_pos, 0.10) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position", origin, 0.20) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	return tw

func anim_death(attacker_pos: Vector3, host: Node) -> Tween:
	if _motion_tween != null and _motion_tween.is_valid():
		_motion_tween.kill()
	set_health_bar_visible(false)
	var dir := position - attacker_pos
	dir.y = 0.0
	dir = dir.normalized() if dir.length_squared() > 0.001 else Vector3.BACK
	var fall_target := position + dir * 0.55 + Vector3(0.0, -0.45, 0.0)
	var tw := host.create_tween().set_parallel(true)
	_motion_tween = tw
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
	shadow_mesh.top_radius = 0.46
	shadow_mesh.bottom_radius = 0.46
	shadow_mesh.height = 0.012
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
	_shadow_blob.position = Vector3(0.0, 0.007, 0.0)
	_shadow_blob.scale = Vector3(1.06, 0.42, 0.68)
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
	_build_health_bar()
	_update_shadow_blob()

func _build_master_aura() -> void:
	if not is_master:
		return
	var team_color: Color = GameData.get_player_color(owner_id)
	_ensure_master_aura_texture()
	_master_aura = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.62, 1.42)
	_master_aura.mesh = quad
	_master_aura.material_override = _make_master_aura_material(_master_aura_texture, Color(team_color.r, team_color.g, team_color.b, 0.95))
	_master_aura.rotation.x = -PI * 0.5
	_master_aura.position = Vector3(0.0, 0.022, 0.0)
	_master_aura.scale = Vector3(1.0, 1.0, 1.0)
	add_child(_master_aura)
	_set_master_aura_visible(true)

func _build_matchup_indicator() -> void:
	_matchup_indicator = Label3D.new()
	_matchup_indicator.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_matchup_indicator.no_depth_test = true
	_matchup_indicator.font_size = 26 if is_master else 22
	_matchup_indicator.outline_size = 6
	_matchup_indicator.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_matchup_indicator.position = Vector3(0.0, 1.78 if is_master else 1.54, 0.0)
	_matchup_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_matchup_indicator.line_spacing = -3.0
	_matchup_indicator.text = ""
	GameData.apply_selected_font_to_label3d(_matchup_indicator)
	add_child(_matchup_indicator)

func _build_status_indicator() -> void:
	_status_indicator = Label3D.new()
	_status_indicator.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_status_indicator.no_depth_test = true
	_status_indicator.font_size = 18
	_status_indicator.outline_size = 6
	_status_indicator.modulate = Color(0.18, 0.84, 0.76, _obstruction_opacity)
	_status_indicator.position = Vector3(0.0, 1.22 if is_master else 1.02, 0.0)
	_status_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_indicator.text = ""
	_status_indicator.visible = false
	GameData.apply_selected_font_to_label3d(_status_indicator)
	add_child(_status_indicator)

func _refresh_status_indicator() -> void:
	if _bound_unit == null or _status_indicator == null:
		return
	var defense_buff: int = int(_bound_unit.defense_buff)
	if defense_buff == _cached_defense_buff:
		return
	_cached_defense_buff = defense_buff
	if defense_buff > 0:
		_status_indicator.text = "DEF +%d" % defense_buff
		_status_indicator.modulate = Color(0.18, 0.84, 0.76, _obstruction_opacity)
		_status_indicator.visible = true
	else:
		_status_indicator.text = ""
		_status_indicator.visible = false

func set_matchup_indicator(state: int) -> void:
	if _matchup_indicator == null:
		return
	match state:
		1:
			_matchup_indicator.text = "▲\nVENTAJA"
			_matchup_indicator.modulate = Color(0.36, 1.0, 0.42, _obstruction_opacity)
		-1:
			_matchup_indicator.text = "▼\nDESVENTAJA"
			_matchup_indicator.modulate = Color(1.0, 0.34, 0.34, _obstruction_opacity)
		_:
			_matchup_indicator.text = ""
			_matchup_indicator.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_set_matchup_indicator_visible(_matchup_indicator.text != "")

func _set_matchup_indicator_visible(visible: bool) -> void:
	if _matchup_indicator != null:
		_matchup_indicator.visible = visible

func set_health_bar_visible(visible: bool) -> void:
	if _health_bar_root != null:
		_health_bar_root.visible = visible

func set_class_badge_visible(visible: bool) -> void:
	_set_class_badge_visible(visible)

func set_health_bar_values(current_hp: int, max_hp: int, animate: bool = true) -> void:
	if _health_bar_fill == null:
		return
	var ratio: float = 0.0 if max_hp <= 0 else clampf(float(current_hp) / float(max_hp), 0.0, 1.0)
	var width: float = maxf(0.001, ratio)
	var color := _health_color(ratio)

	if animate:
		var fill_tw := create_tween().set_parallel(true)
		fill_tw.tween_property(_health_bar_fill, "scale:x", width, 0.18) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		fill_tw.tween_property(_health_bar_fill, "position:x", -0.5 + width * 0.5, 0.18) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		_health_bar_fill.scale.x = width
		_health_bar_fill.position.x = -0.5 + width * 0.5
	_health_bar_fill.modulate = color

	if animate and _health_bar_root != null:
		var tw := create_tween()
		tw.tween_property(_health_bar_root, "scale", Vector3(1.08, 1.16, 1.0), 0.08) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_health_bar_root, "scale", Vector3.ONE, 0.12) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _build_health_bar() -> void:
	_ensure_health_bar_texture()
	_health_bar_root = Node3D.new()
	_health_bar_root.visible = false
	_health_bar_root.position = Vector3(0.0, _sprite_y_combat + 0.62, 0.0)
	add_child(_health_bar_root)

	_health_bar_back = Sprite3D.new()
	_health_bar_back.texture = _health_bar_texture
	_health_bar_back.pixel_size = 1.0
	_health_bar_back.centered = false
	_health_bar_back.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_health_bar_back.no_depth_test = true
	_health_bar_back.shaded = false
	_health_bar_back.modulate = Color(0.05, 0.05, 0.05, 0.82)
	_health_bar_back.position = Vector3(-0.51, -0.06, 0.0)
	_health_bar_back.scale = Vector3(1.02, 0.12, 1.0)
	_health_bar_root.add_child(_health_bar_back)

	_health_bar_fill = Sprite3D.new()
	_health_bar_fill.texture = _health_bar_texture
	_health_bar_fill.pixel_size = 1.0
	_health_bar_fill.centered = false
	_health_bar_fill.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_health_bar_fill.no_depth_test = true
	_health_bar_fill.shaded = false
	_health_bar_fill.position = Vector3(-0.5, -0.04, -0.001)
	_health_bar_fill.scale = Vector3(1.0, 0.08, 1.0)
	_health_bar_root.add_child(_health_bar_fill)

func _ensure_health_bar_texture() -> void:
	if _health_bar_texture != null:
		return
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_health_bar_texture = ImageTexture.create_from_image(img)

func _ensure_badge_texture() -> void:
	if _badge_texture != null:
		return
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_badge_texture = ImageTexture.create_from_image(img)

func _ensure_master_aura_texture() -> void:
	if _master_aura_texture != null:
		return

	var size_px: int = 128
	var image := Image.create(size_px, size_px, false, Image.FORMAT_RGBA8)
	var center := Vector2(size_px * 0.5, size_px * 0.5)
	var radius: float = size_px * 0.40
	var vertices: Array[Vector2] = []
	for i: int in range(6):
		var angle: float = deg_to_rad(60.0 * float(i))
		vertices.append(center + Vector2(cos(angle), sin(angle)) * radius)

	var fade_inside: float = 12.0
	var fade_outside: float = 10.0
	for y: int in range(size_px):
		for x: int in range(size_px):
			var p := Vector2(float(x) + 0.5, float(y) + 0.5)
			var inside: bool = Geometry2D.is_point_in_polygon(p, PackedVector2Array(vertices))
			var edge_dist: float = 10000.0
			for i: int in range(vertices.size()):
				var a: Vector2 = vertices[i]
				var b: Vector2 = vertices[(i + 1) % vertices.size()]
				edge_dist = minf(edge_dist, Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p))
			var center_falloff: float = clampf(1.0 - p.distance_to(center) / (radius * 1.05), 0.0, 1.0)
			var alpha: float = 0.0
			if inside:
				alpha = (0.28 + center_falloff * 0.38) * clampf(edge_dist / fade_inside, 0.0, 1.0)
			else:
				alpha = 0.16 * clampf(1.0 - edge_dist / fade_outside, 0.0, 1.0)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))

	_master_aura_texture = ImageTexture.create_from_image(image)

func _make_master_aura_material(texture: Texture2D, tint: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_texture = texture
	mat.albedo_color = tint
	mat.emission_enabled = true
	mat.emission = tint
	mat.emission_energy_multiplier = 1.2
	return mat

func _build_class_badge(unit) -> void:
	_ensure_badge_texture()
	var unit_type: int = UnitScript.MASTER_UNIT_TYPE if is_master else int(unit.unit_type)
	var icon_path: String = CLASS_ICON_PATHS.get(unit_type, CLASS_ICON_PATHS[UnitScript.UnitType.WARRIOR])
	var icon_tex: Texture2D = load(icon_path) if ResourceLoader.exists(icon_path) else null
	var root_offset := Vector3(-0.52, 0.56, 0.02)
	if is_master:
		root_offset = Vector3(-0.60, 0.64, 0.02)

	_class_badge_root = Node3D.new()
	_class_badge_root.position = root_offset
	add_child(_class_badge_root)

	_class_badge_shadow = Sprite3D.new()
	_class_badge_shadow.texture = icon_tex
	_class_badge_shadow.pixel_size = 0.0114
	_class_badge_shadow.centered = true
	_class_badge_shadow.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_class_badge_shadow.no_depth_test = true
	_class_badge_shadow.shaded = false
	_class_badge_shadow.modulate = Color.WHITE
	_class_badge_shadow.material_override = _make_badge_material(icon_tex, Color(0.0, 0.0, 0.0, 0.18))
	_class_badge_shadow.position = Vector3(0.02, -0.02, 0.004)
	_class_badge_shadow.scale = Vector3(1.18, 1.18, 1.0)
	_class_badge_root.add_child(_class_badge_shadow)

	_class_badge_glow = Sprite3D.new()
	_class_badge_glow.texture = icon_tex
	_class_badge_glow.pixel_size = 0.0144
	_class_badge_glow.centered = true
	_class_badge_glow.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_class_badge_glow.no_depth_test = true
	_class_badge_glow.shaded = false
	_class_badge_glow.modulate = Color.WHITE
	_class_badge_glow.material_override = _make_badge_material(icon_tex, Color(1.0, 1.0, 1.0, 0.24))
	_class_badge_glow.position = Vector3(0.0, 0.0, 0.002)
	_class_badge_glow.scale = Vector3(1.36, 1.36, 1.0) if is_master else Vector3(1.22, 1.22, 1.0)
	_class_badge_root.add_child(_class_badge_glow)

	_class_badge_fill = Sprite3D.new()
	_class_badge_fill.texture = _badge_texture
	_class_badge_fill.pixel_size = 1.0
	_class_badge_fill.centered = true
	_class_badge_fill.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_class_badge_fill.no_depth_test = true
	_class_badge_fill.shaded = false
	_class_badge_fill.modulate = Color(0.0, 0.0, 0.0, 0.44)
	_class_badge_fill.position = Vector3(0.0, 0.0, -0.001)
	_class_badge_fill.scale = Vector3(0.26, 0.26, 1.0) if is_master else Vector3(0.22, 0.22, 1.0)
	_class_badge_root.add_child(_class_badge_fill)

	_class_badge_icon = Sprite3D.new()
	_class_badge_icon.texture = icon_tex
	_class_badge_icon.pixel_size = 0.0126
	_class_badge_icon.centered = true
	_class_badge_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_class_badge_icon.no_depth_test = true
	_class_badge_icon.shaded = false
	_class_badge_icon.modulate = Color.WHITE
	_class_badge_icon.material_override = _make_badge_material(icon_tex, Color.WHITE)
	_class_badge_icon.position = Vector3(0.0, 0.0, -0.002)
	_class_badge_icon.scale = Vector3(1.42, 1.42, 1.0) if is_master else Vector3(1.24, 1.24, 1.0)
	_class_badge_root.add_child(_class_badge_icon)

	_apply_badge_level_visual(int(unit.level))
	_set_class_badge_visible(true)

func _refresh_badge_from_bound_unit() -> void:
	if _bound_unit == null:
		return
	var level: int = int(_bound_unit.level)
	if level == _cached_level:
		return
	_cached_level = level
	_apply_badge_level_visual(level)
	_play_level_up_fx(level)

func _apply_badge_level_visual(level: int) -> void:
	var badge_color: Color = LEVEL_BADGE_COLORS.get(level, Color(0.80, 0.70, 0.28, 0.98))
	if _class_badge_glow != null and _class_badge_glow.material_override is StandardMaterial3D:
		var glow_mat: StandardMaterial3D = _class_badge_glow.material_override as StandardMaterial3D
		glow_mat.albedo_color = Color(badge_color.r, badge_color.g, badge_color.b, 0.24 * _obstruction_opacity)
	if _class_badge_icon != null and _class_badge_icon.material_override is StandardMaterial3D:
		var icon_mat: StandardMaterial3D = _class_badge_icon.material_override as StandardMaterial3D
		icon_mat.albedo_color = Color(badge_color.r, badge_color.g, badge_color.b, _obstruction_opacity)

func _play_level_up_fx(level: int) -> void:
	var color: Color = LEVEL_BADGE_COLORS.get(level, Color(1.0, 0.84, 0.24, 0.98))
	_emit_selection_burst(Color(color.r, color.g, color.b, 0.92), 0.42, 1.28)
	_emit_selection_burst(Color(color.r, color.g, color.b, 0.58), 0.62, 1.72)
	_emit_level_up_column(color)
	_show_level_up_label(level, color)
	if _sprite != null:
		if _level_up_tween != null and _level_up_tween.is_valid():
			_level_up_tween.kill()
		var base_scale: Vector3 = scale
		var boosted_scale: Vector3 = base_scale * 1.18
		_level_up_tween = create_tween().set_parallel(true)
		_level_up_tween.tween_property(self, "scale", boosted_scale, 0.16) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_level_up_tween.tween_property(self, "scale", base_scale, 0.34) \
			.set_delay(0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		_level_up_tween.tween_method(
			func(alpha: float) -> void:
				if _glow_sprite != null and _glow_sprite.material_override is StandardMaterial3D:
					var glow_mat: StandardMaterial3D = _glow_sprite.material_override as StandardMaterial3D
					_glow_sprite.visible = true
					_glow_sprite.modulate = Color(color.r, color.g, color.b, alpha)
					glow_mat.albedo_color = Color(color.r, color.g, color.b, alpha)
					glow_mat.emission = color
					glow_mat.emission_energy_multiplier = 2.4 * alpha,
			0.95, 0.0, 0.54
		)
		_level_up_tween.finished.connect(func() -> void:
			if _glow_sprite != null:
				_glow_sprite.visible = _is_night_lighting and _moon_strength > 0.01
				set_time_lighting(_is_night_lighting, _moon_strength)
		)

func _emit_level_up_column(color: Color) -> void:
	var beam := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.18
	mesh.bottom_radius = 0.34
	mesh.height = 2.1
	mesh.radial_segments = 18
	mesh.rings = 1
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(color.r, color.g, color.b, 0.36)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.8
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam.mesh = mesh
	beam.material_override = mat
	beam.position = Vector3(0.0, 1.05, 0.0)
	beam.scale = Vector3(0.24, 0.12, 0.24)
	add_child(beam)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(beam, "scale", Vector3(1.0, 1.0, 1.0), 0.20) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(beam, "position:y", 1.32, 0.52) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_method(
		func(alpha: float) -> void:
			if is_instance_valid(beam) and beam.material_override is StandardMaterial3D:
				var beam_mat: StandardMaterial3D = beam.material_override as StandardMaterial3D
				beam_mat.albedo_color = Color(color.r, color.g, color.b, alpha)
				beam_mat.emission_energy_multiplier = 2.8 * alpha,
		0.42, 0.0, 0.56
	)
	tw.finished.connect(func() -> void:
		if is_instance_valid(beam):
			beam.queue_free()
	)

func _show_level_up_label(level: int, color: Color) -> void:
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 28
	label.outline_size = 8
	label.position = Vector3(0.0, 1.88, 0.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text = _level_up_label_text(level)
	label.modulate = Color(color.r, color.g, color.b, 0.0)
	GameData.apply_selected_font_to_label3d(label)
	add_child(label)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(label, "position:y", 2.36, 0.72) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_method(
		func(alpha: float) -> void:
			if is_instance_valid(label):
				label.modulate = Color(color.r, color.g, color.b, alpha * _obstruction_opacity),
		0.0, 1.0, 0.12
	)
	tw.tween_method(
		func(alpha: float) -> void:
			if is_instance_valid(label):
				label.modulate = Color(color.r, color.g, color.b, alpha * _obstruction_opacity),
		1.0, 0.0, 0.42
	).set_delay(0.30)
	tw.finished.connect(func() -> void:
		if is_instance_valid(label):
			label.queue_free()
	)

func _level_up_label_text(level: int) -> String:
	match level:
		UnitScript.Level.SILVER:
			return "PLATA"
		UnitScript.Level.GOLD:
			return "ORO"
		UnitScript.Level.PLATINUM:
			return "PLATINO"
		UnitScript.Level.DIAMOND:
			return "DIAMANTE"
		_:
			return "NIVEL +1"

func _set_class_badge_visible(visible: bool) -> void:
	if _class_badge_root != null:
		_class_badge_root.visible = visible

func _set_master_aura_visible(visible: bool) -> void:
	if _master_aura != null:
		_master_aura.visible = visible

func _update_master_aura() -> void:
	if _master_aura == null or not is_master:
		return
	var pulse: float = 0.5 + 0.5 * sin(_fx_time * 2.4)
	var team_color: Color = GameData.get_player_color(owner_id)
	_master_aura.scale = Vector3.ONE * (1.0 + pulse * 0.06)
	if _master_aura.material_override is StandardMaterial3D:
		var mat: StandardMaterial3D = _master_aura.material_override as StandardMaterial3D
		mat.albedo_color = Color(team_color.r, team_color.g, team_color.b, (0.78 + pulse * 0.14) * _obstruction_opacity)
		mat.emission = team_color
		mat.emission_energy_multiplier = (1.00 + pulse * 0.55) * _obstruction_opacity

func _make_badge_material(texture: Texture2D, tint: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_texture = texture
	mat.albedo_color = tint
	mat.no_depth_test = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

func _health_color(ratio: float) -> Color:
	if ratio <= 0.25:
		return Color(1.00, 0.22, 0.22, 0.96)
	if ratio <= 0.55:
		return Color(0.96, 0.36, 0.30, 0.96)
	return Color(0.90, 0.18, 0.18, 0.96)

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
