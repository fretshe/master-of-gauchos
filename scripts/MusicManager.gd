extends Node

# ─── Streams ──────────────────────────────────────────────────────────────────
var music_menu   = preload("res://assets/menu.mp3")
var music_blue   = preload("res://assets/team_blue.mp3")
var music_red    = preload("res://assets/team_red.mp3")
var music_combat = preload("res://assets/combat.mp3")

# ─── State ────────────────────────────────────────────────────────────────────
var _player:                  AudioStreamPlayer
var _combat_player:           AudioStreamPlayer
var _volume:                  float       = 0.8
var _muted:                   bool        = false
var _combat_ducked:           bool        = false
var _transition_tween:        Tween       = null
var _combat_transition_tween: Tween       = null

# ─── Lifecycle ────────────────────────────────────────────────────────────────
func _ready() -> void:
	_player           = AudioStreamPlayer.new()
	_player.volume_db = _target_volume_db()
	add_child(_player)
	_combat_player = AudioStreamPlayer.new()
	_combat_player.stream = music_combat
	_combat_player.volume_db = -80.0
	add_child(_combat_player)
	# Enable looping on all tracks
	for s: AudioStream in [music_menu, music_blue, music_red, music_combat]:
		(s as AudioStreamMP3).loop = true

# ─── Public API ───────────────────────────────────────────────────────────────
func set_music_volume(value: float) -> void:
	_volume           = clampf(value, 0.0, 1.0)
	if _player == null:
		return
	if _combat_ducked:
		if _combat_player != null:
			_combat_player.volume_db = _target_volume_db()
		return
	_player.volume_db = _target_volume_db()

func set_muted(value: bool) -> void:
	_muted = value
	if _player != null:
		if _combat_ducked:
			_player.volume_db = _duck_volume_db()
		else:
			_player.volume_db = _target_volume_db()
	if _combat_player != null:
		if _muted:
			_combat_player.volume_db = -80.0
		else:
			_combat_player.volume_db = _target_volume_db()

func is_muted() -> bool:
	return _muted

## Plays the title / menu track.
func play_menu_music() -> void:
	_play_stream(music_menu)

## Plays team_blue.mp3 for odd players and team_red.mp3 for even players.
func play_battle_music(player_id: int) -> void:
	_play_stream(music_blue if player_id % 2 == 1 else music_red)

## Lowers the current turn music smoothly during combat.
func play_combat_music() -> void:
	if _player == null or _combat_ducked:
		return
	_combat_ducked = true
	_fade_player_to(_duck_volume_db(), 0.45)
	if _combat_player != null:
		_fade_combat_in(0.45)

## Restores the current turn music after combat ends.
func stop_combat_music() -> void:
	if _player == null or not _combat_ducked:
		return
	_combat_ducked = false
	_fade_player_to(_target_volume_db(), 0.65)
	if _combat_player != null:
		_fade_combat_out(0.45)

# ─── Internal ─────────────────────────────────────────────────────────────────
func _play_stream(stream: AudioStream) -> void:
	if _player.stream == stream and _player.playing:
		return
	_fade_transition(stream)

## Fire-and-forget coroutine: 1 s fade out → swap → 1 s fade in.
func _fade_transition(stream: AudioStream) -> void:
	_kill_transition_tween()
	if _player.playing:
		_transition_tween = create_tween()
		_transition_tween.tween_property(_player, "volume_db", -80.0, 1.0)
		await _transition_tween.finished
	_player.stream    = stream
	_player.volume_db = -80.0
	_player.play()
	_transition_tween = create_tween()
	var target_db: float = _target_volume_db()
	if _combat_ducked:
		target_db = _duck_volume_db()
	_transition_tween.tween_property(_player, "volume_db", target_db, 1.0)

func _target_volume_db() -> float:
	return -80.0 if _muted or _volume <= 0.001 else linear_to_db(_volume)

func _duck_volume_db() -> float:
	return -80.0

func _fade_player_to(target_db: float, duration: float) -> void:
	if _player == null:
		return
	_kill_transition_tween()
	_transition_tween = create_tween()
	_transition_tween.tween_property(_player, "volume_db", target_db, duration)

func _fade_combat_in(duration: float) -> void:
	if _combat_player == null:
		return
	_kill_combat_transition_tween()
	if _muted:
		_combat_player.volume_db = -80.0
	if not _combat_player.playing:
		_combat_player.play()
	_combat_transition_tween = create_tween()
	_combat_transition_tween.tween_property(_combat_player, "volume_db", _target_volume_db(), duration)

func _fade_combat_out(duration: float) -> void:
	if _combat_player == null:
		return
	_kill_combat_transition_tween()
	_combat_transition_tween = create_tween()
	_combat_transition_tween.tween_property(_combat_player, "volume_db", -80.0, duration)
	_combat_transition_tween.finished.connect(func() -> void:
		if _combat_player != null:
			_combat_player.stop()
	)

func _kill_transition_tween() -> void:
	if _transition_tween != null and is_instance_valid(_transition_tween):
		_transition_tween.kill()
	_transition_tween = null

func _kill_combat_transition_tween() -> void:
	if _combat_transition_tween != null and is_instance_valid(_combat_transition_tween):
		_combat_transition_tween.kill()
	_combat_transition_tween = null
