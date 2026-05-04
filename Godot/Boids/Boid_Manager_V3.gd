extends Node
class_name Boid_Manager_V3


static var Boid_Manager_Instance : Boid_Manager_V3
static func Get_Instance():
    return Boid_Manager_Instance



## right listen bookaroo, ok so here we got the best boid manager ever we gonna get the multimesh and shit gonna jkust be lit!
## So we got homies and enemies, homies gonna be -120 health to -1,
## enemies gonna be 1 to 120 health
## althe healths are apart of a packed bute array but of SIGNED BYTE
## NOT unsigned


@export_group("Global")

## whats the absoilute maximum number of boids we can have??
static var MAX_NUMBER_OF_BOIDS : int = 1000

## How do we want to divide up our friendlies? (Assuming we want 100 boids max)
##   0.5 == Equal num of Friends V Enemy (50 v 50)
##   0.1 == Small num of Friends V CRAP LOADS of Enemy (10 v 90)
static var Friendly_Enemy_Count_Ratio : float = 0.5

## All bolts can only exit for a max of X seconds... we want to 
static var All_Bolts_Lifetimes : float = 2.0


@export_group("Friendlys")
# Where will friendlys spawn?
## where we all gonna spawn from
@export var Friendly_Spawn_Point : Node3D

## How many Friendlys are we allowed to spawn? If we have 100 boids max, with a 50/50 friendly/enemy split,
## rathar than having all 50 friendlies spawn at once, we can say "HEY, only 20% can spawn of the 50 we have"
#@export_range(0.01, 1.0, 0.01, "prefer_slider") var Friendly_Spawn_Pool_Amount : float = 0.2
var Friendly_Spawn_Pool_Amount : float = 1.0

## what mesh we gonna use for enemies
@export var Friendly_MultiMesh : MultiMeshInstance3D

## any cool friendly meshes?
@export var Friendly_Ship_Mesh : MeshInstance3D

## what mesh we gonna use for friendly ships bolts when firing
@export var Friendly_Bolts_MultiMesh : MultiMeshInstance3D

@export_group("Enemies")
# Where will friendlys spawn?
## where we all gonna spawn from
@export var Enemy_Spawn_Point : Node3D

@export_range(0.01, 1.0, 0.01, "prefer_slider") var Enemy_Spawn_Pool_Amount : float = 0.2

## what multimesh we gonna use for enemies
@export var Enemy_MultiMesh : MultiMeshInstance3D

## What mesh we wanna use for enemies?
@export var Enemy_Ship_Mesh : MeshInstance3D

## what multimesh we gonna use for enemies
@export var Enemy_Bolts_MultiMesh : MultiMeshInstance3D

@export_group("Steering")
@export var max_speed : float = 2.0
@export var max_force : float = 10.0
@export var banking : float = 0.05
@export var mass : float = 2.0
@export var arrive_slowing_distance : float = 4.0

@export_group("Combat")
## How close does a boid need to be at a mothership to reload?
@export var reload_distance : float = 0.5
@export var reload_time_required : float = 10.0

## must divide nicely into 2.0, or whatever All_Bolts_Lifetimes is
const Friendly_Fire_Rate : float = 0.4
const Enemy_Fire_Rate : float = 1.0

## At what distance can a boid fire?
@export var Friendly_Firing_Distance : float = 2
@export var Enemy_Firing_Distance : float = 1.0 

## At what speed do bolts shoot?
@export var Friendly_Firing_Starting_Speed : float = 2
@export var Enemy_Firing_Starting_Speed : float = 1.1

## Whats the ammo capacity to reload to? (never go above 125)
@export var Friendly_Ammo_Capacity : int = 50
@export var Enemy_Ammo_Capacity : int = 10 


var max_num_friendly_bolts : int = ceili(All_Bolts_Lifetimes / Friendly_Fire_Rate)
var max_num_enemy_bolts : int = ceili(All_Bolts_Lifetimes / Enemy_Fire_Rate)


## How long (seconds) does it take for a boid to respawn and start shooting again
@export var Friendly_Respawn_Time : float = 5.0
@export var Enemy_Respawn_Time : float = 5.0
@export var Enemy_Bolts_Explosion_Radius : float = 5 
@export var Enemy_Bolts_Explosion_Damage : int = 25

## Check every X seconds if the target our boid is targetting is still worth it? or should we choose another?
@export var target_recheck_seconds : float = 5.0


# signed health of ALL entities:
var All_Friendly_Boids_ENT : PackedByteArray
var All_Enemy_Boids_ENT : PackedByteArray




# ----- All Enetity COMPonents ------------------------------------------
## Ammo of all boids... 0 means we gotta refuel, >= 1 means we can keep firing
## Ammo_COMP[10] = 55 means the 10th boid is at 55 ammo 
var Friendly_Ammo_COMP : PackedByteArray
var Enemy_Ammo_COMP : PackedByteArray

## Who are our boids targetting? 
## Lets get all their global positions
var Friendly_Target_Enemy_Boid : PackedVector3Array
var Enemy_Target_Enemy_Boid : PackedVector3Array


## How long left for this boid to be fully reloaded
var Friendly_boid_reload_Timer_COMP : PackedFloat32Array
var Enemy_boid_reload_Timer_COMP : PackedFloat32Array


## For enemies, which planet they're targetting
@onready var targets_index : Dictionary[int, Damageable] = {
    -1 : %PlanetEarthy,
    -2 : %PlanetMoony,
    -3 : %PlanetKnockOffJupiter,
    -4 : %"THE GODDAMN SUN",
    -5 : %"Friendly MotherShip",
    -6 : %"Enemy MotherShip"
}


## What's the velocity of the boid at index i ?
var Friendly_Boid_Velocitys : PackedVector3Array 
var Enemy_Boid_Velocitys : PackedVector3Array 


## Velocity of all friendly bolts
var Friendly_Bolts_Velocities : PackedVector3Array
var Friendly_Bolts_Lifetimes : PackedFloat32Array


## Velocity of all Enemy Bolts
var Enemy_Bolts_Velocities : PackedVector3Array
var Enemy_Bolts_Lifetimes : PackedFloat32Array



## We're going to be using Offbrand Physics DLSS for this (see original Boid_Manager)
## when pushing a new buffer, we need to swap between current and previous buffer
## like a Graphics SwapChain
var _current_friendly_transforms_buffer : PackedVector3Array
var _current_friendly_bolts_transforms_buffer : PackedVector3Array
var _current_enemy_transforms_buffer : PackedVector3Array
var _current_enemy_bolts_transforms_buffer : PackedVector3Array

var _previous_friendly_transforms_buffer : PackedVector3Array
var _previous_friendly_bolts_transforms_buffer : PackedVector3Array
var _previous_enemy_transforms_buffer : PackedVector3Array
var _previous_enemy_bolts_transforms_buffer : PackedVector3Array

var _use_current_buffer_this_frame : bool = true

const DEFAULT_BOID_HEALTH : int = 120
const RETIRED_BOLT_LIFETIME : float = -1.0
const ACTIVE_BOLT_SCALE : float = 1.0
const RETIRED_BOLT_SCALE : float = 0.000001



# --- My THREAD of sanity is waining -------------------------------------------
var FRIENDLY_BOID_MANAGER_THREAD : Thread
var ENEMY_BOID_MANAGER_THREAD : Thread
var FRIENDLY_BOID_BOLT_MANAGER_THREAD : Thread
var ENEMY_BOID_BOLT_MANAGER_THREAD : Thread
# ------------------------------------------------------------------------------



var _friendly_boid_wake_semaphore : Semaphore = Semaphore.new()
var _enemy_boid_wake_semaphore : Semaphore = Semaphore.new()
var _friendly_bolt_wake_semaphore : Semaphore = Semaphore.new()
var _enemy_bolt_wake_semaphore : Semaphore = Semaphore.new()

var _friendly_boid_done_semaphore : Semaphore = Semaphore.new()
var _enemy_boid_done_semaphore : Semaphore = Semaphore.new()
var _friendly_bolt_done_semaphore : Semaphore = Semaphore.new()
var _enemy_bolt_done_semaphore : Semaphore = Semaphore.new()

var _worker_exit_requested : bool = false

var _friendly_boid_worker_delta : float = 0.0
var _enemy_boid_worker_delta : float = 0.0
var _friendly_bolt_worker_delta : float = 0.0
var _enemy_bolt_worker_delta : float = 0.0

## Position of all planets
var _target_position_cache : Dictionary[int, Vector3] = {}

## Radius of all planets
var _target_radius_cache : Dictionary[int, float] = {}


var _bounds_extents_cache : Vector3 = Vector3(32.0, 16.0, 32.0)
var _has_bounds_cache : bool = false
var _simulation_time_seconds : float = 0.0
var _friendly_no_enemy_elapsed_seconds : float = 0.0




static func _friendly_slots_count() -> int:
    var slots_count : int = int(MAX_NUMBER_OF_BOIDS * Friendly_Enemy_Count_Ratio)
    return clampi(slots_count, 0, MAX_NUMBER_OF_BOIDS * Friendly_Enemy_Count_Ratio)

static func _enemy_slots_count() -> int:
    return MAX_NUMBER_OF_BOIDS - _friendly_slots_count()



## increase the enemy pool size from X percent to Y percent... 
## if Add_Amount is greater than 1.0 it will mean we just spawn the maximum number of enemies
func Increase_Enemy_Pool_Size(Add_Amount : float) -> bool:
    if Enemy_Spawn_Pool_Amount < 1.0:
        Enemy_Spawn_Pool_Amount += Add_Amount
        Enemy_Spawn_Pool_Amount = clampf(Enemy_Spawn_Pool_Amount, 0.0, 1.0)
        return true
    return false



## Decrease the enemy pool size from X percent to Y percent... 
func Decrease_Enemy_Pool_Size(Add_Amount : float) -> bool:
    if Enemy_Spawn_Pool_Amount > 0.000001:
        Enemy_Spawn_Pool_Amount -= Add_Amount
        Enemy_Spawn_Pool_Amount = clampf(Enemy_Spawn_Pool_Amount, 0.00001, 1.0)
        return true
    return false



func _enemy_pool_cap() -> int:
    var raw_cap : int = int(float(_enemy_slots_count()) * Enemy_Spawn_Pool_Amount)
    if _enemy_slots_count() <= 0:
        return 0
    return clampi(raw_cap, 1, _enemy_slots_count())



#get the boid transform using the buffer we're ACTUALLY using this frame
func _get_boid_transform(boid_index: int, get_Friendly: bool, get_Bolt: bool, use_previous_frame : bool = false, ) -> Transform3D:
    var use_upcoming_frame_buffer : bool 
    
    if use_previous_frame:
        use_upcoming_frame_buffer = not _use_current_buffer_this_frame
    else:
        use_upcoming_frame_buffer = _use_current_buffer_this_frame
    
    var target_buffer : PackedVector3Array
    
    if get_Friendly and get_Bolt:
        if use_upcoming_frame_buffer:
            target_buffer = _current_friendly_bolts_transforms_buffer
        else:
            target_buffer = _previous_friendly_bolts_transforms_buffer
    
    elif get_Friendly and not get_Bolt:
        if use_upcoming_frame_buffer:
            target_buffer = _current_friendly_transforms_buffer
        else:
            target_buffer = _previous_friendly_transforms_buffer
    
    elif not get_Friendly and get_Bolt:
        if use_upcoming_frame_buffer:
            target_buffer = _current_enemy_bolts_transforms_buffer
        else:
            target_buffer = _previous_enemy_bolts_transforms_buffer
    else:
        if use_upcoming_frame_buffer:
            target_buffer = _current_enemy_transforms_buffer
        else:
            target_buffer = _previous_enemy_transforms_buffer
    
    if target_buffer == null:
        printerr("_get_boid_transform is returning null target buffer")
        return Transform3D.IDENTITY
    
    return Transform3D(
        target_buffer.get((boid_index * 4) + 0),
        target_buffer.get((boid_index * 4) + 1),
        target_buffer.get((boid_index * 4) + 2),
        target_buffer.get((boid_index * 4) + 3)
        )



func _set_boid_transform(boid_index: int, get_Friendly: bool, get_Bolt: bool, new_transform: Transform3D) -> bool:
    var target_buffer : PackedVector3Array
    
    if get_Friendly and get_Bolt:
        if _use_current_buffer_this_frame:
            target_buffer = _current_friendly_bolts_transforms_buffer
        else:
            target_buffer = _previous_friendly_bolts_transforms_buffer
    
    elif get_Friendly and not get_Bolt:
        if _use_current_buffer_this_frame:
            target_buffer = _current_friendly_transforms_buffer
        else:
            target_buffer = _previous_friendly_transforms_buffer
    
    elif not get_Friendly and get_Bolt:
        if _use_current_buffer_this_frame:
            target_buffer = _current_enemy_bolts_transforms_buffer
        else:
            target_buffer = _previous_enemy_bolts_transforms_buffer
    else:
        if _use_current_buffer_this_frame:
            target_buffer = _current_enemy_transforms_buffer
        else:
            target_buffer = _previous_enemy_transforms_buffer
    
    target_buffer[boid_index + 0] = new_transform.basis.x
    target_buffer[boid_index + 1] = new_transform.basis.y
    target_buffer[boid_index + 2] = new_transform.basis.z
    target_buffer[boid_index + 3] = new_transform.origin
    
    return true
    

            
            
func Get_Bolt_Velocity(Belonging_to_which_Boid : int, get_Friendly : bool, which_bolt : int) -> Vector3:
    var target_buffer : PackedVector3Array
    var max_num_bolts : int
    if get_Friendly and (which_bolt >= max_num_friendly_bolts):
        printerr("HEY! Homies can only have " + str(max_num_friendly_bolts) + " bolts")
        which_bolt = clampi(which_bolt, 0, (max_num_friendly_bolts-1))
        
    elif not get_Friendly and (which_bolt >= max_num_enemy_bolts):
        printerr("HEY! Enemies can only have " + str(max_num_enemy_bolts) + " bolts")
        which_bolt = clampi(which_bolt, 0, (max_num_enemy_bolts-1))
        
    max_num_bolts = max_num_friendly_bolts if get_Friendly else max_num_enemy_bolts
    
    if _use_current_buffer_this_frame:
        if get_Friendly:
            target_buffer = _current_friendly_bolts_transforms_buffer
        else:
            target_buffer = _current_enemy_bolts_transforms_buffer
    else:
        if get_Friendly:
            target_buffer = _previous_friendly_bolts_transforms_buffer
        else:
            target_buffer = _previous_enemy_bolts_transforms_buffer
            
    return target_buffer.get((Belonging_to_which_Boid * max_num_bolts) + which_bolt)
        


static func _is_bolt_slot_inactive(bolt_age: float) -> bool:
    return bolt_age < 0.0 or bolt_age > All_Bolts_Lifetimes


func _spawn_bolt(which_boid : int, get_Friendly : bool, origin: Vector3, velocity: Vector3) -> bool:
    # boids, where will we be shooting from and at what starting direction
    var starting_boid_velocity_buffer : PackedVector3Array
    var starting_boid_origin_buffer : PackedVector3Array
    
    # BOLTS
    var target_bolt_velocity_buffer : PackedVector3Array
    var target_bolt_lifetimes_buffer : PackedFloat32Array
    var starting_location : Vector3
    var starting_Velocity : Vector3
    
    starting_boid_velocity_buffer = Friendly_Boid_Velocitys if get_Friendly else Enemy_Boid_Velocitys
    
    if get_Friendly:
        starting_boid_origin_buffer = _current_friendly_transforms_buffer if _use_current_buffer_this_frame else _previous_friendly_transforms_buffer
    else:
        starting_boid_origin_buffer = _current_enemy_transforms_buffer if _use_current_buffer_this_frame else _previous_enemy_transforms_buffer
    
    
    # BOLTS now
    target_bolt_velocity_buffer = Friendly_Bolts_Velocities if get_Friendly else Enemy_Bolts_Velocities
    target_bolt_lifetimes_buffer = Friendly_Bolts_Lifetimes if get_Friendly else Enemy_Bolts_Lifetimes
    
    var bolt_index_lifetime : Dictionary[int, float] = {}
    var max_num_bolts = max_num_friendly_bolts if get_Friendly else max_num_enemy_bolts
    var starting_index : int = which_boid * max_num_bolts
    var min_wait_time : float = Friendly_Fire_Rate if get_Friendly else Enemy_Fire_Rate
    
    var all_lifetimes : Array[float]
    
    for bolt in max_num_bolts:
        all_lifetimes.append(target_bolt_lifetimes_buffer.get(starting_index + bolt))
        bolt_index_lifetime[starting_index + bolt] = all_lifetimes[bolt]
    all_lifetimes.sort()
    
    # has enough time even passed between the latest shot?
    if all_lifetimes.get(1) < min_wait_time:   
        return false
        
    var free_bolt_index = bolt_index_lifetime.find_key(0)
    
    
       
    
     
    

    buffer_ref[start_index + 0] = Vector3(scale, 0.0, 0.0)
    buffer_ref[start_index + 1] = Vector3(0.0, scale, 0.0)
    buffer_ref[start_index + 2] = Vector3(0.0, 0.0, scale)
    buffer_ref[start_index + 3] = origin
    return buffer_ref


func _set_bolt_transform_slot(slot_index: int, for_friendly: bool, origin: Vector3, scale: float, set_current: bool, set_previous: bool) -> void:
    if for_friendly:
        if set_current:
            _current_friendly_bolts_transforms_buffer = _set_bolt_transform_entry(_current_friendly_bolts_transforms_buffer, slot_index, origin, scale)
        if set_previous:
            _previous_friendly_bolts_transforms_buffer = _set_bolt_transform_entry(_previous_friendly_bolts_transforms_buffer, slot_index, origin, scale)
    else:
        if set_current:
            _current_enemy_bolts_transforms_buffer = _set_bolt_transform_entry(_current_enemy_bolts_transforms_buffer, slot_index, origin, scale)
        if set_previous:
            _previous_enemy_bolts_transforms_buffer = _set_bolt_transform_entry(_previous_enemy_bolts_transforms_buffer, slot_index, origin, scale)


func _get_bolt_origin(slot_index: int, for_friendly: bool, from_current_buffer: bool) -> Vector3:
    var source_buffer : PackedVector3Array
    if for_friendly:
        source_buffer = _current_friendly_bolts_transforms_buffer if from_current_buffer else _previous_friendly_bolts_transforms_buffer
    else:
        source_buffer = _current_enemy_bolts_transforms_buffer if from_current_buffer else _previous_enemy_bolts_transforms_buffer

    var origin_index : int = (slot_index * 4) + 3
    if origin_index >= source_buffer.size():
        return Vector3.ZERO
    return source_buffer[origin_index]


func _get_active_bolt_transforms_buffer(for_friendly_bolts: bool) -> PackedVector3Array:
    if for_friendly_bolts:
        return _current_friendly_bolts_transforms_buffer if _use_current_buffer_this_frame else _previous_friendly_bolts_transforms_buffer
    return _current_enemy_bolts_transforms_buffer if _use_current_buffer_this_frame else _previous_enemy_bolts_transforms_buffer


func _set_active_bolt_transforms_buffer(for_friendly_bolts: bool, new_buffer: PackedVector3Array) -> void:
    if for_friendly_bolts:
        if _use_current_buffer_this_frame:
            _current_friendly_bolts_transforms_buffer = new_buffer
        else:
            _previous_friendly_bolts_transforms_buffer = new_buffer
    else:
        if _use_current_buffer_this_frame:
            _current_enemy_bolts_transforms_buffer = new_buffer
        else:
            _previous_enemy_bolts_transforms_buffer = new_buffer


func _safe_normalised(input_vector: Vector3) -> Vector3:
    if input_vector.length_squared() <= 0.000001:
        return Vector3.ZERO
    return input_vector.normalized()


func _limit_magnitude(input_vector: Vector3, max_magnitude: float) -> Vector3:
    var safe_limit : float = max(max_magnitude, 0.000001)
    var current_length : float = input_vector.length()
    if current_length <= safe_limit:
        return input_vector
    return input_vector * (safe_limit / max(current_length, 0.000001))


func _steer_towards(current_velocity: Vector3, desired_velocity: Vector3) -> Vector3:
    var steering_force : Vector3 = desired_velocity - current_velocity
    return _limit_magnitude(steering_force, max_force)


func _calc_bounds_steer(boid_position: Vector3) -> Vector3:
    if _has_bounds_cache == false:
        return Vector3.ZERO

    var local_position : Vector3 = boid_position - _bounds_center_cache
    var safe_extents : Vector3 = Vector3(
        max(_bounds_extents_cache.x, 0.001),
        max(_bounds_extents_cache.y, 0.001),
        max(_bounds_extents_cache.z, 0.001)
    )

    var desired_direction : Vector3 = Vector3.ZERO
    var x_limit : float = safe_extents.x * 0.9
    var y_limit : float = safe_extents.y * 0.9
    var z_limit : float = safe_extents.z * 0.9

    if local_position.x > x_limit:
        desired_direction.x = -1.0
    elif local_position.x < -x_limit:
        desired_direction.x = 1.0

    if local_position.y > y_limit:
        desired_direction.y = -1.0
    elif local_position.y < -y_limit:
        desired_direction.y = 1.0

    if local_position.z > z_limit:
        desired_direction.z = -1.0
    elif local_position.z < -z_limit:
        desired_direction.z = 1.0

    return _safe_normalised(desired_direction)


func _calc_planet_avoidance_steer(boid_position: Vector3) -> Vector3:
    var avoidance_direction : Vector3 = Vector3.ZERO
    var planet_ids : PackedInt32Array = PackedInt32Array([-1, -2, -3, -4])
    var planet_i : int = 0
    while planet_i < planet_ids.size():
        var planet_id : int = planet_ids[planet_i]
        if _target_position_cache.has(planet_id) and _target_radius_cache.has(planet_id):
            var planet_position : Vector3 = _target_position_cache.get(planet_id, Vector3.ZERO)
            var planet_radius : float = float(_target_radius_cache.get(planet_id, 0.5))
            var to_boid : Vector3 = boid_position - planet_position
            var distance_to_planet : float = max(to_boid.length(), 0.000001)
            var avoidance_distance : float = max(planet_radius * 2.0, 0.5)
            if distance_to_planet < avoidance_distance:
                var push_strength : float = 1.0 - (distance_to_planet / avoidance_distance)
                avoidance_direction += _safe_normalised(to_boid) * push_strength
        planet_i += 1
    return _safe_normalised(avoidance_direction)


func _calc_separation_steer(boid_index: int, boid_position: Vector3, only_avoid_same_faction: bool) -> Vector3:
    var separation_direction : Vector3 = Vector3.ZERO
    var neighbour_scan_radius_sq : float = 9.0
    var candidate_boid_index : int = 0
    while candidate_boid_index < MAX_NUMBER_OF_BOIDS:
        if candidate_boid_index != boid_index and _is_valid_boid_index(candidate_boid_index):
            var candidate_health : int = int(All_Entities_ENT[candidate_boid_index])
            if candidate_health != 0:
                var same_faction : bool = (_is_friendly_slot_index(candidate_boid_index) and _is_friendly_slot_index(boid_index)) or (_is_enemy_slot_index(candidate_boid_index) and _is_enemy_slot_index(boid_index))
                if only_avoid_same_faction == false or same_faction:
                    var other_position : Vector3 = _get_boid_transform(candidate_boid_index, true).origin
                    var away : Vector3 = boid_position - other_position
                    var distance_sq : float = away.length_squared()
                    if distance_sq > 0.0001 and distance_sq < neighbour_scan_radius_sq:
                        separation_direction += away / distance_sq
        candidate_boid_index += 1

    return _safe_normalised(separation_direction)


func _compute_wander_steer(boid_index: int, forward_direction: Vector3) -> Vector3:
    var safe_forward : Vector3 = _safe_normalised(forward_direction)
    if safe_forward.length_squared() <= 0.000001:
        safe_forward = Vector3.FORWARD

    var right_direction : Vector3 = _safe_normalised(safe_forward.cross(Vector3.UP))
    if right_direction.length_squared() <= 0.000001:
        right_direction = Vector3.RIGHT
    var up_direction : Vector3 = _safe_normalised(right_direction.cross(safe_forward))
    if up_direction.length_squared() <= 0.000001:
        up_direction = Vector3.UP

    var angle_a : float = (_simulation_time_seconds * 1.1) + (float(boid_index) * 0.619)
    var angle_b : float = (_simulation_time_seconds * 1.7) + (float(boid_index) * 0.337)
    var wave_a : float = sin(angle_a)
    var wave_b : float = cos(angle_b)

    var wander_direction : Vector3 = safe_forward + (right_direction * wave_a * 0.7) + (up_direction * wave_b * 0.4)
    return _safe_normalised(wander_direction)


func _compose_boid_transform(boid_position: Vector3, boid_velocity: Vector3) -> Transform3D:
    var safe_velocity : Vector3 = boid_velocity
    if safe_velocity.length_squared() <= 0.000001:
        safe_velocity = Vector3.FORWARD
    var visual_forward : Vector3 = _safe_normalised(safe_velocity)
    var target_position : Vector3 = boid_position + visual_forward
    var look_transform : Transform3D = Transform3D(Basis.IDENTITY, boid_position).looking_at(target_position, Vector3.UP, true)
    return look_transform


func _find_nearest_enemy_boid_for_friendly(_friendly_boid_index: int, boid_position: Vector3, boid_forward: Vector3) -> int:
    var best_enemy_index : int = -1
    var best_distance_sq : float = INF
    var first_enemy_index : int = _friendly_slots_count()
    var enemy_index_scan : int = first_enemy_index
    var normalised_forward : Vector3 = _safe_normalised(boid_forward)
    var cone_dot_threshold : float = cos(deg_to_rad(28.0))
    if normalised_forward.length_squared() <= 0.000001:
        normalised_forward = Vector3.FORWARD

    while enemy_index_scan < MAX_NUMBER_OF_BOIDS:
        if _is_enemy_slot_index(enemy_index_scan) and All_Entities_ENT[enemy_index_scan] != 0:
            var enemy_scan_position : Vector3 = _get_boid_transform(enemy_index_scan, true).origin
            var to_enemy : Vector3 = enemy_scan_position - boid_position
            var enemy_scan_distance_sq : float = to_enemy.length_squared()
            if enemy_scan_distance_sq > 0.000001:
                var enemy_direction : Vector3 = to_enemy.normalized()
                var directional_dot : float = normalised_forward.dot(enemy_direction)
                if directional_dot >= cone_dot_threshold and enemy_scan_distance_sq < best_distance_sq:
                    best_distance_sq = enemy_scan_distance_sq
                    best_enemy_index = enemy_index_scan
        enemy_index_scan += 1

    if best_enemy_index != -1:
        return best_enemy_index

    enemy_index_scan = first_enemy_index
    while enemy_index_scan < MAX_NUMBER_OF_BOIDS:
        if _is_enemy_slot_index(enemy_index_scan) and All_Entities_ENT[enemy_index_scan] != 0:
            var enemy_position_any_direction : Vector3 = _get_boid_transform(enemy_index_scan, true).origin
            var any_direction_distance_sq : float = boid_position.distance_squared_to(enemy_position_any_direction)
            if any_direction_distance_sq < best_distance_sq:
                best_distance_sq = any_direction_distance_sq
                best_enemy_index = enemy_index_scan
        enemy_index_scan += 1

    return best_enemy_index


func _pick_nearest_planet_target(boid_position: Vector3) -> int:
    var planet_ids : PackedInt32Array = PackedInt32Array([-1, -2, -3, -4])
    var best_planet_id : int = -1
    var best_planet_distance_sq : float = INF
    var i : int = 0
    while i < planet_ids.size():
        var planet_id : int = planet_ids[i]
        if _target_position_cache.has(planet_id):
            var planet_position : Vector3 = _target_position_cache.get(planet_id, Vector3.ZERO)
            var distance_sq : float = boid_position.distance_squared_to(planet_position)
            if distance_sq < best_planet_distance_sq:
                best_planet_distance_sq = distance_sq
                best_planet_id = planet_id
        i += 1
    return best_planet_id


func _is_enemy_count_alive() -> bool:
    var enemy_start : int = _friendly_slots_count()
    var enemy_index : int = enemy_start
    while enemy_index < MAX_NUMBER_OF_BOIDS:
        if _is_enemy_slot_index(enemy_index) and All_Entities_ENT[enemy_index] != 0:
            return true
        enemy_index += 1
    return false


func _run_friendly_boid_worker(delta: float) -> void:
    _physics_status_text = "friendly boid worker running"
    var has_any_enemy_alive : bool = _is_enemy_count_alive()
    if has_any_enemy_alive:
        _friendly_no_enemy_elapsed_seconds = 0.0
    else:
        _friendly_no_enemy_elapsed_seconds += delta

    var friendly_slots : int = _friendly_slots_count()
    var boid_index : int = 0
    while boid_index < friendly_slots:
        if _is_friendly_slot_index(boid_index) == false or All_Entities_ENT[boid_index] == 0:
            boid_index += 1
            continue

        var boid_transform : Transform3D = _get_boid_transform(boid_index)
        var boid_position : Vector3 = boid_transform.origin
        var boid_velocity : Vector3 = Velocities_COMP[boid_index]
        var boid_forward : Vector3 = _safe_normalised(boid_velocity)
        if boid_forward.length_squared() <= 0.000001:
            boid_forward = -boid_transform.basis.z
            boid_forward = _safe_normalised(boid_forward)

        var ammo_left : int = int(Ammo_COMP[boid_index])
        var has_ammo : bool = ammo_left > 0
        var steering_accumulator : Vector3 = Vector3.ZERO

        var separation_steer : Vector3 = _calc_separation_steer(boid_index, boid_position, true)
        steering_accumulator += separation_steer * 3.0

        var bounds_steer : Vector3 = _calc_bounds_steer(boid_position)
        steering_accumulator += bounds_steer * 5.5

        var planet_avoid_steer : Vector3 = _calc_planet_avoidance_steer(boid_position)
        steering_accumulator += planet_avoid_steer * 4.0

        if has_ammo:
            var recheck_timer : float = Target_Recheck_Timer_COMP[boid_index] - delta
            Target_Recheck_Timer_COMP[boid_index] = recheck_timer

            var target_enemy_index : int = int(Friendly_Target_Enemy_Boid[boid_index])
            var target_valid : bool = _is_valid_boid_index(target_enemy_index) and _is_enemy_slot_index(target_enemy_index) and All_Entities_ENT[target_enemy_index] != 0
            if target_valid == false or recheck_timer <= 0.0:
                target_enemy_index = _find_nearest_enemy_boid_for_friendly(boid_index, boid_position, boid_forward)
                Friendly_Target_Enemy_Boid[boid_index] = target_enemy_index
                Target_Recheck_Timer_COMP[boid_index] = max(target_recheck_seconds, 0.2)

            if _is_valid_boid_index(target_enemy_index) and _is_enemy_slot_index(target_enemy_index) and All_Entities_ENT[target_enemy_index] != 0:
                var target_enemy_position : Vector3 = _get_boid_transform(target_enemy_index, true).origin
                var to_enemy : Vector3 = target_enemy_position - boid_position
                var distance_to_enemy : float = max(to_enemy.length(), 0.000001)
                var desired_velocity_to_enemy : Vector3 = _safe_normalised(to_enemy) * max_speed
                steering_accumulator += _steer_towards(boid_velocity, desired_velocity_to_enemy) * 2.75

                if distance_to_enemy <= Friendly_Firing_Distance:
                    Fire_Bolt(boid_index)
            elif _friendly_no_enemy_elapsed_seconds >= 30.0 and _target_position_cache.has(-6):
                var enemy_mothership_position : Vector3 = _target_position_cache.get(-6, boid_position)
                var to_enemy_mothership : Vector3 = enemy_mothership_position - boid_position
                var desired_enemy_mothership_velocity : Vector3 = _safe_normalised(to_enemy_mothership) * max_speed
                steering_accumulator += _steer_towards(boid_velocity, desired_enemy_mothership_velocity) * 1.65
            else:
                var wander_steer_no_target : Vector3 = _compute_wander_steer(boid_index, boid_forward)
                steering_accumulator += wander_steer_no_target * 1.2

            Reload_Timer_COMP[boid_index] = 0.0
        else:
            Friendly_Target_Enemy_Boid[boid_index] = -1
            var friendly_mothership_position : Vector3 = _target_position_cache.get(-5, boid_position)
            var to_friendly_mothership : Vector3 = friendly_mothership_position - boid_position
            var distance_to_friendly_mothership : float = max(to_friendly_mothership.length(), 0.000001)

            var desired_speed_to_reload : float = max_speed
            if distance_to_friendly_mothership < arrive_slowing_distance:
                desired_speed_to_reload = max_speed * (distance_to_friendly_mothership / max(arrive_slowing_distance, 0.001))
            var desired_reload_velocity : Vector3 = _safe_normalised(to_friendly_mothership) * max(desired_speed_to_reload, 0.0)
            steering_accumulator += _steer_towards(boid_velocity, desired_reload_velocity) * 3.4

            if distance_to_friendly_mothership <= reload_distance:
                var reload_timer_value : float = Reload_Timer_COMP[boid_index] + delta
                Reload_Timer_COMP[boid_index] = reload_timer_value
                boid_velocity = boid_velocity.lerp(Vector3.ZERO, clampf(delta * 2.5, 0.0, 1.0))
                if reload_timer_value >= reload_time_required:
                    Ammo_COMP[boid_index] = clampi(Friendly_Ammo_Capacity, 0, 127)
                    Reload_Timer_COMP[boid_index] = 0.0
            else:
                Reload_Timer_COMP[boid_index] = 0.0

        var wander_steer : Vector3 = _compute_wander_steer(boid_index, boid_forward)
        steering_accumulator += wander_steer * 0.7

        var acceleration : Vector3 = _limit_magnitude(steering_accumulator, max_force) / max(mass, 0.001)
        boid_velocity += acceleration * delta
        boid_velocity = _limit_magnitude(boid_velocity, max_speed)
        if boid_velocity.length_squared() <= 0.000001:
            boid_velocity = boid_forward * min(max_speed, 0.3)

        Velocities_COMP[boid_index] = boid_velocity
        boid_position += boid_velocity * delta
        var new_transform : Transform3D = _compose_boid_transform(boid_position, boid_velocity)
        _set_boid_transform(boid_index, new_transform)
        boid_index += 1


func _run_enemy_boid_worker(delta: float) -> void:
    _physics_status_text = "enemy boid worker running"
    var first_enemy_index : int = _friendly_slots_count()
    var boid_index : int = first_enemy_index
    while boid_index < MAX_NUMBER_OF_BOIDS:
        if _is_enemy_slot_index(boid_index) == false or All_Entities_ENT[boid_index] == 0:
            boid_index += 1
            continue

        var boid_transform : Transform3D = _get_boid_transform(boid_index)
        var boid_position : Vector3 = boid_transform.origin
        var boid_velocity : Vector3 = Velocities_COMP[boid_index]
        var boid_forward : Vector3 = _safe_normalised(boid_velocity)
        if boid_forward.length_squared() <= 0.000001:
            boid_forward = -boid_transform.basis.z
            boid_forward = _safe_normalised(boid_forward)

        var steering_accumulator : Vector3 = Vector3.ZERO
        var separation_steer : Vector3 = _calc_separation_steer(boid_index, boid_position, true)
        var bounds_steer : Vector3 = _calc_bounds_steer(boid_position)
        var planet_avoid_steer : Vector3 = _calc_planet_avoidance_steer(boid_position)
        steering_accumulator += separation_steer * 2.5
        steering_accumulator += bounds_steer * 5.0

        var ammo_left : int = int(Ammo_COMP[boid_index])
        if ammo_left > 0:
            var recheck_timer : float = Target_Recheck_Timer_COMP[boid_index] - delta
            Target_Recheck_Timer_COMP[boid_index] = recheck_timer

            var planet_target_id : int = int(Enemy_Target_Planet_ID_COMP[boid_index])
            var target_valid : bool = _target_position_cache.has(planet_target_id)
            if target_valid == false or recheck_timer <= 0.0:
                planet_target_id = _pick_nearest_planet_target(boid_position)
                Enemy_Target_Planet_ID_COMP[boid_index] = planet_target_id
                Target_Recheck_Timer_COMP[boid_index] = max(target_recheck_seconds, 0.2)

            if _target_position_cache.has(planet_target_id):
                var planet_position : Vector3 = _target_position_cache.get(planet_target_id, boid_position)
                var planet_radius : float = float(_target_radius_cache.get(planet_target_id, 0.5))
                var to_planet : Vector3 = planet_position - boid_position
                var distance_to_planet_centre : float = max(to_planet.length(), 0.000001)
                var distance_to_planet_surface : float = max(distance_to_planet_centre - planet_radius, 0.0)

                var desired_planet_speed : float = max_speed * 0.75
                if distance_to_planet_surface < arrive_slowing_distance:
                    desired_planet_speed = max_speed * (distance_to_planet_surface / max(arrive_slowing_distance, 0.001))
                var desired_planet_velocity : Vector3 = _safe_normalised(to_planet) * max(desired_planet_speed, 0.0)

                steering_accumulator += _steer_towards(boid_velocity, desired_planet_velocity) * 2.2
                steering_accumulator += planet_avoid_steer * 1.35

                if distance_to_planet_surface <= Enemy_Firing_Distance:
                    Fire_Bolt(boid_index)

                if distance_to_planet_surface < max(planet_radius * 0.35, 0.6):
                    steering_accumulator += (-_safe_normalised(to_planet)) * 4.25
            else:
                var wander_without_planet : Vector3 = _compute_wander_steer(boid_index, boid_forward)
                steering_accumulator += wander_without_planet * 1.2

            Reload_Timer_COMP[boid_index] = 0.0
        else:
            Enemy_Target_Planet_ID_COMP[boid_index] = -1
            var enemy_mothership_position : Vector3 = _target_position_cache.get(-6, boid_position)
            var to_enemy_mothership : Vector3 = enemy_mothership_position - boid_position
            var distance_to_enemy_mothership : float = max(to_enemy_mothership.length(), 0.000001)

            var desired_enemy_reload_speed : float = max_speed
            if distance_to_enemy_mothership < arrive_slowing_distance:
                desired_enemy_reload_speed = max_speed * (distance_to_enemy_mothership / max(arrive_slowing_distance, 0.001))
            var desired_enemy_reload_velocity : Vector3 = _safe_normalised(to_enemy_mothership) * max(desired_enemy_reload_speed, 0.0)
            steering_accumulator += _steer_towards(boid_velocity, desired_enemy_reload_velocity) * 3.0

            if distance_to_enemy_mothership <= reload_distance:
                var enemy_reload_timer_value : float = Reload_Timer_COMP[boid_index] + delta
                Reload_Timer_COMP[boid_index] = enemy_reload_timer_value
                boid_velocity = boid_velocity.lerp(Vector3.ZERO, clampf(delta * 2.5, 0.0, 1.0))
                if enemy_reload_timer_value >= reload_time_required:
                    Ammo_COMP[boid_index] = clampi(Enemy_Ammo_Capacity, 0, 127)
                    Reload_Timer_COMP[boid_index] = 0.0
            else:
                Reload_Timer_COMP[boid_index] = 0.0

        var wander_steer : Vector3 = _compute_wander_steer(boid_index, boid_forward)
        steering_accumulator += wander_steer * 0.8

        var acceleration : Vector3 = _limit_magnitude(steering_accumulator, max_force) / max(mass, 0.001)
        boid_velocity += acceleration * delta
        boid_velocity = _limit_magnitude(boid_velocity, max_speed)
        if boid_velocity.length_squared() <= 0.000001:
            boid_velocity = boid_forward * min(max_speed, 0.3)

        Velocities_COMP[boid_index] = boid_velocity
        boid_position += boid_velocity * delta
        var new_transform : Transform3D = _compose_boid_transform(boid_position, boid_velocity)
        _set_boid_transform(boid_index, new_transform)

        boid_index += 1


func _run_bolt_worker(delta: float, for_friendly_bolts: bool) -> void:
    var bolts_velocity_comp : PackedVector4Array = Friendly_Bolts_Velocities_COMP if for_friendly_bolts else Enemy_Bolts_Velocities_COMP
    if bolts_velocity_comp.is_empty():
        return

    var active_bolt_transforms : PackedVector3Array = _get_active_bolt_transforms_buffer(for_friendly_bolts)
    var slot_index : int = 0
    while slot_index < bolts_velocity_comp.size():
        var bolt_data : Vector4 = bolts_velocity_comp[slot_index]
        if bolt_data.w >= 0.0:
            bolt_data.w += delta
            var origin_index : int = (slot_index * 4) + 3
            if origin_index < active_bolt_transforms.size():
                var bolt_origin : Vector3 = active_bolt_transforms[origin_index]
                bolt_origin += Vector3(bolt_data.x, bolt_data.y, bolt_data.z) * delta
                active_bolt_transforms[origin_index] = bolt_origin
            bolts_velocity_comp[slot_index] = bolt_data
        slot_index += 1

    if for_friendly_bolts:
        Friendly_Bolts_Velocities_COMP = bolts_velocity_comp
    else:
        Enemy_Bolts_Velocities_COMP = bolts_velocity_comp
    _set_active_bolt_transforms_buffer(for_friendly_bolts, active_bolt_transforms)
    Retire_old_Bolt(for_friendly_bolts)
 

## TODO: Get the current transform of the boid who fired, get its velocity, 
## try find if it has any bolts fired already. if we're checking boid #100, 
## and anything above #90 is an enemy usually, first normalise 100 to 10 using Normalise_Enemy_Boid_index(),
## Then see if we can find bolt[0], bolt[1], bolt[2], bolt[3] etc... (depending on what Friendly_Fire_Rate/Enemy_Fire_Rate 
## and what All_Bolts_Lifetimes is) if the smallest of those bolts has the W component of their Vector4 greater than the fire_rate, and is not == 0,
## we then find the bolt with the largest W and check if it's greater than the bolt_lifetime which it should be... we then reuse that bolt slot 
## we then know enough time has passed and we can fire off another shot. if all bolts have a W of 0 then we can fire immeditaely.
## if we want to fire, and the 
func Fire_Bolt(Which_boid_is_Firing : int) -> bool:
    if _is_valid_boid_index(Which_boid_is_Firing) == false:
        return false
    if Get_Boid_State(Which_boid_is_Firing) == E_Boid_State.DEAD:
        return false
    if Ammo_COMP.get(Which_boid_is_Firing) <= 0:
        return false

    var is_friendly : bool = is_friendly_boid(Which_boid_is_Firing)
    var fire_rate : float = Friendly_Fire_Rate if is_friendly else Enemy_Fire_Rate
    var firing_speed : float = Friendly_Firing_Starting_Speed if is_friendly else Enemy_Firing_Starting_Speed
    var bolts_per_boid : int = _get_bolts_per_boid(is_friendly)

    var owner_boid_local_index : int = Which_boid_is_Firing
    if is_friendly == false:
        owner_boid_local_index = Normalise_Enemy_Boid_index(Which_boid_is_Firing)

    var first_bolt_slot : int = owner_boid_local_index * bolts_per_boid
    var last_bolt_slot_exclusive : int = first_bolt_slot + bolts_per_boid
    var bolts_velocity_comp : PackedVector4Array = Friendly_Bolts_Velocities_COMP if is_friendly else Enemy_Bolts_Velocities_COMP

    if first_bolt_slot < 0 or first_bolt_slot >= bolts_velocity_comp.size():
        return false
    if last_bolt_slot_exclusive > bolts_velocity_comp.size():
        last_bolt_slot_exclusive = bolts_velocity_comp.size()
        if last_bolt_slot_exclusive <= first_bolt_slot:
            return false

    var selected_slot_index : int = -1
    var slot_index : int = first_bolt_slot
    while slot_index < last_bolt_slot_exclusive:
        var slot_age : float = bolts_velocity_comp[slot_index].w
        if _is_bolt_slot_inactive(slot_age):
            selected_slot_index = slot_index
            break
        slot_index += 1

    if selected_slot_index == -1:
        var smallest_active_age : float = INF
        var smallest_active_age_slot : int = -1
        slot_index = first_bolt_slot
        while slot_index < last_bolt_slot_exclusive:
            var active_age : float = bolts_velocity_comp[slot_index].w
            if active_age < smallest_active_age:
                smallest_active_age = active_age
                smallest_active_age_slot = slot_index
            slot_index += 1

        if smallest_active_age_slot == -1:
            return false
        if smallest_active_age <= fire_rate:
            return false
        if is_zero_approx(smallest_active_age):
            return false

        selected_slot_index = smallest_active_age_slot

    var boid_velocity : Vector3 = Velocities_COMP[Which_boid_is_Firing]
    var boid_transform : Transform3D = _get_boid_transform(Which_boid_is_Firing)
    var bolt_spawn_origin : Vector3 = boid_transform.origin
    var bolt_velocity : Vector3 = boid_velocity * firing_speed
    bolts_velocity_comp[selected_slot_index] = Vector4(bolt_velocity.x, bolt_velocity.y, bolt_velocity.z, 0.0)
    _set_bolt_transform_slot(selected_slot_index, is_friendly, bolt_spawn_origin, ACTIVE_BOLT_SCALE, true, true)

    if is_friendly:
        Friendly_Bolts_Velocities_COMP = bolts_velocity_comp
    else:
        Enemy_Bolts_Velocities_COMP = bolts_velocity_comp

    var ammo_left : int = Ammo_COMP.get(Which_boid_is_Firing) - 1
    ammo_left = max(0, ammo_left)
    Ammo_COMP.set(Which_boid_is_Firing, ammo_left)
    return true
               
          
## TODO: When a Bolt has been fired over All_Bolts_Lifetimes seconds ago, it must be retired.
## Because we're dealing with Transform3D for our multmesh, and we're updating them via packedVector3array,
## an old retired bolt should continue on it's trajectory for a frame but then have it's scale set to 0.00001 
## because we'll be lerping from one buffer to another. an active bolt will have a scale of 1, 
## and a W component of less than All_Bolts_Lifetimes
func Retire_old_Bolt(do_friendly_bolts : bool) -> void:
    if do_friendly_bolts:
        var friendly_slot_index : int = 0
        while friendly_slot_index < Friendly_Bolts_Velocities_COMP.size():
            var friendly_bolt_data : Vector4 = Friendly_Bolts_Velocities_COMP[friendly_slot_index]
            var friendly_bolt_age : float = friendly_bolt_data.w
            if friendly_bolt_age > All_Bolts_Lifetimes:
                var friendly_bolt_origin : Vector3 = _get_bolt_origin(friendly_slot_index, true, _use_current_buffer_this_frame)
                _set_bolt_transform_slot(friendly_slot_index, true, friendly_bolt_origin, RETIRED_BOLT_SCALE, _use_current_buffer_this_frame, false)
                _set_bolt_transform_slot(friendly_slot_index, true, friendly_bolt_origin, ACTIVE_BOLT_SCALE, false, not _use_current_buffer_this_frame)
                friendly_bolt_data.w = RETIRED_BOLT_W
                Friendly_Bolts_Velocities_COMP[friendly_slot_index] = friendly_bolt_data
            friendly_slot_index += 1

    else:
        var enemy_slot_index : int = 0
        while enemy_slot_index < Enemy_Bolts_Velocities_COMP.size():
            var enemy_bolt_data : Vector4 = Enemy_Bolts_Velocities_COMP[enemy_slot_index]
            var enemy_bolt_age : float = enemy_bolt_data.w
            if enemy_bolt_age > All_Bolts_Lifetimes:
                var enemy_bolt_origin : Vector3 = _get_bolt_origin(enemy_slot_index, false, _use_current_buffer_this_frame)
                _set_bolt_transform_slot(enemy_slot_index, false, enemy_bolt_origin, RETIRED_BOLT_SCALE, _use_current_buffer_this_frame, false)
                _set_bolt_transform_slot(enemy_slot_index, false, enemy_bolt_origin, ACTIVE_BOLT_SCALE, false, not _use_current_buffer_this_frame)
                enemy_bolt_data.w = RETIRED_BOLT_W
                Enemy_Bolts_Velocities_COMP[enemy_slot_index] = enemy_bolt_data
            enemy_slot_index += 1

  
func _emit_boid_destroyed_particles(hit_position: Vector3) -> void:
    var particles_node : Node = get_node_or_null("Boid_Explosion_Particles")
    if particles_node == null:
        particles_node = get_node_or_null("Ships Canons Particles")
    if particles_node is GPUParticles3D:
        var particles : GPUParticles3D = particles_node as GPUParticles3D
        particles.global_position = hit_position
        particles.restart()
        particles.emitting = true


func _respawn_boid_after_timer(boid_index: int, should_be_friendly: bool) -> void:
    if _is_valid_boid_index(boid_index) == false:
        return
    if All_Entities_ENT.get(boid_index) != 0:
        return
    if should_be_friendly and _can_spawn_friendly() == false:
        return
    if should_be_friendly == false and _can_spawn_enemy() == false:
        return

    var spawn_point : Node3D = Friendly_Spawn_Point if should_be_friendly else Enemy_Spawn_Point
    if spawn_point == null:
        return

    var spawn_transform : Transform3D = Transform3D.IDENTITY
    spawn_transform.origin = spawn_point.global_position
    _set_boid_transform(boid_index, spawn_transform)

    var signed_health : int = DEFAULT_BOID_HEALTH if should_be_friendly else -DEFAULT_BOID_HEALTH
    All_Entities_ENT.set(boid_index, signed_health)

    var ammo_amount : int = Friendly_Ammo_Capacity if should_be_friendly else Enemy_Ammo_Capacity
    ammo_amount = clampi(ammo_amount, 0, 127)
    Ammo_COMP.set(boid_index, ammo_amount)
    Friendly_Target_Enemy_Boid[boid_index] = -1
    Enemy_Target_Planet_ID_COMP[boid_index] = -1
    Target_Recheck_Timer_COMP[boid_index] = 0.0
    Reload_Timer_COMP[boid_index] = 0.0

    var seeded_velocity : Vector3 = Vector3(
        randf_range(-0.1, 0.1),
        randf_range(-0.1, 0.1),
        randf_range(-1.0, -0.2)
    )
    Velocities_COMP.set(boid_index, seeded_velocity)




static func Get_Old_Boid_Buffer(get_friendly_boid_buffer : bool) -> PackedVector3Array:
    if Boid_Manager_Instance._use_current_buffer_this_frame:
        if get_friendly_boid_buffer:
            return Boid_Manager_Instance._previous_friendly_transforms_buffer
        else:
            return Boid_Manager_Instance._previous_enemy_transforms_buffer
    else:
        if get_friendly_boid_buffer:
            return Boid_Manager_Instance._current_friendly_transforms_buffer
        else:
            return Boid_Manager_Instance._current_enemy_transforms_buffer



func Get_Boid_State(Which_Boid_ENT : int) -> E_Boid_State:
    if Which_Boid_ENT < 0 and Which_Boid_ENT >= -6:
        return E_Boid_State.OTHER
        
    elif All_Entities_ENT.get(Which_Boid_ENT) < 0:
        return E_Boid_State.ENEMY
        
    elif All_Entities_ENT.get(Which_Boid_ENT) > 0:
        return E_Boid_State.FRIENDLY
        
    else:
        return E_Boid_State.DEAD



## Cause a little explosion at All_Entities_ENT[i].position
func on_boid_destroyed(Which_Boid_ENT : int):
    if _is_valid_boid_index(Which_Boid_ENT) == false:
        return

    var boid_state : E_Boid_State = Get_Boid_State(Which_Boid_ENT)
    if boid_state != E_Boid_State.FRIENDLY and boid_state != E_Boid_State.ENEMY:
        return

    var dead_transform : Transform3D = _get_boid_transform(Which_Boid_ENT, true)
    _emit_boid_destroyed_particles(dead_transform.origin)

    var hide_transform : Transform3D = dead_transform
    hide_transform.origin = Vector3(-999999.0, -999999.0, -999999.0)
    _set_boid_transform(Which_Boid_ENT, hide_transform)
    Velocities_COMP.set(Which_Boid_ENT, Vector3.ZERO)
    Ammo_COMP.set(Which_Boid_ENT, 0)

    var respawn_delay : float = Friendly_Respawn_Time if boid_state == E_Boid_State.FRIENDLY else Enemy_Respawn_Time
    var respawn_timer : SceneTreeTimer = get_tree().create_timer(max(respawn_delay, 0.01))
    var should_be_friendly : bool = boid_state == E_Boid_State.FRIENDLY
    respawn_timer.timeout.connect(_respawn_boid_after_timer.bind(Which_Boid_ENT, should_be_friendly))
    
    

    
    
## Apply Damage to either a boid or a Planet / Ship
func Apply_Damage_SYS(Which_Boid_ENT : int, Damage : int):
    var new_health = All_Entities_ENT.get(Which_Boid_ENT)
    if Get_Boid_State(Which_Boid_ENT) == E_Boid_State.FRIENDLY:
        new_health -= Damage
        if new_health <= 0:
            on_boid_destroyed(Which_Boid_ENT)
            All_Entities_ENT.set(Which_Boid_ENT, 0)
        else:
            All_Entities_ENT.set(Which_Boid_ENT, new_health)
    elif Get_Boid_State(Which_Boid_ENT) == E_Boid_State.ENEMY:
        new_health += Damage
        if new_health >= 0:
            on_boid_destroyed(Which_Boid_ENT)
            All_Entities_ENT.set(Which_Boid_ENT, 0)
        else:
            All_Entities_ENT.set(Which_Boid_ENT, new_health)
    
    elif Get_Boid_State(Which_Boid_ENT) == E_Boid_State.OTHER:
        var new_target : Damageable = targets_index.get(Which_Boid_ENT)
        new_target.Apply_Damage(float(Damage))
        
 


func _friendly_boid_thread_loop() -> void:
    while true:
        _friendly_boid_wake_semaphore.wait()
        if _worker_exit_requested:
            _friendly_boid_done_semaphore.post()
            return
        _run_friendly_boid_worker(_friendly_boid_worker_delta)
        _friendly_boid_done_semaphore.post()


func _enemy_boid_thread_loop() -> void:
    while true:
        _enemy_boid_wake_semaphore.wait()
        if _worker_exit_requested:
            _enemy_boid_done_semaphore.post()
            return
        _run_enemy_boid_worker(_enemy_boid_worker_delta)
        _enemy_boid_done_semaphore.post()


func _friendly_bolt_thread_loop() -> void:
    while true:
        _friendly_bolt_wake_semaphore.wait()
        if _worker_exit_requested:
            _friendly_bolt_done_semaphore.post()
            return
        _run_bolt_worker(_friendly_bolt_worker_delta, true)
        _friendly_bolt_done_semaphore.post()


func _enemy_bolt_thread_loop() -> void:
    while true:
        _enemy_bolt_wake_semaphore.wait()
        if _worker_exit_requested:
            _enemy_bolt_done_semaphore.post()
            return
        _run_bolt_worker(_enemy_bolt_worker_delta, false)
        _enemy_bolt_done_semaphore.post()


func _start_worker_threads() -> void:
    _worker_exit_requested = false
    FRIENDLY_BOID_MANAGER_THREAD = Thread.new()
    ENEMY_BOID_MANAGER_THREAD = Thread.new()
    FRIENDLY_BOID_BOLT_MANAGER_THREAD = Thread.new()
    ENEMY_BOID_BOLT_MANAGER_THREAD = Thread.new()
    FRIENDLY_BOID_MANAGER_THREAD.start(_friendly_boid_thread_loop)
    ENEMY_BOID_MANAGER_THREAD.start(_enemy_boid_thread_loop)
    FRIENDLY_BOID_BOLT_MANAGER_THREAD.start(_friendly_bolt_thread_loop)
    ENEMY_BOID_BOLT_MANAGER_THREAD.start(_enemy_bolt_thread_loop)


func _stop_worker_threads() -> void:
    if FRIENDLY_BOID_MANAGER_THREAD == null:
        return
    _worker_exit_requested = true
    _friendly_boid_wake_semaphore.post()
    _enemy_boid_wake_semaphore.post()
    _friendly_bolt_wake_semaphore.post()
    _enemy_bolt_wake_semaphore.post()

    _friendly_boid_done_semaphore.wait()
    _enemy_boid_done_semaphore.wait()
    _friendly_bolt_done_semaphore.wait()
    _enemy_bolt_done_semaphore.wait()

    if FRIENDLY_BOID_MANAGER_THREAD.is_started():
        FRIENDLY_BOID_MANAGER_THREAD.wait_to_finish()
    if ENEMY_BOID_MANAGER_THREAD.is_started():
        ENEMY_BOID_MANAGER_THREAD.wait_to_finish()
    if FRIENDLY_BOID_BOLT_MANAGER_THREAD.is_started():
        FRIENDLY_BOID_BOLT_MANAGER_THREAD.wait_to_finish()
    if ENEMY_BOID_BOLT_MANAGER_THREAD.is_started():
        ENEMY_BOID_BOLT_MANAGER_THREAD.wait_to_finish()

    FRIENDLY_BOID_MANAGER_THREAD = null
    ENEMY_BOID_MANAGER_THREAD = null
    FRIENDLY_BOID_BOLT_MANAGER_THREAD = null
    ENEMY_BOID_BOLT_MANAGER_THREAD = null


func _dispatch_workers(delta: float) -> void:
    _friendly_boid_worker_delta = delta
    _enemy_boid_worker_delta = delta
    _friendly_bolt_worker_delta = delta
    _enemy_bolt_worker_delta = delta

    _friendly_boid_wake_semaphore.post()
    _enemy_boid_wake_semaphore.post()
    _friendly_bolt_wake_semaphore.post()
    _enemy_bolt_wake_semaphore.post()

    _friendly_boid_done_semaphore.wait()
    _enemy_boid_done_semaphore.wait()
    _friendly_bolt_done_semaphore.wait()
    _enemy_bolt_done_semaphore.wait()


func _exit_tree() -> void:
    _stop_worker_threads()


func _ready() -> void:
    Boid_Manager_Instance = self
    All_Entities_ENT = PackedByteArray()
    Ammo_COMP = PackedByteArray()
    Friendly_Target_Enemy_Boid = PackedInt32Array()
    Enemy_Target_Planet_ID_COMP = PackedInt32Array()
    Target_Recheck_Timer_COMP = PackedFloat32Array()
    Reload_Timer_COMP = PackedFloat32Array()
    Velocities_COMP = PackedVector3Array()
    Friendly_Bolts_Velocities_COMP = PackedVector4Array()
    Enemy_Bolts_Velocities_COMP = PackedVector4Array()
    
    _initisalise_multmeshes()
    _initisalise_packed_arrays()
    _start_worker_threads()

    
    
    
func _initisalise_multmeshes():
    Friendly_MultiMesh.multimesh.mesh = Friendly_Ship_Mesh.mesh
    Friendly_MultiMesh.multimesh.instance_count = _friendly_slots_count()
    Friendly_MultiMesh.multimesh.visible_instance_count = _friendly_slots_count()
    
    Enemy_MultiMesh.multimesh.mesh = Enemy_Ship_Mesh.mesh
    Enemy_MultiMesh.multimesh.instance_count = _enemy_slots_count()
    Enemy_MultiMesh.multimesh.visible_instance_count = _enemy_slots_count()
    

    
    
    
    
    
func _initisalise_packed_arrays():
    All_Entities_ENT.resize(MAX_NUMBER_OF_BOIDS)
    All_Entities_ENT.fill(0) # Everyone starts as DEAD
    
    Ammo_COMP.resize(MAX_NUMBER_OF_BOIDS)
    Ammo_COMP.fill(0)

    Friendly_Target_Enemy_Boid.resize(MAX_NUMBER_OF_BOIDS)
    Friendly_Target_Enemy_Boid.fill(-1)

    Enemy_Target_Planet_ID_COMP.resize(MAX_NUMBER_OF_BOIDS)
    Enemy_Target_Planet_ID_COMP.fill(-1)

    Target_Recheck_Timer_COMP.resize(MAX_NUMBER_OF_BOIDS)
    Target_Recheck_Timer_COMP.fill(0.0)

    Reload_Timer_COMP.resize(MAX_NUMBER_OF_BOIDS)
    Reload_Timer_COMP.fill(0.0)
    
    Velocities_COMP.resize(MAX_NUMBER_OF_BOIDS)
    Velocities_COMP.fill(Vector3.ZERO)
    
    # How many bolts can a friendly fire before the All_Bolts_Lifetimes timer is up?
    var friendly_bolts_num = int(MAX_NUMBER_OF_BOIDS * Friendly_Enemy_Count_Ratio)
    friendly_bolts_num = friendly_bolts_num * (All_Bolts_Lifetimes / Friendly_Fire_Rate) 
    
    var enemy_bolts_num = MAX_NUMBER_OF_BOIDS - int(MAX_NUMBER_OF_BOIDS * Friendly_Enemy_Count_Ratio)
    enemy_bolts_num = enemy_bolts_num * (All_Bolts_Lifetimes / Enemy_Fire_Rate)
    
    Friendly_Bolts_Velocities_COMP.resize(friendly_bolts_num)
    Friendly_Bolts_Velocities_COMP.fill(Vector4(0.0, 0.0, 0.0, RETIRED_BOLT_W))
    
    Enemy_Bolts_Velocities_COMP.resize(enemy_bolts_num)
    Enemy_Bolts_Velocities_COMP.fill(Vector4(0.0, 0.0, 0.0, RETIRED_BOLT_W))

    Friendly_Bolts_MultiMesh.multimesh.instance_count = friendly_bolts_num
    Friendly_Bolts_MultiMesh.multimesh.visible_instance_count = friendly_bolts_num
    Enemy_Bolts_MultiMesh.multimesh.instance_count = enemy_bolts_num
    Enemy_Bolts_MultiMesh.multimesh.visible_instance_count = enemy_bolts_num


    var retired_basis_x : Vector3 = Vector3(RETIRED_BOLT_SCALE, 0.0, 0.0)
    var retired_basis_y : Vector3 = Vector3(0.0, RETIRED_BOLT_SCALE, 0.0)
    var retired_basis_z : Vector3 = Vector3(0.0, 0.0, RETIRED_BOLT_SCALE)
    var hidden_origin : Vector3 = Vector3(-999999.0, -999999.0, -999999.0)

    _current_friendly_bolts_transforms_buffer.resize(friendly_bolts_num * 4)
    _previous_friendly_bolts_transforms_buffer.resize(friendly_bolts_num * 4)
    var friendly_slot_index : int = 0
    while friendly_slot_index < friendly_bolts_num:
        var friendly_base_index : int = friendly_slot_index * 4
        _current_friendly_bolts_transforms_buffer[friendly_base_index + 0] = retired_basis_x
        _current_friendly_bolts_transforms_buffer[friendly_base_index + 1] = retired_basis_y
        _current_friendly_bolts_transforms_buffer[friendly_base_index + 2] = retired_basis_z
        _current_friendly_bolts_transforms_buffer[friendly_base_index + 3] = hidden_origin
        _previous_friendly_bolts_transforms_buffer[friendly_base_index + 0] = retired_basis_x
        _previous_friendly_bolts_transforms_buffer[friendly_base_index + 1] = retired_basis_y
        _previous_friendly_bolts_transforms_buffer[friendly_base_index + 2] = retired_basis_z
        _previous_friendly_bolts_transforms_buffer[friendly_base_index + 3] = hidden_origin
        friendly_slot_index += 1

    _current_enemy_bolts_transforms_buffer.resize(enemy_bolts_num * 4)
    _previous_enemy_bolts_transforms_buffer.resize(enemy_bolts_num * 4)
    var enemy_slot_index : int = 0
    while enemy_slot_index < enemy_bolts_num:
        var enemy_base_index : int = enemy_slot_index * 4
        _current_enemy_bolts_transforms_buffer[enemy_base_index + 0] = retired_basis_x
        _current_enemy_bolts_transforms_buffer[enemy_base_index + 1] = retired_basis_y
        _current_enemy_bolts_transforms_buffer[enemy_base_index + 2] = retired_basis_z
        _current_enemy_bolts_transforms_buffer[enemy_base_index + 3] = hidden_origin
        _previous_enemy_bolts_transforms_buffer[enemy_base_index + 0] = retired_basis_x
        _previous_enemy_bolts_transforms_buffer[enemy_base_index + 1] = retired_basis_y
        _previous_enemy_bolts_transforms_buffer[enemy_base_index + 2] = retired_basis_z
        _previous_enemy_bolts_transforms_buffer[enemy_base_index + 3] = hidden_origin
        enemy_slot_index += 1
    
    var friendly_boid_count : int = _friendly_slots_count()
    _current_friendly_transforms_buffer.resize(friendly_boid_count * 4)
    _previous_friendly_transforms_buffer.resize(friendly_boid_count * 4)
    var friendly_boid_index : int = 0
    while friendly_boid_index < friendly_boid_count:
        var friendly_base_index : int = friendly_boid_index * 4
        _current_friendly_transforms_buffer[friendly_base_index + 0] = Vector3.RIGHT
        _current_friendly_transforms_buffer[friendly_base_index + 1] = Vector3.UP
        _current_friendly_transforms_buffer[friendly_base_index + 2] = Vector3.BACK
        _current_friendly_transforms_buffer[friendly_base_index + 3] = hidden_origin
        _previous_friendly_transforms_buffer[friendly_base_index + 0] = Vector3.RIGHT
        _previous_friendly_transforms_buffer[friendly_base_index + 1] = Vector3.UP
        _previous_friendly_transforms_buffer[friendly_base_index + 2] = Vector3.BACK
        _previous_friendly_transforms_buffer[friendly_base_index + 3] = hidden_origin
        friendly_boid_index += 1

    var enemy_boid_count : int = _enemy_slots_count()
    _current_enemy_transforms_buffer.resize(enemy_boid_count * 4)
    _previous_enemy_transforms_buffer.resize(enemy_boid_count * 4)
    var enemy_boid_index : int = 0
    while enemy_boid_index < enemy_boid_count:
        var enemy_base_index : int = enemy_boid_index * 4
        _current_enemy_transforms_buffer[enemy_base_index + 0] = Vector3.RIGHT
        _current_enemy_transforms_buffer[enemy_base_index + 1] = Vector3.UP
        _current_enemy_transforms_buffer[enemy_base_index + 2] = Vector3.BACK
        _current_enemy_transforms_buffer[enemy_base_index + 3] = hidden_origin
        _previous_enemy_transforms_buffer[enemy_base_index + 0] = Vector3.RIGHT
        _previous_enemy_transforms_buffer[enemy_base_index + 1] = Vector3.UP
        _previous_enemy_transforms_buffer[enemy_base_index + 2] = Vector3.BACK
        _previous_enemy_transforms_buffer[enemy_base_index + 3] = hidden_origin
        enemy_boid_index += 1
    
    
    
## Check how many friendly entities we have, if we have 100 boids, 
## a 50/50 friendly enemy split, and a friendly pool size of 0.5, 
## is there less than 25 friendly boid active? or are we at capacity? 
func _can_spawn_friendly() -> bool:
    var active_friendlies : int = 0
    var friendly_slots : int = _friendly_slots_count()
    var boid_index : int = 0
    while boid_index < friendly_slots:
        if All_Entities_ENT.get(boid_index) > 0:
            active_friendlies += 1
            if active_friendlies >= _friendly_pool_cap():
                return false
        boid_index += 1
    return true


func Spawn_Friendly_Boid() -> bool:
    var friendly_slot_count : int = _friendly_slots_count()
    if friendly_slot_count <= 0:
        return false

    var free_friendly_index : int = -1
    var boid_index : int = 0
    while boid_index < friendly_slot_count:
        if All_Entities_ENT[boid_index] == 0:
            free_friendly_index = boid_index
            break
        boid_index += 1

    if free_friendly_index == -1:
        return false

    var spawn_transform : Transform3D = Transform3D.IDENTITY
    var spawn_origin : Vector3 = Friendly_Spawn_Point.global_position if Friendly_Spawn_Point != null else Vector3.ZERO
    spawn_transform.origin = spawn_origin

    var friendly_mothership_damageable : Damageable = targets_index.get(-5, null)
    if friendly_mothership_damageable != null and friendly_mothership_damageable is Node3D:
        var friendly_mothership_node : Node3D = friendly_mothership_damageable as Node3D
        spawn_transform.basis = friendly_mothership_node.global_basis
    elif Friendly_Spawn_Point != null:
        spawn_transform.basis = Friendly_Spawn_Point.global_basis

    var transform_base_index : int = free_friendly_index * 4
    if (transform_base_index + 3) < _current_friendly_transforms_buffer.size():
        _current_friendly_transforms_buffer[transform_base_index + 0] = spawn_transform.basis.x
        _current_friendly_transforms_buffer[transform_base_index + 1] = spawn_transform.basis.y
        _current_friendly_transforms_buffer[transform_base_index + 2] = spawn_transform.basis.z
        _current_friendly_transforms_buffer[transform_base_index + 3] = spawn_transform.origin
    if (transform_base_index + 3) < _previous_friendly_transforms_buffer.size():
        _previous_friendly_transforms_buffer[transform_base_index + 0] = spawn_transform.basis.x
        _previous_friendly_transforms_buffer[transform_base_index + 1] = spawn_transform.basis.y
        _previous_friendly_transforms_buffer[transform_base_index + 2] = spawn_transform.basis.z
        _previous_friendly_transforms_buffer[transform_base_index + 3] = spawn_transform.origin

    All_Entities_ENT[free_friendly_index] = DEFAULT_BOID_HEALTH
    Ammo_COMP[free_friendly_index] = clampi(Friendly_Ammo_Capacity, 0, 127)
    Friendly_Target_Enemy_Boid[free_friendly_index] = -1
    Enemy_Target_Planet_ID_COMP[free_friendly_index] = -1
    Target_Recheck_Timer_COMP[free_friendly_index] = 0.0
    Reload_Timer_COMP[free_friendly_index] = 0.0

    var initial_velocity_direction : Vector3 = Vector3.UP if randf() >= 0.5 else Vector3.DOWN
    Velocities_COMP[free_friendly_index] = initial_velocity_direction
    return true


func Spawn_Enemy_Boid() -> bool:
    var first_enemy_index : int = _friendly_slots_count()
    var enemy_slot_count : int = _enemy_slots_count()
    if enemy_slot_count <= 0:
        return false

    var free_enemy_index : int = -1
    var boid_index : int = first_enemy_index
    while boid_index < MAX_NUMBER_OF_BOIDS:
        if All_Entities_ENT[boid_index] == 0:
            free_enemy_index = boid_index
            break
        boid_index += 1

    if free_enemy_index == -1:
        return false

    var spawn_transform : Transform3D = Transform3D.IDENTITY
    var spawn_origin : Vector3 = Enemy_Spawn_Point.global_position if Enemy_Spawn_Point != null else Vector3.ZERO
    spawn_transform.origin = spawn_origin

    var enemy_mothership_damageable : Damageable = targets_index.get(-6, null)
    if enemy_mothership_damageable != null and enemy_mothership_damageable is Node3D:
        var enemy_mothership_node : Node3D = enemy_mothership_damageable as Node3D
        spawn_transform.basis = enemy_mothership_node.global_basis
    elif Enemy_Spawn_Point != null:
        spawn_transform.basis = Enemy_Spawn_Point.global_basis

    var enemy_local_index : int = Normalise_Enemy_Boid_index(free_enemy_index)
    var transform_base_index : int = enemy_local_index * 4
    if (transform_base_index + 3) < _current_enemy_transforms_buffer.size():
        _current_enemy_transforms_buffer[transform_base_index + 0] = spawn_transform.basis.x
        _current_enemy_transforms_buffer[transform_base_index + 1] = spawn_transform.basis.y
        _current_enemy_transforms_buffer[transform_base_index + 2] = spawn_transform.basis.z
        _current_enemy_transforms_buffer[transform_base_index + 3] = spawn_transform.origin
    if (transform_base_index + 3) < _previous_enemy_transforms_buffer.size():
        _previous_enemy_transforms_buffer[transform_base_index + 0] = spawn_transform.basis.x
        _previous_enemy_transforms_buffer[transform_base_index + 1] = spawn_transform.basis.y
        _previous_enemy_transforms_buffer[transform_base_index + 2] = spawn_transform.basis.z
        _previous_enemy_transforms_buffer[transform_base_index + 3] = spawn_transform.origin

    All_Entities_ENT[free_enemy_index] = -DEFAULT_BOID_HEALTH
    Ammo_COMP[free_enemy_index] = clampi(Enemy_Ammo_Capacity, 0, 127)
    Friendly_Target_Enemy_Boid[free_enemy_index] = -1
    Enemy_Target_Planet_ID_COMP[free_enemy_index] = -1
    Target_Recheck_Timer_COMP[free_enemy_index] = 0.0
    Reload_Timer_COMP[free_enemy_index] = 0.0

    var initial_velocity_direction : Vector3 = Vector3.UP if randf() >= 0.5 else Vector3.DOWN
    Velocities_COMP[free_enemy_index] = initial_velocity_direction
    return true



## Check how many friendly entities we have, if we have 100 boids, 
## a 50/50 friendly enemy split, and a friendly pool size of 0.5, 
## is there less than 25 friendly boid active? or are we at capacity? 
func _can_spawn_enemy() -> bool:
    var active_enemies : int = 0
    var first_enemy_index : int = _friendly_slots_count()
    var boid_index : int = first_enemy_index
    while boid_index < MAX_NUMBER_OF_BOIDS:
        if All_Entities_ENT.get(boid_index) < 0:
            active_enemies += 1
            if active_enemies >= _enemy_pool_cap():
                return false
        boid_index += 1
    return true


func _get_mesh_radius_world(mesh_instance: MeshInstance3D) -> float:
    if mesh_instance == null:
        return 0.5
    if mesh_instance.mesh == null:
        return 0.5

    if mesh_instance.mesh is SphereMesh:
        var sphere_mesh : SphereMesh = mesh_instance.mesh as SphereMesh
        return max(0.05, sphere_mesh.radius)

    var mesh_aabb : AABB = mesh_instance.mesh.get_aabb()
    var max_extent : float = max(mesh_aabb.size.x, max(mesh_aabb.size.y, mesh_aabb.size.z))
    return max(0.05, (max_extent * 0.5))


func _estimate_damageable_hit_radius(target_damageable: Damageable) -> float:
    if target_damageable == null:
        return 0.5
    
    if target_damageable.has_method("Get_Mesh"):
        if target_damageable.Get_Mesh() != null:
            return _get_mesh_radius_world(target_damageable.Get_Mesh())
            
    var target_node : Node3D = target_damageable as Node3D
    if target_node == null:
        return 0.5

    var best_radius : float = 0.5
    for child in target_node.get_children():
        if child is MeshInstance3D:
            var child_mesh : MeshInstance3D = child as MeshInstance3D
            var child_radius : float = _get_mesh_radius_world(child_mesh)
            var child_offset : float = target_node.global_position.distance_to(child_mesh.global_position)
            best_radius = max(best_radius, child_radius + child_offset)

    return best_radius


func _get_enemy_bolts_transform_buffer() -> PackedVector3Array:
    if _use_current_buffer_this_frame:
        return _current_enemy_bolts_transforms_buffer
    return _previous_enemy_bolts_transforms_buffer


func _get_friendly_bolts_transform_buffer() -> PackedVector3Array:
    if _use_current_buffer_this_frame:
        return _current_friendly_bolts_transforms_buffer
    return _previous_friendly_bolts_transforms_buffer


func _set_enemy_bolt_slot_inactive(slot_index: int) -> void:
    if slot_index < 0 or slot_index >= Enemy_Bolts_Velocities_COMP.size():
        return
    var slot_velocity : Vector4 = Enemy_Bolts_Velocities_COMP[slot_index]
    slot_velocity.w = RETIRED_BOLT_W
    Enemy_Bolts_Velocities_COMP[slot_index] = slot_velocity


func _set_friendly_bolt_slot_inactive(slot_index: int) -> void:
    if slot_index < 0 or slot_index >= Friendly_Bolts_Velocities_COMP.size():
        return
    var slot_velocity : Vector4 = Friendly_Bolts_Velocities_COMP[slot_index]
    slot_velocity.w = RETIRED_BOLT_W
    Friendly_Bolts_Velocities_COMP[slot_index] = slot_velocity


func _apply_enemy_bolt_explosion_damage(explosion_center: Vector3) -> void:
    var cell_id : int = Spatial_Grid.Get_ID_of_Cell_from_Location(explosion_center)
    if cell_id == -1:
        return

    var affected_boids : PackedInt32Array = Spatial_Grid.Get_All_Boids_in_Cell(cell_id, false)
    var boid_i : int = 0
    while boid_i < affected_boids.size():
        var boid_index : int = affected_boids[boid_i]
        if boid_index >= 0 and boid_index < MAX_NUMBER_OF_BOIDS:
            var boid_state : E_Boid_State = Get_Boid_State(boid_index)
            if boid_state == E_Boid_State.FRIENDLY:
                var boid_position : Vector3 = _get_boid_transform(boid_index).origin
                var within_explosion_radius : bool = boid_position.distance_to(explosion_center) <= Enemy_Bolts_Explosion_Radius
                if within_explosion_radius:
                    Apply_Damage_SYS(boid_index, Enemy_Bolts_Explosion_Damage)
        boid_i += 1


## TODO: Cycle through all friendly bolts and check their XYZ position and see if
## any of them are within 0.1 units of any enemy boids in the same Spatial_Grid cell.
## or if they struck the enemy mothership. it uses Damageable so we can call that instead
func _did_any_friendly_bolts_hit_enemies_or_mothership() -> bool:
    var did_any_hit : bool = false
    if Friendly_Bolts_Velocities_COMP.is_empty():
        return false

    var friendly_bolts_transform_buffer : PackedVector3Array = _get_friendly_bolts_transform_buffer()
    if friendly_bolts_transform_buffer.is_empty():
        return false

    var enemy_ship_hit_distance : float = 0.1
    var slot_index : int = 0
    while slot_index < Friendly_Bolts_Velocities_COMP.size():
        var bolt_velocity_data : Vector4 = Friendly_Bolts_Velocities_COMP[slot_index]
        var bolt_age : float = bolt_velocity_data.w
        var slot_is_active : bool = bolt_age >= 0.0 and bolt_age <= All_Bolts_Lifetimes
        if slot_is_active:
            var position_index : int = (slot_index * 4) + 3
            if position_index < friendly_bolts_transform_buffer.size():
                var bolt_position : Vector3 = friendly_bolts_transform_buffer[position_index]
                var did_hit_enemy_boid : bool = false

                var cell_id : int = Spatial_Grid.Get_ID_of_Cell_from_Location(bolt_position)
                if cell_id != -1:
                    var boids_in_same_cell : PackedInt32Array = Spatial_Grid.Get_All_Boids_in_Cell(cell_id, false)
                    var boid_i : int = 0
                    while boid_i < boids_in_same_cell.size():
                        var boid_index : int = boids_in_same_cell[boid_i]
                        if boid_index >= 0 and boid_index < MAX_NUMBER_OF_BOIDS and Get_Boid_State(boid_index) == E_Boid_State.ENEMY:
                            var enemy_boid_position : Vector3 = _get_boid_transform(boid_index).origin
                            var did_hit_enemy : bool = bolt_position.distance_to(enemy_boid_position) <= enemy_ship_hit_distance
                            if did_hit_enemy:
                                Apply_Damage_SYS(boid_index, 1)
                                _set_friendly_bolt_slot_inactive(slot_index)
                                did_any_hit = true
                                did_hit_enemy_boid = true
                                break
                        boid_i += 1

                if did_hit_enemy_boid == false:
                    var enemy_mothership : Damageable = targets_index.get(-6, null)
                    if enemy_mothership != null:
                        var enemy_mothership_hit_radius : float = _estimate_damageable_hit_radius(enemy_mothership)
                        var did_hit_mothership : bool = bolt_position.distance_to(enemy_mothership.global_position) <= enemy_mothership_hit_radius
                        if did_hit_mothership:
                            enemy_mothership.Apply_Damage(1.0)
                            _set_friendly_bolt_slot_inactive(slot_index)
                            did_any_hit = true
        slot_index += 1

    return did_any_hit



## TODO: Cycle through all enemy bolts and check their XYZ position and see if
## any of them are within any of the planets in OffbrandSolarSystem (they all use sphere meshinstance3D so we can just query the Radius)
## or if they struck the friendly mothership. They all use Damageable so we can call that instead
func _did_any_enemy_bolts_hit_planet_or_mothership() -> bool:
    var did_any_hit : bool = false
    if Enemy_Bolts_Velocities_COMP.is_empty():
        return false

    var enemy_bolts_transform_buffer : PackedVector3Array = _get_enemy_bolts_transform_buffer()
    if enemy_bolts_transform_buffer.is_empty():
        return false

    var target_ids_to_check : PackedInt32Array = PackedInt32Array([-1, -2, -3, -4, -5])
    var slot_index : int = 0
    while slot_index < Enemy_Bolts_Velocities_COMP.size():
        var bolt_velocity_data : Vector4 = Enemy_Bolts_Velocities_COMP[slot_index]
        var bolt_age : float = bolt_velocity_data.w
        var slot_is_active : bool = bolt_age >= 0.0 and bolt_age <= All_Bolts_Lifetimes
        if slot_is_active:
            var position_index : int = (slot_index * 4) + 3
            if position_index < enemy_bolts_transform_buffer.size():
                var bolt_position : Vector3 = enemy_bolts_transform_buffer[position_index]
                var target_idx : int = 0
                
                while target_idx < target_ids_to_check.size():
                    var target_id : int = target_ids_to_check[target_idx]
                    var target_damageable : Damageable = targets_index.get(target_id, null)
                    if target_damageable != null:
                        var hit_radius : float = _estimate_damageable_hit_radius(target_damageable)
                        var did_hit_target : bool = bolt_position.distance_to(target_damageable.global_position) <= hit_radius
                        if did_hit_target:
                            
                            #TODO: All enemies 
                            target_damageable.Apply_Damage(1.0)
                            _apply_enemy_bolt_explosion_damage(bolt_position)
                            _set_enemy_bolt_slot_inactive(slot_index)
                            did_any_hit = true
                            break
                    target_idx += 1
        slot_index += 1

    return did_any_hit



func _flush_multimesh_buffers(do_friendlys : bool, do_bolts : bool):
    var target_multmesh : MultiMeshInstance3D
    var new_buffer : PackedVector3Array
    var prev_buffer : PackedVector3Array
    if do_friendlys and do_bolts:
        target_multmesh = Friendly_Bolts_MultiMesh
        new_buffer = _current_friendly_bolts_transforms_buffer if _use_current_buffer_this_frame else _previous_friendly_bolts_transforms_buffer
        prev_buffer = _current_friendly_bolts_transforms_buffer if not _use_current_buffer_this_frame else _previous_friendly_bolts_transforms_buffer
        
    elif do_friendlys and not do_bolts:
        target_multmesh = Friendly_MultiMesh
        new_buffer = _current_friendly_transforms_buffer if _use_current_buffer_this_frame else _previous_friendly_transforms_buffer
        prev_buffer = _current_friendly_transforms_buffer if not _use_current_buffer_this_frame else _previous_friendly_transforms_buffer

    elif not do_friendlys and do_bolts:
        target_multmesh = Enemy_Bolts_MultiMesh
        new_buffer = _current_enemy_bolts_transforms_buffer if _use_current_buffer_this_frame else _previous_enemy_bolts_transforms_buffer
        prev_buffer = _current_enemy_bolts_transforms_buffer if not _use_current_buffer_this_frame else _previous_enemy_bolts_transforms_buffer
        
    elif not do_friendlys and not do_bolts:
        target_multmesh = Enemy_MultiMesh
        new_buffer = _current_enemy_transforms_buffer if _use_current_buffer_this_frame else _previous_enemy_transforms_buffer
        prev_buffer = _current_enemy_transforms_buffer if not _use_current_buffer_this_frame else _previous_enemy_transforms_buffer

    if target_multmesh != null and target_multmesh.multimesh != null:
        var target_instance_count : int = target_multmesh.multimesh.instance_count
        var expected_vec3_len : int = target_instance_count * 4
        var corrected_new_buffer : PackedVector3Array = _ensure_transform_vec3_buffer_size(new_buffer, expected_vec3_len)
        var corrected_prev_buffer : PackedVector3Array = _ensure_transform_vec3_buffer_size(prev_buffer, expected_vec3_len)
        var new_float_buffer : PackedFloat32Array = _convert_transform_vec3_buffer_to_float_buffer(corrected_new_buffer, target_instance_count)
        var prev_float_buffer : PackedFloat32Array = _convert_transform_vec3_buffer_to_float_buffer(corrected_prev_buffer, target_instance_count)
        target_multmesh.multimesh.set_buffer_interpolated(new_float_buffer, prev_float_buffer)


func _ensure_transform_vec3_buffer_size(source_buffer: PackedVector3Array, expected_len: int) -> PackedVector3Array:
    if source_buffer.size() == expected_len:
        return source_buffer

    var corrected_buffer : PackedVector3Array = PackedVector3Array()
    corrected_buffer.resize(expected_len)
    var fill_index : int = 0
    while fill_index < expected_len:
        var mod_index : int = fill_index % 4
        if mod_index == 0:
            corrected_buffer[fill_index] = Vector3.RIGHT
        elif mod_index == 1:
            corrected_buffer[fill_index] = Vector3.UP
        elif mod_index == 2:
            corrected_buffer[fill_index] = Vector3.BACK
        else:
            corrected_buffer[fill_index] = Vector3(-999999.0, -999999.0, -999999.0)
        fill_index += 1

    var copy_count : int = min(source_buffer.size(), expected_len)
    var copy_index : int = 0
    while copy_index < copy_count:
        corrected_buffer[copy_index] = source_buffer[copy_index]
        copy_index += 1
    return corrected_buffer


func _convert_transform_vec3_buffer_to_float_buffer(vec3_buffer: PackedVector3Array, instance_count: int) -> PackedFloat32Array:
    var float_buffer : PackedFloat32Array = PackedFloat32Array()
    float_buffer.resize(instance_count * 12)

    var instance_index : int = 0
    while instance_index < instance_count:
        var vec_base_index : int = instance_index * 4
        var basis_x : Vector3 = vec3_buffer[vec_base_index + 0]
        var basis_y : Vector3 = vec3_buffer[vec_base_index + 1]
        var basis_z : Vector3 = vec3_buffer[vec_base_index + 2]
        var origin : Vector3 = vec3_buffer[vec_base_index + 3]

        var float_base_index : int = instance_index * 12
        float_buffer[float_base_index + 0] = basis_x.x
        float_buffer[float_base_index + 1] = basis_y.x
        float_buffer[float_base_index + 2] = basis_z.x
        float_buffer[float_base_index + 3] = origin.x
        float_buffer[float_base_index + 4] = basis_x.y
        float_buffer[float_base_index + 5] = basis_y.y
        float_buffer[float_base_index + 6] = basis_z.y
        float_buffer[float_base_index + 7] = origin.y
        float_buffer[float_base_index + 8] = basis_x.z
        float_buffer[float_base_index + 9] = basis_y.z
        float_buffer[float_base_index + 10] = basis_z.z
        float_buffer[float_base_index + 11] = origin.z
        instance_index += 1
    return float_buffer






func _refresh_cached_target_data() -> void:
    var refreshed_positions : Dictionary[int, Vector3] = {}
    var refreshed_radii : Dictionary[int, float] = {}
    var all_target_ids : Array = targets_index.keys()
    var i : int = 0
    while i < all_target_ids.size():
        var target_id : int = int(all_target_ids[i])
        var target_damageable : Damageable = targets_index.get(target_id, null)
        if target_damageable != null:
            refreshed_positions[target_id] = target_damageable.global_position
            refreshed_radii[target_id] = _estimate_damageable_hit_radius(target_damageable)
        i += 1

    _target_position_cache = refreshed_positions
    _target_radius_cache = refreshed_radii


func _refresh_cached_bounds_from_spatial_grid() -> void:
    var spatial_grid : Spatial_Grid = Spatial_Grid.Get_Instance()
    if spatial_grid == null:
        _has_bounds_cache = false
        return

    var collision_shape : CollisionShape3D = spatial_grid.get_node_or_null("CollisionShape3D") as CollisionShape3D
    if collision_shape == null:
        _has_bounds_cache = false
        return
    if (collision_shape.shape is BoxShape3D) == false:
        _has_bounds_cache = false
        return

    var box_shape : BoxShape3D = collision_shape.shape as BoxShape3D
    var shape_size : Vector3 = box_shape.size
    var world_scale : Vector3 = collision_shape.global_basis.get_scale().abs()
    _bounds_extents_cache = Vector3(
        max((shape_size.x * world_scale.x) * 0.5, 0.001),
        max((shape_size.y * world_scale.y) * 0.5, 0.001),
        max((shape_size.z * world_scale.z) * 0.5, 0.001)
    )
    _bounds_center_cache = collision_shape.global_position
    _has_bounds_cache = true


func _physics_process(delta: float) -> void:
    _simulation_time_seconds += delta
    _refresh_cached_target_data()
    _refresh_cached_bounds_from_spatial_grid()
    _dispatch_workers(delta)
    _did_any_friendly_bolts_hit_enemies_or_mothership()
    _did_any_enemy_bolts_hit_planet_or_mothership()
    
    # Time to do some caluclating!
    # --- Friendly boids (not BOLTS) -------------------------------------------
    # When spawned in for the first time, Friendly bodis will wander aimlessly,
    # Always making sure to avoid colliding with other boids by checking its neighbours.
    # Occasionally they'll slerp to a new direction to wander about.
    # If a friendly boid goes out of bounds (outside the extent of Spatial Partitioning Grid), 
    # the weight for steering BACK into bounds is MUCH higher.
    # If a friendly boid is close enough to a planet, their weight to steer-avoid is MUCH higher.
    # If a Friendly boid finds an enemy boid in their cone of vision when doing a Spatial_Grid.Get_Boids_in_Cone()
    # They will then have a much higher Pursue weight and start to pursue the enemy.
    # If the friendly boid is within Friendly_Firing_Distance of the enemy, they'll start to fire.
    # If the friendly boid is out of ammo, their weight to seek/pursue/arrive the friendly mothership is MUCH Higher.
    # Once a friendly boid "arrives" at a friendly mothership (within reload_distance unit) they'll drop their speed to try match the mothership.
    # after reload_time_required seconds their ammo will be reset and repeat.
    # if a friendly boid is ever destroyed by taking too much damage from the explosions caused by
    # Enemy boid bolts when they strike a planet, the friendly boid will have its index in All_Entities_ENT set to 0 (dead)
    # and then after Friendly_Respawn_Time seconds it will spawn from the friendly mothership with an intial velocity of UP or DOWN
    # 
    # FRIENDLY_BOID_MANAGER_THREAD should try calculate all of this, physics process will start the thread,
    # and then wait for FRIENDLY_BOID_MANAGER_THREAD to finish it's work, then the multmesh buffers will be updated / interpolated 
    # using multimesh.set_buffer_interpolated
    #
    # --- Friendly bolts (not BOIDS) -------------------------------------------
    # When Fire_Bolt is called... the chosen bolt will have the location set to the ship that fired it and float off with it's new velocity.
    # Every Bolt fired should have its W component (not XYZ, because its a Vector4) incremented by the physics frame delta
    # 
    # FRIENDLY_BOID_BOLT_MANAGER_THREAD will also be responsible for checking bolt collisions if 
    # a friendly bolt collided with a enemy boids, and also for cleaning up after itself with Retire_old_Bolt()
    #
    # --- Enemy boids (not BOLTS) ----------------------------------------------
    #
    # When spawned in for the first time, Enemy boids will wander aimlessly, with a SLIGHT weight towards a planet.
    # Always making sure to avoid colliding with other boids by checking its neighbours.
    # Occasionally they'll slerp to a new direction to wander about.
    # If a Enemy boid goes out of bounds, the weight for steering BACK into bounds is MUCH higher.
    # The closer an enemy boid gets to a planet, the higher the weight the enemy boid will look_at the planet and steer towards it
    # Once the Enemy boid is within Enemy_Firing_Distance units to the planet (excluding its radius) 
    # it will attempt to fire its bomb (bolt) (all enemy boids are effectively bombers).
    # Once an enemy boid is too close it will have a MUCH higher avoidance weight and try to steer away.
    # Enemy boids reload the same way as Friendly boids, by seeking arrive to the enemy mothership and try to wait while 
    # close enough to the ship to be reloaded.
    # When an enemy boid has been enough times by a friendly boid and has its health set to 0, 
    # it will wait a few seconds and respawn at the mothership with a initial BACKWARDS velocity
    #
    # ENEMY_BOID_MANAGER_THREAD should calculate this
    # ENEMY_BOID_BOLT_MANAGER_THREAD will calculate all the Bolts like how FRIENDLY_BOID_BOLT_MANAGER_THREAD checks friendly bolts
    
    _flush_multimesh_buffers(true, false)
    _flush_multimesh_buffers(true, true)
    _flush_multimesh_buffers(false, false)
    _flush_multimesh_buffers(false, true)
    _use_current_buffer_this_frame = not _use_current_buffer_this_frame
    




var _friendly_spawn_timer : float = 0
var _enemy_spawn_timer : float = 0

func _process(delta: float) -> void:
    var _unused_delta : float = delta
    if has_node("Camera3D/Label"):
        var debug_label : Label = get_node("Camera3D/Label") as Label
        if debug_label != null:
            debug_label.text = "FPS: %d\nPhysics Tick: %d\nWorker: %s" % [
                Engine.get_frames_per_second(),
                Engine.physics_ticks_per_second,
                _physics_status_text
            ]
        
    
    if _can_spawn_friendly() and _friendly_spawn_timer <= 0.0:
        Spawn_Friendly_Boid()
        _friendly_spawn_timer = Friendly_Respawn_Time
        
    if _can_spawn_enemy() and _enemy_spawn_timer <= 0.0:
        Spawn_Enemy_Boid()
        _enemy_spawn_timer = Enemy_Respawn_Time
    
    _friendly_spawn_timer -= delta
    _enemy_spawn_timer -= delta
    
        
        
