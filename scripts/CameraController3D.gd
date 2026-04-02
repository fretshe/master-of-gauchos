extends Camera3D

# ─── Constants ──────────────────────────────────────────────────────────────────
const MOVE_SPEED := 14.0
const LERP_SPEED := 8.0
const ZOOM_MIN   := 5.0    # minimum Y height
const ZOOM_MAX   := 28.0   # maximum Y height
const ZOOM_STEP  := 2.0

# Combat camera constants
const COMBAT_SIDE_DIST := 2.75   # lateral distance from midpoint
const COMBAT_HEIGHT    := 1.65   # camera height above midpoint
const COMBAT_TIME      := 0.8
const COMBAT_FOV       := 58.0
const COMBAT_LOOK_UP   := 0.42
const COMBAT_LIGHT_LOCAL_POS := Vector3(0.0, 0.72, 0.42)
const COMBAT_LIGHT_ENERGY := 3.15
const COMBAT_LIGHT_SPOT_ANGLE := 34.0
const COMBAT_LIGHT_RANGE := 11.0

# ─── State ──────────────────────────────────────────────────────────────────────
var _target_pos:  Vector3 = Vector3.ZERO
var _target_zoom: float   = 16.0

var _drag_active:    bool    = false
var _drag_last_world: Vector3 = Vector3.ZERO

var _map_min: Vector3 = Vector3.ZERO
var _map_max: Vector3 = Vector3(40.0, 0.0, 30.0)

# ─── Combat state ────────────────────────────────────────────────────────────────
var _combat_locked:    bool    = false
var _pre_combat_transform: Transform3D = Transform3D.IDENTITY
var _pre_combat_zoom:      float        = 16.0
var _showcase_locked: bool = false
var _manual_cinematic_lock: bool = false
var _pre_showcase_transform: Transform3D = Transform3D.IDENTITY
var _pre_showcase_zoom: float = 16.0
var _pre_showcase_fov: float = 75.0

var _combat_light: SpotLight3D = null
var _active_tween: Tween = null
var _combat_dof_tween: Tween = null
var _shake_tween: Tween = null
var _camera_attributes: CameraAttributesPractical = null
var _pre_combat_dof_amount: float = 0.0
var _pre_combat_near_enabled: bool = false
var _pre_combat_far_enabled: bool = false
var _pre_combat_fov: float = 75.0

# ─── Public API ─────────────────────────────────────────────────────────────────
func set_map_bounds(min_pos: Vector3, max_pos: Vector3) -> void:
	_map_min = min_pos
	_map_max = max_pos

## Moves camera to a simple above-and-behind view of the combat midpoint.
## Returns the Tween so callers can `await tween.finished`.
func enter_combat_mode(pos_a: Vector3, pos_b: Vector3) -> Tween:
	if _combat_locked:
		force_reset_combat_state()
	print("[Combat] pos_a=", pos_a, " pos_b=", pos_b)

	var mid: Vector3 = (pos_a + pos_b) / 2.0
	_pre_combat_transform = global_transform
	_pre_combat_zoom      = _target_zoom
	_pre_combat_fov       = fov
	_combat_locked        = true

	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()

	var direction:     Vector3 = (pos_b - pos_a).normalized()
	var perpendicular: Vector3 = Vector3(-direction.z, 0.0, direction.x)
	var current_offset: Vector3 = global_position - mid
	current_offset.y = 0.0
	if current_offset.length_squared() > 0.001 and current_offset.dot(perpendicular) < 0.0:
		perpendicular = -perpendicular
	var cam_pos: Vector3 = mid + perpendicular * COMBAT_SIDE_DIST + Vector3(0.0, COMBAT_HEIGHT, 0.0)
	var look_target: Vector3 = mid + Vector3(0.0, COMBAT_LOOK_UP, 0.0)
	var target_basis: Basis = Basis.looking_at(look_target - cam_pos, Vector3.UP)
	var target_transform := Transform3D(target_basis, cam_pos)
	_ensure_combat_light()
	if _combat_light != null:
		_combat_light.position = COMBAT_LIGHT_LOCAL_POS
		_combat_light.rotation = Vector3.ZERO
		_combat_light.visible = true
	_enable_combat_dof(cam_pos.distance_to(look_target))
	_active_tween = create_tween()
	_active_tween.set_parallel(true)
	_active_tween.tween_property(self, "global_transform", target_transform, COMBAT_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_active_tween.tween_property(self, "fov", COMBAT_FOV, COMBAT_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return _active_tween

## Returns Euler angles (degrees) for a node at `from` looking at `to`.
func _compute_look_at_rotation(from: Vector3, to: Vector3) -> Vector3:
	var basis := Basis.looking_at(to - from, Vector3.UP)
	return basis.get_euler() * (180.0 / PI)

## Smoothly pans to world_pos preserving current height and rotation.
## Skips silently if a combat sequence is still active.
func focus_on(world_pos: Vector3, zoom_height: float = -1.0) -> void:
	if _combat_locked or _showcase_locked:
		return
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	var current_height: float = zoom_height if zoom_height > 0.0 else global_position.y
	var pitch_radians: float = absf(deg_to_rad(rotation_degrees.x))
	var focus_distance: float = current_height / tan(pitch_radians) if pitch_radians > 0.001 else current_height
	var planar_forward: Vector3 = -global_basis.z
	planar_forward.y = 0.0
	if planar_forward.length_squared() < 0.001:
		planar_forward = Vector3(0.0, 0.0, -1.0)
	else:
		planar_forward = planar_forward.normalized()
	var desired_position: Vector3 = world_pos - planar_forward * focus_distance
	var target: Vector3 = Vector3(
		clampf(desired_position.x, _map_min.x, _map_max.x),
		current_height,
		clampf(desired_position.z, _map_min.z, _map_max.z)
	)
	# Sync lerp targets so _process converges to the same destination
	_target_pos.x = target.x
	_target_pos.z = target.z
	_target_zoom  = current_height
	_active_tween = create_tween()
	_active_tween.tween_property(self, "global_position", target, 1.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## Restores camera to its pre-combat state.
## Returns the Tween so callers can `await tween.finished` (duration: COMBAT_TIME).
func exit_combat_mode() -> Tween:
	if not _combat_locked:
		_disable_combat_dof(true)
		var idle_tween: Tween = create_tween()
		idle_tween.tween_interval(0.0)
		return idle_tween
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_disable_combat_dof()
	# Restore lerp targets so _process converges correctly once unlocked
	_target_pos  = Vector3(_pre_combat_transform.origin.x, 0.0, _pre_combat_transform.origin.z)
	_target_zoom = _pre_combat_zoom
	_active_tween = create_tween()
	_active_tween.set_parallel(true)
	_active_tween.tween_property(self, "global_transform", _pre_combat_transform, COMBAT_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_active_tween.tween_property(self, "fov", _pre_combat_fov, COMBAT_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_active_tween.chain().tween_callback(func():
		if _combat_light != null:
			_combat_light.queue_free()
			_combat_light = null
		_combat_locked = false
	)
	return _active_tween

func enter_showcase_mode(world_pos: Vector3, zoom_height: float = 1.72, focus_height: float = 0.78, showcase_fov: float = 58.0) -> Tween:
	if _combat_locked:
		var blocked_tween := create_tween()
		blocked_tween.tween_interval(0.0)
		return blocked_tween
	if _showcase_locked:
		exit_showcase_mode(true)
	_pre_showcase_transform = global_transform
	_pre_showcase_zoom = _target_zoom
	_pre_showcase_fov = fov
	_showcase_locked = true
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	var focus_target: Vector3 = world_pos + Vector3(0.0, focus_height, 0.0)
	var combat_like_offset: Vector3 = Vector3(0.0, zoom_height, 1.82)
	var desired_position: Vector3 = focus_target + combat_like_offset
	var target_pos: Vector3 = Vector3(
		clampf(desired_position.x, _map_min.x, _map_max.x),
		zoom_height,
		clampf(desired_position.z, _map_min.z, _map_max.z)
	)
	var target_basis: Basis = Basis.looking_at(focus_target - target_pos, Vector3.UP)
	var target_transform := Transform3D(target_basis, target_pos)
	_target_pos = Vector3(target_pos.x, 0.0, target_pos.z)
	_target_zoom = zoom_height
	_ensure_combat_light()
	if _combat_light != null:
		_combat_light.position = Vector3(0.0, 0.34, 0.12)
		_combat_light.rotation = Vector3.ZERO
		_combat_light.light_color = Color(1.0, 0.90, 0.78, 1.0)
		_combat_light.light_energy = 3.9
		_combat_light.spot_angle = 54.0
		_combat_light.spot_range = 9.0
		_combat_light.visible = true
	_enable_combat_dof(target_pos.distance_to(focus_target))
	_active_tween = create_tween()
	_active_tween.set_parallel(true)
	_active_tween.tween_property(self, "global_transform", target_transform, 0.55) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_active_tween.tween_property(self, "fov", showcase_fov, 0.55) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return _active_tween

func exit_showcase_mode(immediate: bool = false) -> Tween:
	if not _showcase_locked:
		var idle_tween := create_tween()
		idle_tween.tween_interval(0.0)
		return idle_tween
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_disable_combat_dof(immediate)
	if immediate:
		global_transform = _pre_showcase_transform
		_target_pos = Vector3(_pre_showcase_transform.origin.x, 0.0, _pre_showcase_transform.origin.z)
		_target_zoom = _pre_showcase_zoom
		fov = _pre_showcase_fov
		if _combat_light != null and is_instance_valid(_combat_light):
			_combat_light.queue_free()
			_combat_light = null
		_showcase_locked = false
		var done_tween := create_tween()
		done_tween.tween_interval(0.0)
		return done_tween
	_target_pos = Vector3(_pre_showcase_transform.origin.x, 0.0, _pre_showcase_transform.origin.z)
	_target_zoom = _pre_showcase_zoom
	_active_tween = create_tween()
	_active_tween.set_parallel(true)
	_active_tween.tween_property(self, "global_transform", _pre_showcase_transform, 0.42) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_active_tween.tween_property(self, "fov", _pre_showcase_fov, 0.42) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_active_tween.chain().tween_callback(func() -> void:
		if _combat_light != null and is_instance_valid(_combat_light):
			_combat_light.queue_free()
			_combat_light = null
		_showcase_locked = false
	)
	return _active_tween

func force_reset_combat_state(restore_transform: bool = true) -> void:
	var was_locked: bool = _combat_locked
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	if _combat_dof_tween != null and _combat_dof_tween.is_valid():
		_combat_dof_tween.kill()
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	if restore_transform and was_locked:
		global_transform = _pre_combat_transform
		_target_pos = Vector3(_pre_combat_transform.origin.x, 0.0, _pre_combat_transform.origin.z)
		_target_zoom = _pre_combat_zoom
		fov = _pre_combat_fov
	_restore_combat_dof_state(_pre_combat_dof_amount)
	if _combat_light != null and is_instance_valid(_combat_light):
		_combat_light.queue_free()
	_combat_light = null
	_drag_active = false
	_combat_locked = false
	_showcase_locked = false
	_manual_cinematic_lock = false
	h_offset = 0.0
	v_offset = 0.0

func set_manual_cinematic_lock(active: bool) -> void:
	if active and _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_drag_active = false
	_manual_cinematic_lock = active

func shake_combat(strength: float = 0.18, duration: float = 0.24) -> void:
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	h_offset = 0.0
	v_offset = 0.0
	var half_duration: float = maxf(duration * 0.5, 0.05)
	_shake_tween = create_tween()
	_shake_tween.set_parallel(true)
	_shake_tween.tween_method(
		func(weight: float) -> void:
			var amp: float = strength * (1.0 - weight * 0.35)
			h_offset = randf_range(-amp, amp)
			v_offset = randf_range(-amp * 0.55, amp * 0.55),
		0.0,
		1.0,
		half_duration
	)
	_shake_tween.chain()
	_shake_tween.tween_method(
		func(weight: float) -> void:
			var amp: float = strength * (1.0 - weight)
			h_offset = randf_range(-amp, amp)
			v_offset = randf_range(-amp * 0.55, amp * 0.55),
		0.0,
		1.0,
		half_duration
	)
	_shake_tween.finished.connect(func() -> void:
		h_offset = 0.0
		v_offset = 0.0
	)

# ─── Godot callbacks ─────────────────────────────────────────────────────────────
func _ready() -> void:
	if attributes == null:
		attributes = CameraAttributesPractical.new()
	_pre_combat_fov = fov
	if attributes is CameraAttributesPractical:
		_camera_attributes = attributes as CameraAttributesPractical
		_camera_attributes.dof_blur_amount = 0.0
		_camera_attributes.dof_blur_near_enabled = false
		_camera_attributes.dof_blur_far_enabled = false

func _ensure_combat_light() -> void:
	if _combat_light != null and is_instance_valid(_combat_light):
		return
	_combat_light = SpotLight3D.new()
	_combat_light.name = "CombatSpotLight"
	_combat_light.shadow_enabled = true
	_combat_light.light_color = Color(1.0, 0.78, 0.58, 1.0)
	_combat_light.light_energy = COMBAT_LIGHT_ENERGY
	_combat_light.spot_range = COMBAT_LIGHT_RANGE
	_combat_light.spot_angle = COMBAT_LIGHT_SPOT_ANGLE
	_combat_light.spot_angle_attenuation = 0.88
	_combat_light.spot_attenuation = 1.15
	_combat_light.shadow_bias = 0.02
	_combat_light.shadow_normal_bias = 0.55
	_combat_light.distance_fade_enabled = false
	_combat_light.visible = false
	add_child(_combat_light)

func _process(delta: float) -> void:
	if _combat_locked or _showcase_locked or _manual_cinematic_lock:
		return   # Tween controls the camera; skip lerp to avoid fighting it
	_handle_keyboard(delta)
	var t: float = minf(LERP_SPEED * delta, 1.0)
	position.x = lerpf(position.x, _target_pos.x, t)
	position.z = lerpf(position.z, _target_pos.z, t)
	position.y = lerpf(position.y, _target_zoom,  t)

func _unhandled_input(event: InputEvent) -> void:
	if _combat_locked or _showcase_locked or _manual_cinematic_lock:
		return   # Block all camera input during cinematic
	if event is InputEventMouseButton:
		var mbe: InputEventMouseButton = event as InputEventMouseButton
		match mbe.button_index:
			MOUSE_BUTTON_RIGHT:
				if mbe.pressed:
					var hit: Variant = _screen_to_ground(mbe.position)
					if hit != null:
						_drag_active = true
						_drag_last_world = hit as Vector3
				else:
					_drag_active = false
			MOUSE_BUTTON_WHEEL_UP:
				if mbe.pressed:
					_target_zoom = clampf(_target_zoom - ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
			MOUSE_BUTTON_WHEEL_DOWN:
				if mbe.pressed:
					_target_zoom = clampf(_target_zoom + ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
	elif event is InputEventMouseMotion and _drag_active:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		var hit: Variant = _screen_to_ground(motion.position)
		if hit == null:
			return
		var world_hit: Vector3 = hit as Vector3
		var delta_world: Vector3 = _drag_last_world - world_hit
		_target_pos.x += delta_world.x
		_target_pos.z += delta_world.z
		_clamp_target()
		_drag_last_world = world_hit

# ─── Internal ────────────────────────────────────────────────────────────────────
func _handle_keyboard(delta: float) -> void:
	var move: Vector2 = Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		move.y += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		move.y -= 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move.x += 1.0
	if move == Vector2.ZERO:
		return

	# Direction relative to current yaw so WASD always matches camera facing
	var yaw:     float   = rotation.y
	var forward: Vector3 = Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right:   Vector3 = Vector3( cos(yaw), 0.0, -sin(yaw))

	# Scale speed with zoom height so panning feels consistent at any zoom level
	var speed:        float   = MOVE_SPEED * (_target_zoom / 14.0)
	var displacement: Vector3 = (right * move.x + forward * move.y).normalized() * speed * delta
	_target_pos += displacement
	_clamp_target()

func _clamp_target() -> void:
	_target_pos.x = clampf(_target_pos.x, _map_min.x, _map_max.x)
	_target_pos.z = clampf(_target_pos.z, _map_min.z, _map_max.z)

func _screen_to_ground(screen_pos: Vector2) -> Variant:
	var origin: Vector3 = project_ray_origin(screen_pos)
	var direction: Vector3 = project_ray_normal(screen_pos)
	if absf(direction.y) < 0.0001:
		return null
	var t: float = -origin.y / direction.y
	if t < 0.0:
		return null
	return origin + direction * t

func _enable_combat_dof(focus_distance: float) -> void:
	if _camera_attributes == null:
		return
	if _combat_dof_tween != null and _combat_dof_tween.is_valid():
		_combat_dof_tween.kill()
	_pre_combat_dof_amount = _camera_attributes.dof_blur_amount
	_pre_combat_near_enabled = _camera_attributes.dof_blur_near_enabled
	_pre_combat_far_enabled = _camera_attributes.dof_blur_far_enabled
	_camera_attributes.dof_blur_near_enabled = true
	_camera_attributes.dof_blur_far_enabled = true
	_camera_attributes.dof_blur_near_distance = maxf(0.1, focus_distance - 0.55)
	_camera_attributes.dof_blur_near_transition = 0.85
	_camera_attributes.dof_blur_far_distance = focus_distance + 0.85
	_camera_attributes.dof_blur_far_transition = 2.2
	_combat_dof_tween = create_tween()
	_combat_dof_tween.tween_property(_camera_attributes, "dof_blur_amount", 0.28, 0.45) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _disable_combat_dof(immediate: bool = false) -> void:
	if _camera_attributes == null:
		return
	if _combat_dof_tween != null and _combat_dof_tween.is_valid():
		_combat_dof_tween.kill()
	if immediate:
		_restore_combat_dof_state(_pre_combat_dof_amount)
		return
	_combat_dof_tween = create_tween()
	_combat_dof_tween.tween_property(_camera_attributes, "dof_blur_amount", _pre_combat_dof_amount, 0.35) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_combat_dof_tween.tween_callback(func() -> void:
		_restore_combat_dof_state(_pre_combat_dof_amount)
	)

func _restore_combat_dof_state(target_amount: float) -> void:
	if _camera_attributes == null:
		return
	_camera_attributes.dof_blur_amount = target_amount
	_camera_attributes.dof_blur_near_enabled = _pre_combat_near_enabled
	_camera_attributes.dof_blur_far_enabled = _pre_combat_far_enabled
