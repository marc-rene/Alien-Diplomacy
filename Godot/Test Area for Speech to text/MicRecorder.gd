## MicRecorder.gd
## Captures mic input using AudioServer directly (Julian Todd method),
## transcribes on gesture/key release via godot-whisper, then emits the text.
##
## Scene setup:
##   - Attach this to a plain Node
##   - Set `stt_node` in the inspector to a CaptureStreamToText node (with language_model assigned)
##   - Set `player` in the inspector to your Player node (for VR gesture input)
##   - Connect `transcription_ready(text)` signal to whatever needs the text

extends Node

## Emitted when a full transcription is ready
signal transcription_ready(text: String)

## Emitted while recording so the UI can show a "listening..." indicator
signal recording_state_changed(is_recording: bool)

## CaptureStreamToText node — assign in inspector (needs language_model set on it)
@export var stt_node: Node

## The Player node — used to connect to FIST_signal for push-to-talk
@export var player: Player

## Max recording time in seconds before auto-stop (0 = disabled)
@export var max_record_seconds: float = 10.0

var _accumulating := false
var _accumulated_frames: PackedVector2Array = []
var _transcribe_thread: Thread = null
var _record_timer := 0.0


func _ready() -> void:
    # Julian Todd method — activate mic input at the AudioServer level
    AudioServer.set_input_device_active(true)

    # CaptureStreamToText needs a "Record" bus with AudioEffectCapture to exist
    # Load the pre-built bus layout from the whisper samples so it doesn't crash
    var bus_layout = load("res://samples/godot_whisper/sample_bus_layout.tres")
    if bus_layout:
        AudioServer.set_bus_layout(bus_layout)
    else:
        push_warning("MicRecorder: Could not load sample_bus_layout.tres — CaptureStreamToText may crash.")

    # Stop CaptureStreamToText from running its own capture loop — we feed it manually
    if stt_node:
        stt_node.set("recording", false)
    else:
        push_warning("MicRecorder: No stt_node assigned — transcription will not work.")

    # Connect VR gesture (Fist = hold to talk)
    if player:
        player.FIST_signal.connect(_on_fist)
    else:
        push_warning("MicRecorder: No Player assigned — VR gesture input disabled. Use Space key for desktop testing.")


func _process(delta: float) -> void:
    if not _accumulating:
        return

    # Julian Todd method — pull frames directly from AudioServer each frame
    var available := AudioServer.get_input_frames_available()
    if available > 0:
        _accumulated_frames.append_array(AudioServer.get_input_frames(available))

    # Auto-stop if we hit the time limit
    if max_record_seconds > 0.0:
        _record_timer += delta
        if _record_timer >= max_record_seconds:
            _stop_recording()


func _unhandled_input(event: InputEvent) -> void:
    # Desktop fallback: hold T to talk
    if event is InputEventKey and event.keycode == KEY_T:
        if event.pressed and not event.echo and not _accumulating:
            _start_recording()
        elif not event.pressed and _accumulating:
            _stop_recording()


# --- VR gesture ---

func _on_fist(started: bool) -> void:
    if started:
        _start_recording()
    else:
        _stop_recording()


# --- Recording control ---

func _start_recording() -> void:
    if _transcribe_thread and _transcribe_thread.is_alive():
        push_warning("MicRecorder: Still transcribing previous clip — ignoring.")
        return
    _accumulated_frames.clear()
    _record_timer = 0.0
    _accumulating = true
    recording_state_changed.emit(true)
    print("MicRecorder: recording started")


func _stop_recording() -> void:
    if not _accumulating:
        return
    _accumulating = false
    recording_state_changed.emit(false)
    print("MicRecorder: recording stopped — %d frames captured" % _accumulated_frames.size())

    if _accumulated_frames.is_empty():
        push_warning("MicRecorder: No frames captured.")
        return

    _transcribe_thread = Thread.new()
    _transcribe_thread.start(_do_transcribe.bind(_accumulated_frames.duplicate()))
    _accumulated_frames.clear()


# --- Transcription (runs on background thread) ---

func _do_transcribe(frames: PackedVector2Array) -> void:
    if not stt_node:
        push_warning("MicRecorder: stt_node is null.")
        return

    # resample() and transcribe() are methods on SpeechToText (CaptureStreamToText's base)
    var resampled: PackedFloat32Array = stt_node.resample(frames, 0)  # 0 = SRC_SINC_FASTEST
    if resampled.is_empty():
        push_warning("MicRecorder: resample returned empty — check mic permissions.")
        return

    var tokens: Array = stt_node.transcribe(resampled, "", 0)
    if tokens.is_empty():
        push_warning("MicRecorder: transcribe returned no tokens.")
        return

    var full_text: String = tokens[0].strip_edges() if tokens.size() > 0 else ""

    call_deferred("_on_transcription_done", full_text)


func _on_transcription_done(text: String) -> void:
    print("MicRecorder: transcribed → \"%s\"" % text)
    transcription_ready.emit(text)
    if _transcribe_thread:
        _transcribe_thread.wait_to_finish()
        _transcribe_thread = null


# --- Cleanup on exit / app pause (covers both desktop and Android/Quest) ---

func _notification(what: int) -> void:
    match what:
        NOTIFICATION_WM_CLOSE_REQUEST, \
        NOTIFICATION_APPLICATION_PAUSED, \
        NOTIFICATION_EXIT_TREE:
            _accumulating = false
            if _transcribe_thread and _transcribe_thread.is_alive():
                _transcribe_thread.wait_to_finish()
            _transcribe_thread = null
