extends Node
class_name Viewport2DIn3DHandTouch

## Adds physical hand/finger interaction to `XRToolsViewport2DIn3D`.
## Converts finger overlap into viewport clicks and optional gesture scrolling.

@export_flags_3d_physics var hand_collision_mask: int = 1

## Minimum time between accepted clicks per finger collider.
@export var click_cooldown_seconds: float = 0.25

## When enabled: long-press (0.4s) sends double-click (e.g. FileDialog folders). When disabled: only single clicks.
@export var enable_double: bool = false
@export var double_click_hold_seconds: float = 0.4

## Scroll-by-pose: index pinch or fist plus hand movement scrolls viewport content.
@export var scroll_enabled: bool = true
@export var scroll_pose_index_pinch: bool = true
@export var scroll_pose_fist: bool = true
## Pixels of hand movement per 1 unit of scroll (tune for feel)
@export var scroll_sensitivity: float = 0.5

var _viewport: SubViewport
var _screen_body: Node  # StaticBody3D with viewport_2d_in_3d_body.gd (has global_to_viewport)
var _touch_area: Area3D
var _cooldown_by_area: Dictionary = {}  # area -> cooldown end time

## Double-click state used when long-press is enabled.
var _pending_tap_area: Area3D = null
var _pending_tap_pos: Vector2 = Vector2.ZERO
var _long_press_fired: bool = false

## Active scroll gesture state.
var _scroll_active: bool = false
var _scroll_finger: Player_Finger = null
var _scroll_hand_right: bool = false
var _scroll_last_viewport_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
    var parent = get_parent()
    if not parent is XRToolsViewport2DIn3D:
        push_error("Viewport2DIn3DHandTouch gotta have a XRToolsViewport2DIn3D daddy... failure")
        set_process(false)
        return

    var viewport_2d_to_3d: XRToolsViewport2DIn3D = parent
    _viewport = viewport_2d_to_3d.get_node_or_null("Viewport") as SubViewport
    _screen_body = viewport_2d_to_3d.get_node_or_null("StaticBody3D")
    if not _viewport or not _screen_body:
        push_error("Viewport2DIn3DHandTouch couldn't find Viewport or StaticBody3D... failure.")
        set_process(false)
        return

    # ctrl shift a check
    if not _screen_body.has_method("global_to_viewport"):
        push_error("Viewport2DIn3DHandTouch found a StaticBody3D but it has no global_to_viewport... use CTRL+SHIFT+A because godot xr init is weird")
        set_process(false)
        return

    _setup_touch_area(viewport_2d_to_3d)


func _setup_touch_area(viewport_2d_to_3d: XRToolsViewport2DIn3D) -> void:
    _touch_area = Area3D.new()
    _touch_area.name = "HandTouchArea"
    _touch_area.collision_layer = 0
    _touch_area.collision_mask = hand_collision_mask
    _touch_area.monitorable = false
    _touch_area.monitoring = true

    var shape : BoxShape3D = BoxShape3D.new()
    var screen_size : Vector2 = viewport_2d_to_3d.screen_size
    shape.size = Vector3(screen_size.x, screen_size.y, 0.02)

    var col : CollisionShape3D = CollisionShape3D.new()
    col.name = "CollisionShape3D"
    
    # thanks GPT
    col.transform = Transform3D(
        Vector3(1.0, 0.0, 0.0), 
        Vector3(0.0, 1.0, 0.0), 
        Vector3(0.0, 0.0, 1.0), 
        Vector3(0.0, 0.0, -0.01))
        
    col.shape = shape

    # must call_defered other godot will fail saying it's too bsuy to add children
    _touch_area.add_child.call_deferred(col)
    viewport_2d_to_3d.add_child.call_deferred(_touch_area)

    _touch_area.area_entered.connect(_on_touch_area_entered)
    _touch_area.area_exited.connect(_on_touch_area_exited)

    if scroll_enabled:
        set_process(true)


func _process(delta: float) -> void:
    if not scroll_enabled or not _touch_area or not _screen_body.has_method("global_to_viewport"):
        return
    var parent = get_parent()
    if not parent is XRToolsViewport2DIn3D or not parent.enabled:
        return

    var overlapping: Array[Area3D] = _touch_area.get_overlapping_areas()
    var scroll_pose_fingers: Array[Player_Finger] = []
    for area in overlapping:
        if area is Player_Finger:
            var finger: Player_Finger = area as Player_Finger
            if _is_scroll_pose(finger):
                scroll_pose_fingers.append(finger)

    # Start scroll: pinch/fist while in area
    if scroll_pose_fingers.size() > 0 and not _scroll_active:
        var finger := _pick_scroll_finger(scroll_pose_fingers)
        if finger:
            _scroll_active = true
            _scroll_finger = finger
            _scroll_hand_right = finger.is_right_hand
            _scroll_last_viewport_pos = _clamp_to_viewport(_screen_body.global_to_viewport(finger.global_position))

    # Update scroll: apply delta and keep tracking
    if _scroll_active:
        if not is_instance_valid(_scroll_finger) or _scroll_finger.get_parent() == null:
            _end_scroll()
        elif not _scroll_finger in overlapping or not _is_scroll_pose_for_hand(_scroll_hand_right):
            _end_scroll()
        else:
            var current_pos := _clamp_to_viewport(_screen_body.global_to_viewport(_scroll_finger.global_position))
            var delta_y: float = _scroll_last_viewport_pos.y - current_pos.y
            _scroll_last_viewport_pos = current_pos
            if absf(delta_y) > 0.5:
                _push_scroll(delta_y * scroll_sensitivity)
    else:
        _scroll_finger = null


func _is_scroll_pose(finger: Player_Finger) -> bool:
    var pose: Player_Finger.E_POSES = Player_Finger.CURRENT_RIGHT_HAND_POSE if finger.is_right_hand else Player_Finger.CURRENT_LEFT_HAND_POSE
    if scroll_pose_index_pinch and pose == Player_Finger.E_POSES.INDEX_THUMB_PINCH:
        return true
    if scroll_pose_fist and pose == Player_Finger.E_POSES.FIST:
        return true
    return false


func _is_scroll_pose_for_hand(is_right: bool) -> bool:
    var pose: Player_Finger.E_POSES = Player_Finger.CURRENT_RIGHT_HAND_POSE if is_right else Player_Finger.CURRENT_LEFT_HAND_POSE
    if scroll_pose_index_pinch and pose == Player_Finger.E_POSES.INDEX_THUMB_PINCH:
        return true
    if scroll_pose_fist and pose == Player_Finger.E_POSES.FIST:
        return true
    return false


func _pick_scroll_finger(fingers: Array[Player_Finger]) -> Player_Finger:
    for f in fingers:
        if f.Which_Finger == Player_Finger.E_FINGER.SECOND:
            return f
    return fingers[0] if fingers.size() > 0 else null


func _clamp_to_viewport(pos: Vector2) -> Vector2:
    if not _viewport:
        return pos
    var vs: Vector2 = _viewport.size
    return Vector2(clampf(pos.x, 0, vs.x), clampf(pos.y, 0, vs.y))


func _end_scroll() -> void:
    _scroll_active = false
    _scroll_finger = null


func _push_scroll(delta_y: float) -> void:
    if not is_instance_valid(_viewport):
        return
    # Positive delta_y = hand moved up = scroll content down (like dragging menu up)
    var ev := InputEventMouseButton.new()
    ev.position = _scroll_last_viewport_pos
    ev.global_position = _scroll_last_viewport_pos
    ev.button_index = MOUSE_BUTTON_WHEEL_DOWN if delta_y > 0 else MOUSE_BUTTON_WHEEL_UP
    ev.pressed = true
    ev.factor = clampf(absf(delta_y) / 10.0, 0.001, 2.0)
    _viewport.push_input(ev)
    ev.pressed = false
    _viewport.push_input(ev)


func _on_touch_area_entered(area: Area3D) -> void:
    if not area is Player_Finger:
        return
    if not is_instance_valid(_viewport) or not _screen_body.has_method("global_to_viewport"):
        return
    var finger: Player_Finger = area as Player_Finger
    # Don't trigger click when user is in scroll pose (pinch/fist)
    if scroll_enabled and _is_scroll_pose(finger):
        return

    var now: float = Time.get_ticks_msec() / 1000.0
    if _cooldown_by_area.get(area, 0.0) > now:
        return

    if enable_double:
        # Long-press mode: wait for exit or timer; quick tap = single, hold = double
        if _pending_tap_area != null:
            return
        _pending_tap_area = area
        _pending_tap_pos = _clamp_to_viewport(_screen_body.global_to_viewport(area.global_position))
        _long_press_fired = false
        get_tree().create_timer(double_click_hold_seconds).timeout.connect(_on_long_press_timeout)
    else:
        # Single-click only: fire immediately
        _cooldown_by_area[area] = now + click_cooldown_seconds
        var at_2d: Vector2 = _clamp_to_viewport(_screen_body.global_to_viewport(area.global_position))
        var parent = get_parent()
        if parent is XRToolsViewport2DIn3D and parent.enabled:
            _push_click_pair(at_2d, false)


func _on_long_press_timeout() -> void:
    if not is_instance_valid(_viewport) or not get_parent().enabled:
        _pending_tap_area = null
        return
    if is_instance_valid(_pending_tap_area) and _pending_tap_area in _touch_area.get_overlapping_areas():
        _push_click_pair(_pending_tap_pos, true)
        _cooldown_by_area[_pending_tap_area] = Time.get_ticks_msec() / 1000.0 + click_cooldown_seconds
        _long_press_fired = true
    _pending_tap_area = null


func _on_touch_area_exited(area: Area3D) -> void:
    if area != _pending_tap_area:
        return
    if enable_double:
        if not _long_press_fired and is_instance_valid(_viewport) and get_parent().enabled:
            _push_click_pair(_pending_tap_pos, false)
            _cooldown_by_area[area] = Time.get_ticks_msec() / 1000.0 + click_cooldown_seconds
    _pending_tap_area = null
    _long_press_fired = false


func _push_click_pair(at: Vector2, is_double_click: bool) -> void:
    if not is_instance_valid(_viewport):
        return
    var down := InputEventMouseButton.new()
    down.button_index = MOUSE_BUTTON_LEFT
    down.pressed = true
    down.position = at
    down.global_position = at
    down.button_mask = MOUSE_BUTTON_MASK_LEFT
    down.double_click = is_double_click
    _viewport.push_input(down)

    var up := InputEventMouseButton.new()
    up.button_index = MOUSE_BUTTON_LEFT
    up.pressed = false
    up.position = at
    up.global_position = at
    up.button_mask = 0
    up.double_click = is_double_click
    if get_parent().enabled:
        _viewport.push_input(up)
