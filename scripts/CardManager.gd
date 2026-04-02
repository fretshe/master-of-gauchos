extends Node

signal hand_changed(player_id: int)
signal card_played(player_id: int, card: Dictionary)
signal card_resolved(player_id: int, card: Dictionary, target_unit: Unit)
signal unit_killed_by_card(unit: Unit, killer_player_id: int)
signal message_emitted(text: String, tint: Color)
signal free_summon_requested(player_id: int)
signal revive_requested(player_id: int, unit_data: Dictionary)

const DECK_BLUEPRINT: Array[Dictionary] = [
	{"type": "essence", "value": 2, "color": "cyan", "count": 8},
	{"type": "essence", "value": 3, "color": "cyan", "count": 5},
	{"type": "essence", "value": 4, "color": "cyan", "count": 3},
	{"type": "essence", "value": 5, "color": "cyan", "count": 2},
	{"type": "heal", "value": 2, "color": "teal", "count": 6},
	{"type": "heal", "value": 4, "color": "teal", "count": 4},
	{"type": "heal", "value": 6, "color": "teal", "count": 2},
	{"type": "damage", "value": 2, "color": "red", "count": 5},
	{"type": "damage", "value": 3, "color": "red", "count": 4},
	{"type": "damage", "value": 4, "color": "red", "count": 3},
	{"type": "damage", "value": 5, "color": "red", "count": 1},
	{"type": "exp", "value": 1, "color": "purple", "count": 2},
	{"type": "exp", "value": 2, "color": "purple", "count": 3},
	{"type": "exp", "value": 3, "color": "purple", "count": 2},
]

var deck: Array[Dictionary] = []
var hands: Dictionary = {1: [], 2: [], 3: [], 4: []}
var used_card_this_turn: bool = false
var free_summon_active: bool = false
var resource_manager: Node = null
var hex_grid: Node = null
var active_effects: Array[Dictionary] = []
var sacred_towers: Array[Dictionary] = []
var dead_units_by_player: Dictionary = {}

func setup_deck() -> void:
	deck.clear()
	hands = {1: [], 2: [], 3: [], 4: []}
	used_card_this_turn = false

	for entry: Dictionary in DECK_BLUEPRINT:
		var count: int = int(entry.get("count", 1))
		for _i: int in range(count):
			deck.append({
				"type": str(entry.get("type", "")),
				"value": int(entry.get("value", 0)),
				"color": str(entry.get("color", "cyan")),
			})

	for player_id: int in GameData.get_player_ids():
		for bonus_card: Dictionary in GameData.get_equipped_bonus_cards_for_player(player_id):
			deck.append(bonus_card.duplicate(true))

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i: int in range(deck.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Dictionary = deck[i]
		deck[i] = deck[j]
		deck[j] = tmp

func get_hand(player_id: int) -> Array:
	return (hands.get(player_id, []) as Array).duplicate(true)

func card_requires_target(card: Dictionary) -> bool:
	var card_type: String = str(card.get("type", ""))
	if card_type == "faction":
		match str(card.get("effect", "")):
			"immobilize", "poison", "attack_debuff", "damage", "heal", \
			"exp", "extra_move", "double_attack", "defense_buff", \
			"untargetable", "swap_hp":
				return true
			_:
				return false
	return card_type == "heal" or card_type == "damage" or card_type == "exp" or card_type == "refresh"

func can_target_card(player_id: int, card: Dictionary, target_unit: Unit) -> bool:
	if target_unit == null or not is_instance_valid(target_unit):
		return false
	if str(card.get("type", "")) == "faction":
		match str(card.get("effect", "")):
			"immobilize", "poison", "attack_debuff", "damage":
				return target_unit.owner_id != player_id and not (target_unit is Master)
			"exp", "double_attack", "defense_buff", "untargetable":
				return target_unit.owner_id == player_id
			"extra_move":
				return target_unit.owner_id == player_id and not target_unit.moved
			"heal":
				return target_unit.owner_id == player_id and target_unit.hp < target_unit.max_hp
			"swap_hp":
				return target_unit.owner_id != player_id and not (target_unit is Master)
			_:
				return false
	match str(card.get("type", "")):
		"heal":
			return target_unit.owner_id == player_id and target_unit.hp < target_unit.max_hp
		"exp":
			return target_unit.owner_id == player_id
		"refresh":
			return target_unit.owner_id == player_id and (target_unit.moved or target_unit.has_attacked)
		"damage":
			return target_unit.owner_id != player_id and not (target_unit is Master)
		_:
			return false

func draw_card(player_id: int) -> void:
	var hand: Array = hands.get(player_id, [])
	if hand.size() >= 3:
		_emit_message("Mano llena", Color(0.92, 0.92, 0.96))
		return
	if deck.is_empty():
		_emit_message("Mazo agotado", Color(1.0, 0.74, 0.34))
		return

	var draw_index: int = _find_next_drawable_card_index(player_id)
	if draw_index == -1:
		_emit_message("No hay cartas para esta faccion", Color(0.94, 0.74, 0.34))
		return

	var card: Dictionary = deck[draw_index]
	deck.remove_at(draw_index)
	hand.append(card)
	hands[player_id] = hand
	emit_signal("hand_changed", player_id)

func play_card(player_id: int, card_index: int, target_unit: Unit = null) -> bool:
	if used_card_this_turn:
		_emit_message("Ya usaste una carta", Color(0.96, 0.84, 0.28))
		return false

	var hand: Array = hands.get(player_id, [])
	if card_index < 0 or card_index >= hand.size():
		return false

	var card: Dictionary = hand[card_index]
	if target_unit != null and not is_instance_valid(target_unit):
		target_unit = null
	if card_requires_target(card) and not can_target_card(player_id, card, target_unit):
		_emit_message("Objetivo invalido", Color(1.0, 0.46, 0.46))
		return false

	match str(card.get("type", "")):
		"essence":
			if resource_manager != null and resource_manager.has_method("add_essence"):
				resource_manager.call("add_essence", player_id, int(card.get("value", 0)))
		"heal":
			target_unit.hp = mini(target_unit.hp + int(card.get("value", 0)), target_unit.max_hp)
		"damage":
			target_unit.hp = maxi(0, target_unit.hp - int(card.get("value", 0)))
			VFXManager.show_damage_label(null, _unit_world_pos(target_unit), int(card.get("value", 0)), "damage", false)
			if target_unit.hp == 0:
				emit_signal("unit_killed_by_card", target_unit, player_id)
		"exp":
			target_unit.gain_exp(int(card.get("value", 0)))
		"refresh":
			target_unit.moved = false
			target_unit.has_attacked = false
		"faction":
			var effect: String = str(card.get("effect", ""))
			var value: int = int(card.get("value", 0))
			match effect:
				"essence":
					if resource_manager != null and resource_manager.has_method("add_essence"):
						resource_manager.call("add_essence", player_id, value)
				"exp":
					target_unit.gain_exp(value)
				"damage":
					target_unit.hp = maxi(0, target_unit.hp - value)
					VFXManager.show_damage_label(null, _unit_world_pos(target_unit), value, "damage", false)
					if target_unit.hp == 0:
						emit_signal("unit_killed_by_card", target_unit, player_id)
				"heal":
					target_unit.hp = mini(target_unit.hp + value, target_unit.max_hp)
				"heal_all":
					if hex_grid != null:
						for unit_value: Variant in hex_grid.get_all_units():
							var unit: Unit = unit_value as Unit
							if unit != null and unit.owner_id == player_id:
								unit.hp = mini(unit.hp + value, unit.max_hp)
				"extra_move":
					target_unit.move_bonus += value
				"double_attack":
					target_unit.extra_attacks += 1
				"immobilize":
					add_effect({"effect": "immobilize", "unit": target_unit,
						"owner_player": target_unit.owner_id, "turns_left": 1})
				"poison":
					add_effect({"effect": "poison", "unit": target_unit,
						"damage": maxi(1, value), "owner_player": player_id, "turns_left": 3})
				"defense_buff":
					target_unit.defense_buff += value
				"attack_debuff":
					target_unit.attack_debuff += value
				"untargetable":
					target_unit.untargetable = true
				"sacrifice_essence":
					if hex_grid != null:
						for unit_value: Variant in hex_grid.get_all_units():
							var master: Unit = unit_value as Unit
							if master != null and master.owner_id == player_id and master is Master:
								master.hp = maxi(1, master.hp - 5)
								break
					if resource_manager != null and resource_manager.has_method("add_essence"):
						resource_manager.call("add_essence", player_id, value)
				"swap_hp":
					if hex_grid != null and target_unit != null:
						for unit_value: Variant in hex_grid.get_all_units():
							var master: Unit = unit_value as Unit
							if master != null and master.owner_id == player_id and master is Master:
								var tmp: int = master.hp
								master.hp = mini(target_unit.hp, master.max_hp)
								target_unit.hp = mini(tmp, target_unit.max_hp)
								break
				"tower_heal":
					sacred_towers.append({"owner_player": player_id, "value": maxi(1, value)})
				"free_summon":
					free_summon_active = true
					emit_signal("free_summon_requested", player_id)
				"revive":
					var dead: Array = dead_units_by_player.get(player_id, [])
					if dead.is_empty():
						_emit_message("No hay unidades muertas", Color(0.94, 0.74, 0.22))
						return false
					var unit_data: Dictionary = dead[-1]
					dead_units_by_player[player_id] = dead.slice(0, dead.size() - 1)
					emit_signal("revive_requested", player_id, unit_data)
				"aoe_damage":
					if hex_grid != null and hex_grid.has_method("get_enemy_units_near_towers"):
						var targets: Array = hex_grid.call("get_enemy_units_near_towers", player_id)
						for target_value: Variant in targets:
							var t: Unit = target_value as Unit
							if t != null and is_instance_valid(t):
								t.hp = maxi(0, t.hp - value)
								VFXManager.show_damage_label(null, _unit_world_pos(t), value, "damage", false)
								if t.hp == 0:
									emit_signal("unit_killed_by_card", t, player_id)
				"random":
					var rng := RandomNumberGenerator.new()
					rng.randomize()
					if hex_grid != null:
						var all_units: Array = hex_grid.get_all_units()
						if not all_units.is_empty():
							var rand_unit: Unit = all_units[rng.randi() % all_units.size()] as Unit
							if rand_unit != null and is_instance_valid(rand_unit):
								match rng.randi_range(0, 3):
									0:
										rand_unit.hp = maxi(0, rand_unit.hp - 3)
										VFXManager.show_damage_label(null, _unit_world_pos(rand_unit), 3, "damage", false)
									1:
										rand_unit.hp = mini(rand_unit.hp + 3, rand_unit.max_hp)
									2:
										if resource_manager != null and resource_manager.has_method("add_essence"):
											resource_manager.call("add_essence", player_id, 3)
									3:
										rand_unit.gain_exp(3)
				_:
					return false
		_:
			return false

	AudioManager.play_card(str(card.get("type", "")))

	hand.remove_at(card_index)
	hands[player_id] = hand
	used_card_this_turn = true
	emit_signal("hand_changed", player_id)
	emit_signal("card_played", player_id, card)
	emit_signal("card_resolved", player_id, card, target_unit)
	return true

func play_card_on_tower(player_id: int, card_index: int, tower_cell: Vector2i) -> bool:
	if used_card_this_turn:
		_emit_message("Ya usaste una carta", Color(0.96, 0.84, 0.28))
		return false

	var hand: Array = hands.get(player_id, [])
	if card_index < 0 or card_index >= hand.size():
		return false

	var card: Dictionary = hand[card_index]
	if str(card.get("type", "")) != "faction" or str(card.get("effect", "")) != "tower_heal":
		return false

	_prune_invalid_sacred_towers()
	for existing: Dictionary in sacred_towers:
		if existing.get("cell", Vector2i(-1, -1)) == tower_cell:
			_emit_message("Esta torre ya tiene el efecto activo", Color(1.0, 0.76, 0.28))
			return false

	var value: int = maxi(1, int(card.get("value", 1)))
	sacred_towers.append({"owner_player": player_id, "cell": tower_cell, "value": value})
	if hex_grid != null and hex_grid.has_method("set_tower_special_effect"):
		hex_grid.call("set_tower_special_effect", tower_cell, "tower_heal", player_id, value)

	AudioManager.play_card("faction")
	hand.remove_at(card_index)
	hands[player_id] = hand
	used_card_this_turn = true
	emit_signal("hand_changed", player_id)
	emit_signal("card_played", player_id, card)
	emit_signal("card_resolved", player_id, card, null)
	return true

func end_turn_reset() -> void:
	used_card_this_turn = false
	free_summon_active = false

func add_effect(effect_data: Dictionary) -> void:
	active_effects.append(effect_data)

func track_dead_unit(unit: Unit) -> void:
	if unit == null or unit is Master:
		return
	var player_id: int = unit.owner_id
	if not dead_units_by_player.has(player_id):
		dead_units_by_player[player_id] = []
	dead_units_by_player[player_id].append({
		"type": unit.unit_type,
		"name": unit.unit_name,
		"owner_id": player_id,
	})

func process_effects(player_id: int) -> void:
	var to_remove: Array[Dictionary] = []
	_prune_invalid_sacred_towers()
	for effect: Dictionary in active_effects:
		var effect_type: String = str(effect.get("effect", ""))
		var owner: int = int(effect.get("owner_player", 0))
		var _unit_raw = effect.get("unit", null)
		var unit: Unit = _unit_raw as Unit if is_instance_valid(_unit_raw) else null
		match effect_type:
			"poison":
				if owner != player_id:
					continue
				if unit != null and is_instance_valid(unit) and unit.hp > 0:
					var dmg: int = int(effect.get("damage", 1))
					unit.hp = maxi(0, unit.hp - dmg)
					VFXManager.show_damage_label(null, _unit_world_pos(unit), dmg, "damage", false)
					if unit.hp == 0:
						emit_signal("unit_killed_by_card", unit, owner)
			"immobilize":
				if owner != player_id:
					continue
				if unit != null and is_instance_valid(unit):
					unit.moved = true
			_:
				continue
		effect["turns_left"] = int(effect.get("turns_left", 0)) - 1
		if int(effect.get("turns_left", 0)) <= 0:
			to_remove.append(effect)
	for e: Dictionary in to_remove:
		active_effects.erase(e)
	for tower_effect: Dictionary in sacred_towers:
		if int(tower_effect.get("owner_player", 0)) != player_id:
			continue
		var heal_amount: int = int(tower_effect.get("value", 1))
		var target_cell: Vector2i = tower_effect.get("cell", Vector2i(-1, -1))
		if target_cell != Vector2i(-1, -1):
			if hex_grid != null and hex_grid.has_method("heal_unit_on_cell"):
				hex_grid.call("heal_unit_on_cell", target_cell, heal_amount)
		elif hex_grid != null and hex_grid.has_method("heal_units_on_owned_towers"):
			hex_grid.call("heal_units_on_owned_towers", player_id, heal_amount)

func _emit_message(text: String, tint: Color) -> void:
	emit_signal("message_emitted", text, tint)

func _prune_invalid_sacred_towers() -> void:
	if hex_grid == null or not hex_grid.has_method("get_tower_at"):
		return
	var invalid_entries: Array[Dictionary] = []
	for tower_effect: Dictionary in sacred_towers:
		var target_cell: Vector2i = tower_effect.get("cell", Vector2i(-1, -1))
		if target_cell == Vector2i(-1, -1):
			continue
		var tower: Tower = hex_grid.call("get_tower_at", target_cell.x, target_cell.y) as Tower
		if tower == null:
			invalid_entries.append(tower_effect)
			continue
		if tower.owner_id != int(tower_effect.get("owner_player", 0)):
			invalid_entries.append(tower_effect)
			continue
		if tower.special_effect_type != "tower_heal":
			invalid_entries.append(tower_effect)
	for invalid_entry: Dictionary in invalid_entries:
		sacred_towers.erase(invalid_entry)

func _unit_world_pos(unit: Unit) -> Vector3:
	if hex_grid != null and hex_grid.has_method("get_cell_for_unit") and hex_grid.has_method("hex_to_world"):
		var cell: Vector2i = hex_grid.call("get_cell_for_unit", unit)
		if cell != Vector2i(-1, -1):
			return hex_grid.call("hex_to_world", cell.x, cell.y)
	return Vector3(unit.visual_pos.x, 0.0, unit.visual_pos.y)

func _find_next_drawable_card_index(player_id: int) -> int:
	for i: int in range(deck.size()):
		var card: Dictionary = deck[i]
		if _can_player_draw_card(player_id, card):
			return i
	return -1

func _can_player_draw_card(player_id: int, card: Dictionary) -> bool:
	if not card.has("allowed_player_ids"):
		return true
	var allowed: Variant = card.get("allowed_player_ids", [])
	if not (allowed is Array):
		return true
	for allowed_player: Variant in allowed:
		if int(allowed_player) == player_id:
			return true
	return false

func serialize_state() -> Dictionary:
	return {
		"deck": deck.duplicate(true),
		"hands": hands.duplicate(true),
		"used_card_this_turn": used_card_this_turn,
		"active_effects": active_effects.duplicate(true),
		"sacred_towers": sacred_towers.duplicate(true),
		"dead_units_by_player": dead_units_by_player.duplicate(true),
	}

func load_state(state: Dictionary) -> void:
	deck = (state.get("deck", []) as Array).duplicate(true)
	hands = (state.get("hands", {}) as Dictionary).duplicate(true)
	used_card_this_turn = bool(state.get("used_card_this_turn", false))
	active_effects = (state.get("active_effects", []) as Array).duplicate(true)
	sacred_towers = (state.get("sacred_towers", []) as Array).duplicate(true)
	dead_units_by_player = (state.get("dead_units_by_player", {}) as Dictionary).duplicate(true)
	for player_id: int in [1, 2, 3, 4]:
		if not hands.has(player_id):
			hands[player_id] = []
