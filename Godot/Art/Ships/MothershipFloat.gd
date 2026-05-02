extends Node3D
class_name MothershipFloat

enum FloatMode {
    FRIENDLY_PLANET_STANDOFF = 0,
    ENEMY_SOLAR_SHELL = 1,
}

@export var mode : int = FloatMode.FRIENDLY_PLANET_STANDOFF
@export var movement_speed : float = 0.3
@export var rotation_slerp_speed : float = 0.1
@export var arrive_distance : float = 0.25
@export var repick_seconds : float = 20.0
@export var enemy_shell_thickness : float = 3.0
@export var friendly_planet_safety_multiplier : float = 1.2

@export var DEBUG_Marker_Mesh : MeshInstance3D = null
@export var Solar_System_Root : Node3D = null


@export_group("Steering")
@export var steering_mass : float = 2.0
@export var steering_max_force : float = 1.2
@export var steering_seek_weight : float = 1.0
@export var steering_avoidance_weight : float = 2.2
@export var steering_damping : float = 0.2
@export var avoidance_look_ahead : float = 6.0
@export var avoidance_radius_multiplier : float = 2.0
@export var avoidance_emergency_weight : float = 3.0

var planets : Array[MeshInstance3D] = []
var target_point : Vector3 = Vector3.ZERO
var repick_timer : float = 0.0
var velocity : Vector3 = Vector3.ZERO


func _ready() -> void:
    if Solar_System_Root == null:
        Solar_System_Root = %OffbrandSolarSystem
    if Solar_System_Root == null:
        printerr("Hey i have no idea how but OffBrandSolarSystem is gone?")
        return
        
    _cache_planets()
    _pick_new_target()


func _process(delta: float) -> void:
    if planets.is_empty():
        _cache_planets()

    repick_timer -= delta
        
    if global_position.distance_to(target_point) <= arrive_distance or repick_timer <= 0.0:
        _pick_new_target()

    _apply_steering(delta)
    _face_target_with_x_axis(delta)


func _face_target_with_x_axis(delta: float) -> void:
    var facing_dir : Vector3 = velocity.normalized()
    if facing_dir.length_squared() < 0.000001:
        facing_dir = (target_point - global_position).normalized()
    if facing_dir.length_squared() < 0.000001:
        return

    var x_axis : Vector3 = facing_dir
    var up_hint : Vector3 = Vector3.UP
    var z_axis : Vector3 = x_axis.cross(up_hint)
    if z_axis.length_squared() < 0.000001:
        up_hint = Vector3.FORWARD
        z_axis = x_axis.cross(up_hint)
        if z_axis.length_squared() < 0.000001:
            return
    z_axis = z_axis.normalized()
    var y_axis : Vector3 = z_axis.cross(x_axis).normalized()

    var target_basis : Basis = Basis(x_axis, y_axis, z_axis).orthonormalized()
    var current_q : Quaternion = global_basis.orthonormalized().get_rotation_quaternion()
    var target_q : Quaternion = target_basis.get_rotation_quaternion()
    var slerp_weight : float = clamp(rotation_slerp_speed * delta, 0.0, 1.0)
    var blended_q : Quaternion = current_q.slerp(target_q, slerp_weight).normalized()
    global_basis = Basis(blended_q).orthonormalized()


func _apply_steering(delta: float) -> void:
    
    var seek_force : Vector3 = _calculate_seek_force()
    var avoid_force : Vector3 = _calculate_avoidance_force()
    var steering_force : Vector3 = (seek_force * steering_seek_weight) + (avoid_force * steering_avoidance_weight)
    
    if steering_force.length() > steering_max_force:
        steering_force = steering_force.limit_length(steering_max_force)

    var acceleration : Vector3 = steering_force / max(steering_mass, 0.001)
    velocity += acceleration * delta
    if velocity.length() > movement_speed:
        velocity = velocity.limit_length(movement_speed)

    velocity -= velocity * min(1.0, steering_damping * delta)
    global_position += velocity * delta


func _calculate_seek_force() -> Vector3:
    var to_target : Vector3 = target_point - global_position
    var dist_to_target : float = to_target.length()
    if dist_to_target < 0.000001:
        return -velocity

    var desired_speed : float = movement_speed
    if dist_to_target < arrive_distance * 4.0:
        desired_speed = movement_speed * (dist_to_target / max(arrive_distance * 4.0, 0.001))
    var desired_velocity : Vector3 = (to_target / dist_to_target) * desired_speed
    return desired_velocity - velocity


func _calculate_avoidance_force() -> Vector3:
    var force : Vector3 = Vector3.ZERO
    if planets.is_empty():
        return force

    var forward : Vector3 = velocity.normalized()
    if forward.length_squared() < 0.000001:
        forward = (target_point - global_position).normalized()
    if forward.length_squared() < 0.000001:
        forward = global_basis.x.normalized()
    if forward.length_squared() < 0.000001:
        forward = Vector3.RIGHT

    for i in range(planets.size()):
        var obstacle : MeshInstance3D = planets[i]
        var obstacle_center : Vector3 = obstacle.global_position
        var obstacle_radius : float = _get_planet_radius(obstacle) * avoidance_radius_multiplier

        var to_obstacle : Vector3 = obstacle_center - global_position
        var forward_dist : float = to_obstacle.dot(forward)
        if forward_dist < 0.0:
            continue

        var clamped_forward_dist : float = min(forward_dist, avoidance_look_ahead)
        var projected : Vector3 = global_position + (forward * clamped_forward_dist)
        var from_center_to_projected : Vector3 = projected - obstacle_center
        var lateral_dist : float = from_center_to_projected.length()

        if lateral_dist < obstacle_radius and forward_dist <= avoidance_look_ahead:
            var away : Vector3 = from_center_to_projected.normalized()
            if away.length_squared() < 0.000001:
                away = (global_position - obstacle_center).normalized()
            if away.length_squared() < 0.000001:
                away = -forward

            var lateral_strength : float = 1.0 - (lateral_dist / max(obstacle_radius, 0.001))
            var forward_strength : float = 1.0 - (forward_dist / max(avoidance_look_ahead, 0.001))
            var strength : float = max(lateral_strength, forward_strength)
            force += away * (movement_speed * strength)

        var direct_dist : float = global_position.distance_to(obstacle_center)
        if direct_dist < obstacle_radius:
            var emergency_away : Vector3 = (global_position - obstacle_center).normalized()
            if emergency_away.length_squared() < 0.000001:
                emergency_away = -forward
            force += emergency_away * (movement_speed * avoidance_emergency_weight)

    return force


func _cache_planets() -> void:
    planets.clear()
    if Solar_System_Root == null:
        return

    for child in Solar_System_Root.get_children():
        if child is MeshInstance3D:
            planets.push_back(child as MeshInstance3D)


func _pick_new_target() -> void:
    if mode == FloatMode.ENEMY_SOLAR_SHELL:
        target_point = _pick_enemy_shell_point()
    else:
        target_point = _pick_friendly_planet_standoff_point()
    _update_debug_target_node_position()
    repick_timer = repick_seconds



func _update_debug_target_node_position() -> void:
    if DEBUG_Marker_Mesh == null:
        return
    DEBUG_Marker_Mesh.global_position = target_point


func _pick_friendly_planet_standoff_point() -> Vector3:
    if planets.is_empty():
        return global_position

    var random_index : int = randi_range(0, planets.size() - 1)
    var planet : MeshInstance3D = planets[random_index]
    var planet_radius : float = _get_planet_radius(planet)
    var safe_radius : float = planet_radius * friendly_planet_safety_multiplier

    var to_planet : Vector3 = planet.global_position - global_position
    var distance_to_planet : float = to_planet.length()
    if distance_to_planet < 0.00001:
        var random_dir : Vector3 = _random_unit_vector()
        return planet.global_position - (random_dir * safe_radius)

    # Example: ship 10 away, radius 1 => safe radius 1.2 => move to 8.8 away along the planet direction.
    var direction_to_planet : Vector3 = to_planet / distance_to_planet
    return planet.global_position - (direction_to_planet * safe_radius)


func _pick_enemy_shell_point() -> Vector3:
    if Solar_System_Root == null:
        return global_position + (_random_unit_vector() * 3.0)

    var center : Vector3 = Solar_System_Root.global_position
    var system_outer_radius : float = _get_system_outer_radius()
    var max_shell_distance : float = system_outer_radius + enemy_shell_thickness

    for _attempt in range(64):
        var dir : Vector3 = _random_unit_vector()
        var ring_distance : float = randf_range(system_outer_radius + 0.1, max_shell_distance)
        var candidate : Vector3 = center + (dir * ring_distance)
        if _is_point_outside_all_planets(candidate, friendly_planet_safety_multiplier):
            return candidate

    return center + (_random_unit_vector() * max_shell_distance)


func _is_point_outside_all_planets(point: Vector3, clearance_multiplier: float) -> bool:
    for i in range(planets.size()):
        var planet : MeshInstance3D = planets[i]
        var min_dist : float = _get_planet_radius(planet) * clearance_multiplier
        if point.distance_to(planet.global_position) < min_dist:
            return false
    return true


func _get_system_outer_radius() -> float:
    var max_radius : float = 1.0
    if Solar_System_Root == null:
        return max_radius

    for i in range(planets.size()):
        var planet : MeshInstance3D = planets[i]
        var planet_radius : float = _get_planet_radius(planet)
        var dist_from_center : float = planet.global_position.distance_to(Solar_System_Root.global_position)
        var candidate_radius : float = dist_from_center + planet_radius
        if candidate_radius > max_radius:
            max_radius = candidate_radius

    return max_radius


func _get_planet_radius(planet: MeshInstance3D) -> float:
    if planet.mesh == null:
        return 1.0

    if planet.mesh is SphereMesh:
        var sphere_mesh : SphereMesh = planet.mesh as SphereMesh
        var max_scale : float = max(planet.scale.x, max(planet.scale.y, planet.scale.z))
        return max(0.05, sphere_mesh.radius * max_scale)

    var aabb : AABB = planet.mesh.get_aabb()
    var max_extent : float = max(aabb.size.x, max(aabb.size.y, aabb.size.z))
    var fallback_scale : float = max(planet.scale.x, max(planet.scale.y, planet.scale.z))
    return max(0.05, (max_extent * 0.5) * fallback_scale)


func _random_unit_vector() -> Vector3:
    var dir : Vector3 = Vector3(
        randf_range(-1.0, 1.0),
        randf_range(-1.0, 1.0),
        randf_range(-1.0, 1.0)
    )
    if dir.length_squared() < 0.0001:
        dir = Vector3.FORWARD
    return dir.normalized()
