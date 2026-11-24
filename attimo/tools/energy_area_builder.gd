extends RefCounted
## Worker of tools/movement_gym_builder.gd: Zone_Energy, the energy test area west of the Loader room (phase 5, D-22, D-23).
## Generated, never hand-edited. Contract: build_into(zone, builder) where `zone` is the group Zone_Energy and `builder` is the
## movement_gym_builder instance (helpers through builder.call). The zone starts at the Loader room's west wall line (x -115): the two
## zones share that wall, its z -2..2 cell is the open doorway and the energy floor lies under it, so the walk lane z -2..2 from the hall
## through the Loader room into this zone is plain floor. The zone is z -26..26 like the Loader room (tiles centred on 4 j).
##
## Plan view (x east, z south, tiles on the 4 m lattice, x -115..-239, z -26..26; every station has a sign and an "Erwartet:" line):
##   Energy_Track      z 0, x -121..-235   straight 114 m charge track with a mark every 10 m (the lane stays free of stations)
##   Energy_Capsule    (-131, 12)          capsule, 5 s respawn; Start marker 2.5 m east of it
##   Energy_Machine    (-143, 12)          broken machine, 8 s respawn
##   Energy_ChargeSpot (-155, 12)          marked plate for the charge button (R)
##   Energy_Drain      (-121, 8)           a lone drain plate beside the zone entry (off the walk lane)
##   Shot_TapVsFull    start (-171, 16)    lever 20 m away (tap range + 5 m), valve 20.4 m away that needs a full charge, gear gate behind it
##   Energy_AirDash    start (-209, 12)    8 m pit (z 6..18, x -219..-211): more than a run jump, within run jump + air dash; plate and capsule
##   Energy_BoostLine  z -12, x -131..-227 boost rings every 16 m (always on); Shot_Moving start (-171, -14), lever (-179, -18)
##   Energy_DashHop    start (-129, -22)   flat lane with marks at the stage 1, 2 and 3 reach; plate and capsule
##   Energy_WallRun    start (-197, -19)   12 m wall pad over a pit (z -22..-14, x -215..-199); plate and capsule
## Station sizes that depend on a number are computed from res://resources/player/movement_default.tres (gym rule: sizes from metrics).

const CONFIG_PATH: String = "res://resources/player/movement_default.tres"
const CAPSULE_SCENE: String = "res://scenes/mechanisms/energy_capsule.tscn"
const MACHINE_SCENE: String = "res://scenes/mechanisms/broken_machine.tscn"
const PLATE_SCENE: String = "res://scenes/mechanisms/energy_drain_plate.tscn"
const BOOST_SCENE: String = "res://scenes/mechanisms/boost_ring.tscn"
const PAD_SCENE: String = "res://scenes/mechanisms/wall_pad.tscn"
const LEVER_SCENE: String = "res://scenes/mechanisms/lever.tscn"
const VALVE_SCENE: String = "res://scenes/mechanisms/valve.tscn"
const GATE_SCENE: String = "res://scenes/mechanisms/gear_gate.tscn"
const ZONE_FLOOR_SCENE: String = "res://scenes/mechanisms/zone_floor.tscn"
const HAND_SCRIPT: String = "res://scripts/hand/hand_controller.gd"

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
## The track runs along z 0 between these x (a 114 m strip, west of the doorway).
const TRACK_FROM: float = -121.0
const TRACK_TO: float = -235.0
const MARK_EVERY: float = 10.0
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
## Shot tap vs full: the lever stands this far beyond a tap shot's range (the full charge reaches further).
const TAP_EXTRA: float = 5.0

var _config: MovementConfig
## Pits cut out of the floor: Rect2(x_min, z_min, width, depth) in world metres on tile edges.
var _pits: Array[Rect2] = []
var _small_range: float = 15.0
var _big_range: float = 25.0


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
	capsule.set("respawn_time", respawn)
	return capsule


func _build_stations(zone: Node3D, builder: RefCounted) -> void:
	var hand: Node = (load(HAND_SCRIPT) as GDScript).new() as Node
	_small_range = float(hand.get("hand_small_range"))
	_big_range = float(hand.get("hand_big_range"))
	hand.free()
	_build_track(zone, builder)
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


## The charge track: a straight 114 m strip along z 0 with a distance mark every 10 m (from the doorway side).
func _build_track(zone: Node3D, builder: RefCounted) -> void:
	var station: Node3D = _station(zone, builder, "Energy_Track", Vector3(TRACK_FROM - 4.0, 0.0, -4.0), "Ladestrecke", "Erwartet: Ab 10 m/s (Dash, Dash-Hop) lädt der Arm, normales Laufen nicht")
	station.set_meta(&"x_from", TRACK_FROM)
	station.set_meta(&"x_to", TRACK_TO)
	station.set_meta(&"length", TRACK_FROM - TRACK_TO)
	var distance: float = MARK_EVERY
	while TRACK_FROM - distance >= TRACK_TO:
		builder.call(&"_label", station, "Mark_%d" % roundi(distance), "%d m" % roundi(distance), Vector3(TRACK_FROM - distance, 0.6, 2.4), 48)
		distance += MARK_EVERY


func _build_capsule_station(zone: Node3D, builder: RefCounted) -> void:
	var at: Vector3 = Vector3(-131.0, 0.0, 12.0)
	var station: Node3D = _station(zone, builder, "Energy_Capsule", at, "Energiekapsel (Extraktor: Taste 2, LMB halten)", "Erwartet: +40 in einer halben Sekunde, dann dunkel, nach 5 s wieder voll")
	_marker(station, builder, "Start", at + Vector3(2.5, 0.0, 0.0))
	_capsule(station, builder, "Capsule", at, CAPSULE_RESPAWN)


## "15" for whole numbers, "0,6" (German decimal comma) otherwise.
func _fmt(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(roundi(value))
	return ("%.1f" % value).replace(".", ",")


## A drain plate (gym only) at the global point `at`, a child of `parent`.
func _plate(parent: Node3D, builder: RefCounted, node_name: String, at: Vector3) -> Node3D:
	return builder.call(&"_instance", parent, PLATE_SCENE, node_name, at - parent.position) as Node3D


## A driven mechanism: an always-on source added BEFORE the mechanism so it is ready first (puzzle-room pattern).
func _driven(parent: Node3D, builder: RefCounted, scene: String, node_name: String, at: Vector3, basis: Basis = Basis.IDENTITY) -> Node3D:
	var driver: SignalSource = SignalSource.new()
	driver.start_active = true
	builder.call(&"_adopt", parent, driver, "Driver%s" % node_name, at - parent.position)
	var mechanism: Node3D = builder.call(&"_instance", parent, scene, node_name, at - parent.position, basis) as Node3D
	mechanism.set("source", driver)
	return mechanism


func _build_machine_station(zone: Node3D, builder: RefCounted) -> void:
	var at: Vector3 = Vector3(-143.0, 0.0, 12.0)
	var station: Node3D = _station(zone, builder, "Energy_Machine", at, "Kaputte Maschine", "Erwartet: LMB halten: +60 in 2 s, dann dunkel")
	_marker(station, builder, "Start", at + Vector3(3.0, 0.0, 0.0))
	var machine: Node3D = builder.call(&"_instance", station, MACHINE_SCENE, "Machine", at - station.position) as Node3D
	machine.set("respawn_time", MACHINE_RESPAWN)


func _build_charge_spot(zone: Node3D, builder: RefCounted) -> void:
	var at: Vector3 = Vector3(-155.0, 0.0, 12.0)
	var station: Node3D = _station(zone, builder, "Energy_ChargeSpot", at, "Ladepunkt (R halten)", "Erwartet: Still stehen und R halten lädt langsam, Bewegen bricht ab")
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
	var station: Node3D = _station(zone, builder, "Energy_BoostLine", at, "Boost-Linie", "Erwartet: Die Ringe halten dich schnell, der Arm lädt dabei")
	_marker(station, builder, "Start", at)
	for k: int in BOOST_COUNT:
		var x: float = BOOST_X_FIRST - BOOST_SPACING * k
		_driven(station, builder, BOOST_SCENE, "Ring_%d" % k, Vector3(x, BOOST_HEIGHT, BOOST_Z))


func _build_air_dash(zone: Node3D, builder: RefCounted) -> void:
	var start: Vector3 = Vector3(-209.0, 0.0, 12.0)
	var text: String = "Luft-Dash kostet %s" % _fmt(_config.air_dash_cost)
	var station: Node3D = _station(zone, builder, "Energy_AirDash", start, text, "Erwartet: Leer kein Luft-Dash, mit Energie über die Grube")
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
	var text: String = "Dash-Hop Stufen 2-3 kosten je %s" % _fmt(_config.long_jump_cost)
	var station: Node3D = _station(zone, builder, "Energy_DashHop", start, text, "Erwartet: Leer nur Stufe 1, mit Energie Stufe 2 und 3")
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
	var text: String = "Wandlauf nach %s s" % _fmt(_config.wall_run_free_time)
	var station: Node3D = _station(zone, builder, "Energy_WallRun", start, text, "Erwartet: Leer endet der Lauf nach %s s, mit Energie hält er länger" % _fmt(_config.wall_run_free_time))
	_marker(station, builder, "Start", start)
	var pad_at: Vector3 = Vector3(WALL_PIT.position.x + WALL_PIT.size.x * 0.5, 0.0, WALL_PIT.position.y)
	var pad: Node3D = _driven(station, builder, PAD_SCENE, "Pad", pad_at)
	pad.set("mode", WallPad.Mode.WALL_RUN)
	_marker(station, builder, "Far", Vector3(WALL_PIT.position.x - 4.0, 0.0, -19.0))
	_plate(station, builder, "Plate", Vector3(-195.0, 0.0, -13.0))
	_capsule(station, builder, "Capsule", Vector3(-193.0, 0.0, -15.0), CAPSULE_RESPAWN)


## Tap vs full charge: the lever stands beyond a tap shot's range, the valve (full charge only) is still within the full range.
func _build_shot_tap_vs_full(zone: Node3D, builder: RefCounted) -> void:
	var start: Vector3 = Vector3(-171.0, 0.0, 16.0)
	var lever_distance: float = _small_range + TAP_EXTRA
	var text: String = "Schuss: tippen oder laden"
	var expect: String = "Erwartet: Tippen reicht %s m, voll geladen %s m und dreht das Ventil" % [_fmt(_small_range), _fmt(_big_range)]
	var station: Node3D = _station(zone, builder, "Shot_TapVsFull", start, text, expect)
	station.set_meta(&"tap_range", _small_range)
	station.set_meta(&"full_range", _big_range)
	_marker(station, builder, "Start", start)
	_capsule(station, builder, "Capsule", start + Vector3(0.0, 0.0, 5.0), CAPSULE_RESPAWN)
	var lever_at: Vector3 = start + Vector3(-lever_distance, 0.0, -4.0)
	builder.call(&"_instance", station, LEVER_SCENE, "LeverFar", lever_at - station.position)
	var valve_at: Vector3 = start + Vector3(-lever_distance, 0.0, 4.0)
	var valve: Node3D = builder.call(&"_instance", station, VALVE_SCENE, "Valve", valve_at - station.position) as Node3D
	var gate: Node3D = builder.call(&"_instance", station, GATE_SCENE, "Gate", valve_at + Vector3(-4.0, 0.0, 0.0) - station.position) as Node3D
	gate.set("source", valve)


## A lever beside the boost line to hit while moving fast (the snap and bend of the shot).
func _build_shot_moving(zone: Node3D, builder: RefCounted) -> void:
	var start: Vector3 = Vector3(-171.0, 0.0, -14.0)
	var station: Node3D = _station(zone, builder, "Shot_Moving", start, "Treffen im Lauf", "Erwartet: Das Ziel rastet ein, der Schuss biegt sich hinein")
	_marker(station, builder, "Start", start)
	_capsule(station, builder, "Capsule", start + Vector3(0.0, 0.0, 4.0), CAPSULE_RESPAWN)
	builder.call(&"_instance", station, LEVER_SCENE, "Lever", Vector3(-179.0, 0.0, -18.0) - station.position)
