extends Node3D
class_name  Boid_Manager

# whats the absoilute maximum number of boids we can have??
@export_range(2, 200, 1, "prefer_slider") var Max_Num_Boids = 100

# How do we want to divide up our friendlies? (Assuming we want 100 boids max)
#   0.5 == Equal num of Friends V Enemy (50 v 50)
#   0.1 == Small num of Friends V CRAP LOADS of Enemy (10 v 90) 
@export_range(0, 1, 0.01, "prefer_slider") var Friendly_Enemy_Count_Ratio = 0.5

@export_group("Friendlys")
# Where will friendlys spawn?
@export var Friendly_Spawn_Point : Node3D   
@export var Friendly_Mesh : MeshInstance3D
@export var Friendly_MultiMesh : MultiMeshInstance3D
static var max_friendly_count := 0

@export_group("Enemies")
# Where will enemies spawn?
@export var Enemy_Spawn_Point : Node3D   
@export var Enemy_Mesh : MeshInstance3D
@export var Enemy_MultiMesh : MultiMeshInstance3D
static var max_enemy_count := 0


static var multimesh_mapping : Dictionary # {Entity index : index in multimesh}


# SO here's the naming convention
# Entities will end in _ent
# componenets (like velocity, etc...) end with _comp

# Our entities will have their health and team based off the ALL_ENTITIES_ent
# It's a packed signed-byte array, because we'll only have 3 states:
#   -127 -> -1  (You're on Enemy team, and you have X health)
#   0           (Yo you is deactivated / dead) 
#   1 -> 127    (You're on Friendly team, and you have X health
static var ALL_ENTITIES_ent : PackedByteArray


# Global Positions of all entities
static var GLOBAL_POSITIONS_comp : PackedVector3Array


# Global Velocities of all entities
static var VELOCITIES_comp : PackedVector3Array





func _ready():
    ALL_ENTITIES_ent.resize(Max_Num_Boids)
    ALL_ENTITIES_ent.fill(0)    # You're all deactivated!
    
    GLOBAL_POSITIONS_comp.resize(Max_Num_Boids)
    GLOBAL_POSITIONS_comp.fill(Vector3.ZERO)
    
    max_friendly_count = int(Friendly_Enemy_Count_Ratio * Max_Num_Boids)
    max_enemy_count = Max_Num_Boids - Friendly_Enemy_Count_Ratio
    
    
    print("Max num of boids: %d\n\tFriendly boids: %d\n\tEnemy boids: %d" % [ALL_ENTITIES_ent.size(), max_friendly_count, max_enemy_count])
    
    Friendly_MultiMesh.multimesh.mesh = $Friendly_Mesh.mesh
    Enemy_MultiMesh.multimesh.mesh = $Enemy_Mesh.mesh
    
    Friendly_MultiMesh.multimesh.transform_format = MultiMesh.TRANSFORM_3D # 3D format
    Enemy_MultiMesh.multimesh.transform_format = MultiMesh.TRANSFORM_3D
    
    Friendly_MultiMesh.multimesh.instance_count = max_friendly_count
    Enemy_MultiMesh.multimesh.instance_count = max_enemy_count
    
    Friendly_MultiMesh.multimesh.visible_instance_count = 0
    Enemy_MultiMesh.multimesh.visible_instance_count = 0
    
        
    
    
    
func spawn_mesh(is_friendly : bool):
    var targetted_multimesh = Friendly_MultiMesh if is_friendly else Enemy_MultiMesh
    

    
func spawn_ship(force_spawn : bool, is_friendly : bool) -> bool:
    var free_index : int
    
    if is_friendly:
        free_index = ALL_ENTITIES_ent.find(0) # any dead decatived boids?
        if free_index >= max_friendly_count: # Only enemy spots are free
            free_index = -1
    
    else:
        free_index = ALL_ENTITIES_ent.find(0, max_friendly_count) # any dead decatived enemy boids?
        
        
    if free_index == -1 and force_spawn: # No free spots found, we gotta kill some other ship
        free_index = randi_range(0, (ALL_ENTITIES_ent.size() - 1))
        
    elif free_index == -1 and force_spawn == false: # no free spots found... crap
        return false
    
    var start_health = 127 if is_friendly else -127
    var start_pos = Friendly_Spawn_Point.global_position if is_friendly else Enemy_Spawn_Point.global_position
    
    #ALL_ENTITIES_ent.encode_s8(free_index, start_health) 
    ALL_ENTITIES_ent[free_index] = start_health
    GLOBAL_POSITIONS_comp[free_index] = start_pos
    VELOCITIES_comp[free_index] = Vector3.DOWN  # Start them off flying Downwards
    
    if is_friendly:
        multimesh_mapping[free_index]
        
    
    return true



func spawn_friendly(force_spawn = false) -> bool:
    return spawn_ship(force_spawn, true)
        


func spawn_enemy(force_spawn = false) -> bool:
    return spawn_ship(force_spawn, false)
    
    
    
    
