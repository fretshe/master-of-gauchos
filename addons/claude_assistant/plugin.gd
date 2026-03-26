@tool
extends EditorPlugin

const ClaudePanelScene := preload("res://addons/claude_assistant/claude_panel.tscn")

var _panel: Control = null

func _enter_tree() -> void:
	_panel = ClaudePanelScene.instantiate()
	# Right-bottom-left dock slot — appears alongside the Inspector as a tab
	add_control_to_dock(DOCK_SLOT_RIGHT_BL, _panel)

func _exit_tree() -> void:
	if _panel != null:
		remove_control_from_docks(_panel)
		_panel.queue_free()
		_panel = null

func get_plugin_name() -> String:
	return "Claude Assistant"
