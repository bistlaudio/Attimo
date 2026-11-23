extends RefCounted
## Worker of tools/movement_gym_builder.gd: the mechanism rooms (phase 4). The gym is generated, so the rooms live
## here. Pinned worker contract, used by every room worker of this phase: build_into(zone, builder), where `builder` is
## the movement_gym_builder instance. Its helpers are invoked with builder.call(&"_adopt", ...) and so on (a RefCounted
## typed handle has no such methods). Coordinates are on the 1 m grid with 2 m / 4 m modules.
##
## Plan view (x east, z south): the hall east wall sits at x 42.5. The door (Zahnrad-Tor) is its z 0 cell, the tracer lever
## stands on the hall side at (38, -3). Room 2 is the showcase hall east of the door, x 43..163, z -36..36 (120 m x 72 m, 04.1-05,
## D-04). A 12 m slot grid (SLOT_PITCH) holds nine zones (ZONES) and 33 stations; a street at z -12..12 runs from the west door to
## the east exit (z 0..4). The puzzle rooms of tools/puzzle_rooms_builder.gd follow behind its east wall, shifted by PUZZLE_SHIFT_X.

const GATE_SCENE: String = "res://scenes/mechanisms/gear_gate.tscn"
const LEVER_SCENE: String = "res://scenes/mechanisms/lever.tscn"
const BEAM_SCENE: String = "res://scenes/proto/primitive_beam.tscn"
const PILLAR_SCENE: String = "res://scenes/proto/primitive_pillar.tscn"
const VALVE_SCENE: String = "res://scenes/mechanisms/valve.tscn"
const CORE_SCENE: String = "res://scenes/mechanisms/energy_core.tscn"
const CRANK_SCENE: String = "res://scenes/mechanisms/crank.tscn"
const AND_SCENE: String = "res://scenes/mechanisms/logic_and.tscn"
const OR_SCENE: String = "res://scenes/mechanisms/logic_or.tscn"
const TIMER_SCENE: String = "res://scenes/mechanisms/logic_timer.tscn"
const ROTATING_SCENE: String = "res://scenes/mechanisms/rotating_platform.tscn"
const LIFT_SCENE: String = "res://scenes/mechanisms/lift_platform.tscn"
const CONVEYOR_SCENE: String = "res://scenes/mechanisms/conveyor.tscn"
const NOZZLE_SCENE: String = "res://scenes/mechanisms/steam_nozzle.tscn"
const PENDULUM_SCENE: String = "res://scenes/mechanisms/pendulum.tscn"
const LOW_GRAVITY_SCENE: String = "res://scenes/mechanisms/low_gravity_zone.tscn"
## Height of the raised moving stations (Dreh-Plattform, Hub-Plattform, Pendel walkway): their bodies are 0.5 m thick, so the
## deck stays clear of the floor tiles and the rider really stands on the moving body. No moving body's top face may be coplanar
## with a floor tile (the engine would pick the tile as the supporting body); belts carry a 0.05 m lip above their node origin.
const RAISED: float = 1.0
## Showcase rows: the north row stands at z -12, the south row at z 12; the stations are 10 m apart on x.
const STATION_X: Array[float] = [48.0, 58.0, 68.0]
const STATION_Z: float = 12.0
## Distance of a station's gate from its trigger, towards the room centre.
const GATE_DISTANCE: float = 4.0
const WALL_X: float = 42.5
const ROOM_X_MIN: float = 43.0
## Room 2 was x 43..75 (04-03) and grew to x 115 in 04-04 for the moving stations; the puzzle rooms start behind it.
const ROOM_X_MAX: float = 163.0
const ROOM_Z_HALF: float = 36.0
const TILE: float = 4.0
## Index of the east wall cell (z 0..4) that stays open for the puzzle room doorway: the row whose centre is z 2.
const EAST_DOOR_ROW: int = int(ROOM_Z_HALF / TILE)
## Slot grid (D-04): slot(i, j) = (49 + 12 i, 0, -30 + 12 j), i 0..9, j 0..5.
const SLOT_PITCH: float = 12.0
const SLOT_X0: float = 49.0
const SLOT_Z0: float = -30.0
## The nine zones: slot block i0..i1 x j0..j1, header title and floor tint. Open floor (no zone) is i6..7 j2..3 and i8..9.
const ZONES: Array[Dictionary] = [
	{"tag": "Wand", "title": "Wand", "i0": 0, "j0": 0, "i1": 1, "j1": 1, "tint": Color(0.60, 0.48, 0.22)},
	{"tag": "Felder", "title": "Felder & Schleuder", "i0": 2, "j0": 0, "i1": 3, "j1": 1, "tint": Color(0.20, 0.38, 0.40)},
	{"tag": "Gefahren", "title": "Gefahren", "i0": 4, "j0": 0, "i1": 5, "j1": 0, "tint": Color(0.55, 0.25, 0.20)},
	{"tag": "Dampf", "title": "Dampf", "i0": 4, "j0": 1, "i1": 5, "j1": 3, "tint": Color(0.55, 0.55, 0.55)},
	{"tag": "Umwelt", "title": "Umwelt", "i0": 6, "j0": 0, "i1": 7, "j1": 1, "tint": Color(0.35, 0.48, 0.58)},
	{"tag": "Trigger", "title": "Trigger", "i0": 0, "j0": 2, "i1": 1, "j1": 3, "tint": Color(0.55, 0.45, 0.30)},
	{"tag": "Logik", "title": "Logik", "i0": 2, "j0": 2, "i1": 3, "j1": 3, "tint": Color(0.30, 0.36, 0.48)},
	{"tag": "Plattformen", "title": "Plattformen", "i0": 0, "j0": 4, "i1": 3, "j1": 5, "tint": Color(0.32, 0.45, 0.30)},
	{"tag": "Tempo", "title": "Sprung & Tempo", "i0": 4, "j0": 4, "i1": 7, "j1": 5, "tint": Color(0.42, 0.30, 0.45)},
]
const ZONE_FLOOR_SCENE: String = "res://scenes/mechanisms/zone_floor.tscn"
## The zone floor scene is a 24 x 24 m overlay; the instance root is scaled to the zone rect.
const ZONE_FLOOR_SIZE: float = 24.0
const HEADER_FONT_SIZE: int = 128
const HEADER_HEIGHT: float = 7.5
## Room-2 respawn near the west door and the reset volume east of the hall reset (x 80).
const RESPAWN_ROOM2: Vector3 = Vector3(47.0, 0.0, 0.0)


func slot(i: int, j: int) -> Vector3:
	return Vector3(SLOT_X0 + SLOT_PITCH * i, 0.0, SLOT_Z0 + SLOT_PITCH * j)


## World rect (x, z, width, depth) of a zone row of ZONES.
func zone_rect(row: Dictionary) -> Rect2:
	var x0: float = ROOM_X_MIN + SLOT_PITCH * int(row["i0"])
	var z0: float = -ROOM_Z_HALF + SLOT_PITCH * int(row["j0"])
	var width: float = SLOT_PITCH * (int(row["i1"]) - int(row["i0"]) + 1)
	var depth: float = SLOT_PITCH * (int(row["j1"]) - int(row["j0"]) + 1)
	return Rect2(x0, z0, width, depth)


func build_into(zone: Node3D, builder: RefCounted) -> void:
	_build_room_shell(zone, builder)
	_build_zones(zone, builder)
	_build_room_reset(zone, builder)
	_build_door(zone, builder)
	build_showcase_stations(zone, builder)
	_build_puzzle_rooms(zone, builder)


## The three puzzle rooms (04-05) start behind room 2's east wall, in their own worker.
func _build_puzzle_rooms(zone: Node3D, builder: RefCounted) -> void:
	var script: GDScript = load("res://tools/puzzle_rooms_builder.gd") as GDScript
	if script == null or not script.can_instantiate():
		builder.set(&"failure", "cannot load res://tools/puzzle_rooms_builder.gd")
		return
	var worker: RefCounted = script.new() as RefCounted
	worker.call(&"build_into", zone, builder)


## Showcase stations along the room walls (04-03: triggers and logic; 04-04 and 04-05 add the moving mechanisms).
## North row (z -12): Handrad-Ventil x 48, Energiekern x 58 (on a 4 m pillar), Uhrwerk-Kurbel x 68.
## South row (z 12): UND x 48, ODER x 58, Timer x 68. Every gate stands 4 m towards the room centre.
## Free slots for plan 04-04 and later: (73, 0, -12) and (73, 0, 12) at the east wall, and the centre area
## x 52..64, z -4..4. Keep stations at least 6 m apart so the aim assist never mixes up neighbours.
func build_showcase_stations(zone: Node3D, builder: RefCounted) -> void:
	_station_valve(zone, builder, Vector3(STATION_X[0], 0.0, -STATION_Z))
	_station_core(zone, builder, Vector3(STATION_X[1], 0.0, -STATION_Z))
	_station_crank(zone, builder, Vector3(STATION_X[2], 0.0, -STATION_Z))
	_station_logic(zone, builder, Vector3(STATION_X[0], 0.0, STATION_Z), "And", AND_SCENE, "UND: beide Hebel")
	_station_logic(zone, builder, Vector3(STATION_X[1], 0.0, STATION_Z), "Or", OR_SCENE, "ODER: ein Hebel")
	_station_timer(zone, builder, Vector3(STATION_X[2], 0.0, STATION_Z))
	_build_moving_stations(zone, builder)


## A gate GATE_DISTANCE towards the room centre from `at`, wired to `source`. Returns the gate.
func _station_gate(zone: Node3D, builder: RefCounted, at: Vector3, tag: String, source: Node3D) -> Node3D:
	var toward_centre: float = 1.0 if at.z < 0.0 else -1.0
	var gate_position: Vector3 = Vector3(at.x, 0.0, at.z + toward_centre * GATE_DISTANCE)
	var gate: Node3D = builder.call(&"_instance", zone, GATE_SCENE, "Gate_%s" % tag, gate_position) as Node3D
	gate.set("source", source)
	return gate


## A station sign Label_<tag>. With `expect` (D-03) a second, smaller line Label_<tag>_Expect hangs 0.7 m below it; its text starts
## with "Erwartet:" and says what should happen when the player tries the station.
func _sign(zone: Node3D, builder: RefCounted, tag: String, text: String, at: Vector3, height: float = 2.8, expect: String = "") -> void:
	builder.call(&"_label", zone, "Label_%s" % tag, text, Vector3(at.x, height, at.z))
	if expect != "":
		builder.call(&"_label", zone, "Label_%s_Expect" % tag, expect, Vector3(at.x, height - 0.7, at.z), 40)


func _station_valve(zone: Node3D, builder: RefCounted, at: Vector3) -> void:
	var valve: Node3D = builder.call(&"_instance", zone, VALVE_SCENE, "Valve", at) as Node3D
	_station_gate(zone, builder, at, "Valve", valve)
	_sign(zone, builder, "Valve", "Handrad-Ventil (großer Puls)", at)


func _station_core(zone: Node3D, builder: RefCounted, at: Vector3) -> void:
	builder.call(&"_instance", zone, PILLAR_SCENE, "CorePillar", at)
	var core: Node3D = builder.call(&"_instance", zone, CORE_SCENE, "EnergyCore", Vector3(at.x, 4.0, at.z)) as Node3D
	_station_gate(zone, builder, at, "Core", core)
	_sign(zone, builder, "Core", "Energiekern (Zeit)", at, 6.6)


func _station_crank(zone: Node3D, builder: RefCounted, at: Vector3) -> void:
	var crank: Node3D = builder.call(&"_instance", zone, CRANK_SCENE, "Crank", at) as Node3D
	_station_gate(zone, builder, at, "Crank", crank)
	_sign(zone, builder, "Crank", "Uhrwerk-Kurbel (E halten)", at)


## Two levers feeding a LogicAnd or LogicOr node (`tag` "And" or "Or") that drives the gate.
func _station_logic(zone: Node3D, builder: RefCounted, at: Vector3, tag: String, scene: String, text: String) -> void:
	var lever_a: Node3D = builder.call(&"_instance", zone, LEVER_SCENE, "Lever%sA" % tag, Vector3(at.x - 2.0, 0.0, at.z)) as Node3D
	var lever_b: Node3D = builder.call(&"_instance", zone, LEVER_SCENE, "Lever%sB" % tag, Vector3(at.x + 2.0, 0.0, at.z)) as Node3D
	var logic: Node3D = builder.call(&"_instance", zone, scene, "Logic%s" % tag, Vector3(at.x, 0.0, at.z)) as Node3D
	var wired: Array[SignalSource] = [lever_a as SignalSource, lever_b as SignalSource]
	logic.set("sources", wired)
	_station_gate(zone, builder, at, tag, logic)
	_sign(zone, builder, tag, text, at)


func _station_timer(zone: Node3D, builder: RefCounted, at: Vector3) -> void:
	var lever: Node3D = builder.call(&"_instance", zone, LEVER_SCENE, "LeverTimer", at) as Node3D
	var timer: Node3D = builder.call(&"_instance", zone, TIMER_SCENE, "LogicTimer", Vector3(at.x, 0.0, at.z)) as Node3D
	timer.set("source", lever)
	timer.set("hold_time", 4.0)
	_station_gate(zone, builder, at, "Timer", timer)
	_sign(zone, builder, "Timer", "Timer (4 s)", at)


## Moving mechanisms (04-04, D-27): one station per mechanism, rotating-platform axis, lift look, belt behaviour and nozzle
## mode, each wired to its own lever. Stations are at least 6 m apart on the 1 m grid.
## Old part: nozzles JUMP (58, 0), UPDRAFT (68, 0), CANNON (74, -12), WALL (74, 12).
## Extension x 76..115: north row z -12 Dreh-Plattform LYING 80, STANDING 90, TILTING 100 and the Pendel bridge at 110;
## centre row z 0 Hub-Plattform PISTON 80 and CHAIN 90; south row z 12 Foerderband RUN_WHILE_ON (84) and REVERSE_ON_SIGNAL (102).
func _build_moving_stations(zone: Node3D, builder: RefCounted) -> void:
	var yaw_east: Basis = Basis(Vector3.UP, -PI * 0.5)
	var yaw_west: Basis = Basis(Vector3.UP, PI * 0.5)
	_station_mover(zone, builder, "NozzleJump", NOZZLE_SCENE, Vector3(58.0, 0.0, 0.0), Basis.IDENTITY, Vector3(55.5, 0.0, 0.0), {"mode": SteamNozzle.Mode.JUMP}, "Dampfdüse: Sprung")
	_station_mover(zone, builder, "NozzleUpdraft", NOZZLE_SCENE, Vector3(68.0, 0.0, 0.0), Basis.IDENTITY, Vector3(65.5, 0.0, 0.0), {"mode": SteamNozzle.Mode.UPDRAFT}, "Dampfdüse: Aufwind")
	_station_mover(zone, builder, "NozzleCannon", NOZZLE_SCENE, Vector3(74.0, 0.0, -STATION_Z), Basis.from_euler(Vector3(PI * 0.25, -PI * 0.5, 0.0)), Vector3(74.0, 0.0, -9.5), {"mode": SteamNozzle.Mode.CANNON}, "Dampfdüse: Kanone")
	_station_mover(zone, builder, "NozzleWall", NOZZLE_SCENE, Vector3(74.0, 0.0, STATION_Z), yaw_west, Vector3(74.0, 0.0, 9.5), {"mode": SteamNozzle.Mode.WALL}, "Dampfdüse: Wand")
	_station_mover(zone, builder, "RotatingLying", ROTATING_SCENE, Vector3(80.0, RAISED, -STATION_Z), Basis.IDENTITY, Vector3(80.0, 0.0, -6.5), {"axis_mode": RotatingPlatform.AxisMode.LYING}, "Dreh-Plattform: liegend (Zahnrad)", 4.5)
	_station_mover(zone, builder, "RotatingStanding", ROTATING_SCENE, Vector3(90.0, RAISED, -STATION_Z), Basis.IDENTITY, Vector3(92.5, 0.0, -8.0), {"axis_mode": RotatingPlatform.AxisMode.STANDING}, "Dreh-Plattform: stehend (Uhrzeiger)", 4.5)
	_station_mover(zone, builder, "RotatingTilting", ROTATING_SCENE, Vector3(100.0, RAISED, -STATION_Z), Basis.IDENTITY, Vector3(100.0, 0.0, -6.5), {"axis_mode": RotatingPlatform.AxisMode.TILTING}, "Dreh-Plattform: kippend", 4.5)
	_station_mover(zone, builder, "LiftPiston", LIFT_SCENE, Vector3(80.0, RAISED, 0.0), Basis.IDENTITY, Vector3(80.0, 0.0, 4.5), {"look": LiftPlatform.Look.PISTON}, "Hub-Plattform: Kolben", 7.0)
	_station_mover(zone, builder, "LiftChain", LIFT_SCENE, Vector3(90.0, RAISED, 0.0), Basis.IDENTITY, Vector3(90.0, 0.0, 4.5), {"look": LiftPlatform.Look.CHAIN}, "Hub-Plattform: Kette", 7.0)
	_station_mover(zone, builder, "ConveyorRun", CONVEYOR_SCENE, Vector3(84.0, 0.0, STATION_Z), yaw_east, Vector3(84.0, 0.0, 15.5), {"behaviour": Mechanism.Behaviour.RUN_WHILE_ON}, "Förderband: läuft solange an")
	_station_mover(zone, builder, "ConveyorReverse", CONVEYOR_SCENE, Vector3(102.0, 0.0, STATION_Z), yaw_east, Vector3(102.0, 0.0, 15.5), {"behaviour": Mechanism.Behaviour.REVERSE_ON_SIGNAL}, "Förderband: Hebel kehrt um")
	# The Pendel hangs over a narrow 2 m walkway (two beams, 1 m high); the bob swings across it just above the deck.
	builder.call(&"_instance", zone, BEAM_SCENE, "PendulumWalkA", Vector3(110.0, 0.0, -14.0), builder.call(&"_yaw", 90.0))
	builder.call(&"_instance", zone, BEAM_SCENE, "PendulumWalkB", Vector3(110.0, 0.0, -10.0), builder.call(&"_yaw", 90.0))
	_station_mover(zone, builder, "Pendulum", PENDULUM_SCENE, Vector3(110.0, RAISED, -STATION_Z), Basis.IDENTITY, Vector3(112.5, 0.0, -8.0), {}, "Pendel: Knockback", 7.5)
	# Tracer of 04.1 (MECH-04 K): a 10 x 12 x 10 m volume at (106, 0, 0), its lever 6.5 m south. Plan 04.1-05 moves it onto the slot grid.
	_station_mover(zone, builder, "LowGravity", LOW_GRAVITY_SCENE, Vector3(106.0, 0.0, 0.0), Basis.IDENTITY, Vector3(106.0, 0.0, 6.5), {}, "Schwerkraft-Zone", 3.2, "Erwartet: Sprünge hoch, weit und langsam")


## One moving mechanism wired to a fresh lever, with its sign. `props` are set on the mechanism before it is saved.
func _station_mover(zone: Node3D, builder: RefCounted, tag: String, scene: String, at: Vector3, basis: Basis, lever_at: Vector3, props: Dictionary, text: String, sign_height: float = 3.2, expect: String = "") -> void:
	var lever: Node3D = builder.call(&"_instance", zone, LEVER_SCENE, "Lever%s" % tag, lever_at) as Node3D
	var mechanism: Node3D = builder.call(&"_instance", zone, scene, tag, at, basis) as Node3D
	mechanism.set("source", lever)
	for key: Variant in props:
		mechanism.set(String(key), props[key])
	_sign(zone, builder, tag, text, Vector3(lever_at.x, 0.0, lever_at.z), sign_height, expect)


func _build_room_shell(zone: Node3D, builder: RefCounted) -> void:
	var columns: int = roundi((ROOM_X_MAX - ROOM_X_MIN) / TILE)
	var rows: int = roundi(ROOM_Z_HALF * 2.0 / TILE)
	for column: int in columns:
		var x: float = ROOM_X_MIN + TILE * 0.5 + TILE * column
		for row: int in rows:
			var z: float = -ROOM_Z_HALF + TILE * 0.5 + TILE * row
			builder.call(&"_floor_tile", zone, "Room2Floor_%d_%d" % [column, row], x, 0.0, z)
		builder.call(&"_wall", zone, "Room2WallNorth_%d" % column, x, -ROOM_Z_HALF - 0.5, 0.0, 0.0)
		builder.call(&"_wall", zone, "Room2WallSouth_%d" % column, x, ROOM_Z_HALF + 0.5, 0.0, 0.0)
	for row: int in rows:
		# The z 0..4 cell (row 4) is the doorway into the puzzle rooms (EntryGate of puzzle_rooms_builder).
		if row == EAST_DOOR_ROW:
			continue
		var z: float = -ROOM_Z_HALF + TILE * 0.5 + TILE * row
		builder.call(&"_wall", zone, "Room2WallEast_%d" % row, ROOM_X_MAX + 0.5, z, 90.0, 0.0)
	# The hall floor ends at x 42 and room 2 starts at x 43: a 1 m threshold closes the wall cell between them.
	builder.call(&"_instance", zone, BEAM_SCENE, "Room2Threshold", Vector3(WALL_X, -1.0, 0.0), builder.call(&"_yaw", 90.0))
	# The hall east wall ends at z 34 and room 2 reaches z 36: the plug closes the 2 m gap on the west side.
	builder.call(&"_wall", zone, "Room2WallWestPlug", WALL_X, ROOM_Z_HALF, 90.0)


func _build_door(zone: Node3D, builder: RefCounted) -> void:
	# _yaw(90) = Basis(UP, +90 deg) maps local -X to world +Z: the open gate slides along +z inside the wall plane,
	# into the WallEast_1 segment (z 2..6) beside the doorway, never into room 2 or the hall.
	var gate: Node3D = builder.call(&"_instance", zone, GATE_SCENE, "ZahnradTor", Vector3(WALL_X, 0.0, 0.0), builder.call(&"_yaw", 90.0)) as Node3D
	var lever: Node3D = builder.call(&"_instance", zone, LEVER_SCENE, "TracerLever", Vector3(38.0, 0.0, -3.0)) as Node3D
	gate.set("source", lever)
	builder.call(&"_label", zone, "Label_Tracer", "Fernauslöser: RMB halten, LMB tippen", Vector3(38.0, 2.4, -3.0))
	builder.call(&"_label", zone, "Label_Room2", "Raum 2", Vector3(WALL_X, 5.0, 0.0))


## Zone decor (D-04, D-12), all under the group ZoneDecor so that the stations stay the only mechanism children of the zone: a tint
## overlay ZoneFloor_<tag>, low divider beams with walk-through gaps on every border between two zones (or a zone and open floor)
## and a large header sign ZoneHeader_<tag>. Stores the metadata `zones` the layout test reads.
func _build_zones(zone: Node3D, builder: RefCounted) -> void:
	var decor: Node3D = builder.call(&"_group", zone, "ZoneDecor") as Node3D
	var entries: Array = []
	# Cell grid of the zone index per 12 m slot (-1 open floor), used for the borders.
	var columns: int = roundi((ROOM_X_MAX - ROOM_X_MIN) / SLOT_PITCH)
	var rows: int = roundi(ROOM_Z_HALF * 2.0 / SLOT_PITCH)
	var cells: Dictionary = {}
	for index: int in ZONES.size():
		var row: Dictionary = ZONES[index]
		var rect: Rect2 = zone_rect(row)
		var tag: String = String(row["tag"])
		var centre: Vector2 = rect.get_center()
		var floor_node: MeshInstance3D = builder.call(&"_instance", decor, ZONE_FLOOR_SCENE, "ZoneFloor_%s" % tag, Vector3(centre.x, 0.01, centre.y), Basis.IDENTITY.scaled(Vector3(rect.size.x / ZONE_FLOOR_SIZE, 1.0, rect.size.y / ZONE_FLOOR_SIZE))) as MeshInstance3D
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = row["tint"] as Color
		material.roughness = 0.9
		floor_node.material_override = material
		var header_name: String = "ZoneHeader_%s" % tag
		builder.call(&"_label", decor, header_name, String(row["title"]), Vector3(centre.x, HEADER_HEIGHT, centre.y), HEADER_FONT_SIZE)
		entries.append({"tag": tag, "title": String(row["title"]), "rect": rect, "header": NodePath("ZoneDecor/%s" % header_name)})
		for i: int in range(int(row["i0"]), int(row["i1"]) + 1):
			for j: int in range(int(row["j0"]), int(row["j1"]) + 1):
				cells[Vector2i(i, j)] = index
	var divider: int = 0
	for i: int in columns:
		for j: int in rows:
			var here: int = int(cells.get(Vector2i(i, j), -1))
			# East border of this cell (borders along z, yaw 90) and south border (along x).
			if i + 1 < columns and int(cells.get(Vector2i(i + 1, j), -1)) != here:
				var x: float = ROOM_X_MIN + SLOT_PITCH * (i + 1)
				var z: float = -ROOM_Z_HALF + SLOT_PITCH * (j + 0.5)
				builder.call(&"_instance", decor, BEAM_SCENE, "Divider_%d" % divider, Vector3(x, 0.0, z), builder.call(&"_yaw", 90.0))
				divider += 1
			if j + 1 < rows and int(cells.get(Vector2i(i, j + 1), -1)) != here:
				var x2: float = ROOM_X_MIN + SLOT_PITCH * (i + 0.5)
				var z2: float = -ROOM_Z_HALF + SLOT_PITCH * (j + 1)
				builder.call(&"_instance", decor, BEAM_SCENE, "Divider_%d" % divider, Vector3(x2, 0.0, z2))
				divider += 1
	zone.set_meta(&"zones", entries)


## Room-2 safety net (T-04.1-13): a FallReset under x 81..193 (east of the hall reset's x 80 edge) that returns the player to
## Respawn_Room2 near the west door. The puzzle rooms carry their own resets above it.
func _build_room_reset(zone: Node3D, builder: RefCounted) -> void:
	var marker: Marker3D = Marker3D.new()
	builder.call(&"_adopt", zone, marker, "Respawn_Room2", RESPAWN_ROOM2)
	var rig: Node3D = (builder.get(&"_root") as Node).get_node("CameraRig") as Node3D
	var area: FallReset = builder.call(&"_fall_reset", "FallResetRoom2", Vector3(137.0, -30.0, 0.0), Vector3(112.0, 4.0, 132.0), marker, rig) as FallReset
	builder.call(&"_adopt", zone, area, "FallResetRoom2", Vector3(137.0, -30.0, 0.0))
	builder.call(&"_owner_children", area)
