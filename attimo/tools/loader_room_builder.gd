extends RefCounted
## Worker of tools/movement_gym_builder.gd: Zone_Loader, the Loader test room behind the west door of the hall (phase 5, D-21).
## Generated, never hand-edited. Contract: build_into(zone, builder) where `zone` is the group Zone_Loader and `builder` is the
## movement_gym_builder instance (helpers through builder.call). Every size that depends on a number is computed from
## res://resources/player/movement_default.tres through LoaderMath at build time (gym rule: sizes from metrics), and the room
## test recomputes it from the current config, so a retune fails the test until the gym is regenerated (T-05-07).
##
## Plan view (x east, z south, floor tiles on the 4 m lattice, x -43..-115, z -26..26):
##   west door (hall WallWest_0 is open)  -> DoorLanding tile (x -40), threshold beam (x -42.5), then the room
##   walk lane z -2..2 (x -43..-115, plain floor y 0; it continues through the open west wall cell into Zone_Energy)
##   Loader_Redirect  x -55, z 12     open flat floor, hold and throw
##   Loader_Air       x -70, z 12     2 m platform with a 1 m step, hold in the air
##   Loader_Gap       x -95 .. -115, z 6..14   launch platform, pit, far island; gap = mid of base and bonus reach
##   Loader_SuperJump x -55 .. -60, z -16      solid ledge only a discharge with a full core reaches

const CONFIG_PATH: String = "res://resources/player/movement_default.tres"
const BEAM_SCENE: String = "res://scenes/proto/primitive_beam.tscn"
const PILLAR_SCENE: String = "res://scenes/proto/primitive_pillar.tscn"

const TILE: float = 4.0
## Tile centres of the lattice: x -45 - 4 k (k 0..17, edges -43..-115), z 4 j (j -6..6, edges -26..26).
const X_FIRST: float = -45.0
const COLUMNS: int = 18
const ROWS_HALF: int = 6
const X_EAST_EDGE: float = -43.0
const X_WEST_EDGE: float = -115.0
const X_EAST_EDGE_RESET: float = -42.0
const Z_HALF: float = 26.0
const DOOR_X: float = -42.5
const RESPAWN: Vector3 = Vector3(-47.0, 0.0, 0.0)
## The fall reset sits well below every floor, like the gym's other zones.
const FALL_Y: float = -8.0

## Discharge pitch of the gap station (degrees above the horizon, toward the island).
const GAP_PITCH_DEG: float = 30.0
## The gap launch platform ends at this x (a lattice edge); the pit runs west from it.
const GAP_PLATFORM_EDGE: float = -95.0
## Gap rows: z 6..14 (two lattice cells, centres 8 and 12).
const GAP_ROWS: Array[int] = [2, 3]
const GAP_SIGN_Z: float = 10.0
## The launch marker stands this far inside the platform edge.
const GAP_MARKER_INSET: float = 0.5
## Super jump: the discharge tilts this far from the vertical toward the ledge (the camera pitch limit of D-29 is 75 degrees).
const LEDGE_TILT_DEG: float = 15.0
const LEDGE_MARKER: Vector3 = Vector3(-55.0, 0.0, -16.0)
## Capsules next to the gap launch and the super jump marker, so bonus tries do not need the pit (5 s respawn).
const CAPSULE_SCENE: String = "res://scenes/mechanisms/energy_capsule.tscn"
const CAPSULE_RESPAWN: float = 5.0
const GAP_CAPSULE: Vector3 = Vector3(-91.0, 0.0, 14.0)
const LEDGE_CAPSULE: Vector3 = Vector3(-51.0, 0.0, -16.0)
const LEDGE_CENTRE: Vector3 = Vector3(-60.0, 0.0, -16.0)

var _config: MovementConfig


func build_into(zone: Node3D, builder: RefCounted) -> void:
	_config = load(CONFIG_PATH) as MovementConfig
	if _config == null:
		builder.set(&"failure", "cannot load %s" % CONFIG_PATH)
		return
	zone.set_meta(&"x_range", Vector2(X_WEST_EDGE, X_EAST_EDGE))
	var gap: Dictionary = _gap_numbers()
	_build_floor(zone, builder, float(gap["gap_width"]))
	_build_walls(zone, builder)
	_build_door(zone, builder)
	_build_reset(zone, builder)
	_build_redirect(zone, builder)
	_build_air(zone, builder)
	_build_gap(zone, builder, gap)
	_build_super_jump(zone, builder)
	_build_capsules(zone, builder)


# --- numbers from the config ----------------------------------------------------------------------------------


## The launch direction of the gap station: toward -x, GAP_PITCH_DEG above the horizon.
func gap_direction() -> Vector3:
	var pitch: float = deg_to_rad(GAP_PITCH_DEG)
	return Vector3(-cos(pitch), sin(pitch), 0.0)


## Base and bonus reach of a discharge from a standing start along the gap direction, and the gap between them (1 m snapped).
func _gap_numbers() -> Dictionary:
	var direction: Vector3 = gap_direction()
	var base_speed: float = LoaderMath.discharge_speed(0.0, _config.loader_min_push, 0.0, _config.loader_max_speed)
	var bonus_speed: float = LoaderMath.discharge_speed(0.0, _config.loader_min_push, _config.loader_bonus_speed, _config.loader_max_speed)
	var base_reach: float = LoaderMath.flat_reach(LoaderMath.discharge_velocity(direction, base_speed), _config)
	var bonus_reach: float = LoaderMath.flat_reach(LoaderMath.discharge_velocity(direction, bonus_speed), _config)
	return {
		"base_reach": base_reach,
		"bonus_reach": bonus_reach,
		"gap_width": roundf((base_reach + bonus_reach) * 0.5),
		"direction": direction,
	}


# --- floor, walls, door, reset --------------------------------------------------------------------------------


func _build_floor(zone: Node3D, builder: RefCounted, gap_width: float) -> void:
	for column: int in COLUMNS:
		var x: float = X_FIRST - TILE * column
		for j: int in range(-ROWS_HALF, ROWS_HALF + 1):
			if GAP_ROWS.has(j) and x - TILE * 0.5 < GAP_PLATFORM_EDGE:
				continue
			builder.call(&"_floor_tile", zone, "Floor_%d_%d" % [roundi(x), j * 4], x, 0.0, j * TILE)
	# The far island of the gap rows, anchored at the far edge; one wall-anchored tile closes a remainder at the west wall.
	var far_edge: float = GAP_PLATFORM_EDGE - gap_width
	var index: int = 0
	var edge: float = far_edge
	while edge - TILE >= X_WEST_EDGE - 0.01:
		for j: int in GAP_ROWS:
			builder.call(&"_floor_tile", zone, "Island_%d_%d" % [index, j * 4], edge - TILE * 0.5, 0.0, j * TILE)
		edge -= TILE
		index += 1
	if edge > X_WEST_EDGE + 0.01:
		for j: int in GAP_ROWS:
			builder.call(&"_floor_tile", zone, "Island_%d_%d" % [index, j * 4], X_WEST_EDGE + TILE * 0.5, 0.0, j * TILE)


func _build_walls(zone: Node3D, builder: RefCounted) -> void:
	for column: int in COLUMNS:
		var x: float = X_FIRST - TILE * column
		builder.call(&"_wall", zone, "LoaderWallNorth_%d" % roundi(x), x, -Z_HALF - 0.5, 0.0, 0.0)
		builder.call(&"_wall", zone, "LoaderWallSouth_%d" % roundi(x), x, Z_HALF + 0.5, 0.0, 0.0)
	# The west wall is built per 4 m cell (named LoaderWallWest_<j>). The z -2..2 cell (j 0) stays open: it is the doorway into Zone_Energy
	# (tools/energy_area_builder.gd), whose floor starts flush at the wall line x -115 and runs under the doorway.
	for j: int in range(-ROWS_HALF, ROWS_HALF + 1):
		if j == 0:
			continue
		builder.call(&"_wall", zone, "LoaderWallWest_%s" % _cell_name(j), X_WEST_EDGE - 0.5, j * TILE, 90.0, 0.0)


func _build_door(zone: Node3D, builder: RefCounted) -> void:
	# The hall floor ends at x -42 and the room starts at x -43: a 1 m threshold closes the door cell. DoorLanding bridges the hall's
	# gap-course pit between that threshold and the gap course's island 4 (x -38..-34, z 0..4).
	builder.call(&"_instance", zone, BEAM_SCENE, "LoaderThreshold", Vector3(DOOR_X, -1.0, 0.0), builder.call(&"_yaw", 90.0))
	builder.call(&"_floor_tile", zone, "DoorLanding", -40.0, 0.0, 0.0)
	builder.call(&"_label", zone, "Label_Loader", "Loader-Raum", Vector3(-47.0, 5.0, 0.0))


func _build_reset(zone: Node3D, builder: RefCounted) -> void:
	var marker: Marker3D = Marker3D.new()
	builder.call(&"_adopt", zone, marker, "Respawn_Loader", RESPAWN)
	var rig: Node3D = (builder.get(&"_root") as Node).get_node("CameraRig") as Node3D
	# x -115..-42: it ends on the shared wall line x -115 so it never overlaps FallResetEnergy of Zone_Energy.
	var width: float = X_EAST_EDGE_RESET - X_WEST_EDGE
	var centre: Vector3 = Vector3((X_EAST_EDGE_RESET + X_WEST_EDGE) * 0.5, FALL_Y, 0.0)
	var area: FallReset = builder.call(&"_fall_reset", "FallResetLoader", centre, Vector3(width, 4.0, Z_HALF * 2.0 + 4.0), marker, rig) as FallReset
	builder.call(&"_adopt", zone, area, "FallResetLoader", centre)
	builder.call(&"_owner_children", area)


func _cell_name(index: int) -> String:
	return ("m%d" % -index) if index < 0 else str(index)


# --- stations -------------------------------------------------------------------------------------------------


## A station node (a direct child of the zone, at the zone origin so its children use global coordinates) with its two sign lines
## Label_<tag> and Label_<tag>_Expect above `at`.
func _station(zone: Node3D, builder: RefCounted, tag: String, at: Vector3, text: String, expect: String) -> Node3D:
	var station: Node3D = builder.call(&"_group", zone, tag) as Node3D
	station.set_meta(&"at", at)
	builder.call(&"_label", station, "Label_%s" % tag, text, at + Vector3(0.0, 3.2, 0.0))
	builder.call(&"_label", station, "Label_%s_Expect" % tag, expect, at + Vector3(0.0, 2.5, 0.0), 40)
	return station


func _marker(station: Node3D, builder: RefCounted, node_name: String, global_at: Vector3) -> Marker3D:
	var marker: Marker3D = Marker3D.new()
	builder.call(&"_adopt", station, marker, node_name, global_at - station.position)
	return marker


func _build_redirect(zone: Node3D, builder: RefCounted) -> void:
	var station: Node3D = _station(zone, builder, "Loader_Redirect", Vector3(-55.0, 0.0, 12.0), "Loader: Rechtsklick halten", "Erwartet: Die Welt wird langsam, loslassen wirft dich in Blickrichtung")
	_marker(station, builder, "Launch", Vector3(-55.0, 0.0, 12.0))


func _build_air(zone: Node3D, builder: RefCounted) -> void:
	var station: Node3D = _station(zone, builder, "Loader_Air", Vector3(-70.0, 0.0, 12.0), "Loader in der Luft", "Erwartet: Du hängst in der Luft, einmal pro Sprung")
	# A 2 m block (two slabs) with a 1 m step on its east side to jump from.
	builder.call(&"_floor_tile", station, "Block_a", -70.0, 1.0, 12.0)
	builder.call(&"_floor_tile", station, "Block_b", -70.0, 2.0, 12.0)
	builder.call(&"_floor_tile", station, "Step", -66.0, 1.0, 12.0)
	_marker(station, builder, "Launch", Vector3(-70.0, 2.0, 12.0))


func _build_gap(zone: Node3D, builder: RefCounted, numbers: Dictionary) -> void:
	var gap_width: float = float(numbers["gap_width"])
	var station: Node3D = _station(zone, builder, "Loader_Gap", Vector3(GAP_PLATFORM_EDGE - gap_width * 0.5, 0.0, GAP_SIGN_Z), "Lücke: nur mit vollem Kern", "Erwartet: Mit Kern landest du drüben, ohne fällst du in die Grube")
	station.set_meta(&"gap_width", gap_width)
	station.set_meta(&"base_reach", float(numbers["base_reach"]))
	station.set_meta(&"bonus_reach", float(numbers["bonus_reach"]))
	station.set_meta(&"launch_direction", numbers["direction"] as Vector3)
	station.set_meta(&"platform_edge_x", GAP_PLATFORM_EDGE)
	station.set_meta(&"far_edge_x", GAP_PLATFORM_EDGE - gap_width)
	_marker(station, builder, "Launch", Vector3(GAP_PLATFORM_EDGE + GAP_MARKER_INSET, 0.0, GAP_SIGN_Z))
	_marker(station, builder, "Far", Vector3(GAP_PLATFORM_EDGE - gap_width - 2.0, 0.0, GAP_SIGN_Z))


func _build_super_jump(zone: Node3D, builder: RefCounted) -> void:
	var apex_min: float = LoaderMath.apex_height(_config.loader_min_push, _config)
	var apex_bonus: float = LoaderMath.apex_height(minf(_config.loader_min_push + _config.loader_bonus_speed, _config.loader_max_speed), _config)
	var ledge_height: float = (apex_min + apex_bonus) * 0.5
	ledge_height = maxf(ledge_height, _config.jump_3_height + 1.0)
	ledge_height = roundf(ledge_height * 2.0) * 0.5
	var station: Node3D = _station(zone, builder, "Loader_SuperJump", Vector3(LEDGE_MARKER.x, 0.0, LEDGE_MARKER.z), "Super-Sprung", "Erwartet: Nach oben schauen, mit Kern erreichst du die Kante")
	station.set_meta(&"ledge_height", ledge_height)
	station.set_meta(&"apex_min", apex_min)
	station.set_meta(&"apex_bonus", apex_bonus)
	var tilt: float = deg_to_rad(LEDGE_TILT_DEG)
	station.set_meta(&"launch_direction", Vector3(-sin(tilt), cos(tilt), 0.0))
	_marker(station, builder, "Launch", LEDGE_MARKER)
	# A solid block of 1 m slabs up to the ledge height (the top slab is the ledge).
	var top: float = ledge_height
	var slab: int = 0
	while top > 0.0:
		builder.call(&"_floor_tile", station, "Ledge_%d" % slab, LEDGE_CENTRE.x, top, LEDGE_CENTRE.z)
		top -= 1.0
		slab += 1


func _build_capsules(zone: Node3D, builder: RefCounted) -> void:
	for entry: Array in [["Capsule_Gap", GAP_CAPSULE], ["Capsule_SuperJump", LEDGE_CAPSULE]]:
		var capsule: Node3D = builder.call(&"_instance", zone, CAPSULE_SCENE, String(entry[0]), entry[1] as Vector3) as Node3D
		capsule.set("respawn_time", CAPSULE_RESPAWN)
