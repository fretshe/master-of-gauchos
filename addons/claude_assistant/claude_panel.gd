@tool
extends Control

# ─── API constants ──────────────────────────────────────────────────────────────
const API_URL     := "https://api.anthropic.com/v1/messages"
const MODEL       := "claude-sonnet-4-20250514"
const MAX_TOKENS  := 4096
const SETTING_KEY := "claude_assistant/api_key"

# ─── Palette (dark theme matching the Godot editor) ────────────────────────────
const C_BG       := Color(0.13, 0.13, 0.13, 1.0)
const C_SURFACE  := Color(0.17, 0.17, 0.17, 1.0)
const C_SURFACE2 := Color(0.20, 0.20, 0.20, 1.0)
const C_BORDER   := Color(0.28, 0.28, 0.28, 1.0)
const C_TEXT     := Color(0.85, 0.85, 0.85, 1.0)
const C_DIM      := Color(0.52, 0.52, 0.52, 1.0)
const C_ACCENT   := Color(0.55, 0.28, 0.92, 1.0)
const C_USER_BG  := Color(0.16, 0.14, 0.26, 1.0)
const C_ASST_BG  := Color(0.11, 0.18, 0.16, 1.0)
const C_SYS_BG   := Color(0.14, 0.14, 0.18, 1.0)
const C_ERR_BG   := Color(0.26, 0.08, 0.08, 1.0)
const C_BTN      := Color(0.30, 0.12, 0.58, 1.0)
const C_BTN_HOV  := Color(0.40, 0.18, 0.72, 1.0)
const C_BTN_PRE  := Color(0.22, 0.08, 0.44, 1.0)
const C_BTN_GRAY := Color(0.22, 0.22, 0.22, 1.0)

# ─── State ─────────────────────────────────────────────────────────────────────
var _messages: Array[Dictionary] = []
var _loading:  bool = false

# ─── UI node refs ──────────────────────────────────────────────────────────────
var _key_edit:   LineEdit
var _scroll:     ScrollContainer
var _chat_vbox:  VBoxContainer
var _msg_input:  TextEdit
var _send_btn:   Button
var _status_lbl: Label
var _http:       HTTPRequest

# ═══════════════════════════════════════════════════════════════════════════════
# Init
# ═══════════════════════════════════════════════════════════════════════════════
func _ready() -> void:
	_build_ui()
	_http = HTTPRequest.new()
	_http.use_threads = true
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)
	_load_api_key()
	_add_bubble("system", "Hola! Soy Claude.\nIngresá tu API key arriba y empezá a escribir.\n[Ctrl+Enter para enviar]")

func _exit_tree() -> void:
	if _http != null and _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		_http.cancel_request()

# ═══════════════════════════════════════════════════════════════════════════════
# UI construction
# ═══════════════════════════════════════════════════════════════════════════════
func _build_ui() -> void:
	# Root fills the dock panel
	var root: VBoxContainer = VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 4)
	add_child(root)

	# ── Header row ──────────────────────────────────────────────────────────
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 4)
	root.add_child(header)

	var title_lbl: Label = Label.new()
	title_lbl.text = "  ✦ Claude Assistant"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_color_override("font_color", C_ACCENT)
	title_lbl.add_theme_font_size_override("font_size", 13)
	header.add_child(title_lbl)

	var new_btn: Button = _make_btn("Nueva", Vector2(58, 26), C_BTN_GRAY, C_BORDER)
	new_btn.tooltip_text = "Iniciar nueva conversación"
	new_btn.pressed.connect(_clear_conversation)
	header.add_child(new_btn)

	_add_hsep(root)

	# ── API key row ──────────────────────────────────────────────────────────
	var key_row: HBoxContainer = HBoxContainer.new()
	key_row.add_theme_constant_override("separation", 4)
	root.add_child(key_row)

	var key_lbl: Label = Label.new()
	key_lbl.text = " API Key:"
	key_lbl.custom_minimum_size = Vector2(62, 0)
	key_lbl.add_theme_color_override("font_color", C_DIM)
	key_lbl.add_theme_font_size_override("font_size", 11)
	key_row.add_child(key_lbl)

	_key_edit = LineEdit.new()
	_key_edit.placeholder_text = "sk-ant-api03-..."
	_key_edit.secret = true
	_key_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_key_edit.add_theme_font_size_override("font_size", 11)
	_key_edit.add_theme_color_override("font_color", C_TEXT)
	_key_edit.text_changed.connect(_on_api_key_changed)
	key_row.add_child(_key_edit)

	_add_hsep(root)

	# ── Chat scroll area ─────────────────────────────────────────────────────
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_scroll)

	_chat_vbox = VBoxContainer.new()
	_chat_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_vbox.add_theme_constant_override("separation", 6)
	_scroll.add_child(_chat_vbox)

	# ── Status label (hidden when idle) ─────────────────────────────────────
	_status_lbl = Label.new()
	_status_lbl.text = ""
	_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_lbl.add_theme_color_override("font_color", C_DIM)
	_status_lbl.add_theme_font_size_override("font_size", 11)
	_status_lbl.visible = false
	root.add_child(_status_lbl)

	_add_hsep(root)

	# ── Message input ────────────────────────────────────────────────────────
	_msg_input = TextEdit.new()
	_msg_input.placeholder_text = "Escribí tu mensaje… (Ctrl+Enter para enviar)"
	_msg_input.custom_minimum_size = Vector2(0, 70)
	_msg_input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_msg_input.add_theme_font_size_override("font_size", 12)
	_msg_input.add_theme_color_override("font_color", C_TEXT)
	_msg_input.gui_input.connect(_on_input_gui_event)
	root.add_child(_msg_input)

	# ── Send row ─────────────────────────────────────────────────────────────
	var send_row: HBoxContainer = HBoxContainer.new()
	send_row.add_theme_constant_override("separation", 4)
	root.add_child(send_row)

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	send_row.add_child(spacer)

	_send_btn = _make_btn("Enviar  ▶", Vector2(96, 30), C_BTN, C_ACCENT)
	_send_btn.pressed.connect(_send_message)
	send_row.add_child(_send_btn)

# ═══════════════════════════════════════════════════════════════════════════════
# Widget builders
# ═══════════════════════════════════════════════════════════════════════════════
func _add_hsep(parent: Control) -> void:
	var sep: HSeparator = HSeparator.new()
	parent.add_child(sep)

func _make_btn(text: String, min_sz: Vector2, bg: Color, border: Color) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.custom_minimum_size = min_sz
	btn.add_theme_font_size_override("font_size", 11)
	btn.add_theme_color_override("font_color", C_TEXT)
	for k: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var s: StyleBoxFlat = StyleBoxFlat.new()
		if k == "hover":
			s.bg_color = bg.lightened(0.12)
		elif k == "pressed":
			s.bg_color = bg.darkened(0.18)
		elif k == "disabled":
			s.bg_color = bg.darkened(0.30)
		else:
			s.bg_color = bg
		s.border_color = border
		s.set_border_width_all(1)
		s.corner_radius_top_left     = 4
		s.corner_radius_top_right    = 4
		s.corner_radius_bottom_left  = 4
		s.corner_radius_bottom_right = 4
		s.content_margin_left   = 8.0
		s.content_margin_right  = 8.0
		s.content_margin_top    = 3.0
		s.content_margin_bottom = 3.0
		btn.add_theme_stylebox_override(k, s)
	return btn

func _make_panel_style(bg: Color, radius: int = 6) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = bg
	s.corner_radius_top_left     = radius
	s.corner_radius_top_right    = radius
	s.corner_radius_bottom_left  = radius
	s.corner_radius_bottom_right = radius
	s.content_margin_left   = 8.0
	s.content_margin_right  = 8.0
	s.content_margin_top    = 6.0
	s.content_margin_bottom = 6.0
	return s

# ═══════════════════════════════════════════════════════════════════════════════
# Chat bubble
# ═══════════════════════════════════════════════════════════════════════════════
func _add_bubble(role: String, text: String) -> void:
	var container: PanelContainer = PanelContainer.new()
	var bg_color: Color
	match role:
		"user":      bg_color = C_USER_BG
		"assistant": bg_color = C_ASST_BG
		"error":     bg_color = C_ERR_BG
		_:           bg_color = C_SYS_BG
	container.add_theme_stylebox_override("panel", _make_panel_style(bg_color))
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	container.add_child(vbox)

	# Role label (skip for system messages)
	if role != "system":
		var role_lbl: Label = Label.new()
		role_lbl.add_theme_font_size_override("font_size", 10)
		match role:
			"user":
				role_lbl.text = "Vos"
				role_lbl.add_theme_color_override("font_color", Color(0.70, 0.60, 1.00))
			"assistant":
				role_lbl.text = "Claude"
				role_lbl.add_theme_color_override("font_color", C_ACCENT)
			"error":
				role_lbl.text = "Error"
				role_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		vbox.add_child(role_lbl)

	# Message body
	var rtl: RichTextLabel = RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rtl.add_theme_color_override("default_color", C_TEXT)
	rtl.add_theme_font_size_override("normal_font_size", 12)
	rtl.text = text
	vbox.add_child(rtl)

	_chat_vbox.add_child(container)
	_scroll_to_bottom_deferred()

func _scroll_to_bottom_deferred() -> void:
	await get_tree().process_frame
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)

# ═══════════════════════════════════════════════════════════════════════════════
# Actions
# ═══════════════════════════════════════════════════════════════════════════════
func _send_message() -> void:
	var text: String    = _msg_input.text.strip_edges()
	var api_key: String = _key_edit.text.strip_edges()

	if text.is_empty() or _loading:
		return

	if api_key.is_empty():
		_set_status("⚠  Ingresá tu API key antes de enviar.", true)
		return

	_save_api_key(api_key)
	_msg_input.text = ""
	_messages.append({"role": "user", "content": text})
	_add_bubble("user", text)
	_set_loading(true)
	_call_api(api_key)

func _call_api(api_key: String) -> void:
	var body: Dictionary = {
		"model":      MODEL,
		"max_tokens": MAX_TOKENS,
		"messages":   _messages,
	}
	var headers: PackedStringArray = PackedStringArray([
		"Content-Type: application/json",
		"x-api-key: " + api_key,
		"anthropic-version: 2023-06-01",
	])
	var err: int = _http.request(
		API_URL, headers, HTTPClient.METHOD_POST, JSON.stringify(body)
	)
	if err != OK:
		_set_loading(false)
		_add_bubble("error", "No se pudo iniciar la petición (error %d)." % err)

func _on_request_completed(
		result: int, code: int,
		_headers: PackedStringArray, body: PackedByteArray) -> void:
	_set_loading(false)

	if result != HTTPRequest.RESULT_SUCCESS:
		_add_bubble("error", "Error de red (resultado %d).\nRevisá tu conexión." % result)
		return

	var raw: String = body.get_string_from_utf8()

	if code != 200:
		# Try to extract the error message from the API JSON
		var jtest: JSON = JSON.new()
		var msg: String = raw
		if jtest.parse(raw) == OK:
			var d: Dictionary = jtest.data
			if d.has("error") and (d["error"] as Dictionary).has("message"):
				msg = d["error"]["message"]
		_add_bubble("error", "API devolvió %d:\n%s" % [code, msg.substr(0, 400)])
		return

	var json: JSON = JSON.new()
	if json.parse(raw) != OK:
		_add_bubble("error", "No se pudo parsear la respuesta de la API.")
		return

	var data: Dictionary = json.data
	if not data.has("content"):
		_add_bubble("error", "Respuesta inesperada de la API (sin campo 'content').")
		return

	var content: Array = data["content"]
	if content.is_empty():
		_add_bubble("error", "La API devolvió contenido vacío.")
		return

	var first: Dictionary = content[0]
	if not first.has("text"):
		_add_bubble("error", "Bloque de contenido sin campo 'text'.")
		return

	var reply: String = first["text"]
	_messages.append({"role": "assistant", "content": reply})
	_add_bubble("assistant", reply)

func _clear_conversation() -> void:
	_messages.clear()
	for child: Node in _chat_vbox.get_children():
		child.queue_free()
	# Small delay so queue_free runs before we add the welcome bubble
	await get_tree().process_frame
	_add_bubble("system", "Nueva conversación iniciada.")

# ═══════════════════════════════════════════════════════════════════════════════
# UI state helpers
# ═══════════════════════════════════════════════════════════════════════════════
func _set_loading(val: bool) -> void:
	_loading          = val
	_send_btn.disabled = val
	_send_btn.text     = "  …  " if val else "Enviar  ▶"
	if val:
		_set_status("Esperando respuesta de Claude…", false)
	else:
		_set_status("", false)

func _set_status(msg: String, is_error: bool) -> void:
	_status_lbl.text    = msg
	_status_lbl.visible = not msg.is_empty()
	var col: Color = Color(0.90, 0.35, 0.35) if is_error else C_DIM
	_status_lbl.add_theme_color_override("font_color", col)

# ═══════════════════════════════════════════════════════════════════════════════
# API key persistence via EditorSettings
# ═══════════════════════════════════════════════════════════════════════════════
func _save_api_key(key: String) -> void:
	if not Engine.is_editor_hint():
		return
	var settings: EditorSettings = EditorInterface.get_editor_settings()
	if not settings.has_setting(SETTING_KEY):
		settings.add_property_info({
			"name":        SETTING_KEY,
			"type":        TYPE_STRING,
			"hint":        PROPERTY_HINT_PASSWORD,
			"hint_string": "",
		})
	settings.set_setting(SETTING_KEY, key)

func _load_api_key() -> void:
	if not Engine.is_editor_hint():
		return
	var settings: EditorSettings = EditorInterface.get_editor_settings()
	if settings.has_setting(SETTING_KEY):
		_key_edit.text = str(settings.get_setting(SETTING_KEY))

func _on_api_key_changed(new_key: String) -> void:
	_save_api_key(new_key)

# ═══════════════════════════════════════════════════════════════════════════════
# Keyboard shortcut: Ctrl+Enter sends the message
# ═══════════════════════════════════════════════════════════════════════════════
func _on_input_gui_event(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER and event.ctrl_pressed:
			_send_message()
			_msg_input.accept_event()
