extends Node

const SETTINGS_PATH := "user://settings.cfg"

var music_volume: float = 0.6
var sfx_volume:   float = 1.0
var tooltips_enabled: bool = true
var cell_context_enabled: bool = false

func _ready() -> void:
	load_settings()
	MusicManager.set_music_volume(music_volume)
	AudioManager.set_volume(sfx_volume)

func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	MusicManager.set_music_volume(music_volume)
	_save()

func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	AudioManager.set_volume(sfx_volume)
	_save()

func set_tooltips_enabled(enabled: bool) -> void:
	tooltips_enabled = bool(enabled)
	_save()

func set_cell_context_enabled(enabled: bool) -> void:
	cell_context_enabled = bool(enabled)
	_save()

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	music_volume = clampf(float(cfg.get_value("audio", "music_volume", 0.6)), 0.0, 1.0)
	sfx_volume   = clampf(float(cfg.get_value("audio", "sfx_volume",   1.0)), 0.0, 1.0)
	tooltips_enabled = bool(cfg.get_value("ui", "tooltips_enabled", true))
	cell_context_enabled = bool(cfg.get_value("ui", "cell_context_enabled", false))

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "sfx_volume",   sfx_volume)
	cfg.set_value("ui", "tooltips_enabled", tooltips_enabled)
	cfg.set_value("ui", "cell_context_enabled", cell_context_enabled)
	cfg.save(SETTINGS_PATH)
