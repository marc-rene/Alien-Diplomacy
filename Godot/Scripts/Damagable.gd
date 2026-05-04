extends Node3D
class_name Damageable


## Default Health
@export var Max_Health : float = 9000
@export var Can_Be_Damaged : bool = true

## The Mesh Instance that will have all the damage fx be applied to it
@export var Main_Mesh : MeshInstance3D

@export_group("Target Pulse FX")
@export var Target_Pulse_Enabled : bool = true
## Tint colour of the additive overlay layer placed on top of the existing material.
@export var Target_Pulse_Color : Color = Color(1.0, 0.15, 0.15, 1.0)
## How transparent the overlay is at the dim point of the pulse (0 means invisible)
@export_range(0.0, 1.0, 0.01, "prefer_slider") var Target_Pulse_Min_Alpha : float = 0.05
## How opaque the overlay is at the bright point of the pulse
@export_range(0.0, 1.0, 0.01, "prefer_slider") var Target_Pulse_Max_Alpha : float = 0.75
## Duration in seconds of one full dim -> bright -> dim cycle
@export_range(0.05, 5.0, 0.05, "prefer_slider") var Target_Pulse_Cycle_Duration : float = 1.4

var _current_health : float = Max_Health

var _target_pulse_tween : Tween = null
var _target_pulse_overlay_material : StandardMaterial3D = null
var _target_pulse_is_active : bool = false


func Apply_Damage(Damage_Amount : float):
    if Can_Be_Damaged == false:
        return
        
    _current_health -= Damage_Amount
    
    _on_damage_taken(Damage_Amount)
    
    if _current_health < 0:
        _on_destroyed()


## Get the 3D mesh that should have the damage FX applied to ut
func Get_Mesh() -> MeshInstance3D:
    if Main_Mesh != null:
        return Main_Mesh
    if $"." is MeshInstance3D:
        return $"." as MeshInstance3D
    return null


## Start a continuous red overlay pulse on this damageable.
## Calling repeatedly while already pulsing is a no-op (won't restart the loop).
## The overlay is rendered as an additional pass on top of the existing
## material, so the original albedo / shader is preserved.
func Pulse_Targeted_Red() -> void:
    if Target_Pulse_Enabled == false:
        return
    if _target_pulse_is_active:
        return

    var target_mesh : MeshInstance3D = Get_Mesh()
    if target_mesh == null:
        return

    if _target_pulse_overlay_material == null:
        _target_pulse_overlay_material = _build_pulse_overlay_material()

    target_mesh.material_overlay = _target_pulse_overlay_material
    _target_pulse_is_active = true
    _start_pulse_loop_tween()


## Stop the red overlay pulse and remove the overlay from the mesh.
func Stop_Pulse_Targeted_Red() -> void:
    if _target_pulse_tween != null and _target_pulse_tween.is_valid():
        _target_pulse_tween.kill()
    _target_pulse_tween = null

    var target_mesh : MeshInstance3D = Get_Mesh()
    if target_mesh != null and target_mesh.material_overlay == _target_pulse_overlay_material:
        target_mesh.material_overlay = null

    _target_pulse_is_active = false


func _start_pulse_loop_tween() -> void:
    if _target_pulse_overlay_material == null:
        return

    if _target_pulse_tween != null and _target_pulse_tween.is_valid():
        _target_pulse_tween.kill()

    var min_alpha : float = clampf(Target_Pulse_Min_Alpha, 0.0, 1.0)
    var max_alpha : float = clampf(Target_Pulse_Max_Alpha, 0.0, 1.0)
    if max_alpha < min_alpha:
        max_alpha = min_alpha

    var half_duration : float = max(Target_Pulse_Cycle_Duration * 0.5, 0.05)

    var dim_color : Color = Target_Pulse_Color
    dim_color.a = min_alpha
    var bright_color : Color = Target_Pulse_Color
    bright_color.a = max_alpha

    _target_pulse_overlay_material.albedo_color = dim_color

    _target_pulse_tween = create_tween()
    _target_pulse_tween.set_loops()
    _target_pulse_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    _target_pulse_tween.tween_property(_target_pulse_overlay_material, "albedo_color", bright_color, half_duration)
    _target_pulse_tween.tween_property(_target_pulse_overlay_material, "albedo_color", dim_color, half_duration)


func _build_pulse_overlay_material() -> StandardMaterial3D:
    var overlay_material : StandardMaterial3D = StandardMaterial3D.new()
    overlay_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    overlay_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    overlay_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    overlay_material.cull_mode = BaseMaterial3D.CULL_BACK
    overlay_material.disable_receive_shadows = true
    overlay_material.albedo_color = Color(
        Target_Pulse_Color.r,
        Target_Pulse_Color.g,
        Target_Pulse_Color.b,
        clampf(Target_Pulse_Min_Alpha, 0.0, 1.0)
    )
    return overlay_material


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
