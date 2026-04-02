extends Node

const META_SAVE_PATH := "user://meta_progression.dat"
const BUILD_VERSION_LABEL := "Beta 0.2.2"
const BUILD_VERSION_CODE := "0.2.2"
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
	"version": "Beta 0.2.2",
	"title": "Pulido de tablero, feedback visual y legibilidad de movimiento",
	"date": "2026-04-02",
	"sections": [
		{
			"title": "Novedades",
			"items": [
				"Las casillas de movimiento ahora muestran un contorno exterior amarillo para leer mejor el area alcanzable desde cualquier angulo.",
				"El nuevo borde de movimiento suma una respiracion suave de brillo para marcar recorrido sin ensuciar el tablero.",
				"Se corrigio un problema visual que dejaba algunas casillas de bosque restauradas con un tono mas oscuro despues de usar highlights.",
				"Se siguio puliendo la presentacion del tablero para que la lectura de seleccion, movimiento y altura sea mas clara.",
			],
		},
		{
			"title": "Terreno y tablero",
			"items": [
				"El bosque recupera mejor su color base real al encender y apagar efectos visuales de seleccion o movimiento.",
				"Se suavizo la respuesta del bosque a las sombras para evitar lecturas demasiado oscuras, especialmente en situaciones de foco visual.",
				"El sistema de resaltado ya no depende solo de apagar el resto del tablero para mostrar casillas validas.",
				"Se corrigieron inconsistencias visuales entre casillas de distinta altura al dibujar informacion sobre sus bordes.",
			],
		},
		{
			"title": "Combate y cartas",
			"items": [
				"Las cartas ahora anuncian mejor sus efectos con una telegraphica previa y proyectiles mas lentos y visibles.",
				"Se siguio reforzando la lectura de los efectos de combate para que no aparezcan de golpe sobre el campo.",
				"Los proyectiles y efectos asociados ganaron presencia visual para no perderse entre unidades y terreno.",
				"Se mantuvo el trabajo de pulido sobre super criticos, seleccion y respuesta visual general del combate.",
			],
		},
		{
			"title": "Presentacion general",
			"items": [
				"Se continuo afinando la interfaz para que Summoners of the Andes gane coherencia visual entre tablero, menu y feedback de partida.",
				"El equipo de color, brillo y contraste del tablero fue recalibrado para priorizar lectura tactica sin perder atmosfera.",
				"El parche sigue consolidando el cambio de identidad visual y de lenguaje del juego alrededor de Summoners of the Andes.",
				"Se sumaron mas retoques de estabilidad y pulido general en sistemas ya incorporados durante la beta 0.2.",
			],
		},
	],
}
const MAX_RUN_HISTORY := 24
const MAX_EQUIPPED_EXTRA_FACTION_CARDS := 6
const UNLOCK_DEFS := {
	"gaucho_fogon_gaucho": {
		"name": "Fogón Gaucho",
		"description": "Completá 3 partidas con Gauchos como Jugador 1. Cuenta tanto ganar como perder. Desbloquea Fogón Gaucho para futuros mazos gauchos.",
		"faction": 0,
		"required_runs": 3,
		"reward_cards": [
			{"type": "essence", "value": 6, "color": "gold",
			 "label": "LEG", "icon": "G",
			 "display_name": "Fogón Gaucho",
			 "description": "Obtené +6 de esencia.",
			 "art_path": "res://assets/sprites/cards/gauchos/fogon_gaucho.png"},
		],
	},
	"gaucho_descanso": {
		"name": "Descanso",
		"description": "Completá 6 partidas con Gauchos como Jugador 1. Cuenta tanto ganar como perder. Desbloquea Descanso para futuros mazos gauchos.",
		"faction": 0,
		"required_runs": 6,
		"reward_cards": [
			{"type": "refresh", "value": 0, "color": "gold",
			 "label": "LEG", "icon": "↻",
			 "display_name": "Descanso",
			 "description": "Refrescá una unidad aliada para que actúe nuevamente.",
			 "art_path": "res://assets/sprites/cards/gauchos/descanso.png"},
		],
	},
	"gaucho_cuchillo_criollo": {
		"name": "Cuchillo criollo",
		"description": "Completá 9 partidas con Gauchos como Jugador 1. Cuenta tanto ganar como perder. Desbloquea Cuchillo criollo para futuros mazos gauchos.",
		"faction": 0,
		"required_runs": 9,
		"reward_cards": [
			{"type": "faction", "effect": "damage", "value": 4, "color": "gold",
			 "display_name": "Cuchillo criollo",
			 "description": "-4 HP a una unidad enemiga.",
			 "art_path": "res://assets/sprites/cards/gauchos/cuchillo_criollo.png"},
		],
	},
	"militar_bombardeo": {
		"name": "Bombardeo",
		"description": "Completá 3 partidas con Militares como Jugador 1. Cuenta tanto ganar como perder. Desbloquea Bombardeo para futuros mazos militares.",
		"faction": 1,
		"required_runs": 3,
		"reward_cards": [
			{"type": "faction", "effect": "damage", "value": 7, "color": "gold",
			 "display_name": "Bombardeo",
			 "description": "-7 HP a una unidad enemiga."},
		],
	},
	"militar_fuego_cobertura": {
		"name": "Fuego de cobertura",
		"description": "Completá 6 partidas con Militares como Jugador 1. Cuenta tanto ganar como perder. Desbloquea Fuego de cobertura para futuros mazos militares.",
		"faction": 1,
		"required_runs": 6,
		"reward_cards": [
			{"type": "faction", "effect": "aoe_damage", "value": 3, "color": "gold",
			 "display_name": "Fuego de cobertura",
			 "description": "-3 HP a todas las unidades enemigas adyacentes a tus torres."},
		],
	},
	"militar_llamada_refuerzos": {
		"name": "Llamada de refuerzos",
		"description": "Completá 9 partidas con Militares como Jugador 1. Cuenta tanto ganar como perder. Desbloquea Llamada de refuerzos para futuros mazos militares.",
		"faction": 1,
		"required_runs": 9,
		"reward_cards": [
			{"type": "faction", "effect": "free_summon", "value": 0, "color": "gold",
			 "display_name": "Llamada de refuerzos",
			 "description": "Invocá una unidad nivel 1 sin costo de esencia."},
		],
	},
	"indio_circulo_sagrado": {
		"name": "Círculo sagrado",
		"description": "Completá 3 partidas con Nativos como Jugador 1. Cuenta tanto ganar como perder. Desbloquea Círculo sagrado para futuros mazos nativos.",
		"faction": 2,
		"required_runs": 3,
		"reward_cards": [
			{"type": "faction", "effect": "heal_all", "value": 2, "color": "gold",
			 "display_name": "Círculo sagrado",
			 "description": "Curá +2 HP a todas las unidades aliadas."},
		],
	},
	"indio_torre_sagrada": {
		"name": "Torre sagrada",
		"description": "Completá 6 partidas con Nativos como Jugador 1. Cuenta tanto ganar como perder. Desbloquea Torre sagrada para futuros mazos nativos.",
		"faction": 2,
		"required_runs": 6,
		"reward_cards": [
			{"type": "faction", "effect": "tower_heal", "value": 1, "color": "gold",
			 "display_name": "Torre sagrada",
			 "description": "Tus torres curan +1 HP extra a unidades aliadas en su hexágono."},
		],
	},
	"indio_totem_guerra": {
		"name": "Tótem de guerra",
		"description": "Completá 9 partidas con Nativos como Jugador 1. Cuenta tanto ganar como perder. Desbloquea Tótem de guerra para futuros mazos nativos.",
		"faction": 2,
		"required_runs": 9,
		"reward_cards": [
			{"type": "faction", "effect": "exp", "value": 4, "color": "gold",
			 "display_name": "Tótem de guerra",
			 "description": "+4 exp a una unidad aliada."},
		],
	},
	"brujo_transmutacion": {
		"name": "Transmutación",
		"description": "Completá 3 partidas con Brujos como Jugador 1. Cuenta tanto ganar como perder. Desbloquea Transmutación para futuros mazos brujos.",
		"faction": 3,
		"required_runs": 3,
		"reward_cards": [
			{"type": "faction", "effect": "swap_hp", "value": 0, "color": "gold",
			 "display_name": "Transmutación",
			 "description": "Intercambiá el HP de una unidad enemiga con el de tu Maestro."},
		],
	},
	"brujo_resurreccion": {
		"name": "Resurrección",
		"description": "Completá 6 partidas con Brujos como Jugador 1. Cuenta tanto ganar como perder. Desbloquea Resurrección para futuros mazos brujos.",
		"faction": 3,
		"required_runs": 6,
		"reward_cards": [
			{"type": "faction", "effect": "revive", "value": 0, "color": "gold",
			 "display_name": "Resurrección",
			 "description": "Devolvé tu última unidad muerta con 50% de HP."},
		],
	},
	"brujo_caos_total": {
		"name": "Caos total",
		"description": "Completá 9 partidas con Brujos como Jugador 1. Cuenta tanto ganar como perder. Desbloquea Caos total para futuros mazos brujos.",
		"faction": 3,
		"required_runs": 9,
		"reward_cards": [
			{"type": "faction", "effect": "random", "value": 0, "color": "gold",
			 "display_name": "Caos total",
			 "description": "Efecto aleatorio: daño, curación, esencia o exp a unidad aleatoria."},
		],
	},
}

# â”€â”€â”€ Inter-scene game data â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
# ─── Team color palette (8 options) ────────────────────────────────────────────
const AVAILABLE_COLORS: Array[Color] = [
	Color(0.20, 0.50, 1.00),   # Azul
	Color(1.00, 0.20, 0.20),   # Rojo
	Color(0.24, 0.88, 0.34),   # Verde
	Color(1.00, 0.88, 0.24),   # Amarillo
	Color(0.40, 0.80, 1.00),   # Celeste
	Color(1.00, 0.55, 0.10),   # Naranja
	Color(0.60, 0.20, 0.90),   # Morado
	Color(1.00, 0.40, 0.70),   # Rosa
]

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
var color_p1:            Color  = AVAILABLE_COLORS[0]
var color_p2:            Color  = AVAILABLE_COLORS[1]
var color_p3:            Color  = AVAILABLE_COLORS[2]
var color_p4:            Color  = AVAILABLE_COLORS[3]
var current_map:         int = 0   # 0=Llanuras  1=Sierras  2=Precordillera
var map_size:            Vector2i = Vector2i(16, 12)   # cols x rows
var winner_id:           int = 0   # 0=draw  1=player1  2=player2
var turns_played:        int = 0
var units_killed_p1:     int = 0   # units eliminated BY player 1 (i.e. P2 units killed)
var units_killed_p2:     int = 0   # units eliminated BY player 2 (i.e. P1 units killed)
var towers_captured_p1:  int = 0
var towers_captured_p2:  int = 0
var match_stats:         Dictionary = {}

# â”€â”€â”€ Generated map data (set by Main before HexGrid ready) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
var map_seed:            int       = 0
var map_terrain:         Array     = []   # Array[Array[int]] [row][col]
var map_tower_positions: Array     = []   # Array[Vector2i]
var map_tower_incomes:   Array     = []   # Array[int]
var map_master_p1:       Vector2i  = Vector2i(1, 3)
var map_master_p2:       Vector2i  = Vector2i(10, 4)
var map_master_p3:       Vector2i  = Vector2i(1, 12)
var map_master_p4:       Vector2i  = Vector2i(10, 12)
var tutorial_mode_active: bool = false
var tutorial_chapter_id:  String = ""

# â”€â”€â”€ Save path â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
const SAVE_PATH := "user://savegame.dat"
const DEFAULT_CONTINUE_SCENE_PATH := "res://scenes/Main3D.tscn"
var completed_runs: Array[Dictionary] = []
var faction_run_counts: Dictionary = {}
var unlocked_ids: Array[String] = []
var equipped_unlock_ids: Array[String] = []
var equipped_base_card_ids: Array[String] = []
var completed_tutorial_chapters: Array[String] = []
var selected_font_id: String = "normal"
var fullscreen_enabled: bool = false
var last_completed_run: Dictionary = {}
var last_new_unlocks: Array[String] = []
var loaded_match_state: Dictionary = {}
var loaded_scene_path: String = DEFAULT_CONTINUE_SCENE_PATH
var has_loaded_match_state: bool = false

# â”€â”€â”€ Reset (call before starting a new game) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
	match_stats         = {}
	map_seed            = 0
	map_terrain         = []
	map_tower_positions = []
	map_tower_incomes   = []
	map_master_p1       = Vector2i(1, 3)
	map_master_p2       = Vector2i(10, 4)
	map_master_p3       = Vector2i(1, 12)
	map_master_p4       = Vector2i(10, 12)
	tutorial_mode_active = false
	tutorial_chapter_id = ""
	loaded_match_state  = {}
	loaded_scene_path   = DEFAULT_CONTINUE_SCENE_PATH
	has_loaded_match_state = false
	color_p1            = AVAILABLE_COLORS[0]
	color_p2            = AVAILABLE_COLORS[1]
	color_p3            = AVAILABLE_COLORS[2]
	color_p4            = AVAILABLE_COLORS[3]

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

func is_fullscreen_enabled() -> bool:
	return fullscreen_enabled

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

func set_fullscreen_enabled(enabled: bool) -> void:
	fullscreen_enabled = enabled
	save_meta()

func toggle_fullscreen_enabled() -> bool:
	fullscreen_enabled = not fullscreen_enabled
	save_meta()
	return fullscreen_enabled

func apply_window_mode(window: Window) -> void:
	if window == null:
		return
	var target_mode: int = DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen_enabled else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(target_mode)
	window.mode = Window.MODE_FULLSCREEN if fullscreen_enabled else Window.MODE_WINDOWED

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

func mark_tutorial_chapter_completed(chapter_id: String) -> void:
	if chapter_id == "":
		return
	if not completed_tutorial_chapters.has(chapter_id):
		completed_tutorial_chapters.append(chapter_id)
		completed_tutorial_chapters.sort()
		save_meta()

func is_tutorial_chapter_completed(chapter_id: String) -> bool:
	return completed_tutorial_chapters.has(chapter_id)

# â”€â”€â”€ Persistence â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
		"match_stats":        match_stats,
		"map_seed":           map_seed,
		"map_size":           map_size,
		"map_terrain":        map_terrain,
		"map_tower_positions": map_tower_positions,
		"map_tower_incomes":  map_tower_incomes,
		"map_master_p1":      map_master_p1,
		"map_master_p2":      map_master_p2,
		"map_master_p3":      map_master_p3,
		"map_master_p4":      map_master_p4,
		"tutorial_mode_active": tutorial_mode_active,
		"tutorial_chapter_id": tutorial_chapter_id,
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
	match_stats        = d.get("match_stats", {})
	map_seed           = d.get("map_seed", 0)
	map_size           = d.get("map_size", Vector2i(16, 12))
	map_terrain        = d.get("map_terrain", [])
	map_tower_positions = d.get("map_tower_positions", [])
	map_tower_incomes  = d.get("map_tower_incomes", [])
	map_master_p1      = d.get("map_master_p1", Vector2i(1, 3))
	map_master_p2      = d.get("map_master_p2", Vector2i(10, 4))
	map_master_p3      = d.get("map_master_p3", Vector2i(1, 12))
	map_master_p4      = d.get("map_master_p4", Vector2i(10, 12))
	tutorial_mode_active = bool(d.get("tutorial_mode_active", false))
	tutorial_chapter_id = str(d.get("tutorial_chapter_id", ""))
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
		"match_stats":         match_stats,
		"map_seed":            map_seed,
		"map_size":            map_size,
		"map_terrain":         map_terrain,
		"map_tower_positions": map_tower_positions,
		"map_tower_incomes":   map_tower_incomes,
		"map_master_p1":       map_master_p1,
		"map_master_p2":       map_master_p2,
		"map_master_p3":       map_master_p3,
		"map_master_p4":       map_master_p4,
		"tutorial_mode_active": tutorial_mode_active,
		"tutorial_chapter_id": tutorial_chapter_id,
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
		"equipped_base_card_ids": equipped_base_card_ids,
		"completed_tutorial_chapters": completed_tutorial_chapters,
		"selected_font_id": selected_font_id,
		"fullscreen_enabled": fullscreen_enabled,
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
	if d.has("equipped_base_card_ids"):
		equipped_base_card_ids = _variant_to_string_array(d.get("equipped_base_card_ids", []))
	else:
		equipped_base_card_ids = _get_all_default_faction_card_ids()
	completed_tutorial_chapters = _variant_to_string_array(d.get("completed_tutorial_chapters", []))
	selected_font_id = str(d.get("selected_font_id", "normal"))
	fullscreen_enabled = bool(d.get("fullscreen_enabled", false))
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
		"match_stats": match_stats.duplicate(true),
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

func is_base_card_equipped(card_id: String) -> bool:
	return equipped_base_card_ids.has(card_id)

func get_max_equipped_extra_faction_cards() -> int:
	return MAX_EQUIPPED_EXTRA_FACTION_CARDS

func get_max_equipped_faction_cards_for_faction(faction_id: int) -> int:
	return get_default_faction_cards(faction_id).size() + MAX_EQUIPPED_EXTRA_FACTION_CARDS

func get_equipped_bonus_card_count_for_faction(faction_id: int) -> int:
	var total: int = 0
	for unlock_id: String in equipped_unlock_ids:
		var unlock_def: Dictionary = get_unlock_def(unlock_id)
		if unlock_def.is_empty():
			continue
		if int(unlock_def.get("faction", -1)) != faction_id:
			continue
		total += (unlock_def.get("reward_cards", []) as Array).size()
	return total

func get_equipped_base_card_count_for_faction(faction_id: int) -> int:
	var total: int = 0
	for card_data: Dictionary in get_default_faction_cards(faction_id):
		if is_base_card_equipped(str(card_data.get("source_card_id", ""))):
			total += 1
	return total

func get_equipped_faction_card_count_for_faction(faction_id: int) -> int:
	return get_equipped_base_card_count_for_faction(faction_id) + get_equipped_bonus_card_count_for_faction(faction_id)

func can_equip_unlock(unlock_id: String) -> bool:
	if not is_unlock_unlocked(unlock_id):
		return false
	if equipped_unlock_ids.has(unlock_id):
		return true
	var unlock_def: Dictionary = get_unlock_def(unlock_id)
	if unlock_def.is_empty():
		return false
	var faction_id: int = int(unlock_def.get("faction", -1))
	var reward_count: int = (unlock_def.get("reward_cards", []) as Array).size()
	return get_equipped_bonus_card_count_for_faction(faction_id) + reward_count <= MAX_EQUIPPED_EXTRA_FACTION_CARDS

func toggle_unlock_equipped(unlock_id: String) -> bool:
	if not is_unlock_unlocked(unlock_id):
		return false
	if equipped_unlock_ids.has(unlock_id):
		equipped_unlock_ids.erase(unlock_id)
	else:
		if not can_equip_unlock(unlock_id):
			return false
		equipped_unlock_ids.append(unlock_id)
	save_meta()
	return equipped_unlock_ids.has(unlock_id)

func toggle_base_card_equipped(card_id: String) -> bool:
	if card_id == "":
		return false
	if equipped_base_card_ids.has(card_id):
		equipped_base_card_ids.erase(card_id)
	else:
		equipped_base_card_ids.append(card_id)
		equipped_base_card_ids.sort()
	save_meta()
	return equipped_base_card_ids.has(card_id)

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
	for default_card: Dictionary in get_default_faction_cards(player_faction):
		if not is_base_card_equipped(str(default_card.get("source_card_id", ""))):
			continue
		var card: Dictionary = default_card.duplicate(true)
		card.erase("source_card_id")
		card["allowed_player_ids"] = [player_id]
		card["faction"] = player_faction
		cards.append(card)
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
				card["faction"] = player_faction
				cards.append(card)
	return cards

func get_default_faction_cards(faction: int) -> Array[Dictionary]:
	var cards: Array = FactionData.get_faction_cards(faction)
	var result: Array[Dictionary] = []
	for i: int in range(cards.size()):
		var value: Variant = cards[i]
		if not (value is Dictionary):
			continue
		var card: Dictionary = (value as Dictionary).duplicate(true)
		card["source_card_id"] = _make_base_card_id(faction, i)
		result.append(card)
	return result

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
	if equipped_base_card_ids == null:
		equipped_base_card_ids = _get_all_default_faction_card_ids()
	if selected_font_id == "":
		selected_font_id = "normal"
	fullscreen_enabled = bool(fullscreen_enabled)
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
	var faction_card_counts: Dictionary = {}
	for unlock_id: String in equipped_unlock_ids:
		if not UNLOCK_DEFS.has(unlock_id) or not unlocked_ids.has(unlock_id):
			continue
		var unlock_def: Dictionary = get_unlock_def(unlock_id)
		var faction_id: int = int(unlock_def.get("faction", -1))
		var reward_count: int = (unlock_def.get("reward_cards", []) as Array).size()
		var current_count: int = int(faction_card_counts.get(faction_id, 0))
		if current_count + reward_count > MAX_EQUIPPED_EXTRA_FACTION_CARDS:
			continue
		faction_card_counts[faction_id] = current_count + reward_count
		valid_equipped.append(unlock_id)
	equipped_unlock_ids = valid_equipped

	var valid_base_ids: Array[String] = _get_all_default_faction_card_ids()
	var filtered_base_ids: Array[String] = []
	for card_id: String in equipped_base_card_ids:
		if valid_base_ids.has(card_id):
			filtered_base_ids.append(card_id)
	equipped_base_card_ids = filtered_base_ids

func _prune_invalid_font_id() -> void:
	if not FONT_OPTIONS.has(selected_font_id):
		selected_font_id = "normal"

func _make_base_card_id(faction: int, index: int) -> String:
	return "base_%d_%d" % [faction, index]

func _get_all_default_faction_card_ids() -> Array[String]:
	var result: Array[String] = []
	for faction_id: int in FactionData.get_all_faction_ids():
		for card_data: Dictionary in get_default_faction_cards(faction_id):
			result.append(str(card_data.get("source_card_id", "")))
	return result

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
		1: return color_p1
		2: return color_p2
		3: return color_p3
		4: return color_p4
		_: return Color(0.75, 0.75, 0.75, 1.00)

func set_player_color(player_id: int, color: Color) -> void:
	match player_id:
		1: color_p1 = color
		2: color_p2 = color
		3: color_p3 = color
		4: color_p4 = color

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
