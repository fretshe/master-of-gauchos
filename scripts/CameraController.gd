extends Camera2D

# ─── Constants ──────────────────────────────────────────────────────────────────
const MOVE_SPEED    := 400.0
const LERP_SPEED    := 8.0
const ZOOM_MIN      := 0.40
const ZOOM_MAX      := 2.00
const ZOOM_STEP     := 0.10
# Matches HexGrid.PERSP_SCALE_Y — compensates vertical scroll so moving up/down
# covers the same visual distance per second as moving left/right.
const PERSP_Y_SCALE := 0.65

# ─── State ──────────────────────────────────────────────────────────────────────
var _target_pos:  Vector2 = Vector2.ZERO
var _target_zoom: float   = 1.0

var _drag_active:    bool    = false
var _drag_origin:    Vector2 = Vector2.ZERO
var _drag_cam_start: Vector2 = Vector2.ZERO

var _combat_mode:     bool    = false
var _pre_combat_pos:  Vector2 = Vector2.ZERO
var _pre_combat_zoom: float   = 1.0

# ─── Public API ─────────────────────────────────────────────────────────────────
func center_on(world_pos: Vector2) -> void:
	_target_pos = world_pos
	_clamp_target()

func enter_combat_mode(unit_a_pos: Vector2, unit_b_pos: Vector2) -> void:
	_combat_mode    = true
	_pre_combat_pos  = _target_pos
	_pre_combat_zoom = _target_zoom
	var mid: Vector2 = unit_a_pos.lerp(unit_b_pos, 0.5)
	var tw: Tween = create_tween().set_parallel(true)
	tw.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "position", mid,              0.5)
	tw.tween_property(self, "zoom",     Vector2(2.0, 2.0), 0.5)
	await tw.finished
	_target_pos  = mid
	_target_zoom = 2.0

func exit_combat_mode() -> void:
	var tw: Tween = create_tween().set_parallel(true)
	tw.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "position", _pre_combat_pos,                    0.5)
	tw.tween_property(self, "zoom",     Vector2(_pre_combat_zoom, _pre_combat_zoom), 0.5)
	await tw.finished
	_target_pos  = _pre_combat_pos
	_target_zoom = _pre_combat_zoom
	_combat_mode = false

func set_map_bounds(width: float, height: float) -> void:
	limit_left   = 0
	limit_top    = 0
	limit_right  = int(width)
	limit_bottom = int(height)
	_clamp_target()

# ─── Godot callbacks ─────────────────────────────────────────────────────────────
func _ready() -> void:
	_target_pos  = position
	_target_zoom = zoom.x

func _process(delta: float) -> void:
	if _combat_mode:
		return
	_handle_keyboard(delta)
	# Smooth position
	position = position.lerp(_target_pos, minf(LERP_SPEED * delta, 1.0))
	# Smooth zoom
	var z: float = lerpf(zoom.x, _target_zoom, minf(LERP_SPEED * delta, 1.0))
	zoom = Vector2(z, z)

func _unhandled_input(event: InputEvent) -> void:
	if _combat_mode:
		return
	if event is InputEventMouseButton:
		var mbe: InputEventMouseButton = event as InputEventMouseButton
		if mbe.button_index == MOUSE_BUTTON_RIGHT:
			if mbe.pressed:
				_drag_active    = true
				_drag_origin    = mbe.position
				_drag_cam_start = _target_pos
			else:
				_drag_active = false
		elif mbe.button_index == MOUSE_BUTTON_WHEEL_UP and mbe.pressed:
			_target_zoom = clampf(_target_zoom + ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
		elif mbe.button_index == MOUSE_BUTTON_WHEEL_DOWN and mbe.pressed:
			_target_zoom = clampf(_target_zoom - ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)

	elif event is InputEventMouseMotion and _drag_active:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		var delta_screen: Vector2 = motion.position - _drag_origin
		_target_pos = _drag_cam_start - delta_screen / zoom.x
		_clamp_target()

# ─── Internal ────────────────────────────────────────────────────────────────────
func _handle_keyboard(delta: float) -> void:
	var dir: Vector2 = Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	if dir != Vector2.ZERO:
		var move: Vector2 = dir.normalized()
		move.y /= PERSP_Y_SCALE   # more world-Y per frame so visual scroll speed stays uniform
		_target_pos += move * MOVE_SPEED * delta / zoom.x
		_clamp_target()

func _clamp_target() -> void:
	var half: Vector2 = get_viewport_rect().size * 0.5 / zoom
	var lo_x: float   = float(limit_left)  + half.x
	var hi_x: float   = float(limit_right) - half.x
	var lo_y: float   = float(limit_top)   + half.y
	var hi_y: float   = float(limit_bottom) - half.y
	# Guard against tiny maps / extreme zoom-out
	_target_pos.x = clampf(_target_pos.x, minf(lo_x, hi_x), maxf(lo_x, hi_x))
	_target_pos.y = clampf(_target_pos.y, minf(lo_y, hi_y), maxf(lo_y, hi_y))
