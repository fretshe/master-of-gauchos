extends Node

signal hand_changed(player_id: int)
signal card_played(player_id: int, card: Dictionary)
signal card_resolved(player_id: int, card: Dictionary, target_unit: Unit)
signal unit_killed_by_card(unit: Unit, killer_player_id: int)
signal message_emitted(text: String, tint: Color)

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
var resource_manager: Node = null
var hex_grid: Node = null

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
	return card_type == "heal" or card_type == "damage" or card_type == "exp"

func can_target_card(player_id: int, card: Dictionary, target_unit: Unit) -> bool:
	if target_unit == null:
		return false
	match str(card.get("type", "")):
		"heal":
			return target_unit.owner_id == player_id and target_unit.hp < target_unit.max_hp
		"exp":
			return target_unit.owner_id == player_id
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

func end_turn_reset() -> void:
	used_card_this_turn = false

func _emit_message(text: String, tint: Color) -> void:
	emit_signal("message_emitted", text, tint)

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
	}

func load_state(state: Dictionary) -> void:
	deck = (state.get("deck", []) as Array).duplicate(true)
	hands = (state.get("hands", {}) as Dictionary).duplicate(true)
	used_card_this_turn = bool(state.get("used_card_this_turn", false))
	for player_id: int in [1, 2, 3, 4]:
		if not hands.has(player_id):
			hands[player_id] = []
