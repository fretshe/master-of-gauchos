extends Node

# ─── Streams ──────────────────────────────────────────────────────────────────
var music_menu   = preload("res://assets/menu.mp3")
var music_blue   = preload("res://assets/team_blue.mp3")
var music_red    = preload("res://assets/team_red.mp3")
var music_combat = preload("res://assets/combat.mp3")

# ─── State ────────────────────────────────────────────────────────────────────
var _player:            AudioStreamPlayer
var _volume:            float       = 0.8
var _pre_combat_stream: AudioStream = null
var _muted:             bool        = false

# ─── Lifecycle ────────────────────────────────────────────────────────────────
func _ready() -> void:
	_player           = AudioStreamPlayer.new()
	_player.volume_db = _target_volume_db()
	add_child(_player)
	# Enable looping on all tracks
	for s: AudioStream in [music_menu, music_blue, music_red, music_combat]:
		(s as AudioStreamMP3).loop = true

# ─── Public API ───────────────────────────────────────────────────────────────
func set_music_volume(value: float) -> void:
	_volume           = clampf(value, 0.0, 1.0)
	_player.volume_db = _target_volume_db()

func set_muted(value: bool) -> void:
	_muted = value
	if _player != null:
		_player.volume_db = _target_volume_db()

func is_muted() -> bool:
	return _muted

## Plays the title / menu track.
func play_menu_music() -> void:
	_play_stream(music_menu)

## Plays team_blue.mp3 for odd players and team_red.mp3 for even players.
func play_battle_music(player_id: int) -> void:
	_play_stream(music_blue if player_id % 2 == 1 else music_red)

## Saves the current track and switches to combat.mp3.
func play_combat_music() -> void:
	_pre_combat_stream = _player.stream
	_play_stream(music_combat)

## Fades back to whatever was playing before play_combat_music().
func stop_combat_music() -> void:
	if _pre_combat_stream != null:
		_play_stream(_pre_combat_stream)
		_pre_combat_stream = null

# ─── Internal ─────────────────────────────────────────────────────────────────
func _play_stream(stream: AudioStream) -> void:
	if _player.stream == stream and _player.playing:
		return
	_fade_transition(stream)

## Fire-and-forget coroutine: 1 s fade out → swap → 1 s fade in.
func _fade_transition(stream: AudioStream) -> void:
	if _player.playing:
		var tw_out: Tween = create_tween()
		tw_out.tween_property(_player, "volume_db", -80.0, 1.0)
		await tw_out.finished
	_player.stream    = stream
	_player.volume_db = -80.0
	_player.play()
	var tw_in: Tween = create_tween()
	tw_in.tween_property(_player, "volume_db", _target_volume_db(), 1.0)

func _target_volume_db() -> float:
	return -80.0 if _muted or _volume <= 0.001 else linear_to_db(_volume)
