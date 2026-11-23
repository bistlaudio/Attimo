extends RefCounted
## Worker of tools/mechanism_rooms_builder.gd: the three puzzle rooms behind the showcase (phase 4, D-26..D-29). Generated, never hand-edited.
## Contract: build_into(zone, builder) where `builder` is the movement_gym_builder instance (helpers via builder.call). `zone` is
## Zone_MechanismRooms; the rooms go into its child Zone_PuzzleRooms.
##
## Plan view (x east, z south), local coordinates (the group is shifted east by PUZZLE_SHIFT_X = 104). Room 2 of the showcase ended at x 115 (east wall plane x 115.5, global 163.5). Its east wall has a doorway in the
## z 0..4 cell (EntryGate, opened by LeverEntry). Every puzzle room is 24 m wide (z -12..12), 1 m grid, 4 m tiles; the doorway of each
## room's east wall is the same z 0..4 cell and holds that room's ExitGate, which is also the entrance of the next room.
##   PuzzleRoom_1 "Fernschuss"  x 116..152.5   pulse room: small shot, big pulse, AND, lift, timed energy core
##   PuzzleRoom_2 "Uhrwerk"     x 153..199.5   crank (near contact), OR, gear, reversing conveyor, pendulum
##   PuzzleRoom_3 "Dampf"       x 200..313.5   timer, steam nozzles (jump, updraft, cannon, wall), clock hand, tilt plate, chain lift
## Each room node stores the metadata the test reads (tests/smoke/test_mechanism_rooms.gd): solve_order, solve_sizes
## (0 small shot, 1 big shot, -1 near contact), reach_checks and x_range. Reach numbers come from docs/MOVEMENT-METRICS.md: no jump
## chain crosses more than 15.6 m or climbs more than 4.0 m, a single run jump covers 5.52 m by 2.0 m.

const GATE_SCENE: String = "res://scenes/mechanisms/gear_gate.tscn"
const LEVER_SCENE: String = "res://scenes/mechanisms/lever.tscn"
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
const BEAM_SCENE: String = "res://scenes/proto/primitive_beam.tscn"
const PILLAR_SCENE: String = "res://scenes/proto/primitive_pillar.tscn"

const HALF: float = 12.0
const TILE: float = 4.0
## z of the doorway cell centre (the cell z 0..4) in every east wall.
const DOOR_Z: float = 2.0
const ROWS_ALL: Array[float] = [-10.0, -6.0, -2.0, 2.0, 6.0, 10.0]
const ROWS_LEDGE: Array[float] = [-6.0, -2.0, 2.0, 6.0]
## The FallReset box sits well below every floor and covers 40 m to each side.
const FALL_Y: float = -8.0
const FALL_THICKNESS: float = 4.0
const FALL_HALF_Z: float = 40.0
## Local x of room 2's east wall plane before the shift (the entrance of puzzle room 1).
const ENTRY_X: float = 115.5
## Room 2 of the showcase grew to x 219 (separate rooms along a corridor, equal to ROOM_X_MAX of mechanism_rooms_builder): the
## whole group moves east by ROOM2_EAST_X - 115. Node names, local coordinates and reach checks stay unchanged; x_range metadata is global.
const ROOM2_EAST_X: float = 219.0
const PUZZLE_SHIFT_X: float = ROOM2_EAST_X - 115.0


func build_into(zone: Node3D, builder: RefCounted) -> void:
	var puzzle: Node3D = builder.call(&"_group", zone, "Zone_PuzzleRooms") as Node3D
	puzzle.position = Vector3(PUZZLE_SHIFT_X, 0.0, 0.0)
	_build_entry(puzzle, builder)
	_build_room_1(puzzle, builder)
	_build_room_2(puzzle, builder)
	_build_room_3(puzzle, builder)


# --- shared helpers -------------------------------------------------------------------------------------------


func _build_entry(puzzle: Node3D, builder: RefCounted) -> void:
	var gate: Node3D = builder.call(&"_instance", puzzle, GATE_SCENE, "EntryGate", Vector3(ENTRY_X, 0.0, DOOR_Z), builder.call(&"_yaw", 90.0)) as Node3D
	var lever: Node3D = builder.call(&"_instance", puzzle, LEVER_SCENE, "LeverEntry", Vector3(112.0, 0.0, 6.0)) as Node3D
	gate.set("source", lever)
	builder.call(&"_instance", puzzle, BEAM_SCENE, "EntryThreshold", Vector3(ENTRY_X, -1.0, DOOR_Z), builder.call(&"_yaw", 90.0))
	builder.call(&"_label", puzzle, "Label_Entry", "Rätselräume", Vector3(ENTRY_X, 5.0, DOOR_Z))


## A room node with its name label and the x range metadata.
func _room(puzzle: Node3D, builder: RefCounted, node_name: String, title: String, x_in: float, x_out: float) -> Node3D:
	var room: Node3D = builder.call(&"_group", puzzle, node_name) as Node3D
	room.set_meta(&"x_range", Vector2(x_in + PUZZLE_SHIFT_X, x_out + PUZZLE_SHIFT_X))
	builder.call(&"_label", room, "Label_Name", title, Vector3(x_in + 6.0, 5.0, DOOR_Z))
	return room


## Floor tiles (4 m) between x0 and x1 at height `top`, on the given rows. Names carry the integer tile centre: Prefix_x_z.
func _tiles(room: Node3D, builder: RefCounted, prefix: String, x0: float, x1: float, top: float, rows: Array[float]) -> void:
	var columns: int = roundi((x1 - x0) / TILE)
	for column: int in columns:
		var x: float = x0 + TILE * 0.5 + TILE * column
		for z: float in rows:
			builder.call(&"_floor_tile", room, "%s_%d_%d" % [prefix, roundi(x), roundi(z)], x, top, z)


func _side_walls(room: Node3D, builder: RefCounted, x0: float, x1: float, prefix: String) -> void:
	var columns: int = roundi((x1 - x0) / TILE)
	for column: int in columns:
		var x: float = x0 + TILE * 0.5 + TILE * column
		builder.call(&"_wall", room, "%sWallN_%d" % [prefix, roundi(x)], x, -HALF - 0.5, 0.0, 0.0)
		builder.call(&"_wall", room, "%sWallS_%d" % [prefix, roundi(x)], x, HALF + 0.5, 0.0, 0.0)


## A wall plane at `x` across the room with the doorway cell left open (closed when `door` is false).
func _cross_wall(room: Node3D, builder: RefCounted, x: float, prefix: String, door: bool) -> void:
	var z: float = -HALF + TILE * 0.5
	var index: int = 0
	while z < HALF:
		if not (door and is_equal_approx(z, DOOR_Z)):
			builder.call(&"_wall", room, "%s_%d" % [prefix, index], x, z, 90.0, 0.0)
		z += TILE
		index += 1


func _gate(room: Node3D, builder: RefCounted, x_out: float, source: Node3D) -> GearGate:
	var gate: GearGate = builder.call(&"_instance", room, GATE_SCENE, "ExitGate", Vector3(x_out, 0.0, DOOR_Z), builder.call(&"_yaw", 90.0)) as GearGate
	gate.set("source", source)
	builder.call(&"_instance", room, BEAM_SCENE, "Threshold", Vector3(x_out, -1.0, DOOR_Z), builder.call(&"_yaw", 90.0))
	return gate


func _lever(room: Node3D, builder: RefCounted, node_name: String, at: Vector3, near_only: bool = false) -> Node3D:
	var lever: Node3D = builder.call(&"_instance", room, LEVER_SCENE, node_name, at) as Node3D
	if near_only:
		lever.set("near_only", true)
	return lever


func _mechanism(room: Node3D, builder: RefCounted, scene: String, node_name: String, at: Vector3, source: Node3D, props: Dictionary = {}, basis: Basis = Basis.IDENTITY) -> Node3D:
	var mechanism: Node3D = builder.call(&"_instance", room, scene, node_name, at, basis) as Node3D
	mechanism.set("source", source)
	for key: Variant in props:
		mechanism.set(String(key), props[key])
	return mechanism


func _logic(room: Node3D, builder: RefCounted, scene: String, node_name: String, at: Vector3, sources: Array[SignalSource]) -> Node3D:
	var logic: Node3D = builder.call(&"_instance", room, scene, node_name, at) as Node3D
	logic.set("sources", sources)
	return logic


func _sources(items: Array) -> Array[SignalSource]:
	var typed: Array[SignalSource] = []
	for item: Variant in items:
		typed.append(item as SignalSource)
	return typed


## The respawn marker and the FallReset volume under the whole room (x_in..x_end). It resets every mechanism of the room.
func _finish(room: Node3D, builder: RefCounted, x_in: float, x_end: float, respawn: Vector3, solve: Array, sizes: Array, checks: Array) -> void:
	var marker: Marker3D = Marker3D.new()
	builder.call(&"_adopt", room, marker, "Respawn", respawn)
	var rig: Node3D = (builder.get(&"_root") as Node).get_node("CameraRig") as Node3D
	var centre: Vector3 = Vector3((x_in + x_end) * 0.5, FALL_Y, 0.0)
	var size: Vector3 = Vector3(x_end - x_in, FALL_THICKNESS, FALL_HALF_Z * 2.0)
	var area: FallReset = builder.call(&"_fall_reset", "FallReset", centre, size, marker, rig) as FallReset
	area.reset_root = room
	builder.call(&"_adopt", room, area, "FallReset", centre)
	builder.call(&"_owner_children", area)
	var paths: Array[NodePath] = []
	for entry: Variant in solve:
		paths.append(NodePath(String(entry)))
	room.set_meta(&"solve_order", paths)
	room.set_meta(&"solve_sizes", sizes)
	var specs: Array = []
	for entry: Variant in checks:
		var spec: Dictionary = (entry as Dictionary).duplicate()
		spec["from"] = NodePath(String(spec["from"]))
		spec["to"] = NodePath(String(spec["to"]))
		specs.append(spec)
	room.set_meta(&"reach_checks", specs)


func _needs(from: String, to: String) -> Dictionary:
	return {"from": from, "to": to, "rule": &"needs_mechanism", "via": &"none"}


func _reach(from: String, to: String, via: StringName, extra: Dictionary = {}) -> Dictionary:
	var spec: Dictionary = {"from": from, "to": to, "rule": &"reachable", "via": via}
	spec.merge(extra)
	return spec


# --- room 1: Fernschuss ---------------------------------------------------------------------------------------


## The pulse room. A lever on an 8 m pillar stack is out of any jump, a valve on the island is 16 m across the pit (small pulse range
## 15 m, big pulse 25 m); both feed an AND that raises the piston lift to the 6 m ledge (more than the highest jump). On the ledge a
## shot wakes the energy core (8 s), and the player drops to the island and runs through the ExitGate before it closes.
func _build_room_1(puzzle: Node3D, builder: RefCounted) -> void:
	var x_in: float = 116.0
	var x_out: float = 152.5
	var room: Node3D = _room(puzzle, builder, "PuzzleRoom_1", "Fernschuss", x_in, x_out)
	_tiles(room, builder, "StartFloor", 116.0, 128.0, 0.0, ROWS_ALL)
	_tiles(room, builder, "IslandFloor", 144.0, 152.0, 0.0, ROWS_ALL)
	_tiles(room, builder, "LedgeFloor", 132.0, 144.0, 6.0, ROWS_LEDGE)
	_side_walls(room, builder, x_in, 152.0, "R1")
	_cross_wall(room, builder, x_out, "R1WallEast", true)

	builder.call(&"_instance", room, PILLAR_SCENE, "FarPillarLow", Vector3(124.0, 0.0, -10.0))
	builder.call(&"_instance", room, PILLAR_SCENE, "FarPillarTop", Vector3(124.0, 4.0, -10.0))
	var lever_far: Node3D = _lever(room, builder, "LeverFar", Vector3(124.0, 8.0, -10.0))
	var valve: Node3D = builder.call(&"_instance", room, VALVE_SCENE, "Valve", Vector3(146.0, 0.0, 6.0)) as Node3D
	var both: Node3D = _logic(room, builder, AND_SCENE, "LogicAnd", Vector3(130.0, 0.0, -4.0), _sources([lever_far, valve]))
	_mechanism(room, builder, LIFT_SCENE, "Lift", Vector3(130.0, 0.0, 0.0), both, {"point_a": Vector3.ZERO, "point_b": Vector3(0.0, 6.0, 0.0), "speed": 3.0, "look": LiftPlatform.Look.PISTON})
	var core: Node3D = builder.call(&"_instance", room, CORE_SCENE, "EnergyCore", Vector3(141.0, 6.0, 0.0)) as Node3D
	core.set("core_duration", 8.0)
	_gate(room, builder, x_out, core)

	var checks: Array = [
		_needs("StartFloor_126_2", "IslandFloor_146_2"),
		_needs("StartFloor_126_2", "LedgeFloor_134_2"),
		_needs("StartFloor_126_-10", "FarPillarTop"),
		_reach("StartFloor_126_2", "Lift", &"jump"),
		_reach("Lift", "LedgeFloor_134_2", &"lift_top"),
		_reach("LedgeFloor_142_2", "IslandFloor_146_2", &"jump"),
	]
	_finish(room, builder, x_in, x_out, Vector3(119.0, 0.0, DOOR_Z), ["LeverFar", "Valve", "EnergyCore"], [0, 1, 0], checks)


# --- room 2: Uhrwerk ------------------------------------------------------------------------------------------


## The clockwork room. The 22 m pit is wider than any jump chain. The belt runs west until the crank is wound (hold E) or the lever on
## the gear island is thrown (OR), then it carries the player east. A pendulum sweeps the belt across its width. A divider wall keeps
## the island apart from the far platform, so the gear route does not skip the belt.
func _build_room_2(puzzle: Node3D, builder: RefCounted) -> void:
	var x_in: float = 153.0
	var x_out: float = 199.5
	var room: Node3D = _room(puzzle, builder, "PuzzleRoom_2", "Uhrwerk", x_in, x_out)
	_tiles(room, builder, "StartFloor", 153.0, 165.0, 0.0, ROWS_ALL)
	_tiles(room, builder, "FarFloor", 187.0, 199.0, 0.0, ROWS_ALL)
	_tiles(room, builder, "IslandFloor", 179.0, 183.0, 0.0, [4.0])
	_side_walls(room, builder, x_in, 199.0, "R2")
	_cross_wall(room, builder, x_out, "R2WallEast", true)
	for z: float in [-6.0, -2.0, 2.0, 6.0, 10.0]:
		builder.call(&"_wall", room, "Divider_%d" % roundi(z), 185.5, z, 90.0, 0.0)
		builder.call(&"_wall", room, "DividerTop_%d" % roundi(z), 185.5, z, 90.0, 4.0)

	var crank: Node3D = builder.call(&"_instance", room, CRANK_SCENE, "Crank", Vector3(157.0, 0.0, -10.0)) as Node3D
	var lever_gear: Node3D = _lever(room, builder, "LeverGear", Vector3(157.0, 0.0, 6.0))
	_mechanism(room, builder, ROTATING_SCENE, "Gear", Vector3(171.0, 0.0, 4.0), lever_gear, {"axis_mode": RotatingPlatform.AxisMode.LYING})
	var lever_b: Node3D = _lever(room, builder, "LeverB", Vector3(181.0, 0.0, 4.0))
	var either: Node3D = _logic(room, builder, OR_SCENE, "LogicOr", Vector3(160.0, 0.0, -10.0), _sources([crank, lever_b]))
	_mechanism(room, builder, CONVEYOR_SCENE, "Conveyor", Vector3(175.0, 0.0, -10.0), either, {"behaviour": Mechanism.Behaviour.REVERSE_ON_SIGNAL}, builder.call(&"_yaw", 90.0))
	# An always-on driver for the pendulum, added before it so it is ready first.
	var driver: SignalSource = SignalSource.new()
	driver.start_active = true
	builder.call(&"_adopt", room, driver, "PendulumDriver", Vector3(175.0, 0.0, -10.0))
	_mechanism(room, builder, PENDULUM_SCENE, "Pendulum", Vector3(175.0, 0.0, -10.0), driver, {}, builder.call(&"_yaw", -90.0))
	var lever_exit: Node3D = _lever(room, builder, "LeverExit", Vector3(191.0, 0.0, -10.0))
	_gate(room, builder, x_out, lever_exit)

	var checks: Array = [
		_needs("StartFloor_163_-10", "FarFloor_189_-10"),
		_reach("StartFloor_163_-10", "Conveyor", &"jump"),
		_reach("Conveyor", "FarFloor_189_-10", &"jump"),
		_reach("StartFloor_163_2", "Gear", &"jump"),
		_reach("Gear", "IslandFloor_181_4", &"jump"),
		_needs("IslandFloor_181_4", "DividerTop_2"),
	]
	_finish(room, builder, x_in, x_out, Vector3(156.0, 0.0, DOOR_Z), ["Crank", "LeverExit"], [-1, 0], checks)


# --- room 3: Dampf --------------------------------------------------------------------------------------------


## The steam room, an ascent and a descent. A lever starts a 5 s timer that runs the jump nozzle (5 m ledge), a clock hand carries the
## player to the 9 m ledge, an updraft column lifts to the 14 m ledge, a tilt plate (or the cannon shortcut) crosses the 16 m gap, a
## chain lift brings the player down. The ExitGate needs a shot lever on the high ledge AND a near-contact lever on the ground, and a
## steam wall in front of the gate blows against the player until its lever turns it into a tailwind.
func _build_room_3(puzzle: Node3D, builder: RefCounted) -> void:
	var x_in: float = 200.0
	var x_out: float = 304.5
	var x_end: float = 313.5
	var room: Node3D = _room(puzzle, builder, "PuzzleRoom_3", "Dampf", x_in, x_out)
	_tiles(room, builder, "StartFloor", 200.0, 212.0, 0.0, ROWS_ALL)
	_tiles(room, builder, "Ledge1Floor", 214.0, 226.0, 5.0, ROWS_LEDGE)
	_tiles(room, builder, "Ledge2Floor", 236.0, 248.0, 9.0, ROWS_LEDGE)
	_tiles(room, builder, "Ledge3Floor", 248.0, 256.0, 14.0, ROWS_LEDGE)
	_tiles(room, builder, "Ledge4Floor", 272.0, 284.0, 14.0, ROWS_LEDGE)
	_tiles(room, builder, "EndFloor", 288.0, 304.0, 0.0, ROWS_ALL)
	_tiles(room, builder, "GoalFloor", 305.0, 313.0, 0.0, ROWS_ALL)
	_side_walls(room, builder, x_in, 212.0, "R3a")
	_side_walls(room, builder, 288.0, 313.0, "R3b")
	_cross_wall(room, builder, x_out, "R3WallMid", true)
	_cross_wall(room, builder, x_end, "R3WallEast", false)

	var yaw_east: Basis = builder.call(&"_yaw", 90.0)
	# Stage 1: lever, timer, jump nozzle up to the 5 m ledge.
	var lever_a: Node3D = _lever(room, builder, "LeverA", Vector3(203.0, 0.0, -6.0))
	var timer: Node3D = builder.call(&"_instance", room, TIMER_SCENE, "Timer", Vector3(203.0, 0.0, -6.0)) as Node3D
	timer.set("source", lever_a)
	timer.set("hold_time", 5.0)
	_mechanism(room, builder, NOZZLE_SCENE, "NozzleJump", Vector3(210.0, 0.0, 0.0), timer, {"mode": SteamNozzle.Mode.JUMP, "launch_speed": 22.0})
	# Stage 2: the clock hand, pivot at the end of the 5 m ledge, sweeping up to the 9 m ledge.
	var lever_b: Node3D = _lever(room, builder, "LeverB", Vector3(217.0, 5.0, -6.0))
	_mechanism(room, builder, ROTATING_SCENE, "Hand", Vector3(226.0, 5.0, 0.0), lever_b, {"axis_mode": RotatingPlatform.AxisMode.STANDING}, yaw_east)
	# Stage 3: updraft column from the 9 m ledge to the 14 m ledge.
	var lever_c: Node3D = _lever(room, builder, "LeverC", Vector3(239.0, 9.0, -6.0))
	_mechanism(room, builder, NOZZLE_SCENE, "Updraft", Vector3(244.0, 9.0, 0.0), lever_c, {"mode": SteamNozzle.Mode.UPDRAFT})
	# Stage 4: the tilt plate across the 16 m gap, and the cannon shortcut over it.
	var lever_d: Node3D = _lever(room, builder, "LeverD", Vector3(251.0, 14.0, -6.0))
	_mechanism(room, builder, ROTATING_SCENE, "Tilt", Vector3(264.0, 14.0, 0.0), lever_d, {"axis_mode": RotatingPlatform.AxisMode.TILTING})
	var lever_cannon: Node3D = _lever(room, builder, "LeverCannon", Vector3(250.5, 14.0, 6.0))
	var cannon_basis: Basis = Basis.from_euler(Vector3(PI * 0.25, -PI * 0.5, 0.0))
	_mechanism(room, builder, NOZZLE_SCENE, "Cannon", Vector3(254.0, 14.0, 6.0), lever_cannon, {"mode": SteamNozzle.Mode.CANNON, "launch_speed": 28.0}, cannon_basis)
	# Stage 5: chain lift down, then the exit: shot lever above, near lever below, steam wall in front of the gate.
	var lever_lift: Node3D = _lever(room, builder, "LeverLift", Vector3(280.0, 14.0, 6.0))
	_mechanism(room, builder, LIFT_SCENE, "LiftChain", Vector3(286.0, 0.0, 0.0), lever_lift, {"point_a": Vector3.ZERO, "point_b": Vector3(0.0, 14.0, 0.0), "speed": 4.0, "look": LiftPlatform.Look.CHAIN})
	var exit_shot: Node3D = _lever(room, builder, "ExitShot", Vector3(276.0, 14.0, -6.0))
	var lever_near: Node3D = _lever(room, builder, "LeverNear", Vector3(291.0, 0.0, 6.0), true)
	var both: Node3D = _logic(room, builder, AND_SCENE, "ExitAnd", Vector3(300.0, 0.0, 6.0), _sources([exit_shot, lever_near]))
	var lever_wall: Node3D = _lever(room, builder, "LeverWall", Vector3(296.0, 0.0, 8.0))
	_mechanism(room, builder, NOZZLE_SCENE, "Wall", Vector3(302.5, 0.0, DOOR_Z), lever_wall, {"mode": SteamNozzle.Mode.WALL, "behaviour": Mechanism.Behaviour.REVERSE_ON_SIGNAL}, yaw_east)
	_gate(room, builder, x_out, both)
	builder.call(&"_label", room, "Label_Goal", "Ziel", Vector3(309.0, 3.0, DOOR_Z))

	var hand_tip: float = 8.0 * sin(deg_to_rad(35.0))
	var hand_gap: float = 8.0 - 8.0 * cos(deg_to_rad(35.0))
	var checks: Array = [
		_needs("StartFloor_210_2", "Ledge1Floor_216_2"),
		_reach("NozzleJump", "Ledge1Floor_216_2", &"nozzle_apex"),
		_reach("Ledge1Floor_224_2", "Hand", &"jump"),
		_reach("Hand", "Ledge2Floor_238_2", &"jump", {"from_dy": hand_tip, "gap_extra": hand_gap}),
		_needs("Ledge2Floor_246_2", "Ledge3Floor_250_2"),
		_reach("Updraft", "Ledge3Floor_250_2", &"updraft_jump"),
		_needs("Ledge3Floor_254_2", "Ledge4Floor_274_2"),
		_reach("Ledge3Floor_254_2", "Tilt", &"jump"),
		_reach("Tilt", "Ledge4Floor_274_2", &"jump"),
		_reach("Cannon", "Ledge4Floor_274_2", &"cannon"),
		_reach("LiftChain", "Ledge4Floor_282_2", &"lift_top"),
		_reach("LiftChain", "EndFloor_290_2", &"jump"),
	]
	_finish(room, builder, x_in, x_end, Vector3(203.0, 0.0, DOOR_Z), ["LeverA", "LeverB", "LeverC", "LeverD", "LeverCannon", "LeverLift", "ExitShot", "LeverNear"], [0, 0, 0, 0, 0, 0, 0, -1], checks)
