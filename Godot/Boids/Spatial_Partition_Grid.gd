extends Area3D
class_name Spatial_Grid

@export var Partition_Cell_Size : float = 2.0
@export var Partition_Enabled : bool = true

## TODO: If there's any boids inside a grid cube, should the grid cube be lit up a bit with a new 
@export var DEBUG_Show_Highlight_material_at_active_grid : bool = false

const _CELL_COORD_MASK : int = 0x1FFFFF
const _CELL_COORD_OFFSET : int = 1048576
const _CELL_COORD_MAX : int = 1048575
const _NO_CELL : int = -1
const _DEBUG_OPACITY_PER_BOID : float = 0.125

var _cell_to_entity_indices : Dictionary[int, PackedInt32Array] = {}
var _next_cell_to_entity_indices : Dictionary[int, PackedInt32Array] = {}

var _spatial_partition_check_thread : Thread = null
var _thread_swap_mutex : Mutex = Mutex.new()
var _thread_should_exit : bool = false
var _thread_has_new_grid_data : bool = false

var _debug_active_cells_visual : MultiMeshInstance3D = null

static var Spatial_Grid_Instance : Spatial_Grid = null


static func Get_Instance() -> Spatial_Grid:
    if is_instance_valid(Spatial_Grid_Instance):
        return Spatial_Grid_Instance

    var scene_tree : SceneTree = Engine.get_main_loop() as SceneTree
    if scene_tree == null:
        return null

    var current_scene : Node = scene_tree.current_scene
    if current_scene == null:
        return null

    var spatial_grid_node : Node = current_scene.get_node_or_null("Spatial Partitioning Grid")
    if spatial_grid_node is Spatial_Grid:
        Spatial_Grid_Instance = spatial_grid_node as Spatial_Grid

    return Spatial_Grid_Instance


## TODO: Get the Cell ID based off the given Vector3 location.
static func Get_ID_of_Cell_from_Location(World_Location : Vector3) -> int:
    var spatial_grid : Spatial_Grid = Get_Instance()
    if spatial_grid == null:
        return _NO_CELL
    if spatial_grid.Partition_Enabled == false:
        return _NO_CELL

    var safe_cell_size : float = max(spatial_grid.Partition_Cell_Size, 0.001)
    var cell_x : int = int(floor(World_Location.x / safe_cell_size))
    var cell_y : int = int(floor(World_Location.y / safe_cell_size))
    var cell_z : int = int(floor(World_Location.z / safe_cell_size))
    return _pack_cell_coordinates(cell_x, cell_y, cell_z)


static func _pack_cell_coordinates(cell_x: int, cell_y: int, cell_z: int) -> int:
    var clamped_x : int = clampi(cell_x, -_CELL_COORD_OFFSET, _CELL_COORD_MAX)
    var clamped_y : int = clampi(cell_y, -_CELL_COORD_OFFSET, _CELL_COORD_MAX)
    var clamped_z : int = clampi(cell_z, -_CELL_COORD_OFFSET, _CELL_COORD_MAX)

    var packed_x : int = (clamped_x + _CELL_COORD_OFFSET) & _CELL_COORD_MASK
    var packed_y : int = (clamped_y + _CELL_COORD_OFFSET) & _CELL_COORD_MASK
    var packed_z : int = (clamped_z + _CELL_COORD_OFFSET) & _CELL_COORD_MASK

    return (packed_x << 42) | (packed_y << 21) | packed_z


static func _unpack_cell_coordinates(cell_id: int) -> Vector3i:
    var packed_x : int = (cell_id >> 42) & _CELL_COORD_MASK
    var packed_y : int = (cell_id >> 21) & _CELL_COORD_MASK
    var packed_z : int = cell_id & _CELL_COORD_MASK

    var cell_x : int = packed_x - _CELL_COORD_OFFSET
    var cell_y : int = packed_y - _CELL_COORD_OFFSET
    var cell_z : int = packed_z - _CELL_COORD_OFFSET
    return Vector3i(cell_x, cell_y, cell_z)


## TODO: Get all entitys in the Cell that belongs to Whatever Cell_ID we give. check for neighbours too
static func Get_All_Boids_in_Cell(Cell_ID:int, include_neighbouring_cells : bool = true) -> PackedInt32Array:
    var all_nearby_boids : PackedInt32Array = PackedInt32Array()
    var spatial_grid : Spatial_Grid = Get_Instance()
    if spatial_grid == null:
        return all_nearby_boids
    if spatial_grid.Partition_Enabled == false:
        return all_nearby_boids
    if Cell_ID == _NO_CELL:
        return all_nearby_boids

    if include_neighbouring_cells == false:
        return spatial_grid._cell_to_entity_indices.get(Cell_ID, PackedInt32Array())

    var base_coords : Vector3i = _unpack_cell_coordinates(Cell_ID)
    var dx : int = -1
    while dx <= 1:
        var dy : int = -1
        while dy <= 1:
            var dz : int = -1
            while dz <= 1:
                var neighbour_id : int = _pack_cell_coordinates(base_coords.x + dx, base_coords.y + dy, base_coords.z + dz)
                var boids_in_cell : PackedInt32Array = spatial_grid._cell_to_entity_indices.get(neighbour_id, PackedInt32Array())
                var boid_i : int = 0
                while boid_i < boids_in_cell.size():
                    all_nearby_boids.push_back(boids_in_cell[boid_i])
                    boid_i += 1
                dz += 1
            dy += 1
        dx += 1

    return all_nearby_boids


func _ready() -> void:
    # TODO: Fill out _cell_to_entity_indices... We should fill them in based off our Area3D and collision shape, and our grid cell size
    Spatial_Grid_Instance = self
    _cell_to_entity_indices = {}
    _next_cell_to_entity_indices = {}

    if Partition_Cell_Size <= 0.0:
        Partition_Cell_Size = 2.0

    _thread_should_exit = false
    _thread_has_new_grid_data = false
    _spatial_partition_check_thread = Thread.new()
    _spatial_partition_check_thread.start(_spatial_partition_thread_loop)
    _setup_debug_visuals()


func _exit_tree() -> void:
    _thread_should_exit = true
    if _spatial_partition_check_thread != null and _spatial_partition_check_thread.is_started():
        _spatial_partition_check_thread.wait_to_finish()
    if is_instance_valid(Spatial_Grid_Instance) and Spatial_Grid_Instance == self:
        Spatial_Grid_Instance = null
    if is_instance_valid(_debug_active_cells_visual):
        _debug_active_cells_visual.queue_free()
        _debug_active_cells_visual = null


func _setup_debug_visuals() -> void:
    _debug_active_cells_visual = MultiMeshInstance3D.new()
    _debug_active_cells_visual.name = "Runtime_Debug_Active_Grid_Cells"
    _debug_active_cells_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _debug_active_cells_visual.visible = false

    var active_cells_multimesh : MultiMesh = MultiMesh.new()
    active_cells_multimesh.transform_format = MultiMesh.TRANSFORM_3D
    active_cells_multimesh.use_colors = true
    active_cells_multimesh.instance_count = 0
    _debug_active_cells_visual.multimesh = active_cells_multimesh

    var cell_box_mesh : BoxMesh = BoxMesh.new()
    cell_box_mesh.size = Vector3.ONE * max(Partition_Cell_Size * 0.98, 0.01)

    var debug_material : StandardMaterial3D = StandardMaterial3D.new()
    debug_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    debug_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    debug_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    debug_material.albedo_color = Color(1.0, 0.2, 0.08, 0.15)
    debug_material.emission_enabled = true
    debug_material.emission = Color(1.0, 0.2, 0.08)
    debug_material.emission_energy_multiplier = 0.35
    cell_box_mesh.material = debug_material

    _debug_active_cells_visual.multimesh.mesh = cell_box_mesh
    add_child(_debug_active_cells_visual)


func _update_debug_active_cells_visuals() -> void:
    if is_instance_valid(_debug_active_cells_visual) == false:
        return

    if DEBUG_Show_Highlight_material_at_active_grid == false or Partition_Enabled == false:
        _debug_active_cells_visual.visible = false
        _debug_active_cells_visual.multimesh.instance_count = 0
        return

    var active_cells_multimesh : MultiMesh = _debug_active_cells_visual.multimesh
    if active_cells_multimesh == null:
        return
    if active_cells_multimesh.mesh is BoxMesh:
        var cell_box_mesh : BoxMesh = active_cells_multimesh.mesh as BoxMesh
        cell_box_mesh.size = Vector3.ONE * max(Partition_Cell_Size * 0.98, 0.01)

    var cell_keys : Array = _cell_to_entity_indices.keys()
    var active_cell_count : int = cell_keys.size()

    if active_cell_count <= 0:
        _debug_active_cells_visual.visible = false
        active_cells_multimesh.instance_count = 0
        return

    active_cells_multimesh.instance_count = active_cell_count
    active_cells_multimesh.visible_instance_count = active_cell_count
    _debug_active_cells_visual.visible = true

    var visual_index : int = 0
    while visual_index < active_cell_count:
        var cell_id : int = int(cell_keys[visual_index])
        var boids_in_cell : PackedInt32Array = _cell_to_entity_indices.get(cell_id, PackedInt32Array())
        var boid_count_in_cell : int = boids_in_cell.size()
        var cell_coords : Vector3i = _unpack_cell_coordinates(cell_id)
        var safe_cell_size : float = max(Partition_Cell_Size, 0.001)
        var cell_center : Vector3 = Vector3(
            (float(cell_coords.x) + 0.5) * safe_cell_size,
            (float(cell_coords.y) + 0.5) * safe_cell_size,
            (float(cell_coords.z) + 0.5) * safe_cell_size
        )
        var visual_transform : Transform3D = Transform3D(Basis.IDENTITY, cell_center)
        active_cells_multimesh.set_instance_transform(visual_index, visual_transform)

        var alpha : float = clampf(float(boid_count_in_cell) * _DEBUG_OPACITY_PER_BOID, 0.0, 1.0)
        active_cells_multimesh.set_instance_color(visual_index, Color(1.0, 0.2, 0.08, alpha))
        visual_index += 1


## TODO:  Cycle through the Boid_Manager_V2 buffer (previous one) and determine the Cell_ID that each boid belongs to
func _check_boids_positions_and_grid_cells() -> void:
    var generated_cell_data : Dictionary[int, PackedInt32Array] = {}
    if Partition_Enabled == false:
        _thread_swap_mutex.lock()
        _next_cell_to_entity_indices = generated_cell_data
        _thread_has_new_grid_data = true
        _thread_swap_mutex.unlock()
        return

    var boid_manager_instance : Boid_Manager_V2 = Boid_Manager_V2.Get_Instance()
    if boid_manager_instance == null:
        _thread_swap_mutex.lock()
        _next_cell_to_entity_indices = generated_cell_data
        _thread_has_new_grid_data = true
        _thread_swap_mutex.unlock()
        return

    var safe_cell_size : float = max(Partition_Cell_Size, 0.001)
    var total_boids : int = boid_manager_instance.MAX_NUMBER_OF_BOIDS
    var friendly_slots : int = int(float(total_boids) * boid_manager_instance.Friendly_Enemy_Count_Ratio)
    friendly_slots = clampi(friendly_slots, 0, total_boids)

    var old_friendly_buffer : PackedVector3Array = Boid_Manager_V2.Get_Old_Boid_Buffer(true)
    var old_enemy_buffer : PackedVector3Array = Boid_Manager_V2.Get_Old_Boid_Buffer(false)
    var all_entities : PackedByteArray = boid_manager_instance.All_Entities_ENT

    var boid_index : int = 0
    while boid_index < total_boids:
        if boid_index >= all_entities.size():
            break

        var health_state : int = int(all_entities[boid_index])
        var is_alive : bool = health_state != 0
        if is_alive:
            var boid_position : Vector3 = Vector3.ZERO
            var position_buffer_index : int = 0
            var has_transform_data : bool = false

            if boid_index < friendly_slots:
                position_buffer_index = (boid_index * 4) + 3
                if position_buffer_index < old_friendly_buffer.size():
                    boid_position = old_friendly_buffer[position_buffer_index]
                    has_transform_data = true
            else:
                var enemy_index : int = boid_index - friendly_slots
                position_buffer_index = (enemy_index * 4) + 3
                if position_buffer_index < old_enemy_buffer.size():
                    boid_position = old_enemy_buffer[position_buffer_index]
                    has_transform_data = true

            if has_transform_data:
                var cell_x : int = int(floor(boid_position.x / safe_cell_size))
                var cell_y : int = int(floor(boid_position.y / safe_cell_size))
                var cell_z : int = int(floor(boid_position.z / safe_cell_size))
                var cell_id : int = _pack_cell_coordinates(cell_x, cell_y, cell_z)
                var boids_in_cell : PackedInt32Array = generated_cell_data.get(cell_id, PackedInt32Array())
                boids_in_cell.push_back(boid_index)
                generated_cell_data.set(cell_id, boids_in_cell)
        boid_index += 1

    _thread_swap_mutex.lock()
    _next_cell_to_entity_indices = generated_cell_data
    _thread_has_new_grid_data = true
    _thread_swap_mutex.unlock()


func _spatial_partition_thread_loop() -> void:
    while _thread_should_exit == false:
        _check_boids_positions_and_grid_cells()
        OS.delay_msec(16)


## When given a start position, and a direction, and a "Range", figure out what cells are in front of you
## This will be helpful for friendly boids who want to try figure out of there's any enemies in their cone of vision
static func Get_Cells_in_Cone(
    start_world_location: Vector3,
    forward_direction: Vector3,
    range_in_cells: int,
    half_angle_degrees: float = 20.0,
    include_empty_cells: bool = false
) -> PackedInt32Array:
    var cone_cell_ids : PackedInt32Array = PackedInt32Array()
    var spatial_grid : Spatial_Grid = Get_Instance()
    if spatial_grid == null:
        return cone_cell_ids
    if spatial_grid.Partition_Enabled == false:
        return cone_cell_ids

    var normalised_forward : Vector3 = forward_direction.normalized()
    if normalised_forward.length_squared() <= 0.000001:
        return cone_cell_ids

    var safe_range_in_cells : int = max(1, range_in_cells)
    var safe_cell_size : float = max(spatial_grid.Partition_Cell_Size, 0.001)
    var safe_half_angle_degrees : float = clampf(half_angle_degrees, 1.0, 89.0)
    var cone_cosine_threshold : float = cos(deg_to_rad(safe_half_angle_degrees))
    var cone_radius_scale : float = tan(deg_to_rad(safe_half_angle_degrees))
    var max_world_distance : float = (float(safe_range_in_cells) * safe_cell_size) + (safe_cell_size * 0.5)

    var seen_cell_ids : Dictionary[int, bool] = {}
    var step_index : int = 0
    while step_index <= safe_range_in_cells:
        var step_world_distance : float = float(step_index) * safe_cell_size
        var cone_centre : Vector3 = start_world_location + (normalised_forward * step_world_distance)
        var radius_world : float = step_world_distance * cone_radius_scale
        var radius_cells : int = int(ceil(radius_world / safe_cell_size))
        radius_cells = max(radius_cells, 0)

        var offset_x : int = -radius_cells
        while offset_x <= radius_cells:
            var offset_y : int = -radius_cells
            while offset_y <= radius_cells:
                var offset_z : int = -radius_cells
                while offset_z <= radius_cells:
                    var cell_offset_world : Vector3 = Vector3(float(offset_x), float(offset_y), float(offset_z)) * safe_cell_size
                    var candidate_world_location : Vector3 = cone_centre + cell_offset_world
                    var to_candidate : Vector3 = candidate_world_location - start_world_location
                    var distance_to_candidate : float = to_candidate.length()
                    if distance_to_candidate > max_world_distance:
                        offset_z += 1
                        continue

                    var should_include : bool = false
                    if distance_to_candidate <= 0.000001:
                        should_include = true
                    else:
                        var candidate_direction : Vector3 = to_candidate / max(distance_to_candidate, 0.000001)
                        var directional_dot : float = candidate_direction.dot(normalised_forward)
                        should_include = directional_dot >= cone_cosine_threshold

                    if should_include:
                        var candidate_cell_id : int = Get_ID_of_Cell_from_Location(candidate_world_location)
                        if candidate_cell_id != _NO_CELL and seen_cell_ids.has(candidate_cell_id) == false:
                            if include_empty_cells or spatial_grid._cell_to_entity_indices.has(candidate_cell_id):
                                seen_cell_ids.set(candidate_cell_id, true)
                                cone_cell_ids.push_back(candidate_cell_id)
                    offset_z += 1
                offset_y += 1
            offset_x += 1
        step_index += 1

    return cone_cell_ids


static func Get_Boids_in_Cone(
    start_world_location: Vector3,
    forward_direction: Vector3,
    range_in_cells: int,
    half_angle_degrees: float = 20.0,
    only_enemy_boids: bool = true
) -> PackedInt32Array:
    var boids_in_cone : PackedInt32Array = PackedInt32Array()
    var spatial_grid : Spatial_Grid = Get_Instance()
    if spatial_grid == null:
        return boids_in_cone
    if spatial_grid.Partition_Enabled == false:
        return boids_in_cone

    var boid_manager_instance : Boid_Manager_V2 = Boid_Manager_V2.Get_Instance()
    if boid_manager_instance == null:
        return boids_in_cone

    var candidate_cells : PackedInt32Array = Get_Cells_in_Cone(
        start_world_location,
        forward_direction,
        range_in_cells,
        half_angle_degrees,
        false
    )
    if candidate_cells.is_empty():
        return boids_in_cone

    var seen_boid_indices : Dictionary[int, bool] = {}
    var all_entities : PackedByteArray = boid_manager_instance.All_Entities_ENT
    var cell_i : int = 0
    while cell_i < candidate_cells.size():
        var cell_id : int = candidate_cells[cell_i]
        var boids_in_cell : PackedInt32Array = Get_All_Boids_in_Cell(cell_id, false)
        var boid_i : int = 0
        while boid_i < boids_in_cell.size():
            var boid_index : int = boids_in_cell[boid_i]
            if boid_index >= 0 and boid_index < all_entities.size():
                if seen_boid_indices.has(boid_index) == false:
                    var health_state : int = int(all_entities[boid_index])
                    var is_alive : bool = health_state != 0
                    if is_alive:
                        var is_enemy : bool = health_state < 0
                        if only_enemy_boids == false or is_enemy:
                            seen_boid_indices.set(boid_index, true)
                            boids_in_cone.push_back(boid_index)
            boid_i += 1
        cell_i += 1

    return boids_in_cone


func _physics_process(_delta: float) -> void:
    if _thread_has_new_grid_data:
        _thread_swap_mutex.lock()
        if _thread_has_new_grid_data:
            _cell_to_entity_indices = _next_cell_to_entity_indices
            _thread_has_new_grid_data = false
        _thread_swap_mutex.unlock()

    _update_debug_active_cells_visuals()
