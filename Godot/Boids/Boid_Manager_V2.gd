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

## what mesh we gonna use for enemies
@export var Friendly_MultiMesh : MultiMeshInstance3D

## what mesh we gonna use for friendly ships bolts when firing
@export var Friendly_Bolts_MultiMesh : MultiMeshInstance3D

@export_group("Enemies")
# Where will friendlys spawn?
## where we all gonna spawn from
@export var Enemy_Spawn_Point : Node3D

## what multimesh we gonna use for enemies
@export var Enemy_MultiMesh : MultiMeshInstance3D

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

@export var Friendly_Fire_Rate : float = 0.2
@export var Enemy_Fire_Rate : float = 1.0

## At what distance can a boid fire?
@export var Friendly_Firing_Distance : float = 2
@export var Enemy_Firing_Distance : float = 1.0 

## Whats the ammo capacity to reload to?
@export var Friendly_Ammo_Capacity : int = 50
@export var Enemy_Ammo_Capacity : int = 10 

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
var Ammo_COMP : PackedInt32Array

## Who are our boids targetting? 
## For friendlies, Lets get the index of the boid in question
## For enemies, which planet are we targetting?
var Friendly_Target_Enemy_Boid : PackedInt32Array

## For enemies, which planet they're targetting
@onready var planets_index := {
    1 : $OffbrandSolarSystem/PlanetEarthy,
    2 : $OffbrandSolarSystem/PlanetMoony,
    3 : $OffbrandSolarSystem/PlanetKnockOffJupiter,
    4 : $"OffbrandSolarSystem/THE GODDAMN SUN"
}


## What's the velocity of the boid at index i ?
var Velocities_COMP : PackedVector3Array 


var Friendly_Bolts : PackedVector3Array





# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
    pass
