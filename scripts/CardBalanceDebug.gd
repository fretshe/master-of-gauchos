extends RefCounted

class_name CardBalanceDebug

const TYPE_NAMES := {
	"essence": "Esencia",
	"heal": "Curacion",
	"damage": "Dano",
	"exp": "XP",
}


func print_deck_report() -> void:
	var totals_by_type: Dictionary = {}
	var counts_by_type: Dictionary = {}
	var total_cards: int = 0

	for entry: Dictionary in CardManager.DECK_BLUEPRINT:
		var card_type: String = str(entry.get("type", ""))
		var value: int = int(entry.get("value", 0))
		var count: int = int(entry.get("count", 0))
		total_cards += count
		totals_by_type[card_type] = int(totals_by_type.get(card_type, 0)) + value * count
		counts_by_type[card_type] = int(counts_by_type.get(card_type, 0)) + count

	print("[Cards] ===== Reporte del mazo =====")
	print("[Cards] Total de cartas: %d" % total_cards)

	for type_key: String in ["essence", "heal", "damage", "exp"]:
		var type_count: int = int(counts_by_type.get(type_key, 0))
		if type_count <= 0:
			continue
		var total_value: int = int(totals_by_type.get(type_key, 0))
		var avg_value: float = float(total_value) / float(type_count)
		print("[Cards] %s | cantidad:%d | valor medio:%.2f | valor total:%d" % [
			TYPE_NAMES.get(type_key, type_key),
			type_count,
			avg_value,
			total_value,
		])

	for entry: Dictionary in CardManager.DECK_BLUEPRINT:
		print("[Cards]   %s %d x%d" % [
			TYPE_NAMES.get(str(entry.get("type", "")), str(entry.get("type", ""))),
			int(entry.get("value", 0)),
			int(entry.get("count", 0)),
		])
