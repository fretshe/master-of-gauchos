extends Node

# ─── Preloaded SFX ──────────────────────────────────────────────────────────────
var sfx_sword   = preload("res://assets/audio/sfx/combat/sword_hit.mp3")
var sfx_sword_02 = preload("res://assets/audio/sfx/combat/sword_hit_02.mp3")
var sfx_sword_03 = preload("res://assets/audio/sfx/combat/sword_hit_03.mp3")
var sfx_arrow   = preload("res://assets/audio/sfx/combat/arrow_hit.mp3")
var sfx_arrow_02 = preload("res://assets/audio/sfx/combat/arrow_hit_02.mp3")
var sfx_arrow_03 = preload("res://assets/audio/sfx/combat/arrow_hit_03.mp3")
var sfx_lance   = preload("res://assets/audio/sfx/combat/lance_hit.mp3")
var sfx_lance_02 = preload("res://assets/audio/sfx/combat/lance_hit_02.mp3")
var sfx_lance_03 = preload("res://assets/audio/sfx/combat/lance_hit_03.mp3")
var sfx_critical_hit = preload("res://assets/audio/sfx/combat/critical_hit.mp3")
var sfx_super_critical_hit: AudioStream = null
var sfx_super_critical_charge: AudioStream = null
var sfx_heavy_impact = preload("res://assets/audio/sfx/combat/heavy_impact.mp3")
var sfx_massive_impact = preload("res://assets/audio/sfx/combat/massive_impact.mp3")
var sfx_crowd_crit = preload("res://assets/audio/sfx/combat/crowd_crit.mp3")
var sfx_crowd_crit_2 = preload("res://assets/audio/sfx/combat/crowd_crit_2.mp3")
var sfx_crowd_crit_3 = preload("res://assets/audio/sfx/combat/crowd_crit_3.mp3")
var sfx_crowd_gold = preload("res://assets/audio/sfx/combat/crowd_gold.mp3")
var sfx_crowd_gold_2 = preload("res://assets/audio/sfx/combat/crowd_gold_2.mp3")
var sfx_crowd_master = preload("res://assets/audio/sfx/combat/crowd_master.mp3")
var sfx_crowd_super_crit_01: AudioStream = null
var sfx_crowd_super_crit_02: AudioStream = null
var sfx_crowd_super_crit_03: AudioStream = null
var sfx_sapucay_crit = preload("res://assets/audio/sfx/combat/sapucay_crit.mp3")
var sfx_hurt_01 = preload("res://assets/audio/sfx/combat/hurt_01.mp3")
var sfx_hurt_02 = preload("res://assets/audio/sfx/combat/hurt_02.mp3")
var sfx_dodge_01 = preload("res://assets/audio/sfx/combat/dodge_01.mp3")
var sfx_dodge_02 = preload("res://assets/audio/sfx/combat/dodge_02.mp3")
var sfx_walk_01 = preload("res://assets/audio/sfx/movement/walk_01.mp3")
var sfx_walk_02 = preload("res://assets/audio/sfx/movement/walk_02.mp3")
var sfx_button  = preload("res://assets/audio/sfx/ui/button.mp3")
var sfx_capture = preload("res://assets/audio/sfx/ui/tower_capture.mp3")
var sfx_essence = preload("res://assets/audio/sfx/ui/essence_gain.mp3")
var sfx_level_up = preload("res://assets/audio/sfx/ui/level_up.mp3")
var sfx_summon  = preload("res://assets/audio/sfx/ui/summon.mp3")
var sfx_card_essence = preload("res://assets/audio/sfx/cards/card_essence.mp3")
var sfx_card_heal    = preload("res://assets/audio/sfx/cards/card_heal.mp3")
var sfx_card_damage  = preload("res://assets/audio/sfx/cards/card_damage.mp3")
var sfx_card_exp     = preload("res://assets/audio/sfx/cards/card_exp.mp3")
var sfx_dice_critical_01 = preload("res://assets/audio/sfx/dice/dice_critical_01.mp3")
var sfx_dice_critical_02 = preload("res://assets/audio/sfx/dice/dice_critical_02.mp3")
var sfx_day_rooster_01 = preload("res://assets/audio/ambient/day_night/day_rooster_01.mp3")
var sfx_night_owl_01 = preload("res://assets/audio/ambient/day_night/night_owl_01.mp3")
var sfx_night_owl_02 = preload("res://assets/audio/ambient/day_night/night_owl_02.mp3")
var sfx_day_birds_01 = preload("res://assets/audio/ambient/day_night/day_birds_01.mp3")
var sfx_day_birds_02 = preload("res://assets/audio/ambient/day_night/day_birds_02.mp3")
var sfx_day_birds_03 = preload("res://assets/audio/ambient/day_night/day_birds_03.mp3")
var sfx_day_birds_04 = preload("res://assets/audio/ambient/day_night/day_birds_04.mp3")
var sfx_night_crickets_01 = preload("res://assets/audio/ambient/day_night/night_crickets_01.mp3")
var sfx_night_crickets_02 = preload("res://assets/audio/ambient/day_night/night_crickets_02.mp3")
var sfx_night_crickets_03 = preload("res://assets/audio/ambient/day_night/night_crickets_03.mp3")
var sfx_wind_01 = preload("res://assets/audio/ambient/day_night/wind_01.mp3")
var sfx_wind_02 = preload("res://assets/audio/ambient/day_night/wind_02.mp3")
var sfx_wind_03 = preload("res://assets/audio/ambient/day_night/wind_03.mp3")
var sfx_wind_04 = preload("res://assets/audio/ambient/day_night/wind_04.mp3")
var sfx_wind_05 = preload("res://assets/audio/ambient/day_night/wind_05.mp3")
var sfx_wind_06 = preload("res://assets/audio/ambient/day_night/wind_06.mp3")

# ─── Constants ──────────────────────────────────────────────────────────────────
const MIX_RATE := 22050.0

# ─── State ──────────────────────────────────────────────────────────────────────
var _player:          AudioStreamPlayer   # procedural synthesis (death, level-up, etc.)
var _dice_player:     AudioStreamPlayer
var _dice_aux_player: AudioStreamPlayer
var _sfx_player:      AudioStreamPlayer   # MP3 one-shot SFX
var _sfx_players:     Array[AudioStreamPlayer] = []
var _sfx_pool_index:  int = 0
var _crowd_players:   Array[AudioStreamPlayer] = []
var _crowd_pool_index: int = 0
var _sapucay_player:  AudioStreamPlayer   # dedicated player for sapucay — never interrupted
var _master_volume: float = 0.70
var _walk_toggle:   bool  = false
var _muted:         bool  = false
var _menu_button_sfx: AudioStream = null
var _combat_last_pitch: Dictionary = {}

const MENU_BUTTON_SFX_PATH := "res://assets/audio/sfx/ui/menu_button.mp3"
const SFX_POOL_SIZE := 8
const CROWD_POOL_SIZE := 4
const COMBAT_PITCH_RANGES := {
	-1: Vector2(0.95, 1.03),
	0: Vector2(0.94, 1.04),
	1: Vector2(0.98, 1.08),
	2: Vector2(0.92, 1.00),
	3: Vector2(0.90, 0.98),
}
const COMBAT_VOLUME_JITTER_DB := 1.6
var _sword_attack_sfx: Array[AudioStream] = []
var _arrow_attack_sfx: Array[AudioStream] = []
var _lance_attack_sfx: Array[AudioStream] = []
var _hurt_sfx: Array[AudioStream] = []
var _dodge_sfx: Array[AudioStream] = []
var _crowd_crit_sfx: Array[AudioStream] = []
var _crowd_gold_sfx: Array[AudioStream] = []
var _crowd_super_crit_sfx: Array[AudioStream] = []
var _dice_critical_sfx: Array[AudioStream] = []
var _day_birds_sfx: Array[AudioStream] = []
var _night_owl_sfx: Array[AudioStream] = []
var _night_crickets_sfx: Array[AudioStream] = []
var _wind_sfx: Array[AudioStream] = []
var _dice_critical_index: int = 0

# ─── Lifecycle ───────────────────────────────────────────────────────────────────
func _ready() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)
	_dice_player = AudioStreamPlayer.new()
	add_child(_dice_player)
	_dice_aux_player = AudioStreamPlayer.new()
	add_child(_dice_aux_player)
	for i: int in range(SFX_POOL_SIZE):
		var pooled_player := AudioStreamPlayer.new()
		add_child(pooled_player)
		_sfx_players.append(pooled_player)
	for i: int in range(CROWD_POOL_SIZE):
		var crowd_player := AudioStreamPlayer.new()
		add_child(crowd_player)
		_crowd_players.append(crowd_player)
	if not _sfx_players.is_empty():
		_sfx_player = _sfx_players[0]
	_sapucay_player = AudioStreamPlayer.new()
	_sapucay_player.volume_db = _target_volume_db()
	add_child(_sapucay_player)
	_sword_attack_sfx = [sfx_sword, sfx_sword_02, sfx_sword_03]
	_arrow_attack_sfx = [sfx_arrow, sfx_arrow_02, sfx_arrow_03]
	_lance_attack_sfx = [sfx_lance, sfx_lance_02, sfx_lance_03]
	_hurt_sfx = [sfx_hurt_01, sfx_hurt_02]
	_dodge_sfx = [sfx_dodge_01, sfx_dodge_02]
	sfx_super_critical_charge = load("res://assets/audio/sfx/combat/super_critical_charge_01.mp3") as AudioStream
	if sfx_super_critical_charge == null:
		sfx_super_critical_charge = load("res://assets/audio/sfx/combat/super_critical_charge_02.mp3") as AudioStream
	sfx_super_critical_hit = load("res://assets/audio/sfx/combat/super_critical_hit.mp3") as AudioStream
	sfx_crowd_super_crit_01 = load("res://assets/audio/sfx/combat/crowd_super_crit_01.mp3") as AudioStream
	sfx_crowd_super_crit_02 = load("res://assets/audio/sfx/combat/crowd_super_crit_02.mp3") as AudioStream
	sfx_crowd_super_crit_03 = load("res://assets/audio/sfx/combat/crowd_super_crit_03.mp3") as AudioStream
	_crowd_crit_sfx = [sfx_crowd_crit, sfx_crowd_crit_2, sfx_crowd_crit_3]
	_crowd_gold_sfx = [sfx_crowd_gold, sfx_crowd_gold_2]
	_crowd_super_crit_sfx.clear()
	for stream: AudioStream in [sfx_crowd_super_crit_01, sfx_crowd_super_crit_02, sfx_crowd_super_crit_03]:
		if stream != null:
			_crowd_super_crit_sfx.append(stream)
	_dice_critical_sfx = [sfx_dice_critical_01, sfx_dice_critical_02]
	_day_birds_sfx = [sfx_day_birds_01, sfx_day_birds_02, sfx_day_birds_03, sfx_day_birds_04]
	_night_owl_sfx = [sfx_night_owl_01, sfx_night_owl_02]
	_night_crickets_sfx = [sfx_night_crickets_01, sfx_night_crickets_02, sfx_night_crickets_03]
	_wind_sfx = [sfx_wind_01, sfx_wind_02, sfx_wind_03, sfx_wind_04, sfx_wind_05, sfx_wind_06]
	_menu_button_sfx = _load_menu_button_sfx()

# ─── Public API ─────────────────────────────────────────────────────────────────
func set_volume(value: float) -> void:
	_master_volume = clampf(value, 0.0, 1.0)
	if _player != null:
		_player.volume_db = _target_volume_db()
	if _dice_player != null:
		_dice_player.volume_db = _target_volume_db()
	if _dice_aux_player != null:
		_dice_aux_player.volume_db = _target_volume_db()
	for sfx_player: AudioStreamPlayer in _sfx_players:
		if sfx_player != null:
			sfx_player.volume_db = _target_volume_db()
	for crowd_player: AudioStreamPlayer in _crowd_players:
		if crowd_player != null:
			crowd_player.volume_db = _target_volume_db()
	if _sapucay_player != null:
		_sapucay_player.volume_db = _target_volume_db()

func set_muted(value: bool) -> void:
	_muted = value
	if _player != null:
		_player.volume_db = _target_volume_db()
	if _dice_player != null:
		_dice_player.volume_db = _target_volume_db()
	if _dice_aux_player != null:
		_dice_aux_player.volume_db = _target_volume_db()
	for sfx_player: AudioStreamPlayer in _sfx_players:
		if sfx_player != null:
			sfx_player.volume_db = _target_volume_db()
	for crowd_player: AudioStreamPlayer in _crowd_players:
		if crowd_player != null:
			crowd_player.volume_db = _target_volume_db()
	if _sapucay_player != null:
		_sapucay_player.volume_db = _target_volume_db()

func is_muted() -> bool:
	return _muted

## sword_hit for WARRIOR / MASTER, arrow_hit for ARCHER, lance_hit for LANCER / RIDER.
func play_attack(unit_type: int = -1) -> void:
	match unit_type:
		0: _play_combat_sfx(_choose_stream(_sword_attack_sfx), unit_type)    # WARRIOR
		1: _play_combat_sfx(_choose_stream(_arrow_attack_sfx), unit_type)    # ARCHER
		2: _play_combat_sfx(_choose_stream(_lance_attack_sfx), unit_type)    # LANCER
		3: _play_combat_sfx(_choose_stream(_lance_attack_sfx), unit_type)    # RIDER
		_: _play_combat_sfx(_choose_stream(_sword_attack_sfx), unit_type)    # MASTER (unit_type == -1) or unknown

func play_critical() -> void:
	_play_combat_sfx(sfx_critical_hit, -1, 1.0, 0.9)

func play_super_critical() -> void:
	if sfx_super_critical_hit != null:
		_play_combat_sfx(sfx_super_critical_hit, -1, 0.98, 2.8)
	else:
		_play_combat_sfx(sfx_critical_hit, -1, 0.92, 2.5)
	_play_layered_sfx(sfx_massive_impact, 0.94, 2.2, false)

func play_super_critical_charge() -> void:
	if sfx_super_critical_charge == null:
		return
	_play_combat_sfx(sfx_super_critical_charge, -1, 1.0, 1.8)

func play_heavy_impact() -> void:
	_play_combat_sfx(sfx_heavy_impact, -1, 1.0, 1.4)

func play_massive_impact() -> void:
	_play_combat_sfx(sfx_massive_impact, -1, 0.98, 1.9)

func play_crowd_crit() -> void:
	_play_layered_sfx(_choose_stream(_crowd_crit_sfx), 1.0, 2.45, true)

func play_crowd_gold() -> void:
	_play_layered_sfx(_choose_stream(_crowd_gold_sfx), 1.0, 1.85, true)

func play_crowd_master() -> void:
	_play_layered_sfx(sfx_crowd_master, 1.0, 1.65, true)

func play_crowd_super_critical() -> void:
	var stream: AudioStream = _choose_stream(_crowd_super_crit_sfx)
	if stream == null:
		return
	for crowd_player: AudioStreamPlayer in _crowd_players:
		if crowd_player != null and crowd_player.playing:
			crowd_player.stop()
	_play_layered_sfx(stream, 1.0, 3.0, true)

func play_sapucay_crit() -> void:
	if _sapucay_player == null or sfx_sapucay_crit == null:
		return
	_sapucay_player.stream    = sfx_sapucay_crit
	_sapucay_player.pitch_scale = 1.0
	_sapucay_player.volume_db = _target_volume_db() + 1.30
	_sapucay_player.play()

func play_hurt() -> void:
	_play_combat_sfx(_choose_stream(_hurt_sfx), -1, 0.96, 1.25)

func play_dodge() -> void:
	_play_combat_sfx(_choose_stream(_dodge_sfx), -1, 1.02, 0.4)

func play_dice_roll() -> void:
	var buf: PackedVector2Array = PackedVector2Array()
	var pulses: int = 9
	for i: int in range(pulses):
		var pitch_bias: float = 1.0 - float(i) / float(pulses) * 0.18
		var freq: float = randf_range(210.0, 420.0) * pitch_bias
		_append_wave(buf, freq, 0.032, 0.045, "triangle")
		_append_wave(buf, freq * 0.52, 0.016, 0.028, "square")
	_append_silence(buf, 0.02)
	_emit_to_player(buf, _dice_player, -9.5)

func play_dice_reveal() -> void:
	var buf: PackedVector2Array = PackedVector2Array()
	_append_wave(buf, 660.0, 0.06, 0.075, "sine")
	_append_wave(buf, 880.0, 0.09, 0.06, "triangle")
	_emit_to_player(buf, _dice_player, -8.0)

func play_dice_critical() -> void:
	var dice_critical_stream: AudioStream = _next_dice_critical_stream()
	if dice_critical_stream != null:
		if _dice_aux_player == null:
			return
		_dice_aux_player.stream = dice_critical_stream
		_dice_aux_player.pitch_scale = 1.0
		_dice_aux_player.volume_db = _target_volume_db() - 10.5
		_dice_aux_player.play()
		return
	var buf: PackedVector2Array = PackedVector2Array()
	_append_wave(buf, 1174.66, 0.07, 0.12, "sine")
	_append_wave(buf, 1567.98, 0.09, 0.10, "sine")
	_append_wave(buf, 2093.00, 0.14, 0.08, "triangle")
	_emit_to_player(buf, _dice_aux_player, 1.5)

## Alternates between walk_01 and walk_02 each call.
func play_move() -> void:
	_walk_toggle = not _walk_toggle
	_play_sfx(sfx_walk_01 if _walk_toggle else sfx_walk_02)

## Tower captured.
func play_capture() -> void:
	_play_sfx(sfx_capture)

## Essence income at turn start.
func play_essence() -> void:
	_play_sfx(sfx_essence)

## UI button click.
func play_button() -> void:
	_play_sfx(sfx_button)

## Main menu / new game menu button click.
func play_menu_button() -> void:
	_play_sfx(_menu_button_sfx if _menu_button_sfx != null else sfx_button)

## Descending pitch slide — unit defeated.
func play_death() -> void:
	var buf:    PackedVector2Array = PackedVector2Array()
	var dur:    float              = 0.35
	var frames: int                = int(MIX_RATE * dur)
	var phase:  float              = 0.0
	for i: int in range(frames):
		var pct:  float = float(i) / float(frames)
		var freq: float = lerp(440.0, 110.0, pct)
		phase          += TAU * freq / MIX_RATE
		var env: float  = 1.0 - pct
		var s:   float  = sin(phase) * 0.30 * env * _master_volume
		buf.append(Vector2(s, s))
	_emit(buf)

## Rising pentatonic run ending on a sustained note — level up.
func play_level_up() -> void:
	if sfx_level_up != null:
		_play_sfx(sfx_level_up)
		return
	var buf: PackedVector2Array = PackedVector2Array()
	_append_sine(buf, 261.63, 0.06, 0.26)
	_append_sine(buf, 329.63, 0.06, 0.26)
	_append_sine(buf, 392.00, 0.06, 0.26)
	_append_sine(buf, 523.25, 0.06, 0.26)
	_append_sine(buf, 659.25, 0.18, 0.24)
	_emit(buf)

## Soft two-note chime — turn changes.
func play_turn_change() -> void:
	var buf: PackedVector2Array = PackedVector2Array()
	_append_sine(buf, 392.00, 0.08, 0.18)
	_append_sine(buf, 523.25, 0.10, 0.14)
	_emit(buf)

## Unit summoned.
func play_summon() -> void:
	_play_sfx(sfx_summon)

func play_card(card_type: String) -> void:
	match card_type:
		"essence":
			_play_sfx(sfx_card_essence)
		"heal":
			_play_sfx(sfx_card_heal)
		"damage":
			_play_sfx(sfx_card_damage)
		"exp":
			_play_sfx(sfx_card_exp)
		"refresh":
			_play_sfx(sfx_card_heal)

func play_day_night_transition(is_night: bool) -> void:
	if is_night:
		_play_layered_sfx(_choose_stream(_night_owl_sfx), randf_range(0.98, 1.04), -4.5)
	else:
		_play_layered_sfx(sfx_day_rooster_01, randf_range(0.98, 1.03), -3.5)

func play_day_night_ambient(is_night: bool) -> void:
	var roll: float = randf()
	if roll < 0.46:
		_play_layered_sfx(_choose_stream(_wind_sfx), randf_range(0.96, 1.04), -19.5)
		return
	if is_night:
		_play_layered_sfx(_choose_stream(_night_crickets_sfx), randf_range(0.98, 1.03), -15.0)
	else:
		_play_layered_sfx(_choose_stream(_day_birds_sfx), randf_range(0.98, 1.06), -12.5)

# ─── Helpers ─────────────────────────────────────────────────────────────────────
func _play_sfx(stream: AudioStream) -> void:
	var sfx_player: AudioStreamPlayer = _next_sfx_player()
	if sfx_player == null:
		return
	sfx_player.stream = stream
	sfx_player.pitch_scale = 1.0
	sfx_player.volume_db = _target_volume_db()
	sfx_player.play()

func _play_combat_sfx(stream: AudioStream, unit_type: int, base_pitch: float = 1.0, extra_volume_db: float = 0.0) -> void:
	var sfx_player: AudioStreamPlayer = _next_sfx_player()
	if sfx_player == null or stream == null:
		return
	sfx_player.stream = stream
	sfx_player.pitch_scale = _next_combat_pitch(unit_type) * base_pitch
	sfx_player.volume_db = _target_volume_db() + randf_range(-COMBAT_VOLUME_JITTER_DB, 0.35) + extra_volume_db
	sfx_player.play()

func _play_layered_sfx(stream: AudioStream, pitch: float = 1.0, extra_volume_db: float = 0.0, use_crowd_pool: bool = false) -> void:
	var sfx_player: AudioStreamPlayer = _next_crowd_player() if use_crowd_pool else _next_sfx_player()
	if sfx_player == null or stream == null:
		return
	sfx_player.stream = stream
	sfx_player.pitch_scale = pitch
	sfx_player.volume_db = _target_volume_db() + extra_volume_db
	sfx_player.play()

func _next_sfx_player() -> AudioStreamPlayer:
	if _sfx_players.is_empty():
		return null
	var sfx_player: AudioStreamPlayer = _sfx_players[_sfx_pool_index % _sfx_players.size()]
	_sfx_pool_index = (_sfx_pool_index + 1) % _sfx_players.size()
	return sfx_player

func _next_crowd_player() -> AudioStreamPlayer:
	if _crowd_players.is_empty():
		return _next_sfx_player()
	var crowd_player: AudioStreamPlayer = _crowd_players[_crowd_pool_index % _crowd_players.size()]
	_crowd_pool_index = (_crowd_pool_index + 1) % _crowd_players.size()
	return crowd_player

func _next_combat_pitch(unit_type: int) -> float:
	var pitch_range: Vector2 = COMBAT_PITCH_RANGES.get(unit_type, COMBAT_PITCH_RANGES[-1])
	var pitch: float = randf_range(pitch_range.x, pitch_range.y)
	var last_pitch: float = float(_combat_last_pitch.get(unit_type, -1.0))
	if last_pitch > 0.0 and absf(pitch - last_pitch) < 0.018:
		pitch = clampf(
			pitch + (0.022 if pitch < ((pitch_range.x + pitch_range.y) * 0.5) else -0.022),
			pitch_range.x,
			pitch_range.y
		)
	_combat_last_pitch[unit_type] = pitch
	return pitch

func _choose_stream(streams: Array[AudioStream]) -> AudioStream:
	if streams.is_empty():
		return null
	return streams[randi() % streams.size()]

func _next_dice_critical_stream() -> AudioStream:
	if _dice_critical_sfx.is_empty():
		return null
	var stream: AudioStream = _dice_critical_sfx[_dice_critical_index % _dice_critical_sfx.size()]
	_dice_critical_index = (_dice_critical_index + 1) % _dice_critical_sfx.size()
	return stream

func _load_menu_button_sfx() -> AudioStream:
	if ResourceLoader.exists(MENU_BUTTON_SFX_PATH):
		var stream := load(MENU_BUTTON_SFX_PATH) as AudioStream
		if stream != null:
			return stream
	return sfx_button

# ─── Waveform helpers ────────────────────────────────────────────────────────────
func _append_sine(buf: PackedVector2Array, freq: float, dur: float, vol: float) -> void:
	_append_wave(buf, freq, dur, vol, "sine")

func _append_wave(buf: PackedVector2Array, freq: float, dur: float, vol: float, wave_type: String = "sine") -> void:
	var frames: int = int(MIX_RATE * dur)
	for i: int in range(frames):
		var t:   float = float(i) / MIX_RATE
		var env: float = 1.0 - float(i) / float(frames)
		var phase: float = TAU * freq * t
		var raw: float = sin(phase)
		match wave_type:
			"square":
				raw = 1.0 if raw >= 0.0 else -1.0
			"triangle":
				raw = asin(sin(phase)) * (2.0 / PI)
			_:
				raw = sin(phase)
		var s: float = raw * vol * env * _master_volume
		buf.append(Vector2(s, s))

func _emit(buf: PackedVector2Array) -> void:
	_emit_to_player(buf, _player)

func _append_silence(buf: PackedVector2Array, dur: float) -> void:
	var frames: int = int(MIX_RATE * dur)
	for _i: int in range(frames):
		buf.append(Vector2.ZERO)

func _emit_to_player(buf: PackedVector2Array, player: AudioStreamPlayer, extra_volume_db: float = 0.0) -> void:
	if buf.is_empty():
		return
	if player == null:
		return
	var dur:    float               = float(buf.size()) / MIX_RATE
	var stream: AudioStreamGenerator = AudioStreamGenerator.new()
	stream.mix_rate      = MIX_RATE
	stream.buffer_length = dur + 0.05
	player.stream = stream
	player.volume_db = _target_volume_db() + extra_volume_db
	player.play()
	var pb: AudioStreamGeneratorPlayback = player.get_stream_playback()
	if pb != null:
		pb.push_buffer(buf)

func _target_volume_db() -> float:
	return -80.0 if _muted or _master_volume <= 0.001 else linear_to_db(_master_volume)
