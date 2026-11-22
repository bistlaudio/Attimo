extends RefCounted
## Worker of tools/movement_gym_builder.gd: the mechanism rooms (phase 4). The gym is generated, so the rooms live
## here. Pinned worker contract, used by every room worker of this phase: build_into(zone, builder), where `builder` is
## the movement_gym_builder instance. Its helpers are invoked with builder.call(&"_adopt", ...) and so on (a RefCounted
## typed handle has no such methods). Coordinates are on the 1 m grid with 2 m / 4 m modules.
##
## Plan view (x east, z south): the hall east wall sits at x 42.5. The door (Zahnrad-Tor) is its z 0 cell, the tracer lever
## stands on the hall side at (38, -3). Room 2 is the shell east of the door, x 43..75, z -16..16.

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
## Showcase rows: the north row stands at z -12, the south row at z 12; the stations are 10 m apart on x.
const STATION_X: Array[float] = [48.0, 58.0, 68.0]
const STATION_Z: float = 12.0
## Distance of a station's gate from its trigger, towards the room centre.
const GATE_DISTANCE: float = 4.0
const WALL_X: float = 42.5
const ROOM_X_MIN: float = 43.0
const ROOM_X_MAX: float = 75.0
const ROOM_Z_HALF: float = 16.0
const TILE: float = 4.0


func build_into(zone: Node3D, builder: RefCounted) -> void:
	_build_room_shell(zone, builder)
	_build_door(zone, builder)
	build_showcase_stations(zone, builder)


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


## A gate GATE_DISTANCE towards the room centre from `at`, wired to `source`. Returns the gate.
func _station_gate(zone: Node3D, builder: RefCounted, at: Vector3, tag: String, source: Node3D) -> Node3D:
	var toward_centre: float = 1.0 if at.z < 0.0 else -1.0
	var gate_position: Vector3 = Vector3(at.x, 0.0, at.z + toward_centre * GATE_DISTANCE)
	var gate: Node3D = builder.call(&"_instance", zone, GATE_SCENE, "Gate_%s" % tag, gate_position) as Node3D
	gate.set("source", source)
	return gate


func _sign(zone: Node3D, builder: RefCounted, tag: String, text: String, at: Vector3, height: float = 2.8) -> void:
	builder.call(&"_label", zone, "Label_%s" % tag, text, Vector3(at.x, height, at.z))


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
