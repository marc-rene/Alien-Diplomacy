extends Node3D
class_name Damageable


## Default Health
@export var Max_Health : float = 9000
@export var Can_Be_Damaged : bool = true

## The Mesh Instance that will have all the damage fx be applied to it
@export var Main_Mesh : MeshInstance3D

var _current_health : float = Max_Health

func Apply_Damage(Damage_Amount : float):
    if Can_Be_Damaged == false:
        return
        
    _current_health -= Damage_Amount
    
    _on_damage_taken(Damage_Amount)
    
    if _current_health < 0:
        _on_destroyed()


## Get the 3D mesh that should have the damage FX applied to ut
func Get_Mesh() -> MeshInstance3D:
    if Main_Mesh == null:
        return $"."
    return Main_Mesh


func Apply_Healing(Heal_Amount : float):
    _current_health += Heal_Amount
    
    _on_healing_taken(Heal_Amount)
    
    if _current_health > Max_Health:
        _current_health = Max_Health
    


## When something heals, it should pulse green or something
func _on_healing_taken(heal_amount : float):
    pass
    
    
## When a planet takes damage, it should pulse red or do something, a mothership should do something else
func _on_damage_taken(damage_amount : float):
    pass


## When a planet takes damage, it should pulse red or do something, a mothership should do something else
func _on_destroyed():
    pass
