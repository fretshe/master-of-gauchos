extends Node

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
var current_map:         int = 0   # 0=Llanuras  1=Montañas  2=Volcánico
var map_size:            Vector2i = Vector2i(24, 16)   # cols × rows
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
var map_master_p1:       Vector2i  = Vector2i(1, 3)
var map_master_p2:       Vector2i  = Vector2i(10, 4)
var map_master_p3:       Vector2i  = Vector2i(1, 12)
var map_master_p4:       Vector2i  = Vector2i(10, 12)

# ─── Save path ──────────────────────────────────────────────────────────────────
const SAVE_PATH := "user://savegame.dat"

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
	map_size            = Vector2i(24, 16)
	winner_id           = 0
	turns_played        = 0
	units_killed_p1     = 0
	units_killed_p2     = 0
	towers_captured_p1  = 0
	towers_captured_p2  = 0
	map_seed            = 0
	map_terrain         = []
	map_tower_positions = []
	map_master_p1       = Vector2i(1, 3)
	map_master_p2       = Vector2i(10, 4)
	map_master_p3       = Vector2i(1, 12)
	map_master_p4       = Vector2i(10, 12)

# ─── Persistence ────────────────────────────────────────────────────────────────
func save() -> void:
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("[GameData] Cannot open save file for writing: " + SAVE_PATH)
		return
	f.store_var({
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
	})

func load() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		push_error("[GameData] Cannot open save file for reading: " + SAVE_PATH)
		return false
	var raw: Variant = f.get_var()
	if not (raw is Dictionary):
		return false
	var d: Dictionary = raw as Dictionary
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
	return true

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
