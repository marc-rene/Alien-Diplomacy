## SpeechTestUI.gd
## Attach to a Node3D in the test scene.
## Uses Label3D nodes so it's visible in VR world space.
##
## Expected children:
##   StatusLabel3D  (Label3D)
##   TranscriptLabel3D (Label3D)

extends Node3D

@onready var status_label: Label3D = $StatusLabel3D
@onready var transcript_label: Label3D = $TranscriptLabel3D

var _transcript_lines: Array[String] = []
const MAX_LINES := 6


func _ready() -> void:
	status_label.text = "Fist = talk"
	transcript_label.text = ""


func _on_mic_recorder_recording_state_changed(is_recording: bool) -> void:
	if is_recording:
		status_label.text = "Listening..."
		status_label.modulate = Color(1, 0.3, 0.3)
	else:
		status_label.text = "Transcribing..."
		status_label.modulate = Color(1, 1, 0.3)


func _on_mic_recorder_transcription_ready(text: String) -> void:
	status_label.text = "Fist = talk"
	status_label.modulate = Color(1, 1, 1)

	if text.strip_edges() == "":
		return  # Error or no-match — reset label but don't add blank line

	_transcript_lines.append(text)
	if _transcript_lines.size() > MAX_LINES:
		_transcript_lines.pop_front()

	transcript_label.text = "\n".join(_transcript_lines)
