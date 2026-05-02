extends Node
class_name Boid_Manager_V2

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


@export_group("Friendlys")
# Where will friendlys spawn?
## where we all gonna spawn from
@export var Friendly_Spawn_Point : Node3D

## what mesh we gonna use for the homies?
@export var Friendly_Mesh : MeshInstance3D

## what mesh we gonna use for enemies
@export var Friendly_MultiMesh : MultiMeshInstance3D



@export_group("Steering")
@export var max_speed : float = 2.0
@export var max_force : float = 10.0
@export var banking : float = 0.05
@export var mass : float = 2.0
@export var seek_weight : float = 1.0
@export var dont_crash_weight : float = 2.0
@export var return_back_to_reload_weight : float = 1.5
@export var near_crash_multiplier : float = 8.0
@export var avoid_radius_multiplier : float = 2.0
@export var avoid_padding : float = 0.3
@export var arrive_slowing_distance : float = 4.0
@export var reload_distance : float = 0.5
@export var reload_time_required : float = 10.0
@export var target_recheck_seconds : float = 5.0




# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
    pass
