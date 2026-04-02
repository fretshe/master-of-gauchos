extends Node

# Faction enum
enum Faction { GAUCHOS = 0, MILITARES = 1, INDIOS = 2, BRUJOS = 3 }

# Faction metadata
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
	Faction.INDIOS: {
		"name":   "Nativos",
		"color":  Color(0.28, 0.82, 0.48),
		"desc":   "Movilidad y acecho.\nPresión ágil del territorio.",
		"folder": "res://assets/sprites/factions/nativos/",
	},
	Faction.BRUJOS: {
		"name":   "Brujos",
		"color":  Color(0.72, 0.42, 0.92),
		"desc":   "Misticismo y amenaza.\nPresencia oscura en el frente.",
		"folder": "res://assets/sprites/factions/brujos/",
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

# Public API
func get_sprite_path(faction: int, unit_type: int) -> String:
	var data: Dictionary = FACTION_DATA.get(faction, FACTION_DATA[Faction.GAUCHOS])
	var file: String = TYPE_TO_FILE.get(unit_type, "warrior.png")
	return data["folder"] + file

func get_faction_name(faction: int) -> String:
	return FACTION_DATA.get(faction, FACTION_DATA[Faction.GAUCHOS])["name"]

func get_color(faction: int) -> Color:
	return FACTION_DATA.get(faction, FACTION_DATA[Faction.GAUCHOS])["color"]

func get_desc(faction: int) -> String:
	return FACTION_DATA.get(faction, FACTION_DATA[Faction.GAUCHOS])["desc"]

func get_all_faction_ids() -> Array[int]:
	return [
		Faction.GAUCHOS,
		Faction.MILITARES,
		Faction.INDIOS,
		Faction.BRUJOS,
	]

func get_faction_cards(faction: int) -> Array[Dictionary]:
	match faction:
		Faction.GAUCHOS:
			return [
				{"type": "faction", "effect": "immobilize", "value": 0, "color": "gold",
				 "display_name": "Lazo",
				 "description": "Inmovilizá una unidad enemiga. No puede moverse el próximo turno.",
				 "art_path": "res://assets/sprites/cards/gauchos/lazo.png"},
				{"type": "faction", "effect": "exp", "value": 3, "color": "gold",
				 "display_name": "Mate amargo",
				 "description": "+3 exp a una unidad aliada.",
				 "art_path": "res://assets/sprites/cards/gauchos/mate_amargo.png"},
				{"type": "faction", "effect": "extra_move", "value": 3, "color": "gold",
				 "display_name": "Arreo",
				 "description": "Una unidad aliada puede moverse 3 casillas extra este turno.",
				 "art_path": "res://assets/sprites/cards/gauchos/arreo.png"},
			]
		Faction.MILITARES:
			return [
				{"type": "faction", "effect": "double_attack", "value": 0, "color": "gold",
				 "display_name": "Orden de ataque",
				 "description": "Una unidad aliada puede atacar dos veces este turno."},
				{"type": "faction", "effect": "extra_move", "value": 4, "color": "gold",
				 "display_name": "Avance táctico",
				 "description": "+4 movimiento a una unidad aliada este turno."},
				{"type": "essence", "value": 5, "color": "gold",
				 "display_name": "Suministros de guerra",
				 "description": "+5 de esencia."},
			]
		Faction.INDIOS:
			return [
				{"type": "faction", "effect": "heal", "value": 8, "color": "gold",
				 "display_name": "Medicina ancestral",
				 "description": "Curá +8 HP a una unidad aliada."},
				{"type": "faction", "effect": "defense_buff", "value": 3, "color": "gold",
				 "display_name": "Espíritu guardián",
				 "description": "+3 defensa a una unidad aliada por un turno."},
				{"type": "faction", "effect": "poison", "value": 1, "color": "gold",
				 "display_name": "Flecha venenosa",
				 "description": "-1 HP por 3 turnos al inicio del turno del lanzador."},
			]
		Faction.BRUJOS:
			return [
				{"type": "faction", "effect": "attack_debuff", "value": 3, "color": "gold",
				 "display_name": "Maldición",
				 "description": "Una unidad enemiga pierde -3 ataques por un turno."},
				{"type": "faction", "effect": "sacrifice_essence", "value": 8, "color": "gold",
				 "display_name": "Pacto oscuro",
				 "description": "Tu Maestro pierde 5 HP. Ganás +8 de esencia."},
				{"type": "faction", "effect": "untargetable", "value": 0, "color": "gold",
				 "display_name": "Niebla arcana",
				 "description": "Una unidad aliada no puede ser atacada este turno."},
			]
		_:
			return []
