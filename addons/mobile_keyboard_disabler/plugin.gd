@tool
extends EditorPlugin

# Keyboard Disabler
# Añade un botón toggle al CONTAINER_TOOLBAR (barra principal del editor).
# Cuando está activo, desactiva el teclado virtual de Android mientras se
# tapea dentro del área de código de la pantalla "Scripts".
#
# El estado NO se persiste en EditorSettings a propósito: cada vez que se
# abre el editor, el toggle vuelve a su valor por defecto (OFF = teclado
# virtual normal).

var _toggle_button: Button
var _keyboard_disabled: bool = false
var _script_editor: ScriptEditor


func _enter_tree() -> void:
	_script_editor = EditorInterface.get_script_editor()

	_toggle_button = Button.new()
	_toggle_button.flat = true
	_toggle_button.toggle_mode = true
	_toggle_button.button_pressed = _keyboard_disabled
	_assign_icon()
	_refresh_button_look()
	_toggle_button.toggled.connect(_on_toggle_pressed)

	add_control_to_container(CONTAINER_TOOLBAR, _toggle_button)

	if _script_editor and not _script_editor.editor_script_changed.is_connected(_on_editor_script_changed):
		_script_editor.editor_script_changed.connect(_on_editor_script_changed)


func _exit_tree() -> void:
	if _script_editor and _script_editor.editor_script_changed.is_connected(_on_editor_script_changed):
		_script_editor.editor_script_changed.disconnect(_on_editor_script_changed)

	# Al desactivar el plugin, dejamos el teclado virtual funcionando normal.
	_apply_virtual_keyboard_state(true)

	if _toggle_button:
		remove_control_from_container(CONTAINER_TOOLBAR, _toggle_button)
		_toggle_button.queue_free()
		_toggle_button = null


func _on_toggle_pressed(pressed: bool) -> void:
	_keyboard_disabled = pressed
	_refresh_button_look()
	_apply_virtual_keyboard_state(not _keyboard_disabled)


func _on_editor_script_changed(_script: Script) -> void:
	# Se dispara al abrir un script o cambiar de pestaña: reaplicamos el
	# estado actual por si el nuevo editor de código aún no lo tiene.
	_apply_virtual_keyboard_state(not _keyboard_disabled)


func _apply_virtual_keyboard_state(keyboard_enabled: bool) -> void:
	if not _script_editor:
		return
	for editor in _script_editor.get_open_script_editors():
		if not editor.has_method("get_base_editor"):
			continue
		var base_editor: Control = editor.get_base_editor()
		if base_editor is TextEdit and "virtual_keyboard_enabled" in base_editor:
			base_editor.virtual_keyboard_enabled = keyboard_enabled


func _assign_icon() -> void:
	# Intenta usar un ícono nativo del editor; si ninguno existe en el
	# tema actual, el botón se queda sin ícono y usa solo texto.
	var base_control := EditorInterface.get_base_control()
	for icon_name in ["Keyboard", "KeyboardShortcut", "InputEventKey"]:
		if base_control.has_theme_icon(icon_name, "EditorIcons"):
			_toggle_button.icon = base_control.get_theme_icon(icon_name, "EditorIcons")
			return


func _refresh_button_look() -> void:
	var has_icon := _toggle_button.icon != null
	if _keyboard_disabled:
		_toggle_button.text = "OFF" if has_icon else "Keyboard: OFF"
		_toggle_button.tooltip_text = "Virtual keyboard DISABLED in the Scripts editor.\nTap to reactivate it."
		_toggle_button.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3))
		_toggle_button.add_theme_color_override("font_pressed_color", Color(1.0, 0.5, 0.3))
		_toggle_button.add_theme_color_override("font_hover_color", Color(1.0, 0.5, 0.3))
	else:
		_toggle_button.text = "ON" if has_icon else "Keyboard: ON"
		_toggle_button.tooltip_text = "Virtual keyboard with normal behavior.\nTap to disable it in the Scripts editor."
		_toggle_button.remove_theme_color_override("font_color")
		_toggle_button.remove_theme_color_override("font_pressed_color")
		_toggle_button.remove_theme_color_override("font_hover_color")
