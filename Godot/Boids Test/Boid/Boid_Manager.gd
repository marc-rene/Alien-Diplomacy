extends Node3D
class_name  Boid_Manager

# whats the absoilute maximum number of boids we can have??
@export_range(2, 200, 1, "prefer_slider") var Max_Num_Boids := 100

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


# Global Positions of all entities
# static var GLOBAL_POSITIONS_comp : PackedVector3Array


# Global Velocities of all entities
var VELOCITIES_comp : PackedVector3Array




var inited := false
func _ready():
    ALL_ENTITIES_ent = PackedByteArray()
    ALL_ENTITIES_ent.resize(Max_Num_Boids)
    ALL_ENTITIES_ent.fill(0)    # You're all deactivated!
    
    VELOCITIES_comp = PackedVector3Array()
    VELOCITIES_comp.resize(Max_Num_Boids)
    VELOCITIES_comp.fill(Vector3.ZERO)
    
    max_friendly_count = int(Friendly_Enemy_Count_Ratio * Max_Num_Boids)
    
    
    print("Max num of boids: %d\n\tFriendly boids: %d\n\tEnemy boids: %d" % [ALL_ENTITIES_ent.size(), max_friendly_count, Max_Num_Boids - max_friendly_count])
    
    Friendly_MultiMesh.multimesh.mesh = $Friendly_Mesh.mesh
    Enemy_MultiMesh.multimesh.mesh = $Enemy_Mesh.mesh
    
    #Friendly_MultiMesh.multimesh.transform_format = MultiMesh.TRANSFORM_3D # 3D format
    #Enemy_MultiMesh.multimesh.transform_format = MultiMesh.TRANSFORM_3D
    
    Friendly_MultiMesh.multimesh.instance_count = max_friendly_count
    Enemy_MultiMesh.multimesh.instance_count = Max_Num_Boids - max_friendly_count
    
    Friendly_MultiMesh.multimesh.visible_instance_count = max_friendly_count
    Enemy_MultiMesh.multimesh.visible_instance_count = Max_Num_Boids - max_friendly_count
    
    #for friend in max_friendly_count:
        #multimesh_mapping[friend] = friend
    #for enemy in max_enemy_count:
        #multimesh_mapping[max_friendly_count + enemy] = enemy
    inited = true




func is_alive(entity_index: int) -> bool:
    return ALL_ENTITIES_ent[entity_index] != 0


func is_friendly(entity_index: int) -> bool:
    return entity_index < max_friendly_count
    
    
func is_enemy(entity_index: int) -> bool:
    return entity_index >= max_friendly_count




func get_boid_transform(entity_index: int) -> Transform3D:
    if is_alive(entity_index) == false:
        return Transform3D.IDENTITY
    
    # multimesh buffer is a 4*3 matrix
    #var temp_trans := Transform3D(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)

    if is_friendly(entity_index):
        return Friendly_MultiMesh.multimesh.get_instance_transform(entity_index)
    else:
        return Enemy_MultiMesh.multimesh.get_instance_transform(entity_index - max_friendly_count)
            

            
var i := 0
func _process(delta: float) -> void:
    if not inited:
        return
    spawn_enemy()
    spawn_friendly()
    
    for ent in range(ALL_ENTITIES_ent.size()):
        if is_alive(ent):
            #print("Moving Ent #" + str(ent) + " from " + str(get_boid_transform(ent)) + " to " + str(get_boid_transform(ent).translated(VELOCITIES_comp[ent])) )
            #set_boid_transform(ent, (get_boid_transform(ent).translated(VELOCITIES_comp[ent]) * delta * 0.1) )
            var new_trans := get_boid_transform(ent)
            new_trans.origin += VELOCITIES_comp[ent] * delta
            new_trans.basis = Basis(Quaternion(Vector3.FORWARD, VELOCITIES_comp[ent].normalized()))
            
            set_boid_transform(ent, new_trans)



func _physics_process(delta: float) -> void:
    for ent in range(ALL_ENTITIES_ent.size()):
        if is_alive(ent):
            $Label3D.transform = get_boid_transform(ent)
            $Label3D.text = str(get_boid_transform(ent))
            Performance
            #print("#" + str(ent) + "\n\tPosit: " + str($Label3D.global_position) + "\n\tRotat" + str($Label3D.global_rotation) + "\n\tScale" + str($Label3D.scale) + "\n\tBasis" + str($Label3D.basis) + "\n\tTrans" + str($Label3D.global_transform) )
 
func spawn_mesh(is_friendly : bool):
    var targetted_multimesh = Friendly_MultiMesh if is_friendly else Enemy_MultiMesh
    

func set_boid_transform(ship_entity_index : int, new_transform : Transform3D):
    if ship_entity_index < max_friendly_count:
        Friendly_MultiMesh.multimesh.set_instance_transform(ship_entity_index, new_transform)
    else:
        Enemy_MultiMesh.multimesh.set_instance_transform((ship_entity_index-max_friendly_count), new_transform)
    
    
func spawn_ship(force_spawn : bool, is_friendly : bool) -> bool:
    var free_index : int
    
    if is_friendly:
        free_index = ALL_ENTITIES_ent.find(0) # any dead decatived boids?
        if is_enemy(free_index): # Only enemy spots are free
            free_index = -1
    
    else:
        free_index = ALL_ENTITIES_ent.find(0, max_friendly_count) # any dead decatived enemy boids?     
        
    if free_index == -1 and force_spawn and is_friendly: # No free spots found, we gotta kill some other ship
        free_index = randi_range(0, (max_friendly_count-1))
        
    elif free_index == -1 and force_spawn and not is_friendly:
        free_index = randi_range(max_friendly_count, (Max_Num_Boids-1))
        
    elif free_index == -1 and force_spawn == false: # no free spots found... crap
        return false
    
    var start_health = 127 if is_friendly else -127
    var start_pos := Friendly_Spawn_Point.global_position if is_friendly else Enemy_Spawn_Point.global_position
    var start_transform := Transform3D.IDENTITY
    
    if is_friendly:
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
    VELOCITIES_comp[free_index] = Vector3.DOWN  # Start them off flying Downwards
    
    set_boid_transform(free_index, start_transform)
    
    

    
    return true



func spawn_friendly(force_spawn = false) -> bool:
    return spawn_ship(force_spawn, true)
        


func spawn_enemy(force_spawn = false) -> bool:
    return spawn_ship(force_spawn, false)
    
    
    
    
