extends PanelContainer

@onready var line_edit: LineEdit = $MarginContainer/VBoxContainer/TextEdit

const ROWS: Array = [
	["q","w","e","r","t","y","u","i","o","p"],
	["a","s","d","f","g","h","j","k","l","↵"],
	["z","x","c","v","b","n","m","⌫"],
	["SPACE"],
]


func _ready() -> void:
	var vbox: VBoxContainer = $MarginContainer/VBoxContainer

	var keyboard_vbox := VBoxContainer.new()
	keyboard_vbox.name = "KeyboardRows"
	keyboard_vbox.size_flags_vertical = SIZE_EXPAND_FILL
	keyboard_vbox.add_theme_constant_override("separation", 4)
	vbox.add_child(keyboard_vbox)

	for row: Array in ROWS:
		var hbox := HBoxContainer.new()
		hbox.size_flags_vertical = SIZE_EXPAND_FILL
		hbox.add_theme_constant_override("separation", 4)
		keyboard_vbox.add_child(hbox)

		for key: String in row:
			var btn := Button.new()
			btn.text = key
			btn.size_flags_horizontal = SIZE_EXPAND_FILL
			btn.size_flags_vertical = SIZE_EXPAND_FILL
			btn.pressed.connect(_on_key_pressed.bind(key))
			hbox.add_child(btn)


func _on_key_pressed(key: String) -> void:
	# Make sure the LineEdit has focus so caret is active
	if not line_edit.has_focus():
		line_edit.grab_focus()

	match key:
		"⌫":
			var t := line_edit.text
			if t.length() > 0:
				line_edit.text = t.left(t.length() - 1)
				line_edit.caret_column = line_edit.text.length()
		"SPACE":
			line_edit.insert_text_at_caret(" ")
		"↵":
			# Push Enter as an InputEventKey directly into this SubViewport
			# (bypasses main-viewport _input which doesn't fire in XR)
			var ev_down := InputEventKey.new()
			ev_down.keycode = KEY_ENTER
			ev_down.physical_keycode = KEY_ENTER
			ev_down.pressed = true
			get_viewport().push_input(ev_down)
			var ev_up := InputEventKey.new()
			ev_up.keycode = KEY_ENTER
			ev_up.physical_keycode = KEY_ENTER
			ev_up.pressed = false
			get_viewport().push_input(ev_up)
		_:
			line_edit.insert_text_at_caret(key)
