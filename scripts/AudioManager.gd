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

# ─── Constants ──────────────────────────────────────────────────────────────────
const MIX_RATE := 22050.0

# ─── State ──────────────────────────────────────────────────────────────────────
var _player:        AudioStreamPlayer   # procedural synthesis (death, level-up, etc.)
var _sfx_player:    AudioStreamPlayer   # MP3 one-shot SFX
var _sfx_players:   Array[AudioStreamPlayer] = []
var _sfx_pool_index: int = 0
var _master_volume: float = 0.70
var _walk_toggle:   bool  = false
var _muted:         bool  = false
var _menu_button_sfx: AudioStream = null
var _combat_last_pitch: Dictionary = {}

const MENU_BUTTON_SFX_PATH := "res://assets/audio/sfx/ui/menu_button.mp3"
const SFX_POOL_SIZE := 5
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

# ─── Lifecycle ───────────────────────────────────────────────────────────────────
func _ready() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)
	for i: int in range(SFX_POOL_SIZE):
		var pooled_player := AudioStreamPlayer.new()
		add_child(pooled_player)
		_sfx_players.append(pooled_player)
	if not _sfx_players.is_empty():
		_sfx_player = _sfx_players[0]
	_sword_attack_sfx = [sfx_sword, sfx_sword_02, sfx_sword_03]
	_arrow_attack_sfx = [sfx_arrow, sfx_arrow_02, sfx_arrow_03]
	_lance_attack_sfx = [sfx_lance, sfx_lance_02, sfx_lance_03]
	_hurt_sfx = [sfx_hurt_01, sfx_hurt_02]
	_dodge_sfx = [sfx_dodge_01, sfx_dodge_02]
	_menu_button_sfx = _load_menu_button_sfx()

# ─── Public API ─────────────────────────────────────────────────────────────────
func set_volume(value: float) -> void:
	_master_volume = clampf(value, 0.0, 1.0)
	if _player != null:
		_player.volume_db = _target_volume_db()
	for sfx_player: AudioStreamPlayer in _sfx_players:
		if sfx_player != null:
			sfx_player.volume_db = _target_volume_db()

func set_muted(value: bool) -> void:
	_muted = value
	if _player != null:
		_player.volume_db = _target_volume_db()
	for sfx_player: AudioStreamPlayer in _sfx_players:
		if sfx_player != null:
			sfx_player.volume_db = _target_volume_db()

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

func play_hurt() -> void:
	_play_combat_sfx(_choose_stream(_hurt_sfx), -1, 0.96, 1.25)

func play_dodge() -> void:
	_play_combat_sfx(_choose_stream(_dodge_sfx), -1, 1.02, 0.4)

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

func _next_sfx_player() -> AudioStreamPlayer:
	if _sfx_players.is_empty():
		return null
	var sfx_player: AudioStreamPlayer = _sfx_players[_sfx_pool_index % _sfx_players.size()]
	_sfx_pool_index = (_sfx_pool_index + 1) % _sfx_players.size()
	return sfx_player

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

func _load_menu_button_sfx() -> AudioStream:
	if ResourceLoader.exists(MENU_BUTTON_SFX_PATH):
		var stream := load(MENU_BUTTON_SFX_PATH) as AudioStream
		if stream != null:
			return stream
	return sfx_button

# ─── Waveform helpers ────────────────────────────────────────────────────────────
func _append_sine(buf: PackedVector2Array, freq: float, dur: float, vol: float) -> void:
	var frames: int = int(MIX_RATE * dur)
	for i: int in range(frames):
		var t:   float = float(i) / MIX_RATE
		var env: float = 1.0 - float(i) / float(frames)
		var s:   float = sin(TAU * freq * t) * vol * env * _master_volume
		buf.append(Vector2(s, s))

func _emit(buf: PackedVector2Array) -> void:
	if buf.is_empty():
		return
	var dur:    float               = float(buf.size()) / MIX_RATE
	var stream: AudioStreamGenerator = AudioStreamGenerator.new()
	stream.mix_rate      = MIX_RATE
	stream.buffer_length = dur + 0.05
	_player.stream = stream
	_player.play()
	var pb: AudioStreamGeneratorPlayback = _player.get_stream_playback()
	if pb != null:
		pb.push_buffer(buf)

func _target_volume_db() -> float:
	return -80.0 if _muted or _master_volume <= 0.001 else linear_to_db(_master_volume)
