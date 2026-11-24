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
## Station sizes that depend on a number are computed from res://resources/player/movement_default.tres (gym rule: sizes from metrics).

const CONFIG_PATH: String = "res://resources/player/movement_default.tres"
const CAPSULE_SCENE: String = "res://scenes/mechanisms/energy_capsule.tscn"

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
	_build_track(zone, builder)
	_build_capsule_station(zone, builder)


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
