extends PanelContainer

@onready var chat_label: RichTextLabel = $MarginContainer/VBoxContainer/ChatHistory
@onready var line_edit: LineEdit = $MarginContainer/VBoxContainer/TextEdit

const ROWS: Array = [
    ["q","w","e","r","t","y","u","i","o","p"],
    ["a","s","d","f","g","h","j","k","l","↵"],
    ["z","x","c","v","b","n","m","⌫"],
    ["SPACE"],
]

signal outcome_reached(outcome: String)  # "peace", "war", "stalemate"

var ai_chat: Node = null
var ai_busy: bool = false
var _warming_up: bool = false
var _outcome_declared: bool = false
var _exchange_count: int = 0
var _token_buffer: String = ""
var _flush_timer: float = 0.0
const FLUSH_INTERVAL: float = 0.05

# Alien voice synthesis
var _audio_player: AudioStreamPlayer = null
var _playback: AudioStreamGeneratorPlayback = null
var _alien_phase: float = 0.0
var _alien_freq: float = 300.0
var _alien_freq_target: float = 300.0
var _alien_wobble_timer: float = 0.0
var _alien_next_wobble: float = 0.1
const SAMPLE_RATE: float = 22050.0

# Emotion system
var _current_emotion: String = "neutral"
var _emotion_freq_min: float = 150.0
var _emotion_freq_max: float = 450.0
var _emotion_wobble_speed: float = 0.12
var _emotion_wobble_min: float = 0.06
var _emotion_wobble_max: float = 0.18
var _emotion_tremolo_speed: float = 0.008
var _emotion_harmonic: float = 0.15
var _emotion_check_buffer: String = ""

# [freq_min, freq_max, wobble_speed, wobble_min, wobble_max, tremolo_speed, harmonic, volume_db]
const EMOTION_PROFILES: Dictionary = {
    "neutral":   [150.0, 450.0, 0.12, 0.06, 0.18, 0.008, 0.15, -6.0],
    "happy":     [420.0, 950.0, 0.22, 0.03, 0.09, 0.018, 0.07, -4.0],
    "angry":     [70.0,  240.0, 0.25, 0.02, 0.06, 0.025, 0.38, -2.0],
    "intrigued": [220.0, 530.0, 0.06, 0.14, 0.30, 0.004, 0.09, -7.0],
    "menacing":  [50.0,  150.0, 0.04, 0.20, 0.45, 0.002, 0.42, -3.0],
}


func _ready() -> void:
    line_edit.virtual_keyboard_enabled = false
    _setup_audio()
    _setup_nobodywho()
    _build_keyboard()


func _setup_audio() -> void:
    var gen := AudioStreamGenerator.new()
    gen.mix_rate = SAMPLE_RATE
    gen.buffer_length = 0.15
    _audio_player = AudioStreamPlayer.new()
    _audio_player.stream = gen
    _audio_player.volume_db = -6.0
    add_child(_audio_player)


func _set_emotion(emotion: String) -> void:
    if emotion == _current_emotion:
        return
    _current_emotion = emotion
    var p: Array = EMOTION_PROFILES[emotion]
    _emotion_freq_min    = p[0]
    _emotion_freq_max    = p[1]
    _emotion_wobble_speed = p[2]
    _emotion_wobble_min  = p[3]
    _emotion_wobble_max  = p[4]
    _emotion_tremolo_speed = p[5]
    _emotion_harmonic    = p[6]
    if _audio_player:
        _audio_player.volume_db = p[7]


func _detect_emotion(text: String) -> String:
    var t := text.to_lower()
    var scores := {"neutral": 0, "happy": 0, "angry": 0, "intrigued": 0, "menacing": 0}
    for w in ["haha", "excellent", "good", "grand", "victory", "treasure", "pleased", "splendid", "brilliant", "ha"]:
        if t.contains(w): scores["happy"] += 1
    for w in ["fool", "insolent", "destroy", "blast", "worthless", "scum", "pathetic", "useless", "incompetent", "rage"]:
        if t.contains(w): scores["angry"] += 1
    for w in ["interesting", "curious", "hmm", "wonder", "fascinating", "strange", "peculiar", "unusual", "tell me", "explain"]:
        if t.contains(w): scores["intrigued"] += 1
    for w in ["beware", "suffer", "doom", "fear", "dread", "surrender", "perish", "darkness", "warning", "threat"]:
        if t.contains(w): scores["menacing"] += 1
    var best := "neutral"
    var best_score := 0
    for emotion in scores:
        if scores[emotion] > best_score:
            best_score = scores[emotion]
            best = emotion
    return best


func _start_alien_voice() -> void:
    _set_emotion("neutral")
    _emotion_check_buffer = ""
    _alien_freq = randf_range(_emotion_freq_min, _emotion_freq_max)
    _alien_freq_target = _alien_freq
    _alien_phase = 0.0
    _audio_player.play()
    _playback = _audio_player.get_stream_playback()


func _stop_alien_voice() -> void:
    _audio_player.stop()
    _playback = null


func _fill_alien_audio(delta: float) -> void:
    if _playback == null:
        return
    _alien_wobble_timer += delta
    if _alien_wobble_timer >= _alien_next_wobble:
        _alien_wobble_timer = 0.0
        _alien_next_wobble = randf_range(_emotion_wobble_min, _emotion_wobble_max)
        _alien_freq_target = randf_range(_emotion_freq_min, _emotion_freq_max)
    _alien_freq = lerpf(_alien_freq, _alien_freq_target, _emotion_wobble_speed)
    var frames := _playback.get_frames_available()
    for i in frames:
        _alien_phase = fmod(_alien_phase + _alien_freq / SAMPLE_RATE, 1.0)
        var s := sin(_alien_phase * TAU) * 0.5
        s += sin(_alien_phase * TAU * 2.1) * _emotion_harmonic
        s += sin(_alien_phase * TAU * 3.3) * (_emotion_harmonic * 0.5)
        var tremolo := sin(Time.get_ticks_msec() * _emotion_tremolo_speed) * 0.35 + 0.65
        s *= tremolo * 0.35
        _playback.push_frame(Vector2(s, s))


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
    ai_chat.set("system_prompt", """You are Dave, a ruthless space pirate warlord who has launched a boid fleet invasion of a planetary system. A diplomat is trying to negotiate with you to stop the attack.

Your personality: proud, greedy, aggressive. You respect strength, clever deals, real tribute. You despise weakness, empty promises, and flattery.

Always reply with 1-3 sentences in character first. Then, only when you are truly ready to declare an outcome, append a tag on a new line at the very end:
- Convinced by a strong offer or deal: append [OUTCOME:PEACE]
- Angered, insulted, or fed up: append [OUTCOME:WAR]
- Still negotiating: no tag at all.

Example of a peace response:
"Hmm. That tribute is... acceptable. You have bought your planets one more cycle, diplomat. [OUTCOME:PEACE]"

Example of a war response:
"You dare insult me with that offer?! The fleet doubles its attack! [OUTCOME:WAR]"

Never output a tag without a real response before it. Never explain the tags.""")
    ai_chat.set("model_node", model)
    add_child(ai_chat)

    ai_chat.connect("response_updated", _on_response_updated)
    ai_chat.connect("response_finished", _on_response_finished)

    chat_label.text = ""
    chat_label.append_text("[color=yellow]Connecting...[/color]\n")
    print("NobodyWho ready in TypingTest — warming up")
    _warming_up = true
    ai_busy = true
    ai_chat.ask(".")


func _make_holo_style(bg_alpha: float) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = Color(0.0, 0.8, 1.0, bg_alpha)
    s.border_color = Color(0.0, 1.0, 1.0, 0.9)
    s.set_border_width_all(1)
    s.set_corner_radius_all(6)
    s.content_margin_left = 2
    s.content_margin_right = 2
    s.content_margin_top = 2
    s.content_margin_bottom = 2
    return s


func _build_keyboard() -> void:
    var vbox: VBoxContainer = $MarginContainer/VBoxContainer

    # Holographic panel background
    var panel_style := StyleBoxFlat.new()
    panel_style.bg_color = Color(0.0, 0.05, 0.15, 0.75)
    panel_style.border_color = Color(0.0, 0.9, 1.0, 0.6)
    panel_style.set_border_width_all(2)
    panel_style.set_corner_radius_all(10)
    add_theme_stylebox_override("panel", panel_style)

    # Holographic LineEdit
    var line_style := StyleBoxFlat.new()
    line_style.bg_color = Color(0.0, 0.4, 1.0, 0.85)
    line_style.border_color = Color(0.0, 1.0, 1.0, 0.8)
    line_style.set_border_width_all(1)
    line_style.set_corner_radius_all(4)
    line_edit.add_theme_stylebox_override("normal", line_style)
    line_edit.add_theme_stylebox_override("focus", line_style)
    line_edit.add_theme_color_override("font_color", Color(0.0, 1.0, 1.0, 1.0))
    line_edit.add_theme_color_override("caret_color", Color(0.0, 1.0, 1.0, 1.0))
    line_edit.add_theme_color_override("selection_color", Color(0.0, 0.6, 0.8, 0.5))

    # Chat label color
    chat_label.add_theme_color_override("default_color", Color(0.0, 0.9, 1.0, 1.0))

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
            btn.add_theme_stylebox_override("normal", _make_holo_style(0.12))
            btn.add_theme_stylebox_override("hover", _make_holo_style(0.35))
            btn.add_theme_stylebox_override("pressed", _make_holo_style(0.6))
            btn.add_theme_stylebox_override("focus", _make_holo_style(0.12))
            btn.add_theme_color_override("font_color", Color(0.0, 1.0, 1.0, 1.0))
            btn.add_theme_color_override("font_hover_color", Color(0.8, 1.0, 1.0, 1.0))
            btn.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0, 1.0))
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
    chat_label.append_text("[color=cyan]Dave:[/color] ")
    ai_chat.ask(msg)
    _start_alien_voice()


func _process(delta: float) -> void:
    if not _token_buffer.is_empty():
        _flush_timer += delta
        if _flush_timer >= FLUSH_INTERVAL:
            chat_label.append_text(_token_buffer)
            _token_buffer = ""
            _flush_timer = 0.0
    if ai_busy and not _warming_up:
        _fill_alien_audio(delta)


func _on_response_updated(new_token: String) -> void:
    if _warming_up:
        return
    _token_buffer += new_token
    _emotion_check_buffer += new_token
    if _emotion_check_buffer.length() > 80:
        _set_emotion(_detect_emotion(_emotion_check_buffer))
        _emotion_check_buffer = ""


func _on_response_finished(_response: String) -> void:
    _stop_alien_voice()
    if not _token_buffer.is_empty():
        var cleaned := _token_buffer.replace("[OUTCOME:PEACE]", "").replace("[OUTCOME:WAR]", "").strip_edges()
        if not cleaned.is_empty():
            chat_label.append_text(cleaned)
        _token_buffer = ""
    if _warming_up:
        _warming_up = false
        ai_busy = false
        line_edit.editable = true
        chat_label.text = ""
        chat_label.append_text("[color=green]Connection established.[/color]\n")
        print("Warmup complete")
        return
    _exchange_count += 1
    _check_outcome(_response)
    chat_label.append_text("\n")
    ai_busy = false
    line_edit.editable = true
    line_edit.grab_focus()


func _check_outcome(response: String) -> void:
    if _outcome_declared:
        return
    if "[OUTCOME:PEACE]" in response:
        _outcome_declared = true
        _set_emotion("happy")
        outcome_reached.emit("peace")
        get_tree().call_group("outcome_listener", "receive_outcome", "peace")
        print("Outcome: PEACE")
    elif "[OUTCOME:WAR]" in response:
        _outcome_declared = true
        _set_emotion("angry")
        outcome_reached.emit("war")
        get_tree().call_group("outcome_listener", "receive_outcome", "war")
        print("Outcome: WAR")
