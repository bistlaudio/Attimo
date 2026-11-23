extends RefCounted
## Worker of tools/movement_gym_builder.gd: the mechanism rooms (phase 4). The gym is generated, so the rooms live
## here. Pinned worker contract, used by every room worker of this phase: build_into(zone, builder), where `builder` is
## the movement_gym_builder instance. Its helpers are invoked with builder.call(&"_adopt", ...) and so on (a RefCounted
## typed handle has no such methods). Coordinates are on the 1 m grid with 2 m / 4 m modules.
##
## Plan view (x east, z south): the hall east wall sits at x 42.5. The door (Zahnrad-Tor) is its z 0 cell, the tracer lever
## stands on the hall side at (38, -3). Room 2 is the shell east of the door, x 43..115, z -16..16 (grown in 04-04); the puzzle rooms
## of tools/puzzle_rooms_builder.gd follow behind its east wall.

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
## deck stays clear of the floor tiles and the rider really stands on the moving body.
const RAISED: float = 1.0
## Showcase rows: the north row stands at z -12, the south row at z 12; the stations are 10 m apart on x.
const STATION_X: Array[float] = [48.0, 58.0, 68.0]
const STATION_Z: float = 12.0
## Distance of a station's gate from its trigger, towards the room centre.
const GATE_DISTANCE: float = 4.0
const WALL_X: float = 42.5
const ROOM_X_MIN: float = 43.0
## Room 2 was x 43..75 (04-03) and grew to x 115 in 04-04 for the moving stations; the puzzle rooms start behind it.
const ROOM_X_MAX: float = 115.0
const ROOM_Z_HALF: float = 16.0
const TILE: float = 4.0
## Index of the east wall cell (z 0..4) that stays open for the puzzle room doorway.
const EAST_DOOR_ROW: int = 4


func build_into(zone: Node3D, builder: RefCounted) -> void:
	_build_room_shell(zone, builder)
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


func _build_door(zone: Node3D, builder: RefCounted) -> void:
	# _yaw(90) = Basis(UP, +90 deg) maps local -X to world +Z: the open gate slides along +z inside the wall plane,
	# into the WallEast_1 segment (z 2..6) beside the doorway, never into room 2 or the hall.
	var gate: Node3D = builder.call(&"_instance", zone, GATE_SCENE, "ZahnradTor", Vector3(WALL_X, 0.0, 0.0), builder.call(&"_yaw", 90.0)) as Node3D
	var lever: Node3D = builder.call(&"_instance", zone, LEVER_SCENE, "TracerLever", Vector3(38.0, 0.0, -3.0)) as Node3D
	gate.set("source", lever)
	builder.call(&"_label", zone, "Label_Tracer", "Fernauslöser: RMB halten, LMB tippen", Vector3(38.0, 2.4, -3.0))
	builder.call(&"_label", zone, "Label_Room2", "Raum 2", Vector3(WALL_X, 5.0, 0.0))
