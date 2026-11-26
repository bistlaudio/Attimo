extends RefCounted
## Worker of tools/movement_gym_builder.gd: Zone_Energy, the energy test area west of the Loader room (phase 5, D-22, D-23).
## Generated, never hand-edited. Contract: build_into(zone, builder) where `zone` is the group Zone_Energy and `builder` is the
## movement_gym_builder instance (helpers through builder.call). The zone starts at the Loader room's west wall line (x -115): the two
## zones share that wall, its z -2..2 cell is the open doorway and the energy floor lies under it, so the walk lane z -2..2 from the hall
## through the Loader room into this zone is plain floor. The zone is z -26..26 like the Loader room (tiles centred on 4 j).
##
## Plan view (x east, z south, tiles on the 4 m lattice, x -115..-239, z -26..26; every station has a sign and an "Erwartet:" line):
##   (the former Energy_Track charge strip is gone: movement no longer charges the arm, D-41; the lane z 0 stays free of stations)
##   Energy_Capsule    (-131, 12)          capsule, 5 s respawn; Start marker 2.5 m east of it
##   Energy_Machine    (-143, 12)          broken machine, 8 s respawn
##   Energy_ChargeSpot (-155, 12)          marked plate for the charge button (R)
##   Energy_Drain      (-121, 8)           a lone drain plate beside the zone entry (off the walk lane)
##   Shot_TapVsFull    start (-171, 16)    a Loader field 14 m west (the former shot station, D-47)
##   Energy_AirDash    start (-209, 12)    8 m pit (z 6..18, x -219..-211): more than a run jump, within run jump + air dash; plate and capsule
##   Energy_BoostLine  z -12, x -131..-227 boost rings every 16 m (always on); Shot_Moving start (-171, -14), Loader field (-185, -18)
##   Energy_DashHop    start (-129, -22)   flat lane with marks at the stage 1, 2 and 3 reach; plate and capsule
##   Energy_WallRun    start (-197, -19)   12 m wall pad over a pit (z -22..-14, x -215..-199); plate and capsule
## Station sizes that depend on a number are computed from res://resources/player/movement_default.tres (gym rule: sizes from metrics).

const CONFIG_PATH: String = "res://resources/player/movement_default.tres"
const CAPSULE_SCENE: String = "res://scenes/kit/energy/energy_capsule.tscn"
const MACHINE_SCENE: String = "res://scenes/kit/energy/broken_machine.tscn"
const PLATE_SCENE: String = "res://scenes/mechanisms/energy_drain_plate.tscn"
const BOOST_SCENE: String = "res://scenes/kit/steampunk/boost_ring.tscn"
const PAD_SCENE: String = "res://scenes/kit/steampunk/wall_pad.tscn"
const FIELD_SCENE: String = "res://scenes/kit/energy/loader_field.tscn"
const ZONE_FLOOR_SCENE: String = "res://scenes/mechanisms/zone_floor.tscn"

const TILE: float = 4.0
## Tile centres: x -117 - 4 k (k 0..30, edges -115..-239), z 4 j (j -6..6, edges -26..26).
const X_FIRST: float = -117.0
const COLUMNS: int = 31
const ROWS_HALF: int = 6
const X_EAST_EDGE: float = -115.0
const X_WEST_EDGE: float = -239.0
const Z_HALF: float = 26.0
const RESPAWN: Vector3 = Vector3(-123.0, 0.0, 0.0)
const FALL_Y: float = -8.0
const CAPSULE_RESPAWN: float = 5.0
const MACHINE_RESPAWN: float = 8.0
## Boost ring line: z, first x, spacing, count, ring centre height.
const BOOST_Z: float = -12.0
const BOOST_X_FIRST: float = -131.0
const BOOST_SPACING: float = 16.0
const BOOST_COUNT: int = 7
const BOOST_HEIGHT: float = 1.2
## Air dash pit: 8 m wide (a run jump covers 5.52 m, a run jump plus the air dash about 9.5 m, docs/MOVEMENT-METRICS.md).
const AIR_PIT: Rect2 = Rect2(-219.0, 6.0, 8.0, 12.0)
## Wall run pit under the 12 m pad (the pad stands on its north edge, z -22).
const WALL_PIT: Rect2 = Rect2(-215.0, -22.0, 16.0, 8.0)
## Metres from a Loader-field station start to its field (the Loader field replaces the former lever, valve and gate, D-47).
const FIELD_DISTANCE: float = 14.0
const FIELD_EXPECT: String = "Erwartet: Nur ein Loader mit mindestens 2 Stufen gleitet hindurch und wird langsamer; alles andere prallt sanft ab"

var _config: MovementConfig
## Pits cut out of the floor: Rect2(x_min, z_min, width, depth) in world metres on tile edges.
var _pits: Array[Rect2] = []


func build_into(zone: Node3D, builder: RefCounted) -> void:
	_config = load(CONFIG_PATH) as MovementConfig
	if _config == null:
		builder.set(&"failure", "cannot load %s" % CONFIG_PATH)
		return
	zone.set_meta(&"x_range", Vector2(X_WEST_EDGE, X_EAST_EDGE))
	_collect_pits()
	_build_floor(zone, builder)
	_build_walls(zone, builder)
	_build_reset(zone, builder)
	_build_stations(zone, builder)


## Hook of the stations that cut pits out of the floor (filled by the station builders before the floor is laid).
func _collect_pits() -> void:
	_pits.clear()
	_pits.append(AIR_PIT)
	_pits.append(WALL_PIT)


# --- floor, walls, reset --------------------------------------------------------------------------------------


func _in_pit(x: float, z: float) -> bool:
	for pit: Rect2 in _pits:
		if pit.has_point(Vector2(x, z)):
			return true
	return false


func _build_floor(zone: Node3D, builder: RefCounted) -> void:
	for column: int in COLUMNS:
		var x: float = X_FIRST - TILE * column
		for j: int in range(-ROWS_HALF, ROWS_HALF + 1):
			if _in_pit(x, j * TILE):
				continue
			builder.call(&"_floor_tile", zone, "EFloor_%d_%d" % [roundi(-x), j * 4], x, 0.0, j * TILE)


## North, south and west walls only: the east edge is the Loader room's west wall with its open doorway.
func _build_walls(zone: Node3D, builder: RefCounted) -> void:
	for column: int in COLUMNS:
		var x: float = X_FIRST - TILE * column
		builder.call(&"_wall", zone, "EnergyWallNorth_%d" % roundi(-x), x, -Z_HALF - 0.5, 0.0, 0.0)
		builder.call(&"_wall", zone, "EnergyWallSouth_%d" % roundi(-x), x, Z_HALF + 0.5, 0.0, 0.0)
	for j: int in range(-ROWS_HALF, ROWS_HALF + 1):
		builder.call(&"_wall", zone, "EnergyWallWest_%s" % _cell_name(j), X_WEST_EDGE - 0.5, j * TILE, 90.0, 0.0)
	builder.call(&"_label", zone, "Label_Energy", "Energie-Bereich", Vector3(-123.0, 5.0, 0.0))


func _build_reset(zone: Node3D, builder: RefCounted) -> void:
	var marker: Marker3D = Marker3D.new()
	builder.call(&"_adopt", zone, marker, "Respawn_Energy", RESPAWN)
	var rig: Node3D = (builder.get(&"_root") as Node).get_node("CameraRig") as Node3D
	var width: float = X_EAST_EDGE - X_WEST_EDGE
	var centre: Vector3 = Vector3((X_EAST_EDGE + X_WEST_EDGE) * 0.5, FALL_Y, 0.0)
	var area: FallReset = builder.call(&"_fall_reset", "FallResetEnergy", centre, Vector3(width, 4.0, Z_HALF * 2.0 + 4.0), marker, rig) as FallReset
	builder.call(&"_adopt", zone, area, "FallResetEnergy", centre)
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


## An energy capsule that refills after `respawn` seconds, a child of `parent` at the global point `at`.
func _capsule(parent: Node3D, builder: RefCounted, node_name: String, at: Vector3, respawn: float) -> Node3D:
	var capsule: Node3D = builder.call(&"_instance", parent, CAPSULE_SCENE, node_name, at - parent.position) as Node3D
	capsule.call("set_respawn", respawn)
	return capsule


func _build_stations(zone: Node3D, builder: RefCounted) -> void:
	_build_capsule_station(zone, builder)
	_build_machine_station(zone, builder)
	_build_charge_spot(zone, builder)
	_build_drain_station(zone, builder)
	_build_boost_line(zone, builder)
	_build_air_dash(zone, builder)
	_build_dash_hop(zone, builder)
	_build_wall_run(zone, builder)
	_build_shot_tap_vs_full(zone, builder)
	_build_shot_moving(zone, builder)


func _build_capsule_station(zone: Node3D, builder: RefCounted) -> void:
	var at: Vector3 = Vector3(-131.0, 0.0, 12.0)
	var station: Node3D = _station(zone, builder, "Energy_Capsule", at, "Energiekapsel (Extraktor: Taste 2, LMB halten)", "Erwartet: +3 Stufen, schnell, dann dunkel, nach 5 s wieder voll")
	_marker(station, builder, "Start", at + Vector3(2.5, 0.0, 0.0))
	_capsule(station, builder, "Capsule", at, CAPSULE_RESPAWN)


## "1 Stufe" or "3 Stufen" for a whole-step cost.
func _steps(count: int) -> String:
	return "%d Stufe" % count if count == 1 else "%d Stufen" % count


## "15" for whole numbers, "0,6" (German decimal comma) otherwise.
func _fmt(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(roundi(value))
	return ("%.1f" % value).replace(".", ",")


## A drain plate (gym only) at the global point `at`, a child of `parent`.
func _plate(parent: Node3D, builder: RefCounted, node_name: String, at: Vector3) -> Node3D:
	return builder.call(&"_instance", parent, PLATE_SCENE, node_name, at - parent.position) as Node3D


## A driven mechanism: an always-on source added BEFORE the mechanism so it is ready first (puzzle-room pattern).
func _build_machine_station(zone: Node3D, builder: RefCounted) -> void:
	var at: Vector3 = Vector3(-143.0, 0.0, 12.0)
	var station: Node3D = _station(zone, builder, "Energy_Machine", at, "Kaputte Maschine", "Erwartet: LMB halten: +5 Stufen in etwa 2 s, dann dunkel")
	_marker(station, builder, "Start", at + Vector3(3.0, 0.0, 0.0))
	var machine: Node3D = builder.call(&"_instance", station, MACHINE_SCENE, "Machine", at - station.position) as Node3D
	machine.call("set_respawn", MACHINE_RESPAWN)


func _build_charge_spot(zone: Node3D, builder: RefCounted) -> void:
	var at: Vector3 = Vector3(-155.0, 0.0, 12.0)
	var station: Node3D = _station(zone, builder, "Energy_ChargeSpot", at, "Ladepunkt (R halten)", "Erwartet: Still stehen und R halten gibt +1 Stufe alle 5 s, Bewegen bricht ab")
	_marker(station, builder, "Start", at)
	# A flat 4 x 4 m overlay marks the spot (a tinted zone floor, no collision).
	var mark: MeshInstance3D = builder.call(&"_instance", station, ZONE_FLOOR_SCENE, "SpotMark", at + Vector3(0.0, 0.01, 0.0) - station.position, Basis.IDENTITY.scaled(Vector3(4.0 / 24.0, 1.0, 4.0 / 24.0))) as MeshInstance3D
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.78, 0.74, 0.62)
	material.roughness = 0.9
	mark.material_override = material


func _build_drain_station(zone: Node3D, builder: RefCounted) -> void:
	var at: Vector3 = Vector3(-121.0, 0.0, 8.0)
	var station: Node3D = _station(zone, builder, "Energy_Drain", at, "Leer-Platte", "Erwartet: Drauftreten leert den Arm")
	_marker(station, builder, "Start", at)
	_plate(station, builder, "Plate", at)


## Boost rings every 16 m along z -12 next to the track, always on.
func _build_boost_line(zone: Node3D, builder: RefCounted) -> void:
	var at: Vector3 = Vector3(-123.0, 0.0, BOOST_Z)
	var station: Node3D = _station(zone, builder, "Energy_BoostLine", at, "Boost-Linie", "Erwartet: +1 Stufe pro Ring (mit Abklingzeit)")
	_marker(station, builder, "Start", at)
	for k: int in BOOST_COUNT:
		var x: float = BOOST_X_FIRST - BOOST_SPACING * k
		builder.call(&"_instance", station, BOOST_SCENE, "Ring_%d" % k, Vector3(x, BOOST_HEIGHT, BOOST_Z) - station.position)


func _build_air_dash(zone: Node3D, builder: RefCounted) -> void:
	var start: Vector3 = Vector3(-209.0, 0.0, 12.0)
	var text: String = "Luft-Dash kostet %s" % _steps(_config.air_dash_cost)
	var station: Node3D = _station(zone, builder, "Energy_AirDash", start, text, "Erwartet: Ohne Stufe kein Luft-Dash, mit Stufe über die Grube")
	station.set_meta(&"gap_width", AIR_PIT.size.x)
	station.set_meta(&"platform_edge_x", AIR_PIT.position.x + AIR_PIT.size.x)
	station.set_meta(&"far_edge_x", AIR_PIT.position.x)
	_marker(station, builder, "Start", start)
	_marker(station, builder, "Far", Vector3(AIR_PIT.position.x - 2.0, 0.0, 12.0))
	_plate(station, builder, "Plate", Vector3(-205.0, 0.0, 6.0))
	_capsule(station, builder, "Capsule", Vector3(-205.0, 0.0, 18.0), CAPSULE_RESPAWN)


## The distance of one dash-hop stage from the config: the rise and fall time of its jump times its speed.
func _hop_reach(stage: int) -> float:
	var height: float = _config.long_jump_height(stage)
	var rise: float = _config.jump_speed(height) / _config.rise_gravity
	var fall: float = sqrt(2.0 * height / (_config.rise_gravity * _config.fall_multiplier))
	return _config.long_jump_speed(stage) * (rise + fall)


func _build_dash_hop(zone: Node3D, builder: RefCounted) -> void:
	var start: Vector3 = Vector3(-129.0, 0.0, -22.0)
	var text: String = "Dash-Hop Stufen 2-3 kosten je %s" % _steps(_config.long_jump_cost)
	var station: Node3D = _station(zone, builder, "Energy_DashHop", start, text, "Erwartet: Ohne Stufen nur Stufe 1, mit Stufen Stufe 2 und 3")
	_marker(station, builder, "Start", start)
	_plate(station, builder, "Plate", start + Vector3(2.0, 0.0, 4.0))
	_capsule(station, builder, "Capsule", start + Vector3(-2.0, 0.0, 4.0), CAPSULE_RESPAWN)
	# Marks at the cumulative reach of stage 1, 2 and 3 (chained hops), measured west from the start.
	var travelled: float = 0.0
	for stage: int in [1, 2, 3]:
		var reach: float = _hop_reach(stage)
		travelled += reach
		station.set_meta(&"reach_%d" % stage, reach)
		builder.call(&"_label", station, "Mark_Stage_%d" % stage, "Stufe %d: %s m" % [stage, _fmt(roundf(travelled))], Vector3(start.x - travelled, 0.6, start.z - 2.4), 48)


func _build_wall_run(zone: Node3D, builder: RefCounted) -> void:
	var start: Vector3 = Vector3(-197.0, 0.0, -19.0)
	var text: String = "Wandlauf: %d Stufen beim Start, dann %d pro Sekunde" % [_config.wall_run_entry_cost, _config.wall_run_tick_cost]
	var station: Node3D = _station(zone, builder, "Energy_WallRun", start, text, "Erwartet: Unter %d Stufen startet kein Lauf, ohne Stufe für den nächsten Tick fällst du" % _config.wall_run_entry_cost)
	_marker(station, builder, "Start", start)
	var pad_at: Vector3 = Vector3(WALL_PIT.position.x + WALL_PIT.size.x * 0.5, 0.0, WALL_PIT.position.y)
	builder.call(&"_instance", station, PAD_SCENE, "Pad", pad_at - station.position)
	_marker(station, builder, "Far", Vector3(WALL_PIT.position.x - 4.0, 0.0, -19.0))
	_plate(station, builder, "Plate", Vector3(-195.0, 0.0, -13.0))
	_capsule(station, builder, "Capsule", Vector3(-193.0, 0.0, -15.0), CAPSULE_RESPAWN)


## Former tap-vs-full shot station (D-47, D-30 amended): same place and capsule, now a Loader-field obstacle across the lane. Only a
## Loader with at least 2 paid steps glides through (and slows down); walking, a dash and a 1-step Loader bounce off softly.
func _build_shot_tap_vs_full(zone: Node3D, builder: RefCounted) -> void:
	var start: Vector3 = Vector3(-171.0, 0.0, 16.0)
	var station: Node3D = _station(zone, builder, "Shot_TapVsFull", start, "Loader-Feld", FIELD_EXPECT)
	_marker(station, builder, "Start", start)
	_capsule(station, builder, "Capsule", start + Vector3(0.0, 0.0, 5.0), CAPSULE_RESPAWN)
	_field(station, builder, start + Vector3(-FIELD_DISTANCE, 0.0, 0.0))


## Former moving-target shot station: same place and capsule, a Loader field seen from the side of the boost line.
func _build_shot_moving(zone: Node3D, builder: RefCounted) -> void:
	var start: Vector3 = Vector3(-171.0, 0.0, -14.0)
	var station: Node3D = _station(zone, builder, "Shot_Moving", start, "Loader-Feld (seitlich)", FIELD_EXPECT)
	_marker(station, builder, "Start", start)
	_capsule(station, builder, "Capsule", start + Vector3(0.0, 0.0, 4.0), CAPSULE_RESPAWN)
	_field(station, builder, start + Vector3(-FIELD_DISTANCE, 0.0, -4.0))


## A Loader field across the westward lane (its plane faces +X), a child of `station` at the global point `at`.
func _field(station: Node3D, builder: RefCounted, at: Vector3) -> Node3D:
	return builder.call(&"_instance", station, FIELD_SCENE, "LoaderField", at - station.position, builder.call(&"_yaw", 90.0)) as Node3D
