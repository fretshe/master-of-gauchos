extends Node

# ─── Faction enum ────────────────────────────────────────────────────────────────
enum Faction { GAUCHOS = 0, MILITARES = 1 }

# ─── Faction metadata ────────────────────────────────────────────────────────────
const FACTION_DATA := {
	Faction.GAUCHOS: {
		"name":   "Gauchos",
		"color":  Color(0.85, 0.60, 0.15),
		"desc":   "Guerreros de la pampa.\nHábiles y resistentes.",
		"folder": "res://assets/sprites/factions/gauchos/",
	},
	Faction.MILITARES: {
		"name":   "Militares",
		"color":  Color(0.40, 0.65, 0.95),
		"desc":   "Disciplina y fuego.\nFuerza organizada.",
		"folder": "res://assets/sprites/factions/militares/",
	},
}

# -1 = master (special); 0-3 = Unit.UnitType (WARRIOR, ARCHER, LANCER, RIDER)
const TYPE_TO_FILE := {
	-1: "master.png",
	0:  "warrior.png",
	1:  "archer.png",
	2:  "lancer.png",
	3:  "rider.png",
}

# ─── Public API ──────────────────────────────────────────────────────────────────
func get_sprite_path(faction: int, unit_type: int) -> String:
	var data: Dictionary = FACTION_DATA.get(faction, FACTION_DATA[Faction.GAUCHOS])
	var file: String     = TYPE_TO_FILE.get(unit_type, "warrior.png")
	return data["folder"] + file

func get_faction_name(faction: int) -> String:
	return FACTION_DATA.get(faction, FACTION_DATA[Faction.GAUCHOS])["name"]

func get_color(faction: int) -> Color:
	return FACTION_DATA.get(faction, FACTION_DATA[Faction.GAUCHOS])["color"]

func get_desc(faction: int) -> String:
	return FACTION_DATA.get(faction, FACTION_DATA[Faction.GAUCHOS])["desc"]
