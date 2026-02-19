extends Node
class_name Player

# All these should be passed with a bool "Are we still doing this pose? or did we finish?
signal THUMBS_UP_signal
signal POINT_AND_THUMBS_UP_signal 
signal POINT_signal 
signal PEACE_SIGN_signal 
signal FIST_signal 
signal SPOCK_signal  # Index & Middle jointed together away from Ring & Pinky
signal METAL_signal  # Eminem
signal INDEX_THUMB_PINCH_signal
signal NONE_signal   # Open Hand


var xr_interface: XRInterface


func enable_passthrough() -> bool:
    if xr_interface and xr_interface.is_passthrough_supported():
        return xr_interface.start_passthrough()
    else:
        var modes = xr_interface.get_supported_environment_blend_modes()
        if xr_interface.XR_ENV_BLEND_MODE_ALPHA_BLEND in modes:
            xr_interface.set_environment_blend_mode(xr_interface.XR_ENV_BLEND_MODE_ALPHA_BLEND)
            return true
        else:
            return false
            
func _ready():
    xr_interface = XRServer.primary_interface
    if xr_interface and xr_interface.is_initialized():
        print("OpenXR initialised successfully")
        # Turn off v-sync!
        DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
        # Change our main viewport to output to the HMD
        get_viewport().use_xr = true
        enable_passthrough()
    else:
        print("OpenXR not initialized, please check if your headset is connected")
    
    # Now to subscribe to what the hands are doing
    %L_HandPoseDetector.pose_started.connect(_on_hand_pose_detector_pose_started_L)
    %L_HandPoseDetector.pose_ended.connect(_on_hand_pose_detector_pose_ended_L)
    
    %R_HandPoseDetector.pose_started.connect(_on_hand_pose_detector_pose_started_R)
    %R_HandPoseDetector.pose_ended.connect(_on_hand_pose_detector_pose_ended_R)


func _process(delta: float) -> void:
    %Physics_Label.text = "Physics HZ: " + str(Engine.physics_ticks_per_second) + "\nBoid DLSS: " + str(Boid_Manager.Is_Using_Offbrand_Physics_DLSS())
    %FPS_Label.text = "FPS: " + str(Engine.get_frames_per_second())

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
