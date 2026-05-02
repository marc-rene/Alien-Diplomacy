extends Node
class_name Player

# Bool argument: true = gesture started, false = gesture ended
signal THUMBS_UP_signal(started: bool)
signal POINT_AND_THUMBS_UP_signal(started: bool)
signal POINT_signal(started: bool)
signal PEACE_SIGN_signal(started: bool)
signal FIST_signal(started: bool)
signal SPOCK_signal(started: bool)
signal METAL_signal(started: bool)
signal INDEX_THUMB_PINCH_signal(started: bool)
signal NONE_signal(started: bool)


func _ready() -> void:
	# XR is initialised by the scene's main.gd — Player only wires up hand tracking
	%L_HandPoseDetector.pose_started.connect(_on_hand_pose_detector_pose_started_L)
	%L_HandPoseDetector.pose_ended.connect(_on_hand_pose_detector_pose_ended_L)
	%R_HandPoseDetector.pose_started.connect(_on_hand_pose_detector_pose_started_R)
	%R_HandPoseDetector.pose_ended.connect(_on_hand_pose_detector_pose_ended_R)


func _process(_delta: float) -> void:
	%FPS_Label.text = "FPS: " + str(Engine.get_frames_per_second())
	# Physics_Label only meaningful when a Boid_Manager is present
	if is_instance_valid(Engine.get_singleton("Boid_Manager") if Engine.has_singleton("Boid_Manager") else null):
		pass  # extend here if you bring boids back into this scene
	else:
		%Physics_Label.text = ""

func pose_change(pose_name : String, started : bool):
	match pose_name:
		"ThumbsUp":
			THUMBS_UP_signal.emit(started)
		"Point Thumb Up":
			POINT_AND_THUMBS_UP_signal.emit(started)
		"Point":
			POINT_signal.emit(started)
		"Peace Sign":
			PEACE_SIGN_signal.emit(started)
		"Fist":
			FIST_signal.emit(started)
		"Spock":
			SPOCK_signal.emit(started)
		"Metal":
			METAL_signal.emit(started)
		"Index Pinch":
			INDEX_THUMB_PINCH_signal.emit(started)
		_:
			NONE_signal.emit(started)

func _on_hand_pose_detector_pose_started_L(p_name: String) -> void:
	pose_change(p_name, true)
	%L_Label.text = p_name
	
func _on_hand_pose_detector_pose_ended_L(p_name: String) -> void:
	pose_change(p_name, false)
	%L_Label.text = "L-Hand"


func _on_hand_pose_detector_pose_started_R(p_name: String) -> void:
	pose_change(p_name, true)
	%R_Label.text = p_name

func _on_hand_pose_detector_pose_ended_R(p_name: String) -> void:
	pose_change(p_name, false)
	%R_Label.text = "R-Hand"
