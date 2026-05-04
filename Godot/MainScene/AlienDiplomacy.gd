extends Node3D

var xr_interface: XRInterface


func enable_passthrough() -> bool:
    if xr_interface == null:
        return false
    if xr_interface.is_passthrough_supported():
        return xr_interface.start_passthrough()
    var modes = xr_interface.get_supported_environment_blend_modes()
    if xr_interface.XR_ENV_BLEND_MODE_ALPHA_BLEND in modes:
        xr_interface.set_environment_blend_mode(xr_interface.XR_ENV_BLEND_MODE_ALPHA_BLEND)
        return true
    return false


func _ready() -> void:
    add_to_group("outcome_listener")

    xr_interface = XRServer.primary_interface
    if xr_interface and xr_interface.is_initialized():
        print("OpenXR initialised successfully")
        DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
        get_viewport().use_xr = true
        enable_passthrough()
    else:
        print("OpenXR not initialised — xr_interface exists: ", xr_interface != null)
        if xr_interface:
            print("  is_initialized: ", xr_interface.is_initialized())
            print("  capabilities: ", xr_interface.get_capabilities())
        print("Check headset connection / OpenXR runtime")

    # Wait one frame so parent Boid_Manager _ready() has run first
    await get_tree().process_frame
    _setup_boids()


func _setup_boids() -> void:
    var boids := Boid_Manager.boid_manager_instance
    if boids == null:
        print("AlienDiplomacy: Boid_Manager not ready")
        return

    # Clear the camera override — we deleted Camera3D, this prevents _process errors
    boids.Override_Camera = null

    # Set boid fly targets to the NamNam markers
    var friend_target := boids.get_node_or_null("Friend_NamNam")
    var enemy_target  := boids.get_node_or_null("Enemy_NamNam")
    if friend_target:
        boids.friendly_boid_target_node = friend_target
        print("Friendly target: Friend_NamNam")
    else:
        print("WARNING: Friend_NamNam not found on boid manager")
    if enemy_target:
        boids.enemy_boid_target_node = enemy_target
        print("Enemy target: Enemy_NamNam")
    else:
        print("WARNING: Enemy_NamNam not found on boid manager")


func receive_outcome(outcome: String) -> void:
    var boids := Boid_Manager.boid_manager_instance
    if boids == null:
        print("receive_outcome: no Boid_Manager instance found")
        return
    match outcome:
        "peace":
            print("Outcome PEACE — stopping invasion")
            boids.Decrease_Enemy_Pool_Size(1.0)
        "war":
            print("Outcome WAR — escalating invasion")
            boids.Increase_Enemy_Pool_Size(1.0)
