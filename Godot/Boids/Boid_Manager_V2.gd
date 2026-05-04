extends Node
class_name Boid_Manager_V2


static var Boid_Manager_Instance : Boid_Manager_V2
static func Get_Instance():
    return Boid_Manager_Instance



## right listen bookaroo, ok so here we got the best boid manager ever we gonna get the multimesh and shit gonna jkust be lit!
## So we got homies and enemies, homies gonna be -120 health to -1,
## enemies gonna be 1 to 120 health
## althe healths are apart of a packed bute array but of SIGNED BYTE
## NOT unsigned


@export_group("Global")

## whats the absoilute maximum number of boids we can have??
@export_range(2, 260000, 1, "prefer_slider") var MAX_NUMBER_OF_BOIDS : int = 1000

## How do we want to divide up our friendlies? (Assuming we want 100 boids max)
##   0.5 == Equal num of Friends V Enemy (50 v 50)
##   0.1 == Small num of Friends V CRAP LOADS of Enemy (10 v 90)
@export_range(0, 1, 0.01, "prefer_slider") var Friendly_Enemy_Count_Ratio : float = 0.5

## All bolts can only exit for a max of X seconds... we want to 
@export_range(0, 5, 0.1, "prefer_slider") var All_Bolts_Lifetimes : float = 2.0


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

## what mesh we gonna use for friendly ships bolts when firing
@export var Friendly_Bolts_MultiMesh : MultiMeshInstance3D

@export_group("Enemies")
# Where will friendlys spawn?
## where we all gonna spawn from
@export var Enemy_Spawn_Point : Node3D

@export_range(0.01, 1.0, 0.01, "prefer_slider") var Enemy_Spawn_Pool_Amount : float = 0.2

## what multimesh we gonna use for enemies
@export var Enemy_MultiMesh : MultiMeshInstance3D

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

## How long (seconds) does it take for a boid to respawn and start shooting again
@export var Friendly_Respawn_Time : float = 5.0
@export var Enemy_Respawn_Time : float = 5.0
@export var Enemy_Bolts_Explosion_Radius : float = 5 
@export var Enemy_Bolts_Explosion_Damage : int = 25

## Check every X seconds if the target our boid is targetting is still worth it? or should we choose another?
@export var target_recheck_seconds : float = 5.0


# signed health of ALL entities:
#   < 0 == enemy
#   0   == dead
#   > 0 == friendly
var All_Entities_ENT : PackedByteArray


# ----- All Enetity COMPonents ------------------------------------------
## Ammo of all boids... 0 means we gotta refuel, >= 1 means we can keep firing
## Ammo_COMP[10] = 55 means the 10th boid is at 55 ammo 
var Ammo_COMP : PackedByteArray

## Who are our boids targetting? 
## For friendlies, Lets get the index of the boid in question
## For enemies, which planet are we targetting?
var Friendly_Target_Enemy_Boid : PackedInt32Array

## For enemies, which planet they're targetting
@onready var targets_index : Dictionary[int, Damageable] = {
    -1 : $OffbrandSolarSystem/PlanetEarthy,
    -2 : $OffbrandSolarSystem/PlanetMoony,
    -3 : $OffbrandSolarSystem/PlanetKnockOffJupiter,
    -4 : $"OffbrandSolarSystem/THE GODDAMN SUN",
    -5 : $"Friendly MotherShip",
    -6 : $"Enemy MotherShip"
}


## What's the velocity of the boid at index i ?
var Velocities_COMP : PackedVector3Array 

## Velocity of all bolts, 
## each boid gets All_Bolts_Lifetimes / (Friendly_Fire_Rate or Enemy_Fire_Rate)
## so 2.0 / 0.4 means the boid faction get 5 slots each here, wheras a lower firerate means less allocated
## X Y Z for direction, the W here of Vector4 is the time left. A time left of <0 means this bolt is no longer active
var Friendly_Bolts_Velocities_COMP : PackedVector4Array
var Enemy_Bolts_Velocities_COMP : PackedVector4Array

enum E_Boid_State {
    FRIENDLY = 1,
    ENEMY = 2,
    DEAD = 3,
    OTHER = 4, ## This isn't a boid?
} 




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
const RETIRED_BOLT_W : float = -1.0
const ACTIVE_BOLT_SCALE : float = 1.0
const RETIRED_BOLT_SCALE : float = 0.00001



# --- My THREAD of sanity is waining -------------------------------------------
var FRIENDLY_BOID_MANAGER_THREAD : Thread
var ENEMY_BOID_MANAGER_THREAD : Thread
var FRIENDLY_BOID_BOLT_MANAGER_THREAD : Thread
var ENEMY_BOID_BOLT_MANAGER_THREAD : Thread
# ------------------------------------------------------------------------------




func _friendly_slots_count() -> int:
    var slots_count : int = int(MAX_NUMBER_OF_BOIDS * Friendly_Enemy_Count_Ratio)
    return clampi(slots_count, 0, MAX_NUMBER_OF_BOIDS * Friendly_Enemy_Count_Ratio)


## increase the friendly pool size from X percent to Y percent... 
## if Add_Amount is greater than 1.0 it will mean we just spawn the maximum number of friendlies
func Increase_Friendly_Pool_Size(Add_Amount : float) -> bool:
    if Friendly_Spawn_Pool_Amount < 1.0:
        Friendly_Spawn_Pool_Amount += Add_Amount
        Friendly_Spawn_Pool_Amount = clampf(Friendly_Spawn_Pool_Amount, 0.0, 1.0)
        return true
    return false

## increase the enemy pool size from X percent to Y percent... 
## if Add_Amount is greater than 1.0 it will mean we just spawn the maximum number of enemies
func Increase_Enemy_Pool_Size(Add_Amount : float) -> bool:
    if Enemy_Spawn_Pool_Amount < 1.0:
        Enemy_Spawn_Pool_Amount += Add_Amount
        Enemy_Spawn_Pool_Amount = clampf(Enemy_Spawn_Pool_Amount, 0.0, 1.0)
        return true
    return false


## Decrease the friendly pool size from X percent to Y percent... 
func Decrease_Friendly_Pool_Size(Add_Amount : float) -> bool:
    if Friendly_Spawn_Pool_Amount > 0.0:
        Friendly_Spawn_Pool_Amount -= Add_Amount
        Friendly_Spawn_Pool_Amount = clampf(Friendly_Spawn_Pool_Amount, 0.01, 1.0)
        return true
    return false


## Decrease the enemy pool size from X percent to Y percent... 
func Decrease_Enemy_Pool_Size(Add_Amount : float) -> bool:
    if Enemy_Spawn_Pool_Amount > 0.0:
        Enemy_Spawn_Pool_Amount -= Add_Amount
        Enemy_Spawn_Pool_Amount = clampf(Enemy_Spawn_Pool_Amount, 0.01, 1.0)
        return true
    return false


func _enemy_slots_count() -> int:
    return MAX_NUMBER_OF_BOIDS - _friendly_slots_count()


func _friendly_pool_cap() -> int:
    var raw_cap : int = int(float(_friendly_slots_count()) * Friendly_Spawn_Pool_Amount)
    if _friendly_slots_count() <= 0:
        return 0
    return clampi(raw_cap, 1, _friendly_slots_count())


func _enemy_pool_cap() -> int:
    var raw_cap : int = int(float(_enemy_slots_count()) * Enemy_Spawn_Pool_Amount)
    if _enemy_slots_count() <= 0:
        return 0
    return clampi(raw_cap, 1, _enemy_slots_count())


func _is_valid_boid_index(boid_index: int) -> bool:
    return boid_index >= 0 and boid_index < MAX_NUMBER_OF_BOIDS


func is_friendly_boid(boid_index : int) -> bool:
    return (boid_index < MAX_NUMBER_OF_BOIDS * Friendly_Enemy_Count_Ratio) and (boid_index >= 0)


# Change a enemy boid index from Whatever back to 0
func Normalise_Enemy_Boid_index(enemy_boid_index) -> int:
    # Dumbass gave a friendly boid, not an enemy
    if enemy_boid_index < (MAX_NUMBER_OF_BOIDS * Friendly_Enemy_Count_Ratio):
       return enemy_boid_index
    else:
        return enemy_boid_index - (MAX_NUMBER_OF_BOIDS * Friendly_Enemy_Count_Ratio)  



#get the boid transform using the buffer we're ACTUALLY using this frame
func _get_boid_transform(boid_index: int, use_previous_frame : bool = false) -> Transform3D:
    if _is_valid_boid_index(boid_index) == false:
        printerr("HEY! SILLY! " + str(boid_index) + " isn't a valid boid index")
        return Transform3D.IDENTITY
    
    var use_upcoming_frame_buffer : bool 
    
    if use_previous_frame:
        use_upcoming_frame_buffer = not _use_current_buffer_this_frame
    else:
        use_upcoming_frame_buffer = _use_current_buffer_this_frame
    
    var target_buffer : PackedVector3Array
    var actual_index : int
    
    if is_friendly_boid(boid_index):
        actual_index = boid_index
        if use_upcoming_frame_buffer:
            target_buffer = _current_friendly_transforms_buffer
        else:
            target_buffer = _previous_friendly_transforms_buffer
    else:
        actual_index = Normalise_Enemy_Boid_index(boid_index)
        if use_upcoming_frame_buffer:
            target_buffer = _current_enemy_transforms_buffer
        else:
            target_buffer = _previous_enemy_transforms_buffer
            
    return Transform3D(
        target_buffer.get((actual_index * 4) + 0),
        target_buffer.get((actual_index * 4) + 1),
        target_buffer.get((actual_index * 4) + 2),
        target_buffer.get((actual_index * 4) + 3)
        )



func _set_boid_transform(boid_index: int, new_transform: Transform3D) -> bool:
    if _is_valid_boid_index(boid_index) == false:
        printerr("HEY! SILLY! " + str(boid_index) + " isn't a valid boid index")
        return false
    
    var target_buffer : PackedVector3Array
    var actual_index : int
    
    if is_friendly_boid(boid_index):
        actual_index = boid_index
        if _use_current_buffer_this_frame:
            target_buffer = _current_friendly_transforms_buffer
                
        else:
            target_buffer = _previous_friendly_transforms_buffer
                
    else:
        actual_index = Normalise_Enemy_Boid_index(boid_index)
        if _use_current_buffer_this_frame:
            target_buffer = _current_enemy_transforms_buffer
        
        else:
            target_buffer = _previous_enemy_transforms_buffer
            
    target_buffer.set( ((actual_index * 4) + 0), new_transform.basis.x)
    target_buffer.set( ((actual_index * 4) + 0), new_transform.basis.y)
    target_buffer.set( ((actual_index * 4) + 0), new_transform.basis.z)
    target_buffer.set( ((actual_index * 4) + 0), new_transform.origin)
    return true
            
            
func Get_Bolt_Velocity(Belonging_to_which_Boid : int, which_bolt : int) -> Vector3:
    if is_friendly_boid(Belonging_to_which_Boid):
        return Vector3(
            Friendly_Bolts_Velocities_COMP.get(Belonging_to_which_Boid + which_bolt).x,
            Friendly_Bolts_Velocities_COMP.get(Belonging_to_which_Boid + which_bolt).y,
            Friendly_Bolts_Velocities_COMP.get(Belonging_to_which_Boid + which_bolt).z,
            )
    else:
        return Vector3(
            Enemy_Bolts_Velocities_COMP.get(Normalise_Enemy_Boid_index(Belonging_to_which_Boid) + which_bolt).x,
            Enemy_Bolts_Velocities_COMP.get(Normalise_Enemy_Boid_index(Belonging_to_which_Boid) + which_bolt).y,
            Enemy_Bolts_Velocities_COMP.get(Normalise_Enemy_Boid_index(Belonging_to_which_Boid) + which_bolt).z,
            )


func _get_bolts_per_boid(for_friendly_boid: bool) -> int:
    var fire_rate : float = Friendly_Fire_Rate if for_friendly_boid else Enemy_Fire_Rate
    var safe_fire_rate : float = max(fire_rate, 0.001)
    var bolts_per_boid : int = int(All_Bolts_Lifetimes / safe_fire_rate)
    return max(1, bolts_per_boid)


func _is_bolt_slot_inactive(bolt_age: float) -> bool:
    return bolt_age < 0.0 or bolt_age > All_Bolts_Lifetimes


func _set_bolt_transform_entry(buffer_ref: PackedVector3Array, slot_index: int, origin: Vector3, scale: float) -> PackedVector3Array:
    var start_index : int = slot_index * 4
    if (start_index + 3) >= buffer_ref.size():
        return buffer_ref

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
    ammo_amount = clampi(ammo_amount, -128, 127)
    Ammo_COMP.set(boid_index, ammo_amount)

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
        
 


func _ready() -> void:
    Boid_Manager_Instance = self
    All_Entities_ENT = PackedByteArray()
    Ammo_COMP = PackedByteArray()
    Velocities_COMP = PackedVector3Array()
    Friendly_Bolts_Velocities_COMP = PackedVector4Array()
    Enemy_Bolts_Velocities_COMP = PackedVector4Array()
    
    _initisalise_packed_arrays()

    
    
    
func _initisalise_packed_arrays():
    All_Entities_ENT.resize(MAX_NUMBER_OF_BOIDS)
    All_Entities_ENT.fill(0) # Everyone starts as DEAD
    
    Ammo_COMP.resize(MAX_NUMBER_OF_BOIDS)
    Ammo_COMP.fill(0)
    
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

    #ta#rget_multmesh.multimesh.set_buffer_interpolated(new_buffer, prev_buffer)






func _physics_process(delta: float) -> void:
    
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
    





# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
    pass
