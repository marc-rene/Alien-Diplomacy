extends PanelContainer

@onready var chat_label: RichTextLabel = $MarginContainer/VBoxContainer/ChatHistory
@onready var line_edit: LineEdit = $MarginContainer/VBoxContainer/TextEdit

const ROWS: Array = [
    ["q","w","e","r","t","y","u","i","o","p"],
    ["a","s","d","f","g","h","j","k","l","↵"],
    ["z","x","c","v","b","n","m","⌫"],
    ["SPACE"],
]

var ai_chat: Node = null
var ai_busy: bool = false


func _ready() -> void:
    line_edit.virtual_keyboard_enabled = false
    _setup_nobodywho()
    _build_keyboard()


var _last_tried_paths: Array[String] = []


func _print_all_files_in_dir(dir_path: String) -> void:
    var dir := DirAccess.open(dir_path)
    if dir == null:
        print("Could not open directory: ", dir_path)
        return

    dir.list_dir_begin()
    var item_name := dir.get_next()
    while item_name != "":
        if item_name != "." and item_name != "..":
            var full_path := dir_path.path_join(item_name)
            if dir.current_is_dir():
                _print_all_files_in_dir(full_path)
            else:
                print(full_path)
        item_name = dir.get_next()
    dir.list_dir_end()


func _resolve_model_path(filename: String) -> String:
    var candidates: Array[String] = []
    print("All files in user:// are:")
    _print_all_files_in_dir("user://")
    if OS.get_name() == "Android":
        var user_dir := OS.get_user_data_dir()
        candidates = [
            "user://" + filename,
            OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS) + filename,
            "/sdcard/Android/data/com.example.aliendiplomacy/files/" + filename,
            user_dir + "/" + filename,
            "/sdcard/" + filename,
            "/storage/emulated/0/" + filename,
        ]
    else:
        candidates = [
            ProjectSettings.globalize_path("res://" + filename),
        ]

    _last_tried_paths = candidates
    for path in candidates:
        if FileAccess.file_exists(path):
            print("Model found at: ", path)
            return path
        else:
            print("Model was NOT at ", path)

    return ""


func _setup_nobodywho() -> void:
    if not ClassDB.class_exists("NobodyWhoModel") or not ClassDB.class_exists("NobodyWhoChat"):
        chat_label.text = "[color=yellow]NobodyWho not available on this platform.[/color]"
        return

    const MODEL_FILENAME := "gemma-2-2b-it-Q4_K_M.gguf"
    var model_path := _resolve_model_path(MODEL_FILENAME)
    if model_path.is_empty():
        var user_dir := OS.get_user_data_dir()
        var paths_str := "\n".join(_last_tried_paths)
        chat_label.text = (
			"[color=red]Model file not found![/color]\n\n"
            + "[color=yellow]App data dir:[/color]\n" + user_dir + "\n\n"
            + "[color=yellow]Looked in:[/color]\n" + paths_str + "\n\n"
            + "[color=white]Push with ADB:[/color]\nadb push gemma-2-2b-it-Q4_K_M.gguf \""
            + user_dir + "/gemma-2-2b-it-Q4_K_M.gguf\""
        )
        return

    var model = ClassDB.instantiate("NobodyWhoModel")
    model.name = "NobodyWhoModel"
    model.set("model_path", model_path)
    add_child(model)

    ai_chat = ClassDB.instantiate("NobodyWhoChat")
    ai_chat.name = "NobodyWhoChat"
    ai_chat.set("system_prompt", "You are Commander Zyx, a battle-hardened space pirate from the Outer Rim. You speak with authority and menace, use space pirate slang, and keep your answers short and intimidating.")
    ai_chat.set("model_node", model)
    add_child(ai_chat)

    ai_chat.connect("response_updated", _on_response_updated)
    ai_chat.connect("response_finished", _on_response_finished)

    chat_label.text = ""
    chat_label.append_text("[color=green]AI ready — start talking![/color]\n")
    print("NobodyWho ready in TypingTest")


func _build_keyboard() -> void:
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
            _send_message()
        _:
            line_edit.insert_text_at_caret(key)


func _send_message() -> void:
    var msg := line_edit.text.strip_edges()
    if msg.is_empty() or ai_busy:
        return
    if ai_chat == null:
        chat_label.append_text("[color=red]No AI available.[/color]\n")
        return

    ai_busy = true
    line_edit.text = ""
    line_edit.editable = false
    chat_label.append_text("[color=cyan]You:[/color] " + msg + "\n")
    chat_label.append_text("[color=white]AI:[/color] ")
    ai_chat.ask(msg)


func _on_response_updated(new_token: String) -> void:
    chat_label.append_text(new_token)


func _on_response_finished(_response: String) -> void:
    chat_label.append_text("\n")
    ai_busy = false
    line_edit.editable = true
    line_edit.grab_focus()
