extends RefCounted

class_name HelpGlossary

const GOLD_HEX = "#f2c85d"
const CYAN_HEX = "#8fe6ff"
const BRONZE_HEX = "#c27f43"
const SILVER_HEX = "#ced3e0"
const GOLD_RANK_HEX = "#ffd63d"
const PLATINUM_HEX = "#2b955d"
const DIAMOND_HEX = "#54ebff"
const ESSENCE_HEX = "#59d7ff"
const HEAL_HEX = "#8ef0a0"
const DAMAGE_HEX = "#ff8d8d"
const BLESSING_HEX = "#d58cff"

const CLASS_ICON_PATHS = {
	"Guerrero": "res://assets/sprites/ui/class_icons/warrior_icon.png",
	"Arquero": "res://assets/sprites/ui/class_icons/archer_icon.png",
	"Lancero": "res://assets/sprites/ui/class_icons/lancer_icon.png",
	"Jinete": "res://assets/sprites/ui/class_icons/rider_icon.png",
	"Maestro": "res://assets/sprites/ui/class_icons/master_icon.png",
}

const INLINE_ICON_PATHS = {
	"Esencia": "res://assets/sprites/ui/icon_essence_cyan.png",
	"Torres": "res://assets/sprites/ui/icon_tower.png",
	"Torre": "res://assets/sprites/ui/icon_tower.png",
}

const SECTIONS = [
	{
		"title": "Conceptos basicos",
		"items": [
			{"term": "Maestro", "text": "Unidad principal de cada jugador. Si cae, perdes la partida."},
			{"term": "Esencia", "text": "Recurso usado para invocar unidades y activar cartas."},
			{"term": "Torres", "text": "Dan ingreso de esencia, ayudan al control del mapa y suelen ser objetivos clave."},
			{"term": "Niveles", "text": "Las unidades progresan por Bronce, Plata, Oro, Platino y Diamante."},
			{"term": "Bendiciones", "text": "Mejoras permanentes que una unidad puede elegir al subir de nivel."},
		],
	},
	{
		"title": "Combate",
		"items": [
			{"term": "Ataque melee", "text": "Combate cuerpo a cuerpo. La cantidad de golpes depende de la unidad y el terreno."},
			{"term": "Ataque a distancia", "text": "Solo algunas unidades pueden atacar a rango. El defensor puede responder si tiene alcance valido."},
			{"term": "Golpes por combate", "text": "Cada combate puede incluir varios golpes. El dano final surge de cada tirada y sus modificadores."},
			{"term": "Ventaja de tipo", "text": "El sistema de contras aumenta o reduce dano segun la pareja de clases enfrentadas."},
			{"term": "Critico", "text": "No depende solo del valor maximo del dado. Si activa, duplica el dano final de esa tirada."},
			{"term": "Terreno", "text": "Montana y bosque pueden modificar golpes o movimiento. El posicionamiento importa mucho."},
		],
	},
	{
		"title": "Dados",
		"items": [
			{"term": "Bronce", "text": "Dado basico. Tiene resultados bajos y mas dispersion."},
			{"term": "Plata", "text": "Primer salto estable. Mejora la consistencia de dano."},
			{"term": "Oro", "text": "Dado fuerte de mitad de partida. Buen equilibrio entre pico y regularidad."},
			{"term": "Platino", "text": "Dado elite. Marca una ventaja clara sin llegar al techo maximo."},
			{"term": "Diamante", "text": "Dado superior. Tiene los picos mas altos y define unidades de late game."},
			{"term": "Lectura de dados", "text": "El color del dado coincide con el rango de la unidad o del ataque que lo usa."},
		],
	},
	{
		"title": "Clases",
		"items": [
			{"term": "Guerrero", "text": "Unidad frontal, resistente y confiable en melee."},
			{"term": "Arquero", "text": "Especialista en distancia. Suele castigar antes del choque directo."},
			{"term": "Lancero", "text": "Unidad tactica con buen volumen de golpes y opcion de ataque a distancia limitada."},
			{"term": "Jinete", "text": "Movilidad alta, ideal para flanquear, presionar torres y cerrar objetivos."},
			{"term": "Maestro", "text": "Unidad heroica central. Su faccion cambia su forma de pelear y apoyar."},
		],
	},
	{
		"title": "Facciones",
		"items": [
			{"term": "Gauchos", "text": "Perfil flexible y frontal, orientado a presion y presencia en el mapa."},
			{"term": "Militares", "text": "Enfoque disciplinado y directo, con herramientas de control y castigo."},
			{"term": "Nativos", "text": "Mayor presencia de alcance y movilidad tactica para rodear o castigar."},
			{"term": "Brujos", "text": "Juego mas especial y de soporte, con efectos y herramientas menos convencionales."},
		],
	},
	{
		"title": "Cartas",
		"items": [
			{"term": "Cartas de esencia", "text": "Aumentan recursos o alteran la economia de un turno."},
			{"term": "Cartas de dano", "text": "Infligen dano directo o ayudan a rematar objetivos."},
			{"term": "Cartas de soporte", "text": "Curar, mover, mejorar defensa o alterar el ritmo de una unidad."},
			{"term": "Cartas de control", "text": "Aplican efectos como inmovilizar, debilitar o reposicionar la pelea."},
			{"term": "Mazo", "text": "Conjunto de cartas disponibles en partida. Los desbloqueos amplian opciones meta."},
		],
	},
	{
		"title": "Mapa y objetivos",
		"items": [
			{"term": "Captura de torres", "text": "Entrar en la casilla suele bastar para capturarla si esta neutral o enemiga."},
			{"term": "Defensa de torres", "text": "Una torre controlada vale recursos y posicion. Perderla puede cambiar el ritmo del match."},
			{"term": "Economia", "text": "Mas torres y mejor control del mapa significan mas esencia y mejores invocaciones."},
			{"term": "Partida rapida", "text": "Modo libre para configurar mapa, facciones y flujo general de la partida."},
			{"term": "Tutorial", "text": "Capitulos guiados para aprender sistemas clave del juego paso a paso."},
		],
	},
]

static func get_sections():
	return SECTIONS

static func build_bbcode():
	var lines = []
	for section in SECTIONS:
		lines.append("[font_size=24][color=%s]%s[/color][/font_size]" % [GOLD_HEX, str(section.get("title", ""))])
		lines.append("")
		for item in section.get("items", []):
			var term = str(item.get("term", ""))
			var text = str(item.get("text", ""))
			lines.append("%s %s" % [_format_term(term), _format_text(text)])
			lines.append("")
		lines.append("")
	return "\n".join(lines)

static func _format_term(term):
	var styled_term = "[color=%s]%s:[/color]" % [CYAN_HEX, term]
	if CLASS_ICON_PATHS.has(term):
		return "%s %s" % [_icon_tag(str(CLASS_ICON_PATHS[term])), styled_term]
	if INLINE_ICON_PATHS.has(term):
		return "%s %s" % [_icon_tag(str(INLINE_ICON_PATHS[term])), styled_term]
	return styled_term

static func _format_text(text):
	return _highlight_keywords(text)

static func _highlight_keywords(text):
	var rich_text = text
	var replacements = [
		["Diamante", _colorize("Diamante", DIAMOND_HEX)],
		["Platino", _colorize("Platino", PLATINUM_HEX)],
		["Bronce", _colorize("Bronce", BRONZE_HEX)],
		["Plata", _colorize("Plata", SILVER_HEX)],
		["Oro", _colorize("Oro", GOLD_RANK_HEX)],
		["Esencia", _colorize("Esencia", ESSENCE_HEX)],
		["esencia", _colorize("esencia", ESSENCE_HEX)],
		["Torres", _colorize("Torres", GOLD_HEX)],
		["torres", _colorize("torres", GOLD_HEX)],
		["Torre", _colorize("Torre", GOLD_HEX)],
		["torre", _colorize("torre", GOLD_HEX)],
		["Bendiciones", _colorize("Bendiciones", BLESSING_HEX)],
		["bendiciones", _colorize("bendiciones", BLESSING_HEX)],
		["Curar", _colorize("Curar", HEAL_HEX)],
		["curar", _colorize("curar", HEAL_HEX)],
		["cura", _colorize("cura", HEAL_HEX)],
		["Curacion", _colorize("Curacion", HEAL_HEX)],
		["curacion", _colorize("curacion", HEAL_HEX)],
		["dano", _colorize("dano", DAMAGE_HEX)],
		["Dano", _colorize("Dano", DAMAGE_HEX)],
	]
	for entry in replacements:
		rich_text = _replace_whole_word(rich_text, str(entry[0]), str(entry[1]))
	return rich_text

static func _replace_whole_word(text, target, replacement):
	var result = ""
	var index = 0
	var target_len = target.length()
	while index < text.length():
		var found = text.find(target, index)
		if found == -1:
			result += text.substr(index)
			break
		result += text.substr(index, found - index)
		var before_ok = found == 0 or _is_word_separator(text.unicode_at(found - 1))
		var after_index = found + target_len
		var after_ok = after_index >= text.length() or _is_word_separator(text.unicode_at(after_index))
		if before_ok and after_ok:
			result += replacement
		else:
			result += text.substr(found, target_len)
		index = found + target_len
	return result

static func _is_word_separator(codepoint):
	if codepoint >= 48 and codepoint <= 57:
		return false
	if codepoint >= 65 and codepoint <= 90:
		return false
	if codepoint >= 97 and codepoint <= 122:
		return false
	if codepoint == 95:
		return false
	if codepoint >= 192 and codepoint <= 255:
		return false
	return true

static func _colorize(text, color_hex):
	return "[color=%s]%s[/color]" % [color_hex, text]

static func _icon_tag(icon_path, size = 18):
	return "[img=%dx%d]%s[/img]" % [size, size, icon_path]
