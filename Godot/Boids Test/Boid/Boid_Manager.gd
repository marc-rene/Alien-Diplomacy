extends Node3D
class_name Boid_Manager

# whats the absoilute maximum number of boids we can have??
@export_range(2, 260000, 1, "prefer_slider") var Max_Num_Boids : int = 100

# How do we want to divide up our friendlies? (Assuming we want 100 boids max)
#   0.5 == Equal num of Friends V Enemy (50 v 50)
#   0.1 == Small num of Friends V CRAP LOADS of Enemy (10 v 90)
@export_range(0, 1, 0.01, "prefer_slider") var Friendly_Enemy_Count_Ratio : float = 0.5

# How much ammo can a ship hold?
@export_range(1, 200, 1) var Max_Ammo_Capacity : int = 50
@export var ship_max_health : int = 127

@export_group("Friendlys")
# Where will friendlys spawn?
@export var Friendly_Spawn_Point : Node3D
@export var Friendly_Mesh : MeshInstance3D
@export var Friendly_MultiMesh : MultiMeshInstance3D
var max_friendly_count : int = 0

@export_group("Enemies")
# Where will enemies spawn?
@export var Enemy_Spawn_Point : Node3D
@export var Enemy_Mesh : MeshInstance3D
@export var Enemy_MultiMesh : MultiMeshInstance3D

@export_group("Steering")
@export var max_speed : float = 2.0
@export var max_force : float = 10.0
@export var banking : float = 0.05
@export var mass : float = 2.0
@export var seek_weight : float = 1.0
@export var dont_crash_weight : float = 2.0
@export var return_weight : float = 1.5
@export var near_crash_multiplier : float = 8.0
@export var avoid_radius_multiplier : float = 2.0
@export var avoid_padding : float = 0.3
@export var arrive_slowing_distance : float = 4.0
@export var reload_distance : float = 0.5
@export var reload_time_required : float = 10.0
@export var target_recheck_seconds : float = 5.0

@export_group("Combat")
@export var fire_rate_seconds : float = 0.1 # 1 bullet every 100ms
@export var bullet_speed : float = 3.0
@export var bullet_lifetime : float = 2.0
@export_range(0, 500000, 1) var bullet_pool_size : int = 0 # 0 = auto-size based on fire-rate/lifetime
@export var bullet_ship_hit_radius : float = 0.8
@export var bullet_damage_to_ships : int = 4
@export var bullet_damage_to_planets : int = 1
@export var canons_node_name : String = "Ships Canons Particles"

@export_group("VFX")
@export var planet_hit_pulse_duration : float = 0.25
@export var planet_hit_pulse_energy : float = 1.1
@export var reload_pulse_interval : float = 0.2
@export var reload_pulse_duration : float = 0.18
@export var reload_pulse_radius : float = 0.18
@export var bolt_visual_radius : float = 0.06

var temp_friend_mesh_push_buffer : PackedFloat32Array
var temp_enemy_mesh_push_buffer : PackedFloat32Array
var prev_friend_mesh_push_buffer : PackedFloat32Array
var prev_enemy_mesh_push_buffer : PackedFloat32Array

@export_category("Performance HELL")
@export var offbrand_physics_DLSS : bool = true # Do we want to use one buffer? (Smooth) or swap between 2 buffers? (Great performacne, annoying jitter at low fps)
@export var starting_physics_tick : int = 15
@export var try_hit_60 : bool = false
@export var Override_Camera : Camera3D
var use_prev_buffer : bool = true

static var boid_manager_instance : Boid_Manager

static func Is_Using_Offbrand_Physics_DLSS() -> bool: 
    return boid_manager_instance.offbrand_physics_DLSS

static func How_Many_Boids() -> int:
	return boid_manager_instance.Max_Num_Boids

static func How_Many_Boids_Active() -> int:
	return boid_manager_instance.eeees + boid_manager_instance.french

# SO here's the naming convention
# Entities will end in _ent
# componenets (like velocity, etc...) end with _comp

# signed health representation:
#   < 0 enemy
#   0 dead
#   > 0 friendly
var ALL_ENTITIES_ent : PackedInt32Array

var OFFSETS_comp : PackedByteArray

# Ammo can go negative while searching for ammo dock
var ALL_ENTITY_AMMOS_comp : PackedInt32Array
var ALL_ENTITY_HEALTH_comp : PackedInt32Array
var ALL_ENTITY_TARGET_INDEX_comp : PackedInt32Array
var ALL_ENTITY_TARGET_KIND_comp : PackedByteArray # 0=ship, 1=planet
var ALL_ENTITY_TARGET_RECHECK_TIMER_comp : PackedFloat32Array
var ALL_ENTITY_FIRE_COOLDOWN_comp : PackedFloat32Array
var ALL_ENTITY_RELOAD_TIMER_comp : PackedFloat32Array
var ALL_ENTITY_RELOAD_PULSE_TIMER_comp : PackedFloat32Array

# Global Velocities of all entities
var VELOCITIES_comp : PackedVector3Array

# Scene refs
var Planet_Targets : Array[MeshInstance3D] = []
var Planet_Radius_comp : PackedFloat32Array
var Planet_Pulse_Timer_comp : PackedFloat32Array
var Planet_Pulse_Overlay_comp : Array[StandardMaterial3D] = []

var Friendly_MotherShip : Node3D
var Enemy_MotherShip : Node3D

# Bullets
var BULLET_POSITIONS_comp : Array[Vector3] = []
var BULLET_VELOCITIES_comp : Array[Vector3] = []
var BULLET_LIFETIMES_comp : Array[float] = []
var BULLET_OWNERS_comp : Array[int] = []
var BULLET_TARGET_comp : Array[int] = []
var BULLET_TARGET_KIND_comp : Array[int] = [] # 0=ship,1=planet
var BULLET_ACTIVE_COUNT : int = 0
var BULLET_CAPACITY : int = 0

var Bolt_Visuals : MultiMeshInstance3D
var Reload_Pulse_Visuals : MultiMeshInstance3D

var RELOAD_PULSE_POSITIONS_comp : Array[Vector3] = []
var RELOAD_PULSE_LIFETIMES_comp : Array[float] = []


func Refresh_Entities():
    inited = false
    ALL_ENTITIES_ent.resize(Max_Num_Boids)
	ALL_ENTITIES_ent.fill(0) # You're all deactivated!

	VELOCITIES_comp.resize(Max_Num_Boids)
	VELOCITIES_comp.fill(Vector3.ZERO)

	ALL_ENTITY_AMMOS_comp.resize(Max_Num_Boids)
	ALL_ENTITY_AMMOS_comp.fill(Max_Ammo_Capacity)

	ALL_ENTITY_HEALTH_comp.resize(Max_Num_Boids)
	ALL_ENTITY_HEALTH_comp.fill(ship_max_health)

	ALL_ENTITY_TARGET_INDEX_comp.resize(Max_Num_Boids)
	ALL_ENTITY_TARGET_INDEX_comp.fill(-1)

	ALL_ENTITY_TARGET_KIND_comp.resize(Max_Num_Boids)
	ALL_ENTITY_TARGET_KIND_comp.fill(0)

	ALL_ENTITY_TARGET_RECHECK_TIMER_comp.resize(Max_Num_Boids)
	ALL_ENTITY_FIRE_COOLDOWN_comp.resize(Max_Num_Boids)
	ALL_ENTITY_RELOAD_TIMER_comp.resize(Max_Num_Boids)
	ALL_ENTITY_RELOAD_PULSE_TIMER_comp.resize(Max_Num_Boids)
	for i in range(Max_Num_Boids):
		ALL_ENTITY_TARGET_RECHECK_TIMER_comp[i] = randf_range(0.0, target_recheck_seconds)
		ALL_ENTITY_FIRE_COOLDOWN_comp[i] = randf_range(0.0, fire_rate_seconds)
		ALL_ENTITY_RELOAD_TIMER_comp[i] = 0.0
		ALL_ENTITY_RELOAD_PULSE_TIMER_comp[i] = 0.0

	OFFSETS_comp.resize(Max_Num_Boids)
	for i in range(Max_Num_Boids):
		OFFSETS_comp.encode_s8(i, randi_range(-100, 100))
		if OFFSETS_comp[i] == 0:
			OFFSETS_comp[i] += 1

	max_friendly_count = int(Friendly_Enemy_Count_Ratio * Max_Num_Boids)

    temp_friend_mesh_push_buffer.resize(max_friendly_count * 12)
    prev_friend_mesh_push_buffer.resize(max_friendly_count * 12)
    temp_enemy_mesh_push_buffer.resize((Max_Num_Boids - max_friendly_count) * 12)
    prev_enemy_mesh_push_buffer.resize((Max_Num_Boids - max_friendly_count) * 12)
    _configure_bullet_pool()

	print("Max num of boids: %d\n\tFriendly boids: %d\n\tEnemy boids: %d" % [ALL_ENTITIES_ent.size(), max_friendly_count, Max_Num_Boids - max_friendly_count])

	Friendly_MultiMesh.multimesh.mesh = Friendly_Mesh.mesh
	Enemy_MultiMesh.multimesh.mesh = Enemy_Mesh.mesh
	Friendly_MultiMesh.multimesh.instance_count = max_friendly_count
	Enemy_MultiMesh.multimesh.instance_count = Max_Num_Boids - max_friendly_count
	Friendly_MultiMesh.multimesh.visible_instance_count = max_friendly_count
	Enemy_MultiMesh.multimesh.visible_instance_count = Max_Num_Boids - max_friendly_count

	keep_spawning_f = true
	keep_spawning_e = true
	inited = true


var inited : bool = false
func _ready():
	if Friendly_Spawn_Point == null or Friendly_Mesh == null or Friendly_MultiMesh == null or Enemy_Spawn_Point == null or Enemy_Mesh == null or Enemy_MultiMesh == null:
		printerr("Yo aint said what yo homies or estonies is!!!")
		set_physics_process(false)
		return

	boid_manager_instance = self
	Engine.physics_ticks_per_second = starting_physics_tick

	ALL_ENTITIES_ent = PackedInt32Array()
	VELOCITIES_comp = PackedVector3Array()
	OFFSETS_comp = PackedByteArray()
	ALL_ENTITY_AMMOS_comp = PackedInt32Array()
	ALL_ENTITY_HEALTH_comp = PackedInt32Array()
	ALL_ENTITY_TARGET_INDEX_comp = PackedInt32Array()
	ALL_ENTITY_TARGET_KIND_comp = PackedByteArray()
	ALL_ENTITY_TARGET_RECHECK_TIMER_comp = PackedFloat32Array()
	ALL_ENTITY_FIRE_COOLDOWN_comp = PackedFloat32Array()
	ALL_ENTITY_RELOAD_TIMER_comp = PackedFloat32Array()
	ALL_ENTITY_RELOAD_PULSE_TIMER_comp = PackedFloat32Array()
	Planet_Radius_comp = PackedFloat32Array()
	Planet_Pulse_Timer_comp = PackedFloat32Array()

    Refresh_Entities()
    _resolve_scene_refs()
    _setup_bolt_visuals()
    _configure_bullet_pool()
    _setup_reload_visuals()


func _resolve_scene_refs() -> void:
	var root : Node = get_parent()
	if root == null:
		return

	Planet_Targets.clear()
	Planet_Pulse_Overlay_comp.clear()

	if root.has_node("OffbrandSolarSystem"):
		var solar = root.get_node("OffbrandSolarSystem")
		for child in solar.get_children():
			if child is MeshInstance3D:
				Planet_Targets.push_back(child)

	Friendly_MotherShip = root.get_node_or_null("Friendly MotherShip - UNSC")
	Enemy_MotherShip = root.get_node_or_null("Enemy MotherShip - UNSC2")

	Planet_Radius_comp.resize(Planet_Targets.size())
	Planet_Pulse_Timer_comp.resize(Planet_Targets.size())
	for i in range(Planet_Targets.size()):
		Planet_Pulse_Timer_comp[i] = 0.0
		Planet_Radius_comp[i] = _get_planet_radius(Planet_Targets[i])
		var overlay : StandardMaterial3D = StandardMaterial3D.new()
		overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		overlay.albedo_color = Color(1.0, 0.0, 0.0, 0.15)
		overlay.emission_enabled = true
		overlay.emission = Color(1.0, 0.0, 0.0)
		overlay.emission_energy_multiplier = 0.0
		Planet_Targets[i].material_overlay = overlay
		Planet_Pulse_Overlay_comp.push_back(overlay)


func _setup_bolt_visuals() -> void:
    Bolt_Visuals = MultiMeshInstance3D.new()
    Bolt_Visuals.name = "Runtime_Bolt_Visuals"
    var bolt_mm : MultiMesh = MultiMesh.new()
    bolt_mm.transform_format = MultiMesh.TRANSFORM_3D
    bolt_mm.instance_count = 0
    bolt_mm.visible_instance_count = 0
    Bolt_Visuals.multimesh = bolt_mm

	var bolt_mesh : SphereMesh = SphereMesh.new()
	bolt_mesh.radius = bolt_visual_radius
	bolt_mesh.height = bolt_visual_radius * 2.0
	bolt_mesh.radial_segments = 6
	bolt_mesh.rings = 4

	var bolt_mat : StandardMaterial3D = StandardMaterial3D.new()
	bolt_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bolt_mat.emission_enabled = true
	bolt_mat.emission = Color(1.0, 0.75, 0.35)
	bolt_mat.emission_energy_multiplier = 1.2
	bolt_mat.albedo_color = Color(1.0, 0.75, 0.35)
	bolt_mesh.material = bolt_mat

	Bolt_Visuals.multimesh.mesh = bolt_mesh
	add_child(Bolt_Visuals)


func _configure_bullet_pool() -> void:
    var shots_per_ship_in_flight : int = int(ceil(bullet_lifetime / max(fire_rate_seconds, 0.001))) + 1
    var auto_capacity : int = max(1, Max_Num_Boids * max(1, shots_per_ship_in_flight))
    BULLET_CAPACITY = bullet_pool_size if bullet_pool_size > 0 else auto_capacity

    BULLET_POSITIONS_comp.resize(BULLET_CAPACITY)
    BULLET_VELOCITIES_comp.resize(BULLET_CAPACITY)
    BULLET_LIFETIMES_comp.resize(BULLET_CAPACITY)
    BULLET_OWNERS_comp.resize(BULLET_CAPACITY)
    BULLET_TARGET_KIND_comp.resize(BULLET_CAPACITY)
    BULLET_TARGET_comp.resize(BULLET_CAPACITY)

    for i in range(BULLET_CAPACITY):
        BULLET_POSITIONS_comp[i] = Vector3.ZERO
        BULLET_VELOCITIES_comp[i] = Vector3.ZERO
        BULLET_LIFETIMES_comp[i] = 0.0
        BULLET_OWNERS_comp[i] = -1
        BULLET_TARGET_KIND_comp[i] = 0
        BULLET_TARGET_comp[i] = -1

    BULLET_ACTIVE_COUNT = 0
    if Bolt_Visuals != null and Bolt_Visuals.multimesh != null:
        Bolt_Visuals.multimesh.instance_count = BULLET_CAPACITY
        Bolt_Visuals.multimesh.visible_instance_count = 0


func _setup_reload_visuals() -> void:
	Reload_Pulse_Visuals = MultiMeshInstance3D.new()
	Reload_Pulse_Visuals.name = "Runtime_Reload_Visuals"
	var reload_mm : MultiMesh = MultiMesh.new()
	reload_mm.transform_format = MultiMesh.TRANSFORM_3D
	reload_mm.instance_count = 0
	Reload_Pulse_Visuals.multimesh = reload_mm

	var reload_mesh : SphereMesh = SphereMesh.new()
	reload_mesh.radius = reload_pulse_radius
	reload_mesh.height = reload_pulse_radius * 2.0
	reload_mesh.radial_segments = 8
	reload_mesh.rings = 6

	var reload_mat : StandardMaterial3D = StandardMaterial3D.new()
	reload_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	reload_mat.emission_enabled = true
	reload_mat.emission = Color(0.35, 1.0, 0.35)
	reload_mat.emission_energy_multiplier = 1.0
	reload_mat.albedo_color = Color(0.35, 1.0, 0.35, 0.6)
	reload_mesh.material = reload_mat

	Reload_Pulse_Visuals.multimesh.mesh = reload_mesh
	add_child(Reload_Pulse_Visuals)


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


func is_alive(entity_index: int) -> bool:
	if entity_index < ALL_ENTITIES_ent.size():
		return ALL_ENTITIES_ent[entity_index] != 0
	printerr("OH CRAP! Our entities are too small, we gotta resize!")
	Refresh_Entities()
	return false


func is_friendly(entity_index: int) -> bool:
	return entity_index < max_friendly_count


func is_enemy(entity_index: int) -> bool:
	return entity_index >= max_friendly_count


func get_boid_transform(entity_index: int) -> Transform3D:
	if is_alive(entity_index) == false:
		return Transform3D.IDENTITY
	if is_friendly(entity_index):
		return Friendly_MultiMesh.multimesh.get_instance_transform(entity_index)
	return Enemy_MultiMesh.multimesh.get_instance_transform(entity_index - max_friendly_count)


var temp_buffer : PackedByteArray
func count_free_spots(friendly_spots : bool) -> int:
	temp_buffer.clear()
	if friendly_spots:
		temp_buffer.slice(0, max_friendly_count)
	else:
		temp_buffer.slice(max_friendly_count)
	return temp_buffer.count(0)


var frame_fence : int = 0
var keep_spawning_f : bool = true
var keep_spawning_e : bool = true
var cam_point : Transform3D

var french = 0
var eeees = 0

var frame_time_switches : int = 0
var update_physics_score : float = 1


func _process(delta: float) -> void:
	if not inited:
		return

	if keep_spawning_f:
		keep_spawning_f = spawn_friendly()
		french += 1
		if keep_spawning_f == false:
			print("STOPPED FRENCH")

	if keep_spawning_e:
		keep_spawning_e = spawn_enemy()
		eeees += 1
		if keep_spawning_e == false:
			print("STOPPED ESTONIA")

	cam_point = get_boid_transform(max_friendly_count)
	frame_fence += 1

	if Override_Camera != null:
		$Camera3D.global_position = cam_point.origin - cam_point.basis.z + cam_point.basis.y
		$Camera3D.look_at(cam_point.origin, Vector3.UP)
		$Camera3D/Label.text = "FPS: " + str(Engine.get_frames_per_second()) + "\nFriendly Boids: " + str(french - 1) + "\nEnemy Boids: " + str(eeees - 1) + "\nPhysics FPS: " + str(Engine.physics_ticks_per_second)
		$Camera3D/Label.text += "\nPhysics Update Tick score: " + str(update_physics_score) + "\nPhysics Frame Fence: " + str(physics_fence) + "/" + str(int(frames_before_change * update_physics_score)) + "\nPhysics fps next change: " + str(clamp(int(starting_physics_tick * update_physics_score), 1, starting_physics_tick))
		$Camera3D/Label.text += "\nAwful frame drops: " + str(frame_time_switches)
		$Camera3D/Label.text += "\nUsing Offbrand Physics DLSS?: " + str(offbrand_physics_DLSS)

	if try_hit_60:
		struggling_level = int(Engine.get_frames_per_second() / 10)
		if struggling_level <= 1:
			update_physics_score = 0.01
			Engine.max_physics_steps_per_frame = 1
			physics_fence = frames_before_change
			frame_time_switches += 100
		elif struggling_level < 2:
			update_physics_score -= 0.005
			frame_time_switches += 50
		elif struggling_level < 3:
			update_physics_score -= 0.0002
			frame_time_switches += 1
		elif struggling_level < 4:
			Engine.max_physics_steps_per_frame = 2
			update_physics_score += 0.0001
			frame_time_switches -= 1
		elif struggling_level < 5:
			Engine.max_physics_steps_per_frame = 3
			update_physics_score += 0.0003
			frame_time_switches -= 2
		elif struggling_level < 7:
			update_physics_score += 0.001
			frame_time_switches -= 3
		else:
			update_physics_score += 0.005
			frame_time_switches -= int(1 * Engine.physics_ticks_per_second)

		frame_time_switches = clamp(frame_time_switches, -10000, 10000)
		update_physics_score = clampf(update_physics_score, 0.01, 1)

		if physics_fence >= (frames_before_change * update_physics_score):
			physics_fence = 0

		if frame_time_switches > 5000 and offbrand_physics_DLSS == false:
			printerr("Sorry bud, performance is too jittery no matter what we do, switching to hacky low performance mode")
			offbrand_physics_DLSS = true
		if frame_time_switches < 0 and offbrand_physics_DLSS:
			print("performance seems to be better, going back to better boids")
			offbrand_physics_DLSS = false
	else:
		Engine.max_physics_steps_per_frame = 3
		update_physics_score = 1

	Engine.physics_ticks_per_second = clamp(int(starting_physics_tick * update_physics_score), 1, starting_physics_tick)

	if frame_fence % 800 == 0:
		print("FPS: " + str(Engine.get_frames_per_second()))
		print("Homies: " + str(Friendly_MultiMesh.multimesh.instance_count) + "\tbuffer size: " + str(Friendly_MultiMesh.multimesh.buffer.size()))
		print("Enemies: " + str(Enemy_MultiMesh.multimesh.instance_count) + "\tbuffer size: " + str(Enemy_MultiMesh.multimesh.buffer.size()))
		print("Total: " + str(ALL_ENTITIES_ent.size()) + "\t Velocities too: " + str(VELOCITIES_comp.size()))
		frame_fence = 0


var force : Vector3
var accel : Vector3
var new_trans : Transform3D
var temp_up : Vector3
var struggling_level : int = 0
const frames_before_change : int = 100
var physics_fence : int = 0


func _physics_process(delta: float) -> void:
	physics_fence += 1

	for ent in range(Max_Num_Boids):
		if inited and is_alive(ent) == false:
			continue

		new_trans = get_boid_transform(ent)
		var ship_pos : Vector3 = new_trans.origin
		var ship_vel : Vector3 = VELOCITIES_comp[ent]

		# Every ship regularly checks if a better target exists.
		ALL_ENTITY_TARGET_RECHECK_TIMER_comp[ent] -= delta
		if ALL_ENTITY_TARGET_RECHECK_TIMER_comp[ent] <= 0.0:
			_repick_target(ent)
			ALL_ENTITY_TARGET_RECHECK_TIMER_comp[ent] = target_recheck_seconds

		var avoid_force_data : Dictionary = _calculate_dont_crash_force(ship_pos, ship_vel)
		var avoid_force : Vector3 = avoid_force_data.force
		var is_too_close_to_planet : bool = avoid_force_data.too_close

		var steer_force : Vector3 = Vector3.ZERO
		var desired_force : Vector3 = Vector3.ZERO
		var avoid_weight : float = dont_crash_weight

		if ALL_ENTITY_AMMOS_comp[ent] < 0:
			var mothership : Node3D = Friendly_MotherShip if is_friendly(ent) else Enemy_MotherShip
			if mothership != null:
				desired_force = _arrive_force(ship_pos, mothership.global_position, ship_vel, arrive_slowing_distance)
				_process_reload_logic(ent, ship_pos, mothership.global_position, delta)
			steer_force = desired_force * return_weight + avoid_force * avoid_weight
		else:
			var target_pos : Vector3 = _get_current_target_position(ent, ship_pos)
			desired_force = _seek_force(ship_pos, target_pos, ship_vel)

			# If we're super close to a planet, crash-avoidance should overpower seek/pursue.
            if is_too_close_to_planet:
                avoid_weight *= near_crash_multiplier
                steer_force = desired_force * (seek_weight * 0.15) + avoid_force * avoid_weight
            else:
                steer_force = desired_force * seek_weight + avoid_force * avoid_weight

            _process_ship_fire(ent, new_trans, target_pos, delta)

        if steer_force.length() > max_force:
            steer_force = steer_force.limit_length(max_force)

        force = steer_force
        accel = force / max(mass, 0.001)
        VELOCITIES_comp[ent] += accel * delta
        if VELOCITIES_comp[ent].length() > max_speed:
            VELOCITIES_comp[ent] = VELOCITIES_comp[ent].limit_length(max_speed)

        if VELOCITIES_comp[ent].length_squared() > 0.01:
            temp_up = new_trans.basis.y.lerp((Vector3.UP + accel * banking).normalized(), delta * 5.0)
            new_trans = new_trans.looking_at(new_trans.origin - VELOCITIES_comp[ent], temp_up)

        new_trans.origin += VELOCITIES_comp[ent] * delta
        _push_transform_to_buffers(ent, new_trans)

    _update_bullets(delta)
    _update_reload_pulses(delta)
    _update_planet_hit_pulses(delta)
    _flush_multimesh_buffers()


func _seek_force(from_pos: Vector3, target_pos: Vector3, current_vel: Vector3) -> Vector3:
    var to_target : Vector3 = target_pos - from_pos
    if to_target.length_squared() <= 0.00001:
        return Vector3.ZERO
    var desired : Vector3 = to_target.normalized() * max_speed
    return desired - current_vel


func _arrive_force(from_pos: Vector3, target_pos: Vector3, current_vel: Vector3, slowing_distance: float) -> Vector3:
    var to_target : Vector3 = target_pos - from_pos
    var dist : float = to_target.length()
    if dist < 0.001:
        return Vector3.ZERO
    if dist < reload_distance:
        return -current_vel * 0.6
    var ramped : float= (dist / max(slowing_distance, 0.01)) * max_speed
    var clipped : float = min(max_speed, ramped)
    var desired : = (to_target / dist) * clipped
    return desired - current_vel


func _calculate_dont_crash_force(ship_pos: Vector3, ship_vel: Vector3) -> Dictionary:
    var best_force : Vector3 = Vector3.ZERO
    var too_close : bool = false
    for i in range(Planet_Targets.size()):
        var planet : MeshInstance3D = Planet_Targets[i]
        var radius : float = Planet_Radius_comp[i]
        var to_ship : Vector3 = ship_pos - planet.global_position
        var dist : float = to_ship.length()
        if dist <= 0.0001:
            continue
        var avoid_distance : float= max(0.25, radius * avoid_radius_multiplier)
        if dist < avoid_distance + avoid_padding:
            var normal : Vector3 = to_ship / dist
            var strength : float = ((avoid_distance + avoid_padding) - dist) / max(avoid_distance, 0.001)
            var braking : Vector3 = (-ship_vel).limit_length(max_speed * 0.5) * strength
            var candidate : Vector3 = normal * (max_speed * strength) + braking
            if candidate.length_squared() > best_force.length_squared():
                best_force = candidate
            if dist < avoid_distance:
                too_close = true
    return {
        "force": best_force,
        "too_close": too_close,
    }


func _process_reload_logic(ent: int, ship_pos: Vector3, mothership_pos: Vector3, delta: float) -> void:
    var dist_to_base : float = ship_pos.distance_to(mothership_pos)
    if dist_to_base <= reload_distance:
        ALL_ENTITY_RELOAD_TIMER_comp[ent] += delta
        ALL_ENTITY_RELOAD_PULSE_TIMER_comp[ent] -= delta
        if ALL_ENTITY_RELOAD_PULSE_TIMER_comp[ent] <= 0.0:
            _spawn_reload_pulse(ship_pos)
            ALL_ENTITY_RELOAD_PULSE_TIMER_comp[ent] = reload_pulse_interval
        if ALL_ENTITY_RELOAD_TIMER_comp[ent] >= reload_time_required:
            ALL_ENTITY_AMMOS_comp[ent] = Max_Ammo_Capacity
            ALL_ENTITY_RELOAD_TIMER_comp[ent] = 0.0
            ALL_ENTITY_RELOAD_PULSE_TIMER_comp[ent] = 0.0
            _repick_target(ent)
    else:
        ALL_ENTITY_RELOAD_TIMER_comp[ent] = 0.0
        ALL_ENTITY_RELOAD_PULSE_TIMER_comp[ent] = 0.0


func _process_ship_fire(ent: int, ship_transform: Transform3D, target_pos: Vector3, delta: float) -> void:
    ALL_ENTITY_FIRE_COOLDOWN_comp[ent] -= delta
    if ALL_ENTITY_FIRE_COOLDOWN_comp[ent] > 0.0:
        return
    if ALL_ENTITY_AMMOS_comp[ent] < 0:
        return

    while ALL_ENTITY_FIRE_COOLDOWN_comp[ent] <= 0.0:
        ALL_ENTITY_FIRE_COOLDOWN_comp[ent] += fire_rate_seconds

    var ship_vel : Vector3 = VELOCITIES_comp[ent]
    var shot_dir : Vector3 = (target_pos - ship_transform.origin).normalized()
    if shot_dir.length_squared() < 0.001:
        shot_dir = ship_vel.normalized()
    if shot_dir.length_squared() < 0.001:
        shot_dir = -ship_transform.basis.z.normalized()

    # Bullet world velocity is a snapshot at fire time:
    # inherited ship momentum + muzzle velocity along shot direction.
    var bullet_world_velocity : Vector3 = ship_vel + (shot_dir * bullet_speed)
    if bullet_world_velocity.length_squared() < 0.00001:
        bullet_world_velocity = shot_dir * bullet_speed

    var owner_team : int = 0 if is_friendly(ent) else 1
    var target_kind : int = ALL_ENTITY_TARGET_KIND_comp[ent]
    var target_index : int = ALL_ENTITY_TARGET_INDEX_comp[ent]
    _spawn_bullet(ship_transform.origin, bullet_world_velocity, owner_team, target_kind, target_index)
    ALL_ENTITY_AMMOS_comp[ent] -= 1


func _spawn_bullet(pos: Vector3, vel: Vector3, owner_team: int, target_kind: int, target_index: int) -> void:
    if BULLET_ACTIVE_COUNT >= BULLET_CAPACITY:
        return

    var bullet_index : int = BULLET_ACTIVE_COUNT
    BULLET_ACTIVE_COUNT += 1

    BULLET_POSITIONS_comp[bullet_index] = pos
    BULLET_VELOCITIES_comp[bullet_index] = vel
    BULLET_LIFETIMES_comp[bullet_index] = bullet_lifetime
    BULLET_OWNERS_comp[bullet_index] = owner_team
    BULLET_TARGET_KIND_comp[bullet_index] = target_kind
    BULLET_TARGET_comp[bullet_index] = target_index

    # If a particles node exists in scene, emit once for muzzle flash vibe.
    if has_node(canons_node_name):
        var maybe_particles = get_node(canons_node_name)
        if maybe_particles is GPUParticles3D:
            maybe_particles.global_position = pos
            maybe_particles.emitting = true


func _update_bullets(delta: float) -> void:
    for i in range(BULLET_ACTIVE_COUNT - 1, -1, -1):
        BULLET_LIFETIMES_comp[i] -= delta
        if BULLET_LIFETIMES_comp[i] <= 0.0:
            _remove_bullet_swap(i)
            continue

        BULLET_POSITIONS_comp[i] += BULLET_VELOCITIES_comp[i] * delta

        var did_hit : bool = false
        var target_kind : int = BULLET_TARGET_KIND_comp[i]
        var target_index : int = BULLET_TARGET_comp[i]
        var owner_team : int = BULLET_OWNERS_comp[i]

        if target_kind == 1:
            did_hit = _bullet_hit_planet(BULLET_POSITIONS_comp[i], target_index)
            if did_hit:
                on_hit_planet(target_index, bullet_damage_to_planets)
        else:
            did_hit = _bullet_hit_ship(BULLET_POSITIONS_comp[i], target_index, owner_team)
            if did_hit:
                on_hit_ship(target_index, bullet_damage_to_ships, owner_team)

        if did_hit:
            _remove_bullet_swap(i)

    _render_bullets()


func _render_bullets() -> void:
    if Bolt_Visuals == null or Bolt_Visuals.multimesh == null:
        return
    var count : int = BULLET_ACTIVE_COUNT
    if Bolt_Visuals.multimesh.instance_count != BULLET_CAPACITY:
        Bolt_Visuals.multimesh.instance_count = BULLET_CAPACITY
    Bolt_Visuals.multimesh.visible_instance_count = count
    for i in range(count):
        var t : Transform3D = Transform3D(Basis.IDENTITY, BULLET_POSITIONS_comp[i])
        Bolt_Visuals.multimesh.set_instance_transform(i, t)


func _remove_bullet_swap(index: int) -> void:
    var last_index : int = BULLET_ACTIVE_COUNT - 1
    if index < 0 or index > last_index:
        return
    if index != last_index:
        BULLET_POSITIONS_comp[index] = BULLET_POSITIONS_comp[last_index]
        BULLET_VELOCITIES_comp[index] = BULLET_VELOCITIES_comp[last_index]
        BULLET_LIFETIMES_comp[index] = BULLET_LIFETIMES_comp[last_index]
        BULLET_OWNERS_comp[index] = BULLET_OWNERS_comp[last_index]
        BULLET_TARGET_KIND_comp[index] = BULLET_TARGET_KIND_comp[last_index]
        BULLET_TARGET_comp[index] = BULLET_TARGET_comp[last_index]
    BULLET_ACTIVE_COUNT -= 1


func _bullet_hit_planet(bullet_pos: Vector3, planet_index: int) -> bool:
    if planet_index < 0 or planet_index >= Planet_Targets.size():
        return false
    var dist : float = bullet_pos.distance_to(Planet_Targets[planet_index].global_position)
    return dist <= Planet_Radius_comp[planet_index]


func _bullet_hit_ship(bullet_pos: Vector3, ship_index: int, owner_team: int) -> bool:
    if ship_index < 0 or ship_index >= Max_Num_Boids:
        return false
    if not is_alive(ship_index):
        return false
    if owner_team == 0 and is_friendly(ship_index):
        return false
    if owner_team == 1 and is_enemy(ship_index):
        return false
    var ship_pos : Vector3 = get_boid_transform(ship_index).origin
    return bullet_pos.distance_to(ship_pos) <= bullet_ship_hit_radius


func on_hit_planet(planet_index: int, damage: int = 1) -> void:
    if planet_index < 0 or planet_index >= Planet_Pulse_Timer_comp.size():
        return
    Planet_Pulse_Timer_comp[planet_index] = planet_hit_pulse_duration


func on_hit_ship(entity_index: int, damage: int = 1, source_team: int = -1) -> void:
    if entity_index < 0 or entity_index >= Max_Num_Boids:
        return
    if not is_alive(entity_index):
        return
    if source_team == 0 and is_friendly(entity_index):
        return
    if source_team == 1 and is_enemy(entity_index):
        return

    ALL_ENTITY_HEALTH_comp[entity_index] -= damage
    if ALL_ENTITY_HEALTH_comp[entity_index] <= 0:
        _kill_ship(entity_index)


func _kill_ship(entity_index: int) -> void:
    ALL_ENTITIES_ent[entity_index] = 0
    ALL_ENTITY_HEALTH_comp[entity_index] = 0
    ALL_ENTITY_AMMOS_comp[entity_index] = -1
    VELOCITIES_comp[entity_index] = Vector3.ZERO
    var dead_transform : Transform3D = Transform3D.IDENTITY
    dead_transform.origin = Vector3(999999, 999999, 999999)
    set_boid_transform(entity_index, dead_transform)


func _update_planet_hit_pulses(delta: float) -> void:
    for i in range(Planet_Pulse_Timer_comp.size()):
        if Planet_Pulse_Timer_comp[i] > 0.0:
            Planet_Pulse_Timer_comp[i] = max(0.0, Planet_Pulse_Timer_comp[i] - delta)
        var overlay : StandardMaterial3D = Planet_Pulse_Overlay_comp[i]
        if overlay == null:
            continue
        var alpha : float = Planet_Pulse_Timer_comp[i] / max(planet_hit_pulse_duration, 0.001)
        overlay.emission_energy_multiplier = alpha * planet_hit_pulse_energy
        overlay.albedo_color = Color(1.0, 0.0, 0.0, alpha * 0.25)


func _spawn_reload_pulse(pos: Vector3) -> void:
    RELOAD_PULSE_POSITIONS_comp.push_back(pos)
    RELOAD_PULSE_LIFETIMES_comp.push_back(reload_pulse_duration)


func _update_reload_pulses(delta: float) -> void:
    for i in range(RELOAD_PULSE_POSITIONS_comp.size() - 1, -1, -1):
        RELOAD_PULSE_LIFETIMES_comp[i] -= delta
        if RELOAD_PULSE_LIFETIMES_comp[i] <= 0.0:
            RELOAD_PULSE_POSITIONS_comp.remove_at(i)
            RELOAD_PULSE_LIFETIMES_comp.remove_at(i)

    if Reload_Pulse_Visuals == null or Reload_Pulse_Visuals.multimesh == null:
        return

    Reload_Pulse_Visuals.multimesh.instance_count = RELOAD_PULSE_POSITIONS_comp.size()
    for i in range(RELOAD_PULSE_POSITIONS_comp.size()):
        Reload_Pulse_Visuals.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, RELOAD_PULSE_POSITIONS_comp[i]))


func _repick_target(ent: int) -> void:
    if is_friendly(ent):
        _pick_best_enemy_target(ent)
    else:
        _pick_best_planet_target(ent)


func _pick_best_enemy_target(ent: int) -> void:
    var current : int = ALL_ENTITY_TARGET_INDEX_comp[ent]
    var ship_pos : Vector3 = get_boid_transform(ent).origin
    var best : int = current
    var best_dist : float = INF

    if current >= 0 and current < Max_Num_Boids and is_alive(current) and is_enemy(current):
        best_dist = ship_pos.distance_to(get_boid_transform(current).origin)
    else:
        best = -1

    var attempts : int = 3
    for _i in range(attempts):
        var candidate : int = _random_alive_enemy_index()
        if candidate == -1:
            continue
        var dist : float = ship_pos.distance_to(get_boid_transform(candidate).origin)
        if dist < best_dist:
            best_dist = dist
            best = candidate

    ALL_ENTITY_TARGET_INDEX_comp[ent] = best
    ALL_ENTITY_TARGET_KIND_comp[ent] = 0


func _pick_best_planet_target(ent: int) -> void:
    if Planet_Targets.is_empty():
        ALL_ENTITY_TARGET_INDEX_comp[ent] = -1
        ALL_ENTITY_TARGET_KIND_comp[ent] = 1
        return

    var current : int = ALL_ENTITY_TARGET_INDEX_comp[ent]
    var ship_pos : Vector3 = get_boid_transform(ent).origin
    var best : int = current
    var best_dist : float = INF

    if current >= 0 and current < Planet_Targets.size():
        best_dist = ship_pos.distance_to(Planet_Targets[current].global_position)
    else:
        best = randi_range(0, Planet_Targets.size() - 1)
        best_dist = ship_pos.distance_to(Planet_Targets[best].global_position)

    for _i in range(3):
        var candidate : int = randi_range(0, Planet_Targets.size() - 1)
        var dist : float = ship_pos.distance_to(Planet_Targets[candidate].global_position)
        if dist < best_dist:
            best_dist = dist
            best = candidate

    ALL_ENTITY_TARGET_INDEX_comp[ent] = best
    ALL_ENTITY_TARGET_KIND_comp[ent] = 1


func _random_alive_enemy_index() -> int:
    if max_friendly_count >= Max_Num_Boids:
        return -1
    for _i in range(8):
        var idx : int = randi_range(max_friendly_count, Max_Num_Boids - 1)
        if is_alive(idx):
            return idx
    for idx in range(max_friendly_count, Max_Num_Boids):
        if is_alive(idx):
            return idx
    return -1


func _get_current_target_position(ent: int, fallback_from: Vector3) -> Vector3:
    var target_kind : int = ALL_ENTITY_TARGET_KIND_comp[ent]
    var target_idx : int = ALL_ENTITY_TARGET_INDEX_comp[ent]

    if target_kind == 1:
        if target_idx >= 0 and target_idx < Planet_Targets.size():
            return Planet_Targets[target_idx].global_position
        _pick_best_planet_target(ent)
        target_idx = ALL_ENTITY_TARGET_INDEX_comp[ent]
        if target_idx >= 0 and target_idx < Planet_Targets.size():
            return Planet_Targets[target_idx].global_position
    else:
        if target_idx >= 0 and target_idx < Max_Num_Boids and is_alive(target_idx):
            return get_boid_transform(target_idx).origin
        _pick_best_enemy_target(ent)
        target_idx = ALL_ENTITY_TARGET_INDEX_comp[ent]
        if target_idx >= 0 and target_idx < Max_Num_Boids and is_alive(target_idx):
            return get_boid_transform(target_idx).origin

    return fallback_from


func _push_transform_to_buffers(ent: int, t: Transform3D) -> void:
    if ent < max_friendly_count:
        var i : int = 12 * ent
        if use_prev_buffer or offbrand_physics_DLSS == false:
            temp_friend_mesh_push_buffer[i + 0] = t.basis.x.x
            temp_friend_mesh_push_buffer[i + 1] = t.basis.y.x
            temp_friend_mesh_push_buffer[i + 2] = t.basis.z.x
            temp_friend_mesh_push_buffer[i + 3] = t.origin.x
            temp_friend_mesh_push_buffer[i + 4] = t.basis.x.y
            temp_friend_mesh_push_buffer[i + 5] = t.basis.y.y
            temp_friend_mesh_push_buffer[i + 6] = t.basis.z.y
            temp_friend_mesh_push_buffer[i + 7] = t.origin.y
            temp_friend_mesh_push_buffer[i + 8] = t.basis.x.z
            temp_friend_mesh_push_buffer[i + 9] = t.basis.y.z
            temp_friend_mesh_push_buffer[i + 10] = t.basis.z.z
            temp_friend_mesh_push_buffer[i + 11] = t.origin.z
        else:
            prev_friend_mesh_push_buffer[i + 0] = t.basis.x.x
            prev_friend_mesh_push_buffer[i + 1] = t.basis.y.x
            prev_friend_mesh_push_buffer[i + 2] = t.basis.z.x
            prev_friend_mesh_push_buffer[i + 3] = t.origin.x
            prev_friend_mesh_push_buffer[i + 4] = t.basis.x.y
            prev_friend_mesh_push_buffer[i + 5] = t.basis.y.y
            prev_friend_mesh_push_buffer[i + 6] = t.basis.z.y
            prev_friend_mesh_push_buffer[i + 7] = t.origin.y
            prev_friend_mesh_push_buffer[i + 8] = t.basis.x.z
            prev_friend_mesh_push_buffer[i + 9] = t.basis.y.z
            prev_friend_mesh_push_buffer[i + 10] = t.basis.z.z
            prev_friend_mesh_push_buffer[i + 11] = t.origin.z
    else:
        var idx : int = ent - max_friendly_count
        var j : int = 12 * idx
        if use_prev_buffer or offbrand_physics_DLSS == false:
            temp_enemy_mesh_push_buffer[j + 0] = t.basis.x.x
            temp_enemy_mesh_push_buffer[j + 1] = t.basis.y.x
            temp_enemy_mesh_push_buffer[j + 2] = t.basis.z.x
            temp_enemy_mesh_push_buffer[j + 3] = t.origin.x
            temp_enemy_mesh_push_buffer[j + 4] = t.basis.x.y
            temp_enemy_mesh_push_buffer[j + 5] = t.basis.y.y
            temp_enemy_mesh_push_buffer[j + 6] = t.basis.z.y
            temp_enemy_mesh_push_buffer[j + 7] = t.origin.y
            temp_enemy_mesh_push_buffer[j + 8] = t.basis.x.z
            temp_enemy_mesh_push_buffer[j + 9] = t.basis.y.z
            temp_enemy_mesh_push_buffer[j + 10] = t.basis.z.z
            temp_enemy_mesh_push_buffer[j + 11] = t.origin.z
        else:
            prev_enemy_mesh_push_buffer[j + 0] = t.basis.x.x
            prev_enemy_mesh_push_buffer[j + 1] = t.basis.y.x
            prev_enemy_mesh_push_buffer[j + 2] = t.basis.z.x
            prev_enemy_mesh_push_buffer[j + 3] = t.origin.x
            prev_enemy_mesh_push_buffer[j + 4] = t.basis.x.y
            prev_enemy_mesh_push_buffer[j + 5] = t.basis.y.y
            prev_enemy_mesh_push_buffer[j + 6] = t.basis.z.y
            prev_enemy_mesh_push_buffer[j + 7] = t.origin.y
            prev_enemy_mesh_push_buffer[j + 8] = t.basis.x.z
            prev_enemy_mesh_push_buffer[j + 9] = t.basis.y.z
            prev_enemy_mesh_push_buffer[j + 10] = t.basis.z.z
            prev_enemy_mesh_push_buffer[j + 11] = t.origin.z


func _flush_multimesh_buffers() -> void:
    if offbrand_physics_DLSS:
        if use_prev_buffer:
            Friendly_MultiMesh.multimesh.set_buffer_interpolated(temp_friend_mesh_push_buffer, prev_friend_mesh_push_buffer)
            Enemy_MultiMesh.multimesh.set_buffer_interpolated(temp_enemy_mesh_push_buffer, prev_enemy_mesh_push_buffer)
        else:
            Friendly_MultiMesh.multimesh.set_buffer_interpolated(prev_friend_mesh_push_buffer, temp_friend_mesh_push_buffer)
            Enemy_MultiMesh.multimesh.set_buffer_interpolated(prev_enemy_mesh_push_buffer, temp_enemy_mesh_push_buffer)
        use_prev_buffer = !use_prev_buffer
    else:
        Friendly_MultiMesh.multimesh.buffer = temp_friend_mesh_push_buffer
        Enemy_MultiMesh.multimesh.buffer = temp_enemy_mesh_push_buffer


func set_boid_transform(ship_entity_index : int, new_transform : Transform3D):
    if is_friendly(ship_entity_index):
        Friendly_MultiMesh.multimesh.set_instance_transform(ship_entity_index, new_transform)
    else:
        Enemy_MultiMesh.multimesh.set_instance_transform((ship_entity_index - max_friendly_count), new_transform)


func spawn_ship(force_spawn : bool, p_is_friendly : bool) -> bool:
    var free_index : int

    if p_is_friendly:
        free_index = ALL_ENTITIES_ent.find(0)
        if free_index != -1 and is_enemy(free_index):
            free_index = -1
    else:
        free_index = ALL_ENTITIES_ent.find(0, max_friendly_count)

    if free_index == -1 and force_spawn and p_is_friendly:
        free_index = randi_range(0, max_friendly_count - 1)
    elif free_index == -1 and force_spawn and not p_is_friendly:
        free_index = randi_range(max_friendly_count, Max_Num_Boids - 1)
    elif free_index == -1 and force_spawn == false:
        return false

    var start_health_sign = 1 if p_is_friendly else -1
    var start_pos : Vector3 = Friendly_Spawn_Point.global_position if p_is_friendly else Enemy_Spawn_Point.global_position
    var start_transform : Transform3D = Transform3D.IDENTITY

    if p_is_friendly:
        Friendly_MultiMesh.multimesh.buffer[(free_index * 12)] = 1.0
        Friendly_MultiMesh.multimesh.buffer[(free_index * 12) + 3] = start_pos.x
        Friendly_MultiMesh.multimesh.buffer[(free_index * 12) + 5] = 1.0
        Friendly_MultiMesh.multimesh.buffer[(free_index * 12) + 7] = start_pos.y
        Friendly_MultiMesh.multimesh.buffer[(free_index * 12) + 10] = 1.0
        Friendly_MultiMesh.multimesh.buffer[(free_index * 12) + 11] = start_pos.z
    else:
        var enemy_idx : int = free_index - max_friendly_count
        Enemy_MultiMesh.multimesh.buffer[(enemy_idx * 12)] = 1.0
        Enemy_MultiMesh.multimesh.buffer[(enemy_idx * 12) + 3] = start_pos.x
        Enemy_MultiMesh.multimesh.buffer[(enemy_idx * 12) + 5] = 1.0
        Enemy_MultiMesh.multimesh.buffer[(enemy_idx * 12) + 7] = start_pos.y
        Enemy_MultiMesh.multimesh.buffer[(enemy_idx * 12) + 10] = 1.0
        Enemy_MultiMesh.multimesh.buffer[(enemy_idx * 12) + 11] = start_pos.z

    start_transform.origin = start_pos
    start_transform = start_transform.looking_at(start_pos + Vector3.DOWN, Vector3.UP)
    ALL_ENTITIES_ent[free_index] = ship_max_health * start_health_sign
    ALL_ENTITY_HEALTH_comp[free_index] = ship_max_health
    ALL_ENTITY_AMMOS_comp[free_index] = Max_Ammo_Capacity
    ALL_ENTITY_TARGET_INDEX_comp[free_index] = -1
    ALL_ENTITY_TARGET_KIND_comp[free_index] = 0 if p_is_friendly else 1
    ALL_ENTITY_RELOAD_TIMER_comp[free_index] = 0.0
    ALL_ENTITY_RELOAD_PULSE_TIMER_comp[free_index] = 0.0
    ALL_ENTITY_FIRE_COOLDOWN_comp[free_index] = randf_range(0.0, fire_rate_seconds)
    ALL_ENTITY_TARGET_RECHECK_TIMER_comp[free_index] = randf_range(0.0, target_recheck_seconds)

    VELOCITIES_comp[free_index] = Vector3(randf_range(-0.02, 0.02), randf_range(-0.8, -4), randf_range(-0.02, 0.02))
    set_boid_transform(free_index, start_transform)
    _repick_target(free_index)
    return true


func spawn_friendly(force_spawn = false) -> bool:
    return spawn_ship(force_spawn, true)


func spawn_enemy(force_spawn = false) -> bool:
    return spawn_ship(force_spawn, false)
