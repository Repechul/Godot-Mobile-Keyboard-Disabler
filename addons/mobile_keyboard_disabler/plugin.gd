@tool
extends EditorPlugin

# Adds a toggle button to the CONTAINER_TOOLBAR (editor's main toolbar).
# When active, it disables Android's on-screen keyboard everywhere text
# can be entered in the editor: the Script editor, Inspector fields,
# FileSystem search, rename dialogs, SpinBox number entry, dialogs, etc.
# New fields created while the toggle is on (a freshly opened dialog, a
# newly selected node's Inspector row...) are picked up automatically.
#
# The state is intentionally NOT persisted in EditorSettings: every time
# the editor is opened, the toggle starts OFF (normal keyboard behavior).

var _toggle_button: Button
var _keyboard_disabled: bool = false

func _enter_tree() -> void:
	_toggle_button = Button.new()
	_toggle_button.flat = true
	_toggle_button.toggle_mode = true
	_toggle_button.button_pressed = _keyboard_disabled
	_assign_icon()
	_refresh_button_look()
	_toggle_button.toggled.connect(_on_toggle_pressed)

	add_control_to_container(CONTAINER_TOOLBAR, _toggle_button)

	get_tree().node_added.connect(_on_node_added)

func _exit_tree() -> void:
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)

	# Leave every field working normally once the plugin unloads.
		
	_apply_to_subtree(EditorInterface.get_base_control(), true)

	if _toggle_button:
		remove_control_from_container(CONTAINER_TOOLBAR, _toggle_button)
		_toggle_button.queue_free()
		_toggle_button = null

func _on_toggle_pressed(pressed: bool) -> void:
	_keyboard_disabled = pressed
	_refresh_button_look()
	
	# Re-sync every field that already exists; fields created from now on
	# are caught live by _on_node_added.
	
	_apply_to_subtree(EditorInterface.get_base_control(), not _keyboard_disabled)

func _on_node_added(node: Node) -> void:
	if not (node is LineEdit or node is TextEdit):
		return
	if not "virtual_keyboard_enabled" in node:
		return
	if _is_inside_subviewport(node):
		return
	node.virtual_keyboard_enabled = not _keyboard_disabled

func _apply_to_subtree(node: Node, keyboard_enabled: bool) -> void:
	if node is SubViewport:
		return # Never touch the scene being edited/previewed, only editor UI.
	if (node is LineEdit or node is TextEdit) and "virtual_keyboard_enabled" in node:
		node.virtual_keyboard_enabled = keyboard_enabled
		
	# include_internal=true, otherwise built-in composite fields (e.g. the
	# LineEdit inside every SpinBox) are invisible to get_children().
		
	for child in node.get_children(true):
		_apply_to_subtree(child, keyboard_enabled)

func _is_inside_subviewport(node: Node) -> bool:
	var current := node.get_parent()
	while current:
		if current is SubViewport:
			return true
		current = current.get_parent()
	return false

func _assign_icon() -> void:

	# Tries a native editor icon first; if none exists in the current
	# theme, the button just falls back to text only.

	var base_control := EditorInterface.get_base_control()
	for icon_name in ["Keyboard", "KeyboardShortcut", "InputEventKey"]:
		if base_control.has_theme_icon(icon_name, "EditorIcons"):
			_toggle_button.icon = base_control.get_theme_icon(icon_name, "EditorIcons")
			return

func _refresh_button_look() -> void:
	var has_icon := _toggle_button.icon != null
	if _keyboard_disabled:
		_toggle_button.text = "OFF" if has_icon else "Keyboard: OFF"
		_toggle_button.tooltip_text = "Virtual keyboard DISABLED throughout the editor.\nTap to reactivate it."
		_toggle_button.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3))
		_toggle_button.add_theme_color_override("font_pressed_color", Color(1.0, 0.5, 0.3))
		_toggle_button.add_theme_color_override("font_hover_color", Color(1.0, 0.5, 0.3))
	else:
		_toggle_button.text = "ON" if has_icon else "Keyboard: ON"
		_toggle_button.tooltip_text = "Virtual keyboard with normal behavior.\nTap to disable it throughout the editor."
		_toggle_button.remove_theme_color_override("font_color")
		_toggle_button.remove_theme_color_override("font_pressed_color")
		_toggle_button.remove_theme_color_override("font_hover_color")
