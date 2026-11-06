extends RefCounted
## Worker of tools/build_movement_gym.gd: builds the movement gym (D-20) node tree from Prototype Bits wrappers.
## The launcher is compiled before the autoloads exist, so the typed gym code lives here, loaded at run time.
## Re-running reproduces the same file. The gym uses no new assets: only scenes/proto wrappers, the Player,
## the CameraRig, the debug overlays and Label3D text markings (A33). Every coordinate is on the 1 m grid
## except the 20 degree ramp, which is rotated by definition.
##
## Plan view (x east, z south, forward = -z, hall x -42..42, z -50..34, tiles on a 4 m lattice):
##   lane (x 0, z 0..-40), height references (z -6, x 8..20), ramps/stairs/ledges (x 6..40, z -48..-10),
##   gap course (x -38 column z 34..-22, then z -20 row x -38..-4), passage (z -2, x -26..-10),
##   conveyors (z 12 and 20, x -26..-10), pillar forest (x -6..10, z 10..31), moving platforms (x 14..38, z 10..34).

const PROTO: String = "res://scenes/proto/"
const FLOOR: String = PROTO + "primitive_floor.tscn"
const WALL: String = PROTO + "primitive_wall.tscn"
const CUBE: String = PROTO + "primitive_cube_small.tscn"
const PILLAR: String = PROTO + "primitive_pillar.tscn"
const SLOPE: String = PROTO + "primitive_slope.tscn"
const BEAM: String = PROTO + "primitive_beam.tscn"
const PLATFORM: String = PROTO + "moving_platform.tscn"
const PLAYER: String = "res://scenes/player/player.tscn"
const CAMERA_RIG: String = "res://scenes/camera/camera_rig.tscn"
const EVENT_LOG: String = "res://scenes/debug/event_log.tscn"
const METRICS_OVERLAY: String = "res://scenes/debug/metrics_overlay.tscn"
const TUNING_PANEL: String = "res://scenes/debug/tuning_panel.tscn"
const HIT_PUFFS: String = "res://scenes/debug/hit_puffs.tscn"

## Hall lattice: cell (i, j) is a 4 m tile centred at (4 i, 4 j), top at y 0.
const CELLS_X: Vector2i = Vector2i(-10, 10)
const CELLS_Z: Vector2i = Vector2i(-12, 8)
const TILE: float = 4.0

const MARKER_FONT_SIZE: int = 64
const MARKER_PIXEL_SIZE: float = 0.01

var _root: Node3D
var _scenes: Dictionary[String, PackedScene] = {}
## Lattice cells that a zone fills itself (conveyors, the lift hole). Key: Vector2i cell.
var _taken_cells: Dictionary[Vector2i, bool] = {}
## Pit rectangles in xz (Rect2: position x, z; size width, depth). Lattice cells that overlap one stay empty.
var _pits: Array[Rect2] = []
## Empty after a successful build().
var failure: String = ""


## Returns the gym root, or null with `failure` set. The tree is never added to a SceneTree, so no _ready runs.
func build() -> Node3D:
	_root = Node3D.new()
	_root.name = "MovementGym"

	_build_environment()
	var hall: Node3D = _group(_root, "Hall")
	var spawn: Marker3D = Marker3D.new()
	_adopt(_root, spawn, "Spawn", Vector3.ZERO)
	var player: Node3D = _instance(_root, PLAYER, "Player", Vector3.ZERO)
	var rig: Node3D = _instance(_root, CAMERA_RIG, "CameraRig", Vector3.ZERO)
	rig.set("target", player)

	# Zones first: they register pits and taken cells that the hall lattice honours.
	_build_measurement_strip(_group(_root, "Zone_MeasurementStrip"))
	_build_ramps_stairs(_group(_root, "Zone_RampsStairs"))
	_build_gaps(_group(_root, "Zone_Gaps"), spawn, rig)
	_build_moving_platforms(_group(_root, "Zone_MovingPlatforms"))
	_build_conveyors(_group(_root, "Zone_Conveyors"))
	_build_camera_tests(_group(_root, "Zone_CameraTests"))
	_build_hall(hall)

	var hall_reset: Area3D = _fall_reset("FallResetHall", Vector3(0.0, -30.0, -8.0), Vector3(160.0, 4.0, 160.0), spawn, rig)
	_root.add_child(hall_reset)
	hall_reset.owner = _root
	_owner_children(hall_reset)

	_instance_node(_root, EVENT_LOG, "EventLog")
	_instance_node(_root, METRICS_OVERLAY, "MetricsOverlay")
	_instance_node(_root, TUNING_PANEL, "TuningPanel")
	_instance_node(_root, HIT_PUFFS, "HitPuffs")

	if failure != "":
		_root.free()
		return null
	return _root


# --- construction helpers -----------------------------------------------------------------------------------


func _group(parent: Node, node_name: String) -> Node3D:
	var node: Node3D = Node3D.new()
	_adopt(parent, node, node_name, Vector3.ZERO)
	return node


func _adopt(parent: Node, node: Node, node_name: String, position: Vector3, basis: Basis = Basis.IDENTITY) -> void:
	node.name = node_name
	var spatial: Node3D = node as Node3D
	if spatial != null:
		spatial.transform = Transform3D(basis, position)
	parent.add_child(node)
	node.owner = _root


func _instance(parent: Node, path: String, node_name: String, position: Vector3, basis: Basis = Basis.IDENTITY) -> Node3D:
	var node: Node = _instance_node(parent, path, node_name)
	var spatial: Node3D = node as Node3D
	if spatial == null:
		failure = "%s is not a Node3D scene" % path
		return Node3D.new()
	spatial.transform = Transform3D(basis, position)
	return spatial


## Instances any scene (the debug overlays are CanvasLayers). The instance root gets the gym as owner.
func _instance_node(parent: Node, path: String, node_name: String) -> Node:
	if not _scenes.has(path):
		var loaded: PackedScene = load(path) as PackedScene
		if loaded == null:
			failure = "cannot load %s" % path
			return Node3D.new()
		_scenes[path] = loaded
	var node: Node = _scenes[path].instantiate()
	node.name = node_name
	parent.add_child(node)
	node.owner = _root
	return node


## Only nodes that were added directly need an owner here; instance internals stay unowned so the scene keeps
## the instance reference instead of copying the wrapper.
func _owner_children(node: Node) -> void:
	for child: Node in node.get_children():
		child.owner = _root
		_owner_children(child)


func _yaw(degrees: float) -> Basis:
	return Basis(Vector3.UP, deg_to_rad(degrees))


func _label(parent: Node, node_name: String, text: String, position: Vector3) -> void:
	var label: Label3D = Label3D.new()
	label.text = text
	label.font_size = MARKER_FONT_SIZE
	label.pixel_size = MARKER_PIXEL_SIZE
	label.outline_size = 12
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.shaded = false
	_adopt(parent, label, node_name, position)


func _floor_tile(parent: Node, node_name: String, x: float, top: float, z: float) -> Node3D:
	return _instance(parent, FLOOR, node_name, Vector3(x, top - 1.0, z))


func _wall(parent: Node, node_name: String, x: float, z: float, yaw_degrees: float, bottom: float = 0.0) -> Node3D:
	return _instance(parent, WALL, node_name, Vector3(x, bottom, z), _yaw(yaw_degrees))


func _fall_reset(node_name: String, centre: Vector3, size: Vector3, respawn: Node3D, rig: Node3D) -> FallReset:
	var area: FallReset = FallReset.new()
	area.name = node_name
	area.position = centre
	area.respawn = respawn
	area.camera_rig = rig as CameraRig
	area.add_child(_box_shape("CollisionShape3D", size))
	return area


func _box_shape(node_name: String, size: Vector3, centre: Vector3 = Vector3.ZERO) -> CollisionShape3D:
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	shape_node.name = node_name
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape_node.shape = box
	shape_node.position = centre
	return shape_node


# --- environment --------------------------------------------------------------------------------------------


func _build_environment() -> void:
	var sky_material: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	var sky: Sky = Sky.new()
	sky.sky_material = sky_material
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	world_environment.environment = environment
	_adopt(_root, world_environment, "WorldEnvironment", Vector3.ZERO)

	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.shadow_enabled = true
	var sun_basis: Basis = Basis(
		Vector3(0.866025, 0.0, 0.5),
		Vector3(0.383022, 0.642788, -0.663414),
		Vector3(-0.321394, 0.766044, 0.55667),
	)
	_adopt(_root, sun, "Sun", Vector3.ZERO, sun_basis)


# --- hall ---------------------------------------------------------------------------------------------------


func _build_hall(hall: Node3D) -> void:
	for i: int in range(CELLS_X.x, CELLS_X.y + 1):
		for j: int in range(CELLS_Z.x, CELLS_Z.y + 1):
			var cell: Vector2i = Vector2i(i, j)
			if _taken_cells.has(cell) or _in_pit(cell):
				continue
			_floor_tile(hall, "Floor_%s_%s" % [_cell_name(i), _cell_name(j)], i * TILE, 0.0, j * TILE)

	var x_edge: float = CELLS_X.y * TILE + TILE * 0.5 + 0.5
	var z_north: float = CELLS_Z.x * TILE - TILE * 0.5 - 0.5
	var z_south: float = CELLS_Z.y * TILE + TILE * 0.5 + 0.5
	for i: int in range(CELLS_X.x, CELLS_X.y + 1):
		_wall(hall, "WallNorth_%s" % _cell_name(i), i * TILE, z_north, 0.0)
		_wall(hall, "WallSouth_%s" % _cell_name(i), i * TILE, z_south, 0.0)
	for j: int in range(CELLS_Z.x, CELLS_Z.y + 1):
		_wall(hall, "WallEast_%s" % _cell_name(j), x_edge, j * TILE, 90.0)
		_wall(hall, "WallWest_%s" % _cell_name(j), -x_edge, j * TILE, 90.0)


func _cell_name(index: int) -> String:
	return ("m%d" % -index) if index < 0 else str(index)


func _in_pit(cell: Vector2i) -> bool:
	var rect: Rect2 = Rect2(cell.x * TILE - TILE * 0.5, cell.y * TILE - TILE * 0.5, TILE, TILE)
	for pit: Rect2 in _pits:
		if rect.intersects(pit):
			return true
	return false


func _pit(x_min: float, x_max: float, z_min: float, z_max: float) -> void:
	_pits.append(Rect2(x_min, z_min, x_max - x_min, z_max - z_min))


func _take_cell(x: float, z: float) -> void:
	_taken_cells[Vector2i(roundi(x / TILE), roundi(z / TILE))] = true


# --- Zone_MeasurementStrip ----------------------------------------------------------------------------------


func _build_measurement_strip(zone: Node3D) -> void:
	# A straight 40 m lane from the spawn toward -z. Distance markers every 2 m beside it. The hall tile seams
	# every 4 m (x -2 and 2, z -2, -6, ...) give the eye a second scale.
	for metres: int in range(0, 41, 2):
		_label(zone, "Distance_%02d" % metres, "%d m" % metres, Vector3(3.0, 1.2, -float(metres)))

	# Height references of 1, 2, 3 and 4 m, with their labels.
	_floor_tile(zone, "Height_1m", 8.0, 1.0, -6.0)
	_instance(zone, CUBE, "Height_2m", Vector3(12.0, 0.0, -6.0))
	_instance(zone, CUBE, "Height_3m_Cube", Vector3(16.0, 0.0, -6.0))
	_floor_tile(zone, "Height_3m_Slab", 16.0, 3.0, -6.0)
	_instance(zone, PILLAR, "Height_4m", Vector3(20.0, 0.0, -6.0))
	_label(zone, "HeightLabel_1m", "1 m", Vector3(8.0, 2.0, -6.0))
	_label(zone, "HeightLabel_2m", "2 m", Vector3(12.0, 3.0, -6.0))
	_label(zone, "HeightLabel_3m", "3 m", Vector3(16.0, 4.0, -6.0))
	_label(zone, "HeightLabel_4m", "4 m", Vector3(20.0, 5.0, -6.0))


# --- Zone_RampsStairs ---------------------------------------------------------------------------------------


func _build_ramps_stairs(zone: Node3D) -> void:
	# 45 degree slope up to a 4 m plateau (rises toward -x). The plateau is two floor tiles closed by walls.
	_instance(zone, SLOPE, "Slope45", Vector3(16.0, 0.0, -44.0))
	_floor_tile(zone, "Plateau_0", 12.0, 4.0, -44.0)
	_floor_tile(zone, "Plateau_1", 8.0, 4.0, -44.0)
	for index: int in 2:
		var px: float = 12.0 - 4.0 * index
		_wall(zone, "PlateauWallNorth_%d" % index, px, -46.5, 0.0)
		_wall(zone, "PlateauWallSouth_%d" % index, px, -41.5, 0.0)
	_wall(zone, "PlateauWallWest", 5.5, -44.0, 90.0)
	_label(zone, "Label_Slope45", "45 deg slope", Vector3(16.0, 5.5, -44.0))
	_label(zone, "Label_Plateau", "plateau 4 m", Vector3(9.0, 5.5, -44.0))

	# 20 degree ramp of two rotated floor tiles, running up toward -x from (28, 0, -36).
	var angle: float = deg_to_rad(20.0)
	var direction: Vector3 = Vector3(-cos(angle), sin(angle), 0.0)
	var normal: Vector3 = Vector3(sin(angle), cos(angle), 0.0)
	var ramp_basis: Basis = Basis(Vector3.BACK, -angle)
	var ramp_start: Vector3 = Vector3(28.0, 0.0, -36.0)
	for index: int in 2:
		var surface_centre: Vector3 = ramp_start + direction * (2.0 + 4.0 * index)
		_instance(zone, FLOOR, "Ramp20_%d" % index, surface_centre - normal, ramp_basis)
	_label(zone, "Label_Ramp20", "20 deg ramp", Vector3(24.0, 4.0, -36.0))

	# Stairs: six 0.15 m risers (1 m deep) up to a 0.9 m landing, rising toward -x from x 30.
	for step: int in range(1, 7):
		var riser_top: float = 0.15 * step
		_instance(zone, BEAM, "Riser_%d" % step, Vector3(30.0 - (step - 0.5), riser_top - 1.0, -28.0), _yaw(90.0))
	_instance(zone, FLOOR, "StairLanding", Vector3(22.0, 0.9 - 1.0, -28.0))
	_label(zone, "Label_Risers", "6 risers x 0.15 m", Vector3(27.0, 2.0, -28.0))
	_label(zone, "Label_Landing", "landing 0.9 m", Vector3(22.0, 2.0, -28.0))

	# Ledge ladder: three single ledges of 0.25, 0.35 and 0.5 m, 1 m deep and 4 m wide, to run at from +x.
	var ledge_heights: Array[float] = [0.25, 0.35, 0.5]
	var ledge_names: Array[String] = ["025", "035", "050"]
	for index: int in ledge_heights.size():
		var ledge_z: float = -22.0 + 5.0 * index
		_instance(zone, BEAM, "Ledge_%s" % ledge_names[index], Vector3(34.0, ledge_heights[index] - 1.0, ledge_z), _yaw(90.0))
		_label(zone, "Label_Ledge_%s" % ledge_names[index], "ledge %.2f m" % ledge_heights[index], Vector3(34.0, 1.8, ledge_z))


# --- Zone_Gaps ----------------------------------------------------------------------------------------------


func _build_gaps(zone: Node3D, spawn: Node3D, rig: Node3D) -> void:
	# Leg 1 runs along -z in the column x -38..-34, leg 2 turns east along the row z -22..-18.
	# Islands are 4 m floor tiles, gaps are 2, 3, 4, 5, 6, 8, 10 and 12 m. The pit is a moat around the path,
	# so the only way across is the jump.
	_pit(-42.0, -30.0, -26.0, 34.0)
	_pit(-42.0, -2.0, -26.0, -14.0)

	var gap_widths: Array[int] = [2, 3, 4, 5, 6, 8, 10, 12]
	var island_index: int = 0
	var z_high: float = 34.0
	for gap_index: int in 6:
		_gap_island(zone, island_index, -36.0, z_high - 2.0)
		var gap_centre_z: float = z_high - 4.0 - gap_widths[gap_index] * 0.5
		_label(zone, "Label_Gap_%02d" % gap_widths[gap_index], "gap %d m" % gap_widths[gap_index], Vector3(-36.0, 1.6, gap_centre_z))
		z_high -= 4.0 + gap_widths[gap_index]
		island_index += 1
	# The corner island ends leg 1 and starts leg 2.
	_gap_island(zone, island_index, -36.0, z_high - 2.0)
	island_index += 1
	var corner_z: float = z_high - 2.0
	var x_low: float = -34.0
	for gap_index: int in range(6, 8):
		_label(zone, "Label_Gap_%02d" % gap_widths[gap_index], "gap %d m" % gap_widths[gap_index], Vector3(x_low + gap_widths[gap_index] * 0.5, 1.6, corner_z))
		x_low += gap_widths[gap_index]
		_gap_island(zone, island_index, x_low + 2.0, corner_z)
		x_low += 4.0
		island_index += 1
	_label(zone, "Label_Start", "gap course start", Vector3(-36.0, 3.0, 32.0))

	var respawn: Marker3D = Marker3D.new()
	_adopt(zone, respawn, "Respawn_Gaps", Vector3(-36.0, 0.0, 32.0))
	var reset: FallReset = FallReset.new()
	reset.name = "FallResetGaps"
	reset.respawn = respawn
	reset.camera_rig = rig as CameraRig
	zone.add_child(reset)
	reset.owner = _root
	reset.transform = Transform3D(Basis.IDENTITY, Vector3.ZERO)
	var leg_one: CollisionShape3D = _box_shape("Leg1", Vector3(12.0, 4.0, 60.0), Vector3(-36.0, -8.0, 4.0))
	var leg_two: CollisionShape3D = _box_shape("Leg2", Vector3(40.0, 4.0, 12.0), Vector3(-22.0, -8.0, -20.0))
	reset.add_child(leg_one)
	leg_one.owner = _root
	reset.add_child(leg_two)
	leg_two.owner = _root


func _gap_island(zone: Node3D, index: int, x: float, z: float) -> void:
	_floor_tile(zone, "Island_%d" % index, x, 0.0, z)


# --- Zone_MovingPlatforms -----------------------------------------------------------------------------------


func _build_moving_platforms(zone: Node3D) -> void:
	# The linear and circular platforms float with their bottom flush on the floor, so they glide over the hall
	# tiles without overlapping them. Board them with a jump.
	var linear: MovingPlatform = _instance(zone, PLATFORM, "Platform_Linear", Vector3(16.0, 0.0, 12.0)) as MovingPlatform
	linear.mode = MovingPlatform.Mode.LINEAR
	linear.travel = Vector3(12.0, 0.0, 0.0)
	linear.speed = 3.0
	_label(zone, "Label_Linear", "linear 12 m, 3 m/s", Vector3(22.0, 3.0, 12.0))

	var circle: MovingPlatform = _instance(zone, PLATFORM, "Platform_Circle", Vector3(28.0, 0.0, 26.0)) as MovingPlatform
	circle.mode = MovingPlatform.Mode.CIRCLE
	circle.radius = 6.0
	circle.speed = 3.0
	_label(zone, "Label_Circle", "circle r 6 m, 3 m/s", Vector3(22.0, 3.0, 26.0))

	# The lift rises 6 m out of a one cell hole to a ledge of 6 m next to it.
	_take_cell(36.0, 16.0)
	_floor_tile(zone, "LiftHoleBottom", 36.0, -1.0, 16.0)
	var lift: MovingPlatform = _instance(zone, PLATFORM, "Platform_Vertical", Vector3(36.0, -1.0, 16.0)) as MovingPlatform
	lift.mode = MovingPlatform.Mode.LINEAR
	lift.travel = Vector3(0.0, 6.0, 0.0)
	lift.speed = 2.0
	_floor_tile(zone, "LiftLedge", 36.0, 6.0, 20.0)
	_label(zone, "Label_Lift", "lift 6 m, 2 m/s", Vector3(36.0, 3.0, 16.0))
	_label(zone, "Label_LiftLedge", "ledge 6 m", Vector3(36.0, 8.0, 20.0))


# --- Zone_Conveyors -----------------------------------------------------------------------------------------


func _build_conveyors(zone: Node3D) -> void:
	_conveyor_strip(zone, "Conveyor_3ms", 12.0, Vector3(3.0, 0.0, 0.0))
	_conveyor_strip(zone, "Conveyor_5ms", 20.0, Vector3(-5.0, 0.0, 0.0))
	_label(zone, "Label_Conveyor_3ms", "conveyor +3 m/s", Vector3(-18.0, 2.0, 12.0))
	_label(zone, "Label_Conveyor_5ms", "conveyor -5 m/s", Vector3(-18.0, 2.0, 20.0))


func _conveyor_strip(zone: Node3D, prefix: String, z: float, velocity: Vector3) -> void:
	for index: int in 4:
		var x: float = -24.0 + 4.0 * index
		_take_cell(x, z)
		var tile: StaticBody3D = _floor_tile(zone, "%s_%d" % [prefix, index], x, 0.0, z) as StaticBody3D
		tile.constant_linear_velocity = velocity


# --- Zone_CameraTests ---------------------------------------------------------------------------------------


func _build_camera_tests(zone: Node3D) -> void:
	# A 2 m wide, 16 m long passage along x at z -2, walled on both sides. Floor slabs on top of the walls form
	# an 8 m low-ceiling section in the middle with the underside at 3 m (a 2 m capsule keeps 1 m of headroom).
	for index: int in 4:
		var x: float = -24.0 + 4.0 * index
		_wall(zone, "PassageWallNorth_%d" % index, x, -3.5, 0.0)
		_wall(zone, "PassageWallSouth_%d" % index, x, -0.5, 0.0)
	_instance(zone, FLOOR, "PassageCeiling_0", Vector3(-18.0, 3.0, -2.0))
	_instance(zone, FLOOR, "PassageCeiling_1", Vector3(-14.0, 3.0, -2.0))
	_label(zone, "Label_Passage", "passage 2 m x 16 m", Vector3(-26.0, 2.0, -2.0))
	_label(zone, "Label_Ceiling", "ceiling 3 m", Vector3(-16.0, 2.0, -2.0))

	# Pillar forest: a pillar every 3 m, every other row shifted by 1 m.
	var row: int = 0
	var z: float = 10.0
	while z <= 31.0:
		var shift: float = 1.0 if row % 2 == 1 else 0.0
		for column: int in 6:
			var x: float = -6.0 + 3.0 * column + shift
			_instance(zone, PILLAR, "Pillar_%d_%d" % [row, column], Vector3(x, 0.0, z))
		row += 1
		z += 3.0
	_label(zone, "Label_Forest", "pillar forest", Vector3(0.0, 5.5, 8.0))
