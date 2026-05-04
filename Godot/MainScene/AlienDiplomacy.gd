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

    # Start with a small friendly force so peace outcomes can visibly grow it
    boids.Friendly_MultiMesh.multimesh.visible_instance_count = int(0.2 * boids.max_friendly_count)
    print("Friendly visible start: ", boids.Friendly_MultiMesh.multimesh.visible_instance_count)


func receive_outcome(outcome: String) -> void:
    var boids := Boid_Manager.boid_manager_instance
    if boids == null:
        print("receive_outcome: no Boid_Manager instance found")
        return

    var step := 0.15

    match outcome:
        "peace":
            print("Outcome PEACE — reducing invasion, reinforcing friendlies")
            boids.Decrease_Enemy_Pool_Size(step)
            # Grow visible friendly count by 15% of the total friendly cap
            var new_vis := mini(
                boids.Friendly_MultiMesh.multimesh.visible_instance_count + int(step * boids.max_friendly_count),
                boids.max_friendly_count
            )
            boids.Friendly_MultiMesh.multimesh.visible_instance_count = new_vis
            boids.keep_spawning_f = true  # refill any dead friendly slots
            print("Enemy pool: ", boids.Enemy_Pool_Amount, "  Friendly visible: ", new_vis)

        "war":
            print("Outcome WAR — escalating invasion, thinning friendlies")
            boids.Increase_Enemy_Pool_Size(step)
            # Shrink visible friendly count by 15% of the total friendly cap
            var new_vis := maxi(
                boids.Friendly_MultiMesh.multimesh.visible_instance_count - int(step * boids.max_friendly_count),
                0
            )
            boids.Friendly_MultiMesh.multimesh.visible_instance_count = new_vis
            print("Enemy pool: ", boids.Enemy_Pool_Amount, "  Friendly visible: ", new_vis)
