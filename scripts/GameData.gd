extends Node

const META_SAVE_PATH := "user://meta_progression.dat"
const BUILD_VERSION_LABEL := "Beta 0.1.1"
const BUILD_VERSION_CODE := "0.1.1"
const FONT_OPTIONS := {
	"normal": {
		"label": "Normal",
		"theme_path": "res://themes/normal_theme.tres",
		"font_path": "res://assets/fonts/tahoma.ttf",
	},
	"pixel": {
		"label": "Pixel",
		"theme_path": "res://themes/pixelon_theme.tres",
		"font_path": "res://assets/fonts/Pixelon-E4JEg.otf",
	},
}
const PATCH_NOTES := {
	"version": "Beta 0.1.1",
	"title": "Primer build con continuidad entre partidas",
	"date": "2026-03-27",
	"sections": [
		{
			"title": "Novedades",
			"items": [
				"Nuevo sistema de guardado durante la partida.",
				"Se agrego la opcion Guardar y salir en el menu de pausa.",
				"Continuar desde el menu principal ahora recupera una partida valida en progreso.",
				"Se implemento la primera capa de progresion meta con desbloqueos entre partidas.",
			],
		},
		{
			"title": "Balance y contenido",
			"items": [
				"Se incorporo el ejemplo de desbloqueo Alijo Gaucho.",
				"Al jugar 5 partidas con Gauchos como Jugador 1 se habilita una carta especial para futuras runs.",
			],
		},
		{
			"title": "Arreglos",
			"items": [
				"Se corrigio la restauracion visual del estado al continuar una partida guardada.",
				"Se repararon los retratos del menu de invocacion en las builds exportadas.",
				"Se actualizo el nombre oficial del proyecto a Summoners of the Andes.",
			],
		},
		{
			"title": "En foco",
			"items": [
				"Seguir expandiendo desbloqueos, cartas de faccion y balance general de combate.",
			],
		},
	],
}
const MAX_RUN_HISTORY := 24
const UNLOCK_DEFS := {
	"gaucho_opening_cache": {
		"name": "Alijo Gaucho",
		"description": "Juega 5 partidas con Gauchos como Jugador 1. Desbloquea una carta especial de apertura para mazos gauchos.",
		"faction": 0,
		"required_runs": 5,
		"reward_cards": [
			{
				"type": "essence",
				"value": 6,
				"color": "gold",
				"label": "LEG",
				"icon": "G",
				"display_name": "Fogon Gaucho",
			},
		],
	},
}

# ─── Inter-scene game data ──────────────────────────────────────────────────────
var faction_p1:          int = 0   # FactionData.Faction value
var faction_p2:          int = 1   # FactionData.Faction value
var extra_players_enabled: bool = false
var player_count:         int = 2
var faction_p3:          int = 0
var faction_p4:          int = 1
var player3_enabled:     bool = false
var player4_enabled:     bool = false
var player_mode_p1:      String = "human"
var player_mode_p2:      String = "human"
var player_mode_p3:      String = "human"
var player_mode_p4:      String = "human"
var current_map:         int = 0   # 0=Llanuras  1=Sierras  2=Precordillera
var map_size:            Vector2i = Vector2i(16, 12)   # cols x rows
var winner_id:           int = 0   # 0=draw  1=player1  2=player2
var turns_played:        int = 0
var units_killed_p1:     int = 0   # units eliminated BY player 1 (i.e. P2 units killed)
var units_killed_p2:     int = 0   # units eliminated BY player 2 (i.e. P1 units killed)
var towers_captured_p1:  int = 0
var towers_captured_p2:  int = 0

# ─── Generated map data (set by Main before HexGrid ready) ─────────────────────
var map_seed:            int       = 0
var map_terrain:         Array     = []   # Array[Array[int]] [row][col]
var map_tower_positions: Array     = []   # Array[Vector2i]
var map_tower_incomes:   Array     = []   # Array[int]
var map_master_p1:       Vector2i  = Vector2i(1, 3)
var map_master_p2:       Vector2i  = Vector2i(10, 4)
var map_master_p3:       Vector2i  = Vector2i(1, 12)
var map_master_p4:       Vector2i  = Vector2i(10, 12)

# ─── Save path ──────────────────────────────────────────────────────────────────
const SAVE_PATH := "user://savegame.dat"
const DEFAULT_CONTINUE_SCENE_PATH := "res://scenes/Main3D.tscn"
var completed_runs: Array[Dictionary] = []
var faction_run_counts: Dictionary = {}
var unlocked_ids: Array[String] = []
var equipped_unlock_ids: Array[String] = []
var selected_font_id: String = "normal"
var last_completed_run: Dictionary = {}
var last_new_unlocks: Array[String] = []
var loaded_match_state: Dictionary = {}
var loaded_scene_path: String = DEFAULT_CONTINUE_SCENE_PATH
var has_loaded_match_state: bool = false

# ─── Reset (call before starting a new game) ────────────────────────────────────
func reset() -> void:
	faction_p1          = 0
	faction_p2          = 1
	extra_players_enabled = false
	player_count        = 2
	faction_p3          = 0
	faction_p4          = 1
	player3_enabled     = false
	player4_enabled     = false
	player_mode_p1      = "human"
	player_mode_p2      = "human"
	player_mode_p3      = "human"
	player_mode_p4      = "human"
	current_map         = 0
	map_size            = Vector2i(16, 12)
	winner_id           = 0
	turns_played        = 0
	units_killed_p1     = 0
	units_killed_p2     = 0
	towers_captured_p1  = 0
	towers_captured_p2  = 0
	map_seed            = 0
	map_terrain         = []
	map_tower_positions = []
	map_tower_incomes   = []
	map_master_p1       = Vector2i(1, 3)
	map_master_p2       = Vector2i(10, 4)
	map_master_p3       = Vector2i(1, 12)
	map_master_p4       = Vector2i(10, 12)
	loaded_match_state  = {}
	loaded_scene_path   = DEFAULT_CONTINUE_SCENE_PATH
	has_loaded_match_state = false

func _ready() -> void:
	load_meta()

func get_build_version_label() -> String:
	return BUILD_VERSION_LABEL

func get_build_version_code() -> String:
	return BUILD_VERSION_CODE

func get_patch_notes() -> Dictionary:
	return PATCH_NOTES.duplicate(true)

func get_selected_font_id() -> String:
	return selected_font_id

func get_selected_font_label() -> String:
	return str(FONT_OPTIONS.get(selected_font_id, FONT_OPTIONS["normal"]).get("label", "Normal"))

func get_font_label(font_id: String) -> String:
	return str(FONT_OPTIONS.get(font_id, FONT_OPTIONS["normal"]).get("label", "Normal"))

func get_font_toggle_target_label() -> String:
	var ids: Array[String] = get_font_option_ids()
	if ids.size() <= 1:
		return get_selected_font_label()
	var current_index: int = maxi(0, ids.find(selected_font_id))
	var next_index: int = (current_index + 1) % ids.size()
	var next_id: String = ids[next_index]
	return str(FONT_OPTIONS.get(next_id, FONT_OPTIONS["normal"]).get("label", "Normal"))

func get_font_option_ids() -> Array[String]:
	var ids: Array[String] = []
	for font_id: Variant in FONT_OPTIONS.keys():
		ids.append(str(font_id))
	ids.sort()
	if ids.has("normal"):
		ids.erase("normal")
		ids.push_front("normal")
	if ids.has("pixel"):
		ids.erase("pixel")
		ids.append("pixel")
	return ids

func cycle_font_option() -> String:
	var ids: Array[String] = get_font_option_ids()
	if ids.is_empty():
		return selected_font_id
	var current_index: int = ids.find(selected_font_id)
	if current_index == -1:
		current_index = 0
	var next_id: String = ids[(current_index + 1) % ids.size()]
	set_selected_font_id(next_id)
	return selected_font_id

func set_selected_font_id(font_id: String) -> void:
	if not FONT_OPTIONS.has(font_id):
		font_id = "normal"
	selected_font_id = font_id
	save_meta()

func apply_selected_theme(window: Window) -> void:
	if window == null:
		return
	var selected_theme: Theme = get_selected_theme_resource()
	if selected_theme == null:
		return
	window.theme = selected_theme
	if window.get_tree() != null and window.get_tree().root != null:
		window.get_tree().root.theme = selected_theme
		var current_scene: Node = window.get_tree().current_scene
		if current_scene != null:
			_apply_theme_to_node(current_scene, selected_theme)

func _apply_theme_to_node(node: Node, selected_theme: Theme) -> void:
	if node is Control:
		var control: Control = node as Control
		control.theme = selected_theme
		control.remove_theme_font_override("font")
		control.propagate_notification(Control.NOTIFICATION_THEME_CHANGED)
	for child: Node in node.get_children():
		_apply_theme_to_node(child, selected_theme)

func get_selected_theme_resource() -> Theme:
	var theme_path: String = str(FONT_OPTIONS.get(selected_font_id, FONT_OPTIONS["normal"]).get("theme_path", "res://themes/normal_theme.tres"))
	var selected_theme: Theme = load(theme_path)
	return selected_theme

func get_selected_font_resource() -> Font:
	var font_path: String = str(FONT_OPTIONS.get(selected_font_id, FONT_OPTIONS["normal"]).get("font_path", "res://assets/fonts/tahoma.ttf"))
	var selected_font: Font = load(font_path)
	return selected_font

func apply_selected_font_to_control(control: Control) -> void:
	if control == null:
		return
	var selected_font: Font = get_selected_font_resource()
	if selected_font == null:
		return
	control.add_theme_font_override("font", selected_font)

func apply_selected_font_to_label3d(label: Label3D) -> void:
	if label == null:
		return
	var selected_font: Font = get_selected_font_resource()
	if selected_font == null:
		return
	label.font = selected_font

# ─── Persistence ────────────────────────────────────────────────────────────────
func save() -> void:
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("[GameData] Cannot open save file for writing: " + SAVE_PATH)
		return
	f.store_var({
		"scene_path": DEFAULT_CONTINUE_SCENE_PATH,
		"in_progress": false,
		"extra_players_enabled": extra_players_enabled,
		"player_count":        player_count,
		"player3_enabled":     player3_enabled,
		"player4_enabled":     player4_enabled,
		"player_mode_p1":      player_mode_p1,
		"player_mode_p2":      player_mode_p2,
		"player_mode_p3":      player_mode_p3,
		"player_mode_p4":      player_mode_p4,
		"current_map":        current_map,
		"winner_id":          winner_id,
		"turns_played":       turns_played,
		"units_killed_p1":    units_killed_p1,
		"units_killed_p2":    units_killed_p2,
		"towers_captured_p1": towers_captured_p1,
		"towers_captured_p2": towers_captured_p2,
		"map_seed":           map_seed,
		"map_size":           map_size,
		"map_terrain":        map_terrain,
		"map_tower_positions": map_tower_positions,
		"map_tower_incomes":  map_tower_incomes,
		"map_master_p1":      map_master_p1,
		"map_master_p2":      map_master_p2,
		"map_master_p3":      map_master_p3,
		"map_master_p4":      map_master_p4,
		"faction_p1":         faction_p1,
		"faction_p2":         faction_p2,
		"faction_p3":         faction_p3,
		"faction_p4":         faction_p4,
		"match_state":        {},
	})
	f.close()

func load() -> bool:
	var d: Dictionary = _read_save_data()
	if d.is_empty():
		return false
	loaded_scene_path = str(d.get("scene_path", DEFAULT_CONTINUE_SCENE_PATH))
	has_loaded_match_state = bool(d.get("in_progress", false))
	loaded_match_state = d.get("match_state", {})
	extra_players_enabled = d.get("extra_players_enabled", false)
	player_count        = d.get("player_count", 2)
	player3_enabled     = d.get("player3_enabled", false)
	player4_enabled     = d.get("player4_enabled", false)
	player_mode_p1      = str(d.get("player_mode_p1", "human"))
	player_mode_p2      = str(d.get("player_mode_p2", "human"))
	player_mode_p3      = str(d.get("player_mode_p3", "human"))
	player_mode_p4      = str(d.get("player_mode_p4", "human"))
	current_map        = d.get("current_map",        0)
	winner_id          = d.get("winner_id",          0)
	turns_played       = d.get("turns_played",       0)
	units_killed_p1    = d.get("units_killed_p1",    0)
	units_killed_p2    = d.get("units_killed_p2",    0)
	towers_captured_p1 = d.get("towers_captured_p1", 0)
	towers_captured_p2 = d.get("towers_captured_p2", 0)
	map_seed           = d.get("map_seed", 0)
	map_size           = d.get("map_size", Vector2i(16, 12))
	map_terrain        = d.get("map_terrain", [])
	map_tower_positions = d.get("map_tower_positions", [])
	map_tower_incomes  = d.get("map_tower_incomes", [])
	map_master_p1      = d.get("map_master_p1", Vector2i(1, 3))
	map_master_p2      = d.get("map_master_p2", Vector2i(10, 4))
	map_master_p3      = d.get("map_master_p3", Vector2i(1, 12))
	map_master_p4      = d.get("map_master_p4", Vector2i(10, 12))
	faction_p1         = d.get("faction_p1", 0)
	faction_p2         = d.get("faction_p2", 1)
	faction_p3         = d.get("faction_p3", 0)
	faction_p4         = d.get("faction_p4", 1)
	return true

func save_match_in_progress(scene_path: String, match_state: Dictionary) -> void:
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("[GameData] Cannot open save file for writing: " + SAVE_PATH)
		return
	f.store_var({
		"scene_path": scene_path,
		"in_progress": true,
		"match_state": match_state,
		"extra_players_enabled": extra_players_enabled,
		"player_count":        player_count,
		"player3_enabled":     player3_enabled,
		"player4_enabled":     player4_enabled,
		"player_mode_p1":      player_mode_p1,
		"player_mode_p2":      player_mode_p2,
		"player_mode_p3":      player_mode_p3,
		"player_mode_p4":      player_mode_p4,
		"current_map":         current_map,
		"winner_id":           winner_id,
		"turns_played":        turns_played,
		"units_killed_p1":     units_killed_p1,
		"units_killed_p2":     units_killed_p2,
		"towers_captured_p1":  towers_captured_p1,
		"towers_captured_p2":  towers_captured_p2,
		"map_seed":            map_seed,
		"map_size":            map_size,
		"map_terrain":         map_terrain,
		"map_tower_positions": map_tower_positions,
		"map_tower_incomes":   map_tower_incomes,
		"map_master_p1":       map_master_p1,
		"map_master_p2":       map_master_p2,
		"map_master_p3":       map_master_p3,
		"map_master_p4":       map_master_p4,
		"faction_p1":          faction_p1,
		"faction_p2":          faction_p2,
		"faction_p3":          faction_p3,
		"faction_p4":          faction_p4,
	})
	f.close()
	loaded_scene_path = scene_path
	loaded_match_state = match_state.duplicate(true)
	has_loaded_match_state = true

func clear_saved_match() -> void:
	loaded_match_state = {}
	loaded_scene_path = DEFAULT_CONTINUE_SCENE_PATH
	has_loaded_match_state = false
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

func clear_loaded_match_cache() -> void:
	loaded_match_state = {}
	loaded_scene_path = DEFAULT_CONTINUE_SCENE_PATH
	has_loaded_match_state = false

func has_saved_match() -> bool:
	var d: Dictionary = _read_save_data()
	return bool(d.get("in_progress", false))

func save_meta() -> void:
	var f: FileAccess = FileAccess.open(META_SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("[GameData] Cannot open meta save for writing: " + META_SAVE_PATH)
		return
	f.store_var({
		"completed_runs": completed_runs,
		"faction_run_counts": faction_run_counts,
		"unlocked_ids": unlocked_ids,
		"equipped_unlock_ids": equipped_unlock_ids,
		"selected_font_id": selected_font_id,
	})
	f.close()

func load_meta() -> bool:
	_ensure_meta_defaults()
	if not FileAccess.file_exists(META_SAVE_PATH):
		return false
	var f: FileAccess = FileAccess.open(META_SAVE_PATH, FileAccess.READ)
	if f == null:
		push_error("[GameData] Cannot open meta save for reading: " + META_SAVE_PATH)
		return false
	var raw: Variant = f.get_var()
	f.close()
	if not (raw is Dictionary):
		return false
	var d: Dictionary = raw as Dictionary
	completed_runs = _variant_to_dict_array(d.get("completed_runs", []))
	faction_run_counts = d.get("faction_run_counts", {})
	unlocked_ids = _variant_to_string_array(d.get("unlocked_ids", []))
	equipped_unlock_ids = _variant_to_string_array(d.get("equipped_unlock_ids", []))
	selected_font_id = str(d.get("selected_font_id", "normal"))
	_prune_invalid_unlock_ids()
	_prune_invalid_font_id()
	return true

func record_completed_run() -> void:
	load_meta()
	var player_one_faction: int = get_faction_for_player(1)
	var run_summary: Dictionary = {
		"completed_at": Time.get_datetime_string_from_system(false, true),
		"winner_id": winner_id,
		"turns_played": turns_played,
		"player_one_faction": player_one_faction,
		"player_count": get_enabled_player_count(),
		"map_id": current_map,
		"units_killed_p1": units_killed_p1,
		"units_killed_p2": units_killed_p2,
		"towers_captured_p1": towers_captured_p1,
		"towers_captured_p2": towers_captured_p2,
	}
	last_completed_run = run_summary.duplicate(true)
	last_new_unlocks.clear()
	completed_runs.push_front(run_summary)
	if completed_runs.size() > MAX_RUN_HISTORY:
		completed_runs = completed_runs.slice(0, MAX_RUN_HISTORY)
	faction_run_counts[player_one_faction] = int(faction_run_counts.get(player_one_faction, 0)) + 1
	for unlock_id: String in UNLOCK_DEFS.keys():
		if unlocked_ids.has(unlock_id):
			continue
		if _is_unlock_condition_met(unlock_id):
			unlocked_ids.append(unlock_id)
			last_new_unlocks.append(unlock_id)
	save_meta()

func get_unlock_ids() -> Array[String]:
	var ids: Array[String] = []
	for unlock_id: Variant in UNLOCK_DEFS.keys():
		ids.append(str(unlock_id))
	ids.sort()
	return ids

func get_unlock_def(unlock_id: String) -> Dictionary:
	return (UNLOCK_DEFS.get(unlock_id, {}) as Dictionary).duplicate(true)

func is_unlock_unlocked(unlock_id: String) -> bool:
	return unlocked_ids.has(unlock_id)

func is_unlock_equipped(unlock_id: String) -> bool:
	return equipped_unlock_ids.has(unlock_id)

func toggle_unlock_equipped(unlock_id: String) -> bool:
	if not is_unlock_unlocked(unlock_id):
		return false
	if equipped_unlock_ids.has(unlock_id):
		equipped_unlock_ids.erase(unlock_id)
	else:
		equipped_unlock_ids.append(unlock_id)
	save_meta()
	return equipped_unlock_ids.has(unlock_id)

func get_unlock_progress(unlock_id: String) -> Dictionary:
	var unlock_def: Dictionary = get_unlock_def(unlock_id)
	if unlock_def.is_empty():
		return {"current": 0, "required": 0, "complete": false}
	var faction: int = int(unlock_def.get("faction", 0))
	var required_runs: int = int(unlock_def.get("required_runs", 0))
	var current_runs: int = int(faction_run_counts.get(faction, 0))
	return {
		"current": current_runs,
		"required": required_runs,
		"complete": current_runs >= required_runs,
	}

func get_equipped_bonus_cards_for_player(player_id: int) -> Array[Dictionary]:
	var cards: Array[Dictionary] = []
	var player_faction: int = get_faction_for_player(player_id)
	for unlock_id: String in equipped_unlock_ids:
		var unlock_def: Dictionary = get_unlock_def(unlock_id)
		if unlock_def.is_empty():
			continue
		if int(unlock_def.get("faction", -1)) != player_faction:
			continue
		for card_value: Variant in unlock_def.get("reward_cards", []):
			if card_value is Dictionary:
				var card: Dictionary = (card_value as Dictionary).duplicate(true)
				card["source_unlock_id"] = unlock_id
				card["allowed_player_ids"] = [player_id]
				cards.append(card)
	return cards

func consume_new_unlocks() -> Array[String]:
	var unlocks: Array[String] = last_new_unlocks.duplicate()
	last_new_unlocks.clear()
	return unlocks

func get_runs_for_faction(faction: int) -> int:
	return int(faction_run_counts.get(faction, 0))

func _ensure_meta_defaults() -> void:
	if completed_runs == null:
		completed_runs = []
	if faction_run_counts == null:
		faction_run_counts = {}
	if unlocked_ids == null:
		unlocked_ids = []
	if equipped_unlock_ids == null:
		equipped_unlock_ids = []
	if selected_font_id == "":
		selected_font_id = "normal"
	if last_completed_run == null:
		last_completed_run = {}
	if last_new_unlocks == null:
		last_new_unlocks = []

func _is_unlock_condition_met(unlock_id: String) -> bool:
	var progress: Dictionary = get_unlock_progress(unlock_id)
	return bool(progress.get("complete", false))

func _variant_to_dict_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not (value is Array):
		return result
	for entry: Variant in value:
		if entry is Dictionary:
			result.append((entry as Dictionary).duplicate(true))
	return result

func _variant_to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not (value is Array):
		return result
	for entry: Variant in value:
		result.append(str(entry))
	return result

func _prune_invalid_unlock_ids() -> void:
	var valid_unlocked: Array[String] = []
	for unlock_id: String in unlocked_ids:
		if UNLOCK_DEFS.has(unlock_id):
			valid_unlocked.append(unlock_id)
	unlocked_ids = valid_unlocked

	var valid_equipped: Array[String] = []
	for unlock_id: String in equipped_unlock_ids:
		if UNLOCK_DEFS.has(unlock_id) and unlocked_ids.has(unlock_id):
			valid_equipped.append(unlock_id)
	equipped_unlock_ids = valid_equipped

func _prune_invalid_font_id() -> void:
	if not FONT_OPTIONS.has(selected_font_id):
		selected_font_id = "normal"

func _read_save_data() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		push_error("[GameData] Cannot open save file for reading: " + SAVE_PATH)
		return {}
	var raw: Variant = f.get_var()
	f.close()
	if raw is Dictionary:
		return raw as Dictionary
	return {}

func get_player_ids() -> Array[int]:
	var ids: Array[int] = [1, 2]
	if player3_enabled:
		ids.append(3)
	if player4_enabled:
		ids.append(4)
	return ids

func get_enabled_player_count() -> int:
	return get_player_ids().size()

func get_player_name(player_id: int) -> String:
	return "Jugador %d" % player_id

func is_player_enabled(player_id: int) -> bool:
	match player_id:
		1, 2:
			return true
		3:
			return player3_enabled
		4:
			return player4_enabled
		_:
			return false

func get_player_color(player_id: int) -> Color:
	match player_id:
		1:
			return Color(0.20, 0.50, 1.00, 1.00)
		2:
			return Color(1.00, 0.20, 0.20, 1.00)
		3:
			return Color(0.24, 0.88, 0.34, 1.00)
		4:
			return Color(1.00, 0.88, 0.24, 1.00)
		_:
			return Color(0.75, 0.75, 0.75, 1.00)

func get_faction_for_player(player_id: int) -> int:
	match player_id:
		1:
			return faction_p1
		2:
			return faction_p2
		3:
			return faction_p3
		4:
			return faction_p4
		_:
			return faction_p1

func get_player_mode(player_id: int) -> String:
	match player_id:
		1:
			return player_mode_p1
		2:
			return player_mode_p2
		3:
			return player_mode_p3
		4:
			return player_mode_p4
		_:
			return "human"

func get_master_cell_for_player(player_id: int) -> Vector2i:
	match player_id:
		1:
			return map_master_p1
		2:
			return map_master_p2
		3:
			return map_master_p3
		4:
			return map_master_p4
		_:
			return Vector2i(-1, -1)

