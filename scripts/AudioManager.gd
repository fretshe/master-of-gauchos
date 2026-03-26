extends Node

# ─── Preloaded SFX ──────────────────────────────────────────────────────────────
var sfx_sword   = preload("res://assets/audio/sfx/combat/sword_hit.mp3")
var sfx_arrow   = preload("res://assets/audio/sfx/combat/arrow_hit.mp3")
var sfx_lance   = preload("res://assets/audio/sfx/combat/lance_hit.mp3")
var sfx_walk_01 = preload("res://assets/audio/sfx/movement/walk_01.mp3")
var sfx_walk_02 = preload("res://assets/audio/sfx/movement/walk_02.mp3")
var sfx_button  = preload("res://assets/audio/sfx/ui/button.mp3")
var sfx_capture = preload("res://assets/audio/sfx/ui/tower_capture.mp3")
var sfx_essence = preload("res://assets/audio/sfx/ui/essence_gain.mp3")
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
var _master_volume: float = 0.70
var _walk_toggle:   bool  = false

# ─── Lifecycle ───────────────────────────────────────────────────────────────────
func _ready() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)
	_sfx_player = AudioStreamPlayer.new()
	add_child(_sfx_player)

# ─── Public API ─────────────────────────────────────────────────────────────────
func set_volume(value: float) -> void:
	_master_volume = clampf(value, 0.0, 1.0)

## sword_hit for WARRIOR / MASTER, arrow_hit for ARCHER, lance_hit for LANCER / RIDER.
func play_attack(unit_type: int = -1) -> void:
	match unit_type:
		0: _play_sfx(sfx_sword)    # WARRIOR
		1: _play_sfx(sfx_arrow)    # ARCHER
		2: _play_sfx(sfx_lance)    # LANCER
		3: _play_sfx(sfx_lance)    # RIDER
		_: _play_sfx(sfx_sword)    # MASTER (unit_type == -1) or unknown

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
	_sfx_player.stream    = stream
	_sfx_player.volume_db = linear_to_db(_master_volume)
	_sfx_player.play()

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
