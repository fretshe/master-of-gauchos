extends Node

const BONUSES := {
	"tough_skin":     {id="tough_skin",     name="Piel dura",        description="+2 HP maximo",                                      type="global"},
	"veteran":        {id="veteran",        name="Veterano",         description="+1 XP extra por combate",                           type="global"},
	"immune":         {id="immune",         name="Inmune",           description="No puede ser envenenado",                           type="global"},
	"resistant":      {id="resistant",      name="Resistente",       description="Reduce 1 punto de dano recibido",                   type="global"},
	"swiftness":      {id="swiftness",      name="Paso ligero",      description="+1 movimiento permanente",                          type="global"},
	"raider":         {id="raider",         name="Merodeador",       description="Capturar torres da +2 XP extra",                    type="global"},
	"fury":           {id="fury",           name="Furia",            description="Con menos de 50% HP, mejora un dado melee",         type="warrior"},
	"battle_veteran": {id="battle_veteran", name="Vet. de batalla",  description="Doble XP contra unidades de nivel superior",        type="warrior"},
	"cleaver":        {id="cleaver",        name="Hachazo",          description="+1 impacto melee por combate",                      type="warrior"},
	"executioner":    {id="executioner",    name="Verdugo",          description="+1 al resultado contra enemigos heridos",           type="warrior"},
	"precision":      {id="precision",      name="Punteria",         description="El primer ataque por turno siempre acierta",        type="archer"},
	"long_range":     {id="long_range",     name="Rango largo",      description="Alcance de ataque +1 casilla",                     type="archer"},
	"volley":         {id="volley",         name="Andanada",         description="+1 disparo en ataques a distancia",                 type="archer"},
	"marksman":       {id="marksman",       name="Tirador experto",  description="+1 al resultado de ataques a distancia",            type="archer"},
	"javelin_expert": {id="javelin_expert", name="Jabalina experta", description="La jabalina puede usarse 2 veces por turno",        type="lancer"},
	"charge":         {id="charge",         name="Carga",            description="Si se movio antes de atacar, +1 al dado melee",     type="lancer"},
	"pathfinder":     {id="pathfinder",     name="Baqueano",         description="Bosque y montana cuestan 1 de movimiento",          type="lancer"},
	"pinning":        {id="pinning",        name="Empalador",        description="Si hiere, aplica -1 ataque al rival este turno",    type="lancer"},
	"flanking":       {id="flanking",       name="Flanqueo",         description="Si ataca lateral o trasero, +1 al resultado",       type="rider"},
	"brutal_charge":  {id="brutal_charge",  name="Carga brutal",     description="Si se movio 3+ casillas, el primer golpe usa PLATINO", type="rider"},
	"trample":        {id="trample",        name="Arrollar",         description="+1 impacto melee por combate",                      type="rider"},
	"outrider":       {id="outrider",       name="Explorador",       description="+1 movimiento permanente",                          type="rider"},
	"aura":           {id="aura",           name="Aura",             description="Aliados adyacentes regeneran 1 HP por turno",       type="master"},
	"leadership":     {id="leadership",     name="Liderazgo",        description="Aliados en radio 2 ganan +1 XP por combate",        type="master"},
	"command":        {id="command",        name="Mando",            description="+1 movimiento permanente",                          type="master"},
	"royal_guard":    {id="royal_guard",    name="Guardia real",     description="+4 HP maximo",                                      type="master"},
}

const GLOBAL_POOL: Array[String] = ["tough_skin", "veteran", "immune", "resistant", "swiftness", "raider"]

var _pending: Array = []
var level_up_menu = null

func queue_bonus_selection(unit: Unit) -> void:
	if not _pending.has(unit):
		_pending.append(unit)

func has_pending_bonuses() -> bool:
	return not _pending.is_empty()

func pop_next_pending() -> Unit:
	if _pending.is_empty():
		return null
	return _pending.pop_front() as Unit

func process_pending() -> void:
	while has_pending_bonuses():
		var unit: Unit = pop_next_pending()
		if unit == null or not is_instance_valid(unit) or unit.hp <= 0:
			continue
		var options: Array = get_bonus_options(unit)
		if options.is_empty():
			continue
		if GameData.get_player_mode(unit.owner_id) == "ai":
			var best: String = get_ai_best_bonus(unit, options)
			if not best.is_empty():
				apply_bonus(unit, best)
		elif level_up_menu != null:
			level_up_menu.show_for_unit(unit)
			var bonus_id: String = await level_up_menu.bonus_chosen
			if not bonus_id.is_empty():
				apply_bonus(unit, bonus_id)

func get_bonus_options(unit: Unit) -> Array:
	var global_pool: Array[String] = GLOBAL_POOL.filter(func(id: String) -> bool: return not id in unit.active_bonuses)
	var type_pool: Array[String] = _get_type_pool(unit).filter(func(id: String) -> bool: return not id in unit.active_bonuses)
	var options: Array = []
	if not type_pool.is_empty():
		options.append(BONUSES[type_pool[randi() % type_pool.size()]])
	if not global_pool.is_empty():
		options.append(BONUSES[global_pool[randi() % global_pool.size()]])
	if options.size() < 2:
		var combined: Array[String] = []
		for id: String in type_pool:
			if not _options_have_bonus(options, id):
				combined.append(id)
		for id: String in global_pool:
			if not _options_have_bonus(options, id):
				combined.append(id)
		if not combined.is_empty():
			options.append(BONUSES[combined[randi() % combined.size()]])
	return options

func _options_have_bonus(options: Array, bonus_id: String) -> bool:
	for option_value: Variant in options:
		var option: Dictionary = option_value as Dictionary
		if str(option.get("id", "")) == bonus_id:
			return true
	return false

func _get_type_pool(unit: Unit) -> Array[String]:
	if unit is Master:
		return ["aura", "leadership", "command", "royal_guard"]
	match unit.unit_type:
		Unit.UnitType.WARRIOR:
			return ["fury", "battle_veteran", "cleaver", "executioner"]
		Unit.UnitType.ARCHER:
			return ["precision", "long_range", "volley", "marksman"]
		Unit.UnitType.LANCER:
			return ["javelin_expert", "charge", "pathfinder", "pinning"]
		Unit.UnitType.RIDER:
			return ["flanking", "brutal_charge", "trample", "outrider"]
	return []

func apply_bonus(unit: Unit, bonus_id: String) -> void:
	if bonus_id.is_empty() or bonus_id in unit.active_bonuses:
		return
	unit.active_bonuses.append(bonus_id)
	match bonus_id:
		"tough_skin":
			unit.max_hp += 2
			unit.hp = mini(unit.hp + 2, unit.max_hp)
			unit.bonus_tough_skin = true
		"veteran":
			unit.bonus_veteran = true
		"immune":
			unit.bonus_immune = true
		"resistant":
			unit.bonus_resistant = true
		"swiftness":
			unit.move_range += 1
			unit.bonus_swiftness = true
		"raider":
			unit.bonus_raider = true
		"fury":
			unit.bonus_fury = true
		"battle_veteran":
			unit.bonus_battle_veteran = true
		"cleaver":
			unit.bonus_cleaver = true
		"executioner":
			unit.bonus_executioner = true
		"precision":
			unit.bonus_precision = true
		"long_range":
			unit.attack_range += 1
			unit.bonus_long_range = true
		"volley":
			unit.bonus_volley = true
		"marksman":
			unit.bonus_marksman = true
		"javelin_expert":
			unit.bonus_javelin_expert = true
		"charge":
			unit.bonus_charge = true
		"pathfinder":
			unit.bonus_pathfinder = true
		"pinning":
			unit.bonus_pinning = true
		"flanking":
			unit.bonus_flanking = true
		"brutal_charge":
			unit.bonus_brutal_charge = true
		"trample":
			unit.bonus_trample = true
		"outrider":
			unit.move_range += 1
			unit.bonus_outrider = true
		"aura":
			unit.bonus_aura = true
		"leadership":
			unit.bonus_leadership = true
		"command":
			unit.move_range += 1
			unit.bonus_command = true
		"royal_guard":
			unit.max_hp += 4
			unit.hp = mini(unit.hp + 4, unit.max_hp)
			unit.bonus_royal_guard = true
	print("[Bendiciones] %s obtuvo: %s" % [unit.unit_name, BONUSES.get(bonus_id, {}).get("name", bonus_id)])

func reapply_stat_bonuses(unit: Unit) -> void:
	if unit.bonus_tough_skin:
		unit.max_hp += 2
	if unit.bonus_royal_guard:
		unit.max_hp += 4
	if unit.bonus_swiftness:
		unit.move_range += 1
	if unit.bonus_outrider:
		unit.move_range += 1
	if unit.bonus_command:
		unit.move_range += 1
	if unit.bonus_long_range:
		unit.attack_range += 1
	unit.hp = mini(unit.hp, unit.max_hp)

func rebuild_bonus_flags(unit: Unit) -> void:
	unit.bonus_tough_skin = false
	unit.bonus_veteran = false
	unit.bonus_immune = false
	unit.bonus_resistant = false
	unit.bonus_swiftness = false
	unit.bonus_raider = false
	unit.bonus_fury = false
	unit.bonus_battle_veteran = false
	unit.bonus_cleaver = false
	unit.bonus_executioner = false
	unit.bonus_precision = false
	unit.bonus_long_range = false
	unit.bonus_volley = false
	unit.bonus_marksman = false
	unit.bonus_javelin_expert = false
	unit.bonus_charge = false
	unit.bonus_pathfinder = false
	unit.bonus_pinning = false
	unit.bonus_flanking = false
	unit.bonus_brutal_charge = false
	unit.bonus_trample = false
	unit.bonus_outrider = false
	unit.bonus_aura = false
	unit.bonus_leadership = false
	unit.bonus_command = false
	unit.bonus_royal_guard = false
	for bonus_id: String in unit.active_bonuses:
		match bonus_id:
			"tough_skin": unit.bonus_tough_skin = true
			"veteran": unit.bonus_veteran = true
			"immune": unit.bonus_immune = true
			"resistant": unit.bonus_resistant = true
			"swiftness": unit.bonus_swiftness = true
			"raider": unit.bonus_raider = true
			"fury": unit.bonus_fury = true
			"battle_veteran": unit.bonus_battle_veteran = true
			"cleaver": unit.bonus_cleaver = true
			"executioner": unit.bonus_executioner = true
			"precision": unit.bonus_precision = true
			"long_range": unit.bonus_long_range = true
			"volley": unit.bonus_volley = true
			"marksman": unit.bonus_marksman = true
			"javelin_expert": unit.bonus_javelin_expert = true
			"charge": unit.bonus_charge = true
			"pathfinder": unit.bonus_pathfinder = true
			"pinning": unit.bonus_pinning = true
			"flanking": unit.bonus_flanking = true
			"brutal_charge": unit.bonus_brutal_charge = true
			"trample": unit.bonus_trample = true
			"outrider": unit.bonus_outrider = true
			"aura": unit.bonus_aura = true
			"leadership": unit.bonus_leadership = true
			"command": unit.bonus_command = true
			"royal_guard": unit.bonus_royal_guard = true

func get_ai_best_bonus(unit: Unit, options: Array) -> String:
	if options.is_empty():
		return ""
	var best_id: String = str((options[0] as Dictionary).get("id", ""))
	var best_score: int = -1
	for bonus_value: Variant in options:
		var bonus: Dictionary = bonus_value as Dictionary
		var score: int = _score_bonus(unit, str(bonus.get("id", "")))
		if score > best_score:
			best_score = score
			best_id = str(bonus.get("id", ""))
	return best_id

func _score_bonus(unit: Unit, bonus_id: String) -> int:
	var hp_pct: float = float(unit.hp) / float(maxi(unit.max_hp, 1))
	var is_master: bool = unit is Master
	match bonus_id:
		"tough_skin": return 6 if hp_pct < 0.5 else 4
		"veteran": return 4
		"immune": return 2
		"resistant": return 5 if is_master else 3
		"swiftness": return 6
		"raider": return 5
		"fury": return 7 if hp_pct < 0.5 else 4
		"battle_veteran": return 3
		"cleaver": return 7
		"executioner": return 5
		"precision": return 5
		"long_range": return 6
		"volley": return 7
		"marksman": return 6
		"javelin_expert": return 5
		"charge": return 4
		"pathfinder": return 6
		"pinning": return 5
		"flanking": return 4
		"brutal_charge": return 6
		"trample": return 6
		"outrider": return 7
		"aura": return 8 if is_master else 2
		"leadership": return 5 if is_master else 2
		"command": return 7 if is_master else 2
		"royal_guard": return 8 if is_master else 3
	return 1
