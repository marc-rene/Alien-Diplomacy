extends Node3D
class_name Boid_Manager

# whats the absoilute maximum number of boids we can have??
#@export_range(2, 200, 1, "prefer_slider") var Max_Num_Boids := 100
@export_range(2, 260000, 1, "prefer_slider") var Max_Num_Boids := 100

# How do we want to divide up our friendlies? (Assuming we want 100 boids max)
#   0.5 == Equal num of Friends V Enemy (50 v 50)
#   0.1 == Small num of Friends V CRAP LOADS of Enemy (10 v 90) 
@export_range(0, 1, 0.01, "prefer_slider") var Friendly_Enemy_Count_Ratio := 0.5

@export_group("Friendlys")
# Where will friendlys spawn?
@export var Friendly_Spawn_Point : Node3D   
@export var Friendly_Mesh : MeshInstance3D
@export var Friendly_MultiMesh : MultiMeshInstance3D
var max_friendly_count := 0

@export_group("Enemies")
# Where will enemies spawn?
@export var Enemy_Spawn_Point : Node3D   
@export var Enemy_Mesh : MeshInstance3D
@export var Enemy_MultiMesh : MultiMeshInstance3D

## What percentage of Enemies can we spawn? 1.0 means spawn everyone
@export var Enemy_Pool_Amount : float = 0.2

@export var max_speed := 2.0
@export var banking := 0.05
@export var mass := 2.0

var temp_friend_mesh_push_buffer : PackedFloat32Array
var temp_enemy_mesh_push_buffer : PackedFloat32Array
var prev_friend_mesh_push_buffer : PackedFloat32Array
var prev_enemy_mesh_push_buffer : PackedFloat32Array

@export_category("Performance HELL")
@export var offbrand_physics_DLSS : bool = true # Do we want to use one buffer? (Smooth) or swap between 2 buffers? (Great performacne, annoying jitter at low fps)
@export var starting_physics_tick : int = 15 # Do we want to use one buffer? (Smooth) or swap between 2 buffers? (Great performacne, annoying jitter)
@export var try_hit_60 : bool = false # try and fail to make the FPS keep 60
@export var Override_Camera : Camera3D
var use_prev_buffer : bool = true

static var boid_manager_instance : Boid_Manager

static func Is_Using_Offbrand_Physics_DLSS() -> bool:
    return boid_manager_instance.offbrand_physics_DLSS

static func How_Many_Boids() -> int:
    return boid_manager_instance.Max_Num_Boids

static func How_Many_Boids_Active() -> int:
    return boid_manager_instance.eeees + boid_manager_instance.french


var friendly_boid_target_node : Node3D
var enemy_boid_target_node : Node3D

# SO here's the naming convention
# Entities will end in _ent
# componenets (like velocity, etc...) end with _comp

# Our entities will have their health and team based off the ALL_ENTITIES_ent
# It's a packed signed-byte array, because we'll only have 3 states:
#   -127 -> -1  (You're on Enemy team, and you have X health)
#   0           (Yo you is deactivated / dead) 
#   1 -> 127    (You're on Friendly team, and you have X health
#   from [0:max_friendly_count] is friends, [max_friendly_count : ] is enemies
var ALL_ENTITIES_ent : PackedByteArray

var OFFSETS_comp : PackedByteArray

# Global Positions of all entities
# static var GLOBAL_POSITIONS_comp : PackedVector3Array


# Global Velocities of all entities
var VELOCITIES_comp : PackedVector3Array


func Refresh_Entities():
    inited = false
    ALL_ENTITIES_ent.resize(Max_Num_Boids)
    ALL_ENTITIES_ent.fill(0)    # You're all deactivated!
    
    VELOCITIES_comp.resize(Max_Num_Boids)
    VELOCITIES_comp.fill(Vector3.ZERO)
    
    OFFSETS_comp.resize(Max_Num_Boids)
    for i in range(Max_Num_Boids):
        OFFSETS_comp.encode_s8(i, 1)

    
    max_friendly_count = int(Friendly_Enemy_Count_Ratio * Max_Num_Boids)
    
    temp_friend_mesh_push_buffer.resize(max_friendly_count * 12)
    prev_friend_mesh_push_buffer.resize(max_friendly_count * 12)
    temp_enemy_mesh_push_buffer.resize((Max_Num_Boids - max_friendly_count) * 12)
    prev_enemy_mesh_push_buffer.resize((Max_Num_Boids - max_friendly_count) * 12)

    print("Max num of boids: %d\n\tFriendly boids: %d\n\tEnemy boids: %d" % [ALL_ENTITIES_ent.size(), max_friendly_count, Max_Num_Boids - max_friendly_count])
    
    Friendly_MultiMesh.multimesh.mesh = Friendly_Mesh.mesh
    Enemy_MultiMesh.multimesh.mesh = Enemy_Mesh.mesh
    
    #Friendly_MultiMesh.multimesh.transform_format = MultiMesh.TRANSFORM_3D # 3D format
    #Enemy_MultiMesh.multimesh.transform_format = MultiMesh.TRANSFORM_3D
    
    Friendly_MultiMesh.multimesh.instance_count = max_friendly_count
    Enemy_MultiMesh.multimesh.instance_count = Max_Num_Boids - max_friendly_count
    
    Friendly_MultiMesh.multimesh.visible_instance_count = max_friendly_count
    Enemy_MultiMesh.multimesh.visible_instance_count = Max_Num_Boids - max_friendly_count
    
    keep_spawning_f = true
    keep_spawning_e = true
    inited = true

var inited := false
func _ready():
    if Friendly_Spawn_Point == null or Friendly_Mesh == null or Friendly_MultiMesh == null or Enemy_Spawn_Point == null or Enemy_Mesh == null  or Enemy_MultiMesh == null:
        printerr("Yo aint said what yo homies or estonies is!!!")
        set_physics_process(false)
        return 
        
    boid_manager_instance = self
    Engine.physics_ticks_per_second = starting_physics_tick
    
    ALL_ENTITIES_ent = PackedByteArray()
    
    VELOCITIES_comp = PackedVector3Array()
    
    OFFSETS_comp = PackedByteArray()

    Refresh_Entities()
    
    Enemy_MultiMesh.multimesh.visible_instance_count = (Enemy_Pool_Amount * (Max_Num_Boids * Friendly_Enemy_Count_Ratio))
    
    
    
    





func is_alive(entity_index: int) -> bool:
    if entity_index < ALL_ENTITIES_ent.size():
        return ALL_ENTITIES_ent[entity_index] != 0
    else:
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
    else:
        return Enemy_MultiMesh.multimesh.get_instance_transform(entity_index - max_friendly_count)
            
    
var temp_buffer : PackedByteArray        
func count_free_spots(friendly_spots : bool) -> int:
    temp_buffer.clear()
    if friendly_spots:
        temp_buffer.slice(0, max_friendly_count)
    else:
        temp_buffer.slice(max_friendly_count)
    
    return temp_buffer.count(0)
    
            
            
var frame_fence := 0
var keep_spawning_f : bool = true
var keep_spawning_e : bool = true
const max_offset : float = 10.0
var cam_point : Transform3D

var friendly_pos : Vector3 = Vector3(0, 50, 0)
var enemy_pos : Vector3  = Vector3(0, -50, 0)

var french = 0
var eeees = 0

var frame_time_switches : int = 0
var update_physics_score : float = 1

## We only ever fly to one target at a time, so we only ever pulse the
## one Damageable that is currently being targeted.
var _currently_pulsing_target : Damageable = null


func _resolve_damageable_for_target_node(target_node: Node) -> Damageable:
    if target_node == null:
        return null
    if target_node is Damageable:
        return target_node as Damageable
    var parent_node : Node = target_node.get_parent()
    if parent_node != null and parent_node is Damageable:
        return parent_node as Damageable
    return null


func _set_currently_pulsing_target(new_target_node: Node) -> void:
    var new_damageable : Damageable = _resolve_damageable_for_target_node(new_target_node)
    if new_damageable == _currently_pulsing_target:
        return

    if _currently_pulsing_target != null and is_instance_valid(_currently_pulsing_target):
        _currently_pulsing_target.Stop_Pulse_Targeted_Red()

    _currently_pulsing_target = new_damageable

    if _currently_pulsing_target != null:
        _currently_pulsing_target.Pulse_Targeted_Red()


## every X frames lets change things up
@export var Do_Change_Every_X_Frame : int = 2000

func _process(delta: float) -> void:
    
    Enemy_MultiMesh.multimesh.visible_instance_count = int(clampf(Enemy_Pool_Amount, 0.0, 1.0) * (Max_Num_Boids - (Max_Num_Boids * Friendly_Enemy_Count_Ratio)))
    
    if not inited:
        return
    if keep_spawning_f: 
        keep_spawning_f = spawn_friendly()
        french += 1
        #print("French num: " + str(french) + "\tV: " + str(VELOCITIES_comp[french-1]))
        
        #cam_point = get_boid_transform(0)
        if keep_spawning_f == false:
            print("STOPPED FRENCH")
    if spawn_enemy(): 
        eeees += 1
    
    cam_point = get_boid_transform(max_friendly_count)
    frame_fence += 1
    #$Camera3D.global_position = cam_point.origin - cam_point.basis.z * 3 + cam_point.basis.y * 2  # behind + up
    if Override_Camera != null:
        $Camera3D.global_position = cam_point.origin - cam_point.basis.z + cam_point.basis.y  # behind + up
        $Camera3D.look_at(cam_point.origin, Vector3.UP)
        
        $Camera3D/Label.text = "FPS: " + str(Engine.get_frames_per_second()) + "\nFriendly Boids: " + str(french-1) + "\nEnemy Boids: " + str(eeees-1) + "\nPhysics FPS: " + str(Engine.physics_ticks_per_second)
        $Camera3D/Label.text += "\nPhysics Update Tick score: " + str(update_physics_score) + "\nPhysics Frame Fence: " + str(physics_fence) +"/"+ str(int(frames_before_change*update_physics_score)) + "\nPhysics fps next change: " + str(clamp(int(starting_physics_tick * update_physics_score), 1, starting_physics_tick))
        $Camera3D/Label.text += "\nAwful frame drops: " + str(frame_time_switches)
        $Camera3D/Label.text += "\nUsing Offbrand Physics DLSS?: " + str(offbrand_physics_DLSS)
   
    if try_hit_60: 
        struggling_level = int(Engine.get_frames_per_second() / 10)
            
        if (struggling_level <= 1 ):
            update_physics_score = 0.01
            Engine.max_physics_steps_per_frame = 1
            #Engine.physics_ticks_per_second = clamp(int(starting_physics_tick * 0.1), 1, 100)
            physics_fence = frames_before_change
            frame_time_switches += 100      
        elif (struggling_level < 2 ):
            update_physics_score -= 0.005
            #Engine.physics_ticks_per_second = clamp(int(starting_physics_tick * 0.15), 1, 100)
            #physics_fence = 0
            frame_time_switches += 50
        elif (struggling_level < 3 ):
            update_physics_score -= 0.0002
            frame_time_switches += 1 
        elif (struggling_level < 4 ):
            Engine.max_physics_steps_per_frame = 2
            update_physics_score += 0.0001
            frame_time_switches -= 1
        elif (struggling_level < 5 ):
            Engine.max_physics_steps_per_frame = 3
            update_physics_score += 0.0003
            frame_time_switches -= 2
        elif (struggling_level < 7 ):
            update_physics_score += 0.001
            frame_time_switches -= 3
        else:
            update_physics_score += 0.005
            frame_time_switches -= int(1 * Engine.physics_ticks_per_second)

        frame_time_switches = clamp(frame_time_switches, -10000, 10000)
        update_physics_score = clampf(update_physics_score, 0.01, 1)
       

        #elif (struggling_level < 6 and physics_fence >= frames_before_change):
            #Engine.physics_ticks_per_second = clamp(int(starting_physics_tick * 0.9), 1, 100)
            #physics_fence = 0
        if physics_fence >= (frames_before_change*update_physics_score):
            physics_fence = 0
            
        if frame_time_switches > 5000 and offbrand_physics_DLSS == false:
            printerr("Sorry bud, performance is too jittery no matter what we do, switching to hacky low performance mode")
            offbrand_physics_DLSS = true
            
        if frame_time_switches < 0 and offbrand_physics_DLSS:
            print("performance seems to be better, going back to better boids")
            offbrand_physics_DLSS = false
    
    else: # dont bpther juggling the physics fps
        Engine.max_physics_steps_per_frame = 3
        update_physics_score = 1
    
    Engine.physics_ticks_per_second = clamp(int(starting_physics_tick * update_physics_score), 1, starting_physics_tick) 
    
    if frame_fence % 9001 == 0: 
        for i in range(Max_Num_Boids):
            OFFSETS_comp.encode_s8(i, randi_range(-1, 1))
            if OFFSETS_comp[i] == 0:
                OFFSETS_comp[i] += 1
    if frame_fence % 19001 == 0: 
        for i in range(Max_Num_Boids):
            OFFSETS_comp.encode_s8(i, randi_range(-2, 2))
            if OFFSETS_comp[i] == 0:
                OFFSETS_comp[i] += 1
    if frame_fence % 28979 == 0: 
        for i in range(Max_Num_Boids):
            OFFSETS_comp.encode_s8(i, randi_range(-3, 3))
            if OFFSETS_comp[i] == 0:
                OFFSETS_comp[i] += 1
    
    
    if frame_fence % Do_Change_Every_X_Frame == 0: 
        
        print("FPS: " + str(Engine.get_frames_per_second()) )
        print("Homies: " + str(Friendly_MultiMesh.multimesh.instance_count) + "\tbuffer size: " + str(Friendly_MultiMesh.multimesh.buffer.size()))
        print("Enemies: " + str(Enemy_MultiMesh.multimesh.instance_count) + "\tbuffer size: " + str(Enemy_MultiMesh.multimesh.buffer.size()))
        print("Enemies (VISABLE): " + str(Enemy_MultiMesh.multimesh.visible_instance_count) + "\tActually 'spawned': " + str(eeees))
        print("Total: " + str(ALL_ENTITIES_ent.size()) + "\t Velocities too: " + str(VELOCITIES_comp.size()) )
        
        
        var potential_targets : Array[Node] = %OffbrandSolarSystem.get_children()
        potential_targets.append(%"Friendly MotherShip")
        potential_targets.append(%"Enemy MotherShip")
        #for child in potential_targets:
            #print("Options for boids to target is: " + child.name)
            
        var target_node_marker : Node3D = null
        var target_planet : Node = potential_targets.pick_random()
        if target_planet.has_node("Boid_Target"):
            target_node_marker = target_planet.get_node("Boid_Target") as Node3D
            print("NEW TARGET FOUND! " + target_planet.name + " - " +  target_node_marker.name)
        elif target_planet is Node3D:
            target_node_marker = target_planet as Node3D
            print("NEW TARGET FOUND! " + target_planet.name)
        
        if target_node_marker != null:
            friendly_boid_target_node = target_node_marker
            enemy_boid_target_node = target_node_marker
            _set_currently_pulsing_target(target_planet)
        frame_fence = 0
        
    if friendly_boid_target_node:
        friendly_pos = friendly_boid_target_node.global_position
    if enemy_boid_target_node and not IS_PEACE_ACHIEVED:
        enemy_pos = enemy_boid_target_node.global_position - enemy_boid_target_node.position
        
    if IS_PEACE_ACHIEVED:
        enemy_pos = Vector3(90000, 0, 0)
        max_speed = 3
        
        #for i in range(Max_Num_Boids / 2):
            #OFFSETS_comp[i * 2 - 1] = OFFSETS_comp[i] * -1.1 
            #OFFSETS_comp[i+1] = OFFSETS_comp[i+1] * 1.01 


#func make_blurry(target: Vector3, offset:float) -> Vector3:
    #return Vector3(target.x - offset, target.y + offset, target.z + offset)

 
var target_pos : Vector3       
var to_target : Vector3
var desried : Vector3
#func calculate_force(ent : int) -> Vector3:
    #target_pos = $Friend_NamNam.global_position if is_friendly(ent) else $Enemy_NamNam.global_position
    ##var to_target = make_blurry(target_node.global_position, 1.0 / ((ent % 20) + 1)) - get_boid_transform(ent).origin
    #to_target = target_pos - get_boid_transform(ent).origin
    #to_target.x += (1.0 / OFFSETS_comp[ent])
    #to_target.y += (1.1 / OFFSETS_comp[ent])
    #to_target.z += (-1.2 / OFFSETS_comp[ent])
    #desried = to_target.normalized() * max_speed # max speed
    #return desried - VELOCITIES_comp[ent]



var force : Vector3
var accel : Vector3
var new_trans : Transform3D
var temp_up : Vector3
var struggling_level : int = 0
var prev_struggle : int = 999999
const frames_before_change : int = 100
var physics_fence : int = 0
func _physics_process(delta: float) -> void:
        
    physics_fence += 1   
            
        
    for ent in range(Max_Num_Boids):
        if inited and is_alive(ent) == false: 
            continue

        target_pos = friendly_pos if is_friendly(ent) else enemy_pos
        new_trans = get_boid_transform(ent)
        #target_pos.x = randfn(target_pos.x, 1.0)
        #target_pos.y = randfn(target_pos.y, 1.0)
        #target_pos.z = randfn(target_pos.z, 1.0)        
        #var to_target = make_blurry(target_node.global_position, 1.0 / ((ent % 20) + 1)) - get_boid_transform(ent).origin
        to_target = target_pos - new_trans.origin
        to_target.x += clampf((randf_range(-1.1, 1.1) * OFFSETS_comp[ent]), -1.0, 1)
        to_target.y += clampf((randf_range(-1.8, 1.8) * OFFSETS_comp[ent]), -1.0, 2)
        to_target.z += clampf((randf_range(-1.1, 1.1) * OFFSETS_comp[ent]), -1.0, 1)
        desried = to_target.normalized() * max_speed # max speed
        
        force = desried - VELOCITIES_comp[ent]
        #force = calculate_force(ent)
        accel = force / mass # mass = 1
        VELOCITIES_comp[ent] += accel * delta
        #new_trans = get_boid_transform(ent)

        if VELOCITIES_comp[ent].length_squared() > 0.1:
            temp_up = new_trans.basis.y.lerp((Vector3.UP + accel * banking).normalized(), delta * 5)
            new_trans = new_trans.looking_at(new_trans.origin - VELOCITIES_comp[ent], temp_up)
        new_trans.origin += VELOCITIES_comp[ent] * delta

        if ent < max_friendly_count: #is friendlY?
            if use_prev_buffer or offbrand_physics_DLSS == false:
                temp_friend_mesh_push_buffer[(12 * ent) + 0] = new_trans.basis.x.x
                temp_friend_mesh_push_buffer[(12 * ent) + 1] = new_trans.basis.y.x
                temp_friend_mesh_push_buffer[(12 * ent) + 2] = new_trans.basis.z.x
                temp_friend_mesh_push_buffer[(12 * ent) + 3] = new_trans.origin.x
                temp_friend_mesh_push_buffer[(12 * ent) + 4] = new_trans.basis.x.y
                temp_friend_mesh_push_buffer[(12 * ent) + 5] = new_trans.basis.y.y
                temp_friend_mesh_push_buffer[(12 * ent) + 6] = new_trans.basis.z.y
                temp_friend_mesh_push_buffer[(12 * ent) + 7] = new_trans.origin.y
                temp_friend_mesh_push_buffer[(12 * ent) + 8] = new_trans.basis.x.z
                temp_friend_mesh_push_buffer[(12 * ent) + 9] = new_trans.basis.y.z
                temp_friend_mesh_push_buffer[(12 * ent) + 10] = new_trans.basis.z.z
                temp_friend_mesh_push_buffer[(12 * ent) + 11] = new_trans.origin.z
            else:
                prev_friend_mesh_push_buffer[(12 * ent) + 0] = new_trans.basis.x.x
                prev_friend_mesh_push_buffer[(12 * ent) + 1] = new_trans.basis.y.x
                prev_friend_mesh_push_buffer[(12 * ent) + 2] = new_trans.basis.z.x
                prev_friend_mesh_push_buffer[(12 * ent) + 3] = new_trans.origin.x
                prev_friend_mesh_push_buffer[(12 * ent) + 4] = new_trans.basis.x.y
                prev_friend_mesh_push_buffer[(12 * ent) + 5] = new_trans.basis.y.y
                prev_friend_mesh_push_buffer[(12 * ent) + 6] = new_trans.basis.z.y
                prev_friend_mesh_push_buffer[(12 * ent) + 7] = new_trans.origin.y
                prev_friend_mesh_push_buffer[(12 * ent) + 8] = new_trans.basis.x.z
                prev_friend_mesh_push_buffer[(12 * ent) + 9] = new_trans.basis.y.z
                prev_friend_mesh_push_buffer[(12 * ent) + 10] = new_trans.basis.z.z
                prev_friend_mesh_push_buffer[(12 * ent) + 11] = new_trans.origin.z
        

        if ent >= max_friendly_count: #not friendlY?
            if use_prev_buffer or offbrand_physics_DLSS == false:
                temp_enemy_mesh_push_buffer[(12 * (ent - max_friendly_count)) + 0] = new_trans.basis.x.x
                temp_enemy_mesh_push_buffer[(12 * (ent - max_friendly_count)) + 1] = new_trans.basis.y.x
                temp_enemy_mesh_push_buffer[(12 * (ent - max_friendly_count)) + 2] = new_trans.basis.z.x
                temp_enemy_mesh_push_buffer[(12 * (ent - max_friendly_count)) + 3] = new_trans.origin.x
                temp_enemy_mesh_push_buffer[(12 * (ent - max_friendly_count)) + 4] = new_trans.basis.x.y
                temp_enemy_mesh_push_buffer[(12 * (ent - max_friendly_count)) + 5] = new_trans.basis.y.y
                temp_enemy_mesh_push_buffer[(12 * (ent - max_friendly_count)) + 6] = new_trans.basis.z.y
                temp_enemy_mesh_push_buffer[(12 * (ent - max_friendly_count)) + 7] = new_trans.origin.y
                temp_enemy_mesh_push_buffer[(12 * (ent - max_friendly_count)) + 8] = new_trans.basis.x.z
                temp_enemy_mesh_push_buffer[(12 * (ent - max_friendly_count)) + 9] = new_trans.basis.y.z
                temp_enemy_mesh_push_buffer[(12 * (ent - max_friendly_count)) + 10] = new_trans.basis.z.z
                temp_enemy_mesh_push_buffer[(12 * (ent - max_friendly_count)) + 11] = new_trans.origin.z
            else:
                prev_enemy_mesh_push_buffer[(12 * (ent - max_friendly_count)) + 0] = new_trans.basis.x.x
                prev_enemy_mesh_push_buffer[(12 * (ent - max_friendly_count)) + 1] = new_trans.basis.y.x
                prev_enemy_mesh_push_buffer[(12 * (ent - max_friendly_count)) + 2] = new_trans.basis.z.x
                prev_enemy_mesh_push_buffer[(12 * (ent - max_friendly_count)) + 3] = new_trans.origin.x
                prev_enemy_mesh_push_buffer[(12 * (ent - max_friendly_count)) + 4] = new_trans.basis.x.y
                prev_enemy_mesh_push_buffer[(12 * (ent - max_friendly_count)) + 5] = new_trans.basis.y.y
                prev_enemy_mesh_push_buffer[(12 * (ent - max_friendly_count)) + 6] = new_trans.basis.z.y
                prev_enemy_mesh_push_buffer[(12 * (ent - max_friendly_count)) + 7] = new_trans.origin.y
                prev_enemy_mesh_push_buffer[(12 * (ent - max_friendly_count)) + 8] = new_trans.basis.x.z
                prev_enemy_mesh_push_buffer[(12 * (ent - max_friendly_count)) + 9] = new_trans.basis.y.z
                prev_enemy_mesh_push_buffer[(12 * (ent - max_friendly_count)) + 10] = new_trans.basis.z.z
                prev_enemy_mesh_push_buffer[(12 * (ent - max_friendly_count)) + 11] = new_trans.origin.z
            
        #set_boid_transform(ent, new_trans) # Godot is terrible with CPU -> gpu calls
    
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

        #$Label3D.transform = get_boid_transform(ent)
        #$Label3D.text = str(get_boid_transform(ent))
        #print("#" + str(ent) + "\n\tPosit: " + str($Label3D.global_position) + "\n\tRotat" + str($Label3D.global_rotation) + "\n\tScale" + str($Label3D.scale) + "\n\tBasis" + str($Label3D.basis) + "\n\tTrans" + str($Label3D.global_transform) )
    

func set_boid_transform(ship_entity_index : int, new_transform : Transform3D):
    if is_friendly(ship_entity_index):
        Friendly_MultiMesh.multimesh.set_instance_transform(ship_entity_index, new_transform)
    else:
        Enemy_MultiMesh.multimesh.set_instance_transform((ship_entity_index-max_friendly_count), new_transform)
    
    
func spawn_ship(force_spawn : bool, p_is_friendly : bool) -> bool:
    var free_index : int = -1
    
    if p_is_friendly:
        free_index = ALL_ENTITIES_ent.find(0) # any dead decatived boids?
        if is_enemy(free_index): # Only enemy spots are free
            free_index = -1
    else:
        free_index = ALL_ENTITIES_ent.find(0, max_friendly_count) # any dead decatived enemy boids?     
        
    if free_index == -1 and force_spawn and p_is_friendly: # No free spots found, we gotta kill some other ship
        free_index = randi_range(0, (max_friendly_count-1))
        
    elif free_index == -1 and force_spawn and not p_is_friendly:
        free_index = randi_range(max_friendly_count, (Max_Num_Boids-1))
        
    elif free_index == -1 and force_spawn == false: # no free spots found... crap
        return false
    
    var start_health = 127 if p_is_friendly else -127
    var start_pos := Friendly_Spawn_Point.global_position if p_is_friendly else Enemy_Spawn_Point.global_position
    var start_transform := Transform3D.IDENTITY
    
    if p_is_friendly:
        #it is my sincerest hope, that I never have to touch godot and it's basis type ever again        
        
        Friendly_MultiMesh.multimesh.buffer[(free_index * 12)] = 1.0
        Friendly_MultiMesh.multimesh.buffer[(free_index * 12) + 3] = start_pos.x
        Friendly_MultiMesh.multimesh.buffer[(free_index * 12) + 5] = 1.0 
        Friendly_MultiMesh.multimesh.buffer[(free_index * 12) + 7] = start_pos.y
        Friendly_MultiMesh.multimesh.buffer[(free_index * 12) + 10] = 1.0
        Friendly_MultiMesh.multimesh.buffer[(free_index * 12) + 11] = start_pos.z
    else:
        Enemy_MultiMesh.multimesh.buffer[((free_index - max_friendly_count)  * 12)] = 1.0
        Enemy_MultiMesh.multimesh.buffer[((free_index - max_friendly_count) * 12) + 3] = start_pos.x
        Enemy_MultiMesh.multimesh.buffer[((free_index - max_friendly_count) * 12) + 5] = 1.0 
        Enemy_MultiMesh.multimesh.buffer[((free_index - max_friendly_count) * 12) + 7] = start_pos.y
        Enemy_MultiMesh.multimesh.buffer[((free_index - max_friendly_count) * 12) + 10] = 1.0
        Enemy_MultiMesh.multimesh.buffer[((free_index - max_friendly_count) * 12) + 11] = start_pos.z
        
    start_transform.origin = start_pos
    start_transform = start_transform.scaled(Vector3.ONE)
    start_transform = start_transform.looking_at(Vector3.DOWN)
    #ALL_ENTITIES_ent.encode_s8(free_index, start_health) 
    ALL_ENTITIES_ent[free_index] = start_health
    VELOCITIES_comp[free_index] = Vector3(randf_range(-0.02, 0.02), randf_range(-0.8, -4), randf_range(-0.02, 0.02)) # Start them off flying Downwards
    
    var cur_buffer_to_init : PackedFloat32Array
    var old_buffer_to_init : PackedFloat32Array
    
    cur_buffer_to_init = temp_friend_mesh_push_buffer if p_is_friendly else temp_enemy_mesh_push_buffer
    old_buffer_to_init = prev_friend_mesh_push_buffer if p_is_friendly else prev_enemy_mesh_push_buffer
    
    var start_index = free_index
    if not p_is_friendly:
        start_index -= max_friendly_count
    
    cur_buffer_to_init[(12 * start_index) + 0] = start_transform.basis.x.x
    cur_buffer_to_init[(12 * start_index) + 1] = start_transform.basis.y.x
    cur_buffer_to_init[(12 * start_index) + 2] = start_transform.basis.z.x
    cur_buffer_to_init[(12 * start_index) + 3] = start_transform.origin.x
    cur_buffer_to_init[(12 * start_index) + 4] = start_transform.basis.x.y
    cur_buffer_to_init[(12 * start_index) + 5] = start_transform.basis.y.y
    cur_buffer_to_init[(12 * start_index) + 6] = start_transform.basis.z.y
    cur_buffer_to_init[(12 * start_index) + 7] = start_transform.origin.y
    cur_buffer_to_init[(12 * start_index) + 8] = start_transform.basis.x.z
    cur_buffer_to_init[(12 * start_index) + 9] = start_transform.basis.y.z
    cur_buffer_to_init[(12 * start_index) + 10] = start_transform.basis.z.z
    cur_buffer_to_init[(12 * start_index) + 11] = start_transform.origin.z
    
    old_buffer_to_init[(12 * start_index) + 0] = start_transform.basis.x.x
    old_buffer_to_init[(12 * start_index) + 1] = start_transform.basis.y.x
    old_buffer_to_init[(12 * start_index) + 2] = start_transform.basis.z.x
    old_buffer_to_init[(12 * start_index) + 3] = start_transform.origin.x
    old_buffer_to_init[(12 * start_index) + 4] = start_transform.basis.x.y
    old_buffer_to_init[(12 * start_index) + 5] = start_transform.basis.y.y
    old_buffer_to_init[(12 * start_index) + 6] = start_transform.basis.z.y
    old_buffer_to_init[(12 * start_index) + 7] = start_transform.origin.y
    old_buffer_to_init[(12 * start_index) + 8] = start_transform.basis.x.z
    old_buffer_to_init[(12 * start_index) + 9] = start_transform.basis.y.z
    old_buffer_to_init[(12 * start_index) + 10] = start_transform.basis.z.z
    old_buffer_to_init[(12 * start_index) + 11] = start_transform.origin.z

    set_boid_transform(free_index, start_transform)
    
    
    return true



func spawn_friendly(force_spawn = false) -> bool:
    return spawn_ship(force_spawn, true)
        


func spawn_enemy(force_spawn = false) -> bool:
    var max_num_enemies_allowed : int = Enemy_Pool_Amount * (Max_Num_Boids - (Max_Num_Boids * Friendly_Enemy_Count_Ratio))
    if eeees < (max_num_enemies_allowed - 1):
        return spawn_ship(force_spawn, false)
    else:
        return false


## new_amount: 0.1 means increase the pool size from X by 10% (capped at 100%)
func Increase_Enemy_Pool_Size(new_amount: float):
    Enemy_Pool_Amount += new_amount
    Enemy_Pool_Amount = clampf(Enemy_Pool_Amount, 0.0001, 1.0)
    

## Decrease pool by X percent
func Decrease_Enemy_Pool_Size(reduction_amount : float):
    Enemy_Pool_Amount -= reduction_amount
    Enemy_Pool_Amount = clampf(Enemy_Pool_Amount, 0.0001, 1.0)

static var IS_PEACE_ACHIEVED : bool = false

static func Peace_Achieved():
    IS_PEACE_ACHIEVED = true
    
    
