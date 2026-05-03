## AndroidSpeechRecognizer.gd
## Drop-in replacement for MicRecorder.gd on Android / Meta Quest.
## Wraps the SpeechRecognizerPlugin AAR via Godot's plugin singleton.
##
## Emits the same signals as MicRecorder so SpeechTestUI.gd needs no changes:
##   recording_state_changed(is_recording: bool)
##   transcription_ready(text: String)
##
## Call start_listening() on fist gesture (same as before).

extends Node

signal recording_state_changed(is_recording: bool)
signal transcription_ready(text: String)

## Assign the Player node in the Inspector (same as MicRecorder.gd used to need).
@export var player: Node = null

var _plugin: Object = null


func _ready() -> void:
    if not OS.has_feature("android"):
        push_warning("AndroidSpeechRecognizer: not on Android, plugin unavailable")
    else:
        if Engine.has_singleton("SpeechRecognizerPlugin"):
            _plugin = Engine.get_singleton("SpeechRecognizerPlugin")
            _plugin.transcription_ready.connect(_on_transcription_ready)
            _plugin.recording_state_changed.connect(_on_recording_state_changed)
            _plugin.speech_error.connect(_on_speech_error)
            print("AndroidSpeechRecognizer: plugin loaded OK")
            # Ask for microphone permission on first run
            OS.request_permissions()
        else:
            printerr("AndroidSpeechRecognizer: SpeechRecognizerPlugin singleton not found — is the AAR in android/build/libs?")

    # Auto-find Player if not assigned in inspector
    if player == null:
        player = get_node_or_null("../Player")
    if player == null:
        player = get_node_or_null("/root/Speechtest/Player")

    # Wire up VR fist gesture
    if player and player.has_signal("FIST_signal"):
        player.FIST_signal.connect(_on_fist)
        print("AndroidSpeechRecognizer: fist gesture connected to ", player.name)
    else:
        push_warning("AndroidSpeechRecognizer: Could not find Player node — fist gesture won't work")


func _on_fist(started: bool) -> void:
    if started:
        start_listening()
    else:
        stop_listening()


## Keyboard fallback: hold T to talk (mirrors MicRecorder.gd behaviour).
func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.keycode == KEY_T:
        if event.pressed and not event.echo:
            start_listening()
        elif not event.pressed:
            stop_listening()


func start_listening() -> void:
    if _plugin:
        _plugin.startListening()


func stop_listening() -> void:
    if _plugin:
        _plugin.stopListening()


func _on_recording_state_changed(is_recording: bool) -> void:
    recording_state_changed.emit(is_recording)


func _on_transcription_ready(text: String) -> void:
    transcription_ready.emit(text)


func _on_speech_error(error_code: int) -> void:
    # Android SpeechRecognizer error codes:
    # -1 = no microphone permission
    #  2 = network error (Quest not on Wi-Fi?)
    #  5 = client error (recognizer in bad state — now auto-reset in plugin)
    #  7 = no match (spoke but nothing recognised — safe to retry)
    #  8 = recognizer busy
    #  9 = insufficient permissions
    # 13 = language unavailable (offline pack missing — needs Wi-Fi for online mode)
    printerr("AndroidSpeechRecognizer: error code ", error_code)
    recording_state_changed.emit(false)
    # Always emit transcription_ready so the UI never gets stuck on "Transcribing..."
    transcription_ready.emit("")
