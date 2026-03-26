extends RefCounted

class_name Tower

# ─── Properties ────────────────────────────────────────────────────────────────
var tower_name: String  = "Tower"
var owner_id: int       = 0        # 0=neutral, 1=player1, 2=player2
var income: int         = 2        # gold generated per turn
var position: Vector2i  = Vector2i(-1, -1)
var visual_flash: float = 0.0   # capture pulse intensity [0..1]

# ─── API ───────────────────────────────────────────────────────────────────────
func capture(new_owner_id: int) -> void:
	owner_id = new_owner_id

func owner_name() -> String:
	match owner_id:
		1: return "Player 1"
		2: return "Player 2"
		_: return "Neutral"
